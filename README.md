# ShikiUI

**A complete interface suite for WoW 1.12 (Turtle WoW / OctoWoW), built from scratch** — and the optional data packages that power its Codex and quest tools.

English · [Français](README.fr.md)

ShikiUI is **one addon plus four generated data addons**, released together as a single zip. The UI works on its own; the data packages
unlock the **Codex** (dungeon loot, sets, reputations, quests, monsters) and the **quest tools** (map pins, minimap pins, direction arrow).
Native French and English (works with a French or an English client), themed styles, Simple/Expert menu, raid mode.

> Personal project by Shikiwa (speedy8182), developed with AI assistance.

## What is Shiki?

**ShikiUI** is the interface: one addon that replaces a whole pile of separate ones. Unit frames, action bars, nameplates, bags, chat,
minimap, tooltips, damage meter, boss alerts, auction house, mail… each one is a module you can switch on or off, move and restyle from a single
menu (`/sui`). Everything is written for the 1.12 client, in French and English.

**ShikiCodex** is the game encyclopedia built into ShikiUI — a window (the **Codex** button on the minimap, or `/sui codex`) plus the data behind it.
You look something up, and the Codex shows it *and* puts it on your map:

- *"Where does this item drop?"* — dungeon and raid loot, sets, reputation rewards.
- *"Where do I go for this quest?"* — your quest log with a direction arrow, "!" and "?" pins on the world map and the minimap.
- *"Where do I find this monster?"* — search by name, see its levels and pin its spawn points.
- *"Where is the nearest vendor, mailbox or flight master?"* — place pins for vendors, mailboxes, flight masters, herbs, ore and trainers.

Because that data is big, it is **not inside ShikiUI**: it ships as four separate *ShikiCodexData* addons that load only when you open the Codex
or a map. That is why ShikiUI is a **suite of packages** — the interface on one side, the Codex data on the other, installed together from one zip.

## The packages

```
                     ┌────────────────────────────┐
                     │          ShikiUI           │  the interface: 48 modules, /sui menu,
                     │        (required)          │  quest tracker, Codex window
                     └─────────────┬──────────────┘
          loaded on demand, only when the Codex or a map needs them
        ┌───────────────┬──────────┴──────────┬────────────────┐
┌───────┴───────┐ ┌─────┴──────────┐ ┌────────┴───────┐ ┌──────┴────────┐
│ShikiCodexData │ │…Data_Quests    │ │…Data_Places    │ │…Data_Mobs     │
│ loot, sets,   │ │ quests, pins,  │ │ vendors, mail- │ │ monsters,     │
│ reputations,  │ │ arrow          │ │ boxes, flight  │ │ levels, spawn │
│ attunements   │ │                │ │ masters, herbs │ │ points, loot  │
└───────────────┘ └────────────────┘ └────────────────┘ └───────────────┘
```

| Folder | What it is | Needed for | Licence |
|---|---|---|---|
| `ShikiUI` | The interface: menu, modules, quest tracker, Codex window | everything | MIT |
| `ShikiCodexData` | Dungeon and raid loot, set pages, reputations, attunements, item names | Codex tabs *Dungeons / Sets / Reputations* | GPL v2 (derived from Atlas-CFM) |
| `ShikiCodexData_Quests` | Quest titles, levels, NPCs, map and minimap pin coordinates | quests in the Codex, "!" / "?" pins, direction arrow | GPL v2 (derived from Atlas-CFM) + MIT (pfQuest) |
| `ShikiCodexData_Places` | Useful places: vendors, mailboxes, flight masters, herbs, ore, trainers… | place pins on the maps | MIT (pfQuest) |
| `ShikiCodexData_Mobs` | Monsters: names, levels, map points, who drops what | monster search in the Codex (pins on maps) | MIT (pfQuest) |

The four `ShikiCodexData*` folders are **generated data**, never edited by hand (`tools/build_codex_data.js`, `tools/build_places.js`,
`tools/build_mobs.js`), and **load on demand**: they cost no memory or load time until you open the Codex or a map. Without them ShikiUI works
normally, but the Codex and the quest pins stay empty. All five share the same version number. Sources and credits: Atlas-CFM,
pfQuest and pfQuest-octo-plus — see each folder's `NOTICE.txt`.

## Install

