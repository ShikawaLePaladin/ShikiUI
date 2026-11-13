// lint50 : verifie qu'un fichier Lua reste compatible avec le Lua 5.0 de WoW 1.12 et les regles du projet.
//  - interdits 5.0 : '#', '%', '...', select, rawlen, string.match / string.gmatch ;
//  - interdits projet : loadstring / loadfile / dofile / RunScript / setfenv / getfenv sur du texte importe (aucun usage tolere), source non ASCII ou avec BOM ;
//  - fuites : ecriture d'une globale non declaree (hors ShikiUI*, SLASH_*, SlashCmdList[...]) ;
//  - upvalues : une fonction ne doit pas depasser 32 upvalues (alerte des 20) ; 200 locals max par fonction.
// Usage : node lint50.js fichier.lua [...]
const fs = require('fs');
const path = require('path');
function req(name) {
  const cands = [path.join(__dirname, 'node_modules'), 'C:/Temp/ccx/luatest/node_modules', path.join(__dirname, '..', 'node_modules')];
  for (const c of cands) { try { return require(path.join(c, name)); } catch (e) { /* suivant */ } }
  return require(name);
}
const luaparse = req('luaparse');

const ALLOWED_GLOBAL_WRITES = new RegExp("^(ShikiUI|ShikiUIDB|SLASH_SHIKIUI[0-9]+|_ERRORMESSAGE)$");
const BAD_STRING_FN = ['match', 'gmatch', 'rawlen'];
const BAD_CALLS = ['select', 'rawlen', 'loadstring', 'loadfile', 'dofile', 'RunScript', 'setfenv', 'getfenv', 'load'];

