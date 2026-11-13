-- t_migrate2 : pfUI present mais son equivalent est coupe (apres /reload), cas limites, modules sans equivalent.
local SUI = ShikiUI
local C = SUI.Config
local U = SUI.Units
local Mg = SUI.Migrate

local bPlayer = CreateFrame("Frame", "PlayerFrame", UIParent)
bPlayer:RegisterEvent("UNIT_HEALTH")
local bTarget = CreateFrame("Frame", "TargetFrame", UIParent)
bTarget:RegisterEvent("PLAYER_TARGET_CHANGED")
CreateFrame("Frame", "PlayerFrameDropDown", UIParent)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)

local function mods(names)
  local t = {}
  for i = 1, table.getn(names) do t[names[i]] = function() end end
  return { module = t }
end

local function cmd(s)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"](s)
  return CHATTEXT()
end

SECTION("t_migrate2 : l'equivalent pfUI est coupe au demarrage -> ShikiUI prend la main")
pfUI = mods({ "player", "target", "targettarget", "actionbar" })
pfUI_config = { disabled = { player = "1", target = "1", targettarget = "1" }, unitframes = { disable = "0" } }
BOOT()
SETTLE()
EQ("pfUI detecte", Mg.present, true)
EQ("ShikiUI actif", SUI.modules.units.enabled, true)
EQ("cadres construits", U.built, true)
EQ("etat shiki", Mg.State("units"), "shiki")
EQ("seul actionbars reste en attente", Mg.HeldCount(), 1)
EQ("Blizzard libre", Mg.BlizzOwned(), false)
EQ("PlayerFrame masque par ShikiUI", bPlayer:IsShown(), false)
EQ("TargetFrame masque par ShikiUI", bTarget:IsShown(), false)
CONTAINS("status : on", cmd("status"), "units=on")
CONTAINS("rapport : ShikiUI actif", cmd("migrate"), "ShikiUI actif")

SECTION("t_migrate2 : retour de pfUI (config rechargee, session inchangee)")
Mg.Back("units")
EQ("etat returning", Mg.State("units"), "returning")
EQ("ShikiUI reste actif jusqu'au /reload", SUI.modules.units.enabled, true)
Mg.Take("units")
EQ("de nouveau shiki", Mg.State("units"), "shiki")

SECTION("t_migrate2 : cas limites de la detection")
-- cadres d'unites de pfUI desactives globalement
pfUI_config = { disabled = {}, unitframes = { disable = "1" } }
EQ("unitframes.disable coupe les modules de cadres", Mg.ConfigRuns("player"), false)
EQ("... mais pas actionbar", Mg.ConfigRuns("actionbar"), true)
-- module absent chez pfUI
pfUI_config = { disabled = {}, unitframes = {} }
EQ("module jamais enregistre", Mg.ConfigRuns("focus"), false)
-- configuration absente ou invalide
pfUI_config = nil
EQ("sans configuration : pfUI tourne", Mg.ConfigRuns("player"), true)
pfUI_config = { disabled = "oui", unitframes = 3 }
EQ("configuration invalide ignoree", Mg.ConfigRuns("player"), true)
EQ("Take repare une table disabled invalide", (Mg.Take("units")), true)
EQ("la table disabled recree", type(pfUI_config.disabled), "table")
pfUI_config = nil
local ok, key = Mg.Take("units")
EQ("Take sans configuration : refuse", ok, false)
EQ("... avec le bon message", key, "migrate.nopfui")
pfUI_config = { disabled = {}, unitframes = {} }
-- pfUI charge mais sans aucun equivalent enregistre : rien a couper
pfUI = mods({ "actionbar" })
local ok2, key2 = Mg.Take("units")
EQ("Take sans equivalent chez pfUI : refuse", ok2, false)
EQ("... message", key2, "migrate.nopfui")
EQ("... rien ecrit", pfUI_config.disabled.actionbar, nil)
-- seul 'player' tourne : le module attend, Blizzard gere par pfUI
pfUI = mods({ "player" })
Mg.Boot()
EQ("un seul equivalent actif suffit pour attendre", Mg.Held("units"), true)
EQ("Blizzard gere par pfUI (player)", Mg.BlizzOwned(), true)
-- seul 'targettarget' tourne : ShikiUI attend aussi, mais Blizzard n'est pas gere par pfUI
pfUI = mods({ "targettarget" })
Mg.Boot()
EQ("targettarget seul : attend", Mg.Held("units"), true)
EQ("targettarget seul : Blizzard libre", Mg.BlizzOwned(), false)
-- module sans equivalent
EQ("module hors table : jamais retenu", Mg.Held("perf"), false)
EQ("module inconnu : etat libre", Mg.State("zzz"), "free")
-- pfUI disparu
pfUI = nil
Mg.Boot()
EQ("pfUI absent : Boot le note", Mg.present, false)
EQ("pfUI absent : rien retenu", Mg.Held("units"), false)
EQ("pfUI absent : Blizzard libre", Mg.BlizzOwned(), false)
EQ("pfUI absent : etat libre", Mg.State("units"), "free")
CONTAINS("pfUI absent : rapport", cmd("migrate"), "pfUI n'est pas charge")
CONTAINS("pfUI absent : take refuse", cmd("migrate take units"), "rien a migrer")
EQ("aucune erreur interne", SUI.errCount, 0)

DONE()
