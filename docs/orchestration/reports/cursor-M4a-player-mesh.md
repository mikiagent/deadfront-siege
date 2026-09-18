# Cursor M4a — survivor player model and animation state machine

The playable survivor now uses the real rigged Meshy character and clip set in all default/player lab paths.

## What shipped
- Added reusable `RiggedModel` runtime in `scripts/core/rigged_model.gd` and moved clip merge/remap/facing/scale logic there so creature and player rigs share one path.
- Refit `CreatureView` + `Creature` to use `RiggedModel` animation playback when a species GLB exists, while keeping placeholder animation flow for no-GLB species.
- Replaced capsule/nose player visuals with `RiggedModel` + `PlayerAnim` nodes in `scenes/player/player.tscn`; `scenes/main.tscn` now instances that player scene instead of duplicating placeholder geometry.
- Wired survivor metadata loading from `data/characters/survivor.json` (`forward_axis`, `height_meters`) in `Player`.
- Added player rig sockets from skeleton bones (`RightHand`, `Hips`) via `BoneAttachment3D` + `Marker3D` anchors and exposed them for tool/mount alignment.
- Added `PlayerAnim` clip state machine (`idle`, walk/run locomotion split at 5.5 m/s, `hit_react`, `death`, `attack_*`, `roll`, `gather`, `knockdown`, `mount_idle`) with one-time `[player] missing clip <name>` fallback logging.
- Hooked visuals into gameplay: hunt auto-attacks and tackle now trigger player attack clips; roll and gather actions trigger player clips.
- Added screenshot capture path (`--shot=...`) and used lab auto-demo setup to capture evidence frames.

## Acceptance evidence

### Smoke
`tools/smoke.sh`:

```
[boot] Game autoload ready. smoke_test=true lab=- godot=4.7.1-stable (official)
[boot] main scene ready
[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day
SMOKE PASS
```

### Headless lab logs
Headless runs for `creature_lab`, `hunt_lab`, and `capture_lab` print survivor remap lines with zero missing tracks and no `[player] missing bone ...` lines:

```
[player] clip idle tracks=30 remapped=30 missing=0
[player] clip walk tracks=29 remapped=29 missing=0
[player] clip run tracks=28 remapped=28 missing=0
[player] clip attack_primary tracks=32 remapped=32 missing=0
[player] clip mount_idle tracks=36 remapped=36 missing=0
```

No `[player] missing clip ...` fallback lines are emitted with the current eleven survivor clips.

### Screenshots
- Hunt lab mid-fight: `docs/orchestration/reports/m4a-hunt-lab.png`
- Capture lab mounted on velociraptor: `docs/orchestration/reports/m4a-capture-lab-riding.png`

Scale uses each `MeshInstance3D` local AABB (survivor `char1` is 1.72 m). Including the importer's 0.01 node scale in the measured height over-scaled the mesh ~100×.

## Reproduce
```bash
tools/smoke.sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --quit-after 240 -- --lab=hunt_lab
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --quit-after 360 -- --lab=capture_lab
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=hunt_lab --shot=../docs/orchestration/reports/m4a-hunt-lab.png
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=capture_lab --shot=../docs/orchestration/reports/m4a-capture-lab-riding.png
```
