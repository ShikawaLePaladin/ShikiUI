-- t_units : cadres joueur / cible / cible de la cible.
local SUI = ShikiUI
local C = SUI.Config
local U = SUI.Units

-- cadres Blizzard et menus d'origine (le jeu les fournit)
local bPlayer = CreateFrame("Frame", "PlayerFrame", UIParent)
bPlayer:RegisterEvent("UNIT_HEALTH")
local bTarget = CreateFrame("Frame", "TargetFrame", UIParent)
bTarget:RegisterEvent("PLAYER_TARGET_CHANGED")
CreateFrame("Frame", "PlayerFrameDropDown", UIParent)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)

SECTION("t_units : construction")
EQ("pas de cadre avant le demarrage", U.built, false)
BOOT()
SETTLE()
EQ("construit", U.built, true)
local fp, ft, ftt = U.frames.player, U.frames.target, U.frames.targettarget
T("trois cadres", fp ~= nil and ft ~= nil and ftt ~= nil)
EQ("nom global", ft:GetName(), "ShikiUI_Unit_target")
EQ("joueur visible", fp:IsShown(), true)
EQ("cible cachee sans cible", ft:IsShown(), false)
EQ("cible de cible cachee", ftt:IsShown(), false)
EQ("largeur par defaut", fp:GetWidth(), 180)
EQ("hauteur par defaut", fp:GetHeight(), 28)
EQ("cible de cible : largeur x0.6", ftt:GetWidth(), 108)
EQ("cible de cible : hauteur", ftt:GetHeight(), 19)
EQ("nom du joueur", fp.nameText:GetText(), "Shikiwa")
EQ("texte de vie joueur", fp.hpText:GetText(), "100%")
EQ("barre de vie pleine", fp.hp:GetValue(), 1)
NEAR("couleur de classe (paladin)", fp.hp.sbc[1], 0.9)
EQ("barre de ressource visible", fp.pw:IsShown(), true)
NEAR("ressource pleine", fp.pw.value, 1)
NEAR("couleur mana", fp.pw.sbc[3], 0.95)
EQ("pas de ressource pour la cible de cible", ftt.noPower, true)
EQ("aucune erreur interne", SUI.errCount, 0)
-- dessin initial : position par defaut au centre
local p1 = fp.points[1]
EQ("ancre par defaut", p1[1], "CENTER")
EQ("decalage x joueur", p1[4], -230)
-- mouvement possible / verrouille
EQ("deplacable", fp.movable, true)
-- cadres Blizzard masques
EQ("PlayerFrame masque", bPlayer:IsShown(), false)
EQ("PlayerFrame sans evenements", next(bPlayer.events), nil)
EQ("TargetFrame masque", bTarget:IsShown(), false)

SECTION("t_units : cible hostile (pourcentage)")
MKTARGET({ name = "Seigneur", hp = 65, hpMax = 100, level = 63 })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("cible visible", ft:IsShown(), true)
EQ("nom avec niveau", ft.nameText:GetText(), "63 Seigneur")
EQ("pourcentage seul pour un ennemi (max = 100)", ft.hpText:GetText(), "65%")
NEAR("barre", ft.hp:GetValue(), 0.65)
NEAR("rouge hostile", ft.hp.sbc[1], 0.85)
EQ("pas de barre de ressource (pas de mana)", ft.pw:IsShown(), false)
MKTARGET({ name = "Boss", level = -1 })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("niveau ?? pour un boss", ft.nameText:GetText(), "?? Boss")
-- changement de mode du texte : toujours un pourcentage tant que max = 100
C.Set("units.hptext", "both")
SETTLE()
EQ("both + max 100 : pourcentage", ft.hpText:GetText(), "100%")
C.Set("units.hptext", "none")
SETTLE()
EQ("aucun texte", ft.hpText:GetText(), "")
C.Set("units.hptext", "percent")

SECTION("t_units : couleurs")
local function colorFor(t)
  MKTARGET(t)
  Fire("PLAYER_TARGET_CHANGED")
  SETTLE()
  return ft.hp.sbc
