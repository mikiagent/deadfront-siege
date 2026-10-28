# FOODCAT: the owner's Durango food catalog mapped onto our foods

Branch `claude/mmo-foodcat` (from `claude/mmo-overhaul` 7f95b89c, later merged up to 7d537d51). Owner request: "Also add food effects,
we will want to work on food and cooking systems too". Source: `docs/reference/durango-food-catalog-level60.csv`
(254 rows from a fan guide, level-60 figures, committed with this work). It is research data from the
Durango:0 reconstruction. Every number taken from it is tagged `restoration-evaluated` and marked
`# ASSUMPTION` in its foods.json note, with the catalog row it came from. None of it is presented as an
original 2019 constant.

No balance tuning beyond the mapping. No second food or status system: everything goes through
FOODFX's bundle (`FoodEffects.evaluate` -> `EatSession._apply_bundle`).

## Normalisation and level scaling (orchestrator decision, 2026-10-28)

The catalog sets **relative** values only. Its magnitudes are not imported. There is one factor per bar,
stored in `foods.json` → `catalog_scale` (and marked `# ASSUMPTION` there):

| factor | value | how it was derived |
|---|---|---|
| `energy_k` | **0.110791** | raw_meat's pre-FOODCAT L1 `food_energy` 12 ÷ (catalog Brisket total 173.3 ÷ 1.6) |
| `fatigue_k` | **0.666667** | our largest existing restorative (`fatigue_tonic` −200 at 7f95b89c) ÷ the largest mapped catalog \|Fatigue\| (Fatigue Restorative −300). The catalog states no fatigue scale of its own. |
| `health_k` | **0.099206** | our only existing food heal (`camp_stew` +5) ÷ the largest mapped catalog Health (Herbal Tea +50.4). The catalog states no health scale of its own. |

Level rule: `ItemDef.food_energy_at(level) = food_energy x (1 + 0.01 x level)`, which makes level 60 = x1.6. So:

- item `food_energy` (L1 base) = catalog L60 total ÷ 1.6 × `energy_k`. A level-60 instance restores the catalog total × `energy_k`.
- `energy.instant_release_ratio` = catalog instant ÷ catalog total, so the catalog's split shape is kept at every level.
- Fatigue ±N and Health +N = catalog figure × `fatigue_k` / `health_k`.
- Buffs, Health, Fatigue, Fullness and status levels stay flat (no level rule). This is an orchestrator default and `# ASSUMPTION`.

`t_foodcat` checks all of this on every mapped row:

- level-60 Energy = catalog total × `energy_k`;
- a level-1 raw meat stays within 10 % of the old 12;
- each feed's pet fill is within ±20 % of its base value.

No food newly empties or fills a bar. The tonic's −200 equals its own base value (it already emptied the
bar), the feeds' +86.67 is halved by Vitals and does not fill it, and herbal tea heals +5.

**Before → after L1 Energy (`food_energy`), sample of 5:**

| food | 7f95b89c | first FOODCAT pass (raw catalog) | now (normalised) |
|---|---|---|---|
| raw_meat | 12 | 102.06 | 11.31 |
| grilled_meat | 24 | 24 (kept) | 11.31 |
| tea | 44 | 28 | 3.10 |
| meatball | 18 | 127.75 | 14.15 |
| berry | 6 | 30.94 | 3.43 |

**Pet feed fill** (`Food.feed_pet`: energy_restore × 10, level 1):

| feed | 7f95b89c | now | change |
|---|---|---|---|
| carnivore_feed | 15 × 10 = 150 | 13.053 × 1.01 × 10 = 131.8 | −12.1 % |
| herbivore_feed | 12 × 10 = 120 | 131.8 | +9.8 % |

Both are within ±20 %.


## Mapping table (our id -> catalog Game ID)

