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

local getn, tinsert, tsort = table.getn, table.insert, table.sort
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
		local ng = { en = g.en, fr = g.fr, map = g.map, zid = g.zid, n = 0, pins = {} }
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
M.GCELL = 2.5                -- cote (en % de carte) d'une cellule : les donneurs d'une meme cellule ne font qu'un "!"
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
				gz = { id = -1, t = L("msg.questtrack.givers"), cap = Cx.PIN_POOL, n = 0, zones = { { en = en, fr = fr, map = P.ZoneMap(zid), zid = zid, n = 0, pins = {} } } }
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
							pin = { k = "S", x = e.x, y = e.y, nm = ref and P.QName(ref.kind, ref.id) or nil, ek = ref and ref.kind or nil, lines = {}, more = 0, q = {} }
							cells[key] = pin
							tinsert(pins, pin)
						end
						tinsert(pin.q, { id = e.id, lvl = e.lvl, title = title })
					end
				end
			end
			if pins[1] then
				for i = 1, getn(pins) do
					local pin = pins[i]
					tsort(pin.q, function(a, b)
						if a.lvl ~= b.lvl then return a.lvl < b.lvl end
						return a.title < b.title
					end)
					for k = 1, getn(pin.q) do
						local qe = pin.q[k]
						if k <= M.GTIPMAX then
							tinsert(pin.lines, (qe.lvl > 0 and ("[" .. qe.lvl .. "] ") or "") .. qe.title)
						elseif k == M.GTIPMAX + 1 then
							tinsert(pin.lines, L("msg.questtrack.more", getn(pin.q) - M.GTIPMAX))
						end
					end
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

-- ---------------------------------------------------------------- minicarte
-- Les memes epingles que la carte du monde (objectifs et rendus de tes quetes, donneurs), posees sur la minicarte autour du joueur.
-- Position : (epingle - joueur) en % de la carte de la zone x taille de la zone en yards (table ci-dessous), puis yards -> pixels d'apres le zoom de la
-- minicarte (rayon en yards selon le zoom, dehors / dedans). Les tailles de zones et les rayons viennent de pfQuest (MIT, db\minimap.lua et map.lua),
-- jamais lus a l'execution : la table est recopiee ici. Une epingle de quete suivie hors de portee reste au bord (repere de direction, plus pale).
-- Une minuterie (M.MINI_EVERY s) n'existe que tant que l'option est active, le Codex est actif ET une epingle peut etre posee.
M.MINI_EVERY = 0.2
M.MINI_MAX = 40
M.MINI_SIZE = 11
M.MINI_REFRESH = 3           -- secondes entre deux recompositions de la liste d'epingles (la position, elle, est calculee a chaque tour)
M.mpins = {}

-- Zones (numero de zone des donnees = numero de zone pfQuest) : { largeur, hauteur } en yards
M.YARDS = {
	[0]={35200,23467}, [1]={4925,3283}, [3]={2488,1658}, [4]={3350,2233}, [8]={2294,1529}, [10]={2700,1800}, [11]={4135,2756}, [12]={3471,2315},
	[14]={5288,3525}, [15]={5250,3500}, [16]={5071,3381}, [17]={10133,6756}, [25]={712,469}, [28]={4300,2867}, [33]={6381,4254}, [36]={2800,1867},
	[38]={2758,1840}, [40]={3500,2333}, [41]={2500,1667}, [44]={2171,1448}, [45]={3600,2400}, [46]={2929,1952}, [47]={3850,2567}, [51]={2231,1488},
	[85]={4519,3013}, [130]={4200,2800}, [139]={3871,2581}, [141]={5092,3394}, [148]={6550,4367}, [209]={381,254}, [215]={5138,3425}, [267]={3200,2133},
	[331]={5767,3844}, [357]={6950,4633}, [361]={5750,3833}, [400]={4400,2933}, [405]={4496,2998}, [406]={4883,3256}, [408]={3092,2047},
	[409]={2901,1916}, [440]={6900,4600}, [490]={3700,2467}, [491]={736,491}, [493]={2308,1540}, [616]={3206,2142}, [618]={7100,4733}, [717]={378,252},
	[718]={1170,785}, [719]={1222,806}, [721]={571,379}, [722]={709,473}, [796]={204,135}, [876]={828,541}, [1176]={1383,923}, [1337]={894,596},
	[1377]={3483,2323}, [1477]={695,463}, [1497]={959,640}, [1519]={1738,1158}, [1537]={791,528}, [1581]={450,300}, [1583]={887,591}, [1584]={1407,938},
	[1637]={1403,935}, [1638]={1044,696}, [1657]={1058,706}, [1941]={1348,888}, [1977]={2121,1415}, [2017]={1185,790}, [2040]={1468,976},
	[2041]={1513,1003}, [2057]={320,213}, [2100]={2112,1411}, [2159]={483,322}, [2257]={312,208}, [2366]={1086,727}, [2437]={739,493}, [2557]={1275,850},
	[2597]={4238,2825}, [2677]={499,333}, [2717]={1265,843}, [3277]={1146,765}, [3358]={1756,1171}, [3428]={978,652}, [3429]={2513,1675},
	[3456]={1992,1318}, [3457]={823,549}, [3478]={4139,2946}, [4012]={3159,2108}, [5023]={989,1393}, [5024]={1608,1075}, [5053]={1008,672},
	[5077]={2643,1751}, [5086]={547,392}, [5087]={355,235}, [5097]={1273,854}, [5103]={752,510}, [5121]={3227,2187}, [5130]={1432,977}, [5135]={320,213},
	[5136]={620,413}, [5138]={657,435}, [5144]={309,208}, [5147]={2778,1852}, [5148]={652,440}, [5153]={613,408}, [5163]={703,469}, [5179]={3666,2442},
	[5204]={1272,845}, [5208]={1250,837}, [5225]={3082,2061}, [5536]={2472,1665}, [5557]={2800,1868},
}

