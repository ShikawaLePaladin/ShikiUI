-- t_bags : sacs unifies et banque (fenetres, emplacements, recherche / filtres, valeur, tri, banque, combat, modes, pfUI).
local SUI = ShikiUI
local C = SUI.Config
local TH = SUI.Theme
local L = SUI.L
BGINSTALL()
BGRESET()
-- realiste : le code Blizzard plante si le bouton n'a pas l'enfant "<nom>Cooldown" ; on ne doit jamais l'appeler
ContainerFrame_UpdateCooldown = function(bag, b)
  W.bg.blizzcalls = (W.bg.blizzcalls or 0) + 1
  local cd = getglobal(b:GetName() .. "Cooldown")
  cd.nilcrash = cd.x.y
end
setglobal("CooldownFrame_SetTimer", function(cd, st, du, en) W.bg.cds = W.bg.cds + 1; cd.timer = { st, du, en } end)
ABINSTALL = ABINSTALL or function() end
local function callScript(f, name) this = f; f.scripts[name]() end
local function has(lang, key) return SUI.locales[lang][key] ~= nil end
local function win(k) return SUI.Bags.wins[k] end
local function sb(k, bag, slot) return win(k).holder[bag].btn[slot] end
local function alphaOf(b) return b.alpha end
local function dimmed(k)
  local n = 0
  local w = win(k)
  for i = 1, w.n do
    if alphaOf(w.order[i]) < 1 then n = n + 1 end
  end
  return n
end
local function money(c) return L("msg.bags.money", math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100) end
local function textOf(k) return win(k).value:GetText() end
local function pump(n) Pump(0.1, n or 2) end

-- Blizzard : fonctions d'origine (stubs) que le module remplace puis restaure
local NAMES = { "ToggleBackpack", "OpenBackpack", "CloseBackpack", "ToggleBag", "OpenBag", "CloseBag", "OpenAllBags", "CloseAllBags", "ToggleKeyRing" }
local orig = {}
for _, n in ipairs(NAMES) do
  orig[n] = function() ACT("blizz " .. n) end
  setglobal(n, orig[n])
end

-- objets de test
BGINFO(100, { name = "Epee Rare", q = 3, type = "Arme", sub = "Epees", eq = "INVTYPE_WEAPON", price = 5000 })
BGINFO(101, { name = "Torche", q = 1, type = "Divers", sub = "Divers", price = 10 })
BGINFO(102, { name = "Pain", q = 1, type = "Consommable", sub = "Nourriture", price = 5 })
BGINFO(103, { name = "Chiffon Gris", q = 0, type = "Divers", sub = "Camelote", price = 3 })
BGINFO(104, { name = "Casque Epique", q = 4, type = "Armure", sub = "Tissu", eq = "INVTYPE_HEAD", price = 20000 })
BGINFO(105, { name = "Potion", q = 1, type = "Consommable", sub = "Potion", price = 50 })
BGINFO(106, { name = "Os Gris", q = 0, type = "Divers", sub = "Camelote", price = 7 })
BGINFO(107, { name = "Anneau Vert", q = 2, type = "Armure", sub = "Bijou", eq = "INVTYPE_FINGER", price = 300 })

local function fillStart()
  W.bg.slot = {}
  BGLAYOUT({ [0] = 16, [1] = 6 })
  BGPUT(0, 1, 100, 1); BGPUT(0, 2, 103, 1); BGPUT(0, 4, 102, 5); BGPUT(0, 5, 104, 1); BGPUT(0, 7, 106, 1); BGPUT(0, 9, 101, 1)
  BGPUT(1, 1, 107, 1); BGPUT(1, 3, 105, 3); BGPUT(1, 4, 103, 2)
end
fillStart()
W.bg.money = 123456

SECTION("t_bags : contrat et etat au demarrage")
BOOT()
SETTLE()
local mod = SUI.modules.bags
T("module enregistre", mod ~= nil)
EQ("cout declare", mod.cost, "medium")
EQ("coupe par defaut (mise au point)", mod.enabled, nil)
EQ("aucune fenetre construite", next(SUI.Bags.wins), nil)
EQ("aucune erreur au demarrage", SUI.errCount, 0)
T("ligne Migrate.MAP", SUI.Migrate.MAP.bags ~= nil and SUI.Migrate.MAP.bags[1] == "bags")
for _, n in ipairs(NAMES) do T("Blizzard intact : " .. n, getglobal(n) == orig[n]) end

SECTION("t_bags : activation et remplacement des fonctions d'ouverture")
C.Set("modules.bags", true)
SETTLE()
local M = SUI.Bags
EQ("actif", mod.enabled, true)
EQ("encore aucune fenetre (creation a la demande)", next(M.wins), nil)
for _, n in ipairs(NAMES) do T("remplace : " .. n, getglobal(n) ~= orig[n]) end
local c0 = CREATED
getglobal("ToggleBackpack")()
EQ("ouverture : fenetre des sacs creee", win("bag") ~= nil, true)
EQ("fenetre visible", win("bag").frame:IsShown(), true)
EQ("nom de la fenetre", win("bag").frame:GetName(), "ShikiUI_Bag")
local esc = false
for i = 1, table.getn(UISpecialFrames) do if UISpecialFrames[i] == "ShikiUI_Bag" then esc = true end end
T("Echap ferme la fenetre", esc)
getglobal("ToggleBackpack")()
EQ("deuxieme appel : ferme", win("bag").frame:IsShown(), false)
getglobal("OpenAllBags")(true)
EQ("OpenAllBags(force) ouvre", win("bag").frame:IsShown(), true)
getglobal("OpenAllBags")(true)
EQ("OpenAllBags(force) ne ferme pas", win("bag").frame:IsShown(), true)
getglobal("CloseAllBags")()
EQ("CloseAllBags ferme", win("bag").frame:IsShown(), false)
getglobal("ToggleBag")(1)
EQ("ToggleBag ouvre", win("bag").frame:IsShown(), true)
getglobal("CloseBag")(1)
EQ("CloseBag ferme", win("bag").frame:IsShown(), false)
getglobal("OpenBackpack")()
EQ("OpenBackpack ouvre", win("bag").frame:IsShown(), true)
local blizz = 0
for _, a in ipairs(W.acts) do if string.find(a, "blizz ", 1, true) then blizz = blizz + 1 end end
EQ("jamais d'appel aux fonctions d'origine", blizz, 0)

SECTION("t_bags : emplacements, mise en page, affichage")
local w = win("bag")
EQ("22 emplacements (16 + 6)", w.n, 22)
EQ("sacs listes (0 a 4)", w.nlist, 5)
EQ("sac 0 : holder portant l'identifiant du sac", w.holder[0].calls.SetID[1], 0)
EQ("sac 1 : holder portant l'identifiant du sac", w.holder[1].calls.SetID[1], 1)
EQ("emplacement : identifiant", sb("bag", 0, 5).calls.SetID[1], 5)
EQ("nom du bouton", sb("bag", 0, 5):GetName(), "ShikiUI_Item_0_5")
EQ("sac sans place : pas de holder", w.holder[2], nil)
local p1 = w.order[1].points[1]
EQ("bouton 1 : x", p1[4], 6)
EQ("bouton 1 : y", p1[5], -54)
EQ("bouton 2 : x", w.order[2].points[1][4], 6 + 34)
EQ("bouton 11 : retour a la ligne x", w.order[11].points[1][4], 6)
EQ("bouton 11 : retour a la ligne y", w.order[11].points[1][5], -88)
EQ("bouton : largeur", w.order[1]:GetWidth(), 32)
EQ("fenetre : largeur", w.frame:GetWidth(), 350)
EQ("fenetre : hauteur", w.frame:GetHeight(), 184)
EQ("un seul point par bouton", table.getn(w.order[11].points), 1)
EQ("icone", sb("bag", 0, 1).itex, "Interface\\Icons\\Item100")
EQ("quantite d'une pile", sb("bag", 0, 4).icount, 5)
EQ("emplacement vide : pas d'icone", sb("bag", 0, 3).itex, nil)
EQ("emplacement vide : quantite 0", sb("bag", 0, 3).icount == nil or sb("bag", 0, 3).icount == 0, true)
EQ("pas desature", sb("bag", 0, 1).idesat, false)
T("recharge relue", sb("bag", 0, 1).cd ~= nil and sb("bag", 0, 1).cd.timer ~= nil)
EQ("code Blizzard de recharge jamais appele", W.bg.blizzcalls, nil)
local rare = sb("bag", 0, 1).bbc
NEAR("bordure rare : r", rare[1], 0.3)
NEAR("bordure rare : g", rare[2], 0.6)
NEAR("bordure epique", sb("bag", 0, 5).bbc[1], 0.4)
NEAR("bordure inhabituelle", sb("bag", 1, 1).bbc[1], 0.2)
NEAR("commun sous la limite : bordure neutre", sb("bag", 0, 9).bbc[1], TH.c.border[1])
NEAR("gris sous la limite : bordure neutre", sb("bag", 0, 2).bbc[1], TH.c.border[1])
NEAR("vide : bordure neutre", sb("bag", 0, 3).bbc[1], TH.c.border[1])
EQ("ligne de valeur", textOf("bag"), L("msg.bags.value.bag", money(123456), 13, 22))
EQ("titre", w.title:GetText(), L("msg.bags.title.bag"))
local f0 = CREATED
Fire("BAG_UPDATE", 0)
pump(5)
EQ("rafraichissement : aucune frame creee", CREATED, f0)

