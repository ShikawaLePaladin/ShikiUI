-- mock_bulletin : extension de simulation du module "bulletin" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : BULL_SETUP() (appelee par t_bulletin.lua seulement) cree la table globale DBB2 comme le fait
-- DifficultBulletinBoard 2.40 (noms relevees dans l'addon installe) : DBB2.gui (cadre "DBB2ConfigGUI", cache), DBB2.gui.backdrop, DBB2.gui.close
-- et DBB2.gui.configBtn avec leur .backdrop, DBB2:CreateBackdrop(cadre, inset, legacy, transp) qui (re)pose les couleurs propres a DBB.
-- Aides : BULL_SETUP() BULL_REMOVE() BULL_NOWINDOW() (DBB charge mais sans fenetre) ; compteurs DBB2.shows / DBB2.hides / DBB2.backdrops.
-- Valeurs de couleur = DONNEES DE TEST (celles de DBB).
ALLOW("DBB2")

local function withBackdrop(f)
  f.backdrop = CreateFrame("Frame", nil, f)
  return f
end

function BULL_SETUP()
  local d = { shows = 0, hides = 0, backdrops = 0, config = {} }
  d.CreateBackdrop = function(self, f, inset, legacy, transp)
    d.backdrops = d.backdrops + 1
    if not f.backdrop then f.backdrop = CreateFrame("Frame", nil, f) end
    f.backdrop:SetBackdropColor(0.08, 0.08, 0.10, transp or 0.85)
    f.backdrop:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
  end
  local gui = CreateFrame("Frame", "DBB2ConfigGUI", UIParent)
  gui:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  gui:Hide()
  withBackdrop(gui)
  gui.close = withBackdrop(CreateFrame("Button", "DBB2Close", gui))
  gui.configBtn = withBackdrop(CreateFrame("Button", "DBB2ConfigBtn", gui))
  gui:SetScript("OnShow", function() d.shows = d.shows + 1 end)
  gui:SetScript("OnHide", function() d.hides = d.hides + 1 end)
  d.gui = gui
  DBB2 = d
  d:CreateBackdrop(gui, nil, nil, 0.85)
  d:CreateBackdrop(gui.close)
  d:CreateBackdrop(gui.configBtn)
  d.backdrops = 0
end

function BULL_NOWINDOW()
  DBB2 = { config = {} }
end

function BULL_REMOVE()
  DBB2 = nil
end
