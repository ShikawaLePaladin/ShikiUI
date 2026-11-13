// Mutations du module "group" (moteur partage SUI.GroupEngine). Format : [fichier, motif, remplacement, libelle[, suite]].
const S = 't_group.lua';
module.exports = [
  ['Mod_Group.lua', 'cost = "medium",', 'cost = "heavy",', 'group : cout declare modifie', S],
  ['Mod_Group.lua', 'if src == "xp" or src == "pos" then return d <= cfg.rangeyd end', 'if src == "xp" or src == "pos" then return d < 0 end', 'group : distance de portee ignoree', S],
  ['Mod_Group.lua', 'if not UnitIsVisible(unit) then return false end', 'if false then return false end', 'group : unite hors de vue consideree a portee', S],
  ['Mod_Group.lua', 'if f.state ~= 0 or f.inRange == false then a = g.cfg.outalpha end', 'if f.state ~= 0 then a = g.cfg.outalpha end', 'group : estompage hors de portee perdu', S],
  ['Mod_Group.lua', 'if f.state ~= 0 or f.inRange == false then a = g.cfg.outalpha end', 'if f.inRange == false then a = g.cfg.outalpha end', 'group : estompage des morts / hors ligne perdu', S],
  ['Mod_Group.lua', 'local n = g.cfg.budget\n', 'local n = 1000\n', 'group : budget par passage ignore', S],
  ['Mod_Group.lua', 'SUI.Cancel(g.tFlush)', '', 'group : minuterie de vidage non annulee', S],
  ['Mod_Group.lua', 'SUI.Cancel(g.tSlow)', '', 'group : minuterie du tour lent non annulee', S],
  ['Mod_Group.lua', 'if mode == "all" then cureOk = true elseif mode == "known" then cureOk = E.cure[dt] and true or false end', 'cureOk = true', 'group : dissipation sans tenir compte des sorts connus', S],
  ['Mod_Group.lua', 'if nd < wantD and nd < g.maxDeb and (cureOk or not cfg.dispelonly) then', 'if nd < wantD and nd < g.maxDeb then', 'group : option dissipables seulement ignoree', S],
  ['Mod_Group.lua', 'if nd < wantD and nd < g.maxDeb and (cureOk or not cfg.dispelonly) then', 'if nd < wantD and (cureOk or not cfg.dispelonly) then', 'group : maximum d icones de debuff depasse', S],
  ['Mod_Group.lua', 'if sfind(tex, g.alerts[k], 1, true) then', 'if false then', 'group : alertes de debuff jamais declenchees', S],
  ['Mod_Group.lua', 'local useAlerts = cfg.alerts and g.nAlerts > 0', 'local useAlerts = g.nAlerts > 0', 'group : option alertes ignoree', S],
  ['Mod_Group.lua', 'SUI.Config.AddPreset("raid", "*", { ["group.buffs"] = 0, ["group.debuffs"] = 2,', 'SUI.Config.AddPreset("raid", "*", { ["group.buffs"] = 0, ["group.debuffs"] = 3,', 'group : preset Raid modifie', S],
  ['Mod_Group.lua', 'g.tFlush = SUI.Every(FLUSH, g.fnFlush, g.title .. ".flush", true)', 'g.tFlush = SUI.Every(FLUSH, g.fnFlush, g.title .. ".flush", false)', 'group : minuterie de vidage non protegee', S],
  ['Mod_Group.lua', 'local step = cfg.slowstep', 'local step = 1', 'group : pas du tour lent ignore', S],
  ['Mod_Group.lua', 'if not inc and SUI.Units and SUI.Units.active and SUI.Config.Get("units.incheal") then inc = true end', '', 'group : cadres joueur ne declenchent pas l ecoute des incantations', 't_units.lua'],
  ['Mod_Group.lua', '\tif SUI.UnitsHealNotify then SUI.UnitsHealNotify() end', '', 'group : changement de soin entrant non notifie aux cadres joueur', 't_units.lua'],
  ['Mod_Group.lua', 'if name and m.name == name and m.amount > inc then inc = m.amount end', '', 'group : mon soin ignore par la requete des cadres joueur', 't_units.lua'],
];
