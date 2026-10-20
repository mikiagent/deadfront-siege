# Task: fix the reviewers' minor findings on the merged DEADFRONT packages

DEADFRONT is a Godot 4.7.1 typed-GDScript game (project in game/). Nine wave-1 packages passed independent review
and were merged; their reviewers left the concrete minor findings below. Fix each one in the smallest correct way,
in the existing code style (typed GDScript, class_name per file, short why-comments, no new autoloads, no new
dependencies). Add or tighten a test assertion where a finding says a check could not fail. Do not change
behaviour beyond what each finding asks; skip a finding (and say why in the report) if fixing it would need a
design decision. Do NOT edit game/scripts/ui/*.gd, game/data/items.json, game/data/recipes.json or game/project.godot.

How to run Godot (ALWAYS like this, the machine is shared and must stay silent):
  /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<test>.gd
Never run Godot without gslot.sh, never pass --editor, never play audio. game/override.cfg must stay.
Commit after every few fixes with a clear message ending "Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>".
At the end write docs/orchestration/reports/dsc-minors-wave1.md: one line per finding: fixed (file:line) / skipped (why).
Done means ./tools/dsc/verify_minors.sh exits 0. Never edit that script.

## Findings
### 1. game/scripts/world/placed_building.gd:38
- Problem: from_dict does bool(d.get("open", false)). If a corrupt or hostile save has "open": "true", null, [] or {}, this raises 'SCRIPT ERROR: Nonexistent bool constructor' and from_dict aborts, so the gate (and anything restored after it in that call) is dropped on load. Reproduced in probe2.gd.
- Fix: b.gate_open = b.kind == &"gate" and d.get("open", false) == true

### 2. game/scripts/dev/siege_probe.gd:36-39
- Problem: label-uses-max-hp cannot tell max_hp from a hard-coded 200, because max_hp == 200 and hp == 200. It is also only printed: a false value does not fail the probe.
- Fix: Set platform.max_hp to a non-200 value (e.g. 250) before the check, and quit(1) when the label does not match.

### 3. game/scripts/world/tile_path.gd:14,47,64
- Problem: The spec says path() 'returns a reachable flag'. The flag is a mutable member (last_reachable) on a TilePath shared by every creature and the survivor, so it is only valid when read right after the call. That is fine single-threaded, but fragile for the server-side reuse W3 plans.
- Fix: Acceptable for now. Note it in contracts, or add a path_result() that returns {points, reachable}.

### 4. game/scripts/world/field_plot.gd:62 / game/scripts/world/taming_pen.gd (pack-up via BuildPlacer)
- Problem: Pack-up conservation gaps that are not tested. An empty field with fertilizer_overflow > 0 packs up and drops the stored fertiliser. A running pen returns the captured animal (I verified this), but taming progress and any fed meat are discarded silently.
- Fix: Block field pack-up while fertilizer_overflow > 0, or return the floor() of it as items. Add a pen-occupant case to t_build.

### 5. game/scripts/world/build_placer.gd:461 (World.note_building / construction XP)
- Problem: The place -> pack -> place loop awards +8 construction XP and +30 pioneer XP every cycle. This existed before for PlacedBuilding kinds; universal pack-up now extends it to every kind. The report documents it.
- Fix: Follow-up: mark repacked kit stacks (or use W1-ITEMS uid) and skip XP for re-placing a repacked kit.

### 6. creature_clips.gd natural_speed / anim_events.json natural_speeds
- Problem: Nothing guards against stale bakes. The bake records walk_len and run_len, but the runtime never compares them to the loaded clip. Since this branch point, stegosaurus GLB clips have landed on mmo-overhaul and have no bake. dsc re-animations of the raptors and quadrupeds are in progress. A replaced GLB would silently use the old speed.
- Fix: In setup, ignore the bake (and print once) when the baked *_len differs from the trimmed clip length by more than 1 %. Rebake after merge.

### 7. game/scripts/creatures/creature_genetics.gd:103 (from_dict)
- Problem: The report says untrusted genetics are handled, but a save whose genetics hold a non-Dictionary `ivs`, `evs` or `level_gains` raises `SCRIPT ERROR: Invalid call. Nonexistent function 'get' in base 'String'`. My probe hit it with ivs='x'. PetRecord.recompute then falls back to neutral genetics, so nothing is lost, but debug builds stop on it. The line predates this package.
- Fix: Read each table as `var t: Variant = data.get("ivs", {}); if not t is Dictionary: t = {}` before the loop.

### 8. game/scripts/world/taming_pen.gd:72-75 (legacy tamed_animal path)
- Problem: try_insert bonds a legacy tamed_animal item at Lv1 and returns true without inserting anything. It shows no notice and bonds one item per tap. A survivor holding both a legacy tamed_animal and a captured_animal must tap twice to start the pen.
- Fix: Acceptable for a legacy-only path. Optionally add a player.notice after bonding and fall through to the captured_animal insert.

### 9. game/scripts/pets/pet_record.gd:from_dict
- Problem: Loaded identity fields are not validated. `origin` accepts any string (my probe got `market_dupe`), `wild_level` can exceed `level`, `name` has no length limit, and duplicate uids are not detected. Offline this is the player's own save, but the server validator must not trust these fields.
- Fix: Add these fields to the W2-INT AssetValidator hook, with an origin whitelist, wild_level <= level and uid uniqueness per owner.

### 10. tools/web_pack_for_vercel.py:4 (module docstring)
- Problem: The usage text was spliced into the middle of a sentence: "Godot's loader expects one file named index.pck. Usage: web_pack_for_vercel.py OUT_DIR [--soak] We download the parts in the browser..."
- Fix: Put the Usage line on its own line after the description.

### 11. game/scripts/items/held_model.gd:24-41 and station_craft.gd:_sync_hand_tool
- Problem: When hunting with a weapon whose props_manifest row has model null (spear, bow), attach returns null and the hand is empty. _sync_hand_tool then retries every frame (ResourceLoader/tool-key lookups per frame). Probe: 'hunting held spear row_model=<null> attached=false'.
- Fix: Fall back to the gather tool model, or cache a 'no model' marker per def_id so the attach is not retried every frame.

### 12. game/scripts/items/crafting.gd:419 finish_craft doc + station_craft.gd:_finish_one
- Problem: The doc says overflow units are kept by the caller, e.g. at the station. StationCraft only push_errors and drops them. The branch should be unreachable because output_fits runs first, but if it is ever reached it loses items silently and the comment misdescribes it.
- Fix: Re-add the overflow units or drop them into the world, or correct the comment.

### 13. game/scripts/items/item_stack.gd:from_dict
- Problem: Provenance cleaning is partial. created_at 1e300 loads as INT64_MAX ('created=9223372036854775807'). A non-string uid is stringified ({"a":1} -> '{ "a": 1 }'). The format ('i<seq>'/'l<hex>') is never checked, though the comment says vault and market will trust these fields.
- Fix: Clamp created_at to a sane upper bound such as now plus slack, and accept uid only as a String matching ^[il][0-9a-f]+$ (else blank it).

### 14. game/scripts/items/item_stack.gd:duplicate_stack / Inventory.remove_at
- Problem: Splitting a uid'd stack gives both halves the same uid. Probe: '[probe] split shares uid=true'. Only stack_max==1 crafts get a uid today, so this cannot happen yet. It is documented as integrator hook 5.
- Fix: Re-mint the taken part's uid on split (server side in W1-SRVDOM, or in W2-INV's remove_at), as the report says.

### 15. game/scripts/creatures/creature_anim.gd _travel() ONESHOT replay via _playback.start()
- Problem: Replaying the one-shot the machine is already on teleports to frame 0 with no crossfade. A back-to-back attack therefore pops for one frame. Behaviour is otherwise correct: P5 in r3/hostile.log shows hits=1 and done=1.
- Fix: Accept as polish, or add a self-transition with a short xfade if the pop shows in play.

### 16. game/scripts/pets/pet_record.gd recompute() (the 'd == null' early return)
- Problem: A save row for an unknown species keeps its stored stats unsanitized. A probe loaded species 'dodo' with hp 1e9, and the pet kept hp=1000000000.
- Fix: Have the W1-SAVE sanitizer drop unknown species (already planned), or clamp stats to 0 or neutral when the def is missing.

### 17. game/scripts/pets/pet_record.gd from_dict (origin, uid)
- Problem: origin is accepted as any string, and uids are not checked for uniqueness across a roster on load. Two save rows sharing a uid both load (probe: dup uid load same=true). This matters once the market keys pets by uid.
- Fix: Whitelist origin values, and leave roster-level uid dedupe to the W2-INT validator. Note both in the hooks.

### 18. game/scripts/world/harvest_node.gd:305-320 with player.gd:818-821
- Problem: The tier gate works in HarvestNode.can_gather, but in game a bare-handed player at copper or iron never sees 'needs <tier> pick'. _auto_equip_tool prints 'need tool pick' first, and refusals are print-only, never notice(). player.gd is protected, so the package cannot fix this.
- Fix: W2-PLAYER or the integrator applies hook 2: call node.can_gather before the auto-equip and notice(why).

### 19. game/scripts/world/harvest_node.gd:132-138, 522-531 (_occupied)
- Problem: No test covers the new 'no regrow while someone stands on the node' behaviour (phys-node-01). t_items checks only the collider height.
- Fix: Add a t_items case: a depleted node, a Node3D in group 'player' at its position, then _process past regen; assert it stays depleted, and refills once the body moves away.

### 20. game/scripts/dev/foundation_lab.gd:57-61 (W1-QA owned)
- Problem: roll_yield now strips the climate stamp (inv-01). foundation_lab still claims and prints 'unmerged climates', which now always reads temperate=0 tropical=0.
- Fix: W1-QA updates the lab text or assertion when it renames the lab to harvest_lab.

### 21. game/scripts/world/prop_visuals.gd:39
- Problem: After this package, PropVisuals.attach_tool_model has no callers: HeldModel replaced its only use. The file is outside the package, so the dead code was left behind.
- Fix: The integrator, or the owner of prop_visuals.gd, deletes it.

### 22. game/scripts/creatures/brains/pack_index.gd:9-30
- Problem: The per-physics-frame pack cache can return freed instances. If a live pack member is freed inside the frame its list was built in, members() still returns it. My probe: '[probe] pack_freed before=3 after=3 stale_entries=1'. Callers then read c.brain without is_instance_valid (_propagate_alert, _idle_pack_slot, leash_break), which raises a script error. Calls from idle-phase callbacks such as anim-event bites hit the same physics-frame number. In practice it needs a live member freed mid-frame (island unload or a despawn).
- Fix: In members(), drop entries that fail is_instance_valid(c) before returning. Alternatively, call PackIndex.invalidate() from Creature's tree_exiting.

### 23. game/tests/t_ai.gd:288-299
- Problem: _test_flee_speed_floor recomputes max(base*flee_speed_mult, flee_min_mps) from the profile instead of running creature.gd's flee-speed code. Deleting the floor in creature.gd:512 would not fail t_ai; only the sweep's worst-IV flight would catch it.
- Fix: Put the flee speed in a small Creature function that both the physics step and the test call, or set state=flee, step one physics frame and assert on velocity.

### 24. game/scripts/creatures/brains/creature_brain.gd:13
- Problem: The alias const LOD_RADIUS := BrainRest.LOD_RADIUS is never used; only BrainRest.LOD_RADIUS is read.
- Fix: Delete the alias.

### 25. game/tests/t_tame.gd (each _test_* function)
- Problem: There is no completion sentinel. A GDScript runtime error aborts only the current test function: my probe confirmed the caller keeps going ('[probe] caller continued after runtime error'). A crash between two _expect calls therefore skips the rest of that section's asserts, and the run can still print '[t_tame] PASS'. In my mutant (smilodon def removed) the asserts before the crash happened to fail, and the '[t_tame] rules ...' summary line silently disappeared.
- Fix: Have each _test_* bump a counter on its last line and require counter == 7 before printing PASS, or make the runner treat any 'SCRIPT ERROR' line as FAIL (this extends integrator hook 5).

### 26. game/scripts/world/taming_pen.gd:_process (success path)
- Problem: PetRecord.from_def(def, ...) is called without a null check. A captured_animal whose species is no longer in data crashes the pen's _process after running=false has been set. The pen keeps a stale occupant, and the next try_insert overwrites it, so the animal is lost. The escape path (_spawn_wild(null)) has the same pre-existing issue.
- Fix: Guard def == null: print, keep the occupant, and stop, or return the item to the player.

### 27. game/scripts/creatures/creature_genetics.gd:from_dict
- Problem: Malformed nested genetics, such as {"ivs": 5}, raise a SCRIPT ERROR ("Nonexistent function 'get' in base 'int'"). The pet then loads with neutral genetics. Nothing crashes, but the report calls this a trust boundary and it logs errors.
- Fix: Type-check data.get("ivs") / evs / level_gains with `is Dictionary` before calling .get on them.

### 28. tools/check_export_payload.py:main
- Problem: Argument parsing is fragile: '--max-mb' or '--top' without a value raises a bare IndexError. The over-ceiling message rounds, so a pack of 220,000,001 bytes reads 'pack is 220.0 MB, over the 220 MB ceiling'.
- Fix: Use argparse, and print the byte count alongside the MB figure in the ceiling error.

### 29. game/scripts/dev/hunt_lab.gd (_spawn_groups)
- Problem: Combat rolls in hunt_lab use the unseeded CombatTuning.rng, so the 3.2 s acceptance beat is not deterministic. Survivor HP at 3.2 s ranged 18-80 over my 6 runs, and the report saw 9-82 with three raptors. No run failed, but the margin is one crit.
- Fix: Set CombatTuning.rng.seed to a fixed value in _ready so the acceptance shot is reproducible, and keep the assertion.

### 30. game/scripts/dev/raid_gear_probe.gd:74,88; game/scripts/dev/counter_matchup_probe.gd:14 (not owned)
- Problem: These probes call the global seed() to make combat deterministic. Creature and survivor rolls now go through CombatTuning.rng, which that seed does not touch, so their results (for example 'real boss contact kills in 4-6 landed hits') are now random from run to run. status_effects.gd:213 still uses the global randf(), which contradicts 'one seedable RNG'.
- Fix: Integrator hook: add CombatTuning.rng.seed = <same seed> next to each seed() call. In the owned status_effects.gd:213, switch to CombatTuning.roll().

### 31. game/scripts/combat/hunt.gd say_throttled
- Problem: One 3 s timestamp throttles every message. If 'Something is in the way.' was shown, a 'No clear shot' notice within the next 3 s is silently dropped, and the reverse.
- Fix: Throttle per message text (a small Dictionary of text to last time), or keep separate timestamps for melee and ranged.

### 32. game/scripts/combat/hunt.gd fire_ranged (range_left = def.range_m * 1.5)
- Problem: A new tuning number is hard-coded in code although the spec moves formulas into combat_tuning.json. A missed stone also flies 50 % past the weapon's range.
- Fix: Move it to ranged.arc_range_mult in combat_tuning.json, or compute the arc length from launch_velocity.

### 33. game/scripts/combat/melee_query.gd blocker()
- Problem: Every query allocates a new SphereShape3D. While a fence blocks melee, _auto_attack calls MeleeQuery.clear every frame, so that is up to 6 casts plus one resource allocation per frame for each blocked survivor.
- Fix: Cache one static SphereShape3D and set its radius per call. Optionally skip the per-frame clear() retry until the throttle window passes.

### 34. game/scripts/combat/stone_projectile.gd impact -> Hunt.wear_weapon
- Problem: Stones still in flight after the slingshot breaks call wear_weapon on the broken stack again, so each of them repeats the 'X broke.' notice and print.
- Fix: Return early in wear_weapon when w.is_broken().

### 35. game/scripts/world/dirt_disc.gdshader:28 + WorldLighting moon (gl_compatibility only)
- Problem: On the web renderer at night, the camp dirt pads around the chest and tent read as near-black halos. Measured patch luminance at tod 0.0: chest pad 0.087 in compat vs 0.241 in Forward+. The bonfire pad is 0.143 vs grass near the fire at 0.162. The pad albedo is now tint*(0.11-0.33). In compat it sits under a moon shadow, and the fire is weaker in compat. lighting_lab's disc_ratio only runs in daylight (compat 0.83), so this is untested. On-reference (Durango pads are dark), but lv-dirt-18's 'black stains' are still visible on the deploy renderer at night.
- Fix: Add a night disc-vs-grass check in compat to lighting_lab. Then raise the pad floor (for example tint*(0.16+0.22*detail)) or cut the compat moon shadow strength, until compat night pads sit within about 0.6x of the grass near the fire.

### 36. game/data/world/lighting.json default.saturation 1.25
- Problem: The renderers disagree on grass hue. Mean grass in my matched day shots: Forward+ hue 76 deg, sat 0.45 (olive) vs compat hue 96 deg, sat 0.50 (lime). The gap was already there (86 vs 105 deg before). It is not closed, and the 1.25 saturation raises saturation in both. The web build ships compat.
- Fix: Add a compat-only saturation or exposure key (as was done for moon_energy_compat). Have lighting_lab print the ground hue in both renderers so the drift is visible.

### 37. game/scripts/world/world_lighting.gd:18 FALLBACK
- Problem: The fallback profile, used when lighting.json is broken, has no colour keys. _c() then returns WHITE for fog_night_color and every sky colour, so a broken JSON gives white night fog and a white sky. The comment says a bad edit 'dims nothing to black', but it washes out instead.
- Fix: Copy the default colour keys into FALLBACK, or add a t_light case that loads FALLBACK and checks night fog luminance <= 0.15.

### 38. game/scripts/dev/lighting_lab.gd:51
- Problem: Headless runs print '[lighting] SKIP' and exit 0, so a CI gate that runs the lab headless passes without measuring anything (qa-render-01 wants a real web-renderer gate).
- Fix: Exit 2 (or 1) on headless unless a --allow-skip flag is passed. W1-QA should run it windowed.
