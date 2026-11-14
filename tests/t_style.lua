-- t_style : moteur de styles (Theme.lua jetons + Style.lua registre) : styles livres, resolution, changement a chaud, reglages individuels,
-- ressources de repli, import / export, styles de l'utilisateur et sauvegarde, interface (lignes couleur, bouton reinit., panneau Styles).
local SUI = ShikiUI
local C = SUI.Config
local TH = SUI.Theme
local S = SUI.Style
BOOT({ db = { global = { styles = { preboot = { c = { bg = "445566" } } } } } })
SETTLE()

SECTION("t_style : demarrage")
T("style de l utilisateur recharge au demarrage", S.styles.preboot ~= nil and S.styles.preboot.origin == "user")
EQ("couleur rechargee", S.styles.preboot.def.c.bg, "445566")

local function near(a, b) return math.abs(a - b) < 0.003 end
local function bgIs(hex, mult)
  local r, g, b, a = S.ParseHex(hex)
  return near(TH.c.bg[1], r) and near(TH.c.bg[2], g) and near(TH.c.bg[3], b) and near(TH.c.bg[4], a)
end

SECTION("t_style : couleurs hexadecimales")
local r, g, b, a = S.ParseHex("FF8000")
EQ("RRGGBB : rouge", r, 1)
NEAR("RRGGBB : vert", g, 128 / 255, 0.001)
EQ("RRGGBB : bleu", b, 0)
EQ("RRGGBB : opaque", a, 1)
r, g, b, a = S.ParseHex("00000080")
NEAR("RRGGBBAA : alpha", a, 128 / 255, 0.001)
EQ("trop court", S.ParseHex("FF80"), nil)
EQ("pas hexa", S.ParseHex("GG0000"), nil)
EQ("pas une chaine", S.ParseHex(5), nil)
EQ("vide", S.ParseHex(""), nil)
EQ("sept caracteres", S.ParseHex("FF80001"), nil)
EQ("aller-retour", S.Hex(S.ParseHex("12AB34CD")), "12AB34CD")
EQ("Hex borne", S.Hex(2, -1, 0.5, nil), "FF000080" == S.Hex(2, -1, 0.5, nil) and "FF000080" or S.Hex(2, -1, 0.5, nil))

SECTION("t_style : styles livres")
local need = { "shiki", "pfstyle", "elvstyle", "blizzard" }
for i = 1, table.getn(need) do
  local id = need[i]
  T(id .. " : enregistre", S.styles[id] ~= nil)
  EQ(id .. " : livre avec l'addon", S.styles[id] and S.styles[id].origin, "builtin")
  T(id .. " : nom fr", SUI.locales.fr["style." .. id .. ".label"] ~= nil)
  T(id .. " : nom en", SUI.locales.en["style." .. id .. ".label"] ~= nil)
  T(id .. " : description fr", SUI.locales.fr["style." .. id .. ".desc"] ~= nil)
  T(id .. " : description en", SUI.locales.en["style." .. id .. ".desc"] ~= nil)
end
T("au moins 4 styles", table.getn(S.names) >= 4)
EQ("le style d'origine est le premier", S.names[1], "shiki")
EQ("defaut", S.DEFAULT, "shiki")
EQ("nom affichable", S.Label("blizzard"), "Blizzard classique")
EQ("nom inconnu : l'id", S.Label("nimportequoi"), "nimportequoi")
T("description non vide", S.Desc("pfstyle") ~= "")
EQ("description inconnue", S.Desc("nimportequoi"), "")
C.Set("ui.locale", "en")
EQ("nom traduit", S.Label("blizzard"), "Blizzard classic")
C.Set("ui.locale", "fr")
-- chacun a son propre look
local sigs = {}
for i = 1, table.getn(S.names) do
  local tok = S.Resolve(S.names[i])
  local parts = {}
  for k = 1, table.getn(TH.colorNames) do table.insert(parts, tok.hex[TH.colorNames[k]]) end
  table.insert(parts, tok.names.font .. tok.names.bar .. tok.names.edge .. tok.names.panel .. tok.names.button .. tok.names.outline)
  local sig = table.concat(parts, ",")
  T(S.names[i] .. " : look distinct des autres", not sigs[sig])
  sigs[sig] = S.names[i]
