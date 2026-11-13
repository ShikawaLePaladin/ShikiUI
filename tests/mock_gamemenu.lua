-- mock_gamemenu.lua : menu Echap (GameMenuFrame) simule. MKGAMEMENU(opts) construit la fenetre telle que l'utilisateur la voit :
--   titre "Main Menu" ; "Donation Rewards" (ajoute par le serveur), [espace], "Options", "Key Bindings", "Macros", [espace], "Logout",
--   "Exit Game", [espace], "Return to Game" ; pas de boutons Video / Sound / Interface / Help.
-- Les valeurs (hauteur 21, ecart 1 px, espace 16 px) sont des DONNEES DE TEST, pas des mesures du client.
-- opts : buttons = liste de { texte, ecart avant } ; reverse = true (GetChildren renvoie les enfants a l'envers, comme un ordre quelconque) ;
--        absLast = true (le dernier bouton est pose en absolu sur le bas de la fenetre) ; bad = { ["GameMenuButtonTemplate"] = true } (modeles inconnus).
-- La geometrie (GetTop...) suit les ancrages quand W.layout = true (voir mock_layout.lua).
W = W or {}
W.gm = { bad = {} }

local prev = CreateFrame
CreateFrame = function(kind, name, parent, tmpl)
  if tmpl and W.gm.bad[tmpl] then error("Couldn't find XML template : " .. tostring(tmpl), 2) end
  local f = prev(kind, name, parent, tmpl)
  local gm = rawget(_G, "GameMenuFrame")
  if gm and parent == gm and gm.kids then
    table.insert(gm.kids, f)
    f.template = tmpl
  end
  return f
end

function MKGAMEMENU(opts)
  opts = opts or {}
  W.gm = { bad = {} }
  local specs = opts.buttons or {
    { "Donation Rewards", 0 }, { "Options", 16 }, { "Key Bindings", 1 }, { "Macros", 1 },
    { "Logout", 16 }, { "Exit Game", 1 }, { "Return to Game", 16 },
  }
  rawset(_G, "GameMenuFrame", nil)
  local f = CreateFrame("Frame", "GameMenuFrame", UIParent)
  f.kids = {}
  f.shown = false
  f:SetWidth(256)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f.GetChildren = function(self)
    if opts.reverse then
      local r = {}
      for i = table.getn(self.kids), 1, -1 do table.insert(r, self.kids[i]) end
      return table.unpack(r)
    end
    return table.unpack(self.kids)
  end
  f.GetNumChildren = function(self) return table.getn(self.kids) end
  CreateFrame("Frame", nil, f)    -- un enfant qui n'est pas un bouton
  local total = 30
  local last = nil
  for i = 1, table.getn(specs) do
    local b = CreateFrame("Button", "GameMenuButton" .. i, f, "GameMenuButtonTemplate")
    b:SetWidth(144)
    b:SetHeight(21)
    b:SetText(specs[i][1])
    if not last then
      b:SetPoint("TOP", f, "TOP", 0, -30)
    elseif opts.absLast and i == table.getn(specs) then
      b:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
    else
      b:SetPoint("TOP", last, "BOTTOM", 0, -specs[i][2])
      total = total + specs[i][2]
    end
    total = total + 21
    last = b
  end
  f:SetHeight(total + 16)
  W.gm.frame = f
  W.gm.bad = opts.bad or {}      -- modeles refuses seulement pour les boutons crees APRES la fenetre (ceux de l addon)
  return f
end

-- Fenetre cachee par HideUIPanel (aide du client)
HideUIPanel = function(fr) fr:Hide(); ACT("HideUIPanel") end

-- Position verticale (haut) d'un bouton, par nom de texte
function GMTOP(text)
  local f = rawget(_G, "GameMenuFrame")
  for i = 1, table.getn(f.kids) do
    if f.kids[i]:GetText() == text then return f.kids[i]:GetTop() end
  end
  return nil
end
