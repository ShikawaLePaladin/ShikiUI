-- ShikiUI Codex : guide des donjons (butin par boss) et recherche d'objets / de quetes, dans UNE fenetre.
-- Les donnees viennent UNIQUEMENT des addons ShikiCodexData (butin, noms) et ShikiCodexData_Quests (quetes), generes par tools/build_codex_data.js
-- (format : ShikiCodexData\FORMAT.md et FORMAT_QUESTS.md). Ce module ne lit ni Atlas-CFM ni pfQuest. Les deux addons sont LoadOnDemand : charges a la
-- premiere ouverture (donnees) et a la premiere recherche de quete (quetes), jamais au login. Fenetre construite a la premiere ouverture seulement ;
-- fermee, elle ne coute rien (pas d'OnUpdate, pas d'evenement ecoute sauf le debut de combat). L'index de recherche est prepare par petits paquets a
-- l'ouverture de la recherche et libere a la fermeture. Commande : /sui codex [texte].
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert, tsort = table.getn, table.insert, table.sort
local slower, sfind, sformat, ssub, slen = string.lower, string.find, string.format, string.sub, string.len
local floor = math.floor

local M = {}
SUI.Codex = M

M.on = false
M.NROWS = 18                 -- lignes visibles par colonne
M.RH = 18                    -- pas entre deux lignes
M.W, M.H = 650, 420
M.CHUNK = 4                  -- instances indexees par tour de minuterie
M.tab = "inst"
M.sel = { inst = nil, boss = nil }
M.off = { inst = 0, boss = 0, loot = 0, res = 0 }
M.insts = nil                -- liste triee des donjons (construite a la demande)
M.bosses, M.loots, M.res = {}, {}, {}
M.bcache = {}                -- boss d'un donjon (vide a chaque ouverture)
M.ix = nil                   -- index de recherche : listes paralleles id / nom en minuscules / donjon / boss
M.warmed = {}                -- objets dont le client a deja ete prie de charger les donnees (une seule demande par objet)
M.warned = false             -- une seule ligne de chat par session pour un probleme de donnees

local function glob(name)
	return getglobal(name)
end

-- Langue des textes : "fr" sur un client frFR, sinon "en".
local function lang()
	if GetLocale and GetLocale() == "frFR" then return "fr" end
	return "en"
end

-- ---------------------------------------------------------------- fournisseur de donnees (seul endroit qui lit ShikiCodexData*)
-- Le reste du module ne parle qu'a P. Format des donnees : ShikiCodexData\FORMAT.md et FORMAT_QUESTS.md (schema 1).
local P = {}
M.P = P
P.SCHEMA = 1                          -- version de FORME des donnees attendue
P.ADDON = "ShikiCodexData"
P.QADDON = "ShikiCodexData_Quests"
P.why, P.qwhy = nil, nil              -- derniere cause de refus : "missing" "disabled" "corrupt" "schema" "empty" "api"
P.have = {}                           -- version de schema vue par addon (pour le message "schema")

local function countKeys(t)
	local n = 0
	for k in pairs(t) do n = n + 1 end
	return n
end

