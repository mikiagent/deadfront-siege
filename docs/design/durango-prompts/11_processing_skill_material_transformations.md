# Claude Implementation Prompt 11: Durango Wild Lands Processing Skill and Material Transformation

## Objective

Implement the **Processing profession** from the original 2019 *Durango: Wild Lands* as a fully integrated gameplay system in my existing survival game. Cover the entire loop: gaining Processing XP, unlocking Processing skill-tree nodes with SP, using Handicraft and Metal Processing Ability, manufacturing components, changing individual materials in place, working with limited processing attempts, using workstations and delegated jobs, and feeding processed materials into weapons, tailoring, construction, cooking, inventory, and the player marketplace.

**Do not merely explain or prototype this system. Inspect my existing project, implement a functional vertical slice, integrate it, and test it.** Reuse existing inventory identities, crafting recipes, item traits, skill trees, timers, workstations, stat modifiers, market, and persistence. Never create a competing copy of those services.

Distinguish three levels of evidence in all configurations and deliverables: (1) mechanics evidenced in recovered original client skill/recipe data, (2) historical player-reported figures, (3) values estimated or modified by modern reconstructions such as Durango:0. Make all uncertain values editable.

## 1. What Processing is and is not

Processing is **both** a named skill category and an umbrella term for material transformations in multiple professions. Implement a shared transformation engine but enforce **recipe-specific profession requirements**. Drying leather or refining ore may require Processing; seasoning food may require Cooking; agricultural processing may require Farming. Do not award all transformation XP to Processing by default.

Three processing modes:

1. **Component manufacture:** Consume raw ingredients to produce a new type of item, such as rope, charcoal, peeled bark, nails, leather straps, glue, cord, fabric, metal links, or refined metal.
2. **In-place modification:** Select one existing material and change its tags or attributes (trimming, compression, surface preparation, tanning, metal treatments), spending processing opportunities when applicable. Preserve unique identity or explicitly log an identity-preserving definition transformation.
3. **Combination/alloy production:** Consume several specified inputs to produce a new material with calculated level and inherited or recipe-defined attributes (e.g., bronze, brass, steel).

These are different transaction types with shared validation and result-calculation services.

## 2. Processing profession and skill progression

Processing is one of the original 12 core skill categories. Its category level is limited by overall character level, historically level 60. Performing eligible completed processing work awards Processing XP and overall XP. Unlocking category level does **not** automatically grant every recipe: purchase relevant nodes with the shared Skill Point pool, honor prerequisites and category-level gates, and complete research milestones where applicable. Original recovered references describe around **44 nodes / 21 progression lines / 172 total SP** for all Processing nodes. Verify counts against data before baking them in.

Seed a data-driven Processing tree around these historically documented examples (not an exhaustive or guaranteed exact original-node inventory):

| Processing level | Skill or technique | Approximate SP |
|---:|---|---|
| 1 | Basic Processing; Rope | automatic/basic |
| 5 | Normal Nail | 1 |
| 10 | Charcoal; Leather Strap | 1–2 |
| 15 | Dry Leather; Peeled Bark | 2 |
| 20 | Handicraft I | 3 |
| 25 | Trimmed Material; Extended Fabric | 3 |
| 30 | Glue; Gem Extraction | 4 |
| 40 | Cord; Waterproofed Material; Refined Ore; Metalworking I | 4 |
| 45 | Adhesive Accessory; Dry Rubber; Metal Links | ~5 |
| 50 | Copper Alloy; Fiber-Tanned Material; Compressed Material | ~5 |
| 55 | Processed Surface and advanced metal/leather techniques | recipe-specific |
| 60 | Precision Processing; Processed Debris; advanced metal treatment | ~6 |

Use independent nodes for independently purchased unlocks, explicit prerequisite references, actual supported level requirements, and adjustable SP costs. Do not assume every skill listed in the same level row shares a prerequisite or cost. Research unlocks from the general leveling system should apply when appropriate.

## 3. Two kinds of ability, separate from category level

- **Handicraft Ability:** Effective proficiency for many general processing actions.
- **Metal Processing Ability:** Effective proficiency for metallurgy-specific recipes.

Both are distinct from Processing category level and final material level. Their values can draw from purchased passive skills, tools, equipment, food buffs, and attributes using the existing stat modifier system.

Historically documented ability lines:

