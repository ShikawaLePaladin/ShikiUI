-- ShikiCodexData\Inst_RagefireChasm.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["RagefireChasm"] = {
	n = "Ragefire Chasm", f = "Gouffre de Ragefeu", kd = "dungeon", lv = 8, hi = 18, mx = 5, acr = "RFC", loc = "Orgrimmar",
	boss = {
		{ n = "Oggleflint", f = "Lorgnesilex", m = 6,
			id = { 80700, 80701, 80702, 17041 },
			rt = { 35, 35, 30, 100 },
			dc = {
				[4] = 29,
			}
		},
		{ n = "Taragaman the Hungerer", f = "Taragaman l'Affameur",
			id = { 14149, 14148, 14145, 14540, 5235 },
			rt = { 33, 33, 33, 100, 100 },
			fl = { 2, 2, 2, 0, 0 },
			mk = {
				[4] = 6,
				[5] = 6,
			},
			dc = {
				[5] = 29,
			}
		},
		{ n = "Jergosh the Invoker", f = "Jergosh l'Invocateur",
			id = { 14150, 14147, 14151, 55004, 80111 },
			rt = { 33, 33, 33, 25, 25 },
			fl = { 2, 2, 2, 0, 0 },
			mk = {
				[4] = 6,
				[5] = 6,
			},
			dc = {
				[4] = 29,
				[5] = 29,
			}
		},
		{ n = "Bazzalan",
			id = { 5212, 80705, 80704, 80703, 64, 51217 },
			rt = { 25, 30, 30, 30, 100, 1 },
			fl = { 0, 2, 2, 2, 0, 0 },
			mk = {
				[2] = 6,
				[3] = 6,
				[4] = 6,
				[5] = 6,
				[6] = 6,
			},
			dc = {
				[5] = 29,
				[6] = 60,
			}
		},
		{ n = "Trash Mobs-Ragefire Chasm",
			id = { 14395, 14396, 12862 },
			rt = { 25, 25, 25 },
			fl = { 2, 2, 2 },
			mk = {
				[3] = 6,
			},
			ct = {
				[1] = { 15449, 0, 15, 15450, 0, 15, 15451, 0, 15 },
				[2] = { 15449, 0, 15, 15450, 0, 15, 15451, 0, 15 },
			},
			dc = {
				[3] = 29,
			}
		},
	},
}
