-- ShikiCodexData\Inst_Uldaman.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["Uldaman"] = {
	n = "Uldaman", kd = "dungeon", lv = 30, hi = 51, mx = 5, acr = "Uld", loc = "Badlands", lf = "Terres ingrates", ky = { { n = "Staff of Prehistoria", i = "Ironaya", id = 7733 } },
	boss = {
		{ n = "Baelog",
			id = { 9401, 9400, 9399 },
			rt = { 50, 50, 100 },
			fl = { 2, 2, 0 },
			qt = {
				[3] = 175,
			}
		},
		{ n = "Eric \"The Swift\"", f = "Eric \"l'Agile\"",
			id = { 9394, 9398, 2459 },
			rt = { 50, 50, 100 },
			fl = { 2, 2, 0 },
			dc = {
				[3] = 7,
			}
		},
		{ n = "Olaf",
			id = { 9404, 9403, 1177 },
			rt = { 50, 50, 100 },
			fl = { 2, 2, 0 },
			dc = {
				[3] = 7,
			}
		},
		{ n = "Baelog's Chest",
			id = { 7740 },
			rt = { 100 },
			ct = {
				[1] = { 7733, 0, 15 },
			},
			dc = {
				[1] = 33,
			}
		},
		{ n = "Revelosh",
			id = { 9389, 9388, 9390, 9387, 7741 },
			rt = { 25, 25, 25, 25, 100 },
			fl = { 2, 2, 2, 2, 0 },
			ct = {
				[5] = { 7733, 0, 15 },
			},
			dc = {
				[5] = 33,
			}
		},
		{ n = "Ironaya", px = "Summon",
			id = { 9409, 9407, 9408, 51217 },
			rt = { 33, 33, 33, 1 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Ancient Stone Keeper", f = "Ancien Gardien des pierres",
			id = { 9410, 9411, 80746 },
			rt = { 50, 50, 30 },
			fl = { 2, 2, 0 },
			mk = {
				[3] = 6,
			}
		},
		{ n = "Galgann Firehammer",
			id = { 11310, 9412, 11311, 9419 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Tablet of Will",
			id = { 5824 },
			rt = { 100 },
			ct = {
				[1] = { 6723, 0, 15 },
			}
		},
		{ n = "Shadowforge Cache",
			id = { 7669 },
			rt = { 100 },
			ct = {
				[1] = { 7888, 0, 15 },
			}
		},
		{ n = "Grimlok",
			id = { 9415, 9416, 9414, 51217, 26015 },
			rt = { 33, 33, 33, 1, 1 },
			fl = { 2, 2, 2, 0, 0 },
			mk = {
				[4] = 6,
				[5] = 8,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Archaedas", px = "Lower",
			id = { 11118, 9413, 9418, 51217, 26004, 9417, 26014, 26005 },
			rt = { 33, 33, 33, 5, 1, 1, 1, 1 },
			fl = { 2, 2, 2, 0, 0, 0, 0, 0 },
			mk = {
				[4] = 6,
				[5] = 8,
				[6] = 8,
				[7] = 8,
				[8] = 8,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Trash Mobs-Uldaman",
			id = {
				9431, 9429, 80810, 9420, 9430, 9397, 9406, 9428, 9432, 9396, 9393, 7666, 9381, 9426, 9422, 9465,
				9384, 9386, 9427, 9392, 9424, 9383, 9425, 9423, 9391,
			},
			rt = {
				0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 100, 0.01, 0.01, 0.01, 0.01, 0.01,
				0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01,
			},
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 },
			mk = {
				[3] = 6,
			},
			ct = {
				[12] = { 7673, 0, 15 },
			}
		},
	},
}
