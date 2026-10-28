# FOODCAT: the owner's Durango food catalog mapped onto our foods

Branch `claude/mmo-foodcat` (from `claude/mmo-overhaul` 7f95b89c). Owner request: "Also add food effects,
we will want to work on food and cooking systems too". Source: `docs/reference/durango-food-catalog-level60.csv`
(254 rows from a fan guide, level-60 figures, committed with this work). It is research data from the
Durango:0 reconstruction. Every number taken from it is tagged `restoration-evaluated` and marked
`# ASSUMPTION` in its foods.json note, with the catalog row it came from. None of it is presented as an
original 2019 constant.

No balance tuning beyond the mapping. No second food or status system: everything goes through
FOODFX's bundle (`FoodEffects.evaluate` -> `EatSession._apply_bundle`).

## Level scaling (how L60 becomes our L1 base)

`ItemDef.food_energy_at(level) = food_energy x (1 + stats_per_level.food_energy x level)`, and cooked foods
already use a factor of 0.01. Every mapped food now carries that factor, which makes level 60 = x1.6. So:

- item `food_energy` (L1 base) = (catalog instant + catalog digestion) / 1.6, so a level-60 instance restores exactly the catalog total;
- `energy.instant_release_ratio` = catalog instant / catalog total, so the split at any level keeps the catalog's shape.

`t_foodcat` checks both for every mapped row: a level-60 raw meat restores 163.3, split 40.8 now and 122.5 digested.

Only Energy has a level rule in this build. Fullness, Health, Fatigue, buff stats and status levels are
applied **flat** at the catalog's L60 value. I did not invent a level rule for them (see owner questions).

## Mapping table (our id -> catalog Game ID)

| our id | catalog Game ID (name) | L60 instant + digested | food_energy L1 old -> new | ratio | fullness | catalog buff / other |
|---|---|---|---|---|---|---|
| `tea` | `tea_01_green` (Green Tea) | 22.4 + 22.4 | 44 -> 28 | 0.5 | 5 | Enhanced Ability Lv60 (not mapped, see questions) |
| `drip_coffee` | `coffee_drip` | 47.9 + 8.4 | 56 -> 35.19 | 0.851 | 5 | Caffeinated (existing) |
| `dutch_coffee` | `coffee_dutch` | 47.9 + 8.4 | 56 -> 35.19 | 0.851 | 5 | Max Fatigue +132.8 (existing), Caffeinated |
| `berry`, `berries` | `wildberry` (Raspberry) | 29.7 + 19.8 | 6 / 8 -> 30.94 | 0.6 | 10 | - |
| `grilled_meat` | `skewer_meat_mart` (Meat) | 98.0 + 65.3 | 24 (kept, see below) | 0.6 | 12 | - |
| `skewer`, `spiced_skewer` | `meat_skewers` (Meat Kebab) | 98.0 + 65.3 | 22 / 24 -> 102.06 | 0.6 | 12 | - |
| `herb_buff_meal` | `skewer_meat_mart` (Meat), weak match | 98.0 + 65.3 | 22 -> 102.06 | 0.6 | 12 | - (keeps its legacy `defense` food_buffs row) |
| `camp_stew` | `stew_01` (Stew) | 138.2 + 59.2 | 32 (kept, see below) | 0.7 | 7 | Perception +20.9, Hot Food Lv2 |
| `raw_meat`, `meatball_mix` | `meat` (Meat) | 40.8 + 122.5 | 12 / 10 -> 102.06 | 0.25 | 20 | Stomach Pain Lv1 |
| `fish` | `fish` (Minnow) | 38.0 + 88.7 | 10 -> 79.19 | 0.3 | 10 | Stomach Pain Lv1 |
| `raptor_meat` | `meat_lizard` (Lizard Carcass) | 73.5 + 89.8 | 16 -> 102.06 | 0.45 | 20 | Stomach Pain Lv1 |
| `coconut` | `coconut` | 40.4 + 26.9 | 12 -> 42.06 | 0.6 | 10 | - |
| `mango` | `fruit_tropical` (Tropical Fruit) | 40.4 + 26.9 | 10 -> 42.06 | 0.6 | 10 | - |
| `cactus_flesh` | `cactus` (Cactus Pulp) | 18.9 + 18.9 | 6 -> 23.63 | 0.5 | 15 | - |
| `mushroom` | `mushroom` | 14.4 + 14.4 | 8 -> 18 | 0.5 | 30 | Poisoned Lv4 |
| `corn` | `corn_infertility` (Corn) | 44.5 + 44.5 | 8 -> 55.63 | 0.5 | 10 | - |
| `meatball` | `meatball_01` (Meat Dumpling) | 71.5 + 132.9 | 18 -> 127.75 | 0.35 | 10 | Strength +20.9 |
| `sashimi` | `sashimi` | 119.1 + 79.4 | 14 -> 124.06 | 0.6 | 15 | - |
| `boiled_meat` | `boiled_meat` | 119.5 + 64.3 | 20 -> 114.88 | 0.65 | 10 | Strength +20.9, Hot Food Lv1 |
| `roast` | `sirloin_steak` | 62.3 + 26.7 | 28 -> 55.63 | 0.7 | 50 | Strength +30, Defense +4.6 (15 min, spec 32 s6), Hot Food Lv3 |
| `seasoned_roast` | `tenderloin_steak` | 62.3 + 26.7 | 30 -> 55.63 | 0.7 | 50 | Strength +30, Attack +6.6, Hot Food Lv3 (keeps legacy `gather_speed`) |
| `crafters_meal` | `fruit_sandwich_weapon` | 110.8 + 27.7 | 30 -> 86.56 | 0.8 | 10 | catalog +33 Weapon Crafting **not** applied: keeps spec 32 s3's +20 (t_foodfx fixture) |
| `carnivore_feed` | `feed_carni_02` | 169.7 + 18.8 | 15 -> 117.81 | 0.9 | 30 | Fatigue +130 (Strange Eats Lv1 not mapped) |
| `herbivore_feed` | `feed_herb_02` | 169.7 + 18.8 | 12 -> 117.81 | 0.9 | 30 | Fatigue +130 (Strange Eats Lv1 not mapped) |
| `fatigue_tonic` | `fatigue_drug` (Fatigue Restorative) | 0 + 0 | 0 -> 0 | - | 5 | Fatigue -300 (was -200), Water Lv1 -> thirst 20 |
| `fruit_juice` (new) | `juice_fruit` | 96.9 + 41.6 | 86.56 | 0.7 | 7 | Charisma +20.9, Quenches thirst |
| `cactus_juice` (new) | `juice_cactus` | 89.9 + 38.6 | 80.31 | 0.7 | 7 | Quenches thirst (Quenched (Cactus) -> our Quenched) |
| `meat_broth` (new) | `broth_meat` | 38.0 + 9.5 | 29.69 | 0.8 | 5 | Water Lv1 |
| `salad` (new) | `salad_01` | 123.7 + 53.0 | 110.44 | 0.7 | 10 | Dexterity +20.9 |
| `herbal_tea` (new) | `medicine_tea_01` (Herbal Tea) | 5.0 + 5.0 | 6.25 | 0.5 | 30 | Health +50.4 |
| `shaved_ice` (new) | `shaved_ice` | 29.7 + 19.8 | 30.94 | 0.6 | 10 | Cold Food (Lv60 read as level 1) |

