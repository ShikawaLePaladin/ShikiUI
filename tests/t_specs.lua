-- t_specs : suite du module "specs" (detection de la spe, jeux par spe, application automatique, coexistence avec Simple Action Sets, barres).
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
SPECS_SETUP()
SPECS_TALENTS(31, 20, 0)
BOOT()
SETTLE()
local M = SUI.Specs
local mod = SUI.modules.specs

SECTION("t_specs : enregistrement et contrat")
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
EQ("actif au demarrage", mod and mod.enabled, true)
EQ("aucune erreur interne au demarrage", SUI.errCount, 0)
EQ("categorie du menu", SUI.categories.specs, 45)
for _, k in ipairs({ "specs.auto", "specs.announce", "specs.delay", "specs.minpoints", "specs.bars", "specs.bars.clear" }) do
  T("option declaree : " .. k, C.meta[k] ~= nil)
end
EQ("barres : coupees par defaut", C.Get("specs.bars"), false)
for _, k in ipairs({ "specs.auto", "specs.announce", "specs.delay", "specs.minpoints", "specs.bars", "specs.bars.clear" }) do
  EQ("reglage global (suit le joueur d'un profil a l'autre) : " .. k, C.meta[k].global, true)
end
T("evenement des talents ecoute", SUI.handlers["CHARACTER_POINTS_CHANGED"] ~= nil)

SECTION("t_specs : detection de la specialisation")
local s = M.Scan()
EQ("arbre dominant", s.id, 1)
EQ("signature", M.Signature(s), "31/20/0")
EQ("total", s.total, 51)
EQ("nom lu dans l'onglet", s.names[1], "Sacre")
SPECS_TALENTS(5, 31, 10)
EQ("autre arbre dominant", M.Scan().id, 2)
SPECS_TALENTS(25, 25, 1)
EQ("egalite : aucune dominante", M.Scan().id, 0)
SPECS_TALENTS(2, 1, 0)
EQ("sous le seuil de points : aucune dominante", M.Scan().id, 0)
C.Set("specs.minpoints", 0)
EQ("seuil 0 : la dominante revient", M.Scan().id, 1)
C.Set("specs.minpoints", 5)
SPECS_TALENTS(0, 0, 0)
EQ("aucun point : spe 0", M.Scan().id, 0)
EQ("nom de la spe 0", M.SpecName(0), L("mod.specs.hybrid"))
local realInfo = GetTalentTabInfo
setglobal("GetTalentTabInfo", function() error("boum") end)
EQ("API qui plante : nil sans erreur", M.Scan(), nil)
setglobal("GetTalentTabInfo", nil)
EQ("API absente : nil sans erreur", M.Scan(), nil)
setglobal("GetTalentTabInfo", realInfo)
SPECS_TALENTS(31, 20, 0)
EQ("retour a la normale", M.Scan().id, 1)

SECTION("t_specs : jeux (capture, liaison, champs)")
local okP = C.NewProfile("Soin")
T("profil de test cree", okP)
local ok, key = M.Capture("Tank")
EQ("capture d'un jeu", ok, true)
EQ("message de creation", key, "msg.specs.saved")
EQ("profil capture", M.GetPreset("Tank").profile, "Default")
ok, key = M.Capture("Tank")
EQ("2e capture : mise a jour", key, "msg.specs.updated")
EQ("nom invalide refuse", (M.Capture("a b")), false)
EQ("nom vide refuse", (M.Capture(nil)), false)
EQ("pas de barres sans option", M.GetPreset("Tank").bars, nil)
ok, key = M.SetField("Tank", "role", "tank")
EQ("champ role", M.GetPreset("Tank").role, "tank")
EQ("role invalide refuse", (M.SetField("Tank", "role", "magicien")), false)
EQ("champ inconnu refuse", (M.SetField("Tank", "couleur", "x")), false)
EQ("profil inconnu refuse", (M.SetField("Tank", "profile", "Nexiste")), false)
EQ("layout inconnu refuse", (M.SetField("Tank", "layout", "nexistepas")), false)
EQ("jeu inconnu refuse", (M.SetField("Fantome", "role", "tank")), false)
M.SetField("Tank", "role", "-")
EQ("'-' retire le champ", M.GetPreset("Tank").role, nil)
M.Capture("Soin")
M.SetField("Soin", "profile", "Soin")
M.SetField("Soin", "role", "heal")
M.SetField("Soin", "layout", "compact")
EQ("spe invalide", (M.Link(7, "Soin")), false)
EQ("jeu inconnu non liable", (M.Link(2, "Fantome")), false)
ok, key = M.Link(2, "Soin")
EQ("liaison", M.Assigned(2), "Soin")
M.Link(1, "Tank")
EQ("liaison 1", M.Assigned(1), "Tank")
local names = M.PresetNames()
EQ("jeux tries", table.concat(names, ","), "Soin,Tank")
T("resume lisible", string.find(M.Summary(M.GetPreset("Soin")), "heal", 1, true) ~= nil)
-- limite de jeux
for i = 1, 12 do M.Capture("Z" .. i) end
EQ("plafond de jeux", (M.Capture("Z99")), false)
for i = 1, 12 do M.Delete("Z" .. i) end
EQ("apres nettoyage", M.CountPresets(), 2)

