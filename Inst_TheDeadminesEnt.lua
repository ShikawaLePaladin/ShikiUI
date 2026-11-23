-- ShikiCodexData\Inst_TheDeadminesEnt.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["TheDeadminesEnt"] = {
	n = "The Deadmines (Entrance)", f = "Les Mortemines (Entr\195\169e)", kd = "entrance", lv = 0, hi = 0, mx = 0, acr = "DM", loc = "Westfall", lf = "Marche de l'Ouest",
	boss = {
		{ n = "Marisa du'Paige", px = "Rare, Varies",
			id = { 3019, 4660 },
			rt = { 25, 75 }
		},
		{ n = "Brainwashed Noble", f = "Noble manipul\195\169", px = "Rare",
			id = { 5967, 3902 },
			rt = { 64, 26 }
		},
		{ n = "Foreman Thistlenettle", f = "Contrema\195\174tre Crispechardon",
			id = { 1875 },
			rt = { 100 },
			ct = {
				[1] = { 1893, 0, 15 },
			}
		},
	},
}
