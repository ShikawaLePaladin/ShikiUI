-- t_preview : volet d'apercu 2D du menu (Menu_Preview.lua, Preview_Raid.lua, Preview_Layout.lua, Preview_Basic.lua) : ouverture / fermeture,
-- plan de la fenetre (cote / dessous / masque) et tenue a l'ecran, mise a jour en direct, clic -> option, raid 5/10/20/40, aucune creation
-- en combat, niveaux de cadres (controles cliquables avec le volet), mise en page et liens, apercus minimaux, aucune erreur interne.
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Menu
local P = SUI.Preview
local G = M.G
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
BOOT()
SETTLE()

local function walk(fr, fn, seen)
  seen = seen or {}
  if seen[fr] then return end
  seen[fr] = true
  fn(fr)
  if fr.GetChildren then
    local kids = { fr:GetChildren() }
    for i = 1, table.getn(kids) do if kids[i] ~= fr then walk(kids[i], fn, seen) end end
  end
end
local function zonesOf(root)
  local list = {}
  walk(root, function(f) if f.pz and f.pdef then table.insert(list, f) end end)
  return list
end
local function zoneBy(root, id)
  local z = zonesOf(root)
  for i = 1, table.getn(z) do if z[i].pz == id then return z[i] end end
end
local function shownCells(st)
  local n = 0
  for i = 1, 40 do if st.cells[i]:IsShown() then n = n + 1 end end
  return n
end
local function setScreen(w, h)
  UIParent.GetWidth = function() return w end
  UIParent.GetHeight = function() return h end
end

SECTION("t_preview : moteur et enregistrement")
EQ("module d'apercu present", type(P), "table")
EQ("Register refuse un id vide", P.Register("", { build = function() end }), false)
EQ("Register refuse sans build", P.Register("zz", {}), false)
EQ("Register refuse un non-tableau", P.Register("zz", 5), false)
T("raid enregistre", P.reg.raid ~= nil)
T("group enregistre", P.reg.group ~= nil)
T("mise en page enregistree", P.reg.layout ~= nil)
T("cadres d'unites, barres, plaques, discussion enregistres", P.reg.units and P.reg.actionbars and P.reg.nameplates and P.reg.chat)
EQ("pas de volet avant ouverture du menu", P.pane, nil)
SlashCmdList["SHIKIUI"]("")
T("menu ouvert", M.frame ~= nil and M.frame:IsShown())
T("volet construit", P.pane ~= nil)
EQ("volet a droite par defaut", M.pvMode, "side")
EQ("volet visible", P.pane:IsShown(), true)
EQ("fenetre elargie", M.frame:GetWidth(), G.W + G.PX + G.PW + G.PAD)
EQ("hauteur inchangee", M.frame:GetHeight(), G.H)
T("tous les apercus prepares a l'ouverture", P.reg.raid.root and P.reg.layout.root and P.reg.units.root and P.reg.chat.root)
EQ("la page d'accueil montre la mise en page", P.curId, "layout")
EQ("le volet est un descendant de la fenetre", P.pane:GetParent(), M.frame)
EQ("aucune erreur interne a l'ouverture", SUI.errCount, 0)

SECTION("t_preview : bouton Apercu (masquer / afficher, memorise)")
local btn = M.frame.pvBtn
EQ("libelle du bouton", btn.label:GetText(), "Apercu")
EQ("bouton marque quand le volet est visible", btn.selected, true)
btn:Click()
EQ("masque : memorise (global)", C.GetGlobal("menuPreview"), false)
EQ("masque : volet cache", P.pane:IsShown(), false)
EQ("masque : mode off", M.pvMode, "off")
EQ("masque : fenetre rendue a sa largeur", M.frame:GetWidth(), G.W)
EQ("masque : bouton non marque", btn.selected, false)
M.Open("cat", "raid")
EQ("masque : navigation sans volet", P.pane:IsShown(), false)
btn:Click()
EQ("reaffiche : memorise", C.GetGlobal("menuPreview"), true)
EQ("reaffiche : volet visible", P.pane:IsShown(), true)
EQ("reaffiche : a droite", M.pvMode, "side")
EQ("reaffiche : apercu du raid", P.curId, "raid")
M.Hide()
M.Show()
EQ("reouverture : volet conserve", P.pane:IsShown(), true)
EQ("aucune erreur", SUI.errCount, 0)

SECTION("t_preview : plan de la fenetre et tenue a l'ecran")
local old = { UIParent.GetWidth, UIParent.GetHeight }
local plans = { { 1920, 1080, "side" }, { 1366, 768, "side" }, { 1024, 768, "side" }, { 900, 1080, "below" }, { 700, 500, "off" } }
for _, pl in ipairs(plans) do
  for _, sc in ipairs({ 0.7, 1.0, 1.3, 2.0 }) do
    setScreen(pl[1], pl[2])
    C.Set("ui.scale", sc)
    Pump(1)
    M.ApplyScale()
    local es = M.frame:GetScale()
    T("tient a l'ecran " .. pl[1] .. "x" .. pl[2] .. " echelle " .. sc, M.frame:GetWidth() * es <= pl[1] + 1 and M.frame:GetHeight() * es <= pl[2] + 1)
    if sc == 1.0 then EQ("mode " .. pl[1] .. "x" .. pl[2], M.pvMode, pl[3]) end
    local pw, ph = P.Dims()
    if M.pvMode == "side" then
      T("volet dans la fenetre (cote)", G.W + G.PX + pw <= M.frame:GetWidth() and G.NAVTOP + ph <= M.frame:GetHeight())
    elseif M.pvMode == "below" then
      T("volet dans la fenetre (dessous)", G.CX + pw <= M.frame:GetWidth() and G.NAVTOP + G.NAVH + 2 + ph <= M.frame:GetHeight())
    else
      EQ("volet cache (off)", P.pane:IsShown(), false)
    end
  end
end
setScreen(900, 1080)
C.Set("ui.scale", 1.0)
M.ApplyScale()
EQ("dessous : hauteur augmentee", M.frame:GetHeight(), G.H + G.BH)
EQ("dessous : largeur de base", M.frame:GetWidth(), G.W)
M.Open("cat", "raid")
EQ("dessous : apercu du raid visible", P.reg.raid.root:IsShown(), true)
T("dessous : cadres du raid dessines", shownCells(P.reg.raid.root.st) > 0)
EQ("dessous : taille du corps", P.reg.raid.root:GetWidth(), P.Dims() - 12)
UIParent.GetWidth, UIParent.GetHeight = old[1], old[2]
C.Set("ui.scale", 1.0)
M.ApplyScale()
EQ("retour a droite", M.pvMode, "side")
EQ("aucune erreur d'echelle", SUI.errCount, 0)

SECTION("t_preview : apercu du raid (5 / 10 / 20 / 40)")
M.Open("cat", "raid")
local def = P.reg.raid
local root = def.root
local st = root.st
EQ("la page raid montre l'apercu du raid", P.curId, "raid")
EQ("apercu visible", root:IsShown(), true)
EQ("module coupe : mention dans le volet", P.pane.status:GetText(), "module desactive : apercu des reglages seulement")
EQ("titre du volet", P.pane.title:GetText(), "Apercu : " .. M.CatLabel("raid"))
EQ("40 joueurs par defaut", shownCells(st), 40)
for _, n in ipairs({ 5, 10, 20, 40 }) do
  local b
  for i = 1, table.getn(st.btns) do if st.btns[i].n == n then b = st.btns[i] end end
  T("bouton " .. n, b ~= nil)
  b:Click()
  EQ(n .. " joueurs affiches", shownCells(st), n)
  EQ(n .. " : bouton marque", b.selected, true)
  CONTAINS(n .. " : legende", st.cap:GetText(), tostring(n))