-- bit b (puissance de 2) present dans m ? (pas d'operateur binaire en Lua 5.0)
local function hasBit(m, b)
	local q = floor(m / b)
	return q - floor(q / 2) * 2 == 1
end

-- m == nil : visible partout (masque 15)
local function vis(m, bit)
	if type(m) ~= "number" then return true end
	return hasBit(m, bit)
end

-- Cause de l'absence d'un addon dont la table n'existe pas apres LoadAddOn : absent de la liste, desactive, ou present mais illisible.
-- (le retour de LoadAddOn n'est pas fiable en 1.12 : on juge sur la table, puis on interroge la liste des addons)
function P.Diagnose(addon)
	local gn, gi = glob("GetNumAddOns"), glob("GetAddOnInfo")
	if not gn or not gi then return "missing" end
	for i = 1, gn() do
		local name, title, notes, enabled = gi(i)
		if name == addon then
			if not enabled then return "disabled" end
			return "corrupt"
		end
	end
	return "missing"
end

-- Controle de la table principale (une fois par table chargee) : "ok" ou la cause.
function P.CheckMain(d)
	if P.checked == d then return P.checkWhy end
	local why = "ok"
	P.have[P.ADDON] = d.schema
	if d.schema ~= P.SCHEMA then
		why = "schema"
	elseif type(d.inst) ~= "table" or type(d.profiles) ~= "table" or type(d.auto) ~= "table" or type(d.en) ~= "table" or type(d.fr) ~= "table"
		or type(d.en.i) ~= "table" or type(d.fr.i) ~= "table" then
		why = "corrupt"
	else
		local n = countKeys(d.inst)
		local want = type(d.counts) == "table" and d.counts.inst or 0
		if n == 0 and want == 0 then
			why = "empty"
		elseif n ~= want then
			why = "corrupt"            -- un fichier d'instance n'a pas ete lu (erreur Lua : le jeu saute la suite de l'addon)
		end
	end
	P.checked, P.checkWhy = d, why
	return why
end

function P.CheckQuests(q)
	if P.qchecked == q then return P.qcheckWhy end
	local why = "ok"
	P.have[P.QADDON] = q.schema
	if q.schema ~= P.SCHEMA then
		why = "schema"
	elseif type(q.q) ~= "table" or type(q.en) ~= "table" or type(q.fr) ~= "table" or type(q.en.t) ~= "table" or type(q.fr.t) ~= "table"
		or type(q.en.u) ~= "table" or type(q.en.o) ~= "table" or type(q.en.i) ~= "table" then
		why = "corrupt"
	else
		local n = countKeys(q.q)
		local want = type(q.counts) == "table" and q.counts.quests or 0
		if n == 0 and want == 0 then
			why = "empty"
		elseif n ~= want then
			why = "corrupt"
		end
	end
	P.qchecked, P.qcheckWhy = q, why
	return why
end

-- Table de donnees valide, ou nil (ne charge jamais rien).
function P.Data()
	local d = glob("ShikiCodexData")
	if type(d) ~= "table" then return nil end
	if P.CheckMain(d) ~= "ok" then return nil end
	return d
end

function P.Q()
	local q = glob("ShikiCodexQuests")
	if type(q) ~= "table" then return nil end
	if P.CheckQuests(q) ~= "ok" then return nil end
	return q
end

-- Charge ShikiCodexData a la demande (idempotent : LoadAddOn n'est appele que si la table est absente). Retour : ok, cause.
function P.Load()
	local d = glob("ShikiCodexData")
	if type(d) ~= "table" then
		local la = glob("LoadAddOn")
		if not la then
			P.why = "api"
			return false, "api"
		end
		pcall(la, P.ADDON)
		d = glob("ShikiCodexData")
		if type(d) ~= "table" then
			P.why = P.Diagnose(P.ADDON)
			return false, P.why
		end
	end
	local why = P.CheckMain(d)
	P.why = why
	return why == "ok", why
end

-- Charge ShikiCodexData_Quests (depend du premier : le jeu charge les deux). Appele a la premiere recherche de quete.
function P.LoadQuests()
	local q = glob("ShikiCodexQuests")
	if type(q) ~= "table" then
		local la = glob("LoadAddOn")
		if not la then
			P.qwhy = "api"
			return false, "api"
		end
		pcall(la, P.QADDON)
		q = glob("ShikiCodexQuests")
		if type(q) ~= "table" then
			P.qwhy = P.Diagnose(P.QADDON)
			return false, P.qwhy
		end
	end
	local why = P.CheckQuests(q)
	P.qwhy = why
	return why == "ok", why
end

function P.HasQuests()
	return P.Q() ~= nil
end

-- Metadonnees pour l'affichage : { schema, build, atlas, pfquest, octo } ou nil
function P.Info()
	local d = P.Data()
	if not d then return nil end
	local s = type(d.sources) == "table" and d.sources or {}
	return {
		schema = d.schema, build = d.build,
		atlas = s.atlas and s.atlas.version, pfquest = s.pfquest and s.pfquest.version, octo = s.octoplus and s.octoplus.version,
	}
end

-- Profil de serveur : detection "Auto" d'Atlas, decrite dans Meta.lua (D.auto : regles evaluees dans l'ordre).
function P.Detect(d)
	local gb, gr = glob("GetBuildInfo"), glob("GetRealmName")
	local build = gb and gb() or nil
	local realm = gr and gr() or nil
	local rules = d.auto.rules
	local i = 1
	while type(rules) == "table" and rules[i] do
		local r = rules[i]
		if r.b and build == r.b then return r.p end
		if r.r and realm and sfind(realm, r.r, 1, true) then return r.p end
		i = i + 1
	end
	return d.auto.fallback or d.default
end

local function bitOf(d, id)
	local i = 1
	while d.profiles[i] do
		if d.profiles[i].id == id then return d.profiles[i].bit end
		i = i + 1
	end
	return nil
end

-- Profil choisi (option codex.server, "auto" par defaut) : id et bit. Memorise jusqu'a M.Reset / M.Open.
function P.Profile()
	local d = P.Data()
	if not d then return nil, 1 end
	if P.bitv then return P.pid, P.bitv end
	local id = C.Get("codex.server")
	if not id or id == "auto" then id = P.Detect(d) end
	local bit = bitOf(d, id)
	if not bit then
		id = d.default
		bit = bitOf(d, id) or 1
	end
	P.pid, P.bitv = id, bit
	return id, bit
end

-- Nom d'affichage du profil choisi (texte d'Atlas, ex. "Turtle WoW 1.17.2") ou nil
function P.ProfileName()
	local d = P.Data()
	if not d then return nil end
	local id = P.Profile()
	local i = 1
	while d.profiles[i] do
		if d.profiles[i].id == id then return d.profiles[i].atlas or id end
		i = i + 1
	end
	return id
end

-- Donjons visibles sur le profil : { key, name, lvl, hi, acr, max, kind } (ordre de D.order puis les autres)
local function addInst(out, d, key, bit, fr)
	local it = d.inst[key]
	if type(it) ~= "table" or type(it.boss) ~= "table" or not vis(it.m, bit) then return end
	local name = it.n or key
	if fr and it.f then name = it.f end
	tinsert(out, { key = key, name = tostring(name), lvl = it.lv or 0, hi = it.hi or it.lv or 0, acr = it.acr, max = it.mx, kind = it.kd })
end

function P.Instances()
	local out = {}
	local d = P.Data()
	if not d then return out end
	local _, bit = P.Profile()
	local fr = lang() == "fr"
	local seen = {}
	local ord = d.order
	if type(ord) == "table" then
		for i = 1, getn(ord) do
			if not seen[ord[i]] then
				seen[ord[i]] = true
				addInst(out, d, ord[i], bit, fr)
			end
		end
	end
	for key in pairs(d.inst) do
		if not seen[key] then addInst(out, d, key, bit, fr) end
	end
	return out
end

-- Nombre de lignes de butin visibles d'un butin (boss ou page)
local function countLoot(loot, bit)
	local ids = loot.id
	if type(ids) ~= "table" then return 0 end
	local n = getn(ids)
	local mk = loot.mk
	if type(mk) ~= "table" then return n end
	local c = 0
	for i = 1, n do
		if vis(mk[i], bit) then c = c + 1 end
	end
	return c
end

-- Lignes visibles d'un boss : butin propre, page partagee (pg) ou menu de sets (sm : pages des sets visibles)
local function countBoss(d, b, bit)
	if b.id then return countLoot(b, bit) end
	if b.pg then
		local p = d.page and d.page[b.pg]
		return p and countLoot(p, bit) or 0
	end
	if b.sm then
		local s = d.sets and d.sets[b.sm]
		local c = 0
		local j = 1
		while type(s) == "table" and s[j] do
			local p = d.page and d.page[s[j].pg]
			if p and vis(s[j].m, bit) then c = c + countLoot(p, bit) end
			j = j + 1
		end
		return c
	end
	return 0
end

-- Boss d'un donjon : { name, n (lignes visibles), index (rang dans les donnees), key } ; seuls les boss visibles qui ont du butin
function P.Bosses(key)
	local out = {}
	local d = P.Data()
	local it = d and d.inst[key]
	if type(it) ~= "table" or type(it.boss) ~= "table" then return out end
	local _, bit = P.Profile()
	if not vis(it.m, bit) then return out end
	local fr = lang() == "fr"
	for i = 1, getn(it.boss) do
		local b = it.boss[i]
		if type(b) == "table" and vis(b.m, bit) then
			local n = countBoss(d, b, bit)
			if n > 0 then
				local name = b.n or i
				if fr and b.f then name = b.f end
				tinsert(out, { name = tostring(name), n = n, index = i, key = key })
			end
		end
	end
	return out
end

-- Ajoute les lignes visibles d'un butin : { id, rate (nombre, texte ou nil), shared (pool partage), note (precision d'Atlas) }
local function addRows(out, d, loot, bit, fr)
	local ids = loot.id
	if type(ids) ~= "table" then return end
	for i = 1, getn(ids) do
		if vis(loot.mk and loot.mk[i], bit) and type(ids[i]) == "number" then
			local r = loot.rt and loot.rt[i]
			if type(r) ~= "number" and type(r) ~= "string" then r = nil end
			local fl = loot.fl and loot.fl[i] or 0
			local note = nil
			local dc = loot.dc and loot.dc[i]
			if dc then
				note = (fr and d.discfr and d.discfr[dc]) or (d.disc and d.disc[dc])
			end
			tinsert(out, { id = ids[i], rate = r, shared = hasBit(fl, 1) or nil, note = note })
		end
	end
