-- t_addons : gestionnaire d'addons (Addons.lua, page "Addons" du menu), bouton ShikiUI du menu Echap (GameMenu.lua),
-- boutons Deplacer / Raccourcis du menu et cartes de l'accueil.
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Menu
local A = SUI.Addons
local G = SUI.GameMenu
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
BOOT()
SETTLE()

local function cmd(s)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"](s)
  return CHATTEXT()
end
local function rowFor(name)
  for i = 1, M.used.arow do
    local r = M.pools.arow[i]
    if r.entry and r.entry.name == name then return r end
  end
end

MKADDONS({
  "ShikiUI", "nampower", "pfUI", "Zeta",
  { name = "ShikiBars", title = "|cff00ff00Shiki Bars|r", notes = "Barres", enabled = false },
  { name = "Alpha", title = "Alpha Tools", notes = "Un addon", loadable = false },
  { name = "SuperWoW", enabled = true },
})

SECTION("t_addons : liste")
local list = A.Scan()
EQ("7 addons", table.getn(list), 7)
EQ("tri par titre (insensible a la casse)", list[1].title, "Alpha Tools")
EQ("codes de couleur retires du titre", list[4].title, "Shiki Bars")
EQ("etat actif lu", list[4].on, false)
EQ("chargeable lu", list[1].loadable, false)
T("nampower critique", A.IsCritical("nampower"))
T("SuperWoW critique (casse ignoree)", A.IsCritical("SuperWoW"))
T("ShikiUI critique", A.IsCritical("ShikiUI"))
T("Zeta pas critique", not A.IsCritical("Zeta"))
T("ShikiBars est a moi", A.IsMine("ShikiBars"))
T("pfUI n'est pas a moi", not A.IsMine("pfUI"))
EQ("aucun changement au depart", A.Changes(list), 0)

SECTION("t_addons : filtres et recherche")
A.filter, A.query = "all", ""
local n = 0
for i = 1, table.getn(list) do if A.Match(list[i]) then n = n + 1 end end
EQ("tous", n, 7)
A.filter = "on"
n = 0
for i = 1, table.getn(list) do if A.Match(list[i]) then n = n + 1 end end
EQ("actifs", n, 6)
A.filter = "off"
n = 0
for i = 1, table.getn(list) do if A.Match(list[i]) then n = n + 1 end end
EQ("inactifs", n, 1)
A.filter = "mine"
n = 0
for i = 1, table.getn(list) do if A.Match(list[i]) then n = n + 1 end end
EQ("Mes Shiki*", n, 2)
A.filter, A.query = "all", "bars"
n = 0
for i = 1, table.getn(list) do if A.Match(list[i]) then n = n + 1 end end
EQ("recherche sur le nom ou le titre", n, 1)
A.query = "shiki bars"
n = 0
for i = 1, table.getn(list) do if A.Match(list[i]) then n = n + 1 end end
EQ("recherche sur le titre seul (avec espace)", n, 1)
A.query = ""

SECTION("t_addons : bascule, addons critiques, rechargement")
W.acts = {}
EQ("Zeta coupe d'un clic", A.Toggle("Zeta", true), "done")
EQ("DisableAddOn appele", ADDONENABLED("Zeta"), false)
EQ("1 changement en attente", A.Changes(), 1)
EQ("reactiver", A.Toggle("Zeta", false), "done")
EQ("etat rendu", ADDONENABLED("Zeta"), true)
EQ("0 changement", A.Changes(), 0)
CHATCLEAR()
EQ("nampower : 1er clic", A.Toggle("nampower", true), "armed")
EQ("nampower encore actif", ADDONENABLED("nampower"), true)
CONTAINS("avertissement", CHATTEXT(), "nampower")
EQ("nampower : 2e clic", A.Toggle("nampower", true), "done")
EQ("nampower coupe", ADDONENABLED("nampower"), false)
A.Toggle("nampower", false)
A.Toggle("ShikiUI", true)
Pump(10, 1)
EQ("le 2e clic trop tard ne compte pas", A.Toggle("ShikiUI", true), "armed")
EQ("ShikiUI encore actif", ADDONENABLED("ShikiUI"), true)
A.armed = nil
A.Toggle("Zeta", true)
W.reloads = 0
W.combat = true
A.Reload()
EQ("pas de rechargement en combat", W.reloads, 0)
W.combat = false
A.Reload()
EQ("rechargement", W.reloads, 1)
A.Toggle("Zeta", false)

