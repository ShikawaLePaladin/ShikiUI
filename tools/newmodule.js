// newmodule : cree un module ShikiUI a partir du modele docs\template\ (voir MODULES.md).
//   node tools/newmodule.js <Nom> [--order N] [--root <dossier>]
// <Nom> : une majuscule puis lettres / chiffres (Mod_<Nom>.lua, module "<nom en minuscules>"). L'ordre de la categorie du menu vient
// de la table "Modules reserves" de MODULES.md (une ligne  | nom | ordre | ... | ) ; --order pour un module hors de la table.
// Cree : ShikiUI\Mod_<Nom>.lua, ShikiUI\Locale_<Nom>.lua, tests\t_<nom>.lua, tests\mock_<nom>.lua, tests\mutations\<nom>.js ;
// puis regenere ShikiUI\ShikiUI.toc. Ne modifie AUCUN fichier existant et refuse d'ecraser quoi que ce soit.
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const args = process.argv.slice(2);
function opt(name) { const i = args.indexOf(name); if (i < 0) return null; const v = args[i + 1]; args.splice(i, 2); return v; }
const orderArg = opt('--order');
const rootArg = opt('--root');
const root = rootArg ? path.resolve(rootArg) : path.join(__dirname, '..');
const Name = args[0];
function die(msg) { console.log('newmodule : ' + msg); process.exit(1); }

if (!Name || !/^[A-Z][A-Za-z0-9]{1,23}$/.test(Name)) die('nom invalide (une majuscule puis lettres / chiffres, 2 a 24 caracteres) : ' + Name);
const name = Name.toLowerCase();
const core = fs.readFileSync(path.join(root, 'ShikiUI', 'Core.lua'), 'latin1');
const rm = core.match(/SUI\.reservedModules = \{([^}]*)\}/);
const reserved = rm ? (rm[1].match(/[a-z]+(?= = true)/g) || []) : [];
if (reserved.includes(name)) die(`"${name}" est un nom reserve par le socle (${reserved.join(', ')})`);

let order = orderArg ? parseInt(orderArg, 10) : null;
if (order === null) {
  const mdPath = path.join(root, 'MODULES.md');
  const md = fs.existsSync(mdPath) ? fs.readFileSync(mdPath, 'utf8') : '';
  const row = md.split(/\r?\n/).map(l => l.match(/^\|\s*`?([a-z0-9]+)`?\s*\|\s*(\d+)\s*\|/)).find(m => m && m[1] === name);
  if (row) order = parseInt(row[2], 10);
}
if (order === null || !(order >= 10 && order <= 999)) die(`ordre de categorie inconnu pour "${name}" : ajoute une ligne a la table de MODULES.md ou passe --order N (10 a 999)`);

// l'ordre ne doit pas deja etre pris par un autre module
const taken = [];
for (const f of fs.readdirSync(path.join(root, 'ShikiUI')).filter(f => f.endsWith('.lua'))) {
  const t = fs.readFileSync(path.join(root, 'ShikiUI', f), 'latin1');
  let m; const re = /SUI\.RegisterCategory\("([a-z0-9]+)", (\d+)\)/g;
  while ((m = re.exec(t))) taken.push([m[1], parseInt(m[2], 10), f]);
}
const clash = taken.find(t => t[1] === order && t[0] !== name);
if (clash) die(`l'ordre ${order} est deja pris par la categorie "${clash[0]}" (${clash[2]})`);

const T = path.join(root, 'docs', 'template');
const plan = [
  ['Mod_Template.lua', path.join('ShikiUI', `Mod_${Name}.lua`)],
  ['Locale_Template.lua', path.join('ShikiUI', `Locale_${Name}.lua`)],
  ['t_template.lua', path.join('tests', `t_${name}.lua`)],
  ['mock_template.lua', path.join('tests', `mock_${name}.lua`)],
  ['mutation_template.js', path.join('tests', 'mutations', `${name}.js`)],
];
for (const [, dst] of plan) if (fs.existsSync(path.join(root, dst))) die('existe deja, rien n\'est ecrase : ' + dst);
fs.mkdirSync(path.join(root, 'tests', 'mutations'), { recursive: true });
for (const [srcName, dst] of plan) {
  let text = fs.readFileSync(path.join(T, srcName), 'utf8');
  text = text.replace(/SUI\.RegisterCategory\("template", \d+\)/, `SUI.RegisterCategory("template", ${order})`);
  text = text.replace(/TEMPLATE/g, Name.toUpperCase()).replace(/Template/g, Name).replace(/template/g, name);
  fs.writeFileSync(path.join(root, dst), text);
  console.log('  cree ' + dst);
}
const r = spawnSync('node', [path.join(__dirname, 'gen_toc.js'), '--root', root], { encoding: 'utf8' });
process.stdout.write(r.stdout || '');
if (r.status !== 0) die('gen_toc a echoue');
console.log(`module "${name}" cree (categorie ${order}). Etape suivante : sh tests/run_tests.sh t_${name}.lua`);
