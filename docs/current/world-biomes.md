# World — islands, biomes, flora & fauna

> Generated 2026-10-27 by `tools/docs_wiki/gen_game_data.py` from the build's own data. Never hand-edit; re-run after any balance pass.

Sources: `game/data/islands/*.json`, `game/data/world/climates.json`, `game/data/world/rules.json` (weather), `game/data/creatures/*.json`, `game/data/butchering.json`.

## Island roster (15)

| island | name | climate | tier | kind | permanent | lifetime (s) |
|---|---|---|---|---|---|---|
| `desert_35` | Unstable Desert | desert | 35 | unstable |  |  |
| `desert_50` | Unstable Desert | desert | 50 | unstable |  |  |
| `home_grassland` | Private Grassland | grassland | 10 | private | True | 0 |
| `savannah_15` | Unstable Savannah | savannah | 15 | unstable |  |  |
| `savannah_45` | Unstable Savannah | savannah | 45 | unstable |  |  |
| `swamp_55` | Unstable Swamp | swamp | 55 | unstable |  |  |
| `temperate_20` | Unstable Temperate | temperate | 20 | unstable |  |  |
| `temperate_25` | Unstable Temperate | temperate | 25 | unstable | False | 7200 |
| `temperate_35` | Unstable Temperate | temperate | 35 | unstable |  |  |
| `temperate_45` | Unstable Temperate | temperate | 45 | unstable |  |  |
| `tropical_25` | Unstable Tropical | tropical | 25 | unstable |  |  |
| `tropical_40` | Unstable Tropical | tropical | 40 | unstable |  |  |
| `tundra_30` | Unstable Tundra | tundra | 30 | unstable |  |  |
| `tundra_55` | Unstable Tundra | tundra | 55 | unstable |  |  |
| `volcanic_60` | Unstable Volcanic | volcanic | 60 | unstable |  |  |

## Climates — flora & gatherable materials

### blue_tropical — tiers L55

- Survival resist needed: `heat_high`, `humidity`.
- Vegetation families: `PalmTree`, `Plant`, `Lilypad`, `Rock`, `Grass`, `WildGrass`, `CoralNode`, `PearlNode`.
- Gatherable materials (yellow-pip latent attr when noted): `pearl`, `coral` *(attr: hard)*, `palm_frond`, `blue_dye`, `coconut` *(attr: water)*.

### desert — tiers L35, L50

- Survival resist needed: `heat_high`, `sun`.
- Vegetation families: `Cactus`, `CactusFlowers`, `CactusFlower`, `Rock`, `CommonTree_Dead`, `WildGrass`, `CopperOreNode`, `SaltNode`, `SandstoneNode`.
- Gatherable materials (yellow-pip latent attr when noted): `cactus_flesh` *(attr: water)*, `cactus_spine` *(attr: needle)*, `sandstone`, `copper_ore`, `salt`, `stone`.

### grassland — tiers L10 — **the private home island**

- Vegetation families: `CommonTree`, `BirchTree`, `Bush`, `BushBerries`, `Grass`, `Grass_Short`, `Flowers`, `Rock`, `WoodLog`, `TreeStump`, `WildGrass`, `GraniteBoulder`, `HerbPlant`, `FibreTuft`, `BranchPile`, `BerrySprig`, `Corn`.
- Gatherable materials (yellow-pip latent attr when noted): `fibre_stalk`, `branch`, `wood_log`, `stone`, `herb_leaf`, `berries`, `clay`, `corn`.

### savannah — tiers L15, L45

- Survival resist needed: `heat_weak`.
- Vegetation families: `CommonTree_Dead`, `Grass`, `Grass_Short`, `Rock`, `Bush`, `TreeStump`, `WildGrass`, `AcaciaTree`, `SandstoneNode`, `OchreNode`, `FlaxPlant`, `DryGrassTuft`, `BranchPile`.
- Gatherable materials (yellow-pip latent attr when noted): `dry_grass` *(attr: dry)*, `acacia_wood` *(attr: light)*, `sandstone`, `ochre`, `branch`, `stone`.

