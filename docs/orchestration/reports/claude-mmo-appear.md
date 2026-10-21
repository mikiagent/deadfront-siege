# APPEAR-A: survivor hair, helmet shells, face (CHAR-APPEARANCE P2-P4)

Date: 2026-10-21. Agent: Claude Code (art pipeline). Branch `claude/mmo-appear`, worktree
`.claude/worktrees/mmo-appear`, base `claude/mmo-overhaul` at 29ffa292. Credits spent: 0 (no Tripo, Meshy or
image generation; headless Blender and Godot only).

| step | state |
|---|---|
| P2 hair split and four hairstyles | done, this report |
| P3 helmet shells | not started |
| P4 clean-shaven jaw, facial hair, feature decals | not started |

## P2: what shipped

Everything rebuilds from git with one command, in about a minute:

```
tools/blender/survivor_appearance/build.sh [sheet.png]
```

It reads `body/body_helmet.glb` as shipped at 29ffa292 (`git show`), so a rerun never starts from a processed
file. Two reruns gave byte-identical GLBs and JPGs (md5 checked).

| script | does |
|---|---|
| `split_hair.py` | Splits body_helmet's triangles by connected surface. The surface that holds the neck seam is the head and the rest is hair. Both GLBs keep the template's full vertex arrays, skin and inverse bind matrices, so they bind to the game skeleton exactly like the body regions. Writes the option rows into `hair/hair.json`. |
| `paint_scalp.py` | Bald and buzz scalps, painted from 3D: every head texel gets its bind-pose position through Tripo's auto-unwrap. The scalp is the head surface the hair shell covers, smoothed over the mesh, so the new hairline follows the head and not the shell's jagged strand ends (this is the "ring at the hairline"). The skin fill is a harmonic continuation of the surrounding skin: forehead tone in front, nape tone behind, no seam. |
| `crop_hair.py` | Short crop: the scalp triangles cut 16 ways and pushed out along the normal, from 0.8 mm at the painted hairline to 8.5 mm over the crown. A skirt drops the open edge 0.5 mm into the scalp. Weights are blended from the scalp, and the texture is a 1024 strand pattern flowing from the crown. |
| `render_options.py` | Neutral studio renders (Workbench, flat grey) in front, side, 3/4, back and portrait views next to the unchanged base. |
| `clip_penetration.py` | Skins the hair pieces through all 29 clips (12 frames each, linear blend skinning from the glTF data, as Godot does). Measures how far any vertex sinks into the posed head and chest, relative to the bind pose. |
| `glb.py`, `paintlib.py` | glTF reader/writer and paint helpers (numpy only) |

Files in `game/assets/characters/survivor/hair/`:

| file | what | tris | texture |
|---|---|---|---|
| `head.glb` | the head without the hair shell, original paint | 2185 | the survivor's own maps (`../survivor_*`) |
| `hair_current.glb` | today's hair as a piece. Weights: HeadTop_End 0.67, Head 0.33, Neck 0.0001 | 4119 | the survivor's own maps |
| `head_buzz.glb` | head, stubble scalp | 2185 | `head_buzz_Color.jpg` (2048, full atlas copy) |
| `head_bald.glb` | head, skin scalp | 2185 | `head_bald_Color.jpg` (2048, full atlas copy) |
| `hair_crop.glb` | crop shell (506 of its tris are the skirt) | 4105 | `hair_crop_Color.jpg` (1024) |
| `hair.json` | split stats, paint stats, the option rows | | |
| `clip_penetration.json` | per-clip penetration, below | | |

Every piece has 65 joints with the same names and inverse bind matrices as `body/body_helmet.glb` (max
difference 0.0). Bind drift is 3.0e-7 m.

`armor/forager/kit.json` and `armor/hide_and_bone/kit.json`: the helmet now hides `["helmet", "hair"]`. Both
helmets still hide the whole head until P3 makes them shells.

### The default look is today's mesh, not the split pair

The earlier draft built the default look from `head.glb` + `hair_current.glb`. In the home_lab shot that differed
from today **at the survivor's head** by 154 px (Forward+ 1600x900), 176 px (gl_compatibility 1600x900) and 43 px
(844x390); today vs today was 0 px outside the minimap. Each split mesh gets its own import LODs (and shadow
mesh), so at in-play distance the two halves simplify differently from the one mesh.

