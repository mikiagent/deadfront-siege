# claude-pinfeel: Pinned puts the victim on its back, and the T. rex pins with its foot

Branch `claude/mmo-pinfeel`, cut from `origin/claude/mmo-overhaul` 0152e8d4. Not merged to canon.

Owner, verbatim: "pinned should force the player/animal in the lying down animation or something like that. It
would be cool if the trex or whatever physically pinned the target with a foot".

## What shipped

### 1. The victim lies down for the whole pin
- **Survivor**: she drops with `knockdown`. About 1 s in, when she is on her back, she blends into the new `pinned`
  loop until Pinned ends, then stands.
  - The `pinned` loop is 2 s and was authored in headless Blender from knockdown's last frame (`tools/make_pinned.py`).
  - In the loop she shoves up at the foot with both hands in turn, kicks one leg then the other, turns her head side
    to side, and her chest heaves and writhes.
  - A hit during the pin does not stand her up into a flinch.
  - Code: `PlayerAnim._tick_pinned`.
- **Animals**: a Pinned animal holds its knockdown pose (`CreatureAnim.hold_down`) and gets up when Pinned ends.
  - Unlike a real knockdown, this opens no capture window.
  - A status tick (Pinned does 2 HP/s) or a hit no longer flips a downed animal into hit_react. This also fixes the
    same thing for a Knockdown-status animal.
- **Can't move or attack**: this was already true through the status's `cannot_act` flag. It is now tested.
- **Break-free**: the game has none. `statuses.json` lists Pinned as `cleared_by: struggle, pet_aggro`, but nothing
  in the code fires either of those. I did not invent one, so Pinned ends on its 4 s timer.

### 2. The T. rex pins with its foot
- **Clip**: `pin_foot`, 4 s, held on its last frame. Added to `tools/gait/make_rex_moves.py` on the current 30-bone rig.
  - It starts on the stomp's impact frame (attack_heavy at 0.72).
  - The right foot rises and comes down on the victim, toes curled down, 0.30 m up, 1.8 m ahead, toward the midline.
  - She crouches over it, nose-down with the neck curled, then holds through two growling breaths with small head
    shakes and the tail up.
  - The head comes as low as the rig allows. It cannot reach the victim, which is 3 m behind the snout on this body.
- **Game wiring**:
  - When a hit applies Pinned and the attacker's rig has a `pin_foot` state, the attacker calls `Creature.start_pin`
    (from `CreatureAttack._apply_token`). Today that is only the T. rex.
  - The creature holds still. Its brain pauses (`CreatureBrain` returns early while `pin_victim` is set), and
    `Creature._tick_pin` keeps the victim under the foot.
  - It lets go when Pinned ends, or when either of them dies or is freed. On release it blends back to idle over 0.3 s.
  - The TyrantBrain recovery (PUNISH) window picks up after the release.
- **Foot placement**: I moved the victim to the foot rather than IK-placing the foot. This is `PinHold`
  (`game/scripts/combat/pin_hold.gd`).
  - The victim faces the rex, so on her back her head points away from it.
  - Each physics frame she is slid on the ground plane until her chest (Spine2) is under the claws (Toe.R + 0.85
    along the bone).
  - First try, the chest under the middle of the toes: the 12 m rex's foot hid her completely. Now her head and
    arms stick out in front of the claws, where the camera sees them.
- **Other pinners**: Tarbosaurus also lists `pinned`, but it has no model or rig. It keeps the old behaviour: the
  victim lies down, with no foot. Any species that later gets a `pin_foot` clip gets the foot pin with no code change.

### 3. Telegraph and fairness
- **ASSUMPTION**: a foot-pinner (any species with `pin_foot`) applies Pinned only with its telegraphed heavy, never
  with a bite.
  - For the T. rex, that heavy is the stomp: a 1.2 s windup with the foot hauled up, under the "STOMP - ROLL OR GET
    CLEAR" ring.
  - Before this, every T. rex bite applied Pinned. The rex kept biting during the pin, and each bite refreshed it, so a
    survivor without the raid kit could be held down until she died.
  - Now the rex holds still while it pins and cannot attack.
