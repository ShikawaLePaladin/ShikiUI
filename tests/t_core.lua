-- t_core : demarrage, routeur d'evenements, minuterie partagee, modules, sortie de combat, deconnexion.
local SUI = ShikiUI
SECTION("t_core : demarrage")
EQ("version", SUI.VERSION, "0.3.0")
EQ("commande /sui", SlashCmdList["SHIKIUI"] ~= nil, true)
EQ("SLASH_SHIKIUI1", SLASH_SHIKIUI1, "/sui")
EQ("SLASH_SHIKIUI2", SLASH_SHIKIUI2, "/shikiui")
T("pas de /shiki (pris par ShikiwaRotation)", SLASH_SHIKIUI1 ~= "/shiki" and SLASH_SHIKIUI2 ~= "/shiki")

-- un seul routeur, une seule frame de minuterie
EQ("frame evenements", SUI.evFrame ~= nil and SUI.evFrame:GetName(), "ShikiUI_Events")
EQ("frame minuterie", SUI.tickFrame:GetName(), "ShikiUI_Tick")
local onUpdates = 0
for i = 1, table.getn(ALLFRAMES) do
  if ALLFRAMES[i].scripts.OnUpdate then onUpdates = onUpdates + 1 end
end
EQ("un seul OnUpdate avant le demarrage", onUpdates, 1)

BOOT()
CONTAINS("bandeau de demarrage", CHATTEXT(), "ShikiUI 0.3.0")
T("profil actif Default", SUI.Config.curName == "Default")
T("modules actives", SUI.modules.units.enabled and SUI.modules.perf.enabled)
EQ("aucune erreur interne au demarrage", SUI.errCount, 0)
onUpdates = 0
for i = 1, table.getn(ALLFRAMES) do
  if ALLFRAMES[i].scripts.OnUpdate then onUpdates = onUpdates + 1 end
end
EQ("un seul OnUpdate apres le demarrage (cadres d'unites compris)", onUpdates, 1)
-- le noyau detache son propre ecouteur ; le module "windows" garde le sien tant qu'il est actif (fenetres chargees a la demande)
local alh = SUI.handlers["ADDON_LOADED"]
local alOthers = 0
if alh then for _, h in pairs(alh) do alOthers = alOthers + 1 end end
local alWant = 0
if SUI.modules.windows and SUI.modules.windows.enabled then alWant = alWant + 1 end
if SUI.modules.specs and SUI.modules.specs.enabled then alWant = alWant + 1 end
T("ADDON_LOADED detache apres usage (hors modules windows et specs, fenetres chargees a la demande)", alh == nil or (alWant > 0 and alOthers == alWant))

-- mauvais ADDON_LOADED ignore
SECTION("t_core : routeur")
local got = {}
local function h1(ev, a1, a2) table.insert(got, "h1:" .. tostring(a1) .. ":" .. tostring(a2)) end
local function h2(ev, a1) table.insert(got, "h2:" .. tostring(a1)) end
local function boom() error("boum") end
SUI.On("TEST_EVENT", h1)
SUI.On("TEST_EVENT", h1)            -- doublon ignore
SUI.On("TEST_EVENT", boom)
SUI.On("TEST_EVENT", h2)
EQ("evenement enregistre sur la frame", SUI.evFrame.events["TEST_EVENT"], true)
local e0 = SUI.errCount
Fire("TEST_EVENT", "a", "b")
EQ("h1 appele une fois, h2 appele malgre l'erreur de boom", table.concat(got, ","), "h1:a:b,h2:a")
EQ("erreur comptee", SUI.errCount, e0 + 1)
CONTAINS("derniere erreur memorisee", SUI.lastErr, "event TEST_EVENT")
T("compteur d'evenements", SUI.evCount["TEST_EVENT"] == 1)
SUI.Off("TEST_EVENT", boom)
SUI.Off("TEST_EVENT", h1)
got = {}
Fire("TEST_EVENT", "z")
EQ("apres Off", table.concat(got, ","), "h2:z")
SUI.Off("TEST_EVENT", h2)
EQ("dernier handler retire -> desinscription", SUI.evFrame.events["TEST_EVENT"], nil)
SUI.Off("EVENT_INCONNU", h1)    -- ne doit pas planter

-- un handler qui se retire pendant la distribution ne casse pas les autres
local order = {}
local selfOff
selfOff = function() table.insert(order, "s"); SUI.Off("TEST2", selfOff) end
local after = function() table.insert(order, "a") end
SUI.On("TEST2", selfOff)
SUI.On("TEST2", after)
Fire("TEST2")
T("auto-retrait pendant la distribution : 'a' est appele", string.find(table.concat(order, ","), "a", 1, true) ~= nil)
SUI.Off("TEST2", after)

SECTION("t_core : minuterie")
local calls = 0
local t1 = SUI.Every(1, function() calls = calls + 1 end, "t1")
Pump(0.5)
EQ("pas encore", calls, 0)
Pump(0.6)
EQ("une fois apres 1.1 s", calls, 1)
Pump(1.0)
EQ("deux fois", calls, 2)
SUI.Cancel(t1)
Pump(5)
EQ("annulee", calls, 2)

local once = 0
SUI.After(2, function() once = once + 1 end, "once")
Pump(1.9)
EQ("After : pas avant", once, 0)
Pump(0.2)
EQ("After : une fois", once, 1)
Pump(10)
EQ("After : jamais deux fois", once, 1)

