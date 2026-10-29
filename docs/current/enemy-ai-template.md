# Enemy AI template: class profiles, sequences, cooldowns

How a wild creature fights, as the build runs it today. Classes on it: the deinonychus (`pack_flanker`,
the template), the compsognathus (`swarm`) and the herd grazers (`pack_mule`: zebraceratops, protoceratops).
Code: `game/scripts/creatures/brains/tactical_brain.gd` (`TacticalBrain`), data:
`game/data/creatures/ai.json` → `archetypes.<archetype>.tactics`, test: `game/tests/t_tactical.gd`.

## Who gets it
`Creature._make_brain` gives `TacticalBrain` to any non-pet whose archetype row has a `tactics`
block (`TacticalBrain.has_tactics`). Pets keep `PetBrain`. The T. rex keeps `TyrantBrain`. Every
other species keeps `RaptorPackBrain` or `CreatureBrain` until its class gets a profile. The
shared rules in `CreatureBrain._pre_think` still run first: leash, sleep, walking home, LOD
freeze.

## States
`approach` → `circle` (strafing at the stand-off ring) → a **sequence** → its finisher (`pounce`,
`charge`, `lunge` leap-in → `combo`/`attack`) → one back-off (`hop`), or `hold` when a back-off is
not allowed. The fillers are `hold`, `circle`, `feint`, `hop` and `dodge`. `retreat` happens
below `retreat_frac` HP. `lurk` (shown as `brain_state`) is the ambush idle.
Full-rate thinking runs in every one of these states (`_full_rate`).

## Profile format (`tactics`, every number an ASSUMPTION)
| Key | Deinonychus | Meaning |
|---|---|---|
| `sequences` | 7 rows | `{name, steps[], weight}`; the last step is the finisher |
| `point_blank` | `[combo, bite]` | at contact, after `contact_after_s` 1.0 s of circling |
| `ring_m`, `circle_min_s`/`max_s` | 8 m, 0.5–1.0 s | stand-off ring and filler beat length |
| `bite_cd` / `combo_cd` / `pounce_cd` / `charge_cd` / `hop_cd` | 7 / 10 / 12 / 5 / 3.5 s | each move's own cooldown, committed when the move is picked |
| `pounce_telegraph_s`, `pounce_mult`, `pounce_min_m`/`max_m`, `chase_pounce_max_m` | 0.8 s, 2.5×, 4–14 m, 8 m | pounce windup with a ground ring, damage, range |
| `pounce_overshoot_chance`, `_m`, `pounce_miss_recover_s` | 0.25, 3 m, 1.5 s | sail past the prey; a miss leaves a longer punish window |
| `combo_mults` | 1.0 / 1.3 / 1.8 | damage of each `bite_combo` hit |
| `strafe_m`, `strafe_s` | 3.75 m, 0.42 s | the powerful strafe (dodge step) |
| `hop_m`, `leap_back_m`, `leap_in_max_m`, `leap_height_per_m` | 5.6, 8, 8 m, 0.2 | leap lengths (the profile's, not the body's); arc height rises with distance |
| `max_retreat_m` | 16 m | no back-leap ends farther from the prey than this |
| `w_hold` / `w_strafe` / `w_dodge` / `w_feint` / `w_hop` | 0.8 / 0.3 / 0.3 / 0.1 / 0.1 | filler weights; hold ×2 while the prey is not advancing; while the bite cools or the prey presses, only strafe / dodge / hop |
| `wait_max_s`, `opening_swing_cd_s` | 3 s, 0.2 s | pressed: wait for an opening (her swing recovering, her back turned) before committing |
| `charge_speed_mult` | 1.5 | the charge runs at 1.5× the run, using the `charge` clip when the rig has it |
| `max_basic_streak`, `max_basic_share` | 2, 0.15 | anti-spam: basics in a row; the share the test allows |
| `retreat_frac`, `wide_ring_mult`, `wide_circle_s` | 0.4, 1.6, 4 s | back off when hurt, then circle wider |
| `ambush`, `cover_m`, `ambush_radius_m`, `back_radius_m`, `ambush_pounce_max_m` | true, 14, 6, 10, 10 m | lurk at the tree nearest home and open with the pounce |

