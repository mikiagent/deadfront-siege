# Durango: Wild Lands — content inventory and leveling

**Date:** 2026-10-16
**Source:** design data bundled in the Android client `durango-wild-lands-5-2-1plus2001141741.apk` (build 5.2.1, offline end-of-service build). Read from a scratch export, not committed.
**Companions:** [design lessons](./durango-wild-lands-design-lessons.md), [client systems inventory](./durango-wild-lands-client-systems-inventory.md).

This is a catalogue of what existed, by name and count. It lists names, groupings and numbers only. It does not copy descriptions or data tables.

## Animals

**214 animal entries on 27 rig frameworks.** Many entries are recolours, juveniles, biome variants, elite or "paper" event variants, and season variants of one rig. This confirms the systems PRD's "build rigs, not species" rule.

| Rig | Entries | Tameable entries | Species and variants on this rig |
|---|---|---|---|
| Macrauchenia | 30 | 11 | Macrauchenia, Megaloceros (several sex and snow variants) |
| Ornithomimus | 23 | 7 | Coelophysis (juvenile, snow, season 2), Gallimimus, mutant variants |
| Triceratops | 23 | 10 | Protoceratops (incl. pink), Centrosaurus, Styracosaurus, volcanic Chasmosaurus, Bonusaurus |
| Phenacodus | 20 | 12 | Phenacodus (incl. event variants), elephant shrew, rat |
| Raptor | 15 | 8 | Raptor, Deinonychus (incl. savannah), Oviraptor (snow, tropical) |
| Dire wolf | 12 | 2 | Dire wolf (juvenile, snow), mutant variants |
| Ankylosaurus | 11 | 3 | Ankylosaurus (juvenile), mutant variants |
| Parasaurolophus | 10 | 4 | Parasaurolophus, Edmontosaurus, Iguanodon, Saurolophus, volcanic hadrosaur |
| Stegosaurus | 10 | 0 | Stegosaurus, Kentrosaurus (both with juveniles), Tuojiangosaurus |
| Mammoth | 8 | 0 | Mammoth, elephant |
| Sabertooth | 8 | 4 | Smilodon (incl. snow), mutant variants |
| Compsognathus | 8 | 1 | Compsognathus (striped, event), dodo |
| Tyrannosaur | 6 | 1 | T. rex, Tarbosaurus (incl. feathered) |
| Apatosaurus | 4 | 0 | Apatosaurus, Amargasaurus |
| Brachiosaurus | 4 | 0 | Brachiosaurus and juvenile, on two rigs |
| Iguana | 3 | 1 | Rock and volcanic iguanas |
| Dimetrodon | 3 | 0 | Dimetrodon, poisonous lizards |
| Pachycephalosaurus | 2 | 0 | Pachycephalosaurus |
| Allosaurus | 2 | 0 | Allosaurus, warp-accelerator variant |
| Andrewsarchus | 2 | 0 | Andrewsarchus |
| Others | 10 | 0 | Dog, lizard, horseshoe crab, a watermelon event monster, and human male and female rigs used for NPCs |

Animal types are herbivore, carnivore, scavenger, and a training-dummy "sandbag" type.

**74 pet types.** The most varied are Phenacodus, Megaloceros, Smilodon, Skunkodus and Deinotherium. Pets also include rides with no wild entry in this build, such as Gastornis, Euoplocephalus, Utahraptor, Dilophosaurus, Pavomimus, Zebraceratops and a Labrador retriever.

## Plants and resources

**711 natural resource types.** The biggest groups:

