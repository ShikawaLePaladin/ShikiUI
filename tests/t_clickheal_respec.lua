-- t_clickheal_respec : apres une respec le grimoire est relu (second passage differe, relecture au clic) et un clic n'est jamais avale.
local SUI = ShikiUI
local C = SUI.Config
GRP_SETUP()
EXT.unitxp("real")
BOOT()
SETTLE()
local M = SUI.ClickHeal
local FULL = { { "Flash of Light", "Rank 1" }, { "Holy Light", "Rank 1" }, { "Cleanse", "" }, { "Redemption", "Rank 1" } }
GRP_SPELLS(FULL)
GRP_PARTY(2)
W.partyMembers = 2
C.Set("modules.group", true)
C.Set("modules.clickheal", true)
SETTLE()
Pump(0.3, 3)
local fr = SUI.Group.party.frames[2]
local function casts() return table.getn(GRP.casts) end
local function reset() GRP.casts = {}; W.acts = {}; GRP.mods = {}; Pump(2.5, 1) end

SECTION("t_clickheal_respec : grimoire vide pendant la respec")
reset()
EQ("sort connu au depart", M.IsKnown("Flash of Light"), true)
GRP_SPELLS({})
Fire("CHARACTER_POINTS_CHANGED")
EQ("grimoire vide lu", M.IsKnown("Flash of Light"), false)
CHATCLEAR()
Click(fr, "LeftButton")
EQ("rien de lance", casts(), 0)
EQ("le clic cible quand meme", LASTACT(), "TargetUnit party1")

SECTION("t_clickheal_respec : le client finit de remplir le grimoire sans nouvel evenement")
reset()
GRP_SPELLS(FULL)
Click(fr, "LeftButton")
EQ("relecture au clic : le sort est lance", casts(), 1)
EQ("le bon sort", GRP.casts[1][1], "Flash of Light")

SECTION("t_clickheal_respec : second passage differe")
reset()
GRP_SPELLS({})
Fire("SPELLS_CHANGED")
EQ("vide d'abord", M.IsKnown("Holy Light"), false)
GRP_SPELLS(FULL)
Pump(2.5, 1)
EQ("le passage differe relit le grimoire", M.IsKnown("Holy Light"), true)

SECTION("t_clickheal_respec : en combat rien n'est relu")
W.combat = true
GRP_SPELLS({})
Fire("SPELLS_CHANGED")
T("relecture reportee", M.bookPending == true)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
Pump(0.5, 1)
EQ("apres le combat : grimoire relu (vide)", M.IsKnown("Holy Light"), false)
GRP_SPELLS(FULL)
Fire("SPELLS_CHANGED")
Pump(2.5, 1)
EQ("et de nouveau complet", M.IsKnown("Holy Light"), true)

SECTION("t_clickheal_respec : module coupe, plus d'ecoute")
C.Set("modules.clickheal", false)
GRP_SPELLS({})
Fire("SPELLS_CHANGED")
Pump(2.5, 1)
EQ("coupe : grimoire non relu", M.IsKnown("Holy Light"), true)
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
