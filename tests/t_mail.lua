-- t_mail : module "mail" (ramassage en masse, filtres, envoi en masse, destinataires, journal, reglages, cycle de vie).
local SUI = ShikiUI
local C = SUI.Config
BGINSTALL()
MAILINSTALL()
BGRESET()
MAILRESET()
BGLAYOUT({ [0] = 16, 18 })
BOOT()
SETTLE()
local M = SUI.Mail
local mod = SUI.modules.mail

local function liveTasks(name)
  local n = 0
  for i = 1, table.getn(SUI.tasks) do
    if SUI.tasks[i].name == name and not SUI.tasks[i].dead then n = n + 1 end
  end
  return n
end
local function hasHandler(ev, fn)
  local h = SUI.handlers[ev]
  if not h then return false end
  for i = 1, table.getn(h) do if h[i] == fn then return true end end
  return false
end
local AH = "Stormwind Auction House"
local function fill()
  MAILRESET()
  MAILADD({ sender = "Alice", money = 100 })
  MAILADD({ sender = "Bob", item = 1001 })
  MAILADD({ sender = "Carl", cod = 50, item = 1002 })
  MAILADD({ sender = "GM", item = 1003, gm = true })
  MAILADD({ sender = AH, item = 1004, money = 200 })
  MAILADD({ sender = "Vide" })
  MAILADD({ sender = "Dan", item = 1005, count = 3 })
end
local function collect()
  M.StartCollect()
  Pump(0.3, 60)
end
local function resetCfg()
  C.Set("mail.filter", "all")
  C.Set("mail.takemoney", true)
  C.Set("mail.takeitems", true)
  C.Set("mail.keepfree", 0)
  C.Set("mail.deleteempty", false)
  C.Set("mail.autotake", false)
  C.Set("mail.confirmsend", true)
end

SECTION("t_mail : contrat et construction")
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
T("coupe par defaut", not mod.enabled)
EQ("coupe en mode Raid", mod.raid, "off")
EQ("aucun evenement avant activation", SUI.handlers["MAIL_SHOW"], nil)
EQ("aucun evenement de reponse avant activation", SUI.handlers["MAIL_INBOX_UPDATE"], nil)
C.Set("modules.mail", true)
SETTLE()
EQ("module actif", mod.enabled, true)
T("panneau construit", M.frame ~= nil)
EQ("panneau cache boite fermee", M.frame:IsShown(), false)
T("evenement d'ouverture ecoute", hasHandler("MAIL_SHOW", M.OnShow))
T("evenement de fermeture ecoute", hasHandler("MAIL_CLOSED", M.OnClose))
EQ("pas de reponse ecoutee boite fermee", SUI.handlers["MAIL_INBOX_UPDATE"], nil)
EQ("pas de minuterie boite fermee", liveTasks("mail.tick"), 0)
EQ("journal prealloue", table.getn(M.log), 50)
EQ("8 boutons de destinataires", table.getn(M.frame.recent), 8)

SECTION("t_mail : ouverture et fermeture de la boite")
fill()
MAILOPEN()
EQ("boite ouverte", M.open, true)
EQ("panneau visible", M.frame:IsShown(), true)
EQ("une minuterie", liveTasks("mail.tick"), 1)
T("reponse ecoutee", hasHandler("MAIL_INBOX_UPDATE", M.OnInbox))
T("envoi ecoute", hasHandler("MAIL_SEND_SUCCESS", M.OnSendSuccess))
MAILOPEN()
EQ("reouverture : toujours une seule minuterie", liveTasks("mail.tick"), 1)
Pump(0.3, 2)
EQ("7 courriers comptes", M.info.mails, 7)
EQ("4 courriers avec objet hors remboursement", M.info.items, 4)
MAILCLOSE()
EQ("boite fermee", M.open, false)
EQ("panneau cache", M.frame:IsShown(), false)
EQ("minuterie rendue", liveTasks("mail.tick"), 0)
EQ("reponse rendue", SUI.handlers["MAIL_INBOX_UPDATE"], nil)
EQ("envoi rendu", hasHandler("MAIL_SEND_SUCCESS", M.OnSendSuccess), false)
EQ("ramassage refuse boite fermee", M.StartCollect(), false)
EQ("envoi refuse boite fermee", M.RequestSend("Bob", true), false)

