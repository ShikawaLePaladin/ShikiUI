-- ShikiUI Units : cadres joueur / cible / cible de la cible (v0.1).
-- Evenements via le routeur central, rafraichissement groupe par une minuterie partagee (drapeaux 'dirty'),
-- aucune creation d'objet en combat, cible de la cible lue par sondage (pas d'evenement fiable en 1.12).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local T = SUI.Theme
local U = {}
SUI.Units = U

local getn = table.getn
local floor = math.floor

U.frames = {}
U.order = { "player", "target", "targettarget", "pet" }
U.cfgName = { player = "player", target = "target", targettarget = "tot", pet = "pet" }
U.built = false
U.active = false
U.dirty = false
U.animating = false
U.blizzHidden = false

local TOT_RATIO = 0.6
local PET_RATIO = 0.8
local FLUSH = 0.05
local POLL_TOT = 0.2
local POLL_RANGE = 0.25
local BLIZZ = { "PlayerFrame", "TargetFrame", "TargetofTargetFrame", "PetFrame" }

-- couleurs d'interface (choix de style, pas des donnees de jeu)
local COL_GRAY = { 0.55, 0.55, 0.55 }
local COL_FRIEND = { 0.35, 0.75, 0.45 }
local COL_ENEMY = { 0.85, 0.25, 0.25 }
local COL_NEUTRAL = { 0.90, 0.78, 0.30 }
local POWER_COL = {
	[0] = { 0.25, 0.45, 0.95 },   -- mana
	[1] = { 0.85, 0.22, 0.22 },   -- rage
	[2] = { 0.90, 0.50, 0.20 },   -- focus
	[3] = { 0.95, 0.85, 0.25 },   -- energie
}

-- valeurs lues depuis la config (mises a jour par U.ReadConfig)
local cfg = { classcolor = true, showpower = true, hptext = "percent", range = true, smooth = true, incheal = true }

function U.ReadConfig()
	local C = SUI.Config
	cfg.classcolor = C.Get("units.classcolor")
	cfg.showpower = C.Get("units.showpower")
	cfg.hptext = C.Get("units.hptext")
	cfg.range = C.Get("units.range")
	cfg.smooth = C.Get("units.smooth") and not SUI.emergency
	cfg.incheal = C.Get("units.incheal")
end

function U.Enabled(unit)
	return SUI.Config.Get("units." .. U.cfgName[unit] .. ".enabled")
end

local function abbrev(n)
	if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
	if n >= 10000 then return string.format("%.0fk", n / 1000) end
	if n >= 1000 then return string.format("%.1fk", n / 1000) end
	return tostring(floor(n))
end
U.Abbrev = abbrev

-- En 1.12 la vie des unites hostiles est un POURCENTAGE (maximum 100) : on n'affiche alors que le pourcentage.
function U.HpString(mode, hp, max)
	if mode == "none" then return "" end
	local pct = (max > 0) and floor(hp / max * 100 + 0.5) or 0
	if max == 100 then return pct .. "%" end
	if mode == "value" then return abbrev(hp) end
	if mode == "percent" then return pct .. "%" end
	return abbrev(hp) .. " | " .. pct .. "%"
end

function U.UnitColor(unit)
	if UnitIsPlayer(unit) then
		if cfg.classcolor then
			local _, class = UnitClass(unit)
			local col = class and RAID_CLASS_COLORS[class]
			if col then return col.r, col.g, col.b end
		end
		if UnitCanAttack("player", unit) then return COL_ENEMY[1], COL_ENEMY[2], COL_ENEMY[3] end
		return COL_FRIEND[1], COL_FRIEND[2], COL_FRIEND[3]
	end
	if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then return COL_GRAY[1], COL_GRAY[2], COL_GRAY[3] end
	if UnitIsFriend("player", unit) then return COL_FRIEND[1], COL_FRIEND[2], COL_FRIEND[3] end
	if UnitCanAttack("player", unit) then
		if UnitIsEnemy("player", unit) then return COL_ENEMY[1], COL_ENEMY[2], COL_ENEMY[3] end
		return COL_NEUTRAL[1], COL_NEUTRAL[2], COL_NEUTRAL[3]
	end
	return COL_FRIEND[1], COL_FRIEND[2], COL_FRIEND[3]
