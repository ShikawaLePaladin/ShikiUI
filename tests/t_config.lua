-- t_config : registre, validation, profils, roles, positions, export / import, SavedVariables corrompues.
local SUI = ShikiUI
local C = SUI.Config

SECTION("t_config : avant Init")
EQ("Get sans base : defaut", C.Get("ui.scale"), 1.0)
EQ("Get cle inconnue", C.Get("nope"), nil)
EQ("GetGlobal sans base", C.GetGlobal("x"), nil)

-- SavedVariables corrompues : l'addon doit demarrer proprement
SECTION("t_config : base corrompue")
BOOT({ db = {
  profiles = { Default = { v = { ["units.width"] = "abc", ["nope.key"] = 1, ["ui.locale"] = "en", ["ui.scale"] = 99, ["units.hptext"] = "bidon", ["ui.locked"] = false, ["units.smooth"] = false }, pos = "x" }, Cassee = "oops" },
  chars = "oops", global = "oops",
} })
EQ("aucune erreur interne", SUI.errCount, 0)
EQ("largeur invalide retiree", C.cur.v["units.width"], nil)
EQ("cle inconnue retiree", C.cur.v["nope.key"], nil)
EQ("cle globale retiree du profil", C.cur.v["ui.locale"], nil)
EQ("echelle hors bornes ramenee au maximum", C.Get("ui.scale"), 1.3)
EQ("choix invalide retire", C.cur.v["units.hptext"], nil)
EQ("valeur valide conservee", C.Get("units.smooth"), false)
EQ("ancien ui.locked=false reverrouille au demarrage (Mover)", C.Get("ui.locked"), true)
EQ("pos invalide remplace", type(C.cur.pos), "table")
EQ("global reconstruit", type(C.db.global), "table")
EQ("langue par defaut fr", C.Get("ui.locale"), "fr")
EQ("langue effective fr", SUI.locale, "fr")
EQ("premier lancement", C.GetGlobal("firstRun"), true)

SECTION("t_config : validation")
local function V(k, v) local ok, nv = C.Validate(k, v); return ok, nv end
local ok, nv = V("ui.scale", 1.0); T("scale 1.0", ok and nv == 1.0)
ok, nv = V("ui.scale", 0.1); T("scale sous le min -> 0.7", ok and nv == 0.7)
ok, nv = V("ui.scale", 5); T("scale au dessus du max -> 1.3", ok and nv == 1.3)
ok, nv = V("ui.scale", 1.02); NEAR("scale arrondie au pas 0.05", nv, 1.0)
ok, nv = V("ui.scale", 1.03); NEAR("scale arrondie au pas 0.05 (haut)", nv, 1.05)
ok, nv = V("ui.scale", "1.1"); T("scale texte numerique", ok and math.abs(nv - 1.1) < 1e-9)
ok = V("ui.scale", "abc"); EQ("scale texte invalide", ok, false)
ok = V("ui.scale", 0 / 0); EQ("scale NaN", ok, false)
ok = V("ui.scale", true); EQ("scale booleen", ok, false)
ok = V("ui.scale", {}); EQ("scale table", ok, false)
ok = V("ui.scale", nil); EQ("scale nil", ok, false)
ok, nv = V("ui.locked", 1); T("bool depuis 1", ok and nv == true)
ok, nv = V("ui.locked", 0); T("bool depuis 0", ok and nv == false)
ok = V("ui.locked", "true"); EQ("bool depuis texte", ok, false)
ok = V("ui.accent", "blue"); EQ("choix valide", ok, true)
ok = V("ui.accent", "rose"); EQ("choix invalide", ok, false)
ok = V("ui.accent", 3); EQ("choix numerique", ok, false)
ok = V("unknown.key", 1); EQ("cle inconnue", ok, false)
ok, nv = V("units.width", 197); EQ("pas 5 : 197 -> 195", nv, 195)
ok, nv = V("units.width", 198); EQ("pas 5 : 198 -> 200", nv, 200)
ok, nv = V("units.height", 28.4); EQ("pas 1", nv, 28)

