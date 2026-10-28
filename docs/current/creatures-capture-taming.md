# Creatures, AI, capture & taming — as the build runs today

Species data: `game/data/creatures/*.json`, one file per species, fields per
`game/data/creatures/SCHEMA.md`, read by `game/scripts/creatures/creature_def.gd`. AI tuning:
`game/data/creatures/ai.json`. Brain: `game/scripts/creatures/brains/creature_brain.gd` (BODY
`game/scripts/creatures/creature.gd`). Spawns: `game/scripts/world/island_spawns.gd` +
`game/scripts/world/spawner.gd`. Capture: `game/scripts/pets/capture_system.gd`, field tame:
`game/scripts/pets/field_tame.gd`, hunt actions: `game/scripts/combat/hunt.gd`, pen:
`game/scripts/world/taming_pen.gd`, pet record: `game/scripts/pets/pet_record.gd`, pet stats:
`game/scripts/pets/pet_stats.gd`, summons/riding: `game/scripts/player/player_pets.gd`.

## Species roster (19 JSONs)
Each species carries `tier` (its own level), `archetype`, `tameable`, `capture_tier`, `stats{hp,
attack, defense, speed, bag_slots}`, `taming{preferred_food, accepted_food, feeds_needed,
window_seconds, requires_pen}` and `clips`.

| species | tier | archetype | tameable | capture_tier | hp | atk | def | speed | feeds | pen |
|---|---|---|---|---|---|---|---|---|---|---|
| zebraceratops | 13 | pack_mule | yes | 1 | 720 | 36 | 80 | 400 | 3 | no |
| compsognathus | 15 | swarm | yes | 1 | 90 | 7 | 10 | 650 | 3 | no |
| coelophysis | 18 | flock_harass | yes | 1 | 420 | 60 | 30 | 720 | 3 | no |
| protoceratops | 20 | pack_mule | yes | 1 | 980 | 45 | 110 | 420 | 3 | no |
| velociraptor | 25 | pack_raptor | yes | 2 | 640 | 95 | 40 | 700 | 3 | no |
| megaloceros | 30 | antlered | yes | 2 | 1800 | 150 | 80 | 760 | 3 | no |
| gallimimus | 30 | runner | yes | 3 | 1400 | 120 | 50 | 900 | 6 | yes |
| deinonychus | 35 | pack_flanker | yes | 3 | 1450 | 165 | 70 | 660 | 3 | no |
| dilophosaurus | 40 | venom_ranged | yes | 4 | 2600 | 210 | 80 | 560 | 6 | yes |
| smilodon | 45 | saber_cat | yes | 5 | 3800 | 360 | 140 | 720 | 3 | no |
| styracosaurus | 45 | horned_charger | yes | 3 | 5200 | 300 | 220 | 470 | 6 | yes |
| stegosaurus | 45 | spiked_tail | yes | 4 | 8500 | 380 | 300 | 400 | 6 | yes |
| allosaurus | 50 | apex_raptor | **no** | 0 | 9000 | 480 | 180 | 520 | 6 | yes |
| utahraptor | 50 | apex_raptor | yes | 5 | 4200 | 340 | 120 | 620 | 6 | yes |
| ankylosaurus | 50 | club_tail | yes | 4 | 12000 | 420 | 520 | 380 | 6 | yes |
| triceratops | 55 | horned_charger | yes | 5 | 14000 | 520 | 380 | 450 | 6 | yes |
| brachiosaurus | 60 | titan | **no** | 0 | 90000 | 900 | 500 | 300 | 6 | yes |
| tyrannosaurus | 60 | tyrant | yes | 0 | 200000 | 1100 | 400 | 450 | 6 | yes |
| tarbosaurus | 60 | tyrant | yes | 5 | 24000 | 700 | 260 | 480 | 6 | yes |

`capture_tier` 0 cannot be netted (no net of tier 0 exists). Absent `taming` defaults
(`creature_def.gd`): herbivores prefer berry / accept fibre_stalk, carnivores prefer raw_meat /
accept fish or raptor_meat; length > 5 m → 6 feeds and requires_pen, else 3 feeds and field
completion.

## Brains & AI (`ai.json`, `brains/`)
- States: roam, alert (0.6 s), approach, attack, retreat, flee, disengage, sleep, downed, dead;
  thinks at `THINK_HZ` = 10, staggered per creature.
- Archetypes (15 in `ai.json`, plus `default`): pack_raptor, pack_flanker, apex_raptor, swarm,
  flock_harass, venom_ranged, saber_cat, tyrant, pack_mule, spiked_tail, runner, antlered,
  club_tail, horned_charger, titan.