- Damage while pinned is the existing status data (2 HP/s for 4 s). The raid kit still prevents Pinned.
- `raid_gear_probe.gd` now applies its Pinned token with `attack_heavy`, so it still tests that the kit blocks the pin.

## Shots

In `docs/orchestration/reports/pinfeel/`. They come from an off-screen windowed run: `--position 6000,3000`,
self-quitting, `-- --lab=creature_lab --god --skip-charcreate --species=tyrannosaurus --pinshots=DIR`. This is a new
lab flag, and the shots show the brain's real stomp, not a forced clip.

| File | What it shows |
|---|---|
| `pin_0_windup.png` | Game camera: the stomp windup and the STOMP telegraph ring |
| `pin_1_plant.png` | Game camera: the foot coming down; she is falling |
| `pin_2_held_wide.png` | Wide three-quarter view: the rex crouched over her, foot planted |
| `pin_3_held_low.png` | Low camera beside her: on her back, claws on her chest, head and arms out in front, struggling |
| `pin_4_held_game_cam.png` | What a player sees: the rex goes see-through over the survivor and she shows under the claws |
| `pin_5_released.png` | Pinned is gone: the rex back to idle, she is up and fighting, PUNISH counting down |

I looked at every frame.

## Gates

| Gate | Result |
|---|---|
| `t_pinfeel` (new) | PASS. A Pinned survivor goes down, then plays the pinned loop, and tap-to-walk moves her 0.00 m. A hit does not stand her up. A Pinned raptor holds its knockdown pose with no capture window and stands when the pin ends. A bite does not pin. The stomp pins and the rex plays and holds `pin_foot`. The claws end 0.07 m from her chest (tolerance 0.45), with the foot 0.25 m up. When the timer runs out the rex goes back to idle, having held still, and she stands and walks |
| `t_combat`, `t_rexclips`, `t_canim`, `t_godlab` | PASS |
| `t_capture09`, `t_tame`, `t_ai`, `t_ragdoll` (they cover the downed-animal hit_react change) | PASS |
| `run_all.gd` | `[tests] PASS` |
| `tools/smoke.sh --no-import` | SMOKE PASS |
| `check_rex_clips.py`, 11 clips incl. `pin_foot` | PASS, worst sink 2.5 cm, pin_foot sink 0.7 cm, no slip |
| `audit_gaits.py --gate` | GATE PASS |

About `check_rex_clips.py`: `pin_foot` is in a new HELD set, so its first and last frames are not required to be on
the prints. It starts on the stomp's impact and ends on the held pin. Sink, float, slip and grounded are still checked.

Credits: 0.

## Not done, and risks
- **Getting up**: release pops her from lying to idle with no get-up clip. This is the same as the existing
  knockdown release.
- **Height**: the foot's height is fixed in the clip, sized for a lying survivor's chest. A bigger pinned animal (a
  pet) is slid under the claws in x/z only, so the foot may sink into its body. No pet-vs-rex pin was looked at.
- **Ridden mount**: a ridden mount that gets Pinned still moves under its rider. The ridden path runs before the
  status checks; this was already so.
- **No break-free**: if the owner wants struggle-to-escape or a pet pulling the rex off, the hook is
  `statuses.json` `cleared_by` and `StatusEffects.clear_by_item`. That needs a design call.
- **Pinned survivor and other creatures**: while she is pinned, other creatures can still hit her, as before.
- **Jaw**: the rex's jaw opens 12-21 deg in the hold. That is small enough that the known mouth-shut mesh stretch
  barely shows.

## Next agent
- If Milan wants the head right over the victim: the neck cannot reach on this rig. It would need the rex to step
  back (root motion), which no clip has today. Or wait for the v2 open-jaw model.
