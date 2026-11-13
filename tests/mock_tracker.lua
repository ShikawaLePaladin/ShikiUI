-- mock_tracker : simulation pour le module "tracker" (chargee automatiquement par le harnais). Ne contient QUE des noms d'API de WoW 1.12
-- (GetMoney, time, date, IsInInstance, GetRealZoneText, RequestRaidInfo, GetNumSavedInstances, GetSavedInstanceInfo, GetRepairAllCost,
-- extension C_Item.GetItemSellPriceByID) et des DONNEES DE TEST.
-- Etat : W.tk. L'heure absolue (time) suit l'horloge du harnais (NOW) : Pump(dt) la fait avancer ; TKAGE(s) saute s secondes.
-- Aides : TKINSTALL() TKRESET() TKSET(cuivre) TKGAIN(cuivre) TKLOSE(cuivre) TKLOOTMSG(cuivre) TKLOCK(nom, id, secondes) TKZONE(dedans, type, zone)
-- TKPRICE(id, cuivre) TKLOOTITEM(id, nom, n) TKAGE(s) TKMIDNIGHT() (saute jusqu'apres le prochain minuit local).

W.tk = { money = 0, epoch = 1794052800, t0 = 1000, locks = {}, inInst = nil, itype = "none", zone = "Orgrimmar", repair = 0,
  prices = {}, requests = 0, answer = true }

function TKINSTALL()
  local function put(k, v) rawset(_G, k, v) end
  put("time", function() return W.tk.epoch + math.floor(NOW - W.tk.t0) end)
  put("date", function(fmt, t) return os.date(fmt or "%c", t or time()) end)
  put("IsInInstance", function() return W.tk.inInst and 1 or nil, W.tk.itype end)
  put("GetRealZoneText", function() return W.tk.zone end)
  put("RequestRaidInfo", function()
    W.tk.requests = W.tk.requests + 1
    if W.tk.answer then Fire("UPDATE_INSTANCE_INFO") end
  end)
  put("GetNumSavedInstances", function() return table.getn(W.tk.locks) end)
  put("GetSavedInstanceInfo", function(i)
    local l = W.tk.locks[i]
    if not l then return nil end
    return l.name, l.id, l.secs
  end)
  put("GetRepairAllCost", function() return W.tk.repair, 1 end)
  put("C_Item", { GetItemSellPriceByID = function(id) return W.tk.prices[id] end })
  put("GetMoney", function() return W.tk.money end)
end

function TKRESET()
  W.tk.money, W.tk.locks, W.tk.inInst, W.tk.itype, W.tk.zone, W.tk.repair, W.tk.prices, W.tk.requests, W.tk.answer =
    0, {}, nil, "none", "Orgrimmar", 0, {}, 0, true
end

function TKSET(n) W.tk.money = n end
function TKGAIN(n)
  W.tk.money = W.tk.money + n
  Fire("PLAYER_MONEY")
end
function TKLOSE(n)
  W.tk.money = W.tk.money - n
  Fire("PLAYER_MONEY")
end

-- Texte de CHAT_MSG_MONEY en anglais : "You loot 3 Gold, 2 Silver, 20 Copper."
function TKLOOTMSG(c)
  local g = math.floor(c / 10000)
  local s = math.floor((c - g * 10000) / 100)
  local k = c - g * 10000 - s * 100
  local parts = {}
  if g > 0 then table.insert(parts, g .. " Gold") end
  if s > 0 then table.insert(parts, s .. " Silver") end
  if k > 0 then table.insert(parts, k .. " Copper") end
  Fire("CHAT_MSG_MONEY", "You loot " .. table.concat(parts, ", ") .. ".")
end

function TKLOCK(name, id, secs) table.insert(W.tk.locks, { name = name, id = id, secs = secs }) end

function TKZONE(inside, typ, zone)
  W.tk.inInst, W.tk.itype, W.tk.zone = inside and true or nil, typ or "none", zone or W.tk.zone
  Fire("ZONE_CHANGED_NEW_AREA")
end

function TKPRICE(id, c) W.tk.prices[id] = c end
function TKLOOTITEM(id, name, n)
  local link = "|cff1eff00|Hitem:" .. id .. ":0:0:0|h[" .. name .. "]|h|r"
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. link .. ((n and n > 1) and ("x" .. n) or "") .. ".")
end

function TKAGE(s)
  NOW = NOW + s
  Pump(0.5, 1)
end

function TKMIDNIGHT()
  local now = time()
  local into = tonumber(date("%H", now)) * 3600 + tonumber(date("%M", now)) * 60 + tonumber(date("%S", now))
  TKAGE(86400 - into + 60)
end

-- Rien n'est installe a l'import : la suite appelle TKINSTALL() (ne touche pas aux globales partagees des autres suites).
