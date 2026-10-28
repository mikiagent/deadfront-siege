# dsc — MATLOOK: natural material appearance, package 1 of 4 (data + tree→bag)

Spec: `docs/design/durango-prompts/35_natural_material_color.md` · Task: MATLOOK (spec 35 package 1).
Scope rule held: `game/data/materials/*.json`, `game/scripts/items/{item_stack,inventory,material_look}.gd`,
`game/scripts/world/harvest_node.gd`, `game/scripts/server/intent_handlers.gd`, `game/tests/{t_matlook,t_items}.gd`,
`game/tests/fixtures/*`, `docs/current/*.md`. Nothing outside the gate's SCOPE regex was touched.

## What shipped

| piece | file | what it does |
|---|---|---|
| species table | `game/data/materials/wood_species.json` (new) | 7 species — `birch, oak, acacia, palm, pine, snow_pine, willow` — each `{name, color #rrggbb, family, grain, variation{hue_deg, value}}`; `tree_kinds` maps every `tree`/`tree_dead` family in `nature_manifest.json` (20) plus the `tree_stump` prop; `default_species: oak`; empty `climate_overrides` hook |
| look model | `game/scripts/items/material_look.gd` (new, `class MaterialLook`) | `species_for(kind, climate)`, `look_for(kind, climate, seed)`, `look_for_species(id, seed)`, `stamp(stack, …)`, `validate(look)`, `sanitize(look)`, `default_look()`, `is_wood_item()`; seeded jitter (hue ±5°, value ±0.07) inside the species range |
| instance field | `game/scripts/items/item_stack.gd` | `look: Dictionary` (duplicate, merge identity, `to_dict` only when non-empty, `from_dict` through `MaterialLook.sanitize`) |
| gather, client | `game/scripts/world/harvest_node.gd:roll_yield` | stamps the node family's species, colour seeded from the same rng that rolls the count |
| gather, server | `game/scripts/server/intent_handlers.gd:_gather` | same stamp from the facade node's `family`/`climate` and the op's `ServerRng` (replay draws the same colour; asserted) |
| grouping | `game/scripts/items/inventory.gd:groups` | key is def_id + species; groups carry `species` (`""` for unlooked rows) |
| tests | `game/tests/t_matlook.gd`, `game/tests/fixtures/matlook_rows.json` (new) | species table, gather, independence, save/fixture, server, grouping, gate |
| docs | `docs/current/inventory-bags.md`, `docs/current/items-traits.md` | short facts on `look` (see the caveat below) |

Only wood defs get a look: everything the tree path yields that has the `wood` category (`wood_log`,
`pine_log`, `snow_pine`, `willow_wood`, `acacia_wood`, `branch`, planks/`split_wood`/`pillar`). Fruit,
fibre, bark, resin and stone from the same node carry none.

### Species ↔ tree-kind mapping (the `# ASSUMPTION`s live in `_about`)

| tree kind(s) | species | why |
|---|---|---|
| `PineTree`, `PineTree_Autumn` | `pine` | spec 35 Pine row |
| `PineTree_Snow` | `snow_pine` | the snowfield kind reads bleached; own species so a player can seek it |
| `BirchTree`, `_Autumn`, `_Snow` | `birch` | needs the spec's pale/whitish wood; borrows the spec Oak row |
| `CommonTree`, `_Autumn`, `_Snow`, `tree_stump` | `oak` | default wood; borrows the spec Maple row |
| `AcaciaTree` | `acacia` | the one reddish wood we have; borrows the Mahogany row |
| `PalmTree` | `palm` | spec Palm row |
| `Willow`, `_Autumn`, `_Snow` | `willow` | swamp/temperate; borrows a lightened Walnut row |
| every `*_Dead*` | its living kind's species | dead trees drop branches only; weathered look is a later package |

The spec's `almond`, `mahogany`, `maple`, `walnut`, `ebony` palettes and `oak`-as-pale-cream are **not**
species here: we have no almond, mahogany, maple, walnut or ebony tree, and our oak (CommonTree) is a
warm brown, not whitish. Only species our trees have are defined, as the task requires. Adding one is a
row plus a `tree_kinds` entry, no code.

## Test evidence (`game/tests/t_matlook.gd`, gate stage 1 + related)

```
[t_matlook] species=7 kinds=20 default=oak
[t_matlook] save: look round-trip ok; old row unchanged; 6 forged looks refused
[t_matlook] fixture: legacy unlooked=true honest=true forged dropped=true bag-roundtrip=true escrow=true
[t_matlook] server look={ "species": "acacia", "color": "#9d4c30", "family": "warm reddish-brown", "grain": "bold striped" } replay=true
[t_matlook] groups=3 species=oak, birch
[t_matlook] GAP vault.item(valid look) = "unknown item field look": … outside this job's scope
[t_matlook] PASS
```