## Modifier blocks (`tactics.<block>`, multiplied together)
A block is `{knob: factor}` over the profile's own knobs (`cooldown_mult`, `w_<finisher>`,
`combo_seq_mult`, `w_dodge` / `w_hop` / `w_strafe` / `w_feint`, `beat_mult`, `wait_mult`,
`retreat_frac_mult`). It is active when:
- `enraged`: the creature is enraged. The nature's `enrage_mult` pulls each factor toward 1.
- `pack_bold`: at least `pack_bold.n` live packmates are on the fight (bolder in numbers).
- `alone`: no live packmate is left.
- `weak_prey`: the prey's HP fraction is under `weak_prey.hp_frac` (opportunistic).

Genetic alphas are separate: `tactics.alpha` multiplies the nature knobs (Creature.nature_knob).

## Swarm extras (compsognathus)
- `surround: true`: each packmate steers to its own slot on the ring, evenly spaced by pack index,
  the ring turning `surround_turn_deg` per second.
- `backoff: "scurry"`: back-offs run out (`scurry_s`, facing the prey: walk_back/strafe clips)
  instead of leaping.
- `retreat_mode: "flee"`: below `retreat_frac` it flees for `flee_s` and comes back. A packmate's
  death makes the rest flee for `mate_death_flee_s`.
- `feint_repositions: true`: its feint (a dart in and out with no bite) stays a filler while the
  bite cools.
- Sequences: dart (charge into a bite), or strafe_left/right then dart; point blank is the bite.
- Missing clips for the art thread: hop_back, leap_back, dodge_left/right, pounce, charge,
  bite_combo. It plays well without them: the strafes stand in for dodges, the run for the charge,
  and it scurries instead of leaping.

## Herd grazer extras (pack_mule: zebraceratops, protoceratops)
A profile on a herbivore archetype runs only while the animal is **provoked** (`CreatureBrain._provoked`):
skittish after 3 hits in 8 s, a `stand_ground_natures` nature after 1 hit, Aggressive (`auto_engage`)
always, a herdmate's rally for `defend_s`. When the provocation ends, or the prey is more than `guard_m`
from the animal's home, it stands down (`stand_down`) to alert and the grazer rules decide again.
- **Natures.** `flee_natures` (Timid) are never provoked: hit or not, they run. `stand_ground_natures`
  (Brave) do not flee on sight: they hold a threat display at the threat and charge when it comes within
  `display_charge_m` 5 m (surface to surface) or hits them, and graze again once it is past 1.2 × sight.
  Everyone else flees on sight (skittish) until provoked.
- **`display` step:** stop, face the prey, play `alert` (head lowered) for `display_s` 1.2 s. The main
  sequence is display → charge (weight 3); plain charge 1; strafe_left/right → charge 0.5 each.
- **Straight charge (`charge_straight`):** the line is locked at the start, through the prey's spot by
  `charge_through_m` 2.5 m, at `charge_speed_mult` 1.5 × run with the `charge` clip. Contact with the prey
  in front (dot > 0.2) is one impact: `CreatureAttack.apply_for(attack_heavy, charge_mult 1.8)`, rolls
  dodge it. A miss staggers it for `charge_miss_recover_s` 1.5 s (the punish window). After a hit that
  leaves the prey behind it, the kick follows; else the one back-off.
- **Kick (`kick` clip, `kick_cd` 5 s, `kick_mult` 1.4):** point blank only, and only with the prey in its
  rear arc (dot < -0.3). The body keeps its back to her while the kick plays. `kick` is a one-shot attack
  in `CreatureAnim.ATTACKS`, its hit at `anim_events.json kick.hit_frac` 0.45.
- **Herd defence (`herd_defend`):** a herdmate that takes a hit rallies every other member (not Timid, not
  one hit in the last 3 s) onto the attacker for `defend_s` 8 s (`tactic` "defend"). The hurt one runs.
- **Retreat:** `retreat_mode` flee below `retreat_frac` 0.25 for `flee_s` 4 s (`_holds_flee` keeps a
  provoked grazer running); `alone` scales feints ×1.5, retreat ×1.4, cooldowns ×1.3.