SECTION("t_addons : page du menu")
M.Show("addons")
EQ("page addons", M.page, "addons")
EQ("persistance de la page", ShikiUIDB.global.menuPage, "addons")
local navE = nil
for i = 1, table.getn(M.navList) do
  if M.navList[i].kind == "page" and M.navList[i].id == "addons" then navE = M.navList[i] end
end
T("entree de navigation Addons", navE ~= nil)
local ai = nil
for i = 1, table.getn(M.navList) do if M.navList[i] == navE then ai = i end end
local nh = 0
for i = 1, table.getn(M.navList) do if M.navList[i].kind == "head" and M.navList[i].id == "tools" then nh = nh + 1 end end
EQ("un seul en-tete Outils", nh, 1)
EQ("Addons suit l'en-tete Outils", ai and M.navList[ai - 1].kind .. ":" .. M.navList[ai - 1].id, "head:tools")
EQ("7 lignes", M.used.arow, 7)
T("champ de recherche", M.used.aedit == 1)
EQ("1re ligne", M.pools.arow[1].name:GetText(), "Alpha Tools")
EQ("case decochee pour un addon coupe", rowFor("ShikiBars").chk.on, false)
EQ("case cochee", rowFor("Zeta").chk.on, true)
EQ("addon non chargeable signale", rowFor("Alpha").tag:GetText(), "non chargeable")
A.SetFilter("off")
EQ("filtre inactifs : 1 ligne", M.used.arow, 1)
A.SetFilter("all")
-- clic sur une ligne
W.acts = {}
rowFor("Zeta"):Click()
EQ("clic = coupe", ADDONENABLED("Zeta"), false)
EQ("etiquette recharger", rowFor("Zeta").tag:GetText(), "recharger")
EQ("bouton appliquer avec compteur", M.frame.head.btn[1].label:GetText(), "Appliquer et recharger (1)")
W.reloads = 0
M.frame.head.btn[1]:Click()
EQ("appliquer et recharger", W.reloads, 1)
rowFor("Zeta"):Click()
EQ("reactive", ADDONENABLED("Zeta"), true)
EQ("plus de compteur", M.frame.head.btn[1].label:GetText(), "Appliquer et recharger")
-- addon critique par la case
rowFor("pfUI"):Click()
rowFor("SuperWoW"):Click()
EQ("critique : 1er clic ne coupe pas", ADDONENABLED("SuperWoW"), true)
EQ("etiquette de confirmation", rowFor("SuperWoW").tag:GetText(), "Confirmer ?")
rowFor("SuperWoW"):Click()
EQ("critique : 2e clic coupe", ADDONENABLED("SuperWoW"), false)
rowFor("SuperWoW"):Click()
rowFor("pfUI"):Click()
-- recherche
local ed = M.pools.aedit[1].edit
ed:SetText("zeta")
EQ("recherche : requete", A.query, "zeta")
EQ("recherche : 1 ligne", M.used.arow, 1)
ed:SetText("")
EQ("recherche vide : 7 lignes", M.used.arow, 7)
ed:SetText("zzzz")
EQ("aucun resultat", M.used.arow, 0)
ed:SetText("")

