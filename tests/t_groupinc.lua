-- t_groupinc : soins entrants de MOI-MEME sur les cadres de groupe / raid (barre qui prolonge la vie pendant mon incantation) :
-- cible lue (cible du jeu, clic ShikiUI annonce, GUID SuperWoW), montant estime (rang du grimoire, bonus de soins), arret de la barre
-- (fin, echec, interruption, delai de securite), reglage "soins entrants de" (moi / tous) avec HealComm, noms francais, cout.
local SUI = ShikiUI
local C = SUI.Config
GRP_SETUP()
EXT.unitxp("real")
BOOT()
SETTLE()
-- cette suite isole le comportement du module GROUPE : les cadres joueur / cible (units.incheal) ne
-- gardent pas les ecoutes de lancement quand le groupe coupe les soins entrants
C.Set("units.incheal", false)
local E = SUI.GroupEngine
local M = SUI.Group
local CH = SUI.ClickHeal

W.units.player.class = "PRIEST"
GRP_SPELLS({ { "Flash Heal", "Rank 1", "Interface\\Icons\\Spell_Holy_FlashHeal" }, { "Flash Heal", "Rank 2", "Interface\\Icons\\Spell_Holy_FlashHeal" },
  { "Holy Light", "Rank 1", "Interface\\Icons\\Spell_Holy_HolyBolt" }, { "Fireball", "Rank 1", "Interface\\Icons\\Spell_Fire_FlameBolt" } })
GRP_PARTY(2)
W.partyMembers = 2
W.units.party2.hp = 2000
C.Set("modules.group", true)
SETTLE()
Pump(0.3, 3)
local g = M.party
local a1, a2 = g.names["Ami1"], g.names["Ami2"]

SECTION("t_groupinc : reglage et valeurs par defaut")
T("option group.incsrc declaree", C.meta["group.incsrc"] ~= nil)
T("option raid.incsrc declaree", C.meta["raid.incsrc"] ~= nil)
EQ("par defaut : tous (moi inclus)", C.Get("group.incsrc"), "all")
for _, k in ipairs({ "group", "raid" }) do
  T("texte " .. k, SUI.L("opt." .. k .. ".incsrc") ~= "opt." .. k .. ".incsrc")
  T("infobulle " .. k, SUI.L("tip." .. k .. ".incsrc") ~= "tip." .. k .. ".incsrc")
  T("choix moi " .. k, SUI.L("choice." .. k .. ".incsrc.me") ~= "choice." .. k .. ".incsrc.me")
  T("choix tous " .. k, SUI.L("choice." .. k .. ".incsrc.all") ~= "choice." .. k .. ".incsrc.all")
end
T("evenements de lancement ecoutes", SUI.handlers.SPELLCAST_START ~= nil and table.getn(SUI.handlers.SPELLCAST_START) > 0)
EQ("rang le plus haut relu dans le grimoire", E.bookRank["Flash Heal"], 2)
EQ("sort hors liste ignore du grimoire", E.bookRank["Fireball"], nil)

SECTION("t_groupinc : montant estime")
EQ("rang 2 sans bonus", E.HealAmount("Flash Heal", 2, 1500), 286)
EQ("rang demande", E.HealAmount("Flash Heal", 1, 1500), 215)
EQ("rang hors table : plafonne", E.HealAmount("Flash Heal", 40, 1500), 885)
EQ("rang absent : plus haut rang connu", E.HealAmount("Flash Heal", nil, 1500), 286)
EQ("sort inconnu : zero", E.HealAmount("Fireball", 1, 1500), 0)
EQ("grimoire inconnu pour ce sort : plus haut rang de la table", E.HealAmount("Greater Heal", nil, 2500), 2194)
rawset(_G, "GetSpellBonusHealing", function() return 350 end)
EQ("bonus de soins x temps d'incantation / 3,5 s", E.HealAmount("Flash Heal", 2, 1500), 436)
EQ("bonus plafonne a 100 % au dela de 3,5 s", E.HealAmount("Greater Heal", 5, 5000), 2544)
rawset(_G, "GetSpellBonusHealing", nil)
EQ("sans l'API de bonus : valeur de base", E.HealAmount("Flash Heal", 2, 1500), 286)
EQ("nom francais reconnu", E.HealKey("Soins rapides"), "Flash Heal")
EQ("nom francais accentue reconnu", E.HealKey("Lumi\195\168re sacr\195\169e"), "Holy Light")
EQ("nom anglais reconnu", E.HealKey("Holy Light"), "Holy Light")
EQ("autre sort : rien", E.HealKey("Fireball"), nil)

