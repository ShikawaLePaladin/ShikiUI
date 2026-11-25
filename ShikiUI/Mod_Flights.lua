-- Mod_Flights : chronometre de vol. Le client 1.12 ne donne aucune duree : le module la mesure a chaque trajet (de l'entree sur le taxi a
-- l'atterrissage), la retient par couple depart > arrivee, puis affiche un compte a rebours au vol suivant et la duree dans l'infobulle
-- de la carte des vols. Aucune minuterie hors vol. Regles du socle (Lua 5.0) : pas de '#', '%', '...', select, string.match.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Flights = M

local floor, sformat = math.floor, string.format

local TICK = 0.2
local TAKEOFF = 10          -- secondes laissees au taxi pour decoller, sinon la demande est oubliee
local SHORTEST = 10         -- un "vol" plus court n'est pas retenu (decollage rate)
local WIDTH = 220

M.on = false
M.flight = nil              -- { key, to, asked, start }

local function glob(n) return getglobal(n) end

function M.Clock(s)
	s = floor((s or 0) + 0.5)
	if s < 0 then s = 0 end
	local m = floor(s / 60)
	return sformat("%d:%02d", m, s - m * 60)
end

function M.Key(from, to) return tostring(from) .. " > " .. tostring(to) end

function M.Times()
	local t = C.GetGlobal("flighttimes")
	if type(t) ~= "table" then
		t = {}
		C.SetGlobal("flighttimes", t)
	end
	return t
end

function M.Known(key)
	local t = C.GetGlobal("flighttimes")
	return type(t) == "table" and t[key] or nil
end

-- Nom du point de vol ou se trouve le joueur (carte des vols ouverte)
function M.Here()
	if not NumTaxiNodes then return nil end
	for i = 1, (NumTaxiNodes() or 0) do
		if TaxiNodeGetType(i) == "CURRENT" then return TaxiNodeName(i) end
	end
	return nil
end

-- ---------------------------------------------------------------- barre
function M.Build()
	if M.frame then return end
	local f = CreateFrame("Frame", "ShikiUI_Flight", UIParent)
	f:SetWidth(WIDTH)
	f:SetHeight(36)
	T.Backdrop(f, T.c.bg, T.c.border)
	M.title = T.Text(f, 11, T.c.text, "CENTER")
	M.title:SetPoint("TOP", f, "TOP", 0, -5)
	M.title:SetWidth(WIDTH - 12)
	M.title:SetHeight(12)
	local bar = T.Bar(f)
	bar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 5)
	bar:SetWidth(WIDTH - 12)
	bar:SetHeight(12)
	local over = CreateFrame("Frame", nil, bar)
	over:SetAllPoints(bar)
	M.time = T.Text(over, 11, T.c.text, "CENTER", true)
	M.time:SetPoint("CENTER", over, "CENTER", 0, 0)
	M.bar, M.frame = bar, f
	f:Hide()
	SUI.Layout.Register(f, "flights", "TOP", 0, -140)
end

function M.Draw()
	local fl = M.flight
	if not fl or not fl.start or not M.frame then return end
	if not C.Get("flights.timer") then M.frame:Hide() return end
	local elapsed = GetTime() - fl.start
	local total = M.Known(fl.key)
	local r, g, b = T.Accent()
	M.bar:SetStatusBarColor(r, g, b)
	M.title:SetText(L("msg.flights.to", fl.to))
	if total and total > 0 then
		local left = total - elapsed
		M.bar:SetValue(left > 0 and elapsed / total or 1)
		M.time:SetText(M.Clock(left > 0 and left or 0))
	else
		M.bar:SetValue(1)
		M.time:SetText(L("msg.flights.learning", M.Clock(elapsed)))
	end
	M.frame:Show()
end

-- ---------------------------------------------------------------- suivi du vol
function M.Stop()
	if M.task then SUI.Cancel(M.task) M.task = nil end
	M.flight = nil
	if M.frame then M.frame:Hide() end
end

function M.Tick()
	local fl = M.flight
	if not fl then M.Stop() return end
	local flying = UnitOnTaxi and UnitOnTaxi("player")
	if not fl.start then
		if flying then
			fl.start = GetTime()
			SUI.WhenSafe(M.Build)
			M.Draw()
		elseif GetTime() - fl.asked > TAKEOFF then
			M.Stop()
		end
		return
	end
	if flying then M.Draw() return end
	local took = GetTime() - fl.start
	if took >= SHORTEST then M.Times()[fl.key] = floor(took + 0.5) end
	M.Stop()
end

-- Appele AVANT TakeTaxiNode : la carte des vols est encore ouverte, les noms sont lisibles
function M.Request(slot)
	if not M.on or not slot or not TaxiNodeName or TaxiNodeGetType(slot) ~= "REACHABLE" then return end
	local from, to = M.Here(), TaxiNodeName(slot)
	if not from or not to then return end
	M.Stop()
	M.flight = { key = M.Key(from, to), to = to, asked = GetTime() }
	M.task = SUI.Every(TICK, M.Tick, "flights.tick")
end

-- Ligne de duree dans l'infobulle d'une destination
function M.Tooltip(button)
	if not M.on or not C.Get("flights.tip") or not button or not button.GetID or not TaxiNodeName then return end
	local slot = button:GetID()
	if TaxiNodeGetType(slot) ~= "REACHABLE" then return end
	local from, to = M.Here(), TaxiNodeName(slot)
	if not from or not to then return end
	local s = M.Known(M.Key(from, to))
	local c = T.c.dim
	GameTooltip:AddLine(s and L("msg.flights.tip", M.Clock(s)) or L("msg.flights.unknown"), c[1], c[2], c[3])
	GameTooltip:Show()
end

-- Enveloppes posees une seule fois ; module coupe, elles ne font que transmettre
function M.Hook()
	if not M.hookedTake and type(glob("TakeTaxiNode")) == "function" then
		local orig = glob("TakeTaxiNode")
		M.hookedTake = true
		setglobal("TakeTaxiNode", function(slot)
			M.Request(slot)
			return orig(slot)
		end)
	end
	if not M.hookedTip and type(glob("TaxiNodeOnButtonEnter")) == "function" then
		local orig = glob("TaxiNodeOnButtonEnter")
		M.hookedTip = true
		setglobal("TaxiNodeOnButtonEnter", function(button)
			orig(button)
			M.Tooltip(button or this)
		end)
	end
end

function M.OnTaxiMap() M.Hook() end

function M.OnLeave() M.Stop() end

function M.Enable()
	M.on = true
	M.Hook()
	SUI.On("TAXIMAP_OPENED", M.OnTaxiMap)
	SUI.On("PLAYER_LEAVING_WORLD", M.OnLeave)
end

function M.Disable()
	M.on = false
	SUI.Off("TAXIMAP_OPENED", M.OnTaxiMap)
	SUI.Off("PLAYER_LEAVING_WORLD", M.OnLeave)
	M.Stop()
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("flights", 84)

SUI.RegisterModule("flights", {
	default = true,
	cost = "light",
	options = {
		{ key = "flights.timer", type = "bool", cat = "flights", label = "opt.flights.timer", tip = "tip.flights.timer",
			default = true, simple = true, order = 10 },
		{ key = "flights.tip", type = "bool", cat = "flights", label = "opt.flights.tip", tip = "tip.flights.tip",
			default = true, simple = true, order = 20 },
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("flights", function(rest)
	local t, n = M.Times(), 0
	for k, s in pairs(t) do
		n = n + 1
		SUI.Print(k .. " : " .. M.Clock(s))
	end
	if n == 0 then SUI.Print(L("msg.flights.none")) end
end, "help.flights")