- **Handicraft I–V:** skill-level milestones 20, 25, 30, 35, 40; approximately +4 Handicraft Ability per purchased node, up to +20.
- **Metalworking I–IV:** milestones 40, 45, 50, 55; approximately +4 Metal Processing Ability per node, up to +16.

Model these as configuration-based progression bonuses. Do not add bonuses every time the UI renders or a save reloads. Show current ability, required ability, relevant buffs, and calculated success chance in the processing UI.

## 4. Material instances and the finite processing count

Every bone, hide, log, ore, fruit, or processed intermediate remains a **unique inventory item instance**, with independent:

- stable instance ID and definition ID;
- level, tags, ordinary and rare attributes, durability or condition if supported;
- `processing_remaining` and optionally `processing_max`;
- processing history / provenance;
- owner and current container/location.

**Normal resources generally should not stack physically.** Visual groups must not merge data. One rare bone can be processed while another identical-named bone remains untouched.

Processing attempts are finite. A method defines how many attempts it consumes and whether it can operate on a material that has none left. At zero, block further count-consuming processing. Do not assume that five attempts is universal; source, gather outcome, and recipe may affect it. A modern reconstruction models some Flawless gathering outcomes as adding an opportunity and mistakes as removing one; tag these as unverified/reconstruction-specific until corroborated.

Do not mix up **processing count**, **material level**, and **attribute levels**.

## 5. Wood, bone and stone techniques

Implement data-driven material compatibility and changes. Begin with these documented / player-reported operations:

| Method | Approximate Processing unlock | Material attribute change / purpose |
|---|---:|---|
| Trimmed Material | 25 | Prepare compatible wood, bone, stone for further work |
| Compressed Material | 50 | High Density +2; durability-oriented |
| Processed Surface | 55 | Lightweight +2; accuracy/evasion/storage when relevant |
| Precision-Processed Material | 60 | Compact Structure +2; lethality-oriented |
| Processed Debris | 60 | Firm +2, Low Density +1; attack vs. durability trade-off |

Each method validates material type, tags/previous processing, learned skill, tools, workstation, ability, required additional ingredients, available attempts, and target attribute caps/conflicts. Preview changes **before** irreversible consumption.

Example: select **one** level-55 bone with Firm 2 and five remaining attempts. Apply Processed Debris three times, assuming success and no cap: Firm becomes 8; Low Density becomes 3; two attempts remain. The attack bonus is only realized when that bone is used in a compatible **primary material** slot of an equipment recipe. Its Low Density may reduce durability.

This example is simplified; support recipe-defined incompatibility, failure outcomes, and property cancellation rather than blindly adding every tag.

## 6. Leather, fibers, adhesives and general intermediates

Represent a viable pathway **raw hide/leather → dried material → specialized tanning → tailored equipment**. Example operations:

| Operation | Approximate Processing level | Effect |
|---|---:|---|
| Dry Leather | 15 | Prepare leather, remove wetness-related state where applicable |
| Fiber-Tanned Material | ~45 | Durability / High Density related potential |
| Alum-Tanned Material | ~50 | Lightweight +2; evasion-oriented |
| Oil-Tanned Material | ~55 | Tough Fiber +2, Low Density +1; defense vs. durability |

Exact unlock levels and variants should be verified against available original recipe data, and some numerical effects come from historical guides or reconstructions. **Do not treat every tanning technique as the same recipe.** Maintain material tags that permit or forbid subsequent treatments.

Also implement component conversion recipes where the existing item database supports them: ropes, nails, charcoal, straps, glue, cords, extended fabrics, rubber, and metal links. These should yield unique intermediate instances as appropriate, with item level and inherited properties calculated via recipe rules.

## 7. Ore refining, metal treatments and alloys

Build the pipeline **mine ore → refine at kiln using prescribed fuel/tools → optionally treat metal or alloy ingredients → use resulting material to craft equipment or buildings**.

Reference operations:

| Operation | Approx. skill level | Result |
|---|---:|---|
| Refined Ore | 40 | Convert ore to workable metal |
| Desulfurized Metal | 50 | High Density +2 |
| Smelted Metal | 55 | Lightweight +1 and Compact Structure +1 |
| Decarburized Metal | 60 | Firm +2 and Low Density +1 |

Reference alloy outputs (historical community tables; recipe details and values may differ by version):

