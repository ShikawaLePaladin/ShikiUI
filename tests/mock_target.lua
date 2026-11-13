-- mock_target.lua : plaques de nom, ennemis proches et acquisition de cible simules (Target.lua). Charge par le harnais.
-- Tout est DONNEE DE TEST. Les plaques sont des enfants du WorldFrame de mock_wow.lua ; un ennemi est aussi une "unite" dont le
-- GUID sert de jeton (W.units[guid]) : UnitXP("distanceBetween", ...) de EXT.unitxp("real") le trouve donc tout seul.
W.plates = {}
W.lastTarget = nil
W.spellRange = {}      -- sort -> 1 | 0

local unpack5 = table.unpack
WorldFrame.GetChildren = function(self) return unpack5(W.plates) end

-- MKPLATE("0xF1...", { dist = 8, reaction = 2, dead = false, combat = true, shown = true, button = true })
function MKPLATE(guid, o)
  o = o or {}
  local kind = (o.button == false) and "Frame" or "Button"
  local f = CreateFrame(kind, nil, WorldFrame)
  f.GetName = function(self, g) if g then return guid end return nil end
  f.plateGuid = guid
  if o.shown == false then f.shown = false end
  W.units[guid] = { name = o.name or "Ennemi", hp = 100, hpMax = 100, mana = 0, manaMax = 0, ptype = 0, level = 60, isPlayer = false,
    friend = false, canAttack = true, enemy = true, guid = guid, dist = o.dist or 10, sight = o.sight, reaction = o.reaction or 2,
    dead = o.dead, combat = (o.combat ~= false) }
  table.insert(W.plates, f)
  return f
end
function CLEARPLATES()
  for i = 1, table.getn(W.plates) do W.units[W.plates[i].plateGuid or ""] = nil end
  W.plates = {}
end

local baseCombat = UnitAffectingCombat
UnitAffectingCombat = function(u)
  if u ~= "player" and W.units[u] and W.units[u].combat ~= nil then return W.units[u].combat and 1 or nil end
  return baseCombat(u)
end
UnitReaction = function(a, b) local x = W.units[a]; return x and x.reaction or nil end
UnitIsDead = function(u) local x = W.units[u]; return (x and x.dead) and 1 or nil end

IsSpellInRange = function(spell, unit)
  if not W.units[unit] then return nil end
  return W.spellRange[spell]
end
ClearTarget = function() W.lastTarget = W.units.target; W.units.target = nil; ACT("ClearTarget") end
local function nearest(playersOnly)
  local best, bd = nil, nil
  for guid, x in pairs(W.units) do
    if guid ~= "target" and x.enemy and not x.dead and x.dist and (not playersOnly or x.isPlayer) and (bd == nil or x.dist < bd) then best, bd = guid, x.dist end
  end
  return best
end
TargetNearestEnemy = function()
  ACT("TargetNearestEnemy")
  local g = nearest(false)
  if g then local c = {}; for k, v in pairs(W.units[g]) do c[k] = v end; W.units.target = c end
end
TargetNearestEnemyPlayer = function()
  ACT("TargetNearestEnemyPlayer")
  local g = nearest(true)
  if g then local c = {}; for k, v in pairs(W.units[g]) do c[k] = v end; W.units.target = c end
end
TargetLastTarget = function()
  ACT("TargetLastTarget")
  if W.lastTarget then W.units.target = W.lastTarget end
end
