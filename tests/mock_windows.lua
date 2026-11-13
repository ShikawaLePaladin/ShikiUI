-- mock_windows : simulation des fenetres de Blizzard pour le module "windows" (chargee automatiquement par le harnais).
-- Ne contient QUE des noms d'API de WoW 1.12 (UIPanelWindows, ShowUIPanel, HideUIPanel, UpdateUIPanelPositions, IsShiftKeyDown...) et des
-- DONNEES DE TEST. Etat : W.win. Rien n'est defini au chargement : une suite appelle WININSTALL() AVANT BOOT().
-- Aides : WINFRAME(nom [, { onshow = fn, scale = n }]) cree un cadre Blizzard cache et l'inscrit dans UIPanelWindows
-- WINMODS(shift, ctrl, alt) WINDOWN(f [, bouton]) WINUP(f [, bouton]) (appellent OnMouseDown / OnMouseUp comme le client : this, arg1)
-- WINDRAG(f, gauche, bas [, bouton]) (appui + deplacement simule + relache) WINSHOW(f) (ShowUIPanel) WINHIDE(f).

W.win = { mods = {}, updates = 0 }

function WINMODS(s, c, a) W.win.mods = { shift = s and true or false, ctrl = c and true or false, alt = a and true or false } end

function WININSTALL()
  W.win = { mods = {}, updates = 0 }
  rawset(_G, "IsShiftKeyDown", function() return W.win.mods.shift and 1 or nil end)
  rawset(_G, "IsControlKeyDown", function() return W.win.mods.ctrl and 1 or nil end)
  rawset(_G, "IsAltKeyDown", function() return W.win.mods.alt and 1 or nil end)
  rawset(_G, "UIPanelWindows", {})
  rawset(_G, "UpdateUIPanelPositions", function(f)
    W.win.updates = W.win.updates + 1
    -- comme Blizzard : replace les panneaux a gauche de l'ecran
    for name in pairs(UIPanelWindows) do
      local p = rawget(_G, name)
      if p and p:IsShown() then
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", "UIParent", "TOPLEFT", 16, -104)
      end
    end
  end)
  rawset(_G, "ShowUIPanel", function(f)
    f:Show()
    UpdateUIPanelPositions(f)
  end)
end

function WINFRAME(name, opt)
  opt = opt or {}
  local f = CreateFrame("Frame", name, UIParent)
  f:SetWidth(300)
  f:SetHeight(400)
  f:EnableMouse(true)
  f:Hide()
  if opt.onshow then f:SetScript("OnShow", opt.onshow) end
  if opt.scale then f:SetScale(opt.scale) end
  UIPanelWindows[name] = { area = "left", pushable = 1 }
  return f
end

local function fire(f, script, button)
  local o, oa = this, arg1
  this = f
  arg1 = button or "LeftButton"
  local fn = f:GetScript(script)
  if fn then fn() end
  this, arg1 = o, oa
end

function WINDOWN(f, button) fire(f, "OnMouseDown", button) end
function WINUP(f, button) fire(f, "OnMouseUp", button) end

function WINDRAG(f, left, bottom, button)
  fire(f, "OnMouseDown", button)
  f.left, f.bottom = left, bottom
  fire(f, "OnMouseUp", button)
end

function WINSHOW(f) ShowUIPanel(f) end
function WINHIDE(f) f:Hide() end
