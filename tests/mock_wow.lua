-- mock_wow.lua : API WoW 1.12 simulee pour les tests de ShikiUI (Lua 5.3 de fengari + raccourcis Lua 5.0).
-- Ne contient QUE des noms d'API de WoW 1.12 ou d'extensions connues (SuperWoW / Nampower / UnitXP / ClassicAPI).
-- Les couleurs de classe et valeurs de unites ci-dessous sont des DONNEES DE TEST, pas des donnees de jeu.

-- ---------------------------------------------------------------- raccourcis Lua 5.0
string.gfind = string.gmatch
tinsert = table.insert
tremove = table.remove
table.getn = function(t) return #t end
getglobal = function(n) return rawget(_G, n) end
setglobal = function(n, v) rawset(_G, n, v) end
_G._G = _G
gcinfo = function() return W.gc, 4096 end

LOG = {}
NOW = 1000
GetTime = function() return NOW end

-- ---------------------------------------------------------------- monde simule
W = {
  units = {},          -- id -> { name, hp, hpMax, mana, manaMax, ptype, level, isPlayer, class, friend, canAttack, enemy, dead, ghost,
                       --         offline, tapped, tappedByMe, guid, dist, sight, behind, pos = {x,y,z} }
  combat = false, fps = 60, lat = 50, gc = 2048, realm = "TestRealm", locale = "frFR",
  spellTargeting = false, cursorItem = false, interact = {},   -- interact[unit] = 3 | 4 | nil : distance de CheckInteractDistance
  sw = false,          -- SuperWoW : UnitExists renvoie aussi le GUID
  acts = {},           -- actions realisees (TargetUnit, SpellTargetUnit, DropItemOnUnit, SetMouseover...)
}
function ACT(s) table.insert(W.acts, s) end
function LASTACT() return W.acts[table.getn(W.acts)] end

function MKPLAYER()
  W.units.player = { name = "Shikiwa", hp = 5000, hpMax = 5000, mana = 3000, manaMax = 3000, ptype = 0, level = 60,
    isPlayer = true, class = "PALADIN", friend = true, canAttack = false, guid = "0xP1", pos = { 0, 0, 0 } }
end
function MKTARGET(t)
  local d = { name = "Cible", hp = 100, hpMax = 100, mana = 0, manaMax = 0, ptype = 0, level = 61, isPlayer = false,
    friend = false, canAttack = true, enemy = true, guid = "0xT1", dist = 12, sight = true, pos = { 10, 0, 0 } }
  for k, v in pairs(t or {}) do d[k] = v end
  W.units.target = d
  return d
end
function MKTOT(t)
  local d = { name = "Tank", hp = 8000, hpMax = 9000, mana = 0, manaMax = 0, ptype = 1, level = 60, isPlayer = true,
    class = "WARRIOR", friend = true, canAttack = false, guid = "0xT2" }
  for k, v in pairs(t or {}) do d[k] = v end
  W.units.targettarget = d
  return d
end

local function U(u) return W.units[u] end
UnitExists = function(u)
  local x = U(u)
  if not x then return nil end
  if W.sw then return 1, x.guid end
  return 1
