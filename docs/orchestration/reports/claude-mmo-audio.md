# Audio layer: buses, AudioDirector, 456 CC0 sounds, hooks, tests

Date: 2026-10-18. Agent: Claude Code. Branch `claude/mmo-audio` (not pushed).

**No agent can listen. Every sound here was picked and processed from measurements (ffmpeg
envelopes, loudness, durations), not by ear. Subjective quality, the creature voice designs
above all, is unverified until the owner listens.** Fastest way: `godot --path game -- --lab=audio_lab`
plays every category in turn; then play normally with `-- --audio-log` to see what fires.

## What shipped

- `game/default_bus_layout.tres`: Master (HardLimiter, ceiling -0.8 dB) > Music -7 dB, Ambience -3 dB,
  SFX 0, Creatures 0, UI -4 dB. Godot loads it by its default path; `project.godot` is unchanged.
- `game/scripts/core/settings.gd` (`Settings`): tiny ConfigFile store at `user://settings.cfg`.
  `Game.audio.set_bus_volume(bus, linear)` scales a bus around its designed level and persists it;
  `bus_volume(bus)` reads it back for a future settings screen.
- `game/scripts/audio/`:
  - `audio_director.gd` (`AudioDirector`, at `Game.audio`, created on first use as a child of the
    Game autoload): `play(event, at = Vector3.INF, params)` with params `pitch`, `volume_db`,
    `delay`, `follow`. Voice pool: 12 2D + 32 3D players, at most 32 active, per-event
    `max_instances` (oldest instance restarts), per-event `cooldown`, priority stealing,
    out-of-earshot events never take a voice, no variation repeats twice in a row.
    `set_weather(kind, intensity)` (`rain`, `storm`, `wind`, `snow`, `sandstorm`, `ash_storm`,
    `clear`, or `auto`). `play_creature(node, species, kind)`. `attach_loop(event, host)` for
    campfires. `--audio-log` prints every event that gets a voice.
  - Listener: the iso camera sits 40 m from the survivor (`IsoCamera.distance`), so the camera is
    a useless ear (everything on screen is equally far). An `AudioListener3D` rides on the survivor
    at +1.2 m, rotated like the camera so screen-left is ear-left; inverse-distance attenuation with
    per-event `unit_size` (5 m small creatures to 18 m huge) and `max_distance` (28 m footsteps to
    120 m huge roars); pan strength 0.55 so the top-down view does not hard-pan.
  - `audio_beds.gd` (`AudioBeds`): crossfaded loops. Climate bed from `World.island_def.climate`
    and `Game.phase_name()` (night vs the rest, 6 s fade); shore surf rising over the last 30 m to
    `land_radius()`; weather layer from `island_runtime.raining` (storm climates get heavy rain and
    thunder every 12-35 s) unless `set_weather` overrides; bed ducks to 0.65 under rain.
    Music: explore and night tracks play once then leave 40-90 s of silence; combat loops.
  - `music_state.gd` (`MusicState`): combat starts after 0.8 s of sustained threat (or at once when
    the survivor deals or takes damage) and ends only after 10 s of calm.
  - `audio_hooks.gd` (`AudioHooks`): one `SceneTree.node_added` connection plus a scan of the
    existing tree. Hooks BaseButton/HexButton (click, or confirm/cancel by button word), the seven
    panel classes (open/close on `visibility_changed`), Player, Creature, HarvestNode,
    StoneProjectile, SiegeProjectile, Bonfire. Threat for music = `vitals.in_combat` or a creature
    within 35 m in alert/approach/attack/chase whose `brain.attack_target` is the survivor.
- `game/data/audio/events.json` (170 events + ambience/music maps), `creature_voices.json`
  (19 species), `credits.json` (every shipped file, every source). `game/assets/audio/` (456 .ogg)
  and `game/assets/audio/CREDITS.md`.
- `tools/audio/`: the reproducible build (`build_audio.py` recipes, `render.py` layer/pitch/trim/
  loop/normalise engine, `srcs.py` licence registry, `oggenc.py`). The downloads are not in git.
- Tests: `game/tests/audio_tests.gd`, one call from `run_all.gd`. Lab: `scenes/dev/audio_lab.tscn`.
- `HANDOFF.md` section 3: one line for `game/scripts/audio/`.

