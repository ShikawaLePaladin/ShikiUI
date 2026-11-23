-- ShikiCodexData\Inst_UldamanEnt.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["UldamanEnt"] = {
	n = "Uldaman: Entrance", f = "Uldaman (Entr\195\169e)", kd = "entrance", lv = 0, hi = 0, mx = 0, acr = "Uld", loc = "Badlands", lf = "Terres ingrates",
	boss = {
		{ n = "Magregan Deepshadow", px = "Wanders",
			id = { 4635 },
			rt = { 100 },
			ct = {
				[1] = { 4987, 0, 15, 6723, 0, 15 },
			}
		},
		{ n = "Tablet of Ryun'Eh",
			id = { 4631 },
			rt = { 100 },
			ct = {
				[1] = { 4746, 0, 15 },
			}
		},
		{ n = "Krom Stoutarm's Chest",
			id = { 8027 },
			rt = { 100 }
		},
		{ n = "Garrett Family Chest",
			id = { 8026 },
			rt = { 100 }
		},
		{ n = "Digmaster Shovelphlange", f = "Ma\195\174tre des fouilles Shovelphlange", px = "Rare, Varies",
			id = { 9375, 9378, 9382 },
			rt = { 10, 15, 65 }
		},
	},
}
