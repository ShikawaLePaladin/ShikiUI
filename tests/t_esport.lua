-- t_esport : module "esport" (suivi PvP : ennemis recents, DR par categorie, detection SuperWoW + journal,
-- ciblage par clic, tri par vie, options, cycle de vie).
local SUI = ShikiUI
local C = SUI.Config
ESP_SETUP()
ESP.raid = { "M1", "M2" }
EXT.unitxp("real")
BOOT()
SETTLE()

local function liveTasks()
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == "esport.sweep" and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end

SECTION("t_esport : enregistrement et contrat")
local M = SUI.Esport
local mod = SUI.modules.esport
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "medium")
EQ("categorie du menu", SUI.categories.esport, 71)
T("option lowfirst declaree", C.meta["esport.lowfirst"] ~= nil)
T("option drwindow declaree", C.meta["esport.drwindow"] ~= nil)
EQ("drwindow par defaut 15", C.Get("esport.drwindow"), 15)
EQ("7 categories de controle", table.getn(M.CC_ORDER), 7)
EQ("aucune erreur interne au demarrage", SUI.errCount, 0)

SECTION("t_esport : detection des ennemis")
C.Set("modules.esport", true)
SETTLE()
ESP_ENEMY("target", { name = "Bob", cls = "MAGE", hp = 2000, hpMax = 4000, guid = "0xE1", isPlayer = true, mark = 8 })
ESP_ENEMY("mouseover", { name = "Zed", cls = "ROGUE", hp = 800, hpMax = 4000, guid = "0xE2", isPlayer = true })
M.Sweep()
EQ("2 ennemis", table.getn(M.order), 2)
EQ("ennemi par nom", M.enemies["Bob"] ~= nil, true)
EQ("classe memorisee", M.enemies["Bob"].cls, "MAGE")
EQ("marque memorisee", M.enemies["Bob"].mark, 8)
T("minuterie de balayage", M.task ~= nil)
-- tri par vie croissante : Zed (800) avant Bob (2000)
EQ("le plus faible en premier", M.order[1], "Zed")
-- oubli apres REMEMBER
Pump(0.1, 2)
ESP.units["target"] = nil   -- Bob quitte le monde : le balayage ne le revoit plus
Pump(31)
EQ("oubli apres 30 s sans revoir", M.enemies["Bob"], nil)
EQ("oubli : retire de l'ordre", table.getn(M.order), 1)
ESP_ENEMY("target", { name = "Bob", cls = "MAGE", hp = 2000, hpMax = 4000, guid = "0xE1", isPlayer = true, mark = 8 })
M.Sweep()
EQ("revoir : reenregistre", M.enemies["Bob"] ~= nil, true)

SECTION("t_esport : DR via SuperWoW")
EXT.superwow(true)
-- EXT.superwow ecrase SpellInfo avec sa propre table : re-installer celle du mock esport
rawset(_G, "SpellInfo", function(id) return ESP.spells[id] end)
SUI.Api.Detect()
-- le handler UNIT_CASTEVENT s'enregistre a l'activation : reactiver apres la detection de SuperWoW
C.Set("modules.esport", false)
C.Set("modules.esport", true)
SETTLE()
ESP.spells = { [853] = "Hammer of Justice", [5782] = "Fear", [122] = "Frost Nova", [1776] = "Gouge" }
ESP_ENEMY("mouseover", { name = "Zed", cls = "ROGUE", hp = 800, hpMax = 4000, guid = "0xE2", isPlayer = true })
ESP.units["target"] = { name = "Bob", cls = "MAGE", hp = 2000, hpMax = 4000, guid = "0xE1", isPlayer = true }
M.Sweep()
-- Bob lance HoJ sur Zed : la VICTIME est Zed
ESP_CAST("0xE1", "0xE2", "CAST", 853)
EQ("DR applique a la victime", M.enemies["Zed"].dr.stun ~= nil, true)
EQ("DR compteur 1", M.enemies["Zed"].dr.stun.count, 1)
-- 2e stun tout de suite : compteur 2
ESP_CAST("0xE1", "0xE2", "CAST", 853)
EQ("DR compteur 2", M.enemies["Zed"].dr.stun.count, 2)
-- 3e : compteur 3 (plafonne a 4)
ESP_CAST("0xE1", "0xE2", "CAST", 853)
EQ("DR compteur 3", M.enemies["Zed"].dr.stun.count, 3)
-- categorie differente : compteur independant
ESP_CAST("0xE1", "0xE2", "CAST", 5782)
EQ("DR peur independant", M.enemies["Zed"].dr.fear.count, 1)
-- sort non-CC : rien
ESP_CAST("0xE1", "0xE2", "CAST", 133)
EQ("sort non-CC : rien", M.enemies["Zed"].dr.fire or "none", "none")
-- fenetre expiree : compteur reparti de 1
C.Set("esport.drwindow", 5)
Pump(6)
ESP_CAST("0xE1", "0xE2", "CAST", 853)
EQ("fenetre expiree : compteur reparti", M.enemies["Zed"].dr.stun.count, 1)
C.Set("esport.drwindow", 15)
ESP_CAST("0xE1", "0xE2", "CAST", 853)
-- nom FR du sort reconnu via l'alias
ESP.spells = { [853] = "Marteau de la Justice" }
ESP_CAST("0xE1", "0xE2", "CAST", 853)
T("sort FR reconnu", M.enemies["Zed"].dr.stun ~= nil)
ESP.spells = { [853] = "Hammer of Justice" }

