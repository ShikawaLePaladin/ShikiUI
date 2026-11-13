-- t_minimap : module "minimap" (cadre, forme, taille, zoom, coordonnees, zone, heure, boutons d'addons, coexistence pfUI, modes, cycle de vie).
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Minimap
local TH = SUI.Theme

MM_SETUP()
-- pfUI fait tourner sa minimap et ses boutons d'addons : le module ShikiUI attend, meme en combat
pfUI = { module = { minimap = function() end, addonbuttons = function() end } }
pfUI_config = { disabled = {} }
W.combat = true
BOOT()
SETTLE()

SECTION("t_minimap : coexistence pfUI et construction hors combat")
local mod = SUI.modules.minimap
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
EQ("ligne pfUI relevee", SUI.Migrate.MAP.minimap and table.concat(SUI.Migrate.MAP.minimap, ","), "minimap,addonbuttons")
EQ("etat attente", SUI.Migrate.State("minimap"), "wait")
T("module retenu", not mod.enabled)
EQ("minimap intacte (parent d'origine)", Minimap.parent, MinimapCluster)
EQ("aucun cadre ShikiUI", M.holder, nil)
T("prise en main", SUI.Migrate.Take("minimap"))
EQ("pfUI coupe : minimap", pfUI_config.disabled.minimap, "1")
EQ("pfUI coupe : boutons", pfUI_config.disabled.addonbuttons, "1")
SUI.Migrate.Boot()
C.Notify(nil, nil)
EQ("module actif", mod.enabled, true)
EQ("combat : pas de cadre cree", M.holder, nil)
EQ("combat : pas de minuterie", M.task, nil)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
EQ("construit apres le combat", M.built, true)
T("cadre cree", M.holder ~= nil)
EQ("aucune erreur interne", SUI.errCount, 0)
EQ("la minimap vit dans le cadre ShikiUI", Minimap.parent, M.holder)
EQ("position via le moteur de mise en page", SUI.Layout.items["minimap"].frame, M.holder)
EQ("taille de la minimap", Minimap:GetWidth(), 140)
EQ("taille du cadre", M.holder:GetWidth(), 146)
EQ("masque rond par defaut", Minimap.mask, "Textures\\MinimapMask")
EQ("decor masque : bordure", MinimapBorder:IsShown(), false)
EQ("decor masque : zoom +", MinimapZoomIn:IsShown(), false)
EQ("decor masque : horloge du jeu", GameTimeFrame:IsShown(), false)
EQ("cadre visible", M.holder:IsShown(), true)
T("une minuterie", M.task ~= nil)

SECTION("t_minimap : zoom")
EQ("molette active", Minimap.wheelOn, true)
local wheel = Minimap:GetScript("OnMouseWheel")
T("script de molette", wheel ~= nil)
this = Minimap; arg1 = 1; wheel()
EQ("molette haut : zoom +", Minimap.zoom, 1)
arg1 = -1; wheel(); wheel()
EQ("molette bas : zoom -", Minimap.zoom, -1)
C.Set("minimap.wheel", false)
EQ("molette coupee", Minimap.wheelOn, false)
arg1 = 1; wheel()
EQ("molette coupee : aucun zoom", Minimap.zoom, -1)
C.Set("minimap.wheel", true)

SECTION("t_minimap : coordonnees, zone, heure")
Pump(0.6)
EQ("coordonnees (1 decimale)", M.coordText:GetText(), "45.7, 50.0")
EQ("coordonnees visibles", M.coordText:IsShown(), true)
C.Set("minimap.dec", 0)
EQ("0 decimale", M.coordText:GetText(), "46, 50")
C.Set("minimap.dec", 2)
EQ("2 decimales", M.coordText:GetText(), "45.67, 50.00")
C.Set("minimap.dec", 1)
MMAP.x, MMAP.y = 0, 0
Pump(0.6)
EQ("instance : tirets", M.coordText:GetText(), "--")
MMAP.x, MMAP.y = 0.1, 0.2
Pump(0.6)
EQ("coordonnees mises a jour", M.coordText:GetText(), "10.0, 20.0")
C.Set("minimap.coords", false)
EQ("coordonnees coupees : cache", M.coordText:IsShown(), false)
EQ("coordonnees coupees : vide", M.coordText:GetText(), "")
C.Set("minimap.coords", true)
EQ("nom de la zone", M.zoneText:GetText(), "Elwynn")
EQ("zone amie : couleur 'good'", M.zoneText.tc[1], TH.c.good[1])
EQ("zone amie : couleur 'good' (vert)", M.zoneText.tc[2], TH.c.good[2])
MMAP.zone, MMAP.pvp = "Durotar", "hostile"
local before = MMAP.mapSet
Fire("ZONE_CHANGED_NEW_AREA")
EQ("zone changee", M.zoneText:GetText(), "Durotar")
EQ("zone hostile : couleur 'bad'", M.zoneText.tc[1], TH.c.bad[1])
EQ("carte recalee sur la zone", MMAP.mapSet, before + 1)
MMAP.pvp = "contested"
Fire("MINIMAP_ZONE_CHANGED")
EQ("zone contestee : couleur 'warn'", M.zoneText.tc[2], TH.c.warn[2])
MMAP.pvp = nil
Fire("ZONE_CHANGED")
EQ("zone neutre : couleur du texte", M.zoneText.tc[1], TH.c.text[1])
WorldMapFrame:Show()
before = MMAP.mapSet
Fire("ZONE_CHANGED")
EQ("carte du monde ouverte : pas de recalage", MMAP.mapSet, before)
WorldMapFrame:Hide()
C.Set("minimap.zonepvp", false)
MMAP.pvp = "hostile"
Fire("ZONE_CHANGED")
EQ("couleur de zone coupee", M.zoneText.tc[1], TH.c.text[1])
C.Set("minimap.zonepvp", true)
C.Set("minimap.zone", false)
EQ("nom de zone coupe : cache", M.zoneText:IsShown(), false)
C.Set("minimap.zone", true)
EQ("horloge coupee par defaut", M.clockText:IsShown(), false)
C.Set("minimap.clock", "local")
EQ("heure locale", M.clockText:GetText(), "14:05")
EQ("horloge visible", M.clockText:IsShown(), true)
C.Set("minimap.clock", "server")
EQ("heure du serveur", M.clockText:GetText(), "09:07")
MMAP.minute = 8
Pump(0.6)
EQ("heure mise a jour", M.clockText:GetText(), "09:08")
C.Set("minimap.clock", "off")
EQ("horloge coupee", M.clockText:IsShown(), false)

SECTION("t_minimap : forme, taille, opacite")
C.Set("minimap.shape", "square")
EQ("masque carre", Minimap.mask, "Interface\\ChatFrame\\ChatFrameBackground")
C.Set("minimap.shape", "round")
EQ("masque rond", Minimap.mask, "Textures\\MinimapMask")
C.Set("minimap.size", 200)
EQ("taille minimap", Minimap:GetWidth(), 200)
EQ("hauteur minimap", Minimap:GetHeight(), 200)
EQ("taille cadre", M.holder:GetWidth(), 206)
C.Set("minimap.alpha", 0.5)
EQ("opacite", M.holder:GetAlpha(), 0.5)
C.Set("minimap.alpha", 1)
C.Set("minimap.size", 140)
C.Set("minimap.clutter", false)
EQ("decors rendus", MinimapBorder:IsShown(), true)
C.Set("minimap.clutter", true)
EQ("decors masques de nouveau", MinimapBorder:IsShown(), false)

SECTION("t_minimap : boutons d'addons regroupes")
local b1 = MM_BUTTON("LibDBIcon10_Foo", true)
local b2 = MM_BUTTON("MonAddonMinimapButton", true)
MM_BUTTON("MiniMapMailFrame", true)         -- bouton du client : jamais touche
MM_BUTTON("PinDecoratif", false)            -- pas de clic : pas un bouton
MM_BUTTON("TropGrand", true, 80)            -- trop grand : pas un bouton
MM_BUTTON("ShikiUI_Autre", true)
EQ("rien de range avant la recherche", M.nbtn, 0)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("minimap scan")
EQ("deux boutons ranges", M.nbtn, 2)
CONTAINS("message", CHATTEXT(), "2 bouton(s)")
EQ("parent = tiroir", b1.parent, M.drawer)
EQ("taille rangee", b1:GetWidth(), 28)
EQ("hauteur rangee", b2:GetHeight(), 28)
EQ("largeur du tiroir", M.drawer:GetWidth(), 3 + 2 * 31)
EQ("hauteur du tiroir", M.drawer:GetHeight(), 3 + 31)
-- cadre rebelle : un addon qui reprend la main sur la taille de son bouton ne doit pas etre range
-- (sinon il reste une "barre" qui deborde du tiroir)
local breb = MM_BUTTON("RebelMinimapButton", true)
local w0 = breb:GetWidth()
local ow, oh = breb.SetWidth, breb.SetHeight
breb.SetWidth = function() end
breb.SetHeight = function() end
SlashCmdList["SHIKIUI"]("minimap scan")
EQ("cadre rebelle : collecte mais pas dans la grille", M.nbtn, 3)
EQ("cadre rebelle : grille a deux", M.ngrp, 2)
EQ("cadre rebelle : rendu a son parent d'origine", breb.parent ~= M.drawer, true)
EQ("cadre rebelle : taille d'origine conservee", breb:GetWidth(), w0)
EQ("tiroir ferme", M.drawer:IsShown(), false)
breb.SetWidth, breb.SetHeight = ow, oh   -- le rebelle redevient sage pour la suite de la suite
for i = table.getn(Minimap.kids), 1, -1 do
  if Minimap.kids[i] == breb then table.remove(Minimap.kids, i) end
end
for i = M.nbtn, 1, -1 do
  if M.btns[i].f == breb then
    table.remove(M.btns, i)
    M.nbtn = M.nbtn - 1
  end
end
breb:SetParent(nil)
-- une INFOBULLE (LibDBIconTooltip) n'est jamais un bouton : jamais collectee, et purgee si elle l'avait ete
local tip = CreateFrame("GameTooltip", "LibDBIconTooltipTest", Minimap)
tip:SetWidth(27)
tip:SetHeight(27)
tip:SetScript("OnMouseUp", function() end)
table.insert(Minimap.kids, tip)
W.combat = false
SlashCmdList["SHIKIUI"]("minimap scan")
EQ("infobulle : jamais collectee", M.nbtn, 2)
-- une infobulle DEJA collectee (ancien scan) est purgee au scan suivant : son cadre est lui-meme une GameTooltip
local tip2 = CreateFrame("GameTooltip", "LibDBIconTooltipOld", Minimap)
tip2.SetParent = function(self, p) self.parent = p end   -- comme MM_BUTTON : le parent suivi (le vrai jeu met a jour aussi)
tip2:SetWidth(27)
tip2:SetHeight(27)
tip2:SetScript("OnMouseUp", function() end)
table.insert(Minimap.kids, tip2)
tip2:SetParent(M.drawer)   -- l'infobulle avait ete rangee dans le tiroir (disp = drawer)
table.insert(M.btns, { f = tip2, name = "LibDBIconTooltipOld", kind = "addon", parent = Minimap, point = "TOPLEFT", rel = Minimap, relPoint = "TOPLEFT", x = 5, y = -5, w = 27, h = 27, disp = "drawer" })
M.nbtn = M.nbtn + 1
tip2.suiGrouped = true
SlashCmdList["SHIKIUI"]("minimap scan")
EQ("infobulle pre-collectee : purgee au scan suivant", M.nbtn, 2)
EQ("infobulle purgee : rendue a sa place d'origine", tip2.parent, Minimap)
EQ("infobulle purgee : plus groupee", tip2.suiGrouped, nil)
-- cadre NON CARRE (ex. TWBGQueueMinimapMenuFrame 40x32) : proportions conservees, ramene a l'echelle du slot,
-- centre, et son echelle d'origine est rendue au remplacement
local bns = CreateFrame("Button", "WideMenuFrameTest", Minimap)
bns.SetWidth = nil
bns.SetWidth = function(self, w) self.wide = w end
bns.GetWidth = function(self) return self.wide or 40 end
bns.SetHeight = function(self, h) self.high = h end
bns.GetHeight = function(self) return self.high or 32 end
bns:SetWidth(40)
bns:SetHeight(32)
bns:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 5, -5)
bns:SetScript("OnClick", function() end)
table.insert(Minimap.kids, bns)
SlashCmdList["SHIKIUI"]("minimap scan")
EQ("non carre : collecte", M.nbtn, 3)
EQ("non carre : largeur d'origine", bns:GetWidth(), 40)
NEAR("non carre : echelle 28/40", bns:GetScale(), 0.7, 0.01)
EQ("non carre : largeur effective du slot", math.floor(bns:GetWidth() * bns:GetScale() + 0.5), 28)
-- remis sur le bord : l'echelle d'origine (1) est rendue
if M.keep then M.keep["WideMenuFrameTest"] = true end
SlashCmdList["SHIKIUI"]("minimap scan")
NEAR("non carre remis sur le bord : echelle rendue", bns:GetScale(), 1, 0.01)
EQ("non carre remis : largeur d'origine", bns:GetWidth(), 40)
if M.keep then M.keep["WideMenuFrameTest"] = nil end
for i = table.getn(Minimap.kids), 1, -1 do
  if Minimap.kids[i] == bns then table.remove(Minimap.kids, i) end
