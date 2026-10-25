# 08 | Blueprints, worksites, modular houses, constructed materials and room ambience

**Status: 2026-10-25 building-system reference incorporated as an OWNER-SUPPLIED DURANGO INSPIRATION, NOT a set of independently verified historical claims.** Everything marked **CONFIRMED** below comes from existing Deadfront owner decisions. New footprint sizes, modular room/appearance/ambience formulas, station production chains, building-durability behavior and example recipes are **DESIGN PROPOSALS** requiring owner approval/playtesting; **not coded** merely by writing this document.

## 0. North star and boundaries

**Player promise:** A high-quality settlement is a visible expression of exploration, mining/lumbering, dinosaur hunting, skilled processing, skilled builders, house planning, furniture, and a growing human/dinosaur tribe. A house is **not individually placed Minecraft blocks**. The player designs a small number of **grid-aligned room modules**, invests **processed construction parts**, and adds functional furnishing. A village with well-built rooms should operate noticeably better than a cluster of naked crafting stations.

**CONFIRMED Deadfront decisions that outrank any reference-game differences:**

1. **One Crafting menu** contains structure blueprint recipes. The **BUILD** mode is solely for spatial placement, movement, orientation and later connected-room layout, **not a competing building recipe catalog**. Blueprint must be crafted/unlocked before worksite placement. [Systems vision](../design/2026-10-25-systems-vision-and-open-decisions.md#5-unified-crafting---blueprint---construction-site-major-workflow-change), [decision CRAFT-01](decisions.md).
2. Every player has an **unraidable, PvE/PvP-attack-proof private home island**. Remote player-owned **PvE** settlements may be attacked by dinosaurs; optional late PvPvE frontier outposts may be raided by other players according to frontier rules. A Durango Domain does **not** override this separate Deadfront safe-home rule.
3. A **larger private island is PURCHASED as a full replacement**, not expanded by placing more land beside the existing home. After preview/confirmation, the old home is automatically dismantled and **100% of invested building materials** enter the dedicated salvage-only recovery vault; humans, dinos and ordinary inventory migrate separately. [Home migration](03-private-islands-and-upgrade-migration.md).
4. Materials come from gathering, processing, and hunting. **Traits are signed and functional** and can be fused from two lots; their contribution to buildings comes from **deposited component lots, not the cheap blueprint paper**. [05 Material Traits](05-material-level-traits-and-loot.md).
5. Persistent human workers can haul/build with their own skills, tools, energy and endurance. Building skill controls **who can initiate**, not who may deliver resources. Workers stop repetitive work-tool use at **1 durability**. [Tribe/Labor](../design/tribe-lineage-domain-and-labor.md).
6. **Food continues spoiling at home and in containers** despite physical safety, unless built storage provides a real preservation multiplier. [07 Cooking/Spoilage](07-crafting-processing-and-food.md).

## 1. Existing engine and content versus desired construction

**Verified currently present:**
- `BuildGrid` implements a **1-meter tile grid**, coordinate mapping, occupancy/reservation, rotated rectangular footprints, claims, slope/water and placement checks, and transforms.
- `BuildPlacer` shows a **translucent grid-aligned ghost, valid/invalid feedback, rotation, move/layout mode** and can spawn a finished `PlacedBuilding`/`CraftStation` by consuming an already-crafted **building kit** or (for some older simple items) raw resources directly at placement.
- `PlacedBuilding` stores position, cell, rotation, kind, and current persistence/durability-like use state for shelters; save/load handles existing placed buildings.
- `game/data/props_manifest.json` has footprints for `tent 3×3`, `log_shelter 4×4`, `taming_pen 4×4`, `fence 2×1`, `workbench 2×1`, and **existing individual** `floor`, `wall`, `wall_doorway`, `roof` 1×1 props, plus craft stations/furniture. Models are mostly separate Kenney-type props and **do not yet implement a connected house system**.
- `game/data/recipes.json` has a number of direct `*_kit` recipes (campfire, workbench, canvas tent, log shelter, basket, drying rack, smoker, crock pot, etc.). `game/data/items.json` also has `wood_log`, `split_wood`, `plank`, `pillar`, and lashings.

**Not currently present as a coherent system:**
- Unlock/craft **lightweight blueprint item → unfinished persistent worksite → deposit specified construction components → perform labor → activate finished structure**. Direct-to-finished kit placement is the existing behavior and must be **migrated**, not passed off as a completed implementation.
- Choose a **configurable modular house footprint** per blueprint, connected multiroom structural grouping, perimeter-wall/roof generation by room size, room-local boundary and functional classification/ambience.
- Full manufacturing chain for `support_beam, reinforced_pillar, wall_panel, roof_panel, flooring_panel, framed_doorway, construction_fasteners` and their material-level/trait contribution.
- Full **installed material style → visible wall/roof/floor/pillar appearance** and reconstruction without duplication; structural durability, repairs and remote raid targeting integration; nuanced room furniture bonus. Some partial props/visuals exist, but not this complete behavior.
- Builder skill initiation permissions separate from unskilled material donation; resource reservations, worker construction jobs, completion conditions, cancel/move/repair and atomic save/migration semantics.

**Do not delete existing building kits before implementing safe migration:** older saves and inventories may reference them. Consider conversion to legacy blueprint items with an explicit salvage/credit policy, or keep a subset of instant-deploy field objects (e.g., temporary campfire/bedroll) while making houses, permanent crafting facilities and significant storage use true worksites.

## 2. The complete player loop and state machine

1. **Learn blueprint** from Construction skill, research/progression or exploration. Show recipe, size options, required builder skill, expected resource groups, work time, intended room use and furniture possibilities in one **Crafting > Structures** section.
2. **Craft blueprint ITEM** cheaply (e.g., prepared writing surface/cord/wood, no full house materials); the paper/item unlock is not the house itself. Exact blueprint crafting consumption/reuse rule remains OPEN.
3. **Choose size** from permitted family choices, normally `2×2`, `3×3`, `4×4`. The chosen size fixes footprint and scales material quantities, required labor and room capacity **before** placing. Construction skill gates the size/family **at initiation**. Example: early 2×2 basic shelter; mid 3×3 cabin; advanced 4×4 great room. **All numbers/example levels proposed**.
4. **Place the blueprint ghost** in present 1m BuildGrid; rotate, preview required cells, blocked tiles, slope, island permissions, rights, adjacent doors and connectors. Confirmation atomically consumes/reserves the blueprint and spawns a **persistent unfinished worksite** occupying the chosen cells, not a completed building.
5. **Deposit components** by selecting exact lots from bag or storage or assigning hauling workers. Show required and delivered for `foundation/floor`, `support_frame`, `wall`, `roof`, `entry/doors`, `joinery`, and optional furnishings. Separate **component fabrication** (Workbench/Carpentry/Forge/Processing) from **site construction labor**.
6. **Build with human labor:** owner skilled builder can personally initiate/execute; trained workers and allies assist according to allowed territory and skill. The site processes stages (foundation → frame → enclosure → completion) once relevant materials and work are provided. Until completed, no free station production, indoor rest buff, storage capacity or occupancy bonus.
7. **Finish, inspect and furnish:** house/room appearance reflects installed components' surface material mix; room provides basic shelter/occupancy/sleep rules and may gain valid local bonuses from properly located furniture/functional stations.
8. **Extend via ADJACENT MODULE:** attach an independently built room to a compatible door edge with support/collision/path validation. An existing completed 2×2 cannot silently inflate to 4×4; build another module or dismantle/rebuild. Preserve rooms as independent modules in a shared complex.
9. **Maintain, move, repair, demolish or migrate:** ownership, damaged/perfect condition, recovered material lots, local ambience, occupancy and worksite progress persist across saves and island replacement.

**Explicit state machine:** `known_blueprint` (recipe unlock) → `blueprint_item` → `placing_preview` (nonpersistent) → `worksite_reserved` → `foundation` → `framing` → `enclosure` → `completed` → `damaged/repairing` or `dismantled`. May add `paused: insufficient resources / builder absent / insufficient power`. A placement failure must consume **nothing**; canceled worksite must follow an explicit refund transaction; never occupy free cells twice or turn a partial site into a free finished house.

## 3. Grid, floorplan size, linking and validation

### 3.1 Modular size matrix (proposed)

| Room module | Grid cells | Simple intended role | Unlock progression | Building quantities |
|---|---:|---|---|---|
| 2×2 | 4 | bedroom, kitchen, small workroom | Starter Construction | 4 floor tiles, 8 perimeter edge segments, 4 corner supports (if design calls for them) |
| 3×3 | 9 | larger bedroom, kitchen, workshop | Intermediate Construction | 9 floor tiles, 12 perimeter edge segments, 4 corners |
| 4×4 | 16 | communal room, barracks, large workshop | Advanced Construction | 16 floor tiles, 16 perimeter edges, 4 corners |
| Connected group | Sum of room tiles, minus disallowed overlap | Joined household with independently classified functional rooms | Doorway/section connection knowledge | Each module has own floor/wall/roof allocations; valid joined shared-edge wall handling |

**Quantities are grid-geometry identities:** rectangular `width × height` floor tiles and `2(width+height)` perimeter edge segments, before deducting **door openings** or counting shared wall connectors. The *crafting item counts* required for a `floor_panel`, `wall_panel`, `roof_panel` can be bundled (e.g., 1 panel covers multiple edge/tile units), so don't force 16 separate taps to construct a 4×4.

**Proposed guardrails:**
- Existing Godot BuildGrid 1m footprint grid remains spatial source; modules are a **single placeable building/worksite** with authored perimeter mesh assembled from data. No forced manual placement of every wall/pillar.
- Placement allows 0°,90°,180°,270° and keeps the intended rotated footprint. Validity covers claimed terrain, slope, water, obstruction, tree/rock, island zone, reserved/unbuilt footprints, shoreline and access to doors/paths.
- Room connectors are authored **edge sockets**; two rooms join if their door edges align along grid edges and walkable floor elevations match within tolerance. An attached room may use a framed door, open/frameless passage or shared boundary. Avoid arbitrary adjacency triggering an unintended room merge or buff leak.
- A finished module retains its `room_id` and module-level `building_id`; `household_group_id` only links connected pieces. Treat **separate rooms as separately evaluated ambience/temperature/work stations** even though the player sees one building complex.
- Grid size is not the literal pixel size of every prop/real-world comfortable room. Character, worker and mount collision/pathing needs actual navmesh clearance. Huge dinosaur saddles/bodies may be unable to enter 2×2 doorways, consistent with physical creature scale.
- Preview surfaces optional floor/wall/roof style, door openings and material estimates. Construction cannot spawn an inaccessible no-exit room, seal a worker inside or overlap protected public routes. Exit/path validity checks are important for worker AI and raids.

### 3.2 Structural stages and material budget

Recommended deterministic count concept per room with grid footprint `w × h`:

```text
floor_cells = w * h
perimeter_edges = 2 * (w + h)
door_edges = explicit openings on perimeter
closed_wall_edges = perimeter_edges - door_edges - valid_shared_open_edges
roof_cells = floor_cells        # for simple enclosed rectangular shelter
frame_supports = 4 + internal_supports_if_w/h_requires
foundation_units = floor_cells * terrain_foundation_factor
work_units = Σ(component_units_i × per_component_labor_i) + site_setup_labor
```

These are transparent **quantity drivers**, not an approved final recipe. For larger structures, construction should scale more than nominal blueprint paper but may receive legitimate efficient interior/post-sharing savings. **No double spending a shared wall**: a boundary owned/paid for by one room can be removed/replaced as a legitimate doorway conversion and the saved materials accounted for in an audit. Support roof/upper mass without full structural-engineering sandbox physics; simple validated bracing and local strength stat suffice.

## 4. Manufacture components BEFORE installing them

**Owner rule (already confirmed for high-level gear):** evolved construction must use processed components, not raw wood logs and stones dumped into final building creation. Construction and weapons share the same economic logic.

| Component family | Example base material chain | Processed part (new unless existing marked) | Functional installation |
|---|---|---|---|
| **Wood pillars** | `wood_log → split_wood → plank` + treatment/rope | `support_pillar` / `reinforced_pillar` **[ADD]**; existing `pillar` item currently defined | Vertical frames, load-bearing edges |
| **Beams** | `plank → treated_plank` + `carved_bone_rib → reinforced_bone_block` + joinery | `support_beam`, `reinforced_beam` **[ADD]** | Wall/roof support, structural HP |
| **Floor modules** | Planks, stone blocks, treated boards, fitted scutes | `wood_floor_panel`, `stone_floor_panel` **[ADD]** | Visible walking surface, weather/durability/room ambience |
| **Wall modules** | Timber frame + plank, hide and fiber infill, bone/scute reinforcements | `wood_wall_panel`, `hide_wall_panel`, `stone_wall_panel` **[ADD]** | Shelter, insulation, raidable barriers, cosmetic wall design |
| **Roof panels** | Treated timber + fiber/thatch, hide tarp, ceramics/metal at high tier | `thatch_roof_panel`, `treated_roof_panel`, `plate_roof_panel` **[ADD]** | Water cover, heat/weatherproofing, visible roof |
| **Door and passage pieces** | Processed beam + fitted wood + hinge/strap | `framed_doorway`, `door_hinge_set`, `frameless_connector` **[ADD]** | Valid connections and access control; passage preserves room identities |
| **Joinery/fasteners** | `twine, hide_strap` early, `refined_iron_bar → forged_iron_fittings` later | `construction_lashing`, `iron_fastener_set` **[ADD]** | Each installed joint and finishing material |
| **Stone foundation** | stone → stone block (cut/chisel; source item must exist), clay → kiln-fired brick | `cut_stone_block`, `fired_brick` **[ADD]** | Foundation and fireplaces; later fortification |
| **Decorative/comfort furniture** | Planks, cured hide, textiles, bone fittings, scutes | bed, stove, racks, bench, lighting, shelves (blueprints and parts) | Local room function and **bounded** ambience buffs |

**Existing**: `wood_log`, `split_wood`, `plank`, `pillar`, `twine`, `hide_strap` and various kits. **New from chapter23 but not yet implemented**: `treated_plank`, `reinforced_bone_block`, `forged_iron_fittings`, `cured_hide_binding` and other craft chain components. **Avoid inventing raw source nodes without item definitions**. Stone block, fired brick and iron fastener recipes must have real gathering/crafting sources. Both `support_pillar` and existing `pillar` need explicit migration or alias contract to avoid duplicate meaningless item IDs.

### 4.1 Example illustrative recipes, NOT shipped or approved

- `support_pillar`: `plank ×2 + hide_strap ×1 → support_pillar ×1`, Workbench/Carpentry level ~10.
- `wood_floor_panel`: `plank ×2 + twine ×1 → wood_floor_panel ×1`, Workbench level ~10.
- `wood_wall_panel`: `support_pillar ×1 + plank ×2 + twine ×1 → wood_wall_panel ×1`, Carpentry level ~15.
- `thatch_roof_panel`: `plank ×1 + fibre_stalk ×2 + twine ×1 → thatch_roof_panel ×1`, Workbench level ~10.
- `support_beam`: `treated_plank ×2 + carved_bone_rib ×1 + hide_strap ×1 → support_beam ×1`, mid Processing + Woodworking.
- `reinforced_beam`: `support_beam ×1 + reinforced_bone_block ×1 + forged_iron_fittings ×1 → reinforced_beam ×1`, late Carpentry/Forge.
- `stone_wall_panel`: `cut_stone_block ×2 + cured_hide_binding ×1 → stone_wall_panel ×1`, Masonry skill.
- `plate_roof_panel`: `treated_plank ×2 + shaped_scute_plate ×1 + forged_iron_fittings ×1 → plate_roof_panel ×1`, late tech.

**Station career fit:** Woodworking/Carpentry shapes timber; Processing treats/composites; Butchering supplies scutes/bone/hide; Metalworking/Forge shapes fasteners; Construction consumes completed manufactured parts, uses endurance and skill to erect the structure. This creates trade demand among specialists, without obliging one character to master every prerequisite skill.

### 4.2 Blueprint size determines a *bill of materials* that uses functional slots

The blueprint requires **typed component roles**, not just `wood ×100`. Example small 2×2 cabin, illustration only:

| Installation role | Sample required components | Why |
|---|---|---|
| Foundation / floor | `wood_floor_panel ×4` | Four floor cells |
| Supports | `support_pillar ×4` | Four corner posts |
| Walls | `wood_wall_panel ×7` | Eight perimeter segments minus one door |
| Entry | `framed_doorway ×1` | One walkable access edge |
| Roof | `thatch_roof_panel ×4` | Four covered tiles |
| Joinery | `construction_lashing ×4` | Fasteners and material sink |
| Labor | Player/worker Construction work units | Labor after material delivery |

2×2 size ×1 is not automatically enough for 3×3. Scaling is computed from geometry and tech constraints (roof supports, corners and joins), with **per-material quantity and level** visible at placement. For early temporary field tent/bedroll, keep existing direct kits as an explicit exception until migration.

## 5. Material-based appearance and modular customization

**Visual design:** The actual **delivered floor/wall/roof/pillar components** decide the finished surfaces. Floor boards look like the lumber type; fitted stone walls visibly look stony; scute/bone pieces show reinforcement. The user's supplied Durango reference discusses majority material design and later appearance customization, but these are **proposal inspirations**, not independently verified gameplay facts here.

**Suggested deterministic texture resolver per room and surface:**

```text
surface_style(surface_role) =
  max_by( installed_surface_area_by_material_family,
          stable_secondary_order=material_family_id )
```

- Compute floor appearance from floor materials, roof from roof materials, walls from wall materials, pillars from installed supports separately. **Weighted by actual installed coverage**, not rarity, price, level or blueprint type.
- Example: 9 floor cells with 6 wood panels and 3 stone panels → primary visible flooring style **wood**, with optional visible stone accent if mesh system allows. A wooden floor does not make an iron roof look wooden.
- **No discontinuous combat/stat exploit from majority style**: visual majority is appearance only. Trait stats use actual quantity/role shares; switch from 51% to 49% must not magically halve building HP.
- Rooms should allow **redecoration/renovation** by applying a new manufactured wall/roof/floor finish through a **real refurbishment work order** with cost, skill and time. If cosmetic style is merely skin/paint, it must not pretend to replace protective material mass or make a cheap plank look like armored stone while retaining stone defenses.
- If a module shares a connected wall, show consistent doorway seam/trims. Attached modules can have visibly different roof, wall or floor designs.
- Preserve harvested/butchered batch identity and signed trait provenance into installed material summaries, while keeping saved data bounded.

## 6. Functional rooms and local ambience bonuses

A room is **functional when completed, appropriately enclosed (where required), accessible and fitted with the right stations/furniture**. Functional identity is determined by contents and player choice, not magical global aura. One house can be connected but individual rooms retain **different local ambience** calculations.

| Room archetype | Example furniture/equipment | Primary benefit (proposal) | Important counterweight |
|---|---|---|---|
| **Bedroom / home quarters** | Bed, lighting, weatherproof insulated roof | Better rest/exhaustion recovery and usable sheltered sleeping | Limited beds/occupants, current rest design governs rate |
| **Barracks** | Bunks/bedrolls, utilitarian heating | Efficient human worker housing capacity | Lower recovery/comfort than carefully furnished bedroom |
| **Kitchen** | Crock Pot, Stone Grill, Smoker + prep shelf/ventilation | **Kitchen Ambience** can reduce cooking work/time or modest waste within a cap | Real cooking fuel and food spoilage continue |
| **Workshop** | Workbench, tool rack, light, shelves | Slightly improved eligible crafting labor throughput or lower tool wear | No free material, no skill gate bypass |
| **Storehouse / pantry** | Chest/racks, covered floor, insulation or cold storage | More organized capacity; designated insulated store reduces food decay per [07](07-crafting-processing-and-food.md) | **Only actual container contents** get reduced spoilage, not every item on island |
| **Medical room** | Clean bed, medicine prep, sanitary storage | Better medically relevant work/safety conditions | No instant HP restoration from common food |
| **Taming / animal handling** | Reinforced gates/pen, feeding access | Safer dinosaur management, housing/capture utility | Species size and welfare limits; no automatic tame |
| **Communal room** | Seats, light, rest infrastructure | Bounded human rest/social support (if later defined) | Don't invent a happiness stat without an actual gameplay consumer |

**Proposal for rule evaluation:**
- `Room.valid` requires final structure, sufficient floor enclosure/roof for type, at least one accessible entrance, and required functional furniture. A stove dumped in an open field stays usable as stove but does **not** gain an indoor Kitchen Ambience bonus.
- `Room.ambience_score = Σ(valid_furnishing_points × furnishing_condition × trait_efficiency) + relevant_room_material_bonus`, with a family-specific **hard cap**, so placing 500 identical chairs cannot exceed it. Candidate mechanics only, not owner-approved math or values.
- Bonuses should apply **only** to eligible actions physically performed at the corresponding station/room (`kitchen cooking` vs `forge metalworking`); a shared interior door does **not** merge two rooms' kitchen ambience or provide one pantry's insulation to the next room.
- Example pilot, **NOT approved balancing**: a complete kitchen with cooker+prep shelf+ventilation gets up to **10% shorter Cooking work time**, diminishing duplicate furnishings; kitchen material traits may influence fuel and station wear separately. No stackable 10% from every chair.
- Housing is not simply XP gain: it supports the tribe population/children/future jobs, which already depend on resource and food supply. A mature tribe's rooms create demand for processed materials and builders.

## 7. Skill/labor rights, collaboration and worker specialization

**Owner-inspired rule:** A player/human **lacking sufficient Construction knowledge cannot INITIATE a blueprint/worksite** that requires it; they **may deliver materials, help with hauling and basic physical construction labor** if permissions allow. This makes actual builders valuable without blocking a party from collectively funding a house.

**Recommended permission matrix:**

| Operation | Check |
|---|---|
| Discover/learn/craft advanced blueprint | Appropriate Construction knowledge/skill/research and crafting conditions on initiating human |
| Place/create unfinished worksite | Valid blueprint item, placement rights, valid tiles, builder eligibility (or designated authorized builder) |
| Deposit components | Owner/tribe permission, valid exact material lots and worksite capacities; **no own advanced Construction unlock needed** |
| Haul, carry and provide basic labor | Permission, pathing, Endurance/Energy and worksite job availability; lower skill slows output |
| Perform technical stage/signoff (if enabled) | A suitably qualified builder; avoids loophole of a novice initiating a level-60 building by material delivery |
| Furnish/operate room stations | Usual station/equipment permission and personal skill requirements |
| Modify connected doorway, demolish or refund | Structure ownership/tribe construction rights and zone policy |
| Raid/damage/loot structure | Separate home-safe versus frontier PvE/PvPvE rules; no homeowner-permission bypass |

**Suggested work-time math (not a locked final formula):**

```text
work_remaining -= delta_seconds
                  × base_builder_efficiency
                  × relevant_construction_skill_factor
                  × endurance_energy_factor
                  × tool_quality_factor
                  × accessibility_factor
```

Use bounded factors, not infinite builder-speed multiplication. Multiple workers can contribute parallel work with diminishing site labor capacity; their fatigue, tool wear and feeding must remain real. Labor cost and material transfer are separate ledgers. A structure cannot be instantly completed by inserting its last plank if labor was not yet performed.

## 8. Structure traits, damage, upkeep, safe zones and rebuild

**Installed material-level & signed traits**, from [05](05-material-level-traits-and-loot.md):
- `Straight-Grained` beam can improve frame integrity; `Rot-Resistant` roof can lower maintenance; `Weatherproof` roofing can protect interior or pantry; `Insulating` hide can improve bedroom recovery / storage; `Reinforced` scute/iron fittings improve exposed wall protection; `Efficient Draft` furnace/smoker parts reduce fuel need. Negative `Warped, Cracked, Leaky, Flammable, Rot-Prone, Heat-Wasting` are real penalties.
- Evaluate trait impact only on relevant **component slots and material volume/area share**, then cap at sensible role-specific maxima; one rare floor plank cannot produce an impregnable fortress. Installed traits persist with the completed room and show in inspector. Damaged components may reduce active benefit until repaired.
- **Durability split:** structural current/max HP and repairable **wear/maintenance condition** should be distinct from environmental passive time decay. An exposed raidable wall can take damage from approved animal/PvPvE attacks. The **owner's protected home should have NO hostile damage**. For Durango-like private-home maintenance relief, **PROPOSE** no passive weather wear/maintenance cost on completed private-home structures, while optional frontier sites may have environmental wear by climate; this is **not yet owner-approved**. Food inside a safe-home pantry STILL spoils normally.
- Repairs consume compatible processed components and labor, with a tracked ledger. Replacing a weak wall with strong scutes should change only that wall and its visuals/trait summary, not retroactively upgrade every room in the settlement.
- **Safe-home replacement invariant**: paid home upgrade receives **100% of building material investment** in the special dismantle-material recovery vault and residents/items move separately. Keep original contributed lot identities, levels, signed traits, quantity and prior fusion provenance where possible; avoid giving both a component and its raw input back for one installation. Scope for blueprint paper, repairs, upgrades and partial worksites is OPEN, tracked.
- **Unstable-island resets** automatically dismantle installations into the special recovery vault but currently **do not have approved full 100% refund percentage**; don't copy the paid-home full-refund policy to all regions by accident. For contested outpost raids, destruction/loot rules are separate.
- **Large private home** is bought/replaces old island, not expanded via Durango's island expansion menu. Connected room module footprints may grow **inside** land boundary while private land itself remains finite and upgrade-priced.

## 9. Examples of different viable settlement layouts

```text
Example 1: compact starter compound
+--+----+
|2×2|3×3 |    # door socket between modules
|Bed|Cook|    # connected, independent rest + kitchen effects
+--+----+

Example 2: developed home
[4×4 shared hall] -- [3×3 workshop] -- [2×2 store/pantry]
        |
    [3×3 barracks]

All rooms have individual floor styles, roofing/insulation, furniture
and separate functional room ambience; shared structure supports navigation.
```

**Important:** diagrams are conceptual, not a literal grid embedding of incompatible widths. Actual doorway socket alignment, cell width and walkable connections must be validated in game before committing the arrangement.

## 10. Schema contracts and implementation worklist for Claude

### 10.1 Proposed data structures (illustrative, not existing schema)

```json
{
  "blueprint_id": "cabin_room",
  "allowed_sizes": [[2,2], [3,3], [4,4]],
  "required_construction_skill_by_size": {"2x2": 10, "3x3": 25, "4x4": 40},
  "worksite_stages": ["foundation", "frame", "enclosure", "furnishing"],
  "component_roles": ["floor", "support", "wall", "roof", "door", "joinery"],
  "unlocks": {"skill_tree": "construction"}
}
```

```json
{
  "worksite_id": "persistent-id",
  "owner_or_tribe_id": "persisted-owner",
  "blueprint_id": "cabin_room",
  "grid_cell": [12, 16],
  "grid_rotation_quarters": 1,
  "footprint": [3, 3],
  "state": "framing",
  "delivered_component_lots": [
    {"component_id": "support_pillar", "count": 4, "level": 20,
     "traits": [{"id": "straight_grained", "magnitude": 0.05}],
     "source_lot": "persisted-lot"}
  ],
  "labor_done": 18.0,
  "labor_required": 55.0,
  "room_id": "persistent-room-id",
  "door_sockets": [{"edge": "east", "offset": 1}],
  "room_role": "kitchen",
  "installed_surface_area_by_family": {"floor": {"wood": 6, "stone": 3}},
  "condition": 1.0
}
```

This does **not** imply all source lots must be serialized as huge repeated ancestry lists. Signed trait snapshots and verified source IDs can be condensed; ensure save migration and rollback are robust. The example worksite carries a candidate level/skill and labor, **not approved constants**.

### 10.2 Exact missing-feature backlog

- **BUILD-01** Unified **Crafting > Structures** recipe/unlock for blueprint items, personal skill/knowledge gating and clear resource estimation. No separate catalogue as an alternate way to build.
- **BUILD-02** Persisted worksite entity/state machine and full **ghost placement transaction**, grid occupancy, variable room footprint and material deposit panels. The existing grid is reusable but currently direct kit placement spawns completed structures.
- **BUILD-03** **Processed construction part items + recipes** `support_pillar, support_beam, reinforced_beam, wood/stone_floor_panel, wood/hide/stone_wall_panel, roof_panel, framed_doorway, fasteners, cut_stone_block`, with actual existing ore/log/stone/animal inputs and station gates.
- **BUILD-04** **2×2/3×3/4×4 selectable modular room family**, dynamic perimeter/roof/floor component geometry, rotational behavior, door-socket alignment and connected module IDs. Completed room does not expand in place.
- **BUILD-05** Deposit material **specific lot** / optional allowed substitutions (wood vs stone) with level/trait integrity, reservation, exact categories and no double-pay, partial material refunds and skill-aware work.
- **BUILD-06** Human/tribe worker haul/labor tasks, authorized unskilled material help, required qualified construction initiator, staged work time, persistence, tool 1-durability stop and safety.
- **BUILD-07** Visual material majority resolver for **separate floor/roof/wall/pillar surfaces**, rebuild/render mesh, room-specific looks, and legitimate restyling/retrofit cost.
- **BUILD-08** Completed room classification, enclosure/furniture checks, **bounded LOCAL ambience buffs** for kitchen, bedroom, barracks, workshop, storehouse, clinic and animal facilities, including food/worker/resting hooks.
- **BUILD-09** Structure component trait/level/crafting provenance to HP/repair/upkeep, real damaged surfaces/repair work, no giant bonus from one plank, own material appearance, and correct safe-home/PvE/PvPvE defense policies.
- **BUILD-10** Home-island atomic paid replacement + 100% original invested material **salvage-only vault** transfer, unfinished worksite cancellation, existing building-kit save migration, and distinct unstable island/reset/ransom/raid rules.
- **BUILD-11** Save/load and offline worker/time integration, door/path/navmesh updates, move/layout validations, connect/disconnect/refurbishment consistency, dynamic structure collision versus dinosaur size.
- **BUILD-12** Automated visual/behavioral acceptance tests and controlled migrations for legacy player kits/placed buildings, old recipe IDs, role materials, placement exploits and room ambience.

### 10.3 Test requirements

1. A 3×3 blueprint can be crafted only at valid Construction unlock; an unqualified helper may **contribute materials** but cannot independently place/start that advanced worksite.
2. Valid ghost placement reserves exactly nine grid cells and persists as unfinished across save/reload. Invalid overlap, unclaimed, slope or water consumes no item.
3. Building one 2×2 room requires **4 floor cells and 8 perimeter edges** worth of components (adjusted only for door/opening and actual panel coverage), not just a single `wood` category quantity.
4. A 4×4 completed room cannot be resized to 5×5 by dragging a corner. Attaching a separate 2×2 with aligned doors is legal, with separate room IDs and local ambience.
5. Processing a Straight-Grained treated plank and a Rot-Resistant plank into a composite beam correctly inherits signed traits and applying that beam to a structure changes frame durability/maintenance rather than unrelated food buffs.
6. A 3×3 room with **6 wood floor and 3 stone floor tiles** visually uses majority wood floor styling; if roof is mostly stone, roof style is independently stone. Stat contributions continue to depend on true quantities and material traits rather than appearance threshold.
7. Kitchen Ambience triggers only in a valid kitchen equipped and connected appropriately; workshop/barracks in adjacent modules do **not** receive Kitchen production bonus.
8. Building-material contribution reservation/withdrawal and worker labor stage interruption cannot duplicate materials or create free finished structures.
9. Paid safe-home island replacement automatically dismantles paid-investment building inputs and returns **100%** to the special vault **once** with lots/traits preserved. It does not copy ordinary chest contents into the salvage-only vault or make a second free house.
10. Temporary field camping kits that remain supported work after migration; unsupported old kits are converted/refunded transparently. No crash from old `PlacedBuilding` snapshots.
11. A saved unfinished 4×4 worksite occupies 16 cells, blocks pathing and survives reload; it cannot supply cooking/bed/room buffs before being completed.
12. Safe-home buildings cannot be raided/damaged by enemies. Remote PvE outposts have dinosaur attacks and optional frontier PvPvE outposts have allowed player attacks. Ambient weather/maintenance on private homes is **OPEN**, never equated with food no-spoil.
13. Food in kitchen/pantry decays at correct container multiplier even if the home cannot be attacked; spoiled food doesn't inherit kitchen ambience as a fresh edible.
14. A visually armored stone door cannot be passed through by a dinosaur physically too big for the opening; regular human worker route remains valid with door socket/path updates.

**Complete implementation means the relevant blueprints, component items, worksite deposits, staged labor, room appearance, functional ambience, save compatibility and automated tests all exist.** A .md file alone does NOT implement the mechanic.

## 11. Open owner decisions for later balancing

- **Blueprint item lifecycle:** consumed on placement vs durable reusable pattern once learned, plus what part of the initial craft material investment is refundable in paid island upgrade.
- **Construction skill thresholds and how a qualified worker sponsors the placement**: who is the builder of record when unskilled tribe leader asks a qualified follower to construct.
- **Exact modular size choices** (2×2,3×3,4×4) and whether rectangular 2×3,3×4 modules are unlocked later; room door and roof visuals need actual prototype.
- **Do floors/walls/roofs use uniform family styling by majority** or show detailed mixed patches? Recommended majority family for performance with optional true accents; actual material stats never tied to style majority.
- **Kitchen ambience** bonus implementation: lower cook work time vs fuel vs waste; how furnishings score, how far/enclosure counts, maximum buff and whether owner wants a named **Kitchen Ambience** status.
- **Construction material level contribution**, builder skill vs labor, load-bearing support density, failure/sag of gigantic unsupported roofs; choose readable lightweight abstraction, not fragile physics sim.
- **Passive building time-wear** on protected private homes: user-provided Durango description offers no passive private home wear. Propose protected home no hostile damage (already confirmed) and optional no passive weather decay (NOT confirmed), whereas frontier ambient/raid exposure can be tuned.
- **Cancellation, repair and manual demolition refunds** vs guaranteed 100% **paid home replacement** refund, new half-built worksites, originally fused composite lots and blueprint items. Avoid duplication.
- **Permitted zones / claim rights** for remote outposts and module connections. Cannot directly import Durango domain protection that invalidates Deadfront frontier rules.

**Historical statement handling:** The source message describes Durango's specific room dimensions, skill, door connection, materials-driven looks, room ambience, cooperative help and private-island passive durability as historical reference. This chapter treats those as inspiration; the Deadfront rules above are explicitly tagged as confirmed or proposed. No web source verification or game runtime changes occurred while writing this chapter.
