-- ShikiUI PallyPower : benedictions de raid pour paladin (module "pallypower"), dans l'esprit de PallyPower (addon 1.12 original :
-- reconnaissance du CONCEPT d'attribution par grille ; aucun code copie, tout reecrit).
-- Ce que fait le module :
--   1. Fenetre de grille : chaque membre du raid = une ligne, 5 benedictions en colonnes (Kings, Wisdom, Might, Salvation, Light).
--      Clic sur une case = attribuer / retirer CETTE benediction A CE joueur ; clic droit = retirer. En-tete : un bouton par
--      benediction (tout le monde / personne) et un bouton par classe presente (jeu par defaut de la classe, clic droit = vider).
--      Les attributions restent propres a ce module : jamais posees automatiquement, memoire dans ShikiUIDB (global).
--   2. Bouton "Benir" / touche (Bindings.xml SHIKIUI_PALLYPOWER, /sui pp cast) : pose a CHAQUE joueur ses benedictions attribuees,
--      UNE par tour (GCD 1,1 s), en sautant ceux qui l'ont deja (UnitBuff, simple OU greater : jamais reposee par-dessus). Greater
--      (option ; 30 min sur ce serveur) ou simple (10 min) selon le reglage pp.greater. Fonctionne EN combat (benedictions d'urgence).
--   3. Jugement (option pp.judge) : none / light / wisdom / crusader, pose sur la cible courante au demarrage du cycle.
-- NON VERIFIE EN JEU : noms des sorts (client ANGLAIS, meme limite assume que Mod_Totems ; un client francais ne trouvera pas les
--   benedictions), les 9 retours de GetRaidRosterInfo (var 6 = nom de classe EN, releve dans RaidTools), CastSpellByName(spell, unit)
--   sans SuperWoW (methode par echange de cible, comme le soin au clic), Bindings.xml charge par le client sans entree de .toc
--   (convention du dossier d'addon). Pas de synchronisation entre paladins (protocole addon : version 2). Benes de combat (Protection,
--   Liberte, Sacrifice) hors grille : elles se lient au clic via le module Soins au clic.
-- Cout declare : "medium" (grille construite UNE fois hors combat ; fenetre fermee = aucune minuterie, aucune lecture).
-- Lua 5.0 : pas de '#', '%', '...', select, string.match ; au plus 32 valeurs externes par fonction ; aucune globale non declaree.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.PallyPower = M

local getn, tinsert = table.getn, table.insert
local floor, mmin, mmax = math.floor, math.min, math.max
local sfind, slower, sgsub, strsub = string.find, string.lower, string.gsub, string.sub
local EMPTY = ""

-- Pliage d'accents (UTF-8 FR -> lettres pures) : comparaisons de noms de buffs en plie.
-- Les cles sont les sequences UTF-8 FR en decimales : \195\169 = e accentue, etc.
local PLAIN = {
	["\195\160"] = "a", ["\195\162"] = "a", ["\195\164"] = "a", ["\195\167"] = "c", ["\195\168"] = "e",
	["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e", ["\195\174"] = "i", ["\195\175"] = "i",
	["\195\180"] = "o", ["\195\182"] = "o", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\188"] = "u",
	["\195\156"] = "u", ["\195\138"] = "e", ["\195\137"] = "e", ["\195\136"] = "e", ["\195\139"] = "e",
	["\195\135"] = "c", ["\195\142"] = "i", ["\195\143"] = "i", ["\195\148"] = "o", ["\195\150"] = "o",
	["\195\153"] = "u", ["\195\128"] = "a", ["\195\130"] = "a", ["\195\132"] = "a", ["\195\147"] = "o",
	["\195\146"] = "a", ["\195\149"] = "o", ["\195\154"] = "u", ["\195\161"] = "a", ["\195\163"] = "a",
	["\195\165"] = "a", ["\195\166"] = "a", ["\195\173"] = "i", ["\195\176"] = "o", ["\195\178"] = "o",
	["\195\177"] = "n", ["\195\145"] = "n", ["\195\152"] = "o", ["\195\151"] = "o",
}
local function fold(s)
	local out = slower(s)
	out = sgsub(out, "\195[\128-\191]", PLAIN)
	return out
end
local GAMEFR = (getglobal("GetLocale") and getglobal("GetLocale")() == "frFR") and true or false
M.GAMEFR = GAMEFR

M.on = false
M.win = nil
M.roster = {}            -- { { name, unit, file } } dans l'ordre du raid
M.nrost = 0
M.assign = nil           -- name -> { kings = true, ... } (persiste dans ShikiUIDB.global.pallypower.assign)
M.pairs = {}             -- file du cycle en cours : { unit, name, base, who }
M.npairs, M.qi = 0, 0
M.task = nil
M.castn = 0              -- benedictions posees depuis le debut du cycle
M.offset = 0             -- defilement de la grille
M.view = 22              -- lignes visibles
M.buffNames = {}         -- [unite] = { ["blessing of kings"] = true, ... } : noms des buffs lus par tour du cycle
M.tip = nil              -- infobulle cachee pour lire les noms de buffs (creee hors combat, voir EnsureTip)

-- Benedictions attribuables (noms EN du client) ; ordre de pose. [donnees du jeu]
M.BLESS = { "kings", "wisdom", "might", "salvation", "light" }
M.SPELLS = { kings = "Blessing of Kings", wisdom = "Blessing of Wisdom", might = "Blessing of Might",
	salvation = "Blessing of Salvation", light = "Blessing of Light" }
-- Jeux par defaut d'une classe (bouton de classe). [donnees du jeu]
M.CLASSDEF = {
	WARRIOR = { kings = true, might = true }, ROGUE = { kings = true, might = true }, HUNTER = { kings = true, might = true },
	MAGE = { kings = true, wisdom = true }, WARLOCK = { kings = true, wisdom = true }, PRIEST = { kings = true, wisdom = true },
	DRUID = { kings = true, wisdom = true }, SHAMAN = { kings = true, wisdom = true }, PALADIN = { wisdom = true },
}
M.JUDGES = { none = EMPTY, light = "Judgement of Light", wisdom = "Judgement of Wisdom", crusader = "Judgement of Crusader" }
M.GREATERPFX = "Greater "
-- Noms FR (client frFR depuis OctoWow) : incantations, jugements et lecture d'infobulle selon la langue du jeu.
-- Sequences d'echappement ASCII : \195\169 = e accentue, etc. (comparaisons faites en plie, voir fold plus bas).
M.SPELLS_FR = { kings = "Ben\195\169diction des Rois", wisdom = "Ben\195\169diction de Sagesse", might = "Ben\195\169diction de Puissance",
	salvation = "Ben\195\169diction de Salut", light = "Ben\195\169diction de Lumi\195\168re" }
M.GREATER_FR = "Ben\195\169diction sup\195\169rieure "
M.SPELLS_GFR = { kings = "Ben\195\169diction sup\195\169rieure des Rois", wisdom = "Ben\195\169diction sup\195\169rieure de Sagesse", might = "Ben\195\169diction sup\195\169rieure de Puissance", salvation = "Ben\195\169diction sup\195\169rieure de Salut", light = "Ben\195\169diction sup\195\169rieure de Lumi\195\168re" }
M.JUDGES_FR = { light = "Jugement de Lumi\195\168re", wisdom = "Jugement de Sagesse", crusader = "Jugement du crois\195\169" }
M.ROWS = 40
M.MAXCLASS = 10

-- ---------------------------------------------------------------- attributions
function M.LoadAssign()
	local db = C.GetGlobal("pallypower.assign")
	if type(db) ~= "table" then
		db = {}
		C.SetGlobal("pallypower.assign", db)
	end
	M.assign = db
end

local function asg(name)
	local a = M.assign[name]
	if not a then
		a = {}
		M.assign[name] = a
	end
	return a
end

function M.Has(name, b)
	local a = M.assign[name]
	return a and a[b] and true or false
end

local function saveAssign()
	C.SetGlobal("pallypower.assign", M.assign)
end

function M.Toggle(name, b, want)
	local a = asg(name)
	if want == nil then want = not a[b] end
	if want then a[b] = true else a[b] = nil end
	saveAssign()
	M.PaintCells()
end

-- Bouton de classe : attr (jeu par defaut) ou vider la classe.
function M.SetClass(file, attr)
	for i = 1, M.nrost do
		local r = M.roster[i]
		if r.file == file then
			local a = asg(r.name)
			for k in pairs(a) do a[k] = nil end
			if attr then
				local d = M.CLASSDEF[file]
				if d then
					for k, v in pairs(d) do
						if v then a[k] = true end
					end
				end
			end
		end
	end
	saveAssign()
	M.PaintCells()
end

function M.SetAll(b, want)
	for i = 1, M.nrost do
		local a = asg(M.roster[i].name)
		if want then a[b] = true else a[b] = nil end
	end
	saveAssign()
	M.PaintCells()
end

function M.ClearAll()
	for _, a in pairs(M.assign) do
		for k in pairs(a) do a[k] = nil end
	end
	saveAssign()
	M.PaintCells()
end

-- Classes presentes dans le raid, sans doublon.
M.classes = {}

function M.ScanClasses()
	for k in pairs(M.classes) do M.classes[k] = nil end
	for i = 1, M.nrost do
		local f = M.roster[i].file
		if f and not M.classes[f] then M.classes[f] = true end
	end
end

-- ---------------------------------------------------------------- liste du raid
local function rosterAdd(name, unit, file)
	for i = 1, M.nrost do
		if M.roster[i].name == name then return end
	end
	if M.nrost >= M.ROWS then return end
	M.nrost = M.nrost + 1
	M.roster[M.nrost] = { name = name, unit = unit, file = file or "WARRIOR" }
end

function M.ScanRoster()
	M.nrost = 0
	local nr = 0
	local gnr = getglobal("GetNumRaidMembers")
	if type(gnr) == "function" then nr = gnr() or 0 end
	if nr > 0 then
		local gri = getglobal("GetRaidRosterInfo")
		for i = 1, nr do
			if gri then
				local name, _, _, _, _, file = gri(i)
				if name then rosterAdd(name, "raid" .. i, file) end
			end
		end
	else
		local np = 0
		local gnp = getglobal("GetNumPartyMembers")
		if type(gnp) == "function" then np = gnp() or 0 end
		local _, fe = UnitClass("player")
		rosterAdd(UnitName("player") or EMPTY, "player", fe)
		for i = 1, np do
			local u = "party" .. i
			if UnitExists(u) then
				local _, f2 = UnitClass(u)
				rosterAdd(UnitName(u) or EMPTY, u, f2)
			end
		end
	end
	M.ScanClasses()
	M.offset = 0
	if M.win and M.win:IsShown() then M.Rebuild() end
end

function M.OnRoster()
	if M.on then M.ScanRoster() end
end

-- ---------------------------------------------------------------- benedictions posees ?
-- En 1.12, UnitBuff renvoie une TEXTURE, pas un nom (comme le documente Mod_PowerAuras) : le nom d'un buff se lit
-- par une infobulle cachee (SetUnitBuff + ligne 1), methode eprouvee dans PowerAuras. Les noms d'une unite sont lus
-- UNE fois par tour du cycle (cache par unite, vide a chaque BuildPairs) : au plus 32 lectures d'infobulle par joueur.
local function unitBuffNames(unit)
	local names = M.buffNames[unit]
	if names then return names end
	names = {}
	M.buffNames[unit] = names
	local ub = getglobal("UnitBuff")
	if type(ub) ~= "function" or not M.tip then return names end
	for i = 1, 32 do
		if not ub(unit, i) then break end
		M.tip:SetOwner(UIParent, "ANCHOR_NONE")
		M.tip:SetUnitBuff(unit, i)
		local fs = getglobal("ShikiUI_PPTipTextLeft1")
		local nm = fs and fs:GetText()
		if nm and nm ~= "" then names[slower(nm)] = true end
	end
	return names
end

-- Vrai si l'unite porte deja cette benediction (simple OU greater : on ne repose jamais par-dessus).
function M.HasBuff(unit, base)
	local names = unitBuffNames(unit)
	local want = fold(base)
	local gw = fold(M.GREATERPFX .. base)
	if GAMEFR and M.SPELLS_FR[base] then
		want = fold(M.SPELLS_FR[base])
		gw = fold(M.SPELLS_GFR[base] or (M.GREATER_FR .. M.SPELLS_FR[base]))
	end
	for n in pairs(names) do
		if n == want or n == gw or n == fold(base) or n == fold(M.GREATERPFX .. base) then return true end
	end
	return false
end

-- ---------------------------------------------------------------- cycle de benediction
-- Nom reel du sort selon la langue du jeu (frFR chez OctoWow : "Ben959diction sup959rieure des Rois"), sinon EN.
function M.SpellName(b)
	if GAMEFR and M.SPELLS_FR[b] then
		if C.Get("pallypower.greater") then return M.SPELLS_GFR[b] or (M.GREATER_FR .. M.SPELLS_FR[b]) end
		return M.SPELLS_FR[b]
	end
	local base = M.SPELLS[b]
	if C.Get("pallypower.greater") then return M.GREATERPFX .. base end
	return base
end

-- Construit la liste (unite, sort) de tout ce qui manque, dans l'ordre de la liste puis des benedictions.
function M.BuildPairs()
	M.npairs, M.qi, M.castn = 0, 0, 0
	M.buffNames = {}   -- les noms de buffs sont relus a chaque tour du cycle
	for i = 1, M.nrost do
		local r = M.roster[i]
		local a = M.assign[r.name]
		if a then
			for j = 1, getn(M.BLESS) do
				local b = M.BLESS[j]
				if a[b] and not M.HasBuff(r.unit, M.SPELLS[b]) then
					M.npairs = M.npairs + 1
					M.pairs[M.npairs] = { unit = r.unit, name = M.SpellName(b), base = M.SPELLS[b], frb = GAMEFR and M.SPELLS_FR[b] or nil, who = r.name }
				end
			end
		end
	end
end

local function castOn(unit, name)
	-- SuperWoW : lancement direct sur l'unite ; sinon methode par echange de cible (comme le soin au clic).
	if SUI.Api.superwow then
		CastSpellByName(name, unit)
		return
	end
	local was = UnitName("target")
	TargetUnit(unit)
	CastSpellByName(name)
	if was then TargetUnit(was) end
end

-- Un tour du cycle : pose UNE benediction (GCD), planifie le tour suivant ; arret propre quand tout est pose.
function M.CastStep()
	if not M.on or not M.task then return end
	if UnitIsDead("player") then return end      -- mort : le cycle attend (file gardee)
	while M.qi < M.npairs do
		M.qi = M.qi + 1
		local p = M.pairs[M.qi]
		if p and UnitExists(p.unit) and not UnitIsDead(p.unit) then
			-- entre-temps un autre paladin a pu poser la benediction : on ne repose jamais par-dessus
			if not M.HasBuff(p.unit, p.base) then
				castOn(p.unit, p.name)
				M.castn = M.castn + 1
				M.PaintStatus()
				return
			end
		end
	end
	M.Stop()
	M.PaintStatus()
	if M.castn > 0 then SUI.Print(L("msg.pallypower.done", M.castn)) end
end

function M.CastAll()
	if not M.on then SUI.Print(L("msg.pallypower.off")) return end
	if M.npairs > 0 and M.qi < M.npairs then SUI.Print(L("msg.pallypower.busy")) return end
	if M.task then SUI.Cancel(M.task) M.task = nil end
	-- le jugement part avant tout, meme si plus personne ne manque (c'est un geste a part)
	local jid = C.Get("pallypower.judge") or "none"
	local j = (GAMEFR and M.JUDGES_FR[jid]) or M.JUDGES[jid] or EMPTY
	if j ~= EMPTY and UnitExists("target") and UnitCanAttack("player", "target") then CastSpellByName(j) end
	M.BuildPairs()
	if M.npairs == 0 then
		SUI.Print(L("msg.pallypower.allset"))
		M.PaintStatus()
		return
	end
	M.qi = 0
	M.task = SUI.Every(1.1, M.CastStep, "pp.cast", true)
	M.CastStep()
	M.PaintStatus()
end

function M.Stop()
	if M.task then SUI.Cancel(M.task) M.task = nil end
	M.npairs, M.qi = 0, 0
end

-- ---------------------------------------------------------------- fenetre (grille)
local function cellClick()
	local b = this
	if b.who and b.bless then M.Toggle(b.who, b.bless) end
end

local function cellRClick()
	local b = this
	if b.who and b.bless then M.Toggle(b.who, b.bless, false) end
end

local function mkBtn(parent, label, w, h, fn, rfn)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(w)
	b:SetHeight(h)
	T.Backdrop(b, T.c.bg, T.c.border)
	b.txt = T.Text(b, 10, T.c.text, "CENTER", true)
	b.txt:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.txt:SetText(label or EMPTY)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function()
		if arg1 == "RightButton" and rfn then rfn() else fn() end
	end)
	return b
end

function M.Build()
	if M.win then return end
	local f = CreateFrame("Frame", "ShikiUI_PallyPowerWin", UIParent)
	f:SetWidth(540)
	f:SetHeight(520)
	T.Backdrop(f, T.c.panel, T.c.border)
	f:SetFrameStrata("HIGH")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetClampedToScreen(true)
	f:Hide()
	M.win = f
	f.title = T.Text(f, 13, T.c.text, "LEFT")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	f.title:SetText(L("mod.pallypower.title"))
	f.status = T.Text(f, 11, T.c.dim, "LEFT")
	f.status:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
	f.close = mkBtn(f, "x", 18, 18, function() M.Close() end)
	f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	-- rangee 1 : un bouton par benediction (tout le monde / clic droit : personne)
	f.allB = {}
	for j = 1, getn(M.BLESS) do
		local b = M.BLESS[j]
		local btn = mkBtn(f, L("mod.pallypower.bless." .. b), 74, 18,
			function() M.SetAll(b, not M.AllHave(b)) end,
			function() M.SetAll(b, false) end)
		btn:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (j - 1) * 80, -30)
		f.allB[b] = btn
	end
	-- rangee 2 : boutons de classes presentes (jeu par defaut / clic droit = vider)
	f.classB = {}
	for i = 1, M.MAXCLASS do
		local b = mkBtn(f, EMPTY, 46, 18, function()
			if this.file then M.SetClass(this.file, true) end
		end, function()
			if this.file then M.SetClass(this.file, false) end
		end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * 50, -52)
		b:Hide()
		f.classB[i] = b
	end
	-- grille : NOM + une case par benediction, M.ROWS lignes preparees, M.view visibles (molette)
	f.rows = {}
	for i = 1, M.ROWS do
		local row = CreateFrame("Frame", nil, f)
		row:SetHeight(14)
		row:SetWidth(520)
		row.name = T.Text(row, 10, T.c.text, "LEFT", true)
		row.name:SetPoint("LEFT", row, "LEFT", 4, 0)
		row.name:SetWidth(110)
		row.cells = {}
		for j = 1, getn(M.BLESS) do
			local b = M.BLESS[j]
			local cell = CreateFrame("Button", nil, row)
			cell:SetWidth(74)
			cell:SetHeight(13)
			cell.bless = b
			T.Backdrop(cell, T.c.bg, T.c.border)
			cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			cell:SetScript("OnClick", function()
				if arg1 == "RightButton" then cellRClick() else cellClick() end
			end)
			cell:SetPoint("LEFT", row, "LEFT", 128 + (j - 1) * 80, 0)
			row.cells[b] = cell
		end
		if i == 1 then
			row:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -74)
		else
			row:SetPoint("TOPLEFT", f.rows[i - 1], "BOTTOMLEFT", 0, -2)
		end
		row:Hide()
		f.rows[i] = row
	end
	-- pied : defauts, vider, BENIR
	f.bDef = mkBtn(f, L("msg.pallypower.defauts"), 96, 20, function()
		for i = 1, M.nrost do
			local r = M.roster[i]
			local d = M.CLASSDEF[r.file]
			local a = asg(r.name)
			for k in pairs(a) do a[k] = nil end
			if d then
				for k, v in pairs(d) do
					if v then a[k] = true end
				end
			end
		end
		saveAssign()
		M.PaintCells()
	end)
	f.bDef:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
	f.bClear = mkBtn(f, L("msg.pallypower.clear"), 70, 20, function() M.ClearAll() end)
	f.bClear:SetPoint("LEFT", f.bDef, "RIGHT", 6, 0)
	f.bCast = mkBtn(f, L("msg.pallypower.cast"), 110, 20, function() M.CastAll() end)
	f.bCast:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
	T.GearButton(f, "pallypower", { size = 14, point = "TOPRIGHT", x = -26, y = -4, title = L("msg.pallypower.gear") })
	f:SetScript("OnMouseWheel", function()
		if arg1 > 0 then M.Scroll(-3) else M.Scroll(3) end
	end)
	SUI.Layout.Register(f, "pp.win", "CENTER", 240, 0)
	if SUI.Mover and SUI.Mover.Register then
		SUI.Mover.Register("pp.win", f, { label = L("mod.pallypower.title"), scale = false })
	end
	T.OnAccent(function()
		if M.win and M.win:IsShown() then M.PaintCells() end
	end)
