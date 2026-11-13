-- t_bulletin : module "bulletin" (integration de DifficultBulletinBoard : ouverture, habillage, position, cout nul si coupe ou absent).
local SUI = ShikiUI
local C = SUI.Config
local TH = SUI.Theme
BOOT()
SETTLE()
local M = SUI.Bulletin
local mod = SUI.modules.bulletin

local function liveTasks()
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end
local function hasH(ev, fn)
  local h = SUI.handlers[ev]
  if not h then return false end
  for i = 1, table.getn(h) do if h[i] == fn then return true end end
  return false
end
local function approx(a, b) return math.abs(a - b) < 0.0001 end

SECTION("t_bulletin : contrat")
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
T("coupe par defaut", not mod.enabled)
EQ("aucune erreur interne au demarrage", SUI.errCount, 0)
EQ("aucun evenement avant activation", hasH("PLAYER_ENTERING_WORLD", M.Attach), false)
T("commande /sui dbb enregistree", SUI.commands.dbb ~= nil)

SECTION("t_bulletin : DBB absent, cout nul")
local t0, f0 = liveTasks(), CREATED
CHATCLEAR()
C.Set("modules.bulletin", true)
EQ("module actif", mod.enabled, true)
EQ("DBB non detecte", M.present, false)
EQ("aucun evenement enregistre", hasH("PLAYER_ENTERING_WORLD", M.Attach), false)
EQ("aucune surveillance de reglage", M.watching, nil)
EQ("aucune minuterie", liveTasks(), t0)
EQ("aucune frame creee", CREATED, f0)
EQ("rien enveloppe", M.wrapped, nil)
EQ("pas dans les integrations", table.concat(SUI.Api.Integrations(), ","), "")
SlashCmdList["SHIKIUI"]("dbb")
CONTAINS("commande : DBB absent", CHATTEXT(), SUI.L("msg.bulletin.absent"))
CHATCLEAR()
SlashCmdList["SHIKIUI"]("dbb status")
CONTAINS("statut", CHATTEXT(), SUI.L("msg.bulletin.status", 0, 0, 1, 0))
EQ("ouverture impossible", M.Open("open"), false)
C.Set("modules.bulletin", false)
EQ("coupe", mod.enabled, false)
EQ("toujours aucune minuterie", liveTasks(), t0)

SECTION("t_bulletin : DBB charge sans fenetre")
BULL_NOWINDOW()
CHATCLEAR()
C.Set("modules.bulletin", true)
EQ("DBB detecte", M.present, true)
EQ("attend l'entree dans le monde", hasH("PLAYER_ENTERING_WORLD", M.Attach), true)
EQ("une surveillance de reglage", M.watching, true)
SlashCmdList["SHIKIUI"]("dbb")
CONTAINS("fenetre inexistante", CHATTEXT(), SUI.L("msg.bulletin.nowindow"))
Fire("PLAYER_ENTERING_WORLD")
EQ("toujours en attente", hasH("PLAYER_ENTERING_WORLD", M.Attach), true)
EQ("aucune minuterie", liveTasks(), t0)
-- la fenetre apparait
BULL_SETUP()
local d = DBB2
local gui = d.gui
local f1 = CREATED
Fire("PLAYER_ENTERING_WORLD")
EQ("evenement rendu", hasH("PLAYER_ENTERING_WORLD", M.Attach), false)
EQ("scripts enveloppes", gui:GetScript("OnShow"), M.OnShow)
EQ("OnHide enveloppe", gui:GetScript("OnHide"), M.OnHide)
EQ("aucune frame creee", CREATED, f1)
EQ("fenetre cachee : pas encore habillee", M.skinned, false)

