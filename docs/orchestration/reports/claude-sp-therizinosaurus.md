# SP-THERIZINOSAURUS: a new species, the Therizinosaurus

Branch `claude/mmo-sp-therizinosaurus`, cut from `origin/claude/mmo-overhaul` 1bb8adec, canon merged back in. Pushed, not merged to canon.

Owner sheet: `therizinosaurus_owner_sheet_1` ("use this for the therezino"), copied to `game/assets/creatures/therizinosaurus/ref/therizinosaurus_sheet.png`. There was no therizinosaurus in the game before; this is a new species.

## Credits
**Tripo: 50**, one P1 multiview generation, no retry. Balance 1955 before, 1905 after. Meshy 0, no Tripo rig/anim/retexture, no paid images. Codex drew one image (free).
- Task `65b2aab3-3547-48b0-a1c2-923f7cb395e0`, V3 API called directly with the key in `~/.tripo/config.json` (never printed).
- Inputs (`ref/therizinosaurus_view_{front,left,back,right}.png`):
  - front and back cropped from the owner sheet, rescaled to the side view's animal height;
  - left: a Codex neutral-stance side view (feet side by side, arms forward, claws clear of the legs, beak parted);
  - right: its mirror.
- Result: matches the sheet (slate-blue feathers, lavender legs, pink wattle, three long black sickle claws per hand, tail fan). The claws came out whole, so no separate Blender claw pieces were needed. Source GLB `work/therizinosaurus_tripo_v1.glb` (gitignored; the task id re-downloads it).

## Model and rig (rebuild: `tools/gait/build_therizinosaurus.sh`, ~40 s)
- `tools/gait/rig_biped.py` with `tools/gait/therizinosaurus_rig.json` (joints read off ortho renders). Two small, opt-in additions to the PACHY tool (the pachycephalosaurus is unchanged):
  - a 5th arm point adds a **Claw** bone (the three claws ride it) and a non-deforming **ClawTip** marker at the claw tip, which the game's hit check reads;
  - `leg_zone_y` keeps the long hanging claws out of the leg-only weight zone; `proxy_frac` keeps the heat weights (the voxel proxy weighted nothing on this mesh).