SECTION("t_mail : ramassage en masse")
resetCfg()
fill()
MAILFREE(20)
MAILOPEN()
CHATCLEAR()
collect()
EQ("ramassage termine", M.active, false)
EQ("argent ramasse", M.gold, 300)
EQ("objets ramasses (3 piles + 1 + 1)", M.items, 5)
EQ("places libres consommees", W.mail.free, 17)
EQ("argent du courrier 1 pris", W.mail.box[1].money, 0)
EQ("objet du courrier 2 pris", W.mail.box[2].item, nil)
EQ("courrier contre remboursement intact", W.mail.box[3].item, 1002)
EQ("courrier de MJ intact", W.mail.box[4].item, 1003)
EQ("argent hotel des ventes pris", W.mail.box[5].money, 0)
EQ("objet hotel des ventes pris", W.mail.box[5].item, nil)
EQ("objet de 3 pris", W.mail.box[7].item, nil)
EQ("aucun courrier supprime par defaut", table.getn(W.mail.box), 7)
CONTAINS("resume", CHATTEXT(), SUI.L("msg.mail.collected", 5, M.Money(300)))
EQ("jamais d'argent d'un COD", W.mail.box[3].cod, 50)
EQ("journal : 5 entrees", M.lcount, 5)
EQ("journal : le plus recent d'abord", M.LogGet(1).name, "Objet1005")
EQ("journal : quantite", M.LogGet(1).count, 3)
EQ("journal : le plus ancien en dernier", M.LogGet(5).money, 100)
EQ("journal : hors bornes", M.LogGet(6), nil)
EQ("journal : indice zero", M.LogGet(0), nil)
EQ("compteur apres ramassage", M.info.money, 0)
T("texte d'etat", string.find(M.frame.status:GetText(), "7", 1, true) ~= nil)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("mail log 2")
CONTAINS("commande log : objet", CHATTEXT(), "Objet1005")
CONTAINS("commande log : argent", CHATTEXT(), AH)
EQ("deuxieme ramassage ne reprend rien", (function() local g = M.gold; collect(); return M.gold end)(), 0)

SECTION("t_mail : filtres")
resetCfg()
fill() C.Set("mail.filter", "ah") collect()
EQ("hotel des ventes : argent", M.gold, 200)
EQ("hotel des ventes : objet pris", W.mail.box[5].item, nil)
EQ("hotel des ventes : autre argent intact", W.mail.box[1].money, 100)
EQ("hotel des ventes : autre objet intact", W.mail.box[2].item, 1001)
fill() C.Set("mail.filter", "noah") collect()
EQ("sans hotel des ventes : argent", M.gold, 100)
EQ("sans hotel des ventes : objet pris", W.mail.box[2].item, nil)
EQ("sans hotel des ventes : objet de l'hotel intact", W.mail.box[5].item, 1004)
EQ("sans hotel des ventes : argent de l'hotel intact", W.mail.box[5].money, 200)
fill() C.Set("mail.filter", "money") collect()
EQ("argent seulement : argent", M.gold, 300)
EQ("argent seulement : aucun objet", M.items, 0)
EQ("argent seulement : objet intact", W.mail.box[2].item, 1001)
resetCfg()
fill() C.Set("mail.takemoney", false) collect()
EQ("sans argent : rien d'argent", M.gold, 0)
EQ("sans argent : objets pris", M.items, 5)
EQ("sans argent : argent intact", W.mail.box[1].money, 100)
resetCfg()
fill() C.Set("mail.takeitems", false) collect()
EQ("sans objets : argent pris", M.gold, 300)
EQ("sans objets : aucun objet", M.items, 0)
EQ("sans objets : objet intact", W.mail.box[2].item, 1001)
resetCfg()

SECTION("t_mail : places libres et inventaire plein")
fill() MAILFREE(3) C.Set("mail.keepfree", 3)
CHATCLEAR()
collect()
EQ("places gardees : argent du premier courrier pris", M.gold, 100)
EQ("places gardees : aucun objet pris", M.items, 0)
EQ("places gardees : objet intact", W.mail.box[2].item, 1001)
EQ("places gardees : ramassage arrete", M.active, false)
CONTAINS("places gardees : message", CHATTEXT(), SUI.L("msg.mail.why.full"))
C.Set("mail.keepfree", 2)
fill() MAILFREE(3)
collect()
EQ("une place de plus : un seul objet de plus", W.mail.free, 2)
EQ("une place de plus : s'arrete ensuite", M.items, 1)
C.Set("mail.keepfree", 0)
fill() MAILFREE(0)
M.BagFree = function(bag) if bag == 0 then return 5 end return 0 end
CHATCLEAR()
collect()
EQ("jeu refuse : ramassage arrete", M.active, false)
EQ("jeu refuse : aucun objet", M.items, 0)
CONTAINS("jeu refuse : message", CHATTEXT(), SUI.L("msg.mail.why.full"))
MAILINSTALL()
EQ("curseur de reponse libere", M.waitUpd, false)

SECTION("t_mail : suppression des courriers vides")
resetCfg()
MAILRESET()
MAILADD({ sender = "A" })
MAILADD({ sender = "B", text = true })
MAILADD({ sender = "C", money = 50 })
collect()
EQ("vides gardes par defaut", MAILBOX(), "A,B,C")
C.Set("mail.deleteempty", true)
MAILRESET()
MAILADD({ sender = "A" })
MAILADD({ sender = "B", text = true })
MAILADD({ sender = "C", money = 50 })
collect()
EQ("courrier avec texte jamais supprime", MAILBOX(), "B")
MAILRESET()
MAILADD({ sender = "A", cod = 10, item = 1002 })
MAILADD({ sender = "B", gm = true })
collect()
EQ("COD et MJ jamais supprimes", MAILBOX(), "A,B")
C.Set("mail.filter", "money")
MAILRESET()
MAILADD({ sender = "A" })
collect()
EQ("filtre argent : pas de suppression", MAILBOX(), "A")
resetCfg()

