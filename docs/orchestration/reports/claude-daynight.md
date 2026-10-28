# DAYNIGHT — day/night widget redesign (Claude, 2026-10-28)

Owner, verbatim: "I don't like the day/night cycle UI and I want you to improve it and animate it so it
looks cooler please". Branch `claude/mmo-daynight` (from `claude/mmo-overhaul`). Not merged: **the
owner picks a variant first.**

## What shipped

`game/scripts/ui/day_night_dial.gd` rewritten; three faces behind one switch,
`DayNightDial.variant` (`&"a"`, `&"b"`, `&"c"`), or `--daynight=a|b|c` after `--` on the command line.
Default `a`. Once the owner picks, delete the other two `_build_*` / `_draw_*` pairs and the switch.

| | Desktop | Phone (compact) | Look |
|---|---|---|---|
| **A** hex sky window | 78x68 | 66x64 | flat-top hex with a sky gradient, the sun and moon on an arc over a hill line, the clock on the ground, a gold pip riding the rim as the 24 h "now" (midnight bottom, 06:00 left, noon top) |
| **B** half-dial horizon | 112x76 | 66x64 | a half-disc sky with hour ticks, the sun and moon wheeling over it, a strip under it with a 24 h track (daylight span lit, gold caret at now) and the clock |
| **C** scrolling sky band | 200x62 | 66x64 | the sky of the hours around now (±6 h, phones ±4 h) in columns, the light's path curve, stars in the night hours, a gold needle at now with the sun or moon riding it, a tab under it with the phase, the clock and the next phase's countdown (desktop) |

Shared by all three: a sky gradient keyed to WorldLighting's phase times; sun up 06:14–18:14 and the moon
opposite it; stars fade in over ~36 s after sunset and out before sunrise, twinkling; a ~14 s flourish
either side of sunrise and sunset (turning sun rays, a horizon glow, the rim flashing gold). The tap label
(phase, clock, time to next phase, closes after 4 s) is unchanged. Roboto Condensed via `UiTokens.ui_face`.

Every face docks where the old disc did (the minimap's bottom-left edge, 4 px off it), so nothing else
moved. The minimap's top-left corner, where HUDRULES puts the orders badge, stays clear. On phones every
face is 66 px wide so it stays inside the map column `UiTokens.hud_reserved` keeps clear (234 px in from
the right).

Cost: geometry is built on layout only. The sky is one `canvas_item_add_triangle_array` call whose colours are
written into a preallocated array. The strings are rebuilt once a game minute. It redraws every frame only
while stars or a flourish show, otherwise every 15 game seconds.

`hunt_hud.gd` hook (one line): the DEBUG hex under the dial uses `_daynight.size.y` (the `DISC` const is
gone). New lab: `game/scripts/dev/daynight_lab.gd` / `game/scenes/dev/daynight_lab.tscn`.

## Owner review files (`docs/orchestration/reports/daynight/`)

Per variant `v` in a, b, c:
- `daynight_<v>_1600x900_day.png`, `daynight_<v>_844x390_day.png`: 2x2 panels, dawn 06:00 / noon / dusk
  18:00 / midnight (row-major), on the real HUD over the home island.
- `daynight_<v>_1600x900_sunrise.png`, `daynight_<v>_844x390_sunrise.png`: 8 frames, 05:24 to 07:04.
- `daynight_<v>_1600x900_day.mp4`, `daynight_<v>_844x390_day.mp4`: a day in 10 s (each 0.3–0.4 MB).

Re-capture: `--resolution 1600x900 -- --lab=daynight_lab --shot-dir=DIR [--variants=a,b,c] [--video]`,
then ffmpeg the `frames_*` folders (command in the lab header).

## Gates

- `t_daynight` PASS. New checks: each face draws over 96 steps of a day. By day the sun is up in the face
  and the moon is not; by night the moon is up and the sun is not. Stars never show by day (for C: never
  while the band holds only day hours). The clock text matches. A and B's sun runs east to west; C's sun rides
  the needle, highest at noon. Each face is docked, inside a `hud_reserved` zone and off
  `HudLayout.taken_rects` at 1600x900, 844x390 and 390x844. 120 night frames redraw each frame with no
  object or static-memory growth, and a source scan finds no allocating code in any `_draw*`.
- `t_fieldhud` PASS with each of `--daynight=a`, `b`, `c` (0 overlaps at 1600x900 and 844x390, idle and combat).
- `t_ui` PASS, `t_uiicons` PASS, run_all `[tests] PASS`, `bash tools/smoke.sh --no-import` SMOKE PASS.

## Assumptions

- `# ASSUMPTION:` sunrise and sunset sit halfway through dawn and dusk (06:14, 18:14). The PRD only names
  the phases. Time rules are untouched.
- No moon phases (not in the PRDs): the moon is a full disc with two craters.

## Risks / next

- On phones the three faces share a 66x64 box, so B and C are less distinct there than on desktop (C's
  band shows ±4 h and drops its side texts).
- The sky colours are hand-keyed in the dial (`SKY_KEYS`), not read from lighting.json, so a lighting
  retune will not move them.
- Desktop B is 76 tall and its top edge is 6 px under the desktop quest card (which ends at y 106) (t_fieldhud passes). If the quest card
  grows, B is the face that collides first.
