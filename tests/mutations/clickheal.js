// Mutations du module "clickheal" (soins au clic).
const S = 't_clickheal.lua';
module.exports = [
  ['Mod_ClickHeal.lua', 'cost = "light",', 'cost = "heavy",', 'clickheal : cout declare modifie', S],
  ['Mod_ClickHeal.lua', 'if IsShiftKeyDown() then return 2 end', 'if IsShiftKeyDown() then return 3 end', 'clickheal : maj confondue avec ctrl', S],
  ['Mod_ClickHeal.lua', 'if IsControlKeyDown() then return 3 end', 'if IsControlKeyDown() then return 4 end', 'clickheal : ctrl confondu avec alt', S],
  ['Mod_ClickHeal.lua', 'if IsAltKeyDown() then return 4 end', '', 'clickheal : alt ignore', S],
  ['Mod_ClickHeal.lua', 'if want <= 0 or k.max <= 0 then return name end', 'if k.max <= 0 then return name end', 'clickheal : rang maximum mal gere', S],
  ['Mod_ClickHeal.lua', 'for r = want, 1, -1 do', 'for r = want, want do', 'clickheal : pas de repli sur un rang plus bas', S],
  ['Mod_ClickHeal.lua', 'return name .. "(" .. t .. ")" end', 'return name end', 'clickheal : rang jamais envoye', S],
  ['Mod_ClickHeal.lua', 'if m == "swap" then return false end', '', 'clickheal : methode echange ignoree', S],
  ['Mod_ClickHeal.lua', 'return SUI.Api.superwow and true or false', 'return true', 'clickheal : lancement direct sans SuperWoW', S],
  ['Mod_ClickHeal.lua', 'if not same then TargetUnit(unit) end', 'TargetUnit(unit)', 'clickheal : cible changee meme si identique', S],
  ['Mod_ClickHeal.lua', 'if not same and C.Get("clickheal.retarget") then', 'if C.Get("clickheal.retarget") then', 'clickheal : cible rendue a tort', S],
  ['Mod_ClickHeal.lua', 'if had then TargetLastTarget() else ClearTarget() end', 'TargetLastTarget()', 'clickheal : cible vide non retablie', S],
  ['Mod_ClickHeal.lua', 'if SpellIsTargeting() then SpellTargetUnit(unit) end', '', 'clickheal : curseur de sort non resolu', S],
  ['Mod_ClickHeal.lua', 'if not M.on or not C.Get("clickheal.hints") or not tip or not tip.AddLine then return end', 'if not M.on or not tip or not tip.AddLine then return end', 'clickheal : option infobulle ignoree', S],
  ['Mod_ClickHeal.lua', 'if key == nil or sfind(key, "^clickheal%.") then M.Rebuild() end', '', 'clickheal : liaisons non relues au changement', S],
  ['Mod_ClickHeal.lua', 'SUI.Config.AddPreset("raid", "*", { ["clickheal.hints"] = false })', 'SUI.Config.AddPreset("raid", "*", { ["clickheal.hints"] = true })', 'clickheal : preset Raid perdu', S],
  ['Mod_ClickHeal.lua', 'if SUI.InCombat() then', 'if false then', 'clickheal : grimoire relu en combat', S],
];