-- erreur dans une minuterie : isolee, comptee, la tache continue
local n = 0
SUI.Every(1, function() n = n + 1; error("tache") end, "boomtask")
local e1 = SUI.errCount
Pump(1.1)
Pump(1.1)
EQ("la tache en erreur est rappelee", n, 2)
EQ("erreurs de tache comptees", SUI.errCount, e1 + 2)

-- mode urgence : 'scalable' double l'intervalle, les autres non
SECTION("t_core : echelle d'urgence")
local sc, ns = 0, 0
SUI.Every(1, function() sc = sc + 1 end, "scal", true)
SUI.Every(1, function() ns = ns + 1 end, "nonscal", false)
Pump(1.1)
EQ("avant urgence scalable", sc, 1)
EQ("avant urgence non scalable", ns, 1)
SUI.Perf.SetEmergency(true)
EQ("rateMul 2", SUI.rateMul, 2)
Pump(1.1, 6)   -- 6.6 s
T("scalable ralenti (<= 4 appels sur 6.6 s au lieu de 7)", sc <= 1 + 4)
T("non scalable inchange (>= 6)", ns >= 6)
SUI.Perf.SetEmergency(false)
EQ("rateMul 1", SUI.rateMul, 1)

-- WhenSafe
SECTION("t_core : WhenSafe / sortie de combat")
local ws = 0
SUI.WhenSafe(function() ws = ws + 1 end)
EQ("hors combat : immediat", ws, 1)
W.combat = true
SUI.WhenSafe(function() ws = ws + 10 end)
SUI.WhenSafe(function() error("apres combat") end)
EQ("en combat : differe", ws, 1)
W.combat = false
local e2 = SUI.errCount
Fire("PLAYER_REGEN_ENABLED")
EQ("execute a la sortie de combat", ws, 11)
EQ("erreur de la file isolee", SUI.errCount, e2 + 1)
Fire("PLAYER_REGEN_ENABLED")
EQ("file videe", ws, 11)

-- modules
SECTION("t_core : modules")
local log = {}
SUI.RegisterModule("zztest", {
  default = true,
  options = { { key = "zztest.x", type = "bool", cat = "general", label = "opt.zztest.x", default = false, order = 1 } },
  init = function() table.insert(log, "init") end,
  enable = function() table.insert(log, "enable") end,
  disable = function() table.insert(log, "disable") end,
})
T("option modules.zztest enregistree", SUI.Config.meta["modules.zztest"] ~= nil)
T("option du module enregistree", SUI.Config.meta["zztest.x"] ~= nil)
EQ("module inconnu", SUI.EnableModule("nope"), false)
SUI.EnableModule("zztest")
SUI.EnableModule("zztest")
EQ("init + enable une seule fois", table.concat(log, ","), "init,enable")
EQ("disable", SUI.DisableModule("zztest"), true)
EQ("disable idempotent", SUI.DisableModule("zztest"), false)
SUI.EnableModule("zztest")
EQ("re-enable sans nouvel init", table.concat(log, ","), "init,enable,disable,enable")
-- via la configuration
SUI.Config.Set("modules.zztest", false)
EQ("config -> disable", log[table.getn(log)], "disable")
SUI.Config.Set("modules.zztest", true)
EQ("config -> enable", log[table.getn(log)], "enable")
-- erreur dans enable : isolee
SUI.RegisterModule("bad", { enable = function() error("x") end, init = function() error("y") end })
local e3 = SUI.errCount
SUI.EnableModule("bad")
EQ("erreurs init+enable comptees", SUI.errCount, e3 + 2)
-- changement de profil : realignement des modules
SUI.Config.NewProfile("Alt")
SUI.Config.UseProfile("Alt")
SUI.Config.Set("modules.zztest", false)
EQ("zztest coupe dans Alt", SUI.modules.zztest.enabled, false)
SUI.Config.UseProfile("Default")
EQ("retour a Default : zztest reactive", SUI.modules.zztest.enabled, true)

-- deconnexion
SECTION("t_core : deconnexion")
Fire("PLAYER_LOGOUT")
EQ("shutdown", SUI.shutdown, true)
EQ("evenements detaches", next(SUI.evFrame.events), nil)
EQ("OnUpdate detache", SUI.tickFrame.scripts.OnUpdate, nil)
local e4 = SUI.errCount
Fire("PLAYER_TARGET_CHANGED")
Pump(1)
EQ("plus aucune activite", SUI.errCount, e4)
DONE()

SECTION("t_core : journal d'erreurs persistant")
do
  local n0 = table.getn(SUI.errlog)
  SUI.Report("unit", "boom")
  EQ("Report ajoute au journal", table.getn(SUI.errlog), n0 + 1)
  CONTAINS("entree formatee", SUI.errlog[table.getn(SUI.errlog)], "|unit|boom")
  EQ("journal range dans la config", SUI.Config.db.global.errlog, SUI.errlog)
  for i = 1, 60 do SUI.LogError("x", "m" .. i) end
  T("anneau borne a 40", table.getn(SUI.errlog) == 40)
  _ERRORMESSAGE("Interface/AddOns/ShikiUI/Mod_X.lua:12: attempt to index nil")
  CONTAINS("erreur de script ShikiUI capturee", SUI.errlog[table.getn(SUI.errlog)], "|script|")
  local c = table.getn(SUI.errlog)
  _ERRORMESSAGE("Interface/AddOns/Autre/a.lua:1: oops")
  EQ("erreur d'un autre addon ignoree", table.getn(SUI.errlog), c)
  SUI.Command("errors clear")
  EQ("errors clear vide le journal", table.getn(SUI.errlog), 0)
end