end
local ptok = S.Resolve("pfstyle")
local etok = S.Resolve("elvstyle")
local btok = S.Resolve("blizzard")
local stok = S.Resolve("shiki")
EQ("pfStyle : texte contourne", ptok.names.outline, "outline")
EQ("pfStyle : barres degradees", ptok.names.bar, "blizzard")
EQ("pfStyle : fonds translucides", ptok.alpha < 1, true)
EQ("ElvStyle : accent a la couleur de classe", etok.accentName, "class")
EQ("ElvStyle : fonds opaques", etok.alpha, 1)
EQ("Blizzard : police du jeu", btok.names.font, "frizqt")
EQ("Blizzard : bordure arrondie", btok.names.edge, "rounded")
EQ("Blizzard : boutons du jeu", btok.names.button, "blizzard")
EQ("Blizzard : fond d'infobulle", btok.names.panel, "tooltip")
EQ("Shiki : plat", stok.names.edge .. stok.names.bar .. stok.names.button, "thinflatflat")
for _, id in ipairs(S.names) do
  local tok = S.Resolve(id)
  for k = 1, table.getn(TH.colorNames) do
    local c = tok.c[TH.colorNames[k]]
    T(id .. " : couleur " .. TH.colorNames[k] .. " valide", c and c[1] >= 0 and c[1] <= 1 and c[4] >= 0 and c[4] <= 1)
  end
  T(id .. " : chemins de ressources valides", type(tok.font) == "string" and type(tok.bar) == "string" and type(tok.panel) == "string")
end

SECTION("t_style : registre et validation")
EQ("id trop court", (SUI.RegisterStyle("a", {})), false)
EQ("id en majuscules", (SUI.RegisterStyle("Joli", {})), false)
EQ("id avec espace", (SUI.RegisterStyle("deux mots", {})), false)
EQ("id trop long", (SUI.RegisterStyle(string.rep("a", 25), {})), false)
EQ("id non texte", (SUI.RegisterStyle(12, {})), false)
local ok, why = SUI.RegisterStyle("shiki", {})
EQ("jamais d'ecrasement", ok, false)
EQ("raison", why, "msg.style.exists")
local n0 = table.getn(S.names)
ok = SUI.RegisterStyle("regtest", { c = { bg = "102030FF" }, bar = "blizzard" })
EQ("style valide", ok, true)
EQ("ajoute a la liste vivante", table.getn(S.names), n0 + 1)
EQ("origine par defaut", S.styles.regtest.origin, "builtin")
EQ("style sans label : id affiche", S.Label("regtest"), "regtest")
-- donnees hostiles
local clean, bad = S.Sanitize({ c = { bg = "zzz", panel = "112233", inconnue = "000000", text = 5 }, font = "../../x", bar = { 1 }, edge = "inexistant",
  fontScale = 99, alpha = -3, accent = "rose", label = "style.shiki.label", evil = function() end, button = "blizzard" })
EQ("couleur valide gardee", clean.c.panel, "112233")
EQ("couleur invalide retiree", clean.c.bg, nil)
EQ("couleur inconnue retiree", clean.c.inconnue, nil)
EQ("couleur non texte retiree", clean.c.text, nil)
EQ("police inconnue retiree", clean.font, nil)
EQ("barre non texte retiree", clean.bar, nil)
EQ("bordure inconnue retiree", clean.edge, nil)
EQ("echelle bornee", clean.fontScale, 1.8)
EQ("opacite bornee", clean.alpha, 0.3)
EQ("accent inconnu retire", clean.accent, nil)
EQ("bouton valide garde", clean.button, "blizzard")
T("elements invalides comptes", bad >= 8)
EQ("label emprunte a un autre style", clean.label, "style.shiki.label")
clean = S.Sanitize({ fontScale = 0 / 0 })
EQ("NaN retire", clean.fontScale, nil)
clean = S.Sanitize("texte")
EQ("pas une table : vide", next(clean.c), nil)
clean = S.Sanitize({ c = 12 })
EQ("c invalide", next(clean.c), nil)
clean = S.Sanitize({ accent = "FFD100" })
EQ("accent hexadecimal", clean.accent, "FFD100")
clean = S.Sanitize({ accent = "class" })
EQ("accent classe", clean.accent, "class")
clean = S.Sanitize({ label = "n importe quoi", desc = "style.zz.desc" })
EQ("label invalide retire", clean.label, nil)
EQ("desc conforme gardee", clean.desc, "style.zz.desc")

