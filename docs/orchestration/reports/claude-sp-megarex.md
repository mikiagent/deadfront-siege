# SP-TYRANNOSAURUS -> MEGAREX: the open-mouth T. rex remodel became its own boss

Branch `claude/mmo-sp-tyrannosaurus`, with canon (`origin/claude/mmo-overhaul` d915e67f, incl. PINFEEL, woolly rhino,
megaloceros, smilodon) merged in. Not merged to canon.

## How it got here
- The task: remodel the T. rex with a real jaw (owner "go"), because the old mesh was made mouth-shut and the lips stretched.
- The v2 model was built as a replacement for the T. rex.
- Milan saw it: "Yo you gotta call that monstrosity MegaRex ... lowkey make it a boss fight".
- So v2 is now the boss species **`megarex`**, and the **regular `tyrannosaurus` is back to its canon model, clips,
  howdah, ragdoll and brain**.

**Credits: Tripo 50** (balance 2555 -> 2505).
- One multiview generation, task `7270b4be-bf0b-4ce6-ab92-bbceb3a48eea`, P1-20260311, texture + PBR, 15k faces.
- No retry; no Meshy, Higgsfield, or Tripo rig/anim/retexture.

## The model (`game/assets/creatures/megarex/`, rebuilt by `tools/gait/build_megarex.sh`)
- **Views**: crops of the owner's sheet `trex_owner_sheet_1.png` (side, mirrored side, front, back), padded on the sheet's grey.
- **Mesh**: Tripo matched the sheet. Olive-khaki croc scales, pyramid scutes, heavy brow, a giant head on almost no
  neck, the mouth wide open with separate teeth.
- **Mirror**: Tripo modelled a mid-stride pose (right leg trailing 2 m with a longer thigh). Posing it square stretched
  the thigh into a sheet, so `fit_rex_rig.py` keeps the left half and mirrors it.
- **Rig**: `fit_rex_rig.py` fits the T. rex's 30-bone rig (same names and local axes, so every rex tool carries over).
  - Weights are by distance to the bones, own side only, smoothed over the welded skin. No leg is bound to the
    other side, the old rex bug.
  - Two weighting approaches failed first: shards at the knee, and bone heat leaking the arm into the foot.
- **Jaw**: `add_jaw.py --open --weld` adds a real Jaw bone, bound with the mouth closed.
  - New `--weld`: the glTF UV-seam split made the lips crack open along every seam.
  - Roll fix: a +X turn now opens the jaw on +Y-facing rigs too.
  - Jaw keys are scaled 0.7, so the roar and bites open 31-34 deg, inside the modelled gape. No lip stretch.
- **Size**: 1.3x the T. rex in game: 10.4 m tall, 21.5 m long (MR1).
- **Clips (17)**, made by `make_rex_moves.py --v2` and `make_gait.py`:
  - From the T. rex: heavy idle, roar, lunge bite, stomp, tail whip, pin_foot (PINFEEL), stalking walk/run/strafes/walk_back.
  - New:
    - bite_shake: clamp, four thrashes, fling.
    - hit_react and feed.
    - knockdown, death and sleep, belly-down. Every lying frame settles the skin onto the floor, which fixes the
      old sinking and hovering.
  - Without `--v2` the script reproduces the canon T. rex clips byte for byte (alert and pin_foot checked).

## The boss (MegaRexBrain extends TyrantBrain)
- **Hooks**: TyrantBrain gained small virtual hooks (`_special_attack`, `_tail_ok`, `_pick_attack`, `_windup_s`,
  `_recovery_s`, `_impact_special`). Their defaults keep the T. rex exactly as in canon.
- **Phase 1 (> 66 %)**: bite, bite, stomp. The stomp pins her under the foot (PINFEEL). No tail whip: a target
  behind her draws a turn.
- **Phase 2 (<= 66 %)**:
  - The bite and shake: every third bite on a survivor or a creature <= 3 m. "BITE & SHAKE" telegraph, 1.5x damage,
    and she's flung down (knockdown). Pinned stays the stomp's.
  - The tail whip.
  - Windups x0.8, recoveries x0.9.
- **Phase 3 (<= 33 %)**:
  - Enraged: the status, kept on.
  - A roar on entering the phase, then every 14 s in melee ("ROAR - GET CLEAR", 22 m ring). Survivors and creatures
    <= 3 m go Groggy and flinch; big animals stand.
  - Windups x0.65, recoveries x0.7.
