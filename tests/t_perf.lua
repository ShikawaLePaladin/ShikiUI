-- t_perf : moniteur, mode urgence automatique (hysteresis), bandeau, rapport.
local SUI = ShikiUI
local C = SUI.Config
local P = SUI.Perf

SECTION("t_perf : echantillonnage")
BOOT()
EQ("module actif par defaut", SUI.modules.perf.enabled, true)
EQ("bandeau coupe par defaut", C.Get("perf.hud"), false)
EQ("pas de bandeau cree", P.hud, nil)
W.fps, W.lat, W.gc = 72, 45, 2048
Pump(1.1)
EQ("fps lus", P.fps, 72)
EQ("latence lue", P.lat, 45)
EQ("memoire lue", P.mem, 2048)
EQ("allocation nulle au debut", P.allocRate, 0)
W.gc = 2148; Pump(1.0)
W.gc = 2248; Pump(1.0)
NEAR("debit d'allocation (100 Ko/s)", P.allocRate, 100)
W.gc = 1500; Pump(1.0)   -- ramasse-miettes : les baisses ne comptent pas
T("baisse (GC) ignoree : debit ne devient pas negatif", P.allocRate >= 0)
for i = 1, 30 do W.gc = W.gc + 10; Pump(1.0) end
T("historique borne a 10 echantillons", table.getn(P.hist) <= 10)

SECTION("t_perf : bandeau")
C.Set("perf.hud", true)
T("bandeau cree hors combat", P.hud ~= nil)
EQ("affiche", P.hud:IsShown(), true)
Pump(1.1)
CONTAINS("texte : fps", P.hud.text:GetText(), "fps")
CONTAINS("texte : latence", P.hud.text:GetText(), "ms")
CONTAINS("texte : memoire", P.hud.text:GetText(), "Mo")
EQ("position par defaut en haut", P.hud.points[1][1], "TOP")
C.Set("perf.hud", false)
EQ("cache", P.hud:IsShown(), false)
C.Set("perf.hud", true)
EQ("reaffiche sans recreation", P.hud:IsShown(), true)
-- jamais de creation en combat
C.Set("perf.hud", false)
local hud = P.hud
P.hud = nil
hud:Hide()
local created = CREATED
W.combat = true
C.Set("perf.hud", true)
EQ("combat : pas de creation", CREATED, created)
EQ("combat : pas de bandeau", P.hud, nil)
Pump(1.1)
EQ("combat : toujours pas apres un echantillon", CREATED, created)
W.combat = false
Pump(1.1)
T("hors combat : cree a l'echantillon suivant", P.hud ~= nil)
-- couleurs
W.fps = 20
Pump(1.1)
CONTAINS("fps bas : rouge", P.hud.text:GetText(), "|cffe85454")
W.fps = 72
Pump(1.1)
CONTAINS("fps bon : vert", P.hud.text:GetText(), "|cff5ccc78")

SECTION("t_perf : urgence automatique")
W.fps = 60
C.Set("perf.auto", true)
C.Set("perf.autofps", 30)
Pump(1.1, 5)
EQ("fps corrects : pas d'urgence", SUI.emergency, false)
W.fps = 20
Pump(1.1, 2)
EQ("2 echantillons bas : pas encore", SUI.emergency, false)
Pump(1.1, 1)
EQ("3 echantillons bas : urgence", SUI.emergency, true)
EQ("rythme ralenti", SUI.rateMul, 2)
CONTAINS("message d'urgence", CHATTEXT(), "Mode urgence ACTIF")
CONTAINS("bandeau : URGENCE", P.hud.text:GetText(), "URGENCE")
EQ("declenchee automatiquement", P.autoTriggered, true)
-- remontee brusque mais courte : l'urgence reste
W.fps = 80
Pump(1.1 * 2, 5)    -- minuterie ralentie : 2.2 s par echantillon
EQ("hysteresis : 5 bons echantillons ne suffisent pas", SUI.emergency, true)
Pump(1.1 * 2, 6)
EQ("apres 10+ bons echantillons : fin", SUI.emergency, false)
EQ("rythme normal", SUI.rateMul, 1)
-- un fps qui oscille ne declenche pas
W.fps = 20; Pump(1.1, 2)
W.fps = 60; Pump(1.1, 1)
W.fps = 20; Pump(1.1, 2)
EQ("oscillation : pas d'urgence", SUI.emergency, false)
-- fps a 0 (chargement) ignore
W.fps = 0
Pump(1.1, 10)
EQ("fps nul ignore", SUI.emergency, false)
-- urgence manuelle : pas coupee automatiquement
W.fps = 80
P.SetEmergency(true)
EQ("urgence manuelle", SUI.emergency, true)
EQ("pas marquee automatique", P.autoTriggered, false)
Pump(1.1 * 2, 20)
EQ("l'urgence manuelle reste", SUI.emergency, true)
P.SetEmergency(false)
local seen = {}
P.OnEmergency(function(on) table.insert(seen, tostring(on)) end)
P.OnEmergency(function() error("casse") end)
P.SetEmergency(true)
P.SetEmergency(true)       -- idempotent
P.SetEmergency(false)
EQ("callbacks : une fois par changement", table.concat(seen, ","), "true,false")
T("callback en erreur isole", SUI.errCount >= 2)
-- reglage de seuil
C.Set("perf.autofps", 60)
W.fps = 50
Pump(1.1, 3)
EQ("seuil releve : urgence", SUI.emergency, true)
P.SetEmergency(false)
C.Set("perf.auto", false)
Pump(1.1, 5)
EQ("auto coupe : pas d'urgence", SUI.emergency, false)

SECTION("t_perf : rapport")
SUI.Perf.SetProfile(true)
Pump(1.1, 4)
Fire("PLAYER_REGEN_ENABLED")
local lines = P.Report()
T("lignes", table.getn(lines) >= 4)
CONTAINS("principale", lines[1], "FPS")
CONTAINS("allocation", lines[2], "Ko/s")
CONTAINS("etat", lines[3], "Mode urgence")
local txt = table.concat(lines, "\n")
CONTAINS("minuterie perf.sample listee", txt, "perf.sample")
CONTAINS("temps indicatif", txt, "indicatif")
CONTAINS("evenement liste", txt, "evenement")
SUI.Perf.SetProfile(false)
lines = P.Report()
T("sans profilage : pas de temps", string.find(table.concat(lines, "\n"), "indicatif", 1, true) == nil)
SUI.Perf.SetProfile(false)
local calls = 0
for i = 1, table.getn(SUI.tasks) do calls = calls + SUI.tasks[i].calls end
EQ("remise a zero des compteurs", calls, 0)

SECTION("t_perf : module coupe")
C.Set("modules.perf", false)
EQ("module coupe", SUI.modules.perf.enabled, false)
local before = P.fps
W.fps = 11
Pump(3)
EQ("plus d'echantillon", P.fps, before)
EQ("bandeau cache", P.hud:IsShown(), false)
C.Set("modules.perf", true)
Pump(1.1)
EQ("relance", P.fps, 11)
local nSample = 0
for i = 1, table.getn(SUI.tasks) do
  local t = SUI.tasks[i]
  if t.name == "perf.sample" and not t.dead then nSample = nSample + 1 end
end
EQ("une seule minuterie d'echantillonnage", nSample, 1)
CONTAINS("seules erreurs : le callback casse volontairement", SUI.lastErr, "emergency")
DONE()
