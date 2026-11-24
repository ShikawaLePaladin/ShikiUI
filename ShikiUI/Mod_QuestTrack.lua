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
	local zone = nil
	for i = 1, n do
		local ok2, title, level, _, isHeader, _, isComplete = pcall(gt, i)
		if ok2 and type(title) == "string" and isHeader then zone = title end
		if ok2 and type(title) == "string" and not isHeader then
			local e = { i = i, title = title, level = tonumber(level) or 0, complete = (isComplete == 1), objs = {}, zone = zone }
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

-- ---------------------------------------------------------------- choix des quetes affichees
-- "questtrack.hide" : cles "titre#niveau" des quetes retirees de la liste, separees par "|" (cle hors menu). Tout le reste du journal est affiche.
-- "questtrack.arrowq" : cle de la quete visee par la fleche ("" = la plus proche). M.list reste le journal entier ; M.View() est ce qu'on montre.
M.MAXHIDE = 60
SUI.Config.Register({ ["questtrack.hide"] = "", ["questtrack.arrowq"] = "" })

function M.Key(e)
	local k = string.gsub(e.title, "|", "")
	return k .. "#" .. e.level
end

local function hideSet()
	local s = C.Get("questtrack.hide")
	if type(s) ~= "string" then return "" end
	return s
end

function M.IsShown(e)
	return not string.find("|" .. hideSet() .. "|", "|" .. M.Key(e) .. "|", 1, true)
end

-- Montre / retire une quete de la liste (enregistre ; les plus anciennes retraits sont oublies au-dela de M.MAXHIDE)
function M.SetShown(e, on)
	local key = M.Key(e)
	local arr = {}
	for k in string.gfind(hideSet(), "[^|]+") do
		if k ~= key then tinsert(arr, k) end
	end
	if not on then tinsert(arr, key) end
	while getn(arr) > M.MAXHIDE do table.remove(arr, 1) end
	C.Set("questtrack.hide", table.concat(arr, "|"))
end

function M.SetAllShown(on)
	if on then
		C.Set("questtrack.hide", "")
		return
	end
	local arr = {}
	for i = 1, getn(M.list) do tinsert(arr, M.Key(M.list[i])) end
	while getn(arr) > M.MAXHIDE do table.remove(arr, 1) end
	C.Set("questtrack.hide", table.concat(arr, "|"))
end

local function zoneNow()
	local f = glob("GetRealZoneText") or glob("GetZoneText")
	if not f then return nil end
	local ok, z = pcall(f)
	if ok and type(z) == "string" and z ~= "" then return z end
	return nil
end

-- Quetes montrees : le journal sans les retraits ; zoneOnly (liste a l'ecran seulement) : seulement celles de la zone ou tu es, si elle est connue
function M.View(zoneOnly)
	local out = {}
	local zn = zoneOnly and C.Get("questtrack.zoneonly") and zoneNow() or nil
	for i = 1, getn(M.list) do
		local e = M.list[i]
		if M.IsShown(e) and (not zn or e.zone == zn) then tinsert(out, e) end
	end
	return out
end

function M.NumShown()
	local n = 0
	for i = 1, getn(M.list) do
		if M.IsShown(M.list[i]) then n = n + 1 end
	end
	return n
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

-- Enregistrement de carte d'une quete du journal (objectifs, ou rendu si terminee) ; nil si inconnue / sans epingle. Mis en cache.
function M.EntryRec(Cx, e)
	local id = M.Resolve(e)
	if not id then return nil end
	local kind = e.complete and "E" or "O"
	local key = id .. ":" .. kind
	local rec = M.recs[key]
	if rec == nil then
		local full = Cx.PinBuild(id)
		rec = full and filtered(full, kind) or false
		M.recs[key] = rec
	end
	return rec or nil
end

-- Fournisseur appele par le Codex (carte ouverte seulement) : une liste d'enregistrements resolus pour les quetes du journal
function M.Recs(c, z, ctx)
	local Cx = codex()
	if not Cx or not M.on then return {} end
	local mini = ctx == "mini"
	local wantObj = (ctx == "arrow") or C.Get(mini and "questtrack.mini" or "questtrack.pins") and true or false
	local wantGiv = (ctx ~= "arrow") and C.Get(mini and "questtrack.minigivers" or "questtrack.givers") and true or false
	if not wantObj and not wantGiv then return {} end
	local out = {}
	local view = wantObj and M.View() or {}
	for i = 1, getn(view) do
		local rec = M.EntryRec(Cx, view[i])
		if rec then tinsert(out, rec) end
	end
	if wantGiv then
		if M.gready then
			if not c then c, z = Cx.MapCur() end
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
M.MINI_EVERY = 0.25          -- tour lent (choix des epingles) ; la position est posee a chaque image par M.MiniMove
M.MINI_MAX = 40
M.MINI_SIZE = 15
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
	p.tex = p:CreateTexture(nil, "ARTWORK")
	p.tex:SetAllPoints(p)
	p.mark = T.Text(p, 9, T.c.text, "RIGHT", true)
	p.mark:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 3, -2)
	p.kind = "S"
	p:Hide()
	M.mpins[i] = p
	return p
