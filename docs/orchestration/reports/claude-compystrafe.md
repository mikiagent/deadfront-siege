# Report: COMPYSTRAFE (compsognathus remodel, jaw, strafes, nervous idle), Claude

Branch `claude/mmo-compystrafe`, cut from `origin/claude/mmo-overhaul` (0fea2471). Not pushed, not merged.
It started as "strafe_left/right on the compy", and Milan widened it during the run: give it a mouth that opens and
closes, then rebuild it from his new green turnaround sheet, then give it an exaggerated curious, jumpy idle.

## What shipped
- **New model** from Milan's sheet (`ref/compsognathus_sheet_v2.png`). The FRONT and SIDE panels were cropped,
  with the human silhouette painted out (`ref/compsognathus_front_v2.png`, `ref/compsognathus_left_v2.png`).
  Then one Tripo multiview-to-model run (P1-20260311, texture + PBR, face_limit 15000, task
  e9f3b219-7fdb-4812-b2ab-b27b830a84f4). **50 credits** (balance 2955 -> 2905). The mirrored right view and the
  TOP/REAR 3/4 panels were left out on purpose: the side pose is mid-stride, so a mirrored right view would
  contradict which leg is forward, and the other two panels are not orthographic. Tripo still produced clean,
  symmetric, standing legs. The raw mesh is in `work/compsognathus_tripo_v2.glb`.
- **Rig**: `tools/transplant_rig.py`, the same route and Velociraptor donor as v1, so the bone names and the clip
  contract are unchanged. The mesh is 0.502 m tall and 0.998 m long. `pipeline.source_height_m` is updated, and
  the in-game size stays `height_meters` 1.2 (ASSUMPTION: the human silhouette on the sheet is not used for scale).
- **Jaw (open/close)**: `tools/jaw/add_jaw.py --open --part 8`. New `--open` mode: the mesh was modelled with
  the mouth open, so the mouth line is fitted through the gape (the widest empty band per slice). Teeth and small
  islands in the snout are made rigid to whichever jaw holds them. The mouth is then closed in the bind pose,
  29.7 deg of the 33.7 deg gape, leaving it slightly parted so the lips never fuse. The bite, heavy bite, roar
  and feed open the jaw, and the idle sniff opens it a little.
- **Clips**: `tools/gait/transfer_clips.py` (new) carries the v1 clips (attack_primary, attack_heavy, alert, feed,
  hit_react, knockdown, death, sleep, walk, run, walk_back) over to the new rig:
  - turns are replayed in armature space, so differences in bone roll do not matter;
  - translations are scaled by the leg ratio (0.62);
  - legs are IK-solved onto the root-parented feet every frame;
  - a floor pass lifts the Body wherever the skin would sink.

  Clip names and lengths are unchanged, so anim_events hit timings still apply.
- **strafe_left / strafe_right**: rebuilt for the new rig with `make_gait.py` and the new
  `tools/gait/compsognathus.json` (strafe: 0.625 s loop, stride 0.15, roll/sway into the step, tail and head
  wiggle). Planted feet slide against the travel direction (strafe_left feet move -X while the animal moves +X =
  its left), so there is no moonwalk, and the loop is seamless. Natural speed is
  `natural_speeds.compsognathus.strafe_left/right` = 0.574 m/s at 1.2 m (`_len` 0.625).
- **Idle, nervous and curious**: `tools/gait/make_nervous_idle.py` (new), 3.5 s loop. It has:
  - bird-like darting glances, held between snaps, with head tilts of 24-30 deg;
  - a neck crane forward and down to sniff, with snout bobs and a working jaw;
  - a startled rear-up with a small hop (both feet leave the ground and land on their own prints);
  - weight shifting foot to foot, and tail flicks.

  Feet are planted (0 drift) apart from the hop, and the last frame equals the first.
- **AI (clip selection only)**: `CreatureAnim.pick_direction/set_move_velocity` take a side threshold.
  `creature.gd` passes `FACING_SIDE_DOT` (0.5) while the brain's `strafe_face` holds the body facing the prey;
  otherwise it stays 0.7. Without this, surround slots reached on a diagonal glided on the forward walk. The
  share of circling frames that play the strafe on the correct side went from 0.83 to 0.87 (1144 frames).
  `t_swarm` now asserts >= 0.8, and `t_tactical` asserts the 50-deg diagonal case. Brain logic and ai.json are
  untouched (zebraai is editing those).
- **Data**: in `compsognathus.json`, pipeline v2 with a `remodel_2026_10_28` block, `look` text from Milan's
  description, and eye glow points re-measured from the red eye texels in Head-bone space (radius 0.02).
  `anim_events.json` has rebaked compy walk/run speeds (0.312 / 2.367) plus the strafe speeds. The bake had
  dropped deinonychus `charge` 6.6, and I put it back by hand. Docs: `docs/current/enemy-ai-template.md`
  (locomotion threshold).

## A/B for Milan (`docs/orchestration/reports/compystrafe/`)
- `ab_model.png`: four views (left side, front, top, three-quarter). v1 is on the left and the new model on the
  right.
- `ab_mouth.png`: head side and front, mouth closed (alert f0) and open (alert f20). v1 is the top row and the
  new model the bottom row.
- `ab_idle.png`, `ab_strafe_left.png`, `ab_strafe_right.png`, `ab_attack_primary.png`: for each, v1 front + side
  rows on top and the new front + side rows below, 8 frames each.
- `new_bite_jaw.png`: the bite on the new model (rest, wind-up gape, snap shut, recoil).
- `ingame_lab.png`: the new compy in the creature lab (Godot, textured).
- `tripo_input_views.png`, `tripo_preview.png`: what went into Tripo and what came back.

## Gates
- `t_swarm` PASS (circling strafe share 0.87), `t_canim` PASS, `t_tactical` PASS.
- `python3 tools/audit_gaits.py --gate` GATE PASS: compy walk drift L 0.000 / R -0.034, run L +0.018 / R -0.248,
  all under the +0.05 moonwalk line.
- `tools/audit_creature_deformation.py` (v1 -> new):
  - max edge ratio is lower on most clips;
  - p99 edge ratio is about 2-2.8 on the jaw clips, from the mouth-corner stretch when it opens;
  - lying clips sink 1.1-2.2 cm (death, knockdown, sleep), about 2-4 % of body height; v1 sank 0.4 cm.
- The jaw is in the rig and keyed in attack_primary, attack_heavy, alert, feed and idle.
- See the end of this file for all_tests, smoke and rig imports.

## Known issues / for the next agent
- **Thin white slivers at the mouth corners** when the jaw is wide open, and faintly in a close front view when
  shut. They come from scale islands in the corner ramp. A proper fix is open_mouth.py-style corner lining or
  welding those islands. They are small at gameplay distance.
- The `repair` and `warp` numbers in `compsognathus.json` and `work/rig_manifest.json` still describe v1.
- The skill's external verifiers (`~/Documents/DeepseekCLI/verifiers`, limb_check, creature-verify) are not on
  this machine. I checked with the repo's audits, world-space drift measurements and render strips instead.
- The clip-viewer recording (mp4) was not made. The PNG strips and the lab frame stand in for it.
- The old v1 Meshy mesh (`work/compsognathus_i2m_v1.glb`) and the v1 refs are kept for reference.

Credits: Tripo 50 (one generation, no retry). Meshy 0. Higgsfield 0.