end

-- ---------------------------------------------------------------- mise a jour d'un cadre
function U.UpdateHealth(f)
	local unit = f.unit
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	local ratio = (max > 0) and (hp / max) or 0
	if f.dead then ratio = 0 end
	if cfg.smooth and f.drawn then
		f.goal = ratio
		f.anim = true
	else
		f.cur = ratio
		f.goal = ratio
		f.anim = false
		f.hp:SetValue(ratio)
	end
	f.drawn = true
	local txt = ""
	if f.dead or f.offline then
		txt = ""
	else
		txt = U.HpString(cfg.hptext, hp, max)
	end
	f.hpText:SetText(txt)
	-- Pre-soin (soins entrants) : barre translucide par-dessus la vie, jamais au-dela du plein
	if f.heal then
		local inc = 0
		if cfg.incheal and not f.dead and SUI.UnitsIncoming then
			inc = SUI.UnitsIncoming(unit, UnitName(unit) or "", SUI.Api.GUID(unit)) or 0
		end
		local hv = ratio
		if inc > 0 and max > 0 then
			hv = (hp + inc) / max
			if hv > 1 then hv = 1 end
		end
		f.heal:SetValue(hv)
	end
	f.lhp, f.lmx = hp, max
end

function U.UpdatePower(f)
	if f.noPower then return end
	local unit = f.unit
	local max = UnitManaMax(unit)
	if not cfg.showpower or max <= 0 or f.dead or f.offline then
		f.pw:Hide()
		return
	end
	f.pw:Show()
	local ptype = UnitPowerType(unit)
	local col = POWER_COL[ptype] or COL_GRAY
	f.pw:SetStatusBarColor(col[1], col[2], col[3], 1)
	f.pw:SetValue(UnitMana(unit) / max)
end

function U.Refresh(f)
	local unit = f.unit
	local name = UnitName(unit) or ""
	f.dead = UnitIsDeadOrGhost(unit) and true or false
	f.offline = (UnitIsPlayer(unit) and not UnitIsConnected(unit)) and true or false
	local prefix = ""
	if unit ~= "player" then
		local lv = UnitLevel(unit)
		if lv and lv > 0 then prefix = lv .. " " elseif lv == -1 then prefix = "?? " end
	end
	f.nameText:SetText(prefix .. name)
	if f.snap then
		f.drawn = false          -- nouvelle unite : la barre saute a la bonne valeur au lieu de glisser depuis l'ancienne
		f.snap = false
	end
	local r, g, b = U.UnitColor(unit)
	f.hp:SetStatusBarColor(r, g, b, 1)
	if f.heal then f.heal:SetStatusBarColor(T.c.good[1], T.c.good[2], T.c.good[3], 0.45) end
	if f.dead then
		f.statusText:SetText(UnitIsGhost(unit) and L("unit.ghost") or L("unit.dead"))
	elseif f.offline then
		f.statusText:SetText(L("unit.offline"))
	else
		f.statusText:SetText("")
	end
	U.UpdateHealth(f)
	U.UpdatePower(f)
	f.lnm = name
end

function U.UpdateVisibility(f)
	local unit = f.unit
	local want = U.active and U.Enabled(unit) and (unit == "player" or UnitExists(unit)) and true or false
	if want ~= f.vis then
		f.vis = want
		if want then f:Show() else f:Hide() end
		if want then
			f.dAll = true
			f.snap = true
		end
	end
	return want
end

function U.MarkAll()
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f then f.dAll = true end
	end
	U.dirty = true
end

-- Appele par le moteur de groupe (Mod_Group) quand un montant de soin entrant change : joueur et cible relisent.
SUI.UnitsHealNotify = function()
	local any = false
	local p, t = U.frames.player, U.frames.target
	if p and p.vis then p.dHp = true any = true end
	if t and t.vis then t.dHp = true any = true end
	if any then U.dirty = true end
end

