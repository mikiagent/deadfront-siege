# Cursor M0 — foundation

Shipped the archive move, lab routing, Data autoload, item/inventory layer, harvest nodes, inventory UI, and `foundation_lab`.

## What shipped
- Root HTML/GLB plus `assets/*.glb` moved to `archive/deadfront-siege/` with a three-line README. Repo root is `AGENTS.md`, `.gitignore`, `.cursor/`, `archive/`, `docs/`, `game/`, `research/`, `tools/`.
- `--lab=<name>` on `OS.get_cmdline_user_args()`; `main.gd` instances `res://scenes/dev/<name>.tscn` and disables `DefaultPlayfield`. Smoke still uses the default floor.
- Autoload `Data` loads `data/items.json`, `data/statuses.json`, and every creature JSON (skips `anim_events.json`). Prints `[data] items=21 statuses=14 creatures=4`.
- `ItemDef` / `ItemStack` / `Inventory` (D7 merge: def + level + attributes + flags). Player bag is 20 slots.
- `HarvestNode` + player `NavigationAgent3D` + runtime-baked `NavigationRegion3D`. Tap-to-path, wait `gather_seconds`, print `[item] +N id attrs`.
- Inventory UI (`I`) shows attributes, level, process count, flags.

## Lab output (headless demo)
```
[item] +1 fibre_stalk { "climate": "temperate" }
[item] +1 fibre_stalk { "climate": "temperate" }
[item] +1 fibre_stalk { "climate": "tropical" }
[item] +1 fibre_stalk { "climate": "tropical" }
[item] refused thicket: need tool knife
[item] +1 fibre_stalk { "climate": "thicket" }
[item] fibre stacks temperate=2 tropical=2 (unmerged climates)
```
Same-climate fibre merges; temperate and tropical stay separate. Thicket prints `need tool knife` until a work knife is given.

## Assumptions
- `# ASSUMPTION:` harvest regen 8 s and gather 1.2 s (not numbered in PRD §8).
- Yields are 1–1 for the raptor-slice nodes.

## Blocked
- Nothing. Godot MCP `run_project` has no argv slot for `--lab=`; labs were run headless via the Godot binary.

## Reproduce
```
tools/smoke.sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=foundation_lab
```
Headless proof: add `--headless --quit-after 300`.
