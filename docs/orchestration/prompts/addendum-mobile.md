# Addendum for Cursor: mobile-first (applies to M0 and every later milestone)

The owner changed the platform decision: this is a **mobile game first**, desktop second. Read the updated `docs/orchestration/plan.md` D2 and the new rules in `.cursor/rules/durango.mdc` before continuing.

What already exists (do not rebuild it): `scenes/ui/touch_controls.tscn` is autoloaded as `TouchControls`. It has a floating joystick on the left half of the screen that presses `move_*` and `sprint`, TouchScreenButtons on the right bound to `attack`, `roll`, `interact`, `tactic_1`, `tactic_2`, `inventory`, `craft`, and pinch/trackpad zoom for the iso camera. It appears automatically on touchscreens, and on desktop with `-- --touch` or F4. `project.godot` now has `emulate_touch_from_mouse`, landscape orientation, and the `mobile` renderer override for phones. `project.godot` and `scripts/core/input_setup.gd` changed; re-read them before editing.

What this means for your work:
- Read input only through InputMap actions. Never check for mouse buttons, keys, or touch events in gameplay scripts. The one exception is a screen tap for tap-to-gather / tap-to-attack: use the `tap` action and `get_viewport().get_mouse_position()` (touch emulates the mouse), and ignore taps that land on a visible Control or over the touch layer's buttons.
- When you add a verb, add its action in `input_setup.gd` and a button spec in `touch_controls.gd` (`BUTTONS` array) if a thumb needs it.
- UI: tap targets at least 64 px in the 1600x900 canvas, no hover-only information (tooltips open on tap, close on tap-outside), inventory and craft panels usable one-handed on a phone, everything inside `DisplayServer.get_display_safe_area()`.
- Performance: no per-frame allocations in hot loops, use MultiMeshInstance3D for vegetation, cap creature count per island for mobile (a constant in `game.gd`, `# ASSUMPTION:` 24).
- Test every acceptance check twice: once with keyboard, once with `-- --touch` and the mouse.

---

# Addendum 2 for Cursor: creature orientation and scale (M1)

`game/data/creatures/SCHEMA.md` §3 changed. Generated meshes arrive facing an arbitrary axis and at arbitrary size. In `CreatureView`, read `pipeline.forward_axis` (one of `+Z -Z +X -X`, default `-Z`) and `pipeline.source_height_m` from the species JSON; rotate the model so that axis faces Godot's `-Z`, then scale uniformly so the measured height equals `height_meters`. If `source_height_m` is absent, measure the imported AABB at runtime. Also implement the clip fallbacks in SCHEMA §2 (`run` = `walk` at 1.6x, `alert` = `idle`, `hit_react` = first 40% of `knockdown`) so a four-clip stand-in pack animates fully.
