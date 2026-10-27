<!-- Owner's file: 15_building_construction_and_crafting_stations.md (2026-10-21). Filed as 30 because 15 is the island map scale. -->

# GUIDE 15 — Durango: Wild Lands Building Construction and Crafting Stations

## Mission for Claude

Implement the **actual Craft/Build production workflow** from Durango: Wild Lands in my existing dinosaur survival game. This is a **standalone implementation guide** for making construction components, placing unfinished construction sites, depositing exact material instances, performing construction work, completing structures, and using functioning crafting/processing stations.

This is **not** a land-claiming guide. The Domain system controls where and by whom a structure may be placed; this guide controls **how a structure is manufactured and becomes usable**. It complements the existing construction-quality, material-processing, inventory, progression, and Domain guides. Inspect all those systems and the project architecture before changing code. Reuse them; do not build parallel inventories, recipe engines, skill systems, or building registries.

**Goal:** `Gather logs/reeds → make planks and straps → learn Basic Workbench blueprint → place construction site in a Domain → supply the exact ingredients → do construction work → finish a leveled workbench → open its station UI → process materials in a real queued job → retrieve output`.

## Historical references and confidence

- A contemporary step-by-step tutorial describes **Basic Workbench**: Building/Construction skill level 20, learn the Basic Workbench skill for **3 SP**, select `Craft/Build → Storage Unit/Workbench → Basic Workbench`, supply **2 Plank Shape + 2 Pillar Shape + 6 Strap**, place in one's Domain, finish building, then use it. https://durangoguides.blogspot.com/2017/09/how-to-make-basic-workbench-in-durango.html
- A community materials mastersheet lists workstations and recipes including Basic, Journeyman, and Expert Workbench, Drying Rack, Loom, Kiln, Oven, Stove, Kitchen. https://www.scribd.com/document/501357601/Durango-Wildlands-Mastersheet
- Current Durango:0 reference lists blueprints, component slots, tool requirements, capability checks and timings. Its data mixes recovered definitions and **estimated or modified restoration behavior**: https://kghj76138.github.io/durango-homecoming-guide/en/building.html
- Station recipe eligibility uses **station tags/types plus minimum station levels**, not merely workstation appearance. The mapping of some blueprints to station tags is restoration-inferred: https://kghj76138.github.io/durango-homecoming-guide/en/craft.html
- Player reports confirm that ingredient levels and the appropriate crafting category cap determine resulting levels: https://www.reddit.com/r/DurangoWildLands/comments/bncwdn

**Do not misrepresent estimated reconstruction formulas, precise timers, station throughput or effect multipliers as verified original Nexon rules.** Keep uncertainty documented and make values configurable.

---

## 1. Distinguish four related production concepts

1. **Building components:** tangible crafted resources such as logs shaped into pillars, planks, trimmed planks, straps, rope, nails, glue, masonry, and metal accessories. These are **individual item instances**, with levels and attributes, not generic quantity counters.
2. **Placeable building blueprints:** definitions for a Basic Workbench, box, wall, drying rack, kiln, house piece, taming pen, etc. They specify ingredient *slots/tags*, footprint, unlock, ability, work, restrictions, outputs, and function.
3. **Construction sites:** persistent unfinished world entities occupying an approved placement footprint and accepting exact deposited ingredients plus work contribution.
4. **Completed structures:** world entities that have item level, material-derived qualities, durability, owner/permissions, and optionally a functional workstation inventory/job queue.

Crafting a plank is not the same as placing a plank floor. Manufacturing components, placing a construction site, completing construction, and processing items at the completed station must have distinct operations and state.

## 2. Craft/Build UI and discovery

Provide a `Craft/Build` entry from the gameplay interface with categories analogous to the original:

- Construction Parts: Planks, Pillars, Frames, Floor/Wall/Roof Sections, and related components
- Storage Unit / Workbench: Boxes, Workbenches, Drying Racks, Kilns, Looms, Kitchens and other production stations
- Shelters / Buildings: Houses, walls, floors, doors, roofs, foundations
- Installation / Decoration: Furniture, lamps, fences, functional room installations
- Farming / Animal Facilities where relevant: Fields, pens, feeders, taming structures

A blueprint details panel must show **required Construction skill / skill-node unlock, Furniture Crafting or Building Ability, workstation/tool if applicable, footprint, permitted land, ingredients with acceptable tags and minimum levels, construction workload, expected result level, expected quality bonuses, and whether the site is currently placeable**.

