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
- `required_ability(rec)` = the recipe's `required_ability` key. 35 recipes now declare one (review round 1,
  below); a recipe without it only has the existing `min_level` category gate, so it reads 100 % — the
  skewer of spec 25 §8 included.
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

**Live craft path (`game/scripts/items/station_craft.gd`)** — the plan is built once when the work starts and
reused (see review round 1 below); a failure never needs bag room.

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
| Success chance | always 100 % (no roll) | spec 04 curve; 35 gated recipes reach it (lowest 0.840 at its own gate) |
| Failure | impossible | spends the picked instances once, makes nothing, notice, no XP |
| Flawless | none | 5 % per successful craft, +10 % durability, quality marker (measured 5.35 % / 2000) |
| Rare trait | none from crafting | primary carries it (always) else 5 % roll (measured 4.85 % / 2000) |
| Skewer Tool slot | any `handle` (a club qualified) | stick or leg bone only (`allowed_ids`) |
| Preview | level/energy only | + success %, flawless %, inherited traits, loss warning |
| Craft screen smallest target, 844x390 | 48-60 px | 64 px |

## Verified (round 0)
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

## Review round 1 (findings 1)-(6) + regressions

The first round shipped the rules but left the loop open at four points. All are fixed:
**the curve had no reachable failure in shipped data**, **a retry could re-roll the craft**, **the craft
card only existed in the dev lab**, and **online play still used the old direct path**.

**Data (finding 1).** `game/data/recipes.json`: every recipe with `min_level >= 10` now declares an
explicit `required_ability = min_level + 40` (35 recipes; the four `min_level 55` raid pieces take 95).
Below that, the gate is still the category level alone, so early crafting is unchanged. The lowest
shipped success at a recipe's own gate is now **0.840** (`raid_maul`, level 55, ability 55 vs 95) and a
survivor several levels short fails outright; the curve is reachable in shipped data with no code path
needed. Documented as an ASSUMPTION in `rules.json` `crafting._about`: the values are gate level + a
fixed shortfall headroom, not a balance pass, and the owner can retune per recipe with no code change.

**One roll, reused (findings 2, 4, 5).** `Crafting` now splits planning from running:
- `plan_craft(rec, inv, picks, ability, level, burn_skill, rng)` returns one dict with the picks, their
  uids and defs, the outcome (success/flawless/rare), the burn result and the output level. One outcome
  roll, one burn roll, decided once.
- `plan_picks(inv, rec, plan)` re-resolves the plan's instances **by uid** wherever the bag moved them (a
  fungible stack falls back to def + slot); it returns `[]` when one left the bag, so the craft stops
  with nothing consumed instead of substituting a different stack (spec 08:98).
- `plan_fits(inv, rec, plan)` checks room using the plan's own burn and level; `run_plan` consumes,
  builds, applies flawless/rare and **never rolls**; `report_plan` is the notice + XP half (XP once, on
  success only).
- `finish_craft` (a dead duplicate) is gone; `craft`, `commit_plan`, `commit_outcome` and the server all
  run through one plan.
- `StationCraft` builds the plan in `_start_craft_cycle` and keeps it: a full bag holds the craft
  (`_full_wait`, one notice, inputs untouched) and the retry finishes on **the same** plan.
- Explicit picks are no longer a bypass: `_plan_ordered` requires an explicit pick to pass the slot's own
  `allowed_ids`, so a club named as the skewer's Tool cannot slip past the rule that rejects it.

**Live card (finding 3).** `StationCraft._show_card` runs at craft start in real play (not only in the
lab) and `set_progress` updates every frame: success %, flawless %, inherited traits, the loss warning,
and the material ring raised from 28 to **32 px radius (64 px box)**, the phone floor.

