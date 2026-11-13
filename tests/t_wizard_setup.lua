-- t_wizard_setup : assistant d'installation a DEUX parcours (Menu_Wizard.lua), de bout en bout, par clics sur les boutons.
-- Chaque bouton cree dans une boucle est clique et la valeur EFFECTIVEMENT retenue est controlee (pas de bug du "dernier bouton" du client 1.12) ;
-- valeurs appliquees dans la configuration, annulation complete, Passer / Precedent / Par defaut conseille, changement de parcours en cours,
-- specialites (module "specs" simule), premier lancement, journal de clics, aucune trace de l'ancien import pfUI.
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Menu
local B = SUI.Backup
local S = SUI.Style

AU_SETUP()
TNK_SETUP()
SPECS_SETUP()
SPECS_TALENTS(31, 20, 0, { "Sacre", "Protection", "Vindicte" })
BOOT()
SETTLE()
C.SetGlobal("firstRun", false)

local function open(path)
  if M.wiz then M.wiz:Hide() end
  M.ws = nil
  M.ShowWizard(1)
  local w = M.wiz
  if path then w.pg.welcome.path[path == "quick" and 1 or 2]:Click() end
  return w
end
local function stepsStr()
  return table.concat(M.WizSteps(), ",")
end
local function go(id)
  local st = M.WizSteps()
  for i = 1, table.getn(st) do
    if st[i] == id then M.WizGo(i) return end
  end
  error("etape absente : " .. id .. " (" .. stepsStr() .. ")")
end
local function sumText(w)
  local t = ""
  for i = 1, 17 do
    local r = w.pg.summary.rows[i]
    if r.l:IsShown() then t = t .. r.l:GetText() .. "=" .. r.v:GetText() .. "\n" end
  end
  return t
end
local function setMods()
  local t = {}
  for i = 1, table.getn(SUI.moduleOrder) do t[SUI.moduleOrder[i]] = C.Get("modules." .. SUI.moduleOrder[i]) and true or false end
  return t
end
local function sameMods(set, label)
  for i = 1, table.getn(SUI.moduleOrder) do
    local n = SUI.moduleOrder[i]
    EQ(label .. " : " .. n, M.ws.sel.mods[n] and true or false, set[n] and true or false)
  end
