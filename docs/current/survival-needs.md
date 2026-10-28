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
| well_rested | no exhaustion gain at all (flag `no_fatigue_gain`) | 60–300 s (from sleeping) |
| clean | fatigue ×0.8 | 360 s (from washing) |
| dirty / very_dirty | fatigue ×1.2 / ×1.5 | until washed |
| thirsty | fatigue ×1.2 | until drinking |
| quenched | heat fatigue ×0.8 | 360 s (from drinking) |
| wet | heat fatigue ×0.8 | 120 s |
| infected_wound | +0.15 fatigue/min, max HP ×0.8 | until treated |
| tastes_bad | +0.5 fatigue/min | 60 s |
| tastes_horrible / tastes_disgusting | fatigue ×1.2 / ×1.3 | 300 s |

Rates are on the 0-100 fatigue scale; all multipliers of one kind multiply together
(`StatusEffects._product`). `game/data/statuses.json` defines 33 statuses in all; the fatigue
ones are above, the rest are the damage and capture conditions (bleed, deep_bleed, venom, fracture,
pinned, deafened, groggy, knockdown, snared, dizziness, enraged), the target-side variants
(bleeding_target, poisoned_target, poisoned), the food states (full, stomachache, caffeinated, the
five `tastes_*` and `hot_food` / `cold_food`, vigor) and the cleanliness pair (dirty / very_dirty
are above, clean is too). Each status's `fx` block gives its HUD colour, icon, particles and
vignette (see [hud.md](hud.md)). Washing clears dirty/very_dirty and grants Clean; drinking clears
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

### Cooking roles & per-slot inheritance (`game/scripts/items/cook_roles.gd`, `game/data/cook_roles.json`)
- A cooking recipe slot may name a **role** — `main`, `topping`, `sauce`, `broth`, `spice`,
  `support`. The role is an extra restriction on the slot: its `categories` list (and `exclude`
  list) must also match the item, so a spice can never fill a main slot even when the slot's own
  category would take it (`CookRoles.role_accepts` in `_allowed`). A recipe with no role on any
  slot keeps category-only behaviour.
- Inheritance is per recipe (`"inherit": true`) and per slot (`"inherit": {traits, processed,
  flags, rare}`), read from **that exact ingredient instance** by `CookRoles.collect` before the
  units are spent: `traits` copies the instance's attributes by key, `processed` copies its
  in-place cooking history, `flags` copies its flags, `rare` lets green/rare attributes pass.
  Key collisions resolve **first wins in slot order** — the same trait on two mains does not add
  up or average. Slot 0 (`primary`) still carries level/quality for the dish.
- What a dish inherited is stored on the item in `attributes.cooked_roles` (one row per filled
  slot: def id, level, kept traits, dropped traits, cooking history, flags, role bonus) plus
  `attributes.cooked_buffs`. A roled recipe does **not** keep the primary's wholesale attribute
  copy, so a dish shows only what its rules let through; `Food.inspector_text`
  (`game/scripts/items/food.gd`) prints a `cooked in:` line naming each slot's role, ingredient and
  carried traits, marking a refused one `(kept out)`.
- Role bonuses: topping/sauce/broth/spice ingredients grant a buff when their category matches
  `role_bonus` in `game/data/cook_roles.json` (`fruit_glaze`, `herbal_zing`, `spice_warmth`,
  `broth_comfort`; 600 s, +2 to +4 to one stat). They live in buff group `cooked_role`
  (`game/data/foods.json`), so they neither replace nor are replaced by the dish's own
  Enhanced Ability/Survival buff. These numbers are ASSUMPTIONs — spec 08 §4 gives no figures.
- Inherited traits feed the dish's FOODFX bundle: `FoodEffects.evaluate` appends
  `CookRoles.effect_rows` (`rich_cut`: ×1.15 Energy and +2 Fullness per level; `gamey_cut`:
  +4 Fullness and +3 Thirst per level; `fresh_cut`: +2 Health per level — all ASSUMPTION) and
  reports which traits were carried and which were discarded. A raw ingredient carrying the same
  attribute gets none of this; only the stored dish record counts.
- Poison survives cooking whatever the flags say. Six example recipes ship as data
  (`roled_grilled_meat`, `roled_berry_glazed_meat`, `roled_broth_soup`, `roled_spiced_stew`,
  `roled_herb_roast`, `roled_salad`), listed with their slots in recipes.md.

## Rest (`game/scripts/player/rest_state.gd`, rates in `game/data/rest.json`)
- A Rest context hex (and the X key, InputMap action `rest`) anywhere out of combat sits her down
  (`PlayerActions.rest()`; online an `act.rest {"on": bool}` intent, only queued — no server side
  yet). The hex hides while she rests or sleeps and in water. Refused, with the reason shown: dead,
  mounted, asleep, rolling or knocked down, in water, hunting, a hit within 5 s (`combat_lock_s`), or
  a creature targeting her in alert/approach/attack/retreat.
