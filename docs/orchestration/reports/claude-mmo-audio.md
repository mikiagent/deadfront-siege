# Audio layer: buses, AudioDirector, 456 CC0 sounds, hooks, tests

Date: 2026-10-18. Agent: Claude Code. Branch `claude/mmo-audio` (not pushed).

**No agent can listen. Every sound here was picked and processed from measurements (ffmpeg
envelopes, loudness, durations), not by ear. Subjective quality, the creature voice designs
above all, is unverified until the owner listens.** Fastest way: `godot --path game -- --lab=audio_lab`
plays every category in turn; then play normally with `-- --audio-log` to see what fires.

## Review fixes (second pass, same day)

An independent review found one blocker, five majors and five minors. All were checked against
the code and fixed; none turned out wrong. Each has a test in `game/tests/audio_tests.gd` that
fails on the old code.

| Finding | Fix | Test |
|---|---|---|
| Blocker: survivor hurt/impact/armour and forced combat music on every `Vitals.damaged`, which also fires on every 0.5 s status tick (stomachache from bad food: about 600 thuds and grunts over 5 min, combat music the whole time) | Hooked to a new `Player.hit_taken(amount, heavy)`, emitted from `take_hit_fx`, which only `creature_attack.gd` calls on a landed hit. DoT on the survivor makes no sound | `_test_live`: real `player.tscn`, stomachache ticks play nothing and leave combat unforced; `take_hit_fx` plays `survivor_hurt` and forces combat |
| Major: creature `combat_float("hit")` from bleed/poison ticks played impacts, 70% hurt yelps and forced combat | `StatusEffects.ticking` is true while a DoT tick lands; `_on_creature_float` ignores floats raised inside it | `_test_live`: real velociraptor, bleeding_target ticks play no impact and leave combat unforced; a direct `take_damage` still plays |
| Major: listener 1.2 m over the survivor and `max_db = 3`; Godot adds `volume_db` then clamps, so every near 3D sound sat at +3 dB and `volume_db` and the walk/run and impact_bone offsets did nothing; no limiter on web | Listener at `LISTENER_HEIGHT = 8 m` over the survivor and `MAX_DB = 0` on every 3D voice and campfire loop: a sound at the survivor with `unit_size <= 8` lands at or under 0 dB, so table levels and offsets apply. The distance low-pass is off (`attenuation_filter_cutoff_hz = 20500`) because web Sample playback has none, so native now matches web. Campfire `unit_size` 3 -> 7, `max_distance` 18 -> 24 to keep it audible at the new ear | `_test_near_field`: Godot's formula for steps, hurt, swing, impacts, armour, chop at the ear height; 2 dB less must still be 2 dB less; listener height checked on a live survivor |
| Major: `alimiter` capped sample peak only; 72 files above -1 dBTP, 6 above 0 dBTP | `render.py`: limiter at -1.5 dBFS on 4x oversampled audio (192 kHz), encode, then measure the .ogg itself with `ebur128 peak=true` and lower the gain until it is at or under -1 dBTP; the build raises if any file is still over. `credits.json` stores `true_peak_db` per file | `_test_credits`: every shipped file's `true_peak_db <= -1.0`. Independent rescan of all 456 .ogg: max -1.1 dBTP, 0 over -1 |
| Major: steps 3.1/s at walk while the walk clip lands feet 1.9/s; not phase-locked | Steps fire when the playing `walk`/`run` clip passes a foot strike: phases 0.28/0.76 (walk.glb) and 0.31/0.81 (run.glb), read off the ankle-bone heights by FK over each clip. Any speed_scale follows. With no locomotion clip (no rig) steps keep the walk cadence, 0.533 s | `_test_step_phase` (wrap, between-strike, 20 strikes in 10 walk cycles) and `_test_live`: real survivor, 4 walk cycles and 4 run cycles give 8 steps each (old code gave about 13 for walk) |
| Major: raptors were BigSoundBank domestic cat roars/growls at 0.86-0.98, the same cats smilodon leads with | `carn_medium` rebuilt: leads are Canada geese (alert bark), alligator hiss (attack), sandhill crane (idle, death) and rubberduck's CC0 creature hurt calls; the cat is a minority layer at rate 0.62-0.70 and -11 to -14 dB; post chain high-pass 150 Hz, low-pass 6.8 kHz, flanger comb and a 14 ms slap echo. `credits.json` now records each file's `lead` source | `_test_raptor_sources`: no raptor file leads with any source the smilodon set uses or with a BigSoundBank cat |
| Minor: a creature critting the survivor played impact, crit and a hurt yelp on the attacker | A `crit` float on a creature that was not damaged in the last 50 ms is the attacker's: it plays `impact_crit` at the survivor and nothing on the creature | `_test_live`: emitting `crit` on an undamaged raptor plays no raptor impact and one survivor crit |
| Minor: shore/weather/music slots faded to 0 kept playing at -80 dB forever (decoded PCM kept on web) | `AudioBeds._fade` frees any slot whose gain and target are both 0 | `_test_beds_release` |
| Minor: `_cstate` leaked despawned creatures; group scan and per-creature work every frame; `_effective_weather` every frame | State erased on `tree_exiting`; the group scan runs only on the 0.25 s poll and caches large/huge creatures for per-frame footfalls (size kept in the state); thunder reads the weather cached by the 0.5 s ambience tick | `_test_live`: state is gone after the raptor leaves the tree |
| Minor: bus defaults captured from the live bus, so a recreated director compounded the volume setting | `AudioDirector.designed_bus_db(bus)` reads `default_bus_layout.tres` | `_test_bus_defaults`: three directors made and freed at 0.5 SFX leave SFX at designed -6.0 dB |
| Minor: report accuracy | LUFS and peaks below are now measured on the shipped .ogg (the first pass measured the pre-encode WAV; Vorbis at q 0.15 drops noisy beds by about 1.3 dB, which is why volcanic_night read -28.8 then and -30.1 to the reviewer). Commons credits: `url` is the `File:` page that carries the licence, `download` the media file. Mono thunder and fire are deliberate point sources; beds and music are stereo | `_test_credits` checks Commons `url`/`download` |

