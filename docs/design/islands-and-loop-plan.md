# Islands, look and first-hour loop: plan

**Status:** v1, 2026-10-21. Lead-designer plan for the owner's request: *"focus on building islands so they are larger
with different biome terrain (even the player starter island). Make the islands visually appealing and improve the
build/craft/skill systems until there is a clear gameplay loop that is fun."* Base: `claude/mmo-overhaul` 88ba6ef3
(SKILLBUY merged at 22a98728; W2-GATHER, W2-PROCESS, W2-BUILDSYS, ECON, SAVEFIX, CLAIMFIX, GUIDE, W1-BIOME not merged).

Inputs: three scout reports (island tech, first-hour play, look) with measurements, prototypes and shots in the session
scratchpad `islands-plan/`; `islandmap-check.md`; specs 01, 03, 04, 05, 08, 09, 10, 15, 25 and **26 (biome concept art)**;
`world-design.md`; PRD §4.2-4.4. Numbers marked *ASSUMPTION* are ours where the docs are silent.

**Two design rulings this plan rests on**
1. **Climate stays one per island** (PRD §4.4). The owner's "different biome terrain" is **zones inside an island** (PRD
   :1003 "tile biomes are data-driven"): every island, the starter included, has 5-7 zones drawn from its climate's set.
2. **The home terrain pick (PRD §4.2, world-design §7) becomes a zone weighting**, not a node count. Every home has every
   home zone; a Forest pick makes the forest the largest zone, a Riverside pick puts the river through the middle, and so on.

---

## 1. Islands

### 1.1 Sizes

Land is measured as the dry bounding box. Reference: Durango map 300 x 374 m (islandmap-check). Today: home 134 x 131 m,
every unstable island 406 x 404 m (forced to S = 480 by `island_runtime.gd:84-90`).

| Island | Grid square S (m) | Land target (long x short) | Land area | Edge to edge at run (7 m/s) |
|---|---|---|---|---|
| Home (grassland 10) | 416 | 375 x 300 m (+-10 %) | 70-80k m2 | ~54 s |
| Unstable tier 15-25 | 368 | 330 x 265 m | 55-65k m2 | ~47 s |
| Unstable tier 30-45 | 416 | 375 x 300 m | 70-80k m2 | ~54 s |
| Unstable tier 50-60 | 464 | 415 x 335 m | 90-100k m2 | ~60 s |

- Size comes from `data/islands/<id>.json` `size_m` (or a tier default in `rules.json`), never from `far_shore x 2`.
  Every unstable island ends up no bigger than today's 480, so the unstable build cost does not grow.
- Heightmap resolution: `_res = 161` for every island (160 divides into 8 chunks; cells 2.3-2.9 m, so 2-6 m hills do
  not facet badly). Mesh cost about 1.6x today's 129 (0.14-0.36 s native today). Fall back to 129 if the build gate fails.
- The grid stays a square centred on the world origin (tile map, minimap, atlas, water shader, claims and tests all assume
  it). The **shape** gets a centre offset inside that square instead (1.2), which is one vector and no consumer change.

### 1.2 Shape generator (ragged, elongated, varied)

One function replaces the three radial tests (`island_terrain.gd:67`, `:327`, `island_runtime.gd:229`):

```
q        = rotate(p - shape_centre, -long_axis_angle);  q.y /= aspect          # aspect 0.75-0.85
theta    = atan2(q)
edge(th) = R * (1 + a2 cos(2th+f2) + a3 cos(3th+f3) + a4 cos(4th+f4)           # a_k 0.04-0.10
                 + peninsula(th) - bay(th)) + coast_noise(th) * 0.05 R
eff_rad  = |q| / edge(theta)                                                   # 1.0 = the coastline
```