- Pose: `sleep_down` lowers her, then at 0.8 s she blends (0.4 s) into a built one-key "sit" clip
  (`PlayerAnim._ensure_sit_clip`): hips and legs from `sleep_down` at 1.05 s, spine/head/arms from
  `idle`, spine turned so the torso is upright. Same pose at every place. Getting up blends into
  `sleep_up` from 0.68 s. The rig has no authored sit clip.
- Recovery each frame by place, re-read twice a second (all ASSUMPTION, `rest.json` `_note`):

| place | when | Health/s (+ passive 0.8) | fatigue/min |
|---|---|---|---|
| open | anywhere else | +0.3 | -6 |
| fire | within 3.0 m of a Bonfire node | +2.0 | -15 |
| shelter | within 3.2 m of a tent, canvas tent, straw roll, log shelter or cabin bed | +3.0 | -30 |

- Conditions: fatigue recovery is divided by statuses' `fatigue_mult` (Dirty 1.2 → -25/min in
  shelter, Clean 0.8 speeds it). A `blocks_regen` status stops the rest's healing; damage-over-time
  comes off Health. Status ticks never stand her up, wake her or cancel the walk to a bedding
  (`Player._on_vitals_damaged` returns on `StatusEffects.ticking`); hits, fights and hunting creatures do.
- By a fire: sitting down clears Wet; heat fatigue ×1.2 and cold ×0.8 while seated
  (`RestState.climate_mult` in `Player.tick_climate_fatigue`).
- Ends with the stand-up on a move key, the joystick, a tap-to-walk, a hit, or combat. Autofeed waits
  while she rests. The save writes `player.resting`; a load sits her down only for a saved `true`
  (saves without the key load standing, `RestState.load_saved`).
- HUD: the Resting chip, the rate pill and recovery floats ([hud.md](hud.md)).

## Sleep (`player_sim.gd` + `game/scripts/world/placed_building.gd`)
- Spots: `sleep_spot` group nodes with `sleeps_left != 0`; the nearest within 3.2 m is offered.
  Sleep from anywhere: the survivor routes to the bedding (lie-down reach `SLEEP_REACH` = 2.2 m),
  then lies at its centre anchor.
- Start is refused in combat or within 5 s of a hit ("Can't sleep in combat"), when fatigue < 1.0
  ("Already rested"), or when dead.
- The restore eases exhaustion linearly across the duration; an interrupted or finished sleep pays
  the tiny remainder exactly. Sleep is the only full reset of exhaustion. While asleep she also heals
  at the shelter rest rate (+3.0 HP/s on top of passive, `RestState.heal`); the rest's fatigue rate is
  not added on top of the sleep's drain. Choosing Sleep while seated lies her down from the sit.

| spot | uses | restore | duration |
|---|---|---|---|
| straw_roll | 1 | 65 pts | 12 s (~5.4 pts/s) |
| tent | 6 | 100 pts | 10 s |
| canvas_tent | 12 | 100 pts | 8 s |
| log_shelter | unlimited | 100 pts | 7 s |
| cabin_bed | unlimited | 100 pts | 5 s |

- A completed sleep spends one use; temporary bedding `queue_free`s at 0 and its uses persist in
  saves. Waking steps the survivor out 1.6 m onto the door side (+Z) first.
- **Well Rested** (owner 2026-10-28; `RestState.grant_well_rested`, status `well_rested` in
  `statuses.json`, numbers in `rest.json` `well_rested`): waking from a completed sleep, or from one
  ended by moving after at least 5 s (`min_sleep_s`, or the bedding's whole duration if shorter),
  grants it for 3 s per point of exhaustion the sleep removed, clamped 60–300 s (ASSUMPTION; a tent
  sleep from 60 gives 180 s). A sleep ended by a hit, combat or death grants nothing; a second sleep
  never shortens a running one. While it runs, `Vitals.add_fatigue` drops every positive gain (the
  time baseline, movement, gathering, hits, climate, statuses, the level gap); rest, meals and sleep
  still lower exhaustion. It is a status, so the save keeps its time left (`statuses[].time_left`).
- Interrupts: movement/nav input, an active route, entering combat, a hit within 1 s, death, or
  moving > 3.2 m from the spot — "Sleep interrupted"; completing shows "Rested". A status tick
  (bleed, stomachache) is not a hit: it neither wakes her nor drops the walk to the bedding.

## Day clock (`game/scripts/core/game.gd`)
- `day_length_seconds` = 720 — one game day per 12 real minutes. `time_of_day` runs 0..1
  (0 = midnight, 0.5 = noon).
- Phases (`phase_name`, mirrored by WorldLighting and the HUD dial): night under 0.22 or from 0.80,
  dawn to 0.30, day to 0.72, dusk to 0.80. Heat bites during the day phase; cold at every other
  phase.
- Dev lab: `game/scripts/dev/needs_lab.gd` drives the whole loop headless (eat, drink, wash, sleep,
  climate) and prints pass/fail notes.

## Screens (phone landscape, [all screens](ui-screens.md))

**Vitals and fatigue belt (top left)**

![hud](screens/hud.webp)

**What is tiring you**

![fatigue](screens/fatigue.webp)

**Food inspector**

![bag_food_inspect](screens/bag_food_inspect.webp)
