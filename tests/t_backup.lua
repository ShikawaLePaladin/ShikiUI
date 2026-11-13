-- t_backup : sauvegardes / profils (Backup.lua, Config.lua), page "Profils et sauvegardes" du menu, assistant face a pfUI (cohabitation).
-- L'ancien import des reglages pfUI a ete supprime : plus aucune API Import* dans Migrate, plus de sous-commande /sui migrate import.
local SUI = ShikiUI
local C = SUI.Config
local B = SUI.Backup
local M = SUI.Menu
local Mg = SUI.Migrate

CreateFrame("Frame", "PlayerFrame", UIParent)
CreateFrame("Frame", "TargetFrame", UIParent)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)

local TNOW = 1000000
rawset(_G, "time", function() return TNOW end)
rawset(_G, "date", function(f, t) return "2026-01-02 03:04" end)

local function cmd(s)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"](s)
  return CHATTEXT()
end
local function bcmd(s)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"]("backup " .. s)
  return CHATTEXT()
end

SECTION("t_backup : instantanes")
BOOT()
SETTLE()
C.SetGlobal("firstRun", false)
EQ("base de sauvegardes creee", type(C.db.backups), "table")
EQ("version de base", C.db.v, 2)
EQ("aucune sauvegarde au depart", table.getn(B.List()), 0)
C.SetBase("units.width", 250)
local id1 = B.Create("manual", "avant")
T("identifiant", type(id1) == "number")
EQ("une sauvegarde", table.getn(B.List()), 1)
local r = B.List()[1]
EQ("profil", r.profile, C.curName)
EQ("etiquette", r.label, "avant")
EQ("copie des reglages", r.v["units.width"], 250)
EQ("date relevee", r.t, TNOW)
EQ("libelle de la date", B.Stamp(r.t), "2026-01-02 03:04")
EQ("raison", B.Reason(r), "Manuelle")
CONTAINS("resume", B.Summary(r), "reglage(s)")
-- la copie est profonde : changer le profil ne change pas l'instantane
C.SetBase("units.width", 300)
EQ("instantane intact", B.Find(id1).v["units.width"], 250)
-- restauration : instantane de securite d'abord
local nb = table.getn(B.List())
local ok, key = B.Restore(id1)
EQ("restauration", ok, true)
EQ("valeur restauree", C.Get("units.width"), 250)
EQ("securite prise avant restauration", table.getn(B.List()), nb + 1)
EQ("securite : raison", B.List()[1].reason, "restore")
EQ("securite : ancienne valeur", B.List()[1].v["units.width"], 300)
ok, key = B.Restore(99999)
EQ("instantane inconnu", ok, false)
EQ("instantane inconnu : message", key, "msg.menu.bk.unknown")
W.combat = true
ok, key = B.Restore(id1)
EQ("pas de restauration en combat", ok, false)
W.combat = false

SECTION("t_backup : automatiques, copie identique, rotation")
local before = table.getn(B.List())
local a1 = B.AutoCreate("periodic")
T("copie auto prise (le profil a change)", a1 ~= nil)
EQ("copie identique non empilee", B.AutoCreate("periodic"), nil)
EQ("une seule de plus", table.getn(B.List()), before + 1)
C.SetGlobal("backup.auto", false)
C.SetBase("units.width", 260)
EQ("automatique coupe : rien", B.AutoCreate("logout"), nil)
local idw = B.Create("wizard")
T("la securite est prise meme si l'auto est coupe", idw ~= nil)
C.SetGlobal("backup.auto", true)
C.Set("backup.keep", 3)
for i = 1, 8 do
  C.SetBase("units.width", 200 + i * 10)
  B.Create("wizard")
end
local nauto, nman = 0, 0
local l = B.List()
for i = 1, table.getn(l) do
  if l[i].reason == "manual" then nman = nman + 1 else nauto = nauto + 1 end
end
EQ("rotation : 3 automatiques gardees", nauto, 3)
EQ("les manuelles ne tournent pas", nman, 1)
EQ("la plus recente est gardee", B.List()[1].v["units.width"], 280)
T("la manuelle du depart est gardee", B.Find(id1) ~= nil)
for i = 1, 33 do B.Create("manual") end
nman = 0
l = B.List()
for i = 1, table.getn(l) do if l[i].reason == "manual" then nman = nman + 1 end end
EQ("plafond des manuelles", nman, B.MAXMANUAL)
-- suppression
local first = B.List()[1].id
ok, key = B.Delete(first)
EQ("suppression", ok, true)
EQ("suppression : disparu", B.Find(first), nil)
ok, key = B.Delete(first)
EQ("suppression d'un inconnu", ok, false)

