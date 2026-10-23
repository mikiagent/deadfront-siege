# Tyrannosaurus rex — rig, weights, animation

Tripo P1 multiview mesh (task `c7aea80d-714b-49f6-b59b-645c87f8a6c9`, 50 credits), rigged and
animated in Blender 5.2 LTS through the MCP for Blender add-on.

## Mesh

| | |
|---|---|
| triangles | 13,855 |
| vertices | 7,025 (after merge-by-distance 0.0005 m; 17,912 before) |
| material | 1 PBR: base colour, metal/rough (ORM) and normal, 2048² each, embedded in the GLB |
| height | 8.00 m (measured, feet at Z = 0) |
| length | 19.37 m nose to tail tip |
| facing | head toward Blender +Y → glTF **−Z** (the game's forward) |
| origin | at the feet, centred in X and Y |

The imported mesh was 1 unit long along glTF X. The head end (tall, bulky skull) was identified at
+X by slicing the mesh along its length and comparing cross-section height; the tail tapers to a
0.27 m point at −X. It was rotated +90° about Z, scaled ×19.412 to 8.0 m, moved so the lowest
vertex sits at Z = 0, and all transforms applied.

Merge-by-distance removed 10,887 duplicate vertices. **258 non-manifold vertices remain** — the
mesh is a scan-style shell with open boundaries at the mouth interior and around the separate
teeth/claw islands. It is 41 islands: one body (6,275 verts) plus 40 small ones (teeth in the
mouth, claws on the feet). This is fine for a game asset but means the mesh is not watertight.

## Rig

One armature, `Armature`, 30 bones, all deforming except `root`:

```
root
└ Hips ─ Spine1 ─ Spine2 ─ Chest ─ Neck1 ─ Neck2 ─ Head ─ Jaw
  │                        ├ Arm.L ─ Forearm.L ─ Hand.L
  │                        └ Arm.R ─ Forearm.R ─ Hand.R
  ├ Thigh.L ─ Shin.L ─ Metatarsal.L ─ Toe.L
  ├ Thigh.R ─ Shin.R ─ Metatarsal.R ─ Toe.R
  └ Tail1 … Tail7
```

Joints were **measured from this mesh**, not guessed:

- **Spine/neck/head**: cross-sections every 0.5 m along Y gave the body centreline (z ≈ 5.3–5.6
  over the trunk, rising to 6.6 at the skull). Hips at y 1.60, chest at y 4.60, head pivot at
  y 6.90, snout tip at y 9.30.
- **Jaw**: the mouth line is the crease where the side normals flip from up to down; sampled per
  slice it runs 6.72 at y 6.9 down to 5.97 at y 9.0. The jaw bone pivots at (0, 7.00, 6.45) and
  runs to the chin at (0, 9.35, 5.95).
- **Legs**: the vertex clusters below the belly on each side, sliced by Z. Hip (1.05, 1.60, 3.40),
  knee (1.20, 0.78, 1.80), ankle (1.25, 1.25, 0.85), ball of foot (1.35, 1.95, 0.22), toe tip
  (1.45, 3.30, 0.12) — the bird-like zigzag the mesh actually has.
- **Arms**: the small limbs under the chest, shoulder (0.85, 5.75, 5.15) → elbow (0.95, 5.15,
  4.15) → hand (1.00, 5.45, 3.80).
- **Tail**: seven bones following the measured centreline from the hips to the tip at y −9.60.

**Side naming**: the animal faces +Y, so its right side is +X. `.R` bones are at +X and `.L` at
−X, matching the creature's own left/right. (The first pass had them mirrored; the names were
swapped on both bones and vertex groups so the game's "raise the right foot" means the foot the
camera sees.)

## Weights

`ARMATURE_AUTO` (bone heat) succeeded — no voxel-remesh fallback was needed. Then:

