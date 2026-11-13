// Mutations du module "raid" (cadres de raid 40 sur le moteur partage).
const S = 't_raid.lua';
module.exports = [
  ['Mod_Raid.lua', 'cost = "heavy",', 'cost = "light",', 'raid : cout declare modifie', S],
  ['Mod_Raid.lua', 'max = 40, maxDeb = 3, maxBuf = 3,', 'max = 25, maxDeb = 3, maxBuf = 3,', 'raid : moins de 40 cadres', S],
  ['Mod_Raid.lua', 'M.g.units = E.RAID_UNITS', 'M.g.units = E.PARTY_UNITS', 'raid : mauvaises unites', S],
  ['Mod_Raid.lua', 'if M.g and SUI.GroupEngine then SUI.GroupEngine.Deactivate(M.g) end', '', 'raid : moteur non desactive', S],
  ['Mod_Raid.lua', 'if key == nil or key == "ui.locked" or key == "ui.locale" or sfind(key, "^raid%.") then SUI.GroupEngine.OnKey(M.g, key) end', '', 'raid : reglages non relus', S],
  ['Mod_Raid.lua', '{ ["raid.debuffs"] = 1, ["raid.hots"] = 1, ["raid.budget"] = 16, ["raid.slowstep"] = 8, ["raid.powerheight"] = 0 }', '{ ["raid.debuffs"] = 3, ["raid.hots"] = 1, ["raid.budget"] = 16, ["raid.slowstep"] = 8, ["raid.powerheight"] = 0 }', 'raid : preset Raid perdu', S],
  ['Mod_Raid.lua', 'opt("powerheight", "number", 40, 0,', 'opt("powerheight", "number", 40, 4,', 'raid : puissance allumee par defaut', S],
  ['Mod_Raid.lua', 'default = false,', 'default = true,', 'raid : allume par defaut', S],
  ['Mod_Raid.lua', 'opt("maxgroup", "number", 10, 8,', 'opt("maxgroup", "number", 10, 4,', 'raid : sous-groupes masques par defaut', S],
  ['Mod_Raid.lua', 'if w[1] == "alert" then\n\t\tE.CmdAlert(g, w)', 'if w[1] == "alert" then', 'raid : commande alert perdue', S],
  ['Mod_Raid.lua', 'E.CmdRole(g, { "role", w[2], w[3] })', 'E.CmdRole(g, { "role", w[3], w[2] })', 'raid : commande role inversee', S],
];
