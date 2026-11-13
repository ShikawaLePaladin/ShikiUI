-- mock_minimap : extension de simulation du module "minimap" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : MM_SETUP() (appele par t_minimap.lua seulement) cree la Minimap, ses decors et les fonctions du client,
-- pour ne rien changer aux autres suites. Noms d'API releves dans le pfUI installe (modules/minimap.lua, addonbuttons.lua) :
-- Minimap:SetMaskTexture, Minimap:EnableMouseWheel, Minimap_ZoomIn / Minimap_ZoomOut, MinimapBorder, MinimapZoomIn, MinimapZoomOut,
-- MiniMapWorldMapButton, MinimapToggleButton, MinimapZoneTextButton, GameTimeFrame, GetPlayerMapPosition, SetMapToCurrentZone,
-- GetMinimapZoneText, GetZonePVPInfo, WorldMapFrame ; GetGameTime (API 1.12 standard). Valeurs = DONNEES DE TEST.
ALLOW("MMAP")

function MM_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  if rawget(_G, "date") == nil then
    G("date", function(fmt)
      local s = fmt
      s = string.gsub(s, "%%H", "14")
      s = string.gsub(s, "%%M", "05")
      return s
    end)
  end
  MMAP = { x = 0.4567, y = 0.5, zone = "Elwynn", pvp = "friendly", hour = 9, minute = 7, mapSet = 0, zoomed = {} }
  local cluster = CreateFrame("Frame", "MinimapCluster", UIParent)
  local mm = CreateFrame("Frame", "Minimap", cluster)
  mm.parent = cluster
  mm:SetPoint("TOPRIGHT", cluster, "TOPRIGHT", 0, 0)
  mm:SetWidth(140)
  mm:SetHeight(140)
  mm.kids = {}
  mm.zoom = 0
  mm.GetZoom = function(self) return self.zoom end
  mm.SetZoom = function(self, z) self.zoom = z end
  mm.SetMaskTexture = function(self, t) self.mask = t end
  mm.SetParent = function(self, p) self.parent = p end
  -- comme le client : GetChildren / GetNumChildren = les cadres (pas les regions) dont le parent est ce cadre, a l'instant T
  local function kidsOf(self)
    local out = {}
    for i = 1, table.getn(ALLFRAMES) do
      local f = ALLFRAMES[i]
      if f.parent == self and (f.kind == "Frame" or f.kind == "Button" or f.kind == "GameTooltip") then table.insert(out, f) end
    end
    return out
  end
  local function giveKids(f)
    f.GetChildren = function(self) return table.unpack(kidsOf(self)) end
    f.GetNumChildren = function(self) return table.getn(kidsOf(self)) end
  end
  giveKids(mm)
  giveKids(cluster)
  giveKids(UIParent)
  mm.EnableMouseWheel = function(self, v) self.wheelOn = v and true or false end
  for _, name in ipairs({ "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut", "MinimapToggleButton",
      "MiniMapWorldMapButton", "MinimapZoneTextButton", "GameTimeFrame", "MiniMapTracking", "MiniMapMeetingStoneFrame" }) do
    local bf = CreateFrame("Frame", name, cluster)
    bf:SetWidth(24)
    bf:SetHeight(24)
    bf:SetPoint("TOPRIGHT", cluster, "TOPRIGHT", -10, -10)
  end
  CreateFrame("Frame", "WorldMapFrame", UIParent):Hide()
  G("GetPlayerMapPosition", function(unit) return MMAP.x, MMAP.y end)
  G("GetMinimapZoneText", function() return MMAP.zone end)
  G("GetZonePVPInfo", function() return MMAP.pvp end)
  G("MouseIsOver", function(f) return MMAP.over ~= nil and MMAP.over == f or nil end)
  G("GetGameTime", function() return MMAP.hour, MMAP.minute end)
  G("SetMapToCurrentZone", function() MMAP.mapSet = MMAP.mapSet + 1 end)
  G("Minimap_ZoomIn", function() Minimap.zoom = Minimap.zoom + 1; table.insert(MMAP.zoomed, "in") end)
  G("Minimap_ZoomOut", function() Minimap.zoom = Minimap.zoom - 1; table.insert(MMAP.zoomed, "out") end)
end

-- MM_BUTTON(nom, cliquable, taille, parent, genre) : un bouton d'addon pose sur la Minimap (comme LibDBIcon ou un addon maison).
-- parent = UIParent : cree sous UIParent puis ancre a la Minimap ; genre = "Frame" : cadre avec OnMouseUp au lieu d'un Button.
function MM_BUTTON(name, clickable, size, parent, kind)
  local b = CreateFrame(kind or "Button", name, parent or Minimap)
  b.SetParent = function(self, p) self.parent = p end
  b:SetWidth(size or 31)
  b:SetHeight(size or 31)
  b:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 5, -5)
  if clickable ~= false then
    if kind == "Frame" then b:SetScript("OnMouseUp", function() end) else b:SetScript("OnClick", function() end) end
  end
  table.insert(Minimap.kids, b)
  return b
end
