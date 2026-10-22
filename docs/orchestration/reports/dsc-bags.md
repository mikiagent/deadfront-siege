# dsc-bags — spec 31 (bag types, levels, inherited storage, Pocket, inspect/compare, craft preview)

Branch `claude/mmo-bags` (worktree `mmo-bags`). Gate: `verify_job.sh bags` (test, lab at 1600×900
and 844×390, then related tests + `tools/smoke.sh` + scope).

## What shipped
- **Data.** `game/data/bags.json` (new): rules + five bag types. `items.json`: five bag items
  (`categories: [accessory, bag]`, `bag_def` pointer); `woven_bag` kept as a legacy id pointing at
  `basic_bag`. `recipes.json`: five tailoring bag recipes.
- **One capacity function.** `game/scripts/items/bag_capacity.gd` (`BagCapacity`) is the only
  formula: per-item breakdown (`base`, inherited `storage{}`, `capacity`, `pocket`, type `other`,
  `total`), `inventory_total(inv)` for the whole bag, `count(inv)`, and the crafting-side
  inheritance helpers. `InventoryEquipment.bag_bonus/capacity`, the Bag header, `Crafting.bag_preview`
  and the inspect panel all delegate to it; there is no second copy of the arithmetic.
- **Bag definitions.** `game/scripts/items/bag_def.gd` (`BagDef`): type table, `base_capacity(id,
  level)` (linear interpolation between curve rows, clamped), `inheritable`, `storage_bonus`, slot,
  min craft level, recipe id.
- **Instances and inheritance.** A crafted bag is an `ItemStack` with its own level, attributes and
  durability. `Crafting.build_output` applies `BagCapacity.apply_inheritance`: only the attributes
  the bag type lists as inheritable come off the picked primary material; everything else stays on
  the material. Pocket only ever comes from an attribute, never from the level.
- **Craft preview.** `Crafting.bag_preview(inv, rec, picks, player)` builds the bag through the same
  `build_output`/`crafted_level_for` the real craft uses and reports expected level, base, inherited
  attributes, Pocket, capacity attribute, type modifier, final storage and the survivor's total
  capacity wearing it. `craft_ui.gd` prints that block in the recipe detail ("BAG PREVIEW").
- **Inspect and compare.** `game/scripts/ui/bag_inspect.gd` (`BagInspect`): level, Storage Capacity,
  Base Capacity, inherited storage lines, Pocket Lv. + spaces, capacity attribute, bag modifier,
  Crafting Quality, Durability, then the comparison with the bag worn in the same slot
  ("Current bag: +N / New bag: +M / Capacity change: ±K") in green for an improvement and the
  warning colour for a reduction. Hooked into `inventory_ui.gd` ("Inspect bag" action).
- **Header.** `BAG used / capacity` is recalculated in `rebuild()`, which runs on every inventory
  `changed` signal, so wearing or removing a bag updates it in the same frame.
- **Save/load and migration.** Bags round-trip through the existing `Inventory.to_array` /
  `extras_to_dict` (level, attributes, flags, durability). `woven_bag` saves are unchanged rows: the
  item id still exists and now points at `basic_bag`, so the old bag loads at its own level and
  attributes and takes the Basic Bag curve instead of the flat `bag_slots: 20` it used to carry.

## Historical vs assumed (spec §15)
**Historical / from the spec:** base personal capacity **100**; Pocket **+6 spaces per level**
(1 → +6, 5 → +30); storage from equipped bags *and* clothing; per-instance bag levels; material-
derived bonuses; dinosaur cargo and containers as separate inventories; resources stored
individually; bag level and capacity bonus being different statistics.

**Assumed (new design values, allowed by §15):** every curve, `storage_bonus`, recipe, material list
and min craft level. The tables:

| type | L1 | L10 | L20 | L30 | L45 | L60 | own bonus | inherits | min craft |
|---|---:|---:|---:|---:|---:|---:|---:|---|---:|
| Basic Bag | 20 | 24 | 28 | 32 | 38 | 44 | 0 | pocket, capacity | 1 |
| Small Pouch | 8 | 12 | 16 | 20 | 24 | 28 | 0 | capacity | 1 |
| Large Pouch | 14 | 20 | 26 | 32 | 40 | 48 | 0 | capacity | 8 |
| Advanced Backpack | 26 | 34 | 42 | 50 | 60 | 70 | 0 | pocket, capacity | 20 |
| Specialized Storage Bag | 22 | 30 | 38 | 46 | 56 | 66 | +8 | pocket, capacity | 30 |

