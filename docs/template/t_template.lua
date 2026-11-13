-- t_template : suite de tests du module "template" (copiee sous tests\t_<nom>.lua). Une suite = un fichier, autonome :
-- elle demarre l'addon avec BOOT(), construit son monde avec les aides du mock, et finit par DONE().
-- Aides : T(nom, condition) EQ(nom, obtenu, attendu) NEAR CONTAINS ERR SECTION BOOT SETTLE Pump(dt, n) Fire(evenement, ...) MKPLAYER MKTARGET
-- CHAT / CHATTEXT / CHATCLEAR, W (monde simule), EXT.superwow / nampower / unitxp (extensions), INRAID / LEAVERAID (mock_addons.lua).
local SUI = ShikiUI
local C = SUI.Config
EXT.unitxp("real")
BOOT()
SETTLE()

SECTION("t_template : enregistrement et contrat")
local mod = SUI.modules.template
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
EQ("actif au demarrage", mod and mod.enabled, true)
EQ("aucune erreur interne au demarrage", SUI.errCount, 0)
T("cadre construit", SUI.Template.frame ~= nil)

SECTION("t_template : comportement")
TEMPLATE_ENEMIES(3, 10)
Pump(0.6)
EQ("compte les ennemis proches", SUI.Template.count, 3)
CONTAINS("texte affiche", SUI.Template.text:GetText(), "3")
TEMPLATE_ENEMIES(5, 10)
Pump(0.6)
EQ("compte mis a jour", SUI.Template.count, 5)

SECTION("t_template : reglages et modes")
C.Set("template.width", 200)
EQ("largeur appliquee", SUI.Template.frame:GetWidth(), 200)
C.Set("template.visible", false)
EQ("cache", SUI.Template.frame:IsShown(), false)
C.Set("template.visible", true)
EQ("montre", SUI.Template.frame:IsShown(), true)
C.Set("template.width", 120)
SUI.Mode.Set("raid", "manual")
EQ("preset Raid livre (largeur)", C.Get("template.width"), 90)
EQ("preset appliquee au cadre", SUI.Template.frame:GetWidth(), 90)
SUI.Mode.Set("normal", "manual")
EQ("retour au Normal", C.Get("template.width"), 120)

SECTION("t_template : commande et langues")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("template")
CONTAINS("commande", CHATTEXT(), "5")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("help")
CONTAINS("aide du module", CHATTEXT(), "/sui template")

SECTION("t_template : desactivation")
local before = table.getn(SUI.tasks)
C.Set("modules.template", false)
EQ("module coupe", mod.enabled, false)
EQ("cadre cache", SUI.Template.frame:IsShown(), false)
local live = 0
for i = 1, table.getn(SUI.tasks) do
  if SUI.tasks[i].name == "template.tick" and not SUI.tasks[i].dead then live = live + 1 end
end
EQ("minuterie rendue", live, 0)
C.Set("modules.template", true)
EQ("module rallume", mod.enabled, true)
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
