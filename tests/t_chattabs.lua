-- t_chattabs : module "chattabs" (gestionnaire d'onglets de chat : creer / renommer / fermer / reordonner, types et canaux, modeles,
-- sauvegarde par personnage, restauration, menu contextuel, page du menu).
local SUI = ShikiUI
local C = SUI.Config
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
CTW_SETUP()
BOOT()
SETTLE()
Pump(10)
SUI.errCount = 0        -- ecarte l erreur eventuelle de l assistant de premiere installation (autre fichier, autre agent)
local M = SUI.ChatTabs
local CH = SUI.Chat
local L = SUI.L
local Mn = SUI.Menu
local mod = SUI.modules.chattabs

local function ids()
  local t = {}
  for _, w in ipairs(M.Ordered()) do table.insert(t, w.id) end
  return table.concat(t, ",")
end
local function popBtn(label)
  for i = 1, 24 do
    local b = M.pop.btns[i]
    if b:IsShown() and b.label:GetText() == label then return b end
  end
end

SECTION("t_chattabs : enregistrement et contrat")
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
EQ("actif", mod and mod.enabled, true)
EQ("aucune erreur interne", SUI.errCount, 0)
EQ("fenetres visibles", ids(), "1,2,3")
T("journal de combat reconnu", M.IsCombatLog(2))
T("menu contextuel branche sur le module chat", CH.tabMenu == M.TabMenu)
T("popup construit", M.pop ~= nil)

SECTION("t_chattabs : types de messages")
local f1 = ChatFrame1
T("dire present", M.TypeOn(f1, M.TYPE.say))
T("officiers absents", not M.TypeOn(f1, M.TYPE.officer))
T("combat absent", not M.TypeOn(f1, M.TYPE.combat))
CTW_LOGCLEAR()
EQ("DoType ok", M.DoType(1, "officer", true), true)
T("officiers presents", M.TypeOn(f1, M.TYPE.officer))
T("groupe inconnu du client ignore", not string.find(CTW_LOG(), "GUILD_OFFICER", 1, true))
M.DoType(1, "officer", false)
T("officiers retires", not M.TypeOn(f1, M.TYPE.officer))
M.DoType(1, "combat", true)
T("combat actif", M.TypeOn(f1, M.TYPE.combat))
T("experience non ajoutee par le combat", not CTW_HASGROUP(1, "COMBAT_XP_GAIN"))
M.DoType(1, "combat", false)
T("combat coupe", not M.TypeOn(f1, M.TYPE.combat))
local ok, key = M.DoType(2, "say", true)
EQ("journal de combat intouchable", ok, false)
EQ("message", key, "msg.chattabs.combatlog")

SECTION("t_chattabs : canaux")
EQ("classe general", M.ChanClass("General - Elwynn"), "general")
EQ("classe general (fr)", M.ChanClass("G\195\169n\195\169ral - Elwynn"), "general")
EQ("classe commerce", M.ChanClass("Commerce - Ville"), "trade")
EQ("classe recherche de groupe", M.ChanClass("LookingForGroup"), "lfg")
EQ("classe world", M.ChanClass("World"), "world")
EQ("classe perso", M.ChanClass("MonCanal"), "custom")
EQ("canaux rejoints", table.concat(M.JoinedChannels(), "|"), "General - Elwynn|Trade - City|World")
T("general reconnu par prefixe", M.ChannelOn(f1, "General - Elwynn"))
T("commerce absent", not M.ChannelOn(f1, "Trade - City"))
M.DoChannel(1, "Trade - City", true)
T("commerce ajoute", M.ChannelOn(f1, "Trade - City"))
M.DoChannel(1, "General - Elwynn", false)
T("general retire (entree courte)", not M.ChannelOn(f1, "General - Elwynn"))
EQ("liste", CTW_CHANS(1), "Trade - City")

SECTION("t_chattabs : modeles")
EQ("modele loot", M.DoPreset(3, "loot"), true)
T("butin", CTW_HASGROUP(3, "LOOT"))
T("argent", CTW_HASGROUP(3, "MONEY"))
T("pas de dire", not CTW_HASGROUP(3, "SAY"))
EQ("aucun canal", CTW_CHANS(3), "")
M.DoPreset(3, "trade")
EQ("modele commerce : tous les canaux", CTW_CHANS(3), "General - Elwynn,Trade - City,World")
M.DoPreset(3, "general")
EQ("modele general : general seulement", CTW_CHANS(3), "General - Elwynn")
T("modele general : dire", CTW_HASGROUP(3, "SAY"))
M.DoPreset(3, "all")
EQ("modele tout : tous les canaux", CTW_CHANS(3), "General - Elwynn,Trade - City,World")
T("modele tout : combat", CTW_HASGROUP(3, "COMBAT_SELF_HITS"))
M.DoPreset(3, "social")
T("modele social : chuchotements", CTW_HASGROUP(3, "WHISPER"))
T("modele social : pas de butin", not CTW_HASGROUP(3, "LOOT"))
ok, key = M.DoPreset(2, "loot")
EQ("modele refuse sur le journal de combat", ok, false)
ok, key = M.DoPreset(3, "inconnu")
EQ("modele inconnu", key, "msg.chattabs.nopreset")

