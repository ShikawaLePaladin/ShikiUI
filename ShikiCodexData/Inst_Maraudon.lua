-- ShikiCodexData\Inst_Maraudon.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["Maraudon"] = {
	n = "Maraudon", kd = "dungeon", lv = 35, hi = 55, mx = 5, acr = "Mara", loc = "Desolace", lf = "D\195\169solace", ky = { { n = "Scepter of Celebras", i = "Portal", id = 17191 } },
	boss = {
		{ n = "Veng",
			id = { 17765 },
			rt = { 100 },
			ct = {
				[1] = { 17774, 0, 15 },
			},
			dc = {
				[1] = 45,
			}
		},
		{ n = "Noxxion",
			id = { 17746, 17744, 17745, 17702 },
			rt = { 33, 33, 33, 100 },
			fl = { 2, 2, 2, 0 },
			ct = {
				[4] = { 17191, 0, 15 },
			}
		},
		{ n = "Razorlash", f = "Tranchefouet",
			id = { 17749, 17748, 17750, 17751, 60780, 51802 },
			rt = { 25, 25, 25, 25, 3, 8 },
			fl = { 2, 2, 2, 2, 0, 0 },
			mk = {
				[5] = 6,
				[6] = 6,
			},
			ct = {
				[5] = { 65022, 0, 15 },
			}
		},
		{ n = "Maraudos",
			id = { 17764 },
			rt = { 100 },
			ct = {
				[1] = { 17774, 0, 15 },
			},
			dc = {
				[1] = 45,
			}
		},
		{ n = "Lord Vyletongue", f = "Seigneur Vylelangue",
			id = { 17755, 17754, 17752, 17684, 17703, 61748, 51217 },
			rt = { 33, 33, 33, 80, 100, 100, 5 },
			fl = { 2, 2, 2, 0, 0, 0, 0 },
			mk = {
				[6] = 6,
				[7] = 6,
			},
			ct = {
				[4] = { 17775, 0, 15, 17776, 0, 15, 17777, 0, 15, 17779, 0, 15 },
				[5] = { 17191, 0, 15 },
				[6] = { 61517, 0, 15 },
			},
			dc = {
				[7] = 60,
			}
		},
		{ n = "Meshlok the Harvester", f = "Meshlok le Moissonneur", px = "Rare",
			id = { 17767, 17741, 17742, 60780 },
			rt = { 33, 33, 33, 10 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[4] = 6,
			},
			ct = {
				[4] = { 65022, 0, 15 },
			}
		},
		{ n = "Celebras the Cursed", f = "Celebras le Maudit",
			id = { 17740, 17739, 17738, 17684, 60780, 51217 },
			rt = { 33, 33, 33, 80, 3, 5 },
			fl = { 2, 2, 2, 0, 0, 0 },
			mk = {
				[5] = 6,
				[6] = 6,
			},
			ct = {
				[4] = { 17775, 0, 15, 17776, 0, 15, 17777, 0, 15, 17779, 0, 15 },
				[5] = { 65022, 0, 15 },
			},
			dc = {
				[6] = 60,
			}
		},
		{ n = "Landslide", f = "Glissement de terrain",
			id = { 17734, 17736, 17737, 17943, 17684, 41002, 41356 },
			rt = { 25, 25, 25, 25, 80, 100, 100 },
			fl = { 2, 2, 2, 2, 0, 0, 0 },
			mk = {
				[6] = 6,
				[7] = 6,
			},
			ct = {
				[5] = { 17775, 0, 15, 17776, 0, 15, 17777, 0, 15, 17779, 0, 15 },
				[6] = { 40080, 0, 15 },
			},
			dc = {
				[7] = 17,
			}
		},
		{ n = "Tinkerer Gizlock", f = "Artisan Gizlock",
			id = { 17718, 17717, 17719, 17684, 26000, 50020, 40083, 51809 },
			rt = { 33, 33, 33, 80, 33, 33, 8, 8 },
			fl = { 2, 2, 2, 0, 2, 2, 0, 0 },
			mk = {
				[5] = 8,
				[6] = 8,
				[7] = 6,
				[8] = 6,
			},
			ct = {
				[4] = { 17775, 0, 15, 17776, 0, 15, 17777, 0, 15, 17779, 0, 15 },
				[7] = { 41327, 0, 15 },
				[8] = { 60098, 0, 15 },
			},
			dc = {
				[6] = 50,
			}
		},
		{ n = "Rotgrip", f = "Grippe-charogne",
			id = { 17732, 17728, 17730, 26003, 17684 },
			rt = { 33, 33, 33, 33, 80 },
			fl = { 2, 2, 2, 2, 0 },
			mk = {
				[4] = 8,
			},
			ct = {
				[5] = { 17775, 0, 15, 17776, 0, 15, 17777, 0, 15, 17779, 0, 15 },
			}
		},
		{ n = "Princess Theradras", f = "Princesse Theradras",
			id = { 17780, 17715, 17707, 17714, 17711, 17713, 17710, 17766, 17684, 61458, 50020, 51217 },
			rt = { 1, 14, 14, 14, 14, 14, 14, 14, 80, 100, 14, 5 },
			fl = { 0, 2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 0 },
			mk = {
				[10] = 6,
				[11] = 8,
				[12] = 6,
			},
			ct = {
				[9] = { 17775, 0, 15, 17776, 0, 15, 17777, 0, 15, 17779, 0, 15 },
			},
			dc = {
				[11] = 50,
				[12] = 60,
			}
		},
		{ n = "Elder Splitrock", f = "Ancien Splitrock", px = "Lunar Festival", pg = "LunarFestival" },
		{ n = "Trash Mobs-Maraudon", m = 6,
			id = { 80756, 80753, 80752, 80755, 80749, 80754, 62008, 80750, 80751, 80748, 60780 },
			rt = { 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.5 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0 },
			ct = {
				[11] = { 65022, 0, 15 },
			}
		},
	},
}
