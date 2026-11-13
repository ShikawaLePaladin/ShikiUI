-- t_mover : service de deplacement (Mover.lua) : inscription et noms, entree / sortie, ui.locked, combat, glisser + aimantation + guides,
-- fleches, molette, clic droit, panneau de position precise, alignements, symetrie, "Montrer tout", annulation, positions par mode, commandes.
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Mover
local Mn = SUI.Menu
local Ly = SUI.Layout
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
BOOT()
SETTLE()
W.layout = true

local function cmd(s)
  CHATCLEAR()
  SlashCmdList["SHIKIUI"](s)
  return CHATTEXT()
end
local function mk(w, h)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetWidth(w)
  f:SetHeight(h)
  return f
end
local function leftOf(id) return M.items[id].frame:GetLeft() * M.items[id].frame:GetScale() end
local function botOf(id) return M.items[id].frame:GetBottom() * M.items[id].frame:GetScale() end
local function posOf(id) local l, b, s = C.GetPos(id); return l, b, s end

-- cadres de test, loin des cadres des modules
local fa, fb, fc = mk(100, 50), mk(120, 40), mk(80, 80)
local previewed = {}
M.Register("zz.a", fa, { label = "Cadre A", point = "BOTTOMLEFT", x = 700, y = 600 })
M.Register("zz.b", fb, { label = "Cadre B", point = "BOTTOMLEFT", x = 1000, y = 600 })
M.Register("zz.c", fc, { label = "Cadre C", point = "BOTTOMLEFT", x = 700, y = 800, scale = false,
  preview = function(on) previewed[table.getn(previewed) + 1] = on end })
local hid = mk(60, 20)
hid:Hide()
M.Register("zz.hidden", hid, { point = "BOTTOMLEFT", x = 300, y = 300 })
M.Register("zz.nolabel", mk(30, 30), { point = "BOTTOMLEFT", x = 300, y = 500 })

SECTION("t_mover : inscription et noms")
EQ("rejet : id vide", M.Register("", fa), false)
EQ("rejet : id trop long", M.Register(string.rep("x", 40), fa), false)
EQ("rejet : pas un cadre", M.Register("zz.x", "pas un cadre"), false)
EQ("libelle donne", M.Label("zz.a"), "Cadre A")
EQ("libelle de repli lisible", M.Label("zz.nolabel"), "Zz.nolabel")
local nitems = 0
for i = 1, table.getn(M.order) do
  local id = M.order[i]
  nitems = nitems + 1
  local lb = M.Label(id)
  T("libelle non vide : " .. id, type(lb) == "string" and lb ~= "")
end
T("des cadres de modules sont enregistres", nitems >= 8)
T("unit.player enregistre", M.items["unit.player"] ~= nil)
T("unit.target enregistre", M.items["unit.target"] ~= nil)
local named = 0
for _, id in ipairs({ "unit.player", "unit.target", "unit.targettarget", "group", "raid" }) do
  if M.items[id] then
    named = named + 1
    T("nom du module pour " .. id, M.Label(id) ~= id and M.Label(id) ~= "")
  end
end
T("noms de modules verifies", named >= 3)

SECTION("t_mover : entree, sortie, ui.locked")
EQ("inactif au depart", M.active, false)
EQ("cadres verrouilles au depart", C.Get("ui.locked"), true)
local pos0 = ShikiUIDB.profiles
M.Show = nil
CHATCLEAR()
EQ("Enter", M.Enter(), true)
EQ("actif", M.active, true)
EQ("ui.locked suit", C.Get("ui.locked"), false)
T("voile", M.veil:IsShown())
T("bandeau", M.banner:IsShown())
CONTAINS("message d'entree", CHATTEXT(), "Mode deplacement")
for _, id in ipairs({ "zz.a", "zz.b", "zz.c", "zz.nolabel", "unit.player", "unit.target" }) do
  local rec = M.items[id]
  T("poignee de " .. id, rec.handle ~= nil and rec.handle:IsShown())
  if rec.handle then
    T("poignee nommee : " .. id, string.find(rec.handle.label:GetText(), M.Label(id), 1, true) ~= nil)
  end
end
T("cadre cache : pas de poignee", M.items["zz.hidden"].handle == nil or not M.items["zz.hidden"].handle:IsShown())
-- aucune poignee anonyme : toute poignee visible a un nom
for i = 1, table.getn(M.order) do
  local h = M.items[M.order[i]].handle
  if h and h:IsShown() then T("etiquette non vide : " .. M.order[i], h.label:GetText() ~= "") end
end
EQ("le bouton du bandeau 'Verrouiller et quitter'", M.banner.exit.label:GetText(), "Verrouiller et quitter")
M.banner.exit:Click()
EQ("quitte", M.active, false)
EQ("ui.locked rebascule", C.Get("ui.locked"), true)
T("voile ferme", not M.veil:IsShown())
for i = 1, table.getn(M.order) do
  local h = M.items[M.order[i]].handle
  if h then T("poignee cachee : " .. M.order[i], not h:IsShown()) end