end

-- Butin d'un boss (rang `index` dans le donjon `key`) : liste de { id, rate, shared, note }. Le taux par defaut du boss est deja applique.
function P.Loot(key, index)
	local out = {}
	local d = P.Data()
	local it = d and d.inst[key]
	local b = type(it) == "table" and type(it.boss) == "table" and it.boss[index]
	if type(b) ~= "table" then return out end
	local _, bit = P.Profile()
	local fr = lang() == "fr"
	if b.id then
		addRows(out, d, b, bit, fr)
	elseif b.pg then
		local p = d.page and d.page[b.pg]
		if p then addRows(out, d, p, bit, fr) end
	elseif b.sm then
		local s = d.sets and d.sets[b.sm]
		local j = 1
		while type(s) == "table" and s[j] do
			local p = d.page and d.page[s[j].pg]
			if p and vis(s[j].m, bit) then addRows(out, d, p, bit, fr) end
			j = j + 1
		end
	end
	return out
end

-- Nom stocke d'un objet : langue du client, sinon anglais (repli PAR ID) ; nil si inconnu
function P.ItemName(id)
	local d = P.Data()
	if not d then return nil end
	if lang() == "fr" and d.fr.i[id] then return d.fr.i[id] end
	return d.en.i[id]
end

-- Qualite (0 a 5) et icone stockees (tables Meta.qual / Meta.icon, vides pour l'instant) ; nil, nil sinon
function P.ItemMeta(id)
	local d = P.Data()
	if not d then return nil, nil end
	local q = type(d.qual) == "table" and d.qual[id] or nil
	if type(q) ~= "number" then q = nil end
	local tex = type(d.icon) == "table" and d.icon[id] or nil
	if type(tex) ~= "string" or tex == "" then
		tex = nil
	elseif not sfind(tex, "\\", 1, true) then
		tex = "Interface\\Icons\\" .. tex
	end
	return q, tex
end

-- Quetes ---------------------------------------------------------------
-- decoupe sur un separateur litteral ; garde les champs vides ; "" donne { "" }
local function split(s, sep)
	local out = {}
	local pos = 1
	local a = sfind(s, sep, pos, true)
	while a do
		tinsert(out, ssub(s, pos, a - 1))
		pos = a + slen(sep)
		a = sfind(s, sep, pos, true)
	end
	tinsert(out, ssub(s, pos))
	return out
end

-- "u12,o5,i7,r9,+" -> { { kind = "u", id = 12 }, ... }, tronque (vrai si un "+" final)
local function refs(s)
	local out = {}
	local more = false
	if not s or s == "" then return out, more end
	local t = split(s, ",")
	for i = 1, getn(t) do
		if t[i] == "+" then
			more = true
		else
			tinsert(out, { kind = ssub(t[i], 1, 1), id = tonumber(ssub(t[i], 2)) })
		end
	end
	return out, more
end

-- "a:1,2" / "p:3@7" -> { mode, items = { { id, mask }, ... } }
local function rewardOf(s)
	if not s or s == "" then return nil end
	local out = { mode = ssub(s, 1, 1), items = {} }
	local t = split(ssub(s, 3), ",")
	for i = 1, getn(t) do
		local at = sfind(t[i], "@", 1, true)
		if at then
			tinsert(out.items, { id = tonumber(ssub(t[i], 1, at - 1)), mask = tonumber(ssub(t[i], at + 1)) })
		else
			tinsert(out.items, { id = tonumber(t[i]) })
		end
	end
	return out
end

-- Titre d'une quete : francais s'il existe (client frFR), sinon anglais ; nil si inconnue
function P.QuestTitle(id)
	local q = P.Q()
	if not q then return nil end
	if lang() == "fr" and q.fr.t[id] then return q.fr.t[id] end
	return q.en.t[id]
end

-- Niveau et niveau minimum (lus dans les 2 premieres sections, sans decoder le reste) ; nil si 0 / inconnu
function P.QuestLevels(id)
	local q = P.Q()
	local s = q and q.q[id]
	if type(s) ~= "string" then return nil, nil end
	local a = sfind(s, ";", 1, true)
	if not a then return nil, nil end
	local b = sfind(s, ";", a + 1, true)
	local lvl = tonumber(ssub(s, 1, a - 1))
	local min = tonumber(ssub(s, a + 1, (b or slen(s) + 1) - 1))
	if lvl == 0 then lvl = nil end
	if min == 0 then min = nil end
	return lvl, min
end

-- Nom d'une entite de quete : kind "u" PNJ, "o" objet du monde, "i" / "r" objet
function P.QName(kind, id)
	if kind == "r" then kind = "i" end
	if kind ~= "u" and kind ~= "o" and kind ~= "i" then return nil end
	local q = P.Q()
	if q then
		local t = q.fr[kind]
		if lang() == "fr" and type(t) == "table" and t[id] then return t[id] end
		t = q.en[kind]
		if type(t) == "table" and t[id] then return t[id] end
	end
	if kind == "i" then return P.ItemName(id) end
	return nil
end

function P.ZoneName(z)
	local q = P.Q()
	if not q or not z or z == 0 or type(q.en.z) ~= "table" then return nil end
	if lang() == "fr" and type(q.fr.z) == "table" and q.fr.z[z] then return q.fr.z[z] end
	return q.en.z[z]
end

-- Quete decodee : { id, lvl, min, zone, pre = { ids }, start, finish, obj (listes de { kind, id }), more, reward, rule } ; nil si inconnue
function P.Quest(id)
	local q = P.Q()
	local s = q and q.q[id]
	if type(s) ~= "string" then return nil end
	local f = split(s, ";")
	local r = { id = id, lvl = tonumber(f[1]) or 0, min = tonumber(f[2]) or 0, zone = tonumber(f[5]) or 0, pre = {} }
	if f[6] and f[6] ~= "" then
		local p = split(f[6], ",")
		for i = 1, getn(p) do
			tinsert(r.pre, tonumber(p[i]))
		end
	end
	r.start = refs(f[7])
	r.finish = refs(f[8])
	r.obj, r.more = refs(f[9])
	r.reward = rewardOf(f[11])
	r.rule = type(q.rr) == "table" and q.rr[id] or nil
	return r
end

-- ---------------------------------------------------------------- etat des donnees (messages, une seule ligne de chat par session)
M.WHYKEY = {
	missing = "msg.codex.nodata", disabled = "msg.codex.datadisabled", corrupt = "msg.codex.datacorrupt",
	schema = "msg.codex.dataschema", empty = "msg.codex.dataempty", api = "msg.codex.dataapi",
}

-- Texte (fr ou en) de la cause d'un refus pour l'addon `addon`.
function M.WhyText(addon, why)
	local k = M.WHYKEY[why]
	if not k then return "" end
	if why == "schema" then return L(k, addon, tostring(P.have[addon] or "?"), tostring(P.SCHEMA)) end
	return L(k, addon)
end

function M.Warn(addon, why)
	if M.warned then return end
	M.warned = true
	SUI.Print(M.WhyText(addon, why))
end

-- Donnees principales pretes ? Charge ShikiCodexData s'il le faut (une seule fois : LoadAddOn n'est pas rappele tant que la table est la).
function M.DataReady()
	local ok, why = P.Load()
	M.dataOK = ok
	M.dataWhy = nil
	if not ok then M.dataWhy = why end
	M.profText = ""
	local info = ok and P.Info()
	if info then M.profText = L("msg.codex.profile", P.ProfileName() or "?", tostring(info.build or "?")) end
	return ok
