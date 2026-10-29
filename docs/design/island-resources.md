# Island maps and resource distribution: landmarks, biomes, depletion

**Status:** PROPOSAL v1, 2026-10-29. Not canon. Nothing here changes a shipped rule until Milan says so; the build
thread may only pick up the parts marked "build-thread call" in the open-questions file.
**Input:** Milan's research handoff "Durango: Wild Lands — Island Maps and Resource Distribution" (29 Oct 2026), read
against the docs wiki and the build on `claude/mmo-overhaul` d0c649fa.
**Companion file:** [`island-resources-open-questions.md`](island-resources-open-questions.md) (decisions for Milan,
build-thread defaults, and unverified history).

### Evidence labels used throughout

| Label | Meaning |
|---|---|
| **HISTORICAL** | Reported Durango behaviour, from the handoff's sources (fan archive, community mastersheet, a guide, a modern reconstruction). None of it is verified against footage or game files. |
| **CURRENT** | True of our docs or build today, with the file that says so. |
| **PROPOSED** | Our recommendation. Every number is a starting value marked *ASSUMPTION* until tuned. |

### Constraints this proposal keeps (from Milan's standing rules)

- Permanent home island plus resettable expedition (unstable) islands. New players start on the tutorial island at the
  south-most port; its last order grants the home.
- Prefab-first building: blueprints, worksites and transportable kits.
- One item per harvest. Tools and skill change speed and quality, never count. Each item rolls a level and at most 1-2
  perks, no duplicate families, grey rate 35 %.
- Active play beats passive: personally gathering, hunting and discovering must be the best route to rare materials
  and good traits. Tribe work and stations stabilise basic supply.
- Colour shows natural appearance, never rarity.
- Warp Gems are spent at the harbour to travel. Gold is the soft currency.
- Multiplayer is deferred, so nothing here assumes other players deplete an island.
- Islands are mostly flat and walkable, with non-navigable rocks, plateaus, cliffs, mountains and volcanos, in the
  creative shapes of Milan's "Satellite Island Map Grid.png".
- The game is about resource **quality** and skill building, not quantity.

---

## 1. Summary

1. **The pattern worth copying from Durango** is geographic purpose: a biome tells you which materials you can find,
   common materials grow everywhere suitable, and the rare ones sit in named, findable **landmarks** that you have to
   scout, reach and sometimes fight for. We already have most of the pieces (climates, zones, ring levels, one crater,
   fog of war). What we lack is the landmark layer, a real reset, and a reason for depletion to matter.
2. **Biggest gaps today** (section 2): every unstable island has at most one crater, and only `temperate_25` defines
   one; crater nodes are six generic herb plants whatever the climate; every ambient node regrows in 1-4 minutes, so
   nothing is ever scarce; an island "sinks" by teleporting you to camp and then comes back with the same layout; and
   iron ore exists only on the level 60 volcanic island, so iron and steel tools are end-game only.
3. **Proposal** (sections 3-5): five content layers per island (ambient nodes, habitat clusters, landmarks, contested
   landmarks, dynamic opportunities); 4-10 landmarks per expedition island drawn from eight landmark types per
   climate; a "Landmarks Found x / y" counter with a Gold payout per find; landmark nodes that do not regrow on
   expedition islands until the island resets with a new seed; and a rule that only the player's own hands get the
   landmark trait bonus.
4. **Six milestones** with test gates (section 6), in roadmap order after the island-shapes and zone work already
   running.
5. **Decisions for Milan** are in the open-questions file. The first one is what happens to buildings left on an
   island when it resets.

---

## 2. Gap analysis against the current wiki and build (deliverable a)

Sources read: `docs/current/world-biomes.md`, `docs/current/map-format.md`, `docs/current/items-traits.md`,
`docs/design/world-design.md`, `docs/design/islands-and-loop-plan.md`, `docs/design/durango-informed-improvements.md`,
`docs/design/durango-prompts/15_island_map_scale.md`, `docs/vision/WildLandsMMO_Game_Vision.md`,
`docs/vision/WildLandsMMO_Open_Questions.md`, `tools/docs_wiki/phase-map.json` (roadmap), and the code under
`game/scripts/world/`, `game/scripts/core/world.gd`, `game/data/`.

