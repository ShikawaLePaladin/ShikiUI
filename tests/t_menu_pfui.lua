-- t_menu_pfui : le menu face a pfUI (etat "en attente", bouton Migrer, carte pfUI de l'accueil).
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Menu
local Mg = SUI.Migrate

CreateFrame("Frame", "PlayerFrame", UIParent)
CreateFrame("Frame", "TargetFrame", UIParent)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
pfUI = { module = { player = function() end, target = function() end, targettarget = function() end,
  actionbar = function() end, chat = function() end } }
pfUI_config = { disabled = {}, unitframes = { disable = "0" } }

local function mcardFor(name)
  for i = 1, M.used.mcard do
    if M.pools.mcard[i].modName == name then return M.pools.mcard[i] end
  end
end

SECTION("t_menu_pfui : modules en attente")
BOOT()
SETTLE()
SlashCmdList["SHIKIUI"]("")
EQ("pfUI detecte", Mg.Present(), true)
local held = Mg.HeldCount()
T("modules en attente", held >= 1)
EQ("etat de units", M.State("units"), "wait")
M.Open("home")
local card
for i = 1, M.used.stat do if M.pools.stat[i].title:GetText() == "PFUI" then card = M.pools.stat[i] end end
T("carte pfUI", card ~= nil)
EQ("pfUI detecte", card.value:GetText(), "Detecte")
CONTAINS("modules en attente", card.sub:GetText(), tostring(held))
EQ("bouton Migrer", card.b1:IsShown(), true)
EQ("bouton Migrer : libelle", card.b1.label:GetText(), "Migrer")
card.b1:Click()
EQ("Migrer : page Modules", M.page, "modules")
EQ("Migrer : filtre En attente", M.filter, "wait")
local nwait = 0
for i = 1, table.getn(SUI.moduleOrder) do if M.State(SUI.moduleOrder[i]) == "wait" then nwait = nwait + 1 end end
T("au moins un module en attente", nwait >= 1)
EQ("seulement les modules en attente", M.used.mcard, nwait)
local cu = mcardFor("units")
T("carte units en attente", cu ~= nil)
CONTAINS("etat", cu.state:GetText(), "En attente de pfUI")
EQ("bouton Migrer sur la carte", cu.mig:IsShown(), true)
EQ("pastille d'etat", cu.dot.vc[1] == M.StateColor("wait")[1], true)
CONTAINS("pied : migration", M.frame.info:GetText(), "/sui migrate")
-- confirmation en deux clics
cu.mig:Click()
EQ("1er clic : confirmation", cu.mig.label:GetText(), "Confirmer ?")
EQ("rien n'est pris", pfUI_config.disabled.player, nil)
Pump(3.1)
EQ("delai ecoule", cu.mig.label:GetText(), "Migrer")
cu.mig:Click()
Pump(1)
cu.mig:Click()
EQ("2e clic : ShikiUI prend le module", Mg.State("units"), "leaving")
EQ("pfUI coupe pour ce module", pfUI_config.disabled.player, "1")
CHATCLEAR()
M.Open("cat", "units")
CONTAINS("etat dans l'entete", M.frame.head.status:GetText(), "")
DONE()
