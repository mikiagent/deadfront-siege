# 32. Durango: Wild Lands — Food, Drink, Consumption Effects, and Buff Implementation

> Filed as spec 32: the number 16 in the source document's title collides with `16_hud_day_night_dial.md`.
> Its internal section numbers (§1-§16) are unchanged.

## Purpose

Implement a Durango: Wild Lands-inspired **food and drink effects system** in the existing survival game. This guide supplements `08_cooking_food_traits_and_individual_ingredients.md`; it focuses on **what consuming a specific food or drink does to the character**, rather than how to craft a recipe. Do not build a second cooking, inventory, or status-effect architecture. Inspect the actual project and extend its shared systems.

**Provenance warning:** The 2019 Nexon original and the modern *Durango:0 Homecoming* reconstruction are not identical. The latter preserves extracted client data but estimates certain calculations, including the digestion period, and changed some food buff strengths in September 2026. All example quantities below should be source/version tagged and configurable; do not assert they are original server constants.

Primary research references:
- https://kghj76138.github.io/durango-homecoming-guide/en/food.html
- https://kghj76138.github.io/durango-homecoming-guide/en/food-list.html

## 1. Distinct consumable effects

Do **not** collapse these into a single Hunger/Thirst value:

| Effect channel | Gameplay meaning / implementation |
|---|---|
| Energy | Restores action energy, either immediately or through digestion |
| Maximum Energy | Temporary modification to Energy ceiling, not current Energy |
| Fullness / satiety | Controls how full the player feels; separate from actual Energy |
| Thirst | Drinks may quench thirst; use existing thirst state if present |
| Health | Immediate positive or negative health change |
| Life | Distinct recoverable-life concept in recovered data; map carefully to existing health architecture |
| Fatigue | Immediate reduction/addition to current fatigue |
| Maximum Fatigue | Temporary increase/decrease to fatigue capacity, **not** the same as reducing current fatigue |
| Primary attributes | Temporary Strength, Dexterity, Agility, Endurance, Will, Intelligence, Perception, Charisma |
| Combat statistics | Attack, Accuracy, Lethality, Defense |
| Production abilities | Profession-specific numeric Ability buffs, *not* permanent skill-category levels |
| Temperature | Hot/Cold Food statuses, context-dependent heat/cold/fatigue effects |
| Debuffs and medicine | Stomach Pain, poison, toxin statuses, antidotes, treatments, immunities |
| Taste | Flavor ratings, possible XP bonus or fatigue-rate penalty |
| Digestion | Delayed Energy payout, cancellable/expiring according to explicit effect rules |
| Consumption time | An eat/drink duration, potentially interruptible |
| Buff grouping | Replacement rules for mutually exclusive food-buff slots |

## 2. Energy: immediate vs. gradual

Model at least:

```
instant_energy = latent_energy * clamp(instant_release_ratio, 0, 1)
digested_energy = latent_energy - instant_energy
```

A 200-Energy food with release ratio 0.4 gives 80 immediately and 120 over time. The Durango:0 model distributes delayed Energy over **300 seconds**; this duration is **reconstruction-estimated**, not proven original server behavior. Modifier tags from cooking can adjust latent Energy and the instant portion. Clamp Energy appropriately and define what happens when maximum Energy changes during digestion. Never deliver the delayed share twice after reload.

Cooking styles such as heating, frying, and stir-frying may change immediate-release ratios. Raw and prepared versions of one ingredient should therefore be able to produce different Energy recovery curves.

## 3. The 27 documented food-buff keys

Implement these as typed status/stat modifiers in the shared character-stat system (only where an underlying gameplay stat exists). The 27 keys are:

**Primary attributes (8):** Strength, Dexterity, Agility, Endurance, Will, Intelligence, Perception, Charisma.

**Survival/combat (6):** Maximum Energy, Maximum Fatigue, Attack, Accuracy, Lethality, Defense.