| Alloy | Typical input family | Example inherited/added properties |
|---|---|---|
| Bronze | Copper + tin | High Density +5 |
| Brass | Copper + zinc | Compact Structure +3 |
| Leaded Bronze | Copper/tin/lead | Firm +4, Full +2 |
| Steel | Iron-based inputs | Firm +1, Compact Structure +2 |
| Wrought Iron | Processed iron | Firm +2, Sharp +2 |

Require exact ingredient instances, recipe-specific ratios, material roles, tools, fuel and workstation types/levels. If the game's material list lacks certain ores, add definitions carefully or mark those recipes unavailable, rather than presenting impossible craftable recipes.

## 8. Output level, attribute inheritance and rare traits

Integrate with the existing crafting engine. A production recipe may use average / weighted average ingredient level, bounded by the relevant skill category level and recipe minima/maxima. Example from a historical player guide: combining level-40 ore with level-60 charcoal could produce level-50 refined metal. **That does not prove every processing recipe uses an unweighted average.** Support recipe-specific formulas and special cases.

For **in-place processing**, use the existing item as the base; only change level when the actual process rules require it. Preserve rare green properties unless a documented explicit recipe transformation consumes or replaces them.

For downstream equipment and buildings, inherit ordinary material traits according to primary-material roles, often by averaging contributing trait levels and rounding down. Rare effects may use separate rules, such as qualifying from one main material. Secondary ingredients must not magically grant every trait. The UI's preview and final result must share one calculation service.

## 9. Tools, stations and delegated processing

Processing was intertwined with construction and workstation quality. Validate the exact station type, its **level**, relevant tool type/level, and ability requirements. Example requirements/times from **modern Durango:0 data, not verified original Nexon timers**:

| Operation | Station | Tool | Approximate delegated duration |
|---|---|---|---|
| Dry Leather | Drying Rack Lv. 15+ | none | 10 min |
| Trimmed Material | Workbench Lv. 20+ | Saw Lv. 5+ | 10 min |
| Alum-Tanned Material | Drying Rack Lv. 40+ | Hammer Lv. 25+ | 40 min |
| Compressed Material | Workbench Lv. 40+ | Knife Lv. 25+ | 45 min |
| Refined Ore | Kiln Lv. 35+ | Hammer Lv. 25+ | 20 min |
| Smelted Metal | Kiln Lv. 55+ | Hammer Lv. 45+ | 50 min |

Support immediate vs. delegated operations according to recipe definitions. Delegated jobs must reserve/remove exact materials, occupy one real queue slot, count down authoritatively, complete offline when supported, and deliver exact results. The station level can control recipe access and queue capacity, not merely cosmetic appearance. Building traits such as **More Space** and **Shorter Duration** must affect eligible jobs through the existing workstation trait system. Handle demolished stations, cancellations, full output containers and server restarts without losing items or duplicating output.

## 10. Success, failure, Flawless, energy and fatigue

Use the project's shared manufacturing service to calculate success from **required ability - effective ability**, based on the relevant ability type, equipment, food and buffs. Apply the already implemented success curve rather than creating another contradictory one.

Define recipe-specific failure consumption, possible partial recovery, and Flawless effects. Do **not** assume all processing jobs gain exactly the same bonus on a Flawless result. Some modern restoration behaviors are estimates; keep them configurable.

Consume configured energy/fatigue on actual processing actions; award XP exactly once at the eligible event. Workstation queues must not repeatedly award XP on loading or polling. Surface predicted costs and probabilities in the UI.

## 11. Processing UI

Create or extend a **Processing** profession screen with:

- current Processing level, XP, research gate, learnable nodes and available SP;
- current Handicraft and Metal Processing Ability, including bonuses;
- techniques organized as General Components, Wood/Bone/Stone, Leather, Metal/Alloys and appropriate subgroups;
- compatible inventory items with instance ID, level, attributes (positive gold, negative gray, rare green), remaining attempts, and processing history;
- exact item selection, station/tool requirements and consumed side ingredients;
- **before/after attribute preview**, output level, chance of success and Flawless, cost in energy/fatigue and time;
- start operation, delegated queue state, completion/collection and clear failure messages.

Never hide an irreplaceable rare trait behind a generic icon or auto-select that rare item when a common alternative exists. Allow filtering by processing opportunities and rare trait status. Keep touch-friendly layout and Durango-like dark panels / yellow highlighted actions if consistent with the existing UI.

## 12. Transaction architecture and persistence

Use one authoritative transaction mechanism for immediate transformations and delegated jobs. A successful transaction should:

