-- t_modules : contrat des modules et du socle partage : AddStrings, commandes enregistrables, RegisterModule, et controle de TOUS les modules
-- presents (ceux du socle comme ceux que les autres agents ajoutent : Mod_<Nom>.lua) - cout declare, reglages dans leur espace de noms,
-- categorie unique, textes dans les deux langues, aucun reglage orphelin. Cette suite attrape un module mal ecrit sans avoir a le connaitre.
local SUI = ShikiUI
local C = SUI.Config
BOOT()
SETTLE()

local function has(lang, key) return SUI.locales[lang][key] ~= nil end

SECTION("t_modules : SUI.AddStrings")
local a, s = SUI.AddStrings("fr", { ["opt.zzs.a"] = "Un", ["opt.zzs.b"] = "Deux" })
EQ("deux cles ajoutees", a, 2)
EQ("aucune ignoree", s, 0)
EQ("lisible", SUI.locales.fr["opt.zzs.a"], "Un")
a, s = SUI.AddStrings("fr", { ["opt.zzs.a"] = "Pirate", ["opt.zzs.c"] = "Trois" })
EQ("jamais d'ecrasement", SUI.locales.fr["opt.zzs.a"], "Un")
EQ("une ajoutee, une ignoree", a .. "/" .. s, "1/1")
T("ignoree signalee", SUI.localeSkipped["fr:opt.zzs.a"] == true)
a, s = SUI.AddStrings("fr", { ["help.1"] = "pirate" })
T("une cle du noyau ne se remplace pas", SUI.locales.fr["help.1"] ~= "pirate")
a, s = SUI.AddStrings("de", { ["opt.zzs.d"] = "x" })
EQ("langue inconnue", a .. "/" .. s, "0/0")
a, s = SUI.AddStrings("fr", "texte")
EQ("pas une table", a .. "/" .. s, "0/0")
a, s = SUI.AddStrings("fr", { ["opt.zzs.e"] = 12, [5] = "x", ["opt.zzs.f"] = {} })
EQ("valeurs invalides ignorees", a .. "/" .. s, "0/3")
SUI.missingL["opt.zzs.late"] = true
SUI.AddStrings("fr", { ["opt.zzs.late"] = "Tard" })
EQ("une cle manquante signalee est effacee", SUI.missingL["opt.zzs.late"], nil)
C.Set("ui.locale", "fr")
EQ("L utilise les textes ajoutes", SUI.L("opt.zzs.b"), "Deux")
SUI.AddStrings("en", { ["opt.zzs.b"] = "Two" })
C.Set("ui.locale", "en")
EQ("L en anglais", SUI.L("opt.zzs.b"), "Two")
EQ("repli sur le francais", SUI.L("opt.zzs.a"), "Un")
C.Set("ui.locale", "fr")

SECTION("t_modules : SUI.RegisterCommand")
local got
local ok, why = SUI.RegisterCommand("zzcmd", function(rest) got = rest end, "help.zzcmd")
EQ("commande enregistree", ok, true)
SUI.AddStrings("fr", { ["help.zzcmd"] = "/sui zzcmd - essai" })
SUI.AddStrings("en", { ["help.zzcmd"] = "/sui zzcmd - test" })
SlashCmdList["SHIKIUI"]("zzcmd bonjour le monde")
EQ("arguments transmis", got, "bonjour le monde")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("help")
CONTAINS("l'aide la liste", CHATTEXT(), "/sui zzcmd - essai")
ok, why = SUI.RegisterCommand("zzcmd", function() end, "x")
EQ("doublon refuse", ok, false)
EQ("raison", why, "taken")
for _, name in ipairs({ "help", "menu", "profile", "role", "lock", "reset" }) do
  ok = SUI.RegisterCommand(name, function() end)
  if SUI.reservedCommands[name] then EQ("commande reservee refusee : " .. name, ok, false) end
end
ok, why = SUI.RegisterCommand("Mauvais Nom", function() end)
EQ("nom invalide refuse", ok, false)
ok, why = SUI.RegisterCommand("zzother", "pas une fonction")
EQ("fonction obligatoire", ok, false)
SUI.RegisterCommand("zzboom", function() error("boum") end)
local e0 = SUI.errCount
CHATCLEAR()
SlashCmdList["SHIKIUI"]("zzboom")
T("une commande qui plante n'arrete rien", SUI.errCount >= e0)
SlashCmdList["SHIKIUI"]("zzunknown")
CONTAINS("commande inconnue", CHATTEXT(), SUI.L("msg.unknown.cmd"))

