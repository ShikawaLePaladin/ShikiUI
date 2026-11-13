-- t_charstats : module "charstats" (panneaux de statistiques sur le modele du builder OctoFan : 9 panneaux, 3 affiches, presets de
-- classe et de role memorises par personnage, formules du builder, lecture equipement / talents, valeurs estimees "~", infobulles,
-- evenements, options, modes). Les cas figes de la section "builder" viennent de tests/bench_builder.js (--emit-lua).
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.CharStats
local R = M.Rules

CS_SETUP()
W.combat = true
BOOT()
SETTLE()

local function near(a, b) return math.abs(a - b) < 0.0001 end
local function cmd(s) SlashCmdList["SHIKIUI"](s) end

SECTION("t_charstats : formules du builder")
-- valeurs calculees avec les fonctions du builder (missChanceVsSkill, dualWieldMissChance, ...)
EQ("echec jaune : competence = defense", R.MissVsSkill(315, 0), 5)
EQ("echec jaune : competence 300", R.MissVsSkill(300, 0), 8)
T("echec jaune : le toucher retire", near(R.MissVsSkill(305, 2), 5))
T("echec jaune : 0,2 par point au-dessus", near(R.MissVsSkill(330, 0), 2))
EQ("echec jaune : plancher a 0", R.MissVsSkill(400, 0), 0)
EQ("echec jaune : plafond a 60", R.MissVsSkill(0, 0), 60)
EQ("deux armes : +19", R.DualMiss(300, 0), 27)
EQ("deux armes : le builder borne l'echec a une main avant d'ajouter 19", R.DualMiss(300, 10), 19)
EQ("deux armes : plafond a 60", R.DualMiss(0, 0), 60)
EQ("esquive adverse : competence 315", R.BossDodge(315), 5)
EQ("esquive adverse : competence 300", R.BossDodge(300), 6.5)
EQ("esquive adverse : plancher a 0", R.BossDodge(400), 0)
EQ("coup partiel : 300", R.Glance(300), 65)
EQ("coup partiel : 305", R.Glance(305), 75)
T("coup partiel : 310", near(R.Glance(310), 85))
EQ("coup partiel : 315", R.Glance(315), 92)
EQ("coup partiel : 320", R.Glance(320), 95)
EQ("critique : -3 a 300", R.CritAdjust(300), -3)
EQ("critique : -3 a 315 (pas au-dessus)", R.CritAdjust(315), -3)
T("critique : +0,04 par point au-dessus de 315", near(R.CritAdjust(320), 0.2))
T("critique : -0,2 par point sous 300", near(R.CritAdjust(250), -13))
T("plafond critique", near(R.CritCap(300, 4, false), 49.5))
T("plafond critique a deux armes", near(R.CritCap(300, 4, true), 30.5))
T("evitement : -0,2 par niveau", near(R.Avoid(5.5, 3), 4.9))
EQ("evitement : plancher a 0", R.Avoid(0.3, 3), 0)
T("evitement total", near(R.TotalAvoid(5, 5.5, 6.25, 0, 3), 15.75))
EQ("valeur de blocage", R.BlockValue(120, 18), 23)
EQ("valeur de blocage : plancher a 0", R.BlockValue(0, 0), 0)
T("mana de l'esprit / 5 s (paladin)", near(R.SpiritMana5("PALADIN", 50), 62.5))
T("mana de l'esprit / 5 s (pretre)", near(R.SpiritMana5("PRIEST", 280), 206.25))
EQ("mana de l'esprit : classe sans mana", R.SpiritMana5("WARRIOR", 50), 0)
T("critique des sorts (paladin)", near(R.SpellCrit("PALADIN", 100, 60), 3.7 + 100 / (14.77 + 0.65 * 60)))
EQ("critique des sorts : classe sans formule", R.SpellCrit("WARRIOR", 100, 60), 0)
EQ("toucher des sorts : boss niveau 63", R.SpellBase(3), 83)
EQ("toucher des sorts : meme niveau", R.SpellBase(0), 96)
EQ("toucher des sorts : plancher a 33", R.SpellBase(10), 33)
EQ("toucher des sorts : borne a 99", R.SpellHit(0, 10), 99)
EQ("toucher des sorts : borne a 1", R.SpellHit(10, -100), 1)

SECTION("t_charstats : construction hors combat")
local mod = SUI.modules.charstats
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "medium")
EQ("module actif", mod and mod.enabled, true)
EQ("combat : pas de panneau", M.panel, nil)
EQ("combat : pas de minuterie", M.task, nil)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
EQ("construit apres le combat", M.built, true)
T("panneau cree", M.panel ~= nil)
EQ("quarante lignes pre-creees", table.getn(M.lines), 40)
EQ("aucune erreur interne", SUI.errCount, 0)
EQ("le panneau est enfant de l'onglet Personnage (PaperDollFrame)", M.panel.parent, PaperDollFrame)
EQ("le bouton Stats est sur l'onglet Personnage", M.btn.parent, PaperDollFrame)
T("le bouton Stats existe meme volet cache", M.btn:IsShown())
T("une minuterie", M.task ~= nil)
EQ("fenetre fermee : panneau non visible", M.panel:IsVisible(), false)
EQ("fenetre fermee : aucun calcul", CS.calls.stats, 0)
Pump(0.6, 3)
EQ("fenetre fermee : la minuterie ne calcule pas", CS.calls.stats, 0)
EQ("fenetre fermee : aucune lecture d'infobulle", CS.calls.gear, 0)

SECTION("t_charstats : equipement et talents")
CS.gear[1] = { "Casque", "Equip: Improves your chance to hit by 2%." }
CS.gear[2] = { "Collier", "Equip: Increases damage and healing done by magical spells and effects by up to 30." }
CS.gear[3] = { "Epaulettes", "Equip: Increases damage done by Fire spells and effects by up to 20." }
CS.gear[4] = { "Cape", "Equip: Restores 6 mana per 5 sec." }
CS.gear[5] = { "Torse", "Equip: Improves your chance to get a critical strike with spells by 1%.", "Equip: Increases healing done by spells and effects by up to 55." }
CS.gear[6] = { "Gants", "Equip: Decreases the magical resistances of your spell targets by 15." }
CS.gear[7] = { "Bottes", "Equip: Your attacks ignore 200 of the target's armor." }
CS.gear[8] = { "Anneau", "Equip: Increases your spell haste by 3%.", "Equip: Increases casting speed by 1%." }
CS.gear[19] = { "Ceinture", "Equip: Improves your chance to hit with spells by 1%." }
CS.talents = {
  { name = "Precision", rank = 2, lines = { "Precision", "Rank 2/3", "Increases your chance to hit with melee weapons by 2%.", "Next rank:", "Increases your chance to hit with melee weapons by 3%." } },
  { name = "Meditation", rank = 1, lines = { "Meditation", "Rank 1/3", "Allows 15% of your mana regeneration to continue while casting." } },
  { name = "Inconnu", rank = 0, lines = { "Inconnu", "Rank 0/1", "Increases your chance to hit with melee weapons by 9%." } },
  { name = "Sorts", rank = 1, lines = { "Sorts", "Rank 1/2", "Increases your chance to hit with spells by 0%." } },
}
CharacterFrame:Show()
Pump(0.6)
EQ("fenetre ouverte : le panneau calcule", CS.calls.gear > 0, true)
EQ("toucher : objets + talents (le rang suivant est ignore)", M.S.hit, 4)
EQ("toucher des sorts : objets", M.gear.shit, 1)
EQ("critique des sorts : objets", M.gear.scrit, 1)
EQ("puissance des sorts", M.S.sp, 30)
EQ("soins = soins + puissance", M.S.heal, 85)
EQ("la puissance de feu seule n'est plus comptee", M.gear.sp, 30)
EQ("mana / 5 s des objets", M.S.mp5, 6)
EQ("penetration des sorts", M.gear.spen, 15)
EQ("penetration d'armure", M.gear.apen, 200)
EQ("hate (deux formulations)", M.gear.haste, 4)
EQ("talent de regeneration en lancant", M.tal.casting, 15)
EQ("talent de rang 0 ignore", M.tal.hit, 2)
EQ("pas de bouclier", M.S.shield, false)
EQ("aucune erreur", SUI.errCount, 0)

