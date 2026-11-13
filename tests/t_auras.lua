-- t_auras : module "auras" (buffs / debuffs / armes du joueur, buffs / debuffs de la cible, cadres du jeu, reglages, modes, cycle de vie).
local SUI = ShikiUI
local C = SUI.Config
AU_SETUP()
BOOT()
SETTLE()
local M = SUI.Auras
local TH = SUI.Theme

local function liveTasks(name)
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == name and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end
local function taskOf(name)
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == name and not SUI.tasks[i].dead then return SUI.tasks[i] end
  end
  return nil
end

local ICON_A = "Interface\\Icons\\Spell_A"
local ICON_B = "Interface\\Icons\\Spell_B"
local ICON_C = "Interface\\Icons\\Spell_C"

SECTION("t_auras : formats du temps")
EQ("1 h", M.TimeText(M.TimeKey(3700)), "1h")
EQ("2 min", M.TimeText(M.TimeKey(125)), "2m")
EQ("1 min", M.TimeText(M.TimeKey(60)), "1m")
EQ("59 s", M.TimeText(M.TimeKey(59.4)), "59")
EQ("10 s", M.TimeText(M.TimeKey(10)), "10")
EQ("9,9 s", M.TimeText(M.TimeKey(9.94)), "9.9")
EQ("0,3 s", M.TimeText(M.TimeKey(0.34)), "0.3")
T("la cle change avec le texte", M.TimeKey(45.2) == M.TimeKey(45.9))

SECTION("t_auras : contrat, coupe par defaut, construction hors combat")
local mod = SUI.modules.auras
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "medium")
T("coupe par defaut", not mod.enabled)
EQ("ligne pfUI relevee", table.concat(SUI.Migrate.MAP.auras, ","), "buff")
EQ("cadre du jeu intact", BuffFrame:IsEventRegistered("PLAYER_AURAS_CHANGED"), 1)
W.combat = true
local c0 = CREATED
C.Set("modules.auras", true)
EQ("combat : module actif", mod.enabled, true)
EQ("combat : aucune frame creee", CREATED, c0)
EQ("combat : pas construit", M.built, false)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
EQ("construit apres le combat", M.built, true)
for _, k in ipairs({ "pb", "pw", "pd", "tb", "td" }) do
  T("groupe " .. k, M.groups[k] ~= nil)
  EQ("position " .. k .. " par la mise en page", SUI.Layout.items["auras." .. k].frame, M.groups[k].holder)
end
EQ("boutons du joueur : 32 buffs", M.groups.pb.max, 32)
EQ("boutons du joueur : 16 debuffs", M.groups.pd.max, 16)
EQ("2 armes", M.groups.pw.max, 2)
EQ("cadres du jeu : buffs masques", BuffFrame:IsEventRegistered("PLAYER_AURAS_CHANGED"), nil)
EQ("cadres du jeu : buffs caches", BuffFrame:IsShown(), false)
EQ("cadres du jeu : armes caches", TemporaryEnchantFrame:IsShown(), false)
EQ("une minuterie", liveTasks("auras.tick"), 1)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_auras : positions par defaut sans chevauchement")
local function span(k)
  local it = SUI.Layout.items["auras." .. k]
  local h = M.groups[k].holder:GetHeight()
  if it.point == "CENTER" then return it.y - h / 2, it.y + h / 2 end
  return it.y - h, it.y
end
local function disjoint(a, b)
  local alo, ahi = span(a)
  local blo, bhi = span(b)
  return ahi <= blo or bhi <= alo
end
T("buffs / armes distincts", disjoint("pb", "pw"))
T("buffs / debuffs distincts", disjoint("pb", "pd"))
T("armes / debuffs distincts", disjoint("pw", "pd"))
T("buffs / debuffs de la cible distincts", disjoint("tb", "td"))