| Group | Count | Examples |
|---|---|---|
| Trees | 73 | Acacia, almond, ash, bamboo, banana, baobab, coconut, cypress, date, eucalyptus, ginkgo, maple, persimmon, ice and ember trees, dead logs |
| Grasses and reeds | 48 | Cattail, cotton, flax, lotus, onion, oxalis, heliconia, bird of paradise, bracken |
| Bushes | 35 | Blackberry, raspberry, cranberry, coffee, chilli, pepper, hazel, fig, lavender, lilac, dog rose |
| Cacti | 7 | Saguaro, prickly pear, agave, ocotillo |
| Ores and minerals | about 20 | Copper, iron, black iron, tin, zinc, gold, silver, sulphur, obsidian, marble, basalt, granite, clay |
| Gems | 6 | Amethyst, diamond, emerald, ruby, sapphire, topaz |
| Fishing points | 7 | Lake, river and ocean fishing, shrimp |
| Carcasses and bone piles | 12 | Dead Phenacodus, Brachiosaurus, Triceratops and others, bone piles in three sizes |
| Mud and lava | 6 | Swamp mud, ice mud, lava, dried lava |
| Warped modern debris | about 100 | Gas stations, kiosks, classroom furniture, army crates and tents, hospital beds, vending and office machines, street furniture, cars and trucks |

Many plants have poisonous variants, such as poison coconut, poison bracken and poison mushroom. Some carry story documents as hidden finds. Season 2 and event versions exist for many resources.

**Resources per biome:** tropical forest has the most, about 360 types. Grassland, swamp, temperate forest, river, snowfield, lake, desert and tundra each have 230 to 290. Lava has the fewest, about 90.

## Biomes

Tile biomes: temperate forest, tropical forest, desert, tundra, snowfield, grassland, swamp mud, volcanic, pebble beach, sand beach, cold ocean, warm ocean, river, lake, lava.

Island climates, as displayed to players: grassland, savannah, temperate, tropical, blue tropical, tundra, desert, swamp, snowfield, volcanic, plus Ancora for the tutorial. This matches the PRD's ten climates. Climate is an island label over a mix of tile biomes.

## Islands and maps

**About 260 island templates.** Grouped by role:

| Role | Climates | Levels |
|---|---|---|
| Tutorial sandbox (Ancora) | Ancora | 1 |
| Safehouse | Tropical | 5 |
| Village | Grassland | 6 to 12 |
| Personal island | Grassland | 10 |
| City | Temperate, tropical, grassland, tundra | 40 |
| Unstable | All ten climates | 15 to 60 |
| Outpost | Tropical, temperate, grassland | 30 to 60 |
| Instance | Swamp, tropical | 60 |

Unstable islands make up most templates. They come at fixed level steps per climate. Savannah starts at 15. Tropical spans 18 to 60. Volcanic is level 60 only. Blue tropical is level 55 only.

Thirteen pre-made terrain maps are bundled: five personal grassland islands, and one each for unstable temperate, desert, tropical, savannah, snowfield, tundra, swamp and volcanic islands. All other terrain was generated.

Weather is set per template. The end-of-service build uses storm and snow "ending" weather on many islands.

## Crafting

**About 720 recipes and 556 building blueprints.**

| Recipe category | Recipes | Subcategories |
|---|---|---|
| Clothing | 157 | Novice, settler, explorer and hunter outfits, hats, gloves, shoes, bags, accessories, parts, reforging |
| Cooking | 152 | Fire cooking, baking, water cooking, preserving, oils, fermentation, ingredients, medicine, specialities |
| Weapons and tools | 132 | Axes, blunt weapons, swords, spears, bows, crossbows, each with separate blade or head parts |
| Material processing | 85 | Basic, building, fabric and metal processing |
| Tools | 74 | Hoes, pickaxes, shovels, saws, harpoons, cooking tools, repair kits, instruments |
| Modular building parts | 64 | Floors, walls, roofs, doors, windows, interiors |
| Season 2 and events | about 50 | Clothing, tools, processing, cooking, recipe books |