end
local col = colorFor({ isPlayer = true, class = "MAGE", friend = false, canAttack = true })
NEAR("joueur ennemi : couleur de classe", col[1], 0.4)
C.Set("units.classcolor", false)
SETTLE()
col = colorFor({ isPlayer = true, class = "MAGE", friend = false, canAttack = true })
NEAR("joueur ennemi sans couleur de classe : rouge", col[1], 0.85)
col = colorFor({ isPlayer = true, class = "MAGE", friend = true, canAttack = false })
NEAR("joueur ami sans couleur de classe : vert", col[2], 0.75)
C.Set("units.classcolor", true)
col = colorFor({ isPlayer = false, friend = true, canAttack = false, enemy = false })
NEAR("PNJ ami : vert", col[2], 0.75)
col = colorFor({ isPlayer = false, friend = false, canAttack = true, enemy = false })
NEAR("PNJ neutre : jaune", col[1], 0.90)
col = colorFor({ isPlayer = false, tapped = true, tappedByMe = false })
NEAR("PNJ marque par un autre : gris", col[1], 0.55)
col = colorFor({ isPlayer = false, tapped = true, tappedByMe = true })
NEAR("PNJ marque par moi : rouge", col[1], 0.85)

SECTION("t_units : formats de vie")
EQ("abbrev 999", U.Abbrev(999), "999")
EQ("abbrev 1000", U.Abbrev(1000), "1.0k")
EQ("abbrev 9999", U.Abbrev(9999), "10.0k")
EQ("abbrev 12000", U.Abbrev(12000), "12k")
EQ("abbrev 1200000", U.Abbrev(1200000), "1.2m")
EQ("valeur", U.HpString("value", 4500, 5000), "4.5k")
EQ("pourcentage", U.HpString("percent", 4500, 5000), "90%")
EQ("les deux", U.HpString("both", 4500, 5000), "4.5k | 90%")
EQ("aucun", U.HpString("none", 4500, 5000), "")
EQ("max 0", U.HpString("percent", 0, 0), "0%")
EQ("max 100 : toujours pourcentage", U.HpString("value", 40, 100), "40%")

SECTION("t_units : etats mort / fantome / hors ligne")
MKTARGET({ isPlayer = true, class = "MAGE", friend = true, canAttack = false, hp = 0, hpMax = 3000, dead = true })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("mort : statut", ft.statusText:GetText(), "Mort")
EQ("mort : pas de texte de vie", ft.hpText:GetText(), "")
EQ("mort : barre vide", ft.hp:GetValue(), 0)
MKTARGET({ isPlayer = true, class = "MAGE", friend = true, canAttack = false, hp = 0, hpMax = 3000, dead = true, ghost = true })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("fantome", ft.statusText:GetText(), "Fantome")
MKTARGET({ isPlayer = true, class = "MAGE", friend = true, canAttack = false, hp = 3000, hpMax = 3000, offline = true })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("hors ligne", ft.statusText:GetText(), "Hors ligne")
EQ("hors ligne : pas de ressource", ft.pw:IsShown(), false)
MKTARGET({ isPlayer = true, class = "MAGE", friend = true, canAttack = false, hp = 3000, hpMax = 3000, mana = 900, manaMax = 3000 })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("vivant : statut efface", ft.statusText:GetText(), "")
EQ("ressource visible", ft.pw:IsShown(), true)
NEAR("ressource 30%", ft.pw.value, 0.3)

SECTION("t_units : evenements groupes")
W.units.target.hp = 1500
Fire("UNIT_HEALTH", "target")
NEAR("pas de mise a jour avant le tour de minuterie", ft.hp:GetValue(), 1)
SETTLE(1)
T("mise a jour apres la minuterie (lissage : en route)", ft.hp:GetValue() < 1)
SETTLE(30)
NEAR("converge vers 50%", ft.hp:GetValue(), 0.5, 0.01)
EQ("texte exact", ft.hpText:GetText(), "50%")
-- plusieurs evenements, une seule mise a jour
local setvals = 0
local origSet = ft.hp.SetValue
ft.hp.SetValue = function(self, v) setvals = setvals + 1; return origSet(self, v) end
C.Set("units.smooth", false)
SETTLE()
setvals = 0
W.units.target.hp = 900
for _ = 1, 20 do Fire("UNIT_HEALTH", "target") end
SETTLE()
EQ("20 evenements -> une seule ecriture de barre", setvals, 1)
NEAR("valeur directe sans lissage", ft.hp:GetValue(), 0.3)
-- inactif : aucune ecriture
setvals = 0
local created = CREATED
Pump(0.06, 200)
EQ("repos : aucune ecriture de barre", setvals, 0)
EQ("repos : aucune creation d'objet", CREATED, created)
-- evenements d'autres unites ignores
Fire("UNIT_HEALTH", "party1")
Fire("UNIT_HEALTH", "mouseover")
EQ("unites inconnues : pas sale", U.dirty, false)
-- puissance
W.units.target.mana = 1500
Fire("UNIT_MANA", "target")
SETTLE()
NEAR("ressource mise a jour", ft.pw.value, 0.5)
-- evenement qui renomme
W.units.target.name = "Renomme"
Fire("UNIT_NAME_UPDATE", "target")
SETTLE()
EQ("nom mis a jour", ft.nameText:GetText(), "61 Renomme")
C.Set("units.smooth", true)