SECTION("t_bags : evenements groupes (pas de travail dans l'evenement)")
BGPUT(0, 3, 105, 1)
BGPUT(1, 2, 101, 1)
Fire("BAG_UPDATE", 0)
EQ("evenement : rien n'est relu tout de suite", sb("bag", 0, 3).itex, nil)
pump(2)
EQ("minuterie : sac 0 relu", sb("bag", 0, 3).itex, "Interface\\Icons\\Item105")
EQ("sac 1 non signale : pas relu", sb("bag", 1, 2).itex, nil)
Fire("BAG_UPDATE", 1)
pump(2)
EQ("sac 1 signale : relu", sb("bag", 1, 2).itex, "Interface\\Icons\\Item101")
EQ("valeur : places libres mises a jour", textOf("bag"), L("msg.bags.value.bag", money(123456), 11, 22))
W.bg.money = 5
Fire("PLAYER_MONEY")
pump(2)
EQ("argent mis a jour", textOf("bag"), L("msg.bags.value.bag", money(5), 11, 22))
W.bg.slot[0][1].held = true
Fire("ITEM_LOCK_CHANGED")
pump(2)
EQ("objet verrouille : desature", sb("bag", 0, 1).idesat, true)
W.bg.slot[0][1].held = nil
Fire("ITEM_LOCK_CHANGED")
pump(2)
EQ("deverrouille : normal", sb("bag", 0, 1).idesat, false)
local cd0 = W.bg.cds
Fire("BAG_UPDATE_COOLDOWN")
pump(2)
EQ("recharges relues une fois par emplacement", W.bg.cds - cd0, 22)
BGPUT(0, 3, nil)
BGPUT(1, 2, nil)
Fire("BAG_UPDATE", 0); Fire("BAG_UPDATE", 1)
pump(2)

SECTION("t_bags : camelote (valeur) avec l'API de prix")
local _, _, _, _, priced0 = M.Totals(w)
EQ("sans API de prix : pas de valeur de camelote", priced0, false)
BGPRICES(true)
for k in pairs(M.INF.id) do M.INF.id[k] = nil end
Fire("BAG_UPDATE", 0); Fire("BAG_UPDATE", 1)
w.dAll = true
pump(2)
local free, total, junk = M.Totals(w)
EQ("camelote : 3 + 7 + 3 x 2 = 16", junk, 16)
EQ("places libres", free, 13)
EQ("total", total, 22)
EQ("ligne avec camelote", textOf("bag"), L("msg.bags.value.bag", money(5), 13, 22) .. L("msg.bags.value.junk", money(16)))
BGPRICES(false)
for k in pairs(M.INF.id) do M.INF.id[k] = nil end
w.dAll = true
pump(2)

SECTION("t_bags : recherche et filtres")
EQ("sans recherche : rien d'estompe", dimmed("bag"), 0)
w.edit:SetText("EPEE")
pump(2)
EQ("recherche nom : 21 estompes", dimmed("bag"), 21)
EQ("recherche : l'epee reste nette", alphaOf(sb("bag", 0, 1)), 1)
NEAR("recherche : opacite des autres", alphaOf(sb("bag", 0, 2)), 0.25)
w.edit:SetText("armure")
pump(2)
EQ("recherche type : 2 armures nettes", dimmed("bag"), 20)
w.edit:SetText("bijou")
pump(2)
EQ("recherche sous-type", dimmed("bag"), 21)
w.edit:SetText("")
pump(2)
EQ("recherche vide : tout net", dimmed("bag"), 0)
EQ("filtre au depart", w.filter, "all")
Click(w.fbtn)
EQ("filtre equipement", w.filter, "gear")
EQ("libelle du bouton", w.fbtn.label:GetText(), L("choice.bags.filter.gear"))
pump(2)
EQ("equipement : 3 nets", dimmed("bag"), 19)
Click(w.fbtn)
pump(2)
EQ("filtre camelote", w.filter, "junk")
EQ("camelote : 3 nets", dimmed("bag"), 19)
w.edit:SetText("gris")
pump(2)
EQ("camelote + recherche", dimmed("bag"), 19)
w.edit:SetText("chiffon")
pump(2)
EQ("camelote + recherche precise : 2 nets", dimmed("bag"), 20)
w.edit:SetText("")
Click(w.fbtn)
pump(2)
EQ("filtre qualite", w.filter, "good")
EQ("qualite : 3 nets", dimmed("bag"), 19)
Click(w.fbtn)
pump(2)
EQ("retour a tout", w.filter, "all")
EQ("tout net", dimmed("bag"), 0)
-- objet pas encore dans le cache du client : le type est relu plus tard
BGINFO(110, { name = "Fantome", q = 2, type = "Gemme", sub = "Gemme", uncached = true })
BGPUT(0, 3, 110, 1)
Fire("BAG_UPDATE", 0)
pump(2)
w.edit:SetText("gemme")
pump(2)
EQ("cache vide : pas de resultat", dimmed("bag"), 22)
W.bg.info[110].uncached = false
pump(15)
EQ("cache rempli : retrouve", dimmed("bag"), 21)
w.edit:SetText("")
BGPUT(0, 3, nil)
Fire("BAG_UPDATE", 0)
pump(2)

SECTION("t_bags : tri")
local function scramble()
  W.bg.slot = {}
  BGLAYOUT({ [0] = 8, [1] = 4 })
  BGPUT(0, 1, 106, 1); BGPUT(0, 3, 105, 3); BGPUT(0, 4, 101, 1); BGPUT(0, 5, 100, 1); BGPUT(0, 7, 103, 1); BGPUT(0, 8, 104, 1)
  BGPUT(1, 1, 102, 1); BGPUT(1, 2, 105, 5); BGPUT(1, 3, 107, 1)
  Fire("BAG_UPDATE", 0); Fire("BAG_UPDATE", 1)
  pump(3)
end
local function runSort()
  CHATCLEAR()
  Click(w.sbtn)
  pump(150)
end
scramble()
EQ("12 emplacements apres changement de taille", w.n, 12)
runSort()
EQ("sort termine", w.sort, nil)
EQ("tri par qualite : sac 0", BGSTR(0), "104,100,107,102,105,105,101,103")
EQ("tri par qualite : sac 1", BGSTR(1), "106,0,0,0")
EQ("piles : la plus grosse d'abord", W.bg.slot[0][5].count, 5)
EQ("piles : la plus petite ensuite", W.bg.slot[0][6].count, 3)
EQ("curseur vide", CursorHasItem(), nil)
CONTAINS("message de fin", CHATTEXT(), string.sub(L("msg.bags.sort.done", 0), 1, 6))
local picks = W.bg.picks
pump(40)
EQ("trie : plus aucun deplacement", W.bg.picks, picks)
CHATCLEAR()
Click(w.sbtn)
pump(10)
EQ("deja trie : aucun deplacement", W.bg.picks, picks)
EQ("deja trie : termine", w.sort, nil)
EQ("affichage apres le tri : icone", sb("bag", 0, 1).itex, "Interface\\Icons\\Item104")
EQ("affichage apres le tri : vide", sb("bag", 1, 2).itex, nil)

scramble()
C.Set("bags.sort", "type")
runSort()
EQ("tri par type : sac 0", BGSTR(0), "100,104,107,102,105,105,101,103")
EQ("tri par type : sac 1", BGSTR(1), "106,0,0,0")
scramble()
C.Set("bags.sort", "name")
C.Set("bags.junklast", false)
runSort()
EQ("tri par nom sans camelote en dernier : sac 0", BGSTR(0), "107,104,103,100,106,102,105,105")
EQ("tri par nom : sac 1", BGSTR(1), "101,0,0,0")
C.Set("bags.junklast", true)
runSort()
EQ("tri par nom avec camelote en dernier : sac 0", BGSTR(0), "107,104,100,102,105,105,101,103")
EQ("tri par nom avec camelote en dernier : sac 1", BGSTR(1), "106,0,0,0")
C.Set("bags.sort", "quality")

SECTION("t_bags : tri refuse (combat, curseur) et interrompu")
scramble()
local before = BGSTR(0)
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
CHATCLEAR()
EQ("combat : StartSort refuse", M.StartSort(w), false)
CONTAINS("combat : message", CHATTEXT(), L("msg.bags.sort.combat"))
EQ("combat : rien ne bouge", BGSTR(0), before)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
PickupContainerItem(0, 1)
CHATCLEAR()
EQ("curseur occupe : refuse", M.StartSort(w), false)
CONTAINS("curseur : message", CHATTEXT(), L("msg.bags.sort.cursor"))
PickupContainerItem(0, 1)
EQ("curseur rendu", CursorHasItem(), nil)
pump(5)
-- le tri demarre puis le joueur entre en combat : il se met en pause, puis reprend
EQ("tri lance", M.StartSort(w), true)
pump(2)
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
local p2 = W.bg.picks
pump(30)
EQ("combat : tri en pause", W.bg.picks, p2)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
pump(150)
EQ("apres le combat : tri termine", w.sort, nil)
EQ("apres le combat : resultat", BGSTR(0), "104,100,107,102,105,105,101,103")
-- fermer la fenetre interrompt le tri sans perdre d objet
scramble()
EQ("tri relance", M.StartSort(w), true)
pump(3)
w.frame:Hide()
EQ("fermeture : tri annule", w.sort, nil)
EQ("fermeture : curseur vide", CursorHasItem(), nil)
local sp = 0
for bag = 0, 1 do
  for i = 1, W.bg.size[bag] do
    if W.bg.slot[bag][i] then sp = sp + 1 end
  end
end
EQ("aucun objet perdu", sp, 9)
getglobal("OpenBackpack")()
pump(3)
-- blocage : un objet reste verrouille
scramble()
W.bg.lockdur = 1000
EQ("tri lance (verrou durable)", M.StartSort(w), true)
pump(100)
EQ("blocage : tri abandonne", w.sort, nil)
CONTAINS("blocage : message", CHATTEXT(), L("msg.bags.sort.fail"))
W.bg.lockdur = 0.1
NOW = NOW + 2000
pump(5)
-- l'ouverture declenche un tri si demande
scramble()
CHATCLEAR()
C.Set("bags.sortopen", true)
w.frame:Hide()
getglobal("OpenBackpack")()
T("tri a l'ouverture", w.sort ~= nil)
pump(150)
EQ("tri a l'ouverture : resultat", BGSTR(0), "104,100,107,102,105,105,101,103")
C.Set("bags.sortopen", false)
scramble()
w.frame:Hide()
getglobal("OpenBackpack")()
EQ("sans l'option : pas de tri a l'ouverture", w.sort, nil)