end
for i = M.nbtn, 1, -1 do
  if M.btns[i].f == bns then table.remove(M.btns, i); M.nbtn = M.nbtn - 1 end
end
bns:SetParent(nil)
for i = table.getn(Minimap.kids), 1, -1 do
  if Minimap.kids[i] == tip or Minimap.kids[i] == tip2 then table.remove(Minimap.kids, i) end
end
for i = M.nbtn, 1, -1 do
  if M.btns[i].f == tip2 then table.remove(M.btns, i); M.nbtn = M.nbtn - 1 end
end
tip:SetParent(nil)
tip2:SetParent(nil)
local p1 = b1.points[table.getn(b1.points)]
EQ("ancre du premier bouton", p1[1], "TOPLEFT")
EQ("decalage du premier bouton", p1[4], 3)
local p2 = b2.points[table.getn(b2.points)]
EQ("decalage du second bouton", p2[4], 3 + 31)
SlashCmdList["SHIKIUI"]("minimap scan")
EQ("recherche sans doublon", M.nbtn, 2)
Click(M.toggle)
EQ("bouton +  : tiroir ouvert", M.drawer:IsShown(), true)
Click(M.toggle)
EQ("bouton +  : tiroir ferme", M.drawer:IsShown(), false)
SlashCmdList["SHIKIUI"]("minimap drawer")
EQ("commande : tiroir", M.drawer:IsShown(), true)
M.drawer:Hide()
local b3 = MM_BUTTON("AutreMinimapIcon", true)
local b4 = MM_BUTTON("EncoreUnBouton", true)
C.Set("minimap.cols", 2)
SlashCmdList["SHIKIUI"]("minimap scan")
EQ("quatre boutons", M.nbtn, 4)
EQ("deux colonnes : largeur", M.drawer:GetWidth(), 3 + 2 * 31)
EQ("deux lignes : hauteur", M.drawer:GetHeight(), 3 + 2 * 31)
local p4 = b4.points[table.getn(b4.points)]
EQ("quatrieme bouton : colonne 2", p4[4], 3 + 31)
EQ("quatrieme bouton : ligne 2", p4[5], -(3 + 31))
C.Set("minimap.cols", 4)
C.Set("minimap.btnsize", 36)
EQ("taille de bouton changee", b1:GetWidth(), 36)
C.Set("minimap.btnsize", 28)
C.Set("minimap.edge", false)   -- sans ancrage sur le bord, le bouton retrouve l'ancre de l'addon
C.Set("minimap.buttons", false)
EQ("regroupement coupe : parent rendu", b1.parent, Minimap)
EQ("regroupement coupe : taille rendue", b1:GetWidth(), 31)
EQ("regroupement coupe : bouton + cache", M.toggle:IsShown(), false)
local pb = b1.points[table.getn(b1.points)]
EQ("regroupement coupe : position rendue", pb[1], "TOPLEFT")
EQ("regroupement coupe : decalage rendu", pb[4], 5)
C.Set("minimap.buttons", true)
C.Set("minimap.edge", true)
EQ("regroupement repris", b1.parent, M.drawer)
EQ("bouton + revenu", M.toggle:IsShown(), true)
-- combat : la recherche attend
local late = MM_BUTTON("TardifMinimapButton", true)
W.combat = true
SlashCmdList["SHIKIUI"]("minimap scan")
EQ("combat : rien de range", M.nbtn, 4)
T("recherche en attente", M.pending)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
EQ("apres le combat : range", M.nbtn, 5)
EQ("tardif range", late.parent, M.drawer)
local late2 = MM_BUTTON("EncoreTardifMinimapButton", true)
Fire("PLAYER_ENTERING_WORLD")
Pump(3.2)
EQ("recherche automatique apres l'entree dans le monde", M.nbtn, 6)
EQ("deuxieme recherche", late2.parent, M.drawer)

