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
1. Target must be `capturable()`: knockdown started and `tameable` (`creature.gd`).
2. Health fraction must be under `FieldTame.CAPTURE_HEALTH_FRAC` = 0.30.
3. `Inventory.best_capture_net` must hold a net whose `capture_tier` ≥ the species'
   `capture_tier`; nets are `capture_net_i` … `capture_net_v` (tiers 1–5) in `game/data/items.json`.
4. The survivor needs the matching capture technique (`Data.has_capture_technique`).
5. Chance = `TIER_BASE`[net tier] × (1.5 − HP fraction), clamped 0.05–0.90, where `TIER_BASE` =
   1:0.35, 2:0.45, 3:0.55, 4:0.65, 5:0.75 (an assumption in code).
6. Success consumes 1 net and puts a `captured_animal` stack (species, variant, level, genetics,
   `slot_span` 4) into the bag. Failure clears capturability and applies `enraged`.

Nets do not damage. `Hunt.use_net` refuses with "Weaken it below 30% health before netting it."
Knockdown itself comes from tackle/kick/stagger — see `game/scripts/combat/combat_tactics.gd`.

## Field tame (`FieldTame`)
- `can_attempt`: alive, `tameable`, not a pet, no tame cooldown, `knockdown` status, HP < 30%.
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

## Pets & mounts
- Bonded cap = `Data.bonded_cap`: 3 + Animal Handling `bonded_slots` nodes, at most 7
  (`SkillRules.bonded_capacity`). At most `MAX_OUT` = 3 pets out at once (`player_pets.gd`).
- `PetRecord`: level to `PetStats.MAX_LEVEL` 60, XP curve `xp_to_next` = 30 + 15 × level,
  `RESPAWN_TIME` 180 s, per-pet `bag` inventory, stats recomputed by `recompute` from
  `PetStats` (health growth 0.028/level, attacks 0.002, defenses 0.006).
- Mounting: `PlayerPets.mount` requires `&"mount"` in the pet's `tamed_role`; `dismount` and
  `mounted_move` ride at the pet's pace and burn hunger. Saddle data lives per species in
  `game/assets/creatures/<species>/mount/mount.json` (9 species have one);
  `game/data/mounts_skip.json` is empty. Riders need no saddle item.
- Pets, their uids, levels and bags save under the save key `pets` (see
  [saves-persistence.md](saves-persistence.md)).
