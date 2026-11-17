-- Mod_Actionbars : barres d'action de ShikiUI (remplace le module "actionbar" de pfUI, voir Migrate.MAP).
-- Sept barres : principale (pages / formes), 4 barres de Blizzard (bas gauche, bas droite, droite, gauche), formes, familier.
-- Fonctions : raccourcis, noms de macros, quantites, recharges (chiffre + voile), portee / ressource (teinte), visibilite par barre,
-- pose de raccourcis au survol, masquage des barres de Blizzard, modes Normal / Raid.
-- Reecriture complete : aucun code de pfUI ni d'un autre addon n'a ete copie. Signatures d'API relevees dans les addons installes
-- (pfUI MIT, ItemRack, FredoAutoTarget) : HasAction GetActionTexture GetActionText GetActionCount GetActionCooldown IsUsableAction
-- IsActionInRange IsCurrentAction IsAutoRepeatAction IsConsumableAction IsEquippedAction UseAction PickupAction PlaceAction
-- GetBindingKey GetBindingText SetBinding SaveBindings GetCurrentBindingSet GetNumShapeshiftForms GetShapeshiftFormInfo
-- GetShapeshiftFormCooldown CastShapeshiftForm GetPetActionInfo GetPetActionCooldown CastPetAction PickupPetAction TogglePetAutocast
-- PetHasActionBar GetBonusBarOffset CURRENT_ACTIONBAR_PAGE NUM_ACTIONBAR_PAGES ; evenements ACTIONBAR_* UPDATE_BONUS_ACTIONBAR
-- UPDATE_SHAPESHIFT_FORM(S) PET_BAR_UPDATE(_COOLDOWN) UNIT_PET UPDATE_BINDINGS. Rien de tout cela n'a ete execute en jeu.
-- Postures : sorts qui exigent une posture / forme / aura (guerrier, druide, voleur...) -> bouton grise tant qu'elle n'est pas active, posture
-- requise dans l'infobulle ou le bouton, changement de posture au clic (option). Table de donnees : section "POSTURES" plus bas.
-- Cout declare : medium (une minuterie partagee de 0,1 s ; la portee est relue une fois sur deux ; aucun OnUpdate personnel).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local getn, floor, ceil = table.getn, math.floor, math.ceil

local M = {}
SUI.Actionbars = M

local TICK = 0.1
local PAD = 3
local NO_TINT = 1          -- style:ok teinte neutre : aucune teinte appliquee a l'icone (ce n'est pas une couleur de style)
local CROP_LO, CROP_HI = 0.08, 0.92
local SHADE_ALPHA = 0.45
local GCD_MAX = 1.5        -- 1,5 s ou moins = recharge globale (le 1.12 la renvoie via GetActionCooldown)
local FADE_TICK, FADE_STEP = 0.03, 0.12     -- fondu doux : un pas de 12 % toutes les 0,03 s (environ 0,25 s de transparent a opaque)

M.on = false
M.built = false
M.order = { "main", "bar2", "bar3", "bar4", "bar5", "stance", "pet" }
M.bars = {}
M.base = 0               -- decalage d'actions de la barre principale : (page - 1) * 12
M.page = 1
M.nforms = 0
M.petbar = false
M.grid = false
M.combat = false
M.bind = false
M.tickN = 0
M.cdList = {}
M.cdN = 0
M.dSlot = {}
M.dAll, M.dState, M.dCd, M.dBind, M.dBase, M.dVis = false, false, false, false, false, false
M.class = nil              -- classe du joueur (jeton anglais), relue avec les formes
M.curPosture = nil       -- posture / forme / aura courante (cle de M.POSTURES ou M.AURA_POSTURE), nil = aucune
M.postureReady = false   -- faux tant que les formes du guerrier ne sont pas lues : on ne grise alors rien
M.formIdx, M.formKey = {}, {}     -- cle -> indice de forme (GetShapeshiftFormInfo) et inverse
M.auraPosture = false    -- vrai si la classe a une posture donnee par une aura (camouflage, forme d'ombre) : PLAYER_AURAS_CHANGED
M.dPost = false
M.stnCache, M.shortCache = {}, {}
M.fading = false         -- vrai tant qu'une barre n'a pas atteint son opacite cible (la minuterie de fondu est permanente, sans allocation)

-- kind : action (emplacements du jeu) | stance | pet. base : decalage d'emplacements des barres fixes de Blizzard (releve dans pfUI :
-- bas gauche 61-72, bas droite 49-60, droite 25-36, gauche 37-48). bind : prefixe des commandes de raccourcis.
local DEF = {
	main   = { kind = "action", bind = "ACTIONBUTTON", max = 12, n = 12, per = 12, pt = "BOTTOM", x = 0, y = 24, en = true },
	bar2   = { kind = "action", base = 60, bind = "MULTIACTIONBAR1BUTTON", max = 12, n = 12, per = 12, pt = "BOTTOM", x = 0, y = 70, en = true },
	bar3   = { kind = "action", base = 48, bind = "MULTIACTIONBAR2BUTTON", max = 12, n = 12, per = 12, pt = "BOTTOM", x = 0, y = 116, en = true },
	bar4   = { kind = "action", base = 24, bind = "MULTIACTIONBAR3BUTTON", max = 12, n = 12, per = 1, pt = "RIGHT", x = -4, y = 0, en = false },
	bar5   = { kind = "action", base = 36, bind = "MULTIACTIONBAR4BUTTON", max = 12, n = 12, per = 1, pt = "RIGHT", x = -48, y = 0, en = false },
	stance = { kind = "stance", bind = "SHAPESHIFTBUTTON", max = 10, n = 10, per = 10, pt = "BOTTOM", x = -250, y = 162, en = true },
	pet    = { kind = "pet", bind = "BONUSACTIONBUTTON", max = 10, n = 10, per = 10, pt = "BOTTOM", x = 250, y = 162, en = true },
}
M.DEF = DEF
for i = 1, getn(M.order) do
	local k = M.order[i]
	local d = DEF[k]
	d.key = k
	d.kEnabled = "actionbars." .. k .. ".enabled"
	d.kShow = "actionbars." .. k .. ".show"
	d.kButtons = "actionbars." .. k .. ".buttons"
	d.kPer = "actionbars." .. k .. ".perrow"
	d.kScale = "actionbars." .. k .. ".scale"
	d.kAOut = "actionbars." .. k .. ".alphaout"
	d.kAIn = "actionbars." .. k .. ".alphain"
	d.kLayout = "bars." .. k
end

