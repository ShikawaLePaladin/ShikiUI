-- t_powerauras : module "powerauras" (alertes : auras, recharges, barres, conditions, procs, zones, packs, page du menu, cout).
local SUI = ShikiUI
local C = SUI.Config
PA_SETUP()
BOOT()
MKPLAYER()
W.units.player.class = "WARRIOR"
SETTLE()
local M = SUI.PowerAuras
M.class = ""
M.Load()
local L = SUI.L
local getn = table.getn

local function liveTasks(name)
  local n = 0
  for i = 1, getn(SUI.tasks) do
    if SUI.tasks[i].name == name and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end
local function hasHandler(ev, fn)
  local h = SUI.handlers[ev]
  if not h then return false end
  for i = 1, getn(h) do if h[i] == fn then return true end end
  return false
end
local function reset()
  C.SetBase("powerauras.data", "")
  C.SetBase("powerauras.zones", "rrrddrdd")
  M.editId = 0
  M.pick = false
  M.SetDemo(false)
  PA_CLEAR()
  PA.cd, PA.sounds, PA.files, PA.combo, PA.party, PA.raid = {}, {}, {}, 0, 0, 0
  PA.tabs = { 0, 0, 0 }
  PA.bagcd, PA.equipcd = {}, {}
  W.combat = false
  W.units.target = nil
  M.quietUntil = 0
  M.bannerUntil, M.flashUntil = 0, 0
  M.lastSound = -10
end
local function tick() Pump(0.25) end
local function add(t, pack)
  local a, why = M.Add(t, pack)
  tick()
  return a
end
local function tileOf(a) return a.tile and a.tile.f or nil end

SECTION("t_powerauras : contrat, coupe par defaut, rien tant qu'aucune alerte")
local mod = SUI.modules.powerauras
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
T("coupe par defaut", not mod.enabled)
EQ("9 options", getn(mod.options), 9)
T("pas d'equivalent pfUI", SUI.Migrate.MAP.powerauras == nil)
EQ("aucune minuterie avant activation", liveTasks("powerauras.tick"), 0)
EQ("aucun evenement avant activation", hasHandler("UNIT_AURA", M.OnEvent), false)
EQ("aucune tuile", getn(M.tiles), 0)
local c0 = CREATED
C.Set("modules.powerauras", true)
SETTLE()
EQ("actif", mod.enabled, true)
EQ("sans alerte : aucune minuterie", liveTasks("powerauras.tick"), 0)
EQ("sans alerte : aucun evenement", hasHandler("UNIT_AURA", M.OnEvent), false)
EQ("sans alerte : aucune frame creee", CREATED, c0)
T("sans alerte : indication a l'activation", string.find(CHATTEXT(), "powerauras", 1, true) ~= nil)
EQ("categorie du menu", SUI.categories.powerauras, 66)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_powerauras : sauvegarde, validation, limites")
reset()
local a1 = add({ kind = "aura", name = "Reaction", tex = "Interface\\Icons\\Spell_Reaction", zone = 2, size = 48, proc = true })
T("alerte creee", a1 ~= nil)
EQ("1 alerte", M.nal, 1)
EQ("identifiant 1", a1.id, 1)
local data = C.Get("powerauras.data")
T("sauvegarde : genre et nom", string.find(data, "k=aura", 1, true) and string.find(data, "n=Reaction", 1, true))
T("sauvegarde : icone sans antislash", not string.find(data, "\\", 1, true) and string.find(data, "t=Interface/Icons/Spell_Reaction", 1, true))
T("sauvegarde : seuls les ecarts", not string.find(data, "d=icon", 1, true) and not string.find(data, "u=player", 1, true))
EQ("icone relue avec antislash", a1.texd, "Interface\\Icons\\Spell_Reaction")
EQ("icone de comparaison en minuscules", a1.texr, "interface\\icons\\spell_reaction")
EQ("nom de comparaison en minuscules", a1.namel, "reaction")
EQ("zone relue", a1.zone, 2)
EQ("proc relu", a1.proc, true)
EQ("liste d'auras de l'alerte", a1.lk, "pb")
-- texte libre sans separateurs
local a2 = add({ kind = "cd", name = "  A;b|c=d\n  " })
EQ("separateurs retires", a2.name, "A b c d")
EQ("40 caracteres au plus", string.len(M.Clean(string.rep("x", 90))), 40)
-- sauvegarde corrompue
C.SetBase("powerauras.data", "k=bogus|i=1|z=99|s=500|g=zzz|h=-5|p=9;i=1|k=power|r=zzz|w=nope;;garbage;k=cd|i=0|e=0")
EQ("4 fiches lues (les vides sont sautees)", M.nal, 4)
EQ("genre inconnu -> aura", M.alerts[1].kind, "aura")
EQ("zone bornee", M.alerts[1].zone, 8)
EQ("taille bornee", M.alerts[1].size, 96)
EQ("lueur inconnue -> defaut", M.alerts[1].glow, "border")
EQ("seuil borne", M.alerts[1].thr, 0)
EQ("specialisation bornee", M.alerts[1].spec, 3)
EQ("identifiant en double corrige", M.alerts[2].id ~= M.alerts[1].id, true)
EQ("ressource inconnue -> vie", M.alerts[2].res, "health")
EQ("declencheur invalide pour une barre -> toujours", M.alerts[2].when, "always")
EQ("identifiant nul corrige", M.alerts[3].id > 0, true)
EQ("alerte coupee relue", M.alerts[4].on, false)
EQ("identifiants distincts", M.alerts[3].id ~= M.alerts[2].id and M.alerts[3].id ~= M.alerts[1].id and M.alerts[4].id ~= M.alerts[3].id, true)
-- limite
reset()
for i = 1, 24 do M.Add({ kind = "cd", name = "S" .. i }) end
EQ("24 alertes", M.nal, 24)
local over, why = M.Add({ kind = "cd", name = "Trop" })
EQ("25e refusee", over, nil)
EQ("raison : plein", why, "full")
local bigdata = ""
for i = 1, 30 do bigdata = bigdata .. (i > 1 and ";" or "") .. "k=cd|i=" .. i end
C.SetBase("powerauras.data", bigdata)
EQ("30 fiches sauvegardees : 24 lues", M.nal, 24)
-- aller-retour exact
reset()
local rt = add({ kind = "aura", unit = "target", filt = "debuff", name = "Rend", when = "missing", dur = 12, col = "bad", glow = "pulse", snd = "ping",
  vc = "combat", grp = "raid", cls = "WARRIOR", spec = 2, minst = 3, hold = 5, tm = false, sk = false, lb = true, disp = "bar", size = 28, zone = 6 })
local enc = M.EncodeOne(rt)
local copy = {}
M.DecodeInto(copy, enc)
local same = true
for i = 1, getn(M.F) do
  local f = M.F[i]
  if copy[f[2]] ~= rt[f[2]] then same = false; print("  ecart " .. f[2] .. " " .. tostring(copy[f[2]]) .. " / " .. tostring(rt[f[2]])) end
end
T("aller-retour sans perte", same)

