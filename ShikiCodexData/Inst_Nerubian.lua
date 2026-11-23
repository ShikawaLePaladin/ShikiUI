-- ShikiCodexData\Inst_Nerubian.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["Nerubian"] = {
	n = "Nerubian Overseer", f = "Surveillant n\195\169rubien", kd = "world", lv = 1, hi = 60, mx = 40, acr = "Spooder", m = 6, loc = "Eastern Plaguelands", lf = "Maleterres de l'est",
	boss = {
		{ n = "Nerubian Overseer", f = "Surveillant n\195\169rubien",
			id = { 51738, 51737, 51736, 51735, 51740, 51734, 51733, 51732, 51731, 51730, 12717, 22388, 83547, 51739 },
			rt = { 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 5, 5, 5, 100 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0 },
			ct = {
				[11] = { 12640, 0, 15 },
				[12] = { 22385, 0, 15 },
				[13] = { 65014, 0, 15 },
			}
		},
	},
}
