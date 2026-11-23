-- ShikiCodexData\Inst_HateforgeQuarry.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["HateforgeQuarry"] = {
	n = "Hateforge Quarry", kd = "dungeon", lv = 48, hi = 60, mx = 5, acr = "HQ", m = 6, loc = "Burning Steppes", lf = "Steppes ardentes",
	boss = {
		{ n = "High Foreman Bargul Blackhammer",
			id = { 60566, 60569, 60567, 60568, 60570, 60565, 60775, 41985, 41460, 61462, 70226, 51217 },
			rt = { 20, 20, 20, 20, 15, 20, 15, 100, 100, 100, 1, 5 },
			fl = { 2, 2, 2, 2, 0, 2, 0, 0, 0, 0, 0, 0 },
			mk = {
				[8] = 4,
			},
			ct = {
				[8] = { 41986, 0, 15 },
				[10] = { 61465, 0, 15 },
			},
			dc = {
				[7] = 2,
				[11] = 45,
				[12] = 60,
			}
		},
		{ n = "Gemology Plans",
			id = { 56106 },
			rt = { 100 },
			ct = {
				[1] = { 56109, 0, 15, 70166, 0, 15, 56014, 0, 15 },
			},
			dc = {
				[1] = 17,
			}
		},
		{ n = "Engineer Figgles",
			id = { 60540, 60542, 60541, 60543, 60545, 60539, 13325, 70226, 51217 },
			rt = { 20, 20, 20, 20, 20, 15, 0.025, 1, 5 },
			fl = { 2, 2, 2, 2, 2, 0, 0, 0, 0 },
			dc = {
				[8] = 45,
				[9] = 60,
			}
		},
		{ n = "Corrosis",
			id = { 80672, 80673, 80670, 80671, 41003, 80674 },
			rt = { 20, 20, 20, 20, 100, 20 },
			fl = { 2, 2, 2, 2, 0, 2 },
			ct = {
				[5] = { 40080, 0, 15 },
			}
		},
		{ n = "Hatereaver Annihilator",
			id = { 60562, 60564, 60563, 60561, 60559, 60560, 70226, 51217 },
			rt = { 20, 20, 20, 20, 20, 15, 1, 5 },
			fl = { 2, 2, 2, 2, 2, 0, 0, 0 },
			dc = {
				[7] = 45,
				[8] = 60,
			}
		},
		{ n = "Har'gesh Doomcaller",
			id = { 51045, 51047, 51048, 51046, 60549, 60548, 60550, 60547, 60546, 60551, 41985, 70226, 51217 },
			rt = { 25, 25, 25, 25, 20, 20, 20, 20, 20, 1.2, 100, 3, 100 },
			fl = { 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
			mk = {
				[11] = 4,
			},
			ct = {
				[11] = { 41986, 0, 15 },
				[12] = { 70227, 0, 15, 70228, 0, 15, 70229, 0, 15, 70230, 0, 15, 70231, 0, 15, 70232, 0, 15, 70233, 0, 15, 70234, 0, 15, 70235, 0, 15, 70236, 0, 15, 70238, 0, 15 },
			},
			dc = {
				[12] = 45,
				[13] = 60,
			}
		},
		{ n = "Trash Mobs-Hateforge Quarry",
			id = { 84010, 84011, 84012, 84013, 84014, 84015, 60616, 60582, 60572, 60612 },
			rt = { 0.005, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005, 0.1, 0.0025 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 0, 0 },
			ct = {
				[1] = { 60576, 0, 15 },
				[2] = { 60578, 0, 15 },
				[3] = { 60577, 0, 15 },
				[4] = { 60574, 0, 15 },
				[5] = { 60573, 0, 15 },
				[6] = { 60575, 0, 15 },
			},
			dc = {
				[9] = 37,
			}
		},
		{ n = "Incendosaur Skin Armor", pg = "IncendosaurSkinArmor" },
	},
}
