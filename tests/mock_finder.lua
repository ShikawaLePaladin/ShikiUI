-- mock_finder : simulation des canaux de chat, des envois et du groupe pour le module "finder" (chargee automatiquement, AVANT le mode strict).
-- Rien n'est modifie au chargement : FINDER_SETUP() (appele par t_finder.lua seulement) pose les fonctions du client ; FINDER_FRAMES() cree Minimap, FriendsFrame et GameTooltip.
-- Noms d'API de WoW 1.12 : SendChatMessage, PlaySound, InviteByName, GetNumPartyMembers, GetNumRaidMembers, IsPartyLeader, IsRaidLeader,
-- IsRaidOfficer, GetChannelList, ChatFrame_SendTell, IsShiftKeyDown, Minimap, FriendsFrame, GameTooltip. Valeurs = DONNEES DE TEST.
-- Aides : FND_AD(texte, auteur [, canal]) envoie un message de canal ; FND_YELL / FND_SAY ; FND_SENT() nombre d'envois ; FND_LAST() dernier envoi ;
-- FND_RESET() remet le monde simule a zero ; FND_ROWS() cartes visibles ; FND_CLICK(bouton [, "RightButton"]).
ALLOW("FNDW")

function FINDER_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  FNDW = { sent = {}, sounds = {}, invites = {}, tells = {}, party = 0, raid = 0, leader = false, raidLeader = false, officer = false,
    shift = false, channels = { { 1, "General" }, { 2, "Trade" }, { 4, "World" } } }
  G("SendChatMessage", function(text, chan, lang, to) table.insert(FNDW.sent, { text = text, chan = chan, to = to }) end)
  G("PlaySound", function(name) table.insert(FNDW.sounds, name) end)
  G("InviteByName", function(name) table.insert(FNDW.invites, name) end)
  G("GetNumPartyMembers", function() return FNDW.party end)
  G("GetNumRaidMembers", function() return FNDW.raid end)
  G("IsPartyLeader", function() return FNDW.leader and 1 or nil end)
  G("IsRaidLeader", function() return FNDW.raidLeader and 1 or nil end)
  G("IsRaidOfficer", function() return FNDW.officer and 1 or nil end)
  G("IsShiftKeyDown", function() return FNDW.shift and 1 or nil end)
  G("ChatFrame_SendTell", function(name) table.insert(FNDW.tells, name) end)
  G("GetChannelList", function()
    local t = {}
    for i = 1, table.getn(FNDW.channels) do
      table.insert(t, FNDW.channels[i][1])
      table.insert(t, FNDW.channels[i][2])
    end
    return table.unpack(t)
  end)
end

-- Cadres du client utilises par les boutons d'acces : a creer APRES BOOT() (le module minimap reagit a la presence de Minimap).
function FINDER_FRAMES()
  if rawget(_G, "Minimap") == nil then
    local m = CreateFrame("Frame", "Minimap", UIParent)
    m:SetWidth(140)
    m:SetHeight(140)
  end
  if rawget(_G, "FriendsFrame") == nil then
    local f = CreateFrame("Frame", "FriendsFrame", UIParent)
    f:SetWidth(384)
    f:SetHeight(512)
  end
  if rawget(_G, "GameTooltip") == nil then
    CreateFrame("GameTooltip", "GameTooltip", UIParent)
  end
end

function FND_RESET()
  FNDW.sent, FNDW.sounds, FNDW.invites, FNDW.tells = {}, {}, {}, {}
  FNDW.party, FNDW.raid, FNDW.leader, FNDW.raidLeader, FNDW.officer, FNDW.shift = 0, 0, false, false, false, false
end

function FND_AD(text, author, chan)
  Fire("CHAT_MSG_CHANNEL", text, author or "Bob", "", chan or "4. World")
end
function FND_YELL(text, author) Fire("CHAT_MSG_YELL", text, author or "Bob") end
function FND_SAY(text, author) Fire("CHAT_MSG_SAY", text, author or "Bob") end
function FND_SENT() return table.getn(FNDW.sent) end
function FND_LAST() return FNDW.sent[table.getn(FNDW.sent)] end

-- Clic sur un bouton du theme (OnClick du script, avec le bouton de souris).
function FND_CLICK(b, btn)
  local so, sa = this, arg1
  this, arg1 = b, btn or "LeftButton"
  b.scripts.OnClick()
  this, arg1 = so, sa
end

-- Nombre de cartes visibles de la fenetre principale.
function FND_ROWS()
  local n = 0
  local M = ShikiUI.Finder
  for i = 1, 12 do
    if M.rows[i] and M.rows[i]:IsShown() then n = n + 1 end
  end
  return n
end
