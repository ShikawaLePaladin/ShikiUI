-- t_nameplates : module "nameplates" (reservoir de plaques, vie, menace, debuffs personnels, incantations, marqueurs, distance, modes, cycle de vie).
local SUI = ShikiUI
local C = SUI.Config
NP_SETUP()
EXT.superwow(true)
EXT.nampower(true)
EXT.unitxp("real")
CB_SETUP()
CB_SPELLINFO()
BOOT()
SETTLE()
-- isolation : les cadres joueur / cible (pre-soins, units.incheal) gardent aussi SPELLCAST_* ecoutes
C.Set("units.incheal", false)
if SUI.GroupEngine and SUI.GroupEngine.SyncCast then SUI.GroupEngine.SyncCast() end
local M = SUI.Nameplates
local TH = SUI.Theme
local P1, P2, P3 = "0xF13000000001", "0xF13000000002", "0xF13000000003"
local ME = "0xPLAYER"
W.units.player = W.units.player or { name = "Moi", guid = ME }
W.units.player.guid = ME

local function hiOf(b) local _, hi = b:GetMinMaxValues() return hi end
local function liveTasks(name)
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == name and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end

SECTION("t_nameplates : contrat, coupe par defaut, construction hors combat")
local mod = SUI.modules.nameplates
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "heavy")
T("coupe par defaut", not mod.enabled)
EQ("ligne pfUI relevee", table.concat(SUI.Migrate.MAP.nameplates, ","), "nameplates")
EQ("aucune frame avant activation", M.built, false)
W.combat = true
local c0 = CREATED
C.Set("modules.nameplates", true)
EQ("combat : module actif", mod.enabled, true)
EQ("combat : aucune frame creee", CREATED, c0)
EQ("combat : pas construit", M.built, false)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
EQ("construit apres le combat", M.built, true)
EQ("40 emplacements", table.getn(M.slots), 40)
EQ("tous libres", M.nFree, 40)
EQ("une minuterie", liveTasks("nameplates.tick"), 1)

SECTION("t_nameplates : detection des plaques")
CLEARPLATES()
local pl1 = NP_PLATE(P1, { name = "Garde", level = "58", hp = 50, hpMax = 100 })
local notPlate = CreateFrame("Button", nil, WorldFrame)
W.plates[2] = notPlate
local named = CreateFrame("Button", "UneFrameNommee", WorldFrame)
W.plates[3] = named
Pump(0.1, 2)
EQ("une seule plaque reconnue", M.nPlates, 1)
EQ("plaque : emplacement pris", M.nUsed, 1)
EQ("table plaque -> emplacement", M.slotOf[pl1] ~= nil, true)
EQ("table guid -> emplacement", M.byGuid[P1] ~= nil, true)
EQ("bouton sans bordure : ignore", M.known[notPlate], false)
EQ("cadre nomme : ignore", M.known[named], false)
local s1 = M.slotOf[pl1]
EQ("cadre ancre sur la plaque", s1.f.points[1][2], pl1)
EQ("cadre visible", s1.f:IsShown(), true)
EQ("largeur", s1.f:GetWidth(), 110)
EQ("hauteur", s1.f:GetHeight(), 10)
-- les objets d'origine sont neutralises
EQ("bordure d'origine videe", pl1.np.border:GetTexture(), "")
EQ("barre d'origine videe", pl1.np.hb.sbtex, "")
-- vie
EQ("vie : valeur", s1.bar:GetValue(), 50)
EQ("vie : maximum", hiOf(s1.bar), 100)
EQ("vie : texte", s1.hpFs:GetText(), "50%")
EQ("nom et niveau", s1.nameFs:GetText(), "58 Garde")
EQ("couleur du jeu reprise", s1.bar.sbc[1], 1)
pl1.np.hb:SetValue(25)
Pump(0.1, 1)
EQ("vie : mise a jour", s1.bar:GetValue(), 25)
EQ("vie : texte mis a jour", s1.hpFs:GetText(), "25%")
-- plaque cachee -> emplacement rendu
pl1:Hide()
Pump(0.1, 1)
EQ("plaque cachee : emplacement rendu", M.nFree, 40)
EQ("plaque cachee : cadre cache", s1.f:IsShown(), false)
EQ("plaque cachee : guid oublie", M.byGuid[P1], nil)
pl1:Show()
Pump(0.1, 1)
EQ("plaque reaffichee : emplacement repris", M.nUsed, 1)
-- la plaque change d'unite
local s1b = M.slotOf[pl1]
pl1.GetName = function(self, g) if g then return P2 end return nil end
W.units[P2] = W.units[P1]
Pump(0.1, 1)
EQ("nouvel GUID suivi", M.byGuid[P2] ~= nil, true)
EQ("ancien GUID oublie", M.byGuid[P1], nil)
pl1.GetName = function(self, g) if g then return P1 end return nil end
Pump(0.1, 1)
EQ("retour au premier GUID", M.byGuid[P1] ~= nil, true)
EQ("aucune erreur interne " .. tostring(SUI.lastErr), SUI.errCount, 0)
local pl2 = NP_PLATE(P2, { name = "Loup", level = "57" })
local pl3 = NP_PLATE(P3, { name = "Ami", friend = true })
Pump(0.1, 2)
local s2, s3 = M.slotOf[pl2], M.slotOf[pl3]
EQ("trois plaques suivies", M.nUsed, 3)

