# ALLOFEEL: allosaurus arms in every attack, three new moves (carno kit waiting on canon)

Branch `claude/mmo-allofeel`, from `origin/claude/mmo-overhaul`, with canon merged back in (bigstomp 2eecfc3e, then megajoust f1b73788; every gate rerun after the last merge). Pushed, not merged to canon.
Credits: Tripo 0, Meshy 0, Higgsfield 0. The model and rig (`allosaurus.glb`) are untouched; only clips, data and code changed.

What the owner said: "Alosaurus model turned out great! the arms should be moving as part of the attack animation and add more attacks generally. Carnotaurus attacks are welcome on this".

## 1. Arms in every attack
- `tools/gait/make_allo_moves.py` gained `arm_keys()`: per-side tracks for shoulder swing (`up`, `out`), elbow and wrist, in raptor_overlay.py's arm language. The rig has no finger bones, so the claws "spread" and "curl" through the wrist.
- **attack_primary** (snap bite): the arms cock back with the claws curled, thrust out with the head (claws presented), and rake down on the bite. The right arm leads the left.
- **attack_heavy** (hatchet): the arms rise and spread wide with the claws open through the held gape, which is the telegraph. They slam down with the chop, hook in on the hit, then drag back to the chest.
- **grab_bite**: the arms reach out wide with the claws spread, then stay extended and clench on the clamp (0.3). On each bite the elbows fold to haul her to the jaws. They fling open on the release.
- **kick** (shoulder ram): both arms tuck in the wind. The right arm drives out with the shoulder and rakes down after the hit, while the left swings back.
- Measured in the engine, from the first frame to the hit, with the claw tip in the chest's frame (so the body carrying the arm doesn't count):

| clip | canon before (tip m / elbow deg / wrist deg) | now (lead / other tip m, elbow, wrist) |
|---|---|---|
| attack_primary | 0.25 / 0 / 0 | 1.15 / 1.00 m, 64, 60 |
| attack_heavy | 0.70 / 19 / 0 | 1.51 / 1.52 m, 40, 59 |
| grab_bite | 0.83 / 20 / 14 | 1.61 / 1.61 m, 44, 58 |
| kick | 0.43 / 10 / 0 | 1.16 / 0.66 m, 44, 42 |

- **ClawTip rows** (`hitboxes.json`): a part at the tip of the claws. It is the `Hand.L/R` bone plus a 0.64 m offset along it (`_part: ClawTip.X`), radius 0.45 m.
  - The rig has no ClawTip bone. Adding one means re-exporting the approved model, so I didn't.
  - The rows sit on every move where the hands are at the prey at the hit frame: bite, hatchet, grab, ram (right hand), rake, slash and the checks (near hand).

## 2. Three new moves (TacticalBrain `tactics.moves`, data-driven)
| move | clip | when | hit | effect |
|---|---|---|---|---|
| ARM RAKE | `claw_rake` 1.1 s | prey 3.5-5.2 m in front (under its chest) | 0.5, claw tips | x1.1, no bleed |
| HATCHET SLASH | `slash_bite` 1.3 s | prey 5.2-6.8 m in front | 0.42, jaw/skull + claws | x1.3, **Bleed** (with the hatchet: `tactics.status_clips`), then it pulls back off her |
| SHOULDER-CHECK | `check_left` / `check_right` 1.0 s | prey at its flank, 45-120 deg off its facing, within 3.2 m | 0.45, stepping leg + chest + near claws | x0.9, shoves her 3.5 m sideways |

- **Rake:** it rears with both arms high and the claws trembling, holds, then pitches forward and rakes both arms down through her. The left arm goes a beat ahead.
- **Slash:** the slash-and-retreat bite. The head cocks high to its left with the jaws gaping, then the open upper jaw slashes down through the middle and across to its right.
- **Check:** it leans away, then slams sideways. The near foot steps out into her and the near arm lashes out.
  - The chest is about 4 m up, over a 1.78 m survivor, so at her height it is the leg that connects.
- **Telegraphs:**
  - Each new clip has `tell_fracs` in `anim_events.json`, so a ground ring appears at the start of its held windup.
  - The new `tactics.rings` puts that ring where the move lands, for example beside the flank for the check. Before, every ring was 1.2 m ahead of centre, which is under this animal's chest.