-- Boucle de rafraichissement groupe (minuterie partagee, ralentie en mode urgence).
function U.Flush()
	if not U.dirty and not U.animating then return end
	U.dirty = false
	local anim = false
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f then
			if f.dAll then
				f.dAll, f.dHp, f.dPw = false, false, false
				if U.UpdateVisibility(f) then U.Refresh(f) end
			elseif f.vis then
				if f.dHp then
					f.dHp = false
					U.UpdateHealth(f)
				end
				if f.dPw then
					f.dPw = false
					U.UpdatePower(f)
				end
			end
			if f.anim then
				local d = f.goal - f.cur
				if d < 0.004 and d > -0.004 then
					f.cur = f.goal
					f.anim = false
				else
					f.cur = f.cur + d * 0.35
				end
				f.hp:SetValue(f.cur)
				if f.anim then anim = true end
			end
		end
	end
	U.animating = anim
end

-- ---------------------------------------------------------------- evenements
local HP_EV = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true }
local PW_EV = { UNIT_MANA = true, UNIT_MAXMANA = true, UNIT_RAGE = true, UNIT_MAXRAGE = true, UNIT_ENERGY = true,
	UNIT_MAXENERGY = true, UNIT_FOCUS = true, UNIT_MAXFOCUS = true }
local ALL_EV = { UNIT_DISPLAYPOWER = true, UNIT_NAME_UPDATE = true, UNIT_LEVEL = true, UNIT_FLAGS = true, UNIT_FACTION = true }

local function onUnitEvent(ev, a1)
	if ev == "UNIT_PET" and a1 == "player" then
		local pf = U.frames.pet
		if pf then pf.dAll = true ; U.dirty = true end
		return
	end
	local f = U.frames[a1]
	if not f or not f.vis then return end
	if HP_EV[ev] then f.dHp = true
	elseif PW_EV[ev] then f.dPw = true
	elseif ALL_EV[ev] then f.dAll = true
	else return end
	U.dirty = true
end

local function onTargetChanged()
	local t, tt = U.frames.target, U.frames.targettarget
	if t then t.dAll = true; t.snap = true; t.rangeTxt = nil end
	if tt then tt.dAll = true; tt.snap = true end
	U.dirty = true
	U.PollRange()
end

local function onPlayerState()
	local p = U.frames.player
	if p then p.dAll = true end
	U.dirty = true
end

local function onWorld()
	U.MarkAll()
	U.dirty = true
end