end

-- Tout le monde dans la liste porte-t-il cette attribution ? (bouton d'en-tete : tout / personne)
function M.AllHave(b)
	if M.nrost == 0 then return false end
	for i = 1, M.nrost do
		if not M.Has(M.roster[i].name, b) then return false end
	end
	return true
end

function M.Scroll(d)
	if not M.win then return end
	local maxoff = mmax(0, M.nrost - M.view)
	M.offset = mmax(0, mmin(maxoff, M.offset + d))
	M.PaintRows()
end

-- Peint les lignes visibles (noms, couleurs de classe) et rattache les cases a leur joueur.
function M.PaintRows()
	local f = M.win
	if not f then return end
	for i = 1, M.ROWS do
		local row = f.rows[i]
		local r = M.roster[i]
		if r and i > M.offset and i <= M.offset + M.view then
			row.name:SetText(r.name)
			local cc = RAID_CLASS_COLORS[r.file]
			if cc then row.name:SetTextColor(cc.r, cc.g, cc.b) end
			row._n = r.name
			row:Show()
			for j = 1, getn(M.BLESS) do
				row.cells[M.BLESS[j]].who = r.name
			end
		else
			row._n = nil
			row:Hide()
		end
	end
end

-- Peint l'ETAT des cases (attribuee = bordure accent) sans reconstruire.
function M.PaintCells()
	local f = M.win
	if not f or not f:IsShown() then return end
	local ar, ag, ab = T.Accent()
	local bc = T.c.border
	for i = 1, M.ROWS do
		local row = f.rows[i]
		if row:IsShown() and row._n then
			for j = 1, getn(M.BLESS) do
				local cell = row.cells[M.BLESS[j]]
				if cell.who and M.Has(cell.who, cell.bless) then
					cell:SetBackdropBorderColor(ar, ag, ab, 1)
				else
					cell:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1)
				end
			end
		end
	end
	M.PaintClasses()
	M.PaintStatus()
