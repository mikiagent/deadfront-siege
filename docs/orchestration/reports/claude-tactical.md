# Report: TACTICAL (tactical creature combat), Claude

Branch `claude/mmo-tactical` in worktree `mmo-tactical`. Merged: `claude/mmo-mountenergy` (71f77909),
`claude/mmo-overhaul` (latest at hand-off), and `claude/mmo-jaws` a14a8ef6. Nothing pushed, and
nothing merged into canon by me. The owner stopped the deinonychus work at the template stage
("a good template for future work"). Other classes are documented as planned, not built.
Template page: `docs/current/enemy-ai-template.md`.

## What shipped
- **TacticalBrain** (`game/scripts/creatures/brains/tactical_brain.gd`). Any archetype whose
  `ai.json` row has a `tactics` block gets it. Only `pack_flanker` (deinonychus) has one today.
- **Ambush.** The deinonychus lurks beside the tree nearest home (`brain_state` lurk). It strikes
  only inside 6 m, or inside 10 m when the survivor's back is turned, and opens with the pounce
  (up to 10 m). Once it loses the target it walks home and lurks again.
- **Offence from movement: data-defined sequences.** Steps are backstep (a hop_back, at most one
  per sequence), the powerful strafe (dodge_left/right, 2.5 m in 0.42 s), then pounce, charge
  (a run into a bite) or combo (a leap-in into bite_combo). A sequence is picked by weight times
  a nature knob, and only when its finisher is off cooldown and affordable.
- **The basic bite is a last resort**: point blank or during a chase. There is always a beat
  between two basics, and at most 2 in a row.
- **Pounce.** A 0.8 s telegraph with a "POUNCE - ROLL!" ground ring. It aims at the prey's
  predicted position. The hit lands at `pounce.hit_frac` of the clip, for 2.5x bite damage, and
  stuns through the hurt stun. It overshoots 25% of the time (more for Aggressive). A miss
  leaves 1.5 s of punishable recovery.
- **Chomp combo.** Three bites at the `anim_events` `hit_fracs`, for 1.0x / 1.3x / 1.8x. The tell
  ring appears at `tell_fracs[0]`, before the MEGA chomp. A player hit no longer cuts the combo
  short.
- **Back-offs are leaps** (hop_back 3.5 m, leap_back 5 m; the arc scales with distance). There is
  one after an attack. Two back-jumps never come in a row without a strafe, attack, pounce or
  chase between them. They have their own 3.5 s cooldown and never end beyond 12 m.
- **Fillers while nothing is ready**: hold (alert pose; twice as likely while the prey is not
  advancing), strafe, feint, hop. Prey walking away is chased at a full run, or pounced.
- **Retreat when hurt** below 0.4 HP times the nature multiplier: it leaps back, then circles on a
  1.6x ring for 4 s.
- **Direction-aware locomotion for every species and ridden mounts**
  (`CreatureAnim.set_move_velocity`): walk_back when moving against its facing, strafe_left or
  strafe_right when moving sideways, each stride-matched; otherwise walk/run.
- **CreatureClips OPTIONAL** now loads bite_combo, hop_back, leap_back, pounce, dodge_left,
  dodge_right, strafe_left, strafe_right and walk_back when the GLB exists. The OPTIONAL clips
  (sleep, tail_swipe) were never loaded before; they load now.
- **Player.**
  - A hit stuns her for exactly the hurt clip's length (0.79 s): no movement and no swings.
    Walk/run takes over at once afterwards. For 0.8 s after that, hits still damage but cannot
    stun again.
  - The basic swing cooldown is max(1/attack_rate, `basic_cooldown_s` 0.8). Unarmed and rate-1
    weapons stay at 1.0 s.
  - Tackle and Kick now fire. They were silently refused because the auto-attack swing kept the
    player busy, and in the creature lab keys 1-4 forced creature clips. Both now cut the swing,
    say why when they are refused, keep their 8 s and 6 s cooldowns, and stagger the target for
    0.8 s and 0.5 s.
- **Server.** `act.attack {net_id, ms?}` refuses a swing inside the basic cooldown with
  `not_ready`. Creature AI, creature cooldowns and the hurt-stun rule are **client-only**:
  creature hits on a player are not resolved on the server yet (`rolls_dodge` is the hook for
  when they are).

