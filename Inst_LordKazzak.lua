-- ShikiCodexData\Inst_LordKazzak.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["LordKazzak"] = {
	n = "Lord Kazzak", f = "Seigneur Kazzak", kd = "world", lv = 1, hi = 60, mx = 40, acr = "LK", loc = "Blasted Lands", lf = "Terres foudroy\195\169es",
	boss = {
		{ n = "Lord Kazzak", f = "Seigneur Kazzak",
			id = {
				18546, 17112, 18204, 18543, 19133, 17111, 19135, 18544, 19134, 17113, 17682, 17683, 18600, 17962,
				17963, 17964, 17969, 18665, 14479, 70164, 70169, 83545, 26017, 21891,
			},
			rt = { 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 6, 4, 4, 8, 12, 16, 13, 100, 4, 2, 2, 40, 20, 20 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2 },
			mk = {
				[14] = 6,
				[20] = 6,
				[21] = 6,
				[22] = 6,
				[23] = 8,
				[24] = 8,
			},
			ct = {
				[14] = { 13926, 0, 15, 7971, 0, 15, 3864, 0, 15, 55251, 0, 15, 55250, 0, 15, 7910, 0, 15, 7909, 0, 15, 1529, 0, 15, 12361, 0, 15 },
				[15] = { 13926, 0, 15, 7971, 0, 15, 55250, 0, 6, 7909, 0, 15, 3864, 0, 15, 55251, 0, 6, 7910, 0, 15, 1529, 0, 15, 12364, 0, 15 },
				[16] = { 13926, 0, 15, 7971, 0, 15, 55250, 0, 6, 7909, 0, 15, 3864, 0, 15, 55251, 0, 6, 7910, 0, 15, 1529, 0, 15, 12800, 0, 15 },
				[17] = { 13926, 0, 15, 7971, 0, 15, 55250, 0, 6, 7909, 0, 15, 3864, 0, 15, 55251, 0, 6, 7910, 0, 15, 1529, 0, 15, 12799, 0, 15 },
				[18] = { 18608, 0, 15, 18609, 0, 15 },
				[19] = { 14101, 0, 15 },
				[20] = { 56017, 0, 15 },
				[21] = { 56010, 0, 15 },
				[22] = { 65003, 0, 15 },
			},
			dc = {
				[11] = 2,
				[12] = 2,
				[13] = 2,
				[14] = 8,
				[15] = 8,
				[16] = 8,
				[17] = 8,
			}
		},
	},
}
