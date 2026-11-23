-- ShikiCodexData\Inst_TheDeadmines.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["TheDeadmines"] = {
	n = "The Deadmines", f = "Les Mortemines", kd = "dungeon", lv = 10, hi = 24, mx = 5, acr = "VC", loc = "Westfall", lf = "Marche de l'Ouest",
	boss = {
		{ n = "Jared Voss", m = 6,
			id = { 55377, 55376, 55375, 41429, 107 },
			rt = { 50, 25, 25, 100, 100 },
			mk = {
				[5] = 4,
			},
			ct = {
				[4] = { 70239, 0, 15, 70240, 0, 15 },
			},
			dc = {
				[5] = 30,
			}
		},
		{ n = "Rhahk'Zor",
			id = { 872, 5187, 80706, 9496 },
			rt = { 5, 95, 50, 100 },
			mk = {
				[3] = 6,
				[4] = 4,
			},
			dc = {
				[4] = 30,
			}
		},
		{ n = "Miner Johnson", f = "Mineur Johnson", px = "Rare",
			id = { 5444, 5443 },
			rt = { 65, 35 }
		},
		{ n = "Sneed",
			id = { 5194, 5195, 80707, 81315, 50256 },
			rt = { 35, 65, 60, 100, 100 },
			mk = {
				[3] = 6,
				[4] = 6,
				[5] = 4,
			},
			ct = {
				[4] = { 81316, 0, 15, 81317, 0, 15 },
			},
			dc = {
				[5] = 30,
			}
		},
		{ n = "Sneed's Shredder", f = "D\195\169chiqueteur de Sneed",
			id = { 1937, 2169, 7365 },
			rt = { 10, 90, 100 },
			ct = {
				[3] = { 7606, 0, 15, 7607, 0, 15 },
			}
		},
		{ n = "Gilnid",
			id = { 1156, 5199 },
			rt = { 45, 55 }
		},
		{ n = "Masterpiece Harvester", m = 6,
			id = { 55380, 55379, 55378 },
			rt = { 50, 25, 25 }
		},
		{ n = "Mr. Smite", f = "M. Smite",
			id = { 7230, 5192, 5196, 81007, 26024 },
			rt = { 20, 30, 30, 20, 1 },
			mk = {
				[4] = 6,
				[5] = 8,
			}
		},
		{ n = "Cookie", f = "Macaron",
			id = { 5198, 5197, 80708, 8490, 60526, 9338 },
			rt = { 35, 65, 60, 15, 100, 100 },
			mk = {
				[3] = 6,
				[5] = 6,
				[6] = 4,
			},
			ct = {
				[5] = { 70070, 0, 15 },
			},
			dc = {
				[6] = 30,
			}
		},
		{ n = "Captain Greenskin", f = "Capitaine Vertepeau",
			id = { 5201, 10403, 5200 },
			rt = { 40, 30, 30 }
		},
		{ n = "Edwin VanCleef",
			id = { 5193, 5202, 10399, 5191, 81005, 2874, 3637, 51217, 29980, 108 },
			rt = { 30, 30, 20, 20, 8, 100, 100, 1, 100, 100 },
			mk = {
				[5] = 6,
				[8] = 6,
				[9] = 4,
				[10] = 4,
			},
			ct = {
				[6] = { 2933, 0, 15 },
				[7] = { 6087, 0, 15, 2041, 0, 15, 2042, 0, 15 },
			},
			dc = {
				[8] = 60,
				[9] = 30,
				[10] = 30,
			}
		},
		{ n = "Trash Mobs-The Deadmines",
			id = { 8492, 80802, 80803, 1943, 10401, 10400, 10402 },
			rt = { 4, 3, 3, 4, 4, 1.75, 1.2 },
			mk = {
				[2] = 6,
				[3] = 6,
				[4] = 6,
				[5] = 6,
				[6] = 6,
				[7] = 6,
			}
		},
		{ n = "Defias Leather", pg = "Deadmines" },
	},
}
