-- ShikiCodexData\Inst_RareMobs.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["RareMobs"] = {
	n = "Rare Mobs", kd = "world", lv = 1, hi = 60, mx = 0, m = 6, loc = "Various Locations",
	boss = {
		{ n = "Shade Mage", px = "0.4k (17L) Tirisfal Glades [15, 68]",
			id = { 61500, 61501 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Graypaw Alpha", px = "0.7k (18L) Tirisfal Glades [27, 58]",
			id = { 60492, 60493 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Earthcaller Rezengal", px = "0.4k (18L) Stonetalon Mountains [74, 79]",
			id = { 61502, 61503 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Blazespark", px = "0.8k (24L) Stonetalon Mountains [21, 29]",
			id = { 61504, 61505 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Witch Doctor Tan'zo", px = "2k (35L) Arathi Highlands [44, 13]",
			id = { 61507, 61506, 61508 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Dawnhowl", px = "2k (40L) Gilneas [43, 23]",
			id = { 61580, 61581, 61582 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Widow of the Woods", px = "6k (40L) Gilneas [30, 50]",
			id = { 61575, 61576, 61589 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Maltimor's Prototype", px = "6k (43L) Gilneas [48, 57]",
			id = { 61573, 61574, 61572 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Bonecruncher", px = "2k (44L) Gilneas [54, 56]",
			id = { 61583, 61584, 61585 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Duskskitterer", px = "2k (44L) Gilneas [46, 78]",
			id = { 61610, 61611, 61612 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Baron Perenolde", px = "3k (45L) Gilneas [67, 80]",
			id = { 61577, 61578 },
			rt = { 33, 33 },
			fl = { 2, 2 }
		},
		{ n = "Kin'Tozo", px = "20k (45L) Stranglethorn Vale [27, 55]",
			id = { 60438, 60439, 60440, 60441, 60442 },
			rt = { 25, 25, 25, 25, 2 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Grug'thok the Seer", px = "15k (47L) Feralas [58, 71]",
			id = { 81380, 81381, 81382, 81383, 81384 },
			rt = { 25, 25, 25, 25, 0.5 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Explorer Ashbeard", px = "16k (49L) Searing Gorge [71, 18]",
			id = { 83275, 83276, 83277, 83278, 83279 },
			rt = { 0.5, 25, 25, 25, 25 },
			fl = { 0, 2, 2, 2, 2 }
		},
		{ n = "Jal'akar", px = "18k (50L) The Hinterlands [53, 34]",
			id = { 51023, 51024, 51025, 83273, 83274 },
			rt = { 25, 25, 25, 25, 0.5 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Ripjaw", px = "9k (51L) Lapidis Isle [55, 21]",
			id = { 61535, 61536, 61537 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Ruk'thok the Pyromancer", px = "3k (51L) Lapidis Isle [43, 29]",
			id = { 61613, 61614, 61615 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Embereye", px = "4k (51L) Gillijim's Isle [67, 69]",
			id = { 61538, 61539, 61540 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Xalvic Blackclaw", px = "19k (53L) Felwood [53, 29]",
			id = { 81370, 81371, 81372, 81373, 81374 },
			rt = { 25, 25, 25, 25, 0.5 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Firstborn of Arugal", px = "10k (55L) Gilneas [40, 37]",
			id = { 61586, 61587, 61588 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Margon the Mighty", px = "25k (55L) Lapidis Isle [30, 41]",
			id = { 61531, 61532, 61534, 61533 },
			rt = { 33, 33, 33, 2 },
			fl = { 2, 2, 2, 0 }
		},
		{ n = "The Wandering Knight", px = "22k (55L) Western Plaguelands [64, 74]",
			id = { 83257, 83258, 83259, 83260 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Letashaz", px = "25k (55L) Gillijim's Isle [29, 89]",
			id = { 61542, 61543, 61544, 61541 },
			rt = { 33, 33, 33, 2 },
			fl = { 2, 2, 2, 0 }
		},
		{ n = "Aquitus", px = "7k (56L) Gillijim's Isle [27, 70]",
			id = { 61529, 61530, 61528 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Stoneshell", px = "4k (56L) Tel'Abim [40, 47]",
			id = { 61509, 61510, 61511 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Tarangos", px = "23k (56L) Azshara [42, 80]",
			id = { 81360, 81361, 81362, 81364 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Zareth Terrorblade", px = "23k (57L) Blasted Lands [55, 59]",
			id = { 83265, 83266, 83267, 83268, 83269 },
			rt = { 25, 25, 25, 25, 0.5 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Highvale Silverback", px = "4k (58L) Tel'Abim [57, 48]",
			id = { 61518, 61519, 61520 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Mallon The Moontouched", px = "27k (58L) Winterspring [57, 61]",
			id = { 81375, 81376, 81377, 81378, 81379 },
			rt = { 25, 25, 25, 25, 0.5 },
			fl = { 2, 2, 2, 2, 0 }
		},
		{ n = "Professor Lysander", px = "9k (59L) Western Plaguelands [12, 50]",
			id = { 41060, 41061, 41062, 41063 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Blademaster Kargron", px = "28k (59L) Burning Steppes [45, 32]",
			id = { 81365, 81367, 81368, 81369 },
			rt = { 25, 25, 25, 0.5 },
			fl = { 2, 2, 2, 0 }
		},
		{ n = "Azurebeak", px = "20k (60L) Hyjal [23, 37]",
			id = { 61550, 61551, 61549 },
			rt = { 40, 40, 20 },
			fl = { 2, 2, 0 }
		},
		{ n = "Barkskin Fisher", px = "5k (60L) Hyjal [66, 53]",
			id = { 84507 },
			rt = { 100 }
		},
		{ n = "Admiral Barean Westwind", px = "141k (60L) Eastern Plaguelands [66, 42]",
			id = { 60383, 60384, 60385, 60386, 60387, 60388, 60389, 60390 },
			rt = { 17, 17, 17, 17, 17, 17, 15, 15 },
			fl = { 2, 2, 2, 2, 2, 2, 0, 0 }
		},
		{ n = "Shadeflayer Goliath", px = "17k (61L) Hyjal [10, 44]",
			id = { 61546, 61548, 61545, 61547 },
			rt = { 30, 30, 20, 20 },
			fl = { 2, 2, 0, 0 }
		},
		{ n = "Crusader Larsarius", px = "28k (61L) Eastern Plaguelands [47, 60]",
			id = { 60437, 83263, 83264, 83261, 83262 },
			rt = { 0.2, 25, 25, 25, 25 },
			fl = { 0, 2, 2, 2, 2 }
		},
	},
}
