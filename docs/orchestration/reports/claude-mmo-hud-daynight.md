# HUD-DAYNIGHT: day/night dial docked to the minimap (Claude, 2026-10-20, fixes 2026-10-21)

Owner: "We don't have the day/night cycle component in the UI next to the map". Spec: `docs/design/durango-prompts/16_hud_day_night_dial.md`. Reference: `docs/reference/durango-hud-daynight.webp`.

Branch `claude/mmo-hud-daynight`, work tree `.claude/worktrees/mmo-hud-daynight`. No Meshy or Tripo credits spent.

## Pre-merge fixes (orchestrator's ruling after the blind judge, 3-0, and review minors)

| # | Ruling | What changed |
|---|---|---|
| 1 | Dock the dial to the minimap frame, 56-64 px at 1600x900, >= 48 px at 844x390, minimap/coordinates/quest card/END untouched | `DISC` 48 -> 60 px at every size. `dock(map_rect)` replaces `place()`: the disc's right edge is 4 px left of the minimap frame and its bottom is level with the frame's bottom (the reference docks at the top-left; our quest card holds that spot). At 1600x900 the dial is at 1366,128; at 844x390 it is at 610,128. The minimap, the `X Y` line, the quest card and End Combat do not move. |
| 2 | Sun or moon disc on a clear arc instead of the needle | The needle and hub are gone. A white arc (the upper half, 0.4 rad past each horizon) carries the sun disc with a glow by day and a crescent moon, opposite the sun, by night. The lower half is darkened as ground, so the arc's ends dim below the horizon. |
| 3 | Keep the HUD's `08:30 day` line only if it adds information | Dropped (hooks patch): the dial already shows the phase. The clock moved into the dial's label (`Day  09:42` / `Dusk in 4 min`), formatted like `Game.clock_label()`. `drawn_blocks["map_text"]` now covers only the `X Y` line. |
| 4 | Toggle only when the release is inside the dial | The press arms the dial, and the release toggles it only if `_has_point(release)`, as BaseButton does. A touch and its emulated mouse still toggle once. |
| 5 | Countdown never reads `60 s` or overstates by a minute | Under 60 whole seconds it counts seconds (1-59 s, ceil). From 60 s on it shows `roundi(secs / 60)` minutes, never more than 30 s off. The old code used `ceil`, so it read 59.5 s as `60 s` and 61 s as `2 min`. |
| 6 | `--tod=` out of core `game.gd` | Removed from `game.gd` on this branch. The hooks patch adds it to `LabKit.build()` (labs only); `ui_real_capture_lab` uses `LabKit`. |

## What ships

- `game/scripts/ui/day_night_dial.gd` (`class_name DayNightDial`). A 60 px round dial with a 24-hour face: midnight at the bottom, 06:00 left, noon top, 18:00 right. The sky is tinted by phase (night navy, dawn mauve, day blue, dusk brown). The ring and arc are white because the dial is a control; the sun and moon carry the colour. A tap opens a label to the left of the disc with the phase, the clock and the time to the next phase. A second tap closes it, and so does a 4 s timeout. While open, the control grows leftwards, so the HUD's block checks and `taken_rects` cover the label. `FOCUS_NONE`, like the HUD hexes.
- The dial reads time in one place only, `DayNightDial.clock()`, which returns `Vector2(Game.time_of_day, Game.day_length_seconds)`. **Online swap:** change that one line to return the server's clock. Phases use `Game.phase_name()`'s thresholds through `WorldLighting.DAWN/DAY/DUSK/NIGHT`, which t_lighting pins to `phase_name()`. The dial never sets the clock (PRD:289).
- `game/tests/t_daynight_dial.gd` (see Test).
- Hooks patch `docs/orchestration/reports/claude-mmo-hud-daynight-hooks.patch`, for files this package does not own. It is not committed here. It was regenerated on this branch after merging `claude/mmo-overhaul` ddaab662, and `git apply --cached --check` on ddaab662's tree exits 0 with no offsets.
  - `hunt_hud.gd`: adds the `_daynight` var, built after the minimap. `_layout()` calls `_daynight.dock(_minimap.get_rect())`, so the dial is laid out again on every `size_changed`. The desktop DEBUG hex (shown only with the debug overlay) moves under the dial. The `clock  phase` line under the coordinates goes.
  - `ui_tokens.gd`: `hud_reserved()` widens the landscape right column from 190 to 240 px and the portrait map column from 178 to 240 px. Gather and station radials therefore keep off the dial, whose left edge is 234 px in from the right.
  - `ui_real_capture_lab.gd`: after the `hud` screen, opens the dial's label, gates every HUD block again as `hud_daynight` and saves `hud_daynight_<size>.png`.
  - `lab_kit.gd`: `--tod=<0..1>` sets the starting time of day for any lab built with LabKit.

`# ASSUMPTION:` choices, all ours, because the PRDs are silent: the docked position, the tints and the sun/moon colours, the 24-hour face orientation, the label wording, the countdown in real minutes/seconds (`next phase share x Game.day_length_seconds`), and the 4 s auto-close.

## Test

`game/tests/t_daynight_dial.gd` checks the following:

