# ShikiUI — Spécification

Version du document : 0.3 (2026-11-04) — état du code : **v0.3.0 « socle de modules parallèles »** (fondation v0.1 + migration pfUI + modes, cibles, styles, mises en page, outillage de modules), testée hors jeu uniquement.
Cible : client WoW 1.12 (Turtle WoW), Lua 5.0, Interface 11200.
Documents liés : `PARITY.md` (matrice pfUI → ShikiUI, addons à absorber, licences, découpage en modules).

---

## 1. Vision

Une interface complète **100 % maison** (aucun code de pfUI/ElvUI repris : licences, et le but est de maîtriser chaque ligne), pensée pour :

- **la performance d'abord** : raid 40 joueurs à 60 FPS et plus ; un seul `OnUpdate`, un seul routeur d'évènements, zéro allocation inutile, aucune création d'objet en combat ;
- **un menu qui se comprend en 10 secondes** (mode Simple) **sans rien interdire** à qui veut tout régler (mode Expert) ;
- **l'exploitation des extensions du client** (SuperWoW, Nampower, UnitXP, ClassicAPI) avec détection automatique et **repli propre sur l'API 1.12** quand elles sont absentes ;
- un style **sombre et minimaliste** (inspiration ElvUI), cohérent partout via un système de thème ;
- une base **testable hors jeu** : tout ce qui peut être vérifié sans client l'est, le reste est listé honnêtement comme « non vérifié en jeu ».

Périmètre final (décidé avec l'utilisateur) : cadres d'unités, barres d'action, sacs, chat, minimap, plaques de nom, outils (dégâts, menace, soins, alertes). Rôles de départ : tank / soigneur / DPS / PvP. Nom : **ShikiUI**, commandes `/sui` et `/shikiui` (`/shiki` est pris par ShikiwaRotation).

### Objectif (décision de l'utilisateur, 2026-11-04) : **remplacer pfUI**, puis absorber ses addons
- **Remplacer pfUI** : pas de coexistence durable. La coexistence n'est qu'un **état de transition** pendant la migration module par module (§2.7).
- **Absorber** les addons qu'il utilise en **réécrivant chaque fonction** dans ShikiUI (aucun code tiers copié ; licences relevées addon par addon dans `PARITY.md`). Les addons dont il possède le code (Shiki\*, OctoMeter, OctoManaSwap, ConsoHelper, ItemRack, TankSuite, RollFor, RaidTools…) sont des forks ou des créations à lui ; les Shiki\* **restent séparés** (affichés / pilotés dans ShikiUI, jamais fusionnés).
- **Feuille de route par usage réel** (§5) : ce qu'il voit et utilise le plus (barres d'action, chat, minimap, plaques, incantation / buffs, groupe) d'abord ; ce qui est énorme ou purement données (DPSMate, Puppeteer, aux, RollFor, AtlasLoot, pfQuest, BigWigs) en **pont** d'abord, réécriture ensuite ou jamais.