SECTION("t_bags : sacs speciaux ignores par le tri (API de sac disponible)")
scramble()
setglobal("GetInventoryItemID", function(u, slot) return 9000 + slot end)
setglobal("ContainerIDToInventoryID", function(bag) return bag end)
setglobal("C_Item", { GetItemInfoInstant = function(id)
  if id == 9001 then return id, "t", "s", "e", "i", 11, 2 end
  if id == 9003 then return id, "t", "s", "e", "i", 1, 1 end
  return id, "t", "s", "e", "i", 1, 0
end })
CHATCLEAR()
local b1s = BGSTR(1)
EQ("sac 1 = carquois", M.BagKind(1), "quiver")
EQ("sac 2 = sac ordinaire", M.BagKind(2), "bag")
EQ("sac 3 = sac special", M.BagKind(3), "special")
EQ("sac 0 : toujours ordinaire", M.BagKind(0), "bag")
EQ("trousseau", M.BagKind(-2), "key")
runSort()
EQ("sac ordinaire trie", BGSTR(0), "104,100,105,101,103,106,0,0")
EQ("sac special inchange", BGSTR(1), b1s)
CONTAINS("message sacs ignores", CHATTEXT(), string.sub(L("msg.bags.sort.skipped", 2), 1, 3))
setglobal("GetInventoryItemID", nil)
setglobal("ContainerIDToInventoryID", nil)
setglobal("C_Item", nil)
EQ("sans API : type de sac inconnu", M.BagKind(1), nil)

SECTION("t_bags : reglages")
fillStart()
Fire("BAG_UPDATE", 0); Fire("BAG_UPDATE", 1)
pump(3)
EQ("retour a 22 emplacements", w.n, 22)
C.Set("bags.size", 40)
C.Set("bags.columns", 8)
pump(2)
EQ("colonnes : retour a la ligne", w.order[9].points[1][5], -(54 + 42))
EQ("taille", w.order[1]:GetWidth(), 40)
EQ("largeur de fenetre", w.frame:GetWidth(), 12 + 8 * 40 + 7 * 2)
C.Set("bags.spacing", 6)
pump(2)
EQ("espace", w.order[2].points[1][4], 6 + 46)
C.Set("bags.size", 32); C.Set("bags.columns", 10); C.Set("bags.spacing", 2)
pump(2)
EQ("retour a la largeur de depart", w.frame:GetWidth(), 350)
C.Set("bags.quality", false)
pump(2)
NEAR("bordures de qualite coupees", sb("bag", 0, 1).bbc[1], TH.c.border[1])
C.Set("bags.quality", true)
C.Set("bags.borderlimit", 4)
pump(2)
NEAR("limite de bordure 4 : rare neutre", sb("bag", 0, 1).bbc[1], TH.c.border[1])
NEAR("limite de bordure 4 : epique colore", sb("bag", 0, 5).bbc[1], 0.4)
C.Set("bags.borderlimit", 2)
pump(2)
NEAR("limite 2 : rare colore", sb("bag", 0, 1).bbc[1], 0.3)
C.Set("bags.counts", false)
pump(2)
EQ("quantites coupees", sb("bag", 0, 4).icount, 0)
C.Set("bags.counts", true)
pump(2)
EQ("quantites remises", sb("bag", 0, 4).icount, 5)
C.Set("bags.value", false)
pump(2)
EQ("valeur coupee", textOf("bag"), "")
C.Set("bags.value", true)
pump(2)
T("valeur remise", textOf("bag") ~= "")
C.Set("bags.search", false)
EQ("recherche cachee", w.edit:IsShown(), false)
C.Set("bags.search", true)
EQ("recherche remise", w.edit:IsShown(), true)
C.Set("bags.filters", false)
EQ("filtre cache", w.fbtn:IsShown(), false)
C.Set("bags.filters", true)
EQ("filtre remis", w.fbtn:IsShown(), true)
W.bg.keysize = 4
C.Set("bags.keyring", true)
pump(2)
EQ("trousseau : 4 emplacements de plus", w.n, 26)
EQ("trousseau : holder -2", w.holder[-2].calls.SetID[1], -2)
EQ("trousseau : nom", sb("bag", -2, 1):GetName(), "ShikiUI_Item_k2_1")
C.Set("bags.keyring", false)
pump(2)
EQ("trousseau retire de la liste", w.nlist, 5)
EQ("trousseau : emplacements caches", sb("bag", -2, 1):IsShown(), false)
EQ("retour a 22 emplacements visibles", w.n, 22)
W.bg.keysize = 0

SECTION("t_bags : taille d'un sac qui change, et combat")
BGBAG(2, 4)
pump(2)
EQ("sac pose : 26 emplacements", w.n, 26)
EQ("nouveaux emplacements : nom", sb("bag", 2, 4):GetName(), "ShikiUI_Item_2_4")
BGBAG(2, 0)
pump(2)
EQ("sac retire : 22 emplacements", w.n, 22)
EQ("emplacement retire cache", sb("bag", 2, 4):IsShown(), false)
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
local c1 = CREATED
CHATCLEAR()
BGBAG(3, 6)
pump(3)
EQ("combat : aucune frame creee", CREATED, c1)
EQ("combat : seuls les emplacements existants", w.n, 22)
for i = 1, 10 do Fire("BAG_UPDATE", 0); Fire("ITEM_LOCK_CHANGED"); pump(1) end
EQ("combat : evenements sans creation", CREATED, c1)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
pump(3)
EQ("fin de combat : emplacements crees", w.n, 28)
BGBAG(3, 0)
pump(2)
EQ("retour a 22", w.n, 22)

SECTION("t_bags : banque")
CreateFrame("Frame", "BankFrame", UIParent)
setglobal("StaticPopup_Show", function(n) ACT("popup " .. n) end)
W.bg.slot[-1] = {}
BGLAYOUT({ [-1] = 24, [5] = 6, [6] = 6 })
BGPUT(-1, 1, 100, 1)
W.bg.banksl = 2
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
CHATCLEAR()
w.frame:Hide()
Fire("BANKFRAME_OPENED")
EQ("banque en combat : fenetre pas creee", win("bank"), nil)
CONTAINS("banque en combat : message", CHATTEXT(), L("msg.bags.combat"))
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
pump(3)
EQ("fin de combat : banque creee", win("bank") ~= nil, true)
local bk = win("bank")
EQ("banque visible", bk.frame:IsShown(), true)
EQ("banque : 24 + 12 emplacements", bk.n, 36)
EQ("banque : holder du sac -1", bk.holder[-1].calls.SetID[1], -1)
EQ("banque : nom du bouton", rawget(_G, "ShikiUI_Item_k1_1") ~= nil, true)
EQ("banque : sac 5", bk.holder[5].calls.SetID[1], 5)
EQ("banque : icone", sb("bank", -1, 1).itex, "Interface\\Icons\\Item100")
EQ("banque : valeur", textOf("bank"), L("msg.bags.value.bank", 35, 36))
EQ("banque : titre", bk.title:GetText(), L("msg.bags.title.bank"))
EQ("sacs aussi ouverts", win("bag").frame:IsShown(), true)
local bf = rawget(_G, "BankFrame")
EQ("Blizzard : banque invisible (echelle)", bf.scale, 0.001)
EQ("Blizzard : banque invisible (opacite)", bf.alpha, 0)
for i = 1, 6 do T("sac de banque " .. i, rawget(_G, "ShikiBankBag" .. i) ~= nil) end
EQ("bouton d'achat visible (2 sur 6)", bk.buy:IsShown(), true)
Click(bk.buy)
EQ("achat : fenetre de confirmation", LASTACT(), "popup CONFIRM_BUY_BANK_SLOT")
W.bg.banksl = 3
BGBAG(7, 6)
Fire("PLAYERBANKBAGSLOTS_CHANGED")
pump(3)
EQ("sac de banque achete : 42 emplacements", bk.n, 42)
BGPUT(-1, 2, 104, 1)
Fire("PLAYERBANKSLOTS_CHANGED")
pump(2)
EQ("banque : objet vu", sb("bank", -1, 2).itex, "Interface\\Icons\\Item104")
EQ("banque : valeur mise a jour", textOf("bank"), L("msg.bags.value.bank", 40, 42))
Fire("BANKFRAME_CLOSED")
EQ("banque fermee", bk.frame:IsShown(), false)
EQ("Blizzard : echelle rendue", bf.scale, 1)
EQ("Blizzard : opacite rendue", bf.alpha, 1)
C.Set("bags.bankwin", false)
Fire("BANKFRAME_OPENED")
EQ("sans remplacement : banque ShikiUI fermee", bk.frame:IsShown(), false)
EQ("sans remplacement : Blizzard intact", bf.scale, 1)
C.Set("bags.bankwin", true)
Fire("BANKFRAME_CLOSED")
getglobal("CloseAllBags")()

SECTION("t_bags : banque, une erreur de bouton ne coupe pas la boucle")
do
  local IC = "Interface"..string.char(92).."Icons"..string.char(92).."Item"
  local bk2 = win("bank")
  C.Set("bags.bankwin", true)
  W.bg.slot[-1] = {}
  BGLAYOUT({ [-1] = 28, [5] = 6, [6] = 6 })
  for i = 1, 28 do BGPUT(-1, i, 100 + i, 1) end
  Fire("BANKFRAME_OPENED")
  pump(3)
  bk2 = win("bank")
  T("banque : au moins 40 emplacements", bk2.n >= 40)
  local seen = 0
  for i = 1, 28 do if sb("bank", -1, i).itex == IC .. (100 + i) then seen = seen + 1 end end
  EQ("banque : les 28 objets affiches", seen, 28)
  -- un bouton dont la mise a jour plante n'interrompt pas les suivants
  local bad = sb("bank", -1, 3)
  local old = bad.GetID
  bad.GetID = function() error("boom") end
  bad.slot = nil
  W.bg.slot[-1][27] = nil
  BGPUT(-1, 27, 150, 1)
  Fire("PLAYERBANKSLOTS_CHANGED")
  pump(3)
  EQ("boucle non coupee apres erreur de bouton", sb("bank", -1, 27).itex, IC .. 150)
  bad.GetID = old
  bad.slot = 3
  EQ("code Blizzard jamais appele (banque)", W.bg.blizzcalls, nil)
  Fire("BANKFRAME_CLOSED")
  getglobal("CloseAllBags")()
