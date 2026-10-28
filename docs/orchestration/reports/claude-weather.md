# WEATHER: storms, heat, cold, and mood idles (claude/mmo-weather)

Owner brief: "Rain / Rain and lightning (infrequent), ground shakes when thunder arrives (after lightning flash) / Heat (orange outline similar to red outline for combat, slightly shaking screen, like games set in the desert, it should look hot) / Cold (blue/white outline similar to red outline for combat, infrequent shaking screen (for becoming cold and defrosting), frost around the outside)". A follow-up asked for mood idle animations: cold shiver, heat fanning, tired, exhausted.

This is a visual direction for the owner to review before merging. Nothing has been pushed or merged.

## What shipped

- **State** (`game/scripts/world/world_weather.gd`)
  - Rain still applies Wet.
  - The island now rolls its climate's rain chance, and each rain spell can be a storm on a separate roll. Both chances live in `data/world/rules.json` under `weather.climates`.
  - In a storm, lightning strikes every 8-20 s at a distance of 400-3000 m. Each strike is a double flicker. Its thunder lands `distance / 343 m/s` later (1.2-8.7 s) and starts a rumble.
  - `lightning(distance_m)` and `thunder(distance_m)` are signals, left as hooks for sound. No audio exists yet.
  - Heat and cold come from `WorldWeather.temp_targets`, which reads the same `Player.climate_needs` and `climate_shortfall` values that climate fatigue charges:
    - heat shows only by day;
    - cold shows at any hour, and its unmet share counts outside the day phase;
    - Wet and Quenched cool the heat, and sitting by a fire warms the cold.
  - Frost creeps in behind cold over about 8 s and melts over about 5 s.
  - The survivor shivers when she gets cold (cold reaches 0.5), when she defrosts (frost falls below 0.2), and every 14-28 s while she stays cold.
- **Screen layer** (`game/scripts/world/weather_fx.gd`, `game/shaders/weather/`)
  - The layer is canvas layer -1, below every HUD layer. The HUD, its taken rects and the combat red edge (`StatusFx.draw_vignette`) always draw on top of it.
  - `weather_edge.gdshader` does not read the screen. It draws:
    - the rain's grey wash, darker in a storm and at the edges;
    - heat's orange edge, using the red edge's 14 % ramp, with a slow throb and a warm wash;
    - cold's blue-white edge;
    - rime frost that grows in from the borders, corners first, with a crust and a few glints;
    - the lightning flash.
  - `weather_shimmer.gdshader` is the heat shimmer. It reads the screen texture, makes rising waves that are stronger low on the screen, and applies a slightly bleached warm grade. It only runs on high quality while heat is above 0.01.
  - During a hunt, or while a status with a red edge is active (bleed, deep bleed), the weather edges drop to 35 % so the red edge reads first. `heat_bleed_1600x900.png` shows this.
  - A strike adds 1.8 x flash to the sun's energy (the moon's at night) after WorldLighting has run that frame (`process_priority` 100). Rain dims the sun by up to 50 %. Both changes are made on top of WorldLighting's values every frame, so they stay compatible with the held sky-shadow work.
- **Shake** (`game/scripts/camera/iso_camera.gd`)
  - `weather_offset` is added to the existing trauma offset and clamped to 0.2 m. The data cap `shake_m.max` is 0.15 m.
  - Thunder rumbles up to 0.12 m (about 8 px at 1600x900), heat sways up to 0.012 m, and a shiver is 0.05 m.
  - The game had no accessibility setting, so I added `IsoCamera.reduce_shake` (`--reduce-shake`). It turns off weather shake and combat trauma. No settings screen exists to expose it yet.
- **Debug**
  - `--weather=clear|rain|storm|heat|cold` holds one state, and `--weather-quality=low|high` picks the quality.
  - `scenes/dev/weather_lab.tscn` takes `--weather=`, `--island=`, `--bleed`, `--shot-dir=`, `--seq` (6 frames across one lightning and thunder beat) and `--perf`.
- **Mood idles** (`game/scripts/player/player_anim.gd`)
  - When the survivor stands still she plays, in priority order: `idle_exhausted` (fatigue 75 % and up), then `idle_cold` or `idle_heat` (weather feel 0.5 and up, whichever is stronger), then `idle_tired` (50 % and up), then plain `idle`.
  - If a clip is missing, the next one in line plays.
  - Idles blend into each other over 0.5 s. Moving and busy clips (roll, attack, hurt, gather) still win.
  - I merged the art thread's clips from claude/mmo-jaws (commit 42a96058) and added them to `RiggedModel.LOOPING`. The test checks that each clip loads, loops and plays.
  - `t_rest` and `sleep_lab` asserted `current_clip == idle`. They now accept any `idle*` clip, because a tired survivor stands in `idle_tired`.