SECTION("t_chattabs : creer, renommer, fermer")
local id = M.Create("Loot")
EQ("fenetre creee", id, 4)
EQ("visible", ids(), "1,2,3,4")
EQ("nom pose", CHATW.names[4], "Loot")
EQ("contenu vide au depart", CTW_GROUPS(4), "")
id = M.Create("Troc", "trade")
EQ("fenetre creee avec modele", id, 5)
EQ("modele applique", CTW_CHANS(5), "General - Elwynn,Trade - City,World")
T("barre : nom de l'onglet apres rafraichissement", true)
Pump(0.6)
EQ("barre : onglet 4", CH.tabs[4].label:GetText(), "Loot")
EQ("rename", M.Rename(4, "a;b:c|d"), true)
EQ("nom nettoye", CHATW.names[4], "a b c d")
ok, key = M.Rename(4, "  ;; ")
EQ("nom vide refuse", key, "msg.chattabs.badname")
EQ("nom coupe", M.CleanName("12345678901234567890"), "1234567890123456")
ok, key = M.Close(1)
EQ("fenetre principale non fermable", key, "msg.chattabs.main")
ok, key = M.Close(2)
EQ("journal de combat non fermable", key, "msg.chattabs.combatlog")
EQ("fermeture", M.Close(5), true)
EQ("visible apres fermeture", ids(), "1,2,3,4")
CTW.noOpen = true
id, key = M.Create("X")
EQ("pas de fenetre libre", key, "msg.chattabs.full")
CTW.noOpen = false
W.combat = true
id, key = M.Create("X")
EQ("creation refusee en combat", key, "msg.chattabs.combat")
ok, key = M.Close(4)
EQ("fermeture refusee en combat", key, "msg.chattabs.combat")
W.combat = false

SECTION("t_chattabs : ordre des onglets")
EQ("ordre naturel", ids(), "1,2,3,4")
EQ("monter", M.Move(4, -1), true)
EQ("ordre", ids(), "1,2,4,3")
EQ("pas au dela du premier", M.Move(1, -1), false)
Pump(0.6)
EQ("barre : onglet 4 en 3e position", CH.tabs[4].slot, 3)
EQ("barre : onglet 3 en 4e position", CH.tabs[3].slot, 4)
M.Move(4, 1)
EQ("descendre", ids(), "1,2,3,4")
M.Move(4, -1)

SECTION("t_chattabs : sauvegarde par personnage et restauration")
CHATW.names[4] = "Butin"
M.DoPreset(4, "loot")
EQ("sauvegarde automatique", M.HasSaved(), true)
local snap = M.Snapshot()
T("instantane sans journal de combat", not string.find(snap, ":Combat Log:", 1, true))
T("instantane : groupe", string.find(snap, "LOOT", 1, true) ~= nil)
EQ("cle propre au personnage", C.GetGlobal("chattabs.layout." .. C.CharKey()), snap)
C.Set("chattabs.autosave", false)
M.Close(4)
M.DoPreset(3, "combat")
CHATW.names[3] = "Zzz"
local afterClose = C.GetGlobal("chattabs.layout." .. C.CharKey())
T("fermer retire la fenetre de la sauvegarde meme sans sauvegarde automatique", not string.find(afterClose, "4:Butin", 1, true))
T("le reste de la sauvegarde est intact", string.find(afterClose, "3:Whispers", 1, true) ~= nil)
EQ("restauration", M.Restore(), true)
EQ("une fenetre fermee n'est PAS rouverte", ids(), "1,2,3")
EQ("nom restaure", CHATW.names[3], "Whispers")
-- une fenetre enregistree mais fermee a l'insu du module (ancienne sauvegarde) est rouverte
C.SetGlobal("chattabs.layout." .. C.CharKey(), snap)
EQ("restauration d'une sauvegarde ancienne", M.Restore(), true)
EQ("fenetre rouverte, journal de combat a son rang", ids(), "1,2,4,3")
EQ("nom restaure", CHATW.names[3], "Whispers")
T("types restaures", CTW_HASGROUP(4, "LOOT"))
T("types du modele combat effaces", not CTW_HASGROUP(3, "COMBAT_SELF_HITS"))
EQ("ordre restaure", table.concat(M.order, ","), "1,2,4,3")
EQ("chaine inconnue", M.Parse("n'importe quoi"), nil)
EQ("chaine sans fenetre valide", M.Parse("v1;9:Nom:SAY:"), nil)
EQ("groupe en minuscules ignore", table.getn(M.Parse("v1;1:Nom:say,SAY:")[1].groups), 1)
EQ("fenetre en double ignoree", table.getn(M.Parse("v1;1:A:SAY:;1:B:SAY:")), 1)
C.SetGlobal("chattabs.layout." .. C.CharKey(), nil)
local ok2, k2 = M.Restore()
EQ("rien a restaurer", k2, "msg.chattabs.nosaved")
C.Set("chattabs.autosave", true)

SECTION("t_chattabs : restauration a la connexion")
M.Save()
M.restored = false
CHATW.names[1] = "Autre"
Fire("PLAYER_ENTERING_WORLD")
Pump(5)
EQ("restauree apres le delai", CHATW.names[1], "General")
EQ("une seule fois", M.restored, true)
M.restored = false
C.Set("chattabs.restore", false)
CHATW.names[1] = "Autre"
Fire("PLAYER_ENTERING_WORLD")
Pump(5)
EQ("option coupee : rien restaure", CHATW.names[1], "Autre")
C.Set("chattabs.restore", true)
FCF_SetWindowName(ChatFrame1, "General")