end

SECTION("t_bags : commande /sui bags")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("bags")
EQ("/sui bags ouvre", win("bag").frame:IsShown(), true)
SlashCmdList["SHIKIUI"]("bags")
EQ("/sui bags ferme", win("bag").frame:IsShown(), false)
SlashCmdList["SHIKIUI"]("bags find potion")
EQ("find : fenetre ouverte", win("bag").frame:IsShown(), true)
EQ("find : texte recopie", win("bag").edit:GetText(), "potion")
pump(2)
EQ("find : recherche appliquee", dimmed("bag"), 21)
win("bag").edit:SetText("")
pump(2)
SlashCmdList["SHIKIUI"]("bags bank")
EQ("bank : ouvre la banque", win("bank").frame:IsShown(), true)
SlashCmdList["SHIKIUI"]("bags bank")
EQ("bank : la ferme", win("bank").frame:IsShown(), false)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("bags zzz")
CONTAINS("usage", CHATTEXT(), "/sui bags")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("bags sort")
CONTAINS("sort : tri lance", CHATTEXT(), L("msg.bags.sort.start"))
pump(150)
getglobal("CloseAllBags")()

SECTION("t_bags : mode Raid")
EQ("normal : valeur", C.Get("bags.value"), true)
SUI.Mode.Set("raid", "manual")
EQ("raid : pas de ligne de valeur", C.Get("bags.value"), false)
EQ("raid : pas de tri a l'ouverture", C.Get("bags.sortopen"), false)
C.Set("bags.value", true)
EQ("l'ecart de l'utilisateur gagne", C.Get("bags.value"), true)
SUI.Mode.Set("normal", "manual")
EQ("retour Normal", C.Get("bags.value"), true)

SECTION("t_bags : textes et reglages")
EQ("nombre d'options", table.getn(mod.options), 17)
local nsimple = 0
for i = 1, table.getn(mod.options) do
  local o = mod.options[i]
  if o.simple then nsimple = nsimple + 1 end
  for _, lang in ipairs({ "fr", "en" }) do
    T(lang .. " " .. o.label, has(lang, o.label))
    T(lang .. " " .. o.tip, has(lang, o.tip))
    if o.choices then
      for _, v in ipairs(o.choices) do T(lang .. " choix " .. o.key .. "." .. v, has(lang, "choice." .. o.key .. "." .. v)) end
    end
  end
  T("categorie : " .. o.key, o.cat == "bags")
end
EQ("reglages simples", nsimple, 7)
for _, lang in ipairs({ "fr", "en" }) do
  T(lang .. " categorie", has(lang, "cat.bags"))
  T(lang .. " module", has(lang, "opt.modules.bags") and has(lang, "tip.modules.bags"))
  T(lang .. " aide", has(lang, "help.bags"))
  for _, k in ipairs({ "all", "gear", "junk", "good" }) do T(lang .. " filtre " .. k, has(lang, "choice.bags.filter." .. k)) end
end
local def = {}
for i = 1, table.getn(mod.options) do def[mod.options[i].key] = mod.options[i].default end
EQ("defaut colonnes", def["bags.columns"], 10)
EQ("defaut taille", def["bags.size"], 32)
EQ("defaut tri", def["bags.sort"], "quality")
EQ("defaut limite de bordure", def["bags.borderlimit"], 2)
C.Set("bags.columns", 14)
C.Reset("bags.columns")
EQ("reinitialisation", C.Get("bags.columns"), 10)

SECTION("t_bags : coupure du module")
local tasks = SUI.taskCount and SUI.taskCount() or nil
getglobal("OpenAllBags")(true)
C.Set("modules.bags", false)
EQ("coupe", mod.enabled, false)
EQ("fenetre fermee", win("bag").frame:IsShown(), false)
for _, n in ipairs(NAMES) do T("rendu a Blizzard : " .. n, getglobal(n) == orig[n]) end
local leaked = false
for _, ev in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "PLAYER_MONEY" }) do
  local h = SUI.handlers[ev]
  if h then
    for i = 1, table.getn(h) do if h[i] == M.OnEvent then leaked = true end end
  end
end
EQ("evenements rendus", leaked, false)
local c2 = CREATED
local tk0 = M.tickN
W.acts = {}
Fire("BAG_UPDATE", 0)
Fire("BANKFRAME_OPENED")
pump(10)
EQ("coupe : rien ne se passe", CREATED, c2)
EQ("coupe : minuterie arretee", M.tickN, tk0)
EQ("coupe : banque non ouverte", win("bank").frame:IsShown(), false)
EQ("coupe : sacs non ouverts", win("bag").frame:IsShown(), false)
getglobal("ToggleBackpack")()
EQ("coupe : appel d'origine", LASTACT(), "blizz ToggleBackpack")
C.Set("modules.bags", true)
EQ("rallume", mod.enabled, true)
getglobal("OpenAllBags")(true)
EQ("rallume : sacs ouverts", win("bag").frame:IsShown(), true)
EQ("rallume : pas de reconstruction", CREATED, c2)
getglobal("CloseAllBags")()

SECTION("t_bags : pfUI fait tourner son equivalent -> ShikiUI attend")
C.Set("modules.bags", false)
pfUI = { module = { bags = function() end } }
pfUI_config = { disabled = {}, unitframes = { disable = "0" } }
SUI.Migrate.Boot()
EQ("Held", SUI.Migrate.Held("bags"), true)
EQ("etat wait", SUI.Migrate.State("bags"), "wait")
C.Set("modules.bags", true)
EQ("reste coupe tant que pfUI tourne", mod.enabled, false)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("migrate")
CONTAINS("rapport migrate", CHATTEXT(), "bags")
SlashCmdList["SHIKIUI"]("migrate take bags")
EQ("take : equivalent pfUI coupe", pfUI_config.disabled.bags, "1")
EQ("take : module ShikiUI coche", C.Get("modules.bags"), true)
pfUI = nil
pfUI_config = nil
SUI.Migrate.Boot()


