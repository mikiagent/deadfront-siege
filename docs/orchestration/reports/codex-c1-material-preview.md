# C1 material preview slice

## Shipped

The existing crafting detail panel lists each automatically selected ingredient lot for the next craft, its level and current attributes, and marks the primary lot whose attributes are inherited under the existing rules. The list comes from the same allocation as consumption. It is explicitly a preview: inventory changes, travel to a station, or queued crafts may change later picks. No reservation or item-selection behavior was added.

Existing crafting signatures, recipes, item serialization, inventory counts, and save schema remain unchanged. The allocation summary now returns deep-copied attributes and a primary marker alongside its existing fields. New preview text scales up in touch mode; the rest of the existing craft menu still has small text and buttons at phone resolution.

## Next fusion slice

The owner asked for additive same-trait fusion and delegated the first recipe and cap. A concrete first design is: at a workbench, process one existing `dense_bone` into one `carved_bone_rib`, then combine two eligible, independently sourced ribs into one `reinforced_bone_block`. No catalyst for this first slice. `dense_bone` is already obtained by butchering and the workbench already exists. The rib and block and their recipes do not yet exist in the shipped data.

For percentage-based traits, use an additive cap of +20 percentage points for positive contributions and -20 percentage points for negative contributions, tracked separately so a drawback is not erased by an unrelated benefit. This is a lead-selected starting value under the owner's instruction to be creative, not a measured balance result. Other units require their own explicit cap. Store both contributor records even when the displayed total is capped.

Fusion is not implemented in this slice. The current game has no named signed-trait registry, actual per-lot provenance, or harvest roll for such traits. Implementing the recipe safely requires persistent source identities across splitting and saves; two genuinely independent consumed lots; a same-source anti-duplication rule; preview and consumption sharing the same plan; atomic refund on interruption; and defined effects and sourcing for the selected traits. Do not relabel arbitrary legacy `attributes` as signed traits or claim a functioning fusion recipe until those paths exist.

## Verification

Starting HEAD `31af74abc857a4ffb3e0f1f8ec0f4e4701747e99`; fetched `origin/main` at `923657262cd335fefee9126df61dd0fff4b93321`. Branch: `codex/c1-material-preview`.

- Baseline and final `tools/test.sh`: `[tests] PASS`; final `tools/smoke.sh --no-import`: `SMOKE PASS`.
- `c1_material_preview_regression.gd`: `C1 MATERIAL PREVIEW PASS`; covers multiple lots, distinct attributes, the primary marker, read-only preview, and agreement with actual consumption.
- Existing C0 restoration and schema 0–3 compatibility regressions: pass.
- `--lab=craft_lab`: exit 0; two different primary-material knives remain separate and the station two-tap flow passes. The lab prints `knife expected=32 got=1` in its second level example because the first craft raised the weapon skill to level 1, which then caps the second craft; the lab has no assertion for this stale expectation. This was not changed here.
- Visible native Godot: inspected 1600x900 desktop and 844x390 landscape with `--touch`. New lot text is legible in the landscape image; pre-existing recipe and station text remains very small. This is a simulated window, not a physical phone or notch/safe-area test.

No Meshy credits spent. The next agent should make the whole craft menu legible and touch-sized in landscape, and implement the fusion path only with source identity and transactional tests. Do not merge or deploy without authorization.