- `peninsula(th)`: one or two Gaussian lobes, width 18-30 deg, height 0.18-0.30 R (spec 26: "peninsulas and large
  cliffs"). `bay(th)`: one cove, width 25-35 deg, depth 0.15-0.30 R, on the harbour side; the harbour sits at its head.
- Everything downstream (shore bands, ridge, tile types, `land_radius()`, `is_dry`) works in `eff_rad` units, so the
  existing beach and shallow-water profile survive unchanged.
- **Precompute** `eff_rad` into a PackedFloat32Array at heightmap resolution with a bilinear `rad_at(x, z)`. Never call
  noise inside `is_dry` / `spawn_ok` (TilePath, creature probes and build checks call them per tile).
- **Seed per island** from `seed` in the island JSON (fallback `hash(id)`), used by terrain, scatter and spawns
  (`island_terrain.gd:36`, `island_scatter.gd:16`). Home keeps seed 17 for the legacy core (1.6). Node ids become
  `<layout_tag>_<family>_<n>` so old ids never match new nodes.
- **Consumers to fix:** TilePath region from the dry bounding box, not `land_radius` (`tile_path.gd:146-152`; the
  prototype left 333 dry tiles outside the walkable grid); scatter windows (`island_scatter.gd:79,284`); palm test
  (`:92`); spawn clamp (`island_spawns.gd:53`); `ring_name` and `_ring_point` measured from the **landing point**, not
  the origin (`island_runtime.gd:175-184`, `island_spawns.gd:81-89`).
- **Unstable camp at the landing:** camp hint = arrival point + 20-25 m inland (world-design §2: "camp is always on the
  coast"). Camp to harbour <= 40 m (today 186-210 m). Fix the 13 stale harbour hints and make t_harbour's JSON check
  read the row before `_publish_harbour_arrival` overwrites it.

### 1.3 Landforms (spec 26: "big landforms carry the look")

Height = base rolling noise (0.5-1.5 m) + zone relief + features. All features are stored once as data on the runtime
(`rt.features`) and read by both the height loop and the tile-type loop (today the river is duplicated at
`island_terrain.gd:75-80` and `:343-346`).

| Feature | Rule | Gameplay |
|---|---|---|
| Hills | 1-2 ridge spines along the long axis away from the harbour, 3-6 m, slope > 0.55 paints rock | Hide the crater zone from camp (world-design §9.1) |
| Cliffs and terraces | 2-4 m steps on hill flanks and on one peninsula's coast; faces paint rock, block paths (slope gate) | Natural walls, view points |
| River | Polyline from the highest hill to the sea, 3-5 control points + noise, 6-10 m wide, MUD bed depth -0.25 to -0.38 (t_water profile); widens to a 20-30 m delta with 2 channels where it meets the coast | Water, washing (spec 17), clay, reeds |
| Pond or lake | 0-1 per island, 15-30 m, in the wettest low ground | Herbivores drink at dawn (world-design §5) |
| Cove | The `bay` lobe; harbour at its head | Short camp-to-dock walk |
| Crater | Every island (today only temperate_25), inland in the hill zone, >= 0.6 L from the landing | One landmark per island |

### 1.4 Biome zones

**Zone map.** In the existing `_build_tile_types` loop compute per tile: coast distance, river distance, elevation,
slope and a 60-90 m moisture noise. Assign in this order (thresholds in `biomes.json`, shifted by the terrain pick):
coast < 14 m -> beach (or cliff coast if slope > 0.55); river < 12 m or pond -> riverbank; slope > 0.5 or top 15 % of
elevation -> rocky hills; legacy core (home only) -> camp meadow; moisture > 0.62 -> forest; moisture < 0.35 -> dry
upland; else meadow. Mode-filter at 4 m and merge regions under 400 m2, so zones are patches, not speckle. Store
`rt.biome_types` (PackedByteArray, tile-indexed) and write it to the G channel of the tile map (FORMAT_R8 -> RG8,
`island_terrain.gd:318,353`; keep G in `set_tile_type`, `:429`).

**Home island zones (grassland).** Layout for the default pick, south cove harbour; shares are of land area.

| Zone | Share | Ground (grass / patches) | Resource nodes | Creatures | Landmark |
|---|---|---|---|---|---|
| Camp meadow (legacy core, r <= 60 m) | 6 % | #78994f bright green, trampled dirt #7a6248 round buildings, flowers | FibreTuft, BranchPile, BerrySprig, Bush, small Rock | none inside 25 m (world-design §2) | Camp, cove harbour, ford |
| Meadow | 20 % | #7f9f52 yellow-green, flower patches | WildGrass, FibreTuft, BushBerries, HerbPlant, few CommonTree | Compsognathus 2 groups x2 | Lone big tree |
| Birch-oak forest | 25 % | #4f7a3e deep green, leaf litter #5e4a33 at 30 % | CommonTree, BirchTree, TreeStump, WoodLog (fallen logs), Bush, HerbPlant | Compsognathus x2 at the edge | Old grove, 5-6 big crowns |
| Riverbank | 12 % | #5f8a52 lush, mud #5a4632, reed beds | clay (2 groups of 3; world-design §4 lists clay for grassland), ReedPlant (spec 26 reed beds; *ASSUMPTION*), HerbPlant, BushBerries | Zebraceratops x2 drinking | Delta, log bridge prop |
| Rocky hills | 15 % | #7a8460 with rock #7d7b74 on slopes | Rock, GraniteBoulder piles, Rock_Moss | Protoceratops x2 | Cliff terrace, hill source of the river |
| Dry upland | 14 % | #9a9258 golden straw, dirt 15 % | Grass_Short, WildGrass, GraniteBoulder, FibreTuft | Zebraceratops herd x3 | Termite mounds (prop, spec 26) |
| Beach and coast | 8 % | sand #d2bf8f, wet line #a8956a | BranchPile (driftwood), Rock; SaltNode only on the Coastal pick (world-design §7) | none | Rocky peninsula |

- Home creatures: 11 total. **Gallimimus leaves the home** (world-design §7: "none hostile"; it killed the bot twice by
  130 s). Wild animals on home top back up to these counts every 5 min while the player is > 60 m away
  (*ASSUMPTION*: PRD §4.2 regen is disputed; this keeps meat, bone and taming available).
- Home material level by zone (world-design §1 says home is tier 10; `level_override: 1` freezes everything at Lv 1):
  core 1, meadow/beach 1-3, forest/riverbank 3-6, hills/upland 6-10. **Owner check** (economy).
- Terrain pick weights (world-design §7 bonuses): **Meadow** meadow 32 %, forest 15 %; **Forest** forest 40 %, meadow
  10 %; **Rocky** hills 28 % + 2 extra boulder piles; **Riverside** river through the middle (both banks), riverbank 22 %;
  **Coastal** beaches 15 %, aspect 0.70, two coves, SaltNode on the beach.
- Home layout: long axis east-west; shape centre (0, -35) so the south coast sits about 115 m below the origin (land fits the 416 m square
  with >= 20 m of sea on every side) and a 50 m cove brings the dock back to about (0, 62), where it is today. River: east hills -> west coast, passing the old stubs, with
  the old dry gap at |x| < 25 m kept as the ford by camp.

**Zone sets per climate (unstable islands).** Families exist in `nature_manifest.json`; landmarks follow spec 26.

| Climate | Zones (5-6) | Signature nodes by zone | Landmarks |
|---|---|---|---|
| Savannah | golden grassland, river delta, red sandstone mesas, scrub, beach | DryGrassTuft + AcaciaTree / ReedPlant / SandstoneNode, OchreNode / Bush, CommonTree_Dead | mesa cliffs, termite mounds |
| Temperate | mixed forest, willow riverbank, meadow, flint hills, beach | CommonTree, BirchTree, PineTree / Willow, ReedPlant, clay / Flowers, FibreTuft / FlintNode, Rock_Moss | waterfall at the hill river |
| Tropical | jungle, lagoon, obsidian ridge, palm beach | PalmTree, BambooPlant, VinePlant, MangoBush / Lilypad, ReedPlant / ObsidianNode / PalmTree | black crystal ridge |
| Tundra | pine taiga, frozen steppe, ice hills, snowy shore | PineTree(_Snow) / Grass_Short / IceNode, Rock_Snow / Bush_Snow | ice cliffs |
| Desert | dunes, canyon mesas, oasis, salt flats | Cactus, CactusFlowers / SandstoneNode, CopperOreNode / Bush, ReedPlant / SaltNode | canyon, oasis pool |
| Swamp | willow marsh, peat bog, hummock forest, mud shore | Willow, MarshHerbPlant, Lilypad / PeatNode, mud, clay / CommonTree | dead-tree marsh |
| Snowfield | snow forest, glacier rock, wind plain | BirchTree_Snow, PineTree_Snow / SilverOreNode, IceNode / Grass_Short | glacier cliffs |
| Blue tropical | reef lagoon, palm beach, jungle | CoralNode, PearlNode / PalmTree / Plant, VinePlant | reef |
| Volcanic | basalt fields, sulphur vents, ash scrub, hot-spring terraces | BlackIronNode, LavaRockNode / SulphurNode, AshNode / CommonTree_Dead / (visual) | smoking cone, steam vents |

Per-zone densities live in `biomes.json` (`nodes_per_ha` per family, ground-cover set, tree density field). Zones
keep the ring archetype (world-design §2): gathering-ring nodes near the landing, tier-gating nodes (flint, clay, tin,
obsidian, copper) within 60-110 m of the landing camp so the first visit pays off.

### 1.5 Map

- Minimap and atlas share one texture (`hunt_hud.gd:1253-1280`); colour grass/dry tiles by the zone's map colour from
  `biomes.json` (a lighter, flatter version of the ground tint), sand/water/rock as today. The atlas follows by itself
  (`map_screen.gd:325-328`). Prototype: `islands-plan/shots/atlas_base_vs_proto.png`.
- The map shows the true elongated shape and cove; MAPUI (backlog, spec 15/25) adds fog, trail and icons on top of the
  same texture, so this package leaves fog alone.

### 1.6 Save compatibility (no schema bump, no new save key)

- **Legacy core:** within 50 m of the origin the height is the old function (seed 17, old constants, old river carve),
  blended to the new terrain by 70 m; no new ridge, river or cliff inside 75 m. Every old fixture sits there (baskets
  (4,8), (2.5,9.5), spawn (0,12), camp (0,8), dock (0.5,61.5)).
- **Load rescue:** after load, if the player position fails `spawn_ok`, move to the camp (`save_game.gd:255-261` fixes
  only y today). Buildings keep today's re-validate and refund path (`save_restore.gd:30-34,114-124`).
- **Harvest state:** new node ids carry the layout tag, so old `unstable.harvested` entries match nothing (no random
  depleted nodes). Drop `bare_tiles` rows whose node id is unknown at load.
- Claims are absolute tile rects inside the core; unchanged. The harbour already snaps to the nearest legal coast.
- Gate: the scout's old-save lab (`islands-plan/isl_savecompat.gd` + `old_home_save.json`) loads with every building
  kept, every claim dry, the player on dry land, and t_save's v0/v1 fixtures pass.

### 1.7 Performance budget (gl_compatibility; gates for every package)

| Measure | Budget | Today |
|---|---|---|
| Island build, native | <= 2.5 s home, <= 3.0 s unstable | home 0.8-1.4 s, unstable 2.9-3.6 s typical |
| Island build, web (Chrome desktop) | <= 6 s behind the fade, split with awaits if over | not measured |
| HarvestNodes per island | home 450-600, unstable 500-750 | 216 / 210-397 |
| Scene nodes after build | <= 6,000 | 2,036 / 3,549 |
| Ground-cover instances | MultiMesh in 32 m cells, 120 m range, no shadow | 96 / 185 |
| Camp view 1600x900 | visible primitives < 900k, shadow < 3.0M, draws < 450 | home 2.83M total, 315 draws |
| Frame time, web build | p95 <= 16.7 ms desktop Chrome; p95 <= 33 ms at 844x390 with DevTools CPU throttle 4x | not measured |
| Heap per island | <= +90 MB | +24 / +58 MB |
| Creatures | home 11; unstable cap 24 kept, spawned by zone near the player | 8 / 24 |

Work needed to hit it: per-vertex slope and typed packed arrays in `_build_tile_types` (about 5 `surface_y` calls per
tile today) and `TilePath._rebuild` (about 6); skip tiles outside the dry box; build the tile image from a byte array.

---

## 2. Look (ranked by visual impact)

| # | Change | Files | Check |
|---|---|---|---|
| 1 | **Ground painting.** Zone tints from `biomes.json`; per-climate texture sets from W1-BIOME (`claude/mmo-w1-biome`, unmerged: 10 Blender-baked sets, `BiomeMaterial`); macro variation at 41/15/6.5 m as per-zone uniforms; zone id sampled at two noise-warped points for soft edges; bilinear bank mask (no 1 m stair steps). Palettes for the 7 climates without one: | `terrain_tiles.gdshader`, `island_terrain.gd`, `climates.json`, `biomes.json`, `biome_material.gd` | Top-down home atlas: >= 5 zone colours, each >= 4 % of land. Camp and forest shots: ground hue histogram has >= 2 peaks. River bank: no step edge visible at 1:1. Blind A/B vs today on 3 Durango refs + spec 26 concepts: new wins >= 5/6 |
| 2 | **Ground cover** (biggest gap). One island-wide MultiMesh culled at 48 m from the island centre (`island_scatter.gd:307`) becomes 32 m cells like VegBatch; placement retries; per-zone sets of 3-5 wide, low clump cards (grass tuft, fern, flowering weed, leaf litter, dry tuft, reed plume); per-instance tint and scale; density thins with distance instead of switching off; no shadows | `island_scatter.gd:267-314`, new `ground_cover.gd`, `foliage_sway.gdshader`, card art | Lab prints instances within 25 m of the survivor: >= 0.3 per m2 at camp, in forest, and at a point 150 m from the origin; the far count is within +-25 % of the near count. Grass never on desert, tundra, volcanic (vegetation lists) |
| 3 | **Forest structure.** A 40-80 m density field plus the zone map: groves with touching canopy, clearings, meadows. Trees home 40 -> 180-250, as CARD2D cards if adopted; 2+ variants per family with tint/scale jitter; soften the occlusion dither (spec 21) | `island_scatter.gd:73-120`, `nature_manifest.json`, `occlusion.gd` | Top-down canopy mask: forest zone 40-60 % cover, meadow <= 10 %. Camp-zoom frame (17 x 30 m): forest >= 15 trees, meadow 2-5. Perf gates hold |
| 4 | **Light and grade (LIGHT2).** `shadow_opacity` 0.62 and `shadow_blur` 1.6 on both lights (`world_lighting.gd:182`, prototype worked in compat); per-climate ambient colour; mild contrast via `adjustment_*`; top haze and vignette ColorRect under the HUD | `world_lighting.gd`, `lighting.json` | Grass luminance in shade / in sun 0.55-0.75 (today near-black navy). No blown highlights (existing check). Dusk shot reads golden, not brown (judge) |
| 5 | **Coast.** Wet-sand darkening line, two foam bands, beach clutter (driftwood, rocks, shells as cards); sea planes large enough that no square edge shows in play, map or sail views | `water.gdshader`, `island_terrain.gd:239-268` | Shore shot shows the wet line; no sea edge in camp, shore or overview shots |
| 6 | **Camp clutter and claim line.** Logs, planks, stone ring, crates scattered at camp build; claim outline as small stones or a thin dotted line (Durango); varied prop disc sizes | `island_runtime.gd:276-288`, `claim_outline.gd`, `prop_visuals.gd` | Claim line is no longer the loudest shape: its mean contrast to the ground is below the tent's |

Palettes to add (grass / dry / dirt / sand / rock): desert #b9a46a / #c9b07a / #a07a52 / #e0c48e / #9a7a5c; tundra
#8a9a78 / #a6a58a / #6b6052 / #b9b29c / #8a8a88; tropical #3f8f3a / #6f9a45 / #6a4a30 / #e6d3a0 / #6c6a5e; swamp
#4f6a3a / #6a6a40 / #4a3f2c / #8a7d5a / #5c5e52; volcanic #4a4a3c / #5e5648 / #3a3330 / #4c4844 / #2e2c2c; snowfield
#dfe6ea / #c8d0d4 / #8a8478 / #d6d8d6 / #7a7e82; blue_tropical #3e9a5a / #78a85a / #6a5038 / #f0e6c8 / #6e7470. Snow and
sand come from W1-BIOME's own textures, not from tinting a green photo (the scout's tint-only prototype turned tundra ochre).

Not worth spending on: night lighting, fire glow, beach gradient, building models, survivor scale, default zoom.
Phone HUD clutter at 844x390 belongs to PHONEHUD (add: one-line ORDERS chip, 110 px minimap, pills only for the target).

---

## 3. The first hour

### 3.1 What is wrong today (scout B, bot at 5x, human estimate 2.5-4x)

Permanent rain makes the survivor Wet almost always (flat +0.3 fatigue/min, 15/min, so TIRED at 1:25 bot time and forced
sleeps every 3-5 min); Orders step 11 asks to tame a Zebraceratops a club barely scratches (2.1 per hit); the Orders hand
out the work knife (3.8 damage) instead of the Stone Knife (33.7); a building placement pays 38 XP against 2 per gather,
so fence spam is the fastest XP; until today SP had little to buy (SKILLBUY now sells 103 of 213 nodes); stations hold no
state and the BUILD sheet lists only kits in the bag; crafts never fail or surprise (`rare_attribute_chance` read
nowhere); the home runs out of animals and has no clay; Orders after step 11 are "sail to X / reach Survival N"; the first
unstable island offers no new tier and its camp is 190-210 m from the dock.

### 3.2 Target beat sheet (human time; every beat ends with visible feedback)

| Min | Player does | Unlocks | Reward / feedback |
|---|---|---|---|
| 0-2 | Wakes at the cove camp; gathers branches, stones, fibre in the camp meadow (radial, spec 22) | Orders 1-3 | "+4 XP / Gathering +1" toast bottom-left (spec 25 §6); Orders line "+15 XP, +1 T" per step |
| 2-5 | Twists twine, knaps the **Stone Knife** (weapon) and the work axe at the bench | Lv 2 | Level-up flash (LEVELFX); 10 SP; Skills tab pulses on a buyable Gathering node |
| 5-9 | Walks 40-70 m into the birch-oak forest: ground turns deep green, crowns close in; fells logs, picks herbs | first SP buy (gather yield) | Yield bump visible on the next pass ("+1 Log") |
| 9-13 | Crafts and places a **basket**; "Store all" at camp; builds the **stone fire pit** | Lv 3-4 | First-build bonus; bag 0/100 again |
| 13-18 | Hunts compsognathus at the meadow edge; corpse radial (meat, leg bone; leather and teeth locked, need tools; spec 25 §6); cooks a **skewer** with meat + leg bone at 100 % success, sees inherited traits (spec 08, 25 §8) | Butchering/Cooking +1 | Buff icon (gather speed +25 % for 5 min) |
| 18-24 | Builds a **drying rack**, loads hide and meat, walks off; weaves a **net** | passive job (returns in 2 min) | "Rack ready" pip on the minimap and camp |
| 24-30 | Follows the river to the riverbank: washes off Dirty, digs **clay**, cuts reeds; first TIRED around here; sleeps in the tent (manual, 10 s) | crock pot, water well (world-design station table) | Fatigue face resets; Camp Stew recipe lights up |
| 30-38 | Nets and tames a **compsognathus** (stunned at any HP, or HP <= 30 %, spec 09); then a zebraceratops in the dry upland with the net once stunned | Pets 1-2; Survival 6-8 | Pet card; zebraceratops carries cargo, rideable once SADDLES lands |
| 38-45 | Climbs the rocky hills: boulders, protoceratops; sees the river source and cliff; buys a Melee or Construction node | Lv 8-9 | View over the whole island; zone map fills on the minimap |
| 45-52 | Reaches Lv 10 / Survival 10; Orders: "Sail to Savannah 15" with the reason shown (Lv 15 materials, acacia `light` = faster tools, ochre, the crater) | Harbour route | Sail chart node lights (SAILUI) |
| 52-60 | Lands at the savannah landing camp (<= 40 m from the dock); gathers Lv 12-15 acacia and sandstone within 60-110 m; finds the crater (+30 T, fatigue -20, world-design §6); cargo-warps home (2 T) with a warning about unstable goods | Lv 11-12 | First item above Lv 10 crafted at home: "Stone Knife Lv 13" (level = mean of materials, spec 04) |

Hour-one targets: Lv 11-13, 3-5 buildings of 3+ kinds, 2 pets, 4+ SP buys, 2 islands, 0-1 deaths, 1-2 sleeps.

### 3.3 Fixes to get there

**Survival pacing (spec 01, PRD §4.4.1)**
- Wet stops being a flat drain: only heat -20 %, cold +30 %, humidity +30 % (PRD :284). SAVEFIX owns this (its brief names
  Wet); LOOP1 only checks the result.
- Rain: one 2-4 min shower every 10-15 min (*ASSUMPTION*; PRD has no cycle) instead of 18 s every 50-90 s
  (`world_weather.gd:8,43,59-64`).
- Work fatigue from spec 01's coefficients: gathering 0.4 sqrt(workload), crafting 2 sqrt, construction 4 sqrt (workload
  = action seconds). Construction now costs fatigue, which also caps fence spam.