SECTION("t_chattabs : reinitialisation")
EQ("reset", M.Reset(), true)
EQ("une seule fenetre en plus du journal", ids(), "1,2")
T("fenetre 1 : dire", CTW_HASGROUP(1, "SAY"))
T("fenetre 1 : pas de combat", not CTW_HASGROUP(1, "COMBAT_SELF_HITS"))
EQ("sauvegarde effacee", C.GetGlobal("chattabs.layout." .. C.CharKey()) ~= nil, true)
EQ("ordre efface", table.getn(M.order), 0)

SECTION("t_chattabs : menu contextuel")
Pump(0.6)
local t1 = CH.tabs[1]
Click(t1, "LeftButton")
EQ("clic gauche : pas de menu", M.pop:IsShown(), false)
Click(t1, "RightButton")
EQ("clic droit : menu", M.pop:IsShown(), true)
EQ("catcher", M.popCatcher:IsShown(), true)
T("entree renommer", popBtn(L("mod.chattabs.pop.rename")) ~= nil)
EQ("fenetre 1 non fermable : pas de bouton fermer", popBtn(L("mod.chattabs.pop.close")), nil)
Click(popBtn(L("mod.chattabs.pop.new")))
EQ("saisie du nom", M.pop.edit:IsShown(), true)
M.pop.edit:SetText("Raid")
Click(popBtn(L("mod.chattabs.pop.ok")))
EQ("onglet cree depuis le menu", ids(), "1,2,3")
EQ("nom", CHATW.names[3], "Raid")
EQ("menu ferme", M.pop:IsShown(), false)
Click(CH.tabs[3], "RightButton")
Click(popBtn(L("mod.chattabs.pop.types")))
T("page des types", popBtn("[  ] " .. L("mod.chattabs.type.loot")) ~= nil)
Click(popBtn("[  ] " .. L("mod.chattabs.type.loot")))
T("type coche depuis le menu", CTW_HASGROUP(3, "LOOT"))
T("coche affichee", popBtn("[x] " .. L("mod.chattabs.type.loot")) ~= nil)
Click(popBtn(L("mod.chattabs.pop.back")))
Click(popBtn(L("mod.chattabs.pop.presets")))
Click(popBtn(L("mod.chattabs.preset.group")))
T("modele depuis le menu", CTW_HASGROUP(3, "PARTY") and not CTW_HASGROUP(3, "LOOT"))
Click(popBtn(L("mod.chattabs.pop.back")))
local cb = popBtn(L("mod.chattabs.pop.close"))
T("bouton fermer", cb ~= nil)
Click(cb)
T("1er clic : confirmation", popBtn(L("mod.chattabs.pop.confirm")) ~= nil)
Click(popBtn(L("mod.chattabs.pop.confirm")))
EQ("fermee apres confirmation", ids(), "1,2")
C.Set("chattabs.menu", false)
T("option coupee : menu debranche", CH.tabMenu == nil)
Click(CH.tabs[1], "RightButton")
EQ("plus de menu", M.pop:IsShown(), false)
C.Set("chattabs.menu", true)
W.combat = true
Click(CH.tabs[1], "RightButton")
EQ("pas de menu en combat", M.pop:IsShown(), false)
W.combat = false

SECTION("t_chattabs : page du menu")
M.Create("Loot")
M.Create("Troc")
C.SetGlobal("firstRun", false)
Mn.Show("all")
Mn.Open("cat", "chattabs")
EQ("categorie dans la navigation", Mn.CatExists("chattabs"), true)
local inInterface = false
for _, fam in ipairs(Mn.FamilyList()) do
  if fam.id == "interface" then for _, c in ipairs(fam.cats) do if c == "chattabs" then inInterface = true end end end
end
T("famille Interface", inInterface)
EQ("cases : 8 onglets usuels + 19 types + 3 canaux", Mn.used.ct_chk, 30)
EQ("zone de saisie", Mn.used.ct_edit, 1)
T("boutons presents", Mn.used.btn > 20)
local function btnByText(txt)
  for i = 1, Mn.used.btn do
    if Mn.pools.btn[i].label:GetText() == txt then return Mn.pools.btn[i] end
  end
end
Click(btnByText(L("mod.chattabs.preset.loot")))
T("modele applique a la fenetre choisie", CTW_HASGROUP(M.sel, "LOOT"))
local cells = Mn.pools.ct_chk
local lootCell
for i = 1, Mn.used.ct_chk do
  if cells[i].txt:GetText() == L("mod.chattabs.type.loot") then lootCell = cells[i] end
end
EQ("case butin cochee", lootCell.chk.on, true)
Click(lootCell)
T("case decochee : groupe retire", not CTW_HASGROUP(M.sel, "LOOT"))
Mn.SetMode("essential")
EQ("mode Essentiel : types et canaux restent configurables", Mn.used.ct_chk, 30)
Mn.SetMode("all")
Click(btnByText(L("mod.chattabs.save")))
EQ("sauvegarde par le menu", M.HasSaved(), true)
-- selection et fermeture avec confirmation
local before = ids()
local closeBtn
for i = 1, Mn.used.btn do
  if Mn.pools.btn[i].label:GetText() == L("mod.chattabs.close") then closeBtn = Mn.pools.btn[i] end
