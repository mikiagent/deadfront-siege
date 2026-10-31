# SP-GALLIMIMUS: the gallimimus rebuilt from the owner's sheet

Owner (verbatim): "Gallimimus is fast but the model isn't great, animations aren't great and its behavior sucks. Animals that run away from you should get territorial and attack you if you chase them."

Branch `claude/mmo-sp-gallimimus`, cut from `origin/claude/mmo-overhaul` 1066e9c9. Canon a0cc474d (hopstrafe, spinosaurus, allosaurus, megatherium, knockroot and others) is merged in. Pushed, not merged to canon. This is a replacement: the id, the stats, the spawn rows (desert_35 gathering/working/crater, desert_50 gathering), taming and the saddle role are unchanged.

## Credits
**Tripo: 50.** One P1 multiview generation, no retry. Balance went from 1805 to 1755. No Meshy, no Tripo rig, anim or retexture. Codex drew one image (free).
- Task `e0cba9ee-23e6-4fe0-8b93-2899cffb2d5e`, called on the V3 API directly with the key in `~/.tripo/config.json` (never printed).
- Inputs (`game/assets/creatures/gallimimus/ref/gallimimus_view_*.png`, row in `sp-gallimimus/tripo_inputs.jpg`):
  - front and back are cropped from the owner's sheet;
  - left is a Codex neutral-stance side view drawn from the sheet (the sheet's side view is mid-stride with one foot lifted);
  - right is the left view mirrored.
- Result: it matches the sheet. Tan-brown hide, teal stripes and dark mottling on the neck, back and tail, a pale belly, the open toothless beak, slim three-clawed arms tucked, long legs.
- The source GLB is `work/gallimimus_tripo_v1.glb` (gitignored; the task id re-downloads it).

## Model and rig (rebuild: `tools/gait/build_gallimimus.sh`, about 35 s)
- `tools/gait/rig_biped.py` with `tools/gait/gallimimus_rig.json` (joints read off ortho renders). Three small opt-in additions; the other species are unchanged:
  - an 8th spine point adds **Neck3**, so the long neck bends in three places;
  - `foot_drop`: Tripo left the left foot 1.2 cm off the floor, so its skin is lowered with a fade;
  - `leg_top_z`: leg weight fades out above the hips. Before this, a 25x-stretched spike of belly and back skin rode the thigh in the run.
- Jaw: `add_jaw.py --open --pivot 0.035 0.6 --split -12 --close 36`.
  - The sheet's beak gapes about 30 deg. The bind pose shuts it, leaving a few degrees parted, and the Jaw bone carries the whole lower beak, so it opens and closes cleanly.
  - `--split -12` removed a sliver that stretched off the upper beak tip.
- Size kept: 3.8 m to the head top, 5.9 m long. The survivor comes to its chest.

## Clips (20)
| clip | what |
|---|---|
| walk, run, charge, strafe_left/right, walk_back | `make_gait.py` + `tools/gait/gallimimus.json`. A long light stride. The run is flat and fast (9.4 m/s natural), with the neck stretched forward and the tail level. |
| attack_primary | **Beak peck** (1.0 s, hit 0.42). The neck cocks into an S, then reaches forward and down. The beak hits her chest nose-first. A new beak solver (FABRIK on the three neck joints, then the head aimed down 35 deg) puts the tip on her spot. |
| attack_heavy | **Spring-and-rake kick** (1.42 s, hit 0.72). The right leg is hauled 1.8 m up with the knee forward and held trembling through the windup hold (the telegraph). Then it snaps forward through her at 10 m/s and rakes back to the ground. The arms fling back for balance. |
| bite_combo | **Peck-peck-kick** (2.75 s, on the shared fracs). A peck to each side on 0.092 and 0.338. Then it rears with the leg cocked (the tell, 0.5-0.667, held to 0.76) and kicks on 0.815. |
| alert | **Threat display**, played when it turns on a chaser. It draws itself up tall, gapes the beak in a shaking hiss, flings the arms out, raises and lashes the tail, stamps, and jabs the head. |
| hop_back, leap_back, dodge_left/right | Bounds in place. It crouches, tucks the feet in the air and lands with a squash; the dodges bank. The game carries the body. |
| idle, hit_react, feed, knockdown, death, sleep | `make_galli_moves.py`. The idle bobs and scans the neck. Feed pecks at the ground. Sleep sits on its hocks with the neck laid forward. |

All one-shots come from the new `tools/gait/make_galli_moves.py`, which reuses make_pachy_moves' IK-planted feet and adds the beak solver. Every clip then goes through `ground_clip.py`. `natural_speeds.gallimimus` was re-baked (walk 2.58, run 9.41 m/s), and only that row was spliced in.

## Behaviour and moves (data, plus one opt-in brain key; # ASSUMPTION GM1-GM5 in the Open Questions)
- **Skittish prey that turns on a chaser.**
  - It runs from the first threat. A survivor who doesn't follow is left alone, and it goes back to grazing.
  - The old flee-once `territorial` block is gone. It turned on players who had never chased it.
  - Chased, `brain_cornered.gd` turns it: 18 m radius, 1.5 s of pursuit or 10 m covered, or a hit. It plays the hissing display and fights for 14 s. Under 30 % HP it runs again.
- **Why a brain change was needed.** The gallimimus flees at about 15-18 m/s, so every chase ended in one burst and the pressure reset between flights; it never turned. New opt-in key `cornered.carry_s` (6 s, gallimimus only): pressure and metres carry over between its flights while you keep catching up. In the test it turns about 4 s into a 7 m/s chase. Other species are unaffected, since the default is 0.
- **Moves** (`tactics`, base pack_flanker):
  - point blank: kick, then combo, then peck;
  - signature **dodge-and-sprint**: a side bound, then a sprint in to the peck or the combo (`strafe_x -> charge`, `strafe_x -> combo`).
  - `reposition: "hop"`: it circles in bounds and never strafe-walks (HOPSTRAFE had set it to mixed). Its bounds are a body length, so they are long. I updated `t_hopstrafe` to match.
- **Hits use the hitboxes system** (`hitboxes.json` gallimimus row):
  - peck: a 0.55 m capsule along the Head bone (the beak) plus the Jaw;
  - kick: a Toe.R capsule plus Metatarsal.R;
  - combo: both sets. The combo's toe radius is calibrated to 0.7, because a small animal (genetic size 0.9) kicks 0.2 m short at the 3.1 m contact reach.
  - A peck at a survivor behind it misses.
- **Knock tier: light.** The kick shoves her 1.4 m with a 0.6 s stagger. Its force is 1.8, under PlayerKnock's knockdown threshold of 2.0. It also puts **Winded** on her (3 s; `status_applied: winded`, limited to attack_heavy by `pipeline.status_clips`). It never knocks her down; the old `knockdown` token is gone. Feet stay planted on hit (PlantedFlinch is unchanged and the clips pass).
- **Saddle** rebuilt on the new rig (`saddles.json`: socket Spine1, shoulder Chest, neck Neck1). t_mounts and t_saddles pass.

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, or point `tools/fight_lab.command` at this worktree. GOD is on (G toggles it).
2. Press SPAWN, pick **Gallimimus**, any nature, then SPAWN. NEXT (T) also cycles to it.
3. Walk up to it: it bolts. Stand still and it leaves you alone.
4. Chase it, sprinting after it each time it stops. After about 4 s it wheels round into the hissing display, then attacks:
   - beak pecks, with the neck whipping down;
   - the kick, where the leg is held high and trembling (dodge then); a hit staggers and winds you;
   - side bounds, then a sprint back in, or peck-peck-kick.
5. Hit it down under 30 % HP and it runs again. F3 prints each move ([ai] lines); H shows the hitboxes.

## Shots (`docs/orchestration/reports/sp-gallimimus/`)
These come from self-quitting windowed lab runs off-screen (`--position 6000,3000 -- --skip-charcreate --lab=creature_lab --species=gallimimus --clipshots=...`), with the HUD hidden and the survivor standing ahead of it for scale.
- `contact_sheet.jpg`: 3 frames per clip, two clips per row (idle, walk / run, charge / strafe_left, walk_back / alert, attack_primary / attack_heavy, bite_combo / hop_back, leap_back / dodge_left, dodge_right / feed, hit_react / knockdown, death / sleep).
- `hits.jpg`: the peck, the kick (the yellow telegraph ring under it) and the combo's kick, each on its attack_hit frame.
- `lab_selector.jpg`: the spawn panel with Gallimimus picked.
- `tripo_inputs.jpg`: the four Tripo views.

What read wrong and was fixed:
- a spike of back skin shot out of the hips in the run (belly vertices forced onto the thigh; the belly line was lowered and leg weight now fades above the hips);
- the left foot hovered 7 cm in every gait;
- the tail dragged through the floor in the display and the kick telegraph, then overcorrected straight up;
- the peck hooked the head back under the neck and folded the neck into the chest (now FABRIK along a shallow arc, beak nose-first);
- the sleep pose had the head sticking up on a swan neck;
- the combo kick stopped dead on its hit frame (an eased key on the hit).
- In the lab, the death pose carries into the next clip, so sleep was shot in its own run.

## Gates (after merging canon a0cc474d)
- `tools/gait/check_galli.py --height 3.8` (new, adapted from check_pachy): **GALLI_CHECK PASS**, 20 clips. It checks:
  - stretch at most 7.4 (gate 8);
  - no sinking or floating;
  - no moonwalk on the gaits and strafes;
  - no gliding in the one-shots;
  - every peck hit lands within 0.2 m of the target in her chest;
  - every kick hit is 2.4-2.75 m ahead at 0.7-0.8 m up, moving at 9-12 m/s after a 1.56 m raise.
- `python3 tools/audit_gaits.py --gate`: GATE PASS.
- `game/tests/t_sp_gallimimus.gd` (new): **PASS**. It checks:
  - GLB, no boxes, 20 clips, the Jaw and Neck1-3 bones, 3.8 m tall;
  - feet planted in 7 standing clips;
  - the head drops 1.4 m at the peck's hit; the foot is raised 1.8 m in the kick's telegraph;
  - the spawn rows are kept and the lab lists it;
  - fight: point blank the kick is picked and lands, shoves and winds her, no knockdown; the peck lands; the combo lands from 6 m; a peck at her behind it misses;
  - chase: unchased it runs and never turns; chased at 7 m/s it turns with the display and fights; at 20 % HP it runs. Five runs, all pass.
- These pass: t_hitboxes, t_knockdown, t_noboxes, t_combat, t_canim, t_data, t_cornered, t_coelomoves (its gallimimus section moved to t_sp_gallimimus; the data check now expects cornered, not territorial), t_hopstrafe, t_tactical, t_ai, t_mounts, t_saddles, t_labspawn, t_godlab, t_plantedflinch.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
- `t_ragdoll` fails on compsognathus (joint stretch 27 %) and velociraptor (94 %, the HOPSTRAFE rescale). Both come from canon; the gallimimus no longer has a ragdoll row.
- t_hitboxes prints three "String formatting error" lines that come from canon's newer species, not from the gallimimus. It still passes.

## For the next agent / known issues
- **Merge notes:**
  - `brain_cornered.gd`: the opt-in `carry_s` (`_last_press`; `_turn` clears it);
  - `rig_biped.py`: opt-in Neck3, `foot_drop` and `leg_top_z`;
  - `anim_events.json`: `natural_speeds.gallimimus` and `note_gallimimus` rows. The coelomoves notes no longer list gallimimus;
  - `hitboxes.json`: the gallimimus row only; `ragdoll.json`: the gallimimus row removed;
  - `t_hopstrafe`: gallimimus is now in the hop list.
  - On a conflict, take both sides.
- **Damage (GM5):** at attack 120, one peck kills a fresh 100 HP survivor. That is a balance call and I did not tune it.
- **Lying clips:** knockdown and death read as a heap on its side with the toes poking up. They pass the floor gates but could use a better pose.
- **Hop bounds** are one body length (about 9 m at this size, per HOPSTRAFE's rule). Shorten them per species if they look too long in the lab.
- **Not done:**
  - no alpha skin (none was listed);
  - no eye-glow points;
  - no ragdoll profile. The old `ragdoll.json` row named the transplant's bones (Body, Shoulders, BackFoot), so I removed it; the gallimimus falls back to its death clip, as the other rig_biped species do;
  - `docs/current/biome-spawns.md` not regenerated;
  - the old v1 files under `work/` are left in place.