SECTION("t_nameplates : menace")
W.units[P1].combat = true
NP.mt[P1] = "player"
Pump(0.1, 1)
EQ("tank : ennemi sur moi = vert", s1.bar.sbc[1], TH.c.good[1])
NP.mt[P1] = "other"
Pump(0.1, 1)
EQ("tank : ennemi sur un autre = rouge", s1.bar.sbc[1], TH.c.bad[1])
EQ("tank : ennemi sur un autre (vert)", s1.bar.sbc[2], TH.c.bad[2])
NP.mt[P1] = nil
Pump(0.1, 1)
EQ("sans cible (apres un jeton valide) : couleur du jeton sans cible", s1.bar.sbc[2], TH.c.border[2])
C.Set("nameplates.threatnone", false)
Pump(0.1, 1)
EQ("sans cible coupe : couleur du jeu", s1.bar.sbc[2], 0)
C.Set("nameplates.threatnone", true)
NP.mt[P1] = "other"
W.units[P1].combat = false
Pump(0.1, 1)
EQ("hors combat : couleur du jeu", s1.bar.sbc[2], 0)
W.units[P1].combat = true
C.Set("nameplates.threatmode", "dps")
NP.mt[P1] = "player"
Pump(0.1, 1)
EQ("dps : ennemi sur moi = rouge", s1.bar.sbc[1], TH.c.bad[1])
NP.mt[P1] = "other"
Pump(0.1, 1)
EQ("dps : ennemi sur un autre = vert (surete)", s1.bar.sbc[2], TH.c.good[2])
C.Set("nameplates.dpssafe", false)
Pump(0.1, 1)
EQ("dps : surete coupee = couleur du jeu", s1.bar.sbc[2], 0)
C.Set("nameplates.dpssafe", true)
C.Set("nameplates.threatmode", "tank")
NP.mt[P1] = "player"
C.Set("nameplates.threat", false)
Pump(0.1, 1)
EQ("menace coupee : couleur du jeu", s1.bar.sbc[2], 0)
C.Set("nameplates.threat", true)
NP.mt[P1] = nil
Pump(0.1, 1)

SECTION("t_nameplates : menace du serveur (pourcentage, alerte, main tank, familier, demande)")
local function hasH(ev, fn)
  local h = SUI.handlers[ev]
  if not h then return false end
  for i = 1, table.getn(h) do if h[i] == fn then return true end end
  return false
