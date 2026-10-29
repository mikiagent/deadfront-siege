# ZEBRA2: slow gallop, ram charge, livestock model redo (claude, 2026-10-29)

Owner feedback: "way too fast, it should gallop away slowly", "doesn't look like a bulky, docile animal ...
tamable like a cow or horse", "the AI should be the zebraceratops fleeing or charging at the player", "tackling/ramming".

## Part A: speed (commit 1)
- `pack_mule` flee_speed_mult 1.2, flee_min_mps 0 (the lead's commit): about 4.5 m/s with run_speed_mult, under the
  5.5 m/s survivor walk.
- `t_ai`: the skittish merge and the 6.5 m/s flee floor are now tested on **gallimimus** (runner, skittish, no override),
  through flee_speed() and one real physics step. New checks: zebraceratops gets pack_mule's 1.2 over skittish's 1.6;
  best-IV zebraceratops flees under 5.5 m/s; its flee plays the run clip at cadence 0.8 to 1.3 (it is x1.1 now).
- `t_zebra` kick: passed 3 of 3 runs at this head without changes (deterministic seed, kick lands once, 37.7 dmg).
  The earlier failure did not reproduce after merging canon; nothing changed in the kick geometry.
- Gallop cadence: v2 run clip natural speed 4.1 m/s (was 4.0), so the 4.5 m/s flee is not a sped-up run.

## Part B: the charge is a ram (commit 1)
- `PlayerSim.shove(push, stagger_s)`: the survivor slides along the push, decaying to 0 over the stagger, no control;
  walls stop it (move_and_slide); a roll in flight is not shoved.
- `TacticalBrain._charge_impact`: a landed charge (damage unchanged, charge_mult 1.8) calls the shove along the charge
  line. Data in `ai.json` pack_mule tactics: `charge_shove_m` 2.5, `charge_shove_stagger_s` 0.6 (ASSUMPTION, marked).
  Default 0, so no other archetype changes (only pack_mule has charge_straight).
- Charge clip: head drop 42 deg (was 28), deeper crouch: head and shoulders low.
- `t_zebra` case 8: a real (unfrozen) survivor is shoved 3.46 m along the line (wants >= 1.5).

## Part C: model v2 (commit 2)
- Concept: Codex image generation (free plan, 4 images): a side view from the v02 sheet's colours with the new build,
  then front, back and right from that side view. `docs/orchestration/reports/zebra2/views.png`.
- Mesh: Tripo P1 multiview, task `0137446b-db46-451b-91eb-8afaa5a8bff8`. **Credits: 50 Tripo** (balance 2855 -> 2805),
  one generation, no retry. No Meshy, no paid images.
- Rig: `tools/transplant_rig.py` (Quaternius Triceratops donor, same skeleton as v1), output in
  `game/assets/creatures/zebraceratops/`; source mesh at `work/zebraceratops_i2m_v2.glb` (local only: `game/assets/**/work/` is gitignored; Tripo task id above re-downloads it).
- Clips (all 16 names kept): transplant alert, attack_primary, attack_heavy, death, hit_react, idle, knockdown;
  `make_gait.py` walk (trot 0.83 s, stride 0.45) and run (heavy rotary gallop 0.625 s, stride 0.9, duty 0.3, bigger
  body bob); strafes via `--as`; walk_back reversed; charge/kick via `make_charge_kick.py`. feed and sleep are the v1
  clips on the same skeleton (render-checked on v2, not re-authored).
- Saddle rebuilt (`tools/blender/saddles/build.sh zebraceratops`), mount.json rider transform recomputed.
- Speeds rebaked (`tools/bake_clip_speeds.py`): walk 1.54, run 4.11 m/s.
- Size: height_meters 1.8 unchanged; the cow-like body has a short tail, so the overall length is shorter than v1.
- PNGs: `docs/orchestration/reports/zebra2/before_{side,front}_{idle,run}.png`, `after_*.png`, `compare.png`
  (top row v1, bottom v2).

- sleep.glb (v1) keyed the old `Jaw` bone; RiggedModel drops any clip with a missing track, so sleep fell back to
  idle (t_canim). The three Jaw channels were stripped from sleep.glb.
- Ragdoll (`ragdoll.json` zebraceratops): Body/Shoulders capsule radii 0.259/0.306 -> 0.42/0.40 for the barrel,
  and a new optional profile key `lie_frac` (read by `Ragdoll.lie_limit`, default LIE_FRAC 0.5) set to 0.65: the
  barrel holds its hips at ~60 % of standing height on its side (t_ragdoll: 0.37 of 0.61 m, limit now 0.40).
  `RagdollSkin.trunk_half_width` measures in unscaled skeleton units (0.08 for a ~0.5 m half-width barrel), which is
  why the width term never helped; not changed here, worth a look.

## Assumptions / for the next agent
- ASSUMPTION: **no Jaw bone on v2.** The closed-beak mesh tore at the cheek with the fitted mouth line and showed
  almost no gape with `--lip-z 0.405`; a grazer that rams does not need a bite gape. `tools/jaw/verify_jaws.sh
  zebraceratops` would now fail (it is not in all_tests).
- `tools/bake_clip_speeds.py` drops deinonychus' hand-set `natural_speeds.deinonychus.charge` (6.6) on every bake;
  I restored it by hand. Worth fixing in the bake (keep keys it does not measure).
- The tail on the v2 mesh rests slightly raised; the hind leg stretches a little at full gallop extension.
- Old v1 texture files (task 99e1106a) removed; the new extracted textures (0137446b) are committed with imports.