Timbre check without ears (`aspectralstats` centroid, spread, roll-off, flatness, entropy, log
distance to the smilodon set, per kind; old raptor -> new raptor): idle 1.07 -> 0.73, alert
0.77 -> 0.26, attack 0.16 -> 1.65, hurt 0.08 -> 2.20, death 0.30 -> 0.99. Attack, hurt and death
moved well away from the cat. Alert and idle are now closer on these spectral averages (a geese
bark and a cat roar have similar spectral balance), though no raptor alert or idle shares a lead
source with smilodon any more. This measure is crude; it is not a substitute for listening.

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
    a useless ear (everything on screen is equally far). An `AudioListener3D` rides 8 m over the
    survivor (`LISTENER_HEIGHT`), rotated like the camera so screen-left is ear-left; inverse-distance
    attenuation with per-event `unit_size` (5 m small creatures to 18 m huge) and `max_distance`
    (24 m campfire, 28 m footsteps to 120 m huge roars); `max_db` 0 so no voice is boosted above its
    file; pan strength 0.55 so the top-down view does not hard-pan. Big creatures (`unit_size` over
    8 m) still reach the 0 dB cap when close; that cap is their loudest, and it never clips.
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
| `game/scripts/player/player.gd:2153` | `item_gained.emit(id, n)` in `toast()` |
| `game/scripts/player/player.gd:2161` | `noticed.emit(text)` in `notice()` |
| `game/scripts/player/player.gd:2217` | `context_used.emit(id)` in `context_action()` (drink) |
| `game/scripts/player/player.gd:12` | `signal hit_taken(amount, heavy)` (review fix) |
| `game/scripts/player/player.gd:1410` | `hit_taken.emit(amount, heavy)` in `take_hit_fx()` (landed creature hits only) |
| `game/scripts/combat/status_effects.gd:11,25,27` | `var ticking` and `ticking = true/false` around `_dot()` in `_process` (review fix: lets listeners tell a DoT tick from a hit) |
| `game/scripts/items/station_craft.gd:8` | `signal crafted(recipe_id)` |
| `game/scripts/items/station_craft.gd:300` | `crafted.emit(recipe_id)` in `_finish_one()` |
| `game/scripts/core/game.gd:32,207` | `var audio: AudioDirector` (lazy getter) and `ensure_audio()` |
| `game/scripts/core/main.gd:11` | `Game.ensure_audio()` so beds and music start with the playfield |
| `game/tests/run_all.gd:53` | one call into `tests/audio_tests.gd` |