end
Click(closeBtn)
EQ("1er clic : rien de ferme", ids(), before)
Click(closeBtn)
T("2e clic : une fenetre fermee", ids() ~= before)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_chattabs : creation puis deplacement (barre et dock)")
M.Reset()
M.restored = true
local a = M.Create("Aaa")
local b = M.Create("Bbb")
T("fenetres distinctes", a and b and a ~= b)
EQ("nouvelle fenetre ancree au dock", getglobal("ChatFrame" .. a).isDocked ~= nil, true)
EQ("dock : ordre d'arrivee", CTW_DOCK(), "1,2," .. a .. "," .. b)
CTW_FADE(a)
CTW_FADE(1)
Pump(0.6)
EQ("onglet Blizzard reaffiche : recache", getglobal("ChatFrame" .. a .. "Tab"):GetAlpha(), 0)
EQ("onglet Blizzard principal recache", ChatFrame1Tab:GetAlpha(), 0)
EQ("souris des onglets Blizzard coupee", getglobal("ChatFrame" .. a .. "Tab"):IsMouseEnabled(), nil)
local function xs()
  local out = {}
  for i = 1, 7 do
    local tb = CH.tabs[i]
    if tb:IsShown() then table.insert(out, i .. "@" .. tb.slot .. "/" .. tb.points[1][4]) end
  end
  return table.concat(out, " ")
end
local seen, distinct = {}, true
for i = 1, 7 do
  local tb = CH.tabs[i]
  if tb:IsShown() then
    if seen[tb.points[1][4]] then distinct = false end
    seen[tb.points[1][4]] = true
  end
end
EQ("aucun onglet de la barre au meme emplacement : " .. xs(), distinct, true)
EQ("le nouvel onglet est a droite des autres", CH.tabs[b].slot, 4)
EQ("gauche", M.Move(b, -1), true)
Pump(0.6)
EQ("barre : b avant a", CH.tabs[b].slot < CH.tabs[a].slot, true)
EQ("dock Blizzard suit l'ordre", CTW_DOCK(), "1,2," .. b .. "," .. a)
EQ("droite", M.Move(b, 1), true)
Pump(0.6)
EQ("barre : retour", CH.tabs[b].slot > CH.tabs[a].slot, true)
EQ("dock : retour", CTW_DOCK(), "1,2," .. a .. "," .. b)
M.Move(b, -1)
M.Save()
M.order = {}
M.PushOrder()
local fa = getglobal("ChatFrame" .. a)
CTW_DOCK()
for i = table.getn(DOCKED_CHAT_FRAMES), 1, -1 do if DOCKED_CHAT_FRAMES[i] == fa then table.remove(DOCKED_CHAT_FRAMES, i) end end
fa.isDocked = nil          -- fenetre flottante voulue par l'utilisateur
EQ("restauration de l'ordre", M.Restore(), true)
EQ("restauration : une fenetre deja ouverte n'est pas redockee", fa.isDocked, nil)
Pump(0.6)
EQ("ordre restaure dans le dock (sans la fenetre flottante)", CTW_DOCK(), "1,2," .. b)
EQ("ordre restaure dans la barre", CH.tabs[b].slot < CH.tabs[a].slot, true)
-- fenetre qui ne peut pas etre ancree : decalee de la principale
CTW_SETUP(true)
M.placed = 0
local c = M.Create("Ccc")
EQ("non ancree : placement distinct", M.placed, 1)
T("decalee de la fenetre principale", getglobal("ChatFrame" .. c).points[1][4] ~= 0)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_chattabs : guilde, de bout en bout")
CTW_SETUP()
M.Reset()
M.restored = true
local g1 = M.Create("Gld", "social")
local gf = getglobal("ChatFrame" .. g1)
EQ("modele social : GUILD actif", CTW_HASGROUP(g1, "GUILD"), true)
EQ("modele social : OFFICER actif", CTW_HASGROUP(g1, "OFFICER"), true)
EQ("case guilde cochee", M.TypeOn(gf, M.TYPE.guild), true)
M.DoPreset(g1, "loot")
EQ("modele loot : GUILD retire", CTW_HASGROUP(g1, "GUILD"), false)
EQ("case manuelle guilde", M.DoType(g1, "guild", true), true)
EQ("case manuelle : GUILD ajoute", CTW_HASGROUP(g1, "GUILD"), true)
CTW_LOGCLEAR()
M.DoType(g1, "guild", false)
CONTAINS("retrait par ChatFrame_RemoveMessageGroup", CTW_LOG(), "rm:" .. g1 .. ":GUILD")
M.DoType(g1, "guild", true)
M.Save()
M.ApplyPreset("loot", g1)
EQ("restauration rejoue GUILD", M.Restore(), true)
EQ("restauration : GUILD present", CTW_HASGROUP(g1, "GUILD"), true)
-- le client ne connait pas le groupe : on tente tout de meme le nom brut
local tg = getglobal("ChatTypeGroup")
M.SetType(gf, M.TYPE.guild, false)
local saved = tg.GUILD
tg.GUILD = nil
CTW_LOGCLEAR()
M.SetType(gf, M.TYPE.guild, true)
CONTAINS("nom brut tente malgre ChatTypeGroup", CTW_LOG(), "add:" .. g1 .. ":GUILD")
tg.GUILD = saved
-- diagnostic
CHATCLEAR()
SlashCmdList["SHIKIUI"]("chattabs dump")
CONTAINS("dump : fenetre", CHATTEXT(), "Gld")
CONTAINS("dump : groupes reels", CHATTEXT(), "GUILD")
CONTAINS("dump : guilde active", CHATTEXT(), "guilde : actif")
CONTAINS("dump : etat du client", CHATTEXT(), "ChatTypeGroup")
M.DoType(g1, "guild", false)
M.DoType(g1, "say", true)
local out = M.Dump()
local gi
for i = 1, table.getn(out) do if string.find(out[i], "Gld", 1, true) then gi = i end end
CONTAINS("dump : guilde inactive (ligne de la fenetre)", out[gi + 3], "guilde : inactif /")
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_chattabs : fenetres libres, detacher, rattacher, ranger")
CTW_SETUP()
M.Reset()
M.restored = true
for i = 1, 7 do getglobal("ChatFrame" .. i).SetResizable = function(self, v) self.resz = v end end
local w1 = M.Create("Libre")
local f1 = getglobal("ChatFrame" .. w1)
EQ("creee : deverrouillee (FCF_SetLocked)", f1.locked, false)
EQ("creee : deplacable", f1.movable, true)
EQ("creee : redimensionnable", f1.resz, true)
M.Refloat()
EQ("attachee : pas de poignee du Mover", SUI.Mover.items["chat.win" .. w1], nil)
T("menu : entree detacher", (function() Click(CH.tabs[w1], "RightButton"); return popBtn(L("mod.chattabs.pop.detach")) ~= nil end)())
Click(popBtn(L("mod.chattabs.pop.detach")))
EQ("detachee", f1.isDocked, nil)
CONTAINS("FCF_UnDockFrame appele", CTW_LOG(), "undock:" .. w1)
T("poignee du Mover creee", SUI.Mover.items["chat.win" .. w1] ~= nil)
EQ("poignee nommee d'apres l'onglet", SUI.Mover.Label("chat.win" .. w1), "Libre")
T("enregistree dans le Layout (position par personnage)", SUI.Layout.items["chat.win" .. w1] ~= nil)
M.Rename(w1, "Autre")
EQ("renommage : poignee renommee", SUI.Mover.Label("chat.win" .. w1), "Autre")
SUI.Mover.Commit(SUI.Mover.items["chat.win" .. w1], 300, 400)
local pl, pb = C.GetPos("chat.win" .. w1)
EQ("position enregistree", pl, 300)
EQ("position enregistree (bas)", pb, 400)
EQ("fenetre placee", math.floor(f1.points[1][4] * f1:GetScale() + 0.5), 300)
EQ("fenetre libre : garde son echelle d'origine malgre ui.scale", f1:GetScale(), 1)
C.Set("ui.scale", 1.2)
EQ("ui.scale change : la fenetre libre ne change pas de taille", f1:GetScale(), 1)
do
  local Mv = SUI.Mover
  local l, b, r, t, wd, hh = Mv.Rect(Mv.items["chat.win" .. w1])
  NEAR("poignee de la fenetre libre : largeur reelle", wd, f1:GetWidth() * f1:GetScale())
  NEAR("poignee de la fenetre libre : hauteur reelle", hh, f1:GetHeight() * f1:GetScale())