end

-- Quetes pretes ? Charge ShikiCodexData_Quests a la premiere recherche.
function M.QuestsReady()
	local ok, why = P.LoadQuests()
	M.qwhy = (not ok) and why or nil
	if not ok then M.Warn(P.QADDON, why) end
	return ok
end

-- ---------------------------------------------------------------- acces aux donnees (liste des donjons, boss, butin, noms)
-- Liste des donjons du profil : { key, name, lvl, hi, acr, max }, triee par niveau puis par nom. Seuls ceux qui ont du butin sont listes.
function M.Instances()
	if M.insts then return M.insts end
	local list = {}
	local raw = P.Instances()
	local min = C.Get("codex.minlevel") or 0
	for i = 1, getn(raw) do
		local it = raw[i]
		local key = it.key
		local hi = it.hi
		if hi == 0 then hi = 99 end              -- niveau inconnu : ne jamais le masquer par le niveau minimum
		if hi >= min and getn(M.Bosses(key)) > 0 then
			tinsert(list, it)
		end
	end
	tsort(list, function(x, y)
		if x.lvl ~= y.lvl then return x.lvl < y.lvl end
		return x.name < y.name
	end)
	M.insts = list
	return list
end

-- Boss d'un donjon : { name, n, index, key } (cache jusqu'a la prochaine ouverture).
function M.Bosses(key)
	if M.bcache[key] then return M.bcache[key] end
	local out = P.Bosses(key)
	M.bcache[key] = out
	return out
end

-- Butin d'un boss : { id, rate, shared, note } (rate : nombre, texte comme ".2-10", ou nil).
function M.Loot(boss)
	if not boss then return {} end
	return P.Loot(boss.key, boss.index)
end

-- Taux affiche : entier tel quel, fraction avec ses decimales (0.25), texte tel quel (.2-10).
function M.RateText(r)
	if type(r) == "number" then
		if r == floor(r) then return floor(r) .. "%" end
		return sformat("%g", floor(r * 100 + 0.5) / 100) .. "%"
	end
	if type(r) == "string" then return r .. "%" end
	return ""
end

-- Niveau affiche : "60" ou "19-32" ("?" si inconnu).
function M.LevelText(it)
	if (it.lvl or 0) == 0 and (it.hi or 0) == 0 then return "?" end
	if it.hi and it.hi ~= it.lvl then return it.lvl .. "-" .. it.hi end
	return tostring(it.lvl)
end

-- Nom : cache du client (sa langue), sinon nos donnees (langue du client puis anglais), sinon "#id".
function M.ItemName(id)
	local n = GetItemInfo and GetItemInfo(id)
	if n then return n end
	n = P.ItemName(id) or P.QName("i", id)
	if n then return n end
	return "#" .. id
end

-- Qualite : cache du client, sinon la valeur stockee ; nil = inconnue (couleur neutre).
function M.ItemQuality(id)
	if GetItemInfo then
		local _, _, q = GetItemInfo(id)
		if q then return q end
	end
	local q = P.ItemMeta(id)
	return q
end

-- Demande au client de charger les donnees d'un objet (une seule fois par objet) ; repeint une fois plus tard. Jamais obligatoire.
function M.Warm(id)
	if M.warmed[id] then return end
	local ci = glob("C_Item")
	local rq = type(ci) == "table" and ci.RequestLoadItemDataByID
	if not rq then return end
	M.warmed[id] = true
	pcall(rq, id)
	if not M.warmTask then M.warmTask = SUI.After(1.5, M.WarmDone, "codex.warm") end
end

