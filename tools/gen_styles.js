// gen_styles : ecrit les fichiers ShikiUI\Style_<Nom>.lua des styles livres (donnees pures + deux textes par langue).
// Outil de depannage : une fois ecrits, les fichiers Style_*.lua sont la source de verite (on peut les editer a la main).
const fs = require('fs');
const path = require('path');
const dir = path.join(__dirname, '..', 'ShikiUI');

const STYLES = [
  { id: 'shiki', file: 'Shiki',
    c: { bg: '111214F2', panel: '181A1DF2', inset: '0C0C0EFF', border: '33363DFF', text: 'E6E8EDFF', dim: '9499A6FF', good: '5CCC78FF', warn: 'F2C242FF', bad: 'E85454FF' },
    rest: { accent: 'blue', font: 'arial', outline: 'none', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 1 },
    fr: ['Shiki', "Le style d'origine : sombre, minimaliste, bordures fines, accent bleu."],
    en: ['Shiki', 'The original style: dark, minimal, thin borders, blue accent.'] },
  { id: 'pfstyle', file: 'Pfstyle',
    c: { bg: '161616E6', panel: '1E1E1EE6', inset: '0A0A0AFF', border: '000000FF', text: 'FFFFFFFF', dim: 'AAAAAAFF', good: '33FF66FF', warn: 'FFD633FF', bad: 'FF4D4DFF' },
    rest: { accent: 'blue', font: 'arial', outline: 'outline', fontScale: 1, bar: 'blizzard', panel: 'flat', edge: 'thin', button: 'flat', alpha: 0.9 },
    fr: ['pfStyle', 'Dans l\'esprit des interfaces "tout-en-un" : fonds gris sombre translucides, bordure noire, barres en degrade, texte contourne.'],
    en: ['pfStyle', 'In the spirit of all-in-one interfaces: translucent dark grey panels, black border, gradient bars, outlined text.'] },
  { id: 'elvstyle', file: 'Elvstyle',
    c: { bg: '141414FF', panel: '1B1B1BFF', inset: '0A0A0AFF', border: '000000FF', text: 'E0E0E0FF', dim: '8A8A8AFF', good: '4CCC66FF', warn: 'E6B800FF', bad: 'E64D4DFF' },
    rest: { accent: 'class', font: 'arial', outline: 'none', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 1 },
    fr: ['ElvStyle', "Dans l'esprit des interfaces plates et nettes : gris charbon opaque, bordure noire d'un pixel, barres plates, accent a la couleur de ta classe."],
    en: ['ElvStyle', 'In the spirit of flat, crisp interfaces: opaque charcoal grey, one-pixel black border, flat bars, accent in your class color.'] },
  { id: 'blizzard', file: 'Blizzard',
    c: { bg: '1A1A30F0', panel: '262640F0', inset: '000000CC', border: 'CCCCCCFF', text: 'FFFFFFFF', dim: '9D9D9DFF', good: '1EFF00FF', warn: 'FFD100FF', bad: 'FF2020FF' },
    rest: { accent: 'FFD100', font: 'frizqt', outline: 'none', fontScale: 1, bar: 'blizzard', panel: 'tooltip', edge: 'rounded', button: 'blizzard', alpha: 1 },
    fr: ['Blizzard classique', "Le look d'origine du jeu : infobulles a bordure arrondie, police du jeu, boutons classiques, accent or."],
    en: ['Blizzard classic', "The game's original look: rounded-border tooltips, the game font, classic buttons, gold accent."] },
  { id: 'light', file: 'Light',
    c: { bg: 'F2F2F2F2', panel: 'FFFFFFF2', inset: 'DCDCDCFF', border: 'B0B0B0FF', text: '1E1E1EFF', dim: '5E5E5EFF', good: '2E9E4EFF', warn: 'B87800FF', bad: 'C93030FF' },
    rest: { accent: 'blue', font: 'arial', outline: 'none', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 1 },
    fr: ['Clair', 'Minimal clair : fonds blancs, texte sombre, bordures grises.'],
    en: ['Light', 'Minimal light: white panels, dark text, grey borders.'] },
  { id: 'tactical', file: 'Tactical',
    c: { bg: '0C100CF0', panel: '121812F0', inset: '070A07FF', border: '3A4A33FF', text: 'C8D8B8FF', dim: '7C8C70FF', good: '66CC55FF', warn: 'D9B833FF', bad: 'D95040FF' },
    rest: { accent: 'green', font: 'arial', outline: 'outline', fontScale: 0.9, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 0.95 },
    fr: ['Tactique', 'Compact et sobre : fonds vert-noir, texte reduit et contourne, accent vert.'],
    en: ['Tactical', 'Compact and sober: green-black panels, smaller outlined text, green accent.'] },

  { id: 'opale', file: 'Opale',
    c: { bg: '1C2230A0', panel: '262E3E9E', inset: '10141C99', border: '8FA8C8AA', text: 'F0F4FAFF', dim: 'A9B6C8FF', good: '6FD6A0FF', warn: 'F2D06BFF', bad: 'F27B7BFF' },
    rest: { accent: 'blue', font: 'arial', outline: 'outline', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 0.7 },
    fr: ['Opale', 'Fonds translucides bleu-gris (on voit le jeu a travers), bordure claire, texte contourne.'],
    en: ['Opal', 'Translucent blue-grey panels (the game shows through), light border, outlined text.'] },
  { id: 'minuit', file: 'Minuit',
    c: { bg: '0A0E1AF2', panel: '10162AF2', inset: '060912FF', border: '26325AFF', text: 'DCE6FFFF', dim: '7C8AB0FF', good: '4CD6A0FF', warn: 'F0C050FF', bad: 'F06070FF' },
    rest: { accent: 'blue', font: 'arial', outline: 'none', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 1 },
    fr: ['Minuit', 'Bleu nuit profond, bordures discretes, accent bleu clair.'],
    en: ['Midnight', 'Deep midnight blue, subtle borders, light blue accent.'] },
  { id: 'foret', file: 'Foret',
    c: { bg: '0C1410F0', panel: '121E17F0', inset: '080E0BFF', border: '2E4A38FF', text: 'DCEBDDFF', dim: '88A08CFF', good: '6FDC7FFF', warn: 'DDBB44FF', bad: 'DD5A48FF' },
    rest: { accent: 'green', font: 'arial', outline: 'none', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 1 },
    fr: ['Foret', 'Vert sombre naturel, accent vert, texte doux.'],
    en: ['Forest', 'Natural dark green, green accent, soft text.'] },
  { id: 'braise', file: 'Braise',
    c: { bg: '160D0AF0', panel: '22130EF0', inset: '0C0605FF', border: '5A2C1CFF', text: 'F4E4D8FF', dim: 'A88A7AFF', good: '7CCB66FF', warn: 'F5B040FF', bad: 'F05A44FF' },
    rest: { accent: 'orange', font: 'arial', outline: 'none', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 1 },
    fr: ['Braise', 'Brun-rouge chaud, accent orange.'],
    en: ['Ember', 'Warm red-brown, orange accent.'] },
  { id: 'glace', file: 'Glace',
    c: { bg: 'E4F0F8CC', panel: 'F2F8FCD9', inset: 'C4D8E6E6', border: '7FA6C2FF', text: '12283CFF', dim: '4C6A82FF', good: '1E9E6AFF', warn: 'B27A10FF', bad: 'C23A3AFF' },
    rest: { accent: 'blue', font: 'arial', outline: 'none', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 0.85 },
    fr: ['Glace', 'Clair bleute semi-transparent, texte bleu marine.'],
    en: ['Ice', 'Light translucent blue, navy text.'] },
  { id: 'graphite', file: 'Graphite',
    c: { bg: '1E1E20F0', panel: '28282BF0', inset: '141415FF', border: '48484DFF', text: 'EAEAEAFF', dim: '939399FF', good: '58C878FF', warn: 'E8B84AFF', bad: 'E5584CFF' },
    rest: { accent: 'class', font: 'arial', outline: 'none', fontScale: 1, bar: 'flat', panel: 'flat', edge: 'thin', button: 'flat', alpha: 1 },
    fr: ['Graphite', 'Gris neutre, accent a la couleur de ta classe.'],
    en: ['Graphite', 'Neutral grey, accent in your class color.'] },
];

