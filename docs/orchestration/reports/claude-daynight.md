# DAYNIGHT — day/night widget redesign (Claude, 2026-10-28)

Owner, verbatim: "I don't like the day/night cycle UI and I want you to improve it and animate it so it
looks cooler please". Round 1 built three faces. The owner looked at them in game: "bar version is
visually impressive but too big. Semi circle one is the right size and shape but I wish it was
flashier/more artistic somehow". Round 2 (this report) keeps only the half-dial, at the same size and
shape, and makes it as rich as the bar. Faces A (hex) and C (band) and the `--daynight` switch are gone.
Branch `claude/mmo-daynight`, with `claude/mmo-overhaul` merged in and imported. Not merged or pushed.

**Round 3 (weather), owner: "oh can you make the day/night cycle also reflect the current state of the
weather?? that would be awesome".** This branch now includes the weather package: `claude/mmo-weather`
(head ae27b025) is merged in. **Merging day/night also merges weather.** The one conflict, in
`docs/current/world-biomes.md`, kept both sections. The dial reads the weather by property name from
`World.runtime.weather` (or a `weather_source` set by tests and labs), never through the `WorldWeather`
class, so on a tree without weather it draws clear.

- **Rain** (`rain_amount`): the sky greys toward overcast and the sun is veiled. Clouds turn grey and
  three more roll in. Fine slanting streaks fall inside the dial.
- **Storm** (`storm` plus `rain_amount`): the clouds turn black and swell. Streaks get longer, faster and
  more slanted. The sky flickers with `WorldWeather.flash`, so it is synced to the game's double
  flicker, and each strike draws a new jagged bolt. The dial's own storm share eases over 2 s.
- **Heat** (`heat`): an orange haze, strongest at the horizon. The far hills haze over, the hill line and
  treeline shimmer, and the sun's corona grows.
- **Cold** (`cold`, `frost`): the sky pales. Frost spikes and a pale rime creep around the rim, and the
  gold cools to steel as `frost` builds.

Intensity follows the weather's own eased strengths, and any change in weather queues a redraw. The draw
redraws every frame while rain, heat or a flash shows. Cost: about 100 µs a draw headless for a storm at
night mid-strike, against the 600 µs budget, with no memory growth.

New review files in `docs/orchestration/reports/daynight/`:
- `daynight_weather_1600x900_noon.png` and `daynight_weather_844x390_noon.png`: clear, rain, storm
  mid-strike, heat and cold at noon.
- `daynight_weather_1600x900_cycle.mp4`: 10 s cycling clear → rain → storm (three strikes) → heat →
  cold, blending (0.2 MB).

I looked at each round of captures and fixed what I saw:
- The rain sun was too bright. It is veiled now.
- Frost was invisible. A cold change alone never queued a redraw; any weather change now does, and the
  spikes are larger.
- The storm lingered through the heat segment of the video. The lab now eases the storm as over about
  10 s of play.

Tests in t_daynight:
- with no weather to read, the dial draws clear;
- clear shows nothing;
- rain shows streaks and overcast with no bolt, and 0.3 rain draws less than 0.7;
- a storm is heavier than rain with no bolt between strikes, and a strike (flash 0.8) draws a bolt;
- a storm eases in (under 0.2 after 0.1 s);
- heat shows haze that scales with strength and nothing else;
- cold shows frost and nothing else;
- a storm at night mid-strike stays under budget with no memory growth.

