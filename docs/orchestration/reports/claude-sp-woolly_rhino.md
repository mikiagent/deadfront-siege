# SP-WOOLLY_RHINO: the woolly rhino, a new tundra species

Branch `claude/mmo-sp-woolly_rhino` (from `origin/claude/mmo-overhaul` 346a6057). Not merged to canon.
Owner: "build some of the models ... be creative with what moves you think they should do", then "keep cooking".

**Credits: Tripo 50** (balance 2455 -> 2405). One multiview generation, no retry. Task `fc9ea902-6928-4ad9-979a-abbc9a4a24ec`
(P1-20260311, texture + PBR, face limit 15000). Meshy 0, no Tripo rig/anim/retexture, no paid images, no Codex images.

## Model
- Inputs (`sp-woolly_rhino/tripo_inputs.jpg`, copies in `game/assets/creatures/woolly_rhino/ref/`): the owner's regular sheet
  already has a clean side, front and back view on grey, so the four views are crops of it, padded onto one canvas at one
  scale (the back panel is drawn ~0.8x on the sheet and was scaled up 1.2x); right = left mirrored.
- Result (`tripo_mesh_views.jpg`): matches the sheet: curly dark wool, pale long nose horn and short second horn, short
  thick legs, tufted tail. The Tripo hide has ~65 holes, some along the spine; the build welds the spine seam and fills
  the simple holes (19); the rest are hidden by the double-sided creature shader. A thin slit on the shoulders remains.
