# W2-DATA report: item and recipe data, material ladder, nets, armour bands

Branch `claude/mmo-w2-data`, merged with `claude/mmo-overhaul` at cecc936b (the base moved by two HANDOFF/docs
commits; merged in 5849a2d3). Review round 4 gates ran on 753a3c64 with the regenerated hooks patch applied (scratch
tree `w2data-r4-gate`); the commits after it change only this report. No dsc worker was used (the owner took
DeepSeek off on 2026-10-20), so nothing goes in dsc-improvements.md. No credits spent.

## Round 5: the round 4 findings again, on a resumed workflow step (2026-10-21)

A resumed workflow sent this package the round 4 review findings again (raid gear beats steel, raid primary takes
every ingot, act.craft ignores requires_node, warp-ruin loot, wild corn, strap leak, raw node id, dead stack_max,
shared tier icons, and the GAUNTLET "level 5 better than level 1" acceptance item). All of them were handled in round 4 (6dafc6f1, 753a3c64,
table below). Review r4 passed, and the integrator merged the package on 2026-10-20 (eb835a83, base-docs merge
9c4226c8, hooks applied in be970c8c; STATUS merge log 18ef7091). Nothing was left to fix. This round:

- **Base moved by 84 commits** (W2-SKILLS, WATER and docs). `claude/mmo-w2-data` was an ancestor of
  `claude/mmo-overhaul`, so it was fast-forwarded to ddaab662. No merge commit and no conflicts.
- **The fixes survived the later merges** (checked on ddaab662). The raid maul, helm, cuirass and greaves still take
  `tier_steel` as their primary, behind `iron_weapons`/`scute_armor` + Survival 50 + Lv 55. `hide_strap` takes
  `dried_hide` and is not `cured_hide`.
