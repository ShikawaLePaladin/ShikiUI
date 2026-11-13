-- t_menu : fenetre de configuration (accueil, modules, styles, pages de module, recherche globale, defilement, pool, transfert, assistant).
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Menu
local TH = SUI.Theme
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)

-- module de test hors famille connue (doit tomber dans "Autres") ; enregistre avant le demarrage
local fakeOn = 0
SUI.RegisterModule("zzfake", {
  cost = "light",
  options = {
    { key = "zzfake.flag", type = "bool", cat = "zzfake", label = "opt.zzfake.flag", tip = "tip.zzfake.flag", default = true, simple = true, order = 10 },
  },
  enable = function() fakeOn = fakeOn + 1 end,
  disable = function() fakeOn = fakeOn - 1 end,
})

local function cellFor(key)
  for i = 1, M.used.cell do
    local c = M.pools.cell[i]
    if c.opt and c.opt.key == key then return c end
  end
end
local function mcardFor(name)
  for i = 1, M.used.mcard do
    if M.pools.mcard[i].modName == name then return M.pools.mcard[i] end
  end
end
local function scardFor(id)
  for i = 1, M.used.scard do
    if M.pools.scard[i].id == id then return M.pools.scard[i] end
  end
end
local function navFor(kind, id)
  for i = 1, table.getn(M.navList) do
    local e = M.navList[i]
    if e.kind == kind and e.id == id then return M.navItems[i], e end
  end
end
local function nsec()
  local t = {}
  for i = 1, M.used.sec do table.insert(t, M.pools.sec[i].title:GetText()) end
  return table.concat(t, "|")
end
local function nstat()
  local t = {}
  for i = 1, M.used.stat do table.insert(t, M.pools.stat[i].title:GetText()) end
  return table.concat(t, "|")
end
local function wheel(frame, d)
  this = frame; arg1 = d
  frame.scripts.OnMouseWheel()
end

SECTION("t_menu : ouverture et structure")
BOOT()
SETTLE()
EQ("pas de fenetre avant ouverture", M.frame, nil)
EQ("aucune minuterie avant ouverture", M.tick, nil)
local c0 = CREATED
SlashCmdList["SHIKIUI"]("")
T("fenetre construite", M.frame ~= nil)
EQ("affichee", M.frame:IsShown(), true)
EQ("volet d'apercu a droite par defaut", M.pvMode, "side")
EQ("taille 880 + volet x 580", M.frame:GetWidth() == M.G.W + M.G.PX + M.G.PW + M.G.PAD and M.frame:GetHeight() == 580, true)
EQ("accueil par defaut", M.page, "home")
EQ("mode Essentiel par defaut", M.mode, "essential")
EQ("fermable avec Echap", UISpecialFrames[1], "ShikiUI_Menu")
EQ("deplacable", M.frame.movable, true)
T("minuterie creee a l'ouverture", M.tick ~= nil)
T("titre", string.find(M.frame.title:GetText(), "ShikiUI", 1, true) ~= nil)
CONTAINS("version", M.frame.ver:GetText(), "v")
EQ("recherche : indice", M.frame.editHint:GetText(), "Rechercher...")
EQ("bascule Essentiel", M.frame.segEss.label:GetText(), "Essentiel")
EQ("bascule Tout", M.frame.segAll.label:GetText(), "Tout")
EQ("Essentiel selectionne", M.frame.segEss.selected, true)
EQ("Tout non selectionne", M.frame.segAll.selected, false)
CONTAINS("bouton Normal / Raid", M.frame.modeBtn.label:GetText(), "Normal")
EQ("bouton Urgence", M.frame.emBtn.label:GetText(), "Urgence")
SlashCmdList["SHIKIUI"]("")
EQ("bascule : ferme", M.frame:IsShown(), false)
EQ("minuterie annulee a la fermeture", M.tick, nil)
SlashCmdList["SHIKIUI"]("")
EQ("bascule : rouvre", M.frame:IsShown(), true)
T("minuterie recreee", M.tick ~= nil)

SECTION("t_menu : navigation par familles")
local fams = M.FamilyList()
T("au moins 5 familles", table.getn(fams) >= 5)
EQ("premiere famille : General", fams[1].id, "general")
local last = fams[table.getn(fams)]
EQ("module inconnu : famille Autres", last.id, "other")
local inOther = false
for i = 1, table.getn(last.cats) do if last.cats[i] == "zzfake" then inOther = true end end
EQ("zzfake range dans Autres", inOther, true)
local it = navFor("page", "home")
EQ("entree Accueil", it.label:GetText(), "Accueil")
EQ("Accueil selectionne", it.selTex:IsShown(), true)
local itm = navFor("page", "modules")
EQ("entree Modules", itm.label:GetText(), "Modules")
local ith = navFor("head", "look")
EQ("titre de famille", ith.label:GetText(), "APPARENCE")
T("titre de famille non cliquable", ith.entry.kind == "head")
local itu = navFor("cat", "units")
EQ("entree categorie", itu.label:GetText(), "Cadres d'unites")
EQ("pastille d'etat visible (module)", itu.dot:IsShown(), true)
local itg = navFor("cat", "general")
EQ("pas de pastille pour une categorie", itg.dot:IsShown(), false)
itu:Click()
EQ("clic : page module", M.page, "cat")
EQ("clic : categorie", M.cat, "units")
EQ("clic : entree selectionnee", itu.selTex:IsShown(), true)
EQ("accueil deselectionne", it.selTex:IsShown(), false)
itm:Click()
EQ("clic : modules", M.page, "modules")
it:Click()
EQ("clic : accueil", M.page, "home")
EQ("page memorisee", C.GetGlobal("menuPage"), "home")
M.Open("cat", "units")
EQ("page de module memorisee", C.GetGlobal("menuPage"), "cat:units")
M.Open("cat", "inexistant")
EQ("categorie inconnue : accueil", M.page, "home")
M.Open("n'importe quoi")
EQ("page inconnue : accueil", M.page, "home")
do
  local dot = navFor("cat", "zzfake")
  T("module Autres present dans la navigation", dot ~= nil)
  M.Open("cat", "zzfake")
  EQ("page du module Autres", M.cat, "zzfake")
end

SECTION("t_menu : accueil")
M.Open("home")
EQ("8 cartes d'etat", M.used.stat, 8)
CONTAINS("carte mode", nstat(), "MODE DE JEU")
CONTAINS("carte extensions", nstat(), "EXTENSIONS")
CONTAINS("carte performance", nstat(), "PERFORMANCE")
CONTAINS("carte pfUI", nstat(), "PFUI")
EQ("sections de l'accueil", M.used.sec, 4)
EQ("4 boutons de role", table.getn(M.roleButtons), 4)
EQ("libelle tank", M.roleButtons[1].label:GetText(), "Tank")
M.roleButtons[2]:Click()
EQ("role applique", C.GetRole(), "heal")
EQ("bouton selectionne", M.roleButtons[2].selected, true)
CONTAINS("message de role", CHATTEXT(), "Role applique")
C.ApplyRole("tank")
EQ("role externe : bouton suit", M.roleButtons[1].selected, true)
EQ("carte style", M.pools.stat[3].value:GetText(), SUI.Style.Label(C.Get("style.name")))
-- carte profil : < et >
CHATCLEAR()
C.NewProfile("Second")
M.Open("home")
local prof = M.pools.stat[5]
EQ("carte profil : nom", prof.value:GetText(), "Default")
prof.b2:Click()
EQ("profil suivant", C.curName, "Second")
CONTAINS("pied : profil", M.frame.profileBtn.label:GetText(), "Second")
M.frame.profileBtn:Click("RightButton")
EQ("profil precedent (pied)", C.curName, "Default")
C.DeleteProfile("Second")
M.frame.profileBtn:Click("LeftButton")
EQ("un seul profil : rien", C.curName, "Default")
-- performances : mises a jour par la minuterie
local pc = M.perfCard
T("carte performance", pc ~= nil)
local before = pc.value:GetText()
EQ("FPS texte non vide", before ~= "" and before ~= nil, true)
Pump(1.1)
T("minuterie : valeur toujours presente", pc.value:GetText() ~= "")
-- raccourcis
local function btnFor(label)
  for i = 1, M.used.btn do
    if M.pools.btn[i].label:GetText() == label and M.pools.btn[i]:IsShown() then return M.pools.btn[i] end
  end
