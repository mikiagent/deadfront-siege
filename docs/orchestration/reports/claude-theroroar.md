# claude-theroroar: rearing roar, ceratosaurus stance, spacing stomp

Branch `claude/mmo-theroroar`, cut from `origin/claude/mmo-overhaul` 47dd42cd. Canon merged again at 91f348a6 (spinosaurus, cooldown UI). Pushed. Not merged to canon.
Credits: none. No Tripo, no Meshy, no Higgsfield. Blender only (headless).

## What the owner asked
- 2026-10-31, from the fight lab: "I want to give the T-rex adjacent dinosaurs a roar animation where they stand on their hind legs and roar in almost a circular motion with special effects and screen shake ... I thought the model's head was too big when his head is facing north but if it stands up higher and uses his arms more it could be fine".
- Added mid-task, through the coordinator: "for animals that have weird hitboxes (like trex style where they hang over their legs) add a stomp mechanic that tosses the player backwards to the perfect range of a chomp style attack. Make the ground shake".

## 1. The rearing roar (THERO-ROAR)
**Clip `roar`.** One Blender script authors it for every big theropod rig: `tools/gait/make_thero_roar.py`. The per-species numbers are rows in `tools/gait/thero_roar.json`. To rebuild everything and run the gate, use `tools/gait/build_thero_roar.sh`. The roar goes through these beats:
- **0 to 0.24 (rear):** the body pitches up on the hips and rises as far as the legs reach. The rise is clamped so the foot never leaves its print. The tail lowers as a counterweight, the arms come up and flex, and the head is thrown up and to the left.
- **0.24 to 0.34:** the jaw opens wide on the real `Jaw` bone, using each species' tested gape (27 to 46 deg).
- **0.30 to 0.80 (bellow):** the head sweeps a near-circular arc: high on the left, down and forward through the middle, up on the right. The hips (yawing on planted feet), the chest, both neck bones and the head all carry it. The snout's heading sweeps 215 to 223 deg. The tail swings the opposite way and the arms tremble.
- **0.80 to 1.00:** it settles back to the idle's first frame.

**Rigs that have it (7):** ceratosaurus, tyrannosaurus, megarex, allosaurus, majungasaurus, tarbosaurus, and spinosaurus, which landed on canon during this task. The carnotaurus is skipped as asked: add its row to `thero_roar.json` once claude/mmo-carnofeel lands.

**Shared runtime:** `game/scripts/combat/thero_roar.gd` (TheroRoar), driven by data in `ai.json` `thero_roar`. Any rig with a `roar` clip uses it. There is no per-species code.
- **On aggro:** `CreatureBrain._spot` plays the roar instead of the alert clip. A first hit while it is roaming or asleep (`on_aggro`) also roars. The brain holds still in alert for the roar's length.
  - It roars once per encounter: `cooldown_s` is 30 s per animal.
  - The existing alert uses (hold pose, threat display, pack propagation) keep the old alert clip, so the roar does not spam.
- **On phase changes:** MegaRex used to roar only when entering phase 3 and then every ROAR_COOLDOWN. Now each phase change (into 2 and into 3) opens with the roar at her next attack, played as the windup. Its impact fires the existing bellow (`roar()`, Groggy) plus the burst. The phase-3 repeats keep ROAR_COOLDOWN.
  - ASSUMPTION: the phase-2 roar staggers small things the same way phase 3's does.
- **The burst** fires at the clip's hit_frac, 0.34 in `anim_events.json`:
  - a breath ring blown out of the jaws along the snout;
  - a shockwave ring on the ground;
  - a dust burst;
  - a camera shake on the local survivor through the existing `IsoCamera.shake`.
  - The shake scales with size (0.35 to 0.8 across 4 to 10.5 m) and fades to 0 at 6 body heights.