**Server parity (finding 6).** `IntentHandlers._craft` now builds the same `Crafting.plan_craft` (ability
from `craft_ability(ch.level_of(tree))`, the char's tree level as burn skill) and runs `run_plan` on the
server bag, then `ch.commit`. A failure returns `ok({failed:true, made:0, uids})` — materials gone, no XP,
no error; a full bag is `bag_full` with nothing consumed; a planned instance that left is
`insufficient_items`. Flawless and the inherited rare trait ride the same `apply_outcome`.

**Bug found while testing:** a finished live craft kept its spent `_plan`, so a queued or new craft could
reuse it. `_finish_one` now clears `_plan`/`_burnt` on completion.

## Review round 2 (BLOCKING): every planned unit is pinned, not just one lead per slot

A recipe slot can need 2+ units, and `_plan` fills that from a lead plus supplemental stacks. Round 1
pinned only the lead's uid/def per slot, so `plan_picks` resolved leads and then
`run_plan`/`plan_fits`/`consume_for_craft` recomputed the supplements from the bag **as it is at retry
time**: a full-bag wait (or a server op that lands later) could spend a different identified stack —
another level, other attributes, another uid — while keeping the original output level. What went in
did not match what the plan (and the card) said.

Fix, in `game/scripts/items/crafting.gd`:
- `plan_craft` now stores the complete part list it will spend, per slot, with each part's `uid`, `def`,
  `count`, the recipe slot it fills and the bag slot it was planned in:
  `parts: [{slot, uid, def, count, at}, ...]`. The lead uid/def lists stay for the card and the tests.
- New `plan_parts(inv, rec, plan)` resolves those exact parts against the current bag and is the only
  thing `plan_picks`, `plan_fits` and `run_plan` use. An **identified** part whose uid is gone makes it
  return `[]` with no mutation, even if the same def sits elsewhere (no substitution, spec 08:98); a
  fungible part (no uid) still resolves by def, preferring the slot it was planned in. It also re-checks
  the category/`allowed_ids` of the slot and that the stack still holds >= the pinned count. It runs in
  one pass over the bag plus the parts (uid map), not O(parts x bag).
- New `consume_parts(inv, rec, parts)` spends exactly the resolved parts, primary slot first (output
  attribute/process inheritance keeps its old order); `run_plan` and `plan_fits` both call it, so the
  fit simulation and the real consume free the identical slots.
- `run_plan` returns `left` with nothing consumed when a part cannot be resolved, before any consume.

## Review round 3 (BLOCKING): fungible units are pinned by value, not by slot

Round 2 pinned uid-carrying parts exactly, but an **uid-less** (fungible) part was still resolved by
"the same def in the recorded slot, else the first same-def stack". Two same-def stacks may legally
differ in level, process count, attributes, flags and durability and sit in separate slots
(`ItemStack.can_merge_with` says so), so after a reorder the resolver could hand the craft stack C while
`run_plan` kept the plan's original output level and inherited C's traits: the plan said B, the game spent
C.

Fix, in `game/scripts/items/crafting.gd`:
- Every planned part now carries the value fingerprint of the stack it came from, alongside its uid:
  `level`, `process_count`, `attributes`, `flags` (as strings), `durability`, `max_durability`, plus
  `def`, `count`, the recipe `slot` and the bag slot `at` it was planned in (`_pinned_part`).
- `_same_good(row, stack)` compares exactly what `ItemStack.can_merge_with` compares (def, level,
  process, durability/max, flags, attributes ignoring the `climate` bookkeeping key), and rejects an
  identified stack as a stand-in for a fungible part.
- `plan_parts` resolves a fungible part only to an equivalent stack: the recorded slot first when it
  still holds the same good, then any other equivalent stack of that def; otherwise it returns `[]` with
  no mutation, so `plan_fits`/`run_plan` return `full`/`left` untouched instead of substituting.
  UID parts behave exactly as in round 2.
- The resolution is still one pass over the bag plus the parts (uid map + per-def candidate lists), so
  the added fingerprint comparison only runs for the parts actually being resolved.

## Verified (round 3)
- New `_test_fungible_fingerprint` in `t_craftfeel`: three uid-less `stone` stacks, A (level 5, firm 1),
  B (level 40, firm 4), C (level 60, firm 9). The plan pins A+B with their own level and attributes; then
  C is moved into B's old slot and the bag is reordered. `plan_parts` resolves A+B only (never C), `run_plan`
  consumes exactly A+B, C survives, and the output level is the pin's (not 60) with firm != 9. Replacing B
  with C (same def, other value) makes `run_plan` return `left` with nothing consumed and nothing made.
- Mutation check: a def-only `_same_good` fails 5 of these assertions (C accepted in B's slot, level 60,
  firm 9 inherited, no `left`), so the fingerprint is load-bearing.
- Related: `t_items`, `t_data`, `t_process`, `t_inventory`, `t_server_domain` PASS; `t_craftfeel` PASS
  with no SCRIPT ERROR.

## Verified (round 2)
- New `_test_supplement_pinning` in `t_craftfeel`: a slot with `count: 2` gets an identified lead
  (level 5, uid `laaa…1`) and an identified supplement (level 40, uid `lbbb…2`); the plan pins **both**
  units and carries the level those units give. A better identified stack C (level 60) is then inserted
  and the bag reordered: `plan_parts` still resolves A+B only, `run_plan` consumes exactly A+B, C
  survives untouched, and the output level is the plan's (not C's 60). Removing the pinned B and adding
  an eligible level-40 substitute returns `left` with the lead and the substitute untouched and nothing
  made.