SECTION("t_units : joueur")
W.units.player.hp = 2500
Fire("UNIT_HEALTH", "player")
SETTLE(40)
NEAR("joueur a 50%", fp.hp:GetValue(), 0.5, 0.01)
W.units.player.dead = true
W.units.player.hp = 0
Fire("PLAYER_DEAD")
SETTLE()
EQ("joueur mort", fp.statusText:GetText(), "Mort")
W.units.player.dead = false
W.units.player.hp = 5000
Fire("PLAYER_ALIVE")
SETTLE()
EQ("joueur vivant", fp.statusText:GetText(), "")
W.units.player.ptype = 1
W.units.player.mana = 40
W.units.player.manaMax = 100
Fire("UNIT_DISPLAYPOWER", "player")
SETTLE()
NEAR("couleur rage", fp.pw.sbc[1], 0.85)
NEAR("rage 40%", fp.pw.value, 0.4)
W.units.player.ptype = 0
W.units.player.manaMax = 3000
W.units.player.mana = 3000
Fire("UNIT_DISPLAYPOWER", "player")
SETTLE()

SECTION("t_units : pre-soins (soins entrants sur le joueur et la cible)")
C.Set("units.smooth", false)
T("barre de pre-soin sur le joueur", fp.heal ~= nil)
T("barre de pre-soin sur la cible", ft.heal ~= nil)
EQ("pas de barre sur la cible de cible", ftt.heal, nil)
GRP_SETUP()
GRP_SPELLS({ { "Flash of Light", "Rank 1" }, { "Flash of Light", "Rank 2" } })
if SUI.GroupEngine and SUI.GroupEngine.SyncCast then SUI.GroupEngine.SyncCast() end
W.units.target = nil
Fire("PLAYER_TARGET_CHANGED")
SETTLE(40)
W.units.player.hp = 2500
Fire("UNIT_HEALTH", "player")
SETTLE(40)
NEAR("sans soin : pre-soin egal a la vie", fp.heal:GetValue(), 0.5, 0.001)
-- mon incantation sans cible amie : le soin tombe sur moi, la barre depasse la vie
Fire("SPELLCAST_START", "Flash of Light", 1500)
SETTLE(40)
T("soin sur moi : pre-soin au-dela de la vie", fp.heal:GetValue() > 0.51)
Fire("SPELLCAST_STOP")
SETTLE(40)
NEAR("fin du soin : revient a la vie", fp.heal:GetValue(), 0.5, 0.001)
-- option coupee : la barre suit la vie meme en soin
C.Set("units.incheal", false)
Fire("SPELLCAST_START", "Flash of Light", 1500)
SETTLE(40)
NEAR("option coupee : pre-soin egal a la vie", fp.heal:GetValue(), 0.5, 0.001)
Fire("SPELLCAST_STOP")
C.Set("units.incheal", true)
SETTLE()
-- soin sur ma cible amie : la barre de LA CIBLE monte, pas celle du joueur
MKTARGET({ name = "Soignee", hp = 2000, hpMax = 4000, friend = true })
Fire("PLAYER_TARGET_CHANGED")
SETTLE(40)
Fire("SPELLCAST_START", "Flash of Light", 1500)
SETTLE(40)
T("cible amie : pre-soin au-dela de sa vie", ft.heal:GetValue() > 0.51)
NEAR("cible amie : pas sur le joueur", fp.heal:GetValue(), 0.5, 0.001)
Fire("SPELLCAST_STOP")
SETTLE(40)
C.Set("units.smooth", true)
SETTLE()

