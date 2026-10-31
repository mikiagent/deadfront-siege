# ANKYLOAI: the ankylosaurus fights with its tail club

Branch `claude/mmo-ankyloai` (from `origin/claude/mmo-overhaul` cf3128fc). Not merged to canon. Credits: none.

Owner (Milan, after the god-mode fight lab):
- "ankylosaurus is doing the rush and tackle strategy, it hits too often. I want it to hit HARD. Like it should be smashing that tail around, tail whip, tail smash, etc"
- "ideally the ankylosaurus keeps feet planted or steps in the direction for the swing. It looks like he's gliding when performing the tail attack and the tail doesn't even look like its hitting me"

## What changed
- **ClubTailBrain** (`game/scripts/creatures/brains/club_tail_brain.gd`, picked for archetype `club_tail` in `Creature._make_brain`).
  - It never rushes or tackles. In a fight it shuffles at its walk speed (strafe and walk_back clips, never run).
  - It turns its tail toward the threat until the target stands on the next move's aim spot, then swings.
  - While a move plays it does not move or turn in code. The clip's own steps carry the body.
  - The hit comes from the club: a 1.1 m sphere round the Tail5 tip, checked every physics frame of the move's strike window. It lands at the club's closest pass. The smash lands on the frame the club comes down to the ground.
  - A survivor at its head is never hit.
  - Each move shows a ring where the club will pass, and its name ("TAIL WHIP - ROLL OR GET TO ITS HEAD"), from the first frame until the hit.
  - Damage goes through `CreatureAttack.apply_for`, so a roll in its opening window dodges, as with every other attack.
  - `Creature._on_hit` and `_on_windup` skip this brain, so the old reach-from-centre hit and the ring ahead of the snout are gone.
- **Moves** (numbers in `ai.json archetypes.club_tail.club_moves`, all ASSUMPTION AK1-AK8 in `WildLandsMMO_Open_Questions.md`):

| Move | Clip | Wind-up (tell) | Strike | Damage | Effect | Cooldown |
|---|---|---|---|---|---|---|
| TAIL WHIP | attack_primary 2.0 s | 1.0 s: tail cocks left and rattles, head looks back at you, front-foot stamp | club sweeps behind and round the right flank; aim spot 120 deg right, 3.0 m | 420 x 0.8 | 3 m knockback | 3.5 s |
| TAIL SMASH | attack_heavy 3.0 s | 1.9 s: front feet step out into a brace, tail rises overhead curled, trembles, roar | slams down behind it; aim 165 deg, 3.0 m | 420 x 1.6 on the club | knockdown; shockwave 2.6 m round the club at x0.35 with a 2 m push | 6 s |
| CLUB SWEEP | tail_swipe 2.6 s (new) | 1.1 s: tail drawn far left and low, stamp, head looks back | one long low arc from left through straight behind to the right, all four feet stepping round; aim 180 deg, 2.8 m | 420 x 1.0 | 3.5 m knockback | 5 s |

  - Order when facing one survivor: whip, whip, smash, whip, sweep. The sweep also plays whenever two threats are within 6 m.
  - Cooldowns are x0.6 while enraged.
- **Clips** (`tools/gait/make_tail_club.py`, rebuilt):
  - Every foot is planted, with its pose fixed, except inside a scheduled step. A step lifts the foot on an arc and lands it on a new plant turned about a pivot near the shoulders.
  - The body yaws a few degrees over planted feet, and bigger yaws ride on steps.
  - The whip steps both hind feet into the swing and back.
  - The smash steps the front feet out into a brace and back in.
  - The sweep pivots on steps of all four feet.
  - The club is lifted out of the floor if a slam would bury it.
  - Then the clips get jaw keys (`key_jaw.py --hit 0.58 --heavy-hit 0.65`) and go through `ground_clip.py`, which lifted nothing. `build_ankylosaurus.sh` is updated.
  - alert and sleep are unchanged.
- **Gates added**:
  - `check_ankylo.py` now fails a tail move or alert if a planted foot slides more than 3 cm. It measures the sole, the vertices weighted 0.9 or more to the foot bone.
  - It also reads `club_moves` and fails a move if:
    - the club misses its aim spot (more than the hit radius minus the survivor radius),
    - the club is slow there,
    - the club comes near a survivor at the snout,
    - or the smash's club never comes down.
  - It prints the club path (bearing, distance and height per frame); the aim spots were set from it.
  - The old "club 1.5 m to the side at hit_frac" check is gone.
