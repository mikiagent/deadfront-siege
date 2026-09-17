# C2b — transplant hardening and survivor clips (done by the orchestrator; Codex was out of usage)

Date: 2026-09-17. Meshy balance 3,722 → 3,656 (66 credits: survivor presets 18, Protoceratops references 18 + mesh 30).

## Part A — dinosaurs (no credits)

`tools/transplant_rig.py` v2 replaces the proof-of-concept:

| Step | What changed |
|---|---|
| Repair | Loose-island removal capped at 3% of vertices and only islands under 0.2% of the largest (AI meshes are thousands of islands: Utahraptor 4,340). Merge doubles, fill holes with UVs inherited from neighbours, recalc normals. Utahraptor: 132 holes filled, 27,887 → 10,303 verts (seam duplicates merged). |
| Fit | Landmark warp for bipeds: donor snout, feet and tail tip mapped piecewise-linearly onto the mesh's, hip height and hip width scaled. Quadrupeds keep the bbox fit. |
| Weights | Bone-heat directly when it works (Deinonychus, Velociraptor, Protoceratops 100%), voxel-proxy transfer when it fails (Utahraptor). |
| Clips | All nine contract clips: knockdown = death 0–45% held, hit_react = death 0–35% then reversed, alert = idle 0–40% with the head pitched 20°, attack_heavy gets an 8-frame telegraph hold at 30%. |

Results (posed side renders at 50% of each clip in the scratchpad, rest sheets at `game/assets/creatures/<species>/sheet.png`):

| Species | Mesh | Donor rig | Verdict |
|---|---|---|---|
| Utahraptor | Meshy 7 multi-image v2 (redo, two legs) | Quaternius Velociraptor | Good. Walk, attack, jump, death all deform cleanly |
| Deinonychus | Meshy-t2 v1 | Quaternius Velociraptor | Good. Arm feathers hang low (mesh), reads as arms |
| Velociraptor | Meshy-t2 v1 | Quaternius Velociraptor | Usable. Stretched triangles on the flank remain from the mesh; a v2 with side+front references would fix it (48 credits) |
| Protoceratops | Meshy 7 multi-image v1 (new) | Quaternius Triceratops | Good. Frill, beak, four-legged walk and head-down charge |

Godot: smoke passes; the creature lab could not be run at the end because Cursor's M4a work-in-progress has a parse error in the tree (expected mid-task). The previous run before that edit showed all four species at `missing=0` for every clip.

## Part B — survivor (18 credits)

Library presets applied to rig `01a0b198-7d6e-7761-a3e8-242a26cbe7e3`, no text-to-motion needed:

| clip | preset | note |
|---|---|---|
| attack_primary | 240 Thrust Slash | 3.0 s; play from the wind-up, or at 1.5x |
| attack_heavy | 128 Heavy Hammer Swing | 1.9 s two-hand overhead; the wind-up is the telegraph |
| roll | 158 Roll Dodge | 1.9 s |
| gather | 274 Female Crouch Pick Up Place Side | 9.6 s; loop the first ~2 s |
| knockdown | 187 Knock Down | 2.5 s, holds on the ground |
| mount_idle | 32 Chair Sit Idle | 11.4 s seated loop |

Files: `game/assets/characters/survivor/anim/*.glb` (eleven clips). Only `alert` is missing and falls back to idle.

## For the game side
- Bone names: theropods `root, Hips, Torso, Shoulders, Neck, Head, Tail1–5, BackUpLeg/BackLowLeg/BackFoot .L/.R, FrontLeg/FrontUpLeg/FrontLowLeg/FrontFoot .L/.R`; Protoceratops the same family with real front legs. Survivor: Mixamo-style (`Hips, Spine, Spine01, Spine02, neck, Head, LeftArm…`).
- No root motion: clips animate in place; movement comes from the controller.
- `pipeline` blocks in the four species JSONs and `survivor.json` carry task ids, credits, clip provenance, `forward_axis` (+Z) and measured sizes.

## Left open
- Velociraptor v2 mesh (48 credits) if its flank artefacts show in-game.
- Remaining roster (C3): each theropod needs side + front references with arms tucked; quadrupeds use the Triceratops or Trex donor.
