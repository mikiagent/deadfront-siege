# dsc — NATURES: creature natures that change behaviour

## What shipped

Six natures that change wild and pet AI behaviour and show as a prefix on the animal's name.
Behaviour only: no species identity, art, model, animation or balance number was changed.

| nature | behaviour now (measured) | knobs |
|---|---|---|
| Timid | flees instead of the predator's short back-off once a hit lands, and at more HP; looks less far | `flee_threshold_mult` 1.6 / `retreat_threshold_mult` 1.8, `aggro_radius_mult` 0.9, `retreat_as_flee`; never rolls on tyrant/titan |
| Brave | a ridden pet never stands down for its own HP | `retreat_threshold_mult` 0.5, `protect_rider_below_hp` 1.0 |
| Aggressive | engages a survivor/pet inside its radius unprovoked (even a defensive grazer); wider scan and guard radius | `auto_engage`, `aggro_radius_mult` 1.3, `guard_radius_mult` 1.25; weight ×0.1 on grazer archetypes |
| Loyal | follows closer, big guard radius, threat measured from the owner too | `follow_dist_mult` 0.7, `guard_radius_mult` 1.4, `protect_owner` |
| Stubborn | more feeds, shorter window, longer pen wait, never flees or backs off from damage | `feeds_mult` 1.5, `tame_window_mult` 0.75, `pen_time_mult` 1.4, `fear_immune`, `retreat_threshold_mult` 0.6 |
| Docile | fewer feeds, longer window, shorter pen wait, deals less damage | `feeds_mult` 0.33, `tame_window_mult` 1.25, `pen_time_mult` 0.8, `damage_dealt_mult` 0.75 |

Code:
- `game/data/creatures/natures.json` — the table (defaults always 1.0/false, weights, `never` /
  `only` / `rare_for` masking, `_knobs` explanations, `_assumptions`).
- `game/scripts/creatures/brains/brain_natures.gd` — `class_name CreatureNatures`: table load,
  `knobs()`, `allowed_for()`, `weight_for()`, `roll()`, `spawn_key()`, `from_uid()`, `label()`,
  `display_name()`, `display_title()`. Names no autoload (compiles at boot for the server).
- `creature.gd` — `nature`, rolled at spawn from the spawn key; `nature_id()`, `nature_knob()`,
  `nature_flag()`, `feeds_needed()`, `tame_window_seconds()`; `attack_for()` applies
  `damage_dealt_mult` (the one hit path already reads it).
- `brains/creature_brain.gd` — `_effective_perception()` × `aggro_radius_mult`; `_flees_on_sight()`
  (fear_immune / auto_engage); `retreat_fraction()` and `damage_threshold()`; `note_damage()` flees
  or retreats per nature; `_spot()` lets an auto_engage grazer engage.
- `brains/raptor_pack_brain.gd` — its own retreat line now reads `retreat_fraction()`.
- `brains/pet_brain.gd` — `guard_radius()`, `_threat_distance()` (`protect_owner`),
  `nature_keeps_fighting()` (Brave while ridden), `nature_stop_distance()` (`follow_dist_mult`);
  a pet below its retreat fraction drops the fight unless its nature keeps it in.
- `pets/field_tame.gd` — window/feeds/completion via `feeds_needed()` / `tame_window_seconds()`,
  stamps `nature` on the pet record; `pets/capture_system.gd` puts it on the captured stack;
  `world/taming_pen.gd` reads it back and scales the 30-minute wait by `pen_time_mult`.
- `pets/pet_record.gd` — `nature`, saved in `to_dict()`, migrated in `from_dict()` (unknown or
  missing → derived from the uid). `core/save_sanitizer.gd` keeps the field.
- `ui/creature_plates.gd` and `ui/animal_screen.gd` — the name reads nature, then variant or
  "Alpha" (pack leader), then species.

## Before / after numbers (from `game/tests/t_natures.gd`, the brain's own decision)

