-- mock_addons.lua : liste d'addons, instances et groupes de raid simules (Mode.lua). Charge automatiquement par le harnais.
-- Noms d'API de WoW 1.12 releves dans des addons installes : IsInInstance, GetNumRaidMembers, GetNumPartyMembers, GetNumAddOns,
-- GetAddOnInfo, DisableAddOn, EnableAddOn, ReloadUI. Les valeurs ci-dessous sont des DONNEES DE TEST.
W.instance = { inside = false, type = "none" }   -- type : "raid" | "party" | "pvp" | "none"
W.raidMembers = 0
W.partyMembers = 0
W.addons = {}        -- liste de { name, enabled }
W.reloads = 0

IsInInstance = function()
  if W.instance.inside then return 1, W.instance.type end
  return nil, "none"
end
GetNumRaidMembers = function() return W.raidMembers end
GetNumPartyMembers = function() return W.partyMembers end
GetNumAddOns = function() return table.getn(W.addons) end
GetAddOnInfo = function(i)
  local a = W.addons[i]
  if not a then return nil end
  local loadable = 1
  if a.loadable == false then loadable = nil end
  return a.name, a.title or a.name, a.notes or "", a.enabled and 1 or nil, loadable
end
local function find(n)
  for i = 1, table.getn(W.addons) do
    if W.addons[i].name == n then return W.addons[i] end
  end
  return nil
end
DisableAddOn = function(n)
  local a = find(n)
  if not a then error("DisableAddOn : addon inconnu " .. tostring(n), 2) end
  a.enabled = false
  ACT("DisableAddOn " .. n)
end
EnableAddOn = function(n)
  local a = find(n)
  if not a then error("EnableAddOn : addon inconnu " .. tostring(n), 2) end
  a.enabled = true
  ACT("EnableAddOn " .. n)
end
ReloadUI = function() W.reloads = W.reloads + 1; ACT("ReloadUI") end

-- Aides de test
function MKADDONS(names)
  W.addons = {}
  for i = 1, table.getn(names) do
    local n = names[i]
    if type(n) == "table" then
      table.insert(W.addons, { name = n.name, title = n.title, notes = n.notes, enabled = n.enabled ~= false, loadable = n.loadable })
    else
      table.insert(W.addons, { name = n, enabled = true })
    end
  end
end
function ADDONENABLED(n) local a = find(n); return a and a.enabled end
-- Place le joueur dans un raid : INRAID("raid", 10) = instance de raid + groupe de 10 ; INRAID(nil, 10) = groupe de raid seul.
function INRAID(instanceType, members)
  W.instance = { inside = instanceType ~= nil, type = instanceType or "none" }
  W.raidMembers = members or 0
end
function LEAVERAID() INRAID(nil, 0) end