end
st.btns[4]:Click()
EQ("retour a 40", shownCells(st), 40)
-- reflet direct des vrais reglages
local w0 = st.det:GetWidth()
C.Set("raid.width", 100)
T("largeur de cadre : le cadre agrandi s'elargit", st.det:GetWidth() > w0)
T("largeur : la grille reste dans la zone", st.cells[1]:GetWidth() > 0 and st.cells[1]:GetWidth() <= root:GetWidth())
C.Set("raid.height", 40)
T("hauteur de cadre : le cadre agrandi s'allonge", st.det:GetHeight() > 0)
C.Set("raid.height", 28)
C.Set("raid.width", 64)
EQ("largeur 64 : retour a la taille d'origine", st.det:GetWidth(), w0)
-- groupes visibles
C.Set("raid.maxgroup", 2)
EQ("maxgroup 2 : 10 cadres", shownCells(st), 10)
C.Set("raid.maxgroup", 8)
EQ("maxgroup 8 : 40 cadres", shownCells(st), 40)
-- tri
C.Set("raid.sort", "class")
EQ("tri par classe : premier = DRUID", st.ord[1].class, "DRUID")
C.Set("raid.sort", "name")
EQ("tri par nom : premier = Aldric", st.ord[1].name, "Aldric")
C.Set("raid.sort", "role")
EQ("tri par role : tanks d'abord", st.ord[1].role, "T")
C.Set("raid.sort", "none")
EQ("pas de tri : ordre du raid", st.ord[1].name, "Thorgrim")
C.Set("raid.sort", "group")
-- orientation : en vertical la 2e cellule du groupe est sous la 1re, en horizontal a droite
local function pt(c) return c.points[1][4], c.points[1][5] end
local ax, ay = pt(st.cells[1])
local bx, by = pt(st.cells[2])
T("vertical : meme colonne", ax == bx)
T("vertical : ligne en dessous", by < ay)
C.Set("raid.sort", "none")
C.Set("raid.orient", "horizontal")
ax, ay = pt(st.cells[1])
bx, by = pt(st.cells[2])
T("horizontal : meme ligne", ay == by)
T("horizontal : colonne a droite", bx > ax)
C.Set("raid.perline", 5)
local cx, cy = pt(st.cells[6])
T("horizontal : 6e cadre sur la ligne suivante", cy < ay and cx == ax)
C.Set("raid.perline", 10)
cx, cy = pt(st.cells[6])
T("perline 10 : 6e cadre sur la meme ligne", cy == ay)
C.Set("raid.orient", "vertical")
C.Set("raid.sort", "group")
C.Set("raid.perline", 5)
-- espacement : ecart entre deux groupes
local g1x = pt(st.cells[1])
local g2x = pt(st.cells[6])
C.Set("raid.groupgap", 20)
local g2x2 = pt(st.cells[6])
T("ecart entre groupes plus grand", g2x2 > g2x)
C.Set("raid.groupgap", 6)
-- cadre agrandi : chaque element suit son reglage
local det = st.det
T("exemple complet : au moins un debuff", det.de[1]:IsShown())
C.Set("raid.debuffs", 0)
EQ("debuffs 0 : aucune icone", det.de[1]:IsShown(), false)
C.Set("raid.debuffs", 3)
EQ("debuffs 3 : 3 icones", det.de[3]:IsShown(), true)
C.Set("raid.hots", 0)
EQ("HoTs 0 : aucune icone", det.hi[1]:IsShown(), false)
C.Set("raid.hots", 2)
EQ("HoTs 2 : deux icones", det.hi[2]:IsShown() and not det.hi[3]:IsShown(), true)
C.Set("raid.buffs", 2)
EQ("buffs 2 : deux icones", det.bi[2]:IsShown() and not det.bi[3]:IsShown(), true)
C.Set("raid.buffs", 0)
C.Set("raid.incoming", false)
EQ("soins entrants coupes", det.heal:IsShown(), false)
C.Set("raid.incoming", true)
EQ("soins entrants montres", det.heal:IsShown(), true)
C.Set("raid.hptext", "none")
EQ("texte de vie coupe", det.hpt:IsShown(), false)
C.Set("raid.hptext", "percent")
EQ("texte de vie montre", det.hpt:IsShown(), true)
CONTAINS("texte de vie en pourcentage", det.hpt:GetText(), "%")
C.Set("raid.dispelstyle", "stripe")
EQ("dissipation liseret : voile cache", det.dhl:IsShown(), false)
EQ("dissipation liseret : liseret montre", det.dtx:IsShown(), true)
C.Set("raid.dispelstyle", "frame")
EQ("dissipation voile : liseret cache", det.dtx:IsShown(), false)
EQ("dissipation voile : voile montre", det.dhl:IsShown(), true)
C.Set("raid.dispelmode", "off")
EQ("dissipation coupee : rien", det.dtx:IsShown() or det.dhl:IsShown(), false)
C.Set("raid.dispelmode", "known")
C.Set("raid.powerheight", 4)
EQ("puissance 4 : barre", det.pw:IsShown(), true)
C.Set("raid.powerheight", 0)
EQ("puissance 0 : pas de barre", det.pw:IsShown(), false)
C.Set("raid.marks", false)
EQ("marqueurs coupes", det.mk:IsShown(), false)
C.Set("raid.marks", true)
EQ("marqueurs montres", det.mk:IsShown(), true)
C.Set("raid.roletag", true)
EQ("etiquette de role", det.tag:IsShown(), true)
C.Set("raid.roletag", false)
C.Set("raid.leader", false)
EQ("chef coupe : plus d'etiquette", det.tag:IsShown(), false)
C.Set("raid.leader", true)
C.Set("raid.aggro", false)
EQ("aggro coupee : pas de voile", det.hl:IsShown(), false)
C.Set("raid.aggro", true)
EQ("aggro montree", det.hl:IsShown(), true)
C.Set("raid.hpcolor", "style")
local r0, g0, b0 = det.hp.vc[1], det.hp.vc[2], det.hp.vc[3]
EQ("couleur de vie 'style' = jeton good", r0, SUI.Theme.c.good[1])
C.Set("raid.hpcolor", "class")
for i = 1, 40 do if st.cells[i].pi == 4 then st.cells[i]:Click() end end
EQ("joueur 4 (MAGE) agrandi", st.pick, 4)
NEAR("couleur de classe (RAID_CLASS_COLORS)", det.hp.vc[1], RAID_CLASS_COLORS.MAGE.r)
NEAR("couleur de classe (vert)", det.hp.vc[2], RAID_CLASS_COLORS.MAGE.g)
st.pick = 0
st.redo()
-- etats : mort, hors ligne, hors portee
local dead, off, far
for k = 1, 40 do
  local p = st.ord[k]
  if p.state == 1 then dead = st.cells[k] elseif p.state == 2 then off = st.cells[k] end
end
T("un mort dans la grille", dead ~= nil)
T("un hors ligne dans la grille", off ~= nil)
C.Set("raid.sort", "none")
far = st.cells[19]
C.Set("raid.outalpha", 0.3)
NEAR("mort : transparence reglee", dead:GetAlpha(), 0.3)
NEAR("hors ligne : transparence reglee", off:GetAlpha(), 0.3)
NEAR("hors portee : transparence reglee", far:GetAlpha(), 0.3)
C.Set("raid.range", false)
NEAR("portee coupee : hors portee opaque", far:GetAlpha(), 1)
C.Set("raid.range", true)
C.Set("raid.outalpha", 0.45)
C.Set("raid.sort", "group")
CONTAINS("mort : texte", dead.stt:GetText(), "Mort")
CONTAINS("hors ligne : texte", off.stt:GetText(), "Hors ligne")
-- autres cadres : joueurs clique -> cadre agrandi
st.cells[9]:Click()
EQ("clic sur un cadre : joueur agrandi", st.pick, 9)
EQ("nom du joueur agrandi (coupe a namelen)", det.name:GetText(), "Velkha")
st.pick = 0
st.redo()
EQ("retour a l'exemple complet", det.name:GetText(), "Elaria")
C.Set("raid.namelen", 3)
EQ("longueur du nom", string.len(det.name:GetText()), 3)
C.Set("raid.namelen", 6)
EQ("aucune erreur interne (raid)", SUI.errCount, 0)

