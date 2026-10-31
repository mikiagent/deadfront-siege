# BIGSTOMP: big dinosaurs stomp what is under them; pins come only from a visible stomp or grab

Branch `claude/mmo-bigstomp`: cut from `origin/claude/mmo-knockdown`, then merged with `origin/claude/mmo-ankyloclose`
and `origin/claude/mmo-overhaul` (merged again before the final runs). Not merged to canon. No Tripo or Meshy credits spent.

Owner, verbatim: "ankylosaurus is WAY WAY better in terms of attacks. I think the bigger dinosaurs all need a stomp
mechanic where if you get close they will stomp the ground, shake the screen, and if you get stomped you probably take
a lot of damage or die. Maybe you get pinned by the stomp attack -- hey i think we actually needed that because the
trexes would pin me and it would teleport me under their feet, so if you get there by getting pounced or stomped its
more avoidable"

## What shipped

### 1. The shared stomp (`game/scripts/combat/big_stomp.gd`, data `ai.json big_stomp`)
- `CreatureBrain` owns one `BigStomp` and ticks it before its own think, so every brain gets it without code of its
  own. `stomp_ready()` gates it: fighting a live target, no timed move of its own in flight, no one-shot playing.
  `TacticalBrain` overrides it, because all its fight states count as timed moves: it may only cut in while
  approaching, circling, holding or doing a plain attack.
- **Who stomps:** species JSON height >= 2.9 m, a `big_stomp` clip on the rig, and not a pet.
  - `"big_stomp": false` in a tactics profile (species or archetype) or in an archetype row opts the species out.
    `club_tail` does this, so the ankylosaurus keeps its own stomp.
  - `true` or a dict opts a species in, or overrides numbers.
  - Stegosaurus has no clip, so the helper is idle on it. stegospin can turn it on by adding a `big_stomp` clip and an
    `ai.json big_stomp.species.stegosaurus` row, or by putting `big_stomp: {...}` in its tactics. I did not touch any
    stegosaurus data.
- **Which species:**
  - tyrannosaurus, tarbosaurus, megarex
  - carnotaurus, triceratops, styracosaurus, woolly rhino
  - therizinosaurus and ceratosaurus. Both are on canon now; I treated them as "other big modelled species".
  - Not included: gallimimus, megaloceros, raptor and utahraptor. They are agile runners and get no clip.
  - Allosaurus and brachiosaurus have no model yet. Each gets the stomp once its rig has a `big_stomp` clip.
- **When it stomps:** its target is standing (not knocked down, not pinned) inside the near ring round the spot where
  the foot will land. That spot is under the body: `land`, measured in game per species. Cooldown 3.5 s.
- **The telegraph** (`Telegraph.show_stomp`):
  - A yellow near ring (0.42 x body height) with the foot's dark shadow inside it (the direct ring, 0.16 x height),
    and the text "STOMP - ROLL AWAY".
  - The wind-up runs from 0.6 s on a 3 m animal to 0.9 s on a 10 m one.
  - `play_timed_attack` scales the clip so the foot lands at the end of the wind-up.
- **The slam:**
  - A dust burst.
  - A camera shake through `IsoCamera.shake`: 0.45 to 0.9 trauma by size, fading to nothing at 3x the ring. The
    existing `--reduce-shake` setting turns it off.
  - In the shadow: 2.5 x attack (a T. rex kills a fresh survivor outside GOD), then Pinned under the foot.
  - In the ring: 0.35 x attack and a knockdown (the PlayerKnock tier, pushed away from the foot).
  - A roll in its opening window, or being outside the ring, dodges it.
- **The stomp-pin** is PINFEEL's pin:
  - The `pin_foot` clip holds and the survivor plays her lying `pinned` loop.
  - The animal bites once 1.5 s in (0.6 x attack). The bite starts no flinch and no retaliate order.
  - Pinned runs its 4 s timer. Nothing in the code fires a struggle input yet, so "struggle out" is the timer.
  - The raid kit still blocks the T. rex's pin.

