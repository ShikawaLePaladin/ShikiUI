-- ShikiCodexData\Inst_ShadowfangKeep.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["ShadowfangKeep"] = {
	n = "Shadowfang Keep", f = "Donjon d'Ombrecroc", kd = "dungeon", lv = 14, hi = 30, mx = 5, acr = "SFK", loc = "Silverpine Forest", lf = "For\195\170t des Pins argent\195\169s",
	boss = {
		{ n = "Rethilgore",
			id = { 5254, 80713, 80714 },
			rt = { 100, 35, 35 },
			fl = { 0, 2, 2 },
			mk = {
				[2] = 6,
				[3] = 6,
			}
		},
		{ n = "Fel Steed", f = "Palefroi corrompu",
			id = { 6341, 932 },
			rt = { 8, 29 }
		},
		{ n = "Jordan's Hammer",
			id = { 6895 },
			rt = { 100 },
			ct = {
				[1] = { 6953, 0, 15 },
			}
		},
		{ n = "Razorclaw the Butcher", f = "Tranchegriffe le Boucher",
			id = { 6226, 6633, 1292 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Baron Silverlaine", f = "Baron d'Argelaine",
			id = { 6321, 6323, 80715 },
			rt = { 50, 50, 35 },
			fl = { 2, 2, 0 },
			mk = {
				[3] = 6,
			}
		},
		{ n = "Commander Springvale", f = "Commandant Springvale",
			id = { 6320, 3191, 80717 },
			rt = { 50, 50, 35 },
			fl = { 2, 2, 0 },
			mk = {
				[3] = 6,
			}
		},
		{ n = "Sever", f = "Sectionneur", px = "Scourge Invasion",
			id = { 23173, 23171 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Odo the Blindwatcher", f = "Odo l'Aveugle",
			id = { 6319, 6318 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Deathsworn Captain", f = "Capitaine Ligemort", px = "Rare",
			id = { 6642, 6641 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Fenrus the Devourer", f = "Fenrus le D\195\169voreur",
			id = { 6340, 3230 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Arugal's Voidwalker", f = "Marcheur du Vide d\226\128\153Arugal",
			id = { 5943 },
			rt = { 3 }
		},
		{ n = "The Book of Ur",
			id = { 6283 },
			rt = { 100 },
			ct = {
				[1] = { 6335, 0, 15, 4534, 0, 15 },
			}
		},
		{ n = "Wolf Master Nandos", f = "Ma\195\174tre-loup Nandos",
			id = { 3748, 6314, 80716 },
			rt = { 50, 50, 35 },
			fl = { 2, 2, 0 },
			mk = {
				[3] = 6,
			}
		},
		{ n = "Archmage Arugal", f = "Archimage Arugal",
			id = { 6324, 6392, 6220, 5442, 51217 },
			rt = { 33, 33, 33, 100, 1 },
			fl = { 2, 2, 2, 0, 0 },
			mk = {
				[5] = 6,
			},
			ct = {
				[4] = { 6414, 0, 15 },
			},
			dc = {
				[5] = 60,
			}
		},
		{ n = "Prelate Ironmane", m = 6,
			id = { 55385, 55384, 55383, 55382 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Trash Mobs-Shadowfang Keep",
			id = { 2292, 1489, 1974, 2807, 1482, 1935, 1483, 1318, 3194, 2205, 1484, 41420 },
			rt = { 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 0.07, 10 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0 },
			mk = {
				[12] = 6,
			},
			ct = {
				[12] = { 55505, 0, 15 },
			}
		},
	},
}
