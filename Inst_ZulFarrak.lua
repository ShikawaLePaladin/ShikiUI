-- ShikiCodexData\Inst_ZulFarrak.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["ZulFarrak"] = {
	n = "Zul'Farrak", kd = "dungeon", lv = 30, hi = 54, mx = 5, acr = "ZF", loc = "Tanaris", ky = { { n = "Mallet of Zul'Farrak", i = "Gahz'rilla", id = 9240 } },
	boss = {
		{ n = "Antu'sul",
			id = { 9640, 9641, 9639, 9379, 51217, 26001 },
			rt = { 25, 25, 25, 25, 1, 25 },
			fl = { 2, 2, 2, 2, 0, 2 },
			mk = {
				[5] = 6,
				[6] = 8,
			},
			ct = {
				[4] = { 9372, 0, 15 },
			},
			dc = {
				[5] = 60,
			}
		},
		{ n = "Theka the Martyr", f = "Theka le Martyr",
			id = { 10660 },
			rt = { 100 },
			ct = {
				[1] = { 10749, 0, 15, 10750, 0, 15, 10751, 0, 15 },
			}
		},
		{ n = "Witch Doctor Zum'rah", f = "Sorcier-docteur Zum'rah",
			id = { 18083, 18082, 51803, 51217 },
			rt = { 50, 50, 8, 1 },
			fl = { 2, 2, 0, 0 },
			mk = {
				[3] = 6,
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Nekrum Gutchewer", f = "Nekrum M\195\162chetripes",
			id = { 9471 },
			rt = { 100 },
			ct = {
				[1] = { 9651, 0, 15, 9652, 0, 15 },
			}
		},
		{ n = "Shadowpriest Sezz'ziz", f = "Pr\195\170tre des ombres Sezz'ziz",
			id = { 9470, 9473, 9474, 9475, 51217 },
			rt = { 25, 25, 25, 25, 1 },
			fl = { 2, 2, 2, 2, 0 },
			mk = {
				[5] = 6,
			},
			dc = {
				[5] = 60,
			}
		},
		{ n = "Dustwraith", f = "Ame en peine poudreuse", px = "Rare",
			id = { 12471 },
			rt = { 19 }
		},
		{ n = "Sergeant Bly", f = "Sergent Bly",
			id = { 8548 },
			rt = { 100 },
			ct = {
				[1] = { 9533, 0, 15, 9534, 0, 15 },
			}
		},
		{ n = "Sandfury Executioner", f = "Bourreau Sandfury",
			id = { 8444 },
			rt = { 20 }
		},
		{ n = "Chief Ukorz Sandscalp", f = "Chef Ukorz Scalpessable",
			id = { 9479, 9476, 9477, 9478, 11086, 51217, 26016 },
			rt = { 20, 20, 20, 20, 20, 5, 20 },
			fl = { 2, 2, 2, 2, 2, 0, 2 },
			mk = {
				[6] = 6,
				[7] = 8,
			},
			ct = {
				[5] = { 9372, 0, 15 },
			},
			dc = {
				[6] = 60,
			}
		},
		{ n = "Flame of Farrak",
			id = { 41685 },
			rt = { 100 },
			mk = {
				[1] = 4,
			}
		},
		{ n = "Elder Wildmane", f = "Ancienne Wildmane", px = "Lunar Festival", pg = "LunarFestival" },
		{ n = "Hydromancer Velratha", f = "Hydromancienne Velratha",
			id = { 9234, 10661 },
			rt = { 100, 100 },
			ct = {
				[1] = { 9527, 0, 15, 9531, 0, 15 },
				[2] = { 10749, 0, 15, 10750, 0, 15, 10751, 0, 15 },
			}
		},
		{ n = "Gahz'rilla", px = "Summon",
			id = { 9469, 9467, 80747, 8707, 51217, 26002 },
			rt = { 50, 30, 20, 100, 1, false },
			mk = {
				[3] = 6,
				[5] = 6,
				[6] = 8,
			},
			ct = {
				[4] = { 11122, 0, 15 },
			},
			dc = {
				[5] = 60,
			}
		},
		{ n = "Zel'jeb the Ancient", px = "Flame of Farrak", m = 4,
			id = { 58116, 58117, 58118, 58119 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Champion Razjal the Quick", m = 4,
			id = { 58092, 58093, 58094, 58095 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Zerillis", px = "Rare, Wanders",
			id = { 12470 },
			rt = { 19 }
		},
		{ n = "Trash Mobs-Zul'Farrak",
			id = { 9512, 9484, 862, 6440, 9483, 2040, 5616, 9511, 9481, 9480, 9482, 9243, 70167 },
			rt = { 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 2, 0.04 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0 },
			mk = {
				[13] = 6,
			},
			ct = {
				[13] = { 56018, 0, 15 },
			}
		},
	},
}
