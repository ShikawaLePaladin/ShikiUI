-- mock_macros : extension de simulation du module "macros" (chargee automatiquement par le harnais, apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : MAC_SETUP() (appele par t_macros.lua seulement) definit les fonctions du client utilisees par le module.
-- Noms d'API de WoW 1.12 / SuperWoW relevees dans les addons installes (SuperCleveRoidMacros : Console.lua, Core.lua, Conditionals.lua ;
-- SuperMacro : SuperMacro.lua) : GetNumMacros, GetMacroInfo, EditMacro, CreateMacro, DeleteMacro, GetNumMacroIcons, GetMacroIconInfo,
-- GetSpellName, GetSpellTexture, GetSpellCooldown, CastSpellByName(sort, unite), UnitBuff / UnitDebuff (+ identifiant de sort SuperWoW),
-- SpellInfo, GetShapeshiftForm, GetComboPoints, GetPlayerBuff, GetActionTexture, IsUsableAction, GetContainerItemLink, UseContainerItem,
-- TargetByName, AttackTarget, PetAttack, CancelPlayerBuff, SlashCmdList (CAST, USE, TARGET...), SendChatMessage, RunMacro. Tout est DONNEE DE TEST.
ALLOW("MAC")

local NAMES = { "CAST", "USE", "EQUIP", "TARGET", "ASSIST", "STARTATTACK", "STOPATTACK", "STOPCASTING", "CLEARTARGET", "PETATTACK", "PETFOLLOW",
  "PETWAIT", "PETPASSIVE", "PETDEFENSIVE", "PETAGGRESSIVE" }