SECTION("t_auras : buffs du joueur")
AU_ADD("buff", { tex = ICON_A, count = 1, left = 300 })
AU_ADD("buff", { tex = ICON_B, count = 3, left = 46 })
AU_ADD("buff", { tex = ICON_C, perm = true })
Fire("PLAYER_AURAS_CHANGED")
Pump(0.25, 2)
local pb = M.groups.pb
EQ("3 buffs affiches", pb.shown, 3)
local b1, b2, b3 = pb.btns[1], pb.btns[2], pb.btns[3]
EQ("bouton 1 visible", b1:IsShown(), true)
EQ("bouton 4 cache", pb.btns[4]:IsShown(), false)
EQ("icone 1", b1.lastTex, ICON_A)
EQ("icone 2", b2.lastTex, ICON_B)
EQ("duree 5 min", b1.timer:GetText(), "5m")
EQ("duree 45 s", b2.timer:GetText(), "45")
EQ("permanent : pas de duree", b3.timer:GetText(), "")
EQ("pile 3", b2.count:GetText(), "3")
EQ("pile 1 : rien", b1.count:GetText(), "")
-- les durees avancent sans evenement
Pump(0.25, 20)
EQ("duree 40 s apres 5 s", b2.timer:GetText(), "40")
-- ecriture seulement si le texte change
local writes = 0
local origSet = b1.timer.SetText
b1.timer.SetText = function(s, t) writes = writes + 1 origSet(s, t) end
Pump(0.25, 40)
EQ("duree longue : aucune reecriture en 10 s", writes, 0)
b1.timer.SetText = origSet
-- alerte de fin
EQ("pas d'alerte au depart", b2.lastWarn, false)
Pump(0.25, 120)
EQ("alerte de fin (moins de 10 s)", b2.lastWarn, true)
EQ("couleur d'alerte", b2.timer.tc[1], TH.c.warn[1])
-- un buff en moins
table.remove(AU.buffs, 1)
Fire("PLAYER_AURAS_CHANGED")
Pump(0.25, 2)
EQ("2 buffs restants", pb.shown, 2)
EQ("le dernier bouton est cache", b3:IsShown(), false)
EQ("les icones se decalent", b1.lastTex, ICON_B)
-- annulation au clic droit
Click(b1, "RightButton")
EQ("clic droit : buff annule", AU.cancelled[1], 0)
Click(b1, "LeftButton")
EQ("clic gauche : rien", table.getn(AU.cancelled), 1)
-- infobulle
Hover(b1, true)
EQ("infobulle de buff", AU.tip[1] .. AU.tip[2], "pb0")
Hover(b1, false)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_auras : debuffs du joueur")
AU_ADD("debuff", { tex = ICON_A, count = 2, left = 20, dtype = "Magic" })
AU_ADD("debuff", { tex = ICON_B, count = 1, left = 8, dtype = nil })
Fire("PLAYER_AURAS_CHANGED")
Pump(0.25, 2)
local pd = M.groups.pd
EQ("2 debuffs", pd.shown, 2)
EQ("bordure magie : bleu du jeu", pd.btns[1].bbc[3], 1)
EQ("bordure magie : rouge", pd.btns[1].bbc[1], 0.2)
EQ("sans type : jeton 'bad'", pd.btns[2].bbc[1], TH.c.bad[1])
EQ("pile des debuffs", pd.btns[1].count:GetText(), "2")
Click(pd.btns[1], "RightButton")
EQ("un debuff ne s'annule pas", table.getn(AU.cancelled), 1)
Hover(pd.btns[1], true)
EQ("infobulle de debuff", AU.tip[1] .. AU.tip[2], "pb100")
Hover(pd.btns[1], false)
C.Set("auras.dispel", false)
Pump(0.25, 2)
EQ("couleur de dissipation coupee", pd.btns[1].bbc[1], TH.c.border[1])
C.Set("auras.dispel", true)
Pump(0.25, 2)
EQ("couleur de dissipation remise", pd.btns[1].bbc[1], 0.2)

SECTION("t_auras : augmentations d'arme")
AU.mh = { ms = 600000, charges = 0 }
Fire("UNIT_INVENTORY_CHANGED", "player")
Pump(0.25, 2)
local pw = M.groups.pw
EQ("1 arme", pw.shown, 1)
EQ("icone de la main droite", pw.btns[1].lastTex, "Interface\\Icons\\INV_Weapon_16")
EQ("duree 10 min", pw.btns[1].timer:GetText(), "10m")
AU.oh = { ms = 30000, charges = 4 }
Fire("UNIT_INVENTORY_CHANGED", "player")
Pump(0.25, 2)
EQ("2 armes", pw.shown, 2)
EQ("icone de la main gauche", pw.btns[2].lastTex, "Interface\\Icons\\INV_Weapon_17")
EQ("charges", pw.btns[2].count:GetText(), "4")
EQ("duree 30 s", pw.btns[2].timer:GetText(), "30")
Hover(pw.btns[2], true)
EQ("infobulle d'arme", AU.tip[1] .. AU.tip[3], "inv17")
Hover(pw.btns[2], false)
Fire("UNIT_INVENTORY_CHANGED", "target")
C.Set("auras.weapon", false)
Pump(0.25, 2)
EQ("armes coupees", pw.shown, 0)
C.Set("auras.weapon", true)
Pump(0.25, 2)
EQ("armes remises", pw.shown, 2)

