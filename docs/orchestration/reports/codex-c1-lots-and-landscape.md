# C1 lot identity and landscape crafting

## Shipped

The existing craft menu scales its text and touch controls for the actual landscape window in mobile/touch mode. Main craft, details, batch, and close controls meet the 64-pixel target in the 844x390 simulated phone window. Station and recipe lists remain scrollable. Desktop rendering remains at its existing scale. A craft-lab layout check verifies the main controls' physical dimensions.

The new `MaterialLot` helper creates random 128-bit source identifiers for explicitly created lots, retains signed trait contributor records, rejects combining any overlapping ancestry, and calculates separate positive and negative totals capped at +20 and -20 percentage points. Raw contributor records remain intact. It validates malformed data and uses deterministic ordering. `ItemStack` preserves optional `attributes.material_lot` through its existing save format, deep-copies it on construction, and compares it structurally for stacking, including JSON integer/float normalization. Legacy attributes retain their previous behavior.

This is an opt-in data foundation, not playable fusion. No item drops are assigned signed traits or new source identities yet; no existing recipes, balance values, player data, or save schema were changed. No Meshy credits were spent.

## Verification

Starting HEAD `4fbf472c244e9bfd6400896913d0e0c6c10eed1f`, `origin/main` `923657262cd335fefee9126df61dd0fff4b93321`, branch `codex/c1-material-preview`.

- `c1_material_lot_regression.gd`: `C1 MATERIAL LOT PASS`. Checks source uniqueness, additive caps, separately preserved positive and negative effects, ancestor rejection, deep copies, split/JSON reload/merge, malformed data, and legacy stacking.
- `c1_material_preview_regression.gd`: `C1 MATERIAL PREVIEW PASS`.
- `c0_save_compat_regression.gd` and `c0_restore_regression.gd`: pass. Existing save fixtures cover schemas 0–3.
- Native Godot `--resolution 844x390 -- --lab=craft_lab --touch --c1-craft-layout-check`: `C1 CRAFT LAYOUT PASS`. Screenshots inspected in landscape at 844x390 and desktop at 1600x900. Actual device touch and notch safe areas were not tested.
- `tools/test.sh`: `[tests] PASS`; `tools/smoke.sh --no-import`: `SMOKE PASS`.

## Next agent

Wire provenance into real sourced materials and implement the opt-in two-source bone recipe only after checking allocation, output capacity, interrupted-craft refunds, and legacy inputs. Existing primary-only crafting is not a safe trait fusion path and must remain unchanged for old recipes. Add readable trait summaries instead of showing internal provenance in the crafting UI, and validate on a physical landscape phone. Do not merge or deploy without authorization.
