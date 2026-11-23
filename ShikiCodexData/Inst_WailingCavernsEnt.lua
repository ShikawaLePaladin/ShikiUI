-- ShikiCodexData\Inst_WailingCavernsEnt.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["WailingCavernsEnt"] = {
	n = "Wailing Caverns (Entrance)", f = "Cavernes des lamentations (Entr\195\169e)", kd = "entrance", lv = 0, hi = 0, mx = 0, acr = "WC", loc = "The Barrens", lf = "Les Tarides",
	boss = {
		{ n = "Mad Magglish", f = "Magglish le Dingue", px = "Varies",
			id = { 5334 },
			rt = { 100 }
		},
		{ n = "Trigore the Lasher", f = "Trigore le Flagelleur",
			id = { 5425, 5426 },
			rt = { 50, 50 },
			fl = { 2, 2 },
			mk = {
				[1] = 6,
				[2] = 6,
			}
		},
		{ n = "Boahn",
			id = { 5422, 5423 },
			rt = { 70, 30 }
		},
		{ n = "Kalldan Felmoon",
			id = { 6474, 6475, 6476 },
			ct = {
				[1] = { 6466, 0, 15 },
				[2] = { 6467, 0, 15 },
				[3] = { 6468, 0, 15 },
			},
			dc = {
				[1] = 64,
				[2] = 64,
				[3] = 64,
			}
		},
	},
}
