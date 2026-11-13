-- mock_loot : simulation du butin et des jets pour le module "loot" (chargee automatiquement par le harnais).
-- Ne contient QUE des noms d'API de WoW 1.12 (relevees dans LootBlare, RollFor, _LazyPig) et des DONNEES DE TEST.
-- Etat : W.loot. Aides : LOOTRESET() LOOTLINK(id, nom, qualite) LOOTML(nom|nil) LOOTROSTER({ {nom, classe}, ... }) LOOTROLL(nom, n, min, max)
-- LOOTRW(texte, expediteur) LOOTSENT() LOOTRAIDLEADER(bool) LOOTGROUPROLL(id, objet, nom, qualite, options) LOOTINSTALL() (reaffirme les fonctions).
-- Butin du corps : LOOTITEMS({ { tex, nom, quantite, qualite, lien, piece }, ... }) LOOTCANDS({ "Alice", false, "Bob" }) (false = hors de portee)
-- LOOTTHRESHOLD(q). Appels notes dans W.loot.calls : "LootSlot n", "GiveMasterLoot n i", "CloseLoot".

W.loot = { sent = {}, method = "freeforall", pid = nil, rid = nil, roster = {}, leader = false, officer = false, rolls = {}, party = {}, slots = {}, cands = {}, thr = 2, calls = {} }

local QHEX = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }

function LOOTRESET()
  W.loot.sent, W.loot.method, W.loot.pid, W.loot.rid, W.loot.roster, W.loot.leader, W.loot.officer, W.loot.rolls =
    {}, "freeforall", nil, nil, {}, false, false, {}
  W.loot.slots, W.loot.cands, W.loot.thr, W.loot.calls = {}, {}, 2, {}
end

function LOOTITEMS(list) W.loot.slots = list end
function LOOTCANDS(list) W.loot.cands = list end
function LOOTTHRESHOLD(q) W.loot.thr = q end

function LOOTLINK(id, name, q)
  return "|c" .. QHEX[q or 2] .. "|Hitem:" .. id .. ":0:0:0|h[" .. (name or ("Objet" .. id)) .. "]|h|r"
end

-- chef de butin : nom (le joueur = "player") ou nil pour retirer
function LOOTML(name)
  if not name then W.loot.method, W.loot.pid, W.loot.rid = "group", nil, nil return end
  W.loot.method = "master"
  if name == "player" then W.loot.pid = 0 W.loot.rid = nil return end
  W.loot.pid = 1
  W.units.party1 = { name = name, class = "WARRIOR", isPlayer = true, friend = true }
end

-- LOOTROSTER({ { "Alice", "WARRIOR" }, { "Bob", "MAGE" } }) : le raid ; GetRaidRosterInfo renvoie nom, rang, groupe, niveau, classe, jeton
function LOOTROSTER(list)
  W.loot.roster = list
  W.raidMembers = table.getn(list)
end

function LOOTROLL(name, n, lo, hi)
  Fire("CHAT_MSG_SYSTEM", name .. " rolls " .. n .. " (" .. lo .. "-" .. hi .. ")")
end
function LOOTRW(text, sender, ev) Fire(ev or "CHAT_MSG_RAID_WARNING", text, sender) end
function LOOTSENT() local s = W.loot.sent; return s[table.getn(s)] end
function LOOTRAIDLEADER(on) W.loot.leader = on and true or false end

-- jet de groupe : LOOTGROUPROLL(7, 1234, "Epee", 3) puis Fire("START_LOOT_ROLL", 7)
function LOOTGROUPROLL(id, item, name, q, o)
  o = o or {}
  W.loot.rolls[id] = { name = name, q = q, link = LOOTLINK(item, name, q), count = o.count, canNeed = o.canNeed, canGreed = o.canGreed, canDE = o.canDE }
end

function LOOTINSTALL()
  SendChatMessage = function(msg, ch) table.insert(W.loot.sent, { msg, ch }) end
  GetLootMethod = function() return W.loot.method, W.loot.pid, W.loot.rid end
  IsRaidLeader = function() return W.loot.leader and 1 or nil end
  IsRaidOfficer = function() return W.loot.officer and 1 or nil end
  GetRaidRosterInfo = function(i)
    local r = W.loot.roster[i]
    if not r then return nil end
    return r[1], 0, 1, 60, r[2], r[2], "Zone", true, false
  end
  RandomRoll = function(a, b) ACT(string.format("RandomRoll %d %d", a, b)) end
  GetLootRollItemInfo = function(id)
    local r = W.loot.rolls[id]
    if not r then return nil end
    return "tex" .. id, r.name, r.count or 1, r.q, nil, r.canNeed, r.canGreed, r.canDE
  end
  GetNumLootItems = function() return table.getn(W.loot.slots) end
  local function slot(i) return W.loot.slots[i] end
  LootSlotIsItem = function(i) local x = slot(i); return (x and not x[6]) and 1 or nil end
  LootSlotIsCoin = function(i) local x = slot(i); return (x and x[6]) and 1 or nil end
  GetLootSlotInfo = function(i) local x = slot(i); if not x then return nil end return x[1], x[2], x[3] or 1, x[4] end
  GetLootSlotLink = function(i) local x = slot(i); return x and x[5] or nil end
  LootSlot = function(i) table.insert(W.loot.calls, "LootSlot " .. i) end
  GiveMasterLoot = function(i, c) table.insert(W.loot.calls, "GiveMasterLoot " .. i .. " " .. c) end
  CloseLoot = function() table.insert(W.loot.calls, "CloseLoot") end
  GetMasterLootCandidate = function(i) return W.loot.cands[i] or nil end
  GetLootThreshold = function() return W.loot.thr end
  GetLootRollItemLink = function(id) local r = W.loot.rolls[id]; return r and r.link or nil end
  RollOnLoot = function(id, r) ACT("RollOnLoot " .. id .. " " .. r) end
  ConfirmLootRoll = function(id, r) ACT("ConfirmLootRoll " .. id .. " " .. r) end
end
LOOTINSTALL()