**Manual** — download `ShikiUI-vX.Y.Z.zip` from the [latest release](https://github.com/ShikawaLePaladin/ShikiUI/releases/latest), extract it into
`Interface\AddOns\` (the **five folders** sit at the root of the zip) and restart the game (new addons need a full restart the first time; `/reload`
is enough afterwards).

**OctoLauncher** — add `https://github.com/ShikawaLePaladin/ShikiUI` (installs `ShikiUI`), then the data packages through their branches:
`…/ShikiUI/tree/codexdata`, `…/tree/codexdata-quests`, `…/tree/codexdata-places`, `…/tree/codexdata-mobs`.
If your launcher does not handle branches, take the folders from the release zip.

Main command: **`/sui`** (menu, first-run wizard included). Codex: the **Codex** button on the minimap, or `/sui codex`.

## What the Codex packages give you

- **Codex window** — search an item, a quest or a monster; browse dungeon and raid loot, sets and reputation rewards.
- **Quest tracker** — your quest log on screen with a small arrow button per quest; the **direction arrow** follows the nearest objective
  (or the quest you pick) and turns into an icon when you are close: sword to fight, "?" to turn in, "!" to pick up, bag to collect.
- **Pins on the world map and the minimap** — objectives, "!" quest givers, "?" turn-ins (gold and pulsing when the quest is complete, white
  while it is still in progress), vendors, mailboxes, flight masters, herbs, ore.
- **Quest-mob markers** — a "!" on nameplates and on the target frame for monsters you need to kill, and a green line in their tooltip.
- **Monster search** — find a monster by name (French or English), see its levels and pin where it lives.

## Main modules (ShikiUI)

| Category | Modules |
|---|---|
| **Units** | Player/target frames, party, 40-man raid, raid marks (quick targeting), nameplates |
| **Combat** | Damage meter, threat, TankTools, cast bar, PowerAuras, click-healing, totems |
| **Utilities** | Bags, auction house (4 tabs), mail, auto-vendor, loot, macros, group finder |
| **Raid** | **Boss alerts (BossMods)** — bars and announcements for vanilla MC / BWL / ZG / AQ / Naxx |
| **Social** | WIM-style whispers, chat (keywords, tabs), PvP, bulletin |
| **Tracking** | Instance lockouts, session gold, automatic specs per profile |
| **World** | Codex, quest tracker, map and minimap pins, minimap button drawer |

Every module can be switched on or off, has its own settings (Simple mode by default, Expert for everything), conditional visibility
(always / combat / group / raid / spec…) and free positioning (`/sui move`).

## Standalone addons (without ShikiUI)

**ShikiPallyPower** (paladin blessings) and **ShikiFinder** (group finder) also exist as separate addons in `standalone/`, for players who do not
use ShikiUI. See [standalone/README.md](standalone/README.md).

## Commands

```
/sui                     main menu
/sui codex               Codex window
/sui quests arrow        test target for the direction arrow
/sui bossmods            raid alerts
/sui marks               raid marks
/sui pp                  raid blessings (paladin)
/sui lfg                 group finder
/sui move                move the interface
/sui help                full help
```

## Development

Tests run offline under Node (Lua 5.0 emulated with fengari): structure, Lua 5.0 lint, translations, styles and the module suites.

```bash
sh tests/run_tests.sh                     # everything
node tools/build_codex_data.js --check    # Codex data up to date with the sources (needs the game's AddOns folder)
node tools/build_mobs.js --check          # same for the monster data
```

- **Core** (`Core`, `Config`, `Theme`, `Mover`, `Visibility`, `Layouts`…): shared services, never touched by modules.
- **Modules** (`Mod_<Name>.lua` + `Locale_<Name>.lua`): isolated, contract-based — see `MODULES.md`.
- **Conventions**: strict Lua 5.0, no hard-coded colours or textures (style tokens), nothing created in combat, positions through the
  layout service, FR/EN translations checked.

`SPEC.md` describes the architecture, `PARITY.md` the parity with reference addons, `MODULES.md` the module contract and the state of each module.

## Licence

The code (`ShikiUI/`, `standalone/`) is MIT — see `LICENSE`. Each data folder carries its own `NOTICE.txt` (and `LICENSE` where GPL v2
applies); the data packages are separate works and do not change the licence of the UI code.
