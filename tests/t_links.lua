-- t_links : LIENS entre modules (Layouts.lua : SetLink / GetLink / Unlink / Children / DefaultLinks ; Mover.lua : glisser un parent, cote qui brille,
-- proposition, symbole o-o, menu "Accroche a"). Prouve : suivi du parent (position, echelle, taille), cycles refuses, parent absent, mode raid,
-- reinitialisation, detachement persistant (export / import), anciennes positions respectees, rien ne bouge en combat, option layout.links.
local SUI = ShikiUI
local C = SUI.Config
local Ly = SUI.Layout
local M = SUI.Mover
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
BOOT()
SETTLE()
W.layout = true

local sc = C.Get("ui.scale")
local function mk(w, h)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetWidth(w)
  f:SetHeight(h)
  return f
end
-- coin bas-gauche REEL d'un cadre (unites d'UIParent) d'apres son ancrage
local function LB(f)
  local p = f.points[1]
  return p[4] * f:GetScale(), p[5] * f:GetScale()
end
local function reg(key, w, h, x, y)
  local f = mk(w, h)
  SUI.Layout.Register(f, key, "BOTTOMLEFT", x, y)
  return f
end

local P = reg("zl.p", 200, 100, 500, 400)      -- parent (largeur 200, hauteur 100, a l'echelle ui.scale)
local A = reg("zl.a", 100, 20, 100, 100)       -- enfant
local B = reg("zl.b", 40, 40, 20, 20)          -- petit-enfant
local X = reg("zl.x", 50, 50, 1500, 900)       -- cadre sans lien
local e0 = SUI.errCount

-- position attendue d'un enfant (cw x ch en unites de cadre) sous / au-dessus / a gauche / a droite d'un parent (pl, pb, pw, ph en UIParent)
local function under(pl, pb, pw, ph, cw, ch, dx, dy) return pl + pw / 2 - cw * sc / 2 + dx, pb - ch * sc + dy end

SECTION("t_links : validation de l'API")
local ok, why = Ly.SetLink("zl.a", "zl.p", "DIAGONALE")
EQ("cote invalide : raison", why, "side")
ok, why = Ly.SetLink("zl.a", "zl.nexistepas", "TOP")
EQ("parent inconnu", ok, false)
EQ("parent inconnu : raison", why, "unknown")
ok, why = Ly.SetLink("zl.nexistepas", "zl.p", "TOP")
EQ("enfant inconnu", ok, false)
ok, why = Ly.SetLink("zl.a", "zl.a", "TOP")
EQ("lien a soi-meme refuse", ok, false)
EQ("lien a soi-meme : cycle", why, "cycle")
ok, why = Ly.SetLink(5, "zl.p", "TOP")
EQ("arguments invalides", ok, false)
EQ("aucun lien enregistre apres les refus", Ly.GetLink("zl.a"), nil)
EQ("Unlink sans lien", (Ly.Unlink("zl.a")), false)

SECTION("t_links : suivi du parent")
local ax0, ay0 = LB(A)
NEAR("libre : x par defaut", ax0, 100 * sc, 0.01)
EQ("SetLink", (Ly.SetLink("zl.a", "zl.p", "BOTTOM")), true)
local p, side, dx, dy, src = Ly.GetLink("zl.a")
EQ("GetLink : parent", p, "zl.p")
EQ("GetLink : cote", side, "BOTTOM")
EQ("GetLink : dx par defaut", dx, 0)
EQ("GetLink : dy = ecart standard", dy, -Ly.GAP)
EQ("GetLink : source", src, "user")
local ex, ey = under(500 * sc, 400 * sc, 200 * sc, 100 * sc, 100, 20, 0, -Ly.GAP)
local ax, ay = LB(A)
NEAR("sous le parent : x (centre)", ax, ex, 0.01)
NEAR("sous le parent : y", ay, ey, 0.01)
T("le parent n'a pas bouge", math.abs(LB(P) - 500 * sc) < 0.01)
NEAR("le cadre sans lien n'a pas bouge", (LB(X)), 1500 * sc, 0.01)
-- le parent bouge (position enregistree + Layout.Apply, comme le Mover)
C.SetPos("zl.p", 800, 500)
Ly.Apply("zl.p")
ex, ey = under(800, 500, 200 * sc, 100 * sc, 100, 20, 0, -Ly.GAP)
ax, ay = LB(A)
NEAR("le parent bouge : l'enfant suit (x)", ax, ex, 0.01)
NEAR("le parent bouge : l'enfant suit (y)", ay, ey, 0.01)
-- le parent change d'echelle (echelle propre du cadre, Mover)
C.SetPos("zl.p", 800, 500, 1.5)
Ly.Apply("zl.p")
ex, ey = under(800, 500, 200 * sc * 1.5, 100 * sc * 1.5, 100, 20, 0, -Ly.GAP)
ax, ay = LB(A)
NEAR("echelle du parent : x", ax, ex, 0.01)
NEAR("echelle du parent : y", ay, ey, 0.01)
-- l'echelle globale de l'interface
C.Set("ui.scale", 1.2)
local s2 = 1.2
ex = 800 + 200 * s2 * 1.5 / 2 - 100 * s2 / 2
ey = 500 - 20 * s2 - Ly.GAP
ax, ay = LB(A)
NEAR("ui.scale : x", ax, ex, 0.01)
NEAR("ui.scale : y", ay, ey, 0.01)
C.Set("ui.scale", sc)
-- le parent change de TAILLE sans passer par Layout.Apply : la minuterie le voit
C.SetPos("zl.p", 800, 500)
Ly.Apply("zl.p")
P:SetWidth(300)
P:SetHeight(140)
Pump(0.1, 8)
ex, ey = under(800, 500, 300 * sc, 140 * sc, 100, 20, 0, -Ly.GAP)
ax, ay = LB(A)
NEAR("taille du parent (minuterie) : x", ax, ex, 0.01)
NEAR("taille du parent (minuterie) : y", ay, ey, 0.01)
P:SetWidth(200)
P:SetHeight(100)
EQ("RefreshLinks : un cadre replace", Ly.RefreshLinks(false), 1)
EQ("RefreshLinks : plus rien a replacer", Ly.RefreshLinks(false), 0)
ex, ey = under(800, 500, 200 * sc, 100 * sc, 100, 20, 0, -Ly.GAP)
ax, ay = LB(A)
NEAR("taille revenue : x", ax, ex, 0.01)

SECTION("t_links : decalage et quatre cotes")
EQ("SetLink avec decalage", (Ly.SetLink("zl.a", "zl.p", "TOP", 30, 10)), true)
ax, ay = LB(A)
NEAR("TOP : x = centre + dx", ax, 800 + 100 * sc - 50 * sc + 30, 0.01)
NEAR("TOP : y = haut du parent + dy", ay, 500 + 100 * sc + 10, 0.01)
EQ("RIGHT", (Ly.SetLink("zl.a", "zl.p", "RIGHT", 6, -3)), true)
ax, ay = LB(A)
NEAR("RIGHT : x", ax, 800 + 200 * sc + 6, 0.01)
NEAR("RIGHT : y (centre)", ay, 500 + 50 * sc - 10 * sc - 3, 0.01)
EQ("LEFT", (Ly.SetLink("zl.a", "zl.p", "LEFT")), true)
ax, ay = LB(A)
NEAR("LEFT : x", ax, 800 - 100 * sc - Ly.GAP, 0.01)
NEAR("LEFT : y", ay, 500 + 50 * sc - 10 * sc, 0.01)
local r1, r2, r3, r4 = Ly.Rect("zl.a")
NEAR("Rect : gauche", r1, ax, 0.01)
NEAR("Rect : largeur", r3, 100 * sc, 0.01)
EQ("remplacement : un seul lien par enfant", Ly.Children("zl.p")[1], "zl.a")
EQ("remplacement : pas de doublon", table.getn(Ly.Children("zl.p")), 1)
EQ("rejeu du meme lien : toujours un seul", (Ly.SetLink("zl.a", "zl.p", "LEFT")), true)
local nk = 0
for k, _ in pairs(C.cur.pos) do
  if string.sub(k, 1, 6) == "@zl.a>" then nk = nk + 1 end
end
EQ("une seule entree enregistree pour l'enfant", nk, 1)

SECTION("t_links : chaine, cycles, parcours")
EQ("petit-enfant", (Ly.SetLink("zl.b", "zl.a", "BOTTOM")), true)
local bx, by = LB(B)
local al, ab = LB(A)
NEAR("petit-enfant : sous l'enfant (x)", bx, al + 50 * sc - 20 * sc, 0.01)
NEAR("petit-enfant : sous l'enfant (y)", by, ab - 40 * sc - Ly.GAP, 0.01)
C.SetPos("zl.p", 900, 600)
Ly.Apply("zl.p")
local bx2, by2 = LB(B)
NEAR("la chaine suit le parent : decalage en x", bx2 - bx, 100, 0.01)
NEAR("la chaine suit le parent : decalage en y", by2 - by, 100, 0.01)
ok, why = Ly.SetLink("zl.p", "zl.b", "TOP")
EQ("cycle de 3 refuse", ok, false)
EQ("cycle : raison", why, "cycle")
ok, why = Ly.SetLink("zl.p", "zl.a", "TOP")
EQ("cycle de 2 refuse", ok, false)
EQ("le refus n'a rien enregistre", (Ly.GetLink("zl.p")), nil)
local kids = Ly.Children("zl.p")
EQ("Children(parent)", table.concat(kids, ","), "zl.a")
EQ("Descendants(parent)", table.concat(Ly.Descendants("zl.p"), ","), "zl.a,zl.b")
EQ("Descendants(enfant)", table.concat(Ly.Descendants("zl.a"), ","), "zl.b")
EQ("Children d'une feuille", table.getn(Ly.Children("zl.b")), 0)
T("IsDescendant", Ly.IsDescendant("zl.b", "zl.p") and not Ly.IsDescendant("zl.p", "zl.b") and not Ly.IsDescendant("zl.x", "zl.p"))
-- donnees importees avec un cycle : aucun blocage, les cadres du cycle restent libres
C.SetPos("@zl.p>zl.b*T", 0, 0)
Ly.InvalidateLinks()
EQ("cycle importe : pas de lien effectif", (Ly.LinkedParent("zl.p")), nil)
Ly.Apply("zl.p")
Ly.ApplyAll()
EQ("cycle importe : le parent garde sa place", (LB(P)), 900, 0)
C.cur.pos["@zl.p>zl.b*T"] = nil
Ly.InvalidateLinks()

SECTION("t_links : parent absent (module coupe)")
local saved = Ly.items["zl.p"]
Ly.items["zl.p"] = nil
Ly.Apply("zl.a")
ax, ay = LB(A)
NEAR("parent absent : l'enfant retombe sur sa place libre (x)", ax, 100 * sc, 0.01)
NEAR("parent absent : place libre (y)", ay, 100 * sc, 0.01)
EQ("parent absent : lien non effectif", (Ly.LinkedParent("zl.a")), nil)
EQ("parent absent : lien toujours enregistre", (Ly.GetLink("zl.a")), "zl.p")
Ly.items["zl.p"] = saved
Ly.Apply("zl.a")
ax = LB(A)
NEAR("parent revenu : l'enfant le suit de nouveau", ax, 900 - 100 * sc - Ly.GAP, 0.01)

SECTION("t_links : mode raid")
EQ("lien normal : cote", (select(2, Ly.GetLink("zl.a"))), "LEFT")
SUI.Mode.Set("raid", "manual")
SETTLE()
EQ("raid : herite du lien normal", (select(2, Ly.GetLink("zl.a"))), "LEFT")
EQ("raid : lien propre au mode", (Ly.SetLink("zl.a", "zl.p", "TOP", 0, 5)), true)
T("entree propre au mode enregistree", C.cur.pos["@zl.a>zl.p*T|raid"] ~= nil)
T("l'entree normale est intacte", C.cur.pos["@zl.a>zl.p*L"] ~= nil)
ax, ay = LB(A)
NEAR("raid : au-dessus", ay, 600 + 100 * sc + 5, 0.01)
SUI.Mode.Set("normal", "manual")
SETTLE()
EQ("retour en normal : cote d'origine", (select(2, Ly.GetLink("zl.a"))), "LEFT")
ax, ay = LB(A)
NEAR("retour en normal : a gauche", ax, 900 - 100 * sc - Ly.GAP, 0.01)
SUI.Mode.Set("raid", "manual")
SETTLE()
ax, ay = LB(A)
NEAR("raid a nouveau : au-dessus", ay, 600 + 100 * sc + 5, 0.01)
-- detacher en raid ne touche pas le lien normal
EQ("detacher en raid", Ly.Unlink("zl.a"), true)
EQ("raid : detache", (Ly.GetLink("zl.a")), nil)
T("raid : marqueur de detachement", C.cur.pos["@zl.a>-*N|raid"] ~= nil)
SUI.Mode.Set("normal", "manual")
SETTLE()
EQ("normal : toujours lie", (Ly.GetLink("zl.a")), "zl.p")
Ly.ResetLink("zl.a")
SUI.Mode.Set("raid", "manual")
SETTLE()
EQ("reset : plus aucune entree de lien", (Ly.GetLink("zl.a")), nil)
SUI.Mode.Set("normal", "manual")
SETTLE()
EQ("reset : normal libre aussi", (Ly.GetLink("zl.a")), nil)
C.ClearPosAll("zl.a")
C.ClearPosAll("zl.b")
Ly.ResetLink("zl.b")

SECTION("t_links : liens conseillees, reinitialisation, detachement persistant, anciennes positions")
local D = reg("zl.d", 60, 20, 10, 10)
local E = reg("zl.e", 60, 20, 10, 10)
C.SetPos("zl.e", 333, 444)                                  -- ancienne position enregistree (profil existant)
Ly.Apply("zl.e")
EQ("DefaultLink", Ly.DefaultLink("zl.d", "zl.p", "TOP"), true)
EQ("DefaultLink (enfant avec ancienne position)", Ly.DefaultLink("zl.e", "zl.p", "TOP"), true)
EQ("DefaultLink refuse un lien a soi", Ly.DefaultLink("zl.d", "zl.d", "TOP"), false)
EQ("DefaultLink refuse un cote inconnu", Ly.DefaultLink("zl.d", "zl.p", "MILIEU"), false)
Ly.Apply("zl.d")
local gp, gs, gx, gy, gsrc = Ly.GetLink("zl.d")
EQ("conseille : parent", gp, "zl.p")
EQ("conseille : source", gsrc, "default")
dx, dy = Ly.GetLink("zl.d") and 0, 0
local dl, db = LB(D)
NEAR("conseille : place au-dessus du parent (y)", db, 600 + 100 * sc + Ly.GAP, 0.01)
NEAR("conseille : centre (x)", dl, 900 + 100 * sc - 30 * sc, 0.01)
EQ("ancienne position : pas de lien conseille", (Ly.GetLink("zl.e")), nil)
local el, eb = LB(E)
NEAR("ancienne position respectee (x)", el, 333, 0.01)
NEAR("ancienne position respectee (y)", eb, 444, 0.01)
Ly.ApplyAll()
el, eb = LB(E)
NEAR("ApplyAll : ancienne position respectee", el, 333, 0.01)
-- le parent bouge : l'enfant a lien conseille suit, l'autre non
C.SetPos("zl.p", 1000, 300)
Ly.Apply("zl.p")
dl, db = LB(D)
NEAR("conseille : suit (y)", db, 300 + 100 * sc + Ly.GAP, 0.01)
el, eb = LB(E)
NEAR("ancienne position : ne suit pas", el, 333, 0.01)
-- reinitialiser le cadre (Mover) : l'ancienne position disparait, le lien conseille revient
EQ("Mover.Reset", M.Reset("zl.e"), true)
EQ("reset : lien conseille de retour", (Ly.GetLink("zl.e")), "zl.p")
el, eb = LB(E)
NEAR("reset : place au-dessus du parent", eb, 300 + 100 * sc + Ly.GAP, 0.01)
-- detacher est explicite et dure
EQ("Unlink d'un lien conseille", Ly.Unlink("zl.d"), true)
dl, db = LB(D)
NEAR("detache : le cadre reste ou il est (y)", db, 300 + 100 * sc + Ly.GAP, 0.01)
EQ("detache : plus de lien", (Ly.GetLink("zl.d")), nil)
C.SetPos("zl.p", 1100, 350)
Ly.Apply("zl.p")
Ly.ApplyAll()
dl, db = LB(D)
NEAR("detache : ne suit plus le parent", db, 300 + 100 * sc + Ly.GAP, 0.01)
SUI.Mode.Set("raid", "manual")
SETTLE()
EQ("detache : reste detache en raid", (Ly.GetLink("zl.d")), nil)
SUI.Mode.Set("normal", "manual")
SETTLE()
Ly.InvalidateLinks()
EQ("detache : reste detache apres relecture du profil", (Ly.GetLink("zl.d")), nil)
-- export / import du profil : liens et detachements voyagent avec les positions
EQ("SetLink avant export", (Ly.SetLink("zl.a", "zl.p", "RIGHT", 8, 2)), true)
local str = C.Export()
local iok, iname = C.Import(str, "LienTest")
EQ("import du profil", iok, true)
local pname = C.curName
C.UseProfile(iname)
Ly.InvalidateLinks()
local ip, iside, idx, idy = Ly.GetLink("zl.a")
EQ("import : lien conserve (parent)", ip, "zl.p")
EQ("import : cote", iside, "RIGHT")
EQ("import : dx", idx, 8)
EQ("import : dy", idy, 2)
EQ("import : detachement conserve", (Ly.GetLink("zl.d")), nil)
C.UseProfile(pname)
Ly.InvalidateLinks()
-- une mise en page appliquee place le cadre : le lien explicite s'efface
C.SetPos("zl.a", 5, 5)
Ly.ClearLink("zl.a")
EQ("ClearLink", (Ly.GetLink("zl.a")), nil)
EQ("clef d'enregistrement < 40 caracteres", string.len("@unit.targettarget>unit.target*R|raid") <= 40, true)

SECTION("t_links : option layout.links")
EQ("lien pose", (Ly.SetLink("zl.a", "zl.p", "BOTTOM")), true)
ax, ay = LB(A)
NEAR("option active : lie", ay, 350 - 20 * sc - Ly.GAP, 0.01)
C.Set("layout.links", false)
EQ("option coupee : liens inactifs", (Ly.LinkedParent("zl.a")), nil)
ax, ay = LB(A)
NEAR("option coupee : retour a la place libre (x)", ax, 5, 0.01)
NEAR("option coupee : retour a la place libre (y)", ay, 5, 0.01)
EQ("option coupee : le lien reste enregistre", (Ly.GetLink("zl.a")), "zl.p")
C.SetPos("zl.p", 1200, 400)
Ly.Apply("zl.p")
ax, ay = LB(A)
NEAR("option coupee : l'enfant ne suit pas", ax, 5, 0.01)
C.Set("layout.links", true)
ax, ay = LB(A)
NEAR("option rallumee : l'enfant est revenu (y)", ay, 400 - 20 * sc - Ly.GAP, 0.01)

SECTION("t_links : rien ne bouge en combat")
local created = CREATED
local tasks0 = table.getn(SUI.tasks)
W.combat = true
C.SetPos("zl.p", 400, 700)
Ly.Apply("zl.p")
local cx, cy = LB(A)
NEAR("combat : le parent a bouge (comportement existant)", (LB(P)), 400, 0.01)
NEAR("combat : l'enfant n'a pas bouge (x)", cx, 1200 + 100 * sc - 50 * sc, 0.01)
NEAR("combat : l'enfant n'a pas bouge (y)", cy, 400 - 20 * sc - Ly.GAP, 0.01)
ok, why = Ly.SetLink("zl.b", "zl.p", "TOP")
EQ("combat : SetLink refuse", ok, false)
EQ("combat : raison", why, "combat")
ok, why = Ly.Unlink("zl.a")
EQ("combat : Unlink refuse", ok, false)
EQ("combat : Unlink raison", why, "combat")
Ly.RefreshLinks(false)
Pump(0.1, 10)
cx, cy = LB(A)
NEAR("combat : minuterie sans effet", cy, 400 - 20 * sc - Ly.GAP, 0.01)
Ly.ApplyAll()
cx, cy = LB(A)
NEAR("combat : ApplyAll sans effet sur un cadre accroche", cy, 400 - 20 * sc - Ly.GAP, 0.01)
EQ("combat : aucune frame creee", CREATED, created)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
cx, cy = LB(A)
NEAR("fin de combat : l'enfant a rejoint son parent (x)", cx, 400 + 100 * sc - 50 * sc, 0.01)
NEAR("fin de combat : l'enfant a rejoint son parent (y)", cy, 700 - 20 * sc - Ly.GAP, 0.01)
EQ("fin de combat : mise a jour unique", Ly.deferred, false)
EQ("aucune minuterie en plus", table.getn(SUI.tasks) <= tasks0 + 1, true)

SECTION("t_links : liens conseilles reels (cles de positions existantes)")
local known = {}
for _, k in ipairs({ "unit.player", "unit.target", "unit.targettarget", "castbar.player", "castbar.target", "auras.pb", "auras.pw", "auras.pd",
  "auras.tb", "auras.td", "bars.main", "bars.bar2", "bars.bar3", "bars.bar4", "bars.bar5", "bars.stance", "bars.pet" }) do known[k] = true end
local ndef = 0
for child, d in pairs(Ly.DefaultLinks) do
  if string.sub(child, 1, 3) ~= "zl." then
    ndef = ndef + 1
    T("conseille : enfant connu " .. child, known[child] == true)
    T("conseille : parent connu " .. d.parent, known[d.parent] == true)
    T("conseille : cote valide " .. child, d.side == "TOP" or d.side == "BOTTOM" or d.side == "LEFT" or d.side == "RIGHT")
  end
end
T("une dizaine de liens conseilles", ndef >= 10)
EQ("aucune erreur interne avant l'activation des modules (" .. tostring(SUI.lastErr) .. ")", SUI.errCount, e0)
C.Set("modules.castbar", true)
C.Set("modules.auras", true)
C.Set("modules.actionbars", true)
SETTLE(6)
e0 = SUI.errCount        -- les mocks des modules (auras...) ne sont pas charges ici : leurs erreurs d'API simulee ne concernent pas les liens
local present = 0
for k, _ in pairs(known) do
  if Ly.items[k] then present = present + 1 else print("  (cle absente apres activation : " .. k .. ")") end
end
EQ("toutes les cles conseillees existent dans le Layout", present, 17)
-- joueur + incantation + buffs + debuffs se placent ensemble
C.ClearPosAll("unit.player")
C.SetPos("unit.player", 400, 300)
Ly.Apply("unit.player")
local cb1, cb2 = Ly.GetLink("castbar.player")
EQ("incantation du joueur accrochee au joueur", cb1, "unit.player")
T("buffs du joueur accroches", Ly.GetLink("auras.pb") == "unit.player")
T("debuffs du joueur accroches", Ly.GetLink("auras.pd") == "unit.player")
T("cible : incantation accrochee", Ly.GetLink("castbar.target") == "unit.target")
T("cible : debuffs accroches", Ly.GetLink("auras.td") == "unit.target")
T("barre 2 sur la principale", Ly.GetLink("bars.bar2") == "bars.main")
local cl0, cb0 = LB(Ly.items["castbar.player"].frame)
C.SetPos("unit.player", 600, 350)
Ly.Apply("unit.player")
local cl1, cb1b = LB(Ly.items["castbar.player"].frame)
NEAR("incantation du joueur suit le joueur (x)", cl1 - cl0, 200, 0.01)
NEAR("incantation du joueur suit le joueur (y)", cb1b - cb0, 50, 0.01)
local bl0, bb0 = LB(Ly.items["auras.pb"].frame)
C.SetPos("unit.player", 700, 360)
Ly.Apply("unit.player")
local bl1, bb1 = LB(Ly.items["auras.pb"].frame)
NEAR("buffs du joueur suivent (x)", bl1 - bl0, 100, 0.01)
NEAR("buffs du joueur suivent (y)", bb1 - bb0, 10, 0.01)
local wl0 = LB(Ly.items["auras.pw"].frame)
C.SetPos("unit.player", 760, 360)
Ly.Apply("unit.player")
NEAR("enchantements (chaine buffs -> joueur) suivent", LB(Ly.items["auras.pw"].frame) - wl0, 60, 0.01)

SECTION("t_links : Mover - parent entraine ses enfants")
C.ClearPosAll("zl.a")
C.ClearPosAll("zl.b")
C.SetPos("zl.p", 700, 500)
Ly.ResetLink("zl.a")
Ly.ResetLink("zl.b")
Ly.SetLink("zl.a", "zl.p", "BOTTOM")
Ly.SetLink("zl.b", "zl.a", "BOTTOM")
Ly.Apply("zl.p")
M.Enter()
SETTLE()
local rp, ra, rb = M.items["zl.p"], M.items["zl.a"], M.items["zl.b"]
T("poignees presentes", rp.handle ~= nil and ra.handle ~= nil and rb.handle ~= nil)
local function mouseDrag(h, x0, y0, x1, y1, hold)
  MOUSE.x, MOUSE.y, MOUSE.down = x0, y0, true
  this = h
  arg1 = "LeftButton"
  h.scripts.OnMouseDown()
  MOUSE.x, MOUSE.y = x1, y1
  Pump(0.02, 2)
  if not hold then
    MOUSE.down = false
    Pump(0.02, 1)
  end
end
C.Set("mover.snap", false)
local l0, b0 = LB(P)
local al0, ab0 = LB(A)
local bl00, bb00 = LB(B)
mouseDrag(rp.handle, l0 + 20, b0 + 20, l0 + 20 + 150, b0 + 20 + 60, true)
local al1, ab1 = LB(A)
NEAR("pendant le glissement : l'enfant suit (x)", al1 - al0, 150, 0.01)
NEAR("pendant le glissement : l'enfant suit (y)", ab1 - ab0, 60, 0.01)
local bl1b, bb1b = LB(B)
NEAR("pendant le glissement : le petit-enfant suit", bl1b - bl00, 150, 0.01)
T("pendant le glissement : rien d'enregistre pour l'enfant", C.GetPos("zl.a") == nil)
MOUSE.down = false
Pump(0.02, 1)
local l1 = C.GetPos("zl.p")
NEAR("relache : parent enregistre", l1, l0 + 150, 0.51)
al1, ab1 = LB(A)
NEAR("relache : l'enfant garde son decalage (x)", al1 - al0, 150, 0.6)
NEAR("relache : l'enfant garde son decalage (y)", ab1 - ab0, 60, 0.6)
local pa, sa = Ly.GetLink("zl.a")
EQ("relache : lien intact", pa, "zl.p")
T("un marqueur o-o relie chaque paire", M.UpdateLinks() >= 2)
T("le marqueur est affiche", M.linkMarks[1]:IsShown())
EQ("le marqueur porte le nom d'un enfant", M.linkMarks[1].rec ~= nil, true)

SECTION("t_links : Mover - deplacer un enfant ajuste son decalage")
local da, dd = Ly.GetLink("zl.a") and select(3, Ly.GetLink("zl.a")), select(4, Ly.GetLink("zl.a"))
local cl, cbb = LB(A)
mouseDrag(ra.handle, cl + 10, cbb + 5, cl + 10 + 40, cbb + 5 - 6)
local pp2, ss2, dx2, dy2 = Ly.GetLink("zl.a")
EQ("enfant deplace : toujours lie", pp2, "zl.p")
NEAR("enfant deplace : dx", dx2, da + 40, 1)
NEAR("enfant deplace : dy", dy2, dd - 6, 1)
local nl2 = LB(A)
NEAR("enfant deplace : position", nl2, cl + 40, 1)
T("l'ancien lien conseille / explicite est remplace", C.cur.pos["@zl.a>zl.p*B"] ~= nil)
-- molette (echelle) : le decalage ne bouge pas
local dxs = select(3, Ly.GetLink("zl.a"))
M.StepScale(ra, 0.1)
EQ("echelle d'un enfant : toujours lie", (Ly.GetLink("zl.a")), "zl.p")
EQ("echelle d'un enfant : meme decalage", select(3, Ly.GetLink("zl.a")), dxs)

SECTION("t_links : Mover - cote qui brille, proposition, lien")
-- X (libre) glisse contre le cote droit du parent
local pl, pb, pr, pt = M.Rect(rp)
local xl, xb, xr, xt, xw, xh = M.Rect(M.items["zl.x"])
local px_, py_ = M.Cursor()
EQ("X est libre", (Ly.GetLink("zl.x")), nil)
local xrec = M.items["zl.x"]
local fl, fb = LB(X)
-- amene le bord gauche de X a 5 unites du bord droit du parent, a mi-hauteur
local tx = pr + 5
local ty = pb + (pt - pb) / 2 - 25 * sc
mouseDrag(xrec.handle, fl + 10, fb + 10, tx + 10, ty + 10, true)
T("un cote est mis en evidence", M.glow ~= nil and M.glow:IsShown())
EQ("le cote est celui du parent", M.glow and M.glow.rec, rp)
EQ("c'est le cote droit", M.glow and M.glow.side, "RIGHT")
MOUSE.down = false
Pump(0.02, 1)
T("proposition affichee", M.prop ~= nil and M.prop:IsShown())
T("le glow est eteint au relache", not M.glow:IsShown())
CONTAINS("texte de la proposition", M.prop.text:GetText(), "Accrocher")
EQ("pas encore de lien (proposition seulement)", (Ly.GetLink("zl.x")), nil)
-- Non merci
M.prop.no:Click()
T("non merci : proposition fermee", not M.prop:IsShown())
EQ("non merci : toujours libre", (Ly.GetLink("zl.x")), nil)
-- recommence puis accepte
M.Commit(xrec, fl, fb)
mouseDrag(xrec.handle, fl + 10, fb + 10, tx + 10, ty + 10)
T("proposition a nouveau", M.prop:IsShown())
M.prop.yes:Click()
local xp, xs, xdx, xdy = Ly.GetLink("zl.x")
EQ("accepte : lie au parent", xp, "zl.p")
EQ("accepte : cote droit", xs, "RIGHT")
T("accepte : ecart principal standard", xdx == Ly.GAP)
T("proposition fermee apres acceptation", not M.prop:IsShown())
CHATCLEAR()
-- parent deplace : X suit
local xl0, xb0 = LB(X)
local pl2 = LB(P)
M.Commit(rp, pl2 + 30, (select(2, LB(P))) + 10)
local xl1, xb1 = LB(X)
NEAR("le nouvel enfant suit le parent (x)", xl1 - xl0, 30, 0.6)
NEAR("le nouvel enfant suit le parent (y)", xb1 - xb0, 10, 0.6)
-- un cadre qui dependrait de l'autre ne peut pas etre propose (cycle) : glisser le parent contre son enfant ne brille pas
local ql, qb = LB(P)
local ptgt, pside = M.LinkScan({ rec = rp, w = 200 * sc, hh = 100 * sc, fh = 100 * sc }, xl1 - 200 * sc - 3, xb1)
T("pas de cote propose contre un descendant", ptgt == nil or ptgt.id ~= "zl.x")

SECTION("t_links : Mover - tirer un enfant trop loin le detache ; symbole o-o ; menu Accroche a")
local ar0, ab00 = LB(A)
mouseDrag(ra.handle, ar0 + 10, ab00 + 5, ar0 + 10 + 700, ab00 + 5 + 500)
EQ("tire trop loin : detache", (Ly.GetLink("zl.a")), nil)
T("tire trop loin : marqueur de detachement", C.cur.pos["@zl.a>-*N"] ~= nil)
CONTAINS("tire trop loin : message", CHATTEXT(), "detache")
CHATCLEAR()
-- symbole o-o : un clic detache
M.Sync()
local mk1 = M.linkMarks[1]
T("symbole present", mk1 ~= nil and mk1:IsShown())
local who = mk1.rec.id
mk1:Click()
EQ("clic sur o-o : detache", (Ly.GetLink(who)), nil)
CONTAINS("clic sur o-o : message", CHATTEXT(), "detache")
-- menu contextuel : Accroche a ...
local function rowOf(act)
  for i = 1, table.getn(M.ctx.rows) do
    if M.ctx.rows[i].act == act then return M.ctx.rows[i] end
  end
end
this = ra.handle
arg1 = "RightButton"
ra.handle.scripts.OnMouseUp()
T("menu : action 'Accroche a'", rowOf("link") ~= nil)
CONTAINS("menu : texte 'Accroche a'", rowOf("link").label:GetText(), "Accroche a")
EQ("menu : 'Detacher' inactif (libre)", rowOf("unlink").disabled, true)
rowOf("link"):Click()
T("liste des parents ouverte", M.lkMenu ~= nil and M.lkMenu:IsShown())
EQ("liste : ctx referme", M.ctx:IsShown(), false)
EQ("liste : la capture reste", M.ctxCatcher:IsShown(), true)
local cand, seenAll = {}, {}
for page = 1, 12 do
  cand = {}
  for i = 1, M.LKROWS do
    local b = M.lkMenu.rows[i]
    if b:IsShown() and b.cand then
      cand[b.cand.id] = b
      seenAll[b.cand.id] = true
    end
  end
  if cand["zl.p"] then break end
  M.LkPage(M.lkMenu.next)
end
T("liste : contient le parent (pagination)", cand["zl.p"] ~= nil)
T("liste : ne contient pas l'enfant lui-meme", not seenAll["zl.a"])
T("liste : ne contient pas son propre descendant", not seenAll["zl.b"])
M.LkSide(M.lkMenu.sides[3])                       -- Bas
EQ("cote choisi : Bas", M.lkSide, "BOTTOM")
cand["zl.p"]:Click()
local mp, ms = Ly.GetLink("zl.a")
EQ("menu : lie au parent choisi", mp, "zl.p")
EQ("menu : cote choisi", ms, "BOTTOM")
EQ("menu : liste fermee", M.lkMenu:IsShown(), false)
EQ("menu : capture retiree", M.ctxCatcher:IsShown(), false)
CONTAINS("menu : message", CHATTEXT(), "accroche")
M.lkSide = "auto"
-- Detacher depuis le menu
this = ra.handle
arg1 = "RightButton"
ra.handle.scripts.OnMouseUp()
EQ("menu : 'Detacher' actif (lie)", rowOf("unlink").disabled, false)
rowOf("unlink"):Click()
EQ("menu : detache", (Ly.GetLink("zl.a")), nil)
-- cycle depuis le menu : refus propre
Ly.SetLink("zl.a", "zl.p", "BOTTOM")
local ok2, why2 = Ly.SetLink("zl.p", "zl.a", "BOTTOM")
EQ("menu : cycle refuse", why2, "cycle")
-- liens coupes : menu et glissement inertes
C.Set("layout.links", false)
this = ra.handle
arg1 = "RightButton"
ra.handle.scripts.OnMouseUp()
EQ("liens coupes : 'Accroche a' inactif", rowOf("link").disabled, true)
M.CloseCtx()
EQ("liens coupes : aucun symbole", M.UpdateLinks(), 0)
C.Set("layout.links", true)
-- Reinitialiser un enfant par le Mover remet le lien conseille (ou libre)
M.Reset("zl.a")
EQ("reset de l'enfant : plus de lien enregistre", C.cur.pos["@zl.a>zl.p*B"], nil)
-- sortie : tout est range
M.Exit(true)
T("sortie : symboles caches", not M.linkMarks[1]:IsShown())
T("sortie : proposition fermee", not M.prop:IsShown())
T("sortie : glow eteint", not M.glow:IsShown())
EQ("aucune erreur interne ("  .. tostring(SUI.lastErr) .. ")", SUI.errCount, e0)
C.Set("mover.snap", true)

DONE()