SECTION("t_esport : DR via le journal (sans SuperWoW)")
EXT.superwow(false)
SUI.Api.Detect()
BMC = nil
C.Set("modules.esport", false)
C.Set("modules.esport", true)
SETTLE()
ESP_ENEMY("target", { name = "Bob", cls = "MAGE", hp = 2000, hpMax = 4000, guid = "0xE1", isPlayer = true })
M.Sweep()
CHATCLEAR()
Fire("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "Bob is afflicted by Gouge.")
EQ("journal EN : gouge", M.enemies["Bob"].dr.disorient.count, 1)
CHATCLEAR()
Fire("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "Bob subit Racines entravantes.")
EQ("journal FR : racines", M.enemies["Bob"].dr.root.count, 1)
CHATCLEAR()
Fire("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE", "Bob is afflicted by Fireball.")
EQ("journal : non-CC ignore", M.enemies["Bob"].dr.stun, nil)
EXT.superwow(true)
SUI.Api.Detect()


-- plafond du compteur DR : jamais au-dela de 4 (SuperWoW retabli, la section journal l'avait coupe)
EXT.superwow(true)
rawset(_G, "SpellInfo", function(id) return ESP.spells[id] end)
SUI.Api.Detect()
C.Set("modules.esport", false)
C.Set("modules.esport", true)
SETTLE()
ESP.spells[853] = "Hammer of Justice"
for i = 1, 6 do ESP_CAST("0xE1", "0xE2", "CAST", 853) end
EQ("plafond DR a 4", M.enemies["Zed"].dr.stun.count, 4)

-- rafraichissement de la fenetre DR : un 2e controle prolonge la fenetre
ESP.units["raid2target"] = { name = "Zed", cls = "ROGUE", hp = 800, hpMax = 4000, guid = "0xE2", isPlayer = true }
M.enemies["Zed"].dr.stun = nil
ESP_CAST("0xE1", "0xE2", "CAST", 853)
local at1 = M.enemies["Zed"].dr.stun.at
Pump(3)
ESP_CAST("0xE1", "0xE2", "CAST", 853)
T("fenetre DR rafraichie", M.enemies["Zed"].dr.stun.at ~= at1)
EQ("compteur continue", M.enemies["Zed"].dr.stun.count, 2)

-- victime non-joueur : jamais comptee
ESP.units["raid2target"] = { name = "Mob", cls = "WARRIOR", hp = 500, hpMax = 500, guid = "0xE9", isPlayer = false }
ESP_CAST("0xE1", "0xE9", "CAST", 853)
EQ("victime non-joueur ignoree", M.enemies["Mob"] or "none", "none")
ESP.units["raid2target"] = nil

SECTION("t_esport : fenetre, clic, taille")
M.Open()
SETTLE(20)
T("fenetre ouverte", M.win ~= nil and M.win:IsShown())
T("deplacable", SUI.Layout.items["esport.win"] ~= nil)
-- clic sur une ligne : cible la cible de raid2 qui porte le nom
ESP.units["raid2target"] = { name = "Zed", cls = "ROGUE", hp = 800, hpMax = 4000, guid = "0xE2", isPlayer = true }
ESP_CLEAR()
M.row1:GetScript("OnClick")(M.row1)
CONTAINS("clic : cible l'ennemi", ESP_ACTS(), "TargetUnit raid2target")
ESP.units["raid2target"] = nil
-- coupure : fenetre fermee, minuterie rendue
local tasks0 = liveTasks()
C.Set("modules.esport", false)
EQ("module coupe", mod.enabled, false)
EQ("fenetre fermee", M.win:IsShown(), false)
EQ("minuterie rendue", liveTasks(), tasks0 - 1)
EQ("evenements rendus", SUI.handlers["UNIT_CASTEVENT"], nil)
C.Set("modules.esport", true)
SETTLE()
EQ("rallume", mod.enabled, true)
EQ("aucune erreur interne finale " .. tostring(SUI.lastErr), SUI.errCount, 0)
DONE()