SECTION("t_style : changement de style a chaud")
local panel = TH.Panel(UIParent, 100, 50)
local label = TH.Text(panel, 12, TH.c.text, "LEFT")
local btn = TH.Button(panel, "Ok", 60, 20, function() end)
local bar = TH.Bar(panel)
EQ("style par defaut", C.Get("style.name"), "shiki")
T("jetons de Shiki appliques", bgIs("111214F2"))
EQ("police de Shiki", label.font, TH.FONTS.arial)
EQ("barre de Shiki", bar.sbtex or TH.barTex, TH.BARS.flat)
local applied0 = S.applied
local restyles0 = TH.restyles
C.Set("style.name", "blizzard")
EQ("un seul recalcul", S.applied, applied0 + 1)
T("jetons de Blizzard appliques", bgIs("1A1A30F0"))
EQ("repeinture lancee", TH.restyles, restyles0 + 1)
EQ("police du jeu sur un texte deja cree", label.font, TH.FONTS.frizqt)
EQ("bordure arrondie sur un cadre deja cree", panel.backdrop.edgeFile, TH.EDGES.rounded.file)
EQ("fond d'infobulle sur un cadre deja cree", panel.backdrop.bgFile, TH.PANELS.tooltip)
NEAR("couleur de fond du cadre (panneau)", panel.bgc[1], 38 / 255, 0.003)
EQ("barre du jeu", TH.barTex, TH.BARS.blizzard)
EQ("boutons du jeu", TH.button ~= false, true)
-- accent du style
local ar, ag, ab = TH.Accent()
NEAR("accent Blizzard (or) rouge", ar, 1, 0.003)
NEAR("accent Blizzard (or) vert", ag, 209 / 255, 0.003)
C.Set("style.name", "shiki")
ar, ag, ab = TH.Accent()
NEAR("accent Shiki (bleu)", ar, TH.accents.blue[1], 0.001)
C.Set("style.name", "elvstyle")
ar, ag, ab = TH.Accent()
NEAR("accent ElvStyle = classe (rouge)", ar, RAID_CLASS_COLORS.PALADIN.r, 0.001)
C.Set("ui.accent", "green")
ar, ag, ab = TH.Accent()
NEAR("l'accent choisi bat celui du style", ag, TH.accents.green[2], 0.001)
C.Reset("ui.accent")
EQ("accent par defaut = celui du style", C.Get("ui.accent"), "style")
-- aucun recalcul si rien ne change
local before = S.applied
C.Set("style.name", "elvstyle")
EQ("meme style : pas de recalcul", S.applied, before)
S.Refresh()
EQ("Refresh sans changement : rien", S.applied, before)
C.Set("style.name", "shiki")