| our id | catalog Game ID (name) | L60 instant + digested | food_energy L1 old -> new | ratio | fullness | catalog buff / other |
|---|---|---|---|---|---|---|
| `tea` | `tea_01_green` (Green Tea) | 22.4 + 22.4 | 44 -> 3.10 | 0.5 | 5 | Enhanced Ability Lv60 (catalog block only) |
| `drip_coffee` | `coffee_drip` | 47.9 + 8.4 | 56 -> 3.90 | 0.851 | 5 | Caffeinated (existing) |
| `dutch_coffee` | `coffee_dutch` | 47.9 + 8.4 | 56 -> 3.90 | 0.851 | 5 | Max Fatigue +132.8 (existing spec-32 row), Caffeinated |
| `berry`, `berries` | `wildberry` (Raspberry) | 29.7 + 19.8 | 6 / 8 -> 3.43 | 0.6 | 10 | - |
| `grilled_meat` | `skewer_meat_mart` (Meat) | 98.0 + 65.3 | 24 -> 11.31 | 0.6 | 12 | - |
| `skewer`, `spiced_skewer` | `meat_skewers` (Meat Kebab) | 98.0 + 65.3 | 22 / 24 -> 11.31 | 0.6 | 12 | - |
| `herb_buff_meal` | `skewer_meat_mart` (Meat), weak match | 98.0 + 65.3 | 22 -> 11.31 | 0.6 | 12 | - (keeps its legacy `defense` food_buffs row) |
| `camp_stew` | `stew_01` (Stew) | 138.2 + 59.2 | 32 (kept, see below) | 0.7 | 7 | Perception +20.9, Hot Food Lv2 |
| `raw_meat`, `meatball_mix` | `meat` (Meat) | 40.8 + 122.5 | 12 / 10 -> 11.31 | 0.25 | 20 | Stomach Pain Lv1 |
| `fish` | `fish` (Minnow) | 38.0 + 88.7 | 10 -> 8.77 | 0.3 | 10 | Stomach Pain Lv1 |
| `raptor_meat` | `meat_lizard` (Lizard Carcass) | 73.5 + 89.8 | 16 -> 11.31 | 0.45 | 20 | Stomach Pain Lv1 |
| `coconut` | `coconut` | 40.4 + 26.9 | 12 -> 4.66 | 0.6 | 10 | - |
| `mango` | `fruit_tropical` (Tropical Fruit) | 40.4 + 26.9 | 10 -> 4.66 | 0.6 | 10 | - |
| `cactus_flesh` | `cactus` (Cactus Pulp) | 18.9 + 18.9 | 6 -> 2.62 | 0.5 | 15 | - |
| `mushroom` | `mushroom` | 14.4 + 14.4 | 8 -> 1.99 | 0.5 | 30 | Poisoned Lv4 |
| `corn` | `corn_infertility` (Corn) | 44.5 + 44.5 | 8 -> 6.16 | 0.5 | 10 | - |
| `meatball` | `meatball_01` (Meat Dumpling) | 71.5 + 132.9 | 18 -> 14.15 | 0.35 | 10 | Strength +20.9 |
| `sashimi` | `sashimi` | 119.1 + 79.4 | 14 -> 13.75 | 0.6 | 15 | - |
| `boiled_meat` | `boiled_meat` | 119.5 + 64.3 | 20 -> 12.73 | 0.65 | 10 | Strength +20.9, Hot Food Lv1 |
| `roast` | `sirloin_steak` | 62.3 + 26.7 | 28 -> 6.16 | 0.7 | 50 | Strength +30, Defense +4.6 (15 min, spec 32 s6), Hot Food Lv3 |
| `seasoned_roast` | `tenderloin_steak` | 62.3 + 26.7 | 30 -> 6.16 | 0.7 | 50 | Strength +30, Attack +6.6, Hot Food Lv3 (keeps legacy `gather_speed`) |
| `crafters_meal` | `fruit_sandwich_weapon` | 110.8 + 27.7 | 30 -> 9.59 | 0.8 | 10 | catalog +33 Weapon Crafting **not** applied: keeps spec 32 s3's +20 (t_foodfx pins it) |
| `carnivore_feed` | `feed_carni_02` | 169.7 + 18.8 | 15 -> 13.05 | 0.9 | 30 | Fatigue +130 x fatigue_k = +86.67; Strange Eats (catalog block only) |
| `herbivore_feed` | `feed_herb_02` | 169.7 + 18.8 | 12 -> 13.05 | 0.9 | 30 | Fatigue +130 x fatigue_k = +86.67; Strange Eats (catalog block only) |
| `fatigue_tonic` | `fatigue_drug` (Fatigue Restorative) | 0 + 0 | 0 -> 0 | - | 5 | Fatigue -300 x fatigue_k = -200 (unchanged from base), Water Lv1 -> thirst 20 |
| `fruit_juice` (new) | `juice_fruit` | 96.9 + 41.6 | 9.59 | 0.7 | 7 | Charisma +20.9, Quenches thirst |
| `cactus_juice` (new) | `juice_cactus` | 89.9 + 38.6 | 8.90 | 0.7 | 7 | Quenches thirst (Quenched (Cactus) -> our Quenched) |
| `meat_broth` (new) | `broth_meat` | 38.0 + 9.5 | 3.29 | 0.8 | 5 | Water Lv1 |
| `salad` (new) | `salad_01` | 123.7 + 53.0 | 12.24 | 0.7 | 10 | Dexterity +20.9 |
| `herbal_tea` (new) | `medicine_tea_01` (Herbal Tea) | 5.0 + 5.0 | 0.69 | 0.5 | 30 | Health +50.4 x health_k = +5 |
| `shaved_ice` (new) | `shaved_ice` | 29.7 + 19.8 | 3.43 | 0.6 | 10 | Cold Food (Lv60 read as level 1) |

