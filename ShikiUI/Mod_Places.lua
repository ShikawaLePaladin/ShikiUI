-- ShikiUI Places : lieux utiles sur la carte du monde et la minicarte (module "places", avec le module Codex). Services (reparateur, hotel des ventes, banque,
-- boite aux lettres, marchand, ecurie), deplacements (maitre de vol, aubergiste, maitre de bataille, pierre de rencontre, guerisseur d'esprit), entraineurs
-- (ta classe, tes metiers) et ressources (herbes, minerais, poissons, coffres). Donnees : ShikiCodexData_Places (LoadOnDemand, charge a la premiere pose ;
-- tools/build_places.js depuis pfQuest). Les lieux d'une meme famille proches l'un de l'autre sont regroupes (un clic : la liste). Un fournisseur du Codex
-- (Cx.PinTrack(fn, "places")) : memes epingles, meme fenetre de clic, meme minicarte que les quetes ; aucune minuterie propre.
-- NON VERIFIE EN JEU : GetSkillLineInfo (metiers sous un titre replie : invisibles pour l'API, donc ressources / entraineurs montres si aucun metier n'est lu).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tsort = table.getn, table.insert, table.sort
local slower, sfind, sformat = string.lower, string.find, string.format
local floor = math.floor

local M = {}
SUI.Places = M

M.on = false
M.ADDON = "ShikiCodexData_Places"
M.CELL = 2.5                 -- cote (en % de la carte) d'une cellule de regroupement
M.TIPMAX = 8                 -- lignes de l'infobulle d'une epingle
M.ENTMAX = 40                -- entrees gardees par epingle (la fenetre de clic en montre 8)

-- famille, marque (une lettre ASCII), groupe de couleur, active par defaut
M.KINDS = {
	{ "repair", "R", "svc", true },
	{ "auctioneer", "A", "svc", true },
	{ "banker", "B", "svc", true },
	{ "mailbox", "M", "svc", true },
	{ "vendor", "V", "svc", false },
	{ "stablemaster", "S", "svc", false },
	{ "flight", "F", "trv", true },
	{ "innkeeper", "I", "trv", true },
	{ "battlemaster", "W", "trv", false },
	{ "meetingstone", "P", "trv", false },
	{ "spirithealer", "+", "trv", false },
	{ "trainer", "T", "trn", true },
	{ "herbs", "h", "res", true },
	{ "mines", "m", "res", true },
	{ "fish", "f", "res", false },
	{ "chests", "c", "res", false },
}
M.KIND = {}
for i = 1, getn(M.KINDS) do M.KIND[M.KINDS[i][1]] = M.KINDS[i] end

-- metiers : numero de categorie des entraineurs (101...), motifs (Lua) du nom du metier, anglais et francais sans accents (un point = un octet d'accent)
M.PROF = {
	{ 101, { "alchem", "alchimie" } },
	{ 102, { "blacksmith", "forge" } },
	{ 103, { "cooking", "cuisine" } },
	{ 104, { "enchant" } },
	{ 105, { "engineer", "ing..nierie" } },
	{ 106, { "first aid", "secourisme" } },
	{ 107, { "fishing", "p..che" } },
	{ 108, { "herbal", "herbor" } },
	{ 109, { "jewelcraft", "joaill" } },
	{ 110, { "leatherwork", "cuir" } },
	{ 111, { "mining", "minage" } },
	{ 112, { "skinning", "d..pe" } },
	{ 113, { "tailor", "couture" } },
	{ 114, { "survival", "survie" } },
}
M.CLASSID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }

local function glob(name)
	return getglobal(name)
end

local function codex()
	local Cx = SUI.Codex
	if Cx and Cx.on and Cx.P and Cx.PinTrack then return Cx end
	return nil
end

local function lang()
	if SUI.locale then return SUI.locale == "fr" and "fr" or "en" end
	return "en"
end

-- ---------------------------------------------------------------- le joueur : faction, classe, metiers
function M.Me()
	if M.me then return M.me end
	local me = { fbit = nil, cls = nil, prof = {}, nprof = 0 }
	local fg = glob("UnitFactionGroup")
	if fg then
		local ok, f = pcall(fg, "player")
		if ok and f == "Alliance" then me.fbit = 1 elseif ok and f == "Horde" then me.fbit = 2 end
	end
	local uc = glob("UnitClass")
	if uc then
		local ok, _, tok = pcall(uc, "player")
		if ok and type(tok) == "string" then me.cls = M.CLASSID[tok] end
	end
	local gn, gi = glob("GetNumSkillLines"), glob("GetSkillLineInfo")
	if gn and gi then
		local ok, n = pcall(gn)
		if ok and type(n) == "number" then
			for i = 1, n do
				local ok2, name, header = pcall(gi, i)
				if ok2 and type(name) == "string" and not header then
					local low = slower(name)
					for k = 1, getn(M.PROF) do
						local pats = M.PROF[k][2]
						for j = 1, getn(pats) do
							if sfind(low, pats[j]) and not me.prof[M.PROF[k][1]] then
								me.prof[M.PROF[k][1]] = true
								me.nprof = me.nprof + 1
							end
						end
					end
				end
			end
		end
	end
	local key = tostring(me.fbit) .. "|" .. tostring(me.cls)
	for k = 1, getn(M.PROF) do
		if me.prof[M.PROF[k][1]] then key = key .. "," .. M.PROF[k][1] end
	end
	me.key = key
	M.me = me
	return me
end

function M.OnSkills()
	M.me = nil
	M.Refresh()
end

-- ---------------------------------------------------------------- donnees
function M.Load()
	local pl = glob("ShikiCodexPlaces")
	if type(pl) ~= "table" then
		local la = glob("LoadAddOn")
		if la then pcall(la, M.ADDON) end
		pl = glob("ShikiCodexPlaces")
	end
	if type(pl) ~= "table" or type(pl.z) ~= "table" then
		if not M.warned then
			M.warned = true
			SUI.Print(L("msg.places.missing"))
		end
		return nil
	end
	return pl
end

function M.Name(pl, id)
	local t = lang() == "fr" and pl.fr and pl.fr[id] or nil
	return t or (pl.en and pl.en[id]) or ("#" .. tostring(id))
end

-- Enregistrement { zones = { g } } d'une zone de donnees (nil si les noms de zones des quetes ne sont pas chargeables)
function M.ZRec(Cx, zid)
	M.zrec = M.zrec or {}
	local r = M.zrec[zid]
	if r ~= nil then return r end
	local P = Cx.P
	local en, fr
	if P.LoadQuests() then en, fr = P.ZoneBoth(zid) end
	if en then
		r = { id = -2, t = L("msg.places.title"), cap = Cx.PIN_POOL, n = 0, zones = { { en = en, fr = fr, map = P.ZoneMap(zid), zid = zid, n = 0, pins = {} } } }
	else
		r = false
	end
	M.zrec[zid] = r
	return r
end

-- Zone de donnees affichee par la carte (c, z), ou nil
function M.ZoneOf(Cx, pl, c, z)
	M.zcur = M.zcur or {}
	local key = c .. "." .. z
	local v = M.zcur[key]
	if v ~= nil then return v or nil end
	for zid in pairs(pl.z) do
		local r = M.ZRec(Cx, zid)
		if r and Cx.PinHere(r, c, z) then
			M.zcur[key] = zid
			return zid
		end
	end
	M.zcur[key] = false
	return nil
end

-- ---------------------------------------------------------------- filtres
function M.KindOn(key)
	return C.Get("places." .. key) and true or false
end

-- Un lieu (famille, faction, categorie) est-il a montrer pour ce joueur ?
function M.Wanted(key, fac, tag, me)
	if C.Get("places.faction") and me.fbit and fac ~= 3 and fac ~= me.fbit then return false end
	local mine = C.Get("places.mine")
	if key == "trainer" then
		if tag == 20 or tag == 21 or tag == 22 then return C.Get("places.mounts") and true or false end
		if not mine then return true end
		if tag == 99 then return false end
		if tag > 100 then return me.nprof == 0 or me.prof[tag] == true end
		return me.cls == nil or tag == me.cls
	end
	if mine and me.nprof > 0 then
		if key == "herbs" then return me.prof[108] == true end
		if key == "mines" then return me.prof[111] == true end
		if key == "fish" then return me.prof[107] == true end
	end
	return true
end

-- ---------------------------------------------------------------- regroupement
local function optSig()
	local s = lang()
	for i = 1, getn(M.KINDS) do
		s = s .. (M.KindOn(M.KINDS[i][1]) and "1" or "0")
	end
	return s .. (C.Get("places.faction") and "1" or "0") .. (C.Get("places.mine") and "1" or "0") .. (C.Get("places.mounts") and "1" or "0")
end

local function entryList(pins)
	for i = 1, getn(pins) do
		local pin = pins[i]
		pin.x, pin.y = pin.sx / pin.n, pin.sy / pin.n
		local list = pin.ents
		tsort(list, function(a, b)
			if a.title ~= b.title then return a.title < b.title end
			return a.id < b.id
		end)
		local q, lines = {}, {}
		for k = 1, getn(list) do
			local e = list[k]
			local title = e.title
			if e.cnt > 1 then title = title .. " x" .. e.cnt end
			if k <= M.ENTMAX then tinsert(q, { place = true, title = title, sub = e.sub }) end
			if k <= M.TIPMAX then
				tinsert(lines, title .. (e.sub and (" - " .. e.sub) or ""))
			elseif k == M.TIPMAX + 1 then
				tinsert(lines, L("msg.places.more", getn(list) - M.TIPMAX))
			end
		end
		pin.q, pin.lines = q, lines
		pin.title = L("msg.places.k." .. pin.kind)
		pin.head = pin.title .. " (" .. getn(list) .. ")"
		pin.sx, pin.sy, pin.ents, pin.n, pin.by = nil, nil, nil, nil, nil
	end
end

-- Epingles (regroupees) de la zone de donnees zid pour ce joueur
function M.BuildPins(pl, zid, me)
	local zd = pl.z[zid]
	local pins, cells = {}, {}
	if not zd then return pins end
	for ki = 1, getn(M.KINDS) do
		local key = M.KINDS[ki][1]
		local arr = zd[key]
		if arr and M.KindOn(key) then
			local vk = "P" .. key
			for i = 1, getn(arr), 4 do
				local packed, id, fac, tag = arr[i], arr[i + 1], arr[i + 2], arr[i + 3]
				if M.Wanted(key, fac, tag, me) then
					local xi = floor(packed / 1024)
					local x, y = xi / 10, (packed - xi * 1024) / 10
					local ck = key .. ":" .. floor(x / M.CELL) * 1000 + floor(y / M.CELL)
					local pin = cells[ck]
					if not pin then
						pin = { k = "P", vk = vk, kind = key, x = x, y = y, sx = 0, sy = 0, n = 0, ents = {}, by = {} }
						cells[ck] = pin
						tinsert(pins, pin)
					end
					pin.sx, pin.sy, pin.n = pin.sx + x, pin.sy + y, pin.n + 1
					local e = pin.by[id]
					if e then
						e.cnt = e.cnt + 1
					else
						local sub
						if key == "trainer" then
							sub = L("msg.places.t." .. tag)
						elseif tag and tag > 0 and (key == "herbs" or key == "mines") then
							sub = L("msg.places.skill", tag)
						end
						e = { id = id, title = M.Name(pl, id), sub = sub, cnt = 1 }
						pin.by[id] = e
						tinsert(pin.ents, e)
					end
				end
			end
		end
	end
	entryList(pins)
	return pins
end

-- Fournisseur du Codex : enregistrements de la zone affichee (c, z) ; ctx "mini" : minicarte (option propre)
function M.Recs(c, z, ctx)
	local Cx = codex()
	if not Cx or not M.on or not C.Get("places.show") or not c or not z or z <= 0 then return {} end
	if ctx == "mini" and not C.Get("places.mini") then return {} end
	local pl = M.Load()
	if not pl then return {} end
	local zid = M.ZoneOf(Cx, pl, c, z)
	if not zid then return {} end
	local rec = M.ZRec(Cx, zid)
	if not rec then return {} end
	local me = M.Me()
	local sig = optSig() .. "|" .. me.key
	M.zsig = M.zsig or {}
	if M.zsig[zid] ~= sig then
		M.zsig[zid] = sig
		local g = rec.zones[1]
		g.pins = M.BuildPins(pl, zid, me)
		g.n = getn(g.pins)
		rec.n = g.n
	end
	local out = {}
	if rec.zones[1].n > 0 then tinsert(out, rec) end
	local f = M.focus
	if f and f.zid == zid then
		if not M.focusRec then
			M.focusRec = { id = -3, t = L("msg.places.title"), cap = 1, n = 1, zones = { { en = rec.zones[1].en, fr = rec.zones[1].fr, map = rec.zones[1].map, zid = zid, n = 1,
				pins = { { k = "P", vk = "P" .. f.kind, kind = f.kind, x = f.x, y = f.y, title = L("msg.places.nearest", f.name), head = f.name,
					lines = { f.name }, q = { { place = true, title = f.name } } } } } } }
		end
		tinsert(out, M.focusRec)
	end
	return out
end

-- ---------------------------------------------------------------- le plus proche
M.ALIASES = {
	repair = "repair", reparateur = "repair", repar = "repair",
	auctioneer = "auctioneer", ah = "auctioneer", hdv = "auctioneer", hotel = "auctioneer",
	banker = "banker", bank = "banker", banque = "banker",
	mailbox = "mailbox", mail = "mailbox", courrier = "mailbox", boite = "mailbox",
	vendor = "vendor", marchand = "vendor",
	stablemaster = "stablemaster", stable = "stablemaster", ecurie = "stablemaster",
	flight = "flight", vol = "flight", gryphon = "flight",
	innkeeper = "innkeeper", inn = "innkeeper", auberge = "innkeeper",
	battlemaster = "battlemaster", bg = "battlemaster",
	meetingstone = "meetingstone", pierre = "meetingstone",
	spirithealer = "spirithealer", esprit = "spirithealer",
	trainer = "trainer", entraineur = "trainer",
	herbs = "herbs", herbes = "herbs", herbo = "herbs",
	mines = "mines", mine = "mines", minerai = "mines", minerais = "mines",
	fish = "fish", peche = "fish",
	chests = "chests", coffres = "chests",
}

function M.Nearest(word)
	local key = M.ALIASES[slower(word or "")]
	if not key then
		SUI.Print(L("msg.places.nokind"))
		return
	end
	local Cx = codex()
	if not Cx or not M.on then
		SUI.Print(L("msg.places.off"))
		return
	end
	local pl = M.Load()
	local gp = glob("GetPlayerMapPosition")
	if not pl or not gp then return end
	local c, z = Cx.MapCur()
	local px, py = gp("player")
	if not c or not z or z <= 0 or not px or (px == 0 and py == 0) then
		SUI.Print(L("msg.places.nopos"))
		return
	end
	local zid = M.ZoneOf(Cx, pl, c, z)
	local zd = zid and pl.z[zid]
	local arr = zd and zd[key]
	if not arr then
		SUI.Print(L("msg.places.nonear", L("msg.places.k." .. key)))
		return
	end
	local me = M.Me()
	local sz = SUI.QuestTrack and SUI.QuestTrack.YARDS and SUI.QuestTrack.YARDS[zid] or { 1000, 1000 }
	px, py = px * 100, py * 100
	local best, bd, bx, by
	for i = 1, getn(arr), 4 do
		if M.Wanted(key, arr[i + 2], arr[i + 3], me) then
			local xi = floor(arr[i] / 1024)
			local x, y = xi / 10, (arr[i] - xi * 1024) / 10
			local dx, dy = (x - px) / 100 * sz[1], (y - py) / 100 * sz[2]
			local d = dx * dx + dy * dy
			if not bd or d < bd then best, bd, bx, by = arr[i + 1], d, x, y end
		end
	end
	if not best then
		SUI.Print(L("msg.places.nonear", L("msg.places.k." .. key)))
		return
	end
	M.focus = { zid = zid, kind = key, x = bx, y = by, name = M.Name(pl, best) }
	M.focusRec = nil
	SUI.Print(sformat(L("msg.places.near"), L("msg.places.k." .. key), M.focus.name, floor(bx) .. ", " .. floor(by), floor(math.sqrt(bd) + 0.5)))
	Cx.PinOnMapEvent()
	if SUI.QuestTrack and SUI.QuestTrack.MiniSync then SUI.QuestTrack.MiniSync() end
end

-- ---------------------------------------------------------------- branchement
function M.MiniWanted()
	return M.on and C.Get("places.show") and C.Get("places.mini") and true or false
end

function M.Refresh()
	M.zsig = nil
	M.focusRec = nil
	local Cx = SUI.Codex
	if Cx and Cx.on and Cx.PinOnMapEvent then Cx.PinOnMapEvent() end
end

-- Branche / debranche le fournisseur selon l'etat du module, du Codex et de l'option (a rappeler a chaque changement)
function M.Sync()
	local Cx = SUI.Codex
	if not Cx or not Cx.PinTrack then return end
	local want = M.on and Cx.on and C.Get("places.show") and true or false
	if want then
		for i = 1, getn(M.KINDS) do
			local k = M.KINDS[i]
			Cx.PINTAG["P" .. k[1]] = k[2]
			local g = k[3]
			Cx.PINCOL["P" .. k[1]] = function()
				if g == "svc" then return T.c.text end
				if g == "trv" then return T.c.good end
				if g == "res" then return T.c.dim end
				local r, gg, b = T.Accent()
				return { r, gg, b, 1 }
			end
		end
	end
	if want and Cx.providers.places ~= M.Recs then
		Cx.PinTrack(M.Recs, "places")
	elseif not want and Cx.providers.places == M.Recs then
		Cx.PinTrack(nil, "places")
	end
	if SUI.QuestTrack and SUI.QuestTrack.MiniSync then SUI.QuestTrack.MiniSync() end
end

function M.OnKey()
	if not M.on then return end
	M.Sync()
	M.Refresh()
end

function M.Enable()
	M.on = true
	M.warned = false
	SUI.On("SKILL_LINES_CHANGED", M.OnSkills)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnSkills)
	if not M.watching then
		M.watching = true
		C.Watch("places.", M.OnKey)
	end
	M.Sync()
