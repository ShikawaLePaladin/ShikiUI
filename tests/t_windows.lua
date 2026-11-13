-- t_windows : suite du module "windows" (fenetres de Blizzard deplacables : touche + glisser, position retenue, reapplication,
-- reinitialisation, option par fenetre, combat). Les fenetres Blizzard sont simulees par mock_windows.lua.
local SUI = ShikiUI
local C = SUI.Config
WININSTALL()
local shown = 0
WINFRAME("CharacterFrame", { onshow = function() shown = shown + 1 end })
WINFRAME("SpellBookFrame")
WINFRAME("FriendsFrame", { scale = 0.8 })
BOOT()
SETTLE()
local mod = SUI.modules.windows
local W_ = SUI.Windows
local char = CharacterFrame
local book = SpellBookFrame

local function pt(f) return f.points[1] end
local function moved(f) local p = pt(f); return p and p[1] == "BOTTOMLEFT" end

SECTION("t_windows : enregistrement et options")
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
EQ("actif au demarrage", mod and mod.enabled, true)
EQ("aucune erreur interne", SUI.errCount, 0)
EQ("touche par defaut", C.Get("windows.key"), "shift")
for i = 1, table.getn(W_.DEFS) do
  local d = W_.DEFS[i]
  T("option par fenetre : " .. d.id, C.Get(d.opt) == true)
  T("texte par fenetre : " .. d.id, SUI.L("opt." .. d.opt) ~= "opt." .. d.opt)
end
T("fenetres presentes accrochees", char.suiWinHooked and book.suiWinHooked and FriendsFrame.suiWinHooked)
T("fenetre absente ignoree", W_.Find("talents") ~= nil and getglobal("TalentFrame") == nil)

SECTION("t_windows : textes du menu pour la touche")
for _, k in ipairs({ "shift", "ctrl", "alt", "none" }) do
  local o = { key = "windows.key" }
  T("texte du choix : " .. k, SUI.Menu and SUI.Menu.ChoiceLabel and SUI.Menu.ChoiceLabel(o, k) ~= "choice.windows.key." .. k or SUI.L("choice.windows.key." .. k) ~= "choice.windows.key." .. k)
end

SECTION("t_windows : glisser avec la touche")
WINSHOW(char)
EQ("ancien OnShow conserve", shown, 1)
EQ("position Blizzard au depart", pt(char)[1], "TOPLEFT")
WINMODS(false, false, false)
WINDOWN(char)
T("sans touche : pas de deplacement", not char.moving)
WINMODS(true)
WINDOWN(char, "RightButton")
T("clic droit : pas de deplacement", not char.moving)
WINDOWN(char)
EQ("Maj + clic gauche : deplacement", char.moving, true)
EQ("cadre rendu deplacable", char.movable, true)
char.left, char.bottom = 321, 432
WINUP(char)
T("fin du deplacement", not char.moving)
local l, b = C.GetPos("windows.character")
EQ("position enregistree (gauche)", l, 321)
EQ("position enregistree (bas)", b, 432)
T("cadre ancre sur la position retenue", moved(char) and pt(char)[4] == 321 and pt(char)[5] == 432)

SECTION("t_windows : reapplication a l'affichage (UIPanelWindows)")
WINHIDE(char)
WINSHOW(char)
T("apres reouverture : notre position", moved(char) and pt(char)[4] == 321)
EQ("un seul point d'ancrage", table.getn(char.points), 1)
WINSHOW(book)
T("autre panneau ouvert : fenetre deplacee inchangee", moved(char) and pt(char)[4] == 321)
T("la fenetre non deplacee reste a Blizzard", pt(book)[1] == "TOPLEFT")
local u = W.win.updates
WINSHOW(book)
T("UpdateUIPanelPositions de Blizzard toujours appele", W.win.updates == u + 1)

SECTION("t_windows : touche choisie")
C.Set("windows.key", "ctrl")
WINMODS(true, false, false)
WINDOWN(book)
T("Maj refuse quand Ctrl est choisi", not book.moving)
WINMODS(false, true, false)
WINDRAG(book, 50, 60)
EQ("Ctrl accepte", C.GetPos("windows.spellbook"), 50)
C.Set("windows.key", "alt")
WINMODS(false, true, false)
WINDOWN(book)
T("Ctrl refuse quand Alt est choisi", not book.moving)
WINMODS(false, false, true)
WINDRAG(book, 70, 80)
EQ("Alt accepte", C.GetPos("windows.spellbook"), 70)
C.Set("windows.key", "none")
WINMODS(false, false, false)
WINDRAG(book, 90, 100)
EQ("sans touche : glisser direct", C.GetPos("windows.spellbook"), 90)
C.Set("windows.key", "shift")
WINMODS(true)

SECTION("t_windows : echelle propre a la fenetre")
local fr = FriendsFrame
WINDRAG(fr, 400, 500)
local fl, fb = C.GetPos("windows.social")
NEAR("position en unites de UIParent (gauche)", fl, 320, 1)
NEAR("position en unites de UIParent (bas)", fb, 400, 1)
NEAR("decalage dans l'echelle du cadre", pt(fr)[4], 400, 1)

