// lint_loopclosure : detecte les FERMETURES qui capturent la variable d'une boucle for (Lua 5.0 / client 1.12 : la variable est
// partagee entre les iterations, toutes les fermetures voient la derniere valeur -> tous les boutons font la meme chose).
// Usage : node lint_loopclosure.js [--all] fichier.lua ...   (sans --all : seulement les variables de boucle for ; --all : aussi les
// 'local' declares dans le corps de la boucle et captures par une fermeture)
// Correctif attendu : stocker la valeur sur l'objet (b.n = i) et la relire dans le gestionnaire (this.n / argument), pas dans l'amont.
const fs = require('fs');
const args = process.argv.slice(2);
const all = args.indexOf('--all') >= 0;
const files = args.filter(a => a !== '--all');

function tokenize(src) {
  // retire commentaires et chaines en gardant les numeros de ligne
  const toks = [];
  let i = 0, line = 1;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === '\n') { line++; i++; continue; }
    if (/\s/.test(c)) { i++; continue; }
    if (c === '-' && src[i + 1] === '-') {
      if (src[i + 2] === '[' && src[i + 3] === '[') {
        const e = src.indexOf(']]', i + 4);
        const end = e < 0 ? n : e + 2;
        for (let k = i; k < end; k++) if (src[k] === '\n') line++;
        i = end; continue;
      }
      while (i < n && src[i] !== '\n') i++;
      continue;
    }
    if (c === '"' || c === "'") {
      let k = i + 1;
      while (k < n && src[k] !== c) { if (src[k] === '\\') k++; k++; }
      i = k + 1; toks.push({ t: 'str', line }); continue;
    }
    if (c === '[' && (src[i + 1] === '[' || src[i + 1] === '=')) {
      const m = /^\[(=*)\[/.exec(src.slice(i, i + 12));
      if (m) {
        const close = ']' + m[1] + ']';
        const e = src.indexOf(close, i + m[0].length);
        const end = e < 0 ? n : e + close.length;
        for (let k = i; k < end; k++) if (src[k] === '\n') line++;
        i = end; toks.push({ t: 'str', line }); continue;
      }
    }
    if (/[A-Za-z_]/.test(c)) {
      let k = i + 1;
      while (k < n && /[A-Za-z0-9_]/.test(src[k])) k++;
      toks.push({ t: 'id', v: src.slice(i, k), line, prev: src[i - 1] });
      i = k; continue;
    }
    if (/[0-9]/.test(c)) {
      let k = i + 1;
      while (k < n && /[0-9.xXa-fA-F]/.test(src[k])) k++;
      i = k; toks.push({ t: 'num', line }); continue;
    }
    toks.push({ t: 'op', v: c, line });
    i++;
  }
  return toks;
}

const found = [];
for (const file of files) {
  const toks = tokenize(fs.readFileSync(file, 'latin1'));
  const stack = [];           // { kind, vars, locals, line, caps }
  const loops = [];
  let skipDo = 0;
  for (let p = 0; p < toks.length; p++) {
    const tk = toks[p];
    if (tk.t !== 'id') {
      continue;
    }
    const v = tk.v;
    const isField = tk.prev === '.' || tk.prev === ':';
    if (v === 'for' && !isField) {
      // variables : jusqu'a '=' ou 'in'
      const vars = [];
      let q = p + 1;
      while (q < toks.length && !(toks[q].t === 'op' && toks[q].v === '=') && !(toks[q].t === 'id' && toks[q].v === 'in')) {
        if (toks[q].t === 'id') vars.push(toks[q].v);
        q++;
      }
      stack.push({ kind: 'for', vars, locals: [], line: tk.line, caps: [] });
      skipDo++;
    } else if (v === 'while' && !isField) {
      stack.push({ kind: 'while', vars: [], locals: [], line: tk.line, caps: [] });
      skipDo++;
    } else if (v === 'do' && !isField) {
      if (skipDo > 0) skipDo--; else stack.push({ kind: 'do', vars: [], locals: [], line: tk.line, caps: [] });
    } else if (v === 'function' && !isField) {
      // parametres : jusqu'a ')'
      const params = [];
      let q = p + 1;
      while (q < toks.length && !(toks[q].t === 'op' && toks[q].v === ')')) {
        if (toks[q].t === 'id') params.push(toks[q].v);
        q++;
      }
      stack.push({ kind: 'function', vars: [], params, locals: [], line: tk.line, caps: [] });
    } else if (v === 'if' && !isField) {
      stack.push({ kind: 'if', vars: [], locals: [], line: tk.line, caps: [] });
    } else if (v === 'repeat' && !isField) {
      stack.push({ kind: 'repeat', vars: [], locals: [], line: tk.line, caps: [] });
    } else if ((v === 'end' || v === 'until') && !isField) {
      const f = stack.pop();
      if (f && f.kind === 'for') loops.push(f);
      if (f && f.kind === 'for') {
        for (const c of f.caps) found.push({ file, line: c.line, v: c.v, loop: f.line, kind: c.kind });
      }
    } else if (v === 'local' && !isField) {
      // enregistre les noms declares dans le corps de la boucle englobante
      let q = p + 1;
      if (toks[q] && toks[q].t === 'id' && toks[q].v === 'function') q++;
      const names = [];
      while (q < toks.length && toks[q].t === 'id') {
        names.push(toks[q].v);
        q++;
        if (toks[q] && toks[q].t === 'op' && toks[q].v === ',') q++; else break;
      }
      for (let s = stack.length - 1; s >= 0; s--) {
        if (stack[s].kind === 'function') break;
        if (stack[s].kind === 'for' || stack[s].kind === 'while') { for (const nm of names) stack[s].locals.push(nm); break; }
      }
    } else if (!isField) {
      // identifiant : capture eventuelle par une fermeture imbriquee dans une boucle
      let fi = -1;
      for (let s = stack.length - 1; s >= 0; s--) if (stack[s].kind === 'function') { fi = s; break; }
      if (fi >= 0) {
        const fn = stack[fi];
        if (fn.params.indexOf(v) >= 0) continue;
        for (let s = fi - 1; s >= 0; s--) {
          const lp = stack[s];
          if (lp.kind === 'function') {
            if (lp.params.indexOf(v) >= 0) break;
            continue;
          }
          if (lp.kind === 'for' && lp.vars.indexOf(v) >= 0) {
            lp.caps.push({ line: tk.line, v, kind: 'var' });
            break;
          }
          if (all && (lp.kind === 'for' || lp.kind === 'while') && lp.locals.indexOf(v) >= 0) {
            lp.caps.push({ line: tk.line, v, kind: 'local' });
            break;
          }
        }
      }
    }
  }
}
// dedoublonne (fichier, ligne, variable)
const seen = {};
let n = 0;
for (const f of found) {
  const key = f.file + ':' + f.line + ':' + f.v;
  if (seen[key]) continue;
  seen[key] = 1;
  console.log(f.file.replace(/^.*[\\/]/, '') + ':' + f.line + '  ' + f.kind + ' "' + f.v + '" (boucle ligne ' + f.loop + ') capturee par une fermeture');
  n++;
}
console.log(n === 0 ? 'FERMETURES DE BOUCLE OK' : n + ' capture(s) de variable de boucle');
process.exit(n === 0 ? 0 : 1);