-- Diametre visible de la minicarte en yards, selon le zoom 0..5 : [0] dedans, [1] dehors
M.MINIZ = {
	[0] = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
	[1] = { [0] = 466.667, [1] = 400, [2] = 333.333, [3] = 266.667, [4] = 200, [5] = 133.333 },
}

-- 0 si la minicarte est au zoom "dedans" (reglage du client), 1 dehors
function M.Indoor(zoom)
	local gc = glob("GetCVar")
	if not gc then return 1 end
	local inside, outside = tonumber(gc("minimapInsideZoom")), tonumber(gc("minimapZoom"))
	if inside and outside and inside ~= outside and zoom == inside then return 0 end
	return 1
end

function M.MiniFrame(i)
	local p = M.mpins[i]
	if p then return p end
	local mm = glob("Minimap")
	if i > M.MINI_MAX or not mm then return nil end
	p = CreateFrame("Frame", nil, mm)
	p:SetWidth(M.MINI_SIZE)
	p:SetHeight(M.MINI_SIZE)
	p:SetFrameLevel(mm:GetFrameLevel() + 6)
	T.Backdrop(p, T.c.warn, T.c.bg)
	p.mark = T.Text(p, 9, T.c.bg, "CENTER")
	p.mark:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.kind = "S"
	p:Hide()
	M.mpins[i] = p
	return p
end

function M.MiniHideAll()
	for i = 1, getn(M.mpins) do M.mpins[i]:Hide() end
end

-- Liste plate des epingles a poser pres du joueur : { d, zid, tracked }, recomposee toutes les M.MINI_REFRESH secondes ou si la zone change
function M.MiniList(Cx, c, z)
	local rz = glob("GetRealZoneText")
	local ul = glob("UnitLevel")
	local key = tostring(rz and rz() or "") .. "|" .. c .. "," .. z .. "|" .. tostring(ul and ul("player") or 0) .. "|" .. getn(M.list)
	local now = GetTime()
	if M.miniKey == key and M.miniList and now < (M.miniNext or 0) then return M.miniList end
	M.miniKey, M.miniNext = key, now + M.MINI_REFRESH
	local out = {}
	local srcs = M.Recs()
	for s = 1, getn(srcs) do
		local rec = srcs[s]
		local g = Cx.PinHere(rec, c, z)
		for k = 1, g and getn(g.pins) or 0 do
			if getn(out) >= M.MINI_MAX then break end
			tinsert(out, { d = g.pins[k], zid = g.zid, rec = rec, tracked = (rec.id or 0) >= 0 })
		end
	end
	M.miniList = out
	return out
end

function M.MiniTick()
	local Cx = codex()
	local mm = glob("Minimap")
	local gp = glob("GetPlayerMapPosition")
	local wm = glob("WorldMapFrame")
	if not Cx or not mm or not gp or not mm:IsShown() or (wm and wm:IsShown()) then
		M.MiniHideAll()
		return
	end
	local px, py = gp("player")
	local c, z = Cx.MapCur()
	if not px or not c or not z or z <= 0 or (px == 0 and py == 0) then
		M.MiniHideAll()
		return
	end
	local list = M.MiniList(Cx, c, z)
	local zoom = mm:GetZoom() or 0
	local diam = M.MINIZ[M.Indoor(zoom)][zoom] or 400
	local size = mm:GetWidth()
	local ppy = size / diam
	local half = size / 2 - 5
	local square = C.Get("minimap.shape") == "square"
	local edge = C.Get("questtrack.miniedge")
	px, py = px * 100, py * 100
	local n = 0
	for i = 1, getn(list) do
		local e = list[i]
		local sz = e.zid and M.YARDS[e.zid]
		if sz then
			local sx = (e.d.x - px) / 100 * sz[1] * ppy
			local sy = -(e.d.y - py) / 100 * sz[2] * ppy
			local far
			if square then
				far = (math.abs(sx) > half) or (math.abs(sy) > half)
			else
				far = (sx * sx + sy * sy) > half * half
			end
			local alpha = 1
			if far then
				if e.tracked and edge then
					local k
					if square then
						local m = math.max(math.abs(sx), math.abs(sy))
						k = half / m
					else
						k = half / math.sqrt(sx * sx + sy * sy)
					end
					sx, sy = sx * k, sy * k
					alpha = 0.55
				else
					sz = nil
				end
			end
			if sz then
				local p = M.MiniFrame(n + 1)
				if not p then break end
				local vk = Cx.PinVisual(e.d)
				local ent = Cx.PinEntries(e.rec, e.d)
				local mk = Cx.PinMark(vk, ent and getn(ent) or 0)
				if p.kind ~= vk then
					p.kind = vk
					T.Backdrop(p, Cx.PinColor(vk), T.c.bg)
				end
				if p.markText ~= mk then
					p.markText = mk
					p.mark:SetText(mk)
				end
				p:SetAlpha(alpha)
				p:ClearAllPoints()
				p:SetPoint("CENTER", mm, "CENTER", sx, sy)
				p:Show()
				n = n + 1
			end
		end
	end
	for i = n + 1, getn(M.mpins) do M.mpins[i]:Hide() end