SECTION("t_specs : application d'un jeu")
CHATCLEAR()
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs appliquer Soin")
EQ("application par commande", C.curName, "Soin")
CONTAINS("message d'application", CHATTEXT(), "Soin")
M.Apply("Tank", "manual")
CHATCLEAR()
ok, key = M.Apply("Soin", "manual")
EQ("application", ok, true)
EQ("profil actif change", C.curName, "Soin")
EQ("role applique", C.GetRole(), "heal")
EQ("mise en page appliquee", C.cur.layout, "compact")
EQ("l'API n'ecrit rien elle-meme", CHATTEXT(), "")
local nbk = table.getn(C.db.backups)
ok = M.Apply("Soin", "manual")
EQ("2e application : rien a changer", C.curName, "Soin")
EQ("aucun instantane de plus (rien d'ecrit)", table.getn(C.db.backups), nbk)
EQ("jeu inconnu", (M.Apply("Fantome")), false)
M.Apply("Tank", "manual")
EQ("retour au profil Default", C.curName, "Default")
-- instantane de securite avant d'ecraser role / mise en page
M.SetField("Tank", "role", "dps")
local b0 = table.getn(C.db.backups)
M.Apply("Tank", "manual")
EQ("role dps applique", C.GetRole(), "dps")
T("instantane de securite pris avant le role", table.getn(C.db.backups) > b0)
-- mode explicite
M.SetField("Tank", "mode", "raid")
M.Apply("Tank", "manual")
EQ("mode raid applique", C.mode, "raid")
M.SetField("Tank", "mode", "normal")
M.Apply("Tank", "manual")
EQ("mode normal applique", C.mode, "normal")
M.SetField("Tank", "mode", "-")
-- profil supprime apres coup : pas d'erreur
M.SetField("Tank", "role", "-")
M.GetPreset("Tank").profile = "Disparu"
local e0 = SUI.errCount
ok = M.Apply("Tank", "manual")
EQ("profil introuvable : pas d'erreur", SUI.errCount, e0)
EQ("profil introuvable : profil inchange", C.curName, "Default")
M.GetPreset("Tank").profile = "Default"

-- une etape qui plante : erreur notee, verrou rendu, l'application suivante marche
local realRole = C.ApplyRole
M.SetField("Tank", "role", "tank")
M.Apply("Soin", "manual")
C.ApplyRole = function() error("boum") end
local eb = SUI.errCount
local okb, keyb = M.Apply("Tank", "manual")
EQ("etape en erreur : echec propre", okb, false)
EQ("etape en erreur : message", keyb, "msg.specs.fail")
EQ("etape en erreur : erreur comptee", SUI.errCount, eb + 1)
EQ("etape en erreur : verrou rendu", M.applying, false)
SUI.errCount = eb
C.ApplyRole = realRole
okb = M.Apply("Tank", "manual")
EQ("apres l'erreur : application possible", okb, true)
EQ("apres l'erreur : role applique", C.GetRole(), "tank")
M.SetField("Tank", "role", "-")

SECTION("t_specs : changement de spe automatique")
M.Apply("Tank", "manual")
EQ("depart sur Default", C.curName, "Default")
SPECS_TALENTS(31, 20, 0)
Fire("CHARACTER_POINTS_CHANGED")
Pump(3.5)
EQ("spe memorisee", M.Store(false).last, 1)
-- bascule vers l'arbre 2 : le jeu "Soin" est lie
CHATCLEAR()
SPECS_TALENTS(5, 31, 10)
for i = 1, 5 do Fire("CHARACTER_POINTS_CHANGED") end
Fire("SPELLS_CHANGED")
local live = 0
for i = 1, table.getn(SUI.tasks) do
  if SUI.tasks[i].name == "specs.check" and not SUI.tasks[i].dead then live = live + 1 end
end
EQ("une seule minuterie pour une rafale d'evenements", live, 1)
Pump(1, 2)
EQ("pas encore applique pendant le delai", C.curName, "Default")
Pump(1, 3)
EQ("jeu lie applique", C.curName, "Soin")
EQ("spe memorisee 2", M.Store(false).last, 2)
CONTAINS("annonce du changement", CHATTEXT(), "5/31/10")
-- pastille a l'ecran (module Messages) : le nom de la nouvelle spe
-- (auto coupee : le jeu lie bascule le profil, ou le module Messages peut etre coupe)
C.Set("specs.auto", false)
C.Set("modules.messages", true)
C.Set("messages.toast", true)
SETTLE()
CHATCLEAR()
SPECS_TALENTS(31, 20, 0)
Fire("CHARACTER_POINTS_CHANGED")
Pump(3.5)
local toasts = SUI.Messages and SUI.Messages.toasts or {}
local found = false
for i = 1, table.getn(toasts) do
  if toasts[i].key == "specs" and string.find(toasts[i].text, "31", 1, true) then found = true end
