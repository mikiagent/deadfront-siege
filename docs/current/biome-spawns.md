# Biome spawns — what lives where

> Generated 2026-10-30 by `tools/docs_wiki/gen_game_data.py` from the build's own data. Never hand-edit; re-run after any balance pass.

Which creatures can spawn on each island, grouped by biome (the island's climate). Built from `game/data/world/islands.json` (unstable-isle templates and their ring spawns), `game/data/islands/*.json` (fixed spots, overrides, tutorial `wild_zones`), `game/data/world/rules.json` (rings), `game/data/creatures/*.json` and the models under `game/assets/creatures/`. Rerolled unstable isles reuse their template's spawn table.

How to read it:

- **status**: `in game` means the species has a model (`assets/creatures/<id>/<id>.glb`). A species without one never spawns (NOBOXES, `CreatureDef.eligible`): its row spawns the next species in the same table that has a model, else the first one on the island that has a model. The status column names what spawns instead.
- **level**: the spawning species' tier + the ring's `level_offset` + the row's `tier_offset`, clamped to 1-60 (`Creature._spawn_level`). An island with `level_override` spawns everything at that level. A fixed spot's ring depends on its position, so it shows the full ring span.
- **count × groups, chance**: animals per group, groups per row, and the chance each group appears.
- **alpha**: each group rolls 8% once; on a hit its first member is an alpha (`ai.json` `alpha.chance_per_group`). Islands with `no_alphas` never roll.
- **tameable**: the written species' `tameable` flag. At most 24 creatures spawn per island (`Game.max_creatures_per_island`), so late rows on a crowded island can be cut.

**Models:** 14 of 20 species have one. No model yet: Allosaurus (`allosaurus`), Brachiosaurus (`brachiosaurus`), Dilophosaurus (`dilophosaurus`), Smilodon (`smilodon`), Tarbosaurus (`tarbosaurus`). Retired (model removed, never spawns): Protoceratops (`protoceratops`).

## Grassland

Islands: `home_grassland` (L10, private), `tutorial_isle` (L15, tutorial).

| species | islands | level | groups | tameable | status |
|---|---|---|---|---|---|
| **Zebraceratops** (`zebraceratops`) | `home_grassland`, `tutorial_isle` | L1 | 5 | yes | in game |
| **Compsognathus** (`compsognathus`) | `home_grassland`, `tutorial_isle` | L1 | 9 | yes | in game |
| **Protoceratops** (`protoceratops`) | `home_grassland` | L1 | 1 | yes | retired: spawns fall through to gallimimus |
| **Gallimimus** (`gallimimus`) | `home_grassland` | L1 | 1 | yes | in game |

### `home_grassland` (L10, private)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| fixed spot | Compsognathus | 1 × 1 | 100% | L1 | 8%/group | yes | in game |
| fixed spot | Protoceratops | 1 × 1 | 100% | L1 | 8%/group | yes | retired: spawns fall through to gallimimus |
| fixed spot | Gallimimus | 1 × 1 | 100% | L1 | 8%/group | yes | in game |
| gathering | Compsognathus | 2 × 1 | 100% | L1 | 8%/group | yes | in game |
| gathering | Zebraceratops | 3 × 1 | 100% | L1 | 8%/group | yes | in game |

### `tutorial_isle` (L15, tutorial)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| zone 40 m | Compsognathus | 1 × 1 | 100% | L1 | never | yes | in game |
| zone 45 m | Compsognathus | 1 × 1 | 100% | L1 | never | yes | in game |
| zone 60 m | Compsognathus | 1 × 1 | 100% | L1 | never | yes | in game |
| zone 120 m | Zebraceratops | 3 × 1 | 100% | L1 | never | yes | in game |
| zone 160 m | Compsognathus | 2 × 1 | 100% | L1 | never | yes | in game |
| zone 170 m | Zebraceratops | 2 × 1 | 100% | L1 | never | yes | in game |
| zone 200 m | Compsognathus | 2 × 1 | 100% | L1 | never | yes | in game |
| zone 240 m | Zebraceratops | 3 × 1 | 100% | L1 | never | yes | in game |
| zone 280 m | Compsognathus | 3 × 1 | 100% | L1 | never | yes | in game |
| zone 320 m | Compsognathus | 2 × 1 | 100% | L1 | never | yes | in game |
| zone 360 m | Zebraceratops | 3 × 1 | 100% | L1 | never | yes | in game |

## Savannah

Islands: `savannah_15` (L15, unstable), `savannah_45` (L45, unstable).

| species | islands | level | groups | tameable | status |
|---|---|---|---|---|---|
| **Zebraceratops** (`zebraceratops`) | `savannah_15` | L8 | 1 | yes | in game |
| **Compsognathus** (`compsognathus`) | `savannah_15` | L10 | 2 | yes | in game |
| **Coelophysis** (`coelophysis`) | `savannah_15`, `savannah_45` | L13-28 | 5 | yes | in game |
| **Protoceratops** (`protoceratops`) | `savannah_15` | L18 | 1 | yes | retired: spawns fall through to coelophysis |
| **Deinonychus** (`deinonychus`) | `savannah_45` | L35 | 1 | yes | in game |
| **Styracosaurus** (`styracosaurus`) | `savannah_45` | L45-53 | 2 | yes | in game |
| **Utahraptor** (`utahraptor`) | `savannah_45` | L55 | 1 | yes | in game |

### `savannah_15` (L15, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Compsognathus | 6 × 2 | 100% | L10 | 8%/group | yes | in game |
| gathering | Zebraceratops | 3 × 1 | 100% | L8 | 8%/group | yes | in game |
| working | Coelophysis | 4 × 2 | 100% | L18 | 8%/group | yes | in game |
| working | Protoceratops | 3 × 1 | 100% | L18 | 8%/group | yes | retired: spawns fall through to coelophysis |
| crater | Coelophysis | 5 × 1 | 100% | L26 | 8%/group | yes | in game |
| far_shore | Coelophysis | 1 × 1 | 100% | L28 | 8%/group | yes | in game |

### `savannah_45` (L45, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Coelophysis | 4 × 1 | 100% | L13 | 8%/group | yes | in game |
| working | Styracosaurus | 3 × 1 | 100% | L45 | 8%/group | yes | in game |
| working | Deinonychus | 3 × 1 | 100% | L35 | 8%/group | yes | in game |
| crater | Styracosaurus | 4 × 1 | 100% | L53 | 8%/group | yes | in game |
| far_shore | Utahraptor | 2 × 1 | 100% | L55 | 8%/group | yes | in game |

## Temperate

Islands: `temperate_20` (L20, unstable), `temperate_25` (L25, unstable), `temperate_35` (L35, unstable), `temperate_45` (L45, unstable).

| species | islands | level | groups | tameable | status |
|---|---|---|---|---|---|
| **Compsognathus** (`compsognathus`) | `temperate_20`, `temperate_25` | L10 | 2 | yes | in game |
| **Coelophysis** (`coelophysis`) | `temperate_20` | L18 | 1 | yes | in game |
| **Protoceratops** (`protoceratops`) | `temperate_20`, `temperate_25` | L10-23 | 3 | yes | retired: spawns fall through to compsognathus |
| **Velociraptor** (`velociraptor`) | `temperate_20`, `temperate_25` | L25-33 | 5 | yes | in game |
| **Deinonychus** (`deinonychus`) | `temperate_25`, `temperate_35`, `temperate_45` | L35-43 | 6 | yes | in game |
| **Stegosaurus** (`stegosaurus`) | `temperate_35`, `temperate_45` | L45-53 | 3 | yes | in game |
| **Utahraptor** (`utahraptor`) | `temperate_25`, `temperate_45` | L45-55 | 3 | yes | in game |

### `temperate_20` (L20, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Compsognathus | 5 × 1 | 100% | L10 | 8%/group | yes | in game |
| gathering | Protoceratops | 4 × 1 | 100% | L10 | 8%/group | yes | retired: spawns fall through to compsognathus |
| working | Coelophysis | 4 × 1 | 100% | L18 | 8%/group | yes | in game |
| working | Velociraptor | 2 × 1 | 100% | L25 | 8%/group | yes | in game |
| crater | Protoceratops | 4 × 1 | 100% | L23 | 8%/group | yes | retired: spawns fall through to compsognathus |
| far_shore | Velociraptor | 3 × 1 | 100% | L30 | 8%/group | yes | in game |

### `temperate_25` (L25, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| fixed spot | Utahraptor | 1 × 1 | 100% | L45-55 | 8%/group | yes | in game |
| gathering | Protoceratops | 4 × 1 | 100% | L10 | 8%/group | yes | retired: spawns fall through to compsognathus |
| gathering | Compsognathus | 4 × 1 | 100% | L10 | 8%/group | yes | in game |
| working | Velociraptor | 3 × 2 | 100% | L25 | 8%/group | yes | in game |
| crater | Velociraptor | 4 × 1 | 100% | L33 | 8%/group | yes | in game |
| crater | Deinonychus | 2 × 1 | 100% | L40 | 8%/group | yes | in game |
| far_shore | Deinonychus | 3 × 1 | 100% | L40 | 8%/group | yes | in game |
| far_shore | Utahraptor | 1 × 1 | 25% | L55 | 8%/group | yes | in game |

### `temperate_35` (L35, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| working | Deinonychus | 3 × 2 | 100% | L35 | 8%/group | yes | in game |
| crater | Deinonychus | 4 × 1 | 100% | L43 | 8%/group | yes | in game |
| far_shore | Stegosaurus | 1 × 1 | 100% | L50 | 8%/group | yes | in game |

### `temperate_45` (L45, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| working | Stegosaurus | 2 × 1 | 100% | L45 | 8%/group | yes | in game |
| working | Deinonychus | 3 × 1 | 100% | L35 | 8%/group | yes | in game |
| crater | Stegosaurus | 3 × 1 | 100% | L53 | 8%/group | yes | in game |
| far_shore | Utahraptor | 1 × 1 | 100% | L55 | 8%/group | yes | in game |

## Tropical

Islands: `tropical_25` (L25, unstable), `tropical_40` (L40, unstable).

| species | islands | level | groups | tameable | status |
|---|---|---|---|---|---|
| **Compsognathus** (`compsognathus`) | `tropical_25` | L10 | 1 | yes | in game |
| **Coelophysis** (`coelophysis`) | `tropical_25` | L18 | 1 | yes | in game |
| **Protoceratops** (`protoceratops`) | `tropical_25` | L18 | 1 | yes | retired: spawns fall through to coelophysis |
| **Deinonychus** (`deinonychus`) | `tropical_25`, `tropical_40` | L30-43 | 3 | yes | in game |
| **Dilophosaurus** (`dilophosaurus`) | `tropical_25` | L20 | 1 | yes | no model yet: spawns fall through to compsognathus |
| **Dilophosaurus** (`dilophosaurus`) | `tropical_40` | L35-43 | 2 | yes | no model yet: spawns fall through to deinonychus |
| **Allosaurus** (`allosaurus`) | `tropical_40` | L40 | 1 | no | no model yet: spawns fall through to deinonychus |

### `tropical_25` (L25, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Compsognathus | 6 × 1 | 100% | L10 | 8%/group | yes | in game |
| working | Coelophysis | 4 × 1 | 100% | L18 | 8%/group | yes | in game |
| working | Protoceratops | 3 × 1 | 100% | L18 | 8%/group | yes | retired: spawns fall through to coelophysis |
| crater | Deinonychus | 3 × 1 | 100% | L43 | 8%/group | yes | in game |
| far_shore | Dilophosaurus | 1 × 1 | 100% | L20 | 8%/group | yes | no model yet: spawns fall through to compsognathus |

### `tropical_40` (L40, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Deinonychus | 3 × 1 | 100% | L30 | 8%/group | yes | in game |
| working | Dilophosaurus | 2 × 1 | 100% | L35 | 8%/group | yes | no model yet: spawns fall through to deinonychus |
| working | Deinonychus | 3 × 1 | 100% | L35 | 8%/group | yes | in game |
| crater | Dilophosaurus | 3 × 1 | 100% | L43 | 8%/group | yes | no model yet: spawns fall through to deinonychus |
| far_shore | Allosaurus | 1 × 1 | 30% | L40 | 8%/group | no | no model yet: spawns fall through to deinonychus |

## Tundra

Islands: `tundra_30` (L30, unstable), `tundra_55` (L55, unstable).

| species | islands | level | groups | tameable | status |
|---|---|---|---|---|---|
| **Velociraptor** (`velociraptor`) | `tundra_30`, `tundra_55` | L25 | 2 | yes | in game |
| **Megaloceros** (`megaloceros`) | `tundra_30`, `tundra_55` | L25-38 | 4 | yes | in game |
| **Smilodon** (`smilodon`) | `tundra_30`, `tundra_55` | L35-38 | 2 | yes | no model yet: spawns fall through to megaloceros |
| **Smilodon** (`smilodon`) | `tundra_55` | L25 | 1 | yes | no model yet: spawns fall through to velociraptor |
| **Tarbosaurus** (`tarbosaurus`) | `tundra_55` | L35 | 1 | yes | no model yet: spawns fall through to megaloceros |

### `tundra_30` (L30, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Megaloceros | 4 × 1 | 100% | L25 | 8%/group | yes | in game |
| working | Megaloceros | 3 × 1 | 100% | L30 | 8%/group | yes | in game |
| working | Velociraptor | 3 × 1 | 100% | L25 | 8%/group | yes | in game |
| crater | Megaloceros | 3 × 1 | 100% | L38 | 8%/group | yes | in game |
| far_shore | Smilodon | 1 × 1 | 100% | L35 | 8%/group | yes | no model yet: spawns fall through to megaloceros |

### `tundra_55` (L55, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Megaloceros | 4 × 1 | 100% | L25 | 8%/group | yes | in game |
| working | Smilodon | 2 × 1 | 100% | L25 | 8%/group | yes | no model yet: spawns fall through to velociraptor |
| working | Velociraptor | 4 × 1 | 100% | L25 | 8%/group | yes | in game |
| crater | Smilodon | 3 × 1 | 100% | L38 | 8%/group | yes | no model yet: spawns fall through to megaloceros |
| far_shore | Tarbosaurus | 1 × 1 | 100% | L35 | 8%/group | yes | no model yet: spawns fall through to megaloceros |

## Desert

Islands: `desert_35` (L35, unstable), `desert_50` (L50, unstable).

| species | islands | level | groups | tameable | status |
|---|---|---|---|---|---|
| **Coelophysis** (`coelophysis`) | `desert_35` | L18 | 1 | yes | in game |
| **Gallimimus** (`gallimimus`) | `desert_35`, `desert_50` | L25-38 | 4 | yes | in game |
| **Allosaurus** (`allosaurus`) | `desert_50` | L35 | 1 | no | no model yet: spawns fall through to gallimimus |
| **Ankylosaurus** (`ankylosaurus`) | `desert_50` | L50-58 | 2 | yes | in game |
| **Utahraptor** (`utahraptor`) | `desert_35`, `desert_50` | L50-58 | 3 | yes | in game |

### `desert_35` (L35, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Gallimimus | 4 × 1 | 100% | L25 | 8%/group | yes | in game |
| working | Gallimimus | 3 × 1 | 100% | L30 | 8%/group | yes | in game |
| working | Coelophysis | 4 × 1 | 100% | L18 | 8%/group | yes | in game |
| crater | Gallimimus | 5 × 1 | 100% | L38 | 8%/group | yes | in game |
| far_shore | Utahraptor | 1 × 1 | 100% | L55 | 8%/group | yes | in game |

### `desert_50` (L50, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Gallimimus | 4 × 1 | 100% | L25 | 8%/group | yes | in game |
| working | Utahraptor | 3 × 1 | 100% | L50 | 8%/group | yes | in game |
| working | Ankylosaurus | 1 × 1 | 100% | L50 | 8%/group | yes | in game |
| crater | Ankylosaurus | 2 × 1 | 100% | L58 | 8%/group | yes | in game |
| crater | Utahraptor | 3 × 1 | 100% | L58 | 8%/group | yes | in game |
| far_shore | Allosaurus | 1 × 1 | 100% | L35 | 8%/group | no | no model yet: spawns fall through to gallimimus |

## Swamp

Islands: `swamp_55` (L55, unstable).

| species | islands | level | groups | tameable | status |
|---|---|---|---|---|---|
| **Compsognathus** (`compsognathus`) | `swamp_55` | L10 | 1 | yes | in game |
| **Deinonychus** (`deinonychus`) | `swamp_55` | L35 | 1 | yes | in game |
| **Dilophosaurus** (`dilophosaurus`) | `swamp_55` | L20 | 1 | yes | no model yet: spawns fall through to compsognathus |
| **Triceratops** (`triceratops`) | `swamp_55` | L55-60 | 2 | yes | in game |

### `swamp_55` (L55, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| gathering | Compsognathus | 6 × 1 | 100% | L10 | 8%/group | yes | in game |
| working | Triceratops | 3 × 1 | 100% | L55 | 8%/group | yes | in game |
| working | Deinonychus | 4 × 1 | 100% | L35 | 8%/group | yes | in game |
| crater | Triceratops | 3 × 1 | 100% | L60 | 8%/group | yes | in game |
| far_shore | Dilophosaurus | 3 × 1 | 100% | L20 | 8%/group | yes | no model yet: spawns fall through to compsognathus |

## Volcanic

Islands: `volcanic_60` (L60, unstable).

| species | islands | level | groups | tameable | status |
|---|---|---|---|---|---|
| **Ankylosaurus** (`ankylosaurus`) | `volcanic_60` | L50 | 1 | yes | in game |
| **Utahraptor** (`utahraptor`) | `volcanic_60` | L58 | 1 | yes | in game |
| **Tyrannosaurus rex** (`tyrannosaurus`) | `volcanic_60` | L60 | 1 | yes | in game |

### `volcanic_60` (L60, unstable)

| where | species | count × groups | chance | level | alpha | tameable | status |
|---|---|---|---|---|---|---|---|
| working | Ankylosaurus | 2 × 1 | 100% | L50 | 8%/group | yes | in game |
| crater | Utahraptor | 3 × 1 | 100% | L58 | 8%/group | yes | in game |
| far_shore | Tyrannosaurus rex | 1 × 1 | 100% | L60 | 8%/group | yes | in game |

## Species by home climate

The `climate` field in each creature JSON is the species' home biome; spawning ignores it and uses the island tables above.

| species | tier | home climate | tameable | model | on a spawn table |
|---|---|---|---|---|---|
| Zebraceratops (`zebraceratops`) | 13 | grassland | yes | yes | yes |
| Compsognathus (`compsognathus`) | 15 | savannah | yes | yes | yes |
| Pachycephalosaurus (`pachycephalosaurus`) | 16 | grassland | yes | yes | no |
| Coelophysis (`coelophysis`) | 18 | savannah | yes | yes | yes |
| Protoceratops (`protoceratops`) | 20 | temperate | yes | no | yes |
| Velociraptor (`velociraptor`) | 25 | temperate | yes | yes | yes |
| Gallimimus (`gallimimus`) | 30 | desert | yes | yes | yes |
| Megaloceros (`megaloceros`) | 30 | tundra | yes | yes | yes |
| Deinonychus (`deinonychus`) | 35 | tropical | yes | yes | yes |
| Dilophosaurus (`dilophosaurus`) | 40 | tropical | yes | no | yes |
| Smilodon (`smilodon`) | 45 | tundra | yes | no | yes |
| Stegosaurus (`stegosaurus`) | 45 | temperate | yes | yes | yes |
| Styracosaurus (`styracosaurus`) | 45 | savannah | yes | yes | yes |
| Allosaurus (`allosaurus`) | 50 | desert | no | no | yes |
| Ankylosaurus (`ankylosaurus`) | 50 | desert | yes | yes | yes |
| Utahraptor (`utahraptor`) | 50 | desert | yes | yes | yes |
| Triceratops (`triceratops`) | 55 | swamp | yes | yes | yes |
| Brachiosaurus (`brachiosaurus`) | 60 | any | no | no | no |
| Tarbosaurus (`tarbosaurus`) | 60 | tundra | yes | no | yes |
| Tyrannosaurus rex (`tyrannosaurus`) | 60 | volcanic | yes | yes | yes |

