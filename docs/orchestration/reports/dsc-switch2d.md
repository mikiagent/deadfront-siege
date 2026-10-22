# dsc-switch2d — resources as painted 2D cards, buildings stay 3D

Owner brief (2026-10-21): *"keep buildings 3D and make resources 2D"*, and the flat art must face the
camera at all times, at the same camera angle the game already uses.

## What shipped

Resources (every `harvest` prop: trees, bushes, rocks, plants, logs, ore, clay) now draw as **flat cards
that face the camera**, from the owner's own painted sprites where a family has art and from the baked
CARD2D cards where it does not. Buildings (`placed_building`), creatures and the survivor stay 3D.

- `game/data/world/rules.json` — `"resource_render": "card"` is now the default (the old 3D look is the
  `"model"` rule, still selectable, and the lab shoots both for comparison).
- `game/scripts/world/card_prop.gd`
  - `visual_for(family, pos)` → which art a node draws. Order: the family's own painted sprite row in
    `sprites2d.json` (variant chosen by a hash of the node position, so a node always gets the same
    variant), then its baked card from `card2d.json`, then the overrides/role fallbacks in
    `game/data/world/sprites2d_map.json`. **Nothing resolves to a GLB under `resource_render: "card"`.**
  - `setup_painted(row, height_m, shade_mode)` builds the painted card: the PNG itself as albedo, height
    `height_m` from the manifest, width from the PNG's aspect, and the manifest's pivot pixel is the
    ground point (so the base sits on the terrain).
  - Facing: the quad's basis is set to the live `Camera3D`'s basis every `_face_camera()`. The fallback
    basis (before a camera exists) is derived from the `[shader_globals]` camera values
    (`camera_pitch_deg`, `camera_yaw_deg`, ...) — nothing hard-codes 45° / −38.7°. `[card2d]` in
    `project.godot` is gone.
  - The occlusion-fade body is optional: only cards taller than the survivor's fade height carry the
    instance uniform, the rest use the same shader with the fade body stripped. (GLES3 caps instances
    that use a shader *instance* variable at 4096; 267 island cards plus the 3D props overflowed with
    "Too many instances using shader instance variables".)
- `game/shaders/card_sway.gdshader` — sway, parallax, optional occlusion fade, and `shading_mode`:
  `0` = baked card (normal map), `1` = `SHADE_PAINTED` (lit through a flat, camera-facing normal so the
  paint still takes sun colour/energy and darkens at night), `2` = `SHADE_PAINTED_UNLIT`.
- `game/data/world/sprites2d_map.json` (new) — per-family art overrides and per-role fallbacks as data.
- `game/scripts/world/island_scatter.gd`, `game/scripts/world/harvest_node.gd` — attach/refresh the card
  visual, and swap to the baked "empty" card when a bush is spent.
- `game/scripts/dev/switch2d_lab.gd` + `game/scenes/dev/switch2d_lab.tscn` (new) — the lab the gate runs.
- `game/tests/t_switch2d.gd` (new), `game/tests/t_card2d.gd` — unit stage.

## Verified

- `t_switch2d` PASS (script error free), `t_card2d` PASS, and the related `t_stepover`, `t_occlude` PASS.
- Lab, windowed, at **1600x900** and **844x390** (the phone viewport):
  `painted_nodes=267 baked_nodes=234 model_nodes=0 grey_cards=0 ms_cards 12.6-13.9 ms_models 13.2-13.9
  tap_ok=1 empty_ok=1 facing_err_deg=0.02 shots=6` at each size (final run; frame times move a few percent
  with whatever else is on the box). Six PNGs per resolution:
  `switch2d_home_grassland_cards.png`, `..._models.png`, `switch2d_tropical_25_cards.png`,
  `..._models.png`, `switch2d_night_cards.png`, `switch2d_painted_shading.png`.
- Frame time: cards cost about what the old 3D props cost in the same view (sum of per-island medians,
  vsync off, best of 3 passes per mode). The gate asserts `ms_cards <= ms_models * 1.05`; the winning
  runs sit at 0.1-2 % over the models, and a single pass without the repeats swung by 40 % from other
  agents' Godot instances on the same machine, which is why the lab takes the best of three.