- **Phases.** The phase at 0.0/0.25/0.5/0.75 is night/dawn/day/dusk, both from `phase_at` and from `Game.phase_name()`, and the two agree at 200 times across the day.
- **Label lines.** `Day  12:00` / `Dusk in 3 min`, `Dusk  18:57` / `Night in 8 s`, and `Night  21:36` / `Dawn in 4 min` across midnight.
- **Countdown.** Every quarter second from 0.25 s to 5 min before dusk: 1-59 s and never less than the real wait, then whole minutes at most 30 s off.
- **Colours.** The sun is warm and the moon pale.
- **Layout.** At 1600x900, 844x390 and 390x844 the dial is at least 56 px on desktop (48 on a phone), inside the view, docked (its right edge 4 px from the minimap and its bottom level with the minimap's), and off the minimap after a resize.
- **Taps.** A click opens the label leftwards, in view and off the map, and a second click closes it. A press released 200 px away does not open it. The label closes itself after `OPEN_S`.
- **Never writes the clock.** The clock stays at exactly 0.4 through all of the above, and the source has no assignment to `time_of_day` or `day_length_seconds`.

Run against the old code (89851516 with its own hooks patch, scratch tree `fix-hud-daynight-old`), exit 1. Among its FAIL lines:

- `FAIL noon on a 720 s day reads ["Day", "Dusk in 3 min"], want Day  12:00 / Dusk in 3 min`
- `FAIL the countdown misreads the wait: ["59.00 s -> 60 s", "59.25 s -> 60 s", ...]`
- `FAIL (1600, 900): the dial is (48.0, 48.0), want >= 56 px`
- `FAIL (1600, 900): the dial [P: (1370.0, 114.0), S: (48.0, 48.0)] is docked to the minimap [P: (1430.0, 34.0), S: (154.0, 154.0)]'s bottom-left edge ...`
- `FAIL (1600, 900): a press on the dial released off it opened the label (BaseButton cancels it)`

Without the hooks, it fails with `HuntHud has no day/night dial (_daynight) beside the minimap`. That is the integrator's check that the patch is in.

## Gates

Run on `dbd071bf` (this branch merged with `claude/mmo-overhaul` ddaab662) in the throwaway tree `mkscratch.sh fix-hud-daynight claude/mmo-hud-daynight <hooks patch>`, with the hooks applied. Each line was seen.

- Every `game/tests/t_*.gd` (23), headless through gslot, exit 0. The decisive lines:
  - t_ai, t_build, t_canim, t_combat, t_items, t_light, t_occlude, t_player, t_server_domain, t_srvdom, t_structart, t_tame, t_w2_skills, t_water, t_web: `PASS`
  - t_data: `PASS items=223 recipes=155`
  - t_daynight_dial: `[t_daynight] PASS`
  - t_harbour: `PASS islands=15`
  - t_iconart: `PASS`
  - t_lighting: `[t_light] PASS`
  - t_save: `PASS`, with its 5 deliberate SCRIPT ERRORs
  - t_ui: `engine errors/warnings during the checks: 0` then `[t_ui] PASS`
  - t_uiicons: `PASS ids=177 ...`
- `run_all.gd`: `[tests] PASS`, exit 0.
- `tools/smoke.sh --no-import`: `SMOKE PASS`, exit 0.
- `ui_real_capture_lab`, 8 windowed runs: Forward+ and gl_compatibility, at 1600x900 and 844x390, with `--tod=0.4` and `--tod=0.9`. Each printed `[uireal] PASS screens=hud,hud_daynight,craft,...`, exit 0, with no `SCRIPT ERROR`/`ERROR` lines.
- The same tree without the `hunt_hud.gd` hook: `[t_daynight] FAIL HuntHud has no day/night dial (_daynight) beside the minimap`, exit 1.

## Shots

`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dn2/deliver/` holds `ui_real_capture_lab` shots with `--tod=0.4` (day) and `--tod=0.9` (night), in Forward+ (`fwd_*`) and gl_compatibility (`gl_*`), at 1600x900 and 844x390. For each run there are `hud`, `hud_daynight` (label open) and `combat` (End Combat showing). The folder also has 2x crops of the dial corner (`fwd_1600_day_hud.png` ... `gl_844_night_open.png`) and the reference as `reference_durango-hud-daynight.png`. All 8 runs print `[uireal] PASS screens=hud,hud_daynight,...` with exit 0 and no `SCRIPT ERROR`/`ERROR` lines.

I compared the crops with the reference. The dial now reads as a part of the minimap rather than of the quest card. The sun or moon on the arc reads at a glance, and the dial looks the same in both renderers. Nothing overlaps the quest card, the `X Y` line or End Combat (`combat_*`). The difference from Durango that remains is the corner: the reference sits on the map's top-left rim, and ours sits at the bottom-left because the quest card holds the top-left.

## For the next agent

- Integrator: merge this branch, then `git apply docs/orchestration/reports/claude-mmo-hud-daynight-hooks.patch`. t_daynight_dial fails until the patch is in.
- Online play: replace the body of `DayNightDial.clock()` with the server's time of day and day length.
- Day/night lab shots: `-- --lab=ui_real_capture_lab --tod=0.9` (any LabKit lab).
- Not gated, unchanged by this package: `ui_real_capture_lab` at 390x844 and 667x375 had FAIL lines with and without the hooks (first report, on 5026e1b9). They were not re-run for these fixes.
