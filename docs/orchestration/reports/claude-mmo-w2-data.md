# W2-DATA report: item and recipe data, material ladder, nets, armour bands

Branch `claude/mmo-w2-data`, merged with `claude/mmo-overhaul` at 3213777f. Gates ran on 2f2bc9e4 with the hooks
patch applied (scratch tree `work-w2-data`). No dsc worker was used (the owner took DeepSeek off on 2026-10-20),
so nothing goes in dsc-improvements.md. No credits spent.

## What shipped

- **Material ladder Stone → Bone → Flint → Obsidian → Copper → Bronze → Iron → Steel (GAUNTLET), every rung
  reachable.** New `tin_ore` (TinOreNode family, temperate and tundra, needs a flint pick) and `tin_ingot`.
  Smelting happens at a new fuelled **forge** (`forge_kit`, place_as `forge`): tin, copper (`copper_ore`), iron
  (`black_iron`), bronze alloy (2 copper + 1 tin + fuel gives 2 bronze) and steel (2 iron + 2 fuel). The old
  `ore` → `ingot` recipe is now "Crude Ingot" at the forge with fuel. `ore` (Rough Ore) comes from granite
  boulders with a pick.
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
- **market_category and rarity on every item.** Market categories are the market.json price keys.
  `item_rarity.json` is now a generated mirror of `items.json` rarity, and t_data fails if the two disagree.
- **Recipe gates:** progression recipes carry `requires_node` (a trees.json node id). Hook 6 makes
  `Crafting.progression_block` enforce it. Existing early kits are left ungated so the starting loop does
  not change.
- **Repairs:** `recipes.json "repairs"` has one row per ProgressionScaling tier. They are data only; a
  consumer still has to be written.
- **Missing sources and dead references fixed:** recipes for `hoe`, `steamer_kit`, `pillar`, `claim_stake`,
  `stone_knife`, `cloth_scrap`, `metal_shard`, `blue_dye`, `fruit_fertilizer`, seed extraction for all four
  crops, and `antivenom`/`antibiotic`. New items `moss` and `cactus_flower` for existing nature yields.
  Faction crate ids now point at real items.
- **Loops fixed:** `sashimi`, `carnivore_feed` and `herbivore_feed` were multiplying loops (output fed its
  own slot, x2/x3). The slots now take raw meat.
- **Validator `game/tests/t_data.gd`:** references across every data file; a walk from bare hands over real
  sources only (climate vegetation × nature yields with HarvestNode's own tool and pick-tier gates,
  butchering, farming, capture, taming, recipes); ladder, nets, armour bands and loops; 39 recipes crafted
  through the real `Crafting.preview` planner. New this round: rung time and skill gate never drop along the
  ladder, the pick chain, no ungated recipe turns obsidian or metal into gear, and a hook 6 check that
  `progression_block` refuses `smelt_copper` until `smelting_1` is learned.

## Acceptance (scratch tree on 2f2bc9e4 + hooks patch)

| Item | Result |
|---|---|
| t_data: every referenced id exists; every item has market_category and rarity | `[t_data] PASS items=223 recipes=156` |
| Progression walk logs time per rung, no unreachable rung | see the ladder table below; `best_pick=steel`; `reachable=220/223 pending=["fish", "log_shelter_kit", "cabin_bed_kit"]` |
| Nets I–V craftable; every tameable species has a reachable net | `[t_data] tameable species with a reachable net: 17`; tiers 1–5 each checked |
| steamer_kit and hoe craftable; armour in every 5–10 band 1–60 | `armor_body levels [1, 10, 20, 30, 35, 40, 50, 55]`; head `[10, 20, 30, 35, 40, 50, 55]`; arms/legs same as body |
| equip_mount_lab and craft_lab PASS | `[equiplab] PASS`, `[craft_lab] PASS`, 0 SCRIPT ERROR lines in either |
| every t_*.gd, run_all, smoke, progression probe | All 20 t_*.gd print `[<name>] PASS` with rc=0 (t_data, t_build, t_uiicons, t_items, t_ui, t_iconart, t_save, t_tame, t_player, t_combat, t_ai, t_canim, t_harbour, t_light, t_lighting, t_occlude, t_server_domain, t_srvdom, t_structart, t_web). t_save prints its 5 deliberate SCRIPT ERRORs, as on base; every other log has 0 SCRIPT ERROR and 0 "couldn't resolve track". `[tests] PASS` (run_all); `SMOKE PASS` (tools/smoke.sh --no-import); `[progression] PARTIAL seeded gate fixture, earned loop and raid fight untested; failures=0` (unchanged from base). Import log has 0 error lines. No new Godot-*.ips (25 before and after, newest Godot-2026-10-20-131531.ips). |
| Pick chain in play code (t_items with hook 11) | `[t_items] bare hands: copper_ore='needs obsidian pick' black_iron='needs bronze pick'`; `[t_items] flint node seconds: bone pick (minimum tier) 2.68, flint pick 2.40, base 3.00` |
| Hook 6 enforces requires_node | `[t_data] smelt_copper gate: before 'needs skill smelting 1', after learning smelting_1 ''` |