-- Blizzard : barres a masquer (le jeu les recree sinon). Les boutons ActionButton1-12 restent EXISTANTS (cachees) : les raccourcis
-- ACTIONBUTTONn du jeu passent par eux. Micro-menu, sacs et barre d'XP de Blizzard ne sont pas touches.
local BLIZZ = { "MainMenuBarArtFrame", "BonusActionBarFrame", "ShapeshiftBarFrame", "PetActionBarFrame", "MultiBarBottomLeft",
	"MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "MainMenuBarPerformanceBarFrame" }

local cfg = { size = 36, spacing = 3, fade = 0.25 }
local function noop() end

-- textes de recharge en secondes entieres (pre-calcules : pas de chaine nouvelle chaque dixieme de seconde)
local CDSTR = {}
for i = 0, 59 do CDSTR[i] = tostring(i) end

-- ---------------------------------------------------------------- reglages
function M.ReadConfig()
	cfg.size = C.Get("actionbars.size")
	cfg.spacing = C.Get("actionbars.spacing")
	cfg.keybinds = C.Get("actionbars.keybinds")
	cfg.macrotext = C.Get("actionbars.macrotext")
	cfg.counts = C.Get("actionbars.counts")
	cfg.cooldowns = C.Get("actionbars.cooldowns")
	cfg.cdmin = C.Get("actionbars.cdmin")
	cfg.cdshade = C.Get("actionbars.cdshade")
	cfg.showgcd = C.Get("actionbars.showgcd")
	cfg.cdsweep = C.Get("actionbars.cdsweep")
	cfg.cdsize = C.Get("actionbars.cdsize")
	cfg.cdtextmax = C.Get("actionbars.cdtextmax")
	cfg.cdcolor = C.Get("actionbars.cdcolor")
	cfg.range = C.Get("actionbars.range")
	cfg.mana = C.Get("actionbars.mana")
	cfg.finisher = C.Get("actionbars.finisher")
	cfg.stances = C.Get("actionbars.stances")
	cfg.stancetext = C.Get("actionbars.stancetext")
	cfg.autostance = C.Get("actionbars.autostance")
	cfg.stanceind = C.Get("actionbars.stanceind")
	cfg.unitxp = C.Get("actionbars.unitxp")
	cfg.melee = C.Get("actionbars.melee")
	cfg.empty = C.Get("actionbars.empty")
	cfg.lockdrag = C.Get("actionbars.lockdrag")
	cfg.altself = C.Get("actionbars.altself")
	cfg.rightself = C.Get("actionbars.rightself")
	cfg.tooltips = C.Get("actionbars.tooltips")
	cfg.fade = C.Get("actionbars.fade") / 100
	cfg.aout = C.Get("actionbars.alphaout") / 100
	cfg.ain = C.Get("actionbars.alphain") / 100
	cfg.autopage = C.Get("actionbars.autopage")
	cfg.hideblizz = C.Get("actionbars.hideblizz")
	cfg.xpbar = C.Get("actionbars.xpbar")
	cfg.micro = C.Get("actionbars.micro")
	cfg.microscale = C.Get("actionbars.micro.scale")
	cfg.microcols = C.Get("actionbars.micro.cols")
	cfg.microspace = C.Get("actionbars.micro.space")
	cfg.microalpha = C.Get("actionbars.micro.alpha")
	for i = 1, getn(M.order) do
		local bar = M.bars[M.order[i]]
		if bar then
			local d = bar.def
			bar.enabled = C.Get(d.kEnabled)
			bar.show = C.Get(d.kShow)
			bar.nbtn = C.Get(d.kButtons)
			bar.per = C.Get(d.kPer)
			bar.scale = C.Get(d.kScale)
			bar.aout = C.Get(d.kAOut) / 100
			bar.ain = C.Get(d.kAIn) / 100
		end
	end
end

-- ---------------------------------------------------------------- page active de la barre principale
-- Formule relevee dans pfUI (GetActiveBar) : page 1 + decalage de barre bonus (forme, camouflage) -> page NUM_ACTIONBAR_PAGES + decalage.
function M.ActivePage()
	local page = CURRENT_ACTIONBAR_PAGE or 1
	if cfg.autopage and page == 1 and GetBonusBarOffset then
		local off = GetBonusBarOffset()
		if off and off ~= 0 then return (NUM_ACTIONBAR_PAGES or 6) + off end
	end
	return page
end

function M.Rebase()
	local page = M.ActivePage()
	local base = (page - 1) * 12
	M.page = page
	local bar = M.bars.main
	if base ~= M.base or (bar and bar.rebased ~= base) then
		M.base = base
		M.dAll = true
	end
	if bar then
		bar.rebased = base
		for i = 1, bar.made do bar.btn[i].slot = base + i end
	end
end

-- ---------------------------------------------------------------- aides
local function setText(fs, s)
	if fs.suiTxt ~= s then
		fs.suiTxt = s
		fs:SetText(s)
	end
end

function M.EffN(bar)
	local n = bar.nbtn
	if bar.kind == "stance" and M.nforms < n then n = M.nforms end
	return n
end

function M.CmdOf(b)
	return b.cmd
end

local function paintBorder(b, st)
	if b.bst == st then return end
	b.bst = st
	local c = T.c.border
	if st == 1 then
		local r, g, bl = T.Accent()
		b:SetBackdropBorderColor(r, g, bl, 1)
		return
	elseif st == 2 then
		c = T.c.good
	end
	b:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
end

-- Teinte d'une icone selon son etat (1 hors de portee, 2 ressource insuffisante, 3 inutilisable, 4 mauvaise posture, 5 forme inactive, 0 neutre). Une teinte MULTIPLIE les
-- couleurs de l'icone : un jeton de style tel quel (rouge 0,91 / 0,33 / 0,33) la rend terne. On part donc du jeton, on pousse sa
-- composante dominante au maximum (rouge vif) ou on l'eclaircit vers le blanc (ressource) : aucune couleur en dur.
function M.TintColor(st)
	if st == 1 then
		local c = T.c.bad
		return NO_TINT, c[2] * 0.45, c[3] * 0.45
	elseif st == 2 then
		local r, g, bl = T.Accent()
		return r + (NO_TINT - r) * 0.35, g + (NO_TINT - g) * 0.35, bl + (NO_TINT - bl) * 0.35
	elseif st == 3 then
		local c = T.c.dim
		return c[1], c[2], c[3]
	elseif st == 4 then          -- mauvaise posture : plus sombre que "inutilisable"
		local c = T.c.dim
		return c[1] * 0.85, c[2] * 0.85, c[3] * 0.85
	elseif st == 5 then          -- forme non active (barre de formes) : nette attenuation
		local c = T.c.dim
		return c[1] * 0.6, c[2] * 0.6, c[3] * 0.6   -- nettement plus sombre : une icone naturellement lumineuse ne doit pas passer pour la forme active
	end
	return NO_TINT, NO_TINT, NO_TINT
end

local function paintTint(b, st)
	if b.vst == st then return end
	b.vst = st
	local r, g, bl = M.TintColor(st)
	b.icon:SetVertexColor(r, g, bl, NO_TINT)          -- opacite toujours pleine : seule la couleur change
	b.icon:SetAlpha(NO_TINT)
end

-- ---------------------------------------------------------------- recharges
-- Taille du chiffre de recharge : le Theme garde l'enregistrement de style du texte (T.items), on change sa taille sans toucher au Theme.
local function trackCd(b)
	local fs = b.cdt
	local n = getn(T.items)
	local it = T.items[n]
	if not it or it.o ~= fs then
		it = nil
		for i = n, 1, -1 do
			if T.items[i].o == fs then it = T.items[i] break end
		end
	end
	fs.suiTk = it
end

function M.FontCd(b)
	local it = b.cdt.suiTk
	local size = cfg.cdsize
	if not it or type(size) ~= "number" or it.size == size then return end
	it.size = size
	local px = floor(size * T.fontScale + 0.5)
	if px < 6 then px = 6 end
	local flags = T.outline
	if it.outline and flags == "" then flags = "OUTLINE" end
	pcall(b.cdt.SetFont, b.cdt, T.font, px, flags)
end

-- Balayage (modele "Cooldown" du jeu, cree une fois par bouton) : arrete / lance, sans rien recreer.
local function stopSweep(b)
	local m = b.cdModel
	if m and b.swOn then
		b.swOn = false
		if type(CooldownFrame_SetTimer) == "function" then pcall(CooldownFrame_SetTimer, m, 0, 0, 0) end
		m:Hide()
	end
end

local function startSweep(b, s, d)
	local m = b.cdModel
	if not m then return end
	if not cfg.cdsweep or type(CooldownFrame_SetTimer) ~= "function" then
		stopSweep(b)
		return
	end
	if not b.swOn or b.swS ~= s or b.swD ~= d then
		b.swOn, b.swS, b.swD = true, s, d
		pcall(CooldownFrame_SetTimer, m, s, d, 1)
		m:Show()
	end
end

local function cdClear(b)
	b.cdEnd = nil
	b.cdtier = nil
	b.cdGcd = nil
	if b.incd then
		b.incd = false
		for i = 1, M.cdN do
			if M.cdList[i] == b then
				M.cdList[i] = M.cdList[M.cdN]
				M.cdList[M.cdN] = nil
				M.cdN = M.cdN - 1
				break
			end
		end
	end
	setText(b.cdt, "")
	b.shade:Hide()
	stopSweep(b)
end

local function cdString(r)
	if r >= 3600 then return ceil(r / 3600) .. "h" end
	if r >= 60 then return ceil(r / 60) .. "m" end
	local s = ceil(r)
	if s > 59 then s = 59 end
	return CDSTR[s]
end

-- Un tic de recharge : chiffre (jamais pour la recharge globale ; masque au-dela du seuil), couleur selon le temps restant
-- (rouge sous 3 s, avertissement sous 10 s) et, faute de modele de balayage, voile qui se vide au fil du temps.
local function cdPaint(b, now)
	local r = b.cdEnd - now
	if r <= 0 then
		cdClear(b)
		return
	end
	if cfg.cooldowns and not b.cdGcd and (cfg.cdtextmax <= 0 or r <= cfg.cdtextmax) then
		setText(b.cdt, cdString(r))
		local tier = 0
		if cfg.cdcolor then
			if r <= 3 then tier = 2 elseif r <= 10 then tier = 1 end
		end
		if b.cdtier ~= tier then
			b.cdtier = tier
			local c = T.c.text
			if tier == 2 then c = T.c.bad elseif tier == 1 then c = T.c.warn end
			b.cdt:SetTextColor(c[1], c[2], c[3], 1)
			if b.cdt.suiTk then b.cdt.suiTk.color = c end
		end
	else
		setText(b.cdt, "")
	end
	local full = b:GetHeight() - 2
	if full < 1 then full = 1 end
	if cfg.cdsweep and not b.cdModel and b.cdDur and b.cdDur > 0 then
		local f = r / b.cdDur
		if f > 1 then f = 1 end
		full = full * f
		if full < 1 then full = 1 end
	end
	b.shade:SetHeight(full)
end

-- Lecture gardee de la recharge d'un bouton : GetActionCooldown (sorts, objets, macros), formes ou familier.
local function readCd(b)
	local fn, a
	if b.kind == "stance" then
		fn, a = GetShapeshiftFormCooldown, b.idx
	elseif b.kind == "pet" then
		fn, a = GetPetActionCooldown, b.idx
	elseif b.has then
		fn, a = GetActionCooldown, b.slot
	end
	if type(fn) ~= "function" then return nil end
	local ok, s, d, en = pcall(fn, a)
	if not ok or type(s) ~= "number" or type(d) ~= "number" then return nil end
	return s, d, en
end

function M.UpdateCooldown(b)
	local s, d, en = readCd(b)
	local gcd = (d ~= nil and d <= GCD_MAX)
	if s and s > 0 and d > 0 and en ~= 0 and ((gcd and cfg.showgcd) or (not gcd and d >= cfg.cdmin)) then
		b.cdEnd = s + d
		b.cdDur = d
		b.cdGcd = gcd
		if not b.incd then
			b.incd = true
			M.cdN = M.cdN + 1
			M.cdList[M.cdN] = b
		end
		if cfg.cdshade or (cfg.cdsweep and not b.cdModel) then
			local c = T.c.bg
			b.shade:SetVertexColor(c[1], c[2], c[3], SHADE_ALPHA)
			b.shade:Show()
		else
			b.shade:Hide()
		end
		startSweep(b, s, d)
		cdPaint(b, GetTime())
	else
		cdClear(b)
	end
end

-- ---------------------------------------------------------------- mise a jour d'un bouton
local function hotText(b)
	local k = GetBindingKey(b.cmd)
	if k then return GetBindingText(k, "KEY_", 1) end
	return ""
end

function M.UpdateBinding(b)
	if cfg.keybinds then setText(b.hot, hotText(b)) else setText(b.hot, "") end
end

-- portee : IsActionInRange (1 / 0 / nil) ; repli UnitXP / SuperWoW pour l'attaque automatique (le jeu n'en donne pas).
local function outOfRange(b)
	local slot = b.slot
	local r = IsActionInRange(slot)
	if r == 0 then return true end
	if r == nil and cfg.unitxp and IsAttackAction and UnitExists("target") and UnitCanAttack("player", "target") then
		local okA, att = pcall(IsAttackAction, slot)
		if okA and att then
			local dist, src = SUI.Api.Distance("target")
			if dist and (src == "xp" or src == "pos") and dist > cfg.melee then return true end
		end
	end
	return false