| # | Mechanic | HISTORICAL (handoff) | Our docs say | Our build does (CURRENT) | Gap | Fix in |
|---|---|---|---|---|---|---|
| G1 | Island categories | Personal, civilized, unstable, savage | Private home, unstable, city islands later (world-design §1, vision §2) | Home, tutorial (shared town, permanent), 13 unstable rows in `data/islands/` | Savage (PvP) belongs to deferred multiplayer. Tutorial plays the "civilized" role. No gap to act on now. | none |
| G2 | Biome sets resources | Each biome had a characteristic material mix and level list | Climate table with signature materials (world-design §4); zones per climate (islands plan §1.4) | `climates.json` lists 4-11 materials per climate; zones painted per tile | Covered for commons. Rares are thin: most climates have 1-2 materials not found elsewhere. | §4 matrix |
| G3 | Tool-tier ladder by geography | Iron in tropical, tin in tundra, copper/zinc/silver in snowfield, gold in desert | Ladder stone > flint > copper > bronze > iron > steel | Only `black_iron` carries the `iron_ore` category, and it grows only on `volcanic_60`. `iron_ingot` needs 2 `iron_ore`. | **Iron and steel are reachable only at level 60.** Bronze needs desert 35 copper plus temperate/tundra tin. | §4.3 |
| G4 | Ambient common nodes | Common resources everywhere suitable | Ring archetype: gathering ring tier -5 to 0, working ring tier | Scatter by zone; `material_level()` applies ring offsets from `rules.json` `rings` | Covered. | none |
| G5 | Named landmarks ("craters") | Many named sites per island (forest, garden, mine, mud pit, nest, graveyard, warp remnants); prompt 15 shows "Landmarks Found 2 / 13" | One crater per island (world-design §6, islands plan §1.3), types plant / animal / mineral | `_crater()` in `island_runtime.gd`: one 10 m trigger plus 6 `Plant` nodes yielding `herb_leaf` at tier +5, any climate. Only `temperate_25` (and home, tutorial) set a `crater` position. `rules.json` `craters.plant/animal/mineral` counts are read by nothing. | **The landmark layer is essentially missing.** | §5.1, M1 |
| G6 | Dormant landmarks opened with an item or currency | Dormant craters activated for a temporary gathering opportunity (patch rules unverified) | "Closed craters open by burying 50 T-stones" (world-design §6) | `craters.open_cost_tstones` 50 appears only as a price row in `econ_catalog.gd`; nothing opens | Not built. | §5.3, M3 |
| G7 | Guardians at landmarks | High-value sites guarded by hostile or specific species | Crater zone creatures at tier +3 (world-design §5) | Spawn rows can carry a `tier_offset`; `temperate_25` places one Utahraptor near its crater | Partly built; no landmark-to-guardian link. | §5.2, M3 |
| G8 | Depletion | Nodes deplete; partly harvested ones regrow, exhausted ones may stay gone until reset | "Open craters keep regenerating until the island sinks"; home "regenerates slowly" (world-design §6-7) | Every node regrows each pool after 60 s (mud, clay), 90 s (bushes), 240 s (trees) or 120 s (rest) (`island_scatter.gd` `_family_regen_seconds`), on home and expedition islands alike | **Nothing is scarce for more than four minutes**, so a landmark has no reason to be a destination twice and an island has no reason to be left. | §5.4, M4 |
| G9 | Island reset | Unstable islands expire and are replaced; interval varied by level and version | 6 / 12 / 24 h by tier, warning at 60 s, new layout of the same climate and tier from a seed (world-design §8; roadmap `island-rotation`, later) | `world.gd`: at 0 s the player is moved to camp and nothing else happens. Seed is fixed per island id, so the layout never changes. The timer restarts on every arrival. The harvest snapshot holds only the last unstable island left. | **No reset exists.** | §5.5, M4 |
| G10 | What a reset does to buildings | Not in the handoff | Vision §2: "precise recovery percentage remains unresolved" (salvage vault vs abandon) | Away-island buildings are saved and restored | Open design question for Milan. | Open Q A1 |
| G11 | Map discovery | Terrain map with coordinates, discovered landmarks, travel points; fog; scanners for craters and warp holes | MAPUI: fog, trail, icons (spec 15, 25); prompt 15 asks for "Landmarks Found x / y" and an Exploration Reward row | Fog and trail per island in `MapFog`; coordinates; harbour, camp, crater icons. `map_screen.gd:357`: "no landmark counter exists in code" | Counter, per-landmark reward, discovered-landmark markers, any scouting tool. | §5.6, M2 |
| G12 | Warp holes | Moved players between locations on an island after discovery | Two per island, paid hops after discovering both (world-design §2) | Not built | Not built; currency undecided (Gold or Warp Gems). | Open Q B6 |
| G13 | Home island economy | Personal islands were not an infinite high-yield source | Home tier 10 (world-design §1); vision §3: a larger home reaches level 50-55 nodes; islands plan Q1 proposes zone levels 1-10 | `home_grassland.json` `level_override: 1` (every home material is level 1) | **Docs disagree** (tier 10 vs 50-55 upper end), and the build freezes home at 1. | Open Q A4 |
| G14 | Active vs passive | Not addressed by the handoff beyond "reward active exploration" | Tribe ASSIGN (approved 2026-10-29): members work stations/worksites with the player's skills | Tribe v1 mines and fights; no rule keeps rare-trait sources player-only | Rule missing. | §5.7, M3 |
| G15 | Authored maps | Not addressed | Map lab `landmark` and `resource` markers (map-format.md) | Markers are saved but not imported: "resource clusters are not used yet", "no buildings or props are placed" for landmarks | Authored and generated islands should share one landmark data path. | M1 |
| G16 | Expedition loop | Study biome, choose island, scout, discover, evaluate risk and capacity, gather, return, refine/trade | Vision §1 "the expedition loop", §7 preparation, §17 boats and cargo | Harbour + Warp Gems + cargo-warp home with an unstable-goods warning | The middle of the loop (scout, discover, evaluate) has nothing to find. | M1-M2 |
| G17 | Biome roster and levels | Savanna 15/45, temperate 20/35, tropical 25/40/55/60, tundra 30/40/55/60, desert 35/50/60, swamp 45/55/60, snowfield 50/60, volcanic 60 | Same shape (world-design §1) | 15 islands; no snowfield or blue tropical island rows yet although both climates exist | Content gap, not a design gap. Roadmap `unstable-tier-ladder` covers it. | none |

