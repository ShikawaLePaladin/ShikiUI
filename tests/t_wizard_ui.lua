-- t_wizard_ui : cibles de clic de l'assistant (Menu_Wizard.lua) : taille minimale, bornes de la page, aucun chevauchement,
-- gestionnaire de clic branche, niveaux de frame / strate coherents (assistant AU-DESSUS du menu, meme leve pour le mode deplacement),
-- retour visuel au survol et a l'appui. Les deux parcours (Rapide / Installation +) et chaque onglet des reglages essentiels.
local SUI = ShikiUI
local C = SUI.Config
local M = SUI.Menu

BOOT()
SETTLE()
SECTION("t_wizard_ui : cibles de clic")
if M.wiz then M.wiz:Hide() end
M.ws = nil
M.ShowWizard(1)
local w = M.wiz
local WW, WH = w:GetWidth(), w:GetHeight()
local TOPMIN, BOTMAX = 146, WH - 46 - 2    -- sous l'en-tete, au-dessus des boutons de pied de page

local function collect(pg)
  local t = {}
  local function add(b) if b then t[table.getn(t) + 1] = b end end
  local function list(l) if l then for i = 1, table.getn(l) do add(l[i]) end end end
  list(pg.l) list(pg.path) list(pg.mig) list(pg.sb) list(pg.sz) list(pg.lc) list(pg.mode) list(pg.rb) list(pg.pk) list(pg.slot) list(pg.tabs)
  add(pg.pageBtn) add(pg.now) add(pg.auto) add(pg.keep) add(pg.hours) add(pg.logout)
  if pg.sr then for i = 1, table.getn(pg.sr) do list(pg.sr[i]) end end
  for _, k in ipairs({ "rows", "pb" }) do
    local l = pg[k]
    if l then
      for i = 1, table.getn(l) do
        local r = l[i]
        if r.b then
          if r.b.GetWidth then add(r.b) else list(r.b) end
        end
      end
    end
  end
  return t
end

local function rect(b)
  local _, _, _, x, y = b:GetPoint(1)
  return x, -y, x + b:GetWidth(), -y + b:GetHeight()
end

local total = 0
local function checkPage(id, label)
  local pg = w.pg[id]
  EQ(label .. " : la page ne capte pas la souris", pg:IsMouseEnabled(), nil)
  local shown = {}
  local all = collect(pg)
  for i = 1, table.getn(all) do
    local b = all[i]
    if b:IsShown() then shown[table.getn(shown) + 1] = b end
  end
  for i = 1, table.getn(shown) do
    local b = shown[i]
    local x0, y0, x1, y1 = rect(b)
    total = total + 1
    local tag = label .. " #" .. i
    T(tag .. " : hauteur >= 24", b:GetHeight() >= 24)
    T(tag .. " : largeur >= 24", b:GetWidth() >= 24)
    T(tag .. " : dans les bornes (gauche/droite)", x0 >= 0 and x1 <= WW)
    T(tag .. " : dans les bornes (haut/bas)", y0 >= TOPMIN - 1 and y1 <= BOTMAX)
    T(tag .. " : clic branche", b:GetScript("OnClick") ~= nil)
    T(tag .. " : survol branche", b:GetScript("OnEnter") ~= nil and b:GetScript("OnLeave") ~= nil)
    T(tag .. " : appui branche", b:GetScript("OnMouseDown") ~= nil and b:GetScript("OnMouseUp") ~= nil)
    for j = i + 1, table.getn(shown) do
      local a0, b0, a1, b1 = rect(shown[j])
      local over = x0 < a1 and a0 < x1 and y0 < b1 and b0 < y1
      T(tag .. " / #" .. j .. " : pas de chevauchement", not over)
    end
  end
end

for _, path in ipairs({ "plus", "quick" }) do
  M.WizSetPath(path)
  local steps = M.WizSteps()
  for si = 1, table.getn(steps) do
    M.WizGo(si)
    local id = steps[si]
    if id == "essentials" then
      -- chaque onglet a ses propres lignes
      local seen = 0
      for _, tab in ipairs({ "bars", "units", "group", "meter", "minimap", "chat" }) do
        if table.getn(M.WizTabRows(tab)) > 0 then
          M.ws.tab = tab
          M.WizRender()
          seen = seen + 1
          checkPage(id, path .. " " .. id .. "/" .. tab)
        end
      end
      T(path .. " : des onglets de reglages essentiels", seen >= 4)
    else
      checkPage(id, path .. " " .. id)
    end
  end