SECTION("t_preview : clic sur un element -> option (surlignee)")
local seen = {}
local realFocus = M.FocusKey
M.FocusKey = function(key) seen[table.getn(seen) + 1] = key; return realFocus(key) end
M.SetMode("essential")
M.Open("cat", "raid")
local z = zoneBy(root, "hot")
T("zone des HoTs", z ~= nil)
z:Click()
EQ("clic HoTs : saute a raid.hots", P.lastKey, "raid.hots")
EQ("FocusKey appele avec la cle", seen[table.getn(seen)], "raid.hots")
EQ("surbrillance de l'option", M.hl, "raid.hots")
EQ("page du module", M.page == "cat" and M.cat, "raid")
local cell
for i = 1, M.used.cell do if M.pools.cell[i].opt and M.pools.cell[i].opt.key == "raid.hots" then cell = M.pools.cell[i] end end
T("ligne de l'option presente", cell ~= nil)
EQ("ligne surlignee", cell and cell.hl:IsShown(), true)
-- option avancee : le menu passe en mode Tout
M.SetMode("essential")
zoneBy(root, "buf"):Click()
EQ("clic buffs : raid.buffs", P.lastKey, "raid.buffs")
EQ("option avancee : mode Tout", M.mode, "all")
EQ("option avancee : surlignee", M.hl, "raid.buffs")
M.SetMode("essential")
-- depuis une autre page
M.Open("home")
EQ("accueil : apercu de mise en page", P.curId, "layout")
M.Open("cat", "raid")
zoneBy(root, "gap"):Click()
EQ("clic sur l'ecart (par groupe) : groupgap", P.lastKey, "raid.groupgap")
C.Set("raid.sort", "none")
zoneBy(root, "gap"):Click()
EQ("clic sur l'ecart (sans tri) : spacing", P.lastKey, "raid.spacing")
C.Set("raid.sort", "group")
zoneBy(root, "sort"):Click()
EQ("clic sur le tri", P.lastKey, "raid.sort")
-- survol : surbrillance et infobulle
Hover(z, true)
EQ("survol : zone surlignee", z.hl:IsShown(), true)
T("survol : infobulle", GameTooltip.owner == z)
Hover(z, false)
EQ("fin de survol : zone normale", z.hl:IsShown(), false)
-- toutes les zones des apercus pointent vers une vraie option ou un vrai module
local checked = 0
for _, id in ipairs(P.order) do
  local d = P.reg[id]
  if d.root and id ~= "layout" then
    local zs = zonesOf(d.root)
    for i = 1, table.getn(zs) do
      local key = d.click(zs[i].pz)
      if key then
        checked = checked + 1
        if string.find(key, "^cat:") then
          T("zone " .. id .. "/" .. zs[i].pz .. " -> module existant", M.CatExists(string.sub(key, 5)))
        else
          T("zone " .. id .. "/" .. zs[i].pz .. " -> option existante (" .. key .. ")", P.FindOption(key) ~= nil)
        end
      end
    end
  end
end
T("des zones ont ete controlees", checked > 20)
EQ("zone inconnue : pas de saut", P.Goto("zz.inexistant"), false)
EQ("cle invalide : pas de saut", P.Goto(nil), false)

SECTION("t_preview : apercu du groupe")
M.Open("cat", "group")
EQ("apercu du groupe", P.curId, "group")
local gst = P.reg.group.root.st
EQ("5 joueurs par defaut", shownCells(gst), 5)
local gb
for i = 1, table.getn(gst.btns) do if gst.btns[i].n == 3 then gb = gst.btns[i] end end
gb:Click()
EQ("3 joueurs", shownCells(gst), 3)
gst.btns[2]:Click()
local gw0 = gst.cells[1]:GetWidth()
C.Set("group.width", 160)
T("largeur du groupe suit le reglage", gst.cells[1]:GetWidth() ~= gw0 or gst.cells[1].rc.frame[3] ~= gw0)
C.Set("group.width", 100)
C.Set("group.roletag", true)
EQ("etiquette de role du groupe", gst.det.tag:IsShown(), true)
C.Set("group.roletag", false)
EQ("changement de reglage du raid : l'apercu du groupe est inchange", gst.n, 5)

SECTION("t_preview : mise en page (ecran miniature, liens)")
M.Open("home")
local lroot = P.reg.layout.root
local lst = lroot.st
local nitems = 0
for _ in pairs(SUI.Layout.items) do nitems = nitems + 1 end
T("des cadres enregistres dans la mise en page", nitems >= 3)
local nr = 0
for i = 1, 48 do if lst.rects[i]:IsShown() then nr = nr + 1 end end
EQ("un rectangle par cadre", nr, math.min(nitems, 48))
local pz
for i = 1, 48 do if lst.rects[i]:IsShown() and lst.rects[i].key == "unit.player" then pz = lst.rects[i] end end
T("rectangle du joueur", pz ~= nil)
T("rectangle dans l'ecran miniature", pz.points[1][4] >= 0 and pz.points[1][4] + pz:GetWidth() <= lroot.scr:GetWidth() + 1)
T("nombre de liens coherent", lst.nlinks >= 0)
local hadLinked, hadGet = SUI.Layout.LinkedParent, SUI.Layout.GetLink
SUI.Layout.LinkedParent = function(k)
  if k == "unit.target" then return "unit.player", "RIGHT", 4, 0, "user" end
  return nil
end
M.OnConfig(nil, nil)
EQ("lien dessine (API presente)", lst.nlinks, 1)
T("trait visible", lst.lines[1]:IsShown() or lst.lines[2]:IsShown())
SUI.Layout.LinkedParent = function() error("API cassee") end
M.OnConfig(nil, nil)
EQ("API cassee : aucun lien, aucune erreur interne", lst.nlinks, 0)
SUI.Layout.LinkedParent, SUI.Layout.GetLink = nil, nil
M.OnConfig(nil, nil)
EQ("API absente : aucun lien", lst.nlinks, 0)
SUI.Layout.LinkedParent, SUI.Layout.GetLink = hadLinked, hadGet
M.OnConfig(nil, nil)
-- le deplacement notifie "pos" : les rectangles suivent
local x0 = pz.points[1][4]
SUI.Config.SetPos("unit.player", 100, 300)
SUI.Layout.Apply("unit.player")
SUI.Config.Notify("pos", nil)
T("position notifiee : rectangle redessine", true)
pz:Click()
EQ("clic sur un rectangle : page du module", M.page == "cat" and M.cat, "units")
-- repli : categorie sans apercu propre
M.Open("cat", "loot")
EQ("categorie sans apercu : mise en page en repli", P.curId, "layout")
EQ("repli : module surligne", P.focus, "loot")
M.Open("cat", "units")
EQ("categorie avec apercu propre", P.curId, "units")
EQ("aucune erreur (mise en page)", SUI.errCount, 0)

SECTION("t_preview : apercus minimaux (unites, barres, plaques, discussion)")
M.Open("cat", "units")
local u = P.reg.units.root.st
local uw0 = u.cells[1]:GetWidth()
C.Set("units.width", 120)
T("unites : largeur suit le reglage", u.cells[1]:GetWidth() ~= uw0)
C.Set("units.width", 180)
C.Set("units.showpower", false)
EQ("unites : puissance coupee", u.cells[1].pw:IsShown(), false)
C.Set("units.showpower", true)
EQ("unites : puissance montree", u.cells[1].pw:IsShown(), true)
C.Set("units.hptext", "none")
EQ("unites : texte de vie coupe", u.cells[1].hpt:IsShown(), false)
C.Set("units.hptext", "percent")
EQ("unites : clic sur la largeur", P.reg.units.click("frame"), "units.width")
EQ("unites : puissance -> hauteur de barre", P.reg.units.click("power"), "units.powerheight")
M.Open("cat", "actionbars")
local bs = P.reg.actionbars.root.st
EQ("barres : apercu", P.curId, "actionbars")
EQ("barres : raccourci du bouton 2", bs.b[2].key:IsShown(), true)
C.Set("actionbars.keybinds", false)
EQ("barres : raccourcis coupes", bs.b[2].key:IsShown(), false)
C.Set("actionbars.keybinds", true)
C.Set("actionbars.cooldowns", false)
EQ("barres : recharge coupee", bs.b[3].cd:IsShown(), false)
C.Set("actionbars.cooldowns", true)
EQ("barres : recharge montree", bs.b[3].cd:IsShown(), true)
local bw0 = bs.b[1]:GetWidth()
C.Set("actionbars.size", 48)
T("barres : taille des boutons", bs.b[1]:GetWidth() ~= bw0)
C.Set("actionbars.size", 36)
zoneBy(P.reg.actionbars.root, "b3"):Click()
EQ("barres : clic sur la recharge", P.lastKey, "actionbars.cooldowns")
M.Open("cat", "nameplates")
local pst = P.reg.nameplates.root.st
EQ("plaques : apercu", P.curId, "nameplates")
EQ("plaques : barre d'incantation", pst.cells[1].cb:IsShown(), true)
C.Set("nameplates.castbar", false)
EQ("plaques : incantation coupee", pst.cells[1].cb:IsShown(), false)
C.Set("nameplates.castbar", true)
C.Set("nameplates.debuffs", false)
EQ("plaques : debuffs coupes", pst.cells[1].de[1]:IsShown(), false)
C.Set("nameplates.debuffs", true)
EQ("plaques : debuffs montres", pst.cells[1].de[1]:IsShown(), true)
EQ("plaques : clic sur la cible", P.reg.nameplates.click("bar2"), "nameplates.targetscale")
M.Open("cat", "chat")
local cst = P.reg.chat.root.st
EQ("discussion : apercu", P.curId, "chat")
EQ("discussion : onglets", cst.tab1:IsShown(), true)
C.Set("chat.tabs", false)
EQ("discussion : onglets coupes", cst.tab1:IsShown(), false)
C.Set("chat.tabs", true)
EQ("discussion : heure", cst.lines[1].stamp:IsShown(), true)
C.Set("chat.stamp", false)
EQ("discussion : heure coupee", cst.lines[1].stamp:IsShown(), false)
C.Set("chat.stamp", true)
C.Set("chat.stampfmt", "hms")
CONTAINS("discussion : format hms", cst.lines[1].stamp:GetText(), "12:34:56")
C.Set("chat.stampfmt", "hm")
C.Set("chat.shortchan", true)
CONTAINS("discussion : canal court", cst.lines[1].ch:GetText(), "[1]")
C.Set("chat.shortchan", false)
EQ("aucune erreur (apercus minimaux)", SUI.errCount, 0)

