-- Mod_Crafts : memoire des metiers de tous les personnages. A chaque ouverture d'une fenetre de metier (ou d'enchantement), la liste des
-- recettes connues est retenue (ShikiUIDB.global.crafts). L'infobulle d'un objet recette dit alors quels personnages la connaissent et
-- lesquels ont le metier sans la connaitre. Le client ne donne que les recettes visibles : les listes sont CUMULEES (une section repliee
-- ou un filtre ne fait rien oublier). Aucune minuterie. Regles du socle (Lua 5.0) : pas de '#', '%', '...', select, string.match.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

local M = {}
SUI.Crafts = M

local getn, tinsert, tsort = table.getn, table.insert, table.sort
local sfind, sgsub, tconcat = string.find, string.gsub, table.concat

M.on = false

local function glob(n) return getglobal(n) end

function M.Realm() return tostring(glob("GetRealmName") and GetRealmName() or "?") end

-- { [royaume] = { [personnage] = { [metier] = { r = rang, m = { [recette] = true } } } } }
function M.Store()
	local all = C.GetGlobal("crafts")
	if type(all) ~= "table" then
		all = {}
		C.SetGlobal("crafts", all)
	end
	local r = M.Realm()
	if type(all[r]) ~= "table" then all[r] = {} end
	return all[r]
end

function M.Entry(skill, rank)
	local realm = M.Store()
	local me = tostring(UnitName("player") or "?")
	if type(realm[me]) ~= "table" then realm[me] = {} end
	local e = realm[me][skill]
	if type(e) ~= "table" then
		e = { r = 0, m = {} }
		realm[me][skill] = e
	end
	if type(rank) == "number" and rank > 0 then e.r = rank end
	return e
end

local function usable(skill) return type(skill) == "string" and skill ~= "" and skill ~= "UNKNOWN" end

function M.ScanTrade()
	if not M.on or not GetTradeSkillLine or not GetNumTradeSkills then return end
	local skill, rank = GetTradeSkillLine()
	if not usable(skill) then return end
	local e = M.Entry(skill, rank)
	for i = 1, (GetNumTradeSkills() or 0) do
		local name, kind = GetTradeSkillInfo(i)
		if name and kind ~= "header" then e.m[name] = true end
	end
end

-- L'enchantement passe par la fenetre "Craft" ; le dressage des betes aussi, mais sans ligne de competence : ignore
function M.ScanCraft()
	if not M.on or not GetCraftDisplaySkillLine or not GetNumCrafts then return end
	local skill, rank = GetCraftDisplaySkillLine()
	if not usable(skill) then return end
	local e = M.Entry(skill, rank)
	for i = 1, (GetNumCrafts() or 0) do
		local name, _, kind = GetCraftInfo(i)
		if name and kind ~= "header" then e.m[name] = true end
	end
end

local function runTrade() M.pendingTrade = nil M.ScanTrade() end
local function runCraft() M.pendingCraft = nil M.ScanCraft() end

function M.OnTrade()
	if not M.pendingTrade then M.pendingTrade = SUI.After(0.5, runTrade, "crafts.trade") end
end

function M.OnCraft()
	if not M.pendingCraft then M.pendingCraft = SUI.After(0.5, runCraft, "crafts.craft") end
end

-- ---------------------------------------------------------------- infobulle
-- "Recette : Potion de soins" -> "Potion de soins"
function M.RecipeName(itemName)
	if type(itemName) ~= "string" then return nil end
	local _, _, name = sfind(itemName, ":%s*(.+)$")
	if not name then return nil end
	name = sgsub(name, "%s+$", "")
	return name
end

-- Qui connait la recette, qui a le metier sans la connaitre : deux listes de noms triees
function M.Who(skill, recipe)
	local known, missing = {}, {}
	for who, skills in pairs(M.Store()) do
		local e = skills[skill]
		if e then
			if e.m[recipe] then tinsert(known, who) else tinsert(missing, who .. " (" .. tostring(e.r or 0) .. ")") end
		end
	end
	tsort(known)
	tsort(missing)
	return known, missing
end

function M.AddTip(id, link)
	if not M.on or not C.Get("crafts.tip") or not GetItemInfo or not id then return end
	-- 1.12 : nom, lien, qualite, niveau requis, type, sous-type : le sous-type d'une recette porte le nom du metier
	local name, _, _, _, _, sub = GetItemInfo(id)
	local recipe = M.RecipeName(name)
	if not recipe or not sub then return end
	local known, missing = M.Who(sub, recipe)
	if getn(known) > 0 then
		local c = T.c.good
		GameTooltip:AddLine(L("msg.crafts.known", tconcat(known, ", ")), c[1], c[2], c[3])
	end
	if getn(missing) > 0 then
		local c = T.c.warn
		GameTooltip:AddLine(L("msg.crafts.missing", tconcat(missing, ", ")), c[1], c[2], c[3])
	end
end

-- ---------------------------------------------------------------- liste et oubli
function M.Summary()
	local out = {}
	for who, skills in pairs(M.Store()) do
		local parts = {}
		for skill, e in pairs(skills) do
			local n = 0
			for _ in pairs(e.m) do n = n + 1 end
			tinsert(parts, L("msg.crafts.skill", skill, e.r or 0, n))
		end
		tsort(parts)
		tinsert(out, who .. " : " .. tconcat(parts, ", "))
	end
	tsort(out)
	return out
end

-- Oublie un personnage (supprime ou renomme) ; vrai s'il etait connu
function M.Forget(who)
	local realm = M.Store()
	for name in pairs(realm) do
		if string.lower(name) == string.lower(who) then
			realm[name] = nil
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- cycle de vie
function M.Enable()
	M.on = true
	SUI.On("TRADE_SKILL_SHOW", M.OnTrade)
	SUI.On("TRADE_SKILL_UPDATE", M.OnTrade)
	SUI.On("CRAFT_SHOW", M.OnCraft)
	SUI.On("CRAFT_UPDATE", M.OnCraft)
end

function M.Disable()
	M.on = false
	SUI.Off("TRADE_SKILL_SHOW", M.OnTrade)
	SUI.Off("TRADE_SKILL_UPDATE", M.OnTrade)
	SUI.Off("CRAFT_SHOW", M.OnCraft)
	SUI.Off("CRAFT_UPDATE", M.OnCraft)
	SUI.Cancel(M.pendingTrade)
	SUI.Cancel(M.pendingCraft)
	M.pendingTrade, M.pendingCraft = nil, nil
end

-- ---------------------------------------------------------------- declaration
SUI.RegisterCategory("crafts", 85)

SUI.RegisterModule("crafts", {
	default = true,
	cost = "light",
	options = {
		{ key = "crafts.tip", type = "bool", cat = "crafts", label = "opt.crafts.tip", tip = "tip.crafts.tip",
			default = true, simple = true, order = 10 },
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

SUI.RegisterCommand("crafts", function(rest)
	local _, _, who = sfind(rest or "", "^%s*forget%s+(%S+)")
	if who then
		SUI.Print(L(M.Forget(who) and "msg.crafts.forgot" or "msg.crafts.nochar", who))
		return
	end
	local list = M.Summary()
	if getn(list) == 0 then SUI.Print(L("msg.crafts.none")) return end
	for i = 1, getn(list) do SUI.Print(list[i]) end
end, "help.crafts")
