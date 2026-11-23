-- ShikiCodexData\Inst_BlackrockMountainEnt.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["BlackrockMountainEnt"] = {
	n = "Blackrock Mountain (Entrance)", f = "Mont Blackrock (Entr\195\169e)", kd = "entrance", lv = 0, hi = 0, mx = 0, loc = "Blackrock Mountain", lf = "Mont Blackrock",
	boss = {
		{ n = "Overmaster Pyron", f = "Grand seigneur Pyron", px = "Wanders",
			id = { 14486, 11446 },
			rt = { 18, 25 },
			ct = {
				[1] = { 14134, 0, 15 },
				[2] = { 12061, 0, 15, 12062, 0, 15, 12065, 0, 15 },
			}
		},
		{ n = "Scarshield Quartermaster", f = "Intendant du Bouclier balafr\195\169", px = "Rare",
			id = { 13254, 13248, 18987 },
			rt = { 3, 3, 100 },
			mk = {
				[3] = 6,
			}
		},
		{ n = "The Behemoth", f = "Le B\195\169h\195\169moth", px = "Rare",
			id = { 11603, 11446 },
			rt = { 99, 25 },
			ct = {
				[2] = { 12061, 0, 15, 12062, 0, 15, 12065, 0, 15 },
			}
		},
	},
}
