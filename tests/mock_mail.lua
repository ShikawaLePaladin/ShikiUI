-- mock_mail : simulation de la boite aux lettres pour le module "mail" (chargee automatiquement par le harnais).
-- Ne contient QUE des noms d'API de WoW 1.12 (relevees dans TurtleMail) et des DONNEES DE TEST.
-- Etat : W.mail. Aides : MAILRESET() MAILADD({ sender, money, cod, item = id, count, text, gm }) MAILOPEN() MAILCLOSE() MAILFREE(n)
-- MAILBOX() (liste "expediteur" restants) MAILINSTALL() (reaffirme les fonctions).
-- Le serveur repond apres W.mail.lag secondes (MAIL_INBOX_UPDATE, MAIL_SEND_SUCCESS) ; lag = nil : jamais de reponse.
-- Reprend le curseur de mock_bags (W.bg.cursor, W.bg.slot).

W.mail = { box = {}, sent = {}, attach = nil, free = 20, lag = 0.1, takes = 0, sendfail = nil, name = "" }

function MAILRESET()
  W.mail.box, W.mail.sent, W.mail.attach, W.mail.free, W.mail.lag, W.mail.takes, W.mail.sendfail, W.mail.name =
    {}, {}, nil, 20, 0.1, 0, nil, ""
end

function MAILADD(t)
  local m = { sender = t.sender or "Alice", money = t.money or 0, cod = t.cod or 0, item = t.item, count = t.count or 1,
    text = t.text, gm = t.gm, subject = t.subject or "x" }
  table.insert(W.mail.box, m)
  return m
end

function MAILBOX()
  local t = {}
  for i = 1, table.getn(W.mail.box) do table.insert(t, W.mail.box[i].sender) end
  return table.concat(t, ",")
end

function MAILFREE(n) W.mail.free = n end
function MAILOPEN() Fire("MAIL_SHOW") end
function MAILCLOSE() Fire("MAIL_CLOSED") end

local function later(fn)
  if W.mail.lag then ShikiUI.After(W.mail.lag, fn, "mock.mail") end
end

function MAILINSTALL()
  -- le sac 0 porte le compteur de places libres du test (le vrai M.BagFree compte via GetContainerNumSlots / GetContainerItemInfo)
  local MM = ShikiUI and ShikiUI.Mail; if MM then MM.BagFreeReal = MM.BagFreeReal or MM.BagFree; MM.BagFree = function(bag) if bag == 0 then return W.mail.free end return 0 end end
  rawset(_G, "SendMailNameEditBox", {
    GetText = function(self) return W.mail.name end,
    SetText = function(self, s) W.mail.name = s end,
  })
  GetInboxNumItems = function() return table.getn(W.mail.box) end
  GetInboxHeaderInfo = function(i)
    local m = W.mail.box[i]
    if not m then return nil end
    return "pkg", "stat", m.sender, m.subject, m.money, m.cod, 10, m.item and 1 or nil, nil, nil, m.text and 1 or nil, 1, m.gm and 1 or nil
  end
  GetInboxItem = function(i)
    local m = W.mail.box[i]
    if not m or not m.item then return nil end
    local info = W.bg.info[m.item]
    return info and info.name or ("Objet" .. m.item), "tex", m.count, 1, 1
  end
  TakeInboxMoney = function(i)
    local m = W.mail.box[i]
    if not m or m.cod > 0 then return end
    W.mail.takes = W.mail.takes + 1
    ACT("TakeInboxMoney " .. i)
    m.money = 0
    later(function() Fire("MAIL_INBOX_UPDATE") end)
  end
  TakeInboxItem = function(i)
    local m = W.mail.box[i]
    if not m or not m.item then return end
    if W.mail.free <= 0 then
      Fire("UI_ERROR_MESSAGE", "Inventory is full.")
      return
    end
    W.mail.takes = W.mail.takes + 1
    ACT("TakeInboxItem " .. i)
    W.mail.free = W.mail.free - 1
    m.item = nil
    later(function() Fire("MAIL_INBOX_UPDATE") end)
  end
  DeleteInboxItem = function(i)
    local m = W.mail.box[i]
    if not m then return end
    ACT("DeleteInboxItem " .. i)
    table.remove(W.mail.box, i)
    later(function() Fire("MAIL_INBOX_UPDATE") end)
  end
  ClearCursor = function()
    local c = W.bg.cursor
    if c and c.item then c.item.held = nil end
    W.bg.cursor = nil
  end
  ClickSendMailItemButton = function()
    local c = W.bg.cursor
    if c and c.bag then
      W.bg.slot[c.bag][c.slot] = nil
      c.item.held = nil
      W.mail.attach = c.item
      W.bg.cursor = nil
    end
  end
  GetSendMailItem = function()
    local a = W.mail.attach
    if not a then return nil end
    local info = W.bg.info[a.id]
    return info and info.name or ("Objet" .. a.id), "tex", a.count, 1
  end
  SendMail = function(to, subject, body)
    if not W.mail.attach then return end
    if W.mail.sendfail then
      Fire("UI_ERROR_MESSAGE", W.mail.sendfail)
      return
    end
    table.insert(W.mail.sent, { to = to, subject = subject, id = W.mail.attach.id, count = W.mail.attach.count })
    ACT("SendMail " .. to)
    W.mail.attach = nil
    later(function() Fire("MAIL_SEND_SUCCESS") end)
  end
