# Stegosaurus skin-weight repair (dsc, 2026-10-27)

Task: fix the transplanted Stegosaurus weights that made the runtime fall back to
`force_safe_placeholder` in `game/scripts/creatures/creature_view.gd` because the
mesh stretched "worm-like" on animation.

Status: **weights repaired and measured; not yet swapped into the runtime.** The
runtime bypass is still in place by instruction (no `game/scripts/` writes), and
one clip family (walk/run) still exceeds the project's p99 strain target.

## What was wrong

The shipped `game/assets/creatures/stegosaurus/stegosaurus.glb` carries the donor
skeleton (39 bones, revision 3) with weights painted by
`tools/transplant_rig.py`'s "continuous anatomical" quadruped pass. Measured on
the shipped file:

- Leg blends leaked onto the flanks and midline: 7.1% of non-leg body vertices
  carried a leg weight > 0.05.
- Adjacent verts on the hip seam had wildly different weight sets — e.g. vertex
  8558 `Hips 0.95` next to 8576 `Hips 0.56 + BackUpLeg.R 0.26 + BackLowLeg.R 0.17`.
  Under walk/run that pair shears ~5.7x its rest edge length: the worm look.
- Dorsal plates were split across two or three bones each (plate-local edge
  ratio 1.31 in attack_heavy), so the plate row fanned and detached from the body.

## What the repair does

`tools/stego_weight_repair.py` (headless Blender, re-runnable):

1. Loads `stegosaurus.glb`; if it is ever mesh-only it rebuilds mesh + donor rig
   from `work/stegosaurus_i2m_v1.glb`, `work/rig_manifest.json` and the donor FBX.
2. Detects the 162 dorsal-plate / thagomizer-spike components (connected
   islands above the local spine line by 8.5 cm) so they can be handled rigidly.
3. Repaints weights from scratch:
   - spine chain is a partition of unity in arc length along Head..Tail5
     (2 bones per vertex),
   - legs use one limb quadrant at a time, gated below the hip joint and away
     from the midline, blended down the chain (3 bones),
   - a 6-pass 4.5 cm KD-neighbourhood relaxation removes the hip/shoulder seam
     step,
   - each plate/spike island copies the body weights at its own root, so the
     plate and the skin under it move as one.
4. Enforces the pipeline contract: max 4 influences, normalized
   (`weights.method` in `game/data/creatures/stegosaurus.json` unchanged).
5. Exports `work/stegosaurus_repaired.glb` (mesh + skin, no clips, +Z forward,
   same 39-joint donor skeleton, no topology change beyond the existing mesh).
6. Renders 16 lit 1280x720 QA frames (idle, walk, attack_heavy, knockdown ×
   2 times × side/three-quarter) into `work/qa/weight-repair-v1/`, then prints
   BEFORE and AFTER tables.

Nothing under `game/scripts/`, `game/scenes/`, `game/data/` or the clip files was
touched; no credits spent; no mesh regeneration.

## Numbers

`max` / `p99` are the per-edge stretch ratios from
`tools/audit_creature_deformation.py`; `bone p99.5` is the 99.5th percentile
restricted to edges whose two verts share one dominant bone (it isolates seam
shear from genuine plate-to-plate motion); `plate sep` is how far a plate
centroid moves away from the body surface, in metres, beyond its rest gap.

| clip | max before → after | p99 before → after | bone p99.5 before → after | plate sep before → after |
|---|---|---|---|---|
| idle | 1.07 → 1.06 | 1.02 → 1.01 | 1.05 → 1.02 | 0.001 → 0.001 |
| walk | 4.65 → 2.55 | 1.33 → 1.17 | 2.80 → 1.98 | 0.001 → 0.001 |
| run | 5.74 → 3.15 | 1.62 → 1.23 | 3.51 → 2.42 | 0.001 → 0.001 |
| alert | 1.12 → 1.13 | 1.03 → 1.03 | 1.10 → 1.08 | 0.000 → 0.001 |
| attack_primary | 1.69 → 1.54 | 1.15 → 1.10 | 1.48 → 1.26 | 0.009 → 0.013 |
| attack_heavy | 1.98 → 1.83 | 1.22 → 1.15 | 1.68 → 1.38 | 0.012 → 0.015 |
| hit_react | 1.10 → 1.11 | 1.04 → 1.03 | 1.09 → 1.07 | 0.000 → 0.001 |
| knockdown | 2.08 → 1.40 | 1.14 → 1.06 | 1.54 → 1.17 | 0.002 → 0.002 |
| death | 2.08 → 1.40 | 1.14 → 1.06 | 1.54 → 1.17 | 0.002 → 0.002 |