end
C.Set("ui.scale", 1)
Click(CH.tabs[w1], "RightButton")
T("menu : entree rattacher", popBtn(L("mod.chattabs.pop.attach")) ~= nil)
Click(popBtn(L("mod.chattabs.pop.attach")))
T("rattachee", f1.isDocked ~= nil)
EQ("poignee retiree", SUI.Mover.items["chat.win" .. w1], nil)
EQ("Layout retire", SUI.Layout.items["chat.win" .. w1], nil)
local d1 = M.Detach(1)
EQ("fenetre principale non detachable", d1, false)
-- par commande
CHATCLEAR()
SlashCmdList["SHIKIUI"]("chattabs detach " .. w1)
CONTAINS("commande detach", CHATTEXT(), "detachee")
EQ("detachee par commande", f1.isDocked, nil)
EQ("position retrouvee apres rattachement", math.floor(f1.points[1][4] * f1:GetScale() + 0.5), 300)
-- ranger
local w2 = M.Create("Deux")
M.Detach(w2)
local f2 = getglobal("ChatFrame" .. w2)
f1:ClearAllPoints()
f1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 5000, 5000)
f1.locked = true
f2.locked = true
CHATCLEAR()
SlashCmdList["SHIKIUI"]("chattabs tidy")
CONTAINS("commande tidy", CHATTEXT(), "rangee")
EQ("rangee : f1 deverrouillee", f1.locked, false)
EQ("rangee : f2 deverrouillee", f2.locked, false)
T("rangee : f1 ramenee a l'ecran", f1.points[1][4] ~= 5000)
local okT, nT = M.Tidy()
EQ("ranger : nombre", nT, 2)
-- restauration : les fenetres libres retrouvent leur poignee
M.Save()
M.Unfloat(w1)
EQ("poignee retiree a la main", SUI.Mover.items["chat.win" .. w1], nil)
M.Restore()
T("restauration : poignee de nouveau la", SUI.Mover.items["chat.win" .. w1] ~= nil)
-- fermeture : poignee retiree
M.Close(w1)
EQ("fermee : poignee retiree", SUI.Mover.items["chat.win" .. w1], nil)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_chattabs : commande")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("chattabs new Test loot")
CONTAINS("creation", CHATTEXT(), "cree")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("chattabs list")
CONTAINS("liste", CHATTEXT(), "Test")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("chattabs rename 1 Principal")
EQ("renommage", CHATW.names[1], "Principal")
SlashCmdList["SHIKIUI"]("chattabs preset 1 group")
T("modele par commande", CTW_HASGROUP(1, "PARTY"))
CHATCLEAR()
SlashCmdList["SHIKIUI"]("chattabs bidule")
CONTAINS("usage", CHATTEXT(), "Usage")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("help")
CONTAINS("aide", CHATTEXT(), "/sui chattabs")

