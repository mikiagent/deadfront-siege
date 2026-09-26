# World and island design

**Status:** v1, 2026-09-17. Owner-directed. Machine-readable twin: `game/data/world/` (climates, islands, material rules, spawn tables). Sources: systems PRD §4 (islands, climates, craters), §8.4 (item level), §11 (ecology), §17 (progression geography); roster PRD §2 (tiers per species). Numbers marked *design* are ours, not Durango's.

## Survivor exhaustion (owner-directed, 2026-09-25)

The survivor has Health, Energy, and **Exhaustion** (the saved `fatigue` value).
There are no player Hunger or Thirst meters or starvation penalties. Pet hunger is
separate and unchanged. Exhaustion rises slowly with time and from travel, gathering,
combat, and climate. The face beside its HUD bar progresses through rested (smile),
tired (flat), weary (frown), exhausted (deep frown). At 50% Energy regen slows; at
75% Energy capacity drops to 75%. It never causes death or hard-blocks gathering.

Food restores Energy, gives existing recipe buffs, and eases exhaustion by 25% of
its Energy value. Medicine, not food, remains the direct Health restore. Sleeping at a placed shelter is manual and interruptible; see the tiered sleep
plan below. Simply standing in a tent does not sleep.
These rates and thresholds are design assumptions, not historical Durango facts.

## 1. The shape of the world

Two kinds of land, exactly as Durango shipped: **stable** (your home island, later city islands) and **unstable** (islands that appear at a tier and climate, live for hours, then sink). Travel is a harbour route list, never sailing. Every island is one climate and one tier.

```
Home island (grassland, tier 10, permanent)
   └─ harbour ──► unstable islands by tier ──► craters, warp ruins, missions
                      15 savannah · 20 temperate · 25 tropical · 30 tundra · 35 desert
                      40 tropical/tundra · 45 swamp/savannah · 50 desert/snow · 55 tundra/swamp/blue tropical · 60 swamp/snow/volcanic
```

## 2. Island archetype (every unstable island)

Islands are 240 × 240 m *(design)*, read from the harbour inward. The player should be able to see the next ring from the edge of the current one.

| Ring | Radius from harbour | What is there | Danger |
|---|---|---|---|
| **Landing** | 0–30 m | Harbour, camp (bonfire, public workbench, shed, Communications Centre), coziness zone | none; nothing spawns inside 25 m of camp |
| **Gathering ring** | 30–90 m | Common nodes at island tier −5 to tier, herbivores, the trash mob of the climate | low; solo-safe |
| **Working ring** | 90–160 m | Full-tier nodes, the climate's signature predator packs, the river or water feature, rare-node clusters | medium; packs pull from off-screen |
| **Crater zone** | 160–210 m, one quadrant | Crater (plant, animal or mineral) with guardian creatures at tier +3 (PRD §4.5: +1 or +3 unresolved; we take +3 *design*), rare nodes at tier +5 | high |
| **Far shore** | 210–240 m, opposite quadrant | Warp ruin (unstable loot), apex creature, second warp hole | highest |

Rules:
- One river or lake band crosses the working ring; standing in water 5 s applies **Wet** (PRD §4.4.1).
- Two warp holes per island: one near the harbour, one in the far shore. Discovering both allows paid hops.
- Terrain: rolling noise, hills in the crater zone, beach ring on the coast. Never a cave (PRD §4.4.1).
- Camp is always on the coast; the crater is always inland. Players learn the shape once and read every island.

## 3. Material level

From PRD §8.4 and the owner's crafting rule (§8.4 addendum):

- A node's level = island tier + its ring offset: gathering ring −5 to 0, working ring 0, crater zone +5, warp ruin +5, capped at 60.
- Gathering skill below the node level **downranks** the take to the skill level.
- Crafted item level = mean of all consumed material levels, clamped by skill and recipe max.
- Every material stamped with attributes: always `climate` and `level`; climate-specific latent attributes from the tables below (yellow pip); 5% chance of a rare extra (green pip) *(design)*.
- Unstable-island materials carry the `unstable` flag until cargo-warped home (PRD §14.5).

