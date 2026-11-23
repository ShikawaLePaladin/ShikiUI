-- ShikiCodexData\Inst_Azuregos.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["Azuregos"] = {
	n = "Azuregos", kd = "world", lv = 1, hi = 60, mx = 40, acr = "AZ", loc = "Azshara",
	boss = {
		{ n = "Azuregos",
			id = {
				19132, 18208, 18541, 18547, 18545, 19131, 19130, 17070, 18202, 18542, 18704, 83544, 26018, 26019,
				26021,
			},
			rt = { 10, 10, 12, 10, 10, 10, 10, 10, 10, 10, 100, 40, 10, 10, 10 },
			fl = { 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 2, 2 },
			mk = {
				[12] = 6,
				[13] = 8,
				[14] = 8,
				[15] = 8,
			},
			ct = {
				[11] = { 18714, 0, 15 },
				[12] = { 65006, 0, 15 },
			},
			dc = {
				[11] = 45,
			}
		},
		{ n = "Spirit of Azuregos", f = "Esprit d'Azuregos",
			id = { 20949 },
			ct = {
				[1] = { 21526, 0, 15, 21527, 0, 15 },
			}
		},
	},
}
