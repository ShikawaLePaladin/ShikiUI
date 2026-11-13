-- mock_powerauras : extension de simulation du module "powerauras" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : PA_SETUP() (appelee par t_powerauras.lua seulement) cree le monde des auras, du grimoire, des sacs, des
-- temps de recharge, des points de combo, du groupe et des sons. Noms d'API de WoW 1.12 releves dans les addons installes (voir
-- Mod_PowerAuras.lua). Toutes les valeurs = DONNEES DE TEST.
-- Aides : PA_SETUP() PA_BUFF(liste, nom, tex, count, left) PA_CLEAR() PA_SPELLS({ {nom, rang, tex}, ... }) PA_CD(indice, debut, duree)
--         PA_BAG(bag, slot, nom, tex) PA_EQUIP(slot, nom, tex) PA_SWEEP(on) PA_SW(on)
ALLOW("PA")

function PA_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  rawset(_G, "PA", { pb = {}, pd = {}, tb = {}, td = {}, spells = {}, cd = {}, bags = {}, bagtex = {}, bagcd = {}, equip = {}, equiptex = {}, equipcd = {},
    count = {}, combo = 0, raid = 0, party = 0, sounds = {}, files = {}, tipname = nil, tipcalls = 0, tabs = { 0, 0, 0 }, sweeps = {},
    tiponly = false, ids = {}, spellinfo = {} })
  local PA = rawget(_G, "PA")
  if not rawget(_G, "GameTooltip") then CreateFrame("GameTooltip", "GameTooltip", UIParent) end
  G("BOOKTYPE_SPELL", "spell")
  -- joueur : indices pairs = buffs 0.., debuffs = 100 + i
  local function getp(idx)
    if idx >= 100 then return PA.pd[idx - 99] end
    return PA.pb[idx + 1]
  end
  G("GetPlayerBuff", function(i, filter)
    local list = (filter == "HELPFUL") and PA.pb or PA.pd
    if not list[i + 1] then return -1, nil end
    return (filter == "HELPFUL") and i or (100 + i), nil
  end)
  G("GetPlayerBuffTexture", function(idx) local a = getp(idx); return a and a.tex end)
  G("GetPlayerBuffApplications", function(idx) local a = getp(idx); return a and a.count or 0 end)
  G("GetPlayerBuffTimeLeft", function(idx)
    local a = getp(idx)
    if not a or not a.left then return 0 end
    return a.left - (NOW - (a.t0 or NOW))
  end)
  G("UnitBuff", function(u, i) local a = PA.tb[i]; if u ~= "target" or not a then return nil end return a.tex, a.count end)
  G("UnitDebuff", function(u, i) local a = PA.td[i]; if u ~= "target" or not a then return nil end return a.tex, a.count, "Magic" end)
  -- infobulle cachee : le module cree "ShikiUI_PATip" ; on lui ajoute les methodes qui lisent le monde ci-dessus
  local orig = CreateFrame
  G("CreateFrame", function(kind, name, parent, tmpl)
    local f = orig(kind, name, parent, tmpl)
    if name == "ShikiUI_PATip" then
      f.SetPlayerBuff = function(self, idx) PA.tipcalls = PA.tipcalls + 1; local a = getp(idx); PA.tipname = a and a.name or nil end
      f.SetUnitBuff = function(self, u, i) PA.tipcalls = PA.tipcalls + 1; local a = PA.tb[i]; PA.tipname = a and a.name or nil end
      f.SetUnitDebuff = function(self, u, i) PA.tipcalls = PA.tipcalls + 1; local a = PA.td[i]; PA.tipname = a and a.name or nil end
      rawset(_G, "ShikiUI_PATipTextLeft1", { GetText = function() return PA.tipname end })
    end
    return f
  end)
  -- grimoire, temps de recharge
  G("GetSpellName", function(i, book) local s = PA.spells[i]; if not s then return nil end return s[1], s[2] or "" end)
  G("GetSpellTexture", function(i, book) local s = PA.spells[i]; return s and s[3] or nil end)
  G("GetSpellCooldown", function(i, book) local c = PA.cd[i]; if not c then return 0, 0, 1 end return c[1], c[2], 1 end)
  -- sacs et equipement
  G("GetContainerNumSlots", function(bag) return bag == 0 and 16 or (bag == 1 and 8 or 0) end)
  G("GetContainerItemLink", function(bag, slot)
    local n = PA.bags[bag .. ":" .. slot]
    if not n then return nil end
    return "|cffffffff|Hitem:1:0:0:0|h[" .. n .. "]|h|r"
  end)
  G("GetContainerItemInfo", function(bag, slot) return PA.bagtex[bag .. ":" .. slot], 1 end)
  G("GetContainerItemCooldown", function(bag, slot) local c = PA.bagcd[bag .. ":" .. slot]; if not c then return 0, 0, 1 end return c[1], c[2], 1 end)
  G("GetInventoryItemLink", function(u, slot)
    local n = PA.equip[slot]
    if not n then return nil end
    return "|cffffffff|Hitem:2:0:0:0|h[" .. n .. "]|h|r"
  end)
  G("GetInventoryItemTexture", function(u, slot) return PA.equiptex[slot] end)
  G("GetInventoryItemCooldown", function(u, slot) local c = PA.equipcd[slot]; if not c then return 0, 0, 1 end return c[1], c[2], 1 end)
  G("GetItemCount", function(name)
    for k, v in pairs(PA.count) do if string.lower(k) == string.lower(name) then return v end end
    return 0
  end)
  G("GetComboPoints", function() return PA.combo end)
  G("GetNumRaidMembers", function() return PA.raid end)
  G("GetNumPartyMembers", function() return PA.party end)
  G("GetNumTalentTabs", function() return 3 end)
  G("GetTalentTabInfo", function(i) return "Arbre" .. i, "icon" .. i, PA.tabs[i], "bg" .. i end)
  G("PlaySoundFile", function(f) table.insert(PA.files, f) end)
  G("PlaySound", function(n) table.insert(PA.sounds, n) end)
