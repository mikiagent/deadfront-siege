# Durango: Wild Lands — Remaining Skill Trees and Missing Mechanics

## Instructions to Claude

Implement the undercovered skills of **Durango: Wild Lands (2019)** in the *existing* survival game. Read the earlier guides first, particularly `03_leveling_progression_skill_trees.md`, `04_loot_material_processing_crafting.md`, `07_combat_and_animal_capture.md`, `08_cooking_food_traits_and_individual_ingredients.md`, `10_construction_building_quality.md`, and `11_processing_skill_material_transformations.md`. **Do not create second copies** of XP, combat, item inventory, recipe, crop, or status-effect systems. Extend their data definitions and call sites.

This is a coverage/completion guide, NOT a replacement for the existing guides. The previously described twelve main categories are Survival, Melee, Ranged, Defense, Butchering, Gathering, Cooking, Weapon/Tool, Tailoring, Construction, Farming, and Processing. The late-game **Surviving Toxic Oil Islands** category brings the original-data count to thirteen. Distinguish this special category from ordinary Survival.

Original technique data preserved in the Durango:0 documentation lists **918 nodes** distributed as follows. Treat these as reference content scope, not a requirement to write all nodes in one pass:

| Category | Nodes | Total SP to learn category |
|---|---:|---:|
| Survival | 45 | 146 |
| Melee | 116 | 420 |
| Ranged | 51 | 186 |
| Defense | 31 | 98 |
| Butchering | 29 | 99 |
| Gathering | 78 | 283 |
| Cooking | 96 | 318 |
| Weapon/Tool | 126 | 455 |
| Tailoring | 98 | 383 |
| Construction | 129 | 436 |
| Farming | 57 | 217 |
| Processing | 44 | 172 |
| Surviving Toxic Oil Islands | 18 | 0 |

Numbers and listed node effects are from extracted original technique records as presented in the reference. The restoration's auto-learn logic, formulas, balancing, and SP economy sometimes differ from Nexon's original service. Do not mislabel reconstructed behavior as verified original behavior.

---

## 1. Gathering — Separate Resource Access, Skill, and Work Difficulty

Gathering was not just 'press harvest for wood.' The original skill category contains **78 nodes**, with resource-family progressions such as leaves, branches, bushes, fruit, logs, insects, minerals, stalks, and specialized plants. Relevant techniques unlock gathering *specific parts* of nodes, not necessarily the entire node.

**Documented examples:** Leaf, Branch, Bush, Fruit I, Log I, Bug I, Pebble, Mud I and Stalk are basic/auto-access lines; Boulder appears early; Long Branch is unlocked around Gathering Lv45 for 5 SP. The material returned from a single tree or bush still has its own level and item traits.

Implement:
- Resource nodes with species, biome, node level, finite parts/charges, respawn rules, and material drop tables.
- Harvestable *parts* with distinct technique IDs: a tree may yield leaf, branch, log, fruit, sap, or specialized material according to its definition.
- Each harvest operation must validate learned gathering technique, category level, required tool type and level, sufficient energy, and available inventory capacity.
- Separate **Plant Gathering Ability**, **Mining Ability**, and other relevant proficiency checks; do not equate category level with ability score.
- Higher skill/tool effectiveness reduces work difficulty/time according to configurable rules; never silently grant rare material traits purely for reaching a high level.
- Preserve rare material properties, Flawless gathering results, mistakes, per-instance processing opportunities, and harvest XP through the shared systems.
- Tool wear, fatigue, inventory slots and dinosaur cargo integrate directly.
- Failed/forbidden resource interactions should say exactly what is missing: technique, saw/pickaxe/shovel, tool tier, ability, or available inventory space.

**Vertical slice:** Gather ordinary berries and leaves, then unlock a later log harvesting technique; harvest two same-name logs with different levels and properties and verify both remain separate inventory items.

## 2. Butchering — Carcass Part Selection, Not Generic Random Loot