- Look pass (every shot opened, verdict recorded in `.dsc/NOTES.md`): painted cards are planted on their
  pivots, upright, at manifest scale (palms ~5 m, grass knee-high next to the 1.8 m survivor), take the
  scene light and the night, and cast the island's shadows. No floating, sunk or giant cards. Buildings
  and the 3D trees next to them stay 3D.

## Decisions (and why)

- **Painted art is lit, not unlit** (`SHADE_PAINTED`): a flat, camera-facing normal gives one shade value
  over the whole sprite from the sun's own colour and energy, so a card darkens at night and in shade
  without inventing a second 3D shading on top of the paint. `SHADE_PAINTED_UNLIT` exists and both are
  shot side by side; in full daylight they are nearly identical (head-on sun), at night the lit mode is
  the one that behaves.
- **Families without painted art keep a baked card**, and families with no card fall back by role
  (`# ASSUMPTION:` in `card_prop.gd`), so switching to cards never leaves a hole and never silently
  draws a model. The baked cards read a little flat next to the painted art — that is the art gap, not
  a bug.
- **Facing is measured against the camera's view axis**, not the ray to the camera: with the game's
  4.3° perspective lens a perfectly parallel card far from the focus reads up to ~20° off by the ray.
- **`-- --models` / `resource_render: "model"` stay** so the old look can be compared or restored.

## Lab lessons (for whoever touches `switch2d_lab.gd`)

- `RenderingServer.frame_post_draw` can never fire on a window that is not presenting — it stalled the
  lab past its watchdog once. Use `RenderingServer.force_draw(false)` then one `process_frame`: the
  viewport image is the *last finished* frame, and without the force it is often the previous view
  (that is how the "cards shot" once became the camp, and every grey-card hit became plain grass).
- The card's quad is offset from its node by the pivot compensation, so a sampling rect must centre on
  `global_transform * get_aabb().get_center()`, not on `global_position`.
- `_tap_and_empty()` walks the survivor to a bush; return to the patch before shooting. The model pass
  reloads the island (which respawns the survivor), so it must call `_stand_in_props()` again or its
  shot frames the camp instead of the patch and the cards/models pair is not like-for-like.
- Thin, distant sprites (hanging vines, bamboo) cover a few pixels; `MIN_RECT_PX` (scaled by the frame
  height, so a phone-sized viewport keeps judging) and the 25 m distance cut keep them out.
- Frame timing needs repeats (best of `PERF_PASSES` medians): a single pass is at the mercy of whatever
  else is running on the machine.

## Integrator notes

- The worktree was cut from `claude/mmo-switch2d` at `c86edabd`, which already merges `claude/mmo-card2d`
  and `claude/mmo-sprites2d`. The shared gate's default scope base (merge-base with
  `claude/mmo-overhaul`) predates those merges, so `BASE=c86edabd` is set in `job_switch2d.conf`; against
  that base this task's diff is exactly: `card_prop.gd`, `harvest_node.gd`, `island_scatter.gd`,
  `card_sway.gdshader`, `data/world/rules.json`, `data/world/sprites2d_map.json` (new), `project.godot`,
  `tests/t_card2d.gd`, `tests/t_switch2d.gd` (new), `scripts/dev/switch2d_lab.gd` (new),
  `scenes/dev/switch2d_lab.tscn` (new), plus this report and the `.dsc/` notes. The gate's scope check
  also had to ignore the runner's own bookkeeping files (`.dsc-task/TASK.md`, `.dsc.local.json`), which
  it writes into the worktree; they are not the agent's edits.
- Run smoke through the shared slot script (`gslot.sh`): launched bare in the sandbox, Godot segfaults on
  `user://logs/...` because `$HOME/Library` is not writable and only gslot.sh points `HOME` at scratch.
- `tools/smoke.sh --no-import` → `SMOKE PASS`; `verify_job.sh switch2d` (full) → `VERIFY PASS`.
- Nothing is committed by me; the runner checkpoints.

## Not done / next

- Baked-card art is flatter than the painted art. Cutting painted sprites for the remaining families
  (berry bushes, rocks, stumps) is art work, outside this task.
- The HUD's labels are dense at 844x390 and overlap the view; that is pre-existing HUD layout, untouched.
