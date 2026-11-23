-- ShikiCodexData\Inst_GilneasCity.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["GilneasCity"] = {
	n = "Gilneas City", kd = "dungeon", lv = 43, hi = 49, mx = 5, acr = "GC", m = 6, loc = "Gilneas",
	boss = {
		{ n = "Matthias Holtz",
			id = { 61305, 61304, 61306, 61307 },
			rt = { 33, 33, 33, 2 },
			fl = { 2, 2, 2, 0 }
		},
		{ n = "Packmaster Ragetooth",
			id = { 61301, 61300, 61302, 61303 },
			rt = { 33, 33, 33, 2 },
			fl = { 2, 2, 2, 0 }
		},
		{ n = "Judge Sutherland",
			id = { 61309, 61311, 61310, 61308, 61312 },
			rt = { 25, 25, 25, 25, 2 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Dustivan Blackcowl",
			id = { 61331, 61332, 61330, 61333, 61334, 61626, 41357 },
			rt = { 25, 25, 25, 25, 5, 100, 100 },
			fl = { 2, 2, 2, 2, 0, 0, 0 },
			ct = {
				[6] = { 61627, 0, 15, 61628, 0, 15, 61629, 0, 15, 61630, 0, 15 },
				[7] = { 70134, 0, 15 },
			}
		},
		{ n = "Marshal Magnus Greystone",
			id = { 61313, 61315, 61314, 61316, 61317, 61368, 113 },
			rt = { 25, 25, 25, 25, 5, 5, 5 },
			fl = { 2, 2, 2, 2, 0, 0, 0 },
			ct = {
				[7] = { 151, 0, 15 },
			}
		},
		{ n = "Horsemaster Levvin",
			id = { 61734, 61736, 61735, 61737, 83157 },
			rt = { 25, 25, 25, 25, 0.18 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Harlow Family Chest",
			id = { 61319, 61321, 61320, 61318, 61322 },
			rt = { 25, 25, 25, 25, 5 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Genn Greymane",
			id = { 61323, 61326, 61327, 61325, 61324, 61328, 61329, 61406, 61738, 69000, 61352, 61496 },
			rt = { 15, 15, 15, 15, 15, 15, 15, 0.5, 6, 1.5, 100, 100 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0 },
			ct = {
				[11] = { 61353, 0, 15, 61354, 0, 15, 61355, 0, 15 },
				[12] = { 61497, 0, 15, 61498, 0, 15, 61499, 0, 15, 61369, 0, 15 },
			}
		},
		{ n = "Trash Mobs-Gilneas City",
			id = { 61598, 61336, 61597, 61335, 61339, 61337, 61338, 61596, 41421 },
			rt = { 0.034, 0.034, 0.034, 0.034, 0.034, 0.034, 0.034, 0.034, 10 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 0 },
			ct = {
				[9] = { 55505, 0, 15 },
			}
		},
		{ n = "Greymane Armor", pg = "GreymaneArmor" },
	},
}