**Onboarding and Orders (spec 03 career guides)**
- Rewrite Orders 1-16 to the beat sheet: each step names one system and pays XP + 1-5 T; completion shows "+XP +T".
  Step 11 becomes "Tame an animal" (any species, hint names the compsognathus), with the zebraceratops as step 13.
- The Orders make the **Stone Knife**; `equipped_weapon()` picks the highest-damage weapon, not the first in the bag
  (`inventory.gd:440-450`).
- Capture rule spec 09 (stunned at any HP, or HP <= 30 %) in `field_tame.gd:15-25` and `capture_system.gd:11-13`. Check
  W2-BREED's branch first; it was scoped to own this rule.

**XP economy (spec 03: scale against difficulty, no repeat exploits)**
- Gather XP = 1 + round(pass seconds) (stone 4, log 4, berries 2), not a flat 2.
- Build XP: first placement of each kit type +30, repeats +8, and the same kit within 10 m of another of its kind within
  60 s pays 0 (*ASSUMPTION*).
- Keep the level curve (Lv 10 = 1,800 XP); retune only if the bot misses 3.4's targets.

**Skills (spec 03, 12, 25 §7)**
- SKILLBUY made 103 nodes buyable. Add the feedback: skill XP toast, skill bar "FULL" at the character-level cap, a pulse
  on the Skills hex when a node is affordable (nothing listens to `skill_changed` today).
