# DILOFRILL: the dilophosaurus keeps its frill out in combat and is 12.5 % smaller

Branch `claude/mmo-dilofrill`, from `origin/claude/mmo-overhaul` (30e08c30). Canon re-fetched before this report: no
new commits, so nothing to merge. Pushed, not merged to canon.
Owner (god-mode fight lab): "dilophosaurus, keep its frills out more often in combat. also make it slightly smaller".

## Credits
None.

## Frill
- **How it worked before.** The frill is 7 rib bones a side (`Frill1-7.L/R`, children of Neck2), not a blend shape. The
  rest pose is folded, and only some clips key the ribs open (alert, spit, attack_heavy, attack_primary, pounce). So it
  folded whenever the dino walked, circled or strafed between strikes.
- **New `scripts/creatures/display_flare.gd` (`DisplayFlare`, a SkeletonModifier3D).** It runs after the
  AnimationPlayer and slerps each rib from the clip's pose toward its open pose. One weight drives it, from combat
  state, whatever clip is playing:
  - brain state roam, flee, sleep, disengage, lurk, downed or dead: the weight eases to 0 and the clips own the ribs.
    That keeps the folded gaits, and the flicks in hit_react and death.
  - any other state (alert, approach, circle, hold, display, hop, spit, pounce...): it is held at 0.8.
  - while spit, attack_primary, attack_heavy, pounce or bite_combo plays, it snaps to 1.0 as the tell.
  - It is rate-capped (0.35 s to open, 0.12 s to snap, 0.6 s to fold) and applied through smoothstep, so it never pops.
- **Data, not per clip.** `pipeline.display_flare {bone_prefix: "Frill", open_clip: "alert", open_at: 0.5}`. The open
  pose is read from the alert clip at mid-hiss. `CreatureView.setup` adds the modifier for any species with the block.
  Only the dilophosaurus has it.

## Size (all marked `# ASSUMPTION`, also Open Questions DL8/DL9)
- `height_meters` 3.6 -> 3.15 and `real_length_m` 12.0 -> 10.5 (`size_note`). The model is now 9.2 m long and 3.15 m
  tall.
- `ai.json` `venom_ranged.attack_range` 3.0 -> 2.6, scaled with the snout (3.3 m ahead at the snap). Without this
  the snap needed a 1.09 m jaw radius to reach.
- `hitboxes.json`:
  - The head crit spot moves from [0.01, 0.26, 0.51] r 0.27 to [0.01, 0.23, 0.45] r 0.24.
  - Re-calibrated with `t_hitboxes --calibrate`: rake Toe.R 2.11 -> 1.87, pounce Head 1.74 -> 1.55.
- **Spit origin.** No change was needed: `launch_spit` fires from the Jaw bone, so the glob still leaves the mouth.
  t_sp_dilophosaurus' spit tests pass.
- `t_sp_dilophosaurus` HITS distances 2.0/1.2/0.8 m x 0.875.
- **Left as is:**
  - `pipeline.hit_parts` radius_m (1.0/1.1/1.4), canon's pre-hitbox stand-in.
  - The tactics ranges (spit 3.5-11 m, pounce 4-8 m).
  - The build note `check_dilophosaurus.py --height 3.6`, a Blender asset gate on the unchanged GLB.

## Gates
- **`t_sp_dilophosaurus`: PASS.** New checks:
  - height_meters 3.15, and the mesh is 3.15 m tall;
  - calm (roaming, out of sight): flare weight 0, frill span 0.91 m;
  - in a 20 s fight against a survivor who stands still (GOD on), the frill is flared (span > folded + 0.7 m,
    ASSUMPTION) on **99 % of combat frames**. The threshold is 70 % (ASSUMPTION);
  - it is fully open (weight 1.0) at every strike's hit frame: spit x3, attack_primary, attack_heavy;
  - the largest weight step in a frame is 0.07, with 0.25 allowed (no pop);
  - when she leaves and it goes back to roam, it folds (weight 0).
  - The span is read on `skeleton_updated`: `get_bone_global_pose` in physics is the clip's pose only, without the
    modifier.
- `t_hitboxes` PASS, `t_critspots` PASS, `t_combat` PASS.
- `t_canim`: **FAILS ON CANON, skipped.** The same 5 failures with this diff's data/view files reverted to 30e08c30:
  carnotaurus, styracosaurus, therizinosaurus, triceratops and utahraptor "_on_damaged starts hit_react (got idle)".
  No dilophosaurus row fails.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## Shots (`docs/orchestration/reports/dilofrill/`)
- They come from the new self-quitting `dilofrill_lab` (`--position 6000,3000 -- --skip-charcreate
  --lab=dilofrill_lab --out=DIR`).
- The setup is a live Creature + TacticalBrain, with the survivor for scale:
  - `calm.png`: the brain is held in roam and the frill is folded along the neck;
  - `combat_hold.png`: circling on the idle clip with the frill open (DisplayFlare; the clip alone would have it
    folded);
  - `combat_strike.png`: the spit under the "SPIT - DODGE!" ring, frill fully open.

## For the next agent
- **Reuse.** DisplayFlare is generic. Any species with display bones and a clip that opens them takes it with one
  `pipeline.display_flare` block (a sail, a dewlap, crest feathers).
- **Disk.** The data volume was at 100 % (1.2 GB free) during this task. A canon-check worktree failed with ENOSPC and
  was removed.
