# ShikiUI — Parité pfUI et addons à absorber

Document de travail du 2026-11-04. **But décidé par l'utilisateur : remplacer pfUI** (pas de coexistence durable) **et absorber ses addons** en **réécrivant chaque fonction** dans ShikiUI.
Rien n'est déployé. Rien n'a tourné en jeu. Les tailles de réécriture sont des **estimations**, pas des mesures.

Sources de cet audit (lecture seule) : l'arbre `Interface\AddOns\pfUI` du client octowow (noms et tailles des modules, chargeur `pfUI.lua`, page « Modules » de `gui.lua`), la **vraie configuration pfUI** du personnage principal (2 790 lignes, extraite par `tools\pfui_dump.js`), les dossiers `.toc` / `LICENSE` / `README` des addons de `C:\MesJeuxRare\octowow\Interface\AddOns` et `octoc`, et le code de ciblage de `shikiwa_work\ShikiwaRotation`.

---

## 0. Méthode et licences

**Règle de travail** : on décrit ce que fait une fonction (comportement observable, options, évènements du jeu utilisés), puis on l'écrit à neuf dans le style ShikiUI (routeur unique, minuterie unique, registre d'options, tests hors jeu). **Aucune ligne de code tiers n'est copiée.** On relève les évènements et signatures dans le code installé quand c'est nécessaire, et on les marque « non vérifié en jeu » tant qu'ils n'ont pas tourné.

**Licences relevées** (fichiers présents dans les dossiers installés ; « aucune » = pas de fichier de licence trouvé, donc par défaut tous droits réservés à l'auteur d'origine) :

| Addon | Auteur(s) / origine | Licence relevée | À lui (fork ou code écrit par lui) |
|---|---|---|---|
| pfUI (édition ClassicAPI) | Shagu | **MIT** (2016-2021) | non |
| pfQuest / pfExtend | Shagu, txtsd / Cliencer | MIT / MIT (2026 TinyStick) | non |
| ConsoHelper | ShikawaLePaladin | MIT | **oui** |
| HandGuard | Shikawa | MIT | **oui** |
| OctoMeter | Shikawa | MIT (selon son README) | **oui** |
| OctoManaSwap | shika | aucune (code à lui) | **oui** |
| TankSuite | Shikiwa | aucune (code à lui) | **oui** |
| ItemRack (fork) | Gello (original) ; fork dans `itemrack_work` | aucune | **fork à lui** |
| TrinketMenu (3.41-octo1) | Gello (original) ; fork dans `trinketmenu_work` | aucune | **fork à lui** |
| RollFor (fork) | Obszczymucha ; README « New in this fork » | aucune | **fork à lui** |
| RaidTools (`rt`) | ShikawaLePaladin | aucune | **oui** |
| RaidAuraWatch | Sunreach | aucune | **oui** |
| Shikiwa* / ShikaSwap / ShikiwaSignal | lui | aucune | **oui** (restent séparés) |
| AutoMarkerOW | « OctoWow community » (dossier `automarker-ow` chez lui) | aucune | **à confirmer** |
| CallOfElements | auteur non indiqué dans le toc | **GPL v3** | non |
| DPSMate (Enhanced) | Shino, Torio | **GPL v3** | non |
| DebuffAlert | Orfc | **contradiction** : fichier LICENSE = GPL v3, README = « MIT » | non — demander à l'utilisateur ce qu'il en sait |
| Rinse | Otari / Spit | MIT (2025 Spit) | non |
| _LazyPig | Ogrisch, mrmr, Lexie, TrumpetX | aucune | non |
| AutoInvite | Esco | aucune | non |
| AutoMarker | Weird Vibes | aucune | non |
| BetterCharacterStats | moh, Bennylava, Lexie, Spit, Pepopo, MarcelineVQ | aucune | non |
| LootBlare, TankPlates | Ehawne et al. (Weird Vibes) | aucune | non |
| DifficultBulletinBoard | akzkak, DeterminedPanda | aucune | non |
| TurtleMail | shirsig / sica | aucune | non |
| ShaguDPS | Shagu | aucune dans le dossier | non |
| TWThreat, Tankalyze, Puppeteer, BigWigs (fork Pepopo), WIM, aux, AtlasLoot, MikScrollingBattleText | divers | aucune dans le dossier | non |