### snowfield — tiers L50, L60

- Survival resist needed: `cold_high`, `wind`.
- Vegetation families: `PineTree_Snow`, `BirchTree_Snow`, `Willow_Snow`, `Rock_Snow`, `Bush_Snow`, `CommonTree_Dead_Snow`, `WildGrass`, `IceNode`, `SilverOreNode`.
- Gatherable materials (yellow-pip latent attr when noted): `ice`, `snow_pine` *(attr: resinous)*, `silver_ore`, `stone`.

### swamp — tiers L45, L55, L60

- Survival resist needed: `heat_weak`, `humidity`.
- Vegetation families: `Willow`, `Willow_Dead`, `Lilypad`, `Plant`, `Grass`, `Rock_Moss`, `WoodLog_Moss`, `WildGrass`, `PeatNode`, `ReedPlant`, `MarshHerbPlant`.
- Gatherable materials (yellow-pip latent attr when noted): `reed`, `willow_wood` *(attr: pliant)*, `peat`, `clay`, `marsh_herb` *(attr: medicinal)*, `leech`.

### temperate — tiers L20, L35

- Survival resist needed: `cold_weak`.
- Vegetation families: `CommonTree`, `BirchTree`, `Willow`, `PineTree`, `Bush`, `BushBerries`, `Grass`, `Plant`, `Flowers`, `Rock_Moss`, `Rock`, `WoodLog_Moss`, `TreeStump_Moss`, `WildGrass`, `FlintNode`, `GraniteBoulder`, `FlaxPlant`, `ReedPlant`, `HerbPlant`, `FibreTuft`, `BranchPile`, `BerrySprig`, `TinOreNode`, `Wheat`.
- Gatherable materials (yellow-pip latent attr when noted): `fibre_stalk`, `herb_leaf`, `branch`, `wood_log` *(attr: straight)*, `reed`, `flint`, `clay`, `berries`, `stone`, `tin_ore`, `wheat`.

### tropical — tiers L25, L40

- Survival resist needed: `heat_high`.
- Vegetation families: `PalmTree`, `Plant`, `Grass`, `Bush`, `Rock_Moss`, `Lilypad`, `WildGrass`, `ObsidianNode`, `BambooPlant`, `MangoBush`, `VinePlant`.
- Gatherable materials (yellow-pip latent attr when noted): `palm_frond`, `coconut` *(attr: water)*, `bamboo` *(attr: flexible)*, `mango`, `vine`, `obsidian` *(attr: hard)*, `stone`.

### tundra — tiers L30, L40, L55

- Survival resist needed: `cold_high`.
- Vegetation families: `PineTree`, `PineTree_Snow`, `Bush_Snow`, `Rock_Snow`, `Grass_Short`, `WoodLog_Snow`, `WildGrass`, `IceNode`, `TinOreNode`.
- Gatherable materials (yellow-pip latent attr when noted): `pine_log` *(attr: resinous)*, `resin`, `ice`, `bone`, `stone`, `branch`, `tin_ore`.

### volcanic — tiers L60

- Survival resist needed: `heat_volcanic`.
- Vegetation families: `Rock`, `CommonTree_Dead`, `Rock_Snow`, `WildGrass`, `BlackIronNode`, `SulphurNode`, `LavaRockNode`, `AshNode`.
- Gatherable materials (yellow-pip latent attr when noted): `black_iron` *(attr: hard)*, `lava`, `sulphur`, `ash`.

A climate's `materials` list is what its island generator may place; gather yields per family are the gather-system's own table (`world/rules.json`).

## Weather

Code: `game/scripts/world/world_weather.gd` (state), `game/scripts/world/weather_fx.gd` (screen layer, light pulse, camera shake), `game/shaders/weather/`. Numbers: `game/data/world/rules.json` `weather`. Test: `game/tests/t_weather.gd`; lab: `scenes/dev/weather_lab.tscn`.

