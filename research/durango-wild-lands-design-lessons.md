# Durango: Wild Lands — design lessons from the client's data tables

**Date:** 2026-10-16
**Source:** the design data files bundled in the Android client `durango-wild-lands-5-2-1plus2001141741.apk` (build 5.2.1, the January 2020 offline end-of-service build), plus its type metadata.
**Companion notes:** [client systems inventory](./durango-wild-lands-client-systems-inventory.md), [asset benchmarks and Tripo prompts](../docs/art/durango-asset-benchmarks-and-tripo-prompts.md).
**Evidence tag:** **[data]** = read from the shipped design tables.

## What this is and is not

The client ships about 145 JSON design tables: recipes, items, animals, ecology, skills, status effects, island templates, constants and more. Most balance rules are stored as small formulas inside the data, evaluated at runtime.

This note records **how the systems are built**: their structure, the shape of each formula, and a few example values that show scale. It does not copy tables, formulas or text into Deadfront. Use it to design our own systems and our own numbers.

The tables were exported to a scratch folder outside the repo and are not committed.

## The biggest lesson: data-driven rules with formula strings

Durango's designers tuned the game without code changes. Animal stats, fatigue rates, craft success, taming odds, death penalties and item modifiers are all expressions in data, with named inputs such as combat level, skill level, region level and an island difficulty factor.

**For Deadfront:** put balance curves in `game/data/*.json` as Godot `Expression` strings with a fixed set of named inputs. Designers can then retune without touching GDScript. Keep the input names few and documented.

## Systems

### Crafting [data]

About 720 recipes. Each recipe has:

- **Slots,** each with an id such as main, connector or handle, a count range, and required **tags** rather than items. Any material carrying a matching tag fits. Each slot also lists suggested sources for the UI.
- **Output chosen by the main slot's material.** The recipe lists several output items with criteria on the main slot's tags. A stone blade, bone blade and metal blade in the same axe recipe give three different items. This is how one recipe covers a whole material ladder.
- **Colour inheritance per channel.** Each of the item's three colour channels takes its colour from a named slot's material. The finished axe is coloured by what it is made of.
- **Costs:** an energy cost, a duration, an effort value, required tools or workbenches, a skill ability with a minimum value, and a maximum output level.
- **Flags** for commission crafting, seasonal limits, and whether the craft uses up one of the item's limited modification counts.

**Great success** is a separate roll. Its chance rises with the player's ability relative to the recipe's requirement, is capped per craft family at between a tenth and a fifth, and follows a hump-shaped curve that peaks for mid-level recipes. The floor and ceiling on the success rate are a tenth and three tenths.

**Lessons:** tag-based slots plus "output picked by main material" is the cheapest way to get a large item list from a small recipe list. Per-channel colour inheritance makes crafted items look made from their materials for free.

### Items and tags [data]

About 2,400 item prototypes and 1,150 tags. Tags fall into material, purpose, property and shape groups, with grades from 0 to 3. Property tags carry **modifiers**: a stat, an operation such as increase, and a formula of the tag's level. For example, a storage property adds bag slots in proportion to its level. Tags can also grant a status effect or mark something as pet food.

**Lesson:** item behaviour comes from tags with levels, not from per-item code. A new item is a new combination of existing tags.

### Animals [data]

About 210 animal entries share a few dozen frameworks, which are rigs with motion sets. Each entry has:

- **Stats as curves of combat level,** multiplied by an island difficulty factor. Health and stagger capacity grow with the **square** of level plus an offset, so high-level animals get much tankier. Attack, accuracy and defence grow **linearly**. Health regenerates at a small fixed fraction of its maximum.
- **A stagger meter with sections** at full, one third and one ninth of capacity. Crossing sections moves the animal toward groggy and knockdown. Knockdown has a fixed duration.
- **Directional damage multipliers.** Hits from behind deal more than hits from the front, with flanks in between. In the example read, behind was 1.2 times and front 0.8 times.
- **Hit location by direction.** From the front most hits land on the head. From behind most land on the tail. From the sides most land on the legs.
- **Breakable body parts,** each with a share of total health, its own defence, and status effects applied to the animal when broken, such as a leg injury that makes it limp.
- **Survival gauges** for stamina, life, stagger and hunger, each with a maximum and a rate. Hunger drains slowly over time.
- An AI profile id, a "tension" profile for aggression, a preferred food tag, a drop table, a scale range, and a tameable flag.

**Lessons:** one formula family per stat, scaled by level and island factor, replaces hand-tuned stat blocks. Direction plus body part gives positioning real meaning without complex AI.

### Taming [data]

- An animal is tameable once its health falls to about **30%**.
- Success odds follow an **S-curve on the level gap** between player and animal, so slightly under-levelled players still have a fair chance and badly under-levelled ones do not.
- Odds also fall with the square of the animal's remaining health ratio, which rewards weakening it further.
- A tame attempt takes a few seconds and has a short cooldown. Taming costs tool durability heavily, about three times a craft.

### Pets [data]

- About 75 pet types, each with ranks, rideable and fightable flags, and by-products.
- **Pet jobs:** timed tasks of about an hour that consume pet hunger and give pet experience or produce items, with random bonus items. Training and production are the two kinds.
- Pets earn a fifth of the player's experience.
- Milestones can fail. A failed milestone pays a consolation reward instead of nothing.

### Fatigue [data]

Fatigue is the session governor, and its rules are the most important to understand.