end
-- ui.locked seul
C.Set("ui.locked", false)
EQ("ui.locked=false ouvre le mode", M.active, true)
C.Set("ui.locked", true)
EQ("ui.locked=true ferme le mode", M.active, false)
-- /sui lock, /sui unlock, /sui move
CONTAINS("unlock", cmd("unlock"), "Mode deplacement")
EQ("unlock ouvre", M.active, true)
CONTAINS("lock", cmd("lock"), "Interface verrouillee")
EQ("lock ferme", M.active, false)
cmd("move")
EQ("/sui move ouvre", M.active, true)
cmd("move")
EQ("/sui move ferme", M.active, false)
cmd("deplacer")
EQ("/sui deplacer (alias)", M.active, true)
M.Exit(true)
CONTAINS("aide /sui move", cmd("help"), "/sui move")
CONTAINS("aide /sui deplacer", cmd("help"), "/sui deplacer")
-- Echap
M.Enter()
this = M.veil
arg1 = "ESCAPE"
M.veil.scripts.OnKeyDown()
EQ("Echap quitte", M.active, false)
-- la fermeture du bandeau (UISpecialFrames) quitte aussi
M.Enter()
M.banner:Hide()
EQ("masquer le bandeau quitte", M.active, false)

SECTION("t_mover : combat")
W.combat = true
CHATCLEAR()
EQ("Enter refuse en combat", M.Enter(), false)
EQ("pas actif", M.active, false)
CONTAINS("avertit", CHATTEXT(), "combat")
EQ("ui.locked reste vrai", C.Get("ui.locked"), true)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
EQ("ouvert apres le combat", M.active, true)
W.combat = true
CHATCLEAR()
Fire("PLAYER_REGEN_DISABLED")
EQ("sortie automatique au debut du combat", M.active, false)
W.combat = false
M.Enter()
local created = CREATED
W.combat = true
M.Sync()
EQ("rien de cree en combat", CREATED, created)
-- un cadre ajoute pendant le combat : pas de poignee creee, elle apparait apres
local fd = mk(60, 30)
M.Register("zz.late", fd, { label = "Tardif", point = "BOTTOMLEFT", x = 500, y = 500 })
local c2 = CREATED
W.combat = true
M.Sync()
EQ("combat : pas de poignee creee", M.items["zz.late"].handle, nil)
EQ("combat : aucune creation", CREATED, c2)
W.combat = false
M.Sync()
T("apres le combat : poignee nommee", M.items["zz.late"].handle ~= nil and M.items["zz.late"].handle.label:GetText() == "Tardif")
M.Exit(true)

SECTION("t_mover : glisser, aimantation, guides")
M.Enter()
local ha = M.items["zz.a"].handle
local function drag(h, x0, y0, x1, y1)
  MOUSE.x, MOUSE.y, MOUSE.down = x0, y0, true
  this = h
  arg1 = "LeftButton"
  h.scripts.OnMouseDown()
  MOUSE.x, MOUSE.y = x1, y1
  Pump(0.02, 2)
  MOUSE.down = false
  Pump(0.02, 1)
end
-- cadre A en (700,600) ; B a 1000 : bords gauche 1000, centre 1060, droit 1120
drag(ha, 750, 625, 750 + 200, 625 + 100)
EQ("glisser : gauche", leftOf("zz.a"), 900)
EQ("glisser : bas", botOf("zz.a"), 700)
local l, b = posOf("zz.a")
EQ("position enregistree : gauche", l, 900)
EQ("position enregistree : bas", b, 700)
EQ("mode deplacement toujours actif", M.active, true)
-- aimantation sur le bord gauche de B (1000) : le bord gauche de A arrive a 996
drag(ha, 950, 725, 950 + 96, 725)
EQ("aimant sur le bord gauche d'un autre cadre", leftOf("zz.a"), 1000)
T("ligne-guide verticale cachee apres le lacher", not M.guideV:IsShown())
-- pendant le glissement, la guide est visible
MOUSE.x, MOUSE.y, MOUSE.down = 1050, 725, true
this = ha
arg1 = "LeftButton"
ha.scripts.OnMouseDown()
MOUSE.x = 1050 - 97
Pump(0.02, 2)
T("guide verticale visible pendant le glissement", M.guideV:IsShown())
MOUSE.down = false
Pump(0.02, 1)
-- Alt = pas d'aimant
M.Commit(M.items["zz.a"], 1000, 725)
ABMOD(false, true, false)
drag(ha, 1000, 725, 1000 + 4, 725)
EQ("Alt : aucune aimantation", leftOf("zz.a"), 1004)
ABMOD(false)
-- aimantation coupee par l'option
M.Commit(M.items["zz.a"], 1004, 725)
C.Set("mover.snap", false)
drag(ha, 1000, 725, 1003, 725)
EQ("option aimant coupee", leftOf("zz.a"), 1007)
C.Set("mover.snap", true)
-- aimantation sur le centre de l'ecran (960) : centre de A a 957 -> 960
M.Commit(M.items["zz.a"], 907, 725)
drag(ha, 1000, 725, 1000, 725)
M.Commit(M.items["zz.a"], 907, 725)
drag(ha, 1000, 725, 1003, 725)
EQ("aimant sur le centre de l'ecran", leftOf("zz.a") + 50, 960)
-- grille
C.Set("mover.snap", false)
C.Set("mover.grid", true)
C.Set("mover.gridsize", 40)
T("grille affichee", M.grid ~= nil and M.grid:IsShown() or true)
drag(ha, 1000, 725, 1000 + 17, 725 + 3)
EQ("grille : gauche multiple de 40", leftOf("zz.a") % 40, 0)
C.Set("mover.grid", false)
C.Set("mover.snap", true)
-- un simple clic (sans deplacement) selectionne et ouvre le panneau
local before = leftOf("zz.a")
MOUSE.x, MOUSE.y, MOUSE.down = 1000, 725, true
this = ha
arg1 = "LeftButton"
ha.scripts.OnMouseDown()
MOUSE.down = false
Pump(0.02, 1)
this = ha
arg1 = "LeftButton"
ha.scripts.OnMouseUp()
EQ("clic sans glisser : position inchangee", leftOf("zz.a"), before)
EQ("clic : cadre selectionne", M.sel, M.items["zz.a"])
T("panneau de position affiche", M.panel:IsShown())
EQ("panneau : titre = nom du cadre", M.panel.title:GetText(), "Cadre A")

