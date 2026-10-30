# FOODTORPOR — Food Bag, spoilage outputs, torpor capture

Branch `claude/mmo-foodtorpor`, cut from `origin/claude/mmo-overhaul` and merged with canon after
"Merge BAGUI" (02362ad2) landed. Not pushed, not merged.

Owner (2026-10-29): a "Food Bag" tab eaten in placement order; spoiled food leaves it as "Spoiled Meat"
or "Rot"; Spoiled Meat + Narcoberry make the capture drug; creatures get a torpor bar; weak + past a
torpor threshold = knocked out; blunt adds a little torpor, the drug and tranquilizer darts more.
Player-facing names follow the naming rule: **Sedative**, **Tranquilizer Dart**, **Narcoberry**.

## What shipped

### 1. Food Bag (`Inventory.food_bag`, BAGUI bag panel)
- A **Food Bag** tab on the filter rail (`BagGrid.FILTERS` "food_bag", icon `quick_food`). It lists
  the bag's Food Bag lots in the order they were put in; the Sort dropdown hides there.
- A food's card has **To Food Bag / Out of Food Bag**. Only food-tagged items (`food` category, the
  same tag `ItemTags` reads) go in; no repeats; 20 lots at most (`Inventory.FOOD_BAG_MAX`, ASSUMPTION).
- The tab's toolbar has **Eat in order**: `PlayerActions.eat_food_bag()` hands the whole Food Bag,
  front to back, to BAGUI's `EatSession.begin_queue` (online: one lot per intent).
- Auto-feed (`PlayerSim.tick_autofeed`) takes the first edible Food Bag lot before the quick-food picks.
- Design: the Food Bag is an ordered list of instance uids over the main bag, not a second container,
  so eating, crafting, selling and the eat queue are untouched; a uid whose item left the bag or stopped
  being food (spoiled) drops out (`Inventory.food_bag_prune`).

### 2. Spoilage (`Spoilage`, new — there was none: spec 08 had forbidden a freshness timer)
- A perishable lot gets `spoil_at` (unix time) the first time the survivor's bag ticks it (every 5 s,
  `PlayerSim.tick_spoilage`), so offline time counts. Past it, the lot becomes **Spoiled Meat** (meat,
  incl. cooked meat) or **Rot** (other food), one for one, in the same slot, and leaves the Food Bag.
- Lengths are data, `foods.json` "spoilage" (ASSUMPTION): raw meat 2 h, fruit / mushroom / cactus 4 h,
  cooked 6 h, cold food 1 h; preserved (dried, smoked), drinks, pet feed and burnt food never.
- `spoil_at` is allowed on the market (`economy/limits.json` attributes), so stamped food still sells.
- Rot: **Rot Compost** at the mortar, 3 Rot + 1 earth -> 1 Fruit Fertilizer (the item field plots
  already take; same Fertilizer node gate as the fruit recipe).
- Spoiled Meat + 2 Narcoberry -> **Sedative** (by hand, processing). 1 Sedative + 1 bone -> 3
  **Tranquilizer Darts**.
- **Narcoberry** is new: `narcoberry_bush`, the berry-bush art tinted violet through the card shader's
  existing `tint` uniform (nature_manifest `tint`), 2 per island on grass / dry tiles, own RNG stream,
  none on the tutorial island (with them its bot failed the workbench walk at step 10 twice; with the
  count at 0 it passed).

### 3. Torpor (`Creature.torpor`, `combat_tuning.json` "torpor")
- Doses: landed blunt melee hit or stone shot +6; one charge of a Sedative-coated weapon +20 (the
  "Sedate (n/3)" context hex coats the equipped weapon for 3 landed hits, like the toxin coating); a
  Tranquilizer Dart +30 (the "Dart (n)" hex next to "Fire" shoots one from the slingshot at 25 % damage).
