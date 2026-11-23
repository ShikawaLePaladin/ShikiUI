-- ShikiCodexData\Inst_ScarletMonasteryArmory.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["ScarletMonasteryArmory"] = {
	n = "Scarlet Monastery (Armory)", f = "Monast\195\168re \195\169carlate (Armurerie)", kd = "dungeon", lv = 25, hi = 40, mx = 5, acr = "SM Arm", loc = "Tirisfal Glades", lf = "Clairi\195\168res de Tirisfal", ky = { { n = "The Scarlet Key", id = 7146 } },
	boss = {
		{ n = "Herod",
			id = { 7719, 7718, 10330, 7717, 51217 },
			rt = { 25, 25, 25, 25, 1 },
			fl = { 2, 2, 2, 2, 0 },
			mk = {
				[5] = 6,
			},
			dc = {
				[5] = 60,
			}
		},
		{ n = "Armory Quartermaster Daghelm", m = 6,
			id = { 55477, 55476, 55475, 55474, 41411 },
			rt = { 25, 25, 25, 25, 100 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 7964, 0, 15, 7965, 0, 15 },
			}
		},
		{ n = "Trash Mobs-Scarlet Monastery (Armory)",
			id = {
				5819, 7755, 7727, 7728, 7759, 7754, 10332, 1992, 2262, 7787, 7729, 7761, 7752, 8226, 7786, 5756,
				7736, 8225, 80792, 7753, 7730, 7757, 10333, 10329, 23192,
			},
			rt = {
				0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.1, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01,
				0.01, 0.01, 0.01, 0.01, 0.01, 1.6, 1.6, 1.6,
			},
			fl = { 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0 },
			mk = {
				[19] = 6,
			}
		},
		{ n = "Chain of the Scarlet Crusade", pg = "Scarlet" },
	},
}
