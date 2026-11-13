-- t_bossmods : module "bossmods" (alarmes de raid : detection du boss, t0 de combat, armement des evenements
-- relatifs, annonces lead au canal choisi, barres triees, purge, cycle de vie).
local SUI = ShikiUI
local C = SUI.Config
BMC_SETUP()
EXT.unitxp("real")
BOOT()
SETTLE()
BMC_SETUP()   -- re-applique les overrides (d'autres mocks les ecrasent pendant le BOOT)
BMC_RAID(10)

local function liveTasks()
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == "bossmods.tick" and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end

SECTION("t_bossmods : enregistrement et contrat")
local M = SUI.BossMods
local mod = SUI.modules.bossmods
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "medium")
EQ("categorie du menu", SUI.categories.bossmods, 70)
T("option lead declaree", C.meta["bossmods.lead"] ~= nil)
T("option channel declaree", C.meta["bossmods.channel"] ~= nil)
T("option sound declaree", C.meta["bossmods.sound"] ~= nil)
EQ("lead par defaut 10", C.Get("bossmods.lead"), 10)
T("base : Ragnaros present", M.BOSSES["ragnaros"] ~= nil)
T("base : Onyxia presente", M.BOSSES["onyxia"] ~= nil)
T("base : Ebonroc present", M.BOSSES["ebonroc"] ~= nil)
EQ("aucune erreur interne au demarrage", SUI.errCount, 0)

SECTION("t_bossmods : detection du boss")
C.Set("modules.bossmods", true)
SETTLE()
BMC.name.target = "Ragnaros"
BMC.hostile = true
M.Tick()
EQ("boss detecte par la cible", M.cur, "ragnaros")
EQ("label affiche", M.curLabel, "Ragnaros")
BMC.name.target = "Ebonroc"
M.Tick()
EQ("boss change : ebonroc", M.cur, "ebonroc")
BMC.name.target = "Gardien"
M.Tick()
EQ("non-boss : rien", M.cur, nil)
BMC.name.target = "Ébonroc"
M.Tick()
EQ("accent FR plie", M.cur, "ebonroc")
EQ("accent FR : label sans accent", M.curLabel, "Ebonroc")
BMC.name.target = "Ragnaros"
M.Tick()
EQ("retour : ragnaros", M.cur, "ragnaros")

SECTION("t_bossmods : t0 et armement des evenements")
C.Set("bossmods.lead", 10)
C.Set("bossmods.channel", "self")
BMC_CLEAR()
CHATCLEAR()
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
M.Tick()
T("t0 pose", M.combatAt ~= nil)
-- Wrath of Ragnaros : t=25, lead=10 -> arme a t0+15, barre jusqu'a t0+25
Pump(15.2)
EQ("barre armee au lead", M.narmed, 1)
EQ("evenement Wrath arme", M.armed[1] and M.armed[1].name, "Wrath of Ragnaros")
CONTAINS("annonce lead au chat", CHATTEXT(), "Wrath of Ragnaros")
local nwarn = 0
for _ in string.gfind(CHATTEXT(), "Wrath of Ragnaros") do nwarn = nwarn + 1 end
EQ("annonce unique pendant le lead", nwarn, 1)
T("son joue", BMC.sounds >= 1)
M.Tick()
EQ("anti-doublon", M.narmed, 1)
-- la barre part a t0+25, repetition replanifiee a t0+50
Pump(0.25, 40)
EQ("barre purgee apres l'evenement", M.narmed, 0)
Pump(0.25, 60)
EQ("repetition : rearmee au lead suivant", M.narmed, 1)
T("repetition : moment replanifie", M.next[M.BOSSES.ragnaros.ev[1]] ~= nil)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
M.Tick()

SECTION("t_bossmods : annonces au canal raid")
M.dbg = {}
C.Set("bossmods.channel", "raid")
BMC_RAID(10)
BMC.name.target = "Onyxia"
BMC_CLEAR()
CHATCLEAR()
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
Pump(0.25, 120)
for i = table.getn(M.dbg) - 2, table.getn(M.dbg) do print("RD" .. i .. ": " .. tostring(M.dbg[i])) end
for i = 1, table.getn(SUI.tasks) do local t = SUI.tasks[i] print("RC " .. t.name .. " calls=" .. t.calls) end
print("RDerr rateMul=" .. tostring(SUI.rateMul) .. " lastErr=" .. tostring(SUI.lastErr) .. " errCount=" .. SUI.errCount .. " taskDead=" .. tostring(M.task and M.task.dead) .. " RDstate cur=" .. tostring(M.cur) .. " combatAt=" .. tostring(M.combatAt ~= nil) .. " narmed=" .. M.narmed .. " task=" .. tostring(M.task ~= nil) .. " on=" .. tostring(M.on))
CONTAINS("raid warning envoye", BMC_ACTS(), "RAID_WARNING")
T("son annonce", BMC.sounds >= 1)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
M.Tick()
BMC_CLEAR()