SECTION("t_mover : fleches, molette, clic droit")
C.Set("mover.snap", false)
M.Commit(M.items["zz.a"], 800, 600)
this = ha
Hover(ha, true)
M.sel = M.items["zz.a"]
arg1 = "RIGHT"
this = M.veil
M.veil.scripts.OnKeyDown()
EQ("fleche droite = 1 px", leftOf("zz.a"), 801)
arg1 = "UP"
M.veil.scripts.OnKeyDown()
EQ("fleche haut = 1 px", botOf("zz.a"), 601)
ABMOD(true, false, false)
arg1 = "LEFT"
M.veil.scripts.OnKeyDown()
EQ("Maj + fleche = 10 px", leftOf("zz.a"), 791)
arg1 = "DOWN"
M.veil.scripts.OnKeyDown()
EQ("Maj + bas = 10 px", botOf("zz.a"), 591)
ABMOD(false)
-- molette
this = ha
arg1 = 1
ha.scripts.OnMouseWheel()
local _, _, s = posOf("zz.a")
NEAR("molette : echelle 1,05", s, 1.05, 0.001)
NEAR("l'echelle est appliquee au cadre", M.items["zz.a"].frame:GetScale(), 1.05 * C.Get("ui.scale"), 0.001)
CONTAINS("etiquette : echelle", ha.label:GetText(), "x1.05")
arg1 = -1
ha.scripts.OnMouseWheel()
ha.scripts.OnMouseWheel()
_, _, s = posOf("zz.a")
NEAR("molette : echelle 0,95", s, 0.95, 0.001)
-- cadre sans echelle (zz.c)
local hc = M.items["zz.c"].handle
this = hc
arg1 = 1
hc.scripts.OnMouseWheel()
local _, _, sc = posOf("zz.c")
EQ("cadre sans echelle : molette ignoree", sc, nil)
-- clic droit sur un cadre sans page de reglages : rien ne se passe, le mode reste actif
this = ha
arg1 = "RightButton"
ha.scripts.OnMouseUp()
EQ("clic droit sans page : mode toujours actif", M.active, true)
EQ("cadre de test : pas de categorie", M.SettingsCat("zz.a"), nil)
EQ("bars.main -> categorie actionbars", M.SettingsCat("bars.main"), SUI.Menu and SUI.Menu.CatExists and SUI.Menu.CatExists("actionbars") and "actionbars" or nil)
-- clic molette = reinitialiser
this = ha
arg1 = "MiddleButton"
ha.scripts.OnMouseUp()
EQ("clic molette : position retiree", posOf("zz.a"), nil)
EQ("clic molette : retour a la position par defaut", leftOf("zz.a"), 700)
EQ("clic molette : retour a l'echelle 1", M.items["zz.a"].frame:GetScale(), C.Get("ui.scale"))
C.Set("mover.snap", true)

