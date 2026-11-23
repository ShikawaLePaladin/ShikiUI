-- ShikiCodexData\Inst_DragonmawRetreat.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["DragonmawRetreat"] = {
	n = "Dragonmaw Retreat", kd = "dungeon", lv = 27, hi = 33, mx = 5, acr = "DMR", m = 4, loc = "Wetlands", lf = "Les Paluns", ky = { { n = "Lower Reserve Key", i = "9+" } },
	boss = {
		{ n = "Gowlfang",
			id = { 41571, 41572, 41573, 41574, 41575, 41829 },
			rt = { 20, 20, 20, 20, 20, 20 },
			fl = { 2, 2, 2, 2, 2, 2 },
			ct = {
				[6] = { 41830, 0, 15 },
			}
		},
		{ n = "Cavernweb Broodmother", px = "Lower",
			id = { 58039, 58040, 58041, 58042, 58043, 37009, 41834 },
			rt = { 20, 20, 20, 20, 20, 10, 100 },
			fl = { 2, 2, 2, 2, 2, 0, 0 }
		},
		{ n = "Web Master Torkon", px = "Lower",
			id = { 41566, 41567, 41568, 41569, 41570, 41874 },
			rt = { 20, 20, 20, 20, 20, 100 },
			fl = { 2, 2, 2, 2, 2, 0 },
			dc = {
				[6] = 45,
			}
		},
		{ n = "Garlok Flamekeeper",
			id = { 41578, 41579, 41580, 41581 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Halgan Redbrand",
			id = { 58044, 58045, 58046, 58047, 76, 77 },
			rt = { 25, 25, 25, 25, 6, 6 },
			fl = { 2, 2, 2, 2, 0, 0 },
			ct = {
				[5] = { 156, 0, 15 },
				[6] = { 56112, 0, 15 },
			}
		},
		{ n = "Slagfist Destroyer",
			id = { 41558, 41559, 41560, 41719 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Overlord Blackheart",
			id = { 41726, 41725, 41724, 41727, 74, 41841 },
			rt = { 25, 25, 25, 25, 6, 100 },
			fl = { 2, 2, 2, 2, 0, 0 },
			ct = {
				[5] = { 58112, 0, 15 },
				[6] = { 41842, 0, 15, 41843, 0, 15, 41844, 0, 15 },
			}
		},
		{ n = "Elder Hollowblood",
			id = { 41720, 41721, 41722, 41723, 31 },
			rt = { 25, 25, 25, 25, 6 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Chest of Dathronag",
			id = { 41875 },
			rt = { 100 },
			dc = {
				[1] = 45,
			}
		},
		{ n = "Searistrasz",
			id = { 41561, 41562, 41563, 41564, 41565 },
			rt = { 25, 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2, 2 }
		},
		{ n = "Zuluhed the Whacked",
			id = { 41845, 41846, 41847, 41848, 58099, 69, 71, 41895, 41711, 41981 },
			rt = { 20, 20, 20, 20, 20, 4.5, 4.5, 1.5, 100, 100 },
			fl = { 2, 2, 2, 2, 2, 0, 0, 0, 0, 0 },
			ct = {
				[6] = { 65, 0, 15 },
				[7] = { 66, 0, 15 },
				[8] = { 58234, 0, 15, 58235, 0, 15, 58236, 0, 15 },
				[9] = { 41713, 0, 15, 41714, 0, 15, 41715, 0, 15 },
				[10] = { 41982, 0, 15, 41713, 0, 15, 41714, 0, 15, 41715, 0, 15 },
			}
		},
		{ n = "Trash Mobs-Dragonmaw Retreat",
			id = {
				58102, 58103, 58104, 58105, 58106, 58107, 58108, 58109, 58110, 58111, 58113, 58114, 58115, 70119,
				41825,
			},
			rt = { 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 1.35, 1.35, 1.35, 1.35, 0.01, 50 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 2, 0 },
			ct = {
				[14] = { 56046, 0, 15 },
				[15] = { 41826, 0, 15, 41827, 0, 15, 41828, 0, 15 },
			}
		},
		{ n = "Dragonmaw Battlegarb", pg = "DragonmawBattlegarb" },
	},
}
