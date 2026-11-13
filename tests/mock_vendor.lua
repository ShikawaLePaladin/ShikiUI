-- mock_vendor : simulation d'un marchand pour le module "vendor" (chargee automatiquement par le harnais).
-- Ne contient QUE des noms d'API de WoW 1.12 et des DONNEES DE TEST. S'appuie sur les sacs de mock_bags (BGINFO / BGPUT : q = qualite, price = prix de vente).
-- Etat : W.ven. Rien n'est modifie au chargement hormis deux fonctions NOUVELLES (CanMerchantRepair, RepairAllItems) et des doublures d'achat
-- (BuyMerchantItem, PickupMerchantItem) qui ne font qu'enregistrer. Les fonctions de sacs/argent ne sont reprises qu'a l'appel de VENINSTALL().
-- Aides : VENINSTALL() VENRESET() VENFRAME() VENOPEN() VENCLOSE() VENREPAIR(cout [, canrepair]) VENGUILD(on [, paye]) VENSOLD() (ids vendus, "1,2")
-- Le serveur confirme une vente (PLAYER_MONEY) apres W.ven.lag secondes.

W.ven = { open = false, sells = {}, used = {}, repairs = {}, cost = 0, canrepair = true, guildpays = true, lag = 0.05, bought = 0 }

function VENRESET()
  W.ven.open, W.ven.sells, W.ven.used, W.ven.repairs, W.ven.cost, W.ven.canrepair, W.ven.guildpays, W.ven.lag, W.ven.bought =
    false, {}, {}, {}, 0, true, true, 0.05, 0
  rawset(_G, "CanGuildBankRepair", nil)
end

CanMerchantRepair = function() return W.ven.canrepair and 1 or nil end
RepairAllItems = function(guild)
  table.insert(W.ven.repairs, { guild = guild and true or false, cost = W.ven.cost })
  if W.ven.cost <= 0 then return end
  if guild then
    if not W.ven.guildpays then return end
  else
    W.bg.money = W.bg.money - W.ven.cost
    ShikiUI.After(W.ven.lag, function() Fire("PLAYER_MONEY") end, "mock.ven")
  end
  W.ven.cost = 0
end
BuyMerchantItem = function() W.ven.bought = W.ven.bought + 1 end
PickupMerchantItem = function() W.ven.bought = W.ven.bought + 1 end

function VENREPAIR(cost, can)
  W.ven.cost = cost
  if can ~= nil then W.ven.canrepair = can end
end

-- VENGUILD(true) : CanGuildBankRepair existe (client recent) ; paye = false : la guilde ne paie pas.
function VENGUILD(on, pays)
  if on then rawset(_G, "CanGuildBankRepair", function() return 1 end) else rawset(_G, "CanGuildBankRepair", nil) end
  W.ven.guildpays = (pays ~= false)
end

function VENINSTALL()
  rawset(_G, "GetRepairAllCost", function() return W.ven.cost, 1 end)
  UseContainerItem = function(bag, slot)
    local it = W.bg.slot[bag] and W.bg.slot[bag][slot]
    if not it then return end
    if not W.ven.open then
      table.insert(W.ven.used, it.id)
      ACT("UseContainerItem " .. bag .. " " .. slot)
      return
    end
    local info = W.bg.info[it.id]
    table.insert(W.ven.sells, it.id)
    W.bg.slot[bag][slot] = nil
    W.bg.money = W.bg.money + (info.price or 0) * (it.count or 1)
    ShikiUI.After(W.ven.lag, function() Fire("PLAYER_MONEY") end, "mock.ven")
  end
end

function VENSOLD() return table.concat(W.ven.sells, ",") end

-- MerchantFrame et un enfant a niveau eleve (pour verifier le recalage du niveau des boutons).
function VENFRAME()
  local mf = CreateFrame("Frame", "MerchantFrame", UIParent)
  mf.shown = false
  mf.level = 5
  mf.GetFrameStrata = function(self) return self.strata or "MEDIUM" end
  mf.SetFrameStrata = function(self, s) self.strata = s end
  local kid = CreateFrame("Frame", "MerchantItem1", mf)
  kid.level = 7
  return mf
end

function VENOPEN()
  W.ven.open = true
  local mf = rawget(_G, "MerchantFrame")
  if mf then mf:Show() end
  Fire("MERCHANT_SHOW")
end

function VENCLOSE()
  W.ven.open = false
  local mf = rawget(_G, "MerchantFrame")
  if mf then mf:Hide() end
  Fire("MERCHANT_CLOSED")
end
