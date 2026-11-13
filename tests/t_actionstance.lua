-- t_actionstance : barres d'action et postures (guerrier 3 postures, druide formes, voleur camouflage, forme d'ombre) : bouton grise quand la
-- posture exigee n'est pas active, posture requise (infobulle / bouton), changement de posture au clic, indicateur sur la barre de formes.
local SUI = ShikiUI
local C = SUI.Config
local TH = SUI.Theme
ABINSTALL()
ABRESET()
EXT.unitxp("real")
local blizz = ABBLIZZ()
local tip = ABTOOLTIP()
local function bar(k) return SUI.Actionbars.bars[k] end
local function btn(k, i) return SUI.Actionbars.bars[k].btn[i] end
local function has(lang, key) return SUI.locales[lang][key] ~= nil end
local function tintIs(b, c) return b.icon.vc and math.abs(b.icon.vc[1] - c[1]) < 0.0001 and math.abs(b.icon.vc[2] - c[2]) < 0.0001 end
local function wrong(b) local r, g = SUI.Actionbars.TintColor(4); return tintIs(b, { r, g }) end
local function CLEARACT() W.acts = {} end
local function settle() Pump(0.1, 4) end

-- infobulle d'analyse : le nom du sort vient de la table de test (champ spell)
local stip = CreateFrame("GameTooltip", "ShikiUI_BarScanFake", UIParent)
stip.SetAction = function(self, slot) self.slot = slot end
rawset(_G, "ShikiUI_BarScanTextLeft1", { GetText = function() local a = W.ab.has[stip.slot]; return a and a.spell or nil end })

local WAR = { "Battle Stance", "Defensive Stance", "Berserker Stance" }
local WARFR = { "Posture de combat", "Posture defensive", "Posture berserker" }
local function forms(names, active)
  W.ab.forms = {}
  for i = 1, table.getn(names) do
    W.ab.forms[i] = { icon = "Interface\\Icons\\Form" .. i, name = names[i], active = (active == i), castable = true }
  end
end
local function shift(active)
  for i = 1, table.getn(W.ab.forms) do W.ab.forms[i].active = (active == i) end
  Fire("UPDATE_SHAPESHIFT_FORM")
  settle()
end

forms(WAR, 1)
ABSLOT(1, { tex = "Interface\\Icons\\SS", spell = "Sweeping Strikes" })
ABSLOT(2, { tex = "Interface\\Icons\\BR", spell = "Berserker Rage" })
ABSLOT(3, { tex = "Interface\\Icons\\Rend", spell = "Rend" })
ABSLOT(4, { tex = "Interface\\Icons\\HS", spell = "Heroic Strike" })
ABSLOT(5, { tex = "Interface\\Icons\\Ful", spell = "Fulgurance" })
ABSLOT(6, { tex = "Interface\\Icons\\SB", spell = "Shield Block" })

