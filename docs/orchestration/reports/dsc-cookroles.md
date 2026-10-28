# COOKROLES — cooking recipes with slot roles and per-slot inheritance

Spec: `docs/design/durango-prompts/08_cooking_food_traits_and_individual_ingredients.md` §2–4.
Cooking slots now carry roles (main/topping/sauce/broth/spice/support) and per-slot inheritance
flags, working from exact ingredient instances through the existing crafting slot/plan/consume code.

## What shipped

- **`game/data/cook_roles.json`** (new): the six roles with their accepted/excluded item categories,
  per-role default inheritance flags, the trait → FOODFX effect table, the role → category → buff
  bonus table, and the bonus buffs themselves in FOODFX's buff-bundle shape.
- **`game/scripts/items/cook_roles.gd`** (new, `class_name CookRoles`): `is_roled`,
  `slot_role`, `role_accepts`, `role_categories`, `inherit_rule`, `collect`, `apply_to_output`,
  `effect_rows`, `buff_rows`, `role_bonus`, `sanitize_record`/`sanitize_buffs`, card/detail text.
- **`game/scripts/items/crafting.gd`** — two seams only, no fork of slot/plan/consume:
  `_allowed()` calls `CookRoles.role_accepts(slot, stack)` after the existing category check, and
  the tail of `build_output()` calls `CookRoles.apply_to_output()`. The collect record is read from
  the bag **before** the units are spent and threaded through `run_plan`/`plan_fits`/preview.
- **`game/scripts/items/food_effects.gd`** — `evaluate()` appends `CookRoles.effect_rows` (inherited
  traits only), adds the slot bonuses as buff rows in group `cooked_role`, and publishes
  `inherited` / `discarded` / `role_bonuses` for the UI.
- **`game/scripts/items/food.gd`**, **`game/scripts/ui/food_inspector.gd`** — "cooked in:",
  `inherited:` and `not carried:` lines.
- **`game/scripts/items/inventory.gd`** — `cooked_roles` / `cooked_buffs` added to `PLAIN_ATTRS` so
  the dish's record is named rather than dumped as a material trait.
- **`game/scripts/core/save_sanitizer.gd`** — dish records are rebuilt from untrusted save input.
- **`game/data/recipes.json`** — six new roled recipes (existing 174 untouched).
- **`game/data/foods.json`** — `cooked_role` buff group.
- **`game/scripts/dev/kitchen_lab.gd`** — a COOKROLES pass that cooks a roled recipe live, prints one
  `[cookroles] RESULT k=v …` line and saves shots at 1600x900 and 844x390.
- **`game/tests/t_cookroles.gd`** (new) → `[t_cookroles] PASS`.

## The rules as implemented

| rule (spec 08) | code |
|---|---|
| a role narrows a slot, it never replaces the category check | `CookRoles.role_accepts` (categories + `exclude`; `main` excludes `spice`) |
| only a recipe that opts in inherits | recipe-level `"inherit": true`; `inherit_rule()` returns `{}` otherwise |
| inheritance is per slot, from that exact instance | slot `"inherit": {traits, processed, flags, rare}`, merged over the role defaults; `collect()` reads `inventory.slots[idx]` for each `plan_parts` row |
| no stacking or averaging | first carrier of a trait key wins in slot order; the later one is recorded as dropped |
| rare (green) traits need a compatible conversion | `Crafting.is_rare_attribute()` traits only pass with `rare: true` |
| toppings/sauces/broth/spice add their own bonus | `role_bonus()` → buff row in group `cooked_role` |
| a dish's benefits come from its stored state | `attributes.cooked_roles` + `cooked_buffs`; `effect_rows()` reads only those |

Two different meats therefore produce two different dishes: `roled_grilled_meat` cooked from a
rich-cut raptor instance differs from the same recipe cooked from a gamey-cut instance, and the
difference is the FOODFX bundle, not a display string.

Six example recipes (`roled_grilled_meat`, `roled_berry_glazed_meat`, `roled_broth_soup`,
`roled_spiced_stew`, `roled_herb_roast`, `roled_salad`) cover: main only, main + non-inheriting
topping, an explicit main opt-out, main + spice + broth, main + herb + support, and a recipe-level
opt-out with no main at all.

## Verification

- `t_cookroles` PASSes: role enforcement (a spice in a main slot and a spice_herb in a main slot are
  both refused), inheritance with first-wins / rare gate / opt-outs, two instances of the same def
  producing different dishes, exactly the chosen instances consumed (and nothing else), cancel
  refunding every unit, eating through `EatSession` and seeing the inherited effect in the bundle,
  save round-trip, and forged-record hygiene through the sanitizer.
- `verify_job.sh cookroles 2` → `VERIFY HEADLESS-ONLY: visual lab deferred by owner` (a
  `HEADLESS_ONLY` marker sits in the gate dir). The lab itself was run regardless at 1600x900 and
  844x390 with `all_ok=1`; the 1600x900 shots show the cooking card over the bonfire with its three
  role slots and the food inspector with `inherited: Rich Cut 2` / `not carried: Black Sheen 1`.
  `[cookroles] RESULT roles_ok=1 inherit_ok=1 differ_ok=1 consume_ok=1 cancel_ok=1 foodfx_ok=1
  saved_ok=1 dishes=6 ui_min_px=64`.
- Full gate (`verify_job.sh cookroles`) → see the last section.

## Assumptions (every undocumented number is an `# ASSUMPTION` in the data)

- Role category lists and the `main`/`topping`/`sauce`/`broth` spice exclusion — the spec names
  roles, not their item categories.
- Default inheritance flags per role (main inherits traits/history/flags, everything else nothing).
- Trait effect amounts: `rich_cut` ×1.15 Energy + 2 Fullness per level, `gamey_cut` +4 Fullness
  +3 Thirst, `fresh_cut` +2 Health.
- Role bonus buffs: 600 s, +4 Perception (fruit glaze) / +2 Perception (herbal zing) /
  +2 max Fatigue (warming spice) / +3 max Health (broth comfort). Spec 08 §4 gives one unconfirmed
  community figure (~+4 ability) and no durations.
- The six recipes' stations, timers and slot counts. Their outputs are existing food items so
  FOODFX already has a bundle for each; no item ids were invented.
- Poison always survives cooking (`apply_to_output`), per the PRD's "MAY keep".

## What the next agent needs

1. **Role/inherit columns in `docs/current/recipes.md`.** That page is generated by
   `tools/docs_wiki/gen_game_data.py`, which is outside this job's SCOPE, so it was only
   regenerated (the six roled recipes now appear with their slots). To show roles, extend
   `slots_txt()` — e.g. append `" [%s]" % s["role"]` when `s.get("role")` — and add a short
   paragraph + an `inherit` column to the recipe table, then re-run
   `python3 tools/docs_wiki/gen_game_data.py`. `docs/current/survival-needs.md` already carries the
   rules in prose and is the authority for the behaviour.
2. **Sauce role has no recipe and no items.** `sauce` accepts `juice`/`sauce`/`drink`, and
   `broth_comfort`/`spice_warmth` exist as bonuses, but `items.json` has no sauce item, so no
   example recipe uses the role. Add sauce items first.
3. **Broth/meat quality is not inherited.** Slot 0 still carries the dish's level and quality, so a
   broth slot's ingredient quality does not influence the dish. The spec is silent; flagged, not
   implemented.
4. **No averaging anywhere.** Spec 08 §3 mentions recipes that may opt into averaging; none does.
   `CookRoles.collect` would need a new rule key if one ever should.