SECTION("t_minimap : mode Raid")
SUI.Mode.Set("raid", "manual")
EQ("raid : taille", C.Get("minimap.size"), 120)
EQ("raid : cadre", M.holder:GetWidth(), 126)
EQ("raid : minimap", Minimap:GetWidth(), 120)
EQ("raid : zone cachee", M.zoneText:IsShown(), false)
SUI.Mode.Set("normal", "manual")
EQ("retour Normal : taille", C.Get("minimap.size"), 140)
EQ("retour Normal : zone", M.zoneText:IsShown(), true)

SECTION("t_minimap : commandes")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("minimap")
CONTAINS("position", CHATTEXT(), "10.0, 20.0")
CONTAINS("nombre de boutons", CHATTEXT(), "6 bouton(s)")

SECTION("t_minimap : icones natives en direct")
C.Set("minimap.mailpos", "default")   -- la boite du courrier a deja ete rangee par les sections precedentes : on repart de l'origine
local mf = MiniMapMailFrame
local mb = CreateFrame("Frame", "MiniMapMailBorder", mf)
local mi = CreateFrame("Frame", "MiniMapMailIcon", mf)
mi.SetTexCoord = function(self, a, b, c, d) self.tc = { a, b, c, d } end
mf:SetParent(MinimapCluster)
mf:SetScale(1)
C.Set("minimap.mailpos", "bottomleft")
EQ("courrier : parent = cadre", mf.parent, M.holder)
EQ("courrier : anneau cache", mb:IsShown(), false)
EQ("courrier : decoupe", mi.tc and mi.tc[1], 0.08)
C.Set("minimap.mailpos", "topright")
local pt = mf.points[table.getn(mf.points)]
EQ("courrier : coin change sans reload", pt[1], "TOPRIGHT")
C.Set("minimap.mailpos", "default")
EQ("courrier : rendu au parent", mf.parent, MinimapCluster)
EQ("courrier : anneau rendu", mb:IsShown(), true)
EQ("courrier : decoupe rendue", mi.tc[1], 0)
EQ("courrier : echelle rendue", mf:GetScale(), 1)
C.Set("minimap.mailpos", "topleft")
EQ("courrier : restyle apres origine", mf.parent, M.holder)
C.Set("minimap.mailpos", "hide")
EQ("courrier : cache", mf:IsShown(), false)
C.Set("minimap.mailpos", "topleft")
EQ("courrier : reglage reversible", mf.parent, M.holder)
EQ("aucune erreur interne (natives)", SUI.errCount, 0)

SECTION("t_minimap : audit des icones - liste blanche, modes, surveillance")
local function names()
  local out = {}
  local list = M.List()
  for i = 1, table.getn(list) do out[list[i].name or "?"] = list[i] end
  return out, list
end
local function liveTasks(name)
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == name and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end
local known = names()
T("liste : bouton d'addon", known["LibDBIcon10_Foo"] ~= nil)
T("liste : calendrier du jeu", known["GameTimeFrame"] ~= nil)
T("liste : zoom du jeu", known["MinimapZoomIn"] ~= nil)
T("liste : suivi du jeu", known["MiniMapTracking"] ~= nil)
T("liste : courrier", known["MiniMapMailFrame"] ~= nil)
T("liste : pas de bouton factice", known["PinDecoratif"] == nil and known["TropGrand"] == nil)
EQ("liste : genre addon", known["LibDBIcon10_Foo"].kind, "addon")
EQ("liste : genre jeu", known["GameTimeFrame"].kind, "blizzard")
EQ("liste : genre alerte", known["MiniMapMailFrame"].kind, "native")
EQ("icones du jeu masquees : suivi", MiniMapTracking:IsShown(), false)
EQ("icones du jeu masquees : pierre de rencontre", MiniMapMeetingStoneFrame:IsShown(), false)
EQ("icones du jeu masquees : carte", MiniMapWorldMapButton:IsShown(), false)
EQ("icones du jeu masquees : calendrier", GameTimeFrame:IsShown(), false)
-- le jeu veut remontrer une icone : Show est neutralise, et un Show venu du moteur est re-masque par la surveillance
MiniMapTracking:Show()
EQ("le jeu ne remontre pas le suivi (Show)", MiniMapTracking:IsShown(), false)
MiniMapTracking.shown = true
Pump(2.1)
EQ("le jeu ne remontre pas le suivi (moteur)", MiniMapTracking:IsShown(), false)

-- options declarees
local meta = SUI.Config.meta
EQ("option mode des icones", meta["minimap.btnmode"] and meta["minimap.btnmode"].type, "choice")
EQ("option liste blanche", meta["minimap.keep"] and meta["minimap.keep"].type, "text")
EQ("option interrupteur de liste", meta["minimap.iconlist"] and meta["minimap.iconlist"].type, "bool")
T("mode inconnu refuse", not C.Set("minimap.btnmode", "nimporte"))
EQ("mode inchange", C.Get("minimap.btnmode"), "drawer")
local m1 = M.ParseKeep(" A , B,,C ,A")
T("liste blanche lue", m1.A and m1.B and m1.C and not m1[""])
EQ("liste blanche ecrite triee", M.KeepString({ B = true, A = true, C = false }), "A,B")

