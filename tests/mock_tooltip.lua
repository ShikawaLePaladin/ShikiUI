-- mock_tooltip : extension de simulation du module "tooltip" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : TT_SETUP() (appele par t_tooltip.lua seulement) cree GameTooltip, ses lignes et les fonctions du
-- client. Noms d'API releves dans le pfUI installe (libs/libtooltip.lua, modules/tooltip.lua) et les addons de l'utilisateur :
-- GameTooltipTextLeftN, GameTooltipStatusBar, GameTooltip_SetDefaultAnchor, GameTooltip:Set<...>Item, GetContainerItemLink,
-- GetInventoryItemLink, GetItemInfo, UnitReaction, UnitReactionColor, UnitPVPName, ITEM_QUALITY_COLORS ; GetItemLevel (Nampower).
-- Valeurs = DONNEES DE TEST.
ALLOW("TT")

local function fire(frameParent, script)
  for i = 1, table.getn(ALLFRAMES) do
    local f = ALLFRAMES[i]
    if f.parent == frameParent and f.scripts[script] then
      this = f
      f.scripts[script]()
    end
  end
end

function TT_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  TT = { items = {}, bag = {}, origCalls = 0, hyper = 0 }
  local gt = CreateFrame("GameTooltip", "GameTooltip", UIParent)
  gt.shown = false
  gt.n = 0
  gt.owner = nil
  gt.anchor = nil
  for i = 1, 14 do CreateFrame("Frame", "GameTooltipTextLeft" .. i, gt) end
  CreateFrame("StatusBar", "GameTooltipStatusBar", gt)
  local function clear(self)
    self.n = 0
    for i = 1, 14 do
      local fs = getglobal("GameTooltipTextLeft" .. i)
      fs.text = ""
      fs.tc = nil
    end
  end
  gt.NumLines = function(self) return self.n end
  gt.ClearLines = clear
  gt.AddLine = function(self, text, r, g, b)
    self.n = self.n + 1
    local fs = getglobal("GameTooltipTextLeft" .. self.n)
    fs.text = text
    fs.tc = { r, g, b }
  end
  gt.SetOwner = function(self, owner, anchor)
    self.owner, self.anchor = owner, anchor
    clear(self)
    self:Hide()
  end
  gt.Show = function(self)
    TT.shows = (TT.shows or 0) + 1
    if not self.shown then
      self.shown = true
      fire(self, "OnShow")
    end
  end
  gt.Hide = function(self)
    if self.shown then
      self.shown = false
      fire(self, "OnHide")
    end
  end
  gt.SetScale = function(self, s) self.scale = s end
  gt.GetScale = function(self) return self.scale or 1 end
  local function fillItem(self, id)
    local it = TT.items[id]
    clear(self)
    if not it then return end
    self:AddLine(it.name, 1, 1, 1)
    for _, l in ipairs(it.lines or {}) do self:AddLine(l, 1, 1, 1) end
    self:Show()
  end
  local function idOf(link)
    local _, _, id = string.find(link or "", "item:(%d+)")
    return id and tonumber(id) or nil
  end
  gt.SetBagItem = function(self, bag, slot)
    TT.origCalls = TT.origCalls + 1
    fillItem(self, idOf(TT.bag[bag .. ":" .. slot]))
  end
  gt.SetInventoryItem = function(self, unit, slot)
    TT.origCalls = TT.origCalls + 1
    fillItem(self, idOf(TT.bag["inv:" .. slot]))
  end
  gt.SetHyperlink = function(self, link)
    TT.hyper = TT.hyper + 1
    fillItem(self, idOf(link))
  end
  gt.SetUnit = function(self, unit)
    clear(self)
    self.unit = unit
    self:AddLine(UnitName(unit) or "?", 1, 1, 1)
    self:AddLine("Niveau " .. UnitLevel(unit), 1, 1, 1)
    self:Show()
  end
  -- GameTooltip_SetDefaultAnchor d'origine
  G("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
    tooltip:SetOwner(parent, "ANCHOR_NONE")
    tooltip.defaultAnchor = true
  end)
  G("GetContainerItemLink", function(bag, slot) return TT.bag[bag .. ":" .. slot] end)
  G("GetInventoryItemLink", function(unit, slot) return TT.bag["inv:" .. slot] end)
  G("GetItemInfo", function(link)
    local id = idOf(link) or tonumber(link)
    local it = id and TT.items[id]
    if not it then return nil end
    return it.name, "|Hitem:" .. id .. "|h[" .. it.name .. "]|h", it.quality, it.ilvl, 60, "Armor", "Plate", 1, "INVTYPE_CHEST", "tex"
  end)
  G("UnitReaction", function(u, other) local x = W.units[u]; return x and x.reaction or nil end)
  G("UnitPVPName", function(u) local x = W.units[u]; return x and (x.pvpname or x.name) or nil end)
  G("GetGuildInfo", function(u) local x = W.units[u]; return x and x.guild or nil, x and x.rank or nil, 1 end)
  G("UnitReactionColor", { [2] = { r = 1, g = 0, b = 0 }, [4] = { r = 1, g = 1, b = 0 }, [5] = { r = 0, g = 1, b = 0 } })
  G("ITEM_QUALITY_COLORS", { [1] = { r = 1, g = 1, b = 1 }, [3] = { r = 0, g = 0.4, b = 1 }, [4] = { r = 0.64, g = 0.2, b = 0.93 } })
  gt:Hide()
end

-- TT_ITEM(id, nom, qualite, niveau, lignes) : un objet connu du client + lien |Hitem:id:0:0:0|h[nom]|h.
function TT_ITEM(id, name, quality, ilvl, lines)
  TT.items[id] = { name = name, quality = quality, ilvl = ilvl, lines = lines }
  return "|cffffffff|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r"
end
function TT_NAMPOWER_LEVEL(on, value)
  rawset(_G, "GetItemLevel", on and function(id) return value end or nil)
end
-- TT_HOVER(unite) : survol d'une unite du monde, comme le client : ancrage par defaut puis lignes puis affichage.
function TT_HOVER(unit, parent)
  W.units.mouseover = unit
  GameTooltip_SetDefaultAnchor(GameTooltip, parent or UIParent)
  GameTooltip:AddLine(unit.name, 1, 1, 1)
  GameTooltip:AddLine("Niveau " .. (unit.level or 60), 1, 1, 1)
  GameTooltip:Show()
end
function TT_LINES()
  local out = {}
  for i = 1, GameTooltip:NumLines() do table.insert(out, getglobal("GameTooltipTextLeft" .. i).text) end
  return out
end
function TT_TEXT() return table.concat(TT_LINES(), "\n") end