| check | before (no nature / default) | after (nature) |
|---|---|---|
| Timid raptor hit for 60 % of max HP | retreat (not flee) | flee |
| Timid raptor retreat fraction | 0.30 | 0.54 |
| Brave ridden pet at 20 % HP | stands down | keeps fighting |
| Aggressive ankylosaurus, survivor 4 m away | roam, no target | alert, engaged |
| Aggro radius (tier 20 perception 11 + leash 1.5) | 13.5 m | 17.6 m |
| Stubborn zebraceratops hit for 90 % | flee | roam (ignores fear) |
| Loyal pet 2.19 m from its follow point | holds | walks; stop distance 2.4 → 1.68 m |
| protoceratops feeds needed | 3.00 | Stubborn 4.50 / Docile 1.00 |
| tame window | 45 s | Stubborn 33.8 s / Docile 56.2 s |
| pen wait | 1800 s | Stubborn 2520 s / Docile 1440 s |
| raptor plain blow on a triceratops | 4.0–5.1 | 3.2–3.8 (Docile ×0.75) |
| roll over 400 tyrant spawns | — | docile 162, loyal 77, stubborn 64, aggressive 52, brave 45, timid 0 (never) |

## Shots

None. The owner reserved the machine for headless work (`HEADLESS_ONLY`): no windowed lab or
screenshot was run, so the plate/screen name changes are verified by `display_title` assertions in
`t_natures` only, not by eye.

## Checks run

- `game/tests/t_natures.gd` — PASS (13 sections: table, roll, names, old-save fixture, timid,
  brave, aggressive, stubborn, loyal, taming, pen, docile damage, pet keeps its nature).
- Related: t_ai, t_tame, t_capture09, t_combat, t_save, t_srvdom, t_data all PASS (one editorial
  line per run: `[data] FAIL res://data/creatures/natures.json: creature json missing species` —
  see below).
- `tools/smoke.sh --no-import` — SMOKE PASS. `verify_job.sh natures 1` — PASS.

## Assumptions (`# ASSUMPTION`, also in `natures.json` `_assumptions` / `_knobs`)

- Every knob value is a first pass chosen to be measurable, not balanced.
- Weights: Docile 30, Timid 20, Loyal 15, Stubborn 12, Brave 10, Aggressive 8; a grazer rolls
  Aggressive at ×0.1 weight; tyrant and titan never roll Timid.
- Pets roll the natures their species' archetype allows (no separate pet table).
- New pet rule: a pet below its retreat fraction drops its fight (today nothing did), and a Brave
  pet with its owner riding keeps fighting instead.
- `protect_rider_below_hp` 1.0 = "always while wounded", the simplest reading of the owner's words.
- A wild animal gets its nature from species + spawn point + pack, so a reload at the same spot
  keeps it (same rule as the colour roll).
- Nature heredity/breeding is not implemented (no second brain, no breeding change).

## What the integrator needs

- **Scope exceptions to review**: the Natures helper had to live in `scripts/creatures/brains/`
  (`brain_natures.gd`) because the job's scope only allows `creature/creature_def/spawner` in
  `scripts/creatures/`. It is one extra file in a coded area, not a new system.
- **Data loader**: `core/data.gd` `_load_creatures` reads every `*.json` in `data/creatures/` as a
  species and prints `[data] FAIL res://data/creatures/natures.json: creature json missing species`
  (a `push_error`) on every boot and test. It is outside this job's scope, so it was left alone; the
  fix is one line: skip `natures.json` beside `anim_events.json` and `ai.json`.
- **Server**: `scripts/server/intent_handlers.gd` `_tame` still reads `def.feeds_needed` and mints
  pets without a `nature`. The store round-trips whatever field it is given and
  `PetRecord.from_dict` derives a nature from the uid, so nothing breaks, but a server-tamed pet
  does not obey Stubborn/Docile feeds and its nature is not the wild one. The two-line hook is
  `CreatureNatures.knobs(row.nature).feeds_mult` on `needed` and `pet["nature"] = …` before
  `Provenance.stamp` (the intent file was out of scope and reverted).
- The visual pass (plate text and the Animals screen with a nature prefix) still needs a windowed run.
