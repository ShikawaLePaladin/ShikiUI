-- ShikiCodexData\Inst_CowKing.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["CowKing"] = {
	n = "Moo", kd = "world", lv = 1, hi = 60, mx = 20, acr = "CowKing", m = 6, loc = "Moomoo Grove",
	boss = {
		{ n = "Moo",
			id = { 60486, 60487, 60488, 60489, 60490, 4144, 60485, 60491, 51261 },
			rt = { 25, 50, 50, 50, 50, 100, 100, 100, 100 },
			fl = { 0, 2, 2, 2, 2, 0, 0, 0, 0 },
			dc = {
				[6] = 2,
				[7] = 33,
				[8] = 33,
			}
		},
	},
}