function M.WarmDone()
	M.warmTask = nil
	if M.win and M.win.f:IsShown() then M.Paint() end
end

-- Icone : cache du client, sinon API instantanee de l'extension (chaine seulement), sinon icone stockee ; nil = point d'interrogation.
function M.ItemIcon(id)
	if GetItemInfo then
		local _, _, _, _, _, _, _, _, tex = GetItemInfo(id)
		if tex then return tex end
	end
	local ci = glob("C_Item")
	if type(ci) == "table" and ci.GetItemInfoInstant then
		local ok, a, b, c, d, e = pcall(ci.GetItemInfoInstant, id)
		if ok and type(e) == "string" and e ~= "" then return e end
	end
	local _, tex = P.ItemMeta(id)
	if tex then return tex end
	M.Warm(id)
	return nil
end

-- ---------------------------------------------------------------- recherche
-- Index (objets des donjons) construit par paquets, pour ne jamais bloquer l'image.
function M.StartIndex()
	if M.ix and M.ix.done then return end
	if M.ixTask then return end
	if not P.Data() then
		M.ix = { id = {}, name = {}, inst = {}, boss = {}, n = 0, done = true }
		return
	end
	M.ix = { id = {}, name = {}, inst = {}, boss = {}, n = 0, done = false, at = 0 }
	M.ixTask = SUI.Every(0.03, M.IndexStep, "codex.index")
end

function M.IndexStep()
	local ix = M.ix
	local insts = M.Instances()
	if not ix or ix.done then
		SUI.Cancel(M.ixTask)
		M.ixTask = nil
		return
	end
	local last = ix.at + M.CHUNK
	while ix.at < last and ix.at < getn(insts) do
		ix.at = ix.at + 1
		local bl = M.Bosses(insts[ix.at].key)
		for b = 1, getn(bl) do
			local lt = M.Loot(bl[b])
			for k = 1, getn(lt) do
				ix.n = ix.n + 1
				ix.id[ix.n] = lt[k].id
				ix.name[ix.n] = slower(M.ItemName(lt[k].id))
				ix.inst[ix.n] = ix.at
				ix.boss[ix.n] = b
			end
		end
	end
	if ix.at >= getn(insts) then
		ix.done = true
		SUI.Cancel(M.ixTask)
		M.ixTask = nil
		if M.pending then M.DoSearch(M.pending) end
	end
	if M.win and M.tab == "search" then M.PaintStatus() end
end

function M.ReleaseIndex()
	if M.ixTask then SUI.Cancel(M.ixTask) end
	M.ixTask = nil
	M.ix = nil
	M.pending = nil
end

function M.MaxResults()
	return C.Get("codex.maxresults") or 40
end

-- Resultats pour un texte : objets des donjons d'abord (nom ou id), puis quetes (titre ou id).
function M.DoSearch(text)
	local res = {}
	M.res = res
	M.pending = nil
	text = slower(text or "")
	if slen(text) < 2 then
		M.off.res = 0
		if M.win then M.Paint() end
		return res
	end
	local cap = M.MaxResults()
	local ix = M.ix
	M.more = false
	local num = tonumber(text)
	if num and num ~= floor(num) then num = nil end
	if ix then
		local seen = {}
		for i = 1, ix.n do
			if sfind(ix.name[i], text, 1, true) or (num and ix.id[i] == num) then
				local key = ix.id[i] .. ":" .. ix.inst[i] .. ":" .. ix.boss[i]
				if not seen[key] then
					if getn(res) >= cap then
						M.more = true
						break
					end
					seen[key] = true
					tinsert(res, { kind = "item", id = ix.id[i], inst = ix.inst[i], boss = ix.boss[i] })
				end
			end
		end
	end
	if M.QuestsReady() then
		local qd = P.Q()
		local fr = lang() == "fr" and qd.fr.t or nil
		local hits, low = {}, {}
		for id, en in pairs(qd.en.t) do
			local t = (fr and fr[id]) or en
			local lt = slower(t)
			if sfind(lt, text, 1, true) or id == num then
				low[id] = lt
				tinsert(hits, id)
			end
		end
		tsort(hits, function(x, y)
			local tx, ty = low[x], low[y]
			if tx ~= ty then return tx < ty end
			return x < y
		end)
		if getn(hits) > cap then M.more = true end
		for k = 1, getn(hits) do
			if k > cap then break end
			local id = hits[k]
			local lvl, min = P.QuestLevels(id)
			tinsert(res, { kind = "quest", id = id, title = (fr and fr[id]) or qd.en.t[id], lvl = lvl, min = min })
		end
	end
	M.off.res = 0
	if M.win then M.Paint() end
	return res
end

function M.Search(text)
	if not M.ix or not M.ix.done then
		M.pending = text
		M.StartIndex()
		if M.ix and M.ix.done then M.DoSearch(text) end
		return
	end
	M.DoSearch(text)
end

-- Noms d'une liste de references { kind, id } : "a, b, c, ..." (au plus `cap` noms distincts) ; nil si la liste est vide.
function M.RefNames(list, cap, more)
	if not list or not list[1] then return nil end
	local out, n, seen = "", 0, {}
	for i = 1, getn(list) do
		local name = P.QName(list[i].kind, list[i].id) or ("#" .. tostring(list[i].id))
		if not seen[name] then
			seen[name] = true
			if n >= cap then
				more = true
				break
			end
			n = n + 1
			if out ~= "" then out = out .. ", " end
			out = out .. name
		end
	end
	if more then out = out .. ", ..." end
	return out
end

-- Debut de la quete : nom(s) du PNJ / objet / objet de depart.
function M.QuestStart(id)
	local q = P.Quest(id)
	local s = q and M.RefNames(q.start, 3)
	return s or L("msg.codex.unknown")
end

M.REWKEY = { a = "msg.codex.rew.a", p = "msg.codex.rew.p", x = "msg.codex.rew.x" }

-- Recompenses (quetes de donjon) visibles sur le profil : texte ou nil.
function M.QuestReward(q)
	local rw = q.reward
	if not rw or not rw.items[1] then return nil end
	local _, bit = P.Profile()
	local list = {}
	for i = 1, getn(rw.items) do
		if vis(rw.items[i].mask, bit) then tinsert(list, { kind = "i", id = rw.items[i].id }) end
	end
	local names = M.RefNames(list, 8)
	if not names then return nil end
	local mode = L(M.REWKEY[rw.mode] or M.REWKEY.a)
	if rw.mode == "x" and q.rule then mode = mode .. " " .. q.rule end
	return L("msg.codex.questrew", mode, names)