end
T("des controles ont ete verifies", total > 100)
M.WizSetPath("plus")

-- pied de page
for _, k in ipairs({ "skip", "prevBtn", "defBtn", "passBtn", "nextBtn", "pathBtn" }) do
  local b = w[k]
  T(k .. " : hauteur >= 24", b:GetHeight() >= 24)
  T(k .. " : au-dessus des pages", b:GetFrameLevel() > w.pg.welcome:GetFrameLevel())
  T(k .. " : clic branche", b:GetScript("OnClick") ~= nil)
end
local foot = { "skip", "prevBtn", "defBtn", "passBtn", "nextBtn" }
for i = 1, table.getn(foot) do
  local a = w[foot[i]]
  local _, _, _, ax = a:GetPoint(1)
  T(foot[i] .. " : dans la fenetre", ax >= 0 and ax + a:GetWidth() <= WW)
  for j = i + 1, table.getn(foot) do
    local b = w[foot[j]]
    local _, _, _, bx = b:GetPoint(1)
    T("pied : " .. foot[i] .. " / " .. foot[j] .. " sans chevauchement", ax + a:GetWidth() <= bx or bx + b:GetWidth() <= ax)
  end
end
-- en-tete : titre, bouton de parcours, progression ne se chevauchent pas
local _, _, _, px = w.pathBtn:GetPoint(1)
local _, _, _, dx = w.dots:GetPoint(1)
T("en-tete : parcours / progression", px + w.pathBtn:GetWidth() <= dx)
T("en-tete : parcours dans la fenetre", px + w.pathBtn:GetWidth() <= WW)
-- niveaux et strate
for id, pg in pairs(w.pg) do T("page " .. id .. " : niveau > fenetre", pg:GetFrameLevel() > w:GetFrameLevel()) end

-- l'assistant est au-dessus du menu, y compris leve pour le mode deplacement : niveau le plus haut d'un descendant du menu < niveau de l'assistant
local function maxLevel(fr, seen)
  seen = seen or {}
  if seen[fr] then return 0 end
  seen[fr] = true
  local m = fr:GetFrameLevel()
  if fr.GetChildren then
    local kids = { fr:GetChildren() }
    for i = 1, table.getn(kids) do
      local v = maxLevel(kids[i], seen)
      if v > m then m = v end
    end
  end
  return m
end
M.Show("essential")
SETTLE()
M.SetRaised(true)
T("menu leve : niveau maximal < niveau de l'assistant", maxLevel(M.frame) < w:GetFrameLevel())
M.SetRaised(false)
T("menu normal : niveau maximal < niveau de l'assistant", maxLevel(M.frame) < w:GetFrameLevel())
M.Hide()

-- le survol d'un module / pack / style garde le retour visuel de Theme.lua (bordure d'accent)
M.WizGo(1)
local steps = M.WizSteps()
for i = 1, table.getn(steps) do if steps[i] == "modules" then M.WizGo(i) end end
local sl = w.pg.modules.slot[1]
sl.kind = nil
sl:GetScript("OnEnter")()
local ar, ag, ab = SUI.Theme.Accent()
NEAR("survol d'un module : bordure d'accent", sl.bc and sl.bc[1] or ar, ar)
sl:GetScript("OnMouseDown")()
sl:GetScript("OnMouseUp")()
-- un clic sur chaque carte de la page des modules agit
local mod
for i = 1, 10 do if w.pg.modules.slot[i]:IsShown() and w.pg.modules.slot[i].mod then mod = w.pg.modules.slot[i] break end end
local before = M.ws.sel.mods[mod.mod]
mod:Click()
EQ("un clic sur un module bascule", M.ws.sel.mods[mod.mod], not before)
M.WizFit()
T("ajustement a l ecran sans erreur", true)
w:Hide()
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