**What is already good and should not be re-designed:** climates one per island with 5-7 zones inside; ring levels
from the landing; island sizes from data; the fog and trail map; one item per harvest with perk tiers; cargo-warp home;
Warp Gems at the harbour; the map lab format. This proposal builds on all of them.

---

## 3. Map and resource generation specification (deliverable b)

### 3.1 Five content layers (PROPOSED, adapted from the handoff's §6)

| Layer | What | Where | Regrowth | Who benefits most |
|---|---|---|---|---|
| L1 Ambient nodes | Trees, rocks, grass, berries, water, the climate's commons | Every suitable tile, by zone (CURRENT scatter) | Fast, as today | Everyone, tribe included |
| L2 Habitat clusters | Readable concentrations: forest, reed bed, riverbank clay, scree slope, beach driftwood | Zone cores (CURRENT zone map) | Fast to medium | Everyone, tribe included |
| L3 Landmarks | Named sites with 5-10 better nodes and one signature rare | Inland, spaced, reachable (§3.3) | None on expedition islands until reset; slow on home | The player's own hands (§5.7) |
| L4 Contested landmarks | A landmark plus a guardian group or hazard | Working ring and beyond | As L3 | The player, with pets and party |
| L5 Dynamic opportunities | Dormant landmarks that can be opened, island resets, later seasonal events | Any expedition island | One-off | The player |

L1 and L2 already exist. L3-L5 are the new work.

### 3.2 Generation pipeline (PROPOSED)

The order follows the handoff's implementation order, mapped onto the generator we have.

1. **Shape and traversability.** CURRENT `IslandShape` (or `MapDoc.apply_to_shape` for an authored map): coast,
   hills, cliffs, river, pond, harbour cove. Output: walk mask, TilePath, dry bounding box.
2. **Zones.** CURRENT zone pass (coast, river, slope, elevation, moisture), then any painted map zones.
3. **Ambient and habitat nodes.** CURRENT `IslandScatter` by zone and `material_level()` ring offsets.
4. **Landmark placement** (new, `IslandLandmarks`):
   1. Read the island's landmark budget (§5.1) and the climate's landmark table (`data/world/landmarks.json`).
   2. Draw types without replacement by weight, guaranteeing one of each "must have" type the climate lists.
   3. For each type, sample candidate tiles that pass its terrain rule (e.g. a mine needs a slope or rock tile within
      8 m, a mud pit needs a river or pond bank, a nest needs a flat dry clearing), then keep the best by score:
      distance from the landing in the type's ring band, distance from other landmarks, zone match.
   4. Reject a candidate that fails any validation rule in §3.3, and fall back to the next. A type that finds no site
      is skipped and logged (`[landmarks] skipped <type> reason=<code>`), never forced onto a bad tile.
   5. Plant the landmark's node group around its centre (ring of 6-12 m), then its props (a cave mouth, bones, a
      nest mound, a warp shard) as scenery, never blocking the nodes.
5. **Guardians and hazards** for contested landmarks: a spawn row anchored on the landmark (`at`, `tier_offset` +3).
6. **Discovery data:** each landmark gets a stable id, a display name ("Copper Vein", "Raptor Nests"), a discovery
   radius and a map icon. They go into `rt.landmarks` for the map and the save.
7. **Lifecycle state:** the island's `ExpeditionInstance` (§3.4) seeds steps 1-6 and records what has been found and
   harvested.
8. **Tuning** by bot and by Milan's play (M6).

