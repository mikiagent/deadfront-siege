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

## Owner layout follow-up (same branch, Milan 2026-10-30)

Verbatim: "move the level up UI higher (below hunger) and the skill XP + player XP UI lower (above
eat)" / "the level-up banner goes left, below the hunger ring".

- `HudLayout.levelup_top(hud, r)` is the new anchor: the left column inside the safe area, its top
  8 px under the stomach (hunger) ring's bottom, or under the vitals when no ring is drawn.
- `HudLayout.xp_feed_top(hud)` is the bottom-left anchor: 8 px above the quick-food (EAT) row.
- Character level-up (`LevelUpCelebration.desktop_anchor`): the stack's top is `levelup_top` instead of
  the middle of the free column; it is raised further only when a tall stack would run past the quick
  slots. Phone banner and the target-plate push-down behaviour are unchanged.
- Skill category level-up (`TopFeed.draw`): a `skill` row now has its own column, hung from
  `levelup_top` (left, under the ring) and only sliding down past whatever control occupies that strip;
  gain rows stay in the top-middle column.
- XP feed (`YieldCard.draw_feed`): rows stack upwards from `xp_feed_top`, taking a free spot upward, so
  the newest gain is the bottom one just over EAT.
- Player XP readout ("Lv. N  x / y XP  · u XP each"): drawn bottom-left at the same anchor, under the
  XP rows (it used to be centred on the desktop and right-aligned on a phone).

### Assumptions

- "Player XP UI" means that readout line (the level bar itself stays full width along the bottom edge);
  its label moved with the skill rows so both XP figures sit together above EAT.
- A phone canvas has no left column above the quick row for a 13-line character stack, so a phone keeps
  the centre-band banner (unchanged, as before the follow-up).

### Tests updated

`t_levelfx` (skill row anchored under the ring; character stack starts under the ring, still off every
block and hex), `t_levelbar` (the readout is bottom-left over EAT), `t_uigather` (the XP line is
bottom-left over EAT), `t_fieldhud` (the layout check now uses the drawn readout instead of the retired
centre `UiTokens.xp_line_zone`). `t_hudrules`, `t_levelbadge`, `t_treadmill`, `t_hudredraw` unchanged
and PASS.

## Re-merge onto the new canon (integrator follow-up, 2026-10-30)

Fetched `origin` and merged `origin/claude/mmo-overhaul` (b1e88e3d: FOODTORPOR, SLOWLEVELS,
CREATURECHIPS, TASKSCREEN, STYRATACTICS) into the branch. One conflict, in `docs/current/hud.md`,
resolved keeping both intents:

- Level bar label: our owner-2026-10-30 bottom-left anchor just over the EAT row (with the skill XP
  rows stacking above it) plus canon's `137 / 763 XP` and cost `round(110 x 1.12^n x 2.5)`
  (`player_xp_cost_mult`).
- Skill XP lines: our `HudLayout.xp_feed_top` bottom-left placement **and** canon's SLOWLEVELS batch
  wording (one bar per tree, light-green ghost, `SKILL_CATCHUP_DELAY` 0.6 s, level flash, `SKILL_LIFE`
  2.5 s), merged into one bullet. This file has no Open Questions section, so nothing to merge there.

Code: `hunt_hud.gd` auto-merged and keeps the `_draw`/`_draw_hud` split, the signature and
`_animating()`. One canon input was missing from the signature and is now in it: the target plate's
FOODTORPOR torpor strip and knock-out tick read `t.torpor` (`_q10(t.torpor)`, 0 while the strip is
hidden) — a sedated target's strip would otherwise have frozen between repaints. CREATURECHIPS and
TASKSCREEN need no change: the plate's creature chips are already keyed by `[id, stacks]` in the
target slot, and the claimable-task count only drives the MENU hex's badge (`field.apply_badge` →
`m.queue_redraw()`), which owns its own repaint.

Also added a short "Repaint policy (HUDREDRAW)" section to `docs/current/hud.md` (canon had merged the
canvas section without it): the signature, `_animating()`, the 1 Hz catch-up and the 0-redraw idle.

Re-verified after the merge: `t_hudredraw` — HUD `_draw` 0 over 120 shown frames and 0 over the 60-frame
idle sample, minimap 5/120 and 5/60, process mean 5.26 ms shown vs 6.29 ms hidden (headless noise at
this sample size; the deltas that matter are the draw counts and the per-draw script time, ~1.28 ms).
`t_fieldhud` prints "idle 60 frames with nothing animating: HUD draws 0, minimap draws 0";
`t_levelfx`, `t_levelbadge`, `t_levelbar`, `t_hudrules`, `t_treadmill` PASS; the full
`verify_hudredraw.sh` (including `run_all` and `smoke`) passes.

Gotcha for the next agent: after such a merge, a class added by canon needs one `--import` before any
headless test, or every autoload fails to compile with "Identifier ... not declared".