SECTION("t_powerauras : buff sur moi (icone, nom, piles, duree, absence)")
reset()
SUI.Api.Detect()
local tex = "Interface\\Icons\\Spell_Nature_Reaction"
local b1 = add({ kind = "aura", name = "Reaction", size = 40, zone = 1 })
EQ("alerte active sans aura", b1.act, false)
EQ("evenements ecoutes avec une alerte", hasHandler("UNIT_AURA", M.OnEvent), true)
EQ("une minuterie", liveTasks("powerauras.tick"), 1)
EQ("tuiles preparees", getn(M.tiles) >= 1, true)
EQ("infobulle cachee creee", M.tip ~= nil, true)
local pa = PA_BUFF("pb", "Reaction", tex, 3, 20)
PA_BUFF("pb", "Autre", "Interface\\Icons\\Other", 0, 5)
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("aura trouvee par son nom", b1.act, true)
EQ("tuile attribuee", b1.shown, true)
T("tuile visible", tileOf(b1):IsShown())
EQ("piles lues", b1.cnt, 3)
NEAR("duree restante lue", b1.left, 20, 0.5)
EQ("icone prise sur l'aura", b1.dtex, string.lower(tex))
EQ("icone affichee", b1.tile.tex, string.lower(tex))
EQ("texte des piles", b1.tile.cnt:GetText(), "3")
EQ("texte du temps", b1.tile.time:GetText(), "20")
local calls = PA.tipcalls
tick() tick()
EQ("noms memorises : pas de nouvelle lecture d'infobulle", PA.tipcalls, calls)
-- le temps avance sans evenement
Pump(5.1)
NEAR("temps restant mis a jour sans evenement", b1.left, 14.9, 1)
-- l'aura disparait
PA.pb = {}
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("aura retiree : alerte eteinte", b1.act, false)
EQ("tuile rendue", b1.tile, false)
-- nom + icone connus : on ne lit le nom que des auras de cette icone
local b2 = add({ kind = "aura", name = "Precis", tex = "Interface/Icons/Spell_Precis", zone = 1 })
PA_CLEAR()
PA_BUFF("pb", "Un", "Interface\\Icons\\A", 0, 5)
PA_BUFF("pb", "Deux", "Interface\\Icons\\B", 0, 5)
PA_BUFF("pb", "Precis", "Interface\\Icons\\Spell_Precis", 0, 5)
PA_BUFF("pb", "Trois", "Interface\\Icons\\C", 0, 5)
calls = PA.tipcalls
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("trouvee par icone et nom", b2.act, true)
EQ("noms lus une seule fois par analyse (4 auras)", PA.tipcalls - calls <= 4, true)
-- meme icone, autre nom : pas de faux positif
PA_CLEAR()
PA_BUFF("pb", "Imposteur", "Interface\\Icons\\Spell_Precis", 0, 5)
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("meme icone mais autre nom : eteinte", b2.act, false)
-- sans lecture de nom possible : l'icone suffit
local savedTip = M.tip
M.tip = nil
PA_CLEAR()
PA_BUFF("pb", "Imposteur", "Interface\\Icons\\Spell_Precis", 0, 5)
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("sans infobulle : l'icone suffit", b2.act, true)
M.tip = savedTip
-- insensible a la casse
reset()
local b3 = add({ kind = "aura", name = "clearcasting" })
PA_BUFF("pb", "Clearcasting", "Interface\\Icons\\X", 0, nil)
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("nom insensible a la casse", b3.act, true)
EQ("aura permanente : pas de temps", b3.hasleft, false)
EQ("aura permanente : pas de texte de temps", b3.tile.time:GetText(), "")
EQ("une pile : pas de texte de piles", b3.tile.cnt:GetText(), "")
-- piles minimum
reset()
local b4 = add({ kind = "aura", name = "Flurry", minst = 3 })
local fl = PA_BUFF("pb", "Flurry", "Interface\\Icons\\F", 2, 10)
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("2 piles sous le minimum de 3 : eteinte", b4.act, false)
fl.count = 3
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("3 piles : allumee", b4.act, true)
-- absence
reset()
local m1 = add({ kind = "aura", name = "Battle Shout", when = "missing", vc = "combat" })
tick()
EQ("absent hors combat : filtre combat", m1.act, false)
W.combat = true
tick()
EQ("absent en combat : allumee", m1.act, true)
PA_BUFF("pb", "Battle Shout", "Interface\\Icons\\BS", 0, 100)
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("present : eteinte", m1.act, false)
-- evenements d'autres unites ignores
PA_CLEAR()
M.dA.pb = false
Fire("UNIT_AURA", "party1")
EQ("UNIT_AURA d'un autre joueur ignore", M.dA.pb, false)
Fire("UNIT_AURA", "player")
EQ("UNIT_AURA du joueur marque la lecture", M.dA.pb, true)
M.dA.tb = false
Fire("UNIT_AURA", "target")
EQ("UNIT_AURA de la cible sans alerte de cible : ignore", M.dA.tb, false)
-- mort : pas d'alerte d'absence
W.units.player.dead = true
tick()
EQ("joueur mort : pas d'alerte d'absence", m1.act, false)
W.units.player.dead = nil
W.combat = false

SECTION("t_powerauras : debuff sur la cible (duree estimee, auras deja posees)")
reset()
local d1 = add({ kind = "aura", unit = "target", filt = "debuff", name = "Rend", dur = 12, zone = 2 })
EQ("liste de cible", d1.lk, "td")
tick()
EQ("pas de cible : eteinte", d1.act, false)
MKTARGET({ name = "Boss" })
Fire("PLAYER_TARGET_CHANGED")
tick()
EQ("cible sans debuff : eteinte", d1.act, false)
local td = PA_BUFF("td", "Rend", "Interface\\Icons\\Rend", 1, nil)
Fire("UNIT_AURA", "target")
tick()
EQ("debuff pose sous nos yeux : allumee", d1.act, true)
NEAR("duree estimee : 12 s", d1.left, 12, 0.6)
EQ("duree estimee affichee", d1.hasleft, true)
Pump(5)
NEAR("compte a rebours estime", d1.left, 7, 0.6)
Pump(8)
EQ("duree ecoulee : plus de temps affiche", d1.hasleft, false)
EQ("le debuff est toujours la : allumee", d1.act, true)
-- debuff deja pose a la selection : aucun temps invente
Fire("PLAYER_TARGET_CHANGED")
tick()
EQ("deja pose a la selection : allumee", d1.act, true)
EQ("deja pose : pas de duree inventee", d1.hasleft, false)
-- debuff manquant : cible hostile vivante seulement
reset()
local d2 = add({ kind = "aura", unit = "target", filt = "debuff", name = "Sunder Armor", when = "missing", vc = "combat" })
W.combat = true
tick()
EQ("sans cible : eteinte", d2.act, false)
MKTARGET({ name = "Boss" })
Fire("PLAYER_TARGET_CHANGED")
tick()
EQ("cible hostile sans le debuff : allumee", d2.act, true)
W.units.target.canAttack = false
tick()
EQ("cible amicale : eteinte", d2.act, false)
W.units.target.canAttack = true
W.units.target.dead = true
tick()
EQ("cible morte : eteinte", d2.act, false)
W.units.target.dead = nil
-- buff de cible
reset()
local d3 = add({ kind = "aura", unit = "target", filt = "buff", name = "Enrage" })
EQ("liste de buffs de cible", d3.lk, "tb")
MKTARGET({ name = "Boss" })
PA_BUFF("tb", "Enrage", "Interface\\Icons\\Enrage", 1, nil)
Fire("PLAYER_TARGET_CHANGED")
tick()
EQ("buff de cible trouve", d3.act, true)
W.combat = false

SECTION("t_powerauras : SuperWoW (nom sans infobulle)")
reset()
PA_SW(true)
SUI.Api.Detect()
local s1 = add({ kind = "aura", name = "Backlash" })
PA_BUFF("pb", "Peu importe", "Interface\\Icons\\BL", 0, 5)
PA.ids[0] = 777
PA.spellinfo[777] = "Backlash"
calls = PA.tipcalls
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("nom lu par SpellInfo", s1.act, true)
EQ("aucune infobulle lue", PA.tipcalls, calls)
PA_SW(false)
SUI.Api.Detect()