SECTION("t_units : cible de la cible (sondage)")
MKTARGET({ name = "Boss", hp = 100, hpMax = 100 })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("pas de cible de cible", ftt:IsShown(), false)
MKTOT()
Pump(0.3)
SETTLE()
EQ("apparait par sondage, sans evenement", ftt:IsShown(), true)
EQ("nom", ftt.nameText:GetText(), "60 Tank")
EQ("pas de ressource", ftt.pw:IsShown(), false)
W.units.targettarget.hp = 4500
Pump(0.3)
SETTLE(30)
EQ("vie suivie par sondage", ftt.hpText:GetText(), "50%")
W.units.targettarget.name = "Autre"
Pump(0.3)
SETTLE()
EQ("changement de nom suivi", ftt.nameText:GetText(), "60 Autre")
W.units.targettarget = nil
Pump(0.3)
SETTLE()
EQ("disparait", ftt:IsShown(), false)
C.Set("units.tot.enabled", false)
MKTOT()
Pump(0.3)
SETTLE()
EQ("desactive : reste cache", ftt:IsShown(), false)
C.Set("units.tot.enabled", true)
SETTLE()
Pump(0.3)
SETTLE()
EQ("reactive : visible", ftt:IsShown(), true)
W.units.targettarget = nil
Pump(0.3)
SETTLE()

SECTION("t_units : distance et ligne de vue")
EQ("(nu) pas de texte tant qu'aucune bande n'est connue", ft.rangeText:GetText(), ">28 yd")
EXT.unitxp("real")
Fire("PLAYER_ENTERING_WORLD")
MKTARGET({ dist = 23.2, sight = true })
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("distance UnitXP", ft.rangeText:GetText(), "23 yd")
W.units.target.dist = 8
Pump(0.3)
EQ("distance mise a jour par sondage", ft.rangeText:GetText(), "8 yd")
EQ("alpha plein (ligne de vue pas encore sure ou visible)", ft.alpha, 1)
Pump(3.5)
W.units.target.sight = false
Pump(0.3)
NEAR("hors ligne de vue : attenue", ft.alpha, 0.55)
W.units.target.sight = true
Pump(0.3)
EQ("de nouveau visible", ft.alpha, 1)
C.Set("units.range", false)
SETTLE()
Pump(0.3)
EQ("distance desactivee : texte efface", ft.rangeText:GetText(), "")
C.Set("units.range", true)
EXT.unitxp(nil)
Fire("PLAYER_ENTERING_WORLD")
W.interact = { target = 3 }
W.units.target.dist = nil
Fire("PLAYER_TARGET_CHANGED")
SETTLE()
EQ("repli sur les tranches 1.12", ft.rangeText:GetText(), "<10 yd")
W.interact = {}

SECTION("t_units : interactions")
W.acts = {}
fp:Click("LeftButton")
EQ("clic : cibler", LASTACT(), "TargetUnit player")
W.spellTargeting = true
ft:Click("LeftButton")
EQ("sort en attente : lancer sur l'unite", LASTACT(), "SpellTargetUnit target")
W.spellTargeting = false
W.cursorItem = true
ft:Click("LeftButton")
EQ("objet au curseur : deposer", LASTACT(), "DropItemOnUnit target")
W.cursorItem = false
fp:Click("RightButton")
EQ("clic droit : menu d'origine", LASTACT(), "Dropdown PlayerFrameDropDown")
W.acts = {}
ftt:Click("RightButton")
EQ("clic droit sans menu connu : rien", LASTACT(), nil)
EXT.nampower(true)
Hover(ft, true)
EQ("survol : mouseover Nampower", LASTACT(), "Mouseover target")
EQ("survol : infobulle", GameTooltip.unit, "target")
Hover(ft, false)
EQ("fin de survol", LASTACT(), "Mouseover nil")
EXT.nampower(false)
Hover(ft, true)   -- ne plante pas sans extension
Hover(ft, false)

SECTION("t_units : configuration")
C.Set("units.width", 220)
EQ("largeur appliquee", fp:GetWidth(), 220)
EQ("cible de cible : proportion", ftt:GetWidth(), 132)
C.Set("units.height", 40)
EQ("hauteur appliquee", ft:GetHeight(), 40)
C.Set("units.showpower", false)
SETTLE()
EQ("ressource masquee", fp.pw:IsShown(), false)
C.Set("units.showpower", true)
SETTLE()
EQ("ressource revenue", fp.pw:IsShown(), true)
C.Set("units.player.enabled", false)
SETTLE()
EQ("joueur desactive", fp:IsShown(), false)
C.Set("units.player.enabled", true)
SETTLE()
EQ("joueur reactive", fp:IsShown(), true)
C.Set("units.target.enabled", false)
SETTLE()
EQ("cible desactivee", ft:IsShown(), false)
C.Set("units.target.enabled", true)
SETTLE()
EQ("cible reactivee", ft:IsShown(), true)
C.Set("units.width", 180); C.Set("units.height", 28)

