# Implement Durango: Wild Lands-Inspired Cooking and Individually Attributed Food

## Objective
Implement a full cooking, food processing, recipe, buffs, eating, and food-inventory system inspired by **Durango: Wild Lands (2019)**. Integrate it into the existing project rather than building a second inventory, crafting, or character-stat system. Inspect current code, schemas, crafting, recipes, hunger/energy, equipment, skill tree, persistence, and UI before changing anything. Implement and test a complete vertical slice, not only a design document.

The critical rule is **berries, fruit, vegetables, grain, meat cuts, fish, and other individually generated cooking materials should not automatically stack by shared name**. They have distinct item levels, rolled properties, processing opportunities, and other mutable state. A berry with a valuable trait must remain individually selectable, transferable, and saleable. Visually grouping similar berries is fine, but grouping must never erase their distinct item IDs or reduce physical slot consumption.

## 1. Individual food items: why five berries are five objects

Suppose the player picks five wild berries:

| Berry | Level | Example property | Inventory slots |
|---|---:|---|---:|
| A | 12 | Ordinary | 1 |
| B | 25 | Fresh-like trait | 1 |
| C | 35 | Sweet-like trait | 1 |
| D | 42 | Rare food property | 1 |
| E | 18 | Different condition | 1 |

**These example trait names are illustrations, not confirmed original berry attribute names.** Do not invent them as canon. Five berries occupy five individual spaces. A single `wild_berry x5` stack loses the information needed to select precisely which berry to cook, eat, store, or sell.

Represent food as item instances, using existing project conventions:

```json
{
  "instance_id": "berry_0042",
  "definition_id": "wild_berry",
  "level": 42,
  "attributes": [{"id": "food_trait_from_data", "level": 3}],
  "processing_remaining": 2,
  "processing_history": [],
  "condition": null,
  "container_id": "player_bag"
}
```

The numerical processing count is configurable; modern reconstructions estimate two initial food processing opportunities and this is **not a fully confirmed original server constant**. Do not introduce a freshness/decay timer unless the existing game or verified design requires it; preserve a field only if used.

Preserve per-instance item data when picked up, stored, moved to animal cargo, listed on the player market, processed, crafted, consumed, saved, or reloaded. Prevent auto-selection of a rare ingredient without explicit player selection or a warning.

## 2. Two cooking paths

**In-place cooking (processing):** Transform the chosen food instance in place, keeping its identity and applicable properties. Methods could include grilling/stone-plate BBQ, roasting, boiling, steaming, frying, smoking, drying, seasoning, and other recipes actually present in the game's data. In the Durango:0 restoration, in-place recipes add cooking properties, remove `raw_food` and `wet` tags when applicable, and generally consume a processing opportunity. Verify method-specific behavior rather than making every method identical.

**New-food recipes (combination):** Consume exact selected ingredient instances to create a *new, uniquely identified food item*. Examples include bread, stuffed bread, pizza, salad, sausages, noodles, stews, cakes, juices, sauces, broths, and other valid recipes. Finished food gets a calculated level and properties, not generic static stats copied from a recipe name.

The community Durango:0 cooking reference catalogs 28 in-place cooking methods and 111 new-food recipes, but many behavior details are labeled estimated. Use verified mappings when available; keep all uncertain values tunable.

## 3. Ingredient roles and property inheritance

Each recipe defines slots such as `main`, `topping`, `sauce`, `broth`, `spice`, and `support`, as relevant. Ingredient roles control which properties transfer.

- Only qualifying *main ingredient* slots may transfer existing cooking properties for recipes that explicitly opt into inheritance.
- For qualifying multi-ingredient properties, average property levels according to the specified rounding rule; missing traits should count appropriately rather than copying the best ingredient automatically.
- Support explicit recipes that **do not** inherit earlier cooking properties.
- Toppings, sauces, and broth can add their own recipe-defined bonuses even when they do not inherit main-food attributes.
- Rare material properties may affect cooking only if the recipe defines a compatible conversion; don't indiscriminately transfer every green trait.

A reconstructed reference identifies a limited set of inheriting recipes (including bread, pizza, salad, juice, sauces, sausage, and dough), but those inheritance details are partly estimated. Store them as per-recipe flags and slot rules, not global assumptions.

## 4. Recipe-dependent effects and examples

Durango cooking could create food for survival and specialized jobs. Implement a data-driven effect map with provenances for values:

- Bell pepper topping: weapon-crafting-related ability bonus in compatible dishes.
- Grape topping: sewing ability bonus in compatible dishes.
- Tomato topping: cooking ability bonus in compatible dishes.
- Pumpkin topping: farming ability bonus in compatible dishes.
- Onion-related topping: plant-gathering ability bonus in compatible dishes.
- Bone broth: Endurance-related bonus in documented meal recipes.
- Meat broth: Strength-related bonus.
- Fish broth: Agility-related bonus.
- Vegetable broth: Dexterity-related bonus.
- Fruit-based dishes / fruit wine: attribute buffs depending on recipe and method.