SECTION("t_backup : jamais d'ecrasement sans instantane")
C.Set("backup.keep", 20)
local n0 = table.getn(B.List())
C.SetBase("units.width", 310)
C.ResetProfile()
EQ("reinitialisation : un instantane de plus", table.getn(B.List()), n0 + 1)
EQ("reinitialisation : raison", B.List()[1].reason, "reset")
EQ("reinitialisation : ancienne valeur gardee", B.List()[1].v["units.width"], 310)
ok = C.NewProfile("Tmp")
EQ("profil cree", ok, true)
C.db.profiles.Tmp.v["units.height"] = 50
n0 = table.getn(B.List())
ok = C.DeleteProfile("Tmp")
EQ("profil supprime", ok, true)
EQ("suppression : un instantane de plus", table.getn(B.List()), n0 + 1)
EQ("suppression : raison", B.List()[1].reason, "delete")
EQ("suppression : profil", B.List()[1].profile, "Tmp")
ok, key = B.Restore(B.List()[1].id)
EQ("le profil supprime revient", ok, true)
EQ("profil recree", C.db.profiles.Tmp.v["units.height"], 50)
EQ("restaurer un autre profil le rend actif", C.curName, "Tmp")
C.SelectProfile("Default")
-- renommer
C.db.chars["Autre-Royaume"] = "Tmp"
ok, key = C.RenameProfile("Tmp", "Tmp2")
EQ("renommer", ok, true)
EQ("renommer : message", key, "msg.menu.prof.renamed")
EQ("renomme : nouveau nom", C.db.profiles.Tmp2.v["units.height"], 50)
EQ("les personnages suivent le profil renomme", C.db.chars["Autre-Royaume"], "Tmp2")
EQ("renomme : ancien nom disparu", C.db.profiles.Tmp, nil)
ok, key = C.RenameProfile("Tmp2", "Default")
EQ("renommer vers un nom pris", ok, false)
ok, key = C.RenameProfile("Absent", "Zed")
EQ("renommer un inconnu", ok, false)
ok, key = C.RenameProfile("Tmp2", "")
EQ("nom vide refuse", ok, false)
local follow = false
for i = 1, table.getn(B.List()) do if B.List()[i].profile == "Tmp2" then follow = true end end
T("les sauvegardes suivent le profil renomme", follow)
C.DeleteProfile("Tmp2")
C.db.chars["Autre-Royaume"] = nil

SECTION("t_backup : connexion / deconnexion")
local g = C.db.global
g.firstRun = false
g.lastVersion = "0.0.0"
C.SetBase("units.width", 270)
n0 = table.getn(B.List())
B.OnLogin()
EQ("mise a jour : un instantane", table.getn(B.List()), n0 + 1)
EQ("mise a jour : raison", B.List()[1].reason, "update")
EQ("version memorisee", g.lastVersion, SUI.VERSION)
n0 = table.getn(B.List())
B.OnLogin()
EQ("meme version : rien", table.getn(B.List()), n0)
C.Set("backup.hours", 24)
g.lastAuto = TNOW - 3600
C.SetBase("units.width", 280)
B.OnLogin()
EQ("periodique : trop tot", table.getn(B.List()), n0)
TNOW = TNOW + 30 * 3600
B.OnLogin()
EQ("periodique : un instantane", table.getn(B.List()), n0 + 1)
EQ("periodique : raison", B.List()[1].reason, "periodic")
C.SetBase("units.width", 290)
C.Set("backup.logout", false)
n0 = table.getn(B.List())
B.OnLogout()
EQ("deconnexion coupee : rien", table.getn(B.List()), n0)
C.Set("backup.logout", true)
B.OnLogout()
EQ("deconnexion : un instantane", table.getn(B.List()), n0 + 1)
EQ("deconnexion : raison", B.List()[1].reason, "logout")
B.OnLogout()
EQ("deconnexion identique : rien de plus", table.getn(B.List()), n0 + 1)
g.firstRun = true
g.lastVersion = "0.0.0"
g.lastAuto = 0
C.SetBase("units.width", 300)
n0 = table.getn(B.List())
B.OnLogin()
EQ("premier lancement : pas de copie", table.getn(B.List()), n0)
g.firstRun = false

C.Set("backup.hours", 48)
local idg = B.Create("manual", "globaux")
C.Set("backup.hours", 12)
B.Restore(idg)
EQ("reglages globaux restaures", C.Get("backup.hours"), 48)
B.Delete(idg)

