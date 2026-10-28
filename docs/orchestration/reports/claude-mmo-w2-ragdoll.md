# W2-RAGDOLL: dinosaurs ragdoll on death (Claude)

Owner request (2026-10-20): "if you're having issues with dead dinosaurs not staying on the ground,
try having them ragdoll on death". Spec: `docs/orchestration/mmo/handoff/ragdoll-spec.md`.

## What shipped

- `game/scripts/creatures/ragdoll.gd` (`Ragdoll`): one per death. Plays `hit_react_s` (0.3 s,
  per species) of the death clip, then builds the ragdoll, pushes it from the killing blow (scaled by
  damage, capped) on the real terrain collider and static props, and freezes when every body is quiet
  or at the 3.0 s cap. Freeze copies the simulated pose onto the skeleton, frees every physical bone,
  turns off every skeleton modifier (a frozen corpse costs nothing per frame), puts the creature root
  on the ground under the hips and conforms the posed skin so its lowest vertex touches the ground.
  Budget: at most `budget.max_active` = 4 simulating. Over budget, no profile, no skeleton, or an
  unstable run (NaN, a body over 30 m/s, a joint stretched > 35 %) falls back to the death clip plus
  the same terrain conform. Dead pets use it and hide when their respawn is ready.
- `ragdoll_rig.gd` (`RagdollRig`): PhysicalBoneSimulator3D + capsule PhysicalBone3D per profile body
  (cone = 6DOF, hinge, pin), IK-foot reparenting for the donor rigs, settle/apply pose, release.
- `ragdoll_skin.gd` (`RagdollSkin`): CPU skinning of sampled vertices, ground clearance rays.
- `game/data/creatures/ragdoll.json`: budget, timing, impulse, guards, conform, physics and the 11
  species profiles (now one body per line, 267 lines instead of 2,314).
- `corpse.gd`: no more snap to the flat tile height; `place_settled(world_pos)` is the one seam.
- `creature.gd` (`_on_died` only): creates the corpse, then `Ragdoll.on_death(self, _source, corpse)`.
- `creature_view.gd`: `allow_stegosaurus_rig` (lab only; the game keeps the box placeholder).
- `game/scripts/dev/ragdoll_lab.gd` + `scenes/dev/ragdoll_lab.tscn`: the gate (below).
- `game/tests/t_ragdoll.gd`.

