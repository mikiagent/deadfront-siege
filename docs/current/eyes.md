# Glowing eyes, bloom and trails

Owner: `game/scripts/creatures/creature_eyes.gd` (eyeshine dots) and
`game/scripts/creatures/eye_trail.gd` (`EyeTrail`: bloom, wisps and embers). Per-species eye points
live in `game/data/creatures/<id>.json` under `"eyes": {bone, points, radius, color}` and are owned by the
art thread: the code never writes them.

## Eyeshine (the dots)
Two small unshaded HDR dots on the Head bone, one per authored `points` entry, pushed 5 mm out of the skull
(`SURFACE_PUSH_M`) and capped to 0.6 % of the animal's height (6 mm .. 25 mm). Brightness is global: the
shared per-colour material is painted from `WorldLighting.night` (`NIGHT_ENERGY` 20 at night, a
`day_fraction` 0.01 glint by day). The dots hide when the animal is dead or in the `sleep` brain state.
Six species carry an `eyes` block: tyrannosaurus, utahraptor, deinonychus, velociraptor, coelophysis,
compsognathus.

## Rim light
`CreatureEyes` adds one `OmniLight3D` per eye (child of the dot, so it rides the head bone), pushed
`RIM_PUSH_PER_SEPARATION` 0.35 eye separations out of the socket, range 0.8 separations, attenuation 2.4,
no shadows, eye colour. It is on only above night 0.05 and its energy is `RIM_LEVEL` 1.2 x push distance²
x night: Godot's omni falls off with the inverse square of the distance, so a fixed energy burnt small
heads white. The skull around the socket catches the glow, so the face reads at night.

## Bloom, flame strands and embers (`EyeTrail`)
`EyeTrail` is one `MeshInstance3D` per eyed creature holding **one indexed ArrayMesh surface** for
everything below, so it costs one draw call. Vertices are world positions (`top_level`) so the flame lags
behind the head instead of riding the bone. The material is the flame shader (`FLAME_SHADER`): additive,
unshaded, no depth write, no fog, no shadow.

- **Core and bloom** (always, while the eyes glow): per eye a white-hot core (`CORE_PER_RADIUS` 1.1 dot
  radii, at least `MIN_CORE_PX` 2.5 px) over a bloom (`BLOOM_PER_RADIUS` 5, at least `MIN_BLOOM_PX` 9 px)
  whose alpha falls ring by ring (`BLOOM_RING` / `BLOOM_ALPHA`) to 0. The anatomical dot is 1-3 px from
  the game camera (4.3 deg lens, ~190 m out), so the pixel floors are what makes the eye visible at all.
  Pulled towards the camera along the view ray only (it stays on the eye on screen, the skull does not
  clip it).
- **Flame strands** (head speed above `MIN_SPEED_MPS` 1.6, full at 4.5 m/s; round 2): a Catmull-Rom curve
  through the eye's recent positions, the older part dragged downwind with a slight rise (`DRIFT_MPS`
  0.5, one fixed `WIND`). Over that curve each eye draws a fan of strands (`STRAND_*` tables): strand 0
  the main tongue, 1 and 2 shorter and thinner, fanning out to either side (`FAN_SPREAD` 4.5 half-widths
  at the tip), and 3 a wide faint glow under them in the eye colour. Every strand starts at the eye and
  tapers to a point, is feathered (three vertex columns, edge alpha 0), and has its own flowing noise on
  alpha and lateral flutter (`FLICKER` 0.4 at `FLICKER_HZ` 9). Main half-width: the larger of 0.9 dot
  radii and 2.6 px. Pulled `CLEAR_PER_SEPARATION` 1.5 eye separations towards the camera so it clears
  the near half of the skull it streams over.
- **Flame shader**: strands carry UV.x across the strand and UV.y = position along it (0 eye, 1 tip) + 2 x
  strand index; everything else carries UV.y = -1 and is not torn. A 64x64 tileable noise texture
  (FastNoiseLite, built once, synchronously) scrolls from the eye to the tip (`flow` 1.7); a fragment
  survives only where the noise beats a threshold that rises towards the tip and the edges (`tear` 0.7;
  the glow strand tears at 0.4 of that), so each strand flickers and breaks into licks. Heat follows the
  noise and falls along the strand: hot near the eye, deeper towards the tip.