- First-hour node menu: at least 2 useful buys per tree the first hour touches (Gathering, Butchering, Cooking, Weapon and
  Tool Crafting, Construction, Survival, Melee) at 1-5 SP each, each with a visible number on use.

**Crafting (spec 04, 08, 25 §8)**
- Success rate from crafting ability (`success = clamp(1 - (shortfall/100)^2, 0, 1)`, spec 04); "if crafting fails,
  materials disappear" (spec 25 §8); flawless chance 5 % with a stat bump.
- Wire `rare_attribute_chance` 0.05 at gather (`harvest_node.gd:333-342`); traits carry into crafts via primary slots.
- Skewer: Food slot (meat) + Tool slot (Long Stick, Stick, Short Stick or a leg bone), result shows inherited traits.

**Building (spec 10, world-design station table)**
- BUILD sheet shows every known blueprint with its cost (greyed when short) and crafts the kit in one step (spec 10 §1).
- Stations hold jobs: drying rack, smoker and crock pot run in the background (8-24 s today, blocking); load, walk away,
  collect. Concurrent jobs by station level (spec 10 §6; 1 job below Lv 20 *ASSUMPTION*).
- Building level = min(mean material level, Construction level), shown on the placed building (spec 10 §2).
- Tent sleep restores more on a Comfort > 0 bed (spec 10 §5), so building better beds has a reason.