- **Slots per recipe:** most have 2 or 3. A few have up to 7.
- **Crafting stations:** general table, cooking fire, kiln, tailoring table, weapon table, drying rack, loom, medicine table, kitchen, fertiliser maker, dye table, dye lab, jewellery table, lava kitchen, alcohol ripening, and city versions of several.
- **Hand tools used in crafting:** knife, one-hand axe, bare hands, one-hand and two-hand hammer, needle, mortar, pot, container, cutting board, pan, stone and metal grills.
- **Item level caps** on recipes run from 19 for the crudest items up to 90.
- **Blueprints:** installations and decorations, furniture, workstations, temporary residences, camp pieces, roads and farm tiles, fences and gates, modular houses, clan facilities and labs, boats, hunting traps and warp structures.

## Combat

### The player's move set

About 59 player battle actions, organised by **weapon family**, each with the same skeleton:

| Slot | Role | Shape across families |
|---|---|---|
| Basic attack | A three-step chain, A then B then C | Cheap stamina, low stagger, small experience |
| Skill 1 to 3 or 4 | Learned special moves | Costs several times the basic stamina, about two to three times the damage, much more stagger, and four times the experience |
| Dodge | A roll with a short invulnerable window | Expensive stamina, trains the Defence skill, not the weapon skill |

Weapon families and their specials:

- **One-hand weapons** (sword, axe, blunt): a heavy impact smash, a three-hit flurry, and a piercing stab.
- **Two-hand weapons** (sword, axe, blunt): a wide sweep, a big overhead strike, and a smash with a large area.
- **Spear:** long reach basic attacks, a strike, and a four-hit dash.
- **Bow and crossbow:** a three-shot quickshot and a slow aimed shot. Ranged moves have the longest reach and the least stagger.
- **Bare hands:** free basic punches, kicks, a smash, and a three-hit combination.
- **Tackle:** a shared melee move that does almost no damage but **huge stagger**, several times any other move. It exists to set up knockdowns for capture.

Each move belongs to one variant per weapon type, so axes and blunt weapons reuse the sword animations and numbers with small stamina differences.

### What each hit carries

Every hit lists its timing frame and attack time, a hit radius, a damage multiplier, and a **damage split across impact, pierce and cut**. It also carries armour penetration, stagger added, aggro generated, a taunt value, knockback, and whether it can be blocked.

- **Damage types:** impact, pierce and cut. Animal body parts have a separate defence ratio per type. So a blunt smash and a spear thrust treat the same animal differently.
- **Stagger is its own damage track.** Every move fills the target's stagger meter by a set amount. Filling it moves the animal through the groggy and knockdown sections described in the design lessons note.
- **Glancing hits.** A portion of hits land unclean, for 20 to 30% damage.
- **Critical hits** add 90% damage on top.
- **Stamina** pays for every move. Spending stamina also drains a little energy, which links combat back to food. A dash costs a flat amount of stamina.

### Defence

- **Dodge** gives about a second of evasion and costs a lot of stamina.
- **Auto-guard, auto-dodge and auto-counter** happen without input, based on stats. Being hit and auto-defending both grant Defence experience, so players level Defence by taking fights.
- Players do not take stagger damage at all. Stagger is a tool against animals only.

### Aggro

- Animals start with a base aggro on whoever they notice, and every hit adds aggro scaled by the move.
- When an animal switches targets, the old target keeps a fifth of its aggro.
- **Taunt** is a move property that pulls aggro, and it weakens as the attacker's level exceeds the animal's.
- Pets have their own aggro ratio so tank pets can hold attention.

### How animals fight

- Each animal has attack, accuracy, defence, dodge, evasion and critical as **curves of combat level** scaled by island difficulty, plus an attack cooldown and a damage hurdle that ignores small hits.
- **Directional damage.** Most animals take more from behind and less from the front. Armoured-front animals reverse this and take less from behind. Some take equal damage from every side.
- **Hit location by direction.** Front hits favour the head, rear hits the tail, side hits the legs.
- **Breakable parts.** Body, head, tail, legs and back each own a share of health and their own defence per damage type. Breaking a part applies an injury, such as a leg injury that makes the animal limp.
- **Knockback and blow resistance** limit how far heavy hits push them.
- **Tension** is an aggression gauge re-evaluated every ten seconds, so an animal's mood shifts during a fight.
- Of 214 entries, 139 are herbivores, 69 carnivores, 5 scavengers and 1 training dummy.

