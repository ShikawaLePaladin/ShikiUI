-- t_combat : aucune creation d'objet en combat (cadres, fenetres, lignes), reprise a la sortie de combat.
local SUI = ShikiUI
local C = SUI.Config
local U = SUI.Units
local M = SUI.Menu

SECTION("t_combat : demarrage en plein combat (rechargement d'interface)")
W.combat = true
local c0 = CREATED
BOOT()
EQ("module actif (reglage)", SUI.modules.units.enabled, true)
EQ("mais aucun cadre cree", U.built, false)
EQ("aucun objet cree par les cadres", CREATED, c0)
local ctot = CREATED
Fire("PLAYER_TARGET_CHANGED")
Pump(1)
EQ("evenements sans cadres : aucune erreur", SUI.errCount, 0)
-- fenetres : refus poli
CHATCLEAR()
SlashCmdList["SHIKIUI"]("")
CONTAINS("menu refuse en combat", CHATTEXT(), "Impossible en combat")
EQ("aucune fenetre creee", M.frame, nil)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("export")
CONTAINS("export refuse en combat", CHATTEXT(), "Impossible en combat")
EQ("aucune fenetre de transfert", M.tf, nil)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("wizard")
CONTAINS("assistant refuse en combat", CHATTEXT(), "Impossible en combat")
EQ("aucun assistant", M.wiz, nil)
EQ("rien n'a ete cree", CREATED, ctot)
-- bandeau de performance
C.Set("perf.hud", true)
Pump(1.1, 2)
EQ("bandeau non cree en combat", SUI.Perf.hud, nil)

SECTION("t_combat : sortie de combat")
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
EQ("cadres crees a la sortie de combat", U.built, true)
Pump(1.1)
T("bandeau cree a l'echantillon suivant", SUI.Perf.hud ~= nil)
EQ("sans erreur", SUI.errCount, 0)
-- les cadres suivent la cible comme d'habitude
MKTARGET({ name = "Test" })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("cible visible", U.frames.target:IsShown(), true)

SECTION("t_combat : en combat apres construction")
c0 = CREATED
W.combat = true
-- changement de cible, mort, regeneration : aucune creation
MKTARGET({ name = "Autre", hp = 50 })
Fire("PLAYER_TARGET_CHANGED")
MKTOT()
W.units.player.dead = true
Fire("PLAYER_DEAD")
Fire("UNIT_HEALTH", "target")
SETTLE(10)
Pump(0.3, 10)
EQ("aucun objet cree par les cadres en combat", CREATED, c0)
-- reglages modifies en combat : appliques sans creation
C.Set("units.width", 200)
C.ApplyRole("pvp")
SETTLE()
EQ("largeur appliquee en combat", U.frames.player:GetWidth(), 200)
EQ("aucun objet cree", CREATED, c0)
-- fenetre : construite hors combat (accueil + modules), puis parcourue en combat
W.combat = false
SlashCmdList["SHIKIUI"]("simple")
M.Open("modules")
M.Hide()
W.combat = true
c0 = CREATED
SlashCmdList["SHIKIUI"]("expert")
EQ("ouverte en combat", M.frame:IsShown(), true)
M.Open("modules")
M.Open("cat", "units")
M.frame.edit:SetText("a")
M.Open("home")
M.frame.edit:SetText("")
EQ("aucun objet cree en combat", CREATED, c0)
W.combat = false
SECTION("t_combat : fenetres de transfert")
W.combat = false
M.ShowTransfer("export")
W.combat = true
c0 = CREATED
M.ShowTransfer("import")
EQ("transfert existant : utilisable en combat", M.tf:IsShown(), true)
EQ("sans creation", CREATED, c0)
W.combat = false
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