The original Butchering category contains **29 nodes**, including seafood, skinning, deboning, and slaughter proficiency. It determines what can be harvested *from an animal carcass*, after combat.

**Documented examples:**
- Bone I Lv1 AUTO: Leg Bone.
- Bone II Lv15, 2 SP: Large Leg Bone.
- Leather I Lv10, 2 SP: Leather.
- Feather Lv20, 3 SP.
- Skull I Lv20, 3 SP, with advanced skull ranks later.
- Teeth I Lv25, 3 SP; Teeth II Lv50, 5 SP: Ivory.
- Horn Lv30, 4 SP.
- Leather II Lv45, 5 SP: Armor-type material.
- Slaughter I–V at Lv20/30/40/50/60, with +4 Slaughter Ability per purchased rank.
- Seafood access includes clams, crab, and shrimp.

Implement:
- Persist a kill-generated carcass with an anatomical set of harvestable parts and per-part remaining uses.
- A corpse has a depletion/decay or despawn rule; harvesting meat must not simply generate endless bones or hides.
- Show inspectable harvesting options: meat, skin, bones, skull, teeth, horns, feathers, shellfish as appropriate for the species.
- Each part is unlocked by specific Butchering nodes, tool requirements and Slaughter Ability, *not* by generic character level alone.
- Harvest creates independent unique instances with level and species-associated traits; keep special drops and negative traits.
- Make butchering success, Flawless outcome, yields, and part damage configurable. Preserve carcass depletion transactionally.
- Do not implement 'Leather II' as ordinary leather doubling without verifying the node's documented target type.

**Vertical slice:** Kill a dinosaur; before Leather I, cannot skin it; unlock Leather I; harvest a hide that retains original level and rare attribute; kill another animal and harvest its bone via Bone I; process and sell these exact instances.

## 3. Farming — Fields, Seed Identity, Cultivation, Growth, and Yield

Farming is a distinct category with **57 nodes** across crop, cultivation, and field/facility lines. Its economic purpose was to produce plants with levels and useful food or crafting attributes rather than generic static food counters.

**Documented examples:** Corn and Apple Tree are early/automatic techniques; Till Small Field is Lv1/1 SP; Till Large Field is Lv25/3 SP. Crop knowledge unlocks cultivation and harvesting of appropriate products.

Implement:
- Field construction and land eligibility, including an actual placed Small Field / Large Field plot and the existing construction placement validation.
- Seed item *instances* that preserve definition, level and traits, plus crop-species planting rules. Do not stack away seed quality distinctions.
- Lifecycle: prepare/till field -> select exact seed -> plant -> grow through timed stages -> maintenance (watering, fertilizer or conditions, where supported) -> harvest -> optional seed recovery -> empty/replant.
- Separate Farming Ability, learned crop technique, field/workstation level, soil/biome environment, and crop level.
- Crop production should create individual harvested fruit/vegetable instances; their level and traits matter to Cooking and the Island Market.
- Handle crop persistence/offline growth, failed or interrupted harvest, empty/occupied plots, and anti-duplication.
- Add fertilizer and irrigation only when supported by project content or explicitly adopted as a new gameplay choice; don't claim unknown formulas are original.

**Vertical slice:** Unlock and build a small field, plant a specific corn seed, save/reload during growth, harvest uniquely attributed corn, and cook with a selected individual cob.

## 4. Tailoring — Clothing, Armor, Specialization, and Environment

The original Tailoring tree has **98 nodes** and includes accessories, fabrics/clothing, work attire, protective outfits, and clothing-related crafting proficiency. It is a large separate profession, not just an extension of Weapon Crafting.

**Documented examples:** Footwraps and Leaf Outfit/Leaf Hat are Lv1 AUTO; Straw Shoes at Lv10/2 SP improve heat resistance; Leather Sandals at Lv25/3 SP provide better heat resistance. Higher-level outfits and specialist gear require learned recipes, correct materials, tools, and proficiency.

