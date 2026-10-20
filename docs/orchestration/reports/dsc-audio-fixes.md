# Audio review fixes (dsc), plus the sound settings sheet

Date: 2026-10-20. Agent: DeepSeek (dsc). Branch `claude/mmo-audio`. Gate:
`./tools/dsc/verify_audio.sh` (tests, audio lab, `--mute` boot, smoke, true peak on every shipped
file, settings panel, this report) exits 0.

The first fix pass landed as commits `b8e849e`, `b06a904`, `cea07e9` (Claude Code). This pass
re-checked every finding against the code and the shipped files, fixed the two regressions the
re-check exposed, and added the owner's sound settings and mute controls. Nothing here was judged
by ear; every audio claim below is an ffmpeg/ebur128 measurement or a test.

## Findings, one line each

| # | Sev | Status | Where / why |
|---|---|---|---|
| 1 | blocker | Fixed | `game/scripts/audio/audio_hooks.gd:159` hooks `Player.hit_taken` (emitted from `player.gd:1410` in `take_hit_fx`, which only `creature_attack.gd:53-55` calls on a landed hit), not `Vitals.damaged`. Status ticks (stomachache, bleed, deep_bleed, venom, pinned) play nothing and force no combat. Test `audio_tests._test_live`: six stomachache ticks change no HP-sound counts, leave `_force_combat` false; `take_hit_fx` plays `survivor_hurt` and forces combat. |
| 2 | major | Fixed | `status_effects.gd:25-27` raises `ticking` around `_dot`; `audio_hooks.gd:329` returns on any float raised while it is set, so bleeding/poison ticks on a creature play no impact, no yelp and set no combat. `creature.gd` `on_status_tick_damage` keeps its `dot` float for plates. Test: bleeding_target on a live velociraptor plays zero impacts. |
| 3 | major | Fixed | `audio_director.gd:24,27`: `LISTENER_HEIGHT = 8 m` (ear above the survivor's plane) and `MAX_DB = 0.0` on every 3D voice and the campfire loop. Inverse-distance gain at the ear is <= 0 dB for `unit_size <= 8`, so `volume_db` and the walk/run/`impact_bone` offsets apply. Distance low-pass off to match web Sample playback. Test `_test_near_field`: 2 dB less is still 2 dB less at the ear for steps, hurt, swing, impacts, armour, chop. |
| 4 | major | Fixed | `tools/audio/render.py:93-112`: limiter at -1.5 dBFS on 4x oversampled audio (192 kHz), Vorbis encode, then the encoded `.ogg` is measured with `ebur128 peak=true` and re-rendered quieter until <= -1 dBTP (raises after 6 tries). `credits.json` stores `true_peak_db` per file; `_test_credits` fails the build if any ship file is above -1.0, and the gate rescans all 456 `.ogg` with ffmpeg. Results: max -1.1 dBTP, 0 files above -1 (the six that were above 0 dBTP before: fire +0.9, coin_01 +0.4, flesh_medium_03 +0.4, depleted_bush_02 +0.2, depleted_bush_01 +0.1, arrow_release_02 +0.1). |
| 5 | major | Fixed | `audio_hooks.gd:21` `STEP_PHASES` = walk 0.28/0.76, run 0.31/0.81 (ankle-bone heights over the clips); `:276-283` fires on the playing clip's `current_animation_position`, so cadence follows the clip at any `speed_scale`. Walk is now 2 steps per 1.067 s cycle (1.87/s) instead of 3.1/s. Test `_test_live`: 4 walk cycles and 4 run cycles give 8 steps each. |
| 6 | major | Fixed | `tools/audio/build_audio.py:253-270` `carn_medium`: leads are geese bark (alert), alligator hiss (attack), sandhill crane (idle, death), rubberduck CC0 creature calls (hurt). The BigSoundBank domestic cat is a minority layer at rate 0.62-0.70 and -11 to -14 dB, under `RAPTOR` post chain (high-pass 150 Hz, low-pass 6.8 kHz, flanger comb, 14 ms slap). No raptor file shares a lead source with `mammal_cat`; `credits.json` records each file's `lead`. Test `_test_raptor_sources`. Velociraptor's 1.1x runtime pitch stays: the base is already down at 0.62-0.70, so 1.1x leaves it well under the recording's own pitch. |
| 7 | minor | Fixed | `audio_hooks.gd:331-335`: a `crit` float on a creature not damaged in the last 50 ms is the attacker's; it plays `impact_crit` at the survivor and nothing on the creature. Test: emitting `crit` on an undamaged raptor plays no raptor impact, one survivor crunch. |
| 8 | minor | Fixed | `audio_beds.gd:181-193`: any slot whose gain and target are both 0 is `queue_free`d and erased, so a faded shore/weather slot stops holding decoded PCM. Test `_test_beds_release`. |
| 9 | minor | Fixed | `audio_hooks.gd`: `_cstate` erased on `tree_exiting`, the group scan runs only on the 0.25 s poll, `_big` caches large/huge creatures for per-frame footfalls, and thunder reads `_weather_now` cached by the 0.5 s ambience tick instead of calling `_effective_weather` per frame. Test: state gone after the raptor leaves the tree. |
| 10 | minor | Fixed | `audio_director.gd:98` `designed_bus_db()` reads `default_bus_layout.tres` instead of the live bus. Test: three directors made and freed at SFX 0.5 leave SFX at the designed -6 dB, not compounded. |
| 11 | minor | Fixed | `claude-mmo-audio.md` now carries the measured table below (volcanic_night -30.2 integrated on the shipped file, which is inside the reviewer's -30.1), the true-peak sweep, the `max_db`/volume_db explanation, the old walk-cadence mismatch, and the mono-fire/thunder note. Commons rows in `credits.json` carry the `File:` description page in `url` and the `upload.wikimedia.org` media URL in `download`; `_test_credits` enforces both for all 195 Commons sources. Independently re-measured 15 files: `lufs` and `true_peak_db` in `credits.json` match ffmpeg to 0.1 (worst 0.3 dB, a gated-to-silence short clip). |

Regression found and fixed while re-checking: `_when_ready`/`_once` marked nodes with a shared
`_audio_hooked` meta, so a recreated `AudioDirector` (after `Game.ensure_audio`) hooked nothing —
the live test caught the survivor going silent. Marks now carry the hooks instance id
(`audio_hooks.gd:_mark`).

## Sound settings (new)

- `game/scripts/audio/audio_settings.gd` + `audio_settings.tscn` (`AudioSettings`, `Control`):
  Master, Music, Ambience, SFX (labelled Effects), Creatures and Interface sliders plus **Mute all**.
  Each row is 64 px tall, the drag strip itself 64 px; the whole sheet fits 600 x 605 px. Sliders
  scale their bus around the designed layout level and save through `Settings`
  (`user://settings.cfg`, section `audio`), so a level survives a restart. Mute all silences Master
  only, so the six slider levels stay where they were. Tap outside or ✕ closes; Escape closes.
- `AudioDirector.muted` / `set_muted(on, persist)`: the mute hotkey `mute_audio` (**F10**, gamepad
  D-pad left) toggles it and prints `[audio] master muted (hotkey)`. Boot mute: the saved setting,
  the `--mute` flag (`[audio] master muted (flag)`) and `DEADFRONT_MUTE` (1/true/on/yes,
  `[audio] master muted (env DEADFRONT_MUTE)`), each muting Master without overwriting the saved
  preference. `audio_settings` (**F9**) or `AudioDirector.open_settings()` shows the sheet over the
  current scene (it makes its own CanvasLayer when the host is a Node3D).
- **Menu hook (one line, for whoever owns `ui/*.gd`)**: in `hunt_hud.gd`'s `menu` sheet, after the
  "Save" button, add `_sheet_btn(box, "Sound", func () -> void: _close_sheet(); Game.audio.open_settings())`.
  Nothing under `ui/` was edited here, as asked; the F9 action and the lab's
  `--audio-lab-settings` flag already reach the sheet without it.
- Tests: `audio_tests._test_settings_panel` (six sliders with 64 px targets, a drag moves only its
  bus and persists, Mute all mutes Master and unmuting restores the slider levels, the hotkey action
  exists on a key). Visual check: `.dsc/shots/audio_settings7.png`.

## Loudness, measured on the shipped .ogg (456 files, ffmpeg ebur128 peak=true)

| Category | Files | Mean LUFS | Min to max LUFS | Max true peak |
|---|---|---|---|---|
| UI | 28 | -24.1 | -27.8 to -19.0 | -1.4 dBTP |
| Footsteps | 42 | -28.1 | -28.5 to -27.2 | -1.6 |
| Survivor | 27 | -22.3 | -27.5 to -19.0 | -1.3 |
| Gathering | 32 | -21.9 | -28.5 to -19.3 | -1.2 |
| Combat | 77 | -20.9 | -25.3 to -17.1 | -1.1 |
| Creatures small | 52 | -21.4 | -23.4 to -20.0 | -1.6 |
| Creatures medium | 78 | -19.3 | -21.1 to -18.0 | -1.1 |
| Creatures large | 52 | -17.3 | -19.7 to -16.0 | -1.1 |
| Creatures huge | 39 | -16.4 | -18.1 to -15.0 | -1.2 |
| Ambience | 25 | -25.8 | -30.2 to -19.0 | -1.1 |
| Music | 4 | -21.1 | -22.1 to -20.1 | -5.5 |
| All | 456 | -21.2 | -30.2 to -15.0 | -1.1 |

Clips under 3 s are measured looped to 3 s so the ebur128 gate can read them. Quiet outliers are
transient-heavy files where the -1 dBTP ceiling wins over loudness (gather/depleted_bush_01 -28.5,
ambience/fire -29.3, ambience/volcanic_night -30.2); they do not clip.

## Assumptions

- F10 (mute) and F9 (sound sheet) are free keys; `docs/controls.md` does not use them. Gamepad mute
  is D-pad left, which was free.
- Master mute is separate from the Master slider on purpose: mute is a temporary silence, the slider
  is the level. `--mute`/`DEADFRONT_MUTE` mute for the session only.
- Mono fire and thunder stay mono: both are point sources, not beds. Noted, not changed.

## Gotchas for the next agent

- A new `class_name` is not visible to `--script` runs until `godot --headless --path game --import`
  has run once; the gate does that first for exactly this reason.
- The audio build says what it measured, but nobody has listened; the creature voices above all are
  still unjudged by ear.
