# DEADFRONT systems vision: meaningful materials, living base, and generational survival

**Status:** Owner-directed design direction captured 2026-10-25; **NOT an implementation order**. Exact rates, inheritance rules, roster limits, and edge cases remain proposals pending owner answers.
**Applies to:** Future DEADFRONT design and execution plans. No gameplay code was changed by this document.
**Read with:** `HANDOFF.md`, `GAUNTLET.md`, `docs/design/world-design.md`, `docs/design/skills.md`, `docs/design/economy.md`, `docs/design/durango-informed-improvements.md`, and `docs/release/ship-readiness.md`.
**Authority:** New owner intent supersedes older design where it conflicts; do not treat suggested implementation details or sample probabilities as approved balance numbers. The Durango systems PRD is historical research, not the source of truth for DEADFRONT-specific additions.

## 0. Sharpened fantasy and design pillars

**Proposed pitch:** Survive a prehistoric archipelago, gather imperfect and exceptional materials, build a working settlement of humans and dinosaurs, and grow a lineage of survivors whose inherited potential makes each new life a deeper run through the world.

The player should have recurring reasons to inspect each harvest, ingredient, craft, citizen, and creature instead of treating all like interchangeable quantities. The home island becomes a living economy, not only a decorative storage area. Generational progression should reward mastering existing systems and enable fresh strategic choices, not merely multiplying stats until all danger disappears.

Pillars:
1. **Variation with consequences.** Nearly every gathered lot has drawbacks; rare positive traits can be worth building around. Their numerical effects must be real and understandable, including in food and construction.
2. **Recovery is embodied and gradual.** Sitting and sleeping visibly restore the survivor over time, with different efficiencies and risks.
3. **One coherent production chain.** All structures begin in crafting as blueprints, are placed as worksites, and are completed by delivered materials and labor.
4. **The base works while the player explores.** Human workers have attributes, roles, needs, tasks, carrying limits, and visible work, rather than generating free resources.
5. **A lineage, not just a character slot.** A separate tribe of humans can work, accompany the survivor, and produce the next playable generation. Dinosaurs remain a distinct collection.
6. **Readable agency, not opaque RNG.** Players can inspect status numbers, select/protect inventory in bulk, choose materials intentionally, and understand how traits are inherited or modified.

## 1. Resting and exhaustive recovery (near-term UX)

**Owner intent, confirmed:** During sleep, the Exhaustion bar decreases continuously, rather than dropping only after the full sleep action. Add a ground **Sit** button usable wherever the survivor can safely sit. Sitting slowly reduces Exhaustion and restores Energy. Preserve Health/Medicine separation, current exhaustion penalties, and no hunger/thirst death meters.

**Proposed interaction contract:**
- Sleep still requires a shelter/bed. While sleeping, drain Exhaustion at that shelter's rate each second and update the HUD immediately. Allow waking/interrupting; keep any recovery earned so far. Pause combat and movement actions while sleeping, and break sleep on damage. Better shelter tiers recover faster and may provide safety/comfort.
- Sitting is an always-available action on valid land (no station required) via a clear HUD command, keyboard binding, and touch tap. A sitting animation or distinct pose is required. Sitting reduces Exhaustion much more slowly than sleeping and raises Energy above ordinary idle recovery; moving, attacking, damage, or selecting Stand interrupts it.
- Avoid making sitting an instant, risk-free replacement for sleep: time cost, vulnerability, and interrupted state matter. Prevent sitting in water, midair, or otherwise invalid terrain.
- Use live `Vitals` changes, no fake animation that advances independently of the actual bar. Rest should be testable over partial duration, interrupted duration, full duration, save/load, and background/resume.
- **Open:** rates, whether sleep duration is fixed or user-controlled, bedding-use consumption on partial sleep (must prevent 99%-complete reset exploits), safety/hostility rules, and whether sit is permitted anywhere during combat.

**Design compatibility:** `docs/design/world-design.md` currently describes fixed 5–12 second completed sleeps and disposable bedding with finite completed uses. That is shipped/historical behavior, not approval to keep instant end-of-sleep bar restoration. New rates/durability rules require a follow-up balancing decision and migration plan.

## 2. Status/effect inspector (near-term UX)

**Owner intent, confirmed:** Hover over effect icons beneath the Health bar to see what they are and the actual numbers.

