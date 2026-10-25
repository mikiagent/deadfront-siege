# 07 | Crafting, Cooking, Food Traits, Real-Time Spoilage and Preservation

**Status:** Owner-provided Durango-inspired reference and Deadfront **design proposal** dated 2026-10-25. The desired direction is to add a coherent food-spoilage/preservation loop and retain signed ingredient traits through cooking; **no shelf-life numbers, recipes, loot percentages, storage modifiers or implementation have been locked as live balance**. This specification is intended to give a future coding agent enough behavioral guidance to implement and test it without improvising its core rules.

**North star:** Food is a perishable economic resource that makes hunting, camp preparation, preserved rations, storage buildings, remote expeditions, workers, trade and sustained upbringing meaningful. Fresh food is valuable immediately; specialized processing and buildings convert perishability into logistics and settlement advantage. Rare ingredient traits make dishes distinct without allowing a one-time meal to permanently inflate inherited IVs.

**Durango: Wild Lands inspiration (2019, supplied by owner, not independently verified in this chapter):** perishables progressively lost durability, including in inventory, until vanishing at zero; preservation methods and specialized cold storage slowed decay. The owner's supplied community reference estimates cold-storage reductions around 30–60%+ and example 37%. **Deadfront intentionally differs:** uses a dedicated **Freshness / Spoilage** property (separate from tool durability) and **converts expired food into rotten resources** instead of simply deleting it, unless a later item-specific rule intentionally defines another expiry product.

**Related design:** [05 Material traits and two-input fusion](05-material-level-traits-and-loot.md), [23 processed-component crafting](23-weapons-and-material-crafting-progression.md), [14 Vitals (planned)](README.md), [World and buildings](../design/world-design.md), [Tribe, offspring nutrition and workers](../design/tribe-lineage-domain-and-labor.md), [Economy](../design/economy.md), [Game design decisions](decisions.md). Live sources: [items](../../game/data/items.json), [recipes](../../game/data/recipes.json), [food_buffs](../../game/data/food_buffs.json), [Food](../../game/scripts/items/food.gd), [Crafting](../../game/scripts/items/crafting.gd), [ItemStack](../../game/scripts/items/item_stack.gd), [SaveGame](../../game/scripts/core/save_game.gd).

## 1. Verified current state versus requested system

**Already defined in current game data:**
- Raw `raw_meat`, `fish`, `raptor_meat`; fruits `berries`, `berry`, `mango`, `coconut`, `corn`; `mushroom`, `herb_leaf`, `spice_herb`, `salt`; cooked meals and feed.
- `dry_meat -> dried_meat` at `drying_rack`, `smoke_meat -> smoked_meat` at `smoker`, `camp_stew` at `crock_pot`, roasted/grilled/skewer/meatball/seasoned and herbed foods, and animal feed recipes.
- Four actual food buffs in `food_buffs.json`: **Gather Haste** `gather_speed×1.25 / 300s`, **Sturdy Meal** `defense+8 / 300s`, **Warming Meal** `cold_resist+1 / 600s`, **Cooling Meal** `heat_resist+1 / 600s`. Their current existence is distinct from proposed trait-driven modifications.
- Current `Food.energy_restore` uses item-scaled Energy times `(1 + 0.35×process_count)`; raw food may cause `stomachache`/`tastes_bad`; `Crafting.build_output` copies *primary ingredient* attributes and a poisoned flag, not all signed input trait contributions.
- Current `ItemStack.durability/max_durability` and `wear` model **equipment use**, not elapsed food decay. Food items have no live shelf-life timer. Existing save includes a `saved_unix` time and offline catch-up for fields/snares; no general food aging through inventory, storage and boats.
- `salt` exists as a raw item but there is **no full salt-preservation process/item**, nor a general canning station/item, cold storage system, `rotten_meat` / `rotten_produce` or reliable spoil-to-compost chain. These are **new work**.

**Existing docs only made partial references** to spoiled food, future preservation, storage quality and food traits. This chapter is the first dedicated full lifetime/storage/cooking specification.

## 2. Gameplay contract: freshness independent of equipment durability

