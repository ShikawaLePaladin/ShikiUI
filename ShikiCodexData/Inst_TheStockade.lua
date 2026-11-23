-- ShikiCodexData\Inst_TheStockade.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["TheStockade"] = {
	n = "The Stockade", f = "La Prison", kd = "dungeon", lv = 15, hi = 31, mx = 5, acr = "Stocks", loc = "Stormwind City", lf = "Cit\195\169 de Stormwind",
	boss = {
		{ n = "Targorr the Dread", f = "Targorr le Terrifiant", px = "Varies",
			id = { 80721, 80722, 3630 },
			rt = { 50, 50, 100 },
			fl = { 2, 2, 0 },
			mk = {
				[1] = 6,
				[2] = 6,
			},
			ct = {
				[3] = { 3400, 0, 15, 1317, 0, 15 },
			}
		},
		{ n = "Kam Deepfury",
			id = { 2280, 3640, 80723 },
			rt = { 1, 100, 90 },
			mk = {
				[3] = 6,
			},
			ct = {
				[2] = { 3562, 0, 15, 1264, 0, 15 },
			}
		},
		{ n = "Hamhock", m = 6,
			id = { 80724, 80725 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Bazil Thredd",
			id = { 2909, 2926, 80729, 80730, 80731, 80796, 51217 },
			rt = { 80, 100, 35, 35, 30, 0.05, 1 },
			mk = {
				[3] = 6,
				[4] = 6,
				[5] = 6,
				[6] = 6,
				[7] = 6,
			},
			ct = {
				[2] = { 2933, 0, 15 },
			},
			dc = {
				[7] = 60,
			}
		},
		{ n = "Dextren Ward",
			id = { 2909, 3628, 80726, 80727, 80728, 80796 },
			rt = { 40, 100, 35, 35, 30, 0.05 },
			mk = {
				[3] = 6,
				[4] = 6,
				[5] = 6,
				[6] = 6,
			},
			ct = {
				[2] = { 2033, 0, 15, 2906, 0, 15 },
			}
		},
		{ n = "Bruegal Ironknuckle",
			id = { 3228, 2941, 2942, 2909 },
			rt = { 33, 33, 33, 80 },
			fl = { 2, 2, 2, 0 }
		},
		{ n = "Trash Mobs-The Stockade",
			id = { 80796, 1076, 2909 },
			rt = { 0.05, 0.6, 80 },
			mk = {
				[1] = 6,
			}
		},
	},
}