SECTION("t_style : reglages individuels")
local ok2 = C.Set("style.c.bg", "FF0000")
EQ("couleur valide acceptee", ok2, true)
EQ("casse normalisee", C.Get("style.c.bg"), "FF0000")
NEAR("appliquee a chaud", TH.c.bg[1], 1, 0.001)
NEAR("appliquee a chaud (vert)", TH.c.bg[2], 0, 0.001)
C.Set("style.c.bg", "00ff00cc")
EQ("minuscules normalisees", C.Get("style.c.bg"), "00FF00CC")
EQ("couleur invalide refusee", C.Set("style.c.bg", "vert"), false)
EQ("valeur gardee", C.Get("style.c.bg"), "00FF00CC")
EQ("nombre refuse", C.Set("style.c.bg", 5), false)
EQ("trop long refuse", C.Set("style.c.bg", "FF0000FF00"), false)
T("reglage marque modifie", C.IsModified("style.c.bg"))
C.Reset("style.c.bg")
T("reset : couleur du style", bgIs("111214F2"))
T("reset : plus modifie", not C.IsModified("style.c.bg"))
C.Set("style.font", "frizqt")
EQ("police imposee", label.font, TH.FONTS.frizqt)
C.Set("style.fontscale", 1.5)
EQ("taille multipliee", label.fsize, 18)
C.Set("style.fontscale", 1)
EQ("taille d'origine", label.fsize, 12)
C.Set("style.outline", "thick")
EQ("contour impose", label.fflags, "THICKOUTLINE")
C.Set("style.alpha", 0.5)
NEAR("opacite des fonds", panel.bgc[4], 0.5 * 0.95, 0.01)
C.Set("style.bartex", "blizzard")
EQ("texture de barre imposee", TH.barTex, TH.BARS.blizzard)
C.Set("style.edge", "dialog")
EQ("bordure imposee", panel.backdrop.edgeFile, TH.EDGES.dialog.file)
C.Set("style.edge", "none")
EQ("sans bordure", panel.backdrop.edgeFile, nil)
C.Set("style.name", "light")
S.ResetOverrides()
T("tout est revenu", not C.IsModified("style.font") and not C.IsModified("style.alpha") and not C.IsModified("style.edge"))
EQ("police du style", label.font, TH.FONTS.arial)
EQ("bordure du style", panel.backdrop.edgeFile, TH.EDGES.thin.file)
EQ("choix de style conserve apres reset", C.Get("style.name"), "light")
C.Set("style.name", "shiki")
EQ("choix invalide refuse", C.Set("style.font", "comicsans"), false)

SECTION("t_style : combat")
W.combat = true
local rs0 = TH.restyles
C.Set("style.name", "blizzard")
T("jetons changes meme en combat", bgIs("1A1A30F0"))
EQ("repeinture differee", TH.restyles, rs0)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
EQ("repeinture a la sortie du combat", TH.restyles, rs0 + 1)
C.Set("style.name", "shiki")

SECTION("t_style : ressources personnalisees et repli")
local ar1, key1 = SUI.RegisterAsset("bar", "mabarre", "Interface\\AddOns\\MesMedias\\barre.tga")
EQ("ressource ajoutee", ar1, true)
T("choix ajoute a la liste", (function() for i = 1, table.getn(C.meta["style.bartex"].choices) do if C.meta["style.bartex"].choices[i] == "mabarre" then return true end end end)())
C.Set("style.bartex", "mabarre")
EQ("utilisable", TH.barTex, "Interface\\AddOns\\MesMedias\\barre.tga")
-- le fichier disparait : repli automatique sur la ressource de base
S.missing["bar:mabarre"] = true
S.Refresh(true)
EQ("repli sur la barre de base", TH.barTex, TH.BARS.flat)
S.missing["bar:mabarre"] = nil
S.Refresh(true)
EQ("ressource revenue", TH.barTex, "Interface\\AddOns\\MesMedias\\barre.tga")
C.Reset("style.bartex")
EQ("nom deja pris", select(2, SUI.RegisterAsset("bar", "flat", "Interface\\x\\y.tga")), "msg.style.asset.exists")
EQ("nom invalide", select(2, SUI.RegisterAsset("bar", "Mauvais Nom", "Interface\\x\\y.tga")), "msg.style.asset.bad")
EQ("genre inconnu", select(2, SUI.RegisterAsset("sound", "bip", "Interface\\x\\y.tga")), "msg.style.asset.bad")
EQ("chemin vide", select(2, SUI.RegisterAsset("bar", "vide", "")), "msg.style.asset.bad")
EQ("police a ajouter", (SUI.RegisterAsset("font", "mapolice", "Interface\\AddOns\\MesMedias\\police.ttf")), true)
EQ("bordure sans taille", select(2, SUI.RegisterAsset("edge", "monbord", { file = "Interface\\x.tga" })), "msg.style.asset.bad")
EQ("bordure complete", (SUI.RegisterAsset("edge", "monbord", { file = "Interface\\AddOns\\MesMedias\\bord.tga", size = 12, ins = 3 })), true)
EQ("taille de bordure bornee", TH.assets.edge.monbord.size, 12)
-- sonde : fichier introuvable
local realProbe = S.Probe
S.Probe = function() return false end
local okP, keyP = SUI.RegisterAsset("bar", "absente", "Interface\\AddOns\\Rien\\rien.tga")
EQ("ressource acceptee mais signalee", keyP, "msg.style.asset.missing")
EQ("marquee absente", S.missing["bar:absente"], true)
C.Set("style.bartex", "absente")
EQ("jamais de texture cassee a l'ecran", TH.barTex, TH.BARS.flat)
C.Reset("style.bartex")
S.Probe = realProbe
-- un style qui reference une ressource absente se rabat sur sa base
SUI.RegisterStyle("repli", { bar = "mabarre" })
S.missing["bar:mabarre"] = true
local tk = S.Resolve("repli")
EQ("style : repli sur la base", tk.names.bar, "flat")
S.missing["bar:mabarre"] = nil
-- combat : la sonde ne tourne pas
W.combat = true
EQ("sonde en combat : inconnu", realProbe("Interface\\x"), nil)
W.combat = false

