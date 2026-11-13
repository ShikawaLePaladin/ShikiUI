// Mutations de Target.lua (service partage de ciblage).
module.exports = [
  ['Target.lua', 'if now - T.at < T.TTL and now >= T.at then return T.n end', 'if false then return T.n end', 'target : cache de balayage ignore', 't_target.lua'],
  ['Target.lua', 'hostile = (reaction <= 2)', 'hostile = (reaction <= 4)', 'target : amis comptes comme ennemis', 't_target.lua'],
  ['Target.lua', 'if okD and dead then alive = false end', '', 'target : ennemis morts comptes', 't_target.lua'],
  ['Target.lua', 'if d <= range then c = c + 1 end', 'c = c + 1', 'target : portee ignoree', 't_target.lua'],
  ['Target.lua', 'if (not fighting) or T.fight[i] then\n\t\t\tlocal d', 'if true then\n\t\t\tlocal d', 'target : filtre "en combat" ignore', 't_target.lua'],
  ['Target.lua', 'if not known then return nil, false end', '', 'target : distances inconnues devinees', 't_target.lua'],
  ['Target.lua', 'g == "0x0000000000000000" or ', '', 'target : GUID nul accepte', 't_target.lua'],
  ['Target.lua', 'if not plate:IsObjectType("Button") or not plate:IsShown() then return nil end', 'if not plate:IsShown() then return nil end', 'target : cadre qui n\'est pas une plaque', 't_target.lua'],
  ['Target.lua', 'if not plate:IsObjectType("Button") or not plate:IsShown() then return nil end', 'if not plate:IsObjectType("Button") then return nil end', 'target : plaque cachee comptee', 't_target.lua'],
  ['Target.lua', 'if had and (not UnitExists("target")) and type(TargetLastTarget) == "function" then', 'if false then', 'target : cible precedente perdue', 't_target.lua'],
  ['Target.lua', '\tClearTarget()\n', '', 'target : pas de ClearTarget avant l\'acquisition', 't_target.lua'],
  ['Target.lua', 'T.at = -10      -- le prochain balayage doit relire la situation', '', 'target : cache non invalide apres acquisition', 't_target.lua'],
  ['Target.lua', 'local okG, guid = pcall(plateGuid, children[i])', 'local okG, guid = true, plateGuid(children[i])', 'target : plaque qui plante non isolee', 't_target.lua'],
  ['Target.lua', 'if okG and guid and seen[guid] ~= T.scans then', 'if okG and guid then', 'target : plaque comptee deux fois', 't_target.lua'],
  ['Target.lua', 'if playersOnly and type(TargetNearestEnemyPlayer) == "function" then', 'if false then', 'target : acquisition joueurs ignoree', 't_target.lua'],
  ['Target.lua', 'and (not UnitIsDeadOrGhost(unit)) and true or false', 'and true or false', 'target : cible morte jugee valide', 't_target.lua'],
];
