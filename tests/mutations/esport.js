// Mutations du module "esport" (suivi PvP). Format : [fichier, motif, remplacement, libelle, suite].
const F = 'Mod_Esport.lua', S = 't_esport.lua';
module.exports = [
  [F, 'cost = "medium",', 'cost = "light",', 'esport : cout declare modifie', S],
  [F, 'd.count = mmin(4, d.count + 1)', 'd.count = d.count + 1', 'esport : compteur DR non plafonne', S],
  [F, 'd = { at = now, count = 0 }', 'd = { at = now, count = 2 }', 'esport : DR qui demarre a 2', S],
  [F, 'd.at = now', '', 'esport : fenetre DR jamais rafraichie', S],
  [F, 'if not d or now - d.at > win then', 'if not d then', 'esport : fenetre DR ignoree', S],
  [F, '	M.SeeUnit("target")', '', 'esport : cible jamais vue', S],
  [F, 'e.seenAt = GetTime()', 'e.seenAt = 0', 'esport : ennemis oublies aussitot', S],
  [F, 'if hb > 0 and hb < ha then', 'if hb > 0 and hb > ha then', 'esport : tri par vie inverse', S],
  [F, '\t\t\tM.enemies[nm] = nil', '', 'esport : ennemis jamais oublies', S],
  [F, 'SUI.Cancel(M.task)', '', 'esport : minuterie non annulee a la coupure', S],
  [F, '\t\t\tif g and g == guid and UnitIsPlayer(u) then return UnitName(u) end', '\t\t\tif g and g == guid then return UnitName(u) end', 'esport : victime non-joueur comptee', S],
  [F, 'local cat = M.CcCat(sname)\n\tif cat then M.ApplyCC(nm, cat) end', 'local cat = M.CcCat(sname)\n\tif cat then M.ApplyCC(nm, "stun") end', 'esport : categorie du sort ignoree', S],
];