SECTION("t_charstats : preset de classe (paladin) et valeurs affichees")
EQ("role automatique", M.sel.role, "auto")
EQ("sections du preset paladin", M.sel.sec.meleeBoss and M.sel.sec.defenseBoss and M.sel.sec.base, true)
EQ("pas d'autre section", M.sel.sec.ranged, nil)
local lbl, v
lbl, v = CS_ROW("skillb"); EQ("competence d'arme (melee + bonus)", v, "300")
EQ("libelle du builder", lbl, "Competence d'arme")
lbl, v = CS_ROW("miss"); EQ("% de rater : estime", v, "~4%")
EQ("libelle % de rater", lbl, "% de rater")
EQ("pas de ligne d'attaques speciales a une arme", CS_ROW("missS"), nil)
lbl, v = CS_ROW("needS"); EQ("toucher requis (formule, pas estime)", v, "8%")
EQ("pas de ligne coups blancs a une arme", CS_ROW("needW"), nil)
lbl, v = CS_ROW("bdodge"); EQ("esquive adverse", v, "6.5%")
lbl, v = CS_ROW("glance"); EQ("coup partiel", v, "65%")
lbl, v = CS_ROW("critcap"); EQ("plafond critique", v, "~49.5%")
lbl, v = CS_ROW("criteff"); EQ("critique effectif", v, "~2.5%")
lbl, v = CS_ROW("armor"); EQ("armure", v, "3000")
lbl, v = CS_ROW("defense"); EQ("defense", v, "305")
lbl, v = CS_ROW("dodgeb"); EQ("esquive contre un boss", v, "4.9%")
lbl, v = CS_ROW("parryb"); EQ("parade contre un boss", v, "5.65%")
lbl, v = CS_ROW("blockb"); EQ("pas de bouclier : pas de blocage", v, "-")
lbl, v = CS_ROW("totalb"); EQ("total contre un boss", v, "15.75%")
EQ("pas de valeur de blocage sans bouclier", CS_ROW("bval"), nil)
lbl, v = CS_ROW("str"); EQ("force effective", v, "120")
lbl, v = CS_ROW("spi"); EQ("esprit", v, "50")
local nb = 0
for k = 1, M.nv do if M.lines[k].kind == "R" and M.lines[k].p == "base" then nb = nb + 1 end end
EQ("six lignes de base", nb, 6)

CS_PANELS("melee", "spell", "heal")
lbl, v = CS_ROW("skill"); EQ("melee : competence", v, "300")
lbl, v = CS_ROW("dmg"); EQ("melee : degats", v, "100 - 200")
EQ("melee : libelle des degats", lbl, "Degats")
lbl, v = CS_ROW("spd"); EQ("melee : vitesse", v, "2.60")
lbl, v = CS_ROW("dps"); EQ("melee : dps des coups blancs", v, "58")
lbl, v = CS_ROW("ap"); EQ("melee : puissance d'attaque = base + bonus + malus", v, "240")
lbl, v = CS_ROW("hit"); EQ("melee : toucher estime", v, "~4%")
lbl, v = CS_ROW("crit"); EQ("melee : critique lu", v, "5.5%")
lbl, v = CS_ROW("sp"); EQ("sorts : puissance estimee", v, "~30")
lbl, v = CS_ROW("shit"); EQ("sorts : toucher estime", v, "~1%")
lbl, v = CS_ROW("sbhit"); EQ("sorts : toucher vs boss", v, "~84%")
EQ("sorts : libelle", lbl, "Toucher sorts vs boss (niv. 63)")
lbl, v = CS_ROW("sneed"); EQ("sorts : toucher manquant", v, "~15%")
lbl, v = CS_ROW("scrit"); EQ("sorts : critique estime (intelligence + objets)", v, "~6.56%")
lbl, v = CS_ROW("healb"); EQ("sorts : soin ameliore", v, "~85")
lbl, v = CS_ROW("mp5"); EQ("sorts : mana / 5 s des objets", v, "~6")
lbl, v = CS_ROW("haste"); EQ("sorts : hate", v, "~4%")
lbl, v = CS_ROW("hpow"); EQ("soins : puissance de soins", v, "~85")
lbl, v = CS_ROW("hcrit"); EQ("soins : critique", v, "~6.56%")
lbl, v = CS_ROW("manamax", "heal"); EQ("soins : mana max", v, "3000")
lbl, v = CS_ROW("regout"); EQ("soins : regeneration hors combat", v, "~69")
lbl, v = CS_ROW("regin"); EQ("soins : regeneration en lancant", v, "~15")
CS_PANELS("misc", "ranged", "defense")
lbl, v = CS_ROW("hp"); EQ("divers : vie max", v, "5000")
lbl, v = CS_ROW("res"); EQ("divers : resistances feu / nature / givre / ombre / arcane", v, "10 / 20 / 30 / 40 / 50")
lbl, v = CS_ROW("spen"); EQ("divers : penetration des sorts", v, "~15")
lbl, v = CS_ROW("apen"); EQ("divers : penetration d'armure", v, "~200")
EQ("divers : regeneration presente (classe a mana)", CS_ROW("regout") ~= nil, true)
lbl, v = CS_ROW("norange"); EQ("distance : pas d'arme", lbl, "Aucune arme a distance equipee")
local nr = 0
for k = 1, M.nv do if M.lines[k].kind == "R" and M.lines[k].p == "ranged" then nr = nr + 1 end end
EQ("distance : une seule ligne", nr, 1)
lbl, v = CS_ROW("dodge"); EQ("defense : esquive", v, "5.5%")
lbl, v = CS_ROW("parry"); EQ("defense : parade", v, "6.25%")
lbl, v = CS_ROW("block"); EQ("defense : pas de bouclier", v, "-")
lbl, v = CS_ROW("total"); EQ("defense : total", v, "16.95%")
CS.rspeed, CS.rmin, CS.rmax, CS.rskill, CS.rap, CS.rcrit = 2.9, 600, 830, { 300, 8 }, { 1000, 300, 100 }, 24.25
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("rskill"); EQ("distance : competence (base + bonus)", v, "308")
lbl, v = CS_ROW("rdmg"); EQ("distance : degats", v, "600 - 830")
lbl, v = CS_ROW("rspd"); EQ("distance : vitesse", v, "2.90")
lbl, v = CS_ROW("rap"); EQ("distance : puissance d'attaque", v, "1400")
lbl, v = CS_ROW("rhit"); EQ("distance : toucher estime", v, "~4%")
lbl, v = CS_ROW("rcrit"); EQ("distance : critique lu", v, "24.25%")
EQ("aucune erreur", SUI.errCount, 0)

SECTION("t_charstats : bouclier, deux armes")
CS.gear[17] = { "Bouclier", "Off Hand", "20 Block", "Equip: Increases the block value of your shield by 10." }
CS.right[17] = { "", "Shield" }
CS.offSpeed = 1.5
CS.offskill = { 290, 5 }
CS.omin, CS.omax = 40, 70
M.gearDirty, M.dirty = true, true
CS_PANELS("meleeBoss", "defense", "defenseBoss")
Pump(0.6)
EQ("bouclier detecte", M.S.shield, true)
EQ("bouclier : pas de deux armes", M.S.dual, false)
lbl, v = CS_ROW("block", "defense"); EQ("bouclier : blocage affiche", v, "12%")
lbl, v = CS_ROW("total", "defense"); EQ("bouclier : total avec le blocage", v, "28.95%")
lbl, v = CS_ROW("bval", "defense"); EQ("valeur de blocage : bouclier + objets + force / 20 - 1", v, "~35")
lbl, v = CS_ROW("blockb"); EQ("blocage contre un boss", v, "11.4%")
lbl, v = CS_ROW("bval", "defenseBoss"); EQ("valeur de blocage aussi dans les defenses vs boss", v, "~35")
lbl, v = CS_ROW("totalb"); EQ("total contre un boss avec le blocage", v, "27.15%")
EQ("bouclier : pas de ligne coups blancs", CS_ROW("needW"), nil)
CS.gear[17] = nil
CS.right[17] = nil
M.gearDirty, M.dirty = true, true
CS_PANELS("melee", "meleeBoss", "base")
Pump(0.6)
EQ("deux armes detectees", M.S.dual, true)
lbl, v = CS_ROW("skill"); EQ("deux armes : competences MD | MG", v, "300 | 295")
lbl, v = CS_ROW("dmg2"); EQ("deux armes : degats MD | MG", v, "100-200 | 40-70")
EQ("deux armes : libelle des degats", lbl, "Degats MD | MG")
lbl, v = CS_ROW("spd2"); EQ("deux armes : vitesses", v, "2.60 | 1.50")
EQ("deux armes : libelle de la vitesse", lbl, "Vitesse MD | MG")
lbl, v = CS_ROW("dps"); EQ("deux armes : dps des deux mains", v, "94")
lbl, v = CS_ROW("miss"); EQ("deux armes : % de rater", v, "~23%")
lbl, v = CS_ROW("missS"); EQ("deux armes : rater en attaque speciale", v, "~4%")
lbl, v = CS_ROW("needW"); EQ("deux armes : toucher requis coups blancs", v, "27%")
lbl, v = CS_ROW("critcap"); EQ("deux armes : plafond critique", v, "~30.5%")
CS.offSpeed = nil
M.dirty = true
Pump(0.6)
EQ("une arme de nouveau", M.S.dual, false)
EQ("aucune erreur", SUI.errCount, 0)