local UNIT_EVENTS = { "UNIT_PET", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_MANA", "UNIT_MAXMANA", "UNIT_RAGE", "UNIT_MAXRAGE",
	"UNIT_ENERGY", "UNIT_MAXENERGY", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FLAGS", "UNIT_FACTION" }

-- ---------------------------------------------------------------- sondages (cible de la cible, distance)
function U.PollTot()
	local f = U.frames.targettarget
	if not f or not U.active or not U.Enabled("targettarget") then return end
	local unit = f.unit
	if not UnitExists(unit) then
		if f.vis then
			f.dAll = true
			U.dirty = true
		end
		return
	end
	local hp, mx, nm = UnitHealth(unit), UnitHealthMax(unit), UnitName(unit)
	if not f.vis or hp ~= f.lhp or mx ~= f.lmx or nm ~= f.lnm then
		if nm ~= f.lnm then f.snap = true end
		f.dAll = true
		U.dirty = true
	end
end

function U.PollRange()
	local f = U.frames.target
	if not f or not f.vis then return end
	if not cfg.range then
		if f.rangeTxt ~= "" then
			f.rangeTxt = ""
			f.rangeText:SetText("")
			f:SetAlpha(1)
		end
		return
	end
	local d, src = SUI.Api.Distance("target")
	local txt = ""
	if src then
		if d then txt = SUI.Api.FormatDistance(d, src) else txt = ">28 yd" end
	end
	if txt ~= f.rangeTxt then
		f.rangeTxt = txt
		f.rangeText:SetText(txt)
	end
	local sight = SUI.Api.InSight("target")
	local alpha = (sight == false) and 0.55 or 1
	if alpha ~= f.alphaNow then
		f.alphaNow = alpha
		f:SetAlpha(alpha)
	end
end

-- ---------------------------------------------------------------- interactions
local function onClick()
	local f = this
	local unit = f.unit
	local ch = SUI.ClickHeal
	if ch and ch.on and ch.ClickSolo and ch.ClickSolo(unit, arg1, f) then return end   -- soins au clic sur soi / la cible (Mod_ClickHeal)
	if arg1 == "RightButton" then
		U.OpenMenu(f)
		return
	end
	if SpellIsTargeting() then
		SpellTargetUnit(unit)
	elseif CursorHasItem() then
		DropItemOnUnit(unit)
	else
		TargetUnit(unit)
	end
end

function U.OpenMenu(f)
	local name = (f.unit == "player") and "PlayerFrameDropDown" or ((f.unit == "target") and "TargetFrameDropDown" or nil)
	local dd = name and getglobal(name)
	if dd and ToggleDropDownMenu then
		pcall(ToggleDropDownMenu, 1, nil, dd, "cursor")
	end
end

local function onWheel()
	local ch = SUI.ClickHeal
	if ch and ch.on and ch.WheelSolo then ch.WheelSolo(this.unit, arg1, this) end
end

-- Roulette : activee seulement si une liaison de clic-soin en utilise (appelee par Mod_ClickHeal).
function U.SyncWheel()
	local ch = SUI.ClickHeal
	local on = (ch and ch.on and ch.hasWheel) and true or false
	local p, t = U.frames.player, U.frames.target
	if p then p:EnableMouseWheel((on and ch.SoloOn("player")) and true or false) end
	if t then t:EnableMouseWheel((on and ch.SoloOn("target")) and true or false) end
end

local function onEnter()
	local f = this
	SUI.Api.SetMouseover(f.unit)
	if GameTooltip and UnitExists(f.unit) then
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		GameTooltip:SetUnit(f.unit)
		local ch = SUI.ClickHeal
		if ch and ch.on and ch.AddHints and ch.SoloOn(f.unit) then ch.AddHints(GameTooltip, f) end
		GameTooltip:Show()
	end
end

local function onLeave()
	SUI.Api.SetMouseover(nil)
	if GameTooltip then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------- construction (hors combat uniquement)
function U.Create(unit)
	local f = CreateFrame("Button", "ShikiUI_Unit_" .. unit, UIParent)
	f.unit = unit
	f.noPower = (unit == "targettarget")
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	T.Backdrop(f, T.c.bg, T.c.border)
	-- Barre de pre-soin (soins entrants) SOUS la barre de vie : tout sauf la cible de la cible
	if unit ~= "targettarget" then
		f.heal = T.Bar(f)
		f.heal:SetFrameLevel(f:GetFrameLevel() + 1)
	end
	f.hp = T.Bar(f)
	f.hp:SetFrameLevel(f:GetFrameLevel() + 2)
	f.pw = T.Bar(f)
	f.pw:SetFrameLevel(f:GetFrameLevel() + 2)
	f.nameText = T.Text(f.hp, 11, T.c.text, "LEFT", true)
	f.hpText = T.Text(f.hp, 11, T.c.text, "RIGHT", true)
	f.statusText = T.Text(f.hp, 11, T.c.warn, "CENTER", true)
	f.statusText:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
	if unit == "target" then
		f.rangeText = T.Text(f, 10, T.c.dim, "RIGHT", true)
		f.rangeText:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 2)
	end
	f:SetScript("OnClick", onClick)
	f:SetScript("OnMouseWheel", onWheel)
	f:SetScript("OnEnter", onEnter)
	f:SetScript("OnLeave", onLeave)
	f.dAll = true
	f:Hide()
	return f
end