Plate-local edge ratio in the attack clips: 1.31 → 1.00 (heavy), 1.22 → 1.00
(primary) — plates are now rigid. Worst-clip p99 strain 1.62 → 1.23.

Leakage: body vertices carrying leg weight 7.1% → 6.4% overall (measured on all
non-plate non-leg verts; the remaining share is the actual upper-leg/toe skin),
midline 1.0% → 1.8% (the relaxation pass spreads a little into the midline),
plates with leg weight 0.0% → 0.0%, plates spine-only 100%. Max influences 4,
weight sum error 1.7e-07, 23 groups used, all 39 bones exported.

Project gate: `tools/check_rig_audit.py` on the repaired base + the stock clips
prints `RIG QA PASS: 1 creatures, 9 exported clips` (max <= 10, p99 <= 2.1, no
ground penetration, no rest mismatch, no loop seam). Reports:
`work/qa/weight-repair-v1/after_audit.json`, `before_audit.json`.

## Remaining risks (blunt)

- **walk/run are still strained.** Peak edge 2.55/3.15 (target would be near
  1.3-1.5) and single-bone p99.5 1.98/2.42 on the hip/rear-leg seam of the near
  hind leg. Rendering shows no tearing or worm shear at these numbers and the
  silhouette holds, but the hip crease is the weakest area and a fast run cycle
  at 24 fps will still bulge there. Fixing it properly needs either a hip
  "thigh" helper weight falloff tuned per-vertex (a small second stage) or, more
  likely, shorter stride in the run clip itself — that is a clip change, not a
  weight change.
- **Plate row scissoring.** Rigid plates mean neighbouring plates can scissor
  slightly during the thagomizer sweep (attack_heavy plates translate up to
  1.5 cm relative to the body surface at the peak, vs 1.2 cm before). It reads
  as a plate fanning off its base rather than a torn plate; acceptable but not
  invisible.
- **Midline bleed increased** slightly (1.0% → 1.8% of midline verts carry a
  leg weight above 0.05) because of the spatial relaxation. Below the level the
  renders show.
- The repaired file has not been tested inside Godot. Import flags, material
  sampler behaviour and the runtime's `source_height_m` scaling are untested;
  the QA was Blender-only.

## Verdict

Ready for a human to swap in and look at in-engine, **not** ready to declare
done. Concretely, to adopt it:

1. back up `game/assets/creatures/stegosaurus/stegosaurus.glb`, copy
   `work/stegosaurus_repaired.glb` over it (clips unchanged — the bone set and
   rests are identical, `bone_rest_mismatch` after repair is 6.9e-07),
2. remove the `force_safe_placeholder` special case in
   `game/scripts/creatures/creature_view.gd` (Cursor owns that file),
3. run `tools/smoke.sh` and watch walk/run in-game. If the hip crease bulges
   visibly, the next pass should shorten the run stride or add a hip falloff
   stage rather than re-paint everything.

Files: `tools/stego_weight_repair.py`, `game/assets/creatures/stegosaurus/work/stegosaurus_repaired.glb`,
`game/assets/creatures/stegosaurus/work/qa/weight-repair-v1/` (16 PNGs + 2 audits).
Verify: `bash .dsc/verify_stego.sh` (re-measures BEFORE/AFTER, checks renders are
1280x720, runs `tools/check_rig_audit.py` on the repaired base, and parses the
exported GLB for skin attributes, joint count and absence of clips).