Use authentic compact, dark olive/charcoal, gold-highlighted Durango-inspired UI consistent with existing inventory and construction interfaces. For all interactive elements, use real data.

## 3. Construction progression and recipe gating

- Character level and **Construction category level** are separate. Construction skill level cannot exceed character level; overall character level caps at 60 if that existing rule is implemented.
- A high Construction level does not automatically learn every blueprint. Check **learned skill nodes and prerequisites** in the shared SP skill tree.
- Some blueprint families depend on **Furniture Crafting Ability**, others **Building Ability**. Treat them as distinct calculated proficiency values with gear, tools, traits, food, and skill effects.
- Construction XP should come from relevant completed component crafting and construction work, with exploit protection; never award XP each time a user reopens a site or cancels it.
- Respect recipe minimum and maximum output levels and equipped tool restrictions.
- Show precise unmet prerequisites instead of only disabling the button.

## 4. Ingredient slots are tags, not mere item names

Historical Basic Workbench recipe:

| Ingredient slot | Quantity | Examples / interpretation |
|---|---:|---|
| Plank Shape | 2 | Plank-compatible wood/bone pieces satisfying level/tag requirements |
| Pillar Shape | 2 | Log or processed pillar-compatible pieces satisfying requirements |
| Strap | 6 | Suitable reed/stalk/root-based strap materials |

The original tutorial says to gather logs and reeds/stalks, craft planks where required, and use the relevant work tools. An example recipe in the restoration lists level-10 ingredient requirements. Treat the exact recipe definition as configurable and use item **tags** and minimum level requirements to identify eligible physical ingredients.

Each recipe ingredient slot should store:

```
slot_id, quantity, accepted_material_tags, min_level,
role (main / supporting), whether_level_contributing,
allowed_substitutions, consumed_on_completion
```

Players choose *specific* item instances when it affects level, attributes, processing opportunities, or special effects. Do not consume the first matching rare log automatically. Support previewing chosen components and optional 'protect rare items'.

## 5. Crafting the construction components first

Create the actual prerequisite component chain. Illustrative examples:

- Raw Log → Pillar Shape or Stick Shape
- Raw Log → Plank Shape (through unlocked Construction Part recipe, appropriate workbench/tool)
- Stalk / Reed / Root → Strap or Rope
- Ore → Refined Metal → Nail or Metal Accessories (using existing Processing/metallurgy)
- Animal hide → Leather Strap (via Processing)
- Processed materials → Trimmed Planks / Processed Planks as advanced inputs

**Use real material-instance levels** and inherited traits from the existing item system. These operations consume the actual ingredient IDs, produce new unique items as applicable, and award progression appropriately. Make station requirements explicit; avoid a circular dependency where making the first workbench requires that same workbench unless there is a valid starter alternative.

## 6. Placement and foundation validation

From the blueprint, `Build/Place` opens a ghost preview positioned in the world:

- Display exact occupied footprint and rotation; show ground/grid cells.
- Green outline/tiles for valid; red for invalid.
- Check terrain slope, collisions, water, obstructions, existing structures, restricted biomes, and world bounds.
- Ask the established **Domain/ownership subsystem** whether the player has rights to place at those cells. Do not implement a second domain claimant.
- Allow confirm/cancel/reposition before creating the site.
- On confirmation create one persistent `ConstructionSite` with a unique ID, owner, blueprint ID, transform, reserved footprint, empty ingredient slots and progress, initially **not a functioning station**.

Placement should never automatically grant all a building's benefits or workstation functionality.

## 7. Materials contribution and construction site UI

An unfinished structure is interactable, showing:

- Blueprint name, planned level and owner
- Progress indicator: materials supplied vs required and work completed vs required
- Each recipe slot: quantity needed, accepted tags, minimum level, actual deposited instances and their attributes
- Current calculated output level and potential inherited quality (updated as materials are deposited)
- Required build tools, Construction level/ability and work-energy/fatigue costs
- `Deposit`, `Withdraw` (if authorized), `Work/Build`, `Cancel/Remove` (if authorized)

Contributions transfer physical items from inventories into **construction-site escrow**, not clone items. If multiple clan members contribute, record contribution ownership or follow explicit project settlement permissions and return rules. Players should be able to revisit partially completed projects. Persistent save/load must recover sites without material loss.

