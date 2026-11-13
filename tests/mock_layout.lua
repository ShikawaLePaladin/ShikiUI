-- mock_layout.lua : geometrie opt-in. Avec W.layout = true, GetLeft / GetBottom / GetRight / GetTop des frames creees par CreateFrame suivent
-- leur PREMIER SetPoint (ancrage relatif a UIParent ou a un autre frame, decalages multiplies par l'echelle du frame).
-- Sans W.layout, le comportement de mock_wow.lua est inchange (100, 100). Aide de test seulement : les valeurs sont des DONNEES DE TEST.
W = W or {}
W.layout = false

local FR = {
  TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
  BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

-- Rectangle ecran (gauche, bas, largeur, hauteur) en unites UIParent ; nil si le frame n'a aucun ancrage exploitable.
local function rect(f, depth)
  if f == UIParent or f == nil then return 0, 0, UIParent:GetWidth(), UIParent:GetHeight() end
  if (depth or 0) > 30 then return nil end
  local p = f.points and f.points[1]
  local sc = f.scale or 1
  local w, h = (f.w or 0) * sc, (f.h or 0) * sc
  if not p or p[1] == "ALLPOINTS" then
    if f.left or f.bottom then return (f.left or 100) * sc, (f.bottom or 100) * sc, w, h end
    return nil
  end
  local rl, rb, rw, rh = rect(p[2], (depth or 0) + 1)
  if not rl then return nil end
  local a = FR[p[3] or p[1]] or FR.CENTER
  local ax, ay = rl + rw * a[1], rb + rh * a[2]
  local pf = FR[p[1]] or FR.CENTER
  local x = ax + (p[4] or 0) * sc - pf[1] * w
  local y = ay + (p[5] or 0) * sc - pf[2] * h
  return x, y, w, h
end
W.rect = rect

local rawCreate = CreateFrame
CreateFrame = function(kind, name, parent, tmpl)
  local f = rawCreate(kind, name, parent, tmpl)
  local oL, oB, oR, oT = f.GetLeft, f.GetBottom, f.GetRight, f.GetTop
  f.GetLeft = function(self)
    if W.layout then local x, y, w, h = rect(self); if x then return x / (self.scale or 1) end end
    return oL(self)
  end
  f.GetBottom = function(self)
    if W.layout then local x, y, w, h = rect(self); if x then return y / (self.scale or 1) end end
    return oB(self)
  end
  f.GetRight = function(self)
    if W.layout then local x, y, w, h = rect(self); if x then return (x + w) / (self.scale or 1) end end
    return oR(self)
  end
  f.GetTop = function(self)
    if W.layout then local x, y, w, h = rect(self); if x then return (y + h) / (self.scale or 1) end end
    return oT(self)
  end
  return f
end