end
UnitName = function(u) local x = U(u); return x and x.name or nil end
UnitLevel = function(u) local x = U(u); return x and x.level or 0 end
UnitHealth = function(u) local x = U(u); return x and x.hp or 0 end
UnitHealthMax = function(u) local x = U(u); return x and x.hpMax or 0 end
UnitMana = function(u) local x = U(u); return x and x.mana or 0 end
UnitManaMax = function(u) local x = U(u); return x and x.manaMax or 0 end
UnitPowerType = function(u) local x = U(u); return x and x.ptype or 0 end
UnitIsPlayer = function(u) local x = U(u); return (x and x.isPlayer) and 1 or nil end
UnitClass = function(u) local x = U(u); if not x or not x.class then return nil end return x.class, x.class end
UnitCanAttack = function(a, u) local x = U(u); return (x and x.canAttack) and 1 or nil end
UnitIsFriend = function(a, u) local x = U(u); return (x and x.friend) and 1 or nil end
UnitIsEnemy = function(a, u) local x = U(u); return (x and x.enemy) and 1 or nil end
UnitIsTapped = function(u) local x = U(u); return (x and x.tapped) and 1 or nil end
UnitIsTappedByPlayer = function(u) local x = U(u); return (x and x.tappedByMe) and 1 or nil end
UnitIsDeadOrGhost = function(u) local x = U(u); return (x and (x.dead or x.ghost)) and 1 or nil end
UnitIsGhost = function(u) local x = U(u); return (x and x.ghost) and 1 or nil end
UnitIsConnected = function(u) local x = U(u); return (x and not x.offline) and 1 or nil end
UnitAffectingCombat = function(u) if u == "player" then return W.combat and 1 or nil end return nil end
CheckInteractDistance = function(u, i) return (W.interact[u] and i >= W.interact[u]) and 1 or nil end
-- interact[unit] = 3 : a portee des deux bandes (3 et 4) ; = 4 : seulement la bande 4. (i >= valeur) -> cf. ci-dessus : 3 -> bande 3 et 4 ; 4 -> bande 4 seule.
GetFramerate = function() return W.fps end
GetNetStats = function() return 10, 5, W.lat end
GetRealmName = function() return W.realm end
GetLocale = function() return W.locale end

TargetUnit = function(u) ACT("TargetUnit " .. u) end
SpellIsTargeting = function() return W.spellTargeting and 1 or nil end
SpellTargetUnit = function(u) ACT("SpellTargetUnit " .. u) end
CursorHasItem = function() return W.cursorItem and 1 or nil end
DropItemOnUnit = function(u) ACT("DropItemOnUnit " .. u) end
ToggleDropDownMenu = function(l, v, dd, anchor) ACT("Dropdown " .. tostring(dd and dd:GetName())) end

RAID_CLASS_COLORS = {
  PALADIN = { r = 0.9, g = 0.5, b = 0.7 }, WARRIOR = { r = 0.7, g = 0.6, b = 0.4 }, MAGE = { r = 0.4, g = 0.8, b = 0.9 },
}

-- ---------------------------------------------------------------- extensions (installables / retirables par les tests)
EXT = {}
function EXT.superwow(on)
  W.sw = on and true or false
  if on then
    SUPERWOW_VERSION = "1.5"
    SetAutoloot = function() end
    SpellInfo = function() end
    UnitPosition = function(u) local x = U(u); if not x or not x.pos then return nil end return x.pos[1], x.pos[2], x.pos[3] end
  else
    SUPERWOW_VERSION, SetAutoloot, SpellInfo, UnitPosition = nil, nil, nil, nil
  end
end
function EXT.nampower(on, major)
  if on then
    GetNampowerVersion = function() return major or 3, 0, 1 end
    GetUnitGUID = function(u) local x = U(u); return x and x.guid or nil end
    SetMouseoverUnit = function(u) ACT("Mouseover " .. tostring(u)) end
  else
    GetNampowerVersion, GetUnitGUID, SetMouseoverUnit = nil, nil, nil
  end
end
-- mode "real" : UnitXP d'extension ; "vanilla" : UnitXP(unit) = experience (ignore les arguments inconnus) ; "greedy" : repond 1 a tout.
function EXT.unitxp(mode)
  if mode == "real" then
    UnitXP = function(cmd, a, b)
      if cmd == "nop" then return true end
      if cmd == "version" then return 1700000000 end
      local x = U(b)
      if cmd == "distanceBetween" then return x and x.dist or nil end
      if cmd == "inSight" then if not x then return nil end return x.sight ~= false end
      if cmd == "behind" then if not x then return nil end return x.behind and true or false end
      return nil
    end
  elseif mode == "vanilla" then
    UnitXP = function(unit) if unit == "player" then return 1234 end return 0 end
  elseif mode == "greedy" then
    UnitXP = function() return 1 end
  elseif mode == "throws" then
    UnitXP = function() error("UnitXP indisponible") end
  else
    UnitXP = nil
  end