Conséquences : pour les **addons à lui**, réécrire est un choix de maîtrise (rien n'empêche de réutiliser son propre code, mais l'utilisateur a demandé la réécriture et le **code gardé séparé** pour les Shiki*). Pour les **autres**, la réécriture « propre » est la bonne voie : on ne copie pas, on reproduit le **comportement**. pfUI étant MIT, une reprise serait juridiquement possible avec la mention de copyright, mais ce n'est pas la méthode retenue.

---

## 1. Matrice pfUI → ShikiUI

Statuts : **fait** (dans le code, testé hors jeu) · **prévu vX** · **non voulu** (volontairement absent).
Colonne « Migrate » = noms des modules pfUI que l'assistant de migration doit surveiller et couper (noms relevés dans `pfUI\modules`, ils sont enregistrés par `pfUI:RegisterModule`). Seul `units` est branché aujourd'hui.

Usage réel de pfUI chez l'utilisateur (config lue) : **tout est actif sauf `swingtimer`** ; groupe de 5 utilisé ; **cadres de raid de pfUI coupés** (Puppeteer fait raid et soins) ; 7 barres d'action ; un panneau de chat à gauche ; plaques avec debuffs et couleurs de menace ; loot / roll ; barres XP / réputation ; panneaux bas ; minimap taille 140 ; nombreux skins et docks tiers (DPSMate, ShaguDPS, TWThreat, OctoMeter, WIM…).

