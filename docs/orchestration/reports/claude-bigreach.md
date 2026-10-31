# BIGREACH: melee connects against big creatures

Branch `claude/mmo-bigreach` (from `origin/claude/mmo-overhaul`). Not merged to canon. No credits spent.

## Owner reports
- "im trying to attack the stegosaurus and it wont let me hit it. Maybe its so big that it pushes me away from the hitbox?"
- "Triceratops has a similar problem to Stegosaurus, it might be a size issue (pathfinding and autocombat on large dinosaurs?)"

## Cause
Three things, measured on the live models (probe of mesh bounds vs capsule, genome sizes as rolled):
1. **Reach was centre to centre.** `Hunt.melee_reach` = max(2.1, 0.12 x L + 0.65) from the creature's origin. A long body
   is far bigger than that: stegosaurus tail 9.0 m and head 4.9 m from its centre, triceratops 5.4-5.7 m,
   T. rex 10 m, utahraptor 6.5 m. Standing against the head, tail or rear legs was never in reach.
2. **Reach ignored body size.** `melee_reach` used 0.12 x L, but the capsule is 0.12 x L x the genome size. A stegosaurus
   at size 1.11 has a 2.40 m capsule; the survivor stops at 2.77 m with reach 2.81 m, and any shove puts her out.
3. **The stegosaurus capsule was wider than the stegosaurus.** Capsule radius 2.40 m vs 1.34 m visible half-width:
   she was held a metre off the flank (the "pushes me away"). Auto-attack also pathed to the creature's centre,
   which sits inside its collider.
Line of sight (`MeleeQuery.clear`) was not the cause: it already skips CharacterBody3D.

## Fix
- `Creature.footprint()`: the visible body's ground rectangle in local XZ, from the model's mesh bounds at the current size (cached per size).
- `MeleeQuery.surface_gap` also measures to that footprint (min with capsule-to-capsule), so tackle, kick and auto-ability reach use the body edge too.
  New `MeleeQuery.footprint_point(c, at)`: the nearest point of the visible body.
- `Hunt.in_reach(t, slack)`: old centre rule OR survivor edge within `player_melee.edge_reach_m` (0.5 m, new in combat_tuning.json) of the footprint.
  Used by auto-attack, `swing_now` and the hit check at contact.
- `Hunt.aim_point(t)`: auto-attack walks there (not to the centre). The swing faces it and the hit arc is judged against it, so the hit lands on the flank, legs, head or tail she faces.
  `PlayerSim.face_tick` faces it too.
- `melee_reach` now uses `body_radius()` (carries the genome size).
- `_size_collision`: the capsule radius is clamped to the visible half-width + 0.1 m (stegosaurus 2.40 -> 1.44; also narrows gallimimus, coelophysis, styracosaurus, utahraptor).
  # ASSUMPTION: `body_radius()` is unchanged, because AI spacing, pack slots and wake distance read it. Only the physical collider and melee reads shrink.

## Gates
- `game/tests/t_bigreach.gd` PASS (two runs):
  - All 15 modelled species: the survivor touches the side, rear and front, and the swing lands. At 1 m past reach the swing is refused.
  - Triceratops and stegosaurus, auto-attack with auto-ability off: she approaches from 10 m (side, front, rear) and lands 2 swings in about 2.6 s.
  - The same species with their AI on (aggressive, fighting back): she lands 2 swings in 2.3-3.3 s.
- t_combat, t_tactical, t_kicktackle, t_movepriority and t_godlab all PASS.
- run_all.gd `[tests] PASS`. `tools/smoke.sh --no-import` SMOKE PASS.
- Also PASS: t_ai, t_alphas, t_chasesprint, t_mounts, t_pen_claim, t_petfollow, t_raptorfeel, t_stegofix, t_tribe, t_tribework, t_trikeland.

## Notes for the next agent
- The footprint is a rectangle, so near a thin tail tip it is up to half a body-width generous. Tighten it per bone if that matters.
- The skinned mesh AABB is in bind pose. Animation does not move the footprint.
- The creature brains still use `body_radius()` for their own contact reach. For the clamped species they bite from up to about 1 m beyond the new collider. That was not changed.
- Tribe members (`tribe_member.gd`) still use the centre-based `Hunt.melee_reach`.