SECTION("t_addons : memoire")
local alltxt = ""
for i = 1, M.used.txt do alltxt = alltxt .. M.pools.txt[i].fs:GetText() .. "|" end
CONTAINS("memoire indisponible", alltxt, "indisponible")
local updated = 0
rawset(_G, "UpdateAddOnMemoryUsage", function() updated = updated + 1 end)
rawset(_G, "GetAddOnMemoryUsage", function(name) if name == "Zeta" then return 2048 end return 512 end)
M.Render()
EQ("memoire rafraichie au rendu", updated, 1)
EQ("memoire d'une ligne en Mo", rowFor("Zeta").mem:GetText(), "2.0 Mo")
EQ("memoire d'une ligne en Ko", rowFor("pfUI").mem:GetText(), "512 Ko")
rawset(_G, "UpdateAddOnMemoryUsage", nil)
rawset(_G, "GetAddOnMemoryUsage", nil)
M.Render()
EQ("sans API : pas de memoire", rowFor("Zeta").mem:GetText(), "")

SECTION("t_addons : ensembles Normal / Raid")
EQ("aucun ensemble", A.Diff("raid"), nil)
EQ("ensemble inconnu refuse", A.SaveSet("pirate"), nil)
EQ("enregistre Normal", A.SaveSet("normal"), 7)
EQ("taille", A.SetSize("normal"), 7)
A.Set("Zeta", false)
A.Set("pfUI", false)
EQ("enregistre Raid", A.SaveSet("raid"), 7)
A.Set("Zeta", true)
A.Set("pfUI", true)
local d = A.Diff("raid")
EQ("2 differences avec Raid", table.getn(d), 2)
CHATCLEAR()
SUI.Mode.Set("raid", "manual")
CONTAINS("rappel a l'entree en Raid", CHATTEXT(), "Ensemble Raid : 2 difference(s)")
EQ("appliquer Raid", A.ApplySet("raid"), 2)
EQ("Zeta coupe par l'ensemble", ADDONENABLED("Zeta"), false)
EQ("ensemble Normal", A.ApplySet("normal"), 2)
EQ("Zeta rallume", ADDONENABLED("Zeta"), true)
-- ShikiUI n'est jamais coupe par un ensemble
A.Set("ShikiUI", false)
A.SaveSet("normal")
d = A.Diff("normal")
local found = false
for i = 1, table.getn(d) do if d[i].name == "ShikiUI" and d[i].want == true then found = true end end
T("l'ensemble rallume ShikiUI", found)
A.Set("ShikiUI", true)
SUI.Mode.Set("normal", "manual")
-- boutons de la page
M.Render()
A.Set("Zeta", true)
local bt = nil
for i = 1, M.used.btn do
  local b = M.pools.btn[i]
  if b.label:GetText() == "Enregistrer l'etat actuel comme ensemble Raid" then bt = b end
end
T("bouton d'enregistrement Raid", bt ~= nil)
A.Set("Zeta", false)
bt:Click()
A.Set("Zeta", true)
local nraid = A.ApplySet("raid")
EQ("l'ensemble Raid enregistre par le bouton coupe Zeta", ADDONENABLED("Zeta"), false)
A.Set("Zeta", true)

SECTION("t_addons : commande /sui addons")
CONTAINS("aide", cmd("help"), "/sui addons")
cmd("addons")
EQ("la commande ouvre la page", M.page, "addons")
CONTAINS("save", cmd("addons save raid"), "Ensemble Raid enregistre")
CONTAINS("apply", cmd("addons apply raid"), "Ensemble Raid applique")
CONTAINS("mode inconnu", cmd("addons apply pirate"), "Mode inconnu")
W.reloads = 0
cmd("addons reload")
EQ("reload", W.reloads, 1)
M.Hide()

SECTION("t_addons : sans API d'addons")
local sv = GetNumAddOns
rawset(_G, "GetNumAddOns", nil)
EQ("liste vide", table.getn(A.Scan()), 0)
EQ("indisponible", A.Available(), false)
M.Show("addons")
M.Render()
rawset(_G, "GetNumAddOns", sv)
M.Hide()

