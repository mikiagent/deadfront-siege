# Cursor M7 — cooking, food, and farming

Cooking process chain (skewer → sashimi-steam-steam, boil uprank), eat-with-Full cancel UI, food inspector, buff meals, BuildGrid fields with offline growth, pet feed, and `--lab=kitchen_lab`.

## What shipped

### Food model
- `game/scripts/items/food.gd` — energy = `base × (1 + 0.35 × process_count)` via scaled `food_energy`; raw/poisoned inspector; raw risks (`stomachache`, `tastes_bad`); pet feed (hunger += energy × 10).
- `game/scripts/items/eat_session.gd` + `game/scripts/ui/eat_progress.gd` — 3 s eat, progress ring, **Keep still** hint; move cancels remaining restore and still applies `full` (10 s).
- `game/scripts/ui/food_inspector.gd` — energy / level / process / buffs / RAW / POISONED before eat.
- Inventory: Inspect food / Eat / Feed pet (64 px targets).
- Statuses: `full`, `stomachache`, `tastes_bad` in `statuses.json`.
- ItemDef: `raw`, `poison_chance`, `tastes_bad_chance`, `food_buff`.

### Cooking
- Recipes: meatball (mortar→bonfire), stone grill (burn chance → `burnt_food`), steam (`keep_output_id` stacks process), sashimi (1→3, `force_process_count` 2), boil (mean-of-materials uprank), roast / seasoned roast, buff meals, pet feeds, field kits, fill bucket at well.
- `Crafting.build_output` — poison persists, burn-on-fail, force/keep process, buff attribute, skill level from `player.skills` when > 0.
- Stations: `mortar`, `stone_grill`, `steamer`, `well` as `CraftStation` (reuse station radial + CraftCard).

### Farming
- `game/data/farming.json` + `game/scripts/world/field_plot.gd` — plant / water / fertilise / harvest via GatherRadial hex options; water raises success; fertilizer raises yield with overflow; output level capped by Farming skill; offline catch-up on load.
- Save schema **3**; field crop state in building `to_dict`; `SaveGame` restores `field_small` / `field_large`.

### Buff food
- `game/data/food_buffs.json` — gather_speed / defense / cold_resist / heat_resist; applied on finish eat.

### Lab
- `--lab=kitchen_lab`: bonfire, mortar, grill, steamer, well, field, seeds, raw meat/fish, lv40 water; F6 growth +60 s; F7 eat-cancel.
- Headless prints acceptance evidence (below).

## Acceptance
| Check | Evidence |
|---|---|
| Sashimi-steam-steam highest energy/raw | `per_meat=110.9 vs skewer=30.0` / `sashimi-steam-steam wins energy/raw` |
| Skewer never > 19 | `skewer level=19 (cap 19)` from lv40 meat |
| Boil lv20 meat + lv40 water ≈ 30 | `boil level=30 (want ~30)` |
| Move while eating cancels + Full + UI | `eat UI keep-still visible=true`, `eat cancel … full=true` |
| Flax field water/fert/harvest/overflow/save | `harvest flax x4 lv5 overflow=0.7`, `replant fert_carried=0.7`, `save/load … schema=3` |
| Smoke | `SMOKE PASS` |

## Needs from other agents (owned files)
- **`build_placer.gd`**: wire `_kit_id` / `_spawn` / `_pay` for `field_small`, `field_large`, `mortar`, `stone_grill`, `steamer`, `well` so bag kits place through BuildGrid (lab spawns them directly today).
- Optional: tap-routing already reaches `placed_building` → `_building_interact` for fields; CraftStations already open via existing tap/interact.

## Assumptions
- Process energy factor 0.35 (prompt design).
- Grill burn chance 0.2 → `burnt_food` with negative energy.
- Field growth seconds from `farming.json` (flax 120 s); lab force-matures when needed.
- Fertilizer: each whole yield bonus unit consumes 1.0 fertilizer; fraction overflows.
- Cooking skill 0 still crafts at cap 60 for labs until SP spent; skewer `max_level` 19 still clamps.

## Credits
Meshy credits spent: 0.