end

-- ---------------------------------------------------------------- sorts de finition (Execute, Hammer of Wrath)
-- IsUsableAction du 1.12 ignore le seuil de vie de la cible : le bouton paraitrait disponible a 100 %. On reconnait le sort du bouton
-- (nom de macro, icone, ou ligne 1 de l'infobulle SetAction) puis on grise tant que la cible a plus de 20 % de vie (ou n'est pas attaquable).
M.FIN_PCT = 20
local FIN_NAME = { execute = true, execution = true, ["hammer of wrath"] = true, ["marteau de courroux"] = true }
local FIN_TEX = { ["interface\\icons\\inv_sword_48"] = true }    -- icone d'Execute (utilisee seulement hors macro)
M.finCache = {}

local function normSpell(t)
	if type(t) ~= "string" then return "" end
	t = string.lower(t)
	t = string.gsub(t, "\195[\168-\171]", "e")        -- e accentue (UTF-8) -> e
	t = string.gsub(t, "\195[\160-\165]", "a")
	t = string.gsub(t, "\195[\172-\175]", "i")
	t = string.gsub(t, "\195[\178-\182]", "o")
	t = string.gsub(t, "\195[\185-\188]", "u")
	t = string.gsub(t, "\195\167", "c")
	return t
end
M.NormSpell = normSpell

function M.BuildScan()
	if M.scanTip then return M.scanTip end
	local ok, tip = pcall(CreateFrame, "GameTooltip", "ShikiUI_BarScan", nil, "GameTooltipTemplate")
	if ok and tip then M.scanTip = tip end
	return M.scanTip
end

-- Nom du sort d'un emplacement : ligne 1 de l'infobulle (hors combat seulement : cree des chaines).
function M.ScanSpellName(slot)
	local tip = M.BuildScan()
	if not tip or type(tip.SetAction) ~= "function" then return nil end
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	tip:SetAction(slot)
	local fs = getglobal("ShikiUI_BarScanTextLeft1")
	local t = fs and fs:GetText()
	tip:Hide()
	return t
end

-- Le bouton de cet emplacement lance-t-il un sort de finition ? Resultat memorise par (texte de macro, icone) ; en combat on ne scrute pas.
function M.IsFinisher(slot, tex)
	local name = GetActionText(slot)
	if name == "" then name = nil end
	local key = (name or "") .. "|" .. (tex or "")
	local v = M.finCache[key]
	if v ~= nil then return v end
	if name then
		v = FIN_NAME[normSpell(name)] and true or false
	elseif tex and FIN_TEX[string.lower(tex)] then
		v = true
	elseif SUI.InCombat() then
		return false                     -- inconnu : on ne scrute pas en combat, on reessaiera apres
	else
		v = FIN_NAME[normSpell(M.ScanSpellName(slot))] and true or false
	end
	M.finCache[key] = v
	return v
end

-- La cible permet-elle le sort de finition ? (attaquable, vivante, 20 % de vie ou moins). Aucune allocation.
function M.FinisherReady()
	if not UnitExists("target") or not UnitCanAttack("player", "target") then return false end
	local hp, mx = UnitHealth("target"), UnitHealthMax("target")
	if not hp or not mx or mx <= 0 or hp <= 0 then return false end
	return hp * 100 / mx <= M.FIN_PCT
end

-- ---------------------------------------------------------------- POSTURES : DONNEES (extensible)
-- Trois tables a completer sans toucher au code :
--   M.POSTURES       cle de posture -> noms de forme du jeu (minuscules, sans accents, FR et EN : GetShapeshiftFormInfo les rend dans la langue
--                    du client). Les formes sont reconnues par leur NOM : l'indice change selon les formes apprises (druide).
--   M.AURA_POSTURE   texture de buff -> cle (postures qui ne sont pas des formes : camouflage du voleur, forme d'ombre).
--   M.STANCE_SPELLS  classe -> liste d'entrees { need = { cles acceptees }, "Nom EN", "Nom FR", ... } : le sort exige UNE de ces postures.
--                    Noms de sorts (minuscules / accents ignores). Ajout a chaud : M.AddStanceSpells(classe, { cles }, { "Nom", ... }).
-- A VERIFIER EN JEU : tous les noms francais, et chaque exigence (releves de memoire du jeu 1.12, jamais executes). Un sort absent de la
-- liste n'est jamais grise ; Turtle WoW peut avoir change certaines exigences.
M.POSTURES = {
	battle = { "battle stance", "posture de combat" },
	defensive = { "defensive stance", "posture defensive" },
	berserker = { "berserker stance", "posture berserker" },
	bear = { "bear form", "dire bear form", "forme d'ours", "forme d'ours redoutable" },
	cat = { "cat form", "forme de felin" },
	aquatic = { "aquatic form", "forme aquatique" },
	travel = { "travel form", "forme de voyage" },
	moonkin = { "moonkin form", "forme de selenien" },
	tree = { "tree of life", "tree of life form", "arbre de vie", "forme d'arbre de vie" },
	shadowform = { "shadowform", "forme d'ombre" },
	stealth = { "stealth", "camouflage" },
}
M.AURA_POSTURE = {
	["interface\\icons\\ability_stealth"] = "stealth",
	["interface\\icons\\spell_shadow_shadowform"] = "shadowform",
}
M.STANCE_SPELLS = {
	WARRIOR = {
		{ need = { "battle" }, "Charge", "Overpower", "Fulgurance", "Mocking Blow", "Coup railleur", "Retaliation", "Represailles",
			"Sweeping Strikes", "Attaques balayantes", "Frappes balayantes", "Balayage" },
		{ need = { "battle", "defensive" }, "Rend", "Pourfendre", "Shield Bash", "Coup de bouclier" },
		{ need = { "battle", "berserker" }, "Hamstring", "Brise-genou", "Execute", "Execution" },
		{ need = { "defensive" }, "Shield Block", "Maitrise du blocage", "Revenge", "Vengeance", "Taunt", "Provocation", "Disarm",
			"Desarmement", "Shield Wall", "Mur protecteur" },
		{ need = { "berserker" }, "Pummel", "Volee de coups", "Berserker Rage", "Rage berserker", "Recklessness", "Temerite", "Intercept",
			"Interception", "Whirlwind", "Tourbillon" },
	},
	DRUID = {
		{ need = { "bear" }, "Maul", "Mutiler", "Swipe", "Balayage", "Growl", "Grondement", "Demoralizing Roar", "Rugissement demoralisant",
			"Bash", "Sonner", "Enrage", "Enrager", "Frenzied Regeneration", "Regeneration frenetique", "Challenging Roar",
			"Rugissement provocateur", "Feral Charge", "Charge farouche" },
		{ need = { "cat" }, "Claw", "Griffe", "Rake", "Griffure", "Rip", "Dechirure", "Ferocious Bite", "Morsure feroce", "Shred", "Lambeau",
			"Pounce", "Traquenard", "Ravage", "Tiger's Fury", "Fureur du tigre", "Dash", "Ruee", "Cower", "Derobade", "Prowl", "Roder" },
	},
	ROGUE = {
		{ need = { "stealth" }, "Ambush", "Embuscade", "Garrote", "Garrot", "Cheap Shot", "Coup bas", "Pick Pocket", "Vol a la tire" },
	},
	PRIEST = {},     -- Forme d'ombre : posture reconnue (M.POSTURES) mais aucun sort connu pour l'exiger ; a ajouter ici si le serveur en a
	PALADIN = {},    -- aucune aura n'est exigee par un sort en 1.12 ; a ajouter ici au besoin (cle d'aura a declarer dans M.POSTURES)
}
M.stnIdx, M.stnIdxClass, M.stnN = nil, nil, 0