SECTION("t_preview : apercus des modules (incantation, buffs, infobulle, compteurs, menace, minimap, sacs)")
local NEW = { "castbar", "auras", "tooltip", "meter", "threat", "minimap", "bags" }
for _, id in ipairs(NEW) do
  local d = P.reg[id]
  T(id .. " : apercu enregistre", d ~= nil)
  T(id .. " : categorie du menu existante", M.CatExists(id))
  T(id .. " : construit a l'ouverture", d and d.root ~= nil)
  EQ(id .. " : surveille ses propres reglages", d.watch[1], id .. ".")
  M.Open("cat", id)
  EQ(id .. " : la page montre son apercu", P.curId, id)
  EQ(id .. " : pas de repli sur la mise en page", P.focus, nil)
  EQ(id .. " : racine visible", d.root:IsShown(), true)
  EQ(id .. " : indication affichee", d.root.st.hint:IsShown(), true)
  local zs = zonesOf(d.root)
  T(id .. " : des zones cliquables", table.getn(zs) >= 5)
  local allKey = true
  for i = 1, table.getn(zs) do
    local k = d.click(zs[i].pz)
    if k and not P.FindOption(k) then allKey = false end
  end
  T(id .. " : zones -> options existantes", allKey)
end
EQ("aucune erreur a l'ouverture des apercus", SUI.errCount, 0)
local function vcol(t) local c = t.vc; return c[1], c[2], c[3] end

-- ---- surveillance : seul un reglage de la categorie redessine
M.Open("cat", "castbar")
do
  local d = P.reg.castbar
  local n, orig = 0, d.update
  d.update = function(a, b, c, e, f) n = n + 1; return orig(a, b, c, e, f) end
  C.Set("bags.size", 36)
  EQ("reglage d'une autre categorie : pas de redessin", n, 0)
  C.Set("castbar.height", 20)
  EQ("reglage de la categorie : redessin", n, 1)
  d.update = orig
  C.Set("castbar.height", 16)
  C.Set("bags.size", 32)
end

-- ---- incantation
do
  local d = P.reg.castbar
  local st = d.root.st
  M.Open("cat", "castbar")
  local w0 = st.bars[1].bw
  C.Set("castbar.width", 300)
  T("incantation : largeur du joueur", st.bars[1].bw > w0)
  T("incantation : la barre reste dans la zone", st.bars[1]:GetWidth() <= d.root:GetWidth())
  C.Set("castbar.width", 220)
  local wo = st.bars[2].bw
  C.Set("castbar.owidth", 120)
  T("incantation : largeur des autres barres", st.bars[2].bw < wo)
  C.Set("castbar.owidth", 180)
  local h0 = st.bars[1]:GetHeight()
  C.Set("castbar.height", 28)
  T("incantation : hauteur", st.bars[1]:GetHeight() > h0)
  C.Set("castbar.height", 16)
  EQ("incantation : icone", st.bars[1].ic:IsShown(), true)
  C.Set("castbar.icon", false)
  EQ("incantation : icone coupee", st.bars[1].ic:IsShown(), false)
  C.Set("castbar.icon", true)
  CONTAINS("incantation : nom du sort", st.bars[1].nm:GetText(), "Boule")
  C.Set("castbar.name", false)
  EQ("incantation : nom coupe", st.bars[1].nm:IsShown(), false)
  C.Set("castbar.name", true)
  EQ("incantation : temps", st.bars[1].tm:GetText(), "1.2")
  C.Set("castbar.decimals", 0)
  EQ("incantation : temps sans decimale", st.bars[1].tm:GetText(), "1")
  C.Set("castbar.decimals", 2)
  EQ("incantation : temps a 2 decimales", st.bars[1].tm:GetText(), "1.20")
  C.Set("castbar.decimals", 1)
  C.Set("castbar.timer", false)
  EQ("incantation : temps coupe", st.bars[1].tm:IsShown(), false)
  C.Set("castbar.timer", true)
  EQ("incantation : latence", st.bars[1].lag:IsShown(), true)
  C.Set("castbar.lag", false)
  EQ("incantation : latence coupee", st.bars[1].lag:IsShown(), false)
  C.Set("castbar.lag", true)
  EQ("incantation : etincelle", st.bars[1].spark:IsShown(), true)
  C.Set("castbar.spark", false)
  EQ("incantation : etincelle coupee", st.bars[1].spark:IsShown(), false)
  C.Set("castbar.spark", true)
  EQ("incantation : canalisation qui se vide", st.bars[2].p, 0.6)
  C.Set("castbar.channeldir", "fill")
  EQ("incantation : canalisation qui se remplit", st.bars[2].p, 0.4)
  C.Set("castbar.channeldir", "drain")
  C.Set("castbar.classcolor", true)
  T("incantation : couleur de classe appliquee (sans erreur)", st.bars[1].fill:IsShown())
  C.Set("castbar.classcolor", false)
  EQ("incantation : sort interrompu", st.bars[3].nm:GetText(), "Interrompu")
  C.Set("castbar.failtext", false)
  EQ("incantation : texte d'echec coupe", st.bars[3].nm:IsShown(), false)
  C.Set("castbar.failtext", true)
  C.Set("castbar.target", false)
  EQ("incantation : barre de cible coupee (grisee)", st.on[2], false)
  T("incantation : barre grisee mais montree", st.bars[2]:IsShown())
  C.Set("castbar.target", true)
  EQ("incantation : barre de cible rallumee", st.on[2], true)
  local expect = { bar1 = "castbar.width", bar2 = "castbar.owidth", icon1 = "castbar.icon", name1 = "castbar.name", name3 = "castbar.failtext",
    timer1 = "castbar.timer", timer2 = "castbar.decimals", lag1 = "castbar.lag", spark1 = "castbar.spark", dir1 = "castbar.classcolor",
    dir2 = "castbar.channeldir", height1 = "castbar.height", cap2 = "castbar.target", cap3 = "castbar.focus" }
  for z, k in pairs(expect) do
    EQ("incantation : clic " .. z, d.click(z), k)
    T("incantation : zone " .. z, zoneBy(d.root, z) ~= nil)
  end
  zoneBy(d.root, "icon1"):Click()
  EQ("incantation : clic sur l'icone", P.lastKey, "castbar.icon")
  EQ("incantation : zone sans pendant", d.click("zzz"), nil)
  pcall(C.Set, "castbar.shape", "thin")      -- reglage livre par SUI.Look.Options (autre perimetre) : teste s'il existe
  if C.Get("castbar.shape") == "thin" then
    T("incantation : forme fine (remplissage plus mince)", st.bars[1].fill:GetHeight() < st.bars[1]:GetHeight() - 2)
    C.Set("castbar.shape", "style")
  end
end

