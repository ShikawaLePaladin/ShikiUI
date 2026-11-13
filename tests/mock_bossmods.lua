-- mock_bossmods : extension de simulation du module "bossmods" (chargee apres mock_wow.lua ; globales prefixees BMC_).
-- Simule : nom de la cible / souris (table BMC.name), cible hostile (UnitCanAttack selon BMC.hostile), SendChatMessage
-- (journalise les canaux RAID_WARNING / PARTY), PlaySoundFile (compteur), GetNumRaidMembers / GetNumPartyMembers.
-- Rien n'est pose avant BMC_SETUP().

BMC = { name = {}, acts = {}, sounds = 0, target = "target", hostile = true, raid = {}, party = {} }

function BMC_SETUP()
  -- la cible existe toujours (le module la vise pour detecter le boss)
  if not W.units.target then
    W.units.target = { name = "Ragnaros", hp = 100, hpMax = 100, canAttack = true, enemy = true }
  end
  -- le module Marks tourne aussi (defaut ON) : son API doit exister meme sans MKS_SETUP
  if rawget(_G, "GetRaidTargetIndex") == nil then
    rawset(_G, "GetRaidTargetIndex", function() return nil end)
  end
  rawset(_G, "UnitName", function(u)
    if BMC.name[u] then return BMC.name[u] end
    local d = W.units and W.units[u]
    return d and d.name or nil
  end)
  rawset(_G, "UnitCanAttack", function(a, b)
    if BMC.name[b] then return BMC.hostile and true or false end
    return false
  end)
  rawset(_G, "SendChatMessage", function(msg, chan)
    if chan == "RAID_WARNING" or chan == "PARTY" then BMC.acts[#BMC.acts + 1] = chan .. ": " .. msg end
  end)
  rawset(_G, "PlaySoundFile", function() BMC.sounds = BMC.sounds + 1 end)
  rawset(_G, "GetNumRaidMembers", function() return table.getn(BMC.raid) end)
  rawset(_G, "GetNumPartyMembers", function() return table.getn(BMC.party) end)
end

-- BMC_RAID(n) : raid de n membres (les annonces raid passent).
function BMC_RAID(n)
  BMC.raid = {}
  for i = 1, n do BMC.raid[i] = "Membre" .. i end
end

function BMC_ACTS() return table.concat(BMC.acts, "|") end

function BMC_CLEAR()
  BMC.acts = {}
  BMC.sounds = 0
end