### 2. The pin teleport: cause and fix
- **Cause:** `PinHold.snap` slid the victim toward the claws exponentially (tau 0.08 s) from wherever the hit found her.
  - The tyrant heavy lands on anything in front within its whole reach. So a stomp that landed 5 m from her still
    pinned her, and the snap pulled her under the foot: about 19 % of the gap each frame, up to ~1 m in one frame.
  - The tarbosaurus' jaw clamp did the same from its jaws.
- **Fix:**
  - `PinHold.can_start`: a foot pin starts only on a victim whose chest is already within 0.3 x body height of the
    pinning foot. Otherwise `CreatureAttack._pin_missed` takes Pinned off and knocks her down instead.
  - The tarbosaurus' burst is a pounce-grab, so its row allows 0.8 x height; its jaws carry her the short way.
  - `PinHold.snap` is now speed-capped at 3 m/s (tarbosaurus 6 m/s). Measured: 0.05 m a frame at most.
  - The same cap is on `TacticalBrain`'s raptor and smilodon pin hold.
  - Pinner and victim stop colliding during the pin. Under the belly, the capsule kept pushing her back out. They
    collide again once she is clear of its body.
  - `Creature.start_pin` now returns whether it pinned.
  - The pinning foot is per species: `ai.json big_stomp.species.<id>.pin_bone / pin_reach`. The rex keeps Toe.R + 0.85.

### 3. Clips
- **Generic author:** `tools/gait/make_big_stomp.py` with the leg maps in `tools/gait/big_stomp.json`. It makes
  big_stomp and pin_foot for carnotaurus, triceratops, styracosaurus, woolly rhino, therizinosaurus and ceratosaurus.
  - In big_stomp:
    - The weight shifts off the stomping leg and the body rears.
    - The foot is hauled up, held trembling, then slammed down a little ahead of and inside its print at 0.72.
    - The body drops and shudders, and the foot steps back.
    - Every other foot keeps a fixed plant point. The legs are solved two-bone, and the lower bones keep their rest
      tilt.
  - pin_foot starts on the impact pose, then presses the foot down at a lying survivor's chest height and holds it.
- **Tyrannosaurs:** `make_rex_moves.py big_stomp` is their attack_heavy stomp under its own name (rex, `--v2` megarex,
  `--tarbo`).
  - The tarbosaurus' pin_foot now starts from that stomp, because its pins come from the stomp. Its burst-pin
    crossfades from the lunge pose.
- **Gate:** `tools/gait/check_big_stomp.py`. It checks planted-foot slide, the stomp foot's height at the impact frame,
  its peak and skin sink.
  - Every clip passes: slide 0.000 m, foot on the ground at 0.72, peak 0.8 to 3.9 m.
  - The styracosaurus' impact crouch was cut to stop a 0.33 m tail sink (now -0.04 m).
  - Every clip was then run through `ground_clip.py` (tarbosaurus big_stomp lifted 0.11 m on one frame).
- **Engine lists:** `big_stomp` was added to `CreatureClips.OPTIONAL`, `CreatureAnim.ONESHOT` (not ATTACKS:
  BigStomp lands the hit itself) and `anim_events.json`, plus the species JSON clip lists.

## Tests
- **`game/tests/t_bigstomp.gd` PASS.**
  - Roster: the 9 species have the stomp; ankylosaurus, stegosaurus and velociraptor do not.
  - Per species, she stands in the shadow:
    - it stomps within 0.6-0.9 s;
    - the foot lands inside the shadow (0.00-0.34 m from the centre);
    - it is a direct hit, she is Pinned and it holds `pin_foot`;
    - the shake is 0.4-0.9 and IsoCamera's trauma rises;
    - her chest is under the foot (0.00 m);
    - it lets her go when Pinned ends.
  - Outside GOD, a direct T. rex stomp kills her (100 -> 0).
  - A near miss is a knockdown with no pin.
  - Rolling as the foot comes down: no damage, no pin.
  - The rex, tarbosaurus and megarex heavy:
    - landing away from the foot: a knockdown, no pin;
    - landing at the foot: a pin.
  - Biggest move in one frame while pinned, over every pin: 0.050 m (limit 0.5).