SECTION("t_powerauras : temps de recharge d'un sort")
reset()
PA_SPELLS({ { "Heroic Strike", "Rank 1", "tex_hs" }, { "Shield Wall", "", "tex_sw" }, { "Shield Wall", "Rank 2", "tex_sw2" } })
Fire("SPELLS_CHANGED")
local c1 = add({ kind = "cd", name = "shield wall", when = "ready" })
EQ("sort trouve (dernier rang)", c1.idx, 3)
EQ("sort connu", c1.known, true)
EQ("pret : allumee", c1.act, true)
EQ("icone du grimoire", c1.dtex, "tex_sw2")
EQ("etat : ok", M.StatusOf(c1), "ok")
PA_CD(3, NOW - 10, 30)
tick()
EQ("en recharge : pas prete", c1.act, false)
c1.when = "cool"
M.Cycle(c1, "when", 0)
local c1b = M.alerts[1]
tick()
EQ("declencheur 'en recharge'", c1b.when, "cool")
EQ("en recharge : allumee", c1b.act, true)
NEAR("temps restant", c1b.left, 20, 0.6)
NEAR("fraction restante", c1b.frac, 20 / 30, 0.05)
EQ("texte du temps", c1b.tile.time:GetText(), "20")
-- toujours visible : estompee en recharge
M.Cycle(c1b, "when", 1)
tick()
local c1c = M.alerts[1]
EQ("declencheur 'toujours'", c1c.when, "always")
EQ("toujours : allumee en recharge", c1c.act, true)
EQ("estompee en recharge", c1c.tile.al, 0.45)
PA_CD(3, 0, 0)
tick()
EQ("toujours : allumee quand prete", c1c.act, true)
EQ("plus estompee", c1c.tile.al, 1)
EQ("pas de temps affiche", c1c.tile.time:GetText(), "")
-- delai global ignore
M.Cycle(c1c, "when", -1)
M.Cycle(M.alerts[1], "when", -1)
local c1d = M.alerts[1]
EQ("retour a 'prete'", c1d.when, "ready")
PA_CD(3, NOW, 1.5)
tick()
EQ("delai global de 1,5 s : toujours prete", c1d.act, true)
PA_CD(3, NOW, 8)
tick()
EQ("recharge de 8 s : pas prete", c1d.act, false)
-- sort inconnu
local c2 = add({ kind = "cd", name = "Sort Inconnu" })
EQ("sort inconnu : eteinte", c2.act, false)
EQ("sort inconnu : etat signale", M.StatusOf(c2), "unknown")
-- sort appris plus tard
PA_SPELLS({ { "Sort Inconnu", "", "tex_x" } })
Fire("SPELLS_CHANGED")
tick()
c2 = M.alerts[2]
EQ("sort appris : trouve", c2.known, true)
EQ("sort appris : allumee", c2.act, true)
-- incomplete
local c3 = add({ kind = "cd", name = "" })
EQ("sans nom : etat incomplet", M.StatusOf(c3), "incomplete")
EQ("sans nom : eteinte", c3.act, false)
-- balayage circulaire
PA_SWEEP(true)
reset()
PA_SPELLS({ { "Taunt", "", "tex_t" } })
Fire("SPELLS_CHANGED")
local cs = add({ kind = "cd", name = "Taunt", when = "always" })
PA_CD(1, NOW, 10)
tick()
EQ("balayage lance", getn(PA.sweeps) >= 1, true)
EQ("balayage : debut et duree", PA.sweeps[getn(PA.sweeps)][2], 10)
EQ("modele du jeu affiche", cs.tile.model:IsShown(), true)
C.Set("powerauras.sweep", false)
tick()
EQ("balayage coupe : modele cache", cs.tile.model:IsShown(), false)
EQ("repli : voile qui se vide", cs.tile.shade:IsShown(), true)
C.Set("powerauras.sweep", true)
PA_SWEEP(false)

SECTION("t_powerauras : temps de recharge d'un objet")
reset()
PA_EQUIP(13, "Earthstrike", "tex_es")
PA_BAG(0, 3, "Healing Potion", "tex_pot")
PA.count["Healing Potion"] = 4
local i1 = add({ kind = "cd", item = true, name = "Earthstrike", when = "always" })
local i2 = add({ kind = "cd", item = true, name = "healing potion", when = "always" })
EQ("bijou equipe trouve", i1.inv, 13)
EQ("objet de sac trouve", i2.bag, 0)
EQ("emplacement de sac", i2.slot, 3)
EQ("objet de sac : icone", i2.dtex, "tex_pot")
EQ("bijou : icone", i1.dtex, "tex_es")
EQ("bijou connu", i1.known, true)
EQ("nombre d'objets", i2.cnt, 4)
EQ("nombre d'objets affiche", i2.tile.cnt:GetText(), "4")
PA.equipcd[13] = { NOW - 5, 120 }
PA.bagcd["0:3"] = { NOW - 1, 60 }
tick()
NEAR("recharge du bijou", i1.left, 115, 0.6)
NEAR("recharge de la potion", i2.left, 59, 0.6)
-- l'objet change de place
PA.bags["0:3"] = nil
PA_BAG(1, 2, "Healing Potion", "tex_pot")
PA.bagcd["1:2"] = { NOW - 2, 60 }
Fire("BAG_UPDATE")
tick()
i2 = M.alerts[2]
EQ("objet retrouve apres BAG_UPDATE", i2.bag, 1)
NEAR("recharge suivie au nouvel emplacement", i2.left, 58, 0.6)
-- objet disparu
PA.bags["1:2"] = nil
Fire("BAG_UPDATE")
tick()
EQ("objet disparu : eteinte", M.alerts[2].act, false)
EQ("objet disparu : introuvable", M.StatusOf(M.alerts[2]), "unknown")
-- sans alerte d'objet, BAG_UPDATE ne marque rien
reset()
add({ kind = "cd", name = "Taunt" })
M.dItems = false
Fire("BAG_UPDATE")
EQ("BAG_UPDATE sans alerte d'objet : ignore", M.dItems, false)

SECTION("t_powerauras : barres de ressource et conditions")
reset()
W.units.player.hp, W.units.player.hpMax = 2000, 10000
W.units.player.mana, W.units.player.manaMax = 600, 3000
local p1 = add({ kind = "power", res = "health", disp = "bar", zone = 4 })
local p2 = add({ kind = "power", res = "power", disp = "bar", zone = 4 })
local p3 = add({ kind = "power", res = "combo", unit = "target", disp = "bar", when = "nonzero", zone = 4 })
EQ("barre de vie allumee", p1.act, true)
NEAR("fraction de vie", p1.frac, 0.2, 0.001)
NEAR("barre de vie : valeur", p1.tile.bar:GetValue(), 0.2, 0.001)
EQ("barre de vie : texte", p1.tile.big:GetText(), "Vie 20%")
NEAR("fraction de mana", p2.frac, 0.2, 0.001)
EQ("combo a 0 : eteinte", p3.act, false)
PA.combo = 3
tick()
EQ("combo a 3 : allumee", p3.act, true)
EQ("combo : texte", p3.tile.big:GetText(), "Combo 3")
NEAR("combo : fraction", p3.frac, 0.6, 0.001)
EQ("barre visible", p1.tile.bar:IsShown(), true)
EQ("icone cachee pour une barre de ressource", p1.tile.icon:IsShown(), false)
-- barre d'une cible
reset()
local p4 = add({ kind = "power", res = "health", unit = "target", disp = "bar" })
tick()
EQ("barre de cible sans cible : eteinte", p4.act, false)
MKTARGET({ name = "Boss", hp = 50, hpMax = 100 })
tick()
EQ("barre de cible : allumee", p4.act, true)
NEAR("barre de cible : fraction", p4.frac, 0.5, 0.001)
-- conditions
reset()
W.units.player.hp, W.units.player.hpMax = 9000, 10000
W.units.player.mana, W.units.player.manaMax = 2500, 3000
local k1 = add({ kind = "cond", res = "hplow", thr = 30, disp = "text", vc = "combat" })
local k2 = add({ kind = "cond", res = "manalow", thr = 20, disp = "text" })
local k3 = add({ kind = "cond", res = "targetlow", thr = 20, disp = "text" })
local k4 = add({ kind = "cond", res = "combo", thr = 3, disp = "text" })
W.combat = true
tick()
EQ("vie 90 % : pas d'alerte", k1.act, false)
W.units.player.hp = 2900
tick()
EQ("vie 29 % : alerte", k1.act, true)
EQ("texte de l'alerte", k1.tile.big:GetText(), "Vie basse 29%")
W.units.player.hp = 3000
tick()
EQ("vie 30 % : seuil strict", k1.act, false)
W.combat = false
W.units.player.hp = 1000
tick()
EQ("hors combat : filtre combat", k1.act, false)
EQ("mana 83 % : pas d'alerte", k2.act, false)
W.units.player.mana = 500
tick()
EQ("mana 16 % : alerte", k2.act, true)
W.units.player.ptype = 1
tick()
EQ("rage (pas du mana) : pas d'alerte de mana", k2.act, false)
W.units.player.ptype = 0
EQ("sans cible : pas d'execution", k3.act, false)
MKTARGET({ name = "Boss", hp = 15, hpMax = 100 })
tick()
EQ("cible a 15 % : alerte d'execution", k3.act, true)
W.units.target.canAttack = false
tick()
EQ("cible amicale : pas d'execution", k3.act, false)
W.units.target.canAttack = true
PA.combo = 2
tick()
EQ("combo 2 < 3", k4.act, false)
PA.combo = 4
tick()
EQ("combo 4 >= 3", k4.act, true)
EQ("etiquette par defaut", M.LabelOf(k3), L("mod.powerauras.cond.targetlow"))

