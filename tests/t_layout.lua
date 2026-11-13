-- t_layout : mises en page (Layouts.lua) et combinaison style x mise en page x mode (Normal / Raid) x role / classe.
-- Regle verifiee : le style ne porte AUCUNE position, la mise en page ne porte AUCUNE couleur ; l'ecart de l'utilisateur dans un mode
-- bat toujours une mise en page ; la mise en page appliquee ecrit dans le profil de base (le dernier ecrit gagne).
local SUI = ShikiUI
local C = SUI.Config
local S = SUI.Style
local TH = SUI.Theme
local LY = SUI.Layout
local U = SUI.Units
BOOT()
SETTLE()

local W_, H_ = UIParent:GetWidth(), UIParent:GetHeight()
local function pos(key)
  local l, b = C.GetPos(key)
  return l, b
end

SECTION("t_layout : registre")
EQ("fonction publique", type(SUI.RegisterLayout), "function")
T("les mises en page livrees", SUI.layouts.classic and SUI.layouts.center and SUI.layouts.compact and SUI.layouts.sides)
EQ("id trop court", SUI.RegisterLayout("a", {}), false)
EQ("id en majuscules", SUI.RegisterLayout("Joli", {}), false)
EQ("id avec espace", SUI.RegisterLayout("deux mots", {}), false)
EQ("pas une table", SUI.RegisterLayout("zzlay", "x"), false)
EQ("doublon refuse", SUI.RegisterLayout("center", {}), false)
EQ("ajout", SUI.RegisterLayout("zzlay", { label = "mod.layout.name.classic", pos = { ["unit.player"] = { 0.1, 0.1 } } }), true)
EQ("nom affichable", LY.Label("classic"), "Classique")
EQ("nom inconnu : l'id", LY.Label("nimportequoi"), "nimportequoi")
EQ("sans label : l'id", LY.Label("center"), "Centre")
T("les cadres des unites sont enregistres", LY.items["unit.player"] and LY.items["unit.target"] and LY.items["unit.targettarget"])

SECTION("t_layout : application")
local ok, key, n, bad = LY.ApplyPreset("center")
EQ("applique", ok, true)
EQ("message", key, "msg.layout.applied")
EQ("rien d'ignore", bad, 0)
EQ("mise en page memorisee", C.cur.layout, "center")
EQ("Layout.Current", LY.Current(), "center")
local l, b = pos("unit.player")
EQ("joueur : x", l, math.floor(0.5 * W_ - 300 + 0.5))
EQ("joueur : y", b, math.floor(0.32 * H_ + 0.5))
l, b = pos("unit.target")
EQ("cible : x", l, math.floor(0.5 * W_ + 60 + 0.5))
-- le cadre a bouge
local f = U.frames.player
local p = f.points[1]
EQ("cadre : ancre", p[1], "BOTTOMLEFT")
NEAR("cadre : x", p[4], (0.5 * W_ - 300) / C.Get("ui.scale"), 1)
NEAR("cadre : y", p[5], (0.32 * H_) / C.Get("ui.scale"), 1)
ok, key = LY.ApplyPreset("nexistepas")
EQ("inconnue refusee", ok, false)
EQ("raison", key, "msg.layout.unknown")
EQ("memoire inchangee", C.cur.layout, "center")

SECTION("t_layout : variantes par role")
C.ApplyRole("heal")
l, b = pos("unit.player")
EQ("le role heal a sa variante", b, math.floor(0.22 * H_ + 0.5))
C.ApplyRole("tank")
l, b = pos("unit.player")
EQ("retour au tank : variante generale", b, math.floor(0.32 * H_ + 0.5))
EQ("tank : cadres plus grands", C.Get("units.width"), 200)
EQ("tank : hauteur", C.Get("units.height"), 30)
C.Set("layout.followrole", false)
C.ApplyRole("heal")
l, b = pos("unit.player")
EQ("suivi du role coupe : positions inchangees", b, math.floor(0.32 * H_ + 0.5))
C.Set("layout.followrole", true)
ok = LY.ApplyPreset("center", "heal")
l, b = pos("unit.player")
EQ("role explicite", b, math.floor(0.22 * H_ + 0.5))
ok, key = LY.ApplyPreset("center", "dps")
l, b = pos("unit.player")
EQ("role sans variante : partie generale", b, math.floor(0.32 * H_ + 0.5))