## Hooks added to other scripts (one-line emits, plus the signal declarations)

| File:line | Edit |
|---|---|
| `game/scripts/player/player_anim.gd:8` | `signal clip_played(clip)` |
| `game/scripts/player/player_anim.gd:199` | `clip_played.emit(resolved)` in `_play` (swings, rolls, knockdown, gather/chop/mine/craft clips, sleep down/up) |
| `game/scripts/player/player.gd:9-11` | `signal noticed(text)`, `item_gained(id, n)`, `context_used(id)` |
| `game/scripts/player/player.gd:2151` | `item_gained.emit(id, n)` in `toast()` |
| `game/scripts/player/player.gd:2159` | `noticed.emit(text)` in `notice()` |
| `game/scripts/player/player.gd:2215` | `context_used.emit(id)` in `context_action()` (drink) |
| `game/scripts/items/station_craft.gd:8` | `signal crafted(recipe_id)` |
| `game/scripts/items/station_craft.gd:300` | `crafted.emit(recipe_id)` in `_finish_one()` |
| `game/scripts/core/game.gd:32,207` | `var audio: AudioDirector` (lazy getter) and `ensure_audio()` |
| `game/scripts/core/main.gd:11` | `Game.ensure_audio()` so beds and music start with the playfield |
| `game/tests/run_all.gd:53` | one call into `tests/audio_tests.gd` |

Existing signals used without edits: `Vitals.damaged/died`, `Health.died`, `Creature.combat_float`
(hit/weak/strong/crit), `CreatureAnim.attack_windup`, `HarvestNode.depleted_tile`,
`SkillState.skill_changed` (sound only when a level goes up), `World.pioneer_changed`,
`CanvasItem.visibility_changed`, `BaseButton.pressed`, `HexButton.pressed`, `tree_exiting` on
projectiles. Polled: survivor velocity/floor/water for footsteps, `World.t_stones` (earn = stone
clack, spend = coins), creature `brain_state` edges (alert calls), idle-call timers, big-creature
footfalls from distance moved. `island_runtime.gd` is untouched (read only: `raining`,
`land_radius()`, `_tile_type_at_world()`).

Footstep surface: water when `in_water`; wood when a downward ray hits a `placed_building`;
otherwise the island tile (`SAND` sand, `SHALLOW`/`DEEP` water, `ROCK`/`ASH` stone, `MUD`/`WET`
mud, the rest dirt/grass, or snow on tundra/snowfield). Stride grows with speed (about three steps
a second). Gather kinds: `gather_kind()` chop/mine/gather plus dig (mud, clay, ground role),
butcher (corpse), craft, eat, picked from the survivor's current job, each delayed to the swing.

## Sources and licences

Licences re-checked this session from the saved source pages before use: Kenney `License.txt`
(CC0), BigSoundBank licence page ("Creative Commons CC0 1.0 Universal"), the OpenGameArt licence
field of every page (all CC0; the two pages that also list OGA-BY were not used), Wikimedia
Commons `extmetadata` (CC0 or Public domain; the three CC BY 3.0 candidates were not downloaded).
No source requires attribution or forbids commercial use; authors are credited anyway.

| Collection | Distinct source files used | Licence |
|---|---|---|
| BigSoundBank (Joseph Sardin) | 117 | CC0 1.0 |
| OpenGameArt (qubodup, rubberduck, caveboytup, starninjas, antumdeluge, zane-little-music, emopreben, thebardofblasphemy, eldritch-grim, pauliuw, artisticdude, peludo, trazzz123, nene, indieteur, celestialghost8, emmama) | 59 | CC0 1.0 |
| Kenney (impact, rpg, interface, ui, casino, music jingles) | 85 | CC0 1.0 |
| Wikimedia Commons (USFWS, NPS Yellowstone sound library, Felix Blume, schots, others) | 17 | CC0 1.0 or public domain |

Per-file rows: `game/data/audio/credits.json` (source URL, author, licence, original filename,
collection, download URL for OpenGameArt archives) and `game/assets/audio/CREDITS.md`. Sonniss
GDC bundles were not needed.

## Content and processing

