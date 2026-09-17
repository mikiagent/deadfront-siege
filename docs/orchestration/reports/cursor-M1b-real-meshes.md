# Cursor M1b — real creature meshes

Clip tracks now remap onto `View/Mesh/.../Skeleton3D`. Facing/scale follow SCHEMA §3. JSON archetypes were **not** renamed (Codex owns those files); both `pack_raptor` / `pack_flanker` / `apex_raptor` and SCHEMA `raptor_pack` map to `RaptorPackBrain`.

## Clip remap (headless `--lab=creature_lab`)

Zero `missing bone` lines. Zero AABB warnings.

Velociraptor / deinonychus (one spawn each shown):

```
[creature] clip idle tracks=29 remapped=29 missing=0
[creature] clip walk tracks=31 remapped=31 missing=0
[creature] clip run tracks=31 remapped=31 missing=0
[creature] clip attack_primary tracks=31 remapped=31 missing=0
[creature] clip attack_heavy tracks=33 remapped=33 missing=0
[creature] clip death tracks=35 remapped=35 missing=0
```

Utahraptor: same 29/31/33/35 remap on idle–death. A leftover `anim/knockdown.glb` uses a different skeleton (`missing=12`); that file is discarded and knockdown/hit_react fall back from `death`.

```
[creature] clip knockdown tracks=15 remapped=3 missing=12
[creature] clip death tracks=35 remapped=35 missing=0
```

Protoceratops (Gobkit stand-in, 15 tracks, including its own knockdown):

```
[creature] clip idle tracks=15 remapped=15 missing=0
[creature] clip walk tracks=15 remapped=15 missing=0
[creature] clip run tracks=15 remapped=15 missing=0
[creature] clip attack_primary tracks=15 remapped=15 missing=0
[creature] clip attack_heavy tracks=15 remapped=15 missing=0
[creature] clip knockdown tracks=15 remapped=15 missing=0
[creature] clip death tracks=15 remapped=15 missing=0
```

Fallbacks: `hit_react` = first 40% of knockdown (or death if knockdown was discarded); `alert` = idle; `run` time scale 1.6 from `anim_events.json`. Idle/walk/run loop; other clips hold last frame.

## Facing and scale
- `pipeline.forward_axis` (default `-Z`) yaws `Mesh` so that axis is Godot `-Z`. Current JSONs are `+Z` → 180° on Mesh. View no longer has a blanket 180°; placeholders keep it so they still face the same way.
- Uniform scale = `height_meters / measured AABB height` (AABB preferred over stale `source_height_m` on transplanted GLBs). Mount socket uses `height_meters`.
- Creature `look_at` so Godot `-Z` faces movement.

## Input / mobile
- World targeting uses the `tap` action, ignored over Controls and TouchControls buttons.
- `bandage` / `hunt_chase` already in `input_setup.gd`; touch buttons **AID** and **HOLD** added.
- `Game.max_creatures_per_island = 24` (`# ASSUMPTION:`).

## Screenshot
`screencapture -x docs/orchestration/reports/m1b-creature-lab.png` failed here (`could not create image from display`). The lab was launched windowed (`Godot --path game -- --lab=creature_lab`). Please eyeball size (velo ~0.8 m / knee-high, utahraptor ~2 m / taller than the capsule) and keys 1/2/4/8 before M4a.

## Smoke
`tools/smoke.sh` → `SMOKE PASS`.

## Reproduce
```
tools/smoke.sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=creature_lab
```
Keys 1 idle, 2 walk, 4 attack_primary, 8 death.
