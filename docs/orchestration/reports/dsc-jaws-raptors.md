# dsc-jaws-raptors: jaws for coelophysis, compsognathus, gallimimus, utahraptor

Four Meshy auto-rig species got a working jaw with `tools/jaw/` (add_jaw -> open_mouth -> key_jaw -> copy in ->
render_head check -> saddle rebuild). Nothing in `tools/`, `game/scripts` or `game/scenes` was touched. Credits
spent: 0 (no Meshy/Tripo calls).

Gate: `tools/jaw/verify_jaws.sh coelophysis compsognathus gallimimus utahraptor` -> `JAWS PASS`
(Jaw node in each rig, Jaw channel in `anim/attack_primary.glb` and `anim/alert.glb`, `RIG IMPORT PASS` from
`tools/verify_rig_imports.gd`, `SMOKE PASS`).

## coelophysis — shipped
Mouth line from the painted seam (23 slices, corner t 0.100), 735 jaw verts; lips ripped (87 tape faces), gum-red bag
15 slices / 58 faces, lining 174 faces. Clips keyed at 24 fps: attack_primary 1-21 peak 30 deg, attack_heavy 30,
alert 1-40 peak 40, feed 18, idle 2. Saddle rebuilt.
Render: `/tmp/jaw_coelophysis/roar_f024_threeq.png` — open mouth, red inside, snout attached.

## compsognathus — shipped
Mouth line from the painted seam (22 slices, corner t 0.092), 653 jaw verts; 81 tape faces ripped, bag 17 slices /
66 faces. Same clip keys. Not listed in `tools/blender/saddles/saddles.json`, so no saddle rebuild.
Render: `/tmp/jaw_compsognathus/roar_f024_threeq.png` — open mouth, red inside, snout attached.

## gallimimus — shipped after a retuned mouth line
The default run failed the render check: this species' base-colour atlas has no painted mouth seam (tan/white
camouflage), so add_jaw's "darkest band per slice" fit ran diagonally through the snout and the alert render showed
the snout torn off. Restored with `git checkout -- game/assets/creatures/gallimimus/`, then re-ran add_jaw with
`--min-head 0.95 --slices 12`: near-flat lip line at z~0.92, pivot (-0.0, -0.725, 0.926), 1144 jaw verts. open_mouth:
136 tape faces ripped, bag 16 slices / 62 faces, lining 272 faces. Same clip keys. Saddle rebuilt.
Renders: `/tmp/jaw_gallimimus/C24_f024_side.png`, `C24_f024_threeq.png` (roar, red inside, snout attached),
`C5_f005_side.png` (shut, clean), `Cbite_f009_side.png` (bite). Failed attempts on record:
`roar_f024_threeq.png`, `jawonly_f000_side.png`, `chk0_f000_side.png`.
Note for whoever tunes this next: gallimimus needs those two flags; the default is wrong for it.

## utahraptor — shipped
Mouth line from the painted seam (17 slices, corner t 0.088), 502 jaw verts; 2 rigid teeth islands, 49 tape faces
ripped, bag 15 slices / 58 faces. Same clip keys. Saddle rebuilt.
Render: `/tmp/jaw_utahraptor/roar_f024_threeq.png` — open mouth, red inside, snout attached.

## What was restored
Only gallimimus, once, after the torn-snout render; the retuned run replaced it and is in the game.

## Remaining / not done
- Walk/run clips, eyes and new species are out of scope and unchanged.
- `tools/jaw/verify_jaws.sh` calls Godot without the `HOME` fallback that `tools/smoke.sh` uses; in a sandbox that
  cannot write `$HOME/Library/Application Support`, Godot segfaults and the gate reports `rig imports FAIL`. It passes
  when run with `HOME=$TMPDIR/deadfront-smoke-home`.
