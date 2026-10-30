# dsc-hudredraw: the field HUD redraws only when something changed

Branch `mmo-hudredraw`. Follows `claude-tutperf` (#4: "the HUD redraws every frame unconditionally,
~1.3-1.7 ms/frame desktop").

## What changed

`game/scripts/ui/hunt_hud.gd`

- `_draw` is now `_draw()` (counter + timer) → `_draw_hud()`; the minimap likewise
  (`_draw_minimap()` → `_draw_minimap_body()`). `draw_count`, `map_draw_count`, `draw_usec`,
  `map_draw_usec` are readable by probes and tests.
- `_process` ends with `_tick_redraw(delta)` instead of `queue_redraw()`; the minimap's
  `queue_redraw()` is now `_tick_map_redraw(delta)`.
- `_hud_sig()` is every value `_draw` reads, quantized to what can be seen (0.1 px, whole metres,
  whole seconds, whole degrees on the map): vitals, effective maxima, the HP label, the mount's energy
  readout, stomach fullness/saturation/state/eased glyph scale, handful of level + XP bar values,
  statuses and buff rows (id, stacks, whole seconds), the rest box's lines, the orders step, the hunt
  target and its HP, nearby harvest nodes, the camera, the view size, the placer state, the
  treadmill's look key.
- `_map_sig_key()` is the same for the minimap: her map pixel, her heading, the camera yaw, the fog
  version and trail, the map texture's existence, the orders badge, the creatures inside the disc.
- `_animating()` keeps the repaint going only while a piece moves by itself: transient text (notices,
  toasts, skill XP rows, bites, floats), the level-up celebration and its MENU pulse, the status pulse
  and affliction boxes, the domain banner, the orders flash, gliding world pills, the combat frame
  fade, ghost fills still easing, the fog trail fading while she walks, a level badge at tier 4+.
- `_slow_tick_needed()` + `REDRAW_CATCHUP_S = 1.0`: a 1 Hz catch-up only while a piece that shows
  whole seconds is up (buff countdowns, the rest box's rates, a harvest node's regrow timer on an
  unstable island's "Survivable N min"). With none of those, an idle HUD can stand still indefinitely.
- State that `_draw` used to advance now advances in `_process`: the ghost-fill easing
  (`_tick_trails`), the stomach glyph's eased scale, and the treadmill's sheen clock.

`game/scripts/ui/exhaust_treadmill.gd`: `tick(delta, strain, paused, running)` only advances the sheen
clock while the belt animates; `look_key(phase)` gives the HUD its treads at whole pixels and its
sheen at 15 Hz (0.7 px a step), so a standing belt is a still picture and a crawling one repaints a
few times a second.

`status_fx.gd` (`pulsing()`, box glide tracking), `top_feed.gd` (`busy()`), `hud_pills.gd`
(`animating`: a pill still gliding or showing a regrow countdown).

## Numbers (headless, home island, standing still, `game/tests/t_hudredraw.gd`)

| Measure | Before | After |
|---|---|---|
| HUD `_draw` calls over 120 idle frames | 120 | 12 |
| HUD `_draw` calls over a 60-frame idle sample | 60 | 6 (the 1 Hz catch-up while the strip stands still) |
| Minimap `_draw` calls, same 60 frames | 60 | 1 |
| HUD `_draw` script time per call | 2.28 ms | 1.28 ms |
| HUD script time per frame, idle | 2.28 ms | ~0.13 ms |
| Minimap `_draw` script time per call | 0.086 ms | 0.059 ms |
| Process mean, HUD shown vs hidden | 4.85 / 4.67 ms | 3.53 / 2.73 ms |

The remaining repaints are the signature legitimately changing (the belt's drift key and the island's
own moving things). The per-draw cost also fell because the paint no longer eases trails or moves the
stomach scale.

## Assumptions

- Anything not in the signature waits for the next animating frame or the 1 Hz catch-up. The HUD's own
  controls (hexes, dial, sheets) keep their own redraw logic and are untouched.
- The level badge's shimmer at tier 4+ still repaints every frame (it is a continuous shimmer); tiers
  0-3 are still pictures and no longer do.
- The fog trail keeps repainting only while she walks; a standing survivor's trail is static.

## Checks

`t_hudredraw` (new probe), `t_levelbadge`, `t_levelbar`, `t_treadmill`, `t_hudrules`, `t_levelfx`,
`t_fieldhud` PASS; `run_all` and `tools/smoke.sh` PASS (see the verify script).
