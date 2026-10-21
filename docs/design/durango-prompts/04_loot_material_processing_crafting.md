# Claude implementation prompt: Durango-inspired Loot, Material Properties, Processing and Crafting

Build a resource-driven item economy, **not generic random-color weapon drops**. The source of equipment power should be the level, individual properties, processing history and recipe roles of gathered ingredients.

## Instance-based loot
Create an individually identified instance for each harvested bone, hide, pelt, ore, log, fiber, etc., with material definition, level, dinosaur/resource source, rolled positive/negative/rare attributes, processing opportunities/history, condition/durability, and unique instance ID. Species/resource-node tables determine possible parts and default/rolled traits. Illustrative reconstructed examples: Tarbosaurus leg bone Firm 8 / Low Density 3; Tarbosaurus pelt Fluffy 6 / Lightweight 4; Brachiosaurus leather Tough Fiber 6 / Low Density 2; Ankylosaurus leather Tough Fiber 4 / Heavy 3; Mammoth pelt Oily 8. Do not treat these as fixed guaranteed rolls without verification.

## Three attribute classes
- **Gray negative:** Soft (attack penalty), Heavy (accuracy/evasion penalty), Low Density (durability penalty), Weak Structure (lethality penalty), Soft Fiber (defense penalty).
- **Yellow positive:** Firm (attack), Lightweight (weapon accuracy or clothing evasion), Compact Structure (lethality), High Density (durability), Pointy (penetration), Sharp Section (wound damage), Full (stun), Tough Fiber (defense), High Elasticity (gathering ability), Fluffy (cold protection), Thin (heat protection), Good Breathability (humidity resistance), Oily (wind resistance), Beautiful Pattern (Charisma).
- **Green rare material traits:** Black Sheen, Low Vibration, Wide Serration, Narrow Hook, Split Easily, Vivid Inspiration. Convert only through **compatible primary slots and final equipment type**.

## Rare equipment effects (documented-reference examples)
- Vital Strike: crit applies bleeding, 6 damage/second for 10 seconds.
- Sadism: crit triggers 6 HP/second healing for 10 seconds.
- Throw Dirt: chance to reduce target accuracy 40% for 8 seconds.
- Pain Averse: increased roll/parry effective timing window.
- Gathering Mania: chance for 3 Energy/second over 10 seconds during gathering.
- Extra Extra: chance at extra gathering yield.
- Meticulous Gatherer: +5 percentage points flawless gathering.
- Secrets of Gathering: higher odds for some valuable resource attributes.
- Shorter Duration: 5% reduction for applicable workstation tasks.
- More Space: +1 workstation delegation slot.

Historically associated conversions include Black Sheen → Vital Strike or Throw Dirt, Low Vibration → Sadism or Pain Averse, Narrow Hook/Wide Serration → gathering effects, Split Easily → workstation effects. Exact proc rates, combinations, and some game-version values remain configurable.

## Material processing
Processing changes **one selected exact material** using skills, tools, stations and consumables. Reduce a limited processing-remaining counter. Show preview, trade-offs and processing history. Reference transformations: Compression High Density +2; Surface processing Lightweight +2; Precision processing Compact Structure +2; Debris processing Firm +2 and Low Density +1; desulfurize metal High Density +2; alum tan Lightweight +2; oil tan Tough-related +2 with possible Low Density downside. Metals/alloys with configurable recipes: bronze High Density +5, brass Compact Structure +3, leaded bronze Full +2/Firm +4, steel Firm +1/Compact Structure +2, wrought iron Firm +2/Sharp +2. Treat exact alloy effects as historical-reference configurations.

## Ingredient slots and output-level calculations
A recipe declares primary vs secondary material slots. All eligible input levels can contribute to finished item level, but only qualifying **primary materials** inherit attributes. Initial **simplified reconstructed** level rule: `final_level = min(floor(weighted_average(input_levels)), crafting_category_level, recipe_max_level)` respecting recipe minimum and explicit exceptions. Example 40/50/60 at level-60 crafter yields level 50 under equally weighted inputs.

For several identical primary units, ordinary attributes may be averaged including missing properties as 0, rounded down: five pieces with Firm [4,4,4,0,0] yield Firm 2; Full [0,0,0,4,4] yields Full 1. Rare attributes may pass from a single eligible primary material subject to compatibility and restrictions. Prevent valuable traits in a secondary material from magically transferring. Item preview must use the **same deterministic calculations** as actual crafting.

## Crafting skill vs crafting ability
Category level gates recipes and resulting item level. Separate **Crafting Ability** combines base attributes, tools, specialization/passives, food and equipment and determines success chance. Historical proficiency reference: Weapon Crafting upgrades at category levels 20/25/30/35/40 each could add +4 Crafting Ability. Illustrative preserved curve: `shortfall=max(0, required_ability-actual_ability); success=clamp(1-(shortfall/100)^2,0,1)`; 0 shortfall=100%, 50=75%, 80=36%, 100=0%. Apply recipe-specific failure material losses.

Separate **Flawless** from ordinary success, with configurable chance and bonus (stat improvement, occasionally item level where rules allow). Reference rare crafting-luck effect +6 percentage points. Respect level caps unless an explicit override is configured. Require appropriate workstations/tools/levels (e.g., drying racks, level-gated knives and workbenches); a high-level tool does not itself raise finished item level.

## UI, economy and test
Allow players to inspect individual attributes and select **specific item instances** for primary and secondary slots. Preview level, inherited buffs/penalties, rare conversions, probability, tool/station requirements, and processing limits. Preserve instances through inventory, storage, trade and market. Test harvest Tarbosaurus → inspect individual bone → process Firm → select that bone as hammer primary → calculate level and inherited attack → craft → equip and verify damage. Include atomic consumption, save/load, no duplicate XP, no double-processing, and rare-effect tests.

## Implementation standards
Inspect the existing project and its architecture first. Reuse existing gameplay, inventory, persistence, UI, and network components rather than introducing parallel systems. Implement working code in the project's language and engine, not just pseudocode. Separate definitions/configuration from saved runtime state. Make balancing parameters configurable. Preserve unique instance IDs and enforce atomic ownership/currency transitions. Where multiplayer exists, validate gameplay authoritatively and make retried operations idempotent. Include tests and summarize modified files, verified behavior, assumptions, and remaining limitations.

**Historical fidelity:** Durango: Wild Lands was updated during 2019; published guides can describe different revisions. Distinguish verified original mechanics from contemporary player reports, community reconstruction formulas, and new design choices. Do not claim illustrative values are exact original Nexon server values.
