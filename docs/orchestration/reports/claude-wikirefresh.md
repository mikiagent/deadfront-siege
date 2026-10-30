# claude-wikirefresh: roadmap progress and wiki update (2026-10-30)

## Roadmap progress (canon `claude/mmo-overhaul` at 4aa0ba62)

| Phase | done | next | later | decided against |
|---|---|---|---|---|
| 0 Foundations | 14 | 2 | 0 | 0 |
| 1 Core loop: gather, loot, craft, skills, build | 26 | 1 | 7 | 0 |
| 2 Survive, fight, capture, ride | 35 | 2 | 8 | 0 |
| 3 Islands and look | 11 | 5 | 6 | 0 |
| 4 Progression breadth and economy | 5 | 1 | 10 | 0 |
| 5 Online and late horizon | 1 | 1 | 10 | 0 |
| 6 Polish and tuning | 10 | 3 | 10 | 5 |
| 7 Hex HUD and screens | 12 | 0 | 1 | 0 |

**Done since the last refresh (d0c649fa, 2026-10-29):** island shapes, landmarks (M1-M3), island
reset (M4), resource matrix (M5), unstable isles, north-up camera; tutorial perf, tutorial town, perf
pass 2, loading screens, dev quick start; Food Bag and torpor capture, hunger rework, alpha tag,
creature chips, chase sprint, styracosaurus tactics, auto-ability, knife fixes; slower levels, Task
screen, tribe M2a, HUD redraw; wiki steward.

**In progress:** factions (`claude/mmo-factions`), tutorial town polish loop (`claude/mmo-townpolish`).
Neither branch was on origin when checked.

**Next:** island resources M6 fun pass (Milan's play), taming pen care, country-like islands, zone
content, ground painting, light and grade, level-up flash, item icons, tribes beyond M2a, perf gates.
Multiplayer stays deferred.

## What changed

Branch `claude/mmo-wikirefresh` from `origin/claude/mmo-overhaul` 4aa0ba62. Docs and wiki data only.

### Roadmap (`tools/docs_wiki/phase-map.json`)
- Set done with a note and `evidence` (merge commit, report, test, screenshot where one exists):
  slow-levels, task-screen, alpha-tag, hunger-rework, food-torpor, island-shapes, tutorial-perf,
  tutorial-town, tribe-m2a, island-rotation (ISLAND RESET M4 shipped its 6/12/24 h clocks and reroll).
- New rows: wiki-steward, dev-quickstart (P0); knife-fix (P1); creature-chips, chase-sprint,
  styra-tactics, auto-ability (P2); north-up, island-landmarks, island-matrix, island-fun-pass (next)
  (P3); unstable-isles, factions (next) (P4); loading-screens, perf2, tutorial-town-polish (next) (P6);
  hud-redraw (P7). Every source is a repo file.
- Notes updated, status kept: taming-pen (torpor capture landed, care still to do), country-islands
  (whether ISLANDSHAPES closes it is Milan's call), zone-terrain, perf-gates.
- Evidence back-filled on older done rows from merge hashes in their notes or a matching
  `Merge <PACKAGE>` commit; every `commit:` entry was checked to be an ancestor of canon.
- `updated` 2026-10-30, `seed_note` names the canon head.

### Audit (`python3 tools/docs_wiki/phase_map.py audit`)
- Before: 20 next-and-buildable, 1 next-but-blocked (tribe-m2a), 90 done without evidence.
- After: 15 next-and-buildable, 0 blocked, 16 done without evidence. The 16 (data-twins, save-schema,
  claim-interact, build-system, inventory-screens, construction-quality, survivor-core,
  creature-roster, cargo-warp, exchange-ui, hamburger-menu, phone-hud, web-pack, ui-build-row,
  ui-sheets, ui-stretched-sheets) name no merge I could tie to a commit; they need someone who knows
  their provenance.

### docs/current
- `world-biomes.md`, `items-traits.md`, `recipes.md`: generated sections refreshed from today's data
  (16 islands incl. `tutorial_isle`, per-climate landmark lists, ResinPine, 277 items, 196 recipes,
  21 fauna species). The generator does not keep hand-written sections, so I ran it into a scratch dir
  and spliced only its sections into the pages, keeping every hand section and the hand paragraphs in
  the preamble. `game/data_sheets/*.csv` were **not** touched: six differ from the data (climates,
  creatures, foods, islands, items, recipes) and the generator refuses to overwrite them; they may
  hold unsynced owner edits. Someone should run `sync_game_data.py` or decide on `--force-sheets`.
- `world-biomes.md`: new section on landmarks, island reset, the M5 matrix and unstable isles; the
  tutorial dock now follows the south rule (TUTTOWN); camera faces north (NORTHUP).
- `saves-persistence.md`: save keys `warp_gems`, `tribe`, `tasks`, `tutorial`, `landmarks`,
  `expeditions`, `drift`.
- `ui-screens.md`: Task screen (replaces Orders), Loading screen section, dev quick start; nav entry
  reads Tasks.
- `hud.md`: north-up minimap and Y = -Z readout; creature status chips with stack badges, plate height
  114.
- `controls.md`: auto-ability hex desktop position after NORTHFOLLOW.
- `inventory-bags.md`: Food Bag section; a Lock no longer blocks tool use, broken-knife reason, stone
  knife durability 120.
- `survival-needs.md`: washing works in the sea (was "the salt sea offers none").
- `tutorial.md`: TUTPERF and PERF2 performance notes.
- Packages whose pages were already current: SLOWLEVELS, HUNGER, ALPHATAG, AUTOABILITY, CHASESPRINT,
  STYRATACTICS, TRIBEM2A, TUTTOWN, FOODTORPOR (creatures page), HUDREDRAW.

### STATUS.md
Dated 2026-10-30 section added at the top of `docs/orchestration/mmo/STATUS.md`; the archived body is
unchanged.

## Checks
- `python3 tools/docs_wiki/phase_map.py check`: OK.
- `python3 -m unittest discover -s tools/docs_wiki -p "test_*.py"`: 52 tests OK.
- `python3 tools/docs_wiki/docs_wiki.py index`: 242 docs, 0 cross-line diffs.
- No game code changed, so no Godot run.

## For the next agent
- `docs/design/island-resources.md` (the M1-M6 plan) is only on `claude/mmo-island-resources-doc`;
  roadmap rows cite `docs/current/world-biomes.md` and `docs/design/unstable-isles.md` until it lands.
- When factions or town polish merge, set their rows done with evidence.
- Credits spent: none.
