# Cursor M1 — creature runtime

Placeholder-first creature scene on the SCHEMA clip contract. No files under `game/assets/creatures/<species>/<species>.glb`; every spawn used the primitive placeholder (capsule body, box head, tapered tail, two legs) yawed 180° on `CreatureView`.

## What shipped
- `CreatureDef` from JSON. `# ASSUMPTION:` `move_speed_mps = speed / 100.0`.
- `Creature` + `Health` + `CreatureView` + clip loader + `AnimationTree` state machine (idle, locomotion blend, attacks, hit_react, knockdown hold, death hold, alert).
- Placeholder procedural clips on `View:pose_kind` / `View:pose_t`. Hit events fire from clip-length × `data/creatures/anim_events.json` fractions (default 0.55).
- `# ASSUMPTION:` JSON archetypes `pack_raptor` / `pack_flanker` / `apex_raptor` map to `RaptorPackBrain` (SCHEMA lists `raptor_pack`).
- `# ASSUMPTION:` perception = `8 + tier * 0.15` m.
- Pack aggro, ±60° flank slots at 3 m, heavy pounce at 4–7 m off-axis, flee below 30% HP (apex does not).
- `Spawner` and `creature_lab` (3 velociraptors as pack 1, deinonychus pack 2, utahraptor pack 3). Keys 1–9 force clips on the nearest creature; F deals 100 HP (`Game.lab_force_clips` / `lab_flat_attack`).

## Lab output
```
[creature] velociraptor spawned pack=1
[creature] velociraptor spawned pack=1
[creature] velociraptor spawned pack=1
[creature] deinonychus spawned pack=2
[creature] utahraptor spawned pack=3
[boot] lab=creature_lab
```
No AABB height warnings (placeholders are built from `height_meters`). When a GLB lands at `res://assets/creatures/<id>/<id>.glb` plus `anim/<clip>.glb`, `CreatureView` / `CreatureClips` pick it up with no code change.

## Blocked
- No accepted species GLBs in the handoff path. `work/` intermediates are `.gdignore`d and unused.
- AnimationTree is built at runtime; locomotion also drives `AnimationPlayer.play` so placeholder pose tracks stay reliable.

## Reproduce
```
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=creature_lab
```
Keys 1–9 = idle, walk, run, attack_primary, attack_heavy, hit_react, knockdown, death, alert.
