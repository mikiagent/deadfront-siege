# W2-DATA report: item and recipe data, material ladder, nets, armour bands

Branch `claude/mmo-w2-data` (merged with `claude/mmo-overhaul` at d92f183b). No dsc worker was used
(owner took DeepSeek off on 2026-10-20), so nothing goes in dsc-improvements.md. No credits spent.

## What shipped

- **Material ladder stone → steel, all reachable.** New `tin_ore` (TinOreNode family: temperate and tundra,
  needs a flint pick) and `tin_ingot`. Smelting at a new fuelled **forge** (`forge_kit`, place_as `forge`):
  tin, copper (`copper_ore`), iron (`black_iron`), bronze alloy (2 copper + 1 tin + fuel gives 2 bronze),
  steel (2 iron + 2 fuel). The old `ore` → `ingot` recipe is now "Crude Ingot" at the forge with fuel.
  `ore` (Rough Ore) comes from granite boulders with a pick. The ingot items got their missing
  base_level/tool_class and categories `ingot` + `tier_<metal>`.
- **Named tools and weapons on every rung:** `<tier>_knife/_axe/_pick` plus `<tier>_spear` (flint,
  obsidian) or `<tier>_sword` (copper, bronze, iron, steel), 24 items. Flint and obsidian are made at the
  workbench; metals at a new **anvil** (`anvil_kit`). Base stats match the generic archetypes, and
  `ProgressionScaling.tier_multiplier` makes the step between tiers, so the multiplier is never applied twice.
  The stone rung keeps the existing `stone_knife_work`, `work_axe`, `work_pick` and `stone_knife`.
- **Capture nets I–V:** recipes for II–V. III and up need predator tendon; IV needs metal; V needs armour
  scutes and bronze. The Committee crate ids `capture_net_iii`/`capture_net_v` now exist. All 17 tameable
  species have a reachable net and technique.
- **Armour in every band 1–60:** a new leather set (L20), plus copper (35), bronze (40), iron (50) and steel
  (55). Each set has helm, cuirass, bracers and greaves, 20 items in total. All armour and clothing has
  `insulation {cold, heat}`.
- **market_category and rarity on every item.** Market categories are the market.json price keys.
  `item_rarity.json` is now a generated mirror of `items.json` rarity, and t_data fails if the two disagree.
- **Recipe gates:** new progression recipes carry `requires_node` (a trees.json node id): rung tools,
  forge (`furnace_kiln`), anvil (`hammer`), smelting (`smelting_1/2`), metal armour (`armor_1`,
  `scute_armor`), steamer (`steam`), pillar, fertilizer, antivenom, antibiotic. Existing early kits are
  left ungated so the starting loop does not change.
- **Repairs:** `recipes.json "repairs"` has one row per ProgressionScaling tier, with the material, the
  station and `restore_fraction`. These are data only; a consumer still has to be written.
- **Missing sources and dead references fixed:** recipes for `hoe`, `steamer_kit`, `pillar`, `claim_stake`,
  `stone_knife`, `cloth_scrap`, `metal_shard` (anvil), `blue_dye` (coral at the mortar),
  `fruit_fertilizer`, seed extraction for all four crops, and `antivenom`/`antibiotic` (the statuses.json
  counters; the PRD gives both to Cooking). New items `moss` and `cactus_flower` for existing nature yields.
  Faction crate ids now point at real items, and the T-stone grants moved to `crate_tstones`.
- **Loops fixed:** `sashimi`, `carnivore_feed` and `herbivore_feed` were multiplying loops (output fed its
  own slot, x2/x3). The slots now take raw meat, and herbivore_feed no longer counts as fruit/stalk.
- **Validator** `game/tests/t_data.gd` covers four areas:
  - It checks references across recipes, repairs, factions, rules warp_ruin loot, statuses cleared_by,
    climates, nature_manifest, butchering, farming, structures.json (when present) and requires_node.
  - It walks progression from bare hands using only real sources: climate vegetation × nature yields with
    HarvestNode's own OPTION_TOOLS and pick-tier gates, butchering, farming, capture and taming, and recipes.
    A recipe only counts if its station kit is reachable, and min_level only counts if materials of that
    level are reachable. Faction crates are never a source.
  - It checks the ladder, nets, armour bands and multiplying loops.
  - It crafts 35 recipes through the real `Crafting.preview` planner from the walked materials. Each pick
    must come out with its rung's material tier.
  - Mutation checks: removing TinOreNode from the climates gives FAILs (bronze_ingot, tin_ore, tin_ingot,
    capture_net_v and others). The pre-package data gives 712 FAIL lines.

## Acceptance

| Item | Result |
|---|---|
| t_data: every referenced id exists; every item has market_category and rarity | `[t_data] PASS items=219 recipes=152` |
| Extended progression walk logs time per rung, no unreachable rung | `[t_data] rung stone ~6 s, flint ~10 s, obsidian ~10 s, copper ~44 s, bronze ~79 s, iron ~50 s, steel ~141 s` (gathering+crafting seconds per tool, stations excluded); `best_pick=steel` |
| Nets I–V craftable; every tameable species has a reachable net | `[t_data] tameable species with a reachable net: 17`; each tier 1–5 is checked |
| steamer_kit and hoe craftable; armour in every 5–10 band 1–60 | `armor_body levels [1, 10, 20, 30, 35, 40, 50, 55]`; head `[10, 20, 30, 35, 40, 50, 55]`; arms/legs same as body |
| equip_mount_lab and craft_lab PASS | `[equiplab] PASS`, `[craft_lab] PASS` (on the branch, and again with the hooks applied) |
| tools/smoke.sh --no-import | `SMOKE PASS` |
| run_all | `[tests] PASS` |
| Other t_*.gd | On the branch alone, **t_build** and **t_uiicons** FAIL until the hooks below land: t_build counts 24 kits and cannot spawn forge/anvil, and t_uiicons has no station_forge/anvil icon. With `claude-mmo-w2-data-hooks.patch` applied: t_build, t_uiicons, t_ui, t_data, t_items, t_iconart, t_save (5 deliberate SCRIPT ERRORs, as on base) and run_all all PASS, plus craft_lab and equip_mount_lab. Every other t_*.gd passes on the branch. |