-- Exigence { list = { cles }, set = { cle = true } }
local function makeReq(need)
	local r = { list = need, set = {} }
	for i = 1, getn(need) do r.set[need[i]] = true end
	return r
end

function M.BuildStanceIndex()
	local class = M.class
	if M.stnIdx and M.stnIdxClass == class then return M.stnIdx end
	M.stnIdxClass = class
	local idx = {}
	M.stnIdx = idx
	M.stnN = 0
	local data = class and M.STANCE_SPELLS[class]
	if data then
		for i = 1, getn(data) do
			local e = data[i]
			local req = makeReq(e.need)
			for j = 1, getn(e) do
				idx[normSpell(e[j])] = req
				M.stnN = M.stnN + 1
			end
		end
	end
	return idx
end

-- Ajoute des sorts exigeant l'une des postures `need` pour une classe (jeton anglais) : M.AddStanceSpells("DRUID", { "cat" }, { "Nom" }).
function M.AddStanceSpells(class, need, names)
	local list = M.STANCE_SPELLS[class]
	if not list then
		list = {}
		M.STANCE_SPELLS[class] = list
	end
	local e = { need = need }
	for i = 1, getn(names) do e[i] = names[i] end
	list[getn(list) + 1] = e
	M.stnIdx = nil
	for k in pairs(M.stnCache) do M.stnCache[k] = nil end
	M.dAll = true
end

-- Nom de forme du jeu -> cle de posture (nil si inconnu).
local function postureKey(name)
	if not name then return nil end
	local n = normSpell(name)
	for key, list in pairs(M.POSTURES) do
		for i = 1, getn(list) do
			if list[i] == n then return key end
		end
	end
	return nil
end
M.PostureKey = postureKey

local WAR_FORMS = { "battle", "defensive", "berserker" }
local lowerCache = {}

-- Relit la posture courante : formes (GetShapeshiftFormInfo : nom + actif) puis, pour les classes qui en ont, buffs du joueur
-- (camouflage, forme d'ombre). Appelee sur les evenements de forme / d'aura seulement, jamais a chaque tic.
function M.ReadPosture()
	local _, class = UnitClass("player")
	M.class = class
	for k in pairs(M.formIdx) do M.formIdx[k] = nil end
	for k in pairs(M.formKey) do M.formKey[k] = nil end
	local cur = nil
	for i = 1, M.nforms do
		local _, name, active = GetShapeshiftFormInfo(i)
		local key = postureKey(name)
		if not key and class == "WARRIOR" then key = WAR_FORMS[i] end     -- nom illisible : l'ordre des postures du guerrier est fixe
		if key then
			M.formIdx[key] = i
			M.formKey[i] = key
			if active then cur = key end
		end
	end
	local ub = getglobal("UnitBuff")
	M.auraPosture = (class == "ROGUE" or class == "PRIEST") and type(ub) == "function"
	if not cur and M.auraPosture then
		for i = 1, 32 do
			local tex = ub("player", i)
			if not tex then break end
			local low = lowerCache[tex]
			if not low then
				low = string.lower(tex)
				lowerCache[tex] = low
			end
			local key = M.AURA_POSTURE[low]
			if key then
				cur = key
				break
			end
		end
	end
	M.curPosture = cur
	M.postureReady = not (class == "WARRIOR" and M.nforms == 0)
end

-- La posture courante satisfait-elle l'exigence ? Vrai quand les formes ne sont pas encore lues (on ne grise jamais sur une donnee absente).
function M.PostureOk(req)
	if not M.postureReady then return true end
	local cur = M.curPosture
	return (cur ~= nil and req.set[cur]) and true or false
end

-- Exigence d'un sort lance par macro : premier /cast sans condition du texte, sinon nom de la macro.
function M.MacroReq(name, idx)
	local gi, gm = getglobal("GetMacroIndexByName"), getglobal("GetMacroInfo")
	if type(gi) == "function" and type(gm) == "function" then
		local ok, i = pcall(gi, name)
		if ok and type(i) == "number" and i > 0 then
			local ok2, _, _, body = pcall(gm, i)
			if ok2 and type(body) == "string" then
				for line in string.gfind(body, "[^\n]+") do
					local _, _, rest = string.find(string.lower(line), "^%s*/cast%s+(.*)$")
					if rest and not string.find(rest, "^%[") then
						rest = string.gsub(rest, "%s*%(.-%)%s*$", "")
						rest = string.gsub(rest, "%s+$", "")
						local r = idx[normSpell(rest)]
						if r then return r end
						break
					end
				end
			end
		end
	end
	return idx[normSpell(name)]
end

-- Exigence de posture du sort de cet emplacement (nil = aucune). Resultat memorise par (nom de macro, icone) ; en combat on ne scrute pas
-- l'infobulle : le bouton est relu a la sortie de combat (M.stnPending).
function M.StanceReq(slot, tex)
	local idx = M.BuildStanceIndex()
	if M.stnN == 0 then return nil end
	local name = GetActionText(slot)
	if name == "" then name = nil end
	local key = (name or "") .. "|" .. (tex or "")
	local v = M.stnCache[key]
	if v ~= nil then return v or nil end
	if name then
		v = M.MacroReq(name, idx) or false
	else
		if SUI.InCombat() then
			M.stnPending = true
			return nil
		end
		v = idx[normSpell(M.ScanSpellName(slot))] or false
	end
	M.stnCache[key] = v
	return v or nil
end

-- Libelles : nom court (bouton) et noms longs (infobulle), localises ; le court est memorise (aucune chaine neuve a chaque tic).
function M.StanceShort(key)
	local s = M.shortCache[key]
	if not s then
		s = L("msg.actionbars.stance.short." .. key)
		M.shortCache[key] = s
	end
	return s
end

function M.StanceNames(req)
	local out = ""
	for i = 1, getn(req.list) do
		if i > 1 then out = out .. " / " end
		out = out .. L("msg.actionbars.stance." .. req.list[i])
	end
	return out
end

-- Posture a prendre pour satisfaire l'exigence : indice de forme de la premiere posture exigee que le joueur connait (nil : aucune, ou
-- posture qui n'est pas une forme comme le camouflage).
function M.FormFor(req)
	for i = 1, getn(req.list) do
		local idx = M.formIdx[req.list[i]]
		if idx then return idx end
	end
	return nil
end

-- Libelle de posture d'un bouton de sort : posture manquante (grise) -> nom court de la premiere posture exigee.
function M.StanceLabel(b)
	local txt = ""
	if b.stn and b.stnWrong and (cfg.stancetext == "button" or cfg.stancetext == "both") then txt = M.StanceShort(b.stn.list[1]) end
	setText(b.stnT, txt)
end

function M.UpdateState(b)
	local kind = b.kind
	if kind == "action" then
		if not b.has then
			paintTint(b, 0)
			paintBorder(b, 0)
			return
		end
		local slot = b.slot
		local usable, oom = IsUsableAction(slot)
		local st = 0
		local wrong = (b.stn and cfg.stances and not M.PostureOk(b.stn)) and true or false
		if wrong ~= b.stnWrong then
			b.stnWrong = wrong
			M.StanceLabel(b)
		end
		if wrong then
			st = 4
		elseif b.fin and cfg.finisher and not M.FinisherReady() then
			st = 3
		elseif cfg.range and outOfRange(b) then
			st = 1
		elseif cfg.mana and oom then
			st = 2
		elseif not usable then
			st = 3
		end
		paintTint(b, st)
		local bs = 0
		if IsCurrentAction(slot) or IsAutoRepeatAction(slot) then
			bs = 1
		elseif IsEquippedAction(slot) then
			bs = 2
		end
		paintBorder(b, bs)
	elseif kind == "stance" then
		local _, _, active, castable = GetShapeshiftFormInfo(b.idx)
		local st = 0
		if not castable then st = 3 elseif cfg.stanceind and not active then st = 5 end
		paintTint(b, st)
		paintBorder(b, active and 1 or 0)
		local lab = ""
		if cfg.stanceind and active and M.formKey[b.idx] then lab = M.StanceShort(M.formKey[b.idx]) end
		setText(b.stnT, lab)
	else
		local _, _, _, _, active = GetPetActionInfo(b.idx)
		paintTint(b, 0)
		paintBorder(b, active and 1 or 0)
	end
end

-- Redessine un bouton entier (icone, textes, visibilite) puis son etat et sa recharge.
function M.UpdateButton(b)
	local kind = b.kind
	local has, tex = false, nil
	if kind == "action" then
		has = HasAction(b.slot) and true or false
		if has then tex = GetActionTexture(b.slot) end
	elseif kind == "stance" then
		local icon = GetShapeshiftFormInfo(b.idx)
		tex = icon
		has = (icon ~= nil)
	else
		local name, _, texture, isToken, _, _, autoOn = GetPetActionInfo(b.idx)
		if name then
			has = true
			tex = texture
			if isToken and texture then tex = getglobal(texture) end
			setText(b.auto, autoOn and "A" or "")
		else
			setText(b.auto, "")
		end
	end
	b.has = has
	b.fin = (kind == "action" and has and tex and cfg.finisher and M.IsFinisher(b.slot, tex)) and true or false
	if kind == "action" and has and cfg.stances then b.stn = M.StanceReq(b.slot, tex) else b.stn = nil end
	if not b.stn then
		b.stnWrong = false
		setText(b.stnT, "")
	else
		M.StanceLabel(b)          -- reglage de texte change : libelle relu
	end
	if has and tex then
		b.icon:SetTexture(tex)
		b.vst = nil               -- le jeu peut remettre la teinte a blanc en changeant de texture : on la repeint toujours
		b.icon:Show()
	else
		b.icon:Hide()
	end
	if kind == "action" and has then
		if cfg.macrotext then setText(b.mac, GetActionText(b.slot) or "") else setText(b.mac, "") end
		if cfg.counts and IsConsumableAction(b.slot) then
			setText(b.cnt, tostring(GetActionCount(b.slot)))
		else
			setText(b.cnt, "")
		end
	else
		setText(b.mac, "")
		setText(b.cnt, "")
	end
	local show = b.want and (has or cfg.empty == "show" or M.grid or M.bind)
	if show then b:Show() else b:Hide() end
	M.UpdateBinding(b)
	M.UpdateCooldown(b)
	M.UpdateState(b)
end

-- ---------------------------------------------------------------- clics, glisser, infobulle
function M.Press(b, mouse)
	local kind = b.kind
	if kind == "stance" then
		CastShapeshiftForm(b.idx)
	elseif kind == "pet" then
		if mouse == "RightButton" then TogglePetAutocast(b.idx) else CastPetAction(b.idx) end
	else
		-- posture : un sort exige une autre posture -> on la prend (une pression) plutot que de provoquer l'erreur du jeu. Aucune API
		-- protegee en 1.12 : CastShapeshiftForm est appelable depuis un clic, meme en combat.
		if cfg.autostance and cfg.stances and b.stn and not M.PostureOk(b.stn) then
			local fi = M.FormFor(b.stn)
			if fi then
				CastShapeshiftForm(fi)
				return
			end
		end
		local onself = nil
		if (cfg.altself and IsAltKeyDown()) or (cfg.rightself and mouse == "RightButton") then onself = 1 end
		UseAction(b.slot, 1, onself)
	end
end

function M.OnClick()
	M.Press(this, arg1)
end

function M.OnDragStart()
	local b = this
	if b.kind == "stance" then return end
	if cfg.lockdrag and not IsShiftKeyDown() then return end
	if b.kind == "pet" then PickupPetAction(b.idx) else PickupAction(b.slot) end
end

function M.OnReceiveDrag()
	local b = this
	if b.kind == "stance" then return end
	if b.kind == "pet" then PickupPetAction(b.idx) else PlaceAction(b.slot) end
end

-- Opacite voulue d'une barre = (mode de visibilite : 1, estompee ou 0) x (opacite hors combat ou en combat, reglage general) x (facteur
-- propre a la barre). Pendant la pose de raccourcis et le deplacement d'une action (grille), la barre est montree pleinement.
function M.TargetAlpha(bar)
	local a = 1
	local show = bar.show
	if show == "incombat" then
		-- invisible hors combat ; visible (opaque) en combat, au survol (pour pouvoir deposer un sort) et pendant la mise en place des raccourcis
		if not (M.combat or bar.hover or M.bind) then a = 0 end
	elseif show == "combat" then
		if not (M.combat or bar.hover or M.bind) then a = cfg.fade end
	elseif show == "hover" then
		if not (bar.hover or M.bind) then a = cfg.fade end
	end
	if not (M.bind or M.grid) then
		if M.combat then a = a * cfg.ain * bar.ain else a = a * cfg.aout * bar.aout end
	end
	return a
