-- t_boot2 : premier lancement (base vide) et personnage sans profil memorise.
local SUI = ShikiUI
local C = SUI.Config
SECTION("t_boot2 : premier lancement")
BOOT()
EQ("base creee", type(ShikiUIDB), "table")
EQ("profil par defaut", C.curName, "Default")
EQ("premier lancement", C.GetGlobal("firstRun"), true)
EQ("langue par defaut", SUI.locale, "fr")
EQ("pas d'assistant avant le delai", SUI.Menu.wiz, nil)
Pump(1.4)
EQ("toujours pas a 1,4 s", SUI.Menu.wiz, nil)
Pump(0.3)
T("assistant a 1,5 s", SUI.Menu.wiz ~= nil and SUI.Menu.wiz:IsShown())
EQ("profil memorise pour ce personnage", ShikiUIDB.chars["Shikiwa-TestRealm"], "Default")
EQ("aucune erreur", SUI.errCount, 0)
-- deuxieme connexion dans la meme session de test : l'assistant n'est plus propose
SUI.Menu.WizFinish()
EQ("firstRun efface", ShikiUIDB.global.firstRun, false)
DONE()