function U.ApplyLayout()
	local w = SUI.Config.Get("units.width")
	local h = SUI.Config.Get("units.height")
	local ph = SUI.Config.Get("units.powerheight")
	for i = 1, getn(U.order) do
		local unit = U.order[i]
		local f = U.frames[unit]
		if f then
			local isTot = (unit == "targettarget")
			local isPet = (unit == "pet")
			local rw = isTot and TOT_RATIO or (isPet and PET_RATIO or 1)
			local rh = isTot and 0.7 or (isPet and PET_RATIO or 1)
			local fw = floor(w * rw)
			local fh = math.max(14, floor(h * rh))
			f:SetWidth(fw)
			f:SetHeight(fh)
			local withPower = cfg.showpower and not isTot
			if f.heal then
				f.heal:ClearAllPoints()
				f.heal:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
				f.heal:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
				f.heal:SetHeight(withPower and (fh - 3 - ph) or (fh - 2))
			end
			f.hp:ClearAllPoints()
			f.hp:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
			f.hp:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
			f.hp:SetHeight(withPower and (fh - 3 - ph) or (fh - 2))
			f.pw:ClearAllPoints()
			f.pw:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
			f.pw:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
			f.pw:SetHeight(ph)
			if not withPower then f.pw:Hide() end
			f.nameText:ClearAllPoints()
			f.nameText:SetPoint("LEFT", f.hp, "LEFT", 4, 0)
			f.nameText:SetWidth(floor(fw * 0.62))
			f.nameText:SetHeight(12)
			f.hpText:ClearAllPoints()
			f.hpText:SetPoint("RIGHT", f.hp, "RIGHT", -4, 0)
			f.hpText:SetHeight(12)
			SUI.Layout.Apply("unit." .. unit)
		end
	end
	U.dirty = true
end

function U.Build()
	if U.built then return end
	U.built = true
	local defaults = { player = { -230, -150 }, target = { 230, -150 }, targettarget = { 230, -196 }, pet = { -160, -196 } }
	for i = 1, getn(U.order) do
		local unit = U.order[i]
		local f = U.Create(unit)
		U.frames[unit] = f
		SUI.Layout.Register(f, "unit." .. unit, "CENTER", defaults[unit][1], defaults[unit][2])
	end
	U.ReadConfig()
	U.ApplyLayout()
end

-- Les cadres Blizzard ne sont masques que si aucun autre addon (pfUI) ne s'en charge deja.
local function blizzFree()
	return not (SUI.Migrate and SUI.Migrate.BlizzOwned())
end

function U.HideBlizzard()
	for i = 1, getn(BLIZZ) do
		local fr = getglobal(BLIZZ[i])
		if fr then
			fr:UnregisterAllEvents()
			fr:Hide()
		end
	end
	U.blizzHidden = true
end

local function onConfig(key, value)
	if not U.built then return end
	U.ReadConfig()
	if key == "units.incheal" and SUI.GroupEngine and SUI.GroupEngine.SyncCast then
		SUI.GroupEngine.SyncCast()   -- le moteur re-evalue s'il doit ecouter mes incantations
	end
	if key == "units.hideblizz" then
		if value then
			if blizzFree() then U.HideBlizzard() end
		elseif U.blizzHidden then
			SUI.Print(L("msg.reload"))
		end
	end
	if key == nil or string.sub(key, 1, 6) == "units." then
		U.ApplyLayout()
		U.MarkAll()
	end
end

local function onEmergency(on)
	U.ReadConfig()
	U.MarkAll()
end

function U.Activate()
	U.active = true
	if SUI.Config.Get("units.hideblizz") and blizzFree() then U.HideBlizzard() end
	for i = 1, getn(UNIT_EVENTS) do SUI.On(UNIT_EVENTS[i], onUnitEvent) end
	SUI.On("PLAYER_TARGET_CHANGED", onTargetChanged)
	SUI.On("PLAYER_DEAD", onPlayerState)
	SUI.On("PLAYER_ALIVE", onPlayerState)
	SUI.On("PLAYER_UNGHOST", onPlayerState)
	SUI.On("PLAYER_ENTERING_WORLD", onWorld)
	U.tFlush = SUI.Every(FLUSH, U.Flush, "units.flush", true)
	U.tTot = SUI.Every(POLL_TOT, U.PollTot, "units.tot", true)
	U.tRange = SUI.Every(POLL_RANGE, U.PollRange, "units.range", true)
	-- Le moteur de groupe doit ecouter mes incantations pour la barre de pre-soin joueur / cible
	if SUI.GroupEngine and SUI.GroupEngine.SyncCast then SUI.GroupEngine.SyncCast() end
	U.MarkAll()
