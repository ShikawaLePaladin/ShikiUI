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
M.RATEW = 76                 -- largeur de la colonne de droite "large" (marque + palier)
M.W, M.H = 650, 420
M.CHUNK = 4                  -- instances indexees par tour de minuterie
M.tab = "inst"
M.sel = { inst = nil, boss = nil }
M.off = { inst = 0, boss = 0, loot = 0, res = 0, fac = 0, tier = 0, ritem = 0 }
M.insts = nil                -- liste triee des donjons (construite a la demande)
M.bosses, M.loots, M.res = {}, {}, {}
M.bcache = {}                -- boss d'un donjon (vide a chaque ouverture)
M.repList = nil              -- factions du profil (construites a la demande, videes a chaque ouverture)
M.repAll, M.repTiers, M.repItems = {}, {}, {}   -- lignes de la faction choisie, paliers presents, lignes du palier choisi
M.ix = nil                   -- index de recherche : listes paralleles id / nom en minuscules / donjon / boss
M.warmed = {}                -- objets dont le client a deja ete prie de charger les donnees (une seule demande par objet)
M.warned = false             -- une seule ligne de chat par session pour un probleme de donnees

local function glob(name)
	return getglobal(name)
end

-- Langue des textes : celle de ShikiUI (reglage de langue de l'interface), pas celle du client WoW :
-- un client anglais avec une interface francaise doit voir les quetes et les objets en francais.
local function lang()
	if SUI and SUI.locale then return SUI.locale == "fr" and "fr" or "en" end
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
	-- entrees en plus : pages de reputation liees (it.rp) puis chaine d'attunement (D.attune) ; index = 0 (pas un boss des donnees)
	-- (l'entree de reputation n'est qu'un LIEN : un clic ouvre l'onglet Reputations ; ses objets n'ont pas de liste ici)
	local rp = it.rp
	local k = 1
	while type(rp) == "table" and rp[k] do
		local p = d.page and d.page[rp[k]]
		local n = p and countLoot(p, bit) or 0
		if n > 0 then
			tinsert(out, { name = L("msg.codex.rep.entry", P.RepName(d, rp[k], fr)), n = n, index = 0, key = key, rp = rp[k] })
		end
		k = k + 1
	end
	local ch = P.AttuneChain(key)
	if ch then
		tinsert(out, { name = L("msg.codex.attune.entry"), n = getn(ch), index = 0, key = key, att = true })
	end
	return out
end

-- Nom d'une faction (liste D.rep) : francais ecrit a la main s'il existe, sinon anglais, sinon la cle de page
function P.RepName(d, pg, fr)
	local r = d.rep
	local i = 1
	while type(r) == "table" and r[i] do
		if r[i].pg == pg then
			if fr and r[i].f then return r[i].f end
			return r[i].n or pg
		end
		i = i + 1
	end
	return pg
end

-- Libelle d'un palier de reputation (standingId 1 a 8 ; les donnees n'utilisent que 4 a 8) : texte du client (FACTION_STANDING_LABELn), sinon nos textes
function P.TierText(n)
	if type(n) ~= "number" or n < 1 or n > 8 or n ~= floor(n) then return nil end
	local g = glob("FACTION_STANDING_LABEL" .. n)
	if type(g) == "string" and g ~= "" then return g end
	return L("msg.codex.standing." .. n)
end

-- Chaine d'attunement de l'instance pour le camp du joueur : liste d'ids de quetes, ou nil (camp inconnu : premiere chaine de la liste)
function P.AttuneChain(key)
	local d = P.Data()
	local a = d and type(d.attune) == "table" and d.attune[key]
	if type(a) ~= "table" then return nil end
	local fg = glob("UnitFactionGroup")
	local grp = fg and fg("player")
	local side = (grp == "Horde" and 2) or (grp == "Alliance" and 1) or nil
	local i = 1
	while type(a[i]) == "table" do
		if a[i].sd == 0 or a[i].sd == side or (not side and i == 1) then
			if type(a[i].ch) == "table" and a[i].ch[1] then return a[i].ch end
		end
		i = i + 1
	end
	return nil
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
			local tr = loot.tr and loot.tr[i]
			if type(tr) ~= "number" or tr < 1 then tr = nil end
			tinsert(out, { id = ids[i], rate = r, shared = hasBit(fl, 1) or nil, note = note, tr = tr, tier = tr and P.TierText(tr) or nil })
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

-- Lignes (visibles sur le profil) d'une page de reputation : { id, shared, note, tr (palier 1 a 8 ou nil), tier (libelle du palier ou nil) }
function P.RepRows(pg)
	local out = {}
	local d = P.Data()
	local p = d and d.page and d.page[pg]
	if type(p) ~= "table" then return out end
	local _, bit = P.Profile()
	addRows(out, d, p, bit, lang() == "fr")
	return out
end

-- Nombre de lignes par palier : liste { tier, n } triee (paliers croissants, puis tier = 0 pour les lignes sans palier)
function P.TierCounts(rows)
	local c, out = {}, {}
	for i = 1, getn(rows) do
		local t = rows[i].tr or 0
		c[t] = (c[t] or 0) + 1
	end
	for t = 1, 8 do
		if c[t] then tinsert(out, { tier = t, n = c[t] }) end
	end
	if c[0] then tinsert(out, { tier = 0, n = c[0] }) end
	return out
end

-- Lignes de la chaine d'attunement : { quest = id, title, en, frt (titres anglais / francais s'ils existent), step, steps, lvl, min, pre (ids ou nil) } ;
-- titre dans D.fr.q / D.en.q, sinon addon de quetes, sinon #id. Niveau, minimum et prerequis viennent de l'addon de quetes (nil tant qu'il n'est pas charge).
function P.AttuneRows(key)
	local out = {}
	local ch = P.AttuneChain(key)
	if not ch then return out end
	local d = P.Data()
	local qd = P.Q()
	local fr = lang() == "fr"
	for i = 1, getn(ch) do
		local id = ch[i]
		local ten = (d.en and d.en.q and d.en.q[id]) or (qd and qd.en.t[id]) or nil
		local tfr = (d.fr and d.fr.q and d.fr.q[id]) or (qd and qd.fr.t[id]) or nil
		local t = (fr and tfr) or ten or ("#" .. tostring(id))
		local lvl, min = P.QuestLevels(id)
		local q = qd and P.Quest(id)
		tinsert(out, { quest = id, title = t, en = ten, frt = tfr, step = i, steps = getn(ch), lvl = lvl, min = min, pre = q and q.pre or nil })
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

-- Epingles de carte d'une quete (section 10, groupees par zone) : liste de { kind = "S"|"E"|"O", zone = id, x, y (en % de la carte de la zone), ref } ; nil si inconnue.
-- Jeton = <type><valeur>[.<ref>], valeur = round(x * 10) * 1024 + round(y * 10) (FORMAT_QUESTS.md section 6). Un jeton illisible est ignore.
function P.QuestPins(id)
	local q = P.Q()
	local s = q and q.q[id]
	if type(s) ~= "string" then return nil end
	local out = {}
	local f = split(s, ";")
	if not f[10] or f[10] == "" then return out end
	local groups = split(f[10], "/")
	for i = 1, getn(groups) do
		local c = sfind(groups[i], ":", 1, true)
		local zone = c and tonumber(ssub(groups[i], 1, c - 1))
		if zone then
			local toks = split(ssub(groups[i], c + 1), ",")
			for k = 1, getn(toks) do
				local tok = toks[k]
				local kind = ssub(tok, 1, 1)
				local dot = sfind(tok, ".", 1, true)
				local ref = 0
				local v
				if dot then
					ref = tonumber(ssub(tok, dot + 1)) or 0
					v = tonumber(ssub(tok, 2, dot - 1))
				else
					v = tonumber(ssub(tok, 2))
				end
				if v and (kind == "S" or kind == "E" or kind == "O") then
					local xi = floor(v / 1024)
					tinsert(out, { kind = kind, zone = zone, x = xi / 10, y = (v - xi * 1024) / 10, ref = ref })
				end
			end
		end
	end
	return out
