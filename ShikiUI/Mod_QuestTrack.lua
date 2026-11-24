-- ShikiUI QuestTrack : suivi des quetes en cours. Une petite liste deplacable a l'ecran (titre + objectifs de chaque quete du journal, lus par l'API
-- du client, sans aucune donnee), et, avec le module Codex, les objectifs de TOUTES ces quetes epingles sur la carte du monde (rond "o" : objectif
-- d'une quete en cours, "?" : rendu d'une quete terminee). Un clic sur un titre epingle la quete seule (comme /sui codex pin).
-- Les donnees de quetes (ShikiCodexData_Quests) ne sont chargees que carte ouverte ou au clic, jamais au login : la liste, elle, n'en a pas besoin.
-- Titre du journal -> numero de quete : par le titre (anglais ou francais), puis le niveau affiche dans le journal ; titre inconnu : la quete reste
-- dans la liste mais n'a pas d'epingle. Evenements : QUEST_LOG_UPDATE (regroupes, 0,3 s), PLAYER_ENTERING_WORLD. Aucune minuterie permanente.
-- NON VERIFIE EN JEU : GetNumQuestLeaderBoards(i) / GetQuestLogLeaderBoard(j, i) avec l'indice de quete en 2e argument (1.12), zones repliees du
-- journal (leurs quetes ne sont pas listees par le client : elles manquent ici aussi).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local slower, sformat = string.lower, string.format
local floor = math.floor

local M = {}
SUI.QuestTrack = M

M.on = false
M.DELAY = 0.3                -- silence attendu apres le dernier QUEST_LOG_UPDATE
M.MAXQ = 15                  -- plafond dur de quetes affichees
M.MAXOBJ = 8                 -- objectifs affiches par quete
M.PAD = 6
M.list = {}                  -- quetes lues : { i, title, level, complete, objs = { { text, done } }, id = nil | false | numero }
M.rows = {}                  -- lignes du cadre (creees a la demande)
M.sig = nil
M.recs = {}                  -- enregistrements de carte deja construits : [numero .. ":" .. etat]

local function glob(name)
	return getglobal(name)
end

-- ---------------------------------------------------------------- lecture du journal
-- Quetes du journal, dans l'ordre du client (les en-tetes de zone sont sautes). nil si l'API manque.
function M.Read()
	local gn, gt = glob("GetNumQuestLogEntries"), glob("GetQuestLogTitle")
	if not gn or not gt then return nil end
	local ok, n = pcall(gn)
	if not ok or type(n) ~= "number" then return nil end
	local gnb, gb = glob("GetNumQuestLeaderBoards"), glob("GetQuestLogLeaderBoard")
	local out = {}
	for i = 1, n do
		local ok2, title, level, _, isHeader, _, isComplete = pcall(gt, i)
		if ok2 and type(title) == "string" and not isHeader then
			local e = { i = i, title = title, level = tonumber(level) or 0, complete = (isComplete == 1), objs = {} }
			if gnb and gb then
				local ok3, no = pcall(gnb, i)
				if ok3 and type(no) == "number" then
					if no > M.MAXOBJ then no = M.MAXOBJ end
					for j = 1, no do
						local ok4, text, _, done = pcall(gb, j, i)
						if ok4 and type(text) == "string" and text ~= "" then
							tinsert(e.objs, { text = text, done = (done == 1 or done == true) })
						end
					end
				end
			end
			tinsert(out, e)
		end
	end
	return out
end

-- Signature de la liste (texte) : repeindre seulement si elle change
function M.Signature(list)
	local s = ""
	for i = 1, getn(list) do
		local e = list[i]
		s = s .. e.title .. "|" .. e.level .. "|" .. (e.complete and "1" or "0")
		for j = 1, getn(e.objs) do s = s .. "|" .. e.objs[j].text .. (e.objs[j].done and "+" or "-") end
		s = s .. "\n"
	end
	return s
end

-- ---------------------------------------------------------------- titre -> numero de quete (donnees du Codex)
local function codex()
	local Cx = SUI.Codex
	if Cx and Cx.on and Cx.P then return Cx end
	return nil
end