SECTION("t_powerauras : visibilite (combat, groupe, classe, specialisation)")
reset()
PA_SPELLS({ { "Taunt", "", "tex_t" } })
Fire("SPELLS_CHANGED")
local v1 = add({ kind = "cd", name = "Taunt", when = "always", vc = "nocombat" })
EQ("hors combat : visible", v1.act, true)
W.combat = true
tick()
EQ("en combat : cachee", v1.act, false)
W.combat = false
v1.vc = "any"
v1.grp = "solo"
M.Save()
v1 = M.alerts[1]
tick()
EQ("seul : visible", v1.act, true)
PA.party = 2
tick()
EQ("en groupe : cachee (seul)", v1.act, false)
v1.grp = "grouped"
M.Save()
v1 = M.alerts[1]
tick()
EQ("en groupe : visible (groupe)", v1.act, true)
v1.grp = "raid"
M.Save()
v1 = M.alerts[1]
tick()
EQ("en groupe : cachee (raid)", v1.act, false)
PA.raid = 10
tick()
EQ("en raid : visible (raid)", v1.act, true)
PA.raid, PA.party = 0, 0
v1.grp = "any"
v1.cls = "MAGE"
M.Save()
v1 = M.alerts[1]
tick()
EQ("autre classe : cachee", v1.act, false)
v1.cls = "WARRIOR"
M.Save()
v1 = M.alerts[1]
tick()
EQ("sa classe : visible", v1.act, true)
-- specialisation
v1.spec = 2
M.Save()
v1 = M.alerts[1]
PA.tabs = { 31, 20, 0 }
Fire("CHARACTER_POINTS_CHANGED")
tick()
EQ("spe 1 dominante, alerte pour la spe 2 : cachee", v1.act, false)
PA.tabs = { 5, 31, 15 }
Fire("CHARACTER_POINTS_CHANGED")
tick()
EQ("spe 2 dominante : visible", v1.act, true)
-- le jeu de talents n'est lu qu'hors combat
PA.tabs = { 31, 20, 0 }
W.combat = true
Fire("CHARACTER_POINTS_CHANGED")
tick()
EQ("lecture des talents differee en combat : inchangee", v1.act, true)
W.combat = false
tick()
EQ("hors combat : relue", v1.act, false)

SECTION("t_powerauras : proc (son, banniere, eclair), declenchement unique")
reset()
local r1 = add({ kind = "aura", name = "Clearcasting", proc = true, snd = "raid", hold = 3, col = "good" })
EQ("banniere preparee", M.banner ~= nil, true)
EQ("eclair prepare", M.flash ~= nil, true)
EQ("banniere cachee au depart", M.banner:IsShown(), false)
PA_BUFF("pb", "Clearcasting", "Interface\\Icons\\CC", 0, 15)
M.quietUntil = GetTime() + 5
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("periode calme : allumee mais rien declenche", r1.act, true)
EQ("periode calme : pas de son", getn(PA.files), 0)
EQ("periode calme : pas de banniere", M.banner:IsShown(), false)
-- nouveau declenchement apres la periode calme
PA_CLEAR()
Fire("PLAYER_AURAS_CHANGED")
tick()
M.quietUntil = 0
PA_BUFF("pb", "Clearcasting", "Interface\\Icons\\CC", 0, 15)
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("proc : un son (fichier)", getn(PA.files), 1)
EQ("proc : le bon fichier", PA.files[1], "Sound\\Interface\\RaidWarning.wav")
EQ("proc : banniere affichee", M.banner:IsShown(), true)
EQ("proc : texte de la banniere", M.banner.text:GetText(), "Clearcasting")
EQ("proc : icone de la banniere", M.banner.icon.calls.SetTexture[1], "interface\\icons\\cc")
EQ("proc : eclair affiche", M.flash:IsShown(), true)
EQ("proc : couleur de l'eclair, opacite discrete", M.flash.tex.vc[4], 0.18)
tick() tick()
EQ("l'aura reste : un seul son", getn(PA.files), 1)
Pump(0.5)
EQ("eclair termine", M.flash:IsShown(), false)
EQ("banniere encore la apres 0,5 s", M.banner:IsShown(), true)
Pump(3.2)
EQ("banniere retiree apres 3 s", M.banner:IsShown(), false)
-- re-declenchement
PA_CLEAR()
Fire("PLAYER_AURAS_CHANGED")
tick()
M.lastSound = -10
PA_BUFF("pb", "Clearcasting", "Interface\\Icons\\CC", 0, 15)
Fire("PLAYER_AURAS_CHANGED")
tick()
EQ("nouvelle apparition : nouveau son", getn(PA.files), 2)
-- reglages : eclair fort, aucun, sons coupes
C.Set("powerauras.flash", "strong")
PA_CLEAR() Fire("PLAYER_AURAS_CHANGED") tick()
M.lastSound = -10
PA_BUFF("pb", "Clearcasting", "Interface\\Icons\\CC", 0, 15)
Fire("PLAYER_AURAS_CHANGED") tick()
EQ("eclair fort", M.flash.tex.vc[4], 0.35)
C.Set("powerauras.flash", "off")
M.flash:Hide()
PA_CLEAR() Fire("PLAYER_AURAS_CHANGED") tick()
M.lastSound = -10
PA_BUFF("pb", "Clearcasting", "Interface\\Icons\\CC", 0, 15)
Fire("PLAYER_AURAS_CHANGED") tick()
EQ("eclair coupe", M.flash:IsShown(), false)
C.Set("powerauras.flash", "soft")
local nf = getn(PA.files)
C.Set("powerauras.sound", false)
PA_CLEAR() Fire("PLAYER_AURAS_CHANGED") tick()
PA_BUFF("pb", "Clearcasting", "Interface\\Icons\\CC", 0, 15)
Fire("PLAYER_AURAS_CHANGED") tick()
EQ("sons coupes : silence", getn(PA.files), nf)
C.Set("powerauras.sound", true)
-- delai minimal entre deux sons
M.lastSound = GetTime()
M.Sound("raid", GetTime())
EQ("deux sons rapproches : un seul", getn(PA.files), nf)
-- les autres sons passent par PlaySound
M.lastSound = -10
M.Sound("ping", GetTime())
EQ("son nomme : PlaySound", PA.sounds[1], "MapPing")
-- test depuis l'editeur
M.lastSound = -10
M.Test(r1)
EQ("Tester : son", getn(PA.files) >= nf + 1, true)
-- une alerte sans proc ne montre pas de banniere au declenchement
reset()
local r2 = add({ kind = "aura", name = "Flurry", snd = "tell" })
PA_BUFF("pb", "Flurry", "Interface\\Icons\\F", 0, 10)
Fire("PLAYER_AURAS_CHANGED")
tick()
M.banner:Hide()
PA_CLEAR() Fire("PLAYER_AURAS_CHANGED") tick()
M.lastSound = -10
PA_BUFF("pb", "Flurry", "Interface\\Icons\\F", 0, 10)
Fire("PLAYER_AURAS_CHANGED") tick()
EQ("son sans proc : le son joue", PA.sounds[table.getn(PA.sounds)], "TellMessage")
EQ("sans proc : pas de banniere", M.banner:IsShown(), false)
-- entree dans le monde : periode calme
Fire("PLAYER_ENTERING_WORLD")
T("entree dans le monde : periode calme", M.quietUntil > GetTime() + 2)