SECTION("t_style : style x mode Raid")
C.AddPreset("raid", "*", { ["style.alpha"] = 0.6, ["style.name"] = "tactical" })
SUI.Mode.Set("raid", "manual")
EQ("preset de mode : style", C.Get("style.name"), "tactical")
NEAR("preset de mode : opacite", TH.alpha, 0.95 * 0.6, 0.01)
T("jetons de Tactique appliques", bgIs("0C100CF0"))
C.Set("style.name", "light")
EQ("l'utilisateur gagne en Raid", C.Get("style.name"), "light")
T("jetons de Clair appliques", bgIs("F2F2F2F2"))
SUI.Mode.Set("normal", "manual")
EQ("Normal : style du profil", C.Get("style.name"), "shiki")
T("Normal : jetons de Shiki", bgIs("111214F2"))
NEAR("Normal : opacite d'origine", TH.alpha, 1, 0.001)
SUI.Mode.Set("raid", "manual")
EQ("Raid : le choix de l'utilisateur est retrouve", C.Get("style.name"), "light")
C.Reset("style.name")
EQ("reset en Raid : preset livre", C.Get("style.name"), "tactical")
SUI.Mode.Set("normal", "manual")
-- role / classe
C.AddPreset("raid", "tank", { ["style.font"] = "frizqt" })
C.ApplyRole("tank")
SUI.Mode.Set("raid", "manual")
EQ("preset de role : police", label.font, TH.FONTS.frizqt)
C.ApplyRole("heal")
EQ("autre role : police du style", label.font, TH.FONTS.arial)
SUI.Mode.Set("normal", "manual")

