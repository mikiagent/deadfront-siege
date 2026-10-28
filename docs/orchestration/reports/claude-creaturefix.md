# CREATUREFIX: hole in the head, turn jitter

Branch `claude/mmo-creaturefix` (cut from `claude/mmo-overhaul` db6ca929, `claude/mmo-overhaul` 51a8c46b merged in for the JAWS deinonychus). No GLB, eyes data or sound touched; no paid generation.

## Bug 1: "a big hole in its head" (velociraptor, utahraptor)

**Root cause: the creature colour shader culled back faces; the authored materials do not.**
`game/scripts/creatures/creature_color.gdshader` had `render_mode ... cull_back`. Every creature GLB imports with
double-sided materials (glTF `doubleSided`, Godot `CULL_DISABLED`; probed for all 11 GLB species, only the stegosaurus,
which is drawn as the procedural placeholder anyway, is single-sided). The raptor skulls have inward-wound patches on the
top of the head. With the authored material those patches draw (that is what Blender showed), and once COLORS rebinds
every surface to the colour shader they are culled and the sky shows through.

**Bisect** (new lab `--lab=creature_heads_lab`, four sides at the game camera's 35 deg pitch, utahraptor idle):

| Mode | What changes | Hole |
|---|---|---|
| base | as shipped (before the fix) | yes |
| nocull | colour shader with `cull_disabled` | no |
| nocolor | authored mesh + authored material back (no shader, no rest mesh) | no |
| norest | colour shader kept, authored mesh back (no rest-mesh rebuild) | yes |
| noeyes | eyeshine removed | yes |

The rest-mesh rebuild, eyeshine and pattern layer are not involved. The occlusion conversion never touches creatures:
`Occlusion.make_occludable` / `auto_fade` are only called for props, buildings, scatter and vegetation.

**Fix (one line, shared path):** `cull_back` became `cull_disabled` in the colour shader, so it matches the authored materials. Godot flips the normal on back faces in `cull_disabled` mode, so the inward patches light like they did with the authored material.

**Sweep, all 11 GLB species** (`--modes=diff`): neutral colours, one frozen pose, shot with the old `cull_back` shader and
with the shipped one. Pixels that differ are back faces the old shader hid, out of 360,000 per species:

| Species | idle | attack_primary | run | alert |
|---|---|---|---|---|
| utahraptor | **1390** (visible hole) | 1409 | 1415 | 1294 |
| megaloceros | 140 | 180 | 142 | 128 |
| velociraptor | 62 | 57 | 164 | 45 |
| coelophysis | 103 | 97 | 90 | 80 |
| deinonychus | 15 | 160 | 30 | 84 |
| gallimimus | 28 | | | |
| protoceratops | 21 | | | |
| tyrannosaurus | 16 | | | |
| compsognathus | 15 | | | |
| zebraceratops | 1 | | | |
| stegosaurus | 0 (placeholder) | | | |

After the fix the two shaders are the same, so every species is hole-free by construction. The PNGs below show it. The
velociraptor gets only pinholes in my renders, at the same spot on the skull where the utahraptor has its hole. I did not
reproduce the "big" hole the owner saw on the velociraptor at these four angles; the same fix closes it whatever pose
opens it. The 8 species without a GLB (allosaurus, ankylosaurus, brachiosaurus, dilophosaurus, smilodon, styracosaurus,
tarbosaurus, triceratops) are box placeholders and cannot have the artefact.

Images (`docs/orchestration/reports/creaturefix/`):
- `utahraptor_head_before.png`, `utahraptor_head_after.png`, `utahraptor_head_diffmask.png` (magenta = hole pixels)
- `velociraptor_head_before_run.png`, `velociraptor_head_after_run.png`, `velociraptor_head_diffmask_run.png`
- `contact_all_species_after.png` (game colours), `contact_all_species_after_neutral.png` (neutral colours)

Re-run: `godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=creature_heads_lab --shot-dir=/tmp/heads --modes=diff [--species=utahraptor] [--clip=run@0.3]`.

## Bug 2: "they glitch around (turn speed might be too fast)"

**Root causes:** `Creature.face_towards` used `lerp_angle(yaw, goal, delta * 10)`, an exponential snap with no speed cap.
`CreatureBrain._face_target` passed `delta * 3` in attack, which is almost instant. `TyrantBrain._do_attack` passed `1.0`, a
full snap in one frame. Locomotion also faced the raw nav step every frame, so any path jitter (a pack crowding the
player) turned straight into yaw jitter.

**Fix:**
- `CreatureDef.turn_rate` (rad/s) is read from an optional `turn_rate` field in the species JSON. The default comes from size via `CreatureDef.default_turn_rate(real_length_m)`: 5.0 up to 8 m, 3.0 up to 14 m, 1.4 above. SCHEMA.md documents it.
- `Creature.face_towards` steps yaw with `rotate_toward` by at most `turn_rate * physics step`. All callers in one physics frame share that budget (`_turn_frame` / `_turn_left`), so a brain and the locomotion together can never turn faster than the species. The `delta` argument is kept only for the callers' signature. A later tactical-AI package can call `face_towards` / `turn_rate()` as they are.
- Locomotion faces a low-passed velocity (`FACE_VEL_TAU_S = 0.15`), never turns below `FACE_MIN_SPEED_MPS = 0.3`, and ignores heading reversals inside `FACE_SLACK_RAD = 0.05` (3 deg). Without that slack the low-pass still left a ±1 deg wobble that flipped direction every frame (119 flips in 120 frames in the test below).
- Removed: the `delta * 3` in `_face_target` and the tyrant's `1.0`. The tyrant now locks `locked_forward` to the direction of the target at windup start. During the windup the body turns into that aim at the capped rate, so a bite at a target behind it still lands where it was aimed; it was a snap before. `_impact` is unchanged.

Every value is `# ASSUMPTION` (the PRDs give no turn rates):

| Species | real_length_m | turn_rate rad/s |
|---|---|---|
| compsognathus | 3 | 5.5 |
| velociraptor | 6 | 5.0 |
| coelophysis | 6 | 5.0 |
| smilodon | 2.5 | 5.0 |
| megaloceros | 3 | 4.5 |
| protoceratops | 4 | 4.0 |
| zebraceratops | 4.3 | 4.0 |
| deinonychus | 10.2 | 4.0 |
| utahraptor | 11 | 3.5 |
| gallimimus | 12 | 3.5 |
| dilophosaurus | 12 | 3.0 |
| styracosaurus | 11 | 2.5 |
| allosaurus | 18 | 2.0 |
| tarbosaurus | 20 | 1.6 |
| triceratops | 18 | 1.5 |
| ankylosaurus | 16 | 1.3 |
| stegosaurus | 18 | 1.3 |
| tyrannosaurus | 24 | 1.3 |
| brachiosaurus | 44 | 1.2 |

New test `game/tests/t_turnrate.gd`:
- Max yaw step per frame stays at or below turn_rate·dt for compsognathus, velociraptor, deinonychus, utahraptor, triceratops and T. rex, with two callers facing in the same frame. A 180 deg turn takes the expected number of frames.
- On a goal swinging ±1.5 m every frame, deinonychus, velociraptor and T. rex flip yaw direction 0 times in 120 frames and keep their heading.
- The T. rex windup on a target behind it turns no more than the cap, aims at the target (dot 1.000) and lands.

## Gates

Headless via gslot, run on this branch with the canon merge included:

```
[t_turnrate] PASS
[t_ai] PASS
[t_combat] PASS
[t_canim] PASS
[t_natures] PASS
[t_tame] PASS
[t_occlude] PASS
[t_occlfix] PASS
[t_colors] PASS
[t_eyeglow] PASS
[t_data] PASS items=246 recipes=171
GATE PASS                (python3 tools/audit_gaits.py --gate)
SMOKE PASS               (bash tools/smoke.sh --no-import)
[tests] PASS             (run_all; its 6 SCRIPT ERRORs are the known ones: compile order for hunt_hud,
                          exhaust_treadmill and run_all, plus the deliberate economy_tests FaultyEngine faults)
```

## Risks and notes for the next agent

- Mounts use the species turn rate too. A ridden T. rex now turns at 1.3 rad/s (about 2.4 s for a half turn). That is intentional for wild animals, but the owner may want a faster rate when ridden; `mounted_move` in `player_pets.gd` is the one place to change.
- The colour shader is now double-sided for every creature, which matches the authored materials. Fragment cost is the same as before COLORS, when the authored materials were drawn.
- Canon: the JAWS deinonychus GLB embeds textures that import as `deinonychus_Color_/ORM_/NormalGL_<uuid>` files. Those are not in git. A worktree with a stale `.godot` cache fails to load the deinonychus (`Resource file not found ... deinonychus_Color_...jpg`) until `.godot/imported/deinonychus.glb-*.{md5,scn}` is deleted and the project re-imported. I did that locally and committed none of those files, because the art thread owns `game/assets/creatures/`.
- `Creature._on_died` raises `Trying to assign an array of type "Array" to a variable of type "Array[Creature]"` (creature.gd ~708) when a creature dies outside a world. This was already the case on base, and t_turnrate works around it by not killing the prey. I left it alone.
- `creature_heads_lab` is a dev lab (scenes/dev + scripts/dev). It is not in any test.