SECTION("t_mail : serveur muet et reprise")
MAILRESET()
M.lcount, M.lhead = 0, 0
MAILADD({ sender = "A", money = 100 })
MAILADD({ sender = "B", money = 50 })
local n = 0
TakeInboxMoney = function(i) n = n + 1 end
collect()
EQ("3 essais par courrier puis on passe", n, 6)
EQ("ramassage termine malgre le silence", M.active, false)
EQ("rien compte sans reponse", M.gold, 0)
EQ("rien journalise sans reponse", M.lcount, 0)
MAILINSTALL()
MAILRESET()
MAILADD({ sender = "A", money = 100 })
M.StartCollect()
Fire("UI_ERROR_MESSAGE", "Another error")
EQ("erreur etrangere ignoree", M.active, true)
Fire("UI_ERROR_MESSAGE", nil)
EQ("erreur vide ignoree", M.active, true)
Pump(0.3, 20)
EQ("ramassage termine apres les erreurs etrangeres", M.active, false)
EQ("argent compte apres les erreurs etrangeres", M.gold, 100)
MAILINSTALL()
MAILRESET()
MAILADD({ sender = "A", money = 100 })
W.mail.lag = nil
collect()
EQ("sans reponse : le geste n'est pas compte deux fois", M.gold, 0)
MAILRESET()

SECTION("t_mail : ramassage automatique, arret et fermeture")
resetCfg()
fill()
MAILOPEN()
Pump(0.3, 10)
EQ("rien tout seul par defaut", M.items, 0)
MAILCLOSE()
C.Set("mail.autotake", true)
fill()
MAILOPEN()
Pump(0.3, 80)
EQ("ramassage auto : objets", M.items, 5)
EQ("ramassage auto : termine", M.active, false)
MAILCLOSE()
C.Set("mail.autotake", false)
fill()
MAILOPEN()
M.StartCollect()
Pump(0.3, 2)
EQ("en cours", M.active, true)
SlashCmdList["SHIKIUI"]("mail stop")
EQ("arrete par la commande", M.active, false)
M.StartCollect()
Pump(0.3, 1)
MAILCLOSE()
EQ("fermeture : ramassage coupe", M.active, false)
EQ("fermeture : rien en attente", M.waitUpd, false)
EQ("fermeture : minuterie rendue", liveTasks("mail.tick"), 0)
EQ("seconde demande pendant le ramassage ignoree", (function() MAILOPEN() M.StartCollect() return M.StartCollect() end)(), false)
MAILCLOSE()

SECTION("t_mail : liste d'envoi")
resetCfg()
M.ListClear()
EQ("liste vide", M.nlist, 0)
T("ajout par lien", M.ListAdd("|cffffffff|Hitem:5001:0:0:0|h[Objet5001]|h|r"))
T("ajout par numero", M.ListAdd("5002"))
T("ajout par numero avec espaces", M.ListAdd("  5003  "))
EQ("refus d'une chaine quelconque", M.ListAdd("abc"), false)
EQ("refus d'un nil", M.ListAdd(nil), false)
EQ("3 objets", M.nlist, 3)
T("table lue", M.sendList[5001] and M.sendList[5002] and M.sendList[5003])
T("doublon sans effet", M.ListAdd("5002"))
EQ("toujours 3", M.nlist, 3)
T("retrait", M.ListRemove("5003"))
EQ("retrait d'un absent", M.ListRemove("5003"), false)
EQ("2 objets", M.nlist, 2)
local saved = C.Get("mail.sendlist")
T("enregistree dans le profil", string.find(saved, "5001", 1, true) and string.find(saved, "5002", 1, true) and not string.find(saved, "5003", 1, true))
M.ReadList()
EQ("relecture identique", M.nlist, 2)
for i = 1, 150 do M.ListAdd(tostring(8000 + i)) end
EQ("limite de 100 objets", M.nlist, 100)
EQ("refus au dela de la limite", M.ListAdd("9999"), false)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("mail clear")
EQ("liste videe", M.nlist, 0)
CONTAINS("message de vidage", CHATTEXT(), SUI.L("msg.mail.cleared"))
CHATCLEAR()
SlashCmdList["SHIKIUI"]("mail list")
CONTAINS("liste vide annoncee", CHATTEXT(), SUI.L("msg.mail.list.none"))
SlashCmdList["SHIKIUI"]("mail add 7001")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("mail list")
CONTAINS("commande list", CHATTEXT(), SUI.L("msg.mail.list.line", 7001))
SlashCmdList["SHIKIUI"]("mail remove 7001")
EQ("commande remove", M.nlist, 0)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("mail add zzz")
CONTAINS("objet inconnu", CHATTEXT(), SUI.L("msg.mail.badref"))
CHATCLEAR()
SlashCmdList["SHIKIUI"]("mail")
CONTAINS("aide", CHATTEXT(), SUI.L("msg.mail.help", 0, 0))