end
btnFor("Styles et mises en page"):Click()
EQ("raccourci Styles", M.page, "styles")
M.Open("home")
btnFor("Mises en page"):Click()
EQ("raccourci Mise en page : page styles", M.page, "styles")
T("raccourci Mise en page : defile vers les mises en page", M.cs.cur > 0 or M.cs.max == 0)
M.Open("home")
btnFor("Assistant"):Click()
T("raccourci Assistant", M.wiz ~= nil and M.wiz:IsShown())
M.wiz.skip:Click()
M.Open("home")
-- reinitialisation du profil : confirmation en deux clics
C.Set("units.width", 250)
local rb = btnFor("Reinitialiser")
rb:Click()
EQ("1er clic : confirmation demandee", rb.label:GetText(), "Confirmer ?")
EQ("rien n'est efface", C.Get("units.width"), 250)
Pump(3.1)
EQ("delai ecoule : libelle normal", rb.label:GetText(), "Reinitialiser")
rb:Click()
Pump(1)
rb:Click()
EQ("2e clic : reinitialise", C.Get("units.width"), 180)
CONTAINS("message", CHATTEXT(), "Profil reinitialise")
-- mode Normal / Raid, urgence
M.frame.modeBtn:Click()
EQ("bouton : raid", C.mode, "raid")
CONTAINS("libelle Raid", M.frame.modeBtn.label:GetText(), "Raid")
M.frame.modeBtn:Click()
EQ("bouton : retour Normal", C.mode, "normal")
M.frame.emBtn:Click()
EQ("urgence", SUI.emergency, true)
EQ("bouton urgence selectionne", M.frame.emBtn.selected, true)
M.frame.emBtn:Click()
EQ("urgence coupee", SUI.emergency, false)
-- extensions detectees
EXT.superwow(true); EXT.nampower(true); SUI.Api.Detect()
M.Open("home")
M.UpdateFooter()
CONTAINS("extensions detectees", M.pools.stat[6].sub:GetText(), "SuperWoW")
CONTAINS("pied : extensions", M.frame.info:GetText(), "SuperWoW 1.5, Nampower 3.0.1")
EXT.none(); SUI.Api.Detect()

SECTION("t_menu : page Modules")
M.Open("modules")
local nmod = table.getn(SUI.moduleOrder)
EQ("une carte par module", M.used.mcard, nmod)
T("sections par famille", string.find(nsec(), "AUTRES", 1, true) ~= nil and string.find(nsec(), "GENERAL", 1, true) ~= nil)
local cu = mcardFor("units")
T("carte units", cu ~= nil)
EQ("nom du module", cu.name:GetText(), M.ModName("units"))
EQ("interrupteur On", cu.sw.on, true)
CONTAINS("etat", cu.state:GetText(), "Actif")
CONTAINS("cout declare", cu.state:GetText(), "Cout")
EQ("bouton Configurer", cu.cfg:IsShown(), true)
EQ("pas de Migrer (pas de pfUI)", cu.mig:IsShown(), false)
cu.sw:Click()
EQ("interrupteur : module coupe", SUI.modules.units.enabled, false)
EQ("carte mise a jour", mcardFor("units").sw.on, false)
CONTAINS("etat Desactive", mcardFor("units").state:GetText(), "Coupe")
mcardFor("units").sw:Click()
EQ("module relance", SUI.modules.units.enabled, true)
local cf = mcardFor("zzfake")
cf.sw:Click()
EQ("module Autres coupe", fakeOn, 0)
cf = mcardFor("zzfake")
cf.sw:Click()
EQ("module Autres relance", fakeOn, 1)
-- Raid : ecart propre au mode Raid
local pre = C.GetIn("raid", "modules.chat")
mcardFor("chat").raid:Click()
EQ("interrupteur Raid inverse", C.GetIn("raid", "modules.chat"), not pre)
EQ("le mode Normal n'est pas touche", C.Get("modules.chat"), true)
mcardFor("chat").raid:Click()
EQ("interrupteur Raid retabli", C.GetIn("raid", "modules.chat"), pre)
-- filtres
local nOn, nOff = 0, 0
for i = 1, nmod do
  if M.State(SUI.moduleOrder[i]) == "on" then nOn = nOn + 1 elseif M.State(SUI.moduleOrder[i]) == "off" then nOff = nOff + 1 end
end
M.filter = "off"
M.Render()
EQ("filtre Coupes", M.used.mcard, nOff)
M.filter = "on"
M.Render()
EQ("filtre Actifs", M.used.mcard, nOn)
EQ("filtres complementaires", nOn + nOff, nmod)
M.filter = "wait"
M.Render()
EQ("filtre En attente : aucun", M.used.mcard, 0)
CONTAINS("message vide", M.pools.txt[1].fs:GetText(), "Aucun module")
M.filter = "all"
M.Render()
-- bouton Configurer
mcardFor("bags").cfg:Click()
EQ("Configurer ouvre la page du module", M.page == "cat" and M.cat == "bags", true)
EQ("page de module : titre", M.frame.head.title:GetText(), M.CatLabel("bags"))

SECTION("t_menu : page d'un module (sections, modes, indicateurs)")
M.Open("cat", "units")
EQ("titre du module", M.frame.head.title:GetText(), M.CatLabel("units"))
CONTAINS("description du module", M.frame.head.desc:GetText(), "")
EQ("interrupteur d'entete visible", M.frame.head.sw:IsShown(), true)
EQ("interrupteur d'entete : actif", M.frame.head.sw.on, true)
CONTAINS("etat dans l'entete", M.frame.head.status:GetText(), "Actif")
local simpleCount, allCount = 0, 0
for _, o in ipairs(M.OptionsOf("units")) do
  if o.type ~= "header" then
    allCount = allCount + 1
    if o.simple then simpleCount = simpleCount + 1 end
  end
