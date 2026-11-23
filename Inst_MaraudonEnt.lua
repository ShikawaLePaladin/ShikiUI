-- ShikiCodexData\Inst_MaraudonEnt.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["MaraudonEnt"] = {
	n = "Maraudon (Entrance)", f = "Maraudon (Entr\195\169e)", kd = "entrance", lv = 0, hi = 0, mx = 0, acr = "Mara", loc = "Desolace", lf = "D\195\169solace",
	boss = {
		{ n = "The Nameless Prophet", f = "Le Proph\195\168te sans nom",
			id = { 17757 },
			rt = { 100 },
			ct = {
				[1] = { 17774, 0, 15 },
			}
		},
		{ n = "Kolk",
			id = { 17761 },
			rt = { 100 },
			ct = {
				[1] = { 17774, 0, 15 },
			},
			dc = {
				[1] = 45,
			}
		},
		{ n = "Gelk",
			id = { 17762 },
			rt = { 100 },
			ct = {
				[1] = { 17774, 0, 15 },
			},
			dc = {
				[1] = 45,
			}
		},
		{ n = "Magra",
			id = { 17763 },
			rt = { 100 },
			ct = {
				[1] = { 17774, 0, 15 },
			},
			dc = {
				[1] = 45,
			}
		},
	},
}
