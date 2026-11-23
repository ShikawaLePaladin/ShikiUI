-- ShikiCodexData\Inst_Gnomeregan.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["Gnomeregan"] = {
	n = "Gnomeregan", kd = "dungeon", lv = 19, hi = 38, mx = 5, acr = "Gnome", loc = "Dun Morogh", ky = { { n = "Workshop Key", i = "Back", id = 6893 } },
	boss = {
		{ n = "Grubbis",
			id = { 9445, 9308, 26012, 80737, 80738, 80739 },
			rt = { 25, 15, 25, 25, 25, 25 },
			fl = { 2, 0, 2, 2, 2, 2 },
			mk = {
				[3] = 8,
				[4] = 6,
				[5] = 6,
				[6] = 6,
			},
			ct = {
				[2] = { 9363, 0, 15 },
			},
			dc = {
				[2] = 45,
			}
		},
		{ n = "Matrix Punchograph 3005-B",
			id = { 9282 }
		},
		{ n = "Viscous Fallout", f = "Retomb\195\169e visqueuse",
			id = { 9454, 9453, 9452 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Electrocutioner 6000", f = "Electrocuteur 6000",
			id = { 9447, 9446, 9448, 6893 },
			rt = { 33, 33, 33, 33 },
			fl = { 2, 2, 2, 2 },
			dc = {
				[4] = 25,
			}
		},
		{ n = "Matrix Punchograph 3005-C",
			id = { 9281 }
		},
		{ n = "Crowd Pummeler 9-60", f = "Faucheur de foule 9-60", px = "Upper",
			id = { 9449, 9450, 9327, 9309, 80740, 26011, 81275 },
			rt = { 33, 33, 1, 5, 33, 33, 0.8 },
			fl = { 2, 2, 0, 0, 2, 2, 0 },
			mk = {
				[5] = 6,
				[6] = 8,
				[7] = 6,
			},
			ct = {
				[4] = { 9608, 0, 15, 9609, 0, 15 },
				[7] = { 81253, 0, 15, 81252, 0, 15, 81251, 0, 15, 81250, 0, 15 },
			},
			qt = {
				[4] = "8-10",
			}
		},
		{ n = "Matrix Punchograph 3005-D",
			id = { 9316 }
		},
		{ n = "Dark Iron Ambassador", f = "Ambassadeur Sombrefer",
			id = { 9455, 9456, 9457, 9308 },
			rt = { 33, 33, 33, 15 },
			fl = { 2, 2, 2, 0 },
			ct = {
				[4] = { 9363, 0, 15 },
			},
			dc = {
				[4] = 45,
			}
		},
		{ n = "Mekgineer Thermaplugg", f = "Mekg\195\169nieur Thermaplugg",
			id = {
				9492, 9461, 9458, 9459, 4415, 4413, 4411, 7742, 40084, 51801, 9327, 9299, 9309, 26010, 60098, 81318,
				51217,
			},
			rt = { 25, 25, 25, 25, 2, 2, 2, 2, 4, 4, 1, 100, 5, 25, 50, 100, 1 },
			fl = { 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0 },
			mk = {
				[9] = 6,
				[10] = 6,
				[14] = 8,
				[15] = 6,
				[16] = 6,
				[17] = 6,
			},
			ct = {
				[5] = { 4393, 0, 15 },
				[6] = { 4388, 0, 15 },
				[7] = { 4376, 0, 15 },
				[8] = { 4397, 0, 15 },
				[9] = { 41328, 0, 15 },
				[10] = { 60098, 0, 15 },
				[12] = { 9623, 0, 15, 9624, 0, 15, 9625, 0, 15 },
				[13] = { 9608, 0, 15, 9609, 0, 15 },
				[16] = { 81319, 0, 15, 81320, 0, 15 },
			},
			qt = {
				[13] = "8-10",
			},
			dc = {
				[2] = 49,
				[15] = 45,
				[17] = 60,
			}
		},
		{ n = "Trash Mobs Gnomeregan",
			id = {
				9508, 9491, 9509, 9510, 9487, 9485, 9488, 9486, 9490, 80798, 9308, 9327, 7191, 9308, 9326, 9588,
				9279, 9280, 9282, 9281, 9316,
			},
			rt = { 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 15, 4, 4, 50, 12, 0.1, 5, 0.1, 0.1, 0.1, 0.1 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 2, 0, 2, 2, 2, 2 },
			mk = {
				[10] = 6,
			},
			ct = {
				[11] = { 9363, 0, 15 },
			},
			dc = {
				[11] = 45,
			}
		},
	},
}
