// check_style : un module ne code JAMAIS en dur une couleur, une police ou une texture : tout vient des jetons du style (Theme.lua :
// T.c.*, T.Backdrop, T.Text, T.Bar, T.Panel, T.Button...), sinon il n'obeirait pas au choix du style, ni a l'accent, ni au changement a chaud.
// Verifie Mod_<Nom>.lua (et le modele docs\template\Mod_Template.lua). Les exceptions legitimes (couleur de classe, de ressource, de
// qualite d'objet : des donnees du JEU, pas du style) s'ecrivent avec un commentaire  -- style:ok <raison>  sur la MEME ligne.
//   node check_style.js            controle les fichiers
//   node check_style.js --selftest verifie que le controle detecte bien les fautes (appele par run_tests.sh)
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');

const RULES = [
  [/Set(Backdrop|Text|Vertex|StatusBar|Shadow)(Border)?Color\(\s*[-0-9.]/, 'couleur numerique en dur (utiliser T.c.<nom>, ou T.Accent())'],
  [/Set(Backdrop|Text|Vertex|StatusBar)(Border)?Color\(\s*\{/, 'couleur en table litterale (utiliser T.c.<nom>)'],
  [/SetFont\(\s*"/, 'police en dur (T.Text choisit la police du style)'],
  [/SetStatusBarTexture\(\s*"/, 'texture de barre en dur (T.Bar la prend dans le style)'],
  [/"Interface\\\\Buttons\\\\WHITE8X8"/, 'texture de fond en dur (T.Backdrop / T.Panel)'],
  [/"Interface\\\\Tooltips\\\\UI-Tooltip-(Border|Background)"/, 'bordure ou fond d\'infobulle en dur (T.Backdrop / T.Panel)'],
  [/"Interface\\\\DialogFrame\\\\/, 'cadre de dialogue en dur (T.Backdrop / T.Panel)'],
  [/"Fonts\\\\/, 'fichier de police en dur (T.Text)'],
  [/SetBackdrop\(\s*\{[^}]*(bgFile|edgeFile)/, 'SetBackdrop avec fichiers en dur (T.Backdrop)'],
];

function check(label, text) {
  const out = [];
  text.split(/\r?\n/).forEach((line, i) => {
    if (/^\s*--/.test(line) || /--\s*style:ok/.test(line)) return;
    const code = line.replace(/--.*$/, '');
    for (const [re, why] of RULES) if (re.test(code)) out.push(`${label}:${i + 1}: ${why}`);
  });
  return out;
}

if (process.argv.includes('--selftest')) {
  const bad = [
    'f:SetBackdropColor(0.1, 0.1, 0.1, 1)', 'fs:SetTextColor(1, 0, 0)', 'fs:SetFont("Fonts\\\\FRIZQT__.TTF", 12)',
    'b:SetStatusBarTexture("Interface\\\\TargetingFrame\\\\UI-StatusBar")', 'f:SetBackdrop({ bgFile = "Interface\\\\Buttons\\\\WHITE8X8" })',
    't:SetVertexColor({1,1,1})', 'x = "Interface\\\\Tooltips\\\\UI-Tooltip-Border"',
  ];
  const good = ['f:SetBackdropColor(T.c.bg[1], T.c.bg[2], T.c.bg[3], 1)', 'fs:SetTextColor(r, g, b, 1)', '-- fs:SetFont("x", 1)',
    'fs:SetTextColor(0, 1, 0, 1) -- style:ok vert = bon (donnee de jeu)', 'f:SetBackdrop(T.edgeSpec)'];
  let n = 0;
  for (const l of bad) if (!check('selftest', l).length) { console.log('  non detecte : ' + l); n++; }
  for (const l of good) if (check('selftest', l).length) { console.log('  faux positif : ' + l); n++; }
  console.log(n ? n + ' erreur(s) de l\'autocontrole' : 'AUTOCONTROLE OK (' + bad.length + ' fautes detectees, ' + good.length + ' cas valides acceptes)');
  process.exit(n ? 1 : 0);
}

const dir = path.join(root, 'ShikiUI');
const files = fs.readdirSync(dir).filter(f => /^Mod_.+\.lua$/.test(f)).map(f => path.join(dir, f));
const tpl = path.join(root, 'docs', 'template', 'Mod_Template.lua');
if (fs.existsSync(tpl)) files.push(tpl);
for (const f of ['Menu.lua', 'Menu_Pages.lua', 'Menu_Wizard.lua', 'Menu_Profiles.lua']) files.push(path.join(dir, f));   // le menu suit aussi les jetons du style
let problems = [];
for (const f of files) problems = problems.concat(check(path.relative(root, f), fs.readFileSync(f, 'latin1')));
for (const p of problems) console.log('  ' + p);
console.log(problems.length ? problems.length + ' couleur(s) / texture(s) en dur dans les modules' : 'MODULES SANS STYLE EN DUR (' + files.length + ' fichier(s))');
process.exit(problems.length ? 1 : 0);
