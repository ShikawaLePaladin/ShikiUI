-- ShikiCodexData\Inst_StormwroughtRuins.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["StormwroughtRuins"] = {
	n = "Stormwrought Ruins", kd = "dungeon", lv = 35, hi = 42, mx = 5, acr = "SMR", m = 4, loc = "Balor", ky = { { n = "Key to Stormwrought Castle", i = "6+" } },
	boss = {
		{ n = "Oronok Torn-Heart",
			id = { 58135, 58136, 58137, 58177, 41797 },
			rt = { 25, 25, 25, 25, 100 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 41798, 0, 15 },
			}
		},
		{ n = "Dagar the Glutton",
			id = { 58130, 58132, 58133, 58176 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Librarian Theodorus",
			id = { 58138, 58139, 58140, 58141, 41940 },
			rt = { 25, 25, 25, 25, 100 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 58279, 0, 15, 58280, 0, 15 },
			},
			dc = {
				[5] = 45,
			}
		},
		{ n = "Duke Balor the IV",
			id = { 58142, 58143, 58144, 58145, 41857, 41921 },
			rt = { 25, 25, 25, 25, 100, 100 },
			fl = { 2, 2, 2, 2, 0, 0 },
			ct = {
				[5] = { 58073, 0, 15 },
				[6] = { 58261, 0, 15, 58262, 0, 15 },
			}
		},
		{ n = "Chieftain Stormsong",
			id = { 58146, 58147, 58148, 58149, 75 },
			rt = { 25, 25, 25, 25, 6 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 58134, 0, 15 },
			}
		},
		{ n = "Deathlord Tidebane",
			id = { 58150, 58151, 58152, 58153, 24, 70, 58276, 950 },
			rt = { 25, 25, 25, 25, 6, 6, 1, 0.2 },
			fl = { 2, 2, 2, 2, 0, 0, 0, 0 },
			ct = {
				[6] = { 131, 0, 15 },
			}
		},
		{ n = "Subjugator Halthas Shadecrest",
			id = { 58183, 58184, 58185, 58186, 83 },
			rt = { 25, 25, 25, 25, 6 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 56113, 0, 15 },
			}
		},
		{ n = "Mycellakos",
			id = { 58179, 58180, 58181, 58182, 41926 },
			rt = { 25, 25, 25, 25, 100 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 58268, 0, 15, 58269, 0, 15, 58270, 0, 15 },
			}
		},
		{ n = "Eldermaw the Primordial",
			id = { 58187, 58188, 58189, 58190 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Lady Drazare",
			id = { 58191, 58192, 58193, 58194, 41942 },
			rt = { 25, 25, 25, 25, 100 },
			fl = { 2, 2, 2, 2, 0 },
			dc = {
				[5] = 45,
			}
		},
		{ n = "Ighal'for",
			id = { 41939 },
			rt = { 100 },
			ct = {
				[1] = { 58277, 0, 15, 58278, 0, 15 },
			}
		},
		{ n = "Mergothid",
			id = { 58200, 58201, 58202, 58203, 58204, 58199 },
			rt = { 20, 20, 20, 20, 20, 1 },
			fl = { 2, 2, 2, 2, 2, 0 }
		},
		{ n = "Remains of the Innocent",
			id = { 58195, 58196, 58197, 58198, 41938 },
			rt = { 25, 25, 25, 25, 100 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Trash Mobs-Stormwrought Ruins",
			id = {
				70113, 58178, 58131, 58294, 58295, 58296, 58297, 58298, 58299, 58300, 58301, 1992, 2262, 5756, 5819,
				7727, 7728, 7729, 7730, 7736, 7752, 7753, 7754, 7755, 7757, 7759, 7760, 7761, 7786, 7787, 8225, 8226,
				41941,
			},
			rt = {
				0.02, 1.35, 1.35, 0.0125, 0.0125, 0.0125, 0.0125, 0.0125, 0.0125, 0.0125, 0.0125, 0.02, 0.02, 0.02,
				0.02, 0.02, 0.04, 0.02, 0.02, 0.02, 0.02, 0.02, 0.01, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02,
				0.02, 70,
			},
			fl = { 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0 },
			ct = {
				[1] = { 56040, 0, 15 },
			},
			dc = {
				[33] = 45,
			}
		},
		{ n = "Stormreaver Attire", pg = "Stormreaver" },
	},
}
