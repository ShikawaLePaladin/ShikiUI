-- Locale_Flights : textes du module "flights" (francais sans accents, anglais). Un fichier par module ; tout reste dans l'espace
-- de noms du module. Une entree par ligne : ["cle"] = "texte". Memes cles et memes %s / %d dans les deux langues.
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["cat.flights"] = "Chronometre de vol",
	["opt.modules.flights"] = "Chronometre de vol",
	["tip.modules.flights"] = "Mesure la duree de chaque vol et affiche un compte a rebours au trajet suivant (/sui flights).",
	["opt.flights.timer"] = "Barre pendant le vol",
	["tip.flights.timer"] = "Destination et temps restant pendant le vol (temps ecoule la premiere fois).",
	["opt.flights.tip"] = "Duree sur la carte des vols",
	["tip.flights.tip"] = "Ajoute la duree connue dans l'infobulle d'une destination.",
	["msg.flights.to"] = "Vol vers %s",
	["msg.flights.learning"] = "%s (premier vol : mesure en cours)",
	["msg.flights.tip"] = "Duree : %s",
	["msg.flights.unknown"] = "Duree : inconnue (mesuree au premier vol)",
	["msg.flights.none"] = "Aucun vol mesure pour l'instant.",
	["help.flights"] = "/sui flights - liste les durees de vol mesurees",
})

SUI.AddStrings("en", {
	["cat.flights"] = "Flight timer",
	["opt.modules.flights"] = "Flight timer",
	["tip.modules.flights"] = "Measures each flight and shows a countdown the next time you take it (/sui flights).",
	["opt.flights.timer"] = "Bar while flying",
	["tip.flights.timer"] = "Destination and time left while flying (elapsed time on the first flight).",
	["opt.flights.tip"] = "Duration on the flight map",
	["tip.flights.tip"] = "Adds the known duration to a destination tooltip.",
	["msg.flights.to"] = "Flying to %s",
	["msg.flights.learning"] = "%s (first flight: measuring)",
	["msg.flights.tip"] = "Duration: %s",
	["msg.flights.unknown"] = "Duration: unknown (measured on the first flight)",
	["msg.flights.none"] = "No flight measured yet.",
	["help.flights"] = "/sui flights - lists the measured flight times",
})