end

function U.Deactivate()
	U.active = false
	for i = 1, getn(UNIT_EVENTS) do SUI.Off(UNIT_EVENTS[i], onUnitEvent) end
	SUI.Off("PLAYER_TARGET_CHANGED", onTargetChanged)
	SUI.Off("PLAYER_DEAD", onPlayerState)
	SUI.Off("PLAYER_ALIVE", onPlayerState)
	SUI.Off("PLAYER_UNGHOST", onPlayerState)
	SUI.Off("PLAYER_ENTERING_WORLD", onWorld)
	SUI.Cancel(U.tFlush)
	SUI.Cancel(U.tTot)
	SUI.Cancel(U.tRange)
	if SUI.GroupEngine and SUI.GroupEngine.SyncCast then SUI.GroupEngine.SyncCast() end
	for i = 1, getn(U.order) do
		local f = U.frames[U.order[i]]
		if f then
			f.vis = false
			f:Hide()
		end
	end
end

local function enable()
	SUI.WhenSafe(function()
		if not U.watching then
			U.watching = true
			SUI.Config.Watch("units.", onConfig)
			SUI.Config.Watch("ui.", onConfig)
			SUI.Perf.OnEmergency(onEmergency)
		end
		U.Build()
		U.Activate()
	end)
end

SUI.RegisterCategory("units", 2)
SUI.RegisterModule("units", {
	default = true,
	core = true,
	cost = "medium",
	options = {
		{ key = "units.player.enabled", type = "bool", cat = "units", label = "opt.units.player.enabled", tip = "tip.units.player.enabled", default = true, order = 10 },
		{ key = "units.target.enabled", type = "bool", cat = "units", label = "opt.units.target.enabled", tip = "tip.units.target.enabled", default = true, order = 20 },
		{ key = "units.tot.enabled", type = "bool", cat = "units", label = "opt.units.tot.enabled", tip = "tip.units.tot.enabled", default = true, order = 30 },
		{ key = "units.pet.enabled", type = "bool", cat = "units", label = "opt.units.pet.enabled", tip = "tip.units.pet.enabled", default = true, order = 35 },
		{ key = "units.width", type = "number", cat = "units", label = "opt.units.width", tip = "tip.units.width", min = 100, max = 320, step = 5, default = 180, order = 40 },
		{ key = "units.height", type = "number", cat = "units", label = "opt.units.height", tip = "tip.units.height", min = 16, max = 60, step = 1, default = 28, order = 50 },
		{ key = "units.powerheight", type = "number", cat = "units", label = "opt.units.powerheight", tip = "tip.units.powerheight", min = 2, max = 12, step = 1, default = 4, order = 60 },
		{ key = "units.showpower", type = "bool", cat = "units", label = "opt.units.showpower", tip = "tip.units.showpower", default = true, order = 70 },
		{ key = "units.classcolor", type = "bool", cat = "units", label = "opt.units.classcolor", tip = "tip.units.classcolor", default = true, simple = true, order = 80 },
		{ key = "units.hptext", type = "choice", cat = "units", label = "opt.units.hptext", tip = "tip.units.hptext", choices = { "none", "value", "percent", "both" }, default = "percent", simple = true, order = 90 },
		{ key = "units.range", type = "bool", cat = "units", label = "opt.units.range", tip = "tip.units.range", default = true, simple = true, order = 100 },
		{ key = "units.smooth", type = "bool", cat = "units", label = "opt.units.smooth", tip = "tip.units.smooth", default = true, order = 110 },
		{ key = "units.incheal", type = "bool", cat = "units", label = "opt.units.incheal", tip = "tip.units.incheal", default = true, order = 115 },
		{ key = "units.hideblizz", type = "bool", cat = "units", label = "opt.units.hideblizz", tip = "tip.units.hideblizz", default = true, order = 120, reload = true },
	},
	enable = enable,
	disable = function() U.Deactivate() end,
})