### Ladder numbers against the specs

Seconds are the walk's gathering + crafting time for the dearest tool of the rung, stations and travel
excluded. "Skill gate" is the trees.json level of the rung recipes' `requires_node`.

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
  capture, and `bot_survivor` crafts net I, so a recipe gate would add nothing but a break.

### The new checks fail on the old behaviour

- Branch without the hooks (old nature_manifest, no hook 6): `[t_data] FAIL FlintNode flint needs a bone pick,
  the rung below it (has stone)`, `[t_data] FAIL BlackIronNode black_iron needs a bronze pick, the rung below
  it (has copper)`, `[t_data] FAIL progression_block refuses smelt_copper until smelting_1 is learned (before '',
  after '')`.
- Mutation (steel_ingot back in `blade_mat`, smelt_iron back to 10 s): `[t_data] FAIL ungated recipe work_pick
  takes steel_ingot (steel tier) as its primary` (also improvised_stone_knife, work_axe, hoe) and
  `[t_data] FAIL rung iron tools (~50.0 s) cost at least the rung below (~79.4 s)`.

## requires_node ids against both trees.json files

All 16 ids exist on `claude/mmo-overhaul` and on `claude/mmo-w2-skills` (65853f76), in the same tree at the
same level. **W2-SKILLS must keep these ids:** `work_pick`, `combat_knife`, `copper_tools`, `blade_shapes`,
`iron_weapons`, `hammer` (weapon_tools); `smelting_1`, `smelting_2`, `nails_pillars` (processing);
`armor_1`, `scute_armor` (tailoring); `furnace_kiln` (construction); `steam`, `antivenom`, `antibiotic`
(cooking); `fertilizer` (farming). t_data fails loudly if any of them goes missing. W2-SKILLS' hook H1 adds
its own `SkillRules.recipe_block` check at the top of the same `progression_block`. The two checks are
independent, so H1 needs a rebase onto hook 6 and nothing else.

## Integrator hooks (`docs/orchestration/reports/claude-mmo-w2-data-hooks.patch`)

`git apply --check` is clean on `claude/mmo-overhaul` 3213777f and on the branch.

1. `build_placer.gd _spawn`: `&"forge"` and `&"anvil"` → `CraftStation.make(...)`. W2-BUILDSYS also needs
   `forge`/`anvil` rows in structures.json `placed_kinds`.
2. `save_restore.gd`: add `&"forge", &"anvil"` to the CraftStation restore case.
3. `t_build.gd`: 24 → 26 kits.
4. `craft_ui.gd STATIONS`: add `["forge", "Forge", "ingot"], ["anvil", "Anvil", "hammer"]`.
5. `data/ui_icons.json`: `station_forge` uses station_fire.svg and `station_anvil` uses
   station_grindstone.svg until FORGEART/W1-UIICONS draw their own.
6. `crafting.gd progression_block`: enforce `requires_node` with `_node_unlocked(player, node)`, which finds
   the node's tree in `SkillState.defs` and calls `is_unlocked`. Tested by t_data `_check_node_gate`.
7. `harvest_node.gd OPTION_TOOLS`: pine_log, snow_pine, willow_wood and acacia_wood need an axe.
8. `item_def.gd` (W2-INV): `market_category`, `rarity` and `insulation` fields parsed from items.json.
9. `data/nature_manifest.json` (W1-ITEMS / W2-SCATTER / W3-NATUREART own it), each edit below.
10. `data/world/rules.json` `warp_ruin.loot` (W1-AI / W2-SPAWN own it): dead ids `wire`, `medicine` and
    `rare_seed` become `metal_shard`, `pressure_dressing` and `corn_seed`. The acceptance item requires
    every rules reference to exist.
11. `tests/t_items.gd` (W1-ITEMS): the pick-gate expectations follow hook 9. Black iron says "needs bronze
    pick" and refuses a copper pick. Flint says "needs bone pick" and refuses a stone pick. The minimum-tier
    speed comparison uses a bone pick.