SECTION("t_windows : case deplacable par fenetre, effet immediat")
WINSHOW(char)
C.Set("windows.w_character", false)
EQ("fenetre rendue a Blizzard tout de suite", pt(char)[1], "TOPLEFT")
WINDOWN(char)
T("plus de glisser", not char.moving)
WINHIDE(char)
WINSHOW(char)
EQ("reouverture : position du jeu", pt(char)[1], "TOPLEFT")
T("position gardee en memoire", C.GetPos("windows.character") == 321)
C.Set("windows.w_character", true)
T("recochee : position reappliquee sans /reload", moved(char) and pt(char)[4] == 321)

SECTION("t_windows : fenetre a chargement a la demande")
EQ("TalentFrame absent", getglobal("TalentFrame"), nil)
local tf = WINFRAME("TalentFrame")
Fire("ADDON_LOADED", "Blizzard_TalentUI")
T("accrochee apres ADDON_LOADED", tf.suiWinHooked == true)
WINDRAG(tf, 11, 22)
EQ("deplacable", C.GetPos("windows.talents"), 11)

SECTION("t_windows : reinitialisation")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("windows")
CONTAINS("liste : fenetre", CHATTEXT(), "character")
CONTAINS("liste : grimoire", CHATTEXT(), "SpellBookFrame")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("windows reset personnage")
CONTAINS("nom inconnu", CHATTEXT(), "personnage")
EQ("rien n'a bouge", C.GetPos("windows.character"), 321)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("windows reset character")
EQ("position effacee", C.GetPos("windows.character"), nil)
EQ("fenetre rendue a Blizzard", pt(char)[1], "TOPLEFT")
T("les autres gardent leur position", C.GetPos("windows.spellbook") == 90)
C.Set("windows.resetall", true)
EQ("case de reinitialisation decochee seule", C.Get("windows.resetall"), false)
EQ("tout est efface (grimoire)", C.GetPos("windows.spellbook"), nil)
EQ("tout est efface (talents)", C.GetPos("windows.talents"), nil)
EQ("tout est efface (amis)", C.GetPos("windows.social"), nil)
WINDRAG(char, 5, 6)
SlashCmdList["SHIKIUI"]("windows reset")
EQ("reset sans nom : tout", C.GetPos("windows.character"), nil)
WINDRAG(char, 7, 8)
SUI.Config.ResetPositions()
EQ("reinitialisation globale des positions", pt(char)[1], "TOPLEFT")

SECTION("t_windows : combat et cadres proteges")
WINDRAG(char, 120, 130)
WINHIDE(char)
W_.Find("character").protected = true
W.combat = true
WINSHOW(char)
EQ("en combat : cadre protege non touche", pt(char)[1], "TOPLEFT")
WINDOWN(char)
T("en combat : pas de glisser sur un cadre protege", not char.moving)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
T("sortie de combat : position appliquee", moved(char) and pt(char)[4] == 120)
W_.Find("character").protected = nil
W.combat = true
WINDOWN(book)
EQ("combat : cadre non protege (1.12) deplacable", book.moving, true)
WINUP(book)
W.combat = false

SECTION("t_windows : Bags gere la banque")
local bank = WINFRAME("BankFrame")
Fire("ADDON_LOADED", "Blizzard_Test")
WINDRAG(bank, 33, 44)
SUI.Bags = SUI.Bags or {}
local hadHidden = SUI.Bags.bankHidden
SUI.Bags.bankHidden = true
WINHIDE(bank)
WINSHOW(bank)
EQ("banque remplacee par Bags : laissee tranquille", pt(bank)[1], "TOPLEFT")
WINDOWN(bank)
T("banque remplacee par Bags : pas de glisser", not bank.moving)
SUI.Bags.bankHidden = hadHidden

SECTION("t_windows : monde")
Fire("PLAYER_ENTERING_WORLD")
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_windows : module coupe puis rallume")
WINSHOW(char)
WINDRAG(char, 200, 210)
T("deplacee", moved(char))
local hooked = getglobal("UpdateUIPanelPositions")
C.Set("modules.windows", false)
EQ("module coupe", mod.enabled, false)
EQ("fenetre rendue a Blizzard", pt(char)[1], "TOPLEFT")
WINDOWN(char)
T("plus de glisser", not char.moving)
T("fonction Blizzard restituee", getglobal("UpdateUIPanelPositions") ~= hooked)
local u2 = W.win.updates
WINSHOW(book)
EQ("Blizzard fonctionne", W.win.updates, u2 + 1)
EQ("position gardee", C.GetPos("windows.character"), 200)
C.Set("modules.windows", true)
EQ("module rallume", mod.enabled, true)
T("position reappliquee a la reactivation", moved(char) and pt(char)[4] == 200)
WINDRAG(char, 250, 260)
EQ("glisser a nouveau possible", C.GetPos("windows.character"), 250)
EQ("aucune erreur interne a la fin", SUI.errCount, 0)
DONE()