**Production and gathering (13):** Building Ability, Furniture Crafting Ability, Weapon Crafting Ability, Tailoring Ability, Sewing Ability, Cooking Ability, Farming Ability, Plant Gathering Ability, Mining Ability, Slaughter Ability, Metal Processing Ability, Handicraft Ability, Disassemble Ability.

Abilities must contribute to existing calculated proficiency scores, success checks, or action outcomes. Food granting +20 Weapon Crafting Ability is **not** the same as gaining 20 Weapon Crafting category levels or unlocking skill nodes.

## 4. Food buff channels and exclusivity

The recovered rules distinguish **Enhanced Ability** and **Enhanced Survival** containers. Ordinary attribute/profession meals generally use the first; some survival drinks use the second. They may be active simultaneously. Consuming another food in the same exclusive container replaces the previous buff according to slot rules. A food with only Energy restoration should **not** necessarily erase an unrelated existing buff. Buff duration and replacement semantics must be data-driven and persist through save/load.

Example from restoration's evaluated level-60 data (not guaranteed unmodified 2019 figures):
- Hamburger: Strength +46 and Will +46, presented as an Enhanced Ability buff.
- Dutch Coffee: Maximum Fatigue +132.8 for 20 minutes, presented as Enhanced Survival.

**Critical:** On expiration of a Maximum Fatigue buff, do not blindly subtract the temporary capacity bonus from current fatigue. Recalculate effective maximum, clamp/handle exhaustion explicitly, and never erase persistent base-stat values.

## 5. Drinks, water, coffee, restoratives

Drinks are not simply low-Energy food. Their effects can include thirst, fatigue, special statuses, and survival capacity. Reference examples from the reconstructed catalog (level-60 evaluation where specified; version-sensitive):

| Drink | Example effects |
|---|---|
| Water | Quenches thirst; reconstruction also assigns minor Energy/Fullness effects |
| Tea | 22.4 immediate + 22.4 delayed Energy |
| Drip Coffee | 47.9 immediate + 8.4 delayed Energy, Caffeinated status |
| Dutch Coffee | Same Energy values; Maximum Fatigue +132.8 for 20 minutes |
| Barley Drink (one variant) | Fatigue -30; Attack +2 for 10 minutes; Energy recovery |
| Dunia Warp Mineral Water | Fatigue -200, no Energy recovery |
| Potent Fatigue Restorative | Fatigue -1,000, no Energy recovery |
| Event Mixed Coffee | Energy +80, Health +150, Fatigue -80, thirst quenching |

Some items are event-only, restoratives rather than craftable beverages, or have name variants. Do not make all of them ordinary craftable drinks by default.

**Gameplay distinction:** fatigue-removing tonic changes *current* fatigue; Dutch Coffee changes the *maximum fatigue limit*. They must use different effects.

## 6. Concrete food data examples

Figures below reflect the cited reconstruction's evaluated level-60 examples, **not guaranteed identical 2019 values**, and are useful as data fixtures:

| Food | Immediate Energy | Delayed Energy | Other effects |
|---|---:|---:|---|
| Persimmon | 29.7 | 19.8 | Fullness +10 |
| Bacon | 63.2 | 15.8 | Fullness +25 |
| Raw meat (generic example) | 40.8 | 122.5 | May cause Stomach Pain |
| Meat skewer | 58.2 | 108.1 | Improved taste |
| Stone Plate BBQ meat | 93.1 | 76.2 | Faster immediate recovery |
| Stir-fried meat | 146.6 | 36.7 | High immediate release ratio |
| Vegetable-broth noodles | 163.1 | 54.4 | Dexterity +46, Intelligence +46, 20 min |
| Sirloin Steak | 62.3 | 26.7 | Strength +30, Defense +4.6, 15 min |

The central point: **food level, recipe, inherited ingredient properties, cooking techniques and seasoning combine to calculate the final per-item effects.** The same raw ingredient can lead to different results when prepared differently.

## 7. Taste and flavor fatigue

