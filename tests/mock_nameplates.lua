-- mock_nameplates : extension de simulation du module "nameplates" (chargee automatiquement apres mock_wow.lua, AVANT le mode strict).
-- Rien n'est pose au chargement : NP_SETUP() (appele par t_nameplates.lua seulement) ajoute WorldFrame:GetNumChildren, UnitIsUnit,
-- UnitDebuff et le jeton "<guid>target". NP_PLATE(guid, opts) fabrique une plaque COMPLETE (barre de vie, barre d'incantation, six regions
-- dans l'ordre du jeu). Noms d'API et ordre des regions releves dans pfUI nameplates.lua. Valeurs = DONNEES DE TEST.
ALLOW("NP")

function NP_SETUP()
  local function G(k, v) rawset(_G, k, v) end
  NP = { mt = {}, tdebuffs = {}, plates = {} }
  WorldFrame.GetNumChildren = function(self) return table.getn(W.plates) end
  local baseExists = UnitExists
  G("UnitExists", function(u)
    if type(u) == "string" and not W.units[u] and string.sub(u, -6) == "target" and string.len(u) > 6 then
      local g = string.sub(u, 1, -7)
      if NP.mt[g] then return 1 end
      return nil
    end
    return baseExists(u)
  end)
  G("UnitIsUnit", function(a, b)
    if type(a) == "string" and not W.units[a] and string.sub(a, -6) == "target" and string.len(a) > 6 then
      local g = string.sub(a, 1, -7)
      return (NP.mt[g] ~= nil and NP.mt[g] == b) and 1 or nil
    end
    return a == b and 1 or nil
  end)
  -- menace : nom du detenteur ("<guid>target"), familiers, paquets d'addon envoyes, main tanks du raid
  NP.mtName, NP.pet, NP.sent, NP.roster = {}, {}, {}, {}
  local baseName = UnitName
  G("UnitName", function(u)
    if type(u) == "string" and not W.units[u] and string.sub(u, -6) == "target" and string.len(u) > 6 then
      return NP.mtName[string.sub(u, 1, -7)]
    end
    return baseName(u)
  end)
  G("UnitPlayerControlled", function(u)
    if type(u) == "string" and string.sub(u, -6) == "target" and string.len(u) > 6 then return NP.pet[string.sub(u, 1, -7)] and 1 or nil end
    return nil
  end)
  G("SendAddonMessage", function(prefix, msg, chan) table.insert(NP.sent, prefix .. "|" .. msg .. "|" .. chan) end)
  G("GetRaidRosterInfo", function(i)
    local r = NP.roster[i]
    if not r then return nil end
    return r[1], 0, 1, 60, "Warrior", "WARRIOR", "Zone", 1, nil, r[2]
  end)
  G("UnitDebuff", function(u, i) local a = NP.tdebuffs[i]; if not a then return nil end return a.tex, a.count end)
end

local function texable(t, path)
  t.tex = path
  t.SetTexture = function(self, p) self.tex = p end
  t.GetTexture = function(self) return self.tex end
  t.SetTexCoord = function(self, a, b, c, d, e, f, g, h) self.tc4 = { a, b, c, d, e, f, g, h } end
  return t
end

-- NP_PLATE(guid, { hp = 50, hpMax = 100, r = 1, g = 0, b = 0, name = "Mob", level = "60", mark = 3, cast = { v, lo, hi }, ... })
function NP_PLATE(guid, o)
  o = o or {}
  local p = MKPLATE(guid, o)
  local hb = CreateFrame("StatusBar", nil, p)
  local cb = CreateFrame("StatusBar", nil, p)
  hb.SetStatusBarTexture = function(self, t) self.sbtex = t end
  cb.SetStatusBarTexture = function(self, t) self.sbtex = t end
  hb:SetMinMaxValues(0, o.hpMax or 100)
  hb:SetValue(o.hp or 100)
  hb:SetStatusBarColor(o.r or 1, o.g or 0, o.b or 0, 1)
  cb:SetMinMaxValues(0, 1)
  cb:SetValue(0)
  cb:Hide()
  local border = texable(p:CreateTexture(nil, "ARTWORK"))
  border:SetTexture("Interface\\Tooltips\\Nameplate-Border")
  local glow = texable(p:CreateTexture(nil, "ARTWORK"))
  glow:SetTexture("Interface\\Tooltips\\Nameplate-Glow")
  local name = p:CreateFontString(nil, "OVERLAY")
  name:SetText(o.name or "Mob")
  local level = p:CreateFontString(nil, "OVERLAY")
  level:SetText(o.level or "60")
  local licon = texable(p:CreateTexture(nil, "ARTWORK"))
  licon:SetTexture("Interface\\Tooltips\\Nameplate-Boss")
  local ricon = texable(p:CreateTexture(nil, "ARTWORK"))
  p.GetChildren = function(self) return hb, cb end
  p.GetRegions = function(self) return border, glow, name, level, licon, ricon end
  p.np = { hb = hb, cb = cb, border = border, name = name, level = level, ricon = ricon }
  if o.alpha then p:SetAlpha(o.alpha) end
  W.units[guid].friend = o.friend and true or false
  W.units[guid].canAttack = not o.friend
  return p
end