So a tier-25 temperate island yields level 20–25 fibre in the gathering ring and level 30 flax at its plant crater, and a knife made from level-30 crater bone and level-20 branch is level 25.

## 4. Climates

Ten climates. Resistances gate comfort, not entry (PRD §6.6). Vegetation families are from `game/data/nature_manifest.json`.

| Climate | Tiers | Resist needed | Signature materials (latent attribute) | Vegetation families | Creatures (tier) | Crater types |
|---|---|---|---|---|---|---|
| **Grassland** (home) | 10 | none | fibre_stalk, branch, stone, herb_leaf, berries, clay | CommonTree, BirchTree, Bush, BushBerries, Grass, Flowers, Rock | none hostile; Compsognathus strays | none |
| **Savannah** | 15, 45 | weak heat | acacia_wood (light), dry_grass (fibre, `dry`), sandstone, ochre | CommonTree_Dead, Grass, Grass_Short, Rock, Bush | Compsognathus 15, Coelophysis 15–20, Styracosaurus 45, Protoceratops herds | plant (flax), mineral (ochre, sandstone) |
| **Temperate** | 20, 35 | weak cold | fibre_stalk, herb_leaf, branch, wood_log (`straight`), reed, flint, clay, berries | CommonTree, BirchTree, Willow, PineTree, Bush, BushBerries, Grass, Plant, Flowers, Rock_Moss | Protoceratops 20, Velociraptor 25, Deinonychus 35, Stegosaurus 45 | plant (flax, tea), animal (nests) |
| **Tropical** | 25, 40 | high heat | palm_frond, coconut, bamboo (`flexible`), mango, vine (lashing), obsidian | PalmTree, Plant, Grass, Bush, Rock_Moss, Lilypad | Deinonychus 35, Dilophosaurus 40, Compsognathus recolour | plant (bamboo, mango), mineral (obsidian) |
| **Tundra** | 30, 40, 55 | high cold | pine_log (`resinous`), resin, fur (from Megaloceros), ice, bone | PineTree, PineTree_Snow, Bush_Snow, Rock_Snow, Grass_Short | Megaloceros 30, Smilodon 45, Tarbosaurus 60 | animal (bone graves), mineral (ice) |
| **Desert** | 35, 50 | heat + scorching sun | cactus_flesh (water), cactus_spine (needle), sandstone, copper_ore, salt | Cactus, CactusFlowers, Rock_Sand-like (Rock), CommonTree_Dead | Gallimimus 30, Utahraptor 50, Allosaurus 50, Ankylosaurus 50 | mineral (copper, salt), plant (cactus) |
| **Swamp** | 45, 55, 60 | heat + humidity | reed, willow_wood (`pliant`), peat, clay, marsh_herb (medicine), leech | Willow, Willow_Dead, Lilypad, Plant, Grass, Rock_Moss | Triceratops 55, Deinonychus_swamp, Dilophosaurus | plant (marsh herbs), mineral (mud pits) |
| **Snowfield** | 50, 60 | cold + strong wind | ice, snow_pine, silver_ore, fur | PineTree_Snow, BirchTree_Snow, Willow_Snow, Rock_Snow, Bush_Snow | Smilodon_snow, Velociraptor_snow, Ankylosaurus | mineral (silver, ice) |
| **Blue tropical** | 55 | heat + humidity | pearl, coral (`hard`), palm, blue_dye | PalmTree, Plant, Lilypad, Rock | Dilophosaurus, Deinonychus | mineral (pearl, coral) |
| **Volcanic** | 60 | heat (volcanic) | black_iron, lava (needs shell), sulphur, ash | Rock, CommonTree_Dead, Rock_Snow (as ash-grey) | Tyrannosaurus raid, Ankylosaurus_volcanic | mineral (black iron) |

