# Locomotion lessons (walk/run clips)

Running log for the "every creature's legs alternate properly" thread. Update it after every attempt.
Newest lessons go at the end of their section; per-species results are in the table.

## How the clips are made now

`tools/gait/` (Blender headless, no Godot slot needed):

- `make_gait.py <base.glb> <species>.json <clip> <out.glb> [--frames-dir D] [--textured] [--set k=v ...]`
  plans every foot's path from a footfall table (phase per leg, duty factor, stride per cycle), solves the
  legs with analytic two-bone IK, lowers each end of the body only as far as the legs need to reach,
  keys every frame and exports skeleton-only with the skin (same options as the game's clips).
- `<species>.json` holds the leg chains, pole directions and per-clip gait numbers.
- `render_clip.py` renders an existing clip with the same camera, so old and new compare 1:1.
  The striped ground scrolls at the clip's planted-foot speed: a stuck foot means the stride matches.
- `fix_weights.py` repairs auto-rig skin weights in place (only JOINTS_0/WEIGHTS_0 bytes change).
- `measure_skin.py` (from deadfront-reanim, plus `--where N`) counts stretched edges and names them.

## Lessons

1. The shuffle was not a timing problem. The megaloceros clips in the game plant at 0.10 m/s (walk) and
   0.36 m/s (run) in mesh units: the hooves barely move, so the game had to time-scale them x7-16.
   A planned stride (walk 1.3 m per 1.17 s cycle, gallop 3.0 m per 0.58 s) is 11-14x longer.
2. Plan feet, not joint angles. Hand-keyed rotations (DeepSeek's clips) gave an inchworm or a
   shuffle; feet driven from a footfall table cannot get the order wrong. Phase convention in the json:
   a leg touches down at cycle time `-phase mod 1`. Walk = lateral sequence LH 0, LF .25, RH .5, RF .75
   (phases 0, .75, .5, .25); deer gallop = LH 0, RH .1, LF .4, RF .5 (phases 0, .9, .6, .5).
3. This Meshy quadruped rig has `*Foot` bones parented to `root`, not to the shin: they are hoof
   controllers. The shin ends exactly at the foot head, so IK the shin to the foot head and pose the foot
   bone yourself. Forward is -Y in Blender.
4. Toe-down pitch must rotate about +X here (SIDE is -X). The first try had it backwards: heel-off pushed
   the ankle under the floor and the hooves spiked.
5. Pole directions: megaloceros front and hind both bend with the joint forward (pole -Y) on this rig,
   matching the rest pose; flipping the hind pole to +Y twisted the whole rump.
6. Long strides expose bad auto-weights that short clips hide. Megaloceros had tail bones on the left
   hind hoof and groin, and shin bones on the mid-belly and chest. `fix_weights.py`:
   strip Tail below 0.8 m, strip shin weights above their own knee + 4 cm and hoof weights above the
   hoof + 15 cm; a vertex stripped bare borrows its neighbours' weights (an empty vertex silently falls
   to joint 0 = root and tears 60-115x). Match glTF vertices by nearest Blender vertex, not by rounded
   position (305 seam twins missed and tore). Result: every existing clip deforms the same or better.
   What did NOT help: distance-to-bone radius stripping and neighbour smoothing (both made more
   stretched edges), and Blender bone-heat re-skinning (weights land on `root`, 60x tears).
7. The stretched-edge count is a weak judge for big motions (0.5 cm edges at weight jumps); with the
   texture on, the new walk's 970 stretched edges are not visible. Look at textured frames.
8. In the game today `creature.gd` calls `play_locomotion()`, which plays walk/run at the fixed clip
   speed; stride matching (`set_move_speed`) is only used by the anim lab. With the new clips at cadence 1
   the megaloceros covers 1.3 m/s walking and 6.0 m/s galloping (game scale x1.16), close to its 7.6 run.
   Natural speeds in anim_events.json must be rebaked (`tools/bake_clip_speeds.py`, needs Godot).

## Per species

| species | walk | run | base weights | review | status |
|---|---|---|---|---|---|
| megaloceros | LS walk, 28 f, stride 1.3, duty .65 | transverse gallop, 14 f, stride 3.0, duty .3 | fixed | blind A/B: new won walk (65 %) and run (90 %); fixed its notes (prance fold, nose-dive pitch) | in branch, needs in-game look + speed rebake |

9. Blind review notes on the first megaloceros pass: the lifted foreleg folded like a prance (swing curl
   70 deg -> 35) and the gallop nose-dived (body pitch from the two ends' heights x0.5 -> x0.3, rocking
   0.05 -> 0.01 m). Keep hoof curl modest in a walk; a gallop can fold more.
10. Godot slots were full the whole first session (gameplay tests), so in-game checks and the natural
    speed rebake are left for the integrator. Blender textured strips + scrolling-ground MP4s are the
    review material (`docs/orchestration/mmo/locomotion/<species>/`).