SECTION("t_mail : envoi en masse")
resetCfg()
BGRESET()
BGLAYOUT({ [0] = 16, 18 })
MAILRESET()
BGPUT(0, 1, 5001) BGPUT(0, 2, 5002) BGPUT(0, 3, 6001) BGPUT(1, 1, 5001)
M.ListClear()
M.ListAdd("5001") M.ListAdd("5002")
MAILOPEN()
CHATCLEAR()
EQ("armement : pas encore envoye", M.RequestSend("Bob"), false)
EQ("armement : aucun courrier", table.getn(W.mail.sent), 0)
EQ("armement : destinataire", M.armTo, "Bob")
CONTAINS("armement : message", CHATTEXT(), SUI.L("msg.mail.arm", 3, "Bob"))
EQ("autre destinataire : re-arme seulement", M.RequestSend("Cleo", true), false)
EQ("autre destinataire : arme", M.armTo, "Cleo")
Pump(0.3, 40)
EQ("armement expire", M.armTo, nil)
EQ("armement expire : confirmation refusee", M.RequestSend("Cleo", true), false)
EQ("re-arme", M.armTo, "Cleo")
EQ("nom vide refuse", M.RequestSend("", true), false)
EQ("soi-meme refuse", M.RequestSend(UnitName("player"), true), false)
EQ("soi-meme refuse (casse)", M.RequestSend(string.upper(UnitName("player")), true), false)
T("envoi confirme", M.RequestSend("Cleo", true))
EQ("envoi en cours", M.sending, true)
EQ("3 piles a envoyer", M.ns, 3)
Pump(0.3, 60)
EQ("envoi termine", M.sending, false)
EQ("3 courriers", table.getn(W.mail.sent), 3)
EQ("destinataire", W.mail.sent[1].to, "Cleo")
EQ("un objet par courrier", W.mail.sent[2].count, 1)
EQ("objets envoyes retires du sac 0 (1)", BGIDS(0)[1], 0)
EQ("objets envoyes retires du sac 0 (2)", BGIDS(0)[2], 0)
EQ("objet hors liste intact", BGIDS(0)[3], 6001)
EQ("objet du sac 1 envoye", BGIDS(1)[1], 0)
EQ("envoye compte", M.sent, 3)
EQ("destinataire memorise", C.Get("mail.recent"), "Cleo")
EQ("curseur libre", W.bg.cursor, nil)
EQ("plus rien a envoyer", M.RequestSend("Cleo", true), false)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("mail send Cleo")
CONTAINS("rien a envoyer annonce", CHATTEXT(), SUI.L("msg.mail.nothing"))

SECTION("t_mail : envoi sans confirmation, erreur, commande")
C.Set("mail.confirmsend", false)
MAILRESET()
BGPUT(0, 1, 5001) BGPUT(0, 2, 5002)
T("envoi direct", M.RequestSend("Dora"))
Pump(0.3, 40)
EQ("envoi direct : 2 courriers", table.getn(W.mail.sent), 2)
EQ("destinataires : Dora puis Cleo", C.Get("mail.recent"), "Dora,Cleo")
MAILRESET()
BGPUT(0, 1, 5001) BGPUT(0, 2, 5002)
W.mail.sendfail = "Cannot send"
CHATCLEAR()
M.RequestSend("Dora")
Pump(0.3, 20)
EQ("erreur du jeu : envoi arrete", M.sending, false)
CONTAINS("erreur du jeu : message", CHATTEXT(), SUI.L("msg.mail.sendstopped", "Cannot send"))
EQ("erreur du jeu : aucun courrier", table.getn(W.mail.sent), 0)
EQ("erreur du jeu : curseur libre", W.bg.cursor, nil)
MAILRESET()
BGRESET()
BGLAYOUT({ [0] = 16, 18 })
BGPUT(0, 1, 5001)
C.Set("mail.confirmsend", true)
SlashCmdList["SHIKIUI"]("mail send Zed")
EQ("commande : armement", M.armTo, "Zed")
EQ("commande : rien envoye", table.getn(W.mail.sent), 0)
SlashCmdList["SHIKIUI"]("mail send Zed ok")
Pump(0.3, 20)
EQ("commande avec ok : envoye", table.getn(W.mail.sent), 1)
EQ("commande avec ok : destinataire", W.mail.sent[1].to, "Zed")
BGPUT(0, 1, 5001)
M.RequestSend("Yan", true)
M.RequestSend("Yan", true)
Pump(0.3, 1)
SlashCmdList["SHIKIUI"]("mail stop")
EQ("arret de l'envoi par la commande", M.sending, false)
EQ("arret : curseur libre", W.bg.cursor, nil)
Pump(0.3, 20)
MAILCLOSE()
MAILOPEN()
BGPUT(0, 5, 5001)
M.RequestSend("Xia", true)
M.RequestSend("Xia", true)
Pump(0.3, 1)
MAILCLOSE()
EQ("fermeture : envoi coupe", M.sending, false)
EQ("fermeture : armement oublie", M.armTo, nil)
MAILOPEN()

C.Set("mail.confirmsend", false)
MAILRESET()
W.mail.lag = nil
BGRESET()
BGLAYOUT({ [0] = 16, 18 })
BGPUT(0, 1, 5001) BGPUT(0, 2, 5002)
M.RequestSend("Ida")
Pump(0.3, 60)
EQ("sans reponse : envoi termine", M.sending, false)
EQ("sans reponse : rien compte", M.sent, 0)
EQ("sans reponse : une tentative par pile", table.getn(W.mail.sent), 2)
C.Set("mail.confirmsend", true)
MAILRESET()
BGRESET()
BGLAYOUT({ [0] = 16, 18 })

