// gen_locale_skin : genere ShikiUI/Locale_Skin.lua (textes fr / en du module skin) depuis les tables ci-dessous.
//   node tools/gen_locale_skin.js
const fs = require('fs');
const path = require('path');
const G = [
  ['menu', 'Menu Echap', 'Main menu (Esc)', 'Menu Echap et ses boutons.', 'The Esc menu and its buttons.'],
  ['options', 'Options (video, son, interface)', 'Options (video, sound, interface)', "Fenetres d'options du jeu : cases, curseurs, listes.", 'Game option windows: checkboxes, sliders, lists.'],
  ['addons', 'Liste des AddOns', 'AddOn list', 'Liste des addons (noms de cadres supposes, non verifies).', 'AddOn list (frame names assumed, unverified).'],
  ['keybind', 'Raccourcis clavier', 'Key bindings', 'Fenetre des raccourcis (chargee a la demande).', 'Key bindings window (load on demand).'],
  ['macro', 'Macros', 'Macros', "Fenetre des macros et sa fenetre de choix d'icone.", 'Macro window and its icon picker.'],
  ['character', 'Personnage', 'Character', 'Cadre du personnage : equipement, onglets, reputation, competences, honneur.', 'Character frame: equipment, tabs, reputation, skills, honor.'],
  ['spellbook', 'Livre de sorts', 'Spellbook', 'Livre de sorts et ses onglets (les icones restent visibles).', 'Spellbook and its tabs (icons stay visible).'],
  ['talents', 'Talents', 'Talents', 'Fenetre des talents (chargee a la demande).', 'Talent window (load on demand).'],
  ['questlog', 'Journal de quetes', 'Quest log', 'Journal de quetes. Le parchemin est garde sauf reglage Parchemin sombre.', 'Quest log. The parchment is kept unless Parchment is set to dark.'],
  ['npc', 'Dialogues PNJ et quetes', 'NPC and quest dialogs', 'Dialogues de PNJ et de quetes (parchemin garde par defaut).', 'NPC and quest dialogs (parchment kept by default).'],
  ['merchant', 'Marchand', 'Merchant', 'Fenetre du marchand et de rachat.', 'Merchant and buyback window.'],
  ['trade', 'Echange', 'Trade', "Fenetre d'echange entre joueurs.", 'Player trade window.'],
  ['trainer', 'Entraineur', 'Trainer', "Fenetre de l'entraineur de classe (chargee a la demande).", 'Class trainer window (load on demand).'],
  ['professions', 'Metiers', 'Professions', "Fenetres des metiers et de l'artisanat (chargees a la demande).", 'Trade skill and craft windows (load on demand).'],
  ['social', 'Amis, Qui, Guilde, Raid', 'Friends, Who, Guild, Raid', 'Cadre social et ses fenetres annexes.', 'Social frame and its pop-up windows.'],
  ['inspect', 'Inspection', 'Inspect', "Fenetre d'inspection d'un joueur (chargee a la demande).", 'Player inspect window (load on demand).'],
  ['dressup', "Cabine d'essayage", 'Dressing room', "Cabine d'essayage (le modele 3D n'est jamais touche).", 'Dressing room (the 3D model is never touched).'],
  ['stable', 'Ecurie', 'Pet stable', 'Fenetre de l\'ecurie des familiers.', 'Pet stable window.'],
  ['taxi', 'Maitre de vol', 'Flight master', 'Carte des vols : seulement le bouton de fermeture (la carte reste intacte).', 'Flight map: only the close button (the map is untouched).'],
  ['auction', 'Hotel des ventes', 'Auction house', "Chrome de l'hotel des ventes (le module Hotel des ventes ajoute son propre panneau).", 'Auction house chrome (the Auction module adds its own panel).'],
  ['mail', 'Courrier', 'Mail', 'Boite aux lettres et lecture du courrier.', 'Mailbox and mail reading.'],
  ['bank', 'Banque', 'Bank', 'Fenetre de la banque.', 'Bank window.'],
  ['loot', 'Butin', 'Loot', 'Fenetre de butin (cede la place au module de butin de pfUI).', 'Loot window (yields to the pfUI loot module).'],
  ['pvp', 'Champs de bataille', 'Battlegrounds', 'Inscription et tableau des scores.', 'Queue and scoreboard.'],
  ['lfg', 'Recherche de groupe', 'Looking for group', 'Fenetres de recherche de groupe de Turtle WoW (noms supposes).', 'Turtle WoW group finder windows (assumed names).'],
  ['worldmap', 'Carte du monde', 'World map', 'Seulement les controles de la carte, jamais les tuiles.', 'Only the map controls, never the tiles.'],
  ['books', 'Livres et lettres', 'Books and letters', 'Livres et lettres a lire.', 'Readable books and letters.'],
  ['popups', 'Fenetres de confirmation', 'Pop-up dialogs', "Fenetres de confirmation, division de pile, selecteur de couleur, appel de joueur.", 'Confirmation pop-ups, stack split, color picker, ready check.'],
  ['chatmenu', 'Menus du chat', 'Chat menus', 'Menus deroulants du chat (canaux, emotes, langues).', 'Chat drop-down menus (channels, emotes, languages).'],
  ['dropdowns', 'Listes deroulantes', 'Drop-down lists', 'Listes deroulantes du jeu (niveaux 1 a 3).', 'Game drop-down lists (levels 1 to 3).'],
  ['tooltips', 'Infobulles annexes', 'Extra tooltips', 'Infobulles de lien, de comparaison et de carte ; GameTooltip si le module Infobulles est coupe.', 'Link, comparison and map tooltips; GameTooltip when the Tooltip module is off.'],
  ['misc', 'Aide, petitions, tabard', 'Help, petitions, tabard', "Fenetre d'aide, petitions de guilde, tabard, enquete.", 'Help window, guild petitions, tabard, survey.'],
];
const O = [
  ['contrast', 'Contraste', 'Contrast', "Discret : fonds plus transparents et bordure estompee ; Fort : fonds opaques et bordure a la couleur d'accent.", 'Soft: more transparent panels and a faded border; High: opaque panels and an accent-colored border.'],
  ['alpha', 'Opacite du fond', 'Background opacity', 'Opacite des fenetres habillees (multipliee par celle du style).', 'Opacity of skinned windows (multiplied by the style opacity).'],
  ['tint', "Teinte d'accent", 'Accent tint', "Applique la couleur d'accent a la bordure et / ou au titre des fenetres.", 'Applies the accent color to the border and / or the title of windows.'],
  ['border', 'Bordure', 'Border', 'Epaisseur de la bordure des fenetres : celle du style, aucune, fine ou epaisse.', 'Window border thickness: the style one, none, thin or thick.'],
  ['corners', 'Coins', 'Corners', 'Coins carres ou arrondis (ou ceux du style).', 'Square or rounded corners (or the style ones).'],
  ['font', 'Police', 'Font', 'Quelle police du style appliquer : aucune, etiquettes (boutons, onglets, titres) ou tout le texte (experimental).', 'Which style font to apply: none, labels (buttons, tabs, titles) or all text (experimental).'],
  ['fontscale', 'Taille de police', 'Font size', 'Echelle de la police des textes habilles.', 'Scale of the skinned text font.'],
  ['art', 'Masquer le decor Blizzard', 'Hide Blizzard artwork', 'Rend transparent le decor des fenetres ; decoche : seuls les controles sont habilles.', 'Makes window artwork transparent; unchecked: only controls are skinned.'],
  ['parchment', 'Parchemin', 'Parchment', 'Parchemin des quetes et des livres : garde (texte lisible) ou sombre (fond du style, texte recolore).', 'Quest and book parchment: kept (readable text) or dark (style panel, recolored text).'],
  ['yield', 'Ceder la place a pfUI', 'Yield to pfUI', 'Ne rien habiller de ce que pfUI habille deja (sa skin equivalente tourne).', 'Skin nothing that pfUI already skins (its matching skin is running).'],
];
const C = [['soft', 'Discret', 'Soft'], ['normal', 'Normal', 'Normal'], ['high', 'Fort', 'High'], ['off', 'Aucune', 'None'], ['border', 'Bordure', 'Border'],
  ['title', 'Titre', 'Title'], ['both', 'Les deux', 'Both'], ['style', 'Du style', 'From style'], ['none', 'Aucune', 'None'], ['thin', 'Fine', 'Thin'],
  ['thick', 'Epaisse', 'Thick'], ['square', 'Carres', 'Square'], ['round', 'Arrondis', 'Rounded'], ['labels', 'Etiquettes', 'Labels'],
  ['all', 'Tout', 'All'], ['keep', 'Garde', 'Kept'], ['dark', 'Sombre', 'Dark']];