- Back-offs scurry (`walk_back` clip) instead of leaping; no dodge (`w_dodge` 0).
- Taming is unchanged: knocked down, it is not thinking; capture at ≤ 30 % or stunned (spec 09).
- Missing clips for the art thread: a front-foot **stamp** for the display (it uses `alert` now), and a
  horn **impact** (the charge's hit shows on the run-through, no strike pose).
- Test: `game/tests/t_zebra.gd`. Lab: `--lab=creature_lab --species=zebraceratops`, or SPAWN →
  Zebraceratops, a nature, count 3.

## Rules the brain enforces
- **Offence comes from movement.** A sequence is picked by weight × the nature's
  `tactic_w_<finisher>`, and only when its finisher is off cooldown and affordable. Steps:
  `backstep` (a hop_back, at most one per sequence), `strafe_left`/`strafe_right` (the dodge
  step), then `pounce`, `charge` (a run into a bite) or `combo` (a leap-in into `bite_combo`).
  A pounce step that is out of range turns into a charge.
- **The basic bite is a last resort.** It fires only at point blank or during a chase. There is
  always a non-attack beat between two basics, and at most `max_basic_streak` basics come before
  a beat or a special.
- **Energy.** Specials go through `Creature.try_special` (`ai.json energy.special_cost_frac`:
  pounce 0.3 and bite_combo 0.35 of the pool). Dashes, charges and lunges need `can_sprint()`.
  `energy.sprint_states` drain the pool.
- **Back-offs are leaps, never walks.** There is ONE after an attack. Two back-jumps never come
  in a row without a strafe, attack, pounce or chase between them. Back-jumps have `hop_cd` and
  are capped by `max_retreat_m`.
- **Pressed, it waits.** While the survivor closes in, it only repositions (strafe-walk, power
  strafe, one backstep). It commits when an opening shows (her swing recovering or playing, her
  back turned) or after `wait_max_s`. While the basic bite is cooling, the filler is
  repositioning too.
- **Running.** In `energy.sprint_states` every creature runs at `energy.run_speed_mult` (1.25) and
  drains `run_drain_per_s` 13. Its pool refills at `regen_mult_fresh` 1.5, or `regen_mult_winded`
  0.6 while winded. The survivor's run and sprint use `combat_tuning movement` (×1.25 speed, ×1.3
  stamina drain), with refill by fatigue strain tier 1.5 / 0.9 / 0.5 / 0.25.
- **Enrage** (status `enraged`, 20 s; a failed tame or a missed net applies it):
  - The body is not tinted. The look is blood instead: `statuses.json` fx.particles "blood" gives
    a dripping body emitter and a flecking mouth emitter (`Creature._sync_status_emitters`, 2
    CPUParticles3D, freed when the rage ends).
  - The `tactics.enraged` multipliers apply (deinonychus: cooldowns x0.55; pounce, combo and
    charge weights x1.6/1.8/1.4; multi-step sequences x1.5; power strafe x2, hop x1.5, plain
    strafe x0.6; beats x0.6; pressed waits x0.4). The nature's `enrage_mult` pulls each toward 1:
    Aggressive 1.5, Brave 1.4, Loyal/Stubborn 1.0, Docile 0.4.
  - A Timid (`enrage_flee`) creature runs from its attacker instead, and returns to the fight
    when the rage ends.
  - Brains without a profile shorten their attack cooldowns by `default.enraged_cd_mult` 0.6 and
    throw their heavy attack one primary sooner.
  - Lab: N, or `--enrage`, enrages the nearest creature.
- **Prey that walks away** (more than 1 m/s outward) is chased at a full run, or pounced when the
  pounce reaches its predicted position. It never holds or backs off while the prey leaves.
- **Hit times are data.** The `bite_combo` hits come from `anim_events.json` `hit_fracs`, and its
  tell ring from `tell_fracs[0]`. The pounce hit comes from `pounce.hit_frac`, and leaps move
  only inside their `airborne` fracs. The roll's i-frames (RollRules) decide dodges in
  `CreatureAttack`.