SECTION("t_actionstance : guerrier, grise selon la posture")
BOOT()
SUI.Actionbars.scanTip = stip
W.units.player.class = "WARRIOR"
SETTLE()
C.Set("modules.actionbars", true)
SETTLE()
local M = SUI.Actionbars
EQ("option declaree : grisage", C.Get("actionbars.stances"), true)
EQ("option declaree : texte (infobulle)", C.Get("actionbars.stancetext"), "tooltip")
EQ("option declaree : changement auto coupe", C.Get("actionbars.autostance"), false)
EQ("option declaree : indicateur de forme", C.Get("actionbars.stanceind"), true)
EQ("classe lue", M.class, "WARRIOR")
EQ("posture courante : combat", M.curPosture, "battle")
T("Sweeping Strikes en posture de combat : actif", not wrong(btn("main", 1)))
T("Berserker Rage en posture de combat : grise", wrong(btn("main", 2)))
T("Rend (combat / defense) : actif en combat", not wrong(btn("main", 3)))
T("Heroic Strike : jamais grise", not wrong(btn("main", 4)))
T("Fulgurance (FR) en posture de combat : actif", not wrong(btn("main", 5)))
T("Shield Block en posture de combat : grise", wrong(btn("main", 6)))
EQ("exigence memorisee sur le bouton", btn("main", 2).stn.list[1], "berserker")
EQ("sort sans exigence : aucune", btn("main", 4).stn, nil)
shift(3)
EQ("posture courante : berserker", M.curPosture, "berserker")
T("Sweeping Strikes en berserker : grise", wrong(btn("main", 1)))
T("Berserker Rage en berserker : actif", not wrong(btn("main", 2)))
T("Rend en berserker : grise", wrong(btn("main", 3)))
T("Fulgurance (FR) en berserker : grise", wrong(btn("main", 5)))
shift(2)
T("Rend en defensive : actif", not wrong(btn("main", 3)))
T("Shield Block en defensive : actif", not wrong(btn("main", 6)))
T("la couleur vient d'un jeton (jeton dim assombri)", btn("main", 1).icon.vc ~= nil and btn("main", 1).icon.vc[1] < TH.c.dim[1] + 0.0001)
-- priorite : mauvaise posture avant portee / ressource
ABSLOT(1, { tex = "Interface\\Icons\\SS", spell = "Sweeping Strikes", range = 0 })
Fire("ACTIONBAR_SLOT_CHANGED", 1)
settle()
T("mauvaise posture prime sur la portee", wrong(btn("main", 1)))
shift(1)
T("bonne posture + hors de portee : teinte de portee", not wrong(btn("main", 1)))
ABSLOT(1, { tex = "Interface\\Icons\\SS", spell = "Sweeping Strikes" })
Fire("ACTIONBAR_SLOT_CHANGED", 1)
settle()

SECTION("t_actionstance : posture requise (bouton et infobulle)")
EQ("par defaut : rien sur le bouton", btn("main", 2).stnT:GetText(), "")
C.Set("actionbars.stancetext", "button")
EQ("texte sur le bouton : posture manquante (Berserker Rage)", btn("main", 2).stnT:GetText(), SUI.L("msg.actionbars.stance.short.berserker"))
EQ("texte sur le bouton : rien quand la posture est la bonne", btn("main", 1).stnT:GetText(), "")
shift(3)
EQ("texte du bouton suit la posture (Sweeping Strikes)", btn("main", 1).stnT:GetText(), SUI.L("msg.actionbars.stance.short.battle"))
EQ("texte du bouton : plus rien pour Berserker Rage", btn("main", 2).stnT:GetText(), "")
shift(1)
C.Set("actionbars.stancetext", "never")
EQ("jamais : texte vide", btn("main", 2).stnT:GetText(), "")
tip.lines = nil
Hover(btn("main", 2), true)
T("jamais : pas de ligne d'exigence", tip.lines == nil or table.getn(tip.lines) == 0)
Hover(btn("main", 2), false)
C.Set("actionbars.stancetext", "tooltip")
tip.lines = nil
Hover(btn("main", 2), true)
EQ("infobulle : ligne d'exigence", tip.lines and tip.lines[table.getn(tip.lines)], SUI.L("msg.actionbars.stance.need", "Posture berserker"))
Hover(btn("main", 2), false)
tip.lines = nil
Hover(btn("main", 3), true)
EQ("infobulle : plusieurs postures", tip.lines and tip.lines[table.getn(tip.lines)], SUI.L("msg.actionbars.stance.need", "Posture de combat / Posture defensive"))
Hover(btn("main", 3), false)
tip.lines = nil
Hover(btn("main", 4), true)
T("sort sans exigence : pas de ligne", tip.lines == nil or table.getn(tip.lines) == 0)
Hover(btn("main", 4), false)
C.Set("actionbars.stancetext", "both")
EQ("les deux : texte sur le bouton", btn("main", 2).stnT:GetText(), SUI.L("msg.actionbars.stance.short.berserker"))
C.Set("actionbars.stancetext", "tooltip")