SECTION("t_config : lecture / ecriture")
EQ("defaut", C.Get("units.width"), 180)
EQ("Set ok", C.Set("units.width", 200), true)
EQ("Get", C.Get("units.width"), 200)
EQ("stocke comme ecart", C.cur.v["units.width"], 200)
C.Set("units.width", 180)
EQ("retour au defaut : ecart supprime", C.cur.v["units.width"], nil)
EQ("Set invalide refuse", C.Set("units.width", "x"), false)
EQ("valeur inchangee", C.Get("units.width"), 180)
C.Set("units.width", 9999)
EQ("Set borne", C.Get("units.width"), 320)
C.Set("units.width", 180)

-- observateurs
local seen = {}
C.Watch("units.", function(k, v) table.insert(seen, tostring(k) .. "=" .. (type(v) == "number" and string.format("%d", v) or tostring(v))) end)
local broken = function() error("watcher casse") end
C.Watch("zzz", broken)
C.Set("units.height", 30)
C.Set("units.height", 30)      -- inchange : pas de notification
C.Set("ui.scale", 1.1)
EQ("notifie une seule fois, seulement le prefixe", table.concat(seen, ","), "units.height=30")
C.Notify("zzz.truc", 1)
T("watcher en erreur isole", SUI.errCount == 1)
C.Unwatch(broken)
seen = {}
seen = {}
C.Watch("units.", function(k, v) end)
C.Notify(nil, nil)
EQ("Notify(nil) : sans cle", table.getn(seen), 1)
C.Set("units.height", 28)
C.Set("ui.scale", 1.0)

-- cles globales : hors profil
SECTION("t_config : cles globales")
C.Set("ui.locale", "en")
EQ("langue en", C.Get("ui.locale"), "en")
EQ("stockee dans global", C.db.global["ui.locale"], "en")
EQ("pas dans le profil", C.cur.v["ui.locale"], nil)
EQ("locale effective", SUI.locale, "en")
C.NewProfile("Autre")
C.UseProfile("Autre")
EQ("la langue suit tous les profils", C.Get("ui.locale"), "en")
C.UseProfile("Default")
C.Set("ui.locale", "fr")
EQ("retour fr", SUI.locale, "fr")
EQ("refuse une langue inconnue", C.Set("ui.locale", "de"), false)

SECTION("t_config : profils")
C.Set("units.width", 220)
local okp, key = C.NewProfile("Copie", "Default")
EQ("copie ok", okp, true)
EQ("cle de message", key, "msg.profile.created")
EQ("copie identique", C.db.profiles.Copie.v["units.width"], 220)
C.db.profiles.Copie.v["units.width"] = 250
EQ("copie profonde (independante)", C.cur.v["units.width"], 220)
okp, key = C.NewProfile("Copie"); EQ("doublon", okp, false); EQ("doublon : message", key, "msg.profile.exists")
okp, key = C.NewProfile("Neuf", "Absent"); EQ("copie d'un profil inconnu", okp, false); EQ("message", key, "msg.profile.unknown")
for _, bad in ipairs({ "", "a/b", "x\"y", string.rep("a", 25), "a:b", "a\nb", "nom|c" }) do
  okp, key = C.NewProfile(bad)
  T("nom invalide refuse : '" .. string.gsub(bad, "\n", "\\n") .. "'", okp == false and key == "msg.profile.badname")