end

-- Fiche d'une quete dans le chat : niveau, niveau minimum, depart, puis fin, zone, objectifs, predecesseur, recompenses quand ils existent.
function M.QuestInfo(r)
	SUI.Print(L("msg.codex.questinfo", r.title, tostring(r.lvl or "?"), tostring(r.min or "?"), M.QuestStart(r.id)))
	local q = P.Quest(r.id)
	if not q then return end
	local s = M.RefNames(q.finish, 3)
	if s then SUI.Print(L("msg.codex.questend", s)) end
	s = P.ZoneName(q.zone)
	if s then SUI.Print(L("msg.codex.questzone", s)) end
	s = M.RefNames(q.obj, 5, q.more)
	if s then SUI.Print(L("msg.codex.questobj", s)) end
	if q.pre[1] then
		local t, n = "", 0
		for i = 1, getn(q.pre) do
			if n >= 3 then
				t = t .. " / ..."
				break
			end
			n = n + 1
			if t ~= "" then t = t .. " / " end
			t = t .. (P.QuestTitle(q.pre[i]) or ("#" .. tostring(q.pre[i])))
		end
		SUI.Print(L("msg.codex.questpre", t))
	end
	s = M.QuestReward(q)
	if s then SUI.Print(s) end
end

-- ---------------------------------------------------------------- navigation
local function clamp(col, count)
	local max = count - M.NROWS
	if max < 0 then max = 0 end
	if M.off[col] > max then M.off[col] = max end
	if M.off[col] < 0 then M.off[col] = 0 end
end

function M.SelectInst(i)
	local insts = M.Instances()
	local it = insts[i]
	M.sel.inst = i
	M.sel.boss = nil
	M.off.boss, M.off.loot = 0, 0
	M.bosses = it and M.Bosses(it.key) or {}
	if M.bosses[1] then M.SelectBoss(1) else M.loots = {} end
end

function M.SelectBoss(i)
	M.sel.boss = i
	M.sel.item = nil
	M.off.loot = 0
	M.loots = M.Loot(M.bosses[i])
	M.sharedSeen = false
	for k = 1, getn(M.loots) do
		if M.loots[k].shared then M.sharedSeen = true end
	end
end

-- Aller a un objet trouve : onglet Donjons, donjon et boss choisis, listes defilees pour montrer la selection.
function M.GoTo(inst, boss, item)
	M.tab = "inst"
	M.SelectInst(inst)
	if boss then M.SelectBoss(boss) end
	if item then
		M.sel.item = item
		for k = 1, getn(M.loots) do
			if M.loots[k].id == item then
				M.off.loot = k - 1
				break
			end
		end
		clamp("loot", getn(M.loots))
	end
	M.off.inst = inst - 1
	clamp("inst", getn(M.Instances()))
	M.off.boss = (boss or 1) - 1
	clamp("boss", getn(M.bosses))
	if M.win then M.Paint() end
end

function M.Wheel(col, delta)
	local count = 0
	if col == "inst" then count = getn(M.Instances())
	elseif col == "boss" then count = getn(M.bosses)
	elseif col == "loot" then count = getn(M.loots)
	else count = getn(M.res) end
	M.off[col] = M.off[col] - delta * 3
	clamp(col, count)
	M.Paint()
end

function M.LinkItem(id)
	if not GetItemInfo then return end
	local _, link = GetItemInfo(id)
	if not link then return end
	local ck, dress, sk = glob("IsControlKeyDown"), glob("DressUpItemLink"), glob("IsShiftKeyDown")
	if ck and ck() and dress then
		dress(link)
	elseif sk and sk() then
		local eb = glob("ChatFrameEditBox")
		if eb and eb:IsVisible() then eb:Insert(link) end
	end
end

-- ---------------------------------------------------------------- fenetre
function M.RowEnter(b)
	local r, g, bl = T.Accent()
	b:SetBackdropBorderColor(r, g, bl, 1)
	local id = b.itemId
	if id and GameTooltip then
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		if GetItemInfo and GetItemInfo(id) then
			GameTooltip:SetHyperlink("item:" .. id .. ":0:0:0")
		else
			GameTooltip:SetText(M.ItemName(id))
		end
		if b.note then GameTooltip:AddLine(b.note, T.c.dim[1], T.c.dim[2], T.c.dim[3]) end
		if b.shared then GameTooltip:AddLine(L("msg.codex.shared"), T.c.dim[1], T.c.dim[2], T.c.dim[3]) end
		GameTooltip:Show()
	end
end

function M.QualityColor(b, id)
	local q = id and M.ItemQuality(id)
	local gq = glob("GetItemQualityColor")
	if q and gq then
		local r, g, bl = gq(q)
		b.label:SetTextColor(r, g, bl, 1)
	else
		b.label:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1)
	end
end

function M.RowLeave(b)
	T.SetSelected(b, b.selected)
	if b.itemId then M.QualityColor(b, b.itemId) end
	if GameTooltip then GameTooltip:Hide() end
end

function M.RowClick(b)
	local col, i = b.col, b.idx + M.off[b.col]
	if col == "inst" then
		M.SelectInst(i)
	elseif col == "boss" then
		M.SelectBoss(i)
	elseif col == "loot" then
		if M.loots[i] then M.LinkItem(M.loots[i].id) end
	else
		local r = M.res[i]
		if not r then return end
		if r.kind == "item" then
			M.GoTo(r.inst, r.boss, r.id)
		else
			M.QuestInfo(r)
		end
	end
	M.Paint()
end