SECTION("t_backup : commande /sui backup")
local t = bcmd("now Mon test")
CONTAINS("now : message", t, "creee")
EQ("now : etiquette", B.List()[1].label, "Mon test")
EQ("now : manuelle", B.List()[1].reason, "manual")
t = bcmd("list")
CONTAINS("list : ligne", t, "Mon test")
CONTAINS("list : usage", t, "/sui backup now")
local last = B.List()[1].id
C.SetBase("units.width", 280)
t = bcmd("restore " .. last)
CONTAINS("restore : message", t, "restauree")
t = bcmd("restore 99999")
CONTAINS("restore inconnu", t, "introuvable")
t = bcmd("delete " .. last)
CONTAINS("delete : message", t, "supprimee")
EQ("delete : disparu", B.Find(last), nil)

SECTION("t_backup : l'import pfUI n'existe plus")
EQ("plus de Mg.ImportPlan", Mg.ImportPlan, nil)
EQ("plus de Mg.Import", Mg.Import, nil)
EQ("plus de Mg.ImportUndo", Mg.ImportUndo, nil)
EQ("plus de Mg.ImportCommand", Mg.ImportCommand, nil)
EQ("plus de Mg.IMPORT_CATS", Mg.IMPORT_CATS, nil)
EQ("plus de Mg.NOT_IMPORTABLE", Mg.NOT_IMPORTABLE, nil)
local t
t = cmd("migrate import")
CONTAINS("migrate import : usage (sous-commande inconnue)", t, "/sui migrate take")
t = cmd("migrate preview")
CONTAINS("migrate preview : usage", t, "/sui migrate take")
t = cmd("migrate undo")
CONTAINS("migrate undo : usage", t, "/sui migrate take")
T("l'aide ne parle plus d'import pfUI", not string.find(t, "import", 1, true))
EQ("pas de cle de traduction d'import pfUI (fr)", SUI.locales.fr["mod.menu.imp.usage"], nil)
EQ("pas de cle de traduction d'import pfUI (en)", SUI.locales.en["mod.menu.imp.usage"], nil)
EQ("pas de cle bk.reason.import (en)", SUI.locales.en["mod.menu.bk.reason.import"], nil)
EQ("pas de cle msg.menu.imp.done (fr)", SUI.locales.fr["msg.menu.imp.done"], nil)
EQ("pas de cle wiz.sum.import (en)", SUI.locales.en["mod.menu.wiz.sum.import"], nil)

SECTION("t_backup : page Profils et sauvegardes")
cmd("")
M.Open("profiles")
SETTLE()
SETTLE()
EQ("page profils", M.page, "profiles")
local function btnByText(txt)
  for i = 1, M.used.btn do
    local b = M.pools.btn[i]
    if b:IsShown() and b.label and b.label:GetText() == txt then return b end
  end
end
local bn = btnByText("Sauvegarder maintenant")
T("bouton Sauvegarder maintenant", bn ~= nil)
n0 = table.getn(B.List())
bn:Click() SETTLE()
EQ("sauvegarde manuelle depuis le menu", table.getn(B.List()), n0 + 1)
EQ("sauvegarde manuelle : raison", B.List()[1].reason, "manual")
local ba = btnByText("[x] Sauvegardes automatiques")
T("interrupteur automatique", ba ~= nil)
ba:Click() SETTLE()
EQ("auto coupe depuis le menu", C.Get("backup.auto"), false)
btnByText("[ ] Sauvegardes automatiques"):Click() SETTLE()
EQ("auto reactive", C.Get("backup.auto"), true)
local keep0 = C.Get("backup.keep")
btnByText(string.format("Garder %d versions", keep0)):Click() SETTLE()
T("rotation du nombre de versions", C.Get("backup.keep") ~= keep0)
-- nouveau profil par la saisie
M.prof.name = "Menu-test"
btnByText("Nouveau (vide)"):Click() SETTLE()
T("profil cree depuis le menu", C.db.profiles["Menu-test"] ~= nil)
C.db.profiles["Menu-test"].v["units.height"] = 50
M.prof.sel = "Menu-test"
M.prof.name = "Menu-copie"
btnByText("Dupliquer"):Click() SETTLE()
T("profil duplique", C.db.profiles["Menu-copie"] ~= nil)
EQ("duplique : reglages copies", C.db.profiles["Menu-copie"] and C.db.profiles["Menu-copie"].v["units.height"], 50)
M.prof.sel = "Menu-copie"
M.prof.name = "Menu-nom"
btnByText("Renommer"):Click() SETTLE()
T("profil renomme", C.db.profiles["Menu-nom"] ~= nil and C.db.profiles["Menu-copie"] == nil)
M.prof.sel = "Menu-nom"
local del = btnByText("Supprimer")
del:Click() SETTLE()
T("suppression : confirmation d'abord", C.db.profiles["Menu-nom"] ~= nil)
EQ("libelle de confirmation", del.label:GetText(), "Confirmer ?")
Pump(1)
SETTLE()
del = btnByText("Confirmer ?")
del:Click() SETTLE()
EQ("suppression confirmee", C.db.profiles["Menu-nom"], nil)
C.DeleteProfile("Menu-test")
-- restaurer par la liste (deux clics)
M.Open("profiles")
SETTLE()
C.SetBase("units.width", 290)
local idr = B.Create("manual", "page")
C.SetBase("units.width", 150)
M.Open("profiles")
SETTLE()
local rb
for i = 1, M.used.note do
  local n = M.pools.note[i]
  if n.btn and n.btn:IsShown() and n.fs:GetText() and string.find(n.fs:GetText(), "page", 1, true) then rb = n.btn end