end
MAILINSTALL()

-- ---------------------------------------------------------------- vraies doublures de cadres pour la saisie du courrier (additif)
-- MAILFRAME(kind, name, parent, o) : cadre nomme avec strate, niveau, rectangle et souris. o = { level, strata, left, bottom, w, h, mouse, shown }.
-- MAILFRAMES() : MailFrame > SendMailFrame > { nom, objet, scroll > corps } (remplacent les doublures simples) ; UIParent liste ses enfants.
-- MAILFRAMES_OFF() : retire tout et remet les doublures simples (MAILINSTALL).
function MAILFRAME(kind, name, parent, o)
  o = o or {}
  local f = CreateFrame(kind, name, parent or UIParent)
  f.level = o.level or 10
  f.strata = o.strata or "MEDIUM"
  f.left, f.bottom, f.w, f.h = o.left or 100, o.bottom or 100, o.w or 50, o.h or 20
  f.mouse = o.mouse and true or false
  if o.shown == false then f.shown = false end
  f.GetFrameStrata = function(self) return self.strata end
  f.SetFrameStrata = function(self, s) self.strata = s end
  f.GetEffectiveScale = function(self) return 1 end
  return f
end

function MAILFRAMES()
  local uiKids = UIParent.GetChildren
  UIParent.GetChildren = function(self)
    local r = {}
    for i = 1, table.getn(ALLFRAMES) do
      if ALLFRAMES[i].parent == self then r[table.getn(r) + 1] = ALLFRAMES[i] end
    end
    return table.unpack(r)
  end
  W.mail.uiKids = uiKids
  local mf = MAILFRAME("Frame", "MailFrame", UIParent, { level = 10, left = 50, bottom = 100, w = 384, h = 400, mouse = true })
  local sf = MAILFRAME("Frame", "SendMailFrame", mf, { level = 11, left = 60, bottom = 110, w = 360, h = 380 })
  MAILFRAME("EditBox", "SendMailNameEditBox", sf, { level = 12, left = 100, bottom = 400, w = 200, h = 20, mouse = true })
  MAILFRAME("EditBox", "SendMailSubjectEditBox", sf, { level = 12, left = 100, bottom = 370, w = 200, h = 20, mouse = true })
  local sc = MAILFRAME("ScrollFrame", "SendMailScrollFrame", sf, { level = 12, left = 80, bottom = 200, w = 300, h = 150 })
  MAILFRAME("EditBox", "SendMailBodyEditBox", sc, { level = 13, left = 80, bottom = 330, w = 300, h = 20, mouse = true })
  return mf
end

function MAILFRAMES_OFF()
  for _, n in ipairs({ "MailFrame", "SendMailFrame", "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailScrollFrame", "SendMailBodyEditBox" }) do
    local f = rawget(_G, n)
    if f then f.shown = false; f.parent = nil end
    rawset(_G, n, nil)
  end
  if W.mail.uiKids then UIParent.GetChildren = nil end
  W.mail.uiKids = nil
  MAILINSTALL()
end

-- MAILSTRATA(root) : donne une vraie strate (GetFrameStrata / SetFrameStrata) a root et a tous ses descendants.
function MAILSTRATA(root)
  local function under(f)
    local p, d = f, 0
    while p and d < 12 do
      if p == root then return true end
      p = p.parent
      d = d + 1
    end
    return false
  end
  for i = 1, table.getn(ALLFRAMES) do
    local f = ALLFRAMES[i]
    if under(f) and f.kind ~= "Texture" and f.kind ~= "FontString" then
      f.strata = f.strata or "MEDIUM"
      f.GetFrameStrata = function(self) return self.strata end
      f.SetFrameStrata = function(self, s) self.strata = s end
    end
  end
end