SECTION("t_charstats : sections, lignes et role, memorises par personnage")
local key = C.CharKey()
local function secs()
  local t = {}
  for i = 1, table.getn(M.PANELS) do if M.sel.sec[M.PANELS[i]] then table.insert(t, M.PANELS[i]) end end
  return table.concat(t, ",")
end
M.SetRole("auto")
EQ("preset paladin apres role auto (ordre du volet)", secs(), "base,meleeBoss,defenseBoss")
local L1 = CS_LINES()
EQ("premiere ligne : titre de la premiere section", L1[1], "H:base")
EQ("sections dans l'ordre du volet : base d'abord", L1[2], "R:str")
EQ("titre de section affiche", M.lines[1].label:GetText(), SUI.L("msg.charstats.p_base"))
EQ("un titre n'a pas de valeur", M.lines[1].value:GetText(), "")
EQ("bouton de role", M.roBtn.label:GetText(), SUI.L("msg.charstats.role", SUI.L("msg.charstats.ro_auto")))
EQ("bouton Choisir", M.edBtn.label:GetText(), SUI.L("msg.charstats.choose"))
-- sections activees / desactivees
EQ("basculer une section", M.ToggleSection("melee"), true)
EQ("section ajoutee", M.sel.sec.melee, true)
T("ses lignes apparaissent", CS_ROW("crit", "melee") ~= nil)
M.ToggleSection("melee")
EQ("section retiree", M.sel.sec.melee, nil)
EQ("ses lignes disparaissent", CS_ROW("crit", "melee"), nil)
EQ("section inconnue refusee", M.ToggleSection("zzz"), false)
-- lignes masquees
EQ("masquer une ligne", M.ToggleRow("base", "armor"), true)
EQ("ligne masquee", CS_ROW("armor", "base"), nil)
T("la meme ligne d'une autre section reste", CS_ROW("armor", "defenseBoss") ~= nil)
EQ("ligne inconnue refusee", M.ToggleRow("base", "zzz"), false)
M.ToggleRow("base", "armor")
T("ligne reaffichee", CS_ROW("armor", "base") ~= nil)
-- mode Choisir
M.OnEditClick()
EQ("mode Choisir actif", M.edit, true)
EQ("bouton Terminer", M.edBtn.label:GetText(), SUI.L("msg.charstats.done"))
local n = 0
for i = 1, M.nv do if M.lines[i].kind == "H" then n = n + 1 end end
EQ("mode Choisir : les neuf sections sont listees", n, 9)
local ln
for i = 1, M.nv do if M.lines[i].kind == "R" and M.lines[i].key == "agi" then ln = M.lines[i] end end
EQ("mode Choisir : case cochee", ln.value:GetText(), "[x]")
this = ln
ln.scripts.OnClick()
EQ("clic sur une ligne : masquee", M.sel.off["base.agi"], true)
for i = 1, M.nv do if M.lines[i].kind == "R" and M.lines[i].key == "agi" then ln = M.lines[i] end end
EQ("case decochee", ln.value:GetText(), "[ ]")
this = ln
ln.scripts.OnClick()
EQ("deuxieme clic : reaffichee", M.sel.off["base.agi"], nil)
local hd
for i = 1, M.nv do if M.lines[i].kind == "H" and M.lines[i].p == "ranged" then hd = M.lines[i] end end
EQ("section non activee : case vide", hd.value:GetText(), "[ ]")
this = hd
hd.scripts.OnClick()
EQ("clic sur un titre : section activee", M.sel.sec.ranged, true)
this = hd
hd.scripts.OnClick()
EQ("clic sur un titre : section retiree", M.sel.sec.ranged, nil)
M.OnEditClick()
EQ("mode Choisir termine", M.edit, false)
this = ln
ln.scripts.OnClick()
EQ("hors mode Choisir, un clic ne fait rien", M.sel.off["base.agi"], nil)
-- memorisation
M.ToggleRow("base", "spi")
local rec = C.db.global.charstats and C.db.global.charstats[key]
T("choix ecrit dans la configuration", type(rec) == "table")
EQ("memorise : role", rec and rec.role, "auto")
EQ("memorise : section", rec and rec.sec.base, true)
EQ("memorise : ligne masquee", rec and rec.off["base.spi"], true)
M.sel.sec, M.sel.off, M.sel.role = {}, {}, "x"
M.LoadSel()
EQ("relu : section", M.sel.sec.base, true)
EQ("relu : ligne masquee", M.sel.off["base.spi"], true)
EQ("relu : role", M.sel.role, "auto")
M.ToggleRow("base", "spi")

local PRE = { tank = "base,meleeBoss,defenseBoss", melee = "base,melee,meleeBoss", ranged = "base,meleeBoss,ranged", caster = "base,spell,misc",
  healer = "base,heal,misc" }
for _, r in ipairs({ "tank", "melee", "ranged", "caster", "healer" }) do
  EQ("role " .. r .. " : valide", M.SetRole(r), true)
  EQ("role " .. r .. " : les sections", secs(), PRE[r])
end
EQ("bouton de role mis a jour", M.roBtn.label:GetText(), SUI.L("msg.charstats.role", SUI.L("msg.charstats.ro_healer")))
M.OnRoleClick(M.roBtn, "LeftButton")
EQ("clic gauche sur le role : suivant (soigneur -> auto)", M.sel.role, "auto")
M.OnRoleClick(M.roBtn, "RightButton")
EQ("clic droit sur le role : precedent (auto -> soigneur)", M.sel.role, "healer")
M.SetRole("tank")
M.ToggleRow("base", "str")
M.SetRole("tank")
EQ("un role remet les lignes masquees a zero", M.sel.off["base.str"], nil)
EQ("role inconnu refuse", M.SetRole("zzz"), false)

-- preset auto selon la classe
local U = W.units.player
for cls, want in pairs({ WARRIOR = "base,meleeBoss,defenseBoss", ROGUE = "base,melee,meleeBoss", HUNTER = "base,meleeBoss,ranged",
  SHAMAN = "base,melee,spell", DRUID = "base,melee,spell", MAGE = "base,spell,misc", WARLOCK = "base,spell,misc", PRIEST = "base,heal,misc",
  PALADIN = "base,meleeBoss,defenseBoss", ZZZ = "base,melee,defense" }) do
  U.class = cls
  M.SetRole("auto")
  EQ("preset auto : " .. cls, secs(), want)
