// check_template : le modele de module doit rester VIVANT. On copie le projet dans un dossier temporaire, on y cree un module de
// demonstration "Demo" avec tools/newmodule.js, puis on lance dans cette copie la chaine complete (structure, lint, traductions, toutes
// les suites dont t_demo.lua, mutations du module). Si un changement du socle casse le modele, c'est ici que ca se voit.
// Refus attendus verifies aussi : nom reserve, nom invalide, ecrasement.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const root = path.join(__dirname, '..');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'suitpl-'));
let bad = 0;
const fail = (s) => { console.log('  ' + s); bad++; };
function sh(cmd, args, opts) {
  return spawnSync(cmd, args, Object.assign({ encoding: 'utf8', maxBuffer: 256 * 1024 * 1024, env: Object.assign({}, process.env, { SUI_INNER: '1' }) }, opts || {}));
}
try {
  for (const d of ['ShikiUI', 'tests', 'tools', 'docs']) fs.cpSync(path.join(root, d), path.join(tmp, d), { recursive: true });
  for (const f of ['MODULES.md']) if (fs.existsSync(path.join(root, f))) fs.copyFileSync(path.join(root, f), path.join(tmp, f));

  const nm = path.join(tmp, 'tools', 'newmodule.js');
  let r = sh('node', [nm, 'Msg', '--order', '98', '--root', tmp]);
  if (r.status === 0) fail('un nom reserve (msg) aurait du etre refuse');
  r = sh('node', [nm, 'bad name', '--order', '98', '--root', tmp]);
  if (r.status === 0) fail('un nom invalide aurait du etre refuse');
  r = sh('node', [nm, 'Demo', '--root', tmp]);
  if (r.status === 0) fail('un ordre de categorie inconnu aurait du etre refuse');
  r = sh('node', [nm, 'Demo', '--order', '3', '--root', tmp]);
  if (r.status === 0) fail('un ordre de categorie deja pris (3 = perf) aurait du etre refuse');
  r = sh('node', [nm, 'Demo', '--order', '98', '--root', tmp]);
  if (r.status !== 0) { fail('creation de Demo echouee : ' + r.stdout + r.stderr); }
  else {
    r = sh('node', [nm, 'Demo', '--order', '98', '--root', tmp]);
    if (r.status === 0) fail('recreer Demo aurait du etre refuse (pas d\'ecrasement)');
    const run = sh('sh', [path.join(tmp, 'tests', 'run_tests.sh')], { cwd: path.join(tmp, 'tests') });
    const out = (run.stdout || '') + (run.stderr || '');
    if (run.status !== 0 || !/TOUT EST VERT/.test(out)) fail('la chaine de tests echoue sur le module Demo :\n' + out.split('\n').filter(l => /FAIL|ERROR|echec|ECHEC|probleme|cle |manque/.test(l)).slice(0, 20).join('\n'));
    if (!/== t_demo\.lua ==/.test(out)) fail('t_demo.lua n\'a pas ete lancee');
    const mu = sh('node', [path.join(tmp, 'tests', 'mutate.js'), 'demo'], { cwd: path.join(tmp, 'tests') });
    const mout = (mu.stdout || '') + (mu.stderr || '');
    if (mu.status !== 0 || !/tous les mutants sont tues \(6\)/.test(mout)) fail('mutations du module Demo : ' + mout.split('\n').slice(-12).join('\n'));
  }
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
console.log(bad ? `${bad} probleme(s) avec le modele de module` : 'MODELE DE MODULE OK (Demo cree, teste, mute, puis supprime)');
process.exit(bad ? 1 : 0);
