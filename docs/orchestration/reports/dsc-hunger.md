# dsc-hunger — hunger rework (memo Part 1)

Owner-approved memo: `origin/claude/mmo-hunger-tribe-doc:docs/design/hunger-and-tribe-automation.md`
Part 1 §1.4 items 1-6 and the §1.5 table. Worktree: `.claude/worktrees/mmo-hunger`.

## Shipped

**Data**
- `game/data/world/rules.json`: new `hunger` block — `decay_per_min` 2.5, band edges
  `empty_below` 10 / `peckish_below` 30 / `fed_below` 70 / `well_fed_below` 100,
  `fatigue_mult` per band (overfull 1.05, well_fed 0.85, fed 1.0, peckish 1.1, empty 1.3, starving 1.5),
  `starving_after_s` 600, `starving_stack_s` 180, `well_fed_regen` 0.2,
  `buff_off_below` 10. The old `fatigue.fullness_mult` map is retired; `Digestion.fatigue_mult_for`
  reads the hunger block.
- `game/data/foods.json`: fullness rescaled per class — raw fruit/berries/fish/mushroom/cactus 6-10
  and flagged `snack: true`, cooked 25-30, dishes 45-60, feast 80+; the seven dishes with meal buffs
  carry `duration_mode: "while_fed"`.
- `game/data/statuses.json`: `starving` is 0.1 HP/s per stack, 3 stacks, nonlethal, own amber colour;
  new `well_fed` boon chip (icon `well_fed.svg`, added to `ui_icons.json` and
  `assets/icons/ui/well_fed.svg`).
- `game/data/tribe.json`: `fullness_per_day` and `eat_below` dropped; members use the shared block.

**Code**
- `game/scripts/items/digestion.gd`: fullness is now a stored value in points (`stored_fullness`) with
  `add_fullness` (EatSession), flat decay in `tick`, bands via `state_for`. The save adds `fullness`
  and `empty_for_s`; an old save seeds `fullness` once from the previous formula (Σ food fullness ×
  undigested share) and stores it on the next save.
- `game/scripts/player/player_sim.gd`: Starving only after `starving_after_s` on an empty stomach,
  a stack every `starving_stack_s` (clamped to 3), cleared the moment a meal leaves the empty band;
  the `well_fed` chip plus `well_fed_regen` heal while in the band; autofeed fires at Peckish.
- `game/scripts/ui/hud_stomach.gd`: the inner ring reads the stored points and its colour stops follow
  the new edges (yellow plateau 30-45, green 70-100, red overfull); the outer ring shows the while_fed
  meal-buff time left.
- `game/scripts/player/buff_slots.gd` + `game/scripts/items/food_effects.gd`: `while_fed` rows are kept
  until fullness drops under `buff_off_below`.
- `game/scripts/tribe/tribe_member.gd`: decay, bands and eating all come from the shared block; the old
  `food_min` 15 floor is gone (it made a berry fill like a dish), so a berry adds its own 8 points.

**Tests**: `game/tests/t_hunger.gd` (new: rules, food classes, decay, bands, save/seed, while_fed,
starving delay), `t_foodfx` (new `_test_while_fed`: a real `crafters_meal` outlives its own 1200 s while
fed, its time left follows the stomach, it expires the tick fullness drops under 10), `t_starving` (new
`_test_dot_never_interrupts`: a starving tick neither cancels a gather nor ends a sleep, a hit does both;
plus the 600 s delay, 0.1 HP/s per stack, 1 HP floor), `t_needs` (a meal fills the stomach by its own
points and the Full status is no longer an eat gate), `t_tribe` (new `_test_hunger_shared`: no
`fullness_per_day`/`eat_below`/`food_min` in tribe.json, 60 s drains exactly the shared rate, a berry adds
its own points), `t_hudrules` (new band/ring stops). `tools/smoke.sh` still prints SMOKE PASS, and
`game/tests/run_all.gd` passes.

## Assumptions (also `# ASSUMPTION:` in code)
- The overfull ceiling is 120 points; a new survivor starts at 60 points (Fed).
- Starving damage is 0.1 HP/s per stack (0.1 / 0.2 / 0.3), first stack after 10 min empty, a stack
  every 3 min, capped at 3. The memo gives the shape, not the numbers.
- The `well_fed` chip carries no flags of its own — its fatigue and regen effects live in
  `PlayerSim` off the `hunger` block, so the chip can never double-apply them.
- Old saves seed the stomach from the pre-rework formula once; there is no migration version bump.
- A new survivor starts at 60 points and members' meals are worth their real `foods.json` fullness (no
  floor): a berry is 8, a roast 55. A member eats at Peckish (under 30) and nothing else changed.
- Starving only starts after 10 minutes *empty* (under 10 points), not after a peckish stretch; the
  comment "fed band" test in `t_starving` keeps that line.

## Save change
`digestion` (player metadata `foodfx_digestion`) gains `fullness` and `empty_for_s`; both are optional
on load. Nothing else in the save format moved.

## For the next agent
`t_starving` runs the status data, the ten-minute delay, the stack table and the 1 HP floor; the HUD
colour stops are pinned by `t_hudrules`. Part 2 (tribe automation) is untouched.