end

M.mact, M.mn = {}, 0

function M.MiniHideAll()
	M.lpx, M.llist, M.mact, M.mn = nil, nil, {}, 0
	for i = 1, getn(M.mpins) do M.mpins[i]:Hide() end
	if M.mover then M.mover:Hide() end
end

-- Liste plate des epingles a poser pres du joueur : { d, zid, rec, tracked }, recomposee toutes les M.MINI_REFRESH secondes ou si la zone change
function M.MiniList(Cx, c, z, px, py)
	if M.miniList and M.miniC == c and M.miniZ == z and GetTime() < (M.miniNext or 0) then return M.miniList end
	M.miniC, M.miniZ = c, z
	local rz = glob("GetRealZoneText")
	local ul = glob("UnitLevel")
	local key = tostring(rz and rz() or "") .. "|" .. c .. "," .. z .. "|" .. tostring(ul and ul("player") or 0) .. "|" .. getn(M.list)
	local now = GetTime()
	if M.miniKey == key and M.miniList and now < (M.miniNext or 0) then return M.miniList end
	M.miniKey, M.miniNext = key, now + M.MINI_REFRESH
	local out = {}
	local srcs = M.on and M.Recs(c, z, "mini") or {}
	for s = 1, getn(srcs) do
		local rec = srcs[s]
		local g = Cx.PinHere(rec, c, z)
		for k = 1, g and getn(g.pins) or 0 do
			if getn(out) >= M.MINI_MAX then break end
			tinsert(out, { d = g.pins[k], zid = g.zid, rec = rec, tracked = (rec.id or 0) >= 0 })
		end
	end
	-- lieux utiles : les plus proches du joueur d'abord (la minicarte n'en pose que M.MINI_MAX au total)
	local Pl = SUI.Places
	if Pl and Pl.MiniWanted and Pl.MiniWanted() then
		local ps = Pl.Recs(c, z, "mini")
		local near = {}
		for s = 1, getn(ps) do
			local rec = ps[s]
			local g = Cx.PinHere(rec, c, z)
			local sz = g and M.YARDS[g.zid]
			for k = 1, g and getn(g.pins) or 0 do
				local d = g.pins[k]
				local dist = 0
				if sz and px and py then
					local dx, dy = (d.x - px) / 100 * sz[1], (d.y - py) / 100 * sz[2]
					dist = dx * dx + dy * dy
				end
				tinsert(near, { d = d, zid = g.zid, rec = rec, tracked = false, dist = dist })
			end
		end
		tsort(near, function(a, b) return a.dist < b.dist end)
		for k = 1, getn(near) do
			if getn(out) >= M.MINI_MAX then break end
			tinsert(out, near[k])
		end
	end
	M.miniList = out
	return out
end

-- Pose par image (OnUpdate de la minicarte) : seulement la position, calculee d'apres celle du joueur ; rien ne bouge quand le joueur est immobile.
function M.MiniMove()
	local n = M.mn
	if n == 0 then return end
	local mm, gp = glob("Minimap"), glob("GetPlayerMapPosition")
	if not mm or not gp then return end
	local px, py = gp("player")
	if not px or (px == 0 and py == 0) then return end
	local zoom = mm:GetZoom() or 0
	if px == M.lpx and py == M.lpy and zoom == M.lzoom then return end
	M.lpx, M.lpy, M.lzoom = px, py, zoom
	local diam = M.MINIZ[M.mindoor or 1][zoom] or 400
	local size = mm:GetWidth()
	local ppy = size / diam
	local half = size / 2 - 5
	local square, edge = M.msquare, M.medge
	local act = M.mact
	for i = 1, n do
		local e = act[i]
		local p = e.p
		local sx = (e.x - px * e.w) * ppy
		local sy = -(e.y - py * e.h) * ppy
		local far
		if square then
			far = (sx > half) or (sx < -half) or (sy > half) or (sy < -half)
		else
			far = (sx * sx + sy * sy) > half * half
		end
		local show = true
		if far then
			if e.tracked and edge then
				local k
				if square then
					local ax, ay = sx < 0 and -sx or sx, sy < 0 and -sy or sy
					k = half / (ax > ay and ax or ay)
				else
					k = half / math.sqrt(sx * sx + sy * sy)
				end
				sx, sy = sx * k, sy * k
				p:SetAlpha(0.55)
			else
				show = false
			end
		else
			p:SetAlpha(1)
		end
		if show then
			p:ClearAllPoints()
			p:SetPoint("CENTER", mm, "CENTER", sx, sy)
			p:Show()
		else
			p:Hide()
		end
	end
