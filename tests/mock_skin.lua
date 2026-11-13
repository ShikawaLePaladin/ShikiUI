-- mock_skin : extension de simulation du module "skin" (chargee automatiquement par le harnais).
-- Fabrique de faux cadres Blizzard : regions (textures / chaines) listees par GetRegions, enfants par GetChildren, textures d'etat des boutons.
-- Noms d'API 1.12 seulement ; les noms de cadres sont des DONNEES DE TEST.

NORMAL_FONT_COLOR = { r = 1, g = 0.5, b = 0.25 }

-- Texture avec chemin lisible ; enregistree comme region du parent si reg ~= false.
function SKIN_TEX(parent, name, path, reg)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t.name = name
  t.path = path
  t.GetTexture = function(s) return s.path end
  t.SetTexture = function(s, p) s.path = p end
  t.GetWidth = function(s) return s.w end
  if reg ~= false then
    parent.regs = parent.regs or {}
    table.insert(parent.regs, t)
  end
  return t
end

function SKIN_FS(parent, name, size, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs.name = name
  if name then rawset(_G, name, fs) end
  fs.font, fs.fsize, fs.fflags = "Fonts\\FRIZQT__.TTF", size or 12, flags or ""
  fs.GetFont = function(s) return s.font, s.fsize, s.fflags end
  parent.regs = parent.regs or {}
  table.insert(parent.regs, fs)
  return fs
end

-- Cadre simule : regions et enfants listes, IsEnabled / GetFontString utilisables.
function SKIN_FRAME(name, kind, parent)
  local f = CreateFrame(kind or "Frame", name, parent or UIParent)
  f.regs, f.kids = {}, {}
  f.GetRegions = function(s) return table.unpack(s.regs) end
  f.GetChildren = function(s) return table.unpack(s.kids) end
  f.IsEnabled = function(s) if s.enabled == false then return nil end return 1 end
  f.GetFontString = function(s) return s.fs end
  if parent and parent.kids then table.insert(parent.kids, f) end
  return f
end

-- Bouton de panneau : Left / Middle / Right + textures d'etat, un texte et sa chaine.
function SKIN_BTN(name, parent, text)
  local b = SKIN_FRAME(name, "Button", parent)
  b:SetText(text or "OK")
  b.fs = SKIN_FS(b, nil, 12)
  b.ntex = SKIN_TEX(b, nil, "Interface\\Buttons\\UI-Panel-Button-Up", false)
  b.ptex = SKIN_TEX(b, nil, "Interface\\Buttons\\UI-Panel-Button-Down", false)
  b.htex = SKIN_TEX(b, nil, "Interface\\Buttons\\UI-Panel-Button-Highlight", false)
  b.dtex = SKIN_TEX(b, nil, "Interface\\Buttons\\UI-Panel-Button-Disabled", false)
  b.GetNormalTexture = function(s) return s.ntex end
  b.GetPushedTexture = function(s) return s.ptex end
  b.GetHighlightTexture = function(s) return s.htex end
  b.GetDisabledTexture = function(s) return s.dtex end
  b.Left = SKIN_TEX(b, name and (name .. "Left") or nil, "Interface\\Buttons\\UI-Panel-Button-Left")
  b.Middle = SKIN_TEX(b, name and (name .. "Middle") or nil, "Interface\\Buttons\\UI-Panel-Button-Middle")
  return b
end

-- Case d'objet : icone (region nommee ...IconTexture) + bordure Quickslot en texture normale.
function SKIN_SLOT(name, parent, normalPath)
  local b = SKIN_FRAME(name, "Button", parent)
  b.icon = SKIN_TEX(b, name .. "IconTexture", "Interface\\Icons\\INV_Misc_QuestionMark")
  b.ntex = SKIN_TEX(b, nil, normalPath or "Interface\\Buttons\\UI-Quickslot2", false)
  b.ptex = SKIN_TEX(b, nil, "Interface\\Buttons\\UI-Quickslot-Depress", false)
  b.GetNormalTexture = function(s) return s.ntex end
  b.GetPushedTexture = function(s) return s.ptex end
  return b
end

-- Barre de defilement : curseur avec sa texture de poignee.
function SKIN_SCROLL(name, parent)
  local s = SKIN_FRAME(name, "Slider", parent)
  s.thumb = SKIN_TEX(s, nil, "Interface\\Buttons\\UI-ScrollBar-Knob", false)
  s.thumb.w, s.thumb.h = 18, 24
  s.thumb.SetWidth = function(t, w) t.w = w end
  s.thumb.SetHeight = function(t, h) t.h = h end
  s.thumb.GetHeight = function(t) return t.h end
  s.GetThumbTexture = function(x) return x.thumb end
  s.GetOrientation = function() return "VERTICAL" end
  return s
end

PanelTemplates_SelectTab = function(tab) tab.enabled = false end
PanelTemplates_DeselectTab = function(tab) tab.enabled = true end
