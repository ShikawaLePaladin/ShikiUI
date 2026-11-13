-- t_boot : SavedVariables au demarrage (langue, profil par personnage, mode du menu, premier lancement) et contenu apres jeu.
local SUI = ShikiUI
local C = SUI.Config

SECTION("t_boot : base existante")
BOOT({ db = {
  v = 1,
  global = { ["ui.locale"] = "en", firstRun = false, menuMode = "expert" },
  profiles = { Default = { v = {}, pos = {} }, Tank = { v = { ["units.width"] = 240 }, pos = {}, role = "tank" } },
  chars = { ["Shikiwa-TestRealm"] = "Tank", ["Autre-TestRealm"] = "Default" },
} })
Pump(2)
EQ("langue restauree", SUI.locale, "en")
CONTAINS("bandeau en anglais", CHATTEXT(), "loaded")
EQ("profil du personnage", C.curName, "Tank")
EQ("valeur du profil", C.Get("units.width"), 240)
EQ("role du profil", C.GetRole(), "tank")
EQ("cadre construit a la taille du profil", SUI.Units.frames.player:GetWidth(), 240)
EQ("pas d'assistant (deja fait)", SUI.Menu.wiz, nil)
SlashCmdList["SHIKIUI"]("")
EQ("mode du menu restaure", SUI.Menu.mode, "all")
SUI.Menu.Hide()

SECTION("t_boot : contenu des SavedVariables")
C.Set("units.height", 33)
C.Set("units.range", false)
C.SetPos("unit.target", 50, 60)
SlashCmdList["SHIKIUI"]("simple")
local db = ShikiUIDB
EQ("meme table que celle injectee", db, C.db)
EQ("version de base", db.v, 2)
EQ("profil memorise", db.chars["Shikiwa-TestRealm"], "Tank")
EQ("ecart enregistre", db.profiles.Tank.v["units.height"], 33)
EQ("ecart booleen faux enregistre", db.profiles.Tank.v["units.range"], false)
EQ("position enregistree", db.profiles.Tank.pos["unit.target"].l, 50)
EQ("mode du menu enregistre", db.global.menuMode, "essential")
local n = 0
for k, v in pairs(db.profiles.Tank.v) do
  n = n + 1
  T("seulement des valeurs simples : " .. k, type(v) == "number" or type(v) == "string" or type(v) == "boolean")
end
EQ("pas de valeur par defaut stockee", n, 3)   -- width, height, range
T("aucune fonction ni frame dans la base", (function()
  local function scan(t, depth)
    if depth > 6 then return false end
    for k, v in pairs(t) do
      if type(v) == "function" or type(v) == "userdata" then return false end
      if type(v) == "table" and not scan(v, depth + 1) then return false end
    end
    return true
  end
  return scan(db, 0)
end)())
-- serialisable (preuve que la base reste saine)
local ok = pcall(SUI.Serial.Encode, db)
EQ("la base entiere est serialisable", ok, true)

SECTION("t_boot : autre personnage")
Fire("PLAYER_LOGOUT")
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