SECTION("t_powerauras : zones, directions, mise en page, deplacement")
reset()
PA_SPELLS({ { "A", "", "ta" }, { "B", "", "tb" }, { "C", "", "tc" } })
Fire("SPELLS_CHANGED")
local z1 = add({ kind = "cd", name = "A", when = "always", zone = 3, size = 40 })
local z2 = add({ kind = "cd", name = "B", when = "always", zone = 3, size = 30 })
local z3 = add({ kind = "cd", name = "C", when = "always", zone = 5, size = 20 })
EQ("zone 3 creee", M.zf[3] ~= nil, true)
EQ("zone 5 creee", M.zf[5] ~= nil, true)
T("zone 3 visible", M.zf[3]:IsShown())
EQ("cadre de zone de taille fixe", M.zf[3]:GetWidth(), M.ZW)
local function pt(a) local p = a.tile.f.points[1]; return p[1], p[3], p[4], p[5] end
local p, rp, x, y = pt(z1)
EQ("zone 3 vers la droite : 1re tuile", p, "TOPLEFT")
EQ("1re tuile en 0", x, 0)
p, rp, x, y = pt(z2)
EQ("2e tuile apres 40 + 4", x, 44)
C.Set("powerauras.spacing", 10)
tick()
p, rp, x, y = pt(z2)
EQ("espacement regle", x, 50)
C.Set("powerauras.spacing", 4)
tick()
EQ("zone 3 : direction par defaut", M.ZoneDir(3), "r")
M.ZoneSet(3, "l")
tick()
p, rp, x, y = pt(M.alerts[2])
EQ("vers la gauche : ancre a droite", p, "TOPRIGHT")
EQ("vers la gauche : decalage negatif", x, -44)
M.ZoneSet(3, "d")
tick()
p, rp, x, y = pt(M.alerts[2])
EQ("vers le bas : ancre en haut", p, "TOPLEFT")
EQ("vers le bas : decalage vertical", y, -44)
M.ZoneSet(3, "u")
tick()
p, rp, x, y = pt(M.alerts[2])
EQ("vers le haut : ancre en bas", p, "BOTTOMLEFT")
EQ("vers le haut : decalage", y, 44)
M.ZoneCycle(3, 1)
EQ("cycle des directions (u -> r)", M.ZoneDir(3), "r")
M.ZoneCycle(3, -1)
EQ("cycle inverse (r -> u)", M.ZoneDir(3), "u")
M.ZoneSet(3, "r")
EQ("direction sauvegardee", string.sub(C.Get("powerauras.zones"), 3, 3), "r")
C.SetBase("powerauras.zones", "xx")
EQ("sauvegarde corrompue : direction par defaut", M.ZoneDir(3), "r")
C.SetBase("powerauras.zones", "rrrddrdd")
-- poignees de deplacement
T("zone enregistree aupres du service de deplacement", SUI.Mover.items["powerauras.z3"] ~= nil)
EQ("poignee : le cadre de la zone", SUI.Mover.items["powerauras.z3"].frame, M.zf[3])
T("zone enregistree dans la mise en page", SUI.Layout.items["powerauras.z3"] ~= nil)
CONTAINS("nom de la poignee", SUI.Mover.Label("powerauras.z3"), "3")
T("banniere deplacable", SUI.Mover.items["powerauras.banner"] ~= nil or M.banner == nil)
-- eteindre la derniere alerte d'une zone cache la zone
z3 = M.alerts[3]
z3.on = false
M.Save()
tick()
EQ("zone 5 videe : cachee", M.zf[5]:IsShown(), false)
EQ("zone 3 toujours visible", M.zf[3]:IsShown(), true)
-- apercu
M.SetDemo(true)
EQ("apercu : alerte coupee non montree", M.alerts[3].shown, false)
M.alerts[3].on = true
M.Save()
M.SetDemo(true)
tick()
EQ("apercu : alerte eteinte montree", M.alerts[3].shown, true)
EQ("apercu : valeurs d'exemple", M.alerts[3].cnt, 3)
M.SetDemo(false)
tick()
EQ("fin d'apercu : alerte eteinte de nouveau", M.alerts[3].shown, true)
M.alerts[3].on = true
-- le mode deplacement montre l'apercu
SUI.Mover.Preview("powerauras.z3", true)
EQ("apercu demande par le service de deplacement", M.demo, true)
SUI.Mover.Preview("powerauras.z3", false)
EQ("apercu coupe", M.demo, false)

SECTION("t_powerauras : formes (icone, barre, texte), couleurs, bordure, lueur")
reset()
PA_SPELLS({ { "A", "", "ta" } })
Fire("SPELLS_CHANGED")
local f1 = add({ kind = "cd", name = "A", when = "always", size = 48, disp = "icon", glow = "pulse", col = "bad" })
EQ("icone : carree", f1.tile.f:GetWidth(), 48)
EQ("icone : hauteur", f1.tile.f:GetHeight(), 48)
EQ("icone : temps visible", f1.tile.time:IsShown(), true)
EQ("icone : pas de texte long", f1.tile.big:IsShown(), false)
EQ("icone : barre cachee", f1.tile.bar:IsShown(), false)
EQ("lueur pulsante affichee", f1.tile.glow:IsShown(), true)
local ga = f1.tile.glow.alpha
Pump(0.4)
T("la lueur pulse", f1.tile.glow.alpha ~= ga)
f1.glow = "none"
M.Save()
tick()
EQ("sans lueur : cachee", M.alerts[1].tile.glow:IsShown(), false)
M.alerts[1].glow = "border"
M.Save()
tick()
EQ("lueur fixe", M.alerts[1].tile.glow:IsShown(), true)
EQ("opacite fixe de la lueur", M.alerts[1].tile.glow.alpha, 0.6)
-- barre
local f2 = M.alerts[1]
f2.disp = "bar"
M.Save()
tick()
f2 = M.alerts[1]
EQ("barre : 4 fois la taille", f2.tile.f:GetWidth(), 192)
EQ("barre : hauteur", f2.tile.f:GetHeight(), 21)
EQ("barre : visible", f2.tile.bar:IsShown(), true)
EQ("barre : icone a gauche", f2.tile.icon:IsShown(), true)
EQ("barre : texte au centre", f2.tile.big:IsShown(), true)
EQ("barre : temps seul cache", f2.tile.time:IsShown(), false)
-- texte
f2.disp = "text"
M.Save()
tick()
f2 = M.alerts[1]
EQ("texte : ligne", f2.tile.f:GetWidth(), 192)
EQ("texte : hauteur", f2.tile.f:GetHeight(), 24)
EQ("texte : ni barre ni icone", f2.tile.bar:IsShown() or f2.tile.icon:IsShown(), false)
EQ("texte : nom", f2.tile.big:GetText(), "A")
-- bordure
f2.disp = "icon"
f2.col = "warn"
M.Save()
tick()
f2 = M.alerts[1]
EQ("bordure de la couleur de l'alerte", f2.tile.f.bbc[1], SUI.Theme.c.warn[1])
C.Set("powerauras.border", "style")
tick()
EQ("bordure du style", f2.tile.f.bbc[1], SUI.Theme.c.border[1])
C.Set("powerauras.border", "none")
tick()
EQ("sans bordure : transparente", f2.tile.f.bbc[4], 0)
C.Set("powerauras.border", "color")
tick()
-- accent suit le changement
f2.col = "accent"
M.Save()
tick()
f2 = M.alerts[1]
local ar = SUI.Theme.Accent()
EQ("couleur d'accent", f2.tile.f.bbc[1], ar)
C.Set("powerauras.alpha", 0.5)
tick()
EQ("opacite generale", f2.tile.f:GetAlpha(), 0.5)
C.Set("powerauras.alpha", 1)
C.Set("powerauras.show", false)
tick()
EQ("alertes masquees : aucune tuile affichee", M.alerts[1].shown, false)
C.Set("powerauras.show", true)
tick()
EQ("alertes de nouveau affichees", M.alerts[1].shown, true)
-- nom affiche
f2 = M.alerts[1]
f2.lb = true
M.Save()
tick()
EQ("nom affiche au-dessus de l'icone", M.alerts[1].tile.name:GetText(), "A")
-- dixiemes
PA_CD(1, NOW - 7, 10)
tick()
NEAR("moins de 3 s restantes : dixiemes", tonumber(M.alerts[1].tile.time:GetText()), 2.75, 0.1)
C.Set("powerauras.tenths", false)
Pump(0.3)
EQ("sans dixiemes : secondes entieres", M.alerts[1].tile.time:GetText(), "3")
C.Set("powerauras.tenths", true)
PA_CD(1, NOW - 40, 130)
tick()
EQ("90 s : en minutes", M.alerts[1].tile.time:GetText(), "1m")

