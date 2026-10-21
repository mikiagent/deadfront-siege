# APPEAR-A: survivor hair, helmet shells, face (CHAR-APPEARANCE P2-P4)

Date: 2026-10-21. Agent: Claude Code (art pipeline). Branch `claude/mmo-appear`, worktree
`.claude/worktrees/mmo-appear`, base `claude/mmo-overhaul` at 29ffa292. Credits spent: 0 (no Tripo, Meshy or
image generation; headless Blender and Godot only).

| step | state |
|---|---|
| P2 hair split and four hairstyles | done, this report |
| P3 helmet shells | done, this report |
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

`armor/forager/kit.json` and `armor/hide_and_bone/kit.json`: in P2 the helmet hid `["helmet", "hair"]`. Since P3
it hides `["hair"]` only (see P3).

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
| walk | 0.51 | 0.38 (0.11 before P3's fix to the measure, see P3) |
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

## P3: what shipped

The forager hat and the hide_and_bone skull are now shells: the survivor's own head (face, chosen scalp, later the
beard) shows under them, and only the hair piece hides. 0 credits; everything is rebuilt by the same
`tools/blender/survivor_appearance/build.sh`, from the helmets as shipped at 29ffa292.

**Merge these GLBs and kit.json only together with the hooks patch.** kit.json now hides `["hair"]` only. Today's
`PlayerEquipment` has no hair region and keeps `body_helmet.glb` (the hair baked in) as the head, so without the
patch the baked hair would poke through both helmets.

| file | what |
|---|---|
| `tools/blender/survivor_appearance/shell_helmet.py` | the shell cut, below |
| `armor/forager/helmet.glb` | 5025 -> 3524 tris (3499 helmet + 25 cap) |
| `armor/hide_and_bone/helmet.glb` | 2958 -> 2058 tris (2029 helmet + 29 cap) |
| `armor/*/kit.json` | helmet slot: `hides: ["hair"]` (was `["helmet", "hair"]`), new triangle count, provenance line |
| `armor/helmet_shells.json` | what each step kept, pushed, repainted and capped, per surface |
| `armor/helmet_clip_penetration.json` | the clip gate for both shells, every clip |

What `shell_helmet.py` does, in order:

1. **Cut.** Tripo's helmets carried the man's own head inside them. His face, eyes, mouth, neck and hair are
   their own connected surfaces (welded by position). It keeps the largest surface, plus every surface that
   touches it (within 3 mm) and sits clear of the bald head (median more than 5 mm out).
   - Forager keeps the hat, a twig and the crown plug. It drops the head (1340 tris), the mouth and both eyes.
   - hide_and_bone keeps the skull, two ear cords and a strap bit. It drops the head (800 tris), both eyes, a nape
     fringe floating 5 mm off the skull and two specks 8-9 cm away.
   - So there are no face shards and no floating spikes.
2. **Fit.** Where the helmet sat up to 6 mm under the base scalp (Tripo's head was lower in places), it is pushed out
   to 1.5 mm over it. Neighbours follow part of the way. Forager: 27 vertices, at most 6.6 mm. Skull: 6 vertices,
   6.0 mm. Deeper parts (lips tucked into the head) stay inside it. Without this, the bald scalp showed through
   gaps in the forager's crown.
3. **Weights.** Helmet within 1.5 cm of the head or chest takes the skin's own weights there, blending back to its
   source weights by 5 cm, so it rides with the skin. The temples carry some Neck, the nape Spine2. In the clip gate
   this took the forager's band from 9 mm into the temple in every clip (idle included) to 0.
4. **Paint.** 27 skull faces that Tripo painted with the face's skin colour (the `render_icons.py` skin test, within
   3 cm of the head) get the helmet's darkest paint. Forager: none.
5. **Caps.** Every hole up to 40 edges gets a fan in that dark paint, unless the head fills it.
   - A hole is the shortest boundary cycle through an edge; Tripo pinches some holes onto the opening.
   - 8 caps per helmet. One is the 4-edge hole in the forager's band right in front of the forehead, where the
     forehead showed through.
   - The 23-edge crown hole stays: the crown plug covers it and the head passes into it.
   - The dark paint is a small patch inside the helmet's darkest wide UV triangle, mapped planar so tangents stay
     valid. The embedded maps are byte-identical to the source, so Godot extracts the same `helmet_*` textures.

### Engine side (hooks patch, regenerated)

`PlayerEquipment._sync_body()` works out which head shows:

- Today's look (`body_helmet.glb`) under a piece that hides `"hair"` swaps to `hair/head.glb`, the bald twin with
  the same paint. It swaps back on unequip.
- Buzz, bald and crop keep their own head; crop's hair piece hides.
- `head_shown` names the file showing now. `set_hair()` now only records the choice and lets `_sync_body()` swap.
- `_swap_region()` returns false on a missing file.
- With no helmet nothing swaps, so the default path is unchanged.

`appearance_lab` runs every option bare-headed and under each helmet. It checks:

- the head is visible and is the expected file;
- the hair piece is hidden;
- all 29 clips play;
- unequip restores the head and the hair;
- shots for each helmet, option and view.

The patch applies cleanly on this branch, on `claude/mmo-overhaul` at 809be2e8, and on overhaul after CHARCREATE's
hooks patch (`git apply --check`, `appearance.json` excluded: CHARCREATE now has that file, so its hair part takes
the four rows above).

**For the merger:**
- CHARCREATE adds `CharacterLook.refresh(rig)` after attaching kit pieces in `equip()`. The heads `_swap_region()`
  attaches need the same call, or a recoloured skin would revert under a helmet.

## P3 gates

