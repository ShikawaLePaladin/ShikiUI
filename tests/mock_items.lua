-- mock_items : simulation de l'equipement porte et des bijoux pour le module "items" (chargee automatiquement par le harnais).
-- Ne contient QUE des noms d'API de WoW 1.12 (relevees dans ItemRack et TrinketMenu) et des DONNEES DE TEST. S'appuie sur la simulation des
-- sacs de mock_bags.lua (curseur partage W.bg.cursor, objets de sac) : une suite appelle BGINSTALL() puis ITINSTALL() avant BOOT().
-- Etat : W.it. Aides : ITRESET() ITWEAR(emplacement, id [, suffixe]) ITLINK(id [, suffixe]) ITINV() ITCD(emplacement, debut, duree) ITBAGCD(sac, case, debut, duree)
-- ITTRINKET(id, nom) (declare un bijou : INVTYPE_TRINKET) ITZONE(type) ITINSTALL().
-- Simulation du curseur : ramasser un objet porte le laisse verrouille ; le poser sur un emplacement occupe echange et laisse l'ancien occupant
-- sur le curseur ; un objet pose reste verrouille W.bg.lockdur secondes.

W.it = { inv = {}, cd = {}, bcd = {}, uses = 0, buffs = {} }

function ITRESET()
  W.it.inv, W.it.cd, W.it.bcd, W.it.uses = {}, {}, {}, 0
  W.it.buffs = {}
  W.bg.cursor = nil
end

function ITLINK(id, suffix)
  local i = W.bg.info[id]
  return "|cffffffff|Hitem:" .. id .. ":0:" .. (suffix or 0) .. ":0|h[" .. (i and i.name or ("Objet" .. id)) .. "]|h|r"
end

function ITWEAR(slot, id, suffix)
  if not W.bg.info[id] then BGINFO(id, {}) end
  W.it.inv[slot] = { id = id, link = ITLINK(id, suffix), count = 1, lockT = 0 }
end

-- liste "slot:id" des emplacements portes, dans l'ordre
function ITINV()
  local t = {}
  for s = 1, 19 do
    if W.it.inv[s] then table.insert(t, s .. ":" .. W.it.inv[s].id) end
  end
  return table.concat(t, ",")
end

function ITCD(slot, start, dur) W.it.cd[slot] = { start, dur } end
function ITBAGCD(bag, slot, start, dur) W.it.bcd[bag .. ":" .. slot] = { start, dur } end
function ITTRINKET(id, name) BGINFO(id, { name = name or ("Bijou" .. id), eq = "INVTYPE_TRINKET", q = 3 }) end
function ITZONE(t)
  if t then W.instance = { inside = true, type = t } else W.instance = { inside = false, type = "none" } end
end

function ITINSTALL()
  local origPickup = PickupContainerItem
  if not W.it.wrapped then
    W.it.wrapped = true
    W.it.origPickup = origPickup
  end
  PickupContainerItem = function(bag, slot)
    local cur = W.bg.cursor
    local srcInv = cur and cur.inv
    W.it.origPickup(bag, slot)
    if srcInv and W.bg.cursor ~= cur then
      if W.it.inv[srcInv] == cur.item then W.it.inv[srcInv] = nil end
    end
  end
  GetInventoryItemLink = function(unit, slot)
    local it = W.it.inv[slot]
    return it and it.link or nil
  end
  GetInventoryItemTexture = function(unit, slot)
    local it = W.it.inv[slot]
    if not it then return nil end
    return W.bg.info[it.id] and W.bg.info[it.id].tex or "tex"
  end
  GetInventoryItemCooldown = function(unit, slot)
    local c = W.it.cd[slot]
    if not c then return 0, 0, 1 end
    return c[1], c[2], 1
  end
  GetContainerItemCooldown = function(bag, slot)
    local c = W.it.bcd[bag .. ":" .. slot]
    if not c then return 0, 0, 1 end
    return c[1], c[2], 1
  end
  IsInventoryItemLocked = function(slot)
    local it = W.it.inv[slot]
    return (it and (it.held or GetTime() < it.lockT)) and 1 or nil
  end
  UseInventoryItem = function(slot) W.it.uses = W.it.uses + 1; ACT("UseInventoryItem " .. slot) end
  ClearCursor = function() W.bg.cursor = nil end
  PickupInventoryItem = function(slot)
    local cur = W.bg.cursor
    local it = W.it.inv[slot]
    if not cur then
      if it and not it.held and GetTime() >= it.lockT then
        it.held = true
        W.bg.cursor = { item = it, inv = slot }
      end
      return
    end
    if cur.inv == slot then
      cur.item.held = nil
      W.bg.cursor = nil
      return
    end
    if it and (it.held or GetTime() < it.lockT) then return end
    local moved = cur.item
    moved.held = nil
    moved.lockT = GetTime() + W.bg.lockdur
    if cur.bag then W.bg.slot[cur.bag][cur.slot] = nil end
    if cur.inv then W.it.inv[cur.inv] = nil end
    W.it.inv[slot] = moved
    if it then
      it.held = true
      W.bg.cursor = { item = it }
    else
      W.bg.cursor = nil
    end
  end
end
ITINSTALL()

-- Auras du joueur (monture) : ITAURAS({ "Interface\Icons\Ability_Mount_RidingHorse", ... }) ; ITAURAS() les retire. UnitBuff(unite, i) -> icone, applications
-- (installe a l'appel : seulement pour les suites qui en ont besoin).
ALLOW("UnitBuff")
function ITAURAS(list)
  W.it.buffs = list or {}
  UnitBuff = function(unit, i)
    if unit ~= "player" then return nil end
    local t = W.it.buffs[i]
    if not t then return nil end
    return t, 1
  end
end

-- Fenetre du personnage (additif) : ITCHAR() cree CharacterFrame (cachee), PaperDollFrame (son onglet) et GameTooltip s'ils n'existent pas.
-- Le client change le niveau d'un cadre apres sa creation : les suites le simulent avec :SetFrameLevel() sur ces cadres.
function ITCHAR()
  if not rawget(_G, "CharacterFrame") then
    CreateFrame("Frame", "CharacterFrame", UIParent):Hide()
    CreateFrame("Frame", "PaperDollFrame", CharacterFrame)
  end
  if not rawget(_G, "GameTooltip") then CreateFrame("GameTooltip", "GameTooltip", UIParent) end
end
