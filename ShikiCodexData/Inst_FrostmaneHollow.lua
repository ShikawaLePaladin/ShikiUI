-- ShikiCodexData\Inst_FrostmaneHollow.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["FrostmaneHollow"] = {
	n = "Frostmane Hollow", kd = "dungeon", lv = 13, hi = 20, mx = 5, acr = "FH", m = 4, loc = "Dun Morogh",
	boss = {
		{ n = "Tan'sha The Sleek",
			id = { 162, 197, 184, 42300 },
			rt = { 33, 33, 33, 100 },
			fl = { 2, 2, 2, 0 },
			ct = {
				[4] = { 158, 0, 15 },
			}
		},
		{ n = "Battlemaster Ubukaz",
			id = { 134, 150, 157 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Kan'za The Seer",
			id = { 213, 241, 205 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Hailar The Frigid",
			id = { 116, 126, 110 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
	},
}