SECTION("t_actionstance : changement de posture au clic")
CLEARACT()
Click(btn("main", 2), "LeftButton")
EQ("coupe : le clic lance le sort", LASTACT(), "UseAction 2 1 nil")
C.Set("actionbars.autostance", true)
Click(btn("main", 2), "LeftButton")
EQ("actif : le clic prend la posture berserker", LASTACT(), "CastShapeshiftForm 3")
Click(btn("main", 3), "LeftButton")
EQ("posture deja bonne : le sort part", LASTACT(), "UseAction 3 1 nil")
Click(btn("main", 6), "LeftButton")
EQ("Shield Block : posture defensive", LASTACT(), "CastShapeshiftForm 2")
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
settle()
Click(btn("main", 2), "LeftButton")
EQ("en combat aussi (aucune API protegee en 1.12)", LASTACT(), "CastShapeshiftForm 3")
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
settle()
-- posture inconnue du joueur (Berserker non apprise) : le sort part, le jeu donne son erreur
forms({ "Battle Stance", "Defensive Stance" }, 1)
Fire("UPDATE_SHAPESHIFT_FORMS")
settle()
Click(btn("main", 2), "LeftButton")
EQ("posture non apprise : pas de changement", LASTACT(), "UseAction 2 1 nil")
forms(WAR, 1)
Fire("UPDATE_SHAPESHIFT_FORMS")
settle()
C.Set("actionbars.autostance", false)

SECTION("t_actionstance : indicateur sur la barre de formes")
EQ("barre de formes visible", bar("stance").frame:IsShown(), true)
EQ("forme active : nom court", btn("stance", 1).stnT:GetText(), SUI.L("msg.actionbars.stance.short.battle"))
EQ("forme inactive : pas de nom", btn("stance", 2).stnT:GetText(), "")
local r5, g5 = M.TintColor(5)
T("forme inactive attenuee (jeton)", tintIs(btn("stance", 2), { r5, g5 }))
T("forme active : couleur normale", tintIs(btn("stance", 1), { 1, 1 }))
shift(2)
EQ("l'indicateur suit la forme", btn("stance", 2).stnT:GetText(), SUI.L("msg.actionbars.stance.short.defensive"))
EQ("ancienne forme : nom retire", btn("stance", 1).stnT:GetText(), "")
C.Set("actionbars.stanceind", false)
EQ("indicateur coupe : nom retire", btn("stance", 2).stnT:GetText(), "")
T("indicateur coupe : plus d'attenuation", tintIs(btn("stance", 1), { 1, 1 }))
C.Set("actionbars.stanceind", true)
shift(1)

SECTION("t_actionstance : options, noms francais, macros")
C.Set("actionbars.stances", false)
T("grisage coupe : Berserker Rage normal", not wrong(btn("main", 2)))
EQ("grisage coupe : aucune exigence", btn("main", 2).stn, nil)
C.Set("actionbars.stances", true)
T("grisage reactive", wrong(btn("main", 2)))
-- noms de formes en francais
forms(WARFR, 3)
Fire("UPDATE_SHAPESHIFT_FORMS")
settle()
EQ("nom francais reconnu", M.curPosture, "berserker")
-- postures lues par l'ordre quand le nom est illisible
forms({ "?", "?", "?" }, 2)
Fire("UPDATE_SHAPESHIFT_FORMS")
settle()
EQ("nom inconnu : ordre du guerrier", M.curPosture, "defensive")
forms(WAR, 1)
Fire("UPDATE_SHAPESHIFT_FORMS")
settle()
-- macros : premier /cast sans condition
local MACROS = { Balai = "/cast Sweeping Strikes\n/cast Heroic Strike", Cond = "/cast [stance:1] Charge; Heroic Strike", Nom = "", Zerk = "/cast Berserker Rage(Rank 1)" }
setglobal("GetMacroIndexByName", function(n) if MACROS[n] then return 1 end return 0 end)
setglobal("GetMacroInfo", function(i) return "x", "Interface\\Icons\\X", MACROS[W.lastMacro] end)
local function macro(slot, name, tex) W.lastMacro = name; ABSLOT(slot, { tex = tex, text = name }); Fire("ACTIONBAR_SLOT_CHANGED", slot); settle() end
macro(7, "Zerk", "Interface\\Icons\\MacZerk")
T("macro /cast Berserker Rage : grisee (rang ignore)", wrong(btn("main", 7)))
macro(8, "Cond", "Interface\\Icons\\MacCond")
T("macro conditionnelle : jamais grisee", not wrong(btn("main", 8)))
macro(9, "Balai", "Interface\\Icons\\MacBalai")
T("macro Sweeping Strikes : bonne posture", not wrong(btn("main", 9)))
shift(3)
T("macro Sweeping Strikes en berserker : grisee", wrong(btn("main", 9)))
shift(1)
-- macro sans corps lisible : le nom de la macro sert
ABSLOT(10, { tex = "Interface\\Icons\\MacName", text = "Intercept" })
Fire("ACTIONBAR_SLOT_CHANGED", 10)
settle()
T("macro nommee comme un sort : grisee", wrong(btn("main", 10)))