- **requires_node ids:** all 16 exist in the merged trees.json (W2-SKILLS' re-key), with names: work_pick
  (Weapon/Tools 5), combat_knife 15, hammer 20, copper_tools 30, blade_shapes 40, iron_weapons 50; smelting_1
  (Processing 25), nails_pillars 20, smelting_2 40; armor_1 (Tailoring 35), scute_armor 45; furnace_kiln
  (Construction 35); steam (Cooking 25), antivenom 20, antibiotic 30; fertilizer (Farming 15).
- **Refusal text (minor 6):** W2-SKILLS H1 replaced hook 6's check at merge. `Crafting.progression_block` now calls
  `SkillRules.recipe_block`, which says "learn Smelting 1 (Processing Lv. 25, N SP)": the node name, tree and level,
  as the finding asks.
- **Hooks patch:** nothing is left to apply. On ddaab662, `git apply -R --check --exclude=game/scripts/items/crafting.gd`
  on the patch is clean (rc=0), so hooks 1-15 are in the base. The crafting.gd hunk does not reverse because H1
  replaced it on purpose. The patch file stays as the record of what was applied. It no longer applies forward
  and must not be applied again.
- **Server craft path (minor 2):** still open, as before. `intent_handlers.gd _craft` checks `required_survival` and
  not the node gate. It stays a W3-SRVACT acceptance item (see "W3-SRVACT acceptance item" below). W3-SRVACT's
  plan-register section belongs to another package, so it was not edited here.

Acceptance (round 5): scratch tree `w2data-r5-gate` on ddaab662 with no patch, since the hooks are in the base. The
import log has 0 error lines.

| Item | Result |
|---|---|
| every t_*.gd (22) | Every one prints its PASS line with rc=0: t_ai, t_build, t_canim, t_combat, `[t_data] PASS items=223 recipes=155`, `[t_harbour] PASS islands=15`, t_iconart, t_items, t_light, t_lighting (`[t_light] PASS`), t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, `[t_uiicons] PASS ids=177 files=116 ...`, t_w2_skills, t_water, t_web. t_save prints its 5 deliberate SCRIPT ERRORs. Every other log has 0 SCRIPT ERROR and 0 "couldn't resolve track" |
| run_all, smoke | `[tests] PASS` (rc=0); `SMOKE PASS` (`tools/smoke.sh --no-import`, rc=0) |
| GAUNTLET: higher tier clearly better; level 5 clearly better than level 1 | `[t_data] L55 armor_body via planner: copper_cuirass 2413 (copper), bronze_cuirass 2756 (bronze), iron_cuirass 3158 (iron), steel_cuirass 3650 (steel), raid_cuirass 4653 (steel)`; `[t_data] L55 weapon via planner: copper_sword 352 (copper), bronze_sword 402 (bronze), iron_sword 460 (iron), steel_sword 532 (steel), raid_maul 1460 (steel)`; `[t_data] level 1 -> 5 from the planner: flint_pick gather power x1.40, flint_spear damage x1.32` |
| Nothing beats steel without the steel gate | `[t_data] above steel_cuirass (686, gate Lv 45): raid_cuirass 875 at steel tier, gate scute_armor Lv 45`; helm and greaves the same; `above steel_sword (100, gate Lv 50): raid_maul 274 at steel tier, gate iron_weapons Lv 50` |
| Node gate refusal (now W2-SKILLS H1) | `[t_data] smelt_copper gate: before 'learn Smelting 1 (Processing Lv. 25, 15 SP); you have 0 SP, reach Lv. 2 for +10 SP', after learning smelting_1 ''` |
| Vision fixes | `[t_data] start island: reachable=110 twine ~2.3 s dried_hide ~5.1 s hide_strap ~3.5 s rope ~8.9 s, metal []`; `[t_data] reachable=216/223 pending=[...] best_pick=steel`; `[t_data] tameable species with a reachable net: 17` |
| Raid kit through real crafting (hook 15) | `[gear] maul L60 steel dmg=1569.6 kit armor=9291.3`; `[gear] PARTIAL real formulas/craft allocation; acquisition, station movement and raid evasions untested; failures=0` (0 FAIL lines) |
| Labs | `[craft_lab] PASS`, `[equiplab] PASS` (headless, rc=0, 0 SCRIPT ERROR) |
| Crashes | No new Godot-*.ips: 25 before and after, the newest still Godot-2026-10-20-232613.ips (another agent's, per the STATUS WATER entry) |

Not rerun this round: the mutation FAIL lines, the windowed pixels and island_lab. This round changed no code or data,
so the round 3 and round 4 evidence for them still holds. The integrator's merge-time island_lab run gave `nodes=397`.

## What shipped

- **Material ladder Stone → Bone → Flint → Obsidian → Copper → Bronze → Iron → Steel (GAUNTLET), every rung
  reachable.** New `tin_ore` (TinOreNode family, temperate and tundra, needs a flint pick) and `tin_ingot`.
  Smelting happens at a new fuelled **forge** (`forge_kit`, place_as `forge`): tin, copper (`copper_ore`), iron
  (`black_iron`), bronze alloy (2 copper + 1 tin + fuel gives 2 bronze) and steel (2 iron + 2 fuel). The old
  `ore` → `ingot` recipe is now "Crude Ingot" at the forge with fuel. `ore` (Rough Ore) is a 0–1 byproduct of
  the desert copper node and needs an obsidian pick, like the copper ore beside it (it used to come from granite
  boulders, which grow on the home grassland; see "Vision fixes").
- **Named tools on every rung:** `<tier>_knife/_axe/_pick` plus `<tier>_spear` (bone, flint, obsidian) or
  `<tier>_sword` (copper, bronze, iron, steel), 28 items. Bone and flint/obsidian are made at the workbench,
  metals at a new **anvil** (`anvil_kit`). Base stats match the generic archetypes; the tier step comes from
  `ProgressionScaling.tier_multiplier` on the primary material, so the multiplier is never applied twice.
  The stone rung keeps `stone_knife_work`, `work_axe`, `work_pick` and `stone_knife`.
- **Rung gear only through gated recipes.** Gear takes its tier from its primary material. The generic
  `improvised_stone_knife`, `work_axe`, `work_pick` and `hoe` take `blade_mat`, and before this round that
  included flint, obsidian, both ores and every ingot. A work pick made of a steel ingot was a steel pick
  with no skill node, which made every `requires_node` gate on the named tools pointless. Now only stone,
  bone, talon and metal shard are `blade_mat` (talon and shard read as flint by hardness). Higher rungs go
  through their named, gated recipes.
- **Each mined rung needs the pick of the rung right below it** (hooks 9 and 11). Flint now needs a bone
  pick (it needed stone, which skipped the bone rung). Black iron now needs a bronze pick (it needed copper,
  so bronze could be skipped entirely). Obsidian ← flint and copper ← obsidian were already right.
- **Capture nets I–V:** recipes for II–V. III and up need predator tendon; IV needs metal; V needs armour
  scutes and bronze. The Committee crate ids `capture_net_iii`/`capture_net_v` now exist. All 17 tameable
  species have a reachable net and technique.
- **Armour in every band 1–60:** a new leather set (L20), plus copper (35), bronze (40), iron (50) and steel
  (55). Each set has helm, cuirass, bracers and greaves. All armour and clothing has `insulation {cold, heat}`.
- **The raid kit sits on top of the ladder (round 4).** Raid maul, helm, cuirass and greaves are made from steel
  ingots only, behind the steel rung's nodes (`iron_weapons`, `scute_armor`) plus Survival 50 and Lv 55. Their base
  values were rebased so the crafted L60 kit keeps the numbers the tyrant fight was tuned at.
- **market_category and rarity on every item.** Market categories are the market.json price keys.
  `item_rarity.json` is now a generated mirror of `items.json` rarity, and t_data fails if the two disagree.
- **Recipe gates:** progression recipes carry `requires_node` (a trees.json node id). Hook 6 makes
  `Crafting.progression_block` enforce it and say what to raise ("needs Smelting 1 (Processing 25)"). Existing early kits are left ungated so the starting loop does
  not change.
- **Repairs:** `recipes.json "repairs"` has one row per ProgressionScaling tier. They are data only; a
  consumer still has to be written.
- **Missing sources and dead references fixed:** recipes for `hoe`, `steamer_kit`, `pillar`, `claim_stake`,
  `stone_knife`, `cloth_scrap`, `metal_shard`, `blue_dye` (staged, see below), `fruit_fertilizer`, seed extraction for all four
  crops, and `antivenom`/`antibiotic`. New items `moss` and `cactus_flower` for existing nature yields.
  Faction crate ids now point at real items.
- **Loops fixed:** `sashimi`, `carnivore_feed` and `herbivore_feed` were multiplying loops (output fed its
  own slot, x2/x3). The slots now take raw meat.
- **Validator `game/tests/t_data.gd`:** references across every data file; a walk from bare hands over real
  sources only (climate vegetation × nature yields with HarvestNode's own tool and pick-tier gates,
  butchering, farming, capture, taming, recipes); ladder, nets, armour bands and loops; 39 recipes crafted
  through the real `Crafting.preview` planner. Rung time and skill gate never drop along the ladder, the pick
  chain, a hook 6 check that `progression_block` refuses `smelt_copper` until `smelting_1` is learned and names
  the tree and level. Round 4 adds: nothing reachable beats the steel item of its slot at equal level unless it is
  gated at least as high; no gear recipe takes material above flint below that rung's node; no split recipe
  multiplies a gear slot category; no ore or metal in warp-ruin loot; and the planner's tier and level evidence.

- **Processing is mandatory (vision fix 1).** Rope is twisted from twine only, hide straps are cut from dried
  hide only, and every armour, tent and bed hide slot takes `cured_hide` (dried hide; since round 4 straps are
  lashing only), never raw hide.
- **No ore on the home grassland (vision fix 2).** Metal starts on the desert and volcanic islands.
- **The walk follows the islands that exist.** t_data gathers on the islands islands.json lists (their climate
  and tier) and butchers only the species those islands spawn. A second walk covers the start island alone.

## Review round 4 (findings and what changed)

| Finding | Fix | Check that now catches it |
|---|---|---|
| major: raid gear beats the steel set and its "metal" primary takes every ingot, so steel-tier gear skipped `iron_weapons`/`scute_armor` | The raid recipes take `tier_steel` (steel ingots only) as their primary, at half the old shard count (2 shards = 1 ingot: maul and cuirass 4, helm and greaves 2), and require `iron_weapons` (maul) or `scute_armor` (helm, cuirass, greaves) on top of their Survival 50 and Lv 55. The base values are rebased by 1.25/2.45 (maul damage 220 → 112, cuirass armour 700 → 357, helm and greaves 300 → 153), so the crafted L60 kit keeps the numbers the tyrant fight was tuned at. Hook 15 updates W1-ITEMS' raid_gear_probe: it now stocks steel ingots and learns the two nodes. Its result: `[gear] maul L60 steel dmg=1569.6 kit armor=9291.3` (shard kit: 1573.0 and 9295.0), and 0 FAIL lines, including "real boss contact kills in4-6 landed hits". The raid kit now sits above steel on purpose. It needs the same steel, the same node, Survival 50 and four times the hide, it has no arms piece, and it is the only set with fracture/pinned protection. | `_check_top_rung`, `_check_ungated_gear` (rewritten: Survival and min_level no longer count as a gate; any gear recipe whose primary takes material above flint needs a node at least as high as the lowest node the ladder's own `tier_<t>` gear has) and `_check_tier_planner`. Pre-fix data (0554797a + its hooks) with the new t_data: `FAIL raid_cuirass (1715 at steel tier) beats steel_cuirass (686 at steel) at equal level with skill gate Lv 0 < Lv 45`, the same for raid_helm, raid_greaves and `raid_maul (539 at steel tier) beats steel_sword (100 at steel) ... Lv 0 < Lv 50`, `FAIL recipe raid_cuirass takes steel-tier material as its primary with skill gate Lv 0, below the ladder's steel gear gate Lv 45` (×4), `FAIL raid gear refuses metal_shard as its primary`, `... copper_ingot ...` |
| major (acceptance): a level 5 tool clearly better than level 1; higher-tier gear clearly better | Met. Evidence from t_data, through the real planner with every input at level 55: `[t_data] L55 armor_body via planner: copper_cuirass 2413 (copper), bronze_cuirass 2756 (bronze), iron_cuirass 3158 (iron), steel_cuirass 3650 (steel), raid_cuirass 4653 (steel)`, `[t_data] L55 weapon via planner: copper_sword 352 (copper), bronze_sword 402 (bronze), iron_sword 460 (iron), steel_sword 532 (steel), raid_maul 1460 (steel)`, `[t_data] level 1 -> 5 from the planner: flint_pick gather power x1.40, flint_spear damage x1.32`. Raid from metal shards or copper ingots is refused (asserted). | `_check_tier_planner` asserts each tier beats the one below, raid ≥ steel, and the level 5 tool ≥ 1.3× level 1 |
| minor: server act.craft ignores requires_node | Unchanged. The W3-SRVACT acceptance item stays (below). | - |
| minor: hook 10 warp-ruin loot (metal_shard at a ruin that could sit on the home island; corn is not a rare seed) | Hook 10 now lists `cloth_scrap`, `pressure_dressing` and `wheat_seed`. world-design.md:106: courier boxes hold "cloth, wire, medicine, rare seeds". No item is wire, and a metal stand-in would put metal in a box that a future consumer could place anywhere, so wire is left out. No seed is rare in items.json, so the stand-in is wheat, which grows wild only on temperate islands, never on the start island. Recorded under assumptions. | `_check_home`: `FAIL warp ruin loot metal_shard is not ore or metal` (old hook 10) |
| minor: wild corn on the home grassland | Kept as the documented assumption (the reviewer accepts it). | - |
| minor: straps halve the dried-hide cost of armour and tents | `hide_strap` leaves the `cured_hide` category. Armour, tent and bed hide slots take dried hide only, and straps stay lashing (one strap fills one lashing unit, like twine). | `_check_split_leaks` (a split may not yield more units of a gear slot category than it consumes): `FAIL recipe hide_strap turns 1 cured_hide unit(s) into 2 hide_strap`, and on the pre-fix data also `FAIL recipe metal_shards turns 1 metal unit(s) into 2 metal_shard` (the old raid kit took "metal") |
| minor: hook 6 refusal shows the raw node id | `_node_block` returns "needs Smelting 1 (Processing 25)": the node's `name` (W2-SKILLS adds names; the base has none, so it falls back to the capitalised id), the tree's name from `SkillState.NAMES`, and the node level. | `_check_node_gate`: `FAIL smelt_copper's refusal 'needs skill smelting 1' names its tree Processing and level 25` (old hook 6). Now `[t_data] smelt_copper gate: before 'needs Smelting 1 (Processing 25)', after learning smelting_1 ''`. W2-SKILLS' H1 runs before hook 6 and says "learn Smelting 1 (Processing Lv. 25, … SP)". By its format string the check should pass with H1 too. That was not run here. |
| minor: dead `stack_max` on material rows | The new rows (tin_ore, tin_ingot, moss, cactus_flower, capture_net_iii–v, antivenom, antibiotic) no longer carry one, and copper, bronze, iron and steel ingot are back to base's 999. 140 base rows still carry a dead value. No check was added: it would mean rewriting those base rows, and the finding offers "leave it out on new ones". | - |
| minor: every tier's tools share the stone-tier icon | Unchanged, ICONS2 follow-up (below). No tint was added: it would be ItemArt code in another package's file, for a stand-in. | - |

Fixture probes: `raid_fight_probe`, `tyrant_window_probe` and `counter_matchup_probe` (W1-ITEMS/W1-COMBAT) make raid gear
with `ItemStack.make(id, 1, {}, level)`. That stack has no material, so it is stone tier, and the rebase halves its
numbers (maul 220 → 112 × level). raid_fight_probe was `PARTIAL` before and after: before, `[raidfight] PARTIAL t=24.4
bossHP=187311 playerHP=0 rolls=8 contacts=6`; after, `[raidfight] PARTIAL t=23.1 bossHP=193141 playerHP=0 rolls=8 contacts=5`
(0 SCRIPT ERROR in both). The survivor dies at about 24 s either way, so the outcome does not change. These probes
assert no stat values, so they are not hooked. Follow-up for W1-ITEMS: pass `{"material_tier": "steel"}` there so the
fixture matches the crafted kit.

## Review round 3 (findings and what changed)

| Finding | Fix | Check that now catches it |
|---|---|---|
| blocker: `syringe` in statuses.json `infected_wound.cleared_by` is not an item; t_data whitelisted it as an action | `syringe` is out of `STATUS_ACTIONS`. Hook 14 drops it from statuses.json (W2-WEATHER owns the file). The PRD row (`dinosaur-roster-and-3d-pipeline.md:98`) names the cure "Antibiotic / syringe", and `antibiotic` is a real item with a recipe (Cooking 30), so the antibiotic stays the cure. No syringe item was added: nothing else in the docs gives it a source or a recipe. | `[t_data] FAIL status infected_wound cleared_by syringe is an item or a listed action` (hook 14 left out) |
| major: the home check only failed when the walk reached ore; a pick-gated ore node on the grassland went unnoticed | `_check_home` now also asserts statically: for every `home` climate, no family in vegetation + `SPECIAL_FAMILIES` yields an `ore`/`metal` item (whatever its `min_pick_tier`), and no `materials` entry is ore or metal. The walk check stays. | Reviewer's M1/M1b (CopperOreNode and TinOreNode in grassland vegetation): the walk still prints `metal []`, and the new lines fail: `[t_data] FAIL home climate grassland grows no metal, but CopperOreNode yields copper_ore`, `... CopperOreNode yields ore`, `... TinOreNode yields tin_ore` |
| major: Corn and Wheat planted on every temperate island at the 24-plant floor, unreported, no pixels | Corn moved to the home grassland, matching its manifest (`climates: ["grassland"]`). Wheat stays on temperate (its manifest lists grassland and temperate). Both get `count: 10` in hook 9, like FlaxPlant, so a wild crop is a find, not a carpet: the scatter halves it on the home island, which gives 5 corn plants there and 10 wheat on temperate_25. Docs: PRD `durango-wild-lands-systems-prd.md:615` says "Corn can be grown with almost no SP", and `12_remaining_skill_trees.md:80` calls Corn an "early/automatic" technique. So corn now grows on the start island, and the island walk reaches 110 items there (108 before; corn and corn_seed are the two new ones). Headless island_lab temperate_25: `nodes=397` (base 378, last round 433). Assumptions below. | `[t_data] FAIL wild crop Corn on temperate is in its manifest climates ["grassland"] with a count (10)` (Corn put back on temperate) |
| minor: bot_survivor could no longer make rope; blade_mat listed flint | Hook 13: `"twine": ["twine"]` in `CATEGORY_ITEMS` (no node yields twine, so `_acquire_for` falls through to the twine recipe), and flint is out of `blade_mat`. | new `_check_bot_map`: `[t_data] FAIL bot_survivor maps rope's slot category twine`, `[t_data] FAIL bot_survivor gathers flint for blade_mat, which it does not fill` (base bot_survivor.gd) |
| minor: metal armour icons borrowed raw_hide/dried_hide | No helm or armour symbol exists in `assets/icons/sym`. The 20 new armour pieces now alias to four new icon keys that point at existing armour renders: `armour_head` (raid_helm), `armour_body` (raid_cuirass), `armour_arms` (forager_wraps), `armour_legs` (raid_greaves). A copper cuirass now shows a cuirass, not a raw hide; in white-symbol contexts it draws as a cuirass silhouette. Per-item art is a follow-up (list below). | `[t_data] FAIL unrendered copper_cuirass borrows the raw_hide icon, not an armor_body picture` (old alias) |
| minor: metal armour gated by nodes labelled hide/scute armour | Recorded as an assumption (below). The docs give no armour gates. W2-SKILLS has already renamed the nodes "Armor 1" and "Scute armor" (d2bb431b), so the label clash only shows on base. | - |
| minor: server craft path ignores requires_node | Left for W3-SRVACT as an acceptance item (below). No server check was added: it would change multiplayer authority, which is an owner gate. | - |
| minor: report line 80 wrong; `crate_tstones` unreported | Line corrected (GraniteBoulder is unchanged from base, which never gave it ore). `crate_tstones` is listed under assumptions and follow-ups. | - |
| minor: t_data reparsed factions.json per key and trees.json per call | `factions` and `trees` are parsed once in `_load_all`. `_check_structures` is a no-op until structures.json exists; it starts checking when W2-BUILDSYS merges. | - |

All five mutations above ran in one t_data run (scratch tree `w2data-mut`, hooks applied, then mutated): rc=1, ten
FAIL lines, each naming its own cause, and the start-island walk line still read `metal []`.

Pixels (windowed, `--rendering-method gl_compatibility`, scratch-only lab that stands the survivor beside the nearest
wild crop; files in the scratchpad, not the repo): `crop_home_1600x900.png`, `crop_home_844x390.png`,
`crop_temperate_1600x900.png`, `crop_temperate_844x390.png`, 0 SCRIPT ERROR in all four logs. Looked at:
- Home grassland: corn shows as young corn plants (a stalk with broad leaves), about knee to waist high next to the
  survivor. Each has a "Corn" label, and they are spread out, not a field. The lab printed `Corn nodes=5 total_nodes=216`.
- temperate_25: wheat shows as pale ear stalks, about knee high, with "Wheat" labels. The lab printed `Wheat nodes=10`.
- At 844x390 both crops are small: the corn by the survivor sits right under its label, but you can see it. No
  fallback boxes and no overlap with the HUD.

## Vision fixes (both cited lines checked)

1. `docs/prd/durango-wild-lands-systems-prd.md:531` reads "Stalks / reeds → twine → rope" and `:533` reads
   "Hide → dried hide → straps". Both say what the task says. Changes (items.json, recipes.json):
   - `twine` gets a `twine` category; the `rope` slot takes `twine` x3 (it took any `lashing`: reed, root,
     vine, bark, tendon, straps, rope).
   - `dried_hide` gets `dried_hide` and `cured_hide`; `hide_strap` gets `cured_hide`. The `hide_strap` slot
     takes `dried_hide` (it took `uncut_hide`, which includes raw and raptor hide).
   - All 33 recipes with a `hide` slot now take `cured_hide`: tent_kit, cabin_bed_kit (staged), the forager,
     leather, hide-and-bone, raid, copper, bronze, iron and steel armour.
   - Dried hide and twine come first on the start island. Twine is a hand recipe from fibre (the grassland has
     fibre_stalk). Dried hide is the existing `dried_hide` recipe at the drying rack (raw hide from a butchered
     compsognathus or zebraceratops, both on home_grassland; drying_rack_kit is wood + lashing with no
     station). No processing.json row is needed in this patch. claude/mmo-w2-process already has
     `stations.drying_rack.recipes.dried_hide` (600 s). t_data's start-island walk proves it:
     `[t_data] start island: reachable=110 twine ~2.3 s dried_hide ~5.1 s hide_strap ~3.5 s rope ~8.9 s, metal []`
     (110 since round 3, when corn and corn_seed joined the start island), and it asserts twine, dried_hide, hide_strap, rope and tent_kit are all reachable there.
2. `docs/design/world-design.md:66` (the Grassland row) lists "fibre_stalk, branch, stone, herb_leaf, berries,
   clay", with no ore. The desert row lists copper_ore (tiers 35, 50) and the volcanic row lists black_iron (60).
   Changes (hook 9): CopperOreNode (desert) gains the `ore` yield. GraniteBoulder is unchanged from base, which
   never gave it ore (an earlier version of hook 9 added ore to it; that is reverted). t_data fails if the
   start-island walk reaches any item with the `ore` or `metal` category, and (since round 3) if a home climate's
   vegetation, special tiles or materials can yield one at all, whatever pick it needs.
   Every rung stays reachable through the islands that exist (desert_35/50, temperate_20/25/35/45,
   tundra_30/55, tropical_25/40, volcanic_60).
   Side effect of the honest walk: snowfield and blue_tropical have no island, so `silver_ore`, `pearl`,
   `coral` and `blue_dye` had no real source. Those four items are now `source_pending` (the reason is in
   items.json), and the `blue_dye` recipe (coral at the mortar) is `staged` until a blue_tropical island exists.

## Acceptance (round 4: scratch tree `w2data-r4-gate` on 753a3c64 + the hooks patch as committed in 1c9dfc83)

| Item | Result |
|---|---|
| t_data: every referenced id exists; every item has market_category and rarity | `[t_data] PASS items=223 recipes=155` (one fewer live recipe: `blue_dye` is staged). `STATUS_ACTIONS` is now cauterise, residence, struggle and pet_aggro only; with hook 14 every statuses.json `cleared_by` id is an item or one of those. Without hook 14: `[t_data] FAIL status infected_wound cleared_by syringe is an item or a listed action` |
| Progression walk logs time per rung, no unreachable rung | see the ladder table below; `[t_data] reachable=216/223 pending=["fish", "log_shelter_kit", "cabin_bed_kit", "silver_ore", "pearl", "coral", "blue_dye"] best_pick=steel` |
| Vision fix 1: twine and dried hide on the start island first; processing mandatory | `[t_data] start island: reachable=110 twine ~2.3 s dried_hide ~5.1 s hide_strap ~3.5 s rope ~8.9 s, metal []`; `_check_processing_chain` passes (no raw hide outside the drying step, rope takes twine only) |
| Vision fix 2: no metal source on the home climate | same line, `metal []`, and the static home assert passes. With CopperOreNode and TinOreNode added to grassland vegetation: `[t_data] FAIL home climate grassland grows no metal, but CopperOreNode yields copper_ore` / `... TinOreNode yields tin_ore` (the walk line still says `metal []`, which is why the static assert exists) |
| Nets I–V craftable; every tameable species has a reachable net | `[t_data] tameable species with a reachable net: 17`; tiers 1–5 each checked |
| steamer_kit and hoe craftable; armour in every 5–10 band 1–60 | `[t_data] armor_body levels [1, 10, 20, 30, 35, 40, 50, 55]`; head `[10, 20, 30, 35, 40, 50, 55]`; arms/legs same as body |
| equip_mount_lab and craft_lab PASS | `[equiplab] PASS`; `[craft_lab] PASS`; rc=0, 0 SCRIPT ERROR lines in either (headless, `-- --lab=<lab>`) |
| GAUNTLET: higher tier clearly better, level 5 tool clearly better than level 1 (round 4) | `[t_data] L55 armor_body via planner: copper_cuirass 2413 (copper), bronze_cuirass 2756 (bronze), iron_cuirass 3158 (iron), steel_cuirass 3650 (steel), raid_cuirass 4653 (steel)`; `[t_data] L55 weapon via planner: copper_sword 352 (copper), bronze_sword 402 (bronze), iron_sword 460 (iron), steel_sword 532 (steel), raid_maul 1460 (steel)`; `[t_data] level 1 -> 5 from the planner: flint_pick gather power x1.40, flint_spear damage x1.32`; the only items above steel at equal level are the raid kit, at the steel nodes: `[t_data] above steel_cuirass (686, gate Lv 45): raid_cuirass 875 at steel tier, gate scute_armor Lv 45` (helm, greaves likewise; `raid_maul 274 ... gate iron_weapons Lv 50` vs steel_sword 100) |
| Raid kit through the real crafting code (hook 15) | `[gear] maul L60 steel dmg=1569.6 kit armor=9291.3`, `[gear] PARTIAL real formulas/craft allocation; acquisition, station movement and raid evasions untested; failures=0` (rc=0, 0 SCRIPT ERROR, 0 FAIL lines) |
| every t_*.gd (round 4) | All 20 print their PASS line with rc=0: t_ai, t_build, t_canim, t_combat, t_data (`[t_data] PASS items=223 recipes=155`), t_harbour (`islands=15`), t_iconart, t_items, t_light, t_lighting (prints `[t_light] PASS`), t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons (`ids=171 files=114`), t_web. t_save prints its 5 deliberate SCRIPT ERRORs, as on base; every other log has 0 SCRIPT ERROR and 0 "couldn't resolve track". t_items first printed `[t_items] FAIL armor follows level x tier` (its literal 300 for raid_helm). Hook 11 now reads the def, and the rerun prints `[t_items] PASS`. |
| run_all, smoke (round 4) | `[tests] PASS` (rc=0, 0 SCRIPT ERROR); `SMOKE PASS` (tools/smoke.sh --no-import, rc=0). The progression probe was not rerun (round 2: `[progression] PARTIAL ... failures=0`, unchanged from base). |
| Labs (round 4) | `[equiplab] PASS`, `[craft_lab] PASS`, island_lab `[world] island temperate_25 nodes=397 creatures=24 terrain=meadow`; rc=0, 0 SCRIPT ERROR, 0 "couldn't resolve track" (headless, `-- --lab=<lab>`) |
| Import, crashes (round 4) | mkscratch import log has 0 error lines. No new Godot-*.ips: 34 before and after this round's runs, newest still Godot-2026-10-20-202004.ips |
| Pick chain in play code (t_items with hook 11) | `[t_items] bare hands: copper_ore='needs obsidian pick' black_iron='needs bronze pick'`; `[t_items] flint node seconds: bone pick (minimum tier) 2.68, flint pick 2.40, base 3.00` |
| Hook 6 enforces requires_node and says what to raise | `[t_data] smelt_copper gate: before 'needs Smelting 1 (Processing 25)', after learning smelting_1 ''` |

### Ladder numbers against the specs

Seconds are the walk's gathering + crafting time for the dearest tool of the rung, stations and travel
excluded. Rerun on 264950b4 with the island-driven walk: the same numbers to the decimal, so the vision fixes
did not move a rung. "Skill gate" is the trees.json level of the rung recipes' `requires_node`.

| Rung | Seconds | Skill gate | Its ore needs | Ore found on (island level) |
|---|---|---|---|---|
| stone | 6.5 | – | bare hands | everywhere |
| bone | 6.8 | – | (butchered, knife) | any kill |
| flint | 10.6 | Lv 5 `work_pick` | bone pick | temperate 20–35 |
| obsidian | 10.6 | Lv 15 `combat_knife` | flint pick | tropical 25–40 |
| copper | 44.0 | Lv 30 `copper_tools` | obsidian pick | desert 35–50 |
| bronze | 79.4 | Lv 40 `blade_shapes` | copper ore + tin (flint pick) | desert + temperate/tundra |
| iron | 92.0 | Lv 50 `iron_weapons` | bronze pick | volcanic 60 |
| steel | 225.2 | Lv 50 `iron_weapons` | (refined iron, `smelting_2`) | volcanic 60 |

What contradicted the specs and was fixed this round:
- **Bone was missing.** GAUNTLET: "Material ladder: Stone -> Bone -> Flint -> Obsidian -> Copper -> Bronze ->
  Iron -> Steel." The walk had no bone rung and bone had no named tools. Added bone tools; flint now needs a
  bone pick.
- **Bronze could be skipped and iron cost less than bronze** (iron ~50 s vs bronze ~79 s; iron ore opened
  with a copper pick). GAUNTLET: "Later ~5-level bands must feel materially harder and more rewarding."
  Black iron now needs a bronze pick, and `smelt_iron` takes 24 s instead of 10 s, so iron ~92 s > bronze.
- **Rung gates were bypassable** through the generic `blade_mat` tools (see "Rung gear only through gated
  recipes"). Owner 2026-10-18: "progression locked behind rare items or crafting recipes".
- Tool levels: crafted level comes from the input materials (W1-ITEMS code, unchanged). A level 5 tool is
  1.32x level 1 on damage and 1.40x on gather power (`level_multiplier`, 0.08 and 0.10 per level), times
  the tier multiplier (bone 1.12 … steel 2.45). The named tools' `base_level` stays 1, so the level is
  never stamped by data.
- Net tiers match the capture techniques (trees.json survival 15/25/35/45/55 → nets I–V, species tiers as
  listed in trees.json). Nothing contradicted. Net I stays ungated even though trees.json lists
  `capture_tool_1` "craft capture net I". CaptureSystem already needs Capture Technique I for any net
  capture, and `bot_survivor` crafts net I, so a recipe gate would add nothing but a break. Spec 02: "initial
  quadruped capture near level 15 is a historical reference", which matches Capture Technique I at Survival 15.
- Processing levels: spec 11's table lists "Basic Processing; Rope" at 1, "Leather Strap" at 10 and "Dry
  Leather" at 15, and trees.json `processing` has `cordage` 1 (twine, rope) and `drying` 10 (dried hide,
  straps). Rope, dried hide and straps stay ungated, the same rule as the early kits. A `drying` gate would put
  the starter tent behind Processing 10, and the vision fix asks for dried hide on the start island before
  anything needs it. The spec's own words for those levels are "should be verified", so nothing is contradicted.
  If W2-SKILLS or the owner wants the gate, it is one `requires_node: "drying"` per recipe.

### The new checks fail on the old behaviour

- Branch without the hooks (old nature_manifest, no hook 6): `[t_data] FAIL FlintNode flint needs a bone pick,
  the rung below it (has stone)`, `[t_data] FAIL BlackIronNode black_iron needs a bronze pick, the rung below
  it (has copper)`, `[t_data] FAIL progression_block refuses smelt_copper until smelting_1 is learned (before '',
  after '')`.
- Old recipes.json (before 264950b4): `[t_data] FAIL recipe rope slot lashing takes ["bark_strip", "reed", "root",
  "twine", "rope", "hide_strap", "vine", "predator_tendon"]; rope is twisted from twine only`, `[t_data] FAIL recipe
  hide_strap slot uncut_hide takes raw raw_hide; raw hide is dried first (Hide -> dried hide -> straps)`, and the
  same line for raptor_hide and for every armour, tent and bed recipe (tent_kit, cabin_bed_kit, raid_helm …
  steel_greaves).
- GraniteBoulder `ore` restored (the old hook 9): `[t_data] FAIL start island yields no metal, but ore comes from
  gather GraniteBoulder (grassland)`, `… but ingot comes from recipe ingot`, `… but metal_shard comes from recipe
  metal_shards`. The forge and the anvil were reachable on the home island.
- run_all with hook 12 on the old recipes.json and items.json: `ERROR: [tests] raw hide raw_hide is dried
  before cutting straps`, `ERROR: [tests] raw hide raptor_hide is dried before cutting straps`,
  `[tests] FAIL count=2` (rc=1).
- Mutation (steel_ingot back in `blade_mat`, smelt_iron back to 10 s): `[t_data] FAIL ungated recipe work_pick
  takes steel_ingot (steel tier) as its primary` (also improvised_stone_knife, work_axe, hoe) and
  `[t_data] FAIL rung iron tools (~50.0 s) cost at least the rung below (~79.4 s)`. Round 4 reran the blade_mat
  half against the rewritten check: `[t_data] FAIL recipe work_pick takes steel-tier material as its primary with
  skill gate Lv 0, below the ladder's steel gear gate Lv 45` (also improvised_stone_knife, work_axe, hoe), plus
  `[t_data] FAIL recipe metal_shards turns 1 blade_mat unit(s) into 2 metal_shard`.

## requires_node ids against both trees.json files

Rechecked in round 4 with `git show <ref>:game/data/skills/trees.json`. All 16 ids exist on
`claude/mmo-overhaul` (cecc936b) and on `claude/mmo-w2-skills` (03364e1a), in the same tree at the same level.
Round 4 puts `iron_weapons` and `scute_armor` on the raid recipes. Both were already gates, so the list stays at 16
ids. **W2-SKILLS must keep these ids:** `work_pick`, `combat_knife`, `copper_tools`, `blade_shapes`,
`iron_weapons`, `hammer` (weapon_tools); `smelting_1`, `smelting_2`, `nails_pillars` (processing);
`armor_1`, `scute_armor` (tailoring); `furnace_kiln` (construction); `steam`, `antivenom`, `antibiotic`
(cooking); `fertilizer` (farming). t_data fails loudly if any of them goes missing. W2-SKILLS' hook H1 adds
its own `SkillRules.recipe_block` check at the top of the same `progression_block`. The two checks are
independent, so H1 needs a rebase onto hook 6 and nothing else.

## Integrator hooks (`docs/orchestration/reports/claude-mmo-w2-data-hooks.patch`)

`git apply --check` is clean on `claude/mmo-overhaul` cecc936b (checked against a temporary index) and on the
branch (753a3c64). The branch has no
edits to `nature_manifest.json` or `world/rules.json` (`git diff claude/mmo-overhaul HEAD --` on both is
empty). Every edit to them is in hooks 9 and 10, with its reason given below.

1. `build_placer.gd _spawn`: `&"forge"` and `&"anvil"` → `CraftStation.make(...)`. W2-BUILDSYS also needs
   `forge`/`anvil` rows in structures.json `placed_kinds`.
2. `save_restore.gd`: add `&"forge", &"anvil"` to the CraftStation restore case.
3. `t_build.gd`: 24 → 26 kits.
4. `craft_ui.gd STATIONS`: add `["forge", "Forge", "ingot"], ["anvil", "Anvil", "hammer"]`.
5. `data/ui_icons.json`: `station_forge` uses station_fire.svg and `station_anvil` uses
   station_grindstone.svg until FORGEART/W1-UIICONS draw their own.
6. `crafting.gd progression_block`: enforce `requires_node` with `_node_block(player, node)`, which finds
   the node's tree in `SkillState.defs`, calls `is_unlocked`, and otherwise returns "needs <node name> (<Tree>
   <level>)", e.g. "needs Smelting 1 (Processing 25)" (round 4; it said "needs skill smelting 1"). Tested by
   t_data `_check_node_gate`. W2-SKILLS' H1 touches the same lines, so it must be regenerated on top of this hook. Also
   new this round: `_category_hint` and `sample_def_for_category` map `cured_hide` to `dried_hide`, so a
   blocked recipe says "Needs Dried Hide" and shows the dried-hide icon, not "Needs Cured Hide" with the
   fallback icon.