end

function M.EnsureMover()
	if M.mover then return M.mover end
	local mm = glob("Minimap")
	if not mm then return nil end
	local f = CreateFrame("Frame", nil, mm)
	f:SetScript("OnUpdate", function() M.MiniMove() end)
	M.mover = f
	return f
end

-- Tour lent (M.MINI_EVERY) : choisit les epingles et leur icone ; la position, elle, est posee a chaque image par M.MiniMove
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
	local list = M.MiniList(Cx, c, z, px * 100, py * 100)
	M.mindoor = M.Indoor(mm:GetZoom() or 0)
	M.msquare = C.Get("minimap.shape") == "square"
	M.medge = C.Get("questtrack.miniedge") and true or false
	if list ~= M.llist then
		M.llist = list
		local act, n = {}, 0
		for i = 1, getn(list) do
			local e = list[i]
			local sz = e.zid and M.YARDS[e.zid]
			if sz then
				local p = M.MiniFrame(n + 1)
				if not p then break end
				local vk = Cx.PinVisual(e.d)
				p.kind = vk
				Cx.PaintIcon(p, e.d, vk)
				local ent = Cx.PinEntries(e.rec, e.d)
				local mk = Cx.PinMark(vk, ent and getn(ent) or 0)
				if p.markText ~= mk then
					p.markText = mk
					p.mark:SetText(mk)
				end
				n = n + 1
				act[n] = { p = p, x = e.d.x / 100 * sz[1], y = e.d.y / 100 * sz[2], w = sz[1], h = sz[2], tracked = e.tracked }
			end
		end
		M.mact, M.mn = act, n
		for i = n + 1, getn(M.mpins) do M.mpins[i]:Hide() end
		M.lpx = nil
	end
	local mv = M.EnsureMover()
	if mv and not mv:IsShown() then mv:Show() end
end

-- Minuterie de la minicarte : seulement si l'option est active, le Codex aussi, et le module actif
function M.MiniSync()
	local Pl = SUI.Places
	local want = codex() ~= nil and ((M.on and (C.Get("questtrack.mini") or C.Get("questtrack.minigivers"))) or (Pl and Pl.MiniWanted and Pl.MiniWanted())) and true or false
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
	local want = M.on and Cx.on and (C.Get("questtrack.pins") or C.Get("questtrack.givers")) and true or false
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
		if Cx.pins[i].hl then
			Cx.pins[i].hl:SetWidth(s * 1.6)
			Cx.pins[i].hl:SetHeight(s * 1.6)
		end
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
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function() M.OnTitle(this, arg1) end)
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
	f.head = T.Text(f, 11, T.c.dim, "LEFT")
	f.head:SetPoint("TOPLEFT", f, "TOPLEFT", M.PAD, -M.PAD - 1)
	f.pick = T.Button(f, L("msg.questtrack.pick.btn"), 58, 15, function() M.PickToggle() end)
	f.pick:SetPoint("TOPRIGHT", f, "TOPRIGHT", -M.PAD, -M.PAD + 1)
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
	local total = getn(M.list)
	if total == 0 or not C.Get("questtrack.show") then
		f:Hide()
		return
	end
	local view = M.View(true)
	local n = getn(view)
	local max = C.Get("questtrack.max")
	if n > max then n = max end
	if n > M.MAXQ then n = M.MAXQ end
	local w = C.Get("questtrack.width")
	f:SetWidth(w)
	f.head:SetText(L("msg.questtrack.head", getn(M.View()), total))
	f.head:SetWidth(w - 2 * M.PAD - 62)
	T.SetButtonText(f.pick, L("msg.questtrack.pick.btn"))
	local y = M.PAD + 18
	for i = 1, n do
		local e = view[i]
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
	M.PickPaint()
	M.LogPaint()
	if codex() and not M.resTask and not M.listResolved(list) then M.resTask = SUI.After(2, M.ResolveAll, "questtrack.res") end
	local Cx = SUI.Codex
	if Cx and Cx.trackFn == M.Recs and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
end

function M.Queue()
	if not M.on or M.task then return end
	M.task = SUI.After(M.DELAY, M.Scan, "questtrack.scan")
end

-- ---------------------------------------------------------------- souris
-- Maj+clic : "[titre]" dans la ligne de saisie du chat ; Ctrl+clic : la quete s'ouvre dans le journal du jeu
function M.ChatLink(e)
	local eb = glob("ChatFrameEditBox")
	if eb and eb.IsVisible and eb:IsVisible() and eb.Insert then eb:Insert("[" .. e.title .. "]") end