end

-- Fixe l'opacite cible ; le cadre y glisse par pas (M.FadeStep). Premier affichage, barre venant d'apparaitre : saut direct.
local function hoverAlpha(bar)
	local a = M.TargetAlpha(bar)
	bar.target = a
	if bar.alpha == nil or bar.snap then
		bar.snap = false
		bar.alpha = a
		bar.frame:SetAlpha(a)
	elseif bar.alpha ~= a then
		M.fading = true
	end
end

-- Un pas de fondu pour toutes les barres (minuterie partagee ; sortie immediate au repos, aucune allocation).
function M.FadeStep()
	if not M.fading then return end
	local busy = false
	for i = 1, getn(M.order) do
		local bar = M.bars[M.order[i]]
		local cur, tgt = bar.alpha, bar.target
		if cur and tgt and cur ~= tgt then
			if cur < tgt then
				cur = cur + FADE_STEP
				if cur > tgt then cur = tgt end
			else
				cur = cur - FADE_STEP
				if cur < tgt then cur = tgt end
			end
			bar.alpha = cur
			bar.frame:SetAlpha(cur)
			if cur ~= tgt then busy = true end
		end
	end
	M.fading = busy
end

function M.OnEnter()
	local b = this
	b.bar.hover = true
	M.hoverBtn = b
	hoverAlpha(b.bar)
	local mode = cfg.tooltips
	if mode == "never" or (mode == "safe" and M.combat) or not GameTooltip then return end
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	if b.kind == "stance" then
		GameTooltip:SetShapeshift(b.idx)
	elseif b.kind == "pet" then
		GameTooltip:SetPetAction(b.idx)
	elseif b.has then
		GameTooltip:SetAction(b.slot)
	else
		return
	end
	if b.stn and cfg.stances and (cfg.stancetext == "tooltip" or cfg.stancetext == "both") then
		local c = T.c.dim
		if b.stnWrong then c = T.c.warn end
		GameTooltip:AddLine(L("msg.actionbars.stance.need", M.StanceNames(b.stn)), c[1], c[2], c[3])
	end
	GameTooltip:Show()
end

function M.OnLeave()
	local b = this
	b.bar.hover = false
	if M.hoverBtn == b then M.hoverBtn = nil end
	hoverAlpha(b.bar)
	if GameTooltip then GameTooltip:Hide() end
end

-- ---------------------------------------------------------------- construction (hors combat)
local function newButton(bar, i)
	local d = bar.def
	local f = CreateFrame("Button", "ShikiUI_AB_" .. bar.key .. "_" .. i, bar.frame)
	f.bar, f.idx, f.kind, f.want = bar, i, d.kind, true
	f.cmd = d.bind .. i
	if d.kind == "action" then f.slot = (d.base or M.base) + i end
	f:SetWidth(cfg.size)
	f:SetHeight(cfg.size)
	T.Backdrop(f, T.c.inset, T.c.border)
	f.icon = f:CreateTexture(nil, "ARTWORK")          -- au-dessus du fond du cadre ; le voile est cree apres, donc au-dessus de l'icone
	f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.icon:SetTexCoord(CROP_LO, CROP_HI, CROP_LO, CROP_HI)
	f.shade = f:CreateTexture(nil, "ARTWORK")
	f.shade:SetTexture(T.tex.white)
	f.shade:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)          -- ancre en bas : seule la hauteur suit la recharge (voile qui se vide)
	f.shade:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.shade:SetHeight(cfg.size - 2)
	f.shade:Hide()
	-- balayage circulaire : modele "Cooldown" du jeu (absent ou refuse : repli sur le voile qui se vide)
	local okM, m = pcall(CreateFrame, "Model", nil, f, "CooldownFrameTemplate")
	if okM and m then
		m:SetAllPoints(f)
		m:SetFrameLevel(f:GetFrameLevel() + 1)
		m:EnableMouse(false)
		m:Hide()
		f.cdModel = m
	end
	-- textes dans un cadre au-dessus du balayage (sinon le modele les recouvre) ; ce cadre ne capte pas la souris
	local tf = CreateFrame("Frame", nil, f)
	tf:SetAllPoints(f)
	tf:SetFrameLevel(f:GetFrameLevel() + 3)
	f.txt = tf
	f.hot = T.Text(tf, 9, T.c.text, "RIGHT", true)
	f.hot:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
	f.cnt = T.Text(tf, 10, T.c.text, "RIGHT", true)
	f.cnt:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	f.mac = T.Text(tf, 8, T.c.dim, "CENTER", true)
	f.mac:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 2)
	f.cdt = T.Text(tf, 14, T.c.text, "CENTER", true)
	f.cdt:SetPoint("CENTER", f, "CENTER", 0, 0)
	trackCd(f)
	M.FontCd(f)
	f.stnT = T.Text(tf, 8, T.c.warn, "CENTER", true)          -- posture requise (sort) ou forme active (barre de formes)
	f.stnT:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
	f.auto = T.Text(tf, 9, T.c.good, "LEFT", true)
	f.auto:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnClick", M.OnClick)
	f:SetScript("OnDragStart", M.OnDragStart)
	f:SetScript("OnReceiveDrag", M.OnReceiveDrag)
	f:SetScript("OnEnter", M.OnEnter)
	f:SetScript("OnLeave", M.OnLeave)
	f:Hide()
	return f
end

-- Cree les boutons manquants d'une barre (jamais en combat : la demande est reportee a la sortie de combat).
function M.EnsureButtons(bar)
	local made = false
	while bar.made < bar.nbtn do
		bar.made = bar.made + 1
		bar.btn[bar.made] = newButton(bar, bar.made)
		made = true
	end
	return made
end

