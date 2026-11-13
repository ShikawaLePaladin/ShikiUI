-- Locale_Template : textes du module "template" (francais sans accents, anglais). Un fichier par module ; tout reste dans l'espace
-- de noms du module : opt.template.* tip.template.* choice.template.* msg.template.* mod.template.* help.template cat.template
-- plus les deux cles obligatoires opt.modules.template et tip.modules.template (le bouton d'activation du module).
-- Une entree par ligne : ["cle"] = "texte", (le controle des traductions lit ces lignes). Memes cles et memes %s / %d dans les deux langues.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.template"] = "Modele",
	["opt.modules.template"] = "Module modele",
	["tip.modules.template"] = "Petit compteur d'ennemis proches : sert d'exemple pour ecrire un module.",
	["opt.template.visible"] = "Afficher le compteur",
	["tip.template.visible"] = "Montre ou cache le petit cadre.",
	["opt.template.width"] = "Largeur du cadre",
	["tip.template.width"] = "Largeur en pixels.",
	["msg.template.count"] = "Ennemis proches : %d",
	["help.template"] = "/sui template - affiche le compteur du module modele",
})

SUI.AddStrings("en", {
	["cat.template"] = "Template",
	["opt.modules.template"] = "Template module",
	["tip.modules.template"] = "Small nearby-enemies counter: an example for writing a module.",
	["opt.template.visible"] = "Show the counter",
	["tip.template.visible"] = "Shows or hides the small frame.",
	["opt.template.width"] = "Frame width",
	["tip.template.width"] = "Width in pixels.",
	["msg.template.count"] = "Nearby enemies: %d",
	["help.template"] = "/sui template - prints the template module counter",
})