end

-- Peint les boutons de classes presentes.
function M.PaintClasses()
	local f = M.win
	if not f then return end
	local n = 0
	for file in pairs(M.classes) do
		n = n + 1
		local b = f.classB[n]
		if b then
			b.txt:SetText(file)
			b.file = file
			b:Show()
		end
	end
	for i = n + 1, M.MAXCLASS do
		f.classB[i].file = nil
		f.classB[i]:Hide()
	end
end

function M.PaintStatus()
	local f = M.win
	if not f then return end
	if M.npairs > 0 and M.qi < M.npairs then
		f.status:SetText(L("msg.pallypower.progress", M.qi, M.npairs))
	elseif M.nrost > 0 then
		f.status:SetText(L("msg.pallypower.count", M.nrost))
	else
		f.status:SetText(EMPTY)
	end
end

-- Reconstruit la grille (roster change) : lignes, classes, cases.
function M.Rebuild()
	M.Build()
	M.PaintRows()
	M.PaintCells()
end

function M.Open()
	if not M.on then return end
	SUI.WhenSafe(function()
		if not M.on then return end
		M.Build()
		M.ScanRoster()
		M.win:Show()
		M.Rebuild()
	end)
end

function M.Close()
	if M.win then M.win:Hide() end
end

function M.ToggleWin()
	if M.win and M.win:IsShown() then M.Close() else M.Open() end