- ffmpeg 8 (Homebrew) for every decode/filter/measure; this ffmpeg has no libvorbis, so the float
  WAV is encoded to Ogg Vorbis through Homebrew libsndfile (`oggenc.py`). Mono for point SFX and
  creatures, stereo for beds and music, 44.1 kHz.
- Each file: leading silence trimmed (`silenceremove`, -50 dB), length capped, tail faded,
  integrated loudness measured with `ebur128` (clips under 3 s are looped to 3 s so the gate can
  measure them), gain to the category target, `alimiter` at -1 dBFS. Beds are 40 s equal-power
  crossfade loops (head blended with the tail past the loop point).
- Creatures: ten voice sets, small/medium/large/huge x herbivore/carnivore plus `mammal_cat`
  (smilodon) and `mammal_deer` (megaloceros); idle x3, alert x2, attack x3, hurt x3, death x2.
  Large and huge sets layer 2-3 recordings, all tape-pitched down (rate 0.4-0.85) and filtered;
  e.g. tyrannosaurus = alligator bellows 0.66 + tiger growl 0.5 + caveboytup's CC0 T-rex calls 0.8,
  low-passed with sub-boost and a short slap echo. No large/huge file is an unprocessed recording.
  Per species: a voice set, a runtime pitch (0.82-1.35) and a timbre colour (dark/neutral/bright
  EQ rendered offline); juveniles play 1.25x higher. Every species has a distinct combination
  (tested). The "formant" variation is an EQ colour, not a true formant shift: this ffmpeg has
  neither rubberband nor a vocoder.
- Music (CC0, OpenGameArt): explore = "Beautiful Forest" (nene) and "Epic at the Jungle"
  (indieteur, trimmed to 118 s); night = "Nighttime Solitude" (celestialghost8, trimmed to 120 s);
  combat = "Determined Pursuit" loop (emmama).

### Integrated loudness per category (ffmpeg ebur128, LUFS)

| Category | Files | Mean | Min to max | Target |
|---|---|---|---|---|
| UI | 28 | -23.9 | -27.0 to -19.0 | -27 to -19 by role |
| Footsteps | 42 | -27.9 | -28.0 to -26.9 | -28 |
| Survivor (vocal, eat, drink, sleep, roll) | 27 | -22.2 | -26.8 to -19.0 | -24 to -19 |
| Gathering | 32 | -21.6 | -27.9 to -19.1 | -22 to -18 |
| Combat | 77 | -20.7 | -25.0 to -17.0 | -25 to -15 by weight |
| Creatures small | 52 | -21.2 | -23.2 to -20.0 | -23 to -20 |
| Creatures medium | 78 | -19.2 | -21.0 to -17.9 | -21 to -18 |
| Creatures large | 52 | -17.2 | -19.5 to -16.0 | -19 to -16 |
| Creatures huge | 39 | -16.3 | -18.0 to -15.0 | -18 to -15 |
| Ambience | 25 | -25.7 | -28.8 to -19.0 | -27 beds, -26 shore/wind, -24 heavy rain/fire, -19 thunder |
| Music | 4 | -21.0 | -22.0 to -20.0 | -22 to -20 |

Files more than 1 dB under target are transient-heavy (punches, twig snaps, mud-pot bubbling)
where the -1 dBFS peak limit wins: `gather/depleted_bush_01/02` (-27.9/-26.2 vs -22),
`survivor/eat_01/02` (-26.8/-24.6 vs -22), `gather/craft_03` (-24.9 vs -22),
`ambience/fire` (-28.2 vs -24) and `ambience/volcanic_night` (-28.8 vs -27). Raise their
`volume_db` in `events.json` if they read quiet in play.

### Size budget

19.75 MB of .ogg (limit 30 MB): ambience 9.23 MB, music 4.75 MB, creatures 3.94 MB, combat
0.68 MB, survivor + footsteps 0.67 MB, gathering 0.31 MB, UI 0.18 MB. 1,839 s of audio in total.

## Web

