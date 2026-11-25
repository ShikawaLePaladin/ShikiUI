-- Mod_Guide : "quoi faire maintenant" - suggestions de quetes pour ton niveau, ta classe, ta race et ta zone, d'apres les donnees du Codex
-- (ShikiCodexData_Quests). Un clic sur une suggestion l'epingle sur la carte et lance la fleche de direction (module Codex).
-- Limite de l'API 1.12 : le jeu ne dit PAS quelles quetes sont terminees. Le module les apprend lui-meme : une quete du journal qui etait
-- terminee puis disparait est notee "faite" (par personnage, ShikiUIDB.global.guidedone). Sans historique, seules les quetes SANS
-- prerequis sont proposees ; apres un rendu, la suite de la chaine apparait en tete (etiquette "suite").
-- Aucune minuterie permanente : evenement QUEST_LOG_UPDATE (regroupe), la fenetre n'est calculee que quand elle est ouverte.
-- Regles du socle (WoW 1.12 / Lua 5.0) : pas de '#', '%', '...', select, string.match ; au plus 32 upvalues par fonction.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Guide = M

local getn, tinsert, tsort, floor = table.getn, table.insert, table.sort, math.floor
local sfind, ssub, slower, sgfind, sformat = string.find, string.sub, string.lower, string.gfind, string.format

local MAXROWS = 8
local ROWH = 22
local WIDTH = 420
local LOWGAP = 6            -- une quete de plus de LOWGAP niveaux sous toi est "grise" : plus proposee
local HIGHGAP = 2           -- ... et au dela de HIGHGAP niveaux au-dessus de toi, trop dure pour l'instant

M.on = false
M.rows = {}                 -- lignes affichees : { id, lvl, title, chain, dist, npc }
M.prev = nil                -- derniere lecture du journal (titre -> { level, complete })

-- ---------------------------------------------------------------- outils
local function glob(n) return getglobal(n) end