7. `harvest_node.gd OPTION_TOOLS`: pine_log, snow_pine, willow_wood and acacia_wood need an axe.
8. `item_def.gd` (W2-INV): `market_category`, `rarity` and `insulation` fields parsed from items.json.
9. `data/nature_manifest.json` (W1-ITEMS / W2-SCATTER / W3-NATUREART own it), each edit below.
10. `data/world/rules.json` `warp_ruin.loot` (W1-AI / W2-SPAWN own it): the dead ids `wire`, `medicine` and
    `rare_seed` become `pressure_dressing` (medicine) and `wheat_seed` (rare seed), and wire is dropped (round 4:
    no item is wire, and metal stays out of loot). The acceptance item requires every rules reference to exist.
11. `tests/t_items.gd` (W1-ITEMS): the pick-gate expectations follow hook 9. Black iron says "needs bronze
    pick" and refuses a copper pick. Flint says "needs bone pick" and refuses a stone pick. The minimum-tier
    speed comparison uses a bone pick. Round 4: "armor follows level x tier" takes raid_helm's armour from its
    def instead of the literal 300, because the rebase made it 153. Without that line the gate run printed
    `[t_items] FAIL armor follows level x tier`.
12. `tests/run_all.gd` `_test_hide_strap_no_self_input` (integrator file): raw_hide and raptor_hide must now be
    refused by the hide_strap recipe ("raw hide %s is dried before cutting straps"). dried_hide stays eligible,
    and the output, count and level checks are unchanged. Without this hook run_all fails on the branch with
    `uncut hide remains eligible raw_hide`.
