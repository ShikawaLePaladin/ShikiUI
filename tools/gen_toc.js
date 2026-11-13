// gen_toc : genere ShikiUI/ShikiUI.toc. Le .toc n'est JAMAIS edite a la main (il est derive des fichiers presents).
//   node tools/gen_toc.js            ecrit le .toc
//   node tools/gen_toc.js --check    echoue si le .toc sur disque differe de ce qui serait genere (utilise par run_tests.sh)
//   --root <dossier>                 racine du projet (par defaut : le dossier au-dessus de tools/)
// Ordre : fichiers du socle (liste CORE ci-dessous), puis un bloc "modules" : pour chaque Mod_<Nom>.lua, par ordre alphabetique,
// Locale_<Nom>.lua puis Mod_<Nom>.lua. Un module ne doit donc JAMAIS dependre de l'ordre de chargement d'un autre module.
// Regles verifiees ici : chaque Mod_<Nom>.lua a son Locale_<Nom>.lua et inversement (hors socle) ; nom = lettre majuscule puis
// lettres / chiffres ; aucun autre .lua dans ShikiUI\ (fichier oublie = erreur, pas un addon qui "marche chez moi").
const fs = require('fs');
const path = require('path');

const CORE = ['Core.lua', 'Locale.lua', 'Locale_Mode.lua', 'Locale_Target.lua', 'Locale_Style.lua', 'Locale_Layout.lua', 'Locale_Menu.lua', 'Locale_Setup.lua', 'Locale_Preview.lua', 'Locale_Mover.lua', 'Locale_Bind.lua', 'Locale_Addons.lua', 'Locale_Visibility.lua', 'Serial.lua',
  'Api.lua', 'Config.lua', 'Backup.lua', 'Migrate.lua', 'Mode.lua', 'Theme.lua', 'Visibility.lua', 'Style.lua', 'Style_Shiki.lua', 'Layouts.lua', 'Mover.lua', 'Bind.lua', 'Perf.lua', 'Units.lua',
  'Target.lua', 'Menu.lua', 'Menu_Pages.lua', 'Menu_Preview.lua', 'Preview_Raid.lua', 'Preview_Layout.lua', 'Preview_Basic.lua', 'Menu_Wizard.lua', 'Menu_Profiles.lua', 'Addons.lua', 'StyleUI.lua', 'Cmd.lua', 'GameMenu.lua'];

const args = process.argv.slice(2);
const check = args.includes('--check');
const ri = args.indexOf('--root');
const root = ri >= 0 ? path.resolve(args[ri + 1]) : path.join(__dirname, '..');
const dir = path.join(root, 'ShikiUI');

function build() {
  const errors = [];
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.lua'));
  const mods = [], locs = [];
  const styles = [];
  for (const f of files) {
    let m = f.match(/^Mod_(.+)\.lua$/);
    if (m) { mods.push(m[1]); continue; }
    m = f.match(/^Style_(.+)\.lua$/);
    if (m && !CORE.includes(f)) {
      if (!/^[A-Z][A-Za-z0-9]{1,23}$/.test(m[1])) errors.push(`nom de style invalide : ${f} (A-Z puis lettres / chiffres)`);
      styles.push(f);
      continue;
    }
    m = f.match(/^Locale_(.+)\.lua$/);
    if (m && !CORE.includes(f)) { locs.push(m[1]); continue; }
    if (!CORE.includes(f)) errors.push(`fichier inconnu dans ShikiUI\ : ${f} (un module s'appelle Mod_<Nom>.lua)`);
  }
  for (const c of CORE) if (!files.includes(c)) errors.push(`fichier du socle manquant : ${c}`);
  for (const n of mods) {
    if (!/^[A-Z][A-Za-z0-9]{1,23}$/.test(n)) errors.push(`nom de module invalide : Mod_${n}.lua (A-Z puis lettres / chiffres)`);
    if (!locs.includes(n)) errors.push(`Mod_${n}.lua sans Locale_${n}.lua`);
  }
  for (const n of locs) if (!mods.includes(n)) errors.push(`Locale_${n}.lua sans Mod_${n}.lua`);
  const lowers = mods.map(n => n.toLowerCase());
  lowers.forEach((n, i) => { if (lowers.indexOf(n) !== i) errors.push(`deux modules de meme nom (casse ignoree) : ${n}`); });
  mods.sort((a, b) => (a.toLowerCase() < b.toLowerCase() ? -1 : 1));
  styles.sort((a, b) => (a.toLowerCase() < b.toLowerCase() ? -1 : 1));

  const core = fs.readFileSync(path.join(dir, 'Core.lua'), 'latin1');
  const vm = core.match(/SUI\.VERSION = "([0-9.]+)"/);
  if (!vm) errors.push('SUI.VERSION introuvable dans Core.lua');
  const version = vm ? vm[1] : '0.0.0';
  const notes = "Interface sombre et minimaliste, moteur leger (un seul timer, un seul routeur d'evenements), menu Simple / Expert, modes Normal / Raid. Exploite SuperWoW, Nampower, UnitXP et ClassicAPI quand ils sont presents. /sui";
  const out = [
    '## Interface: 11200',
    '## Title: |cff4dc4e8Shiki|r|cffffffffUI|r',
    '## Title-frFR: |cff4dc4e8Shiki|r|cffffffffUI|r',
    '## Notes: ' + notes,
    '## Notes-frFR: ' + notes,
    '## Author: Shikiwa',
    '## Version: ' + version,
    '## SavedVariables: ShikiUIDB',
    '',
    '# -- socle (liste fixe : tools/gen_toc.js)',
    ...CORE,
    '',
    '# -- styles supplementaires (generes : Style_<Nom>.lua, ordre alphabetique ; ajouter un style = ajouter un fichier)',
    ...styles,
    '',
    '# -- modules (generes : Locale_<Nom>.lua puis Mod_<Nom>.lua, ordre alphabetique ; ne pas editer ce fichier)',
  ];
  for (const n of mods) { out.push(`Locale_${n}.lua`); out.push(`Mod_${n}.lua`); }
  return { text: out.join('\n') + '\n', errors, mods, styles };
}

const r = build();
if (r.errors.length) {
  for (const e of r.errors) console.log('  ' + e);
  console.log(`${r.errors.length} probleme(s) de structure`);
  process.exit(1);
}
const file = path.join(dir, 'ShikiUI.toc');
if (check) {
  const cur = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  if (cur !== r.text) {
    console.log('  ShikiUI.toc n\'est pas a jour : lance node tools/gen_toc.js');
    process.exit(1);
  }
  console.log(`toc a jour (${r.mods.length} module(s))`);
} else {
  fs.writeFileSync(file, r.text);
  console.log(`ShikiUI.toc ecrit (${r.mods.length} module(s))`);
}
