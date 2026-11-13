// Harnais de test ShikiUI : API WoW 1.12 simulee (fengari = Lua 5.3 avec les raccourcis 5.0), STRICT :
//  - methodes de widgets limitees a la liste 1.12 (voir mock_wow.lua) ;
//  - lecture d'une globale non definie = ERREUR (sauf extensions optionnelles listees) -> detecte les fautes de frappe ;
//  - ecriture d'une globale non declaree = ERREUR (fuite de variable) ;
//  - les fichiers de l'addon sont charges dans l'ordre du .toc, chacun dans son propre chunk (comme le client) ;
//  - toute extension de simulation tests/mock_<nom>.lua est chargee automatiquement apres mock_wow.lua (ordre alphabetique),
//    AVANT le mode strict : elle peut donc definir des globales (un module ajoute ses aides de test sans toucher aux autres fichiers).
// Usage : node harness.js <suite.lua>      env : ADDON_DIR (dossier de l'addon)
const fs = require('fs');
const path = require('path');
function req(name) {
  const cands = [path.join(__dirname, 'node_modules'), 'C:/Temp/ccx/luatest/node_modules', path.join(__dirname, '..', 'node_modules')];
  for (const c of cands) { try { return require(path.join(c, name)); } catch (e) { /* suivant */ } }
  return require(name);
}
const { lua, lauxlib, lualib, to_luastring } = req('fengari');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function run(code, name) {
  const s = to_luastring(code);
  if (lauxlib.luaL_loadbuffer(L, s, s.length, to_luastring('@' + name)) || lua.lua_pcall(L, 0, 0, 0)) {
    console.log('LUA ERROR in ' + name + ': ' + lua.lua_tojsstring(L, -1));
    process.exit(1);
  }
}
const here = __dirname;
const addonDir = process.env.ADDON_DIR || path.join(here, '..', 'ShikiUI');
const strip = (s) => s.replace(/^\uFEFF/, '');
run(strip(fs.readFileSync(path.join(here, 'mock_wow.lua'), 'utf8')), 'mock_wow.lua');
for (const f of fs.readdirSync(here).filter(f => /^mock_.*\.lua$/.test(f) && f !== 'mock_wow.lua').sort()) {
  run(strip(fs.readFileSync(path.join(here, f), 'utf8')), f);
}
run(strip(fs.readFileSync(path.join(here, 'lib_test.lua'), 'utf8')), 'lib_test.lua');   // avant le mode strict : declare les globales de test
run('STRICT_ON()', 'strict');
const toc = fs.readFileSync(path.join(addonDir, 'ShikiUI.toc'), 'utf8').split(/\r?\n/);
const files = toc.map(l => l.trim()).filter(l => l && l.indexOf('#') !== 0).map(f => path.join(addonDir, f));
for (const f of files) run(strip(fs.readFileSync(f, 'utf8')), path.basename(f));
const suite = process.argv[2];
run(strip(fs.readFileSync(path.isAbsolute(suite) ? suite : path.join(process.cwd(), suite), 'utf8')), path.basename(suite));
run('if not TESTS_DONE then print("SUITE ENDED WITHOUT TESTS_DONE") ; os.exit(1) end', 'end');