-- liste blanche : effet immediat, sans /reload
C.Set("minimap.keep", "GameTimeFrame,LibDBIcon10_Foo")
EQ("liste blanche : calendrier visible", GameTimeFrame:IsShown(), true)
EQ("liste blanche : bouton laisse sur la minimap", b1.parent, Minimap)
EQ("liste blanche : taille d'origine", b1:GetWidth(), 31)
EQ("liste blanche : l'autre reste dans le tiroir", b2.parent, M.drawer)
EQ("liste blanche : zoom reste masque", MinimapZoomIn:IsShown(), false)
local gp = GameTimeFrame.points[table.getn(GameTimeFrame.points)]
EQ("icone gardee : accrochee au cadre ShikiUI", gp[2], M.holder)
M.SetKeep("GameTimeFrame", false)
EQ("on retire de la liste : calendrier masque", GameTimeFrame:IsShown(), false)
EQ("liste blanche = bouton Foo seul", C.Get("minimap.keep"), "LibDBIcon10_Foo")
M.SetKeep("LibDBIcon10_Foo", false)
EQ("liste vide", C.Get("minimap.keep"), "")
EQ("bouton range de nouveau", b1.parent, M.drawer)
EQ("taille de tiroir", b1:GetWidth(), 28)

-- fenetre a cases a cocher
SlashCmdList["SHIKIUI"]("minimap icons")
T("fenetre creee", M.win ~= nil)
EQ("fenetre ouverte", M.win:IsShown(), true)
local function rowFor(name)
  for i = 1, table.getn(M.win.rows) do
    local r = M.win.rows[i]
    if r.rec and r.rec.name == name and r:IsShown() then return r end
  end
  return nil
end
for p = 1, 6 do
  M.page = p
  M.RefreshList()
  if rowFor("LibDBIcon10_Foo") then break end
end
local row = rowFor("LibDBIcon10_Foo")
T("fenetre : ligne du bouton", row ~= nil)
EQ("fenetre : case decochee", row.check.on, false)
Click(row.check)
EQ("case cochee : liste blanche", C.Get("minimap.keep"), "LibDBIcon10_Foo")
EQ("case cochee : bouton laisse en place", b1.parent, Minimap)
T("case cochee : ligne a jour", rowFor("LibDBIcon10_Foo").check.on)
Click(row.check)
EQ("case decochee : liste vide", C.Get("minimap.keep"), "")
EQ("case decochee : bouton range", b1.parent, M.drawer)
local _, all = names()
T("plus de 12 icones : plusieurs pages", table.getn(all) > 12)
M.page = 1
M.ListPage(1)
EQ("page suivante", M.page, 2)
M.ListPage(-5)
EQ("page limitee", M.page, 1)
M.win:Hide()
-- interrupteur du menu : ouvre la fenetre puis se remet a zero
C.Set("minimap.iconlist", true)
EQ("menu : fenetre ouverte", M.win:IsShown(), true)
EQ("menu : interrupteur remis a zero", C.Get("minimap.iconlist"), false)
M.win:Hide()
W.combat = true
CHATCLEAR()
SlashCmdList["SHIKIUI"]("minimap icons")
EQ("combat : fenetre fermee", M.win:IsShown(), false)
CONTAINS("combat : message", CHATTEXT(), "combat")
W.combat = false
CHATCLEAR()
SlashCmdList["SHIKIUI"]("minimap list")
CONTAINS("commande list : en-tete", CHATTEXT(), "icone(s) detectee(s)")
CONTAINS("commande list : un bouton", CHATTEXT(), "LibDBIcon10_Foo")

-- boutons crees tardivement : trouves par la surveillance, sans commande ni entree dans le monde
local nb = M.nbtn
local w1 = MM_BUTTON("SurveillanceMinimapButton", true)
local w2 = MM_BUTTON("SousUIParentMinimapButton", true, 30, UIParent)
local w3 = MM_BUTTON("CadreAvecMouseUp", true, 30, nil, "Frame")
local w4 = CreateFrame("Button", nil, Minimap)
w4.SetParent = function(self, p) self.parent = p end
w4:SetWidth(30); w4:SetHeight(30); w4:SetScript("OnClick", function() end)
local w5 = MM_BUTTON("QuestieNote_12", true)                -- repere de carte : jamais un bouton
local w6 = MM_BUTTON("GatherMatePin7", true)
local w7 = MM_BUTTON("LibDBIcon10_GrosMaisBouton", true, 60)   -- trop grand
Pump(2.1)
EQ("surveillance : quatre nouveaux boutons", M.nbtn, nb + 4)
EQ("surveillance : bouton de la minimap", w1.parent, M.drawer)
EQ("surveillance : bouton sous UIParent ancre a la minimap", w2.parent, M.drawer)
EQ("surveillance : cadre avec OnMouseUp", w3.parent, M.drawer)
EQ("surveillance : bouton sans nom", w4.parent, M.drawer)
EQ("repere de carte laisse", w5.parent, Minimap)
EQ("point de carte laisse", w6.parent, Minimap)
EQ("trop grand laisse", w7.parent, Minimap)
local _, list2 = names()
local unnamed = 0
for i = 1, table.getn(list2) do if list2[i].name == nil then unnamed = unnamed + 1 end end
EQ("liste : bouton sans nom present", unnamed, 1)
-- combat : la surveillance attend, puis rattrape
W.combat = true
local w8 = MM_BUTTON("ApresCombatMinimapButton", true)
Pump(2.1)
EQ("combat : pas de recherche", w8.parent, Minimap)
W.combat = false
Pump(2.1)
EQ("apres le combat : rattrape", w8.parent, M.drawer)
-- un addon remet son bouton sur la minimap : la surveillance le range de nouveau
w1.parent = Minimap
w1.points = {}
w1:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 1, -1)
Pump(2.1)
EQ("bouton repris par l'addon : range de nouveau", w1.parent, M.drawer)

-- mode "tout masquer"
C.Set("minimap.btnmode", "hide")
EQ("masquer tout : bouton + cache", M.toggle:IsShown(), false)
EQ("masquer tout : tiroir ferme", M.drawer:IsShown(), false)
EQ("masquer tout : bouton dans le tiroir cache", b1.parent, M.drawer)
EQ("masquer tout : courrier masque", MiniMapMailFrame:IsShown(), false)
C.Set("minimap.keep", "MiniMapMailFrame,LibDBIcon10_Foo")
EQ("masquer tout + liste blanche : courrier visible", MiniMapMailFrame:IsShown(), true)
EQ("masquer tout + liste blanche : bouton visible", b1.parent, Minimap)
C.Set("minimap.keep", "")
C.Set("minimap.clutter", false)
EQ("masquer tout sans decors : calendrier quand meme masque", GameTimeFrame:IsShown(), false)
SlashCmdList["SHIKIUI"]("minimap drawer")
EQ("masquer tout : /sui minimap drawer ouvre quand meme", M.drawer:IsShown(), true)
M.drawer:Hide()
-- mode tiroir sans masquer les decors : le client est laisse visible (et range a gauche du cadre)
C.Set("minimap.btnmode", "drawer")
EQ("tiroir : bouton + revenu", M.toggle:IsShown(), true)
EQ("tiroir : courrier revenu", MiniMapMailFrame:IsShown(), true)
EQ("decors gardes : calendrier visible", GameTimeFrame:IsShown(), true)
local cp = GameTimeFrame.points[table.getn(GameTimeFrame.points)]
EQ("decors gardes : calendrier accroche au cadre ShikiUI", cp[2], M.holder)
C.Set("minimap.clutter", true)
EQ("decors masques : calendrier", GameTimeFrame:IsShown(), false)

