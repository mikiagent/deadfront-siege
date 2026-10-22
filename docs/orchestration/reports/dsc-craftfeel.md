# dsc-craftfeel: crafting has stakes (P7)

Plan: `docs/design/islands-and-loop-plan.md` §3.3 "Crafting", package P7. Specs 04 (success curve,
flawless, rare traits), 08 (skewer Food + Tool slots, inherited traits), 25 §8 ("if crafting fails,
materials disappear"). Branch: `craftfeel` worktree; 5 commits, one per milestone.

## What shipped

**Rules (`game/scripts/items/crafting.gd`)**
- `rules()` reads a new `crafting` block of `game/data/world/rules.json`.
- `success_chance(rec, ability)` = spec 04's preserved curve `clamp(1 - (shortfall/100)^2, 0, 1)` with
  `shortfall = max(0, required_ability - ability)`. Measured: 0 -> 100 %, 50 -> 75 %, 80 -> 36 %, 100 -> 0 %.
- `crafting_ability(player, rec)` = governing skill level + learned `craft_ability` node abilities + food
  `craft_ability` buffs (see assumptions).
- `required_ability(rec)` = the recipe's `required_ability` key. **No recipe in the repo declares one**, and a
  recipe without it only has the existing `min_level` category gate, so live play still reads 100 % — the
  skewer of spec 25 §8 included. Exposing the curve to live recipes is a data/tuning decision, left to the
  owner (see "integrator needs").
- `roll_outcome()` rolls success, then flawless (only on success), then the rare trait: a rare trait the
  primary already carries always passes; otherwise `rare_attribute_chance` (5 %) picks one of spec 04's six.
- `commit_outcome(player, rec, picks, outcome, rng, overflow)` is the single commit path. A failure consumes
  the picked instances exactly once and makes nothing, with a notice ("Crafting failed: the materials are
  lost.") and no XP. A success goes through `finish_craft(..., outcome)` which pays XP once.
- `apply_outcome()`: flawless keeps the crafted level (so a preview can never disagree with the result),
  sets `attributes.quality = "flawless"`, `flags.flawless`, +10 % max durability; a recipe that opts in with
  `flawless_level: true` also gains `crafting.flawless_level_bonus` level. The rare trait is written into the
  output's attributes at value 1 (a carried one keeps its own level).
- `preview_quality(rec, player, primary)` returns the deterministic card numbers: success, flawless,
  required/actual ability, inherited primary traits, `loses_materials`.
- `_plan` honours a slot's new `allowed_ids`.
- `bag_preview` now reports the real success/flawless (was hard-coded 1.0 / 0.0).

**Live craft path (`game/scripts/items/station_craft.gd`)** — `_finish_one` now rolls the outcome once when
the work completes (reproducible `rng`), asks `Crafting.commit_outcome` to commit it, and waits for bag room
only when the craft can succeed (a failure never needs room). Before: it finished through
`finish_craft` directly, so the curve could not apply to the real (walk/hex) craft.

**Data**
- `game/data/world/rules.json`: `crafting` = `success_curve_scale 100`, `flawless_chance 0.05`,
  `flawless_stat_bonus 0.1`, `flawless_level_bonus 1`, `rare_attributes` (Black Sheen, Low Vibration, Wide
  Serration, Narrow Hook, Split Easily, Vivid Inspiration), `ability_food_stat`. `rare_attribute_chance`
  stays 0.05 at the top level (gather already uses it).
- `game/data/recipes.json`: `skewer` and `campfire_skewer` slots carry `role`/`label` (Food, Tool) and the
  Tool slot's `allowed_ids` = `branch` (Stick), `raptor_bone` / `bone` (leg bone). No other recipe changed and
  no balance number moved.

**Preview UI**
- `CraftUI.craftfeel_text(qual)`: `Success N%   Flawless N%`, `Ability x / y needed` (only when a recipe has
  a requirement), `Inherits: Firm, Pointy`, `Materials are lost on failure.`
- The craft sheet's detail leads with those lines (`DetailChance` label), so they are visible before Craft.
- `CraftCard` gained an optional odds line (`CraftOdds`), fed by `StationCraft._show_card`, so the stakes are
  also on the floating card while the survivor works.
- Phone tap targets on the craft sheet raised to 64 px where they were 48-60 (Close, recipe rows, the row's
  Craft button); desktop unchanged.
- Food inspector: a flawless item reads `FLAWLESS +10% durability/quality`; material traits are listed
  (bookkeeping keys `quality` / `flawless_bonus` are skipped).

## Before / after

| | Before | After |
|---|---|---|
| Success chance | always 100 % (no roll) | spec 04 curve; 100 % for recipes without `required_ability` |
| Failure | impossible | spends the picked instances once, makes nothing, notice, no XP |
| Flawless | none | 5 % per successful craft, +10 % durability, quality marker (measured 5.35 % / 2000) |
| Rare trait | none from crafting | primary carries it (always) else 5 % roll (measured 4.85 % / 2000) |
| Skewer Tool slot | any `handle` (a club qualified) | stick or leg bone only (`allowed_ids`) |
| Preview | level/energy only | + success %, flawless %, inherited traits, loss warning |
| Craft screen smallest target, 844x390 | 48-60 px | 64 px |

## Verified
- `game/tests/t_craftfeel.gd` (new, gate stage 1): curve 0/50/80/100; a `min_level` gate still refuses
  before rolling; a failure spends each picked instance exactly once and makes nothing, no XP; 2000 seeded
  crafts at 5.35 % flawless / 4.85 % rare (±2 pp); a primary's rare trait is inherited; the skewer's Food +
  Tool slots, a club refused, a leg bone and a stick accepted; preview level/energy equals the result and a
  flawless craft keeps the level; `CraftUI.craftfeel_text` says the odds, the traits and the loss; XP paid
  once (9.0 for the skewer) and nothing on a material-less retry.
- `game/scripts/dev/craftfeel_lab.gd`: prints
  `[craftfeel] RESULT success_curve_ok=1 fail_consumes=1 flawless_rate=0.0535 rare_trait_rate=0.0485
  skewer_slots_ok=1 preview_matches=1 xp_once=1 ui_min_px=48` at 1600x900 and `... ui_min_px=64` at 844x390.
- Shots looked at: `craftfeel_01_preview_1600x900.png` (sheet on the skewer: chance, Inherits, loss line,
  ingredients, buttons), `craftfeel_02_failure_844x390.png` (the loss notice, one stone gone, no knife),
  `craftfeel_03_flawless_844x390.png` (food inspector: FLAWLESS line, Firm and Black Sheen traits).
- Related tests: `t_items`, `t_data`, `t_process`, `t_needs` PASS; `tools/smoke.sh` PASS; full
  `verify_job.sh craftfeel` PASS.

## Assumptions (`# ASSUMPTION` in code)
- **No recipe re-tuned.** The curve is in place but every live recipe has no `required_ability`, so it reads
  100 % (matching spec 25 §8's skewer). Adding requirements to recipes is balance, which the owner reserved.
- **Crafting Ability** has no attribute/gear stat in this build; the base is the governing skill level, plus
  learned `craft_ability` abilities and food `craft_ability` buffs. Tools and specialization can be added to
  `crafting_ability` later without touching the curve.
- **Flawless stat bump** = +10 % max durability plus the quality marker (no damage/armor formula changed).
  Level stays put so the preview equals the result; `flawless_level: true` opts a recipe into +1 level.
- **Rare trait value** on the output is 1 when it was rolled (a carried trait keeps its level); no conversion
  into equipment effects (Vital Strike etc.) — spec 04 lists those as reference conversions, not this task.
- **Skewer materials** map the docs' "Long Stick, Stick, Short Stick or a leg bone" onto the repo's items:
  `branch` (the stick family's item) and `raptor_bone` / `bone` (leg bones). No new items were invented.
- Server `intent_handlers._craft` is outside this job's scope and still uses the old direct path.

## What the integrator needs
1. **Data decision (owner):** which recipes get `required_ability` and at what values. Once one is set, the
   curve, failure, flawless and the UI all follow with no code change. Until then the live game reads 100 %.
2. **Server:** move `intent_handlers.gd::_craft` onto `Crafting.roll_outcome` + `commit_outcome` (same seed
   and picks) so an online craft fails and gains traits like an offline one. That file is out of this scope.
3. The lab's `ui_min_px` measurement is the smallest visible Button on the craft sheet; other screens were not
   audited.