**Each perishable food LOT has an explicit, visible `freshness` in 0–100%** with stable timestamps, source lot, material traits and process history. Freshness is a *time-dependent condition*, not a rolled fixed negative trait. `Rancid -`, `Preservable +` and `Fresh +` are potential signed material traits with separate definitions affecting risk or spoilage RATE; do not confuse these with the current mutable freshness percentage.

- Freshness begins at 100% for newly acquired food unless the world source or processing says otherwise. Two perishable lots with different freshness or signed traits must not silently merge into one fresh stack.
- Freshness declines **in real elapsed time** inside bag, quick slot, pet food supply, worksite, storage chest, field cache, boat cargo, and on-ground dropped food, including while the player is offline or on another island.
- Food in the permanently safe home island is still perishable. Safe from attack/raid does **not** mean refrigeration.
- **At 0%**, the old edible stack is atomically **converted** to an appropriate spoiled output (e.g., `rotten_meat`, `rotten_produce`, `spoiled_meal`) preserving item count/provenance only where relevant. The original edible item no longer exists. Rotten output has `inedible` and `spoiled` state and an explicit non-food utility path such as compost or bait. Rotting does **not** generate food, permanent health buffs, pet feed or a fresh raw resource.
- If a particular perishable class should truly be destroyed at zero (e.g., transient potion ingredient), that exception must be explicit in item data, **not** the general food rule. No silently disappearing valuable food.
- Nonperishable gear uses ordinary wear/durability and optional repair. Food is not repaired at a grindstone; thawing/freezing, moving containers or reloads do not recover lost freshness.
- Because food is stackable and current non-durability items can stack up to 999, **per-lot freshness and expiration must be handled carefully**. The preferred implementation is whole-lot freshness represented through `food_state`; only same-definition, same signed traits, same preservation method and sufficiently identical expiry time can auto-stack. Otherwise show separate lots or a clearly defined FIFO sublot aggregate, not an exploitative average that freshens expired food. Preserve locked-item protection when food transitions to rotten output, with a clear alert.

### 2.1 Deterministic rate math, no per-frame ticking necessary

For a perishable lot with base shelf life `L` seconds and stored `freshness` fraction `F∈[0,1]`, as time passes in each environment segment:

```text
effective_decay_rate = environment_rate
                     × storage_container_rate
                     × signed_trait_rate
                     × optional_preservation_state_rate

freshness_next = max(0, freshness_now - (elapsed_seconds / L) × effective_decay_rate)
```

**Do not apply a preservation multiplier twice:** Most drying/smoking/salting/canning value is expressed via the product's **longer base shelf life**, while container/ambient/perk multipliers adjust further. Avoid additionally giving smoked meat a second invisible ×0.25 ambient factor if its 72h lifetime already reflects smoking.

