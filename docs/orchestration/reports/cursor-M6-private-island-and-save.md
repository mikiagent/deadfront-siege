# Cursor M6 — private island, travel, save/load

Home loop: a permanent private island, harbour travel to the unstable temperate slice, cargo warp for unstable goods, and a versioned save.

M5 was not in the queue; this milestone ships a compact island generator so travel and save have somewhere to land.

## What shipped
- `game/data/islands/home_grassland.json` (160 m, grassland, permanent, five terrain densities) and `temperate_25.json` (unstable, 2 h lifetime, sail cost 5 T-stones, crater, velociraptor pack).
- `World` autoload: island registry, fade travel, Pioneer Level, T-stones (`# ASSUMPTION:` start 20), cargo waiting at home (60 slots, `# ASSUMPTION:` PRD ~100).
- One-time terrain pick: meadow / forest / rocky / riverside / coastal. Permanent and saved.
- `IslandRuntime`: floor + nav, MultiMesh grass, HarvestNode GLBs from the nature manifest, harbour, camp coziness (−50% fatigue), cargo warp, home cargo basket, crater discover `[world] crater discovered`.
- Buildings: tent (offline rest 8 fatigue/min `# ASSUMPTION:`), basket, fence, gate, sign, plus workbench / drying rack / pen / bonfire. Home placements are free and do not decay. Sprint+interact packs up and returns the kit.
- Unstable gather stamps `unstable`. Walking home through the harbour destroys those stacks with `[world] unstable goods destroyed`. Cargo warp (2 T-stones `# ASSUMPTION:`) sends them to the home harbour basket and clears the flag. Inventory shows a **U** pip.
- Save `user://save_1.json` schema 1: vitals, statuses, inventory, pets, skills, home terrain and buildings, Pioneer, T-stones, island id/position, unstable lifetime and harvested nodes, clock. Autosave every 60 s and on travel; pause menu Save. Load on boot if present.
- Map (M): island, lifetime, harbour routes, warp home, fatigue line, crater marker.

## Lab output (PRD §24 tests 4–5 in spirit)
```
[world] island home_grassland nodes=30 creatures=0 terrain=meadow
[world] unstable goods destroyed
[world] cargo warp 1 stacks fee=2
[world] cargo basket stone=2
[world] saved schema=1 island=home_grassland
[world] offline rest 120s
[world] loaded island=home_grassland terrain=meadow pioneer=0
[world] fatigue after rest=0 terrain=meadow pioneer=0
```
`tools/smoke.sh` → `SMOKE PASS`. `--lab=home_lab` boots onto the home island.

## Assumptions
- Island generator is a stand-in for M5 (flat floor, limited harvest counts, one unstable island).
- Basket 60 slots; cargo fee 2 T-stones; tent rest 8 fatigue per real minute; starting T-stones 20.
- Pack-up is sprint + interact on a home building.

## Reproduce
```
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=home_lab
```
Tap the dock for harbour routes. M = map (warp home). C = craft / place tent and basket.

## Next agent
MOB1 can export this. Real M5 heightmap/river/day-night can replace `IslandRuntime` without changing the save schema.
