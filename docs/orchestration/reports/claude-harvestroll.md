# HARVESTROLL: every gather pass is its own lot

Branch `claude/mmo-harvestroll` (from `origin/claude/mmo-overhaul`). Owner, 2026-10-28: "resource acquisition doesn't appear to be randomized ... it kept giving me the same branch".

## Cause

`HarvestNode.roll_yield` ignored its rng. It returned `yield_attributes`, which `IslandScatter.plant_at` set once at spawn to `{climate, level}`. Every unit from a node was the same item: same level and no rolled attributes. The server `act.gather` did the same with the node's stored attributes. The only per-pass roll was the green rare trait (5%) and finds, and those run off a properly advancing rng (`GatherService.rng`, randomized; the server's per-op `ServerRng`). So about 19 of 20 branches were identical. ONEGATHER's one-item-per-pass rule made this easy to see. No rng was seeded per node or per time window.

## What now varies per harvest

`LootRoller.roll_lot(item, node_level, tool_tier, skill, rng)` runs once per pass. The client (`PlayerActions.finish_gather`), tribe workers (`TribeMember`) and the server (`IntentHandlers._gather`) all call it:

- **Level** inside the node's band `max(1, S-5)..S`, never above S. This is the Traits math doc's site roll, `lo + min(5, floor(6·U^γ))`. γ starts at 1.5 for Gathering 1 with bare hands. Gathering 60 lowers it by 0.5 and a steel tool lowers it by a further 0.25, so skill and tools push results toward the top of the band.
- **Signed material traits** (spec 04's gold/grey). One grey trait at 96% and one gold trait at 7%. The gold odds scale with tool tier and Gathering, capped at 12%. Each trait has magnitude 1..3. The trait is picked from the item's category: wood, stone, ore, fibre, lashing or earth. Food, herbs and treasure roll level only.
- The existing green rare trait and finds still roll per pass, unchanged.
- Each pass still gives exactly one item (ONEGATHER). No gatherable item has variants, so nothing is rolled for variants.

The downrank cap (`max(Gathering, 5)`) still applies after the roll. A level-1 starter node always yields level 1, so on the home island the visible variety comes from the traits.

## Files

- `game/scripts/gather/loot_roller.gd`: `roll_lot`
- `game/scripts/gather/loot_tables.gd`: `lot_cfg`
- `game/data/loot_tables.json`: `lot` section (all numbers, marked ASSUMPTION)
- `game/scripts/world/harvest_node.gd`: `roll_yield(rng, tool_tier, skill)`. The rng defaults to `GatherService.rng`.
- `game/scripts/player/player_actions.gd`, `game/scripts/tribe/tribe_member.gd`, `game/scripts/server/intent_handlers.gd`: pass rng, tool tier and skill. The server uses the op's seeded rng, so replay stays deterministic.
- `game/data/economy/limits.json`: whitelists the 21 gold/grey trait keys (int 0..60). Before this, vault and market deposits refused them, and `t_econ` and `t_uimarket` broke.
- `game/tests/t_harvestroll.gd`: new test. 30 passes on one level-20 birch branch node give at least 5 distinct lots with levels in 15..20. The same seed replays the same sequence and another seed gives a different one. Count is 1 every pass. The expert's mean level is above the novice's, and a level-1 node always yields level 1.
- `docs/vision/WildLandsMMO_Open_Questions.md`: HR1-HR3.

## Checks

- `tools/all_tests.sh` (126 tests): the real failures were `t_econ` and `t_uimarket`, which the vault refusing the new trait keys caused; the limits.json whitelist fixed both. After that, a run at JOBS=2 gave 123/126. The 3 failures were timing gates under machine load (`t_buildspeed` and `t_perfgates` at 2.6-2.7 s against a 2.5 s budget, and `t_weather` thunder frame timing). All 3 passed when re-run alone (`t_weather` failed once alone, then passed twice). An earlier JOBS=4 run had other timing flakes (`t_eyetrails`, `t_petfollow`, `t_uigather`), which also pass alone. No single run of all 126 came back with 0 failures.
- `t_server_domain` (journal replay) passes.
- `tools/smoke.sh --no-import`: SMOKE PASS.

## Open for the owner / next agent

- HR2: 96% of material lots now carry a grey trait. Those are the math doc's unapproved candidate odds. If that feels too punishing, lower `lot.negative_chance`.
- HR3: the category trait lists are placeholders. Spec 04 wants per-resource tables.
- Credits spent: 0.
