# DSC EYEGLOW: glowing eyes on the six predators

Task: `docs/orchestration/dsc/eyeglow-TASK.md`, spec `docs/design/durango-prompts/27_2d_asset_sheets_glowing_eyes.md`
("Glowing eyes"). Eyes are painted into the Tripo textures, so this is a small additive effect on the head.

## What shipped

| File | Change |
|---|---|
| `game/data/creatures/{tyrannosaurus,utahraptor,deinonychus,velociraptor,coelophysis,compsognathus}.json` | `"eyes"` block: `bone`, `points` (2, Head-bone local), `radius`, `color`. No other species has one. |
| `game/scripts/creatures/creature_eyes.gd` (new, `class_name CreatureEyes`) | BoneAttachment3D on the head bone, two emissive spheres, one shared material per colour, brightness scaled by `WorldLighting.night`, hidden when dead or asleep. |
| `game/scripts/creatures/creature_view.gd` | `static eyes_block(id)` reads the species JSON (cached; `CreatureDef` stays untouched) and `_add_eyes()` after `rig.fill_missing(...)` builds the node; a species without an `eyes` block gets nothing. |
| `game/scripts/world/world_lighting.gd` | `static var night: float = 0.0`, written in `drive()` from the existing local on every call. Nothing else changed. |
| `game/tests/t_eyeglow.gd` (new) | Headless acceptance: attachment on Head, two dots, night >= 5x day, 1 mm drift over 2 s of walk, dead hides, no eyes on zebraceratops. |
| `game/scripts/dev/eyeglow_lab.gd` + `game/scenes/dev/eyeglow_lab.tscn` (new) | Windowed lab: side close-ups at midnight and noon, game-camera frame, peak/head luminance numbers, PASS/FAIL. Also `--probe`, `--aim=<px>,<py> [--ray]`, `--move=<dx>,<dy>`, `--species=`, `--day=<fraction>` developer modes used to place the dots. |

## Numbers (verify stage 2, `1600x900`, gl_compatibility, midnight / noon)

```
[eyeglow] tyrannosaurus night_peak=0.95 day_peak=0.46 night_head=0.00 eye_px=50.3
[eyeglow] utahraptor   night_peak=0.99 day_peak=0.24 night_head=0.01 eye_px=21.8
[eyeglow] deinonychus  night_peak=0.98 day_peak=0.37 night_head=0.00 eye_px=22.3
[eyeglow] velociraptor night_peak=0.99 day_peak=0.36 night_head=0.02 eye_px=13.3
[eyeglow] coelophysis  night_peak=0.92 day_peak=0.37 night_head=0.13 eye_px=8.8
[eyeglow] compsognathus night_peak=0.90 day_peak=0.43 night_head=0.12 eye_px=5.2
[eyeglow] none zebraceratops eyes=0
[eyeglow] PASS
```

Gate: every species `night_peak >= 0.6`, `night_peak >= night_head + 0.3`, `day_peak <= 0.6 * night_peak`.
`eye_px` is the two dots' separation on the game camera; the dot itself is 5-50 px across by species.

## What I looked at

Every species was checked on a marked close-up (`<id>_day_side.png` with a magenta cross at each dot and a
50 px grid): velociraptor, utahraptor, deinonychus, tyrannosaurus, coelophysis, compsognathus - the cross sits on
the painted eye in all six. The Tyrannosaurus paint barely draws an eye; the dot sits in the socket brow.
Night frames at the game camera show one crisp dot on the near eye (the far one is correctly hidden by the skull);
the day frames show a dim dot, visible but subdued.

## Colours and radii (ASSUMPTION: the PRDs are silent)

Colours are the ones the task fixed (tyrannosaurus amber, utahraptor/velociraptor yellow-green, deinonychus green,
coelophysis orange-red, compsognathus red). Radii, in model units (the attachment inherits the mesh scale):

| species | radius | on the game camera | why |
|---|---|---|---|
| tyrannosaurus | 0.065 | 50 px apart, dot ~6 px on the game camera | the skull is 8 m tall, so a real eye would be ~4 cm and invisible |
| utahraptor | 0.011 | 22 px apart | real eye ~0.5 cm at 5x scale |
| deinonychus | 0.02 | 22 px apart | same rig family, bigger head |
| velociraptor | 0.012 | 13 px apart | measured from the side shot |
| coelophysis | 0.014 | 9 px apart | the smallest head in the set |
| compsognathus | 0.03 | 5 px apart | tiny body, dot sized to stay a dot after scale; at 0.017 the dot no longer fills its 5x5 window and the numbers gate failed (day_peak 0.62 > 0.54) |

The dot is a sphere of that radius (a billboard quad half-buried in the skull read as a crescent from the side).

## Assumptions

1. Species and colours: as the task lists; the PRD only says "predators and nocturnal species first".
2. Eyes are off while the creature is dead or asleep (`CreatureEyes.is_awake`).
3. Day brightness is a faint glint: 3 % of the night level (`day_fraction`). The literal "a tenth" put the day
   peak above the gate's 0.6 x night limit because AGX lifts small emissive dots a lot.
4. Colour is drawn as emission on a black per-pixel material, not `UNSHADED`: unshaded ignores emission, and
   scaling the albedo by 4 clipped every species to white on gl_compatibility.
5. Eye push off the skin is 3 cm along the model's X (the head's side), not along the line from the bone
   origin, which runs through the cheek on a big skull.

## What the integrator needs

- Nothing to wire: `CreatureView.setup` builds it from the data. Any future species only needs an `eyes` block.
- `WorldLighting.night` is public and updated every `drive()` call; other night-reactive effects can read it.
- The lab is the way to place a new species: `--lab=eyeglow_lab --species=<id> --aim=<px>,<py> --ray`, then
  check `<id>_day_side.png` (crosses) and adjust with `--move=<dx>,<dy>`.
- Verify: `bash <scratchpad>/dsc/verify_eyeglow.sh [1|2]`, full gate = no argument.

## Verification run (fix round, 2026-10-22)

- `verify_eyeglow.sh 1` (t_eyeglow): PASS, 20 s.
- Windowed lab batch, 1600x900 gl_compatibility: PASS, 29.6 s end to end (alarm 500 never reached). The
  earlier 300 s gate timeout came from the previous, unfinished lab; this tree freezes the game clock
  (`Game.day_length_seconds`) and re-pins `time_of_day` before every capture, which is what fixed it.
- `verify_eyeglow.sh` (full gate): PASS in 1:29 - scope check, stage 1, stage 2 lab numbers and shots,
  t_lighting, t_mounts, t_canim and `tools/smoke.sh`.
- Uncommitted radius experiments from the earlier run (compsognathus 0.017, deinonychus 0.012) were
  reverted to the committed 0.03 / 0.02: both made the dots too small to clear the 5x5-window gate.
- The full gate's scope check flagged `.dsc-task/TASK.md`, the harness's own task copy that the runner
  commits at task start; it is byte-identical to the in-scope `docs/orchestration/dsc/eyeglow-TASK.md`.
  The gate now excludes `.dsc-task/` and `.dsc.local.json` exactly as `verify_job.sh` and
  `verify_stationart.sh` already do. No product file changed for this.

## Credits / deps

No Meshy credits, no new dependencies, no engine settings changed.