end
T("units : options avancees", allCount > simpleCount and simpleCount > 0)
EQ("Essentiel : seulement les reglages simples", M.used.cell, simpleCount)
local right = 0
for i = 1, M.used.cell do if M.pools.cell[i].points[1][4] > 0 then right = right + 1 end end
T("Essentiel : reglages sur 2 colonnes", right > 0)
EQ("note des reglages masques", M.used.note, 1)
CONTAINS("nombre de reglages avances", M.pools.note[1].fs:GetText(), tostring(allCount - simpleCount))
-- bouton de la note : passe en mode Tout
M.pools.note[1].btn:Click()
EQ("mode Tout", M.mode, "all")
EQ("memorise", C.GetGlobal("menuMode"), "all")
EQ("Tout : tous les reglages", M.used.cell, allCount)
EQ("Tout : plus de note", M.used.note, 0)
EQ("Tout selectionne", M.frame.segAll.selected, true)
T("titres de sections", string.find(nsec(), "Joueur", 1, true) ~= nil and string.find(nsec(), "Cible", 1, true) ~= nil)
local cw = cellFor("units.width")
EQ("aide sous le libelle (mode Tout)", cw.help:IsShown(), true)
T("aide non vide", cw.help:GetText() ~= "")
M.frame.segEss:Click()
EQ("bascule Essentiel", M.mode, "essential")
EQ("aide cachee en Essentiel", cellFor("units.hptext").help:IsShown(), false)
M.frame.segAll:Click()
-- indicateur de modification
local cwid = cellFor("units.width")
EQ("non modifie : pas de marqueur", cwid.mod:IsShown(), false)
cwid.ctl.slider:SetValue(220)
EQ("curseur applique", C.Get("units.width"), 220)
EQ("marqueur visible", cellFor("units.width").mod:IsShown(), true)
EQ("valeur editable mise a jour", cellFor("units.width").ctl.edit:GetText(), "220")
CONTAINS("compteur de modifies", M.frame.head.status:GetText(), "1")
-- saisie dans le champ de valeur
local ce = cellFor("units.width").ctl
ce.edit:SetText("260")
this = ce.edit
ce.edit.scripts.OnEnterPressed()
EQ("saisie appliquee", C.Get("units.width"), 260)
EQ("curseur suit la saisie", ce.slider:GetValue(), 260)
ce.edit:SetText("abc")
this = ce.edit
ce.edit.scripts.OnEnterPressed()
EQ("saisie invalide : valeur gardee", C.Get("units.width"), 260)
EQ("saisie invalide : champ restaure", ce.edit:GetText(), "260")
-- clic sur le marqueur : reinitialise l'option
cellFor("units.width").mod:Click()
EQ("marqueur : option reinitialisee", C.Get("units.width"), 180)
EQ("marqueur cache", cellFor("units.width").mod:IsShown(), false)
EQ("curseur suit", cellFor("units.width").ctl.slider:GetValue(), 180)
-- bool
local ch = cellFor("units.range")
EQ("controle interrupteur", ch.ctl.ck, "check")
local was = C.Get("units.range")
ch.ctl:Click()
EQ("interrupteur bascule", C.Get("units.range"), not was)
EQ("marqueur apres bascule", cellFor("units.range").mod:IsShown(), true)
-- clic sur la ligne : bascule aussi
this = cellFor("units.range")
cellFor("units.range").scripts.OnMouseUp()
EQ("clic sur la ligne", C.Get("units.range"), was)
-- reglage necessitant un rechargement
local rh = cellFor("units.hideblizz")
CHATCLEAR()
rh.ctl:Click()
CONTAINS("message de rechargement", CHATTEXT(), "/reload")
cellFor("units.hideblizz").ctl:Click()
-- choix : segments <= 3 choix courts, liste deroulante sinon
M.Open("cat", "general")
local cl = cellFor("ui.locale")
EQ("langue : segments", cl.ctl.ck, "seg")
local nloc = table.getn(cl.opt.choices)
EQ("segments affiches", cl.ctl.segs[nloc]:IsShown() and not (cl.ctl.segs[nloc + 1] and cl.ctl.segs[nloc + 1]:IsShown()), true)
local selected = 0
for i = 1, nloc do if cl.ctl.segs[i].selected then selected = i end end
EQ("segment du choix courant", cl.opt.choices[selected], "fr")
cl.ctl.segs[2]:Click()
EQ("segment : langue changee", SUI.locale, cl.opt.choices[2])
EQ("segment : libelle traduit (anglais)", M.frame.segEss.label:GetText(), "Essential")
C.Set("ui.locale", "fr")
EQ("retour au francais", M.frame.segEss.label:GetText(), "Essentiel")
M.Open("cat", "units")
local cd = cellFor("units.hptext")
T("units.hptext : choix", cd ~= nil and cd.opt.type == "choice")
EQ("plus de 3 choix : liste deroulante", cd.ctl.ck, "drop")
CONTAINS("texte du choix", cd.ctl.btn.label:GetText(), "")
cd.ctl.btn:Click()
EQ("liste ouverte", M.frame.drop:IsShown(), true)
EQ("premiere ligne visible", M.frame.drop.rows[1]:IsShown(), true)
local want = cd.opt.choices[M.dropOff + 2]
M.DropPick(2)
EQ("choix applique", C.Get("units.hptext"), want)
EQ("liste fermee apres choix", M.frame.drop:IsShown(), false)
EQ("libelle du bouton suit", cellFor("units.hptext").ctl.btn.label:GetText(), M.ChoiceLabel(cd.opt, want))
cellFor("units.hptext").mod:Click()
EQ("marqueur : choix reinitialise", C.Get("units.hptext"), cd.opt.default)
cellFor("units.hptext").ctl.btn:Click()
EQ("liste rouverte", M.frame.drop:IsShown(), true)
cellFor("units.hptext").ctl.btn:Click()
M.CloseDrop()
EQ("liste fermee", M.frame.drop:IsShown(), false)
-- couleur (style)
M.Open("cat", "style")
local cc = cellFor("style.c.bg")
T("ligne couleur", cc ~= nil)
EQ("controle couleur", cc.ctl.ck, "color")
EQ("sans reglage : champ vide", cc.ctl.hex:GetText(), "")
cc.ctl.hex:SetText("00FF00")
this = cc.ctl.hex
cc.ctl.hex.scripts.OnEnterPressed()
EQ("saisie appliquee", C.Get("style.c.bg"), "00FF00")
NEAR("pastille verte", cellFor("style.c.bg").ctl.swatch.vc[2], 1, 0.01)
NEAR("pastille : pas de rouge", cellFor("style.c.bg").ctl.swatch.vc[1], 0, 0.01)
NEAR("appliquee a l'ecran", TH.c.bg[2], 1, 0.003)
EQ("marqueur visible", cellFor("style.c.bg").mod:IsShown(), true)
cc.ctl.hex:SetText("pasunecouleur")
this = cc.ctl.hex
cc.ctl.hex.scripts.OnEnterPressed()
EQ("saisie invalide : valeur gardee", C.Get("style.c.bg"), "00FF00")
EQ("saisie invalide : champ restaure", cellFor("style.c.bg").ctl.hex:GetText(), "00FF00")
cellFor("style.c.bg").mod:Click()
EQ("reinit. : couleur du style", C.Get("style.c.bg"), "")
EQ("champ vide", cellFor("style.c.bg").ctl.hex:GetText(), "")
-- style.name : liste deroulante, libelle du style
local cn = cellFor("style.name")
EQ("style : liste", cn.ctl.ck, "drop")
EQ("libelle du style courant", cn.ctl.btn.label:GetText(), "Shiki")
-- Raid : la reinitialisation concerne la couche du mode
SUI.Mode.Set("raid", "manual")
C.Set("style.alpha", 0.8)
M.Render()
local ca = cellFor("style.alpha")
EQ("en Raid : marqueur visible", ca.mod:IsShown(), true)
CONTAINS("en Raid : note", M.pools.txt[1].fs:GetText(), "Raid")
ca.mod:Click()
EQ("en Raid : retour au preset ou profil", C.Get("style.alpha") ~= 0.8, true)
SUI.Mode.Set("normal", "manual")
-- texte libre
local nt
for _, o in ipairs(SUI.options) do if o.type == "string" and o.cat ~= "modules" then nt = o break end end
if nt then
  M.Open("cat", nt.cat)
  local ct = cellFor(nt.key)
  T("controle texte", ct ~= nil and ct.ctl.ck == "text")
end

