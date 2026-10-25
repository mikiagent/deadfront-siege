# dsc-foodfx — spec 32 (eating and drinking have effects beyond a flat Energy number)

Branch `claude/mmo-foodfx` (worktree `mmo-foodfx`). Gate: `verify_job.sh foodfx`
(stage 1 = `t_foodfx`; stage 2 = the lab at 1600×900 and 844×390 + shots — **deferred**, see below;
no stage = related tests `t_needs t_items t_save t_ui` + `tools/smoke.sh` + report + scope).

## Owner directive this run: HEADLESS ONLY
The gate directory contains `HEADLESS_ONLY`, so every Godot launch here was `--headless`, Dummy audio,
under the `gslot.sh` slot wrapper, with a timeout and a scratch HOME. **No screenshot or visual approval
was made and none is claimed.** The lab still runs headless (both `--script res://scripts/dev/foodfx_lab.gd`
and `godot --headless res://scenes/dev/foodfx_lab.tscn`) and prints the full `[foodfx] RESULT` line; when
handed `--shot-dir` it prints `screenshot <name> skipped: headless cannot draw` instead of writing a PNG.
Consequence for the orchestrator: `MIN_SHOTS=3` at each of the two window sizes is **unmet and unverified**,
so stage 2 must be re-run windowed on a free machine before this counts as visually approved.

## What shipped

### Data
- **`game/data/foods.json` (new).** One consumption bundle per item id: `channels`, per-field
  `transforms` (processing level / freshness / temperature), `caps`, `buff_groups`
  (`enhanced_ability`, `enhanced_survival`), `stat_keys` (+ `_player_map`), `taste_grades` +
  `flavors` + repeat penalty, `defaults` (instant ratio 0.5, digest 300 s, eat 3 s, Full 10 s) and
  `provenance` tags (`extracted-client`, `community-described`, `restoration-evaluated`, `new-design`).
  Every number that spec 32 does not give carries an `assumption` string on its entry (11 entries).
  Bundles exist for: `spring_water`, `tea`, `drip_coffee`, `dutch_coffee`, `berry`, `grilled_meat`,
  `skewer`, `camp_stew`, `raw_meat`, `crafters_meal`, `fatigue_tonic`, `herb_buff_meal`. An item with
  **no** bundle keeps the old Energy-only path, so nothing outside the slice changed balance.
- **`game/data/items.json`**: six new items (`spring_water`, `tea`, `drip_coffee`, `dutch_coffee`,
  `crafters_meal`, `fatigue_tonic`), all marked `source_pending` (no brewing/cooking recipe yet) so
  `t_data`'s reachability walk stays honest; `game/data/item_rarity.json` mirror and the icon aliases
  updated for them.
- **`game/data/statuses.json`**: 23 → 30. Added `caffeinated`, `tastes_great`, `tastes_delicious`,
  `tastes_horrible`, `tastes_disgusting`, `hot_food`, `cold_food`. The two "horrible" grades reuse the
  existing `StatusEffects.fatigue_mult` → `Vitals.fatigue_gain_mult` path, so the taste penalty is real,
  not decorative.

### Code (new)
| File | Role |
|---|---|
| `game/scripts/items/food_effects.gd` | the single evaluator: `evaluate(instance, ctx)`, `split(latent, ratio)`, `preview(stack, player)`, `transforms_for`, `apply_op`, `cap_for`, `player_stat`, `warnings` (conflict validation) |
| `game/scripts/items/taste.gd` | `dominant`, `score` (repeat-penalty memory), `grade_for` |
| `game/scripts/items/digestion.gd` | delayed Energy rows: `schedule`, `tick`, `total_remaining`, `to_dict`/`from_dict`; lives on the Player as meta `foodfx_digestion` |
| `game/scripts/items/buff_slots.gd` | grouped timed buffs, replace-per-group, `would_replace`, `stat_add`/`stat_mult`, `tick`, save dict; meta `foodfx_slots`; mirrors its rows into `FoodBuffState` |
| `game/tests/t_foodfx.gd` | 120 `ok` asserts, headless |
| `game/scripts/dev/foodfx_lab.gd`, `game/scenes/dev/foodfx_lab.tscn` | the lab, one `[foodfx] RESULT` line + `[foodfx] note` measurements |

