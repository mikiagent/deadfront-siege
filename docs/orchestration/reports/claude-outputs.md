# claude-outputs — one recipe, several outputs by primary material

Task: `.dsc-task/TASK.md` (roadmap `outputs-by-primary`, design doc §7). Branch `claude/mmo-outputs`, merged with
`claude/mmo-overhaul` first. The DeepSeek worker's notes (`.dsc/NOTES.md`) set the direction; it wrote no code.

## What shipped

- `Crafting.output_for(rec, slot1_instance) -> Dictionary` (`game/scripts/items/crafting.gd`): returns the
  `outputs_by_primary` row keyed by the slot-1 instance's item categories (def order), then its material tier,
  else `output`. `build_output` reads its row through it, so the preview, the offline craft, `plan_fits`,
  `output_fits`, `run_plan` and the server `act.craft` op all agree. `bag_preview` reads it as well.
- UI: `CraftUI.output_row(inv, rec, picks = default)` wraps the call for the screens. D1 (`craft_ui.gd`: list
  row icon/name, detail head/stats/count) and D3 (`craft_place.gd` result fallback) use it, and so does
  `station_radial.gd` (one line). `group_of` still groups by the recipe's `output` (the family heading).
- Loader: `Data._load_recipes` logs `push_error` when a keyed row names no item.
- Data (`recipes.json`): `improvised_stone_knife`, `work_axe` and `work_pick` gain
  `{"stone": <old output>, "bone": bone_knife | bone_axe | bone_pick}`. No new items. The `bone_*` rows stay.
- Tests: new `game/tests/t_outputs.gd`. `t_data.gd`'s ladder walk now passes a stone head for the stone rung's
  keyed recipes (it picked the highest-tier blade_mat, which is now bone and makes the bone tool).
- Docs: `docs/current/recipes.md` (new OUTPUTS section and the three rows), `tools/docs_wiki/gen_game_data.py`
  prints the keyed outputs so a regenerate keeps them.

## Gates

t_outputs, t_craftfeel, t_cookroles, t_rareattr, t_uicraft, t_save (5 deliberate SCRIPT ERRORs), t_process,
t_buildquality, t_data: PASS. run_all `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
No lab screenshots were taken: the UI change only swaps which row the screens read.

## Assumptions

- ASSUMPTION: categories are tried before the tier, because untagged materials (raptor_talon) read as the
  `stone` tier and would otherwise make a stone head out of bone.
- ASSUMPTION: a bone head on the three converted recipes uses that recipe's cost and gate.

## Risks for the integrator

- Progression leak: `work_axe`/`work_pick` with 1 bone make a bone axe/pick, where `bone_axe`/`bone_pick` cost
  2 bone and need the `work_pick` node. `improvised_stone_knife` is a hand recipe, so it makes `bone_knife`
  without a workbench or the node. That is a balance question for the owner: drop the bone key, or retire the
  `bone_*` rows and gate the keyed row. Keyed rows carry no per-row gate or slot count today.
- `metal_shard` in these recipes still makes the stone tool (no metal axe item exists).
- `station_craft.gd`'s progress ring and the server's `bag_full` message still name `output` (cosmetic).
- Credits spent: none.
