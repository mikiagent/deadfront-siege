# DEADFRONT systems vision: meaningful materials, living base, and generational survival

**Status:** Owner-directed design direction captured 2026-10-25 and **partly resolved** by explicit follow-up answers on the same date; **NOT an implementation order**. Newly confirmed rules are distinguished from unresolved implementation formulas and zone/loss policies. See the companion [Tribe, Lineage, Domain and Labor spec](tribe-lineage-domain-and-labor.md).
**Applies to:** Future DEADFRONT design and execution plans. No gameplay code was changed by this document.
**Read with:** `HANDOFF.md`, `GAUNTLET.md`, `docs/design/world-design.md`, `docs/design/skills.md`, `docs/design/economy.md`, `docs/design/durango-informed-improvements.md`, and `docs/release/ship-readiness.md`.
**Authority:** New owner intent supersedes older design where it conflicts; do not treat suggested implementation details or sample probabilities as approved balance numbers. The Durango systems PRD is historical research, not the source of truth for DEADFRONT-specific additions.

## 0. Sharpened fantasy and design pillars

**Refined pitch:** Survive a prehistoric archipelago, gather imperfect and exceptional materials, defend and develop a persistent settlement, and build a vulnerable tribe of skilled people and bred dinosaurs. Generations of stronger survivors inherit potential but must personally learn professions; existing people, equipment, territory and civilization progress never reset when control transfers.

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