-- Bit "n" (1, 2, 4, 8...) present dans le masque ? (pas d'operateur de bits en Lua 5.0)
local function hasBit(mask, bit)
	if type(mask) ~= "number" or mask <= 0 then return true end
	local q = floor(mask / bit)
	return q - floor(q / 2) * 2 == 1
end

M.CLASSBIT = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
-- races : noms anglais et francais (masculin / feminin) ; le client 1.12 ne rend que le nom localise
M.RACEBIT = {
	human = 1, humain = 1, humaine = 1, orc = 2, orque = 2, dwarf = 4, nain = 4, naine = 4,
	["night elf"] = 8, ["elfe de la nuit"] = 8, undead = 16, scourge = 16, ["mort-vivant"] = 16, ["morte-vivante"] = 16,
	tauren = 32, gnome = 64, troll = 128, trollesse = 128, goblin = 256, gobelin = 256, gobeline = 256,
	["blood elf"] = 512, ["elfe de sang"] = 512, ["high elf"] = 512, ["haut-elfe"] = 512, ["haute-elfe"] = 512,
}

-- Masques du joueur : race (bit pfQuest, 0 = inconnu), classe (bit pfQuest, 0 = inconnu), camp (589 Alliance / 434 Horde / 0)
function M.Player()
	local race, cls, side = 0, 0, 0
	local ur, uc, uf = glob("UnitRace"), glob("UnitClass"), glob("UnitFactionGroup")
	if ur then
		local ok, a, b = pcall(ur, "player")
		if ok then
			local nm = type(b) == "string" and b or a
			if type(nm) == "string" then race = M.RACEBIT[slower(nm)] or (type(a) == "string" and M.RACEBIT[slower(a)]) or 0 end
		end
	end
	if uc then
		local ok, a, b = pcall(uc, "player")
		if ok then
			local tok = type(b) == "string" and b or a
			if type(tok) == "string" then cls = M.CLASSBIT[string.upper(tok)] or 0 end
		end
	end
	if uf then
		local ok, a = pcall(uf, "player")
		if ok and type(a) == "string" then
			if a == "Alliance" then side = 589 elseif a == "Horde" then side = 434 end
		end
	end
	return race, cls, side
end

-- La quete convient-elle a ce joueur ? Masque vide = tout le monde ; race inconnue : on retombe sur le camp.
function M.RaceOk(mask, race, side)
	if mask == nil or mask == 0 then return true end
	if race ~= 0 then return hasBit(mask, race) end
	if side == 589 then return hasBit(mask, 1) or hasBit(mask, 4) or hasBit(mask, 8) or hasBit(mask, 64) or hasBit(mask, 512) end
	if side == 434 then return hasBit(mask, 2) or hasBit(mask, 16) or hasBit(mask, 32) or hasBit(mask, 128) or hasBit(mask, 256) end
	return true
end

-- ---------------------------------------------------------------- quetes terminees (apprises)
function M.CharKey()
	local n = glob("UnitName") and UnitName("player") or "?"
	local r = glob("GetRealmName") and GetRealmName() or "?"
	return tostring(n) .. "-" .. tostring(r)
end

function M.Done()
	local all = C.GetGlobal("guidedone")
	if type(all) ~= "table" then all = {} end
	local k = M.CharKey()
	if type(all[k]) ~= "table" then all[k] = {} end
	C.SetGlobal("guidedone", all)
	return all[k]
end

-- Identifiants des quetes de titre `title` (et niveau `lvl` quand il est connu) : balayage lineaire, rare (rendu d'une quete).
function M.IdsByTitle(title, lvl)
	local P = SUI.Codex and SUI.Codex.P
	local qd = P and P.Q()
	if not qd then return {} end
	local out = {}
	local low = slower(title)
	for id, s in pairs(qd.q) do
		local en, fr = qd.en.t[id], qd.fr and qd.fr.t and qd.fr.t[id]
		if (en and slower(en) == low) or (fr and slower(fr) == low) then
			local _, _, l = sfind(s, "^(%d+)")
			if not lvl or lvl == 0 or tonumber(l) == lvl or tonumber(l) == 0 then tinsert(out, id) end
		end
	end
	return out
end

-- Compare le journal a la lecture precedente : une quete terminee qui a disparu est une quete rendue.
function M.Scan()
	local qt = SUI.QuestTrack
	if not (qt and qt.Read) then return end
	local list = qt.Read()
	if not list then return end
	local now = {}
	for i = 1, getn(list) do
		local e = list[i]
		now[e.title] = { level = e.level, complete = e.complete }
	end
	if M.prev then
		for title, v in pairs(M.prev) do
			if v.complete and not now[title] and C.Get("guide.learn") then
				local done = M.Done()
				local ids = M.IdsByTitle(title, v.level)
				for i = 1, getn(ids) do done[ids[i]] = true end
				M.dirty = true
			end
		end
	end
	M.prev = now
	M.log = now
end

-- ---------------------------------------------------------------- zone et position du joueur
function M.ZoneId()
	local P = SUI.Codex and SUI.Codex.P
	local qd = P and P.Q()
	local gz = glob("GetRealZoneText")
	if not qd or not gz then return nil end
	local name = slower(tostring(gz() or ""))
	if name == "" then return nil end
	for id, en in pairs(qd.en.z) do
		if slower(en) == name then return id end
	end
	if type(qd.fr.z) == "table" then
		for id, fr in pairs(qd.fr.z) do
			if slower(fr) == name then return id end
		end
	end
	return nil
end

-- Position du joueur en % de la carte (0..100), nil si inconnue
function M.PlayerPos()
	local gp = glob("GetPlayerMapPosition")
	if not gp then return nil end
	local ok, x, y = pcall(gp, "player")
	if not ok or type(x) ~= "number" or (x == 0 and y == 0) then return nil end
	return x * 100, y * 100
end

-- ---------------------------------------------------------------- calcul des suggestions
-- Les 7 premiers champs d'un enregistrement : niveau, niveau min, races, classes, zone, predecesseurs, depart.
local function fields(s)
	local f, n, pos = {}, 0, 1
	while n < 12 do
		local a = sfind(s, ";", pos, true)
		n = n + 1
		if not a then f[n] = ssub(s, pos) break end
		f[n] = ssub(s, pos, a - 1)
		pos = a + 1
	end
	return f
end

-- Depart de la quete le plus proche du joueur dans la zone `zone` : { distance, x, y, ref } ou nil
function M.NearestStart(id, zone, px, py)
	local P = SUI.Codex.P
	local pins = P.QuestPins(id)
	if not pins then return nil end
	local best = nil
	for i = 1, getn(pins) do
		local p = pins[i]
		if p.kind == "S" and (not zone or p.zone == zone) then
			local d = nil
			if px then d = ((p.x - px) ^ 2 + (p.y - py) ^ 2) ^ 0.5 end
			if not best or (d and (not best.d or d < best.d)) then best = { d = d, x = p.x, y = p.y, ref = p.ref, zone = p.zone } end
		end
	end
	return best
end

-- Index construit une fois (un seul passage sur les quetes) : quetes sans prerequis par zone, et suites de chaque quete.
function M.Index(qd)
	if M.idx and M.idxQ == qd then return M.idx end
	local byZone, chainTo = {}, {}
	for id, s in pairs(qd.q) do
		local _, _, z, pre = sfind(s, "^%d+;%d+;%d*;%d*;(%d*);([%d,]*);")
		if z then
			z = tonumber(z) or 0
			if pre == "" then
				if not byZone[z] then byZone[z] = {} end
				tinsert(byZone[z], id)
			else
				for p in sgfind(pre, "%d+") do
					p = tonumber(p)
					if not chainTo[p] then chainTo[p] = {} end
					tinsert(chainTo[p], id)
				end
			end
		end
	end
	M.idx, M.idxQ = { byZone = byZone, chainTo = chainTo }, qd
	return M.idx
end

-- Une quete convient-elle ? (niveau, race, classe, depart connu, pas de competence ni d'evenement, pas deja dans le journal)
function M.Fits(qd, id, opts)
	local s = qd.q[id]
	local title = qd.en.t[id]
	if not s or not title or opts.done[id] then return nil end
	local f = fields(s)
	local lvl = opts.level or 1
	local ql, qmin = tonumber(f[1]) or 0, tonumber(f[2]) or 0
	if qmin > lvl or ql < lvl - LOWGAP or ql > lvl + HIGHGAP then return nil end
	if not f[7] or f[7] == "" or (f[12] or "") ~= "" then return nil end
	if not hasBit(tonumber(f[4]) or 0, opts.cls or 0) or not M.RaceOk(tonumber(f[3]), opts.race or 0, opts.side or 0) then return nil end
	if opts.log[title] or (qd.fr and qd.fr.t and qd.fr.t[id] and opts.log[qd.fr.t[id]]) then return nil end
	return { id = id, lvl = ql, min = qmin, zone = tonumber(f[5]) or 0 }
end

-- Cherche les suggestions : { id, lvl, min, title, chain (suite de chaine), d, npc }. Pur calcul, teste hors jeu.
-- opts : level, race, cls, side, zone, log (titre -> infos), done (id -> true), px, py
function M.Compute(qd, opts)
	local out, seen = {}, {}
	local ix = M.Index(qd)
	local zl = ix.byZone[opts.zone or -1]
	if zl then
		for i = 1, getn(zl) do
			local e = M.Fits(qd, zl[i], opts)
			if e then seen[e.id] = true tinsert(out, e) end
		end
	end
	for did in pairs(opts.done) do
		local cl = ix.chainTo[did]
		if cl then
			for i = 1, getn(cl) do
				local id = cl[i]
				if not seen[id] then
					local e = M.Fits(qd, id, opts)
					if e then e.chain = true seen[id] = true tinsert(out, e) end
				end
			end
		end
	end
	return out
end

-- Tri : suites de chaine d'abord, puis distance (si connue), puis niveau le plus proche du tien.
function M.Sort(list, level)
	tsort(list, function(a, b)
		if a.chain ~= b.chain then return a.chain end
		if a.d and b.d and a.d ~= b.d then return a.d < b.d end
		if (a.d ~= nil) ~= (b.d ~= nil) then return a.d ~= nil end
		local da, db = (a.lvl - level), (b.lvl - level)
		if da < 0 then da = -da end
		if db < 0 then db = -db end
		if da ~= db then return da < db end
		return a.id < b.id
	end)
end

function M.Suggest()
	local P = SUI.Codex and SUI.Codex.P
	if not P then return nil, "codex" end
	if not SUI.Codex.PinQuestsReady then return nil, "codex" end
	local ok = P.LoadQuests()
	if not ok then return nil, "data" end
	local qd = P.Q()
	if not qd then return nil, "data" end
	M.Scan()
	local race, cls, side = M.Player()
	local px, py = M.PlayerPos()
	local zone = M.ZoneId()
	local level = glob("UnitLevel") and UnitLevel("player") or 1
	local list = M.Compute(qd, { level = level, race = race, cls = cls, side = side, zone = zone, log = M.log or {}, done = M.Done(), px = px, py = py })
	for i = 1, getn(list) do
		local e = list[i]
		local st = M.NearestStart(e.id, zone, px, py)
		if st then e.d = st.d end
		e.title = P.QuestTitle(e.id) or qd.en.t[e.id]
		local q = P.Quest(e.id)
		if q and q.start and q.start[1] then e.npc = P.QName(q.start[1].kind, q.start[1].id) end
	end
	M.Sort(list, level)
	local out = {}
	for i = 1, MAXROWS do
		if list[i] then tinsert(out, list[i]) end
	end
	return out, nil, zone, getn(list)
end

-- ---------------------------------------------------------------- fenetre
function M.RowClick(b)
	local r = b.row
	if not r then return end
	if SUI.InCombat() then return end
	if SUI.Codex and SUI.Codex.PinQuest then SUI.Codex.PinQuest(r.id) end
end

function M.RowTip(b)
	local r = b.row
	if not r or not GameTooltip then return end
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:SetText(r.title or "?")
	GameTooltip:AddLine(L("msg.guide.tip.lvl", r.lvl, r.min), T.c.dim[1], T.c.dim[2], T.c.dim[3])
	if r.npc then GameTooltip:AddLine(L("msg.guide.tip.npc", r.npc), T.c.text[1], T.c.text[2], T.c.text[3]) end
	GameTooltip:AddLine(r.chain and L("msg.guide.tip.chain") or L("msg.guide.tip.zone"), T.c.dim[1], T.c.dim[2], T.c.dim[3])
	GameTooltip:AddLine(L("msg.guide.tip.click"), T.c.good[1], T.c.good[2], T.c.good[3])
	GameTooltip:Show()
end

function M.RowLeave()
	if GameTooltip then GameTooltip:Hide() end
end

function M.Build()
	if M.frame then return end
	local f = CreateFrame("Frame", "ShikiUI_Guide", UIParent)
	f:SetWidth(WIDTH)
	f:SetHeight(60 + MAXROWS * ROWH)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	f:SetFrameStrata("DIALOG")
	T.Backdrop(f, T.c.bg, T.c.border)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	f.title = T.Text(f, 13, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	f.sub = T.Text(f, 10, T.c.dim, "LEFT")
	f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -26)
	local close = T.Button(f, "x", 18, 18, function() f:Hide() end)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
	f.rows = {}
	for i = 1, MAXROWS do
		local b = T.Button(f, "", WIDTH - 20, ROWH - 2, M.RowClick)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -42 - (i - 1) * ROWH)
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
		b.label:SetJustifyH("LEFT")
		b:SetScript("OnEnter", function() M.RowTip(this) end)
		b:SetScript("OnLeave", M.RowLeave)
		b:Hide()
		f.rows[i] = b
	end
	f.empty = T.Text(f, 11, T.c.dim, "LEFT")
	f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -50)
	f.empty:SetWidth(WIDTH - 24)
	f:Hide()
	tinsert(UISpecialFrames, "ShikiUI_Guide")
	M.frame = f
end

function M.Paint()
	local f = M.frame
	if not f then return end
	local list, why, zone, total = M.Suggest()
	M.rows = list or {}
	local level = glob("UnitLevel") and UnitLevel("player") or 1
	f.title:SetText(L("msg.guide.title", level))
	local P = SUI.Codex and SUI.Codex.P
	local zn = zone and P and P.ZoneName(zone) or nil
	f.sub:SetText(zn and L("msg.guide.sub", zn, total or 0) or L("msg.guide.sub.nozone"))
	for i = 1, MAXROWS do
		local b, r = f.rows[i], M.rows[i]
		if r then
			b.row = r
			local mark = r.chain and L("msg.guide.chain") or ""
			local dist = r.d and sformat(" - %d", floor(r.d + 0.5)) or ""
			T.SetButtonText(b, sformat("[%d] %s%s%s", r.lvl, mark, r.title or "?", dist))
			b:Show()
		else
			b.row = nil
			b:Hide()
		end
	end
	if why == "data" then f.empty:SetText(L("msg.guide.nodata"))
	elseif why == "codex" then f.empty:SetText(L("msg.guide.nocodex"))
	elseif getn(M.rows) == 0 then f.empty:SetText(L("msg.guide.none"))
	else f.empty:SetText("") end
end

function M.Toggle()
	if not M.on then SUI.Print(L("msg.guide.off")) return end
	if SUI.InCombat() then return end
	M.Build()
	if M.frame:IsShown() then M.frame:Hide() return end
	M.Paint()
	M.frame:Show()
end

-- ---------------------------------------------------------------- evenements, reglages
function M.OnLog()
	if M.pending then return end
	M.pending = true
	SUI.After(0.6, function()
		M.pending = nil
		if not M.on then return end
		M.Scan()
		if M.frame and M.frame:IsShown() then M.Paint() end
	end, "guide.log")
end

function M.OnKey(key, value) end

function M.Enable()
	M.on = true
	SUI.On("QUEST_LOG_UPDATE", M.OnLog)
	if not M.watching then
		M.watching = true
		C.Watch("guide.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("QUEST_LOG_UPDATE", M.OnLog)
	if M.frame then M.frame:Hide() end
	M.idx, M.idxQ = nil, nil
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("guide", 83)

SUI.RegisterModule("guide", {
	default = true,
	cost = "light",
	options = {
		{ key = "guide.learn", type = "bool", cat = "guide", label = "opt.guide.learn", tip = "tip.guide.learn",
			default = true, simple = true, order = 10 },
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("guide", function(rest)
	M.Toggle()
end, "help.guide")