end
U.class = "PALADIN"
-- un autre personnage a ses propres choix
M.SetRole("healer")
U.name = "Autre"
M.LoadSel()
EQ("autre personnage : role automatique", M.sel.role, "auto")
EQ("autre personnage : preset de la classe", secs(), "base,meleeBoss,defenseBoss")
M.SetRole("caster")
U.name = "Shikiwa"
M.LoadSel()
EQ("premier personnage retrouve son role", M.sel.role, "healer")
EQ("premier personnage retrouve ses sections", secs(), PRE.healer)
U.name = "Autre"
M.LoadSel()
EQ("second personnage retrouve son role", M.sel.role, "caster")
U.name = "Shikiwa"
-- enregistrement abime
C.db.global.charstats[key] = { role = "zzz", sec = { base = true, zzz = true, spell = 5 }, off = { ["base.str"] = true, ["zzz.str"] = true, ["base.zzz"] = true, ["base.agi"] = 7, [3] = true } }
M.LoadSel()
EQ("role invalide : automatique", M.sel.role, "auto")
EQ("section valide conservee, invalides ignorees", secs(), "base")
EQ("ligne masquee valide conservee", M.sel.off["base.str"], true)
EQ("ligne masquee invalide ignoree", M.sel.off["zzz.str"], nil)
EQ("ligne inconnue ignoree", M.sel.off["base.zzz"], nil)
EQ("valeur non booleenne ignoree", M.sel.off["base.agi"], nil)
-- ancien format (trois panneaux p1..p3)
C.db.global.charstats[key] = { role = "tank", p1 = "bad", p2 = 5, p3 = "spell" }
M.LoadSel()
EQ("ancien format : role", M.sel.role, "tank")
EQ("ancien format : panneau valide conserve", secs(), "spell")
C.db.global.charstats = "oops"
M.LoadSel()
EQ("table de configuration abimee : preset", secs(), "base,meleeBoss,defenseBoss")
M.SetRole("tank")
EQ("table reparee a l'ecriture", type(C.db.global.charstats), "table")
EQ("table reparee : role", C.db.global.charstats[key].role, "tank")
-- commandes
CHATCLEAR()
cmd("stats role healer")
EQ("commande role", M.sel.role, "healer")
cmd("stats section ranged")
EQ("commande section", M.sel.sec.ranged, true)
cmd("stats section ranged")
EQ("commande section : retrait", M.sel.sec.ranged, nil)
CHATCLEAR()
cmd("stats role zzz")
CONTAINS("commande role invalide : usage", CHATTEXT(), "Usage")
CHATCLEAR()
cmd("stats section zzz")
CONTAINS("commande section invalide : usage", CHATTEXT(), "Usage")
cmd("stats reset")
EQ("commande reset", M.sel.role, "auto")
CHATCLEAR()
cmd("charstats list")
CONTAINS("liste : titre de section", CHATTEXT(), SUI.L("msg.charstats.p_meleeboss"))
CONTAINS("liste : une ligne", CHATTEXT(), "Competence d'arme : 300")
CONTAINS("liste : une ligne estimee", CHATTEXT(), "% de rater : ~4%")
EQ("aucune erreur", SUI.errCount, 0)

SECTION("t_charstats : infobulles")
CS_PANELS("meleeBoss", "melee", "base")
local gt = GameTooltip
local r
lbl, v, r = CS_ROW("hit")
this = r
r.scripts.OnEnter()
EQ("infobulle : titre = libelle", gt.lines[1], "% de toucher")
EQ("infobulle d'une valeur estimee : explication", gt.lines[2], SUI.L("msg.charstats.t_hit"))
EQ("infobulle d'une valeur estimee : legende", gt.lines[3], SUI.L("msg.charstats.t_est"))
EQ("infobulle ancree a la ligne", gt.owner, r)
EQ("infobulle montree", gt.shown, true)
r.scripts.OnLeave()
EQ("infobulle cachee", gt.shown, false)
lbl, v, r = CS_ROW("crit")
this = r
r.scripts.OnEnter()
EQ("valeur lue : fonction du jeu", gt.lines[2], SUI.L("msg.charstats.t_read", "GetCritChance"))
EQ("valeur lue : pas de legende d'estimation", gt.lines[3], nil)
lbl, v, r = CS_ROW("glance")
this = r
r.scripts.OnEnter()
EQ("valeur calculee : explication de la formule", gt.lines[2], SUI.L("msg.charstats.t_boss"))
lbl, v, r = CS_ROW("miss")
this = r
r.scripts.OnEnter()
EQ("valeur calculee avec un toucher estime", gt.lines[2], SUI.L("msg.charstats.t_hitdep"))
this = nil
local created = CREATED
M.RowEnter()
EQ("survol sans ligne : rien", gt.lines[2], SUI.L("msg.charstats.t_hitdep"))
EQ("aucune creation d'objet pour les infobulles", CREATED, created)

SECTION("t_charstats : fonctions optionnelles du client etendu")
CS_PANELS("spell", "heal", "misc")
CS_NATIVE("GetSpellCritChance", function() return 9.5 end)
CS_NATIVE("GetSpellBonusDamage", function(s) return 100 + s end)
CS_NATIVE("GetSpellBonusHealing", function() return 400 end)
CS_NATIVE("GetManaRegen", function() return 10, 4 end)
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("scrit"); EQ("critique des sorts lu", v, "9.5%")
lbl, v = CS_ROW("sp"); EQ("puissance des sorts lue (minimum des ecoles 2 a 7)", v, "102")
lbl, v = CS_ROW("healb"); EQ("soins lus", v, "400")
lbl, v = CS_ROW("regout"); EQ("regeneration lue (par seconde x 5)", v, "50")
lbl, v = CS_ROW("regin"); EQ("regeneration en lancant lue", v, "20")
lbl, v, r = CS_ROW("scrit")
this = r
r.scripts.OnEnter()
EQ("infobulle d'une valeur lue", gt.lines[2], SUI.L("msg.charstats.t_read", "GetSpellCritChance"))
CS_NATIVE("GetSpellCritChance", function() error("boom") end)
CS_NATIVE("GetSpellBonusDamage", function() return nil end)
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("scrit"); EQ("fonction en erreur : retour a l'estimation", v, "~6.56%")
lbl, v = CS_ROW("sp"); EQ("fonction sans valeur : retour a l'estimation", v, "~30")
EQ("aucune erreur interne malgre la fonction en erreur", SUI.errCount, 0)
CS_NATIVE("GetSpellCritChance", nil)
CS_NATIVE("GetSpellBonusDamage", nil)
CS_NATIVE("GetSpellBonusHealing", nil)
CS_NATIVE("GetManaRegen", nil)
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("regout"); EQ("fonctions retirees : regeneration estimee", v, "~69")
-- classe sans mana
U.class = "WARRIOR"
U.manaMax, U.ptype = 0, 1
M.lastMana = nil
M.dirty = true
Pump(0.6)
EQ("classe sans mana : pas de regeneration dans les divers", CS_ROW("regout", "misc"), nil)
lbl, v = CS_ROW("manamax", "heal"); EQ("classe sans mana : mana max absent", v, "-")
U.class, U.manaMax, U.ptype = "PALADIN", 3000, 0
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("manamax", "heal"); EQ("mana max lu", v, "3000")
-- druide en forme animale : derniere valeur de mana conservee
U.ptype, U.manaMax = 1, 100
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("manamax", "heal"); EQ("forme animale : derniere valeur de mana", v, "3000")
U.ptype, U.manaMax = 0, 3000

SECTION("t_charstats : evenements")
CS_PANELS("base", "melee", "defense")
local calls = CS.calls.stats
Pump(0.6, 4)
EQ("rien de neuf : aucun recalcul", CS.calls.stats, calls)
CS.stat[1] = { 100, 200 }
Fire("UNIT_STATS", "party1")
Pump(0.6)
lbl, v = CS_ROW("str"); EQ("evenement d'un autre joueur ignore", v, "120")
Fire("UNIT_STATS", "player")
Pump(0.6)
lbl, v = CS_ROW("str"); EQ("evenement du joueur : valeur relue", v, "200")
local g = CS.calls.gear
CS.gear[19] = { "Ceinture", "Equip: Improves your chance to hit with spells by 3%." }
Fire("UNIT_INVENTORY_CHANGED", "player")
CS_PANELS("spell", "melee", "defense")
Pump(0.6)
EQ("equipement change : relu", CS.calls.gear > g, true)
lbl, v = CS_ROW("shit"); EQ("toucher des sorts relu", v, "~3%")
g = CS.calls.gear
Fire("UNIT_INVENTORY_CHANGED", "party2")
Pump(0.6)
EQ("equipement d'un autre : ignore", CS.calls.gear, g)
local tl = CS.calls.talent
Fire("CHARACTER_POINTS_CHANGED", -1)
CS.talents[1].rank = 3
Pump(0.6)
EQ("talents changes : relus", CS.calls.talent > tl, true)
EQ("talent de rang 3", M.tal.hit, 2)
U.hpMax = 6000
Fire("UNIT_MAXHEALTH", "player")
CS_PANELS("misc", "melee", "defense")
Pump(0.6)
lbl, v = CS_ROW("hp"); EQ("vie max relue", v, "6000")
U.hpMax = 5000

