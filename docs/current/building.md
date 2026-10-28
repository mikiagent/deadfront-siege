# Building & construction quality

Present-tense facts only. Owner spec: `docs/design/durango-prompts/10_construction_building_quality.md`
(§§2-3, 6) and `30_building_construction_and_crafting_stations.md` (§§4-10).

## Two building paths

| Path | Code | Cost |
|---|---|---|
| Modular piece (foundation, wall, doorway, door, window, ceiling, roof, pillar, stairs, ramp, chest, large box, sign) | `game/scripts/world/structure_placer.gd` → `StructurePiece` | exact item instances from the bag, least valuable first (`Inventory.spend_key`) |
| Blueprint → construction site → station (workbench, comm center, …) | `game/scripts/items/build_flow.gd` + `ConstructionSite` → `CraftStation` | exact instances deposited into the site's escrow |

Both compute quality with `game/scripts/world/building_quality.gd` (`BuildingQuality`). Definitions
live in `game/data/structures.json` (`piece_tiers`, `placed_kinds`, `quality`) and
`game/data/blueprints.json`.

## Level (spec 10 §2)

```
avg   = floor(mean of the levels of every level-contributing unit)
level = min( clamp(avg, blueprint minimum_level, blueprint maximum_level), Construction category level )
```

- A unit counts when its slot row says `counts_for_level` / `level_contributing`, else when the row's
  role is `primary`/`main` (structures.json `material_slots`, blueprints.json `slots`).
- `ConstructionSite.contributing_levels()` collects one entry per deposited unit;
  `Blueprints.result_level()` does the arithmetic (blueprint rows) and
  `BuildingQuality.level()` the same for piece rows.
- No level-contributing units: level **1** (`# ASSUMPTION`).
- Pieces: `StructurePlacer.material_levels()` reads the exact bag units the payment will spend, so
  the level a piece gets matches what it took (`StructurePlacer.apply_quality`).
- A piece keeps its level through a tier upgrade (`StructurePiece.set_tier`); `# ASSUMPTION`, the
  spec gives no re-levelling rule.

## Traits (spec 10 §3)

- Only the **first unit of the first primary/main slot** passes traits
  (`BuildingQuality.primary_traits`). Binding/support materials never pass.
- Traits are `Inventory.traits()` (attributes that are not the def's defaults and not bookkeeping).
  Only positive levels carry; everything is stored as `[{id, level}]`.
- A trait does something only when the blueprint lists its effect in `supported_building_effects`
  (a piece with `storage_slots` counts as supporting `storage_space`). Unsupported traits are still
  carried and shown as "(no effect here)".

Effect table (`structures.json` → `quality.attributes`, amounts `# ASSUMPTION` from the spec's
reconstruction references):

| Trait | Effect | Per level |
|---|---|---|
| High Density / Compact Structure | durability | +2 / +1 |
| Low Density / Weak Structure | durability | −2 / −1 |
| Lightweight / Heavy | storage spaces | +3 / −3 |
| Beautiful Pattern / Messy Pattern | comfort | +1 / −1 |
| Strong / Weak Disinfectant | antibiotic | +1 / −1 |
| Firm / Soft | building attack | +1 / −1 |

Rare station traits (`quality.station_rare`, `# ASSUMPTION` which rare id carries which effect):

| Rare trait | Effect | Per level |
|---|---|---|
| Split Easily | job duration × (1 − 0.05·level) | `ProcessStation.effective_seconds` |
| Vivid Inspiration | +1 concurrent job slot | `ProcessStation.slots()` |

Durability effects raise `max_hp` (`StructurePiece.apply_quality`, `CraftStation._apply_quality_health`).
Storage effects resize the piece's container by `grow_to`, and shrink only into empty slots
(`StructurePiece.apply_storage_bonus`) so stored items are never deleted.

## Fires: the permanent firepit and the temporary fires

Three kit-placed fires share `game/scripts/world/bonfire.gd` (`Bonfire`); their numbers live in
`structures.json` → `placed_kinds.<kind>` and are `# ASSUMPTION` (docs 10, 30 and 08 give none).

| Kind | Kit | Permanent | Wood | Fuel |
|---|---|---|---|---|
| `stone_fire_pit` | `stone_fire_pit_kit` | yes, never decays | hidden until wood is loaded | 1 branch = 120 s, up to 600 s |
| `bonfire` | `bonfire_kit` | no | shown from placement | lit with 600 s, burns out |
| `campfire` | `campfire_kit` | no | shown from placement | lit with 120 s, burns out |

- **The permanent pit.** Its Blender model bakes wood and a spit into the mesh, so `Bonfire` hides
  that model and draws its own two-course stone ring. `WoodPile` and `Flame` are separate nodes shown
  only while `fuel_seconds > 0`. `load_wood(player)` spends one `branch` for
  `wood_seconds_per_branch`; when the fuel runs out the wood and flame go and the rocks stay.
- **Temporary fires** burn down every frame, wear `durability_per_minute` (1/min), wear twice as fast
  when the fire stands outside a Domain (the same claim check `BuildGrid.can_place` uses), and are
  removed at burn-out or at 0 durability — the game has no ash state.
- **Cooking** works only while a fire burns: `Bonfire.can_cook()` / `cook_block_reason()`,
  `StationMenu.filter_actions` drops the COOK hex and `StationMenu._on_pressed` refuses the press.
- **LOAD WOOD** is a hex on every fire (`StationMenu.actions_for` → `Bonfire.load_wood`); hidden once
  full. The menu also prints the fire's state line (`info_lines`: `Fuel m:ss · Burning/Out` and
  `Durability cur/max` for temporary fires).
- **Save.** Rows carry `fuel_seconds` and `durability` (the campfire still mirrors `seconds_left`);
  `SaveSanitizer` keeps both fields, and a row without them loads a lit, whole fire.

## Where it is visible

- Piece card: `StructureSheet.fill_card` shows `Lv N · High Density 3` plus one line per trait
  ("High Density Lv 3: +6 durability", "(no effect here)").
- Site: `ConstructionSite.contributing_traits()` / `preview_effects()` / `preview_level()` (the site
  sheet prints the deposited instances' levels per slot).
- Station: HUD chip falls back to `CraftStation.quality_chip_text()` when idle, which reads
  `ProcessStation.label_text()`.

## Persistence

- Piece rows carry `level`, `inherited_attributes`, `quality_durability`, `quality_storage`
  (`StructurePiece.to_dict`); loading clamps them, drops malformed trait rows, and a row from before
  quality loads as level 1, no traits (`StructurePiece.from_dict`).
- Station rows carry `station_level`, `inherited_attributes`, `quality_durability`,
  `quality_duration_mult`, `quality_slots` (`CraftStation.to_dict` / `from_dict`); an old row keeps
  its `station_level` and gets no traits.
- Site escrow is saved as the exact instances (`ConstructionSite.to_dict`), so a reload finishes at
  the same level.

## Tests

- `game/tests/t_buildquality.gd` — level formula and caps, contributing units, primary-only traits,
  lv-10 vs lv-1 wall, durability/storage effects, unsupported effects, save/load, old rows, a mixed
  material site (20,20,12,12 → 16) finishing into a station with a shorter job and a repackaged one.
- `game/tests/t_buildsys.gd`, `t_buildflow.gd`, `t_build.gd` — placement, costs, support/collapse,
  repair/upgrade, rows, site escrow and completion.
- `game/tests/t_firepits.gd` — the fires: empty vs loaded pit, temporary burn-out and wear (2× outside a
  Domain), the cooking gate and hex menu, the info line, and the save round trip through the sanitizer.
