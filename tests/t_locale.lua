-- t_locale : toutes les cles utilisees par l'interface existent en fr et en en ; repli et langue automatique.
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
BOOT()

local function has(lang, key) return SUI.locales[lang][key] ~= nil end

SECTION("t_locale : cles dynamiques")
for i = 1, table.getn(SUI.options) do
  local o = SUI.options[i]
  if o.type ~= "header" then
    for _, lang in ipairs({ "fr", "en" }) do
      T(lang .. " libelle " .. o.label, has(lang, o.label))
      if o.tip then T(lang .. " infobulle " .. o.tip, has(lang, o.tip)) end
      if o.choices and not o.choiceText then
        for k = 1, table.getn(o.choices) do
          local key = "choice." .. o.key .. "." .. o.choices[k]
          T(lang .. " choix " .. key, has(lang, key))
        end
      end
    end
    T("infobulle declaree : " .. o.key, o.tip ~= nil)
    T("libelle declare : " .. o.key, o.label ~= nil)
  end
end
for _, lang in ipairs({ "fr", "en" }) do
  for i = 1, 11 do T(lang .. " help." .. i, has(lang, "help." .. i)) end
  for _, role in ipairs(C.roleOrder) do T(lang .. " role." .. role, has(lang, "role." .. role)) end
  T(lang .. " cat.all", has(lang, "cat.all"))
  for cat, _ in pairs(SUI.categories) do T(lang .. " cat." .. cat, has(lang, "cat." .. cat)) end
end

SECTION("t_locale : parcours complet dans les deux langues")
for _, lang in ipairs({ "fr", "en" }) do
  C.Set("ui.locale", lang)
  SlashCmdList["SHIKIUI"]("expert")
  for _, pg in ipairs({ "home", "modules", "styles" }) do SUI.Menu.Open(pg) end
  for _, cat in ipairs({ "general", "units", "perf", "modules" }) do SUI.Menu.Open("cat", cat) end
  SlashCmdList["SHIKIUI"]("simple")
  SUI.Menu.ShowWizard(1); SUI.Menu.ShowWizard(2); SUI.Menu.ShowWizard(3)
  SUI.Menu.wiz:Hide()
  SlashCmdList["SHIKIUI"]("status")
  SlashCmdList["SHIKIUI"]("perf")
  SlashCmdList["SHIKIUI"]("help")
  SlashCmdList["SHIKIUI"]("profile")
  SlashCmdList["SHIKIUI"]("role tank")
  SlashCmdList["SHIKIUI"]("import zzz")
  SlashCmdList["SHIKIUI"]("emergency on")
  SlashCmdList["SHIKIUI"]("emergency off")
  SlashCmdList["SHIKIUI"]("profile use Nope")
  SlashCmdList["SHIKIUI"]("profile new a/b")
  SlashCmdList["SHIKIUI"]("zzz")
  MKTARGET({ dead = true, isPlayer = true, class = "MAGE", hp = 0, hpMax = 100 })
  Fire("PLAYER_TARGET_CHANGED")
  SETTLE()
  SUI.Menu.Hide()
end
C.Set("ui.locale", "fr")
local missing = {}
for k, _ in pairs(SUI.missingL) do table.insert(missing, k) end
table.sort(missing)
EQ("aucune cle manquante : " .. table.concat(missing, ","), table.getn(missing), 0)
local junk = false
for i = 1, table.getn(CHAT) do
  if string.find(CHAT[i], "%f[%w]msg%.") or string.find(CHAT[i], "%f[%w]opt%.") then junk = true end
end
EQ("aucune cle brute affichee dans le chat", junk, false)

SECTION("t_locale : comportement de L")
SUI.SetLocale("fr")
EQ("francais", L("menu.simple"), "Simple")
EQ("format", L("msg.profile.created", "X"), "Profil cree : X")
SUI.SetLocale("en")
EQ("anglais", L("msg.profile.created", "X"), "Profile created: X")
EQ("cle inconnue : renvoyee telle quelle", L("pas.une.cle"), "pas.une.cle")
EQ("cle inconnue memorisee", SUI.missingL["pas.une.cle"], true)
SUI.locales.en["test.seulement.fr"] = nil
SUI.locales.fr["test.seulement.fr"] = "Francais seul"
EQ("repli sur le francais", L("test.seulement.fr"), "Francais seul")
SUI.locales.fr["test.seulement.fr"] = nil
SUI.SetLocale("de")
EQ("langue inconnue -> fr", SUI.locale, "fr")
W.locale = "frFR"; SUI.SetLocale("auto")
EQ("auto frFR", SUI.locale, "fr")
W.locale = "enUS"; SUI.SetLocale("auto")
EQ("auto enUS", SUI.locale, "en")
W.locale = "deDE"; SUI.SetLocale("auto")
EQ("auto autre -> en", SUI.locale, "en")
SUI.SetLocale("fr")
EQ("argument nombre sans marqueur", L("menu.title", 5), "ShikiUI")
DONE()
