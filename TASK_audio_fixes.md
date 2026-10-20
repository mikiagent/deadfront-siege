# Task: fix the independent audio review findings on branch claude/mmo-audio

DEADFRONT (Godot 4.7.1 typed GDScript, project in game/). The audio layer on this branch (game/scripts/audio/,
game/data/audio/, game/assets/audio/, tools/audio/) was reviewed; fix every blocker and major below and cheap minors.
Nobody can listen: judge by measurement. NEVER play audio aloud (no afplay/ffplay/say); measure with
/opt/homebrew/bin/ffmpeg (ebur128 with peak=true for true peak). Re-render processed files with the existing
tools/audio/ pipeline, not by hand, and keep game/data/audio/credits.json complete for every shipped file.
Also add the owner's requested SOUND SETTINGS: a small panel scene/script under game/scripts/audio/ (Master, Music,
Ambience, SFX, Creatures, UI sliders + Mute all), persisted via the existing settings helper, a mute hotkey
action, and the game honouring the `--mute` command-line flag and the DEADFRONT_MUTE environment variable by
muting Master at boot. Do not edit hunt_hud.gd or other ui/*.gd; list the one-line menu hook in the report.
How to run Godot (always): /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game ...
Commit often; messages end with "Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>". Write
docs/orchestration/reports/dsc-audio-fixes.md (one line per finding: fixed where / skipped why, plus loudness table).
Done means ./tools/dsc/verify_audio.sh exits 0. Never edit that script.

## Findings
### 1. [blocker] game/scripts/audio/audio_hooks.gd:147,160-167 (Vitals.damaged); fed by game/scripts/combat/status_effects.gd:197 and game/scripts/items/food.gd:85
- Problem: The survivor's damage sound is hooked to Vitals.damaged, which fires on every status tick (every 0.5 s), not just on hits. Each tick plays impact_flesh_medium (cooldown 0.03 s), survivor_hurt (cooldown 0.45 s), armour_hit when armour is worn, and sets _force_combat. Bad food applies stomachache (dps 0.2 for 300 s), so the survivor thuds and grunts about 600 times over 5 minutes with combat music forced the whole time. The same happens for bleed (20 s), deep_bleed (30 s), venom (45 s) and pinned.
- Fix: Make the hurt, impact and force-combat sounds respond only to real hits. Smallest option: hook the hit path instead (Player.take_hit_fx, or a one-line emit at creature_attack.gd:53 and the other direct-hit sites). Alternative: give Vitals.take_damage a source or kind and skip status ticks. If DoT gets a sound at all, use one quiet tick event with a cooldown of several seconds and no force_combat.

### 2. [major] game/scripts/audio/audio_hooks.gd:298-313 via game/scripts/creatures/creature.gd:518-524 and game/scripts/combat/status_effects.gd:189
- Problem: Creature._on_damaged emits combat_float(amount, 'hit') for every Health.damaged, including the 0.5 s bleeding_target and poisoned_target ticks (20-30 s, often stacked x5 per the test log). Every tick plays a size-class flesh or hide impact, has a 70% chance of a hurt vocal (0.8 s cooldown), and forces combat music when within 20 m. A bleeding animal running away keeps thudding.
- Fix: Skip impact and hurt sounds for DoT damage. For example, hook the 'dot' float at creature.gd:658 separately and have creature.gd tag DoT damage so it does not emit 'hit', or compare against on_status_tick_damage. Do not set _force_combat from DoT.

### 3. [major] game/scripts/audio/audio_director.gd:281 (max_db = 3.0) with listener at survivor +1.2 m (audio_director.gd:360)
- Problem: Godot's _get_attenuation_db adds volume_db and then clamps to max_db (checked in the engine source). The listener is 1.2 m from the survivor and unit_size is 6-8 m, so inverse-distance gain is +14 to +16 dB. Every survivor sound and every close creature or impact sound therefore lands at exactly +3 dB. All volume_db values in events.json and the per-call params (footstep walk -2 vs run 0, impact_bone -4) have no effect in the near field. The files are limited to about -1 dBFS, so near sounds peak around +2 dBFS. Web Sample mode does not apply bus effects (the report says so itself), so the Master limiter cannot catch this on the judged desktop-Chrome build: transients will clip.
- Fix: Set max_db to 0 or lower (or per event from events.json) and move level intent into unit_size and volume_db. Alternatively, drop the listener into the survivor's plane and raise the floor distance so near gain stays at or below 0 dB. Re-check that footstep walk/run and impact_bone offsets become audible.

### 4. [major] tools/audio/render.py:93-98 (_finish: alimiter limit=-1 dBFS sample peak, then Vorbis encode)
- Problem: The task asked for no true peak above -1 dBTP. The limiter caps sample peak, not true peak, and Vorbis encoding adds overshoot. A full scan of the 456 files finds 72 above -1 dBTP and 6 above 0 dBTP: ambience/fire.ogg +0.9, ui/coin_01.ogg +0.4, combat/flesh_medium_03.ogg +0.4, gather/depleted_bush_02.ogg +0.2, depleted_bush_01.ogg +0.1, combat/arrow_release_02.ogg +0.1. Many creature large/huge alerts and deaths sit at -0.4 to -0.9. Together with the +3 dB near-field boost and no limiter on web, this is real clipping headroom loss.
- Fix: Limit at about -2 dBFS, or oversample before the limiter (aresample=192000, alimiter, aresample=44100), then re-measure every encoded .ogg with ebur128 peak=true and fail the build when any file is above -1 dBTP. Add that assertion to the build script or to audio_tests through a precomputed credits.json peak field.

### 5. [major] game/scripts/audio/audio_hooks.gd:256-272 (_tick_steps)
- Problem: Footstep cadence does not match the walk cycle. walk.glb is 1.067 s and plays at speed_scale 1.0 (player_anim._play / rig.play), which is about 1.9 footfalls per second. At walk_speed 5.5 m/s the code's stride of speed*0.32 = 1.76 m gives about 3.1 steps per second, 67% faster than the feet. Keyboard and joystick movement always uses the walk clip (player_anim.play_locomotion), so the desktop judge hears this on every walk. Run (0.667 s cycle, about 3 per second at 7 m/s) roughly matches. Steps are also not phase-locked to foot contact. The report says steps are distance-based but does not disclose the walk-cadence mismatch.
- Fix: Derive the step interval from the playing clip: two steps per clip length divided by speed_scale, with the phase taken from anim_player.current_animation_position. Or add the two foot-contact times as method-track or anim_events entries for walk and run and emit on those. At minimum, set stride so walk_speed / stride equals 2 / 1.067.

### 6. [major] tools/audio/build_audio.py:243-252 (carn_medium) -> game/assets/audio/creatures/carn_medium/*
- Problem: Velociraptor, deinonychus, utahraptor and dilophosaurus are built from BigSoundBank 'cat roar 1-4' and 'growling cat 1-4' (bsb 1881-1888). Their bigsoundbank.com pages classify them as 'Animals / Cat Domestic'. The attack calls are a domestic cat roar at rate 0.92-0.98 with only an alligator hiss mixed in at -6 dB and no post filter. Velociraptor then gets a 1.1x runtime pitch, which puts it back at or above the cat's original pitch. Idle is a growling cat at 0.86. These are close to unprocessed real-animal recordings used as dinosaurs, and smilodon (mammal_cat) shares the same source cats, so raptors and smilodon will sound alike. The brief asked for raptor barks and hisses.
- Fix: Rebuild carn_medium with the domestic-cat layer pitched well down (0.6-0.75) and kept as a minority layer, led by the hiss, crane and goose, or raspy layers already licensed (caveboytup small-dino-raspy, alligator hiss). Add a bandpass or comb or flanger post chain, and stop sharing primary sources with mammal_cat.

### 7. [minor] game/scripts/combat/creature_attack.gd:52 -> game/scripts/audio/audio_hooks.gd:298-313
- Problem: When a creature crits the player, combat_float(dealt, 'crit') is emitted on the attacker. AudioHooks treats this as the attacker being hit, so the attacking creature plays an impact, impact_crit and (70%) its own hurt vocal, while the survivor's side plays the normal hit sounds.
- Fix: In _on_creature_float, ignore 'crit' when the creature is the attacker (for example, check that its health changed), or play the crit sound on the survivor from the player damage hook.

### 8. [minor] game/scripts/audio/audio_beds.gd:139-143,165-168
- Problem: The shore and weather slots, once created, are never freed. When their target goes to 0 they stay playing at -80 dB indefinitely: _set_layer only sets the target, and the slot never moves to _dying. On web Sample mode that keeps a decoded 40 s stereo PCM buffer (about 15 MB each) and an active source alive for the whole session, which undercuts the report's claim that beds are released after they fade.
- Fix: When a slot's gain reaches 0 with target 0, queue_free the player and erase the slot (or move it to _dying in _set_layer when target <= 0).

### 9. [minor] game/scripts/audio/audio_hooks.gd:32,323,342-381
- Problem: _cstate entries are erased only on death, so creatures that despawn without dying leak entries. _tick_creatures calls get_nodes_in_group('creatures') and does per-creature dictionary work every frame, not only on the 0.25 s poll. _tick_thunder runs _effective_weather (with its Data lookup and _weather_intensity mutation) every frame.
- Fix: Erase state on tree_exiting of the creature. Do the group scan only on the poll, and keep a cached list of large and huge creatures for footfalls.

### 10. [minor] game/scripts/audio/audio_director.gd:75-99
- Problem: _bus_default_db is captured from the live AudioServer when the director starts. If Game.audio is ever recreated (ensure_audio after the node was freed), the already-scaled volume becomes the new 'default', and set_bus_volume compounds on each recreation.
- Fix: Read the designed defaults from default_bus_layout.tres (or a constant table) instead of the live bus volume.

### 11. [minor] docs/orchestration/reports/claude-mmo-audio.md (LUFS table, web section)
- Problem: Report accuracy gaps. It reports volcanic_night at -28.8 LUFS; I measured -30.1. It does not disclose the true-peak overs, the max_db override of volume_db, or the walk-cadence mismatch. Commons credits record the upload.wikimedia.org file URL rather than the File: description page that carries the licence (the licences do check out via extmetadata). Thunder and the fire loop are mono where the brief said stereo ambience; that is acceptable for a point source but should be noted.
- Fix: Update the report with measured true peaks and the fixes above. Store the commons.wikimedia.org/wiki/File:... page URL in credits.json next to the download URL.