SECTION("t_bags : reglages a chaud, icones, emplacements de sacs du jeu")
do
  local BM = SUI.Bags
  C.Set("modules.bags", false)
  C.Set("modules.bags", true)
  SETTLE()
  EQ("module actif", BM.on, true)
  fillStart()
  getglobal("OpenAllBags")(true)
  pump(4)
  local w = win("bag")
  EQ("fenetre au-dessus des barres d'action", w.frame.calls.SetFrameStrata[1], "HIGH")
  -- recherche / filtres coupes : leur effet disparait aussi (sinon des objets restent attenues sans moyen d'y remedier)
  w.edit:SetText("epee")
  callScript(w.edit, "OnTextChanged")
  pump(2)
  T("recherche active : des objets attenues", dimmed("bag") > 0)
  C.Set("bags.search", false)
  pump(3)
  EQ("recherche coupee : requete effacee", w.query, "")
  EQ("recherche coupee : plus d'objet attenue", dimmed("bag"), 0)
  C.Set("bags.search", true)
  BM.CycleFilter(w)
  pump(2)
  T("filtre actif : des objets attenues", dimmed("bag") > 0)
  C.Set("bags.filters", false)
  pump(3)
  EQ("filtres coupes : retour a Tout", w.filter, "all")
  EQ("filtres coupes : plus d'objet attenue", dimmed("bag"), 0)
  C.Set("bags.filters", true)
  pump(2)

  -- l'icone du modele de Blizzard est rentree d'un pixel pour laisser voir la bordure de qualite
  local ic = CreateFrame("Frame", "ShikiUI_Item_0_20IconTexture", UIParent)
  BGBAG(0, 20)
  BM.Layout(w)
  local last = ic.points[table.getn(ic.points)]
  T("icone rentree (bordure visible)", last ~= nil and last[1] == "BOTTOMRIGHT" and last[4] == -1 and table.getn(ic.points) == 2)
  EQ("icone rognee", ic.calls.SetTexCoord[1], 0.07)
  BGBAG(0, 16)
  BM.Layout(w)

  -- emplacements de sacs de Blizzard : recuperes quand leur barre d'origine est masquee, rendus a la desactivation
  getglobal("CloseAllBags")()
  BM.DetachBagSlots(w)
  local art = CreateFrame("Frame", "MainMenuBarArtFrame", UIParent)
  art:Hide()
  for i = 0, 3 do
    local sl = CreateFrame("Button", "CharacterBag" .. i .. "Slot", art)
    sl:SetPoint("TOPLEFT", art, "TOPLEFT", 10 * i, 0)
  end
  getglobal("OpenAllBags")(true)
  pump(2)
  local s0 = getglobal("CharacterBag0Slot")
  EQ("4 emplacements de sacs ranges", table.getn(w.slots), 4)
  T("emplacement de sac dans la fenetre des sacs", s0.calls.SetParent[1] == w.frame)
  EQ("emplacement de sac reduit", s0:GetScale(), 0.75)
  T("rangee de sacs : fenetre plus haute", w.frame:GetHeight() > 100)
  BM.Disable()
  T("emplacement de sac rendu a sa barre", s0.calls.SetParent[1] == art)
  EQ("emplacement de sac : echelle rendue", s0:GetScale(), 1)
  C.Set("modules.bags", false)
  C.Set("modules.bags", true)
  SETTLE()
  -- barre d'origine visible : on n'y touche pas
  BM.DetachBagSlots(w)
  art:Show()
  getglobal("OpenAllBags")(true)
  pump(2)
  EQ("barre d'origine visible : aucun emplacement pris", table.getn(w.slots), 0)
  T("emplacement reste sur sa barre", s0.calls.SetParent[1] == art)
  getglobal("CloseAllBags")()
end

SECTION("t_bags : banque Blizzard (GetInventorySlotInfo) et deplacement")
do
  local BMM = SUI.Bags
  -- reproduit BankFrame.lua de Blizzard : l'emplacement est deduit du NOM du bouton (strsub(nom, 10) = "Bag1".."Bag6")
  local valid = { Bag1 = 1, Bag2 = 2, Bag3 = 3, Bag4 = 4, Bag5 = 5, Bag6 = 6 }
  local function GetInvSlot(n)
    if not valid[n] then error("Invalid inventory slot in GetInventorySlotInfo") end
    return valid[n]
  end
  local calls = 0
  local function blizzUpdate(button)
    calls = calls + 1
    GetInvSlot(string.sub(button:GetName(), 10))
  end
  BMM.UnwrapBankUpdate()
  setglobal("BankFrameItemButton_Update", blizzUpdate)
  BMM.WrapBankUpdate()
  T("mise a jour de Blizzard enveloppee", getglobal("BankFrameItemButton_Update") ~= blizzUpdate)
  for i = 1, 6 do
    local b = getglobal("ShikiBankBag" .. i)
    T("noms de sacs de banque conformes " .. i, b ~= nil and valid[string.sub(b:GetName(), 10)] == i)
    local ok = pcall(blizzUpdate, b)
    T("appel Blizzard direct sans erreur " .. i, ok)
    getglobal("BankFrameItemButton_Update")(b)
  end
  EQ("aucune erreur avalee", BMM.bankErr, nil)
  -- bouton de Blizzard : erreur non masquee ; bouton a nom invalide du module : avalee
  local bad = CreateFrame("Button", "ShikiBankXbad", UIParent)
  getglobal("BankFrameItemButton_Update")(bad)
  EQ("erreur sur un bouton du module avalee", BMM.bankErr, 1)
  local bz = CreateFrame("Button", "BankFrameBagXX", UIParent)
  T("erreur de Blizzard non masquee", not pcall(getglobal("BankFrameItemButton_Update"), bz))
  -- l'ancien nom (bug) reproduit l'erreur de l'utilisateur
  EQ("ancien nom invalide", pcall(blizzUpdate, CreateFrame("Button", "SUIBankBagBag1", UIParent)), false)
  BMM.UnwrapBankUpdate()
  EQ("banque Blizzard rendue", getglobal("BankFrameItemButton_Update"), blizzUpdate)
  BMM.WrapBankUpdate()
  C.Set("modules.bags", false)
  EQ("module coupe : fonction de Blizzard rendue", getglobal("BankFrameItemButton_Update"), blizzUpdate)
  C.Set("modules.bags", true)
  SETTLE()
  T("rallume : enveloppee de nouveau", getglobal("BankFrameItemButton_Update") ~= blizzUpdate)
  C.Set("modules.bags", false)
  C.Set("modules.bags", true)
  SETTLE()
  setglobal("BankFrameItemButton_Update", nil)
end

do
  local BMM = SUI.Bags
  local oldCombat, oldLock = W.combat, C.Get("ui.locked")
  Fire("BANKFRAME_OPENED")
  pump(2)
  getglobal("OpenAllBags")(true)
  for _, k in ipairs({ "bag", "bank" }) do
    local w = win(k)
    local f = w.frame
    local key = w.def.layout
    T(k .. " : barre de titre", w.bar ~= nil and w.bar.win == w)
    EQ(k .. " : cle Layout", SUI.Layout.items[key].frame, f)
    T(k .. " : enregistre au Mover", SUI.Mover.items[key] ~= nil)
    EQ(k .. " : glisser en bas de la barre", w.bar.scripts.OnDragStart ~= nil and w.bar.scripts.OnDragStop ~= nil, true)
    T(k .. " : mouvable", f.movable == true)
    -- verrouille : pas de deplacement, un message
    C.Set("ui.locked", true)
    BMM.warnedLock = false
    CHATCLEAR()
    callScript(w.bar, "OnDragStart")
    EQ(k .. " : verrouille", f.moving, nil)
    CONTAINS(k .. " : message de verrou", CHATTEXT(), L("msg.bags.locked"))
    -- combat : pas de deplacement
    C.Set("ui.locked", false)
    W.combat = true
    callScript(w.bar, "OnDragStart")
    T(k .. " : pas de glissement en combat", not f.moving)
    W.combat = false
    -- libre
    callScript(w.bar, "OnDragStart")
    EQ(k .. " : glissement", f.moving, true)
    f.left, f.bottom = 210, 130
    callScript(w.bar, "OnDragStop")
    EQ(k .. " : fin du glissement", f.moving, false)
    local l, b = C.GetPos(SUI.Layout.WriteKey(key))
    EQ(k .. " : position memorisee X", l, 210)
    EQ(k .. " : position memorisee Y", b, 130)
    -- la position survit a Layout.ApplyAll (profil)
    SUI.Layout.ApplyAll()
    local l2 = C.GetPos(SUI.Layout.ReadKey(key))
    EQ(k .. " : position conservee", l2, 210)
    -- masquage en cours de glissement
    callScript(w.bar, "OnDragStart")
    f.left, f.bottom = 55, 66
    callScript(f, "OnHide")
    EQ(k .. " : masquage : fin du glissement", f.moving, false)
    EQ(k .. " : masquage : position memorisee", (C.GetPos(SUI.Layout.WriteKey(key))), 55)
    f:Show()
  end
  -- remise a zero
  SlashCmdList["SHIKIUI"]("bags reset")
  EQ("reset : sacs", C.GetPos("bags.window"), nil)
  EQ("reset : banque", C.GetPos("bags.bank"), nil)
  -- reset en combat : differe
  C.SetPos("bags.window", 5, 6)
  W.combat = true
  SlashCmdList["SHIKIUI"]("bags reset")
  EQ("reset en combat : differe", (C.GetPos("bags.window")), 5)
  W.combat = false
  Fire("PLAYER_REGEN_ENABLED")
  pump(2)
  EQ("reset apres combat", C.GetPos("bags.window"), nil)
  -- sans Mover
  local sm = SUI.Mover
  SUI.Mover = nil
  local w = win("bag")
  callScript(w.bar, "OnDragStart")
  w.frame.left, w.frame.bottom = 31, 32
  callScript(w.bar, "OnDragStop")
  SUI.Mover = sm
  EQ("sans Mover : memorisee", (C.GetPos(SUI.Layout.WriteKey("bags.window"))), 31)
  SlashCmdList["SHIKIUI"]("bags reset")
  for _, lang in ipairs({ "fr", "en" }) do
    T(lang .. " msg verrou", has(lang, "msg.bags.locked"))
    T(lang .. " msg reset", has(lang, "msg.bags.reset"))
  end
  W.combat = oldCombat
  C.Set("ui.locked", oldLock)
  getglobal("CloseAllBags")()
  Fire("BANKFRAME_CLOSED")
end

SECTION("t_bags : classement par categories")
do
  local BM = SUI.Bags
  EQ("quete FR", BM.Classify("quete", "divers", 1, ""), "quest")
  EQ("quete FR accentuee (octets UTF-8)", BM.Classify("qu\195\170te", "", 1, ""), "quest")
  EQ("quete EN", BM.Classify("quest", "", 1, ""), "quest")
  EQ("quete grise : reste une quete", BM.Classify("quest", "", 0, ""), "quest")
  EQ("camelote (qualite 0)", BM.Classify("armor", "plate", 0, "INVTYPE_CHEST"), "junk")
  EQ("consommable FR", BM.Classify("consommable", "potion", 1, ""), "consum")
  EQ("consommable EN", BM.Classify("consumable", "potion", 1, ""), "consum")
  EQ("marchandise FR", BM.Classify("marchandise", "tissu", 1, ""), "trade")
  EQ("trade goods EN", BM.Classify("trade goods", "cloth", 1, ""), "trade")
  EQ("reactif FR (octets UTF-8)", BM.Classify("r\195\169actif", "", 1, ""), "trade")
  EQ("recette", BM.Classify("recette", "", 1, ""), "trade")
  EQ("armure", BM.Classify("armure", "tissu", 1, "INVTYPE_HEAD"), "equip")
  EQ("arme sans emplacement", BM.Classify("weapon", "", 1, ""), "equip")
  EQ("sac : pas de l'equipement", BM.Classify("conteneur", "", 1, "INVTYPE_BAG"), "other")
  EQ("munitions : pas de l'equipement", BM.Classify("projectile", "", 1, "INVTYPE_AMMO"), "other")
  EQ("divers", BM.Classify("divers", "divers", 1, ""), "other")
  EQ("type inconnu", BM.Classify(nil, nil, nil, nil), "other")
  EQ("7 sections", table.getn(BM.CATS), 7)
  for _, lang in ipairs({ "fr", "en" }) do
    for _, c in ipairs(BM.CATS) do T(lang .. " section " .. c, has(lang, "msg.bags.cat." .. c)) end
    for _, c in ipairs({ "grid", "categories" }) do T(lang .. " choix affichage " .. c, has(lang, "choice.bags.layout." .. c)) end
  end
end

SECTION("t_bags : affichage par categories")
do
  local BM = SUI.Bags
  C.Set("bags.columns", 10)
  C.Set("bags.size", 32)
  C.Set("bags.spacing", 2)
  getglobal("CloseAllBags")()
  BGINFO(108, { name = "Lettre", q = 1, type = "Quete", sub = "Divers", price = 0 })
  BGINFO(109, { name = "Toile", q = 1, type = "Marchandise", sub = "Tissu", price = 4 })
  W.bg.slot = {}
  BGLAYOUT({ [0] = 16, [1] = 6, [2] = 0, [3] = 0, [4] = 0 })
  BGPUT(0, 1, 100, 1); BGPUT(0, 2, 103, 1); BGPUT(0, 4, 102, 5); BGPUT(0, 5, 104, 1); BGPUT(0, 7, 106, 1); BGPUT(0, 9, 101, 1)
  BGPUT(1, 1, 107, 1); BGPUT(1, 3, 105, 3); BGPUT(1, 4, 103, 2); BGPUT(1, 5, 108, 1); BGPUT(1, 6, 109, 4)
  C.Set("bags.layout", "categories")
  getglobal("OpenAllBags")(true)
  pump(4)
  local w = win("bag")
  local n = 0
  for _ in pairs(w.heads) do n = n + 1 end
  EQ("sept en-tetes crees", n, 7)
  local function head(c) return w.heads[c] end
  EQ("equipement : titre", head("equip").label:GetText(), "- " .. L("msg.bags.cat.equip") .. " (3)")
  EQ("consommables : titre", head("consum").label:GetText(), "- " .. L("msg.bags.cat.consum") .. " (2)")
  EQ("quete : titre", head("quest").label:GetText(), "- " .. L("msg.bags.cat.quest") .. " (1)")
  EQ("echange : titre", head("trade").label:GetText(), "- " .. L("msg.bags.cat.trade") .. " (1)")
  EQ("camelote : titre", head("junk").label:GetText(), "- " .. L("msg.bags.cat.junk") .. " (3)")
  EQ("autres : titre", head("other").label:GetText(), "- " .. L("msg.bags.cat.other") .. " (1)")
  EQ("libres : titre", head("free").label:GetText(), "- " .. L("msg.bags.cat.free") .. " (11)")
  EQ("22 emplacements toujours suivis", w.n, 22)
  EQ("premier en-tete sous la barre de titre (y)", head("equip").points[1][5], -54)
  EQ("premier en-tete : x", head("equip").points[1][4], 6)
  EQ("en-tete : largeur = fenetre moins marges", head("equip"):GetWidth(), w.frame:GetWidth() - 12)
  EQ("l'epique d'abord dans l'equipement", w.order[1], sb("bag", 0, 5))
  EQ("puis le rare", w.order[2], sb("bag", 0, 1))
  EQ("puis l'inhabituel", w.order[3], sb("bag", 1, 1))
  EQ("premier objet : sous l'en-tete (y)", w.order[1].points[1][5], -72)
  EQ("premier objet : x", w.order[1].points[1][4], 6)
  EQ("deuxieme objet : x", w.order[2].points[1][4], 6 + 34)
  EQ("section suivante : en-tete plus bas", head("consum").points[1][5], -108)
  EQ("section suivante : premier objet", w.order[4].points[1][5], -126)
  EQ("potion (3) avant pain (nom)", w.order[4], sb("bag", 0, 4))
  T("une seule marque par bouton", table.getn(w.order[4].points) == 1)
  local extra = BM.HasBagSlots(w) and 28 or 0
  EQ("hauteur = 6 sections d'une rangee + 2 rangees libres", w.frame:GetHeight(), 54 + 408 + 6 + extra + 24)
  -- section reduite
  Click(head("equip"))
  pump(3)
  EQ("reduit : titre", head("equip").label:GetText(), "+ " .. L("msg.bags.cat.equip") .. " (3)")
  EQ("reduit : objets masques", sb("bag", 0, 5):IsShown(), false)
  EQ("reduit : les autres restent", sb("bag", 0, 4):IsShown(), true)
  EQ("reduit : section suivante remontee (en-tete + marge)", head("consum").points[1][5], -76)
  EQ("reduit : fenetre plus basse", w.frame:GetHeight(), 54 + 408 - 32 + 6 + extra + 24)
  EQ("reduit : memorise", C.GetGlobal("bagcache").prefs.collapsed.equip, true)
  EQ("reduit : encore 22 emplacements suivis", w.n, 22)
  Click(head("equip"))
  pump(3)
  EQ("deplie : titre", head("equip").label:GetText(), "- " .. L("msg.bags.cat.equip") .. " (3)")
  EQ("deplie : objets revenus", sb("bag", 0, 5):IsShown(), true)
  EQ("deplie : memorise", C.GetGlobal("bagcache").prefs.collapsed.equip, nil)
  -- un nouvel objet arrive
  BGPUT(0, 3, 105, 1)
  Fire("BAG_UPDATE", 0)
  pump(3)
  EQ("nouvel objet : consommables a 3", head("consum").label:GetText(), "- " .. L("msg.bags.cat.consum") .. " (3)")
  EQ("nouvel objet : libres a 10", head("free").label:GetText(), "- " .. L("msg.bags.cat.free") .. " (10)")
  -- objet pas encore connu du client : classe "autres" puis reclasse quand le client le connait
  BGINFO(130, { name = "Mystere", q = 1, type = "Consommable", sub = "Potion", price = 1, uncached = true })
  BGPUT(0, 10, 130, 1)
  Fire("BAG_UPDATE", 0)
  pump(3)
  EQ("inconnu : range dans les autres", head("other").label:GetText(), "- " .. L("msg.bags.cat.other") .. " (2)")
  W.bg.info[130].uncached = nil
  pump(30)
  EQ("connu : reclasse en consommable", head("consum").label:GetText(), "- " .. L("msg.bags.cat.consum") .. " (4)")
  EQ("connu : autres revenus a 1", head("other").label:GetText(), "- " .. L("msg.bags.cat.other") .. " (1)")
  -- combat : on replace sans creer de frame
  local c1 = CREATED
  W.combat = true
  Fire("PLAYER_REGEN_DISABLED")
  BGPUT(0, 11, 101, 1)
  Fire("BAG_UPDATE", 0)
  pump(3)
  EQ("combat : aucune frame creee", CREATED, c1)
  EQ("combat : autres a 2", head("other").label:GetText(), "- " .. L("msg.bags.cat.other") .. " (2)")
  W.combat = false
  Fire("PLAYER_REGEN_ENABLED")
  pump(2)
  -- recherche : toujours attenuee sur la bonne cible
  w.edit:SetText("epee")
  callScript(w.edit, "OnTextChanged")
  pump(2)
  EQ("recherche en sections : un seul objet net", w.n - dimmed("bag"), 1)
  EQ("recherche : c'est l'epee", alphaOf(sb("bag", 0, 1)), 1)
  w.edit:SetText("")
  callScript(w.edit, "OnTextChanged")
  pump(2)
  -- retour a la grille
  C.Set("bags.layout", "grid")
  pump(3)
  for _, c in ipairs(BM.CATS) do EQ("grille : en-tete " .. c .. " cache", head(c):IsShown(), false) end
  EQ("grille : ordre des sacs", w.order[1], sb("bag", 0, 1))
  EQ("grille : bouton 11 y", w.order[11].points[1][5], -88)
  EQ("grille : hauteur", w.frame:GetHeight(), 54 + 3 * 34 - 2 + 6 + extra + 24)
  EQ("grille : tous les objets visibles", sb("bag", 0, 5):IsShown(), true)
  C.Set("bags.layout", "categories")
  pump(3)
  EQ("de nouveau par categories", head("junk"):IsShown(), true)
  getglobal("CloseAllBags")()
  C.Set("bags.layout", "grid")
  BGPUT(0, 3, nil); BGPUT(0, 10, nil); BGPUT(0, 11, nil)
end

SECTION("t_bags : memoire par personnage")
do
  local BM = SUI.Bags
  local me = BM.CharKey()
  EQ("cle Nom-Royaume", me, "Shikiwa-" .. tostring(W.realm))
  EQ("reglage par defaut", C.Get("bags.remember"), true)
  C.SetGlobal("bagcache", nil)
  BM.mem = nil
  fillStart()
  BGLAYOUT({ [0] = 16, [1] = 6, [2] = 0, [3] = 0, [4] = 0 })
  W.bg.money = 777
  getglobal("OpenAllBags")(true)
  pump(2)
  getglobal("CloseAllBags")()
  local root = C.GetGlobal("bagcache")
  T("cache cree a la fermeture des sacs", type(root) == "table" and type(root.chars) == "table")
  local rec = root.chars[me]
  T("instantane du personnage", type(rec) == "table")
  EQ("nom", rec.name, "Shikiwa")
  EQ("classe", rec.class, "PALADIN")
  EQ("argent", rec.money, 777)
  EQ("emplacements", rec.nbag, 22)
  EQ("objets memorises", table.getn(rec.bags), 9)
  EQ("revision incrementee", root.rev >= 1, true)
  EQ("entree de l'epee", rec.bags[1], "100:0:0:0~1~3~equip~Item100~arme~epees~Epee Rare")
  local e = BM.Parse(rec.bags[1])
  EQ("lecture : id", e.id, 100)
  EQ("lecture : quantite", e.count, 1)
  EQ("lecture : qualite", e.q, 3)
  EQ("lecture : categorie", e.cat, "equip")
  EQ("lecture : icone complete", e.tex, "Interface\\Icons\\Item100")
  EQ("lecture : nom", e.name, "Epee Rare")
  EQ("lecture : nom minuscule", e.lname, "epee rare")
  EQ("lecture : lien", e.ref, "100:0:0:0")
  EQ("lecture d'une entree invalide", BM.Parse("n'importe quoi"), nil)
  EQ("lecture d'un non-texte", BM.Parse(42), nil)
  -- plafond
  BGBAG(0, 250)
  for i = 1, 250 do BGPUT(0, i, 101, 1) end
  local out, total = BM.ScanSet("bags")
  EQ("plafond de 200 entrees", table.getn(out), 200)
  EQ("total des emplacements non plafonne", total, 256)
  fillStart()
  BGLAYOUT({ [0] = 16, [1] = 6, [2] = 0, [3] = 0, [4] = 0 })
  -- les personnages sont plafonnes a 12, le plus ancien part, le courant reste
  for i = 1, 14 do root.chars["Fake" .. i .. "-R"] = { t = 100 + i, name = "Fake" .. i, bags = {}, bank = {} } end
  root.chars["Mauvais-R"] = "pas une table"
  BM.Snapshot("bags")
  local nch = 0
  for k in pairs(root.chars) do nch = nch + 1 end
  EQ("12 personnages au plus", nch, 12)
  T("le courant reste", root.chars[me] ~= nil)
  EQ("le plus ancien est parti", root.chars["Fake1-R"], nil)
  T("le plus recent reste", root.chars["Fake14-R"] ~= nil)
  EQ("entree invalide supprimee", root.chars["Mauvais-R"], nil)
  -- jamais d'ecrasement par du vide
  rec = root.chars[me]
  local before = rec.bags
  BGLAYOUT({ [0] = 0, [1] = 0 })
  BM.Snapshot("bags")
  EQ("aucun emplacement lisible : instantane conserve", rec.bags, before)
  BGLAYOUT({ [0] = 16, [1] = 6 })
  -- banque : lue seulement banque ouverte
  EQ("banque fermee : pas d'instantane", BM.Snapshot("bank"), false)
  W.bg.slot[-1] = {}
  BGLAYOUT({ [-1] = 24, [5] = 6, [6] = 6 })
  W.bg.banksl = 2
  BGPUT(-1, 1, 104, 1)
  BGPUT(5, 2, 105, 4)
  Fire("BANKFRAME_OPENED")
  pump(8)
  EQ("banque ouverte : memorisee", table.getn(rec.bank), 2)
  EQ("banque : emplacements", rec.nbank, 36)
  EQ("banque : entree du casque", rec.bank[1], "104:0:0:0~1~4~equip~Item104~armure~tissu~Casque Epique")
  local rev = root.rev
  BGPUT(-1, 2, 100, 1)
  Fire("PLAYERBANKSLOTS_CHANGED")
  pump(8)
  EQ("banque modifiee : mise a jour", table.getn(rec.bank), 3)
  T("banque modifiee : revision", root.rev > rev)
  Fire("BANKFRAME_CLOSED")
  BGPUT(-1, 3, 101, 1)
  Fire("PLAYERBANKSLOTS_CHANGED")
  pump(8)
  EQ("banque fermee : instantane inchange", table.getn(rec.bank), 3)
  getglobal("CloseAllBags")()
  -- combat : differe a la fin du combat
  rev = root.rev
  W.combat = true
  Fire("PLAYER_REGEN_DISABLED")
  EQ("en combat : refuse", BM.Snapshot("bags"), false)
  EQ("en combat : revision inchangee", root.rev, rev)
  W.combat = false
  Fire("PLAYER_REGEN_ENABLED")
  T("fin de combat : instantane fait", root.rev > rev)
  -- deconnexion
  rev = root.rev
  W.combat = true
  mod.shutdown(mod)
  T("deconnexion : instantane meme en combat", root.rev > rev)
  W.combat = false
  Fire("PLAYER_REGEN_ENABLED")
  -- reglage coupe
  C.Set("bags.remember", false)
  rev = root.rev
  EQ("memoire coupee : rien n'est ecrit", BM.Snapshot("bags"), false)
  EQ("memoire coupee : revision inchangee", root.rev, rev)
  C.Set("bags.remember", true)
  -- module coupe : rien n'est ecrit
  BM.on = false
  EQ("module coupe : rien n'est ecrit", BM.Snapshot("bags"), false)
  BM.on = true
end

SECTION("t_bags : vue hors-ligne")
do
  local BM = SUI.Bags
  local me = BM.CharKey()
  local root = C.GetGlobal("bagcache")
  for k in pairs(root.chars) do
    if k ~= me then root.chars[k] = nil end
  end
  time = function() return 5000000 end
  local tf = getglobal("time")
  local now = tf()
  root.chars["Bob-R"] = { name = "Bob", class = "MAGE", t = now - 7200, money = 4567890, nbag = 20, nbank = 24,
    bags = { "103:0:0:0~2~0~junk~Item103~divers~camelote~Chiffon Gris", "102:0:0:0~5~1~consum~Item102~consommable~nourriture~Pain",
      "100:0:0:0~1~3~equip~Item100~arme~epees~Epee Rare", "120:0:0:0~1~2~other~Item120~divers~divers~Inconnu" },
    bank = { "104:0:0:0~1~4~equip~Item104~armure~tissu~Casque Epique" } }
  root.chars["Neuf-R"] = { name = "Neuf", t = now, money = 5, bags = {}, bank = {} }
  BGINFO(120, { name = "Inconnu", q = 2, uncached = true })
  CreateFrame("GameTooltip", "GameTooltip", UIParent)
  getglobal("OpenAllBags")(true)
  pump(3)
  local w = win("bag")
  T("selecteur present", w.vbtn ~= nil and w.vbtn:IsShown())
  EQ("selecteur : personnage actuel", w.vbtn.label:GetText(), L("msg.bags.view.btn", "Shikiwa"))
  EQ("pas encore hors-ligne", w.offline, nil)
  Click(w.vbtn)
  EQ("liste ouverte", w.pick:IsShown(), true)
  EQ("liste : 3 lignes (actuel, Bob, Neuf)", w.prow[3]:IsShown() and not (w.prow[4] and w.prow[4]:IsShown()), true)
  EQ("liste : le personnage actuel d'abord", w.prow[1].label:GetText(), L("msg.bags.view.me", "Shikiwa"))
  EQ("liste : ordre alphabetique", w.prow[2].label:GetText(), "Bob")
  EQ("liste : cle", w.prow[2].key, "Bob-R")
  Click(w.vbtn)
  EQ("liste refermee", w.pick:IsShown(), false)
  Click(w.vbtn)
  Click(w.prow[2])
  EQ("vue hors-ligne", w.offline, true)
  EQ("liste refermee apres le choix", w.pick:IsShown(), false)
  EQ("titre", w.title:GetText(), L("msg.bags.view.title", "Bob"))
  EQ("selecteur : nom du personnage vu", w.vbtn.label:GetText(), L("msg.bags.view.btn", "Bob"))
  EQ("panneau visible", w.vpanel:IsShown(), true)
  EQ("sacs reels masques", w.holder[0]:IsShown(), false)
  EQ("tri masque (lecture seule)", w.sbtn:IsShown(), false)
  pump(3)
  EQ("5 icones (4 sacs + 1 banque)", w.vn, 5)
  EQ("icone", w.vb[1].icon.calls.SetTexture[1], "Interface\\Icons\\Item103")
  EQ("quantite d'une pile", w.vb[2].cnt:GetText(), 5)
  EQ("quantite 1 : pas de chiffre", w.vb[3].cnt:GetText(), "")
  EQ("bordure de qualite (rare)", w.vb[3].bbc[1], 0.1 * 3)
  EQ("position : x", w.vb[2].points[1][4], 6 + 34)
  EQ("fenetre : largeur de la grille", w.frame:GetWidth(), 350)
  T("valeur : argent", string.find(w.value:GetText(), money(4567890), 1, true) ~= nil)
  T("valeur : nombre d'objets", string.find(w.value:GetText(), L("msg.bags.view.counts", 4, 1), 1, true) ~= nil)
  T("valeur : anciennete", string.find(w.value:GetText(), L("msg.bags.view.age.h", 2), 1, true) ~= nil)
  -- infobulle : lien pour un objet connu, texte de repli pour un inconnu
  GameTooltip.calls.SetHyperlink = nil
  callScript(w.vb[3], "OnEnter")
  EQ("infobulle : lien de l'objet", GameTooltip.calls.SetHyperlink[1], "item:100:0:0:0")
  callScript(w.vb[3], "OnLeave")
  GameTooltip.calls.SetHyperlink = nil
  callScript(w.vb[4], "OnEnter")
  EQ("objet inconnu : jamais de lien (risque de deconnexion)", GameTooltip.calls.SetHyperlink, nil)
  EQ("objet inconnu : nom en repli", GameTooltip.lines[1], "Inconnu")
  callScript(w.vb[4], "OnLeave")
  -- les evenements des sacs reels ne touchent pas la vue
  Fire("BAG_UPDATE", 0)
  pump(3)
  EQ("sacs reels toujours masques", w.holder[0]:IsShown(), false)
  EQ("toujours 5 icones", w.vn, 5)
  -- recherche et filtre hors-ligne
  w.edit:SetText("pain")
  callScript(w.edit, "OnTextChanged")
  pump(2)
  local fn = 0
  for i = 1, w.vn do
    if alphaOf(w.vb[i]) < 1 then fn = fn + 1 end
  end
  EQ("recherche hors-ligne : 4 attenues", fn, 4)
  EQ("recherche hors-ligne : le pain reste net", alphaOf(w.vb[2]), 1)
  w.edit:SetText("armure")
  callScript(w.edit, "OnTextChanged")
  pump(2)
  EQ("recherche par type hors-ligne : le casque (banque)", alphaOf(w.vb[5]), 1)
  w.edit:SetText("")
  callScript(w.edit, "OnTextChanged")
  BM.CycleFilter(w)
  pump(2)
  EQ("filtre equipement : epee nette", alphaOf(w.vb[3]), 1)
  EQ("filtre equipement : pain attenue", alphaOf(w.vb[2]), 0.25)
  BM.CycleFilter(w)
  pump(2)
  EQ("filtre camelote : chiffon net", alphaOf(w.vb[1]), 1)
  EQ("filtre camelote : epee attenuee", alphaOf(w.vb[3]), 0.25)
  BM.CycleFilter(w)
  BM.CycleFilter(w)
  EQ("filtre revenu a Tout", w.filter, "all")
  pump(2)
  EQ("plus rien d'attenue", alphaOf(w.vb[2]), 1)
  -- categories : meme vue, classee
  C.Set("bags.layout", "categories")
  pump(3)
  EQ("categories : equipement d'abord", w.vb[1].e.name, "Epee Rare")
  EQ("categories : consommable ensuite", w.vb[2].e.name, "Pain")
  EQ("categories : camelote apres", w.vb[3].e.name, "Chiffon Gris")
  EQ("categories : la banque reste une section a part", w.vb[5].e.name, "Casque Epique")
  C.Set("bags.layout", "grid")
  pump(3)
  EQ("grille : ordre memorise", w.vb[1].e.name, "Chiffon Gris")
  -- retour aux sacs reels
  Click(w.vbtn)
  Click(w.prow[1])
  EQ("retour : en ligne", w.offline, false)
  EQ("retour : sacs reels visibles", w.holder[0]:IsShown(), true)
  EQ("retour : panneau masque", w.vpanel:IsShown(), false)
  EQ("retour : tri revenu", w.sbtn:IsShown(), true)
  EQ("retour : titre", w.title:GetText(), L("msg.bags.title.bag"))
  pump(3)
  EQ("retour : 22 emplacements", w.n, 22)
  EQ("retour : largeur", w.frame:GetWidth(), 350)
  T("retour : valeur reelle", string.find(w.value:GetText(), money(W.bg.money), 1, true) ~= nil)
  -- fermer la fenetre ramene toujours aux sacs reels
  Click(w.vbtn)
  Click(w.prow[2])
  EQ("de nouveau hors-ligne", w.offline, true)
  w.frame:Hide()
  EQ("fermeture : retour en ligne", w.offline, false)
  EQ("fermeture : sacs reels de nouveau montres", w.holder[0]:IsShown(), true)
  getglobal("OpenAllBags")(true)
  pump(2)
  -- erreurs : inconnu, combat
  CHATCLEAR()
  EQ("personnage inconnu : refuse", BM.SetView(w, "Nobody-R"), false)
  CONTAINS("personnage inconnu : message", CHATTEXT(), L("msg.bags.view.none"))
  W.combat = true
  CHATCLEAR()
  EQ("en combat : refuse", BM.SetView(w, "Bob-R"), false)
  CONTAINS("en combat : message", CHATTEXT(), L("msg.bags.view.combat"))
  Click(w.vbtn)
  EQ("en combat : liste non ouverte", w.pick:IsShown(), false)
  W.combat = false
  EQ("personnage actuel : retour sans effet", BM.SetView(w, me), true)
  -- personnage vide
  BM.SetView(w, "Neuf-R")
  pump(3)
  EQ("personnage vide : aucune icone", w.vn, 0)
  EQ("personnage vide : banque jamais ouverte", w.vh[2]:GetText(), L("msg.bags.view.nobank"))
  BM.SetView(w, nil)
  -- memoire coupee : bouton et vue disparaissent
  BM.SetView(w, "Bob-R")
  C.Set("bags.remember", false)
  pump(2)
  EQ("memoire coupee : retour en ligne", w.offline, false)
  EQ("memoire coupee : selecteur masque", w.vbtn:IsShown(), false)
  C.Set("bags.remember", true)
  pump(2)
  EQ("memoire rallumee : selecteur revenu", w.vbtn:IsShown(), true)
  -- changement de style en vue
  BM.SetView(w, "Bob-R")
  pump(2)
  TH.Restyle()
  pump(3)
  EQ("style : vue toujours la", w.vn, 5)
  BM.SetView(w, nil)
  getglobal("CloseAllBags")()
  time = nil
  EQ("aucune erreur interne", SUI.errCount, 0)
end

SECTION("t_bags : tout deposer en banque")
do
  local BM = SUI.Bags
  getglobal("CloseAllBags")()
  CreateFrame("Frame", "BankFrame", UIParent)
  local hearth = 6948
  BGINFO(hearth, { name = "Pierre de foyer", q = 1, type = "Divers", sub = "Divers", price = 0 })
  W.bg.slot = {}
  BGLAYOUT({ [0] = 16, [1] = 6, [-1] = 24 })
  BGPUT(0, 1, 100, 1); BGPUT(0, 2, 103, 1); BGPUT(0, 3, hearth, 1); BGPUT(0, 5, 104, 1); BGPUT(1, 2, 106, 1)
  W.bg.slot[-1] = {}
  W.bg.banksl = 0
  C.Set("bags.depositall", false)
  Fire("BANKFRAME_OPENED")
  pump(4)
  local bk = win("bank")
  EQ("bouton cache par defaut", bk.dbtn:IsShown(), false)
  C.Set("bags.depositall", true)
  pump(2)
  EQ("option cochee : bouton montre", bk.dbtn:IsShown(), true)
  EQ("libelle", bk.dbtn.label:GetText(), L("msg.bags.btn.deposit"))
  local used = {}
  local oldUse = UseContainerItem
  UseContainerItem = function(bag, slot)
    ACT("UseContainerItem " .. bag .. " " .. slot)
    used[table.getn(used) + 1] = bag .. ":" .. slot
    W.bg.slot[bag][slot] = nil
  end
  -- en combat : refuse
  W.combat = true
  CHATCLEAR()
  Click(bk.dbtn)
  CONTAINS("combat : message", CHATTEXT(), L("msg.bags.deposit.combat"))
  EQ("combat : rien envoye", table.getn(used), 0)
  W.combat = false
  -- curseur occupe : refuse
  W.cursorItem = true
  CHATCLEAR()
  Click(bk.dbtn)
  CONTAINS("curseur : message", CHATTEXT(), L("msg.bags.deposit.cursor"))
  W.cursorItem = nil
  -- depot complet : tout sauf la pierre de foyer
  CHATCLEAR()
  Click(bk.dbtn)
  CONTAINS("depart annonce", CHATTEXT(), L("msg.bags.deposit.start", 4))
  EQ("deux fois de suite : ignore", BM.StartDeposit(), false)
  pump(30)
  EQ("4 emplacements envoyes", table.getn(used), 4)
  EQ("ordre des sacs", used[1], "0:1")
  T("pierre de foyer gardee", W.bg.slot[0][3] ~= nil)
  T("rien d'autre dans les sacs", W.bg.slot[0][1] == nil and W.bg.slot[0][2] == nil and W.bg.slot[0][5] == nil and W.bg.slot[1][2] == nil)
  CONTAINS("fin annoncee", CHATTEXT(), L("msg.bags.deposit.done", 4))
  EQ("travail termine", BM.dep, nil)
  -- plus rien a deposer
  CHATCLEAR()
  Click(bk.dbtn)
  CONTAINS("rien a deposer", CHATTEXT(), L("msg.bags.deposit.none"))
  -- le filtre de la fenetre des sacs est respecte
  fillStart()
  BGLAYOUT({ [0] = 16, [1] = 6, [-1] = 24 })
  BGPUT(0, 3, hearth, 1)
  getglobal("OpenAllBags")(true)
  pump(3)
  local w = win("bag")
  BM.CycleFilter(w)
  BM.CycleFilter(w)
  EQ("filtre camelote actif", w.filter, "junk")
  pump(2)
  used = {}
  Click(bk.dbtn)
  pump(40)
  EQ("seulement la camelote : 3 emplacements gris", table.getn(used), 3)
  T("l'equipement reste", W.bg.slot[0][1] ~= nil and W.bg.slot[0][5] ~= nil)
  BM.CycleFilter(w)
  BM.CycleFilter(w)
  EQ("filtre revenu a Tout", w.filter, "all")
  -- interruption : combat en cours de depot
  fillStart()
  BGLAYOUT({ [0] = 16, [1] = 6, [-1] = 24 })
  used = {}
  pump(2)
  Click(bk.dbtn)
  pump(2)
  W.combat = true
  Fire("PLAYER_REGEN_DISABLED")
  local done = table.getn(used)
  pump(20)
  EQ("combat : depot interrompu", BM.dep, nil)
  EQ("combat : plus rien d'envoye", table.getn(used), done)
  W.combat = false
  Fire("PLAYER_REGEN_ENABLED")
  -- banque fermee : bouton cache, depot refuse
  Fire("BANKFRAME_CLOSED")
  EQ("banque fermee : bouton cache", bk.dbtn:IsShown(), false)
  CHATCLEAR()
  EQ("banque fermee : refuse", BM.StartDeposit(), false)
  CONTAINS("banque fermee : message", CHATTEXT(), L("msg.bags.deposit.closed"))
  UseContainerItem = oldUse
  getglobal("CloseAllBags")()
  for _, lang in ipairs({ "fr", "en" }) do
    for _, k in ipairs({ "btn.deposit", "deposit.tip.t", "deposit.tip", "deposit.closed", "deposit.cursor", "deposit.combat", "deposit.none", "deposit.start", "deposit.done",
      "gear", "tip.sort.t", "tip.sort", "tip.filter.t", "tip.filter", "tip.search.t", "tip.search", "view.btn", "view.me", "view.tip.t", "view.tip",
      "view.title", "view.none", "view.combat", "view.bags", "view.bank", "view.nobank", "view.counts", "view.count", "view.uncached",
      "view.age.m", "view.age.h", "view.age.d", "cat.tip.t", "cat.tip" }) do
      T(lang .. " msg " .. k, has(lang, "msg.bags." .. k))
    end
  end
  EQ("aucune erreur interne", SUI.errCount, 0)
end

SECTION("t_bags : infobulles des boutons et engrenage")
do
  getglobal("OpenAllBags")(true)
  pump(2)
  local w = win("bag")
  CreateFrame("GameTooltip", "GameTooltip", UIParent)
  callScript(w.sbtn, "OnEnter")
  EQ("infobulle du tri : titre", GameTooltip.lines[1], L("msg.bags.tip.sort.t"))
  EQ("infobulle du tri : texte", GameTooltip.lines[2], L("msg.bags.tip.sort"))
  callScript(w.sbtn, "OnLeave")
  callScript(w.fbtn, "OnEnter")
  EQ("infobulle du filtre", GameTooltip.lines[1], L("msg.bags.tip.filter.t"))
  callScript(w.fbtn, "OnLeave")
  callScript(w.edit, "OnEnter")
  EQ("infobulle de la recherche", GameTooltip.lines[1], L("msg.bags.tip.search.t"))
  callScript(w.edit, "OnLeave")
  callScript(w.vbtn, "OnEnter")
  EQ("infobulle de la vue", GameTooltip.lines[1], L("msg.bags.view.tip.t"))
  callScript(w.vbtn, "OnLeave")
  T("engrenage cree sur la fenetre des sacs", w.gear ~= nil and w.gear.parent == w.frame)
  getglobal("CloseAllBags")()
end

SECTION("t_bags : fin")
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