- `elapsed_seconds` derives from persisted UTC Unix timestamps (e.g., current game's `Time.get_unix_time_from_system()`) and the **actual location/ownership storage history**, not by a stopwatch reset whenever storage opens. A bag transfer, split, camp chest move or boat loading must settle accrued decay at the OLD rate, then store the new location/rate and timestamp for the next segment.
- On load, compute catch-up deterministically for bags, storage, worksite inputs, pet/worker inventories, boated cargo and ground items. Avoid huge repeated per-frame scans: lazily settle a lot on inspection/transfer/eat/craft/load, and optionally a bounded background queue for UI alerts. Every action seeing the stack must settle it first.
- A client-side clock change backward does not grant extra freshness: use monotonic nonnegative elapsed relative to last resolved wall-clock time and **a consistent server-authoritative UTC time in future multiplayer**. Single-player local-clock abuse cannot be completely eliminated without external authoritative time; document that limit honestly.
- **Freshness affects quality/risk near expiry only if that gameplay curve is explicitly enabled.** Basic MVP: edible above 0 and transforms to rotten exactly at 0. Proposed later: e.g., below 20% shows `Near Spoilage` and may worsen raw-food risks; ensure signed trait descriptions are exact.
- Food freshness and equipment `durability` must not compete for the same field in saves/repair logic; named `food_state` (freshness and `last_decay_unix`) is recommended.

### 2.2 Shelf-life targets, initial balance proposals only

| Item/category | Base life at standard ambient/no storage | Real current item or NEW | Preservation identity |
|---|---:|---|---|
| Raw dinosaur meat `raw_meat, raptor_meat` | **12h** | EXISTING | Fresh hunted flesh, urgently cook/preserve |
| Raw `fish` | **12h** initially | EXISTING | Same simple early baseline; may be shorter later |
| Cooked / roasted `skewer, grilled_meat, roast, seasoned_roast, boiled_meat, meatball, camp_stew` | **24h** | EXISTING | Better eating than raw, still perishable |
| `smoked_meat` | **72h** | EXISTING recipe/product | Smoker extends logistics window |
| `dried_meat` | **5 days / 120h** | EXISTING recipe/product | Most accessible portable preserved ration |
| `salt_preserved_meat` | **7 days / 168h** | **NEW output + salt recipe** | Salt makes resource gathering valuable |
| `canned_meat` | **30 days / 720h** | **OPTIONAL FUTURE tech**, needs advanced container/seal/station | Not an assumed primitive-era baseline |
| Berries, mushrooms, mangos, herbs, crops | **Species/item-dependent; OPEN** | EXISTING plant items, decay values NEW | Start with readable per-category lifetimes, tuned for farming |
| Prepared `carnivore_feed, herbivore_feed` | **Based on ingredients/preservation, OPEN** | EXISTING feed item | Must not become infinite fresh pet food |
| Rotten outputs `rotten_meat, rotten_produce, spoiled_meal` | No edible freshness; optional compost decay loop | **NEW** | Compost, bait, disposal |

**Why these targets:** taken from the owner's supplied **proposed Deadfront adaptation**, NOT claimed Durango's original item durations. Values are intentionally coarse first-pass balance suggestions and should be adjusted for real worker consumption, expedition duration and travel frequency. Don't treat **30-day canned foods** as mandatory if civilization remains mostly prehistoric/iron-age; clay-sealed fermented or pickled stores could become the technologically plausible late equivalent.

### 2.3 Example storage math

Under **50% reduction in decay rate**, `storage_container_rate=0.50`, so effective shelf life doubles if all else unchanged:

- 12h raw meat → **24h** in that container.
- 72h smoked meat → **144h / 6 days**.
- After 6h in a normal bag, raw meat has 50% freshness; placing that remainder in a 50%-rate cold container provides **12 MORE hours**, not a refreshed 24h from the moment of transfer.

**Reference storage reductions in user-provided Durango anecdote (~30–60%+, including 37% cold earthenware)** are **comparative inspiration only**, not verified shipped balances or guaranteed Deadfront upgrade rates.

## 3. Storage construction, resource economy and movement

Storage must create an actual reason to upgrade a camp and commit processed quality materials to structures.

| Container / station | Proposed intended benefit | Availability / caveat |
|---|---|---|
| **Backpack / ordinary floor / non-food basket** | **1.0x decay rate**, no preservation | Existing bags/baskets; special temperature not simulated now |
| **Lidded food chest / clay pantry** | Slight reduction, protects from rain/pests | Planned new item/structure; no currently implemented rate |
| **Cold earthenware / ice kiln** | Noticeable reduction, uses clay/stone/ice and upkeep | NEW, source of ice/cooling fuel and biome access to be added |
| **Ice box / insulated storehouse** | Larger reduction with maintenance/ice or power-appropriate fuel | NEW, expensive processed materials, not free refrigeration |
| **Drying Rack** | Converts appropriate raw goods into long-life dried items | Existing meat recipe; real expiration and process input checks missing |
| **Smoker** | Converts raw meat/fish into smoked outputs; fuel/time logistics | Existing meat recipe; fuel, real preservation and output freshness missing |
| **Pickling jar / Salt-curing vat** | NEW salt/pickling recipes and long-preserved food | `salt` item already exists; recipe, vessel and station not |
| **Canning / sealed ceramic preservation** | Optional high-end >7-day preservation, if plausible to tech ceiling | `canned_meat` and true canning do NOT currently exist |

**Storage multiplier should come from actual container construction/installed traits** (e.g., **Airtight**, **Insulating**, **Weatherproof** improve cold/pantry effectiveness; **Leaky**, **Moldy**, **Cracked** hurt it). Use **bounded lower rate** and cost/maintenance, not a pile of more than 100% reductions or negative decay. A cheap simple basket must not outperform a purpose-built storehouse by accumulating random positive material traits.

**Item location is authoritative.** Bags on the player, chests at the home base, cargo in transit, goods delivered to remote worksites, worker-consumed food and food left on the ground all age. The protected-home raid rule and safe boat-trip rule remain unchanged; food still spoils in both. If a storage station runs out of required cooling supplies/fuel, settle time segments at the old rate up to exhaustion, then at the new rate afterward. No time traveling to exploit a cooling multiplier.

**Tradeoff:** Protected long-term stores enable preparing for a rare high-tier expedition and feeding a large tribe, but require a supply of hunted food, salt/ice, storage maintenance, work, construction space and transportation. Food preservation is a real sink and reason to assign dedicated cooking/storage workers.

## 4. Cooking and preservation recipes, with real current data mapping

### 4.1 Existing food processes that should gain spoilage behavior

| Existing recipe ID | Uses | Processing result when new system is implemented |
|---|---|---|
| `dry_meat` | Raw meat at Drying Rack | Dried Meat (proposed 5 days); source ingredient's freshness informs resulting quality |
| `smoke_meat` | Raw meat at Smoker | Smoked Meat (proposed 72h); source's signed meat traits and safety rules evaluated |
| `stone_grill`, `roast`, `campfire_skewer`, `cook_meatball` | Heat and meat | Cooked meats (24h proposed baseline), retain appropriate food modifiers |
| `camp_stew` | Raw Meat + Herb + Fruit, Crock Pot | 24h proposed, combined food-buff/energy traits from ALL contributing lots |
| `seasoned_roast` | Meat + Spice | Timed Gather Haste buff plus ingredient modifiers (not permanent stats) |
| `herbed_meal` | Meat + Herb | Timed Sturdy Meal buff plus ingredient modifiers |
| `spiced_skewer` | Meat + Handle + Spice | Cooling Meal existing data alias (`heat_resist`) with relevant ingredient traits |
| `carnivore_feed`, `herbivore_feed` | Meat/water or fruit/stalk | Must expire; pet can't be fed spoiled feed as though fresh |

**Current recipe data note:** `salt` already exists in `items.json`; there is no specific `salt_preserved_meat` output or recipe. Canning would need an additional higher-tech process and container.

### 4.2 NEW suggested recipes / steps (not yet implemented)

| New recipe ID / output | Ingredients and station concept | Proposed life / effects | Missing assets/content |
|---|---|---|---|
| `salt_cure_meat` → `salt_preserved_meat` | `raw_meat ×1 + salt ×1 + cured_hide_binding or jar ×1`, Curing Rack/Vat, Cooking+Processing skill | 7 days, modest reduction of some original cooked buff potential; use reusable container instead of consuming costly jar per serving where possible | NEW output/recipe, curing station/vat, fuel/time rules and item-specific ingredient check |
| `pickle_vegetables` → `pickled_vegetables` | Vegetable + salt + clean water, sealed clay jar | Suggested days-to-weeks shelf life; no raw-meat buffs | NEW vegetable/jar item+recipe, correct crop source and finite jar processing |
| `preserve_rations` → `sealed_rations` | Dried meat + dried fruit + crafted wax seal / clay container | Suggested longer portable field ration, ingredient trait-aware but not infinite Energy | NEW ration/packaging recipes; requires actual material sinks |
| `can_meat` → `canned_meat` | Cooked meat + refined metal vessel, pressure-sealing station | 30 days **only if owner later adopts primitive-compatible canning tech** | NEW canning tech, items, can/sealing fuel/gates; NOT a required progression |
| `render_compost` → `compost` | `rotten_meat` or `rotten_produce` + plant fiber/soil at Compost Bin | Fertility input, NEVER restores edible freshness | NEW rotten outputs, Compost Bin, agriculture effect |
| `prepare_bait` → `bait` | `rotten_meat` + fiber/wrapping at workbench/trap station | Limited bait charges, attracts appropriate predators/fish | NEW bait ID/trap consumption and smell/attraction rules |

**Critical anti-exploit rule:** Processing cannot *resurrect* food from zero freshness. A preserve/cook recipe must refuse `spoiled`/rotten lots, and should use the source's **remaining freshness fraction** to initialize the new longer-life product, not reset near-expired input to 100%. Example: raw meat with 25% freshness cooked to a 24h product gets at most 25% of that new life (6h), unless a documented processing method intentionally models a bounded safety improvement and has explicit requirements. Repeated cook->steam->roast cannot duplicate high Energy, create extra volume of food or refresh life indefinitely. `process_count` now increases current Energy by +35% per processing step and must be separately capped by recipe validity; don't let multiple simple heating actions grant infinite Energy.

**Food-safety contract:** Trait-based `Contaminated` or `Rancid` may require an appropriate safety method and source validity. Proper cooking can reduce some modeled foodborne risks, but no generic seasoning is a universal cure; some severe conditions make items unfit for eating. The game is a simulation, not a real-world cooking safety guide.

## 5. Food material traits: exact perk identities and meaningful outputs

**Trait definitions belong to same general signed material lot registry** as weapons and buildings ([05 Material Traits](05-material-level-traits-and-loot.md)), with food eligibility and recipe transformations. **Dynamic freshness** is NOT a positive/negative rolled perk and should not be conflated with `Fresh+`.

### 5.1 Positive traits (PROPOSED)

| Food material trait | Eligible food input | Direct gameplay payoff | May survive cooking? |
|---|---|---|---|
| **Nutrient-Rich** | meat, berries, fruit, crops | Increased immediate **Energy** recovery | Yes, attenuated by cooking if recipe calls for it |
| **Aromatic** | herb, spice, fruit | Increased compatible timed **food-buff duration** | Yes if herb/spice contributes actual flavor/medicine |
| **Hearty** | meat/roots | Increased energy/satiety efficiency; not max HP | Yes, perhaps reduced by drying |
| **Fresh** | recent high-quality source lots | Lower **spoilage rate** / risk within eligible foods; separate from mutable freshness | Only when transform rule says quality survives |
| **Preservable** | suitable meat, dried foods, low-moisture produce | Lower food decay rate in appropriate preserved output | Yes, subject to rate floors and explicit food category |
| **Pure** | water, herbs, edible plants | Lower modeled contamination/sickness risk | Conditionally, subject to recipe safety |
| **Tender** | fresh meat | Better cooking yield or Energy | Sometimes, not necessarily after dehydration |
| **Warming** | warming herb/spice | Strengthens/delays expiry of **Warming Meal** (`cold_resist`) | Only warming recipe |
| **Cooling** | cooling fruit/herb | Strengthens/delays expiry of **Cooling Meal** (`heat_resist`) | Only cooling recipe |
| **Fortifying** | specific meat/herbs | Improves **Sturdy Meal** (`defense`) magnitude/duration | Yes in valid defense recipe |
| **Invigorating** | berries/herbs | Improves **Gather Haste** (`gather_speed`) duration or immediate Energy | Only Gather Haste recipes |
| **Low-Moisture** | dry crops/fish/meat | Improved yield from legitimate drying/preservation | Consumed into shelf-life result; don't double count |
| **Potent** | medicinal edible herbs | Better actual medicine/hazard-remedy effect | Only on compatible medicine/recipe, not a food HP heal by default |
| **Feed-Grade** | nutrient-dense plant/meat intended for pets | Improved pet hunger recovery, safe long-term nutrition input | Only as species-compatible feed |
| **Airtight** | sealed preserved product/package, not biological raw food | Reduced decay rate while seal is intact | Lost on opening or repackaging without new seal |

### 5.2 Negative traits (PROPOSED)

| Food drawback | Eligible sources | Effect |
|---|---|---|
| **Rancid** | fatty meats/processed meats | Faster decay and/or sickness risk, not a free safe cook |
| **Contaminated** | meat, water, plants | Unsafe without appropriate mitigation; some must be discarded |
| **Sour** | fruit/berries | Lower Energy or minor status; compatible preservation may exploit acidity only if designed |
| **Tough** | meat | Worse grilled output, may be softened by slow stew |
| **Gamey** | wild meat | Poor taste/meal value until seasoning, shorter simple-buff effectiveness |
| **Watery** | fruit/produce | Reduced Energy per unit, poor drying yield |
| **Moldy** | plants, stored food | Higher illness/inedibility risk, not fixed by adding Aromatic |
| **Withered** | vegetables/herbs | Reduced buff magnitude/duration |
| **Stale** | preserved bread/ready food | Lower Energy or food enjoyment; **do not** substitute for freshness percent |
| **Poorly Sealed** | packaged food | Worse storage multiplier, risk of early spoilage |
| **Salty** | over-cured food | Lower comfort/short-lived debuff where relevant, but long life may remain |
| **Undercooked** | prepared meat if craft fails | Raw-food risk persists; must not look like a perfectly cooked meal |
| **Infested** | gathered fruit, crops | Reduced usable yield or invalid food without screening |
| **Weak Aroma** | herbs, spices | Reduced Gather Haste/Warming/Cooling/Sturdy boost |
| **Low Nutrients** | poor soil crops or overprocessed meals | Reduced Energy, particularly animal feed |

**Trait-spoilage interaction:** A `Preservable+` item can alter effective rate, a `Rancid-` can speed it up, and both names survive the signed-trait lot model. Actual `freshness=43%` is still displayed separately. The same raw lot can have `Nutrient-Rich+`, `Rancid-` simultaneously and lose freshness with time. All effects must be data-driven and inspectable, not hidden randomized food losses.

### 5.3 Meal trait absorption, buff caps and preservation trade-offs

Cooking with two or more components must inspect **ALL actual ingredient lot traits**, not only `primary.attributes`. Example:

```text
Raw meat lot: Nutrient-Rich +, Rancid -
Herb lot:     Aromatic +, Pure +
Recipe:       Camp Stew (meat + herb + fruit)
Result:       fixed recipe-buff identity (if any)
              Energy bonus from Nutrient-Rich
              relevant buff duration boost from Aromatic
              sanitation adjustment from Pure, while Rancid remains
              actual freshness based on aged inputs / output shelf-life
```

- Food buffs remain **temporary**, currently named Gather Haste, Sturdy Meal, Warming Meal and Cooling Meal, with visible duration and exact stat effect; food is not direct healing (medicine owns Health).
- One recipe may consume multiple ingredient traits, but the finalized meal's effect is computed with **relevant ingredient weights and caps**, not automatic addition of every buff tag from everything thrown into a pot. Invalid or irrelevant traits can be traceable but do not become fake DPS bonuses.
- **Preservation has tradeoffs**: drying and smoking markedly extend shelf life but may reduce some sensitive ingredient buff potential or alter Energy; salting/pickling offers longer life with resource costs and some changed buffs; canning would be rare/advanced. These tradeoffs are explicit per processing recipe; no arbitrary disappearing perks.
- Proposed *example only* bounds for testing: `food_energy_trait_bonus ∈ [-20%, +20%]`; `food_buff_duration_trait_bonus ∈ [-25%, +25%]`; `food_decay_rate_trait_multiplier ∈ [0.7, 1.5]`; preserving container multiplier `≥0.30` by tested tier. **NOT owner-approved tuning or active game values**.
- For existing `food_buffs.json`, do not allow raw `+50% duration` from every ingredient to chain into permanent uptime; same-stat buff re-eat should refresh/replace to a clear cap, not add 600s repeatedly without limit.
- For storage, a **negative food trait isn't cured by a positive construction material trait**. An Airtight jar slows aging but doesn't remove Contaminated; cleaning/purification is a separate method.

## 6. Rotten material use and anti-resurrection loop

Proposed outputs `rotten_meat`, `rotten_produce`, `spoiled_meal` are **not edible, not safe pet feed**, and cannot be transformed back into `raw_meat` by ordinary cooking. They can be gathered into a finite **Compost Bin** (slow processing + plant matter/water/time) or crafted into bounded-use **bait** with actual fauna/trap support. The distinction preserves survival pressure: rotten output is less valuable, uses storage space and has meaningful disposal labor, but retains utility.

An inventory full of rotten items must never trap the player through an unremovable material. Allow batch disposal with current item lock protections, compost routing or worker orders. Compost yield and bait efficacy are limited and never exceed inputs' nutritional resource-equivalence, to avoid `rotten -> fertilizer -> food` giving net infinite output without soil/time/water.

Potential late food supply loop: butcher fresh animals → cook/preserve near base → distribute timed fresh rations to expeditions and animal pens → leftover/spoiled materials become compost/bait → farms and traps consume those resources → grown food still expires. Workers should prioritize sooner-expiring lots first **(FEFO: first expiry first out)**, reserve nonspoiled input and choose preservation processes before foods turn to waste.

## 7. AI workers, base, boats, markets and survival ecosystem

- **Workers** assigned cooking, feeding or transport must check freshness at task start/completion and after time passes; cannot eat or feed pets `rotten_meat`, cannot reserve a perishable lot and make it immortal, and must release reservations if it expires.
- **Home island** can be safe from raids while having serious food logistics. Upgraded storehouses provide longer supplies for population/offspring growth, and persistent worker cooking jobs are useful. Long-term food quality during youth should affect learned/expressed potential only through the separately designed nutrition/raising rules, never instantly change inherited human/dinosaur IVs.
- **Remote islands, expeditions and boats**: a packaged ration expires during actual travel; boats after departure remain unraidable under the confirmed game rule, but spoilage proceeds. No magical stasis in remote inventory or active cargo.
- **Markets**: include food quality, shelf life remaining, signed traits, processing and rarity in price. Trading a 1%-freshness meat stack as if 100% must be impossible. At auction/listing, freshness continues aging and can convert to rotten output; fair buyer disclosure.
- **Portable preservation**: dried, smoked and salt-preserved goods provide advantages without requiring players to construct refrigerator facilities for every early expedition. Cold storage is a settlement wealth sink and optional logistical advantage, not mandatory survival on first day.
- **UI**: `Freshness 68% • Expires in ~8h`, `Stored in Cold Jar: 50% slower decay`, `Nutrient-Rich +Energy`, `Rancid faster spoilage`. Cooking recipe preview shows resulting shelf life/quality, traits kept/lost, actual eligible ingredients and time. Mark `Expiring Soon` and enable sort/filter/lock/bulk actions, not 50 separate individual micro-management decisions.

## 8. Future Claude implementation breakdown / exact missing assets

**FOOD-01** Add a data-driven `perishability` schema on food definitions, with standard shelf life, spoilage target item ID, category/recipe treatment, and optional storage constraints. Distinguish `max_durability` for equipment; no food-only use of `ItemStack.wear()`.

**FOOD-02** Add persistent per-lot `food_state` (freshness fraction, last accounting Unix time, source lot/provenance/processing context), safely convert old saves to reasonable defaults, and ensure splitting, stacking, inventory changes, dropping, chests, boats, workers and market events preserve expiry. Avoid unbounded per-unit memory.

**FOOD-03** Add an offline-safe, lazy deterministic spoilage service; call on every food interaction and inventory/container tick or load, properly settle time under each historical storage rate before moving. Test zero, negative, huge gaps, manual clock reversal and storage-swap exploits.

**FOOD-04** Implement at 0% **atomic transformation** to `rotten_meat`, `rotten_produce`, `spoiled_meal` (NEW item definitions/icons/categories), not silent disappearance. Ensure stack quantity, slot, lock/reservations and overflow follow actual inventory rules; prevent food/pet/recipe consumption of rotten outputs.

**FOOD-05** Add container `decay_rate_multiplier`/storage role; basic chest/pantry, cold earthenware/ice kiln/ice box and optional equipped/boat cargo, real building recipe, maintenance/fuel availability and trait-specific modifiers (Airtight, Insulating, Cracked/Leaky). Prices/upkeep/protection make storage worth building.

**FOOD-06** Integrate existing `dry_meat`, `smoke_meat`, cooking dishes and food inspector with effective freshness, output base lives, cooking safety, signed trait transformation, spoilage quality carry-through, meal tooltip and meaningful preservation trade-offs; cap the existing `process_count`-related Food Energy multiplier/reprocess routes.

**FOOD-07** Implement **`salt_preserved_meat`** and `salt_cure_meat` with existing `salt`, plus coherent drying/smoker time/fuel/catalysts. Evaluate `pickled_vegetables` + sealed jar after first preservation stage; **`canned_meat` and canning stations OPTIONAL** pending technology cap.

**FOOD-08** Add signed **food ingredient trait mapping** in shared `material_traits.json`: eligible pools, rarity, positives/negatives, cooking transform rules and context-weighted bounded Energy/buff decay changes; make `Crafting.build_output()` inspect every actual consumed food lot, including herb, fruit and meat, preserving negative contamination where appropriate. No primary-only inheritance.

**FOOD-09** Add Compost Bin, composting process and optional bait product with actual farming/trap impact; outputs use finite inputs/time and rotten goods cannot be restored to edible meat by ordinary recipes.

**FOOD-10** Add worker FEFO selection, freshness reservation validation, automated drying/smoking/salting, perishable farm output, market listing revaluation/expiration, and pet feeding/offspring nutrition hooks.

**FOOD-11** Add HUD/inventory/inspector expiry, time-left, environment multiplier, signed traits and warning banners, accessibility and batch/sort/locked-item controls. Display expired-to-rotten notifications without spamming every item.

**FOOD-12** Tests for offline/online/storage transfer, source traits, anti-reset cooking, complete recipe/source path, pet/worker/autonomous feeding, save migration, market/boat/remote expedition, crafted food process loops, compost/bait economy and food expiration in safe home.

### Invariants / test scenarios

1. One raw meat lot has **12h** baseline: after 6h in bag it has **50%** freshness; transferring into a 50% decay container leaves **~12h additional life**, not resets.
2. Raw meat left offline for >12h converts to `rotten_meat`, retaining appropriate count and accessible disposal/compost/bait; no edible output remains.
3. Food in locked inventory slot and boat after departure still ages. A container move can't reset time or spoilage, and cannot increase freshness.
4. A 25% fresh raw ingredient processed into smoked/dried food gains a longer **remaining time**, not 100% full new shelf life; a spoiled ingredient cannot be resurrected by cooking/seasoning.
5. Two ingredient lots with **Nutrient-Rich+** and **Aromatic+** produce one dish with appropriate extra Energy + compatible buff duration while separate **Rancid-** remains if source has it.
6. Food already carrying **Contaminated-** does not become safe merely by adding a Pure herb, and `Moldy-` isn't cured by generic food processing.
7. No food is repairable as a tool, and wear from work/weapon contact doesn't drain freshness; clock time doesn't damage swords by food code.
8. Rotten food is not acceptable by `Food.can_eat`, `Food.feed_pet` or worker auto-use; any compost/bait reuse consumes rotten inputs and time.
9. Food/meal Energy, buffs and trait percentage bonuses stay bounded regardless of cooking process_count, stacking, repeated re-eating, rare fusion or ingredient count.
10. Actual wooden or clay cold store with signed **Airtight+** trait has lower but positive decay rate; the exact rate is visible and a damaged container switches subsequent rate correctly.
11. Saved food at 90% with a stored `last_decay_unix` loads as expected after real offline time even if containers have different temperatures. Old saves without food state load safely without duplicate or permanent freshness.
12. Worker queue/market listings/cargo must not maintain stale food quality or allow trade of food that was already rotten at transaction time.

**No Godot gameplay code, item JSON, recipe entries, stations, or final balance numbers were changed by authoring this design chapter.**