-- Index titre minuscule -> { numeros } (anglais et francais), construit une fois quand les donnees sont chargees
function M.TitleIndex(Cx)
	if M.tix then return M.tix end
	local P = Cx.P
	local ok = P.LoadQuests()
	if not ok then return nil end
	local qd = P.Q()
	if not qd or not qd.en or not qd.en.t then return nil end
	local idx = {}
	local function add(id, t)
		if type(t) ~= "string" then return end
		local k = slower(t)
		local l = idx[k]
		if not l then
			idx[k] = { id }
		elseif l[getn(l)] ~= id then
			tinsert(l, id)
		end
	end
	for id, t in pairs(qd.en.t) do add(id, t) end
	if qd.fr and qd.fr.t then
		for id, t in pairs(qd.fr.t) do add(id, t) end
	end
	M.tix = idx
	return idx
end

-- Numero de la quete d'une ligne du journal : niveau identique d'abord, sinon le plus petit numero ; false = inconnue ; nil = donnees indisponibles
function M.Resolve(e)
	if e.id ~= nil then return e.id end
	local Cx = codex()
	if not Cx then return nil end
	local idx = M.TitleIndex(Cx)
	if not idx then return nil end
	local l = idx[slower(e.title)]
	if not l then
		e.id = false
		return false
	end
	local best, any = nil, nil
	for k = 1, getn(l) do
		local id = l[k]
		if not any or id < any then any = id end
		local lvl = Cx.P.QuestLevels(id)
		if lvl == e.level and (not best or id < best) then best = id end
	end
	e.id = best or any
	return e.id
end

-- ---------------------------------------------------------------- enregistrements de carte (fournisseur du Codex)
-- Copie d'un enregistrement du Codex ne gardant que les epingles de type `kind` ("O" objectifs, "E" rendu) ; nil sans epingle
local function filtered(rec, kind)
	local out = { id = rec.id, t = rec.t, n = 0, zones = {} }
	for i = 1, getn(rec.zones) do
		local g = rec.zones[i]
		local ng = { en = g.en, fr = g.fr, map = g.map, n = 0, pins = {} }
		for k = 1, getn(g.pins) do
			if g.pins[k].k == kind then
				tinsert(ng.pins, g.pins[k])
				ng.n = ng.n + 1
			end
		end
		if ng.n > 0 then
			out.n = out.n + ng.n
			tinsert(out.zones, ng)
		end
	end
	if out.n == 0 then return nil end
	return out
end

-- ---------------------------------------------------------------- donneurs de quetes ("!" sur la carte)
-- Index { numero de zone -> liste d'entrees { id, lvl, min, races, classes, x, y, ref } } des epingles de DEPART de toutes les quetes, construit par
-- paquets (M.GCHUNK quetes par tour) la premiere fois que la carte est ouverte, puis garde (quelques dizaines de ko par millier de quetes).
M.GCHUNK = 400
M.GCELL = 1.5                -- cote (en % de carte) d'une cellule : les donneurs d'une meme cellule ne font qu'un "!"
M.GTIPMAX = 6                -- quetes listees dans l'infobulle d'un "!"

local function splitSec(s)
	local out, pos = {}, 1
	local a = string.find(s, ";", pos, true)
	while a do
		tinsert(out, string.sub(s, pos, a - 1))
		pos = a + 1
		a = string.find(s, ";", pos, true)
	end
	tinsert(out, string.sub(s, pos))
	return out
end

-- Masques de pfQuest du joueur (race, classe) ; nil si inconnus (aucun filtre)
function M.PlayerBits()
	local ur, uc = glob("UnitRace"), glob("UnitClass")
	local RACE = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
	local CLASS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128, WARLOCK = 256, DRUID = 1024 }
	local rb, cb
	if ur then
		local ok, _, en = pcall(ur, "player")
		if ok and type(en) == "string" then rb = RACE[en] end
	end
	if uc then
		local ok, _, tok = pcall(uc, "player")
		if ok and type(tok) == "string" then cb = CLASS[tok] end
	end
	return rb, cb
end

local function hasBit(mask, b)
	local q = floor(mask / b)
	return q - floor(q / 2) * 2 == 1
end

function M.GiverStart()
	if M.gready or M.gbuilding then return end
	local Cx = codex()
	if not Cx then return end
	local P = Cx.P
	if not P.LoadQuests() then return end
	local qd = P.Q()
	if not qd or type(qd.q) ~= "table" then return end
	local ids = {}
	for id in pairs(qd.q) do tinsert(ids, id) end
	M.gids, M.gpos, M.gby, M.gbuilding = ids, 1, {}, true
	M.GiverStep()
end