Existing signals used without edits: `Vitals.died`, `Health.died`, `Creature.combat_float`
(hit/weak/strong/crit, ignored while `StatusEffects.ticking`), `CreatureAnim.attack_windup`, `HarvestNode.depleted_tile`,
`SkillState.skill_changed` (sound only when a level goes up), `World.pioneer_changed`,
`CanvasItem.visibility_changed`, `BaseButton.pressed`, `HexButton.pressed`, `tree_exiting` on
projectiles and creatures. Polled: survivor clip phase plus velocity/floor/water for footsteps, `World.t_stones` (earn = stone
clack, spend = coins), creature `brain_state` edges (alert calls), idle-call timers, big-creature
footfalls from distance moved. `island_runtime.gd` is untouched (read only: `raining`,
`land_radius()`, `_tile_type_at_world()`).

Footstep surface: water when `in_water`; wood when a downward ray hits a `placed_building`;
otherwise the island tile (`SAND` sand, `SHALLOW`/`DEEP` water, `ROCK`/`ASH` stone, `MUD`/`WET`
mud, the rest dirt/grass, or snow on tundra/snowfield). Steps land on the foot strikes of the
playing walk or run clip (1.9 and 3.0 a second at speed_scale 1). Gather kinds: `gather_kind()` chop/mine/gather plus dig (mud, clay, ground role),
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
| OpenGameArt (qubodup, rubberduck, caveboytup, starninjas, antumdeluge, zane-little-music, emopreben, thebardofblasphemy, eldritch-grim, artisticdude, nene, indieteur, celestialghost8, emmama) | 68 | CC0 1.0 |
| Kenney (impact, rpg, interface, ui, casino, music jingles) | 85 | CC0 1.0 |
| Wikimedia Commons (USFWS, NPS Yellowstone sound library, Felix Blume, schots, others) | 16 | CC0 1.0 or public domain |

Second pass: rubberduck's "80 CC0 creature SFX" 1 and 2 (licence field CC0 on both saved pages)
joined for the raptors; the Commons rattlesnake dropped out. The first report also listed
pauliuw, peludo and trazzz123, whose downloads were never used in a shipped file.

Per-file rows: `game/data/audio/credits.json` (source page URL, author, licence, original
filename, collection, download URL for OpenGameArt archives and Commons media, lead source,
measured LUFS and true peak) and `game/assets/audio/CREDITS.md`. Sonniss
GDC bundles were not needed.

## Content and processing

- ffmpeg 8 (Homebrew) for every decode/filter/measure; this ffmpeg has no libvorbis, so the float
  WAV is encoded to Ogg Vorbis through Homebrew libsndfile (`oggenc.py`). Mono for point SFX and
  creatures, stereo for beds and music, 44.1 kHz.
- Each file: leading silence trimmed (`silenceremove`, -50 dB), length capped, tail faded,
  integrated loudness measured with `ebur128` (clips under 3 s are looped to 3 s so the gate can
  measure them), gain to the category target, `alimiter` at -1.5 dBFS on 4x oversampled audio,
  Vorbis encode, then the .ogg is measured (`ebur128 peak=true`) and re-rendered quieter until it
  is at or under -1 dBTP. Beds are 40 s equal-power crossfade loops (head blended with the tail
  past the loop point).
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

### Integrated loudness and true peak per category (ffmpeg ebur128 on the shipped .ogg)

| Category | Files | Mean LUFS | Min to max LUFS | Target LUFS | Max true peak |
|---|---|---|---|---|---|
| UI | 28 | -24.1 | -27.8 to -19.0 | -27 to -19 by role | -1.4 dBTP |
| Footsteps | 42 | -28.1 | -28.5 to -27.2 | -28 | -1.6 |
| Survivor (vocal, eat, drink, sleep, roll) | 27 | -22.3 | -27.5 to -19.0 | -24 to -19 | -1.3 |
| Gathering | 32 | -21.9 | -28.5 to -19.3 | -22 to -18 | -1.2 |
| Combat | 77 | -20.9 | -25.3 to -17.1 | -25 to -15 by weight | -1.1 |
| Creatures small | 52 | -21.4 | -23.4 to -20.0 | -23 to -20 | -1.6 |
| Creatures medium | 78 | -19.3 | -21.1 to -18.0 | -21 to -18 | -1.1 |
| Creatures large | 52 | -17.3 | -19.7 to -16.0 | -19 to -16 | -1.1 |
| Creatures huge | 39 | -16.4 | -18.1 to -15.0 | -18 to -15 | -1.2 |
| Ambience | 25 | -25.8 | -30.2 to -19.0 | -27 beds, -26 shore/wind, -24 heavy rain/fire, -19 thunder | -1.1 |
| Music | 4 | -21.1 | -22.1 to -20.1 | -22 to -20 | -5.5 |