SECTION("t_auras : cible")
MKTARGET({ name = "Garde" })
AU_ADD("tbuff", { tex = ICON_A, count = 1 })
AU_ADD("tdebuff", { tex = ICON_B, count = 5, dtype = "Poison" })
AU_ADD("tdebuff", { tex = ICON_C, count = 1 })
Fire("PLAYER_TARGET_CHANGED")
local tb, td = M.groups.tb, M.groups.td
EQ("buff de cible", tb.shown, 1)
EQ("debuffs de cible", td.shown, 2)
EQ("icone de debuff de cible", td.btns[1].lastTex, ICON_B)
EQ("bordure poison", td.btns[1].bbc[2], 0.6)
EQ("pile de cible", td.btns[1].count:GetText(), "5")
EQ("la cible n'a pas de duree", td.btns[1].timer:GetText(), "")
Hover(td.btns[2], true)
EQ("infobulle de debuff de cible", AU.tip[1] .. AU.tip[3], "ud2")
Hover(td.btns[2], false)
Hover(tb.btns[1], true)
EQ("infobulle de buff de cible", AU.tip[1] .. AU.tip[3], "ub1")
Hover(tb.btns[1], false)
AU_ADD("tbuff", { tex = ICON_B, count = 1 })
Fire("UNIT_AURA", "party1")
Pump(0.25, 2)
EQ("aura d'un autre : ignoree", tb.shown, 1)
Fire("UNIT_AURA", "target")
Pump(0.25, 2)
EQ("aura de la cible : relue", tb.shown, 2)
W.units.target = nil
Fire("PLAYER_TARGET_CHANGED")
EQ("plus de cible : buffs vides", tb.shown, 0)
EQ("plus de cible : debuffs vides", td.shown, 0)
EQ("plus de cible : boutons caches", td.btns[1]:IsShown(), false)
MKTARGET({ name = "Garde" })
Fire("PLAYER_TARGET_CHANGED")
EQ("nouvelle cible lue", td.shown, 2)
C.Set("auras.targetbuffs", false)
Pump(0.25, 2)
EQ("buffs de cible coupes", tb.shown, 0)
C.Set("auras.targetbuffs", true)
C.Set("auras.targetdebuffs", false)
Pump(0.25, 2)
EQ("debuffs de cible coupes", td.shown, 0)
C.Set("auras.targetdebuffs", true)
C.Set("auras.target", false)
Pump(0.25, 2)
EQ("cible coupee : buffs", tb.shown, 0)
C.Set("auras.target", true)
Pump(0.25, 2)
EQ("cible remise", td.shown, 2)