- **Base rate per activity** grows slightly with the player's survival level and **shrinks as the player out-levels the region**, down to a floor of half. Some activity types run at half rate or zero.
- **Action costs scale with the square root of the action's energy cost** for gathering, crafting, building and repairs. Combat scales linearly and is the most fatiguing.
- **Biome fatigue** is added per climate category, scaled by how far the biome's effect level exceeds the player's resistance.
- **Unstable islands** multiply fatigue by their difficulty factor, with a minimum.
- Twelve **fatigue categories**: the region-level one plus heat, cold, humidity, dryness, sun, wind, gas, snowstorm and volcanic heat. Each names the ability that raises it and the ability that resists it. Their help text tells the player the remedy, such as washing or drinking for heat.
- **Status effects modify fatigue gain** by percentage. Washing gives about a fifth less fatigue gain for six minutes and removes the dirty states.

**Lesson:** fatigue is a soft wall that steers players toward their level band, the right clothing and rest, without a hard lock.

### Durability [data]

- Each action type wears the tool by a set amount: crafting and building about 3, gathering about half that, taming about 10, and each attack or block a tiny fraction.
- Everything also loses one point per day.
- Repairs remove a random 5 to 13% of maximum durability permanently.

**Lesson:** the permanent repair loss is what eventually forces replacement crafting and keeps crafters in business.

### Death [data]

- On death, half the carried items drop by default. The chance an item is protected rises with character level, by about 1.25% per level.
- The drop point stays for five minutes.
- **Repeated deaths stack:** each death in a row restores less of your gauges, from 60% down to 10%, and less of your fatigue.
- Death clears some statuses, such as being washed.

### Ecology and resource placement [data]

About 710 natural resource types, each placed by an ecology simulation rather than by hand.

- Each has ranges for **temperature, humidity and fertility**, minimum and maximum **distance to rivers, lakes, ocean, cliffs and structures**, and a list of biomes it survives in.
- Each carries **biomass**. A resource forms when enough biomass is around and goes extinct below a threshold.
- Resources grow in **stages**.
- Island templates set a simulation interval, a desired population, and a traffic tolerance, which is how much player activity the ecology absorbs before thinning out.

**Lesson:** placement rules on terrain properties give believable distribution for free. Iron ore near volcanic rivers, reeds by water, and so on. The traffic tolerance is a neat way to make heavy harvesting visibly deplete an area and recover later.

### Islands [data]

About 260 island templates. Each has a level, a role such as rural, risky or personal, a displayed climate, biome effects that apply fatigue categories, weather, factions present, entry requirements, a lifespan, and **herd tables** listing spawns by terrain type up to a total count. Template names encode role, level and biome, so a rural level-35 temperate island and a personal level-10 grassland are separate templates.

**Lesson:** generate islands from a template that fixes level, role, climate and spawn tables, then let the ecology simulation fill in resources.

### Status effects [data]

About 370 effect groups. Each effect has a duration, stack size, effects as typed modifiers, a group, statuses it cancels, tags such as "clear on death", and skin, screen and icon effects.

- Most effects do not stack. Only a handful stack, up to 10.
- **Bleeding and poison exist,** including internal bleeding, unstoppable bleeding, tetanus, and poisons from insects, gas, heat, lizards, plants, oil and dung. Items and recipes grant **cures and immunities** for them.
- No animal in the animal table applies them on hit. Their sources look environmental or ingested, which mostly supports systems PRD §6.4, with one nuance: "internal bleeding" and "unstoppable bleeding" are real statuses with dedicated cures.

**Lesson for Deadfront:** our bleed and poison statuses can reuse this structure: typed modifiers, a cancels list, and cure and immunity tags on items.

### Progression [data]

- **80 character levels** on a steep curve. Experience needed grows roughly geometrically, from tens at level 1 to tens of millions at the top.
- Separate **resistance levels** per climate, with their own thresholds and caps on how fast they grow.
- **Skill categories** carry research times and experience tables. Skill rewards unlock recipes, blueprints, actions, modifiers and weapon tags.
- Free skill unlearns: 5 per day, up to 15 in total before paying.

### Building [data]

About 560 building types and 556 blueprints. Buildings carry footprint size, height, rotation options, passable and unoccupiable tiles, interior and exterior, whether they can be packed into a capsule, repair requirements, set bonuses for interiors, and a "mood" for furnished rooms. Blueprints carry slots like recipes, a post-processing time, and how many helpers can speed it up.

**Lesson:** "helpers can speed up construction" is a light co-op hook worth copying.

### Network design [data]

- 985 message types. About 120 are queries starting with "Get".
- Several features have an **Estimate** message that previews an outcome before the player commits, matching the PRD's "preview before consume" rule.
- Workbench crafts report a duration back, so long crafts run while the player does other things.

## What Deadfront should take from this

1. **Formula strings in data** for every balance curve, with a short documented list of inputs.
2. **Tag-based recipe slots** with output chosen by the main material, and per-channel colour inheritance.
3. **Quadratic health and stagger, linear offence,** scaled by an island factor.
4. **Directional damage and body-part hits** with breakable parts that apply injuries.
5. **Fatigue as the level-band governor:** square-root costs for work, linear for combat, biome terms by resistance gap.
6. **Ecology-driven resource placement** from terrain properties and biomass.
7. **Permanent repair loss** to sustain crafting demand.
8. **Stacking death penalties** instead of harsh single-death loss.

## Limits

- This is the end-of-service build. Some values were relaxed for offline play and may differ from live balance.
- A field present in data may be unused by the client.
- Example values above illustrate scale. Deadfront's own numbers should come from our playtests.