SECTION("t_menu : reinitialisation d'un module")
M.Open("cat", "units")
C.Set("units.width", 230)
C.Set("units.height", 40)
C.Set("units.range", not C.Get("units.range"))
M.Render()
CONTAINS("compteur : 3 modifies", M.frame.head.status:GetText(), "3")
local rbtn = M.frame.head.btn[1]
EQ("bouton de reinitialisation du module", rbtn:IsShown(), true)
EQ("libelle", rbtn.label:GetText(), "Reinitialiser le module")
rbtn:Click()
EQ("1er clic : confirmation", rbtn.label:GetText(), "Confirmer ?")
EQ("rien n'est efface", C.Get("units.width"), 230)
Pump(3.1)
EQ("delai ecoule", rbtn.label:GetText(), "Reinitialiser le module")
rbtn:Click()
Pump(1)
rbtn:Click()
EQ("2e clic : largeur", C.Get("units.width"), 180)
EQ("2e clic : hauteur", C.IsModified("units.height"), false)
EQ("2e clic : booleen", C.IsModified("units.range"), false)
EQ("le module reste actif", C.Get("modules.units"), true)
CONTAINS("message", CHATTEXT(), "remis a leur valeur")
EQ("aucun marqueur apres reinitialisation", cellFor("units.width").mod:IsShown(), false)
-- interrupteur d'entete
M.frame.head.sw:Click()
EQ("entete : module coupe", SUI.modules.units.enabled, false)
CONTAINS("entete : etat", M.frame.head.status:GetText(), "Coupe")
M.frame.head.sw:Click()
EQ("entete : module relance", SUI.modules.units.enabled, true)
-- changement externe : la ligne suit
local cw2 = cellFor("units.width")
C.Set("units.width", 200)
EQ("changement externe : curseur suit", cw2.ctl.slider:GetValue(), 200)
C.Set("units.width", 180)
-- changement de profil avec la fenetre ouverte
C.NewProfile("Autre")
C.Set("units.width", 230)
C.UseProfile("Autre")
EQ("la ligne suit le profil", cellFor("units.width").ctl.slider:GetValue(), 180)
C.UseProfile("Default")
EQ("retour", cellFor("units.width").ctl.slider:GetValue(), 230)
C.Set("units.width", 180)
C.DeleteProfile("Autre")
-- categorie sans module : bouton de page
M.Open("cat", "general")
EQ("categorie : libelle du bouton", M.frame.head.btn[1].label:GetText(), "Reinitialiser la page")
EQ("categorie : pas d'interrupteur", M.frame.head.sw:IsShown(), false)
C.Set("ui.scale", 1.2)
M.Render()
M.frame.head.btn[1]:Click()
M.frame.head.btn[1]:Click()
NEAR("page reinitialisee", C.Get("ui.scale"), 1.0)

SECTION("t_menu : page Styles")
M.Open("styles")
local S = SUI.Style
EQ("une carte par style", M.used.scard, table.getn(S.names))
EQ("une carte par mise en page", M.used.lcard, table.getn(SUI.layoutOrder))
CONTAINS("sections", nsec(), "Mises en page")
local cb = scardFor("blizzard")
T("carte Blizzard", cb ~= nil)
EQ("nom sur la carte", cb.name:GetText(), "Blizzard classique")
T("description", cb.desc:GetText() ~= "")
T("apercu aux couleurs du style", cb.pv.bg.vc ~= nil and math.abs(cb.pv.bg.vc[1] - 26 / 255) < 0.01 and math.abs(cb.pv.bg.vc[3] - 48 / 255) < 0.01)
NEAR("apercu : barre a l'accent du style", cb.pv.fill.vc[1], 1, 0.01)
EQ("apercu : police du style", cb.pv.sample.font, TH.FONTS.frizqt)
local cs = scardFor("shiki")
T("carte du style actif marquee", cs.selected == true and cb.selected == false)
local before = TH.restyles
cb:Click()
EQ("un clic applique le style", C.Get("style.name"), "blizzard")
T("interface repeinte", TH.restyles > before)
T("carte suivie", scardFor("blizzard").selected == true)
local keep = scardFor("shiki").pv.bg.vc[1]
C.Set("style.name", "light")
NEAR("apercu independant du style actif", scardFor("shiki").pv.bg.vc[1], keep, 0.001)
C.Set("style.name", "shiki")
-- boutons d'entete
EQ("boutons d'entete", M.frame.head.nbtn, 4)
M.frame.head.btn[3]:Click()
T("gestionnaire de styles", SUI.StylePicker.frame and SUI.StylePicker.frame:IsShown())
SUI.StylePicker.Hide()
M.frame.head.btn[4]:Click()
EQ("Personnaliser : page style", M.cat, "style")
EQ("Personnaliser : mode Tout", M.mode, "all")
M.Open("styles")
-- mise en page
local lc = M.pools.lcard[1]
local lid = lc.id
lc:Click()
EQ("mise en page appliquee", SUI.Layout.Current(), lid)
T("carte de mise en page marquee", M.pools.lcard[1].selected == true)
-- export / import par la fenetre de transfert
M.frame.head.btn[2]:Click()
T("transfert ouvert (export)", M.tf and M.tf:IsShown())
M.tf.cancel:Click()

SECTION("t_menu : recherche globale")
M.Open("home")
M.frame.edit:SetText("larg")
EQ("recherche memorisee", M.search, "larg")
EQ("indice efface", M.frame.editHint:GetText(), "")
T("resultats", M.used.res >= 1)
EQ("titre de page de recherche", M.frame.head.title:GetText(), "Resultats : larg")
local found = false
for i = 1, M.used.res do if M.pools.res[i].hit.key == "units.width" then found = true end end
EQ("units.width trouve par le libelle", found, true)
CONTAINS("chemin du resultat", M.pools.res[1].path:GetText(), "")
M.frame.edit:SetText("UNITS.HPTEXT")
EQ("recherche par cle, insensible a la casse", M.pools.res[1].hit.key, "units.hptext")
M.frame.edit:SetText("zzzzz")
EQ("aucun resultat", M.used.res, 0)
CONTAINS("message", M.pools.txt[1].fs:GetText(), "Aucun reglage")
-- recherche dans l'aide
local helpHit
for _, o in ipairs(SUI.options) do
  if o.type ~= "header" and o.tip and SUI.L(o.tip) ~= o.tip then helpHit = o break end
end
-- Tab / Entree
M.frame.edit:SetText("a")
T("plusieurs resultats", M.used.res > 3)
T("resultats plafonnes", M.used.res <= M.MAXRES and table.getn(M.hits) > M.MAXRES)
this = M.frame.edit
M.frame.edit.scripts.OnTabPressed()
EQ("Tab : premier resultat", M.resSel, 1)
EQ("resultat selectionne", M.pools.res[1].selected, true)
M.frame.edit.scripts.OnTabPressed()
EQ("Tab : suivant", M.resSel, 2)
local target = M.hits[2]
M.frame.edit.scripts.OnEnterPressed()
EQ("Entree : va sur la page du reglage", M.page, target.cat == "modules" and "modules" or "cat")
EQ("Entree : surbrillance", M.hl, target.key)
EQ("recherche effacee", M.search, "")
EQ("indice revenu", M.frame.editHint:GetText(), "Rechercher...")
-- clic sur un resultat d'un reglage avance : passe en Tout
M.SetMode("essential")
M.Open("home")
M.frame.edit:SetText("units.height")
EQ("hauteur : resultat", M.used.res, 1)
M.pools.res[1]:Click()
EQ("page du module", M.page == "cat" and M.cat == "units", true)
EQ("reglage avance : passe en Tout", M.mode, "all")
EQ("ligne mise en surbrillance", cellFor("units.height").hl:IsShown(), true)
EQ("une seule ligne en surbrillance", cellFor("units.width").hl:IsShown(), false)
-- resultat d'un module
M.frame.edit:SetText("modules.bags")
EQ("module trouve", M.used.res >= 1, true)
M.pools.res[1]:Click()
EQ("resultat module : page Modules", M.page, "modules")
EQ("carte en surbrillance", mcardFor("bags").selected, true)
-- Echap vide la recherche
M.frame.edit:SetText("abc")
this = M.frame.edit
M.frame.edit.scripts.OnEscapePressed()
EQ("Echap vide le champ", M.frame.edit:GetText(), "")
-- recherche en anglais
C.Set("ui.locale", "en")
M.frame.edit:SetText("locked")
T("recherche en anglais", M.used.res >= 1)
M.frame.edit:SetText("")
C.Set("ui.locale", "fr")