SECTION("t_bulletin : ouvrir, fermer, habiller")
local bgc = gui.backdrop
local intg = table.concat(SUI.Api.Integrations(), ",")
CONTAINS("liste des integrations", intg, "DifficultBulletinBoard")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("dbb")
EQ("/sui dbb ouvre", gui:IsShown(), true)
EQ("OnShow de DBB toujours appele", d.shows, 1)
EQ("habille", M.skinned, true)
local bg, bd = TH.c.bg, TH.c.border
T("fond du cadre principal", approx(bgc.bgc[1], bg[1]) and approx(bgc.bgc[3], bg[3]))
T("opacite du style", approx(bgc.bgc[4], bg[4] * (TH.alpha or 1)))
T("bordure du cadre principal", approx(bgc.bbc[1], bd[1]) and approx(bgc.bbc[2], bd[2]))
T("bouton de fermeture habille", approx(gui.close.backdrop.bgc[1], bg[1]))
T("bouton de config habille", approx(gui.configBtn.backdrop.bbc[1], bd[1]))
SlashCmdList["SHIKIUI"]("dbb")
EQ("/sui dbb ferme", gui:IsShown(), false)
EQ("OnHide de DBB toujours appele", d.hides, 1)
SlashCmdList["SHIKIUI"]("dbb open")
EQ("open", gui:IsShown(), true)
SlashCmdList["SHIKIUI"]("dbb open")
EQ("open deux fois : reste ouvert", gui:IsShown(), true)
SlashCmdList["SHIKIUI"]("dbb close")
EQ("close", gui:IsShown(), false)
SlashCmdList["SHIKIUI"]("dbb close")
EQ("close deux fois : reste ferme", gui:IsShown(), false)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("dbb status")
CONTAINS("statut", CHATTEXT(), SUI.L("msg.bulletin.status", 1, 1, 1, 1))

SECTION("t_bulletin : repeinture a chaud et option d'habillage")
gui:Show()
local keep = TH.c.bg
TH.c.bg = { 0.5, 0.25, 0.125, 1 }
TH.RefreshAccent()
T("changement de style : repeint", approx(bgc.bgc[1], 0.5) and approx(bgc.bgc[2], 0.25))
TH.c.bg = keep
C.Set("bulletin.skin", false)
EQ("habillage coupe : DBB retrouve ses couleurs", d.backdrops > 0, true)
T("couleur de DBB rendue", approx(bgc.bgc[1], 0.08) and approx(bgc.bgc[4], 0.85))
EQ("plus habille", M.skinned, false)
gui:Hide()
gui:Show()
EQ("reouverture sans habillage", M.skinned, false)
T("couleur de DBB conservee", approx(bgc.bgc[1], 0.08))
C.Set("bulletin.skin", true)
EQ("habillage rallume (fenetre ouverte)", M.skinned, true)
T("repeint", approx(bgc.bgc[1], TH.c.bg[1]))
gui:Hide()

SECTION("t_bulletin : memoriser la position")
EQ("option coupee par defaut", C.Get("bulletin.rememberpos"), false)
gui:Show()
gui:ClearAllPoints()
gui:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120.4, -80.6)
gui:Hide()
EQ("option coupee : rien memorise", C.Get("bulletin.pos"), "")
C.Set("bulletin.rememberpos", true)
gui:Show()
gui:Hide()
EQ("position memorisee a la fermeture", C.Get("bulletin.pos"), "TOPLEFT|TOPLEFT|120|-81")
gui:ClearAllPoints()
gui:SetPoint("CENTER", UIParent, "CENTER", 5, 5)
gui:Show()
local p, rel, rp, x, y = gui:GetPoint()
EQ("position rappliquee : ancre", p, "TOPLEFT")
EQ("position rappliquee : parent", rel, UIParent)
EQ("position rappliquee : ancre du parent", rp, "TOPLEFT")
EQ("position rappliquee : x", x, 120)
EQ("position rappliquee : y", y, -81)
EQ("un seul point", gui:GetNumPoints(), 1)
-- donnee corrompue ou ancre inconnue : ignoree
C.SetBase("bulletin.pos", "n'importe quoi")
gui:Hide()
gui:ClearAllPoints()
gui:SetPoint("CENTER", UIParent, "CENTER", 7, 7)
C.SetBase("bulletin.pos", "n'importe quoi")
gui:Show()
p, rel, rp, x, y = gui:GetPoint()
EQ("donnee corrompue : position gardee", p, "CENTER")
gui:Hide()
C.SetBase("bulletin.pos", "FOO|CENTER|1|1")
gui:Show()
p = gui:GetPoint()
EQ("ancre inconnue refusee", p, "CENTER")
gui:Hide()
-- cadre ancre ailleurs que sur UIParent : non memorise
C.SetBase("bulletin.pos", "")
gui:ClearAllPoints()
gui:SetPoint("TOPLEFT", DBB2Close, "BOTTOMLEFT", 1, 1)
gui:Show()
gui:Hide()
EQ("ancre relative a un autre cadre : non memorisee", C.Get("bulletin.pos"), "")
C.Reset("bulletin.rememberpos")

