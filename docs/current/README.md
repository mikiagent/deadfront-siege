# Current implementation — what the build does today

One short doc per system, containing only present-tense facts and numbers, each citing the code
path that owns it. The audience is a fresh session (human or agent): read this instead of
trawling history. When the build changes a system, update its doc in the same commit.

| System | Doc | State |
|---|---|---|
| Survival needs (health, stamina, exhaustion) | [survival-needs.md](survival-needs.md) | **written 2026-10-27** — vitals trio + strain tiers, fatigue-status table, food relief & autofeed, sleep spots, day clock |
| HUD & vitals UI | [hud.md](hud.md) | **written 2026-10-27** — layout zones per canvas, combat layer, treadmill belt, day/night dial, fatigue panel & banners |
| Controls & input | [controls.md](controls.md) | truth inherited from the old layout (moves with any `input_setup.gd` change) |
| Items, traits & food effects | [items-traits.md](items-traits.md) | **generated 2026-10-27** — 240-item catalog, rarity/attrs, FOODFX with provenance tags; *editable source*: `game/data_sheets/items.csv` + `foods.csv` (canon) |
| Crafting & processing | [recipes.md](recipes.md) | **generated 2026-10-27** — 168 recipes grouped by station + 8 repair tiers; *editable source*: `game/data_sheets/recipes.csv` + `repairs.csv` + `processing.csv` (canon) |
| World, islands, climate, flora & fauna | [world-biomes.md](world-biomes.md) | **generated 2026-10-27** — 15 islands, 10 climates with flora/materials, 19 fauna, butchering per species; *editable source*: `game/data_sheets/islands.csv` + `climates.csv` + `creatures.csv` + `butchering.csv` (canon) |
| Inventory, bags, storage, multi-select & locks | [inventory-bags.md](inventory-bags.md) | **written 2026-10-28** — instance/uids, stacking categories, 5 bag types + capacity curves, 7 storage containers, batch lock/drop/destroy, save rows & load migration |
| Creatures, AI, capture & taming | [creatures-capture-taming.md](creatures-capture-taming.md) | **written 2026-10-28** — 19-species roster table, 10 AI states + archetypes, spawns & 24 cap, capture rule (stunned at any HP or ≤30 %, net tier, tied-to-technique chance), field tame, pen, bonded cap, pets & mounts |
| Creature rigs and clips | [creature-clips.md](creature-clips.md) | **generated 2026-10-28** — per species: jaw, wings, and which of the 25 clips ship (bite_combo, leaps, dodges, strafes, walk_back, kick, charge...) |
| Saves & persistence | [saves-persistence.md](saves-persistence.md) | **written 2026-10-28** — `user://save_1.json` under the override.cfg user dir, schema 4 + 4 migrations, key table, sanitizer clamps, .bak/quarantine rescue, 60 s autosave |
| Server & multiplayer contract | [server-contract.md](server-contract.md) | **written 2026-10-28** — local in-process engine only (no transport/auth/presence), 12 client + 5 system ops, journal+snapshot store, WorldFacade |
| Economy & trading | [economy-trading.md](economy-trading.md) | **written 2026-10-28** — single T-stone int, 2 sinks (sail cost, 2-stone cargo warp) + 3 sources, market.json data only (no market UI or engine) |
| UI screens (every screen, phone landscape) | [ui-screens.md](ui-screens.md) | **captured 2026-10-28** — 31 shots at 844x390 drawn 2x, rerun `tools/ui_screens.sh` |

*(Sheets live in the canon worktree's `game/data_sheets/` — nine CSVs the owner can edit in any
spreadsheet app, synced back into `game/data/*.json` by the agent. The three generated pages come
from `tools/docs_wiki/gen_game_data.py`; re-run it after any balance pass or accepted sheet sync.)*

Rules for this folder:
- Facts, ranges, code paths — no history, no "why", no design debate. The past lives in deep
  docs; the future in `../vision/`.
- Every number in a doc must be traceable to a constant in a named file (or a rules.json key).
- Keep each doc under ~120 lines; a system's truth should fit on one screen or a table.