## State machine
approach → circle → sequence [backstep] → [strafe] → pounce | charge | leap-in → combo / bite → one back-off (hop) or hold → circle.
Fillers: hold, strafe, feint, hop. Chase: approach at a run. Hurt: retreat (leap, then wide circle).
Ambush: lurk (roam) → pounce opener.

## Numbers (all ASSUMPTION, `ai.json archetypes.pack_flanker.tactics`)
bite_cd 3.5, combo_cd 10, pounce_cd 12, charge_cd 5, hop_cd 3.5 s. Energy cost: pounce 0.3 and
bite_combo 0.35 of the pool. ring 6.5 m, strafe 2.5 m / 0.42 s, hop 3.5 m, leap_back 5 m, leap-in
≤ 6 m, pounce 4–11.5 m (ambush 10 m), telegraph 0.8 s, pounce 2.5x, overshoot 25% / 3 m, miss
recovery 1.5 s, combo 1.0/1.3/1.8x, retreat at 0.4 HP, max retreat 12 m, filler weights
hold/strafe/feint/hop 0.8/0.3/0.1/0.1, max_basic_streak 2. Natures (`natures.json`):
`tactic_cooldown_mult`, `_feint_mult`, `_standoff_mult`, `_hold_mult`, `_backoff_mult`,
`_overshoot_mult`, `tactic_w_<finisher>` (see the template page table). Player:
`HIT_STUN_IMMUNE_S` 0.8, `basic_cooldown_s` 0.8, tackle/kick `stagger_s` 0.8/0.5.

## Gates (this branch, after the last canon merge)
- `t_tactical`: `[t_tactical] PASS` errs=0 on 5 runs in a row plus 1 run under an 8-process CPU
  load. All 6 printed byte-identical censuses, and a per-frame position/state trace matched
  between runs.
  - Seeded: the global RNG, `CombatTuning.rng`, the per-brain `TacticalBrain.rng`, and the IV
    roll (the IVs set speed and used a randomized RNG).
  - The flank side no longer comes from the instance id, and the idle-slide frame comes from
    spawn order, not the instance id (`Creature._slide_phase`).
  - `Engine.max_physics_steps_per_frame` is 1000, so physics never drops steps under load.
  - Test creatures animate in the physics step.
  - The pounce-vs-combo damage is checked on resolved hits.
  - Hold weight is raised to 0.8, which puts holding at 24% of the cooling time; the 15% bar is
    unchanged.
  - The test builds its own floor, so the canon worktree's untracked nature assets cannot affect
    it.
  It covers:
  - the stun length equals the clip length, walk after the stun, no re-stun inside the
    immunity window, tackle and kick land and respect their cooldowns, the player basic
    cooldown;
  - TacticalBrain and the combo clip load; bites never land inside their cooldown; no move
    starts inside its own cooldown; sequences run their steps in order and none has more than
    one backstep;
  - the strafe covers 2.0–3.2 m within 0.5 s; plain bites are at most 15% of attacks and most
    attacks are pounce, charge or combo; never more than 2 basics in a row, with a beat
    between any two;
  - back-jumps are never adjacent; it holds for at least 15% of the cooling time and never
    goes farther than max_retreat_m; it moves around the target and backs off by jumping
    (displacement within 0.5 s and body lift);
  - the pounce telegraph comes before the leap, and the pounce hits harder than the combo's
    first bite; the combo's 3 hits and its tell ring land at the `anim_events` fracs, with
    rising damage;
  - no specials without energy; it retreats below the HP threshold and circles wider after;
  - the ambush: no aggro outside the radius while she faces it, and the first attack is the
    pounce; it chases or pounces when she walks away, and the gap stops growing; an
    overshot pounce misses, lands past her and recovers;
  - natures change the cooldowns, the ring, the retreat point and the sequence pick rates;
  - the direction-clip unit cases.
- `t_ai`, `t_combat`, `t_turnrate`, `t_canim`, `t_natures`, `t_tame`, `t_capture09`, `t_player`,
  `t_fieldhud`, `t_roll`, `t_energy`, `t_petfollow`, `t_domain`, `t_domaind`, `t_srvdom`: all PASS.
- `python3 tools/audit_gaits.py --gate`: GATE PASS. `bash tools/smoke.sh --no-import`: SMOKE PASS.
  run_all: `[tests] PASS`, with only the known base SCRIPT ERRORs (TouchControls compile order,
  the deliberate econ fault).