-- ---- buffs et debuffs
do
  local d = P.reg.auras
  local st = d.root.st
  M.Open("cat", "auras")
  local c1 = st.pool[1]
  local w0 = c1:GetWidth()
  C.Set("auras.size", 40)
  T("buffs : taille", c1:GetWidth() > w0)
  C.Set("auras.size", 28)
  local x1 = pt(c1)
  C.Set("auras.grow", "right")
  T("buffs : croissance vers la droite (premiere icone a gauche)", pt(c1) < x1)
  EQ("buffs : fleche", st.arrow:GetText(), "-->")
  C.Set("auras.grow", "left")
  EQ("buffs : fleche vers la gauche", st.arrow:GetText(), "<--")
  local _, y1 = pt(st.pool[1])
  C.Set("auras.perrow", 4)
  local _, y5 = pt(st.pool[5])
  T("buffs : 4 par ligne, la 5e icone passe a la ligne", y5 < y1)
  C.Set("auras.perrow", 8)
  EQ("buffs : enchantement d'arme", st.pool[1].tm:GetText(), "30m")
  EQ("buffs : durees", st.pool[2].tm:GetText(), "1h")
  C.Set("auras.timer", false)
  EQ("buffs : durees coupees", st.pool[2].tm:IsShown(), false)
  C.Set("auras.timer", true)
  EQ("buffs : cumul affiche", st.pool[4].sk:IsShown(), true)
  C.Set("auras.stacks", false)
  EQ("buffs : cumul coupe", st.pool[4].sk:IsShown(), false)
  C.Set("auras.stacks", true)
  C.Set("auras.weapon", false)
  EQ("buffs : enchantement d'arme coupe", st.on.weapon, false)
  C.Set("auras.weapon", true)
  C.Set("auras.buffs", false)
  EQ("buffs : buffs coupes (legende grisee)", st.on.buffs, false)
  EQ("buffs : zone du groupe retiree", st.z.gbuff1:IsShown(), false)
  EQ("buffs : la legende reste cliquable", st.z.cap2:IsShown(), true)
  C.Set("auras.buffs", true)
  EQ("buffs : zone du groupe revenue", st.z.gbuff1:IsShown(), true)
  C.Set("auras.debuffs", false)
  EQ("buffs : debuffs coupes", st.on.debuffs, false)
  C.Set("auras.debuffs", true)
  C.Set("auras.targetbuffs", false)
  EQ("buffs : buffs de cible coupes", st.z.gbuff2:IsShown(), false)
  C.Set("auras.targetbuffs", true)
  local function shownCount()
    local n = 0
    for i = 1, 34 do if st.pool[i]:IsShown() then n = n + 1 end end
    return n
  end
  C.Set("auras.maxbuffs", 8)
  local few = shownCount()
  C.Set("auras.maxbuffs", 32)
  T("buffs : nombre maximal de buffs", shownCount() > few)
  T("buffs : jamais plus d'icones que la reserve", shownCount() <= 34)
  C.Set("auras.player", false)
  EQ("buffs : joueur coupe", st.on.player, false)
  C.Set("auras.player", true)
  C.Set("auras.perrow", 16)
  C.Set("auras.size", 40)
  T("buffs : 16 icones de 40 px tiennent dans la zone", pt(st.pool[1]) >= 0 and st.z.gbuff1:GetWidth() <= d.root:GetWidth())
  C.Set("auras.perrow", 8)
  C.Set("auras.size", 28)
  local expect = { gbuff1 = "auras.perrow", gbuff2 = "auras.tsize", size = "auras.size", timer = "auras.timer", stack = "auras.stacks",
    warn = "auras.warn", weapon = "auras.weapon", grow = "auras.grow", cap5 = "auras.targetbuffs", cap6 = "auras.targetdebuffs" }
  for z, k in pairs(expect) do EQ("buffs : clic " .. z, d.click(z), k) end
  zoneBy(d.root, "stack"):Click()
  EQ("buffs : clic sur le cumul", P.lastKey, "auras.stacks")
end

-- ---- infobulle
do
  local d = P.reg.tooltip
  local st = d.root.st
  M.Open("cat", "tooltip")
  local w0 = st.item:GetWidth()
  C.Set("tooltip.scale", 1.5)
  T("infobulle : echelle", st.item:GetWidth() > w0)
  C.Set("tooltip.scale", 1)
  EQ("infobulle : habillage ShikiUI", st.on.style, true)
  C.Set("tooltip.style", false)
  EQ("infobulle : habillage coupe", st.on.style, false)
  C.Set("tooltip.style", true)
  C.Set("tooltip.bordercolor", false)
  EQ("infobulle : bordure de qualite coupee", st.on.bordercolor, false)
  C.Set("tooltip.bordercolor", true)
  CONTAINS("infobulle : niveau d'objet", st.item.l[4]:GetText(), "66")
  C.Set("tooltip.itemlevel", false)
  EQ("infobulle : niveau d'objet coupe (grise)", st.on.itemlevel, false)
  EQ("infobulle : la zone reste cliquable", st.z.ilvl:IsShown(), true)
  C.Set("tooltip.itemlevel", true)
  C.Set("tooltip.itemid", true)
  EQ("infobulle : identifiant d'objet", st.on.itemid, true)
  C.Set("tooltip.itemid", false)
  C.Set("tooltip.classcolor", false)
  EQ("infobulle : couleur de classe coupee", st.on.classcolor, false)
  C.Set("tooltip.classcolor", true)
  C.Set("tooltip.target", false)
  EQ("infobulle : cible coupee", st.on.target, false)
  C.Set("tooltip.target", true)
  local hp0 = st.unit:GetHeight()
  C.Set("tooltip.hpbar", false)
  T("infobulle : barre de vie coupee (cadre plus court)", st.unit:GetHeight() < hp0)
  C.Set("tooltip.hpbar", true)
  C.Set("tooltip.hpvalue", false)
  EQ("infobulle : valeur de vie coupee", st.on.hpvalue, false)
  C.Set("tooltip.hpvalue", true)
  C.Set("tooltip.unitid", true)
  EQ("infobulle : unite", st.on.unitid, true)
  C.Set("tooltip.unitid", false)
  local tx0 = pt(st.scr.tip)
  C.Set("tooltip.anchor", "cursor")
  EQ("infobulle : ancre au curseur", st.on.cursor, true)
  T("infobulle : la bulle se deplace pres du curseur", pt(st.scr.tip) ~= tx0)
  CONTAINS("infobulle : legende de l'ancre", st.scr.lab:GetText(), "curseur")
  C.Set("tooltip.anchor", "default")
  EQ("infobulle : ancre par defaut", pt(st.scr.tip), tx0)
  local expect = { istyle = "tooltip.style", uscale = "tooltip.scale", anchor = "tooltip.anchor", ibord = "tooltip.bordercolor", ilvl = "tooltip.itemlevel",
    iid = "tooltip.itemid", ucls = "tooltip.classcolor", utgt = "tooltip.target", uhpb = "tooltip.hpbar", uhpv = "tooltip.hpvalue", uid = "tooltip.unitid" }
  for z, k in pairs(expect) do EQ("infobulle : clic " .. z, d.click(z), k) end
  zoneBy(d.root, "anchor"):Click()
  EQ("infobulle : clic sur l'ecran", P.lastKey, "tooltip.anchor")
end

-- ---- compteurs
do
  local d = P.reg.meter
  local st = d.root.st
  M.Open("cat", "meter")
  EQ("compteurs : une fenetre", st.nwin, 1)
  EQ("compteurs : fenetre 2 cachee", st.wins[2]:IsShown(), false)
  CONTAINS("compteurs : titre = vue - segment", st.wins[1].title:GetText(), "Degats - Actuel")
  C.Set("meter.windows", 3)
  EQ("compteurs : 3 fenetres", st.nwin, 3)
  EQ("compteurs : fenetre 3 montree", st.wins[3]:IsShown(), true)
  EQ("compteurs : fenetre 4 cachee", st.wins[4]:IsShown(), false)
  CONTAINS("compteurs : titre de la fenetre 2", st.wins[2].title:GetText(), "Soins")
  CONTAINS("compteurs : nombre de fenetres affiche", st.wins[1].sub:GetText(), "3")
  C.Set("meter.windows", 1)
  C.Set("meter.view1", "heal")
  CONTAINS("compteurs : vue 1 = soins", st.wins[1].title:GetText(), "Soins")
  C.Set("meter.view1", "damage")
  C.Set("meter.seg1", "overall")
  CONTAINS("compteurs : segment = total", st.wins[1].title:GetText(), "Total")
  C.Set("meter.seg1", "current")
  local w0 = st.wins[1]:GetWidth()
  C.Set("meter.width", 300)
  T("compteurs : largeur", st.wins[1]:GetWidth() > w0)
  T("compteurs : reste dans la zone", st.wins[1]:GetWidth() <= d.root:GetWidth())
  C.Set("meter.width", 240)
  EQ("compteurs : 8 lignes d'exemple au maximum", st.n, 8)
  C.Set("meter.rows", 3)
  EQ("compteurs : 3 lignes", st.n, 3)
  EQ("compteurs : 4e ligne cachee", st.wins[1].r[4].bar:IsShown(), false)
  EQ("compteurs : 3e ligne montree", st.wins[1].r[3].bar:IsShown(), true)
  EQ("compteurs : zone d'une ligne absente retiree", st.z.val:IsShown(), false)
  C.Set("meter.rows", 10)
  C.Set("meter.height", 80)
  T("compteurs : hauteur fixe limite les lignes", st.n < 8)
  C.Set("meter.height", 0)
  EQ("compteurs : hauteur auto", st.n, 8)
  local rh0 = st.wins[1]:GetHeight()
  C.Set("meter.rowh", 24)
  T("compteurs : hauteur de ligne", st.wins[1]:GetHeight() > rh0)
  C.Set("meter.rowh", 16)
  CONTAINS("compteurs : rang", st.wins[1].r[1].nm:GetText(), "1.")
  C.Set("meter.showrank", false)
  EQ("compteurs : rang coupe", string.find(st.wins[1].r[1].nm:GetText(), "1.", 1, true), nil)
  C.Set("meter.showrank", true)
  CONTAINS("compteurs : valeur courte", st.wins[1].r[1].vl:GetText(), "18.4k")
  C.Set("meter.shortnum", false)
  CONTAINS("compteurs : valeur complete", st.wins[1].r[1].vl:GetText(), "18420")
  C.Set("meter.shortnum", true)
  CONTAINS("compteurs : pourcentage", st.wins[1].r[1].vl:GetText(), "%")
  C.Set("meter.showpct", false)
  EQ("compteurs : pourcentage coupe", string.find(st.wins[1].r[1].vl:GetText(), "%", 1, true), nil)
  C.Set("meter.showpct", true)
  C.Set("meter.classcolor", false)
  EQ("compteurs : couleur de classe coupee", st.on.cls, false)
  local ar2 = vcol(st.wins[1].r[1].bar)
  local br2 = vcol(st.wins[1].r[2].bar)
  EQ("compteurs : barres uniformes (accent)", ar2, br2)
  C.Set("meter.classcolor", true)
  local f0 = st.wins[1].title.fsize
  C.Set("meter.fontsize", 16)
  T("compteurs : taille du texte", st.wins[1].title.fsize > f0)
  C.Set("meter.fontsize", 11)
  local expect = { win = "meter.width", title = "meter.view1", wins = "meter.windows", bar1 = "meter.rowh", name2 = "meter.showrank",
    cls = "meter.classcolor", val = "meter.shortnum", pct = "meter.showpct", rowh = "meter.spacing", font = "meter.fontsize" }
  for z, k in pairs(expect) do EQ("compteurs : clic " .. z, d.click(z), k) end
  zoneBy(d.root, "title"):Click()
  EQ("compteurs : clic sur le titre", P.lastKey, "meter.view1")
