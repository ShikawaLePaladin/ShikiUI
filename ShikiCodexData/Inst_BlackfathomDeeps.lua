-- ShikiCodexData\Inst_BlackfathomDeeps.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["BlackfathomDeeps"] = {
	n = "Blackfathom Deeps", f = "Profondeurs de Brassenoire", kd = "dungeon", lv = 19, hi = 32, mx = 5, acr = "BFD", loc = "Ashenvale",
	boss = {
		{ n = "Ghamoo-ra",
			id = { 6907, 6908, 80718 },
			rt = { 50, 50, 35 },
			mk = {
				[3] = 6,
			}
		},
		{ n = "Lady Sarevess", f = "Dame Sarevess",
			id = { 888, 3078, 11121, 5952 },
			rt = { 33, 33, 33, 80 },
			fl = { 2, 2, 2, 0 },
			ct = {
				[4] = { 7003, 0, 15, 7004, 0, 15 },
			}
		},
		{ n = "Gelihast",
			id = { 6906, 6905, 1470, 80720 },
			rt = { 50, 50, 15, 35 },
			mk = {
				[4] = 6,
			}
		},
		{ n = "Velthelaxx the Defiler", m = 4,
			id = { 58120, 58121, 58122, 58123 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Baron Aquanis",
			id = { 16782 },
			rt = { 100 },
			ct = {
				[1] = { 16886, 0, 15, 16887, 0, 15 },
			}
		},
		{ n = "Fathom Stone",
			id = { 16762 },
			rt = { 100 }
		},
		{ n = "Twilight Lord Kelris", f = "Seigneur du cr\195\169puscule Kelris",
			id = { 1155, 6903, 80719, 5881 },
			rt = { 50, 35, 15, 100 },
			mk = {
				[3] = 6,
			},
			ct = {
				[4] = { 7001, 0, 15, 7002, 0, 15 },
			}
		},
		{ n = "Old Serra'kis", f = "Vieux Serra'kis",
			id = { 6901, 6902, 6904 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Aku'mai",
			id = { 6911, 6910, 6909, 51217 },
			rt = { 33, 33, 33, 1 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Trash Mobs-Blackfathom Deeps",
			id = { 1486, 3416, 1491, 3414, 1454, 1481, 2567, 3413, 3415, 3417, 2271 },
			rt = { 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
			mk = {
				[9] = 8,
				[10] = 8,
				[11] = 8,
			}
		},
	},
}