end
T("pastille de changement de spe", found)
C.Set("messages.toast", false)
C.Set("modules.messages", false)
C.Set("specs.auto", true)
SETTLE()
-- retour a l'etat attendu par la suite : spe 2, jeu Soin applique
SPECS_TALENTS(5, 31, 10)
Fire("CHARACTER_POINTS_CHANGED")
Pump(3.5)
EQ("retour d'etat : profil Soin", C.curName, "Soin")
local ap = M.applied
Fire("CHARACTER_POINTS_CHANGED")
Pump(3.5)
EQ("meme spe : pas de nouvelle application", M.applied, ap)
-- retour a l'arbre 1 : jeu Tank (profil Default, role dps)
SPECS_TALENTS(31, 20, 0)
Fire("CHARACTER_POINTS_CHANGED")
Pump(3.5)
EQ("retour : profil Default", C.curName, "Default")
-- spe sans jeu lie : rien ne bouge
SPECS_TALENTS(5, 10, 31)
Fire("CHARACTER_POINTS_CHANGED")
Pump(3.5)
EQ("spe 3 sans jeu : profil inchange", C.curName, "Default")
EQ("mais la spe est memorisee", M.Store(false).last, 3)
-- reglage specs.auto coupe
SPECS_TALENTS(5, 31, 10)
C.Set("specs.auto", false)
Fire("CHARACTER_POINTS_CHANGED")
Pump(3.5)
EQ("auto coupe : pas d'application", C.curName, "Default")
EQ("auto coupe : spe quand meme memorisee", M.Store(false).last, 2)
C.Set("specs.auto", true)
-- delai reglable en direct
C.Set("specs.delay", 1)
SPECS_TALENTS(31, 20, 0)
Fire("SPELLS_CHANGED")
Pump(1.2)
EQ("delai de 1 s respecte", M.Store(false).last, 1)
C.Set("specs.delay", 3)
-- annonce coupee
C.Set("specs.announce", false)
CHATCLEAR()
SPECS_TALENTS(5, 31, 10)
Fire("CHARACTER_POINTS_CHANGED")
Pump(3.5)
EQ("jeu applique malgre l'annonce coupee", C.curName, "Soin")
EQ("annonce coupee : silence", CHATTEXT(), "")
C.Set("specs.announce", true)

SECTION("t_specs : combat")
M.Apply("Tank", "manual")
SPECS_TALENTS(31, 20, 0)
M.Check()
EQ("depart arbre 1", M.Store(false).last, 1)
W.combat = true
SPECS_TALENTS(5, 31, 10)
Fire("CHARACTER_POINTS_CHANGED")
Pump(4)
EQ("en combat : rien n'est applique", C.curName, "Default")
EQ("en combat : balayage differe", M.dirty, true)
local ok2, key2 = M.Apply("Soin", "manual")
EQ("application demandee en combat : mise en file", key2, "msg.specs.queued")
EQ("en combat : profil inchange", C.curName, "Default")
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
EQ("sortie de combat : jeu demande applique", C.curName, "Soin")
Pump(3.5)
EQ("sortie de combat : balayage rejoue", M.Store(false).last, 2)

SECTION("t_specs : Simple Action Sets (coexistence)")
EQ("SAS absent", M.HasSAS(), false)
local ok3, why3 = M.OpenSAS()
EQ("ouvrir SAS sans SAS", ok3, false)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs")
CONTAINS("etat : SAS absent signale", CHATTEXT(), "n'est pas charge")
SPECS_SAS({ "Brainwasher1", "Brainwasher2" })
EQ("SAS detecte", M.HasSAS(), true)
EQ("jeux de SAS lus", table.concat(M.SASSets(), ","), "Brainwasher1,Brainwasher2")
ok3 = M.OpenSAS()
EQ("ouvrir SAS", ok3, true)
EQ("SAS ouvert", SP.sasCalls[1], "toggle")
C.Set("specs.bars", true)
SPECS_BAR(1, { kind = "spell", name = "Holy Light", rank = "Rank 2" })
local snap, why = M.BarsSnapshot()
EQ("barres jamais lues avec SAS", snap, nil)
EQ("raison : SAS gere les barres", why, "msg.specs.sasbars")
EQ("restauration refusee avec SAS", (M.BarsRestore({ [1] = "s:Holy Light:2" })), false)
ok = M.Capture("AvecSAS")
EQ("capture avec SAS : sans barres", M.GetPreset("AvecSAS").bars, nil)
SP.placed = 0
M.SetField("AvecSAS", "sas", "Brainwasher2")
M.Apply("AvecSAS", "manual")
EQ("jeu SAS charge a la demande", SP.sasCalls[2], "swap Brainwasher2")
EQ("aucune action de barre posee", SP.placed, 0)
M.SetField("AvecSAS", "sas", "Inconnu")
local calls = table.getn(SP.sasCalls)
M.Apply("AvecSAS", "manual")
EQ("jeu SAS inconnu : pas d'appel", table.getn(SP.sasCalls), calls)
W.combat = true
EQ("SAS en combat refuse", (M.SwapSAS("Brainwasher1")), false)
W.combat = false
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs sas")
EQ("commande sas : ouvre SAS", SP.sasCalls[table.getn(SP.sasCalls)], "toggle")
SlashCmdList["SHIKIUI"]("specs sas Brainwasher1")
EQ("commande sas <jeu>", SP.sasCalls[table.getn(SP.sasCalls)], "swap Brainwasher1")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs")
CONTAINS("etat : SAS gere les barres", CHATTEXT(), "Simple Action Sets est charge")
M.Delete("AvecSAS")
SPECS_NOSAS()
EQ("SAS decharge", M.HasSAS(), false)

