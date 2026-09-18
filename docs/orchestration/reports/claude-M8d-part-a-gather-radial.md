# Claude M8d Part A — gathering radial (Durango reference)

Reference: `docs/reference/durango-gather-reference.webp`, `durango-tree-options-reference.webp`.

## What shipped
- `scripts/ui/hex_button.gd` (`HexButton`): Durango hex button — dark hex with light rim, icon or glyph, time on top, count below, red no-entry badge when blocked; touch and mouse; ≥ 64 px. Reused by the HUD skill cluster next.
- `scripts/ui/gather_radial.gd` (`GatherRadial`): tapping a node with several yields draws a hexagonal selection outline on its tile with the node name and `Lv. N` (green), and fans hex option buttons to the right (icon from `icons_manifest.json` with alias/category fallback, seconds, count range, `Item Lv. N` label; blocked options dimmed with the badge and `needs <tool>`). Tap a hex → gather with that option; tap anywhere else dismisses and the tap still acts.
- `HarvestNode.options()` / `select_option(i)`: one option per manifest `harvest` entry (trees: Branch 1.8 s bare-handed, Log 3.0 s axe, Bark Strip 3.0 s knife; rocks: Stone pick…). `# ASSUMPTION` tool map: wood_log→axe, stone/ore_chunk/clay→pick, bark_strip/hide→knife, others bare-handed. Single-yield nodes start at once (M8a flow unchanged).
- Player: radial layer (CanvasLayer 55), `_on_gather_option_picked` prints `[item] option <id> xA-B Ts` then begins the M8a auto-gather with that yield; `debug_open_radial` for labs.
- `island_lab`: headless probe picks option 1 on the nearest tree and gathers two units; `--shot=…radial…` captures the radial.

## Evidence
- `docs/orchestration/reports/m8d-gather-radial.png`
- Headless island_lab: `[item] option wood_log x1-2 3.0s (of 3 options)`, `[item] auto-equip work_axe axe`, two `[item] +N wood_log … (pool …)` lines, `[item] option gather done units=2`
- `tools/smoke.sh` → `SMOKE PASS`

## Still to do in M8d
- Context hexes (water: drink/wash/fill; bonfire: cauterise/cook; corpse: loot) and the corpse radial (Part C), pickup toasts, level-up overlay, land claim boundary, label pills, placement hexes (Part B).
