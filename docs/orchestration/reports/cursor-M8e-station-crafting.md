# Cursor M8e — station crafting card and held-item slot

Station tap radial, timed craft card with progress rings, held-tool slot + hand mesh, and bonfire night light.

## What shipped

### UI
- `game/scripts/ui/hex_button.gd` — M8c-style hex control (icon/glyph, seconds, count, red badge); reused by the station radial (M8c/M8d not yet on this branch).
- `game/scripts/ui/station_radial.gd` — hex radial of recipes for a station (seconds, output level, blocked badge with missing ingredient).
- `game/scripts/ui/craft_card.gd` — unprojected `PanelContainer` craft card: recipe name, round ingredient slots with 4 px progress rings and `+` between them, queue `×N`.
- `game/scripts/ui/pickup_toast.gd` — top-centre pickup toast (`[ui] toast id +N`); stacks repeats.
- `game/scripts/ui/held_item_slot.gd` — 64 px bottom-left slot above the menu row; tap opens tool swap row; long-press unequips.

### Session / data
- `game/scripts/items/station_craft.gd` — open station → choose recipe → walk → crouch (`gather` clip) → consume at start → card progress → output + toast; move away / stick input cancels and refunds; retap same hex queues (`×2`).
- `Crafting`: `recipe_seconds` (`# ASSUMPTION` 3 s), `recipes_for_station`, `missing_ingredient_name`, `consume_for_craft` / `finish_craft`.
- `Inventory`: `equipped_tool_index`, `equipped_gather_tool()`, `gather_tools_in_bag()`; `find_gather_tool` prefers the equipped slot.
- Data: `skewer` item + bonfire recipe (meat + handle/branch, 3.0 s, max level 19); icon aliases for `raw_meat` / `skewer`.

### World / player
- `Bonfire`: `craft_station` group, `station_id=bonfire`, warm `OmniLight3D` range 7 m with flicker at dusk/dawn/night.
- `PropVisuals.attach_tool_model` — Kenney tool GLB on `Player.right_hand_anchor()` (`# ASSUMPTION`: knife → hammer stand-in).
- `Player`: `station_craft` setup; `_building_interact` opens craft for `CraftStation`; keyboard `interact` near `craft_station` opens radial. **Did not edit tap-routing** (`_tap_world` / `_interact_tap_target`).

### Lab
- `craft_lab`: bonfire + headless skewer demo; `--shot=` stages craft-card (night, mid-progress) and held-slot (swap row).

## Acceptance
- Screenshots: `docs/orchestration/reports/m8e-craft-card.png`, `m8e-held-slot.png`.
- Headless `craft_lab`: `[craft] blocked skewer: needs branch`, `[craft] start skewer 3.0s`, `[item] +1 skewer`, `[ui] toast skewer +1`.
- `tools/smoke.sh` → `SMOKE PASS`.

## Assumptions
- Stick slot = `handle` category (branch); missing hint prints `branch`.
- Recipe seconds default 3.0 when omitted.
- Knife hand mesh uses Kenney hammer until a knife GLB exists.
- HexButton / pickup toast shipped here because M8c/M8d are not on this branch yet.

## Needs from other agents (tap / owned files)
Bonfire **tap** still only cauterises inside `_interact_tap_target` (owned by the other agent). Wire taps on `CraftStation` / `Bonfire` to `player.open_station_craft(node)` (workbench already works via `_building_interact` → placed_building). Mortar has no placeable yet.

## Credits
Meshy credits spent: 0.