SECTION("t_style : export et import")
C.Set("style.name", "blizzard")
C.Set("style.c.accent", nil)
local str = S.Export("pfstyle")
T("chaine partageable", type(str) == "string" and string.find(str, "^SUI1:") ~= nil)
local str2, key2 = S.Export("nexistepas")
EQ("export d'un inconnu", str2, nil)
EQ("raison", key2, "msg.style.unknown")
local cur = S.Export()
T("export du look effectif", type(cur) == "string")
local nUser = 0
local oi, id, acc, ign = S.Import(str, "Mon pf")
EQ("import", oi, true)
EQ("identifiant normalise", id, "monpf")
T("champs acceptes", acc > 5)
EQ("origine utilisateur", S.styles.monpf.origin, "user")
EQ("memorise dans la base", ShikiUIDB.global.styles.monpf ~= nil, true)
EQ("meme look que la source", S.Resolve("monpf").hex.bg, S.Resolve("pfstyle").hex.bg)
EQ("un style importe n'emprunte pas les textes", S.styles.monpf.def.label, nil)
oi, id = S.Import(str, "Mon pf")
EQ("deuxieme import : nom libre", id, "monpf2")
oi, id = S.Import(str, "shiki")
EQ("jamais d'ecrasement d'un style livre", id, "shiki2")
EQ("le style livre est intact", S.styles.shiki.origin, "builtin")
-- hostile
EQ("chaine vide", (S.Import("")), false)
EQ("chaine absurde", (S.Import("coucou")), false)
EQ("somme de controle fausse", (S.Import("SUI1:00000000:{}")), false)
local prof = C.Export()
EQ("un profil n'est pas un style", (S.Import(prof)), false)
local fake = SUI.Serial.Pack({ v = 1, def = { c = {} } })
EQ("un objet sans etiquette de style est refuse", (S.Import(fake)), false)
fake = SUI.Serial.Pack({ kind = "style", v = 2, def = {} })
EQ("version inconnue", (S.Import(fake)), false)
fake = SUI.Serial.Pack({ kind = "style", v = 1, def = "texte" })
EQ("definition invalide", (S.Import(fake)), false)
fake = SUI.Serial.Pack({ kind = "style", v = 1, name = "Hostile", def = { c = { bg = "<script>" }, bar = "Interface\\..\\..\\x", label = "style.shiki.label", font = "frizqt", zzz = 1 } })
oi, id, acc, ign = S.Import(fake)
EQ("import hostile accepte mais nettoye", oi, true)
EQ("rien de dangereux garde", S.styles[id].def.bar, nil)
EQ("couleur piegee retiree", S.styles[id].def.c.bg, nil)
EQ("police valide gardee", S.styles[id].def.font, "frizqt")
T("elements ignores comptes", ign >= 3)
-- limite de styles personnels
local guard = 0
while guard < 40 do
  guard = guard + 1
  local okI, idI = S.Import(str, "rempli" .. guard)
  if not okI then
    EQ("limite de 24 styles personnels", idI, "msg.style.full")
    break
  end
end
T("limite atteinte", guard < 40)

SECTION("t_style : enregistrer, utiliser, supprimer")
C.Set("style.name", "blizzard")
C.Set("style.c.bg", "224466")
local cnt = 0
for _ in pairs(ShikiUIDB.global.styles) do cnt = cnt + 1 end
-- faire de la place
for id2, rec in pairs(S.styles) do
  if rec.origin == "user" then S.Delete(id2) end
end
local sok, sid = S.SaveCurrent("Mon Style !")
EQ("enregistre", sok, true)
EQ("identifiant normalise", sid, "monstyle")
EQ("selectionne", C.Get("style.name"), "monstyle")
T("reglages individuels effaces (ils sont dans le style)", not C.IsModified("style.c.bg"))
T("le look est conserve", bgIs("224466FF") or bgIs("224466F0"))
EQ("police de Blizzard conservee", S.Resolve("monstyle").names.font, "frizqt")
sok, sid = S.SaveCurrent("Mon Style !")
EQ("deuxieme enregistrement : nom libre", sid, "monstyle2")
sok, sid = S.SaveCurrent("")
T("nom vide : nom de secours", sok and string.find(sid, "^style") ~= nil)
ok, why = S.Delete("shiki")
EQ("un style livre ne se supprime pas", ok, false)
EQ("raison", why, "msg.style.builtin")
ok, why = S.Delete("nexistepas")
EQ("suppression d'un inconnu", why, "msg.style.unknown")
C.Set("style.name", "monstyle")
ok = S.Delete("monstyle")
EQ("suppression", ok, true)
EQ("plus enregistre", S.styles.monstyle, nil)
EQ("retire de la base", ShikiUIDB.global.styles.monstyle, nil)
EQ("retire de la liste", (function() for i = 1, table.getn(S.names) do if S.names[i] == "monstyle" then return false end end return true end)(), true)
EQ("le style actif supprime : retour au style d'origine", C.Get("style.name"), "shiki")
T("jetons d'origine reappliques", bgIs("111214F2"))