end

function M.OpenLog(e)
	local sel = glob("SelectQuestLogEntry")
	if sel then pcall(sel, e.i) end
	local f = glob("QuestLogFrame")
	local show = glob("ShowUIPanel")
	if f and show then
		if f:IsVisible() then
			local upd = glob("QuestLog_Update")
			if upd then upd() end
		else
			show(f)
		end
	end
end

function M.OnTitle(b, button)
	local e = b.entry
	if not e then return end
	local shift, ctrl = glob("IsShiftKeyDown"), glob("IsControlKeyDown")
	if shift and shift() then
		M.ChatLink(e)
		return
	end
	if ctrl and ctrl() then
		M.OpenLog(e)
		return
	end
	if button == "RightButton" then
		M.SetShown(e, false)
		SUI.Print(L("msg.questtrack.hidden", M.Title(e)))
		return
	end
	M.PinEntry(e)
end

-- Epingle la quete seule sur la carte du monde
function M.PinEntry(e)
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
	GameTooltip:AddLine(L("msg.questtrack.tip.hide"), d[1], d[2], d[3])
	GameTooltip:AddLine(L("msg.questtrack.tip.log"), d[1], d[2], d[3])
	if C.Get("questtrack.drag") then GameTooltip:AddLine(L("msg.questtrack.tip.drag"), d[1], d[2], d[3]) end
	GameTooltip:Show()
end

-- ---------------------------------------------------------------- fleche de direction
-- Une petite fleche deplacable pointe vers l'objectif de quete le plus proche dans la zone ou tu te trouves (ou vers la quete epinglee, si elle a
-- un point ici) et indique la distance en yards. Angle = relevement de la cible sur la carte (nord en haut) + orientation du joueur
-- (GetPlayerFacing : radians, sens inverse des aiguilles depuis le nord). Zone sans objectif, carte du monde ouverte sur une autre zone, ou
-- instance (position 0, 0) : la fleche se cache. Une image sur deux : seulement l'angle ; la cible est rechoisie chaque seconde.
M.ARROW_TEX = "Interface\\AddOns\\ShikiUI\\Media\\arrow.tga"
M.ARROW_PICK = 1             -- secondes entre deux choix de cible
M.ARROW_EVERY = 0.05         -- secondes entre deux mises a jour de l'angle
M.ARROW_NEAR = 20            -- yards : "arrive"
M.ARROW_SIZE = 44

-- atan2 (math.atan2 en Lua 5.0 du client ; math.atan a deux arguments ailleurs)
function M.Atan2(y, x)
	if math.atan2 then return math.atan2(y, x) end
	return math.atan(y, x)
end

-- Coordonnees de texture du coin (x, y) (droite, haut ; centre = 0) apres une rotation de a radians dans le sens inverse des aiguilles
local function arrowUV(x, y, c, s)
	return 0.5 + (x * c + y * s), 0.5 - (y * c - x * s)
end

function M.ArrowSetAngle(tex, a)
	local c, s = math.cos(a), math.sin(a)
	local ulx, uly = arrowUV(-0.5, 0.5, c, s)
	local llx, lly = arrowUV(-0.5, -0.5, c, s)
	local urx, ury = arrowUV(0.5, 0.5, c, s)
	local lrx, lry = arrowUV(0.5, -0.5, c, s)
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- Cible : { x, y (0..1 sur la carte de la zone), w, h (yards), title } ou nil
function M.ArrowPick()
	local Cx = codex()
	local gp = glob("GetPlayerMapPosition")
	if not Cx or not gp then return nil end
	local px, py = gp("player")
	local c, z = Cx.MapCur()
	if not px or (px == 0 and py == 0) or not c or not z or z <= 0 then return nil end
	if M.atest and GetTime() < M.atest.till then return M.atest end
	-- priorite : quete choisie pour la fleche (si elle a un point ici) > quete epinglee > objectif le plus proche des quetes affichees
	local srcs = nil
	local aq = C.Get("questtrack.arrowq")
	if type(aq) == "string" and aq ~= "" then
		for i = 1, getn(M.list) do
			if M.Key(M.list[i]) == aq then
				local r = M.EntryRec(Cx, M.list[i])
				if r and Cx.PinHere(r, c, z) then srcs = { r } end
				break
			end
		end
	end
	if not srcs then
		srcs = M.Recs(c, z, "arrow")
		local pinned = Cx.pin
		if pinned and type(pinned.zones) == "table" and Cx.PinHere(pinned, c, z) then
			srcs = { pinned }
		end
	end
	local best, bd = nil, nil
	for s = 1, getn(srcs) do
		local rec = srcs[s]
		local g = Cx.PinHere(rec, c, z)
		local sz = g and (M.YARDS[g.zid] or { 4000, 2667 })
		for k = 1, g and getn(g.pins) or 0 do
			local d = g.pins[k]
			local dx, dy = (d.x / 100 - px) * sz[1], (d.y / 100 - py) * sz[2]
			local d2 = dx * dx + dy * dy
			if not bd or d2 < bd then
				bd = d2
				best = { x = d.x / 100, y = d.y / 100, w = sz[1], h = sz[2], title = rec.t }
			end
		end
	end
	return best
