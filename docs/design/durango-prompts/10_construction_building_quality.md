# Durango: Wild Lands Inspired Construction and Building Quality System

## Objective

Implement a complete **construction, modular housing, building quality, material inheritance, and workstation progression system** inspired by *Durango: Wild Lands* (2019), directly in my existing survival game.

**Do not stop at a design document.** Inspect the project, identify the current building, placement, crafting, inventory, durability, skill-tree, save/load, and multiplayer systems, then integrate the features into those systems. Avoid duplicate inventories, recipe engines, attribute systems, and world-placement logic.

The key philosophy: **buildings are crafted objects with individual levels and material-derived properties, not merely identical placeable decorations.** Two buildings of the same blueprint and level can have meaningfully different performance based on the individual materials used.

## 1. Construction workflow

Support this complete loop:

1. Unlock a construction blueprint in the Construction skill tree (and pay Skill Points when required).
2. Choose the blueprint from the construction UI.
3. Preview and position a construction site in the world, respecting its tile footprint, collisions, land ownership, and placement constraints.
4. Supply the **exact item instances** required by the blueprint, including individual logs, planks, stone, nails, leather, and specialized components.
5. Complete construction work using the correct tools, construction proficiency, and resources.
6. Finalize a persistent building with a computed level, inherited attributes, durability, owner, location, and usable functionality.

Small furnishings may be made as inventory items before placement; large structures may require a world-placed construction site. Make the distinction blueprint-driven.

Construction sites should persist partial resources and progress across save/load, and support cancel/refund rules configurable per structure. Prevent material duplication if two players contribute simultaneously.

## 2. Building level calculation

Distinguish **Construction category level**, **effective Building Ability**, **blueprint constraints**, and **finished building level**.

For standard blueprints, begin with this *reconstructed / simplified* model:

```python
average_material_level = floor(weighted_average(levels_of_eligible_materials))
recipe_bounded_level = clamp(
    average_material_level,
    blueprint.minimum_level,
    blueprint.maximum_level,
)
finished_building_level = min(recipe_bounded_level, builder.construction_level)
```

Implement explicit rules for cases in which a builder does not meet the blueprint minimum; do not silently produce an illegal level. Allow blueprint-specific material weights and exceptional formulas.

Illustrative examples, assuming a minimum below the result:

| Average eligible materials | Construction level | Blueprint max | Output level |
| ---: | ---: | ---: | ---: |
| 20 | 60 | 60 | 20 |
| 60 | 30 | 60 | 30 |
| 55 | 60 | 60 | 55 |
| 60 | 60 | 30 | 30 |

A high-level log alone does not override low Construction skill or blueprint limits. Reuse the existing crafting-level engine where practical instead of duplicating calculations.

## 3. Material-based building attributes

Each input material retains its instance ID, level, positive/negative/rare attributes, and processing history until consumed. Blueprint slots specify whether they contribute to building level, appearance, and/or inherited attributes.

Implement a data-driven **material property -> building effect** conversion table:

| Raw material property | Building effect |
| --- | --- |
| Firm | Building Attack increase, where applicable |
| Soft | Building Attack decrease, where applicable |
| Lightweight | Storage Space increase on eligible storage structures |
| Heavy | Storage Space decrease on eligible structures |
| Beautiful Pattern | Comfort increase on eligible housing/furniture |
| Messy Pattern | Comfort decrease |
| Strong Disinfectant | Antibiotic bonus on eligible structures |
| Weak Disinfectant | Antibiotic penalty |
| High Density | Durability bonus |
| Low Density | Durability penalty |

**Applicability matters**: not every property should affect every structure. An ordinary wall does not magically gain storage slots from Lightweight, and a storage box does not automatically provide house-wide comfort unless its definition explicitly permits it.

Support averaging ordinary attributes across designated primary materials (including missing attributes counting as zero), respecting existing crafting inheritance rules. Rare effects use separate, configurable compatibility/transfer rules. Keep inherited attribute levels and final calculated effects visible for inspection.

### Illustrative specialized structures

- **Storage box:** Lightweight Lv. 6 may grant extra spaces; High Density may boost durability.
- **Bed or furnishing:** Beautiful Pattern raises Comfort; disinfectant-related materials may contribute an Antibiotic effect where permitted.
- **Workbench:** Certain rare material properties may reduce task time or add a parallel crafting slot.