| Domaine | Fonction pfUI (module) | ShikiUI | Statut | Migrate | Priorité | Extras SuperWoW / Nampower / UnitXP / ClassicAPI |
|---|---|---|---|---|---|---|
| Cadres | joueur, cible, cible de la cible | `units` | **fait** (v0.1) | player, target, targettarget | — | GUID, distance UnitXP, ligne de vue |
| Cadres | cible de cible de cible, familier, cible du familier, focus | `units` (suite) | prévu v0.6 | targettargettarget, pet, pettarget, focus | moyenne | focus = GUID (SuperWoW) |
| Cadres | **groupe (5)** | `group` | prévu v0.6 | group | **haute** (utilisé) | `RegisterUnitEvent` (ClassicAPI ≥ 1.15) |
| Cadres | **raid** (coupé chez lui) | `raid` | prévu v0.7, **pont Puppeteer d'abord** | raid | basse (Puppeteer en charge) | idem + budget 40 cadres |
| Cadres | points de combo, barre chasseur, totems, tick d'énergie, feign death | `classbits` | prévu v0.6 | combopoints, hunterbar, totems, energytick, feigndeath | moyenne | — |
| Cadres | **incantation** joueur / cible | `castbar` | prévu v0.4 | castbar | **haute** | file de sorts Nampower (affichage de la file) |
| Cadres | **buffs / debuffs**, buffwatch, miroir (souffle…) | `auras` | prévu v0.4 | buff, buffwatch, mirrortimers | **haute** | durées exactes par GUID (SuperWoW) |
| Cadres | barre d'attaque (swingtimer) | `swing` | prévu (v0.9) ; **coupé chez lui** | swingtimer | basse | évènements d'auto-attaque Nampower (à vérifier) |
| Barres | **barres d'action** (pages, formes, 7 barres), recharge, portée, mana, raccourcis | `bars` | prévu **v0.2** | actionbar, cooldown, macroicons, hoverbind, macrotweak, autoshift, innervatecall, itemcount | **très haute** (la plus visible) | `GetSpellCooldown` précis (Nampower) |
| Barres | barre de menu micro, sac à dos, barre de forme / familier, griffons, graphique HD | `bars` (suite) | prévu v0.2 | gryphons, hdgraphic | moyenne / basse | — |
| Interface | **chat** (onglets, copie, bulles, chuchoteurs) | `chat` | prévu **v0.3** | chat, chatcopy, bubbles, whisperproxy | **très haute** | — |
| Interface | **minimap**, carte du monde (révélation, couleurs), suivi, marqueurs | `minimap`, `map` | prévu v0.3 | minimap, map, mapreveal, mapcolors, tracking, marktracking | **haute** | — |
| Interface | **panneaux** d'infos (FPS, latence, or, durabilité…), barre XP / réputation, position locplus | `panel` | prévu v0.3 | panel, xpbar | **haute** | latence Nampower (à vérifier) |
| Interface | barre des boutons d'addons, **déverrouillage / déplacement** | `Theme.Layout` (existe) + `addonbuttons` | **fait** pour le déplacement ; boutons prévu v0.3 | addonbuttons, unlock | moyenne | — |
| Interface | pixel parfait, échelle | `ui.scale` | **fait** (échelle) ; pixel parfait prévu v0.3 | pixelperfect | moyenne | — |
| Interface | **plaques de nom** (debuffs, menace, couleur par rôle, incantation) | `plates` | prévu **v0.5** (absorbe TankPlates) | nameplates | **très haute** (78 Ko, très utilisé) | GUID par plaque (ClassicAPI `C_NamePlate`) sinon `GetName(1)` des enfants de `WorldFrame` |
| Objets | **sacs** (fenêtre unifiée, tri, recherche) | `bags` | prévu v0.7 ; **trop gros pour une version** (voir §4) | bags, itemcount, newitem, unusable | haute | — |
| Objets | gestionnaire d'équipement, comparaison, valeur de vente, clic objet, auto-vente | `items` | prévu v0.7 (absorbe ItemRack) | equipmentmanager, eqcompare, sellvalue, itemclick, autovendor, questitem | moyenne | — |
| Objets | **infobulles** | `tooltip` | prévu v0.3 | tooltip | haute | GUID de l'unité survolée |
| Butin | **butin / jets / historique** | `loot` | prévu v0.8 (absorbe LootBlare, pont RollFor) | loot, roll, loothistory | haute | — |
| Social | amis, notes d'amis, social | `social` | prévu v0.8 | friends, friendnotes, socialmod | moyenne | — |
| Divers | capture d'écran, caméra AFK, mode farm, score de BG, infight, partage de config (`share`), souris | `misc` | prévu v0.9, au cas par cas | screenshot, afkcam, farmmode, bgscore, infight, share, mouseover | basse | — |
| Intégration | superwow / nampower / unitxp / turtle-wow / addoncompat / combatlogfix | `Api.lua` (existe) | **fait** pour la détection ; correctifs de journal : prévu v0.9 | superwow, nampower, unitxp, turtle-wow, addoncompat, combatlogfix | — | — |
| Interface | **skins** des fenêtres Blizzard et des addons tiers | `skins` | prévu v0.9 ; **trop gros** (voir §4) | skin, thirdparty, thirdparty-vanilla, thirdparty-tbc, addons | moyenne (cohérence) | — |
| Menu | GUI de configuration, profils, assistant de premier lancement, thèmes | `Menu` | **fait** (Simple / Expert, assistant, profils, export / import) | gui, firstrun, custom, updatenotify | — | — |
| Divers | œuf de Pâques, GM, `uf_tukui` (variante de style) | — | **non voulu** | easteregg, gm, uf_tukui | — | — |

Remarques :
- Les noms de modules `marktracking`, `share`, `unlock`… sont ceux des fichiers ; la fonction exacte de chacun **n'a pas été lue en entier** (déduite du nom et de la taille) → à relire avant d'écrire le module ShikiUI correspondant.
- Aucun nom de cadre pfUI d'exécution au-delà de player / target / targettarget n'est supposé ; l'assistant ne touche qu'aux modules dont le nom est dans la table `Migrate.MAP`.

---

## 2. Addons à absorber (réécriture)