The spec's own §6 example (+60 base at level 60) is illustrative; these curves are deliberately
lower so that inherited material attributes and Pocket are what separate two bags of the same level
(measured: two level-30 bags differ by 40 spaces in the lab — 66 vs 26).

Recipes are new: Basic Bag = 2 green hide (primary) + 3 fibre + 1 lashing, tailoring; the other four
follow the same shape on cured hide/cloth/rope at increasing min levels (8/20/30). Materials and
counts are named `ASSUMPTION` in the data files.

Quality: this build has no Common/Rare/Epic roll and `Crafting` has no success or flawless roll yet.
The panel therefore shows the instance's `quality` attribute or its `flawless` flag (else "Normal"),
and `bag_preview` reports success 1.0 / flawless 0.0 rather than inventing a chance. Both are marked
`# ASSUMPTION` in code.

## Overflow policy
Kept consistent with the existing game: a bag reduction that would leave more occupied spaces than
the new maximum is **refused** (the bag stays worn, a notice is shown) and no item is ever deleted.
Verified in `t_bags` §10 and in the lab (`overflow_blocked=1 items_lost=0`).

## Verified
- `game/tests/t_bags.gd` (new): 16 test functions, ~50 asserts covering spec §14 items 1–17 plus the
  `woven_bag` migration. `[t_bags] PASS`.
- `game/scripts/dev/bags_lab.gd` (new) + scene: drives the real bag and craft screens, prints one
  `[bags] RESULT` line measured live and four shots per resolution:
  `bags_01_bag_screen`, `bags_02_inspect_upgrade`, `bags_03_inspect_downgrade`, `bags_04_craft_preview`.
  Identical numbers at 1600×900 and 844×390:
  `base_cap=100 bag_types=5 same_level_diff=40 pocket1=6 pocket5=30 multi_mod_ok=1 reequip_stable=1
  overflow_blocked=1 items_lost=0 preview_level=25 preview_bonus=42 crafted_bonus=42 crafted_worn=142
  preview_matches=1 save_roundtrip=1 header_ok=1 cargo_separate=1 compare_shown=1 panel_fits=1
  ui_min_px=64`.
- Gate: `verify_job.sh bags` → PASS (stage 1 and stage 2 confirmed during the run; full stage adds
  `t_inventory`, `t_items`, `t_save` and `tools/smoke.sh`).

## What the screenshots changed
Looking at the shots found two real layout defects that the asserts had missed: the panel measured
6500 px tall (an autowrapped `Label` in a zero-width column counts one word per line), and on a
landscape phone the panel was a narrow column wrapping off the bottom edge. The panel now gives its
labels an explicit inner width, fits itself deferred into the view (`shown_fits`), and on a compact
canvas is wide-and-short and stops clear of the screen's own close button.

## For the next agent
- Tuning lives in `data/bags.json` (curves, `storage_bonus`, `inheritable`) and `data/recipes.json`.
  No code knows a bag number: change the data and the header, panel and preview follow.
- If a bag success/flawless roll is added to `Crafting` later, feed it into `Crafting.bag_preview`'s
  `success`/`flawless` fields — the preview text already prints them.
- `weapon`/`clothing` storage still comes from `bag_slots` + Pocket on the item def; that path is
  untouched and still adds to personal capacity (spec §7 clothing Pocket).
- `tools/run_all.sh` is left to the integrator; `verify_job.sh` runs the related tests and smoke.

## Gate note (scope base)
`verify_job.sh` defaults its scope diff base to the merge-base with `claude/mmo-overhaul`. This
worktree was cut from `claude/mmo-bags` *after* it merged `claude/mmo-overhaul`, so the merge-base is
`82cbdb27` and the diff then also lists the invslots worker's files (`game/scenes/dev/invslots_lab.tscn`,
`game/tests/t_invslots.gd`, …) that came in through that merge and are not mine. With `BASE` set to
this task's own commit (`2c037f34`, the "BAGS task" commit) the scope check is clean:
`BASE=2c037f34 verify_job.sh bags` → **VERIFY PASS** (t_bags, the lab at both resolutions, t_inventory,
t_items, t_save, smoke, report and scope).