function M.MakeRows(parent, col, x, y, w, withIcon, withRate)
	local rows = {}
	for i = 1, M.NROWS do
		local b = T.Button(parent, "", w, M.RH - 1, M.RowClick)
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - (i - 1) * M.RH)
		b.col, b.idx = col, i
		local lx = 4
		if withIcon then
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetWidth(M.RH - 3)
			b.icon:SetHeight(M.RH - 3)
			b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
			lx = M.RH + 1
		end
		b.label:ClearAllPoints()
		b.label:SetPoint("LEFT", b, "LEFT", lx, 0)
		b.label:SetWidth(w - lx - (withRate and 50 or 4))
		b.label:SetHeight(12)
		b.label:SetJustifyH("LEFT")
		if withRate then
			b.rate = T.Text(b, 10, T.c.dim, "RIGHT")
			b.rate:SetPoint("RIGHT", b, "RIGHT", -4, 0)
			b.rate:SetWidth(46)
		end
		b:EnableMouseWheel(true)
		b:SetScript("OnMouseWheel", function() M.Wheel(this.col, arg1) end)
		b:SetScript("OnEnter", function() M.RowEnter(this) end)
		b:SetScript("OnLeave", function() M.RowLeave(this) end)
		b:Hide()
		rows[i] = b
	end
	return rows
end

local function setRow(b, text, selected, itemId, rate, shared, note)
	if not text then
		b:Hide()
		b.itemId = nil
		b.shared, b.note = nil, nil
		return
	end
	T.SetButtonText(b, text)
	T.SetSelected(b, selected)
	b.itemId = itemId
	b.shared, b.note = shared, note
	if b.rate then b.rate:SetText(M.RateText(rate) .. (shared and "*" or "")) end
	if b.icon then
		if itemId then
			b.icon:SetTexture(M.ItemIcon(itemId) or "Interface\\Icons\\INV_Misc_QuestionMark")
			b.icon:Show()
		else
			b.icon:Hide()
		end
	end
	b:Show()
end

function M.PaintStatus()
	local w = M.win
	if not w then return end
	local txt = ""
	if not M.dataOK then
		txt = M.WhyText(P.ADDON, M.dataWhy)
	elseif M.tab == "inst" then
		txt = L("msg.codex.hint")
		if M.sharedSeen then txt = txt .. " " .. L("msg.codex.sharedhint") end
	else
		local ix = M.ix
		if ix and not ix.done then
			txt = L("msg.codex.indexing", ix.at or 0, getn(M.Instances()))
		elseif getn(M.res) > 0 then
			txt = L("msg.codex.results", getn(M.res))
			if M.more then txt = txt .. " " .. L("msg.codex.more") end
		elseif w.edit:GetText() ~= "" and slen(w.edit:GetText()) >= 2 then
			txt = L("msg.codex.noresult")
		else
			txt = L("msg.codex.search.hint")
		end
		if M.qwhy then txt = txt .. " " .. M.WhyText(P.QADDON, M.qwhy) end
	end
	w.status:SetText(txt)
	w.prof:SetText(M.profText or "")
end

function M.Paint()
	local w = M.win
	if not w then return end
	local inst = M.tab == "inst"
	for i = 1, M.NROWS do
		w.rInst[i]:Hide() w.rBoss[i]:Hide() w.rLoot[i]:Hide() w.rRes[i]:Hide()
	end
	if inst then
		w.cInst:Show() w.cBoss:Show() w.cLoot:Show() w.edit:Hide() w.cRes:Hide()
		local insts = M.Instances()
		clamp("inst", getn(insts))
		clamp("boss", getn(M.bosses))
		clamp("loot", getn(M.loots))
		for i = 1, M.NROWS do
			local k = i + M.off.inst
			local it = insts[k]
			setRow(w.rInst[i], it and (it.name .. "  (" .. sformat(L("msg.codex.level"), M.LevelText(it)) .. ")") or nil, M.sel.inst == k)
			local bk = i + M.off.boss
			local bs = M.bosses[bk]
			setRow(w.rBoss[i], bs and bs.name or nil, M.sel.boss == bk)
			local lk = i + M.off.loot
			local lt = M.loots[lk]
			setRow(w.rLoot[i], lt and M.ItemName(lt.id) or nil, lt and lt.id == M.sel.item, lt and lt.id, lt and lt.rate, lt and lt.shared, lt and lt.note)
			if lt then M.QualityColor(w.rLoot[i], lt.id) end
		end
	else
		w.cInst:Hide() w.cBoss:Hide() w.cLoot:Hide() w.edit:Show() w.cRes:Show()
		clamp("res", getn(M.res))
		local insts = M.Instances()
		for i = 1, M.NROWS do
			local r = M.res[i + M.off.res]
			if r then
				local txt
				if r.kind == "item" then
					local it = insts[r.inst]
					local bs = it and M.Bosses(it.key)[r.boss]
					txt = M.ItemName(r.id) .. "   -   " .. (bs and bs.name or "?") .. " (" .. (it and it.name or "?") .. ")"
				else
					txt = "[" .. L("msg.codex.quest") .. "] " .. r.title .. "  (" .. sformat(L("msg.codex.level"), tostring(r.lvl or "?")) .. ")"
				end
				setRow(w.rRes[i], txt, false, r.kind == "item" and r.id or nil)
				if r.kind == "item" then M.QualityColor(w.rRes[i], r.id) else w.rRes[i].label:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1) end
			else
				setRow(w.rRes[i], nil)
			end
		end
	end
	T.SetSelected(w.tabInst, inst)
	T.SetSelected(w.tabSearch, not inst)
	M.PaintStatus()
end

function M.SetTab(tab)
	M.tab = tab
	if tab == "search" then M.StartIndex() end
	M.Paint()
end

function M.OnSearchText()
	local e = this
	if M.searchTask then SUI.Cancel(M.searchTask) end
	local text = e:GetText()
	M.searchTask = SUI.After(0.35, function() M.Search(text) end, "codex.search")
end

