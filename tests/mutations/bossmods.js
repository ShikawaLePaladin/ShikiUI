// Mutations du module "bossmods" (alarmes de raid). Format : [fichier, motif, remplacement, libelle, suite].
const F = 'Mod_BossMods.lua', S = 't_bossmods.lua';
module.exports = [
  [F, 'cost = "medium",', 'cost = "light",', 'bossmods : cout declare modifie', S],
  [F, '			M.Announce(ev.name, floor(nxt - now + 0.5))', '', 'bossmods : annonce jamais envoyee', S],
  [F, 'M.combatAt = now', '', 'bossmods : t0 de combat jamais pose', S],
  [F, 'if not M.combatAt and inCombat() then', 'if false then', 'bossmods : t0 jamais lu en combat', S],
  [F, 'M.next[ev] = nxt + (ev.every or 3600)', '', 'bossmods : repetition perdue', S],
  [F, '\t\tif M.cur then', '\t\tif false then', 'bossmods : boss precedant jamais oublie', S],
  [F, 'M.curLabel = M.BOSSES[key].label or nm', 'M.curLabel = nm', 'bossmods : label du boss ignore', S],
  [F, '\tif M.task then\n\t\tSUI.Cancel(M.task)\n\t\tM.task = nil\n\tend', '', 'bossmods : minuterie non annulee a la coupure', S],
  [F, '		key = fold(nm)', '		key = "inconnu"', 'bossmods : nom du boss jamais reconnu', S],
  [F, 'local lead = C.Get("bossmods.lead") or 10', 'local lead = 0', 'bossmods : pre-annonce ignoree', S],
];