- The rule, one place, `FieldTame.window_open(hp, hp_max, stunned, torpor_frac)`: **weak** (spec 09
  unchanged: stunned at any HP, or HP <= 30 %) **and** torpor >= 60 %. Nets, feeding tames, the HUD
  and both server intents go through it. A weak animal crossing the threshold collapses (the existing
  `knockdown` status), which opens the feeding window too; the net's captured_animal then goes to the
  pen as before (STATIONSTATE's flow is untouched).
- Torpor holds while knocked down, drains 3 / s after 6 s with no dose; not saved.
- DoT guard now keys on "weak" (`FieldTame.is_weak`), so a bleed cannot kill an animal mid-sedation.
- Plates: a violet strip under the HP bar (creature plate and hunt target plate) with a white tick at
  the threshold. The hint above the target reads "Sedate it: torpor 42% / 60%" when weak, "Knocked out
  — throw the net!" in the window. The 50 % hint is now "Weaken and sedate the dinosaur to capture it.";
  the net's refusal names the missing half (`FieldTame.refusal`).

## Save change (flagged)
- `player.inventory_extras.food_bag`: an array of item uids in eating order. Written only when the
  Food Bag is non-empty (a save that never used it is byte-for-byte unchanged); missing = empty; loaded
  through `extras_from_dict` with a type check (sanitizer template `"food_bag": []`), capped at 20,
  deduplicated, and pruned against the bag's actual food.
- Item attribute `spoil_at` (float unix seconds) on perishable food, and `sedative_hits` (int 0..3) on
  a coated weapon; both pass the save sanitizer and the market validator.
- Wild creature `torpor` is not saved. Server world rows get `torpor` (0..1) with default 0.

## Tests
- New `t_foodtorpor`: food-only, placement order, save round trip and legacy save, capacity, spoilage
  (meat -> Spoiled Meat, berry -> Rot, preserved never, spoiled lots leave the Food Bag, the player's
  own tick), eating order through the queue, auto-feed takes the Food Bag first, the bag panel tab and
  card buttons, Sedative / dart / compost recipes, narcoberry bush, torpor per dose (dart 30 > sedative
  20 > blunt 6), coating, knock-out only when weak + past the threshold, torpor holds while down and
  drains when up, server window, net capture after knockout.
- Updated to the torpor rule (fixtures model a knocked-out animal with full torpor, plus explicit
  "no torpor stays shut" checks): `t_capture09`, `t_tame`, `t_tamingodds`, `t_colors`, `t_natures`,
  `t_targetui`, `t_w2_skills`, `t_uigather` (NET is not gold at 25 % without torpor, gold once sedated),
  `srvdom_checks` and `econ_bridge_checks` (server fixtures set `torpor`).
- `t_buildspeed`: digests re-recorded (2 narcoberry bushes per island). Checked first that with the
  bush count at 0 the build still matched the old digests.
- `t_data` (spoilage is a source of Spoiled Meat / Rot; narcoberry bush in its special families),
  `t_rareattr` (narcoberry rare list), `ui_icons.json` (Dart / Sedate hex icons).
- `bash tools/all_tests.sh` (after the BAGUI merge): 139 / 140, the one fail t_tutorial (step 10 workbench
  walk, twice in a row; the narcoberry bushes on the tutorial island, see above). After excluding the
  tutorial island: t_tutorial, t_buildspeed, t_data, t_foodtorpor PASS run alone. `tools/smoke.sh
  --no-import`: SMOKE PASS.

## Shots (`docs/orchestration/reports/foodtorpor/`)
Milan's later rule "work headlessly for now" arrived after these four were taken; no windowed run was
started after it, and the shots were not retaken after the last commits (the tutorial-island
exclusion does not touch either screen).
- `foodtorpor_plate_torpor_1600x900.png`, `foodtorpor_plate_torpor_844x390.png` — weakened raptor,
  torpor 42 %: violet strip + threshold tick on the target plate (and the creature plate at 1600x900).
- `foodtorpor_food_bag_1600x900.png`, `foodtorpor_food_bag_844x390.png` — the Food Bag tab (mango,
  berry, grilled meat in placement order), the card's "Out of Food Bag", the toolbar's "Eat in order".
- Lab: `game/scenes/dev/foodtorpor_lab.tscn` (`--shot-dir=DIR [--canvas=844x390]`, windowed).

## Assumptions (all in docs/vision/WildLandsMMO_Open_Questions.md, FOODTORPOR T1-T6, F1-F3)
Torpor max 100 for every species; threshold 60 %; doses 6 / 20 / 30; dart damage 25 %; decay 3 / s
after 6 s; Sedative and dart recipes; narcoberry placement (2 per island, all climates); Food Bag 20
lots as a uid view; spoil times; Rot compost recipe.

## Not done / next
- Spoilage runs on the client's own bag only: pet bags, chests, home cargo and the online server do
  not spoil yet.
- Torpor is flat per species (Open Question T1: scale by size / tier).
- Models-mode (`--models`) narcoberry bushes are untinted batched berry bushes (cards mode, the
  default, is tinted).
- No dedicated icons: Spoiled Meat / Rot / Narcoberry / Sedative / Tranquilizer Dart borrow raw meat,
  ash, berry, marsh herb and hollow bone through `icons_manifest.json` aliases.
- Credits spent: none.

## Re-merge (2026-10-30, dsc FOODFIX)
Merged `origin/claude/mmo-overhaul` into this branch (merge commit 9aa7013b, unpushed).
- Conflicts were exactly the two the brief named:
  - `game/tests/t_buildspeed.gd`: took canon's ISLANDSHAPES block (comment + digests), then
    re-recorded the three digests on the merged tree. Provenance proof: with the `narcoberry_bush`
    count temporarily 0 in `island_scatter.gd` the merged build produced exactly canon's digests
    (ee9810de… / 3baa8c61… / d7f9bb52…), then the count was restored to 2 and the new digests
    (f04996a5… / 84bf66db… / c3029c63…) recorded with an updated comment.
  - `docs/vision/WildLandsMMO_Open_Questions.md`: kept BOTH sections (FOODTORPOR T1-T6/F1-F3 and
    ISLANDSHAPES S1-S10) in sequence, no edits to their content.
- Narcoberry vs topography: verified the placement path can never land a bush on ISLANDSHAPES
  cliff/outcrop ground — `_spawn_special_family` only accepts GRASS/DRY tiles and requires
  `spawn_ok(pos,false)` (is_dry -> dry_walk, 0 on every CLIFF tile) plus the harbour/camp keep-outs.
  Now asserted per bush in `t_islandgen._check_islandshapes` (tile != CLIFF, dry + spawn_ok, off the
  dock approach) on all 16 islands incl. the tutorial isle (0 bushes there). t_islandgen PASS.
- t_islandgen gained `tutorial_isle` in its roster (for that check); its hand-tuned dock is exempt
  from the southern-most-dock assertions (ISLANDSHAPES S4 `dock_rule: hint`).
- Gate: `verify_foodfix.sh` VERIFY PASS (t_foodtorpor, t_buildspeed, t_islandgen, t_capture09, t_tame,
  t_tutorial, run_all, smoke). Note: t_buildspeed's timing gate flakes under this box's load (8+ agent
  Godot jobs; canon itself measured 3229 ms home under load ~8.7 per claude-islandshapes.md); the
  digest checks are the merge's real acceptance and pass.