- Jaw: `add_jaw.py --open --pivot 0.07 0.545 --split -8` (the beak is modelled parted; -8 keeps the upper beak whole when the jaw opens).
- Size: 8.0 m to the head top, 13.2 m long (# ASSUMPTION TZ2). The claws hang at survivor height ~5.5 m ahead of its centre.

## Clips (15)
| clip | what |
|---|---|
| walk, run, strafe_left/right, walk_back | `make_gait.py` + `tools/gait/therizinosaurus.json`: slow heavy stride; the run is a jog with the arms tucked and claws curled |
| attack_primary | **claw sweep** (1.0 s, hit 0.42): right arm cocks out to its right, the claw tips sweep low across its front through her spot |
| attack_heavy | **overhead rake** (1.58 s, hit 0.72): rears hissing, both arms high, claws fanned and trembling through the 0.6 windup hold (the telegraph), then both claw sets drive down on her and rake back |
| bite_combo | **hook and rake** (3.0 s, the shared bite_combo fracs): right claws hook her on 0.092 and drag back to the chest; left backhand on 0.338; rears with both arms cocked (tell 0.5-0.667); double claw thrust on 0.815 |
| alert | **threat display**: rears up tall, arms flung wide and raised with the claws fanned, beak open hissing, claws shaking, tail fan raised |
| idle, hit_react, feed, knockdown, death, sleep | `make_theri_moves.py`; feed is a high browse (the claws hook a branch down); lying clips fold the arms back so the claws never prop it up |

All one-shots come from the new `tools/gait/make_theri_moves.py` (make_pachy_moves' IK-planted feet and pose machinery, plus a claw-tip **reach** solver: each hit pose aims the ClawTip at the spot the survivor stands in, because at rest the claws hang 3 m out to each side and missed a target under the head). Every clip then goes through `ground_clip.py`.

## Moves and AI (new archetype `claw_guardian`, ai.json; # ASSUMPTION TZ3-TZ5)
- **Territorial herbivore**: it grazes, and turns on anyone within 14 m of its body (or on one hit). It never flees on sight; it flees when badly hurt. The shared "chased animals turn and fight" rule is claude/mmo-cornered's; not duplicated.
- **Opening**: the threat display, then the hook (display_hook is the heaviest sequence; strafe-then-hook and a plain hook too). From its ring it dashes in for the hook.
- **Hook pull**: the combo's first hit drags her up to 3.5 m toward it (never closer than 4.5 m from its centre), setting up the backhand and the thrust. New `TacticalBrain.landed` hook (`hook_pull_m`).
- **Claw sweep** (point-blank basic): a landed sweep shoves her 3 m back to claw's length (`primary_shove_m`).
- **Overhead rake** (point-blank heavy, x1.8, 8 s cooldown): the only move that bleeds (`bleed_2`, limited to attack_heavy with canon's `pipeline.status_clips`; my own `status_heavy_only` switch was dropped at the ceratosaurus merge).
- **Hits use the claws**: `pipeline.hit_parts` names ClawTip.L/R (radius 1.4-1.6 x size). Behind it or under its tail the claws miss (tested).
- **Spawns**: temperate_45 working ring (1, 60 %), temperate_35 far shore (1, 50 %). The lab lists it (it has a model).
- `CreatureDef.is_herbivore_diet` lists `claw_guardian`.

## How to test (god mode)
1. Point `tools/fight_lab.command`'s REPO at this worktree (or canon once merged), or run `Godot --path game -- --lab=creature_lab --god --skip-charcreate`. God mode is on (G toggles it).
2. Press SPAWN, pick **Therizinosaurus**, nature Aggressive (or any nature: it is territorial), SPAWN. NEXT (T) also cycles to it.
3. Walk toward it: inside ~14 m it rears into the threat display (arms wide, claws fanned, hissing), then dashes in and hooks you: the first claw hit drags you toward it, a backhand, a rear-up, a double thrust.
4. Stand at its claws: watch for the rear-up with both arms high and trembling (the overhead rake; roll out, it bleeds), or the right-arm sweep that shoves you back 3 m.
5. Get behind it or under its tail: its claws miss. F3 prints each move ([ai] lines).

## Shots (`docs/orchestration/reports/sp-therizinosaurus/`)
From self-quitting windowed lab runs off-screen (`--position 6000,3000`, `-- --skip-charcreate --lab=creature_lab --species=therizinosaurus --clipshots=DIR --clips=...`), HUD hidden, the survivor standing ahead of it for scale.
- `contact_sheet.jpg`: 3 frames per clip, two clips per row (idle, walk / run, strafe_left / strafe_right, walk_back / alert, attack_primary / attack_heavy, bite_combo / hit_react, feed / knockdown, death / sleep).
- `hits.png`: the sweep, the overhead rake and the hook combo on their `attack_hit` frames (the combo's last hit is the one saved).
- `lab_selector.jpg`: the spawn panel with Therizinosaurus picked.

What read wrong and was fixed:
- the claws hung 3 m out to each side and missed a survivor under the head at every hit frame: the moves now aim the ClawTip at her spot (reach solver), and the game's hit check reads the ClawTip markers instead of the knuckle;
- the display's tail fan dropped into the floor when it reared (tail pitch sign);
- the sweep barely moved the arm (bigger cock and sweep);
- the combo floated a foot off the floor on the lunge (smaller lunge);
- the run stretched a thigh-feather edge 10.5x (shorter stride; gate 10, worst 9.1);
- lying clips (knockdown, death, sleep) held one arm straight up in the air: the arms now fold back and in under the chest.
- In the lab, a held sleep pose carried into the next clip shot, so feed is shot before the lying clips.

## Gates
After merging canon f1b05695 (ceratosaurus); the merged `.gd` files were scanned for duplicate `func` names (none).
- `tools/gait/check_theri.py --height 8.0` (new, check_pachy adapted): **THERI_CHECK PASS**, 15 clips: stretch (gate 10), floor, moonwalk on gaits and strafes, no gliding in one-shots, and the claws are the hit (a claw tip at survivor height, ahead of the chest and moving at every hit frame of the sweep, the rake and all three combo hits; the rake raised over 4 m first). Claw reach at the hits 6.1-6.9 m ahead of its centre.
- `python3 tools/audit_gaits.py --gate`: GATE PASS.
- `game/tests/t_sp_therizinosaurus.gd`: **PASS**: model, 15 clips, Jaw/Claw/ClawTip bones, 8 m tall; feet planted in 7 standing clips; claw tip in front at the sweep's hit and both claws high in the rake's telegraph; live fight: point blank the brain picks the rake, it lands and bleeds; the sweep lands, shoves her away and does not bleed; the hook dashes in from 9.5 m, lands and drags her toward it; a sweep with her behind it misses; a Brave (not Aggressive) one ignores her at 40 m and turns on her inside its territory; spawn rows; the lab lists it.
- t_noboxes, t_combat, t_canim, t_data, t_ai, t_labspawn, t_tactical, t_sp_ceratosaurus: PASS.
- `run_all.gd`: `[tests] PASS` (needed `claw_guardian` in `combat_counters.json`: family giant). `tools/smoke.sh --no-import`: SMOKE PASS.

## For the next agent / known issues
- **Merge notes**: `tactical_brain.gd` `landed()` was generalised (heavy shove kept; sweep shove and hook pull added), `creature_def.gd` one archetype in the herbivore list, `rig_biped.py` opt-in Claw/ClawTip/leg_zone_y/proxy_frac. anim_events.json: `natural_speeds.therizinosaurus` (Godot bake, dry-run spliced) and `note_therizinosaurus` on attack_primary/attack_heavy/bite_combo. Take both sides on merge.
- The combo uses the shared `bite_combo` slot and its fracs; it hits three times (x0.8/1.0/1.6).
- At atk 400 the rake or a full combo kills a fresh 100 HP survivor (balance, TZ3).
- The run's thigh feathers stretch up to ~9x on one 13 cm edge (check gate 10). Not done: no saddle/mount (TZ1), no alpha skin (none listed), no eye-glow points, no ragdoll profile, no butchering row; `docs/current/biome-spawns.md` not regenerated. Feathers do not physically fluff in the display (no feather bones); the read comes from the arms, rear-up and tail fan.
- The skill's external verifiers and the clip-viewer recorder were not used; the repo gates are the checks.