- **Boss bar**: while she fights you, the top target bar holds her even if you target something else. Its strip
  reads "MEGAREX PHASE n [ENRAGED] + the move timer".
- **Not tameable or capturable.** Every kill drops alpha loot: the guaranteed rare rows, the trophy, and the alpha pool
  (alpha_hide 3-4, alpha_fang 3). Butchering is the rex rows x~1.5.
- **Rare**: one MegaRex at most, chance 0.5, in the crater of swamp_55, tundra_55 and volcanic_60.
- **Ragdoll**: no profile, so she dies through her own death clip. A profile changed the size rolls of later spawns
  and tipped the canon T. rex's slope test over its speed guard.
- **Assumptions** (all numbers): MR1-MR5 in `docs/vision/WildLandsMMO_Open_Questions.md`.
- **Name**: the plate shows "Mega Rex", because the game capitalises species names; the boss strip says MEGAREX.
- **Look**: the olive hide Milan saw.
  - The armoured Alpha look (slate recolour from his armoured sheet) is in `megarex/ref/megarex_armoured_albedo.jpg`
    and `tools/gait/rex_alpha_skin.py`, unused.
  - The sheet's horns would need one more Tripo mesh; not spent.

## Shots (`docs/orchestration/reports/sp-megarex/`)
All from off-screen self-quitting windowed lab runs (`--position 6000,3000 -- --skip-charcreate --lab=creature_lab --species=megarex`).
- `contact_sheet.jpg`: 16 clips beside the survivor.
- `hits.jpg`: the bite and shake clamp and thrash, the roar, the stomp, with the boss strip.
- `pin/`: the real stomp-pin on a survivor.

## Gates
| Gate | Result |
|---|---|
| `game/tests/t_sp_megarex.gd` (new) | PASS. It checks: model and clips, 10.4 m, jaw 31-34 deg, standing feet, lying poses, each phase's moves and telegraph times, the bite and shake lands (knockdown, no pin), the roar staggers small / not big / not far / the survivor, cooldown, boss bar pickup and label, the regular rex untouched, not tameable, alpha loot rows, spawn rows |
| `tools/gait/check_megarex.py` | REXCHECK PASS 17 clips |
| `tools/audit_gaits.py --gate` | GATE PASS |
| t_rexclips (regular rex), t_pinfeel, t_noboxes, t_combat, t_godlab (NEXT includes MegaRex), t_alphas, t_canim, t_eyeglow, t_data, t_ragdoll, t_mounts, t_labspawn | PASS |
| `run_all.gd` | [tests] PASS |
| `tools/smoke.sh --no-import` | SMOKE PASS |

The regular T. rex's canon clips still fail `check_rex_clips.py`, as they did before this branch:
- death, knockdown and sleep sink up to 66 cm;
- feed and hit_react slide.

The coordinator kept the regular rex as is, so I left them. MegaRex's tool chain shows how to fix them.

## How to test (owner)
1. Merge this branch into canon, then double-click `tools/fight_lab.command` (GOD mode).
2. Press NEXT (T) until "Mega Rex" spawns; she comes at you. The top bar shows "MEGAREX PHASE 1".
3. Phase 1: stand at her head. Bite, bite, then STOMP: the foot pins you.
4. Hit her below 66 % for phase 2: BITE & SHAKE (thrash and fling), and walk behind her for the TAIL whip; the
   telegraphs are shorter. Below 33 % she roars (ENRAGED): spawn a small animal next to her (SPAWN) to watch it stagger.
5. Kill her and butcher the carcass: it shows the [ALPHA] tag and drops alpha hide and fangs. The regular T. rex
   (also on NEXT) is the old canon model.

## Shared files touched (keep every row on merge)
`creature_clips.gd` OPTIONAL (+bite_shake), `anim_events.json` (bite_shake row, megarex speeds), `tyrant_brain.gd`
(hooks), `creature.gd` (brain pick), `corpse.gd` (boss alpha loot), `hunt_hud.gd` (boss bar), `telegraph.gd` (labels),
`creature_lab.gd` (CLIPSHOTS list; pinshots skips the tame rex), `add_jaw.py`, `check_rex_clips.py` (LYING),
`make_rex_moves.py` (--v2 clips), `islands.json`, `loot_tables.json`, `butchering.json`.

Report head: see the commit that adds this file.