SECTION("t_bossmods : barres triees et purge a l'affichage")
C.Set("bossmods.channel", "self")
BMC.name.target = "Ragnaros"
M.Open()
SETTLE(40)
W.combat = true
Fire("PLAYER_REGEN_DISABLED")
T("fenetre ouverte", M.win ~= nil and M.win:IsShown())
-- avancer jusqu'a armer plusieurs evenements (Wrath t=25 lead 10 ; Submerge t=90 lead 10)
Pump(0.25, 360)
T("barres armees", M.narmed >= 1)
M.Paint()
T("premiere barre rendue", M.row1.name:GetText() ~= nil and M.row1.name:GetText() ~= "")
M.Close()
EQ("fermee : minuterie conservee (module actif)", liveTasks(), 1)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
M.Tick()

SECTION("t_bossmods : commande et coupure propre")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("bossmods open")
SETTLE()
EQ("/sui bossmods open", M.win:IsShown(), true)
SlashCmdList["SHIKIUI"]("bossmods close")
EQ("/sui bossmods close", M.win:IsShown(), false)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("help")
CONTAINS("aide du module", CHATTEXT(), "/sui bossmods")
local tasks0 = liveTasks()
C.Set("modules.bossmods", false)
EQ("module coupe", mod.enabled, false)
EQ("minuterie rendue", liveTasks(), tasks0 - 1)
C.Set("modules.bossmods", true)
SETTLE()
EQ("rallume", mod.enabled, true)
EQ("aucune erreur interne finale " .. tostring(SUI.lastErr), SUI.errCount, 0)

SECTION("t_bossmods : options barres, ancre annonces, mode test")
C.Set("bossmods.width", 300)
C.Set("bossmods.rows", 3)
SETTLE()
M.dbg2 = {}
M.dbg2 = {}
local nw = 0
for i = 1, table.getn(C.watchers) do if C.watchers[i].prefix == "bossmods." and C.watchers[i].fn == M.OnKey then nw = nw + 1 end end
print("WDBG watchers matching OnKey = " .. nw .. " / total " .. table.getn(C.watchers))
M.OnKey("bossmods.width")
print("WDBG direct apply w=" .. tostring(M.win:GetWidth()))
C.Set("bossmods.width", 300)
C.Set("bossmods.rows", 3)
SETTLE()
for i = 1, table.getn(M.dbg2) do print("K" .. i .. ": " .. tostring(M.dbg2[i])) end
print("DBGW win=" .. tostring(M.win ~= nil) .. " w=" .. tostring(M.win and M.win:GetWidth()))
EQ("largeur appliquee", M.win:GetWidth(), 300)
C.Set("bossmods.width", 220)
-- 4 barres armees mais rows=3 : une seule ligne masquee a l'affichage
M.Test()
SETTLE(20)
T("mode test : arme", M.testing and M.narmed == 4)
M.Paint()
local shown = 0
for i = 1, 8 do if M["row" .. i]:IsShown() then shown = shown + 1 end end
EQ("3 lignes visibles sur 4 armees", shown, 3)
T("ancre d'annonces creee", M.msg ~= nil)
T("ancre deplacable", SUI.Layout.items["bossmods.msg"] ~= nil)
-- annonces de test : chez vous seulement (jamais RAID_WARNING)
EQ("test : pas de raid warning", BMC_ACTS(), "")
C.Set("bossmods.showmsg", false)
M.Test()
EQ("test arrete", M.testing, false)
EQ("barres vides apres le test", M.narmed, 0)
C.Set("bossmods.rows", 6)
C.Set("bossmods.width", 220)
SETTLE()
EQ("aucune erreur interne " .. tostring(SUI.lastErr), SUI.errCount, 0)
DONE()