SECTION("t_menu : defilement")
M.SetMode("all")
M.Open("cat", "units")
local cs_ = M.cs
T("defilement necessaire", cs_.max > 0)
EQ("barre visible", cs_.bar:IsShown(), true)
T("barre large (>= 10 px)", cs_.bar:GetWidth() >= 10)
EQ("depart en haut", cs_.sf:GetVerticalScroll(), 0)
wheel(cs_.sf, -1)
EQ("molette : un pas", cs_.sf:GetVerticalScroll(), cs_.step)
wheel(cs_.sf, -100000)
EQ("molette : plafonnee", cs_.sf:GetVerticalScroll(), cs_.max)
wheel(cs_.sf, 100000)
EQ("molette : plancher", cs_.sf:GetVerticalScroll(), 0)
wheel(cellFor("units.width"), -1)
EQ("molette sur une ligne", cs_.sf:GetVerticalScroll(), cs_.step)
wheel(M.frame, 1)
EQ("molette sur la fenetre", cs_.sf:GetVerticalScroll(), 0)
-- glissement de la poignee
local th = cs_.thumb
MOUSE.x, MOUSE.y, MOUSE.down = 0, 500, true
this = th
th.scripts.OnMouseDown()
T("glissement : suivi du curseur", th.scripts.OnUpdate ~= nil)
MOUSE.y = 440
this = th
th.scripts.OnUpdate()
T("glissement vers le bas : defile", cs_.sf:GetVerticalScroll() > 0)
MOUSE.down = false
this = th
th.scripts.OnUpdate()
EQ("bouton relache : fin du glissement", th.scripts.OnUpdate, nil)
-- clic dans la barre
cs_.sf:SetVerticalScroll(0)
cs_.cur = 0
MOUSE.y = 0
this = cs_.bar
cs_.bar.scripts.OnMouseDown()
T("clic dans la barre : saut", cs_.cur >= 0 and cs_.cur <= cs_.max)
-- navigation : memes regles
T("navigation defilante", M.ns ~= nil and M.ns.max >= 0)
wheel(M.ns.sf, -1)
T("navigation : molette", M.ns.sf:GetVerticalScroll() >= 0)
-- page courte : pas de barre
M.Open("cat", "units")
wheel(M.cs.sf, -100000)
T("defile jusqu au bas", M.cs.cur > 0)
M.Open("styles")
EQ("changement de page : retour en haut", M.cs.cur, 0)
SUI.Config.Set("ui.locale", "fr")
M.Open("cat", "zzfake")
EQ("module court : pas de barre", M.cs.bar:IsShown(), false)
EQ("module court : pas de defilement", M.cs.max, 0)

SECTION("t_menu : rien ne depasse")
local function inside(kind, n)
  local p = M.pools[kind]
  for i = 1, M.used[kind] do
    local f = p[i]
    local pt = f.points and f.points[1]
    if string.sub(kind, 1, 2) == "c_" then
      if f.cell and f:IsShown() and f:GetWidth() + 6 > f.cell:GetWidth() then return false, kind .. i .. " plus large que la ligne" end
    elseif pt and f:IsShown() then
      local x, y = pt[4], pt[5]
      if x < 0 or x + f:GetWidth() > M.child:GetWidth() + 0.5 then return false, kind .. i .. " x" end
      if -y + f:GetHeight() > M.child:GetHeight() + 0.5 then return false, kind .. i .. " y" end
    end
  end
  return true
end
local pages = { { "home" }, { "modules" }, { "styles" }, { "cat", "units" }, { "cat", "general" }, { "cat", "style" }, { "cat", "bags" } }
for _, mm in ipairs({ "essential", "all" }) do
  M.SetMode(mm)
  for _, pg in ipairs(pages) do
    M.Open(pg[1], pg[2])
    for _, kind in ipairs(M.KINDS) do
      local ok, what = inside(kind)
      T("dans la zone : " .. mm .. " " .. pg[1] .. (pg[2] or "") .. " " .. kind .. " " .. tostring(what or ""), ok)
    end
    T("hauteur du contenu >= celle des elements", M.child:GetHeight() >= M.y)
  end
end
-- la fenetre tient dans l'ecran, a toutes les echelles
for _, sc in ipairs({ 0.7, 1.0, 1.3 }) do
  C.Set("ui.scale", sc)
  Pump(1)
  M.ApplyScale()
  local es = M.frame:GetScale()
  T("fenetre dans l'ecran a l'echelle " .. sc, M.frame:GetWidth() * es <= UIParent:GetWidth() * UIParent:GetScale() + 1
    and M.frame:GetHeight() * es <= UIParent:GetHeight() * UIParent:GetScale() + 1)
end
C.Set("ui.scale", 1.0)
Pump(1)
M.ApplyScale()
-- les textes des cartes sont raccourcis (jamais plus longs que la zone)
M.Open("modules")
for i = 1, M.used.mcard do
  T("description courte : " .. M.pools.mcard[i].modName, string.len(M.pools.mcard[i].desc:GetText()) <= 110)
end

SECTION("t_menu : pools stables")
M.SetMode("all")
local pagesAll = { { "home" }, { "modules" }, { "styles" }, { "cat", "units" }, { "cat", "style" }, { "cat", "clickheal" }, { "cat", "general" } }
for _, pg in ipairs(pagesAll) do M.Open(pg[1], pg[2]) end
M.frame.edit:SetText("a"); M.frame.edit:SetText("")
local sizes = {}
for _, k in ipairs(M.KINDS) do sizes[k] = table.getn(M.pools[k]) end
local nav0 = table.getn(M.navItems)
local created0 = CREATED
for i = 1, 200 do
  M.Hide()
  M.Show()
  M.Open(pagesAll[1 + SUI.Mod(i, 7)][1], pagesAll[1 + SUI.Mod(i, 7)][2])
end
EQ("aucune creation sur 200 ouvertures", CREATED, created0)
for _, k in ipairs(M.KINDS) do EQ("pool stable : " .. k, table.getn(M.pools[k]), sizes[k]) end
EQ("navigation stable", table.getn(M.navItems), nav0)
EQ("une seule minuterie", M.tick ~= nil, true)
M.Hide()
EQ("fermee : plus de minuterie", M.tick, nil)
-- aucune tache en cours quand le menu est ferme
local pending = 0
for i = 1, table.getn(SUI.tasks) do if SUI.tasks[i].name == "menutick" and not SUI.tasks[i].dead then pending = pending + 1 end end
EQ("aucune tache menutick", pending, 0)
M.Show()