-- mode "au survol"
C.Set("minimap.btnmode", "hover")
EQ("survol : pas de bouton +", M.toggle:IsShown(), false)
EQ("survol : une minuterie", liveTasks("minimap.hover"), 1)
EQ("survol : tiroir ferme", M.drawer:IsShown(), false)
MMAP.over = M.holder
Pump(0.3)
EQ("survol : la souris sur la minimap ouvre le tiroir", M.drawer:IsShown(), true)
MMAP.over = M.drawer
Pump(1)
EQ("survol : la souris sur le tiroir le garde ouvert", M.drawer:IsShown(), true)
MMAP.over = nil
Pump(0.3)
EQ("survol : delai de grace", M.drawer:IsShown(), true)
Pump(0.6)
EQ("survol : souris partie, tiroir ferme", M.drawer:IsShown(), false)
C.Set("minimap.btnmode", "drawer")
EQ("tiroir : minuterie de survol arretee", liveTasks("minimap.hover"), 0)
EQ("tiroir : + revenu", M.toggle:IsShown(), true)
MMAP.over = M.holder
Pump(0.5)
EQ("tiroir : plus d'ouverture au survol", M.drawer:IsShown(), false)
MMAP.over = nil
C.Set("minimap.buttons", false)
EQ("icones non gerees : bouton laisse", w1.parent, Minimap)
EQ("icones non gerees : plus de bouton +", M.toggle:IsShown(), false)
C.Set("minimap.buttons", true)
EQ("icones gerees de nouveau", w1.parent, M.drawer)
EQ("aucune erreur interne (icones)", SUI.errCount, 0)

SECTION("t_minimap : boutons ancres sur le bord de la minimap")
M.RestoreButtons()   -- les boutons des sections precedentes sont oublies : on repart d'une minimap sans autre bouton
local savedBtns, savedN = M.btns, M.nbtn
M.btns = {}
M.nbtn = 0
C.Set("minimap.keep", "")
C.Set("minimap.btnmode", "drawer")
C.Set("minimap.buttons", false)      -- rien dans le tiroir : tous les boutons restent visibles, donc doivent etre sur le bord
C.Set("minimap.zone", false)
C.Set("minimap.coords", false)
C.Set("minimap.clock", "off")
C.Set("minimap.edge", true)
EQ("option declaree", meta["minimap.edge"] and meta["minimap.edge"].type, "bool")
EQ("option par defaut", meta["minimap.edge"] and meta["minimap.edge"].default, true)
local function polar(f)
  local pt = f.points[table.getn(f.points)]
  local x, y = pt[4], pt[5]
  local ang = math.deg(math.atan(y, x))
  if ang < 0 then ang = ang + 360 end
  return pt, math.sqrt(x * x + y * y), ang, x, y
end
-- bouton a rayon "en dur" de 80 et angle 20 degres : centre sur la Minimap
local ea = MM_BUTTON("EdgeAMinimapButton", true, 30)
ea:ClearAllPoints()
ea:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(math.rad(20)), 80 * math.sin(math.rad(20)))
-- bouton pose sous UIParent et ancre a MinimapCluster (reste "en haut a droite" quand la minimap bouge) : meme angle de 20 degres
MinimapCluster:SetWidth(200)
MinimapCluster:SetHeight(200)
local eb = MM_BUTTON("EdgeBMinimapButton", true, 30, UIParent)
eb:ClearAllPoints()
-- centre voulu : angle 200 degres a 80 du centre de la minimap d'origine ; centre de la minimap d'origine = (30, 30) dans le repere du centre du cluster
eb:SetPoint("CENTER", MinimapCluster, "TOPRIGHT", 30 + 80 * math.cos(math.rad(200)) - 100, 30 + 80 * math.sin(math.rad(200)) - 100)
-- bouton typique a coordonnees d'ecran en dur (ancre UIParent, hors de la minimap, nom reconnaissable)
local ec = CreateFrame("Button", "SAS_MinimapButton", UIParent)
ec.SetParent = function(self, p) self.parent = p end
ec:SetWidth(33)
ec:SetHeight(33)
ec:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -5, -5)
ec:SetScript("OnClick", function() end)
SlashCmdList["SHIKIUI"]("minimap scan")
local half = 70
local rad = half + 3
local pa, ra, aa = polar(ea)
EQ("bord : ancre au centre de la minimap", pa[2], Minimap)
EQ("bord : point central", pa[1], "CENTER")
T("bord : rayon = bord du cadre (pas 80 en dur)", math.abs(ra - rad) < 0.01)
T("bord : angle d'origine conserve (20)", math.abs(aa - 20) < 0.5)
EQ("bord : parent = minimap", ea.parent, Minimap)
local pb, rb, ab = polar(eb)
EQ("cluster : ancre au centre de la minimap", pb[2], Minimap)
T("cluster : angle d'origine retrouve (200)", math.abs(ab - 200) < 0.5)
T("cluster : rayon", math.abs(rb - rad) < 0.01)
local pc, rc, ac = polar(ec)
T("bouton a coordonnees en dur : reconnu", ec.parent == Minimap and pc[2] == Minimap)
T("bouton a coordonnees en dur : sur le bord", math.abs(rc - rad) < 0.01)
-- en direct : taille de la minimap
C.Set("minimap.size", 200)
local _, rs = polar(ea)
T("taille 200 : le bouton suit le bord", math.abs(rs - 103) < 0.01)
C.Set("minimap.size", 140)
-- forme carree : le bouton est sur le cote carre
C.Set("minimap.shape", "square")
local _, _, _, sx, sy = polar(ea)
T("carre : sur le cote", math.abs(math.max(math.abs(sx), math.abs(sy)) - rad) < 0.01)
T("carre : angle conserve", math.abs(math.deg(math.atan(sy, sx)) - 20) < 0.5)
C.Set("minimap.shape", "round")
-- evitement : zone en haut, coordonnees en bas a gauche
local et = MM_BUTTON("EdgeTopMinimapButton", true, 30)
et:ClearAllPoints()
et:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(math.rad(240)), 80 * math.sin(math.rad(240)))
SlashCmdList["SHIKIUI"]("minimap scan")
local _, _, at0 = polar(et)
T("sans zone : angle 240 respecte", math.abs(at0 - 240) < 0.5)
C.Set("minimap.coords", true)
local _, _, at1 = polar(et)
T("coordonnees affichees : le bouton s'ecarte du texte", math.abs(at1 - 240) > 25)
C.Set("minimap.coords", false)
local _, _, at2 = polar(et)
T("coordonnees masquees : retour a l'angle voulu", math.abs(at2 - 240) < 0.5)
-- deux boutons au meme angle : pas de chevauchement
local ed = MM_BUTTON("EdgeDMinimapButton", true, 30)
ed:ClearAllPoints()
ed:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(math.rad(20)), 80 * math.sin(math.rad(20)))
SlashCmdList["SHIKIUI"]("minimap scan")
local _, _, ad = polar(ed)
local _, _, aa2 = polar(ea)
T("deux boutons : angles distincts", math.abs(ad - aa2) >= 15)
-- l'addon deplace son bouton (glisser) : nouvel angle respecte
ea:ClearAllPoints()
ea:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(math.rad(300)), 80 * math.sin(math.rad(300)))
Pump(2.1)
local pm, rm, am = polar(ea)
T("glisser par l'addon : nouvel angle (300)", math.abs(am - 300) < 4)
T("glisser par l'addon : retour sur le bord", math.abs(rm - rad) < 0.01)
-- option coupee : l'ancre de l'addon est rendue
C.Set("minimap.edge", false)
local po = ea.points[table.getn(ea.points)]
T("option coupee : ancre de l'addon rendue", po[1] == "CENTER" and math.abs(po[4] - 80 * math.cos(math.rad(300))) < 0.5)
C.Set("minimap.edge", true)
local _, rr = polar(ea)
T("option remise : de nouveau sur le bord", math.abs(rr - rad) < 0.01)
-- tiroir : les boutons non gardes vont dans le tiroir, pas sur le bord
C.Set("minimap.buttons", true)
EQ("tiroir : bouton range", ea.parent, M.drawer)
EQ("tiroir : plus de marque de bord", M.btns[1].edge, nil)
-- liste blanche : retour sur le bord
C.Set("minimap.keep", "EdgeAMinimapButton")
EQ("liste blanche : sur le bord", ea.parent, Minimap)
local _, rk = polar(ea)
T("liste blanche : rayon du bord", math.abs(rk - rad) < 0.01)
C.Set("minimap.keep", "")
C.Set("minimap.zone", true)
C.Set("minimap.coords", true)
EQ("aucune erreur interne (bord)", SUI.errCount, 0)
-- Simple Action Sets : SASMinimapFrame (cadre sans script, parent Minimap) porte SASMinimapButton ; l'addon le pose lui-meme avec
-- SASMinimap_PosUpdate (SetPoint TOPLEFT calcule pour une minimap de 140). Le client remplace l'ancre de meme nom (le mock les empile).
local sasPos = 200
local sasCalls = 0
local sas = MM_BUTTON("SASMinimapFrame", false, 30, nil, "Frame")
local sasBtn = CreateFrame("Button", "SASMinimapButton", sas)
sasBtn:SetScript("OnClick", function() end)
local function sasPlace()
  sasCalls = sasCalls + 1
  for i = table.getn(sas.points), 1, -1 do
    if sas.points[i][1] == "TOPLEFT" then table.remove(sas.points, i) end
  end
  sas:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 53 - (80 * math.cos(math.rad(sasPos))), (80 * math.sin(math.rad(sasPos))) - 55)