SECTION("t_units : echelle et position")
C.Set("ui.scale", 1.2)
NEAR("echelle appliquee", fp.scale, 1.2)
C.SetPos("unit.player", 120, 240)
C.Notify("pos", nil)
local pt = fp.points[1]
EQ("position enregistree : coin bas gauche", pt[1], "BOTTOMLEFT")
NEAR("x / echelle", pt[4], 100)
NEAR("y / echelle", pt[5], 200)
-- deplacement : service SUI.Mover (poignee nommee, plus de glisser direct sur le cadre)
C.Set("ui.locked", false)
EQ("deverrouiller ouvre le mode deplacement", SUI.Mover.active, true)
EQ("plus de glisser direct sur le cadre", fp.scripts.OnDragStart, nil)
T("poignee du cadre joueur", SUI.Mover.items["unit.player"].handle ~= nil and SUI.Mover.items["unit.player"].handle:IsShown())
SUI.Mover.Commit(SUI.Mover.items["unit.player"], 360, 180)
local l, b = C.GetPos("unit.player")
NEAR("position sauvee x", l, 360, 1)
NEAR("position sauvee y", b, 180, 1)
C.Set("ui.locked", true)
EQ("verrouiller ferme le mode", SUI.Mover.active, false)
C.Set("ui.scale", 1.0)
C.ResetPositions()
EQ("positions reinitialisees : retour a l'ancre", fp.points[1][1], "CENTER")

SECTION("t_units : roles")
C.ApplyRole("tank")
SETTLE()
MKTARGET({ name = "Ami", isPlayer = true, class = "MAGE", friend = true, canAttack = false, hp = 4500, hpMax = 5000 })
Fire("PLAYER_TARGET_CHANGED")
SETTLE(30)
EQ("tank : valeur et pourcentage", ft.hpText:GetText(), "4.5k | 90%")
C.ApplyRole("heal")
SETTLE()
EQ("heal : pourcentage", ft.hpText:GetText(), "90%")
EQ("heal : cible de cible cachee", ftt:IsShown(), false)
C.ResetProfile()

SECTION("t_units : urgence")
local flushes = 0
local origFlush = U.Flush
local t0 = SUI.rateMul
SUI.Perf.SetEmergency(true)
W.units.target.hp = 1000
Fire("UNIT_HEALTH", "target")
SETTLE(6)
NEAR("urgence : mise a jour sans lissage", ft.hp:GetValue(), 0.2, 0.001)
SUI.Perf.SetEmergency(false)
W.units.target.hp = 4000
Fire("UNIT_HEALTH", "target")
SETTLE(1)
T("hors urgence : lissage de nouveau actif", ft.hp:GetValue() > 0.2 and ft.hp:GetValue() < 0.8)

SECTION("t_units : desactivation / reactivation du module")
created = CREATED
C.Set("modules.units", false)
EQ("module coupe", SUI.modules.units.enabled, false)
EQ("cadres caches", fp:IsShown() or ft:IsShown() or ftt:IsShown(), false)
EQ("evenements detaches", SUI.handlers["UNIT_HEALTH"], nil)
EQ("evenement de cible detache", SUI.handlers["PLAYER_TARGET_CHANGED"], nil)
local nTasks = 0
for i = 1, table.getn(SUI.tasks) do if string.find(SUI.tasks[i].name, "units.", 1, true) and not SUI.tasks[i].dead then nTasks = nTasks + 1 end end
EQ("minuteries annulees", nTasks, 0)
Fire("UNIT_HEALTH", "target")
Pump(1)
EQ("module coupe : aucune erreur", SUI.errCount, 0)
C.Set("modules.units", true)
SETTLE()
EQ("module relance", SUI.modules.units.enabled, true)
EQ("aucun cadre recree", CREATED, created)
EQ("joueur revenu", fp:IsShown(), true)
EQ("cible revenue", ft:IsShown(), true)

SECTION("t_units : cadres Blizzard")
C.Set("units.hideblizz", false)
CONTAINS("rechargement demande", CHATTEXT(), "/reload")
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