function M.GiverStep()
	M.gtask = nil
	local Cx = codex()
	if not M.on or not Cx then
		M.gbuilding, M.gids, M.gby = false, nil, nil
		return
	end
	local P = Cx.P
	local qd = P.Q()
	local ids, by = M.gids, M.gby
	local last = M.gpos + M.GCHUNK - 1
	if last > getn(ids) then last = getn(ids) end
	for k = M.gpos, last do
		local id = ids[k]
		local s = qd.q[id]
		if type(s) == "string" and string.find(s, "S", 1, true) then
			local f = splitSec(s)
			local pins = P.QuestPins(id)
			for i = 1, pins and getn(pins) or 0 do
				local p = pins[i]
				if p.kind == "S" then
					local l = by[p.zone]
					if not l then
						l = {}
						by[p.zone] = l
					end
					tinsert(l, { id = id, lvl = tonumber(f[1]) or 0, min = tonumber(f[2]) or 0, races = tonumber(f[3]) or 0, classes = tonumber(f[4]) or 0,
						x = p.x, y = p.y, ref = p.ref })
				end
			end
		end
	end
	M.gpos = last + 1
	if M.gpos > getn(ids) then
		M.gready, M.gbuilding, M.gids = true, false, nil
		if Cx.trackFn == M.Recs and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
	else
		M.gtask = SUI.After(0.02, M.GiverStep, "questtrack.giver")
	end
end

-- Quete du journal portant ce titre ? (inutile de proposer une quete deja prise)
local function inLog(title)
	for i = 1, getn(M.list) do
		if M.list[i].title == title then return true end
	end
	return false
end

-- Enregistrements des donneurs de la zone affichee (c, z) selon le niveau, la race et la classe du joueur ; nil si aucun
function M.GiverRec(Cx, c, z)
	if not M.gready or not c or not z or z <= 0 then return nil end
	local P = Cx.P
	local ul = glob("UnitLevel")
	local pl = ul and ul("player") or 0
	if type(pl) ~= "number" or pl < 1 then return nil end
	local low = C.Get("questtrack.giverlow")
	local rb, cb = M.PlayerBits()
	local out = nil
	M.gz = M.gz or {}
	for zid, list in pairs(M.gby) do
		local gz = M.gz[zid]
		if gz == nil then
			local en, fr = P.ZoneBoth(zid)
			if en then
				gz = { id = -1, t = L("msg.questtrack.givers"), cap = Cx.PIN_POOL, n = 0, zones = { { en = en, fr = fr, map = P.ZoneMap(zid), n = 0, pins = {} } } }
			else
				gz = false
			end
			M.gz[zid] = gz
		end
		if gz and Cx.PinHere(gz, c, z) then
			local cells, pins = {}, {}
			for i = 1, getn(list) do
				local e = list[i]
				local ok = (e.min == 0 or e.min <= pl) and (e.lvl == 0 or e.lvl >= pl - low)
				if ok and e.races ~= 0 and rb and not hasBit(e.races, rb) then ok = false end
				if ok and e.classes ~= 0 and cb and not hasBit(e.classes, cb) then ok = false end
				if ok then
					local title = P.QuestTitle(e.id)
					if title and not inLog(title) then
						local key = floor(e.x / M.GCELL) * 1000 + floor(e.y / M.GCELL)
						local pin = cells[key]
						if not pin then
							local def = P.Quest(e.id)
							local ref = def and def.start and def.start[e.ref]
							pin = { k = "S", x = e.x, y = e.y, nm = ref and P.QName(ref.kind, ref.id) or nil, ek = ref and ref.kind or nil, lines = {}, more = 0 }
							cells[key] = pin
							tinsert(pins, pin)
						end
						if getn(pin.lines) < M.GTIPMAX then
							tinsert(pin.lines, (e.lvl > 0 and ("[" .. e.lvl .. "] ") or "") .. title)
						else
							pin.more = pin.more + 1
						end
					end
				end
			end
			if pins[1] then
				for i = 1, getn(pins) do
					local pin = pins[i]
					if pin.more > 0 then tinsert(pin.lines, L("msg.questtrack.more", pin.more)) end
					pin.more = nil
				end
				local g = gz.zones[1]
				g.pins, g.n = pins, getn(pins)
				gz.n = g.n
				out = out or {}
				tinsert(out, gz)
			end
		end
	end
	return out
end

