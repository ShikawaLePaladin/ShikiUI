fait (defaut coupe, non verifie en jeu) |fait (defaut coupe, non verifie en jeu) |fait (defaut coupe, non verifie en jeu) |fait (defaut coupe, non verifie en jeu) |# ShikiUI - Conventions pour les agents de modules (v0.3.0)

But : plusieurs agents ecrivent des modules EN PARALLELE sans jamais se marcher dessus. Un module = un jeu de fichiers a lui, rien d'autre.
Demarrer : `node tools/newmodule.js <Nom>` (copie le modele `docs/template/`, regenere le .toc). Controle : `sh tests/run_tests.sh` puis `node tests/mutate.js <nom>`.

## Fichiers qu'un module PEUT creer / modifier (et seulement eux)

| Fichier | Role |
|---|---|
| `ShikiUI/Mod_<Nom>.lua` | le module (`SUI.RegisterModule("<nom>", {...})`) |
| `ShikiUI/Locale_<Nom>.lua` | ses textes fr + en via `SUI.AddStrings` (cles `mod.<nom>.*`, `opt.<nom>.*`, `choice.<nom>.*`, `msg.<nom>.*`) |
| `ShikiUI/Style_<Nom>.lua` | (optionnel) un style de plus via `SUI.RegisterStyle`, cles `style.<nom>.label` / `.desc` |
| `tests/t_<nom>.lua` | sa suite de tests |
| `tests/mock_<nom>.lua` | son extension de la simulation (chargee automatiquement par le harnais) |
| `tests/mutations/<nom>.js` | ses mutations (tout mutant doit etre tue, aucun motif introuvable) |
| `MODULES.md` | UNIQUEMENT sa propre ligne dans la table ci-dessous (statut) |

Le `.toc` est GENERE (`node tools/gen_toc.js`) : ne jamais l'editer a la main.

## Fichiers qu'un module ne doit JAMAIS modifier

`Core.lua`, `Config.lua`, `Locale.lua`, `Locale_Mode.lua`, `Locale_Target.lua`, `Locale_Style.lua`, `Locale_Layout.lua`, `Cmd.lua`, `Menu.lua`, `StyleUI.lua`,
`Theme.lua`, `Style.lua`, `Style_Shiki.lua` et les styles livres, `Layouts.lua`, `Mode.lua`, `Target.lua`, `Api.lua`, `Migrate.lua`, `Serial.lua`, `Perf.lua`, `Units.lua`,
`Mover.lua`, `Bind.lua`, `Addons.lua`, `GameMenu.lua` (et leurs `Locale_*`), `Menu_Pages.lua`,
le `.toc` genere, la liste CORE de `tools/gen_toc.js`, `tests/harness.js`, `tests/run_tests.sh`, `tests/mutate.js`, `tests/mock_wow.lua`, `tests/mock_addons.lua`,
`tests/mock_target.lua`, `tests/lib_test.lua`, `tests/lint50.js`, `tests/check_*.js`, les tests et mutations des autres modules, `SPEC.md`, `PARITY.md`.
Besoin d'un changement du socle : le dire dans le rapport (pas de contournement).

## Contrat d'un module

1. `SUI.RegisterModule(nom, { cost = "light|medium|heavy", init, enable, disable, shutdown, options, raid = "off"? })` : `cost` OBLIGATOIRE ; nom `^[a-z][a-z0-9]*$`, hors noms reserves (`style`, `layout`, `mode`, `target`...).
2. Reglages : cles `<nom>.<reglage>` (espace de noms du module), declares via `options` (donc menu Simple/Expert + recherche + bouton "reinitialiser" automatiques). Pas de cle hors de son espace.
3. Textes : tout par `SUI.L("cle")` ; fr ET en ; parite controlee par `check_locale.js`. ASCII strict, sans BOM.
4. Aspect : JAMAIS de couleur, police ou texture en dur dans `Mod_*.lua` : `T.c.<jeton>`, `T.Backdrop/Panel/Text/Button/Bar...` (controle par `check_style.js` ; exception `-- style:ok <raison>` sur la meme ligne, reservee aux donnees du JEU : couleur de classe, de ressource, de qualite).
   Les widgets crees par les fabriques du Theme sont repeints automatiquement au changement de style (`T.Restyle`, differe hors combat) ; un dessin maison s'abonne avec `T.OnAccent(fn)` et relit `T.c.*`. Textures/polices : noms enregistres (`SUI.RegisterAsset`), chemins du jeu ou fichiers de l'utilisateur seulement.
