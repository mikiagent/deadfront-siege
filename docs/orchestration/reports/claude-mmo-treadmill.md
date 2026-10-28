# TREADMILL: the exhaustion belt made richer (Claude agent)

Owner, 2026-10-28: "improve the artistry of the treadmill in the same way please", then "the exhaustion
state is a circle that moves, make it a tall bar".

## Shipped
- `game/scripts/ui/exhaust_treadmill.gd`: new `draw_belt` look, same 232x16 rect and every behaviour
  (direction, speed, Well Rested pause, tap-to-breakdown, percent label). Recessed rubber belt with depth
  shading and end drums, slat seams and stitched edges scrolling with it, strained part filled in blended
  `UiTokens.MOOD` tier colours with lit chevrons, tier notches, chevron streak at speed, a moving sheen,
  Well Rested frost (tint, rime, twinkling crystals), a 0.7 s pulse on crossing into a worse tier.
- The strain marker is now a tall needle: 4 px x 1.6 belt heights (ASSUMPTION on the 1.6), tier glow, crisp edge.
  The tap area (`_fatigue_rect`) is unchanged and still covers it.
- Hook: one line in `HuntHud._process` (`ExhaustTreadmill.tick(delta, strain, well_rested)`).
- `tests/t_treadmill.gd`: belt rect at 844x390 and 1600x900, needle taller than wide and than the belt,
  tier colours/pulse/frost, and a cost check (600 frames off vs 600 on, 50 belts a frame).
- `scripts/dev/treadmill_lab.gd` + `scenes/dev/treadmill_lab.tscn`: capture lab.

## Cost (measured)
~86 µs script time per belt draw (dev Mac, headless), ~45 canvas commands. Over 30,000 draws after warm-up:
static memory +1.2 KB vs +3.2 KB idle, objects +0. One fixed line buffer, cached percent label.
The first ~600 frames do grow memory once (glyph cache for each percent label and the canvas command pool);
the check is net memory and object count, not a malloc counter.

## Captures (docs/orchestration/reports/treadmill/)
- `compare_1600x900.png`, `compare_844x390.png`: before | after, 2x, rows rested, worn, tired, exhausted,
  sleeping (left), Well Rested (paused). Raw `before_*.png` / `after_*.png` beside them.
- `treadmill_1600x900.mp4` (1.1 MB): creep, ramp through every tier (pulses visible at 25/50/75 %), sleep left,
  Well Rested frost. No 844x390 video: the movie writer renders a 1600x900 window, so it would not show that
  layout. 844x390 lays out like desktop anyway (`UiTokens.is_phone` is width < 720), so its belt is the same.

## Gates
t_treadmill, t_rest, t_fieldhud, t_ui, t_hudrules PASS; run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.

## Notes for the next agent
- At 85 %+ strain the needle passes under the percent label (label drawn on top, as the old dot did).