### PvP

PvP reused the same moves at heavily reduced damage: melee at 80%, ranged at 35%, and raw damage at 15%. Ranged damage against buildings was cut by 85%. This matches the PRD's point that PvP needed its own ruleset.

### Lessons for Deadfront

- A small move grammar per weapon family, a three-hit basic chain, three specials and a dodge, reskinned per weapon, gives a lot of variety from little animation.
- Separate damage, stagger and aggro values per move let each move have a job: tackle staggers, flurry damages, sweep handles groups.
- Three damage types against per-part defence make weapon choice matter per animal.
- Directional damage plus body-part hits reward positioning without twitch skill, which suits touch controls.

## How leveling worked

Durango had five separate progression tracks.

### 1. Character level

- **Cap 60.** The table holds 80 thresholds, but the configured maximum is 60. The last 20 were never used.
- **Steep curve.** Each level early on needs about 24% more experience than the last. Near the cap it is about 14% more. Level 60 needs roughly 4 million experience in total, and about a quarter of that is the last level band.
- Experience comes from missions, gathering, hunting, crafting, exploring and dailies. A multiplier clamps between a tenth and ten times, so out-levelled content pays little and higher islands pay more.
- Players under level 10 count as newbies.
- Character level gates which islands you can enter, and **no skill can exceed your character level.**

### 2. Skill levels

- About 12 skill categories, each levelled 1 to 60 by practising it.
- Skill experience needed per level is small and rises slowly, from 1 at level 1 to about 90 at level 59. Each action grants only a few points, capped per action.
- **Processing needs half the experience** of other skills. This matches the PRD.
- **Survival levels by itself** and has no research gates.

### 3. Research gates

From skill level 20, every 5 levels needs a timed **research** before the skill can continue:

| At skill level | Research time |
|---|---|
| 20 | 5 minutes |
| 25 | 20 minutes |
| 30 | 1 hour |
| 35 | 2 hours |
| 40 | 4 hours |
| 45 | 12 hours |
| 50 | 1 day |
| 55 | 2 days |
| 59 | 3 days |

Practising the skill during research shortens it, by an amount that grows with skill level. It can cut at most three quarters of the time.

### 4. Skill points

- Players start with 10 skill points and earn more by levelling. The PRD estimates about 900 by level 60 including milestones.
- Points buy nodes in the skill trees. Unlocks such as recipes, blueprints, actions and capture techniques are the valuable nodes.
- Unlearning is free 5 times a day and paid after that.
- A career-guide "advisor" system awards progress points for skill points spent and category levels reached.

### 5. Climate resistance

- A separate level per climate type, up to 60, levelled by spending time in that climate.
- Gains have **diminishing returns:** full rate up to a cap, then half rate to a second cap, then 5% after that. This stops players grinding one climate in a single sitting.
- Resistance reduces that climate's fatigue. Clothing and food add to it.

### How action success scaled with level

Every gather and craft compares the task's **difficulty** with the player's **ability**:

- The **failure chance grows with the square** of how far difficulty exceeds ability. Small gaps barely matter. Large gaps fail often.
- **Material loss** on failure grows linearly with the gap.
- A separate chance to get **hurt** on failure also grows with the gap.
- Great success is its own roll, covered in the design lessons note.

Other level caps: clans 25, pets 60, islands 60.

### What this means for Deadfront

- Separate tracks for character, skills and climate let players feel progress in several ways at once.
- The skill-below-character-level rule stops one skill racing ahead.
- Research timers turned skill progress into a mobile return-later loop. They were also a frequent complaint at 2 and 3 days.
- Squared difficulty gaps give a forgiving near-level experience and a sharp wall beyond it.
