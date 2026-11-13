-- mock_bags : simulation des sacs / de la banque pour le module "bags" (chargee automatiquement par le harnais).
-- Ne contient QUE des noms d'API de WoW 1.12 (relevees dans pfUI et ItemRack) et des DONNEES DE TEST (faux objets, faux prix).
-- Etat : W.bg. Aides : BGRESET() BGINFO(id, {...}) BGBAG(bag, taille) BGPUT(bag, slot, id, nombre) BGIDS(bag) BGLAYOUT({bag,...}) BGPRICES(on)
-- BGINSTALL() reaffirme toutes les fonctions ci-dessous (une suite l'appelle avant BOOT : un autre mock charge apres celui-ci ne la perturbe pas).
-- Simulation fidele du curseur : ramasser un objet le laisse verrouille dans son emplacement ; le poser sur un emplacement occupe
-- echange les objets et laisse l'ancien occupant sur le curseur ; un objet pose reste verrouille W.bg.lockdur secondes.

NUM_BAG_SLOTS = 4
NUM_BANKBAGSLOTS = 6
W.bg = { size = {}, slot = {}, cursor = nil, money = 0, keysize = 0, banksl = 0, info = {}, picks = 0, lockdur = 0.1, prices = false, cds = 0 }

function BGRESET()
  W.bg.size, W.bg.slot, W.bg.cursor, W.bg.money, W.bg.keysize, W.bg.banksl, W.bg.info, W.bg.picks, W.bg.lockdur =
    {}, {}, nil, 0, 0, 0, {}, 0, 0.1
  W.bg.cds = 0
  setglobal("C_Item", nil)
  W.bg.prices = false
end

-- BGINFO(100, { name = "Epee", q = 3, type = "Arme", sub = "Epees", eq = "INVTYPE_WEAPON", price = 500, uncached = false })
function BGINFO(id, t)
  t.name = t.name or ("Objet" .. id)
  t.q = t.q or 1
  t.type = t.type or "Divers"
  t.sub = t.sub or "Divers"
  t.eq = t.eq or ""
  t.tex = t.tex or ("Interface\\Icons\\Item" .. id)
  W.bg.info[id] = t
end

function BGBAG(bag, n)
  W.bg.size[bag] = n
  W.bg.slot[bag] = W.bg.slot[bag] or {}
  for i = n + 1, 200 do W.bg.slot[bag][i] = nil end
end

local function linkOf(id)
  local i = W.bg.info[id]
  return "|cffffffff|Hitem:" .. id .. ":0:0:0|h[" .. (i and i.name or ("Objet" .. id)) .. "]|h|r"
end

function BGPUT(bag, slot, id, count)
  W.bg.slot[bag] = W.bg.slot[bag] or {}
  if id == nil then W.bg.slot[bag][slot] = nil return end
  if not W.bg.info[id] then BGINFO(id, {}) end
  W.bg.slot[bag][slot] = { id = id, link = linkOf(id), count = count or 1, lockT = 0 }
end
function BGCLEAR(bag, slot) W.bg.slot[bag][slot] = nil end

-- liste des identifiants (ou 0 pour un emplacement vide) d'un sac, dans l'ordre
function BGIDS(bag)
  local t = {}
  for i = 1, W.bg.size[bag] or 0 do
    local it = W.bg.slot[bag] and W.bg.slot[bag][i]
    t[i] = it and it.id or 0
  end
  return t
end
function BGSTR(bag) return table.concat(BGIDS(bag), ",") end

-- BGLAYOUT({ [0] = 16, 18, 18 }) : taille des sacs 0, 1, 2...
function BGLAYOUT(sizes)
  for bag, n in pairs(sizes) do BGBAG(bag, n) end
end

function BGPRICES(on)
  W.bg.prices = on
  if on then
    setglobal("C_Item", { GetItemSellPriceByID = function(id) local i = W.bg.info[id]; return i and i.price or 0 end })
  else
    setglobal("C_Item", nil)
  end
end

function BGINSTALL()
  GetContainerNumSlots = function(bag) return W.bg.size[bag] or 0 end
  GetKeyRingSize = function() return W.bg.keysize end
  GetNumBankSlots = function() return W.bg.banksl end
  local function item(bag, slot) return W.bg.slot[bag] and W.bg.slot[bag][slot] end
  GetContainerItemInfo = function(bag, slot)
    local it = item(bag, slot)
    if not it then return nil end
    local i = W.bg.info[it.id]
    return i.tex, it.count, (it.held or GetTime() < it.lockT) and 1 or nil, i.q, nil
  end
  GetContainerItemLink = function(bag, slot)
    local it = item(bag, slot)
    return it and it.link or nil
  end
  UseContainerItem = function(bag, slot) ACT("UseContainerItem " .. bag .. " " .. slot) end
  PickupContainerItem = function(bag, slot)
    W.bg.picks = W.bg.picks + 1
    local it = item(bag, slot)
    local cur = W.bg.cursor
    if not cur then
      if it and not it.held and GetTime() >= it.lockT then
        it.held = true
        W.bg.cursor = { item = it, bag = bag, slot = slot }
      end
      return
    end
    if it and it.held then            -- on remet l'objet la ou il etait
      it.held = nil
      W.bg.cursor = nil
      return
    end
    if it and GetTime() < it.lockT then return end
    local moved = cur.item
    moved.held = nil
    moved.lockT = GetTime() + W.bg.lockdur
    if cur.bag then W.bg.slot[cur.bag][cur.slot] = nil end
    W.bg.slot[bag] = W.bg.slot[bag] or {}
    W.bg.slot[bag][slot] = moved
    if it then
      it.held = true
      W.bg.cursor = { item = it }     -- l'ancien occupant est maintenant sur le curseur
    else
      W.bg.cursor = nil
    end
  end
  CursorHasItem = function() return (W.bg.cursor or W.cursorItem) and 1 or nil end
  GetItemInfo = function(id)
    local i = W.bg.info[id]
    if not i or i.uncached then return nil end
    return i.name, linkOf(id), i.q, 1, i.type, i.sub, 1, i.eq, i.tex
  end
  GetItemQualityColor = function(q) return 0.1 * q, 0.2 * q, 0.05 * q, "|cff000000" end
  GetMoney = function() return W.bg.money end
  SetItemButtonTexture = function(b, tex) b.itex = tex end
  SetItemButtonCount = function(b, n) b.icount = n end
  SetItemButtonDesaturated = function(b, d) b.idesat = d and true or false end
  ContainerFrame_UpdateCooldown = function(bag, b) W.bg.cds = W.bg.cds + 1; b.cdbag = bag end
end
BGINSTALL()