SECTION("t_powerauras : combat (aucune creation), pool, cycle de vie")
reset()
PA_SPELLS({ { "A", "", "ta" } })
Fire("SPELLS_CHANGED")
local l1 = add({ kind = "cd", name = "A", when = "always" })
local ntiles = getn(M.tiles)
W.combat = true
local cc = CREATED
for i = 1, 20 do Pump(0.25) end
EQ("20 rafraichissements en combat : aucune frame creee", CREATED, cc)
-- ajout d'une alerte en combat
local nz = 0
for i = 1, 8 do if nz == 0 and M.zf[i] == nil then nz = i end end
local nal0 = M.nal
M.Add({ kind = "cd", name = "A", zone = (nz > 0) and nz or 6 })
EQ("alerte ajoutee en combat (donnee)", M.nal, nal0 + 1)
for i = 1, 4 do Pump(0.25) end
EQ("en combat : pas de nouvelle tuile ni zone", CREATED, cc)
T("en combat : zone neuve non creee", nz == 0 or M.zf[nz] == nil)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
for i = 1, 4 do Pump(0.25) end
EQ("hors combat : tuiles suffisantes", getn(M.tiles) >= ntiles, true)
EQ("hors combat : la nouvelle alerte s'affiche", M.alerts[2].shown, true)
-- tuiles recyclees
ntiles = getn(M.tiles)
cc = CREATED
M.alerts[2].on = false
M.Save()
tick()
M.alerts[2].on = true
M.Save()
tick()
EQ("reactiver une alerte reutilise une tuile", getn(M.tiles), ntiles)
EQ("aucune frame de plus", CREATED, cc)
-- retirer la derniere alerte coupe tout
M.Clear()
tick()
EQ("plus d'alerte : minuterie annulee", liveTasks("powerauras.tick"), 0)
EQ("plus d'alerte : evenements rendus", hasHandler("UNIT_AURA", M.OnEvent), false)
EQ("plus d'alerte : zones cachees", M.zf[3] == nil or not M.zf[3]:IsShown(), true)
EQ("plus d'alerte : aucune tuile affichee", M.tiles[1].f:IsShown(), false)
-- desactivation du module
add({ kind = "cd", name = "A", when = "always" })
EQ("alerte ajoutee : minuterie relancee", liveTasks("powerauras.tick"), 1)
EQ("alerte ajoutee : evenements ecoutes", hasHandler("UNIT_AURA", M.OnEvent), true)
C.Set("modules.powerauras", false)
SETTLE()
EQ("module coupe : minuterie annulee", liveTasks("powerauras.tick"), 0)
EQ("module coupe : evenements rendus", hasHandler("UNIT_AURA", M.OnEvent), false)
EQ("module coupe : rien d'affiche", M.tiles[1].f:IsShown(), false)
EQ("module coupe : les alertes restent en memoire", M.nal, 1)
-- edition module coupe : la donnee reste coherente
M.Add({ kind = "cd", name = "B" })
EQ("module coupe : ajout possible", M.nal, 2)
EQ("module coupe : toujours aucune minuterie", liveTasks("powerauras.tick"), 0)
EQ("module coupe : indicateur d'etat", M.on, false)
C.Set("modules.powerauras", true)
SETTLE()
EQ("module rallume : minuterie", liveTasks("powerauras.tick"), 1)
-- changement de profil
local before = M.nal
C.NewProfile("PaTest")
C.UseProfile("PaTest")
SETTLE()
EQ("autre profil : aucune alerte", M.nal, 0)
EQ("autre profil : minuterie annulee", liveTasks("powerauras.tick"), 0)
C.UseProfile("Default")
SETTLE()
EQ("profil d'origine : alertes revenues", M.nal, before)
EQ("profil d'origine : minuterie", liveTasks("powerauras.tick"), 1)
-- cadence
C.Set("powerauras.tick", 0.4)
local found = nil
for i = 1, getn(SUI.tasks) do
  if SUI.tasks[i].name == "powerauras.tick" and not SUI.tasks[i].dead then found = SUI.tasks[i] end
end
EQ("cadence reglable", found and found.interval, 0.4)
EQ("une seule minuterie apres changement", liveTasks("powerauras.tick"), 1)
C.Set("powerauras.tick", 0.2)

SECTION("t_powerauras : edition (modeles, copie, suppression, champs, packs)")
reset()
local tp = M.AddTemplate("proc")
T("modele proc", tp ~= nil)
EQ("modele proc : banniere", tp.proc, true)
EQ("modele proc : son", tp.snd, "raid")
EQ("l'editeur s'ouvre sur la nouvelle alerte", M.editId, tp.id)
EQ("modele proc : incomplet jusqu'au nom", M.StatusOf(tp), "incomplete")
for i = 1, getn(M.TEMPLATES) do
  local before2 = M.nal
  local a = M.AddTemplate(M.TEMPLATES[i].id)
  T("modele " .. M.TEMPLATES[i].id .. " cree", a ~= nil and M.nal == before2 + 1)
end
local n0 = M.nal
local cp = M.Copy(tp.id)
EQ("copie : une alerte de plus", M.nal, n0 + 1)
EQ("copie : identifiant distinct", cp.id ~= tp.id, true)
EQ("copie : meme reglage", cp.snd, "raid")
EQ("suppression", M.Remove(cp.id), true)
EQ("suppression : une de moins", M.nal, n0)
EQ("suppression d'une alerte inconnue", M.Remove(9999), false)
-- champs
reset()
local e1 = add({ kind = "aura", name = "X", size = 40 })
M.Cycle(e1, "size", 1)
EQ("taille suivante", M.alerts[1].size, 48)
M.Cycle(M.alerts[1], "size", -1)
M.Cycle(M.alerts[1], "size", -1)
EQ("taille precedente", M.alerts[1].size, 36)
local e2 = M.alerts[1]
e2.size = 96
M.Cycle(e2, "size", 1)
EQ("la liste boucle", M.alerts[1].size, 16)
M.Cycle(M.alerts[1], "disp", 1)
EQ("affichage suivant", M.alerts[1].disp, "bar")
M.Cycle(M.alerts[1], "when", 1)
EQ("declencheur d'aura suivant", M.alerts[1].when, "missing")
M.Toggle(M.alerts[1], "proc")
EQ("bascule d'un booleen", M.alerts[1].proc, true)
M.Cycle(M.alerts[1], "cls", 1)
EQ("classe suivante", M.alerts[1].cls, "WARRIOR")
M.SetName(M.alerts[1], "Nouveau nom", "Interface\\Icons\\Z")
EQ("nom change", M.alerts[1].name, "Nouveau nom")
EQ("icone changee", M.alerts[1].texd, "Interface\\Icons\\Z")
M.SetName(M.alerts[1], "", nil)
EQ("nom vide : icone retiree", M.alerts[1].tex, "")
EQ("nom vide : incomplet", M.alerts[1].incomplete, true)
-- seuil de condition
reset()
local th = add({ kind = "cond", res = "hplow", thr = 30 })
M.Cycle(th, "res", 1)
EQ("source suivante", M.alerts[1].res, "manalow")
M.Cycle(M.alerts[1], "res", 1)
M.Cycle(M.alerts[1], "res", 1)
EQ("source combo : seuil en points", M.alerts[1].res, "combo")
EQ("seuil de combo par defaut", M.alerts[1].thr, 3)
M.Cycle(M.alerts[1], "thr", 1)
EQ("seuil de combo suivant", M.alerts[1].thr, 4)
-- liste des champs
local fa = M.FieldList(M.alerts[1], false)
T("champs essentiels sans visibilite", not M.InList(fa, "cls") and M.InList(fa, "zone"))
fa = M.FieldList(M.alerts[1], true)
T("champs complets avec visibilite", M.InList(fa, "cls") and M.InList(fa, "spec") and M.InList(fa, "vc") and M.InList(fa, "grp"))