**Storage**
- Basket 60 -> 100 slots (spec 05: "basket about 100"); "Store all materials" button when inside the claim; pets with a
  cargo container show it in the pet card (spec 05).

**First unstable island**
- Landing camp (1.2), gating nodes within 60-110 m, one crater per island, a confirm dialog before sailing home with
  unstable goods (today they vanish with a console print), Orders continue to temperate_20 (flint) at Survival 15.

### 3.4 Numbers to tune (data, not code)

| Knob | Today | Target | File |
|---|---|---|---|
| Rain | 18 s every 50-90 s | 2-4 min every 10-15 min | `world_weather.gd` (move to `rules.json`) |
| Wet fatigue | +0.3/min flat | 0, modifiers only | `statuses.json:248` |
| Fatigue at minute 10 / 30 (normal play) | ~75 / forced sleeps | <= 20 / 35-60 (first sleep 24-30 min) | `vitals.gd`, `rules.json` |
| Gather XP | 2 | 1 + pass seconds | `player_actions.gd:168` |
| Build XP | 38 every time | +30 first of kind, +8 repeat | `build_placer.gd:482`, `world.gd:262` |
| Orders reward | text only | 15-150 XP + 1-5 T per step | `objectives.json` |
| Level at minute 10 / 30 / 60 | 4 / ~9 / ~16 (bot); human ~2 / ~6 / ~10 | 4-5 / 8 / 11-13 (human) | XP knobs above |
| Basket | 60 | 100 | `items.json` |
| Home creatures, respawn | 8, none | 11, top-up every 5 min when > 60 m away | `home_grassland.json`, `spawner.gd` |
| Craft success / flawless / rare trait | 100 % / none / none | spec 04 curve / 5 % / 5 % | `rules.json`, `crafting.gd` |
| Gather pass seconds | 1.1-3.0 | unchanged | |