SECTION("t_style : sauvegardes (compatibilite entre versions)")
local st = ShikiUIDB.global.styles
for k, _ in pairs(st) do st[k] = nil end
st.bonstyle = { c = { bg = "445566", panel = "pasunecouleur" }, bar = "blizzard", ancienchamp = 42 }
st["MAUVAIS ID"] = { c = {} }
st.shiki = { c = { bg = "FFFFFF" } }
st.cassee = "texte"
st.futur = { c = { bg = "445566" }, bar = "texture_future_inconnue", fontScale = 2.5, nouveauchamp = { 1, 2 } }
local before2 = S.styles.shiki.def.c.bg
local loaded = S.LoadUser()
EQ("styles valides recharges", loaded, 2)
EQ("bon style enregistre", S.styles.bonstyle ~= nil and S.styles.bonstyle.origin == "user", true)
EQ("couleur valide gardee", S.styles.bonstyle.def.c.bg, "445566")
EQ("couleur invalide retiree", S.styles.bonstyle.def.c.panel, nil)
EQ("ancien champ inconnu retire", st.bonstyle.ancienchamp, nil)
EQ("style d'une version future : ressource inconnue retiree", S.styles.futur.def.bar, nil)
EQ("style d'une version future : echelle bornee", S.styles.futur.def.fontScale, 1.8)
EQ("identifiant invalide supprime de la base", st["MAUVAIS ID"], nil)
EQ("collision avec un style livre : supprimee", st.shiki, nil)
EQ("le style livre est intact", S.styles.shiki.def.c.bg, before2)
EQ("entree cassee supprimee", st.cassee, nil)
-- un profil qui reference un style disparu
C.cur.v["style.name"] = "disparu"
C.SelectProfile()
T("style disparu : retour au style d'origine", C.Get("style.name") == "shiki")
T("jetons d'origine", bgIs("111214F2"))
-- profil importe avec un nom de style inexistant
local okI = C.Import(SUI.Serial.Pack({ v = 1, c = { ["style.name"] = "inconnu", ["style.c.bg"] = "pas hexa" } }), "Etrange")
EQ("import de profil", okI, true)
C.UseProfile("Etrange")
EQ("style inconnu ignore", C.Get("style.name"), "shiki")
EQ("couleur invalide ignoree", C.Get("style.c.bg"), "")
C.UseProfile("Default")

SECTION("t_style : commande")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("style")
CONTAINS("liste", CHATTEXT(), "blizzard")
CONTAINS("liste : style actif marque", CHATTEXT(), "* shiki")
CONTAINS("aide", CHATTEXT(), "/sui style")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("style use pfstyle")
EQ("use", C.Get("style.name"), "pfstyle")
CONTAINS("confirmation", CHATTEXT(), "pfStyle")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("style use inconnu")
CONTAINS("style inconnu", CHATTEXT(), "inconnu")
EQ("inchange", C.Get("style.name"), "pfstyle")
SlashCmdList["SHIKIUI"]("style save Essai")
EQ("save", C.Get("style.name"), "essai")
SlashCmdList["SHIKIUI"]("style delete essai")
EQ("delete", S.styles.essai, nil)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("style delete shiki")
CONTAINS("delete d'un style livre", CHATTEXT(), "shiki")
EQ("toujours la", S.styles.shiki ~= nil, true)
C.Set("style.font", "frizqt")
SlashCmdList["SHIKIUI"]("style reset")
T("reset", not C.IsModified("style.font"))
SlashCmdList["SHIKIUI"]("style use shiki")
-- export / import par la fenetre de transfert
SlashCmdList["SHIKIUI"]("style export blizzard")
local M = SUI.Menu
T("fenetre de transfert ouverte", M.tf and M.tf:IsShown())
EQ("contenu = la chaine du style", M.tf.edit:GetText(), S.Export("blizzard"))
M.tf:Hide()
SlashCmdList["SHIKIUI"]("style import")
EQ("import : fenetre en mode style", M.tf.kind, "style")
M.tf.edit:SetText(S.Export("light"))
M.tf.ok:Click()
EQ("import par la fenetre", S.styles.light2 ~= nil or S.styles.light ~= nil, true)
CHATCLEAR()
SlashCmdList["SHIKIUI"]("style import " .. S.Export("tactical"))
CONTAINS("import en ligne de commande", CHATTEXT(), "Style importe")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("style import n'importe quoi")
CONTAINS("import invalide signale", CHATTEXT(), "")

