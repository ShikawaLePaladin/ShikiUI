-- mock_chat : extension de simulation du module "chat" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est defini au chargement sauf des fonctions d'aide prefixees CHAT_ : le monde simule (ChatFrameN, listes d'amis...) est pose par
-- CHAT_SETUP(), appele par t_chat.lua seulement, pour ne rien changer aux autres suites (qui chargent tous les mock_*).
-- Noms d'API de WoW 1.12 releves dans le pfUI et les addons installes : NUM_CHAT_WINDOWS, ChatFrameN, ChatFrameNTab, GetChatWindowInfo,
-- FCF_SelectDockFrame, SELECTED_CHAT_FRAME, FCF_SetChatWindowFontSize, SetItemRef, IsShiftKeyDown, GetNumFriends, GetFriendInfo,
-- GetNumGuildMembers, GetGuildRosterInfo, GetNumWhoResults, GetWhoInfo, LOCALIZED_CLASS_NAMES_MALE, date. Valeurs = DONNEES DE TEST.
ALLOW("CHATW")

function CHAT_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  if rawget(_G, "unpack") == nil then G("unpack", table.unpack) end
  if rawget(_G, "date") == nil then
    G("date", function(fmt)
      local s = fmt
      s = string.gsub(s, "%%H", "14")
      s = string.gsub(s, "%%I", "02")
      s = string.gsub(s, "%%M", "05")
      s = string.gsub(s, "%%S", "09")
      s = string.gsub(s, "%%p", "PM")
      return s
    end)
  end
  G("NUM_CHAT_WINDOWS", 7)
  G("COMBAT_LOG", "Combat Log")
  G("LOCALIZED_CLASS_NAMES_MALE", { MAGE = "Mage", PALADIN = "Paladin", WARRIOR = "Guerrier" })
  CHATW = {
    names = { "General", "Combat Log", "Whispers", "", "", "", "" },
    shown = { true, true, true, false, false, false, false },
    shift = false, ctrl = false, lastRef = nil,
    friends = {}, guild = {}, who = {},
  }
  local eb = CreateFrame("Frame", "ChatFrameEditBox", UIParent)
  eb:SetWidth(400)
  eb:SetHeight(22)
  for i = 1, 7 do
    local f = CreateFrame("Frame", "ChatFrame" .. i, UIParent)
    f.id = i
    f.GetID = function(self) return self.id end
    f.lines = {}
    f.scrolled = {}
    f.AddMessage = function(self, text, r, g, b) table.insert(self.lines, text) end
    f.SetMaxLines = function(self, n) self.maxLines = n end
    f.ScrollUp = function(self) table.insert(self.scrolled, "up") end
    f.ScrollDown = function(self) table.insert(self.scrolled, "down") end
    f.PageUp = function(self) table.insert(self.scrolled, "pageup") end
    f.PageDown = function(self) table.insert(self.scrolled, "pagedown") end
    f.ScrollToTop = function(self) table.insert(self.scrolled, "top") end
    f.ScrollToBottom = function(self) table.insert(self.scrolled, "bottom") end
    f:SetWidth(400)
    f:SetHeight(120)
    CreateFrame("Button", "ChatFrame" .. i .. "Tab", UIParent)
    CreateFrame("Button", "ChatFrame" .. i .. "UpButton", UIParent)
    CreateFrame("Button", "ChatFrame" .. i .. "DownButton", UIParent)
    CreateFrame("Button", "ChatFrame" .. i .. "BottomButton", UIParent)
  end
  G("SELECTED_CHAT_FRAME", rawget(_G, "ChatFrame1"))
  G("GetChatWindowInfo", function(i)
    return CHATW.names[i], 14, 0, 0, 0, 0.5, CHATW.shown[i] and 1 or nil, nil, nil
  end)
  G("FCF_SelectDockFrame", function(f) rawset(_G, "SELECTED_CHAT_FRAME", f) end)
  G("FCF_SetChatWindowFontSize", function(f, size) f.fontSizeSet = size end)
  G("SetItemRef", function(link, text, button) CHATW.lastRef = link end)
  G("IsShiftKeyDown", function() return CHATW.shift and 1 or nil end)
  G("IsControlKeyDown", function() return CHATW.ctrl and 1 or nil end)
  G("GetNumFriends", function() return table.getn(CHATW.friends) end)
  G("GetFriendInfo", function(i) local x = CHATW.friends[i]; if not x then return nil end return x[1], x[2], x[3], x[4], 1 end)
  G("GetNumGuildMembers", function() return table.getn(CHATW.guild) end)
  G("GetGuildRosterInfo", function(i) local x = CHATW.guild[i]; if not x then return nil end return x[1], "Rank", 1, x[2], x[3] end)
  G("GetNumWhoResults", function() return table.getn(CHATW.who) end)
  G("GetWhoInfo", function(i) local x = CHATW.who[i]; if not x then return nil end return x[1], "Guilde", x[2], "Humain", x[3] end)
end

-- Aides de test
-- CHAT_SEND(i, texte) : envoie une ligne a ChatFrame<i> par la methode AddMessage (donc par l'enrobage du module s'il est pose).
function CHAT_SEND(i, text) getglobal("ChatFrame" .. i):AddMessage(text, 1, 1, 1) end
function CHAT_LINES(i) return getglobal("ChatFrame" .. i).lines end
function CHAT_LAST(i) local l = getglobal("ChatFrame" .. i).lines; return l[table.getn(l)] end
function CHAT_RESET()
  for i = 1, 7 do getglobal("ChatFrame" .. i).lines = {}; getglobal("ChatFrame" .. i).scrolled = {} end
end
-- CHAT_UNIT(unite, nom, classe) : un joueur simule (groupe, raid, cible...).
function CHAT_UNIT(unit, name, class)
  W.units[unit] = { name = name, hp = 100, hpMax = 100, mana = 0, manaMax = 0, ptype = 0, level = 60, isPlayer = true, class = class,
    friend = true, canAttack = false, guid = "0xC" .. unit }
end
-- Ligne de joueur comme le client la formate : |Hplayer:Nom|h[Nom]|h
function CHAT_PLAYERLINE(name, msg) return "|Hplayer:" .. name .. "|h[" .. name .. "]|h: " .. msg end
function CHAT_CHANNELLINE(name, msg) return "|Hchannel:Trade|h[2. Trade]|h " .. CHAT_PLAYERLINE(name, msg) end