SECTION("t_chattabs : desactivation")
C.Set("modules.chattabs", false)
EQ("coupe", mod.enabled, false)
EQ("menu debranche", CH.tabMenu, nil)
EQ("ordre rendu au module chat", CH.orderList, nil)
Mn.Open("cat", "chattabs")
EQ("page : message module coupe", Mn.used.ct_chk, 0)
C.Set("modules.chattabs", true)
EQ("rallume", mod.enabled, true)
T("menu rebranche", CH.tabMenu == M.TabMenu)
EQ("aucune erreur interne", SUI.errCount, 0)
SECTION("t_chattabs : setup (Guilde / Monde / Donjon)")
do
  local n0 = table.getn(M.Shown())
  local ok, made = M.Setup()
  T("setup reussit", ok == true)
  T("setup cree des onglets", made and made >= 1)
  EQ("fenetres ajoutees", table.getn(M.Shown()), n0 + made)
  local ok2, made2 = M.Setup()
  EQ("deuxieme setup ne duplique rien", made2, 0)
  T("presets guild/world/dungeon", M.PRESET.guild and M.PRESET.world and M.PRESET.dungeon)
end


SECTION("t_chattabs : onglets usuels, selection, auto-ancrage")
do
  M.Reset()
  Mn.Show("all")
  Mn.Open("cat", "chattabs")
  T("gros bouton de creation dans la page", btnByText(L("mod.chattabs.setup.go")) ~= nil)
  local made0 = table.getn(M.Shown())
  Click(btnByText(L("mod.chattabs.setup.go")))
  T("le bouton cree les onglets coches", table.getn(M.Shown()) > made0)
  M.Reset()
  -- tous les onglets usuels sont proposes, coches par defaut : Guilde / Monde / Donjon
  EQ("8 onglets usuels", table.getn(M.USUAL), 8)
  EQ("selection par defaut", table.concat(M.PickedList(), ","), "guild,world,dungeon")
  M.picks.trade = true
  M.picks.world = nil
  EQ("selection modifiee", table.concat(M.PickedList(), ","), "guild,dungeon,trade")
  T("general existe toujours", M.HasTab("general"))
  local ok, made, kept, failed = M.Setup(M.PickedList())
  T("setup avec liste", ok == true)
  EQ("aucun echec", failed, 0)
  T("Commerce cree", M.HasTab("trade"))
  local ok2, made2, kept2 = M.Setup(M.PickedList())
  EQ("relance : rien de cree", made2, 0)
  EQ("relance : tout deja present", kept2, 3)
  -- commande avec arguments et alias
  CHATCLEAR()
  M.Command("setup butin chuchotements")
  T("Butin cree", M.HasTab("loot"))
  T("Chuchotements cree", M.HasTab("whisper"))
  CONTAINS("rapport de setup", CHATTEXT(), "cree(s)")
  -- plus de fenetre libre : echec signale, pas d'erreur
  local before = SUI.errCount
  M.Setup({ "combat", "world", "guild" })
  EQ("pas d'erreur interne", SUI.errCount, before)
  -- cases des onglets usuels dans la page
  for _, w in ipairs(M.Shown()) do if w.name == M.UsualName("trade") then M.Close(w.id) end end
  M.picks.trade = nil
  Mn.Render()
  local tradeCell
  for i = 1, Mn.used.ct_chk do
    if string.find(Mn.pools.ct_chk[i].txt:GetText(), M.UsualName("trade"), 1, true) then tradeCell = Mn.pools.ct_chk[i] end
  end
  T("case Commerce dans la page", tradeCell ~= nil)
  Click(tradeCell)
  EQ("cocher une case memorise le choix", M.picks.trade, true)
  M.picks.trade = nil
  -- cascade : decalage de 28 par fenetre, ancre sur l'ecran
  local cf = ChatFrame4
  M.Cascade(cf, 1)
  local _, r1, _, x1, y1 = cf:GetPoint(1)
  M.Cascade(cf, 3)
  local _, r3, _, x3, y3 = cf:GetPoint(1)
  EQ("cascade ancree a l'ecran", r3, UIParent)
  EQ("cascade : decalage horizontal", x3 - x1, 56)
  EQ("cascade : decalage vertical", y1 - y3, 56)
  -- jamais d'auto-ancrage ni de cycle
  local wins = M.Shown()
  for i = 1, table.getn(wins) do
    local f = getglobal("ChatFrame" .. wins[i].id)
    for p = 1, f:GetNumPoints() do
      local _, rel = f:GetPoint(p)
      T("fenetre " .. wins[i].id .. " non ancree a elle-meme", rel ~= f)
      T("fenetre " .. wins[i].id .. " : pas de cycle", not rel or not M.AnchorCycle(f, rel) or rel == UIParent)
    end
  end
  local a, b = ChatFrame3, ChatFrame4
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0)
  T("cycle detecte (b ancree a a)", M.AnchorCycle(a, b))
  T("auto-ancrage detecte", M.AnchorCycle(a, a))
  T("pas de faux cycle", not M.AnchorCycle(b, UIParent))
  -- dock : doublons retires
  table.insert(DOCKED_CHAT_FRAMES, ChatFrame1)
  M.ApplyDockOrder()
  local seen, dup = {}, false
  for _, f in ipairs(DOCKED_CHAT_FRAMES) do
    if seen[f] then dup = true end
    seen[f] = true
  end
  T("dock sans doublon", not dup)
  EQ("fenetre 1 en tete du dock", DOCKED_CHAT_FRAMES[1], ChatFrame1)
end