SECTION("t_actionstance : en combat, aucune infobulle scrutee")
local scans = 0
stip.SetAction = function(self, slot) scans = scans + 1; self.slot = slot end
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
ABSLOT(11, { tex = "Interface\\Icons\\NewTexture", spell = "Pummel" })
Fire("ACTIONBAR_SLOT_CHANGED", 11)
settle()
EQ("combat : pas de scrutation", scans, 0)
T("combat : sort inconnu non grise", not wrong(btn("main", 11)))
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
settle()
T("apres le combat : Pummel reconnu et grise", wrong(btn("main", 11)))
local s1 = scans
for i = 1, 8 do Fire("UPDATE_SHAPESHIFT_FORM"); Pump(0.1, 2) end
EQ("changements de posture : aucune nouvelle scrutation", scans, s1)

SECTION("t_actionstance : druide")
ABRESET()
W.units.player.class = "DRUID"
forms({ "Bear Form", "Aquatic Form", "Cat Form", "Travel Form" }, 3)
ABSLOT(1, { tex = "Interface\\Icons\\Maul", spell = "Maul" })
ABSLOT(2, { tex = "Interface\\Icons\\Claw", spell = "Claw" })
ABSLOT(3, { tex = "Interface\\Icons\\HT", spell = "Healing Touch" })
ABSLOT(4, { tex = "Interface\\Icons\\Swipe", spell = "Balayage" })
Fire("UPDATE_SHAPESHIFT_FORMS")
Fire("PLAYER_ENTERING_WORLD")
settle()
EQ("classe : druide", M.class, "DRUID")
EQ("forme courante : felin", M.curPosture, "cat")
T("Maul en felin : grise", wrong(btn("main", 1)))
T("Claw en felin : actif", not wrong(btn("main", 2)))
T("Healing Touch : jamais grise", not wrong(btn("main", 3)))
T("Balayage (FR, ours) en felin : grise", wrong(btn("main", 4)))
EQ("grand bouton : exigence ours", btn("main", 1).stn.list[1], "bear")
C.Set("actionbars.autostance", true)
CLEARACT()
Click(btn("main", 1), "LeftButton")
EQ("clic sur Maul : forme d'ours (indice 1)", LASTACT(), "CastShapeshiftForm 1")
-- l'indice de forme change selon les formes apprises : retrouve par le nom
forms({ "Aquatic Form", "Dire Bear Form", "Cat Form" }, 0)
shift(0)
EQ("aucune forme active", M.curPosture, nil)
T("humanoide : Claw grise", wrong(btn("main", 2)))
CLEARACT()
Click(btn("main", 1), "LeftButton")
EQ("Dire Bear Form (indice 2) reconnue comme l'ours", LASTACT(), "CastShapeshiftForm 2")
shift(2)
EQ("forme courante : ours", M.curPosture, "bear")
T("Maul en ours : actif", not wrong(btn("main", 1)))
C.Set("actionbars.autostance", false)
forms({ "Forme d'ours redoutable", "Forme de felin" }, 1)
shift(1)
EQ("noms francais du druide", M.curPosture, "bear")
-- extension a chaud
M.AddStanceSpells("DRUID", { "cat" }, { "Healing Touch" })
settle()
T("sort ajoute a chaud : grise", wrong(btn("main", 3)))