## Clip set (`CreatureClips`)
Required (`CONTRACT`): idle, walk, run, attack_primary, attack_heavy, hit_react, knockdown, death,
alert, feed. Optional (`OPTIONAL`, loaded when the GLB exists): sleep, tail_swipe, bite_combo,
hop_back, leap_back, pounce, dodge_left, dodge_right, strafe_left, strafe_right, walk_back,
charge (a loop like run, stride-matched by `natural_speeds.<id>.charge`).
Fallbacks: a leap without its clip retimes attack_heavy over the profile's `*_s`. A dodge
without its clip plays the strafe loop. Locomotion picks a clip by velocity against facing
(`CreatureAnim.set_move_velocity`): walk_back when dot < -0.5, a strafe when |side| > 0.7, each
stride-matched, otherwise walk/run. The same applies to ridden mounts.

## Natures (`natures.json`, default 1.0)
| Knob | Aggressive | Timid | Brave |
|---|---|---|---|
| `tactic_cooldown_mult` | 0.7 | | |
| `tactic_feint_mult` | 0.5 | 1.5 | |
| `tactic_standoff_mult` | | 1.3 | |
| `tactic_hold_mult` | 1.5 | | 1.5 |
| `tactic_backoff_mult` | | 2.0 | |
| `tactic_overshoot_mult` | 1.6 | | |
| `tactic_w_charge` / `_combo` / `_pounce` | 2.0 / 1.5 / – | 0.4 / – / 1.5 | – / 1.5 / – |
| `retreat_threshold_mult` (shared) | | 1.8 | 0.5 |

## Player side
- A hit stuns her for exactly the hurt clip's length (`PlayerSim.hurt_stun_seconds`): no
  movement, no swings. Then walk/run takes over (`PlayerAnim.end_hurt`).
  `HIT_STUN_IMMUNE_S` 0.8 s follows, during which hits damage but cannot re-stun.
- Basic swing cooldown = max(1 / attack_rate, `player_melee.basic_cooldown_s` 0.8 s), on the
  client and the server (`act.attack`, `ms` like `act.roll`).
- Tackle and Kick have their own cooldowns (8 s and 6 s) and stagger the target
  (`stagger_s` 0.8 and 0.5 s). They can cut the auto-attack swing short.

## Server
`act.attack` enforces the basic cooldown. Creature AI, creature cooldowns and the stun rule are
client-only: creature hits on a player are not validated server-side yet. When they are, they
call `IntentHandlers.rolls_dodge`.

## Adding a new class
1. Decide the archetype's finishers and fillers from its PRD row (e.g. charger: line-up + charge;
   club tail: side-on tail swipe). Don't invent a mechanic the PRD lacks; mark it `# ASSUMPTION`.
2. Add `tactics` to `ai.json archetypes.<archetype>`: `sequences`, `point_blank`, every
   `<move>_cd`, ring, leap lengths, filler weights, `max_basic_streak`/`share`.
3. A finisher that `TacticalBrain` lacks (stomp, tail swipe, spit) needs a `_terminal_ready`
   case, a `_seq_next` step and a state function. Add its energy cost to `special_cost_frac`.
4. List the clips it needs. Missing optional clips fall back as above; ask the art thread for
   the rest and give each its `anim_events.json` timing (`hit_fracs`, `tell_fracs`, `airborne`).
5. Add nature weights (`tactic_w_<finisher>`) where a nature should lean.
6. Copy `t_tactical`'s `_test_fight` for the species: no move inside its cooldown, sequences
   run in order, basics ≤ share, a beat between basics, back-jumps never adjacent, distance ≤
   `max_retreat_m`, energy gate, retreat. Then run t_ai, t_combat, t_natures, t_canim and
   `tools/smoke.sh`.
7. Watch it in the creature lab: press SPAWN (left) to pick the species from the dropdown (every
   species; model-less ones spawn as the box stand-in, marked "(stand-in)"), count, nature and Alpha,
   or launch with
   `Godot --path game -- --lab=creature_lab --species=<id>` (F3 prints every move;
   `--seq=DIR` saves frames).
