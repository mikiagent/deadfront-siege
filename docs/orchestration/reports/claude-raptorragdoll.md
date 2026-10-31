# RAPTORRAGDOLL: velociraptor ragdoll profile fitted to its 1.06 m size

Branch `claude/mmo-raptorragdoll`, cut from `origin/claude/mmo-overhaul` (eb564e56). Not merged. No credits spent.

## Problem
RAPTORSCALE shrank the velociraptor from 2.4 m to 1.06 m tall. Its ragdoll capsules in `game/data/creatures/ragdoll.json` are in world metres and were still sized for 2.4 m, about 2.3x too fat. The body therefore lay propped on its capsules, with hips 0.33 m against a 0.29 m limit, and a front blow only moved it 0.24 m, against the 0.30 m the test requires.

## Change
- In the velociraptor profile, every body's `radius`, the Neck `length` and the Tail5 `extend` are multiplied by 1.06 / 2.4 = 0.442. Joints, damping, mass (60 kg), the impulse settings and the global lying rules are unchanged. The lying limit is not set per species: it comes from the standing height and the trunk width.
- `t_ragdoll` `_test_placeholder_body` spawned the stegosaurus as its model-less placeholder. The canon stegosaurus now has a model, so that check failed on canon. It now spawns the allosaurus, which has no model.

## Result (t_ragdoll)
- Lying: velociraptor hips 0.26 m, limit 0.29 m (stands 0.57 m).
- Front blow: the body's centre moves 0.36 m away from the blow, and the hips 0.41 m. The test needs at least 0.30 m, so the margin is small.
- Back blow: centre 0.45 to 0.53 m. Flank blows: centre 0.62 to 0.82 m, with the body rolled onto its far side.

## Gates
t_ragdoll, t_raptorfeel and t_combat PASS; run_all.gd [tests] PASS; `tools/smoke.sh --no-import` SMOKE PASS.