end

-- Image : angle et distance
function M.ArrowUpdate()
	local f = M.arrow
	if not f then return end
	local now = GetTime()
	if now >= (M.apick or 0) then
		M.apick = now + M.ARROW_PICK
		M.atgt = M.ArrowPick()
	end
	local t = M.atgt
	local gp, gf = glob("GetPlayerMapPosition"), glob("GetPlayerFacing")
	local px, py, face
	if t and gp and gf then
		px, py = gp("player")
		face = gf()
	end
	if not t or not px or (px == 0 and py == 0) or type(face) ~= "number" then
		f.tex:Hide()
		f.txt:SetText("")
		f.sub:SetText("")
		return
	end
	local dx, dy = (t.x - px) * t.w, (t.y - py) * t.h
	local dist = math.sqrt(dx * dx + dy * dy)
	local near = dist < M.ARROW_NEAR
	M.ArrowSetAngle(f.tex, -(M.Atan2(dx, -dy) + face))
	local col = near and T.c.good or { T.Accent() }
	f.tex:SetVertexColor(col[1], col[2], col[3], 1)
	f.tex:Show()
	f.txt:SetText(near and L("msg.questtrack.arrow.here") or L("msg.questtrack.arrow.dist", floor(dist + 0.5)))
	if f.subFor ~= t.title then
		f.subFor = t.title
		f.sub:SetText(t.title or "")
	end
end

function M.ArrowBuild()
	if M.arrow then return M.arrow end
	local f = CreateFrame("Frame", "ShikiUI_QuestArrow", UIParent)
	f:SetWidth(M.ARROW_SIZE + 60)
	f:SetHeight(M.ARROW_SIZE + 30)
	f:SetFrameStrata("MEDIUM")
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetTexture(M.ARROW_TEX)
	f.tex:SetWidth(M.ARROW_SIZE)
	f.tex:SetHeight(M.ARROW_SIZE)
	f.tex:SetPoint("TOP", f, "TOP", 0, 0)
	f.txt = T.Text(f, 12, T.c.text, "CENTER", true)
	f.txt:SetPoint("TOP", f.tex, "BOTTOM", 0, -2)
	f.sub = T.Text(f, 10, T.c.text, "CENTER", true)
	f.sub:SetPoint("TOP", f.txt, "BOTTOM", 0, -1)
	f.sub:SetWidth(M.ARROW_SIZE + 56)
	f.sub:SetHeight(12)
	f.elapsed = 0
	f:SetScript("OnUpdate", function()
		this.elapsed = this.elapsed + arg1
		if this.elapsed < M.ARROW_EVERY then return end
		this.elapsed = 0
		M.ArrowUpdate()
	end)
	SUI.Mover.Register("questtrack.arrow", f, { label = "mod.questtrack.arrow.mover", point = "TOP", x = 0, y = -150 })
	M.arrow = f
	return f
end

-- Montre / cache la fleche selon l'option, le module et le Codex (sans lui, pas de coordonnees de quetes)
function M.ArrowSync()
	local want = M.on and C.Get("questtrack.arrow") and codex() ~= nil and true or false
	if want then
		local f = M.ArrowBuild()
		f:Show()
	elseif M.arrow then
		M.arrow:Hide()
		M.atgt, M.apick = nil, nil
	end
end

-- ---------------------------------------------------------------- fenetre de choix des quetes
-- Une ligne par quete du journal : case (affichee dans la liste), titre (clic = coche / decoche), ">" = la fleche vise cette quete.
M.PICKMAX = 25
M.PICKROW = 19

