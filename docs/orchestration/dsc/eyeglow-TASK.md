# Task: EYEGLOW: glowing eyes on the predators, strongest at night

Context: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival game (project `game/`), web build (gl_compatibility).
Owner: "we want to give some of the dinos glowing eyes (especially in the dark)". Spec:
docs/design/durango-prompts/27_2d_asset_sheets_glowing_eyes.md, section "Glowing eyes" (read it). Eyes are painted into
the Tripo textures, so the glow is a small added effect on the head, not a texture change.

## What to build
- **Species and colours** (ASSUMPTION, the PRDs are silent; list them in the report): tyrannosaurus amber (1.0,0.55,0.1);
  utahraptor and velociraptor yellow-green (0.75,1.0,0.2); deinonychus green (0.3,1.0,0.35); coelophysis orange-red
  (1.0,0.35,0.15); compsognathus red (1.0,0.15,0.1). Every other species has no eyes block and no glow.
- **Data**: an `"eyes"` block in each of those six `game/data/creatures/<id>.json`:
  `{"bone": "Head", "points": [[x,y,z],[x,y,z]], "radius": r, "color": [r,g,b]}`. Points are in the Head bone's local
  space in the model's units (a BoneAttachment3D under the Skeleton3D inherits the model scale). All six models have a
  `Head` bone (measured). Read the creature def where creature_def.gd loads its fields; add `eyes` the same way.
- **`game/scripts/creatures/creature_eyes.gd`** (class_name CreatureEyes): attaches to the Head bone through a
  BoneAttachment3D, draws two small dots (unshaded, emissive, depth-tested so the head hides the far eye; push each dot
  1-2 cm out from the skin so it never z-fights or sinks), one shared material per colour, brightness =
  lerp(day, night, WorldLighting.night) with day about 0.1 of night (a faint glint), off while the creature is dead or
  asleep (ASSUMPTION). Size: readable as two dots at the default game camera at 1600x900 at night; the real eye size is too
  small, so pick a radius per species and say why in the report.
- **Hook**: create it from creature_view.gd where the model and skeleton are set up (a few lines; edit, do not rewrite).
- **Night factor**: in game/scripts/world/world_lighting.gd add `static var night: float = 0.0` and set it in drive() from
  the existing `night` local, on every call (sky or not). Change nothing else in that file.
- **Test `game/tests/t_eyeglow.gd`** (copy game/tests/t_domain.gd's --script pattern: load() scripts on the first frame,
  a 60 s quit watchdog, print `[t_eyeglow] PASS` or FAIL lines): for each of the six, the eyes node exists under a
  BoneAttachment3D on Head with two dots; the material at night 1.0 is at least 5x as bright as at night 0.0; while a
  walk clip plays for 2 s each dot's distance to the head bone stays within 1 mm; a dead creature's eyes are hidden;
  zebraceratops has none.
- **Lab `game/scenes/dev/eyeglow_lab.tscn` + `game/scripts/dev/eyeglow_lab.gd`** (copy how equip_mount_lab.gd and
  lab_kit.gd set up a scene; `--shot-dir=<dir>` argument): for each of the six plus zebraceratops, set the time of day to
  midnight and to noon and drive WorldLighting; save `<id>_night_side.png`, `<id>_day_side.png` (close-up side view of the
  head) and `<id>_night_game.png` (the normal game camera and zoom). In the night_game frame project each eye's world
  position to the screen and take the peak luminance (0-1) of a 5x5 px window around it -> night_peak; the same in the
  noon frame -> day_peak; the mean luminance of the head away from the eyes -> night_head. Print per species
  `[eyeglow] <id> night_peak=%.2f day_peak=%.2f night_head=%.2f eye_px=%.1f`, `[eyeglow] none zebraceratops eyes=0`, then
  `[eyeglow] PASS` only when every species has night_peak >= 0.6, night_peak >= night_head + 0.3 and
  day_peak <= 0.6 x night_peak (the verify checks the same numbers).
- **Report** docs/orchestration/reports/dsc-eyeglow.md: the numbers, the shots you looked at, the radius and colour
  choices, assumptions, what the integrator needs.

## Placing the eyes (the hard part: do it by looking)
For each species, render the head close-up (side and front) with the dots, open the PNG, and move the points until each
dot sits on the painted eye. Write in .dsc/NOTES.md what each shot showed (images expire from your context). Start with
velociraptor; the five raptor-rigged species (utahraptor, deinonychus, velociraptor, coelophysis, compsognathus share a
37-bone rig) will have similar points scaled by head size. Do not guess a whole batch blind.

## How to run Godot (exactly)
- Headless tests: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_eyeglow.gd > /tmp/eyeglow_t.log 2>&1`
  (bash timeout_ms 460000).
- The lab needs a window (never --headless: frame_post_draw never fires headless):
  `... perl -e 'alarm 500; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=eyeglow_lab --shot-dir=/tmp/eyeglow_shots > /tmp/eyeglow_lab.log 2>&1`
- After adding a class_name file: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/eyeglow_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep; read the log file afterwards. Never re-run a hung or failed command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns (use maxf/explicit types); await coroutines;
  `--script` tests have no autoloads on their first frame (load() scripts, as t_domain does); t_save prints 5 deliberate
  SCRIPT ERRORs (normal). git writes are blocked in the dsc sandbox: the runner commits for you.
## Milestones (.dsc/PLAN.md; milestone_done after each; the milestone gate is stage 1 for M1-M2, stage 2 from M3)
- M1 data loading, CreatureEyes, the hook, WorldLighting.night, t_eyeglow: `bash <verify> 1` passes.
- M2 eye points placed for all six by close-up shots (look at every one).
- M3 the lab with numbers and game-camera readability: `bash <verify> 2` passes.
- M4 report and the full verify.
Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_eyeglow.sh [1|2]` (read it first; no argument = full gate, which
also runs t_ai, t_tame, t_canim, t_lighting, t_light, t_mounts, t_combat and smoke, and checks your scope). Baseline today:
"game/data/creatures/tyrannosaurus.json has no eyes block".

## Constraints
Your files only: creature_eyes.gd, the hook in creature_view.gd, the static in world_lighting.gd, the six creature jsons'
eyes blocks, an optional game/shaders/eye_glow.gdshader, t_eyeglow.gd, the lab script and scene, the report. Keep
game/override.cfg. Never touch other worktrees, the owner's save, ~/Documents/deadfront or project.godot. Do not push,
merge or deploy. No new dependencies.
