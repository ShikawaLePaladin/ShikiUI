-- ShikiCodexData\Inst_RazorfenDowns.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["RazorfenDowns"] = {
	n = "Razorfen Downs", f = "Souilles de Tranchebauge", kd = "dungeon", lv = 25, hi = 46, mx = 5, acr = "RFD", loc = "The Barrens", lf = "Les Tarides",
	boss = {
		{ n = "Tuten'kash",
			id = { 10776, 10775, 10777, 51217 },
			rt = { 33, 33, 33, 1 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Henry Stern",
			id = { 3826, 10841 },
			dc = {
				[1] = 7,
				[2] = 7,
			}
		},
		{ n = "Lady Falther'ess", f = "Dame Falther'ess", px = "Scourge Invasion",
			id = { 23178, 23177 },
			rt = { 50, 50 },
			fl = { 2, 2 }
		},
		{ n = "Plaguemaw the Rotting", f = "Pestegueule le Pourrissant",
			id = { 10766, 10760, 80744, 51217 },
			rt = { 33, 33, 33, 1 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[3] = 6,
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Mordresh Fire Eye", f = "Mordresh Oeil-de-feu",
			id = { 10769, 10771, 10770, 51217 },
			rt = { 33, 33, 33, 1 },
			fl = { 2, 2, 2, 0 },
			mk = {
				[4] = 6,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Glutton", f = "Glouton",
			id = { 10774, 10772, 80745, 51217, 26008, 26009 },
			rt = { 33, 33, 33, 1, 1, 1 },
			fl = { 2, 2, 2, 0, 0, 0 },
			mk = {
				[3] = 6,
				[4] = 6,
				[5] = 8,
				[6] = 8,
			},
			dc = {
				[4] = 60,
			}
		},
		{ n = "Death Prophet Rakameg", m = 6,
			id = { 58172, 58173, 58174, 58175 },
			rt = { 25, 25, 25, 25 },
			fl = { 2, 2, 2, 2 }
		},
		{ n = "Ragglesnout", f = "Groinfendu", px = "Rare",
			id = { 10768, 10767, 10758 },
			rt = { 33, 33, 33 },
			fl = { 2, 2, 2 }
		},
		{ n = "Amnennar the Coldbringer", f = "Amnennar le Porte-froid",
			id = { 10763, 10762, 10764, 10761, 10765, 10420, 61657, 51217 },
			rt = { 20, 20, 20, 20, 20, 20, 20, 5 },
			fl = { 2, 2, 2, 2, 2, 2, 2, 0 },
			mk = {
				[7] = 6,
				[8] = 6,
			},
			ct = {
				[6] = { 10823, 0, 15, 10824, 0, 15 },
				[7] = { 61660, 0, 15, 61661, 0, 15, 61662, 0, 15 },
			},
			dc = {
				[8] = 60,
			}
		},
		{ n = "Trash Mobs-Razorfen Downs",
			id = { 10574, 10581, 10583, 10584, 10578, 10582, 10572, 10567, 10571, 10570, 10573 },
			rt = { 0.01, 0.02, 0.01, 0.02, 0.01, 0.02, 0.01, 0.02, 0.01, 0.01, 0.01 },
			fl = { 2, 0, 2, 0, 2, 0, 2, 0, 2, 2, 2 }
		},
	},
}