-- La fleche vise cette quete (ou revient a "la plus proche" si c'etait deja elle)
function M.SetArrowTarget(e)
	local k = M.Key(e)
	if C.Get("questtrack.arrowq") == k then
		C.Set("questtrack.arrowq", "")
		return
	end
	C.Set("questtrack.arrowq", k)
	if not C.Get("questtrack.arrow") then C.Set("questtrack.arrow", true) end
end

local function pickRow(f, i)
	local r = {}
	r.chk = T.Check(f, function(on)
		if r.e then M.SetShown(r.e, on) end
	end)
	r.txt = CreateFrame("Button", nil, f)
	r.txt:SetWidth(236)
	r.txt:SetHeight(16)
	r.fs = T.Text(r.txt, 11, T.c.warn, "LEFT")
	r.fs:SetPoint("LEFT", r.txt, "LEFT", 0, 0)
	r.fs:SetWidth(236)
	r.txt:SetScript("OnClick", function()
		if r.e then M.SetShown(r.e, not M.IsShown(r.e)) end
	end)
	r.arr = T.Button(f, ">", 22, 16, function()
		if r.e then M.SetArrowTarget(r.e) end
	end)
	local y = 28 + (i - 1) * M.PICKROW
	r.chk:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -y)
	r.txt:SetPoint("LEFT", r.chk, "RIGHT", 6, 0)
	r.arr:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -y)
	f.rows[i] = r
	return r
end

function M.PickBuild()
	if M.pick then return M.pick end
	local f = CreateFrame("Frame", "ShikiUI_QuestPick", UIParent)
	f:SetWidth(310)
	f:SetHeight(120)
	f:SetFrameStrata("DIALOG")
	T.Backdrop(f, T.c.bg, T.c.border)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() this:StartMoving() end)
	f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	f:Hide()
	f.rows = {}
	f.title = T.Text(f, 12, T.c.text, "LEFT", true)
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
	f.empty = T.Text(f, 11, T.c.dim, "LEFT")
	f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
	f.hint = T.Text(f, 10, T.c.dim, "LEFT")
	f.hint:SetWidth(290)
	f.hint:SetHeight(26)
	f.bAll = T.Button(f, "", 66, 18, function() M.SetAllShown(true) end)
	f.bAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f.bNone = T.Button(f, "", 66, 18, function() M.SetAllShown(false) end)
	f.bNone:SetPoint("LEFT", f.bAll, "RIGHT", 6, 0)
	f.bClose = T.Button(f, "", 66, 18, function() f:Hide() end)
	f.bClose:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
	f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 30)
	if UISpecialFrames then tinsert(UISpecialFrames, "ShikiUI_QuestPick") end
	M.pick = f
	return f
end

function M.PickPaint()
	local f = M.pick
	if not f or not f:IsShown() then return end
	local aq = C.Get("questtrack.arrowq")
	local n = getn(M.list)
	if n > M.PICKMAX then n = M.PICKMAX end
	f.title:SetText(L("msg.questtrack.pick.title"))
	f.hint:SetText(L("msg.questtrack.pick.hint"))
	T.SetButtonText(f.bAll, L("msg.questtrack.pick.all"))
	T.SetButtonText(f.bNone, L("msg.questtrack.pick.none"))
	T.SetButtonText(f.bClose, L("msg.questtrack.pick.close"))
	f.empty:SetText(n == 0 and L("msg.questtrack.pick.empty") or "")
	for i = 1, n do
		local e = M.list[i]
		local r = f.rows[i] or pickRow(f, i)
		r.e = e
		T.SetCheck(r.chk, M.IsShown(e))
		local col = e.complete and T.c.good or T.c.warn
		r.fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
		r.fs:SetText((e.level > 0 and ("[" .. e.level .. "] ") or "") .. M.Title(e))
		T.SetSelected(r.arr, aq == M.Key(e))
		r.chk:Show()
		r.txt:Show()
		r.arr:Show()
	end
	for i = n + 1, getn(f.rows) do
		local r = f.rows[i]
		r.e = nil
		r.chk:Hide()
		r.txt:Hide()
		r.arr:Hide()
	end
	f:SetHeight(92 + (n > 0 and n or 1) * M.PICKROW)
end

function M.PickToggle()
	if not M.on then return end
	local f = M.PickBuild()
	if f:IsShown() then
		f:Hide()
		return
	end
	if not f.placed then
		f.placed = true
		f:ClearAllPoints()
		if M.frame and M.frame:IsShown() then
			f:SetPoint("TOPRIGHT", M.frame, "TOPLEFT", -8, 0)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
	end
	f:Show()
	M.PickPaint()
end

-- ---------------------------------------------------------------- panneau dans le journal de quetes du jeu
-- Un petit panneau colle a droite de la fenetre du journal : quete selectionnee, dans la liste ou non, epingle, fleche, choix des quetes.
-- QuestLog_Update est enveloppee a la main (pas de hooksecurefunc en 1.12) pour suivre la selection.
function M.LogEntry()
	local gs, gt = glob("GetQuestLogSelection"), glob("GetQuestLogTitle")
	if not gs or not gt then return nil end
	local ok, sel = pcall(gs)
	if not ok or type(sel) ~= "number" or sel < 1 then return nil end
	for i = 1, getn(M.list) do
		local e = M.list[i]
		if e.i == sel then
			local ok2, t = pcall(gt, sel)
			if ok2 and t == e.title then return e end
			return nil
		end
	end
	return nil
