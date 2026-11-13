// Lecture seule : charge un SavedVariables pfUI (Lua) et affiche pfUI_config a plat. Usage : node pfui_dump.js <fichier> [section]
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require(path.join('C:/Temp/ccx/luatest/node_modules', 'fengari'));
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const file = process.argv[2], only = process.argv[3];
const src = fs.readFileSync(file, 'latin1');
const code = src + `
local out = {}
local function walk(t, prefix, depth)
  if depth > 4 then return end
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  for _, ks in ipairs(keys) do
    local v = t[ks]; if v == nil then v = t[tonumber(ks)] end
    if type(v) == "table" then walk(v, prefix .. ks .. ".", depth + 1)
    else out[#out + 1] = prefix .. ks .. " = " .. tostring(v) end
  end
end
if pfUI_config then walk(pfUI_config, "", 0) end
return table.concat(out, "\\n")
`;
const s = to_luastring(code);
if (lauxlib.luaL_loadbuffer(L, s, s.length, to_luastring('@sv')) || lua.lua_pcall(L, 0, 1, 0)) {
  console.log('ERREUR : ' + lua.lua_tojsstring(L, -1)); process.exit(1);
}
const lines = lua.lua_tojsstring(L, -1).split('\n');
for (const l of lines) if (!only || l.startsWith(only + '.')) console.log(l);
