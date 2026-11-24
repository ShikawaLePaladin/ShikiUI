# ShikiUI

Interface complète pour WoW 1.12 (Turtle WoW / OctoWow), écrite de zéro. Un socle léger (un seul timer,
un routeur d'événements), 35+ modules activables, menu Simple/Expert, bilingue **FR/EN** natif
(fonctionne avec le jeu en français ou en anglais), styles thématisés et mode Raid.

> Addon personnel de Shikiwa (speedy8182) — développement assisté par IA.

## Installation

Le zip de la release contient **4 dossiers** a copier ensemble dans `Interface\AddOns\` :

| Dossier | Role | Obligatoire ? |
|---|---|---|
| `ShikiUI` | l'interface (menu, modules, Codex, suivi de quetes...) | **oui** |
| `ShikiCodexData` | donnees du Codex : butin des donjons et raids, sets, reputations, attunements | pour le Codex (onglets Donjons, Sets, Reputations) |
| `ShikiCodexData_Quests` | donnees de quetes : titres, niveaux, PNJ, epingles de carte et de minicarte, fleche | pour les quetes dans le Codex, les "!" sur les cartes, la fleche |
| `ShikiCodexData_Places` | lieux utiles : marchands, boites aux lettres, maitres de vol, herbes, minerais... | pour les epingles de lieux sur les cartes |

Les trois dossiers `ShikiCodexData*` sont des **donnees generees** (jamais modifiees a la main) ; ils sont charges *a la demande* :
ils ne coutent ni memoire ni temps de chargement tant que tu n'ouvres pas le Codex ou une carte. Sans eux, ShikiUI fonctionne
normalement mais le Codex et les epingles de quetes restent vides. Ils portent le meme numero de version que ShikiUI.

**Manuel** : dezipper `ShikiUI-v1.2.3.zip` dans `Interface\AddOns\` (les 4 dossiers sont a la racine du zip), puis relancer le jeu
(un nouvel addon demande un redemarrage complet la premiere fois ; ensuite `/reload` suffit).

**OctoLauncher** : ajouter le lien `https://github.com/ShikawaLePaladin/ShikiUI` (installe `ShikiUI`), puis les donnees via leurs branches :
`https://github.com/ShikawaLePaladin/ShikiUI/tree/codexdata`, `.../tree/codexdata-quests`, `.../tree/codexdata-places`.
Si le lanceur ne gere pas les branches, prendre les dossiers dans le zip de la release.

Commande principale : **`/sui`** (menu) — assistant de premier lancement inclus. Codex : bouton **Codex** de la minicarte ou `/sui codex`.

### English

The release zip contains **4 folders**; copy them together into `Interface\AddOns\`:
`ShikiUI` (the addon, required) and three *generated, load-on-demand* data addons: `ShikiCodexData` (dungeon/raid loot, sets,
reputations, attunements), `ShikiCodexData_Quests` (quest data for the Codex, "!" pins and the arrow) and `ShikiCodexData_Places`
(vendors, mailboxes, flight masters, herbs, ore...). They cost nothing until the Codex or a map needs them; without them ShikiUI works
but the Codex and quest pins stay empty. Restart the game fully the first time (new addons). Main command: `/sui`.

## Modules principaux

| Catégorie | Modules |
|---|---|
| **Unités** | Cadres joueur/cible, Groupe, Raid 40, marques de raid (ciblage rapide) |
| **Combat** | Compteur (meter), Menace, TankTools, CastBar, PowerAuras, Soins au clic, Totems |
| **Utilitaires** | Sacs, Hôtel des ventes (4 onglets), Courrier, Vendeur auto, Loot, Macros, Chercheur de groupe |
| **Raid** | **Alarmes de boss (BossMods)** — barres + annonces vanilla MC/BWL/ZG/AQ/Naxx |
| **Social** | Messages type WIM, Chat (mots-clés, onglets), PvP, Bulletin |
| **Suivi** | Verrous d'instances, or par session, specs auto par profil |

Chaque module est activable/coupable individuellement, a ses propres réglages
(mode Simple par défaut, Expert pour tout), sa visibilité conditionnelle
(toujours / combat / groupe / raid / spé...) et son déplacement libre (`/sui move`).

## Addons autonomes (sans ShikiUI)

**ShikiPallyPower** (bénédictions de paladin) et **ShikiFinder** (chercheur de groupe) existent aussi comme addons séparés dans `standalone/`,
pour les joueurs qui n'utilisent pas ShikiUI. Voir [standalone/README.md](standalone/README.md).

## Commandes

```
/sui                     menu principal
/sui bossmods            alarmes de raid
/sui marks               marques de raid
/sui pp                  bénédictions de raid (paladin)
/sui lfg                 chercheur de groupe
/sui move                déplacer l'interface
/sui help                aide complète
```

## Tests hors jeu

La suite de tests tourne sous Node (Lua 5.0 simulé via fengari) — 72 suites, ~13 000 assertions,
mutations anti-régression incluses :

```bash
sh tests/run_tests.sh     # tout : structure, lint, traductions, styles, suites
node tests/mutate.js      # chaque régression simulée doit être détectée
```

## Architecture

- **Socle** (`Core`, `Config`, `Theme`, `Mover`, `Visibility`, `Layouts`...) : services partagés,
  jamais touchés par les modules
- **Modules** (`Mod_<Nom>.lua` + `Locale_<Nom>.lua`) : isolés, contractuels — voir `MODULES.md`
- **Conventions** : Lua 5.0 strict, zéro couleur/texture en dur (jetons de style), rien de créé
  en combat, positions via le service de layout, traductions FR/EN contrôlées

`SPEC.md` détaille l'architecture, `PARITY.md` la parité avec les addons de référence,
`MODULES.md` le contrat de module et l'état de chacun.