Implement:
- Separate Tailoring category progression and learned recipe restrictions.
- Clothing item slots and equipment effects for heat/cold/humidity/wind resistance, defense, evasion, durability, gathering/crafting ability, and Pocket/storage capacity when appropriate.
- Material inheritance: Fluffy -> cold resistance, Thin -> heat resistance, Good Breathability -> humidity, Oily -> wind, Tough Fiber -> defense, Lightweight -> evasion, High Density -> durability, and compatible rare effects.
- Keep recipe primary slots explicit: the traits of leather/fabric used in a major garment panel should not transfer from arbitrary bindings or decorative ingredients.
- Clothes may have different professions: combat clothing vs gathering outfits vs construction gear vs high-capacity inventory clothing.
- Use separate **Clothing Crafting Ability** and **Sewing Ability** if supported in the original data and project stat system. Avoid collapsing every tailoring proficiency into a generic single stat without reason.
- Recalculate effective stats when worn, damaged, repaired, or removed without stacking old bonuses repeatedly.
- Integrate climate/status effects and fatigue, not just a cosmetic model change.

**Vertical slice:** Craft two same-level outfits with different primary fabrics, compare protection and evasion, equip both successively and verify stats and inventory capacity recalculate correctly.

## 5. Weapon/Tool Crafting — Tool Families, Parts, and Manufacture

The original Weapon/Tool category contains **126 nodes**, making it one of the largest trees. Prior crafting guides explain item level and property transfer but did not fully cover all its recipe unlock lines.

**Documented examples:** Stone Blade Lv1 AUTO, makeshift shovel/hoe Lv1 purchased, stone saw Lv10/2 SP, bone saw Lv25/3 SP, metal saw Lv45/5 SP; corresponding tool tiers influence which high-level materials can be gathered. Handle Lv20/3 SP, Improved Handle Lv40/4 SP, Shaft Lv60/6 SP unlock higher-level weapon parts. Stone Mortar Lv20/3 SP, Earthenware Mortar Lv40/4 SP and Metal Mortar Lv60/6 SP unlock progressively demanding culinary implements. Standard Bow appears around Lv20. Instrument making also appears as a skill line.

Implement:
- Weapon families (clubs, knives, axes, hammers, spears, bows and others already in-game), tool families (saw, pickaxe, shovel, hoe, knife), specialty handles/shafts, mortars, and appropriate instruments.
- Differentiate weapon combat tags from crafting tool tags; a hammer can be a weapon and a tool where defined, but requirements remain specific.
- Recipe blueprints require skill node, level, material shapes, workbench, ability, and actual parts; design a consistent item-part taxonomy.
- Weapons inherit combat attributes from suitable primary material slots; tool performance depends on tool capability and durability, not simply icon or nominal level.
- Advanced tools grant access to higher-tier harvest targets and may alter work time or success, using the Gathering/Butchering calculation service.
- Metal and bone blades use the Processing system for treated materials; do not implement a competing local item-trait algorithm.

**Vertical slice:** Craft a stone saw, unlock bone saw, use it to gather a previously inaccessible advanced log, process the exact log, then craft a weapon using an improved handle and processed primary material.

## 6. Ranged — Active Skills, Aim, Weapon Class, and Status Interactions

The original Ranged tree has **51 nodes**. The combat prompt includes ranged mechanics but should not replace this unlock tree.

**Documented examples:** Barrage is acquired at Ranged Lv5/1 SP. Barrage Damage upgrades occur at Lv15, Lv25, Lv35 with +10% damage effect annotations (consult node definitions for full ranks and prerequisites).

Implement:
- Bow/ranged weapon requirements, targeting distances, projectile travel or hitscan according to existing combat architecture, obstacle/line-of-sight validation and resource costs.
- Barrage and other data-driven ranged actions; active skill node unlocks with prerequisite branches and damage upgrades.
- Distinct player attack stance, cooldown and UI states; combat action must never be usable just because its icon is visible.
- Damage/accuracy calculated with equipped weapon, ammunition where supported, armor, player ability and status effects.
- Apply Ranged XP through authoritative combat events rather than repeated animation requests.
- Stun/capture synergy only if a specific ranged action genuinely produces an eligible incapacity effect.