Attribute meanings (used by recipes later): `light` faster tools, `straight` better pillars, `flexible` bows, `resinous` torches burn longer, `hard` higher durability, `pliant` better lashing, `water` drinkable.

## 5. Spawn tables (unstable islands)

Density is creatures per 100 × 100 m in that ring *(design)*. Packs spawn as one unit. Cap per island 24 on mobile (M1b).

| Island | Gathering ring | Working ring | Crater zone | Far shore |
|---|---|---|---|---|
| Savannah 15 | Compsognathus swarm ×6 (2 groups) | Coelophysis flock ×4 (2), Protoceratops herd ×3 | Coelophysis ×5 at tier 18 | Coelophysis alpha |
| Temperate 20 | Compsognathus ×5, Protoceratops herd ×4 | Coelophysis ×4, Velociraptor pair | Protoceratops guardians ×4 (aggressive) | Velociraptor pack ×3 |
| **Temperate 25** (the raptor slice) | Protoceratops herd ×4, Compsognathus ×4 | Velociraptor pack ×3 (2 packs) | Velociraptor ×4 at tier 28, Deinonychus pair | Deinonychus ×3, Utahraptor (rare, 25%) |
| Tropical 25 | Compsognathus_tropical ×6 | Coelophysis ×4, Protoceratops ×3 | Deinonychus ×3 | Dilophosaurus |
| Tundra 30 | Megaloceros herd ×4 | Megaloceros ×3, Velociraptor_snow ×3 | Megaloceros stag guardians | Smilodon |
| Desert 35 | Gallimimus flock ×4 | Gallimimus ×3, Coelophysis ×4 | Gallimimus ×5 | Utahraptor |
| Temperate 35 | Protoceratops ×4 | Deinonychus pack ×3 (2) | Deinonychus ×4 tier 38 | Stegosaurus |
| Tropical 40 | Deinonychus ×3 | Dilophosaurus pair, Deinonychus ×3 | Dilophosaurus ×3 | Allosaurus (rare) |
| Savannah 45 | Coelophysis ×4 | Styracosaurus herd ×3, Deinonychus ×3 | Styracosaurus ×4 | Utahraptor pack ×2 |
| Temperate 45 | Protoceratops ×4 | Stegosaurus pair, Deinonychus ×3 | Stegosaurus ×3 | Utahraptor |
| Desert 50 | Gallimimus ×4 | Utahraptor pack ×3, Ankylosaurus | Ankylosaurus ×2, Utahraptor ×3 | Allosaurus |
| Swamp 55 | Compsognathus_swamp ×6 | Triceratops herd ×3, Deinonychus_swamp ×4 | Triceratops ×3 | Dilophosaurus ×3 |
| Tundra 55 | Megaloceros ×4 | Smilodon pair, Velociraptor_snow ×4 | Smilodon ×3 | Tarbosaurus |
| Volcanic 60 | none | Ankylosaurus_volcanic ×2 | Utahraptor ×3 | **Tyrannosaurus** raid |

Behaviour hooks (PRD §11.2): herbivores drink at water at dawn and sleep at night; predators hunt harder at night (+50% perception); herds have solidarity (hit one, pull all); scavengers (Compsognathus) swarm corpses within 40 m.

## 6. Craters and warp ruins

- Discovering a crater: fatigue −20 (Joy of Discovery, PRD §6.4), 30 T-stones *(design)*.
- Plant crater: 6–10 rare plant nodes at tier +5 (flax, bamboo, tea, mango, cactus by climate). Animal crater: 3 nests (eggs, feathers, bone) guarded by the climate's herd at tier +3. Mineral crater: 4–6 ore/mud/obsidian nodes.
- Warp ruin (far shore): 2–4 modern-junk containers: courier boxes with cloth, wire, medicine, rare seeds; every item `unstable`.
- Closed craters open by burying 50 T-stones *(design)*; open craters keep regenerating until the island sinks.

