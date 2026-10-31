# ZEBRAWALK: zebraceratops locomotion fix (claude, 2026-10-30)

Owner: "just fix the walking and running animations, strafing, etc." The model, AI, moves, saddle and mount are
unchanged. Locomotion only: walk, run, strafe_left, strafe_right, walk_back (the rig has no turn-in-place clip).
No credits spent.

## What was wrong (measured)
1. **Toes skinned to the body.** The v2 transplant gave the inner toes and inner shin of the front-left and hind-right
   legs (about 700 floor-level vertices, more up the shin) to Shoulders and Tail1/Tail2. When those feet lifted, that
   skin stayed on the ground and stretched into a flat grey sheet under the belly, and the body bob pushed it 11-16 cm
   into the floor. That is the smeared shape in `zebrawalk/before_*_blender.png`, and the vertices shown red in
   `zebrawalk/bad_toe_weights.png`.
2. **Shuffling feet.** The big toes curled down in swing by about as much as the foot lifted (walk lift 3 cm with a 25 degree curl),
   so the soles never cleared the floor by more than 3-4 cm and scuffed through it.
3. **walk_back** was the walk played in reverse; the strafes reused the full 0.45 walk stride sideways.

## What changed
- `tools/gait/fix_foot_weights.py` (new, pure python, only JOINTS_0/WEIGHTS_0 change): below 15 % of the mesh height,
  every body-skinned vertex goes to the legs (its own leg weights, else the nearest leg segment, LowLeg blended into
  Foot near the floor); up to 30 %, only vertices within 0.19 x height of a leg segment, faded so the belly keeps a soft
  seam. Applied once to `zebraceratops.glb` (`--full 0.15 --top 0.30 --radius 0.19`; 2261 vertices).
- `tools/gait/zebraceratops.json`: walk lift 0.05/0.045, swing curl 8/4, toe_roll 10; run lift 0.07/0.06, curl 12/8.
  Cycle, stride, duty and phases unchanged: the walk is still a trot (diagonal pairs), the run a heavy rotary gallop.
- `tools/gait/build_zebraceratops_gaits.sh` (new): rebuilds the 5 clips with `make_gait.py` (strafes and walk_back
  `--as` with stride 0.3), then `ground_clip.py` (lifts frames whose toe-roll dips under the floor, at most 1-3 cm), then
  runs the gate.
- `anim_events.json` natural_speeds, zebraceratops row only (bake_clip_speeds `--dry-run` values spliced in): walk 1.54,
  run 4.107; new strafe_left/strafe_right/walk_back 1.027 (= walk x 0.3/0.45; `check_zebra` measures 1.03).
- `game/data/creatures/zebraceratops.json` pipeline.gaits note; dev lab `zebrawalk_lab` (scene + script) for the sheet.

## Gates
- `tools/gait/check_zebra.py` (new; check_ankylo adapted, plus per-foot moonwalk along the clip's own travel
  direction, sideways skid, 6 cm swing clearance, per-foot speed agreement within 25 %, smooth stance):
  **ZEBRA_CHECK PASS** on all 5 loco clips. Walk: all four feet 1.53-1.54 m/s, trot footfalls (BL+FR, BR+FL);
  strafes and walk_back 1.02-1.03 m/s on every foot; worst stretch 10.3 (was 4.6 with feet torn off; limit 12).
- `--all` on every clip with the new base: alert, attacks, hit_react, idle, kick, feed, death, knockdown pass
  (death/knockdown stretch 8.97, was 8.41). **charge sinks 23 cm** (was 34 cm before) and **sleep sinks 10.5 cm**
  (unchanged): both pre-existing, out of scope (moves).
- `python3 tools/audit_gaits.py --gate`: GATE PASS.
- `t_canim`, `t_mounts`, `t_saddles`, `t_dismount` (12 species), `t_godlab`: PASS.
- `run_all.gd`: [tests] PASS. `tools/smoke.sh --no-import`: SMOKE PASS.

## Pictures
- `zebrawalk/contact_side.png`, `zebrawalk/contact_front.png`: in-game (CreatureView, game lighting), idle/walk/run/
  walk_back/strafe_left/strafe_right at 0/25/50/75 %, from off-screen windowed runs of
  `Godot --path game --position 6000,3000 -- --skip-charcreate --lab=zebrawalk_lab --out=DIR`.
- `zebrawalk/before_walk_blender.png`, `before_run_blender.png` vs `after_walk_run_blender.png` (Blender side strips).

## For the next agent
- `bake_clip_speeds.py` (non dry-run) rewrites the whole natural_speeds table and drops keys it does not measure, so
  a full rebake would delete the strafe/walk_back speeds (same issue the ZEBRA2 report noted for deinonychus).
- `fix_foot_weights.py` must not be rerun on the fixed GLB expecting the same count (it reads the current weights; a
  rerun is a no-op on toes, fine but pointless).
- Hind legs: the v2 mesh's thighs sit behind the transplanted bones, so the back of the hind thigh still creases a
  little at full gallop extension (stretch 10). A re-joint (`rejoint_legs.py`) would be the next step if it shows.
- ASSUMPTION: strafes and walk_back stride 0.3 (a sidestep with the 0.45 walk stride splayed the legs past the body).
