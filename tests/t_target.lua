-- t_target : service partage SUI.Target (ennemis proches par plaques de nom, distance, ligne de vue, acquisition de cible).
local SUI = ShikiUI
local TG = SUI.Target
EXT.unitxp("real")
BOOT()
SETTLE()

SECTION("t_target : rien autour")
EQ("service present", type(TG), "table")
EQ("aucun ennemi", TG.Scan(100), 0)
EQ("source", TG.source, "none")
local n, exact = TG.Count(10, false, 100)
EQ("compte impossible a savoir", n, nil)
EQ("pas exact", exact, false)
EQ("visibles", TG.Visible(false, 100), 0)
EQ("plus proche", TG.Nearest(false, 100), nil)

SECTION("t_target : plaques de nom")
MKPLATE("0xA1", { dist = 5 })
MKPLATE("0xA2", { dist = 12, combat = false })
MKPLATE("0xA3", { dist = 30 })
MKPLATE("0xD1", { dist = 4, dead = true })
MKPLATE("0xF1", { dist = 3, reaction = 5 })
MKPLATE("0xF2", { dist = 3, reaction = 4 })
MKPLATE("0xAB02", { dist = 3, button = false })
MKPLATE("0xAB01", { dist = 3, shown = false })
local scans0 = TG.scans
EQ("ennemis vivants et hostiles", TG.Scan(101), 3)
EQ("source plaques", TG.source, "plates")
EQ("une lecture de plus", TG.scans, scans0 + 1)
n, exact = TG.Count(10, false, 101)
EQ("a moins de 10 yards", n, 1)
EQ("compte fiable", exact, true)
EQ("a moins de 15", (TG.Count(15, false, 101)), 2)
EQ("a moins de 40", (TG.Count(40, false, 101)), 3)
EQ("en combat seulement (15)", (TG.Count(15, true, 101)), 1)
EQ("visibles", TG.Visible(false, 101), 3)
EQ("visibles en combat", TG.Visible(true, 101), 2)
local g, d = TG.Nearest(false, 101)
EQ("plus proche", g, "0xA1")
EQ("sa distance", d, 5)
g, d = TG.Nearest(true, 101)
EQ("plus proche en combat", g, "0xA1")
EQ("cache : pas de nouvelle lecture dans le delai", TG.scans, scans0 + 1)
W.units["0xA3"].dist = 6
EQ("cache : valeur gardee", (TG.Count(10, false, 101.2)), 1)
EQ("apres le delai : relu", (TG.Count(10, false, 101.6)), 2)
EQ("une lecture de plus", TG.scans, scans0 + 2)
EQ("temps qui recule : relu", TG.Scan(50) >= 0, true)
-- plaque sans distance
W.units["0xA1"].dist = nil
TG.at = -10
n = TG.Count(10, false, 200)
EQ("ennemi sans distance : ignore dans le compte", n, 1)
EQ("mais visible", TG.Visible(false, 200), 3)

SECTION("t_target : sans UnitXP")
EXT.unitxp(nil)
SUI.Api.Detect()
TG.at = -10
n, exact = TG.Count(10, false, 300)
EQ("distances inconnues : on ne devine pas", n, nil)
EQ("pas exact", exact, false)
EQ("visibles quand meme", TG.Visible(false, 300), 3)
g = TG.Nearest(false, 300)
EQ("plus proche inconnu", g, nil)
EXT.unitxp("real")
SUI.Api.Detect()
W.units["0xA1"].dist = 5

SECTION("t_target : repli sur la cible")
CLEARPLATES()
TG.at = -10
EQ("plus aucune plaque", TG.Scan(400), 0)
MKTARGET({ dist = 7 })
TG.at = -10
EQ("la cible seule", TG.Scan(401), 1)
EQ("source cible", TG.source, "target")
n, exact = TG.Count(10, false, 401)
EQ("compte (borne basse)", n, 1)
EQ("pas exact", exact, false)
W.units.target.friend = true
W.units.target.canAttack = false
TG.at = -10
EQ("cible amie : ignoree", TG.Scan(402), 0)
W.units.target = nil

