-- ShikiCodexData\Inst_GnomereganEnt.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["GnomereganEnt"] = {
	n = "Gnomeregan (Entrance)", f = "Gnomeregan (Entr\195\169e)", kd = "entrance", lv = 0, hi = 0, mx = 0, acr = "Gnome", loc = "Dun Morogh",
	boss = {
		{ n = "Matrix Punchograph 3005-A",
			id = { 9280 },
			ct = {
				[1] = { 9282, 0, 15 },
			}
		},
		{ n = "Namdo Bizzfizzle",
			id = { 14639 },
			ct = {
				[1] = { 4381, 0, 15 },
			}
		},
		{ n = "Techbot",
			id = { 9444, 9277, 9309 },
			rt = { 69, 100, 100 },
			ct = {
				[3] = { 9608, 0, 15, 9609, 0, 15 },
			}
		},
		{ n = "Trash Mobs-Gnomeregan",
			id = { 9279 },
			rt = { 15 },
			ct = {
				[1] = { 9280, 0, 15 },
			}
		},
	},
}
