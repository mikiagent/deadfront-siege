# TRIKESADDLE: a saddle for the triceratops

Branch `claude/mmo-trikesaddle`, from `origin/claude/mmo-overhaul` 49ff065a. Not merged to canon. No credits spent.

## Why
After TRIKELAND landed, t_mounts failed: "triceratops has no saddle and is not in mounts_skip.json".
The triceratops has the mount role, and at 4.6 m it is far taller than the skip rule allows (back height x 1.6 must exceed the 1.78 m rider).

## What shipped
- `game/assets/creatures/triceratops/mount/saddle.glb` + `mount.json`, built with the shared builder (`tools/blender/saddles/build.sh triceratops`).
  - 7.5k tris, skinned to `Spine1` (seat, girth, stirrups) and `Neck1` (neck strap and leads).
  - `rider_in_mount` carries the 180 deg turn, the same as the T. rex howdah. The triceratops faces glTF -Z; the survivor faces +Z.
- `build_saddles.py` needed small changes, because it assumed the transplant rig (Torso/Shoulders/Neck, facing -Y in Blender):
  - new per-species config keys in `saddles.json`: `forward` ("+Y" turns the rig 180 deg for the build and back before binding), `shoulder_bone`, `neck_bone` and `torso_len_frac`.
    The torso-length minimum would have made the seat 2.6 m long on a 9 m animal.
  - the body mesh is picked by vertex count, so the importer's bone-shape Icosphere can never be measured by mistake.
  - Every other species' config is unchanged and was not rebuilt.
- Triceratops config: socket Spine1, seat between Hips and Chest at 0.55 (behind the frill), and a raised 22 cm cushion.
  - With the default 7 cm cushion the rider's legs sank 0.3 m into the broad back (boot_clear 0.40).
  - With the raised cushion the rider sits on the saddle and his feet are at it (boot_clear 0.07).
- `game/tests/t_mounts.gd` now accepts `Neck1` as the reins bone (Tripo/Opus rigs) as well as `Neck`.

## Shots (`docs/orchestration/reports/trikesaddle/`)
Taken with `equip_mount_lab --species=triceratops`, windowed off-screen at `--position 6000,3000`, self-quitting.
- `triceratops_side.png`, `triceratops_iso.png`: the survivor sits on his back behind the frill, facing forward, at the right scale, with his hands on the reins.
- Lab numbers: saddle_drift 0, rider_drift 0. The rider was steered to run and stopped to idle, then dismounted.

Left as is:
- The stirrups hang at the flank (x +-0.67 m), wider than the rider's feet. The builder places them from the body width.
- The neck strap sits under the frill and is hidden.

## Gates
PASS: t_mounts, t_saddles, t_dismount (13 species, triceratops included), t_trikeland, equip_mount_lab.
run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.