| check | before | after |
|---|---|---|
| `t_matlook` | missing (gate baseline failure) | PASS, 0 SCRIPT ERROR |
| `t_items` | PASS | PASS |
| `t_inventory` | PASS | PASS (groups() still 3 groups / 16 slots in its own check) |
| `t_gather` | PASS | PASS |
| `t_data` | PASS | PASS |
| `t_srvdom` | PASS | PASS |
| `t_econ` | PASS | PASS |
| `t_save` | PASS | PASS (its 5 deliberate SCRIPT ERRORs stay) |
| `tools/smoke.sh --no-import` | — | SMOKE PASS |

What the test can actually fail on (checked by construction): a species with no colour/family/grain/
signed range, an unmapped tree kind, a mapped ghost kind, a log whose species is not its tree's, two logs
whose colour does not differ, a colour outside the range, a look that moves level/attributes/stats/spend
order, a trait that changes a look, a forged look accepted, an old row that gains a look, a missing
round-trip, a group merge across species, a replay that draws a different colour.

Baseline confirmation: the branch before this work has no `t_matlook.gd` and no
`game/data/materials/wood_species.json`, so every check above fails there (the gate's own first
failure line was `game/tests/t_matlook.gd is missing`).

## ⚠ OWNER GATE + one real gap for the integrator

1. **`look` is a new item-instance save field** (owner gate before merge, as instructed). It is additive
   and optional: a row without it keeps exactly its old shape, so old saves load unchanged and are never
   auto-filled. Cost: a legacy log simply has no swatch until re-gathered; I chose *no* auto-fill because
   filling would rewrite every old wood row on load and break the byte-identical save round-trip the
   server's escrow/`char.receive` relies on.
2. **The economy vault refuses a valid look.** `game/data/economy/limits.json` (instance-field whitelist)
   and `game/scripts/economy/asset_validator.gd` are **outside this job's SCOPE regex** (the conf names
   `game/data/econ/limits.json`, singular, which does not exist; the repo file is `economy/`), so I may not
   edit them. Measured verdict, printed by the test: `vault.deposit_item` on a looked log answers
   `unknown item field look`. **A traded log therefore loses vault eligibility until someone adds:**
   - `limits.json → instance_fields.look` as a typed object rule (species enum = the species ids in
     `wood_species.json`, family/grain text or enums, color `#rrggbb`, no jitter range beyond the species'
     own range — `MaterialLook.validate` already enforces the range if called from a `type: "look"` branch), and
   - `AssetValidator.ITEM_KEYS`/`_rule` handling for that object.
   The cleanest wiring: add a `"look"` type to `_rule()` that calls `MaterialLook.validate(v)` and
   returns its message. Nothing else in the economy needs to know: escrow keeps bodies byte for byte.
   The store side is already gated (`ItemStack.from_dict` sanitises, so a forged row value is dropped).

## Assumptions (all `# ASSUMPTION`-marked in the data/code)

- Spec palettes are illustrative: species borrow the nearest spec row and no colour is claimed as sampled.
- One species per tree kind; `climate_overrides` is an empty, honoured hook for a later split.
- Dead trees keep their living kind's species; `tree_stump` → `oak` (it drops `wood_log` with no kind).
- Jitter is ±5° hue / ±0.07 value — "subtle variation" is the spec's only guidance; no balance number moved.
- Forest-gate condition: `is_wood_item` uses the def's `wood` category, so a future wood-category item
  inherits appearance automatically without another mapping.
- Grouping key includes species even though `groups()` is visual only: a birch log under an oak heading
  would read as the same wood.

## What is deliberately NOT built (later packages)

Crafted-item tinting, recipe material selection/preview, building/wall/floor inheritance, packaged
prefab retention, the inspect-UI swatch and colour family chip, the gathering-UI swatch, and any
rarity/trait tie to colour (spec 35 §3 forbids it and the test enforces the separation).

## Notes for the integrator

- `docs/current/items-traits.md` is generated by `tools/docs_wiki/gen_game_data.py`; my section
  "Appearance is not a trait" is hand-written inside it and says so. The generator must learn to emit
  it, or the next regeneration drops it. `docs/current/inventory-bags.md` is hand-maintained.
- `MaterialLook.table()` parses `res://data/materials/wood_species.json` once per run (static cache).
  A missing file degrades to "no species", i.e. no look and no crash.
- If a later package wants the colour for rendering, `ItemStack.look.color` is the sRGB hex; do not
  read `attributes.tint` (that is the catalog's flat icon tint and stays untouched).
- `MaterialLook.HUE_TOLERANCE_DEG`/`VALUE_TOLERANCE` exist because a hex round-trip quantises hue; they
  are validation slack only, not colour design.