end

-- Ajoute une aura a une liste (pb | pd | tb | td) ; left = secondes restantes (joueur) ; renvoie la fiche (modifiable ensuite).
function PA_BUFF(list, name, tex, count, left)
  local a = { name = name, tex = tex, count = count or 0, left = left, t0 = NOW }
  table.insert(PA[list], a)
  return a
end

function PA_CLEAR()
  PA.pb, PA.pd, PA.tb, PA.td = {}, {}, {}, {}
end

function PA_SPELLS(list)
  PA.spells = list
end

function PA_CD(i, start, dur)
  PA.cd[i] = { start, dur }
end

function PA_BAG(bag, slot, name, tex)
  PA.bags[bag .. ":" .. slot] = name
  PA.bagtex[bag .. ":" .. slot] = tex
end

function PA_EQUIP(slot, name, tex)
  PA.equip[slot] = name
  PA.equiptex[slot] = tex
end

-- Balayage circulaire du jeu : CooldownFrame_SetTimer(modele, debut, duree, actif)
function PA_SWEEP(on)
  if on then
    rawset(_G, "CooldownFrame_SetTimer", function(m, s, d, e) table.insert(PA.sweeps, { s, d, e }) end)
  else
    rawset(_G, "CooldownFrame_SetTimer", nil)
  end
end

-- SuperWoW : GetPlayerBuffID(indice) -> id de sort ; SpellInfo(id) -> nom, rang, icone
function PA_SW(on)
  EXT.superwow(on)
  if on then
    rawset(_G, "GetPlayerBuffID", function(idx) return PA.ids[idx] end)
    rawset(_G, "SpellInfo", function(id) local n = PA.spellinfo[id]; if not n then return nil end return n, "", "tex" end)
  else
    rawset(_G, "GetPlayerBuffID", nil)
    rawset(_G, "SpellInfo", nil)
  end
end