end
local sasOrigFn = sasPlace
rawset(_G, "SASMinimap_PosUpdate", sasOrigFn)
sas:ClearAllPoints()
sasPlace()
local function sasWant(p) return (math.deg(math.atan(80 * math.sin(math.rad(p)), -2 - 80 * math.cos(math.rad(p)))) + 360) % 360 end
C.Set("minimap.buttons", false)
SlashCmdList["SHIKIUI"]("minimap scan")
local sasRec
for i = 1, M.nbtn do if M.btns[i].name == "SASMinimapFrame" then sasRec = M.btns[i] end end
T("SAS : cadre reconnu comme bouton de minimap", sasRec ~= nil)
T("SAS : le bouton enfant n'est pas pris a part", M.btns[M.nbtn].name ~= "SASMinimapButton")
local ps, rs, as = polar(sas)
T("SAS : sur le bord de la minimap", math.abs(rs - rad) < 0.01)
T("SAS : angle d'origine conserve", math.abs(as - sasWant(200)) < 0.5)
EQ("SAS : une seule ancre", sas:GetNumPoints(), 1)
T("SAS : fonction de l'addon enveloppee", _G.SASMinimap_PosUpdate ~= sasOrigFn)
-- glissement de l'icone : SAS rappelle PosUpdate (SetPoint TOPLEFT sans ClearAllPoints) -> reprise immediate, sans boucle
sasPos = 100
local before = sasCalls
_G.SASMinimap_PosUpdate()
EQ("SAS : un seul appel de l'addon par glissement", sasCalls - before, 1)
EQ("SAS : une seule ancre apres glissement", sas:GetNumPoints(), 1)
local _, rs2, as2 = polar(sas)
T("SAS : nouvel angle appris (100)", math.abs(sasRec.ang - sasWant(100)) < 0.5 and math.abs(as2 - as) > 5)
T("SAS : rayon du bord apres glissement", math.abs(rs2 - rad) < 0.01)
before = sasCalls
Pump(6)
EQ("SAS : pas de rappel en boucle", sasCalls - before, 0)
-- sans l'enveloppe (autre chemin) : la surveillance rattrape le double ancrage
sasPos = 20
sasOrigFn()
EQ("SAS : double ancrage detecte", sas:GetNumPoints(), 2)
Pump(2.1)
EQ("SAS : surveillance : une seule ancre", sas:GetNumPoints(), 1)
local _, rs3, as3 = polar(sas)
T("SAS : surveillance : angle appris (20)", math.abs(sasRec.ang - sasWant(20)) < 0.5)
-- mode tiroir : le cadre va dans le tiroir
C.Set("minimap.buttons", true)
EQ("SAS : range dans le tiroir", sas.parent, M.drawer)
C.Set("minimap.buttons", false)
EQ("SAS : retour sur le bord", sas.parent, Minimap)
EQ("aucune erreur interne (SAS)", SUI.errCount, 0)
M.RestoreButtons()
M.btns, M.nbtn = savedBtns, savedN
sas.parent = nil
sasBtn.parent = nil
rawset(_G, "SASMinimap_PosUpdate", nil)
M.sasOrig = nil
C.Set("minimap.buttons", true)

SECTION("t_minimap : lanceur ShikiUI - cadre, position, ouverture")
if not rawget(_G, "GameTooltip") then CreateFrame("GameTooltip", "GameTooltip", UIParent) end
rawset(_G, "IsShiftKeyDown", function() return W.shift and 1 or nil end)
W.shift = nil
C.Set("minimap.shape", "round")
C.Set("minimap.size", 140)
C.Set("minimap.buttons", true)
local ln = M.launcher
T("lanceur cree (option par defaut)", ln ~= nil)
EQ("enfant du cadre ShikiUI", ln.parent, M.holder)
EQ("visible", ln:IsShown(), true)
EQ("taille", ln:GetWidth(), 22)
EQ("angle par defaut", C.Get("minimap.launchangle"), 165)
local lp = ln.points[table.getn(ln.points)]
EQ("ancre au centre du cadre", lp[1], "CENTER")
EQ("relative au cadre ShikiUI", lp[2], M.holder)
T("rayon = bord du cadre", math.abs(math.sqrt(lp[4] * lp[4] + lp[5] * lp[5]) - 73) < 0.01)
T("angle 165 (gauche, un peu haut)", lp[4] < 0 and lp[5] > 0 and math.abs(math.deg(math.atan(lp[5], lp[4])) - 165) < 0.5)
T("niveau au-dessus de la minimap", ln:GetFrameLevel() > Minimap:GetFrameLevel() + 6)
M.RequestScan()
local seenLn = false
for i = 1, M.nbtn do if M.btns[i].f == ln then seenLn = true end end
EQ("jamais range dans le tiroir", seenLn, false)
local rv = M.Reserved(70, 73, 30)
local foundRes = false
for i = 1, table.getn(rv) do if math.abs(rv[i][1] - 165) < 0.5 then foundRes = true end end
T("zone reservee sur l'anneau des boutons d'addons", foundRes)
C.Set("minimap.shape", "square")
local sp2 = ln.points[table.getn(ln.points)]
T("forme carree : sur le bord du carre", math.abs(math.abs(sp2[4]) - 73) < 0.01 and sp2[5] > 0 and sp2[5] < 73)
C.Set("minimap.shape", "round")
C.Set("minimap.launchangle", 90)
local ap = ln.points[table.getn(ln.points)]
T("angle 90 : en haut", math.abs(ap[4]) < 0.01 and math.abs(ap[5] - 73) < 0.01)
C.Set("minimap.launchangle", 165)
C.Set("minimap.launchsize", 28)
EQ("taille changee", ln:GetWidth(), 28)
C.Set("minimap.launchsize", 22)

SECTION("t_minimap : lanceur ShikiUI - infobulle")
GameTooltip.lines = nil
this = ln
ln:GetScript("OnEnter")()
this = nil
T("infobulle : titre + etat + 5 aides", GameTooltip.lines and table.getn(GameTooltip.lines) == 7)
CONTAINS("infobulle : titre avec version", GameTooltip.lines[1], "ShikiUI")
CONTAINS("infobulle : profil", GameTooltip.lines[2], C.curName)
CONTAINS("infobulle : clic gauche", GameTooltip.lines[3], "Clic gauche")
CONTAINS("infobulle : clic droit", GameTooltip.lines[4], "Clic droit")
CONTAINS("infobulle : Maj", GameTooltip.lines[5], "Maj")
CONTAINS("infobulle : milieu", GameTooltip.lines[6], "milieu")
CONTAINS("infobulle : glisser", GameTooltip.lines[7], "Glisser")
C.Set("ui.locale", "en")
this = ln
ln:GetScript("OnEnter")()
this = nil
CONTAINS("infobulle en anglais", GameTooltip.lines[3], "Left click")
C.Set("ui.locale", "fr")