end

local function logButton(f, y, fn)
	local b = T.Button(f, "", 170, 20, fn)
	b:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -y)
	return b
end

function M.LogBuild()
	if M.logp then return M.logp end
	local qf = glob("QuestLogFrame")
	if not qf then return nil end
	local f = CreateFrame("Frame", "ShikiUI_QuestLogPanel", qf)
	f:SetWidth(190)
	f:SetHeight(214)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:SetPoint("TOPLEFT", qf, "TOPRIGHT", M.LOGX, -12)
	f:EnableMouse(true)
	f.head = T.Text(f, 10, T.c.dim, "LEFT")
	f.head:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	f.title = T.Text(f, 12, T.c.text, "LEFT", true)
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -22)
	f.title:SetWidth(170)
	f.title:SetHeight(30)
	f.state = T.Text(f, 11, T.c.dim, "LEFT")
	f.state:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -56)
	f.state:SetWidth(170)
	f.codex = T.Text(f, 10, T.c.dim, "LEFT")
	f.codex:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -72)
	f.codex:SetWidth(170)
	f.bTrack = logButton(f, 92, function()
		if f.cur then M.SetShown(f.cur, not M.IsShown(f.cur)) end
	end)
	f.bPin = logButton(f, 116, function()
		if f.cur then M.PinEntry(f.cur) end
	end)
	f.bArrow = logButton(f, 140, function()
		if f.cur then M.SetArrowTarget(f.cur) end
	end)
	f.bPick = logButton(f, 164, function() M.PickToggle() end)
	f.count = T.Text(f, 10, T.c.dim, "LEFT")
	f.count:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f:SetScript("OnShow", function() M.LogPaint() end)
	M.logp = f
	return f
end
M.LOGX = -84

function M.LogPaint()
	local f = M.logp
	if not f then return end
	local e = M.LogEntry()
	f.cur = e
	f.head:SetText(L("msg.questtrack.log.head"))
	f.count:SetText(L("msg.questtrack.log.count", M.NumShown(), getn(M.list)))
	T.SetButtonText(f.bPick, L("msg.questtrack.log.pick"))
	if not e then
		f.title:SetText(L("msg.questtrack.log.none"))
		f.state:SetText("")
		f.codex:SetText("")
		f.bTrack:Hide()
		f.bPin:Hide()
		f.bArrow:Hide()
		return
	end
	f.bTrack:Show()
	f.bPin:Show()
	f.bArrow:Show()
	f.title:SetText(M.Title(e))
	local on = M.IsShown(e)
	local col = on and T.c.good or T.c.dim
	f.state:SetTextColor(col[1], col[2], col[3], col[4] or 1)
	f.state:SetText(L(on and "msg.questtrack.log.on" or "msg.questtrack.log.off"))
	T.SetButtonText(f.bTrack, L(on and "msg.questtrack.log.untrack" or "msg.questtrack.log.track"))
	T.SetButtonText(f.bPin, L("msg.questtrack.log.pin"))
	local arrowOn = C.Get("questtrack.arrowq") == M.Key(e)
	T.SetButtonText(f.bArrow, L(arrowOn and "msg.questtrack.log.arrowoff" or "msg.questtrack.log.arrow"))
	local txt
	if not codex() then
		txt = L("msg.questtrack.log.nocodex")
	elseif type(e.id) == "number" then
		txt = L("msg.questtrack.log.id", e.id)
	elseif e.id == false then
		txt = L("msg.questtrack.log.unknown")
	else
		txt = ""
	end
	f.codex:SetText(txt)
end

function M.LogHook()
	if M.logHooked then return end
	local orig = glob("QuestLog_Update")
	if type(orig) ~= "function" then return end
	M.logHooked = true
	local function wrapped(a, b)
		orig(a, b)
		if M.on and M.logp then pcall(M.LogPaint) end
	end
	setglobal("QuestLog_Update", wrapped)
end

function M.LogSync()
	local want = M.on and C.Get("questtrack.logpanel") and glob("QuestLogFrame") ~= nil
	if want then
		local f = M.LogBuild()
		if f then
			f:Show()
			M.LogHook()
			M.LogPaint()
		end
	elseif M.logp then
		M.logp:Hide()
	end
end

-- Changement de zone : la liste "zone actuelle seulement" se recompose
function M.OnZone()
	if M.on and M.frame and C.Get("questtrack.zoneonly") then M.Paint() end
end