SECTION("t_charstats : options")
CS_PANELS("melee", "defense", "base")
lbl, v = CS_ROW("crit"); EQ("2 decimales : zeros de fin retires", v, "5.5%")
C.Set("charstats.dec", 0)
lbl, v = CS_ROW("crit"); EQ("0 decimale", v, "6%")
C.Set("charstats.dec", 1)
lbl, v = CS_ROW("crit"); EQ("1 decimale", v, "5.5%")
CS.crit = 5.56
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("crit"); EQ("1 decimale : arrondi", v, "5.6%")
C.Set("charstats.dec", 2)
CS.crit = -0.001
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("crit"); EQ("zero negatif affiche 0", v, "0%")
CS.crit = 5.5
M.dirty = true
Pump(0.6)
EQ("a droite : le volet est ancre au coin haut droit de la fenetre", M.panel.points[1][1], "TOPLEFT")
EQ("a droite : relatif a la fenetre du personnage", M.panel.points[1][2], CharacterFrame)
EQ("a droite : sur son bord droit", M.panel.points[1][3], "TOPRIGHT")
EQ("a droite : colle (marge du cadre habille moins 2)", M.panel.points[1][4], -28)
EQ("a droite : meme hauteur que le cadre habille", M.panel.points[1][5], -10)
C.Set("charstats.side", "left")
EQ("cote gauche", M.panel.points[1][1], "TOPRIGHT")
EQ("cote gauche : sur le bord gauche", M.panel.points[1][3], "TOPLEFT")
C.Set("charstats.side", "right")
EQ("cote droit", M.panel.points[1][1], "TOPLEFT")
EQ("bouton Stats ancre a la fenetre", M.btn.points[1][2], CharacterFrame)
C.Set("charstats.width", 300)
EQ("largeur du volet", M.panel:GetWidth(), 300)
EQ("ligne ancree aux deux bords (largeur suit le volet)", M.lines[1].points[2][3], "TOPRIGHT")
C.Set("charstats.width", 290)
C.Set("charstats.show", false)
EQ("panneau cache", M.panel:IsShown(), false)
EQ("le bouton Stats reste visible", M.btn:IsShown(), true)
this = M.btn
M.btn.scripts.OnClick()
this = nil
EQ("le bouton Stats rouvre le volet", C.Get("charstats.show"), true)
C.Set("charstats.show", false)
C.Set("charstats.show", true)
EQ("panneau montre", M.panel:IsShown(), true)
cmd("stats")
EQ("commande sans argument : bascule", C.Get("charstats.show"), false)
cmd("stats")
EQ("commande : rebascule", C.Get("charstats.show"), true)
EQ("anciennes options retirees", C.Get("charstats.tlevel"), nil)
EQ("aucune erreur", SUI.errCount, 0)

SECTION("t_charstats : mode Raid")
EQ("normal : mise a jour en combat", C.Get("charstats.combat"), true)
EQ("normal : panneaux montres", C.Get("charstats.show"), true)
SUI.Mode.Set("raid", "manual")
EQ("raid : pas de mise a jour en combat", C.Get("charstats.combat"), false)
EQ("raid : le volet RESTE affiche (cause du volet invisible)", C.Get("charstats.show"), true)
EQ("raid : le panneau est affiche", M.panel:IsShown(), true)
CS_PANELS("base", "melee", "defense")
W.combat = true
CS.stat[2] = { 80, 111 }
Fire("UNIT_STATS", "player")
Pump(0.6, 2)
lbl, v = CS_ROW("agi"); EQ("raid + combat : valeur figee", v, "90")
W.combat = false
Pump(0.6)
lbl, v = CS_ROW("agi"); EQ("sortie de combat : valeur relue", v, "111")
C.Set("charstats.show", false)
local calc = CS.calls.stats
CS.stat[2] = { 80, 150 }
Fire("UNIT_STATS", "player")
Pump(0.6, 3)
EQ("raid, panneaux caches : aucun calcul", CS.calls.stats, calc)
SUI.Mode.Set("normal", "manual")
EQ("retour au mode normal", C.Get("charstats.combat"), true)
EQ("retour au mode normal : volet montre", C.Get("charstats.show"), true)
Pump(0.6)
lbl, v = CS_ROW("agi"); EQ("retour : valeur relue a la reapparition", v, "150")

SECTION("t_charstats : erreurs jamais avalees, diagnostic")
M.SetRole("auto")
CS_PANELS("melee", "ranged", "defense")
Pump(0.6)
local e0 = SUI.errCount
local oldRanged = rawget(_G, "UnitRangedAttack")
rawset(_G, "UnitRangedAttack", function() error("boom ranged") end)
M.dirty = true
Pump(0.6)
EQ("un groupe en panne : erreur rapportee a SUI.Report", SUI.errCount, e0 + 1)
local last = SUI.errlog[table.getn(SUI.errlog)]
CONTAINS("journal persistant : source", last, "charstats ranged")
CONTAINS("journal persistant : message", last, "boom ranged")
CONTAINS("derniere erreur gardee pour le diagnostic", M.lastErr, "boom ranged")
lbl, v = CS_ROW("crit", "melee"); EQ("les autres groupes continuent (melee)", v, "5.5%")
lbl, v = CS_ROW("dodge", "defense"); EQ("les autres groupes continuent (defense)", v, "5.5%")
M.dirty = true
Pump(0.6)
EQ("meme erreur : pas de rapport en double", SUI.errCount, e0 + 1)
rawset(_G, "UnitRangedAttack", oldRanged)
M.dirty = true
Pump(0.6)
-- une valeur dont le calcul echoue : "?" et rapport
local specv = M.ROWS.crit.v
M.ROWS.crit.v = function() error("boom valeur") end
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("crit", "melee"); EQ("valeur en erreur : point d'interrogation", v, "?")
CONTAINS("valeur en erreur : journal", SUI.lastErr, "boom valeur")
M.ROWS.crit.v = specv
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("crit", "melee"); EQ("valeur retablie", v, "5.5%")
-- script en erreur : protege
local en = M.RowEnter
M.RowEnter = function() error("boom script") end
local ln2 = M.lines[2]
this = ln2
ln2.scripts.OnEnter()
this = nil
M.RowEnter = en
CONTAINS("script en erreur : journal", SUI.lastErr, "boom script")
SUI.errCount = 0
-- diagnostic
CHATCLEAR()
cmd("stats diag")
local ct = CHATTEXT()
CONTAINS("diag : module actif", ct, SUI.L("msg.charstats.d_module", SUI.L("msg.charstats.d_yes"), SUI.L("msg.charstats.d_yes"), "normal", SUI.L("msg.charstats.d_no")))
CONTAINS("diag : fenetre trouvee", ct, "Fenetre du personnage trouvee : oui | volet construit : oui | parent : PaperDollFrame")
CONTAINS("diag : ancrage", ct, "TOPLEFT/TOPRIGHT -28,-10")
CONTAINS("diag : derniere erreur", ct, "boom script")
local d = M.Diag()
T("diag : plusieurs lignes", table.getn(d) >= 5)
-- module coupe : la commande explique au lieu de se taire
C.Set("modules.charstats", false)
CHATCLEAR()
cmd("stats")
CONTAINS("module coupe : message", CHATTEXT(), SUI.L("msg.charstats.notready"))
CONTAINS("module coupe : diagnostic", CHATTEXT(), "actif non")
CONTAINS("module coupe : comment l'activer", CHATTEXT(), "/sui stats on")
cmd("stats on")
EQ("stats on : module actif", C.Get("modules.charstats"), true)
EQ("stats on : volet voulu", C.Get("charstats.show"), true)
EQ("stats on : le module tourne", SUI.modules.charstats.enabled, true)
CHATCLEAR()
cmd("stats")
CONTAINS("bascule : etat annonce", CHATTEXT(), SUI.L("msg.charstats.state_off"))
CharacterFrame:Hide()
CHATCLEAR()
cmd("stats")
CONTAINS("bascule : fenetre fermee, rappel", CHATTEXT(), SUI.L("msg.charstats.open_char"))
EQ("volet rouvert", C.Get("charstats.show"), true)
CharacterFrame:Show()
Pump(0.6)
SUI.errCount = 0

SECTION("t_charstats : creation et cycle de vie")
created = CREATED
for i = 1, 5 do
  M.dirty = true
  Pump(0.6)
end
M.SetRole("healer")
M.SetRole("tank")
M.ToggleSection("ranged")
M.OnEditClick()
M.OnEditClick()
EQ("aucune creation de cadre en rafraichissant ni en changeant de panneau", CREATED, created)
local oldTask = M.task
C.Set("modules.charstats", false)
EQ("coupe : minuterie annulee", oldTask.dead, true)
EQ("coupe : plus de minuterie", M.task, nil)
EQ("coupe : panneau cache", M.panel:IsShown(), false)
C.Set("modules.charstats", true)
T("rallume : une minuterie", M.task ~= nil)
EQ("rallume : panneau montre", M.panel:IsShown(), true)
EQ("rallume : pas de second panneau", M.built, true)
EQ("rallume : la selection est conservee", M.sel.role, "tank")
C.Set("ui.locale", "en")
M.layoutDirty = true
M.dirty = true
CS_PANELS("meleeBoss", "defenseBoss", "base")
Pump(0.6)
EQ("anglais : etiquette", (CS_ROW("miss")), "% to miss")
EQ("anglais : titre", M.lines[1].label:GetText(), "Base stats")
EQ("anglais : role", M.roBtn.label:GetText(), "Role: Tank")
EQ("anglais : bouton", M.btn.label:GetText(), "Stats")
C.Set("ui.locale", "fr")
M.Touch()
EQ("francais : etiquette", (CS_ROW("miss")), "% de rater")
EQ("aucune erreur finale", SUI.errCount, 0)

