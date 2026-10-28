# Task: CURRENTDOCS — write the five missing current-implementation pages

docs/current/README.md lists five systems as "needs writing". Write them, in the exact style of the existing pages
(read docs/current/README.md "Rules for this folder", then docs/current/survival-needs.md and docs/current/hud.md as
models): present-tense facts and numbers only, each number traceable to a constant in a named file or a rules.json key,
no history, no "why", no design debate, no plans. Under ~120 lines each. Cite code as `game/scripts/...gd` paths
(backticked) and functions as `name()` only when that func exists.

Pages (file names are fixed; the gate checks them):
1. docs/current/inventory-bags.md — instance inventory (uids, no stacking by name, which categories still stack),
   bag slots/capacity, bag types and levels (game/data/bags.json, inventory.json), storage/containers, multi-select,
   locking, home cargo/basket, how saves store it. Code: game/scripts/items/, game/scripts/ui/bag_grid.gd etc.
2. docs/current/creatures-capture-taming.md — species roster in data, brains/AI states, spawns, capture rule as the
   code has it TODAY (do not describe pending changes), nets and techniques, field tame, pen, bonded cap, pets, mounts.
   Code: game/scripts/creatures/, game/scripts/pets/, game/scripts/combat/hunt.gd.
3. docs/current/saves-persistence.md — save file location(s), schema/rev numbers, what is saved, migrations, rescue,
   autosave cadence, override.cfg user dir. Code: game/scripts/core/save_game.gd, save_sanitizer.gd.
4. docs/current/server-contract.md — what game/scripts/server/ does today (local only, no host), intents handled,
   character store, auth/presence if present on this line. Say plainly what is NOT on this line.
5. docs/current/economy-trading.md — T-stones and other currencies, sinks that exist (cargo warp fee...), market data
   (game/data/world/market.json) and whether any market UI/engine is live on this line (it may not be: say so).

Then update docs/current/README.md: each row links its page with a short state like the others ("written 2026-10-28 — ...").
Do not edit any other file. Read code to get facts; do not guess. If something is unclear, write what the code does and
mark it "unverified" rather than inventing.

Milestones (.dsc/PLAN.md, milestone_done after each): M1 pages 1-2. M2 pages 3-5. M3 README rows + full verify.
Verify: the given --verify command (it checks length, real paths, real func names, README, scope). Do not run Godot.
Do not merge, push or deploy. Write a short report at docs/orchestration/reports/dsc-currentdocs.md.
