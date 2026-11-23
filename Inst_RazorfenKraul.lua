-- ShikiCodexData\Inst_RazorfenKraul.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["RazorfenKraul"] = {
	n = "Razorfen Kraul", f = "Kraal de Tranchebauge", kd = "dungeon", lv = 19, hi = 38, mx = 5, acr = "RFK", loc = "The Barrens", lf = "Les Tarides",
	boss = {
		{ n = "Aggem Thorncurse", f = "Aggem Mant\195\169pine",
			id = { 6681, 80732, 80733, 80789, 5825 },
			rt = { 100, 35, 35, 0.1, 10 },
			fl = { 0, 2, 2, 0, 0 },
			mk = {
				[2] = 6,
				[3] = 6,
				[4] = 6,
				[5] = 6,
			},
			ct = {
				[5] = { 6751, 0, 15, 6752, 0, 15 },
			}
		},
		{ n = "Death Speaker Jargba", f = "N\195\169crorateur Jargba",
			id = { 6685, 6682, 2816, 5825 },
			rt = { 33, 33, 33, 10 },
			fl = { 2, 2, 2, 0 },
			ct = {
				[4] = { 6751, 0, 15, 6752, 0, 15 },
			}
		},
		{ n = "Overlord Ramtusk", f = "Seigneur Brusquebroche",
			id = { 6687, 6686, 80734, 5825 },
			rt = { 33, 33, 33, 10 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[3] = 6,
			},
			ct = {
				[4] = { 6751, 0, 15, 6752, 0, 15 },
			}
		},
		{ n = "Razorfen Spearhide", f = "Lanceur de Tranchebauge", px = "Rare",
			id = { 6679, 5825 },
			rt = { 80, 10 },
			ct = {
				[2] = { 6751, 0, 15, 6752, 0, 15 },
			}
		},
		{ n = "Rotthorn", m = 6,
			id = { 50800, 58089, 58090, 58091, 41853 },
			rt = { 25, 25, 25, 25, 100 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 41854, 0, 15, 41855, 0, 15 },
			}
		},
		{ n = "Agathelos the Raging", f = "Agathelos l'Enrag\195\169",
			id = { 6690, 6691, 80735, 80736, 69170 },
			rt = { 25, 25, 25, 25, 0.5 },
			fl = { 2, 2, 2, 2, 0 },
			mk = {
				[3] = 6,
				[4] = 6,
				[5] = 6,
			}
		},
		{ n = "Blind Hunter", f = "Chasseur aveugle", px = "Rare",
			id = { 6695, 6697, 6696 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Charlga Razorflank", f = "Charlga Trancheflanc",
			id = { 6693, 6694, 6692, 17008, 5825, 5792, 5793, 51217, 17039, 17042, 17043 },
			rt = { 33, 33, 33, 100, 10, 100, 100, 1, 1, 1, 1 },
			fl = { 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0 },
			mk = {
				[8] = 6,
				[9] = 8,
				[10] = 8,
				[11] = 8,
			},
			ct = {
				[4] = { 17042, 0, 15, 17043, 0, 15, 17039, 0, 15 },
				[5] = { 6751, 0, 15, 6752, 0, 15 },
				[6] = { 4197, 0, 15, 6725, 0, 15, 6742, 0, 15 },
				[7] = { 4197, 0, 15, 6725, 0, 15, 6742, 0, 15 },
			},
			dc = {
				[8] = 60,
			}
		},
		{ n = "Earthcaller Halmgar", f = "Implorateur de la terre Halmgar", px = "Rare",
			id = { 6689, 6688, 5825 },
			rt = { 50, 50, 10 },
			fl = { 2, 2, 0 },
			ct = {
				[3] = { 6751, 0, 15, 6752, 0, 15 },
			}
		},
		{ n = "Trash Mobs-Razorfen Kraul",
			id = { 80789, 2264, 1488, 4438, 1978, 2039, 1727, 776, 1976, 1975, 2549, 5825 },
			rt = { 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 10 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0 },
			mk = {
				[1] = 6,
			},
			ct = {
				[12] = { 6751, 0, 15, 6752, 0, 15 },
			}
		},
	},
}