SECTION("t_menu : style (aucune couleur en dur, suit les jetons)")
M.Open("cat", "units")
local lab = cellFor("units.width").label
C.Set("style.name", "light")
Pump(1)
M.Render()
T("libelle de reglage affiche", lab:GetText() ~= nil and lab:GetText() ~= "")
NEAR("fond de la fenetre = jeton bg", M.frame.bgc[1], TH.c.bg[1], 0.01)
C.Set("style.name", "shiki")
Pump(1)
NEAR("fond suit le retour au style", M.frame.bgc[1], TH.c.bg[1], 0.01)
C.Set("ui.accent", "red")
Pump(1)
local ar = TH.Accent()
T("accent applique", ar ~= nil)
C.Set("ui.accent", "blue")
Pump(1)
EQ("aucune erreur interne apres restyle", SUI.errCount, 0)

SECTION("t_menu : routage des commandes")
M.Hide()
SlashCmdList["SHIKIUI"]("menu modules")
EQ("/sui menu modules", M.page, "modules")
EQ("ouverte", M.frame:IsShown(), true)
SlashCmdList["SHIKIUI"]("menu styles")
EQ("/sui menu styles", M.page, "styles")
SlashCmdList["SHIKIUI"]("menu bags")
EQ("/sui menu bags", M.page == "cat" and M.cat == "bags", true)
SlashCmdList["SHIKIUI"]("menu accueil")
EQ("/sui menu accueil", M.page, "home")
SlashCmdList["SHIKIUI"]("simple")
EQ("/sui simple = Essentiel", M.mode, "essential")
SlashCmdList["SHIKIUI"]("expert")
EQ("/sui expert = Tout", M.mode, "all")
CONTAINS("aide de la commande", (function() CHATCLEAR(); SlashCmdList["SHIKIUI"]("help"); return CHATTEXT() end)(), "menu")

SECTION("t_menu : compatibilite des anciens reglages")
M.mode = nil
C.SetGlobal("menuMode", "expert")
M.LoadState()
EQ("expert devient Tout", M.mode, "all")
C.SetGlobal("menuMode", "simple")
M.LoadState()
EQ("simple devient Essentiel", M.mode, "essential")
C.SetGlobal("menuMode", "essential")
M.LoadState()
EQ("essential conserve", M.mode, "essential")
C.SetGlobal("menuMode", "n'importe quoi")
M.LoadState()
EQ("valeur inconnue : Essentiel", M.mode, "essential")
C.SetGlobal("menuPage", "cat:units")
M.LoadState()
EQ("page memorisee : categorie", M.page == "cat" and M.cat == "units", true)
C.SetGlobal("menuPage", "cat:inconnue")
M.LoadState()
EQ("page memorisee invalide : accueil", M.page, "home")
C.SetGlobal("menuPage", "styles")
M.LoadState()
EQ("page memorisee : styles", M.page, "styles")
M.SetMode("all")

SECTION("t_menu : textes fr / en")
local missing = {}
local function need(key)
  if not SUI.locales.fr[key] then table.insert(missing, "fr:" .. key) end
  if not SUI.locales.en[key] then table.insert(missing, "en:" .. key) end
end
for _, k in ipairs({ "home", "modules", "styles" }) do need("mod.menu.nav." .. k) end
for _, k in ipairs({ "general", "look", "combat", "group", "interface", "tools", "loot", "other" }) do need("mod.menu.fam." .. k) end
for _, k in ipairs({ "on", "off", "wait" }) do need("mod.menu.state." .. k) end
for _, k in ipairs({ "light", "medium", "heavy" }) do need("mod.menu.cost." .. k) end
for _, k in ipairs({ "all", "on", "off", "wait" }) do need("mod.menu.filter." .. k) end
for i = 1, table.getn(SUI.moduleOrder) do if SUI.moduleOrder[i] ~= "zzfake" then need("tip.modules." .. SUI.moduleOrder[i]) end end
for cat, _ in pairs(SUI.categories) do if cat ~= "zzfake" then need("cat." .. cat) end end
for _, o in ipairs(SUI.options) do
  if o.type ~= "header" and o.cat ~= "zzfake" and o.key ~= "modules.zzfake" then
    if o.label then need(o.label) end
    if o.choices and o.choiceKey then for _, v in ipairs(o.choices) do need(o.choiceKey .. v) end end
  end
end
EQ("tous les textes du menu existent en fr et en", table.concat(missing, ", "), "")
for _, lang in ipairs({ "fr", "en" }) do
  C.Set("ui.locale", lang)
  for _, pg in ipairs({ "home", "modules", "styles" }) do M.Open(pg) end
  for _, cat in ipairs({ "general", "units", "style", "perf", "bags", "clickheal", "mode" }) do M.Open("cat", cat) end
  for _, f in ipairs({ "all", "on", "off", "wait" }) do M.filter = f; M.Open("modules") end
  M.filter = "all"
  M.frame.edit:SetText("a"); M.frame.edit:SetText("")
end
C.Set("ui.locale", "fr")
EQ("parcours complet sans erreur", SUI.errCount, 0)

SECTION("t_menu : export / import")
M.Open("home")
btnFor("Exporter"):Click()
local tf = M.tf
T("fenetre de transfert", tf ~= nil and tf:IsShown())
EQ("titre export", tf.title:GetText(), "Exporter le profil")
EQ("chaine exportee", string.sub(tf.edit:GetText(), 1, 5), "SUI1:")
EQ("focus et selection", tf.edit.focus, true)
tf.ok:Click()
EQ("fermee", tf:IsShown(), false)
C.Set("units.width", 260)
btnFor("Exporter"):Click()
local str = tf.edit:GetText()
tf.cancel:Click()
C.ResetProfile()
btnFor("Importer"):Click()
EQ("titre import", tf.title:GetText(), "Importer un profil : colle la chaine ci-dessous")
EQ("champ vide", tf.edit:GetText(), "")
tf.edit:SetText(str)
local n0 = table.getn(C.ListProfiles())
CHATCLEAR()
tf.ok:Click()
EQ("import : un profil de plus", table.getn(C.ListProfiles()), n0 + 1)
CONTAINS("import : message", CHATTEXT(), "Import reussi")
EQ("import : valeur", C.db.profiles.Default2.v["units.width"], 260)
btnFor("Importer"):Click()
tf.edit:SetText("n'importe quoi")
CHATCLEAR()
tf.ok:Click()
CONTAINS("import refuse", CHATTEXT(), "Import refuse")
EQ("pas de profil de plus", table.getn(C.ListProfiles()), n0 + 1)
C.DeleteProfile("Default2")

SECTION("t_menu : assistant de premiere installation")
M.Hide()
C.SetGlobal("firstRun", true)
local function gotoStep(id)
  local st = M.WizSteps()
  for i = 1, table.getn(st) do
    if st[i] == id then M.WizGo(i) return end
  end
  error("etape absente : " .. id)
end
local function hasStep(id)
  local st = M.WizSteps()
  for i = 1, table.getn(st) do if st[i] == id then return true end end
  return false