---

## 4. Build packages (in order)

Running jobs this plan builds on, never duplicates: **CARD2D** (resource cards; owns the card bake, `card_prop`, the
`resource_render` flag), **SADDLES** (mounts), **SAVEFIX** (Wet drain, autosave, max HP), **CLAIMFIX** (CLAIM re-press,
placer ghost), **SKILLBUY** (merged). Also queued: W2-GATHER, W2-PROCESS, W2-BUILDSYS, ECON (finish-6), GUIDE, LEVELFX,
PHONEHUD, WEBPACK, MAPUI. Every package passes the TODO.md merge gates (all `t_*.gd`, run_all `[tests] PASS`, smoke,
windowed shots at 1600x900 and 844x390 looked at, motion gate) plus the gate below. DeepSeek verify scripts live in
`scratchpad/dsc/verify_<key>.sh` and exit 0 only when every line passes.

**P1 GROUNDFIX (DeepSeek, half a day, starts now).** Quick visible wins with no generator change.
- Scope: ground cover into 32 m cells with a 120 m range and placement retries; remove the 48 m whole-island cull
  (`island_scatter.gd:241,284-307`); no grass where the climate's vegetation lacks Grass; `shadow_opacity` 0.62 /
  `shadow_blur` 1.6 (`world_lighting.gd:182`); the 7 missing climate palettes (`climates.json`).