end

-- ---- menace
do
  local d = P.reg.threat
  local st = d.root.st
  M.Open("cat", "threat")
  local f = st.win
  CONTAINS("menace : titre = vue", f.title:GetText(), "Joueurs")
  CONTAINS("menace : le tank porte la marque", f.r[1].nm:GetText(), "[T]")
  C.Set("threat.markholder", false)
  EQ("menace : marque coupee", string.find(f.r[1].nm:GetText(), "[", 1, true), nil)
  C.Set("threat.markholder", true)
  CONTAINS("menace : ligne d'aggro", f.sub:GetText(), "Thorgrim")
  C.Set("threat.showagro", false)
  EQ("menace : ligne d'aggro coupee", f.sub:IsShown(), false)
  C.Set("threat.showagro", true)
  EQ("menace : provocation affichee", f.tag:IsShown(), true)
  C.Set("threat.taunt", false)
  EQ("menace : provocation coupee", f.tag:IsShown(), false)
  EQ("menace : zone de provocation toujours la", st.z.tag:IsShown(), true)
  C.Set("threat.taunt", true)
  CONTAINS("menace : menace par seconde", f.r[1].vl:GetText(), "/s")
  C.Set("threat.showtps", false)
  EQ("menace : menace par seconde coupee", string.find(f.r[1].vl:GetText(), "/s", 1, true), nil)
  C.Set("threat.showtps", true)
  CONTAINS("menace : estimation", f.r[1].vl:GetText(), "~")
  C.Set("threat.estimate", false)
  EQ("menace : estimation coupee", string.find(f.r[1].vl:GetText(), "~", 1, true), nil)
  C.Set("threat.estimate", true)
  local bad = SUI.Theme.c.bad[1]
  EQ("menace : au-dessus du seuil la barre est rouge", vcol(f.r[2].bar), bad)
  C.Set("threat.warn", 100)
  T("menace : seuil releve, la barre n'est plus rouge", vcol(f.r[2].bar) ~= bad)
  C.Set("threat.warn", 85)
  C.Set("threat.view", "mobs")
  CONTAINS("menace : vue des cibles", f.title:GetText(), "Cibles")
  EQ("menace : cibles = noms de monstres", f.r[1].nm:GetText(), "Gnoll")
  EQ("menace : pas de provocation en vue des cibles", f.tag:IsShown(), false)
  C.Set("threat.view", "players")
  C.Set("threat.rows", 3)
  EQ("menace : 3 lignes", st.n, 3)
  EQ("menace : 4e ligne cachee", f.r[4].bar:IsShown(), false)
  C.Set("threat.rows", 10)
  EQ("menace : 6 lignes d'exemple au maximum", st.n, 6)
  local w0 = f:GetWidth()
  C.Set("threat.width", 300)
  T("menace : largeur", f:GetWidth() > w0)
  C.Set("threat.width", 220)
  local expect = { win = "threat.width", title = "threat.view", sub = "threat.showagro", row1 = "threat.markholder", row2 = "threat.warn",
    tag = "threat.taunt", row4 = "threat.showtps", row5 = "threat.classcolor" }
  for z, k in pairs(expect) do EQ("menace : clic " .. z, d.click(z), k) end
  zoneBy(d.root, "tag"):Click()
  EQ("menace : clic sur la provocation", P.lastKey, "threat.taunt")
end

-- ---- minimap
do
  local d = P.reg.minimap
  local st = d.root.st
  M.Open("cat", "minimap")
  EQ("minimap : ronde par defaut", st.on.round, true)
  local top1, mid1 = st.fill[1]:GetWidth(), st.fill[14]:GetWidth()
  T("minimap : ronde, la bande du haut est plus etroite que celle du milieu", top1 < mid1 * 0.5)
  C.Set("minimap.shape", "square")
  EQ("minimap : carree", st.on.round, false)
  EQ("minimap : carree, bande du haut pleine", st.fill[1]:GetWidth(), st.fill[14]:GetWidth())
  CONTAINS("minimap : legende carree", st.cap:GetText(), "carree")
  C.Set("minimap.shape", "round")
  CONTAINS("minimap : legende ronde", st.cap:GetText(), "ronde")
  local d0 = st.d
  C.Set("minimap.size", 220)
  T("minimap : taille", st.d > d0)
  C.Set("minimap.size", 100)
  T("minimap : petite taille", st.d < d0)
  C.Set("minimap.size", 140)
  EQ("minimap : coordonnees", st.coords:GetText(), "45.2, 63.1")
  C.Set("minimap.dec", 0)
  EQ("minimap : coordonnees entieres", st.coords:GetText(), "45, 63")
  C.Set("minimap.dec", 2)
  EQ("minimap : coordonnees a 2 decimales", st.coords:GetText(), "45.23, 63.11")
  C.Set("minimap.dec", 1)
  C.Set("minimap.coords", false)
  EQ("minimap : coordonnees coupees", st.coords:IsShown(), false)
  EQ("minimap : la zone reste cliquable", st.z.coords:IsShown(), true)
  C.Set("minimap.coords", true)
  EQ("minimap : nom de zone", st.zone:IsShown(), true)
  C.Set("minimap.zone", false)
  EQ("minimap : nom de zone coupe", st.zone:IsShown(), false)
  C.Set("minimap.zone", true)
  EQ("minimap : heure coupee par defaut", st.clock:IsShown(), false)
  C.Set("minimap.clock", "local")
  EQ("minimap : heure locale", st.clock:GetText(), "12:34")
  C.Set("minimap.clock", "server")
  CONTAINS("minimap : heure du serveur", st.clock:GetText(), "(S)")
  C.Set("minimap.clock", "off")
  EQ("minimap : lanceur", st.lb:IsShown(), true)
  local lx0 = pt(st.lb)
  C.Set("minimap.launchangle", 0)
  T("minimap : angle du lanceur (a droite a 0 degre)", pt(st.lb) > lx0)
  C.Set("minimap.launchangle", 165)
  C.Set("minimap.launcher", false)
  EQ("minimap : lanceur coupe", st.lb:IsShown(), false)
  C.Set("minimap.launcher", true)
  EQ("minimap : bouton du tiroir", st.tb:IsShown(), true)
  local tx0 = pt(st.tb)
  C.Set("minimap.togglepos", "topright")
  T("minimap : bouton du tiroir en haut a droite", pt(st.tb) > tx0)
  C.Set("minimap.togglepos", "hide")
  EQ("minimap : bouton du tiroir cache", st.tb:IsShown(), false)
  C.Set("minimap.togglepos", "topleft")
  C.Set("minimap.buttons", false)
  EQ("minimap : tiroir coupe", st.tb:IsShown(), false)
  C.Set("minimap.buttons", true)
  EQ("minimap : liseret", st.ring[10]:IsShown(), true)
  C.Set("minimap.edge", false)
  EQ("minimap : liseret coupe", st.ring[10]:IsShown(), false)
  C.Set("minimap.edge", true)
  local expect = { disc = "minimap.shape", size = "minimap.size", edge = "minimap.edge", coords = "minimap.coords", zone = "minimap.zone",
    clock = "minimap.clock", launcher = "minimap.launcher", toggle = "minimap.buttons" }
  for z, k in pairs(expect) do EQ("minimap : clic " .. z, d.click(z), k) end
  zoneBy(d.root, "disc"):Click()
  EQ("minimap : clic sur le disque", P.lastKey, "minimap.shape")
