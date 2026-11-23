-- ShikiCodexData\Inst_WindhornCanyon.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["WindhornCanyon"] = {
	n = "Windhorn Canyon", kd = "dungeon", lv = 26, hi = 30, mx = 5, acr = "WHC", m = 4, loc = "Thousand Needles", lf = "Mille pointes",
	boss = {
		{ n = "Pathun Duskhide",
			id = { 33025, 33026, 33028, 33027, 70242 },
			rt = { 25, 25, 25, 25, 6 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 42205, 0, 15 },
			}
		},
		{ n = "Ahgk'tos the Pure",
			id = { 33021, 33022, 33023, 33024 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Ambassador Vortalus",
			id = { 33029, 33030, 33031, 33032 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Walgan Bloodcaller",
			id = { 33033, 33035, 33082, 42275 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 },
			ct = {
				[3] = { 33036, 0, 15 },
			}
		},
		{ n = "Bonespeaker Narlgom",
			id = { 33037, 33038, 33040, 42276 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Prophet Stormhoof",
			id = { 33041, 33042, 33043, 33044, 70244 },
			rt = { 25, 25, 25, 25, 6 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 42203, 0, 15 },
			}
		},
		{ n = "Chieftain Shalk Blackwind",
			id = { 33045, 33046, 33047, 33048, 70243, 42277 },
			rt = { 25, 25, 25, 25, 6, 1.25 },
			fl = { 2, 2, 2, 2, 0, 0 },
			ct = {
				[5] = { 42204, 0, 15 },
			}
		},
		{ n = "Trash Mobs-Windhorn Canyon",
			id = { 33034, 33039, 33092, 33179, 33180, 33181, 33182, 33183, 33184, 33185 },
			rt = { 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 }
		},
		{ n = "Sacred Windhorn Attire", pg = "SacredWindhorn" },
	},
}