## Asserts I changed (owner rules)
- `t_combat` `_reset_player` clears the hurt stun, because a stunned survivor no longer swings.
- `t_tactical` thresholds followed the owner's later rules:
  - "priority when available" was replaced by sequence checks (owner: offence from movement);
  - circling was relaxed to more than 1 rad of travel around the target, now counting strafes
    and hops (owner: shorter circling);
  - "moves while cooling" now also counts holds (owner: hold ground).

## Not done / risks
- Only pack_flanker has a profile. Raptor packs (velociraptor, utahraptor), tyrants and chargers
  keep their old brains, per the owner's scope stop. The class table in
  `creatures-capture-taming.md` marks them as planned.
- Wing rest-hold: I did not check visually whether Wing.* drift in clips with no wing tracks.
  The AnimationTree is deterministic by default, so missing tracks should blend to rest.
- Without a dodge clip, the strafe-loop fallback gets overridden by `play_idle` while the body
  is moved directly. That only matters for species without dodge clips; none of them use
  TacticalBrain yet.
- In the headless tests, a chase with no nav map stops beyond 12 m (Creature's direct-steer
  limit). The game uses tile paths.

## Try it
`Godot --path game -- --lab=creature_lab --species=deinonychus` (god mode). Walk within 6 m or
turn your back within 10 m to trigger the ambush. Q rolls, 1 is Tackle and 2 is Kick in a fight,
F3 prints every move. `--seq=DIR` saves frames; it steps the lurker into range after a second.
PNGs in `docs/orchestration/reports/tactical/`: lurk, pounce telegraph, pounce, hop back, dodge,
combo.

## Round 2 (owner played the lab, 2026-10-28)
- **Further leaps:** hop_back 5.6 m and leap_back 8 m (+60 %), power strafe 3.75 m, stand-off
  ring 8 m, pounce up to 14 m (8 m while chasing, so a long pounce no longer lets her walk off).
- **Pressed, it waits for an opening.** While she closes in it only repositions (strafe-walk,
  power strafe, one backstep). It commits when her swing is recovering or playing, when her back
  is turned, or after 3 s.
- **Basic bite cooldown 7 s.** While the bite is cooling or she presses it, the filler is
  repositioning only (no hold, no feint).
- **Charge** runs at 1.5x the run speed, using the art thread's low `charge` clip, stride-matched
  through `natural_speeds.deinonychus.charge` 6.6. `charge` is in CreatureClips OPTIONAL/LOOPING.
- **Running is faster for everyone:**
  - The survivor runs and sprints x1.25 (8.75 / 10.6 m/s); her stamina drain is x1.3.
  - Creatures run x1.25 in sprint states and drain 13/s.
  - The mount floor follows her new sprint.
- **Refill by exhaustion:**
  - Stamina refill by strain tier is 1.5 / 0.9 / 0.5 / 0.25.
  - Creature energy refills x1.5 when fresh and x0.6 while winded.
  - These numbers are logged as A6-A10 in `docs/vision/WildLandsMMO_Open_Questions.md`.
- **Merged:** claude/mmo-overhaul (fast-forward) and claude/mmo-jaws 8361b5f2 (charge clip, feather
  wings; `deinonychus_feathers.png` and its `.import` are committed).
- **Tests:**
  - t_tactical now asserts:
    - a pressed wait before the first commit, and the commit on the opening;
    - strafing while it waits;
    - strafe and hop distances against the data;
    - the 7 s bite cooldown;
    - repositioning as the main filler;
    - the charge clip at more than 1.4x the run;
    - run speed and drain at the data factor;
    - refill falling with exhaustion.
  - The simulated clock is locked to the physics step count, which keeps the census
    seed-identical. 5 runs gave identical output.
- **Changed asserts:**
  - The t_tactical "holds its ground >= 15 %" check became "repositioning is the main filler"
    (owner rule).
  - run_all's fatigue-stage regen values are now read from `combat_tuning movement` (owner
    rule).
  - The chase check now looks at the closest gap in the last 2 s of 7 s, because a pounce opens
    the gap mid-leap.
- **Gates:** all PASS, plus SMOKE PASS, run_all `[tests] PASS` and audit_gaits GATE PASS.
  - Test scripts: t_tactical (5 identical runs), t_ai, t_combat, t_natures, t_canim, t_turnrate,
    t_tame, t_capture09, t_player, t_energy, t_mounts, t_roll, t_rest, t_fieldhud.
  - verify_jaws deinonychus: JAWS PASS.