SECTION("t_mail : destinataires memorises")
C.SetBase("mail.recent", "")
C.Set("mail.maxrecent", 3)
M.Remember("Aa") M.Remember("Bb") M.Remember("Aa")
EQ("dedoublonnage et ordre", C.Get("mail.recent"), "Aa,Bb")
M.Remember("aa")
EQ("sans tenir compte de la casse", C.Get("mail.recent"), "aa,Bb")
M.Remember("Cc") M.Remember("Dd")
EQ("limite", C.Get("mail.recent"), "Dd,Cc,aa")
M.Remember("a,b")
M.Remember("")
M.Remember("   ")
M.Remember("a|b")
M.Remember("abcdefghijklmnopqrstuvwxyz")
M.Remember(nil)
M.Remember(12)
EQ("noms invalides refuses", C.Get("mail.recent"), "Dd,Cc,aa")
M.Remember("  Ee  ")
EQ("espaces retires", C.Get("mail.recent"), "Ee,Dd,Cc")
C.Set("mail.remember", false)
M.Remember("Ff")
EQ("memoire coupee", C.Get("mail.recent"), "Ee,Dd,Cc")
C.Set("mail.remember", true)
Pump(0.3, 2)
EQ("bouton 1", M.frame.recent[1].name, "Ee")
EQ("bouton 3", M.frame.recent[3].name, "Cc")
EQ("bouton 4 cache", M.frame.recent[4]:IsShown(), false)
M.frame.recent[2].onclick(M.frame.recent[2], "LeftButton")
EQ("clic : remplit le champ du destinataire", W.mail.name, "Dd")
W.mail.name = "Hank"
Pump(0.3, 2)
Fire("MAIL_SEND_SUCCESS")
EQ("envoi manuel memorise", C.Get("mail.recent"), "Hank,Ee,Dd")
MAILRESET()
W.mail.name = "Gina"
BGRESET()
BGLAYOUT({ [0] = 16, 18 })
BGPUT(0, 1, 5001)
M.frame.send.onclick(M.frame.send, "LeftButton")
EQ("bouton envoyer : arme avec le nom du champ", M.armTo, "Gina")
M.frame.send.onclick(M.frame.send, "LeftButton")
Pump(0.3, 20)
EQ("bouton envoyer : deuxieme clic envoie", W.mail.sent[1] and W.mail.sent[1].to, "Gina")
M.frame.take.onclick(M.frame.take, "LeftButton")
EQ("bouton tout prendre", M.active, true)
M.frame.take.onclick(M.frame.take, "LeftButton")
EQ("meme bouton arrete", M.active, false)

SECTION("t_mail : journal circulaire")
M.lcount, M.lhead = 0, 0
C.Set("mail.logsize", 10)
for i = 1, 12 do M.LogAdd("S", "Obj" .. i, i, 0) end
EQ("journal borne", M.lcount, 10)
EQ("le plus recent", M.LogGet(1).count, 12)
EQ("le plus ancien garde", M.LogGet(10).count, 3)
EQ("au dela", M.LogGet(11), nil)
C.Set("mail.logsize", 10)
M.lcount, M.lhead = 0, 0

SECTION("t_mail : reglages et panneau")
EQ("option panneau par defaut", C.Get("mail.panel"), true)
C.Set("mail.panel", false)
EQ("panneau cache par l'option", M.frame:IsShown(), false)
C.Set("mail.panel", true)
EQ("panneau reaffiche", M.frame:IsShown(), true)
C.Set("mail.keepfree", 5)
C.Reset("mail.keepfree")
EQ("reinitialisation", C.Get("mail.keepfree"), 0)
EQ("filtre par defaut", C.Get("mail.filter"), "all")
EQ("suppression des vides coupee par defaut", C.Get("mail.deleteempty"), false)
EQ("ramassage auto coupe par defaut", C.Get("mail.autotake"), false)
EQ("confirmation d'envoi par defaut", C.Get("mail.confirmsend"), true)
local nopt = 0
for i = 1, table.getn(mod.options) do nopt = nopt + 1 end
T("au moins 10 options", nopt >= 10)
EQ("montant formate", M.Money(12345), "1g 23s 45c")
EQ("montant zero", M.Money(0), "0g 0s 0c")
EQ("montant nil", M.Money(nil), "0g 0s 0c")
T("hotel des ventes reconnu", M.IsAH("Orgrimmar Auction House"))
EQ("autre expediteur", M.IsAH("Alice"), false)
EQ("expediteur nil", M.IsAH(nil), false)

SECTION("t_mail : combat et allocation")
fill()
MAILFREE(20)
local cr = CREATED
W.combat = true
collect()
EQ("ramassage en combat sans creation de frame", CREATED, cr)
W.combat = false
fill()
cr = CREATED
collect()
EQ("ramassage sans creation de frame", CREATED, cr)

SECTION("t_mail : engrenage")
local function gearCheck(label, parent, cat, titleKey)
  local g = parent and parent.suiGears and parent.suiGears[1]
  T(label .. " : engrenage cree", g ~= nil)
  if not g then return end
  EQ(label .. " : parent", g.suiGearParent, parent)
  EQ(label .. " : categorie", g.gearCat, cat)
  EQ(label .. " : titre", g.gearTitle, SUI.L(titleKey))
  T(label .. " : niveau au-dessus du contenu", g:GetFrameLevel() >= parent:GetFrameLevel() + 2)
  local shown
  local keep = SUI.Menu.Show
  SUI.Menu.Show = function(a) shown = a end
  Click(g)
  SUI.Menu.Show = keep
  EQ(label .. " : le clic ouvre la page du module", shown, cat)