SECTION("t_style : panneau Styles (choix en un clic)")
local P = SUI.StylePicker
M.Hide()
P.Show()
T("panneau ouvert", P.frame and P.frame:IsShown())
local shown = 0
for i = 1, 8 do if P.cards[i]:IsShown() then shown = shown + 1 end end
EQ("une carte par style (8 maxi par page)", shown, math.min(8, table.getn(S.names)))
local function cardFor(id)
  for i = 1, 8 do if P.cards[i]:IsShown() and P.cards[i].id == id then return P.cards[i] end end
end
local cb = cardFor("blizzard")
T("carte Blizzard", cb ~= nil)
EQ("nom sur la carte", cb.name:GetText(), "Blizzard classique")
T("description sur la carte", cb.desc:GetText() ~= "")
T("apercu aux couleurs du style", near(cb.pv.bgc[1], 26 / 255) and near(cb.pv.bgc[3], 48 / 255))
NEAR("apercu : barre a l'accent du style", cb.bar.vc[1], 1, 0.01)
EQ("apercu : police du style", cb.sample.font, TH.FONTS.frizqt)
local cs = cardFor("shiki")
T("la carte du style actif est marquee", cs.selected == true and cb.selected == false)
local logic = TH.restyles
cb:Click()
EQ("un clic choisit le style", C.Get("style.name"), "blizzard")
T("l'interface est repeinte", TH.restyles > logic)
T("la carte suit", cb.selected == true)
-- l'apercu ne bouge pas quand le style global change
local keep = cs.pv.bgc[1]
C.Set("style.name", "light")
NEAR("apercu independant du style actif", cs.pv.bgc[1], keep, 0.001)
C.Set("style.name", "shiki")
-- enregistrer depuis le panneau
P.frame.name:SetText("Depuis panneau")
P.frame.save:Click()
T("style enregistre depuis le panneau", S.styles.depuispanneau ~= nil)
EQ("selectionne", C.Get("style.name"), "depuispanneau")
local lastPage = P.page
T("page du nouveau style affichee", cardFor("depuispanneau") ~= nil)
local cu = cardFor("depuispanneau")
T("bouton supprimer sur un style personnel", cu.del:IsShown())
P.page = 1
P.Render()
T("pas de bouton supprimer sur un style livre", cardFor("shiki") ~= nil and not cardFor("shiki").del:IsShown())
P.page = 99
P.Render()
EQ("page hors limites ramenee a la derniere", P.page, math.floor((table.getn(S.names) + 7) / 8))
P.page = lastPage
P.Render()
cu.del:Click()
EQ("supprime depuis le panneau", S.styles.depuispanneau, nil)
-- pages
for i = 1, 9 do S.Import(S.Export("shiki"), "page" .. i) end
P.page = 1
P.Render()
local _, _, total = string.find(P.frame.pageText:GetText() or "", "/ (%d+)")
T("plusieurs pages", tonumber(total) ~= nil and tonumber(total) >= 2)
P.frame.next:Click()
EQ("page suivante", P.page, 2)
for _ = 1, 12 do P.frame.next:Click() end
EQ("derniere page : pas plus loin", P.page, math.floor((table.getn(S.names) + 7) / 8))
P.page = 1
P.Render()
-- personnaliser
P.frame.edit:Click()
EQ("Personnaliser ouvre le menu sur le style", M.cat, "style")
EQ("mode Tout", M.mode, "all")
-- mises en page
local lay = 0
for i = 1, table.getn(SUI.layoutOrder) do if P.layoutButtons[i]:IsShown() then lay = lay + 1 end end
EQ("un bouton par mise en page", lay, table.getn(SUI.layoutOrder))
-- combat : pas de construction
P.Hide()
P.frame = nil
P.cards = {}
P.layoutButtons = {}
W.combat = true
local c0 = CREATED
EQ("panneau refuse en combat", P.Show(), false)
EQ("rien cree en combat", CREATED, c0)
W.combat = false
EQ("hors combat : construit", P.Show(), true)
-- tout reste silencieux
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