end

-- Minuterie de la minicarte : seulement si l'option est active, le Codex aussi, et le module actif
function M.MiniSync()
	local want = M.on and codex() ~= nil and C.Get("questtrack.mini") and true or false
	if want and not M.miniTask then
		M.miniTask = SUI.Every(M.MINI_EVERY, M.MiniTick, "questtrack.mini")
	elseif not want and M.miniTask then
		SUI.Cancel(M.miniTask)
		M.miniTask = nil
		M.miniKey, M.miniList = nil, nil
		M.MiniHideAll()
	end
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
	M.ApplySize(Cx)
	M.MiniSync()
end

-- Taille des epingles de la carte (option) : applique aux epingles deja creees
function M.ApplySize(Cx)
	local s = C.Get("questtrack.pinsize")
	if type(s) ~= "number" or s == Cx.PIN_SIZE then return end
	Cx.PIN_SIZE = s
	for i = 1, getn(Cx.pins) do
		Cx.pins[i]:SetWidth(s)
		Cx.pins[i]:SetHeight(s)
	end
end

-- Titre affiche : celui des donnees du Codex (francais quand l'interface l'est) si la quete est reconnue, sinon celui du client
function M.Title(e)
	local Cx = codex()
	if Cx and type(e.id) == "number" and Cx.P.Q() then
		local t = Cx.P.QuestTitle(e.id)
		if type(t) == "string" and t ~= "" then return t end
	end
	return e.title
end

-- Reconnait toutes les quetes de la liste (charge les donnees du Codex une fois, quelques secondes apres la lecture) puis repeint
function M.ResolveAll()
	M.resTask = nil
	if not M.on or not codex() then return end
	for i = 1, getn(M.list) do M.Resolve(M.list[i]) end
	M.Paint()
end

-- Glisser pour deplacer la liste (option) : sans quitter le jeu ni ouvrir le mode deplacement
function M.DragOn()
	return C.Get("questtrack.drag") and true or false
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
	if SUI.Mover and SUI.Mover.QuickDrag then
		b:RegisterForDrag("LeftButton")
		b:SetScript("OnDragStart", function()
			if f.quickDragStart then f.quickDragStart() end
		end)
		b:SetScript("OnDragStop", function()
			if f.quickDragStop then f.quickDragStop() end
		end)
	end
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
		SUI.Mover.Register("questtrack", f, { label = "mod.questtrack.mover", point = "TOPRIGHT", x = -110, y = -200 })
		SUI.Mover.QuickDrag(f, "questtrack", M.DragOn)
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
		b.txt:SetText((e.level > 0 and ("[" .. e.level .. "] ") or "") .. M.Title(e))
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

-- Vrai quand toutes les quetes de la liste ont deja un numero (ou un constat d'inconnue)
function M.listResolved(list)
	for i = 1, getn(list) do
		if list[i].id == nil then return false end
	end
	return true
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
	if codex() and not M.resTask and not M.listResolved(list) then M.resTask = SUI.After(2, M.ResolveAll, "questtrack.res") end
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
	if C.Get("questtrack.drag") then GameTooltip:AddLine(L("msg.questtrack.tip.drag"), d[1], d[2], d[3]) end
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
	M.MiniSync()
	if M.frame then M.frame:Hide() end
	if M.resTask then
		SUI.Cancel(M.resTask)
		M.resTask = nil
	end
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
		opt("drag", "bool", 12, true, { simple = true }),
		opt("pins", "bool", 20, true, { simple = true }),
		opt("givers", "bool", 25, true, { simple = true }),
		opt("mini", "bool", 22, true, { simple = true }),
		opt("miniedge", "bool", 23, true),
		opt("pinsize", "number", 24, 14, { min = 10, max = 24, step = 1 }),
		opt("giverlow", "number", 26, 6, { min = 0, max = 20, step = 1 }),
		opt("max", "number", 30, 8, { min = 3, max = 15, step = 1 }),
		opt("width", "number", 40, 230, { min = 160, max = 400, step = 10 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("quests", function(rest) M.Command(rest or "") end, "help.questtrack")