end
gearCheck("courrier", M.frame, "mail", "msg.mail.gear")
EQ("courrier : coin haut droit", M.frame.suiGears[1].points[1][1], "TOPRIGHT")
EQ("courrier : le texte d'etat laisse la place de l'engrenage", M.frame.status:GetWidth(), 212)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_mail : coupure")
MAILOPEN()
M.StartCollect()
C.Set("modules.mail", false)
EQ("module coupe", mod.enabled, false)
EQ("panneau cache", M.frame:IsShown(), false)
EQ("ramassage coupe", M.active, false)
EQ("minuterie rendue", liveTasks("mail.tick"), 0)
EQ("ouverture rendue", SUI.handlers["MAIL_SHOW"], nil)
EQ("fermeture rendue", SUI.handlers["MAIL_CLOSED"], nil)
EQ("reponse rendue", SUI.handlers["MAIL_INBOX_UPDATE"], nil)
EQ("erreurs rendues", hasHandler("UI_ERROR_MESSAGE", M.OnError), false)
EQ("boite consideree fermee", M.open, false)
C.Set("modules.mail", true)
SETTLE()
EQ("rallume", mod.enabled, true)
EQ("panneau cache boite fermee", M.frame:IsShown(), false)
MAILOPEN()
EQ("fonctionne apres rallumage", M.frame:IsShown(), true)
MAILCLOSE()
EQ("aucune erreur interne", SUI.errCount, 0)
SECTION("t_mail : deplacement (Mover + Maj-glisser)")
do
  local f = M.frame
  local rec = SUI.Mover.items["mail"]
  T("enregistre au Mover", rec ~= nil and rec.frame == f)
  EQ("cle unique Layout", SUI.Layout.items["mail"] and SUI.Layout.items["mail"].frame, f)
  EQ("nom lisible", SUI.Mover.Label("mail") ~= "", true)
  local oldShift, oldCombat = IsShiftKeyDown, W.combat
  local down, up = f:GetScript("OnMouseDown"), f:GetScript("OnMouseUp")
  T("scripts poses", down ~= nil and up ~= nil)
  IsShiftKeyDown = function() return nil end
  arg1 = "LeftButton"
  down()
  EQ("sans Maj : pas de glissement", f.moving, nil)
  IsShiftKeyDown = function() return 1 end
  down()
  EQ("avec Maj : glissement", f.moving, true)
  f.left, f.bottom = 123, 77
  up()
  EQ("fin du glissement", f.moving, false)
  local l, b = C.GetPos(SUI.Layout.WriteKey("mail"))
  EQ("position memorisee X", l, 123)
  EQ("position memorisee Y", b, 77)
  SUI.Mover.Reset("mail")
  EQ("remise a zero", C.GetPos("mail"), nil)
  IsShiftKeyDown = function() return 1 end
  down()
  EQ("glissement relance", f.moving, true)
  f.left, f.bottom = 55, 66
  f:GetScript("OnHide")()
  EQ("masquage : fin du glissement", f.moving, false)
  EQ("masquage : position memorisee", (C.GetPos(SUI.Layout.WriteKey("mail"))), 55)
  arg1 = "RightButton"
  down()
  EQ("clic droit : pas de glissement", f.moving, false)
  arg1 = "LeftButton"
  local savedMover = SUI.Mover
  SUI.Mover = nil
  down()
  f.left, f.bottom = 31, 32
  up()
  SUI.Mover = savedMover
  EQ("sans Mover : memorisee", (C.GetPos(SUI.Layout.WriteKey("mail"))), 31)
  W.combat = true
  down()
  EQ("pas de glissement en combat", f.moving, false)
  W.combat = oldCombat
  IsShiftKeyDown = oldShift
  arg1 = nil
end

-- vrai M.BagFree (API 1.12, sans GetContainerNumFreeSlots) : compte les cases vides via GetContainerNumSlots / GetContainerItemInfo
do
  local sz, inf = GetContainerNumSlots, GetContainerItemInfo
  GetContainerNumSlots = function(b) if b == 0 then return 4 end return 0 end
  GetContainerItemInfo = function(b, s) if s == 2 then return "tex", 1 end return nil end
  EQ("BagFree reel : 3 cases vides sur 4", M.BagFreeReal(0), 3)
  EQ("le client 1.12 n a pas GetContainerNumFreeSlots (non utilise)", rawget(_G, "GetContainerNumFreeSlots"), nil)
  GetContainerNumSlots, GetContainerItemInfo = sz, inf
end