-- Fournisseur appele par le Codex (carte ouverte seulement) : une liste d'enregistrements resolus pour les quetes du journal
function M.Recs()
	local Cx = codex()
	if not Cx or not M.on or not C.Get("questtrack.pins") then return {} end
	local out = {}
	for i = 1, getn(M.list) do
		local e = M.list[i]
		local id = M.Resolve(e)
		if id then
			local kind = e.complete and "E" or "O"
			local key = id .. ":" .. kind
			local rec = M.recs[key]
			if rec == nil then
				local full = Cx.PinBuild(id)
				rec = full and filtered(full, kind) or false
				M.recs[key] = rec
			end
			if rec then tinsert(out, rec) end
		end
	end
	if C.Get("questtrack.givers") then
		if M.gready then
			local c, z = Cx.MapCur()
			local g = M.GiverRec(Cx, c, z)
			for i = 1, g and getn(g) or 0 do tinsert(out, g[i]) end
		else
			M.GiverStart()
		end
	end
	return out
end

-- Branche / debranche le fournisseur selon l'etat du module, du Codex et de l'option (a rappeler a chaque changement)
function M.Sync()
	local Cx = SUI.Codex
	if not Cx or not Cx.PinTrack then return end
	local want = M.on and Cx.on and C.Get("questtrack.pins") and true or false
	if want and Cx.trackFn ~= M.Recs then
		Cx.PinTrack(M.Recs)
	elseif not want and Cx.trackFn == M.Recs then
		Cx.PinTrack(nil)
	end
end

-- ---------------------------------------------------------------- cadre
function M.Row(i)
	local r = M.rows[i]
	if r then return r end
	local f = M.frame
	local b = CreateFrame("Button", nil, f)
	b:SetHeight(14)
	b:EnableMouse(true)
	b.txt = T.Text(b, 11, T.c.warn, "LEFT")
	b.txt:SetPoint("LEFT", b, "LEFT", 0, 0)
	b:SetScript("OnClick", function() M.OnTitle(this) end)
	b:SetScript("OnEnter", function() M.OnTip(this) end)
	b:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	r = { btn = b, objs = {} }
	for j = 1, M.MAXOBJ do
		local fs = T.Text(f, 10, T.c.text, "LEFT")
		r.objs[j] = fs
	end
	M.rows[i] = r
	return r
end

function M.Build()
	if M.frame then return M.frame end
	local f = CreateFrame("Frame", "ShikiUI_QuestTrack", UIParent)
	f:SetWidth(C.Get("questtrack.width"))
	f:SetHeight(40)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:Hide()
	M.frame = f
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("questtrack", f, { label = "mod.questtrack.mover", point = "TOPRIGHT", x = -20, y = -230 })
	end
	return f
end

local function lineHeight(fs, min)
	local h = fs:GetHeight()
	if type(h) ~= "number" or h < min then return min end
	return h
end

-- Peint la liste : une ligne de titre puis les objectifs de chaque quete ; cadre cache sans quete
function M.Paint()
	local f = M.frame
	if not f then return end
	local n = getn(M.list)
	local max = C.Get("questtrack.max")
	if n > max then n = max end
	if n > M.MAXQ then n = M.MAXQ end
	if n == 0 or not C.Get("questtrack.show") then
		f:Hide()
		return
	end
	local w = C.Get("questtrack.width")
	f:SetWidth(w)
	local y = M.PAD
	for i = 1, n do
		local e = M.list[i]
		local r = M.Row(i)
		local b = r.btn
		b.entry = e
		b:SetWidth(w - 2 * M.PAD)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f, "TOPLEFT", M.PAD, -y)
		local col = e.complete and T.c.good or T.c.warn
		b.txt:SetTextColor(col[1], col[2], col[3], col[4] or 1)
		b.txt:SetWidth(w - 2 * M.PAD)
		b.txt:SetText((e.level > 0 and ("[" .. e.level .. "] ") or "") .. e.title)
		b:Show()
		y = y + 15
		for j = 1, M.MAXOBJ do
			local fs = r.objs[j]
			local o = e.objs[j]
			if o then
				local c = o.done and T.c.dim or T.c.text
				fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
				fs:SetWidth(w - 2 * M.PAD - 8)
				fs:ClearAllPoints()
				fs:SetPoint("TOPLEFT", f, "TOPLEFT", M.PAD + 8, -y)
				fs:SetText(o.text)
				fs:Show()
				y = y + lineHeight(fs, 12)
			else
				fs:Hide()
			end
		end
		y = y + 3
	end
	for i = n + 1, getn(M.rows) do
		M.rows[i].btn:Hide()
		for j = 1, M.MAXOBJ do M.rows[i].objs[j]:Hide() end
	end
	f:SetHeight(y + M.PAD)
	f:Show()