The reconstruction describes seven flavor dimensions: **sweet, salty, sour, bitter, greasy, umami, astringent**. Taste evaluates a food to a grade; repeatedly eating the same dominant flavor may lower satisfaction until appetite recovers.

| Reconstructed taste grade | Example status |
|---|---|
| Phenomenal Flavor | +5% EXP, 300 sec |
| Delicious | +3% EXP, 300 sec |
| Normal | No extra status |
| Horrible | +20% fatigue gain, 300 sec |
| Disgusting | +30% fatigue gain, 300 sec |

The grade thresholds and taste-fatigue scoring are **reconstructed**. Build taste and flavor preference as optional, configurable logic rather than claiming these exact thresholds reflect Nexon's 2019 server.

## 8. Food processing traits and effect composition

Model a food instance's evaluated effects from:

```
base definition
+ item level
+ inherited ingredient traits allowed by recipe slots
+ cooking/preparation methods
+ seasonings, sauces, toppings
+ recipe output rules
= evaluated food effect bundle
```

A useful generic pattern for a single modified numeric field is:

```
modified = (base + sum(additions) - sum(subtractions)) * product(multipliers)
```

Some tags may override/remove effects entirely; this generic expression is **not** a universal formula. Support per-field transform operations, ordering, exclusivity, caps, and conflict validation. Known example property classes: Heated, Deep Fried, Stir-Fried, Well Cooked (+0.15 instant-release ratio in restoration), Digestibility, Continuous Energy Recovery, Fatigue Buff/Debuff, Status Effect Duration+, attribute amplification, Removes Status Effects.

Each tag must refer to the actual instance and explicitly compatible recipe slots. Do not automatically transfer every berry trait into any dish.

## 9. Temperature, bad food, and medicine

- Hot Food and Cold Food may affect thermal survival and fatigue, with effectiveness dependent on biome, weather, and existing climate systems.
- Some raw food may inflict Stomach Pain, poison, or other adverse effects.
- Food can have direct Health penalties or increased fatigue even if technically edible.
- Medicines and special drinks can remove specified conditions (e.g. plant poison), treat tetanus, counter Toxic Oil statuses, or provide immunization.
- Do not invent universal temperature-resistance percentages where original formulas are unverified.
- Preserve separate rules for drinking water versus medicinal consumables.

## 10. Why berries, meat, fruit and prepared meals should NOT automatically stack

Durango's valuable materials are individuated. These three berries might share one icon but not one state:

- Berry A: Lv. 12, no rare traits.
- Berry B: Lv. 25, different Energy/fullness potential.
- Berry C: Lv. 42, useful food attribute, different processing count.

They must consume **three physical inventory spaces** under the Durango-style default. Every fruit/vegetable/meat cut/meal carries a stable ID, level, attributes, processing state, and calculated consumption effects. Never merge by `definition_id` or name alone. Optional *visual grouping* may show “Wild Berry (3)” but must expand to selectable item instances and continue consuming three slots. Consuming, processing, cooking or selling selects the **exact** instance. Use the existing inventory implementation, not a second food-only stack system.

Sample instance:

```json
{
  "instance_id": "berry_0042",
  "definition_id": "wild_berry",
  "level": 42,
  "attributes": [{"id": "example_food_trait", "level": 3}],
  "processing_remaining": 2,
  "container_id": "player_inventory"
}
```

`example_food_trait` is only a placeholder, not an original material property name.

## 11. Consumption transaction lifecycle

1. Player selects exact consumable instance.
2. Validate ownership, edibility, restrictions, character state, and fullness/consumption constraints.
3. Begin a timed eating/drinking action, if required by that item.
4. Allow interruption on movement or taking damage where configured. A canceled action should not consume the item or grant effects.
5. On completion, atomically consume the specific instance and apply immediate effect bundle.
6. Schedule/instantiate delayed digestion Energy using authoritative time or persisted status progress.
7. Apply buffs to correct exclusive buff group; replace only the relevant prior group.
8. Apply taste and temperature conditions; display UI feedback.
9. Save authoritative effects and transaction state to prevent duplicate consumption after restarts.