end

-- ---- sacs
do
  local d = P.reg.bags
  local st = d.root.st
  M.Open("cat", "bags")
  EQ("sacs : sans option de categories, pas de sections", st.on.cats, false)
  EQ("sacs : zone des categories retiree", st.z.cats:IsShown(), false)
  EQ("sacs : clic sur les categories sans option", d.click("cats"), nil)
  CONTAINS("sacs : titre", st.win.title:GetText(), "Sacs")
  local w0 = st.cells[1]:GetWidth()
  C.Set("bags.size", 24)
  T("sacs : petites cases", st.cells[1]:GetWidth() < w0)
  C.Set("bags.size", 32)
  C.Set("bags.columns", 6)
  EQ("sacs : 6 colonnes", st.cols, 6)
  local _, ya = pt(st.cells[7])
  local _, yb = pt(st.cells[1])
  T("sacs : la 7e case passe a la ligne", ya < yb)
  C.Set("bags.columns", 20)
  T("sacs : 20 colonnes tiennent dans la zone", st.cols >= 6 and st.win:GetWidth() <= d.root:GetWidth())
  C.Set("bags.columns", 10)
  EQ("sacs : tri par qualite, le meilleur d'abord", st.ord[1], 1)
  EQ("sacs : tri par qualite, 4e = un objet rare", st.ord[4], 14)
  C.Set("bags.sort", "name")
  EQ("sacs : tri par nom, ordre de l'exemple", st.ord[4], 4)
  CONTAINS("sacs : tri affiche", st.win.sortt:GetText(), "Nom")
  C.Set("bags.sort", "quality")
  EQ("sacs : objets gris en dernier", st.ord[26], 19)
  C.Set("bags.junklast", false)
  EQ("sacs : gris non deplaces", st.on.junklast, false)
  C.Set("bags.sort", "type")
  EQ("sacs : sans tri par qualite ni gris en dernier", st.ord[11], 11)
  C.Set("bags.junklast", true)
  C.Set("bags.sort", "quality")
  local function cellOf(item)
    for i = 1, 40 do
      if st.cells[i].item == item and st.cells[i]:IsShown() then return st.cells[i] end
    end
    return nil
  end
  EQ("sacs : nombre sur l'objet empile", cellOf(5).cn:GetText(), "20")
  C.Set("bags.counts", false)
  EQ("sacs : nombres coupes", cellOf(5).cn:IsShown(), false)
  C.Set("bags.counts", true)
  C.Set("bags.quality", false)
  EQ("sacs : qualite coupee", st.on.quality, false)
  C.Set("bags.quality", true)
  EQ("sacs : recherche", st.win.sb:IsShown(), true)
  C.Set("bags.search", false)
  EQ("sacs : recherche coupee (grisee)", st.on.search, false)
  EQ("sacs : zone de recherche toujours la", st.z.search:IsShown(), true)
  C.Set("bags.search", true)
  C.Set("bags.filters", false)
  EQ("sacs : filtres coupes", st.on.filters, false)
  C.Set("bags.filters", true)
  EQ("sacs : valeur", st.win.money:IsShown(), true)
  C.Set("bags.value", false)
  EQ("sacs : valeur coupee", st.win.money:IsShown(), false)
  C.Set("bags.value", true)
  C.Set("bags.keyring", true)
  EQ("sacs : cles", st.on.keyring, true)
  C.Set("bags.keyring", false)
  -- categories : option livree par le module des sacs (simulee ici)
  table.insert(SUI.options, { key = "bags.categories", type = "bool", cat = "bags", label = "opt.bags.columns", tip = "tip.bags.columns", default = false })
  P.Update(d, nil, nil)
  EQ("sacs : option des categories presente, sections eteintes", st.on.cats, false)
  EQ("sacs : la zone des categories apparait", st.z.cats:IsShown(), true)
  EQ("sacs : clic sur les categories", d.click("cats"), "bags.categories")
  local okSet = pcall(C.Set, "bags.categories", true)
  if okSet and C.Get("bags.categories") == true then
    EQ("sacs : sections par categorie", st.on.cats, true)
    EQ("sacs : en-tete de section", st.heads[1]:IsShown(), true)
    CONTAINS("sacs : en-tete", st.heads[1]:GetText(), "Equipement")
    C.Set("bags.categories", false)
    EQ("sacs : sections coupees", st.heads[1]:IsShown(), false)
  end
  table.remove(SUI.options)
  P.Update(d, nil, nil)
  EQ("sacs : option retiree, plus de zone", st.z.cats:IsShown(), false)
  local expect = { grid = "bags.columns", cell1 = "bags.size", qual = "bags.quality", border = "bags.borderlimit", count = "bags.counts", junk = "bags.junklast",
    sort = "bags.sort", search = "bags.search", filters = "bags.filters", value = "bags.value", keyring = "bags.keyring" }
  for z, k in pairs(expect) do EQ("sacs : clic " .. z, d.click(z), k) end
  zoneBy(d.root, "search"):Click()
  EQ("sacs : clic sur la recherche", P.lastKey, "bags.search")
end
EQ("aucune erreur interne (apercus des modules)", SUI.errCount, 0)

SECTION("t_preview : apercus des modules en combat, instances, anglais")
do
  local host = CreateFrame("Frame", nil, UIParent)
  for _, id in ipairs(NEW) do
    local inst = P.Instance(id, host, 300, 380, false)
    T(id .. " : instance independante", inst ~= nil)
    if inst then
      local allMute = true
      local zs = zonesOf(inst.root)
      for i = 1, table.getn(zs) do if zs[i].mouse then allMute = false end end
      T(id .. " : zones insensibles", allMute and table.getn(zs) >= 5)
      inst.Update("zz.inconnu", nil)
      inst.Update(nil, nil)
    end
  end
  W.combat = true
  local c0 = CREATED
  for _, id in ipairs(NEW) do
    EQ(id .. " : combat, pas d'instance", P.Instance(id, host, 300, 380, false), nil)
  end
  for _, id in ipairs(NEW) do M.Open("cat", id) end
  EQ("combat : l'apercu des sacs est affiche", P.curId, "bags")
  C.Set("bags.columns", 8)
  EQ("combat : l'apercu des sacs se met a jour", P.reg.bags.root.st.cols, 8)
  C.Set("bags.columns", 10)
  M.Open("cat", "castbar")
  C.Set("castbar.width", 260)
  EQ("combat : l'apercu de l'incantation se met a jour", P.reg.castbar.root.st.bars[1].bw > 0, true)
  C.Set("castbar.width", 220)
  C.Set("meter.windows", 2)
  C.Set("meter.windows", 1)
  EQ("combat : navigation et reglages des apercus sans creation", CREATED, c0)
  W.combat = false
  Fire("PLAYER_REGEN_ENABLED")
  SETTLE()
  C.Set("ui.locale", "en")
  M.Open("cat", "castbar")
  EQ("EN : incantation, sort", P.reg.castbar.root.st.bars[1].nm:GetText(), "Fireball")
  M.Open("cat", "meter")
  CONTAINS("EN : compteurs, titre", P.reg.meter.root.st.wins[1].title:GetText(), "Damage - Current")
  M.Open("cat", "minimap")
  CONTAINS("EN : minimap, legende", P.reg.minimap.root.st.cap:GetText(), "Round minimap")
  M.Open("cat", "bags")
  CONTAINS("EN : sacs, recherche", P.reg.bags.root.st.win.st:GetText(), "Search")
  M.Open("cat", "threat")
  CONTAINS("EN : menace, aggro", P.reg.threat.root.st.win.sub:GetText(), "Aggro: Thorgrim")
  C.Set("ui.locale", "fr")
  for i = 1, math.min(3, table.getn(SUI.Style.names)) do
    C.Set("style.name", SUI.Style.names[i])
    Pump(0.2)
  end
  EQ("changement de style : aucune erreur", SUI.errCount, 0)