function M.LayoutBar(bar)
	local n = M.EffN(bar)
	local size = floor(cfg.size * bar.scale / 100 + 0.5)
	local sp = cfg.spacing
	local per = bar.per
	if per > n then per = n end
	if per < 1 then per = 1 end
	for i = 1, bar.made do
		local b = bar.btn[i]
		if i <= n then
			b.want = true
			b:SetWidth(size)
			b:SetHeight(size)
			local col = SUI.Mod(i - 1, per)
			local row = floor((i - 1) / per)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", PAD + col * (size + sp), -(PAD + row * (size + sp)))
		else
			b.want = false
			b:Hide()
		end
	end
	local rows = ceil(n / per)
	if rows < 1 then rows = 1 end
	bar.frame:SetWidth(PAD * 2 + per * size + (per - 1) * sp)
	bar.frame:SetHeight(PAD * 2 + rows * size + (rows - 1) * sp)
	bar.laidN = n
end

-- Visibilite : barre activee, pas "cachee", et (formes / familier) quelque chose a montrer.
local function wanted(bar)
	if not bar.enabled or bar.show == "never" then return false end
	if bar.kind == "stance" then return M.nforms > 0 end
	if bar.kind == "pet" then return M.petbar end
	return true
end

function M.UpdateVisibility()
	for i = 1, getn(M.order) do
		local bar = M.bars[M.order[i]]
		local want = wanted(bar)
		if want ~= bar.vis then
			bar.vis = want
			bar.snap = true          -- une barre qui apparait prend tout de suite son opacite (pas de fondu depuis l'ancienne valeur)
			if want then bar.frame:Show() else bar.frame:Hide() end
		end
		if want then hoverAlpha(bar) end
	end
end

function M.ReadWorld()
	M.nforms = GetNumShapeshiftForms() or 0
	M.petbar = PetHasActionBar() and true or false
	M.ReadPosture()
end

-- Applique les reglages : lit la config, cree ce qui manque (hors combat), recale la mise en page, marque tout a redessiner.
function M.ApplyOptions()
	if not M.built then return end
	M.ReadConfig()
	for k in pairs(M.shortCache) do M.shortCache[k] = nil end
	local missing = false
	for i = 1, getn(M.order) do
		local bar = M.bars[M.order[i]]
		if bar.enabled and bar.made < bar.nbtn then
			if SUI.InCombat() then
				missing = true
			else
				M.EnsureButtons(bar)
			end
		end
	end
	if missing then
		if not M.warned then
			M.warned = true
			SUI.Print(L("msg.actionbars.combat"))
		end
		SUI.WhenSafe(M.ApplyOptions)
	else
		M.warned = false
	end
	M.ReadWorld()
	for i = 1, getn(M.order) do
		local bar = M.bars[M.order[i]]
		if bar.made > 0 then
			M.LayoutBar(bar)
			for j = 1, bar.made do
				bar.btn[j].cdtier = nil           -- couleur et taille du chiffre relues tout de suite
				M.FontCd(bar.btn[j])
			end
		end
	end
	M.Rebase()
	-- masquage des barres de Blizzard : s'applique tout de suite a l'activation du reglage (le retablir demande un /reload)
	if cfg.hideblizz then M.HideBlizzard() end
	-- micro-menu et barre d'experience : leurs reglages (echelle, colonnes, espacement, opacite, affichage) s'appliquent tout de suite
	if not M.micro then M.BuildMicro() end
	M.ApplyMicro()
	if M.StyleXpBars then M.StyleXpBars() end
	M.dAll, M.dVis, M.dBind = true, true, true
	M.UpdateVisibility()
	M.Tick()                 -- reglage change par l'utilisateur : effet immediat (cout negligeable, aucune creation)
end

-- Masque les barres de Blizzard (une fois par session ; rechargement pour les rendre). Sans effet si pfUI fait tourner son equivalent.
local function kill(f)
	if f.UnregisterAllEvents then f:UnregisterAllEvents() end
	if f.Show then f.Show = noop end
	if f.Hide then f:Hide() end
end

-- Barres d'experience / de reputation de Blizzard : sans ce traitement elles restent accrochees a la barre principale d'origine
-- (masquee) et traversent l'ecran par-dessus les barres de ShikiUI. "slim" les amincit et les colle au bord bas de l'ecran,
-- "hide" les cache, "blizz" ne les touche pas. Les textures decoratives sont cachees, la barre de couleur reste fonctionnelle.
local XPTEX = { "MainMenuXPBarTexture0", "MainMenuXPBarTexture1", "MainMenuXPBarTexture2", "MainMenuXPBarTexture3",
	"MainMenuBarMaxLevelBar", "ReputationWatchBarTexture0", "ReputationWatchBarTexture1", "ReputationWatchBarTexture2",
	"ReputationWatchBarTexture3", "ReputationXPBarTexture0", "ReputationXPBarTexture1", "ReputationXPBarTexture2",
	"ReputationXPBarTexture3" }
-- Ancrage des barres XP / reputation : via le moteur de mise en page ("bars.xp" / "bars.rep") pour qu'elles
-- soient DEPLACABLES comme le reste (Mover, presets), et non plus collee en dur. Pleine largeur conservee :
-- le second ancre (BOTTOMRIGHT) est repose apres chaque placement (hook apply du Mover). Les appels repetes
-- (reglages a chaud) re-appliquent la position enregistree sans reenregistrer.
local function pin(f, key, x, y, h)
	f:SetParent(UIParent)
	f:SetHeight(h)
	if SUI.Mover and SUI.Mover.Register and SUI.Layout then
		local function wide()
			f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
		end
		if not (SUI.Layout.items and SUI.Layout.items[key]) then
			SUI.Mover.Register(key, f, { point = "BOTTOMLEFT", x = 0, y = y, apply = wide })
		end
		SUI.Layout.Apply(key)
		wide()
	else
		f:ClearAllPoints()
		f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
		f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -x, y)
	end
end

-- toutes les textures decoratives d'une barre (le jeu les raffiche a chaque mise a jour) ; la texture de remplissage reste
local function stripArt(f)
	local keep = f.GetStatusBarTexture and f:GetStatusBarTexture() or nil
	local r = { f:GetRegions() }
	for i = 1, getn(r) do
		local t = r[i]
		if t ~= keep and t.GetObjectType and t:GetObjectType() == "Texture" then t:Hide() t.Show = noop end
	end
end

-- Masque / rend une barre sans toucher a ses evenements (reversible : on retire seulement notre Show neutralise).
local function hideBar(f)
	if not f.suiShow then f.suiShow = f.Show end
	f:Hide()
	f.Show = noop
end

local function unhideBar(f, keepHidden)
	if f.suiShow then f.Show = f.suiShow end
	if not keepHidden then f:Show() end
end