Determinism: one seed per island instance, `hash(template.seed, instance.generation)`. Home and tutorial keep their
fixed seeds (generation 0, never reset). Node ids keep the CURRENT layout tag plus the generation, so a reset can never
match an old harvest row.

Authored maps: a map-lab `landmark` marker with a `type` prop places that landmark exactly; untyped landmark markers
and islands without markers fall back to step 4. That closes G15 with the same code path.

### 3.3 Validation rules for landmarks (PROPOSED)

| Rule | Value (*ASSUMPTION*) | Why |
|---|---|---|
| Reachable from the harbour on foot (TilePath) | required | Handoff anti-pattern: no unreachable mines |
| Distance from the landing camp | type's ring band; no landmark inside 60 m of camp | Keep the dock area calm; scouting has to happen |
| Spacing between landmark centres | at least 45 m on expedition islands, 30 m on home | Each find is a separate destination |
| Not inside a claim, a `claim_free` circle, the tutorial town's safe ring, or the camp clearing | required | Claims and towns stay clean |
| At least one landmark per island inside 140 m of the landing | required | First find within about 30 s of running from camp |
| At least one landmark visible from a hilltop or across open ground (not hidden by hills) | required | Scouting from high ground has something to show |
| Node group fits on walkable tiles with the node footprint rules | required | No floating or cliff-face nodes |
| Build time added by the pass | at most +0.3 s native per island | Perf budget in islands plan §1.7 |
| Landmark nodes count inside the island's node budget | home 450-600, unstable 500-750 | Same budget; the scatter's top-up yields to landmarks |

### 3.4 Data model (PROPOSED, mapped to our files)

The handoff's five records map onto files we already have, plus one new data file and one new save block.

```text
data/islands/<id>.json  (IslandTemplate; exists)
  id, climate, tier, size_m, kind, permanent, seed, lifetime_seconds, harbour, camp, map
  + landmark_budget: [min, max]          # new; defaults by tier band from rules.json
  + landmark_must: ["mine", ...]         # new, optional

data/world/biomes.json  (HabitatRegion rules; exists)
  per climate + zone: node families, densities, ground cover

data/world/landmarks.json  (ResourceLandmark types; NEW)
  types.<type>:
    display: "Copper Vein"               # name pattern, climate may override
    ring: [min_m, max_m]                 # distance band from the landing
    terrain: ["slope", "rock_near"]      # placement predicates
    nodes: {family: [min, max], ...}     # node group, uses nature_manifest families
    level_offset: 5                      # node level = tier + offset, cap 60
    trait_bonus: {tier_step: 0.05}       # hand-harvest only (§5.7)
    guardians: {chance: 0.4, rows: [...]}
    depletion: "no_regen" | "slow"       # per island kind, §5.4
    dormant_chance: 0.0                  # §5.3
    discovery: {radius_m: 18, gold: 20}
  climates.<climate>: [{type, weight, yields: {...}, must: bool}, ...]

nature_manifest.json  (ResourceNode; exists)
  family -> yields, pool, tool class, min pick tier; + regen_by_kind (new, §5.4)

save: world.expeditions.<island_id>  (ExpeditionInstance; NEW block, replaces the single `harvested` snapshot)
  generation, seed, expires_at_game_s, landmarks_found[], landmark_state{id: {opened, nodes_left}},
  harvested{node_id: pools}, fog (moves under it)
```

Notes:
- `ExpeditionInstance` per island id fixes a CURRENT bug class: `World.harvested` holds only the last unstable island
  left, so visiting two expedition islands forgets the first.
- The home keeps its harvest state in the same block with `generation` 0 and no `expires_at`.
- No schema bump for old saves: a missing block means "generation 0, nothing found, nothing harvested" (the same as a
  first visit today).

---

## 4. Biome-to-resource matrix (deliverable c)

### 4.1 How to read it