SECTION("t_groupinc : ma cible = la cible du jeu")
W.units.target = W.units.party2
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("cadre de la cible : part de soin entrant", a2.incMine, 286)
EQ("autre cadre : rien", a1.incMine or 0, 0)
Pump(0.1, 2)
NEAR("barre : (2000 + 286) / 4000", a2.heal:GetValue(), 0.5715)
Fire("SPELLCAST_STOP")
EQ("fin de l'incantation : part effacee", a2.incMine, 0)
Pump(0.1, 2)
EQ("fin de l'incantation : barre rendue", a2.heal:GetValue(), 0)
Fire("SPELLCAST_START", "Flash Heal", 1500)
Fire("SPELLCAST_INTERRUPTED")
EQ("interrompue : part effacee", a2.incMine, 0)
Fire("SPELLCAST_START", "Flash Heal", 1500)
Fire("SPELLCAST_FAILED")
EQ("echec : part effacee", a2.incMine, 0)
Fire("SPELLCAST_START", "Fireball", 2000)
EQ("sort hors liste : aucune barre", a2.incMine, 0)
Fire("SPELLCAST_START", "Flash Heal", 1500)
Fire("SPELLCAST_START", "Fireball", 2000)
EQ("autre incantation qui remplace : barre retiree", a2.incMine, 0)
W.units.party2.hp = 3900
Fire("SPELLCAST_START", "Flash Heal", 1500)
Pump(0.1, 2)
EQ("barre plafonnee a la vie max", a2.heal:GetValue(), 1)
Fire("SPELLCAST_STOP")
W.units.party2.hp = 2000
Pump(0.1, 2)

SECTION("t_groupinc : cible hostile ou absente -> soi-meme")
W.units.target = nil
local me = g.names[W.units.player.name]
Fire("SPELLCAST_START", "Holy Light", 2500)
EQ("sans cible : moi", E.mine.name, W.units.player.name)
EQ("montant du rang 1 (grimoire)", E.mine.amount, 46)
if me then EQ("mon cadre", me.incMine, 46) end
Fire("SPELLCAST_STOP")
W.units.target = W.units.party1
W.units.party1.friend = false
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("cible hostile : moi, pas la cible", E.mine.name, W.units.player.name)
Fire("SPELLCAST_STOP")
W.units.party1.friend = true

SECTION("t_groupinc : clic ShikiUI -> cible annoncee")
W.units.target = W.units.party2
E.NoteCast("Flash Heal(Rank 1)", "party1")
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("clic : la cible annoncee, pas la cible du jeu", E.mine.name, "Ami1")
EQ("clic : rang annonce", E.mine.amount, 215)
EQ("clic : cadre de la cible annoncee", a1.incMine, 215)
EQ("ancien cadre intact", a2.incMine or 0, 0)
Fire("SPELLCAST_STOP")
EQ("annonce consommee", E.pend.spell, nil)
E.NoteCast("Holy Light", "party1")
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("annonce d'un autre sort : ignoree", E.mine.name, "Ami2")
Fire("SPELLCAST_STOP")
E.NoteCast("Flash Heal", "party1")
E.pend.at = E.pend.at - 5
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("annonce perimee : ignoree", E.mine.name, "Ami2")
Fire("SPELLCAST_STOP")
-- par le vrai chemin du clic (ClickHeal)
W.units.target = W.units.party2
C.Set("modules.clickheal", true)
SETTLE()
GRP.casts = {}
local used = nil
local realNote = E.NoteCast
E.NoteCast = function(spell, unit) used = spell .. "|" .. unit; realNote(spell, unit) end
CH.CastOn("party1", "Flash Heal(Rank 2)")
E.NoteCast = realNote
EQ("ClickHeal annonce le lancement", used, "Flash Heal(Rank 2)|party1")
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("ClickHeal : cible du clic", E.mine.name, "Ami1")
EQ("ClickHeal : rang du clic", E.mine.amount, 286)
Fire("SPELLCAST_STOP")

SECTION("t_groupinc : le jeton d unite change de joueur")
W.units.target = W.units.party2
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("part sur Ami2", a2.incMine, 286)
W.units.party2.name = "Nouveau"
Fire("PARTY_MEMBERS_CHANGED")
Pump(0.3, 3)
EQ("un autre joueur sous ce jeton : pas de part", a2.incMine, 0)
W.units.party2.name = "Ami2"
Fire("PARTY_MEMBERS_CHANGED")
Pump(0.3, 3)
EQ("le nom revient : la part suit le nom", a2.incMine, 286)
Fire("SPELLCAST_STOP")

SECTION("t_groupinc : delai de securite (fin jamais signalee)")
W.units.target = W.units.party2
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("incantation en cours", a2.incMine, 286)
NOW = NOW + 5
Pump(0.5, 4)
EQ("jamais d'arret signale : barre retiree au tour lent", a2.incMine, 0)