The modern Durango:0 reconstruction uses **+3 container spaces per Lightweight level**, **+2 durability per High Density level**, **5% shorter processing time** for a corresponding rare effect, and **+1 workstation delegation slot** for another. These are reference values, **not proven universal original 2019 server formulas**. Keep them configurable and label them as reconstruction-based.

## 4. Storage buildings and capacity

Integrate structures with the unique-item, non-stacking inventory system. Every storage object must have an independent container inventory and ownership/permission controls.

Possible reference: the community mastersheet records a **level-60 Large Leaf Box holding 160 spaces**. Do not impose this value on every box.

Final container capacity can depend on:

- Blueprint base capacity and level scaling, when defined.
- Inherited Storage Space bonuses/penalties.
- Explicit rare effects or upgrades.

```python
capacity = max(0, base_capacity_at_level + property_bonus + rare_effect_bonus)
```

A change in building state must not silently delete stored items. Packaging/moving buildings with contents requires safe, single-owner persistence or a validated restriction. Respect private, personal, shared, and clan permissions if those systems exist.

## 5. Comfort, Antibiotic, housing, and recovery

Implement these as **functional** housing effects, not cosmetic numbers:

- **Comfort:** improves fatigue recovery when a character uses qualifying resting furniture or occupies a qualifying shelter.
- **Antibiotic:** supports relevant health recovery/health-restorative effects while in the applicable environment.
- **Complexity:** optional housing crowding/over-furnishing penalty that prevents infinite furniture stacking from producing unrestricted bonuses.

Historical players described a house **Complexity** penalty related to furniture occupying a large fraction of its available tiles, sometimes reported around half the space. This is not an exact verified universal threshold. Make the rule and occupancy calculation configurable, and show the penalty in the UI.

Define clear, non-exploitable combination rules when multiple pieces of furniture overlap: radius, room ownership, active rest usage, max bonus, diminishing returns, and effect refresh. Never grant recovery just from possessing furniture in inventory.

The reconstruction's estimated Antibiotic health regeneration coefficient (**+0.0075 HP/second per effect level**) is not verified original data. Do not hardcode it as fact; select balanced rates consistent with the existing fatigue/health systems.

## 6. Workstation types, levels, and production quality

Support distinct workstation categories (examples: general workbench, drying rack, kitchen, kiln/smelter, leather-processing station, taming pen, and specialized crafting stations). A high-level station of the wrong type cannot satisfy an unrelated recipe.

Recipe compatibility validates:

1. Correct station type and available functionality.
2. Required station level.
3. Builder/crafter skill and learned recipe requirements.
4. Required tools and tool levels.
5. Available capacity, materials, and queued jobs.

Higher workstation levels can unlock high-tier processing/crafting and may increase concurrent job capacity for certain station types.

Reconstruction examples include:

| Station | Level | Concurrent jobs |
| --- | ---: | ---: |
| General Workbench | 20 | 2 |
| General Workbench | 40 | 3 |
| Large Drying Rack | 20 | 2 |
| Large Drying Rack | 40 | 3 |
| Kitchen | 50 | 3 |
| Kitchen | 60 | 4 |

Treat these as **reference examples tied to specific definitions**, not a universal scaling law.

Special rare material effects could yield **Shorter Duration** (processing/delegation time improvement) and **More Space** (extra workstation job slot). Their exact values must be configurable and their activation shown on the structure's details. Reuse existing crafting/processing job queues and preserve in-progress jobs during save/load.

## 7. Durability, damage, and repair

Structures have individual maximum durability, current durability, and any inherited durability buffs or penalties. Implement repair interactions and appropriate repair kits/material requirements.

- High Density can increase durability on eligible buildings.
- Low Density can reduce durability.
- Repair restores durability according to repair recipe, tool/skill, and structural constraints.
- Damaged/destroyed buildings must have predictable handling for attached inventories, furniture, and queued workstation jobs.

If buildings can take combat damage, integrate with the existing damage system, building ownership rules, and authorized destruction/raiding behavior. Do not invent PvP destruction rules if the current project does not support them.

## 8. Modular houses, footprints, and visual materials

Implement or extend tile-based modular construction:

