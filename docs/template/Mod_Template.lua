-- Mod_Template : MODELE de module ShikiUI. Ce fichier n'est PAS charge (il vit dans docs\template\) : `node tools/newmodule.js <Nom>`
-- en fait une copie ShikiUI\Mod_<Nom>.lua avec son Locale_<Nom>.lua, sa suite de tests, son extension de simulation et ses
-- mutations (voir MODULES.md). Le module ci-dessous est volontairement minuscule mais complet : il montre chaque service partage.
-- Regles du socle (WoW 1.12 / Lua 5.0) : pas de '#', '%', '...', select, string.match ; au plus 32 upvalues par fonction ;
-- aucune allocation en combat ; aucun OnUpdate personnel (SUI.Every) ; frames creees une seule fois, hors combat (SUI.WhenSafe).
ShikiUI = ShikiUI or {}
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
local T = SUI.Theme

-- Espace de noms public du module : un CHAMP de ShikiUI, jamais une globale (le harnais refuse toute globale non declaree).
local M = {}
SUI.Template = M

local TICK = 0.5            -- secondes entre deux rafraichissements (doublees en mode urgence : 'scalable')

M.on = false                -- le module est-il actif ?
M.count = 0

-- ---------------------------------------------------------------- affichage
function M.Refresh()
	if not M.frame then return end
	M.text:SetText(L("msg.template.count", M.count))
end

-- Applique les reglages "template.*" (appele a la construction, a l'activation et a chaque changement de reglage).
function M.ApplyOptions()
	if not M.frame then return end
	M.frame:SetWidth(C.Get("template.width"))
	if M.on and C.Get("template.visible") then M.frame:Show() else M.frame:Hide() end
end

-- Un tour de minuterie : lit le service de ciblage partage (aucun balayage maison) puis redessine.
function M.Tick()
	M.count = SUI.Target.Visible(true)
	M.Refresh()
end

-- Construction unique, hors combat. Les positions passent par SUI.Layout (deplacement, verrouillage, echelle communs).
function M.Build()
	if M.frame then return end
	local f = CreateFrame("Frame", "ShikiUI_Template", UIParent)
	f:SetWidth(120)
	f:SetHeight(24)
	T.Backdrop(f, T.c.bg, T.c.border)
	M.text = T.Text(f, 12, T.c.text, "CENTER")
	M.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	M.frame = f
	SUI.Layout.Register(f, "template", "CENTER", 0, -200)
	M.ApplyOptions()
	M.Refresh()
end

-- ---------------------------------------------------------------- evenements, reglages
function M.OnCombat()
	M.Tick()
end

-- fn(cle, valeur) ; cle == nil : tout a pu changer (profil, mode Normal / Raid, import) -> tout relire.
function M.OnKey(key, value)
	M.ApplyOptions()
end

-- ---------------------------------------------------------------- cycle de vie (appele par le socle)
function M.Enable()
	M.on = true
	SUI.WhenSafe(M.Build)
	SUI.On("PLAYER_REGEN_DISABLED", M.OnCombat)
	SUI.On("PLAYER_REGEN_ENABLED", M.OnCombat)
	M.task = SUI.Every(TICK, M.Tick, "template.tick", true)
	if not M.watching then
		M.watching = true
		C.Watch("template.", M.OnKey)
	end
	M.ApplyOptions()
end

-- Tout ce que Enable a pris doit etre rendu : minuteries, evenements, frames cachees.
function M.Disable()
	M.on = false
	SUI.Cancel(M.task)
	M.task = nil
	SUI.Off("PLAYER_REGEN_DISABLED", M.OnCombat)
	SUI.Off("PLAYER_REGEN_ENABLED", M.OnCombat)
	if M.frame then M.frame:Hide() end
end

-- ---------------------------------------------------------------- declaration
-- Categorie du menu Expert : une par module, du meme nom que lui. L'ordre (2e argument) vient de la table de MODULES.md.
SUI.RegisterCategory("template", 10)

SUI.RegisterModule("template", {
	default = true,          -- false pendant la mise au point : le module n'est alors active que par l'utilisateur
	cost = "light",          -- OBLIGATOIRE : "light" | "medium" | "heavy" (poids a l'execution, voir MODULES.md)
	-- raid = "off",         -- decommenter pour que le mode Raid coupe ce module (l'utilisateur peut le rallumer)
	options = {
		-- cle = "<module>.<nom>" ; label = "opt.<cle>" ; tip = "tip.<cle>" ; textes dans Locale_<Nom>.lua. simple = true : visible en mode Simple.
		{ key = "template.visible", type = "bool", cat = "template", label = "opt.template.visible", tip = "tip.template.visible",
			default = true, simple = true, order = 10 },
		{ key = "template.width", type = "number", cat = "template", label = "opt.template.width", tip = "tip.template.width",
			min = 60, max = 240, step = 10, default = 120, order = 20 },
	},
	enable = function() M.Enable() end,
	disable = function() M.Disable() end,
})

-- Reglages livres pour un mode (un ecart de l'utilisateur dans ce mode gagne toujours). Portee : "*", un role, une classe, "role/CLASSE".
SUI.Config.AddPreset("raid", "*", { ["template.width"] = 90 })

-- Commande /sui template. L'aide (cle help.template) est ajoutee automatiquement a /sui help.
SUI.RegisterCommand("template", function(rest)
	SUI.Print(L("msg.template.count", M.count))
end, "help.template")