- **Ambient / habitat** lists are CURRENT (`climates.json` materials and the islands plan's zone sets).
- **Landmarks** are PROPOSED. Yields in *italics* are materials **we do not have yet**; each needs an item row, a node
  family and a card, so each is a proposal for Milan to accept or cut (open Q A6), not canon.
- **Durango reference** is HISTORICAL and only there to show where we diverge on purpose.
- Landmark levels are tier +5 (cap 60). Guardians are tier +3.

### 4.2 Matrix

| Climate (tiers) | Ambient and habitat (CURRENT) | Landmarks and their signature rare (PROPOSED) | Guardians and hazards | Durango reference (HISTORICAL) |
|---|---|---|---|---|
| **Grassland** home (10) | fibre, branch, wood_log, stone, herb_leaf, berries, clay, corn; zones meadow, forest, riverbank, rocky hills, dry upland, beach | Home only: Old Grove (best wood_log, `straight`), Clay Bank (clay), Flint Scree on the Rocky pick, Salt Flat on the Coastal pick | none hostile | Personal islands: limited natural gathering |
| **Savannah** (15, 45) | dry_grass `dry`, acacia_wood `light`, sandstone, ochre, branch, stone; zones grassland, delta, mesas, scrub, beach | Acacia Grove (acacia_wood), Ochre Pit (ochre, sandstone), Flax Garden (flax), Nest Field (eggs, *feather*), Bone Field (bone, dense_bone) | Coelophysis / Styracosaurus at nests; heat (weak) | Baobab, lavender, elephant grass, crabgrass, nests, zinc and marble mines |
| **Temperate** (20, 25, 35, 45) | fibre, herb_leaf, branch, wood_log `straight`, reed, flint, clay, berries, stone, tin_ore, wheat; zones mixed forest, willow bank, meadow, flint hills, beach | Flint Quarry (flint), Tin Vein (tin_ore), Old Grove (wood_log), Flax Garden (flax), *Tea Garden* (*tea leaf*), Raptor Nests (eggs, `raptor_*` parts nearby) | Velociraptor / Deinonychus packs; Protoceratops at nests; cold (weak) | Flax, bamboo, roses, sandalwood, cotton, tea trees, Oviraptor nests |
| **Tropical** (25, 40) | palm_frond, coconut `water`, bamboo `flexible`, mango, vine, obsidian `hard`, stone; zones jungle, lagoon, obsidian ridge, palm beach | Obsidian Ridge (obsidian), Bamboo Grove (bamboo), Fruit Garden (mango, coconut), **Iron Vein** at tier 40 (*iron_ore*, see §4.3), Vine Tangle (vine) | Deinonychus, Dilophosaurus; heat (high), storms | Bananas, mangoes, sugar cane, tropical flax, rubber trees, iron, gems, marble |
| **Tundra** (30, 40, 55) | pine_log `resinous`, resin, ice, bone, stone, branch, tin_ore; zones taiga, frozen steppe, ice hills, snowy shore | Tin Vein (tin_ore), Resin Pines (resin, pine_log), Bone Field (bone, dense_bone, Megaloceros antler later), Mushroom Ring (mushroom), **Iron Vein** at tier 55 | Megaloceros stags, Smilodon, Tarbosaurus; cold (high) | Fir, pine, cotton, flax, mushrooms, sap, tin, sapphire |
| **Desert** (35, 50) | cactus_flesh `water`, cactus_spine `needle`, sandstone, copper_ore, salt, stone; zones dunes, canyon mesas, oasis, salt flats | Copper Vein (copper_ore, rough `ore`), Salt Pan (salt), Animal Graveyard (bone, dense_bone, skull plates), Cactus Garden (cactus, *agave*), *Gem Pocket* at tier 50 (*ruby*, treasure only) | Utahraptor, Allosaurus, Ankylosaurus; heat + sun | Cactus, agave, animal graveyards, bones, obsidian, gold, ruby |
| **Swamp** (45, 55) | reed, willow_wood `pliant`, peat, clay, marsh_herb `medicinal`, leech; zones willow marsh, peat bog, hummock forest, mud shore | Mud Pit (mud, clay), Peat Bog (peat), Marsh Garden (marsh_herb, *lotus*), Willow Stand (willow_wood), Leech Pool (leech) | Triceratops herds, Dilophosaurus; heat + humidity | Mud, cattails, vines, mangroves, rubber trees, lotus, insects |
| **Snowfield** (50, 60; no island row yet) | ice, snow_pine `resinous`, silver_ore, stone | Silver Vein (silver_ore), Ice Field (ice), Snow Pines (snow_pine), Mammoth-style Bone Field (bone, fur later) | Smilodon, Ankylosaurus; cold + wind | Fir, sandalwood, cranberries, copper, zinc, silver, mammoths |
| **Blue tropical** (55; no island row yet) | pearl, coral `hard`, palm_frond, blue_dye, coconut | Reef (coral, pearl), Dye Garden (blue_dye), Palm Grove | Dilophosaurus, Deinonychus; heat + humidity | (not in the handoff's list) |
| **Volcanic** (60) | black_iron `hard`, lava, sulphur, ash | Black Iron Vein (black_iron), Sulphur Vents (sulphur), Ash Field (ash), **Warp Remnant** (unstable loot, see §5.1) | T. rex raid, Ankylosaurus; heat (volcanic). No gathering ring (world-design §9) | Scorched forests, gray mud, warp remnants, volcanic resources |

Design rule this matrix follows (from the handoff, PROPOSED as canon): **a higher-level biome never supplies
everything.** Each climate keeps at least one signature rare that no other climate has (acacia, flint-quality wood,
obsidian, resin, copper, peat and marsh herbs, silver, pearl, black iron), so a level 50 player still has reasons to
visit a level 20 island for its landmark.

### 4.3 Tool-tier ladder coverage (CURRENT, with the proposed fix)

| Rung | Input | Where it grows today | Earliest island level today | Proposed |
|---|---|---|---|---|
| Stone | stone | everywhere | 1 | unchanged |
| Bone | bone parts | any hunt | 1 | unchanged |
| Flint | flint | temperate | 20 | Flint Quarry landmark on temperate; Flint Scree on the home Rocky pick |
| Obsidian | obsidian | tropical | 25 | unchanged; Obsidian Ridge landmark |
| Copper | copper_ore (pick tier obsidian) | desert | 35 | unchanged; Copper Vein landmark |
| Tin, for bronze | tin_ore | temperate, tundra | 20 / 30 | Tin Vein landmark |
| Iron | `iron_ore` category (only black_iron) | volcanic | **60** | Iron Vein landmarks on tropical 40 and tundra 55 (Durango had iron in tropical). Black iron stays the better volcanic grade. |
| Steel | iron + carbon | volcanic | **60** | follows iron |

This is the most important content fix in the doc: without it the whole iron tier (knife, axe, pick, sword, four armour
pieces) is out of reach until the last island. Whether iron should be that late is Milan's call (open Q A5).

---

## 5. Landmark and depletion rules (deliverable d)

### 5.1 Landmark types and budgets (PROPOSED)

| Type | Node group (*ASSUMPTION*) | Ring band from landing | Contested? | Notes |
|---|---|---|---|---|
| Grove (forest) | 5-8 trees of the climate's best wood | 90-200 m | sometimes | Felling is slow; good for quality wood |
| Garden / colony (plants) | 6-10 plants (fibre, herbs, fruit, flax) | 60-180 m | rarely | Fast to harvest, fragile perks |
| Vein / mine (minerals) | 4-6 ore or stone nodes on a rock face | 110-240 m | often | Needs the right pick tier |
| Mud pit | 4-6 mud, clay or peat nodes at a bank | river or pond | rarely | Low risk, soil materials |
| Nest | 3 nests (eggs, feathers) | 110-240 m | always | The parents guard it; egg taking angers the herd |
| Bone field / graveyard | 4-6 bone piles | 140-260 m | often | Scavengers (Compsognathus) swarm |
| Warp remnant | 2-4 containers of modern junk (CURRENT `warp_ruin` loot) | far shore | always | Every item `unstable` |
| Reef (blue tropical only) | 4-6 coral and pearl nodes in shallows | coast | rarely | Wading, Wet status |

Budget per island (*ASSUMPTION*), by land area so walking time per find stays similar:

| Island | Land | Landmarks | Contested share | Dormant |
|---|---|---|---|---|
| Home (any pick) | 375 x 300 m | 2-3 (low level, see A4) | 0 | 0 |
| Tutorial | 795 x 636 m | 6-8 authored (one per teaching beat) | 1-2 | 0 |
| Unstable 15-25 | 330 x 265 m | 4-6 | 1-2 | 0-1 |
| Unstable 30-45 | 375 x 300 m | 6-8 | 2-3 | 1 |
| Unstable 50-60 | 415 x 335 m | 8-10 | 3-4 | 1-2 |

This replaces "one crater per island" (world-design §6, islands plan §1.3). The CURRENT crater trigger becomes one
landmark of the new kind.

### 5.2 What a landmark gives (PROPOSED)

- **Level:** node level = island tier + 5, capped at 60 (keeps world-design §3's crater offset).
- **Quality, not quantity:** still one item per harvest. A landmark node's hand harvest raises the perk-tier step
  (`loot_tables.json rare_trait.tier_step`, CURRENT 0.35) by +0.05 and the rare-trait chance by x1.5 (*ASSUMPTION*),
  inside the existing cap of 1-2 perks and no duplicate families. Grey rate stays 35 %.
- **Signature rare:** each landmark type per climate names one material you can only get there (§4.2).
- **Guardians:** a contested landmark spawns its guardian group at tier +3 when the player first comes within 40 m,
  anchored on the landmark (they return to it). Alphas follow the CURRENT 8 % per pack rule; none on the tutorial.
- **Pool:** each landmark node has a normal pool (CURRENT pools: a rock or tree gives 30 passes, a bush 12), so a
  landmark yields roughly 60-200 items before it is spent, which is several trips' worth of carrying.

### 5.3 Dormant landmarks (PROPOSED, needs Milan's yes: open Q A3)

- A dormant landmark shows on the map once found, as a sealed site (a capped vent, a sealed cave, a dead grove).
- The player opens it at the site by paying Gold (CURRENT data: `craters.open_cost_tstones` 50, now Gold). Opening wakes
  its guardians, then grows its node group for a limited window (20 game-minutes, *ASSUMPTION*), after which unharvested
  nodes wither.
- It is a Gold sink and a "dynamic opportunity" (layer L5) without a timer the player did not choose.
- Never a Warp Gem cost (Warp Gems stay a harbour currency).

### 5.4 Depletion and regrowth (PROPOSED)

The handoff's warning applies even in single-player: if nothing depletes, landmarks are just denser nodes; if
everything depletes forever, a bad first trip ruins an island. So the rule differs by layer and by island kind.

| Layer | Home and tutorial | Expedition island |
|---|---|---|
| L1 ambient | CURRENT fast regrowth (60-240 s per pool) | Slower: x5 (5-20 min per pool, *ASSUMPTION*) so a camp's surroundings thin out and the player moves on |
| L2 habitat | CURRENT | x5 as above |
| L3/L4 landmark nodes | Slow regrowth: a spent pool refills after one in-game day (*ASSUMPTION*) | **Partial regrowth only:** a node with any units left slowly refills (one unit per 10 min); a node taken to 0 stays empty until the island resets |
| Carcasses | CURRENT | CURRENT |

The partial-regrowth rule is the HISTORICAL player report, adopted because it gives a real choice: strip a vein now,
or leave a unit in each node and come back after the next sail.

### 5.5 Island lifecycle and reset (PROPOSED; parts need Milan: open Q A1, A2)

1. **Lifetime** per world-design §8 and `rules.json lifetime_hours`: 6 h (15-25), 12 h (30-45), 24 h (50-60). The
   CURRENT `temperate_25` override of 2 h is a test value and should go.
2. **One clock per expedition island**, saved in its `ExpeditionInstance`, counting game time while the game runs on
   any island (*ASSUMPTION*: not while the game is closed, so a player cannot lose a camp while away; open Q A2).
   Leaving and coming back no longer restarts the clock (CURRENT behaviour restarts it on every arrival).
3. **Shown everywhere it matters:** the map panel's "Island Life Span" row (spec 15), the Sail chart, and a HUD chip
   in the last 10 minutes.
4. **Warnings** at 10 min and 60 s (CURRENT `sink_warning_seconds` 60). Unstable goods follow the CURRENT cargo-warp
   and confirm rules.
5. **At 0:** the player (if there) is carried to the harbour and offered the sail menu; the island's generation
   increases, a new seed builds a new layout of the same climate and tier, the fog, found landmarks and harvest state
   clear, and the clock starts again.
6. **Buildings and stored goods left there:** Milan's decision (A1). Recommended: packed prefab kits and anything in
   a cargo box at the harbour survive into the vault at home; placed structures are lost but return a share of their
   materials (vision §2 "salvage vault" option). This makes "pack it or lose it" the expedition's closing decision,
   which is what vision §22 "the unstable-island expedition" describes.

### 5.6 Discovery and map (PROPOSED)

- **Found** when the player walks within the landmark's discovery radius (18 m, *ASSUMPTION*) or, for a visible
  landmark, spends 2 s scouting it from a hilltop (below).
- **Reward per find:** Gold scaled by tier (20 Gold at tier 15 up to 60 at tier 60, *ASSUMPTION*), plus the CURRENT
  Joy of Discovery fatigue drop on the first find per island. Replaces the CURRENT single 30-Gold crater payout.
- **Map panel** (spec 15): "Landmarks Found x / y" with a bar, and the Exploration Reward total.
- **Markers:** found landmarks show their icon and name on the map and minimap; unfound ones never show (the
  handoff's anti-pattern: do not reveal every rare at arrival). A dormant landmark's icon reads sealed.
- **Scouting from high ground:** standing on a hill or plateau top, the player can SCOUT (a context action) to reveal
  "?" markers for landmarks in line of sight within 120 m (*ASSUMPTION*). A Survival or exploration skill node can add
  range; a spyglass item can come later. This uses our hills and plateaus and rewards climbing them.
- **Warp holes** (world-design §2) stay later; see open Q B6.

### 5.7 Active beats passive (PROPOSED, closes G14)

| Source | Can harvest | Trait odds | Landmark bonus |
|---|---|---|---|
| Player by hand | everything | full (tool tier, skill) | yes |
| Tribe member following the player | L1, L2 and L3 nodes while the player is within 40 m | base (no tool-tier bonus) | no |
| Tribe member on an ASSIGN job, station, farm, trap | L1, L2 only | base, perk tier capped at II | no |

So passive work keeps the base fed and recovers losses, while rare materials and high perk tiers come from the player
being at the landmark. The tribe numbers are the build thread's call (the 2026-10-29 tribe memo leaves open questions
to it); this table states only the principle that needs Milan's yes (open Q A7).

---

## 6. Implementation milestones and test criteria (deliverable f)

Order follows the roadmap: these come after `island-shapes` and `shape-consumers` (running) and with `zone-terrain`.
Each milestone passes the CURRENT merge gates (all `t_*.gd`, `tools/all_tests.sh`, smoke, windowed shots at 1600x900
and 844x390) plus its own gate below.

**M1 Landmark layer (data + generator).** `data/world/landmarks.json`, `IslandLandmarks` pass, budgets, validation,
map-lab `landmark` markers with `type` imported, the CURRENT crater turned into one landmark.
- `t_landmarks.gd`: for all 15 island rows x 5 seeds, the landmark count is inside its band; every landmark is
  reachable from the harbour by TilePath; spacing and camp-distance rules hold; at least one within 140 m of the
  landing; 0 placed on claims, `claim_free` circles or the tutorial safe ring; deterministic (same seed, same ids and
  positions).
- `islandgen_lab` prints `[landmarks] island=<id> placed=<n> skipped=<n> types=<list>`; skips under 10 % across the run.
- Island build time +0.3 s native at most; node count inside budget.
- A top-down shot per climate with landmark icons drawn, looked at.

**M2 Discovery and map.** Found state, Gold per find, Landmarks Found x / y, markers, SCOUT from high ground,
save round-trip.
- `t_landmark_discovery.gd`: walking into the radius finds once, pays once, survives save and load; unfound landmarks
  never appear on the map texture or minimap; SCOUT reveals only those in line of sight.
- `tools/ui_screens.sh` shots of the map panel with the counter at both resolutions.

**M3 Landmark yields, guardians, active rule, dormant sites.** Level +5, trait bonus, signature rares from data,
guardian spawn on approach, tribe restrictions, dormant open with Gold (if A3 is yes).
- Simulated 2,000 harvests per source: landmark hand-harvest rare rate is 1.4-1.6x ambient at the same tool; tribe
  ASSIGN never yields perk tier III+; one item per harvest holds everywhere.
- Guardians spawn once per approach, return to the landmark, respect the tutorial's no-alpha rule.
- Opening a dormant landmark charges Gold once, grows its nodes, withers them after the window.

**M4 Depletion and reset.** `ExpeditionInstance` save block; per-kind regrowth; partial regrowth on landmark nodes;
real reset with a new seed; warnings; the buildings rule from A1.
- `t_island_reset.gd`: advancing the clock past 0 increments the generation, changes the seed, moves at least 70 % of
  landmark centres by over 40 m, clears found and harvest state, puts the player at the harbour; mid-life save and
  load keeps `expires_at`; leaving and returning does not restart the clock; two expedition islands keep separate
  harvest state.
- Old saves load with no new block and behave as a first visit.

**M5 Matrix content.** Approved new materials (A6), iron veins (A5), node families, card art through the CURRENT card
pipeline, recipes that consume the new materials.
- A ladder audit (`tools/docs_wiki/` style script or `t_data` check) prints the earliest island level for each tool
  rung and fails if a rung has no source at or below its intended level.
- Every climate has at least one signature rare absent from all other climates.
- Generated wiki pages (`gen_game_data.py`) list landmarks per climate.

**M6 Fun pass.** Bot expedition runs plus Milan's play.
- Bot at human pace on a fresh tier-25 island: first landmark found within 3 min of landing; 3+ landmarks found in a
  20-minute trip; at least one contested landmark cleared or deliberately skipped; cargo home has at least one
  landmark-only material.
- The yardstick question to Milan after playing: "is going out to find landmarks fun?"

---

## 7. Proposed wiki changes (not applied; need Milan's OK)

| File | Change |
|---|---|
| `docs/design/world-design.md` §6, §8 | Point to this doc for landmarks and resets once Milan approves; mark "one crater per island" superseded. |
| `docs/design/islands-and-loop-plan.md` §1.3 "Crater, every island" | Same pointer. |
| `docs/vision/WildLandsMMO_Open_Questions.md` | Add the open-question rows A1-A7 with links. |
| `docs/current/world-biomes.md` | Generated "Landmarks per climate" section when M1 lands (from `landmarks.json` via `gen_game_data.py`; never hand-edited). |
| `docs/current/map-format.md` | `landmark` marker gains a `type` prop when M1 lands. |
| `tools/docs_wiki/phase-map.json` | New roadmap features: `landmarks` (phase 3, after `zone-terrain`), `landmark-discovery` (phase 3), `material-ladder-coverage` (phase 4), and fold M4 into the existing `island-rotation`. |
