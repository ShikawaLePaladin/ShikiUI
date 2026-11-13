-- t_meter3 : clic sur un joueur (niveaux de cadre perimes, secours par la position), detail par sort complet (coups, critiques, moyenne,
-- maximum, rates), onglets degats / soins / subis, defilement, retour par clic droit, message quand le detail est coupe.
local SUI = ShikiUI
local C = SUI.Config
MET_SETUP()
EXT.nampower(true)
BOOT()
MET_GROUP()
MET_NP()
SETTLE()
local M = SUI.Meter
local L = SUI.L

local ORC, ME, BOB, EVE = "0xF13000ORC", "0xME", "0xBOB", "0xEVE"
local SD, SDS = "SPELL_DAMAGE_EVENT_OTHER", "SPELL_DAMAGE_EVENT_SELF"

W.combat = false
C.Set("modules.meter", true)
SETTLE()
Fire("PARTY_MEMBERS_CHANGED")
Pump(1.1)
local w = M.win[1]
local f = w.f
MKTARGET({ name = "Orc", level = 60 })
NOW = 3000
M.Reset()

SECTION("t_meter3 : donnees par sort (maximum, moyenne, rates)")
MET_FIRE(SD, ORC, BOB, 133, 500, 0, 2)
MET_FIRE(SD, ORC, BOB, 133, 100, 0, 0)
MET_FIRE(SD, ORC, BOB, 9, 300, 0, 0)
MET_FIRE(SDS, ORC, ME, 133, 400, 0, 0)
local eb = M.cur.k.damage.Bob
EQ("maximum du sort", eb.mx.Fireball, 500)
EQ("maximum d'un autre sort", eb.mx["Shadow Bolt"], 300)
Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fireball was resisted by Orc.")
Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fireball missed Orc.")
Fire("CHAT_MSG_COMBAT_SELF_MISSES", "You miss Orc.")
local em = M.cur.k.damage.Shikiwa
EQ("sort rate deux fois (Nampower + journal des rates)", em.hm.Fireball, 2)
EQ("coup de melee rate", em.hm[M.lblMelee], 1)
EQ("les rates n'ajoutent aucun degat", em.total, 400)
EQ("rates aussi dans le total", M.overall.k.damage.Shikiwa.hm.Fireball, 2)
Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fireball hits Orc for 999.")
EQ("en mode Nampower le journal des degats n'est pas lu", em.total, 400)
Fire("CHAT_MSG_COMBAT_SELF_MISSES", "Someone else misses Orc.")
EQ("message etranger ignore", em.hm[M.lblMelee], 1)
M.Reset()
Fire("CHAT_MSG_COMBAT_SELF_MISSES", "You miss Orc.")
EQ("hors segment : rien enregistre", M.cur, nil)
MET_FIRE(SD, ORC, BOB, 133, 500, 0, 2)
MET_FIRE(SD, ORC, BOB, 133, 100, 0, 0)
MET_FIRE(SD, ORC, BOB, 9, 300, 0, 0)
MET_FIRE(SDS, ORC, ME, 133, 400, 0, 0)
Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your Fireball was dodged by Orc.")
MET_FIRE("SPELL_HEAL_BY_OTHER", EVE, BOB, 635, 700, 1, 0)
MET_FIRE("SPELL_HEAL_BY_OTHER", EVE, BOB, 635, 300, 0, 0)
Pump(1.1)

SECTION("t_meter3 : clic sur un nom, niveaux de cadre perimes")
local step = M.RowH() + C.Get("meter.spacing")
EQ("lignes au niveau du cadre + 2", w.rows[1]:GetFrameLevel(), f:GetFrameLevel() + 2)
EQ("barres au dessus de leur ligne", w.rows[1].bar:GetFrameLevel(), f:GetFrameLevel() + 3)
EQ("boutons au dessus des lignes", w.bClose:GetFrameLevel(), f:GetFrameLevel() + 4)
EQ("poignee au dessus des boutons", w.grip:GetFrameLevel(), f:GetFrameLevel() + 5)
T("lignes captent la souris", w.rows[1]:IsMouseEnabled() == 1)
-- le client change le niveau du cadre de la fenetre apres coup : les lignes se retrouvent dessous
f:SetFrameLevel(30)
this = f
f.scripts.OnShow()
EQ("OnShow recale les lignes", w.rows[1]:GetFrameLevel(), 32)
EQ("OnShow recale les barres", w.rows[1].bar:GetFrameLevel(), 33)
EQ("OnShow recale le titre cliquable", w.tbtn:GetFrameLevel(), 34)
EQ("OnShow recale la poignee", w.grip:GetFrameLevel(), 35)
w.rows[2]:SetFrameLevel(0)
M.ApplyWindow(w)
EQ("redimensionnement : ligne recalee", w.rows[2]:GetFrameLevel(), 32)
EQ("n recalage ne fait rien quand c'est bon", M.SyncLevels(w), 0)
M.SyncLevels(w)

