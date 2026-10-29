# Report: NEWSPECIES (styracosaurus remodel, new pachycephalosaurus), Claude

Branch `claude/mmo-newspecies`, cut from `origin/claude/mmo-overhaul` (2ed2339a). Two commits, one per species.
Not pushed, not merged. Owner approval: Milan's two turnaround sheets (2026-10-28).

Credits: **Tripo 100** (2905 -> 2805; one generation per species, no retry). Meshy 0, Higgsfield 0, no paid images.

## Styracosaurus (commit 1)
- Sheet `ref/styracosaurus_sheet.png` (the turnaround one). FRONT and SIDE panels cropped; the human silhouette
  and a stray tail tip from the TOP panel were painted out. Tripo multiview P1, texture + PBR, face 15000,
  task f9d542ba. The mesh came back standing four-square, mouth open, all spikes, rust stripes.
- Rig: `transplant_rig.py` with the Triceratops donor, same bones as the zebraceratops. New `--hip-z/--shoulder-z`
  overrides: the frill spikes read as the shoulder (0.375) and the splayed feet as the hip (0.098).
- Jaw: `add_jaw.py --open` with new flags. `--snout` stops the nose horn tip passing for the snout tip. `--mid` ignores
  frill-spike gaps. `--reach` handles a lower jaw weighted to Neck. `--pivot/--split` replace the straight lip line,
  which cut the hooked beak. `--close` closes the mouth 25 deg in the bind pose, so it stays slightly parted.
  `key_jaw`: bite 22, roar 30, chew 14.
- Clips (17):
  - walk/run (lateral walk, trot), strafe_left/right and walk_back from `make_gait.py` + `tools/gait/styracosaurus.json`;
  - charge and kick from `make_charge_kick.py`;
  - feed and sleep carried over from the zebraceratops with `transfer_clips.py`, which now solves front legs too;
  - alert, attack_primary/heavy, hit_react, knockdown, death and idle from the transplant.
- Saddle: `saddles.json` entry + `build.sh` (medium class). Eye glow: amber, measured from the painted eye.
- `height_meters` 2.25 (ASSUMPTION: about 5.1 m nose to tail, back about 1.5 m). id, stats, archetype unchanged.
- Bug fixed: `make_charge_kick.py` crashed Blender (SIGBUS) in the kick pass on a stale pose-bone pointer.

## Pachycephalosaurus (commit 2)
- Bare sheet `ref/pachycephalosaurus_sheet.png`. FRONT + SIDE cropped, two strays painted out. Tripo task 83150c87.
- Rig: Velociraptor donor. New `--leg hip knee ankle toe` override. The mesh stands in a crouch, so the landmark
  warp had put the hip 0.25 units ahead of the thigh and 0.19 out to the side.
- Jaw: same `add_jaw --open` route (`--snout 0.121 --pivot 0.05 0.31 --split -26 --close 40`).
- Clips (15):
  - walk/run/strafes/walk_back from `make_gait` + `tools/gait/pachycephalosaurus.json`;
  - charge with the head dropped 35 deg (dome first);
  - feed and sleep transferred from the velociraptor;
  - the donor clips with the tail damped to 35 % by the new `tools/gait/stiffen_tail.py`, for the sheet's long stiff tail.
  - No `kick`: a biped has no double hind kick, and the brain only kicks when the clip exists.
- New `game/data/creatures/pachycephalosaurus.json`: archetype `pack_mule` (zebraceratops herd-grazer charge/flee AI;
  pack_mule's ai.json block not edited), tier 16, hp 900, atk 48, def 90, speed 330, bag 40, capture tier I,
  roles bag/mount/combat, height 1.8 m (small saddle). All ASSUMPTION, modelled on the zebraceratops.
- Saddle (small class), seat moved back over the hips (`seat_frac -0.6`). Amber eye points on the skin.

## Shots (`docs/orchestration/reports/newspecies/`)
Per species: `*_model.png` (side, front, top, 3/4), `*_mouth_closed_open.png` (bind pose vs jaw +30 deg; side,
3/4, front), `*_idle_strip.png`, `*_run_strip.png`, `*_charge_strip.png`. Styracosaurus also has
`styracosaurus_ingame_lab.png` and `styracosaurus_ingame_ride.png` (survivor riding, eyes lit).
Pachycephalosaurus also has `pachycephalosaurus_ingame_ride.png`. The wild one walked off-camera in the lab shot.

## Gates (both species in the tree)
- `tools/verify_rig_imports.gd`: RIG IMPORT PASS, 117 clips through the production loader.
- `python3 tools/audit_gaits.py --gate`: GATE PASS. Planted-foot drift, all backward:
  - styracosaurus: walk -0.11, run -0.15;
  - pachycephalosaurus: walk -0.11, run -0.13/-0.16.
- t_canim, t_labspawn, t_dismount (13 species, both new ones mount and dismount cleanly), t_eyeglow, t_mounts,
  t_saddles, t_zebra, t_data: PASS.
- `bash tools/smoke.sh --no-import`: SMOKE PASS.
- all_tests: 130 tests, 128 pass on the full run. The 2 fails were timing/flaky (t_buildspeed 2696 ms vs a 2500 ms
  budget under load, and t_uigather); both PASS when rerun alone, so fail=0. t_save passed in the suite.
- t_ai and run_all counted 19 species; both now expect 20 (the pachycephalosaurus).
- Natural speeds in anim_events.json: the styracosaurus came from the Godot bake (dry run, spliced in alone so other
  hand rows such as the deinonychus charge stay). The pachycephalosaurus speeds are the make_gait ground speed x
  model scale; the same formula matched the styracosaurus bake to 3 decimals. The bake queue was too long on this machine.

## Known issues / for the next agent
- Pachycephalosaurus: the rear haunch skin barely moves in the walk/run; the legs step under it. The Tripo mesh
  crouches with the thigh folded back. A hip further back made the legs too short (body dropped 0.16). Weight work
  (`fix_weights.py`) or a re-sheet in a neutral stance would fix it. Sleep is the velociraptor's curl and reads
  messy at close range.
- Pachycephalosaurus eyes are not mirrored: the Tripo head sits 8 mm off the midline. So it is not in
  `t_eyeglow`'s strict list; styracosaurus is.
- Styracosaurus is `horned_charger`, which has no tactics profile in ai.json. It runs the default herbivore brain
  until someone adds one; its charge/kick/strafe clips are ready for one. Pachy is `pack_mule` and gets the zebra AI.
- No butchering rows and no ragdoll entries for the pachycephalosaurus (Cursor's `butchering.json`; ragdoll is
  optional). Styracosaurus already had a generated butchering default.
- Not spawned on any island (islands.json is Cursor's); both are in the creature lab spawner.
- `tools/jaw/add_jaw.py` and `tools/gait/transfer_clips.py` include compystrafe's unmerged versions plus my flags.
  Take mine when merging `claude/mmo-compystrafe` (a superset).
- The clip-viewer mp4 recordings were not made. The skill's external verifiers are not on this machine.