Do not treat eating a raw grape as automatically granting the same bonus as a recipe that uses grape as a topping. Some documented high-level toppings yielded around +4 ability in original community reports; the current restoration estimates +6 at level 60 for some toppings. Clearly label and configure those alternatives.

Food benefits may include immediate Energy, digestion-delayed Energy, fullness/satiety, Health, reduced Fatigue when supported, temporary stat/ability buffs, and environmental effects. Food benefits must be calculated from the actual prepared item's stored state. Buffs should not stack infinitely; define refresh, replacement, strongest-wins or separate-category behavior per effect. Original players reported that repeatedly eating a profession-buff food did not simply accumulate that buff without limit.

## 5. Food levels and Cooking progression

Integrate the existing **Cooking skill category** and shared Skill Point tree. Cooking activity awards character XP and Cooking XP on successful completion without repeated XP exploits.

- Cooking category level and learned recipe nodes gate the available recipes and can cap normal output level.
- Crafting Ability is distinct from category level and affects success probability.
- Recipe stations, tools, ingredient types, minimum and maximum levels, processing eligibility, and permitted ingredient roles are validated before cooking.
- Use the established material-level average/cap system where applicable, with configurable recipe exceptions.
- Flawless or mistake outcomes are resolved through the existing crafting quality pipeline and can modify output quality or bonus levels only according to recipe rules.

Do not bypass the game's already-implemented ingredient, processing, crafting-ability, or stat systems.

## 6. Cooking stations, utensils, and processing

Support appropriate existing or new workstation definitions such as cooking fire, drying rack, mortar, workbench, stone plate, pot, oven, stove, frying pan, and kitchen. Recipes declare required station level, tools, skill nodes, materials, action duration, processing opportunities, and expected properties.

Examples of historically documented recipe requirements include basic meat kebabs using a fire, drying at a drying rack, salads using a workbench/container, stews using a fire and suitable pot, and premium sausage processing with more advanced tools. Treat levels and specific recipes as data, not blanket requirements for every food.

Support a material-preview before committing a food process. An in-place process keeps an identity unless the recipe explicitly creates a new item. A multi-material recipe consumes *specific instance IDs* atomically and generates one output item (or explicit yield count).

## 7. Eating, digestion, survival and buffs

On consumption:
1. Validate the exact prepared-food instance and its owner/location.
2. Apply immediately delivered resource changes.
3. Start any digestion-based delayed resource restoration as persistent, capped effects if applicable.
4. Apply temporary attribute, profession, and other status effects with proper expiry and stacking rules.
5. Consume exactly one food instance; update the authoritative state and inventory.
6. Prevent simultaneous double-consumption.

Raw or improperly prepared food may produce penalties if supported by the survival system; cooked food may reduce those risks. Keep effects and durations configurable and distinguish original/client-documented behavior from restoration estimates.

## 8. UI requirements

**Inventory:** every berry is a selectable object in its own space; show level, rare property indicators, processed state, and an inspection panel. Optional collapsible item-type groups cannot merge instances or capacity.

**Cooking recipe screen:** show categories, recipe details, tools/stations, main ingredient and other slot roles, candidate item instances with visible levels/traits, processing opportunities, expected output level, inherited and discarded traits, success/Flawless chance, and resulting Energy/satiety/buffs.

**Food details screen:** show prepared food level, effects, buff duration, digestion effects, and cooking history where appropriate.

**UX safety:** warn when consuming rare or high-level ingredients for trivial meals. Preserve player choice of the exact berry. Show when an attractive material property will *not* carry over through a recipe.

## 9. Persistence, reliability and testing

Use existing authoritative transactions, item IDs, and save systems. Write tests covering nonstacking berries, identical names with different levels, ingredient selection, source and processed trait persistence, in-place cooking, recipe-based cooking, property inheritance/exclusion, toppings/sauces/broths, station validation, ability gating, output level, success/Flawless results, eating effects, buff refresh and expiry, digestion, save/load, transaction rollback, and preventing duplication or repeated XP.

Minimum end-to-end slice:

**Harvest five berries with individual levels/properties → observe five inventory spaces → reserve one ordinary berry → process it → use it in a recipe → preserve a rare berry unused → eat the finished food → verify the calculated effects → save/reload → confirm surviving berries and traits are unchanged.**

## 10. Historical accuracy

The broad material-driven cooking and nonstacking design is inspired by the original 2019 game. Recipe-property inheritance tables, precise processing counts, duration formulas and many food-effect details have been partially reconstructed or estimated by modern fan projects. **Do not present their estimates as confirmed original 2019 server mechanics**. Use verified data where possible and document uncertain default balance values.

References:
- Original community mastersheet: https://www.scribd.com/document/501357601/Durango-Wildlands-Mastersheet
- Reconstructed cooking details and estimated values: https://kghj76138.github.io/durango-homecoming-guide/en/food.html
- Original community discussion of food-buff stacking: https://www.reddit.com/r/DurangoWildLands/comments/cwxi3l

## Final deliverables

Implement directly in the current game. Report changed files, recipe architecture, item identity and nonstacking rules, food trait conversions, exact ingredient selection, survival/stat effects, UI integration, tests run, and historical values that remain approximations. Do not stop at mockups or pseudocode.
