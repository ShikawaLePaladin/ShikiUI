-- t_clickheal : module "clickheal" (soins au clic facon Puppeteer sur les cadres de groupe / raid) : contrat, liaisons par classe et par
-- modificateur, rangs, lancement direct / avec echange de cible, dissipation, resurrection automatique, roulette, infobulles, commandes,
-- grimoire en combat, modes, cycle de vie.
local SUI = ShikiUI
local C = SUI.Config
GRP_SETUP()
EXT.unitxp("real")
BOOT()
SETTLE()
local M = SUI.ClickHeal

GRP_SPELLS({ { "Flash of Light", "Rank 1" }, { "Flash of Light", "Rank 2" }, { "Flash of Light", "Rank 3" },
  { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 2" }, { "Cleanse", "" }, { "Purify", "" }, { "Redemption", "Rank 1" },
  { "Blessing of Might", "Rank 1" }, { "Blessing of Protection", "Rank 1" }, { "Blessing of Protection", "Rank 2" },
  { "Blessing of Sacrifice", "Rank 1" } })
GRP_PARTY(2)
W.partyMembers = 2
C.Set("modules.group", true)
SETTLE()
Pump(0.3, 3)
local function pf(i) return SUI.Group.party.frames[i] end
local fr = pf(2)                           -- party1
local function casts() return table.getn(GRP.casts) end
local function lastCast() return GRP.casts[table.getn(GRP.casts)] end
local function reset() GRP.casts = {}; W.acts = {}; GRP.mods = {}; Pump(2.5, 1) end

SECTION("t_clickheal : contrat et options")
local mod = SUI.modules.clickheal
T("module enregistre", mod ~= nil)
EQ("cout declare", mod and mod.cost, "light")
T("coupe par defaut", not mod.enabled)
EQ("categorie 44", SUI.categories.clickheal, 44)
local n = 0
for i = 1, table.getn(mod.options) do n = n + 1 end
EQ("20 liaisons + 8 reglages + 19 rangs", n, 47)
EQ("liaison par defaut : auto", C.Get("clickheal.none.left"), "auto")
EQ("rang par defaut : maximum", C.Get("clickheal.rank.flashoflight"), 0)
T("avant activation : tous les sorts proposes (priretre inclus)", M.choices[8] ~= nil and (function()
  for i = 1, table.getn(M.choices) do if M.choices[i] == "Renew" then return true end end
  return false
end)())
-- sans module : le cadre applique son comportement normal
reset()
Click(fr, "LeftButton")
EQ("module coupe : clic = cibler", LASTACT(), "TargetUnit party1")
EQ("module coupe : aucun sort", casts(), 0)

SECTION("t_clickheal : activation, classe, grimoire")
C.Set("modules.clickheal", true)
EQ("module actif", mod.enabled, true)
EQ("classe du joueur", M.class, "PALADIN")
EQ("sort connu", M.IsKnown("Flash of Light"), true)
EQ("sort inconnu", M.IsKnown("Blessing of Kings"), false)
EQ("rang max lu du grimoire", M.known["Flash of Light"].max, 3)
EQ("texte de rang du grimoire", M.known["Flash of Light"].txt[2], "Rank 2")
local has = {}
for i = 1, table.getn(M.choices) do has[M.choices[i]] = true end
T("choix reduits a la classe", has["Flash of Light"] and has["Redemption"] and not has["Renew"] and has["menu"] and has["auto"])
T("paladin : benedictions de combat proposees", has["Blessing of Protection"] and has["Blessing of Sacrifice"] and has["Blessing of Freedom"])
EQ("liaison par defaut gauche : Flash of Light", M.map[1].spell, "Flash of Light")
EQ("liaison par defaut droite : Holy Light", M.map[2].spell, "Holy Light")
EQ("pas de liaison du milieu : comportement normal", M.map[3].kind, "default")
EQ("Maj+gauche : cibler", M.map[6].kind, "target")
EQ("Maj+droit : menu", M.map[7].kind, "menu")
EQ("Ctrl+droit : dissiper", M.map[12].kind, "dispel")
EQ("pas de roulette par defaut", M.hasWheel, false)
EQ("aucune erreur interne", SUI.errCount, 0)

SECTION("t_clickheal : lancement avec echange de cible (sans SuperWoW)")
reset()
W.units.target = W.units.party2
Click(fr, "LeftButton")
EQ("sort lance", lastCast()[1], "Flash of Light")
EQ("sans SuperWoW : sans unite", lastCast()[2], nil)
EQ("lance sur la bonne cible", lastCast()[3], "Ami1")
EQ("cible d'avant rendue", W.units.target, W.units.party2)
EQ("ordre : cible, sort, retour", W.acts[1] .. "|" .. W.acts[2] .. "|" .. W.acts[3], "TargetUnit party1|Cast Flash of Light nil|TargetLastTarget")
reset()
W.units.target = nil
Click(fr, "LeftButton")
EQ("pas de cible avant : cible effacee ensuite", W.units.target, nil)
EQ("dernier acte : ClearTarget", LASTACT(), "ClearTarget")
reset()
W.units.target = W.units.party1
Click(fr, "LeftButton")
EQ("deja sur la bonne cible : aucun echange", W.acts[1], "Cast Flash of Light nil")
EQ("pas de changement de cible", table.getn(W.acts), 1)
reset()
C.Set("clickheal.retarget", false)
W.units.target = W.units.party2
Click(fr, "LeftButton")
EQ("sans retour de cible : la cible reste", W.units.target, W.units.party1)
C.Set("clickheal.retarget", true)
reset()
W.spellTargeting = true
Click(fr, "LeftButton")
W.spellTargeting = false
T("sort en attente de cible : cible du sort", string.find(table.concat(W.acts, "|"), "SpellTargetUnit party1", 1, true) ~= nil)
reset()
Click(fr, "RightButton")
EQ("clic droit : Holy Light", lastCast()[1], "Holy Light")
Click(fr, "MiddleButton")
EQ("clic milieu sans liaison : rien de lance", casts(), 1)

SECTION("t_clickheal : lancement direct (SuperWoW)")
EXT.superwow(true)
SUI.Api.Detect()
reset()
W.units.target = W.units.party2
Click(fr, "LeftButton")
EQ("direct : sort avec l'unite", W.acts[1], "Cast Flash of Light party1")
EQ("direct : aucun changement de cible", table.getn(W.acts), 1)
EQ("direct : la cible n'a pas bouge", W.units.target, W.units.party2)
C.Set("clickheal.method", "swap")
reset()
Click(fr, "LeftButton")
EQ("methode swap forcee", W.acts[1], "TargetUnit party1")
C.Set("clickheal.method", "auto")
EXT.superwow(false)
SUI.Api.Detect()
C.Set("clickheal.method", "direct")
reset()
Click(fr, "LeftButton")
EQ("direct sans SuperWoW : repli sur l'echange", W.acts[1], "TargetUnit party1")
C.Set("clickheal.method", "auto")

SECTION("t_clickheal : grimoire FR (client frFR d'OctoWow)")
-- le grimoire renvoie maintenant des noms FR : ils sont rattaches aux cles EN, et l'incantation
-- utilise le NOM REEL du grimoire
C.Set("modules.clickheal", true)
SETTLE()
GRP_SPELLS({ { "Éclair lumineux", "Rang 1" }, { "Éclair lumineux", "Rang 2" }, { "Éclair lumineux", "Rang 3" },
  { "Lumière sacrée", "Rang 1" }, { "Lumière sacrée", "Rang 2" }, { "Purification", "" }, { "Bénédiction des Rois", "Rang 1" },
  { "Horion sacré", "Rang 1" }, { "Horion sacré", "Rang 2" } })
Fire("SPELLS_CHANGED")
SETTLE()
T("FR : Flash of Light connu via le nom du grimoire", M.IsKnown("Flash of Light"))
T("FR : Holy Light connue", M.IsKnown("Holy Light"))
T("FR : Purification connue", M.IsKnown("Cleanse"))
T("FR : Holy Shock connu", M.IsKnown("Holy Shock"))
T("FR : Rois connu", M.IsKnown("Blessing of Kings"))
EQ("FR : rang max lu du grimoire FR", M.known["Flash of Light"].max, 3)
EQ("FR : texte de rang du grimoire", M.known["Flash of Light"].txt[2], "Rang 2")
EQ("FR : rang max Lumiere sacree", M.known["Holy Light"].max, 2)
reset()
C.Set("clickheal.rank.flashoflight", 2)
Click(fr, "LeftButton")
EQ("FR : incantation avec le NOM REEL du grimoire", lastCast()[1], "Éclair lumineux(Rang 2)")
EQ("FR : la cle de l'option reste EN", M.map[1].spell, "Flash of Light")
reset()
Click(fr, "RightButton")
EQ("FR : Holy Light rang max au nom seul", lastCast()[1], "Lumière sacrée")
-- un sort FR absent de la table reste utilise tel quel (sort non soigneur du grimoire)
T("FR : sort hors table conserve", M.CastString("Banque") == "Banque" or M.IsKnown("Banque") == false)
EQ("aucune erreur interne", SUI.errCount, 0)
-- retour au grimoire EN pour la suite de la suite
GRP_SPELLS({ { "Flash of Light", "Rank 1" }, { "Flash of Light", "Rank 2" }, { "Flash of Light", "Rank 3" },
  { "Holy Light", "Rank 1" }, { "Holy Light", "Rank 2" }, { "Cleanse", "" }, { "Purify", "" }, { "Redemption", "Rank 1" },
  { "Blessing of Might", "Rank 1" }, { "Blessing of Protection", "Rank 1" }, { "Blessing of Protection", "Rank 2" },
  { "Blessing of Sacrifice", "Rank 1" } })
Fire("SPELLS_CHANGED")
SETTLE()
EQ("grimoire EN restaure", M.known["Flash of Light"].bookName, "Flash of Light")

SECTION("t_clickheal : rangs")
reset()
C.Set("clickheal.rank.flashoflight", 2)
Click(fr, "LeftButton")
EQ("rang 2 : texte du grimoire", lastCast()[1], "Flash of Light(Rank 2)")
C.Set("clickheal.rank.flashoflight", 9)
Click(fr, "LeftButton")
EQ("rang 9 inconnu : le plus haut connu en dessous", lastCast()[1], "Flash of Light(Rank 3)")
C.Set("clickheal.rank.flashoflight", 0)
Click(fr, "LeftButton")
EQ("rang 0 : le nom seul (rang max)", lastCast()[1], "Flash of Light")
C.Set("clickheal.rank.holylight", 1)
Click(fr, "RightButton")
EQ("rang d'un autre sort", lastCast()[1], "Holy Light(Rank 1)")
C.Set("clickheal.rank.holylight", 0)
C.Set("clickheal.none.middle", "Blessing of Protection")
C.Set("clickheal.rank.blessingofprotection", 1)
Click(fr, "MiddleButton")
EQ("rang d'une benediction de combat", lastCast()[1], "Blessing of Protection(Rank 1)")
C.Set("clickheal.rank.blessingofprotection", 0)
Click(fr, "MiddleButton")
EQ("rang max de la benediction : le nom seul", lastCast()[1], "Blessing of Protection")
C.Set("clickheal.none.middle", "none")
EQ("CastString d'un sort inconnu : nom seul", M.CastString("Fireball"), "Fireball")

SECTION("t_clickheal : modificateurs")
reset()
GRP.mods.shift = true
Click(fr, "LeftButton")
EQ("Maj+gauche : cible seulement", LASTACT(), "TargetUnit party1")
EQ("aucun sort", casts(), 0)
GRP.mods = {}
reset()
GRP.mods.shift = true
Click(fr, "RightButton")
EQ("Maj+droit : menu (cible puis menu)", W.acts[1], "TargetUnit party1")
casts()
GRP.mods = {}
GRP.mods.ctrl = true
GRP.mods.shift = true
reset()
GRP.mods.ctrl = true
GRP.mods.shift = true
Click(fr, "LeftButton")
EQ("priorite : Maj avant Ctrl", LASTACT(), "TargetUnit party1")
GRP.mods = {}
GRP.mods.alt = true
W.acts = {}
Click(fr, "LeftButton")
EQ("Alt+gauche : liaison de depart de la classe = normal", LASTACT(), "TargetUnit party1")
GRP.mods = {}

SECTION("t_clickheal : dissipation")
reset()
GRP.mods.ctrl = true
W.units.party1.debuffs = { { "Interface\\Icons\\x", 1, "Magic" } }
Click(fr, "RightButton")
EQ("Magic : Cleanse", lastCast()[1], "Cleanse")
GRP_SPELLS({ { "Purify", "" }, { "Flash of Light", "Rank 1" }, { "Holy Light", "Rank 1" }, { "Redemption", "Rank 1" } })
Fire("SPELLS_CHANGED")
GRP.casts = {}
Click(fr, "RightButton")
EQ("Magic sans Cleanse : repli sur le premier sort connu", lastCast()[1], "Purify")
W.units.party1.debuffs = { { "Interface\\Icons\\x", 1, "Poison" } }
Click(fr, "RightButton")
EQ("Poison : Purify", lastCast()[1], "Purify")
GRP_SPELLS({ { "Flash of Light", "Rank 1" }, { "Holy Light", "Rank 1" }, { "Redemption", "Rank 1" } })
Fire("SPELLS_CHANGED")
GRP.casts = {}
CHATCLEAR()
Click(fr, "RightButton")
EQ("aucun sort de dissipation : rien de lance", casts(), 0)
CONTAINS("message explicatif", CHATTEXT(), SUI.L("msg.clickheal.nocure"))
EQ("rien a dissiper : le clic cible quand meme", LASTACT(), "TargetUnit party1")
GRP.mods = {}
W.units.party1.debuffs = {}

SECTION("t_clickheal : resurrection automatique, sort inconnu")
reset()
W.units.party1.dead = true
Click(fr, "LeftButton")
EQ("allie mort : resurrection de la classe", lastCast()[1], "Redemption")
C.Set("clickheal.autores", false)
Click(fr, "LeftButton")
EQ("autores coupe : le sort lie", lastCast()[1], "Flash of Light")
C.Set("clickheal.autores", true)
W.units.party1.dead = nil
reset()
SlashCmdList["SHIKIUI"]("clickheal set alt left Blessing of Kings")
EQ("liaison par commande", C.Get("clickheal.alt.left"), "Blessing of Kings")
GRP.mods.alt = true
CHATCLEAR()
Click(fr, "LeftButton")
EQ("sort inconnu du grimoire : rien de lance", casts(), 0)
CONTAINS("sort inconnu signale", CHATTEXT(), SUI.L("msg.clickheal.unknown", "Blessing of Kings"))
EQ("sort inconnu : le clic cible quand meme (jamais avale)", LASTACT(), "TargetUnit party1")
GRP.mods = {}
SlashCmdList["SHIKIUI"]("clickheal set ctrl left res")
reset()
GRP.mods.ctrl = true
W.units.party1.dead = true
Click(fr, "LeftButton")
EQ("jeton res : resurrection", lastCast()[1], "Redemption")
W.units.party1.dead = nil
SlashCmdList["SHIKIUI"]("clickheal set ctrl left none")
casts()
GRP.casts = {}
Click(fr, "LeftButton")
EQ("jeton none : ne fait rien", casts(), 0)
GRP.mods = {}
SlashCmdList["SHIKIUI"]("clickheal reset")
EQ("remise a zero", C.Get("clickheal.alt.left"), "auto")

SECTION("t_clickheal : roulette")
reset()
EQ("pas de roulette : EnableMouseWheel(false)", fr.calls.EnableMouseWheel[1], false)
C.Set("clickheal.none.up", "Holy Light")
EQ("liaison de roulette : hasWheel", M.hasWheel, true)
EQ("roulette activee sur les cadres", fr.calls.EnableMouseWheel[1], true)
this = fr
arg1 = 1
fr.scripts.OnMouseWheel()
EQ("roulette haut : Holy Light", lastCast()[1], "Holy Light")
GRP.casts = {}
arg1 = -1
fr.scripts.OnMouseWheel()
EQ("roulette bas non liee : rien", casts(), 0)
C.Set("clickheal.none.up", "auto")
EQ("liaison retiree : hasWheel", M.hasWheel, false)
EQ("roulette coupee", fr.calls.EnableMouseWheel[1], false)

SECTION("t_clickheal : infobulle d'aide")
W.units.party1.hidden = nil
Hover(fr, true)
local lines = GameTooltip.lines or {}
local joined = table.concat(lines, "|")
T("aide : clic gauche", string.find(joined, "Flash of Light", 1, true) ~= nil)
T("aide : clic droit", string.find(joined, "Holy Light", 1, true) ~= nil)
Hover(fr, false)
C.Set("clickheal.hints", false)
Hover(fr, true)
EQ("aide coupee : aucune ligne ajoutee", table.getn(GameTooltip.lines or {}), 0)
Hover(fr, false)
C.Set("clickheal.hints", true)

SECTION("t_clickheal : commandes")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("clickheal")
CONTAINS("etat", CHATTEXT(), "PALADIN")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("clickheal list")
CONTAINS("liste : Flash of Light", CHATTEXT(), "Flash of Light")
SlashCmdList["SHIKIUI"]("clickheal set none left Holy Light")
EQ("set : valeur enregistree", C.Get("clickheal.none.left"), "Holy Light")
reset()
Click(fr, "LeftButton")
EQ("la liaison change tout de suite", lastCast()[1], "Holy Light")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("clickheal set none left Fireball")
CONTAINS("action refusee", CHATTEXT(), SUI.L("msg.clickheal.badaction", "Fireball"))
EQ("valeur inchangee", C.Get("clickheal.none.left"), "Holy Light")
CHATCLEAR()
SlashCmdList["SHIKIUI"]("clickheal set nowhere left target")
CONTAINS("usage", CHATTEXT(), SUI.L("msg.clickheal.usage"))
SlashCmdList["SHIKIUI"]("clickheal reset")
EQ("remise a zero", C.Get("clickheal.none.left"), "auto")
GRP_SPELLS({ { "Flash of Light", "Rank 1" }, { "Holy Light", "Rank 1" }, { "Redemption", "Rank 1" }, { "Blessing of Kings", "" } })
CHATCLEAR()
SlashCmdList["SHIKIUI"]("clickheal scan")
EQ("scan : nouveau sort connu", M.IsKnown("Blessing of Kings"), true)
EQ("scan : ancien sort oublie", M.IsKnown("Cleanse"), false)

SECTION("t_clickheal : grimoire en combat, modes")
W.combat = true
GRP_SPELLS({ { "Flash of Light", "Rank 1" } })
Fire("SPELLS_CHANGED")
EQ("combat : relecture differee", M.bookPending, true)
EQ("combat : liste inchangee", M.IsKnown("Holy Light"), true)
W.combat = false
Fire("PLAYER_REGEN_ENABLED")
EQ("apres le combat : relu", M.IsKnown("Holy Light"), false)
EQ("plus de relecture en attente", M.bookPending, false)
GRP_SPELLS({ { "Flash of Light", "Rank 1" }, { "Holy Light", "Rank 1" }, { "Redemption", "Rank 1" } })
Fire("SPELLS_CHANGED")
SUI.Mode.Set("raid", "manual")
EQ("mode Raid : pas d'aide dans les infobulles", C.Get("clickheal.hints"), false)
SUI.Mode.Set("normal", "manual")
EQ("mode Normal : aide rendue", C.Get("clickheal.hints"), true)

SECTION("t_clickheal : cadres de raid")
GRP_RAID(10)
W.units.raid2.name = "Raider2"
C.Set("modules.raid", true)
SETTLE()
Pump(0.3, 3)
local rf = SUI.Raid.g.frames[2]
reset()
Click(rf, "LeftButton")
EQ("raid : sort sur l'unite du cadre", W.acts[1], "TargetUnit raid2")
EQ("raid : sort lance", lastCast()[1], "Flash of Light")
C.Set("modules.raid", false)

SECTION("t_clickheal : desactivation")
C.Set("modules.clickheal", false)
EQ("module coupe", mod.enabled, false)
EQ("plus de roulette", M.hasWheel, false)
local hasRenew = false
for i = 1, table.getn(M.choices) do if M.choices[i] == "Renew" then hasRenew = true end end
EQ("liste des sorts rouverte a toutes les classes", hasRenew, true)
T("module coupe : une resurrection reste une valeur valide", (SUI.Config.Validate("clickheal.none.left", "Resurrection")))
T("module coupe : la resurrection du paladin aussi", (SUI.Config.Validate("clickheal.shift.right", "Redemption")))
GRP_SPELLS({ { "Cleanse", "" } })
Fire("SPELLS_CHANGED")
EQ("desactive : grimoire plus relu", M.IsKnown("Holy Light"), true)
reset()
Click(fr, "LeftButton")
EQ("module coupe : clic normal", LASTACT(), "TargetUnit party1")
EQ("module coupe : aucun sort", casts(), 0)
EQ("aucune erreur interne", SUI.errCount, 0)
DONE()