SECTION("t_mover : clic droit = menu d'actions au-dessus de tout (strate, niveau, capture)")
do
  local ORD = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
  local function st(f) return f.calls.SetFrameStrata and f.calls.SetFrameStrata[1] end
  local function rowOf(act)
    for i = 1, table.getn(M.ctx.rows) do
      if M.ctx.rows[i].act == act then return M.ctx.rows[i] end
    end
  end
  local function rclick(h)
    this = h
    arg1 = "RightButton"
    h.scripts.OnMouseUp()
  end
  M.CloseCtx()
  EQ("menu contextuel ferme avant le clic droit", M.ctx == nil or not M.ctx:IsShown(), true)
  rclick(ha)
  T("menu contextuel cree", M.ctx ~= nil and M.ctx:IsShown())
  EQ("le clic droit ne quitte pas le mode", M.active, true)
  EQ("menu : strate TOOLTIP", st(M.ctx), "TOOLTIP")
  EQ("cadre de capture : strate TOOLTIP", st(M.ctxCatcher), "TOOLTIP")
  EQ("cadre de capture affiche", M.ctxCatcher:IsShown(), true)
  EQ("cadre de capture capte la souris", M.ctxCatcher.mouse, true)
  T("capture sous le menu (niveau)", M.ctxCatcher:GetFrameLevel() < M.ctx:GetFrameLevel())
  local nrow = table.getn(M.ctx.rows)
  EQ("neuf actions", nrow, 9)
  for i = 1, nrow do
    local b = M.ctx.rows[i]
    EQ("action " .. b.act .. " : strate TOOLTIP", st(b), "TOOLTIP")
    T("action " .. b.act .. " : niveau au-dessus du menu", b:GetFrameLevel() > M.ctx:GetFrameLevel())
    T("action " .. b.act .. " : texte", b.label:GetText() ~= nil and b.label:GetText() ~= "" and b.label:GetText() ~= "mod.mover.ctx." .. b.act)
  end
  -- au-dessus de tout ce que le deplacement dessine
  local function below(name, fr)
    T(name .. " sous le menu contextuel (strate)", ORD[st(fr)] < ORD[st(M.ctx)])
  end
  below("voile", M.veil)
  below("bandeau", M.banner)
  below("panneau", M.BuildPanel())
  below("liste", M.BuildList())
  local nh = 0
  for i = 1, table.getn(M.order) do
    local rec = M.items[M.order[i]]
    if rec.handle then
      nh = nh + 1
      below("poignee " .. rec.id, rec.handle)
    end
  end
  T("des poignees comparees", nh > 0)
  EQ("titre = nom du cadre", M.ctx.title:GetText(), "Cadre A")
  -- ordre de capture : un clic hors du menu le ferme sans toucher au reste
  M.ctxCatcher.scripts.OnClick()
  EQ("clic hors menu : ferme", M.ctx:IsShown(), false)
  EQ("clic hors menu : capture retiree", M.ctxCatcher:IsShown(), false)
  EQ("clic hors menu : mode toujours actif", M.active, true)
  -- taille
  rclick(ha)
  local _, _, s0 = posOf("zz.a")
  rowOf("plus"):Click()
  local _, _, s1 = posOf("zz.a")
  NEAR("taille + : echelle", s1, (s0 or 1) + 0.05, 0.001)
  EQ("taille + : le menu reste ouvert", M.ctx:IsShown(), true)
  rowOf("minus"):Click()
  rowOf("minus"):Click()
  local _, _, s2 = posOf("zz.a")
  NEAR("taille - x2 : echelle", s2, (s0 or 1) - 0.05, 0.001)
  rowOf("norm"):Click()
  local _, _, s3 = posOf("zz.a")
  NEAR("taille normale", s3 or 1, 1, 0.001)
  EQ("taille normale : menu ferme", M.ctx:IsShown(), false)
  -- reinitialiser la position
  M.Commit(M.items["zz.a"], 900, 700)
  EQ("deplace avant reinitialisation", leftOf("zz.a"), 900)
  rclick(ha)
  rowOf("reset"):Click()
  EQ("reinitialiser : position retiree", posOf("zz.a"), nil)
  EQ("reinitialiser : retour a la place d'origine", leftOf("zz.a"), 700)
  EQ("reinitialiser : menu ferme", M.ctx:IsShown(), false)
  EQ("reinitialiser : mode actif", M.active, true)
  -- position precise
  rclick(ha)
  rowOf("pos"):Click()
  EQ("position precise : cadre selectionne", M.sel, M.items["zz.a"])
  EQ("position precise : panneau ouvert", M.panel:IsShown(), true)
  -- cadre sans echelle : actions de taille inactives
  local hcc = M.items["zz.c"].handle
  rclick(hcc)
  EQ("sans echelle : taille + inactive", rowOf("plus").disabled, true)
  EQ("sans echelle : taille normale inactive", rowOf("norm").disabled, true)
  local sc0 = M.items["zz.c"].frame:GetScale()
  rowOf("plus"):Click()
  EQ("sans echelle : clic sans effet", M.items["zz.c"].frame:GetScale(), sc0)
  EQ("sans page de reglages : options inactives", rowOf("opts").disabled, true)
  M.CloseCtx()
  -- ouvrir les options du module : le menu passe au-dessus, le mode deplacement reste actif
  local hp = M.items["unit.player"].handle
  rclick(hp)
  EQ("cadre joueur : options actives", rowOf("opts").disabled, false)
  EQ("cadre joueur : taille active", rowOf("plus").disabled, not M.items["unit.player"].scaleOk)
  rowOf("opts"):Click()
  EQ("options : menu ShikiUI ouvert", Mn.frame:IsShown(), true)
  EQ("options : sur la page du module", Mn.cat, "units")
  EQ("options : le mode deplacement reste actif", M.active, true)
  EQ("options : menu contextuel ferme", M.ctx:IsShown(), false)
  EQ("options : menu en FULLSCREEN_DIALOG", st(Mn.frame), "FULLSCREEN_DIALOG")
  T("options : menu au-dessus de la poignee (niveau)", Mn.frame:GetFrameLevel() > hp:GetFrameLevel())
  T("options : menu au-dessus du bandeau (niveau)", Mn.frame:GetFrameLevel() > M.banner:GetFrameLevel())
  T("options : menu au-dessus du panneau (niveau)", Mn.frame:GetFrameLevel() > M.panel:GetFrameLevel())
  Mn.Hide()
  -- Echap ferme d'abord le menu contextuel
  rclick(hp)
  this = M.veil
  arg1 = "ESCAPE"
  M.veil.scripts.OnKeyDown()
  EQ("Echap : ferme le menu contextuel", M.ctx:IsShown(), false)
  EQ("Echap : le mode reste actif", M.active, true)
  -- verrouiller et quitter
  rclick(ha)
  rowOf("lock"):Click()
  EQ("verrouiller : mode quitte", M.active, false)
  EQ("verrouiller : menu ferme", M.ctx:IsShown(), false)
  EQ("verrouiller : capture retiree", M.ctxCatcher:IsShown(), false)
  M.Enter()
  EQ("nouvelle entree", M.active, true)
  Mn.Hide()
  M.Sync()