-- Modes "slim" et "hide" : reglables a chaud l'un vers l'autre. Le retour a "blizz" (ancres d'origine perdues) demande un /reload.
function M.StyleXpBars()
	local mode = cfg.xpbar
	if mode == "blizz" or not mode then return end
	if M.xpDone == mode then return end
	if SUI.Migrate and SUI.Migrate.Running and SUI.Migrate.Running("actionbar") then return end
	local before = M.xpDone
	M.xpDone = mode
	local xp = getglobal("MainMenuExpBar")
	local rep = getglobal("ReputationWatchBar")
	if mode == "hide" then
		-- les textures decoratives (cadre metallique long) sont aussi a cacher : au niveau maximum elles restent a l'ecran meme si la barre est cachee
		for i = 1, getn(XPTEX) do
			local t = getglobal(XPTEX[i])
			if t and t.Hide then t:Hide() t.Show = noop end
		end
		if xp then pcall(hideBar, xp) end
		if rep then pcall(hideBar, rep) end
		return
	end
	if before == "hide" then
		if xp then pcall(unhideBar, xp) end
		if rep then
			local watched = true
			local gw = getglobal("GetWatchedFactionInfo")
			if type(gw) == "function" then watched = gw() ~= nil end
			pcall(unhideBar, rep, not watched)
		end
		if M.xpSlim then return end
	end
	M.xpSlim = true
	for i = 1, getn(XPTEX) do
		local t = getglobal(XPTEX[i])
		if t and t.Hide then t:Hide() t.Show = noop end
	end
	if xp then pcall(stripArt, xp) end
	if rep then pcall(stripArt, rep) end
	-- Barre d'experience TOUJOURS visible en mode "fine" (meme au niveau maximum : elle est vide mais presente,
	-- l'utilisateur qui ne la veut pas choisit "Masquee"). La reputation suivie reste juste au-dessus.
	if xp then pcall(pin, xp, "bars.xp", 0, 0, 5) end
	if rep then pcall(pin, rep, "bars.rep", 0, 5, 5) end
end

function M.HideBlizzard()
	if M.killed or not cfg.hideblizz then return end
	M.StyleXpBars()
	if SUI.Migrate and SUI.Migrate.Running and SUI.Migrate.Running("actionbar") then return end
	M.killed = true
	for i = 1, getn(BLIZZ) do
		local f = getglobal(BLIZZ[i])
		if f then pcall(kill, f) end
	end
	for i = 1, 12 do
		local f = getglobal("ActionButton" .. i)
		if f then pcall(kill, f) end
	end
end

-- Micro-menu du jeu (Personnage, Sorts, Talents, Quetes, Social, Carte, Menu, Aide) : ces boutons sont des enfants de la barre d'art
-- de Blizzard que ShikiUI masque ; on les range dans une barre ShikiUI deplacable ("Micro-menu" dans /sui move).
local MICRO = { "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton", "SocialsMicroButton",
	"WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton" }
-- Enregistre le micro-menu aupres du gestionnaire de positions : l'echelle effective = reglage du module x echelle du Mover.
function M.RegisterMicro(f)
	SUI.Layout.Register(f, "bars.micro", "BOTTOMRIGHT", -4, 12)       -- au-dessus de la barre d'experience fine (5 px) et de la reputation (5 px)
	local it = SUI.Layout.items["bars.micro"]
	if it then it.mul = function() return (cfg.microscale or 100) / 100 end end
end

function M.BuildMicro()
	if M.micro or not cfg.hideblizz then return end
	if SUI.Migrate and SUI.Migrate.Running and SUI.Migrate.Running("actionbar") then return end
	local f = CreateFrame("Frame", "ShikiUI_Micro", UIParent)
	T.Backdrop(f, T.c.bg, T.c.border)
	f:SetFrameStrata("MEDIUM")
	M.micro = f
	M.microBtn = {}
	for i = 1, getn(MICRO) do
		local b = getglobal(MICRO[i])
		if b then
			b:SetParent(f)
			b:SetFrameLevel(f:GetFrameLevel() + 2)
			-- la texture du jeu (28 x 58) est vide sur sa moitie haute : sans ceci le haut d'un bouton de la ligne suivante recouvre et vole
			-- les clics du bas des boutons de la ligne du dessus
			if b.SetHitRectInsets then b:SetHitRectInsets(0, 0, 18, 0) end
			b:Show()
			tinsert(M.microBtn, b)
		end
	end
	M.RegisterMicro(f)
	M.ApplyMicro()
end

-- Taille (echelle), colonnes, espacement, opacite et affichage du micro-menu.
function M.ApplyMicro()
	local f = M.micro
	if not f then return end
	if cfg.micro == "never" then f:Hide() return end
	local n = getn(M.microBtn)
	local cols = cfg.microcols
	if cols < 1 then cols = 1 end
	if cols > n then cols = n end
	local sp = cfg.microspace
	local rows = floor((n + cols - 1) / cols)
	local bw, bh = 28, 40            -- partie visible d'un bouton (la texture du jeu fait 28 x 58, la moitie haute est vide)
	for i = 1, n do
		local b = M.microBtn[i]
		local col = SUI.Mod(i - 1, cols)
		local row = floor((i - 1) / cols)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 4 + col * (bw + sp), 14 - row * (bh + sp))
	end
	f:SetWidth(8 + cols * bw + (cols - 1) * sp)
	f:SetHeight(6 + rows * bh + (rows - 1) * sp)
	SUI.Layout.Apply("bars.micro")           -- echelle = reglage du module x echelle du Mover (plus de conflit : la taille ne saute plus)
	f:SetAlpha(cfg.microalpha / 100)
	f:Show()
end

function M.Build()
	if M.built then return end
	M.ReadConfig()
	for i = 1, getn(M.order) do
		local k = M.order[i]
		local d = DEF[k]
		local f = CreateFrame("Frame", "ShikiUI_Bar_" .. k, UIParent)
		T.Backdrop(f, T.c.bg, T.c.border)
		f:SetWidth(40)
		f:SetHeight(40)
		local bar = { key = k, def = d, kind = d.kind, frame = f, btn = {}, made = 0, vis = false, hover = false }
		M.bars[k] = bar
		SUI.Layout.Register(f, d.kLayout, d.pt, d.x, d.y)
		f:Hide()
	end
	M.built = true
	T.OnAccent(M.OnStyle)
	M.HideBlizzard()
	M.BuildMicro()
	M.ApplyOptions()
end

-- Style change a chaud : teintes / bordures relues, ombres de recharge repeintes.
function M.OnStyle()
	if not M.built then return end
	for i = 1, getn(M.order) do
		local bar = M.bars[M.order[i]]
		for j = 1, bar.made do
			local b = bar.btn[j]
			b.vst, b.bst = nil, nil
		end
	end
	M.dAll = true
end

-- ---------------------------------------------------------------- minuterie partagee
local function forEachShown(fn)
	for i = 1, getn(M.order) do
		local bar = M.bars[M.order[i]]
		if bar.vis then
			for j = 1, bar.made do
				local b = bar.btn[j]
				if b.want then fn(b) end
			end
		end
	end
end

function M.Tick()
	if not M.built then return end
	M.tickN = M.tickN + 1
	if M.dBase then
		M.dBase = false
		M.ReadWorld()
		M.Rebase()
	end
	if M.dPost then
		M.dPost = false
		M.ReadPosture()
		M.dState = true
	end
	if M.dVis then
		M.dVis = false
		M.UpdateVisibility()
	end
	if M.dAll then
		M.dAll = false
		M.dState, M.dCd, M.dBind = false, false, false
		for k in pairs(M.dSlot) do M.dSlot[k] = nil end
		for i = 1, getn(M.order) do
			local bar = M.bars[M.order[i]]
			if bar.made > 0 and bar.laidN ~= M.EffN(bar) then M.LayoutBar(bar) end
		end
		forEachShown(M.UpdateButton)
	else
		if next(M.dSlot) then
			for i = 1, getn(M.order) do
				local bar = M.bars[M.order[i]]
				if bar.vis and bar.kind == "action" then
					for j = 1, bar.made do
						local b = bar.btn[j]
						if b.want and M.dSlot[b.slot] then M.UpdateButton(b) end
					end
				end
			end
			for k in pairs(M.dSlot) do M.dSlot[k] = nil end
		end
		if M.dBind then
			M.dBind = false
			forEachShown(M.UpdateBinding)
		end
		if M.dCd then
			M.dCd = false
			forEachShown(M.UpdateCooldown)
		end
	end
	-- etat (portee, ressource, forme active) : sur demande, et une fois sur deux sinon ; recharges relues toutes les 0,5 s par prudence
	if M.dState or SUI.Mod(M.tickN, 2) == 0 then
		M.dState = false
		forEachShown(M.UpdateState)
	end
	if SUI.Mod(M.tickN, 5) == 0 then forEachShown(M.UpdateCooldown) end
	if M.cdN > 0 then
		local now = GetTime()
		local i = 1
		while i <= M.cdN do
			local b = M.cdList[i]
			cdPaint(b, now)
			if M.cdList[i] == b then i = i + 1 end
		end
	end
end

-- ---------------------------------------------------------------- evenements
local EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN",
	"ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "PET_BAR_UPDATE",
	"PET_BAR_UPDATE_COOLDOWN", "UNIT_PET", "UPDATE_BINDINGS", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_HEALTH", "PLAYER_AURAS_CHANGED" }

-- Relecture differee de l'etat des boutons de forme (l'aura / la forme active n'est parfois a jour que quelques dixiemes de seconde apres l'evenement).
function M.LateState()
	if M.lateTask then return end
	M.lateTask = SUI.After(0.4, function()
		M.lateTask = nil
		M.dState = true
	end, "actionbars.late")
end

function M.OnEvent(ev, a1)
	if ev == "ACTIONBAR_SLOT_CHANGED" then
		if a1 and a1 ~= 0 then M.dSlot[a1] = true else M.dAll = true end
	elseif ev == "ACTIONBAR_UPDATE_STATE" or ev == "ACTIONBAR_UPDATE_USABLE" or ev == "PLAYER_TARGET_CHANGED" then
		M.dState = true
	elseif ev == "UNIT_HEALTH" then
		if a1 == "target" and cfg.finisher then M.dState = true end
	elseif ev == "ACTIONBAR_UPDATE_COOLDOWN" or ev == "PET_BAR_UPDATE_COOLDOWN" then
		M.dCd = true
	elseif ev == "ACTIONBAR_PAGE_CHANGED" or ev == "UPDATE_BONUS_ACTIONBAR" then
		M.dBase = true
	elseif ev == "UPDATE_SHAPESHIFT_FORM" or ev == "UPDATE_SHAPESHIFT_FORMS" then
		M.dBase, M.dAll, M.dVis = true, true, true
		M.LateState()
	elseif ev == "PET_BAR_UPDATE" or (ev == "UNIT_PET" and a1 == "player") then
		M.dBase, M.dAll, M.dVis = true, true, true
	elseif ev == "UPDATE_BINDINGS" then
		M.dBind = true
	elseif ev == "ACTIONBAR_SHOWGRID" then
		M.grid = true
		M.dAll, M.dVis = true, true
	elseif ev == "ACTIONBAR_HIDEGRID" then
		M.grid = false
		M.dAll, M.dVis = true, true
	elseif ev == "PLAYER_REGEN_DISABLED" then
		M.combat = true
		M.dVis = true
	elseif ev == "PLAYER_AURAS_CHANGED" then
		if M.auraPosture then M.dPost = true end
		-- paladin : les auras sont des "formes" ; le client met l'aura active a jour APRES l'evenement -> etat des boutons relu tout de suite puis un peu plus tard
		if M.class == "PALADIN" and (M.nforms or 0) > 0 then
			M.dState = true
			M.LateState()
		end
	elseif ev == "PLAYER_REGEN_ENABLED" then
		M.combat = false
		M.dVis = true
		if M.stnPending then
			M.stnPending = false
			M.dAll = true
		end
	elseif ev == "PLAYER_ENTERING_WORLD" then
		M.dBase, M.dAll, M.dVis = true, true, true
	end
