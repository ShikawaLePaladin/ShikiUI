-- t_clickheal_book : module "clickheal", cote grimoire : bouton "Soins au clic" sur SpellBookFrame (position, niveau recale, aspects, clics),
-- sorts lies surlignes (SpellButton1..12), infobulle des gestes, livre du familier, enveloppe de SpellBookFrame_Update, combat, cycle de vie.
local SUI = ShikiUI
local C = SUI.Config
local L = SUI.L
GRP_SETUP()
EXT.unitxp("real")
GameTooltip = GameTooltip or CreateFrame("GameTooltip", "GameTooltip", UIParent)
-- faux grimoire de Blizzard : cadre, 12 boutons, decalage de page, mise a jour
local SB = { offset = 0, updates = 0 }
local book = CreateFrame("Frame", "SpellBookFrame", UIParent)
book.bookType = "spell"
book:SetFrameLevel(5)
book:Hide()
for i = 1, 12 do
  local b = CreateFrame("Button", "SpellButton" .. i, book)
  b.sid = i
  b.GetID = function(self) return self.sid end
end
rawset(_G, "SpellBook_GetSpellID", function(id) return id + SB.offset end)
local origUpdate = function() SB.updates = SB.updates + 1 end
rawset(_G, "SpellBookFrame_Update", origUpdate)
local blizzEnter = 0
for i = 1, 12 do
  getglobal("SpellButton" .. i):SetScript("OnEnter", function() blizzEnter = blizzEnter + 1; GameTooltip:SetOwner(this, "ANCHOR_RIGHT") end)