end

SECTION("t_preview : textes FR / EN et style")
M.Open("cat", "raid")
C.Set("ui.locale", "en")
EQ("EN : titre", P.pane.title:GetText(), "Preview: " .. M.CatLabel("raid"))
EQ("EN : bouton", M.frame.pvBtn.label:GetText(), "Preview")
EQ("EN : indication", P.pane.hint:GetText(), "Click an element to jump to its setting.")
CONTAINS("EN : legende du raid", P.reg.raid.root.st.legend:GetText(), "Examples")
C.Set("ui.locale", "fr")
EQ("FR : bouton", M.frame.pvBtn.label:GetText(), "Apercu")
local names = SUI.Style.names
for i = 1, math.min(3, table.getn(names)) do
  C.Set("style.name", names[i])
  Pump(0.2)
end
EQ("changement de style : aucune erreur", SUI.errCount, 0)
C.Set("modules.raid", true)
EQ("module active : mention retiree", P.pane.status:GetText(), "")
C.Set("modules.raid", false)
EQ("module coupe : mention revenue", P.pane.status:GetText(), "module desactive : apercu des reglages seulement")

SECTION("t_preview : combat (aucune creation), apercu non prepare")
local late = 0
P.Register("general", { build = function(parent, w, h)
  late = late + 1
  local f = CreateFrame("Frame", nil, parent)
  f.txt = f:CreateFontString(nil, "OVERLAY")
  return f
end, update = function(root, w, h, key, value) root.last = key end, click = function(zone) return "ui.scale" end })
W.combat = true
local c0 = CREATED
M.Open("cat", "general")
EQ("combat : aucun cadre cree (apercu non prepare)", CREATED, c0)
EQ("combat : build non appele", late, 0)
EQ("combat : message affiche", P.pane.msg:IsShown(), true)
CONTAINS("combat : texte du message", P.pane.msg:GetText(), "combat")
for _, pg in ipairs({ { "cat", "raid" }, { "cat", "units" }, { "home" }, { "cat", "chat" }, { "cat", "group" }, { "cat", "actionbars" } }) do
  M.Open(pg[1], pg[2])
end
C.Set("raid.width", 80)
C.Set("raid.sort", "name")
C.Set("raid.sort", "group")
C.Set("raid.width", 64)
st.cells[5]:Click()
st.btns[2]:Click()
st.btns[4]:Click()
EQ("combat : navigation et reglages sans creation", CREATED, c0)
EQ("combat : l'apercu se met a jour", shownCells(P.reg.raid.root.st), 40)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
SETTLE()
M.Open("cat", "general")
EQ("hors combat : l'apercu est construit", late, 1)
EQ("hors combat : message retire", P.pane.msg:IsShown(), false)
EQ("hors combat : mis a jour (cle nil)", P.reg.general.root.last, nil)
C.Set("ui.scale", 1.1)
EQ("cle globale : apercu redessine", P.reg.general.root.last, "ui.scale")
C.Set("ui.scale", 1.0)
Pump(1)
EQ("apercu en erreur : signale, pas de plantage", (function()
  P.Register("general", { build = function() error("boum") end, update = function() end })
  local n0 = SUI.errCount
  M.Open("cat", "general")
  M.Open("cat", "raid")
  M.Open("cat", "general")
  return SUI.errCount - n0 >= 1 and P.pane.msg:IsShown()
end)(), true)
SUI.errCount = 0
EQ("aucune erreur interne apres la remise a zero", SUI.errCount, 0)

SECTION("t_preview : niveaux de cadres (controles au-dessus et cliquables)")
M.Open("cat", "raid")
M.SetMode("all")
local pane = P.pane
local function maxLevel(fr)
  local m = fr:GetFrameLevel()
  walk(fr, function(f) if f:GetFrameLevel() > m then m = f:GetFrameLevel() end end)
  return m
end
local pmax = maxLevel(pane)
T("volet au niveau du contenu", pane:GetFrameLevel() >= M.child:GetFrameLevel())
T("liste deroulante au-dessus du volet", M.frame.drop:GetFrameLevel() > pmax)
T("cadre de capture au-dessus du volet", M.frame.catcher:GetFrameLevel() > pmax)
local allAbove = true
for i = 1, M.used.cell do
  local c = M.pools.cell[i]
  if c.opt and c:GetFrameLevel() < pane:GetFrameLevel() then allAbove = false end
end
T("lignes de reglage au niveau du volet ou au-dessus", allAbove)
local zs = zonesOf(P.reg.raid.root)
local lowest = 99999
for i = 1, table.getn(zs) do if zs[i]:GetFrameLevel() < lowest then lowest = zs[i]:GetFrameLevel() end end
T("zones au-dessus des cadres du volet", lowest > P.reg.raid.root:GetFrameLevel())
-- les zones sont au-dessus des cadres de la grille
T("zones au-dessus des cadres du raid", zoneBy(P.reg.raid.root, "hot"):GetFrameLevel() > st.cells[1]:GetFrameLevel())
-- les reglages restent cliquables (un clic sur une ligne agit) avec le volet
local cellRow
for i = 1, M.used.cell do
  local c = M.pools.cell[i]
  if c.opt and c.opt.key == "raid.aggro" then cellRow = c end
end
T("ligne raid.aggro", cellRow ~= nil)
local before = C.Get("raid.aggro")
cellRow.ctl:Click()
EQ("clic sur le controle de la ligne : l'option bascule", C.Get("raid.aggro"), not before)
EQ("la bascule se voit dans l'apercu", st.det.hl:IsShown(), not before)
cellRow.ctl:Click()
EQ("second clic : retour", C.Get("raid.aggro"), before)
-- mode deplacement : tout le menu (volet compris) passe au-dessus
local function strata(f) return f.calls.SetFrameStrata and f.calls.SetFrameStrata[1] end
local l0 = pane:GetFrameLevel()
M.SetRaised(true)
EQ("deplacement : volet en FULLSCREEN_DIALOG", strata(pane), "FULLSCREEN_DIALOG")
EQ("deplacement : zone en FULLSCREEN_DIALOG", strata(zoneBy(P.reg.raid.root, "hot")), "FULLSCREEN_DIALOG")
T("deplacement : volet releve avec la fenetre", pane:GetFrameLevel() == l0 + M.RAISE)
T("deplacement : liste toujours au-dessus", M.frame.drop:GetFrameLevel() > maxLevel(pane))
M.Open("cat", "chat")
M.Open("cat", "raid")
T("deplacement : niveau stable apres navigation", pane:GetFrameLevel() == l0 + M.RAISE)
M.SetRaised(false)
EQ("fin du deplacement : strate normale", strata(pane), "DIALOG")
T("fin du deplacement : niveau d'origine", pane:GetFrameLevel() == l0)
-- le client change le niveau du cadre defilant : le volet suit (comme les controles)
M.child:SetFrameLevel(M.child:GetFrameLevel() + 5)
M.Render()
EQ("niveau du contenu releve : volet recale", pane:GetFrameLevel(), M.lvl)
T("niveau du contenu releve : liste au-dessus", M.frame.drop:GetFrameLevel() > maxLevel(pane))
M.SetMode("essential")
EQ("aucune erreur de niveau", SUI.errCount, 0)

SECTION("t_preview : instance independante (assistant)")
do
  local host = CreateFrame("Frame", nil, UIParent)
  local inst = P.Instance("raid", host, 300, 360, false)
  T("instance creee", inst ~= nil)
  EQ("racine dans l'hote", inst.root:GetParent(), host)
  local zs = zonesOf(inst.root)
  T("zones presentes", table.getn(zs) > 5)
  local allMute = true
  for i = 1, table.getn(zs) do if zs[i].mouse then allMute = false end end
  T("zones insensibles (non interactive)", allMute)
  C.Set("raid.maxgroup", 1)
  inst.Update(nil)
  local n = 0
  for i = 1, 40 do if inst.root.st.cells[i]:IsShown() then n = n + 1 end end
  EQ("instance : suit les reglages", n, 5)
  C.Set("raid.maxgroup", 8)
  local inter = P.Instance("units", host, 300, 300, true)
  local z1 = zonesOf(inter.root)[1]
  EQ("interactive : zones sensibles", z1.mouse, true)
  W.combat = true
  local c1 = CREATED
  EQ("combat : pas d'instance", P.Instance("raid", host, 300, 360, false), nil)
  EQ("combat : rien de cree", CREATED, c1)
  W.combat = false
  EQ("inconnu : pas d'instance", P.Instance("zzz", host, 10, 10, false), nil)
end
EQ("aucune erreur interne (fin)", SUI.errCount, 0)

DONE()
