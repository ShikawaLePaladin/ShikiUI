-- mock_messages : simulation du chat prive pour le module "messages" (chargee automatiquement, AVANT le mode strict).
-- Rien n'est modifie au chargement : MSG_SETUP() (appele par t_messages.lua seulement) pose les fonctions du client.
-- Noms d'API de WoW 1.12 releves dans WIM et pfUI : SendChatMessage, ChatFrame_OnEvent, ChatFrame_ReplyTell, ChatEdit_SetLastTellTarget,
-- ChatEdit_GetLastTellTarget, ChatFrameEditBox, SetItemRef, UnitIsAFK, PlaySound, date, time, ScrollingMessageFrame (AddMessage, Clear,
-- ScrollUp, ScrollDown, ScrollToBottom). Valeurs = DONNEES DE TEST.
-- Aides : MSG_DRAG(source, cadre, dl, db, touche) (appui, deplacement du cadre a (dl, db), relache) MSG_WHISPER(nom, texte) MSG_INFORM(nom, texte) MSG_TYPE(fenetre, texte) MSG_CHATEVENT(evenement, texte, nom)
-- MSG_COMBAT(on) MSG_SENT() (nombre de SendChatMessage) MSG_LAST() MSG_LINES(frame) (texte des lignes d'un cadre de messages).
ALLOW("MSGW")

function MSG_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  MSGW = { sent = {}, chatEv = {}, sounds = {}, refs = {}, afk = false, dnd = false, lastTell = nil, reply = "", now = 1700000000,
    replies = {}, sendTells = {}, mods = {} }
  G("time", function() return MSGW.now end)
  if rawget(_G, "date") == nil then G("date", function(fmt, ts)
    local s = fmt
    s = string.gsub(s, "%%H", "14")
    s = string.gsub(s, "%%M", "05")
    s = string.gsub(s, "%%S", "09")
    s = string.gsub(s, "%%d", "07")
    s = string.gsub(s, "%%m", "03")
    return s
  end) end
  G("SendChatMessage", function(text, chan, lang, to) table.insert(MSGW.sent, { text = text, chan = chan, to = to }) end)
  G("PlaySound", function(name) table.insert(MSGW.sounds, name) end)
  G("UnitIsAFK", function(u) return MSGW.afk and 1 or nil end)
  G("UnitIsDND", function(u) return MSGW.dnd and 1 or nil end)
  G("ChatFrame_OnEvent", function(ev) table.insert(MSGW.chatEv, ev or event) end)
  G("ChatFrame_ReplyTell", function(cf) table.insert(MSGW.replies, "orig") end)
  G("ChatFrame_SendTell", function(name) table.insert(MSGW.sendTells, name) end)
  G("ChatEdit_SetLastTellTarget", function(eb, n) MSGW.lastTell = n end)
  G("ChatEdit_GetLastTellTarget", function(eb) return MSGW.reply end)
  G("IsShiftKeyDown", function() return MSGW.mods.shift and 1 or nil end)
  G("IsControlKeyDown", function() return MSGW.mods.ctrl and 1 or nil end)
  G("IsAltKeyDown", function() return MSGW.mods.alt and 1 or nil end)
  G("ChatFrameEditBox", {})
  G("SetItemRef", function(link, text, button) table.insert(MSGW.refs, link) end)
  local orig = CreateFrame
  G("CreateFrame", function(kind, name, parent, tmpl)
    local f = orig(kind, name, parent, tmpl)
    if kind == "ScrollingMessageFrame" then
      f.lines = {}
      f.scrolls = 0
      f.AddMessage = function(self, t) table.insert(self.lines, t) end
      f.Clear = function(self) self.lines = {} end
      f.ScrollUp = function(self) self.scrolls = self.scrolls + 1 end
      f.ScrollDown = function(self) self.scrolls = self.scrolls - 1 end
      f.ScrollToBottom = function(self) self.scrolls = 0 end
    end
    return f
  end)
end

function MSG_WHISPER(name, text) Fire("CHAT_MSG_WHISPER", text, name) end
function MSG_INFORM(name, text) Fire("CHAT_MSG_WHISPER_INFORM", text, name) end

function MSG_TYPE(slot, text)
  local w = ShikiUI.Messages.win[slot]
  w.edit:SetText(text)
  this = w.edit
  w.edit.scripts.OnEnterPressed()
end

-- Appelle le ChatFrame_OnEvent global comme le client (variables globales event / arg1 / arg2).
function MSG_CHATEVENT(ev, text, name)
  local so, s1, s2 = event, arg1, arg2
  event, arg1, arg2 = ev, text, name
  ChatFrame_OnEvent(ev)
  event, arg1, arg2 = so, s1, s2
end

function MSG_COMBAT(on)
  W.combat = on and true or false
  Fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

function MSG_SENT() return table.getn(MSGW.sent) end
function MSG_LAST() return MSGW.sent[table.getn(MSGW.sent)] end
function MSG_LINES(f) return table.concat(f.lines, "\n") end

-- Glisser a la souris : appui sur 'src' (touche modificatrice 'mod' : "shift" "ctrl" "alt" ou nil), le moteur deplace 'frame' en (left, bottom), relache.
-- Retourne vrai si le deplacement a demarre (frame.moving).
function MSG_DRAG(src, frame, left, bottom, mod)
  MSGW.mods = {}
  if mod then MSGW.mods[mod] = true end
  local so, sa = this, arg1
  this, arg1 = src, "LeftButton"
  src.scripts.OnMouseDown()
  local started = frame.moving and true or false
  if started then frame.left, frame.bottom = left, bottom end
  src.scripts.OnMouseUp()
  this, arg1 = so, sa
  MSGW.mods = {}
  return started
end
