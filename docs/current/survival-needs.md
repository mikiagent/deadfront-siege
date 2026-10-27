# Survival needs — health, stamina, exhaustion, food relief, sleep

The vitals trio and all its rates: `game/scripts/combat/vitals.gd` (`Vitals` on every survivor;
`_process` ticks the three bars). Movement, swim and sleep mechanics: `game/scripts/player/player_sim.gd`.
Hits on the survivor: `game/scripts/player/player.gd`. Status definitions: `game/data/statuses.json`
(multiplied together in `game/scripts/combat/status_effects.gd`). Rules tuning: `game/data/world/rules.json`
(`fatigue.*`). Per-food numbers: see [items-traits.md](items-traits.md).

## Health (red bar)
- Max = 100 base + Pioneer-level `max_health` gains (`level_health`, saved) + equipped gear bonus
  (derived, never saved), × the product of active statuses' `max_health_mult` (Infected Wound ×0.8).
  Statuses recompute it inside `Vitals`; gear never heals, it only raises the cap.
- Regen 0.8 HP/s (`health_regen`), paused 6 s (`REGEN_LOCK_S`) after any hit (small bites are not
  regenerated away), off while a status carries the `blocks_regen` flag.
- Death: `dead` stops regen and further damage until `revive(0.5)` — 50% of max health (min 1),
  stamina restored to at least 50%, fatigue halved. The death card offers "Respawn at camp".

## Energy = stamina (blue bar)
- Cap = `max_energy` 100 base + level gains (`level_energy`, saved) + skill-node bonus + food-buff
  ceiling (`food_max_energy`), before the strain cut (below).
- Spend: sprinting 9.0/s, swimming 6.0/s; every spend starts a 0.8 s regen lock (`STAMINA_LOCK_S`).
  Empty → the survivor drops to a walk; swimming with an empty bar deals 5 HP per second.
- Regen: 16.0/s out of combat (~7 s for a full bar), 2.5/s in combat. In combat = a live hunt target
  or a hit taken within the last 5 s.

## Exhaustion (0-100 fatigue; the HUD face + treadmill)
- Ceiling = `max_fatigue` 100 + the food-buff ceiling (`food_max_fatigue`, e.g. Dutch Coffee).
  `exhausted` flips at 75% of the ceiling. HUD face words: RESTED <25%, WORN <50%, TIRED <75%,
  EXHAUSTED ≥75% of it.
- Every positive gain multiplies: amount × 0.5 (owner halving, `FATIGUE_ACCUMULATION_MULT`) ×
  statuses' `fatigue_mult` product (and ×0.5 again inside a shelter's `coziness` area) ×
  `level_gap_mult`. Reductions (`rest`, meals, sleep) are never halved.
- Baseline idle: `EXHAUSTION_PER_SEC` = 100 pts per 45 min before the halving — 100 pts in ~90 min.
  Tagged `time`; the level gap never applies to it.
- Movement per s (before the halving): walk 0.05, run 0.09, sprint 0.2 (`player_sim._walk`).
- Gathering: 1.5/4 = 0.375 per harvested unit; starting a corpse haul adds a flat 1.0
  (`player_actions.gd`, source `gather`).
- Damage: every hit adds 15% of its damage as fatigue, plus a flat 2.0 per hit taken (`player.gd`,
  source `combat`).
- Climate: unmet heat/cold resistance points × `fatigue.climate_per_min` = 4.0/min. Heat bites
  during the day phase; cold at dawn, dusk and night. The heat share scales with statuses'
  `heat_fatigue_mult`. Standing in water > 5 s applies `wet` (refreshed while in water).
- Island-vs-survivor level gap (`ProgressionScaling.fatigue_level_factor`, set per frame):
  ×(1 + gap·0.06) over-levelled, ×(1 − gap·0.04) under, clamped 0.5–2.0; all positive gains except
  the `time` baseline.
- Per-source fatigue log with an exponential decay window of 180 s (`fatigue.breakdown_window_s`)
  feeds the HUD breakdown panel.