- Files: `island_scatter.gd`, `veg_batch.gd`, `world_lighting.gd`, `climates.json`, a `--probe=groundcover` in island_lab.
- Depends on: nothing; rebase onto CARD2D's scatter hunk if CARD2D merges first.
- Verify: island_lab prints `[groundcover] near=<n> far=<n>` at camp and at 150 m (far >= 0.75 near, near >= 3x
  today's); t_data checks a palette for all 10 climates; island_lab nodes unchanged (397/24); camp gate visible
  primitives < 900k, shadow < 3.0M; shots before/after.

**P2 BIOMEBASE (Claude, half a day).** Land W1-BIOME as the base for zones.
- Scope: rebase `claude/mmo-w1-biome`, hook `BiomeMaterial.apply_terrain` in `_terrain_material()`, move its
  `biomes.json` from per-climate rows to per-climate + zone rows (schema only, values in P4). Pack size: 10 texture sets
  are about 28 MB on a pack already at 255 MB against 220 MB; ship only the climates in use or 512 px sets until WEBPACK
  lands.
- Gate: t_biome PASS, biome_lab 10 patches distinct, camp ground blind A/B vs today >= 5/6, pack delta <= +12 MB.

**P3 ISLANDGEN (Claude core, DeepSeek consumers; 2-3 days).** Sections 1.1-1.3, 1.6, 1.7.
- Claude writes `island_shape.gd` (eff_rad precompute, seed, cove, peninsulas, features: hills, cliffs, river polyline,
  pond, crater) and the legacy core. DeepSeek, in a sub-worktree, fixes consumers (TilePath bbox, scatter windows, spawn
  clamp, rings from the landing, camp at landing, harbour hints, t_harbour JSON check, load rescue, bare_tiles drop) and
  the perf items (packed arrays, per-vertex slope, async split).
- Files: `island_terrain.gd`, `island_runtime.gd`, new `island_shape.gd`, `tile_path.gd`, `island_spawns.gd`,
  `harbour_site.gd`, `save_game.gd`, `save_restore.gd`, `data/islands/*.json`, `rules.json`, `t_harbour.gd`, new
  `dev/island_shape_lab.gd` + `t_islandshape.gd`.
- Depends on: P1 merged (same scatter file). Do not wait for the finish-6 chain; none of its packages touch these files
  except W2-BUILDSYS's `build_grid.gd` call to `spawn_ok` (signature unchanged).
- Verify: `[islandshape] PASS` per island with land size within +-10 % of 1.1, aspect 0.70-0.90, P/sqrt(A) 4.4-5.5,
  solidity 0.80-0.92, >= 12 of 15 distinct heightmaps, river connected hill-to-sea, camp-to-dock <= 40 m (home <= 70 m),
  0 dry tiles outside the TilePath grid; old-save lab passes (1.6); t_save, t_harbour, t_water, t_build PASS; build time
  and heap within 1.7; top-down shots of home and 3 climates.

**P4 BIOMES (Claude; 2 days).** Section 1.4-1.5 and look item 1.
- Scope: zone map + RG8 tile map + shader zone palette and warped edges; per-zone scatter weights and density field;
  home zones and terrain-pick weights; per-zone creature spawns, home top-up, gallimimus off home; home zone levels
  (after the owner's yes); clay and reeds on the home riverbank; map colours; one crater per island.
- Files: `island_terrain.gd` (tile loop), `terrain_tiles.gdshader`, `biomes.json`, `island_scatter.gd`,
  `home_grassland.json`, `islands.json`, `spawner.gd`, `island_spawns.gd`, `hunt_hud.gd` (map texture only).
- Depends on: P2, P3.
- Gate: per island the lab prints zone shares (each listed zone >= 4 %) and nodes per zone per ha; home: 5 terrain picks
  give 5 different zone mixes (largest zone differs as 1.4 says), clay >= 6 nodes, 11 creatures; new recorded baseline
  replaces "nodes=397 creatures=24" in STATUS; atlas shot shows the zones; look item 1 checks; t_biome extended.

**P5 COVERCARDS (after the owner's CARD2D verdict; DeepSeek system, Claude art direction; 2 days).** Look items 2-3.
- Scope: per-zone ground-cover card sets (wide, low clumps, painted look; not the baked low-poly GLBs), forest density
  field, tree counts 180-250 home, variants and tint jitter, softer occlusion dither.
- Art: card images need a source the owner approves (generated images or a pack download both need the owner's yes).
- Depends on: CARD2D adopted (`resource_render: "card"`), P4.
- Gate: look items 2-3 checks; perf budget at camp and in the densest forest at both resolutions on the web build.

**P6 LOOP1 (DeepSeek, data plus small code; 1-2 days; can run beside P3).** Section 3.3 survival pacing, onboarding,
XP economy, storage, first unstable island; 3.4 knobs.
- Files: `objectives.json`, `world_weather.gd`, `rules.json`, `player_actions.gd`, `build_placer.gd`, `world.gd`,
  `inventory.gd`, `items.json`, `field_tame.gd`, `capture_system.gd` (only if W2-BREED did not), store-all in
  `hunt_hud.gd`/camp storage.
- Depends on: SAVEFIX merged (Wet), CLAIMFIX merged (both touch the HUD and vitals).
- Verify: a new `--bot-metrics=<json>` on `bot_survivor.gd` writing per game-minute level, XP, fatigue, Orders step,
  deaths, buildings by kind, pets, SP spent; verify script runs 30 game-minutes at 5x windowed and asserts minute 10:
  Lv >= 4, fatigue <= 30, Orders >= step 8; minute 30: Lv >= 8, pets >= 1, buildings >= 3 kinds, deaths <= 1; build XP
  share of total <= 35 %.

**P7 CRAFTFEEL (Claude design, DeepSeek build; 2 days).** Section 3.3 crafting and skills feedback.
- Scope: success rate, failure loses materials, flawless, rare traits at gather and through primary slots, skewer
  Food + Tool slots with trait preview, skill XP toasts, FULL bar at the cap, Skills hex pulse, first-hour node menu.
- Depends on: W2-GATHER and W2-PROCESS merged (they own gather stacks and processing); LEVELFX for the flash.
- Gate: `t_craftfeel.gd` (same preview and result numbers, spec 04 example 40/50/60 -> 50, five-Firm average example,
  fail removes inputs, rare rate within 3-7 % over 2,000 gathers); shots of the skewer screen vs `durango-craft-skewer.webp`.

**P8 STATIONS (Claude; 2 days).** Section 3.3 building.
- Scope: blueprint catalog in BUILD with costs and one-step kit craft; station job queues that run while you walk away,
  saved; building level from materials and Construction level; Comfort feeding sleep; basket 100.
- Depends on: W2-BUILDSYS merged (it owns structures.json and the modular placer); build on it, do not fork.
- Gate: `t_stations.gd` (a job finishes while the player is 100 m away, survives save/load, never duplicates output;
  building level = spec 10 §2 table rows); bot metrics show >= 3 building kinds by minute 30.

**P9 LOOPCHECK (Claude; 1 day, then repeat after tuning).**
- Scope: 60 game-minute bot run with metrics, a scripted first-hour playthrough with shots every 2 min at 1600x900 and
  844x390, and a tuning pass on 3.4's knobs only.
- Gate: section 3.2's hour-one targets met by the bot at human pace (bot x 2.5); fatigue curve and level curve plotted;
  a blind judge picks the new first 10 minutes over today's from shot sequences; perf budget on the web build.

Order: P1 -> P2 -> P3 -> P4 -> P5 for the islands; P6 in parallel with P3; P7 and P8 when finish-6 lands; P9 last.

### Owner questions (one message)
1. Home material levels by zone (1-10, world-design tier 10) instead of `level_override: 1`? It raises home-made item levels.
2. Ground-cover card art source: generated images, or a downloaded pack? Either needs your yes.
3. Home wild animals top back up every 5 minutes when you are away from them (the PRD leaves home regen open)?
