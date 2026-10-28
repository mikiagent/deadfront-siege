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

## Round 2 (2026-10-28): real lightning, rain modes, the Wet effect, rain on fires, smoke inhalation

The owner asked for five more things:
- "sometimes make the thunder and lightning closer together, sometimes further apart. Spawn actual lightning strike and use the position from the lightning strike to determine this"
- "make the rain have different modes: drizzle, rain, pouring (heavy rain)"
- "the same way we have effects for bleed and poison, there should be an effect for wetness"
- "have rain affect fire somehow" / "fires under a roof will build up smoke though"
- "the smoke should make you take damage tbh"

All five are on `claude/mmo-weather`, with canon merged in. The dial changes live in this branch, because canon already has the dial.

- **Lightning strikes** (`world_weather.gd` `strike_at`, `lightning_bolt.gd`)
  - Every strike lands at a real ground point around the survivor. The distance is drawn from bands in `rules.json` `lightning_bands`:
    - close: 20 %, 6-40 m;
    - mid: 55 %, 40-700 m;
    - far: 25 %, 0.7-2.5 km.
  - Thunder lands the strike's horizontal distance / 343 m/s after the flash. A near strike claps at once; one 2.5 km away claps 7.3 s later.
  - The rumble shake falls with log distance. The test measured 0.12 m at 12 m, 0.035 m at 300 m and 0.007 m at 2 km. It is still clamped and still off with `--reduce-shake`.
  - Each strike spawns a `LightningBolt` at the ground point:
    - a jagged emissive ribbon from 70 m up, with two branches;
    - a ground flash;
    - a scorch mark that fades out over 6 s, after which the node is freed (at most 3 alive at once).
  - The bolt is built from unshaded additive quads, so it is safe on gl_compatibility. There are no decals.
  - A no-shadow `LightningLight` lights the scene from the strike's direction. The earlier sun pulse is gone.
  - `lightning(position, distance_m)` now carries the strike's position. `WorldWeather.last_strike` holds it too.
  - The dial draws its bolt on the side the strike landed (`DayNightDial.strike_side`).
  - **ASSUMPTION:** strikes damage nothing.
- **Rain modes** (`rules.json` `weather.rain_modes`, `default_modes`, per-climate `modes`)
  - Drizzle, rain and pour each set their own particle share (0.25 / 0.55 / 1.0 of 900), drop size and speed, darkening (0.3 / 0.65 / 1.0) and wet-ground strength.
  - The terrain shader reads the `weather_wet` global, which darkens the ground and gives it a sheen.
  - Only pouring rain makes splashes. Storms are pouring rain plus lightning.
  - `WorldWeather.rain_mode` / `rain_level()` expose the mode, and `rain_mode_changed` is the sound hook.
  - `--weather=drizzle|rain|pour` holds a mode.
  - The dial draws a third, two thirds or all of its streaks per mode, longer and faster as the mode gets heavier. Its clouds follow `rain_amount`.
- **Wet** is now kind `effect`, shown as a box beside her instead of a chip under the vitals.
  - It has a new `water_drop` glyph (made with the icon `_src` generator) and is `UiTokens.WET` #4a9fe0, blue rather than green.
  - On her body it shows `water` drip particles and a blue sheen. Pressing or hovering the box shows a tooltip (`StatusFx.input` / `draw_tip`).
  - Rain soaks her to 1, 2 or 3 stacks by mode, and water to 3.
  - Each stack lasts 60 s in the open. She dries faster in heat (4x at full heat) and within 4 m of a burning fire (+4x). Measured: 178 s in the open, 45 s in heat, 36 s by the fire.
  - Wet keeps heat fatigue x0.8. It adds cold fatigue and the cold look x1.3 (PRD :284) and makes resting recover x0.85. **ASSUMPTION:** the 0.85.
