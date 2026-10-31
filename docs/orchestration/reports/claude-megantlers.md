# MEGANTLERS: a Tripo antler rack for the megaloceros stag

Branch `claude/mmo-megantlers`. It started from `origin/claude/mmo-megajoust`, and canon was merged in twice: before and after megajoust landed (f1b73788e). Not merged to canon.

The owner, verbatim: "is there any possibility you can fix the antlers on the male megaloceros so it doesn't look like it was made in blender? Like honestly it might be worth getting a new model from tripo specifically with the antlers". He approved Tripo credits for it.

## Credits
- **Tripo 30.** The balance went from 1705 to 1675. That was one v3.1-20260211 image-to-model task with texture + PBR and face_limit 20000. There was no retry.
  - Task id: `48c4db1d-c6b8-40fb-a881-4cff854d7c78`, recorded in `megaloceros.json` under `pipeline.tripo.stag_antlers`.
  - I called the V3 API directly with the key in `~/.tripo/config.json`. The key was never printed.
- Codex (free): one reference image, `game/assets/creatures/megaloceros/ref/stag_antlers_codex.png`. It shows the pair on a small bare skull cap, in a near-front three-quarter view on white.
  - Codex worked from the owner's stag sheet.
  - The image asks for a thick palmate shovel, long tines, burrs, and bone texture with ivory tips.
- Meshy 0.

## What changed
Only the stag's antler mesh and its two lying clips changed. The body, the rig, the other 17 clips, the doe and the saddles are unchanged.

- **`tools/gait/megaloceros/antler_prep.py`** turns the Tripo rack into `tools/gait/megaloceros/antlers_tripo.glb`, which is committed (800 KB).
  - It turns the rack to the rig's frame and joins the UV-seam duplicates.
  - It cuts the skull cap off with a plane under each burr and keeps the two antlers.
  - It records each burr centre.
  - It turns metallic off and shrinks the textures to 1024.
- **`build_rig.py`**: `tripo_antlers()` replaces the procedural `build_antler`. The settings are in `stag.json` under `antlers`.
  - Each side leans back 15 deg (`pitch_deg`). The left palm also drops 12 deg (`roll_deg [12, 0]`). The bend only starts along the beam (`bend_raw`), so each burr keeps the seat Tripo gave it.
  - The pair is scaled to **7.6 m** tip to tip, which is megajoust's span from the owner-approved sheet. The top is 6.0 m.
  - The burrs sit on the skull at `seat_m` (±0.27, -1.62, 3.74), over the Tripo body's pedicle stubs.
  - **Pedicles:** each cut rim is extruded into the skull to `pedicle_m` and closed. These faces use the stag's own hide material and a crown fur texel, so the bone grows out of fur.
  - **Bake:** the burr bases are baked toward the hide colour around the seat over `fade_m` 0.15 m. The bake goes through emission into `megaloceros_antler` (1024).
  - The rack is skinned 100 % to `Head`, as a separate `Antlers` mesh as before.
- **`clips.py`**: stag `death` and `knockdown` only. Megarun's run clips were not touched.
  - Before: rolled fully on its side, one antler went 1.8 m under the floor in death and 2.1 m in knockdown. The old Blender rack did the same.
  - No head turn alone clears a 7.6 m rack. A seeded random search (`LIE_FIX`) now tries body roll, neck pitch and yaw, head roll and head pitch. It scores every exported frame from the roll's start to the end. It keeps the most rolled pose, then the smallest head change, with no antler point under the floor and none in the body.
  - Result: death rolls -46 deg with the head turned so the rack rests on one antler's tips. Knockdown rolls -70 deg.
  - Both clips go through `tools/gait/ground_clip.py` as before. The doe's code path is unchanged.
- **`check_antlers.py`** (new) checks the rack against the hide and the floor in every stag clip, on the clip's own keys. It ends with "ANTLERS PASS".
  - Anything already in the head at rest is skipped (burr rims, pedicles, the beam bases within 1.1 m).
  - Contact with Head-weighted skin is skipped (ears, brow).
  - It fails on any point more than 0.10 m inside the body or 2 cm under the floor.
  - `build.sh` now runs it at the end and fails the build if it fails.
- **`hitboxes.json`**: the stag's calibrated Head radii are re-fit to the new tips (see Gates).
- **`megaloceros.json`**: the look's span is now 7.6 m, and the build note and Tripo ids are updated.
- **`megantlers_lab`** (`game/scripts/dev/megantlers_lab.gd` + scene) is for review shots only.

## Check results (`check_antlers.py`, all 19 stag clips)
| | Old Blender rack | New Tripo rack |
|---|---|---|
| idle, walk, run, run_turn_left/right, strafe, charge, charge_crouch, alert, attacks, kick, hit_react, sleep, feed | clear | clear |
| death | 12 points up to 0.48 m in the body; antler 1.82 m under the floor | clear; lowest antler point +0.41 m |
| knockdown | antler 2.14 m under the floor | clear; +0.17 m |

## Shots (`docs/orchestration/reports/megantlers/`)
The shots come from off-screen windowed runs (`--position 6000,3000`, self-quitting, `-- --skip-charcreate --lab=megantlers_lab`). Each shot has the old rack on the left, the new one on the right, and the survivor between them.
- `rest_{front,side,tq}.png`
- `charge_{side,tq,front}.png`
- `death_{front,tq,side}.png`: the old stag plays its old death clip, and its antler sinks into the floor. The new one rests on its tips.

The old rack renders pale in these shots. The lab moves the old mesh onto a current stag, and its texture does not follow. The shapes are what to compare.

## Gates
These were run after the second canon merge (f8967dc0a), from an imported worktree with its own user dir (override.cfg).
- `t_megajoust` **PASS**
- `t_sp_megaloceros` **PASS**
- `t_hitboxes` **PASS**:
  - The hurt capsules auto-fit the new skinned rack.
  - `--calibrate` asked for 2.05-2.06 m on the stag's Head rows (charge, attack_primary, attack_heavy) against the 2.00-2.02 from megajoust. `hitboxes.json` now carries 2.06, 2.05 and 2.05.
  - Re-run after that change: PASS.
- `t_canim` **PASS**
- `t_noboxes` **PASS**
- `run_all.gd`: [tests] **PASS**
- `tools/smoke.sh --no-import`: **SMOKE PASS**
- `check_antlers.py`: **ANTLERS PASS**, all 19 stag clips.

## Left as is / for the next agent
- **Mesh size.** The rack is 11k vertices with three textures, and the stag GLB grew from 6.4 to 8.0 MB. Decimate it if mobile memory complains.
- **Asymmetry.** The Tripo rack is asymmetric, like a real one: the left palm is bigger and higher. I kept that.
- **Ears.** The ears are half-weighted to Neck2. When the head drops (feed, attack), an ear swings into a beam base by up to ~0.2 m. This is a body weighting issue, so the check skips head skin. Weighting the ears 100 % to Head would fix it.
- **Death pose.** In death the stag props its head on the rack instead of lying flat. That is the only way a 7.6 m rack clears both the floor and the body.
- **Rebuilds.** `build.sh` now runs `LIE_FIX` for the stag, which adds ~3.5 min. Megarun's run clips will rebuild unchanged by this branch, but `build.sh` rebuilds everything. Merge megarun and this branch with care: keep megarun's `run*.glb` and this branch's `megaloceros.glb`, `death.glb` and `knockdown.glb`.
- **Footprint.** The antlers still count toward `Creature.footprint()`. The span is the same as megajoust's, 7.6 m.