SECTION("t_charstats : visibilite commune et engrenage")
local function gearCheck(label, parent, cat, titleKey)
  local g = parent and parent.suiGears and parent.suiGears[1]
  T(label .. " : engrenage cree", g ~= nil)
  if not g then return end
  EQ(label .. " : parent", g.suiGearParent, parent)
  EQ(label .. " : categorie", g.gearCat, cat)
  EQ(label .. " : titre", g.gearTitle, SUI.L(titleKey))
  T(label .. " : niveau au-dessus du contenu", g:GetFrameLevel() >= parent:GetFrameLevel() + 2)
  local shown
  local keep = SUI.Menu.Show
  SUI.Menu.Show = function(a) shown = a end
  Click(g)
  SUI.Menu.Show = keep
  EQ(label .. " : le clic ouvre la page du module", shown, cat)
end
local V = SUI.Visibility
T("options de visibilite declarees", C.meta["charstats.vis"] ~= nil and C.meta["charstats.fade"] ~= nil)
T("volet enregistre", V.byFrame[M.panel] ~= nil)
EQ("par defaut : volet montre", M.panel:IsShown(), true)
C.Set("charstats.vis", "never")
EQ("regle 'jamais' : volet cache", M.panel:IsShown(), false)
EQ("le bouton Stats reste affiche", M.btn:IsShown(), true)
C.Set("charstats.vis", "always")
Pump(0.1, 8)
EQ("regle levee : volet montre", M.panel:IsShown(), true)
C.Set("charstats.show", false)
C.Set("charstats.vis", "never")
C.Set("charstats.vis", "always")
Pump(0.1, 8)
EQ("volet coupe par le joueur : reste cache malgre la regle", M.panel:IsShown(), false)
C.Set("charstats.show", true)
EQ("volet reclame : montre", M.panel:IsShown(), true)
gearCheck("engrenage", M.par, "charstats", "msg.charstats.gear")
T("engrenage conserve dans le module", M.gearBtn == M.par.suiGears[1])
EQ("engrenage ancre au bouton Stats", M.gearBtn.points[1][2], M.btn)
EQ("engrenage affiche", M.gearBtn:IsShown(), true)
local gb, ph = M.gearBtn, M.panel
C.Set("modules.charstats", false)
SETTLE()
EQ("coupe : engrenage cache", gb:IsShown(), false)
EQ("coupe : volet retire du service", V.byFrame[ph], nil)
C.Set("modules.charstats", true)
SETTLE()
EQ("rallume : engrenage affiche", gb:IsShown(), true)
T("rallume : volet de nouveau enregistre", V.byFrame[ph] ~= nil)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_charstats : repli sans fonctions de chances du client")
local savedG = { crit = CS.gear[9] }
CS.gear[9] = { "Gants", "Equip: Improves your chance to get a critical strike by 2%.", "Equip: Increases your chance to dodge an attack by 1%.",
  "Equip: Increases your chance to parry an attack by 1%.", "Equip: Increases your chance to block attacks with a shield by 1%." }
local savedFn = { crit = GetCritChance, rcrit = GetRangedCritChance, dodge = GetDodgeChance, parry = GetParryChance, block = GetBlockChance }
CS_NATIVE("GetCritChance", nil); CS_NATIVE("GetRangedCritChance", nil); CS_NATIVE("GetDodgeChance", nil)
CS_NATIVE("GetParryChance", nil); CS_NATIVE("GetBlockChance", nil)
W.units.player.class = "WARRIOR"
CS.stat = { { 100, 100 }, { 100, 100 }, { 100, 100 }, { 100, 100 }, { 100, 100 } }
CS.defense = { 300, 10 }
M.gearDirty = true
C.Set("modules.charstats", true)
CS_PANELS("melee", "defense", "ranged")
M.edit = false
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("crit"); EQ("critique sans API : estime (agilite + objets)", v, "~7%")
lbl, v = CS_ROW("dodge"); EQ("esquive sans API : estimee (jamais 0)", v, "~7.15%")
lbl, v = CS_ROW("parry"); EQ("parade sans API : estimee", v, "~6.4%")
T("critique sans API : infobulle d'estimation", M.IsEst(M.ROWS.crit))
EQ("critique : drapeau lu faux", M.S.critRead, false)
CS_NATIVE("GetCritChance", savedFn.crit); CS_NATIVE("GetRangedCritChance", savedFn.rcrit); CS_NATIVE("GetDodgeChance", savedFn.dodge)
CS_NATIVE("GetParryChance", savedFn.parry); CS_NATIVE("GetBlockChance", savedFn.block)
M.dirty = true
Pump(0.6)
lbl, v = CS_ROW("crit"); EQ("critique avec API : valeur lue, sans ~", v, "5.5%")
EQ("critique : drapeau lu vrai", M.S.critRead, true)
CS.gear[9] = savedG.crit
M.gearDirty = true

SECTION("t_charstats : cas du builder (valeurs figees)")
-- FROZEN-BEGIN (genere par tests/bench_builder.js --splice : cas et lignes attendues du builder, a ne pas editer a la main)
local function apply(c)
  CS.stat = { {c.str,c.str}, {c.agi,c.agi}, {c.sta,c.sta}, {c.int,c.int}, {c.spi,c.spi} }
  CS.armor = c.armor
  CS.res = { 0, c.res[1], c.res[2], c.res[3], c.res[4], c.res[5] }
  CS.ap = {c.ap,0,0}; CS.rap = {c.rap,0,0}; CS.crit = c.crit; CS.rcrit = c.rcrit
  CS.skill = {c.skill,0}; CS.offskill = {c.oskill,0}; CS.speed = c.speed; CS.offSpeed = c.offSpeed
  CS.dmin, CS.dmax, CS.omin, CS.omax = c.dmin, c.dmax, c.omin, c.omax
  CS.rspeed, CS.rmin, CS.rmax, CS.rskill = c.rspeed, c.rmin, c.rmax, {c.rskill,0}
  CS.defense = {c.defense,0}; CS.dodge, CS.parry, CS.block = c.dodge, c.parry, c.block
  W.units.player.class = c.cls
  W.units.player.hpMax = c.hp
  W.units.player.manaMax = c.mana
  W.units.player.ptype = (c.mana > 0) and 0 or 1
  M.lastMana = nil
  CS.gear = {}
  CS.right = {}
  local lines = {}
  if c.hit > 0 then table.insert(lines, "Equip: Improves your chance to hit by " .. c.hit .. "%.") end
  if c.shit > 0 then table.insert(lines, "Equip: Improves your chance to hit with spells by " .. c.shit .. "%.") end
  if c.spcrit > 0 then table.insert(lines, "Equip: Improves your chance to get a critical strike with spells by " .. c.spcrit .. "%.") end
  if c.sp > 0 then table.insert(lines, "Equip: Increases damage and healing done by magical spells and effects by up to " .. c.sp .. ".") end
  if c.heal - c.sp > 0 then table.insert(lines, "Equip: Increases healing done by spells and effects by up to " .. (c.heal - c.sp) .. ".") end
  if c.mp5 > 0 then table.insert(lines, "Equip: Restores " .. c.mp5 .. " mana per 5 sec.") end
  if c.haste > 0 then table.insert(lines, "Equip: Increases your spell haste by " .. c.haste .. "%.") end
  if c.spen > 0 then table.insert(lines, "Equip: Decreases the magical resistances of your spell targets by " .. c.spen .. ".") end
  if c.apen > 0 then table.insert(lines, "Equip: Your attacks ignore " .. c.apen .. " of the target's armor.") end
  if table.getn(lines) > 0 then CS.gear[1] = lines end
  if c.shield then
    CS.gear[17] = { "Bouclier", "Off Hand", (c.blockFlat > 0) and (c.blockFlat .. " Block") or "0 Armor" }
    CS.right[17] = { "", "Shield" }
  end
  CS.talents = {}
  if c.regenCast > 0 then
    CS.talents[1] = { name = "Meditation", rank = 1, lines = { "Meditation", "Rank 1/1", "Allows " .. c.regenCast .. "% of your mana regeneration to continue while casting." } }
  end
  M.gearDirty, M.talentDirty = true, true