13. `scripts/dev/bot_survivor.gd` (W1-QA) `CATEGORY_ITEMS`: adds `"twine": ["twine"]`, because rope takes the twine
    category only and no node yields twine, so `_acquire_for` now falls through to the twine recipe. Drops flint
    from `blade_mat`, which flint no longer fills. Checked by t_data `_check_bot_map`. claude/mmo-w1-qa (8597d1d3,
    unmerged) edits other parts of this file; this hunk also applies cleanly to its version.
14. `data/statuses.json` (W2-WEATHER) `infected_wound.cleared_by`: drops `syringe`, which is not an item, and keeps
    `antibiotic`. If W2-WEATHER's branch edits the same lines, keep their version minus `syringe`.
15. `scripts/dev/raid_gear_probe.gd` (W1-ITEMS), round 4: the probe stocks `steel_ingot` instead of `metal_shard`,
    learns `iron_weapons` and `scute_armor` like the tree levels it already sets, and its expected numbers become
    `112 × 5.72 × 2.45` (maul) and `(153 + 357 + 153) × 5.72 × 2.45` (kit). Without this hook the probe stops at
    `[gear] FAIL raid_maul level60 ingredients allowed` and `... exact ingredient allocation`, then hangs until the
    600 s alarm. With it: 0 FAIL lines (see round 4).

