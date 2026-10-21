# Asset replacement register

Owner rule (2026-10-19): low-quality and low-poly assets are marked here for replacement by newer,
higher-quality assets. Every art package reads this file first and updates the row it touches.
Routing (owner, 2026-10-18): Tripo for complex creatures and characters, DeepSeek `dsc` rigs and
animates, Blender MCP or headless Blender scripts for buildings, props and nature.

Status values: `REPLACE` (marked, not started), `IN PROGRESS`, `REVIEW` (built, awaiting owner or
reviewer), `DONE` (shipped and pixel-checked). Evidence comes from the 2026-10-18 audit
(`plan-register.md` section 6) unless noted.

## Creatures

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| deinonychus | Oldest Meshy v1 single-image mesh (12k tris, JPEG normal), twisting pipe legs (owner-reported), slab hands, paddle tail, washed lime | Tripo multiview from approved sheet v01 + dsc rig | art-deinonychus | IN PROGRESS (sheet approved; build interrupted by usage limit) |
| allosaurus, tarbosaurus, dilophosaurus | Procedural box-on-two-sticks placeholder | Tripo + dsc | W1-ARTA | REPLACE (concept sheets need a side-view-first redo; owner batch approval pending) |
| triceratops, styracosaurus, ankylosaurus, smilodon | Box placeholder | Tripo + dsc | W1-ARTB | REPLACE (same) |
| brachiosaurus | Box placeholder (does not spawn yet) | Tripo + dsc | W2-ARTC | REPLACE |
| stegosaurus | v2 (Tripo mesh, Opus rig) now loads in game; override and box fallback deleted, stride-baked, slope conform (claude-mmo-stego.md). STEGO-ART: thagomizer cut from 8 spikes to 4 (two pairs, up and back) and the hide graded to the concept sheet (olive green-brown, cream belly, rust plates, ivory spikes); skeleton, weights, UVs and the 9 clips untouched (claude-mmo-stego-art.md) | One-line fix + review v2; art fix in headless Blender (tools/blender/stegosaurus_art/) | STEGO, STEGO-ART | REVIEW |
| gallimimus, compsognathus, coelophysis | Pure-white untextured patches, washed albedo, plastic look; donor clips | Clips re-animated by dsc (bite attacks, side-lying knockdown, sleep, feed); textures still need retexture/regen | W2-RERIG/ARTC | REVIEW (clips) / REPLACE (textures) |
| velociraptor, utahraptor | Donor rig (no jaw, 5 tail bones); attack whips tail vertical; belly-up knockdown | Clips re-animated by dsc (d649aea: bite attacks, side-lying knockdown, sleep, feed); bespoke rig with jaw still to do | W2-RERIG | REVIEW (clips in game; owner to judge; rig still REPLACE) |
| protoceratops, megaloceros | Procedural quadruped clips: attack = idle, legs-up knockdown | Combat/ground/rest clips re-animated by dsc; walk/run still procedural | W2-RERIG | REVIEW (clips in game; walk/run still REPLACE) |
| zebraceratops | Modelled from a Durango screenshot (IP risk; roster PRD says no Zebraceratops) | Replace with a real ceratopsian (owner to pick) | W2-ARTC | REPLACE (owner decision) |
| All transplanted species | Low-poly donor skeleton (no jaw, 1 neck bone, no toes) | Bespoke dsc rigs | W2-RERIG | REPLACE |

## Structures and props

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| Kenney survival-kit structures (fences, frames, workbench, basket, etc.) | Flat salmon palette, read as placeholders | Blender MCP set with one atlas | W1-STRUCTART | IN PROGRESS (interrupted) |
| Tent | Bare A-frame | Blender | W1-STRUCTART | IN PROGRESS |
| Catapult | Primitive boxes, untextured wheels | Blender | W1-STRUCTART | IN PROGRESS |
| Drying rack, smoker, crock pot, steamer, mortar, well | Static props; processing not visible | Blender, 4 visible stages | W1-STRUCTART + W2-PROCESS | IN PROGRESS |
| Harbour | Untextured grey box 150+ m inland | Blender pier/dock + coast placement | W1-STRUCTART + W2-TERRAIN | REPLACE |
| Building pieces (foundation, wall, doorway, roof, ramp, pillar) | Do not exist | Blender modular kit per tier | W2-BUILDSYS | REPLACE |

## World and nature

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| Quaternius-only nature families (Rock, Rock_Moss, Rock_Snow, Plant, Lilypad, snow and dead trees) | Low-poly CC0 style clashing with the generated set | Headless Blender rebuild in one style | W3-NATUREART | REPLACE |
| Terrain ground | Every climate is the same green meadow | Per-biome texture sets | W1-BIOME | IN PROGRESS (interrupted) |
| Water | Flat plane; disconnected trench river | Shader + terrain | W2-TERRAIN | REPLACE |

## Items and UI

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| Item icons (game-icons.net symbols) | Flat glyphs; owner wants rendered art overflowing the slot with rarity rims | Headless Blender renders | W1-ICONART | REPLACE (merged 2026-10-20: all icons are procedural_v1 renders, see `game/assets/icons/render/manifest.json` `replace` fields and `missing`; 28 flagged first; slots swap to ArtSlot in W2-SCREENS) |
| Held weapons | Hand shows the gather tool, not the weapon | Existing props + W1-ITEMS | W1-ITEMS | IN PROGRESS |
| Animal portraits | Hexagon with a letter | Rendered creature portraits | W2-SCREENS | REPLACE |

## Characters

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| Survivor v1 | Replaced by v2 (merged, live since 548804ac8) | - | - | DONE |
| Survivor v2 | Floats 0.9 m; root motion leaves the capsule (measured on v1, re-check on v2) | Code fix | W2-PLAYER/PANIM | REPLACE (re-measure) |