- **Embers**: a spark every second sample along the flame, twinkling on noise and drifting off as it ages.

### Quality toggle
`EyeTrail.low_quality` (static) defaults to on when the renderer is not Forward+ (gl_compatibility on the
web, the mobile renderer) or the build runs on web or a phone: the same split `WorldLighting._compat` and
`ProcessFx` use. Each trail reads it in `setup()`. Low draws strands 0-2 (no glow strand) over 7 rows
instead of 10, every fourth sample's ember instead of every second, and the shader variant
`#define LOW` takes one noise tap instead of two. 242 vertices per creature instead of 392.

### No per-frame allocation
Every buffer (vertices, colours, the sample chain, the curve rows, the per-strand shape tables) is sized
once in `setup()`. The index buffer and the UVs never change; per frame only positions and core colours
are written by index and uploaded with one `add_surface_from_arrays`. A ribbon block with nothing to
draw is collapsed to one point (degenerate triangles), and `custom_aabb` keeps culling and sorting on the
real reach around the eyes. The engine still copies the vertex buffer to the GPU each frame (as the
round-1 ImmediateMesh did).

| Constant | Value | Meaning |
|---|---|---|
| `MAX_SAMPLES` / `FADE_S` / `SAMPLE_DT` | 12 / 0.3 s / 0.03 s | past positions per eye, how long one is drawn, sample cadence |
| `FORCE_STEP_M` | 0.035 m, at least `max_length_m / (max_samples - 1)` | a move this long samples at once; the floor keeps 120 fps from cutting the flame short |
| `SPEED_SMOOTH` | 25 /s | head speed is smoothed: at 120 fps the bone moves on 60 Hz physics frames only |
| `MAX_LENGTH_M` | 3.2 m | longest flame for eyes 0.35 m apart (deinonychus); scaled by eye separation within 0.6-2.2x |
| `MIN_SPEED_MPS` / `FULL_SPEED_MPS` / `STRENGTH_DECAY` | 1.6 / 4.5 m/s / 5 per s | where the flame starts, where it is full, how fast it dies down |
| `TIP_POW` / `HOT_HEAD` | 0.9 / 0.25 | alpha falls as fade^TIP_POW with age; how white the core burns at the eye |
| `SEGMENTS` / `SEGMENTS_LOW` | 10 / 7 | curve rows per eye |
| `STRANDS` / `STRANDS_LOW` | 4 / 3 | strands per eye (`STRAND_SET` / `STRAND_SET_LOW`) |
| `RESET_JUMP_M` | 2.0 m | a bigger jump is a teleport: the buffer is dropped |
| `MAX_CAMERA_DISTANCE_M` | 600 m | plus a frustum check: off-screen animals build nothing |
| `ENERGY` | 2.2 | HDR level of the flame (shader `energy`) |
| `MAX_VERTICES` | 440 | most vertices one creature draws (asserted) |

Visibility is the eyeshine's: awake, not asleep, not dead, same night fraction.

## Data
No new file under `game/data/creatures/` (every `*.json` there is parsed as a species by
`Data._load_creatures`, so a knob file would log a malformed creature). Per-species overrides are an
optional `"trail": {...}` object **inside the existing `eyes` block**, same keys as the table above
(`fade_s`, `max_samples`, `min_speed_mps`, `full_speed_mps`, `max_length_m`, `flicker`, `flicker_hz`,
`drift_mps`, `taper`, `tip_pow`, `hot_head`, `width_per_radius`, `energy`, `max_distance_m`); every value
is clamped, so a typo cannot spin the buffer.

Eye points (round 3, 2026-10-28): all six species re-measured with `eyeglow_lab --sockets`, without
anyone picking a pixel. The lab renders an unlit (albedo-only) orthographic side close-up of the bind-pose
head, with the dots and flame hidden, and downscales it to 225 px. It takes the strongest contrast blob
within 0.15 eye separations of the old point and re-centres it six times on the luminance-weighted
centroid of its pixels. That pixel's ray against the mesh gives the near eye on the skin; the far eye is
that point mirrored across the model's midline. The lab saves `<id>_socket_marked.png` for a check. The
blob lands within about a third of the painted eye's radius of its centre (on the iris for deinonychus,
coelophysis, T. rex; at the upper edge for utahraptor and velociraptor, by about 1-2 cm). Changes from the
old points (near eye, world): T. rex 23 mm forward; utahraptor 40 mm up, 11 mm forward; deinonychus
13 mm up; velociraptor 32 mm up, 18 mm back; coelophysis 14 mm back; compsognathus 17 mm up.