5. Positions : `SUI.Layout.Register(frame, cle, ancre, x, y)` ; les mises en page (`Layouts.lua`) ecrivent ces positions : ne jamais coder de position fixe qui les contredirait. Un cadre deplacable se declare AUSSI au service de deplacement : `SUI.Mover.Register(id, frame, { label = "cle ou texte", point, x, y, scale = false?, preview = fn(on), ghost = { n, cols, rows, cw, ch }, always = true? })` (poignee nommee, aimantation, panneau X/Y, "Montrer tout") ; jamais de poignee, de fond de deverrouillage ou de glisser-deposer personnels. Boutons a raccourci : `SUI.Bind.AddResolver(function(frame) return commande, libelle end)` et `SUI.Bind.Watch(function(on) end)` ; jamais de capture clavier personnelle.
6. Modes Normal/Raid : un module qui doit se comporter autrement en raid declare `Cfg.AddPreset("raid", ...)` pour SES cles (priorite : ecart utilisateur > preset role+classe > classe > role > "*" > module `raid="off"` > profil > defaut).
7. Cibles : `SUI.Target` (unite, GUID, distance, ligne de vue, cache) ; ne pas dupliquer les appels SuperWoW/Nampower/UnitXP.
8. Commandes : `SUI.RegisterCommand(nom, fn)` (sous `/sui <nom>`), jamais de `SLASH_*` personnel.
9. Performance : aucun `OnUpdate` personnel (`SUI.Every/After/Cancel`) ; aucune frame ni table creee en combat (`SUI.WhenSafe`) ; ecrire un texte seulement s'il change ; un module desactive ne coute rien.
10. Lua 5.0 : pas de `#`, `%`, `...`, `select`, `string.match` ; `SUI.Mod(a,m)` ; au plus 32 upvalues par fonction ; pas de globale (le harnais refuse toute globale non declaree).
11. Sauvegardes : ne rien ecrire dans `ShikiUIDB` en dehors de `Config` (cles declarees) ; jamais de fonction/frame dans la base.

## Modules reserves (nom, ordre de categorie du menu, statut)

Ordres du socle : general 1, units 2, perf 3, mode 4, style 5, layout 6, modules 9. Les modules prevus partent de 20 ; ordres uniques.