Commits this round: a1426822 (profiles, tear gate, sequences), 78d118f5 (megaloceros), 71efeb54
(merge of the base, conflict in `_on_died` resolved: base's PlayerRegistry lookup kept), 38792fff
(protoceratops shoulders; sequence frames force a draw), plus the report commit.

## DeepSeek's checkpoints (branch claude/mmo-w2-ragdoll-dsc1, stopped)

Kept: its `ragdoll.json` profiles as the starting point (already taken into the WIP commit 8604a0b3).
Dropped: its script edits. It deleted `_test_placeholder_body` from t_ragdoll, put the perf gate back
on `Performance.TIME_PHYSICS_PROCESS` (a per-second max, useless for this) and cut the spawn settle
from 150 to 60 frames; all three made the gates weaker. Its root TASK.md and verify_ragdoll.sh
stay on its branch.

What I changed in its profiles, with the reason:
- Its hip and shoulder joints were "pin" (no limits). The numbers passed, but a pin let a leg spin
  through the trunk: megaloceros' flank and rump tore into long sheets of skin (screenshots). Now
  cones (swing 60-70, side 35-45, twist 12-25) on coelophysis, protoceratops, zebraceratops and
  megaloceros. The four heavy species (tyrannosaurus, stegosaurus, deinonychus, utahraptor) keep
  pins: with cones their limits did not hold and the skin sank under the ground; their skin did not
  tear with pins.
- megaloceros: its front legs hang off `Body` while a separate `Shoulders` body swung against them.
  Shoulders now follows the trunk, trunk 0.33 -> 0.55 m and neck 0.94 -> 0.60 m match the skin, and
  the legs are stiff (cone 15/10/5, knees -5..20, feet -5..10), so the deer topples onto its flank
  in about its standing shape. Its own death clip tears the skin too (see Limits).
- protoceratops: neck 0.25 -> 0.48 m covers the frill (it was sinking 15-20 cm and the conform then
  lifted the whole body); its front legs hang off `Body` too, so `Shoulders` follows the trunk (long
  torn edges 90-270 -> 10-90); body 0.38 -> 0.33 m, slimmer lower legs; its `hips` is now the real
  pelvis bone `Hips` (was `Tail2`).
- zebraceratops keeps its Shoulders body (dropping it pushed its hips over 50 % and one case into
  the fallback).
- Rounded to 3 decimals.

## Acceptance (ragdoll_lab: 11 species x flat, 20-degree slope, against a rock; 4 at once)

Gates per case: settled <= 3.5 s; lowest POSED SKIN vertex within 6 cm of the ground and no vertex
more than 6 cm under it (every 1-4th vertex); hips <= 50 % of standing; no foot above 75 % of
standing hips; not legs-up; bone lengths kept (stretch <= 1 %); no NaN; peak body speed < 30 m/s;
hinges (knees, elbows, ankles) within 8 deg of their limits; cones within 20 deg (see Limits); no
physical bone, active modifier, animation or physics tick left on the frozen corpse; corpse at the
body, with loot. New this round: a skin-tear gate (triangle edges longer than 8 % of the creature's
height that grew past 3x their idle length; at most 0.5 % of edges, or the species' own death-clip
count). Exact lines seen (after the last base merge unless noted):

- `[ragdoll_lab] PASS cases=33 ok=33` headless, `--fixed-fps 60`
- `[ragdoll_lab] PASS cases=33 ok=33` windowed 1600x900 Forward+, 0 SCRIPT ERROR
- `[ragdoll_lab] PASS cases=33 ok=33` windowed 1600x900 gl_compatibility, 0 SCRIPT ERROR
- `[ragdoll_lab] perf median added=0.193ms (max 2.0) frozen_added=-0.320ms` / `[ragdoll_lab] PASS perf`
  (4 simultaneous ragdolls on temperate_25, median of 5 passes; earlier runs 0.049 and 0.094 ms)
- `[ragdoll_lab] PASS phone` (844x390 gl_compatibility, iso camera; tyrannosaurus and protoceratops)
- `[t_ragdoll] PASS`: 5th simultaneous death -> budget fallback, missing profile -> fallback,
  injected NaN -> fallback (IK foot back under its parent, budget released), corpse loot/butcher
  still work after a ragdoll, stegosaurus placeholder -> fallback on the ground, place_settled seam.
- island_lab: `[world] mm=2 nodes=378 creatures=24` (unchanged).
- Peaks: tyrannosaurus 26.3 m/s (highest), others 6-17 m/s. Settles 1.8-3.32 s (cap 3.0 s after
  the 0.3 s hit react).
- SMOKE / run_all / every t_*.gd: see "Gates" at the end.

## Screenshots looked at

Under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/rag/`:
- Final profiles, after the base merge: `post_forward_plus/ragdoll_{flat,slope,rock}_forward_plus.png`
  and `post_gl_compatibility/ragdoll_{flat,slope,rock}_gl_compatibility.png`: every species' frozen
  corpse. All 11 lie on a flank on the ground in both renderers; none hover or sink.
- `post_forward_plus/seq_<species>_<terrain>_forward_plus.png` (33): 2x2 settle sequences (0.2 s
  hit react, 0.8 s, 1.6 s, frozen). Looked at megaloceros flat/slope, protoceratops slope/rock,
  tyrannosaurus slope, zebraceratops rock/slope, deinonychus flat, stegosaurus slope, velociraptor.
  Finer sequences (`--rl-seq=`) in `p_0.4,0.55,0.7/`, `p_0.8,0.9,1.0/`, `s_0.35,0.45,0.55/` and
  `s_0.65,0.75,0.9/` (gallimimus, deinonychus, protoceratops against the rock).
- `phone_trex.png`, `phone_proto.png`: corpses under the game's iso camera at 844x390.
- `fb/seq_megaloceros_flat_forward_plus.png`: megaloceros' own death clip (fallback) for comparison.

What they show: before this round megaloceros sat up like a dog with its torso skin stretched into
sheets, and on the slope it was a torn heap; now it lies on its flank with its legs out. Raptors and
coelophysis lie on their sides; tyrannosaurus lies on its side with its upper leg resting raised
(foot 2.0 m up on a 5.6 m hip, inside the gate); stegosaurus lies on its side with one foreleg
lifted; zebraceratops and protoceratops lie on their sides with legs tucked.

## Integrator hooks

1. Already on this branch, outside the spec's Owns: `game/scripts/core/data.gd` skips
   `ragdoll.json` in `_load_creatures` (same pattern as `ai.json` and `anim_events.json`; without it
   Data tries to load it as a species file). One line.
2. Server seam: `Corpse.place_settled(world_pos: Vector3)` is the only setter of the corpse's
   authoritative resting place; a server can call it with its own position.
3. Optional: Health does not record the killing blow's damage, so the push uses the attacker's
   `attack_for()` (ASSUMPTION). To use the real damage, record it in Health and pass it:
   `Ragdoll.on_death(self, _source, corpse, health.last_damage)` in `Creature._on_died`.
4. `t_ragdoll` is a standalone test (`--headless --fixed-fps 60 --path game --script
   res://tests/t_ragdoll.gd`); run_all was not edited.
5. Lab: `--lab=ragdoll_lab` (flags in the file header: `--rl-species`, `--rl-terrain`, `--rl-perf`,
   `--rl-shots=<dir>`, `--rl-seq=a,b,c`, `--rl-phone=<png>`, `--rl-suggest`, `--rl-fallback`).
   Run windowed labs one at a time: two windows at once can leave one occluded.

## Assumptions

- `ragdoll.gd`: the push scales with the attacker's attack stat (Health has no killing-blow damage).
- `corpse.gd` 90 s / 20 s lifetimes are older assumptions, unchanged.

## Limits and what is left

- The donor meshes stretch skin at folded joints in their own death clips (fallback tear counts on
  flat: megaloceros 2,166, zebraceratops 206, protoceratops 150, gallimimus 82). The tear gate allows
  a species up to its own clip's count; the ragdolls now tear far less than that (megaloceros 0-28).
  The megaloceros death clip (still used for the fallback) is visibly torn: an asset job.
- Cone limits are gated at 20 deg, not 8: the engine's 6DOF joint clamps each axis in its own frame,
  the lab decomposes twist-then-swing, and past ~40 deg of swing they disagree by 10-20 deg. Knees,
  elbows and ankles (hinges) are gated at 8 deg.
- Results are chaotic: a change to one profile, or to which four species share a batch, changes the
  others' outcomes. Protoceratops' hips sit at 0.47 m against a 0.48 m limit on the slope; it passes
  in every run I made but has the least margin.
- On the island perf run a tyrannosaurus once aborted (`joint Metatarsal.L stretched 38 % at 0.48 s`)
  and took the fallback; the fallback is the designed path, but the T. rex foot chain is the least
  stable profile.
- Many heavy species freeze at the 3.0 s cap while a leg is still slowly moving (0.2-1 rad/s); the
  pose is on the ground and passes every gate.
- Mid-fall is a tumble, not a clean topple: protoceratops against the rock rolls onto its back with
  its legs up for about 0.3 s (0.55-0.85 s) before it settles on its flank, and the skin folds at
  the shoulders while it does; megaloceros shows a brief dark stretch at the rump around 0.8 s. Both
  are gone by 1.0-1.6 s; the gates judge only the frozen pose.
- Stegosaurus in game is still the box placeholder (fallback path, tested); the lab uses its GLB.

## Gates (after the last base merge, 71efeb54 and later)

- `tools/smoke.sh --no-import`: `SMOKE PASS`
- `run_all.gd`: `[tests] PASS`
- every `game/tests/t_*.gd` exit 0: t_ai, t_build, t_canim, t_combat, t_harbour (`islands=15`),
  t_iconart, t_items, t_light, t_lighting (prints `[t_light] PASS`), t_occlude, t_player,
  t_ragdoll, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_web: all PASS.
- t_ragdoll rerun on the final profiles: `[t_ragdoll] PASS`.
- No Godot crash report during this work (newest `Godot-*.ips` is from 13:15, before it).