Hook 9, `nature_manifest.json`, edit by edit:
- `TinOreNode` family (reuses the silver-ore model, temperate and tundra, `tin_ore` needs a flint pick).
  The spec gives this package "Tin ore family", and a family can only live here.
- `FlintNode` flint `min_pick_tier` stone → bone, and `BlackIronNode` black_iron copper → bronze (the
  ladder fix above).
- `Corn` and `Wheat` get `"count": 10` (like FlaxPlant): a wild crop is a find, not the 24-plant floor (round 3).
- `Cactus` yield `spine` → `cactus_spine` (`spine` is not an item); `ore_chunk` removed from `Rock` (not an
  item; removing it also keeps Rock's single stone yield that t_items' depletion test reads).
- `CopperOreNode` (desert) also yields `ore` 0–1 with `min_pick_tier {"ore": "obsidian"}`. That is the only
  source for Rough Ore, which the Crude Ingot recipe needs. GraniteBoulder is unchanged from base (stone only).
  An earlier version of this hook gave it ore, but it grows on the home grassland, and world-design.md:66 gives
  the grassland no ore.
- Extra yields on natural families for items that had no source: `pine_log` (PineTree), `snow_pine`
  (PineTree_Snow), `willow_wood` (Willow, 1–2), `leech` (Lilypad), `lava` (LavaRockNode), `root` (TreeStump,
  TreeStump_Moss, tree_stump), `mushroom` (Plant) and `spice_herb` (HerbPlant), all 0–1 unless noted. Without them t_data's
  "every item reachable" fails and recipes like `antibiotic`, `seasoned_roast` and `spiced_skewer` can never
  be crafted.