end

-- ---------------------------------------------------------------- lecture et repeinture
function M.Scan()
	M.task = nil
	if not M.on then return end
	local list = M.Read()
	if not list then return end
	local sig = M.Signature(list)
	if sig == M.sig then return end
	M.sig = sig
	-- numeros deja resolus : repris par titre + niveau (la lecture repart de zero a chaque changement)
	local old = M.list
	M.list = list
	for i = 1, getn(list) do
		for k = 1, getn(old) do
			if old[k].title == list[i].title and old[k].level == list[i].level and old[k].id ~= nil then
				list[i].id = old[k].id
				break
			end
		end
	end
	M.Build()
	M.Paint()
	local Cx = SUI.Codex
	if Cx and Cx.trackFn == M.Recs and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
end

function M.Queue()
	if not M.on or M.task then return end
	M.task = SUI.After(M.DELAY, M.Scan, "questtrack.scan")
end

-- ---------------------------------------------------------------- souris
function M.OnTitle(b)
	local e = b.entry
	if not e then return end
	local Cx = SUI.Codex
	if not (Cx and Cx.on) then
		SUI.Print(L("msg.questtrack.nocodex"))
		return
	end
	local id = M.Resolve(e)
	if not id then
		SUI.Print(L("msg.questtrack.unknown", e.title))
		return
	end
	Cx.PinQuest(id)
end

function M.OnTip(b)
	local e = b.entry
	if not e or not GameTooltip then return end
	local d = T.c.dim
	GameTooltip:SetOwner(b, "ANCHOR_LEFT")
	GameTooltip:SetText(e.title)
	GameTooltip:AddLine(L(e.complete and "msg.questtrack.tip.done" or "msg.questtrack.tip.todo"), d[1], d[2], d[3])
	GameTooltip:AddLine(L("msg.questtrack.tip.click"), d[1], d[2], d[3])
	GameTooltip:Show()
end

-- ---------------------------------------------------------------- cycle de vie, commande
function M.OnKey(key, value)
	if not M.on then return end
	M.Sync()
	if M.frame then M.Paint() end
	if key == "questtrack.pins" or key == "questtrack.givers" or key == "questtrack.giverlow" then
		local Cx = SUI.Codex
		if Cx and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
	end
end

function M.Enable()
	M.on = true
	SUI.On("QUEST_LOG_UPDATE", M.Queue)
	SUI.On("PLAYER_ENTERING_WORLD", M.Queue)
	if not M.watching then
		M.watching = true
		C.Watch("questtrack.", M.OnKey)
	end
	M.Sync()
	M.Queue()
end

function M.Disable()
	M.on = false
	SUI.Off("QUEST_LOG_UPDATE", M.Queue)
	SUI.Off("PLAYER_ENTERING_WORLD", M.Queue)
	if M.task then
		SUI.Cancel(M.task)
		M.task = nil
	end
	M.Sync()
	if M.frame then M.frame:Hide() end
	if M.gtask then
		SUI.Cancel(M.gtask)
		M.gtask = nil
	end
	M.list, M.sig, M.tix, M.recs = {}, nil, nil, {}
	M.gready, M.gbuilding, M.gids, M.gby, M.gz = false, false, nil, nil, nil
end

function M.Command(rest)
	local arg = slower(rest or "")
	if arg == "show" or arg == "hide" then
		C.Set("questtrack.show", arg == "show")
	end
	SUI.Print(L("msg.questtrack.status", getn(M.list), C.Get("questtrack.show") and "1" or "0"))
end

local function opt(key, typ, order, def, extra)
	local o = { key = "questtrack." .. key, type = typ, cat = "questtrack", label = "opt.questtrack." .. key, tip = "tip.questtrack." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterCategory("questtrack", 80)

SUI.RegisterModule("questtrack", {
	default = false,
	cost = "light",
	options = {
		opt("show", "bool", 10, true, { simple = true }),
		opt("pins", "bool", 20, true, { simple = true }),
		opt("givers", "bool", 25, true, { simple = true }),
		opt("giverlow", "number", 26, 6, { min = 0, max = 20, step = 1 }),
		opt("max", "number", 30, 8, { min = 3, max = 15, step = 1 }),
		opt("width", "number", 40, 230, { min = 160, max = 400, step = 10 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("quests", function(rest) M.Command(rest or "") end, "help.questtrack")