SECTION("t_addons : menu Echap")
local function btnByText(frame, text)
  for i = 1, table.getn(frame.kids) do
    if frame.kids[i]:GetText() == text then return frame.kids[i] end
  end
end
local function rel(gm, text) local t = GMTOP(text); return t and (gm:GetTop() - t) or nil end
W.layout = true
local gm = MKGAMEMENU()
G.Reset()
G.Hook()
local h0 = gm:GetHeight()
local macros0, logout0, ret0 = rel(gm, "Macros"), rel(gm, "Logout"), rel(gm, "Return to Game")
local opt0, don0, kbd0 = rel(gm, "Options"), rel(gm, "Donation Rewards"), rel(gm, "Key Bindings")
local step = macros0 - kbd0
EQ("pas de 22 (21 + 1)", step, 22)
gm:Show()
local sb = btnByText(gm, "ShikiUI")
T("bouton ShikiUI cree", sb ~= nil)
EQ("modele du bouton", G.how, "macros")
EQ("meme largeur que Macros", sb:GetWidth(), btnByText(gm, "Macros"):GetWidth())
EQ("meme hauteur que Macros", sb:GetHeight(), btnByText(gm, "Macros"):GetHeight())
EQ("meme modele de bouton", sb.template, "GameMenuButtonTemplate")
EQ("juste sous Macros", rel(gm, "ShikiUI"), macros0 + step)
EQ("Macros n'a pas bouge", rel(gm, "Macros"), macros0)
EQ("Options n'a pas bouge", rel(gm, "Options"), opt0)
EQ("Donation Rewards n'a pas bouge", rel(gm, "Donation Rewards"), don0)
EQ("Key Bindings n'a pas bouge", rel(gm, "Key Bindings"), kbd0)
EQ("Logout decale d'un pas", rel(gm, "Logout"), logout0 + step)
EQ("Return to Game decale d'un pas", rel(gm, "Return to Game"), ret0 + step)
EQ("la fenetre grandit d'un pas", gm:GetHeight(), h0 + step)
T("aucun chevauchement", GMTOP("Macros") - sb:GetHeight() >= GMTOP("ShikiUI") and GMTOP("ShikiUI") - sb:GetHeight() >= GMTOP("Logout"))
T("tout reste dans la fenetre", GMTOP("Return to Game") - 21 >= gm:GetBottom())
-- une seule fois
gm:Hide()
gm:Show()
gm:Hide()
gm:Show()
local count = 0
for i = 1, table.getn(gm.kids) do if gm.kids[i]:GetText() == "ShikiUI" then count = count + 1 end end
EQ("un seul bouton ShikiUI apres plusieurs ouvertures", count, 1)
EQ("hauteur inchangee apres reouvertures", gm:GetHeight(), h0 + step)
EQ("Logout toujours decale d'un seul pas", rel(gm, "Logout"), logout0 + step)
G.Install()
EQ("Install idempotent", gm:GetHeight(), h0 + step)
-- clic
sb:Click()
T("le menu Echap est ferme", not gm:IsShown())
T("le menu ShikiUI est ouvert", M.frame and M.frame:IsShown())
M.Hide()

-- ordre des enfants quelconque, bouton du bas pose en absolu, modele de bouton inconnu
gm = MKGAMEMENU({ reverse = true, absLast = true, bad = { GameMenuButtonTemplate = true } })
G.Reset()
G.Hook()
h0 = gm:GetHeight()
local bot1 = GMTOP("Return to Game") - gm:GetBottom()
local m1 = rel(gm, "Macros")
gm:Show()
sb = btnByText(gm, "ShikiUI")
T("repli de modele : bouton cree", sb ~= nil)
EQ("repli de modele : UIPanelButtonTemplate", sb.template, "UIPanelButtonTemplate")
EQ("ordre quelconque : sous Macros", rel(gm, "ShikiUI"), m1 + step)
EQ("bouton en absolu sur le bas : reste a la meme distance du bas", GMTOP("Return to Game") - gm:GetBottom(), bot1)
EQ("fenetre agrandie une fois", gm:GetHeight(), h0 + step)

