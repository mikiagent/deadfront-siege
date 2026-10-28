# LEVELBAR (Claude agent) — segmented green level bar, exponential XP curve, no top-left level disc

Branch `claude/mmo-levelbar` (from `claude/mmo-overhaul`). Owner, 2026-10-28: remove the top-left level
UI, segment the bottom level bar by a unit of XP, make levels exponentially harder; "make it green for
the xp bar too"; give the circle's room to the vitals.

## What shipped
- Top-left level disc (number + LEVELFX badge pulse) removed from `HuntHud._draw`. The HP and energy bars
  start at the panel's left edge and take its 44 px (188 -> 232 px wide at both 1600x900 and 844x390); the
  stomach ring sits right after them and the exhaustion row/treadmill spans the same group. Draw code of
  the ring (`hud_stomach.gd`) and the treadmill (`exhaust_treadmill.gd`) untouched; only positions moved.
- Bottom level bar: 6 px (`UiTokens.XP_BAR_H`), fill `UiTokens.XP_GREEN` (owner exception to green =
  healing, commented), a 2 px gap after every `segment_xp` (100) XP of the level's cost, grouped into a
  multiple of 100 to stay at or under `max_segments` (40) (`LevelDisplay.xp_segments`). Label:
  "Lv. 10  137 / 305 XP  · 100 XP each". `UiTokens.xp_line_zone` widened to 320x30 (t_fieldhud mirror updated).
- Level-up pulse moved from the disc to the bar: `LevelUpCelebration.draw_bar_pulse` (gold wash + rising
  glow, same `level_fx.json` hud timings). `draw_badge` is gone.
- XP curve in data: `pioneer_levels.json xp_curve {base 110, growth 1.12, segment_xp 100, max_segments 40}`;
  `World.xp_for_level(n) = round(base x growth^n)`, plus `level_from_total`, `migrate_linear_xp`.
- Saves: written with `"xp_curve": 2`. A save without it keeps its total XP and the level is recomputed on
  the new curve; if that would drop the level the stored level is kept as a floor (XP into it clamped
  under its cost). A level gained by the recompute gets its per-level HP/energy quietly (no celebration).
- Capture hook: `--shot=` paths containing `levelbar-lvN` set Lv N at 45 % (`HudrulesShot`).

## Curve (cost of reaching the next level)
| Lv | old (100+25n) | new round(110x1.12^n) |
|---|---|---|
| 1 | 100 | 110 |
| 2 | 125 | 123 |
| 3 | 150 | 138 |
| 4 | 175 | 155 |
| 5 | 200 | 173 |
| 6 | 225 | 194 |
| 7 | 250 | 217 |
| 8 | 275 | 243 |
| 9 | 300 | 272 |
| 10 | 325 | 305 |
| 11 | 350 | 342 |
| 12 | 375 | 383 |
| 13 | 400 | 429 |
| 14 | 425 | 480 |
| 15 | 450 | 538 |
| 16 | 475 | 602 |
| 17 | 500 | 674 |
| 18 | 525 | 755 |
| 19 | 550 | 846 |
| 20 | 575 | 947 |
| 21 | 600 | 1061 |
| 22 | 625 | 1188 |
| 23 | 650 | 1331 |
| 24 | 675 | 1491 |
| 25 | 700 | 1670 |
| 26 | 725 | 1870 |
| 27 | 750 | 2094 |
| 28 | 775 | 2346 |
| 29 | 800 | 2627 |
| 30 | 825 | 2942 |

Cumulative to Lv 31: 13,875 old vs 26,546 new. Lv 1-11 stay within ~15 % of the old cost.

## Assumptions (logged as LB1-LB3 in docs/vision/WildLandsMMO_Open_Questions.md, 2026-10-28)
- LB1 constants 110 / 1.12. LB2 floor rule (Lv 13+ old saves keep their level; Lv 10-11 may gain one).
- LB3 100 XP per segment, max 40 (past Lv ~39 a segment becomes 200+ XP).

## Tests
- New `game/tests/t_levelbar.gd` PASS (no top-left level block/label/badge; segments == ceil(cost/unit)
  clamped and growing; curve monotonic + exponential within 1 %; level_from_total matches the table; floor
  rule; XP_GREEN; vitals group uses the freed room, ring beside the bars, nothing overlaps it; both sizes).
- t_ui, t_fieldhud, t_hudrules, t_levelfx, t_xpecon (curve check updated to the new numbers), t_save
  (goldens: pioneer level/xp compared against `migrate_linear_xp`, `xp_curve: 2` asserted), t_w2_skills PASS;
  run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.
- `t_levelbar` is not wired into run_all (no list to add to found); run it by name.

## Captures
`docs/orchestration/reports/levelbar/levelbar_lv{2,10,30}.png`: each stacks the top-left vitals at
1600x900 and 844x390 and the bottom bar strip at both sizes (2, 4 and 30 segments).

## For the next agent
- LEVELFX / stomach / treadmill branches touching `hunt_hud.gd` vitals lines or `draw_badge` will conflict:
  the disc lines and `x += lvl_r * 2.0 + 8.0` are deleted, `full_w` is 276 desktop / panel_w - 14 phone.