Hook 9, `nature_manifest.json`, edit by edit:
- `TinOreNode` family (reuses the silver-ore model, temperate and tundra, `tin_ore` needs a flint pick).
  The spec gives this package "Tin ore family", and a family can only live here.
- `FlintNode` flint `min_pick_tier` stone → bone, and `BlackIronNode` black_iron copper → bronze (the
  ladder fix above).
- `Cactus` yield `spine` → `cactus_spine` (`spine` is not an item); `ore_chunk` removed from `Rock` (not an
  item; removing it also keeps Rock's single stone yield that t_items' depletion test reads).
- `GraniteBoulder` yields `ore` 0–1 with `min_pick_tier {"ore": "stone"}`. That is the only source for
  Rough Ore, which the Crude Ingot recipe needs.
- Extra yields on natural families for items that had no source: `pine_log` (PineTree), `snow_pine`
  (PineTree_Snow), `willow_wood` (Willow, 1–2), `leech` (Lilypad), `lava` (LavaRockNode), `root` (TreeStump,
  TreeStump_Moss, tree_stump), `mushroom` (Plant) and `spice_herb` (HerbPlant), all 0–1 unless noted. Without them t_data's
  "every item reachable" fails and recipes like `antibiotic`, `seasoned_roast` and `spiced_skewer` can never
  be crafted.

On the branch alone t_data, t_build and t_uiicons fail until these hooks land: `[t_build] FAIL route
forge_kit` / `anvil_kit`, `[t_uiicons] FAIL station_forge (from recipes.json) has its own icon, not the
fallback`, and the t_data lines above. With the patch applied every gate passes.

Not in the patch (follow-ups for their owners):
- ItemArt should read `ItemDef.rarity` instead of item_rarity.json (ICONS2/W2-SCREENS), then delete it.
- A repair action that consumes `recipes.json repairs` (W2-PROCESS or W2-CRAFT).
- Insulation should feed climate fatigue (W2-SURVIVAL/W2-WEATHER).
- Forge and anvil models (FORGEART, after this merges); they use the CraftStation fallback box today.
- The server craft path (`intent_handlers.gd _craft`) checks `required_survival` and `min_level` but not
  `requires_node`, because CharacterState keeps tree levels only. Online gating needs W3-SRVACT.
- `bot_survivor.gd` lists flint for `blade_mat`; flint no longer fills it and now needs a bone pick. The
  bot still makes its first tools from stone. W1-QA should drop flint from that list.
- W2-GATHER (unmerged) should re-check its gather tests against the raised flint and black-iron gates.

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
- Insulation points: travel 1/1, forager 1/2, hide_bone 2/0, leather 2/1, metal 1/0.
- Repairs restore 50 % for one unit of the tier material.
- The walk's capture and taming times (60/120 s) only feed the time log.
- Faction crate mapping: fatigue_tonic → camp_stew, medicine → pressure_dressing, rare_seed → corn_seed,
  seeds → flax_seed, nails → metal_shard, technical_workbench_kit → anvil_kit, weapon_parts → hide_strap,
  armor_parts → armor_scute, farming_tools → hoe, elixir_ingredient → marsh_herb.

## Not done / open

- **fish** has no source because no fishing system exists. It is marked `source_pending`, which t_data
  allows only when the item is never a recipe's only option and never a crate reward. log_shelter_kit and
  cabin_bed_kit stay staged.
- `syringe` in statuses.json `infected_wound.cleared_by` is not an item. t_data lists it as an action.
  W2-WEATHER should drop it or ask for an item.
- **One recipe per structures.json piece was not added.** W2-BUILDSYS pieces spend `material_slots`
  directly (spec 10 construction sites), so a kit recipe would set a second price for the same piece.
  t_data checks that every item a piece tier or placed kind spends is reachable when structures.json exists.
- trees.json was not edited, because W2-SKILLS is re-keying it.
- Not touched by this package: gather-03 (latent attribute stamping is code), climate-01 (weather) and the
  Durango trait/alloy effects from prompt 04 (W2-PROCESS/W2-CRAFT).
- No screenshots: this package changes data only. New harvest options on existing nodes, TinOreNode on
  temperate/tundra islands and rough ore on granite boulders were not checked in pixels.
- Labs to register: none new. t_data runs like the other t_*.gd.

## What is left (exact next steps)

1. Independent review with the hooks applied (`mkscratch.sh <name> claude/mmo-w2-data
   docs/orchestration/reports/claude-mmo-w2-data-hooks.patch`).
2. Integrator: `git apply` the hooks patch at merge, rerun every gate, then W2-SKILLS rebases H1 onto hook 6.
3. Follow-ups under "Not in the patch" and "Not done / open".