Confirmed in a local web export of this branch (standard Godot 4.7.1, `web_nothreads_release`)
opened in the Chromium browser pane: the engine creates one AudioContext; after forcing it to
`suspended` from devtools, a single real click on the canvas returned it to `running`. The 4.7.1
template's JS exports `_godot_audio_resume` (calls `ctx.resume()` when not running) and the wasm
imports it; the engine calls it from its input callbacks. No gate or prompt was added. With
`--audio-log` the web build logged the grassland bed, explore music, UI clicks/confirm, the
level-up jingle, creature idle calls and dirt footsteps, and 15 `AudioBufferSourceNode.start`
calls were counted, so samples really play on web. The browser pane allows autoplay, so the
"blocked until first input" case itself was simulated, not observed; desktop Chrome with its
default autoplay policy was not tested.

Web playback is Godot's Sample mode (the default for single-threaded web): bus volumes apply, but
bus effects do not, so the Master limiter only works on desktop/mobile builds. Loudness
normalisation and the 32-voice cap are what keep the web mix in range. Sample mode decodes each
stream to PCM in browser memory (a 40 s stereo bed is about 15 MB, a 2 min track about 45 MB);
beds and music are loaded only while playing and released after they fade, never cached.

## Tests and checks (run this session)

- `run_all.gd`: `[tests] PASS`. Audio checks: every event resolves to existing .ogg files; every
  species json maps to a voice set, all five kinds exist and no two species share set+colour+pitch;
  every size x diet set exists; every gather clip and derived kind has 3+ variations and every
  tile type (snowy or not) maps to a footstep event with 4+; every shipped .ogg is in
  `credits.json` with CC0/public-domain sources, URL and author; all six buses exist and send to
  Master, Master has a limiter; a 500-event burst (cooldowns defeated) fills the pool (peak of at
  least 28 asserted) and never exceeds the 32-voice cap or the pool sizes; per-event cap holds; MusicState never enters combat on a
  blinking threat, never drops out during short lulls, ends after 10 s calm, forces on damage;
  button words map to confirm/cancel/click.
- `tools/smoke.sh --no-import`: SMOKE PASS.
- `--lab=audio_lab --audio-lab-fast`: `PASS coverage events=170 missing=0`.
- `--combat-test --audio-log` and `--gather-test --audio-log` (main scene, headless): swings,
  flesh/bone impacts, compy hurt/death, small body fall, survivor hurt/effort, panel open,
  gather_chop, pickup, dirt footsteps, creature idles all fired. The first combat-test run on a
  fresh user dir failed at `main.gd:112` (`World.runtime` null before the island existed; no
  audio code involved); the second run passed.

## Not covered / gaps

- Nobody has listened. Creature designs, colour EQs, species pitches, LUFS targets, footstep and
  gather delays are all judgement without ears. Tune pitch/colour in
  `data/audio/creature_voices.json`, levels in `events.json` (`volume_db`), recipes in
  `tools/audio/build_audio.py`.
- Formant variation is an EQ approximation (see above).
- No fishing and no jump exist in the game, so no fish or jump/land sounds (roll has a whoosh and
  a landing thud). Arrow and spear release/hit events are built but nothing fires them: the only
  ranged weapon is the slingshot (stone release/hit are hooked). The catapult is hooked.
- Weather: the island runtime only has rain; storm/wind/snow/sandstorm/ash beds play only when
  something calls `set_weather` (no visual weather exists for them yet).
- Footsteps are distance-based, not synced to foot contacts; gather/craft sounds use fixed
  per-clip delays, not measured strike frames. Mounted riding has no hoof steps (big creatures
  thud on their own).
- UI sounds only for `BaseButton`/`HexButton` presses and the seven panel classes; custom-drawn
  HUD widgets that use neither stay silent. Confirm/cancel is chosen by button word. The level-up
  jingle also plays when an occupation is applied at character creation.
- No settings screen (only the API). No reverb or occlusion (none would work on web anyway).
- Ambience is 47% of the budget; drop libsndfile quality from 0.15 or go 32 kHz if the web
  download needs to shrink.
- `ERROR: 1 resources still in use at exit` in the test run is the pre-existing baseline (same
  count with the audio call removed). A headless run that quits while a bed is playing (smoke,
  `--shot` labs) may print `WARNING: 4 ObjectDB instances were leaked at exit`: the dummy audio
  driver has no time to drop the stopped playback before the leak check. Exit-only, harmless.
