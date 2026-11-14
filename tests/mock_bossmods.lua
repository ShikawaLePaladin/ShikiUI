-- mock_bossmods : extension de simulation du module "bossmods" (chargee apres mock_wow.lua ; globales prefixees BMC_).
-- Simule : nom de la cible / souris (table BMC.name), cible hostile (UnitCanAttack selon BMC.hostile), SendChatMessage
-- (journalise RAID_WARNING / PARTY), PlaySoundFile (compteur), SendAddonMessage (compteur BMC.addons),
-- GetNumRaidMembers / GetNumPartyMembers / IsRaidLeader / IsPartyLeader, GetRaidTargetIndex (module Marks).
-- Rien n'est pose avant BMC_SETUP().

BMC = { name = {}, acts = {}, sounds = 0, target = "target", hostile = true, raid = {}, party = {}, addons = 0, raidleader = true }

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
  rawset(_G, "SendAddonMessage", function(prefix, msg, chan)
    BMC.addons = BMC.addons + 1
    BMC.acts[#BMC.acts + 1] = "ADDON " .. prefix .. ":" .. msg
  end)
  rawset(_G, "IsRaidLeader", function() return BMC.raidleader and BMC.raid[1] ~= nil end)
  rawset(_G, "IsPartyLeader", function() return BMC.raidleader end)
end

-- BMC_RAID(n [, leader]) : raid de n membres (annonces raid passent si leader).
function BMC_RAID(n, leader)
  BMC.raid = {}
  for i = 1, n do BMC.raid[i] = "Membre" .. i end
  if leader ~= nil then BMC.raidleader = leader and true or false end
end

function BMC_ACTS() return table.concat(BMC.acts, "|") end

function BMC_CLEAR()
  BMC.acts = {}
  BMC.sounds = 0
end

function BMC_ADDONS() return BMC.addons end

-- BMC_ADDONRECV(sender, msg) : simule la reception d'un message d'addon (a2 = message).
function BMC_ADDONRECV(sender, msg)
  Fire("CHAT_MSG_ADDON", sender, msg, "RAID", "")
end