- Defaults: perception = 8.0 + tier × 0.15 m; attack_range 1.4–2.8 m by archetype; aggro leash =
  perception × `leash_mult` 1.5, never under `aggro_radius`'s 26.0 m when the target is a
  structure; disengage 3.0 s; retreat at
  `retreat_threshold_frac` 0.3 of max HP; flee 8.0 tiles; `chase_speed_mult` 0.7; sleep wake at
  3.0 m and stay awake 30.0 s; `weak_to` ×1.5, `resists` ×0.6 (slashing, blunt).
- Temperaments: skittish (flee on sight, provoke after 3 hits, ×1.6 flee speed), defensive
  (provoke after 1 hit, ×1.2), territorial (1 hit, ×1.2, inside `territory_m` 6.0).
- Specialised brains: `raptor_pack_brain.gd` (alpha + followers), `tyrant_brain.gd` (bite windup
  0.7 s, stomp 1.2 s, stagger after 3 blunt hits poisoned / 6 unpoisoned), `pet_brain.gd`
  (guard radius 9.0 m, drop target at 45.0 m), `brain_flight.gd`, `brain_rest.gd`.

## Spawns
- `IslandSpawns.spawn_all` places fixed rows from the island def's `creatures[]` and ring-band
  rows from its `spawns{}`; ring radius bands come from `rules.json` `rings` (landing 0–30,
  gathering 30–90, working 90–160, crater 160–210, far_shore 210–240 m from ring_centre).
- Cap `rules.json` `creature_cap_mobile` = 24 creatures per island; spawn rng seed 41; a spot must
  be dry land and at least 25 m from camp and from the harbour (`IslandRuntime.spawn_ok`).
  `Spawner.spawn_now` builds the nodes; a `count>1` row becomes a pack.

## Capture, as the code does it now (`CaptureSystem.attempt`, `Hunt.use_net`)
1. `FieldTame.capture_window()` must be open: alive, `tameable`, not a pet, and either the `knockdown`
   status at any HP or HP fraction ≤ `FieldTame.CAPTURE_HEALTH_FRAC` = 0.30 (spec 09).
2. One hint per creature, "Stun the dinosaur to capture it safely.", when a hunted tameable animal
   is at ≤ 50 % HP and not stunned (`Hunt.STUN_HINT_FRAC`). DoTs skip an animal inside the window.
3. `Inventory.best_capture_net` must hold a net whose `capture_tier` ≥ the species'
   `capture_tier`; nets are `capture_net_i` … `capture_net_v` (tiers 1–5) in `game/data/items.json`.
4. The survivor needs the matching capture technique (`Data.has_capture_technique`).
5. Chance (`CaptureSystem.chance_for`, actual HP) = `TIER_BASE`[net tier] × (1.5 − HP fraction), clamped 0.05–0.90, where `TIER_BASE` =
   1:0.35, 2:0.45, 3:0.55, 4:0.65, 5:0.75 (an assumption in code).
6. Success consumes 1 net and puts a `captured_animal` stack (species, variant, level, genetics,
   `slot_span` 4) into the bag. Failure clears capturability and applies `enraged`.

Nets do not damage. `Hunt.use_net` refuses with "Stun it or weaken it to 30% health to capture it."
Knockdown itself comes from tackle/kick/stagger — see `game/scripts/combat/combat_tactics.gd`.

## Field tame (`FieldTame`)
- `can_attempt`: alive, `tameable`, not a pet, no tame cooldown, inside `capture_window()`.
- `lock_reason`: `capture_tier` ≤ `FREE_CAPTURE_TIER` 1 is free; above it needs the technique.
- `apply_feed` takes 1 feed (1.2 s each) of preferred (worth 1.0) or accepted (0.5) food, extends
  the knockdown by 6.0 s, and sets the feed total. Refused at the bonded cap before the food is
  spent.
- Window = the species' `taming.window_seconds` (45 s); completion at `feeds_needed`.
  `requires_pen` species never complete in the field.
- Success (`_complete`) builds a `PetRecord` (origin `tame`, wild level carried), bonds it and
  summons it. Expiry (`fail`) releases the knockdown, applies `enraged`, 60.0 s cooldown.

## Pen (`TamingPen`, building `makeshift_taming_pen`)
- `try_insert` takes one `captured_animal` from the bag; `BASE_SECONDS` = 30 min of real time,
  scaled by `Game.time_scale`. Each `feed` costs 1 raptor_meat and sets the remaining time to
  max(5 s, 60% of what is left).
