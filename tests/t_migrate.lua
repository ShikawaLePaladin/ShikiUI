-- t_migrate : coexistence avec pfUI et migration module par module (pfUI charge, equivalent actif).
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

-- pfUI simule : modules enregistres par pfUI:RegisterModule (pfUI.module[nom]), configuration par personnage
pfUI = { module = { player = function() end, target = function() end, targettarget = function() end,
  actionbar = function() end, chat = function() end, bgscore = function() end, gm = function() end } }
pfUI_config = { disabled = {}, unitframes = { disable = "0" } }

local function cmd(s)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"](s)
  return CHATTEXT()
end

SECTION("t_migrate : pfUI fait tourner ses cadres -> ShikiUI attend")
BOOT()
SETTLE()
EQ("pfUI detecte", Mg.present, true)
T("module units en attente", not SUI.modules.units.enabled)
EQ("cadres ShikiUI non construits", U.built, false)
EQ("Held units", Mg.Held("units"), true)
EQ("etat wait", Mg.State("units"), "wait")
EQ("trois modules en attente (units, actionbars, chat)", Mg.HeldCount(), 3)
EQ("PlayerFrame intact", bPlayer:IsShown(), true)
T("PlayerFrame garde ses evenements", next(bPlayer.events) ~= nil)
EQ("TargetFrame intact", bTarget:IsShown(), true)
EQ("Blizzard gere par pfUI", Mg.BlizzOwned(), true)
EQ("la case ShikiUI reste cochee", C.Get("modules.units"), true)
CONTAINS("status : wait", cmd("status"), "units=wait")
local rep = cmd("migrate")
CONTAINS("rapport : titre", rep, "pfUI est charge")
CONTAINS("rapport : etat", rep, "en attente de pfUI")
CONTAINS("rapport : modules pfUI restants", rep, "2 modules pfUI n'ont pas encore")
CONTAINS("rapport : Blizzard", rep, "Cadres Blizzard")
local M = SUI.Menu
M.Show("simple")
CONTAINS("menu : message de migration", M.frame.info:GetText(), "/sui migrate")
M.Hide()

SECTION("t_migrate : take / back")
local t = cmd("migrate take units")
EQ("player coupe", pfUI_config.disabled.player, "1")
EQ("target coupe", pfUI_config.disabled.target, "1")
EQ("targettarget coupe", pfUI_config.disabled.targettarget, "1")
EQ("actionbar intact", pfUI_config.disabled.actionbar, nil)
CONTAINS("message take", t, "/reload")
EQ("etat leaving", Mg.State("units"), "leaving")
T("ShikiUI attend le /reload", not SUI.modules.units.enabled)
EQ("pfUI tourne encore cette session", Mg.Running("player"), true)
T("rapport : leaving", string.find(cmd("migrate"), "pfUI coupe", 1, true) ~= nil)
local b = cmd("migrate back units")
EQ("player rendu", pfUI_config.disabled.player, "0")
EQ("targettarget rendu", pfUI_config.disabled.targettarget, "0")
CONTAINS("message back", b, "Retour a pfUI")
EQ("retour : en attente", Mg.State("units"), "wait")
EQ("module inconnu : pas d'effet", Mg.Take("zzz"), false)
CONTAINS("module inconnu : message", cmd("migrate take zzz"), "Module inconnu")
EQ("rien ecrit pour un inconnu", pfUI_config.disabled.zzz, nil)
CONTAINS("sous-commande inconnue : usage", cmd("migrate zzz"), "/sui migrate take")

SECTION("t_migrate : both / hold")
cmd("migrate both units")
EQ("coexistence enregistree", C.GetGlobal("coexist").units, true)
EQ("etat both", Mg.State("units"), "both")
EQ("ShikiUI demarre", SUI.modules.units.enabled, true)
EQ("cadres construits", U.built, true)
EQ("PlayerFrame pas masque (pfUI s'en charge)", bPlayer:IsShown(), true)
T("PlayerFrame garde ses evenements en coexistence", next(bPlayer.events) ~= nil)
EQ("units pris, restent actionbars et chat", Mg.HeldCount(), 2)
CONTAINS("status : on", cmd("status"), "units=on")
-- reglage 'masquer Blizzard' remis a la main pendant que pfUI gere les cadres : sans effet
C.Set("units.hideblizz", false)
C.Set("units.hideblizz", true)
EQ("hideblizz sans effet sous pfUI", bPlayer:IsShown(), true)
cmd("migrate hold units")
EQ("coexistence retiree", C.GetGlobal("coexist").units, nil)
EQ("ShikiUI s'efface", SUI.modules.units.enabled, false)
EQ("etat wait de nouveau", Mg.State("units"), "wait")
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_migrate : donnees corrompues")
C.SetGlobal("coexist", { units = "oui", truc = true })
EQ("valeur invalide ignoree", Mg.Coexist("units"), false)
EQ("cle inconnue purgee", C.GetGlobal("coexist").truc, nil)
C.SetGlobal("coexist", 12)
EQ("table absente reparee", Mg.Coexist("units"), false)
EQ("table recree", type(C.GetGlobal("coexist")), "table")

DONE()