function M.Build()
	if M.win then return end
	local f = CreateFrame("Frame", "ShikiUI_Codex", UIParent)
	f:SetWidth(M.W)
	f:SetHeight(M.H)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)
	T.Backdrop(f, T.c.panel, T.c.border)
	local w = { f = f }
	M.win = w

	w.title = T.Text(f, 14, T.c.text, "LEFT", true)
	w.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
	w.title:SetText(L("mod.codex.title"))
	w.close = T.Button(f, "x", 20, 20, function() M.Close() end)
	w.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
	w.prof = T.Text(f, 10, T.c.dim, "RIGHT")
	w.prof:SetPoint("TOPRIGHT", f, "TOPRIGHT", -34, -13)
	w.prof:SetWidth(330)
	w.prof:SetHeight(12)
	w.tabInst = T.Button(f, L("msg.codex.tab.inst"), 90, 22, function() M.SetTab("inst") end)
	w.tabInst:SetPoint("TOPLEFT", f, "TOPLEFT", 90, -8)
	w.tabSearch = T.Button(f, L("msg.codex.tab.search"), 90, 22, function() M.SetTab("search") end)
	w.tabSearch:SetPoint("LEFT", w.tabInst, "RIGHT", 6, 0)

	local top = -66
	w.cInst = CreateFrame("Frame", nil, f)
	w.cInst:SetAllPoints(f)
	w.cBoss = CreateFrame("Frame", nil, f)
	w.cBoss:SetAllPoints(f)
	w.cLoot = CreateFrame("Frame", nil, f)
	w.cLoot:SetAllPoints(f)
	w.cRes = CreateFrame("Frame", nil, f)
	w.cRes:SetAllPoints(f)
	local h1 = T.Text(w.cInst, 11, T.c.dim, "LEFT")
	h1:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -44)
	h1:SetText(L("msg.codex.col.inst"))
	local h2 = T.Text(w.cBoss, 11, T.c.dim, "LEFT")
	h2:SetPoint("TOPLEFT", f, "TOPLEFT", 218, -44)
	h2:SetText(L("msg.codex.col.boss"))
	local h3 = T.Text(w.cLoot, 11, T.c.dim, "LEFT")
	h3:SetPoint("TOPLEFT", f, "TOPLEFT", 398, -44)
	h3:SetText(L("msg.codex.col.loot"))
	w.rInst = M.MakeRows(w.cInst, "inst", 12, top, 200, false, false)
	w.rBoss = M.MakeRows(w.cBoss, "boss", 218, top, 174, false, false)
	w.rLoot = M.MakeRows(w.cLoot, "loot", 398, top, 240, true, true)
	w.rRes = M.MakeRows(w.cRes, "res", 12, top, 626, true, false)

	w.edit = T.Edit(f, 300, 22)
	w.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
	w.edit:SetScript("OnTextChanged", M.OnSearchText)
	w.edit:SetScript("OnEnterPressed", function() this:ClearFocus() M.Search(this:GetText()) end)
	w.edit:Hide()
	w.status = T.Text(f, 10, T.c.dim, "LEFT")
	w.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 8)
	w.status:SetWidth(M.W - 24)
	w.status:SetHeight(12)

	f:SetScript("OnHide", function() M.ReleaseIndex() end)
	f:Hide()
	SUI.Mover.Register("codex.win", f, { label = L("mod.codex.title"), point = "CENTER", x = 0, y = 0, scale = true })
	local sp = glob("UISpecialFrames")
	if type(sp) == "table" then tinsert(sp, "ShikiUI_Codex") end
end

-- ---------------------------------------------------------------- ouverture, fermeture
function M.Open(text)
	if not M.on then SUI.Print(L("msg.codex.off")) return end
	if SUI.InCombat() then SUI.Print(L("msg.codex.combat")) return end
	if not M.win then M.Build() end
	if not M.DataReady() then M.Warn(P.ADDON, M.dataWhy) end
	M.insts = nil
	M.bcache = {}
	local insts = M.Instances()
	if not M.sel.inst or not insts[M.sel.inst] then
		if insts[1] then M.SelectInst(1) end
	end
	if text and text ~= "" then
		M.tab = "search"
		M.StartIndex()
		M.win.edit:SetText(text)
		M.Search(text)
	end
	M.win.f:Show()
	M.Paint()
end

function M.Close()
	if M.win then M.win.f:Hide() end
end

function M.Toggle(text)
	if M.win and M.win.f:IsShown() and (not text or text == "") then
		M.Close()
	else
		M.Open(text)
	end
end

function M.OnCombat()
	if M.win and M.win.f:IsShown() and C.Get("codex.closecombat") then M.Close() end
end

-- Oublie les listes calculees (niveau minimum ou profil de serveur change) : tout est recalcule a la prochaine ouverture.
function M.Reset()
	M.insts = nil
	M.bcache = {}
	P.bitv = nil
	M.ReleaseIndex()
	M.sel.inst, M.sel.boss, M.sel.item = nil, nil, nil
	M.bosses, M.loots, M.res = {}, {}, {}
	M.off.res, M.more = 0, false
end

function M.OnKey(key, value)
	if key == "codex.minlevel" or key == "codex.server" then
		M.Reset()
		if M.win and M.win.f:IsShown() then M.Open() end
	end
end

function M.Enable()
	M.on = true
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombat)
	if not M.watching then
		M.watching = true
		C.Watch("codex.", M.OnKey)
	end
end

function M.Disable()
	M.on = false
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombat)
	if M.searchTask then SUI.Cancel(M.searchTask) M.searchTask = nil end
	if M.warmTask then SUI.Cancel(M.warmTask) M.warmTask = nil end
	M.ReleaseIndex()
	M.Close()
end

SUI.RegisterCategory("codex", 79)

SUI.RegisterModule("codex", {
	default = false,
	cost = "light",
	options = {
		{ key = "codex.server", type = "choice", cat = "codex", label = "opt.codex.server", tip = "tip.codex.server",
			choices = { "auto", "classic", "turtle117", "turtle118", "vplus" }, default = "auto", order = 5 },
		{ key = "codex.closecombat", type = "bool", cat = "codex", label = "opt.codex.closecombat", tip = "tip.codex.closecombat",
			default = true, simple = true, order = 10 },
		{ key = "codex.maxresults", type = "number", cat = "codex", label = "opt.codex.maxresults", tip = "tip.codex.maxresults",
			min = 20, max = 200, step = 10, default = 40, order = 20 },
		{ key = "codex.minlevel", type = "number", cat = "codex", label = "opt.codex.minlevel", tip = "tip.codex.minlevel",
			min = 0, max = 60, step = 5, default = 0, order = 30 },
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("codex", function(rest)
	if not C.Get("modules.codex") then C.Set("modules.codex", true) end
	M.Toggle(rest)
end, "help.codex")
