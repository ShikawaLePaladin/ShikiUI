-- ShikiCodexData\Inst_TheCrescentGrove.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["TheCrescentGrove"] = {
	n = "The Crescent Grove", kd = "dungeon", lv = 32, hi = 38, mx = 5, acr = "CG", m = 6, loc = "Ashenvale",
	boss = {
		{ n = "Kalanar's Strongbox",
			id = { 60472 },
			rt = { 100 }
		},
		{ n = "Grovetender Engryss",
			id = { 83220, 83221, 83222, 83223, 83224, 60176, 51217 },
			rt = { 24, 24, 24, 24, 5, 100, 1 },
			fl = { 2, 2, 2, 2, 0, 0, 0 },
			dc = {
				[7] = 60,
			}
		},
		{ n = "Elder Blackmaw",
			id = { 60178, 60176 },
			rt = { 100, 100 },
			fl = { 2, 2 },
			ct = {
				[1] = { 60179, 0, 15 },
			}
		},
		{ n = "Elder 'One Eye'",
			id = { 60177, 60176 },
			rt = { 100, 100 },
			fl = { 2, 2 },
			ct = {
				[1] = { 60179, 0, 15 },
			}
		},
		{ n = "Keeper Ranathos",
			id = { 83225, 83227, 83226, 83228, 83229, 51217 },
			rt = { 24, 24, 24, 24, 5, 1 },
			fl = { 2, 2, 2, 2, 0, 0 },
			dc = {
				[6] = 60,
			}
		},
		{ n = "High Priestess A'lathea",
			id = { 83208, 83209, 83211, 83210, 51217 },
			rt = { 30, 30, 30, 10, 1 },
			fl = { 2, 2, 2, 0, 0 },
			dc = {
				[5] = 60,
			}
		},
		{ n = "Fenektis the Deceiver",
			id = { 83212, 83213, 83214, 83215, 51217 },
			rt = { 25, 25, 25, 25, 1 },
			fl = { 2, 2, 2, 2, 0 },
			dc = {
				[5] = 60,
			}
		},
		{ n = "Master Raxxieth",
			id = { 60258, 83216, 83217, 83218, 83219, 51217 },
			rt = { 0.5, 25, 25, 25, 25, 5 },
			fl = { 0, 2, 2, 2, 2, 0 },
			dc = {
				[6] = 60,
			}
		},
		{ n = "Trash Mobs-The Crescent Grove",
			id = { 83203, 83204, 83207, 83201, 83206, 83202, 83200, 83205, 61552, 61553, 61554, 61555 },
			rt = { 0.01, 0.5, 0.1, 0.5, 0.01, 0.5, 0.01, 0.5, 0.01, 0.01, 0.01, 0.01 },
			fl = { 2, 0, 0, 0, 2, 0, 2, 0, 2, 2, 2, 2 }
		},
	},
}
