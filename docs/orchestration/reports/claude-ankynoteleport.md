# ANKYNOTELEPORT: no 4 m body jump after an ankylosaurus or stegosaurus turn

Branch `claude/mmo-ankynoteleport`, from canon 03592b15f, merged up to c324c21fc (all gates rerun after it). No credits spent.

## Cause
t_noteleport failed on the ankylosaurus with "worst frame step 3.88 m at approach/pivot_left": the frame a pivot ended.

`ClubTailBrain` turn moves (pivot, spin, about-face) used to work like this:
- During the clip, only the view (`creature.view.transform`) turned about the pivot foot. The body stayed where it was.
- At the end (`_turn_commit`), the body moved round the whole arc in one frame and the view snapped back to rest.

On screen nothing jumped. But the body (the collider, the nav agent, anything that reads `global_position`) teleported
the full arc. For a 90 deg pivot about a front foot about 2.7 m away, that is about 3.9 m. For a 200 deg spin it is
more. The stegosaurus case passed only because no turn happened inside the test window.

## Fix
`_set_turn` now moves the body itself round the arc each pose: `_body_base` turned about the world pivot. Physics
interpolation is off on the body for the turn, so the body and the pose move together. `_turn_commit` now only ends the
turn. The view is no longer touched.

## Results
- t_noteleport (ankylosaurus, stegosaurus): ankylosaurus worst frame step 0.17 m (the tackle leap), stegosaurus 0.09 m.
  Limit 1.0 m.
- t_stegospin: planted toes in turns, worst 0.049-0.099 m (limit 0.15).

## Gates
- t_noteleport ankylosaurus case: PASS.
- Full t_noteleport: PASS on the first run. On the second run it failed on two other species:
  - coelophysis: the kick missed (0.00 m), the known random small-species kick miss;
  - raptor: worst frame step 1.08 m against a 1.00 m limit, in `flank/charge_turn`. That is TacticalBrain's
    charge_turn arc step (`_arc_step`), not ClubTailBrain.

  I did not chase these. The raptor one needs `_arc_step` to cap a frame's step. The kick misses need the small-species
  kick reach from the hitboxes work.
- t_stegospin, t_ankyloclose, t_ankyloopen, t_hitboxes, t_knockdown, t_plantedflinch, t_combat, t_bigstomp: PASS.
- run_all: [tests] PASS. `tools/smoke.sh --no-import`: SMOKE PASS.