SECTION("t_bulletin : coupure")
local nh = d.shows
gui:ClearAllPoints()
gui:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
gui:Show()
EQ("habille avant la coupure", M.skinned, true)
local f2, t2 = CREATED, liveTasks()
C.Set("modules.bulletin", false)
EQ("coupe", mod.enabled, false)
EQ("DBB retrouve ses couleurs", approx(bgc.bgc[1], 0.08), true)
EQ("OnShow d'origine remis", gui:GetScript("OnShow") ~= M.OnShow, true)
EQ("OnHide d'origine remis", gui:GetScript("OnHide") ~= M.OnHide, true)
EQ("rien enveloppe", M.wrapped, nil)
EQ("evenement rendu", hasH("PLAYER_ENTERING_WORLD", M.Attach), false)
EQ("aucune frame creee", CREATED, f2)
EQ("aucune minuterie", liveTasks(), t2)
EQ("plus dans les integrations", table.concat(SUI.Api.Integrations(), ","), "")
gui:Hide()
gui:Show()
EQ("DBB marche toujours (OnShow d'origine)", d.shows > nh, true)
EQ("module coupe : pas d'habillage", M.skinned, false)
gui:Hide()
-- la commande reste utile meme coupee (comme /dbb)
SlashCmdList["SHIKIUI"]("dbb")
EQ("commande avec le module coupe", gui:IsShown(), true)
gui:Hide()

SECTION("t_bulletin : un autre addon s'est enveloppe par-dessus")
C.Set("modules.bulletin", true)
EQ("rallume : enveloppe de nouveau", gui:GetScript("OnShow"), M.OnShow)
local ours = gui:GetScript("OnShow")
local other = 0
gui:SetScript("OnShow", function() ours() other = other + 1 end)
C.Set("modules.bulletin", false)
local s0, bgBefore = d.shows, bgc.bgc[1]
gui:Show()
EQ("l'ancien script de DBB est toujours appele", d.shows, s0 + 1)
EQ("l'autre addon aussi", other, 1)
EQ("module coupe : le notre ne fait rien", approx(bgc.bgc[1], bgBefore), true)
EQ("module coupe : toujours pas habille", M.skinned, false)
gui:Hide()
-- reallumage propre : pas de double envelopppe
C.Set("modules.bulletin", true)
EQ("reallume", mod.enabled, true)
gui:Show()
EQ("habille de nouveau", M.skinned, true)
gui:Hide()
C.Set("modules.bulletin", false)

SECTION("t_bulletin : DBB disparait")
BULL_REMOVE()
C.Set("modules.bulletin", true)
EQ("DBB retire : non detecte", M.present, false)
SlashCmdList["SHIKIUI"]("dbb")
EQ("commande sans DBB : pas d'erreur", SUI.errCount, 0)
C.Set("modules.bulletin", false)

SECTION("t_bulletin : menu et langues")
T("page du menu accrochee", M.hooked == true or SUI.Menu == nil or SUI.Menu.Pages == nil)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("help")
CONTAINS("aide de la commande", CHATTEXT(), "/sui dbb")
local fr, en = SUI.locales.fr, SUI.locales.en
for _, k in ipairs({ "cat.bulletin", "opt.modules.bulletin", "tip.modules.bulletin", "opt.bulletin.skin", "tip.bulletin.skin", "opt.bulletin.rememberpos",
    "tip.bulletin.rememberpos", "mod.bulletin.found", "mod.bulletin.missing", "msg.bulletin.absent", "help.bulletin" }) do
  T("texte fr " .. k, fr[k] ~= nil)
  T("texte en " .. k, en[k] ~= nil)
end
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