## 8. Building work and completion

Once materials and prerequisites are sufficient:

- Start an actual work action, not instant placement for every building.
- Validate player location, tool access/durability, required ability, stamina/energy/fatigue and build permission.
- Animate work, progress and tool use; advance work in a way consistent with the existing action/crafting framework.
- Apply Construction experience on legitimate progress/completion only, bounded against spam.
- Handle interruptions/disconnects and cooperative construction deterministically.
- On completion **atomically**: commit component consumption, determine built structure level and inherited attributes, remove construction site, instantiate completed structure, set correct owner/permissions, and persist.
- Failed/canceled construction must follow configured material recovery policies; never silently delete unique rare components.

State machine suggestion: `preview → site_active → materials_ready → in_progress → completed`, with separate `canceled/removed` and interruption states. Illegal transitions must fail without duplication.

## 9. Built structure level versus craft ability versus quality

Treat as **three independent axes**:

1. **Structure level** affects its capability and eligibility for recipes requiring a minimum station level.
2. **Building/Furniture Crafting Ability** is a separate proficiency check controlling whether building a particular structure succeeds or can begin.
3. **Material-derived attributes / quality** affect concrete functions such as durability, storage capacity, comfort, antibiotic effects, workstation slots and production speed.

Initial simplified level formula for ordinary structures, pending recipe-specific rules:

```
avg_level = floor(weighted_average(levels of level-contributing exact ingredients))
structure_level = min(clamp(avg_level, blueprint_min, blueprint_max), construction_category_level)
```

Handle cases where input materials do not satisfy blueprint minimums as **invalid**, rather than silently upgrading them. Let recipe-specific exceptions override the formula. The precise historical server algorithm is not fully recovered. A level-60 hammer must not magically elevate a structure made of level-10 wood.

### Building attribute mappings

Use inherited material property mappings *only on compatible buildings*:

| Raw property | Possible structure effect |
|---|---|
| Lightweight / Heavy | More / fewer storage spaces |
| High Density / Low Density | More / less structure durability |
| Beautiful Pattern / Messy Pattern | More / less Comfort |
| Strong / Weak Disinfectant | More / less Antibiotic effect |
| Firm / Soft | Building Attack increase / decrease where meaningful |
| Rare Splits Easily | Shorter Duration or More Space where compatible |

The conversion coefficients are data-driven, not assumed exact. Normal property inheritance uses main-material roles and recipe aggregation; rare effects have separate compatibility and transfer rules. Do not blindly transfer every attribute from every secondary ingredient.

## 10. Actual crafting station functionality

A finished station must expose specific **capability tags and a station level**. Examples:

| Station | Core function |
|---|---|
| Makeshift Workbench | Starter recipes and limited handcrafting |
| Basic / Journeyman / Expert Workbench | General craft and Processing recipes requiring Workbench tag and minimum level |
| Drying Rack | Dried leather, preserved/dried materials and other Drying Rack recipes |
| Kiln / Furnace | Charcoal, refining, advanced metallurgy according to recipe definition |
| Loom | Textile, thread and fabric production |
| Bonfire / Cooking Fire | Cooking recipes requiring an open fire |
| Oven / Stove / Kitchen | Specialized cooking and preparation, potentially multiple compatible tags |
| Taming Pen | Taming queue, not a generic crafting workbench |

Use data-driven tags: a recipe requiring `Workbench >=20` must reject a level-12 Workbench, but a level-40 Workbench can qualify. A level-60 Drying Rack cannot substitute for a level-20 Kiln unless explicitly tagged for that operation. Tags must come from station definitions; do not implement logic that matches only display names.

A surviving historic guide describes public camp workbenches as suitable for certain immediate recipes but not a secure place for unattended processing; shared access creates a risk of other players taking output. Respect ownership and permissions.

## 11. Station job queue / delegated production

Certain processing recipes run over time at a workstation. Build a **real job queue**:

