-- ShikiCodexData\Inst_KingMosh.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["KingMosh"] = {
	n = "King Mosh", f = "Roi Mosh", kd = "world", lv = 1, hi = 60, mx = 40, acr = "KingMosh", m = 8, loc = "Un'goro Crater",
	boss = {
		{ n = "King Mosh", f = "Roi Mosh",
			id = { 20003, 20005, 26013, 81041, 83061, 83167 },
			rt = { 17, 17, 17, 17, 17, 17 },
			fl = { 2, 2, 2, 2, 2, 2 },
			ct = {
				[6] = { 83123, 0, 15 },
			},
			dc = {
				[3] = 7,
				[6] = 48,
			}
		},
	},
}