end

function M.OnKey(key, value)
	-- seuls retours en arriere qui ne peuvent pas se faire a chaud : le jeu a perdu ses ancres / ses evenements
	if (key == "actionbars.hideblizz" and value == false and M.killed) or (key == "actionbars.xpbar" and value == "blizz" and M.xpDone) then
		SUI.Print(L("msg.reload"))
	end
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- raccourcis par survol (service SUI.Bind, voir Bind.lua)
-- Les boutons de ces barres se declarent au service (champ cmd) ; le mode lui-meme (survol, touche, conflit, annuler, enregistrement) est celui du service.
SUI.Bind.AddResolver(function(f)
	if f.bar and f.cmd and f.kind then return f.cmd end
	return nil
end)

SUI.Bind.Watch(function(on)
	M.bind = on and true or false
	M.dAll, M.dVis = true, true
end)

function M.SetBindMode(on)
	if on then
		if not M.on then return end
		SUI.Bind.Enter()
	else
		SUI.Bind.Exit(true)
	end
end

-- ---------------------------------------------------------------- cycle de vie
function M.Enable()
	M.on = true
	M.combat = SUI.InCombat()
	SUI.WhenSafe(M.Build)
	for i = 1, getn(EVENTS) do SUI.On(EVENTS[i], M.OnEvent) end
	M.task = SUI.Every(TICK, M.Tick, "actionbars.tick", true)
	M.fadeTask = SUI.Every(FADE_TICK, M.FadeStep, "actionbars.fade", true)
	if not M.watching then
		M.watching = true
		C.Watch("actionbars.", M.OnKey)
	end
	if M.built then
		for i = 1, getn(M.order) do M.bars[M.order[i]].vis = nil end
		M.ApplyOptions()
	end
end

function M.Disable()
	M.on = false
	SUI.Cancel(M.task)
	M.task = nil
	SUI.Cancel(M.fadeTask)
	M.fadeTask = nil
	M.fading = false
	for i = 1, getn(EVENTS) do SUI.Off(EVENTS[i], M.OnEvent) end
	if M.bind then SUI.Bind.Exit(true) end
	if M.built then
		for i = 1, getn(M.order) do
			local bar = M.bars[M.order[i]]
			bar.frame:Hide()
			bar.vis = false
		end
	end
end

-- ---------------------------------------------------------------- commande /sui bars
function M.Command(rest)
	local _, _, sub, arg = string.find(rest or "", "^%s*(%S*)%s*(.*)$")
	sub = string.lower(sub or "")
	if sub == "page" then
		local n = tonumber(arg)
		if not n or n < 1 or n > (NUM_ACTIONBAR_PAGES or 6) then
			SUI.Print(L("msg.actionbars.usage"))
			return
		end
		ChangeActionBarPage(floor(n))
		SUI.Print(L("msg.actionbars.page", floor(n)))
	elseif sub == "bind" then
		M.SetBindMode(not M.bind)
	elseif sub == "" then
		local bars, btns = 0, 0
		for i = 1, getn(M.order) do
			local bar = M.bars[M.order[i]]
			if bar and bar.vis then
				bars = bars + 1
				btns = btns + M.EffN(bar)
			end
		end
		SUI.Print(L("msg.actionbars.status", bars, btns, M.page))
	else
		SUI.Print(L("msg.actionbars.usage"))
	end
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("actionbars", 20)

local OPTS = {
	{ key = "actionbars.size", type = "number", min = 24, max = 56, step = 2, default = 36, simple = true },
	{ key = "actionbars.spacing", type = "number", min = 0, max = 12, step = 1, default = 3 },
	{ key = "actionbars.keybinds", type = "bool", default = true, simple = true },
	{ key = "actionbars.macrotext", type = "bool", default = true },
	{ key = "actionbars.counts", type = "bool", default = true },
	{ key = "actionbars.cooldowns", type = "bool", default = true, simple = true },
	{ key = "actionbars.cdmin", type = "number", min = 0, max = 5, step = 0.5, default = 2 },
	{ key = "actionbars.cdshade", type = "bool", default = true },
	{ key = "actionbars.showgcd", type = "bool", default = true },
	{ key = "actionbars.cdsweep", type = "bool", default = true },
	{ key = "actionbars.cdsize", type = "number", min = 8, max = 24, step = 1, default = 14 },
	{ key = "actionbars.cdtextmax", type = "number", min = 0, max = 600, step = 10, default = 0 },
	{ key = "actionbars.cdcolor", type = "bool", default = true },
	{ key = "actionbars.range", type = "bool", default = true, simple = true },
	{ key = "actionbars.mana", type = "bool", default = true },
	{ key = "actionbars.finisher", type = "bool", default = true },
	{ key = "actionbars.stances", type = "bool", default = true, simple = true },
	{ key = "actionbars.stancetext", type = "choice", choices = { "never", "tooltip", "button", "both" }, default = "tooltip" },
	{ key = "actionbars.autostance", type = "bool", default = false },
	{ key = "actionbars.stanceind", type = "bool", default = true },
	{ key = "actionbars.unitxp", type = "bool", default = true },
	{ key = "actionbars.melee", type = "number", min = 3, max = 12, step = 1, default = 5 },
	{ key = "actionbars.empty", type = "choice", choices = { "show", "drag" }, default = "show" },
	{ key = "actionbars.lockdrag", type = "bool", default = false },
	{ key = "actionbars.altself", type = "bool", default = false },
	{ key = "actionbars.rightself", type = "bool", default = false },
	{ key = "actionbars.tooltips", type = "choice", choices = { "always", "safe", "never" }, default = "always" },
	{ key = "actionbars.fade", type = "number", min = 0, max = 100, step = 5, default = 25 },
	{ key = "actionbars.alphaout", type = "number", min = 0, max = 100, step = 5, default = 100, simple = true },
	{ key = "actionbars.alphain", type = "number", min = 0, max = 100, step = 5, default = 100, simple = true },
	{ key = "actionbars.autopage", type = "bool", default = true },
	{ key = "actionbars.hideblizz", type = "bool", default = true },
	{ key = "actionbars.micro", type = "choice", choices = { "always", "never" }, default = "always" },
	{ key = "actionbars.micro.scale", type = "number", min = 50, max = 200, step = 5, default = 100 },
	{ key = "actionbars.micro.cols", type = "number", min = 1, max = 8, step = 1, default = 8 },
	{ key = "actionbars.micro.space", type = "number", min = 0, max = 12, step = 1, default = 1 },
	{ key = "actionbars.micro.alpha", type = "number", min = 20, max = 100, step = 5, default = 100 },
	{ key = "actionbars.xpbar", type = "choice", choices = { "slim", "hide", "blizz" }, default = "slim" },
}
local options = {}
for i = 1, getn(OPTS) do
	local o = OPTS[i]
	o.cat = "actionbars"
	o.label = "opt." .. o.key
	o.tip = "tip." .. o.key
	o.order = i * 10
	options[getn(options) + 1] = o
end
for i = 1, getn(M.order) do
	local d = DEF[M.order[i]]
	local o0 = 1000 + i * 100
	local list = {
		{ key = d.kEnabled, type = "bool", default = d.en, simple = (d.key == "bar2" or d.key == "bar3") },
		{ key = d.kShow, type = "choice", choices = { "always", "combat", "incombat", "hover", "never" }, default = "always",
			simple = (d.key == "main" or d.key == "bar2" or d.key == "bar3") },
		{ key = d.kButtons, type = "number", min = 1, max = d.max, step = 1, default = d.n },
		{ key = d.kPer, type = "number", min = 1, max = d.max, step = 1, default = d.per },
		{ key = d.kScale, type = "number", min = 50, max = 150, step = 5, default = 100 },
		{ key = d.kAOut, type = "number", min = 0, max = 100, step = 5, default = 100 },
		{ key = d.kAIn, type = "number", min = 0, max = 100, step = 5, default = 100 },
	}
	for j = 1, getn(list) do
		local o = list[j]
		o.cat = "actionbars"
		o.label = "opt." .. o.key
		o.tip = "tip." .. o.key
		o.order = o0 + j
		options[getn(options) + 1] = o
	end
end

SUI.RegisterModule("actionbars", {
	default = false,         -- mise au point : rien n'a ete verifie en jeu ; l'utilisateur l'active (ou /sui migrate take actionbars)
	cost = "medium",
	options = options,
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Remplace le module "actionbar" de pfUI : ShikiUI attend tant que pfUI le fait tourner (voir Migrate.lua).
if SUI.Migrate and SUI.Migrate.MAP then SUI.Migrate.MAP.actionbars = { "actionbar" } end

-- Mode Raid : infobulles sobres hors combat seulement, barres laterales estompees (l'utilisateur peut tout rallumer).
SUI.Config.AddPreset("raid", "*", { ["actionbars.tooltips"] = "safe", ["actionbars.bar4.show"] = "hover", ["actionbars.bar5.show"] = "hover" })

SUI.RegisterCommand("bars", M.Command, "help.actionbars")
