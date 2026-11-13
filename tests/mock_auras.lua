-- mock_auras : extension de simulation du module "auras" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : AU_SETUP() (appele par t_auras.lua seulement) cree BuffFrame, TemporaryEnchantFrame, GameTooltip et les fonctions du
-- client. Noms d'API releves dans les addons installes (BigWigs Core, SpecialEvents-Aura, pfUI buff.lua) : GetPlayerBuff (indice a partir de 0, -1 en fin),
-- GetPlayerBuffTexture / Applications / DispelType / TimeLeft, CancelPlayerBuff, GetWeaponEnchantInfo, GetInventoryItemTexture, UnitBuff, UnitDebuff,
-- DebuffTypeColor. Valeurs = DONNEES DE TEST.
ALLOW("AU")

function AU_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  AU = { buffs = {}, debuffs = {}, tbuffs = {}, tdebuffs = {}, mh = nil, oh = nil, cancelled = {}, tip = {} }
  CreateFrame("Frame", "BuffFrame", UIParent):RegisterEvent("PLAYER_AURAS_CHANGED")
  CreateFrame("Frame", "TemporaryEnchantFrame", UIParent):RegisterEvent("PLAYER_AURAS_CHANGED")
  if not rawget(_G, "GameTooltip") then
    local gt = CreateFrame("GameTooltip", "GameTooltip", UIParent)
    gt.SetOwner = function(self, o, a) self.owner = o end
  end
  local gt = rawget(_G, "GameTooltip")
  gt.SetPlayerBuff = function(self, i) AU.tip = { "pb", i } end
  gt.SetUnitBuff = function(self, u, i) AU.tip = { "ub", u, i } end
  gt.SetUnitDebuff = function(self, u, i) AU.tip = { "ud", u, i } end
  gt.SetInventoryItem = function(self, u, s) AU.tip = { "inv", u, s } end
  G("DebuffTypeColor", { Magic = { r = 0.2, g = 0.6, b = 1 }, Poison = { r = 0, g = 0.6, b = 0 } })
  -- GetPlayerBuff(i, filtre) : i a partir de 0 ; renvoie l'indice (ici i) ou -1
  local function list(filter) if filter == "HARMFUL" then return AU.debuffs end return AU.buffs end
  G("GetPlayerBuff", function(i, filter)
    local l = list(filter)
    if l[i + 1] then return i + (filter == "HARMFUL" and 100 or 0), (l[i + 1].perm and 1 or 0) end
    return -1
  end)
  local function get(idx)
    if idx >= 100 then return AU.debuffs[idx - 100 + 1] end
    return AU.buffs[idx + 1]
  end
  G("GetPlayerBuffTexture", function(idx) local a = get(idx); return a and a.tex end)
  G("GetPlayerBuffApplications", function(idx) local a = get(idx); return a and a.count or 0 end)
  G("GetPlayerBuffDispelType", function(idx) local a = get(idx); return a and a.dtype end)
  G("GetPlayerBuffTimeLeft", function(idx) local a = get(idx); if not a or a.perm then return 0 end return a.left - (NOW - (a.t0 or NOW)) end)
  G("CancelPlayerBuff", function(idx) table.insert(AU.cancelled, idx) end)
  G("GetWeaponEnchantInfo", function()
    local mh, oh = AU.mh, AU.oh
    return mh and 1 or nil, mh and mh.ms or nil, mh and mh.charges or nil, oh and 1 or nil, oh and oh.ms or nil, oh and oh.charges or nil
  end)
  G("GetInventoryItemTexture", function(u, s) return "Interface\\Icons\\INV_Weapon_" .. s end)
  G("UnitBuff", function(u, i) local a = AU.tbuffs[i]; if not a then return nil end return a.tex, a.count end)
  G("UnitDebuff", function(u, i) local a = AU.tdebuffs[i]; if not a then return nil end return a.tex, a.count, a.dtype end)
end

-- AU_BUFF("player" | "debuff" | "tbuff" | "tdebuff", { tex, count, left, perm, dtype })
function AU_ADD(kind, a)
  a.t0 = NOW
  if kind == "buff" then table.insert(AU.buffs, a)
  elseif kind == "debuff" then table.insert(AU.debuffs, a)
  elseif kind == "tbuff" then table.insert(AU.tbuffs, a)
  else table.insert(AU.tdebuffs, a) end
end
function AU_CLEAR() AU.buffs, AU.debuffs, AU.tbuffs, AU.tdebuffs, AU.mh, AU.oh = {}, {}, {}, {}, nil, nil end