**Proposed contract:**
- Hover on desktop, tap to open/dismiss on touch, and keyboard focus on desktop. Never require hover to understand an effect.
- Show localized name, source, whether buff/debuff, remaining duration, stack count, exact current modifier (flat/%/per-second), applicable stat, and useful counter/remedy when known. Examples are illustrative: `Bleeding: -2 HP/s, 9s remaining` or `Well Rested: +15% Energy regen, 25s remaining`.
- Tooltip values must be computed from *active effects and modifiers*, including stacks, level and resistance, not guessed from flavor labels. The countdown and impact update as statuses change.
- Mobile uses a readable anchored detail card; the small existing 18px `StatusGlyph` is informational, not a satisfactory touch target. Avoid covering core controls or breaking the current HUD layout.
- Test overlapping effects, long names, rapidly expiring icons, touch dismissal, and off-screen clamping.

## 3. Every material has traits, mostly negative (core systems priority)

**Owner intent, confirmed:** The currently implemented material attributes do not deliver the intended special-trait experience. Almost every gathering result should have a meaningful negative trait; rare positive traits should be uncommon, and neutral outcomes very unusual. Food, crafting materials, and resulting equipment should all matter on an individual find.

**Distinguish fields:**
- `level`, `material_tier`, `climate`, `origin`, `unstable` = identity/provenance; **not** positive or negative outcome traits.
- `traits[]` = named, signed gameplay modifiers with magnitude, tags, source, and handling/processing rules; each must have a concrete effect.
- Existing generic `attributes` can carry this at first, but a formal typed/data-driven trait definition and serialization contract are necessary before adding complex behaviors.

**Proposed generation flow:**
1. Node/creature/climate, harvesting method, equipment and skill define an eligible trait pool.
2. On successful harvest, roll a **lot** (one coherent outcome for items from one gathering action); attach at least one meaningful drawback to nearly every lot. Avoid a separate random trait for every single unit because it would explode inventory-stack count.
3. Rare positive traits can appear **alongside** drawbacks; exceptionally good lots may avoid major drawbacks. True neutral lots are possible but extremely rare or potentially removed altogether, pending owner decision.
4. Trait magnitudes, rarity, and stacking are deterministic from a saved seed/roll and fully visible in a material tooltip, not rerolled on reload/transfer.
5. Processing, cooking, combining, upgrading and crafting transform traits by explicit data rules. Positive traits and negatives should not automatically clone forever from one primary input; trace which ingredients contributed and prevent duplication exploits.
6. Let the player pick which stacks become ingredients, preview the predicted output's useful and harmful properties, and decide whether to use, process, sell, or discard a low-quality item.

**Illustrative traits only, not an approved catalog:**
- Brittle Stone: lower crafted-tool durability; exceptionally Dense Stone: stronger tools but higher weight.
- Fibrous Bark: binds well but takes longer to process; Moldy Bark: weaker lashings.
- Sour Berries: less Energy and possible short debuff; Fragrant Berries: rarer stronger food buff.
- Impure Ore: lower smelting yield; Veined Ore: rare higher yield; Diseased Meat: unsafe unless properly cooked.

**Open balancing issue:** Constantly negative traits can feel punitive, especially for beginners, and 20 slightly different stone stacks can fill a 20-slot bag. Mitigate with real trade-offs, targeted processing, lot-based stacking, intelligent sort/filter, stack merging rules and tools to bulk discard. Preserve the principle of predominantly negative outcomes while ensuring players still receive usable starter resources. Proposed test: two identical-level resources gathered in one region should frequently have different practical uses, and the choice should remain visible in a finished item/meal.

**Dependencies:** trait taxonomy and rule data -> harvest assignment -> inventory tooltip/filter/stack semantics -> crafting/food inheritance -> market valuation and storage behavior -> bot-based drop-rate/retention tests. Existing `ItemStack.attributes` and exact-match merge behavior are a starting point, not a finished system.

## 4. Inventory batch selection (near-term UX, prerequisite for traits)

**Owner intent, confirmed:** Select multiple items and perform Lock, Drop, and Destroy in bulk.

**Proposed contract:**
- Explicit Select mode with tap/click multi-selection, Select All / Clear, and selection count. Keep normal single-item behavior outside selection mode.
- Bulk **Lock/Unlock** protects valuables from unintended Drop, Destroy, auto-use and auto-material consumption; clarify whether locking an item should also prohibit manually equipping/using it. Current `ItemStack.is_locked()` influences tool availability and should be reconciled rather than silently reused.
- Bulk **Drop** places selected eligible items in-world, with visible recovery rules and capacity/position checks.
- Bulk **Destroy** permanently removes selected eligible items and makes irreversible action visually distinct from Drop. Confirm destructive action and protect rare, equipped, quest, and locked items by default.
- Operations report skipped stacks/reasons and do not partly delete a stack due to selection changes, stale indices, or multi-slot item placeholders. Persist lock flags.
- Extend selection to item quantities where needed; choose whether selecting a stack means all units or an adjustable count.

**Open:** dropped-item persistence/despawn, protected categories, how one confirms a large bulk destroy, and locking manual-use semantics.