end

function M.Disable()
	M.on = false
	SUI.Off("SKILL_LINES_CHANGED", M.OnSkills)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnSkills)
	M.Sync()
	M.me, M.zsig, M.zrec, M.zcur, M.focus, M.focusRec = nil, nil, nil, nil, nil, nil
end

function M.Command(rest)
	local _, _, a, b = sfind(rest or "", "^%s*(%S*)%s*(%S*)")
	a = slower(a or "")
	if a == "near" or a == "proche" then
		M.Nearest(b)
		return
	end
	if a == "off" or a == "clear" then
		M.focus, M.focusRec = nil, nil
		M.Refresh()
		return
	end
	SUI.Print(L("msg.places.status", C.Get("places.show") and "1" or "0"))
end

local function opt(key, typ, order, def, extra)
	local o = { key = "places." .. key, type = typ, cat = "places", label = "opt.places." .. key, tip = "tip.places." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

local OPTS = {
	opt("show", "bool", 10, true, { simple = true }),
	opt("mini", "bool", 12, true, { simple = true }),
	opt("faction", "bool", 14, true),
	opt("mine", "bool", 16, true, { simple = true }),
	opt("mounts", "bool", 18, false),
}
for i = 1, getn(M.KINDS) do
	local k = M.KINDS[i]
	tinsert(OPTS, opt(k[1], "bool", 30 + i, k[4], { simple = (k[4] and true or false) }))
end

SUI.RegisterCategory("places", 81)

SUI.RegisterModule("places", {
	default = false,
	cost = "light",
	options = OPTS,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("places", function(rest) M.Command(rest or "") end, "help.places")