On the branch alone t_data, t_build, t_uiicons, t_items and run_all fail until these hooks land. t_data also
fails without hooks 6, 9 (Corn/Wheat count), 10, 13 and 14. The other lines are `[t_build] FAIL route forge_kit` /
`anvil_kit`, `[t_uiicons] FAIL station_forge (from recipes.json) has its own icon, not the fallback`, run_all's
`uncut hide remains eligible raw_hide` (hook 12), and since round 4 `[t_items] FAIL armor follows level x tier`
(hook 11). raid_gear_probe is not a gate, but it fails without hook 15. With the patch applied every gate passes.

Not in the patch (follow-ups for their owners):
- ItemArt should read `ItemDef.rarity` instead of item_rarity.json (ICONS2/W2-SCREENS), then delete it.
- A repair action that consumes `recipes.json repairs` (W2-PROCESS or W2-CRAFT).
- Insulation should feed climate fatigue (W2-SURVIVAL/W2-WEATHER).
- Forge and anvil models (FORGEART, after this merges); they use the CraftStation fallback box today.
- **W3-SRVACT acceptance item:** the server craft path (`intent_handlers.gd` act.craft, lines 165-190) checks
  `required_survival` and `min_level` but not `requires_node`, because CharacterState keeps tree levels only.
  Online, a player can craft a gated recipe without the node. Required: an intent test that crafts `smelt_copper`
  without `smelting_1` and gets refused. A level stand-in (`ch.level_of(tree) >= node level`) was not added here,
  because it changes multiplayer authority.
