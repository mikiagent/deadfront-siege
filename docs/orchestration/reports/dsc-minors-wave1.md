# dsc — wave-1 minor findings

One line per finding: fixed (file:line) / skipped (why). Status: in progress.

1. fixed — `game/scripts/world/placed_building.gd:40` (gate_open uses `== true`, so a wrong-typed `open` cannot abort the restore)
2. fixed — `game/scripts/dev/siege_probe.gd:35` (max_hp set to 250 before the label check; a wrong label quits 1)
3. pending
4. fixed — `game/scripts/world/build_placer.gd:229` (a field packs its floor(fertilizer_overflow) back as fruit_fertilizer); `t_build` covers the overflow and the pen occupant
5. fixed — `game/scripts/world/build_placer.gd:219,556` (packed kits carry the `repacked` flag; re-placing one skips +8 construction and +30 pioneer XP)
6. fixed before the batch — `game/scripts/creatures/creature_clips.gd:61` already ignores a bake whose `*_len` is >1 % off and prints once; verified by `t_canim._test_bad_input_and_stale_bake`
7. fixed — `game/scripts/creatures/creature_genetics.gd:104` (`_table()` type guard)
8. fixed — `game/scripts/world/taming_pen.gd:76` (legacy bond notices, then falls through to the captured_animal insert; stays put only at the bonded cap)
9. fixed — `game/scripts/pets/pet_record.gd:209` (origin whitelist, uid format, name/tamed_at caps, wild_level <= level); roster-level uid dedupe stays in W2-INT by design
10. pending
11. fixed — `game/scripts/items/station_craft.gd:407` (a `no-hand-model` cache keyed def_id/hunting, so a spear or bow attach is tried once, not every frame)
12. fixed — `game/scripts/items/crafting.gd:419` doc corrected and `game/scripts/items/station_craft.gd:335,282` now retains overflow units and retries the add each tick instead of dropping them
13. fixed — `game/scripts/items/item_stack.gd:227` (uid only as `^[il][0-9a-f]+$`, created_at clamped to now + 86400)
14. fixed — `game/scripts/items/item_stack.gd:90` (`remint_uid`) + `game/scripts/items/inventory.gd:184`
15. skipped — tried a self-transition for the one-shot replay: Godot's state machine then reported a zero clip length and broke attack_hit/attack_done timing (t_canim failed); reverted, one-frame pop accepted as polish
16. fixed — `game/scripts/pets/pet_record.gd:100` (unknown species neutralises the cached stats)
17. fixed — `game/scripts/pets/pet_record.gd:203` (see 9; the duplicate-uid hook is left to the W2-INT validator)
18. pending
19. pending
20. pending
21. fixed — `game/scripts/world/prop_visuals.gd:39` (dead `attach_tool_model` removed; `HeldModel.attach` is the only path)
22. fixed — `game/scripts/creatures/brains/pack_index.gd:30` (members() drops entries failing is_instance_valid before returning)
23. fixed — `game/scripts/creatures/creature.gd:224` (`flee_speed()` shared by the physics step and `t_ai`, which also steps a real physics frame)
24. fixed — `game/scripts/creatures/brains/creature_brain.gd:13` (unused LOD_RADIUS alias deleted)
25. pending
26. fixed — `game/scripts/world/taming_pen.gd:127` (species missing from data: print, keep the occupant, leave the pen waiting)
27. fixed — `game/scripts/creatures/creature_genetics.gd:104`
28. pending
29. fixed — `game/scripts/dev/hunt_lab.gd:20` (CombatTuning.rng seeded in _ready)
30. fixed — `game/scripts/combat/status_effects.gd:213` uses CombatTuning.roll(); probes seeded too (`raid_gear_probe.gd:78,93`, `counter_matchup_probe.gd:15`)
31. fixed — `game/scripts/combat/hunt.gd:22,256` (per-text throttle dictionary)
32. fixed — `game/data/combat_tuning.json:44` (`ranged.arc_range_mult`), read at `game/scripts/combat/hunt.gd:378`
33. fixed — `game/scripts/combat/melee_query.gd:14` (one static SphereShape3D, radius retuned per call)
34. fixed — `game/scripts/combat/hunt.gd:237` (wear_weapon returns early on a broken weapon)
35. pending
36. pending
37. pending
38. pending
