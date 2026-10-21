# Codex animals layout

- Bug: `AnimalScreen` is a direct `CanvasLayer` child, so its full-rect anchors had no Control parent size and the root measured `0x0`; the dimmer did not cover the world/HUD.
- Repro before: `.../gslot.sh perl -e 'alarm 300; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game -- --lab=ui_screenshot_lab` printed `[uishot] PASS`, but the old lab mounted Animals under a Control and therefore masked the CanvasLayer case. The existing shots inspected were `/tmp/deadfront-ui-shots/animals_1600x900.png` and `animals_390x844.png`; they showed the screen content over the plain backdrop, with no real CanvasLayer geometry assertion.
- Root cause: anchors alone do not size a Control whose parent is `CanvasLayer`.
- Fix: `animal_screen.gd` now explicitly tracks viewport size/resize, keeps the modal root sized to the viewport, and uses a compact landscape-phone layout to separate title, active slots, roster, detail, and 56 px actions. `ui_screenshot_lab.gd` now mounts Animals under a CanvasLayer, tests `0x0`, and checks phone HUD-rail coverage at `844x390`.
- Verification: `git diff --check` passed. Post-change Godot labs, import, `run_all.gd`, smoke, and windowed screenshots were blocked because all five machine-wide `gslot.sh` locks were busy (`lockf` returned 75); no post-change visual claim is made.
- Not fixed: no changes were made to `hunt_hud.gd`, `inventory_ui.gd`, or other UI owners. The named `ui_real_capture_lab.gd` is absent from this worktree; `ui_screenshot_lab.gd` is the available equivalent.