- Open station UI and browse only eligible recipes or show actionable reasons for ineligibility.
- Select exact input item instances, supporting materials and desired method.
- Preview output level/properties, workstation requirement, tool/skill requirement, duration, fatigue/energy cost, success chance and possible Flawless outcome.
- Reserve/consume exact inputs once on accepted job start under existing crafting semantics.
- Add a persistent job record: `job_id`, station ID, recipe ID, actor ID, reserved input IDs, start timestamp, expected end timestamp, status and authoritative outcome.
- Different station types/levels may support different concurrency and slots. `More Space` rare effect may add a slot; `Shorter Duration` may shorten eligible jobs, where supported.
- Job timers should continue across saves/restarts and offline play if backed by authoritative world time.
- Completed output resides in the station's output/claim storage until an authorized player collects it. Collection must be exactly once, and inventory-full conditions must never delete items.
- Station destruction, unclaiming, relocation or packaging with active jobs must have explicit policies.

Do not confuse **a construction-site work timer** with **a completed station's production-job timer**.

## 12. Station upgrades and progression

A historical progression chain uses Basic, Journeyman and Expert Workbenches. This can be modeled as separate blueprints or upgrades if the current game supports upgrades, but do not assume the original game had an in-place `Upgrade` button for every station.

Approximate historical/recorded examples (blueprint definitions vary by version):

| Station | Indicative materials |
|---|---|
| Basic Workbench | 2 Plank Shape, 2 Pillar Shape, 6 Strap |
| Journeyman Workbench | 3 Trimmed Planks, 2 Trimmed Pillars, 2 Metal Nails, 6 Rope |
| Expert Workbench | 3 Processed Planks, 3 Trimmed Pillars, 6 Metal Nails, 6 Glue |
| Large Drying Rack | 4 Trimmed Wood Pillars, 4 Glue, 3 Metal Nails |
| Large Loom | 3 Trimmed Wood Pillars, 2 Trimmed Planks, 5 Rope, 2 Metal Nails |

These are grounded examples from the historical mastersheet/restoration; exact material-level thresholds and time values are blueprint-specific and may be modified by reconstructions. Do not force all these into the initial implementation if the project lacks prerequisite materials.

Higher-level stations can unlock advanced recipes; some have more concurrent delegated job slots. Different grades/types must have meaningful, verifiable functions and not just visual changes. Higher station levels do **not** override a player's recipe/category-level caps.

## 13. Houses, modular parts and furniture

Use the same construction-site foundation for modular floors, walls, ceilings, roofs, doors, furniture and storage, with type-specific rules:

- Walls and floors use a snap grid and adjacency/structural compatibility where established.
- Component material choice affects appearance where compatible.
- Housing footprints and building complexity interact with comfort rules if already implemented.
- Furniture can provide Comfort, Antibiotic or other valid area effects.
- Storage buildings instantiate a real independent unique-item inventory on completion.
- Taming pens connect to the companion/taming service; cooking stations to the cooking system; kilns and racks to Processing.
- Decay/repair behavior depends on island type and Domain rules. Private Tamed Island ordinary decay and Civilized Island deterioration must use the established territory policies.

## 14. Data model / code architecture

Prefer data-driven blueprint resources and unified item operations. Example **conceptual**, not required schema:

```yaml
blueprint_id: basic_workbench
category: storage_workbench
required_category: construction
required_category_level: 20
required_skill_node: basic_workbench
skill_point_cost_reference: 3
required_ability_type: furniture_crafting
footprint: [2, 2]  # Illustrative, not verified original footprint
ingredient_slots:
  - {id: planks, accepted_tags: [plank_shape], quantity: 2, min_level: 10, role: primary}
  - {id: pillars, accepted_tags: [pillar_shape], quantity: 2, min_level: 10, role: primary}
  - {id: straps, accepted_tags: [strap], quantity: 6, min_level: 10, role: support}
station:
  tags: [workbench]
  level_from_construction_result: true
  supports_queued_jobs: true
```

Keep `BlueprintDefinition`, `ConstructionSiteInstance`, `CompletedStructureInstance`, `StationDefinition`, `StationJob`, and `ItemInstance` separate. Every persistent item has exactly one owner/location: player bag, site escrow, station input, station output, container, dinosaur cargo, world drop, or market escrow.

Enforce authority and atomicity when multiple players build together or collect output. Never trust UI values for materials, level, property bonuses, timer completion or permissions.

## 15. User interface flows

**A. New Basic Workbench**
1. Open Skills → Construction → unlock Basic Workbench if eligible.
2. Open Craft/Build → Storage Unit/Workbench → Basic Workbench.
3. Inspect prerequisites and ingredient slots.
4. Tap Build → preview/rotate/snap footprint → confirm in owned Domain.
5. Tap the unfinished site → deposit exact planks/pillars/straps.
6. Begin work, watch completion progress → finished Workbench appears.
7. Tap finished Workbench → view its actual level, eligible recipes, open jobs, output and item-property bonuses.