Gates for round 3, all PASS: t_daynight (97–114 µs a draw), t_fieldhud, t_ui, t_uiicons, run_all
`[tests] PASS`, smoke SMOKE PASS. t_weather (from the weather package) failed once ("cold -> clear: one
shiver on defrosting") and then passed twice on this branch and twice on `claude/mmo-weather` itself. That
looks like a flaky timing check in the weather test, not something the dial causes (the dial only reads
WorldWeather).

**Round 4 (canon merge went red).** The canon merge of 47bfeda9 failed t_levelfx at 844x390: the skill
level-up row sat at y 260 instead of 114. I merged `claude/mmo-overhaul` (through TREADMILL d729b6a6) and
imported, then tried to reproduce. On my merged branch, t_levelfx passed 3 times in a row, 3 times run in
parallel to load the machine, and once each with the weather held at rain, storm, cold and heat. A merge
of 47bfeda9 onto the pre-TREADMILL canon (5a748b0c) and a tree with a stale class cache (no import) both
passed too. I could not reproduce the failure.

The dial is not on the feed's path. At 844x390 the dial is 604-670 x 124-188 and the feed column is
340-576 x 114-150. TopFeed centres the column left of the dial, so the dial's 6 px of extra width moved the
column 3 px left (x 343 to 340), which matches the failing rect's x.

The likely cause is the step just before that check. It calls `GatherFeedback.show_yield` with a rare find,
which raises the "Rare find: Resin" and "Rare trait: Black Sheen Stone" notices. Notices are drawn before
the feed at the top centre, and by design the feed hangs below them. When one is still up, the skill row
drops below it. That depends on timing, so a slow or loaded run can fail. My fix: t_levelfx clears the
HUD's notices together with the feed before the skill-row check, so that check tests the feed alone. No
game code changed for this.

## What shipped (round 2)

`game/scripts/ui/day_night_dial.gd` is one face, a gold-rimmed half-dial: 112x76 on desktop and 66x64 on
a phone. It docks where the old dial did, at the minimap's bottom-left edge, and HUDRULES' orders badge
corner stays clear. What it draws:

- **Painted sky.** A 69-vertex half-disc mesh with per-vertex colour:
  - a zenith-to-horizon gradient keyed to WorldLighting's phase times;
  - a warm glow around the sun, stronger near the horizon;
  - a rose band that climbs through sunrise and sinks through sunset;
  - a pulsing bloom for about 14 s either side of each.
- **Clouds.** Three soft clouds drift across with the game hours. Each has a shaded underside and fades
  out before it reaches the rim. They are white by day, rose at dusk and faint slate at night.
- **Sun.** A corona, eight turning rays (long at sunrise and sunset) and two faint lens-flare glints on
  desktop. The corona and rays are clamped inside the rim.
- **Moon.** A halo and three craters. It rides the same arc, opposite the sun.
- **Stars.** They twinkle at night, and every few seconds there may be a shooting star.
- **Horizon.** Far hills and a near treeline (pointed crowns) drift at different speeds as the day turns
  (parallax). The hill tops are lit on the sun's side. Both flatten into the horizon near the rim.
- **Gold rim.** Engraved hour ticks: every hour on desktop, every three on a phone, with 06, 12 and 18
  longer. A gleam sweeps along the rim every 7 s, and about three times as often at sunrise and sunset.
- **Strip under the dial.** A 24 h track (night blue, dawn and dusk orange, day gold) with a glowing gold
  caret at now, and the clock.
- **Unchanged.** The tap label, the clock read (never written), and the time rules.

**Cost.** Each draw is three triangle-array calls (sky, hills, trees) and the track, plus about 60 small
draw commands. It measures 56-72 µs a draw headless in t_daynight; the budget I set is 600 µs. It
redraws every frame only while stars, a flourish or the gleam show; otherwise it redraws every 15 game
seconds. All arrays are built on layout and written in place, and nothing allocates in the draw.

`hunt_hud.gd`: a one-line hook. The DEBUG hex sits under `_daynight.size.y`.
`game/scripts/dev/daynight_lab.gd` captures the dial. `docs/current/hud.md` is updated.

## Owner review files (`docs/orchestration/reports/daynight/`)

- `daynight_1600x900_day.png` and `daynight_844x390_day.png`: 2x2 panels of dawn 06:00, noon, dusk 18:00
  and midnight, on the real HUD over the home island.
- `daynight_1600x900_sunrise.png` and `daynight_844x390_sunrise.png`: 8 frames from 05:24 to 07:04.
- `daynight_1600x900_day.mp4`: a day in 10 s at 2x (0.47 MB).

I looked at each round of captures and fixed what I saw:
- Sun coronas, rays and a rim-end glow spilled outside the dial at sunrise and sunset. They are now
  clamped inside it, and the rim-end glow is gone.
- A purple flare blob under the noon sun. The flare is now two faint warm glints.
- Grey night clouds dirtied the moon. They are fainter at night.
- The treeline was too flat to read. It is taller now.

## Gates

`t_daynight` PASS, with these single-face checks:
- the face draws over 96 steps of a day;
- the sun is up by day and the moon by night, and never both;
- no stars by day;
- the clock text matches the game's clock;
- the sun moves east to west;
- the dial is docked, inside a `hud_reserved` zone and off `HudLayout.taken_rects` at 1600x900,
  844x390 and 390x844;
- 120 night frames redraw every frame with no object or memory growth, under 600 µs a draw;
- a source scan finds nothing that allocates in any `_draw*` function.

`t_fieldhud` PASS (0 overlaps at 1600x900 and 844x390, idle and combat), `t_ui` PASS, `t_uiicons` PASS, run_all `[tests] PASS`, `bash tools/smoke.sh --no-import` SMOKE PASS.

## Assumptions and risks

- `# ASSUMPTION:` sunrise and sunset fall halfway through dawn and dusk (06:14 and 18:14).
- `# ASSUMPTION:` 600 µs is the draw budget for one animated HUD widget.
- No moon phases: they are not in the PRDs.
- The sky colours are hand-keyed in the dial, not read from lighting.json.
- Shine effects (twinkle, gleam, shooting stars, ray spin) run on real time. Sky, clouds, hills and the
  bodies follow the game clock.
- On a phone (66x64) the detail is small. The face is the same apart from three-hourly ticks and no flare.
