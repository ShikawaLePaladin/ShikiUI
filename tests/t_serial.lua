-- t_serial : serialisation sure (aller-retour, rejets, aucune evaluation de code).
local SUI = ShikiUI
local S = SUI.Serial
SECTION("t_serial : aller-retour")

local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k, v in pairs(b) do if a[k] == nil then return false end end
  return true
end

local cases = {
  { name = "table vide", v = {} },
  { name = "nombres", v = { a = 1, b = -2.5, c = 0, d = 1e30, e = 123456789012 } },
  { name = "booleens", v = { t = true, f = false } },
  { name = "chaines speciales", v = { s = 'guillemet " et \\ antislash', u = "", sp = "a b\tc" } },
  { name = "imbrique", v = { x = { y = { z = { w = 1 } } }, l = { l = 5, b = 6 } } },
  { name = "cles speciales", v = { ["units.width"] = 200, ["a:b,c}d"] = 1 } },
}
for i = 1, table.getn(cases) do
  local c = cases[i]
  local enc = S.Encode(c.v)
  local dec, err = S.Decode(enc)
  T("decode " .. c.name .. " : " .. tostring(err), dec ~= nil)
  T("aller-retour " .. c.name, dec ~= nil and same(c.v, dec))
  local packed = S.Pack(c.v)
  local up, err2 = S.Unpack(packed)
  T("pack/unpack " .. c.name .. " : " .. tostring(err2), up ~= nil and same(c.v, up))
end

SECTION("t_serial : format et somme de controle")
local p = S.Pack({ a = 1 })
EQ("en-tete", string.sub(p, 1, 5), "SUI1:")
EQ("somme sur 8 chiffres hexa", string.find(string.sub(p, 6, 13), "^%x%x%x%x%x%x%x%x$") ~= nil, true)
EQ("separateur", string.sub(p, 14, 14), ":")
EQ("corps", string.sub(p, 15), '{"a":1}')
EQ("somme stable", S.Checksum("abc"), S.Checksum("abc"))
T("somme differente", S.Checksum("abc") ~= S.Checksum("abd"))
T("espaces autour tolerees", S.Unpack("  \n" .. p .. " \n ") ~= nil)
-- alteration d'un seul caractere
local altered = string.sub(p, 1, 16) .. "9" .. string.sub(p, 18)
local r, e = S.Unpack(altered)
EQ("alteration refusee", r, nil)
CONTAINS("alteration : raison", e, "somme de controle")

SECTION("t_serial : entrees hostiles")
local function bad(name, s)
  local r2, e2 = S.Unpack(s)
  T(name .. " refuse", r2 == nil and type(e2) == "string")
end
local function badBody(name, body)
  local r2, e2 = S.Decode(body)
  T(name .. " refuse (" .. tostring(e2) .. ")", r2 == nil and type(e2) == "string")
end
bad("nil", nil)
bad("nombre", 5)
bad("vide", "")
bad("sans en-tete", "hello")
bad("mauvaise version", "SUI2:00000000:{}")
bad("pas de somme", "SUI1:abcdef")
bad("somme fausse", "SUI1:00000000:{}")
badBody("code Lua", "os.exit()")
badBody("fonction", "function() end")
badBody("table non fermee", '{"a":1')
badBody("virgule en trop", '{"a":1,}')
badBody("cle sans guillemets", "{a:1}")
badBody("deux-points manquant", '{"a" 1}')
badBody("chaine non terminee", '{"a":"x}')
badBody("echappement tronque", '{"a":"x\\')
badBody("donnees en trop", '{"a":1} extra')
badBody("nombre invalide", '{"a":1.2.3}')
badBody("nombre vide", '{"a":-}')
badBody("hexadecimal", '{"a":0x10}')
badBody("nan", '{"a":nan}')
badBody("trop profond", string.rep('{"a":', 12) .. "1" .. string.rep("}", 12))
local huge = '{"a":"' .. string.rep("x", 70000) .. '"}'
badBody("trop long", huge)
-- limite de profondeur a l'encodage
local deep = {}
local cur = deep
for _ = 1, 10 do cur.n = {}; cur = cur.n end
ERR("encode table trop profonde", S.Encode, deep)
ERR("encode fonction seule", S.Encode, function() end)
EQ("fonction dans une table : ignoree", S.Encode({ f = function() end, a = 1 }), '{"a":1}')
local cyc = {}
cyc.self = cyc
ERR("encode cycle", S.Encode, cyc)

-- nombres speciaux nettoyes
local enc = S.Encode({ n = 0 / 0, i = 1 / 0 })
local dec = S.Decode(enc)
T("nan/inf encodes en 0", dec ~= nil and dec.n == 0 and dec.i == 0)

SECTION("t_serial : evaluation de code impossible")
-- une charge utile qui ressemble a du Lua ne s'execute jamais


local ok = pcall(function() return S.Decode('{"a":"x"}; RAN = true') end)
T("pas d effet de bord", rawget(_G, "RAN") == nil)
DONE()
