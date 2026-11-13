# ShikiUI

Interface complète pour WoW 1.12 (Turtle WoW / OctoWow), écrite de zéro. Un socle léger (un seul timer,
un routeur d'événements), 35+ modules activables, menu Simple/Expert, bilingue **FR/EN** natif
(fonctionne avec le jeu en français ou en anglais), styles thématisés et mode Raid.

> Addon personnel de Shikiwa (speedy8182) — développement assisté par IA.

## Installation

1. Copier le dossier `ShikiUI/` dans `Interface/AddOns/`
2. `/reload`
3. Commande principale : **`/sui`** (menu) — assistant de premier lancement inclus

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
