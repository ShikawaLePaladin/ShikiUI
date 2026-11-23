-- ShikiCodexData\Inst_ScarletMonasteryCathedral.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["ScarletMonasteryCathedral"] = {
	n = "Scarlet Monastery (Cathedral)", f = "Monast\195\168re \195\169carlate (Cath\195\169drale)", kd = "dungeon", lv = 25, hi = 45, mx = 5, acr = "SMCath", loc = "Tirisfal Glades", lf = "Clairi\195\168res de Tirisfal", ky = { { n = "The Scarlet Key", id = 7146 } },
	boss = {
		{ n = "High Inquisitor Fairbanks", f = "Grand Inquisiteur Fairbanks",
			id = { 19507, 19508, 19509 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Scarlet Commander Mograine", f = "Commandant \195\169carlate Mograine",
			id = { 7724, 10330, 7726, 7723, 51804, 51217 },
			rt = { 25, 25, 25, 25, 8, 1 },
			fl = { 2, 2, 2, 2, 0, 0 },
			mk = {
				[5] = 6,
				[6] = 6,
			},
			dc = {
				[6] = 60,
			}
		},
		{ n = "High Inquisitor Whitemane", f = "Grand Inquisiteur Whitemane",
			id = { 7720, 7722, 7721, 51217 },
			rt = { 33, 33, 33, 1 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Trash Mobs-Scarlet Monastery (Cathedral)",
			id = {
				5819, 7755, 7727, 7728, 7759, 7760, 7754, 10332, 1992, 2262, 7787, 7729, 7761, 7752, 8226, 7786,
				5756, 7736, 8225, 80792, 7753, 7730, 7758, 7757, 10328, 10331, 10329,
			},
			rt = {
				0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.1, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01,
				0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.3, 1.7, 1.6,
			},
			fl = { 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0 },
			mk = {
				[20] = 6,
			}
		},
		{ n = "Chain of the Scarlet Crusade", pg = "Scarlet" },
	},
}