**One Energy exception: camp_stew keeps its old Energy (32).** run_all pins `camp_stew.food_energy == 32`
(the normalised catalog value would be 13.67). The assert stays as it is. Every other field of the row is
mapped, and `catalog.energy_kept` says why. grilled_meat now takes its normalised value (11.31). With it,
t_process's processing payoff (spec 08 s2: dried and smoked meat ease more fatigue than grilled) passes again,
so that earlier exception is gone. t_foodcat asserts that at most one row is exempt and that its reason is
documented.

The rule for fields the catalog does not mention: FOODFX/WATER values stay as they were. That covers taste
scores and flavours, eat seconds, berry's raw-risk chance, camp_stew's Health +5, and tea's thirst 20. The
catalog overrides only the fields it states. Each row's `foods.json` entry carries a `catalog` block (game id,
L60 figures, buff, other) and a `FOODCAT # ASSUMPTION` note.

### Unmapped, our side

- `dried_meat`, `smoked_meat`: these must stay unbundled. `t_foodfx` asserts that processed station output keeps the legacy Energy break and Dry relief. The catalog also has no jerky (Bacon would fit smoked meat, if the owner wants that).
- `burnt_food`: this is our own bad food and has no catalog row.
- `steamed_food`: the recipe takes any food, and the only steamed row in the catalog is Cooked Rice, which is not a match.
- `spring_water`: the catalog has no plain water row. The FOODFX design stays.
- `ice`: not edible in this build (category `water`, no Energy). The catalog's Ice is a Cold Food. Ice gained an `ice` category so Shaved Ice can name it in a slot.
- `bandage`, `pressure_dressing`, `splint`, `antivenom`, `antibiotic`: these are treatments, not consumables on the eat path.

### Unmapped, catalog side

The other 220 rows are left out on purpose. Events (`*_event*`, halloween, valentine, cherryblossom
2019, anniversary), store and medicine items (`hp_medicine*`, `fatigue_drug_store*`, `immune_*`,
`medicine_*` except Herbal Tea), and every dish whose ingredients this build does not have (grains,
flour, dough, bread, pizza, noodles, rice, cheese, butter, cream, sauces, eggs, sugar, honey, milk,
persimmon, apple, grape, tomato, potato, onion, pumpkin, taro, beans, flowers and roots, shrimp, clams,
crab, eel, salmon, tropical fish, the meat cuts brisket/sirloin/belly/tenderloin as raw items, steaks as
their own items, sausages, sushi, cakes, wine, beer, mojito, coffee beans and grounds, and so on). It stays
a data slice, as asked.

## Effect types and the test for each (all in `game/tests/t_foodcat.gd`)

Every effect test eats a real instance through `Player.begin_eat_slot` -> `EatSession` -> `FoodEffects`.

