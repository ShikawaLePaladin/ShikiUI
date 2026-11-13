// mutate : verifie que les tests detectent de vraies regressions. Chaque mutation est appliquee a une COPIE de l'addon ;
// au moins une suite doit echouer. Un mutant qui survit = trou dans les tests.
// Les mutations vivent dans tests/mutations/<nom>.js (un fichier par module, charge automatiquement) :
//   module.exports = [ [fichier, motif, remplacement, libelle[, suite]], ... ]    fichier relatif a ShikiUI\ ; le motif doit exister EXACTEMENT.
// Usage : node mutate.js [filtre]     filtre = sous-chaine du nom de fichier de mutations (ex. "mode" ne lance que mode.js)
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const src = path.join(__dirname, '..', 'ShikiUI');
const suites = fs.readdirSync(__dirname).filter(f => /^t_.*.lua$/.test(f)).sort();
const filter = process.argv[2] || '';

const M = [];
for (const f of fs.readdirSync(path.join(__dirname, 'mutations')).filter(f => f.endsWith('.js')).sort()) {
  if (filter && f.indexOf(filter) < 0) continue;
  for (const m of require(path.join(__dirname, 'mutations', f))) M.push(m.concat([null, null]).slice(0, 5).concat([f]));
}

let survivors = 0;
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'suimut-'));
for (const [file, from, to, label, first, origin] of M) {
  const dir = path.join(tmp, 'ShikiUI');
  fs.rmSync(dir, { recursive: true, force: true });
  fs.cpSync(src, dir, { recursive: true });
  const fp = path.join(dir, file);
  if (!fs.existsSync(fp)) { console.log('?? fichier introuvable (' + file + ') : ' + label + '  [' + origin + ']'); survivors++; continue; }
  const text = fs.readFileSync(fp, 'utf8');
  if (!text.includes(from)) { console.log('?? motif introuvable (' + file + ') : ' + label + '  [' + origin + ']'); survivors++; continue; }
  fs.writeFileSync(fp, text.replace(from, () => to));
  let killedBy = null;
  const order = first && suites.includes(first) ? [first].concat(suites.filter(s => s !== first)) : suites;
  for (const s of order) {
    const r = spawnSync('node', [path.join(__dirname, 'harness.js'), path.join(__dirname, s)], { env: Object.assign({}, process.env, { ADDON_DIR: dir }), encoding: 'utf8' });
    if (r.status !== 0) { killedBy = s; break; }
  }
  console.log((killedBy ? 'tue    ' : 'SURVIT ') + '[' + file + '] ' + label + (killedBy ? '  (' + killedBy + ')' : ''));
  if (!killedBy) survivors++;
}
fs.rmSync(tmp, { recursive: true, force: true });
console.log(survivors ? survivors + ' mutant(s) survivant(s) sur ' + M.length : 'tous les mutants sont tues (' + M.length + ')');
process.exit(survivors ? 1 : 0);