end

SECTION("t_mover : panneau de position precise")
M.Select(M.items["zz.a"])
local p = M.panel
-- X / Y sont des decalages depuis le point d'ancrage (BOTTOMLEFT) : ici 700 / 600
EQ("X affiche", p.edX:GetText(), "700")
EQ("Y affiche", p.edY:GetText(), "600")
p.edX:SetText("820")
p.edY:SetText("640")
this = p.edX
p.edX.scripts.OnEnterPressed()
EQ("X applique", leftOf("zz.a"), 820)
EQ("Y applique", botOf("zz.a"), 640)
p.edS:SetText("1.5")
this = p.edS
p.edS.scripts.OnEnterPressed()
_, _, s = posOf("zz.a")
NEAR("echelle appliquee", s, 1.5, 0.001)
p.edS:SetText("9")
p.edS.scripts.OnEnterPressed()
_, _, s = posOf("zz.a")
NEAR("echelle plafonnee a 2", s, 2, 0.001)
p.edS:SetText("1")
p.edS.scripts.OnEnterPressed()
p.edX:SetText("abc")
p.edX.scripts.OnEnterPressed()
EQ("X invalide ignore", leftOf("zz.a"), 820)
-- centrer horizontalement
p.bCenter:Click()
NEAR("centre horizontalement", leftOf("zz.a") + 50, 960, 0.5)
-- reinitialiser
p.bReset:Click()
EQ("reinitialiser", leftOf("zz.a"), 700)
-- aligner
M.Select(M.items["zz.a"])
local rowB = nil
for i = 1, M.ROWS do
  if p.rows[i]:IsShown() and p.rows[i].rec == M.items["zz.b"] then rowB = p.rows[i] end
end
if not rowB then
  M.alignOff = 0
  for off = 0, table.getn(M.alignList), M.ROWS do
    M.alignOff = off
    M.FillPanel(M.items["zz.a"])
    for i = 1, M.ROWS do
      if p.rows[i]:IsShown() and p.rows[i].rec == M.items["zz.b"] then rowB = p.rows[i] end
    end
    if rowB then break end
  end
end
T("Cadre B dans la liste d'alignement", rowB ~= nil)
M.alignMode = "y"
M.Commit(M.items["zz.a"], 700, 900)
rowB:Click()
NEAR("meme hauteur (centres verticaux alignes)", botOf("zz.a") + 25, botOf("zz.b") + 20, 0.5)
M.alignMode = "x"
M.Commit(M.items["zz.a"], 650, 900)
rowB:Click()
EQ("meme X", leftOf("zz.a"), leftOf("zz.b"))
M.alignMode = "w"
M.Commit(M.items["zz.a"], 700, 600)
rowB:Click()
_, _, s = posOf("zz.a")
NEAR("meme largeur : echelle 1,2", s, 1.2, 0.001)
p.bReset:Click()
-- symetrique
M.Select(M.items["zz.a"])
M.alignSel = M.items["zz.b"]
p.bMirror:Click()
NEAR("symetrique : centre a l'oppose de B", leftOf("zz.a") + 50, 1920 - (leftOf("zz.b") + 60), 0.5)
p.bReset:Click()
M.alignSel = nil
M.ClosePanel()
T("panneau ferme", not M.panel:IsShown())

SECTION("t_mover : Joueur / Cible symetriques")
M.Commit(M.items["unit.player"], 100, 300)
M.Commit(M.items["unit.target"], 400, 500)
CHATCLEAR()
M.banner.sym:Click()
local lp, rp = M.Rect(M.items["unit.player"]), nil
local pl, pb, pr, pt = M.Rect(M.items["unit.player"])
local tl, tb, tr, tt = M.Rect(M.items["unit.target"])
NEAR("meme hauteur", (pb + pt) / 2, (tb + tt) / 2, 0.5)
NEAR("distances egales au centre", 960 - (pl + pr) / 2, (tl + tr) / 2 - 960, 0.5)
T("joueur a gauche, cible a droite", (pl + pr) / 2 < 960 and (tl + tr) / 2 > 960)
CONTAINS("message", CHATTEXT(), "meme hauteur")
-- trop pres du centre : l'ecart minimal est respecte
M.PlaceCenter(M.items["unit.player"], 955, 500)
M.PlaceCenter(M.items["unit.target"], 1500, 700)
M.banner.sym:Click()
pl, pb, pr, pt = M.Rect(M.items["unit.player"])
tl, tb, tr, tt = M.Rect(M.items["unit.target"])
local pw, tw = pr - pl, tr - tl
T("ecart minimal entre Joueur et Cible", (tl + tr) / 2 - (pl + pr) / 2 >= (pw + tw) / 2 + 19)
M.Reset("unit.player")
M.Reset("unit.target")