SECTION("t_layout : reinitialisation et glisser-deposer")
LY.ApplyPreset("classic")
EQ("classique : positions effacees", next(C.cur.pos), nil)
EQ("cadre revenu a sa place d'origine", f.points[1][1], "CENTER")
EQ("memorise", C.cur.layout, "classic")
LY.ApplyPreset("center")
C.SetPos("unit.player", 100, 100)
LY.Apply("unit.player")
l, b = pos("unit.player")
EQ("un deplacement a la main gagne (dernier ecrit)", l, 100)
EQ("les autres cadres gardent la mise en page", (pos("unit.target")), math.floor(0.5 * W_ + 60 + 0.5))
-- positions hostiles dans une mise en page
SUI.RegisterLayout("zzbad", { pos = { ["unit.player"] = { "a", 2 }, ["unit.target"] = "x", ["inconnu.cadre"] = { 0.5, 0.5 } }, v = { ["units.width"] = 99999, ["nokey.x"] = 1 } })
ok, key, n, bad = LY.ApplyPreset("zzbad")
EQ("mise en page piegee : appliquee sans erreur", ok, true)
T("elements invalides comptes", bad >= 3)
EQ("valeur hors bornes non ecrite", C.Get("units.width") ~= 99999, true)

SECTION("t_layout : style x mise en page x mode x role")
local ids = { "shiki", "pfstyle", "elvstyle", "blizzard" }
local lays = { "classic", "center", "compact", "sides" }
local expectPos = {
  center = { tank = 0.32, heal = 0.22, dps = 0.32, pvp = 0.32 },
  compact = { tank = 0.28, heal = 0.28, dps = 0.28, pvp = 0.28 },
  sides = { tank = 0.45, heal = 0.45, dps = 0.45, pvp = 0.45 },
}
C.ApplyRole("dps")
C.Set("layout.followrole", false)
local combos, errs0 = 0, SUI.errCount
for si = 1, table.getn(ids) do
  for li = 1, table.getn(lays) do
    for _, mode in ipairs({ "normal", "raid" }) do
      for _, role in ipairs({ "tank", "heal", "dps", "pvp" }) do
        combos = combos + 1
        SUI.Mode.Set(mode, "manual")
        C.Set("style.name", ids[si])
        C.ApplyRole(role)
        local tag = ids[si] .. "/" .. lays[li] .. "/" .. mode .. "/" .. role
        LY.ApplyPreset(lays[li], role)
        local pl, pb = pos("unit.player")
        if lays[li] == "classic" then
          T(tag .. " : positions d'origine", pl == nil)
        else
          EQ(tag .. " : position", pb, math.floor(expectPos[lays[li]][role] * H_ + 0.5))
        end
        local tok = S.Resolve(ids[si])
        T(tag .. " : style intact", math.abs(TH.c.bg[1] - tok.c.bg[1]) < 0.003 and TH.font == tok.font)
        EQ(tag .. " : style choisi", C.Get("style.name"), ids[si])
      end
    end
  end
end
SUI.Mode.Set("normal", "manual")
EQ("128 combinaisons", combos, 128)
EQ("aucune erreur interne", SUI.errCount, errs0)
-- le style ne bouge aucune position, la mise en page ne touche aucune couleur
LY.ApplyPreset("center", "dps")
local bgBefore = TH.c.bg[1]
local px, py = pos("unit.player")
C.Set("style.name", "light")
local qx, qy = pos("unit.player")
T("changer de style ne deplace rien", px == qx and py == qy)
local bg2 = TH.c.bg[1]
LY.ApplyPreset("sides", "dps")
EQ("changer de mise en page ne touche pas aux couleurs", TH.c.bg[1], bg2)
for i = 1, table.getn(SUI.options) do
  local o = SUI.options[i]
  if o.cat == "style" then T("la mise en page n'ecrit pas " .. o.key, not C.IsModified(o.key) or o.key == "style.name") end
end
C.Reset("style.name")

