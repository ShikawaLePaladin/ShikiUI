-- ShikiCodexData\Inst_ScarletMonasteryLibrary.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["ScarletMonasteryLibrary"] = {
	n = "Scarlet Monastery (Library)", f = "Monast\195\168re \195\169carlate (Biblioth\195\168que)", kd = "dungeon", lv = 21, hi = 39, mx = 5, acr = "SM Lib", loc = "Tirisfal Glades", lf = "Clairi\195\168res de Tirisfal",
	boss = {
		{ n = "Houndmaster Loksey", f = "Ma\195\174tre-chien Loksey",
			id = { 7710, 7756, 3456, 51217 },
			rt = { 33, 33, 33, 1 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Arcanist Doan", f = "Arcaniste Doan",
			id = { 7714, 7713, 7712, 7711, 51217 },
			rt = { 25, 25, 25, 25, 1 },
			fl = { 2, 2, 2, 2, 0 },
			mk = {
				[5] = 6,
			},
			dc = {
				[5] = 60,
			}
		},
		{ n = "Doan's Strongbox",
			id = { 7146 },
			dc = {
				[1] = 25,
			}
		},
		{ n = "Brother Wystan", m = 6,
			id = { 55473, 55472, 55471, 55470 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Trash Mobs-Scarlet Monastery",
			id = {
				5819, 80790, 7755, 7727, 7728, 80791, 7759, 7760, 7754, 10332, 1992, 2262, 7787, 7729, 7761, 7752,
				8226, 7786, 5756, 7736, 8225, 7753, 7730, 7758, 7757, 80794, 80799,
			},
			rt = {
				0.01, 0.1, 0.01, 0.01, 0.01, 0.02, 0.01, 0.01, 0.01, 0.1, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01,
				0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.02, 0.02,
			},
			fl = { 2, 0, 2, 2, 2, 0, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0 },
			mk = {
				[2] = 6,
				[6] = 6,
				[26] = 6,
				[27] = 6,
			}
		},
		{ n = "Chain of the Scarlet Crusade", pg = "Scarlet" },
	},
}