- **Docs**
  - `docs/current/world-biomes.md` has a new Weather section with a per-climate odds and look table.
  - The section is also added to `tools/docs_wiki/gen_game_data.py`, so it comes back if the page is regenerated.

## Gates

Every gate passes, including after the merge:

- `t_weather` PASS
- `t_ui`, `t_fieldhud`, `t_statusfx`, `t_web`, `t_colors` all PASS
- `run_all` prints `[tests] PASS`
- `t_rest`, `t_player`, `t_tactical`, `t_canim` all PASS
- `bash tools/smoke.sh --no-import` prints SMOKE PASS

`t_weather` covers:

- each forced state sets the right overlay and parameters;
- every thunder clap lands within 1.5 frames of `distance / 343` after its flash (9 strikes in 2 simulated minutes);
- a flash lifts the sun by about 1.7 over WorldLighting's value;
- the shimmer runs only on high quality;
- frost grows, and there is one shiver getting cold and one defrosting;
- weather shake stays at or under 0.15 m in every state, and is 0 with reduce-shake, along with combat trauma;
- the layer sits under the HUD;
- bleed drops the edges to 35 %;
- the climate rules hold: desert is hot by day and neutral at night, savannah is milder, tundra is colder at night, grassland is neutral, and the desert never rolls rain in 40 checks;
- node count does not grow over 2 simulated minutes of storm (5631 before and after);
- the mood idle priority, the fallback when a clip is missing, all four real clips loading, looping and playing, moving overriding the idle, and a roll not being interrupted.

## Cost

Measured with `weather_lab --perf` on the dev Mac at 1600x900, comparing wall time with the layer drawn and hidden. GPU timers returned 0 on this machine.

| Renderer | State | Cost |
|---|---|---|
| Forward+ | heat, high quality | about +1.2 ms a frame (13.6 to 14.9 ms, and 11.5 to 12.6 ms) |
| Forward+ | cold | below the noise (8.33 vs 8.35 ms) |
| gl_compatibility | heat, high quality | no visible change, but every run sat at the 120 Hz vsync cap |
| gl_compatibility | cold | no visible change, same cap |
| gl_compatibility | heat, low quality | no visible change, same cap |

Turning vsync off did not take effect here, so the gl_compatibility rows show no difference only because the frame rate was capped.

The default quality is low on iOS and Android, which means no shimmer there. Everywhere else, including web, it is high. **I have not measured it on a phone.**

There were no credits, paid generation or Codex.

## PNGs

All are in `docs/orchestration/reports/weather/` and every file is 300 KB or less. The 1600x900 shots were resized to 1200x675 and palette-quantized.

- `storm_1600x900.png`: storm at the peak of a strike's flash.
- `storm_844x390.png`
- `heat_1600x900.png`
- `heat_844x390.png`
- `cold_1600x900.png`
- `cold_844x390.png`
- `heat_bleed_1600x900.png`: heat plus bleed, so the red edge shows over the weather's.
- `compat_storm_heat_cold_1600x900.png`: all three states on gl_compatibility.
- `seq/storm_seq_0..5.png`: the stroke, the second stroke, the afterglow, waiting, the thunder clap with the camera shifted, and the rumble.

## Assumptions (`# ASSUMPTION` in code)

- Per-climate odds: rain chance 1.0 where `climates.json` lists rain, otherwise 0. Storm share per rain spell: grassland 0.15, temperate 0.2, tropical 0.45, swamp 0.25, blue_tropical 0.5. Rain timing keeps the old "18 s every 50-90 s", and storms last 30-45 s.
- Look strength = severity (the climate's resistance need / 3, between 0.4 and 1) x (0.4 + 0.6 x the unmet share). This means a fully resisted survivor still sees a faint version of the effect.
- The cold and heat idles take over at a weather feel of 0.5. Tired and exhausted use spec 01's 50 % and 75 % fatigue tiers.
- The shimmer defaults to low on phones.

## Risks and open items

- The shimmer has not been measured on a real phone, and the phone default skips it.
- Snow, sandstorm, ash storm, fog and overcast are listed in `climates.json` but have no visuals yet.
- Rain no longer falls in dry climates. Before this change, rain fell on every island.
- `--reduce-shake` has no settings screen and is not saved.
- Strikes have no visible bolt in the sky. The flash is the screen plus the sun.
- The storm look is a subtle darkening at midday, and the flash at night has not been looked at.
- The `t_weather` mood-idle checks need the art clips from claude/mmo-jaws, which are now merged into this branch.