-- repli : pas de Macros
gm = MKGAMEMENU({ reverse = true, buttons = { { "Donation Rewards", 0 }, { "Options", 16 }, { "Key Bindings", 1 }, { "Logout", 16 }, { "Exit Game", 1 } } })
G.Reset()
G.Hook()
local kb = rel(gm, "Key Bindings")
local lg = rel(gm, "Logout")
gm:Show()
sb = btnByText(gm, "ShikiUI")
EQ("repli : pas de Macros", G.how, "fallback")
EQ("repli : sous Key Bindings", rel(gm, "ShikiUI"), kb + step)
EQ("repli : Logout decale", rel(gm, "Logout"), lg + step)

-- aucun bouton connu : rien n'est insere
gm = MKGAMEMENU({ buttons = { { "Foo", 0 }, { "Bar", 1 } } })
G.Reset()
G.Hook()
local hh = gm:GetHeight()
gm:Show()
EQ("aucun repere : pas de bouton", btnByText(gm, "ShikiUI"), nil)
EQ("aucun repere : fenetre inchangee", gm:GetHeight(), hh)
EQ("aucun repere : pas de bouton memorise", G.button, nil)
W.layout = false

SECTION("t_addons : boutons Deplacer / Raccourcis du menu")
M.Show("home")
local f = M.frame
T("bouton Deplacer", f.moveBtn ~= nil)
T("bouton Raccourcis", f.bindBtn ~= nil)
EQ("libelle Deplacer", f.moveBtn.label:GetText(), "Deplacer")
EQ("libelle Raccourcis", f.bindBtn.label:GetText(), "Raccourcis")
EQ("Deplacer inactif", f.moveBtn.selected, false)
M.Open("addons")
f.moveBtn:Click()
EQ("Deplacer ouvre le mode", SUI.Mover.active, true)
T("le menu est masque pendant le deplacement", not f:IsShown())
EQ("Deplacer actif", f.moveBtn.selected, true)
SUI.Mover.Exit(true)
T("le menu revient", f:IsShown())
EQ("meme page au retour", M.page, "addons")
EQ("Deplacer de nouveau inactif", f.moveBtn.selected, false)
f.bindBtn:Click()
EQ("Raccourcis ouvre le mode", SUI.Bind.active, true)
T("le menu est masque pendant les raccourcis", not f:IsShown())
SUI.Bind.Exit(true)
T("le menu revient apres les raccourcis", f:IsShown())
-- carte de l'accueil
M.Open("home")
EQ("2 cartes d'action", M.used.acard, 2)
EQ("carte Deplacer", M.pools.acard[1].title:GetText(), "Deplacer l'interface")
EQ("carte Raccourcis", M.pools.acard[2].title:GetText(), "Raccourcis clavier")
M.pools.acard[1]:Click()
EQ("la carte ouvre le mode", SUI.Mover.active, true)
SUI.Mover.Exit(true)
EQ("accueil au retour", M.page, "home")
-- assistant
M.ShowWizard(1)
for k, v in pairs(M.ws.orig.mods) do M.ws.sel.mods[k] = v end
M.WizGo(table.getn(M.WizSteps()))
M.wiz.nextBtn:Click()
EQ("l'assistant est applique", M.wiz.stepId, "done")
M.wiz.nextBtn:Click()
EQ("l'assistant ouvre le mode Deplacer (choix par defaut)", SUI.Mover.active, true)
T("assistant ferme", not M.wiz:IsShown())
SUI.Mover.Exit(true)
M.Hide()

SECTION("t_addons : combat")
W.combat = true
local c0 = CREATED
M.Show("addons")
M.Render()
EQ("aucune creation en combat (page deja construite)", CREATED, c0)
W.combat = false
M.Hide()

EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
