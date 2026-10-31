# ANKYLOCLOSE: the ankylosaurus fights back up close

Branch `claude/mmo-ankyloclose` (from `claude/mmo-overhaul`, merged again before the last test run). No credits spent.

Owner, from the fight lab: "ankylosaurus is hardly fighting back. have it do a stomp attack, a shove attack, a tackle
attack, etc. I should not be able to punch it over and over up close without consequence".

## What shipped

- **Three close moves** in `ClubTailBrain` (`game/scripts/creatures/brains/club_tail_brain.gd`), data in
  `game/data/creatures/ai.json archetypes.club_tail.close_moves` and `close_zone`:
  - **STOMP** (`stomp`, 1.5 s): the front rears off the left forefoot, the foot goes up high and forward, then slams down.
    The hit lands on the frame the foot is back on the ground. It hits a 2.0 m area 4.4 m ahead of the centre (the head
    is 3.6 m out) and knocks the target down.
  - **SHOVE** (`shove_left` / `shove_right`, 1.2 s): it cocks away, then swings its head and spiked shoulders into that
    side while the near forefoot steps out. The hit is a 2.2 m sphere 55 deg to that side, and it knocks the target 3 m
    sideways.
  - **TACKLE** (`tackle`, a 0.9 s coil: crouch, head down, one paw): then a run of up to 2.5 m at 5 m/s on the run gait,
    which is stride-matched, so no glide. It lands on contact just ahead of the snout and knocks the target down.
- **Brain**: a target in the front zone gets STOMP and TACKLE in turn. When she stands past the stomp's reach (6.4 m),
  it always tackles. A target beside it gets SHOVE toward her side. The close moves have their own cooldowns (1.0 to
  1.8 s), separate from the tail's. Behind it or out of reach, the tail moves are unchanged.
  - One punch from close provokes it (`club_tail.provoke_hits: 1`). It skips the alert look-around when the puncher is
    close (`on_aggro`), so it answers about 0.4 s after the first punch lands.
  - It waits for a knocked-down survivor to stand before the next close move.
  - Every move shows the ring and its name ("STOMP - ROLL AWAY"), and a roll dodges it the same way it dodges the tail.
- **Clips** come from `tools/gait/make_tail_club.py`, which has new `pitch` / `shift` / `back` body curves and stomp-shaped
  steps. Every foot stays planted except the one that steps or stomps. They pass `tools/gait/check_ankylo.py`, which now
  includes them in the planted-foot slide check (slide at most 0.007 m, stretch at most 9.9). The clips were grounded
  with `ground_clip.py`. `build_ankylosaurus.sh` builds them by default.
- Engine lists: the new clips are added to `CreatureClips.OPTIONAL`, to `CreatureAnim.ONESHOT` and to `ATTACKS`, so a
  flinch cannot cut them, and to the lab's `FIGHT_CLIPS`. Rows were added to `anim_events.json` and the species JSON clip
  list.
- **Test** `game/tests/t_ankyloclose.gd`. The ankylosaurus is not provoked by hand, and a punch-only survivor in GOD mode
  hunts it.
  - In front: it answers within 1 s of her first landed punch (0.33 to 0.40 s). The first close hit lands within 3 s.
    Both STOMP and TACKLE land in 10 s. It never uses the tail on her. With her standing and close, it is idle at most
    about 0.9 s (limit 2.5 s).
  - Beside it, right and left: SHOVE lands and sends her off that flank.
  - Behind it: no close move, and it still swings the tail.
  - It passed 4 runs in a row on the final numbers.
- **Review lab**: `--lab=ankyloai_lab --out=DIR --moves=stomp,shove_right,tackle` now covers the close moves.
- **Docs**: the fight-lab row is updated. The defaults are AC1-AC8 in `docs/vision/WildLandsMMO_Open_Questions.md`.

## Review shots (`docs/orchestration/reports/ankyloclose/`)

- `<move>_windup_high.png`: the ring and the name during the wind-up.
- `<move>_hit_high.png` / `_hit_low.png`: the frame the hit lands.
  - The stomp: the forefoot is back down and the head is dropped.
  - The shove: the head and shoulders are turned into her side.
  - The tackle: the run is over and the snout is at her.
- `rig/`: Blender renders of the clips on the rig, from the side and the front, at 0.40/0.50/0.60 (tackle at 0.50/0.95).

Fixed after looking at my own shots:
- The stomp first landed on a fixed fraction, while the foot was still in the air, because the tree's crossfade put it a
  few frames late. It now lands when the foot bone is back within 0.12 m of the ground.
- The tackle's contact sphere was too big: it landed 1.5 m short of the snout with no visible run. It is now 0.5 m.
- The stomp's foot lift went from 0.54 m to 0.72 m and the body pitch from 8 to 12 deg, so the rear-up reads.

## Tests run (after merging origin/claude/mmo-overhaul)

t_ankyloclose PASS, t_ankylo3d PASS, t_ankyloai PASS, t_combat PASS, t_tactical PASS, t_canim PASS,
t_compyfeel PASS, run_all `[tests] PASS`, `tools/smoke.sh` SMOKE PASS.

The run_all log opens with the `Identifier not found: Game` compile error (vitals.gd) and the
`Nonexistent function 'new'` lines. That load-order noise is not from this change: none of those files were touched, and
the run still ends in PASS.

## Assumptions / open points

- AC1-AC8 in the Open Questions doc cover the zone, the move order, the cooldowns, the damage, the hit shapes, provoke on
  one punch, no hits on a downed survivor, and the tackle without an impact clip.
- AK6 from ANKYLOAI ("never runs, never closes under 2 m") no longer holds in front: the tackle runs.
- Balance: each close move still one-shots a fresh 100 HP survivor at attack 420, the same as the tail moves (AK1).
- The tackle has no body-slam clip on contact. It is the coil, then the run gait, then the knockdown. A slam clip would
  read better; that is for the next art pass.
- A tamed ankylosaurus (PetBrain) does not use the close moves.
- Not done: the jaw is not keyed on the new clips (the mouth stays at rest, as in tail_swipe).

## For the next agent

The numbers are all in `ai.json club_tail.close_moves` / `close_zone`. Regenerate the clips with
`Blender -b -P tools/gait/make_tail_club.py -- game/assets/creatures/ankylosaurus/ankylosaurus.glb OUT stomp shove_left shove_right tackle`,
then run `ground_clip.py` and `check_ankylo.py`.