end
function EXT.classic(version)
  CLASSIC_API_VERSION = version
  C_NamePlate = version and { GetNamePlateGUIDs = function() return {} end } or nil
end
function EXT.none()
  EXT.superwow(false); EXT.nampower(false); EXT.unitxp(nil); EXT.classic(nil)
  ShikiwaRotation, ShikaSwap, ShikiwaSignal, IsAddOnLoaded = nil, nil, nil, nil
end

-- ---------------------------------------------------------------- chat, commandes
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) table.insert(CHAT, m) end }
function CHATTEXT() return table.concat(CHAT, "\n") end
function CHATCLEAR() CHAT = {} end
SlashCmdList = {}
UISpecialFrames = {}

-- ---------------------------------------------------------------- widgets (liste blanche des methodes 1.12)
local WOW112 = {}
for w in string.gmatch([[SetWidth GetWidth SetHeight GetHeight SetPoint GetPoint GetNumPoints ClearAllPoints SetAllPoints Show Hide IsShown IsVisible SetAlpha GetAlpha SetParent GetParent GetName GetLeft GetRight GetTop GetBottom GetCenter SetScript GetScript RegisterEvent UnregisterEvent UnregisterAllEvents IsEventRegistered SetFrameStrata GetFrameStrata SetFrameLevel GetFrameLevel SetMovable IsMovable SetResizable EnableMouse IsMouseEnabled EnableMouseWheel EnableKeyboard IsKeyboardEnabled RegisterForDrag StartMoving StopMovingOrSizing StartSizing SetBackdrop SetBackdropColor SetBackdropBorderColor GetBackdrop CreateTexture CreateFontString SetScale GetScale GetEffectiveScale SetToplevel SetClampedToScreen SetHitRectInsets IsObjectType GetObjectType GetChildren GetRegions GetNumChildren GetNumRegions SetID GetID Raise Lower SetMinResize SetMaxResize SetUserPlaced SetTexture GetTexture SetTexCoord GetTexCoord SetVertexColor SetBlendMode SetDesaturated SetGradient SetGradientAlpha SetDrawLayer GetDrawLayer SetText GetText SetFont GetFont SetFontObject GetFontObject SetTextColor SetJustifyH SetJustifyV SetShadowColor SetShadowOffset GetStringWidth GetStringHeight SetNonSpaceWrap SetTextHeight GetTextHeight SetNormalTexture SetPushedTexture SetHighlightTexture SetDisabledTexture GetNormalTexture GetPushedTexture GetHighlightTexture GetDisabledTexture RegisterForClicks Enable Disable IsEnabled Click LockHighlight UnlockHighlight SetTextFontObject GetFontString SetNormalFontObject SetHighlightFontObject SetDisabledFontObject SetChecked GetChecked SetCheckedTexture GetCheckedTexture SetDisabledCheckedTexture SetMinMaxValues GetMinMaxValues SetValue GetValue SetValueStep GetValueStep SetOrientation GetOrientation SetThumbTexture GetThumbTexture SetStatusBarTexture SetStatusBarColor GetStatusBarTexture GetStatusBarColor SetAutoFocus SetFocus ClearFocus HasFocus SetMaxLetters SetMaxBytes SetNumeric SetNumber GetNumber SetMultiLine SetTextInsets HighlightText Insert SetPassword SetAltArrowKeyMode SetOwner AddLine AddDoubleLine SetInventoryItem SetHyperlink ClearLines SetUnitBuff SetUnitDebuff NumLines SetBagItem SetUnit SetSpell SetAction SetScrollChild SetVerticalScroll GetVerticalScroll GetVerticalScrollRange UpdateScrollChildRect SetModel SetTimeVisible SetMaxLines AddMessage SetFading SetFadeDuration SetHyperlinksEnabled GetNumLines]], "%S+") do WOW112[w] = true end

