# HUD-DAYNIGHT: day/night dial beside the minimap (Claude, 2026-10-20)

Owner: "We don't have the day/night cycle component in the UI next to the map". Spec: `docs/design/durango-prompts/16_hud_day_night_dial.md`. Reference: `docs/reference/durango-hud-daynight.webp`.

Branch `claude/mmo-hud-daynight`, work tree `.claude/worktrees/mmo-hud-daynight`. No Meshy or Tripo credits spent.

## What shipped

- `game/scripts/ui/day_night_dial.gd` (`class_name DayNightDial`, 155 lines). A 48 px round dial with a 24-hour face: midnight at the bottom, 06:00 left, noon at the top, 18:00 right. By day the warm sun sits at the end of a white needle. By night the pale crescent moon sits opposite the sun, so it stays in the upper half. The disc is tinted by phase (night navy, dawn mauve, day blue, dusk brown), with a darker lower half and a faint horizon line. The ring, needle and hub are white because the dial is a control.
- A tap or click opens a label to the left of the disc, for example `Day` / `Dusk in 4 min` or `Night` / `Dawn in 4 min` (`Night in 33 s` under a minute). A second tap closes it. Otherwise it closes after 4 s. The control grows leftwards while the label is open, so the HUD's block checks and `taken_rects` cover the label too. It is `FOCUS_NONE`, like the HUD hexes and the minimap.
- It reads the clock in one place only, `DayNightDial.clock()`, which returns `Vector2(Game.time_of_day, Game.day_length_seconds)`. **Online swap:** change that one line to return the server's clock. Nothing else reads time. Phases use `Game.phase_name()`'s thresholds through the `WorldLighting.DAWN/DAY/DUSK/NIGHT` constants that t_lighting already pins to `phase_name()`. The dial never sets the clock (PRD:289).
- `game/scripts/core/game.gd`: a `--tod=<0..1>` user arg that sets the starting time of day for labs and shots. One `elif`. It exists for the night shots.
- `game/tests/t_daynight_dial.gd` (see Test).
- Hooks patch `docs/orchestration/reports/claude-mmo-hud-daynight-hooks.patch` for the W1-UI files (not committed on this branch):
  - `hunt_hud.gd` (+5/-1): `_daynight` var, built after the minimap, and `_daynight.place(_minimap.position + Vector2(-12, 80))` in `_layout()`, so it is laid out again on every `size_changed`. The desktop DEBUG hex, shown only with the debug overlay, moves under the dial. It used to sit where the dial is and on the quest card's last line.
  - `ui_tokens.gd`: `hud_reserved()` widens the landscape right column from 190 to 240 px and the portrait map column from 178 to 240 px. Gather and station radials therefore keep off the dial, whose left edge is 230 px in from the right. The desktop zone already covers it. The t_ui zone checks still pass.
  - `ui_real_capture_lab.gd` (+8/-1): after the `hud` screen it opens the dial's label, gates every HUD block again as `hud_daynight` and saves `hud_daynight_<size>.png`. The PASS line lists `hud_daynight`.
  - `hud_layout.gd`: no change needed.

## Placement, and why it differs from the reference

In the reference the dial sits at the minimap's upper-left. On our desktop and landscape layouts the quest card already fills that spot: it runs from the left of the map at the map's top, 72 px tall. The dial therefore sits directly left of the minimap and under the quest card. Its right edge lines up with the card's right edge (12 px from the map) and its top is 8 px under the card (map top + 80). Positions:

| Canvas | Minimap | Dial (closed) | Dial with label open |
|---|---|---|---|
| 1600x900 | 1430,34 154x154 | 1370,114 48x48 | 1254,114 164x48 |
| 844x390 | 674,34 | 614,114 48x48 | 505,114 157x48 |
| 390x844 | 220,34 | 160,114 48x48 | 51,114 157x48 |