end
BOOT()
SETTLE()
local M = SUI.ClickHeal
GRP_SPELLS({ { "Flash of Light", "Rank 1" }, { "Flash of Light", "Rank 2" }, { "Flash of Light", "Rank 3" },
  { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 2" }, { "Cleanse", "" }, { "Purify", "" }, { "Redemption", "Rank 1" },
  { "Blessing of Might", "Rank 1" } })
local function btn(i) return getglobal("SpellButton" .. i) end
local function marked(i) return btn(i).healMark ~= nil and btn(i).healMark:IsShown() end
local function tipText() return table.concat(GameTooltip.lines or {}, "\n") end
local function fireShow(f)
  this = f
  if f.scripts.OnShow then f.scripts.OnShow() end
end
local function update() getglobal("SpellBookFrame_Update")() end

SECTION("t_clickheal_book : options et module coupe")
for _, k in ipairs({ "clickheal.btn", "clickheal.mark", "clickheal.btnpos", "clickheal.btnstyle" }) do
  T("option declaree : " .. k, C.meta[k] ~= nil)
end
EQ("bouton actif par defaut", C.Get("clickheal.btn"), true)
EQ("surlignage actif par defaut", C.Get("clickheal.mark"), true)
EQ("place par defaut : haut", C.Get("clickheal.btnpos"), "top")
EQ("aspect par defaut : texte", C.Get("clickheal.btnstyle"), "label")
EQ("module coupe : pas de bouton", M.bbtn, nil)
EQ("module coupe : grimoire de Blizzard intact", getglobal("SpellBookFrame_Update"), origUpdate)
EQ("module coupe : pas de bandeau", btn(1).healMark, nil)

SECTION("t_clickheal_book : activation")
C.Set("modules.clickheal", true)
SETTLE()
EQ("module actif", SUI.modules.clickheal.enabled, true)
T("bouton cree", M.bbtn ~= nil)
EQ("enfant du grimoire", M.bbtn.parent, book)
EQ("ancre au cadre Blizzard", M.bbtn.points[1][2], book)
EQ("place par defaut : haut", M.bbtn.points[1][1], "TOPRIGHT")
EQ("invisible tant que le grimoire est ferme", M.bbtn:IsVisible(), false)
book:Show()
fireShow(M.bbtn)
EQ("visible avec le grimoire", M.bbtn:IsVisible(), true)
EQ("libelle", M.bbtn.label:GetText(), L("mod.clickheal.btn.label"))
EQ("niveau recale a l'affichage", M.bbtn:GetFrameLevel(), 13)
book:SetFrameLevel(30)
Hover(M.bbtn, true)
EQ("niveau recale au survol (le client le change apres coup)", M.bbtn:GetFrameLevel(), 38)
CONTAINS("infobulle : titre", tipText(), L("mod.clickheal.btn.tiptitle"))
CONTAINS("infobulle : nombre de liaisons et classe", tipText(), L("mod.clickheal.btn.state", M.CountBinds(), "PALADIN"))
CONTAINS("infobulle : surlignage", tipText(), L("mod.clickheal.btn.markon"))
CONTAINS("infobulle : aide", tipText(), L("mod.clickheal.btn.tipbody"))
Hover(M.bbtn, false)
T("liaisons de depart comptees", M.CountBinds() >= 4)
EQ("enveloppe posee sur la mise a jour de Blizzard", getglobal("SpellBookFrame_Update") == origUpdate, false)
EQ("accent : surlignage actif", M.bbtn.selected, true)

SECTION("t_clickheal_book : aspects et places")
C.Set("clickheal.btnstyle", "count")
EQ("aspect avec le nombre", M.bbtn.label:GetText(), L("mod.clickheal.btn.count", M.CountBinds()))
EQ("largeur avec le nombre", M.bbtn:GetWidth(), M.BOOKW.count)
C.Set("clickheal.btnstyle", "compact")
EQ("aspect compact", M.bbtn.label:GetText(), L("mod.clickheal.btn.compact"))
EQ("largeur compacte", M.bbtn:GetWidth(), M.BOOKW.compact)
C.Set("clickheal.btnstyle", "label")
EQ("retour au texte", M.bbtn.label:GetText(), L("mod.clickheal.btn.label"))
C.Set("clickheal.btnpos", "bottom")
EQ("place bas", M.bbtn.points[1][1], "BOTTOMLEFT")
C.Set("clickheal.btnpos", "side")
EQ("place cote", M.bbtn.points[1][1], "TOPLEFT")
C.Set("clickheal.btnpos", "top")
EQ("place haut", M.bbtn.points[1][1], "TOPRIGHT")
C.Set("clickheal.shift.left", "none")
C.Set("clickheal.btnstyle", "count")
EQ("le nombre suit les liaisons", M.bbtn.label:GetText(), L("mod.clickheal.btn.count", M.CountBinds()))
C.Reset("clickheal.shift.left")
C.Set("clickheal.btnstyle", "label")

SECTION("t_clickheal_book : sorts surlignes dans le grimoire")
update()
EQ("la mise a jour de Blizzard est bien appelee", SB.updates >= 1, true)
EQ("Flash of Light (liaison clic gauche) surligne", marked(1), true)
EQ("autre rang du meme sort surligne", marked(3), true)
EQ("Holy Light (clic droit) surligne", marked(4), true)
EQ("Cleanse (dissipation en Ctrl + clic droit) surligne", marked(6), true)
EQ("Purify (dissipation) surligne", marked(7), true)
EQ("Redemption sans liaison : pas de bandeau", marked(8), false)
EQ("Blessing of Might sans liaison : pas de bandeau", marked(9), false)
EQ("case vide : pas de bandeau", marked(10), false)
EQ("bandeau pose sous l'icone (ancres)", btn(1).healMark.points[1][1], "BOTTOMLEFT")
T("bandeau colore par le jeton d'accent", btn(1).healMark.vc ~= nil)
-- page suivante du grimoire
SB.offset = 5
update()
EQ("page suivante : bouton 1 = Cleanse (indice 6)", marked(1), true)
EQ("page suivante : bouton 3 = Redemption", marked(3), false)
EQ("page suivante : bouton 5 = case vide", marked(5), false)
SB.offset = 0
update()
-- liaison changee : le bandeau suit
C.Set("clickheal.shift.left", "Redemption")
EQ("liaison Redemption : surlignee sans rouvrir le grimoire", marked(8), true)
C.Set("clickheal.shift.left", "auto")
EQ("liaison retiree : bandeau efface", marked(8), false)
-- surlignage coupe
C.Set("clickheal.mark", false)
EQ("surlignage coupe : plus de bandeau", marked(1), false)
EQ("surlignage coupe : plus d'accent", M.bbtn.selected, false)
update()
EQ("surlignage coupe : reste coupe apres la mise a jour", marked(4), false)
C.Set("clickheal.mark", true)
EQ("surlignage rallume", marked(1), true)
-- livre du familier
book.bookType = "pet"
update()
EQ("livre du familier : aucun bandeau", marked(1), false)
book.bookType = "spell"
update()
EQ("livre des sorts : bandeaux de retour", marked(1), true)

SECTION("t_clickheal_book : infobulle des sorts du grimoire")
GameTooltip.lines = nil
blizzEnter = 0
Hover(btn(1), true)
EQ("l'infobulle de Blizzard est conservee", blizzEnter, 1)
CONTAINS("gestes ajoutes : titre", tipText(), L("mod.clickheal.book.tip"))
CONTAINS("gestes ajoutes : geste", tipText(), L("choice.clickheal.btn.left"))
Hover(btn(1), false)
GameTooltip.lines = nil
Hover(btn(6), true)
CONTAINS("dissipation : geste avec modificateur", tipText(), L("mod.clickheal.mod.ctrl") .. L("choice.clickheal.btn.right"))
Hover(btn(6), false)
GameTooltip.lines = nil
Hover(btn(8), true)
EQ("sort sans liaison : rien d'ajoute", string.find(tipText(), L("mod.clickheal.book.tip"), 1, true), nil)
Hover(btn(8), false)
EQ("une seule enveloppe d'infobulle par bouton", btn(1).healTip, true)
update()
GameTooltip.lines = nil
blizzEnter = 0
Hover(btn(1), true)
EQ("apres une mise a jour : toujours un seul appel Blizzard", blizzEnter, 1)
Hover(btn(1), false)

SECTION("t_clickheal_book : clics sur le bouton")
local shown
local realShow = SUI.Menu.Show
SUI.Menu.Show = function(cat) shown = cat end
Click(M.bbtn, "LeftButton")
EQ("clic : ouvre la page du module", shown, "clickheal")
SUI.Menu.Show = realShow
Click(M.bbtn, "RightButton")
EQ("clic droit : surlignage coupe", C.Get("clickheal.mark"), false)
EQ("clic droit : bandeaux effaces", marked(1), false)
Click(M.bbtn, "RightButton")
EQ("2e clic droit : surlignage rallume", C.Get("clickheal.mark"), true)
EQ("2e clic droit : bandeaux de retour", marked(1), true)

SECTION("t_clickheal_book : combat")
W.combat = true
local n0 = CREATED
btn(12).healMark = nil
GRP_SPELLS({ { "Flash of Light", "Rank 1" }, { "Flash of Light", "Rank 2" }, { "Flash of Light", "Rank 3" },
  { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 2" }, { "Cleanse", "" }, { "Purify", "" }, { "Redemption", "Rank 1" },
  { "Blessing of Might", "Rank 1" }, { "x", "" }, { "x", "" }, { "Flash of Light", "Rank 4" } })
update()
EQ("en combat : aucun bandeau cree", btn(12).healMark, nil)
EQ("en combat : rien cree du tout", CREATED, n0)
EQ("en combat : reprise demandee", M.markPending, true)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
EQ("fin du combat : bandeau pose", marked(12), true)
EQ("fin du combat : plus de reprise en attente", M.markPending, false)

SECTION("t_clickheal_book : erreur interne jamais visible dans le grimoire")
local realGN = GetSpellName
local up0 = SB.updates
rawset(_G, "GetSpellName", function() error("boum") end)
update()
EQ("la mise a jour de Blizzard est passee", SB.updates, up0 + 1)
T("erreur comptee, pas propagee", (M.markErr or 0) >= 1)
rawset(_G, "GetSpellName", realGN)
update()
EQ("retour a la normale", marked(1), true)

SECTION("t_clickheal_book : cycle de vie")
C.Set("clickheal.btn", false)
EQ("bouton coupe : cache", M.bbtn:IsShown(), false)
C.Set("clickheal.btn", true)
EQ("bouton reactive", M.bbtn:IsShown(), true)
C.Set("modules.clickheal", false)
SETTLE()
EQ("module coupe : bouton cache", M.bbtn:IsShown(), false)
EQ("module coupe : bandeaux effaces", marked(1), false)
EQ("module coupe : fonction de Blizzard rendue", getglobal("SpellBookFrame_Update"), origUpdate)
up0 = SB.updates
update()
EQ("module coupe : mise a jour de Blizzard normale", SB.updates, up0 + 1)
EQ("module coupe : toujours pas de bandeau", marked(1), false)
GameTooltip.lines = nil
Hover(btn(1), true)
EQ("module coupe : pas de ligne ajoutee a l'infobulle", string.find(tipText(), L("mod.clickheal.book.tip"), 1, true), nil)
Hover(btn(1), false)
C.Set("modules.clickheal", true)
SETTLE()
EQ("module rallume : enveloppe reposee", getglobal("SpellBookFrame_Update") == origUpdate, false)
EQ("module rallume : bouton revenu", M.bbtn:IsShown(), true)
update()
EQ("module rallume : bandeaux de retour", marked(1), true)
-- pas de grimoire de Blizzard : aucune erreur
EQ("aucune erreur interne", SUI.errCount, 0)

DONE()
