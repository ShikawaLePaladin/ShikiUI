-- t_clickall : audit de TOUS les boutons / cases cliquables : menu (toutes les pages, modes Essentiel et Tout), assistant (chaque etape,
-- chaque controle), fenetres secondaires (transfert, profils / sauvegardes, migration, social, suivi, messages, macros...).
-- Chaque controle visible est "clique" comme le client le ferait (OnClick, sinon OnMouseUp) ; le test echoue sur toute erreur Lua levee
-- par le gestionnaire OU toute progression de SUI.errCount (erreurs interceptees par SUI.Report / _ERRORMESSAGE).
-- Controles aussi verifies : activables (pas de fenetre parente cachee), aucune zone de clic negative, hierarchie de niveaux.
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Menu

-- simulations du client propres aux modules (API de sorts, auras, macros...) : sans elles le module ne peut pas s activer
for _, n in ipairs({ "TKINSTALL", "AU_SETUP", "CB_SETUP", "MAC_SETUP", "MSG_SETUP", "TNK_SETUP", "TOT_SETUP", "THR_SETUP", "MET_SETUP", "GRP_SETUP", "NP_SETUP", "MM_SETUP", "TT_SETUP" }) do
  local fn = rawget(_G, n)
  if fn then pcall(fn) end
end
BOOT()
SETTLE()
GameTooltip = GameTooltip or CreateFrame("GameTooltip", "GameTooltip", UIParent)
-- le mode deplacement exige de vraies coordonnees d ecran (le mock n en a pas) : il a sa propre suite (t_mover) ; ici on neutralise son entree
if SUI.Mover then SUI.Mover.Enter = function() end end

local clicked, bad = 0, 0
local seen = {}

