-- mock_charstats : extension de simulation du module "charstats" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : CS_SETUP() (appele par t_charstats.lua seulement) cree CharacterFrame, GameTooltip, les fonctions de
-- statistiques du client et une infobulle de lecture simulee. Noms d'API releves dans le BetterCharacterStats installe : UnitStat,
-- UnitArmor, UnitResistance, UnitAttackPower, UnitRangedAttackPower, UnitAttackSpeed, UnitDamage, UnitRangedDamage, UnitAttackBothHands,
-- UnitRangedAttack, UnitDefense, GetCritChance, GetRangedCritChance, GetDodgeChance, GetParryChance, GetBlockChance, GetNumTalentTabs,
-- GetNumTalents, GetTalentInfo, GameTooltip:SetInventoryItem / SetTalent / NumLines. Toutes les valeurs = DONNEES DE TEST.
-- CS_NATIVE(nom, fn) installe une fonction OPTIONNELLE du client etendu (GetSpellCritChance, GetSpellBonusDamage, GetSpellBonusHealing,
-- GetManaRegen) ; CS_NATIVE(nom, nil) la retire.
ALLOW("CS")

function CS_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  CS = {
    stat = { { 100, 120 }, { 80, 90 }, { 150, 160 }, { 100, 100 }, { 40, 50 } },
    armor = 3000, res = { 0, 10, 20, 30, 40, 50 },
    ap = { 200, 50, -10 }, rap = { 0, 0, 0 },
    speed = 2.6, offSpeed = nil, dmin = 100, dmax = 200, omin = 0, omax = 0,
    rspeed = 0, rmin = 0, rmax = 0, rskill = { 0, 0 },
    skill = { 295, 5 }, offskill = { 0, 0 }, defense = { 300, 5 },
    crit = 5.5, rcrit = 0, dodge = 5.5, parry = 6.25, block = 12,
    gear = {}, right = {}, talents = {}, calls = { gear = 0, talent = 0, stats = 0 },
    native = {},
  }
  CreateFrame("Frame", "CharacterFrame", UIParent):Hide()
  CreateFrame("Frame", "PaperDollFrame", CharacterFrame)
  if not rawget(_G, "GameTooltip") then CreateFrame("GameTooltip", "GameTooltip", UIParent) end
  G("UnitStat", function(u, i) CS.calls.stats = CS.calls.stats + 1; return CS.stat[i][1], CS.stat[i][2] end)
  G("UnitArmor", function(u) return CS.armor, CS.armor, CS.armor, 0, 0 end)
  G("UnitResistance", function(u, i) return 0, CS.res[i], 0, 0 end)
  G("UnitAttackPower", function(u) return CS.ap[1], CS.ap[2], CS.ap[3] end)
  G("UnitRangedAttackPower", function(u) return CS.rap[1], CS.rap[2], CS.rap[3] end)
  G("UnitAttackSpeed", function(u) return CS.speed, CS.offSpeed end)
  G("UnitDamage", function(u) return CS.dmin, CS.dmax, CS.omin, CS.omax, 0, 0, 1 end)
  G("UnitRangedDamage", function(u) return CS.rspeed, CS.rmin, CS.rmax, 0, 0, 1 end)
  G("UnitRangedAttack", function(u) return CS.rskill[1], CS.rskill[2] end)
  G("UnitAttackBothHands", function(u) return CS.skill[1], CS.skill[2], CS.offskill[1], CS.offskill[2] end)
  G("UnitDefense", function(u) return CS.defense[1], CS.defense[2] end)
  G("GetCritChance", function() return CS.crit end)
  G("GetRangedCritChance", function() return CS.rcrit end)
  G("GetDodgeChance", function() return CS.dodge end)
  G("GetParryChance", function() return CS.parry end)
  G("GetBlockChance", function() return CS.block end)
  G("GetNumTalentTabs", function() return 1 end)
  G("GetNumTalents", function(tab) return table.getn(CS.talents) end)
  G("GetTalentInfo", function(tab, i) local t = CS.talents[i]; return t.name, "tex", 1, 1, t.rank end)
  -- l'infobulle de lecture (nom fixe pris par le module)
  local realCreate = CreateFrame
  G("CreateFrame", function(kind, name, parent, tmpl)
    local f = realCreate(kind, name, parent, tmpl)
    if name == "ShikiUI_StatsTip" then
      f.n = 0
      for i = 1, 40 do
        realCreate("Frame", name .. "TextLeft" .. i, f)
        realCreate("Frame", name .. "TextRight" .. i, f)
      end
      local function clear(self)
        self.n = 0
        for i = 1, 40 do
          getglobal(name .. "TextLeft" .. i).text = nil
          getglobal(name .. "TextRight" .. i).text = nil
        end
      end
      local function fill(self, lines, rights)
        clear(self)
        for i = 1, table.getn(lines) do
          self.n = self.n + 1
          getglobal(name .. "TextLeft" .. self.n).text = lines[i]
        end
        if rights then
          for i = 1, table.getn(rights) do getglobal(name .. "TextRight" .. i).text = rights[i] end
        end
      end
      f.NumLines = function(self) return self.n end
      f.SetOwner = function(self, o, anchor) clear(self) end
      f.SetInventoryItem = function(self, unit, slot)
        CS.calls.gear = CS.calls.gear + 1
        local lines = CS.gear[slot]
        if not lines then return nil end
        fill(self, lines, CS.right[slot])
        return true
      end
      f.SetTalent = function(self, tab, i)
        CS.calls.talent = CS.calls.talent + 1
        fill(self, CS.talents[i].lines)
      end
    end
    return f
  end)
end

-- Installe (fn) ou retire (nil) une fonction optionnelle du client etendu.
function CS_NATIVE(name, fn)
  rawset(_G, name, fn)
end

-- CS_ROW(cle [, section]) : la ligne affichee (libelle, valeur, cadre) pour une cle de ligne du module, ou nil si absente.
-- 'section' (nom de panneau, ex. "misc") restreint la recherche a cette section.
function CS_ROW(key, sec)
  local M = ShikiUI.CharStats
  for i = 1, M.nv do
    local ln = M.lines[i]
    if ln.kind == "R" and ln.key == key and (not sec or ln.p == sec) then return ln.label:GetText(), ln.value:GetText(), ln end
  end
  return nil
end

-- CS_PANELS(a, b, c) : n'active que ces sections et rafraichit.
function CS_PANELS(a, b, c)
  local M = ShikiUI.CharStats
  M.edit = false
  M.sel.off = {}
  M.SetSections({ a, b or "", c or "" })
  M.Touch()
end

-- CS_LINES() : liste "H:titre" / "R:cle" des lignes affichees.
function CS_LINES()
  local M = ShikiUI.CharStats
  local out = {}
  for i = 1, M.nv do
    local ln = M.lines[i]
    out[i] = ln.kind .. ":" .. (ln.kind == "H" and ln.p or ln.key)
  end
  return out
end
