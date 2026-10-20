# W2-INV report: inventory and equipment by instance

Branch `claude/mmo-w2-inv`. Base claude/mmo-overhaul (1c89134a) merged in d8ea22f2.

## What shipped (owned files only)
- `game/scripts/items/item_def.gd`: materials and food no longer stack (owner 2026-10-20, prompts 05/08). Only `STACKING_CATEGORIES` (ammunition, siege_ammunition, counter_supply, medicine, building) keep the data's `stack_max`; everything else is 1. A new field, `legacy_stack_max`, holds the pre-change per-row ceiling, which the save sanitizer uses. I removed the dead `damage_at`/`armor_value_at`/`max_durability_at`; level scaling stays on ItemStack.
- `game/scripts/items/inventory.gd`:
  - Bag of instances, `BASE_SLOTS = 100` (pack 05).
  - Equipment container: `equip_at(index, slot)` wears the exact item and takes it out of the bag. Gear already worn in that slot swaps back into the freed slot. An item only goes into its own slot.
  - `equip(slot, id)` remains a compatibility path and wears the highest level.
  - `unequip` is refused when the bag is full, so gear is never dropped.
  - Int (bag index) and String (legacy def id) equipment values still resolve. The server's CharacterState relies on this.
  - `can_accept()`, `sort()` (the chosen tool follows its item), `add_growing()` for corpse loot.
  - `remove_at`, `consume` and `consume_by_category` refuse amounts of 0 or less.
  - The automatic tool is picked by work tool first, then highest `gather_power`. The worn weapon counts as a tool.
  - Every non-stacking unit gets a local uid. Only the uid is set, so the server's journal replay stays deterministic.
  - Worn gear saves under `inventory_extras.worn`. Legacy `equipment` def-ids migrate by moving the item out of the bag.
  - `load_array(raw, overflow)`: the migration. It splits stacked rows into one instance per unit and keeps each row's level and attributes. Overflow goes to the `overflow` container (home cargo), or the container grows. Nothing is deleted. A forged save is capped at 100k units. The migration logs a `[inv] migration:` line.
- `game/tests/t_inventory.gd` (new): exact equip through sort and JSON reload, bad amounts, worn gear out of the bag, full-bag unequip refusal, swap, best tool, no stacking, split migration with overflow and with growth, legacy equipment migration, hostile worn rows, identity through transfer. I checked that it can fail: breaking the amount guard and the gather_power comparison gave 5 FAIL lines.

## Integrator hooks (required): `docs/orchestration/reports/claude-mmo-w2-inv-hooks.patch`
Apply with `git apply`. It passes `git apply --check` on d8ea22f2. Contents:
- save_sanitizer.gd: clamp counts to `legacy_stack_max`. Without this, every legacy stack loads as 1, which is **data loss**. Also sanitizes `worn` rows.
- save_game.gd: player bag `load_array(rows, World.cargo_home)`.
- player.gd: `Inventory.new()` (100 slots).
- character_state.gd: `BAG_SLOTS = Inventory.BASE_SLOTS`.
- crafting.gd `_plan`: draws the lead's own def first, so a twine is not eaten as fibre.
- corpse.gd: `add_growing`.
- inventory_ui.gd: the grid grows to slot_count, and Equip uses `equip_at(_selected, slot)`.
- Tests and fixtures that encoded stacking:
  - t_save: helm is now worn, 25 bag rows, a new `_test_stacked_migration`, add-then-equip staging, regenerated goldens, new fixture `save_v3_stacked.json` (the old golden).
  - Also t_tame, t_items, t_player, t_build, run_all, multistack_lab, srvdom_checks and craft_lab.

## Gates (lines seen)
- Branch alone (d8ea22f2):
  - `SMOKE PASS`; `[t_inventory] PASS`.
  - t_ai, t_canim, t_combat, t_harbour, t_iconart, t_light(ing), t_occlude, t_structart, t_ui, t_uiicons, t_web PASS.
  - FAIL until the patch is applied: run_all (count=7), t_build, t_items, t_player, t_save (24), t_srvdom, t_server_domain, t_tame. These tests encode stacking.
- With the patch applied:
  - `SMOKE PASS`; `[tests] PASS`.
  - All 21 t_*.gd PASS, including `[t_save] PASS` and `[t_inventory] PASS`.
  - `[equiplab] PASS`, `[craft_lab] PASS`, kitchen_lab exit 0.
- Screenshots: ui_family_lab at 1600x900 and 844x390 were written to scratch with exit 0 and 0 SCRIPT ERROR. **I did not look at them**, so I make no visual claim.

## Owner decisions / flags
- **Save format change**:
  - Bag rows are now one instance per unit, each with a uid.
  - Worn gear has moved to `inventory_extras.worn`, and new saves no longer write `equipment`.
  - Old saves migrate on load, and overflow goes to home cargo, which grows beyond 60 rather than drop items. Older builds cannot read the new saves correctly.
- Which categories still stack is an ASSUMPTION (the list above).
- Full-bag crafting refusal and the make-room wait can no longer happen for single-output recipes, because spent instances always free a slot.

## Assumptions
- `STACKING_CATEGORIES` list.
- MAX_LOAD_UNITS = 100000.
- Gathered items have origin "" locally.
- A slot index for the held tool remains (it is cleared when its slot empties).

## What is left
1. Orchestrator: apply the hooks patch, rerun all t_*.gd and run_all, then merge.
2. Look at the two inventory PNGs. The 100-slot bag needs W2-SCREENS's grouped or virtualized grid (pack 05 visual grouping). The hook only appends buttons.
3. Server store: legacy stacked rows in existing server characters are not split. A store migration that mints `i<seq>.<k>` uids is needed. Server worn gear also stays in its bag (by uid), so it still occupies server bag slots.
4. Corpse take XP is a flat +3 per take (player_actions.loot). With instances, 3 meat now pay 9 XP. That owner should review it.
5. Pocket and equipment capacity bonuses, and the consume order that protects rare instances (pack 05), are not done.
6. `health_bonus_at` / `food_energy_at` should move to ItemStack (W2-PROCESS).