end

-- Noms d'une zone (anglais, francais s'il differe) : l'anglais sert a retrouver la carte du monde par son NOM, jamais par un numero.
function P.ZoneBoth(z)
	local q = P.Q()
	if not q or not z or type(q.en.z) ~= "table" then return nil, nil end
	local fr = type(q.fr.z) == "table" and q.fr.z[z] or nil
	return q.en.z[z], fr
end

-- 1 (zone vanilla) ou 2 (zone Turtle) si la zone a une carte du monde ; nil sinon (donjon, sous-zone : ne pas epingler)
function P.ZoneMap(z)
	local q = P.Q()
	local v = q and type(q.zk) == "table" and q.zk[z] or nil
	if v == 1 or v == 2 then return v end
	return nil
end

-- Cle de comparaison d'un nom de faction : minuscules, sans espaces autour, sans "the " initial. Le palier du joueur se retrouve par le NOM
-- (le client n'a pas d'identifiant de faction dans nos donnees).
local function factionKey(s)
	if type(s) ~= "string" then return "" end
	s = slower(s)
	local _, _, t = sfind(s, "^%s*(.-)%s*$")
	s = t or s
	if ssub(s, 1, 4) == "the " then s = ssub(s, 5) end
	return s
end

-- Factions du profil (ordre du menu d'Atlas) qui ont au moins une ligne visible : { pg, name, loc, side (1 Alliance, 2 Horde ou nil), n, keys }.
-- keys : noms comparables (anglais puis francais ; "A / B" donne deux noms) pour retrouver la faction dans la liste du client.
-- ATTENTION : une meme page peut apparaitre deux fois (StormpikeFrostwolf, une par camp) : l'identifiant d'une ligne est son RANG, jamais pg.
function P.Reps()
	local out = {}
	local d = P.Data()
	if not d or type(d.rep) ~= "table" then return out end
	local _, bit = P.Profile()
	local fr = lang() == "fr"
	for i = 1, getn(d.rep) do
		local r = d.rep[i]
		local p = type(r) == "table" and d.page and d.page[r.pg]
		if type(p) == "table" and vis(r.m, bit) then
			local n = countLoot(p, bit)
			if n > 0 then
				local name = r.n or r.pg
				if fr and r.f then name = r.f end
				local loc = r.ex
				if fr and r.exf then loc = r.exf end
				local keys = {}
				local names = { r.n, r.f }
				for k = 1, 2 do
					if type(names[k]) == "string" then
						local parts = split(names[k], " / ")
						for j = 1, getn(parts) do tinsert(keys, factionKey(parts[j])) end
					end
				end
				tinsert(out, { pg = r.pg, name = tostring(name), loc = loc, side = r.sd, n = n, keys = keys })
			end
		end
	end
	return out
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
	if boss.rp then return {} end            -- simple lien vers l'onglet Reputations (un clic y va)
	if boss.att then return P.AttuneRows(boss.key) end
	return P.Loot(boss.key, boss.index)
end

-- ---------------------------------------------------------------- reputations et attunements : etat du joueur (lu, jamais modifie)
-- Paliers actuels : { [cle de nom] = standingId (1 Hated ... 8 Exalted) } d'apres GetNumFactions / GetFactionInfo ; nil si le client n'a pas ces fonctions.
-- Les categories repliees du panneau de reputation cachent leurs factions de la liste : une faction absente est INCONNUE (on ne l'ouvre pas, on ne suppose rien).
function M.Standings()
	local gn, gi = glob("GetNumFactions"), glob("GetFactionInfo")
	if not gn or not gi then return nil end
	local ok, n = pcall(gn)
	if not ok or type(n) ~= "number" then return nil end
	local out = {}
	for i = 1, n do
		local ok2, name, _, st = pcall(gi, i)
		if ok2 and type(name) == "string" and type(st) == "number" then
			local k = factionKey(name)
			if out[k] == nil then out[k] = st end
		end
	end
	return out
end

-- Palier actuel du joueur pour une faction de la liste (cles de nom), ou nil si inconnu
function M.RepStanding(rep, map)
	if not rep or not map then return nil end
	for i = 1, getn(rep.keys) do
		local v = map[rep.keys[i]]
		if v then return v end
	end
	return nil
end

-- Marque et jeton de couleur d'un palier requis : atteint [x], manquant [ ], inconnu [?] ; rien pour une ligne sans palier
function M.TierMark(standing, tier)
	if type(tier) ~= "number" or tier < 1 then return nil, nil end
	if type(standing) ~= "number" then return "[?]", T.c.dim end
	if standing >= tier then return "[x]", T.c.good end
	return "[ ]", T.c.bad
end

function M.SideText(sd)
	local g = glob(sd == 1 and "FACTION_ALLIANCE" or "FACTION_HORDE")
	if type(g) == "string" and g ~= "" then return g end
	return sd == 1 and "Alliance" or "Horde"
end

-- Journal de quetes : { [titre en minuscules] = 1 (en cours) ou 2 (a rendre) } ; nil sans API. C'est TOUT ce que l'API 1.12 donne : elle ne dit pas quelles
-- quetes sont terminees, et une zone repliee du journal cache ses quetes (une quete absente peut donc etre finie, jamais prise ou cachee).
function M.Journal()
	local gn, gt = glob("GetNumQuestLogEntries"), glob("GetQuestLogTitle")
	if not gn or not gt then return nil end
	local ok, n = pcall(gn)
	if not ok or type(n) ~= "number" then return nil end
	local out = {}
	for i = 1, n do
		local ok2, title, _, _, isHeader, _, isComplete = pcall(gt, i)
		if ok2 and type(title) == "string" and not isHeader then
			out[slower(title)] = (isComplete == 1) and 2 or 1
		end
	end
	return out
end

-- Etat d'une ligne de chaine dans le journal : 1, 2 ou nil (journal illisible ou quete absente)
function M.ChainState(lt, jr)
	if not jr then return nil end
	return jr[slower(lt.title)] or (lt.en and jr[slower(lt.en)]) or (lt.frt and jr[slower(lt.frt)]) or nil
end

-- Texte de la colonne de droite d'une quete de chaine (marque + niveau) et son jeton de couleur
function M.ChainInfo(lt, jr)
	local st = M.ChainState(lt, jr)
	local mark = (st == 2 and "+") or (st == 1 and "*") or ""
	local col = (st == 2 and T.c.good) or (st == 1 and T.c.warn) or T.c.dim
	local lv = lt.lvl and tostring(lt.lvl) or ""
	if mark ~= "" and lv ~= "" then mark = mark .. " " end
	return mark .. lv, col, st
end

-- Infobulle d'une quete de chaine : niveau, prerequis des donnees, etat dans le journal
function M.ChainTip(b)
	local lt = b.chainRow
	if not lt or not GameTooltip then return end
	local d = T.c.dim
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:SetText(lt.title)
	GameTooltip:AddLine(L("msg.codex.attune.tiplvl", lt.lvl and tostring(lt.lvl) or "?", lt.min and tostring(lt.min) or "?"), d[1], d[2], d[3])
	if lt.pre then
		if lt.pre[1] then
			local names, n = "", 0
			for i = 1, getn(lt.pre) do
				if n >= 3 then
					names = names .. " / ..."
					break
				end
				n = n + 1
				if names ~= "" then names = names .. " / " end
				names = names .. (P.QuestTitle(lt.pre[i]) or ("#" .. tostring(lt.pre[i])))
			end
			GameTooltip:AddLine(L("msg.codex.questpre", names), d[1], d[2], d[3])
		else
			GameTooltip:AddLine(L("msg.codex.attune.tipnopre"), d[1], d[2], d[3])
		end
	end
	if b.chainState == 2 then
		GameTooltip:AddLine(L("msg.codex.attune.tipdone"), T.c.good[1], T.c.good[2], T.c.good[3])
	elseif b.chainState == 1 then
		GameTooltip:AddLine(L("msg.codex.attune.tiplog"), T.c.warn[1], T.c.warn[2], T.c.warn[3])
	elseif b.chainJournal then
		GameTooltip:AddLine(L("msg.codex.attune.tipnolog"), d[1], d[2], d[3])
	end
	GameTooltip:Show()
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
				if lt[k].id then
					ix.n = ix.n + 1
					ix.id[ix.n] = lt[k].id
					ix.name[ix.n] = slower(M.ItemName(lt[k].id))
					ix.inst[ix.n] = ix.at
					ix.boss[ix.n] = b
				end
			end
		end
	end
	if ix.at >= getn(insts) then
		M.IndexReps(ix)
		ix.done = true
		SUI.Cancel(M.ixTask)
		M.ixTask = nil
		if M.pending then M.DoSearch(M.pending) end
	end
	if M.win and M.tab == "search" then M.PaintStatus() end
end

-- Objets des pages de reputation : inst = 0, boss = rang de la faction dans M.Reps() (une page partagee par deux camps n'est indexee qu'une fois)
function M.IndexReps(ix)
	local list = M.Reps()
	local seen = {}
	for r = 1, getn(list) do
		if not seen[list[r].pg] then
			seen[list[r].pg] = true
			local rows = P.RepRows(list[r].pg)
			local at = M.FindRep(list[r].pg) or r      -- le rang du camp du joueur quand la page sert aux deux camps
			for k = 1, getn(rows) do
				ix.n = ix.n + 1
				ix.id[ix.n] = rows[k].id
				ix.name[ix.n] = slower(M.ItemName(rows[k].id))
				ix.inst[ix.n] = 0
				ix.boss[ix.n] = at
			end
		end
	end
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
	M.selQuest = nil
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
	local rec = M.PinBuild(r.id, q)
	if rec and rec.n > 0 then
		SUI.Print(L("msg.codex.pin.zones", M.PinZoneList(rec)))
	elseif rec then
		SUI.Print(L("msg.codex.pin.nocoord", rec.t))
	end
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

-- ---------------------------------------------------------------- epingles de carte (UNE quete a la fois, carte du monde seulement)
-- Un enregistrement resolu { id, t (titre), n (nombre d'epingles), zones = { { en, fr, map, n, pins = { { k, x, y, nm, ek } } } } } est garde en memoire et
-- dans ShikiUIDB.global.codexpin["Nom-Royaume"] (quelques centaines d'octets) : apres /reload la carte montre l'epingle SANS recharger les donnees.
-- La zone se retrouve par son NOM (GetMapContinents / GetMapZones), jamais par un numero. Les epingles sont des Button enfants de WorldMapButton, posees
-- seulement pour la zone AFFICHEE (WORLD_MAP_UPDATE, regroupe par M.PinSettle) ; la minuterie de surveillance n'existe que tant qu'une quete est epinglee.
-- NON VERIFIE en jeu : ToggleWorldMap puis SetMapZoom (ordre), WORLD_MAP_UPDATE a l'ouverture, niveau des cadres, noms de zones Turtle dans GetMapZones.
M.PIN_MAX = 14                -- epingles posees a la fois = taille du pool (les donnees en donnent 12 au plus par quete)
M.PIN_SIZE = 14
M.PIN_DELAY = 0.2             -- silence attendu apres le dernier WORLD_MAP_UPDATE (la carte en envoie une centaine a l'ouverture)
M.PIN_WATCH = 0.5             -- surveillance de l'ouverture / fermeture de la carte
M.PINKINDS = { "S", "E", "O" }
M.PINLABEL = { S = "msg.codex.pin.start", E = "msg.codex.pin.end", O = "msg.codex.pin.obj" }
M.pins = {}                   -- pool d'epingles (jamais detruites, creees hors combat)
M.pin = nil                   -- quete epinglee (enregistrement resolu)
M.pinRefreshes = 0
M.moved = false               -- vrai quand NOUS avons change la zone de la carte (a remettre sur la zone du joueur a la fermeture)

-- nom de zone comparable : minuscules, sans espaces autour ("Northwind " de pfQuest)
local function normName(s)
	if type(s) ~= "string" then return "" end
	s = slower(s)
	local _, _, t = sfind(s, "^%s*(.-)%s*$")
	return t or s
end

-- Index des cartes du client : nom normalise -> { c, z } (une fois par session ; jamais memorise tant que le client ne liste rien)
function M.MapIndex()
	if M.mapIdx then return M.mapIdx end
	local gc, gz = glob("GetMapContinents"), glob("GetMapZones")
	if not gc or not gz then return nil end
	local idx, n = {}, 0
	local conts = { gc() }
	for c = 1, getn(conts) do
		local zs = { gz(c) }
		for z = 1, getn(zs) do
			local key = normName(zs[z])
			if key ~= "" and not idx[key] then
				idx[key] = { c = c, z = z }
				n = n + 1
			end
		end
	end
	if n == 0 then return nil end
	M.mapIdx = idx
	return idx
end

-- Carte affichee : continent, zone (0 = vue du continent)
function M.MapCur()
	local gc, gz = glob("GetCurrentMapContinent"), glob("GetCurrentMapZone")
	if not gc or not gz then return nil, nil end
	return gc(), gz()
end

-- Retrouve la carte d'une zone par son nom (anglais, puis francais). true / false memorises ; nil = le client ne liste aucune carte (rien memorise).
function M.PinResolve(g)
	if g.res ~= nil then return g.res end
	local idx = M.MapIndex()
	if not idx then return nil end
	local e = idx[normName(g.en)] or (g.fr and idx[normName(g.fr)]) or nil
	if e then
		g.c, g.z = e.c, e.z
		g.res = true
	else
		g.res = false
	end
	return g.res
end

-- Zone epinglable ici : elle a une carte du monde dans les donnees ET le client la connait
function M.PinUsable(g)
	return g.map ~= nil and M.PinResolve(g) == true
end

function M.PinZoneText(g)
	if lang() == "fr" and g.fr then return g.fr end
	return g.en
end

-- Resolution d'une quete : zones dans l'ordre depart, fin, objectifs ; les zones sans carte gardent seulement leur nombre d'epingles.
function M.PinBuild(id, q)
	q = q or P.Quest(id)
	if not q then return nil end
	local raw = P.QuestPins(id) or {}
	local rec = { id = id, t = P.QuestTitle(id) or ("#" .. tostring(id)), n = 0, zones = {} }
	local lists = { S = q.start, E = q.finish, O = q.obj }
	local byz = {}
	for pass = 1, 3 do
		local kind = M.PINKINDS[pass]
		local list = lists[kind]
		for i = 1, getn(raw) do
			local p = raw[i]
			if p.kind == kind then
				local g = byz[p.zone]
				if not g then
					local en, fr = P.ZoneBoth(p.zone)
					g = { en = en or ("#" .. tostring(p.zone)), fr = fr, map = P.ZoneMap(p.zone), n = 0, pins = {} }
					byz[p.zone] = g
					tinsert(rec.zones, g)
				end
				g.n = g.n + 1
				rec.n = rec.n + 1
				if g.map and getn(g.pins) < M.PIN_MAX then
					local e = list and list[p.ref]
					tinsert(g.pins, { k = kind, x = p.x, y = p.y, nm = e and P.QName(e.kind, e.id) or nil, ek = e and e.kind or nil })
				end
			end
		end
	end
	return rec
end

-- Etiquette d'une zone qui ne peut pas etre epinglee (nil = epinglable)
function M.PinTag(g)
	if not g.map then return L("msg.codex.pin.tag.nomap") end
	if M.PinResolve(g) ~= true then return L("msg.codex.pin.tag.unknown") end
	return nil
end

-- "Elwynn Forest (3), Westfall (2, pas de carte du monde)" : toutes les zones de la quete, avec ce qu'on peut en faire
function M.PinZoneList(rec)
	local out = ""
	for i = 1, getn(rec.zones) do
		local g = rec.zones[i]
		local tag = M.PinTag(g)
		if out ~= "" then out = out .. ", " end
		out = out .. M.PinZoneText(g) .. " (" .. g.n .. (tag and (", " .. tag) or "") .. ")"
	end
	return out
end

-- Copie propre d'un enregistrement (sauvegarde et relecture) : seulement des textes et des nombres valides, bornes ; nil si inutilisable.
function M.PinClean(rec)
	if type(rec) ~= "table" or type(rec.id) ~= "number" or type(rec.zones) ~= "table" then return nil end
	local out = { id = rec.id, t = type(rec.t) == "string" and rec.t or ("#" .. tostring(rec.id)), n = 0, zones = {} }
	for i = 1, getn(rec.zones) do
		local z = rec.zones[i]
		if i > 16 then break end
		if type(z) == "table" and type(z.en) == "string" and z.en ~= "" then
			local g = { en = z.en, fr = type(z.fr) == "string" and z.fr or nil, map = (z.map == 1 or z.map == 2) and z.map or nil, pins = {} }
			if g.map and type(z.pins) == "table" then
				for k = 1, getn(z.pins) do
					local p = z.pins[k]
					if getn(g.pins) >= M.PIN_MAX then break end
					if type(p) == "table" and (p.k == "S" or p.k == "E" or p.k == "O") and type(p.x) == "number" and type(p.y) == "number"
						and p.x >= 0 and p.x <= 100 and p.y >= 0 and p.y <= 100 then
						tinsert(g.pins, { k = p.k, x = p.x, y = p.y, nm = type(p.nm) == "string" and p.nm or nil, ek = type(p.ek) == "string" and p.ek or nil })
					end
				end
			end
			g.n = type(z.n) == "number" and floor(z.n) or getn(g.pins)
			if g.n < getn(g.pins) then g.n = getn(g.pins) end
			out.n = out.n + g.n
			tinsert(out.zones, g)
		end
	end
	if getn(out.zones) == 0 or out.n == 0 then return nil end
	return out
end

-- Sauvegarde par personnage (nil efface) ; jamais de frame ni de fonction dans la base
function M.PinStore(rec)
	local all = C.GetGlobal("codexpin")
	if type(all) ~= "table" then
		if not rec then return end
		all = {}
		C.SetGlobal("codexpin", all)
	end
	all[C.CharKey()] = rec
end

-- ---- cadres
-- Couleur (jeton du theme) et marque d'un type d'epingle : depart !, fin ?, objectif o
function M.PinColor(kind)
	if kind == "S" then return T.c.warn end
	if kind == "E" then return T.c.good end
	return T.c.bad
end

M.PINMARK = { S = "!", E = "?", O = "o" }

-- i-eme epingle du pool ; creee a la demande, HORS combat seulement (nil sinon : l'appelant reessaie plus tard)
function M.PinFrame(i)
	local p = M.pins[i]
	if p then return p end
	if i > M.PIN_MAX or SUI.InCombat() then return nil end
	local btn = glob("WorldMapButton")
	if not btn then return nil end
	p = CreateFrame("Button", nil, btn)
	p:SetWidth(M.PIN_SIZE)
	p:SetHeight(M.PIN_SIZE)
	p:SetFrameLevel(btn:GetFrameLevel() + 8)
	p:EnableMouse(true)
	T.Backdrop(p, T.c.warn, T.c.bg)
	p.mark = T.Text(p, 10, T.c.bg, "CENTER")
	p.mark:SetPoint("CENTER", p, "CENTER", 0, 0)
	p.kind = "S"
	p.mark:SetText(M.PINMARK.S)
	p:SetScript("OnEnter", function() M.PinEnter(this) end)
	p:SetScript("OnLeave", function() M.PinLeave(this) end)
	p:Hide()
	M.pins[i] = p
	return p
end

-- Infobulle : titre de la quete, puis "Depart : <PNJ>" / "Fin : ..." / "Objectif : ..." (un nom d'objet est signale comme tel)
function M.PinEnter(p)
	local rec, d = M.pin, p.data
	local tt = glob("WorldMapTooltip") or glob("GameTooltip")
	if not rec or not d or not tt then return end
	local r, g, bl = T.Accent()
	p:SetBackdropBorderColor(r, g, bl, 1)
	tt:SetOwner(p, "ANCHOR_LEFT")
	tt:SetText(rec.t)
	local line = L(M.PINLABEL[d.k] or M.PINLABEL.O)
	if d.nm then
		line = line .. ": " .. d.nm
		if d.ek == "i" or d.ek == "r" then line = line .. " (" .. L("msg.codex.pin.item") .. ")" end
	end
	tt:AddLine(line, T.c.dim[1], T.c.dim[2], T.c.dim[3])
	tt:Show()
end

function M.PinLeave(p)
	T.Backdrop(p, M.PinColor(p.kind), T.c.bg)
	local tt = glob("WorldMapTooltip") or glob("GameTooltip")
	if tt then tt:Hide() end
end

-- Bandeau en haut de la carte : ce qui est epingle et ou le voir (clic : zone suivante). Cree hors combat.
function M.PinBanner()
	if M.banner then return M.banner end
	local btn = glob("WorldMapButton")
	if not btn or SUI.InCombat() then return nil end
	local b = T.Button(btn, "", 420, 20, function() M.PinNext() end)
	b:SetPoint("TOPLEFT", btn, "TOPLEFT", 12, -12)
	b:SetFrameLevel(btn:GetFrameLevel() + 9)
	b.label:SetWidth(410)
	b:Hide()
	M.banner = b
	return b
end

function M.PinHideAll()
	for i = 1, getn(M.pins) do M.pins[i]:Hide() end
	if M.banner then M.banner:Hide() end
end

-- ---- pose
-- Texte du bandeau : zone affichee (here) ou les autres zones epinglables
function M.PinBannerText(rec, here)
	local others, text = 0, ""
	for i = 1, getn(rec.zones) do
		local g = rec.zones[i]
		if g ~= here and M.PinUsable(g) then
			others = others + 1
			if others <= 4 then
				if text ~= "" then text = text .. ", " end
				text = text .. M.PinZoneText(g) .. " (" .. g.n .. ")"
			end
		end
	end
	if others > 4 then text = text .. ", ..." end
	if here then
		if others > 0 then return L("msg.codex.pin.banner.here", rec.t, getn(here.pins)) end
		return L("msg.codex.pin.banner.alone", rec.t, getn(here.pins))
	end
	if others > 0 then return L("msg.codex.pin.banner.other", rec.t, text) end
	return L("msg.codex.pin.banner.none", rec.t)
end

-- Pose les epingles de la zone affichee (une seule zone a la fois) ; cache tout ailleurs et quand la carte est fermee.
function M.PinRefresh()
	M.pinRetry = false
	local rec = M.pin
	local wm, btn = glob("WorldMapFrame"), glob("WorldMapButton")
	if not rec or not wm or not btn or not wm:IsShown() then
		M.PinHideAll()
		return
	end
	M.pinRefreshes = M.pinRefreshes + 1
	local c, z = M.MapCur()
	local here = nil
	if c and z and z > 0 then
		for i = 1, getn(rec.zones) do
			local g = rec.zones[i]
			if M.PinUsable(g) and g.c == c and g.z == z then
				here = g
				break
			end
		end
	end
	local n = 0
	if here then
		local w, h = btn:GetWidth(), btn:GetHeight()
		local count = getn(here.pins)
		if count > M.PIN_MAX then count = M.PIN_MAX end
		for i = 1, count do
			local p = M.PinFrame(i)
			if not p then
				M.pinRetry = true             -- pas de creation en combat : on reessaie des que possible
				break
			end
			local d = here.pins[i]
			p.data = d
			if p.kind ~= d.k then
				p.kind = d.k
				T.Backdrop(p, M.PinColor(d.k), T.c.bg)
				p.mark:SetText(M.PINMARK[d.k] or M.PINMARK.O)
			end
			p:ClearAllPoints()
			p:SetPoint("CENTER", btn, "TOPLEFT", d.x / 100 * w, -d.y / 100 * h)
			p:Show()
			n = i
		end
	end
	for i = n + 1, getn(M.pins) do M.pins[i]:Hide() end
	local b = M.PinBanner()
	if b then
		local text = M.PinBannerText(rec, here)
		if b.shownText ~= text then
			b.shownText = text
			T.SetButtonText(b, text)
		end
		b:Show()
	else
		M.pinRetry = true
	end
end

-- Un WORLD_MAP_UPDATE : seulement une date ; la pose a lieu quand la carte s'est tue pendant M.PIN_DELAY (aucun travail dans la rafale).
function M.PinOnMapEvent()
	if not M.pin then return end
	local wm = glob("WorldMapFrame")
	if not wm or not wm:IsShown() then return end
	M.pinStamp = GetTime()
	if not M.pinTask then M.pinTask = SUI.After(M.PIN_DELAY, M.PinSettle, "codex.pins") end
end

function M.PinSettle()
	M.pinTask = nil
	local left = (M.pinStamp or 0) + M.PIN_DELAY - GetTime()
	if left > 0.001 then
		M.pinTask = SUI.After(left, M.PinSettle, "codex.pins")
		return
	end
	M.PinRefresh()
end

-- Remet la carte sur la zone du joueur apres une fermeture (seulement si c'est nous qui l'avions deplacee)
function M.PinMapClosed()
	M.PinHideAll()
	if M.moved then
		M.moved = false
		local f = glob("SetMapToCurrentZone")
		if f then f() end
	end
end

-- Surveillance (0,5 s) : ouverture / fermeture de la carte, et reprise d'une pose bloquee par le combat.
function M.PinWatch()
	local wm = glob("WorldMapFrame")
	local shown = (wm and wm:IsShown()) and true or false
	if shown ~= M.mapShown then
		M.mapShown = shown
		if shown then M.PinOnMapEvent() else M.PinMapClosed() end
	elseif shown and M.pinRetry and M.pin and not SUI.InCombat() then
		M.PinOnMapEvent()
	end
	if not M.pin and not M.moved then M.PinStop(true) end
end

function M.PinStart()
	SUI.On("WORLD_MAP_UPDATE", M.PinOnMapEvent)
	if not M.pinWatch then
		local wm = glob("WorldMapFrame")
		M.mapShown = (wm and wm:IsShown()) and true or false
		M.pinWatch = SUI.Every(M.PIN_WATCH, M.PinWatch, "codex.pinwatch")
	end
	M.PinOnMapEvent()
end

-- Arret : evenement et attente annules ; la surveillance reste seulement si la carte attend sa remise sur la zone du joueur (force : jamais)
function M.PinStop(force)
	SUI.Off("WORLD_MAP_UPDATE", M.PinOnMapEvent)
	if M.pinTask then
		SUI.Cancel(M.pinTask)
		M.pinTask = nil
	end
	if M.pinWatch and (force or not M.moved) then
		SUI.Cancel(M.pinWatch)
		M.pinWatch = nil
	end
end

-- ---- commandes
-- Ouvre la carte (hors combat) sur la zone g
function M.PinShow(g)
	if SUI.InCombat() then return false end
	local wm, zoom, tog = glob("WorldMapFrame"), glob("SetMapZoom"), glob("ToggleWorldMap")
	if not wm or not zoom or not M.PinUsable(g) then return false end
	if not wm:IsShown() and tog then tog() end
	zoom(g.c, g.z)
	M.moved = true
	M.PinStart()
	M.mapShown = wm:IsShown() and true or false
	return true
end

-- Zone epinglable suivante (clic sur le bandeau)
function M.PinNext()
	local rec = M.pin
	if not rec then return end
	local c, z = M.MapCur()
	local list, at = {}, 0
	for i = 1, getn(rec.zones) do
		local g = rec.zones[i]
		if M.PinUsable(g) then
			tinsert(list, g)
			if g.c == c and g.z == z then at = getn(list) end
		end
	end
	if not list[1] then return end
	M.PinShow(list[at + 1] or list[1])
end

-- Epingle l'enregistrement rec (remplace la quete precedente)
function M.PinSet(rec)
	M.PinHideAll()
	M.pin = rec
	M.PinStore(M.PinClean(rec))
	M.PinStart()
end

-- Efface l'epingle (silent : sans message). La carte est remise sur la zone du joueur si elle est fermee, sinon a sa fermeture.
function M.PinOff(silent)
	local had = M.pin ~= nil
	M.pin = nil
	M.PinStore(nil)
	M.PinHideAll()
	local wm = glob("WorldMapFrame")
	if M.moved and not (wm and wm:IsShown()) then M.PinMapClosed() end
	M.PinStop(false)
	if not silent then SUI.Print(L(had and "msg.codex.pin.off" or "msg.codex.pin.nothing")) end
	return had
end

function M.PinQuestsReady()
	local ok, why = P.LoadQuests()
	M.qwhy = (not ok) and why or nil
	if not ok then SUI.Print(M.WhyText(P.QADDON, why)) end
	return ok
end

-- Epingle la quete `id` : resolution, messages (zones, zones sans carte, quete sans coordonnee), ouverture de la carte hors combat.
function M.PinQuest(id)
	if not M.on then
		SUI.Print(L("msg.codex.off"))
		return false
	end
	if not M.PinQuestsReady() then return false end
	local rec = M.PinBuild(id)
	if not rec then
		SUI.Print(L("msg.codex.pin.unknown", tostring(id)))
		return false
	end
	if rec.n == 0 then
		SUI.Print(L("msg.codex.pin.nocoord", rec.t))
		return false
	end
	local first = nil
	for i = 1, getn(rec.zones) do
		if not first and M.PinUsable(rec.zones[i]) then first = rec.zones[i] end
	end
	if not first then
		SUI.Print(L("msg.codex.pin.nomapall", rec.t, M.PinZoneList(rec)))
		return false
	end
	M.PinSet(rec)
	SUI.Print(L("msg.codex.pin.done", rec.t, M.PinZoneList(rec)))
	if SUI.InCombat() then
		SUI.Print(L("msg.codex.pin.combat"))
	else
		M.PinShow(first)
	end
	return true
end

-- Quete d'apres un numero ou un texte : numero connu, sinon titre exact, sinon titre contenant le texte ; plusieurs : liste (rien n'est devine).
function M.PinFindQuest(text)
	if not M.PinQuestsReady() then return nil end
	local qd = P.Q()
	local num = tonumber(text)
	if num and num == floor(num) and qd.q[num] then return num end
	local low = slower(text)
	local fr = lang() == "fr" and qd.fr.t or nil
	local hits, exact, titles = {}, {}, {}
	for id, en in pairs(qd.en.t) do
		local t = (fr and fr[id]) or en
		local lt = slower(t)
		if sfind(lt, low, 1, true) then
			titles[id] = t
			tinsert(hits, id)
			if lt == low then tinsert(exact, id) end
		end
	end
	local list = hits
	if exact[1] then list = exact end
	if not list[1] then
		SUI.Print(L("msg.codex.pin.nomatch", text))
		return nil
	end
	if not list[2] then return list[1] end
	tsort(list, function(x, y)
		if titles[x] ~= titles[y] then return titles[x] < titles[y] end
		return x < y
	end)
	local names = ""
	for i = 1, 5 do
		if list[i] then names = names .. (i > 1 and ", " or "") .. titles[list[i]] .. " [" .. list[i] .. "]" end
	end
	if list[6] then names = names .. ", ..." end
	SUI.Print(L("msg.codex.pin.many", getn(list), names))
	return nil
end

function M.PinStatus()
	local rec = M.pin
	if not rec then
		SUI.Print(L("msg.codex.pin.nothing"))
		return
	end
	SUI.Print(L("msg.codex.pin.status", rec.t, M.PinZoneList(rec)))
end

-- "pin" ou "pin <texte>" (casse ignoree) : vrai, argument ; sinon faux
function M.ParsePin(rest)
	if type(rest) ~= "string" then return false, "" end
	local _, _, w, arg = sfind(rest, "^%s*(%S+)%s*(.-)%s*$")
	if w and slower(w) == "pin" then return true, arg or "" end
	return false, ""
end

function M.PinIsOff(arg)
	arg = slower(arg or "")
	return arg == "off" or arg == "clear" or arg == "effacer"
end

-- Diagnostic (/sui codex pin debug) : etat interne des epingles, en une ou deux lignes de chat
function M.PinDebug()
	local rec = M.pin
	local wm, btn = glob("WorldMapFrame"), glob("WorldMapButton")
	local c, z = M.MapCur()
	local shown = 0
	for i = 1, getn(M.pins) do
		if M.pins[i]:IsShown() then shown = shown + 1 end
	end
	SUI.Print("pin=" .. tostring(rec and rec.id) .. " map=" .. tostring(wm and wm:IsShown()) .. " btn=" .. tostring(btn ~= nil)
		.. " cur=" .. tostring(c) .. "," .. tostring(z) .. " watch=" .. tostring(M.pinWatch ~= nil) .. " pool=" .. getn(M.pins)
		.. " shown=" .. shown .. " banner=" .. tostring(M.banner and M.banner:IsShown() or false) .. " refresh=" .. tostring(M.pinRefreshes)
		.. " retry=" .. tostring(M.pinRetry))
	if rec then
		for i = 1, getn(rec.zones) do
			local g = rec.zones[i]
			SUI.Print("zone " .. tostring(g.en) .. " map=" .. tostring(g.map) .. " res=" .. tostring(g.res) .. " c=" .. tostring(g.c)
				.. " z=" .. tostring(g.z) .. " n=" .. g.n .. " pins=" .. getn(g.pins)
				.. (g.pins[1] and (" p1=" .. g.pins[1].k .. g.pins[1].x .. "," .. g.pins[1].y) or ""))
		end
	end
end

function M.PinCommand(arg)
	if arg == "" then
		M.PinStatus()
	elseif slower(arg) == "debug" then
		M.PinDebug()
	elseif M.PinIsOff(arg) then
		M.PinOff()
	else
		local id = M.PinFindQuest(arg)
		if id then M.PinQuest(id) end
	end
end

-- Relecture de l'epingle du personnage (au chargement du module) : sans charger les donnees.
function M.PinRestore()
	local all = C.GetGlobal("codexpin")
	local rec = type(all) == "table" and M.PinClean(all[C.CharKey()]) or nil
	if rec then
		M.pin = rec
		M.PinStart()
	end
end

-- Bouton "Epingler" de la fenetre : la quete choisie dans la liste des resultats
function M.OnPinButton()
	local id = M.selQuest
	if not id then return end
	if M.pin and M.pin.id == id then M.PinOff() else M.PinQuest(id) end
	M.Paint()
end

-- Vrai si la quete choisie est une ligne de la chaine d'attunement affichee (onglet Donjons) : le bouton Epingler y sert aussi
function M.ChainSelected()
	if M.tab ~= "inst" or not M.selQuest then return false end
	for i = 1, getn(M.loots) do
		if M.loots[i].quest == M.selQuest then return true end
	end
	return false
end

-- Bouton et texte d'etat (onglet Recherche, a droite du champ de saisie ; onglet Donjons : en haut a droite, sur une quete de chaine)
function M.PaintPin()
	local w = M.win
	if not w or not w.pin then return end
	local search = M.tab == "search"
	local show = search or M.ChainSelected()
	local mode = search and "search" or "chain"
	if w.pin.mode ~= mode then
		w.pin.mode = mode
		w.pin:ClearAllPoints()
		if search then
			w.pin:SetPoint("LEFT", w.edit, "RIGHT", 8, 0)
		else
			w.pin:SetPoint("TOPLEFT", w.f, "TOPLEFT", M.W - 12 - 128, -38)
		end
	end
	if show and M.selQuest then
		local label = L((M.pin and M.pin.id == M.selQuest) and "msg.codex.pin.btnoff" or "msg.codex.pin.btn")
		if w.pin.shownText ~= label then
			w.pin.shownText = label
			T.SetButtonText(w.pin, label)
		end
		w.pin:Show()
	else
		w.pin:Hide()
	end
	if search and M.pin then
		w.pinInfo:SetText(L("msg.codex.pin.current", M.pin.t))
		w.pinInfo:Show()
	else
		w.pinInfo:Hide()
	end
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
	if M.bosses[i] and M.bosses[i].att then M.QuestsReady() end   -- niveaux et prerequis de la chaine : addon de quetes, charge a la demande
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

-- ---- onglet Reputations
function M.Reps()
	if not M.repList then M.repList = P.Reps() end
	return M.repList
end

function M.SelectRep(i)
	local rep = M.Reps()[i]
	M.sel.rep = rep and i or nil
	M.sel.tier = 1
	M.sel.ritem = nil
	M.off.tier, M.off.ritem = 0, 0
	M.repAll = rep and P.RepRows(rep.pg) or {}
	M.repTiers = P.TierCounts(M.repAll)
	M.repItems = M.repAll
end

-- Choisit la ligne de palier i (1 = tous les paliers, puis un rang de M.repTiers) et filtre les objets
function M.SelectTier(i)
	M.sel.tier = i
	M.sel.ritem = nil
	M.off.ritem = 0
	local t = i > 1 and M.repTiers[i - 1]
	if not t then
		M.repItems = M.repAll
		return
	end
	local out = {}
	for k = 1, getn(M.repAll) do
		if (M.repAll[k].tr or 0) == t.tier then tinsert(out, M.repAll[k]) end
	end
	M.repItems = out
end

-- Rang de la faction de page pg dans la liste (le camp du joueur d'abord quand la page sert aux deux camps), ou nil
function M.FindRep(pg)
	local fg = glob("UnitFactionGroup")
	local grp = fg and fg("player")
	local side = (grp == "Horde" and 2) or (grp == "Alliance" and 1) or nil
	local list = M.Reps()
	local first = nil
	for i = 1, getn(list) do
		if list[i].pg == pg then
			if not first then first = i end
			if list[i].side == nil or list[i].side == side then return i end
		end
	end
	return first
end

-- Aller a la faction de rang i (et a l'objet item s'il y en a un) : onglet Reputations, listes defilees pour montrer la selection.
function M.GoRepAt(i, item)
	if not M.Reps()[i] then return end
	M.tab = "rep"
	M.SelectRep(i)
	M.off.fac = i - 1
	clamp("fac", getn(M.Reps()))
	if item then
		for k = 1, getn(M.repItems) do
			if M.repItems[k].id == item then
				M.sel.ritem = item
				M.off.ritem = k - 1
				break
			end
		end
		clamp("ritem", getn(M.repItems))
	end
	if M.win then M.Paint() end
end

function M.GoRep(pg, item)
	local i = M.FindRep(pg)
	if i then M.GoRepAt(i, item) end
end

function M.Wheel(col, delta)
	local count = 0
	if col == "inst" then count = getn(M.Instances())
	elseif col == "boss" then count = getn(M.bosses)
	elseif col == "loot" then count = getn(M.loots)
	elseif col == "fac" then count = getn(M.Reps())
	elseif col == "tier" then count = getn(M.repTiers) + 1
	elseif col == "ritem" then count = getn(M.repItems)
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
	if b.chainRow then
		M.ChainTip(b)
	elseif id and GameTooltip then
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
		local bs = M.bosses[i]
		if bs and bs.rp then
			M.GoRep(bs.rp)           -- entree de reputation d'un donjon : lien vers l'onglet
			return
		end
		M.SelectBoss(i)
	elseif col == "fac" then
		M.SelectRep(i)
	elseif col == "tier" then
		M.SelectTier(i)
	elseif col == "ritem" then
		local r = M.repItems[i]
		if r then
			M.sel.ritem = r.id
			M.LinkItem(r.id)
		end
	elseif col == "loot" then
		local lt = M.loots[i]
		if lt and lt.quest then
			M.selQuest = lt.quest
			M.QuestsReady()
			local lvl, min = P.QuestLevels(lt.quest)
			M.QuestInfo({ id = lt.quest, title = lt.title, lvl = lvl, min = min })
		elseif lt then
			M.LinkItem(lt.id)
		end
	else
		local r = M.res[i]
		if not r then return end
		if r.kind == "item" and r.inst == 0 then
			M.GoRepAt(r.boss, r.id)
			return
		elseif r.kind == "item" then
			M.GoTo(r.inst, r.boss, r.id)
		else
			M.selQuest = r.id
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
		local rw = withRate == "wide" and M.RATEW or 46
		b.label:SetWidth(w - lx - (withRate and (rw + 4) or 4))
		b.label:SetHeight(12)
		b.label:SetJustifyH("LEFT")
		if withRate then
			b.rate = T.Text(b, 10, T.c.dim, "RIGHT")
			b.rate:SetPoint("RIGHT", b, "RIGHT", -4, 0)
			b.rate:SetWidth(rw)
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

local function setRow(b, text, selected, itemId, rate, shared, note, tier, tcol)
	b.chainRow, b.chainState, b.chainJournal = nil, nil, nil
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
	if b.rate then
		b.rate:SetText(tier or (M.RateText(rate) .. (shared and "*" or "")))
		local c = tcol or T.c.dim
		b.rate:SetTextColor(c[1], c[2], c[3], 1)
	end
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
		local bs = M.bosses[M.sel.boss or 0]
		if bs and bs.att then txt = L("msg.codex.attune.hint") end
	elseif M.tab == "rep" then
		txt = M.RepStatus()
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

-- Texte de la barre d'etat de l'onglet Reputations : palier actuel de la faction choisie, ou pourquoi il est inconnu
function M.RepStatus()
	local rep = M.Reps()[M.sel.rep or 0]
	if not rep then return L("msg.codex.rep.none") end
	local map = M.Standings()
	if not map then return L("msg.codex.rep.noapi") end
	local st = M.RepStanding(rep, map)
	if not st then return L("msg.codex.rep.unk", rep.name) end
	return L("msg.codex.rep.cur", rep.name, P.TierText(st) or "?") .. " " .. L("msg.codex.rep.legend")
end

-- Onglet Reputations : factions (palier actuel a droite), paliers presents ([x] atteint, [ ] manquant, [?] inconnu), objets du palier choisi
function M.PaintRep()
	local w = M.win
	w.cInst:Hide() w.cBoss:Hide() w.cLoot:Hide() w.edit:Hide() w.cRes:Hide() w.cRep:Show()
	local list = M.Reps()
	if not list[M.sel.rep or 0] then
		if list[1] then
			M.SelectRep(1)
		else
			M.sel.rep, M.repAll, M.repTiers, M.repItems = nil, {}, {}, {}
		end
	end
	clamp("fac", getn(list))
	clamp("tier", getn(M.repTiers) + 1)
	clamp("ritem", getn(M.repItems))
	local map = M.Standings()
	local cur = M.RepStanding(list[M.sel.rep or 0], map)
	for i = 1, M.NROWS do
		local k = i + M.off.fac
		local f = list[k]
		if f then
			local fst = M.RepStanding(f, map)
			local name = f.name
			if f.side then name = name .. " (" .. M.SideText(f.side) .. ")" end
			setRow(w.rFac[i], name, M.sel.rep == k, nil, nil, nil, nil, fst and P.TierText(fst) or "?", fst and T.c.text or T.c.dim)
		else
			setRow(w.rFac[i], nil)
		end
		k = i + M.off.tier
		local text, mark, col = nil, nil, nil
		if k == 1 then
			text = L("msg.codex.rep.all", getn(M.repAll))
		elseif M.repTiers[k - 1] then
			local tt = M.repTiers[k - 1]
			if tt.tier == 0 then
				text = L("msg.codex.rep.notier", tt.n)
			else
				text = (P.TierText(tt.tier) or "?") .. " (" .. tt.n .. ")"
				mark, col = M.TierMark(cur, tt.tier)
			end
		end
		if M.sel.rep == nil then text = nil end
		setRow(w.rTier[i], text, M.sel.tier == k, nil, nil, nil, nil, mark or "", col)
		local r = M.repItems[i + M.off.ritem]
		if r then
			local m, c = M.TierMark(cur, r.tr)
			setRow(w.rRepItem[i], M.ItemName(r.id), r.id == M.sel.ritem, r.id, nil, r.shared, r.note, m and (m .. " " .. (r.tier or "")) or "", c)
			M.QualityColor(w.rRepItem[i], r.id)
		else
			setRow(w.rRepItem[i], nil)
		end
	end
	T.SetSelected(w.tabInst, false)
	T.SetSelected(w.tabRep, true)
	T.SetSelected(w.tabSearch, false)
	M.PaintPin()
	M.PaintStatus()
end

function M.Paint()
	local w = M.win
	if not w then return end
	if M.tab == "rep" then
		M.PaintRep()
		return
	end
	w.cRep:Hide()
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
		local jr = nil           -- journal de quetes : lu une fois par repeinture, seulement si une chaine est affichee (false = illisible)
		for i = 1, M.NROWS do
			local k = i + M.off.inst
			local it = insts[k]
			setRow(w.rInst[i], it and (it.name .. "  (" .. sformat(L("msg.codex.level"), M.LevelText(it)) .. ")") or nil, M.sel.inst == k)
			local bk = i + M.off.boss
			local bs = M.bosses[bk]
			setRow(w.rBoss[i], bs and bs.name or nil, M.sel.boss == bk)
			local lk = i + M.off.loot
			local lt = M.loots[lk]
			local ltext = nil
			local lsel = false
			local ctext, ccol, cst
			if lt and lt.quest then
				ltext = lt.step .. ". " .. lt.title
				lsel = lt.quest == M.selQuest
				if jr == nil then jr = M.Journal() or false end
				ctext, ccol, cst = M.ChainInfo(lt, jr or nil)
			elseif lt then
				ltext = M.ItemName(lt.id)
				lsel = lt.id == M.sel.item
			end
			setRow(w.rLoot[i], ltext, lsel, lt and lt.id, lt and lt.rate, lt and lt.shared, lt and lt.note, (lt and lt.tier) or ctext, ccol)
			if lt and lt.quest then
				w.rLoot[i].chainRow, w.rLoot[i].chainState, w.rLoot[i].chainJournal = lt, cst, jr or nil
			elseif lt then
				M.QualityColor(w.rLoot[i], lt.id)
			end
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
					if r.inst == 0 then
						local rp = M.Reps()[r.boss]
						txt = M.ItemName(r.id) .. "   -   " .. L("msg.codex.rep.entry", rp and rp.name or "?")
					end
				else
					txt = "[" .. L("msg.codex.quest") .. "] " .. r.title .. "  (" .. sformat(L("msg.codex.level"), tostring(r.lvl or "?")) .. ")"
				end
				local chosen = r.kind == "quest" and r.id == M.selQuest
				setRow(w.rRes[i], txt, chosen, r.kind == "item" and r.id or nil)
				if r.kind == "item" then M.QualityColor(w.rRes[i], r.id) elseif not chosen then w.rRes[i].label:SetTextColor(T.c.text[1], T.c.text[2], T.c.text[3], 1) end
			else
				setRow(w.rRes[i], nil)
			end
		end
	end
	T.SetSelected(w.tabInst, inst)
	T.SetSelected(w.tabRep, false)
	T.SetSelected(w.tabSearch, not inst)
	M.PaintPin()
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
	w.prof:SetWidth(280)
	w.prof:SetHeight(12)
	w.tabInst = T.Button(f, L("msg.codex.tab.inst"), 84, 22, function() M.SetTab("inst") end)
	w.tabInst:SetPoint("TOPLEFT", f, "TOPLEFT", 90, -8)
	w.tabRep = T.Button(f, L("msg.codex.tab.rep"), 84, 22, function() M.SetTab("rep") end)
	w.tabRep:SetPoint("LEFT", w.tabInst, "RIGHT", 6, 0)
	w.tabSearch = T.Button(f, L("msg.codex.tab.search"), 84, 22, function() M.SetTab("search") end)
	w.tabSearch:SetPoint("LEFT", w.tabRep, "RIGHT", 6, 0)

	local top = -66
	w.cInst = CreateFrame("Frame", nil, f)
	w.cInst:SetAllPoints(f)
	w.cBoss = CreateFrame("Frame", nil, f)
	w.cBoss:SetAllPoints(f)
	w.cLoot = CreateFrame("Frame", nil, f)
	w.cLoot:SetAllPoints(f)
	w.cRes = CreateFrame("Frame", nil, f)
	w.cRes:SetAllPoints(f)
	w.cRep = CreateFrame("Frame", nil, f)
	w.cRep:SetAllPoints(f)
	w.cRep:Hide()
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
	local g1 = T.Text(w.cRep, 11, T.c.dim, "LEFT")
	g1:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -44)
	g1:SetText(L("msg.codex.col.fac"))
	local g2 = T.Text(w.cRep, 11, T.c.dim, "LEFT")
	g2:SetPoint("TOPLEFT", f, "TOPLEFT", 218, -44)
	g2:SetText(L("msg.codex.col.tier"))
	local g3 = T.Text(w.cRep, 11, T.c.dim, "LEFT")
	g3:SetPoint("TOPLEFT", f, "TOPLEFT", 398, -44)
	g3:SetText(L("msg.codex.col.ritem"))
	w.rFac = M.MakeRows(w.cRep, "fac", 12, top, 200, false, "wide")
	w.rTier = M.MakeRows(w.cRep, "tier", 218, top, 174, false, true)
	w.rRepItem = M.MakeRows(w.cRep, "ritem", 398, top, 240, true, "wide")

	w.edit = T.Edit(f, 300, 22)
	w.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
	w.edit:SetScript("OnTextChanged", M.OnSearchText)
	w.edit:SetScript("OnEnterPressed", function() this:ClearFocus() M.Search(this:GetText()) end)
	w.edit:Hide()
	w.pin = T.Button(f, L("msg.codex.pin.btn"), 128, 22, function() M.OnPinButton() end)
	w.pin:SetPoint("LEFT", w.edit, "RIGHT", 8, 0)
	w.pin:Hide()
	w.pinInfo = T.Text(f, 10, T.c.dim, "LEFT")
	w.pinInfo:SetPoint("LEFT", w.pin, "RIGHT", 8, 0)
	w.pinInfo:SetWidth(180)
	w.pinInfo:SetHeight(12)
	w.pinInfo:Hide()
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
	M.repList = nil
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
	M.repList = nil
	M.repAll, M.repTiers, M.repItems = {}, {}, {}
	M.sel.rep, M.sel.tier, M.sel.ritem = nil, nil, nil
	M.off.fac, M.off.tier, M.off.ritem = 0, 0, 0
	P.bitv = nil
	M.ReleaseIndex()
	M.sel.inst, M.sel.boss, M.sel.item = nil, nil, nil
	M.bosses, M.loots, M.res = {}, {}, {}
	M.off.res, M.more = 0, false
	M.selQuest = nil
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
	M.PinRestore()
end

function M.Disable()
	M.on = false
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombat)
	if M.searchTask then SUI.Cancel(M.searchTask) M.searchTask = nil end
	if M.warmTask then SUI.Cancel(M.warmTask) M.warmTask = nil end
	M.ReleaseIndex()
	M.Close()
	M.PinOff(true)
	M.PinStop(true)
	M.moved = false
	M.mapIdx = nil
	M.selQuest = nil
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

-- /sui codex [texte] ; /sui codex pin <numero ou titre de quete> ; /sui codex pin off ; /sui codex pin (ce qui est epingle)
function M.Command(rest)
	local isPin, arg = M.ParsePin(rest)
	if isPin and M.PinIsOff(arg) and not C.Get("modules.codex") then
		SUI.Print(L("msg.codex.pin.nothing"))
		return
	end
	if not C.Get("modules.codex") then C.Set("modules.codex", true) end
	if isPin then
		M.PinCommand(arg)
	else
		M.Toggle(rest)
	end
end

SUI.RegisterCommand("codex", function(rest) M.Command(rest) end, "help.codex")
