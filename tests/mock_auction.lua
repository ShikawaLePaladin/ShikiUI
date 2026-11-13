-- mock_auction : simulation de l'hotel des ventes pour le module "auction" (chargee automatiquement par le harnais).
-- Ne contient QUE des noms d'API de WoW 1.12 (relevees dans aux-addon) et des DONNEES DE TEST (fausses encheres).
-- Etat : W.ah. Aides : AHRESET() AHADD({ name, count, bid, buy, owner, quality, id, left, tex, inc, cur, high }) AHOPEN() AHCLOSE() AHCAN(bool) AHINSTALL()
-- Achat / annulation / lots (installes seulement par AHINSTALL2(), appele par t_auction) : PlaceAuctionBid (W.ah.bids), CancelAuction (W.ah.cancelled),
-- liste "owner" (AHOWN({ name, count, bid, buy, cur, high, left, id })), GetOwnerAuctionItems (W.ah.ownReq), classes, SplitContainerItem, GetItemCount,
-- AHMONEY(cuivre) (GetMoney), AHCLOCK(jours) (time, avance d'un jour par AHCLOCK(+1)). Le serveur repond a une requete par W.ah.lag secondes.
-- Le serveur repond a une requete apres W.ah.lag secondes par AUCTION_ITEM_LIST_UPDATE, puis autorise la requete suivante ;
-- lag = nil : jamais de reponse. Un lot = 50 encheres. Reprend le curseur de mock_bags (W.bg.cursor, W.bg.slot).

W.ah = { list = {}, cur = {}, total = 0, can = true, lag = 0.1, queries = {}, sell = nil, posted = {}, deposits = 0,
  bids = {}, cancelled = {}, owned = {}, ownReq = 0, money = 0, day = 20000 }

function AHRESET()
  W.ah.list, W.ah.cur, W.ah.total, W.ah.can, W.ah.lag, W.ah.queries, W.ah.sell, W.ah.posted, W.ah.deposits =
    {}, {}, 0, true, 0.1, {}, nil, {}, 0
end

function AHADD(t)
  table.insert(W.ah.list, { name = t.name or "Objet", count = t.count or 1, bid = t.bid or 1, buy = t.buy or 0,
    owner = t.owner or "Zed", quality = t.quality or 1, id = t.id or 3001, left = t.left, tex = t.tex, inc = t.inc, cur = t.cur, high = t.high })
end

function AHOPEN() Fire("AUCTION_HOUSE_SHOW") end
function AHCLOSE() Fire("AUCTION_HOUSE_CLOSED") end
function AHCAN(on) W.ah.can = on and true or false end

local function linkOf(a)
  return "|cffffffff|Hitem:" .. a.id .. ":0:0:0|h[" .. a.name .. "]|h|r"
end

function AHINSTALL()
  W.ah.closed = W.ah.closed or 0
  CloseAuctionHouse = function() W.ah.closed = W.ah.closed + 1 end
  CanSendAuctionQuery = function() return W.ah.can and 1 or nil end
  QueryAuctionItems = function(name, minL, maxL, slot, class, sub, page, usable, quality)
    table.insert(W.ah.queries, { name = name, page = page, usable = usable, quality = quality, minL = minL, maxL = maxL, class = class, sub = sub })
    local low = string.lower(name or "")
    local found = {}
    for i = 1, table.getn(W.ah.list) do
      local a = W.ah.list[i]
      if string.find(string.lower(a.name), low, 1, true) and a.quality >= (quality or 0) then table.insert(found, a) end
    end
    W.ah.total = table.getn(found)
    W.ah.cur = {}
    for i = page * 50 + 1, math.min(W.ah.total, page * 50 + 50) do table.insert(W.ah.cur, found[i]) end
    W.ah.can = false
    if W.ah.lag then
      ShikiUI.After(W.ah.lag, function()
        W.ah.can = true
        Fire("AUCTION_ITEM_LIST_UPDATE")
      end, "mock.ah")
    end
  end
  GetNumAuctionItems = function(kind)
    if kind == "owner" then return table.getn(W.ah.owned), table.getn(W.ah.owned) end
    return table.getn(W.ah.cur), W.ah.total
  end
  GetAuctionItemInfo = function(kind, i)
    local a = (kind == "owner") and W.ah.owned[i] or W.ah.cur[i]
    if not a then return nil end
    return a.name, a.tex or "tex", a.count, a.quality, 1, 1, a.bid, a.inc or 1, a.buy, a.cur or 0, a.high, a.owner
  end
  GetAuctionItemLink = function(kind, i)
    local a = (kind == "owner") and W.ah.owned[i] or W.ah.cur[i]
    return a and linkOf(a) or nil
  end
  GetAuctionItemTimeLeft = function(kind, i)
    local a = (kind == "owner") and W.ah.owned[i] or W.ah.cur[i]
    return a and a.left or 3
  end
  GetAuctionSellItemInfo = function()
    local s = W.ah.sell
    if not s then return nil end
    local info = W.bg.info[s.item.id]
    return info and info.name or ("Objet" .. s.item.id), "tex", s.item.count, 1, 1, 0
  end
  ClickAuctionSellItemButton = function()
    local c = W.bg.cursor
    if c and c.bag then
      W.bg.slot[c.bag][c.slot] = nil
      c.item.held = nil
      W.ah.sell = { item = c.item, bag = c.bag, slot = c.slot }
      W.bg.cursor = nil
    elseif c and c.split then          -- pile scindee (SplitContainerItem) : pas d'emplacement d'origine
      c.item.held = nil
      W.ah.sell = { item = c.item, bag = nil, slot = nil, split = true }
      W.bg.cursor = nil
    elseif not c and W.ah.sell then
      local s = W.ah.sell
      if s.bag then
        W.bg.slot[s.bag][s.slot] = s.item
      else                             -- pile scindee : elle revient sur le curseur
        s.item.held = true
        W.bg.cursor = { item = s.item, split = true }
      end
      W.ah.sell = nil
    end
  end
  CalculateAuctionDeposit = function(minutes)
    W.ah.deposits = W.ah.deposits + 1
    return minutes
  end
  StartAuction = function(bid, buy, dur)
    if not W.ah.sell then return end
    local info = W.bg.info[W.ah.sell.item.id]
    table.insert(W.ah.posted, { bid = bid, buy = buy, dur = dur, name = info and info.name, count = W.ah.sell.item.count })
    W.ah.sell = nil
  end
end
AHINSTALL()

-- ---------------------------------------------------------------- achat, annulation, lots (installation explicite)
function AHOWN(t)
  table.insert(W.ah.owned, { name = t.name or "Objet", count = t.count or 1, bid = t.bid or 1, buy = t.buy or 0, owner = "Moi",
    quality = t.quality or 1, id = t.id or 3001, left = t.left, tex = t.tex, cur = t.cur, high = t.high })
end
function AHMONEY(c) W.ah.money = c; GetMoney = function() return W.ah.money end end
function AHCLOCK(day)
  W.ah.day = day or W.ah.day
  rawset(_G, "time", function() return W.ah.day * 86400 + 3600 end)
end
function AHINSTALL2()
  for _, n in ipairs({ "PlaceAuctionBid", "CancelAuction", "GetOwnerAuctionItems", "GetAuctionItemClasses", "GetAuctionItemSubClasses", "SplitContainerItem", "GetItemCount" }) do
    if ALLOW then ALLOW(n) end
  end
  PlaceAuctionBid = function(kind, idx, amount)
    local a = W.ah.cur[idx]
    table.insert(W.ah.bids, { kind = kind, idx = idx, amount = amount, name = a and a.name, count = a and a.count, owner = a and a.owner })
    if a and amount >= (a.buy or 0) and (a.buy or 0) > 0 then
      for i = 1, table.getn(W.ah.list) do
        if W.ah.list[i] == a then table.remove(W.ah.list, i) break end
      end
    end
  end
  CancelAuction = function(idx)
    table.insert(W.ah.cancelled, { idx = idx, name = W.ah.owned[idx] and W.ah.owned[idx].name })
    table.remove(W.ah.owned, idx)
  end
  GetOwnerAuctionItems = function()
    W.ah.ownReq = W.ah.ownReq + 1
    Fire("AUCTION_OWNED_LIST_UPDATE")
  end
  GetAuctionItemClasses = function() return "Arme", "Armure", "Consommable" end
  GetAuctionItemSubClasses = function(i)
    if i == 1 then return "Epees", "Haches" end
    return "Divers"
  end
  SplitContainerItem = function(bag, slot, n)
    local it = W.bg.slot[bag] and W.bg.slot[bag][slot]
    if not it or W.bg.cursor then return end
    if n >= it.count then
      PickupContainerItem(bag, slot)
      return
    end
    it.count = it.count - n
    W.bg.cursor = { item = { id = it.id, link = it.link, count = n, lockT = 0 }, split = true }
  end
  GetItemCount = function(name)
    local total = 0
    for bag, slots in pairs(W.bg.slot) do
      for _, it in pairs(slots) do
        local info = W.bg.info[it.id]
        if info and info.name == name and not it.held then total = total + it.count end
      end
    end
    return total
  end
end