SECTION("t_chattabs : creation automatique (option) et astuce")
do
  local key = "chattabs.setupdone." .. C.CharKey()
  C.SetGlobal(key, nil)
  C.SetGlobal("chattabs.hint." .. C.CharKey(), nil)
  EQ("option desactivee par defaut", C.Get("chattabs.autosetup"), false)
  T("option declaree", SUI.modules.chattabs.options[1] ~= nil)
  -- plusieurs onglets deja la : l'option ne cree rien (pas de surprise) mais se marque faite
  C.Set("chattabs.autosetup", true)
  local n0 = table.getn(M.Shown())
  M.AutoSetup()
  EQ("rien cree quand il y a deja des onglets", table.getn(M.Shown()), n0)
  T("marque faite", C.GetGlobal(key) ~= nil)
  EQ("une seule fois", M.AutoSetup(), false)
  -- astuce unique
  C.Set("chattabs.autosetup", false)
  EQ("pas d'astuce quand il y a des onglets", M.Hint(), false)
end

SECTION("t_chattabs : fermeture fiable (suppression d'un onglet)")
do
  local key = "chattabs.layout." .. C.CharKey()
  local function saved() return C.GetGlobal(key) or "" end
  local function has(sub) return string.find(saved(), sub, 1, true) ~= nil end
  M.Reset()
  M.restored = true
  C.Set("chattabs.autosave", true)
  C.Set("chattabs.restore", true)
  -- 1) fermeture par le module, sauvegarde automatique allumee
  local g = M.Create("Guilde", "guild")
  T("fenetre creee", g ~= nil)
  T("enregistree", has(":Guilde:"))
  CHATCLEAR()
  EQ("fermeture", M.Close(g), true)
  EQ("fenetre disparue", M.IsShown(g), nil)
  T("retiree de la sauvegarde", not has(":Guilde:"))
  CONTAINS("message de confirmation", CHATTEXT(), "Guilde")
  EQ("retiree de l'ordre", table.concat(M.order, ","), "1,2")
  EQ("retiree de la barre", ids(), "1,2")
  -- la restauration ne la recree pas
  M.Restore()
  EQ("restauration : pas recreee", ids(), "1,2")
  -- 2) sauvegarde automatique coupee : la fermeture retire quand meme la fenetre de l'arrangement
  C.Set("chattabs.autosave", false)
  g = M.Create("Monde", "world")
  M.Save()
  T("enregistree (a la main)", has(":Monde:"))
  EQ("fermeture", M.Close(g), true)
  T("retiree meme sans sauvegarde automatique", not has(":Monde:"))
  T("fenetre 1 toujours enregistree", has("1:General:"))
  C.Set("chattabs.autosave", true)
  -- 3) fermeture par le menu du jeu (FCF_Close directement)
  T("FCF_Close enveloppee", FCF_Close == M.closeWrap)
  g = M.Create("Donjon", "dungeon")
  T("enregistree", has(":Donjon:"))
  local before = M.closedByClient or 0
  FCF_Close(getglobal("ChatFrame" .. g))
  EQ("fenetre fermee par le jeu", M.IsShown(g), nil)
  T("retiree de la sauvegarde", not has(":Donjon:"))
  EQ("retiree de l'ordre", table.concat(M.order, ","), "1,2")
  EQ("comptee", M.closedByClient, before + 1)
  M.Restore()
  EQ("restauration : pas recreee", ids(), "1,2")
  -- 4) pendant la connexion (avant la restauration) : rien n'est efface
  g = M.Create("Butin", "loot")
  M.restored = false
  FCF_Close(getglobal("ChatFrame" .. g))
  T("connexion en cours : sauvegarde intacte", has(":Butin:"))
  M.restored = true
  M.ForgetSaved(g)
  T("oubli cible", not has(":Butin:"))
  -- 5) en combat et module coupe : le jeu ferme, nous n'intervenons pas
  g = M.Create("Troc", "trade")
  W.combat = true
  FCF_Close(getglobal("ChatFrame" .. g))
  W.combat = false
  EQ("combat : fermee par le jeu", M.IsShown(g), nil)
  T("combat : sauvegarde non touchee", has(":Troc:"))
  M.ForgetSaved(g)
  local g2 = M.Create("Troc2", "trade")
  C.Set("modules.chattabs", false)
  SETTLE()
  FCF_Close(getglobal("ChatFrame" .. g2))
  EQ("module coupe : fermee par le jeu", M.IsShown(g2), nil)
  T("module coupe : sauvegarde non touchee", has(":Troc2:"))
  C.Set("modules.chattabs", true)
  SETTLE()
  M.restored = true
  M.ForgetSaved(g2)
  T("rallume : toujours enveloppee", FCF_Close == M.closeWrap)

  -- 6) le client garde la fenetre apres FCF_Close : masquage de secours
  g = M.Create("Rebelle", "guild")
  local realClose = FCF_Close
  rawset(_G, "FCF_Close", function() end)
  rawset(_G, "SetChatWindowShown", function(id, v) CHATW.shown[id] = (v == 1) end)
  CHATCLEAR()
  EQ("fermeture de secours", M.Close(g), true)
  EQ("fenetre disparue", M.IsShown(g), nil)
  T("retiree de la sauvegarde", not has(":Rebelle:"))
  rawset(_G, "SetChatWindowShown", nil)
  -- 7) impossible : message clair, la fenetre reste geree
  g = M.Create("Tetue", "guild")
  local ok, k = M.Close(g)
  EQ("echec annonce", ok, false)
  EQ("cle d'echec", k, "msg.chattabs.closefail")
  T("fenetre toujours listee", M.IsShown(g) ~= nil)
  T("toujours enregistree", has(":Tetue:"))
  EQ("drapeau de fermeture rendu", M.inClose, false)
  rawset(_G, "FCF_Close", realClose)
  EQ("fermeture normale ensuite", M.Close(g), true)

  -- 8) selection : fermer l'onglet affiche ramene a la principale, fermer un autre ne change rien
  local a = M.Create("A1")
  local b = M.Create("B1")
  FCF_SelectDockFrame(getglobal("ChatFrame" .. a))
  SUI.Chat.selected = getglobal("ChatFrame" .. a)
  M.Close(b)
  EQ("autre onglet : selection intacte", SELECTED_CHAT_FRAME, getglobal("ChatFrame" .. a))
  M.Close(a)
  EQ("onglet affiche ferme : retour a la principale", SELECTED_CHAT_FRAME, ChatFrame1)

  -- 9) la restauration reprend une fenetre du meme nom (pas de doublon)
  M.Reset()
  M.restored = true
  local x = M.Create("Guilde", "guild")
  M.Save()
  local snapG = saved()
  M.Close(x)
  local filler = M.Create("Filler")
  local y = M.Create("guilde", "guild")
  T("la fenetre du meme nom n'a plus le meme numero", y ~= x)
  C.SetGlobal(key, snapG)
  local n0 = table.getn(M.Shown())
  M.Restore()
  EQ("aucune fenetre en plus", table.getn(M.Shown()), n0)
  T("la fenetre existante est reprise", M.IsShown(y) ~= nil)
  EQ("nom restaure", CHATW.names[y], "Guilde")
  EQ("l'autre fenetre n'est pas renommee", CHATW.names[filler], "Filler")

  -- 10) doublons
  local d1 = M.Create("Dup")
  local d2 = M.Create("dup")
  local okd, nd = M.Dedupe()
  EQ("doublons : une fermee", nd, 1)
  T("la plus petite reste", M.IsShown(d1) ~= nil and M.IsShown(d2) == nil)
  okd, nd = M.Dedupe()
  EQ("plus de doublon", nd, 0)

  -- 11) recherche par nom
  EQ("par numero", M.FindWindow("1"), 1)
  EQ("par nom (casse ignoree)", M.FindWindow("dup"), d1)
  EQ("par nom usuel", M.FindWindow("guilde"), y)
  EQ("combat : jamais", M.FindWindow("Combat Log"), nil)
  EQ("inconnu", M.FindWindow("zzz"), nil)
  EQ("vide", M.FindWindow(""), nil)
  local x2 = M.Create("Guilde", "guild")
  EQ("doublon : le plus recent d'abord", M.FindWindow("guilde"), x2)

  -- 12) commandes et diagnostic
  CHATCLEAR()
  SlashCmdList["SHIKIUI"]("chattabs close guilde")
  EQ("/sui chattabs close <nom>", M.IsShown(x2), nil)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"]("chattabs check")
  CONTAINS("check : personnage", CHATTEXT(), C.CharKey())
  C.SetGlobal(key, saved() .. ";6:Fantome:SAY:")
  local out, ghosts, dups = M.CheckState()
  EQ("check : un fantome", ghosts, 1)
  EQ("check : pas de doublon", dups, 0)
  T("check : message du fantome", string.find(table.concat(out, "\n"), "Fantome", 1, true) ~= nil)
  local d3 = M.Create("Dup")
  out, ghosts, dups = M.CheckState()
  EQ("check : un doublon", dups, 1)
  M.Close(d3)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"]("chattabs forget 6")
  CONTAINS("forget <n>", CHATTEXT(), "6")
  T("fantome oublie", not has(":Fantome:"))
  CHATCLEAR()
  SlashCmdList["SHIKIUI"]("chattabs forget 6")
  CONTAINS("forget d'une fenetre absente", CHATTEXT(), "6")
  SlashCmdList["SHIKIUI"]("chattabs forget all")
  EQ("forget all", C.GetGlobal(key), nil)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"]("chattabs dedupe")
  T("/sui chattabs dedupe", CHATTEXT() ~= "")
  -- personnage inconnu du client : jamais de sauvegarde sous une cle fausse
  local realName = UnitName
  rawset(_G, "UnitName", function() return "Unknown" end)
  EQ("personnage inconnu : pas de sauvegarde", M.Save(), false)
  EQ("personnage inconnu : rien a charger", M.Load(), nil)
  EQ("personnage inconnu : rien a retirer", M.Unsave(1), false)
  rawset(_G, "UnitName", realName)
  -- menu : nouveaux boutons
  C.SetGlobal("firstRun", false)
  Mn.Show("all")
  Mn.Open("cat", "chattabs")
  local function btnText(txt)
    for i = 1, Mn.used.btn do
      if Mn.pools.btn[i].label:GetText() == txt then return Mn.pools.btn[i] end
    end
  end
  T("bouton Verifier", btnText(L("mod.chattabs.check")) ~= nil)
  T("bouton Doublons", btnText(L("mod.chattabs.dedupe")) ~= nil)
  T("bouton Oublier", btnText(L("mod.chattabs.forget")) ~= nil)
  CHATCLEAR()
  Click(btnText(L("mod.chattabs.check")))
  CONTAINS("bouton Verifier : rapport", CHATTEXT(), C.CharKey())
  EQ("page du menu sans erreur", SUI.errCount, 0)
  Mn.Hide()
  M.Reset()
end

DONE()