end
okp = C.NewProfile(nil); EQ("nom nil", okp, false)
okp = C.NewProfile(12); EQ("nom numerique", okp, false)
okp = C.NewProfile("Nom-2_x"); EQ("nom valide complexe", okp, true)
okp = C.NewProfile("avec espace"); EQ("espace refuse (ambigu en ligne de commande)", okp, false)
EQ("liste triee", table.concat(C.ListProfiles(), ","), "Autre,Copie,Default,Nom-2_x")
okp, key = C.UseProfile("Copie")
EQ("use", okp, true)
EQ("profil courant", C.curName, "Copie")
EQ("valeur du profil", C.Get("units.width"), 250)
EQ("memorise par personnage", C.db.chars["Shikiwa-TestRealm"], "Copie")
okp, key = C.UseProfile("Absent"); EQ("use inconnu", okp, false)
EQ("profil courant inchange", C.curName, "Copie")
okp, key = C.DeleteProfile("Copie"); EQ("suppression du profil actif refusee", okp, false); EQ("message", key, "msg.profile.current")
okp, key = C.DeleteProfile("Absent"); EQ("suppression inconnue", okp, false)
C.UseProfile("Default")
okp = C.DeleteProfile("Copie"); EQ("suppression ok", okp, true)
EQ("supprime", C.db.profiles.Copie, nil)
-- selection par defaut d'un profil disparu
C.db.chars["Shikiwa-TestRealm"] = "Disparu"
EQ("profil disparu -> Default", C.SelectProfile(), "Default")
-- dernier profil
C.db.profiles = { Default = C.db.profiles.Default }
C.curName = "Autre"
okp, key = C.DeleteProfile("Default"); EQ("dernier profil protege", okp, false); EQ("message dernier", key, "msg.profile.last")
C.curName = "Default"

SECTION("t_config : reinitialisation")
C.Set("units.width", 260)
C.SetPos("unit.player", 100, 200)
C.ApplyRole("tank")
local notified = 0
C.Watch("", function(k) if k == nil then notified = notified + 1 end end)
C.ResetProfile()
EQ("valeurs effacees", C.Get("units.width"), 180)
EQ("positions effacees", C.GetPos("unit.player"), nil)
EQ("role efface", C.GetRole(), nil)
EQ("notification globale", notified, 1)

SECTION("t_config : roles")
for _, role in ipairs(C.roleOrder) do
  local preset = C.roles[role]
  T("role " .. role .. " existe", preset ~= nil)
  for k, v in pairs(preset) do
    local okv = C.Validate(k, v)
    T("role " .. role .. " : cle valide " .. k, okv)
  end
end
EQ("4 roles", table.getn(C.roleOrder), 4)
EQ("role inconnu", C.ApplyRole("healer"), false)
EQ("role tank", C.ApplyRole("tank"), true)
EQ("tank : tot", C.Get("units.tot.enabled"), true)
EQ("tank : texte de vie", C.Get("units.hptext"), "both")
EQ("GetRole", C.GetRole(), "tank")
C.ApplyRole("heal")
EQ("heal : tot coupe", C.Get("units.tot.enabled"), false)
EQ("heal : texte", C.Get("units.hptext"), "percent")
C.ApplyRole("pvp")
EQ("pvp : pas de lissage", C.Get("units.smooth"), false)
local rolenote
C.Watch("role", function(k, v) rolenote = v end)
C.ApplyRole("dps")
EQ("notification du role", rolenote, "dps")
C.ResetProfile()

SECTION("t_config : positions")
EQ("pas de position", C.GetPos("a"), nil)
C.SetPos("a", 10.4, 20.6)
local l, b = C.GetPos("a")
EQ("arrondi l", l, 10)
EQ("arrondi b", b, 21)
C.cur.pos.bad = { l = "x", b = 1 }
EQ("position invalide ignoree", C.GetPos("bad"), nil)
C.cur.pos.bad2 = "x"
EQ("position non table ignoree", C.GetPos("bad2"), nil)
C.ClearPos("a")
EQ("effacee", C.GetPos("a"), nil)
C.SetPos("a", 1, 2)
C.ResetPositions()
EQ("toutes effacees", C.GetPos("a"), nil)

SECTION("t_config : export / import")
C.ResetProfile()
C.Set("units.width", 230)
C.Set("units.hptext", "both")
C.Set("ui.accent", "orange")
C.SetPos("unit.player", -230.4, 150)
C.ApplyRole("tank")
local str = C.Export()
EQ("export commence par SUI1", string.sub(str, 1, 5), "SUI1:")
T("export compact (ecarts seulement)", string.len(str) < 400)
CONTAINS("export contient la largeur", str, "units.width")
T("export sans cle par defaut", string.find(str, "units.height", 1, true) == nil)