So `PlayerEquipment` keeps attaching `body/body_helmet.glb` as the head region, exactly as today. A hair row
that names the split pair (`head.glb` + `hair_current.glb`) is worn as that same file. The "hair" region exists
only while an option with a piece (crop) is on.

### Engine side: hooks patch

`docs/orchestration/reports/claude-mmo-appear-hooks.patch` touches other owners' files. It applies cleanly on
this branch and on `claude/mmo-overhaul` at ddaab662 (`git apply --check`).

- `game/scripts/player/player_equipment.gd`: `set_hair(head, scene)` swaps the "helmet" region for the row's
  head and fills a "hair" region with the row's piece through `RiggedModel.attach_skinned` (the armour path),
  then re-applies kit hiding. `""` for both, or the split pair, gives today's `body_helmet.glb`. A missing path
  warns and leaves that region alone. `setup()` is unchanged.
- `game/scripts/dev/appearance_lab.gd`, `.uid`, `game/scenes/dev/appearance_lab.tscn`: the engine gate, below.
- `game/data/characters/appearance.json`: the four rows (CHARCREATE creates this file; it is not on the base or
  on `claude/mmo-charcreate`'s tip). **If CHARCREATE's file is already there at merge, replace its `hair` part's
  options with these rows instead of taking the hunk.**

### Rows for CHARCREATE's `appearance.json`, part `hair`

CHARCREATE's in-progress file (read in its worktree, uncommitted) has `parts[].options` with `id`, `name`,
`scene`, `attach_bone` and `genders` ("m"/"f"), and a placeholder `base_short` row with `scene: ""`. These rows use
that shape and add `head` and `region`. Apply a row with `PlayerEquipment.set_hair(row.head, row.scene)`, not with
a bare `attach_skinned`: the head has to be swapped too.

```json
{"id": "base_short", "name": "Short", "head": "res://assets/characters/survivor/hair/head.glb", "scene": "res://assets/characters/survivor/hair/hair_current.glb", "attach_bone": "Head", "region": "hair", "genders": ["m"]},
{"id": "buzz", "name": "Buzz", "head": "res://assets/characters/survivor/hair/head_buzz.glb", "scene": "", "attach_bone": "Head", "region": "hair", "genders": ["m"]},
{"id": "bald", "name": "Bald", "head": "res://assets/characters/survivor/hair/head_bald.glb", "scene": "", "attach_bone": "Head", "region": "hair", "genders": ["m"]},
{"id": "crop", "name": "Crop", "head": "res://assets/characters/survivor/hair/head.glb", "scene": "res://assets/characters/survivor/hair/hair_crop.glb", "attach_bone": "Head", "region": "hair", "genders": ["m"]}
```

## P2 gates

All gates were run on this worktree with the hooks patch applied. Logs and shots are in the session scratchpad
(`scratchpad/appear/`): `gates1/`, `r7/`, `home2/`, `b3/`, `shots_p2/`.

| gate | result |
|---|---|
| Rebuild from git | `build.sh` twice: GLBs, JPGs, `hair.json` and `clip_penetration.json` byte-identical (md5) |
| Pieces vs body_helmet | 65 joints, same names, inverse bind matrices identical (max diff 0.0), bind drift 3.0e-7 m; 2185 / 4119 / 4105 tris, none over 12k |
| Blender renders, neutral light | front, side, 3/4, back, portrait for base, current (split pair), buzz, bald, crop. All looked at: clean hairline on bald and buzz in front, at the temples and at the nape, no jagged strand ring. Split pair vs base: 2 px over 5 views (a depth tie between the two meshes; the game wears body_helmet.glb for this look) |
| Engine lab, `appearance_lab` | PASS in Forward+ 1600x900, gl_compatibility 1600x900, gl_compatibility 844x390 and headless (exit 0) |
| Default look at start vs today, in the lab | 0 px in front, 3/4, portrait and world views, in all three windowed modes |
| Default look after wearing every option and switching back | 0-2 px off by more than 8/255 (a depth tie at the neck seam: the re-made head is drawn after the chest); the lab allows 4 |
| home_lab shot vs today (`--fixed-fps 60`, 2 runs per mode, minimap masked) | survivor region identical in all 6 runs (Forward+ 1600x900, gl_compatibility 1600x900, 844x390). 4 of 6 runs are 0 px everywhere outside the minimap (whose clock differs run to run). 2 runs (Forward+ run 1, 844x390 run 2) differ only at the left screen edge, where the shadow of something off screen moves in. The default code path does not call `set_hair`, so it cannot cause that. |
| Clips | each of the 4 options attached, all 29 clips played (4 x 29 in every mode); 0 "couldn't resolve track", 0 SCRIPT ERROR |
| Helmet hides hair | crop + hide_and_bone helmet: the hair piece hides, and comes back on unequip |
| Penetration (12 frames per clip, mm sunk into head + chest beyond the bind pose; worst over 29 clips: current 8.44, crop 1.25) | see the table below |
| Tests | all 21 `t_*.gd` PASS (t_save's 5 deliberate SCRIPT ERRORs only), run_all `[tests] PASS`, `SMOKE PASS`, equip_mount_lab `[equiplab] PASS` (0 "couldn't resolve track") |

| clip | current (today's hair) | crop |
|---|---|---|
| walk | 0.51 | 0.11 |
| run | 0.46 | 0.92 |
| sprint | 3.23 | 0.82 |
| attack_primary | 2.95 | 1.03 |
| attack_heavy | 8.44 | 1.01 |
| punch | 1.16 | 0.56 |
| throw_spear | 4.28 | 0.83 |
| gather | 1.54 | 0.47 |
| gather_berry | 0.92 | 0.52 |
| gather_chop | 1.18 | 0.40 |
| gather_dig | 3.94 | 0.63 |
| gather_mine | 8.02 | 1.25 |

Every worst value is below the ear tops. Bald and buzz add no geometry, so nothing can poke through. All 29 clips
are in `hair/clip_penetration.json`.

Shots I looked at (`scratchpad/appear/shots_p2/`):
- `blender_sheet_front_side_34_back_portrait.png`
- `blender_backs.png`
- `blender_34_buzz_bald_crop_current.png`
- `godot_fwd_1600x900.png`, `godot_glc_1600x900.png`, `godot_glc_844x390.png` (each option, on the right, next to the unchanged base: front, side, 3/4, back, portrait, world)
- `home_fwd_split_default_diff_REJECTED.png` (why the split default was dropped)

To rerun:
```
tools/blender/survivor_appearance/build.sh /tmp/sheet.png
godot --path game --resolution 1600x900 -- --lab=appearance_lab --shot-dir=DIR        # add --rendering-method gl_compatibility; 844x390
```

## Notes for the next steps

- **P3 must handle the default under a shell.** The default look is `body_helmet.glb`, with the hair baked in.
  Once a shell helmet hides only `["hair"]`, `_sync_body` must switch the head to `head.glb` while "hair" is
  hidden, and back when it is shown. Today both helmets also hide "helmet", so nothing shows through.
- **Today's nape strand.** In attack_heavy (frame 0) the lowest strand tip of today's hair, at bind position
  (-0.005, 1.547, -0.071), sinks 8.44 mm into the neck. It sinks 8.02 mm in gather_mine. This is the shipped
  mesh, unchanged, because the default must stay as today. The crop follows the scalp's own weights and stays at
  1.25 mm or less.
- **Crop weights.** Crop rim vertices at the nape carry Neck, Spine2 and Shoulder weight from the scalp under
  them, so they deform with the skin. That is why its penetration is low. The `hair_current` piece is
  Head/HeadTop_End only.
- **Texture cost.** Bald and buzz each carry a full 2048 colour atlas copy (about 0.7 MB JPG; one is loaded per
  survivor that picks it). A P1 skin/scalp mask with a tint could replace both.
- **Hair colour.** No tint yet. It needs P1's masks or a hair-colour parameter on the crop and current pieces.
- **Headless message.** In the headless appearance_lab, the dummy renderer prints `ERROR: Parameter "material"
  is null. at: material_get_instance_shader_parameters` once. The same line shows in t_save logs from other
  trees. It is not a script error, and the windowed runs do not print it.
- **Not synced.** The branch is not merged with `claude/mmo-overhaul` (15 commits ahead: WATER, specs 23-24);
  the hooks patch applies on its tip.
- ASSUMPTIONS:
  - `genders: ["m"]`: these pieces fit the v2 base only, which is a man.
  - The crop's crown whorl sits 2.5 cm below the top of the head and 3 cm back.
  - The buzz stubble density is 0.62 ± 0.10.