- Floors, walls, doors, roofs, windows, fences, and furnishings.
- Grid/footprint placement preview with valid/invalid highlighting, rotation, snapping, collisions, and clear confirmation/cancellation.
- Building-site support for larger structures.
- Room/house grouping when required for comfort and complexity mechanics.
- Different appearances drawn from material type or designated appearance-contributing ingredient slots where supported.

Original Construction skill milestones provide useful inspiration:

| Construction skill level | Example floor unlocks |
| ---: | --- |
| 20 | Leaf and stalk floors |
| 35 | Wood and dirt floors |
| 50 | Wooden plank and stone floors |
| 60 | Shaped wood and patterned stone floors |

These need corresponding learned blueprint nodes/Skill Point costs, rather than becoming globally available just because the player's overall level rises.

## 9. Construction progression vs Building Ability

Keep two separate ideas:

- **Construction category level:** XP, progression cap, blueprint eligibility, skill-tree availability, and normal output-level limit.
- **Building Ability / Furniture Crafting Ability:** effective proficiency used to determine whether advanced construction or furniture work can be undertaken or reliably completed.

Ability can be modified by learned proficiency nodes, specialist clothing, architect tools, attributes, food buffs, and titles if those already exist.

Historically, players discussed combining architect equipment and buffs to reach very high effective Building/Furniture Crafting Ability. The exact bonus stack depends on game version. Make modifiers additive/multiplicative in a transparent centralized stat engine and prevent equip/unequip stacking exploits.

Award Construction XP only for meaningful validated work. Support cooperative building contributions if multiplayer exists; do not grant the same completion reward repeatedly.

## 10. Construction UI

Build an interface using the project's existing visual system, optionally borrowing Durango's charcoal/green panels and golden primary actions.

**Blueprint browser:** category, icon, required Construction level, learned-skill status, required SP, material list, tool/station needs, footprint, and expected functional purpose.

**Placement:** ghost preview, grid tiles, rotation, obstacle and territory feedback, confirm/cancel actions.

**Construction site:** supplied vs missing **specific materials**, their levels and bonuses, contributed material instances, work progress, contributors, expected level/effects, and completion requirements.

**Finished building inspector:** blueprint, level, current/max durability, inherited attribute levels, effective storage capacity, comfort/antibiotic bonuses, workstation level, queue capacity, permission state, and available use/repair/package actions.

**Workstation:** station level, compatible recipes, queued jobs, remaining time, added queue slots, and any time modifiers.

Show accurate previews using the same calculation functions as final construction. A material's rare perks should not vanish from the prediction or be fabricated on finished buildings.

## 11. Suggested static and runtime data

Keep definitions separate from building instances.

```python
building_blueprint = {
    "id": "large_leaf_box",
    "type": "storage",
    "minimum_level": 1,
    "maximum_level": 60,
    "required_skill_node": "large_storage",
    "required_building_ability": 0,
    "footprint": [2, 2],
    "material_slots": [
        {"role": "primary", "category": "wood", "quantity": 4,
         "counts_for_level": True, "counts_for_attributes": True},
        {"role": "binding", "category": "binding", "quantity": 2,
         "counts_for_level": True, "counts_for_attributes": False}
    ],
    "supported_building_effects": ["storage_space", "durability"],
}

building_instance = {
    "id": "building_0042",
    "blueprint_id": "large_leaf_box",
    "owner_id": "player_17",
    "level": 60,
    "inherited_attributes": [{"id": "lightweight", "level": 6}],
    "max_durability": 200,
    "current_durability": 200,
    "position": [10, 12],
    "rotation": 0,
    "container_id": "container_0042"
}
```

All IDs, levels, quantities, footprint dimensions, and durability numbers shown above are illustrative unless explicitly identified as historical references. Adapt this schema to the current language/engine.

## 12. Data-driven behavior and integration

Keep these configurable:

- Blueprint/recipe definitions and skill requirements.
- Level calculation and ingredient roles.
- Building attribute conversions and conflicts.
- Workstation level requirements and queue capacities.
- Special time/slot bonuses.
- Comfort and Antibiotic ranges/rates.
- House Complexity thresholds and penalties.
- Durability, damage, and repair rules.
- Placement and territory restrictions.

Reuse the existing material item-instance IDs, processing properties, inventory/escrow transfer system, fatigue/health recovery, construction skill tree, and market system. Buildings with unusual bonuses should be inspectable and tradeable/movable only under valid ownership and packaging rules.