**Vertical slice:** Unlock Barrage and a damage upgrade, attack a moving dinosaur, validate range and hit result, and verify the upgrade changes real damage.

## 7. Defense — Timed Roll, Parry, Auto-Evasion, and Mitigation

The original Defense tree has **31 nodes** and its own progression. The full combat guide covered dodging, but make sure the actual Defense skill tree and numerical modifiers are connected.

**Documented examples:** Roll Lv1 AUTO; Roll Duration I Lv10/2 SP, II Lv20/3 SP, III Lv30/4 SP. Each listed rank grants an Activation Window +5% effect to appropriate action(s). The category also includes defensive bonuses and action branches.

Implement:
- Timed dodge/roll and combat-state windows, not permanent invulnerability while a dodge animation plays.
- Damage mitigation/defense, evasion, health-related bonuses, and parry effects where the matching skill definition calls for them.
- Display visual cooldowns and status, and use server-authoritative hit resolution if multiplayer.
- Distinguish Defense level and purchased abilities from survival attributes and worn armor bonuses.
- Apply the separate Defense XP rules through real defensive gameplay actions, avoiding AFK or spam exploits.

**Vertical slice:** Perform Roll against a dinosaur telegraphed attack, measure valid evasion frames, learn Roll Duration I, and verify a 5% improvement under the defined timing calculation.

## 8. Survival — Exploration, Stealth, Minerals, and Capture

The earlier guides mainly treated Survival as fatigue and animal capture. But original **Survival contains 45 nodes** with broader exploration and access content.

**Documented examples:** Surviving Durango I–VII are category milestones; Stealth I–V are at levels 10/20/30/40/50 and each gives +4 Stealth Ability; Obsidian Lv35/4 SP; Marble Lv40/4 SP; Alum Lv45/5 SP; Mud II Lv10/2 SP; Wild Seed I Lv10/2 SP. Animal handling/capture nodes should use the earlier taming guide.

Implement:
- Real Stealth Ability influencing unprovoked wildlife aggression and awareness, without making the player automatically invisible to combat targets.
- Specialized mineral and unusual plant gathering access; preserve correct category ownership even though the action uses shared gathering infrastructure.
- Link exploration and environment progression to actual resource access and tame/capture eligibility.
- Retain original Survival progression/research exceptions from the global skill guide.
- Do not create a second pet-bonding tree; this is the same Survival category as Animal Taming / Animal Handling.

**Vertical slice:** Without Obsidian unlock, prevent mining obsidian; learn the appropriate node and harvest it; increase Stealth Ability and verify it changes wildlife aggro probability.

## 9. Toxic Oil Island Survival — Late-Game Specialized Category

This is the **13th category** recorded in extracted client skill data, with **18 nodes costing 0 SP** and specialized island progression. It should be a separate optional/late-game expansion, not silently folded into normal Survival.

**Documented unlocks include:** Moss Hut, Wooden Harpoon, Vine Work Outfit, Vine Work Hat, Work Tools, Cooking Bonfire, Insect Gruel, Makeshift Bow, Fog Shelter, Recycled Gloves, Recycled Work Outfit, Recycled Boots and Recycled Gas Mask. The outfit descriptions refer to oil fog and toxicity protection.

Implement only if the project has an appropriate Toxic Oil Island biome or if new-world content is explicitly within scope:
- Toxic exposure and weather/fog sources, protective gear levels, and equipment condition.
- Special island-only resources, cooking, tools, shelter and progression rewards.
- Special XP/progression and zero-SP learned techniques; keep separate from the normal research rules.
- Genuine status effects for oil toxicity and protection, rather than purely cosmetic icons.
- Do not introduce an entire new biome as a dependency blocking the main game; make this a clean optional content pack.

**Vertical slice:** Enter a toxicity zone, experience a real survival penalty, craft/wear Vine Work Outfit and later a gas mask, and measure protection difference.

---

