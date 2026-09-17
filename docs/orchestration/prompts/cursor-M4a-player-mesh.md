# Cursor follow-up M4a — the real player character

A rigged, textured survivor generated through Meshy now lives at `game/assets/characters/survivor/` in the same layout as creatures: `survivor.glb` (rigged, skinned, 24 bones, 1.72 m, faces +Z) plus `anim/idle.glb`, `anim/walk.glb`, `anim/run.glb`, `anim/hit_react.glb`, `anim/death.glb`. Each clip file is a full skinned GLB of the same skeleton with one animation. Metadata, including facing and clip list, is in `game/data/characters/survivor.json`. Do this after M1b (the clip-track remap and scale/facing normalisation), because the player reuses that code.

## Tasks

1. **Generalise the loader.** Move the clip-merging and path-remapping logic from `CreatureClips` / `CreatureView` into a reusable `RiggedModel` node (`scripts/core/rigged_model.gd`): given a base GLB path, an `anim/` folder, a facing axis and a target height, it instantiates the mesh, normalises facing and scale, merges every `anim/*.glb` into one `AnimationLibrary` under the file's name, and exposes `play(clip)`, `signal clip_finished`, and `skeleton`. `CreatureView` becomes a thin wrapper over it (placeholder path stays for species with no GLB).

2. **Player scene.** Replace the capsule and nose in `scenes/main.tscn` / the player scene with a `RiggedModel` child loading the survivor. Keep the CollisionShape3D capsule (0.35 radius, 1.8 height). Camera-relative movement is unchanged; the model must face its movement direction (it faces +Z in the file, so the same normalisation as creatures applies).

3. **Player animation state machine** (`scripts/player/player_anim.gd`): idle, locomotion 1D blend on horizontal speed (walk at 0–5.5 m/s, run above), hit_react on damage, death on zero health (holds). Clips that do not exist yet play a labelled placeholder: `attack_primary`/`attack_heavy` (weapon swing) and `roll`, `gather`, `knockdown` use `idle` with a short time-scale bump and print `[player] missing clip <name>` once. The hunt system's auto-attack and the roll tactic must call into this state machine instead of doing nothing visually.

4. **Mount socket and gather anchor.** Add `Marker3D` nodes on the model for right hand (tool attachment later) and hips (mount alignment), found by bone name `RightHand` and `Hips` via `Skeleton3D` bone attachment (`BoneAttachment3D`).

5. **Labs.** All three labs and the default scene must show the survivor instead of the capsule. Take a screenshot of `hunt_lab` with the survivor mid-fight and one of the survivor riding a velociraptor in `capture_lab`; save to `docs/orchestration/reports/`.

## Acceptance
- `tools/smoke.sh` passes (the smoke check finds the player by group; keep that).
- Headless run of any lab prints no `missing bone` lines for the survivor and at most the listed `[player] missing clip` lines.
- Screenshots referenced in `docs/orchestration/reports/cursor-M4a-player-mesh.md`.
- Commit as `M4a: survivor player model and animation state machine`.