SECTION("t_minimap : lanceur ShikiUI - clics")
local calls = { menu = 0, move = 0, drawer = 0 }
local oMenuToggle, oMoveToggle, oDrawer = SUI.Menu.Toggle, SUI.Mover.Toggle, M.ToggleDrawer
SUI.Menu.Toggle = function() calls.menu = calls.menu + 1 end
SUI.Mover.Toggle = function() calls.move = calls.move + 1 end
M.ToggleDrawer = function() calls.drawer = calls.drawer + 1 end
ln:Click("LeftButton")
EQ("clic gauche : menu /sui", calls.menu, 1)
W.shift = true
ln:Click("LeftButton")
EQ("Maj + clic : mode Deplacer", calls.move, 1)
EQ("Maj + clic : pas de menu", calls.menu, 1)
W.shift = nil
ln:Click("MiddleButton")
EQ("clic milieu : tiroir", calls.drawer, 1)
SUI.Menu.Toggle, SUI.Mover.Toggle, M.ToggleDrawer = oMenuToggle, oMoveToggle, oDrawer
W.combat = true
CHATCLEAR()
M.QOpen(ln)
EQ("en combat : pas de creation du menu rapide", M.qm, nil)
W.combat = false

SECTION("t_minimap : menu rapide")
ln:Click("RightButton")
local qm = M.qm
T("menu rapide cree", qm ~= nil)
EQ("menu rapide ouvert", qm:IsShown(), true)
EQ("capteur de clics ouvert", M.qcatch:IsShown(), true)
T("menu au-dessus du capteur", qm:GetFrameLevel() > M.qcatch:GetFrameLevel())
T("modules proposes", table.getn(M.qlist) > 5)
local hasMinimap, hasCore = false, false
for i = 1, table.getn(M.qlist) do
  if M.qlist[i].name == "minimap" then hasMinimap = true end
  if SUI.modules[M.qlist[i].name].core then hasCore = true end
