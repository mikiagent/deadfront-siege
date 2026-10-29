# HUDTWEAK (Claude agent): vitals restack, stomach under the badge, chips at the bar edge, CLAIM over the dial

Branch `claude/mmo-hudtweak` from `origin/claude/mmo-overhaul` (after LEVELBADGE landed). Owner 2026-10-28, verbatim:
"remove the worn text and push exhaustion up so its below energy. Move claim to above the day/night UI. Debuffs should
start aligned to the leftmost of the health bar. Make hunger bigger and centered underneath level".

## What shipped
- The exhaustion tier word (RESTED / WORN / TIRED / EXHAUSTED) is gone; the face sticker on the belt stays. The belt
  sits right under the energy bar (6 px gap, like health to energy). `HudLayout.vitals_rect` is 22 px shorter.
- Badge centre comes from `HudLayout.badge_centre`; the stomach ring is the badge's radius (30) centred under it
  (`HudLayout.stomach_circle`), out of the chip row, and is a `drawn_blocks["stomach"]` so tooltips and notices place
  around it. The fatigue tap area is the belt, 64 px tall.
- The buff/debuff row starts at the health bar's left edge (x = `hp_bar_rect.position.x`). The landscape phone's
  whistle row (pets out) starts under the bars too, right of the stomach ring; while it shows the chip row drops under
  it instead of shifting right.
- CLAIM hex: centred above the day/night dial's face (`DayNightDial.face_rect`), its caption between them on desktop;
  icon-only, 64 px, on a landscape phone. On the desktop the expanded quest card shifts left of CLAIM.
- 844x390 keeps the 300 px vitals block, so the centre band (top feed, quest card) is unchanged.

## Tests
- `t_levelbadge`: chips start at the health bar's edge; stomach ring badge-sized and centred under the badge, off the
  chips and bars; belt right under the energy bar; no tier word in the source; CLAIM above the dial, off the
  coordinates, 64 px on a phone. `t_hudrules`: ring sits under the badge; its overlap check skips its own block.
- `tools/all_tests.sh`: 132 run, 129 pass first time; t_buildspeed (2526 vs 2500 ms, under load) and t_tribe flaked and
  passed alone; t_fieldhud caught whistles over the quick-food row, fixed (whistles under the bars), then a rerun of
  t_fieldhud, t_levelbadge, t_hudrules, t_controls, t_petradial, t_levelbar, t_treadmill, t_levelfx, t_buildspeed,
  t_tribe: 10/10 PASS. `run_all.gd`: [tests] PASS. `tools/smoke.sh --no-import`: SMOKE PASS.

## Captures
`docs/orchestration/reports/hudtweak/hudtweak-lv{5,30,58}-{1600x900,844x390}.png`.

## Assumptions / notes
- The stomach still has no tap tooltip (none exists on canon).
- On 844x390 CLAIM (y 54-118) overlaps the bottom-right corner of the centre band by about 12 px; the top feed places
  its rows around visible hexes (taken_rects), so they do not collide.