end
T("ligne de sauvegarde", rb ~= nil)
rb:Click() SETTLE()
EQ("1er clic : confirmation", rb.label:GetText(), "Confirmer ?")
EQ("rien restaure au 1er clic", C.Get("units.width"), 150)
Pump(1)
SETTLE()
rb:Click() SETTLE()
EQ("2e clic : restaure", C.Get("units.width"), 290)
-- avec pfUI present : la page ne propose plus d'import
pfUI = { module = { player = function() end } }
pfUI_config = { disabled = {} }
M.Open("profiles")
SETTLE()
EQ("avec pfUI : pas de bouton d'import", btnByText("Importer la selection"), nil)
EQ("avec pfUI : pas de bouton d'annulation d'import", btnByText("Annuler le dernier import"), nil)
pfUI = nil
pfUI_config = nil
M.Open("profiles")
SETTLE()

SECTION("t_backup : assistant face a pfUI")
pfUI = { module = { player = function() end, target = function() end, targettarget = function() end,
  actionbar = function() end, chat = function() end } }
pfUI_config = { disabled = {}, unitframes = { disable = "0", player = { width = "200", height = "40" }, target = { width = "200", height = "40" } },
  position = { pfPlayer = { xpos = "30", ypos = "-40", anchor = "TOPLEFT", parent = "UIParent" } },
  chat = { text = { time = "0" } } }
if M.wiz then M.wiz:Hide() end
M.ws = nil
M.ShowWizard(1)
local wz = M.wiz
local function hasStepP(id)
  local st = M.WizSteps()
  for i = 1, table.getn(st) do if st[i] == id then return true end end
  return false
end
local function gotoP(id)
  local st = M.WizSteps()
  for i = 1, table.getn(st) do if st[i] == id then M.WizGo(i) return end end
  error("etape absente : " .. id)
end
EQ("etape pfUI presente avec pfUI (Installation +)", hasStepP("migrate"), true)
M.WizSetPath("quick")
EQ("etape pfUI presente avec pfUI (Rapide)", hasStepP("migrate"), true)
M.WizSetPath("plus")
gotoP("migrate")
EQ("etape pfUI", wz.stepId, "migrate")
CONTAINS("la liste des modules pfUI est montree", wz.pg.migrate.lines[1]:GetText(), "")
EQ("plus de selection d'import dans l'etat de l'assistant", M.ws.sel.imp, nil)
EQ("plus de boutons d'import sur la page", wz.pg.migrate.imp, nil)
local wI = C.Get("units.width")
wz.pg.migrate.mig[2]:Click()
EQ("prise en main choisie", M.ws.sel.mig, "take")
EQ("rien n'est applique avant la fin", C.Get("units.width"), wI)
EQ("pfUI non touche avant la fin", pfUI_config.disabled.player, nil)
M.WizGo(table.getn(M.WizSteps()))
M.ws.sel.after = "menu"
wz.nextBtn:Click()
EQ("page finale", wz.stepId, "done")
EQ("pas de recopie de pfUI : largeur inchangee", C.Get("units.width"), wI)
EQ("pas de recopie de pfUI : chat inchange", C.Get("chat.stamp") ~= false, true)
EQ("prise en main : pfUI coupe pour units", pfUI_config.disabled.player, "1")
EQ("un instantane avant tout", B.List()[1].reason, "wizard")
EQ("annuler tout", wz.skip.label:GetText(), "Tout annuler")
wz.skip:Click()
EQ("annule : largeur restauree", C.Get("units.width"), wI)
EQ("annule : pfUI rendu", pfUI_config.disabled.player, "0")
M.Hide()
EQ("aucune erreur", SUI.errCount, 0)
DONE()
