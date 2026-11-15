-- Locale_Map : textes du module "map" (francais sans accents, anglais). Une entree par ligne : ["cle"] = "texte".
ShikiUI = ShikiUI or {}
local SUI = ShikiUI

SUI.AddStrings("fr", {
	["mod.map.title"] = "Carte du monde",
	["cat.map"] = "Carte du monde",
	["mod.map.desc"] = "Coordonnees du joueur affichees sur la carte et echelle reglable. Le deplacement de la carte reste celui du module Fenetres.",
	["opt.modules.map"] = "Carte du monde",
	["tip.modules.map"] = "Coordonnees sur la carte et echelle reglable.",
	["opt.map.coords"] = "Coordonnees du joueur",
	["tip.map.coords"] = "Affiche ta position (x, y) en bas de la carte ouverte.",
	["opt.map.scale"] = "Echelle de la carte",
	["tip.map.scale"] = "Taille de la carte du monde (80 a 150 pour cent). S'applique tout de suite, se restaure si tu coupes le module.",
	["help.map"] = "mapinfo : affiche tes coordonnees actuelles dans le chat.",
	["msg.map.closed"] = "Ouvre d'abord la carte du monde (touche M).",
})

SUI.AddStrings("en", {
	["mod.map.title"] = "World map",
	["cat.map"] = "World map",
	["mod.map.desc"] = "Player coordinates shown on the world map and adjustable scale. Moving the map stays with the Windows module.",
	["opt.modules.map"] = "World map",
	["tip.modules.map"] = "Coordinates on the map and adjustable scale.",
	["opt.map.coords"] = "Player coordinates",
	["tip.map.coords"] = "Shows your position (x, y) at the bottom of the open map.",
	["opt.map.scale"] = "Map scale",
	["tip.map.scale"] = "World map size (80 to 150 percent). Applies live, restored if you disable the module.",
	["help.map"] = "mapinfo: prints your current coordinates in chat.",
	["msg.map.closed"] = "Open the world map first (key M).",
})