SECTION("t_meter3 : secours par la position (le cadre capte le clic)")
local top, left = f:GetTop(), f:GetLeft()
local hdr = M.Hdr()
MOUSE.x, MOUSE.y = left + 50, top - (hdr + step * 0 + 4)
this, arg1 = f, "LeftButton"
f.scripts.OnMouseUp()
EQ("clic sur le cadre : detail de la 1re ligne", M.det.f:IsShown(), true)
EQ("detail du bon joueur", M.detName, w.rows[1].entry.name)
local first = M.detName
MOUSE.x, MOUSE.y = left + 50, top - (hdr + step * 1 + 4)
this, arg1 = f, "LeftButton"
f.scripts.OnMouseUp()
T("2e ligne : autre joueur", M.detName ~= first and M.detName ~= nil)
MOUSE.x, MOUSE.y = left + 50, top - 3
f.scripts.OnMouseUp()
T("clic dans l'en-tete : ne change rien", M.detName ~= first)
MOUSE.x, MOUSE.y = left + 50, top - (hdr + step * 30)
f.scripts.OnMouseUp()
T("clic sous les lignes : ne change rien", M.detName ~= first)
arg1 = "RightButton"
f.scripts.OnMouseUp()
EQ("clic droit sur le cadre : ferme", M.det.f:IsShown(), false)
arg1 = nil

SECTION("t_meter3 : detail complet")
local rowOf = {}
for r = 1, w.nrows do if w.rows[r].entry then rowOf[w.rows[r].entry.name] = w.rows[r] end end
Click(rowOf.Bob)
local d = M.det
EQ("detail de Bob", M.detName, "Bob")
EQ("1er sort", d.lines[1].name:GetText(), "Fireball")
EQ("total", d.lines[1].t[1], "600")
EQ("part (600 sur 900)", d.lines[1].t[2], "67%")
EQ("coups", d.lines[1].t[3], "2")
EQ("critiques", d.lines[1].t[4], "50%")
EQ("moyenne", d.lines[1].t[5], "300")
EQ("maximum", d.lines[1].t[6], "500")
EQ("rates pour un autre joueur", d.lines[1].t[7], "-")
EQ("2e sort", d.lines[2].name:GetText(), "Shadow Bolt")
EQ("ligne inutilisee videe", d.lines[3].t[1], "")
CONTAINS("sous titre : total", d.sub:GetText(), "900")
T("en-tetes visibles", d.hdr[1]:IsShown())
T("onglets visibles", d.tabs[1]:IsShown() and d.tabs[2]:IsShown() and d.tabs[3]:IsShown())
EQ("en-tete traduit", d.hdr[3]:GetText(), L("msg.meter.col.hits"))
EQ("onglet courant marque", d.tabs[1].selected, true)
MET.chat = {}
EQ("rapport : titre + lignes", M.ReportDetail("say"), 3)
Pump(1.5)
CONTAINS("rapport : colonnes", MET.chat[2], "Fireball  600")

SECTION("t_meter3 : onglets degats / soins / subis")
Click(d.tabs[2])
EQ("onglet soins", M.detKind, "heal")
EQ("fenetre inchangee", C.Get("meter.view1"), "damage")
CONTAINS("titre : onglet", d.title:GetText(), L("choice.meter.view.heal"))
EQ("soin : sort", d.lines[1].name:GetText(), "Holy Light")
EQ("soin : total", d.lines[1].t[1], "1000")
EQ("soin : critiques", d.lines[1].t[4], "50%")
EQ("soin : maximum", d.lines[1].t[6], "700")
EQ("onglet soins marque", d.tabs[2].selected, true)
EQ("ancien onglet demarque", d.tabs[1].selected, false)
Click(d.tabs[3])
EQ("onglet subis", M.detKind, "taken")
EQ("subis : panneau ouvert meme sans donnees", d.f:IsShown(), true)
EQ("subis : message", d.sub:GetText(), L("msg.meter.detnone"))
EQ("subis : lignes vides", d.lines[1].name:GetText(), "")
Pump(1.1)
EQ("rafraichissement : le panneau reste", d.f:IsShown(), true)
Click(d.tabs[1])
EQ("retour a l'onglet degats", M.detKind, "damage")
EQ("retour : sorts revenus", d.lines[1].name:GetText(), "Fireball")
T("onglet d'origine : plus d'onglet force", M.detTab == nil)
Click(d.tabs[2])
M.Reset()
Pump(1.1)
EQ("remise a zero : panneau ferme", d.f:IsShown(), false)
Click(rowOf.Bob)
this, arg1 = d.f, "RightButton"
d.f.scripts.OnMouseUp()
EQ("clic droit sur le detail : ferme", d.f:IsShown(), false)
EQ("tout est oublie", M.detName, nil)