- **Rain**: every 50.0-90.0 s (first check 40.0 s) the island rolls its climate's rain chance; a spell lasts 18.0-30.0 s, applies Wet, dims the sun by up to half and lays a grey wash.
- **Storm** (rain and lightning): a rain spell is a storm on the climate's storm roll and lasts 30.0-45.0 s. A strike every 8.0-20.0 s, 400.0-3000.0 m away: a double flicker of the screen and the sun (the moon at night), then thunder distance / 343.0 m/s later (1.2-8.7 s) with a camera rumble up to 0.12 m. `WorldWeather.lightning` / `thunder` are the sound hooks (no audio yet).
- **Heat** (by day where the climate asks for heat resistance): an orange screen edge in the combat red edge's style, a warm wash, a heat shimmer (high quality) and a slow sway up to 0.012 m.
- **Cold** (any hour where it asks for cold resistance): a blue-white edge, frost creeping in from the borders (corners first) and a shiver (0.05 m) on getting cold, on defrosting, and every 14.0-28.0 s while cold.
- **Strength**: severity = resistance need / 3 (0.4-1) x (0.4 + 0.6 x unmet share); the unmet share counts while climate fatigue charges it (heat by day, cold otherwise). Wet and Quenched cool the heat, sitting by a fire warms the cold.
- **Screen rules**: the layer is canvas layer -1, under every HUD layer, so HUD rects and the combat red edge draw over it; during a hunt or a red-edge status the weather edges drop to 35 %. Weather shake never exceeds 0.15 m; `--reduce-shake` turns off every camera shake (combat too).
- **Idle by mood**: standing still, the survivor plays `idle_exhausted` (fatigue 75 %+) > `idle_cold` / `idle_heat` (weather feel 0.5+, the stronger) > `idle_tired` (50 %+) > `idle`, each only when its clip exists in `assets/characters/survivor/anim/` (the next in line otherwise), blended over 0.5 s; moving and busy clips win (`PlayerAnim.pick_idle`).
- **Debug**: `--weather=clear|rain|storm|heat|cold` holds a state; `--weather-quality=low|high` (low drops the shimmer; default low on iOS / Android).

| climate | rain chance per check | storm share of spells | heat look by day | cold look |
|---|---|---|---|---|
| blue_tropical | 1.0 | 0.5 | 0.40-1.00 | - |
| desert | 0 | 0 | 0.40-1.00 | - |
| grassland | 1.0 | 0.15 | - | - |
| savannah | 0 | 0 | 0.16-0.40 | - |
| snowfield | 0 | 0 | - | 0.40-1.00 |
| swamp | 1.0 | 0.25 | 0.27-0.67 | - |
| temperate | 1.0 | 0.2 | - | 0.16-0.40 |
| tropical | 1.0 | 0.45 | 0.27-0.67 | - |
| tundra | 0 | 0 | - | 0.27-0.67 |
| volcanic | 0 | 0 | 0.40-1.00 | - |

The look columns run from fully resisted to fully unmet.

## Claimed land is clear of scenery

A domain cell (spec 29) is bare of decoration the moment it is staked, and stays that way:

- **Props go.** Claiming or expanding removes every scenery prop whose footprint overlaps the new
  cells — fallen logs, tree stumps, boulders, reeds, clutter cards, and even a cliff/mesa that an attack
  cannot clear (a claim is not an attack). The sweep is `IslandClaims.clean_claimed()` →
  `IslandProps.clear_claimed()`; the props layer also refuses to place a prop on a claimed tile or with
  a footprint reaching in (`IslandProps._claimed_footprint`).
- **Resources stay.** Trees, rocks, bushes and plants that really can be gathered remain on owned land:
  spec 29 gives the owner the right to build and manage, not a stripped plot. A "harvest node" with no
  valid gather option is a prop and is removed with the rest.
- **Grass stays off.** Grass families and the ground-cover instances are cleared separately
  (`IslandClaims._clear_grass_cells`, `GroundCover`), and never scattered back on a claim.