- **ICONS2 / W1-UIICONS: per-item art for the 59 new items.** None has a render or a symbol of its own: tin_ore,
  tin_ingot, moss, cactus_flower, forge_kit, anvil_kit, capture_net_iii, capture_net_iv, capture_net_v,
  bone_knife, bone_axe, bone_pick, bone_spear, flint_knife, flint_axe, flint_pick, flint_spear, obsidian_knife,
  obsidian_axe, obsidian_pick, obsidian_spear, copper_knife, copper_axe, copper_pick, copper_sword, bronze_knife,
  bronze_axe, bronze_pick, bronze_sword, iron_knife, iron_axe, iron_pick, iron_sword, steel_knife, steel_axe,
  steel_pick, steel_sword, leather_helm, leather_cuirass, leather_bracers, leather_greaves, copper_helm,
  copper_cuirass, copper_bracers, copper_greaves, bronze_helm, bronze_cuirass, bronze_bracers, bronze_greaves,
  iron_helm, iron_cuirass, iron_bracers, iron_greaves, steel_helm, steel_cuirass, steel_bracers, steel_greaves,
  antivenom, antibiotic. Until then the tools borrow the stone-tier symbol of their kind (knife, axe, pick; swords
  and spears the stone knife), so the anvil list looks the same on every tier. The armour borrows the
  `armour_*` renders, and tin_ingot borrows the ingot symbol. When an item gets its own art, drop its alias.
- **W2-LOOP / W3-EXCHANGE:** factions.json `radio_university.crate_tstones` (`{"1-3": 200, "7-10": 2000}`) replaces
  the fake crate items `tstones_200` / `tstones_2000`. No code reads it yet. A consumer must pay those T-stones
  through the real money path, because money is an owner gate. Until then the crate pays nothing in those bands.