SECTION("t_auras : reglages")
AU.buffs = {}
AU_ADD("buff", { tex = ICON_A, count = 1, left = 900 })
Fire("PLAYER_AURAS_CHANGED")
Pump(0.25, 2)
C.Set("auras.size", 36)
EQ("taille", pb.btns[1]:GetWidth(), 36)
EQ("taille (hauteur)", pb.btns[1]:GetHeight(), 36)
C.Set("auras.size", 28)
C.Set("auras.tsize", 30)
EQ("taille de cible", td.btns[1]:GetWidth(), 30)
C.Set("auras.tsize", 22)
-- grille : 8 par ligne, 28 px + 3 d'espace, ligne = 41 px
local p9 = pb.btns[9].points[1]
EQ("9e icone : 2e ligne", p9[5], -41)
EQ("9e icone : 1re colonne", p9[4], 0)
EQ("4e icone : 4e colonne vers la gauche", pb.btns[4].points[1][4], -93)
EQ("ancre vers la gauche", pb.btns[4].points[1][1], "TOPRIGHT")
C.Set("auras.grow", "right")
EQ("ancre vers la droite", pb.btns[4].points[1][1], "TOPLEFT")
EQ("4e icone vers la droite", pb.btns[4].points[1][4], 93)
C.Set("auras.grow", "left")
C.Set("auras.perrow", 4)
EQ("4 par ligne : 5e icone en 2e ligne", pb.btns[5].points[1][5], -41)
C.Set("auras.perrow", 8)
C.Set("auras.spacing", 0)
EQ("sans espace : 2e icone", pb.btns[2].points[1][4], -28)
C.Set("auras.spacing", 3)
C.Set("auras.timer", false)
Pump(0.25, 2)
EQ("durees coupees", pb.btns[1].timer:GetText(), "")
C.Set("auras.timer", true)
Pump(0.25, 2)
EQ("durees remises", pb.btns[1].timer:GetText() ~= "", true)
C.Set("auras.stacks", false)
Pump(0.25, 2)
EQ("piles coupees", pb.btns[1].count:GetText(), "")
C.Set("auras.stacks", true)
C.Set("auras.buffs", false)
Pump(0.25, 2)
EQ("buffs coupes", pb.shown, 0)
C.Set("auras.buffs", true)
C.Set("auras.debuffs", false)
Pump(0.25, 2)
EQ("debuffs coupes", pd.shown, 0)
C.Set("auras.debuffs", true)
for i = 1, 10 do AU_ADD("buff", { tex = ICON_A, count = 1, left = 100 }) end
C.Set("auras.maxbuffs", 8)
Pump(0.25, 2)
EQ("buffs limites a 8", pb.shown, 8)
C.Set("auras.maxbuffs", 32)
Pump(0.25, 2)
EQ("32 buffs au plus", pb.shown, 11)
AU.buffs = {}
C.Set("auras.alpha", 0.5)
EQ("opacite", pb.holder:GetAlpha(), 0.5)
C.Set("auras.alpha", 1)
C.Set("auras.warn", 0)
EQ("alerte de fin reglable", M.cfg.warn, 0)
C.Set("auras.warn", 10)
C.Set("auras.tick", 0.5)
EQ("rythme de relecture", taskOf("auras.tick").interval, 0.5)
EQ("toujours une seule minuterie", liveTasks("auras.tick"), 1)
C.Set("auras.tick", 0.25)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_auras : cadres du jeu et deverrouillage")
C.Set("auras.hideblizz", false)
EQ("cadres du jeu rendus", BuffFrame:IsEventRegistered("PLAYER_AURAS_CHANGED"), 1)
EQ("cadres du jeu rendus : visibles", BuffFrame:IsShown(), true)
C.Set("auras.hideblizz", true)
EQ("cadres du jeu recaches", BuffFrame:IsEventRegistered("PLAYER_AURAS_CHANGED"), nil)
C.Set("auras.player", false)
Pump(0.25, 2)
EQ("joueur coupe : cadres du jeu rendus", BuffFrame:IsEventRegistered("PLAYER_AURAS_CHANGED"), 1)
EQ("joueur coupe : debuffs vides", pd.shown, 0)
C.Set("auras.player", true)
Pump(0.25, 2)
EQ("joueur remis : cadres du jeu recaches", BuffFrame:IsEventRegistered("PLAYER_AURAS_CHANGED"), nil)
C.Set("ui.locked", true)
EQ("verrouille : cadre insensible a la souris", pb.holder:IsMouseEnabled(), nil)
EQ("verrouille : repere cache", pb.holder.hint.shown, false)
C.Set("ui.locked", false)
EQ("deverrouille : plus de fond anonyme (cadre insensible)", pb.holder:IsMouseEnabled(), nil)
EQ("deverrouille : plus de repere anonyme", pb.holder.hint.shown, false)
T("deverrouille : poignee nommee du Mover sur les buffs", SUI.Mover.items["auras.pb"].handle ~= nil and SUI.Mover.items["auras.pb"].handle:IsShown())
C.Set("ui.locked", true)

SECTION("t_auras : un reglage agit tout de suite (sans attendre la minuterie)")
local savedBuffs = AU.buffs
AU.buffs = {}
AU_ADD("buff", { tex = ICON_A, count = 4, left = 300 })
Fire("PLAYER_AURAS_CHANGED")
Pump(0.25, 2)
EQ("pile affichee", M.groups.pb.btns[1].count:GetText(), "4")
C.Set("auras.stacks", false)
EQ("piles coupees sans attendre", M.groups.pb.btns[1].count:GetText(), "")
C.Set("auras.stacks", true)
EQ("piles remises sans attendre", M.groups.pb.btns[1].count:GetText(), "4")
C.Set("auras.buffs", false)
EQ("buffs coupes sans attendre", M.groups.pb.shown, 0)
C.Set("auras.buffs", true)
EQ("buffs remis sans attendre", M.groups.pb.shown, 1)
AU.buffs = savedBuffs
Fire("PLAYER_AURAS_CHANGED")
Pump(0.25, 2)

