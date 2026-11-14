-- t_marks : module "marks" (barre des 8 marques de raid : detection par balayage des cibles, clic = cibler,
-- Maj + clic = poser le marqueur, taille, cycle de vie).
local SUI = ShikiUI
local C = SUI.Config
MKS_SETUP()
MKS.raid = { "M1", "M2" }
EXT.unitxp("real")
BOOT()
SETTLE()

local function liveTasks()
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == "marks.scan" and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end

SECTION("t_marks : enregistrement et contrat")
local M = SUI.Marks
local mod = SUI.modules.marks
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
EQ("categorie du menu", SUI.categories.marks, 69)
T("option size declaree", C.meta["marks.size"] ~= nil)
EQ("aucune erreur interne au demarrage", SUI.errCount, 0)
C.Set("modules.marks", true)
SETTLE()
EQ("module actif", mod.enabled, true)
EQ("barre construite et ouverte", M.bar ~= nil and M.bar:IsShown(), true)
T("unites balayees a l'activation", M.nunits >= 4)
EQ("minuterie de balayage", liveTasks(), 1)
T("deplacable", SUI.Layout.items["marks.bar"] ~= nil)

SECTION("t_marks : detection des marques")
MKS_MARK("raid1target", 8)     -- crane porte par la cible du raid1
MKS_MARK("raid2target", 2)     -- cercle porte par la cible du raid2
Pump(0.6)
EQ("crane detecte sur raid1target", M.found[8], "raid1target")
EQ("cercle detecte sur raid2target", M.found[2], "raid2target")
NEAR("crane frais", M.foundAt[8], GetTime(), 0.1)
-- detection perimee apres 3 s (mais memorisee pour le clic si l'unite existe encore)
Pump(3.5)
EQ("crane perime mais memorise", M.found[8], "raid1target")
-- marque sur la cible du joueur aussi balayee
MKS_MARK("target", 6)
Pump(0.6)
EQ("marque sur ma cible", M.found[6], "target")
-- cible demarquee : plus de detection
MKS_MARK("target", 0)
Pump(3.5)
EQ("cible demarquee : detection perimee", M.foundAt[6] == nil or GetTime() - M.foundAt[6] >= 3, true)

MKS_MARK("raid1target", 9)   -- index impossible : ignore
Pump(0.6)
EQ("index hors limite ignore", M.found[9], nil)
MKS_MARK("raid1target", 8)
Pump(0.6)
SECTION("t_marks : clic = cibler")
MKS_MARK("raid1target", 8)
Pump(0.6)
MKS_CLEAR()
M.Target(8)
CONTAINS("clic : cible le mob marque", MKS_ACTS(), "TargetUnit raid1target")
M.Target(5)
EQ("icone eteinte : rien", MKS_ACTS(), "TargetUnit raid1target")
MKS_CLEAR()

SECTION("t_marks : Maj + clic = poser le marqueur")
local btn8 = M.btn8
rawset(_G, "IsShiftKeyDown", function() return true end)
MKS_CLEAR()
this = btn8 ; btn8:GetScript("OnClick")()
CONTAINS("Maj + clic : marqueur pose", MKS_ACTS(), "SetRaidTarget target 8")
MKS_MARK("target", 8)
MKS_CLEAR()
this = btn8 ; btn8:GetScript("OnClick")()
CONTAINS("Maj + clic : marque retire", MKS_ACTS(), "SetRaidTarget target 0")
rawset(_G, "IsShiftKeyDown", function() return nil end)
MKS_CLEAR()

SECTION("t_marks : taille des icones")
local b1 = M.btn1
C.Set("marks.size", 40)
SETTLE()
EQ("icones agrandies", b1:GetWidth(), 40)
C.Set("marks.size", 24)
SETTLE()
EQ("icones retablies", b1:GetWidth(), 24)

SECTION("t_marks : ouverture / fermeture / commande")
M.Close()
EQ("fermee", M.bar:IsShown(), false)
EQ("minuterie rendue", liveTasks(), 0)
SlashCmdList["SHIKIUI"]("marks")
SETTLE()
EQ("/sui marks (ouvre)", M.bar:IsShown(), true)
SlashCmdList["SHIKIUI"]("marks close")
EQ("/sui marks close", M.bar:IsShown(), false)
EQ("aucune erreur interne " .. tostring(SUI.lastErr), SUI.errCount, 0)

SECTION("t_marks : coupure propre")
M.Open()
SETTLE()
M.Cast = M.Cast   -- no-op de garde
local tasks0 = liveTasks()
C.Set("modules.marks", false)
EQ("module coupe", mod.enabled, false)
EQ("fenetre fermee", M.bar:IsShown(), false)
EQ("minuterie rendue", liveTasks(), tasks0 - 1)
C.Set("modules.marks", true)
SETTLE()
EQ("rallume", mod.enabled, true)
EQ("aucune erreur interne finale " .. tostring(SUI.lastErr), SUI.errCount, 0)
M.Close()
DONE()