SECTION("t_meter3 : defilement des sorts, rates du joueur")
NOW = NOW + 20
MKTARGET({ name = "Orc", level = 60 })
for i = 1, 20 do
  NOW = NOW + 0.5
  MET_FIRE(SDS, ORC, ME, 3000 + i, 1000 - i * 10, 0, 0)
end
Fire("CHAT_MSG_SPELL_SELF_DAMAGE", "Your #3001 is parried by Orc.")
Pump(1.1)
local mine
for r = 1, w.nrows do if w.rows[r].entry and w.rows[r].entry.name == "Shikiwa" then mine = w.rows[r] end end
T("ligne du joueur", mine ~= nil)
Click(mine)
EQ("detail du joueur", M.detName, "Shikiwa")
EQ("20 sorts comptes", M.detCnt, 20)
EQ("1er sort", d.lines[1].name:GetText(), "#3001")
EQ("rates du sort", d.lines[1].t[7], "1")
CONTAINS("pied : nombre de sorts", d.foot:GetText(), "20")
this, arg1 = d.f, -1
d.f.scripts.OnMouseWheel()
EQ("molette : decalage", M.detOff, 1)
EQ("molette : 1er sort decale", d.lines[1].name:GetText(), "#3002")
arg1 = -10
d.f.scripts.OnMouseWheel()
EQ("molette : borne basse", M.detOff, 6)
EQ("dernier sort visible", d.lines[14].name:GetText(), "#3020")
arg1 = 20
d.f.scripts.OnMouseWheel()
EQ("molette : borne haute", M.detOff, 0)
CONTAINS("debit sur temps actif", d.sub:GetText(), "par seconde")
Click(mine)
EQ("clic sur la meme ligne : ferme", d.f:IsShown(), false)

SECTION("t_meter3 : detail coupe -> message, comptages gardent leurs sorts")
C.Set("meter.detail", false)
CHATCLEAR()
Click(mine)
EQ("detail coupe : pas de panneau", d.f:IsShown(), false)
CONTAINS("detail coupe : message", CHATTEXT(), L("msg.meter.detoff"))
C.Set("meter.detail", true)
Click(mine)
EQ("detail rallume : s'ouvre", d.f:IsShown(), true)
Click(w.rows[1], "RightButton")
EQ("clic droit sur une ligne : ferme", d.f:IsShown(), false)

SECTION("t_meter3 : mode Raid garde le detail")
SUI.Mode.Set("raid", "manual")
EQ("mode raid : detail actif", C.Get("meter.detail"), true)
SUI.Mode.Set("normal", "manual")

SECTION("t_meter3 : /sui meter diag")
w.rows[3]:SetFrameLevel(0)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("meter diag")
CONTAINS("diag : fenetre 1", CHATTEXT(), L("msg.meter.diag", 1, f:GetFrameLevel(), 1, table.getn(w.rows)))
EQ("diag : ligne recalee", w.rows[3]:GetFrameLevel(), f:GetFrameLevel() + 2)


SECTION("t_meter3 : derive de niveau sans evenement (minuterie et survol)")
f:SetFrameLevel(61)
T("derive detectee", M.LevelsStale(w) == true)
M.CheckLevels()
EQ("la minuterie recale les lignes", w.rows[1]:GetFrameLevel(), 63)
EQ("la minuterie recale la poignee", w.grip:GetFrameLevel(), 66)
T("plus de derive", M.LevelsStale(w) == false)
f:SetFrameLevel(70)
this = f
f.scripts.OnEnter()
EQ("le survol du cadre recale les lignes", w.rows[1]:GetFrameLevel(), 72)
f:SetFrameLevel(80)
this = w.rows[1]
w.rows[1].scripts.OnEnter()
EQ("le survol d'une ligne recale aussi", w.rows[1]:GetFrameLevel(), 82)

DONE()