- W2-GATHER (unmerged) should re-check its gather tests against the raised flint and black-iron gates.
- **W1-ITEMS:** raid_fight_probe, tyrant_window_probe and counter_matchup_probe make raid gear with no material, so
  it is stone tier and, after the round 4 rebase, half as strong as before. Pass `{"material_tier": "steel"}` there
  so the fixture matches the crafted kit. raid_fight_probe stays `PARTIAL` either way (see round 4).
- **W2-SKILLS:** regenerate H1 on top of hook 6 (`_node_block` replaced `_node_unlocked`). Learning a node in a
  fixture (`trees[tree]["unlocked"].append(id)`, as hook 15 does) must keep working with W2-SKILLS' SkillState.

## Assumptions (all tunable data)

- Tin is found on temperate and tundra islands with a flint pick (tin reads as stone tier by name, so it is
  outside the pick-chain rule).
- Rung gates: bone none (like stone), flint `work_pick`, obsidian `combat_knife`, copper `copper_tools`,
  bronze `blade_shapes`, iron and steel `iron_weapons`.
- Bone tools take 4 s to carve (stone tools 3 s), so the bone rung is not cheaper than the stone one.
- `smelt_iron` takes 24 s (copper and tin 8 s): iron needs the hottest smelt, and it keeps the iron rung
  dearer than bronze.
- Material counts per recipe: knife 1, axe/pick 2, weapon 3 of the rung material; bronze 2+1 → 2.
- Armour base values: leather 90/200/70/100; metal 120/280/95/130 ×tier multiplier; durability 300/400.
- Raid kit (round 4): steel ingots as the primary, `iron_weapons` (maul) / `scute_armor` (armour), and base values
  rebased by 1.25/2.45 (maul 112, cuirass 357, helm and greaves 153), so the crafted L60 kit matches the tuned
  shard kit within 0.3 %. The kit stays above the steel set at equal level (cuirass 875 vs 686 at L1). It is a
  raid set: the same steel and node, plus Survival 50, four times the hide and the status protection. The station
  stays the workbench, and `max_durability` (400) and `health_bonus` are unchanged. A crafted kit's durability now
  scales with steel (×2.45) instead of shard (×1.25).
- Warp-ruin loot (round 4, world-design.md:106 "courier boxes with cloth, wire, medicine, rare seeds"): cloth_scrap,
  pressure_dressing and wheat_seed. Wire is left out (no wire item; a metal stand-in would break "no metal at
  home" if a ruin were ever placed there). Rare seeds become wheat, the one seed that does not grow on the start
  island.
- Insulation points: travel 1/1, forager 1/2, hide_bone 2/0, leather 2/1, metal 1/0.
- Repairs restore 50 % for one unit of the tier material.
- The walk's capture and taming times (60/120 s) only feed the time log.
- Rough ore is a 0–1 byproduct of the desert copper node and needs an obsidian pick. world-design.md lists the
  desert's crater as "mineral (copper, salt)", and the copper node is the first metal node.
- `cured_hide` means dried hide (round 4: straps left the category, because two straps from one hide filled two
  units). Straps are lashing. Rope still takes 3 twine.
- Wild crops (round 3): Corn grows on the home grassland, its manifest climate. PRD:615 and prompt 12:80 put corn
  early, and world-design.md's grassland row lists no crops, so its placement there is this assumption. Wheat
  grows on temperate islands only (its manifest also lists grassland; the docs are silent, so the home island
  keeps a single crop). Both have `count: 10`, the FlaxPlant value, which gives 5 corn on the home island and 10
  wheat per temperate island. # ASSUMPTION is in the hook 9 data; JSON has no comments, so it is recorded here.
- Armour skill gates (round 3): copper (L35) and bronze (L40) armour require `armor_1` (Tailoring 35), and iron
  (L50) and steel (L55) armour require `scute_armor` (Tailoring 45). The docs name no armour gates. On base these
  nodes are labelled "hide armour" / "scute armour"; W2-SKILLS calls them "Armor 1" / "Scute armor". Hide sets
  (leather L20, hide_bone L30) stay ungated, so the first armour does not sit behind Tailoring 35. If W2-SKILLS
  adds metal-armour nodes, move these gates to them.
- Armour icon stand-ins (round 3): `armour_head/body/arms/legs` point at the raid helm, raid cuirass, forager wraps
  and raid greaves renders.
- `crate_tstones` (factions.json) holds the T-stone amounts the old fake crate items carried; nothing reads it.
- Faction crate mapping: fatigue_tonic → camp_stew, medicine → pressure_dressing, rare_seed → corn_seed,
  seeds → flax_seed, nails → metal_shard, technical_workbench_kit → anvil_kit, weapon_parts → hide_strap,
  armor_parts → armor_scute, farming_tools → hoe, elixir_ingredient → marsh_herb.

## Not done / open

- **fish** has no source because no fishing system exists. It is marked `source_pending`, which t_data
  allows only when the item is never a recipe's only option and never a crate reward. log_shelter_kit and
  cabin_bed_kit stay staged.
- **One recipe per structures.json piece was not added.** W2-BUILDSYS pieces spend `material_slots`
  directly (spec 10 construction sites), so a kit recipe would set a second price for the same piece.
  t_data checks that every item a piece tier or placed kind spends is reachable when structures.json exists.
  `_check_structures` is a no-op on the current base (no structures.json) and starts checking when W2-BUILDSYS merges.
- trees.json was not edited, because W2-SKILLS is re-keying it.
- Not touched by this package: gather-03 (latent attribute stamping is code), climate-01 (weather) and the
  Durango trait/alloy effects from prompt 04 (W2-PROCESS/W2-CRAFT).
- Screenshots: only the wild crops (round 3, see above). New harvest options on existing nodes, TinOreNode on
  temperate/tundra islands, rough ore on desert copper nodes and the "Needs Dried Hide" craft hint were not
  checked in pixels.
- **Snowfield and blue_tropical have no island** in islands.json, so `silver_ore`, `pearl`, `coral` and
  `blue_dye` are `source_pending` and the `blue_dye` recipe is staged. Whoever adds those islands (W2-SPAWN /
  W1-BIOME) should drop the four `source_pending` fields and the recipe's `implementation_status`. t_data then
  walks the new island automatically.
- Labs to register: none new. t_data runs like the other t_*.gd.

## What is left (exact next steps)

1. Re-review with the hooks applied (`mkscratch.sh <name> claude/mmo-w2-data
   docs/orchestration/reports/claude-mmo-w2-data-hooks.patch`).
2. Integrator: `git apply` the hooks patch at merge, rerun every gate, then W2-SKILLS rebases H1 onto hook 6.
3. Follow-ups under "Not in the patch" and "Not done / open".