| catalog effect | how it runs through FOODFX's bundle | t_foodcat test |
|---|---|---|
| Stat buffs (Strength, Dexterity, Perception, Charisma, Attack, Defense) | `buffs` row in the `enhanced_ability` group, spec 32's stat keys (already in `stat_keys`) | `_test_stat_buff`: meatball fills Enhanced Ability with Strength +20.9; roast carries Strength + Defense |
| Stomach Pain LvN | raw-food roll; `risk_level` -> `stomachache` stacks | `_test_stomach_pain`: a bad raw meat -> Stomach Pain Lv1 |
| Poisoned LvN | new survivor status `poisoned` (0.2 HP/s per level, copies Stomachache, ASSUMPTION); `risk_status: poisoned`, `risk_level: 4` on mushroom | `_test_poisoned`: a bad mushroom -> Poisoned x4, no Stomach Pain, health drops on a tick |
| Hot Food LvN | `temperature: hot` + `temperature_level` -> `hot_food` stacks (max 4); the higher level wins and levels never add up | `_test_hot_food`: roast -> Lv3; a Lv1 boiled meat afterwards leaves Lv3 |
| Cold Food | `temperature: cold` (+ level) -> `cold_food` | `_test_cold_food`: shaved ice -> Cold Food |
| Vigor LvN | new status `vigor` (no effect: the catalog names none), bundle `statuses` row with `level` | `_test_vigor_and_thirst_status`: probe bundle -> Vigor x2 |
| Thirst LvN | bundle status `thirsty` | same test: probe -> Thirsty |
| Quenches thirst / Water LvN | `thirst` > 0 (20, tea's existing value): clears Thirsty, grants Quenched (WATER) | `_test_quench`: fruit juice and meat broth clear Thirsty, juice grants Quenched |
| Fatigue -N / +N | `fatigue` field (current fatigue, not the cap), catalog x `fatigue_k` | `_test_fatigue`: the tonic pays -300 x k = -200 and floors fatigue; carnivore feed's +130 x k raises fatigue without filling the bar |
| Health +N | `health` field, catalog x `health_k` | `_test_health`: herbal tea heals exactly 50.4 x k = 5 |
| Fullness | `fullness` field (carried; Full status is the gate) | `_test_fullness`: roast pays 50 and leaves Full |
| Energy at level | item `food_energy` (x `energy_k`) + level rule | `_test_level_scaling`: L60 raw meat = (40.8 + 122.5) x k with the catalog's split; L1 raw meat within 10 % of 12; feed fill within ±20 % of base |

The mapping invariants in `_test_mapping` run for every entry with a `catalog` block (34 of them):

- the row exists in the CSV;
- `food_energy_at(60)` equals the catalog total;
- the instant ratio and fullness are the catalog's;
- the provenance is `restoration-evaluated`, and the note names the row;
- every status, risk status and buff stat the entry names exists;
- the temperature level fits the status's max stacks;
- each of the 6 new foods has an item, a bundle, an icon and a recipe.

### Code changes (small, inside FOODFX)

- `food_effects.gd`: bundle `statuses` rows carry `level`; the bundle carries `temperature_level`; `raw_risk` carries `status` and `level`; new `risk_status(entry)`.
- `food.gd`: `raw_risk_roll` returns the bundle's risk status (default `stomachache`); `apply_raw_risks` applies it at its level.
- `eat_session.gd`: `_apply_status(..., level)` sets stacks to max(previous level, new level), capped by the status. Temperature and bundle statuses pass their level. No vitals or sleep files were touched.
- `statuses.json`: `hot_food` max_stacks 1 -> 4; new `vigor` and `poisoned`. `ui_icons.json`: `poisoned` -> venom.svg, `vigor` -> caffeinated.svg (shared SVGs, like `quenched` -> drink.svg).

## New items (6) and recipes (6)

All six use ingredients that already exist, at existing stations. Spec 08 asks for juices, broths and salads; spec 32 s9 asks for hot/cold food and medicine.

| item | recipe (sheet) | station | icon (borrowed, art later) |
|---|---|---|---|
| `fruit_juice` | fruit=1; water=1 | mortar | `berries` |
| `cactus_juice` | cactus=1; water=1 (`cactus_flesh` gained category `cactus`) | mortar | `cactus_flesh` |
| `meat_broth` | raw_meat=1; water=1 | bonfire | `boiled_meat` |
| `salad` | fruit=1; herb=1 | workbench | `herb_leaf` |
| `herbal_tea` | herb=1; water=1 | bonfire | `herb_leaf` |
| `shaved_ice` | ice=1 (`ice` gained category `ice`) | mortar | `ice` |

For art later, these six need their own icons: they borrow through `icons_manifest.json` aliases. All have
process_add 0, so the catalog Energy is not multiplied by a processing step. ASSUMPTION: the stations,
seconds and slot choices (spec 08 names juices and broths without giving recipes).

## Sheet changes (owner sheets stay authoritative)

- `items.csv` gained a `food_energy` column, so the owner can tune Energy in the wiki.
- `foods.csv` gained `health`, `fatigue`, `temperature`, `temperature_level`, `risk_status` and `risk_level`.
- The generator (`gen_game_data.py`) and the sync (`sync_game_data.py`) both know the new columns. The items-traits notes now also print the health/fatigue/temperature level/raw-bite status and each food's catalog row.
- All values went in through the sheets: a script edited the CSVs, `sync_game_data.py --apply` wrote the JSON, and `gen_game_data.py` regenerated `docs/current/items-traits.md` and `recipes.md`. A sync dry run is clean afterwards.
- The JSON-only fields the sheets cannot hold were edited directly: `stats_per_level`, the `item_rarity.json` mirror, icon aliases, and each food's `catalog` block and note.
- Three sync bugs turned up on the first new item rows, and I fixed them:
  - a new item row was created without its `id`;
  - a new recipe whose output is a new item in the same pass was refused, because recipes sync before items;
  - a new recipe row had no primary slot, so t_data's "exactly one primary" failed. The first slot is now the primary.
- The items `attributes` column now writes `default_attributes`, the field the sheet reads. Before, an edit to that column would have landed in an unused key.
- `foods.json` is now in the sync's `indent=2` layout, so its diff is large; the content changes are the mapping.

## Assumptions (all also in data notes, `# ASSUMPTION`)

| # | assumption | where |
|---|---|---|
| A1 | Catalog magnitudes are not imported. `energy_k` = 12 / (173.3 / 1.6) = 0.110791 (raw meat stays near today's 12; the catalog sets relative values only) | `foods.json` `catalog_scale`, items `food_energy` |
| A2 | `fatigue_k` = 200 / 300 = 0.666667 (largest mapped catalog Fatigue -> our tonic's base -200). The catalog states no fatigue scale | `catalog_scale`, foods.csv `fatigue` |
| A3 | `health_k` = 5 / 50.4 = 0.099206 (largest mapped catalog Health -> our only food heal, camp_stew +5). The catalog states no health scale | `catalog_scale`, foods.csv `health` |
| A4 | Buffs, Health, Fatigue, Fullness and status levels are flat (no level rule). Only Energy scales with level (orchestrator default) | foods.json notes |
| A5 | Strength, Dexterity, Agility, Endurance, Will, Intelligence, Perception, Charisma, Attack, Defense: carried Enhanced Ability buff rows with no consumer. No stats added (orchestrator default) | foods.json buffs |
| A6 | Effects with no meaning yet (Strange Eats, Juice, recovery-speed buffs, continuous recovery, prevention medicine, % heals, Enhanced Ability Lv60, Quenched (Cactus) beyond Quenched) are stored in each row's `catalog.other` and not applied (orchestrator default) | foods.json `catalog` |
| A7 | Vigor: a status with no effect, 10 min (orchestrator default) | statuses.json |
| A8 | Crafter's Meal keeps spec 32's +20 Weapon Crafting, not the catalog's +33 (t_foodfx pins it; orchestrator default) | foods.json |
| A9 | dried_meat and smoked_meat are left as they were, with no catalog rows and their processing relief kept (orchestrator default) | - |
| A10 | camp_stew keeps Energy 32 (run_all pin); the normalised value would be 13.67 | `catalog.energy_kept` |
| A11 | "Quenches thirst" / "Water Lv1" -> thirst 20 (tea's existing value); any value above 0 clears Thirsty and grants Quenched | foods.csv `thirst` |
| A12 | "Lv60" on Cold Food, Caffeinated, Enhanced Ability and Quenched (Cactus) is the evaluation level, so Shaved Ice applies Cold Food Lv1 | statuses.json note |
| A13 | Stomach Pain and Poisoned keep the item def's raw-roll chance (the catalog gives a level, not a probability). `poisoned` is 0.2 HP/s per level for 5 min, copied from Stomachache | foods.json, statuses.json |
| A14 | Buff durations are 20 min, or 15 min for the roast (spec 32 s6's Sirloin Steak); the catalog gives none | foods.csv `buffs` |
| A15 | Weak matches: herb_buff_meal and grilled_meat -> the mart "Meat"; raptor_meat -> Lizard Carcass; roast -> Sirloin Steak; seasoned_roast -> Tenderloin Steak; crafters_meal -> the weapon-flavour sandwich | foods.json notes |
| A16 | New-food recipes: stations, seconds and slots (spec 08 names juices, broths and salads but gives no recipes) | recipes.csv |

## Open questions for the owner

None of the earlier questions stay open. The orchestrator decided them as defaults A1-A9 above, and the owner
can tune every one of them in the sheets (`items.csv` `food_energy`, `foods.csv` `fatigue`, `health` and
`buffs`, plus the `catalog_scale` block).

## Gate results (headless, via gslot, after merging claude/mmo-overhaul 7d537d51 and normalising)

- import: rc 0, 0 errors in the log
- `[t_foodcat] PASS`. It prints `a level-1 raw meat stays near its pre-FOODCAT 12 Energy (11.42)`, `carnivore_feed fills a pet 131.8, within 20% of its pre-FOODCAT 150`, `herbivore_feed fills a pet 131.8, within 20% of its pre-FOODCAT 120`, `it pays the catalog's Fatigue -300 x fatigue_k (-200.0)` and `it heals the catalog's Health +50.4 x health_k (20.0 -> 25.0)`.
- `[t_foodfx] PASS`
- `[t_data] PASS items=246 recipes=171`
- `[t_items] PASS`
- `[t_uiicons] PASS ids=193 files=125 ...`
- `[t_save] PASS`. Its 5 SCRIPT ERROR lines are the deliberate ones.
- `[t_inventory] PASS`, `[t_process] PASS`, `[t_needs] PASS`
  - t_process's payoff line: `grilled e=15.4 rel=5.8 | dried e=23.2 rel=20.7 | smoked e=31.4 rel=17.8 | stew e=43.6 rel=16.4`.
- `bash tools/smoke.sh --no-import`: `SMOKE PASS`
- `run_all.gd`: `[tests] PASS`. It has 6 SCRIPT ERRORs: the 3 known TouchControls compile-order errors, plus economy_tests' deliberate fault-test errors, which arrived with the merge.
- `cd tools/docs_wiki && python3 -m unittest`: `Ran 49 tests ... OK`. The merge brought docs/agent-context.md, which fixed the 5 test_phase_map errors.
- `sync_game_data.py` dry run: `dry run clean`.

Note: a Godot `--script` run exits rc 0 even on a parse error. Read the PASS line, not the rc. One of my intermediate t_foodcat runs had that, and I caught it from the log.

## What the next agent needs

- Food numbers are tuned in `game/data_sheets/foods.csv` (effects) and `items.csv` (`food_energy`). Then run `python3 tools/docs_wiki/sync_game_data.py --apply` and then `gen_game_data.py`. Sheets are written with CRLF, so edit them with a csv writer that keeps that, or run gen `--force-sheets` once the sync is clean.
- Whoever wires attributes or combat stats: food buffs already carry `strength`, `perception`, `attack`, `defense`, ... in BuffSlots rows. Add the key to `foods.json` `stat_keys._player_map` once a consumer exists.
- Art: six new food icons (see the table) borrow existing pictures through aliases.
