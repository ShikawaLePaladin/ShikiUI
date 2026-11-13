-- ShikiUI Group : cadres de groupe (5), ennemis epingles (boss / arene) et MOTEUR partage des cadres de groupe (SUI.GroupEngine,
-- utilise aussi par le module "raid" : il ne sert que A L'EXECUTION, jamais au chargement, donc aucune dependance d'ordre de fichiers).
-- Cout declare : MEDIUM (groupe) ; le moteur est ecrit pour 40 cadres (voir Mod_Raid.lua : HEAVY).
--
-- PERFORMANCE (raid 40 d'abord)
--   * un evenement UNIT_* ne touche que SON cadre (table unite -> cadre), il pose un drapeau (dH vie, dP puissance, dA auras, dI infos) et
--     range le cadre dans une file circulaire PREALLOUEE ; une minuterie partagee (SUI.Every) vide la file avec un BUDGET par passage ;
--   * une seconde minuterie fait un tour de "lent" en rotation (portee, mort / hors ligne, aggro Banzai, soins entrants HealComm) sur
--     quelques cadres par passage ; sans UnitXP / SuperWoW la portee retombe sur les tranches 1.12 (CheckInteractDistance : <=28 yd) ;
--   * aucune table ni frame creee en combat : les cadres sont construits UNE fois (SUI.WhenSafe), tout le reste ecrit dans des champs
--     existants ; un texte n'est reecrit que s'il change ; les evenements inutiles (puissance, auras) ne sont pas ecoutes si l'option
--     correspondante est a zero ; un module desactive n'ecoute rien et n'a aucune minuterie.
-- SOURCES (relevees dans les addons installes, rien n'est copie) : evenements UNIT_HEALTH / UNIT_MAXHEALTH / UNIT_MANA... / UNIT_AURA /
--   UNIT_FLAGS / UNIT_NAME_UPDATE / RAID_ROSTER_UPDATE / PARTY_MEMBERS_CHANGED / PARTY_LEADER_CHANGED / PARTY_MEMBER_ENABLE / _DISABLE /
--   RAID_TARGET_UPDATE / SPELLS_CHANGED (pfUI api/unitframes.lua, Puppeteer core/EventHandler.lua) ; UnitDebuff(unit, i) -> texture,
--   applications, type (Puppeteer libs/PTUnit.lua, Rinse.lua) ; sorts de dissipation par classe (Puppeteer PuppeteerSettings.lua, Rinse.lua) ;
--   HealComm-1.0 (AceLibrary) getHeal(NOM) et Banzai-1.0 GetUnitAggroByUnitId(unite) (Puppeteer) ; GetRaidRosterInfo(i) -> nom, rang,
--   sous-groupe, niveau, classe, fichier-classe, zone, en ligne, mort ; GetRaidTargetIndex / SetRaidTargetIconTexture (Puppeteer, pfUI) ;
--   PlaySoundFile("Sound\\Interface\\RaidWarning.wav") (DebuffAlert) ; cadres Blizzard "PartyMemberFrame1..4" masques comme pfUI le fait.
-- NON VERIFIE EN JEU : TOUT (aucun de ces evenements / appels n'a tourne dans le client par ce projet) ; en particulier : les jetons
--   d'unite recus en raid (raidN et/ou player pour soi), PARTY_MEMBER_* (argument), le texte exact des types de debuff selon la langue
--   du client (comparaison anglaise : Magic / Curse / Poison / Disease), UnitIsVisible, GetRaidTargetIndex, l'usage d'un GUID SuperWoW
--   comme jeton d'unite pour les ennemis epingles (UnitHealth(guid), TargetUnit(guid)), le menu contextuel des cadres de raid.
-- AJOUTS (2e passe) : HoT / boucliers du joueur avec duree (hots), type de debuff a dissiper avec priorite et teinte du cadre
--   (dispelprio / dispelstyle), resurrection en cours (resinfo), soins entrants via Puppeteer (PTHealPredict) a defaut de HealComm.
--   Duree des HoT : sorts lances par le joueur uniquement (UNIT_CASTEVENT SuperWoW, sinon relevee par Mod_ClickHeal) ; sur le cadre du
--   joueur le temps restant vient de GetPlayerBuffTimeLeft. Durees de base ([memoire], non relevees dans un addon) : voir E.HOTS.
-- AJOUTS (3e passe) : MES soins en cours (barre de soin entrant sans addon) : SPELLCAST_START / STOP / FAILED / INTERRUPTED + nom du sort ->
--   montant estime (E.HEALS, rang du grimoire, GetSpellBonusHealing si le client l'offre) ; cible = lancement annonce par Mod_ClickHeal
--   (E.NoteCast), sinon GUID SuperWoW (UNIT_CASTEVENT), sinon cible amie du jeu, sinon soi-meme. Reglage <prefixe>incsrc : me / all (all : le plus
--   grand de HealComm / Puppeteer et de mon estimation, jamais la somme). Noms de sorts anglais + francais (a verifier en jeu).
-- Roles : aucune API 1.12 ne les donne ; ils viennent d'une liste manuelle (/sui group role) ou, en option, d'une devinette par classe.
-- "Aggro" = a defaut de Banzai : l'unite visee par la CIBLE du joueur (cible hostile -> cible de la cible), pas une vraie menace.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, tinsert = table.getn, table.insert
local floor, ceil = math.floor, math.ceil
local sfind, ssub, slen, sbyte, sformat = string.find, string.sub, string.len, string.byte, string.format

local E = {}
SUI.GroupEngine = E
local M = {}
SUI.Group = M

local FLUSH = 0.1             -- secondes entre deux vidages de la file (doublees en mode urgence)
local SLOW = 0.25             -- secondes entre deux tours "lents"
local MAXAUR = 16             -- 1.12 : 16 debuffs lisibles

-- ---------------------------------------------------------------- donnees du JEU (pas du style)
-- Couleurs des types de debuff (DebuffTypeColor de FrameXML ; memes valeurs dans Rinse) : donnees de jeu.
E.DEBUFF_COL = {
	Magic = { 0.20, 0.60, 1.00 },    -- style:ok donnee de jeu (type de debuff)
	Curse = { 0.60, 0.00, 1.00 },    -- style:ok donnee de jeu (type de debuff)
	Disease = { 0.60, 0.40, 0.00 },  -- style:ok donnee de jeu (type de debuff)
	Poison = { 0.00, 0.60, 0.00 },   -- style:ok donnee de jeu (type de debuff)
}
-- Couleurs de ressource (mana, rage, focus, energie) : donnees de jeu.
E.POWER_COL = {
	[0] = { 0.25, 0.45, 0.95 },      -- style:ok donnee de jeu (ressource)
	[1] = { 0.85, 0.22, 0.22 },      -- style:ok donnee de jeu (ressource)
	[2] = { 0.90, 0.50, 0.20 },      -- style:ok donnee de jeu (ressource)
	[3] = { 0.95, 0.85, 0.25 },      -- style:ok donnee de jeu (ressource)
}
-- Sorts de dissipation et types qu'ils retirent (Puppeteer PuppeteerSettings.lua, Rinse.lua). Noms anglais du client.
E.CURES = {
	["Cleanse"] = { Poison = true, Disease = true, Magic = true },
	["Purify"] = { Poison = true, Disease = true },
	["Cure Disease"] = { Disease = true },
	["Abolish Disease"] = { Disease = true },
	["Dispel Magic"] = { Magic = true },
	["Cure Poison"] = { Poison = true },
	["Abolish Poison"] = { Poison = true },
	["Remove Curse"] = { Curse = true },
	["Remove Lesser Curse"] = { Curse = true },
}
-- Ordre de base des types a dissiper (le type choisi par l'option dispelprio passe en premier).
E.PRIO_BASE = { "Magic", "Curse", "Poison", "Disease" }
E.PRIO_KEY = { magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease" }
-- HoT / boucliers suivis sur les allies : nom du sort -> duree de base en secondes ([memoire] : Rejuvenation 12, Regrowth 21, Renew 15,
-- Power Word: Shield 30, Abolish 8 ; seul le texte de duree en depend, l'icone vient de l'aura reelle).
E.HOTS = { ["Rejuvenation"] = 12, ["Regrowth"] = 21, ["Renew"] = 15, ["Power Word: Shield"] = 30, ["Abolish Poison"] = 8,
	["Abolish Disease"] = 8 }
-- Resurrections par nom de sort (releve dans HealPredict.lua de Puppeteer).
E.RES = { ["Resurrection"] = true, ["Redemption"] = true, ["Ancestral Spirit"] = true, ["Rebirth"] = true, ["Revive Champion"] = true }
E.CLASS_RANK = { WARRIOR = 1, PALADIN = 2, DRUID = 3, PRIEST = 4, SHAMAN = 5, ROGUE = 6, HUNTER = 7, MAGE = 8, WARLOCK = 9 }
E.ROLE_RANK = { T = 1, H = 2, D = 3 }
-- Devinette par classe (option roleguess = class) : seulement les classes sans ambiguite RELATIVE ; les hybrides restent sans role.
E.GUESS = { PRIEST = "H", MAGE = "D", WARLOCK = "D", ROGUE = "D", HUNTER = "D" }
-- Barre de mana (option manabar) : classes a mana. Soigneurs = classes qui soignent ; lanceurs = toutes les classes a mana (le chasseur
-- seulement si l'option manahunter est cochee). Un role manuel H force la barre ; T / D la retirent en mode "soigneurs".
E.HEALER_CLASS = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }
E.CASTER_CLASS = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true, MAGE = true, WARLOCK = true }
E.SOUND_ALERT = "Sound\\Interface\\RaidWarning.wav"   -- releve dans DebuffAlert.lua

local MAXBUF = 32            -- buffs lus pour reperer les HoT
local RESN = 6               -- resurrections suivies en meme temps
E.hotEnd = {}                -- sort -> { [nom] = fin (GetTime) } : tables creees une fois
for sp in pairs(E.HOTS) do E.hotEnd[sp] = {} end
E.hotTex = {}                -- texture -> nom du sort (releve dans le grimoire)
E.res = {}                   -- resurrections en cours : { c = lanceur, t = cible, u = fin }
for i = 1, RESN do E.res[i] = { c = "", t = "", u = 0 } end
E.NUM = {}                   -- "0".."99" precalcules (aucune chaine creee au rafraichissement)
for i = 0, 99 do E.NUM[i] = tostring(i) end
E.idName = {}                -- cache identifiant de sort -> nom (SuperWoW SpellInfo)
E.idN = 0

local PU = { "player", "party1", "party2", "party3", "party4", "pet", "partypet1", "partypet2", "partypet3", "partypet4" }
local RU = {}
for i = 1, 40 do RU[i] = "raid" .. i end
E.RAID_UNITS = RU

-- Valeurs de repli quand un module n'a pas declare une cle (le moteur sert au groupe, au raid et aux ennemis epingles).
E.CFGKEYS = { solo = false, hideinraid = true, pets = false, maxgroup = 8, width = 100, height = 34, powerheight = 4, spacing = 2,
	groupgap = 6, sort = "none", orient = "vertical", perline = 5, hpcolor = "class", hptext = "percent", namelen = 10, range = true,
	rangeyd = 40, outalpha = 0.45, debuffs = 3, buffs = 0, iconsize = 12, dispelmode = "known", dispelonly = false, aggro = true,
	incoming = true, incsrc = "all", roletag = true, leader = true, marks = true, target = true, tooltip = true, alerts = true, alertsound = "none",
	alertlist = "", roles = "", roleguess = "none", budget = 10, slowstep = 10, hots = 0, hotall = false, dispelstyle = "both",
	dispelprio = "magic", resinfo = true, manabar = "all", manahunter = false, manatext = false }

E.alertHooks = {}         -- fonctions fn(instance, unite, fragment, texture) : point d'entree du futur DebuffAlert configurable
E.cure = {}               -- type de debuff -> true : ce que le joueur sait dissiper (grimoire)
E.instances = {}

-- ---------------------------------------------------------------- utilitaires
-- Remplit 'out' (tableau reutilise) avec les mots separes par ';' ; renvoie leur nombre. Aucune nouvelle table.
function E.ParseList(str, out)
	for i = getn(out), 1, -1 do out[i] = nil end
	local n = 0
	for w in string.gfind(str or "", "[^;]+") do
		local _, _, t = sfind(w, "^%s*(.-)%s*$")
		if t and t ~= "" then
			n = n + 1
			out[n] = t
		end
	end
	return n
end

-- "Nom:T;Nom2:H" -> map[nom] = "T" | "H" | "D" (table reutilisee)
function E.ParseRoles(str, map)
	for k in pairs(map) do map[k] = nil end
	for w in string.gfind(str or "", "[^;]+") do
		local _, _, nm, r = sfind(w, "^%s*(.-)%s*:%s*([THDthd])%s*$")
		if nm and nm ~= "" then map[nm] = string.upper(r) end
	end
end

-- Lit le grimoire : quels types de debuff le joueur peut-il dissiper ? (hors combat ou non : lecture seule, aucune table creee)
function E.ScanCures()
	for k in pairs(E.cure) do E.cure[k] = nil end
	for k in pairs(E.hotTex) do E.hotTex[k] = nil end
	local gn = getglobal("GetSpellName")
	if not gn then return end
	local gt = getglobal("GetSpellTexture")
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	for i = 1, 1000 do
		local name = gn(i, book)
		if not name then break end
		local types = E.CURES[name]
		if types then
			for ty in pairs(types) do E.cure[ty] = true end
		end
		if gt and E.HOTS[name] then
			local ok, tx = pcall(gt, i, book)
			if ok and tx then E.hotTex[tx] = name end
		end
	end
end

local function abbrev(n)
	if n >= 1000000 then return sformat("%.1fm", n / 1000000) end
	if n >= 10000 then return sformat("%.0fk", n / 1000) end
	if n >= 1000 then return sformat("%.1fk", n / 1000) end
	return tostring(floor(n))
end

-- Texte de vie. pctOnly : unites hostiles (en 1.12 leur vie est un pourcentage, maximum 100).
function E.HpText(mode, hp, mx, pctOnly)
	if mode == "none" then return "" end
	local pct = (mx > 0) and floor(hp / mx * 100 + 0.5) or 0
	if pctOnly or mx == 100 then return pct .. "%" end
	if mode == "value" then return abbrev(hp) end
	if mode == "percent" then return pct .. "%" end
	if mode == "deficit" then
		if mx - hp > 0 then return "-" .. abbrev(mx - hp) end
		return ""
	end
	return abbrev(hp) .. " | " .. pct .. "%"
end

-- Coupe un nom a n octets sans couper un caractere UTF-8 en deux.
function E.Cut(name, n)
	if slen(name) <= n then return name end
	local b = sbyte(name, n + 1)
	while n > 0 and b and b >= 128 and b < 192 do
		n = n - 1
		b = sbyte(name, n + 1)
	end
	return ssub(name, 1, n)
end

-- ---------------------------------------------------------------- instance
-- def : { name, title, prefix, kind = "party" | "raid" | "pins", max, maxDeb, maxBuf, layoutKey, defX, defY, after = fn(g) }
function E.New(def)
	local g = { name = def.name, title = def.title or def.name, prefix = def.prefix, kind = def.kind, max = def.max, maxDeb = def.maxDeb,
		maxBuf = def.maxBuf, layoutKey = def.layoutKey, defX = def.defX, defY = def.defY, after = def.after, cfg = {}, frames = {},
		byUnit = {}, names = {}, order = {}, nOrder = 0, q = {}, qh = 1, qt = 1, qn = 0, rr = 1, built = false, active = false,
		rosterDirty = true, arrangeDirty = true, evOn = {}, alerts = {}, nAlerts = 0, roles = {}, pins = {}, nPins = 0,
		slowInterval = def.slowInterval or SLOW, tags = {}, sig = "", maxHot = def.maxHot or 0, dprio = {} }
	g.cap = g.max + 2
	g.fnFlush = function() E.Flush(g) end
	g.fnSlow = function() E.Slow(g) end
	g.hUnit = function(ev, a1)
		local f = g.byUnit[a1]
		if not f or not f.vis then return end
		local k = E.EVFLAG[ev]
		if not k then return end
		f[k] = true
		if not f.inq then E.Push(g, f) end
	end
	g.hRoster = function() g.rosterDirty = true end
	g.hTarget = function() E.OnTarget(g) end
	g.hMarks = function() E.UpdateMarks(g) end
	g.hMember = function(ev, a1)
		if a1 and g.byUnit[a1] then g.hUnit(ev, a1) else g.rosterDirty = true end
	end
	g.fnHot = function() E.TickHots(g) end
	g.hSpells = function()
		E.ScanCures()
		if E.wantInc then E.ScanHeals() end
		E.MarkAll(g, "dA")
		-- respec : le grimoire n'est complet qu'apres la rafale d'evenements ; second passage 2 s plus tard (le premier suffisait mal)
		if g.bookTask then SUI.Cancel(g.bookTask) end
		g.bookTask = SUI.After(2, function()
			g.bookTask = nil
			if not g.active then return end
			E.ScanCures()
			if E.wantInc then E.ScanHeals() end
			E.MarkAll(g, "dA")
		end, g.title .. ".book")
	end
	tinsert(E.instances, g)
	return g
end

E.EVFLAG = { UNIT_HEALTH = "dH", UNIT_MAXHEALTH = "dH", UNIT_MANA = "dP", UNIT_MAXMANA = "dP", UNIT_RAGE = "dP", UNIT_MAXRAGE = "dP",
	UNIT_ENERGY = "dP", UNIT_MAXENERGY = "dP", UNIT_FOCUS = "dP", UNIT_MAXFOCUS = "dP", UNIT_DISPLAYPOWER = "dP", UNIT_AURA = "dA",
	UNIT_NAME_UPDATE = "dI", UNIT_FLAGS = "dI", PARTY_MEMBER_ENABLE = "dH", PARTY_MEMBER_DISABLE = "dH" }

-- Lit les reglages "<prefixe>cle" (repli : E.CFGKEYS) et prepare les listes derivees (alertes, roles, textes de role).
function E.ReadConfig(g)
	local cfg = g.cfg
	for k, d in pairs(E.CFGKEYS) do
		local key = g.prefix .. k
		if C.meta[key] ~= nil then cfg[k] = C.Get(key) else cfg[k] = d end
	end
	if g.after then g.after(g) end
	if cfg.alertlist ~= g.alertRaw then
		g.alertRaw = cfg.alertlist
		g.nAlerts = E.ParseList(cfg.alertlist, g.alerts)
	end
	if cfg.roles ~= g.rolesRaw then
		g.rolesRaw = cfg.roles
		E.ParseRoles(cfg.roles, g.roles)
	end
	g.tags.T = L("msg." .. g.name .. ".role.t")
	g.tags.H = L("msg." .. g.name .. ".role.h")
	g.tags.D = ""
	g.tags.R = L("msg." .. g.name .. ".res")
	-- priorite des types a dissiper : le type choisi d'abord, puis l'ordre de base (table reutilisee)
	local first = E.PRIO_KEY[cfg.dispelprio] or "Magic"
	local rk = 1
	g.dprio[first] = rk
	for i = 1, getn(E.PRIO_BASE) do
		local ty = E.PRIO_BASE[i]
		if ty ~= first then
			rk = rk + 1
			g.dprio[ty] = rk
		end
	end
	E.ResolveSources(g)
end

-- Banzai / HealComm / Puppeteer : optionnels (AceLibrary / PTHealPredict presents ?), relus ici puis toutes les 5 s tant qu'il en manque
-- (un addon charge apres ShikiUI est alors repris sans /reload).
function E.ResolveSources(g)
	local cfg = g.cfg
	g.HC, g.banzai, g.PT = nil, nil, nil
	local AL = getglobal("AceLibrary")
	if AL and AL.HasInstance then
		if (cfg.incoming or cfg.resinfo) and AL:HasInstance("HealComm-1.0") then g.HC = AL("HealComm-1.0") end
		if cfg.aggro and AL:HasInstance("Banzai-1.0") then g.banzai = AL("Banzai-1.0") end
	end
	if g.HC and type(g.HC.getHeal) ~= "function" then g.HC = nil end
	if g.banzai and type(g.banzai.GetUnitAggroByUnitId) ~= "function" then g.banzai = nil end
	local pt = getglobal("PTHealPredict")
	if cfg.incoming and not g.HC and SUI.Api.superwow and type(pt) == "table" and type(pt.getHeal) == "function" then g.PT = pt end
end

-- ---------------------------------------------------------------- file des cadres a mettre a jour (circulaire, preallouee)
function E.Push(g, f)
	if f.inq then return end
	f.inq = true
	g.q[g.qt] = f
	g.qt = g.qt + 1
	if g.qt > g.cap then g.qt = 1 end
	g.qn = g.qn + 1
end

local function pop(g)
	local f = g.q[g.qh]
	g.q[g.qh] = false
	g.qh = g.qh + 1
	if g.qh > g.cap then g.qh = 1 end
	g.qn = g.qn - 1
	f.inq = false
	return f
end

function E.MarkAll(g, flag)
	for i = 1, g.nOrder do
		local f = g.order[i]
		f[flag] = true
		E.Push(g, f)
	end
end

-- ---------------------------------------------------------------- infos d'un cadre (nom, classe, role, sous-groupe)
function E.Info(g, f)
	local unit, cfg = f.unit, g.cfg
	local name = UnitName(unit) or ""
	local _, class = UnitClass(unit)
	local oName, oClass, oSub, oRole = f.name, f.class, f.sub, f.role
	f.name, f.class = name, class
	f.isPlayer = UnitIsPlayer(unit) and true or false
	f.guid = nil
	if SUI.Api.superwow then
		local _, gd = UnitExists(unit)
		f.guid = gd
	end
	f.isSelf = (UnitIsUnit(unit, "player") and true) or false
	f.classRank = E.CLASS_RANK[class] or 99
	local role = g.roles[name]
	if not role and cfg.roleguess == "class" then role = E.GUESS[class] end
	f.role = role
	f.roleRank = E.ROLE_RANK[role or "D"]
	if g.kind == "raid" then
		local _, rank, sub = GetRaidRosterInfo(f.idx)
		f.rank = rank or 0
		f.sub = sub or 1
	elseif g.kind == "party" then
		f.sub = 1
		f.rank = (UnitIsPartyLeader(unit) and 2) or 0
	else
		f.sub = 1
		f.rank = 0
	end
	if name ~= oName or class ~= oClass or f.sub ~= oSub or role ~= oRole then g.arrangeDirty = true end
end

function E.UpdateName(g, f)
	local cfg = g.cfg
	local nm = E.Cut(f.name, cfg.namelen)
	if nm ~= f.nameShown then
		f.nameShown = nm
		f.nameText:SetText(nm)
	end
	local tag = ""
	if cfg.roletag and f.role then tag = g.tags[f.role] or "" end
	if cfg.leader then
		if f.rank == 2 then tag = tag .. "*" elseif f.rank == 1 and g.kind == "raid" then tag = tag .. "+" end
	end
	if tag ~= f.tagShown then
		f.tagShown = tag
		f.tagText:SetText(tag)
	end
end

function E.UpdateMark(g, f)
	local mk = f.mark
	local idx = nil
	if g.cfg.marks and g.kind ~= "pins" then idx = GetRaidTargetIndex(f.unit) end
	if idx ~= f.markIdx then
		f.markIdx = idx
		if idx then
			local fn = getglobal("SetRaidTargetIconTexture")
			if fn then fn(mk, idx) end
			mk:Show()
		else
			mk:Hide()
		end
	end
end

function E.UpdateMarks(g)
	for i = 1, g.nOrder do E.UpdateMark(g, g.order[i]) end
end

-- ---------------------------------------------------------------- couleurs
function E.HpColor(g, f, ratio)
	local mode = g.cfg.hpcolor
	if f.state ~= 0 then
		local c = T.c.dim
		return c[1], c[2], c[3]
	end
	if g.kind == "pins" and not f.isPlayer then
		local c = T.c.bad
		return c[1], c[2], c[3]
	end
	if mode == "class" then
		local col = f.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[f.class]
		if col then return col.r, col.g, col.b end    -- style:ok couleur de classe (donnee de jeu)
	elseif mode == "health" then
		local a, b, t
		if ratio > 0.5 then
			a, b, t = T.c.good, T.c.warn, (1 - ratio) * 2
		else
			a, b, t = T.c.warn, T.c.bad, (0.5 - ratio) * 2
		end
		return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
	end
	local c = T.c.good
	return c[1], c[2], c[3]
end

function E.ApplyAlpha(g, f)
	local a = 1
	if f.state ~= 0 or f.inRange == false then a = g.cfg.outalpha end
	if a ~= f.alphaNow then
		f.alphaNow = a
		f:SetAlpha(a)
	end
end

-- Surbrillance : alerte (rouge) > aggro (orange) > cible (accent). Se repeint aussi au changement de style (voir Build).
function E.PaintState(g, f)
	local cfg = g.cfg
	local r, gg, b, a
	local kind = 0
	if f.alertTex then
		kind = 3
		r, gg, b, a = T.c.bad[1], T.c.bad[2], T.c.bad[3], 0.35
	elseif f.aggro and cfg.aggro then
		kind = 2
		r, gg, b, a = T.c.warn[1], T.c.warn[2], T.c.warn[3], 0.30
	elseif f.isTarget and cfg.target then
		kind = 1
		r, gg, b = T.Accent()
		a = 0.22
	end
	f.kind = kind
	if kind == 0 then
		f.hl:Hide()
		if T.edge and T.edge.file then
			local c = T.c.border
			f:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
		end
	else
		f.hl:SetVertexColor(r, gg, b, a)
		f.hl:Show()
		if T.edge and T.edge.file then f:SetBackdropBorderColor(r, gg, b, 1) end
	end
end

function E.PaintFixed(g)
	for i = 1, getn(g.frames) do
		local f = g.frames[i]
		local c = T.c.good
		f.heal:SetStatusBarColor(c[1], c[2], c[3], 0.45)
		f.hv = nil
		f.pty = nil
		local d = T.c.warn
		f.dispelTx:SetVertexColor(d[1], d[2], d[3], 1)
		f.dispelType = nil
		f.dispelStyle = nil
	end
end

-- ---------------------------------------------------------------- mises a jour d'un cadre
function E.UpdateHealth(g, f)
	local unit, cfg = f.unit, g.cfg
	local hp, mx = UnitHealth(unit), UnitHealthMax(unit)
	local state = 0
	if UnitIsConnected(unit) then
		if UnitIsDeadOrGhost(unit) then state = 1 end
	else
		state = 2
	end
	local ratio = 0
	if state == 0 and mx > 0 then
		ratio = hp / mx
		if ratio > 1 then ratio = 1 end
	end
	if state ~= f.state then
		f.state = state
		f.dP = true
		E.ApplyAlpha(g, f)
	end
	if ratio ~= f.ratio then
		f.ratio = ratio
		f.hp:SetValue(ratio)
	end
	local r, gg, b = E.HpColor(g, f, ratio)
	if r ~= f.cr or gg ~= f.cg or b ~= f.cb then
		f.cr, f.cg, f.cb = r, gg, b
		f.hp:SetStatusBarColor(r, gg, b, 1)
	end
	local hpTxt, stTxt = "", ""
	local isRes = false
	if state == 1 then
		isRes = (cfg.resinfo and f.res) and true or false
		if isRes then
			stTxt = g.tags.R
		else
			stTxt = (UnitIsGhost(unit) and L("unit.ghost")) or L("unit.dead")
		end
	elseif state == 2 then
		stTxt = L("unit.offline")
	else
		if hp ~= f.lhp or mx ~= f.lmx or cfg.hptext ~= f.lmode then
			f.lhp, f.lmx, f.lmode = hp, mx, cfg.hptext
			f.hpStr = E.HpText(cfg.hptext, hp, mx, g.kind == "pins")
		end
		hpTxt = f.hpStr or ""
	end
	if hpTxt ~= f.hpShown then
		f.hpShown = hpTxt
		f.hpText:SetText(hpTxt)
	end
	if isRes ~= f.resShown then
		f.resShown = isRes
		local sc = isRes and T.c.good or T.c.warn
		f.statusText:SetTextColor(sc[1], sc[2], sc[3], sc[4] or 1)
	end
	if stTxt ~= f.stShown then
		f.stShown = stTxt
		f.statusText:SetText(stTxt)
	end
	local hv = 0
	local inc = f.inc or 0
	local im = f.incMine or 0
	if im > inc then inc = im end
	if inc > 0 and mx > 0 and state == 0 then
		hv = (hp + inc) / mx
		if hv > 1 then hv = 1 end
	end
	if hv ~= f.hv then
		f.hv = hv
		f.heal:SetValue(hv)
	end
end

-- La barre de mana de ce cadre est-elle voulue ? "all" : toutes les ressources (comportement d'origine) ; "none" : aucune ;
-- "healers" / "casters" : mana seulement (jamais rage / energie), selon la classe (et le role manuel). Aucune allocation.
function E.ManaWanted(g, f)
	local mode = g.cfg.manabar
	if mode == "all" then return true end
	if mode == "none" or not mode then return false end
	local role, class = f.role, f.class
	if role == "H" then return true end
	if mode == "healers" then
		if role == "T" or role == "D" then return false end
		return E.HEALER_CLASS[class] == true
	end
	if E.CASTER_CLASS[class] then return true end
	return (class == "HUNTER" and g.cfg.manahunter) and true or false
end

-- Hauteur de la barre de vie : l'espace de la barre de puissance est rendu quand elle est cachee.
function E.HpHeight(g, f)
	local cfg = g.cfg
	if cfg.powerheight > 0 and f.pwShown ~= false then return cfg.height - 3 - cfg.powerheight end
	return cfg.height - 2
end

function E.UpdatePower(g, f)
	local unit = f.unit
	local pw = f.pw
	local cfg = g.cfg
	local mx = 0
	local pty = 0
	local all = (cfg.manabar == "all")
	if cfg.powerheight > 0 and f.state == 0 and E.ManaWanted(g, f) then
		pty = UnitPowerType(unit)
		-- hors "all" : seule la mana compte (un druide en ours / felin n'a plus de mana lisible)
		if all or pty == 0 then mx = UnitManaMax(unit) end
	end
	if mx <= 0 then
		if f.pwShown ~= false then
			f.pwShown = false
			pw:Hide()
			f.pwText:Hide()
			f.pwTxt = nil
			E.Resize(g, f)
		end
		return
	end
	if not f.pwShown then
		f.pwShown = true
		pw:Show()
		E.Resize(g, f)
	end
	if pty ~= f.pty then
		f.pty = pty
		local col = E.POWER_COL[pty] or T.c.dim
		pw:SetStatusBarColor(col[1], col[2], col[3], 1)
	end
	local cur = UnitMana(unit)
	pw:SetValue(cur / mx)
	if cfg.manatext then
		local pc = floor(cur * 100 / mx + 0.5)
		if pc > 100 then pc = 100 end
		if pc < 0 then pc = 0 end
		if f.pwTxt ~= pc then
			f.pwTxt = pc
			f.pwText:SetText(E.NUM[pc] or "100")
		end
		f.pwText:Show()
	elseif f.pwTxt then
		f.pwTxt = nil
		f.pwText:Hide()
	end
end

local function edgeColor(f, k, dt)
	local e = f.dEdge[k]
	local col = dt and E.DEBUFF_COL[dt]
	if col then
		e:SetVertexColor(col[1], col[2], col[3], 1)
	else
		local c = T.c.border
		e:SetVertexColor(c[1], c[2], c[3], 1)
	end
end

-- Debuffs (cure / alertes / icones) puis buffs. Aucune table : seulement des champs existants.
function E.UpdateAuras(g, f)
	local cfg = g.cfg
	local unit = f.unit
	local wantD, wantB = cfg.debuffs, cfg.buffs
	local mode = cfg.dispelmode
	local nd = 0
	local dtype, alertTex, alertFrag = nil, nil, nil
	local bestRank = 99
	local useAlerts = cfg.alerts and g.nAlerts > 0
	if wantD > 0 or mode ~= "off" or useAlerts then
		for i = 1, MAXAUR do
			local tex, count, dt = UnitDebuff(unit, i)
			if not tex then break end
			local cureOk = false
			if dt and dt ~= "" then
				if mode == "all" then cureOk = true elseif mode == "known" then cureOk = E.cure[dt] and true or false end
				if cureOk then
					local rk = g.dprio[dt] or 9
					if rk < bestRank then
						bestRank = rk
						dtype = dt
					end
				end
			end
			if useAlerts and not alertTex then
				for k = 1, g.nAlerts do
					if sfind(tex, g.alerts[k], 1, true) then
						alertTex, alertFrag = tex, g.alerts[k]
						break
					end
				end
			end
			if nd < wantD and nd < g.maxDeb and (cureOk or not cfg.dispelonly) then
				nd = nd + 1
				if f.dTex[nd] ~= tex then
					f.dTex[nd] = tex
					f.dIcon[nd]:SetTexture(tex)
					f.dIcon[nd]:SetTexCoord(0.08, 0.92, 0.08, 0.92)    -- recadrage repose apres la texture
				end
				if f.dType[nd] ~= (dt or false) then
					f.dType[nd] = dt or false
					edgeColor(f, nd, dt)
				end
			end
		end
	end
	if nd ~= f.dN then
		local lo, hi = nd + 1, f.dN
		if f.dN < nd then lo, hi = f.dN + 1, nd end
		for k = lo, hi do
			if k <= nd then
				f.dIcon[k]:Show()
				f.dEdge[k]:Show()
			else
				f.dIcon[k]:Hide()
				f.dEdge[k]:Hide()
			end
		end
		f.dN = nd
	end
	-- types de debuff a dissiper : lisere colore a gauche
	local dstyle = cfg.dispelstyle
	if dtype ~= f.dispelType or dstyle ~= f.dispelStyle then
		f.dispelType = dtype
		f.dispelStyle = dstyle
		if dtype then
			local col = E.DEBUFF_COL[dtype]
			if col then
				f.dispelTx:SetVertexColor(col[1], col[2], col[3], 1)
				f.dispelHl:SetVertexColor(col[1], col[2], col[3], 0.32)
			end
			if dstyle ~= "frame" then f.dispelTx:Show() else f.dispelTx:Hide() end
			if dstyle ~= "stripe" then f.dispelHl:Show() else f.dispelHl:Hide() end
		else
			f.dispelTx:Hide()
			f.dispelHl:Hide()
		end
	end
	-- alerte
	if alertTex ~= f.alertTex then
		local isNew = (alertTex ~= nil and f.alertTex == nil)
		f.alertTex = alertTex
		if alertTex then
			f.alertIcon:SetTexture(alertTex)
			f.alertIcon:Show()
		else
			f.alertIcon:Hide()
		end
		f.dB = true
		if isNew then E.FireAlert(g, f, alertFrag, alertTex) end
	end
	-- buffs
	local nb = 0
	if wantB > 0 then
		for i = 1, wantB do
			if nb >= g.maxBuf then break end
			local tex = UnitBuff(unit, i)
			if not tex then break end
			nb = nb + 1
			if f.bTex[nb] ~= tex then
				f.bTex[nb] = tex
				f.bIcon[nb]:SetTexture(tex)
				f.bIcon[nb]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
		end
	end
	if nb ~= f.bN then
		local lo, hi = nb + 1, f.bN
		if f.bN < nb then lo, hi = f.bN + 1, nb end
		for k = lo, hi do
			if k <= nb then f.bIcon[k]:Show() else f.bIcon[k]:Hide() end
		end
		f.bN = nb
	end
	E.UpdateHots(g, f)
end

-- ---------------------------------------------------------------- HoT / boucliers du joueur (icone + duree)
-- Temps restant d'un buff du JOUEUR (API 1.12 GetPlayerBuff*), nil si indisponible.
function E.PlayerLeft(tex)
	local gb, gx, gl = getglobal("GetPlayerBuff"), getglobal("GetPlayerBuffTexture"), getglobal("GetPlayerBuffTimeLeft")
	if type(gb) ~= "function" or type(gx) ~= "function" or type(gl) ~= "function" then return nil end
	for i = 0, 31 do
		local idx = gb(i, "HELPFUL")
		if not idx or idx < 0 then break end
		if gx(idx) == tex then return gl(idx) end
	end
	return nil
end

-- Un sort suivi vient d'etre lance par le joueur sur 'name' : memorise sa fin et redessine le cadre (aucune table creee en regime).
function E.NoteHot(name, spell)
	local d = E.HOTS[spell]
	local rec = E.hotEnd[spell]
	if not d or not rec or not name or name == "" then return end
	rec[name] = GetTime() + d
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.built and g.cfg.hots > 0 then
			local f = g.names[name]
			if f then
				f.dA = true
				E.Push(g, f)
			end
		end
	end
end

-- Pose / retire les icones de HoT d'un cadre (jusqu'a cfg.hots, plafonne a g.maxHot).
function E.UpdateHots(g, f)
	local cfg = g.cfg
	local want = cfg.hots
	if want > g.maxHot then want = g.maxHot end
	local nh = 0
	if want > 0 then
		local unit, name = f.unit, f.name
		local now = GetTime()
		for i = 1, MAXBUF do
			local tex = UnitBuff(unit, i)
			if not tex then break end
			local sp = E.hotTex[tex]
			if sp then
				local ex = E.hotEnd[sp][name]
				if ex and ex <= now then ex = nil end
				if ex and f.isSelf then
					local left = E.PlayerLeft(tex)
					if left and left > 0 then ex = now + left end
				end
				if ex or cfg.hotall then
					nh = nh + 1
					if f.hTex[nh] ~= tex then
						f.hTex[nh] = tex
						f.hIcon[nh]:SetTexture(tex)
						f.hIcon[nh]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					end
					f.hExp[nh] = ex or false
					f.hSec[nh] = nil
					if nh >= want then break end
				end
			end
		end
	end
	if nh ~= f.hN then
		local lo, hi = nh + 1, f.hN
		if f.hN < nh then lo, hi = f.hN + 1, nh end
		for k = lo, hi do
			if k <= nh then
				f.hIcon[k]:Show()
				f.hTime[k]:Show()
			else
				f.hIcon[k]:Hide()
				f.hTime[k]:Hide()
				f.hTime[k]:SetText("")
				f.hSec[k] = nil
			end
		end
		f.hN = nh
	end
	E.TickFrameHots(g, f, GetTime())
end

-- Texte de duree de chaque icone (reecrit seulement quand la seconde change) ; une icone expiree relance l'analyse du cadre.
function E.TickFrameHots(g, f, now)
	for k = 1, f.hN do
		local ex = f.hExp[k]
		local s = -1
		if ex then
			s = ceil(ex - now)
			if s <= 0 then
				f.dA = true
				E.Push(g, f)
				s = -1
			end
		end
		if s ~= f.hSec[k] then
			f.hSec[k] = s
			local txt = ""
			if s >= 100 then
				txt = floor(s / 60) .. "m"
			elseif s >= 0 then
				txt = E.NUM[s]
			end
			f.hTime[k]:SetText(txt)
		end
	end
end

function E.TickHots(g)
	if not g.active or not g.built then return end
	local now = GetTime()
	for i = 1, g.nOrder do
		local f = g.order[i]
		if f.hN > 0 then E.TickFrameHots(g, f, now) end
	end
end

-- Minuterie des durees : seulement si des HoT sont demandes.
function E.SyncHots(g)
	local need = g.active and g.maxHot > 0 and g.cfg.hots > 0
	if need and not g.tHot then
		g.tHot = SUI.Every(0.5, g.fnHot, g.title .. ".hot", true)
	elseif not need and g.tHot then
		SUI.Cancel(g.tHot)
		g.tHot = nil
	end
end

-- ---------------------------------------------------------------- resurrection en cours (SuperWoW : UNIT_CASTEVENT ; sinon HealComm)
local function spellName(id)
	if not id then return nil end
	local nm = E.idName[id]
	if nm ~= nil then return nm or nil end
	local si = getglobal("SpellInfo")
	if type(si) ~= "function" then return nil end
	local ok, n = pcall(si, id)
	nm = (ok and type(n) == "string") and n or false
	if E.idN < 400 then
		E.idN = E.idN + 1
		E.idName[id] = nm
	end
	return nm or nil
end

-- true si quelqu'un est en train de ressusciter le cadre f.
function E.IsResurrecting(g, f)
	local now = GetTime()
	local gd = f.guid
	if gd then
		for i = 1, RESN do
			local s = E.res[i]
			if s.u > now and s.t == gd then return true end
		end
		local pt = getglobal("PTHealPredict")
		if type(pt) == "table" and type(pt.IsBeingResurrected) == "function" then
			local ok, v = pcall(pt.IsBeingResurrected, gd)
			if ok and v then return true end
		end
	end
	if g.HC and type(g.HC.UnitisResurrecting) == "function" then
		local ok, v = pcall(g.HC.UnitisResurrecting, g.HC, f.name)
		if ok and v then return true end
	end
	return false
end

-- Evaluation immediate des cadres morts d'une cible de resurrection.
local function refreshRes(guid)
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.built then
			for k = 1, g.nOrder do
				local f = g.order[k]
				if f.guid == guid and f.state == 1 then
					f.res = E.IsResurrecting(g, f)
					f.dH = true
					E.Push(g, f)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- mes soins en cours (barre de soin entrant : ma propre incantation)
-- Soin direct moyen par rang (rang 1 d'abord), SANS bonus. Estimation : talents (Soins ameliores, Soins spirituels...) et critiques ne sont
-- pas pris en compte ; le bonus de soins vient de GetSpellBonusHealing quand le client l'offre, ponderee par le temps d'incantation / 3.5 s.
-- Valeurs relevees de memoire (non verifiees en jeu). Les HoT et les soins instantanes n'ont pas de barre d'incantation : ils n'y sont pas.
E.HEALS = {
	["Lesser Heal"] = { 51, 78, 146 },
	["Heal"] = { 330, 476, 624, 781 },
	["Greater Heal"] = { 956, 1219, 1523, 1902, 2194 },
	["Flash Heal"] = { 215, 286, 360, 439, 567, 704, 885 },
	["Holy Light"] = { 46, 88, 181, 345, 538, 758, 1022, 1343, 1680 },
	["Flash of Light"] = { 67, 113, 162, 218, 294, 369 },
	["Healing Touch"] = { 44, 100, 219, 404, 634, 818, 1028, 1313, 1656, 2060, 2472 },
	["Regrowth"] = { 100, 176, 257, 339, 431, 543, 685, 859, 1061 },
	["Healing Wave"] = { 39, 71, 142, 292, 408, 579, 797, 1092, 1464, 1735 },
	["Lesser Healing Wave"] = { 174, 264, 359, 486, 668, 880 },
	["Chain Heal"] = { 357, 449, 607 },
}
-- Noms francais (octets UTF-8 ecrits en decimal : la source reste ASCII). Non verifie en jeu.
E.HEALALIAS = {
	["Soins inf\195\169rieurs"] = "Lesser Heal",
	["Soins"] = "Heal",
	["Soins sup\195\169rieurs"] = "Greater Heal",
	["Soins rapides"] = "Flash Heal",
	["Lumi\195\168re sacr\195\169e"] = "Holy Light",
	["\195\137clair lumineux"] = "Flash of Light",
	["Toucher gu\195\169risseur"] = "Healing Touch",
	["R\195\169tablissement"] = "Regrowth",
	["Vague de soins"] = "Healing Wave",
	["Vague de soins inf\195\169rieurs"] = "Lesser Healing Wave",
	["Salve de gu\195\169rison"] = "Chain Heal",
}
E.bookRank = {}              -- sort de E.HEALS -> plus haut rang connu
E.mine = { name = nil, amount = 0, at = 0, endAt = 0, src = nil }   -- ma incantation de soin en cours : cible (nom) et montant estime
E.pend = { spell = nil, rank = nil, unit = nil, at = 0 }            -- dernier lancement annonce par ShikiUI (clic sur un cadre)
E.INC_EV = { "SPELLCAST_START", "SPELLCAST_STOP", "SPELLCAST_FAILED", "SPELLCAST_INTERRUPTED" }

-- Nom de E.HEALS correspondant a un nom de sort du client (anglais ou francais), ou nil.
function E.HealKey(name)
	if not name then return nil end
	if E.HEALS[name] then return name end
	return E.HEALALIAS[name]
end

-- Plus haut rang connu de chaque soin de la liste (relu quand le grimoire change).
function E.ScanHeals()
	local br = E.bookRank
	for k in pairs(br) do br[k] = nil end
	local gn = getglobal("GetSpellName")
	if type(gn) ~= "function" then return end
	local book = getglobal("BOOKTYPE_SPELL") or "spell"
	for i = 1, 800 do
		local name, rank = gn(i, book)
		if not name then break end
		local key = E.HealKey(name)
		if key then
			local _, _, n = sfind(rank or "", "(%d+)")
			n = tonumber(n) or 1
			if n > (br[key] or 0) then br[key] = n end
		end
	end
end

-- Montant estime d'un soin : rang demande (sinon le plus haut connu) + bonus de soins ponderee par le temps d'incantation (ms).
function E.HealAmount(key, rank, castMs)
	local t = E.HEALS[key]
	if not t then return 0 end
	local r = rank or E.bookRank[key] or getn(t)
	if r > getn(t) then r = getn(t) end
	if r < 1 then r = 1 end
	local v = t[r]
	local fb = getglobal("GetSpellBonusHealing")
	if type(fb) == "function" then
		local ok, b = pcall(fb)
		if ok and type(b) == "number" and b > 0 then
			local coef = (tonumber(castMs) or 0) / 3500
			if coef > 1 then coef = 1 end
			v = v + b * coef
		end
	end
	return floor(v + 0.5)
end

-- Annonce un lancement fait par ShikiUI (Mod_ClickHeal) : la cible est connue exactement, meme si la cible du jeu est rendue aussitot.
-- spell : "Nom" ou "Nom(Rank n)" ; unit : jeton d'unite.
function E.NoteCast(spell, unit)
	if type(spell) ~= "string" or not unit then return end
	local _, _, base, rank = sfind(spell, "^(.-)%s*%(%D*(%d+)%)$")
	local p = E.pend
	p.spell = base or spell
	p.rank = tonumber(rank)
	p.unit = unit
	p.at = GetTime()
end

-- Un cadre dont le nom est 'name' doit relire ma part de soin entrant.
function E.RefreshMine(name)
	if not name then return end
	local m = E.mine
	local v = (m.name == name) and m.amount or 0
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.built and g.kind ~= "pins" then
			local f = g.names[name]
			if f and (f.incMine or 0) ~= v then
				f.incMine = v
				f.dH = true
				E.Push(g, f)
			end
		end
	end
	if SUI.UnitsHealNotify then SUI.UnitsHealNotify() end   -- cadres joueur / cible de Units.lua
end

function E.SetMine(tname, amount, dur, src)
	local m = E.mine
	local old = m.name
	m.name, m.amount, m.src = tname, amount, src
	m.at = GetTime()
	m.endAt = m.at + (dur or 0) + 1
	if old and old ~= tname then E.RefreshMine(old) end
	E.RefreshMine(tname)
end

function E.ClearMine()
	local m = E.mine
	local old = m.name
	if not old then return end
	m.name, m.amount, m.src = nil, 0, nil
	E.RefreshMine(old)
end

-- Soins entrants pour un cadre HORS instances (Units.lua : joueur, cible). Retourne le meilleur montant connu
-- (mon incantation en cours, puis HealComm / PTHealPredict pour les autres soigneurs). 0 si rien.
function E.IncomingFor(name, guid)
	local inc = 0
	local m = E.mine
	if name and m.name == name and m.amount > inc then inc = m.amount end
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.kind ~= "pins" and g.cfg.incoming and g.cfg.incsrc ~= "me" then
			if g.HC and name and name ~= "" then
				local ok, v = pcall(g.HC.getHeal, g.HC, name)
				if ok and type(v) == "number" and v > inc then inc = v end
			elseif g.PT and guid then
				local ok, v = pcall(g.PT.getHeal, guid)
				if ok and type(v) == "number" and v > inc then inc = v end
			end
		end
	end
	return inc
end

-- Consommateur des soins entrants pour les cadres joueur / cible de Units.lua (charge avant ce fichier).
SUI.UnitsIncoming = function(unit, name, guid)
	return E.IncomingFor(name, guid)
end

-- Vrai si le lancement annonce par ShikiUI correspond a ce sort (et est recent).
local function pendingFor(key, now)
	local p = E.pend
	return p.spell and p.unit and now - p.at < 2 and E.HealKey(p.spell) == key
end

-- SPELLCAST_START (nom du sort, duree en ms) / STOP / FAILED / INTERRUPTED : mon incantation de soin et sa cible.
function E.OnMyCast(ev, a1, a2)
	if ev ~= "SPELLCAST_START" then
		E.ClearMine()
		return
	end
	local now = GetTime()
	local m = E.mine
	if m.name and m.src == "sw" and now - m.at < 1 then return end      -- SuperWoW a deja donne la cible exacte
	local key = E.HealKey(a1)
	if not key then
		E.ClearMine()
		return
	end
	local tname, rank = nil, nil
	if pendingFor(key, now) then
		tname, rank = UnitName(E.pend.unit), E.pend.rank
		E.pend.spell = nil
	elseif UnitExists("target") and UnitIsFriend("player", "target") then
		tname = UnitName("target")
	else
		tname = UnitName("player")
	end
	if not tname then
		E.ClearMine()
		return
	end
	E.SetMine(tname, E.HealAmount(key, rank, a2), (tonumber(a2) or 0) / 1000, "ev")
end

-- Cible d'un lancement SuperWoW : le nom du cadre portant ce GUID (nil si la cible n'est pas dans un groupe).
local function nameOfGuid(gd)
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.built and g.kind ~= "pins" then
			for k = 1, g.nOrder do
				local f = g.order[k]
				if f.guid == gd then return f.name end
			end
		end
	end
	return nil
end

-- UNIT_CASTEVENT (SuperWoW) pour moi : START donne la cible exacte, CAST / FAIL la fin.
function E.MyCastEvent(a2, a3, a4)
	if a3 == "START" then
		local key = E.HealKey(spellName(a4))
		if not key then return end
		local tgt = a2
		if not tgt or tgt == "" then tgt = E.myGuid end
		local tname = nameOfGuid(tgt)
		if not tname then return end
		local ms = tonumber(getglobal("arg5")) or 0
		local rank = nil
		local now = GetTime()
		if pendingFor(key, now) then rank = E.pend.rank end
		E.SetMine(tname, E.HealAmount(key, rank, ms), ms / 1000, "sw")
	elseif a3 == "CAST" or a3 == "FAIL" then
		E.ClearMine()
	end
end

-- UNIT_CASTEVENT : a1 lanceur, a2 cible, a3 type (START / CAST / FAIL...), a4 sort ; la duree (ms) est le 5e argument.
function E.OnCastEvent(ev, a1, a2, a3, a4)
	if not a1 then return end
	if not E.myGuid then
		local _, gd = UnitExists("player")
		E.myGuid = gd
	end
	if E.wantInc and a1 == E.myGuid and (a3 == "START" or a3 == "CAST" or a3 == "FAIL") then E.MyCastEvent(a2, a3, a4) end
	if a3 == "CAST" and a1 == E.myGuid and E.wantHots then
		local nm = spellName(a4)
		if nm and E.HOTS[nm] then
			local tgt = a2
			if not tgt or tgt == "" then tgt = a1 end
			for i = 1, getn(E.instances) do
				local g = E.instances[i]
				if g.active and g.built and g.cfg.hots > 0 then
					for k = 1, g.nOrder do
						local f = g.order[k]
						if f.guid == tgt then E.NoteHot(f.name, nm) end
					end
				end
			end
		end
	end
	if not E.wantRes then return end
	if a3 == "START" or a3 == "CAST" then
		local nm = spellName(a4)
		if nm and E.RES[nm] and a2 and a2 ~= "" then
			local now = GetTime()
			local slot = nil
			for i = 1, RESN do
				if E.res[i].c == a1 then
					slot = E.res[i]
					break
				end
			end
			if not slot then
				for i = 1, RESN do
					if E.res[i].u <= now then
						slot = E.res[i]
						break
					end
				end
			end
			if not slot then slot = E.res[1] end
			slot.c, slot.t = a1, a2
			if a3 == "START" then
				slot.u = now + (tonumber(getglobal("arg5")) or 10000) / 1000 + 1
			else
				slot.u = now + 30        -- incantation terminee : la cible a 30 s pour accepter
			end
			refreshRes(a2)
		end
	elseif a3 == "FAIL" then
		for i = 1, RESN do
			local s = E.res[i]
			if s.c == a1 and s.u > 0 then
				local t = s.t
				s.u = 0
				refreshRes(t)
			end
		end
	end
end

-- Ecoute UNIT_CASTEVENT seulement si une instance active a besoin des HoT ou de la resurrection (SuperWoW requis).
function E.SyncCast()
	local hots, res, inc = false, false, false
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		if g.active and g.kind ~= "pins" then
			if g.cfg.hots > 0 and g.maxHot > 0 then hots = true end
			if g.cfg.resinfo then res = true end
			if g.cfg.incoming then inc = true end
		end
	end
	-- Les cadres joueur / cible de Units.lua consomment aussi les soins entrants (barre de pre-soin sur soi).
	if not inc and SUI.Units and SUI.Units.active and SUI.Config.Get("units.incheal") then inc = true end
	E.wantHots, E.wantRes = hots, res
	if inc ~= E.wantInc then
		E.wantInc = inc
		for i = 1, getn(E.INC_EV) do
			if inc then SUI.On(E.INC_EV[i], E.OnMyCast) else SUI.Off(E.INC_EV[i], E.OnMyCast) end
		end
		if inc then E.ScanHeals() else E.ClearMine() end
	end
	if SUI.Api.superwow and (hots or res or inc) then SUI.On("UNIT_CASTEVENT", E.OnCastEvent) else SUI.Off("UNIT_CASTEVENT", E.OnCastEvent) end
end

-- Alerte nouvelle sur un cadre : crochets externes (futur DebuffAlert) puis son optionnel.
function E.FireAlert(g, f, frag, tex)
	for i = 1, getn(E.alertHooks) do
		local ok, err = pcall(E.alertHooks[i], g, f.unit, frag, tex)
		if not ok then SUI.Report("alerthook", err) end
	end
	local mode = g.cfg.alertsound
	if mode == "none" then return end
	if mode == "self" and not UnitIsUnit(f.unit, "player") then return end
	local now = GetTime()
	if g.lastSound and now - g.lastSound < 2 then return end
	g.lastSound = now
	PlaySoundFile(E.SOUND_ALERT)
end

-- Ajoute / retire un crochet d'alerte (retourne true si ajoute / retire).
function E.OnAlert(fn)
	for i = 1, getn(E.alertHooks) do
		if E.alertHooks[i] == fn then return false end
	end
	tinsert(E.alertHooks, fn)
	return true
end

function E.OffAlert(fn)
	for i = getn(E.alertHooks), 1, -1 do
		if E.alertHooks[i] == fn then
			table.remove(E.alertHooks, i)
			return true
		end
	end
	return false
end

function E.UpdateFrame(g, f)
	if not f.vis then
		f.dI, f.dH, f.dP, f.dA, f.dB = false, false, false, false, false
		return
	end
	if f.dI then
		f.dI = false
		E.Info(g, f)
		E.UpdateName(g, f)
		E.UpdateMark(g, f)
		f.dH, f.dP, f.dA, f.dB = true, true, true, true
		f.isTarget = (UnitIsUnit(f.unit, "target") and true) or false
	end
	if f.dH then
		f.dH = false
		E.UpdateHealth(g, f)
	end
	if f.dP then
		f.dP = false
		E.UpdatePower(g, f)
	end
	if f.dA then
		f.dA = false
		E.UpdateAuras(g, f)
	end
	if f.dB then
		f.dB = false
		E.PaintState(g, f)
	end
end

-- Vide la file (budget par passage) ; roster et disposition d'abord.
function E.Flush(g)
	if not g.built or not g.active then return end
	if g.rosterDirty then
		g.rosterDirty = false
		E.Rebuild(g)
	end
	local n = g.cfg.budget
	while n > 0 and g.qn > 0 do
		E.UpdateFrame(g, pop(g))
		n = n - 1
	end
	if g.arrangeDirty then E.Arrange(g) end
end

-- ---------------------------------------------------------------- tour lent (portee, etat, aggro, soins entrants)
function E.Range(unit, cfg)
	if UnitIsUnit(unit, "player") then return true end
	if not UnitIsVisible(unit) then return false end
	local d, src = SUI.Api.Distance(unit)
	if src == "xp" or src == "pos" then return d <= cfg.rangeyd end
	if src == "band" then return d ~= nil end
	return nil
end

function E.SlowFrame(g, f)
	local cfg = g.cfg
	local unit = f.unit
	local st = 0
	if UnitIsConnected(unit) then
		if UnitIsDeadOrGhost(unit) then st = 1 end
	else
		st = 2
	end
	if st ~= f.state then
		f.dH = true
		E.Push(g, f)
	end
	if cfg.range then
		local r = E.Range(unit, cfg)
		if r ~= f.inRange then
			f.inRange = r
			E.ApplyAlpha(g, f)
		end
	elseif f.inRange ~= nil then
		f.inRange = nil
		E.ApplyAlpha(g, f)
	end
	if g.banzai and cfg.aggro then
		local ok, v = pcall(g.banzai.GetUnitAggroByUnitId, g.banzai, unit)
		local ag = (ok and v) and true or false
		if ag ~= f.aggro then
			f.aggro = ag
			f.dB = true
			E.Push(g, f)
		end
	end
	if cfg.resinfo and st == 1 then
		local rs = E.IsResurrecting(g, f)
		if rs ~= f.res then
			f.res = rs
			f.dH = true
			E.Push(g, f)
		end
	elseif f.res then
		f.res = false
		f.dH = true
		E.Push(g, f)
	end
	if (g.HC or g.PT) and cfg.incoming and cfg.incsrc ~= "me" then
		local ok, inc
		if g.HC then
			ok, inc = pcall(g.HC.getHeal, g.HC, f.name)
		elseif f.guid then
			ok, inc = pcall(g.PT.getHeal, f.guid)
		end
		if not ok or type(inc) ~= "number" then inc = 0 end
		if inc ~= f.inc then
			f.inc = inc
			f.dH = true
			E.Push(g, f)
		end
	elseif f.inc and f.inc ~= 0 then
		f.inc = 0
		f.dH = true
		E.Push(g, f)
	end
end

-- Ennemis epingles : aucun evenement par GUID, on interroge (au plus 4 cadres).
function E.PollPin(g, f)
	local unit = f.unit
	if not UnitExists(unit) then
		if not f.gone then
			f.gone = true
			f.dI = true
			E.Push(g, f)
		end
		return
	end
	local hp, mx, nm = UnitHealth(unit), UnitHealthMax(unit), UnitName(unit)
	if f.gone or hp ~= f.lhp or mx ~= f.lmx or nm ~= f.name then
		f.gone = false
		f.dI = true
		E.Push(g, f)
	end
end

function E.Slow(g)
	if not g.active or not g.built then return end
	local cfg = g.cfg
	if E.mine.name and GetTime() > E.mine.endAt then E.ClearMine() end
	local n = g.nOrder
	if n == 0 then return end
	if g.kind == "pins" then
		for i = 1, n do E.PollPin(g, g.order[i]) end
		return
	end
	if (cfg.incoming or cfg.resinfo or cfg.aggro) and not (g.HC or g.PT) then
		local now = GetTime()
		if now >= (g.srcAt or 0) then
			g.srcAt = now + 5
			E.ResolveSources(g)
		end
	end
	if cfg.aggro and not g.banzai then
		local nf = nil
		if UnitExists("target") and UnitExists("targettarget") and UnitCanAttack("player", "target") then
			nf = g.names[UnitName("targettarget") or ""]
		end
		if nf ~= g.aggroFrame then
			local old = g.aggroFrame
			g.aggroFrame = nf
			if old then
				old.aggro = false
				old.dB = true
				E.Push(g, old)
			end
			if nf then
				nf.aggro = true
				nf.dB = true
				E.Push(g, nf)
			end
		end
	end
	local step = cfg.slowstep
	if step > n then step = n end
	local i = g.rr
	for _ = 1, step do
		if i > n then i = 1 end
		E.SlowFrame(g, g.order[i])
		i = i + 1
	end
	g.rr = i
	-- Les soins des AUTRES soigneurs (HealComm / PTHealPredict) changent sans evenement :
	-- les cadres joueur / cible relisent a chaque passage lent (pas seulement les cadres de groupe).
	if (g.HC or g.PT) and cfg.incoming and cfg.incsrc ~= "me" and SUI.UnitsHealNotify then
		SUI.UnitsHealNotify()
	end
end

function E.OnTarget(g)
	if not g.active then return end
	for i = 1, g.nOrder do
		local f = g.order[i]
		local t = (UnitIsUnit(f.unit, "target") and true) or false
		if t ~= f.isTarget then
			f.isTarget = t
			E.PaintState(g, f)
		end
	end
end

-- ---------------------------------------------------------------- roster et disposition
local function setVisible(g, f, want)
	if want == f.vis then return end
	f.vis = want
	if want then
		f:Show()
		f.dI = true
		E.Push(g, f)
	else
		f:Hide()
		f.dI, f.dH, f.dP, f.dA, f.dB = false, false, false, false, false
		f.alertTex = nil
		f.aggro = false
		f.res = false
		f.inRange = nil
		f.state = nil
		f.lhp = nil
	end
end

function E.Rebuild(g)
	local cfg = g.cfg
	for k in pairs(g.names) do g.names[k] = nil end
	if g.kind == "raid" then g.byUnit["player"] = nil end
	local nr = GetNumRaidMembers()
	local np = GetNumPartyMembers()
	if g.kind == "party" then
		local hide = (nr > 0 and cfg.hideinraid)
		local baseOn = (not hide) and (np > 0 or cfg.solo)
		for i = 1, g.max do
			local f = g.frames[i]
			local want
			if i == 1 then
				want = baseOn
			elseif i <= 5 then
				want = baseOn and np >= i - 1 and UnitExists(f.unit) and true or false
			else
				want = baseOn and cfg.pets and UnitExists(f.unit) and true or false
			end
			setVisible(g, f, want)
		end
	elseif g.kind == "raid" then
		for i = 1, g.max do
			local f = g.frames[i]
			local want = false
			if i <= nr then
				local nm, _, sub = GetRaidRosterInfo(i)
				if nm and (sub or 1) <= cfg.maxgroup then want = true end
			end
			setVisible(g, f, want)
			if want and UnitIsUnit(f.unit, "player") then g.byUnit["player"] = f end
		end
	else
		for i = 1, g.max do
			local f = g.frames[i]
			f.unit = g.pins[i]
			setVisible(g, f, i <= g.nPins)
		end
	end
	-- liste ordonnee des cadres visibles (tableau reutilise)
	local n = 0
	for i = 1, g.max do
		local f = g.frames[i]
		if f.vis then
			n = n + 1
			g.order[n] = f
			if f.lastUnit ~= f.unit then
				f.lastUnit = f.unit
				f.dI = true
				E.Push(g, f)
			end
			E.Info(g, f)
			if f.name ~= "" then g.names[f.name] = f end
			local im = (E.mine.name == f.name) and E.mine.amount or 0      -- ma part de soin entrant suit le NOM, pas le jeton d unite
			if (f.incMine or 0) ~= im then
				f.incMine = im
				f.dH = true
				E.Push(g, f)
			end
		end
	end
	g.nOrder = n
	if g.rr > n then g.rr = 1 end
	g.arrangeDirty = true
	E.Arrange(g)
	if g.container then
		if n > 0 then g.container:Show() else g.container:Hide() end
	end
end

local function less(g, a, b)
	local s = g.cfg.sort
	if s == "group" then
		if a.sub ~= b.sub then return a.sub < b.sub end
	elseif s == "role" then
		if a.roleRank ~= b.roleRank then return a.roleRank < b.roleRank end
		if a.classRank ~= b.classRank then return a.classRank < b.classRank end
	elseif s == "class" then
		if a.classRank ~= b.classRank then return a.classRank < b.classRank end
	elseif s == "name" then
		if a.name ~= b.name then return a.name < b.name end
	end
	return a.idx < b.idx
end

-- Tri par insertion (sans allocation) puis placement ; ne repose un point que s'il change.
function E.Arrange(g)
	g.arrangeDirty = false
	local cfg = g.cfg
	local order, n = g.order, g.nOrder
	for i = 2, n do
		local f = order[i]
		local j = i - 1
		while j >= 1 and less(g, f, order[j]) do
			order[j + 1] = order[j]
			j = j - 1
		end
		order[j + 1] = f
	end
	local w, h = cfg.width, cfg.height
	local sp, gap = cfg.spacing, cfg.groupgap
	local sortGroup = (cfg.sort == "group")
	local vertical = (cfg.orient == "vertical")
	local perline = cfg.perline
	local line, pos, lastSub = 0, 0, nil
	local maxX, maxY = 0, 0
	for k = 1, n do
		local f = order[k]
		if sortGroup then
			if f.sub ~= lastSub then
				if lastSub then line = line + 1 end
				pos = 0
				lastSub = f.sub
			end
		else
			line = floor((k - 1) / perline)
			pos = (k - 1) - line * perline
		end
		local lineGap = sortGroup and gap or sp
		local x, y
		if vertical then
			x = line * (w + lineGap)
			y = pos * (h + sp)
		else
			x = pos * (w + sp)
			y = line * (h + lineGap)
		end
		if x ~= f.px or y ~= f.py then
			f.px, f.py = x, y
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", g.container, "TOPLEFT", x, -y)
		end
		if x + w > maxX then maxX = x + w end
		if y + h > maxY then maxY = y + h end
		pos = pos + 1
	end
	if g.container then
		g.container:SetWidth(maxX > 0 and maxX or w)
		g.maxY = maxY
	end
end

-- ---------------------------------------------------------------- clics, survol
local function onEnter()
	local f = this
	SUI.Api.SetMouseover(f.unit)
	local g = f.g
	if g.cfg.tooltip and GameTooltip and UnitExists(f.unit) then
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		GameTooltip:SetUnit(f.unit)
		local ch = SUI.ClickHeal
		if ch and ch.on and ch.AddHints then ch.AddHints(GameTooltip, f) end
		GameTooltip:Show()
	end
end

local function onLeave()
	SUI.Api.SetMouseover(nil)
	if GameTooltip then GameTooltip:Hide() end
end

function E.OpenMenu(f)
	local unit = f.unit
	local dd
	if unit == "player" then
		dd = getglobal("PlayerFrameDropDown")
	else
		local _, _, n = sfind(unit, "^party(%d)$")
		if n then dd = getglobal("PartyMemberFrame" .. n .. "DropDown") end
	end
	if not dd then
		TargetUnit(unit)
		dd = getglobal("TargetFrameDropDown")
	end
	if dd and ToggleDropDownMenu then pcall(ToggleDropDownMenu, 1, nil, dd, "cursor") end
end

function E.DefaultClick(f, btn)
	local unit = f.unit
	if btn == "RightButton" then
		E.OpenMenu(f)
		return
	end
	if SpellIsTargeting() then
		SpellTargetUnit(unit)
	elseif CursorHasItem() then
		DropItemOnUnit(unit)
	else
		TargetUnit(unit)
	end
end

local function onClick()
	local f = this
	local btn = arg1
	local ch = SUI.ClickHeal
	if ch and ch.on and ch.Click(f.unit, btn, f) then return end
	E.DefaultClick(f, btn)
end

local function onWheel()
	local f = this
	local ch = SUI.ClickHeal
	if ch and ch.on and ch.Wheel then ch.Wheel(f.unit, arg1, f) end
end

-- ---------------------------------------------------------------- construction (hors combat uniquement)
function E.CreateUnitFrame(g, i)
	local f = CreateFrame("Button", "ShikiUI_" .. g.title .. "_" .. i, g.container)
	f.g = g
	f.idx = i
	f.unit = g.units and g.units[i] or nil
	if f.unit then g.byUnit[f.unit] = f end
	f.state = nil
	f.name = ""
	f.sub = 1
	f.rank = 0
	f.roleRank = 3
	f.classRank = 99
	f.dN, f.bN, f.hN = 0, 0, 0
	f.dTex, f.dType, f.bTex = {}, {}, {}
	f.dIcon, f.dEdge, f.bIcon = {}, {}, {}
	f.hTex, f.hIcon, f.hTime, f.hExp, f.hSec = {}, {}, {}, {}, {}
	f:SetFrameStrata("LOW")
	f:EnableMouse(true)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	T.Backdrop(f, T.c.bg, T.c.border)
	f.heal = T.Bar(f)
	f.heal:SetFrameLevel(f:GetFrameLevel() + 1)
	f.heal.bg:Hide()
	f.hp = T.Bar(f)
	f.hp:SetFrameLevel(f:GetFrameLevel() + 2)
	f.hp.bg:Hide()
	f.pw = T.Bar(f)
	f.pw:SetFrameLevel(f:GetFrameLevel() + 2)
	f.pw:Hide()
	f.ov = CreateFrame("Frame", nil, f)
	f.ov:SetFrameLevel(f:GetFrameLevel() + 6)
	f.ov:SetAllPoints(f)
	f.hl = f.ov:CreateTexture(nil, "OVERLAY")
	f.hl:SetTexture(T.tex.white)
	f.hl:SetAllPoints(f)
	f.hl:Hide()
	f.dispelHl = f.ov:CreateTexture(nil, "ARTWORK")
	f.dispelHl:SetTexture(T.tex.white)
	f.dispelHl:SetAllPoints(f)
	f.dispelHl:Hide()
	f.dispelTx = f.ov:CreateTexture(nil, "OVERLAY")
	f.dispelTx:SetTexture(T.tex.white)
	f.dispelTx:Hide()
	f.alertIcon = f.ov:CreateTexture(nil, "OVERLAY")
	f.alertIcon:Hide()
	f.mark = f.ov:CreateTexture(nil, "OVERLAY")
	f.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	f.mark:Hide()
	for k = 1, g.maxDeb do
		local e = f.ov:CreateTexture(nil, "ARTWORK")
		e:SetTexture(T.tex.white)
		e:Hide()
		f.dEdge[k] = e
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.dIcon[k] = ic
	end
	for k = 1, g.maxBuf do
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.bIcon[k] = ic
	end
	for k = 1, g.maxHot do
		local ic = f.ov:CreateTexture(nil, "OVERLAY")
		ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ic:Hide()
		f.hIcon[k] = ic
		local tt = T.Text(f.ov, 8, T.c.text, "CENTER", true)
		tt:Hide()
		f.hTime[k] = tt
	end
	f.nameText = T.Text(f.ov, 10, T.c.text, "LEFT", true)
	f.hpText = T.Text(f.ov, 10, T.c.text, "RIGHT", true)
	f.statusText = T.Text(f.ov, 10, T.c.warn, "CENTER", true)
	f.tagText = T.Text(f.ov, 9, T.c.warn, "RIGHT", true)
	f.pwText = T.Text(f.ov, 8, T.c.text, "CENTER", true)
	f.pwText:Hide()
	f:SetScript("OnClick", onClick)
	f:SetScript("OnEnter", onEnter)
	f:SetScript("OnLeave", onLeave)
	f:SetScript("OnMouseWheel", onWheel)
	f:Hide()
	return f
end

local anchorBar
function E.Resize(g, f)
	local hpH = E.HpHeight(g, f)
	anchorBar(f.hp, f, hpH)
	anchorBar(f.heal, f, hpH)
end

function anchorBar(b, f, hpH)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	b:SetHeight(hpH)
end

-- Roues de souris : seulement si les liaisons de clic en utilisent (voir Mod_ClickHeal.lua).
function E.SyncWheel()
	local ch = SUI.ClickHeal
	local on = (ch and ch.on and ch.hasWheel) and true or false
	for i = 1, getn(E.instances) do
		local g = E.instances[i]
		for k = 1, getn(g.frames) do g.frames[k]:EnableMouseWheel(on) end
	end
end

-- Tailles et ancrages internes (reappliques quand un reglage de taille change).
function E.ApplyGeometry(g)
	local cfg = g.cfg
	local w, h, ph, isz = cfg.width, cfg.height, cfg.powerheight, cfg.iconsize
	local nhot = cfg.hots
	if nhot > g.maxHot then nhot = g.maxHot end
	local sig = w .. "|" .. h .. "|" .. ph .. "|" .. isz .. "|" .. nhot
	if sig == g.sig then return end
	g.sig = sig
	for i = 1, getn(g.frames) do
		local f = g.frames[i]
		f:SetWidth(w)
		f:SetHeight(h)
		f.px, f.py = nil, nil
		f.pwShown = nil
		E.Resize(g, f)
		f.pw:ClearAllPoints()
		f.pw:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
		f.pw:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
		f.pw:SetHeight(ph > 0 and ph or 1)
		f.pwText:ClearAllPoints()
		f.pwText:SetPoint("CENTER", f.pw, "CENTER", 0, 0)
		f.pwText:SetHeight(10)
		f.pwTxt = nil
		f.nameText:ClearAllPoints()
		f.nameText:SetPoint("LEFT", f.hp, "LEFT", 3, 0)
		f.nameText:SetWidth(floor(w * 0.62))
		f.nameText:SetHeight(12)
		f.hpText:ClearAllPoints()
		f.hpText:SetPoint("RIGHT", f.hp, "RIGHT", -3, 0)
		f.hpText:SetHeight(12)
		f.statusText:ClearAllPoints()
		f.statusText:SetPoint("CENTER", f.hp, "CENTER", 0, 0)
		f.tagText:ClearAllPoints()
		f.tagText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
		f.tagText:SetHeight(10)
		f.mark:ClearAllPoints()
		f.mark:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
		f.mark:SetWidth(isz)
		f.mark:SetHeight(isz)
		f.dispelTx:ClearAllPoints()
		f.dispelTx:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		f.dispelTx:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
		f.dispelTx:SetWidth(3)
		local asz = h - 6
		if asz > 28 then asz = 28 end
		f.alertIcon:ClearAllPoints()
		f.alertIcon:SetPoint("CENTER", f, "CENTER", 0, 0)
		f.alertIcon:SetWidth(asz)
		f.alertIcon:SetHeight(asz)
		local base = 2 + ((ph > 0) and (ph + 1) or 0)
		for k = 1, g.maxDeb do
			local ic, e = f.dIcon[k], f.dEdge[k]
			e:ClearAllPoints()
			e:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2 + (k - 1) * (isz + 3), base - 1)
			e:SetWidth(isz + 2)
			e:SetHeight(isz + 2)
			ic:ClearAllPoints()
			ic:SetPoint("CENTER", e, "CENTER", 0, 0)
			ic:SetWidth(isz)
			ic:SetHeight(isz)
		end
		for k = 1, g.maxBuf do
			local ic = f.bIcon[k]
			ic:ClearAllPoints()
			ic:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2 - (nhot + k - 1) * (isz + 1), base)
			ic:SetWidth(isz)
			ic:SetHeight(isz)
		end
		for k = 1, g.maxHot do
			local ic, tt = f.hIcon[k], f.hTime[k]
			ic:ClearAllPoints()
			ic:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2 - (k - 1) * (isz + 1), base)
			ic:SetWidth(isz)
			ic:SetHeight(isz)
			tt:ClearAllPoints()
			tt:SetPoint("CENTER", ic, "CENTER", 0, 0)
			tt:SetWidth(isz + 6)
			tt:SetHeight(10)
		end
	end
	g.arrangeDirty = true
end

local function handleStart()
	local h = this
	if C.Get("ui.locked") then return end
	h.container:StartMoving()
	h.moving = true
end

local function handleStop()
	local h = this
	if not h.moving then return end
	h.moving = false
	local c = h.container
	c:StopMovingOrSizing()
	local l, b = c:GetLeft(), c:GetBottom()
	if c.layoutKey and l and b then
		local sc = c:GetScale() or 1
		C.SetPos(c.layoutKey, l * sc, b * sc)
		SUI.Layout.Apply(c.layoutKey)
	end
end

-- Ancienne poignee "::" : remplacee par la poignee nommee du service Mover (Mover.lua), donc toujours cachee.
function E.SyncLock(g)
	if not g.handle then return end
	g.handle:Hide()
end

function E.Build(g)
	if g.built then return end
	g.built = true
	local c = CreateFrame("Frame", "ShikiUI_" .. g.title .. "_Container", UIParent)
	c:SetFrameStrata("LOW")
	c:SetWidth(g.cfg.width)
	c:SetHeight(1)
	g.container = c
	g.handle = T.Button(c, "::", 22, 12, nil)
	g.handle:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 0, 2)
	g.handle.container = c
	g.handle:RegisterForDrag("LeftButton")
	g.handle:SetScript("OnDragStart", handleStart)
	g.handle:SetScript("OnDragStop", handleStop)
	for i = 1, g.max do g.frames[i] = E.CreateUnitFrame(g, i) end
	SUI.Layout.Register(c, g.layoutKey, "TOPLEFT", g.defX, g.defY)
	T.OnAccent(function()
		if g.active then
			E.PaintFixed(g)
			E.MarkAll(g, "dB")
			E.MarkAll(g, "dA")
		end
	end)
	E.PaintFixed(g)
	E.ApplyGeometry(g)
	E.SyncLock(g)
	E.SyncWheel()
	if not g.active then c:Hide() end
end

-- ---------------------------------------------------------------- evenements
local UNIT_EV = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FLAGS", "UNIT_MANA", "UNIT_MAXMANA", "UNIT_RAGE",
	"UNIT_MAXRAGE", "UNIT_ENERGY", "UNIT_MAXENERGY", "UNIT_FOCUS", "UNIT_MAXFOCUS", "UNIT_DISPLAYPOWER", "UNIT_AURA",
	"PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE" }
local POWER_EV = { UNIT_MANA = true, UNIT_MAXMANA = true, UNIT_RAGE = true, UNIT_MAXRAGE = true, UNIT_ENERGY = true,
	UNIT_MAXENERGY = true, UNIT_FOCUS = true, UNIT_MAXFOCUS = true, UNIT_DISPLAYPOWER = true }
local MANA_EV = { UNIT_MANA = true, UNIT_MAXMANA = true, UNIT_DISPLAYPOWER = true }
local ROSTER_EV = { "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_PET" }

local function want(g, ev)
	local cfg = g.cfg
	if g.kind == "pins" then return false end
	if POWER_EV[ev] then
		if cfg.powerheight <= 0 or cfg.manabar == "none" then return false end
		return cfg.manabar == "all" or MANA_EV[ev] == true     -- hors "all" : la rage / l'energie ne servent a rien
	end
	if ev == "UNIT_AURA" then
		return cfg.debuffs > 0 or cfg.buffs > 0 or cfg.dispelmode ~= "off" or (cfg.alerts and g.nAlerts > 0) or cfg.hots > 0
	end
	if ev == "UNIT_PET" then return g.kind == "party" and cfg.pets end
	return true
end

local function setEv(g, ev, handler, on)
	if on and not g.evOn[ev] then
		g.evOn[ev] = true
		SUI.On(ev, handler)
	elseif not on and g.evOn[ev] then
		g.evOn[ev] = false
		SUI.Off(ev, handler)
	end
end

function E.SyncEvents(g)
	local cfg = g.cfg
	for i = 1, getn(UNIT_EV) do
		local ev = UNIT_EV[i]
		setEv(g, ev, (ev == "PARTY_MEMBER_ENABLE" or ev == "PARTY_MEMBER_DISABLE") and g.hMember or g.hUnit, g.active and want(g, ev))
	end
	for i = 1, getn(ROSTER_EV) do
		local ev = ROSTER_EV[i]
		setEv(g, ev, g.hRoster, g.active and want(g, ev) and g.kind ~= "pins")
	end
	setEv(g, "PLAYER_TARGET_CHANGED", g.hTarget, g.active and (cfg.target or cfg.aggro))
	setEv(g, "RAID_TARGET_UPDATE", g.hMarks, g.active and cfg.marks and g.kind ~= "pins")
	setEv(g, "SPELLS_CHANGED", g.hSpells, g.active and g.kind ~= "pins")
end

function E.Activate(g)
	if g.active then return end
	g.active = true
	E.ReadConfig(g)
	E.ScanCures()
	E.SyncEvents(g)
	g.tFlush = SUI.Every(FLUSH, g.fnFlush, g.title .. ".flush", true)
	g.tSlow = SUI.Every(g.slowInterval, g.fnSlow, g.title .. ".slow", true)
	E.SyncHots(g)
	E.SyncCast()
	g.rosterDirty = true
	if g.built then
		g.container:Show()
		E.ApplyGeometry(g)
		E.SyncLock(g)
		E.Flush(g)
	end
end

function E.Deactivate(g)
	if not g.active then return end
	g.active = false
	E.SyncEvents(g)
	SUI.Cancel(g.tFlush)
	SUI.Cancel(g.tSlow)
	g.tFlush, g.tSlow = nil, nil
	E.SyncHots(g)
	E.SyncCast()
	if g.built then
		for i = 1, getn(g.frames) do setVisible(g, g.frames[i], false) end
		for i = 1, g.cap do g.q[i] = false end
		g.qh, g.qt, g.qn = 1, 1, 0
		g.nOrder = 0
		g.container:Hide()
		g.handle:Hide()
	end
end

-- Reglage modifie : relire, retailler, reorganiser, tout redessiner.
function E.OnKey(g, key)
	if not g.active then return end
	E.ReadConfig(g)
	if g.built then E.ApplyGeometry(g) end
	E.SyncEvents(g)
	E.SyncHots(g)
	E.SyncCast()
	g.rosterDirty = true
	g.arrangeDirty = true
	-- ce qui ne se recalcule pas tout seul : opacite hors portee, aggro, soins entrants (sinon repris au tour lent suivant)
	local cfg = g.cfg
	if not cfg.aggro then
		g.aggroFrame = nil
		for i = 1, g.nOrder do g.order[i].aggro = false end
	end
	for i = 1, g.nOrder do
		local f = g.order[i]
		if not cfg.range then f.inRange = nil end
		if not cfg.incoming then
			f.inc = 0
			f.incMine = 0
		end
		if not cfg.resinfo then f.res = false end
		if f.state ~= nil then E.ApplyAlpha(g, f) end
		f.dI = true
		E.Push(g, f)
	end
	if g.built then E.SyncLock(g) end
end

-- ---------------------------------------------------------------- commandes communes (alertes, roles)
local function words(rest)
	local out = {}
	for w in string.gfind(rest or "", "%S+") do tinsert(out, w) end
	return out
end
E.Words = words

local function setList(g, key, list)
	local s = table.concat(list, ";")
	if slen(s) > 400 then
		SUI.Print(L("msg." .. g.name .. ".toolong"))
		return false
	end
	C.Set(g.prefix .. key, s)
	return true
end

-- /sui <module> alert add <fragment> | del <fragment> | list | scan
function E.CmdAlert(g, w)
	local sub = w[2]
	local tmp = {}
	local n = E.ParseList(C.Get(g.prefix .. "alertlist"), tmp)
	if sub == "add" and w[3] then
		for i = 1, n do
			if tmp[i] == w[3] then
				SUI.Print(L("msg." .. g.name .. ".alertdup", w[3]))
				return
			end
		end
		tinsert(tmp, w[3])
		if setList(g, "alertlist", tmp) then SUI.Print(L("msg." .. g.name .. ".alertadded", w[3])) end
	elseif sub == "del" and w[3] then
		local found = false
		for i = n, 1, -1 do
			if tmp[i] == w[3] then
				table.remove(tmp, i)
				found = true
			end
		end
		if found then
			setList(g, "alertlist", tmp)
			SUI.Print(L("msg." .. g.name .. ".alertdeleted", w[3]))
		else
			SUI.Print(L("msg." .. g.name .. ".alertmissing", w[3]))
		end
	elseif sub == "scan" then
		local k = 0
		for _, unit in ipairs({ "player", "target" }) do
			if UnitExists(unit) then
				for i = 1, MAXAUR do
					local tex = UnitDebuff(unit, i)
					if not tex then break end
					local _, _, seg = sfind(tex, "([^\\]+)$")
					k = k + 1
					SUI.Print(L("msg." .. g.name .. ".alertscan", unit, seg or tex))
				end
			end
		end
		if k == 0 then SUI.Print(L("msg." .. g.name .. ".alertscan0")) end
	else
		if n == 0 then
			SUI.Print(L("msg." .. g.name .. ".alertnone"))
		else
			SUI.Print(L("msg." .. g.name .. ".alertlist", table.concat(tmp, ", ")))
		end
	end
end

-- /sui <module> role <nom> <t|h|d|none>
function E.CmdRole(g, w)
	local name, r = w[2], w[3]
	if not name or not r then
		SUI.Print(L("msg." .. g.name .. ".roleusage"))
		return
	end
	local tmp = {}
	local n = E.ParseList(C.Get(g.prefix .. "roles"), tmp)
	for i = n, 1, -1 do
		local _, _, nm = sfind(tmp[i], "^(.-):")
		if nm == name then table.remove(tmp, i) end
	end
	r = string.upper(r)
	if r == "T" or r == "H" or r == "D" then
		tinsert(tmp, name .. ":" .. r)
	elseif r ~= "NONE" then
		SUI.Print(L("msg." .. g.name .. ".roleusage"))
		return
	end
	if setList(g, "roles", tmp) then SUI.Print(L("msg." .. g.name .. ".roleset", name, r)) end
end

-- ================================================================ module "group"
M.on = false
M.party = nil
M.enemies = nil

M.party = E.New({ name = "group", title = "Group", prefix = "group.", kind = "party", max = 10, maxDeb = 4, maxBuf = 6, maxHot = 4,
	layoutKey = "group", defX = 20, defY = -260 })
M.party.units = PU

-- Ennemis epingles : memes cadres, leurs propres dimensions (group.enemywidth / enemyheight) ; unite = GUID SuperWoW.
M.enemies = E.New({ name = "group", title = "GroupEnemies", prefix = "group.", kind = "pins", max = 4, maxDeb = 4, maxBuf = 1,
	layoutKey = "group.enemies", defX = 300, defY = -260, slowInterval = 0.25,
	after = function(g)
		g.cfg.width = C.Get("group.enemywidth")
		g.cfg.height = C.Get("group.enemyheight")
		g.cfg.powerheight = 0
		g.cfg.sort = "none"
		g.cfg.orient = "vertical"
		g.cfg.debuffs = 0
		g.cfg.buffs = 0
		g.cfg.range = false
		g.cfg.aggro = false
		g.cfg.incoming = false
		g.cfg.marks = false
		g.cfg.dispelmode = "off"
		g.cfg.hots = 0
		g.cfg.resinfo = false
		g.cfg.alerts = false
		g.cfg.roletag = false
	end })

local BLIZZ_PARTY = { "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" }

function M.HideBlizzard()
	for i = 1, getn(BLIZZ_PARTY) do
		local fr = getglobal(BLIZZ_PARTY[i])
		if fr then
			fr:UnregisterAllEvents()
			fr:Hide()
		end
	end
	M.blizzHidden = true
end

-- ---------------------------------------------------------------- ennemis epingles
function M.Pin(guid)
	local g = M.enemies
	if not guid then return false, "noguid" end
	local cap = C.Get("group.enemies")
	if cap <= 0 then return false, "off" end
	for i = 1, g.nPins do
		if g.pins[i] == guid then return false, "dup" end
	end
	if g.nPins >= cap or g.nPins >= g.max then return false, "full" end
	g.nPins = g.nPins + 1
	g.pins[g.nPins] = guid
	if g.built then g.frames[g.nPins].unit = guid end
	g.rosterDirty = true
	return true
end

function M.Unpin(guid)
	local g = M.enemies
	for i = 1, g.nPins do
		if g.pins[i] == guid then
			for j = i, g.nPins - 1 do g.pins[j] = g.pins[j + 1] end
			g.pins[g.nPins] = nil
			g.nPins = g.nPins - 1
			if g.built then
				for j = 1, g.max do g.frames[j].unit = g.pins[j] end
			end
			g.rosterDirty = true
			return true
		end
	end
	return false
end

function M.ClearPins()
	local g = M.enemies
	for i = 1, g.nPins do g.pins[i] = nil end
	g.nPins = 0
	if g.built then
		for j = 1, g.max do g.frames[j].unit = nil end
	end
	g.rosterDirty = true
end

local function targetGuid()
	if not UnitExists("target") then return nil end
	return SUI.Target.GUID("target")
end

function M.OnTargetAuto()
	local g = M.enemies
	if not M.on or C.Get("group.enemyauto") ~= "boss" then return end
	if not (SUI.Api.superwow and UnitExists("target")) then return end
	if UnitClassification("target") == "worldboss" and UnitCanAttack("player", "target") then M.Pin(targetGuid()) end
end

function M.OnClearPins()
	local g = M.enemies
	for i = g.nPins, 1, -1 do
		local guid = g.pins[i]
		if not UnitExists(guid) or UnitIsDeadOrGhost(guid) then M.Unpin(guid) end
	end
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key, value)
	if not M.on then return end
	-- nombre d'ennemis epingles abaisse (ou a zero) : les cadres en trop disparaissent tout de suite
	if key == nil or key == "group.enemies" then
		local cap = C.Get("group.enemies")
		while M.enemies.nPins > cap do M.Unpin(M.enemies.pins[M.enemies.nPins]) end
	end
	E.OnKey(M.party, key)
	E.OnKey(M.enemies, key)
	if key == "group.hideblizz" then
		if value then
			M.HideBlizzard()
		elseif M.blizzHidden then
			SUI.Print(L("msg.reload"))
		end
	end
	if key == nil or key == "ui.locked" then
		E.SyncLock(M.party)
		E.SyncLock(M.enemies)
	end