- **Loads and rebuilds match.** A save stores only the domain cells, never the absence of props; the
  domain is restored before the props regenerate from the island seed, so a reloaded island has no
  scenery inside its claims and nothing regrows there later. No save-format change.

## Fauna (19 species)

| tier | species | climate | clade | period | length (m) |
|---|---|---|---|---|---|
| 13 | **Zebraceratops** | grassland | Ceratopsia | Durango original (fictional) | 4.3 |
| 15 | **Compsognathus** | savannah | Compsognathidae | Late Jurassic | 3.0 |
| 18 | **Coelophysis** | savannah | Coelophysoidea | Late Triassic | 6.0 |
| 20 | **Protoceratops** | temperate | Ceratopsia | Late Cretaceous | 4.0 |
| 25 | **Velociraptor** | temperate | Dromaeosauridae | Late Cretaceous | 6.0 |
| 30 | **Gallimimus** | desert | Ornithomimidae | Late Cretaceous | 12.0 |
| 30 | **Megaloceros** | tundra | Cervidae | Pleistocene | 3.0 |
| 35 | **Deinonychus** | tropical | Dromaeosauridae | Early Cretaceous | 10.2 |
| 40 | **Dilophosaurus** | tropical | Neotheropoda | Early Jurassic | 12.0 |
| 45 | **Smilodon** | tundra | Machairodontinae | Pleistocene | 2.5 |
| 45 | **Stegosaurus** | temperate | Stegosauridae | Late Jurassic | 18.0 |
| 45 | **Styracosaurus** | savannah | Ceratopsia | Late Cretaceous | 11.0 |
| 50 | **Allosaurus** | desert | Allosauridae | Late Jurassic | 18.0 |
| 50 | **Ankylosaurus** | desert | Ankylosauridae | Late Cretaceous | 16.0 |
| 50 | **Utahraptor** | desert | Dromaeosauridae | Early Cretaceous | 11.0 |
| 55 | **Triceratops** | swamp | Ceratopsia | Late Cretaceous | 18.0 |
| 60 | **Brachiosaurus** | any | Brachiosauridae | Late Jurassic | 44.0 |
| 60 | **Tarbosaurus** | tundra | Tyrannosauridae | Late Cretaceous | 20.0 |
| 60 | **Tyrannosaurus rex** | volcanic | Tyrannosauridae | Late Cretaceous | 24.0 |

## Butchering: choosing what to cut

A kill leaves a carcass. Tapping it opens the **part picker** (`game/scripts/ui/butcher_picker.gd`): one 64 px hex per part that species offers, its icon, the seconds the cut takes, how many units are still on the carcass, and a red reason under any part that cannot be cut now. The "Loot chest" button on the picker opens the older chest screen (bag on the left, carcass on the right, Take all), so old muscle memory still works.

Picking a part starts a timed cut (1.6 s, the gathering ring runs over the carcass). The survivor must stay in reach; walking away or cancel takes nothing and spends nothing. A finished cut hands over **only that part** — the other parts stay on the carcass:

- **Cut budget** — `1 + floor(Butchering level / 10)` cuts per carcass (Lv1 → 1, Lv10 → 2, Lv30 → 4, Lv60 → 7). When it runs out the carcass is spent; the parts never cut are lost (`# ASSUMPTION`, the spec is silent on carcass size).
- **Yield** — the shipped scaling per cut: the part's `base` rows count, +15% per knife tier above stone, 0.75x with no knife, never below 1, plus +1% per Butchering level.
- **Rare parts** — one rare roll per chosen part, at that part's `rare` row odds (default 0.12, +15% per knife tier, cap 0.6) and only once its butcher skill node is learned.
- **Blocked parts** — a part gated by a Butchering skill node, a part already cut, a carcass with no cuts left, or spoiled meat from a poisonous species reads its reason on the hex.
- **Saves** — the carcass's species, its cuts left and which parts were cut round-trip through save/load (`docs/current/saves-persistence.md`); loading into a scene respawns the carcass with that state.