Clips under 3 s are measured looped to 3 s (the 400 ms gate cannot read a 0.3 s thud otherwise).
70 of 456 files land more than 1 dB under their target and 16 more than 3 dB under (the first
pass had 54 and 6 by its own WAV measure; the first report named only seven). They are
transient-heavy (punches, twig snaps, crackle, mud-pot bubbling) where the -1 dBTP ceiling wins
over loudness: worst `gather/depleted_bush_01` -28.5 vs -22, `combat/flesh_medium_01/04` -25.0/
-24.8 vs -19, `survivor/eat_01` -27.5 vs -22, `ambience/fire` -29.3 vs -24, `gather/depleted_rock_01`
-23.2 vs -19, `ambience/volcanic_night` -30.2 vs -27. Integrated loudness under-reads short
transients, so these may not sound quiet; if they do, give them more `volume_db` (at most to 0 dB
near the survivor, see the listener note) or a compressor in their recipe.

### Size budget

19.72 MB of .ogg (limit 30 MB): ambience 9.25 MB, music 4.75 MB, creatures 3.89 MB, combat
0.68 MB, survivor + footsteps 0.67 MB, gathering 0.31 MB, UI 0.18 MB. 1,842 s of audio in total.

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
bus effects and the 3D distance low-pass do not, so the Master limiter only works on desktop/mobile
builds. What keeps the web mix out of clipping: every file at or under -1 dBTP, no 3D voice above
0 dB (`MAX_DB`), loudness normalisation and the 32-voice cap. Many simultaneous loud voices can
still sum past full scale on web; nothing measured that case. The web export was not re-run after
the review fixes; the changes are engine-side settings and re-rendered files of the same names. Sample mode decodes each
stream to PCM in browser memory (a 40 s stereo bed is about 15 MB, a 2 min track about 45 MB);
beds and music are loaded only while playing; since the review fix a slot that fades to silence is
freed (before, shore and weather slots stayed alive at -80 dB).

## Tests and checks (run this session)

- After the review fixes: `--import`, then `run_all.gd` `[tests] PASS`, `tools/smoke.sh --no-import`
  SMOKE PASS, `--lab=audio_lab --audio-lab-fast` `PASS coverage events=170 missing=0`,
  `--combat-test --audio-log` (one survivor_hurt per landed compy bite, impacts, crit, compy
  hurt/death, body fall) and `--gather-test --audio-log` (dirt steps, chops, pickup). The new tests
  are listed in the review table above.
- First pass, `run_all.gd`: `[tests] PASS`. Audio checks: every event resolves to existing .ogg files; every
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
- Footsteps follow the walk/run clips' measured foot strikes; gather/craft sounds still use fixed
  per-clip delays, not measured strike frames. Mounted riding has no hoof steps (big creatures
  thud on their own).
- UI sounds only for `BaseButton`/`HexButton` presses and the seven panel classes; custom-drawn
  HUD widgets that use neither stay silent. Confirm/cancel is chosen by button word. The level-up
  jingle also plays when an occupation is applied at character creation.
- No settings screen (only the API). No reverb or occlusion (none would work on web anyway).
- Damage over time on the survivor (bleed, poison, stomachache) is silent by choice; the bonfire
  cauterise (5 damage, `Vitals.take_damage` without `take_hit_fx`) is silent too.
- The near-field mix is quieter than the first pass by design (near sounds were pinned at +3 dB,
  now at or under 0 dB). If the owner finds the SFX too quiet, raise the SFX/Creatures bus or
  per-event `volume_db` up to 0, not `MAX_DB`.
- Ambience is 47% of the budget; drop libsndfile quality from 0.15 or go 32 kHz if the web
  download needs to shrink.
- `ERROR: 1 resources still in use at exit` in the test run is the pre-existing baseline (same
  count with the audio call removed). A headless run that quits while a bed is playing (smoke,
  `--shot` labs) may print `WARNING: 4 ObjectDB instances were leaked at exit`: the dummy audio
  driver has no time to drop the stopped playback before the leak check. Exit-only, harmless.
