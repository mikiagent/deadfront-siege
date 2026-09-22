# Durango-style UI redesign

## Shipped
Presentation-only pass over the player-facing screens. Gameplay rules, save schema, capture threshold, economy, spawns, and combat formulas are unchanged.

- Shared tokens in `UiTokens` (8 px grid, 12 px radius, ink panels, teal selection, danger red, type floors) and one `ContextRadial` hex layout used by gather, station entry, and the station menu.
- HUD: one bottom command rail, white action glyphs, compact upper-left vitals, minimap and a quest chip from existing island state, world-label collision avoidance with ellipsis. Debug hex stays off unless `Game.debug_overlay` is on.
- Creature plates: one emphasized plate; other creatures collapse to a thin bar; tamed pets keep HP plus a thin XP bar. Gathering UI stays above plates. Dead creatures already drop aggro rings.
- Inventory keeps the 5-column bag and 3x3 equipment grid and no longer scales the whole panel. Animals keeps an unlimited roster, three pinned active slots, aligned growth rows, and a circular respawn timer.
- Crafting is categories, recipe list, and a result column. Locked ingredients and missing stations stay visible. Placement uses a light dim, a thin grid, a teal valid footprint, red only when invalid, a local contact shadow, cost text, and rotate / place / cancel hints.
- World Atlas keeps the WORLD ATLAS title, region cards, one teal selected card, and readable zoom controls.
- Death is a card: YOU DIED, the downed-by line, the retreat note, and Respawn at camp. There is no new respawn timer.

## Validation
- `GODOT_PATH=/Applications/Godot_mono.app/Contents/MacOS/Godot ./tools/test.sh`: `[tests] PASS`. The suite still logs the existing "Save schema 4 is newer than this build (3)" guard.
- `ui_family_lab` exists and printed `[uifamily] inventory=true animals=true unlimited=true active_cap=3 stego=stegosaurus`.
- `ui_screenshot_lab` printed `[uishot] PASS` at 1600x900 and 390x844 for hud, inventory, animals, craft, atlas, death, and radial.
- Windowed Godot (Metal, not the headless dummy renderer) wrote PNGs under `/tmp/deadfront-ui-shots/`. Those pixels were inspected. Headless cannot read viewport textures.
- Desktop Chrome and a production soak were not run. `tools/publish_pck.sh`, `tools/deploy_web.sh`, and Vercel were not run. Claude Code publishes after review.

## Alias / stamp
The stamp stand-in is the git commit that contains this report. No pack hash and no deployment alias exist until that publish step.

## Assumptions
- `docs/reference/` did not contain the named Durango screenshots. Hierarchy follows the written spec and the existing HUD, not copied art.
- The quest chip reads the current island (home vs unstable vs empty lab). It is not a new quest system.
- Death cause is presentation-only (`player.downed_by`). Respawn is still the existing camp button; no countdown was added.
- The capture unit test loads `field_tame.gd` on the first frame so `godot --script` can compile it after autoloads exist. The 30% capture rule is unchanged.

Credits spent: 0.
