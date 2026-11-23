-- ShikiCodexData\Inst_Concavius.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["Concavius"] = {
	n = "Concavius", kd = "world", lv = 1, hi = 60, mx = 40, acr = "Concavius", m = 6, loc = "Desolace", lf = "D\195\169solace",
	boss = {
		{ n = "Concavius",
			id = { 83233, 83234, 83237, 83238, 83239, 83240, 83236 },
			rt = { 17, 17, 17, 17, 17, 17, 100 },
			fl = { 2, 2, 2, 2, 2, 2, 0 },
			ct = {
				[7] = { 7076, 0, 15, 7078, 0, 15, 7080, 0, 15, 7082, 0, 15, 7971, 0, 15, 12361, 0, 15, 12363, 0, 15, 12364, 0, 15, 12800, 0, 15, 11370, 0, 15, 13468, 0, 15, 14256, 0, 15, 15416, 0, 15, 20520, 0, 15 },
			},
			dc = {
				[7] = 8,
			}
		},
	},
}
