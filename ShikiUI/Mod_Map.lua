-- ShikiUI Map : coordonnees du joueur sur la carte du monde + echelle de la carte (options, a chaud).
-- Le DEPLACEMENT de la carte reste le module "windows" ; ici on ajoute l'affichage de position (lecture
-- de GetPlayerMapPosition quand la carte est ouverte) et l'echelle du cadre Blizzard (SetScale, restore a la coupure).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local C = SUI.Config

local floor = math.floor
local sformat = string.format

local M = {}
SUI.Map = M

M.active = false
M.appliedScale = nil     -- echelle posee par nous (restore a la coupure)

local function frame()
	return getglobal("WorldMapFrame")
end

local function scale()
	local sc = (C.Get("map.scale") or 100) / 100
	if sc <= 0 then sc = 1 end
	return sc
end

function M.ApplyScale()
	local f = frame()
	if not f then return end
	if not M.active then
		if M.appliedScale then f:SetScale(1) M.appliedScale = nil end
		return
	end
	local sc = scale()
	f:SetScale(sc)
	M.appliedScale = sc
end

-- Texte "position : x, y" pose en bas du cadre (cree une fois, montre/assigne par la minuterie).
local posText = nil   -- texte x, y pose sur la carte ; M.posText = reference publique (tests/panneau)

local function ensureText(f)
	if posText then return posText end
	posText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	posText:SetShadowColor(0, 0, 0, 1)
	posText:SetShadowOffset(1, -1)
	posText:SetHeight(12)
	posText:SetWidth(200)
	posText:SetPoint("BOTTOM", f, "BOTTOM", 0, 4)
	M.posText = posText
	return posText
end

local function showPos(f)
	local gp = getglobal("GetPlayerMapPosition")
	if not gp then return false end
	local x, y = gp("player")
	if not x then return false end
	x = floor((x or 0) * 100 + 0.5)
	y = floor((y or 0) * 100 + 0.5)
	local t = ensureText(f)
	t:SetText(sformat("%d, %d", x, y))
	t:Show()
	return true
end

-- un tour de minuterie : texte si la carte est visible et l'option cochee, cache sinon
function M.Tick()
	local f = frame()
	if not f or not M.active then return end
	local vis = f.IsShown and f:IsShown()
	if not vis then
		if posText then posText:Hide() end
		return
	end
	if C.Get("map.coords") then
		if not showPos(f) and posText then posText:Hide() end
	elseif posText then
		posText:Hide()
	end
end

function M.Activate()
	M.active = true
	M.ApplyScale()
	if M.task then SUI.Cancel(M.task) end
	M.task = SUI.Every(0.3, M.Tick, "map.tick", true)
	M.Tick()
end

function M.Deactivate()
	M.active = false
	SUI.Cancel(M.task)
	M.task = nil
	if posText then posText:Hide() end
	M.ApplyScale()
end

function M.OnKey(key, value)
	M.ApplyScale()
	if M.active then M.Tick() end
end

function M.Enable()
	SUI.WhenSafe(M.Activate)
	if not M.watching then
		M.watching = true
		C.Watch("map.", M.OnKey)
	end
end

function M.Disable()
	M.Deactivate()
end

SUI.RegisterCategory("map", 74)

local function opt(key, typ, order, def, extra)
	local o = { key = "map." .. key, type = typ, cat = "map", label = "opt.map." .. key, tip = "tip.map." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("map", {
	default = true,
	cost = "light",
	options = {
		opt("coords", "bool", 10, true, { simple = true }),
		opt("scale", "number", 20, 100, { min = 80, max = 150, step = 5, simple = true }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("mapinfo", function()
	local f = frame()
	if not f or not f.IsShown or not f:IsShown() then SUI.Print(L("msg.map.closed")) return end
	local gp = getglobal("GetPlayerMapPosition")
	if not gp then SUI.Print(L("msg.map.closed")) return end
	local x, y = gp("player")
	x = floor((x or 0) * 100 + 0.5)
	y = floor((y or 0) * 100 + 0.5)
	SUI.Print(sformat("x: %d   y: %d", x, y))
end, "help.map")
