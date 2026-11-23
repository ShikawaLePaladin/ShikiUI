-- ShikiCodexData\Inst_Ostarius.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["Ostarius"] = {
	n = "Ostarius", kd = "world", lv = 1, hi = 60, mx = 40, acr = "Ostarius", m = 6, loc = "Tanaris",
	boss = {
		{ n = "Ostarius",
			id = {
				83530, 83531, 83486, 83488, 83485, 83487, 83483, 83532, 83484, 83482, 83481, 83480, 83235, 17962,
				17963, 17965, 17969,
			},
			rt = { 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 100, 20, 20, 20, 20 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0 },
			ct = {
				[14] = { 13926, 0, 15, 7971, 0, 15, 3864, 0, 15, 55251, 0, 15, 55250, 0, 15, 7910, 0, 15, 7909, 0, 15, 1529, 0, 15, 12361, 0, 15 },
				[15] = { 13926, 0, 15, 7971, 0, 15, 55250, 0, 15, 7909, 0, 15, 3864, 0, 15, 55251, 0, 15, 7910, 0, 15, 1529, 0, 15, 12364, 0, 15 },
				[16] = { 13926, 0, 15, 7971, 0, 15, 55250, 0, 15, 7909, 0, 15, 3864, 0, 15, 55251, 0, 15, 7910, 0, 15, 1529, 0, 15, 12363, 0, 15 },
				[17] = { 13926, 0, 15, 7971, 0, 15, 55250, 0, 15, 7909, 0, 15, 3864, 0, 15, 55251, 0, 15, 7910, 0, 15, 1529, 0, 15, 12799, 0, 15 },
			},
			dc = {
				[14] = 8,
				[15] = 8,
				[16] = 8,
				[17] = 8,
			}
		},
	},
}