let total = 0;
for (const file of process.argv.slice(2)) {
  const raw = fs.readFileSync(file);
  const issues = [];
  if (raw.length >= 3 && raw[0] === 0xEF && raw[1] === 0xBB && raw[2] === 0xBF) issues.push('BOM UTF-8 present');
  for (let i = 0; i < raw.length; i++) if (raw[i] > 127) { issues.push(`octet non ASCII a l'offset ${i}`); break; }
  const src = raw.toString('latin1');
  let ast;
  try { ast = luaparse.parse(src, { luaVersion: '5.1', locations: true, comments: false }); }
  catch (e) { console.log(`${file}: PARSE ERROR ${e.message}`); total++; continue; }

  // ---- constructions interdites
  (function walk(n) {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(walk); return; }
    const line = n.loc ? n.loc.start.line : '?';
    if (n.type === 'UnaryExpression' && n.operator === '#') issues.push(`ligne ${line}: operateur '#' (absent de Lua 5.0)`);
    if (n.type === 'BinaryExpression' && n.operator === '%') issues.push(`ligne ${line}: operateur '%' (absent de Lua 5.0)`);
    if (n.type === 'VarargLiteral') issues.push(`ligne ${line}: '...' (absent de Lua 5.0)`);
    if (n.type === 'MemberExpression' && n.base && n.base.type === 'Identifier' && n.base.name === 'string' && BAD_STRING_FN.includes(n.identifier.name)) issues.push(`ligne ${line}: string.${n.identifier.name} (absent de Lua 5.0)`);
    if (n.type === 'CallExpression' && n.base.type === 'Identifier' && BAD_CALLS.includes(n.base.name)) issues.push(`ligne ${line}: ${n.base.name}() interdit`);
    if (n.type === 'StringCallExpression' && n.base.type === 'Identifier' && BAD_CALLS.includes(n.base.name)) issues.push(`ligne ${line}: ${n.base.name} interdit`);
    for (const k of Object.keys(n)) if (k !== 'loc' && k !== 'range') walk(n[k]);
  })(ast);

  // ---- portee : globales ecrites, locals par fonction, upvalues
  const warnings = [];
  function analyzeFunction(fn, outerScopes, outerNames) {
    const scopes = [new Set()];            // portees locales de CETTE fonction
    let localCount = 0;
    const used = new Set();                // identifiants references
    const declareHere = (name) => { scopes[scopes.length - 1].add(name); localCount++; };
    const isLocalHere = (name) => scopes.some(s => s.has(name));
    (fn.parameters || []).forEach(p => { if (p.name) declareHere(p.name); });
    const nested = [];
    function w(n) {
      if (!n || typeof n !== 'object') return;
      if (Array.isArray(n)) { n.forEach(w); return; }
      const line = n.loc ? n.loc.start.line : '?';
      switch (n.type) {
        case 'FunctionDeclaration':
          if (n.identifier) {
            if (n.isLocal) declareHere(n.identifier.name);
            else if (n.identifier.type === 'Identifier') { used.add(n.identifier.name); checkGlobalWrite(n.identifier.name, line); }
            else w(n.identifier);
          }
          nested.push({ n, scopesSnapshot: scopes.map(s => new Set(s)) });
          return;
        case 'LocalStatement':
          w(n.init);
          n.variables.forEach(v => declareHere(v.name));
          return;
        case 'AssignmentStatement':
          n.variables.forEach(v => { if (v.type === 'Identifier') { used.add(v.name); checkGlobalWrite(v.name, line); } else w(v); });
          w(n.init);
          return;
        case 'ForNumericStatement':
          w([n.start, n.end, n.step]);
          scopes.push(new Set()); declareHere(n.variable.name); w(n.body); scopes.pop();
          return;
        case 'ForGenericStatement':
          w(n.iterators);
          scopes.push(new Set()); n.variables.forEach(v => declareHere(v.name)); w(n.body); scopes.pop();
          return;
        case 'DoStatement': scopes.push(new Set()); w(n.body); scopes.pop(); return;
        case 'WhileStatement': w(n.condition); scopes.push(new Set()); w(n.body); scopes.pop(); return;
        case 'RepeatStatement': scopes.push(new Set()); w(n.body); w(n.condition); scopes.pop(); return;
        case 'IfClause': case 'ElseifClause': w(n.condition); scopes.push(new Set()); w(n.body); scopes.pop(); return;
        case 'ElseClause': scopes.push(new Set()); w(n.body); scopes.pop(); return;
        case 'Identifier': used.add(n.name); return;
        default:
          for (const k of Object.keys(n)) if (k !== 'loc' && k !== 'range') w(n[k]);
      }
    }
    function checkGlobalWrite(name, line) {
      if (isLocalHere(name)) return;
      if (outerNames.has(name)) return;     // local d'une fonction englobante
      if (ALLOWED_GLOBAL_WRITES.test(name)) return;
      issues.push(`ligne ${line}: ecriture de la globale '${name}' (fuite ?)`);
    }
    w(fn.body);
    if (localCount > 200) issues.push(`ligne ${fn.loc.start.line}: ${localCount} locals dans une fonction (limite 200)`);
    // upvalues : identifiants utilises, non locaux ici, presents dans les portees englobantes
    const ups = [...used].filter(nm => !isLocalHere(nm) && outerNames.has(nm));
    // isLocalHere ne voit que la derniere portee ouverte ; on recalcule avec l'union des locals de la fonction
    const own = new Set();
    (function collect(n) {
      if (!n || typeof n !== 'object') return;
      if (Array.isArray(n)) { n.forEach(collect); return; }
      if (n.type === 'FunctionDeclaration') { if (n.isLocal && n.identifier) own.add(n.identifier.name); return; }
      if (n.type === 'LocalStatement') n.variables.forEach(v => own.add(v.name));
      if (n.type === 'ForNumericStatement') own.add(n.variable.name);
      if (n.type === 'ForGenericStatement') n.variables.forEach(v => own.add(v.name));
      for (const k of Object.keys(n)) if (k !== 'loc' && k !== 'range') collect(n[k]);
    })(fn.body);
    (fn.parameters || []).forEach(p => p.name && own.add(p.name));
    const realUps = [...used].filter(nm => !own.has(nm) && outerNames.has(nm));
    if (realUps.length > 32) issues.push(`ligne ${fn.loc.start.line}: ${realUps.length} upvalues (limite 32)`);
    else if (realUps.length > 20) warnings.push(`ligne ${fn.loc.start.line}: ${realUps.length} upvalues (limite 32, alerte des 20)`);
    nested.forEach(({ n }) => {
      const names = new Set([...outerNames, ...own]);
      analyzeFunction(n, scopes, names);
    });
  }

  const top = { parameters: [], body: ast.body, loc: { start: { line: 1 } } };
  analyzeFunction(top, [], new Set());

  total += issues.length;
  const topLocals = new Set();
  ast.body.forEach(s => { if (s.type === 'LocalStatement') s.variables.forEach(v => topLocals.add(v.name)); if (s.type === 'FunctionDeclaration' && s.isLocal) topLocals.add(s.identifier.name); });
  if (issues.length) console.log(`${file}:\n  ` + issues.join('\n  '));
  else console.log(`${file}: LINT OK (locals de tete : ${topLocals.size}/200)` + (warnings.length ? `  [${warnings.length} alerte(s)]` : ''));
  warnings.forEach(x => console.log(`  alerte ${x}`));
}
process.exit(total ? 1 : 0);