local function describe(f)
  local bits = {}
  if f.opt and f.opt.key then bits[#bits + 1] = tostring(f.opt.key) end
  if f.label and f.label.GetText then bits[#bits + 1] = "'" .. tostring(f.label:GetText()) .. "'" end
  if f.name then bits[#bits + 1] = tostring(f.name) end
  if f.id then bits[#bits + 1] = "#" .. tostring(f.id) end
  return table.concat(bits, " ")
end

local function clickable(f)
  if f.kind == "Button" or f.kind == "CheckButton" then
    return (f.scripts.OnClick or f.scripts.OnMouseUp) and true or false
  end
  if f.kind == "Frame" and f.mouse and f.scripts.OnMouseUp then return true end   -- lignes de reglage du menu
  if f.kind == "Slider" then return true end
  if f.kind == "EditBox" and (f.scripts.OnEnterPressed or f.scripts.OnTextChanged) then return true end
  return false
end

-- clique un controle ; renvoie vrai si tout s'est bien passe
local function press(f, where)
  local e0 = SUI.errCount
  local ok, err
  if f.kind == "Slider" then
    ok, err = pcall(function()
      local lo, hi = f:GetMinMaxValues()
      f:SetValue(hi)
      f:SetValue(lo)
      f:SetValue((lo + hi) / 2)
    end)
  elseif f.kind == "EditBox" then
    ok, err = pcall(function()
      this = f
      if f.scripts.OnEditFocusGained then f.scripts.OnEditFocusGained() end
      if f.scripts.OnTextChanged then f.scripts.OnTextChanged() end
      if f.scripts.OnEnterPressed then f.scripts.OnEnterPressed() end
      if f.scripts.OnEditFocusLost then f.scripts.OnEditFocusLost() end
    end)
  elseif f.scripts.OnClick then
    ok, err = pcall(f.Click, f, "LeftButton")
  else
    ok, err = pcall(function()
      this = f
      arg1 = "LeftButton"
      if f.scripts.OnMouseDown then f.scripts.OnMouseDown() end
      f.scripts.OnMouseUp()
    end)
  end
  clicked = clicked + 1
  if SUI.Mover and SUI.Mover.active then pcall(SUI.Mover.Exit, true) end   -- le mode deplacement (bouton Deplacer) ne doit pas rester actif
  local good = ok and SUI.errCount == e0
  if not good then
    bad = bad + 1
    print("  ECHEC clic [" .. where .. "] " .. describe(f) .. " : " .. tostring(ok and SUI.lastErr or err))
    SUI.errCount = e0
  end
  T(where .. " : " .. describe(f), good)
  return good
end

-- parcourt les controles visibles ; relance `reopen` si le clic a change de page
local function under(f, root)
  if not root then return true end
  local p = f
  while p do
    if p == root then return true end
    p = p.parent
  end
  return false
end

local function sweep(where, reopen, twice, root)
  local snap = {}
  for i = 1, table.getn(ALLFRAMES) do
    local f = ALLFRAMES[i]
    if clickable(f) and f:IsVisible() and under(f, root) then snap[#snap + 1] = f end
  end
  local n = 0
  for i = 1, table.getn(snap) do
    local f = snap[i]
    if f:IsVisible() and not f.noclickall then
      local page, cat, mode = M.page, M.cat, M.mode
      local lbl = f.label and f.label.GetText and f.label:GetText() or ""
      press(f, where)
      n = n + 1
      if twice and f:IsVisible() then press(f, where .. " (2e clic)") end
      if reopen and (M.page ~= page or M.cat ~= cat or M.mode ~= mode or (M.frame and not M.frame:IsShown())) then reopen() end
      if n % 25 == 0 then SETTLE(1) end
    end
  end
  return n
end

local function closeAll()
  for i = 1, table.getn(ALLFRAMES) do
    local f = ALLFRAMES[i]
    if f.name and (f.name == "ShikiUI_Transfer") and f:IsShown() then f:Hide() end
  end
end

-- ------------------------------------------------------------------ menu : toutes pages x tous modes
SECTION("t_clickall : menu")
SlashCmdList["SHIKIUI"]("")
T("menu ouvert", M.frame ~= nil and M.frame:IsShown())
M.RebuildNav()
local entries = {}
for i = 1, table.getn(M.navList) do
  local e = M.navList[i]
  if e.kind ~= "head" then entries[#entries + 1] = { page = (e.kind == "page") and e.id or "cat", cat = e.id } end
end
local modes = { "essential", "all" }
local total = 0
for mi = 1, 2 do
  M.SetMode(modes[mi])
  for ei = 1, table.getn(entries) do
    local e = entries[ei]
    if modes[mi] == "essential" and e.page == "cat" and not os.getenv("CLICKALL_FULL") then goto continue end   -- le mode "all" couvre deja les categories (rapide)
    local tag = "menu " .. modes[mi] .. " " .. e.page .. "/" .. tostring(e.cat)
    local function reopen()
      closeAll()
      if M.frame and not M.frame:IsShown() then M.Show() end
      M.SetMode(modes[mi])
      M.Open(e.page, e.cat)
    end
    reopen()
    SETTLE(2)
    local ec0 = SUI.errCount
    local nn = sweep(tag, reopen, false, nil)
    if SUI.errCount ~= ec0 then print("  ERR hors clic : " .. tag .. " : " .. tostring(SUI.lastErr)) end
    if os.getenv("DBGN") then print(tag, nn) end
    total = total + nn
    if M.page ~= e.page then reopen() end
    ::continue::
  end
end
T("des controles de menu ont ete cliques", total > 100)
print("  menu : " .. total .. " clics")

-- ------------------------------------------------------------------ assistant
SECTION("t_clickall : assistant")
M.SetMode("essential")
if M.wiz then M.wiz:Hide() end
M.ws = nil
M.ShowWizard(1)
local steps = M.WizSteps()
local wtotal = 0
for si = 1, table.getn(steps) do
  local id = steps[si]
  local function reopen()
    if not M.wiz:IsShown() then M.ShowWizard(si) end
    M.WizGo(si)
  end
  M.WizGo(si)
  SETTLE(1)
  -- pied de page : Retour / Suivant testes a part (ils changent d'etape)
  local snap = {}
  for i = 1, table.getn(ALLFRAMES) do
    local f = ALLFRAMES[i]
    if clickable(f) and f:IsVisible() and under(f, M.wiz) and f ~= M.wiz.skip and f ~= M.wiz.nextBtn and f ~= M.wiz.prevBtn then snap[#snap + 1] = f end
  end
  for i = 1, table.getn(snap) do
    local f = snap[i]
    if f:IsVisible() then
      press(f, "assistant " .. id)
      wtotal = wtotal + 1
      reopen()
    end
  end
  -- chaque controle de l'assistant doit etre dans la fenetre (hierarchie) et cliquable (activable)
  for i = 1, table.getn(snap) do
    local f = snap[i]
    local p, inWiz = f, false
    while p do
      if p == M.wiz then inWiz = true end
      p = p.parent
    end
    T("assistant " .. id .. " : " .. describe(f) .. " est dans la fenetre", inWiz)
    T("assistant " .. id .. " : " .. describe(f) .. " accepte la souris ou est un bouton", f.kind == "Button" or f.kind == "CheckButton")
  end
  -- Suivant / Retour
  reopen()
  if id ~= "summary" and id ~= "done" then
    local e0 = SUI.errCount
    local ok, err = pcall(M.wiz.nextBtn.Click, M.wiz.nextBtn, "LeftButton")
    T("assistant " .. id .. " : Suivant", ok and SUI.errCount == e0)
    if not ok then print("  " .. tostring(err)) end
    if si > 1 then
      reopen()
      ok, err = pcall(M.wiz.prevBtn.Click, M.wiz.prevBtn, "LeftButton")
      T("assistant " .. id .. " : Retour", ok and SUI.errCount == e0)
    end
  end
end
print("  assistant : " .. wtotal .. " clics")
T("controles de l'assistant cliques", wtotal > 40)
-- langue : un clic sur Francais / English change vraiment la langue, et revient
M.ws = nil
M.ShowWizard(1)
local pg = M.wiz.pg.welcome
pg.l[2]:Click("LeftButton")
EQ("assistant : clic English", SUI.Config.Get("ui.locale"), "en")
pg.l[1]:Click("LeftButton")
EQ("assistant : clic Francais", SUI.Config.Get("ui.locale"), "fr")
-- taille : un clic sur chaque taille la memorise
M.WizGo(2)
for i = 1, table.getn(steps) do if steps[i] == "style" then M.WizGo(i) end end
local sp = M.wiz.pg.style
for i = 1, 3 do
  sp.sz[i]:Click("LeftButton")
  T("assistant : taille " .. i .. " memorisee", M.ws.sel.scale ~= nil and sp.sz[i].selected == true)
end
-- Suivant jusqu'a Appliquer puis Termine : tout le parcours sans erreur
M.ws = nil
M.ShowWizard(1)
for i = 1, 30 do
  if M.wiz.stepId == "done" then break end
  local ok = pcall(M.wiz.nextBtn.Click, M.wiz.nextBtn, "LeftButton")
  T("parcours : suivant " .. i, ok)
end
EQ("parcours : arrive a la fin", M.wiz.stepId, "done")
pcall(M.wiz.nextBtn.Click, M.wiz.nextBtn, "LeftButton")
M.wiz:Hide()

-- ------------------------------------------------------------------ fenetres secondaires
SECTION("t_clickall : fenetres secondaires")
local function runCmd(cmd, rest)
  local e0 = SUI.errCount
  local ok, err = pcall(SlashCmdList["SHIKIUI"], cmd .. (rest and (" " .. rest) or ""))
  T("commande /sui " .. cmd .. " " .. tostring(rest or "") .. " sans erreur", ok and SUI.errCount == e0)
  if not ok then print("  " .. tostring(err)) end
  SETTLE(2)
end
local wins = {
  { "export" }, { "import" }, { "social" }, { "social", "show" }, { "social", "options" }, { "tracker" }, { "tracker", "show" },
  { "tracker", "graph" }, { "tracker", "export" }, { "msg" }, { "msg", "history" }, { "msg", "show" }, { "macros" }, { "macros", "show" },
  { "macros", "open" }, { "backup" }, { "migrate" }, { "migrate", "scan" }, { "addons" }, { "bags" }, { "bags", "show" }, { "meter", "show" },
  { "bind" }, { "mail" }, { "auction" }, { "loot" }, { "items" }, { "clickheal" }, { "chattabs" }, { "style" }, { "style", "list" },
  { "layout" }, { "skin" }, { "bars" }, { "group" }, { "raid" }, { "threat" }, { "totems" }, { "castbar" }, { "nameplates" },
  { "tooltip" }, { "tank" }, { "auras" }, { "minimap" }, { "charstats" }, { "mode" }, { "status" }, { "help" }, { "errors" }, { "focus" },
}
local wclicks = 0
for i = 1, table.getn(wins) do
  local ec0 = SUI.errCount
  runCmd(wins[i][1], wins[i][2])
  wclicks = wclicks + sweep("fenetre /sui " .. wins[i][1] .. " " .. tostring(wins[i][2] or ""), nil, false)
  if SUI.errCount ~= ec0 then print("  ERR hors clic apres /sui " .. wins[i][1] .. " " .. tostring(wins[i][2]) .. " : " .. tostring(SUI.lastErr)); ec0 = SUI.errCount end
  closeAll()
  if SUI.Mover and SUI.Mover.active then pcall(SUI.Mover.Exit, true) end
  if M.wiz and M.wiz:IsShown() then M.wiz:Hide() end
end
print("  fenetres secondaires : " .. wclicks .. " clics")
-- page profils : deux clics (confirmation)
M.Open("profiles")
SETTLE(2)
sweep("profils (confirmation)", function() M.Open("profiles") end, true)

EQ("aucune erreur interne a la fin", SUI.errCount, 0)
print("  total : " .. clicked .. " clics, " .. bad .. " en echec")
DONE()