**2026-10-25 owner refinement:** Durable outputs such as main weapons, crossbows, workhorse tools and buildings are the primary material-trait endgame. Food/one-use consumables should usually change/improve potion-like buffs and remain quick to manage. Rare treasure charms may target a chosen beneficial trait and raise its gathering odds (example: "+20% chance" is not yet defined as relative or percentage points). [Detailed trait endgame](tribe-lineage-domain-and-labor.md#8-resource-quality-and-targeted-trait-discovery).

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

**Owner-confirmed:** Workers are persistent human Tribe members with the same skill and equipment possibilities as playable humans. Build dedicated mining and lumbering sites and future production facilities. Workers automatically attempt tasks they **can** do, preferring tasks matching their aptitudes, levels and equipment. A built **Monitoring Stand** lets the player explicitly permit, prohibit and prioritize work.

Workers stop **automatic equipment use** just before breakage: a 250-durability tool used for labor should be left at **1/250**, not consumed by mindless job repetition. Show why a worker is idle, which task and tool they use, and what station/material blocks production. Hauling and worksite material delivery require real item reservations and transport, never free generation or duplication.

**Proposed future sub-systems:** per-human work priorities and eligibility, mining/lumbering production limits, station queues, item inventory, equipped gear, sleep/exhaustion, food/upkeep, zone safety, worksite jobs, maintenance/repair. A veteran character who was previously controlled by the player can remain a skilled worker with their accumulated personal abilities.

**Open:** whether tool preservation also applies in combat, where repairs are sourced, offline production, Monitoring Stand geographic scope, housing/support needs, and work hazards. See [detailed labor spec](tribe-lineage-domain-and-labor.md#6-worker-economy-and-self-directed-task-ai).

## 7. Tribe and generations: persistent lineage, **not a prestige reset**

**Owner-confirmed:** Humans and dinosaurs have distinct owned rosters, permanent identities and breeding systems. A tribe's domain in PvE/PvP territory draws **raiders** and **exiled wanderers** seeking to join. Human population is **limited by houses and other support infrastructure**, not unlimited roster capacity. Humans and dinosaurs can die in PvE/PvP battles.

Human reproduction is **extremely resource-consuming** and remains taxing at endgame. The player develops a lineage by intentionally selecting parents with useful inherited potential; wild dinosaurs likewise tend to have spiky/uneven stats, and selective breeding over generations can create stronger dinosaurs. Offspring do **not** automatically inherit their parents' earned levels and career XP.

**Absolutely no reset on character adoption:** The base, equipment, research/world state, dinosaurs, all other living humans, and every prior character's hard-earned levels and skills **remain**. Control transfers to a new, individually low-level survivor who gains XP and skills in their own career. The former avatar can work at base stations using their existing training and gear. This is an ongoing civilization and roster, not a New Game+ that erases anything. Transfer can also conceptually occur between existing eligible survivors; final switching restrictions remain open.

**Tribe-wipe fallback:** If all human tribe members die, a **new default playable survivor** with mediocre baseline innate stats appears. **The private home island is permanently protected**, with its stored resources and resident workers safe from enemy attack. Contested outpost losses and post-wipe ownership still need detailed policy; see [protected home / logistics / upbringing](safe-home-expeditions-offspring-and-identity.md).

**Genetic intent:** Innate potential and weaknesses matter over generations; excellent combinations should be rare and costly, not unlimited inflation. Humans should remain valuable individuals with jobs and identities rather than disposable stat tokens. The specific inheritance, raising, relationship and breeding formulas are **not yet locked**.

The canonical detailed spec is [Tribe, Lineage, Domain and Labor](tribe-lineage-domain-and-labor.md).

## 8. Expedition and separate rosters

**Owner-confirmed:** Three active **Expedition** companion slots can hold humans, dinosaurs, or a **mounted human+dinosaur pair as ONE composite slot**. The playable survivor's own mount/slot accounting remains to be decided. Human **Tribe** management stays separate from dinosaur **Creatures** management.

**Mounted combat is a trade:** An unmounted dinosaur fights according to its species instincts and AI (berserker predator, ramming charger, defensive herbivore with buck/tackle/tail swipe). A human rider improves coordination, intelligence and navigation, can attack with compatible mounted weapons such as spears, and shifts the pair toward controlled rider-led combat **at the expense of some autonomous dinosaur-style attacks**. The owner's "1+1 = about 1.5, not 3" describes desired synergy; **do not implement it as a universal numerical multiplier**.

**Suggested UI:** `Expedition | Tribe | Creatures`, with a single slot showing both mount/rider portraits and independent health/gear. Decide the name of the legacy Animals button once Expedition navigation is prototyped.

**Open:** fate of surviving mount when rider dies, player-character mount accounting, dismount, mount weapon limitations and save semantics. See [Expedition specification](tribe-lineage-domain-and-labor.md#7-expedition-slots-human-dinosaur-mounted-pair).


**Additional owner answers, 2026-10-25:** Every player has a permanently safe private island; PvE and PvPvE **outposts are optional high-reward risk**, with a possible boat-based worker transport route back to home for permanent material storage. **Confirmed:** remote resource settlements can be raided, but a boat **underway toward the home island** and its cargo cannot be attacked. **It may depart even during an active raid**, limited to cargo capacity from **boat and harbor levels/traits**; dock loading details remain open. **Future contested PvP** requires [local-alpha and anti-punching-down siege design](pvp-raiding-local-alphas-and-siege-fairness.md). Human offspring grow by **timer + sustained food-quality requirements**, with childhood/youth education shaping eventual abilities. Fictional human male/female models should visibly differ on average in size/strength and preferred roles, **without any innate intelligence gap or locked profession**; women are combat-viable through firearms, bows, crossbows, tactics and training, with significant overlap and exceptional individuals of either sex. Physique should partly signal but never perfectly disclose stats. See [design specification](safe-home-expeditions-offspring-and-identity.md).

**Further owner decisions (2026-10-25):** For the canonical source, see [design v2 decisions](../game-design/decisions.md). Larger private-island purchases **abandon the old island** for a **new larger home with higher-level resource nodes**; **dismantled building materials** go to a distinct salvage Ender Chest-like box. PvPvE entry requires **individual level 60 to unlock level-60 islands**, with a new low-level successor's access still to decide. Purchased/dropped/looted higher-level items are **strictly unequippable** until that individual meets the level; no scaled-down equipping. See [audited questions](../game-design/audit-and-open-questions.md) for migration and unlock consequences.


## 9. Dependency-aware roadmap (proposal, not approved schedule)

| Phase | Design outcome | Key proof |
|---|---|---|
| A | Live sleep/sitting, accurate effect tooltips | Partial rest and interruptions reflect actual Energy/Exhaustion |
| B | Inventory bulk selection/locks, visible traits and filters | Rare lots are protected and sorted correctly |
| C | Consequential materials, food buffs and rare trait-targeting charms | Long-lived gear differs materially; single-use food stays low-friction |
| D | One crafting menu, blueprint items, placed worksites and material delivery | No double-charges, save/load, no premature finished building |
| E | Persistent humans, housing, baseline survivor fallback, work assignments and Monitoring Stand | Old avatars retain skills; work stops tools at 1 durability |
| F | Mining/lumber sites, logistics and domain PvE danger/recruitment | Workers consume real inputs and survive meaningful territorial pressure |
| G | Separate Tribe/Creatures genetics, breeding and childhood/raising progression | Cost remains meaningful late-game; individual growth, no stat exploit |
| H | Three Expedition slots with mounted pairs and individual AI combat | Rider+mount counts one; meaningful changes to coordinated attacks |
| I | Zone-specific PvP/domain ownership and combat loss | Server-authoritative if real multiplayer, with recovery and fairness |

**Dependencies:** separate character identity from controller before character transfers; define durable inventories and AI work orders before automatic construction; decide housing/raid safe-zone policy before domain PvE; define genetics, limits and cost before breeding. PvP is a long-term server-backed feature, not a present ability of the single-player client.

Before shipping a phase, define save migration, exact visible flow, focused testing lab, UI behavior, and deployment release gate. See [detailed roadmap](tribe-lineage-domain-and-labor.md#10-dependency-driven-delivery-roadmap).

## 10. Owner responses, settled rules, and next decisions

### Resolved by owner on 2026-10-25

1. **Domain attention:** PvE/PvP zone domains attract hostile raiders and exiled wanderers who can join.
2. **Generational succession:** No existing civilization or human career progress resets when control transfers. New playable humans start personally inexperienced; veteran humans can become skilled base workers. Tribe populations depend on structures/infrastructure.
3. **Reproduction/selection:** Very costly even in late game; heritable strengths/weaknesses matter in both humans and dinosaurs. Typical wild dinosaurs have uneven stat potential. Tribe members and dinosaurs can die; human extinction yields a default mediocre survivor.
4. **Items:** Long-lasting gear and structures especially reward top-level, beneficial-trait materials. Consumables are less strategically important, while food traits enhance buff/potion-style effects. Rare treasure charms target specific desirable material traits.
5. **Workers:** Sites such as mining/lumbering, self-directed aptitude-based work, human equipment, 1-durability no-break automatic work policy, and buildable Monitoring Stand for controlling priorities.
6. **Expedition:** Three active mixed slots, mounted human+dinosaur pair counts as one slot. Mounted tactics improve pathfinding and control but substitute rider weapons for some independent dinosaur attacks; combined advantage is meaningful but far less than two fully independent fighters.

### Remaining high-leverage choices

1. **Territory (partly resolved):** Home island is **always unraidable and permanent**. Only voluntary external outposts have PvE/PvPvE exposure. Can raiders attack contested outposts and assigned workers while offline, and can shipments depart during a raid? **Homebound shipments already in transit cannot be intercepted.**
2. **Parenthood/raising (partly resolved):** Offspring mature **on timers**, consuming food. **Growth-phase food quality affects expressed final stats**, and a **youth education phase** builds knowledge. Who may become parents and what are the timing/care costs?
3. **Tribe wipe:** Protected-home resources/structures must remain safe. Which external territorial claims and combat-deployed possessions survive when every human dies?
4. **Genetics:** Visible height/build may correlate with genes, but some appearance and hidden potential should remain surprising. How does inheritance combine potentials and drawbacks without creating perfect lineages?
5. **Worker autonomy and losses:** What happens in offline time; do workers stop using weapons at 1 durability too; can a Monitoring Stand override safety?
6. **Charm odds:** Does "+20% chance" mean `p -> 1.2p` (relative) or `p -> p+0.20` (percentage points), and may bonuses stack?
7. **Rider edge cases:** Does a mount stay deployed or return home if its rider dies, and does the player-controlled survivor's own mount occupy an active companion slot?

**Next design gate:** Resolve the high-impact questions before locking genetics formulas, permanent-death and infrastructure persistence rules, raider scheduling, offspring progression and server/PvP implementation. [Detailed specification and acceptance scenarios](tribe-lineage-domain-and-labor.md).