SECTION("t_specs : barres d'action (sans SAS)")
SPECS_SPELLS({ { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 2" }, { "Seal of Righteousness", "Rank 1" } })
SPECS_MACROS({ "Fort", "Soin" })
SPECS_BAGS({ ["0:3"] = "Pierre de foyer" })
SPECS_BAR(1, { kind = "spell", name = "Holy Light", rank = "Rank 2" })
SPECS_BAR(2, { kind = "macro", name = "Fort" })
SPECS_BAR(3, { kind = "item", name = "Pierre de foyer" })
SPECS_BAR(4, { kind = "spell", name = "Seal of Righteousness", rank = "Rank 1" })
C.Set("specs.bars", true)
local snap2, n2 = M.BarsSnapshot()
EQ("4 emplacements lus", n2, 4)
EQ("sort + rang", snap2[1], "s:Holy Light:2")
EQ("macro", snap2[2], "m:Fort")
EQ("objet", snap2[3], "i:Pierre de foyer")
EQ("sort rang 1", snap2[4], "s:Seal of Righteousness:1")
ok = M.Capture("Barres")
EQ("capture avec barres", ok, true)
EQ("barres dans le jeu", M.GetPreset("Barres").bars[2], "m:Fort")
T("resume mentionne les barres", string.find(M.Summary(M.GetPreset("Barres")), "4", 1, true) ~= nil)
-- on vide et on restaure
SP.bar = {}
SPECS_BAR(10, { kind = "spell", name = "Autre", rank = "Rank 1" })
SP.placed = 0
local r, placed, missing, same = M.BarsRestore(M.GetPreset("Barres").bars)
EQ("restauration ok", r, true)
EQ("4 poses", placed, 4)
EQ("0 manquant", missing, 0)
EQ("sort restaure", SP.bar[1].name .. SP.bar[1].rank, "Holy LightRank 2")
EQ("macro restauree", SP.bar[2].name, "Fort")
EQ("objet restaure", SP.bar[3].name, "Pierre de foyer")
EQ("curseur vide apres restauration", SP.cursor, nil)
EQ("case non listee intouchee (clear coupe)", SP.bar[10] ~= nil, true)
-- 2e passe : tout est identique, rien n'est repose
SP.placed = 0
r, placed, missing, same = M.BarsRestore(M.GetPreset("Barres").bars)
EQ("2e passe : 0 pose", placed, 0)
EQ("2e passe : 4 identiques", same, 4)
EQ("2e passe : aucune action", SP.placed, 0)
-- sort inconnu du livre (autre spe) : case laissee telle quelle
SP.bar[4] = { kind = "spell", name = "Autre", rank = "Rank 1" }
SPECS_SPELLS({ { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 2" } })
r, placed, missing = M.BarsRestore(M.GetPreset("Barres").bars)
EQ("sort introuvable compte comme manquant", missing, 1)
EQ("case laissee", SP.bar[4].name, "Autre")
-- rang absent : repli sur le plus haut rang connu
SPECS_SPELLS({ { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 3" }, { "Seal of Righteousness", "Rank 1" } })
SP.bar[1] = nil
r, placed = M.BarsRestore({ [1] = "s:Holy Light:2" })
EQ("rang absent : plus haut rang", SP.bar[1].rank, "Rank 3")
-- rang present parmi plusieurs : le bon rang, pas le plus haut ; case deja occupee : le curseur est rendu
SPECS_SPELLS({ { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 2" }, { "Holy Light", "Rank 3" } })
SP.bar[1] = { kind = "spell", name = "Autre", rank = "Rank 1" }
SP.bar[2] = { kind = "spell", name = "Autre", rank = "Rank 1" }
M.BarsRestore({ [1] = "s:Holy Light:2", [2] = "s:Holy Light:1" })
EQ("2e case occupee aussi remplacee", SP.bar[2].rank, "Rank 1")
EQ("rang demande respecte", SP.bar[1].rank, "Rank 2")
EQ("case occupee : curseur rendu", SP.cursor, nil)
SPECS_SPELLS({ { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 3" }, { "Seal of Righteousness", "Rank 1" } })
-- option : vider les cases vides du jeu
C.Set("specs.bars.clear", true)
SP.bar[10] = { kind = "spell", name = "Autre", rank = "Rank 1" }
M.BarsRestore(M.GetPreset("Barres").bars)
EQ("clear : case hors jeu videe", SP.bar[10], nil)
C.Set("specs.bars.clear", false)
-- en combat : jamais
W.combat = true
SP.placed = 0
r = M.BarsRestore(M.GetPreset("Barres").bars)
EQ("barres jamais touchees en combat", r, false)
EQ("combat : aucune action", SP.placed, 0)
EQ("combat : pas de lecture", (M.BarsSnapshot()), nil)
W.combat = false
-- via l'application d'un jeu, option coupee : pas de barres
C.Set("specs.bars", false)
SP.bar = {}
SP.placed = 0
M.Apply("Barres", "manual")
EQ("option barres coupee : rien de pose", SP.placed, 0)
C.Set("specs.bars", true)
M.Apply("Barres", "manual")
T("option barres allumee : barres posees", SP.placed >= 4)
-- API de barres absente
local realHas = HasAction
setglobal("HasAction", nil)
EQ("sans API de barres : refus propre", (M.BarsSnapshot()), nil)
setglobal("HasAction", realHas)
C.Set("specs.bars", false)

SECTION("t_specs : donnees stockees")
local function plain(t, depth)
  for k, v in pairs(t) do
    local tv = type(v)
    if tv == "function" or tv == "userdata" then return false end
    if tv == "table" then
      if depth > 6 or not plain(v, depth + 1) then return false end
    end
  end
  return true
end
T("rien que des donnees (pas de fonction ni de cadre)", plain(C.GetGlobal("specs"), 0))
T("rangees par personnage", C.GetGlobal("specs")[C.CharKey()] ~= nil)

SECTION("t_specs : commande")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs etat")
CONTAINS("etat : spe", CHATTEXT(), "Specialisation")
CONTAINS("etat : lignes par spe", CHATTEXT(), "Sacre")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs sauver Cmd1")
EQ("sauver par commande", M.GetPreset("Cmd1") ~= nil, true)
CONTAINS("retour de la sauvegarde", CHATTEXT(), "Cmd1")
SlashCmdList["SHIKIUI"]("specs lier 3 Cmd1")
EQ("lier par numero", M.Assigned(3), "Cmd1")
SlashCmdList["SHIKIUI"]("specs lier protection Cmd1")
EQ("lier par nom d'arbre", M.Assigned(2), "Cmd1")
SlashCmdList["SHIKIUI"]("specs lier auto Cmd1")
EQ("lier la spe actuelle", M.Assigned(M.Scan().id), "Cmd1")
SlashCmdList["SHIKIUI"]("specs lier 3 -")
EQ("delier", M.Assigned(3), nil)
SlashCmdList["SHIKIUI"]("specs regler Cmd1 role tank")
EQ("regler", M.GetPreset("Cmd1").role, "tank")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs liste")
CONTAINS("liste", CHATTEXT(), "Cmd1 :")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs appliquer Cmd1")
EQ("appliquer par commande", C.GetRole(), "tank")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs lier 9 Cmd1")
CONTAINS("spe invalide signalee", CHATTEXT(), "Spe invalide")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs appliquer Fantome")
CONTAINS("jeu inconnu signale", CHATTEXT(), "Jeu inconnu")
SlashCmdList["SHIKIUI"]("specs oublier Cmd1")
EQ("oublier", M.GetPreset("Cmd1"), nil)
EQ("oublier delie aussi", M.Assigned(2), nil)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs nimportequoi")
CONTAINS("aide complete", CHATTEXT(), "sauver <nom>")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("help")
CONTAINS("aide du module", CHATTEXT(), "/sui specs")
C.Set("ui.locale", "en")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs nimportequoi")
CONTAINS("aide en anglais", CHATTEXT(), "save <name>")
C.Set("ui.locale", "fr")

SECTION("t_specs : page du menu")
local Mn = SUI.Menu
C.SetGlobal("firstRun", false)
M.Link(1, "Tank")
M.Link(2, "Soin")
Mn.Show("all")
Mn.Open("cat", "specs")
EQ("categorie dans la navigation", Mn.CatExists("specs"), true)
local inGeneral = false
for _, fam in ipairs(Mn.FamilyList()) do
  if fam.id == "general" then for _, c in ipairs(fam.cats) do if c == "specs" then inGeneral = true end end end
end
T("famille General", inGeneral)
local function btnByText(txt)
  for i = 1, Mn.used.btn do
    local b = Mn.pools.btn[i]
    if b.label:GetText() == txt and b:IsShown() then return b end
  end
end
T("boutons de spe presents", btnByText(L("mod.specs.btn.save")) ~= nil)
T("options affichees sous la page (auto)", Mn.used.c_check > 0)
local nTank = table.getn(M.PresetNames())
Click(btnByText(L("mod.specs.btn.save")))
T("bouton Sauver : un jeu au nom de la spe", M.GetPreset("Sacre") ~= nil)
EQ("bouton Sauver : jeu lie a la spe 1", M.Assigned(1), "Sacre")
M.Link(1, "Tank")
Mn.Render()
Click(btnByText(L("mod.specs.btn.pick")))
T("bouton de liaison : jeu suivant", M.Assigned(1) ~= "Tank")
-- suppression avec confirmation (2 clics)
M.Delete("Sacre")
Mn.Render()
local nb = table.getn(M.PresetNames())
local del = btnByText(L("mod.specs.btn.delete"))
Click(del)
EQ("suppression : 1er clic, rien de supprime", table.getn(M.PresetNames()), nb)
Click(del)
EQ("suppression : 2e clic", table.getn(M.PresetNames()), nb - 1)
-- bouton du champ role : cycle
local nm = M.PresetNames()[1]
M.SetField(nm, "role", "-")
Mn.Render()
Click(btnByText(L("mod.specs.f.role") .. ": -"))
EQ("bouton role : premier role", M.GetPreset(nm).role, "tank")
Mn.SetMode("essential")
T("mode Essentiel : page toujours la", btnByText(L("mod.specs.btn.apply")) ~= nil)
Mn.SetMode("all")
-- module coupe : message
C.Set("modules.specs", false)
Mn.Render()
T("module coupe : plus de bouton de spe", btnByText(L("mod.specs.btn.save")) == nil)
C.Set("modules.specs", true)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_specs : bouton Jeux ShikiUI sur la fenetre des talents")
local function fireShow(f)
  this = f
  if f.scripts.OnShow then f.scripts.OnShow() end
end
GameTooltip = GameTooltip or CreateFrame("GameTooltip", "GameTooltip", UIParent)
local function tipText()
  local t = GameTooltip.lines or {}
  return table.concat(t, "\n")
end
W.combat = false
SPECS_TALENTS(31, 20, 0)
M.cur = M.Scan()
M.lastName = nil
EQ("options du bouton : defauts", C.Get("specs.btn") and C.Get("specs.btnpos") .. "/" .. C.Get("specs.btnstyle"), "bottom/full")
EQ("sans fenetre des talents : pas de bouton", M.btn, nil)
local tf = CreateFrame("Frame", "TalentFrame", UIParent)
tf:SetFrameLevel(5)
tf:Hide()
Fire("ADDON_LOADED", "Blizzard_TalentUI")
T("bouton cree au chargement de la fenetre (a la demande)", M.btn ~= nil)
EQ("enfant de TalentFrame", M.btn.parent, tf)
EQ("ancre au cadre Blizzard", M.btn.points[1][2], tf)
EQ("place par defaut : bas", M.btn.points[1][1], "BOTTOMRIGHT")
EQ("invisible tant que la fenetre est fermee", M.btn:IsVisible(), false)
tf:Show()
fireShow(M.btn)
EQ("visible avec la fenetre", M.btn:IsVisible(), true)
EQ("niveau recale a l'affichage", M.btn:GetFrameLevel(), 13)
tf:SetFrameLevel(30)
Hover(M.btn, true)
EQ("niveau recale au survol (le client le change apres coup)", M.btn:GetFrameLevel(), 38)
Pump(0.3, 1)
Hover(M.btn, false)
-- texte : spe + jeu en vigueur
EQ("spe sans jeu en vigueur", M.btn.label:GetText(), L("mod.specs.btn.full", "Sacre", L("mod.specs.btn.noset")))
EQ("pas d'accent sans jeu", M.btn.selected, false)
M.Link(1, "Tank")
M.Apply("Tank", "manual")
EQ("jeu applique : nom dans le bouton", M.btn.label:GetText(), L("mod.specs.btn.full", "Sacre", "Tank"))
EQ("jeu lie en vigueur : accent", M.btn.selected, true)
EQ("jeu en vigueur retenu dans les donnees", M.Store(false).applied, "Tank")
M.lastName = nil
EQ("apres /reload : lu dans les donnees", M.AppliedName(), "Tank")
M.Apply("Soin", "manual")
EQ("autre jeu que celui de la spe : pas d'accent", M.btn.selected, false)
M.Apply("Tank", "manual")
SPECS_TALENTS(5, 31, 10)
M.cur = M.Scan()
M.BtnRefresh()
EQ("autre spe detectee : nom change", M.btn.label:GetText(), L("mod.specs.btn.full", "Protection", "Tank"))
SPECS_TALENTS(31, 20, 0)
M.cur = M.Scan()
Hover(M.btn, true)
CONTAINS("infobulle : spe detectee", tipText(), "Sacre")
CONTAINS("infobulle : jeu en vigueur", tipText(), "Tank")
CONTAINS("infobulle : aide", tipText(), L("mod.specs.btn.tipbody"))
Hover(M.btn, false)
-- aspects et places
C.Set("specs.btnstyle", "label")
EQ("aspect texte", M.btn.label:GetText(), L("mod.specs.btn.label"))
EQ("aspect texte : largeur", M.btn:GetWidth(), M.BTNW.label)
C.Set("specs.btnstyle", "compact")
EQ("aspect compact", M.btn.label:GetText(), L("mod.specs.btn.compact"))
EQ("aspect compact : largeur", M.btn:GetWidth(), M.BTNW.compact)
C.Set("specs.btnstyle", "full")
C.Set("specs.btnpos", "top")
EQ("place haut", M.btn.points[1][1], "TOPRIGHT")
C.Set("specs.btnpos", "side")
EQ("place cote", M.btn.points[1][1], "TOPLEFT")
C.Set("specs.btnpos", "bottom")
EQ("place bas", M.btn.points[1][1], "BOTTOMRIGHT")
-- talents illisibles : texte neutre
local realNum = GetNumTalentTabs
M.cur = nil
rawset(_G, "GetNumTalentTabs", nil)
M.BtnApply()
EQ("API des talents absente : texte neutre", M.btn.label:GetText(), L("mod.specs.btn.label"))
rawset(_G, "GetNumTalentTabs", realNum)
M.cur = M.Scan()
M.BtnApply()

SECTION("t_specs : menu des jeux de la fenetre des talents")
EQ("menu pas encore construit", M.menu, nil)
Click(M.btn, "LeftButton")
T("menu construit au premier clic", M.menu ~= nil)
EQ("menu enfant de TalentFrame (se ferme avec elle)", M.menu.parent, tf)
EQ("menu affiche", M.menu:IsShown(), true)
EQ("menu au-dessus de la fenetre (niveau)", M.menu:GetFrameLevel(), 50)
EQ("niveau des enfants recale", M.menu.rows[1]:GetFrameLevel(), 52)
EQ("menu monte vers le haut (bouton en bas)", M.menu.points[1][1], "BOTTOMRIGHT")
local names = M.PresetNames()
EQ("une ligne par jeu", M.menu.rows[table.getn(names)]:IsShown(), true)
EQ("pas de ligne en trop", M.menu.rows[table.getn(names) + 1]:IsShown(), false)
EQ("ligne = nom du jeu", M.menu.rows[1].label:GetText(), names[1])
local tankRow
for i = 1, table.getn(names) do
  if names[i] == "Tank" then tankRow = M.menu.rows[i] end
end
EQ("jeu en vigueur marque", tankRow.selected, true)
EQ("etiquette des spes liees", tankRow.tag:GetText(), L("mod.specs.q.s", 1))
CONTAINS("etat : spe detectee", M.menu.s1:GetText(), "Sacre")
CONTAINS("etat : signature des talents", M.menu.s1:GetText(), "31/20/0")
CONTAINS("etat : jeu lie", M.menu.s2:GetText(), "Tank")
CONTAINS("etat : jeu en vigueur", M.menu.s3:GetText(), "Tank")
T("hauteur calculee", M.menu:GetHeight() > 100)
Hover(tankRow, true)
CONTAINS("infobulle d'un jeu : contenu", tipText(), "Tank")
CONTAINS("infobulle d'un jeu : gestes", tipText(), "Sacre")
Hover(tankRow, false)
-- appliquer un jeu depuis le menu
local soinRow
for i = 1, table.getn(names) do
  if names[i] == "Soin" then soinRow = M.menu.rows[i] end
end
Click(soinRow, "LeftButton")
EQ("clic sur un jeu : applique", C.curName, "Soin")
EQ("le menu se ferme apres l'application", M.menu:IsShown(), false)
EQ("le bouton suit", M.AppliedName(), "Soin")
-- lier / delier avec le clic droit
Click(M.btn, "LeftButton")
M.Link(1, nil)
Click(soinRow, "RightButton")
EQ("clic droit : lie la spe detectee", M.Assigned(1), "Soin")
Click(soinRow, "RightButton")
EQ("2e clic droit : delie", M.Assigned(1), nil)
EQ("le menu reste ouvert", M.menu:IsShown(), true)
-- enregistrer ici : jeu nouveau au nom de la spe, lie
CHATCLEAR()
Click(M.menu.save, "LeftButton")
EQ("nouveau jeu au nom de la spe", M.GetPreset("Sacre") ~= nil, true)
EQ("lie a la spe detectee", M.Assigned(1), "Sacre")
EQ("jeu enregistre = jeu en vigueur", M.AppliedName(), "Sacre")
CONTAINS("message de confirmation", CHATTEXT(), "Sacre")
CONTAINS("menu redessine", M.menu.s3:GetText(), "Sacre")
-- enregistrer ici sur une spe deja liee : met a jour ce jeu
C.NewProfile("Autre")
C.UseProfile("Autre")
local before = M.CountPresets()
Click(M.menu.save, "LeftButton")
EQ("jeu lie mis a jour", M.GetPreset("Sacre").profile, "Autre")
EQ("pas de doublon", M.CountPresets(), before)
C.UseProfile("Default")
-- nom propose : nettoye
EQ("nom propose pour l'hybride", M.AutoName(0), L("mod.specs.q.hybridname"))
SPECS_TALENTS(31, 20, 0, { "Maitrise des betes", "Protection", "Vindicte" })
M.cur = M.Scan()
EQ("nom propose : caracteres invalides remplaces", M.AutoName(1), "Maitrise_des_betes")
SPECS_TALENTS(31, 20, 0, { "Sacre", "Protection", "Vindicte" })
M.cur = M.Scan()
-- page Specs
local shown
local realShow = SUI.Menu.Show
SUI.Menu.Show = function(cat) shown = cat end
Click(M.menu.page, "LeftButton")
EQ("ouvre la page Specs", shown, "specs")
EQ("menu ferme", M.menu:IsShown(), false)
shown = nil
Click(M.btn, "RightButton")
EQ("clic droit sur le bouton : page Specs", shown, "specs")
SUI.Menu.Show = realShow
-- Builds
local items = SUI.Items
local qopen
if items then
  local realQ = items.QuickOpen
  local realOn = items.on
  items.on = true
  items.QuickOpen = function(anchor, up) qopen = anchor end
  Click(M.btn, "LeftButton")
  EQ("Builds present : bouton menu rapide", M.menu.bq:IsShown(), true)
  EQ("Builds present : bouton fenetre", M.menu.bw:IsShown(), true)
  Click(M.menu.bq, "LeftButton")
  EQ("menu rapide ancre au bouton", qopen, M.btn)
  items.on = false
  Click(M.btn, "LeftButton")
  EQ("Builds coupe : pas de lien", M.menu.bq:IsShown(), false)
  M.MenuClose()
  items.QuickOpen, items.on = realQ, realOn
end
-- bascule du menu par le bouton
Click(M.btn, "LeftButton")
EQ("clic : ouvre", M.menu:IsShown(), true)
Click(M.btn, "LeftButton")
EQ("re-clic : ferme", M.menu:IsShown(), false)
-- bouton coupe : menu ferme
Click(M.btn, "LeftButton")
C.Set("specs.btn", false)
EQ("bouton coupe : cache", M.btn:IsShown(), false)
EQ("bouton coupe : menu ferme", M.menu:IsShown(), false)
C.Set("specs.btn", true)
EQ("bouton reactive", M.btn:IsShown(), true)
EQ("aucune erreur interne (bouton)", SUI.errCount, 0)

SECTION("t_specs : bouton et menu en combat")
M.MenuClose()
W.combat = true
local nCreated = CREATED
local menuKeep = M.menu
M.menu = nil
Click(M.btn, "LeftButton")
EQ("en combat : menu non construit", M.menu, nil)
EQ("en combat : aucune creation", CREATED, nCreated)
M.menu = menuKeep
Click(M.btn, "LeftButton")
EQ("menu deja construit : s'ouvre en combat", M.menu:IsShown(), true)
M.MenuClose()
W.combat = false

SECTION("t_specs : bouton - cycle de vie")
C.Set("modules.specs", false)
EQ("module coupe : bouton cache", M.btn:IsShown(), false)
EQ("module coupe : menu ferme", M.menu:IsShown(), false)
EQ("module coupe : ADDON_LOADED rendu", (function()
  local h = SUI.handlers["ADDON_LOADED"] or {}
  for i = 1, table.getn(h) do
    if h[i] == M.OnAddon then return true end
  end
  return false
end)(), false)
C.Set("modules.specs", true)
EQ("module rallume : bouton revient", M.btn:IsShown(), true)
-- bouton cree seulement hors combat
M.btn, M.menu = nil, nil
W.combat = true
nCreated = CREATED
M.BtnApply()
EQ("en combat : bouton non cree", CREATED, nCreated)
EQ("en combat : bouton absent", M.btn, nil)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
Pump(0.3, 1)
T("hors combat : bouton cree", M.btn ~= nil)
EQ("aucune erreur interne (cycle de vie)", SUI.errCount, 0)

SECTION("t_specs : desactivation")
C.Set("modules.specs", false)
EQ("module coupe", mod.enabled, false)
EQ("evenement rendu", SUI.handlers["CHARACTER_POINTS_CHANGED"], nil)
local liveT = 0
for i = 1, table.getn(SUI.tasks) do
  if SUI.tasks[i].name == "specs.check" and not SUI.tasks[i].dead then liveT = liveT + 1 end
end
EQ("minuterie rendue", liveT, 0)
local last = M.Store(false).last
SPECS_TALENTS(5, 10, 31)
Fire("CHARACTER_POINTS_CHANGED")
Pump(4)
EQ("coupe : la spe n'est plus suivie", M.Store(false).last, last)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("specs sauver X")
CONTAINS("commande coupee : message", CHATTEXT(), L("mod.specs.disabled"))
C.Set("modules.specs", true)
EQ("module rallume", mod.enabled, true)
Pump(4)
EQ("rallume : la spe est relue", M.Store(false).last, 3)
EQ("aucune erreur interne a la fin", SUI.errCount, 0)

SECTION("t_specs : curseur propre apres un changement de spe (plus de clic bloque)")
C.Set("specs.bars", true)
SPECS_SPELLS({ { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 2" }, { "Holy Light", "Rank 3" } })
local realCursor = rawget(_G, "CursorHasItem")
rawset(_G, "CursorHasItem", function() return SP.cursor and 1 or nil end)
SP.bar = {}
SP.cursor = { kind = "item", name = "Objet du joueur" }
SP.placed = 0
local rb, why = M.BarsRestore({ [1] = "s:Holy Light:2" })
EQ("curseur occupe : barres refusees", rb, false)
EQ("curseur occupe : message", why, "msg.specs.cursorbusy")
EQ("curseur occupe : ce que le joueur tient est intact", SP.cursor.name, "Objet du joueur")
EQ("curseur occupe : aucune pose", SP.placed, 0)
SP.cursor = nil
-- erreur du client pendant la pose : l'etape n'echoue pas et le curseur est rendu
local realPlace = rawget(_G, "PlaceAction")
rawset(_G, "PlaceAction", function(slot) error("boom") end)
rb, placed, missing = M.BarsRestore({ [1] = "s:Holy Light:2" })
EQ("erreur de pose : restauration terminee", rb, true)
EQ("erreur de pose : compte en echec", placed, 0)
EQ("erreur de pose : curseur vide", SP.cursor, nil)
EQ("erreur de pose : plus de sort tenu", M.holding, false)
rawset(_G, "PlaceAction", realPlace)
-- filet de securite : un sort reste au curseur par notre faute est vide, jamais celui du joueur
SP.cursor = { kind = "spell", name = "Holy Light", rank = "Rank 2" }
M.holding = true
M.ReleaseCursor()
EQ("sort tenu par nous : vide", SP.cursor, nil)
SP.cursor = { kind = "item", name = "Objet du joueur" }
M.holding = false
M.ReleaseCursor()
EQ("objet tenu par le joueur : intact", SP.cursor.name, "Objet du joueur")
SP.cursor = nil
-- application d'un jeu avec barres alors que le joueur tient quelque chose : message, rien de pose, pas d'erreur
M.Capture("Curs")
SP.cursor = { kind = "item", name = "Objet du joueur" }
local okA, keyA, nmA, txtA = M.Apply("Curs", "manual")
EQ("jeu applique malgre tout", okA, true)
CONTAINS("barres non touchees signalees", txtA or "", L("msg.specs.cursorbusy"))
EQ("l'objet du joueur reste en main", SP.cursor.name, "Objet du joueur")
SP.cursor = nil
rawset(_G, "CursorHasItem", realCursor)
C.Set("specs.bars", false)
EQ("aucune erreur interne (curseur)", SUI.errCount, 0)

DONE()
