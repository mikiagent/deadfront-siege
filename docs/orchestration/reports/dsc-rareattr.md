# dsc — RAREATTR (rare material attributes at gather, carried into crafts)

Task: roadmap item "Rare material attributes: 5% green-pip roll wired at gather, traits carried into crafts via primary
slots" (docs/design/islands-and-loop-plan.md §3.4 P7, spec 04:11/04:25/04:33, world-design.md:55, PRD:541).

## What shipped

A gather instance already rolled a 5 % green rare trait (W2-GATHER). Two things were missing: the trait was drawn from
one global pool of six for every material, and nothing proved spec 04:33's primary-slot rule. RAREATTR fixes the first
and proves the second, without a second trait system.

- `game/data/loot_tables.json` — `rare_trait.by_material`: each of the 52 gatherable ids has its own rare-attribute
  list. `rare_trait.traits` (the six) stays as the fallback for an item with no row; `chance` stays 0.05.
- `game/scripts/gather/loot_tables.gd` — `material_traits(id)` (the material's list, else the six) and
  `trait_materials()`.
- `game/scripts/gather/loot_roller.gd` — `roll_trait(rng, material)`; the pool is the material's list.
- `game/scripts/gather/gather_service.gd` — `stamp_traits` passes the landed instance's `def_id`. Client and the server
  (`act.gather`) share this path, so both get the same roll.
- `game/tests/t_rareattr.gd` — the proof (below).
- `docs/current/items-traits.md` — a hand-written "Rare material attributes (RAREATTR)" section (the rest of the file
  is generated; re-add this section after a regeneration until `gen_game_data.py` emits it).

`game/scripts/items/crafting.gd` needed **no change**: `build_output` already copies the primary slot instance's
attributes onto the output, and every one of the 174 shipped recipes marks slot 1 `primary: true`. The new test pins
that behaviour so a later change cannot silently copy secondaries.

## Before / after numbers

| measurement | before | after |
|---|---|---|
| gather rare-trait rate (20000 seeded gathers, real `stamp_traits`) | 5 % (data), 0.0215 when the global pool is forced back in | 0.0524 (within 5 % ± 0.5 pp) |
| traits from outside the material's own list | 1236 of the rolls when `stamp_traits` used the global pool | 0 |
| instances with two rare traits | 0 | 0 |
| material lists present | 0 (one pool of six) | 52 of 52 gatherables, every key one of the six |

## Verified (`game/tests/t_rareattr.gd`, headless)

```
[t_rareattr] pools 52 materials, 52 gatherables, missing 0, stray 0
[t_rareattr] roll rate 0.0524 over 20000 gathers (1048 hits, 52 traited materials, off-list 0, two-trait 0)
[t_rareattr] save/load stone=… "vivid_inspiration": true … uid kept, branch=… "narrow_hook": true
[t_rareattr] slot1 craft: picks [0, 1, 2] -> stone_knife_work { …, "black_sheen": true }
[t_rareattr] slot2 craft: picks [0, 1, 2] -> stone_knife_work { … }      (no black_sheen)
[t_rareattr] slot3 craft: picks [0, 1, 2] -> stone_knife_work { … }      (no black_sheen)
[t_rareattr] the gathered instance: rare ["low_vibration"], green 67b84e, rows [{ "text": "Low Vibration", "cls": "rare" }]
[t_rareattr] the crafted item:    rare ["low_vibration"], green 67b84e, rows [Durability, Damage, Low Vibration/rare]
[t_rareattr] PASS
```

Each check was shown able to fail: forcing `stamp_traits` back to the global pool fails the rate and off-list checks;
copying every consumed stack's attributes onto the output fails the slot-2 and slot-3 checks; a sanitizer that drops
boolean attributes fails the save/load checks; `InvAttributes.class_of` no longer classing rare keys fails 8 checks
(gathered and crafted pips, the grid mark, "still reads as rare").

`t_gather` (the existing gather suite) passes unchanged. The full gate runs `t_gather`, `t_save`, `t_craftfeel`,
`t_econ` and `tools/smoke.sh`.

## Shots

None. The gate's scratchpad carries the owner's `HEADLESS_ONLY` marker (visible Godot labs deferred), and the gate's
`LAB=gather_lab` lives in `game/scripts/dev/gather_lab.gd`, which is outside this task's SCOPE. The visual claim (the
green pip) is therefore measured through the same functions the UI calls — `InvAttributes.sections`,
`ItemInspectPanel.rows_for` (row class + `#67B84E` colour), `InvAttributes.has_rare` (the bag grid's mark) — not
photographed.

## Assumptions

- **Per-material lists (ASSUMPTION).** Spec 04:25 names conversions for five of the six traits and no per-material table.
  The shipped grouping: combat materials (stone, ore, metal, crystal, ice, pearl) → Black Sheen / Low Vibration
  (Vital Strike / Throw Dirt, Sadism / Pain Averse); tool-shaping materials (timber, fibre, cordage) → Wide Serration /
  Narrow Hook (gathering effects); workpieces (timber, earth, clay, resin) also → Split Easily (workstation effects);
  Vivid Inspiration has no documented conversion, so every material can roll it. Data only; retune freely.
- **Chance unchanged** at 5 % (world-design.md:55); no tool/skill bonus (spec 12:42 says Gathering level never raises it).
- **The craft's own luck roll is untouched** (`rules.json` `crafting.rare_attribute_chance`, 5 %, full six): spec 04
  gives it no material list, and it is CRAFTFEEL's measured number.
- **Fallback, not error,** for an item with no `by_material` row: it rolls the six. A new harvest id added to
  nature_manifest before its data row therefore keeps rolling instead of silently losing its rare trait.
- No balance numbers were tuned.

## What the integrator needs

1. `game/data/loot_tables.json` `rare_trait.by_material` is the one place to retune which attributes a material can
   roll. `t_rareattr` fails if a gatherable id has no row or a row names something outside the six, so a new node
   material needs a row here in the same change.
2. The gate's `LAB=gather_lab` cannot satisfy this task's lab contract: `gather_lab.gd` is outside SCOPE and prints
   no `[rareattr] RESULT` line. If `HEADLESS_ONLY` is removed the stage 2/3 lab step will fail on the missing RESULT
   line. Either point RAREATTR-like jobs at a lab inside SCOPE, or extend `gather_lab.gd` with a `[rareattr] RESULT`
   line (keys: rate, off_list, per_material count, slot1_carry, slot2_leak, green) in a follow-up.
3. `docs/current/items-traits.md` is generated except for the new section; if `tools/docs_wiki/gen_game_data.py` is
   re-run, re-add it (or teach the generator to emit it from `rare_trait.by_material`).
4. Nothing outside this task's scope changed: `crafting.gd`, `save_sanitizer.gd`, `inv_attributes.gd` and
   `gather_lab.gd` are byte-identical; the mutation experiments that touched them were reverted.