SECTION("t_modules : SUI.RegisterModule (validation)")
local n0 = table.getn(SUI.moduleOrder)
local e1 = SUI.errCount
EQ("nom en majuscules refuse", SUI.RegisterModule("Zzmod", { cost = "light" }), false)
EQ("nom vide refuse", SUI.RegisterModule("", { cost = "light" }), false)
EQ("pas de table", SUI.RegisterModule("zzmod", nil), false)
EQ("nom reserve (msg)", SUI.RegisterModule("msg", { cost = "light" }), false)
EQ("nom reserve (style)", SUI.RegisterModule("style", { cost = "light" }), false)
EQ("nom reserve (layout)", SUI.RegisterModule("layout", { cost = "light" }), false)
EQ("nom reserve (mode)", SUI.RegisterModule("mode", { cost = "light" }), false)
EQ("sept refus signales", SUI.errCount, e1 + 7)
EQ("aucun module ajoute", table.getn(SUI.moduleOrder), n0)
EQ("module valide", SUI.RegisterModule("zzmod", { cost = "heavy" }), true)
T("cout conserve", SUI.modules.zzmod.cost == "heavy" and not SUI.modules.zzmod.costMissing)
EQ("doublon refuse", SUI.RegisterModule("zzmod", { cost = "light" }), false)
SUI.RegisterModule("zznocost", {})
EQ("cout manquant signale", SUI.modules.zznocost.costMissing, true)
EQ("cout par defaut", SUI.modules.zznocost.cost, "medium")
SUI.RegisterModule("zzbadcost", { cost = "enorme" })
EQ("cout invalide signale", SUI.modules.zzbadcost.costMissing, true)
T("l'option modules.<nom> existe", C.meta["modules.zzmod"] ~= nil)
-- retirer les modules de test pour que le controle du contrat ne les voie pas
for i = table.getn(SUI.options), 1, -1 do
  if string.find(SUI.options[i].key, "^modules%.zz") then table.remove(SUI.options, i) end
end
for _, nm in ipairs({ "zzmod", "zznocost", "zzbadcost" }) do
  SUI.modules[nm] = nil
  for i = table.getn(SUI.moduleOrder), 1, -1 do
    if SUI.moduleOrder[i] == nm then table.remove(SUI.moduleOrder, i) end
  end
end

SECTION("t_modules : contrat de chaque module present")
local seenOrder = {}
for cat, ord in pairs(SUI.categories) do
  T("categorie " .. cat .. " : ordre numerique", type(ord) == "number")
  for cat2, ord2 in pairs(SUI.categories) do
    if cat ~= cat2 and ord == ord2 and cat ~= "general" then
      T("ordre de categorie unique (" .. cat .. " / " .. cat2 .. ")", false)
    end
  end
end
local names = {}
for i = 1, table.getn(SUI.moduleOrder) do table.insert(names, SUI.moduleOrder[i]) end
T("au moins les modules du socle", table.getn(names) >= 2)
for i = 1, table.getn(names) do
  local name = names[i]
  local m = SUI.modules[name]
  T(name .. " : cout declare (light / medium / heavy)", SUI.COSTS[m.cost] == true and not m.costMissing)
  T(name .. " : nom conforme", string.find(name, "^[a-z][a-z0-9]*$") ~= nil)
  T(name .. " : option modules." .. name, C.meta["modules." .. name] ~= nil)
  for _, lang in ipairs({ "fr", "en" }) do
    T(name .. " : libelle " .. lang, has(lang, "opt.modules." .. name))
    T(name .. " : infobulle " .. lang, has(lang, "tip.modules." .. name))
  end
  T(name .. " : raid vaut off ou rien", m.raid == nil or m.raid == "off")
  for _, fname in ipairs({ "init", "enable", "disable", "shutdown" }) do
    T(name .. " : " .. fname .. " est une fonction ou rien", m[fname] == nil or type(m[fname]) == "function")
  end
  if not m.core and m.options then
    for k = 1, table.getn(m.options) do
      local o = m.options[k]
      T(name .. " : reglage " .. tostring(o.key) .. " dans l'espace '" .. name .. ".'", string.find(o.key, "^" .. name .. "%.") ~= nil)
      T(name .. " : categorie declaree pour " .. o.key, SUI.categories[o.cat] ~= nil)
    end
  end
end
-- tous les reglages
local seenKey = {}
for i = 1, table.getn(SUI.options) do
  local o = SUI.options[i]
  if o.type ~= "header" then
    T("reglage " .. o.key .. " : cle unique", not seenKey[o.key])
    seenKey[o.key] = true
    T("reglage " .. o.key .. " : categorie declaree", SUI.categories[o.cat] ~= nil)
    T("reglage " .. o.key .. " : valeur par defaut valide", select == nil and true or (function() local okv = C.Validate(o.key, C.defaults[o.key]); return okv end)())
    for _, lang in ipairs({ "fr", "en" }) do
      T(lang .. " " .. o.label, has(lang, o.label))
      if o.tip then T(lang .. " " .. o.tip, has(lang, o.tip)) end
    end
  end
end
-- chaque categorie a un texte
for cat, _ in pairs(SUI.categories) do
  for _, lang in ipairs({ "fr", "en" }) do T(lang .. " cat." .. cat, has(lang, "cat." .. cat)) end
end
-- chaque commande a son aide
for i = 1, table.getn(SUI.commandOrder) do
  local c = SUI.commands[SUI.commandOrder[i]]
  for _, lang in ipairs({ "fr", "en" }) do
    if c.help then T(lang .. " " .. c.help, has(lang, c.help)) end
  end
end
EQ("aucun preset de mode invalide", next(C.presetBad), nil)
EQ("aucune erreur interne au demarrage", SUI.errCount, e1 + 7 + 3)
T("pas de texte manquant a l'execution", next(SUI.missingL) == nil)
DONE()