SECTION("t_mover : Montrer tout")
M.Exit(true)
C.Set("modules.group", true)
C.Set("modules.raid", true)
SETTLE()
M.Enter()
EQ("faux cadres : pas encore", M.showAll, false)
M.banner.all:Click()
EQ("montrer tout", M.showAll, true)
EQ("apercu du module appele", previewed[table.getn(previewed)], true)
T("cadre cache : poignee factice", M.items["zz.hidden"].handle ~= nil and M.items["zz.hidden"].handle:IsShown())
CONTAINS("etiquette factice", M.items["zz.hidden"].handle.label:GetText(), "exemple")
T("plaques d'exemple", M.demo ~= nil and M.demo:IsShown())
-- groupe / raid factices
local hg = M.items["group"] and M.items["group"].handle
T("groupe : poignee", hg ~= nil and hg:IsShown())
EQ("groupe : 5 cellules factices", hg and table.getn(hg.cells) >= 5, true)
local raidrec = M.items["raid"]
if raidrec then
  T("raid : poignee", raidrec.handle ~= nil and raidrec.handle:IsShown())
  local seen = {}
  for i = 1, table.getn(M.RAIDSIZES) do
    seen[M.RAIDSIZES[i]] = true
  end
  EQ("tailles de raid 5/10/25/40", table.concat({ M.RAIDSIZES[1], M.RAIDSIZES[2], M.RAIDSIZES[3], M.RAIDSIZES[4] }, ","), "5,10,25,40")
  local before = M.raidIdx
  M.banner.raid:Click()
  T("changer la taille du raid factice", M.raidIdx ~= before)
  EQ("libelle du bouton", M.banner.raid.label:GetText(), "Raid : " .. M.RAIDSIZES[M.raidIdx])
end
-- pas d'allocation en combat pour les poignees manquantes
M.SetShowAll(false)
EQ("apercu retire", previewed[table.getn(previewed)], false)
T("plaques retirees", not M.demo:IsShown())
T("poignee factice cachee", not M.items["zz.hidden"].handle:IsShown())
local c0 = CREATED
W.combat = true
M.SetShowAll(true)
EQ("aucune creation en combat (Montrer tout)", CREATED, c0)
W.combat = false
M.SetShowAll(false)
-- sortie : tout est retire
M.SetShowAll(true)
M.Exit(true)
T("sortie : plaques retirees", not M.demo:IsShown())
T("sortie : apercu retire", previewed[table.getn(previewed)] == false)
EQ("sortie : showAll remis a faux", M.showAll, false)

SECTION("t_mover : annuler, reinitialiser, positions par mode")
M.Enter()
M.Commit(M.items["zz.a"], 810, 620)
M.Commit(M.items["zz.b"], 1010, 640)
M.banner.cancel:Click()
EQ("annuler : mode ferme", M.active, false)
EQ("annuler : A revient", leftOf("zz.a"), 700)
EQ("annuler : B revient", leftOf("zz.b"), 1000)
EQ("annuler : rien d'enregistre", posOf("zz.a"), nil)
M.Enter()
M.Commit(M.items["zz.a"], 810, 620)
M.Commit(M.items["zz.b"], 1010, 640)
M.banner.exit:Click()
EQ("garder : A enregistre", leftOf("zz.a"), 810)
-- tout reinitialiser : deux clics
M.Enter()
M.banner.reset:Click()
EQ("tout reinitialiser : 1er clic demande confirmation", M.banner.reset.label:GetText(), "Confirmer ?")
EQ("rien n'est efface au 1er clic", leftOf("zz.a"), 810)
M.banner.reset:Click()
EQ("2e clic reinitialise", leftOf("zz.a"), 700)
EQ("B aussi", leftOf("zz.b"), 1000)
-- /sui move reset
M.Commit(M.items["zz.a"], 810, 620)
M.Commit(M.items["zz.b"], 1010, 640)
CONTAINS("reset d'un cadre", cmd("move reset zz.a"), "Cadre A")
EQ("A reinitialise", leftOf("zz.a"), 700)
EQ("B intact", leftOf("zz.b"), 1010)
cmd("move reset all")
EQ("tout reinitialise", leftOf("zz.b"), 1000)
CONTAINS("cadre inconnu", cmd("move reset zz.nope"), "zz.nope")
M.Exit(true)
-- mode Raid : positions propres au mode, repli sur Normal
M.Enter()
M.Commit(M.items["zz.a"], 810, 620)
M.Exit(true)
EQ("Normal : A deplace", leftOf("zz.a"), 810)
SUI.Mode.Set("raid", "manual")
SETTLE()
EQ("Raid : repli sur la position Normal", leftOf("zz.a"), 810)
M.Enter()
M.Commit(M.items["zz.a"], 900, 700)
M.Exit(true)
EQ("Raid : position propre au mode", leftOf("zz.a"), 900)
T("Raid : position serialisable (cle a part)", C.cur.pos["zz.a|raid"] ~= nil)
EQ("Raid : Normal intact", (C.GetPos("zz.a")), 810)
SUI.Mode.Set("normal", "manual")
SETTLE()
EQ("retour Normal", leftOf("zz.a"), 810)
-- reinitialiser efface les deux modes
M.Enter()
M.Reset("zz.a")
M.Exit(true)
SUI.Mode.Set("raid", "manual")
SETTLE()
EQ("reinitialiser efface aussi le mode Raid", leftOf("zz.a"), 700)
SUI.Mode.Set("normal", "manual")
SETTLE()

