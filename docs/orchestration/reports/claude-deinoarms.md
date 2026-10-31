# DEINOARMS: two hind legs, wings that move in every attack, and a smaller deinonychus

Branch `claude/mmo-deinoarms`, from `origin/claude/mmo-overhaul`, with canon merged in again before this report.
Pushed, not merged to canon.

What the owner said:
1. "the new deinonychus model looks good but make sure its arms/wings actually move during attacks"
2. "oh the legs in the model are messed up, 4 legs on the ground"
3. "deinonychus should be slightly smaller"

## Credits
- **Tripo: 50.** This was the one allowed retry, task `88864bcb-3323-4b5e-a096-a64529eb0a4f`. The balance was 1675 before and 1625 after.
- Meshy 0, Higgsfield 0. Codex images are free.

## 1. Four legs on the ground: what was wrong
- The v4 Tripo mesh really had **four hind legs**.
  - On each side there were two leg columns, 0.5 m apart. They joined into one thigh and one fused blob of feet (`deinoarms/v4_four_legs.jpg`).
  - The cause was the Codex side view I fed Tripo: it showed the legs in a stride, one forward and one back. Tripo combined that with the front view and built a leg for each.
  - It was not the arms or the wings: in idle, walk and run only hind-foot skin came within 0.35 m of the floor.
- **Blender first.** The two legs on each side share one fused foot mesh: a cut from the rear leg's shin flood-fills straight into the front leg (checked at three cut heights). It cannot be cut and re-skinned cleanly.
- **Retry spent.** Codex redrew the side view with the hind legs side by side (one leg column) and the wings folded high. It then drew the front and back from that side view (`deinoarms/tripo_inputs_v5.jpg`).
- The v5 mesh has two legs (`deinoarms/v5_two_legs.jpg`, `tripo_mesh_v5.jpg`). The whole build was rerun on it with `tools/gait/build_deinonychus.sh`.

## 2. Arms and wings that read
**Measured on the deformed skin, before the fix (v4 as on canon):**
- The wing tips moved 0.7-1.3 m against the chest. The front edge of the wings, where the hands are, moved only 0.24-0.36 m.
- In the attacks, the forward arm swing pushed the wing tips down and backward, toward the ground. They stayed against the flank in side views.
- So the bone angles (62-106 deg) looked big, but most of the wing hardly moved and nothing spread out.

**v5 problem:** the wings are fused into the flank skin, so there are no wing shells to skin to the arms.

**What changed:**
- **New `deino_wing_shell.py`.**
  - It copies the folded-wing area of each flank as its own shell, pushed 4 mm out, and skins it to the arm. The shoulder edge goes on the upper arm and the tip on the forearm.
  - The flank underneath keeps its feathers and its torso weights, so nothing tears open when the wing lifts.
- **The attacks swing the arms 1.5x**, all on the upper arm (`raptor_overlay.py --arm-gain 1.5 --shoulder 0`).
- **New `deino_wings.py`:**
  - On the wind-up and through the hit of the bite, all three chomps, the pounce and the sickle slash, each wing spreads 70 deg out and 25 deg up. The slash uses 90 deg and 65 deg, because its arms are already raised.
  - It picks whichever direction carries the wing away from the body. In the slash, the first attempt had pushed the wings into the chest.
  - In every standing clip it lifts the wing whenever it would come within about 0.65 m of the floor.
- **After the fix, on the skinned mesh as Godot draws it (`t_sp_deinonychus`):**

  | Attack | Wing tip travel L / R (m) | Hand claw travel L / R (m) |
  |---|---|---|
  | Bite | 1.80 / 1.80 | 0.65 / 0.77 |
  | Combo | 1.22 / 1.26 | 0.71 / 0.82 |
  | Pounce | 1.87 / 1.86 | 0.78 / 0.79 |
  | Slash | 1.24 / 1.26 (Blender gate) | 1.16 / 1.16 |

  The claws cannot reach 1 m. They sit at the end of the hand bone, 0.45 m from the shoulder, so a full swing is 0.9 m. Their gate is 0.6 m (DN8).
- **Shots** (`deinoarms/attacks_windup_hit_side.jpg` and `_tq.jpg`):
  - the wind-up and hit of the bite, the three chomps, the pounce and the slash;
  - off-screen windowed lab runs, `--lab=deinonychus_lab --close`.
