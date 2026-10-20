# dsc: wave-1 minor findings

One line per finding: fixed (file:line), partly fixed, not fixed (reason) or wrong finding
(evidence). Line numbers are on branch `claude/mmo-dsc-minors` after the merge of
`claude/mmo-overhaul`. Count: 33 fixed, 3 partly fixed (9, 17, 36), 1 not fixed (15),
1 wrong finding (6). Findings 1, 22, 26, 29 and 35 were reported fixed in the first round but
were not; the second review round (below) fixed them, and each now has a check that fails on
the first-round code.

1. fixed (round 2): `game/scripts/world/placed_building.gd:40` (`ov is bool and ov`; the round-1 `== true` raised on a String, Array or Dictionary just like `bool()`). `t_save._test_gate_open_direct` calls `from_dict` directly with "true", [], {}, 1, null and true, because SaveSanitizer coerces `open` before the restore path reaches it
2. fixed: `game/scripts/dev/siege_probe.gd:39` (max_hp 250 before the check; a wrong label quits 1)
3. fixed: `game/scripts/world/tile_path.gd:6,84` (contract note on the shared `last_reachable`, plus `path_result()` returning {points, reachable})
4. fixed: `game/scripts/world/build_placer.gd:239` (a field packs floor(fertilizer_overflow) back as fruit_fertilizer). Round 2: `field_plot.gd` clamps `fertilizer_overflow` on load to 0..20 (finite), so a forged save cannot mint fertiliser or make pack-up refuse; t_build covers INF, -INF, NAN, 1e9, -3; `t_build` covers the field overflow and, added by the finisher, packing up an occupied pen (kit and captured_animal come back). Taming progress is still dropped on pack-up, as the finding describes
5. fixed: `game/scripts/world/build_placer.gd:23,227,481,558` (packed kits carry a `repacked` flag; re-placing one skips the +8 construction and +30 pioneer XP). Limits: a flagged kit does not merge with fresh kits, and with both in the bag the first slot decides whether XP is paid
6. wrong finding (already fixed): `game/scripts/creatures/creature_clips.gd:61-70` at the merge base 55c6541 already ignores a bake whose `*_len` is more than 1 % off and prints once; `t_canim._test_bad_input_and_stale_bake` covers it. The rebake after the merge was not run (`tools/bake_clip_speeds.py`); a stale row is ignored at runtime
7. fixed: `game/scripts/creatures/creature_genetics.gd:101-116` (`_table()` type guard on ivs, evs and level_gains)
8. fixed: `game/scripts/world/taming_pen.gd:72-80` (the legacy bond shows a notice, then falls through to the captured_animal insert; stops only at the bonded cap)
9. partly fixed: `game/scripts/pets/pet_record.gd:16,212,215,243` (origin whitelist, uid format, name cap of 24, tamed_at clamp, wild_level <= level). Not fixed: uid uniqueness per owner. `from_dict` sees one row; that check belongs in the W2-INT AssetValidator
10. fixed: `tools/web_pack_for_vercel.py:7` (Usage on its own line)
11. fixed: `game/scripts/items/station_craft.gd:409-421` (a no-model cache keyed def_id/hunting, so a spear or bow attach is tried once, not every frame)
12. fixed: `game/scripts/items/crafting.gd:422` (doc corrected) and `game/scripts/items/station_craft.gd:341` (overflow units are held and re-added each tick instead of dropped). Limit: held units are not saved, so quitting with a full bag still loses them. The branch should stay unreachable because output_fits runs first
13. fixed: `game/scripts/items/item_stack.gd:227,233` (uid accepted only as a String matching `^[il][0-9a-f]+\z`; created_at clamped to now + 86400). Round 2: `$` also matched before a trailing newline, so both uid regexes (here and `pet_record.gd:18`) anchor with `\z`; t_items and t_save cover "i12\n" / "p_12\n"
14. fixed: `game/scripts/items/item_stack.gd:86` (`remint_uid`) and `game/scripts/items/inventory.gd:186`; t_items checks a split
15. not fixed: a state-machine self-transition made Godot report a zero clip length and broke attack_hit/attack_done timing (t_canim failed), so it was reverted. The one-frame pop is accepted polish, which the finding allows (`creature_anim.gd:253` comment)
16. fixed: `game/scripts/pets/pet_record.gd:100` (an unknown species zeroes the cached stats instead of keeping stored numbers)
17. partly fixed: origin whitelist as in 9. Not fixed: roster-level duplicate uids, left to the W2-INT validator as the finding suggests
18. fixed: `game/scripts/player/player.gd:821-833` (can_gather runs before auto-equip; refusals go through notice(), e.g. "Needs obsidian pick"). Round 2: only the first letter is upper-cased ("Need tool axe", was "Need Tool Axe"), and `t_build._test_gather_refusal_notice` drives `_begin_gather` bare-handed at copper and at a tree and asserts both notices. Merge risk: W2-PLAYER is splitting player.gd, so the integrator has to carry this hunk into PlayerActions
19. fixed: `game/tests/t_items.gd:127` (`_test_regen_blocked_by_occupant`: a depleted node stays empty under a body and refills once it moves)
20. fixed: `game/scripts/dev/foundation_lab.gd:53-62` (prints the merged fibre count and how many units still carry a climate stamp)
21. fixed: `game/scripts/world/prop_visuals.gd` (dead `attach_tool_model` removed; round 2 also removed the tombstone comment)
22. fixed (round 2): `game/scripts/creatures/brains/pack_index.gd:28-40`. The round-1 typed `filter` lambda raised "Cannot convert argument 1 from Object to Object" on the freed entry and wrote an empty list back, so the live members vanished too. Now an untyped scan rebuilds the list only when an entry is stale. `t_ai._test_pack_member_freed_in_frame`: 3 raptors, free one in-frame, members() returns the other 2 with 0 logged errors (round-1 code: after=0, errors=2)
23. fixed: `game/scripts/creatures/creature.gd:225` (`flee_speed()` shared by the physics step and `t_ai.gd:288`, which also steps a real physics frame)
24. fixed: `game/scripts/creatures/brains/creature_brain.gd:11` (unused LOD_RADIUS alias and its doc comment deleted; BrainRest.LOD_RADIUS is the one constant)
25. fixed: `game/tests/t_tame.gd:33-45` (each _test_* bumps `_sections`; PASS needs all 7). Mutant-checked by dsc: a runtime error in _test_rules now prints FAIL
26. fixed (round 2): `game/scripts/world/taming_pen.gd:70,110-120`. Round 1 cleared `running` before the guard, so the next try_insert overwrote the occupant. Now try_insert refuses whenever an animal is inside, and the guard keeps the pen running with a one-game-minute retry, so a save made while the species is missing finishes once the data is back; pack-up still hands the animal back. t_build retries an insert with a second captured_animal after the unknown-species finish (round-1 code: insert=true, occupant lost)
27. fixed: same guard as 7
28. fixed: `tools/check_export_payload.py:127` (argparse) and `:118` (the ceiling error prints bytes next to MB)
29. fixed (round 2): `game/scripts/dev/hunt_lab.gd:20-21,84`. Seeding CombatTuning.rng was not enough (75/59/100 HP in the review, 73/81/79 here with the global seed added too): Creature.spawn rolls IVs from a fresh `randomize()`d RNG that no seed reaches. `_starter_level` now gives the lab animals `CreatureGenetics.neutral()`. Five headless runs (three in parallel, then two more while the full gate ran on a loaded machine) each printed `hp=76 at 3.2 s`
30. fixed: `game/scripts/combat/status_effects.gd:213` (CombatTuning.roll()); probes seeded at `raid_gear_probe.gd:78,93` and `counter_matchup_probe.gd:15`
31. fixed: `game/scripts/combat/hunt.gd:22,257` (throttle per message text)
32. fixed: `game/data/combat_tuning.json:33` (`ranged.arc_range_mult` 1.5), read at `game/scripts/combat/hunt.gd:380`
33. fixed: `game/scripts/combat/melee_query.gd:14` (one static SphereShape3D, radius set per call). The optional skip of the per-frame clear() was not done
34. fixed: `game/scripts/combat/hunt.gd:238` (wear_weapon returns early on a broken weapon); t_combat covers it
35. fixed (round 2): `game/scripts/dev/lighting_lab.gd` `_pad_ratios` and `game/scripts/world/dirt_disc.gdshader:29-36`. The round-1 check took one median over all pads, so the fire-lit bonfire pad hid the dark ones. Each pad is now measured against its own outer ring and the worst pad must reach 0.6x; on the round-1 shader compat FAILED it (CargoWarp 0.49, CampBench 0.80). On gl_compatibility only (`CURRENT_RENDERER` define) the pad floor rises from 0.11 to 0.16. Windowed 1600x900: compat worst pad 0.82, day disc 0.94, PASS; Forward+ unchanged (worst 1.32, day 1.18), PASS. Night crops before/after were checked by eye: the chest and A-frame pads read as dark earth with their shadows visible, not black halos. An alpha-scissor (opaque) pad was tried first and did not help (0.45), so the darkening is not the transparent pass
36. partly fixed: `game/data/world/lighting.json:21` `saturation_compat` 1.2, applied at `game/scripts/world/world_lighting.gd:155` on gl_compatibility only (the finisher moved it off `_compat`, which also covered the phones' mobile renderer). lighting_lab prints hue and saturation per renderer. Windowed: grass saturation compat 0.42 vs Forward+ 0.43 (1.1 gave 0.39). Not fixed: the hue gap, compat 88 deg vs Forward+ 58 deg. Saturation cannot move hue
37. fixed: `game/scripts/world/world_lighting.gd:19-31` (FALLBACK carries every colour key) and `game/tests/t_lighting.gd:31` (fallback night fog luminance <= 0.15)
38. fixed: `game/scripts/dev/lighting_lab.gd:57-66` (headless exits 2 unless `--allow-skip` is passed)

## Lab flakiness fixed on the way (not in the 38, but it blocked the gate)

`game/scripts/dev/combat_rules_lab.gd` failed at random with 2-3 different checks; each was a
measurement artefact, not a regression:
- kick/tackle: `use_kick()`/`use_tackle()` are no-ops while the survivor's clip is busy or a
  tactic lock is left, and the lab fired them after a fixed 1.2 s wait. It now waits on
  `Hunt.can_start_tactic()`.
- swing timing: the swing start was read by polling `anim.current_clip` per process frame, which
  recorded it 1-2 frames late and made the measured gap 0.208 s instead of 0.39 s. It now stamps
  `swing_started` and `hit_landed` on Hunt's own signals (steady 0.278 s).
- fence/control bouts: bite and dodge rolls decided whether the control reached its bite count
  (1, 2 and 7 seen). The bouts now force accuracy 1.0 / dodge 0.0, so the control only asks whether
  the raptor can reach and bite (>= 2 in 10 s); the fence still has to hold at 0 against an
  attacker that cannot miss.

`game/scripts/dev/wild_ai_sweep_lab.gd` also failed intermittently on its 24-creature perf budget
(2.05 ms vs 2.0 ms at load 2.7/4.2/5.5, no code change). `_perf` now takes the best median of up
to three five-window passes, 10 s apart, and logs every pass with its load average. Budgets are
unchanged (2.0 ms at 24 creatures, 8.0 ms at 120). Regression check (Claude, finisher): with a
temporary `OS.delay_usec(50)` at the top of `Creature._physics_process` the lab still FAILS: 24
creatures read 35.30 / 2.76 / 3.05 ms over three passes (best 2.76 > 2.0), 120 creatures 14.74 /
13.99 / 14.09 (best 13.99 > 8.0), rc=1. Clean run: 1.01 ms and 3.60 ms on the first pass, PASS,
112 s; the injected run took 171 s, under the gate's 300 s alarm.

`game/scripts/dev/ai_validation_lab.gd` failed intermittently on "pet repeat attack stalled:
bites=1": the same attack cadence produced 1 or 3-4 bites depending on the pet's hit rolls, so the
section now forces accuracy 1.0 / dodge 0.0 (and restores the overrides). It still catches the
original bug (a frozen `_attack_cd` after one bite) but no longer fails on a bad roll.

## Finisher (Claude), after the dsc run ended on a model error

- Perf gate (uncommitted from dsc): kept and tidied. The unused load-average read is gone and
  the lab no longer waits after the last pass. The regression check above shows a real
  regression still fails. Budgets are unchanged.
- Merged `claude/mmo-overhaul` (18 commits, harbour work). Only `tile_path.gd` changed on both
  sides, and it auto-merged into separate hunks.
- Untracked 41 generated files that the dsc batch had committed: treestump and woodlog `.import`
  and `_Image_` extracts, plus `.gd.uid` files. They stay on disk. Committed, they would
  add/add-conflict with the branches that own those assets.
- Review fixes: `saturation_compat` now applies on gl_compatibility only. The overflow flush in
  `StationCraft._process` moved after the player null check. A dead retry branch in
  `player._begin_gather` was dropped: can_gather and auto-equip use the same
  `find_gather_tool`, so the retry could never succeed. Added the occupied-pen pack-up case to
  t_build.
- Gate, run through gslot by the finisher: `tools/dsc/verify_minors.sh` exited 0 twice. The
  first run was right after the merge. The second ran on the review fixes: all 12 test
  scripts, all 8 labs and smoke PASS. After the last test edit (occupied-pen case),
  `verify_minors_partial.sh` exited 0 and t_build printed the pen line
  `packed=true captured_back=1 kit_back=1`.

## Second review round (Claude)

An independent reviewer found four blockers (1, 22, 26, 29), one major (35) and seven minors.
Each blocker and the major is fixed above with a check that FAILS on the first-round code:
with the seven fixed source files swapped back to their round-1 versions (`7401cd5`), t_save, t_build, t_ai
and t_items all exit 1 on the new cases (gate from_dict raises on "true"; pen insert=true and
the occupant is lost; members after=0 errors=2; uid "i12\n" / "p_12\n" kept; notice
"Need Tool Axe"; overflow loads INF), and with the fixes restored all four PASS.

Minors:
- uid regexes anchored with `\z` (13); fertilizer_overflow clamped on load (4); gather notice
  test and first-letter capitalisation (18); prop_visuals tombstone removed (21).
- `combat_rules_lab.gd`: the dead `_swing_probe` polling is gone, and so are `_game_t`, its
  `_process` and the `process_priority = 1000` that only existed for that polling.
- `t_tame.gd`: `_sections += 1` sits at the end of `_test_rules`, above the doc comment of
  `_test_untrusted_load`.
- The dsc brief moved from the repo root (`TASK_minors.md`) to `tools/dsc/minors/TASK.md`.
- Trailers: 11 dsc commits in `494b749..52d1db3` lack `Co-Authored-By: DeepSeek (dsc)
  <noreply@deepseek.com>`. History is not rewritten; the integrator's merge commit of this
  branch should carry that trailer.

## Follow-ups this leaves open (not in the 38)

- W2-BUILDSYS: the compat hue gap (36). Compat night pads are now >= 0.6x per pad (35), still
  darker than on Forward+; the mobile renderer (phones, native) was not measured.
- W2-INT: roster-level pet uid uniqueness (9, 17).
- W2-PLAYER / integrator: port the `_begin_gather` hunk (18) into the player split.
- Rebake natural speeds after GLB changes (`tools/bake_clip_speeds.py`, 6).
- The lab is still named `foundation_lab`; the rename to `harvest_lab` belongs to W1-QA.

No dependencies, autoloads or UI files were added or touched. `game/override.cfg` and
`game/project.godot` are unchanged.