SECTION("t_actionstance : voleur (camouflage par aura) et forme d'ombre")
ABRESET()
W.units.player.class = "ROGUE"
local buffs = {}
setglobal("UnitBuff", function(u, i) local b = buffs[i]; if b then return b end return nil end)
ABSLOT(1, { tex = "Interface\\Icons\\Amb", spell = "Ambush" })
ABSLOT(2, { tex = "Interface\\Icons\\SS2", spell = "Sinister Strike" })
Fire("PLAYER_ENTERING_WORLD")
settle()
EQ("aura suivie pour le voleur", M.auraPosture, true)
EQ("pas de posture", M.curPosture, nil)
T("Ambush hors camouflage : grise", wrong(btn("main", 1)))
T("Sinister Strike : jamais grise", not wrong(btn("main", 2)))
buffs = { "Interface\\Icons\\Ability_Stealth" }
Fire("PLAYER_AURAS_CHANGED")
settle()
EQ("camouflage lu dans les buffs", M.curPosture, "stealth")
T("Ambush en camouflage : actif", not wrong(btn("main", 1)))
buffs = {}
Fire("PLAYER_AURAS_CHANGED")
settle()
T("camouflage perdu : Ambush grise", wrong(btn("main", 1)))
-- pas de lecture d'aura pour un guerrier
W.units.player.class = "WARRIOR"
forms(WAR, 1)
Fire("UPDATE_SHAPESHIFT_FORMS")
settle()
EQ("guerrier : pas d'aura suivie", M.auraPosture, false)
-- pretre : forme d'ombre, posture reconnue ; sorts ajoutes par la table de donnees
ABRESET()
W.units.player.class = "PRIEST"
ABSLOT(1, { tex = "Interface\\Icons\\VT", spell = "Vampiric Touch" })
M.AddStanceSpells("PRIEST", { "shadowform" }, { "Vampiric Touch" })
buffs = {}
Fire("PLAYER_AURAS_CHANGED")
Fire("PLAYER_ENTERING_WORLD")
settle()
T("pretre sans forme d'ombre : sort grise", wrong(btn("main", 1)))
buffs = { "Interface\\Icons\\Spell_Shadow_Shadowform" }
Fire("PLAYER_AURAS_CHANGED")
settle()
EQ("forme d'ombre reconnue (aura)", M.curPosture, "shadowform")
T("forme d'ombre active : sort actif", not wrong(btn("main", 1)))
buffs = {}
forms({ "Shadowform" }, 1)
Fire("UPDATE_SHAPESHIFT_FORMS")
settle()
EQ("forme d'ombre reconnue (forme du jeu)", M.curPosture, "shadowform")

SECTION("t_actionstance : donnees, traductions, cycle de vie")
for key in pairs(M.POSTURES) do
  for _, lang in ipairs({ "fr", "en" }) do
    T(lang .. " nom long " .. key, has(lang, "msg.actionbars.stance." .. key))
    T(lang .. " nom court " .. key, has(lang, "msg.actionbars.stance.short." .. key))
  end
end
for cls, list in pairs(M.STANCE_SPELLS) do
  for i = 1, table.getn(list) do
    for k = 1, table.getn(list[i].need) do T(cls .. " : posture connue " .. list[i].need[k], M.POSTURES[list[i].need[k]] ~= nil) end
  end
end
for _, k in ipairs({ "stances", "stancetext", "autostance", "stanceind" }) do
  for _, lang in ipairs({ "fr", "en" }) do
    T(lang .. " libelle " .. k, has(lang, "opt.actionbars." .. k))
    T(lang .. " infobulle " .. k, has(lang, "tip.actionbars." .. k))
  end
end
for _, c in ipairs({ "never", "tooltip", "button", "both" }) do T("choix " .. c, has("fr", "choice.actionbars.stancetext." .. c) and has("en", "choice.actionbars.stancetext." .. c)) end
EQ("normalisation des accents du francais", M.NormSpell("Ma\195\174trise du blocage"), "maitrise du blocage")
EQ("normalisation : Temerite", M.NormSpell("T\195\169m\195\169rit\195\169"), "temerite")
W.units.player.class = "WARRIOR"
forms(WAR, 1)
ABRESET()
W.units.player.class = "WARRIOR"
forms(WAR, 1)
Fire("UPDATE_SHAPESHIFT_FORMS")
settle()
-- module coupe : l'evenement d'aura ne fait plus rien
C.Set("modules.actionbars", false)
local e0 = SUI.errCount
Fire("PLAYER_AURAS_CHANGED")
Fire("UPDATE_SHAPESHIFT_FORM")
Pump(0.5, 3)
EQ("module coupe : rien ne tourne", SUI.errCount, e0)
C.Set("modules.actionbars", true)
settle()
EQ("module rallume : posture relue", M.curPosture, "battle")
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