- Mutation checks: dropping the "identified uid gone -> []" rule, or ignoring pinned uids entirely,
  each fail the assertions (the second fails 5+ of them), so the pinning is genuinely load-bearing.
- Related: `t_items`, `t_data`, `t_process`, `t_inventory`, `t_server_domain` PASS; `verify_job.sh
  craftfeel` stage 1 + stage 2 (headless-deferred) PASS.

## Verified (round 1)
- `game/tests/t_craftfeel.gd`, 99 assertions, all PASS; it now asserts the round-1 regressions:
  shipped-data reachability (35 gated recipes, lowest 0.840 at its own gate, value read from data);
  explicit club pick refused; two full-bag retries holding then landing on one plan; one burn value per
  plan (a `grill` plan with `burnt=true` yields burnt food, `false` yields grilled meat, no second roll);
  uid preservation across a bag sort and a "left" stop with a legal substitute in the bag; the live card
  visible with Success/Flawless/loss text and a >= 64 px ring; a live station craft that fills its bag
  mid-work holds twice and lands once room appears; online parity (shared curve, twine success pays XP
  once, club pick -> `insufficient_items`) and online stakes (a pinned failure recipe through the real
  `store.apply("act.craft")` loses exactly the picked unit by level, pays no XP; a success makes 1 and
  pays 7.0 XP once; flawless + `black_sheen` applied by the server path).
- Mutation check: making `run_plan` roll its own burn fails 4 of those assertions, so the no-re-roll
  tests can actually fail.
- Related: `t_items`, `t_data`, `t_process`, `t_server_domain` PASS; `verify_job.sh craftfeel` PASS.

## Assumptions (`# ASSUMPTION` in code)
- **`required_ability = min_level + 40`** on the 35 recipes with `min_level >= 8` is a deliberate
  ASSUMPTION (documented in `rules.json` `crafting._about`) to make the curve reachable in shipped data.
  It is not a balance pass: early recipes (min_level 0) keep 100 %, and every value can be retuned in
  data alone.
- **Crafting Ability** has no attribute/gear stat in this build; the base is the governing skill level,
  plus learned `craft_ability` abilities and food `craft_ability` buffs.
- **Flawless** = +10 % max durability plus the quality marker; level stays put so the preview equals the
  result (`flawless_level: true` opts a recipe into +1 level).
- **Rare trait** value on the output is 1 when it was rolled (a carried trait keeps its level).
- **Skewer materials** map the docs' "Long Stick, Stick, Short Stick or a leg bone" onto `branch` and
  `raptor_bone` / `bone`; no items were invented.

## Deferred
- **Visual lab gate.** The owner reserved the machine for this round (`HEADLESS_ONLY`): no window may be
  opened, so the 1600x900 / 844x390 lab shots and the `[craftfeel] RESULT ... ui_min_px` line are
  **deferred to the orchestrator**. Every headless stage passes; the ring size (64 px) and the card text
  are asserted headlessly instead.
- The report's earlier lab numbers (`ui_min_px=48` at 1600x900) predate the ring change and are not a
  fresh measurement this round.

## What the integrator needs
1. Re-run the visual lab when the machine is free: it prints `[craftfeel] RESULT ... ui_min_px=64` at
   844x390; expected shots are the craft sheet with odds, the live craft card, and the loss notice.
2. Tuning only: the 35 `required_ability` values are the owner's to adjust; no code depends on the exact
   numbers (the test reads the data value, it does not hard-code 50/95).