- **Still small in shots:** from the side the spread reads less than from the front three-quarter view. The wings are dark against a brown body, so a front or overhead camera shows them best.

## 3. Smaller (DN7)
- `height_meters` 2.87 -> **2.55** (-11 %, `# ASSUMPTION` in the JSON with both values).
  - It is 5.45 m long on screen.
  - Its head is about 2.55 m up, next to the 1.78 m survivor.
  - Bulk 6.0 x 2.55 = 15.3 keeps it a hop/strafe mix. At 15 or under, HOPSTRAFE would turn it into a hopper.
- `attack_range` scaled with it: 2.6 -> 2.3.
- Hitbox rows were recalibrated at the new size:

  | Move | Calibrated part radii (m) |
  |---|---|
  | Bite | Jaw 0.56, ClawTip.L 0.65, ClawTip.R 0.68 |
  | Combo | Jaw 0.66, ClawTip.L 1.01, ClawTip.R 0.97 |
  | Pounce | ClawTip.L 0.97, ClawTip.R 1.00 |

  The slash foot no longer needs a calibrated radius. No combo or pounce part could be calibrated below about 0.97 m except the combo's Jaw.
- The saddle was rebuilt (rider root at 0.28 of the mesh height). t_mounts, t_saddles and t_dismount pass.
- `natural_speeds` were rescaled. They are planned stride / cycle x 5.46, and walk and run match `bake_clip_speeds.py`.
- The eye-glow points were refitted.
- The ragdoll `lie_frac` override (DN6) was dropped. The smaller body settles at 39 % under the default 50 %.

## New checks
- `tools/gait/check_deinonychus.py` (Blender, posed skin):
  - **wings and claws:** in each attack the wing tip moves at least 1.0 m and the ClawTip at least 0.6 m against the chest;
  - **biped:** in every non-lying clip, nothing but hind-leg skin comes within 0.25 m of the floor;
  - **footprint:** at rest, the skin on the floor per side spans at most 0.35 x height, which is one foot. v5 measures 0.62 m against a 0.89 m limit; v4's two feet were about 1.15 m at this height.
  - The stretch gate is 15, for the v5 hip-socket edge: 13.3x in the slash, 14.5x in the fall.
- `t_sp_deinonychus` measures the same things on the skinned mesh in Godot: skin vertices computed from the skeleton pose and the skin binds.
  - The wing tips and claws travel in the bite, the combo, the pounce and the slash.
  - Nothing but the hind legs reaches 0.25 m in 13 standing clips.
  - It is 2.55 m tall.

## Gates (after the last canon merge)
- `check_deinonychus.py --height 2.55`: DEINONYCHUS_CHECK PASS. `audit_gaits --gate`: GATE PASS.
- PASS: t_sp_deinonychus, t_hitboxes, t_mounts, t_saddles, t_dismount, t_noboxes, t_combat, t_data, t_tactical, t_hopstrafe, t_eyeglow, t_eyetrails, t_critspots, t_boneparts, t_labspawn, t_godlab, t_bigreach, t_ai, t_raptorfeel, t_raptorflank, t_sp_raptor, t_coelomoves.
- `run_all` `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.
- t_canim was skipped as asked.
- t_ragdoll fails on the velociraptor slope death only, the same as on canon; every deinonychus case passes. t_turnrate fails on the T. rex side bite, also the same as on canon.

## How to test
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, spawn Deinonychus and look at it standing: two legs, wings folded on the flanks.
2. Stand close for the bite and the 3-chomp combo: on each wind-up the barred wings spread out and up, then rake in on the bite.
3. Step back for the pounce: the wings spread in the air.
4. The sickle slash: the wings lift high for balance under the red ring.
5. H shows the jaw and claw hit spheres. It is smaller than before: its head is just above the survivor's.

## For the next agent
- The disk was full (425 MB free) partway through. I removed only my own build temp folders, and `build_deinonychus.sh` now deletes its temp folder when it finishes. The disk later had 79 GB free.
- Some PNGs in my scratchpad vanished during the low-disk period; the v5 input views survive as `tripo_inputs_v5.jpg`.
- The colour-morph hook is unchanged (DN5).