Logs and shots: `scratchpad/appear/p3/` (`b1/`, `lab1/`, `home/`, `tests/`) and `scratchpad/appear/shots_p3/`.

| gate | result |
|---|---|
| Rebuild from git | `build.sh` twice: 24 files (both helmets, both kit.json, both json reports, every hair file) byte-identical (md5). The P2 GLBs, JPGs and hair.json are unchanged. |
| Shells vs source and body | 65 joints with the body's names; inverse bind matrices identical to the shipped helmets (max diff 0.0) and 6.9e-6 from body_helmet's, as shipped; weights sum to 1; material and the three embedded maps byte-identical; 3524 / 2058 tris, none over 12k |
| Blender renders, neutral light | 7 rows (base; each helmet over the default head, buzz, bald) in front, side, 3/4, back, portrait and the play camera's angle from above; plus close-ups from below, above, behind and the side. All looked at: no face shards, no floating spikes, no hair or scalp through the hat crown or band, face under both brims is the base face in the chosen skin |
| Engine lab, `appearance_lab` | PASS in Forward+ 1600x900, gl_compatibility 1600x900, gl_compatibility 844x390 and headless; 0 SCRIPT ERROR, 0 warnings |
| Clips | 4 options x (bare, forager, hide_and_bone) x 29 clips in every mode; 0 "couldn't resolve track" |
| Default look vs today, in the lab | 0 px at the start; 0 px off by more than 8/255 after every option and helmet was worn, in all three windowed modes |
| home_lab shot vs today (P2's baseline shots, 2 runs per mode, minimap masked) | survivor region identical in all 6 runs. Forward+ and 844x390: 0 px everywhere. gl_compatibility 1600x900: 10k px at the left screen edge, where a wandering creature is in one shot and not the other (the two P3 runs differ from each other there too). No helmet is worn in home_lab, so the new code does not run there. |
| Penetration (12 frames per clip, mm of helmet sunk into head + chest beyond the bind pose) | forager 0.0 in all 29 clips. hide_and_bone 0.0 in walk, run, attack_primary, gather, gather_berry, gather_chop and gather_dig. Its worst values: death 7.94, attack_heavy 7.54, gather_mine 6.63, throw_spear 3.72, fish_cast 3.64, sprint 0.91. These are the bottom tips of the skull's back plate, at the nape, when the head tips far back. Hair hides under both helmets, so nothing of the hair can clip. |
| Tests | all 21 `t_*.gd` PASS (t_save's 5 deliberate SCRIPT ERRORs only), run_all `[tests] PASS`, `SMOKE PASS`, equip_mount_lab `[equiplab] PASS` (0 "couldn't resolve track") |

**The measure changed in P3.** `clip_penetration.py` counted a point as under the surface whenever the nearest
point's normal faced away. Far from the head (a hat brim 6-10 cm out) or beside an ear rim, that sign flips: the
forager read 52-66 mm in clips where nothing touched. A point now counts only when it lies straight under a face,
within 3 cm. P2's worst values are unchanged (current 8.44, crop 1.25). Some crop values under 1 mm moved, for
example walk 0.11 -> 0.38.

Shots I looked at (`scratchpad/appear/shots_p3/`):
- `blender_sheet_helmets_front_side_34_back_portrait_iso.png`
- `blender_closeups_default_buzz_bald.png`
- `godot_fwd_1600x900_heads.png`, `godot_glc_1600x900_heads.png` (each helmet x option on the right, next to the
  unchanged base: front, side, 3/4, back)
- `godot_glc_844x390.png`
- `home_glc_vs_today_creature_left_edge.png`

What did not work, and was dropped:
- **A scalp liner under the crown.** It showed through as a dark band on the forehead and over the ears.
- **A backing behind holes, found by sight lines.** The skull's sockets sit on a convex surface, so a "surrounded
  on all sides" test misses them. It also caught the gaps between the teeth and painted the forehead.

## Notes for the next steps

- **The skull's eye sockets show the wearer's head.** Through them you see the forehead and front scalp: dark with
  the default and crop heads, stubble with buzz, skin with bald. That is what a worn skull shows. The base head
  sits higher than Tripo's head did and fills the socket cavity, so the dark lining there is gone. To get dark
  sockets for every look, plug the two socket tunnels (find the rim by hand, or ask for a re-bake with closed
  sockets).
- **The skull's back plate at the nape.** It dips up to 7.9 mm into the neck when the head tips far back (death,
  attack_heavy, gather_mine). Walk, run, attack_primary and gather are 0.
- **P4.**
  - Beards show under both helmets, since only `"hair"` hides. The skull's cheek guards run down beside the jaw.
  - Check the long beard against them before deciding whether hide_and_bone should also hide `"beard"`.
  - Facial-hair decals live on the head, so they are unaffected.
- **Icons.** `forager_hood` and `hide_bone_helm` are rendered from these GLBs (`icons/render/manifest.json`).
  - The committed PNGs are untouched, and t_iconart passes.
  - `tools/render_icons.py --verify` will now report those two as changed until the icon owner re-renders them. The
    new renders lose Tripo's face and hair, which `render_icons.py` was stripping by colour anyway.
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
- **Not synced.** The branch is not merged with `claude/mmo-overhaul`, which is 31 commits ahead at 809be2e8. The
  hooks patch applies on that tip.
- ASSUMPTIONS:
  - The skull's eye sockets stay open and show the wearer's head (P3).
  - The forager's crown plug (82 tris, part of Tripo's hair top fused into the hat) is part of the hat.
  - `genders: ["m"]`: these pieces fit the v2 base only, which is a man.
  - The crop's crown whorl sits 2.5 cm below the top of the head and 3 cm back.
  - The buzz stubble density is 0.62 ± 0.10.