- **Fight lab**: the info line names ClubTailBrain and its moves. In `docs/current/fight-lab.md` the Ankylosaurus row now has the new brain, moves and clips, with the verdict "reworked per owner 2026-10-31, re-test".
- `t_ankylo3d`: the old checks "club to the side at the hit" and "attack_primary hits from the centre" are replaced. A wild ankylosaurus runs ClubTailBrain, and its whip played at a survivor in front of its snout does not hurt her.
- `ankylo3d_lab` also shoots tail_swipe; its hit-% marks follow the new club passes.
- New review lab: `--lab=ankyloai_lab --out=DIR`.

## Gates (all on the final tree)
- `check_ankylo.py --height 2.25`: **ANKYLO_CHECK PASS**, 15 clips.
  - whip: slide 1.7 cm, club 0.33 m from the aim spot at 20.6 m/s, 5.5 m from the snout.
  - smash: slide 1.3 cm, club 0.09 m from the spot, 6.6 m from the snout.
  - sweep: slide 1.6 cm, club 0.29 m from the spot at 15.2 m/s, 5.6 m from the snout.
  - Worst stretch is 6.5; the lowest skin point is -1.0 cm.
- `game/tests/t_ankyloai.gd`: **PASS**. Per move it checks:
  - the Godot club bone passes the aim spot within the radius and never nears the snout;
  - the ring and name are up from frame 1, and still up when the club lands;
  - the hit lands after the wind-up: whip 1.28 s after a 1.00 s wind-up, smash 2.02 after 1.86, sweep 1.53 after 1.14;
  - the club is 0.3 to 0.5 m from her at the hit;
  - the body neither turns nor slides in code while the clip plays (0 rad, 0 m);
  - a survivor at the snout takes 0 hits;
  - the smash knocks her down, hits with the club when it is down at 0.89 m, and hits a survivor straight behind it.

  Beyond the per-move checks:
  - A roll pressed 0.12 s before the whip lands takes no hit.
  - In a 40 s fight starting at 9 m, it never ran or charged.
  - Its top speed was 0.99 m/s, and it never came closer than 2.3 m.
  - It played 6 moves, each started with her within 4 deg of its aim bearing (all on the tail side).
  - It landed 5 hits, the closest two 5.5 s apart (gate: 3 s).
- t_ankylo3d, t_combat, t_canim, t_godlab, t_ai: PASS. `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## Shots (`docs/orchestration/reports/ankyloai/`)
They come from self-quitting windowed runs off-screen: `--position 6000,3000 -- --skip-charcreate --lab=ankyloai_lab --out=DIR`.
- A live creature swings at the survivor on its aim spot in GOD mode. The tree pauses on the frame the club hits.
- `<move>_hit_high.png` / `<move>_hit_low.png`: the club is on the survivor at the hit (caption: club 0.3 to 0.5 m from her). The smash shot shows the club down at her legs.
- `<move>_windup_high.png`: the ring and name during the wind-up. The smash shot shows the tail raised overhead.

What I fixed after looking at my own shots:
- The first whip hit landed as the club touched the edge of a 1.3 m sphere, with the club visibly beside her. I changed it to land at the club's closest pass, with a 1.1 m radius.
- The smash landed while the club was still at head height. In Godot the slam plays a few frames after the authored timing, so the hit is now triggered by the club's height.
- In the windowed run the whip's club passed at the very end of its window. I widened the window.

## For the next agent / risks
- **Pets**: a tamed ankylosaurus (PetBrain) still hits by reach at the global `hit_frac` (0.42 / 0.72). That now falls in the wind-up of the longer clips, so its hit lands early (AK8). Not in scope.
- The aim spots are calibrated to these clips. If you re-author them, re-run `check_ankylo.py`, read the printed club path, and update `club_moves`. t_ankyloai will fail if they drift.
- The survivor's auto-kick shoves the animal 0.8 m in one frame. That is the survivor's tactic, not the ankylosaurus moving.
- Balance (AK1): every move still one-shots a fresh, unarmoured 100 HP survivor at attack 420. This was true before the change too.
- Not checked by the owner yet: the feel in the windowed fight lab. The verdict column says "re-test".