const CH = { contrast: ['soft', 'normal', 'high'], tint: ['off', 'border', 'title', 'both'], border: ['style', 'none', 'thin', 'thick'],
  corners: ['style', 'square', 'round'], font: ['off', 'labels', 'all'], parchment: ['keep', 'dark'] };
const q = (s) => '"' + s.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
function block(lang) {
  const i = lang === 'fr' ? 0 : 1;
  const fr = lang === 'fr';
  const out = [];
  const add = (k, v) => out.push('\t[' + q(k) + '] = ' + q(v) + ',');
  add('cat.skin', fr ? 'Habillage' : 'Skin');
  add('opt.modules.skin', fr ? 'Habillage des fenetres Blizzard' : 'Blizzard window skin');
  add('tip.modules.skin', fr
    ? "Habille les fenetres du jeu (menu, options, personnage, sorts, marchand, popups...) au style ShikiUI : fond, bordure, boutons, onglets, listes. Cede la place a pfUI pour ce qu'il habille deja. Non verifie en jeu."
    : 'Skins game windows (menu, options, character, spells, merchant, pop-ups...) with the ShikiUI style: panel, border, buttons, tabs, lists. Yields to pfUI for what it already skins. Unverified in game.');
  add('mod.skin.hdr.look', fr ? 'Apparence' : 'Look');
  add('mod.skin.hdr.rules', fr ? 'Regles' : 'Rules');
  add('mod.skin.hdr.frames', fr ? 'Fenetres habillees' : 'Skinned windows');
  for (const o of O) { add('opt.skin.' + o[0], o[1 + i]); add('tip.skin.' + o[0], o[3 + i]); }
  for (const g of G) { add('opt.skin.f.' + g[0], g[1 + i]); add('tip.skin.f.' + g[0], g[3 + i]); }
  for (const k of Object.keys(CH)) for (const v of CH[k]) add('choice.skin.' + k + '.' + v, C.find((x) => x[0] === v)[1 + i]);
  add('msg.skin.head', fr ? 'Habillage : %d groupe(s) actif(s), %d cadre(s) habille(s).' : 'Skin: %d active group(s), %d skinned frame(s).');
  add('msg.skin.line', fr ? '  %s : %s (%d/%d cadres)' : '  %s: %s (%d/%d frames)');
  add('msg.skin.state.on', fr ? 'actif' : 'active');
  add('msg.skin.state.off', fr ? 'coupe' : 'off');
  add('msg.skin.state.pfui', fr ? 'laisse a pfUI' : 'left to pfUI');
  add('msg.skin.state.wait', fr ? 'en attente du cadre' : 'waiting for the frame');
  add('help.skin', fr ? "/sui skin [refresh] - etat de l'habillage des fenetres Blizzard" : '/sui skin [refresh] - Blizzard window skin status');
  return 'SUI.AddStrings("' + lang + '", {\n' + out.join('\n') + '\n})\n';
}
const head = '-- Locale_Skin : textes du module "skin" (francais sans accents, anglais). Genere par tools/gen_locale_skin.js ; une entree par ligne.\n' +
  '-- Memes cles et memes %s / %d dans les deux langues (controle par tests/check_locale.js).\nShikiUI = ShikiUI or {}\nlocal SUI = ShikiUI\n\n';
fs.writeFileSync(path.join(__dirname, '..', 'ShikiUI', 'Locale_Skin.lua'), head + block('fr') + '\n' + block('en'), 'latin1');