SECTION("t_mover : /sui move grid, show, sym, list")
cmd("move grid")
EQ("grille activee", C.Get("mover.grid"), true)
cmd("move grid")
EQ("grille coupee", C.Get("mover.grid"), false)
cmd("move show")
EQ("show ouvre le mode et montre tout", M.active and M.showAll, true)
cmd("move sym")
M.Exit(true)
CONTAINS("liste", cmd("move list"), "zz.a")
CONTAINS("aide inconnue", cmd("move zzz"), "move")

SECTION("t_mover : plus de fond anonyme hors mode")
-- ui.locked=false seul : le mode s'ouvre et seules les poignees nommees apparaissent
C.Set("ui.locked", false)
local anon = 0
for i = 1, table.getn(ALLFRAMES) do
  local f = ALLFRAMES[i]
  if f.kind ~= "Texture" and f.kind ~= "FontString" and f:IsVisible() and f.backdrop and (f.w or 0) >= 60 and (f.h or 0) >= 60 and not f.name then
    -- un fond sans nom visible : doit etre une poignee, un panneau du mode ou le menu
    local ok = false
    for j = 1, table.getn(M.order) do
      if M.items[M.order[j]].handle == f then ok = true end
    end
    if f.parent == M.veil or f.parent == M.banner then ok = true end
    if not ok then
      anon = anon + 1
      print("  fond anonyme : " .. tostring(f.w) .. "x" .. tostring(f.h))
    end
  end
end
EQ("aucun fond anonyme visible", anon, 0)
C.Set("ui.locked", true)

SECTION("t_mover : surcharge du menu et reouverture")
Mn.Show("styles")
T("menu ouvert", Mn.frame:IsShown())
M.Enter()
T("menu masque pendant le deplacement", not Mn.frame:IsShown())
M.Exit(true)
T("menu rouvert apres", Mn.frame:IsShown())
EQ("meme page", Mn.page, "styles")
Mn.Hide()
M.Enter()
M.Exit(true)
T("menu ferme reste ferme", not Mn.frame:IsShown())

SECTION("t_mover : cadres caches, liste, reduction des panneaux")
do
  EQ("UIParent n'est pas deplacable", M.Register("zz.ui", UIParent), false)
  local far = mk(100, 40)
  M.Register("zz.far", far, { point = "BOTTOMLEFT", x = -4000, y = -4000 })
  M.Enter()
  local rec = M.items["zz.hidden"]
  T("cadre cache : toujours sans poignee avant la liste", rec.handle == nil or not rec.handle:IsShown())
  local names = {}
  for _, it in ipairs(M.ListItems()) do names[it.rec.id] = true end
  T("la liste contient le cadre cache", names["zz.hidden"])
  T("la liste contient le cadre hors ecran", names["zz.far"])
  T("la liste contient les cadres des modules", names["unit.player"])
  EQ("Focus d'un cadre cache", M.Focus(rec), true)
  T("poignee forcee visible", rec.handle ~= nil and rec.handle:IsShown())
  T("poignee nommee", string.find(rec.handle.label:GetText(), M.Label("zz.hidden"), 1, true) ~= nil)
  T("etiquette 'exemple' sur un cadre cache", string.find(rec.handle.label:GetText(), "exemple", 1, true) ~= nil)
  EQ("cadre selectionne", M.sel, rec)
  T("panneau de position ouvert", M.panel:IsShown())
  local frec = M.items["zz.far"]
  T("cadre hors ecran detecte", M.OffScreen(frec))
  M.Focus(frec)
  T("cadre hors ecran ramene a l'ecran", not M.OffScreen(frec))
  T("poignee minimale (largeur)", frec.handle:GetWidth() >= M.MINW)
  T("poignee minimale (hauteur)", frec.handle:GetHeight() >= M.MINH)
  -- liste : ouverture, recherche, clic
  M.ToggleList()
  T("liste ouverte", M.list:IsShown())
  M.list.edit:SetText("cadre a")
  this = M.list.edit
  M.list.edit.scripts.OnTextChanged()
  local items = M.ListItems()
  EQ("recherche : un seul resultat", table.getn(items), 1)
  EQ("recherche : Cadre A", items[1].label, "Cadre A")
  T("ligne visible", M.list.rows[1]:IsShown())
  T("ligne suivante vide", not M.list.rows[2]:IsShown())
  Click(M.list.rows[1])
  EQ("clic ligne : selection", M.sel, M.items["zz.a"])
  M.list.edit:SetText("")
  M.list.edit.scripts.OnTextChanged()
  T("filtre vide : toute la liste", table.getn(M.ListItems()) >= 8)
  -- reduction des panneaux
  M.Collapse(M.list, true)
  T("liste reduite : lignes cachees", not M.list.rows[1]:IsShown())
  EQ("liste reduite : hauteur", M.list:GetHeight(), 34)
  M.Collapse(M.list, false)
  T("liste rouverte", M.list.rows[1]:IsShown())
  M.Collapse(M.panel, true)
  T("panneau reduit : champs caches", not M.panel.edX:IsShown())
  M.Select(M.items["zz.b"])
  T("panneau reduit reste reduit apres selection", not M.panel.edX:IsShown())
  M.Collapse(M.panel, false)
  T("panneau rouvert", M.panel.edX:IsShown())
  M.CollapseBanner(true)
  T("bandeau reduit : boutons caches", not M.banner.grid:IsShown() and not M.banner.reset:IsShown())
  T("bandeau reduit : quitter reste visible", M.banner.exit:IsShown())
  EQ("bandeau reduit : hauteur", M.banner:GetHeight(), 60)
  M.CollapseBanner(false)
  T("bandeau rouvert", M.banner.grid:IsShown())
  T("bandeau deplacable", M.banner.movable == true)
  T("panneau deplacable", M.panel.movable == true)
  M.Exit(true)
  T("liste fermee a la sortie", not M.list:IsShown())
  T("poignee forcee retiree a la sortie", not rec.handle:IsShown() and rec.forced == nil)