### Statuses that touch fatigue (`game/data/statuses.json`)
| status | effect | duration |
|---|---|---|
| clean | fatigue ×0.8 | 360 s (from washing) |
| dirty / very_dirty | fatigue ×1.2 / ×1.5 | until washed |
| thirsty | fatigue ×1.2 | until drinking |
| quenched | heat fatigue ×0.8 | 360 s (from drinking) |
| wet | heat fatigue ×0.8 | 120 s |
| infected_wound | +0.15 fatigue/min, max HP ×0.8 | until treated |
| tastes_bad | +0.5 fatigue/min | 60 s |
| tastes_horrible / tastes_disgusting | fatigue ×1.2 / ×1.3 | 300 s |

Rates are on the 0-100 fatigue scale; all multipliers of one kind multiply together
(`StatusEffects._product`). Washing clears dirty/very_dirty and grants Clean; drinking clears
Thirsty and grants Quenched (`game/scripts/player/water_access.gd`).

## Food & relief
- No satiety meter in this build (`game/scripts/items/eat_session.gd`): eating pays instant Energy
  now + digested Energy on a schedule (`digest_seconds`), and always applies the `full` status
  (default 10 s; the bundle may extend it) — the only eating gate (`Food.can_eat` refuses `full`).
- Relief: a food's own `fatigue` row applies directly (negative eases current fatigue, positive
  adds it). Foods without a spec-32 bundle (dried/smoked outputs) keep the legacy path:
  `Vitals.eat()` — rest of 25% × ((instant + digested) × 1.5) — plus their `fatigue_relief` row.
  Raw-food rolls can add `stomachache` / `tastes_bad`.
- Autofeed (`player_sim.tick_autofeed`): a quick-slot food auto-eats when Energy ≤ 50% of base max
  or fatigue ≥ 60% of base max, outside combat, near-idle; 12 s cooldown after a bite.
- Warming/Cooling meals, dried/smoked relief and capacity buffs (Dutch Coffee's max-fatigue
  ceiling): per-food numbers in items-traits.md; buffs live in `BuffSlots`.

## Sleep (`player_sim.gd` + `game/scripts/world/placed_building.gd`)
- Spots: `sleep_spot` group nodes with `sleeps_left != 0`; the nearest within 3.2 m is offered.
  Sleep from anywhere: the survivor routes to the bedding (lie-down reach `SLEEP_REACH` = 2.2 m),
  then lies at its centre anchor.
- Start is refused in combat or within 5 s of a hit ("Can't sleep in combat"), when fatigue < 1.0
  ("Already rested"), or when dead.
- The restore eases exhaustion linearly across the duration; an interrupted or finished sleep pays
  the tiny remainder exactly. Sleep is the only full reset of exhaustion.

| spot | uses | restore | duration |
|---|---|---|---|
| straw_roll | 1 | 65 pts | 12 s (~5.4 pts/s) |
| tent | 6 | 100 pts | 10 s |
| canvas_tent | 12 | 100 pts | 8 s |
| log_shelter | unlimited | 100 pts | 7 s |
| cabin_bed | unlimited | 100 pts | 5 s |

- A completed sleep spends one use; temporary bedding `queue_free`s at 0 and its uses persist in
  saves. Waking steps the survivor out 1.6 m onto the door side (+Z) first.
- Interrupts: movement/nav input, an active route, entering combat, a hit within 1 s, death, or
  moving > 3.2 m from the spot — "Sleep interrupted"; completing shows "Rested".

## Day clock (`game/scripts/core/game.gd`)
- `day_length_seconds` = 720 — one game day per 12 real minutes. `time_of_day` runs 0..1
  (0 = midnight, 0.5 = noon).
- Phases (`phase_name`, mirrored by WorldLighting and the HUD dial): night under 0.22 or from 0.80,
  dawn to 0.30, day to 0.72, dusk to 0.80. Heat bites during the day phase; cold at every other
  phase.
- Dev lab: `game/scripts/dev/needs_lab.gd` drives the whole loop headless (eat, drink, wash, sleep,
  climate) and prints pass/fail notes.
