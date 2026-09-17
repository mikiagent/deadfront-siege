# Cursor milestone M0 — foundation

You are building the Godot side of a dinosaur survival game (a Durango: Wild Lands rebuild with its mistakes fixed). A skeleton project already boots at `game/`. M0 makes the repo sane, proves your tool loop, and lays the item data layer that every later system stores things in.

## Read first
- `AGENTS.md`, `.cursor/rules/durango.mdc`, `docs/orchestration/plan.md` (decisions D1–D8, milestone table)
- `docs/prd/durango-wild-lands-systems-prd.md` §8, §9.1, §9.2 (items, attributes, flexible recipes) and §6 (vitals, for naming only)
- `game/data/creatures/SCHEMA.md` (you consume this; do not edit it)
- The existing skeleton: `game/project.godot`, `game/scripts/core/*.gd`, `game/scripts/player/player.gd`, `game/scripts/camera/iso_camera.gd`, `game/scenes/main.tscn`, `tools/smoke.sh`

## Tool loop
Use the `godot` MCP server: `get_project_info` on `game/`, `run_project` then `get_debug_output` (look for `[boot]` lines), `stop_project`. Then run `tools/smoke.sh` and confirm `SMOKE PASS`. Do this before changing anything so you know the baseline works.

## Tasks

1. **Archive the old game.** `git mv` every `*.html` and `*.glb` in the repo root, plus `assets/*.glb`, into `archive/deadfront-siege/`. Add `archive/deadfront-siege/README.md` (three lines: what it is, open `index.html` in a browser, treated as a design spec only). Do not modify the moved files. The repo root should then contain only `AGENTS.md`, `.gitignore`, `.cursor/`, `archive/`, `docs/`, `game/`, `research/`, `tools/`.

2. **Lab scene routing.** In `scripts/core/game.gd`, read `--lab=<name>` from `OS.get_cmdline_user_args()`; when present, `main.gd` loads `res://scenes/dev/<name>.tscn` as a child instead of the default floor. The smoke test path must still work unchanged.

3. **Data autoload** `scripts/core/data.gd` (autoload `Data`): loads `game/data/items.json`, `game/data/statuses.json` (create it empty-but-valid; M2 fills it), and every `game/data/creatures/*.json` into typed Resources at startup. Print `[data] items=N statuses=N creatures=N`. Fail loudly on a malformed file.

4. **Item model** (`scripts/items/`):
   - `ItemDef` Resource: `id`, `display_name`, `categories: Array[StringName]` (from PRD §9.1: blade, handle, lashing, fibre, herb, cloth, meat, bone, hide, stone, wood, medicine, tool, weapon), `stack_max`, `tool_class` (knife/axe/pick/none), `base_level`.
   - `ItemStack` RefCounted: `def_id`, `count`, `level`, `process_count`, `attributes: Dictionary` (tag → value, e.g. `{"climate":"temperate","hardness":2}`), `flags: Array[StringName]` (`unstable`, `poisoned`). Two stacks merge **only** when def, level, attributes and flags are identical. This is decision D7; do not simplify it.
   - `Inventory` RefCounted: fixed slot count, `add(stack) -> int` returning the remainder, `remove`, `find_by_category`, `signal changed`. Player gets a 20-slot inventory.
   - `game/data/items.json`: at least these defs for the raptor slice: branch, stone, fibre_stalk, twine, herb_leaf, cloth_scrap, bandage, stone_knife_work, stone_knife, raptor_meat, raptor_bone, raptor_hide, raw_hide, capture_net_i. Every entry has categories.

5. **Harvest node** `scenes/world/harvest_node.tscn` + `scripts/world/harvest_node.gd`: a StaticBody3D with a placeholder mesh, exported `yield_table` (def_id, min, max, attributes to stamp on the yield), `required_tool_class`, `regen_seconds`, `gather_seconds`. Clicking it (the `tap` action, raycast from the camera) makes the player path to it (add a NavigationAgent3D to the player and a NavigationRegion3D to the floor), face it, wait `gather_seconds`, then receive the yield. Print `[item] +N <id> <attributes>`.

6. **Inventory UI** (`scenes/ui/inventory.tscn`): a GridContainer of slots toggled by the `inventory` action, tooltip shows attributes, level, process count and flags. Ugly is fine; correct is required.

7. **Lab** `scenes/dev/foundation_lab.tscn`: floor with navmesh, player, six harvest nodes (two fibre stalks with different `climate` attributes, a branch pile, a stone, a herb, a thicket that needs a knife), a debug label showing inventory slot usage.

## Acceptance (do all, then report)
- `tools/smoke.sh` prints `SMOKE PASS`.
- `run_project` with `--lab=foundation_lab`: gathering the two fibre stalks produces two separate stacks (different attributes), gathering the same stalk twice merges. The thicket refuses without a knife and prints why.
- `git status` shows the archive move and only your owned folders otherwise.
- Write `docs/orchestration/reports/cursor-M0-foundation.md`: what shipped, assumptions marked `# ASSUMPTION:`, anything that blocked you, and the exact command to reproduce the lab.