### Code (changed)
- **`game/scripts/items/eat_session.gd`** is now the spec 32 §11 transaction:
  validate (`Food.can_eat` + `FoodEffects.evaluate` once, for that exact instance) → timed action
  (`eat_seconds` from the bundle) → interrupt refunds everything → atomic consume of *that* instance →
  immediate effects → schedule digestion → buff slots → taste → temperature/raw risk. `_process` also
  ticks `BuffSlots` and `Digestion`, so buff expiry and delayed Energy advance with the survivor's food
  clock; `advance(delta)` is split out so a test/lab can drive fixed steps.
- **`game/scripts/combat/vitals.gd`**: `food_max_fatigue` / `food_max_energy` + `effective_max_fatigue()`
  / `effective_max_energy()` + `sync_food_caps()`. Every clamp, the stamina cap, regen multipliers and the
  exhaustion threshold now read the effective values.
- **`game/scripts/ui/food_inspector.gd`**: the §12 card — level, exact traits, instant vs over-time
  Energy, Fullness, Thirst, Health, Fatigue, max-stat effects, ability bonuses, negatives, buff group,
  duration, eat time, and a line naming the active buff this food would replace. Body in a
  `ScrollContainer` so Eat/Feed/Close (64 px) never leave the canvas; `shown_min_px` / `shown_fits` /
  `shown_replaces` are measured for tests and the lab.
- **`game/scripts/core/save_game.gd`**: `player.foodfx = {buffs, digestion}` written and restored
  (before the status sync), with capacity re-synced on load.
- **`game/scripts/items/food.gd`**: `is_raw` / `raw_risk_roll` also read the bundle, so a raw berry's
  Stomach Pain chance is data.

## Before / after (behaviour changes an integrator must know)
1. **A cancelled eat now grants nothing.** Before, Energy was dripped in while the bar ran and a cancel
   kept what had been paid. §11.4 says a cancelled action "should not consume the item or grant effects",
   so the instant share is paid once, at the commit. Past half, a raw meal still rolls its risk and Full
   still applies (unchanged, `sec-eat-23`).
2. **The item is consumed at the commit, not at the start.** The bag no longer loses the item when the
   bar begins; `_consumed` ids make a double fast-tap unable to take one instance twice.
3. **`Vitals.max_fatigue` / `max_energy` are base stats again.** A Maximum Fatigue buff raises the
   *ceiling* (`effective_max_fatigue()`), never the saved base, and expiry only re-clamps current values.
   Any out-of-scope reader still comparing `fatigue` to `max_fatigue` should move to the effective pair.
4. **Food buffs live in `BuffSlots`, mirrored into `FoodBuffState`.** `scripts/player/food_buff_state.gd`
   is outside this job's scope, so `BuffSlots._sync` rewrites its own rows into it (keys prefixed `fx_`).
   Existing readers (`Crafting.crafting_ability`, Player heat/cold resistance) keep working untouched.
   Legacy `food_buffs.json` rows still go through `Food.apply_buffs` and still stack.
5. **`t_needs`' expectation of Full-on-cancel** was already satisfied; the only test-side change was
   making that expectation explicit for the new refund path (nothing else in `t_needs` moved).

## Historical vs assumed (spec 32 §15)
**From the spec / reconstruction:** the channel list (§1), the Energy split rule and the 200 @ 0.4 example
(§2), "ability buffs, never category levels" with the +20 Weapon Crafting Ability example (§3), the two
exclusive buff groups (§4), the drink figures for Tea 22.4 + 22.4 and Dutch Coffee 47.9 + 8.4 and its
Maximum Fatigue +132.8 for 20 min (§5), the Bacon Fullness row (§6), taste grades (§7), the evaluator
order (§8), Stomach Pain from bad raw food (§9), the §11 transaction, the §12 line set, and the §13
save/digest-once requirement.