- On finish: `SUCCESS_CHANCE` = 0.70 bonds the animal (origin `capture`); failure spawns it back
  wild and fleeing. At the bonded cap the finished animal stays in the pen unbonded.

## Natures (owner 2026-10-28)

A Pokémon-like temperament that changes BEHAVIOUR only, on top of the archetype and temperament
above (it never replaces them and never edits a species' stats). Table:
`game/data/creatures/natures.json`; helper: `game/scripts/creatures/brains/brain_natures.gd`
(`class_name CreatureNatures`); knobs are read in one place each, through
`Creature.nature_knob()/nature_flag()` (`game/scripts/creatures/creature.gd`).

| nature | what it does | knobs (default 1.0) |
|---|---|---|
| Timid | avoids combat, more likely to flee | `flee_threshold_mult` 1.6 / `retreat_threshold_mult` 1.8, `aggro_radius_mult` 0.9, `retreat_as_flee`; never on tyrant/titan |
| Brave | protects its rider even when wounded | `retreat_threshold_mult` 0.5, `protect_rider_below_hp` 1.0 (a ridden pet never stands down for its own HP) |
| Aggressive | attacks nearby threats without orders | `auto_engage` (engages unprovoked, also means a grazer does not flee on sight), `aggro_radius_mult` 1.3, `guard_radius_mult` 1.25; weight ×0.1 on grazer archetypes |
| Loyal | stays close and protects its owner | `follow_dist_mult` 0.7, `guard_radius_mult` 1.4, `protect_owner` (threat measured from the owner too) |
| Stubborn | harder to tame, resistant to fear | `feeds_mult` 1.5, `tame_window_mult` 0.75, `pen_time_mult` 1.4, `fear_immune`, `retreat_threshold_mult` 0.6 |
| Docile | easier to tame, less effective in combat | `feeds_mult` 0.33, `tame_window_mult` 1.25, `pen_time_mult` 0.8, `damage_dealt_mult` 0.75 |

- Roll: once per animal at spawn, seeded from species + spawn point + pack
  (`CreatureNatures.spawn_key`), weighted by `weights` and masked per archetype (`never`, `only`,
  `rare_for`). Docile and Timid are the common ones.
- AI: `creature_brain.gd` (`_effective_perception`, `_flees_on_sight`, `damage_threshold`,
  `retreat_fraction`, `note_damage`, `_spot`), `raptor_pack_brain.gd` (retreat line),
  `pet_brain.gd` (`guard_radius`, `_threat_distance`, `nature_keeps_fighting`,
  `nature_stop_distance`), damage dealt in `Creature.attack_for` for wild animals and in
  `PetRecord.stat_value` for pets (its one stat source, so a Docile pet hits softer while the
  stored `attack` the PETS sheet shows stays the species number).
- Taming: `Creature.feeds_needed()/tame_window_seconds()` = species number × nature;
  `FieldTame` (window, feeds, completion) and `TamingPen` (wait at insert, nature carried on the
  captured stack by `CaptureSystem`) read them. Spec 09's capture rule is unchanged.
- Name and tag (owner 2026-10-28: "put it as a tag under their name, not in the name itself"): the
  name is the animal's own — species, with the colour variant or "Alpha" (pack leader) in front:
  "Velociraptor", "Alpha Velociraptor". The nature is a small chip directly UNDER that name, its
  short label only ("Timid"), built by `game/scripts/ui/nature_chip.gd` (`NatureChip`, the spec §5
  trait chip in its gold/positive style) and fed by `CreatureNatures.tag_for()` / `tag()`. Shown on
  the world plate (inside the pill, between the name and the HP bar; the plate keeps its 176x94
  budget and the chip row is always reserved, so nothing jumps), on the Animals screen (each roster
  row, each ACTIVE slot and the detail header) and in the pet radial's centre disc. No nature, no
  chip and no gap; the name helpers (`CreatureNatures.display_name/display_title`) no longer take a
  nature at all, so a nature cannot creep back into a name.
- Saves: `PetRecord.nature` is an optional field. A pet row without one (an old save, the server's
  roster) loads with the nature its uid derives, and every later load agrees. Fixture:
  `game/tests/fixtures/pet_record_no_nature.json`; test: `game/tests/t_natures.gd`.
- Known gap for the integrator: `core/data.gd` still walks every `*.json` in `data/creatures/`
  as a species, so each boot logs `[data] FAIL … natures.json: creature json missing species`
  (a `push_error`, nothing gates on it); and the server's `_tame` uses the species feed count and
  mints pets without the wild nature (the store round-trips whatever it is given, and
  `PetRecord.from_dict` derives a nature, so nothing breaks).
- `# ASSUMPTION`: every number in the table is a first pass for measurability, not balance, and
  the pet rule "a pet below its retreat threshold drops the fight" is new; only a Brave pet with
  its owner riding keeps fighting.

## Energy (owner 2026-10-28)

Every creature, wild or pet, has an energy pool (`Creature.energy` / `energy_max`). It has no
exhaustion and no treadmill. Running and special moves spend it, and rest or a walk refills it.
Rules: `ai.json` `"energy"`. A species JSON may override them with an `"energy"` block
`{max, regen_per_s, run_drain_per_s, costs{clip: n}}`, or give a clip entry as an object with
`"energy_cost"`. Code: `game/scripts/creatures/creature.gd` (energy section). Test:
`game/tests/t_energy.gd`.

- Size default: pool = 80 + 6 × `real_length_m`, refill time = 10 + 0.5 × length s (bigger means a
  larger pool and a slower refill). Running drains 10/s.
- Hysteresis: at or under 5 % (`stop_frac`) the animal is `winded`. It cannot run or start a special
  until the pool is back at 40 % (`resume_frac`).
- Running for wild animals and pets means being in a `sprint_states` brain state (approach, attack,
  flee, retreat, chase) while moving. A winded animal moves at `walk_mps` = 0.5 × its base speed.
  Roaming does not count as running.
- Specials: `special_cost(clip)` is the species' own cost, else `special_cost_frac` × pool
  (attack_heavy 0.3, deinonychus `bite_combo` 0.35). Everything else is free. API for the brains:
  `can_use_special(cost)`, `spend_energy(cost)`, `try_special(clip)` (checks, then spends),
  `can_sprint()`, `energy_frac()`. **The brains do not call these yet.** The tactical-combat package
  owns the brains and wires heavies to `try_special`.
- Not saved: a reload starts every animal at full, since the pool refills in 11–32 s.
- `# ASSUMPTION`: all of these numbers are a first pass.

| species | length m | pool | refill /s | 0→full s | run from full s | winded→resume s | heavy cost |
|---|---|---|---|---|---|---|---|
| compsognathus | 3 | 98 | 8.5 | 11.5 | 9.3 | 4.0 | 29 |
| zebraceratops | 4.3 | 106 | 8.7 | 12.2 | 10.1 | 4.3 | 32 |
| velociraptor | 6 | 116 | 8.9 | 13.0 | 11.0 | 4.5 | 35 |
| deinonychus | 10.2 | 141 | 9.4 | 15.1 | 13.4 | 5.3 | 42 (bite_combo 49) |
| triceratops | 18 | 188 | 9.9 | 19.0 | 17.9 | 6.6 | 56 |
| tyrannosaurus | 24 | 224 | 10.2 | 22.0 | 21.3 | 7.7 | 67 |
| brachiosaurus | 44 | 344 | 10.8 | 32.0 | 32.7 | 11.2 | 103 |

## Pets & mounts
- Bonded cap = `Data.bonded_cap`: 3 + Animal Handling `bonded_slots` nodes, at most 7
  (`SkillRules.bonded_capacity`). At most `MAX_OUT` = 3 pets out at once (`player_pets.gd`).
- `PetRecord`: level to `PetStats.MAX_LEVEL` 60, XP curve `xp_to_next` = 30 + 15 × level,
  `RESPAWN_TIME` 180 s, per-pet `bag` inventory, stats recomputed by `recompute` from
  `PetStats` (health growth 0.028/level, attacks 0.002, defenses 0.006).
- Mounting: `PlayerPets.mount` requires `&"mount"` in the pet's `tamed_role`. Ridden, the mount walks
  at `walk_mps` (0.5 × its pet pace). It runs at its pet pace while Shift is held or the HUD SPRINT
  toggle is on (`PlayerPets.wants_mount_sprint`). Running drains the MOUNT's energy and drops back to
  a walk when the mount is winded; the toggle stays on, so the mount runs again at 40 %. The rider's
  stamina and exhaustion do not change. Riding burns the mount's hunger. Saddle data lives per species in
  `game/assets/creatures/<species>/mount/mount.json` (9 species have one);
  `game/data/mounts_skip.json` is empty. Riders need no saddle item.
- Pets, their uids, levels and bags save under the save key `pets` (see
  [saves-persistence.md](saves-persistence.md)).

## Screens (phone landscape, [all screens](ui-screens.md))

**Animal roster**

![animals](screens/animals.webp)

**Creature plate**

![plate](screens/plate.webp)

**Pet out**

![pet_out](screens/pet_out.webp)