The owner said the deinonychus eyes were "very close together". The mesh does not support that: the
spacing was already the skull's own width at the socket (0.200 m on a 0.183 m skull, now 0.193 m with
the 5 mm surface push), and every pair was already mirrored. What read as two eyes close together was
the far eye glowing through the head in profile (below).

## The hidden eye (round 3)
Owner: "when the enemy is facing you such that you should only see one eye, you see both eye trail
candle sources". The core and bloom draw without a depth test, so the far eye showed through the skull.
Per eye, `EyeTrail._facing` compares the eye's outward axis (from the other eye to it) with the
direction to the camera. At or below `FACING_HIDDEN` (-0.45) the eye's core and bloom have alpha 0; at
or above `FACING_SHOWN` (-0.1) they are fully lit. Head-on gives 0, so both eyes show. A 90 deg profile
from the iso camera gives about -0.8 for the far eye. A hidden eye's flame starts transparent at the eye
and fades in from `SKULL_CLEAR_FROM` 0.9 to `SKULL_CLEAR_TO` 1.6 eye separations along it, so it appears
once it has streamed out past the skull. Embers get the same treatment. All of this is CPU-side alpha,
so it works the same on gl_compatibility. The eyeshine dots are depth-tested already. The rim lights
are unchanged.

`_in_view` now culls by the eye, not by the Eyes node. That node sits at the animal's feet, so a T. rex
whose feet were just off the bottom of the screen lost its glowing eyes.

## Cost
Measured by `t_eyetrails` on this Mac, script time inside `tick()` only, animals running at full flame
strength (round 2 fixed the measurement: round 1 timed animals standing still, so it mostly timed the
bloom; the round-1 code measured the same way costs 5.6 ms for 20 animals):

| | per creature | 20 creatures |
|---|---|---|
| round 1 (ImmediateMesh, 1 wisp per eye) | ~280 us | 5.6 ms |
| round 2 high (4 strands per eye) | ~70 us | 1.4 ms |
| round 2 low (3 strands, web / phones) | ~53 us | ~1.1 ms |

The saving is the indexed layout (three vertices per strand row instead of 24, UVs and indices written
once) and a 256-entry noise table instead of two `sin()` per sample. The upload itself is about 2 us. GPU:
the flame shader is one or two texture taps on a few hundred small additive fragments per eye. Two omni
lights per glowing creature at night (no shadows).

## Tests
`game/tests/t_eyeglow.gd` (dots, night contrast, dead hides) and `game/tests/t_eyetrails.gd` (still head
draws nothing, speed grows length and alpha, fade-out after stopping, sample cap, flicker spread versus
`flicker: 0`, length cap at 12 m/s, day/dead/asleep hidden, distance cull stops rebuilding, 20-animal
cost; round 2: the shader's render modes and noise texture, the quality toggle (strand count, shader
variant, fewer vertices, less script), and no per-frame allocation: fixed buffer size, no Object created,
static memory flat over 360 ticks, and a scan of the tick-path functions for allocating constructs;
round 3: for the deinonychus and the T. rex at a 90 deg profile from 190 m, 35 deg up, the far eye's halo
alpha is at most 2 % of the near one's; head-on both are within 10 %; the far flame is 0 at the eye and
fully on 2 separations out). `t_eyeglow` round 3: every eyed species' dots mirror across the midline,
and their spacing matches the skull's skin-to-skin width at the socket within 12 % (rays along the
lateral axis at each dot's height and length, bind pose). `t_eyetrails` also renders a look-pass with `-- --shot-dir=DIR` when run windowed: a night ground plane,
`WorldLighting` at midnight and the real `IsoCamera` (default zoom 14 m, 18 m for the T. rex), the animal
standing in profile, then head-on, then running a curve across the screen and snapping round, at 60 fps and real frame time; it saves
800x450 crops around the eye. Options: `--shot-species=a,b`, `--shot-zoom=<m>`, `--shot-tod=<0..1>`
(0.79 is dusk). Add `--rendering-method gl_compatibility --rendering-driver opengl3` for the web look
(which also turns on the low-quality path).
