-- Locale_Guide : textes du module "guide" (francais sans accents, anglais). Un fichier par module ; tout reste dans l'espace
-- de noms du module : opt.guide.* tip.guide.* choice.guide.* msg.guide.* mod.guide.* help.guide cat.guide
-- plus les deux cles obligatoires opt.modules.guide et tip.modules.guide (le bouton d'activation du module).
-- Une entree par ligne : ["cle"] = "texte", (le controle des traductions lit ces lignes). Memes cles et memes %s / %d dans les deux langues.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.guide"] = "Guide de quetes",
	["opt.modules.guide"] = "Guide de quetes",
	["tip.modules.guide"] = "Propose les quetes a faire pour ton niveau, ta classe et ta zone (/sui guide). Un clic epingle la quete et lance la fleche.",
	["opt.guide.learn"] = "Retenir les quetes rendues",
	["tip.guide.learn"] = "Le jeu ne dit pas quelles quetes sont finies : le guide note celles que tu rends pour proposer leur suite et ne plus reproposer les quetes faites.",
	["msg.guide.title"] = "Quetes pour toi (niveau %d)",
	["msg.guide.sub"] = "%s - %d quete(s) trouvee(s). Clic : epingler + fleche.",
	["msg.guide.sub.nozone"] = "Zone inconnue : suites de chaines seulement.",
	["msg.guide.chain"] = "suite : ",
	["msg.guide.none"] = "Rien a proposer ici pour l'instant. Change de zone ou rends une quete pour voir sa suite.",
	["msg.guide.nodata"] = "Donnees de quetes absentes : installe ShikiCodexData_Quests.",
	["msg.guide.nocodex"] = "Active le module Codex pour utiliser le guide.",
	["msg.guide.off"] = "Le guide de quetes est coupe (menu /sui, modules).",
	["msg.guide.tip.lvl"] = "Niveau %d, a partir du niveau %d",
	["msg.guide.tip.npc"] = "Donnee par : %s",
	["msg.guide.tip.chain"] = "Suite d'une quete que tu as rendue.",
	["msg.guide.tip.zone"] = "Quete de depart dans ta zone, sans prerequis.",
	["msg.guide.tip.click"] = "Clic : epingler sur la carte et suivre avec la fleche",
	["help.guide"] = "/sui guide - quetes conseillees pour ton niveau et ta zone",
})

SUI.AddStrings("en", {
	["cat.guide"] = "Quest guide",
	["opt.modules.guide"] = "Quest guide",
	["tip.modules.guide"] = "Suggests quests to do for your level, class and zone (/sui guide). A click pins the quest and starts the arrow.",
	["opt.guide.learn"] = "Remember turned-in quests",
	["tip.guide.learn"] = "The game does not tell which quests are done: the guide notes the ones you turn in to suggest their follow-ups and stop suggesting finished quests.",
	["msg.guide.title"] = "Quests for you (level %d)",
	["msg.guide.sub"] = "%s - %d quest(s) found. Click: pin + arrow.",
	["msg.guide.sub.nozone"] = "Unknown zone: quest chain follow-ups only.",
	["msg.guide.chain"] = "next: ",
	["msg.guide.none"] = "Nothing to suggest here right now. Change zone, or turn in a quest to see its follow-up.",
	["msg.guide.nodata"] = "Quest data missing: install ShikiCodexData_Quests.",
	["msg.guide.nocodex"] = "Enable the Codex module to use the guide.",
	["msg.guide.off"] = "The quest guide is off (/sui menu, modules).",
	["msg.guide.tip.lvl"] = "Level %d, from level %d",
	["msg.guide.tip.npc"] = "Given by: %s",
	["msg.guide.tip.chain"] = "Follow-up of a quest you turned in.",
	["msg.guide.tip.zone"] = "Starting quest in your zone, no prerequisite.",
	["msg.guide.tip.click"] = "Click: pin on the map and follow with the arrow",
	["help.guide"] = "/sui guide - recommended quests for your level and zone",
})