for (const s of STYLES) {
  const q = (t) => '"' + t.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
  const cl = Object.keys(s.c).map(k => `${k} = "${s.c[k]}"`).join(', ');
  const r = s.rest;
  const text = `-- Style_${s.file} : style "${s.fr[0]}" (donnees pures : voir Style.lua). Conception originale ; aucune texture ni police tierce, seulement des
-- ressources du jeu designees par leur nom (voir Theme.lua). Aucun code copie d'un autre addon.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.RegisterStyle("${s.id}", {
	label = "style.${s.id}.label", desc = "style.${s.id}.desc",
	c = { ${cl} },
	accent = ${q(String(r.accent))}, font = "${r.font}", outline = "${r.outline}", fontScale = ${r.fontScale}, bar = "${r.bar}",
	panel = "${r.panel}", edge = "${r.edge}", button = "${r.button}", alpha = ${r.alpha},
})

SUI.AddStrings("fr", {
	["style.${s.id}.label"] = ${q(s.fr[0])},
	["style.${s.id}.desc"] = ${q(s.fr[1])},
})

SUI.AddStrings("en", {
	["style.${s.id}.label"] = ${q(s.en[0])},
	["style.${s.id}.desc"] = ${q(s.en[1])},
})
`;
  const target = path.join(dir, `Style_${s.file}.lua`);
  if (fs.existsSync(target) && process.argv[2] !== '--force') continue;   // les fichiers existants font foi (editables a la main)
  fs.writeFileSync(target, text);
  console.log('Style_' + s.file + '.lua');
}