end

-- ---------------------------------------------------------------- cycle de vie
function M.OnKey(key)
	if key == nil or sfind(key or EMPTY, "^pallypower%.") then
		if M.win and M.win:IsShown() then M.PaintStatus() end
	end
end

-- L'infobulle cachee qui lit les noms de buffs (methode PowerAuras) : creee une seule fois, hors combat.
function M.EnsureTip()
	if M.tip then return end
	local existing = getglobal("ShikiUI_PPTip")
	if existing then M.tip = existing return end
	local ok, t = pcall(CreateFrame, "GameTooltip", "ShikiUI_PPTip", UIParent, "GameTooltipTemplate")
	if ok and t then
		t:SetOwner(UIParent, "ANCHOR_NONE")
		M.tip = t
	end
end

function M.Enable()
	M.on = true
	M.LoadAssign()
	SUI.WhenSafe(M.EnsureTip)
	SUI.On("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.On("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.On("PLAYER_ENTERING_WORLD", M.OnRoster)
	if not M.watching then
		M.watching = true
		C.Watch("pallypower.", M.OnKey)
	end
	local _, cls = UnitClass("player")
	if cls ~= "PALADIN" and not M.warned then
		M.warned = true
		SUI.Print(L("msg.pallypower.nopaladin"))
	end
	M.ScanRoster()
end

function M.Disable()
	M.on = false
	M.Stop()
	SUI.Off("RAID_ROSTER_UPDATE", M.OnRoster)
	SUI.Off("PARTY_MEMBERS_CHANGED", M.OnRoster)
	SUI.Off("PLAYER_ENTERING_WORLD", M.OnRoster)
	M.Close()
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("pallypower", 68)

local function opt(key, typ, order, def, extra)
	local o = { key = "pallypower." .. key, type = typ, cat = "pallypower", label = "opt.pallypower." .. key, tip = "tip.pallypower." .. key, default = def, order = order }
	if extra then
		for k, v in pairs(extra) do o[k] = v end
	end
	return o
end

local function judgeText(o, v) return L("choice.pallypower.judge." .. v) end

SUI.RegisterModule("pallypower", {
	default = false,
	cost = "medium",
	options = {
		opt("greater", "bool", 10, true, { simple = true }),
		opt("judge", "choice", 20, "none", { choices = { "none", "light", "wisdom", "crusader" }, choiceText = judgeText, simple = true }),
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Le module reste actif en mode Raid : les benedictions d'urgence se posent EN combat.
SUI.RegisterCommand("pp", function(rest)
	if not M.on then
		C.Set("modules.pallypower", true)
	end
	rest = rest or EMPTY
	if rest == "open" then
		M.Open()
	elseif rest == "close" then
		M.Close()
	elseif rest == "cast" then
		M.CastAll()
	elseif rest == "clear" then
		M.ClearAll()
		SUI.Print(L("msg.pallypower.cleared"))
	else
		M.ToggleWin()
	end
end, "help.pallypower")