Colonnes : **Réécrire** = fonctions à reproduire · **Taille** = estimation en lignes Lua ShikiUI (S ≤ 400, M ≤ 1 200, L ≤ 3 000, XL > 3 000) · **API** = dépendances optionnelles · **Version** = version cible · **Prio** = selon l'usage réel (installé et actif, présence d'un historique de réglages, rôle de l'utilisateur : paladin Ret / Necroladin, raid, officier de raid) · **Module** = module ShikiUI proposé (§3).
**Fiabilité des descriptions** : celles marquées « README » viennent des fichiers lus ; les autres sont résumées d'après le nom, le `.toc` et la taille, et **doivent être relues dans le code de l'addon avant d'écrire le module** (le but étant de ne rien omettre de ce que l'utilisateur utilise vraiment).
Taille source (Ko de Lua) donnée pour situer l'effort, **données et traductions comprises** (donc surestimé pour la logique).

### 2.1 Liste demandée explicitement

| Addon | Source Ko | Réécrire (fonctions) | Taille | API | Version | Prio | Module |
|---|---|---|---|---|---|---|---|
| **_LazyPig** | 82 | (d'après son README) descente de monture automatique, jets automatiques sur objets de ZG (4 modes), fenêtre de butin sous le curseur, traitement automatique des dialogues PNJ (taxi, maître de BG, aubergiste, vendeur), mise en sourdine du canal monde en instance / filtre anti-répétition, clic droit vers échange / HV / courrier, Maj + clic droit = scinder, Maj à un vendeur = vente de gris + réparation, quêtes répétables auto, acceptation de groupe (3 modes) / invocation / résurrection d'instance, caméra étendue, combinaisons de touches (Alt+Ctrl = échange / confirmations, Ctrl+Maj = suivre…), réglage par `/lp` | M | — | v0.8 | haute | Social |
| **AutoInvite** | 10 | invitation automatique par chuchotement ou chat de guilde si le message correspond (un seul mot-clé, insensible à la casse), conversion en raid ; `/ai` | S | — | v0.8 | moyenne | Social |
| **AutoMarker** (SuperWoW) + **AutoMarkerOW** | 190 / 88 | pose automatique de marques de raid sur des cibles connues (listes par instance), détection par GUID | M (liste de monstres = données à relire, **jamais inventées**) | **SuperWoW** (GUID, `UnitExists` 2ᵉ retour) | v0.9 | haute (raid) | Raid |
| **BetterCharacterStats** | 254 | feuille de personnage enrichie : crit / toucher / hâte / résistances / attaque / sorts / parade, par catégorie repliable | M ; **ne rien inventer** : les formules viennent des règles du jeu connues, à confirmer avec l'utilisateur | — | v0.7 | moyenne | Personnage |
| **CallOfElements** (GPL v3, **présent seulement dans `octowow`**, absent d'`octoc`) | 261 | barre de totems du chaman : jeux de totems, minuterie par totem, retrait / relance, ensembles personnalisés | M | — | v0.9 | basse (le chaman n'est pas son rôle principal ; ami en Élémentaire) | Combat (classe) |
| **ConsoHelper** (à lui, MIT) | 79 | grille de consommables par catégorie, filtre, utilisation et suivi de la fiche | S | — | v0.7 | haute (raid) | Objets |
| **DebuffAlert** (licence ambiguë) | 31 | alerte visuelle (icône + texte par debuff) et sonore sur debuffs choisis du joueur, mode test, cadre déplaçable, icône masquable (README) ; **version plus configurable** : listes par rôle / instance, son choisi, durée, position, priorité | S–M | durées par GUID (SuperWoW) | v0.9 | moyenne | Raid |
| **HandGuard** (à lui, MIT) | 64 | appels d'urgence aux soigneurs (main de protection / bouclier divin avec confirmation), raccourcis, vérification de lancement par évènement | S | — | v0.9 | moyenne (paladin) | Combat (classe) |
| **Système de ciblage** de ShikiwaRotation | (extrait de 268 Ko) | voir §2.3 | M | UnitXP, SuperWoW, plaques | v0.5 (avec les plaques) | haute | Combat |
| **ItemRack** (fork à lui) | 324 | jeux d'équipement, échange automatique par évènement (combat, monture, zone, buff), menu radial | L | — | v0.7 | haute | Objets |
| **LootBlare** | 19 | fenêtre des jets en cours quand un objet est lié dans l'avertissement de raid, tri par type de jet, premier jet seul | S | — | v0.8 | haute | Butin |
| **OctoManaSwap** (à lui) | 124 | échange d'armes / reliques selon le mana, suivi des procs ; **version plus évoluée** : règles par spé, seuils, historique | M | Nampower (file de sorts) | v0.9 | haute (Necroladin) | Combat (classe) |
| **RollFor** (fork à lui) | 1 180 | jets avec réserves, réserves douces, fenêtre joueurs triés par classe, annonces, import des réserves ; **version modifiable / configurable** | **XL** | — | **v1.1+**, par morceaux | haute | Butin |
| **TankSuite** (à lui) | 125 | outils de tank (fichiers : annonces, menace, plaques, liste du groupe, interface, menu), optionnel pfUI / ShaguPlates ; **recoupe `plates` et `Target`** (à relire avant de découper) | M | menace TWThreat (à lire) | v0.9 | moyenne | Combat |
| **DifficultBulletinBoard** | 351 | agrégation du chat monde par sujets (donjons, raids, métiers), filtres, bouton minimap | L | — | v1.0 | basse | Social |
| **TurtleMail** | 71 | courrier : tout prendre, ouverture en lot, mémorisation des destinataires, journal | S–M | — | v0.8 | moyenne | Courrier / HV |

### 2.2 Groupes complémentaires

| Groupe | Addon | Source Ko | Réécrire | Taille | API | Version | Prio |
|---|---|---|---|---|---|---|---|
| **Combat** | DPSMate (GPL) | 4 320 | mesure dégâts / soins / dissipations / absorptions par module, fenêtres multiples, historique de combats | **XL** | journal de combat SuperWoW | **pont d'abord (v0.7)**, réécriture v1.2+ | haute (utilisé) |
| | ShaguDPS | 73 | mesure simple dégâts / soins, portée du journal de combat | M | `trackall` = tout le monde proche | v0.9 | moyenne |
| | **OctoMeter** (à lui) | 370 | mesure + onglet Menace (déjà évolué par lui) | L | SuperWoW | **pont** (affichage / dock dans ShikiUI), réécriture v1.1 | haute |
| | TWThreat | 77 | menace de raid (communication d'addon) | M | — | pont v0.9 | haute (tank / officier) |
| | Tankalyze | 714 (Ace2 embarqué) | annonces de taunt / résistances, suivi des échecs de provocation | M | SuperWoW | v1.0 | basse |
| | TankPlates | 9 | couleur de plaque selon la menace | S | plaques / GUID | **v0.5** avec `plates` | haute |
| **Raid** | Puppeteer | 933 | cadres de soin / raid par rôle, **liaisons souris-sorts**, cibles prioritaires, soins prévus | **XL** | `RegisterUnitEvent`, HealComm | **pont v0.7** ; réécriture **v1.2+** | **très haute** (utilisé en raid) |
| | RaidAuraWatch (à lui) | 35 | surveillance d'auras de raid | S | GUID | v0.9 | moyenne |
| | BigWigs (fork Pepopo) | 3 469 | modules de combats de boss, barres, alertes | **XL** | — | **ne pas réécrire** : pont (skin + position des barres) | haute |
| | RaidTools `rt` (à lui) | 1 290 | outils d'officier : groupes, import, partage | **XL** | — | **ne pas réécrire** : pont / bouton | haute |
| | RollFor | voir §2.1 | | | | | |
| | DebuffAlert | voir §2.1 | | | | | |
| | Rinse | 73 | dissipation des debuffs des alliés à la manière de Decursive (un clic / une macro `/rinse`), listes d'exclusion et de priorité ; utilise SuperWoW, Nampower, UnitXP si présents (README) | M | portée UnitXP | v0.9 | haute (soigneur) |
| **Confort** | ItemRack / TrinketMenu | 324 / 79 | voir §2.1 ; TrinketMenu : menu de bijoux, file d'utilisation | L / M | — | v0.7 | haute |
| | aux (shirsig) | 321 | **hôtel des ventes** : recherche, scan, ventes avec valeurs historiques | **XL** | — | **v1.2+ ou pont** (données de 8 Mo, très utilisé) | moyenne |
| | TurtleMail | voir §2.1 | | | | | |
| | WIM | 265 | chuchotements en fenêtres, historique, alias, filtres | L | — | v0.8 | haute |
| | AtlasLoot | 3 466 | **données** d'objets de donjons ; interface de parcours | **XL (données)** | — | **ne pas réécrire** : pont / skin ; les données restent à AtlasLoot | basse |
| | pfQuest / pfExtend | 39 434 / 149 | base de quêtes / carte ; pfExtend = butin des monstres | **XL (données)** | — | **ne pas réécrire** : pont (marqueurs de carte sur la minimap ShikiUI) | moyenne |
| | MikScrollingBattleText | 636 | texte de combat défilant | L | — | v1.0 ou pont | moyenne |
| **Shiki\*** | ShikiwaRotation, ShikiwaHeal, ShikaSwap, ShikiwaSignal | 268 / 159 / 205 / 12 | **affichés et pilotés** dans ShikiUI (état, bouton, profils) ; **code gardé séparé** | S (ponts) | globales Shiki* | v0.4 pour le premier pont | haute |

### 2.3 Système de ciblage (extrait de ShikiwaRotation)

Ce que fait le code de l'utilisateur (relu dans `ShikiwaRotation.lua` lignes 594-643 et `ShikiwaRotation_Regen.lua` lignes 276-375) et que ShikiUI doit proposer comme **service partagé** `SUI.Target` :
1. **Acquisition du plus proche** : `ClearTarget()` avant `TargetNearestEnemy()` (sans cela l'API avance au suivant du cycle et non au plus proche) ; variante joueurs en PvP ; **retour à la cible précédente** (`TargetLastTarget`) si rien n'est trouvé.
2. **Re-ciblage automatique** : si la cible ennemie est hors de portée de **tous** les sorts de référence, on cible le plus proche, avec un délai minimal (`retargetGap`, 0,3 s par défaut).
3. **Dénombrement des ennemis** : énumération des **enfants de `WorldFrame`** de type Button (plaques de nom), GUID par `plaque:GetName(1)` (extension du client), filtre hostile / vivant / en combat, **distance exacte par `UnitXP("distanceBetween", "player", guid)`**, cache de 0,4 s, tout sous `pcall`. Retourne `nil` (inconnu) plutôt que de forcer une valeur ; repli dégradé = nombre de plaques sans distance.
4. **Distance à la cible** par UnitXP.
ShikiUI en fera un service (`SUI.Target.Nearest()`, `Count(range)`, `Dist()`) réécrit avec **ses** tests ; il servira aux plaques, au suivi de menace et à l'alerte AoE. ClassicAPI offre `C_NamePlate.GetNamePlateGUIDs` : le préférer quand il existe (déjà détecté dans `Api.lua`).

---

## 3. Découpage proposé en modules ShikiUI

| Module | Contenu | Taille | Version |
|---|---|---|---|
| `units` (**fait**) | joueur, cible, cible de cible | M | v0.1 |
| `bars` | barres d'action, menu micro, formes, recharge | L | v0.2 |
| `chat` + `minimap` + `panel` + `tooltip` | interface de base visible partout | L | v0.3 |
| `castbar` + `auras` | incantation, buffs / debuffs, alerte de debuff (DebuffAlert) | L | v0.4 |
| `plates` + `Target` | plaques, menace colorée (TankPlates), service de ciblage | L | v0.5 |
| `group` + `classbits` | groupe de 5, focus, familier, points de combo… | M | v0.6 |
| `items` + `char` | ItemRack, TrinketMenu, ConsoHelper, feuille de personnage (BCS) | L | v0.7 |
| `loot` + `social` | LootBlare, jets, LazyPig, AutoInvite, WIM, amis | L | v0.8 |
| `mail` | TurtleMail | S | v0.8 |
| `combat` | HandGuard, OctoManaSwap évolué, TankSuite, Rinse, Call of Elements | L | v0.9 |
| `raid` | AutoMarker, RaidAuraWatch, ponts BigWigs / rt / Puppeteer | M | v0.9 |
| `bags` | sacs unifiés | **XL** | v1.0 |
| `skins` | habillage des fenêtres Blizzard et d'addons tiers | **XL** | v1.0 |
| `meter` | mesure de dégâts / menace | XL | v1.1+ |
| `heal` (cadres de raid de soin) | remplacement de Puppeteer | XL | v1.2+ |
| `ah` | hôtel des ventes (aux) | XL | v1.2+ |
| `rollfor` | réserves et jets | XL | v1.1+ |

**Trop gros pour une seule version** : RollFor (1,2 Mo), DPSMate (4,3 Mo), Puppeteer (0,9 Mo), aux, bags + skins, et toutes les bases de données (AtlasLoot, pfQuest : **jamais réécrites**, uniquement ponts). Chacun se découpe en versions « lecture d'abord, puis écriture ».
**Ponts plutôt que réécriture** : BigWigs, rt, AtlasLoot, pfQuest, ainsi que tout ce que l'utilisateur entretient déjà (OctoMeter, Shiki*) tant qu'ils servent.

Principe d'absorption (comme pour pfUI) : un module ShikiUI qui a un équivalent actif **attend** ; l'assistant (`/sui migrate`) indique quoi couper, bascule en un clic, et le retour arrière est un clic aussi. Même table `Migrate.MAP` pour les addons (noms de dossiers d'addons, via `IsAddOnLoaded`), pas seulement pour pfUI. **À faire quand le premier module d'addon arrive** (v0.7).

---

## 4. Ordre de travail recommandé (par usage réel)

1. **v0.2 barres d'action** — la plus visible, 7 barres chez lui, remplacement impossible sans elle.
2. **v0.3 chat + minimap + panneaux + infobulles** — le reste du quotidien.
3. **v0.4 incantation + auras (+ DebuffAlert) + pont Shiki\***.
4. **v0.5 plaques + service de ciblage + TankPlates**.
5. **v0.6 groupe de 5**, puis seulement ensuite le raid (**Puppeteer reste en place** tant que `heal` n'existe pas).
6. **v0.7 → v0.9** objets, butin / social, combat, raid (ponts).
7. **v1.0** sacs + skins ; **v1.1+** meter, RollFor ; **v1.2+** soin de raid, hôtel des ventes.

Rien de cette liste n'a été validé avec l'utilisateur au-delà de « remplacer pfUI et absorber ces addons » ; l'ordre est une proposition.

---

## 5. Non vérifié / à demander

- **En jeu** : tout. ShikiUI v0.1 n'a jamais tourné dans le client. L'écriture de `pfUI_config.disabled[...]` à l'exécution (et sa prise en compte au `/reload` sans être écrasée par un profil pfUI) est **supposée** d'après le code du chargeur lu, pas essayée.
- Les noms d'exécution `pfUI.module[...]` pour les modules autres que player / target / targettarget.
- La fonction exacte de plusieurs modules pfUI (voir remarque §1).
- Licences : DebuffAlert (GPL vs MIT), AutoMarkerOW (qui l'a écrit ?), ItemRack / TrinketMenu / RollFor (forks : aucune licence de l'amont relevée dans les dossiers, à vérifier sur les dépôts d'origine si publication).
- Usage « réel » : déduit de ce qui est installé et des SavedVariables, **pas** d'un journal d'utilisation. Les fichiers `AddOns.txt` des personnages sont trop hétérogènes pour en tirer un classement fiable ; l'utilisateur peut corriger les priorités.
- Question à poser : CallOfElements n'est installé que dans `octowow` (pas `octoc`) — le garder dans le périmètre ? L'ami en Élémentaire l'utilise-t-il ?