**B. Process a material**
1. Open a level-qualified Workbench.
2. Select a processing recipe, e.g. Trimmed Material requiring the station's tag/level.
3. Choose exact material instance, compatible tool and recipe ingredients.
4. Submit a job → see countdown and queue position.
5. Collect the actual transformed output after completion.

**C. Failure/blocked states**
- Cannot place outside claim or on obstructed terrain.
- Cannot deposit wrong material tag or insufficient material level.
- Cannot start job without unlocked recipe, needed tool, sufficient station level or station queue capacity.
- Cannot use construction site as a workstation before completion.
- Cannot cancel, salvage or withdraw other people's contributions without relevant permissions.

## 16. Implementation phases

**Phase 1 — Component chain:** Tag-based ingredient slots, Construction Part recipes, unique component items, level preview.

**Phase 2 — Site pipeline:** Blueprint selection, placement preview, Domain validation, site entity, deposited materials, work, completion, persistence.

**Phase 3 — Functional station:** Real Workbench tag/level, station UI, recipe validation, one live processing job, exact output claim.

**Phase 4 — Station variety:** Drying Rack, Kiln, Loom, Oven/Kitchen, Taming Pen integration; stations with different tags/capacity.

**Phase 5 — Quality and advanced features:** Material inheritance, Comfort/Storage/Durability effects, rare workstation perks, advanced workbench blueprints, cooperative construction, repair and decay, packaging/moving policies.

Do not implement dozens of decorative nonfunctioning blueprints before finishing the complete Basic Workbench vertical slice.

## 17. Required tests and verification

Verify at minimum:

1. Component recipes accept valid material tags, reject invalid ones.
2. Specific high/low-level logs yield distinct components and sensible resulting preview levels.
3. Rare component item IDs/properties remain intact while stored and deposited.
4. A player without the learned Basic Workbench skill cannot place it.
5. Domain permissions, collision and rotation rules reject invalid placement.
6. Placement creates a **site**, not an instant finished Workbench.
7. Different contributors can deposit components without item duplication or theft.
8. Partially completed sites persist after save/load.
9. Completing a site removes escrowed inputs exactly once and creates exactly one structure.
10. Structure level respects ingredient level, Construction cap and blueprint max.
11. Correct primary-material attributes transfer; secondary inputs do not indiscriminately transfer.
12. Completed stations enforce tag/type and minimum level per recipe.
13. Workstation capacity and job queue limits work; jobs persist through restarts.
14. Completed products are collectible only once and preserve item-instance traits.
15. Player with a high-level Workbench but insufficient Cooking/Processing skill cannot bypass skill requirements.
16. Canceling sites, destroying stations and disconnecting during jobs do not lose or dupe items.
17. Inventory-full output claim provides a safe fallback.
18. Construction XP cannot be farmed through cancel/restart loops.
19. Storage capacity/Comfort/Antibiotic/Durability bonuses change actual game systems, not just UI labels.
20. Screenshot and playtest of the full original-style `Craft/Build` construction flow.

## 18. Final acceptance test

**Playable sequence:**

`Gather ≥2 logs + reeds/stalks → craft 2 Plank Shape, obtain 2 Pillar Shape and 6 Strap → unlock Basic Workbench → position it within a valid claimed Domain → create site → deposit each exact item → perform build work → finish a level-calculated Workbench → interact → run an eligible Processing recipe → collect a genuine processed item → save/reload and verify structure + processed item + all properties persist.`

If a prerequisite station/component is unavailable in the project, implement the smallest legitimate starter chain needed for this sequence; don't cheat by granting a fully built Workbench.

## 19. Deliverables for Claude

After working directly in the repository, report:

- Existing architecture inspected and which systems were reused
- Files changed, created or migrated
- Component/blueprint/station schema and content added
- Exact Build/Place/Contribute/Work/Complete/Use flows connected to UI
- Real recipe tag and level validation
- How station jobs, output, inventory, ownership and quality function
- Tests run and results, including a playable vertical slice
- Historic rules versus estimates/new choices
- Known limitations and next logical implementation stages

**Do not stop at mockups or pseudocode. Build, connect and test a functioning construction and crafting-station loop in my existing game.**