SECTION("t_layout : un ecart de l'utilisateur dans un mode bat la mise en page")
SUI.Mode.Set("raid", "manual")
C.Set("units.width", 120)
LY.ApplyPreset("compact", "dps")
EQ("en Raid : l'ecart de l'utilisateur tient", C.Get("units.width"), 120)
EQ("la mise en page est dans le profil", C.cur.v["units.width"], 150)
SUI.Mode.Set("normal", "manual")
EQ("en Normal : la mise en page", C.Get("units.width"), 150)
SUI.Mode.Set("raid", "manual")
C.ResetMode("raid")
EQ("apres reinit. du mode : la mise en page", C.Get("units.width"), 150)
-- preset de mode livre vs mise en page : le preset du mode gagne sur le profil, l'utilisateur gagne sur le preset
C.AddPreset("raid", "*", { ["units.height"] = 40 })
LY.ApplyPreset("compact", "dps")
EQ("preset de mode > mise en page (profil)", C.Get("units.height"), 40)
C.Set("units.height", 33)
EQ("ecart > preset de mode", C.Get("units.height"), 33)
SUI.Mode.Set("normal", "manual")
EQ("Normal : mise en page", C.Get("units.height"), 22)
C.ResetMode("raid")

SECTION("t_layout : sauvegarde")
LY.ApplyPreset("sides", "tank")
local blob = C.Export()
local okI, name = C.Import(blob, "Copie")
EQ("import", okI, true)
EQ("la mise en page voyage avec le profil", ShikiUIDB.profiles[name].layout, "sides")
C.UseProfile(name)
EQ("rechargee", LY.Current(), "sides")
C.UseProfile("Default")
local hostile = SUI.Serial.Pack({ v = 1, layout = "../../etc", c = {} })
okI, name = C.Import(hostile, "Piege")
EQ("import hostile accepte", okI, true)
EQ("nom de mise en page invalide ignore", ShikiUIDB.profiles[name].layout, nil)
hostile = SUI.Serial.Pack({ v = 1, layout = { 1 }, c = {} })
okI, name = C.Import(hostile, "Piege2")
EQ("type invalide ignore", ShikiUIDB.profiles[name].layout, nil)
ShikiUIDB.profiles.Default.layout = 42
C.SelectProfile("Default")
EQ("sauvegarde corrompue nettoyee", C.cur.layout, nil)
ShikiUIDB.profiles.Default.layout = "inexistante"
C.SelectProfile("Default")
EQ("mise en page inconnue gardee mais sans effet", C.cur.layout, "inexistante")
C.ApplyRole("heal")
C.ResetProfile()
EQ("ResetProfile oublie la mise en page", C.cur.layout, nil)

SECTION("t_layout : commande")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("layout")
CONTAINS("liste", CHATTEXT(), "center")
CONTAINS("aide", CHATTEXT(), "/sui layout")
SlashCmdList["SHIKIUI"]("layout use center")
EQ("use", C.cur.layout, "center")
SlashCmdList["SHIKIUI"]("layout use sides heal")
EQ("use avec role", C.cur.layout, "sides")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("layout use sides pirate")
CONTAINS("role inconnu", CHATTEXT(), "pirate")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("layout use inconnue")
CONTAINS("mise en page inconnue", CHATTEXT(), "inconnue")
SlashCmdList["SHIKIUI"]("layout reset")
EQ("reset : positions", next(C.cur.pos), nil)
EQ("reset : memoire", C.cur.layout, nil)

SECTION("t_layout : panneau")
SlashCmdList["SHIKIUI"]("style pick")
local P = SUI.StylePicker
T("panneau ouvert", P.frame:IsShown())
local btn
for i = 1, 8 do if P.layoutButtons[i]:IsShown() and P.layoutButtons[i].id == "center" then btn = P.layoutButtons[i] end end
T("bouton de la mise en page Centre", btn ~= nil)
EQ("libelle", btn.label:GetText(), "Centre")
btn:Click()
EQ("un clic applique la mise en page", C.cur.layout, "center")
T("bouton marque", btn.selected == true)
EQ("aucune erreur interne", SUI.errCount, errs0)
DONE()