- **Rain on fires** (`game/scripts/world/fire_weather.gd`, `rules.json` `fire_weather`, all numbers ASSUMPTION)
  - An unsheltered fire burns fuel and wears faster by mode. The stone firepit feels half of that extra.
  - Only pouring rain and storms soak a fire. A bonfire or campfire goes out in about 90 s of pouring rain (60 s in a storm); the firepit takes about 5 min.
  - In the rain the flame shrinks and sputters and steam rises off it. `WorldWeather.fire_out` is the hiss hook.
  - A roof or ceiling over the fire's module keeps all of this off.
  - Lighting a fire is blocked in pouring rain without a roof: the build ghost reason `too_wet`, and no loading wood into a cold firepit. Plain rain does not block it.
- **Smoke under a roof**
  - Smoke pools toward 0.15 + 0.85 x enclosure over 90 s, and clears in 12 s once the fire is out or the space is open.
  - Enclosure counts walls (1), windows (0.8) and doorways (0.5) on the four edges of the fire's module. A roof with no walls stays at 0.15, so an open-sided shelter vents.
  - The smoke shows as two grey sheets under the roof.
  - From a density of 0.3, a survivor under the roof within 3 m gets **Smoke Inhalation** (`smoke_inhalation`):
    - an ash-grey #9a9a9e effect box with a smoke-cloud glyph, cough puffs, and grey tick numbers (the tick colour follows the status colour);
    - the tooltip reads "Breathing thick smoke hurts you ... Ventilate the space or leave it.";
    - 0.4 Health a second per stack, with stacks 1-3 rising with density;
    - it ends 3 s after she leaves.
  - **Shortcut:** only the fire's own module counts as the enclosed space.

Tests: `t_weather` covers all of the above:
- thunder delay = distance / 343 for every strike, and a visible bolt node at the strike position;
- shake falls with distance, every bolt is freed, and the node count does not grow;
- drizzle < rain < pour in particles, drop length, darkening and wet ground, with splashes only in pour;
- rain applies Wet by mode, and she dries faster by a fire and in heat; the box, drips and tooltip show and are gone when dry; Wet is not green;
- fuel drain is ordered drizzle < rain < pour, and the firepit burns slower than a bonfire;
- only pour and storm put a fire out in 150 s; the firepit survives 150 s of pour and goes out in about 5 min;
- a roofed fire burns as if dry;
- smoke pools under walls and vents under an open roof; damage rises with density, stops when she leaves, and clears once the fire is out;
- no lighting a fire in pour in the open;
- the dial's bolt follows the strike side.

`t_daynight_dial` adds a check that drizzle < rain < pour in streaks, alpha and clouds.

`t_controls` now uses Dirty for its status-row case, because Wet is a box now. `t_statusfx` accepts the new `water` and `cough` presets.

Round 2 captures, in `docs/orchestration/reports/weather/round2/`:
- `rain_drizzle_1600x900.png`, `rain_rain_1600x900.png`, `rain_pour_1600x900.png`.
- The pour shot also shows the Wet x3 box and her sheen, a bonfire in the rain, a smoky three-walled shelter (`--fire`), and steam off the camp fire.
- `strike_near_bolt_1600x900.png`: a 7 m strike with its bolt in view.
- `strike_near_6frames.png`: flash, the second stroke, afterglow and the scorch mark; the thunder is near-instant.
- `strike_far_6frames.png`: a 1.5 km strike, with 4.4 s from the flash to the clap.
- `weather/storm_near_far_strikes.mp4`: 11 s, a near strike then a far one.

Round 2 risks:
- From the iso camera, only strikes within about 12 m of her are on screen. Mid and far strikes show as the flash, the directional light and the dial's bolt.
- The smoke sheets inside a walled shelter read weakly from outside, because the walls fade for occlusion. I did not tune that.
- `t_rest`'s "Stomachache walk to the bedding" check fails on canon 22594181 as well, so it was not caused by this round.
- The `weather_wet` shader global was added to `project.godot`.

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
