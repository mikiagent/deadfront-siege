# claude-stationstate — pen tiers, visible station state, capture-then-tame, nails, worksites, work loops

Branch `claude/mmo-stationstate` (from `origin/claude/mmo-overhaul` 0fea2471). Not pushed, not merged.
No credits spent (all props procedural).

## Shipped
1. **Taming pen tiers** (`game/data/taming_pens.json`, `TamingPen.tiers/fits/required_kind/refuse_text`).
   A pen takes a species when `real_length_m` <= max length and value (`capture_tier`, 0 = 6) <= max value.

   | Kind | Label | Footprint | Max length | Max value | Kit (workbench) | Takes (beyond the tier below) |
   |---|---|---|---|---|---|---|
   | makeshift_taming_pen | Small | 4x4 | 6 m | 2 | wood 4, lashing 2 (hand) | zebraceratops, compsognathus, coelophysis, protoceratops, velociraptor, megaloceros |
   | taming_pen_medium | Medium | 5x5 | 12 m | 4 | wood 8, lashing 4, nails 2 | gallimimus, deinonychus, dilophosaurus, styracosaurus |
   | taming_pen_large | Large | 6x6 | 18 m | 5 | wood 12, lashing 6, stone 6, nails 4 | smilodon, stegosaurus, utahraptor, ankylosaurus, triceratops |
   | taming_pen_apex | Apex | 8x8 | any | 6 | log 8, lashing 8, stone 12, nails 8 | tarbosaurus, tyrannosaurus |

   Refusal: "The Ankylosaurus is too big for a Small Taming Pen: it needs a Large Taming Pen." (notice +
   pen screen). The penned animal is drawn at its full genetic size (`Occupant` CreatureView), so big tames
   overhang the fence; "Taming 24m 10s" floats over the pen.
2. **Capture, then tame** (Milan addition): capture already gave a `captured_animal` bag stack. Now the pen
   rolls `TamingPen.odds()` = the capture S-curve (`TamingOdds`, survival level vs animal level), shown as
   "Tame NN%" on the pen screen; failure = escapes wild (existing). Size/nature/genetics show `???` on the
   pen screen until tamed. Transport = the bag (existing slot_span 4).
3. **Station state visible** (`StationState`, `game/data/station_state.json`): stone grill spit + meat +
   warm light only while roasting; forge (data-built hearth body, no GLB exists) hot coals, glowing billet,
   light and sparks only while working, cold coals idle; drying rack / smoker / crock pot / steamer keep
   their existing stage models/contents (now tested idle vs busy); farm plots grow plant rows through
   sprout/young/growing/mature (failed wilts) with a floating "1m 30s" / "Ready" timer. Fires untouched.
4. **Metal nails** (Milan addition): `metal_nails` x4 from 1 ingot + 1 fuel at the forge, node
   `nails_pillars` (existing node that "unlocks nails"); required by the medium/large/apex pens.
5. **Worksites** (Milan addition): `ConstructionSite` now lies on a dirt patch of its footprint with a faint
   grey round symbol (the station kit's icon) and "Building 40%"; existing BuildFlow.complete swaps it.
6. **Work loops + craft card** (Milan addition): `station_state.json work_anim` maps kind -> loop (workbench/
   anvil/mortar hammer, grill/crock pot/steamer stir, rack/smoker hang, forge forge, tanning_frame tan).
   StationCraft calls `PlayerAnim.play_work(kind)` (short kind; clip `work_<kind>`) when it exists, else the
   old craft loop; `stop_work()` on end. The floating craft card (CraftCard: recipe name + ingredient hexes)
   already existed; now tested to show/hide with the job.

## Not done / for the next agent
- **Tanning frame and oven** are not buildable kinds (world-design lists the tanning frame as planned), so
  no rows: adding a kind = one `station_state.json` row. The stone grill is the spit-roast cooking station.
- **Ankylosaurus has no model** (draws as the long placeholder box), so the overhang PNG uses a utahraptor
  (11 m) in the 6 m large pen and a velociraptor in the small pen. The test checks the ankylosaurus overhang.
- `docs/current/recipes.md` is generated: `tools/docs_wiki/gen_game_data.py` refused (differing sheets);
  the integrator should re-run with `--force-sheets` after review.
- The pen wait still follows the (hidden) nature's `pen_time_mult`, so the timer can hint at the nature.
- `play_work(kind)` argument form must match claude/mmo-rummage (I pass "hammer", not "work_hammer").
- Craft card shows recipe + inputs; no separate tool icon was added.

## Test fixtures touched
- `t_build`: placeable kit count 26 -> 29 (three pen tiers). `t_structart`: the three pen tiers are
  fence assemblies like `taming_pen`. `game/scripts/dev/market_harness.gd`: `earn()` target 25 -> 40;
  the Settlers' demand table rotates over items.json, so new items cut the viewer's overshoot and the
  "affordable listing" check failed.
- Full suite (128 tests, JOBS=3 on a machine with ~30 other Godot runs): 124 pass; t_buildspeed,
  t_eyetrails (timing budgets), t_dismount and t_save failed under load and all four PASS re-run alone
  (JOBS=1). `tools/smoke.sh --no-import`: SMOKE PASS.

## Save changes (backward compatible, flagged for the owner's gate)
- Pen rows: `kind` may now be `taming_pen_medium|large|apex`; old rows (`makeshift_taming_pen`) load as the
  small pen. SaveSanitizer treats every pen kind like the old one. No other save fields added.

## Assumptions (Open Questions P1-P6 in docs/vision/WildLandsMMO_Open_Questions.md)
Pen limits/footprints/costs, pen odds curve + escape on failure, nails recipe/amounts/which stations, grill as
cooking station + forge data body, work-loop mapping.

## Verify
- `game/tests/t_stationstate.gd`: pen accept/refuse by species, every tameable species has a tier, refusal
  keeps the animal, ankylosaurus overhangs (7.2 m vs 3 m half-side, scale 1.0), tier save round trip, empty
  pen hides the animal; grill/forge busy props only while a craft runs; rack/smoker food only while working;
  plot timer 1m 30s -> 1m 13s -> 13s -> Ready -> hidden; worksite dirt + kit icon + progress; pen odds follow
  survival level; craft card shows/hides with a real workbench job. `t_buildflow` asserts completion
  replaces the worksite.
- PNGs (phone landscape 2x, `--position 6000,3000`): `docs/orchestration/reports/stationstate/`
  base_idle/base_busy (whole base), stations_idle/stations_busy (grill, rack, forge, plots close-up),
  pen_idle/pen_busy. Lab: `--lab=stationstate_lab --state=idle|busy --view=all|stations|pen`.
  Note: a `--shot` path containing "tree" or "skills" opens the Skills sheet (HuntHud); worktree paths
  contain "worktrees", so shoot to a scratch path and copy.
