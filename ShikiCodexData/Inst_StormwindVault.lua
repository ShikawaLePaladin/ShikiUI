-- ShikiCodexData\Inst_StormwindVault.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["StormwindVault"] = {
	n = "Stormwind Vault", kd = "dungeon", lv = 58, hi = 60, mx = 5, acr = "SV", m = 6, loc = "Stormwind City", lf = "Cit\195\169 de Stormwind",
	boss = {
		{ n = "Aszosh Grimflame",
			id = { 60504, 60419, 60425, 60434, 60431, 60418, 41985, 70226, 51217 },
			rt = { 17, 17, 17, 17, 17, 17, 100, 1, 5 },
			fl = { 2, 2, 2, 2, 2, 2, 0, 0, 0 },
			mk = {
				[7] = 4,
			},
			ct = {
				[7] = { 41986, 0, 15 },
			},
			dc = {
				[8] = 45,
				[9] = 60,
			}
		},
		{ n = "Tham'Grarr",
			id = { 60502, 60415, 60424, 60435, 60416, 60417, 41985, 70226, 51217 },
			rt = { 17, 17, 17, 17, 17, 17, 100, 1, 5 },
			fl = { 2, 2, 2, 2, 2, 2, 0, 0, 0 },
			mk = {
				[7] = 4,
			},
			ct = {
				[7] = { 41986, 0, 15 },
			},
			dc = {
				[1] = 49,
				[8] = 45,
				[9] = 60,
			}
		},
		{ n = "Black Bride",
			id = { 60408, 60409, 60411, 60436, 60410, 41985, 70226, 51217 },
			rt = { 20, 20, 20, 20, 20, 100, 1, 5 },
			fl = { 2, 2, 2, 2, 2, 0, 0, 0 },
			mk = {
				[6] = 4,
			},
			ct = {
				[6] = { 41986, 0, 15 },
			},
			dc = {
				[7] = 45,
				[8] = 60,
			}
		},
		{ n = "Damian",
			id = { 60421, 60423, 60433, 60500, 60427, 60422, 41985, 70226, 41463, 51217 },
			rt = { 20, 20, 20, 20, 20, 1, 100, 1, 100, 5 },
			fl = { 2, 2, 2, 2, 2, 0, 0, 0, 0, 0 },
			mk = {
				[7] = 4,
			},
			ct = {
				[7] = { 41986, 0, 15 },
				[9] = { 70236, 0, 15 },
			},
			dc = {
				[8] = 45,
				[10] = 60,
			}
		},
		{ n = "Volkan Cruelblade", px = "Optional",
			id = { 60412, 60414, 60432, 60503, 60413, 41985, 70226, 51217 },
			rt = { 20, 20, 20, 20, 20, 100, 1, 5 },
			fl = { 2, 2, 2, 2, 2, 0, 0, 0 },
			mk = {
				[6] = 4,
			},
			ct = {
				[6] = { 41986, 0, 15 },
			},
			dc = {
				[7] = 45,
				[8] = 60,
			}
		},
		{ n = "Arc'tiras / Vault Armory Equipment",
			id = { 40003, 60505, 60506, 60501, 60420, 60426, 60429, 60430, 83570, 41406, 41985, 41700, 51217 },
			rt = { 25, 25, 25, 25, 25, 25, 25, 25, 15, 100, 100, 100, 80 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0 },
			mk = {
				[11] = 4,
			},
			ct = {
				[10] = { 55133, 0, 15, 55134, 0, 15, 55135, 0, 15 },
				[11] = { 41986, 0, 15 },
				[12] = { 41704, 0, 15 },
			},
			qt = {
				[11] = 3,
			},
			dc = {
				[13] = 60,
			}
		},
		{ n = "Trash Mobs-Stormwind Vault",
			id = { 61592, 61590, 61591, 61593, 61563, 61594, 61595 },
			rt = { 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02 },
			fl = { 2, 2, 2, 2, 2, 2, 2 }
		},
	},
}
