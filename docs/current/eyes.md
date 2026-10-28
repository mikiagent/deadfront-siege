# Glowing eyes and their motion trail

Owner: `game/scripts/creatures/creature_eyes.gd` (eyeshine dots) and
`game/scripts/creatures/eye_trail.gd` (`EyeTrail`, the flame ribbon behind them). Per-species eye points
live in `game/data/creatures/<id>.json` under `"eyes": {bone, points, radius, color}` and are owned by the
art thread: the code never writes them.

## Eyeshine (the dots)
Two small unshaded HDR dots on the Head bone, one per authored `points` entry, pushed 5 mm out of the skull
(`SURFACE_PUSH_M`) and capped to 0.6 % of the animal's height (6 mm .. 25 mm). Brightness is global: the
shared per-colour material is painted from `WorldLighting.night` (`NIGHT_ENERGY` 20 at night, a
`day_fraction` 0.01 glint by day). The dots hide when the animal is dead or in the `sleep` brain state.
Six species carry an `eyes` block: tyrannosaurus, utahraptor, deinonychus, velociraptor, coelophysis,
compsognathus.

## The trail (flame in the wind)
`EyeTrail` is one `MeshInstance3D` per eyed creature holding **one ImmediateMesh with one surface for both
eyes**, so a trail costs one draw call and one mesh. It is additive, unshaded, depth-write-off, casts no
shadow, and its vertices are world positions (`top_level`), which is what lets the ribbon lag behind the
head instead of riding the bone.

Each frame the trail records the eye dots' positions into a ring buffer and redraws the streak:
`t` runs 1 at the tail to 0 at the head; width tapers (`TAPER` 0.16 of the head width at the tip), alpha
falls faster than width (`TIP_POW` 1.8), the head whitens (`HOT_HEAD` 0.30), the tail drifts up and
sideways with age (`DRIFT_MPS` 0.55) and both width and alpha wobble with time and along the streak
(`FLICKER` 0.45 at `FLICKER_HZ` 13, two sines, no noise object).

| Constant (in `eye_trail.gd`) | Value | Meaning |
|---|---|---|
| `MAX_SAMPLES` | 12 | past positions kept per eye |
| `FADE_S` | 0.22 s | how long a sample is drawn (owner asked 0.15-0.3) |
| `SAMPLE_DT` / `MIN_STEP_M` / `FORCE_STEP_M` | 0.02 s / 4 mm / 35 mm | sample cadence, dead zone, instant sample on a lunge |
| `MIN_SPEED_MPS` / `FULL_SPEED_MPS` | 0.9 / 3.2 m/s | head speed where the trail starts and where it is at full strength |
| `MAX_LENGTH_M` | 0.9 m | longest streak, whatever the speed |
| `RESET_JUMP_M` | 2.0 m | a bigger jump is a teleport: the buffer is dropped, never smeared |
| `MAX_CAMERA_DISTANCE_M` | 55 m | beyond this the trail is not built at all (the iso camera is 40 m out) |
| `WIDTH_PER_RADIUS` / `ENERGY` | 1.9 / 2.2 | streak width per eye radius, brightness against the dot |
| `MIN_GLOW` | 0.02 | below this eyeshine fraction (day) no ribbon exists |

Visibility is exactly the eyeshine's: awake, not asleep, not dead, and the same night fraction, so a trail
never hangs where no eye glows. While hidden the trail drops its history and rebuilds nothing; it follows
the camera's distance, not the player's.

## Data
No new file under `game/data/creatures/` (every `*.json` there is parsed as a species by
`Data._load_creatures`, so a knob file would log a malformed creature). Per-species overrides are an
optional `"trail": {...}` object **inside the existing `eyes` block**, same keys as the table above
(`fade_s`, `max_samples`, `min_speed_mps`, `full_speed_mps`, `max_length_m`, `flicker`, `flicker_hz`,
`drift_mps`, `taper`, `tip_pow`, `hot_head`, `width_per_radius`, `energy`, `max_distance_m`); every value
is clamped, so a typo cannot spin the buffer.

## Cost
20 ribbons at full strength measure about 0.04-0.05 ms of tick work per frame on this machine
(`t_eyetrails` prints the number). Worst case geometry is 2 x 13 points x 6 vertices per creature.

## Tests
`game/tests/t_eyeglow.gd` (dots, night contrast, dead hides) and `game/tests/t_eyetrails.gd` (still head
draws nothing, speed grows length and alpha, fade-out after stopping, sample cap, flicker spread versus
`flicker: 0`, length cap at 12 m/s, day/dead/asleep hidden, distance cull stops rebuilding, 20-animal
cost). `t_eyetrails` also renders a look-pass with `-- --shot-dir=DIR` when run windowed.