- **Sound:** none. Canon has no audio assets at all, so the burst is silent.
- **Bigstomp:** its shake is not on canon. I used the same pattern (`IsoCamera.shake(local, amount x falloff)`) so the two can be unified when it lands.
- **Labels:** the telegraph and opening labels name `roar` as ROAR.

## 2. Ceratosaurus stance
`make_cerato_moves.py` now has a STANCE that the idle and the alert (its combat stance and hold pose) stand on. Every other clip is unchanged.
- The body tips 13 deg nose-up and rises 0.05 hip heights.
- The neck is carried higher and the snout stays level.
- The arms are held forward and flexed, with the hands working during the breath.
- `check_cerato.py` passes, with feet on their prints.
- From behind (the fight camera's pitch), the head now sits up over a taller torso instead of capping a level back. From the side it is visibly taller against the survivor. See `theroroar/ceratosaurus_stance_before_after.jpg`. Whether that fixes "head too big" is the owner's call.

## 3. Spacing stomp (coordinator's add-on)
**Clip `spacing_stomp`** (1.0 s, hit_frac 0.4), authored by the same script with the 4th argument `spacing_stomp`:
- the weight rocks onto the left leg;
- the right foot is hauled up 0.7 to 1.5 m with the toes hanging and slammed back onto its own print;
- the left foot never moves.

It exists on the same 7 rigs. The tarbosaurus was added as "T. rex style" (ASSUMPTION).

**Runtime:** `game/scripts/combat/spacing_stomp.gd` (SpacingStomp), with data in `ai.json` `spacing_stomp`. CreatureBrain owns one (`spacing`) and ticks it before its think, the way bigstomp does.
- **When it fires:** the target is standing and tucked in. That means ahead of the hips, but closer than the bite's jaw reach less 0.8 m, and inside the body's width. It also waits until no one-shot is playing and no leap or timed move owns the body.
- **The slam:** the roar's shake helper (`TheroRoar.shake_local`), its ground ring and dust, and 0.15x attack damage.
- **The shove:** straight out in front, through `PlayerSim.shove`, then PlayerKnock.
  - She lands at the bite's reach, which is read from the species' own `attack_primary` jaw hitbox at its hit frame (`Hitbox.baked`), not a constant.
  - A knockdown slides exactly the push. A throw (the big ones) flies and then tumbles on, so the new `PlayerKnock.push_to_land` shortens the push by the tumble. Below the minimum throw it uses a higher, shorter arc.
  - Measured landings were within 0.02 to 0.08 m of the reach on all 7 rigs.
- **The follow-up:** it waits while she is in the air, then bites through the brain's own path. TacticalBrain tries the combo, then the bite. TyrantBrain uses a new `follow_up_bite()` timed bite.
- **Bigstomp:** it is not on canon (`git log origin/claude/mmo-overhaul | grep -i bigstomp` is empty), so this is built standalone. The clip, class, data key and brain field all have their own names (`spacing_stomp`, `SpacingStomp`, `spacing`) so the two moves stay distinct. Expect a small textual conflict in `creature_brain.gd`, `creature_clips.gd`, `creature_anim.gd` and `ai.json` when bigstomp merges.
- **Hitbox data:** the ceratosaurus, allosaurus, majungasaurus and spinosaurus `attack_primary` rows in `hitboxes.json` gained `aim_down_m` = 0.55 x height (ASSUMPTION). Without it their standing-height bites missed a survivor lying on the ground. This also lets their ordinary bites reach a downed or low target.

## Gates
- `t_theroroar` (new): **PASS**. It checks:
  - All 7 rigs have the clip, sampled in the engine at game scale:
    - feet planted, worst 0.026 m against the 5 cm limit;
    - head sweep 215 to 220 deg;
    - the hips rise and the jaw opens 30 to 65 deg.
  - The roar fires on spot and on a first hit, and holds in place.
  - The burst fires and shakes (0.31 at 12 m).
  - There is no second roar inside the cooldown.
  - The shake falls off with distance and grows with size.
  - MegaRex's phase-2 roar fires, and its impact bursts.
- `t_spacingstomp` (new): **PASS**. All 7 rigs build a stomp and a velociraptor has none. Live on all 7, with her tucked at 0.35 of the jaw reach:
  - it stomps after 0.02 s;
  - the ground shakes;
  - she is knocked down or thrown;
  - she lands at the jaw reach within ±0.3 m (worst 0.08 m);
  - the follow-up bite lands on her;
  - at bite reach she is not counted as tucked.
- `tools/gait/build_thero_roar.sh`: **BUILD OK**. Blender checks on all 14 clips: no sinking, feet on their prints, sweep ≥ 180 deg, jaw ≥ 25 deg.
- `python3 tools/audit_gaits.py --gate`: **GATE PASS**.
- t_canim, t_combat, t_plantedflinch: **PASS**.
- Updated for the new behaviour and passing:
  - t_sp_megarex: phase 2 now opens with the roar, and the phase-3 roar is the `roar` clip;
  - t_rexclips: spotting plays `roar`;
  - t_sp_majungasaurus: 19 listed clips.
- Full `tools/all_tests.sh`, `run_all.gd` and `tools/smoke.sh --no-import`: see the closing section.

## Shots (`docs/orchestration/reports/theroroar/`)
All shots come from off-screen windowed runs of the new `theroroar_lab` (`--position 6000,3000`, self-quitting, `-- --skip-charcreate`), and I looked at each one.
- `roar_contact_sheet_tq.jpg` and `roar_contact_sheet_side.jpg`: 7 species at 12/34/55/75 % from a front three-quarter and the side, with the survivor for scale. The 34 % column is the burst, with the breath ring, ground ring and dust.
- `ceratosaurus_stance_before_after.jpg`. The top row is from behind at the fight camera's 38.7 deg pitch; the bottom row is side on. The four columns are:
  - idle before;
  - idle after;
  - alert at 50 % before;
  - alert at 50 % after.
- `spacing_stomp_hit_and_bite.jpg`: live fights for all 7, at the slam (dust ring, shake value) and at the follow-up bite's hit frame. The caption gives the push and the jaw reach.
- To reproduce:
  - `--lab=theroroar_lab --out=DIR [--species=..] [--clip=roar] [--pcts=..] [--cams=tq,side,behind]`
  - `--lab=theroroar_lab --out=DIR --stomp --species=<id>` (one species per run: running several in one process left the survivor's state dirty between them).

## Known limits and things the next agent should know
- **The follow-up bite does not dip to the ground.** Every bite clip is authored at standing height. On a downed survivor the hit connects through data: the rexes' calibrated 6.5 to 7.2 m head spheres, and the `aim_down_m` above. The jaws visibly close over her rather than on her. A real fix is a low "ground bite" clip per rig. Not done.
- **No roar sound.** Canon has no audio. The burst would play one if added.
- **Camera shake** cannot be seen in a still shot. The tests assert the amounts.
- **The ceratosaurus head was not resized,** only re-posed, as the owner suggested.
- **Shared files touched:**
  - `creature_brain.gd`: the roar in `_spot` and `on_aggro`; the `spacing` tick and `spacing_ready` / `_body_committed`.
  - `tactical_brain.gd`: `_body_committed`.
  - `tyrant_brain.gd`: labels, `follow_up_bite`, `_body_committed`.
  - `mega_rex_brain.gd`: the phase roar.
  - `creature_anim.gd` and `creature_clips.gd`: new one-shots.
  - `telegraph.gd`: label.
  - `player_knock.gd`: `push_to_land`.
  - Data: `ai.json`, `anim_events.json`, `hitboxes.json`, and 7 species jsons, whose pipeline clips gained `roar` and `spacing_stomp`.
- **Every number in `thero_roar.json` and in `ai.json` `thero_roar` / `spacing_stomp` is an ASSUMPTION** tuned on renders.
