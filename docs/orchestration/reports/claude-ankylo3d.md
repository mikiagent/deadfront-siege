# ANKYLO3D: the v3 ankylosaurus is a rigged, animated 3D model

Branch `claude/mmo-ankylo3d` (from `origin/claude/mmo-overhaul` a2c5acbf). Not merged to canon.
Owner approval: Milan, "yeah that ankylo v3 is great make it into a 3D model".

**Credits: Tripo 50** (balance 2755 -> 2705). One multiview generation, no retry. Meshy 0, no Tripo rigging,
animation or retexture, no paid images. Codex image generation (free) drew the front and back views.

## Mesh
- Inputs (`docs/orchestration/reports/ankylo3d/tripo_inputs.jpg`, copies in `game/assets/creatures/ankylosaurus/ref/`):
  - left: `ankylosaurus_side_v3.png` padded to 1600x1600 with its own grey (#B2B4B7), because the club touched the right edge;
  - right: that image mirrored (the animal is symmetric);
  - front and back: Codex, from the padded side view plus the v3 sheet. I checked both by eye before spending.
  - Not cropped from the sheet: the skill says crops lost a forearm before.
- Tripo P1-20260311 multiview, texture + PBR, face limit 15000, task `b55b511f-3cb5-43cf-8d04-ddb3a0d51ea2`.
  - The tripo CLI is gone from this machine: `~/.local/bin/tripo` points at a deleted node_modules.
  - I called the V3 API directly with the key in `~/.tripo/config.json` (never printed). The script is in my scratchpad and is not committed.
- Result (`tripo_mesh_views.jpg`): it matches the sheet.
  - Dark slate shell, bone-pale spikes, a hooked beak with the mouth open.
  - A long spiked tail with a big club, four splayed legs.
  - 1.0 x 0.53 x 0.31 units, facing +X.
  - The source GLB is at `work/ankylosaurus_tripo_v1.glb` (gitignored; the task id re-downloads it).

## Rig and clips (all reproducible: `tools/gait/build_ankylosaurus.sh`)
1. `tools/transplant_rig.py` with the Quaternius Triceratops donor (the styracosaurus/zebraceratops skeleton),
   `--hip-z 0.10 --shoulder-z 0.105`. The side spikes fooled the hip measure: it read 0.076 of a 0.31-unit body.
2. Jaw: `add_jaw.py --open --pivot -0.02 0.118 --split -13 --close 26 --blend 0.03`. The beak closes to a slight gap.
   - New `--blend` option. The jaw skin fades in across the mouth corner, and a snout island that reaches back to the corner is not made rigid.
   - Without it, a 26 deg close tore a white crack behind the jaw.
   - Default 0, so other species are unchanged.
3. **New `tools/gait/rejoint_legs.py`.**
   - The landmark warp left the front shoulder, elbow and wrist 7 cm inside the body (x 0.135; the front leg column stands at x 0.205).
   - It left the hind joints 7 cm ahead of the hind leg, with elbow and knee only 3-4 cm off the floor.
   - Every stride swung paw skin 0.38 m (game scale) through the floor, and the toes stretched 20-40x.
   - The tool moves the joints onto the measured leg columns and re-splits only each leg's own weight (paw, lower, upper).
   - The transplant clips are moved onto the new joints with `transfer_clips.py`.
4. Clips (14):
   - **walk** (lateral, 1.08 s), **run** (lumbering trot, 0.625 s, duty 0.55 so it never leaves the ground),
     **strafe_left/right**, **walk_back**: from `make_gait.py` + new `tools/gait/ankylosaurus.json`.
   - **attack_primary**, **attack_heavy**, **alert**, **sleep**: new `tools/gait/make_tail_club.py`, keyed from rest.
     The body yaws about the front feet, so the hindquarters swing with the tail. The feet follow that yaw and the
     hind feet scramble. Two-bone leg IK runs every frame, and a floor pass lifts the body if a knee would go under.
     - attack_primary 1.25 s: the tail cocks left, then whips to the right side. The club is 3.7 m out to the side
       at 38 m/s on the hit frame (hit_frac 0.42).
     - attack_heavy 2.0 s: braces low, the club cocked high and trembling, then a full swing at hit_frac 0.72.
     - alert: head up, body low, the club raised and rattling.
     - sleep: settles belly-down, legs out to the sides, chin down, tail curled. Not looped; the game holds the last frame.
   - **feed**: the styracosaurus graze, moved across with `transfer_clips.py`.
   - **idle, hit_react, knockdown, death**: the transplant's donor clips, moved onto the new legs.
   - Jaw keys (`key_jaw.py`): a grunt on the swing (14 deg), a roar on alert and on the heavy telegraph (24/26), chewing on feed, breathing on idle.
   - Every clip then goes through STEGOFIX's `ground_clip.py`. The donor's roll onto the side pushed a paw 0.34 m under the floor.
5. Size: `height_meters` 3.4 -> **2.25** (# ASSUMPTION, read as "withers").
   - The shell over the shoulders is at the survivor's head height (1.78 m).
   - The model is 7.1 m long, matching the look's "8 meter".
   - `real_length_m` (16) is unchanged, and so is `body_radius`.
6. Data:
   - `ankylosaurus.json`: look and texture_prompt rewritten for the v3 dark slate design, new clip descriptions, and a `pipeline` block (forward +Z, source height 0.3145, provenance, clip list).
   - `anim_events.json`: `natural_speeds.ankylosaurus` comes from `bake_clip_speeds.py --dry-run` (walk 0.991, run 2.061 m/s); strafes and walk_back use the same formula. Only this row was spliced in.
7. Wiring:
   - `CreatureView` loads `assets/creatures/<id>/<id>.glb` by convention, so the ankylosaurus now draws the GLB everywhere (wild, pens, labs) instead of the box placeholder.
   - I did not touch spawn filtering. If claude/mmo-noboxes filters out species without a model, the ankylosaurus passes that filter once this branch is in.

## Shots (`docs/orchestration/reports/ankylo3d/`)
They come from self-quitting windowed runs off-screen (`--position 6000,3000`) of the new `ankylo3d_lab` (`-- --skip-charcreate --lab=ankylo3d_lab --out=DIR`).
- `contact_sheet.jpg`: 14 clips at 30 % and 60 %, side camera (survivor ahead of the head for scale) and a high three-quarter from the right rear.
- `hits.png`: both attacks on their hit frame. Full frames are in `sheet/`.

What read wrong in my reviews, and what I did about it:
- **Fixed** in the shots above:
  - paws through the floor and stretched toes (the rejoint);
  - a white crack at the jaw corner (`--blend`);
  - a run with all four feet in the air (duty 0.55);
  - the hind toes curling through the floor (less swing curl).
- In the lab, a paused seek kept the previous clip's tail, because Godot's importer drops constant tracks. The lab
  now resets the pose before each clip. The game drives clips through an AnimationTree, which resets missing tracks itself.
- **Left as is**:
  - The sleep body sits about 0.1 m off the ground. The floor pass keeps the folded knees above the floor.
  - knockdown/death are the donor's roll onto the right side, with the legs out.
  - The swing goes to the right side only; there is no mirrored left swing.

## Gates
- `tools/gait/check_ankylo.py --height 2.25` (new; check_stego's stretch/ground/moonwalk gate adapted to this rig in game metres, plus a "club is the hit" check): **ANKYLO_CHECK PASS**, 14 clips.
  - Worst stretch 7.5 (gate 12); the lowest skin is -0.011 m (gate -0.03).
  - The planted feet slide backward in walk and run; walk_back slides the other way.
- `python3 tools/audit_gaits.py --gate`: **GATE PASS**. ankylosaurus walk drift -0.07 to -0.09, run -0.09 to -0.10 (+z facing, backwards); run and walk are distinct.
- `tools/verify_rig_imports.gd`: RIG IMPORT PASS, 126 clips.
- `game/tests/t_ankylo3d.gd`: **PASS**. It checks:
  - the GLB draws with no boxes, and all 11 listed clips plus the strafes and walk_back load;
  - the Jaw bone and Tail1-5 exist;
  - the model is 2.25 m tall and 7.1 m long;
  - the feet stay within 6 cm of rest in idle, walk, run, both attacks, hit_react, alert and feed;
  - the club is more than 1.5 m to the side and faster than 4 m/s at both hit frames;
  - a spawned ankylosaurus's attack_primary reaches its hit once and damages a survivor in reach.
- t_combat, t_canim, t_stationstate (large pen and size), t_stegofix, t_boneparts, t_data, t_natures, t_labspawn, t_ai, t_eyeglow: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
- **t_ragdoll FAILS, and the failure was already there.** Line 531 still expects "stegosaurus is the placeholder in game"; STEGOFIX removed that placeholder. It does not involve the ankylosaurus, and I did not touch it.

## For the next agent
- The hit is decided by reach from the body's centre (`creature._on_hit`), not by where the club is.
  - The brain faces its target, so the club visibly lands beside the animal's right flank while the survivor stands at its head.
  - A tactics profile for `club_tail` could turn the animal broadside or tail-on before the swing, as real ankylosaurs did. ai.json and the brain are Cursor's.
  - No tactics profile exists, so the default herbivore brain runs (defensive temperament).
- At attack 420 the swing one-shots a fresh survivor (100 -> 0 in t_ankylo3d with force_accuracy). That is the species stat block, not the clip; it is a balance call.
- No ragdoll profile, no mount and no saddle (tamed roles are bag/combat). Eye-glow points are not set.
- `tools/jaw/add_jaw.py` gained `--blend`; merge with any branch that also edits it.
- New tools are written for the Triceratops-donor skeleton, so they work for styracosaurus/zebraceratops-family rigs too.
  - `rejoint_legs.py` fixes any transplant whose legs the landmark warp misplaced.
  - `make_tail_club.py` provides a tail swing for any `club_tail`/`spiked_tail` species.

Report head: see the push below (commit on `claude/mmo-ankylo3d`).