## 5. Unified crafting -> blueprint -> construction site (major workflow change)

**Owner intent, confirmed:** Remove a separate building **catalog/menu**. A structure is unlocked via its blueprint recipe, crafted in the **same crafting menu** as gear/food, then placed as a blueprint item and built by adding materials to an unfinished construction site.

**Proposed flow:**
1. **Discover/unlock** structure knowledge through skills, research, exploration or progression. A locked structure is visible in Crafting with a clear unlock requirement.
2. **Craft the blueprint item** in a Structures/Blueprints category of the existing Crafting menu. This makes a tangible placeable item. Distinguish the cheap cost to draft a blueprint from the actual materials required to construct the building; do not charge the full bill twice.
3. **Place blueprint** by using the item from inventory or a quick placement action. Enter current grid ghost/rotate/validity flow. Valid placement consumes/reserves the blueprint and creates a persistent **worksite**, not a finished building.
4. **Deliver materials** from bag, storage, or NPC worker logistics to the worksite. Show required vs delivered materials, levels/traits where meaningful, and a progress bar/next step.
5. **Construction labor** (player or assigned worker) advances the site to a finished structure after requirements are met. Building material quality/traits should affect outcome as appropriate, without allowing a harmful exploit.
6. **Cancel/move/repair** with explicit refund and persistence rules. An incomplete site occupies its footprint, can be inspected after save/load, and cannot turn into an operable station prematurely.

The present `BUILD` interface may survive **only as a spatial placement/layout mode**, not as a competing recipe catalog. Existing crafted kits should be migrated carefully to blueprint items, and current placed buildings/saves must still load. Unlocking a recipe and consuming its blueprint item are separate concepts.

**Open:** are blueprints consumed on placement, reusable once learned, or renewable craftable items; site material quality tracking; who provides labor; dismantle/refund percentages; remote-island placement rights; when construction is allowed during danger.

## 6. Human base workers (major new system)

**Owner intent, confirmed:** NPC workers with individual stats can be assigned to the base for crafting, hauling/transport, and other productive jobs, inspired by Palworld's assignment loop.

**Proposed core jobs:** gathering at permitted local nodes, hauling materials between worksite/stations/storage, constructing worksites, operating stations/crafting queued recipes, farming, cooking, maintaining gear/buildings, and guarding. Phase them rather than launching all together.

Each human has a saved identity, stats/aptitudes, learned skills, relevant traits, work priorities, job eligibility, carrying capacity, Energy/Exhaustion and needs. Assignment UI shows job, destination/station, stock/input requirements, work-rate calculation, rest/safety state, and blockers. Use visible travel/carry/drop-off behavior. No teleporting goods, conjuring inputs, or duplicating materials. Workers use worksite inventory and storage permissions rather than reading arbitrary global inventory.

**Suggested phased automation:** (A) one worker + one hauling route; (B) supply a worksite; (C) craft from a queued recipe and deliver output; (D) priorities, work shifts, needs/food/rest, skill growth; (E) specialized jobs and multi-worker coordination.

**Open:** how people join tribe (recruitment, rescue, births), how many may work at once, their salary/upkeep/food/housing, worker autonomy versus micro-management, whether work progresses offline, hazards/death, and whether workers are all eligible to become playable characters.

## 7. Tribe and generations: a playable new-game-plus loop (long-term pillar)

**Owner intent, confirmed:** Add a **human tribe system separate from dinosaurs**, with the ability to create and raise new playable survivors that inherit stats from their parents. Each new generation should feel like a new-game-plus run in which understanding of existing systems and inherited potential make the player stronger. Tribe members can also work at the base or travel in the active party.

**Proposed model (subject to design discussion):**
- A persistent **Tribe** roster holds people, genealogy/parentage, inherited attributes, acquired skills, equipment, work preferences, relationship/parent eligibility and activity state. The **Creatures** roster separately holds tamed dinosaurs/pets and their current genetics system.
- A new playable successor is produced by the player-selected parentage/lineage mechanism. A clear growth/raising loop determines how and when the successor becomes controllable. No arbitrary implicit replacement of the currently played survivor.
- Distinguish **inherited potential** (aptitudes, ceilings, strengths/weaknesses, possibly recessive traits) from **earned ability** (XP, actual craft mastery and gear). Use meaningful trade-offs and diminishing returns/soft caps, not unlimited flat stat multiplication.
- **Generation transition:** the player voluntarily chooses a successor. The permanent base, discovered knowledge, tribe members, infrastructure and any explicitly designated legacy items persist. Personal level/skill allocation/progression reset partially or wholly only after the owner defines a rewarding reason to replay.
- Successors can specialize differently: one life might be a hunter, the next a builder/researcher who benefits from the foundation of the previous life. Better lineage should unlock viable strategies, not trivialize the world or force repeated idle breeding.
- Treat child growth, passing of time, parental selection, co-parent conditions, retirement/permadeath, kinship restrictions and relationship tone as **explicit open decisions**, not implied by the term "breeding." Abstract/fast-forward growth is a valid design direction for a survival game.