| nom | ordre | statut |
|---|---|---|
| actionbars | 20 | fait (defaut coupe, non verifie en jeu) |
| bags | 21 | fait (defaut coupe, non verifie en jeu ; affichage grille ou par categories reduisibles, memoire des sacs/banque/argent par personnage (ShikiUIDB.global.bagcache), vue hors-ligne en lecture seule, bouton Tout deposer, engrenage et infobulles) |
| chat | 22 | libre |
| minimap | 23 | libre |
| nameplates | 24 | fait (defaut coupe, non verifie en jeu) |
| castbar | 25 | fait (defaut coupe, non verifie en jeu) |
| auras | 26 | fait (defaut coupe, non verifie en jeu) |
| group | 27 | fait (defaut coupe, non verifie en jeu ; moteur partage SUI.GroupEngine, groupe + ennemis epingles) |
| tooltip | 28 | fait (defaut actif, non verifie en jeu ; style, ancre, couleurs, cible de la cible, ID, niveau d objet, prix marchand, ligne Possede lue dans bagcache ecrit par bags) |
| items | 29 | fait (defaut coupe, non verifie en jeu ; jeux d'equipement, echange par evenement, barre de bijoux) |
| loot | 30 | fait (defaut coupe, non verifie en jeu ; fenetre de jets, regles par objet/qualite, historique) |
| social | 31 | fait (defaut coupe, non verifie en jeu ; auto-invitation, marquage par liste utilisateur, automatismes LazyPig avec avertissement) |
| stats | 32 | libre |
| mail | 33 | fait (defaut coupe, non verifie en jeu ; ramassage et envoi en masse, jamais de COD) |
| bulletin | 34 | libre |
| markers | 35 | libre |
| tanktools | 36 | fait (defaut coupe, non verifie en jeu ; alertes de tank : aggro perdu, provocation ratee, vie basse, barre des defensifs ; depend de SUI.Meter.Compile pour les motifs ; visibilite tanktools.vis / .fade, police tanktools.font / .fontsize) |
| meter | 37 | fait (defaut coupe, non verifie en jeu ; compteurs degats/soins/subis/interruptions/dispels, segments par combat et par boss, resume, export ; vue "threat" via SUI.Threat.GetRows) |
| threat | 47 | fait (defaut coupe, non verifie en jeu ; fenetre de menace via le protocole serveur TWThreat, non verifie ; visibilite threat.vis / .fade, engrenage, aspect threat.bartex / .shape / .font) |
| alerts | 38 | libre |
| totems | 39 | fait (defaut coupe, non verifie en jeu ; visibilite totems.vis / .fade, police totems.font / .fontsize) |
| manaswap | 40 | libre |
| debuffs | 41 | libre |
| handguard | 42 | libre |
| raid | 46 | fait (defaut coupe, non verifie en jeu ; raid 40 sur SUI.GroupEngine de Mod_Group) |
| auction | 48 | fait (defaut coupe, non verifie en jeu ; hotel des ventes en 4 onglets Chercher / Vendre / Mes ventes / Analyse : filtres, tri, bonnes affaires, achat et enchere toujours confirmes, vente en lots, annulation confirmee, analyse de la recherche et historique local) |
| chattabs | 49 | fait (defaut actif, non verifie en jeu ; gestionnaire d'onglets de chat, modeles, sauvegarde par personnage, menu clic droit) |
| clickheal | 44 | fait (defaut coupe, non verifie en jeu ; soins au clic par classe + modificateur) |
| specs | 45 | fait (defaut actif, non verifie en jeu ; detection de la spe par points de talents, jeux de reglages par spe : profil, role, mise en page, mode, barres hors Simple Action Sets ; coexiste avec SAS) |
| tracker | 58 | fait (defaut coupe, non verifie en jeu ; verrous d'instances et de raids de tous les personnages, limite horaire de donjons, or par session / jour / compte ventile par source, graphe, export) |
| messages | 55 | fait (defaut coupe, non verifie en jeu ; fenetres de conversation par interlocuteur type WIM, pastilles de notification, historique persistant, reponse d'absence, file en combat, /sui msg) |
| macros | 60 | fait (defaut coupe, non verifie en jeu ; macros a conditions type CleveRoidMacros via enveloppement de SlashCmdList + editeur de macros ; se met en retrait si un addon equivalent est charge ; exception regle 8 : SLASH_SHIKIMACROS_* pour les commandes absentes du jeu) |
| vendor | 62 | fait (defaut coupe, non verifie en jeu ; vente du gris un objet par tour, listes blanche (jamais) et noire (toujours), plafond qualite 0 sauf liste noire, reparation auto avec seuil de confirmation et repli guilde si l API existe, boutons Vendre le gris / Reparer et engrenage sur MerchantFrame, /sui vendor ; jamais d achat) |
| finder | 56 | fait (defaut coupe, non verifie en jeu ; chercheur de groupe maison : ecoute des canaux publics, analyse FR/EN des annonces LFM/LFG en cartes (instance, roles, places, niveau, butin), filtres, alertes avec son, poster mon annonce avec modeles et anti-spam, ecoute minimale fenetre fermee, /sui lfg) |
| powerauras | 66 | fait (defaut coupe, non verifie en jeu ; alertes type WeakAuras / PowerAuras : buff/debuff sur moi ou la cible, recharges de sorts et d objets, procs avec bandeau + son, barres de ressource, conditions (vie basse, execute...), 8 zones deplacables (Mover) en ligne/colonne, filtres combat/groupe/classe/spe, 10 modeles + 17 packs par classe et role, editeur dans le menu ; une seule minuterie, rien tant qu aucune alerte active, /sui powerauras) |
| pallypower | 68 | fait (defaut coupe, non verifie en jeu ; benedictions de raid paladin : grille d'attributions par joueur et par classe (Kings, Wisdom, Might, Salvation, Light), memoire globale par personnage, bouton Benir qui pose a chacun la sienne une par GCD en sautant ceux qui l'ont deja (UnitBuff, greater ou simple selon pp.greater), jugement optionnel au demarrage, touche SHIKIUI_PALLYPOWER via Bindings.xml, /sui pp ; pas de synchronisation entre paladins (v2) ; noms de sorts EN seulement (limite assumee)) |
