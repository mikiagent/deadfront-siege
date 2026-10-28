# Enemy AI template — the tactical class profile

How a wild creature fights when its archetype carries a tactical profile. The deinonychus
(`pack_flanker`) is the first and so far the only class on it; its profile is the template for the
next ones. Code: `game/scripts/creatures/brains/tactical_brain.gd` (`TacticalBrain`), data:
`game/data/creatures/ai.json` → `archetypes.<archetype>.tactics`, test: `game/tests/t_tactical.gd`.

## Who gets it

`Creature._make_brain` (`game/scripts/creatures/creature.gd`) picks, in this order: a pet →
`PetBrain`; the tyrannosaurus → `TyrantBrain`; any other species whose archetype row has a
`tactics` block → `TacticalBrain` (`TacticalBrain.has_tactics`); a `raptor_pack` archetype →
`RaptorPackBrain`; everything else `CreatureBrain`. The shared rules in
`CreatureBrain._pre_think` still run first (leash, sleep, walking home, LOD freeze, the reacquire
rule); `TacticalBrain._think` adds the combat behaviour only while the target is valid and the
state is one of its own moves.

## States

`approach` (walk to `ring_m`) → `circle` (strafe on the ring at `circle_speed_frac` 1.0 × the
species' walk speed, `circle_step_deg` 35° a step, facing the prey) → a manoeuvre:
`feint` (a fast step in, then a hop back out), `lunge` (a dash into the basic bite or into the
combo), `pounce` (telegraph → leap → recover), `combo` / `attack` (standing in a bite), `hop` (the
backward leap every back-off uses), `retreat` (below `retreat_frac`). All of them are full-rate
thinking states (`_full_rate`). When the target dies or is lost, `_think` hands back to
`CreatureBrain` (roam, scan, alert, flee).

## The loop, in the order the code runs it

- **Choose the strongest attack that is ready.** `attack_priority` (deinonychus: combo, pounce,
  bite) is walked top down; `attack_available(move, d)` needs the move off its own cooldown
  (`<move>_cd`, counted down in `_think`), the body free to swing (`_can_swing`: no clip running,
  not staggering, the pack's gap over), and, per move: combo needs the species' `bite_combo` clip,
  its energy (`can_use_special(special_cost)`) and reach or `can_sprint()`; pounce needs a sprint,
  its energy and a distance inside `pounce_min_m`–`pounce_max_m` (+ the prey's extra size); bite
  needs reach or a sprint. `bite_cd` is the shortest cooldown, so the basic bite is the filler.
- **A cooldown starts when the move is picked** (`_start_cd`), scaled by the nature's
  `tactic_cooldown_mult`.
- **Nothing ready: keep moving.** `_move_beat` re-rolls the circle timer
  (`circle_min_s`–`circle_max_s`), flips the strafe direction with `flip_chance`, and starts a
  feint with `feint_chance` × the nature's `tactic_feint_mult` — only outside the ring and able to
  sprint.
- **Inside the ring with nothing to throw: hop back out.** `_circle` starts a backward leap rather
  than reversing on foot (owner rule: jump back, never walk back).
- **Every attack ends in a hop.** `_swing` faces the prey while the clip runs, then `_start_hop`;
  the pounce's recover phase does the same. No two back-jumps are forced apart by a timer — each
  move's own cooldown is what separates them.
- **Pack spacing.** `pack_gap_s` 0.6 s keeps two members of one pack from swinging on the same
  beat (`_mark_pack` / `_pack_ready`), and a follower with a leader that has a target copies that
  target.
- **Hurt → retreat.** Below `retreat_frac` (0.4 of max HP, × the nature's
  `retreat_threshold_mult`, never for a `fear_immune` nature), it hops back (`retreat_hop_mult`
  1.4 × `hop_m`), strafes the wide ring (`ring_m` × `wide_ring_mult` 1.6) for `retreat_s` 2.5 s
  and holds that wide ring for `wide_circle_s` 4 s before re-engaging; `retreat_cd` 10 s gates the
  next retreat.

## The deinonychus profile (`ai.json` `archetypes.pack_flanker.tactics`)

Every number is an `# ASSUMPTION` (first pass, not balanced).

| key | value | meaning |
|---|---|---|
| `attack_priority` | combo, pounce, bite | strongest first |
| `ring_m`, `circle_speed_frac`, `circle_step_deg` | 5.5 m, 1.0, 35° | the stand-off ring and how it walks it |
| `circle_min_s` / `max_s`, `flip_chance` | 0.8 / 1.6 s, 0.3 | filler beat length, strafe-direction flip |
| `contact_after_s` | 1.0 s | at contact, a strike only after this much circling |
| `bite_cd` / `combo_cd` / `pounce_cd` / `retreat_cd` | 3.5 / 10 / 12 / 10 s | each move's own cooldown |
| `lunge_speed_mult`, `lunge_max_s` | 1.0, 1.2 s | the dash into an attack |
| `feint_chance`, `feint_s` | 0.25, 0.7 s | the step-in/step-out beat |
| `pounce_min_m` / `max_m`, `pounce_telegraph_s` | 4–8 m, 0.8 s | range and the windup ring |
| `pounce_leap_s`, `pounce_height_m`, `pounce_radius_m`, `pounce_recover_s`, `pounce_mult` | 0.4 s, 1.0 m, 1.6 m, 0.7 s, 1.5× | the leap and its hit |
| `combo_mults` | 1.0 / 1.3 / 1.8 | damage of the three `bite_combo` hits |
| `hop_m`, `hop_s`, `hop_height_m`, `hop_land_s` | 3.5 m, 0.4 s, 0.7 m, 0.15 s | the backward leap |
| `retreat_frac`, `retreat_s`, `retreat_speed_frac`, `wide_ring_mult`, `wide_circle_s` | 0.4, 2.5 s, 1.2, 1.6, 4 s | hurt, back off, circle wider |
| `pack_gap_s` | 0.6 s | minimum space between pack swings |

Ring and retreat fraction are both scaled by the prey's extra size (`reach_to` / `_size_excess`
in `creature_brain.gd`), so a big target pushes the ring out.

## Hit times are data

The `bite_combo`'s three hits come from `game/data/creatures/anim_events.json`
`clips.bite_combo.hit_fracs` (0.092, 0.338, 0.815) and its tell ring from `tell_fracs`
(`CreatureAnim` reads both; `TacticalBrain.hit_damage_mult` supplies the `combo_mults` multiplier
through `CreatureAttack.apply_for`). The pounce's damage is applied at the end of the fixed-time
leap (`_pounce_land`), through the same `CreatureAttack.apply_for` path, so the roll's i-frame
window (`RollRules`) decides a dodge exactly as it does for a bite. `pounce`, `hop_back`,
`leap_back`, `dodge_left` / `dodge_right` and `strafe_left` / `strafe_right` are optional clips:
`_start_hop` plays `hop_back` when the rig has it and otherwise retimes `attack_heavy` over
`hop_s`; the pounce windup retimes `attack_heavy` so its strike frame lands with the leap.

## Natures (`natures.json`, default 1.0)

| knob | Timid | Aggressive |
|---|---|---|
| `tactic_cooldown_mult` | | 0.7 |
| `tactic_feint_mult` | 1.5 | 0.5 |
| `tactic_standoff_mult` | 1.3 | |
| `retreat_threshold_mult` (shared with every brain) | 1.8 | |

## Player side, as it interacts with this

- A creature hit stuns the survivor for the hurt clip's length (`PlayerSim.hurt_stun_seconds`,
  the `hit_react` clip; 0.35 s without a rig), then `HIT_STUN_IMMUNE_S` 0.8 s during which hits
  still damage but cannot re-stun.
- A roll inside `RollRules.iframes_s()` 0.32 s dodges a hit that would otherwise land
  (`CreatureAttack` → `Player.roll_dodge`): no damage, no stagger, one Defense XP.
- Tackle (`combat_tuning.json` `tackle`: cooldown 8 s, `stagger_s` 0.8) and Kick (`kick`:
  cooldown 6 s, `stagger_s` 0.5) stagger the target, which is what opens the capture window for a
  stunned animal (see [creatures-capture-taming.md](creatures-capture-taming.md)).

## Server

`act.attack` (`game/scripts/server/intent_handlers.gd`) validates one melee swing: creature
exists and is alive, not a pet, in reach, melee weapon only, then runs the client's accuracy /
damage / crit formula on the server RNG. Creature AI, creature cooldowns and the stun rule stay
client-side: a creature's hit on the player is not validated server-side yet.

## Adding a new class

1. Add a `tactics` block to `ai.json` `archetypes.<archetype>` with the keys above (start from
   `pack_flanker`).
2. Give the species the clips it needs; missing optional clips fall back as described above.
3. Add its hit timings to `anim_events.json` (`hit_frac`, `hit_fracs`, `tell_fracs`, `airborne`)
   if it brings a new attack clip.
4. Copy `t_tactical`'s fight for the species (no move inside its cooldown, the strongest ready
   attack goes, energy gate, retreat, a back-off after every attack) and run
   `game/tests/t_ai.gd`, `game/tests/t_combat.gd`, `game/tests/t_natures.gd` and `tools/smoke.sh`.
5. Watch it in the creature lab (`game/scripts/dev/creature_lab.gd`, `--lab=creature_lab`).
