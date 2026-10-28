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

## Bloom, wisps and embers (`EyeTrail`)
`EyeTrail` is one `MeshInstance3D` per eyed creature holding **one ImmediateMesh with one surface** for
everything below, so it costs one draw call. Additive, unshaded, no depth write, no fog, no shadow; vertices
are world positions (`top_level`) so the wisp lags behind the head instead of riding the bone.

- **Core and bloom** (always, while the eyes glow): per eye a white-hot core (`CORE_PER_RADIUS` 1.1 dot
  radii, at least `MIN_CORE_PX` 2.5 px) over a bloom (`BLOOM_PER_RADIUS` 5, at least `MIN_BLOOM_PX` 9 px)
  whose alpha falls ring by ring (`BLOOM_RING` / `BLOOM_ALPHA`) to 0. The anatomical dot is 1-3 px from
  the game camera (4.3 deg lens, ~190 m out), so the pixel floors are what makes the eye visible at all.
  Pulled towards the camera along the view ray only (it stays on the eye on screen, the skull does not
  clip it).
- **Wisp** (head speed above `MIN_SPEED_MPS` 1.6, full at 4.5 m/s): a Catmull-Rom curve through the eye's
  recent positions (12 rows), five vertex columns across with alpha 0 at both edges (feathered), a thin
  body (half-width the larger of 1.4 dot radii, 3.5 % of its length, and 4 px) tapering to a point, alpha
  fading with age and along the length, flowing value noise on width, alpha and lateral offset
  (`FLICKER` 0.4 at `FLICKER_HZ` 9), the older part dragged downwind with a slight rise (`DRIFT_MPS` 0.5,
  one fixed `WIND`). Pulled `CLEAR_PER_SEPARATION` 1.5 eye separations towards the camera so it clears
  the near half of the skull it streams over.
- **Embers**: a spark every second sample along the wisp, twinkling on noise and drifting off it as it ages.

| Constant | Value | Meaning |
|---|---|---|
| `MAX_SAMPLES` / `FADE_S` | 12 / 0.3 s | past positions per eye, how long one is drawn |
| `MAX_LENGTH_M` | 1.6 m | longest wisp for eyes 0.35 m apart (deinonychus); scaled by eye separation within 0.5-2.2x |
| `MIN_SPEED_MPS` / `FULL_SPEED_MPS` / `STRENGTH_DECAY` | 1.6 / 4.5 m/s / 5 per s | where the wisp starts, where it is full, how fast it dies down |
| `RESET_JUMP_M` | 2.0 m | a bigger jump is a teleport: the buffer is dropped |
| `MAX_CAMERA_DISTANCE_M` | 600 m | plus a frustum check: off-screen animals build nothing |
| `ENERGY` | 2.2 | HDR level of the vertex colours |
| `MAX_VERTICES` | 1032 | worst case per creature per frame (asserted) |

Visibility is the eyeshine's: awake, not asleep, not dead, same night fraction.

## Data
No new file under `game/data/creatures/` (every `*.json` there is parsed as a species by
`Data._load_creatures`, so a knob file would log a malformed creature). Per-species overrides are an
optional `"trail": {...}` object **inside the existing `eyes` block**, same keys as the table above
(`fade_s`, `max_samples`, `min_speed_mps`, `full_speed_mps`, `max_length_m`, `flicker`, `flicker_hz`,
`drift_mps`, `taper`, `tip_pow`, `hot_head`, `width_per_radius`, `energy`, `max_distance_m`); every value
is clamped, so a typo cannot spin the buffer.

Eye points: the T. rex points were corrected on 2026-10-27 (they sat in the brow socket ~10 cm above and
ahead of the painted eyeball): `[±0.5119, 0.9485, 0.7624]`, measured with
`eyeglow_lab --species=tyrannosaurus --aim=958,348 --ray`. Deinonychus, velociraptor and utahraptor were
checked side and front and left as they were.

## Cost
20 creatures at full strength measure about 1.5 ms of GDScript tick work per frame on this Mac
(`t_eyetrails` prints it; the gate is 2 ms). Most of it is rebuilding the bloom and wisp every frame. Two
omni lights per glowing creature at night (no shadows).

## Tests
`game/tests/t_eyeglow.gd` (dots, night contrast, dead hides) and `game/tests/t_eyetrails.gd` (still head
draws nothing, speed grows length and alpha, fade-out after stopping, sample cap, flicker spread versus
`flicker: 0`, length cap at 12 m/s, day/dead/asleep hidden, distance cull stops rebuilding, 20-animal
cost). `t_eyetrails` also renders a look-pass with `-- --shot-dir=DIR` when run windowed: a night ground plane,
`WorldLighting` at midnight and the real `IsoCamera` (default zoom 14 m, 18 m for the T. rex), the animal
standing, running a curve across the screen and snapping round; it saves 800x450 crops around the eye.
Options: `--shot-species=a,b`, `--shot-zoom=<m>`.