end

SECTION("t_mover : poignees empilees (ordre par taille, faux cadres compacts, cycle, liste)")
do
  local big, mid, small = mk(600, 400), mk(300, 200), mk(90, 40)
  M.Register("zz.big", big, { point = "BOTTOMLEFT", x = 1300, y = 300, label = "Grand" })
  M.Register("zz.mid", mid, { point = "BOTTOMLEFT", x = 1350, y = 350, label = "Moyen" })
  M.Register("zz.small", small, { point = "BOTTOMLEFT", x = 1400, y = 400, label = "Petit" })
  local huge = mk(900, 700)
  huge:Hide()
  M.Register("zz.huge", huge, { point = "BOTTOMLEFT", x = 1000, y = 100, label = "Enorme cache" })
  M.Enter()
  M.SetShowAll(true)
  local rb, rm, rs, rh = M.items["zz.big"], M.items["zz.mid"], M.items["zz.small"], M.items["zz.huge"]
  local lb, lm, ls = rb.handle:GetFrameLevel(), rm.handle:GetFrameLevel(), rs.handle:GetFrameLevel()
  T("niveau : moyen au-dessus du grand", lm > lb)
  T("niveau : petit au-dessus du moyen", ls > lm)
  T("niveaux sous les panneaux", ls < M.veil:GetFrameLevel() + 30)
  -- faux cadre d'exemple : taille compacte et transparence
  local w, h = M.RectSize(rh)
  T("faux cadre : largeur compacte", w <= M.GHOSTW)
  T("faux cadre : hauteur compacte", h <= M.GHOSTH)
  T("la poignee d'un cadre cache est petite", rh.handle:GetWidth() <= M.GHOSTW and rh.handle:GetHeight() <= M.GHOSTH)
  -- poignees empilees sous un point
  local l, b = M.FrameLB(rs)
  local under = M.Under(l + 5, b + 5)
  T("3 poignees (au moins) sous le point", table.getn(under) >= 3)
  EQ("la plus petite d'abord", under[1], rs)
  local seen = {}
  for i = 1, table.getn(under) do seen[under[i]] = i end
  T("ordre croissant des tailles", seen[rs] < seen[rm] and seen[rm] < seen[rb])
  -- cycle : Tab parcourt les poignees sous la souris
  local cx, cy = l + 5, b + 5
  local old = GetCursorPosition
  GetCursorPosition = function() return cx * UIParent:GetEffectiveScale(), cy * UIParent:GetEffectiveScale() end
  M.sel = nil
  M.CycleUnder()
  EQ("premier cycle : la plus petite", M.sel, rs)
  M.CycleUnder()
  EQ("deuxieme cycle : la suivante", M.sel, under[2])
  this = M.veil
  arg1 = "TAB"
  M.veil.scripts.OnKeyDown()
  EQ("Tab : poignee suivante", M.sel, under[3])
  for i = 1, table.getn(under) do M.CycleUnder() end
  T("le cycle boucle", M.sel ~= nil)
  GetCursorPosition = old
  -- liste : cadre totalement recouvert
  M.Focus(rb)
  EQ("liste : cadre selectionne", M.sel, rb)
  EQ("liste : mis en avant", M.raised, rb)
  T("liste : poignee au-dessus des petites", rb.handle:GetFrameLevel() > rs.handle:GetFrameLevel())
  T("liste : clignotement lance", M.flash ~= nil and M.flash.rec == rb)
  M.Select(rs)
  EQ("une autre selection retire la mise en avant", M.raised, nil)
  T("niveau d'origine retabli", rb.handle:GetFrameLevel() < rs.handle:GetFrameLevel())
  M.Focus(rb)
  M.Exit(true)
  EQ("sortie : mise en avant effacee", M.raised, nil)
  EQ("sortie : clignotement efface", M.flash, nil)
end

W.layout = false
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