## 7. Home island (private)

Grassland, tier 10, 160 × 160 m, permanent. One-time terrain choice (PRD §4.2):

| Terrain | Layout | Bonus |
|---|---|---|
| Meadow | flat, open, sparse trees | most buildable land |
| Forest | dense CommonTree/BirchTree, clearings | +wood, shade (heat fatigue −) |
| Rocky | outcrops, few trees | +stone, natural walls |
| Riverside | river through the middle | water everywhere, farming success + |
| Coastal | long beach, salt | salt, fishing later |

Home resources regenerate slowly unless uprooted (NamuWiki reading, PRD §4.2 dispute resolved *design*: regenerate). No hostile spawns; Compsognathus strays for defence XP.

## 8. Island lifetime and rotation (M10)

- Lifetime by tier: 15–25: 6 h, 30–45: 12 h, 50–60: 24 h real time *(design)*, shown on the map. Warning at 60 s, forced return to camp.
- When an island sinks, a new layout of the same climate and tier appears within a minute; layouts come from a seed, so the ring archetype holds but node and crater positions differ.
- Follow-route (PRD §4.2) is out of scope until co-op.

## 9. Acceptance for the level design

1. From the camp, the player can see the gathering ring and the river; the crater zone is hidden by hills until entered.
2. A tier-25 island yields materials at 20, 25 and 30 in its three rings, and a crafted knife's level reads back as the mean.
3. Every climate has at least one tameable herbivore in the gathering ring and one status-applying predator in the working ring.
4. The volcanic island has no gathering ring: it is a raid, not a farm.

## Building expansion plan (owner-directed, 2026-09-26)

The shelter and utility line should make a camp useful, not fill the build menu with
cosmetic copies. These are DEADFRONT design recipes, not a historical Don't Starve
catalog. Counts below are initial balance targets. "Existing" means the gameplay
already has a station or prop, not that its final art or new behavior is finished.
Sleep is a deliberate action at a placed shelter: movement or damage interrupts it,
without spending a use. A completed sleep restores exhaustion, then decrements its
remaining uses in saved building state. Used bedding cannot be repacked into a fresh
kit. The public camp's starter shelter remains unlimited; it grants no free kit.

| Tier / structure | Craft input (item category/count) | What it does / unlocks | State |
|---|---|---|---|
| 0 Straw roll | fibre 3 + lashing 1 | 12 s sleep, restore 65 exhaustion; disappears after 1 completed sleep. 1x2. | first implementation |
| 1 Field tent | hide 2 + wood 2 + lashing 1 | 10 s sleep, restore 100; 6 completed sleeps, then disappears. 3x3. Replaces unlimited personal tent. | first implementation |
| 2 Canvas tent | fibre/canvas 6 + wood 3 + lashing 2 | 8 s sleep, restore 100; 12 sleeps; weather cover later. 3x3. | planned |
| 3 Log shelter | log 8 + fibre 6 + lashing 3 | 7 s sleep, restore 100; repair with logs instead of finite uses. 4x4. | planned |
| 4 Cabin bed | plank 6 + fibre 4 + hide 2 | 5 s sleep inside enclosed cabin, permanent; better home-base rest. | planned |

