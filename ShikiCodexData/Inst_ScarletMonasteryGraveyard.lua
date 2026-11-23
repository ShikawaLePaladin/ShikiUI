-- ShikiCodexData\Inst_ScarletMonasteryGraveyard.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["ScarletMonasteryGraveyard"] = {
	n = "Scarlet Monastery (Graveyard)", f = "Monast\195\168re \195\169carlate (Cimeti\195\168re)", kd = "dungeon", lv = 25, hi = 36, mx = 5, acr = "SMGY", loc = "Tirisfal Glades", lf = "Clairi\195\168res de Tirisfal",
	boss = {
		{ n = "Interrogator Vishas", f = "Interrogateur Vishas",
			id = { 7682, 7683, 80741, 80742, 51217 },
			rt = { 50, 50, 35, 35, 1 },
			fl = { 2, 2, 0, 0, 0 },
			mk = {
				[3] = 6,
				[4] = 6,
				[5] = 6,
			},
			dc = {
				[5] = 60,
			}
		},
		{ n = "Scorn", f = "D\195\169dain", px = "Scourge Invasion",
			id = { 23169, 23170, 23168 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Bloodmage Thalnos", f = "Mage de sang Thalnos",
			id = { 7685, 7684, 80743, 51217 },
			rt = { 50, 50, 35, 1 },
			fl = { 2, 2, 0, 0 },
			mk = {
				[3] = 6,
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Ironspine", f = "Echine-de-fer", px = "Rare",
			id = { 7688, 7687, 7686 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Azshir the Sleepless", f = "Azshir le Sans-sommeil", px = "Rare",
			id = { 7709, 7708, 7731 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Fallen Champion", f = "Champion mort", px = "Rare",
			id = { 7691, 7690, 7689 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Duke Dreadmoore", m = 6,
			id = { 55388, 55386, 55387, 55389 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Trash Mobs-Scarlet Monastery (Graveyard)",
			id = { 5819, 7727, 7728, 80791, 7754, 10332, 2262, 7787, 7729, 7761, 7752, 8226, 7786, 7753, 7730, 80794 },
			rt = { 0.01, 0.01, 0.01, 0.02, 0.01, 0.1, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.02 },
			fl = { 2, 2, 2, 0, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0 },
			mk = {
				[4] = 6,
				[16] = 6,
			}
		},
		{ n = "Chain of the Scarlet Crusade", pg = "Scarlet" },
	},
}