end
EQ("ecoute des paquets active par defaut", hasH("CHAT_MSG_ADDON", M.OnAddon), true)
W.units.player.name = "Moi"
M.player = "Moi"
W.partyMembers = 2
W.units[P1].combat = true
NP.mt[P1] = "player"
MKTARGET({ name = "Garde", guid = P1 })
Fire("PLAYER_TARGET_CHANGED")
Pump(0.1, 8)
EQ("avant tout paquet : vert", s1.bar.sbc[1], TH.c.good[1])
EQ("avant tout paquet : aucun chiffre", s1.thrFs:GetText(), "")
-- je tiens la creature : Bob est a 85 pour cent de ma menace
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1;Bob:0:850:85:1;Eve:0:200:20:0", "PARTY", "Server")
Pump(0.1, 1)
EQ("tank : chiffre du challenger", s1.thrFs:GetText(), "Bob 85%")
EQ("tank : seuil atteint = jaune (rouge)", s1.bar.sbc[1], TH.c.warn[1])
EQ("tank : seuil atteint = jaune (vert)", s1.bar.sbc[2], TH.c.warn[2])
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1;Bob:0:500:50:1", "PARTY", "Server")
Pump(0.1, 1)
EQ("tank : sous le seuil = vert", s1.bar.sbc[1], TH.c.good[1])
EQ("tank : sous le seuil, chiffre", s1.thrFs:GetText(), "Bob 50%")
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1", "PARTY", "Server")
Pump(0.1, 1)
EQ("tank : seul sur la creature", s1.thrFs:GetText(), "0%")
-- reglage en direct : seuil a 0 = plus d'alerte jaune, le chiffre reste
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1;Bob:0:900:90:1", "PARTY", "Server")
Pump(0.1, 1)
EQ("jaune avant", s1.bar.sbc[1], TH.c.warn[1])
C.Set("nameplates.threatwarn", 0)
Pump(0.1, 1)
EQ("seuil 0 : plus de jaune", s1.bar.sbc[1], TH.c.good[1])
EQ("seuil 0 : chiffre garde", s1.thrFs:GetText(), "Bob 90%")
C.Set("nameplates.threatwarn", 80)
Pump(0.1, 1)
EQ("seuil remis : jaune", s1.bar.sbc[1], TH.c.warn[1])
-- chiffre coupe en direct, l'alerte jaune garde l'ecoute
C.Set("nameplates.threatpct", false)
Pump(0.1, 1)
EQ("chiffre coupe : texte vide", s1.thrFs:GetText(), "")
EQ("chiffre coupe : couleur jaune gardee", s1.bar.sbc[1], TH.c.warn[1])
EQ("chiffre coupe : ecoute gardee (alerte)", hasH("CHAT_MSG_ADDON", M.OnAddon), true)
C.Set("nameplates.threatwarn", 0)
EQ("tout coupe : plus d'ecoute", hasH("CHAT_MSG_ADDON", M.OnAddon), false)
EQ("tout coupe : donnees oubliees", M.pl.n, 0)
C.Set("nameplates.threatwarn", 80)
C.Set("nameplates.threatpct", true)
EQ("rallume : ecoute", hasH("CHAT_MSG_ADDON", M.OnAddon), true)
-- donnees vieillies : plus rien d'affiche (jamais de chiffre invente)
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1;Bob:0:900:90:1", "PARTY", "Server")
Pump(0.1, 1)
EQ("chiffre frais", s1.thrFs:GetText(), "Bob 90%")
Pump(0.5, 8)
EQ("chiffre vieilli : efface", s1.thrFs:GetText(), "")
EQ("chiffre vieilli : retour au vert", s1.bar.sbc[1], TH.c.good[1])
-- paquet qui n'est pas de la menace / mal forme
Fire("CHAT_MSG_ADDON", "TWT", "bonjour", "PARTY", "Server")
Fire("CHAT_MSG_ADDON", "TWT", nil, "PARTY", "Server")
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=;;:::;x", "PARTY", "Server")
Pump(0.1, 1)
EQ("paquets invalides sans erreur " .. tostring(SUI.lastErr), SUI.errCount, 0)
-- une reponse arrivee juste apres un changement de cible est ignoree (elle peut etre celle de l'ancienne cible)
Fire("PLAYER_TARGET_CHANGED")
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1;Bob:0:900:90:1", "PARTY", "Server")
Pump(0.1, 1)
EQ("apres changement de cible : ignoree", s1.thrFs:GetText(), "")
Pump(0.1, 8)
-- role autre que tank : mon pourcentage de la menace du tank
C.Set("nameplates.threatmode", "dps")
NP.mt[P1] = "other"
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:0:850:85:1;Bob:1:1000:100:1", "PARTY", "Server")
Pump(0.1, 1)
EQ("dps : mon pourcentage", s1.thrFs:GetText(), "85%")
EQ("dps : pres de prendre l'aggro = jaune", s1.bar.sbc[1], TH.c.warn[1])
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:0:300:30:1;Bob:1:1000:100:1", "PARTY", "Server")
Pump(0.1, 1)
EQ("dps : loin du seuil = vert (un autre a l'aggro)", s1.bar.sbc[2], TH.c.good[2])
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:0:1100:110:1;Bob:1:1000:100:1", "PARTY", "Server")
NP.mt[P1] = "player"
Pump(0.1, 1)
EQ("dps : je l'ai = rouge", s1.bar.sbc[1], TH.c.bad[1])
C.Set("nameplates.threatmode", "tank")
-- un main tank du raid la tient : accent (et non rouge) ; coupe = rouge
NP.mt[P1] = "other"
NP.mtName[P1] = "Bob"
W.raidMembers = 1
NP.roster[1] = { "Bob", "MAINTANK" }
Fire("RAID_ROSTER_UPDATE")
Pump(0.1, 1)
local acr, acg = TH.Accent()
EQ("main tank : accent", s1.bar.sbc[1], acr)
EQ("main tank : accent (vert)", s1.bar.sbc[2], acg)
C.Set("nameplates.threattank", false)
Pump(0.1, 1)
EQ("main tank non reconnu : rouge", s1.bar.sbc[1], TH.c.bad[1])
C.Set("nameplates.threattank", true)
NP.roster[1] = { "Bob", "MAINASSIST" }
Fire("RAID_ROSTER_UPDATE")
Pump(0.1, 1)
EQ("simple assistant : rouge", s1.bar.sbc[1], TH.c.bad[1])
-- familier
NP.pet[P1] = true
NP.mtName[P1] = "Rex"
Pump(0.1, 1)
EQ("familier : gris", s1.bar.sbc[1], TH.c.dim[1])
NP.pet[P1] = nil
NP.mt[P1] = nil
W.raidMembers = 0
Fire("RAID_ROSTER_UPDATE")
-- liste du mode tank : une creature autre que la cible, rapprochee par la fin de son GUID ET son nom
NP.mt[P2] = "player"
W.units[P2].combat = true
Pump(0.1, 1)
EQ("liste tank : creature sans chiffre au depart", s2.thrFs:GetText(), "")
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1#TMTv1=Loup:2:Eve:90;Garde:77:Bob:30", "PARTY", "Server")
Pump(0.1, 1)
EQ("liste tank : chiffre sur la bonne plaque", s2.thrFs:GetText(), "Eve 90%")
EQ("liste tank : jaune", s2.bar.sbc[1], TH.c.warn[1])
EQ("liste tank : creature absente de la liste", s3.thrFs:GetText(), "")
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1#TMTv1=Autre:2:Eve:90", "PARTY", "Server")
Pump(0.1, 1)
EQ("liste tank : meme id mais autre nom = rien", s2.thrFs:GetText(), "")
-- position du chiffre
EQ("chiffre a droite", s2.thrFs.points[1][1], "LEFT")
C.Set("nameplates.threatpos", "left")
EQ("chiffre a gauche (en direct)", s2.thrFs.points[1][1], "RIGHT")
C.Set("nameplates.threatpos", "right")
NP.mt[P2] = nil
-- demande au serveur
W.combat = true
NP.sent = {}
M.reqAt, M.pktAt = -100, -100
Pump(0.1, 2)
EQ("demande mode tank envoyee", NP.sent[1], "TWT_UDTSv4_TM|limit=5|PARTY")
local nsent = table.getn(NP.sent)
Pump(0.1, 4)
EQ("une demande par seconde au plus", table.getn(NP.sent), nsent)
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1", "PARTY", "Server")
Pump(0.5, 1)
EQ("un autre addon a obtenu une reponse : on se tait", table.getn(NP.sent), nsent)
C.Set("nameplates.threatmode", "dps")
Pump(1.1, 2)
EQ("role autre : demande simple", NP.sent[table.getn(NP.sent)], "TWT_UDTSv4|limit=5|PARTY")
C.Set("nameplates.threatrequest", false)
local n2 = table.getn(NP.sent)
Pump(1.1, 3)
EQ("demande coupee : rien envoye", table.getn(NP.sent), n2)
C.Set("nameplates.threatrequest", true)
W.partyMembers = 0
Pump(1.1, 3)
EQ("hors groupe : rien envoye", table.getn(NP.sent), n2)
W.combat = false
C.Set("nameplates.threatmode", "tank")
W.units.target = nil
Fire("PLAYER_TARGET_CHANGED")
Pump(0.1, 2)
EQ("aucune erreur interne (menace) " .. tostring(SUI.lastErr), SUI.errCount, 0)

SECTION("t_nameplates : couleurs de menace (mode auto, jetons, provocation, sans cible)")
local function colorIs(tok) local c = TH.c[tok]; return s1.bar.sbc[1] == c[1] and s1.bar.sbc[2] == c[2] and s1.bar.sbc[3] == c[3] end
MKTARGET({ name = "Garde", guid = P1 })
Fire("PLAYER_TARGET_CHANGED")
Pump(0.1, 8)
W.units[P1].combat = true
W.units[P1].isPlayer = false
W.units[P1].class = nil
NP.mt[P1] = "player"
NP.mtName[P1] = nil
C.Set("nameplates.threatmode", "auto")
C.Set("nameplates.threatwarn", 0)
C.cur.role = nil
Pump(0.1, 2)
EQ("auto sans role : mode tank", M.mode, "tank")
T("auto sans role : sur moi = vert", colorIs("good"))
C.cur.role = "tank"
Pump(0.1, 2)
EQ("auto role tank : mode tank", M.mode, "tank")
C.cur.role = "heal"
Pump(0.1, 2)
EQ("auto role soigneur : mode dps", M.mode, "dps")
T("auto soigneur : sur moi = rouge", colorIs("bad"))
NP.mt[P1] = "other"
Pump(0.1, 2)
T("auto soigneur : sur un autre = vert", colorIs("good"))
C.cur.role = "dps"
Pump(0.1, 2)
EQ("auto role dps : mode dps", M.mode, "dps")
C.cur.role = "tank"
Pump(0.1, 2)
T("auto tank : sur un autre = rouge", colorIs("bad"))
-- les couleurs sont des jetons choisis (aucune couleur en dur)
C.Set("nameplates.coldanger", "dim")
Pump(0.1, 1)
T("danger -> jeton gris", colorIs("dim"))
C.Set("nameplates.coldanger", "accent")
Pump(0.1, 1)
local ar2, ag2, ab2 = TH.Accent()
EQ("danger -> accent (rouge)", s1.bar.sbc[1], ar2)
EQ("danger -> accent (vert)", s1.bar.sbc[2], ag2)
C.Set("nameplates.coldanger", "bad")
NP.mt[P1] = "player"
C.Set("nameplates.colsafe", "text")
Pump(0.1, 1)
T("surete -> jeton texte", colorIs("text"))
C.Set("nameplates.colsafe", "good")
-- seuil jaune
C.Set("nameplates.threatwarn", 80)
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1;Bob:0:900:90:1", "PARTY", "Server")
Pump(0.1, 1)
T("alerte : orange", colorIs("warn"))
C.Set("nameplates.colwarn", "bad")
Pump(0.1, 1)
T("alerte reglee sur le jeton rouge", colorIs("bad"))
C.Set("nameplates.colwarn", "warn")
-- provocation : sort lance par le joueur sur ce GUID (SuperWoW)
CB.info[7001] = { "Taunt", "", "tex_taunt" }
CB.info[7002] = { "Challenging Shout", "", "tex_shout" }
CB.info[7003] = { "Fireball", "", "tex_fb" }
Fire("CHAT_MSG_ADDON", "TWT", "TWTv4=Moi:1:1000:100:1", "PARTY", "Server")
Pump(0.1, 1)
T("avant provocation : vert", colorIs("good"))
Fire("UNIT_CASTEVENT", ME, P1, "CAST", 7003, 0)
Pump(0.1, 1)
T("sort ordinaire : pas de provocation", colorIs("good"))
Fire("UNIT_CASTEVENT", "0xAUTRE", P1, "CAST", 7001, 0)
Pump(0.1, 1)
T("provocation d'un autre : ignoree", colorIs("good"))
Fire("UNIT_CASTEVENT", ME, P1, "START", 7001, 0)
Pump(0.1, 1)
T("debut d'incantation : pas encore", colorIs("good"))
Fire("UNIT_CASTEVENT", ME, P1, "CAST", 7001, 0)
Pump(0.1, 1)
T("provoque : jeton provocation", colorIs("text"))
T("provoque : la plaque voisine n'est pas touchee", s2.bar.sbc[1] ~= TH.c.text[1] or s2.bar.sbc[2] ~= TH.c.text[2])
C.Set("nameplates.coltaunt", "warn")
Pump(0.1, 1)
T("provocation : jeton reglable", colorIs("warn"))
C.Set("nameplates.coltaunt", "text")
C.Set("nameplates.threattaunt", false)
Pump(0.1, 1)
T("provocation coupee : retour au vert", colorIs("good"))
C.Set("nameplates.threattaunt", true)
Pump(0.1, 1)
T("provocation reactivee", colorIs("text"))
NP.mt[P1] = "other"
Pump(0.1, 1)
T("provoque mais pas encore sur moi : rouge (etat du role)", colorIs("bad"))
NP.mt[P1] = "player"
Pump(3.5, 1)
T("effet termine (3 s) : vert", colorIs("good"))
Fire("UNIT_CASTEVENT", ME, P1, "CAST", 7002, 0)
Pump(0.1, 1)
T("cri de defi : toutes les creatures sur moi", colorIs("text"))
Pump(6.5, 1)
T("cri de defi termine (6 s)", colorIs("good"))
-- Nampower : SPELL_GO_SELF(objet, sort, lanceur, cible)
Fire("SPELL_GO_SELF", 0, 7001, ME, P1)
Pump(0.1, 1)
T("Nampower : provocation", colorIs("text"))
Pump(3.5, 1)
-- sans cible : seulement en combat
NP.mt[P1] = nil
Pump(0.1, 1)
T("sans cible : jeton sans cible", colorIs("border"))
W.units[P1].combat = false
Pump(0.1, 1)
EQ("sans cible hors combat : couleur du jeu", s1.bar.sbc[2], 0)
W.units[P1].combat = true
NP.mt[P1] = "player"
C.Set("nameplates.threatmode", "tank")
C.cur.role = nil
NP.mt[P1] = nil
W.units.target = nil
Fire("PLAYER_TARGET_CHANGED")
Pump(0.1, 2)
EQ("aucune erreur interne (couleurs) " .. tostring(SUI.lastErr), SUI.errCount, 0)

SECTION("t_nameplates : cible")
EQ("sans cible : echelle 1", s1.f:GetScale(), 1)
MKTARGET({ name = "Garde", guid = P1 })
Fire("PLAYER_TARGET_CHANGED")
Pump(0.1, 1)
EQ("GUID de la cible", M.targetGuid, P1)
EQ("cible : plaque agrandie", s1.f:GetScale(), 1.2)
EQ("autre plaque : echelle 1", s2.f:GetScale(), 1)
local ar = TH.Accent()
EQ("cible : bordure d'accent", s1.f.bbc[1], ar)
C.Set("nameplates.targetscale", 1.5)
Pump(0.1, 1)
EQ("echelle reglable", s1.f:GetScale(), 1.5)
C.Set("nameplates.targetglow", false)
Pump(0.1, 1)
EQ("mise en avant coupee", s1.f:GetScale(), 1)
C.Set("nameplates.targetglow", true)
C.Set("nameplates.targetscale", 1.2)
W.units.target = nil
Fire("PLAYER_TARGET_CHANGED")
Pump(0.1, 1)
EQ("cible perdue : echelle 1", s1.f:GetScale(), 1)
MKTARGET({ name = "Garde", guid = P1 })
Fire("PLAYER_TARGET_CHANGED")
Pump(0.1, 1)

SECTION("t_nameplates : debuffs personnels (Nampower)")
EQ("aucun debuff au depart", M.nd, 0)
FIREX("AURA_CAST_ON_OTHER", 133, ME, P1, 0, 0, 0, 0, 12000, 0)
EQ("debuff suivi", M.nd, 1)
Pump(0.1, 1)
EQ("icone affichee", s1.dTex[1]:IsShown(), true)
EQ("icone du sort", s1.dTex[1].suiTex, "Interface\\Icons\\Spell_Fire_FlameBolt")
EQ("duree restante", s1.dFs[1]:GetText(), "11")
EQ("autre plaque : pas d'icone", s2.dTex[1]:IsShown(), false)
FIREX("AURA_CAST_ON_OTHER", 689, P2, P1, 0, 0, 0, 0, 12000, 0)
EQ("debuff d'un autre joueur : ignore", M.nd, 1)
FIREX("AURA_CAST_ON_OTHER", 689, ME, P1, 0, 0, 0, 0, 30000, 0)
EQ("deuxieme debuff", M.nd, 2)
FIREX("AURA_CAST_ON_OTHER", 689, ME, P2, 0, 0, 0, 0, 150000, 0)
Pump(0.1, 1)
EQ("deuxieme icone", s1.dTex[2]:IsShown(), true)
EQ("autre plaque : son debuff", s2.dTex[1]:IsShown(), true)
EQ("duree longue en minutes", s2.dFs[1]:GetText(), "2m")
FIREX("AURA_CAST_ON_OTHER", 133, ME, P1, 0, 0, 0, 0, 12000, 0)
EQ("meme debuff : rafraichi, pas duplique", M.nd, 3)
FIREX("AURA_CAST_ON_OTHER", 133, ME, P1, 0, 0, 0, 0, 0, 0)
EQ("duree nulle : ignoree", M.nd, 3)
C.Set("nameplates.debuffmax", 1)
Pump(0.1, 1)
EQ("debuffmax : une icone", s1.dTex[2]:IsShown(), false)
C.Set("nameplates.debuffmax", 4)
C.Set("nameplates.debufftimer", false)
Pump(0.1, 1)
EQ("duree coupee", s1.dFs[1]:GetText(), "")
C.Set("nameplates.debufftimer", true)
C.Set("nameplates.debuffs", false)
Pump(0.1, 1)
EQ("debuffs coupes", s1.dTex[1]:IsShown(), false)
C.Set("nameplates.debuffs", true)
Pump(0.1, 1)
FIREX("DEBUFF_REMOVED_OTHER", P1, 1, 133)
EQ("debuff retire", M.nd, 2)
Pump(0.1, 1)
EQ("icone retiree", s1.dTex[2]:IsShown(), false)
Pump(5, 40)
EQ("expiration complete", M.nd, 0)
Pump(0.1, 1)
EQ("plus d'icone", s1.dTex[1]:IsShown(), false)
FIREX("AURA_CAST_ON_OTHER", 133, ME, P1, 0, 0, 0, 0, 12000, 0)
Fire("UNIT_DIED", P1)
EQ("mort : debuffs retires", M.nd, 0)
-- repli sans Nampower : debuffs de la cible, sans duree
NP.tdebuffs = { { tex = "Interface\\Icons\\Spell_Shadow_A", count = 1 } }
Pump(0.1, 1)
EQ("repli : icone sur la cible", s1.dTex[1]:IsShown(), true)
EQ("repli : sans duree", s1.dFs[1]:GetText(), "")
EQ("repli : pas sur les autres", s2.dTex[1]:IsShown(), false)
NP.tdebuffs = {}
Pump(0.1, 1)
EQ("repli : icone retiree", s1.dTex[1]:IsShown(), false)

SECTION("t_nameplates : incantations des ennemis")
Fire("UNIT_CASTEVENT", P1, ME, "START", 133, 2000)
Pump(0.1, 1)
EQ("barre visible", s1.cb:IsShown(), true)
EQ("nom du sort", s1.cNameFs:GetText(), "Fireball")
EQ("icone du sort", s1.cIcon, "Interface\\Icons\\Spell_Fire_FlameBolt")
NEAR("progression", s1.cbar:GetValue(), 0.05, 0.03)
Pump(0.1, 10)
NEAR("progression a 1,1 s", s1.cbar:GetValue(), 0.55, 0.06)
EQ("autre plaque : pas de barre", s2.cb:IsShown(), false)
Fire("UNIT_CASTEVENT", P1, ME, "CAST", 133)
Pump(0.1, 1)
EQ("fin du sort : barre cachee", s1.cb:IsShown(), false)
Fire("UNIT_CASTEVENT", P1, ME, "START", 133, 2000)
Fire("UNIT_CASTEVENT", P1, ME, "FAIL", 133)
Pump(0.1, 1)
EQ("echec : barre cachee", s1.cb:IsShown(), false)
Fire("UNIT_CASTEVENT", P1, ME, "START", 133, 2000)
Pump(0.1, 1)
Fire("UNIT_CASTEVENT", P1, ME, "FAIL", 689)
Pump(0.1, 1)
EQ("echec d'un autre sort : ignore", s1.cb:IsShown(), true)
Fire("UNIT_CASTEVENT", P1, ME, "CAST", 133)
Pump(0.1, 1)
Fire("UNIT_CASTEVENT", P1, ME, "CHANNEL", 689, 3000)
Pump(0.1, 1)
EQ("canalisation : nom", s1.cNameFs:GetText(), "Drain Life")
T("canalisation : la barre se vide", s1.cbar:GetValue() > 0.9)
Pump(0.1, 10)
T("canalisation : vide avec le temps", s1.cbar:GetValue() < 0.7)
Fire("UNIT_CASTEVENT", P1, ME, "CAST", 689)
Pump(0.1, 1)
-- Nampower
FIREX("SPELL_START_OTHER", 0, 133, P1, ME, 0, 2000)
Pump(0.1, 1)
EQ("Nampower : barre visible", s1.cb:IsShown(), true)
local t0 = s1.cT0
Fire("UNIT_CASTEVENT", P1, ME, "START", 133, 2000)
EQ("doublon d'evenement : pas de redemarrage", s1.cT0, t0)
Fire("SPELL_FAILED_OTHER", P1, 133)
Pump(0.1, 1)
EQ("Nampower : echec cache la barre", s1.cb:IsShown(), false)
-- repli : barre d'origine
pl1.np.cb:SetMinMaxValues(0, 10)
pl1.np.cb:SetValue(5)
pl1.np.cb:Show()
Pump(0.1, 1)
EQ("repli : barre d'origine copiee", s1.cb:IsShown(), true)
NEAR("repli : valeur", s1.cbar:GetValue(), 0.5, 0.01)
EQ("repli : sans nom", s1.cNameFs:GetText(), "")
pl1.np.cb:Hide()
Pump(0.1, 1)
EQ("repli : barre cachee", s1.cb:IsShown(), false)
Fire("UNIT_CASTEVENT", P1, ME, "START", 133, 2000)
Pump(0.1, 1)
C.Set("nameplates.castname", false)
Pump(0.1, 1)
EQ("nom du sort coupe", s1.cNameFs:GetText(), "")
C.Set("nameplates.castname", true)
C.Set("nameplates.casticon", false)
Pump(0.1, 1)
EQ("icone du sort coupee", s1.cIconTex:IsShown(), false)
C.Set("nameplates.casticon", true)
C.Set("nameplates.castbar", false)
Pump(0.1, 1)
EQ("incantations coupees", s1.cb:IsShown(), false)
C.Set("nameplates.castbar", true)
Pump(0.1, 1)
Fire("UNIT_DIED", P1)
Pump(0.1, 1)
EQ("mort : barre cachee", s1.cb:IsShown(), false)
Fire("UNIT_CASTEVENT", "0xINCONNU", ME, "START", 133, 2000)
EQ("lanceur sans plaque : ignore", s1.casting, false)

SECTION("t_nameplates : marqueurs, distance, plaques amies")
local rp = pl1.np.ricon.points[1]
EQ("marqueur ancre sur notre cadre", rp[2], s1.f)
EQ("marqueur : au-dessus du nom", rp[5], 14)
EQ("marqueur : taille", pl1.np.ricon:GetWidth(), 20)
C.Set("nameplates.markersize", 30)
EQ("marqueur : taille reglable", pl1.np.ricon:GetWidth(), 30)
C.Set("nameplates.markers", false)
T("marqueurs coupes", pl1.np.ricon:GetWidth() < 1)
C.Set("nameplates.markers", true)
C.Set("nameplates.name", false)
EQ("sans nom : marqueur plus bas", pl1.np.ricon.points[1][5], 2)
EQ("sans nom : texte vide", s1.nameFs:GetText(), "")
C.Set("nameplates.name", true)
Pump(0.1, 1)
EQ("nom remis", s1.nameFs:GetText(), "58 Garde")
EQ("distance : cible seulement", s1.distFs:GetText(), "10m")
EQ("distance : pas sur les autres", s2.distFs:GetText(), "")
W.units[P1].dist = 7.4
Pump(0.1, 1)
EQ("distance arrondie", s1.distFs:GetText(), "7m")
C.Set("nameplates.distance", "all")
Pump(0.1, 1)
EQ("distance : toutes", s2.distFs:GetText(), "10m")
C.Set("nameplates.distance", "off")
Pump(0.1, 1)
EQ("distance coupee", s1.distFs:GetText(), "")
C.Set("nameplates.distance", "target")
EQ("plaque amie : pas de barre", s3.bar:IsShown(), false)
EQ("plaque amie : nom ecrit", s3.nameFs:GetText(), "60 Ami")
C.Set("nameplates.friendly", true)
Pump(0.1, 1)
EQ("plaques amies reglables : barre", s3.bar:IsShown(), true)
C.Set("nameplates.friendly", false)
Pump(0.1, 1)

SECTION("t_nameplates : reglages")
C.Set("nameplates.width", 150)
EQ("largeur", s1.f:GetWidth(), 150)
EQ("incantation : meme largeur", s1.cb:GetWidth(), 150)
C.Set("nameplates.width", 110)
C.Set("nameplates.height", 16)
EQ("hauteur", s1.f:GetHeight(), 16)
C.Set("nameplates.height", 10)
C.Set("nameplates.debuffsize", 20)
EQ("taille des debuffs", s1.dTex[1]:GetWidth(), 20)
C.Set("nameplates.debuffsize", 14)
C.Set("nameplates.castheight", 12)
EQ("hauteur d'incantation", s1.cb:GetHeight(), 12)
C.Set("nameplates.castheight", 8)
C.Set("nameplates.hptext", false)
EQ("pourcentage coupe", s1.hpFs:GetText(), "")
C.Set("nameplates.hptext", true)
pl1.np.hb:SetValue(30)
Pump(0.1, 1)
EQ("pourcentage remis", s1.hpFs:GetText(), "30%")
C.Set("nameplates.level", false)
Pump(0.1, 1)
EQ("sans niveau", s1.nameFs:GetText(), "Garde")
C.Set("nameplates.level", true)
W.units[P1].isPlayer = true
W.units[P1].class = "MAGE"
C.Set("nameplates.classcolor", true)
Pump(0.1, 1)
EQ("couleur de classe", s1.bar.sbc[1], 0.4)
C.Set("nameplates.classcolor", false)
Pump(0.1, 1)
EQ("couleur de classe coupee", s1.bar.sbc[1], 1)
C.Set("nameplates.rate", 0.3)
EQ("toujours une seule minuterie", liveTasks("nameplates.tick"), 1)
C.Set("nameplates.rate", 0.1)
-- sans GUID (pas de SuperWoW) : la plaque reste utilisable
pl2.GetName = function(self, g) return nil end
Pump(0.1, 2)
EQ("sans GUID : plaque suivie", M.slotOf[pl2] ~= nil, true)
EQ("sans GUID : pas de jeton de menace", M.slotOf[pl2].ttoken, nil)
EQ("sans GUID : aucune erreur interne", SUI.errCount, 0)

SECTION("t_nameplates : limite de plaques et mode Raid")
C.Set("nameplates.maxplates", 10)
for i = 4, 14 do NP_PLATE("0xF130000000" .. string.format("%02d", i), {}) end
Pump(0.1, 2)
EQ("10 plaques au plus", M.nUsed, 10)
CLEARPLATES()
Pump(0.1, 1)
C.Set("nameplates.maxplates", 40)
SUI.Mode.Set("raid", "manual")
EQ("preset Raid : largeur", C.Get("nameplates.width"), 90)
EQ("preset Raid : debuffs", C.Get("nameplates.debuffmax"), 3)
EQ("preset Raid : distance", C.Get("nameplates.distance"), "off")
EQ("preset Raid : rythme", C.Get("nameplates.rate"), 0.2)
EQ("preset Raid : plaques", C.Get("nameplates.maxplates"), 25)
SUI.Mode.Set("normal", "manual")
EQ("retour Normal : largeur", C.Get("nameplates.width"), 110)
EQ("retour Normal : rythme", C.Get("nameplates.rate"), 0.1)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("nameplates")
CONTAINS("commande", CHATTEXT(), "Plaques : ")
C.Set("ui.locale", "en")
EQ("anglais", SUI.L("opt.nameplates.width"), "Width")
C.Set("ui.locale", "fr")

SECTION("t_nameplates : aucune creation en combat")
local q1 = NP_PLATE(P1, { name = "Garde" })
local q2 = NP_PLATE(P2, { name = "Loup" })
Pump(0.1, 2)
W.combat = true
local c1 = CREATED
local nt = table.getn(SUI.tasks)
for i = 1, 8 do
  Fire("UNIT_CASTEVENT", P1, ME, "START", 133, 2000)
  FIREX("AURA_CAST_ON_OTHER", 133, ME, P2, 0, 0, 0, 0, 12000, 0)
  Fire("PLAYER_TARGET_CHANGED")
  Pump(0.1, 3)
end
EQ("combat : aucune frame creee", CREATED, c1)
T("combat : aucune minuterie creee", table.getn(SUI.tasks) <= nt)
W.combat = false

SECTION("t_nameplates : reglages en direct et plaques rendues au jeu")
CLEARPLATES()
Pump(0.1, 2)
local pa = NP_PLATE("0xF1300000A001", { name = "Alpha", hp = 40, hpMax = 100 })
pa.np.name:SetWidth(80)
Pump(0.1, 2)
local sa = M.slotOf[pa]
EQ("plaque prise en charge", sa ~= nil, true)
EQ("vie ecrite", sa.hpFs:GetText(), "40%")
C.Set("nameplates.hptext", false)
Pump(0.1, 1)
EQ("pourcentage coupe", sa.hpFs:GetText(), "")
C.Set("nameplates.hptext", true)
Pump(0.1, 1)
EQ("pourcentage remis sans changement de vie", sa.hpFs:GetText(), "40%")
-- plaque amie : le nom seul, sans fond ni cadre
local pf = NP_PLATE("0xF1300000A002", { name = "Ami", friend = true })
Pump(0.1, 2)
local sf = M.slotOf[pf]
EQ("amie : fond invisible", sf.f.bgc[4], 0)
EQ("amie : bordure invisible", sf.f.bbc[4], 0)
C.Set("nameplates.friendly", true)
Pump(0.1, 1)
T("amie reglable : fond rendu", sf.f.bgc[4] > 0)
T("amie reglable : bordure rendue", sf.f.bbc[4] > 0)
C.Set("nameplates.friendly", false)
Pump(0.1, 1)
EQ("amie coupee : fond de nouveau invisible", sf.f.bgc[4], 0)
-- limite de plaques abaissee en direct
for i = 1, 12 do NP_PLATE("0xF1300000B0" .. string.format("%02d", i), {}) end
Pump(0.1, 2)
T("plus de 10 plaques suivies", M.nUsed > 10)
C.Set("nameplates.maxplates", 10)
EQ("limite appliquee sans attendre", M.nUsed, 10)
local naked = 0
for i = 1, table.getn(W.plates) do
  local p = W.plates[i]
  if not M.slotOf[p] and p.np and not p.suiSkin then naked = naked + 1 end
end
T("les plaques en trop retrouvent leur apparence", naked >= 1)
Pump(0.1, 2)
EQ("limite tenue", M.nUsed, 10)
C.Set("nameplates.maxplates", 40)
Pump(0.1, 2)
T("limite relevee : plaques reprises", M.nUsed > 10)

SECTION("t_nameplates : aspect commun (texture, forme, police)")
local s1 = M.slots[1]
T("options d'aspect declarees", C.meta["nameplates.bartex"] ~= nil and C.meta["nameplates.shape"] ~= nil and C.meta["nameplates.font"] ~= nil and C.meta["nameplates.fontsize"] ~= nil)
EQ("barre de vie : hauteur du reglage", s1.bar:GetHeight(), M.cfg.height - 2)
EQ("barre de vie : largeur du reglage", s1.bar:GetWidth(), M.cfg.width - 2)
C.Set("nameplates.bartex", "blizzard")
EQ("texture de la barre de vie", s1.bar.calls.SetStatusBarTexture[1], TH.BARS.blizzard)
EQ("texture de la barre d'incantation", s1.cbar.calls.SetStatusBarTexture[1], TH.BARS.blizzard)
C.Set("nameplates.shape", "thin")
EQ("forme fine : barre de vie", s1.bar:GetHeight(), math.max(2, math.floor((M.cfg.height - 2) * 0.4 + 0.5)))
EQ("forme fine : barre d'incantation", s1.cbar:GetHeight(), math.max(2, math.floor((M.cfg.castheight - 2) * 0.4 + 0.5)))
C.Set("nameplates.height", 14)
EQ("forme fine suit la hauteur", s1.bar:GetHeight(), math.max(2, math.floor(12 * 0.4 + 0.5)))
C.Set("nameplates.shape", "style")
EQ("forme du style : hauteur rendue", s1.bar:GetHeight(), 12)
C.Set("nameplates.height", 10)
C.Set("nameplates.bartex", "style")
EQ("texture du style rendue", s1.bar.calls.SetStatusBarTexture[1], TH.barTex)
C.Set("nameplates.fontsize", 12)
EQ("police : nom", s1.nameFs.fsize, 12)
EQ("police : vie", s1.hpFs.fsize, 12)
EQ("police : nom d'incantation", s1.cNameFs.fsize, 12)
EQ("police : minuterie d'effet", s1.dFs[1].fsize, 12)
C.Set("nameplates.fontsize", 0)
EQ("taille d'origine rendue (nom 9)", s1.nameFs.fsize, math.floor(9 * TH.fontScale + 0.5))
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_nameplates : desactivation")
C.Set("modules.nameplates", false)
EQ("module coupe", mod.enabled, false)
EQ("minuterie rendue", liveTasks("nameplates.tick"), 0)
EQ("emplacements rendus", M.nUsed, 0)
EQ("evenements retires", SUI.handlers["AURA_CAST_ON_OTHER"], nil)
EQ("evenements de lancement retires", SUI.handlers["UNIT_CASTEVENT"], nil)
EQ("debuffs oublies", M.nd, 0)
EQ("coupe : bordure d'origine rendue", pa.np.border.tex, "Interface\\Tooltips\\Nameplate-Border")
EQ("coupe : plaque de nouveau libre", pa.suiSkin, nil)
EQ("coupe : nom d'origine rendu (largeur)", pa.np.name:GetWidth(), 80)
EQ("coupe : emplacement vide", sa.plate, nil)
C.Set("modules.nameplates", true)
SETTLE()
EQ("module rallume", mod.enabled, true)
EQ("rallume : une minuterie", liveTasks("nameplates.tick"), 1)
Pump(0.1, 2)
T("rallume : plaques reprises", M.nUsed >= 1)
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()