end

local CASES = {
  {cls="PALADIN",lvl=60,str=120,agi=90,sta=160,int=100,spi=50,armor=3000,ap=240,rap=0,crit=5.5,rcrit=0,skill=300,oskill=0,speed=2.6,offSpeed=nil,dmin=100,dmax=200,omin=0,omax=0,rspeed=0,rmin=0,rmax=0,rskill=0,hit=4,shit=1,spcrit=1,sp=30,heal=85,mp5=6,regenCast=15,haste=0,shield=true,blockFlat=18,spen=0,apen=0,defense=330,dodge=7,parry=9,block=17,res={10,20,30,40,50},hp=5000,mana=3000,name="paladin_tank"},
  {cls="WARRIOR",lvl=60,str=300,agi=150,sta=350,int=40,spi=45,armor=2200,ap=1800,rap=500,crit=21.3,rcrit=14.2,skill=308,oskill=302,speed=2.6,offSpeed=1.5,dmin=250,dmax=300,omin=70,omax=120,rspeed=2.2,rmin=90,rmax=140,rskill=300,hit=9,shit=0,spcrit=0,sp=0,heal=0,mp5=0,regenCast=0,haste=0,shield=false,blockFlat=0,spen=0,apen=250,defense=300,dodge=6,parry=6.5,block=0,res={10,20,30,40,50},hp=5000,mana=0,name="warrior_dual"},
  {cls="ROGUE",lvl=60,str=90,agi=380,sta=160,int=30,spi=40,armor=3000,ap=1300,rap=0,crit=28.7,rcrit=0,skill=315,oskill=315,speed=1.8,offSpeed=1.4,dmin=90,dmax=170,omin=60,omax=100,rspeed=0,rmin=0,rmax=0,rskill=0,hit=12,shit=0,spcrit=0,sp=0,heal=0,mp5=0,regenCast=0,haste=0,shield=false,blockFlat=0,spen=0,apen=0,defense=300,dodge=29,parry=8,block=0,res={10,20,30,40,50},hp=5000,mana=0,name="rogue_dagger_hit"},
  {cls="HUNTER",lvl=60,str=120,agi=330,sta=160,int=120,spi=60,armor=3000,ap=240,rap=1400,crit=18,rcrit=24.3,skill=300,oskill=0,speed=2.8,offSpeed=nil,dmin=80,dmax=140,omin=0,omax=0,rspeed=2.9,rmin=600,rmax=830,rskill=308,hit=5,shit=0,spcrit=0,sp=0,heal=0,mp5=4,regenCast=0,haste=0,shield=false,blockFlat=0,spen=0,apen=0,defense=300,dodge=15,parry=0,block=0,res={10,20,30,40,50},hp=6400,mana=4200,name="hunter_bow"},
  {cls="PRIEST",lvl=60,str=120,agi=90,sta=190,int=330,spi=280,armor=900,ap=20,rap=0,crit=3,rcrit=0,skill=300,oskill=0,speed=2,offSpeed=nil,dmin=40,dmax=60,omin=0,omax=0,rspeed=0,rmin=0,rmax=0,rskill=0,hit=0,shit=2,spcrit=3,sp=120,heal=640,mp5=18,regenCast=25,haste=0,shield=false,blockFlat=0,spen=10,apen=0,defense=300,dodge=3,parry=0,block=0,res={10,20,30,40,50},hp=4300,mana=9100,name="priest_heal"},
  {cls="MAGE",lvl=60,str=120,agi=90,sta=170,int=360,spi=150,armor=3000,ap=240,rap=0,crit=2,rcrit=0,skill=300,oskill=0,speed=2,offSpeed=nil,dmin=30,dmax=50,omin=0,omax=0,rspeed=0,rmin=0,rmax=0,rskill=0,hit=0,shit=14,spcrit=5,sp=520,heal=520,mp5=0,regenCast=0,haste=0,shield=false,blockFlat=0,spen=25,apen=0,defense=300,dodge=3,parry=0,block=0,res={10,20,30,40,50},hp=3700,mana=9800,name="mage_caster"},
}
local EXPECT = {
  ["paladin_tank|base"] = {"Force=120","Agilite=90","Endurance=160","Intelligence=100","Esprit=50","Armure=3000"},
  ["paladin_tank|melee"] = {"Competence d'arme=300","Degats=100 - 200","Vitesse=2.60","DPS (coups blancs)=58","Puissance d'attaque=240","% de toucher=4%","% critique=5.5%"},
  ["paladin_tank|meleeBoss"] = {"Competence d'arme=300","% de rater=4%","Toucher requis : attaques speciales=8%","% esquive adverse=6.5%","Degats coup partiel=65%","Plafond critique=49.5%","Critique effectif=2.5%"},
  ["paladin_tank|ranged"] = {"Aucune arme a distance equipee="},
  ["paladin_tank|spell"] = {"Puissance des sorts=30","% de toucher=1%","Toucher sorts vs boss (niv. 63)=84%","Toucher manquant (plafond 99 %)=15%","% critique=6.56%","Soin ameliore=85","Regen. mana / 5s=6","Hate des sorts=0%"},
  ["paladin_tank|heal"] = {"Puissance de soins=85","% critique (sorts)=6.56%","Mana max=3000","Regen. hors combat / 5s=69","Regen. en lancant / 5s=15","Hate des sorts=0%"},
  ["paladin_tank|misc"] = {"Vie max=5000","Mana max=3000","Regen. hors combat / 5s=69","Regen. en lancant / 5s=15","Res. Feu/Nat./Givre/Ombre/Arc.=10 / 20 / 30 / 40 / 50"},
  ["paladin_tank|defense"] = {"Armure=3000","Defense=330","Esquive=7%","Parade=9%","Blocage=17%","Total=39.2%","Valeur de blocage=23"},
  ["paladin_tank|defenseBoss"] = {"Armure=3000","Defense=330","Esquive=6.4%","Parade=8.4%","Blocage=16.4%","Total=37.4%","Valeur de blocage=23"},
  ["warrior_dual|base"] = {"Force=300","Agilite=150","Endurance=350","Intelligence=40","Esprit=45","Armure=2200"},
  ["warrior_dual|melee"] = {"Competence d'arme=308 | 302","Degats MD | MG=250-300 | 70-120","Vitesse MD | MG=2.60 | 1.50","DPS (coups blancs)=169","Puissance d'attaque=1800","% de toucher=9%","% critique=21.3%"},
  ["warrior_dual|meleeBoss"] = {"Competence d'arme=308","% de rater=19%","% de rater (attaques speciales)=0%","Toucher requis : attaques speciales=6.4%","Toucher requis : coups blancs (2 armes)=25.4%","% esquive adverse=5.7%","Degats coup partiel=81%","Plafond critique=35.3%","Critique effectif=18.3%"},
  ["warrior_dual|ranged"] = {"Competence d'arme=300","Degats=90 - 140","Vitesse=2.20","Puissance d'attaque=500","% de toucher=9%","% critique=14.2%"},
  ["warrior_dual|spell"] = {"Puissance des sorts=0","% de toucher=0%","Toucher sorts vs boss (niv. 63)=83%","Toucher manquant (plafond 99 %)=16%","% critique=0%","Soin ameliore=0","Regen. mana / 5s=0","Hate des sorts=0%"},
  ["warrior_dual|heal"] = {"Puissance de soins=0","% critique (sorts)=0%","Mana max=-","Regen. hors combat / 5s=0","Regen. en lancant / 5s=0","Hate des sorts=0%"},
  ["warrior_dual|misc"] = {"Vie max=5000","Mana max=-","Res. Feu/Nat./Givre/Ombre/Arc.=10 / 20 / 30 / 40 / 50","Penetration d'armure=250"},
  ["warrior_dual|defense"] = {"Armure=2200","Defense=300","Esquive=6%","Parade=6.5%","Blocage=-","Total=17.5%"},
  ["warrior_dual|defenseBoss"] = {"Armure=2200","Defense=300","Esquive=5.4%","Parade=5.9%","Blocage=-","Total=16.3%"},
  ["rogue_dagger_hit|base"] = {"Force=90","Agilite=380","Endurance=160","Intelligence=30","Esprit=40","Armure=3000"},
  ["rogue_dagger_hit|melee"] = {"Competence d'arme=315 | 315","Degats MD | MG=90-170 | 60-100","Vitesse MD | MG=1.80 | 1.40","DPS (coups blancs)=129","Puissance d'attaque=1300","% de toucher=12%","% critique=28.7%"},
  ["rogue_dagger_hit|meleeBoss"] = {"Competence d'arme=315","% de rater=19%","% de rater (attaques speciales)=0%","Toucher requis : attaques speciales=5%","Toucher requis : coups blancs (2 armes)=24%","% esquive adverse=5%","Degats coup partiel=92%","Plafond critique=36%","Critique effectif=25.7%"},
  ["rogue_dagger_hit|ranged"] = {"Aucune arme a distance equipee="},
  ["rogue_dagger_hit|spell"] = {"Puissance des sorts=0","% de toucher=0%","Toucher sorts vs boss (niv. 63)=83%","Toucher manquant (plafond 99 %)=16%","% critique=0%","Soin ameliore=0","Regen. mana / 5s=0","Hate des sorts=0%"},
  ["rogue_dagger_hit|heal"] = {"Puissance de soins=0","% critique (sorts)=0%","Mana max=-","Regen. hors combat / 5s=0","Regen. en lancant / 5s=0","Hate des sorts=0%"},
  ["rogue_dagger_hit|misc"] = {"Vie max=5000","Mana max=-","Res. Feu/Nat./Givre/Ombre/Arc.=10 / 20 / 30 / 40 / 50"},
  ["rogue_dagger_hit|defense"] = {"Armure=3000","Defense=300","Esquive=29%","Parade=8%","Blocage=-","Total=42%"},
  ["rogue_dagger_hit|defenseBoss"] = {"Armure=3000","Defense=300","Esquive=28.4%","Parade=7.4%","Blocage=-","Total=40.8%"},
  ["hunter_bow|base"] = {"Force=120","Agilite=330","Endurance=160","Intelligence=120","Esprit=60","Armure=3000"},
  ["hunter_bow|melee"] = {"Competence d'arme=300","Degats=80 - 140","Vitesse=2.80","DPS (coups blancs)=39","Puissance d'attaque=240","% de toucher=5%","% critique=18%"},
  ["hunter_bow|meleeBoss"] = {"Competence d'arme=300","% de rater=3%","Toucher requis : attaques speciales=8%","% esquive adverse=6.5%","Degats coup partiel=65%","Plafond critique=50.5%","Critique effectif=15%"},
  ["hunter_bow|ranged"] = {"Competence d'arme=308","Degats=600 - 830","Vitesse=2.90","Puissance d'attaque=1400","% de toucher=5%","% critique=24.3%"},
  ["hunter_bow|spell"] = {"Puissance des sorts=0","% de toucher=0%","Toucher sorts vs boss (niv. 63)=83%","Toucher manquant (plafond 99 %)=16%","% critique=0%","Soin ameliore=0","Regen. mana / 5s=4","Hate des sorts=0%"},
  ["hunter_bow|heal"] = {"Puissance de soins=0","% critique (sorts)=0%","Mana max=4200","Regen. hors combat / 5s=72","Regen. en lancant / 5s=4","Hate des sorts=0%"},
  ["hunter_bow|misc"] = {"Vie max=6400","Mana max=4200","Regen. hors combat / 5s=72","Regen. en lancant / 5s=4","Res. Feu/Nat./Givre/Ombre/Arc.=10 / 20 / 30 / 40 / 50"},
  ["hunter_bow|defense"] = {"Armure=3000","Defense=300","Esquive=15%","Parade=-","Blocage=-","Total=20%"},
  ["hunter_bow|defenseBoss"] = {"Armure=3000","Defense=300","Esquive=14.4%","Parade=-","Blocage=-","Total=19.4%"},
  ["priest_heal|base"] = {"Force=120","Agilite=90","Endurance=190","Intelligence=330","Esprit=280","Armure=900"},
  ["priest_heal|melee"] = {"Competence d'arme=300","Degats=40 - 60","Vitesse=2.00","DPS (coups blancs)=25","Puissance d'attaque=20","% de toucher=0%","% critique=3%"},
  ["priest_heal|meleeBoss"] = {"Competence d'arme=300","% de rater=8%","Toucher requis : attaques speciales=8%","% esquive adverse=6.5%","Degats coup partiel=65%","Plafond critique=45.5%","Critique effectif=0%"},
  ["priest_heal|ranged"] = {"Aucune arme a distance equipee="},
  ["priest_heal|spell"] = {"Puissance des sorts=120","% de toucher=2%","Toucher sorts vs boss (niv. 63)=85%","Toucher manquant (plafond 99 %)=14%","% critique=11.54%","Soin ameliore=640","Regen. mana / 5s=18","Hate des sorts=0%"},
  ["priest_heal|heal"] = {"Puissance de soins=640","% critique (sorts)=11.54%","Mana max=9100","Regen. hors combat / 5s=224","Regen. en lancant / 5s=70","Hate des sorts=0%"},
  ["priest_heal|misc"] = {"Vie max=4300","Mana max=9100","Regen. hors combat / 5s=224","Regen. en lancant / 5s=70","Res. Feu/Nat./Givre/Ombre/Arc.=10 / 20 / 30 / 40 / 50","Penetration des sorts=10"},
  ["priest_heal|defense"] = {"Armure=900","Defense=300","Esquive=3%","Parade=-","Blocage=-","Total=8%"},
  ["priest_heal|defenseBoss"] = {"Armure=900","Defense=300","Esquive=2.4%","Parade=-","Blocage=-","Total=7.4%"},
  ["mage_caster|base"] = {"Force=120","Agilite=90","Endurance=170","Intelligence=360","Esprit=150","Armure=3000"},
  ["mage_caster|melee"] = {"Competence d'arme=300","Degats=30 - 50","Vitesse=2.00","DPS (coups blancs)=20","Puissance d'attaque=240","% de toucher=0%","% critique=2%"},
  ["mage_caster|meleeBoss"] = {"Competence d'arme=300","% de rater=8%","Toucher requis : attaques speciales=8%","% esquive adverse=6.5%","Degats coup partiel=65%","Plafond critique=45.5%","Critique effectif=0%"},
  ["mage_caster|ranged"] = {"Aucune arme a distance equipee="},
  ["mage_caster|spell"] = {"Puissance des sorts=520","% de toucher=14%","Toucher sorts vs boss (niv. 63)=97%","Toucher manquant (plafond 99 %)=2%","% critique=15.4%","Soin ameliore=520","Regen. mana / 5s=0","Hate des sorts=0%"},
  ["mage_caster|heal"] = {"Puissance de soins=520","% critique (sorts)=15.4%","Mana max=9800","Regen. hors combat / 5s=125","Regen. en lancant / 5s=0","Hate des sorts=0%"},
  ["mage_caster|misc"] = {"Vie max=3700","Mana max=9800","Regen. hors combat / 5s=125","Regen. en lancant / 5s=0","Res. Feu/Nat./Givre/Ombre/Arc.=10 / 20 / 30 / 40 / 50","Penetration des sorts=25"},
  ["mage_caster|defense"] = {"Armure=3000","Defense=300","Esquive=3%","Parade=-","Blocage=-","Total=8%"},
  ["mage_caster|defenseBoss"] = {"Armure=3000","Defense=300","Esquive=2.4%","Parade=-","Blocage=-","Total=7.4%"},
}
-- FROZEN-END
U.name = "Shikiwa"
local PANELS = M.PANELS
local nrows, nbad = 0, 0
for i = 1, table.getn(CASES) do
  local c = CASES[i]
  apply(c)
  for p = 1, table.getn(PANELS) do
    local want = EXPECT[c.name .. "|" .. PANELS[p]]
    M.edit = false
    M.SetSections({ PANELS[p] })
    M.Touch()
    local got = {}
    for k = 1, M.nv - 1 do
      local row = M.lines[k + 1]
      local val = string.gsub(row.value:GetText(), "^~", "")
      got[k] = row.label:GetText() .. "=" .. val
    end
    local ok = (table.getn(got) == table.getn(want))
    for k = 1, table.getn(want) do
      nrows = nrows + 1
      if got[k] ~= want[k] then ok = false end
    end
    if not ok then
      nbad = nbad + 1
      print("  ecart " .. c.name .. " / " .. PANELS[p] .. " : obtenu [" .. table.concat(got, " ; ") .. "] attendu [" .. table.concat(want, " ; ") .. "]")
    end
  end
end
EQ("cas du builder : tous les panneaux identiques", nbad, 0)
T("cas du builder : des lignes ont ete comparees", nrows > 200)
EQ("aucune erreur finale", SUI.errCount, 0)
DONE()
