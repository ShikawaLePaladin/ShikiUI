-- ShikiCodexData\Inst_WailingCaverns.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["WailingCaverns"] = {
	n = "Wailing Caverns", f = "Cavernes des lamentations", kd = "dungeon", lv = 10, hi = 24, mx = 5, acr = "WC", loc = "The Barrens", lf = "Les Tarides",
	boss = {
		{ n = "Lord Cobrahn", f = "Seigneur Cobrahn",
			id = { 6465, 6460, 10410, 9738 },
			rt = { 33, 33, 33, 100 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[4] = 6,
			},
			ct = {
				[4] = { 6504, 0, 15, 6505, 0, 15 },
			}
		},
		{ n = "Lady Anacondra", f = "Dame Anacondra",
			id = { 6446, 10412, 5404, 80709, 23800, 9739, 2189, 2190 },
			rt = { 25, 25, 25, 25, 0.2, 100, 50, 50 },
			fl = { 2, 2, 2, 2, 0, 0, 0, 0 },
			mk = {
				[4] = 6,
				[5] = 6,
				[6] = 6,
				[7] = 6,
				[8] = 6,
			},
			ct = {
				[6] = { 6504, 0, 15, 6505, 0, 15 },
			},
			dc = {
				[7] = 29,
				[8] = 29,
			}
		},
		{ n = "Kresh",
			id = { 6447, 80710, 13245, 49992, 6443 },
			rt = { 33, 33, 33, 0.02, 80 },
			fl = { 2, 2, 2, 0, 0 },
			mk = {
				[2] = 6,
				[4] = 6,
				[5] = 6,
			},
			ct = {
				[4] = { 49991, 0, 15 },
				[5] = { 6480, 0, 15, 918, 0, 15 },
			}
		},
		{ n = "Deviate Faerie Dragon", f = "Dragon f\195\169\195\169rique d\195\169viant", px = "Rare",
			id = { 5243, 6632, 6443 },
			rt = { 50, 50, 80 },
			fl = { 2, 2, 0 },
			ct = {
				[3] = { 6480, 0, 15, 918, 0, 15 },
			}
		},
		{ n = "Zandara Windhoof", m = 6,
			id = { 55371, 55369, 55370, 41410 },
			rt = { 50, 25, 25, 100 },
			fl = { 0, 2, 2, 0 },
			ct = {
				[4] = { 70224, 0, 15 },
			}
		},
		{ n = "Lord Pythas", f = "Seigneur Pythas",
			id = { 6473, 80711, 6472, 9740, 80864 },
			rt = { 33, 33, 33, 100, 100 },
			fl = { 2, 2, 2, 0, 0 },
			mk = {
				[2] = 6,
				[4] = 6,
				[5] = 6,
			},
			ct = {
				[4] = { 6504, 0, 15, 6505, 0, 15 },
				[5] = { 80860, 0, 15, 80861, 0, 15 },
			}
		},
		{ n = "Skum",
			id = { 6448, 6449, 80712, 6443 },
			rt = { 33, 33, 33, 80 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[3] = 6,
				[4] = 6,
			},
			ct = {
				[4] = { 6480, 0, 15, 918, 0, 15 },
			}
		},
		{ n = "Vangros", m = 6,
			id = { 55374, 55372, 55373 },
			rt = { 50, 25, 25 },
			fl = { 0, 2, 2 }
		},
		{ n = "Lord Serpentis", f = "Seigneur Serpentis", px = "Upper",
			id = { 5970, 10411, 6459, 6469, 9741, 80863 },
			rt = { 25, 25, 25, 25, 100, 25 },
			fl = { 2, 2, 2, 2, 0, 2 },
			mk = {
				[5] = 6,
				[6] = 6,
			},
			ct = {
				[5] = { 6504, 0, 15, 6505, 0, 15 },
				[6] = { 80860, 0, 15, 80861, 0, 15 },
			}
		},
		{ n = "Verdan the Everliving", f = "Verdan l'Immortel", px = "Upper",
			id = { 6629, 6630, 6631, 6443 },
			rt = { 33, 33, 33, 80 },
			fl = { 2, 2, 2, 0 },
			ct = {
				[4] = { 6480, 0, 15, 918, 0, 15 },
			}
		},
		{ n = "Mutanus the Devourer", f = "Mutanus le D\195\169voreur",
			id = { 6461, 6627, 6463, 81006, 10441, 6443, 51217 },
			rt = { 25, 25, 25, 25, 25, 80, 0.1 },
			fl = { 2, 2, 2, 2, 2, 0, 0 },
			mk = {
				[7] = 6,
			},
			ct = {
				[5] = { 10657, 0, 15, 10658, 0, 15 },
				[6] = { 6480, 0, 15, 918, 0, 15 },
			},
			dc = {
				[7] = 60,
			}
		},
		{ n = "Trash Mobs-Wailing Caverns",
			id = { 10413, 55381, 80807, 80862 },
			rt = { 2, 0.02, 0.02, 30 },
			mk = {
				[2] = 6,
				[3] = 6,
				[4] = 6,
			},
			ct = {
				[4] = { 80860, 0, 15, 80861, 0, 15 },
			}
		},
		{ n = "Embrace of the Viper", pg = "Wailing" },
	},
}
