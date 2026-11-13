-- t_groupmana : barre de mana des soigneurs / lanceurs dans les cadres de groupe et de raid (option manabar : none / healers / casters / all),
-- rage et energie exclues hors "all", cadre sans barre = barre de vie pleine hauteur, evenements de puissance ecoutes seulement si utiles.
local SUI = ShikiUI
local C = SUI.Config
GRP_SETUP()
EXT.unitxp("real")
BOOT()
SETTLE()
local E = SUI.GroupEngine
local M = SUI.Group

local function frames() return M.party.frames end
local function flush() Pump(0.1, 4) end

SECTION("t_groupmana : groupe, soigneurs seulement")
GRP_PARTY(4, { { class = "PRIEST" }, { class = "WARRIOR" }, { class = "MAGE" }, { class = "DRUID" } })
W.units.player.class = "HUNTER"
C.Set("modules.group", true)
SETTLE()
flush()
local pr, wa, ma, dr, hu = frames()[2], frames()[3], frames()[4], frames()[5], frames()[1]
EQ("defaut : toutes les ressources", C.Get("group.manabar"), "all")
EQ("defaut : guerrier avec barre", wa.pw:IsShown(), true)
C.Set("group.manabar", "healers")
flush()
EQ("soigneur (pretre) : barre", pr.pw:IsShown(), true)
EQ("guerrier : pas de barre", wa.pw:IsShown(), false)
EQ("mage : pas de barre (soigneurs seulement)", ma.pw:IsShown(), false)
EQ("druide : barre", dr.pw:IsShown(), true)
EQ("chasseur : pas de barre", hu.pw:IsShown(), false)
-- la barre de vie reprend la hauteur quand la barre de mana est cachee
local h = C.Get("group.height")
EQ("avec barre : vie = hauteur - 3 - puissance", pr.hp:GetHeight(), h - 3 - C.Get("group.powerheight"))
EQ("sans barre : vie pleine hauteur", wa.hp:GetHeight(), h - 2)
EQ("evenement de mana ecoute", M.party.evOn.UNIT_MANA, true)
EQ("evenement de rage non ecoute", M.party.evOn.UNIT_RAGE == true, false)
EQ("evenement d'energie non ecoute", M.party.evOn.UNIT_ENERGY == true, false)
EQ("changement de forme ecoute", M.party.evOn.UNIT_DISPLAYPOWER, true)

SECTION("t_groupmana : valeur, formes du druide, rafraichissement")
W.units.party1.mana = 1000
Fire("UNIT_MANA", "party1")
flush()
NEAR("mana a moitie", pr.pw:GetValue(), 0.5)
-- le druide passe en ours : plus de mana lisible, la barre disparait
W.units.party4.ptype = 1
W.units.party4.manaMax = 100
W.units.party4.mana = 100
Fire("UNIT_DISPLAYPOWER", "party4")
flush()
EQ("druide en ours : barre cachee", dr.pw:IsShown(), false)
EQ("druide en ours : vie pleine hauteur", dr.hp:GetHeight(), h - 2)
W.units.party4.ptype = 0
W.units.party4.manaMax = 2000
W.units.party4.mana = 2000
Fire("UNIT_DISPLAYPOWER", "party4")
flush()
EQ("druide de retour : barre", dr.pw:IsShown(), true)
-- mort : pas de barre
W.units.party1.dead = true
Fire("UNIT_HEALTH", "party1")
flush()
EQ("soigneur mort : barre cachee", pr.pw:IsShown(), false)
W.units.party1.dead = nil
Fire("UNIT_HEALTH", "party1")
flush()
EQ("soigneur relevé : barre", pr.pw:IsShown(), true)

SECTION("t_groupmana : tous les lanceurs, chasseurs, aucune")
C.Set("group.manabar", "casters")
flush()
EQ("lanceurs : mage", ma.pw:IsShown(), true)
EQ("lanceurs : guerrier non", wa.pw:IsShown(), false)
EQ("lanceurs : chasseur non par defaut", hu.pw:IsShown(), false)
C.Set("group.manahunter", true)
flush()
EQ("option chasseurs : barre", hu.pw:IsShown(), true)
C.Set("group.manahunter", false)
flush()
EQ("option chasseurs retiree", hu.pw:IsShown(), false)
C.Set("group.manabar", "none")
flush()
EQ("aucune : pretre sans barre", pr.pw:IsShown(), false)
EQ("aucune : plus d'evenement de mana", M.party.evOn.UNIT_MANA, false)
C.Set("group.manabar", "all")
flush()
EQ("toutes : guerrier de nouveau", wa.pw:IsShown(), true)
EQ("toutes : evenement de rage ecoute", M.party.evOn.UNIT_RAGE, true)

SECTION("t_groupmana : role manuel et pourcentage")
C.Set("group.manabar", "healers")
C.Set("group.roles", "Ami2:H;Ami1:D")
flush()
EQ("role H force la barre (guerrier)", wa.pw:IsShown(), true)
EQ("role D retire la barre (pretre)", pr.pw:IsShown(), false)
C.Set("group.roles", "")
flush()
C.Set("group.manatext", true)
flush()
W.units.party2.mana = 500
-- guerrier ayant pour role H : mana 500 / 2000
C.Set("group.roles", "Ami2:H")
flush()
EQ("pourcentage ecrit", wa.pwText:GetText(), "25")
EQ("pourcentage visible", wa.pwText:IsShown(), true)
C.Set("group.manatext", false)
flush()
EQ("pourcentage coupe", wa.pwText:IsShown(), false)
C.Set("group.roles", "")
flush()

SECTION("t_groupmana : raid")
EQ("raid : defaut soigneurs", C.Get("raid.manabar"), "healers")
EQ("raid : option declaree", SUI.modules.raid.options ~= nil, true)
local found = 0
for i = 1, table.getn(SUI.modules.raid.options) do
  local k = SUI.modules.raid.options[i].key
  if k == "raid.manabar" or k == "raid.manahunter" or k == "raid.manatext" then found = found + 1 end
end
EQ("raid : 3 options de mana", found, 3)
GRP_RAID(25, { {}, { class = "PRIEST" }, { class = "ROGUE" }, { class = "WARLOCK" } })
C.Set("raid.powerheight", 4)
C.Set("modules.raid", true)
SETTLE()
Pump(0.3, 6)
local g = SUI.Raid.g
local function rf(i) for k = 1, g.nOrder do if g.order[k].unit == "raid" .. i then return g.order[k] end end end
EQ("raid : evenement de mana ecoute", g.evOn.UNIT_MANA, true)
EQ("raid : pas d'evenement d'energie", g.evOn.UNIT_ENERGY == true, false)
EQ("raid : pretre avec barre", rf(2).pw:IsShown(), true)
EQ("raid : voleur sans barre", rf(3).pw:IsShown(), false)
EQ("raid : demoniste sans barre (soigneurs)", rf(4).pw:IsShown(), false)
C.Set("raid.manabar", "casters")
Pump(0.3, 6)
EQ("raid casters : demoniste avec barre", rf(4).pw:IsShown(), true)
EQ("raid casters : voleur sans barre", rf(3).pw:IsShown(), false)
-- en raid a 40 : un evenement de mana ne touche qu'un cadre
local q0 = g.qn
W.units.raid2.mana = 100
Fire("UNIT_MANA", "raid2")
EQ("un seul cadre en file", g.qn - q0, 1)
Pump(0.3, 6)
NEAR("valeur de mana du pretre", rf(2).pw:GetValue(), 0.05)
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