end
local style0, role0, layout0 = C.Get("style.name"), C.GetRole(), C.cur.layout
local mods0 = {}
for i = 1, table.getn(SUI.moduleOrder) do mods0[SUI.moduleOrder[i]] = C.Get("modules." .. SUI.moduleOrder[i]) end
local nb0 = table.getn(SUI.Backup.List())
if M.wiz then M.wiz:Hide() end
M.ws = nil
M.ShowWizard(1)
local w = M.wiz
T("assistant ouvert", w ~= nil and w:IsShown())
EQ("etape 1", w.step, 1)
EQ("titre", w.title:GetText(), "Bienvenue dans ShikiUI")
local nsteps = table.getn(M.WizSteps())
T("au moins 8 etapes (Installation +)", nsteps >= 8)
EQ("parcours preselectionne : Installation +", M.ws.sel.path, "plus")
EQ("progression", w.dots:GetText(), "Etape 1 sur " .. nsteps)
EQ("pas d'etape pfUI sans pfUI", hasStep("migrate"), false)
EQ("pas de bouton Precedent a l'etape 1", w.prevBtn:IsShown(), false)
EQ("2 choix de langue", w.pg.welcome.l[1]:IsShown() and w.pg.welcome.l[2]:IsShown(), true)
EQ("2 parcours proposes", w.pg.welcome.path[1]:IsShown() and w.pg.welcome.path[2]:IsShown(), true)
EQ("Installation + est selectionne", w.pg.welcome.path[2].selected, true)
w.pg.welcome.l[2]:Click()
EQ("anglais choisi", SUI.locale, "en")
EQ("textes traduits sur place", w.skip.label:GetText(), "Cancel")
w.pg.welcome.l[1]:Click()
EQ("retour au francais", SUI.locale, "fr")
CONTAINS("detection : SuperWoW", w.pg.welcome.det[1].name:GetText(), "SuperWoW")
w.nextBtn:Click()
EQ("etape 2 : role", w.stepId, "role")
EQ("Precedent visible", w.prevBtn:IsShown(), true)
w.prevBtn:Click()
EQ("Precedent", w.stepId, "welcome")
gotoStep("style")
local S = SUI.Style
local second = S.names[2]
w.pg.style.sb[2]:Click()
EQ("style choisi dans l'assistant", M.ws.sel.style, second)
EQ("mais pas applique", C.Get("style.name"), style0)
local tok = S.Resolve(second)
NEAR("apercu : couleur de fond du style choisi", w.pg.style.pv.bg.vc[1], tok.c.bg[1])
NEAR("apercu : bordure du style choisi", w.pg.style.pv.edge.vc[1], tok.c.border[1])
w.pg.style.sz[3]:Click()
NEAR("taille choisie, non appliquee", C.Get("ui.scale"), 1.0)
gotoStep("layout")
w.pg.layout.lc[2]:Click()
EQ("mise en page choisie", M.ws.sel.layout, SUI.layoutOrder[2])
w.pg.layout.lc[2]:Click()
EQ("re-clic : on garde les positions", M.ws.sel.layout, nil)
w.pg.layout.lc[2]:Click()
w.pg.layout.mode[2]:Click()
EQ("mode manuel choisi", M.ws.sel.modeauto, false)
gotoStep("role")
local pickRole = (role0 == "tank") and 2 or 1
local roleName = C.roleOrder[pickRole]
if M.ws.sel.role == roleName then pickRole = pickRole + 1; roleName = C.roleOrder[pickRole] end
w.pg.role.rb[pickRole]:Click()
EQ("role choisi, non applique", M.ws.sel.role, roleName)
EQ("role du profil intact", C.GetRole(), role0)
gotoStep("modules")
local pk = w.pg.modules.pk
pk[3]:Click()
EQ("pack Leger reconnu", M.WizCurrentPack(), "light")
EQ("Leger : units actif", M.ws.sel.mods.units, true)
EQ("Leger : chat coupe", M.ws.sel.mods.chat, false)
EQ("rien d'applique : chat toujours actif", C.Get("modules.chat"), mods0.chat)
pk[7]:Click()
EQ("pack Tout", M.WizCurrentPack(), "all")
for i = 1, table.getn(SUI.moduleOrder) do EQ("Tout : " .. SUI.moduleOrder[i], M.ws.sel.mods[SUI.moduleOrder[i]], true) end
pk[3]:Click()
-- la carte du module tooltip (toutes les pages)
local function findSlot(name)
  local pages = math.floor((table.getn(SUI.moduleOrder) - 1) / 10) + 1
  for p = 1, pages do
    M.ws.modPage = p
    M.WizRender()
    for i = 1, 10 do
      local b = w.pg.modules.slot[i]
      if b:IsShown() and b.mod == name then return b, i end
    end
  end
end
local slot, slotIdx = findSlot("tooltip")
T("carte du module tooltip", slot ~= nil)
CONTAINS("case cochee", slot.label:GetText(), "[x]")
T("la carte donne une phrase", w.pg.modules.sd[slotIdx]:GetText() ~= nil and w.pg.modules.sd[slotIdx]:GetText() ~= "")
slot:Click()
EQ("module coupe a la main", M.ws.sel.mods.tooltip, false)
slot, slotIdx = findSlot("tooltip")
CONTAINS("case decochee", slot.label:GetText(), "[ ]")
EQ("reglage manuel : aucun pack", M.WizCurrentPack(), nil)
this = slot
slot:GetScript("OnEnter")()
CONTAINS("description au survol", w.pg.modules.hint:GetText(), "Cout")
slot:Click()
gotoStep("essentials")
M.ws.tab = "bars"
M.WizRender()
local barsRow = w.pg.essentials.rows[1]
EQ("la premiere ligne des barres est la visibilite", barsRow.b[4].oid, "incombat")
barsRow.b[4]:Click()
EQ("barres cachees hors combat", M.ws.sel.es.bars, "incombat")
gotoStep("place")
w.pg.place.pb[3].b:Click()
EQ("apres : ouvrir le menu", M.ws.sel.after, "menu")
gotoStep("summary")
EQ("derniere etape : Appliquer", w.nextBtn.label:GetText(), "Appliquer")
local function sumText()
  local t = ""
  for i = 1, 15 do
    local r = w.pg.summary.rows[i]
    if r.l:IsShown() then t = t .. r.l:GetText() .. "=" .. r.v:GetText() .. "\n" end
  end
  return t
end
CONTAINS("recapitulatif : style", sumText(), S.Label(second))
CONTAINS("recapitulatif : parcours", sumText(), "Installation +")
CONTAINS("recapitulatif : sans risque", w.pg.summary.safe:GetText(), "Rien n'est applique")
EQ("TOUJOURS rien d'applique : style", C.Get("style.name"), style0)
EQ("TOUJOURS rien d'applique : role", C.GetRole(), role0)
EQ("aucune sauvegarde avant Appliquer", table.getn(SUI.Backup.List()), nb0)
W.combat = true
w.nextBtn:Click()
EQ("combat : pas d'application", w.stepId, "summary")
W.combat = false
w.nextBtn:Click()
EQ("page finale", w.stepId, "done")
EQ("style applique", C.Get("style.name"), second)
EQ("role applique", C.GetRole(), roleName)
EQ("modules : pack Leger applique (chat)", C.Get("modules.chat"), false)
EQ("modules : pack Leger applique (units)", C.Get("modules.units"), true)
EQ("mode manuel applique", C.Get("mode.auto"), false)
NEAR("taille appliquee", C.Get("ui.scale"), 1.1)
EQ("barre 2 cachee hors combat", C.Get("actionbars.bar2.show"), "incombat")
EQ("barre principale toujours visible", C.Get("actionbars.main.show"), "always")
EQ("une sauvegarde de securite", table.getn(SUI.Backup.List()), nb0 + 1)
EQ("raison : assistant", SUI.Backup.List()[1].reason, "wizard")
CONTAINS("la page finale annonce le total", w.pg.done.lines:GetText(), "reglage(s) appliques")
EQ("bouton annuler = tout annuler", w.skip.label:GetText(), "Tout annuler")
w.skip:Click()
EQ("assistant ferme", w:IsShown(), false)
EQ("style restaure", C.Get("style.name"), style0)
EQ("role restaure", C.GetRole(), role0)
EQ("mise en page restauree", C.cur.layout, layout0)
NEAR("taille restauree", C.Get("ui.scale"), 1.0)
for i = 1, table.getn(SUI.moduleOrder) do EQ("module restaure : " .. SUI.moduleOrder[i], C.Get("modules." .. SUI.moduleOrder[i]), mods0[SUI.moduleOrder[i]]) end
EQ("premier lancement efface", C.GetGlobal("firstRun"), false)
M.ShowWizard(1)
M.wiz.pg.welcome.l[2]:Click()
EQ("langue vue sur le champ", SUI.locale, "en")
M.wiz.skip:Click()
EQ("annule : assistant ferme", M.wiz:IsShown(), false)
EQ("annule : langue restauree", SUI.locale, "fr")
EQ("annule : style intact", C.Get("style.name"), style0)
M.ShowWizard(2)
EQ("ouverture directe a l'etape 2", M.wiz.step, 2)
gotoStep("summary")
M.ws.sel.after = "menu"
M.wiz.nextBtn:Click()
EQ("appliquer sans rien changer", M.wiz.stepId, "done")
M.wiz.nextBtn:Click()
EQ("termine : assistant ferme", M.wiz:IsShown(), false)
EQ("menu ouvert en Essentiel sur l'accueil", M.frame:IsShown() and M.mode == "essential" and M.page == "home", true)
for _, lang in ipairs({ "fr", "en" }) do
  C.Set("ui.locale", lang)
  for _, id in ipairs({ "welcome", "migrate", "role", "modules", "style", "layout", "essentials", "specs", "backup", "place", "summary", "done" }) do
    for _, part in ipairs({ "name", "why", "what" }) do
      T(lang .. " " .. id .. " " .. part, M.Has("mod.setup.s." .. id .. "." .. part))
    end
  end
