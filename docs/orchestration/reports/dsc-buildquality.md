# dsc — BUILDQUALITY (construction quality: building level from materials, traits to buildings)

Task: roadmap feature `construction-quality`, spec `docs/design/durango-prompts/10_construction_building_quality.md`
(§§2-3, 6) and `30_building_construction_and_crafting_stations.md` (§§4-10).

## What shipped

| File | Change |
|---|---|
| `game/scripts/world/building_quality.gd` (new) | `BuildingQuality`: `contributing_levels`, `level` (spec formula), `primary_traits`, `attribute_rows`, `effects`, `effect_lines`, `summary`, `supported`/`station_supported`, `clean_attrs` |
| `game/data/structures.json` | new `quality` block: attribute→effect table (per-level amounts) and `station_rare` |
| `game/scripts/world/structure_placer.gd` | `pick_units`/`pay` spend the least-valuable exact units; `material_levels`/`material_traits`; `apply_quality`; `quality_text`; `_supported` |
| `game/scripts/world/structure_piece.gd` | `quality_durability`/`quality_storage`, `apply_storage_bonus`, persisted + clamped in `to_dict`/`from_dict`, `set_tier` keeps trait durability |
| `game/scripts/world/construction_site.gd` | `contributing_traits`, `preview_effects` |
| `game/scripts/world/craft_station.gd` | `inherited_attributes`, `quality_*`, `_apply_quality_health`, `quality_text`, `quality_chip_text`, persisted |
| `game/scripts/world/process_station.gd` | `quality_duration_mult`, `quality_slots`, `effective_seconds`, slot bonus, idle chip quality text |
| `game/scripts/items/build_flow.gd` | completion sets the station's traits and effects before it enters the tree |
| `game/scripts/world/structure_sheet.gd` | `card_lines` + the piece card's quality/trait/capacity lines |
| `game/tests/t_buildquality.gd` (new) | acceptance suite (below) |
| `docs/current/building.md` (new) + index row | facts-only building doc |

## Behaviour, before → after

- Piece placement took materials by def id (`Inventory.consume`) and left `build_level = 1` on every
  piece, `inherited_attributes = []`. Now the payment spends the **least valuable exact units**
  (`Inventory.spend_key`) and the piece's level is `min(clamp(floor(mean), blueprint min/max),
  Construction)` of those units, with the primary material's traits.
  Example (test): a wood wall from Lv 10 planks/twine is **Lv 10**; from Lv 1, **Lv 1**.
- A blueprint site finished from mixed instances: `(20, 20, 12, 12)` → **Lv 16** station, preview
  equal to the finished level. Before, the same level was computed but no traits were carried and no
  station effect existed.
- Traits now do something only where the blueprint supports it: High Density Lv 3 on a wall →
  +6 max durability (1200 → 1206); Lightweight Lv 2 on a chest → +6 container slots (100 → 106);
  Heavy Lv 2 on a large box → −6 slots (never into an occupied slot); Lightweight on a **wall** does
  nothing and its card says "(no effect here)".
- Station rare effects: Split Easily Lv 2 → `trimmed_plank` 12 s → **10.8 s**; Vivid Inspiration
  Lv 1 → +1 concurrent job slot.
- Saves: piece rows now carry `level`, `inherited_attributes`, `quality_durability`,
  `quality_storage`; station rows carry the four `quality_*`/traits fields. A row **without** them
  loads as level 1, no traits (malformed trait rows clamped, junk dropped).

## Verification

- `t_buildquality`: PASS, exit 0, no SCRIPT ERROR (engine formula and caps, contributing units,
  primary-only traits, lv-10 vs lv-1 wall, durability/storage effects, unsupported effect, station
  durability + preview parity, save round trips, old rows, mixed material site → station, 10%
  shorter job, extra job slot, inspect text).
- `t_build`, `t_buildsys`, `t_buildflow`: PASS with no SCRIPT ERROR after the change.
- Full gate: see the runner's verify output for this task (stage 1 + stage 2).

## Shots

**None taken, deliberately.** The owner's `HEADLESS_ONLY` marker in the gate's scratchpad defers
windowed labs; the gate takes the headless-only path and the visual check is deferred with it. The
change is text plus numbers, so the inspect text is verified by `t_buildquality` reading the same
`StructureSheet.card_lines()` the card renders.

## Assumptions (`# ASSUMPTION` in code/data)

1. No level-contributing units → level 1 (pieces: `StructurePlacer.apply_quality`; blueprints:
   `BuildFlow.complete` `maxi(1, …)`).
2. Traits come from the first unit of the first primary/main slot only; supports never pass.
3. Effect amounts are the spec's reconstruction references where it gives them (+2 durability/High
   Density level, +3 spaces/Lightweight level, mirrored for the negatives) and 1 per level for the
   spec's un-numbered comfort/antibiotic/building-attack rows (`structures.json` `quality`).
4. Which rare id carries which station effect (Split Easily → duration, Vivid Inspiration → slot) is
   ours; the spec names the effects but not the ids.
5. A station always supports `durability`: `blueprints.json` has no `supported_building_effects`
   and is outside this job's scope.
6. A piece with `storage_slots` counts as supporting `storage_space` (its `piece_tiers` row does not
   list it; rewriting 14 rows would move data other building tests pin).
7. A tier upgrade keeps the piece's level and trait durability (spec silent on re-levelling).
8. No balance tuning done: no HP/damage/XP/fatigue numbers changed; durability/storage deltas are
   the spec's own per-level reconstruction values.

## For the integrator

- `docs/current/building.md` is new; add it to any generated index that lists `docs/current/`.
- UI styling of the new card lines is deliberately minimal (gold first line, muted details in
  `StructureSheet.fill_card`); a Claude pass should restyle, not rewrite.
- Not built (out of scope / spec's later stages): comfort and antibiotic **functional** effects
  (housing recovery), house Complexity, material-driven appearance, and attributing the level to
  kit-placed kinds (baskets, tents — they have no material instances).
- Repair still pays by def id and does not re-level; that matches the spec's silence and keeps
  `t_buildsys`'s repair-cost assertions intact.
