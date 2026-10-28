# claude-outputs — one recipe, several outputs by primary material

Task: `.dsc-task/TASK.md` (roadmap `outputs-by-primary`, design doc §7). Branch `claude/mmo-outputs`, merged with
`claude/mmo-overhaul` first. The DeepSeek worker's notes (`.dsc/NOTES.md`) set the direction; it wrote no code.

## What shipped

- `Crafting.output_for(rec, slot1_instance) -> Dictionary` (`game/scripts/items/crafting.gd`): returns the
  `outputs_by_primary` row keyed by the slot-1 instance's declared tier (`tier_<t>` category), then its item
  categories (def order), then its computed material tier, else `output`. `build_output` reads its row through it, so the preview, the offline craft, `plan_fits`,
  `output_fits`, `run_plan` and the server `act.craft` op all agree. `bag_preview` reads it as well.
- UI: `CraftUI.output_row(inv, rec, picks = default)` wraps the call for the screens. D1 (`craft_ui.gd`: list
  row icon/name, detail head/stats/count) and D3 (`craft_place.gd` result fallback) use it, and so does
  `station_radial.gd` (one line). `group_of` still groups by the recipe's `output` (the family heading).
- Loader: `Data._load_recipes` logs `push_error` when a keyed row names no item.
- Data: **mechanism only, no recipe uses it yet.** A first commit keyed the work knife/axe/pick by bone; the
  coordinator reverted that data (and the `t_data.gd` tweak it needed) because it skips the bone-tool cost and
  gate. The decision is Open Questions 2026-10-28 **A6**.
- Tests: new `game/tests/t_outputs.gd` builds keyed copies of the work knife/axe/pick in memory
  (stone/bone/flint keys plus the fallback), registers them in `Data.recipes` for the server op, removes them
  after, and asserts no shipped recipe carries the key.
- Docs: `docs/current/recipes.md` (OUTPUTS section, "mechanism only"), Open Questions A6, `tools/docs_wiki/gen_game_data.py`
  prints the keyed outputs so a regenerate keeps them.

## Gates

t_outputs, t_craftfeel, t_cookroles, t_rareattr, t_uicraft, t_save (5 deliberate SCRIPT ERRORs), t_process,
t_buildquality, t_data: PASS. run_all `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
No lab screenshots were taken: the UI change only swaps which row the screens read.

## Assumptions

- ASSUMPTION: key order is declared tier (`tier_flint` makes flint a flint head despite its `stone`
  category), then categories (an untagged raptor_talon reads as `bone`, not the default `stone` tier), then
  the computed tier (metal_shard reads as flint by hardness, so a `flint` key catches it).
- A keyed row has no cost or requirements of its own (A6 asks whether it should).

## Risks for the integrator

- Whoever keys a recipe family later must check the cost/gate leak: e.g. keying the work axe by bone would
  make a bone axe from 1 bone without the `work_pick` node.
- `station_craft.gd`'s progress ring and the server's `bag_full` message still name `output` (cosmetic).
- Credits spent: none.
