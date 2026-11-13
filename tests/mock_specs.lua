-- mock_specs : extension de simulation du module "specs" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : SPECS_SETUP() (appelee par t_specs.lua seulement) cree le monde des talents, du livre de sorts, des
-- macros, des sacs et des barres d'action. Noms d'API de WoW 1.12 releves dans SimpleActionSets, ShikaSwap et pfUI : GetNumTalentTabs,
-- GetTalentTabInfo (nom, icone, points, fond), GetSpellName(i, "spell") (nom, rang), PickupSpell, PickupMacro, GetMacroInfo,
-- GetContainerNumSlots, GetContainerItemLink, PickupContainerItem, HasAction, GetActionText, PickupAction, PlaceAction, ClearCursor,
-- GameTooltip:SetAction. Toutes les valeurs = DONNEES DE TEST.
-- Aides : SPECS_TALENTS(p1, p2, p3 [, noms]) SPECS_SPELLS({ { nom, "Rank n" }, ... }) SPECS_MACROS({ nom, ... }) SPECS_BAGS({ [bag..":"..slot] = nom })
--         SPECS_BAR(slot, { kind = "spell"|"macro"|"item", name, rank }) SPECS_SAS(sets) SPECS_NOSAS()
ALLOW("SP")

function SPECS_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  SP = { tabs = { { "Sacre", 0 }, { "Protection", 0 }, { "Vindicte", 0 } }, spells = {}, macros = {}, bags = {}, bar = {}, cursor = nil,
    placed = 0, sas = nil, sasCalls = {} }
  G("GetNumTalentTabs", function() return table.getn(SP.tabs) end)
  G("GetTalentTabInfo", function(i)
    local t = SP.tabs[i]
    if not t then return nil end
    return t[1], "Interface\\Icons\\Tab" .. i, t[2], "Interface\\TalentFrame\\Bg" .. i
  end)
  G("GetSpellName", function(i, book)
    local s = SP.spells[i]
    if not s then return nil end
    return s[1], s[2] or ""
  end)
  G("PickupSpell", function(i, book) if SP.cursor then error("curseur deja plein") end; SP.cursor = { kind = "spell", name = SP.spells[i][1], rank = SP.spells[i][2] } end)
  G("GetMacroInfo", function(i) return SP.macros[i] end)
  G("PickupMacro", function(i) if SP.cursor then error("curseur deja plein") end; SP.cursor = { kind = "macro", name = SP.macros[i] } end)
  G("GetContainerNumSlots", function(bag) return bag == 0 and 16 or 0 end)
  G("GetContainerItemLink", function(bag, s)
    local n = SP.bags[bag .. ":" .. s]
    if not n then return nil end
    return "|cffffffff|Hitem:1:0:0:0|h[" .. n .. "]|h|r"
  end)
  G("PickupContainerItem", function(bag, s) if SP.cursor then error("curseur deja plein") end; SP.cursor = { kind = "item", name = SP.bags[bag .. ":" .. s] } end)
  G("HasAction", function(s) return SP.bar[s] and 1 or nil end)
  G("GetActionText", function(s)
    local a = SP.bar[s]
    if a and a.kind == "macro" then return a.name end
    return nil
  end)
  G("PickupAction", function(s) SP.cursor = SP.bar[s]; SP.bar[s] = nil end)
  G("PlaceAction", function(s)
    local old = SP.bar[s]
    SP.bar[s] = SP.cursor
    SP.cursor = old
    SP.placed = SP.placed + 1
    ACT("PlaceAction " .. s)
  end)
  G("ClearCursor", function() SP.cursor = nil end)
  -- infobulle de lecture (nom fixe pris par le module) : SetAction remplit la ligne 1
  local realCreate = CreateFrame
  G("CreateFrame", function(kind, name, parent, tmpl)
    local f = realCreate(kind, name, parent, tmpl)
    if name == "ShikiUI_SpecsTip" then
      realCreate("Frame", name .. "TextLeft1", f)
      realCreate("Frame", name .. "TextRight1", f)
      f.SetAction = function(self, slot)
        local a = SP.bar[slot]
        getglobal(name .. "TextLeft1").text = a and a.name or nil
        getglobal(name .. "TextRight1").text = a and a.rank or nil
      end
    end
    return f
  end)
end

-- SPECS_TALENTS(31, 20, 0 [, { "Sacre", "Protection", "Vindicte" }])
function SPECS_TALENTS(p1, p2, p3, names)
  SP.tabs[1][2], SP.tabs[2][2], SP.tabs[3][2] = p1, p2, p3
  if names then
    for i = 1, 3 do SP.tabs[i][1] = names[i] end
  end
end
function SPECS_SPELLS(list) SP.spells = list end
function SPECS_MACROS(list) SP.macros = list end
function SPECS_BAGS(t) SP.bags = t end
function SPECS_BAR(slot, a) SP.bar[slot] = a end

-- Simple Action Sets simule : SAS_SwapSet / SAS_SetExists / SASMain_Toggle / SAS_Saved / PlrName (globales du vrai addon)
function SPECS_SAS(sets)
  local list = {}
  for _, n in ipairs(sets or {}) do list[n] = {} end
  rawset(_G, "SAS_Saved", { ["Shikiwa - TestRealm"] = { s = list } })
  rawset(_G, "PlrName", "Shikiwa - TestRealm")
  rawset(_G, "SAS_SetExists", function(n) return list[n] and true or nil end)
  rawset(_G, "SAS_SwapSet", function(n) table.insert(SP.sasCalls, "swap " .. tostring(n)) end)
  rawset(_G, "SASMain_Toggle", function() table.insert(SP.sasCalls, "toggle") end)
end
function SPECS_NOSAS()
  for _, k in ipairs({ "SAS_Saved", "PlrName", "SAS_SetExists", "SAS_SwapSet", "SASMain_Toggle" }) do rawset(_G, k, nil) end
end
