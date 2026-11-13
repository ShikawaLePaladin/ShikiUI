-- mock_esport : extension de simulation du module "esport" (chargee apres mock_wow.lua ; globales prefixees ESP_).
-- Simule : joueurs ennemis (table ESP.units : unit -> { name, cls, hp, hpMax, guid, isPlayer, friend, mark }),
-- GetRaidTargetIndex, TargetUnit / SpellTargetUnit (journalises), UNIT_CASTEVENT rejouable via ESP_CAST,
-- SpellInfo (ESP.spells : id -> nom), GetNumRaidMembers / GetNumPartyMembers, SUI.Api.GUID.
-- Rien n'est pose avant ESP_SETUP().

ESP = { units = {}, acts = {}, spells = {}, raid = {}, party = {} }

function ESP_SETUP()
  rawset(_G, "UnitName", function(u)
    local d = ESP.units[u]
    if d then return d.name end
    return nil
  end)
  rawset(_G, "UnitExists", function(u)
    local d = ESP.units[u]
    if d then return true end
    return u == "player"
  end)
  rawset(_G, "UnitIsPlayer", function(u) local d = ESP.units[u] return d and d.isPlayer and true or false end)
  rawset(_G, "UnitIsFriend", function(a, b) local d = ESP.units[b] return d and d.friend and true or false end)
  rawset(_G, "UnitClass", function(u) local d = ESP.units[u] if d and d.cls then return "Mage", d.cls end return nil end)
  rawset(_G, "UnitHealth", function(u) local d = ESP.units[u] return d and d.hp or 0 end)
  rawset(_G, "UnitHealthMax", function(u) local d = ESP.units[u] return d and d.hpMax or 0 end)
  rawset(_G, "GetRaidTargetIndex", function(u) local d = ESP.units[u] return d and d.mark or nil end)
  rawset(_G, "TargetUnit", function(u) ESP.acts[#ESP.acts + 1] = "TargetUnit " .. tostring(u) end)
  rawset(_G, "SpellTargetUnit", function(u) ESP.acts[#ESP.acts + 1] = "SpellTargetUnit " .. tostring(u) end)
  rawset(_G, "SpellIsTargeting", function() return false end)
  rawset(_G, "GetNumRaidMembers", function() return table.getn(ESP.raid) end)
  rawset(_G, "GetNumPartyMembers", function() return table.getn(ESP.party) end)
  rawset(_G, "SpellInfo", function(id) return ESP.spells[id] end)
  if rawget(_G, "ShikiUI") and ShikiUI.Api then
    ShikiUI.Api.GUID = function(u) local d = ESP.units[u] return d and d.guid or nil end
  end
end

-- ESP_ENEMY(unit, { name = "Bob", cls = "MAGE", hp = 2000, hpMax = 4000, guid = "0xF1", isPlayer = true, mark = 8 })
function ESP_ENEMY(unit, t)
  ESP.units[unit] = t
end

-- ESP_CAST(casterGuid, targetGuid, type, spellId) : rejoue l'evenement SuperWoW.
function ESP_CAST(a1, a2, a3, a4)
  Fire("UNIT_CASTEVENT", a1, a2, a3 or "CAST", a4 or 0, 0)
end

function ESP_ACTS() return table.concat(ESP.acts, "|") end

function ESP_CLEAR() ESP.acts = {} end