The progression probe (`-- --progression-probe`) is unchanged and still prints `[progression] PARTIAL ...
failures=0`. My ladder walk is in t_data and does not extend that probe, because progression_probe.gd
belongs to W1-ITEMS.

No screenshots: this package changes data only. Possible visual effects are new harvest options on
existing nodes, Corn/Wheat/TinOreNode on temperate islands, and rough ore on granite boulders on the home
island. None of these were checked in pixels.

## Integrator hooks (`docs/orchestration/reports/claude-mmo-w2-data-hooks.patch`, `git apply` clean on d92f183b)

1. `build_placer.gd _spawn`: `&"forge"` and `&"anvil"` → `CraftStation.make(...)`. W2-BUILDSYS also needs
   `forge`/`anvil` rows in structures.json `placed_kinds`.
2. `save_restore.gd`: add `&"forge", &"anvil"` to the CraftStation restore case.
3. `t_build.gd`: 24 → 26 kits.
4. `craft_ui.gd STATIONS`: add `["forge", "Forge", "ingot"], ["anvil", "Anvil", "hammer"]`.
5. `data/ui_icons.json`: `station_forge` uses station_fire.svg and `station_anvil` uses
   station_grindstone.svg until W1-UIICONS draws its own icons.
6. `crafting.gd progression_block`: enforce `requires_node` with `_node_unlocked(player, node)`, which looks
   up the node's tree in SkillState.defs and calls `is_unlocked`.
7. `harvest_node.gd OPTION_TOOLS`: pine_log, snow_pine, willow_wood and acacia_wood need an axe.
   acacia_wood was already bare-handed before this package.
8. `item_def.gd` (W2-INV): `market_category`, `rarity` and `insulation` fields parsed from items.json.

Not in the patch:
- ItemArt should read `ItemDef.rarity` instead of item_rarity.json (ICONS2/W2-SCREENS). Then item_rarity.json
  can be deleted.
- A repair action that consumes `recipes.json repairs` belongs to W2-PROCESS or W2-CRAFT.
- Insulation should feed climate fatigue (W2-SURVIVAL/W2-WEATHER).
- Forge and anvil models belong to W1-STRUCTART/DSC-CAMP; they currently use the CraftStation fallback box.
  Register them in asset-replacement.md.

## Files outside the Owns list (flag for review)

- `game/data/nature_manifest.json`. The spec gives this package "Tin ore family", which can only be a
  nature family. Changes:
  - TinOreNode family (reuses the silver-ore model).
  - Dead yields fixed: `spine` → `cactus_spine`; `ore_chunk` removed from Rock.
  - Real sources added: `ore` on GraniteBoulder; pine_log, snow_pine, willow_wood, leech, lava, root,
    mushroom and spice_herb as 0–1 extra yields on their natural families.

  None of the packages that own this file are running.
- `game/data/world/rules.json` `warp_ruin.loot`: the dead ids wire, medicine and rare_seed became
  metal_shard, pressure_dressing and corn_seed. The acceptance item requires rules references to exist.

## Assumptions (# ASSUMPTION, all tunable data)

- Tin is found on temperate and tundra islands with a flint pick.
- Rung gates use these skill nodes: flint `work_pick`, obsidian `combat_knife`, copper `copper_tools`,
  bronze `blade_shapes`, iron and steel `iron_weapons`.
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
  Instead, t_data checks that every item a piece tier or placed kind spends is reachable; all 8 are, on
  the BUILDSYS branch's file.
- trees.json was not edited, because W2-SKILLS is re-keying it. If W2-SKILLS renames node ids, the
  `requires_node` values must follow; t_data fails loudly if any of them goes missing.
- Not touched by this package: gather-03 (latent attribute stamping is code), climate-01 (weather) and the
  Durango trait/alloy effects from prompt 04 (W2-PROCESS/W2-CRAFT).
- Labs to register: none new. t_data runs like the other t_*.gd.

## Gate status at the clean stop (merged branch d92f183b, hooks not applied)

Seen `rc=0`: run_all, t_ai, t_canim, t_combat, t_data, t_harbour, t_iconart, t_items, t_light, t_lighting,
t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_web, plus the
craft_lab and equip_mount_lab labs.

Seen `rc=1`: t_build and t_uiicons. Both are the expected forge/anvil hook gap; both PASS with the hooks
patch applied (see the table above).

The smoke run on the merged tree was killed at the stop. The last line seen was `SMOKE PASS`, on the
pre-merge tree just before commit 87394e99 (first gate run, before the base merge).

## What is left (exact next steps)

1. The integrator runs `git apply docs/orchestration/reports/claude-mmo-w2-data-hooks.patch`, then
   reruns t_build, t_uiicons, t_ui, t_data and run_all. All passed when I applied the patch locally.
2. Rerun `tools/smoke.sh --no-import` on the merged tree.
3. Independent review of the data. Review the two files outside the Owns list first: nature_manifest.json
   and rules.json warp_ruin loot.
4. Follow-ups listed under "Not in the patch" and "Not done / open".