1. Lock/validate the selected item and supporting ingredients.
2. Validate character level, learned nodes, effective ability, item tags, processing attempts, station, tools, permissions and queue capacity.
3. Calculate preview/outcome using the shared material and crafting services.
4. Atomically reserve resources and deduct relevant costs.
5. Apply success/failure/Flawless outcome exactly once.
6. Write processed item(s) with correct IDs, attributes, levels, ownership and location.
7. Update processing count and append provenance.
8. Award XP once and persist results.
9. Notify UI, crafting, building and market indices as required.

Use reliable persistent identifiers for processing jobs and operations. Prevent the same item being sold on Island Market, equipped, transferred or processed by another job while reserved. Enforce server authority for multiplayer.

## 13. Trade and cross-system integration

- **Inventory:** Never flatten materials into identical stacks; processed materials remain separately inspectable and tradeable.
- **Gathering/Butchering:** Preserve material origin and original traits; skill-based Flawless gathering interactions only where configured.
- **Weapon Crafting:** Firm, Compact Structure, Lightweight and related properties convert to attack/lethality/accuracy when inherited from eligible primary slots.
- **Tailoring:** Leather tanning influences defense, evasion and durability via recipe conversion rules.
- **Construction:** High Density can improve building durability; Lightweight and rare attributes can improve suitable storage/workstations.
- **Cooking:** Share the general transformation engine but use Cooking skills and food-specific inheritance; do not award Processing XP for every meal.
- **Player Market:** Listing or buying processed items transfers exact instances and their full modifications; preserve market escrow constraints.
- **Progression:** Shared SP economy, research gates, stat modifier service and item-level caps.

## 14. Required end-to-end vertical slices

Implement and verify these before attempting a huge database of recipes:

**Bone route:** Hunt dinosaur → harvest unique level-55 bone → inspect Firm 2 and five attempts → learn relevant Processing technique → process it with trade-off → verify updated Firm, Low Density and remaining attempts → select bone in a weapon's primary slot → craft a weapon with inherited stats → save/reload.

**Leather route:** Harvest hide → dry → tan with chosen technique → craft clothing → verify defense/evasion/durability conversion and preservation of rare traits where allowed.

**Metal route:** Mine ore → refine using correct kiln, fuel and tool → produce alloy or treated metal → craft an appropriate high-level weapon and inspect its inherited attributes.

**Economy route:** Transfer processed material to another player via Island Market → verify exact item instance and processing history survives sale.

## 15. Tests and edge cases

Test: separate Processing XP; character-level cap; SP unlocking/prerequisites; research gates; both ability score types; tool and station type/level requirements; finite processing count; zero-attempt rejection; identical named items with different states; exact item targeting; property cap/conflict rules; negative property trade-offs; rare trait preservation; recipe-specific output levels; in-place vs. new-item transformations; alloy recipes; success/failure/Flawless; delegated job timing and queue limits; cancellation/refunds; station destruction; offline progress; material reserve/release; save/load; repeated requests; two-player concurrency; full inventories; food/station bonuses; deterministic preview; XP issued once; and no duplication during market/storage transfers.

## 16. Implementation order and deliverables

1. Audit existing code and give a concise integration map.
2. Implement Processing definitions and skill-tree nodes in the existing level/SP system.
3. Add unified transformation recipe modes and validation.
4. Implement exact item instance modifications and processing counts.
5. Build one working bone-processing route and verify downstream inherited weapon stats.
6. Add leather processing, general intermediates, metallurgy and alloys.
7. Integrate workstations, delegated queues, ability scores, buffs, and XP/fatigue.
8. Connect UI, inventory, market, building and persistence.
9. Run tests and fix regressions.

Report files changed, nodes/recipes truly implemented, configurable values, test results, incomplete content and any historical assumptions. Do not claim features work unless they have been executed/tested or clearly state verification limitations.

## Historical reference material

- Recovered Processing skill descriptions: https://kghj76138.github.io/durango-homecoming-guide/en/skills.html
- Recipe and material processing lists: https://kghj76138.github.io/durango-homecoming-guide/en/craft-list.html
- Material properties: https://kghj76138.github.io/durango-homecoming-guide/en/materials.html

**Final principle:** Processing is not just converting five logs into a plank. It is a profession for deliberately improving **individual material instances**, spending finite opportunities to shape the attributes of the equipment, clothing and buildings other players eventually make.
