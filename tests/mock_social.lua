-- mock_social : simulation du groupe, des amis, de la guilde et des fenetres de demande pour le module "social" (chargee automatiquement).
-- Ne contient QUE des noms d'API de WoW 1.12 (relevees dans AutoInvite, AutoMarkerOW et _LazyPig) et des DONNEES DE TEST.
-- Etat : W.soc. Aides : SOCRESET() SOCGROUP({ "Bob", ... }, leader) SOCRAID(n, leader, officer) SOCUNIT(unite, { name, player, dead, attack, icon })
-- SOCLOG() (actions faites, une chaine) SOCLOGCLEAR() SOCINSTALL() (definit toutes les fonctions ci-dessous).
-- IMPORTANT : rien n'est defini au chargement (les noms comme IsShiftKeyDown ou GetNumFriends sont aussi simules par d'autres mocks avec un autre
-- modele) : une suite appelle SOCINSTALL() avant BOOT().

W.soc = {}

function SOCRESET()
  W.soc = { shift = false, party = {}, raid = {}, leader = false, officer = false, ignores = {}, guild = {}, friends = {}, log = {},
    units = {}, instance = false, summon = 0, addons = {}, hasGuild = true, popups = {} }
  W.combat = false
end

function SOCGROUP(names, leader)
  W.soc.party = names or {}
  W.soc.raid = {}
  W.soc.leader = leader and true or false
end

function SOCRAID(n, leader, officer)
  local t = {}
  for i = 1, n do t[i] = "Membre" .. i end
  W.soc.raid = t
  W.soc.party = {}
  W.soc.leader = leader and true or false
  W.soc.officer = officer and true or false
end

function SOCUNIT(unit, t) W.soc.units[unit] = t end

function SOCLOG() return table.concat(W.soc.log, "|") end
function SOCLOGCLEAR() W.soc.log = {} end

local function act(s) table.insert(W.soc.log, s) end

local ORIGNAME

function SOCINSTALL()
  local g = function(name, fn) rawset(_G, name, fn) end
  if not ORIGNAME then ORIGNAME = rawget(_G, "UnitName") or function() return "Moi" end end
  g("IsShiftKeyDown", function() return W.soc.shift and 1 or nil end)
  g("GetNumRaidMembers", function() return table.getn(W.soc.raid) end)
  g("GetNumPartyMembers", function() return table.getn(W.soc.party) end)
  g("IsRaidLeader", function() return W.soc.leader and 1 or nil end)
  g("IsRaidOfficer", function() return W.soc.officer and 1 or nil end)
  g("IsPartyLeader", function() return W.soc.leader and 1 or nil end)
  g("UnitName", function(u)
    for i = 1, table.getn(W.soc.party) do if u == "party" .. i then return W.soc.party[i] end end
    for i = 1, table.getn(W.soc.raid) do if u == "raid" .. i then return W.soc.raid[i] end end
    local t = W.soc.units[u]
    if t then return t.name end
    return ORIGNAME(u)
  end)
  g("GetNumIgnores", function() return table.getn(W.soc.ignores) end)
  g("GetIgnoreName", function(i) return W.soc.ignores[i] end)
  g("IsInGuild", function() return W.soc.hasGuild and 1 or nil end)
  g("GetNumGuildMembers", function() return table.getn(W.soc.guild) end)
  g("GetGuildRosterInfo", function(i) return W.soc.guild[i] end)
  g("GetNumFriends", function() return table.getn(W.soc.friends) end)
  g("GetFriendInfo", function(i) return W.soc.friends[i] end)
  g("InviteByName", function(n) act("InviteByName " .. n) end)
  g("ConvertToRaid", function() act("ConvertToRaid") end)
  g("AcceptGroup", function() act("AcceptGroup") end)
  g("DeclineGroup", function() act("DeclineGroup") end)
  g("StaticPopup_Hide", function(w) act("Hide " .. w) end)
  g("CancelDuel", function() act("CancelDuel") end)
  g("DeclineGuild", function() act("DeclineGuild") end)
  g("AcceptResurrect", function() act("AcceptResurrect") end)
  g("GetSummonConfirmTimeLeft", function()
    local left = W.soc.summonUntil and (W.soc.summonUntil - GetTime()) or 0
    if left < 0 then left = 0 end
    return left
  end)
  g("ConfirmSummon", function() act("ConfirmSummon") end)
  g("UnitExists", function(u) return W.soc.units[u] and 1 or nil end)
  g("UnitIsPlayer", function(u) return W.soc.units[u] and W.soc.units[u].player and 1 or nil end)
  g("UnitIsDead", function(u) return W.soc.units[u] and W.soc.units[u].dead and 1 or nil end)
  g("UnitCanAttack", function(a, u) return W.soc.units[u] and W.soc.units[u].attack and 1 or nil end)
  g("GetRaidTargetIndex", function(u) return W.soc.units[u] and W.soc.units[u].icon or nil end)
  g("SetRaidTarget", function(u, i)
    act("SetRaidTarget " .. u .. " " .. i)
    if W.soc.units[u] then W.soc.units[u].icon = i end
  end)
  g("IsInInstance", function() if W.soc.instance then return 1, "party" end return nil, "none" end)
  g("IsAddOnLoaded", function(n) return W.soc.addons[n] and 1 or nil end)
end
SOCRESET()