SECTION("t_groupinc : reglage moi / tous avec HealComm")
GRP_ACE(true, false)
C.Set("group.incoming", false)
C.Set("group.incoming", true)
GRP.heals.Ami2 = 1000
Pump(0.25, 3)
EQ("tous : soins des autres lus", a2.inc, 1000)
Fire("SPELLCAST_START", "Flash Heal", 1500)
Pump(0.1, 2)
NEAR("tous : le plus grand des deux (pas d'addition, HealComm compte deja mon soin)", a2.heal:GetValue(), 0.75)
Fire("SPELLCAST_STOP")
GRP.heals.Ami2 = 100
Pump(0.25, 3)
Fire("SPELLCAST_START", "Flash Heal", 1500)
Pump(0.1, 2)
NEAR("tous : ma part si elle est plus grande", a2.heal:GetValue(), 0.5715)
Fire("SPELLCAST_STOP")
GRP.heals.Ami2 = 1000
C.Set("group.incsrc", "me")
Pump(0.25, 3)
EQ("moi seulement : soins des autres coupes", a2.inc, 0)
Fire("SPELLCAST_START", "Flash Heal", 1500)
Pump(0.1, 2)
NEAR("moi seulement : ma part reste", a2.heal:GetValue(), 0.5715)
Fire("SPELLCAST_STOP")
Pump(0.1, 2)
EQ("moi seulement : fin", a2.heal:GetValue(), 0)
C.Set("group.incsrc", "all")
Pump(0.25, 3)
EQ("retour a tous : relus", a2.inc, 1000)
-- pont Units (cadres joueur / cible) : la meme source sert les barres de pre-soin hors groupe
GRP.heals[W.units.player.name] = 500
EQ("pont Units : HealComm pour le joueur", SUI.UnitsIncoming("player", W.units.player.name, nil), 500)
EQ("pont Units : mon incantation prise en compte (max, pas d'addition)", (function()
  Fire("SPELLCAST_START", "Flash Heal", 1500)
  local v = SUI.UnitsIncoming("party2", "Ami2", nil)
  Fire("SPELLCAST_STOP")
  return v
end)(), 1000)
EQ("pont Units : un nom sans soin", SUI.UnitsIncoming("player", "Inconnu", nil), 0)
GRP.heals[W.units.player.name] = nil
GRP.heals.Ami2 = 0
Pump(0.25, 3)
GRP_NOACE()

SECTION("t_groupinc : desactivation")
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("part presente", a2.incMine, 286)
C.Set("group.incoming", false)
EQ("incoming coupe : part remise a zero aussitot", a2.incMine, 0)
Pump(0.1, 2)
EQ("incoming coupe : barre vide", a2.heal:GetValue(), 0)
EQ("incoming coupe : evenements de lancement non ecoutes", SUI.handlers.SPELLCAST_START == nil, true)
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("incoming coupe : rien ne se passe", a2.incMine, 0)
C.Set("group.incoming", true)
EQ("rallume : evenements ecoutes", SUI.handlers.SPELLCAST_START ~= nil, true)
Fire("SPELLCAST_STOP")

SECTION("t_groupinc : cible exacte par GUID (SuperWoW)")
EXT.superwow(true)
SUI.Api.Detect()
local NAMES = { [2061] = "Flash Heal", [99] = "Fireball" }
SpellInfo = function(id) return NAMES[id] end
E.myGuid = nil
C.Set("group.incoming", false)
C.Set("group.incoming", true)
Pump(0.1, 3)
T("UNIT_CASTEVENT ecoute", SUI.handlers.UNIT_CASTEVENT ~= nil)
W.units.target = W.units.party1
Fire("UNIT_CASTEVENT", "0xP1", "0xGparty2", "START", 2061, 1500)
EQ("GUID : cible exacte (pas la cible du jeu)", E.mine.name, "Ami2")
EQ("GUID : montant", E.mine.amount, 286)
EQ("GUID : cadre", a2.incMine, 286)
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("l'evenement 1.12 ne remplace pas la cible exacte", E.mine.name, "Ami2")
Fire("UNIT_CASTEVENT", "0xGparty1", "0xGparty2", "START", 2061, 1500)
EQ("incantation d'un autre : ignoree", E.mine.src, "sw")
Fire("UNIT_CASTEVENT", "0xP1", "0xGparty2", "FAIL", 2061)
EQ("GUID : echec efface", a2.incMine, 0)
Fire("UNIT_CASTEVENT", "0xP1", "0xGparty1", "START", 99, 1500)
EQ("GUID : sort hors liste ignore", E.mine.name, nil)
Fire("UNIT_CASTEVENT", "0xP1", "", "START", 2061, 1500)
EQ("GUID : sans cible = moi", E.mine.name, W.units.player.name)
Fire("UNIT_CASTEVENT", "0xP1", "", "CAST", 2061)
EQ("GUID : lancement termine efface", E.mine.name, nil)
Fire("UNIT_CASTEVENT", "0xP1", "0xUNKNOWN", "START", 2061, 1500)
EQ("GUID : cible hors groupe ignoree", E.mine.name, nil)
EXT.superwow(false)

SECTION("t_groupinc : raid")
GRP_CLEAR()
GRP_RAID(10)
W.raidMembers = 10
C.Set("modules.group", false)
C.Set("modules.raid", true)
SETTLE()
Pump(0.3, 4)
local R = SUI.Raid.g
local r3 = R.names["Raider3"]
T("cadre de raid", r3 ~= nil)
W.units.target = W.units.raid3
Fire("SPELLCAST_START", "Flash Heal", 1500)
EQ("raid : part de soin entrant", r3 and r3.incMine, 286)
Fire("SPELLCAST_STOP")
EQ("raid : fin", r3 and r3.incMine, 0)

EQ("aucune erreur interne", SUI.errCount, 0)

DONE()