end

function M.Enable()
	M.on = true
	if not M.watching then
		M.watching = true
		C.Watch("", function(key, value)
			if key == nil or key == "ui.locked" or key == "ui.locale" or sfind(key, "^group%.") then M.OnKey(key, value) end
		end)
	end
	SUI.On("PLAYER_TARGET_CHANGED", M.OnTargetAuto)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnClearPins)
	SUI.On("PLAYER_ENTERING_WORLD", M.ClearPins)
	SUI.WhenSafe(function()
		if not M.on then return end
		E.ReadConfig(M.party)
		E.ReadConfig(M.enemies)
		E.Build(M.party)
		E.Build(M.enemies)
		E.Activate(M.party)
		E.Activate(M.enemies)
		if C.Get("group.hideblizz") then M.HideBlizzard() end
	end)
end

function M.Disable()
	M.on = false
	SUI.Off("PLAYER_TARGET_CHANGED", M.OnTargetAuto)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnClearPins)
	SUI.Off("PLAYER_ENTERING_WORLD", M.ClearPins)
	E.Deactivate(M.party)
	E.Deactivate(M.enemies)
	-- les cadres de groupe du jeu ont perdu leurs evenements : seul un /reload les rend (dit une seule fois)
	if M.blizzHidden and not M.blizzNotified then
		M.blizzNotified = true
		SUI.Print(L("msg.reload"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("group", 27)

local function opt(key, typ, order, def, extra)
	local o = { key = "group." .. key, type = typ, cat = "group", label = "opt.group." .. key, tip = "tip.group." .. key, default = def, order = order }
	if extra then for k, v in pairs(extra) do o[k] = v end end
	return o
end

SUI.RegisterModule("group", {
	default = false,
	cost = "medium",
	options = {
		opt("solo", "bool", 10, false, { simple = true }),
		opt("hideinraid", "bool", 20, true),
		opt("pets", "bool", 30, false),
		opt("width", "number", 40, 100, { min = 50, max = 220, step = 2, simple = true }),
		opt("height", "number", 50, 34, { min = 16, max = 80, step = 2, simple = true }),
		opt("powerheight", "number", 60, 4, { min = 0, max = 12, step = 1 }),
		opt("manabar", "choice", 61, "all", { choices = { "none", "healers", "casters", "all" } }),
		opt("manahunter", "bool", 62, false),
		opt("manatext", "bool", 63, false),
		opt("spacing", "number", 70, 2, { min = 0, max = 20, step = 1 }),
		opt("sort", "choice", 80, "none", { choices = { "none", "role", "class", "name" } }),
		opt("orient", "choice", 90, "vertical", { choices = { "vertical", "horizontal" } }),
		opt("hpcolor", "choice", 100, "class", { choices = { "class", "health", "style" }, simple = true }),
		opt("hptext", "choice", 110, "percent", { choices = { "none", "percent", "value", "deficit", "both" }, simple = true }),
		opt("namelen", "number", 120, 10, { min = 4, max = 16, step = 1 }),
		opt("range", "bool", 130, true, { simple = true }),
		opt("rangeyd", "number", 140, 40, { min = 10, max = 60, step = 5 }),
		opt("outalpha", "number", 150, 0.45, { min = 0.2, max = 1, step = 0.05 }),
		opt("debuffs", "number", 160, 3, { min = 0, max = 4, step = 1, simple = true }),
		opt("buffs", "number", 170, 0, { min = 0, max = 6, step = 1 }),
		opt("hots", "number", 172, 2, { min = 0, max = 4, step = 1, simple = true }),
		opt("hotall", "bool", 174, false),
		opt("iconsize", "number", 180, 12, { min = 8, max = 20, step = 1 }),
		opt("dispelmode", "choice", 190, "known", { choices = { "known", "all", "off" }, simple = true }),
		opt("dispelonly", "bool", 200, false),
		opt("dispelstyle", "choice", 202, "both", { choices = { "stripe", "frame", "both" } }),
		opt("dispelprio", "choice", 204, "magic", { choices = { "magic", "curse", "poison", "disease" } }),
		opt("aggro", "bool", 210, true),
		opt("incoming", "bool", 220, true),
		opt("incsrc", "choice", 221, "all", { choices = { "me", "all" } }),
		opt("resinfo", "bool", 225, true),
		opt("roletag", "bool", 230, true),
		opt("leader", "bool", 240, true),
		opt("marks", "bool", 250, true),
		opt("target", "bool", 260, true),
		opt("tooltip", "bool", 270, true),
		opt("alerts", "bool", 280, true),
		opt("alertsound", "choice", 290, "none", { choices = { "none", "self", "any" } }),
		opt("alertlist", "string", 300, ""),
		opt("roles", "string", 310, ""),
		opt("roleguess", "choice", 320, "none", { choices = { "none", "class" } }),
		opt("budget", "number", 330, 10, { min = 1, max = 40, step = 1 }),
		opt("slowstep", "number", 340, 10, { min = 1, max = 40, step = 1 }),
		opt("hideblizz", "bool", 350, true, { reload = true }),
		opt("enemies", "number", 360, 0, { min = 0, max = 4, step = 1 }),
		opt("enemyauto", "choice", 370, "off", { choices = { "off", "boss" } }),
		opt("enemywidth", "number", 380, 160, { min = 100, max = 300, step = 5 }),
		opt("enemyheight", "number", 390, 22, { min = 14, max = 50, step = 2 }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Equivalent pfUI : le module "group" (cadres de groupe).
if SUI.Migrate and SUI.Migrate.MAP and not SUI.Migrate.MAP.group then SUI.Migrate.MAP.group = { "group" } end

-- Mode Raid (groupe de 5 dans un raid / donjon difficile) : plus compact, pas de buffs, debuffs a dissiper seulement.
SUI.Config.AddPreset("raid", "*", { ["group.buffs"] = 0, ["group.debuffs"] = 2, ["group.dispelonly"] = true, ["group.width"] = 90,
	["group.height"] = 30, ["group.budget"] = 12 })

SUI.RegisterCommand("group", function(rest)
	local w = words(rest)
	local sub = w[1]
	if sub == "alert" then
		E.CmdAlert(M.party, w)
	elseif sub == "role" then
		E.CmdRole(M.party, { "role", w[2], w[3] })
	elseif sub == "pin" then
		if not SUI.Api.superwow then
			SUI.Print(L("msg.group.needsw"))
			return
		end
		local ok, why = M.Pin(targetGuid())
		SUI.Print(L(ok and "msg.group.pinned" or ("msg.group.pin." .. tostring(why))))
	elseif sub == "unpin" then
		local guid = targetGuid()
		SUI.Print(L(guid and M.Unpin(guid) and "msg.group.unpinned" or "msg.group.pin.none"))
	elseif sub == "clearpins" then
		M.ClearPins()
		SUI.Print(L("msg.group.pinscleared"))
	else
		local g = M.party
		SUI.Print(L("msg.group.info", g.nOrder, M.enemies.nPins, g.qn, g.nAlerts))
	end
end, "help.group")
