# Grok subagent task: three low-risk UI density fixes (presentation only)

Scope: edit ONLY `game/scripts/ui/inventory_ui.gd`, `game/scripts/ui/craft_ui.gd` and
`game/scripts/ui/animal_screen.gd`. Do not touch any other file, do not commit, do not deploy,
do not run git add. Another agent is editing `hunt_hud.gd` and `hex_button.gd` at the same time,
so leave those alone and ignore transient parse errors in them if you run tests mid-way.
Use the shared tokens in `game/scripts/ui/ui_tokens.gd` (8 px grid, `UiTokens.body(view)`,
`UiTokens.meta(view)`, `UiTokens.heading(view)`, teal selected, 44 px minimum targets).
Desktop 1600x900 is the judge; 390x844 must stay usable. Never shrink text to hide clipping.

1. Character screen (`inventory_ui.gd`): at 1600x900 the content sits in the top third of the
   panel and the rest is empty. Make it use the space: bag slot cells at least 64 px on desktop
   (keep 5 columns x 4 rows), equipment cells the same size (keep 3x3), stat rows with
   `UiTokens.body` size and 8 px rhythm, the equipment grid vertically centred against the bag,
   the "Tap an item." hint below the grid. Long names keep the reserved line + ellipsis.
2. Craft screen (`craft_ui.gd`): recipe rows ellipsise the metadata ("Stone Work Knife  Lv 60 ·…").
   Reserve enough width for the `Lv 60 · 3.0s` metadata so it never truncates at 1600x900; only
   the recipe name may ellipsise.
3. Animals screen (`animal_screen.gd`): the growth/genetics scroll list runs under the EQUIP /
   CLOSE button bar ("Melee Attack" is half hidden at 1600x900). Give the scroll container a
   bottom margin equal to the bar height plus 8 px so the last row is fully visible when
   scrolled to the end.

Verify: `GODOT_PATH=/Applications/Godot_mono.app/Contents/MacOS/Godot ./tools/test.sh` prints
`[tests] PASS` and `/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=ui_screenshot_lab`
(windowed) writes `/tmp/deadfront-ui-shots/inventory_1600x900.png`, `craft_1600x900.png`,
`animals_1600x900.png`; look at those PNGs and fix what you see before finishing. Finish by
printing GROK DONE and a five-line summary of exactly what changed in each file.