-- ---------------------------------------------------------------- cycle de vie, commande
-- Bouton "Quetes" autour de la minicarte (glissable) : affiche / masque le suivi de quetes
function M.RingButton()
	local want = M.on and C.Get("questtrack.btn") and true or false
	local b = M.rbtn
	if not b and want then
		local mm = getglobal("Minimap")
		if not mm or SUI.InCombat() then return end
		b = T.Button(mm, L("msg.questtrack.btn"), 50, 22, function() C.Set("questtrack.show", not C.Get("questtrack.show")) end)
		b.suiOwn = true
		b:SetFrameStrata("HIGH")
		b:SetFrameLevel((mm:GetFrameLevel() or 0) + 12)
		b:SetScript("OnEnter", M.RingEnter)
		b:SetScript("OnLeave", M.RingLeave)
		SUI.MiniRing.Drag(b, "questtrack.angle", 270)
		M.rbtn = b
	end
	if b then
		if want then
			if not b.ringDrag then SUI.MiniRing.Place(b, "questtrack.angle", 270) end
			b:Show()
		else
			b:Hide()
		end
	end
end

function M.RingEnter()
	local r, g, bl = T.Accent()
	this:SetBackdropBorderColor(r, g, bl, 1)
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:AddLine(L("cat.questtrack"))
	GameTooltip:AddLine(L("msg.questtrack.btn.tip"), T.c.dim[1], T.c.dim[2], T.c.dim[3])
	GameTooltip:Show()
end

function M.RingLeave()
	this:SetBackdropBorderColor(T.c.border[1], T.c.border[2], T.c.border[3], 1)
	GameTooltip:Hide()
end

function M.OnKey(key, value)
	if key == "questtrack.btn" or key == "questtrack.angle" then M.RingButton() end
	if key == "questtrack.arrow" then M.ArrowSync() end
	if not M.on then return end
	M.Sync()
	if M.frame then M.Paint() end
	if key == "questtrack.logpanel" then M.LogSync() end
	if key == "questtrack.arrowq" then M.apick = 0 end
	if key == "questtrack.hide" or key == "questtrack.arrowq" then
		M.PickPaint()
		M.LogPaint()
	end
	if key == "questtrack.pins" or key == "questtrack.givers" or key == "questtrack.giverlow" or key == "questtrack.hide" then
		local Cx = SUI.Codex
		if Cx and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
	end
end

function M.Enable()
	M.on = true
	SUI.On("QUEST_LOG_UPDATE", M.Queue)
	SUI.On("PLAYER_ENTERING_WORLD", M.Queue)
	SUI.On("ZONE_CHANGED_NEW_AREA", M.OnZone)
	if not M.watching then
		M.watching = true
		C.Watch("questtrack.", M.OnKey)
	end
	M.Sync()
	M.Queue()
	M.RingButton()
	M.ArrowSync()
	M.LogSync()
end

function M.Disable()
	M.on = false
	M.ArrowSync()
	M.RingButton()
	M.LogSync()
	if M.pick then M.pick:Hide() end
	SUI.Off("QUEST_LOG_UPDATE", M.Queue)
	SUI.Off("PLAYER_ENTERING_WORLD", M.Queue)
	SUI.Off("ZONE_CHANGED_NEW_AREA", M.OnZone)
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

-- /sui quests arrow : cible d'essai pendant 30 s (a 100 yards au nord-est de toi), pour voir la fleche sans quete dans la zone
function M.ArrowTest()
	local gp = glob("GetPlayerMapPosition")
	local px, py = 0, 0
	if gp then px, py = gp("player") end
	if not px or (px == 0 and py == 0) then
		SUI.Print(L("msg.questtrack.arrow.nopos"))
		return
	end
	M.atest = { x = px + 100 / 4000, y = py - 100 / 2667, w = 4000, h = 2667, title = L("msg.questtrack.arrow.test"), till = GetTime() + 30 }
	M.apick = 0
	M.ArrowSync()
end

function M.Command(rest)
	local arg = slower(rest or "")
	if arg == "arrow" then
		M.ArrowTest()
		return
	end
	if arg == "pick" then
		M.PickToggle()
		return
	end
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
		opt("minigivers", "bool", 22.5, true, { simple = true }),
		opt("miniedge", "bool", 23, true),
		opt("btn", "bool", 21, true),
		opt("arrow", "bool", 21.2, true, { simple = true }),
		opt("logpanel", "bool", 11, true, { simple = true }),
		opt("zoneonly", "bool", 11.5, false),
		opt("angle", "number", 21.5, 270, { min = 0, max = 355, step = 5 }),
		opt("pinsize", "number", 24, 16, { min = 12, max = 32, step = 1 }),
		opt("giverlow", "number", 26, 6, { min = 0, max = 20, step = 1 }),
		opt("max", "number", 30, 8, { min = 3, max = 15, step = 1 }),
		opt("width", "number", 40, 230, { min = 160, max = 400, step = 10 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("quests", function(rest) M.Command(rest or "") end, "help.questtrack")