reset()
-- packs
EQ("pack conseille : classe et role", M.class, "WARRIOR")
C.cur.role = "tank"
EQ("pack conseille tank", M.Recommended(), "WARRIOR.tank")
C.cur.role = "dps"
EQ("pack conseille degats", M.Recommended(), "WARRIOR.dps")
C.cur.role = "heal"
EQ("pas de soigneur guerrier : premier pack de la classe", M.Recommended(), "WARRIOR.tank")
C.cur.role = nil
local pk = M.PackFind("WARRIOR.tank")
T("pack guerrier tank", pk ~= nil)
local added = M.PackAdd("WARRIOR.tank")
EQ("pack installe", added, getn(pk.alerts))
EQ("alertes du pack presentes", M.nal, getn(pk.alerts))
EQ("compte du pack", M.PackCount("WARRIOR.tank"), getn(pk.alerts))
local again, why2 = M.PackAdd("WARRIOR.tank")
EQ("pack deja installe", why2, "have")
EQ("rien ajoute", M.nal, getn(pk.alerts))
T("pack : alerte de recharge", M.alerts[1].kind == "cd" and M.alerts[1].name == "Shield Block")
EQ("pack : etiquette de pack", M.alerts[1].pack, "WARRIOR.tank")
local gone = M.RemovePack("WARRIOR.tank")
EQ("pack retire", gone, getn(pk.alerts))
EQ("plus d'alerte", M.nal, 0)
local unk, why3 = M.PackAdd("NOPE.none")
EQ("pack inconnu", why3, "none")
-- pack et limite
for i = 1, 22 do M.Add({ kind = "cd", name = "S" .. i }) end
local fullp, why4 = M.PackAdd("WARRIOR.tank")
EQ("pack refuse : place insuffisante", why4, "full")
EQ("rien ajoute", M.nal, 22)
reset()
-- tous les packs : valides, un seul identifiant, 24 alertes au plus
for i = 1, getn(M.PACKS) do
  local p = M.PACKS[i]
  T("pack " .. p.id .. " : taille raisonnable", getn(p.alerts) >= 2 and getn(p.alerts) <= 12)
  local n = M.PackAdd(p.id)
  T("pack " .. p.id .. " : installable", n == getn(p.alerts))
  local okAll = true
  for j = 1, M.nal do
    local a = M.alerts[j]
    if a.pack == p.id and a.kind ~= "power" and a.kind ~= "cond" and a.name == "" then okAll = false end
    if a.pack == p.id and a.incomplete then okAll = false end
  end
  T("pack " .. p.id .. " : alertes completes", okAll)
  M.RemovePack(p.id)
end
EQ("tous les packs retires", M.nal, 0)
-- le pack d'une classe tourne vraiment
C.cur.role = "tank"
M.PackAdd("WARRIOR.tank")
PA_SPELLS({ { "Shield Wall", "", "tex_sw" }, { "Taunt", "", "tex_t" } })
Fire("SPELLS_CHANGED")
tick()
local sw = nil
for i = 1, M.nal do if M.alerts[i].name == "Shield Wall" then sw = M.alerts[i] end end
EQ("pack : Shield Wall connu et affiche", sw and sw.shown, true)
local sb = nil
for i = 1, M.nal do if M.alerts[i].name == "Shield Block" then sb = M.alerts[i] end end
EQ("pack : Shield Block inconnu signale", M.StatusOf(sb), "unknown")
C.cur.role = nil
reset()

SECTION("t_powerauras : page du menu")
local Mn = SUI.Menu
C.SetGlobal("firstRun", false)
Mn.Show("all")
Mn.Open("cat", "powerauras")
T("page de la categorie", Mn.page == "cat" and Mn.cat == "powerauras")
local function btnByLabel(txt)
  for i = 1, Mn.used.pa_btn do
    if Mn.pools.pa_btn[i].label:GetText() == txt then return Mn.pools.pa_btn[i] end
  end
  return nil
end
local function btnsByLabel(txt)
  local t = {}
  for i = 1, Mn.used.pa_btn do
    if Mn.pools.pa_btn[i].label:GetText() == txt then table.insert(t, Mn.pools.pa_btn[i]) end
  end
  return t
end
Mn.Render()
EQ("aucune erreur interne a l'affichage", SUI.errCount, 0)
T("modeles proposes", btnByLabel(L("mod.powerauras.tpl.proc")) ~= nil)
EQ("10 modeles", getn(M.TEMPLATES), 10)
T("pack conseille propose", btnsByLabel(L("mod.powerauras.pack.add")) ~= nil and getn(btnsByLabel(L("mod.powerauras.pack.add"))) >= 3)
EQ("8 zones proposees", getn(btnsByLabel(L("mod.powerauras.zone.line", 1, L("mod.powerauras.dir.r"), 0))) >= 1, true)
-- infobulle d'un bouton
local tb = btnByLabel(L("mod.powerauras.tpl.proc"))
Hover(tb, true)
T("infobulle du modele", GameTooltip.lines ~= nil and GameTooltip.lines[1] == L("mod.powerauras.tpl.proc"))
Hover(tb, false)
-- ajouter un modele
Click(tb)
EQ("modele ajoute", M.nal, 1)
EQ("editeur ouvert", M.editId, M.alerts[1].id)
local edits = Mn.pools.pa_edit
EQ("une zone de saisie", Mn.used.pa_edit, 1)
-- saisie du nom
local ed = edits[1].edit
ed:SetText("Reaction")
EQ("saisie memorisee", M.edit.name, "Reaction")
this = ed
ed.scripts.OnEnterPressed()
EQ("Entree applique le nom", M.alerts[1].name, "Reaction")
EQ("alerte complete", M.StatusOf(M.alerts[1]), "ok")
-- champs cycles : taille
local sizeBtn = btnByLabel(M.FieldText(M.alerts[1], "size"))
T("bouton de taille", sizeBtn ~= nil)
local sz0 = M.alerts[1].size
Click(sizeBtn)
EQ("clic gauche : valeur suivante", M.alerts[1].size > sz0, true)
sizeBtn = btnByLabel(M.FieldText(M.alerts[1], "size"))
sizeBtn:Click("RightButton")
EQ("clic droit : valeur precedente", M.alerts[1].size, sz0)
-- booleen : proc
local procBtn = btnByLabel(M.FieldText(M.alerts[1], "proc"))
Click(procBtn)
EQ("bouton booleen", M.alerts[1].proc, false)
-- vue Essentiel : pas de visibilite
Mn.SetMode("essential")
Mn.Render()
T("essentiel : pas de classe", btnByLabel(M.FieldText(M.alerts[1], "cls")) == nil)
Mn.SetMode("all")
Mn.Render()
T("complet : classe", btnByLabel(M.FieldText(M.alerts[1], "cls")) ~= nil)
-- liste : couper, copier, supprimer
local onB = btnsByLabel(L("mod.powerauras.on"))
T("bouton actif de la liste", getn(onB) >= 1)
Click(onB[1])
EQ("alerte coupee depuis la liste", M.alerts[1].on, false)
local cpB = btnsByLabel(L("mod.powerauras.copy"))
Click(cpB[1])
EQ("alerte copiee depuis la liste", M.nal, 2)
local delB = btnsByLabel(L("mod.powerauras.del"))
Click(delB[1])
EQ("suppression : premier clic ne supprime pas", M.nal, 2)
delB = btnsByLabel(L("menu.confirm"))
T("bouton de confirmation", getn(delB) == 1)
Click(delB[1])
EQ("suppression confirmee", M.nal, 1)
-- liste des auras actuelles
M.editId = M.alerts[1].id
M.alerts[1].on = true
M.Save()
Mn.Render()
PA_BUFF("pb", "Mark of the Wild", "Interface\\Icons\\MW", 0, 600)
PA_BUFF("pb", "Thorns", "Interface\\Icons\\TH", 0, 300)
local pickOpen = btnByLabel(L("mod.powerauras.pick.open"))
T("bouton de liste d'auras", pickOpen ~= nil)
Click(pickOpen)
EQ("liste ouverte", M.pick, true)
local mw = btnByLabel("Mark of the Wild")
T("aura proposee", mw ~= nil)
T("seconde aura proposee", btnByLabel("Thorns") ~= nil)
Click(mw)
EQ("aura choisie : nom", M.alerts[1].name, "Mark of the Wild")
EQ("aura choisie : icone", M.alerts[1].tex, "interface/icons/mw")
EQ("liste refermee", M.pick, false)
EQ("saisie mise a jour", M.edit.name, "Mark of the Wild")
-- test et fin
local testB = btnByLabel(L("mod.powerauras.test"))
M.alerts[1].snd = "ping"
M.Save()
M.lastSound = -10
Mn.Render()
Click(btnByLabel(L("mod.powerauras.test")))
EQ("Tester : son joue", PA.sounds[table.getn(PA.sounds)], "MapPing")
Click(btnByLabel(L("mod.powerauras.done")))
EQ("Terminer ferme le formulaire", M.editId, 0)
-- packs
local addB = btnsByLabel(L("mod.powerauras.pack.add"))
local before3 = M.nal
Click(addB[1])
T("pack installe depuis la page", M.nal > before3)
T("message de pack", string.find(CHATTEXT(), "alerte", 1, true) ~= nil)
local rmB = btnsByLabel(L("mod.powerauras.pack.remove"))
local nrm = M.nal
for i = 1, getn(rmB) do Click(rmB[i]) end
T("packs retires depuis la page", M.nal < nrm)
-- tous les packs
Click(btnByLabel(L("mod.powerauras.packs.every")))
EQ("tous les packs", M.allPacks, true)
EQ("tous les packs affiches", getn(btnsByLabel(L("mod.powerauras.pack.add"))), getn(M.PACKS))
Click(btnByLabel(L("mod.powerauras.packs.mine")))
EQ("seulement la classe", M.allPacks, false)
-- zones
local zb = btnByLabel(L("mod.powerauras.zone.line", 1, L("mod.powerauras.dir.r"), M.ZoneCount(1)))
T("bouton de zone", zb ~= nil)
Click(zb)
EQ("zone 1 : direction suivante", M.ZoneDir(1), "l")
zb = btnByLabel(L("mod.powerauras.zone.line", 1, L("mod.powerauras.dir.l"), M.ZoneCount(1)))
zb:Click("RightButton")
EQ("zone 1 : clic droit, direction precedente", M.ZoneDir(1), "r")
-- apercu
add({ kind = "cd", name = "Z" })
Mn.Render()
local dmB = btnByLabel(L("mod.powerauras.demo.start"))
T("bouton d'apercu", dmB ~= nil)
Click(dmB)
EQ("apercu actif", M.demo, true)
T("bouton de fin d'apercu", btnByLabel(L("mod.powerauras.demo.stop")) ~= nil)
Click(btnByLabel(L("mod.powerauras.demo.stop")))
EQ("apercu coupe", M.demo, false)
-- tout supprimer
local clB = btnByLabel(L("mod.powerauras.clear"))
Click(clB)
EQ("tout supprimer : confirmation", M.nal >= 1, true)
Click(btnByLabel(L("menu.confirm")))
EQ("tout supprime", M.nal, 0)
Mn.Render()
T("liste vide : aide affichee", Mn.used.pa_lbl == 0 or Mn.used.pa_lbl >= 0)
-- module coupe : avertissement mais page utilisable
C.Set("modules.powerauras", false)
Mn.Render()
T("module coupe : modeles proposes quand meme", btnByLabel(L("mod.powerauras.tpl.buff")) ~= nil)
C.Set("modules.powerauras", true)
-- mode combat : aucune creation
Mn.Render()
W.combat = true
local cm = CREATED
Mn.Render()
EQ("rendu en combat : aucune frame creee", CREATED, cm)
W.combat = false
Mn.Hide()