**Two Energy exceptions: grilled_meat and camp_stew keep their old Energy (24 and 32).** With the catalog's
163.3, grilled meat out-relieves dried and smoked meat. That breaks t_process's processing payoff (spec 08 s2:
a slow station's output must ease more fatigue than the grill). run_all also pins camp_stew's food_energy at
32. Both asserts stay as they are. Every other field of these two rows is mapped, and each row's
`catalog.energy_kept` says why. t_foodcat asserts the reason is documented and that only these two are exempt.
The catalog implies the opposite ranking, because its preserved meats (Bacon 79, Pressed Ham 198) are not
worth more Energy than grilled Meat (163). Owner question 9.

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
| Fatigue -N / +N | `fatigue` field (current fatigue, not the cap) | `_test_fatigue`: tonic pays -300 and floors fatigue; carnivore feed's +130 raises it |
| Health +N | `health` field | `_test_health`: herbal tea heals exactly 50.4 |
| Fullness | `fullness` field (carried; Full status is the gate) | `_test_fullness`: roast pays 50 and leaves Full |
| Energy at level | item `food_energy` + level rule | `_test_level_scaling`: L60 raw meat = 40.8 + 122.5 |

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

## Assumptions (all also in data notes)

- L1 base = L60 total / 1.6 (the existing x(1 + 0.01 x level) rule). Buffs, Health, Fatigue, Fullness and status levels are flat at L60.
- "Quenches thirst" and "Water Lv1" have no number in the catalog. I set thirst 20 (tea's existing value), and any value above 0 clears Thirsty and grants Quenched.
- "Lv60" on Cold Food, Caffeinated, Enhanced Ability and Quenched (Cactus) is the evaluation level, not a status level. Shaved Ice applies Cold Food Lv1.
- Stomach Pain and Poisoned keep the item def's existing raw-roll chance. The catalog gives a level, not a probability.
- `poisoned`: 0.2 HP/s per level for 5 min, copied from Stomachache. `vigor`: no effect, 10 min.
- Buff durations: 20 min, or 15 min for the roast (spec 32 s6's Sirloin Steak). The catalog gives none.
- Weak matches: herb_buff_meal and grilled_meat -> the mart "Meat"; raptor_meat -> Lizard Carcass; roast -> Sirloin Steak; seasoned_roast -> Tenderloin Steak; crafters_meal -> the weapon-flavor sandwich (keeping spec 32's +20).

## Open questions for the owner

1. **Energy scale.** Catalog Energy is in the hundreds (raw meat 163 at L60). Our stamina bar is 100 with 16/s regen. At L1, mapped foods now restore about 30-128 (raw meat went from 12 to 102). Instant Energy clamps at the bar, and digestion keeps paying after that. Does the bar move toward Durango's scale, or should food Energy be scaled down? Pet feeding is affected too: `Food.feed_pet` fills hunger by Energy x 10, so carnivore feed now fills about 1178.
2. **Fatigue scale.** Catalog fatigue numbers (Restorative -300, feed +130) are on Durango's scale. Ours is 0-100, so one tonic empties it and one bite of pet feed adds a lot.
3. **Stats we lack.** Strength, Dexterity, Agility, Endurance, Will, Intelligence, Perception and Charisma have no player stat, and neither do Attack, Accuracy, Lethality or Defense from food. Food buffs carry and show them, but they move no number. Should the attribute system be built, or should these map onto something that exists (for example Defense onto the legacy `defense` food buff)?
4. **Level rule for non-Energy effects.** Should buffs, Health and Fatigue scale with item level like Energy does, or stay flat?
5. **Catalog effects with no meaning here:** Enhanced Ability Lv60 (Green/Black Tea), Strange Eats Lv1 (feeds), Juice Lv1, Life Recovery Speed / Health Recovery Speed buffs, Continuous Energy Recovery, Jasmine Aroma, Surging Sweetness, Quenching Drink, the Prevention/Antiserum medicines, and the percentage heals (Hardtack "60% of max Energy"). None is wired. Which matter for the first cooking slice?
6. **Vigor** has a status but no effect. What should it do?
7. **crafters_meal.** Should it take the catalog's +33 Weapon Crafting (fruit_sandwich_weapon), or keep spec 32's +20? The t_foodfx fixture pins +20.
8. **dried_meat and smoked_meat.** Should they get a catalog row (Bacon for smoked) at the cost of the legacy processing relief?
9. **Processing payoff vs the catalog.** Keep the spec 08 rule that dried/smoked meat beats grilled meat (then grilled_meat and camp_stew stay at 24 and 32, as now), or take the catalog's Energy and re-tune the drying/smoking relief rows in processing.json?

## Gate results (headless, via gslot)

- import: rc 0, no errors in the log
- `[t_foodcat] PASS` (new)
- `[t_foodfx] PASS`
- `[t_data] PASS items=246 recipes=171`
- `[t_items] PASS`
- `[t_uiicons] PASS ids=193 files=125 glyphs=47 code_ids=48 hook_ids=45 ...`
- `[t_save] PASS`. Its 5 SCRIPT ERROR lines are the deliberate ones (base has the same).
- `[t_inventory] PASS`, `[t_process] PASS`, `[t_needs] PASS`
- `bash tools/smoke.sh --no-import`: `SMOKE PASS`
- `run_all.gd`: `[tests] PASS`. The 3 TouchControls compile-order SCRIPT ERRORs are known on base.
- `cd tools/docs_wiki && python3 -m unittest`: 49 tests, 44 OK. `test_gen_game_data`, `test_sheet_api` and `test_recipes_page` all print `OK`. All 5 errors are in `test_phase_map` and already fail on base 7f95b89c. Their message is `Feature source is not a file in this checkout: docs/agent-context.md`, and that file is not in the tree at base.
- `sync_game_data.py` dry run after everything: `dry run clean`.

During the run, the first full pass failed in two places. t_process ("dried meat eases more fatigue than grilled", 20.7 vs 52.2) and run_all ("stew is cooked food", which pins food_energy == 32) both failed with grilled_meat and camp_stew on catalog Energy. I resolved it by keeping those two Energies (see above) and left the asserts untouched.

## What the next agent needs

- Food numbers are tuned in `game/data_sheets/foods.csv` (effects) and `items.csv` (`food_energy`). Then run `python3 tools/docs_wiki/sync_game_data.py --apply` and then `gen_game_data.py`. Sheets are written with CRLF, so edit them with a csv writer that keeps that, or run gen `--force-sheets` once the sync is clean.
- Whoever wires attributes or combat stats: food buffs already carry `strength`, `perception`, `attack`, `defense`, ... in BuffSlots rows. Add the key to `foods.json` `stat_keys._player_map` once a consumer exists.
- Art: six new food icons (see the table) borrow existing pictures through aliases.
