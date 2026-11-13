-- t_groupheal : cadres de groupe / raid pour soigneurs : type de debuff a dissiper (priorite, marque), HoT / boucliers du joueur avec
-- duree (sans et avec SuperWoW), resurrection en cours (SuperWoW, HealComm, Puppeteer), soins entrants Puppeteer (PTHealPredict) a
-- defaut de HealComm, jeton "rinse" du clic (Rinse present / absent), note des HoT lances par un clic.
local SUI = ShikiUI
local C = SUI.Config
GRP_SETUP()
EXT.unitxp("real")
BOOT()
SETTLE()
-- cette suite isole le comportement du module GROUPE (ecoutes_coupees quand rien n'est voulu) :
-- les cadres joueur / cible (units.incheal) ne maintiennent pas les ecoutes a elles seules
C.Set("units.incheal", false)
local E = SUI.GroupEngine
local M = SUI.Group
local CH = SUI.ClickHeal

local RENEW = "Interface\\Icons\\Spell_Holy_Renew"
local REJ = "Interface\\Icons\\Spell_Nature_Rejuvenation"
local OTHER = "Interface\\Icons\\Spell_Holy_WordFortitude"
local D_DIS = "Interface\\Icons\\Spell_Nature_NullifyDisease"
local D_MAG = "Interface\\Icons\\Spell_Nature_Slow"
local D_CUR = "Interface\\Icons\\Spell_Shadow_CurseOfTounges"

W.units.player.class = "PRIEST"
GRP_SPELLS({ { "Cleanse", "", "Interface\\Icons\\Spell_Holy_Renew_Cleanse" }, { "Renew", "Rank 1", RENEW },
  { "Renew", "Rank 2", RENEW }, { "Rejuvenation", "Rank 1", REJ }, { "Resurrection", "Rank 1", "Interface\\Icons\\Spell_Holy_Resurrection" } })
GRP_PARTY(2)
W.partyMembers = 2
C.Set("modules.group", true)
SETTLE()
Pump(0.3, 3)
local function frames() return M.party.frames end
local a0, a1 = frames()[1], frames()[2]

SECTION("t_groupheal : options et valeurs par defaut")
for _, k in ipairs({ "hots", "hotall", "dispelstyle", "dispelprio", "resinfo" }) do
  T("option group." .. k .. " declaree", C.meta["group." .. k] ~= nil)
  T("option raid." .. k .. " declaree", C.meta["raid." .. k] ~= nil)
  T("texte FR group." .. k, SUI.L("opt.group." .. k) ~= "opt.group." .. k)
  T("texte FR raid." .. k, SUI.L("opt.raid." .. k) ~= "opt.raid." .. k)
end
EQ("HoT par defaut (groupe)", C.Get("group.hots"), 2)
EQ("marque par defaut : liseré + cadre", C.Get("group.dispelstyle"), "both")
EQ("type prioritaire par defaut", C.Get("group.dispelprio"), "magic")
EQ("jeton rinse propose", (function() for i = 1, table.getn(CH.choices) do if CH.choices[i] == "rinse" then return true end end return false end)(), true)

SECTION("t_groupheal : debuff dissipable, priorite des types")
EQ("Cleanse relu : magie dissipable", E.cure.Magic, true)
EQ("Cleanse relu : malediction non dissipable", E.cure.Curse, nil)
W.units.party1.debuffs = { { D_DIS, 1, "Disease" }, { D_MAG, 1, "Magic" }, { D_CUR, 1, "Curse" } }
Fire("UNIT_AURA", "party1")
Pump(0.1, 2)
EQ("priorite magie : type retenu", a1.dispelType, "Magic")
local cm = E.DEBUFF_COL.Magic
EQ("liseré : couleur du type", a1.dispelTx.vc[1], cm[1])
C.Set("group.dispelprio", "disease")
Pump(0.1, 2)
EQ("priorite maladie : type retenu", a1.dispelType, "Disease")
EQ("liseré repeint", a1.dispelTx.vc[1], E.DEBUFF_COL.Disease[1])
C.Set("group.dispelprio", "curse")
Pump(0.1, 2)
EQ("priorite malediction mais non dissipable : repli sur la magie", a1.dispelType, "Magic")
C.Set("group.dispelprio", "magic")
C.Set("group.dispelstyle", "stripe")
Pump(0.1, 2)
EQ("style liseré : liseré visible", a1.dispelTx:IsShown(), true)
EQ("style liseré : cadre non teinte", a1.dispelHl:IsShown(), false)
C.Set("group.dispelstyle", "frame")
Pump(0.1, 2)
EQ("style cadre : liseré cache", a1.dispelTx:IsShown(), false)
EQ("style cadre : cadre teinte", a1.dispelHl:IsShown(), true)
EQ("teinte : couleur du type", a1.dispelHl.vc[1], cm[1])
NEAR("teinte : transparence", a1.dispelHl.vc[4], 0.32)
C.Set("group.dispelstyle", "both")
Pump(0.1, 2)
EQ("style les deux : liseré", a1.dispelTx:IsShown(), true)
EQ("style les deux : teinte", a1.dispelHl:IsShown(), true)
W.units.party1.debuffs = {}
Fire("UNIT_AURA", "party1")
Pump(0.1, 2)
EQ("plus de debuff : liseré cache", a1.dispelTx:IsShown(), false)
EQ("plus de debuff : teinte cachee", a1.dispelHl:IsShown(), false)

SECTION("t_groupheal : HoT du joueur sans SuperWoW")
EQ("grimoire : texture de Renew relevee", E.hotTex[RENEW], "Renew")
EQ("grimoire : texture de Rejuvenation relevee", E.hotTex[REJ], "Rejuvenation")
EQ("minuterie des durees active", GRP_TASKS("Group.hot"), 1)
W.units.party1.buffs = { { OTHER, 1 }, { RENEW, 1 } }
Fire("UNIT_AURA", "party1")
Pump(0.1, 2)
EQ("HoT d'un autre lanceur : masque par defaut", a1.hN, 0)
C.Set("group.hotall", true)
Pump(0.1, 2)
EQ("option tous les lanceurs : icone", a1.hN, 1)
EQ("icone : texture de l'aura", a1.hTex[1], RENEW)
EQ("icone visible", a1.hIcon[1]:IsShown(), true)
EQ("sans lancement connu : pas de duree", a1.hTime[1]:GetText(), "")
C.Set("group.hotall", false)
Pump(0.1, 2)
EQ("option coupee : icone retiree", a1.hN, 0)
EQ("icone cachee", a1.hIcon[1]:IsShown(), false)
E.NoteHot("Ami1", "Renew")
Pump(0.1, 2)
EQ("HoT lance par moi : icone", a1.hN, 1)
EQ("duree affichee (15 s)", a1.hTime[1]:GetText(), "15")
Pump(5, 1)
EQ("duree decomptee", a1.hTime[1]:GetText(), "10")
EQ("2e HoT sur un autre sort inconnu : ignore", a1.hN, 1)
Pump(11, 1)
Pump(0.1, 3)
EQ("HoT expire : icone retiree", a1.hN, 0)
EQ("HoT expire : texte efface", a1.hTime[1]:GetText(), "")
-- disposition : les buffs sont decales pour laisser la place aux HoT
C.Set("group.buffs", 2)
Pump(0.1, 2)
EQ("HoT 1 colle a droite", a1.hIcon[1].points[1][4], -2)
EQ("HoT 2 a cote", a1.hIcon[2].points[1][4], -15)
EQ("buffs decales de 2 icones", a1.bIcon[1].points[1][4], -28)
C.Set("group.hots", 0)
Pump(0.1, 2)
EQ("HoT a zero : minuterie des durees coupee", GRP_TASKS("Group.hot"), 0)
EQ("HoT a zero : buffs de nouveau a droite", a1.bIcon[1].points[1][4], -2)
C.Set("group.buffs", 0)
C.Set("group.hots", 2)
Pump(0.1, 2)
EQ("HoT reactives : minuterie des durees", GRP_TASKS("Group.hot"), 1)
-- mon propre cadre : le temps restant vient du jeu
W.units.player.buffs = { { RENEW, 1, 7.4 } }
E.NoteHot("Shikiwa", "Renew")
Pump(0.1, 2)
EQ("mon cadre : icone de HoT", a0.hN, 1)
EQ("mon cadre : temps restant du jeu (7,4 -> 8)", a0.hTime[1]:GetText(), "8")
W.units.player.buffs = nil
-- plafond de 4 icones et plusieurs sorts
W.units.party1.buffs = { { RENEW, 1 }, { REJ, 1 } }
C.Set("group.hotall", true)
Pump(0.1, 2)
EQ("deux HoT differents : deux icones", a1.hN, 2)
C.Set("group.hots", 1)
Pump(0.1, 2)
EQ("limite a une icone", a1.hN, 1)
C.Set("group.hotall", false)
C.Set("group.hots", 2)
W.units.party1.buffs = {}
Pump(0.1, 2)

SECTION("t_groupheal : HoT et resurrection avec SuperWoW (UNIT_CASTEVENT)")
EXT.superwow(true)
SUI.Api.Detect()
local NAMES = { [774] = "Rejuvenation", [10] = "Resurrection", [99] = "Fireball" }
SpellInfo = function(id) return NAMES[id] end
E.myGuid = nil
C.Set("group.hots", 3)
Pump(0.1, 3)
EQ("UNIT_CASTEVENT ecoute (HoT)", SUI.handlers.UNIT_CASTEVENT ~= nil, true)
EQ("GUID releve sur le cadre", a1.guid, "0xGparty1")
W.units.party1.buffs = { { REJ, 1 } }
Fire("UNIT_AURA", "party1")
Pump(0.1, 2)
EQ("pas encore lance : aucune icone", a1.hN, 0)
Fire("UNIT_CASTEVENT", "0xGparty2", "0xGparty1", "CAST", 774)
Pump(0.1, 2)
EQ("sort d'un autre joueur : ignore", a1.hN, 0)
Fire("UNIT_CASTEVENT", "0xP1", "0xGparty1", "CAST", 99)
Pump(0.1, 2)
EQ("sort non suivi : ignore", a1.hN, 0)
Fire("UNIT_CASTEVENT", "0xP1", "0xGparty1", "CAST", 774)
Pump(0.1, 2)
EQ("mon Rejuvenation : icone", a1.hN, 1)
EQ("mon Rejuvenation : 12 s", a1.hTime[1]:GetText(), "12")
-- l'ajout par un clic ShikiUI est ignore quand SuperWoW suit deja les lancements
E.hotEnd.Renew.Ami1 = nil
-- resurrection
W.units.party1.dead = true
Fire("UNIT_HEALTH", "party1")
Pump(0.1, 2)
EQ("mort : texte du jeu", a1.statusText:GetText(), SUI.L("unit.dead"))
Fire("UNIT_CASTEVENT", "0xGparty2", "0xGparty1", "START", 10, 10000)
Pump(0.1, 2)
EQ("resurrection en cours : texte", a1.statusText:GetText(), SUI.L("msg.group.res"))
EQ("resurrection : couleur du jeton good", a1.statusText.tc[1], SUI.Theme.c.good[1])
Fire("UNIT_CASTEVENT", "0xGparty2", "0xGparty1", "FAIL", 10)
Pump(0.1, 2)
EQ("resurrection interrompue : texte mort", a1.statusText:GetText(), SUI.L("unit.dead"))
EQ("resurrection interrompue : couleur d'avertissement", a1.statusText.tc[1], SUI.Theme.c.warn[1])
Fire("UNIT_CASTEVENT", "0xGparty2", "0xGparty1", "START", 10, 10000)
Pump(0.1, 2)
C.Set("group.resinfo", false)
Pump(0.1, 2)
EQ("resinfo coupe : texte mort", a1.statusText:GetText(), SUI.L("unit.dead"))
C.Set("group.resinfo", true)
Pump(0.1, 2)
EQ("resinfo reactive : resurrection toujours suivie", a1.statusText:GetText(), SUI.L("msg.group.res"))
Fire("UNIT_CASTEVENT", "0xGparty2", "0xGparty1", "FAIL", 10)
Pump(0.1, 2)
-- ecoute coupee quand rien ne la demande
C.Set("group.hots", 0)
C.Set("group.resinfo", false)
C.Set("raid.resinfo", false)
Pump(0.1, 2)
T("soins entrants (mes soins) : UNIT_CASTEVENT reste ecoute pour la cible exacte", SUI.handlers.UNIT_CASTEVENT ~= nil and table.getn(SUI.handlers.UNIT_CASTEVENT) > 0)
C.Set("group.incoming", false)
C.Set("raid.incoming", false)
Pump(0.1, 2)
EQ("plus de HoT, de resurrection ni de soins entrants : UNIT_CASTEVENT non ecoute", SUI.handlers.UNIT_CASTEVENT == nil, true)
C.Set("group.incoming", true)
C.Set("raid.incoming", true)
C.Set("group.resinfo", true)
C.Set("group.hots", 2)
Pump(0.1, 2)

SECTION("t_groupheal : resurrection HealComm / Puppeteer, soins entrants Puppeteer")
-- HealComm
GRP_ACE(true, false)
C.Set("group.resinfo", false)
C.Set("group.resinfo", true)
GRP.resurrecting.Ami1 = true
Pump(0.3, 4)
EQ("HealComm : resurrection en cours", a1.statusText:GetText(), SUI.L("msg.group.res"))
GRP.resurrecting.Ami1 = nil
Pump(0.3, 4)
EQ("HealComm : fin de resurrection", a1.statusText:GetText(), SUI.L("unit.dead"))
GRP_NOACE()
C.Set("group.resinfo", false)
C.Set("group.resinfo", true)
-- Puppeteer (PTHealPredict) : resurrection et soins entrants
W.units.party1.dead = nil
W.units.party1.hp = 2000
Fire("UNIT_HEALTH", "party1")
Pump(0.3, 3)
GRP_PT(true)
GRP.ptheals["0xGparty1"] = 1500
C.Set("group.incoming", false)
C.Set("group.incoming", true)
Pump(0.3, 4)
EQ("Puppeteer : soins entrants lus", a1.inc, 1500)
NEAR("Puppeteer : barre (2000 + 1500) / 4000", a1.heal:GetValue(), 0.875)
GRP.ptheals["0xGparty1"] = 0
Pump(0.3, 4)
EQ("Puppeteer : plus de soins entrants", a1.heal:GetValue(), 0)
W.units.party1.dead = true
Fire("UNIT_HEALTH", "party1")
Pump(0.3, 3)
GRP.ptres["0xGparty1"] = true
Pump(0.3, 4)
EQ("Puppeteer : resurrection en cours", a1.statusText:GetText(), SUI.L("msg.group.res"))
GRP.ptres["0xGparty1"] = nil
Pump(0.3, 4)
W.units.party1.dead = nil
Fire("UNIT_HEALTH", "party1")
Pump(0.3, 3)
-- addon charge APRES ShikiUI : repris sans /reload
GRP_PT(false)
C.Set("group.incoming", false)
C.Set("group.incoming", true)
Pump(0.3, 3)
GRP_PT(true)
GRP.ptheals["0xGparty1"] = 1000
Pump(6, 1)
Pump(0.3, 4)
EQ("source apparue plus tard : reprise sans /reload", a1.inc, 1000)
GRP_PT(false)
EXT.superwow(false)
SUI.Api.Detect()
SpellInfo = nil
Pump(6, 1)
Pump(0.3, 3)

SECTION("t_groupheal : clic ShikiUI -> HoT note (sans SuperWoW), jeton rinse")
local fr = a1
local function reset() GRP.casts = {}; W.acts = {}; GRP.mods = {}; Pump(2.5, 1) end
C.Set("modules.clickheal", true)
EQ("classe lue", CH.class, "PRIEST")
reset()
E.hotEnd.Renew.Ami1 = nil
W.units.party1.buffs = { { RENEW, 1 } }
Click(fr, "MiddleButton")
EQ("clic milieu : Renew lance", GRP.casts[1] and GRP.casts[1][1], "Renew")
T("fin du HoT notee par le clic", E.hotEnd.Renew.Ami1 ~= nil and E.hotEnd.Renew.Ami1 > GetTime())
Pump(0.1, 3)
EQ("icone de HoT apres le clic", fr.hN, 1)
EQ("duree apres le clic", fr.hTime[1]:GetText(), "15")
-- Rinse absent : repli sur la dissipation de ShikiUI
reset()
W.units.party1.debuffs = { { D_MAG, 1, "Magic" } }
C.Set("clickheal.none.left", "rinse")
Click(fr, "LeftButton")
EQ("Rinse absent : repli sur Cleanse", GRP.casts[1] and GRP.casts[1][1], "Cleanse")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("clickheal rinse")
CONTAINS("commande rinse sans Rinse : message", CHATTEXT(), SUI.L("msg.clickheal.norinse"))
-- Rinse present : appele, aucun sort ShikiUI
local rinseCalls = 0
SlashCmdList["RINSE"] = function(cmd) rinseCalls = rinseCalls + 1 end
reset()
Click(fr, "LeftButton")
EQ("Rinse present : appele une fois", rinseCalls, 1)
EQ("Rinse present : aucun sort ShikiUI", table.getn(GRP.casts), 0)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("clickheal rinse")
EQ("commande rinse : appel", rinseCalls, 2)
CONTAINS("commande rinse : message", CHATTEXT(), SUI.L("msg.clickheal.rinseok"))
SlashCmdList["RINSE"] = nil
-- avec SuperWoW, le clic ne note rien (UNIT_CASTEVENT s'en charge)
EXT.superwow(true)
SUI.Api.Detect()
reset()
E.hotEnd.Renew.Ami1 = nil
Click(fr, "MiddleButton")
EQ("avec SuperWoW : le clic ne note pas la fin du HoT", E.hotEnd.Renew.Ami1, nil)
EXT.superwow(false)
SUI.Api.Detect()
C.Set("modules.clickheal", false)

SECTION("t_groupheal : cadres de raid")
C.Set("modules.group", false)
GRP_CLEAR()
GRP_RAID(10)
GRP_SPELLS({ { "Cleanse", "", "x" }, { "Renew", "Rank 1", RENEW } })
C.Set("modules.raid", true)
SETTLE()
Pump(0.3, 3)
local R = SUI.Raid.g
local r2 = R.frames[2]
EQ("raid : HoT par defaut", C.Get("raid.hots"), 2)
EQ("raid : 3 icones de HoT construites par cadre", table.getn(r2.hIcon), 3)
EQ("raid : minuterie des durees", GRP_TASKS("Raid.hot"), 1)
W.units.raid2.buffs = { { RENEW, 1 } }
W.units.raid2.debuffs = { { D_MAG, 1, "Magic" } }
Fire("UNIT_AURA", "raid2")
E.NoteHot("Raider2", "Renew")
Pump(0.2, 3)
EQ("raid : HoT lance par moi", r2.hN, 1)
EQ("raid : duree", r2.hTime[1]:GetText(), "15")
EQ("raid : type a dissiper", r2.dispelType, "Magic")
EQ("raid : teinte du cadre", r2.dispelHl:IsShown(), true)
C.Set("raid.dispelstyle", "stripe")
Pump(0.1, 2)
EQ("raid : style liseré en direct", r2.dispelHl:IsShown(), false)
C.Set("raid.hots", 0)
Pump(0.1, 2)
EQ("raid : HoT a zero en direct", r2.hN, 0)
EQ("raid : minuterie coupee", GRP_TASKS("Raid.hot"), 0)
C.Set("modules.raid", false)
EQ("aucune erreur interne", SUI.errCount, 0)

DONE()