**Assumed (this build's own placeholder, marked `# ASSUMPTION` in data and listed per entry):** every
`caps` value, the 0.5 default instant ratio, 300 s digestion, 3 s eat, 10 s Full, every taste threshold
and the repeat penalty, all Fullness/Thirst/Health/Fatigue numbers not quoted above, the berry's 12 % raw
chance and 4 min duration, the skewer's 0.6 ratio and Fullness 20, the stew's Fullness 30 / Health +5,
the meal's 20 min duration, and the fatigue tonic's magnitude. Tune them in `foods.json` only — no code
constant duplicates them.

## Verified (headless, this worktree)
- `game/tests/t_foodfx.gd` **PASS**, 120 `ok`, no `SCRIPT ERROR`: split 0 / 0.4 / 1 and the clamp;
  bundle data + provenance + conflict warning; instant vs digested measured on real Energy; the delayed
  share paid exactly once (and once after a reload); interrupt consumes and grants nothing; a second
  intent is blocked; group replace and group coexist; max-fatigue expiry clamps and never touches the
  base; tonic vs cap distinction; plain food leaves an unrelated buff alone; an ability buff moves
  `Crafting.crafting_ability` 1 → 21 and the success chance on a real recipe without moving a level;
  raw berry → Stomach Pain; save/load of digestion + buffs + capacity; the §12 card lines; 64 px targets
  and `fits=true` at 1280×720.
- Lab (`--lab=foodfx_lab`, headless): `[foodfx] RESULT instant_split_ok=1 digest_once_ok=1
  interrupt_refunds_ok=1 double_eat_blocked_ok=1 buff_slots_ok=1 maxfatigue_expiry_ok=1
  fatigue_vs_maxfatigue_ok=1 buff_coexist_ok=1 plain_food_keeps_buff_ok=1 ability_check_moves_ok=1
  bad_food_status_ok=1 taste_grade_ok=1 save_roundtrip_ok=1 ui_min_px=64`. Same line from the `.tscn`.
  The line prints the four names `job_foodfx.conf`'s `LAB_ASSERT` uses without the `_ok` suffix as well
  (`interrupt_refunds`, `double_eat_blocked`, `plain_food_keeps_buff`, `save_roundtrip`), so one line
  satisfies either spelling; the lab also takes a third frame (`food_card_tea`) so `MIN_SHOTS=3` can be met.
- Related: `t_needs`, `t_items`, `t_save`, `t_ui` all PASS. `t_save` prints `SCRIPT ERROR` lines by
  design (its abort/sanitizer probes); the gate exempts it.
- Not verified here: windowed lab at 1600×900 / 844×390 and the screenshots (HEADLESS_ONLY).

## What the next agent needs
- **Run stage 2 windowed** on a free machine: `bash docs/orchestration/dsc/gates/verify_job.sh foodfx 2`.
  Expect `ui_min_px=64` at 844×390 (the assert demands ≥64 there, ≥44 at 1600×900) and 3 shots per size.
- **Recipes.** The six new items are `source_pending`: they need brewing/cooking recipes (station +
  ingredients) before a survivor can reach them without the lab. Until then they exist for the effect
  system only, and `t_data` will keep flagging them if `source_pending` is removed early.
- **Consumers that do not exist yet.** Attribute and combat-stat buff rows are carried, printed and saved
  but move nothing, because this build has no shared player attribute/attack stat (weapon damage comes
  from the equipped item); `FoodEffects.player_stat` therefore maps only `max_fatigue` / `max_energy` and
  the professions onto `craft_ability`. The Phenomenal XP multiplier is carried in the grade row but there
  is no single XP grant path to multiply. Both are gaps to close with the attribute system, not faked here.
- **Out-of-scope follow-up:** if `scripts/player/food_buff_state.gd` is ever rewritten, `BuffSlots._sync`
  is the only writer of the `fx_` rows and must move with it.