Match actual multiplayer/server-authority requirements if applicable. Respect save/load, active-buff durations, capacity changes, disconnects, and double-clicks.

## 12. UI integration

Add a compact food inspection panel showing **item level, exact traits, Energy immediate/over-time, Fullness, thirst, health, fatigue, max-stat effects, ability bonuses, negative effects, buff group, duration, and consumption time**. A tooltip should explain when food *replaces an active buff*. The inventory should continue to show individually selectable items and rare-trait indicators. Crafting previews should project effects from *chosen ingredient IDs*, with unknown/random outcomes labeled as such. Display separate current fatigue and maximum fatigue so drink effects are intelligible.

## 13. Data model and implementation architecture

Prefer shared systems and data-driven registries:

- `FoodDefinition`: valid consumption channels, base values/curves, duration, effects.
- `FoodItemInstance`: reference to item ID, level, inherited tags, prepared state, processing history.
- `FoodEffectEvaluator`: evaluates final per-instance effects, only once in the authoritative transaction.
- `ConsumableAction`: prerequisites, progress, interrupt/cancel/commit.
- `DigestionEffect`: remaining gradual Energy, elapsed/persisted time, update behavior.
- `BuffSlotManager`: Enhanced Ability and Enhanced Survival compatibility, exclusivity, duration, replacement.
- `StatusEffectManager`: beneficial and harmful timed effects, removal, stacking rules.
- `TasteEvaluator`: optional flavor scoring, taste-memory effects.
- `ConsumableUI`: previews, tooltips, buff status, ingredient selection.

Keep a provenance field on reconstructed example values (original extracted, community-described, restoration-evaluated, new design) and make tuning values editable without rewrites.

## 14. Integration with existing Durango-inspired guides

- `01`: Fatigue/current and maximum fatigue, environmental modifiers.
- `03`: Character attributes and profession Ability, not XP/category levels.
- `04` and `11`: Material property transforms, processing count and Flawless effects.
- `05`: Unique item instance inventory, nonstacking storage, safe moves.
- `06`: Exact item listings and preservation of food traits during sale.
- `08`: Cooking recipes, in-place preparation, eligible inheritance slots.
- `12`: Relevant Gathering, Farming, Butchering and Cooking skill-tree hooks.

## 15. Tests and vertical slice

Tests should cover: different-level berries; two same-name foods with different traits; processing a single chosen fruit; immediate vs delayed Energy; interruption without consumption; eating twice quickly; slot replacement vs coexisting slots; maximum fatigue bonus expiration; profession buff impact on real ability checks; harmful raw food; hot/cold conditions; taste statuses; recipe-specific trait inheritance; event-only drinks; preservation in market/storage/dinosaur cargo; save/load during digestion and buffs; no duplicate XP/effects.

**Minimum playable sequence:** Harvest three individually attributed berries → inspect three independent slots → cook using one explicitly selected berry → calculate that prepared item's modified immediate/delayed Energy → eat it → apply immediate Energy and a timed buff → verify digestion and buff expiry → save/reload without duplicates → verify the other two berries are unchanged.

## 16. Claude delivery instructions

1. Inspect the current project's files and systems first.
2. Implement the smallest fully functional end-to-end slice before adding dozens of food definitions.
3. Extend, don't duplicate, existing food/cooking, inventory, stat, fatigue and persistence code.
4. Add data-driven examples for water, tea, coffee, a raw berry, cooked meat, a profession-buff meal, and a fatigue restorative.
5. Show source provenance and configurable values for anything not verified from 2019.
6. Provide modified files, gameplay demonstration steps, tests and known gaps.

**Do not stop with a design document or UI placeholders. Deliver working systems that make food and drink meaningful to combat, exploration, crafting, fatigue and resource management.**