Numbers: `game/data/loot_tables.json` `butcher`; code: `game/scripts/gather/carcass_parts.gd` (`CarcassParts.parts/cut_budget/cut`), `game/scripts/creatures/corpse.gd` (the cut in flight), `game/scripts/gather/loot_roller.gd` (`roll_part`). Test: `game/tests/t_butcher.gd`.

`base` rows fall on a cut of that part and `rare` rows need butcher skill at least the listed level.

## Butchering drops per species

- **Zebraceratops** — base: `raptor_meat` 2–3; `raptor_bone` 2–3; `raw_hide` 1–2; `dense_bone` 1–2; `armor_scute` 1–1; rare: `raptor_bone` 1–1 (skill 1)
- **Compsognathus** — base: `raw_meat` 2–4; `bone` 1–2; `raw_hide` 1–1; `predator_tendon` 1–2; rare: 
- **Coelophysis** — base: `raw_meat` 2–4; `bone` 1–2; `raw_hide` 1–1; `predator_tendon` 1–2; rare: 
- **Protoceratops** — base: `raptor_meat` 3–4; `raptor_bone` 2–3; `raw_hide` 1–2; `dense_bone` 1–2; `armor_scute` 1–1; rare: `raptor_bone` 1–1 (skill 1)
- **Velociraptor** — base: `raptor_meat` 2–3; `raptor_bone` 1–2; `raptor_hide` 1–1; `predator_tendon` 1–2; rare: `raptor_talon` 1–1 (skill 1)
- **Gallimimus** — base: `raw_meat` 4–7; `bone` 2–3; `raw_hide` 1–2; rare: 
- **Megaloceros** — base: `raw_meat` 2–4; `bone` 1–2; `raw_hide` 1–1; rare: 
- **Deinonychus** — base: `raptor_meat` 2–4; `raptor_bone` 1–2; `raptor_hide` 1–1; `predator_tendon` 1–2; rare: `raptor_talon` 1–1 (skill 1)
- **Dilophosaurus** — base: `raw_meat` 4–7; `bone` 2–3; `raw_hide` 1–2; `venom_gland` 1–2; rare: 
- **Smilodon** — base: `raw_meat` 2–4; `bone` 1–2; `raw_hide` 1–1; `predator_tendon` 1–2; rare: 
- **Stegosaurus** — base: `raw_meat` 8–14; `bone` 3–5; `raw_hide` 2–4; `dense_bone` 1–2; `armor_scute` 1–1; rare: 
- **Styracosaurus** — base: `raw_meat` 4–7; `bone` 2–3; `raw_hide` 1–2; `dense_bone` 1–2; `armor_scute` 1–1; rare: 
- **Allosaurus** — base: `raw_meat` 8–14; `bone` 3–5; `raw_hide` 2–4; `predator_tendon` 1–2; rare: 
- **Ankylosaurus** — base: `raw_meat` 8–14; `bone` 3–5; `raw_hide` 2–4; `dense_bone` 1–2; `armor_scute` 1–1; rare: 
- **Utahraptor** — base: `raptor_meat` 3–5; `raptor_bone` 2–3; `raptor_hide` 1–2; `predator_tendon` 1–2; rare: `raptor_talon` 1–1 (skill 2)
- **Triceratops** — base: `raw_meat` 8–14; `bone` 3–5; `raw_hide` 2–4; `dense_bone` 1–2; `armor_scute` 1–1; rare: 
- **Brachiosaurus** — base: `raw_meat` 8–14; `bone` 3–5; `raw_hide` 2–4; `dense_bone` 1–2; `armor_scute` 1–1; rare: 
- **Tarbosaurus** — base: `raw_meat` 8–14; `bone` 3–5; `raw_hide` 2–4; `dense_bone` 1–2; `armor_scute` 1–1; rare: 
- **Tyrannosaurus rex** — base: `raw_meat` 8–14; `bone` 3–5; `raw_hide` 2–4; `dense_bone` 1–2; `armor_scute` 1–1; rare: 