end
C.Set("ui.locale", "fr")
M.Hide()
M.wiz:Hide()

SECTION("t_menu : au-dessus du mode deplacement (strate, niveau, ordre de capture)")
do
  local Mv = SUI.Mover
  local ORD = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
  local function st(f) return f.calls.SetFrameStrata and f.calls.SetFrameStrata[1] end
  W.layout = true
  M.Hide()
  M.Show()
  local f = M.frame
  local lv0 = f:GetFrameLevel()
  EQ("hors deplacement : strate DIALOG", st(f), "DIALOG")
  EQ("hors deplacement : pas releve", M.raised, false)
  Mv.Enter()
  EQ("deplacement actif", Mv.active, true)
  EQ("l'entree masque le menu", f:IsShown(), false)
  EQ("pile relevee des l'entree", M.raised, true)
  M.Show()
  EQ("menu affiche pendant le deplacement", f:IsShown(), true)
  EQ("menu : strate FULLSCREEN_DIALOG", st(f), "FULLSCREEN_DIALOG")
  EQ("liste : strate FULLSCREEN_DIALOG", st(f.drop), "FULLSCREEN_DIALOG")
  EQ("cadre de capture : strate FULLSCREEN_DIALOG", st(f.catcher), "FULLSCREEN_DIALOG")
  T("menu au-dessus du voile (strate)", ORD[st(f)] > ORD[st(Mv.veil)])
  local top, nh = 0, 0
  local function over(name, fr)
    T(name .. " : strate <= menu", ORD[st(fr)] <= ORD[st(f)])
    T(name .. " : niveau sous le menu", fr:GetFrameLevel() < f:GetFrameLevel())
  end
  for i = 1, table.getn(Mv.order) do
    local rec = Mv.items[Mv.order[i]]
    if rec.handle then
      nh = nh + 1
      over("poignee " .. rec.id, rec.handle)
    end
  end
  T("des poignees existent", nh > 0)
  over("bandeau", Mv.banner)
  Mv.BuildPanel()
  over("panneau", Mv.panel)
  Mv.BuildList()
  over("liste des cadres", Mv.list)
  T("zone defilante : niveau releve", M.lvl > Mv.banner:GetFrameLevel())
  T("capture de la liste au-dessus du menu", f.catcher:GetFrameLevel() > f:GetFrameLevel())
  T("liste deroulante au-dessus de la capture", f.drop:GetFrameLevel() > f.catcher:GetFrameLevel())
  T("liste deroulante au-dessus de tout le deplacement", f.drop:GetFrameLevel() > Mv.banner:GetFrameLevel())
  -- une liste deroulante reste utilisable pendant le deplacement, sans fermer le mode
  M.Open("cat", "units")
  local cd = cellFor("units.hptext")
  cd.ctl.btn:Click()
  EQ("liste ouverte pendant le deplacement", f.drop:IsShown(), true)
  local want = cd.opt.choices[M.dropOff + 2]
  M.DropPick(2)
  EQ("choix applique pendant le deplacement", C.Get("units.hptext"), want)
  EQ("le mode deplacement reste actif", Mv.active, true)
  EQ("bouton Deplacer du menu : accentue", f.moveBtn.selected, true)
  -- sortie : strate et niveau d'origine
  Mv.Exit(true)
  EQ("sortie : pile abaissee", M.raised, false)
  EQ("sortie : strate DIALOG", st(f), "DIALOG")
  EQ("sortie : strate de la liste", st(f.drop), "DIALOG")
  EQ("sortie : niveau d'origine", f:GetFrameLevel(), lv0)
  -- un deuxieme cycle ne derive pas
  Mv.Enter()
  Mv.Exit(true)
  EQ("deux cycles : niveau d'origine", f:GetFrameLevel(), lv0)
  W.layout = false
end

SECTION("t_menu : combat")
M.Hide()
W.combat = true
c0 = CREATED
M.SetMode("all")
M.Show()
EQ("en combat, fenetre existante : s'ouvre", M.frame:IsShown(), true)
for _, pg in ipairs({ { "home" }, { "modules" }, { "styles" }, { "cat", "units" }, { "cat", "style" } }) do M.Open(pg[1], pg[2]) end
-- pools vides (cas d'un menu construit avant, page jamais vue) : en combat, rien ne se cree, la page s'affiche tronquee
M.pools.cell, M.pools.mcard = {}, {}
M.Open("cat", "units")
M.Open("modules")
EQ("combat : pool vide, aucune creation", CREATED, c0)
EQ("combat : page tronquee mais sans erreur", M.used.cell + M.used.mcard, 0)
M.frame.edit:SetText("a")
M.frame.edit:SetText("")
EQ("aucun objet cree en combat", CREATED, c0)
M.Hide()
W.combat = false
EQ("aucune erreur interne", SUI.errCount, 0)
-- niveau reel du cadre de contenu change par le client apres la construction : les controles doivent rester AU-DESSUS (sinon plus aucun clic)
M.Show()
M.Open("cat", "actionbars")
M.child:SetFrameLevel(M.child:GetFrameLevel() + 9)
M.Render()
do
  local kids = { M.child:GetChildren() }
  local minl, nctl = 1000000, 0
  for i = 1, table.getn(kids) do
    if kids[i].ck and kids[i]:IsShown() then
      nctl = nctl + 1
      if kids[i]:GetFrameLevel() < minl then minl = kids[i]:GetFrameLevel() end
    end
  end
  EQ("controles presents", nctl > 0, true)
  EQ("controles au-dessus du cadre de contenu", minl > M.child:GetFrameLevel(), true)
  EQ("M.lvl suit le niveau reel", M.lvl, M.child:GetFrameLevel())
end
M.Hide()
-- /sui menudiag : diagnostic immediat, sans erreur
M.Show()
local e0 = SUI.errCount
SUI.Command("menudiag")
EQ("menudiag : aucune erreur", SUI.errCount, e0)
M.Hide()
EQ("aucune erreur interne (fin)", SUI.errCount, 0)
DONE()