A label under or beside a dial at the map's top would have covered the quest card. The label always opens into free space. `# ASSUMPTION:` choices, all ours: this position, the tints and the sun/moon colours, the 24-hour face orientation, the label wording and its countdown in real minutes/seconds (`next phase share x Game.day_length_seconds`), and the 4 s auto-close. The existing `09:42 day` line under the coordinates is kept. The owner did not ask to remove it.

## Test

`game/tests/t_daynight_dial.gd`: the phase at time of day 0.0/0.25/0.5/0.75 is night/dawn/day/dusk, both from `phase_at` and from `Game.phase_name()`. `phase_at` agrees with `phase_name()` at 200 times across the day. It checks the label text at 0.5, 0.79 and 0.9 (over midnight), that the sun is warm and the moon pale, and that the HUD has `_daynight` as a child. At 1600x900, 844x390 and 390x844 the dial must be at least 44 px, inside the view, just left of the minimap and within its height after a resize, and off the minimap. A pushed click opens the label leftwards, still in view and off the map, and a second click closes it. The label also closes itself after 4 s. "Never writes time": Game's processing is stopped, the clock is set to 0.4, and after every resize, click and process it must still read exactly 0.4. The dial's source also contains no assignment to `time_of_day` or `day_length_seconds`.

- Without the hooks (head, `git apply -R` the patch): `[t_daynight] FAIL HuntHud has no day/night dial (_daynight) beside the minimap`, exit 1.
- With the hooks: `[t_daynight] PASS`, exit 0.

## Gates (on `e6ce221d` = this branch merged with `claude/mmo-overhaul` c5c920e7, hooks patch applied; each line seen)

- Every `game/tests/t_*.gd`, exit 0: t_ai, t_build, t_canim, t_combat, t_data (`PASS items=223 recipes=155`), t_daynight_dial, t_harbour, t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (`PASS`, its 5 deliberate SCRIPT ERRORs), t_server_domain, t_srvdom, t_structart, t_tame, t_ui (`engine errors/warnings during the checks: 0`), t_uiicons, t_web.
- `run_all.gd`: `[tests] PASS`.
- `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS`.
- `ui_real_capture_lab`, windowed, `--tod=0.4` (day) and `--tod=0.9` (night): `[uireal] PASS screens=hud,hud_daynight,craft,...` with exit 0 and no ERROR lines, at 1600x900 and 844x390, in Forward+ and in gl_compatibility (8 runs).
- `git apply --check` of the hooks patch on `claude/mmo-overhaul` c5c920e7: exit 0 (checked against that commit's tree).

Not gated, and failing the same way without this package: `ui_real_capture_lab` at 390x844 (4 FAILs: a radial hex on SKILLS, `the wild creature shows a plate`, the resize_back skills panel 760 px wide) and at 667x375 (1 FAIL: a radial hex on the level line). The FAIL lines are identical with and without the hooks (run on `5026e1b9`). In both runs the dial and its open label pass every `hud`/`hud_daynight` block check.

## Shots

`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/daynight/deliver/`: `hud`, `hud_daynight` (label open) and `combat` at 1600x900 and 844x390, day and night, Forward+ (`fwd_*`) and gl_compatibility (`gl_*`), plus dusk (`fwd_1600x900_dusk_*`), dawn (`gl_1600x900_dawn_*`), `fwd_390x844_day_hud_daynight_390x844.png`, `fwd_667x375_night_hud_daynight_668x376.png` and the reference as PNG. I opened each one. The first parallel `fwd 1600x900 day` run saved a stale frame (the craft screen) as its hud shots. I re-ran it alone, and the shots in `deliver/` come from that re-run.

## For the next agent

- Integrator: merge this branch, then `git apply docs/orchestration/reports/claude-mmo-hud-daynight-hooks.patch`. t_daynight_dial fails until the patch is in. That is its "old code" check.
- Online play: replace the body of `DayNightDial.clock()` with the server's time of day and day length.
- `--tod=` works for any lab: `-- --lab=ui_real_capture_lab --tod=0.9`.
