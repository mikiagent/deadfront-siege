# In-place build roadmap | C0-C13

**Goal:** Ship approved game improvements on the already-implemented `game/` project while preserving real saves, content, UI, animation and export behavior. The order below is a proposed engineering dependency graph, **not** permission to implement unapproved numerical gameplay rules.

| Milestone | What to extend in current game | Existing files to reuse | Objective completion |
|---|---|---|---|
| **C0 Protect existing game** | Baseline tests/screenshots, save backups/recovery, representative schema 0-3 fixtures, regression script; retain schema 3 until required | `core/save_game.gd`, `save_migrations.gd`, `game/tests/run_all.gd`, `tools/` | Current real save safely reloads, errors do not clobber file, no gameplay regression |
| **C1 Signed material lots and fusion** | Trait catalog/resolver, optional lineage on `ItemStack`, selected two-source recipe only, output preview from both consumed lots | `items/item_stack.gd`, `inventory.gd`, `crafting.gd`, `world/harvest_node.gd`, `Data` | 2 inputs -> 1 component with both +/- traits, old recipes unchanged, save and merge tests |
| **C2 Food + rest UX** | Food timestamps, preservation/spoilage transformation, continuous Sit/Sleep and numeric effect inspector on existing UI | `items/food.gd`, `ItemStack`, `combat/vitals.gd`, `PlacedBuilding`, UI | 12h example only after values approved, offline catch-up and interruptions, no food reset on moving |
| **C3 Processing/18 weapons** | Smelter, Forge, Lamination Press and missing sourced intermediates; extend 6×3 weapon roster | `game/data/items.json`, `recipes.json`, `Data`, `crafting.gd`, `CombatCounters` | Every final weapon has real source, station, level gate and correct processed components |
| **C4 Worksites/packable construction** | Crafted blueprint -> grid worksite -> contributed components -> labor -> unique building; packed item ID preserves maker & traits | `BuildGrid`, `BuildPlacer`, `PlacedBuilding`, crafting data | Current home buildings/old kits stay valid, same identity across pack/unpack, capacity preflight prevents loss |
| **C5 Human tribe and occupations** | Import legacy player as human0, individual progression, recruit real humans, monitoring stand, finite jobs | `Player`, `World`, `SkillState`, `SaveGame`, `HarvestNode` | old avatar save intact, job tools stop at1, physical transfers and no double assignments |
| **C6 Descendants and education** | Food-dependent upbringing, parent/genetics records and teacher slots using same tribe roster | C5 records, food, skills | adult level1 retains only inherited IV, not parent skills/XP; birth idempotent |
| **C7 Combat attributes/armor/physics** | New 6 attack-mode labels mapped to existing counters, armor hit zones, body mass, stomp/pounce/mounted reach | `creature.gd`, `CombatCounters`, `CreatureAttack`, `CreatureGenetics` adapter | existing AI and combat tests pass, geometric hit and heavy pounce bounce, old IV preserved |
| **C8 Expedition roster/crew driving** | Three companion slots, trained human driver orders and real seat occupancy layered onto existing Player.mount | `Player`, `PetRecord`, `CreatureView`, `World` | can switch player and tribe driver without cloning humans; fallback when driver dies |
| **C9 Turrets and mounted platforms** | Existing field catapult refactor, automatic finite-ammo sentries, platform 1/2/1 sockets and single shared ammo box | `FieldCatapult`, `SiegeProjectile`, C7-C8 | both player/tribe gunner configurations and conservation tests, existing catapult unchanged |
| **C10 Home upgrades and world-reset safety** | Paid home replacement, salvage-only recovery vault, unstable reset policy after explicit owner decision | `World`, `SaveGame`, `PlacedBuilding`, grid | 100% home upgrade salvage, separate resident/storage transfers, no double refund |
| **C11 Physical logistics + market goods** | Boat+harbor physical load/route, future packed structure trade, original creator identity | `World.travel`, `cargo_home`, `Harbour`, `Inventory` | preserve cargo warp, boat becomes safe only after true departure |
| **C12 Frontier multiplayer** | Introduce real server authority, bounded siege PvPvE, 72h custody, anti-punch-down, raid economy | current game client plus NEW server after owner-approved scope | no client-authoritative fake PvP; permanent home immune, ransom/claim exact |
| **C13 Ship, optimize and polish** | Test on current web pipeline and touch, art/animation/UX performance, migration suite | `tools/`, assets, `GAUNTLET.md` | one verifiably serving production alias/build stamp after explicit release authorization |

## Smaller implementation dependency structure

```text
C0 Save safety / regression baseline
  ├── C1 Material lots -> C2 Food / rest -> C3 Advanced recipe chains -> C4 Worksites
  │                                                └── C5 Human workers -> C6 Descendants
  └── Existing capture + combat -> C7 Armor/mass -> C8 party/crew
                                       └──────────────────> C9 mounted siege
C4 + C5 -> C10 Home migration -> C11 boats & trade -> C12 server frontier
C13 continuous QA through every ticket (only release after explicitly requested)
```

This order is **flexible** when a small owner-approved feature can be shipped without later systems. For example, selected craft UI improvements and continuous sitting can be done before human reproduction. Build priority is determined by real player value, scope and dependency evidence, not mandatory giant batches.

## How to write a continuation ticket

A valid ticket declares:
`target_branch_base_SHA`; `existing_API_to_preserve`; `owner_confirmed_rule_ids`; `candidate_equations_needing_approval`; `old_save_fixtures`; `exact_data_IDs`; `owned_files`; `new_extension_files`; `input_output`; `acceptance_labs`; `desktop_touch_visual_gate`; `rollback`; `out_of_scope`.

Do not create a second project root or change every domain at once. Don't label shipped until actual build and deployed alias verified.

## Suggested first gameplay slice after C0

**C1A:** one processed `reinforced_bone_block` combining two `carved_bone_rib` material lots with both beneficial and detrimental trait lineage, plus binding catalyst and station. Exact new item IDs, quantities and fusion cap require owner sign-off, and should be cross-checked against `game/data/items.json`, `recipes.json`, `nature_manifest.json`, `butchering.json`. Write `Crafting._plan` and `build_output` tests first. Preserve all historical primary-inheritance recipes under opt-in extension.

Do not manufacture arbitrary required items or claim C1 is live before those sources/stations exist.
