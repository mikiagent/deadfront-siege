# Cursor milestone M8e — station crafting card and held-item slot

Reference: `docs/reference/durango-crafting-reference.webp`. In words: at night, the
survivor crouches at a campfire. Above the fire a compact dark card reads `Skewer` with
two round ingredient slots (meat, stick) joined by a `+`; a circular progress ring around
each slot fills as the craft proceeds. The fire lights a warm circle on the ground.
Bottom-left, above the menu row, a **held-item slot** shows the equipped tool (a skewer
here) with a swap-arrows glyph.

Do this after M8d. Reuse M8c's `HexButton` and M8d's radial. No autoloads, no
`project.godot`, no `game/shell/`, no `tools/`.

## Tasks

1. **Station crafting by tap.** Tapping a bonfire, workbench, drying rack or mortar
   (any `CraftStation`) opens a hex radial of the recipes that station can make now
   (icon, seconds, output level; red badge + missing ingredient name when short). The
   craft panel from M4 stays reachable from MENU → Craft for the full list.
2. **Craft card.** Choosing a recipe walks the player to the station, plays the
   `gather` clip (crouch), and shows a `CraftCard` Control above the station
   (unprojected): recipe name, one round slot per ingredient with its icon and count,
   `+` between slots, a 4 px circular progress ring around each slot filling over the
   recipe time (`recipes.json` `seconds`, `# ASSUMPTION` 3 s when absent). Ingredients
   are consumed at start; output arrives at the end with the M8d pickup toast. Moving
   away cancels and refunds. Queue: tapping the same hex again while crafting queues
   another (card shows `×2`).
3. **Held-item slot.** A 64 px slot bottom-left above the menu row shows the equipped
   tool (the one `Inventory.find_gather_tool` would pick first); tapping it opens a
   small row of the tools in the bag to swap; long-press unequips. The equipped tool
   is what gather options (M8d) check first, and it shows in the survivor's right hand
   (`Player.right_hand_anchor()`, Kenney tool GLBs from `props_manifest.json` `tools`).
4. **Fire light.** Bonfires get an `OmniLight3D` (warm, range 7 m, flicker) like the
   M5b lantern, on at dusk/night.

## Acceptance
- `m8e-craft-card.png` (night, crouched at the bonfire, the card with two ringed slots
  mid-progress, fire glow on the tiles) and `m8e-held-slot.png` (slot with a tool and the
  swap row open).
- Headless `craft_lab`: choosing a skewer prints `[craft] start skewer 3.0s` then
  `[item] +1 skewer` and `[ui] toast skewer +1`; a missing ingredient prints
  `[craft] blocked skewer: needs branch`.
- `tools/smoke.sh` → `SMOKE PASS`; report `docs/orchestration/reports/cursor-M8e-station-crafting.md`;
  commit as `M8e: station crafting card, held-item slot`.