SECTION("t_powerauras : textes, commande")
-- toutes les cles dynamiques existent
local missing = {}
local function chk(key)
  if L(key) == key then table.insert(missing, key) end
end
for i = 1, getn(M.KINDS) do chk("mod.powerauras.k." .. M.KINDS[i]) end
chk("mod.powerauras.name.aura") chk("mod.powerauras.name.cd") chk("mod.powerauras.name.label")
chk("mod.powerauras.name.cd.item")
for f, list in pairs(M.ENUM) do
  if f ~= "kind" and f ~= "cls" then
    for i = 1, getn(list) do chk("mod.powerauras.v." .. f .. "." .. list[i]) end
  end
end
for k, list in pairs(M.WHEN) do for i = 1, getn(list) do chk("mod.powerauras.v.when." .. list[i]) end end
for k, list in pairs(M.RES) do for i = 1, getn(list) do chk("mod.powerauras.v.res." .. list[i]) end end
for i = 1, getn(M.ENUM.cls) do chk("choice.powerauras.cls." .. M.ENUM.cls[i]) end
for i = 1, getn(M.F) do
  local nm = M.F[i][2]
  if nm == "unit" or nm == "filt" or nm == "when" or nm == "res" or nm == "thr" or nm == "disp" or nm == "zone" or nm == "size" or nm == "glow"
    or nm == "snd" or nm == "proc" or nm == "col" or nm == "minst" or nm == "dur" or nm == "tm" or nm == "sk" or nm == "lb" or nm == "hold"
    or nm == "vc" or nm == "grp" or nm == "cls" or nm == "spec" then
    chk("mod.powerauras.f." .. nm)
    chk("tip.powerauras.f." .. nm)
  end
end
for i = 1, getn(M.TEMPLATES) do chk("mod.powerauras.tpl." .. M.TEMPLATES[i].id); chk("tip.powerauras.tpl." .. M.TEMPLATES[i].id) end
for i = 1, getn(M.PACKS) do chk("mod.powerauras.role." .. M.PACKS[i].role) end
for i = 1, getn(M.DIRS) do chk("mod.powerauras.dir." .. M.DIRS[i]) end
for _, s in ipairs({ "off", "incomplete", "unknown" }) do chk("mod.powerauras.st." .. s) end
chk("mod.powerauras.st.long.incomplete")
chk("mod.powerauras.st.long.unknown")
chk("mod.powerauras.cond.hplow") chk("mod.powerauras.cond.manalow") chk("mod.powerauras.cond.targetlow") chk("mod.powerauras.cond.combo")
for _, v in ipairs({ "off", "soft", "strong" }) do chk("choice.powerauras.flash." .. v) end
for _, v in ipairs({ "color", "style", "none" }) do chk("choice.powerauras.border." .. v) end
EQ("aucune cle de texte manquante", table.concat(missing, ", "), "")
-- champs : chaque etiquette de champ cycle sur chaque valeur sans erreur de texte
reset()
local tx = add({ kind = "aura", name = "T" })
local ok = true
for i = 1, getn(M.FieldList(tx, true)) do
  local fld = M.FieldList(tx, true)[i]
  local s = M.FieldText(tx, fld)
  if string.find(s, "mod.powerauras", 1, true) then ok = false; print("  texte brut: " .. s) end
end
T("libelles des champs complets", ok)
-- commande
reset()
local cmd = SUI.commands.powerauras
T("commande enregistree", cmd ~= nil)
CHATCLEAR()
cmd.fn("list")
CONTAINS("liste vide", CHATTEXT(), L("msg.powerauras.none"))
CHATCLEAR()
cmd.fn("pack WARRIOR.dps")
CONTAINS("pack installe par commande", CHATTEXT(), "Pack")
T("alertes du pack", M.nal > 3)
CHATCLEAR()
cmd.fn("pack WARRIOR.dps")
CONTAINS("pack deja installe", CHATTEXT(), L("msg.powerauras.pack.have"))
CHATCLEAR()
cmd.fn("pack nope")
CONTAINS("pack inconnu", CHATTEXT(), "nope")
CHATCLEAR()
cmd.fn("list")
CONTAINS("liste : premiere ligne", CHATTEXT(), "1.")
cmd.fn("demo")
EQ("apercu par commande", M.demo, true)
cmd.fn("demo")
EQ("apercu coupe par commande", M.demo, false)
M.lastSound = -10
PA.sounds, PA.files = {}, {}
cmd.fn("test 1")
T("test par commande : banniere", M.banner:IsShown())
cmd.fn("off")
EQ("commande off", mod.enabled, false)
cmd.fn("on")
EQ("commande on", mod.enabled, true)
CHATCLEAR()
cmd.fn("pack")
CONTAINS("pack conseille par defaut", CHATTEXT(), L("msg.powerauras.pack.have"))
EQ("aucune erreur interne a la fin", SUI.errCount, 0)

DONE()