1. Two smoothing passes over the mesh graph on the body island.
2. **Hard jaw/skull split** at the measured mouth line: everything below it and forward of y 7.0
   is `Jaw` only, everything above is `Head` only, with a 0.12 m blend band. Teeth are thin spikes
   that cross the plane, so classification uses a 6-pass low-pass position (a tooth tip averages
   back toward its own gum) and requires both raw and smoothed positions to agree.
3. **Teeth islands** are assigned whole to `Head` or `Jaw` by cone direction: the base end holds
   more vertices than the tip end, and upper teeth point down while lower teeth point up.
4. **Claw islands** go to the nearest `Toe.*` / `Hand.*` bone.
5. Normalised, limited to 4 influences, and a safety net assigns any leftover vertex to its nearest
   bone.

Result: **0 unweighted vertices, 0 unnormalised, 0 vertices over 4 influences.** The upper skull
does not move with the jaw — verified by posing the jaw 25° open and measuring per-vertex
displacement (only the 5 vertices at the very back of the mouth crease move, by <2 cm).

Test poses checked visually: jaw open 25° (no tearing of the skull), right leg raised, tail curved,
head turned.

## Clips

30 fps. All clips are grounded per frame (a root-Z correction pass guarantees the lowest vertex
never goes below Z = 0). Loops (`idle`, `walk`, `run`, `sleep`) have identical first and last
frames and no root drift.

| clip | frames | duration | notes |
|---|---|---|---|
| idle | 1–121 | 4.00 s | loop; breathing, tail sway, jaw idle |
| walk | 1–49 | 1.60 s | loop; two steps, counter-swinging tail |
| run | 1–28 | 0.90 s | loop; longer stride, deeper body pitch |
| attack_primary | 1–48 | 1.57 s | **hit at frame 21 (42%)** — jaw snaps shut |
| attack_heavy | 1–78 | 2.57 s | **hit at frame 56 (72%)** — right foot lifts 0.86 m, held f24–f36 (0.6 s), then stomps |
| tail_swipe | 1–60 | 1.97 s | wind-up left, sweep right |
| hit_react | 1–24 | 0.77 s | flinch and recoil |
| knockdown | 1–96 | 3.17 s | staggers, buckles, ends lying on its side |
| death | 1–90 | 2.97 s | hit, knees, falls to its side, still |
| alert | 1–72 | 2.37 s | rears up, roars with the jaw wide |
| feed | 1–120 | 3.97 s | head down, three bite-and-tear cycles |
| sleep | 1–181 | 6.00 s | loop; lying on its side, breathing |

## Files

```
tyrannosaurus.glb            mesh + armature, rest pose, no animation, textures embedded
anim/<clip>.glb              same armature, exactly one animation each
sheet.png                    4 rest views + 3 key poses per clip (12 clips)
work/tyrannosaurus.blend     the working file
work/*.py                    the pipeline scripts (build_all.py rebuilds every clip)
```

## Notes on the previous run's scripts

`ref/prev_work/` was reused as instructed: `animlib.py`, `clips_loco.py`, `clips_attack.py`,
`clips_react.py`, `clips_extra.py` and `sheet.py` were copied into `work/` and repointed at this
project. Retuning for this heavier, longer-legged body:

- `attack_heavy` now raises the **right** foot (the previous run raised the left, which the game
  camera would not see) and drops the hips 0.52 m on the stomp instead of 0.34 m.
- `attack_primary` lunges and bites 0.42–0.48 m lower for the heavier body.
- `ground()` in `animlib` only grounds the poses it is handed, so clips that never call it (run,
  both attacks, feed) sank up to 1.1 m through the floor. `s12_groundfix.py` corrects the root-Z
  curve per frame on every action after the clips are built.
- Blender 5.2 has no `BLENDER_EEVEE` engine id; `sheet.py` now falls back through
  `BLENDER_EEVEE_NEXT` → `BLENDER_EEVEE` → `BLENDER_WORKBENCH`.