- Order: point_blank is kick, check, grab, rake, slash, heavy, bite. Cooldowns: rake 6 s, slash 9 s, check 5 s.
- **Code** (small, generic; any species can use it):
  - `TacticalBrain`: `_move_row`, `_move_of_clip`, `_move_clip` (front/side arc, side picks the clip), `_play_move`, plus the mult and shove hooks. A side move keeps its flank to the prey instead of turning to face her.
  - `Telegraph.show_for` reads `tactics.rings`.
  - The new clips are added to the ONESHOT/ATTACKS/OPTIONAL/FIGHT_CLIPS lists.

## 3. Carnotaurus kit: NOT DONE (not on canon)
`git log origin/claude/mmo-overhaul --oneline | grep -i carnofeel` is empty as of the final merge. `claude/mmo-carnofeel` (fb8d6988) is finished but unmerged. Send me back when it lands.
- The plan: turn on its charge knockdown and pass-through, its 3-bite chomp combo (an allosaurus `bite_combo` clip with arm rakes) and its wide post-charge turning arc. All through the allosaurus' tactics and its own clips.
- Then extend `t_sp_allosaurus` to cover them.

## 4. Not touched
No roar and no spacing stomp (claude/mmo-theroroar owns those).

## Gates (on the merged head)
- `tools/gait/check_allo.py --height 6.5`: **ALLO_CHECK PASS**, 20 clips. New checks:
  - arms in every attack: lead claw tip >= 1.0 m, the other >= 0.4 m, elbow and wrist >= 30 deg;
  - the rake drives the claws down (24.6 m/s, to 1.23 m);
  - the slash cuts down through the middle (34.7 m/s, side +0.03 m);
  - the check is a sideways lurch (11.7 m/s).
  - Worst stretch: 9.33, in check_right (a 2.8 cm edge in the left hand, limit 10).
- `t_sp_allosaurus`: **PASS**. New checks:
  - the ClawTip offset runs along the hand;
  - in the engine, every attack's claw tip travels > 1.0 m (the other > 0.4 m) and the elbow and wrist each bend > 25 deg;
  - each new move is picked only in its range and arc (the check by side);
  - its ring covers her before the hit;
  - it lands; the slash bleeds and the rake doesn't; the check throws her > 1.5 m sideways.
- `t_hitboxes`: **PASS**. It now also covers `tactics.moves` rows: front moves at the middle and far end of their range, the checks at 60 and 90 deg on each flank. Calibrated radii are in AL8.
- t_knockdown, t_combat, t_sp_carnotaurus, t_tactical, t_canim, t_raptorflank: PASS.
- `run_all.gd`: **[tests] PASS**. `tools/audit_gaits.py --gate`: **GATE PASS**. `tools/smoke.sh --no-import`: **SMOKE PASS**.

## Shots (`docs/orchestration/reports/allofeel/`)
They come from off-screen windowed runs of `allosaurus_lab` (`--position 6000,3000 -- --skip-charcreate --lab=allosaurus_lab --hits-only --close`). The survivor stands where the jaws land.
- `hits_close_sheet.jpg`, `hits_threequarter_sheet.jpg`: every attack at its hit frame, plus the held tells of the hatchet, rake, slash and checks.
- `arms_zoom_rake_grab_ram_check.jpg`: the arms close up.
- `hit_frames/`: every frame from the side, three-quarter and close cameras.

## Rebuild
`tools/gait/build_allosaurus.sh` builds the 4 new clips too. It needs the gitignored Tripo mesh for the rig step.
I built these clips from the committed `allosaurus.glb` with the same poser and `ground_clip.py` step, so the model is unchanged.

## Open (AL7-AL9 in `docs/vision/WildLandsMMO_Open_Questions.md`)
- **AL7:** the new moves' numbers are first guesses.
- **AL8:** the ClawTip offset rows and the calibrated radii.
- **AL9:** the "shoulder" check lands through the leg at survivor height.
- The check rings sit beside the flank, but an attack on her side doesn't turn the camera; the owner should feel-test it in the fight lab.
