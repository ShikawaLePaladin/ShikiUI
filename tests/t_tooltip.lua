-- t_tooltip : module "tooltip" (style, position, couleurs, cible de la cible, ID, niveau d'objet, vie, masquage, coexistence pfUI, modes).
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Tooltip
local TH = SUI.Theme

TT_SETUP()
local function unit(t)
  local d = { name = "Garde", hp = 100, hpMax = 100, mana = 0, manaMax = 0, ptype = 0, level = 60, isPlayer = false, friend = false,
    canAttack = true, enemy = true, reaction = 2, guid = "0xT" }
  for k, v in pairs(t or {}) do d[k] = v end
  return d
end
local function count(pat)
  local n = 0
  for _, l in ipairs(TT_LINES()) do if string.find(l, pat, 1, true) then n = n + 1 end end
  return n
end
local function liveTasks()
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == "tooltip.tick" and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end

-- pfUI fait tourner ses infobulles : le module attend (meme en combat)
pfUI = { module = { tooltip = function() end } }
pfUI_config = { disabled = {} }
local origBag = GameTooltip.SetBagItem
W.combat = true
BOOT()
SETTLE()

SECTION("t_tooltip : coexistence pfUI et construction hors combat")
local mod = SUI.modules.tooltip
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
EQ("ligne pfUI relevee", SUI.Migrate.MAP.tooltip and table.concat(SUI.Migrate.MAP.tooltip, ","), "tooltip")
EQ("etat attente", SUI.Migrate.State("tooltip"), "wait")
T("module retenu", not mod.enabled)
EQ("aucun enrobage tant que pfUI tient les infobulles", GameTooltip.SetBagItem, origBag)
T("prise en main", SUI.Migrate.Take("tooltip"))
EQ("pfUI coupe", pfUI_config.disabled.tooltip, "1")
SUI.Migrate.Boot()
C.Notify(nil, nil)
EQ("module actif", mod.enabled, true)
EQ("combat : rien de construit", M.built, nil)
EQ("combat : pas de minuterie", M.task, nil)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
EQ("construit apres le combat", M.built, true)
T("frame de suivi enfant de l'infobulle", M.watch ~= nil and M.watch.parent == GameTooltip)
T("enrobage des objets", GameTooltip.SetBagItem ~= origBag)
EQ("aucune erreur interne", SUI.errCount, 0)
EQ("une minuterie", liveTasks(), 1)
T("fond au style : couleur posee", GameTooltip.bgc ~= nil)
EQ("bordure au style", GameTooltip.bbc[1], TH.c.border[1])

SECTION("t_tooltip : unites")
SlashCmdList["SHIKIUI"]("tooltip")
W.units.mouseovertarget = nil
TT_HOVER(unit({ name = "Alice", isPlayer = true, class = "MAGE", friend = true, canAttack = false, enemy = false, reaction = 5,
  hp = 8000, hpMax = 9000 }))
EQ("tooltip affichee", GameTooltip:IsShown(), true)
EQ("nom colore (classe)", GameTooltipTextLeft1.tc[1], 0.4)
EQ("nom colore (classe) : vert", GameTooltipTextLeft1.tc[2], 0.8)
EQ("bordure a la couleur de la classe", GameTooltip.bbc[1], 0.4)
EQ("texte de vie", M.hpText:GetText(), "8.0k / 9.0k (89%)")
W.units.mouseover.hp = 4500
Pump(0.6)
EQ("texte de vie mis a jour", M.hpText:GetText(), "4.5k / 9.0k (50%)")
EQ("pas de ligne de cible sans cible", count("Cible"), 0)
GameTooltip:Hide()
EQ("texte de vie efface", M.hpText:GetText(), "")
-- cible de la cible
W.units.mouseovertarget = unit({ name = "Tank", isPlayer = true, class = "WARRIOR", friend = true, canAttack = false, reaction = 5 })
TT_HOVER(unit({ name = "Bob", isPlayer = true, class = "PALADIN", friend = true, canAttack = false, reaction = 5 }))
EQ("ligne de cible", count("Cible : Tank"), 1)
local last = getglobal("GameTooltipTextLeft" .. GameTooltip:NumLines())
EQ("cible coloree (classe, rouge de guerrier)", last.tc[1], RAID_CLASS_COLORS.WARRIOR.r)
GameTooltip:Hide()
C.Set("tooltip.target", false)
TT_HOVER(unit({ name = "Bob", isPlayer = true, class = "PALADIN", friend = true, canAttack = false, reaction = 5 }))
EQ("cible de la cible coupee", count("Cible"), 0)
GameTooltip:Hide()
C.Set("tooltip.target", true)
W.units.mouseovertarget = nil
-- monstre : reaction, pourcentage, ID de PNJ
TT_HOVER(unit({ name = "Garde", hp = 45, hpMax = 100, reaction = 2 }))
EQ("monstre hostile : bordure rouge", GameTooltip.bbc[1], 1)
EQ("monstre hostile : bordure rouge (vert nul)", GameTooltip.bbc[2], 0)
EQ("vie des hostiles : pourcentage", M.hpText:GetText(), "45%")
EQ("pas d'ID par defaut", count("ID PNJ"), 0)
GameTooltip:Hide()
EXT.superwow(true)
C.Set("tooltip.unitid", true)
TT_HOVER(unit({ name = "Garde", guid = "0xF130002D8F2711AB", reaction = 2 }))
EQ("ID de PNJ lu dans le GUID", count("ID PNJ : 11663"), 1)
GameTooltip:Hide()
TT_HOVER(unit({ name = "Joueur", isPlayer = true, class = "MAGE", guid = "0xF130002D8F2711AB", reaction = 5 }))
EQ("pas d'ID pour un joueur", count("ID PNJ"), 0)
GameTooltip:Hide()
TT_HOVER(unit({ name = "Familier", guid = "0xF140002D8F2711AB", reaction = 4 }))
EQ("GUID qui n'est pas une creature : pas d'ID", count("ID PNJ"), 0)
GameTooltip:Hide()
EXT.superwow(false)
TT_HOVER(unit({ name = "Garde", reaction = 2 }))
EQ("sans SuperWoW : pas d'ID", count("ID PNJ"), 0)
GameTooltip:Hide()
C.Set("tooltip.unitid", false)
-- reglages couleur / barre
C.Set("tooltip.bordercolor", false)
TT_HOVER(unit({ name = "Alice", isPlayer = true, class = "MAGE", friend = true, canAttack = false, reaction = 5 }))
EQ("bordure coloree coupee : style", GameTooltip.bbc[1], TH.c.border[1])
GameTooltip:Hide()
C.Set("tooltip.bordercolor", true)
C.Set("tooltip.classcolor", false)
TT_HOVER(unit({ name = "Alice", isPlayer = true, class = "MAGE", friend = true, canAttack = false, reaction = 5 }))
EQ("nom non colore", GameTooltipTextLeft1.tc[1], 1)
GameTooltip:Hide()
C.Set("tooltip.classcolor", true)
C.Set("tooltip.hpvalue", false)
TT_HOVER(unit({ name = "Alice", isPlayer = true, class = "MAGE", friend = true, canAttack = false, reaction = 5, hp = 50, hpMax = 90 }))
EQ("texte de vie coupe", M.hpText:GetText(), "")
GameTooltip:Hide()
C.Set("tooltip.hpvalue", true)
EQ("barre visible par defaut", GameTooltipStatusBar:GetAlpha(), 1)
C.Set("tooltip.hpbar", false)
EQ("barre de vie masquee", GameTooltipStatusBar:GetAlpha(), 0)
C.Set("tooltip.hpbar", true)
-- unite d'un cadre d'unite (SetUnit) : retrouvee par le nom
W.units.party1 = unit({ name = "Pierre", isPlayer = true, class = "PALADIN", friend = true, canAttack = false, reaction = 5 })
W.units.mouseover = nil
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
GameTooltip:SetUnit("party1")
EQ("cadre d'unite : nom colore", GameTooltipTextLeft1.tc[1], RAID_CLASS_COLORS.PALADIN.r)
GameTooltip:Hide()

SECTION("t_tooltip : objets")
local epee = TT_ITEM(1234, "Epee", 4, 66, { "Equip: +10 Force" })
local casque = TT_ITEM(1235, "Casque", 3, 66, { "Item Level 66" })
TT.bag["0:1"] = epee
TT.bag["0:2"] = casque
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
TT.origCalls = 0
GameTooltip:SetBagItem(0, 1)
EQ("l'original est appele une fois", TT.origCalls, 1)
EQ("lien retenu", M.ItemId(M.link), 1234)
EQ("niveau d'objet ajoute", count("Niveau d'objet : 66"), 1)
EQ("pas d'ID par defaut", count("ID objet"), 0)
EQ("bordure epique", GameTooltip.bbc[1], 0.64)
GameTooltip:Hide()
EQ("lien oublie a la fermeture", M.link, nil)
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
GameTooltip:SetBagItem(0, 2)
EQ("niveau deja affiche par le jeu : pas de doublon", count("Niveau d'objet"), 0)
EQ("bordure rare", GameTooltip.bbc[3], 1)
GameTooltip:Hide()
TT_NAMPOWER_LEVEL(true, 70)
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
GameTooltip:SetBagItem(0, 1)
EQ("GetItemLevel de Nampower prioritaire", count("Niveau d'objet : 70"), 1)
GameTooltip:Hide()
TT_NAMPOWER_LEVEL(false)
C.Set("tooltip.itemid", true)
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
GameTooltip:SetBagItem(0, 1)
EQ("ID d'objet", count("ID objet : 1234"), 1)
GameTooltip:Hide()
C.Set("tooltip.itemid", false)
C.Set("tooltip.itemlevel", false)
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
GameTooltip:SetBagItem(0, 1)
EQ("niveau d'objet coupe", count("Niveau d'objet"), 0)
GameTooltip:Hide()
C.Set("tooltip.itemlevel", true)
TT.bag["inv:16"] = epee
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
GameTooltip:SetInventoryItem("player", 16)
EQ("objet equipe", count("Niveau d'objet : 66"), 1)
GameTooltip:Hide()
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
TT.hyper = 0
GameTooltip:SetHyperlink("item:1234:0:0:0")
EQ("lien de chat : original appele une fois", TT.hyper, 1)
EQ("lien de chat : niveau", count("Niveau d'objet : 66"), 1)
GameTooltip:Hide()
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
GameTooltip:SetHyperlink("spell:55")
EQ("lien de sort : aucun objet", M.link, nil)
EQ("lien de sort : aucune ligne ajoutee", GameTooltip:NumLines(), 0)
GameTooltip:Hide()

SECTION("t_tooltip : position, echelle, combat")
GameTooltip.defaultAnchor = nil
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
EQ("position par defaut du jeu", GameTooltip.defaultAnchor, true)
C.Set("tooltip.anchor", "cursor")
GameTooltip.defaultAnchor = nil
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
EQ("position au curseur", GameTooltip.anchor, "ANCHOR_CURSOR")
EQ("original non appele", GameTooltip.defaultAnchor, nil)
C.Set("tooltip.anchor", "default")
C.Set("tooltip.scale", 1.2)
EQ("echelle", GameTooltip:GetScale(), 1.2)
C.Set("tooltip.scale", 1)
C.Set("tooltip.combathide", true)
W.combat = true
TT_HOVER(unit({ name = "Garde", reaction = 2 }))
EQ("combat : infobulle du monde cachee", GameTooltip:IsShown(), false)
local shell = CreateFrame("Frame", "UnCadre", UIParent)
TT_HOVER(unit({ name = "Garde", reaction = 2 }), shell)
EQ("combat : infobulle d'un cadre gardee", GameTooltip:IsShown(), true)
GameTooltip:Hide()
W.combat = false
TT_HOVER(unit({ name = "Garde", reaction = 2 }))
EQ("hors combat : infobulle du monde affichee", GameTooltip:IsShown(), true)
GameTooltip:Hide()
C.Set("tooltip.combathide", false)

SECTION("t_tooltip : prix marchand")
do
  local price = 12345
  setglobal("C_Item", { GetItemSellPriceByID = function(id) return price end })
  local function bagTip(b, s)
    GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(b, s)
  end
  local coin = M.CoinText(12345)
  EQ("pieces : or, argent, cuivre", coin, "1po 23pa 45pc")
  EQ("pieces : cuivre seul", M.CoinText(7), "7pc")
  EQ("pieces : or et cuivre (argent a zero)", M.CoinText(10005), "1po 0pa 5pc")
  EQ("pieces : argent seul", M.CoinText(300), "3pa")
  bagTip(0, 1)
  EQ("prix a l'unite (ClassicAPI)", count("Marchand : 1po 23pa 45pc"), 1)
  GameTooltip:Hide()
  BGLAYOUT({ [0] = 4 })
  BGPUT(0, 1, 1234, 5)
  bagTip(0, 1)
  EQ("prix de la pile (sac)", count("Marchand : 1po 23pa 45pc (pile de 5 : 6po 17pa 25pc)"), 1)
  EQ("pile : une seule ligne de prix", count("Marchand"), 1)
  GameTooltip:Hide()
  BGPUT(0, 1, nil)
  -- chez un marchand le jeu affiche le prix de revente des objets du sac
  local mf = CreateFrame("Frame", "MerchantFrame", UIParent)
  bagTip(0, 1)
  EQ("marchand ouvert : pas de doublon pour un objet du sac", count("Marchand"), 0)
  GameTooltip:Hide()
  GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink("item:1234:0:0:0")
  EQ("marchand ouvert : lien de chat quand meme", count("Marchand"), 1)
  GameTooltip:Hide()
  mf:Hide()
  bagTip(0, 1)
  EQ("marchand ferme : prix", count("Marchand"), 1)
  GameTooltip:Hide()
  -- sources
  price = 0
  bagTip(0, 1)
  EQ("prix nul : rien", count("Marchand"), 0)
  GameTooltip:Hide()
  setglobal("C_Item", nil)
  bagTip(0, 1)
  EQ("aucune source : rien", count("Marchand"), 0)
  GameTooltip:Hide()
  local origInfo = GetItemInfo
  GetItemInfo = function(x)
    local a, b, c, d, e, f, g, h, i, j = origInfo(x)
    if not a then return nil end
    return a, b, c, d, e, f, g, h, i, j, 777
  end
  bagTip(0, 1)
  EQ("11e retour de GetItemInfo", count("Marchand : 7pa 77pc"), 1)
  GameTooltip:Hide()
  local lnk = M.Link("SetBagItem", 0, 1)
  SUI.Bags.INF.price[lnk] = 4321
  bagTip(0, 1)
  EQ("valeur memorisee par les sacs en priorite", count("Marchand : 43pa 21pc"), 1)
  GameTooltip:Hide()
  SUI.Bags.INF.price[lnk] = nil
  GetItemInfo = origInfo
  setglobal("C_Item", { GetItemSellPriceByID = function() return 12345 end })
  C.Set("tooltip.vendor", false)
  bagTip(0, 1)
  EQ("option coupee : pas de prix", count("Marchand"), 0)
  GameTooltip:Hide()
  C.Set("tooltip.vendor", true)
  -- combat + masquer en combat : ni prix ni possession
  C.Set("tooltip.combathide", true)
  W.combat = true
  bagTip(0, 1)
  EQ("combat + masquer en combat : pas de prix", count("Marchand"), 0)
  EQ("combat + masquer en combat : niveau d'objet garde", count("Niveau d'objet : 66"), 1)
  GameTooltip:Hide()
  C.Set("tooltip.combathide", false)
  bagTip(0, 1)
  EQ("combat sans masquage : prix", count("Marchand"), 1)
  GameTooltip:Hide()
  W.combat = false
  setglobal("C_Item", nil)
end

SECTION("t_tooltip : objets possedes")
do
  local me = M.CharKey()
  T("cle du personnage", me ~= nil and string.find(me, "-", 1, true) ~= nil)
  local function bagTip()
    GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(0, 1)
  end
  EQ("sans cache ni sacs : aucune ligne", (function() bagTip(); local n = count("Possede"); GameTooltip:Hide(); return n end)(), 0)
  BGLAYOUT({ [0] = 4 })
  BGPUT(0, 1, 1234, 5)
  bagTip()
  EQ("sacs seuls (direct)", count("Possede : 5 sacs"), 1)
  EQ("sacs seuls : aucun autre", count("autres"), 0)
  GameTooltip:Hide()
  local root = { rev = 1, chars = {
    [me] = { name = "Moi", bank = { "1234:0:0:0~3~3~equip~x~armor~plate~Epee" }, bags = { "1234:0:0:0~99~3~equip~x~armor~plate~Epee" } },
    ["Bob-R"] = { name = "Bob", bags = { "1234:0:0:0~2~3~equip~x~armor~plate~Epee", "55:0:0:0~9~1~other~x~a~b~Autre" },
      bank = { "1234:0:0:0~4~3~equip~x~armor~plate~Epee" } },
    ["Eve-R"] = { name = "Eve", bags = { "1234:0:0:0~1~3~equip~x~armor~plate~Epee" }, bank = {} },
    ["Casse-R"] = "pas une table",
  } }
  C.SetGlobal("bagcache", root)
  bagTip()
  EQ("sacs / banque / autres", count("Possede : 5 sacs / 3 banque / 7 autres personnages"), 1)
  EQ("le sac memorise du personnage courant est ignore (direct)", count("99"), 0)
  EQ("detail par personnage", count("Bob 6") + count("Eve 1"), 2)
  GameTooltip:Hide()
  EQ("une seule ligne de detail", (function() bagTip(); local n = count("Bob"); GameTooltip:Hide(); return n end)(), 1)
  -- l'index suit la revision du cache
  root.chars["Eve-R"].bags[1] = "1234:0:0:0~10~3~equip~x~armor~plate~Epee"
  bagTip()
  EQ("meme revision : index conserve", count("autres personnages"), 1)
  EQ("meme revision : ancien total", count("7 autres personnages"), 1)
  GameTooltip:Hide()
  root.rev = 2
  bagTip()
  EQ("nouvelle revision : index reconstruit", count("16 autres personnages"), 1)
  GameTooltip:Hide()
  BGPUT(0, 1, nil)
  bagTip()
  TT.bag["0:1"] = TT.bag["0:1"]
  EQ("sans objet en sac : banque et autres", count("Possede : 3 banque / 16 autres personnages"), 1)
  GameTooltip:Hide()
  C.Set("tooltip.owned", false)
  bagTip()
  EQ("option coupee : rien", count("Possede"), 0)
  GameTooltip:Hide()
  C.Set("tooltip.owned", true)
  -- plus de quatre personnages : liste tronquee
  for i = 1, 5 do root.chars["Z" .. i .. "-R"] = { name = "Z" .. i, bags = { "1234:0:0:0~1~3~equip~x~armor~plate~Epee" }, bank = {} } end
  root.rev = 3
  bagTip()
  EQ("detail tronque a 4 noms", count(", ..."), 1)
  GameTooltip:Hide()
  C.Set("tooltip.combathide", true)
  W.combat = true
  bagTip()
  EQ("combat + masquer en combat : pas de possession", count("Possede"), 0)
  GameTooltip:Hide()
  W.combat = false
  C.Set("tooltip.combathide", false)
  -- objet que personne ne possede
  GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink("item:1234:0:0:0")
  EQ("lien de chat : compte aussi les autres personnages", count("autres personnages"), 1)
  GameTooltip:Hide()
  C.SetGlobal("bagcache", nil)
  bagTip()
  EQ("cache supprime : aucune ligne, aucune erreur", count("Possede"), 0)
  GameTooltip:Hide()
  EQ("aucune erreur interne", SUI.errCount, 0)
end

SECTION("t_tooltip : textes des nouveaux reglages")
for _, lang in ipairs({ "fr", "en" }) do
  for _, k in ipairs({ "vendor", "owned" }) do
    T(lang .. " libelle " .. k, SUI.locales[lang]["opt.tooltip." .. k] ~= nil)
    T(lang .. " aide " .. k, SUI.locales[lang]["tip.tooltip." .. k] ~= nil)
  end
  for _, k in ipairs({ "coin.g", "coin.s", "coin.c", "vendor", "vendor.stack", "owned", "owned.bags", "owned.bank", "owned.others" }) do
    T(lang .. " msg " .. k, SUI.locales[lang]["msg.tooltip." .. k] ~= nil)
  end
end
local nopt, nsimple = 0, 0
for i = 1, table.getn(mod.options) do
  nopt = nopt + 1
  if mod.options[i].simple then nsimple = nsimple + 1 end
end
EQ("14 reglages", nopt, 14)
T("prix et possession dans le mode Simple", C.Get("tooltip.vendor") == true and C.Get("tooltip.owned") == true)

SECTION("t_tooltip : mode Raid")
SUI.Mode.Set("raid", "manual")
EQ("raid : masquage en combat", C.Get("tooltip.combathide"), true)
EQ("raid : pas de texte de vie", C.Get("tooltip.hpvalue"), false)
EQ("raid : lu par le module", M.cfg.combathide, true)
SUI.Mode.Set("normal", "manual")
EQ("retour Normal", C.Get("tooltip.combathide"), false)

SECTION("t_tooltip : style et barre reversibles a chaud")
C.Set("tooltip.style", false)
EQ("style coupe : fond d'origine", GameTooltip.backdrop and GameTooltip.backdrop.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border")
TH.Restyle()
EQ("style coupe : le repeint du theme n'y touche pas", GameTooltip.backdrop.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border")
C.Set("tooltip.style", true)
T("style rendu : fond ShikiUI", GameTooltip.backdrop and GameTooltip.backdrop.edgeFile ~= "Interface\\Tooltips\\UI-Tooltip-Border")
C.Set("tooltip.hpbar", false)
C.Set("modules.tooltip", false)
EQ("module coupe : barre de vie rendue malgre hpbar=false", GameTooltipStatusBar:GetAlpha(), 1)
EQ("module coupe : fond d'origine", GameTooltip.backdrop.edgeFile, "Interface\\Tooltips\\UI-Tooltip-Border")
C.Set("modules.tooltip", true)
C.Set("tooltip.hpbar", true)
T("module rallume : fond ShikiUI", GameTooltip.backdrop.edgeFile ~= "Interface\\Tooltips\\UI-Tooltip-Border")

SECTION("t_tooltip : desactivation et reactivation")
C.Set("modules.tooltip", false)
EQ("module coupe", mod.enabled, false)
EQ("echelle rendue", GameTooltip:GetScale(), 1)
EQ("minuterie rendue", liveTasks(), 0)
C.Set("tooltip.anchor", "cursor")
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
T("coupe : position du jeu", GameTooltip.anchor ~= "ANCHOR_CURSOR")
C.Set("tooltip.anchor", "default")
W.units.mouseovertarget = unit({ name = "Tank", isPlayer = true, class = "WARRIOR", friend = true, canAttack = false, reaction = 5 })
TT_HOVER(unit({ name = "Bob", isPlayer = true, class = "PALADIN", friend = true, canAttack = false, reaction = 5 }))
EQ("coupe : aucune ligne ajoutee", GameTooltip:NumLines(), 2)
EQ("coupe : nom non colore", GameTooltipTextLeft1.tc[1], 1)
GameTooltip:Hide()
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
TT.origCalls = 0
GameTooltip:SetBagItem(0, 1)
EQ("coupe : l'original reste appele", TT.origCalls, 1)
GameTooltip:Hide()
C.Set("modules.tooltip", true)
EQ("module rallume", mod.enabled, true)
EQ("une seule minuterie", liveTasks(), 1)
GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
TT.origCalls = 0
GameTooltip:SetBagItem(0, 1)
EQ("rallume : original appele une seule fois (pas de double enrobage)", TT.origCalls, 1)
EQ("rallume : niveau d'objet une seule fois", count("Niveau d'objet : 66"), 1)
GameTooltip:Hide()
EQ("aucune erreur interne", SUI.errCount, 0)
T("pas de texte manquant", next(SUI.missingL) == nil)
C.Set("ui.locale", "en")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("tooltip")
CONTAINS("anglais", CHATTEXT(), "hook(s) installed")
C.Set("ui.locale", "fr")
DONE()