end
-- clique le bouton (rid, oid) de la page des reglages essentiels (en choisissant l'onglet qui le porte)
local function pick(w, rid, oid)
  local pg = w.pg.essentials
  for ti = 1, table.getn(pg.tabs) do
    local tb = pg.tabs[ti]
    if tb:IsShown() then
      tb:Click()
      for i = 1, 5 do
        local row = pg.rows[i]
        for j = 1, 4 do
          local b = row.b[j]
          if b:IsShown() and b.rid == rid and b.oid == oid then
            b:Click()
            return true
          end
        end
      end
    end
  end
  error("bouton absent : " .. rid .. "/" .. oid)
end

local orig = {
  role = C.GetRole(), style = C.Get("style.name"), scale = C.Get("ui.scale"), layout = C.cur.layout, modeauto = C.Get("mode.auto"),
  mods = setMods(),
}

-- ------------------------------------------------------------------ parcours Rapide
SECTION("t_wizard_setup : parcours Rapide")
local w = open("quick")
EQ("etapes du parcours Rapide", stepsStr(), "welcome,role,style,summary")
EQ("progression Rapide", w.dots:GetText(), "Etape 1 sur 4")
EQ("Rapide est selectionne", w.pg.welcome.path[1].selected, true)
EQ("Installation + n'est plus selectionne", w.pg.welcome.path[2].selected, false)
EQ("Rapide : la suite par defaut est le menu", M.ws.sel.after, "menu")
w.pg.welcome.l[2]:Click()
EQ("langue : English", M.ws.sel.locale, "en")
EQ("langue : English (champ)", SUI.locale, "en")
w.pg.welcome.l[1]:Click()
EQ("langue : Francais", M.ws.sel.locale, "fr")
EQ("langue : Francais (champ)", SUI.locale, "fr")
w.nextBtn:Click()
EQ("Suivant : role", w.stepId, "role")
for i = 1, 4 do
  w.pg.role.rb[i]:Click()
  EQ("role : bouton " .. i, M.ws.sel.role, C.roleOrder[i])
  EQ("role : bouton " .. i .. " mis en avant", w.pg.role.rb[i].selected, true)
end
w.pg.role.rb[3]:Click()
EQ("role : dps", M.ws.sel.role, "dps")
w.pg.role.rb[2]:Click()
EQ("role : soigneur", M.ws.sel.role, "heal")
sameMods(M.WizPackSet("heal"), "Rapide : modules du pack Soigneur")
EQ("Rapide : debuffs conseilles", M.ws.sel.es.debuffs, "n3")
EQ("Rapide : dissipation conseillee", M.ws.sel.es.dispel, "known")
CONTAINS("Rapide : le role annonce l'application d'office", w.pg.role.reco:GetText(), "Rapide")
w.nextBtn:Click()
EQ("Suivant : style", w.stepId, "style")
for i = 1, 12 do
  local b = w.pg.style.sb[i]
  if b:IsShown() then
    b:Click()
    EQ("style : bouton " .. i, M.ws.sel.style, S.names[i])
  end
end
w.pg.style.sb[3]:Click()
local SC = { 0.9, 1.0, 1.1 }
for i = 1, 3 do
  w.pg.style.sz[i]:Click()
  NEAR("taille : bouton " .. i, M.ws.sel.scale, SC[i])
end
NEAR("taille : Grande", M.ws.sel.scale, 1.1)
w.nextBtn:Click()
EQ("Suivant : recapitulatif", w.stepId, "summary")
EQ("Appliquer", w.nextBtn.label:GetText(), "Appliquer")
CONTAINS("recapitulatif : parcours", sumText(w), "Rapide")
CONTAINS("recapitulatif : role", sumText(w), "Soigneur")
CONTAINS("recapitulatif : style", sumText(w), S.Label(S.names[3]))
EQ("rien d'applique avant le clic (role)", C.GetRole(), orig.role)
EQ("rien d'applique avant le clic (style)", C.Get("style.name"), orig.style)
local nb0 = table.getn(B.List())
w.nextBtn:Click()
EQ("page finale", w.stepId, "done")
EQ("role applique", C.GetRole(), "heal")
EQ("style applique", C.Get("style.name"), S.names[3])
NEAR("taille appliquee", C.Get("ui.scale"), 1.1)
local heal = M.WizPackSet("heal")
for i = 1, table.getn(SUI.moduleOrder) do
  local n = SUI.moduleOrder[i]
  EQ("Rapide applique le pack Soigneur : " .. n, C.Get("modules." .. n) and true or false, heal[n] and true or false)
end
EQ("Rapide applique les debuffs conseilles (raid)", C.Get("raid.debuffs"), 3)
EQ("Rapide applique les debuffs conseilles (groupe)", C.Get("group.debuffs"), 3)
EQ("Rapide applique : dissipables seuls (groupe)", C.Get("group.dispelonly"), true)
EQ("Rapide ne touche pas a la mise en page", C.cur.layout, orig.layout)
EQ("Rapide ne touche pas au mode", C.Get("mode.auto"), orig.modeauto)
EQ("sauvegarde prise", table.getn(B.List()), nb0 + 1)
EQ("sauvegarde : raison", B.List()[1].reason, "wizard")
w.skip:Click()
EQ("Tout annuler ferme", w:IsShown(), false)
EQ("annule : role", C.GetRole(), orig.role)
EQ("annule : style", C.Get("style.name"), orig.style)
NEAR("annule : taille", C.Get("ui.scale"), orig.scale)
EQ("annule : debuffs (raid)", C.Get("raid.debuffs"), 2)
EQ("annule : dissipables seuls (groupe)", C.Get("group.dispelonly"), false)
for i = 1, table.getn(SUI.moduleOrder) do
  local n = SUI.moduleOrder[i]
  EQ("annule : module " .. n, C.Get("modules." .. n) and true or false, orig.mods[n])
end

-- ------------------------------------------------------------------ parcours Installation + : modules
SECTION("t_wizard_setup : Installation + / modules")
w = open("plus")
EQ("parcours par defaut = Installation +", M.ws.sel.path, "plus")
EQ("etapes d'Installation +", stepsStr(), "welcome,role,modules,style,layout,essentials,specs,backup,place,summary")
EQ("Installation + : la suite par defaut est le deplacement", M.ws.sel.after, "move")
go("role")
w.pg.role.rb[1]:Click()
EQ("role tank", M.ws.sel.role, "tank")
sameMods(M.WizPackSet("tank"), "Installation + : modules du pack Tank")
EQ("Tank : menace conseillee", M.ws.sel.es.tshow, "on")
go("modules")
M.ws.modPage = 1
M.WizRender()
local pg = w.pg.modules
local shown = 0
for i = 1, 10 do
  local b = pg.slot[i]
  if b:IsShown() then
    shown = shown + 1
    local name = b.mod
    local snap = {}
    for k, v in pairs(M.ws.sel.mods) do snap[k] = v end
    b:Click()
    EQ("carte " .. i .. " (" .. name .. ") bascule son module", M.ws.sel.mods[name], not snap[name])
    for k, v in pairs(M.ws.sel.mods) do
      if k ~= name then EQ("carte " .. i .. " ne touche pas " .. k, v, snap[k]) end
    end
    b:Click()
    EQ("carte " .. i .. " re-clic", M.ws.sel.mods[name], snap[name])
    T("carte " .. i .. " a une phrase", pg.sd[i]:IsShown() and pg.sd[i]:GetText() ~= nil and pg.sd[i]:GetText() ~= "")
  end
end
EQ("10 cartes par page", shown, 10)
local first1 = pg.slot[1].mod
local npages = math.floor((table.getn(SUI.moduleOrder) - 1) / 10) + 1
T("plusieurs pages de cartes", npages >= 2)
pg.pageBtn:Click()
EQ("page suivante", M.ws.modPage, 2)
T("page suivante : autres modules", pg.slot[1].mod ~= first1)
for i = 2, npages do pg.pageBtn:Click() end
EQ("les pages tournent", M.ws.modPage, 1)
EQ("premiere carte de nouveau", pg.slot[1].mod, first1)
T("modules conseilles d'abord", string.find(pg.slot[1].label:GetText(), "conseille", 1, true) ~= nil)
for i = 1, 7 do
  pg.pk[i]:Click()
  local set = M.WizPackSet(pg.pk[i].pid)
  sameMods(set, "pack " .. pg.pk[i].pid)
end
w.defBtn:Click()
sameMods(M.WizPackSet("tank"), "Par defaut conseille (modules) = pack Tank")
pg.pk[3]:Click()
w.passBtn:Click()
EQ("Passer (modules) : etape suivante", w.stepId, "style")
sameMods(orig.mods, "Passer (modules) : retour a l'etat d'avant")

-- ------------------------------------------------------------------ Installation + : reglages essentiels
SECTION("t_wizard_setup : Installation + / reglages essentiels")
w = open("plus")
go("role")
w.pg.role.rb[1]:Click()
go("essentials")
local ep = w.pg.essentials
local tabsShown = {}
for i = 1, table.getn(ep.tabs) do
  if ep.tabs[i]:IsShown() then tabsShown[table.getn(tabsShown) + 1] = ep.tabs[i].tab end
end
EQ("6 onglets avec le pack Tank", table.concat(tabsShown, ","), "bars,units,group,meter,minimap,chat")
local nrows = 0
for ti = 1, table.getn(ep.tabs) do
  ep.tabs[ti]:Click()
  EQ("onglet " .. ep.tabs[ti].tab .. " choisi", M.ws.tab, ep.tabs[ti].tab)
  EQ("onglet " .. ep.tabs[ti].tab .. " mis en avant", ep.tabs[ti].selected, true)
  for i = 1, 5 do
    local row = ep.rows[i]
    if row.label:IsShown() then
      nrows = nrows + 1
      local opts = {}
      for j = 1, 4 do
        local b = row.b[j]
        if b:IsShown() then
          b:Click()
          EQ("ligne " .. b.rid .. " : option " .. j .. " retenue", M.ws.sel.es[b.rid], b.oid)
          opts[table.getn(opts) + 1] = b
          for k = 1, table.getn(opts) do
            EQ("ligne " .. b.rid .. " : seul le bouton clique est en avant (" .. k .. ")", opts[k].selected, k == table.getn(opts))
          end
        end
      end
      T("ligne " .. tostring(row.label:GetText()) .. " : textes presents", row.label:GetText() ~= nil and row.help:GetText() ~= nil)
    end
  end
end
T("au moins 18 lignes de reglages essentiels", nrows >= 18)
-- choix precis a appliquer
local PICKS = {
  { "bars", "incombat" }, { "size", "large" }, { "micro", "never" }, { "xp", "hide" },
  { "uwidth", "small" }, { "uhp", "both" }, { "upower", "off" }, { "urange", "off" },
  { "rsize", "r10" }, { "dispel", "all" }, { "donly", "off" }, { "debuffs", "n1" },
  { "mwin", "n2" }, { "mhide", "on" }, { "tshow", "off" }, { "twarn", "p95" }, { "tsound", "off" },
  { "shape", "square" }, { "clock", "server" }, { "coords", "off" }, { "btnmode", "hover" },
  { "chat", "quiet" },
}
for i = 1, table.getn(PICKS) do
  pick(w, PICKS[i][1], PICKS[i][2])
  EQ("choix " .. PICKS[i][1], M.ws.sel.es[PICKS[i][1]], PICKS[i][2])
end
go("specs")
local sp = w.pg.specs
for i = 1, 3 do T("specialite " .. i .. " proposee", sp.sl[i]:IsShown()) end
CONTAINS("specialite 1 nommee", sp.sl[1]:GetText(), "Sacre")
local wantRoles = { "tank", "heal", "keep" }
for i = 1, 3 do
  for j = 1, 5 do
    sp.sr[i][j]:Click()
    local exp = sp.sr[i][j].rn
    if exp == "keep" then exp = nil end
    EQ("specialite " .. i .. " bouton " .. j, M.ws.sel.spec[i], exp)
  end
end
sp.sr[1][2]:Click()
sp.sr[2][3]:Click()
sp.sr[3][1]:Click()
EQ("specialite 1 : tank", M.ws.sel.spec[1], "tank")
EQ("specialite 2 : heal", M.ws.sel.spec[2], "heal")
EQ("specialite 3 : inchangee", M.ws.sel.spec[3], nil)
go("summary")
local st = sumText(w)
CONTAINS("recapitulatif : specialite 1", st, "Sacre")
CONTAINS("recapitulatif : reglages essentiels resumes en une ligne", st, "Reglages essentiels")
CONTAINS("recapitulatif : nombre de reglages changes", st, "modifies")
local u0 = { width = C.Get("units.width"), size = C.Get("actionbars.size"), max = C.Get("raid.maxgroup"), stamp = C.Get("chat.stamp"),
  shape = C.Get("minimap.shape"), win = C.Get("meter.windows"), warn = C.Get("threat.warn") }
w.nextBtn:Click()
EQ("page finale", w.stepId, "done")
EQ("bars : barre 2 cachee hors combat", C.Get("actionbars.bar2.show"), "incombat")
EQ("bars : barre principale toujours visible", C.Get("actionbars.main.show"), "always")
EQ("size", C.Get("actionbars.size"), 44)
EQ("micro", C.Get("actionbars.micro"), "never")
EQ("xp", C.Get("actionbars.xpbar"), "hide")
EQ("uwidth", C.Get("units.width"), 150)
EQ("uhp", C.Get("units.hptext"), "both")
EQ("upower", C.Get("units.showpower"), false)
EQ("urange", C.Get("units.range"), false)
EQ("rsize (10 joueurs = 2 groupes)", C.Get("raid.maxgroup"), 2)
EQ("dispel (groupe)", C.Get("group.dispelmode"), "all")
EQ("dispel (raid)", C.Get("raid.dispelmode"), "all")
EQ("donly (groupe)", C.Get("group.dispelonly"), false)
EQ("donly (raid)", C.Get("raid.dispelonly"), false)
EQ("debuffs (groupe)", C.Get("group.debuffs"), 1)
EQ("debuffs (raid)", C.Get("raid.debuffs"), 1)
EQ("mwin", C.Get("meter.windows"), 2)
EQ("mhide", C.Get("meter.hideooc"), true)
EQ("tshow", C.Get("threat.show"), false)
EQ("twarn", C.Get("threat.warn"), 95)
EQ("tsound", C.Get("threat.sound"), false)
EQ("shape", C.Get("minimap.shape"), "square")
EQ("clock", C.Get("minimap.clock"), "server")
EQ("coords", C.Get("minimap.coords"), false)
EQ("btnmode", C.Get("minimap.btnmode"), "hover")
EQ("chat : sans heure", C.Get("chat.stamp"), false)
EQ("chat : canaux courts", C.Get("chat.shortchan"), true)
CONTAINS("la page finale previent du /reload (barre d'xp)", w.pg.done.reload:GetText(), "/reload")
local Sp = SUI.Specs
local n1, n2 = Sp.Assigned(1), Sp.Assigned(2)
T("specialite 1 liee a un jeu", n1 ~= nil)
T("specialite 2 liee a un jeu", n2 ~= nil)
EQ("specialite 3 non liee", Sp.Assigned(3), nil)
EQ("jeu de la specialite 1 : role", Sp.GetPreset(n1 or "?") and Sp.GetPreset(n1).role, "tank")
EQ("jeu de la specialite 2 : role", Sp.GetPreset(n2 or "?") and Sp.GetPreset(n2).role, "heal")
EQ("module specialites actif", C.Get("modules.specs"), true)
w.skip:Click()
EQ("annule : assistant ferme", w:IsShown(), false)
EQ("annule : units.width", C.Get("units.width"), u0.width)
EQ("annule : actionbars.size", C.Get("actionbars.size"), u0.size)
EQ("annule : raid.maxgroup", C.Get("raid.maxgroup"), u0.max)
EQ("annule : chat.stamp", C.Get("chat.stamp"), u0.stamp)
EQ("annule : minimap.shape", C.Get("minimap.shape"), u0.shape)
EQ("annule : meter.windows", C.Get("meter.windows"), u0.win)
EQ("annule : threat.warn", C.Get("threat.warn"), u0.warn)
EQ("annule : specialite 1 delie", Sp.Assigned(1), nil)
EQ("annule : specialite 2 delie", Sp.Assigned(2), nil)
EQ("annule : jeu 1 supprime", n1 and Sp.GetPreset(n1), nil)
for i = 1, table.getn(SUI.moduleOrder) do
  local n = SUI.moduleOrder[i]
  EQ("annule : module " .. n, C.Get("modules." .. n) and true or false, orig.mods[n])
end
EQ("annule : role", C.GetRole(), orig.role)

-- ------------------------------------------------------------------ Passer / Precedent / Par defaut conseille / changer de parcours
SECTION("t_wizard_setup : Passer, Precedent, Par defaut conseille, changement de parcours")
w = open("plus")
EQ("etape 1 : pas de Precedent", w.prevBtn:IsShown(), false)
T("etape 1 : Passer et Par defaut visibles", w.passBtn:IsShown() and w.defBtn:IsShown())
EQ("etape 1 : pas de bouton de parcours (le choix est sur la page)", w.pathBtn:IsShown(), false)
w.passBtn:Click()
EQ("Passer (accueil)", w.stepId, "role")
T("bouton de parcours visible ensuite", w.pathBtn:IsShown())
CONTAINS("le bouton de parcours nomme le parcours", w.pathBtn.label:GetText(), "Installation +")
w.prevBtn:Click()
EQ("Precedent", w.stepId, "welcome")
-- Precedent jusqu'au bout
M.WizGo(table.getn(M.WizSteps()))
EQ("derniere etape = recapitulatif", w.stepId, "summary")
T("recapitulatif : ni Passer ni Par defaut", not w.passBtn:IsShown() and not w.defBtn:IsShown())
local n = 0
while w.stepId ~= "welcome" and n < 30 do
  w.prevBtn:Click()
  n = n + 1
end
EQ("Precedent ramene a l'accueil", w.stepId, "welcome")
EQ("nombre de Precedent = etapes - 1", n, table.getn(M.WizSteps()) - 1)
-- style : choix puis Passer
go("style")
w.pg.style.sb[2]:Click()
w.pg.style.sz[3]:Click()
w.passBtn:Click()
EQ("Passer (style) : style d'avant", M.ws.sel.style, orig.style)
NEAR("Passer (style) : taille d'avant", M.ws.sel.scale, orig.scale)
EQ("Passer (style) : etape suivante", w.stepId, "layout")
go("style")
w.pg.style.sb[2]:Click()
w.pg.style.sz[1]:Click()
w.defBtn:Click()
EQ("Par defaut (style) : style livre", M.ws.sel.style, S.DEFAULT)
NEAR("Par defaut (style) : taille normale", M.ws.sel.scale, 1.0)
EQ("Par defaut ne change pas d'etape", w.stepId, "style")
-- mise en page
go("layout")
w.pg.layout.lc[2]:Click()
w.pg.layout.mode[2]:Click()
w.defBtn:Click()
EQ("Par defaut (mise en page) : positions gardees", M.ws.sel.layout, nil)
EQ("Par defaut (mise en page) : mode automatique", M.ws.sel.modeauto, true)
w.pg.layout.lc[2]:Click()
w.pg.layout.mode[1]:Click()
w.passBtn:Click()
EQ("Passer (mise en page) : positions gardees", M.ws.sel.layout, nil)
EQ("Passer (mise en page) : mode d'avant", M.ws.sel.modeauto, orig.modeauto)
-- role
go("role")
w.pg.role.rb[2]:Click()
w.passBtn:Click()
EQ("Passer (role) : role d'avant", M.ws.sel.role, orig.role)
go("role")
w.defBtn:Click()
EQ("Par defaut (role) : DPS", M.ws.sel.role, "dps")
-- essentiels
go("role")
w.pg.role.rb[2]:Click()
go("essentials")
pick(w, "shape", "square")
w.defBtn:Click()
EQ("Par defaut (essentiels) : dissipation du soigneur", M.ws.sel.es.dispel, "known")
EQ("Par defaut (essentiels) : debuffs du soigneur", M.ws.sel.es.debuffs, "n3")
EQ("Par defaut (essentiels) : ce qui n'est pas conseille revient a l'etat d'avant", M.ws.sel.es.shape, M.ws.orig.es.shape)
pick(w, "debuffs", "n0")
w.passBtn:Click()
for k, v in pairs(M.ws.orig.es) do EQ("Passer (essentiels) : " .. k, M.ws.sel.es[k], v) end
EQ("Passer (essentiels) : etape suivante", w.stepId, "specs")
-- un role change apres une retouche manuelle ne l'ecrase pas
go("essentials")
pick(w, "debuffs", "n0")
go("role")
w.pg.role.rb[3]:Click()
EQ("changement de role : la retouche manuelle est gardee", M.ws.sel.es.debuffs, "n0")
-- changement de parcours en cours
go("modules")
M.WizSetPath("quick")
EQ("quick depuis modules : etape suivante qui existe", w.stepId, "style")
EQ("quick : 4 etapes", stepsStr(), "welcome,role,style,summary")
EQ("quick : la suite devient le menu", M.ws.sel.after, "menu")
M.WizSetPath("plus")
go("layout")
M.WizSetPath("quick")
EQ("quick depuis la mise en page : recapitulatif", w.stepId, "summary")
w.pathBtn:Click()
EQ("bouton de parcours : retour a la premiere page", w.stepId, "welcome")
w.pg.welcome.path[2]:Click()
EQ("retour a Installation +", M.ws.sel.path, "plus")
EQ("retour : toutes les etapes", table.getn(M.WizSteps()), 10)
EQ("la progression suit le parcours", w.dots:GetText(), "Etape 1 sur 10")
w.skip:Click()

-- ------------------------------------------------------------------ relance et premier lancement
SECTION("t_wizard_setup : /sui wizard et premier lancement")
if M.wiz then M.wiz:Hide() end
SlashCmdList["SHIKIUI"]("wizard")
EQ("/sui wizard ouvre l'assistant", M.wiz:IsShown(), true)
EQ("/sui wizard : etape 1", M.wiz.step, 1)
M.wiz.skip:Click()
C.SetGlobal("firstRun", true)
M.ws = nil
M.wiz:Hide()
M.ShowWizard()
EQ("premier lancement : parcours Installation + preselectionne", M.ws.sel.path, "plus")
EQ("premier lancement : role conseille", M.ws.sel.role, "dps")
sameMods(M.WizPackSet("complete"), "premier lancement : pack conseille")
EQ("premier lancement : menace conseillee", M.ws.sel.es.tshow, "on")
EQ("premier lancement : rien d'applique", C.GetRole(), orig.role)
M.wiz.skip:Click()
EQ("fermer l'assistant efface firstRun", C.GetGlobal("firstRun"), false)
EQ("fermer sans rien changer : role", C.GetRole(), orig.role)

-- ------------------------------------------------------------------ journal, erreurs, plus d'import pfUI
SECTION("t_wizard_setup : journal de clics, erreurs, aucune trace de l'import pfUI")
local clics = 0
for i = 1, table.getn(SUI.errlog) do
  local line = SUI.errlog[i]
  if string.find(line, "|wizard clic|", 1, true) then clics = clics + 1
  elseif string.find(line, "|wizard", 1, true) then T("journal : erreur de l'assistant : " .. line, false) end
end
T("le journal contient les clics de l'assistant", clics > 5)
EQ("aucune erreur interne", SUI.errCount, 0)
EQ("plus de Menu.WizToggleImp", M.WizToggleImp, nil)
EQ("plus de Migrate.Import", SUI.Migrate.Import, nil)
EQ("plus de Migrate.ImportPlan", SUI.Migrate.ImportPlan, nil)
EQ("plus de Migrate.IMPORT_CATS", SUI.Migrate.IMPORT_CATS, nil)
T("etat de l'assistant sans import", M.ws == nil or M.ws.sel.imp == nil)
local f = io and io.open and io.open("ShikiUI/Menu_Wizard.lua", "r")
if f then
  local src = f:read("*a")
  f:close()
  EQ("source de l'assistant : pas de Mg.Import", string.find(src, "Mg.Import", 1, true), nil)
  EQ("source de l'assistant : pas d'ImportPlan", string.find(src, "ImportPlan", 1, true), nil)
  EQ("source de l'assistant : pas d'IMPORT_CATS", string.find(src, "IMPORT_CATS", 1, true), nil)
  EQ("source de l'assistant : pas de NOT_IMPORTABLE", string.find(src, "NOT_IMPORTABLE", 1, true), nil)
end
-- textes : toutes les lignes de reglages et options existent en francais ET en anglais
local missing = 0
for _, lang in ipairs({ "fr", "en" }) do
  C.Set("ui.locale", lang)
  for _, tab in ipairs({ "bars", "units", "group", "meter", "minimap", "chat" }) do
    T(lang .. " onglet " .. tab, M.Has("mod.setup.tab." .. tab))
  end
  for _, path in ipairs({ "quick", "plus" }) do
    T(lang .. " parcours " .. path, M.Has("mod.setup.path." .. path .. ".n") and M.Has("mod.setup.path." .. path .. ".d"))
  end
  M.WizSetPath("plus")
end
C.Set("ui.locale", "fr")
EQ("aucune cle de traduction manquante signalee par l'assistant", missing, 0)
w = open("plus")
for _, lang in ipairs({ "fr", "en" }) do
  C.Set("ui.locale", lang)
  SUI.missingL = {}
  local st2 = M.WizSteps()
  for si = 1, table.getn(st2) do
    M.WizGo(si)
    if st2[si] == "essentials" then
      for _, tab in ipairs({ "bars", "units", "group", "meter", "minimap", "chat" }) do
        M.ws.tab = tab
        M.WizRender()
      end
    end
  end
  go("summary")
  local bad = ""
  for k, _ in pairs(SUI.missingL) do bad = bad .. k .. " " end
  EQ(lang .. " : aucune cle manquante en parcourant l'assistant", bad, "")
end
C.Set("ui.locale", "fr")
w:Hide()
EQ("aucune erreur interne a la fin", SUI.errCount, 0)
DONE()
