// gen_locale_style : (re)genere ShikiUI\Locale_Style.lua a partir des tables ci-dessous. Outil de depannage : le fichier genere est la source de verite.
const fs = require('fs');
const path = require('path');
const colors = [['bg', 'fond', 'background'], ['panel', 'panneau', 'panel'], ['inset', 'creux (barres, cases)', 'inset (bars, boxes)'], ['border', 'bordure', 'border'], ['text', 'texte', 'text'], ['dim', 'texte discret', 'dim text'], ['good', 'bon (vert)', 'good (green)'], ['warn', 'alerte (jaune)', 'warning (yellow)'], ['bad', 'mauvais (rouge)', 'bad (red)']];
const fr = {}, en = {};
function both(k, f, e) { fr[k] = f; en[k] = e; }
both('cat.style', 'Style et apparence', 'Style and look');
both('opt.style.name', 'Style', 'Style');
both('tip.style.name', "Choisis l'apparence generale (couleurs, polices, bordures, boutons). Le changement est immediat.", 'Pick the overall look (colors, fonts, borders, buttons). The change is immediate.');
both('opt.style.font', 'Police', 'Font');
both('tip.style.font', "Remplace la police du style. 'Celui du style' garde le choix du style.", "Overrides the style font. 'From the style' keeps the style's choice.");
both('opt.style.outline', 'Contour du texte', 'Text outline');
both('tip.style.outline', 'Contour des textes, utile sur les fonds clairs ou charges.', 'Text outline, useful on light or busy backgrounds.');
both('opt.style.fontscale', 'Taille des textes', 'Text size');
both('tip.style.fontscale', 'Multiplie la taille de tous les textes (1,00 = celle du style).', "Multiplies the size of every text (1.00 = the style's size).");
both('opt.style.bartex', 'Texture des barres', 'Bar texture');
both('tip.style.bartex', 'Aspect des barres de vie, de ressource et de progression.', 'Look of health, power and progress bars.');
both('opt.style.edge', 'Bordures et coins', 'Borders and corners');
both('tip.style.edge', 'Epaisseur et forme des bordures : fine, epaisse, arrondie ou cadre de dialogue.', 'Border thickness and shape: thin, thick, rounded or dialog frame.');
both('opt.style.panel', 'Fond des panneaux', 'Panel background');
both('tip.style.panel', 'Texture de fond des cadres : plate, infobulle ou dialogue.', 'Background texture of frames: flat, tooltip or dialog.');
both('opt.style.button', 'Boutons', 'Buttons');
both('tip.style.button', 'Boutons plats ou boutons classiques du jeu.', "Flat buttons or the game's classic buttons.");
both('opt.style.alpha', 'Opacite des fonds', 'Background opacity');
both('tip.style.alpha', "Multiplie l'opacite des fonds (1,00 = celle du style).", "Multiplies background opacity (1.00 = the style's value).");
for (const [k, f, e] of colors) {
  both('opt.style.c.' + k, 'Couleur : ' + f, 'Color: ' + e);
  both('tip.style.c.' + k, 'Code hexadecimal RRGGBB ou RRGGBBAA. Vide = couleur du style.', "Hexadecimal code RRGGBB or RRGGBBAA. Empty = the style's color.");
}
const ch = (k, v, f, e) => both('choice.style.' + k + '.' + v, f, e);
for (const k of ['font', 'outline', 'bartex', 'edge', 'panel', 'button']) ch(k, 'style', 'Celui du style', 'From the style');
ch('font', 'arial', 'Arial Narrow', 'Arial Narrow'); ch('font', 'frizqt', 'Friz Quadrata (jeu)', 'Friz Quadrata (game)');
ch('outline', 'none', 'Aucun', 'None'); ch('outline', 'outline', 'Contour', 'Outline'); ch('outline', 'thick', 'Contour epais', 'Thick outline');
ch('bartex', 'flat', 'Plate', 'Flat'); ch('bartex', 'blizzard', 'Degrade du jeu', 'Game gradient');
ch('edge', 'none', 'Aucune', 'None'); ch('edge', 'thin', 'Fine', 'Thin'); ch('edge', 'thick', 'Epaisse', 'Thick'); ch('edge', 'rounded', 'Arrondie', 'Rounded'); ch('edge', 'dialog', 'Cadre de dialogue', 'Dialog frame');
ch('panel', 'flat', 'Plat', 'Flat'); ch('panel', 'tooltip', 'Infobulle', 'Tooltip'); ch('panel', 'dialog', 'Dialogue', 'Dialog');
ch('button', 'flat', 'Plats', 'Flat'); ch('button', 'blizzard', 'Classiques du jeu', 'Game classic');
both('msg.style.badname', 'Nom de style invalide (2 a 24 lettres minuscules ou chiffres) : %s', 'Invalid style name (2 to 24 lowercase letters or digits): %s');
both('msg.style.exists', 'Un style porte deja ce nom.', 'A style already has this name.');
both('msg.style.added', 'Style ajoute.', 'Style added.');
both('msg.style.unknown', 'Style inconnu : %s', 'Unknown style: %s');
both('msg.style.builtin', 'Un style livre avec ShikiUI ne se supprime pas : %s', 'A style shipped with ShikiUI cannot be deleted: %s');
both('msg.style.deleted', 'Style supprime : %s', 'Style deleted: %s');
both('msg.style.full', 'Trop de styles personnels (24 maximum).', 'Too many personal styles (24 maximum).');
both('msg.style.line', '%s %s - %s %s', '%s %s - %s %s');
both('msg.style.user', '(personnel)', '(personal)');
both('msg.style.used', 'Style actif : %s', 'Active style: %s');
both('msg.style.saved', 'Style enregistre : %s. Les reglages individuels ont ete effaces (ils sont dans le style).', 'Style saved: %s. Individual settings were cleared (they are part of the style now).');
both('msg.style.reset', 'Reglages individuels de style effaces.', 'Individual style settings cleared.');
both('msg.style.imported', "Style importe : %s (%d champs, %d ignores). /sui style use %s pour l'activer.", 'Style imported: %s (%d fields, %d ignored). /sui style use %s to activate it.');
both('msg.style.asset.bad', 'Ressource invalide.', 'Invalid asset.');
both('msg.style.asset.exists', 'Une ressource porte deja ce nom.', 'An asset already has this name.');
both('msg.style.asset.added', 'Ressource ajoutee.', 'Asset added.');
both('msg.style.asset.missing', 'Ressource ajoutee, mais le fichier semble introuvable : repli automatique sur la ressource de base.', 'Asset added, but the file seems missing: falling back to the base asset.');
both('help.style', "/sui style [list | pick | use <id> | save <nom> | delete <id> | export [id] | import [chaine] | reset] - styles d'affichage", '/sui style [list | use <id> | save <name> | delete <id> | export [id] | import [string] | reset] - display styles');
both('mod.style.pick', 'Styles', 'Styles');
both('mod.style.title', 'Choisis un style', 'Pick a style');
both('mod.style.current', 'Style actuel : %s', 'Current style: %s');
both('mod.style.reset', 'Reinit.', 'Reset');
both('mod.style.edit', 'Personnaliser', 'Customize');
both('mod.style.sample', 'Exemple', 'Sample');
both('mod.style.import', 'Importer', 'Import');
both('mod.style.export', 'Exporter', 'Export');
both('mod.style.save', 'Enregistrer', 'Save');
both('mod.style.namehint', 'Nom du nouveau style...', 'New style name...');
both('mod.style.page', 'Page %d / %d', 'Page %d / %d');
both('mod.style.layouts', 'Mises en page', 'Layouts');
function block(lang, o) {
  return 'SUI.AddStrings("' + lang + '", {\n' + Object.keys(o).map(k => '\t["' + k + '"] = "' + o[k].replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '",').join('\n') + '\n})\n';
}
fs.writeFileSync(path.join(__dirname, '..', 'ShikiUI', 'Locale_Style.lua'),
  '-- ShikiUI Locale_Style : textes du moteur de styles (Style.lua). Ajoutes par SUI.AddStrings. (Le nom de chaque style est dans son Style_<Nom>.lua.)\nShikiUI = ShikiUI or {}\nlocal SUI = ShikiUI\n\n' + block('fr', fr) + '\n' + block('en', en));
console.log('Locale_Style.lua ecrit');
