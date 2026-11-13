-- mock_actionbars : extension de simulation du module "actionbars" (chargee automatiquement par le harnais).
-- Ne contient QUE des noms d'API de WoW 1.12 (relevees dans pfUI, ItemRack, FredoAutoTarget) et des DONNEES DE TEST.
-- Etat : W.ab. Aides : ABRESET() ABSLOT(slot, {...}) ABFORMS(n) ABPET({...}) ABTOOLTIP() ABBLIZZ() ABMOD(shift, alt, ctrl).
-- ABINSTALL() reaffirme toutes les fonctions ci-dessous (une suite l'appelle avant BOOT : un autre mock charge apres celui-ci ne la perturbe pas).

W.ab = { has = {}, bonus = 0, forms = {}, pet = {}, petbar = false, bind = {}, mods = {}, saved = 0 }
CURRENT_ACTIONBAR_PAGE = 1
NUM_ACTIONBAR_PAGES = 6

function ABRESET()
  W.ab.has, W.ab.bonus, W.ab.forms, W.ab.pet, W.ab.petbar, W.ab.bind, W.ab.mods, W.ab.saved = {}, 0, {}, {}, false, {}, {}, 0
  CURRENT_ACTIONBAR_PAGE = 1
end

-- ABSLOT(61, { tex = "Interface\\Icons\\A", text = "Macro", consumable = true, count = 5, usable = false, oom = true, range = 0,
--              current = true, auto = false, equipped = true, attack = true, cd = { 100, 10, 1 } }) ; ABSLOT(61, nil) = vide
function ABSLOT(slot, t)
  if t and not t.tex then t.tex = "Interface\\Icons\\Slot" .. slot end
  if t and t.usable == nil then t.usable = true end
  W.ab.has[slot] = t
end
function ABFORMS(n, active)
  W.ab.forms = {}
  for i = 1, n do W.ab.forms[i] = { icon = "Interface\\Icons\\Form" .. i, name = "Forme" .. i, active = (active == i), castable = true } end
end
function ABPET(list)
  W.ab.pet = list or {}
  W.ab.petbar = list ~= nil and true or false
end
function ABMOD(shift, alt, ctrl) W.ab.mods = { shift = shift, alt = alt, ctrl = ctrl } end
function ABBIND(cmd, k1, k2) W.ab.bind[cmd] = { k1, k2 } end

function ABINSTALL()
  HasAction = function(s) return W.ab.has[s] and 1 or nil end
  GetActionTexture = function(s) local a = W.ab.has[s]; return a and a.tex or nil end
  GetActionText = function(s) local a = W.ab.has[s]; return a and a.text or nil end
  GetActionCount = function(s) local a = W.ab.has[s]; return a and a.count or 0 end
  IsConsumableAction = function(s) local a = W.ab.has[s]; return (a and a.consumable) and 1 or nil end
  IsEquippedAction = function(s) local a = W.ab.has[s]; return (a and a.equipped) and 1 or nil end
  IsCurrentAction = function(s) local a = W.ab.has[s]; return (a and a.current) and 1 or nil end
  IsAutoRepeatAction = function(s) local a = W.ab.has[s]; return (a and a.auto) and 1 or nil end
  IsAttackAction = function(s) local a = W.ab.has[s]; return (a and a.attack) and 1 or nil end
  IsUsableAction = function(s)
    local a = W.ab.has[s]
    if not a then return nil, nil end
    return a.usable and 1 or nil, a.oom and 1 or nil
  end
  IsActionInRange = function(s) local a = W.ab.has[s]; return a and a.range or nil end
  GetActionCooldown = function(s)
    local a = W.ab.has[s]
    if not a or not a.cd then return 0, 0, 0 end
    return a.cd[1], a.cd[2], a.cd[3] or 1
  end
  -- balayage du jeu (Cooldown.lua) : on note le dernier appel par modele
  CooldownFrame_SetTimer = function(m, start, dur, en) m.sweep = { start, dur, en }; W.ab.sweeps = (W.ab.sweeps or 0) + 1 end
  UseAction = function(s, chk, onself) ACT("UseAction " .. s .. " " .. tostring(chk) .. " " .. tostring(onself)) end
  PickupAction = function(s) ACT("PickupAction " .. s) end
  PlaceAction = function(s) ACT("PlaceAction " .. s) end
  ChangeActionBarPage = function(n) CURRENT_ACTIONBAR_PAGE = n; ACT("ChangeActionBarPage " .. n) end
  GetBonusBarOffset = function() return W.ab.bonus end
  IsShiftKeyDown = function() return W.ab.mods.shift and 1 or nil end
  IsAltKeyDown = function() return W.ab.mods.alt and 1 or nil end
  IsControlKeyDown = function() return W.ab.mods.ctrl and 1 or nil end
  GetBindingKey = function(cmd) local b = W.ab.bind[cmd]; if not b then return nil end return b[1], b[2] end
  GetBindingText = function(key, prefix, abbrev) return string.upper(key) end
  SetBinding = function(key, cmd)
    for c, b in pairs(W.ab.bind) do
      if b[1] == key then b[1] = nil end
      if b[2] == key then b[2] = nil end
      if not b[1] and not b[2] then W.ab.bind[c] = nil end
    end
    if cmd then
      local b = W.ab.bind[cmd] or {}
      if not b[1] then b[1] = key else b[2] = key end
      W.ab.bind[cmd] = b
    end
    ACT("SetBinding " .. key .. " " .. tostring(cmd))
    return true
  end
  GetCurrentBindingSet = function() return 2 end
  SaveBindings = function(set) W.ab.saved = W.ab.saved + 1; ACT("SaveBindings " .. tostring(set)) end
  GetNumShapeshiftForms = function() return table.getn(W.ab.forms) end
  GetShapeshiftFormInfo = function(i) local f = W.ab.forms[i]; if not f then return nil end return f.icon, f.name, f.active, f.castable end
  GetShapeshiftFormCooldown = function(i) local f = W.ab.forms[i]; if not f or not f.cd then return 0, 0, 0 end return f.cd[1], f.cd[2], 1 end
  CastShapeshiftForm = function(i) ACT("CastShapeshiftForm " .. i) end
  PetHasActionBar = function() return W.ab.petbar and 1 or nil end
  GetPetActionInfo = function(i)
    local p = W.ab.pet[i]
    if not p then return nil end
    return p.name, "", p.texture, p.token, p.active, true, p.autoOn
  end
  GetPetActionCooldown = function(i) local p = W.ab.pet[i]; if not p or not p.cd then return 0, 0, 0 end return p.cd[1], p.cd[2], 1 end
  CastPetAction = function(i) ACT("CastPetAction " .. i) end
  PickupPetAction = function(i) ACT("PickupPetAction " .. i) end
  TogglePetAutocast = function(i) ACT("TogglePetAutocast " .. i) end
end
ABINSTALL()

-- Infobulle : SetShapeshift / SetPetAction n'existent pas dans la liste blanche du mock (methodes de l'API 1.12 relevees dans pfUI)
function ABTOOLTIP()
  local g = CreateFrame("GameTooltip", "GameTooltip", UIParent)
  g.SetShapeshift = function(self, i) self.shape = i end
  g.SetPetAction = function(self, i) self.petAct = i end
  g.IsOwned = function(self, o) return self.owner == o end
  return g
end

-- Cadres de Blizzard que le module masque
function ABBLIZZ()
  local names = { "MainMenuBarArtFrame", "BonusActionBarFrame", "ShapeshiftBarFrame", "PetActionBarFrame", "MultiBarBottomLeft",
    "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight" }
  for i = 1, 12 do table.insert(names, "ActionButton" .. i) end
  local made = {}
  for _, n in ipairs(names) do
    local f = CreateFrame("Button", n, UIParent)
    f:RegisterEvent("ACTIONBAR_UPDATE_STATE")
    made[n] = f
  end
  return made
end