SECTION("t_target : unite precise")
SUI.Api.Detect()
MKTARGET({ dist = 9, sight = false, behind = true })
EQ("distance", TG.Distance("target"), 9)
Pump(60)
EQ("ligne de vue", TG.Sight("target"), false)
EQ("dans le dos", TG.Behind("target"), true)
EQ("cible hostile", TG.Harm("target"), true)
W.units.target.dead = true
W.units.target.hp = 0
EQ("cible morte : pas hostile utile", TG.Harm("target"), false)
W.units.target = nil
EQ("pas de cible", TG.Harm("target"), false)
EXT.superwow(true)
MKTARGET({ guid = "0xBEEF" })
EQ("GUID par SuperWoW", TG.GUID("target"), "0xBEEF")
EXT.superwow(false)
W.units.target = nil
-- portee d'un sort
EQ("sort inconnu", TG.SpellInRange("Jugement", "target"), nil)
MKTARGET({})
W.spellRange["Jugement"] = 1
EQ("a portee", TG.SpellInRange("Jugement", "target"), 1)
W.spellRange["Jugement"] = 0
EQ("hors de portee", TG.SpellInRange("Jugement", "target"), 0)
W.units.target = nil

SECTION("t_target : acquisition de cible")
W.acts = {}
MKPLATE("0xE1", { dist = 8 })
MKPLATE("0xE2", { dist = 20 })
EQ("rien a cibler sans cible : trouve", TG.Acquire(false), true)
EQ("cible le plus proche", W.units.target.guid, "0xE1")
T("ClearTarget avant", W.acts[1] == "ClearTarget")
T("puis TargetNearestEnemy", W.acts[2] == "TargetNearestEnemy")
W.acts = {}
W.units["0xE1"].isPlayer = false
W.units["0xE2"].isPlayer = true
EQ("joueurs seulement", TG.Acquire(true), true)
EQ("cible le joueur", W.units.target.guid, "0xE2")
T("API joueurs utilisee", W.acts[2] == "TargetNearestEnemyPlayer")
-- rien a cibler : on retrouve l'ancienne cible
W.units["0xE1"].dead = true
W.units["0xE2"].dead = true
W.acts = {}
local before = W.units.target
EQ("rien : la cible precedente est retrouvee", TG.Acquire(false), true)
T("TargetLastTarget utilise", W.acts[table.getn(W.acts)] == "TargetLastTarget")
CLEARPLATES()
W.units.target = nil
W.units["0xE1"], W.units["0xE2"] = nil, nil
W.lastTarget = nil
EQ("aucune cible possible", TG.Acquire(false), false)

SECTION("t_target : cache et plaques illisibles")
MKPLATE("0xA9", { dist = 5 })
TG.at = -10
TG.Scan(800)
local sc = TG.scans
TG.Acquire(false)
TG.Scan(800.1)
EQ("apres une acquisition : relu malgre le cache", TG.scans, sc + 1)
CLEARPLATES()
local realChildren = WorldFrame.GetChildren
WorldFrame.GetChildren = function() error("boum") end
MKTARGET({ dist = 7 })
TG.at = -10
EQ("lecture des plaques en erreur : repli sur la cible", TG.Scan(810), 1)
WorldFrame.GetChildren = realChildren
W.units.target = nil

SECTION("t_target : doublons")
MKPLATE("0xD0D1", { dist = 5 })
MKPLATE("0xD0D1", { dist = 5 })
TG.at = -10
EQ("la meme plaque deux fois : comptee une fois", TG.Scan(450), 1)
CLEARPLATES()

SECTION("t_target : diagnostic et robustesse")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("target")
CONTAINS("diagnostic", CHATTEXT(), "plaques")
local a, b, c = TG.Caps()
EQ("plaques disponibles", a, true)
EQ("UnitXP", c, true)
-- plaque dont le nom plante
MKPLATE("0xB1", { dist = 5 })
W.plates[1].GetName = function() error("boom") end
TG.at = -10
EQ("plaque qui plante : ignoree", TG.Scan(500), 0)
CLEARPLATES()
-- GUID invalide
MKPLATE("pas un guid", { dist = 5 })
MKPLATE("0x0000000000000000", { dist = 5 })
W.plates[1].GetName = function(self, g) if g then return "pas un guid" end end
W.plates[2].GetName = function(self, g) if g then return "0x0000000000000000" end end
TG.at = -10
EQ("GUID invalides ignores", TG.Scan(501), 0)
CLEARPLATES()
-- beaucoup de plaques : pas d'accumulation sans fin
for i = 1, 60 do MKPLATE("0xC" .. i, { dist = 5 + i }) end
TG.at = -10
EQ("60 plaques", TG.Scan(600), 60)
T("compte borne", TG.Count(1000, false, 600) == 60)
CLEARPLATES()
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