For multiplayer, placement, material consumption, ownership, storage access, and construction outcomes must be server-authoritative, atomic/idempotent, and safe under simultaneous contributions.

## 13. Required tests

Test at minimum:

1. Locked and unlocked blueprints with Construction level + SP prerequisites.
2. Placement rejection for occupied/unauthorized grid tiles.
3. Construction-site progress and cancellation.
4. Consuming exact unique material instances (no duplication).
5. Output level capped by material average, skill, and blueprint.
6. Correct primary/secondary material inheritance.
7. Positive and negative building attributes.
8. Storage capacity changes from Lightweight/Heavy on eligible structures only.
9. Durable construction, deterioration, and repair.
10. Comfort/Fatigue recovery and Antibiotic effects only in valid contexts.
11. House Complexity and overlapping furniture handling.
12. Workstation level gates, queue slots, and rare duration bonuses.
13. Workbench crafting tasks across scene changes and reloads.
14. Modular floors/walls/roofs with materials and appearance.
15. Building/Furniture Crafting Ability modifiers and removal.
16. Container contents when structures are packed, relocated, damaged, or destroyed.
17. Save/load of site progress, completed buildings, queues, and permissions.
18. Multiplayer concurrent build contributions when supported.
19. Crafted-building previews matching actual output.
20. Existing inventory, crafting, taming-pen, and market regression tests.

## 14. Implementation order

Implement a verified vertical slice first:

**Gather leveled logs → inspect Beautiful Pattern/Lightweight → select exact logs → unlock box blueprint → place construction site → supply materials → build → inherit attributes → open storage with correct capacity → save/load without losing bonuses or contents.**

Then expand in stages:

1. Construction blueprints, placement, sites, level computation, and persistence.
2. Attribute inheritance and functional storage/durability effects.
3. Workstation levels and parallel crafting jobs.
4. Housing furniture, Comfort/Antibiotic recovery, and Complexity.
5. Modular houses, appearance inheritance, repair, multiplayer safeguards, and UI polish.

## Appendix — finished-structure reference screenshots (owner, 2026-10-27)

Pasted screenshot of the original interaction radial over a finished structure (a Makeshift Tent Lv. 2 standing in the wild; not on disk). Reading is the orchestrator's:
- **Hex actions on the object:** Remove (red), Package, Rest, View History, Designate as Waypoint; the label rides beside the selected hex.
- **Object panel:** name + level (Makeshift Tent Lv. 2), a 3/3 use counter with a clock icon, Capacity 1/1 (shelter resting slots), a Shelter family tag, and an **Authorizations** row noting "Subject to Domain Permissions" — per-object ACLs defer to the Domain layer (spec 29), which is exactly the division §4 requests.
- **Rest on a shelter** is where §5's comfort/fatigue recovery is spent in the world; Package matches §4's packaging rule. View History and waypoint designation belong with the map specs (15, 25).
- The radial follows 25's interaction-camera rule: tapping the structure pans to it and locks the radial on it.

## 15. Historical fidelity and sources

Recreate these *design relationships*: resources have individual properties; Construction level and Building Ability are distinct; finished building level is constrained by materials and progression; building properties create functional bonuses; workstation type/level gates recipes; higher-end structures require advanced skill-tree unlocks.

**Historical caveat:** Some property mappings, skill/blueprint definitions, and workbook performance tables are drawn from extracted original data, while exact multipliers, inheritance details, aesthetics, and recovery rates sometimes reflect community reconstructions or adjustments. State which values are verified, reconstruction-based, or newly balanced. Do not claim approximate figures are official Nexon formulas.

Useful reference material:

- https://kghj76138.github.io/durango-homecoming-guide/en/materials.html
- https://www.scribd.com/document/501357601/Durango-Wildlands-Mastersheet

## 16. Deliverables

Implement the working system and report:

- Files created/modified and important architecture decisions.
- Blueprint and Construction skill integration.
- Unique material usage, output level, and attribute inheritance.
- Storage, comfort, antibiotic, durability, workstation, and modular-building mechanics completed.
- UI screens/actions actually working.
- Configurable balancing values and which are historical versus estimated.
- Tests run, results, known limitations, and any incomplete features.

**Do not implement only menus or unrelated decorative buffs. Building levels and inherited material traits must have observable, testable gameplay consequences.**
