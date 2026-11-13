-- mock_marks : extension de simulation du module "marks" (chargee apres mock_wow.lua ; globales d'aide prefixees MKS_).
-- Simule : GetRaidTargetIndex (table MKS.idx[unit]), SetRaidTarget (journalise), TargetUnit / SpellTargetUnit
-- (journalises), GetNumRaidMembers / GetNumPartyMembers (tables MKS.raid / MKS.party), GetLocale (langue du monde W).
-- Rien n'est pose avant MKS_SETUP().

MKS = { idx = {}, raid = {}, party = {}, acts = {} }

function MKS_SETUP()
  rawset(_G, "GetRaidTargetIndex", function(u) return MKS.idx[u] end)
  rawset(_G, "SetRaidTarget", function(u, idx) MKS.acts[#MKS.acts + 1] = "SetRaidTarget " .. tostring(u) .. " " .. tostring(idx) end)
  rawset(_G, "TargetUnit", function(u) MKS.acts[#MKS.acts + 1] = "TargetUnit " .. tostring(u) end)
  rawset(_G, "SpellTargetUnit", function(u) MKS.acts[#MKS.acts + 1] = "SpellTargetUnit " .. tostring(u) end)
  rawset(_G, "SpellIsTargeting", function() return false end)
  rawset(_G, "GetNumRaidMembers", function() return table.getn(MKS.raid) end)
  rawset(_G, "GetNumPartyMembers", function() return table.getn(MKS.party) end)
  rawset(_G, "GetLocale", function() return W.locale end)
  rawset(_G, "UnitExists", function(u)
    if u == "player" or u == "target" or u == "mouseover" or u == "targettarget" then return true end
    if type(u) == "string" and string.find(u, "^raid%d+target$") then return MKS.idx[u] ~= nil end
    return false
  end)
  rawset(_G, "UnitIsPlayer", function(u) return u == "player" or u == "mouseover" end)
  if rawget(_G, "IsShiftKeyDown") == nil then rawset(_G, "IsShiftKeyDown", function() return nil end) end
end

-- MKS_MARK(unit, idx) : le mob cible par cette unite porte ce marqueur (0 / nil = aucun).
function MKS_MARK(unit, idx)
  if idx and idx > 0 then MKS.idx[unit] = idx else MKS.idx[unit] = nil end
end

function MKS_ACTS() return table.concat(MKS.acts, "|") end

function MKS_CLEAR() MKS.acts = {} end
