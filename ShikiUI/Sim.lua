-- ShikiUI Sim : simulateur de groupe / raid pour tester les cadres SANS vrai groupe (outil de developpement, inerte par defaut).
-- /sui sim party [n] | raid [n] | off | dmg | kill [i] | res [i] | offline [i] | far [i] | debuff [i] | hp <i> <pct> | anim | status
-- Tant qu'une simulation est active, les fonctions d'unite du client sont enveloppees : les jetons raidN / partyN renvoient des donnees
-- fictives (le joueur reel "player" reste reel) ; tout le reste passe a la fonction d'origine. /sui sim off restaure tout. Aucun cadre
-- n'est modifie : le moteur de groupe lit simplement ces valeurs et recoit les evenements habituels (RAID_ROSTER_UPDATE, UNIT_HEALTH...).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local L = SUI.L
local getn, floor, random = table.getn, math.floor, math.random

local S = { on = false, mode = nil, n = 0, m = {}, orig = {}, anim = nil }
SUI.Sim = S

local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "PALADIN", "ROGUE", "HUNTER", "SHAMAN", "DRUID", "WARLOCK" }
local CLASSNAMES = { WARRIOR = "Guerrier", PRIEST = "Pretre", MAGE = "Mage", PALADIN = "Paladin", ROGUE = "Voleur", HUNTER = "Chasseur",
	SHAMAN = "Chaman", DRUID = "Druide", WARLOCK = "Demoniste" }
local HPMAX = 4000
local DEBUFF_TEX = "Interface\\Icons\\Spell_Shadow_ShadowWordPain"

-- jeton d'unite -> index de membre (1..n) ou nil. En raid : raidN ; en groupe : "player" reste reel, partyN = membre N + 1.
local function idx(u)
	if not S.on or type(u) ~= "string" then return nil end
	local _, _, k = string.find(u, "^raid(%d+)$")
	if k and S.mode == "raid" then
		k = tonumber(k)
		if k >= 1 and k <= S.n then return k end
		return nil
	end
	_, _, k = string.find(u, "^party(%d+)$")
	if k and S.mode == "party" then
		k = tonumber(k) + 1
		if k >= 2 and k <= S.n then return k end
	end
	return nil
end

local function mk(i)
	local cls = CLASSES[math.mod(i - 1, getn(CLASSES)) + 1]
	return { name = "Sim" .. i, class = cls, sub = floor((i - 1) / 5) + 1, hp = 1, dead = false, offline = false, far = false, debuff = false }
end

-- fonctions enveloppees : nom -> function(m, i)  (m = membre fictif, i = son index)
local WRAP = {
	UnitExists = function(m) return 1 end,
	UnitName = function(m) return m.name end,
	UnitClass = function(m) return CLASSNAMES[m.class], m.class end,
	UnitIsDeadOrGhost = function(m) return m.dead and 1 or nil end,
	UnitIsGhost = function(m) return nil end,
	UnitHealth = function(m) return m.dead and 0 or floor(m.hp * HPMAX) end,
	UnitHealthMax = function(m) return HPMAX end,
	UnitIsConnected = function(m) return (not m.offline) and 1 or nil end,
	UnitCanAttack = function(m) return nil end,
	UnitIsPlayer = function(m) return 1 end,
	UnitIsFriend = function(m) return 1 end,
	UnitIsVisible = function(m) return (not m.far) and 1 or nil end,
	UnitClassification = function(m) return "normal" end,
	UnitPowerType = function(m) return 0 end,
	UnitMana = function(m) return 2000 end,
	UnitManaMax = function(m) return 2000 end,
	UnitLevel = function(m) return 60 end,
	UnitIsPartyLeader = function(m, i) return (i == 1) and 1 or nil end,
	GetRaidTargetIndex = function(m) return nil end,
	UnitBuff = function(m) return nil end,
}

local function install()
	for name, fn in pairs(WRAP) do
		local o = _G[name]
		S.orig[name] = o
		local w = fn
		_G[name] = function(u, a, b, c)
			local i = idx(u)
			if i then return w(S.m[i], i) end
			return o(u, a, b, c)
		end
	end
	local oD = _G.UnitDebuff
	S.orig.UnitDebuff = oD
	_G.UnitDebuff = function(u, n, a, b)
		local i = idx(u)
		if i then
			if S.m[i].debuff and n == 1 then return DEBUFF_TEX, 1, "Magic" end
			return nil
		end
		return oD(u, n, a, b)
	end
	local oIs = _G.UnitIsUnit
	S.orig.UnitIsUnit = oIs
	_G.UnitIsUnit = function(a, b)
		local x, y = idx(a), idx(b)
		if x or y then
			if not x and a == "player" then x = 1 end
			if not y and b == "player" then y = 1 end
			return (x and y and x == y) and 1 or nil
		end
		return oIs(a, b)
	end
	local oR, oP, oI = _G.GetNumRaidMembers, _G.GetNumPartyMembers, _G.GetRaidRosterInfo
	S.orig.GetNumRaidMembers, S.orig.GetNumPartyMembers, S.orig.GetRaidRosterInfo = oR, oP, oI
	_G.GetNumRaidMembers = function()
		if S.mode == "raid" then return S.n end
		return 0
	end
	_G.GetNumPartyMembers = function()
		if S.mode == "party" then return S.n - 1 end
		return 0
	end
	_G.GetRaidRosterInfo = function(i)
		if S.mode ~= "raid" then return oI(i) end
		local m = S.m[i]
		if not m then return nil end
		return m.name, (i == 1) and 2 or 0, m.sub, 60, CLASSNAMES[m.class], m.class, "Sim", (not m.offline) and 1 or nil, m.dead and 1 or nil
	end