| Utility / station | Craft input (category/count) | What it does / enables | State |
|---|---|---|---|
| Campfire (temporary) | wood 2 + tinder 1 | Basic skewers, warmth and light for a short fuel budget; burns out. Distinct from the present persistent bonfire, which remains legacy until the conversion has a save migration. | planned |
| Stone fire pit | stone 6 + wood 2 | Persistent campsite fire/light; unlocks grilling and cauterise. Keep camp's existing fire available. | planned |
| Crock pot | clay 4 + stone 2 + wood 2 | Combines several ingredients into cooked meals and recipe buffs; no generic "cook anything" shortcut. | planned |
| Meat drying station | wood 4 + lashing 2 | Placed drying rack processes raw meat/fish into dried meat in 8 s (17 energy), keeping the existing dried-hide recipe. Weather, spoilage and passive batches remain planned. | first implementation |
| Flat stone grill | stone 4 + wood 2 | Single-ingredient roasted meats and vegetables; hotter tier than skewer. | planned |
| Smoker | wood 6 + stone 3 + lashing 2 | Slower preserved meat, better food quality than drying. | planned |
| Mortar and pestle | stone 3 + wood 1 | Crush herbs and grind ingredients for medicine and meatballs. | existing station / final art pending |
| Water well | stone 6 + wood 4 + lashing 2 | Reliable water source away from rivers; supports farming and cooking. | existing station / final art pending |
| Water purifier | clay 3 + stone 3 + wood 2 | Boils water for cooking, medicine, and dye processes. | planned |
| Workbench | wood 4 + lashing 2 | Basic tools, small structures and repair recipes. | existing |
| Repair grindstone | stone 4 + wood 2 | Repairs tools/weapons using compatible materials; avoid free durability resets. | planned |
| Tanning frame | wood 4 + lashing 3 | Processes hides for clothes and advanced shelters. | planned |
| Loom | wood 5 + fibre 4 + lashing 2 | Weaves canvas/cloth for tents, armour and sails. | planned |
| Kiln | clay 6 + stone 4 + wood 2 | Fired bricks and ceramic pots. | planned |
| Clay furnace / forge | clay 8 + stone 6 + wood 4 | Smelts ores and makes metal parts; fuel is consumed. | planned |
| Anvil bench | metal 3 + wood 4 | Metal tools and weapon upgrades; requires forge output. | planned |

| Home / ecology | Craft input (category/count) | What it does / enables | State |
|---|---|---|---|
| Basket | fibre 4 + wood 1 | 60-slot storage. | existing |
| Lidded chest | wood 6 + metal 1 | Protected storage with an explicit access owner when sharing exists. | planned |
| Raised storehouse | log 10 + plank 6 + lashing 4 | Large protected food/material store. | planned |
| Seed planter | wood 2 + soil/clay 2 | Small herb nursery; plant management. | planned |
| Farm plot | wood 2 + fibre 2 + soil/clay 4 | Grow crops with water and tending. | existing field system |
| Compost bin | wood 4 + fibre 2 | Converts plant scraps into fertilizer over time. | planned |
| Rain catcher | wood 3 + fibre 4 + clay 2 | Collects rainwater for the well/field loop. | planned |
| Fish trap | wood 3 + lashing 2 | Passive fish catch in placed water, with finite bait. | planned |
| Animal feed trough | wood 3 + fibre 2 | Deposits feed for bonded animals, not a free hunger reset. | planned |
| Reinforced taming pen | wood 8 + lashing 4 + metal 2 | Safer taming space; preserves the species' wild stat block. | planned |
| Fence / gate | wood 2 / wood 3 + lashing 1 | Route and protect a claim; gate allows entry. | existing |
| Palisade / windbreak | log 4 + lashing 2 / wood 3 + fibre 2 | Defence / climate cover in claimed areas. | planned |
| Watchtower / lantern post | wood 8 + lashing 3 / wood 2 + fuel 1 | Sightlines / night visibility; no passive omniscience. | planned |
| Sign / map board | wood 1 / plank 3 + lashing 1 | Name a place / display discovered route information. | sign existing; board planned |
| Cargo marker | wood 3 + stone 2 | Marks outbound cargo prep; does not waive warp fee. | planned |

Make the early loop legible: gather fibre -> roll -> sleep, hunt for hide -> field
tent, then a temporary cooking fire -> stone pit -> crock pot/meat dryer. Station
recipes should point to real products before placing the models. Generated art
replaces the Kenney placeholders only after in-world pixel checks. New economy
outputs, fuel rates, storage size, spoilage time and late tiers remain design
assumptions to playtest, not shipped mechanics.