ALLFRAMES = {}
CREATED = 0          -- nombre de CreateFrame / CreateTexture / CreateFontString (pour les tests "pas de creation en combat")
local newFrame
local function script(self, name)
  local fn = self.scripts[name]
  if fn then
    local o, oa = this, arg1
    this = self
    fn()
    this, arg1 = o, oa
  end
end

newFrame = function(name, kind, parent)
  CREATED = CREATED + 1
  local f = { scripts = {}, name = name, shown = true, events = {}, kind = kind, points = {}, parent = parent, scale = 1,
    alpha = 1, w = 0, h = 0, level = 1, value = 0, minv = 0, maxv = 1, text = "", id = CREATED, calls = {} }
  setmetatable(f, { __index = function(t, k)
    if type(k) == "string" and string.find(k, "^%u") then
      if not WOW112[k] then error("API absente de WoW 1.12 : " .. k, 2) end
      return function(self, a, b, c, d, e) self.calls[k] = { a, b, c, d, e }; return self end
    end
    return nil end })
  f.SetScript = function(self, k, fn) self.scripts[k] = fn end
  f.GetScript = function(self, k) return self.scripts[k] end
  f.RegisterEvent = function(self, ev) self.events[ev] = true end
  f.UnregisterEvent = function(self, ev) self.events[ev] = nil end
  f.UnregisterAllEvents = function(self) self.events = {} end
  f.IsEventRegistered = function(self, ev) return self.events[ev] and 1 or nil end
  f.CreateFontString = function(self) return newFrame(nil, "FontString", self) end
  f.CreateTexture = function(self) return newFrame(nil, "Texture", self) end
  f.IsShown = function(self) return self.shown end
  f.IsVisible = function(self)
    local p = self
    while p do
      if not p.shown then return false end
      p = p.parent
    end
    return true
  end
  f.Show = function(self)
    if not self.shown then
      self.shown = true
      script(self, "OnShow")
    end
  end
  f.Hide = function(self)
    if self.shown then
      self.shown = false
      script(self, "OnHide")
    end
  end
  f.GetText = function(self) return self.text end
  f.SetText = function(self, t)
    if t == nil then error("SetText(nil)", 2) end
    local old = self.text
    self.text = t
    if self.kind == "EditBox" and old ~= t then script(self, "OnTextChanged") end
  end
  f.SetMinMaxValues = function(self, a, b) self.minv = a; self.maxv = b end
  f.GetMinMaxValues = function(self) return self.minv, self.maxv end
  f.GetValue = function(self) return self.value end
  f.SetValueStep = function(self, s) self.step = s end
  f.SetValue = function(self, v)
    if type(v) ~= "number" then error("SetValue(non number)", 2) end
    if v < self.minv then v = self.minv end
    if v > self.maxv then v = self.maxv end
    local changed = (v ~= self.value)
    self.value = v
    if changed and self.kind == "Slider" then script(self, "OnValueChanged") end
  end
  f.SetPoint = function(self, point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    table.insert(self.points, { point, rel, relPoint, x, y })
  end
  f.ClearAllPoints = function(self) self.points = {} end
  f.GetNumPoints = function(self) return table.getn(self.points) end
  f.GetPoint = function(self, i) local p = self.points[i or 1]; if not p then return nil end return p[1], p[2], p[3], p[4], p[5] end
  f.SetAllPoints = function(self, rel) self.points = { { "ALLPOINTS", rel } } end
  f.SetWidth = function(self, w) self.w = w end
  f.SetHeight = function(self, h) self.h = h end
  f.GetWidth = function(self) return self.w end
  f.GetHeight = function(self) return self.h end
  f.SetScale = function(self, s) self.scale = s end
  f.GetScale = function(self) return self.scale end
  f.GetEffectiveScale = function(self) return self.scale end
  f.SetAlpha = function(self, a) self.alpha = a end
  f.GetAlpha = function(self) return self.alpha end
  f.SetFrameLevel = function(self, l) self.level = l end
  f.GetFrameLevel = function(self) return self.level end
  f.GetLeft = function(self) return self.left or 100 end
  f.GetBottom = function(self) return self.bottom or 100 end
  f.GetRight = function(self) return (self.left or 100) + self.w end
  f.GetTop = function(self) return (self.bottom or 100) + self.h end
  f.GetCenter = function(self) return 0, 0 end
  f.GetParent = function(self) return self.parent end
  f.GetName = function(self) return self.name end
  f.GetObjectType = function(self) return self.kind end
  f.IsObjectType = function(self, t) return self.kind == t end
  f.EnableMouse = function(self, v) self.mouse = v and true or false end
  f.IsMouseEnabled = function(self) return self.mouse and 1 or nil end
  f.StartMoving = function(self) self.moving = true end
  f.StopMovingOrSizing = function(self) self.moving = false end
  f.SetMovable = function(self, v) self.movable = v and true or false end
  f.IsMovable = function(self) return self.movable and 1 or nil end
  f.SetStatusBarColor = function(self, r, g, b, a) self.sbc = { r, g, b, a } end
  f.GetStatusBarColor = function(self) local c = self.sbc or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
  f.SetVertexColor = function(self, r, g, b, a) self.vc = { r, g, b, a } end
  f.SetTextColor = function(self, r, g, b, a) self.tc = { r, g, b, a } end
  f.SetThumbTexture = function(self) self.thumb = self.thumb or newFrame(nil, "Texture", self) end
  f.GetThumbTexture = function(self) self.thumb = self.thumb or newFrame(nil, "Texture", self); return self.thumb end
  f.SetVerticalScroll = function(self, v) self.vscroll = v end
  f.GetVerticalScroll = function(self) return self.vscroll or 0 end
  f.SetScrollChild = function(self, c) self.scrollChild = c end
  f.SetFocus = function(self) self.focus = true end
  f.ClearFocus = function(self) self.focus = false end
  f.HasFocus = function(self) return self.focus and 1 or nil end
  f.GetStringWidth = function(self) return string.len(self.text or "") * 6 end
  f.Click = function(self, btn)
    local o = arg1
    arg1 = btn or "LeftButton"
    script(self, "OnClick")
    arg1 = o
  end
  f.SetBackdrop = function(self, b) self.backdrop = b end
  f.SetBackdropBorderColor = function(self, r, g, b, a) self.bbc = { r, g, b, a } end
  f.SetBackdropColor = function(self, r, g, b, a) self.bgc = { r, g, b, a } end
  f.SetFont = function(self, face, size, flags)
    if type(face) ~= "string" or type(size) ~= "number" then error("SetFont : arguments invalides", 2) end
    self.font, self.fsize, self.fflags = face, size, flags
  end
  -- infobulle (GameTooltip) : on enregistre ce qui est demande
  f.SetOwner = function(self, o, anchor) self.owner = o; self.lines = {} end
  f.SetUnit = function(self, u) self.unit = u end
  f.SetText = (kind == "GameTooltip") and function(self, t) self.lines = { t } end or f.SetText
  f.AddLine = function(self, t) self.lines = self.lines or {}; table.insert(self.lines, t) end
  table.insert(ALLFRAMES, f)
  return f
end

CreateFrame = function(kind, name, parent, tmpl)
  local f = newFrame(name, kind, parent)
  if name then rawset(_G, name, f) end
  -- comme le client : les cadres dont le parent est ce cadre (cree apres)
  f.GetChildren = function(self)
    local r = {}
    for i = 1, table.getn(ALLFRAMES) do
      if ALLFRAMES[i].parent == self then r[table.getn(r) + 1] = ALLFRAMES[i] end
    end
    return table.unpack(r)
  end
  return f
end
UIParent = newFrame("UIParent", "Frame")
UIParent.GetHeight = function() return 1080 end
UIParent.GetWidth = function() return 1920 end
WorldFrame = newFrame("WorldFrame", "Frame")   -- les plaques de nom sont ses enfants (voir mock_target.lua)
PlayerFrame = nil
TargetFrame = nil

-- Evenements : envoyes a TOUTES les frames qui les ont enregistres, comme le client
function Fire(ev, a1, a2, a3, a4, a5)
  local so = { event, arg1, arg2, arg3, arg4, arg5 }
  event = ev; arg1, arg2, arg3, arg4, arg5 = a1, a2, a3, a4, a5
  for i = 1, table.getn(ALLFRAMES) do
    local f = ALLFRAMES[i]
    if f.events[ev] and f.scripts.OnEvent then
      this = f
      f.scripts.OnEvent()
    end
  end
  event, arg1, arg2, arg3, arg4, arg5 = so[1], so[2], so[3], so[4], so[5], so[6]
end
-- Horloge : fait avancer le temps et appelle les OnUpdate des frames affichees
function Pump(dt, n)
  for _ = 1, (n or 1) do
    NOW = NOW + dt
    for i = 1, table.getn(ALLFRAMES) do
      local f = ALLFRAMES[i]
      if f.shown and f.scripts.OnUpdate then
        this = f
        arg1 = dt
        f.scripts.OnUpdate()
      end
    end
  end
end
-- Clic / survol simules
function Click(f, btn) f:Click(btn) end
function Hover(f, on)
  this = f
  local fn = f.scripts[on and "OnEnter" or "OnLeave"]
  if fn then fn() end
end

-- ---------------------------------------------------------------- mode strict
local OPTIONAL = {
  SUPERWOW_VERSION = true, SetAutoloot = true, SpellInfo = true, UnitPosition = true, GetNampowerVersion = true,
  GetUnitGUID = true, SetMouseoverUnit = true, CLASSIC_API_VERSION = true, C_NamePlate = true, UnitXP = true,
  pfUI = true, pfUI_config = true,
  ShikaSwap = true, ShikiwaRotation = true, ShikiwaSignal = true, IsAddOnLoaded = true, GameTooltip = true,
  event = true, this = true, arg1 = true, arg2 = true, arg3 = true, arg4 = true, arg5 = true,
  IsSpellInRange = true, TargetNearestEnemyPlayer = true, TargetLastTarget = true,
  CheckInteractDistance = true, _ERRORMESSAGE = true, time = true, ShikiUIDB = true, ShikiUI = true, TESTS_DONE = true, PlayerFrame = true, TargetFrame = true, TargetofTargetFrame = true,
}
function STRICT_ON()
  setmetatable(_G, { __index = function(t, k)
    if OPTIONAL[k] or (type(k) == "string" and (string.find(k, "^SLASH_") or string.find(k, "^ShikiUI"))) then return nil end
    error("globale non definie lue : " .. tostring(k), 2)
  end, __newindex = function(t, k, v)
    if type(k) == "string" and not (OPTIONAL[k] or string.find(k, "^SLASH_") or string.find(k, "^ShikiUI")) and not ALLOW_NEW[k] then
      error("ecriture d'une globale non declaree : " .. tostring(k), 2)
    end
    rawset(t, k, v)
  end })
end
-- globales que les tests (ou le mock) ont le droit de creer apres STRICT_ON
ALLOW_NEW = { }
function ALLOW(name) ALLOW_NEW[name] = true end
function STRICT_OFF() setmetatable(_G, nil) end