end

local function uninstall()
	for name, o in pairs(S.orig) do
		_G[name] = o
		S.orig[name] = nil
	end
end

local function token(i)
	if S.mode == "raid" then return "raid" .. i end
	if i == 1 then return "player" end
	return "party" .. (i - 1)
end

local function fire(ev, a1)
	local f = _G.ShikiUI_Events
	local h = f and f:GetScript("OnEvent")
	if not h then return end
	_G.event, _G.arg1 = ev, a1
	h()
end

local function roster()
	fire("PARTY_MEMBERS_CHANGED")
	fire("RAID_ROSTER_UPDATE")
end

local function touch(i, aura)
	if i == 1 and S.mode == "party" then return end
	fire("UNIT_HEALTH", token(i))
	if aura then fire("UNIT_AURA", token(i)) end
end

local function each(arg, fn)
	local i = tonumber(arg)
	if i then
		if S.m[i] then fn(i, S.m[i]) end
	else
		for k = 1, S.n do fn(k, S.m[k]) end
	end
end

local function stop()
	if S.anim then
		SUI.Cancel(S.anim)
		S.anim = nil
	end
	if S.on then
		S.on = false
		uninstall()
		S.mode, S.n = nil, 0
		roster()
	end
end

local function start(mode, n)
	if S.on then stop() end
	local max = (mode == "raid") and 40 or 5
	n = tonumber(n) or ((mode == "raid") and 25 or 5)
	if n < 2 then n = 2 end
	if n > max then n = max end
	S.m = {}
	for i = 1, n do S.m[i] = mk(i) end
	S.mode, S.n, S.on = mode, n, true
	install()
	roster()
	for i = 1, n do touch(i, true) end
	SUI.Print(L("msg.sim.on", mode, n))
end

local function damage()
	for i = 1, S.n do
		local m = S.m[i]
		if not m.dead then
			m.hp = m.hp - random() * 0.5
			if m.hp <= 0 then
				m.hp = 0
				m.dead = (random() < 0.3)
			end
			if m.hp < 0.02 and not m.dead then m.hp = 0.02 end
		end
		touch(i)
	end
end

local function cmd(rest)
	local _, _, sub, a, b = string.find(rest or "", "^%s*(%S*)%s*(%S*)%s*(%S*)")
	sub = sub or ""
	if sub == "party" or sub == "raid" then
		start(sub, a)
	elseif sub == "off" then
		stop()
		SUI.Print(L("msg.sim.off"))
	elseif not S.on then
		SUI.Print(L("help.sim"))
	elseif sub == "dmg" then
		damage()
	elseif sub == "kill" then
		each(a, function(i, m) m.dead = true; m.hp = 0; touch(i) end)
	elseif sub == "res" then
		each(a, function(i, m) m.dead = false; m.hp = 1; touch(i) end)
	elseif sub == "offline" then
		each(a, function(i, m) m.offline = not m.offline; touch(i) end)
	elseif sub == "far" then
		each(a, function(i, m) m.far = not m.far; touch(i) end)
	elseif sub == "debuff" then
		each(a, function(i, m) m.debuff = not m.debuff; touch(i, true) end)
	elseif sub == "hp" then
		local i, p = tonumber(a), tonumber(b)
		if i and p and S.m[i] then
			S.m[i].hp = p / 100
			S.m[i].dead = false
			touch(i)
		end
	elseif sub == "anim" then
		if S.anim then
			SUI.Cancel(S.anim)
			S.anim = nil
		else
			S.anim = SUI.Every(0.7, damage, "sim")
		end
	else
		local dead, off, far = 0, 0, 0
		for i = 1, S.n do
			if S.m[i].dead then dead = dead + 1 end
			if S.m[i].offline then off = off + 1 end
			if S.m[i].far then far = far + 1 end
		end
		SUI.Print(L("msg.sim.status", S.mode, S.n, dead, off, far))
	end
end

SUI.RegisterCommand("sim", cmd, "help.sim")
