# NAVZOOM: the nav menu zooms out and clouds drift in (Claude, 2026-10-28)

Branch `claude/mmo-navzoom` (from `claude/mmo-overhaul` 04016b23). Owner: "can you make it so clicking on
the nav menu zooms out and parallax clouds move in, that would be sick".

## What shipped

- `game/scripts/ui/menu_transition.gd` (`MenuTransition`, new): one per follow camera, a child of the
  `IsoCamera`. `MenuTransition.hold(node, strength)` holds it while `node` is in the tree and visible;
  `follow(item, strength)` re-holds a sheet that is hidden and shown instead of freed. The strongest
  holder wins. Holders are polled each frame, so a freed, queued-for-deletion, removed or hidden holder
  releases it without signal bookkeeping.
  - **Zoom:** it reads the camera's `size` (the zoom the wheel and pinch set) when the transition
    starts, eases it to 1.8x over 0.6 s (smoothstep, retargeted from the current value, so a close or
    reopen mid-transition reverses smoothly), and writes the saved value back exactly when it ends,
    then frees itself. Distance, near/far, tall-tree fade, shadow fit and the build-ghost label all
    follow `size` as they do for pinch zoom. Capped at `IsoCamera.LAB_MAX_SIZE` (30 m, what cull
    ranges cover), so from the player's max zoom (18 m) it goes to 1.67x. Angle never changes.
  - **Clouds:** a CanvasLayer at layer -1 (over the 3D world, under the HUD, plates, nav menu and
    sheets) with one Control drawing three layers (far/mid/near) of soft clouds: clusters of 7 puffs of
    one 256 px radial `GradientTexture2D`, with a faint grey belly pass. Each layer drifts at its own
    speed and size, and slides in from the screen edges as the transition rises (near layers further),
    parting on close. About 220 batched texture rects a frame, no shaders, no lighting, no assets.
- `nav_menu.gd`: `MenuTransition.hold(self)` in `_enter_tree` (one line). No `hunt_hud.gd` edit.
- `sheet_chrome.gd`: `backdrop()` calls `MenuTransition.follow(r, SHEET_STRENGTH)`, so every
  full-screen sheet (Craft, Animals, Market, Character/Skills/Orders, UiWorld sheets, world_ui) gets
  the lighter version (strength 0.45: 1.36x, fainter clouds, under its blur) while shown. MENU -> a
  sheet eases from 1.8x to 1.36x instead of snapping back.
- `tests/t_navzoom.gd`: open reaches 1.8x distance over the duration (mid value in between), angle
  unchanged; close restores exact `size`/`distance`/rotation (`==`, not approx); clouds and the node
  exist only while open/closing; mid-transition close; reopen during close does not compound; from a
  player zoom of 9 m; the follow keeps tracking a moved survivor while open; a hidden sheet holds
  nothing, a shown one gives 1.36x, hiding restores; 20 toggles at odd timings: node count 5628 -> 5628
  and exact zoom.
- `scripts/dev/navzoom_lab.gd` + `scenes/dev/navzoom_lab.tscn`: saves every frame of open/hold/close.
  Run with `--fixed-fps 30 --resolution 1600x900 -- --lab=navzoom_lab --shot-dir=DIR`.

## Gates

t_navzoom PASS, t_uinav PASS, t_ui PASS, t_fieldhud PASS, t_uichrome PASS, t_occlude / t_occlude2 /
t_occlfix PASS, run_all `[tests] PASS`, `bash tools/smoke.sh --no-import` SMOKE PASS.
t_uinav prints a SCRIPT ERROR at line 132 (it presses Orders as a "disabled" entry, but Orders has been
enabled since UICHAR, so the menu frees and the next line reads it); it predates this branch and the test
still passes.

## Captures (`docs/orchestration/reports/navzoom/`)

- `seq_open_1..8.png`: open transition at 1600x900 (frames 4-23 at 30 fps, 800 px wide).
- `closed_1600x900.png` / `open_1600x900.png` (scaled to 960/1120 wide to stay under 300 KB),
  `closed_844x390.png` / `open_844x390.png` (native), `open_1600x900_gl_compat.png`.
- `navzoom_open_close_1600x900.mp4` (1.8 MB, 2.2 s: open at 0.13 s, close at 1.33 s).

## Assumptions

- ASSUMPTION: 1.8x distance, 0.6 s, smoothstep (owner gave no numbers; brief said 1.6-2x, ~0.6 s).
- ASSUMPTION: full-screen sheets get strength 0.45 (1.36x, fainter clouds), from `SheetChrome.backdrop()`.
- Clouds are under the HUD (layer -1), so on close the HUD returns over the parting clouds.
- Ortho dev camera (`--cam-ortho`) zooms the same way (its `size` is the ortho height).

## Risks / for the next agent

- While a transition runs it owns `IsoCamera.size`: a wheel or pinch zoom during the menu is overwritten
  and the pre-menu zoom comes back. A lab that sets `cam.size` while a sheet is open would see its value
  replaced until the sheet closes.
- Any screen that uses `SheetChrome.backdrop()` now zooms the camera while shown. A screen that is
  visible but meant to sit over a non-world view (none today) would zoom the world behind it.
- In gl_compatibility the clouds look the same; the captures show the forward and compat views differ in
  tree crown placement before and after the menu, which is not from this change (closed frames match).
- Credits spent: 0 (no Meshy/Tripo/paid assets).