local n0 = table.getn(C.ListProfiles())
local oki, name, acc, ign = C.Import(str)
EQ("import ok", oki, true)
EQ("nom du profil importe (collision -> suffixe)", name, "Default2")
EQ("acceptes", acc, 3)
EQ("ignores", ign, 0)
EQ("un profil de plus", table.getn(C.ListProfiles()), n0 + 1)
local imp = C.db.profiles.Default2
EQ("largeur importee", imp.v["units.width"], 230)
EQ("texte importe", imp.v["units.hptext"], "both")
EQ("accent importe", imp.v["ui.accent"], "orange")
EQ("position importee (arrondie)", imp.pos["unit.player"].l, -230)
EQ("role importe", imp.role, "tank")
EQ("le profil courant n'a pas bouge", C.curName, "Default")
-- nom explicite, deuxieme import : suffixes successifs
oki, name = C.Import(str, "Partage")
EQ("nom explicite", name, "Partage")
oki, name = C.Import(str, "Partage")
EQ("collision -> Partage2", name, "Partage2")
oki, name = C.Import(str, "mauvais/nom")
EQ("nom explicite invalide -> Import", name, "Import")

SECTION("t_config : imports hostiles")
local S = SUI.Serial
local function imp2(tbl) return C.Import(S.Pack(tbl)) end
local r1, e1 = C.Import("n'importe quoi"); T("texte quelconque", r1 == false and type(e1) == "string")
r1, e1 = C.Import(nil); EQ("nil", r1, false)
r1, e1 = imp2({ v = 2, c = {} }); EQ("mauvaise version", r1, false); EQ("raison", e1, "format")
r1, e1 = imp2({ v = 1 }); EQ("sans c", r1, false)
r1, e1 = imp2({ v = 1, c = "x" }); EQ("c non table", r1, false)
r1, e1 = imp2(5); EQ("charge non table", r1, false)
local ok1, nm, a1, i1 = imp2({ v = 1, c = { ["units.width"] = 9999, ["nope"] = 1, ["ui.locale"] = "en", ["units.hptext"] = "zzz", ["ui.locked"] = "oui", ["units.height"] = 30 } })
EQ("import partiel ok", ok1, true)
EQ("1 accepte (borne) + height", a1, 2)
EQ("4 ignores (inconnue, globale, choix, type)", i1, 4)
EQ("largeur bornee a l'import", C.db.profiles[nm].v["units.width"], 320)
EQ("locale non importee", C.db.profiles[nm].v["ui.locale"], nil)
EQ("la langue globale n'a pas change", C.Get("ui.locale"), "fr")
-- positions hostiles
local ok2, nm2, a2, i2 = imp2({ v = 1, c = {}, pos = { good = { l = 5, b = 6 }, far = { l = 99999, b = 0 }, text = { l = "a", b = 1 }, flat = 7, [string.rep("k", 41)] = { l = 1, b = 1 } } })
EQ("positions : ok", ok2, true)
EQ("positions : 1 bonne", C.db.profiles[nm2].pos.good.l, 5)
EQ("positions : hors ecran refusee", C.db.profiles[nm2].pos.far, nil)
EQ("positions : cle trop longue refusee", C.db.profiles[nm2].pos[string.rep("k", 41)], nil)
EQ("positions : 4 ignorees", i2, 4)
local many = {}
for i = 1, 200 do many["p" .. i] = { l = i, b = i } end
local ok3, nm3, a3, i3 = imp2({ v = 1, c = {}, pos = many })
local cnt = 0
for _ in pairs(C.db.profiles[nm3].pos) do cnt = cnt + 1 end
EQ("positions plafonnees a 128", cnt, 128)
EQ("role inconnu ignore", (function() local o, n = imp2({ v = 1, c = {}, role = "dieu" }); return C.db.profiles[n].role end)(), nil)
-- aucun effet sur le profil actif
EQ("profil actif intact", C.cur.v["units.width"], 230)
EQ("aucune erreur interne pendant les imports hostiles", SUI.errCount, 1)   -- 1 = le watcher casse volontairement plus haut
DONE()