end
EQ("la minimap n'est pas proposee", hasMinimap, false)
EQ("aucun module du socle", hasCore, false)
local sorted = true
for i = 2, table.getn(M.qlist) do if M.qlist[i - 1].key > M.qlist[i].key then sorted = false end end
T("liste triee par nom", sorted)
T("premiere page remplie", qm.rows[1]:IsShown() and qm.rows[1].mname == M.qlist[1].name)
CONTAINS("profil affiche", qm.bProfile.label:GetText(), C.curName)
CONTAINS("mode affiche", qm.bMode.label:GetText(), "Normal")
CONTAINS("page affichee", qm.pageText:GetText(), "1 /")
local esc = false
for i = 1, table.getn(UISpecialFrames) do if UISpecialFrames[i] == "ShikiUI_MinimapQuick" then esc = true end end
T("Echap ferme le menu", esc)
-- infobulle d'une ligne
GameTooltip.lines = nil
this = qm.rows[1]
qm.rows[1]:GetScript("OnEnter")()
this = nil
T("infobulle de ligne : nom + description + aide", GameTooltip.lines and table.getn(GameTooltip.lines) >= 2)
-- pages
local np = M.QPages()
T("plusieurs pages", np > 1)
M.qpage = 1
this = qm
arg1 = -1
qm:GetScript("OnMouseWheel")()
EQ("molette bas : page 2", M.qpage, 2)
arg1 = 1
qm:GetScript("OnMouseWheel")()
EQ("molette haut : page 1", M.qpage, 1)
arg1 = 1
qm:GetScript("OnMouseWheel")()
EQ("molette haut en page 1 : derniere page", M.qpage, np)
this, arg1 = nil, nil
M.qpage = 1
M.QRender()
-- module : un clic coupe, un autre rallume
local first = qm.rows[1].mname
local was = C.Get("modules." .. first)
qm.rows[1]:Click("LeftButton")
EQ("clic sur un module : bascule", C.Get("modules." .. first), not was)
qm.rows[1]:Click("LeftButton")
EQ("deuxieme clic : retour", C.Get("modules." .. first), was)
-- profil
local p0 = C.curName
C.NewProfile("TmpQuick", p0)
C.NewProfile("TmpQuick2", p0)
qm.bProfile:Click("LeftButton")
T("profil suivant", C.curName ~= p0)
qm.bProfile:Click("RightButton")
EQ("profil precedent", C.curName, p0)
qm.bProfile:Click("RightButton")
T("profil precedent en boucle (retour a la fin)", C.curName ~= p0)
qm.bProfile:Click("LeftButton")
EQ("retour au profil de depart", C.curName, p0)
C.DeleteProfile("TmpQuick")
C.DeleteProfile("TmpQuick2")
-- mode
qm.bMode:Click("LeftButton")
EQ("mode Raid", C.mode, "raid")
CONTAINS("libelle du mode", qm.bMode.label:GetText(), "Raid")
EQ("bouton de mode en surbrillance", qm.bMode.selected, true)
qm.bMode:Click("LeftButton")
EQ("retour au mode Normal", C.mode, "normal")
-- style
local st0 = C.Get("style.name")
qm.bStyle:Click("LeftButton")
T("style suivant", C.Get("style.name") ~= st0 or table.getn(SUI.Style.names) < 2)
qm.bStyle:Click("RightButton")
EQ("style precedent", C.Get("style.name"), st0)
-- Deplacer, aide, reglages
local mv = 0
local oMT = SUI.Mover.Toggle
SUI.Mover.Toggle = function() mv = mv + 1 end
qm.bMove:Click("LeftButton")
SUI.Mover.Toggle = oMT
EQ("Deplacer appele", mv, 1)
EQ("Deplacer ferme le menu", qm:IsShown(), false)
M.QOpen(ln)
CHATCLEAR()
qm.bHelp:Click("LeftButton")
CONTAINS("aide dans le chat", CHATTEXT(), "/sui")
EQ("Aide ferme le menu", qm:IsShown(), false)
M.QOpen(ln)
local shown = 0
local oShow = SUI.Menu.Show
SUI.Menu.Show = function() shown = shown + 1 end
qm.bSettings:Click("LeftButton")
SUI.Menu.Show = oShow
EQ("Reglages ouvre le menu", shown, 1)
EQ("Reglages ferme le menu rapide", qm:IsShown(), false)
-- fermeture par le capteur, par la commande, positionnement
M.QOpen(ln)
M.qcatch:Click("LeftButton")
EQ("clic ailleurs : ferme", qm:IsShown(), false)
EQ("capteur ferme", M.qcatch:IsShown(), false)
SlashCmdList["SHIKIUI"]("minimap menu")
EQ("/sui minimap menu : ouvre", qm:IsShown(), true)
local qp = qm.points[table.getn(qm.points)]
EQ("ancre du menu : ouvre vers le haut (lanceur en bas)", qp[1], "BOTTOMLEFT")
EQ("ancre du menu : relative au lanceur", qp[2], ln)
T("hauteur du menu plausible", qm:GetHeight() > 200)
SlashCmdList["SHIKIUI"]("minimap menu")
EQ("/sui minimap menu : ferme", qm:IsShown(), false)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_minimap : lanceur ShikiUI - glisser")
MOUSE.x, MOUSE.y, MOUSE.down = 0, 100, true
ln:GetScript("OnMouseDown")()
local ds = ln:GetScript("OnDragStart")
this = ln
ds()
this = nil
EQ("glissement en cours", M.lnDrag, true)
T("une minuterie de glissement", M.dragTask ~= nil)
Pump(0.05)
local dp = ln.points[table.getn(ln.points)]
T("suit le curseur (90 degres)", math.abs(dp[4]) < 0.5 and math.abs(dp[5] - 73) < 0.5)
EQ("rien n'est ecrit pendant le glissement", C.Get("minimap.launchangle"), 165)
MOUSE.x, MOUSE.y = -100, -100
Pump(0.05)
dp = ln.points[table.getn(ln.points)]
T("suit le curseur (225 degres)", dp[4] < 0 and dp[5] < 0 and math.abs(dp[4] - dp[5]) < 0.5)
MOUSE.down = false
Pump(0.05)
EQ("relache detecte : glissement fini", M.lnDrag, false)
EQ("angle memorise", C.Get("minimap.launchangle"), 225)
EQ("minuterie arretee", M.dragTask, nil)
local calls2 = 0
local oT = SUI.Menu.Toggle
SUI.Menu.Toggle = function() calls2 = calls2 + 1 end
ln:Click("LeftButton")
EQ("le clic qui suit un glissement est ignore", calls2, 0)
ln:GetScript("OnMouseDown")()
ln:Click("LeftButton")
EQ("clic suivant normal", calls2, 1)
SUI.Menu.Toggle = oT
-- arret par OnDragStop
MOUSE.x, MOUSE.y, MOUSE.down = 100, 0, true
this = ln
ds()
this = nil
Pump(0.05)
this = ln
ln:GetScript("OnDragStop")()
this = nil
EQ("OnDragStop : angle memorise (0)", C.Get("minimap.launchangle"), 0)
EQ("OnDragStop : minuterie arretee", M.dragTask, nil)
MOUSE.down = false
C.Set("minimap.launchangle", 165)
-- le glissement ferme le menu rapide ; couper l'option l'arrete
M.QOpen(ln)
MOUSE.down = true
this = ln
ds()
this = nil
EQ("le glissement ferme le menu rapide", M.qm:IsShown(), false)
C.Set("minimap.launcher", false)
EQ("option coupee : lanceur cache", ln:IsShown(), false)
EQ("option coupee : glissement arrete", M.dragTask, nil)
MOUSE.down = false
C.Set("minimap.launcher", true)
EQ("option rallumee : lanceur visible", ln:IsShown(), true)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_minimap : visibilite conditionnelle et police")
EQ("cadre enregistre au service de visibilite", SUI.Visibility.Count(), 1)
T("options vis et fade declarees", SUI.Config.meta["minimap.vis"] ~= nil and SUI.Config.meta["minimap.fade"] ~= nil)
EQ("vis : defaut toujours", C.Get("minimap.vis"), "always")
T("options de police declarees", SUI.Config.meta["minimap.font"] ~= nil and SUI.Config.meta["minimap.fontsize"] ~= nil)
M.drawer:Show()
M.QOpen(ln)
C.Set("minimap.vis", "never")
Pump(0.1, 8)
EQ("jamais : cadre cache", M.holder:IsShown(), false)
EQ("jamais : tiroir ferme", M.drawer:IsShown(), false)
EQ("jamais : menu rapide ferme", M.qm:IsShown(), false)
C.Set("minimap.alpha", 0.6)
EQ("opacite : pas de reapparition cachee", M.holder:IsShown(), false)
C.Set("minimap.vis", "always")
Pump(0.1, 8)
EQ("toujours : cadre visible", M.holder:IsShown(), true)
EQ("opacite du reglage restauree", M.holder:GetAlpha(), 0.6)
C.Set("minimap.alpha", 1)
EQ("opacite pleine", M.holder:GetAlpha(), 1)
C.Set("minimap.vis", "combat")
Pump(0.1, 8)
EQ("combat seulement : cache hors combat", M.holder:IsShown(), false)
C.Set("minimap.size", 120)
EQ("changer la taille cachee ne montre pas le cadre", M.holder:IsShown(), false)
C.Set("minimap.size", 140)
C.Set("minimap.vis", "always")
Pump(0.1, 8)
EQ("retour visible", M.holder:IsShown(), true)
-- police
local fpath = "Interface\\AddOns\\MesMedias\\police.ttf"
SUI.RegisterAsset("font", "mapfont", fpath)
C.Set("minimap.font", "mapfont")
EQ("police des coordonnees", M.coordText.font, fpath)
EQ("police de la zone", M.zoneText.font, fpath)
EQ("police de l'heure", M.clockText.font, fpath)
C.Set("minimap.fontsize", 14)
EQ("taille absolue", M.zoneText.fsize, 14)
C.Set("minimap.fontsize", 0)
C.Set("minimap.font", "style")
T("police du style rendue", M.coordText.font ~= fpath)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_minimap : desactivation et reactivation")
local function live()
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == "minimap.tick" and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end
EQ("une minuterie", live(), 1)
C.Set("minimap.shape", "square")
EQ("masque carre pose", Minimap.mask, "Interface\\ChatFrame\\ChatFrameBackground")
C.Set("modules.minimap", false)
EQ("module coupe", mod.enabled, false)
EQ("cadre cache", M.holder:IsShown(), false)
EQ("minimap rendue a son parent", Minimap.parent, MinimapCluster)
EQ("masque rond rendu", Minimap.mask, "Textures\\MinimapMask")
EQ("decors rendus", MinimapBorder:IsShown(), true)
EQ("molette rendue", Minimap.wheelOn, false)
EQ("boutons rendus", b1.parent, Minimap)
EQ("courrier rendu a la coupure", MiniMapMailFrame.parent, MinimapCluster)
EQ("taille minimap d'origine rendue", Minimap:GetWidth(), 140)
EQ("suivi rendu au jeu", MiniMapTracking:IsShown(), true)
MiniMapTracking:Hide()
MiniMapTracking:Show()
EQ("Show du jeu retabli", MiniMapTracking:IsShown(), true)
EQ("calendrier rendu", GameTimeFrame:IsShown(), true)
EQ("fenetre des icones fermee", M.win:IsShown(), false)
EQ("lanceur cache", M.launcher:IsShown(), false)
EQ("menu rapide ferme", M.qm:IsShown(), false)
M.QOpen(M.holder)
EQ("module coupe : le menu rapide ne s'ouvre pas", M.qm:IsShown(), false)
Pump(0.1)
EQ("service de visibilite libere", SUI.Visibility.Count(), 0)
EQ("opacite d'origine rendue", M.holder:GetAlpha(), 1)
EQ("minuterie rendue", live(), 0)
C.Set("modules.minimap", true)
EQ("module rallume", mod.enabled, true)
EQ("minimap reprise", Minimap.parent, M.holder)
EQ("decors masques", MinimapBorder:IsShown(), false)
EQ("boutons reranges", b1.parent, M.drawer)
EQ("suivi masque de nouveau", MiniMapTracking:IsShown(), false)
EQ("liste blanche conservee", C.Get("minimap.keep"), "")
C.Set("minimap.shape", "round")
EQ("une seule minuterie apres rallumage", live(), 1)
EQ("lanceur de retour", M.launcher:IsShown(), true)
EQ("service de visibilite de nouveau", SUI.Visibility.Count(), 1)
EQ("aucune erreur interne", SUI.errCount, 0)
T("pas de texte manquant", next(SUI.missingL) == nil)
C.Set("ui.locale", "en")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("minimap")
CONTAINS("anglais", CHATTEXT(), "button(s) in the drawer")
C.Set("ui.locale", "fr")
DONE()
