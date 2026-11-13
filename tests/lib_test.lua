-- lib_test.lua : petites aides communes aux suites (assertions, demarrage de l'addon).
PASS, FAIL = 0, 0
FAILS = {}

function T(name, cond)
  if cond then
    PASS = PASS + 1
  else
    FAIL = FAIL + 1
    table.insert(FAILS, name)
    print("  FAIL : " .. name)
  end
end

function EQ(name, got, want)
  if got == want then
    PASS = PASS + 1
  else
    FAIL = FAIL + 1
    table.insert(FAILS, name)
    print("  FAIL : " .. name .. " -> obtenu " .. tostring(got) .. ", attendu " .. tostring(want))
  end
end

function NEAR(name, got, want, eps)
  if type(got) == "number" and math.abs(got - want) <= (eps or 0.0001) then
    PASS = PASS + 1
  else
    FAIL = FAIL + 1
    table.insert(FAILS, name)
    print("  FAIL : " .. name .. " -> obtenu " .. tostring(got) .. ", attendu " .. tostring(want))
  end
end

-- l'appel doit lever une erreur (pcall)
function ERR(name, fn, ...)
  local ok = pcall(fn, ...)
  T(name .. " (doit echouer)", not ok)
end

function CONTAINS(name, s, sub)
  T(name .. " contient '" .. sub .. "'", type(s) == "string" and string.find(s, sub, 1, true) ~= nil)
end

function SECTION(name) print("# " .. name) end

-- Demarre l'addon comme le client : ADDON_LOADED -> PLAYER_LOGIN -> PLAYER_ENTERING_WORLD.
-- opts.db : SavedVariables a injecter ; opts.noworld : saute PLAYER_ENTERING_WORLD
function BOOT(opts)
  opts = opts or {}
  MKPLAYER()
  if opts.db then ShikiUIDB = opts.db end
  Fire("ADDON_LOADED", "ShikiUI")
  Fire("PLAYER_LOGIN")
  if not opts.noworld then Fire("PLAYER_ENTERING_WORLD") end
end

-- Un tour de minuterie suffisant pour traiter les rafraichissements groupes.
function SETTLE(n)
  Pump(0.06, n or 3)
end

function DONE()
  print(string.format("  %d ok, %d echec(s)", PASS, FAIL))
  if FAIL > 0 then os.exit(1) end
  TESTS_DONE = true
end