function MAC_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  rawset(_G, "MAC", { macros = {}, spells = {}, cd = {}, casts = {}, acts = {}, vanilla = {}, mods = {}, buffs = {}, debuffs = {}, sid = {},
    forms = {}, form = 0, combo = 0, worn = {}, items = {}, bag = {}, bagN = {}, actions = {}, usable = {}, chat = {}, edits = {}, mounted = false,
    resting = false, party = 0, raid = 0, iconN = 20 })
  G("BOOKTYPE_SPELL", "spell")
  G("GetSpellName", function(i, book)
    local s = MAC.spells[i]
    if not s then return nil end
    return s[1], s[2]
  end)
  G("GetSpellTexture", function(i, book) local s = MAC.spells[i]; return s and ("Interface\\Icons\\" .. string.gsub(s[1], " ", "")) or nil end)
  G("GetSpellCooldown", function(i, book) local c = MAC.cd[i]; if not c then return 0, 0, 1 end return c[1], c[2], 1 end)
  G("CastSpellByName", function(spell, unit) table.insert(MAC.casts, spell .. "|" .. tostring(unit)) end)
  G("IsShiftKeyDown", function() return MAC.mods.shift and 1 or nil end)
  G("IsControlKeyDown", function() return MAC.mods.ctrl and 1 or nil end)
  G("IsAltKeyDown", function() return MAC.mods.alt and 1 or nil end)
  G("UnitIsUnit", function(a, b)
    local x, y = W.units[a], W.units[b]
    if not x or not y then return nil end
    return (x == y or (x.guid ~= nil and x.guid == y.guid)) and 1 or nil
  end)
  G("UnitCreatureType", function(u) local x = W.units[u]; return x and x.ctype or nil end)
  G("UnitBuff", function(u, i)
    local a = MAC.buffs[u] and MAC.buffs[u][i]
    if not a then return nil end
    return a.tex, a.count, a.sid
  end)
  G("UnitDebuff", function(u, i)
    local a = MAC.debuffs[u] and MAC.debuffs[u][i]
    if not a then return nil end
    return a.tex, a.count, a.dtype, a.sid
  end)
  G("GetPlayerBuff", function(i, filter)
    local bad = (filter == "HARMFUL")
    local l = bad and MAC.debuffs.player or MAC.buffs.player
    if l and l[i + 1] then return (bad and 200 or 100) + i end
    return -1
  end)
  G("GetPlayerBuffTimeLeft", function(idx)
    local bad = idx >= 200
    local l = bad and MAC.debuffs.player or MAC.buffs.player
    local a = l and l[idx - (bad and 200 or 100) + 1]
    return a and a.left or 0
  end)
  G("CancelPlayerBuff", function(idx) table.insert(MAC.acts, "CancelPlayerBuff " .. idx) end)
  G("GetShapeshiftForm", function() return MAC.form end)
  G("GetShapeshiftFormInfo", function(i) local f = MAC.forms[i]; if not f then return nil end return "tex", f, i == MAC.form, true end)
  G("CastShapeshiftForm", function(i) table.insert(MAC.acts, "CastShapeshiftForm " .. i) end)
  G("GetComboPoints", function() return MAC.combo end)
  G("IsResting", function() return MAC.resting and 1 or nil end)
  G("IsMounted", function() return MAC.mounted end)
  G("GetNumRaidMembers", function() return MAC.raid end)
  G("GetNumPartyMembers", function() return MAC.party end)
  G("GetActionTexture", function(s) return MAC.actions[s] end)
  G("IsUsableAction", function(s) local u = MAC.usable[s]; if u == nil then return 1, nil end return u and 1 or nil, nil end)
  G("GetActionCooldown", function(s) return 0, 0, 1 end)
  G("TargetLastTarget", function() table.insert(MAC.acts, "TargetLastTarget") end)
  G("ClearTarget", function() table.insert(MAC.acts, "ClearTarget") end)
  G("TargetByName", function(n, exact) table.insert(MAC.acts, "TargetByName " .. n) end)
  G("AssistUnit", function(u) table.insert(MAC.acts, "AssistUnit " .. u) end)
  G("AssistByName", function(n) table.insert(MAC.acts, "AssistByName " .. n) end)
  G("AttackTarget", function() table.insert(MAC.acts, "AttackTarget") end)
  G("SpellStopCasting", function() table.insert(MAC.acts, "SpellStopCasting") end)
  G("PetAttack", function() table.insert(MAC.acts, "PetAttack") end)
  G("PetFollow", function() table.insert(MAC.acts, "PetFollow") end)
  G("PetWait", function() table.insert(MAC.acts, "PetWait") end)
  G("PetPassiveMode", function() table.insert(MAC.acts, "PetPassiveMode") end)
  G("PetDefensiveMode", function() table.insert(MAC.acts, "PetDefensiveMode") end)
  G("PetAggressiveMode", function() table.insert(MAC.acts, "PetAggressiveMode") end)
  -- objets
  G("GetContainerNumSlots", function(b) return MAC.bagN[b] or 0 end)
  G("GetContainerItemLink", function(b, s)
    local n = MAC.bag[b] and MAC.bag[b][s]
    if not n then return nil end
    return "|cffffffff|Hitem:" .. (MAC.items[n] and MAC.items[n].id or 1) .. ":0:0:0|h[" .. n .. "]|h|r"
  end)
  G("UseContainerItem", function(b, s) table.insert(MAC.acts, "UseContainerItem " .. b .. " " .. s) end)
  G("UseInventoryItem", function(s) table.insert(MAC.acts, "UseInventoryItem " .. s) end)
  G("GetInventoryItemLink", function(u, s)
    local n = MAC.worn[s]
    if not n then return nil end
    return "|cffffffff|Hitem:" .. (MAC.items[n] and MAC.items[n].id or 1) .. ":0:0:0|h[" .. n .. "]|h|r"
  end)
  G("GetItemInfo", function(id)
    if type(id) == "string" then
      for n, it in pairs(MAC.items) do if n == id then return n, "link", 1, 1, 1, "Armor", it.sub, 1, "", it.tex end end
      return nil
    end
    for n, it in pairs(MAC.items) do
      if it.id == id then return n, "link", 1, 1, 1, it.type or "Armor", it.sub, 1, "", it.tex end
    end
    return nil
  end)
  -- macros du jeu
  G("GetNumMacros", function()
    local a, c = 0, 0
    for i = 1, 18 do if MAC.macros[i] then a = a + 1 end end
    for i = 19, 36 do if MAC.macros[i] then c = c + 1 end end
    return a, c
  end)
  G("GetMacroInfo", function(i)
    local m = MAC.macros[i]
    if not m then return nil end
    return m.name, m.tex or "Interface\\Icons\\INV_Misc_QuestionMark", m.body, 1
  end)
  G("EditMacro", function(i, name, icon, body, loc, per)
    local m = MAC.macros[i]
    if not m then error("macro inexistante") end
    table.insert(MAC.edits, { i, name, icon, body })
    if name then m.name = name end
    if body then m.body = body end
    Fire("UPDATE_MACROS")
    return i
  end)
  G("CreateMacro", function(name, icon, body, loc, per)
    local first, last = 1, 18
    if per then first, last = 19, 36 end
    for i = first, last do
      if not MAC.macros[i] then
        MAC.macros[i] = { name = name, body = body or "" }
        table.insert(MAC.edits, { "create", i, name, icon, per })
        Fire("UPDATE_MACROS")
        return i
      end
    end
    return nil
  end)
  G("DeleteMacro", function(i) MAC.macros[i] = nil; table.insert(MAC.edits, { "delete", i }); Fire("UPDATE_MACROS") end)
  G("GetNumMacroIcons", function() return MAC.iconN end)
  G("GetMacroIconInfo", function(i) return "Interface\\Icons\\Icon" .. i end)
  -- bavardage : lignes envoyees au chat (comme le fait le client pour #showtooltip), execution d'une macro
  G("SendChatMessage", function(msg, ctype) table.insert(MAC.chat, tostring(ctype) .. "|" .. msg) end)
  G("RunMacro", function(i)
    local m = MAC.macros[i]
    if m then MAC_RUN(m.body) end
  end)
  -- gestionnaires d'origine du jeu (enregistres comme le client : SlashCmdList + SLASH_xxx1)
  for _, k in ipairs(NAMES) do
    G("SLASH_" .. k .. "1", "/" .. string.lower(k))
    SlashCmdList[k] = function(msg) table.insert(MAC.vanilla, k .. "|" .. tostring(msg)) end
  end
  if not rawget(_G, "GameTooltip") then CreateFrame("GameTooltip", "GameTooltip", UIParent) end
  -- infobulle cachee du module : lecture du nom d'une aura sans SuperWoW
  local cf = CreateFrame
  G("CreateFrame", function(kind, name, parent, tmpl)
    local f = cf(kind, name, parent, tmpl)
    if name == "ShikiUI_MacroTip" then
      local left = UIParent:CreateFontString(nil, "ARTWORK")
      rawset(_G, "ShikiUI_MacroTipTextLeft1", left)
      f.SetUnitBuff = function(self, u, i)
        local a = MAC.buffs[u] and MAC.buffs[u][i]
        left:SetText(a and a.name or "")
      end
      f.SetUnitDebuff = function(self, u, i)
        local a = MAC.debuffs[u] and MAC.debuffs[u][i]
        left:SetText(a and a.name or "")
      end
    end
    return f
  end)
end

-- sorts connus du grimoire : liste { "nom", "rang" }
function MAC_SPELLS(list)
  MAC.spells = list
end

function MAC_MACRO(i, name, body) MAC.macros[i] = { name = name, body = body } end

-- Comme le client : "/mot reste" -> le gestionnaire de SlashCmdList qui porte ce texte. Les lignes sans "/" partent au chat.
function MAC_RUN(body)
  for line in string.gmatch(body .. "\n", "([^\n]*)\n") do
    local _, _, word, rest = string.find(line, "^%s*(/%S+)%s*(.*)$")
    if not word then
      if line ~= "" then SendChatMessage(line, "SAY") end
    else
      word = string.lower(word)
      local done = false
      for key, fn in pairs(SlashCmdList) do
        for i = 1, 4 do
          if not done and rawget(_G, "SLASH_" .. key .. i) == word then
            done = true
            fn(rest)
          end
        end
      end
    end
  end
end

function MAC_BUFF(unit, list) MAC.buffs[unit] = list end
function MAC_DEBUFF(unit, list) MAC.debuffs[unit] = list end
function MAC_LAST() return MAC.casts[table.getn(MAC.casts)] end
function MAC_CLEAR()
  MAC.casts, MAC.acts, MAC.vanilla, MAC.chat = {}, {}, {}, {}
end
function MAC_SW(on)
  EXT.superwow(on)
  ShikiUI.Api.Detect()
  if on then
    rawset(_G, "SpellInfo", function(id) return MAC.sid[id] end)
  end
end
function MAC_MACROFRAME()
  local f = CreateFrame("Frame", "MacroFrame", UIParent)
  f.selectedMacro = 2
  return f
end
