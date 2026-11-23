-- ShikiCodexData\Inst_BGAlteracValleyNorth.lua - FICHIER GENERE par tools/build_codex_data.js : ne pas modifier a la main (relancer l'outil).
-- Sources : Atlas-CFM_Core 1.87 (GPL v2, auteur : CFM et contributeurs) ; pfQuest 8.0.0 (MIT, Eric Mauser "Shagu") ; pfQuest-octo-plus 1.0.0 (MIT, contributeurs de pfQuest-octo).
-- Licence de ce fichier : GPL v2 (voir LICENSE et NOTICE.txt dans ce dossier). Format : FORMAT.md.
local D = ShikiCodexData
D.inst["BGAlteracValleyNorth"] = {
	n = "Alterac Valley (North)", f = "Vall\195\169e d'Alterac (Nord)", kd = "bg", lv = 51, hi = 60, mx = 40, acr = "AV", loc = "Alterac Mountains", lf = "Montagnes d'Alterac", rp = { "StormpikeFrostwolf" },
	boss = {
		{ n = "Korrak the Bloodrager", f = "Korrak le Ragesang",
			id = { 13080, 12970, 12686, 21135, 17108 }
		},
		{ n = "Ivus the Forest Lord (Summon)",
			id = { 19105, 19113, 19111, 19112, 19109, 19110 }
		},
	},
}