- Size (# ASSUMPTION): 2.95 m at the hump (1.8 m x the 1.6 house exaggeration), 6.2 m nose to tail. The survivor reaches
  its shoulder. `real_length_m` 7.4 (the roster's 2x of 3.7 m).

## Rig and clips (reproducible: `tools/gait/woolly_rhino/build.sh`)
- `build_rig.py`: SP-MEGALOCEROS's hand-built mammal rig (3-joint legs with carpus/hock/fetlock, a jaw), with rhino
  landmarks (`rhino.json`, `rig_landmarks.jpg`). Changes for the rhino:
  - the legs only take skin inside their own fore-aft span: the belly wool hangs below the elbows, and the deer rule
    ("below the belly line = leg") tore the skirt 20x when the legs swung;
  - horns and forehead skinned 100 % to Head; two marker bones `Horn` (base -> tip) and `HornTip` for horn hits;
  - spine seam weld and hole fill (above).
- `clips.py`: the megaloceros solver and gaits (planted feet, analytic legs) with rhino strides, and the rhino's moves.
  16 clips: idle, walk, run, charge, strafe_left/right, walk_back, alert, attack_primary, attack_heavy, toss,
  hit_react, knockdown, death, sleep, feed. Every clip then goes through STEGOFIX's `ground_clip.py`.
- Jaw: snorts in the paw telegraph, grunts on the hits, chews on feed.

## Moves and AI (`woolly_rhino.json` "tactics", base horned_charger)
1. **Paw-the-ground telegraph** (`alert`, 2 s, the display step): head drops until the horn points at her, a snort,
   three back-scrapes with the right forefoot, a horn hook with each.
2. **Long charge + toss** (`charge` loop, then `toss`): head-down gallop with the horn levelled at waist height
   (1.1-1.7 m), 3.2 s, x1.7 speed, through her spot by 4 m. On impact the horn must reach her; the toss clip whips the
   head up and the survivor is shoved 5 m and lifted 5.5 m/s (about 1 m up), stagger 1.1 s.
   Sequence weights: paw -> charge 4, plain charge 0.5, strafe -> charge 0.5 each.
3. **Wide horn sweep** (`attack_heavy`, point blank, x2.2): head cocked far right and held trembling (the tell), then
   ripped across the front to the far left; the horn tip crosses the front at ~26 m/s, 3.2 m ahead, sweeping +-3.2 m.
4. **Stamp** (`attack_primary`, the basic): forequarters rise, both forefeet come forward and slam down 0.8 m ahead.
- No hind kick (no kick clip). Temperament territorial (horned_charger). COELOMOVES' skittish-territorial profile
  (run once, then turn and fight) landed on canon during this work; considered and not used (# ASSUMPTION, Open
  Questions WR3): the paw-the-ground display already is the rhino's territorial warning, and running first would
  hide its charge. Adding `"territorial": {...}` to its tactics block turns it on.
- **Hits:** claude/mmo-hitboxes is not on canon, so hits are judged at the bone at the hit frame
  (`pipeline.hit_parts` + new `Creature.part_hit`): the stamp needs a forefoot, the sweep and the charge the horn
  within 1.1-1.3 m of her body. A survivor standing at the rump is not hit by a sweep any more.

## Code (small, shared)
- Species tactics (`CreatureDef.tactics`, `TacticalBrain.tactics_for_def/resolve`): written to COELOMOVES' shape;
  after merging canon, canon's copy is the one kept.
- `TacticalBrain._charge_impact`: plays `toss` when the rig has it and passes `toss_lift_mps`; the impact needs `part_hit(&"charge")`.
  Under COMPYFEEL's no-glide rule the toss is a one-shot (`CreatureAnim.ONESHOT`, not an ATTACK, so no second hit
  event): the rhino stops where the horn met her, plays the toss in place, and the charge ends when the clip does.
- `PlayerSim.shove(push, stagger, lift_mps = 0.0)`: the optional upward kick.
- `Creature._on_hit` also requires `part_hit`; `Creature.spawn` gives an alpha the `alpha` model variant;
  `CreatureView.pick_variant` never rolls `alpha`.
- `CreatureClips.OPTIONAL` + `toss`; lab moves line knows `toss` and species tactics.
- `run_all.gd`: the combat-counter species count is now `>= 21` (was `== 20`; new species keep adding).

## Data
- `game/data/creatures/woolly_rhino.json` (stats, taming, tactics, hit parts, coloration, pipeline/provenance).
- `anim_events.json`: `natural_speeds.woolly_rhino` from `bake_clip_speeds.py` (walk 1.405, run 4.02 m/s; strafes and
  walk_back as the walk) and `clips.toss` (hit_frac 0.3). Only these rows were added.
- Spawns: 2 per group in the working ring of `tundra_30` and `tundra_55`. Butchering row. Saddle (`mount/`, built with
  the shared saddle builder; `saddles.json` gained `probe_x_m` because the back ray fell through the spine slit).
- Alpha skin: `woolly_rhino_alpha_albedo.jpg` (`alpha_skin.py`, a rufous recolour of the Tripo albedo), used only by alphas.

## Shots (`docs/orchestration/reports/sp-woolly_rhino/`, off-screen windowed `rhino_lab` runs)
`contact_sheet_side.jpg`, `contact_sheet_tq.jpg` (16 clips at 30/60 % with the survivor), `signature_hits.jpg` (stamp,
sweep tell and hit, toss, paw), `alpha_skin.jpg`, `tripo_inputs.jpg`, `tripo_mesh_views.jpg`, `rig_landmarks.jpg`.
Fixed after looking: gallop and walk strides (hind legs dragged, belly scraping), charge horn into the grass, toss
neck stretch, belly skirt tearing, bodies sinking in knockdown/death/sleep, holes on the back.
Left: knockdown/death are a roll onto the right side; the run is a heavy gallop that briefly floats 6 cm.

## Gates
- `Blender -b -P tools/gait/check_woolly_rhino.py -- woolly_rhino.glb anim --height 2.95`: **RHINO_CHECK PASS**, 16 clips
  (stretch <= 11.6, gate 12; lowest skin -0.012 m; stamp/sweep/toss/charge part checks).
- `python3 tools/audit_gaits.py --gate`: **GATE PASS** (rhino walk/run drift negative, distinct).
- `game/tests/t_sp_woolly_rhino.gd`: **PASS** (model + 16 clips load, bones, size, feet planted in 12 standing clips,
  sweep/toss/stamp at their hit frames, stamp and sweep land from the front, the sweep misses at the rump, paw ->
  charge -> toss hurts and lifts her ~1 m, alpha skin on alpha spawns only, tundra tables and the lab list it).
- t_noboxes, t_combat, t_canim, t_data, t_mounts, t_styraco, t_zebra, t_labspawn, t_alphas: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
- After merging canon (ff7f03b8: COELOMOVES, ANKYLOAI, PINFEEL, PACHY...), rerun: RHINO_CHECK PASS, GATE PASS,
  `all_tests.sh` t_sp_woolly_rhino t_noboxes t_combat t_canim t_data t_ai t_boneparts t_mounts t_styraco t_zebra
  t_coelomoves t_labspawn t_alphas t_ankylo3d t_ankyloai: 15/15 PASS; `run_all.gd` [tests] PASS; SMOKE PASS.
- A full pre-merge `all_tests.sh` sweep (stopped half way) also showed t_colors ("stegosaurus uses the placeholder
  boxes") and t_buildspeed (built-island digests) failing; both fail the same way on a clean canon checkout.
  t_ai and t_boneparts needed the 21st species (fixed).

## How to test (god mode)
1. `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate` (or `tools/fight_lab.command` once merged).
2. SPAWN -> species "Woolly rhino" -> nature Aggressive -> SPAWN (tick Alpha for the red alpha skin), or press NEXT until it comes.
3. Stand ~10 m in front: it paws the ground (head low, three scrapes), then charges; stay in line to be tossed, sidestep (roll) to make it miss and stand staggered.
4. Walk up to its head: point blank it sweeps the horn wide (watch the cocked-right tell), or stamps with both forefeet.
5. Stand beside its rump: the sweep no longer reaches you. In the wild it spawns in the working ring of tundra_30/55.

## For the next agent
- When claude/mmo-hitboxes lands: move `pipeline.hit_parts` into `hitboxes.json` (species woolly_rhino: horn capsule
  Horn->HornTip for attack_heavy and charge, FrontFoot.L/R for attack_primary) and drop `Creature.part_hit`.
- `docs/current/biome-spawns.md` is generated; rerun `tools/docs_wiki/gen_game_data.py` after merge.
- No ragdoll profile, no eye-glow points.

Second canon merge (ee6bfcbb: COMPYFEEL, new pachy): `OPTIONAL` keeps charge_crouch, pin_foot and toss. Rerun:
t_sp_woolly_rhino (now also: the run plays the rhino's own charge clip; the toss plays in place, 0.00 m slide),
t_compyfeel, t_coelomoves, t_combat, t_canim, t_mounts, t_alphas, t_styraco, t_zebra, t_ai: 10/10 PASS;
run_all [tests] PASS; SMOKE PASS; RHINO_CHECK PASS; GATE PASS.

Report head: merge commit d0fd565d on `claude/mmo-sp-woolly_rhino` (pushed); this line is updated in the follow-up commit.