SECTION("t_mail : saisie du courrier (champs recouverts, clic-zone, Tab, panneau)")
do
  if ShikiUI_Wizard then ShikiUI_Wizard:Hide() end      -- assistant de premiere installation (autre fichier) : recouvre tout dans la simulation
  MAILFRAMES()
  local mf, sf = MailFrame, SendMailFrame
  local nb, sj, bd, sc = SendMailNameEditBox, SendMailSubjectEditBox, SendMailBodyEditBox, SendMailScrollFrame
  MAILOPEN()
  Pump(0.5)
  local P = M.frame
  MAILSTRATA(P)
  -- repartir d'un etat propre (l'ouverture a deja reparee)
  nb.level, sj.level, bd.level = 12, 12, 13
  M.fixes = 0
  EQ("aucun cadre ne recouvre : rien a corriger", M.SyncFields(), 0)
  EQ("niveau intact", nb.level, 12)
  -- un cadre perime au-dessus du champ (niveau 40, meme strate)
  local cover = MAILFRAME("Frame", "TestCover", mf, { level = 40, left = 90, bottom = 390, w = 240, h = 40, mouse = true })
  -- une AUTRE fenetre legitimement au-dessus (pas dans le courrier) : signalee, jamais traversee
  local other = MAILFRAME("Frame", "TestOther", UIParent, { level = 500, left = 90, bottom = 390, w = 240, h = 40, mouse = true })
  EQ("deux cadres au-dessus", table.getn(M.Overlays(nb)), 2)
  EQ("seul celui du courrier est corrige", M.SyncFields(), 1)
  EQ("niveau juste au-dessus du cadre du courrier", nb.level, 41)
  EQ("l'autre fenetre reste signalee", M.Overlays(nb)[1], other)
  other.shown = false
  nb.level = 12
  M.fixes = 0
  EQ("le recouvrement est vu", table.getn(M.Overlays(nb)), 1)
  EQ("le recouvrement est le bon cadre", M.Overlays(nb)[1], cover)
  EQ("le recouvrement fait partie du courrier", M.Overlays(nb)[1]:GetParent(), mf)
  EQ("champ voisin non recouvert", table.getn(M.Overlays(sj)), 0)
  EQ("un champ corrige", M.SyncFields(), 1)
  EQ("champ rehausse au-dessus du cadre", nb.level, 41)
  EQ("plus de recouvrement", table.getn(M.Overlays(nb)), 0)
  EQ("idempotent", M.SyncFields(), 0)
  EQ("compteur", M.fixes, 1)
  -- cadre sans souris : ne bloque pas
  cover.mouse = false
  nb.level = 12
  EQ("sans souris : pas un recouvrement", table.getn(M.Overlays(nb)), 0)
  -- cadre cache : ne bloque pas
  cover.mouse = true
  cover.shown = false
  EQ("cache : pas un recouvrement", table.getn(M.Overlays(nb)), 0)
  cover.shown = true
  -- autre strate : signale mais pas touche
  cover.strata = "FULLSCREEN_DIALOG"
  EQ("autre strate : vu", table.getn(M.Overlays(nb)), 1)
  EQ("autre strate : champ pas touche", M.SyncFields(), 0)
  EQ("autre strate : niveau intact", nb.level, 12)
  cover.shown = false
  cover.strata = "MEDIUM"
  -- ancetre qui capte la souris au-dessus de son enfant (niveau perime)
  sf.mouse = true
  sf.level = 60
  sj.level = 12
  EQ("l'ancetre recouvre", table.getn(M.Overlays(sj)) >= 1, true)
  M.SyncFields()
  T("champs sous l'ancetre rehausses", sj.level > 60 and nb.level > 60 and bd.level > 60)
  sf.mouse = false
  sf.level = 11
  nb.level, sj.level, bd.level = 12, 12, 13
  -- onglet Envoyer ferme : champs invisibles, ignores
  sf.shown = false
  cover.shown, cover.mouse = true, true
  EQ("onglet Envoyer ferme : rien a faire", M.SyncFields(), 0)
  sf.shown = true
  cover.shown = false

  SECTION("t_mail : saisie - scripts Tab / Entree / Echap et clic dans la zone du texte")
  M.WireFields()
  T("Tab du destinataire pose", nb.scripts.OnTabPressed ~= nil)
  T("Entree de l'objet posee", sj.scripts.OnEnterPressed ~= nil)
  T("Echap pose", nb.scripts.OnEscapePressed ~= nil and bd.scripts.OnEscapePressed ~= nil)
  EQ("souris active", nb.mouse, true)
  nb:SetFocus()
  nb.scripts.OnTabPressed()
  EQ("Tab : objet a le focus", sj.focus, true)
  sj.scripts.OnEnterPressed()
  EQ("Entree : texte a le focus", bd.focus, true)
  this = bd
  bd.scripts.OnEscapePressed()
  EQ("Echap : focus rendu", bd.focus, false)
  T("zone du texte captante", sc.mouse == true)
  bd.focus = false
  sc.scripts.OnMouseDown()
  EQ("clic dans la zone : le texte a le focus", bd.focus, true)
  -- un script du jeu deja present n'est pas ecrase
  local own = function() end
  nb.suiMailWired = nil
  nb.scripts.OnTabPressed = own
  M.WireFields()
  EQ("script du jeu conserve", nb.scripts.OnTabPressed, own)
  -- le script de la zone garde l'ancien
  local called = 0
  sc.suiMailWired = nil
  sc.scripts.OnMouseDown = function() called = called + 1 end
  M.WireFields()
  bd.focus = false
  sc.scripts.OnMouseDown()
  EQ("ancien OnMouseDown conserve", called, 1)
  EQ("et le focus est donne", bd.focus, true)

  SECTION("t_mail : saisie - panneau sous la fenetre du courrier")
  P.left, P.bottom = 100, 100
  EQ("panneau sur la fenetre : descend", M.SinkPanel(), true)
  EQ("strate sous MailFrame", P.strata, "LOW")
  EQ("enfants aussi", P.recent[1].strata, "LOW")
  EQ("deja descendu : rien", M.SinkPanel(), false)
  P.left = 700
  EQ("a cote : remonte", M.SinkPanel(), true)
  EQ("strate normale", P.strata, "MEDIUM")
  EQ("enfants aussi (remontes)", P.fix.strata, "MEDIUM")
  P.left = 100
  W.combat = true
  EQ("en combat : le panneau ne bouge pas", M.SinkPanel(), false)
  EQ("en combat : strate intacte", P.strata, "MEDIUM")
  EQ("en combat : reparation sans effet", M.RepairInput(), 0)
  W.combat = false
  mf.strata = "DIALOG"
  EQ("fenetre en DIALOG : panneau sous elle", M.SinkPanel(), true)
  EQ("strate juste dessous", P.strata, "HIGH")
  mf.strata = "MEDIUM"
  M.SinkPanel()
  P.left = 700
  M.SinkPanel()

  SECTION("t_mail : saisie - ouverture, minuterie, option, bouton, diagnostic")
  -- reparation automatique juste apres l'ouverture
  MAILCLOSE()
  nb.level = 12
  cover.shown, cover.strata, cover.level = true, "MEDIUM", 70
  M.fixes = 0
  other.shown = true       -- l'autre fenetre est la aussi : jamais traversee
  MAILOPEN()
  Pump(0.5)
  EQ("reparation apres l'ouverture", nb.level, 71)
  T("compte", M.fixes >= 1)
  -- surveillance : un nouveau recouvrement apparait onglet Envoyer ouvert
  cover.level = 90
  Pump(0.35, 12)
  EQ("reparation periodique", nb.level, 91)
  -- passage sur l'onglet Envoyer
  cover.level = 120
  sf.shown = false
  Pump(0.7)
  sf.shown = true
  Pump(0.7)
  EQ("reparation au passage sur l'onglet Envoyer", nb.level, 121)
  -- option coupee
  C.Set("mail.fixfields", false)
  cover.level = 150
  Pump(0.35, 14)
  EQ("option coupee : rien reparee", nb.level, 121)
  C.Set("mail.fixfields", true)
  Pump(0.35, 14)
  EQ("option rallumee : reparation", nb.level, 151)
  -- bouton du panneau
  nb.focus = false
  cover.level = 200
  P.fix.onclick(P.fix, "LeftButton")
  EQ("bouton : champ repare", nb.level, 201)
  EQ("bouton : curseur dans le destinataire", nb.focus, true)
  CHATCLEAR()
  sf.shown = false
  P.fix.onclick(P.fix, "LeftButton")
  T("onglet Envoyer ferme : message", string.find(CHATTEXT(), SUI.L("msg.mail.opensend"), 1, true) ~= nil)
  sf.shown = true
  -- bouton destinataire : passe a l'objet
  C.Set("mail.remember", true)
  M.Remember("Zed")
  Pump(0.5)
  sj.focus = false
  P.recent[1].onclick(P.recent[1], "LeftButton")
  EQ("destinataire pose", nb.text, "Zed")
  EQ("puis curseur dans l'objet", sj.focus, true)
  -- infobulles
  T("infobulle du bouton Tout prendre", P.take.scripts.OnEnter ~= nil and P.take.scripts.OnLeave ~= nil)
  T("infobulle du bouton Reparer", P.fix.scripts.OnEnter ~= nil)
  GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
  this = P.fix
  P.fix.scripts.OnEnter()
  T("infobulle affichee", GameTooltip.lines ~= nil and GameTooltip.lines[1] == SUI.L("tip.mail.btn.fix"))
  P.fix.scripts.OnLeave()
  -- diagnostic
  cover.level = 300
  CHATCLEAR()
  local out = M.Diag(false)
  local all = table.concat(out, "\n")
  T("diag : cadres du courrier listes", string.find(all, "MailFrame", 1, true) and string.find(all, "SendMailNameEditBox", 1, true))
  T("diag : recouvrement signale", string.find(all, "AU-DESSUS : TestCover", 1, true) ~= nil)
  EQ("diag sans fix ne repare pas", nb.level, 201)
  out = M.Diag(true)
  EQ("diag fix repare", nb.level, 301)
  all = table.concat(out, "\n")
  T("diag : plus de recouvrement du courrier", string.find(all, "AU-DESSUS : TestCover", 1, true) == nil)
  T("diag : l autre fenetre reste signalee", string.find(all, "AU-DESSUS : TestOther", 1, true) ~= nil)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"]("maildiag")
  T("commande /sui maildiag", string.find(CHATTEXT(), "MailFrame", 1, true) ~= nil)
  M.lastDiag = nil
  SlashCmdList["SHIKIUI"]("mail diag fix")
  T("commande /sui mail diag fix", M.lastDiag ~= nil)
  -- boite fermee : refus
  MAILCLOSE()
  CHATCLEAR()
  EQ("boite fermee : refus", M.OnRepair(), false)
  -- sans champs du jeu (autre version du client) : aucune erreur
  MAILFRAMES_OFF()
  MAILOPEN()
  Pump(0.35, 14)
  EQ("sans fenetre du courrier : aucune erreur", M.RepairInput(), 0)
  EQ("diag sans fenetre : aucune erreur", type(M.Diag(false)), "table")
  MAILCLOSE()
  EQ("aucune erreur interne (saisie)", SUI.errCount, 0)
end

DONE()