**Major risks to resolve before design lock:** how to prevent infinite stat creep and exploit chains; balancing dynamic island difficulty against stronger generations; avoiding mandatory/repetitive grinds; save schema and permanent identity for each character; player attachment to a particular survivor; compatibility with future multiplayer/tribal co-op; keeping the system approachable on mobile.

## 8. Party roster and navigation

**Owner intent, confirmed:** Current **three active animal slots** may also hold human tribe members, including a tribe member riding a mount. Tribe humans and dinosaurs remain separate management systems.

**Proposed UI names:**
- **Expedition** or **Party** = three active companion/deployment slots across humans, dinosaurs, and human-plus-mount combinations.
- **Tribe** = full human roster, family/generations, roles and assignments.
- **Creatures** = dinosaur collection, taming, genetics and growth.

Rename the current **Animals** command to **Companions** or **Expedition** only after selecting whether that screen manages the active three, the creature roster, or both. A clean proposal is three surface tabs `Expedition | Tribe | Creatures`.

**Open slot semantics:** Does a mounted human + their dinosaur use one composite deployment slot or two? Who controls the mount? Can the playable survivor itself ride a mount without consuming a slot? Are non-deployed workers always base-bound? A single definition must govern UI, combat balance, persistence, and summons.

## 9. Dependency-aware roadmap (proposal, not approved schedule)

| Phase | Outcome | Why this order |
|---|---|---|
| A. Clarity & recovery | Continuous sleep relief, Sit action, status numerical tooltips | Small visible wins; establish Energy/Exhaustion truth |
| B. Item agency | Bulk select/lock/drop/destroy, trait taxonomy and legible tooltips | Protect and sort unusual finds before increasing item variants |
| C. Meaningful materials | Trait rolls and transfer through processing, cooking, craft/equipment and value | Makes gathering decisions meaningful rather than cosmetic |
| D. Unified construction | Craftable blueprints, placeable worksites, delivery and manual build | Establishes durable work-order model |
| E. Worker automation | Worker roster, haul to worksite, station jobs, rest/skills | Leverages existing construction and crafting queues |
| F. Expedition + tribe foundations | Separate human/dino rosters, generalized three-slot party, mounted composition | Provides stable identity and deployment before inheritance |
| G. Generational NG+ | Parentage, raising, inheritance, successor transition, progression carryover | Highest-cost balancing/data change; build on a functioning tribe |

Before any phase ships: exact gameplay scenario, schema/save-migration plan, headless targeted lab, unit/smoke pass, desktop pixel test, phone tap test, and exact deploy/alias-stamp verification per GAUNTLET. Since this is a **design-only** document, none of those implementation tests have been run for these additions.

## 10. Decisions to make with the owner, in order

1. **Core motivation:** Is the ultimate fantasy breeding stronger *playable* survivors, directing a thriving tribe, or both equally? What does a satisfying generation transition look like?
2. **Generation mechanics:** Are offspring produced through two selected adult tribe members with relationships/time/raising, a more abstract legacy-combination system, or another rule? How quickly do they become playable?
3. **Carryover and difficulty:** Exactly which things persist after switching (base, discoveries, skills, personal level, items, creatures, jobs), and which reset? How does the next generation stay challenging?
4. **Party slots:** Does rider + mount count as one slot or two, and does the current playable survivor count?
5. **Materials:** Should 100% of gathered lots have a downside (positive+negative permitted), or allow a tiny clean/neutral percentage? What feels truly rare for positives: 1 in 100, 1 in 1,000, or another rate?
6. **Trait propagation:** Can processing improve/remove negative traits, can good traits transfer, and how do you prevent one exceptional input from endlessly replicating bonuses?
7. **Construction:** After unlocking a structure, is the blueprint itself a one-use craftable item, with all physical costs paid at the worksite?
8. **Workers:** Do all workers belong to the Tribe roster? Should they need shelter, food, rest, wages or other upkeep? Can they perform work when the player is offline?
9. **Rest/safety:** Are sitting and sleeping available during nearby danger, and what counts as a shelter's used sleep when interrupted?
10. **Drop/destroy:** Are locked items protected only from disposal, or also from equipping/crafting? How long should dropped items remain recoverable?

**Design lock gate:** Once answered, convert each phase into a canonical spec with explicit numbers, UI states, data schema, save migration and acceptance tests. Do not silently implement these open questions as guesses.