- **After the second overhaul merge, PASS:** t_pinfeel, t_rexclips, t_combat, t_tactical, t_canim, t_noboxes,
  t_sp_tarbosaurus, t_sp_carnotaurus, t_sp_woolly_rhino, t_godlab, t_sp_raptor, t_sp_smilodon, t_cornered (earlier
  also t_capture09, t_tame, t_ragdoll), `run_all` `[tests] PASS`, `tools/smoke.sh` SMOKE PASS.
- **FAIL, already failing before this work.** The same failures show on the knockdown + ankyloclose + overhaul merge
  commit `ebeca1a9` without any BIGSTOMP change:
  - `t_knockdown`: "styracosaurus charge_shove_m 4.0 m x size 1.50 -> tier 2 (want 1)". STYRAFIX made the
    styracosaurus 3x bigger, so its charge now throws. Either the test's expectation or the number needs the owner's
    call.
  - `t_ankyloclose`: "close hits land ... / both front moves land". On the merge base it was 3 fails, including the
    shove; now it is 2. With knockdown merged, a knocked-down survivor lies longer, so fewer close moves fit in 10 s.
  - Not changed here; both belong to the knockdown and ankyloclose owners.
- No duplicate `func` names in any merged .gd file.

## Review shots (`docs/orchestration/reports/bigstomp/`)
They come from `--lab=creature_lab --god --skip-charcreate --species=X --stompshots=DIR` (new flag), windowed at
`--position 6000,3000`, self-quitting. Per species, `<species>_<k>_<what>.png`:
- `0_windup_game`: the ring and shadow on the game camera.
- `1_windup_side`: the foot up.
- `2_slam_side`: dust, and the foot on her.
- `3_slam_game`
- `4_pinned_low`

What I saw:
- The tyrannosaur family and the carnotaurus read clearly: foot up over the ring, dust burst, her under the claws.
- On the quadrupeds the stomping forefoot faces the lit side poorly: the three-quarter camera is backlit. The lab's
  fixed cameras also miss her in several `pinned_low` frames (triceratops, styracosaurus, woolly rhino, rex). The
  test measures the pin there (chest 0.00 m from the foot).
- The woolly rhino run caught a near miss: it turned during its approach, so she was in the ring, not the shadow.

## Assumptions (Open Questions BS1-BS8)
These are size threshold 2.9 m, ring and shadow sizes, wind-up 0.6-0.9 s, damage 2.5x / 0.35x, cooldown 3.5 s, no
stomp on a downed target, one bite at 1.5 s while pinned, Pinned still on its 4 s timer (no struggle input exists),
shake numbers, pin reach 0.3x height (tarbosaurus 0.8x), slide 3 m/s (tarbosaurus 6), and one stomping foot per
species.

## For the next agent
- **Numbers:** all in `ai.json big_stomp`.
- **A new species:**
  1. Add a leg map to `tools/gait/big_stomp.json`.
  2. Run `Blender -b -P tools/gait/make_big_stomp.py -- <base.glb> <species> <out>`.
  3. Run `ground_clip.py --fps 24` and `check_big_stomp.py`, then copy the clips to `anim/`.
  4. Add an `ai.json big_stomp.species.<id>` row: `land` from the t_bigstomp print, plus `pin_bone`.
- **Ideas:**
  - A mirrored clip, so it can stomp with the nearer foot.
  - A struggle input that clears Pinned (`statuses.json cleared_by: struggle`).
  - A tamed big pet does not stomp; that is an owner call.