## 10. Global Integration Rules

1. **One progression system:** all categories share character level, category XP/level, SP spending, prerequisites, resets, save/load, and research gating. Some categories have special XP and research rules.
2. **One item system:** all gathered materials, seeds, carcass products and crafted equipment remain individually identifiable, preserving levels, traits, durability, processing history and ownership.
3. **One attribute calculation service:** evaluate bonuses from learned nodes, equipped items, food and status effects without duplication or drift.
4. **One action validator:** before gathering, harvesting, butchering, cooking, crafting or using combat moves, verify the correct category node plus tools, ability, target, resources and capacity.
5. **One transaction system:** items cannot be consumed twice, dropped twice, harvested twice, or regenerated on transfer; same for XP, SP and currency rewards.
6. **One UI vocabulary:** add missing categories to the existing hexagonal skill-tree interface. Display lock reason, category level, prerequisites, SP cost, ability changes and recipe unlocks.
7. **Data-driven original skill records:** ideally import a vetted table of original 918 nodes (category, line, stage, required level, SP, effects), then bind each effect to functional game systems. Do not mark a node implemented if it has no real behavior.
8. **Prioritize incremental, tested content:** implement one end-to-end vertical slice per category and then expand recipes/nodes. Keep unknown values configurable.
9. **Preserve original-versus-modern distinction:** extracted client node names and effect descriptions are better-grounded than reconstructed server formulas; identify modified defaults explicitly.
10. **Multiplayer:** all item creation, harvest depletion, combat hits, skill spending, crop harvesting, crafting results and trading must be authoritative.

## 11. Priority Order for Claude

**First:** Gathering + Butchering, because they create the majority of crafting ingredients.

**Second:** Farming + Tailoring, because crop identities connect to Cooking and garment bonuses connect to climate, inventory and survival.

**Third:** Weapon/Tool crafting recipe branches and specialty tools, because they complete the harvesting and processing loop.

**Fourth:** Ranged + Defense skill-tree depth, using the existing Combat service.

**Fifth:** Remaining Survival exploration nodes and the optional Toxic Oil Island category.

For each: inspect existing project, list gaps, add real data+effects, write tests, and report which unlocks are fully functional, partial, or merely defined. Do not implement a decorative but inert 918-node UI.

## 12. Acceptance Tests

- A tree has distinct harvestable parts with different unlock requirements.
- Dinosaur carcass yields meat, bones and hide only when part-specific techniques allow it.
- Two corn seeds remain unique and grow into independently attributed harvests.
- Clothing made from different fabric properties applies different climate/defense bonuses.
- Crafted saw level and learned recipe affect gathering eligibility.
- Barrage is locked until learned; its upgraded node changes real damage.
- Roll Duration upgrade changes actual valid timing rather than just tooltip text.
- Stealth reduces wildlife aggro using the real AI detection service.
- Every new category earns the correct XP and obeys the global level cap.
- Skill resets remove permissions and modifiers without destroying previously crafted items.
- Item transfers, offline crop growth, and game saves preserve unique attributes.
- No regression in already implemented taming, cooking, processing, building, market, inventory or combat.

## Sources and Historical Confidence

- Original skill tree / all 918 nodes (with labels describing what is confirmed, estimated or changed): https://kghj76138.github.io/durango-homecoming-guide/en/skills.html
- Gathering behavior and technique requirements: https://kghj76138.github.io/durango-homecoming-guide/en/gather.html
- Player stats, abilities and original starting jobs: https://kghj76138.github.io/durango-homecoming-guide/en/stats.html

The source is a community restoration and original-data documentation project. **Extracted skill definitions are not the same as independently verified original server execution rules.** Flag any uncertain effect formulas and match project design when data is missing.

## Final Instruction

**Implement the remaining category mechanics in the existing game, not in a new prototype. Preserve unique individual resources, material traits, specialized roles, real skill unlocks, and cross-category dependence.** Report files edited, nodes added, actual functional integrations, passing tests, and unresolved historical assumptions.
