-- Locale_Crafts : textes du module "crafts" (francais sans accents, anglais). Un fichier par module ; tout reste dans l'espace
-- de noms du module. Une entree par ligne : ["cle"] = "texte". Memes cles et memes %s / %d dans les deux langues.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.crafts"] = "Metiers",
	["opt.modules.crafts"] = "Memoire des metiers",
	["tip.modules.crafts"] = "Retient les recettes de tes personnages (ouvre une fois chaque fenetre de metier) et les signale dans les infobulles (/sui crafts).",
	["opt.crafts.tip"] = "Qui connait la recette",
	["tip.crafts.tip"] = "Sur un objet recette : les personnages qui la connaissent et ceux qui ont le metier sans la connaitre.",
	["msg.crafts.known"] = "Connue par : %s",
	["msg.crafts.missing"] = "Pas connue par : %s",
	["msg.crafts.skill"] = "%s %d (%d recettes)",
	["msg.crafts.none"] = "Aucun metier retenu : ouvre une fois la fenetre de metier de chaque personnage.",
	["msg.crafts.forgot"] = "Metiers de %s oublies.",
	["msg.crafts.nochar"] = "Aucun personnage nomme %s dans la memoire des metiers.",
	["help.crafts"] = "/sui crafts [forget <nom>] - metiers retenus par personnage",
})

SUI.AddStrings("en", {
	["cat.crafts"] = "Professions",
	["opt.modules.crafts"] = "Profession memory",
	["tip.modules.crafts"] = "Remembers your characters' recipes (open each profession window once) and shows them in tooltips (/sui crafts).",
	["opt.crafts.tip"] = "Who knows the recipe",
	["tip.crafts.tip"] = "On a recipe item: characters who know it and characters who have the profession but not the recipe.",
	["msg.crafts.known"] = "Known by: %s",
	["msg.crafts.missing"] = "Not known by: %s",
	["msg.crafts.skill"] = "%s %d (%d recipes)",
	["msg.crafts.none"] = "No profession remembered: open each character's profession window once.",
	["msg.crafts.forgot"] = "Forgot the professions of %s.",
	["msg.crafts.nochar"] = "No character named %s in the profession memory.",
	["help.crafts"] = "/sui crafts [forget <name>] - professions remembered per character",
})