SECTION("t_auras : mode Raid, commande, langues")
SUI.Mode.Set("raid", "manual")
EQ("preset Raid : relecture lente", C.Get("auras.tick"), 0.5)
EQ("preset Raid : buffs de cible coupes", C.Get("auras.targetbuffs"), false)
EQ("preset applique", taskOf("auras.tick").interval, 0.5)
SUI.Mode.Set("normal", "manual")
EQ("retour Normal : relecture", C.Get("auras.tick"), 0.25)
EQ("retour Normal : buffs de cible", C.Get("auras.targetbuffs"), true)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("auras")
CONTAINS("commande", CHATTEXT(), "Auras : ")
T("cible non nulle", M.groups.tb.shown + M.groups.td.shown > 0)
CONTAINS("commande : total cible", CHATTEXT(), "cible " .. (M.groups.tb.shown + M.groups.td.shown))
CHATCLEAR()
SlashCmdList["SHIKIUI"]("help")
CONTAINS("aide du module", CHATTEXT(), "/sui auras")
C.Set("ui.locale", "en")
EQ("anglais", SUI.L("opt.auras.size"), "Icon size")
C.Set("ui.locale", "fr")

SECTION("t_auras : aucune creation en combat")
AU_ADD("buff", { tex = ICON_A, count = 2, left = 120 })
W.combat = true
local c1 = CREATED
local nt = table.getn(SUI.tasks)
for i = 1, 6 do
  Fire("PLAYER_AURAS_CHANGED")
  Fire("PLAYER_TARGET_CHANGED")
  Fire("UNIT_AURA", "target")
  Pump(0.25, 4)
end
EQ("combat : aucune frame creee", CREATED, c1)
T("combat : aucune minuterie creee", table.getn(SUI.tasks) <= nt)
EQ("combat : les icones restent a jour", pb.shown, 1)
W.combat = false

SECTION("t_auras : visibilite commune et police des minuteries")
local V = SUI.Visibility
T("options de visibilite declarees", C.meta["auras.vis"] ~= nil and C.meta["auras.fade"] ~= nil)
T("options de police declarees", C.meta["auras.font"] ~= nil and C.meta["auras.fontsize"] ~= nil)
EQ("pas de texture de barre (aucune barre)", C.meta["auras.bartex"], nil)
local allReg = true
for i = 1, table.getn(M.order) do
  if not V.byFrame[M.groups[M.order[i]].holder] then allReg = false end
end
T("les 5 groupes sont enregistres", allReg)
EQ("opacite pleine par defaut", pb.holder:GetAlpha(), 1)
C.Set("auras.vis", "never")
Pump(0.1, 8)
EQ("regle 'jamais' : opacite nulle", pb.holder:GetAlpha(), 0)
EQ("regle 'jamais' : cadre toujours affiche (logique du module intacte)", pb.holder:IsShown(), true)
C.Set("auras.alpha", 0.5)
EQ("opacite du module sans effet tant que masque", pb.holder:GetAlpha(), 0)
C.Set("auras.vis", "always")
Pump(0.1, 8)
NEAR("regle levee : opacite du module", pb.holder:GetAlpha(), 0.5, 0.001)
C.Set("auras.alpha", 1)
Pump(0.1, 2)
NEAR("opacite du module reglee en direct", pb.holder:GetAlpha(), 1, 0.001)
local tm = pb.btns[1].timer
C.Set("auras.fontsize", 14)
EQ("taille absolue des minuteries", tm.fsize, 14)
C.Set("auras.fontsize", 0)
EQ("taille du module sans reglage", tm.fsize, math.floor(10 * TH.fontScale + 0.5))
EQ("police du style par defaut", tm.font, TH.font)
local ph = pb.holder
C.Set("modules.auras", false)
SETTLE()
EQ("coupe : cadres retires du service", V.byFrame[ph], nil)
C.Set("modules.auras", true)
SETTLE()
T("rallume : cadres de nouveau enregistres", V.byFrame[ph] ~= nil)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_auras : desactivation")
C.Set("modules.auras", false)
EQ("module coupe", mod.enabled, false)
EQ("minuterie rendue", liveTasks("auras.tick"), 0)
EQ("evenements retires", SUI.handlers["PLAYER_AURAS_CHANGED"], nil)
EQ("cadre du joueur cache", pb.holder:IsShown(), false)
EQ("cadre de cible cache", td.holder:IsShown(), false)
EQ("cadres du jeu rendus a la coupure", BuffFrame:IsEventRegistered("PLAYER_AURAS_CHANGED"), 1)
C.Set("modules.auras", true)
EQ("module rallume", mod.enabled, true)
EQ("rallume : une minuterie", liveTasks("auras.tick"), 1)
EQ("rallume : cadre visible", pb.holder:IsShown(), true)
EQ("rallume : cadres du jeu recaches", BuffFrame:IsEventRegistered("PLAYER_AURAS_CHANGED"), nil)
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
