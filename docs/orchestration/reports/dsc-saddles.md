# SADDLES: riding saddles for every rideable tame (dsc)

Agent: dsc. Branch: `claude/mmo-saddles` (worktree `.claude/worktrees/mmo-saddles`). No paid generation (0
credits), no creature mesh/rig/clip changes, T. rex howdah untouched.

## What shipped

**Seven new saddles** in the T. rex howdah's style family, sized to the animal: leather seat with pad,
skirts, pommel horn and bone cantle; girth strap + iron buckles; stirrups (iron bar, leather, tread/sides/
yoke); hand reins from the pommel to the fists; and a neck strap with leads to the pommel. All skinned to the
species' own skeleton (seat/straps/girth/stirrups 100 % to the socket bone, neck strap and leads to `Neck`,
blending to the socket at the pommel), so the saddle follows every clip.

| species | saddle tris | socket | back top (m) | rider hips above ground (m) | seat top (m) | rider root in model (glTF Y, m) |
|---|---|---|---|---|---|---|
| protoceratops | 8582 | Torso | 1.38 | 1.53 | 1.43 | 0.95 |
| megaloceros | 7270 | Torso | 1.36 | 1.53 | 1.43 | 0.95 |
| gallimimus | 7140 | Torso | 2.97 | 3.13 | 3.03 | 2.55 |
| velociraptor | 7244 | Torso | 1.94 | 2.08 | 1.98 | 1.50 |
| utahraptor | 7342 | Torso | 3.29 | 3.45 | 3.35 | 2.87 |
| coelophysis | 7260 | Torso | 1.62 | 1.76 | 1.66 | 1.18 |
| deinonychus | 7738 | Torso | 3.03 | 3.18 | 3.08 | 2.60 |

Heights are at each species' `height_meters` (the in-game scale). "back top" and "seat top" come from the
builder's raycast of the game GLB; the rider root is `rider_in_mount` in glTF model space, and the hips are
0.581 m above it in the `mount_idle` pose. Every species also gets `mount/saddle.glb` + `mount/mount.json`
with `socket`, `saddle`, `rider_offset`, `rider_in_mount`, `seat`, `stirrups`, `scale`,
`hips_above_socket_m`, `seat_above_socket_m`.

deinonychus was not in the task's list but is a mount-role species with a game model, so it got one too
(the test checks every mount species with a GLB).

**Too small, left on the hips-socket fallback** (measured, no data changed):

| species | back height (m) | limit (rider 1.78 / 1.6) | verdict |
|---|---|---|---|
| zebraceratops | 0.86 | 1.376 | rider is 1.3x the limit: `game/data/mounts_skip.json` |

**Code**
- `creature_view.rider_transform()` now orthonormalises the basis. `rider_in_mount` is in model space and the
  game scales each GLB to `height_meters` (K = 1.1..6.0), so without this the rider came out K times too big
  for every species except the T. rex (K = 1). The translation is untouched, so the rider still lands on the
  seat. The hips-socket fallback is unchanged for species without `mount/mount.json`.
- `game/scripts/dev/equip_mount_lab.gd`: `--species=<id>`, `--all-mounts`, `--shot-dir=<dir>`. For each
  species it spawns the pet as a pet record, mounts, plays idle/walk/run, and checks: saddle path taken,
  `mount_idle` playing, saddle glued to the socket bone (drift < 3 cm), rider rigid on that bone, hips
  `hips_above_socket_m` above the socket (+-8 cm, i.e. on the seat and not sunk into or floating over the
  body), boots clear of the hide, dismount restores the rig and removes the saddle. Prints
  `[mountlab] PASS species=<id>` and `[mountlab] PASS all mounts`; exit 1 on failure. Shots side + iso per
  species.
- `game/tests/t_mounts.gd`: every mount-role species with a GLB either has saddle.glb + mount.json with all
  keys (socket must be a bone of the GLB and of the saddle's own skeleton, rider_offset/rider_in_mount 16
  floats, tri count 400..20000, Neck present for the reins) or is in `mounts_skip.json` with its measured
  numbers and no saddle. It also checks the skip rule itself and that the T. rex still has its saddle.
- `tools/blender/saddles/`: `build_saddles.py` (one shared builder, raycast-measured, `--preview=` renders
  side/iso/front workbench shots), `saddles.json` (per-species sizes), `build.sh <species>|--all` (build +
  `mount_to_model_space.py`), and a copy of `mount_to_model_space.py`.

## How it was made
The builder imports the game's own GLB, measures the hide (top-down rays for the seat surface, rays outward
from the body axis for the girth and neck cross-sections, so no leg or far side is picked up), places the
rider from the survivor's own seated pose (measured on `mount_idle`: hips 0.581 m above the armature root,
feet 0.098, hands (+-0.203, -0.091, 0.846)), then builds and skins the saddle. `rider_offset` is written in
Blender's imported bone frame and converted by `mount_to_model_space.py` against the same game GLB, exactly
as the T. rex howdah was.

# ASSUMPTION: these models face +Z in glTF (i.e. -Y in Blender after the import) like the survivor's own
forward, so no 180 deg turn is baked into the rider root (the howdah has one because the T. rex faces -Z).
# ASSUMPTION: the socket is `Torso` for every transplanted donor rig (they all share one skeleton: Hips ->
Torso -> Shoulders -> Neck -> Head); the T. rex keeps Spine2.

## Verification
- `equip_mount_lab --all-mounts`: `[mountlab] PASS species=…` for tyrannosaurus, deinonychus,
  protoceratops, megaloceros, coelophysis, utahraptor, gallimimus, velociraptor; zebraceratops on the
  fallback; `[mountlab] PASS all mounts`. Saddle drift 0.0000 m, rider drift 0.0000 m for every saddled
  species; boot clearance 0.00-0.08 m.
- `t_mounts.gd` -> `PASS t_mounts` (8 saddled, 1 skipped).
- `tools/smoke.sh --no-import` -> `SMOKE PASS`.
- `verify_saddles.sh` -> `VERIFY PASS: 6 saddled species` (note: run it with `HOME` pointed at the gslot
  scratch home; a bare run cannot create `user://logs` in this sandbox and Godot exits 134 before smoke).

Shots (verify run): `…/scratchpad/dsc/saddles-out/shots/<species>_{side,iso}.png` for every species above.
Blender previews: `/tmp/saddleprev/<species>_{side,iso,front}.png` (rebuild with `--preview=<dir>`).

## For the next agent
- The T. rex `mount.json` predates the `seat`/`hips_above_socket_m` keys; `t_mounts.gd` exempts it because the
  howdah must not be edited. If it ever is, add those two numbers.
- `--all-mounts` rides deinonychus too; if the roster grows, a new mount species with a GLB and no saddle will
  fail `t_mounts.gd` until it is built (`tools/blender/saddles/build.sh <id>`) or measured into the skip list.
- Lore/mechanics untouched; the PRD is silent on saddle appearance for these species, so the howdah's
  materials and proportions were reused.
