-- mock_pallypower : extension de simulation du module "pallypower" (chargee apres mock_wow.lua ; globales d'aide prefixees PP_).
-- Simule : liste du raid (GetNumRaidMembers / GetRaidRosterInfo), buffs des unites (UnitBuff par nom), lancements de sorts
-- (CastSpellByName journalise), mort / existence des unites, UnitClass du joueur. Rien n'est pose avant PP_SETUP().

PP = { raid = {}, party = {}, buffs = {}, casts = {}, dead = {}, hostile = false }

-- PP_RAID({ "Shikiwa/PALADIN", "Bob/WARRIOR", ... }) : construit le raid 1..n (le joueur reste hors liste raid).
function PP_RAID(members)
  PP.raid = {}
  PP.party = {}
  for i = 1, table.getn(members) do
    local name, file = string.match(members[i], "^(.-)/(.+)$")
    if not name then name, file = members[i], "WARRIOR" end
    PP.raid[i] = { name = name, file = file }
  end
end

-- PP_PARTY({ "Bob/WARRIOR", ... }) : groupe de 5 (le joueur + party1..n).
function PP_PARTY(members)
  PP.raid = {}
  PP.party = {}
  for i = 1, table.getn(members) do
    local name, file = string.match(members[i], "^(.-)/(.+)$")
    if not name then name, file = members[i], "WARRIOR" end
    PP.party[i] = { name = name, file = file }
  end
end

-- PP_BUFF(unit, "Blessing of Kings") : pose un buff nomme ; PP_BUFF(unit, nil) vide.
function PP_BUFF(unit, name)
  if name then PP.buffs[unit] = name else PP.buffs[unit] = nil end
end

function PP_SETUP()
  rawset(_G, "GetNumRaidMembers", function() return table.getn(PP.raid) end)
  rawset(_G, "GetNumPartyMembers", function() return table.getn(PP.party) end)
  rawset(_G, "GetRaidRosterInfo", function(i)
    local r = PP.raid[i]
    if not r then return nil end
    return r.name, 0, 1, 60, r.file, r.file, "", true, false   -- 9 retours 1.12, var 6 = nom de classe EN
  end)
  rawset(_G, "UnitBuff", function(u, i)
    if i > 1 then return nil end
    return PP.buffs[u]
  end)
  rawset(_G, "UnitIsDead", function(u) return PP.dead[u] and true or false end)
  rawset(_G, "UnitExists", function(u)
    if u == "player" or u == "target" then return true end
    if type(u) == "string" and string.find(u, "^raid%d+$") then return PP.raid[tonumber(string.sub(u, 5))] ~= nil end
    if type(u) == "string" and string.find(u, "^party%d+$") then return PP.party[tonumber(string.sub(u, 6))] ~= nil end
    return false
  end)
  rawset(_G, "UnitCanAttack", function(a, b) return b == "target" and PP.hostile and true or false end)
  rawset(_G, "CastSpellByName", function(name, unit) table.insert(PP.casts, { name = name, unit = unit }) end)
  rawset(_G, "UnitName", function(u)
    if u == "player" then return "Shikiwa" end
    if type(u) == "string" and string.find(u, "^party%d+$") then
      local p = PP.party[tonumber(string.sub(u, 6))]
      return p and p.name or nil
    end
    return "Cible"
  end)
  rawset(_G, "UnitClass", function(u)
    if u == "player" then return "Paladin", W.units and W.units.player and W.units.player.class or "PALADIN" end
    return nil
  end)
  -- infobulle cachee du module (SetUnitBuff -> ligne 1) : le nom lu = le buff pose par PP_BUFF
  local ppTip = CreateFrame("GameTooltip", "ShikiUI_PPTip", UIParent)
  ppTip.SetOwner = function(self, o, a) self.owner = o end
  ppTip.SetUnitBuff = function(self, u, i) self.tipName = PP.buffs[u] end
  rawset(_G, "ShikiUI_PPTipTextLeft1", { GetText = function(self) return ppTip.tipName end })
end

function PP_CASTS()
  local out = {}
  for i = 1, table.getn(PP.casts) do
    local c = PP.casts[i]
    out[i] = c.name .. (c.unit and ("->" .. c.unit) or "")
  end
  return table.concat(out, "|")
end

function PP_CLEARCASTS() PP.casts = {} end