Non-objectifs : fusionner ShikiwaRotation / ShikiwaHeal / ShikaSwap / ShikiwaSignal dans ShikiUI (ils restent séparés, ShikiUI les détecte et s'y intègre sans dépendance dure) ; reproduire pfUI à l'identique (on reproduit **ses fonctions utiles**, pas ses réglages morts ni ses œufs de Pâques) ; supporter d'autres versions du jeu ; réécrire les bases de données (AtlasLoot, pfQuest).

---

## 2. Architecture du moteur

Fichiers (ordre du `.toc`, généré) : `Core`, `Locale` (+ `Locale_Mode/Target/Style/Layout`), `Serial`, `Api`, `Config`, `Migrate`, `Mode`, `Theme`, `Style` (+ `Style_*`), `Layouts`, `Perf`, `Units`, `Target`, `Menu`, `StyleUI`, `Cmd`, puis les modules. Un seul espace de noms global `ShikiUI` (+ `ShikiUIDB` pour les SavedVariables).

### 2.1 Core — évènements, minuterie, modules
- **Routeur d'évènements unique** (`SUI.On/Off`) : une frame, une table de handlers par évènement, `pcall` par handler (une erreur n'arrête pas les autres), compteur par évènement (pour `/sui perf`). Un handler peut se retirer pendant la distribution sans faire sauter son voisin (les retraits sont différés).
- **Minuterie partagée unique** (`SUI.Every/After/Cancel`) : un seul `OnUpdate`, sortie immédiate tant qu'aucune échéance n'est atteinte (`minNext`), tâches `scalable` ralenties ×2 en mode urgence, mesure optionnelle du temps par tâche (`/sui perf profile`, **indicatif** : le client 1.12 n'a pas de mesure CPU par addon).
- **`WhenSafe`** : exécute tout de suite hors combat, sinon à `PLAYER_REGEN_ENABLED`. Toute création de frame passe par là.
- **Modules à la demande** : `RegisterModule(nom, {init, enable, disable, shutdown, options})`. Chaque module déclare ses réglages (donc ses lignes de menu) ; l'interrupteur `modules.<nom>` est créé automatiquement. `init` n'est appelé qu'à la première activation → un module désactivé ne coûte rien (pas de frames, pas d'évènements, pas de minuterie). Changement de profil → tous les modules sont réalignés.
- **Arrêt propre** : à `PLAYER_LOGOUT`, tous les évènements sont détachés (certains clients plantent à la fermeture sinon ; observé chez d'autres addons, cause non vérifiée).
- **Rapport d'erreurs** : `SUI.Report` compte et mémorise la dernière erreur ; `/sui debug on` les affiche.

### 2.2 Config — réglages, profils, rôles, positions
- **Clés plates** (`units.width`) enregistrées avec leur type, bornes, pas, choix, valeur par défaut. `Validate` borne, arrondit au pas, refuse NaN / mauvais type / choix inconnu.
- **Un profil ne stocke que les écarts** par rapport aux défauts → export compact, évolutions du code sans migration (une nouvelle option prend sa valeur par défaut).
- **Clés globales** (`global = true`, ex. `ui.locale`) stockées hors profil.
- **Profils** : créer (éventuellement par copie), utiliser, supprimer (jamais l'actif ni le dernier), réinitialiser. Nom : 1–24 caractères `[A-Za-z0-9_-]` (pas d'espace : ambigu en ligne de commande). Profil mémorisé **par personnage** (`Nom-Royaume`).
- **Rôles** (tank / soigneur / DPS / PvP) = jeux de valeurs de départ appliqués par-dessus le profil ; uniquement des choix d'interface (aucune donnée de jeu).
- **Positions** : stockées en unités d'`UIParent`, indépendantes de l'échelle (position × échelle à l'enregistrement, ÷ échelle à l'application).
- **Observateurs** `Watch(préfixe, fn)` : les modules réagissent aux changements sans scruter. `Notify(nil)` = « tout a pu changer ».
- **SavedVariables défensives** : à l'initialisation, toute valeur invalide, clé inconnue, profil non-table ou structure corrompue est nettoyée ; la base ne contient jamais de fonction ni de frame.
- **Export / import** : chaîne `SUI1:<somme 8 hex>:<corps>`, corps = sérialisation texte maison. **Jamais de `loadstring`** : analyseur récursif avec limites (60 000 caractères, profondeur 6). À l'import chaque valeur repasse par `Validate`, les clés globales et inconnues sont ignorées et comptées, les positions sont bornées (coordonnées, 32 caractères par clé, 64 entrées). L'import crée un **nouveau** profil (suffixe numérique en cas de collision) et ne touche jamais au profil actif.

### 2.3 i18n
- Français par défaut, anglais complet (166 clés chacun, parité contrôlée par script : mêmes clés, mêmes marqueurs de format). Repli fr → clé brute ; toute clé manquante est mémorisée (`SUI.missingL`) et les tests échouent s'il en reste après un parcours complet de l'interface.
- Langue globale (`ui.locale`), changeable à chaud : menu et messages se retraduisent sur place.
- Sources en ASCII strict (les textes français sont écrits sans accents dans le code ; si on veut les accents, il faudra vérifier l'encodage du client — voir questions).

### 2.4 Moniteur de performance (module `perf`)
- Échantillon chaque seconde : FPS, latence monde, mémoire Lua (`gcinfo`), débit d'allocation approximatif (somme des hausses sur 10 échantillons, les baisses dues au ramasse-miettes sont ignorées).
- **Bandeau** optionnel déplaçable, créé uniquement hors combat.
- **Mode urgence** : manuel (`/sui emergency`, bouton du menu) ou **automatique** avec hystérésis (3 échantillons sous le seuil → on entre ; 10 échantillons à seuil+15 → on sort ; l'urgence manuelle n'est jamais coupée automatiquement). Effets : minuteries `scalable` ×2, lissage des barres coupé, callbacks `Perf.OnEmergency` pour les modules.
- Rapport `/sui perf` : FPS/latence/mémoire, allocation, minuteries les plus appelées, évènements les plus fréquents.

### 2.5 Thème (`Theme.lua`)
- Jetons : `bg`, `panel`, `inset`, `border`, `text`, `dim`, `good`, `warn`, `bad` ; accents `bleu / vert / orange / classe` (couleur de classe du joueur).
- Fabriques de widgets 1.12 uniques (`Backdrop`, `Text`, `Button`, `Check`, `Slider`, `Edit`, `Bar`) : **aucune méthode absente de 1.12** (pas de `SetSize`, `SetShown`…) ; textures `WHITE8X8` ; police `ARIALN.TTF`.
- Les widgets s'abonnent aux changements d'accent (`OnAccent`) → changement de couleur à chaud.
- **Layout** : un enregistrement par cadre (`Layout.Register(frame, clé, ancre, x, y)`) → déplacement à la souris quand `ui.locked` est faux, position sauvegardée dans le profil, échelle globale `ui.scale` appliquée partout.
- Depuis v0.3 : moteur de styles complet (§2.12) et mises en page (§2.13).

### 2.6 Cadres d'unités (module `units`, v0.1)
- Joueur, cible, cible de la cible. Évènements via le routeur central, **rafraîchissement groupé** par une tâche partagée (drapeaux `dirty` : N évènements → 1 écriture), animation de barre à pas constant (désactivée en urgence), **snap** immédiat quand l'unité change (la barre ne « glisse » pas d'une cible à l'autre).
- La cible de la cible est **sondée** (0,2 s) : le client 1.12 n'a pas d'évènement fiable pour elle.
- Règle 1.12 respectée : la vie des unités hostiles est un **pourcentage** (max = 100) → on n'affiche alors que le pourcentage.
- Couleurs : classe (joueurs), hostile / neutre / ami, marqué par un autre joueur (gris). États mort / fantôme / hors ligne.
- Distance sous la cible : UnitXP → SuperWoW (positions) → tranches `<10 / 10-28 / >28 yd` via `CheckInteractDistance`. Cible estompée hors ligne de vue (UnitXP).
- Clic gauche = cibler / sort en attente / déposer l'objet du curseur ; clic droit = menu d'origine ; survol = infobulle + `SetMouseoverUnit` (Nampower).
- Cadres Blizzard masqués (option `units.hideblizz`, rechargement nécessaire pour les rétablir) **uniquement si aucun pfUI ne s'en charge déjà** (§2.7).

### 2.7 Migration pfUI → ShikiUI (module `Migrate`, v0.1.x)

**Principe** : chaque module ShikiUI qui a un équivalent pfUI **attend** tant que pfUI fait tourner cet équivalent. Il n'y a jamais deux jeux de cadres empilés sans que l'utilisateur l'ait choisi.

- **Table** `Migrate.MAP` : module ShikiUI → modules pfUI équivalents (noms enregistrés par `pfUI:RegisterModule`, relevés dans le code installé). Aujourd'hui : `units` → `player`, `target`, `targettarget`. Chaque nouveau module y ajoute sa ligne.
- **Détection** (`Migrate.Boot()` à `PLAYER_LOGIN`, après le chargement de tous les addons) : instantané de ce que pfUI **fait tourner dans cette session**. Un module pfUI tourne s'il est enregistré (`pfUI.module[nom]`), n'est pas coupé (`pfUI_config.disabled[nom] ~= "1"`) et, pour les modules de cadres, si `pfUI_config.unitframes.disable ~= "1"`. La configuration vivante est relue séparément pour savoir ce qui se passera **au prochain `/reload`**.
- **Interrupteur par module** (« ShikiUI prend la main ») : `/sui migrate take <module>` écrit `pfUI_config.disabled[...] = "1"` pour les équivalents de ce personnage, coche le module ShikiUI et demande `/reload` ; **retour arrière** `back` (remet « 0 »). `both` = les deux à l'écran (essai de placement, enregistré dans `ShikiUIDB.global.coexist`) ; `hold` = reprendre l'attente.
- **États** affichés par `/sui migrate` et le menu : `libre` (pas de pfUI), `ShikiUI actif`, `en attente de pfUI`, `pfUI coupé, /reload pour démarrer`, `pfUI revient, /reload`, `les deux à l'écran`.
- **Cadres Blizzard** : `units.hideblizz` est **automatiquement sans effet** tant que pfUI fait tourner `player` ou `target` (ce sont ces modules qui les masquent chez pfUI) ; il reprend son effet dès que pfUI ne s'en charge plus.
- **Menu** : à la place de la ligne des intégrations, « pfUI détecté : N module(s) ShikiUI en attente. Tape /sui migrate ». `/sui status` marque `units=wait`.
- **Sûreté** : un module « voulu mais retenu » n'est ni initialisé ni activé (aucune frame, aucun évènement) ; toute écriture chez pfUI se limite à `pfUI_config.disabled` pour les noms de `MAP` ; table `coexist` nettoyée à l'initialisation.
- **Non vérifié en jeu** : que l'écriture de `pfUI_config.disabled` soit bien lue par pfUI au `/reload` sans être réécrasée (profil pfUI) ; les noms d'exécution des cadres pfUI au-delà des trois cités ; l'aspect de la ligne de pied de page dans le menu.
- **Même mécanisme pour les addons** (quand le premier module d'addon arrive, v0.7) : `MAP` désignera des dossiers d'addons (`IsAddOnLoaded`), l'assistant proposera de les couper dans la liste des addons du personnage.

### 2.8 Conception raid 40 (à implémenter en v0.6 pour le groupe de 5 puis v0.7 pour le raid, contraintes déjà posées)
- Table **unité → cadre** centrale ; un évènement `UNIT_*` ne touche que son cadre.
- Une seule tâche de flush pour tous les cadres, budget par passage (ex. 8 cadres/tick au-delà de N dirty), textes mis en cache (on ne réécrit que si la valeur change — déjà le cas en v0.1).
- Auras : désactivées par défaut dans les petits cadres de raid, activées en option avec limite stricte.
- Si Nampower / ClassicAPI offrent des évènements filtrés par GUID / par unité (`RegisterUnitEvent` ≥ ClassicAPI 1.15.0), les utiliser pour éviter de recevoir les évènements des 39 autres. **Noms d'évènements Nampower à vérifier dans la doc installée avant usage.**
- Banc d'essai : scène simulée 40 cadres + 1000 évènements/s mesurée hors jeu (allocations, appels), puis mesure en jeu (voir risques).

### 2.9 Modules en parallèle (v0.3) — voir `MODULES.md`
- Un module = `Mod_<Nom>.lua` + `Locale_<Nom>.lua` (+ `Style_<Nom>.lua` optionnel) + `tests/t_<nom>.lua` + `tests/mock_<nom>.lua` + `tests/mutations/<nom>.js`. Aucun fichier du socle n'est touché ; le `.toc` est **généré** (`tools/gen_toc.js`, ordre : socle, styles, modules) ; `tools/newmodule.js` crée le squelette depuis `docs/template/` (testé : module de démonstration créé, testé, muté puis supprimé).
- **Services partagés** : `SUI.AddStrings(code, table)` (textes d'un module, clés réservées protégées, jamais d'écrasement) ; `SUI.RegisterCommand(nom, fn, aide)` (sous-commande `/sui <nom>`, noms réservés refusés) ; `SUI.RegisterModule` exige `cost = light|medium|heavy` et refuse les noms réservés (`style`, `layout`, `mode`, `target`…) ; `SUI.Target` (§2.10).
- **Garde-fous automatiques** (tous dans `run_tests.sh`) : lint Lua 5.0, parité fr/en, **aucune couleur/police/texture en dur dans un module** (`check_style.js`), contrat des modules (`t_modules.lua` parcourt tous les modules), modèle de module.

### 2.10 Cibles (`Target.lua`, service partagé)
Une seule source pour « l'unité, son GUID, sa distance, sa ligne de vue » : cache invalidé par évènement, GUID via SuperWoW/Nampower/UnitXP quand présents, repli par tranches de distance 1.12, plaques de nom identifiées par GUID hexadécimal. Les modules n'appellent plus eux-mêmes les extensions.

### 2.11 Modes Normal / Raid (`Mode.lua`)
- Deux modes ; changement manuel, ou automatique à l'entrée/sortie d'un raid (option). Le profil ne stocke que les **écarts du mode** (`mm[mode]`).
- **Priorité de fusion** d'une valeur, de la plus forte à la plus faible : écart de l'utilisateur dans le mode courant › preset rôle+classe › preset classe › preset rôle › preset générique « * » › `raid = "off"` du module › valeur du profil › défaut. `Cfg.Source(clé)` dit d'où elle vient (`override / preset / profile / default / global`) ; le bouton « x » de chaque ligne du menu supprime l'écart (retour au preset ou au profil).
- **Addons externes** : liste configurable par mode ; **aucun `DisableAddOn` sans confirmation explicite** (écran de confirmation, retour arrière proposé, effet au `/reload`).

### 2.12 Moteur de styles (`Theme.lua` + `Style.lua` + `StyleUI.lua`)
- Un **style** = un jeu de jetons (palette `bg/panel/inset/border/text/dim/good/warn/bad…`, accent, police, texture de barre, bordure, opacité, échelle de police). Aucun module n'en code en dur : tout passe par `T.c.*` et les fabriques (`T.Backdrop/Panel/Text/Button/Bar…`). `T.c` est modifié **sur place** (les références gardées par les modules restent valides).
- **Changement à chaud** : `S.Refresh` → `T.Apply(jetons)` → `T.Restyle` repeint tous les widgets suivis, différé hors combat (`WhenSafe`).
- `SUI.RegisterStyle(nom, def)` ; un fichier `Style_<Nom>.lua` par style. Livrés : **Shiki** (défaut, sombre minimal), **pfStyle** (esprit « pfUI »), **ElvStyle** (esprit « ElvUI »), **Blizzard** (classique), plus Light et Tactical. Les noms évoquent un *esprit* ; **aucun code, texture ou police tiers**.
- **Réglages individuels** par-dessus le style (couleurs hex `RRGGBB[AA]`, police, barre, bordure, opacité, échelle de police), chacun avec « x » réinitialiser.
- **Ressources** (polices, textures de barre, bordures) désignées par **nom**, enregistrées par `SUI.RegisterAsset(genre, nom, valeur)` ; une ressource inconnue ou absente retombe sur la ressource de base (`S.missing` la signale). Sources autorisées : chemins du jeu (`Fonts\ARIALN.TTF`, `Fonts\FRIZQT__.TTF`, `Interface\…`) ou fichiers fournis par l'utilisateur.
- **Import/export** : `SUI1:<somme>:<corps>` avec marque « style » (un profil collé comme style, ou l'inverse, est refusé) ; tout est revalidé (couleurs hex, ressources connues, bornes, pas de clé de texte arbitraire) ; 16 styles personnels au plus, stockés dans `ShikiUIDB.global.styles`.
- **Menu** : bouton « Styles » → sélecteur à cartes avec **aperçu indépendant** de chaque style (calculé depuis ses jetons, sans l'appliquer), clic = application, enregistrer / importer / exporter / personnaliser / réinitialiser, boutons de mises en page ; mode Expert : catégorie « Style » complète.

### 2.13 Mises en page (`Layouts.lua`)
- Une **mise en page** = positions (fractions d'`UIParent` + décalage) et quelques réglages de taille, **séparées du style** (le style ne porte jamais de position). Livrées : Classique (remise à zéro), Centre, Compact, Côtés ; variantes par rôle ; `SUI.RegisterLayout(id, def)`.
- Appliquer = écrire dans le profil (`SetPos`, `SetBase`), **dernière écriture gagnante** ; option `layout.followrole` : changer de rôle réapplique la mise en page du rôle. `/sui layout [list|use <id> [rôle]|reset]`.
- **Ordre de fusion style × mise en page × mode × rôle/classe** : le style fournit l'aspect (jetons), la mise en page fournit géométrie et positions (profil), le mode et le rôle/classe fournissent des presets de réglages (§2.11) ; un écart de l'utilisateur gagne toujours. Les quatre dimensions sont indépendantes ; test de matrice **128 combinaisons** (style × mise en page × mode × rôle).

### 2.14 Licences, distribution, compatibilité des sauvegardes
**Licences / distribution (à valider avant toute publication)**
1. Code : 100 % maison ; ni pfUI ni ElvUI n'ont fourni de code, texture, police ou disposition copiée. « pfStyle » / « ElvStyle » sont des **noms descriptifs d'inspiration** : vérifier avant publication qu'ils ne posent pas de problème de marque (renommer au besoin : seuls `Style_Pfstyle.lua` / `Style_Elvstyle.lua` et leurs textes changent).
2. Ressources : aucune ressource n'est livrée avec l'addon (zéro `.tga/.blp/.ttf`). Polices et textures = chemins **du jeu** (propriété de Blizzard, utilisés par référence, comme tout addon). Toute ressource ajoutée plus tard doit avoir une licence compatible, listée ici avec sa source.
3. Les chaînes de style/profil échangées entre joueurs ne contiennent que des valeurs (couleurs, noms), jamais de code ni de chemin libre.
4. Les styles ajoutés par des tiers passent par `RegisterStyle` (validés) ; leurs ressources et licences restent à la charge de leur auteur.

**ShikiUIDB : compatibilité et migration**
- Version de la base : `db.v` (`DB_VERSION` = 1 : aucune conversion n'a encore été nécessaire). À chaque chargement, **toute la base est revalidée** : valeurs hors bornes recalées, clés et champs inconnus supprimés, profils non-tables écartés ; une ancienne sauvegarde ne casse donc jamais et une clé retirée du code disparaît proprement.
- Les profils sont **épars** (seulement les écarts) : une nouvelle option prend sa valeur par défaut sans migration. Champs ajoutés en v0.3 : `mm` (écarts par mode), `layout`, `global.modeAddons`, `global.modeDisabled`, `global.styles`, clés `style.*`. Une sauvegarde 0.1/0.2 s'ouvre telle quelle ; **une sauvegarde 0.3 rechargée par un code 0.1/0.2 perd ces champs** (ignorés puis effacés) : copier `WTF` avant un retour en arrière.
- Un style personnel dont une ressource a disparu s'affiche avec la ressource de base ; un style supprimé alors qu'il est actif est remplacé par le défaut.
- Règle d'évolution : ne jamais changer le sens d'une clé existante, en ajouter une nouvelle ; incrémenter la version de la base seulement si une conversion est écrite **et testée** ; renommer une clé = écrire l'alias de migration dans `Config`.

---

## 3. APIs détectées et replis

| Capacité | Détection | Usage | Repli sans l'extension |
|---|---|---|---|
| **SuperWoW** | `SUPERWOW_VERSION` ou (`SetAutoloot` et `SpellInfo`) | 2ᵉ retour de `UnitExists` = GUID ; `UnitPosition` (distance) | pas de GUID ; distance par tranches |
| **Nampower** | `GetNampowerVersion()` (major, minor, patch) sous `pcall` | `GetUnitGUID`, `SetMouseoverUnit` (survol), file de sorts | GUID via SuperWoW sinon aucun ; pas de mouseover |
| **UnitXP** | sonde `pcall(UnitXP,"nop","nop")` **et** (horodatage de version numérique > 10⁹ **ou** `inSight` booléen) | `distanceBetween`, `inSight`, `behind` (toujours avec `"player"` en premier) | distance SuperWoW ou tranches ; pas de ligne de vue |
| **ClassicAPI** | `CLASSIC_API_VERSION` numérique (X·10000+Y·100+Z) | `RegisterUnitEvent` (≥ 11500), `C_NamePlate.GetNamePlateGUIDs` | évènements globaux ; plaques via enfants de `WorldFrame` |
| Intégrations Shiki* | globales `ShikiwaRotation`, `ShikaSwap`, `ShikiwaSignal`, `IsAddOnLoaded("ShikiwaHeal")` | affichage dans `/sui status` ; ponts futurs | aucune |

Garde-fous : **toute** extension est appelée sous `pcall` ; `UnitXP` existe aussi en 1.12 vanille (expérience du joueur) → le simple test d'existence est interdit (faux positifs testés) ; `inSight` n'est appelé qu'**3 s après l'entrée dans le monde** (précaution reprise d'addons qui observent des plantages plus tôt — cause non vérifiée).

Signatures relevées dans des addons réels installés (pfUI, Puppeteer, SuperCleveRoidMacros, SuperAPI) ; elles n'ont **pas** été exécutées dans le jeu par ce projet.

---

## 4. Menu : Simple / Expert

### 4.1 Principes
- Un **registre de réglages déclaratif** (`SUI.RegisterOption`) alimente les deux modes : un module ajoute ses options sans toucher à `Menu.lua`. Champs : clé, type (`bool` / `number` / `choice`), catégorie, libellé et infobulle (clés de traduction), bornes/pas/choix, `simple` (visible en mode Simple), `order`, `reload` (message « /reload »).
- **Simple** (défaut) : une seule colonne de ~8 réglages essentiels + **barre de rôles** (Tank / Soigneur / DPS / PvP : un clic règle le départ) ; aucune recherche, aucun jargon.
- **Expert** : colonne de catégories (Tout, Général, Cadres d'unités, Performance, Modules…), **recherche** instantanée (libellé traduit **ou** clé technique), en-têtes de catégorie, barre de défilement.
- Pied de fenêtre : profil (clic gauche = suivant, droit = précédent), bouton Urgence, Exporter, Importer, Réinitialiser (**deux clics**, confirmation qui expire en 3 s), extensions et intégrations détectées.
- **Lignes en pool** : créées au premier affichage, réutilisées ensuite (changer de mode, de catégorie, rechercher ne crée **aucun** objet). En combat : aucune fenêtre ni ligne n'est créée (liste tronquée au pool existant, message poli sinon).
- Échap ferme la fenêtre ; la fenêtre est déplaçable ; mode (Simple/Expert) mémorisé.

### 4.2 Assistant de première installation (3 étapes)
1. **Langue** (Français / English) — appliquée immédiatement.
2. **Rôle** (Tank / Soigneur / DPS / PvP) — applique le jeu de départ.
3. **Taille** (Petite 0,9 / Normale 1,0 / Grande 1,1) — règle l'échelle globale.
Lancé 1,5 s après la première connexion (`firstRun`), relançable par `/sui wizard`, « Passer » à tout moment. À la fin : ouverture du menu Simple.

### 4.3 Commandes `/sui` (et `/shikiui`)
`/sui` (menu) · `simple` · `expert` · `wizard` · `status` · `perf [profile on|off | reset]` · `emergency [on|off]` · `lock` / `unlock` · `profile list|use|new|delete|reset` · `role tank|heal|dps|pvp` · `lang fr|en` · `export` / `import [chaîne]` · `migrate [take|back|both|hold <module>]` · `debug [on|off]` · `mode [normal|raid|toggle|auto|reset|info|addons]` · `style [list|use|pick|export|import|reset]` · `layout [list|use|reset]` · `target` · `help`.

---

## 5. Feuille de route par usage réel

Remplace l'ancien ordre (raid d'abord) : l'ordre suit **ce que l'utilisateur voit et utilise** (config pfUI lue, addons installés). Détail des modules, tailles, licences et ponts : `PARITY.md`. Chaque module livré s'inscrit dans `Migrate.MAP` (§2.7) : il attend pfUI, puis un clic donne la main à ShikiUI.

| Version | Contenu | Remplace chez pfUI / absorbe | Statut |
|---|---|---|---|
| **v0.1** | Core, config/profils/rôles, thème, menu Simple/Expert + assistant, perf, cadres joueur/cible/cible de cible, export/import, **garde-fou de coexistence + `/sui migrate`**, tests hors jeu | player, target, targettarget | **fait (non validé en jeu)** |
| v0.2 | **Barres d'action** : pages, formes, 7 barres, recharge/portée/mana, raccourcis, menu micro, sac à dos | actionbar, cooldown, macroicons, hoverbind… | à faire |
| v0.3 | **Chat**, **minimap**, **panneaux d'infos + barre XP/réputation**, **infobulles**, boutons d'addons, pixel parfait | chat, minimap, panel, xpbar, tooltip, addonbuttons… | à faire |
| v0.4 | **Incantation**, **buffs/debuffs** (+ DebuffAlert configurable), pont **Shiki\*** (état/boutons de ShikiwaRotation, ShikiwaHeal, ShikaSwap) | castbar, buff, buffwatch, mirrortimers | à faire |
| v0.5 | **Plaques de nom** + service de ciblage `SUI.Target` (extrait de ShikiwaRotation) + menace colorée | nameplates ; absorbe TankPlates | à faire |
| v0.6 | **Groupe de 5**, focus, familier, points de combo, totems, barre chasseur | group, pet, focus, combopoints, totems… | à faire |
| v0.7 | **Objets** : ItemRack, TrinketMenu, ConsoHelper, feuille de personnage (BCS) ; **ponts** DPSMate / Puppeteer / OctoMeter (dock + skin) ; migration des addons | equipmentmanager, eqcompare… | à faire |
| v0.8 | **Butin et social** : LootBlare, jets, LazyPig, AutoInvite, WIM, amis ; **courrier** (TurtleMail) | loot, roll, friends… | à faire |
| v0.9 | **Combat et raid** : HandGuard, OctoManaSwap évolué, TankSuite, Rinse, Call of Elements, AutoMarker, RaidAuraWatch ; profils par spécialisation ; passe optimisation | — | à faire |
| v1.0 | **Sacs** et **skins**, validation **mesurée en jeu** (raid à 60 FPS), documentation, thèmes, publication | bags, skin, thirdparty | à faire |
| v1.1+ | Réécriture des gros morceaux, un par un : mesure de dégâts/menace, RollFor, DifficultBulletinBoard | — | à décider |
| v1.2+ | Cadres de **soin de raid** (remplace Puppeteer), **hôtel des ventes** (aux) | raid | à décider |

Règle de livraison : chaque version est livrable seule, sans fonction à moitié finie ; un module non prêt reste coupé par défaut.

---

## 6. Stratégie de tests hors jeu

Outil : **node + fengari** (Lua 5.3) avec un mock WoW 1.12 **strict** (`tests/mock_wow.lua`) :
- méthodes de widgets limitées à la liste 1.12 (toute méthode inconnue = erreur → pas de `SetSize` par mégarde) ;
- **lecture** d'une globale non définie = erreur (hors extensions déclarées optionnelles) ; **écriture** d'une globale non déclarée = erreur (fuites) ;
- horloge contrôlée (`Pump`), évènements (`Fire`), compteur d'objets créés (`CREATED`) pour prouver « aucune création en combat / en navigation » ;
- extensions installables/retirables par scénario (`EXT.superwow/nampower/unitxp/classic`, dont un faux `UnitXP` vanille et un `UnitXP` qui répond 1 à tout).

Contrôles :
| Contrôle | Fichier | Rôle |
|---|---|---|
| Lint Lua 5.0 | `lint50.js` | refuse `#`, `%`, `...`, `select`, `string.match/gmatch`, `loadstring` & co, non-ASCII/BOM, globales écrites par fuite, >32 upvalues, >200 locals |
| Traductions | `check_locale.js` | parité fr/en, marqueurs de format, clés littérales des sources présentes |
| 14 suites | `t_*.lua` | cœur, config, sérialisation, API, cadres d'unités, menu, perf, commandes, locale, combat, démarrage (base existante / vide), **migration pfUI** (`t_migrate` : pfUI actif, `t_migrate2` : pfUI coupé, cas limites) |
| Mutations | `mutate.js` | applique 67 régressions plausibles à une copie du code (dont 18 sur la migration) ; chaque mutant doit être tué par une suite (état actuel : tous tués) |

Lancer : `sh tests/run_tests.sh` (lint + traductions + suites) ; `node tests/mutate.js` (mutations, ~1 min).

Limite assumée : Lua 5.3 ≠ Lua 5.0. Le lint interdit les constructions 5.0-incompatibles connues, mais le **comportement réel du client** (positions, polices, évènements) ne se teste qu'en jeu.

---

## 7. Risques

| Risque | Gravité | Parade |
|---|---|---|
| Comportement réel du client différent du mock (ancres/échelle, polices, évènements) | élevée | liste « non vérifié » ci-dessous ; premier test en jeu sur UN client, avec `/sui debug on` |
| FPS en raid 40 non mesuré | élevée | v0.2 : banc d'essai + mesure en jeu avant toute promesse ; mode urgence déjà en place |
| Conflit avec pfUI / ElvUI / autres cadres | moyenne | **traité en v0.1.x** pour pfUI : un module attend tant que pfUI fait tourner son équivalent, bascule module par module avec retour arrière (§2.7) ; cadres Blizzard jamais masqués si pfUI s'en charge. Reste à faire : ElvUI et autres (même table) ; vérifier en jeu l'écriture de `pfUI_config.disabled` |
| Masquer les cadres Blizzard (désinscrire les évènements) casse un addon qui s'y accroche | moyenne | option désactivable ; rétablir demande un `/reload` (annoncé) |
| Extension absente ou d'une autre version que celle supposée | moyenne | détection + `pcall` + replis, tests sur plusieurs profils d extensions (nu, SuperWoW, Nampower, ClassicAPI, UnitXP reel / vanille / trompeur / en erreur) |
| Plantage à la fermeture (observé ailleurs, cause non vérifiée) | moyenne | détachement des évènements à `PLAYER_LOGOUT` |
| Mesure CPU par addon impossible en 1.12 | faible | le profilage de minuteries est étiqueté indicatif ; la vraie mesure est le FPS en scène reproductible |
| Taille du projet (barres, sacs, chat, plaques…) | élevée | livraison par versions, modules indépendants, registre d'options partagé |
| Accents dans les textes | faible | sources en ASCII ; à décider avec l'utilisateur (voir questions) |

### Non vérifié en jeu (v0.3 : tout le code est non testé en jeu)
Nouveautés v0.3 : (a) portée de `DisableAddOn` (personnage ou compte) et `GetAddOnInfo` au-delà du nom ; (b) `instanceType` « arena » ; (c) `GetName(1)` des plaques ; (d) `inSight`/`behind` UnitXP avec un GUID ; (e) valeur de retour de `SetFont` ; (f) rendu des `TexCoord` des boutons et des textures `Interface\…` (bordure/fond d'infobulle, cadre de dialogue, UI-Panel-Button, UI-StatusBar) ; (g) sonde `GetTexture` pour un fichier absent ; (h) rendu réel de chaque style et des aperçus du sélecteur ; (i) positions des mises en page selon résolution/échelle ; (j) changement de mode en raid en plein combat ; (k) coût réel du repeint à chaud avec beaucoup de widgets.

#### Liste v0.1
Tout ce qui touche au client réel, en particulier :
1. rendu : ancres, `GetLeft/GetBottom` × échelle pour le glisser-déposer, empilement des strates, scroll frame sans gabarit, curseur `Slider` sans gabarit, police `Fonts\ARIALN.TTF` ;
2. `UnitXP("version","coffTimeDateStamp")` renvoie bien un nombre > 10⁹ ; `inSight` renvoie un booléen ; délai de 3 s suffisant ;
3. `UnitPowerType` renvoie un nombre (0 mana, 1 rage, 2 focus, 3 énergie) ; `GetNetStats` renvoie (entrée, sortie, latence) ; `gcinfo` en Ko ;
4. existence de `TargetofTargetFrame` dans ce client (le code tolère son absence) ;
5. `ToggleDropDownMenu(1,nil,PlayerFrameDropDown,"cursor")` pour le clic droit ;
6. `EditBox:SetMaxLetters(0)` = illimité, chaînes d'export de plusieurs milliers de caractères dans un `EditBox` mono-ligne ;
7. effets de bord de `UnregisterAllEvents()`+`Hide()` sur `PlayerFrame` / `TargetFrame` ;
8. toute mesure de performance.

---

## 8. Questions ouvertes pour l'utilisateur

1. **Rythme de livraison** : une version = un test en jeu (recommandé : v0.1 testée avant d'écrire v0.2), ou plusieurs versions d'affilée ?
2. **Premier test en jeu** : sur quel client (sur les 3) et avec quelles extensions réellement chargées ? Peux-tu lancer `/sui status` et me donner la sortie + `/sui debug on` si une erreur apparaît ?
3. **Accents** : veux-tu les accents dans l'interface ? (cela suppose de vérifier l'encodage UTF-8 des fichiers sur tes clients ; sinon on garde l'ASCII.)
4. ~~pfUI : coexister ou remplacer ?~~ **Tranché (2026-11-04) : remplacer**, migration module par module (§2.7). Reste : ElvUI est-il aussi à surveiller (il n'est pas installé chez toi) ?
5. ~~Cadres Blizzard~~ **Tranché par la mise en œuvre** : masqués seulement si le module ShikiUI est actif **et** qu'aucun pfUI ne s'en charge ; à confirmer en jeu.
6. **Profils par spécialisation** : détection automatique (talents) acceptable, ou bascule manuelle uniquement ?
7. **Outils (dégâts/menace/soins)** : proposition de `PARITY.md` = **pont d'abord** pour DPSMate, OctoMeter, TWThreat, Puppeteer, BigWigs, RaidTools (docks / skin / positions), réécriture plus tard pour les plus gros. D'accord ? Idem RollFor (XL, par morceaux) et ShikaSwap (reste séparé).
8. **Style** : ElvUI sombre est le défaut ; veux-tu aussi un thème clair / fort contraste dès la v0.9 ?
9. **Distribution** : usage privé, ou dépôt public (GitHub) comme SunreachFR ? Cela décide des licences de polices/textures.
10. **Éléments à reprendre** de tes addons Shiki* (HUD de ShikiwaRotation, menu de ShikiwaHeal) : en module ShikiUI ou à laisser séparés ?
11. **Ordre de la feuille de route (§5)** : barres d'action → chat / minimap → incantation / buffs → plaques → groupe → objets → butin → combat. Valides-tu, ou y a-t-il un module sans lequel tu ne peux pas tester ShikiUI en jeu avant ?
12. **Licences** : DebuffAlert (LICENSE = GPL v3, README = MIT) et AutoMarkerOW (qui l'a écrit ?) : que sais-tu ? Les forks ItemRack / TrinketMenu / RollFor sont-ils à publier un jour ?
13. **Call of Elements** n'est installé que sur le client octowow : le garder dans le périmètre (chaman) ?
14. **Quels personnages** font référence pour l'usage réel (les `AddOns.txt` sont trop hétérogènes pour trancher) ? Un addon de `PARITY.md` que tu n'utilises pas = à retirer du périmètre.
