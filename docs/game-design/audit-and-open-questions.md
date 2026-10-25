# DEADFRONT design-document audit and decision backlog

**Audit date:** 2026-10-25.
**Scope inspected:** root `HANDOFF.md` and `GAUNTLET.md`; `docs/design/` briefs (world, skills, economy, weapons, traits, tribe, safe home, raiding, progression), the historical Durango systems and dinosaur-roster PRDs, `docs/level-scaling.md`, `docs/controls.md`, `docs/engine-decision.md`, `docs/orchestration/plan.md`, `docs/release/ship-readiness.md` and the repository's markdown inventory. The `docs/orchestration/prompts`, `docs/orchestration/reports` and `docs/playtests` are historical implementation evidence; they are **not** treated as current design authority. This is a **product-spec audit**, not a line-by-line code audit or game execution test.

**Ground rules:** `docs/game-design/decisions.md` captures confirmed owner choices. A **CONFLICT** is an old statement superseded by an owner decision; an **OPEN** item requires an owner decision; a **SPEC GAP** needs detailed engineering/economy rules after intent is chosen. Illustrative numbers from old research are not a commitment.

## A. Obsolete or conflicting design language requiring canonicalization

| ID | Earlier docs/ambiguity | New owner decision and remaining action |
|---|---|---|
| C01 | [World design](../design/world-design.md) describes one private island, fixed terrain options; [progression proposal](../design/progression-risk-and-island-economy.md) lists *expand/migrate/multiple island* as undecided. | **RESOLVED:** player purchases a **fresh, larger, higher-resource-level home** and **abandons** the previous. Dismantled building resources move to dedicated salvage Ender Chest. Migration semantics remain OPEN. |
| C02 | [World](../design/world-design.md) assumes 160x160m private starting home and only lower-tier home resources, while old Durango rules treat unstable islands as source of level-tier resources. | **RESOLVED in principle:** new purchased protected homes have **higher-level nodes**. Need resource scaling, limits and non-PvP endgame availability. |
| C03 | [PvP workshop](../design/pvp-raiding-local-alphas-and-siege-fairness.md) still depicts player class matchmaking as the major gate and earlier late PvP as tentative. | **RESOLVED:** personal level **60 and level-60 island unlock** required before PvPvE. Regional anti-stomp classification still OPEN. |
| C04 | [Skills](../design/skills.md) and [progression](../design/progression-risk-and-island-economy.md) present full item downscaling versus equip-level gate as alternatives. | **RESOLVED:** **unequippable** unless individual's level meets item requirement. Skills, traits, equip errors and NPC/boat effects still require specs. |
| C05 | Previous [PvP](../design/pvp-raiding-local-alphas-and-siege-fairness.md) suggested selected raid windows. | **RESOLVED:** owner says **NO scheduled player-selected windows**. Needs protection based on attacker scarcity/cost and robust garrison rather than online appointments. |
| C06 | [Durango systems PRD](../prd/durango-wild-lands-systems-prd.md) describes historic Savage/Combat Island and early/late PvP rules, plus no shipped breeding. | Research only. Do not copy as Deadfront. Current design explicitly wants **human and dinosaur breeding** and late, opt-in PvPvE outposts. |
| C07 | [World design](../design/world-design.md) states harbor **route list, never sailing**, while new boat/cargo specs require in-transit manifests. | No technical contradiction if harbor routes remain abstract with visible boats, but explicitly decide **map travel simulation vs steerable voyage**. Homebound vessel combat immunity is CONFIRMED. |
| C08 | [World](../design/world-design.md) describes **unstable islands sinking after 6-24 hours** while new design features constructed, defendable, persistent **remote outposts**. | **OPEN** distinction between transient expedition islands and persistent contested territory; cannot put long-lived towns on islands that sink every few hours without rules. |
| C09 | [Economy](../design/economy.md) adds 25% price per latent attribute; [new material brief](../design/2026-10-25-systems-vision-and-open-decisions.md) requires **mostly negative traits**. | Market must price signed practical utility and levels, not every attribute as positive. Trait transfer and valuation still OPEN. |
| C10 | [Orchestration plan](../orchestration/plan.md) says solo-first/no PvP, mobile-first/no web, historic split agents; [HANDOFF](../../HANDOFF.md) uses deployed web as primary test. | Historical plans are not current product scope. Canonical design target supports future authoritative PvPvE while shipping strategy/platform/implementation sequencing remain OPEN. |
| C11 | [Ship readiness](../release/ship-readiness.md) suggests purchasing **extra character slots** as convenience; expanded tribe/population/gene system now makes capacity a major power source. | **OPEN** whether selling slots/housing/worker capacity is de facto pay-to-win. Do not approve purchased capacity until tribe economy and monetization fairness are resolved. |
| C12 | [Materials and inventory proposal](../design/2026-10-25-systems-vision-and-open-decisions.md) changes buildings from finished kits to blueprints + delivered worksites, while [world's building catalog](../design/world-design.md) describes costs for direct kit crafting. | Future spec must clarify **blueprint drafting cost vs worksite deposit cost** and dismantle/salvage behavior, plus save migration. |

## B. Priority owner questions (answer these before drafting implementation-grade specs)

### Critical: world, character, irreversible loss

**Q01. Private island purchase and ownership.**
When the player buys the next larger island, is **migration automatic after a confirmation** or must they manually dismantle and prepare everything first? Does the previous island disappear immediately or is there a one-time grace/inspection period? Can one upgrade before fully clearing it?

**Q02. Dedicated dismantling vault and property transfer.**
Do dismantled buildings refund **100% of their original materials, a reduced fraction, or some quality-dependent amount**? Does the Ender Chest carry only dismantling refunds as you said, with regular inventory/storage transported separately? What becomes of livestock, humans, unfinished worksites and unclaimed storage at the former island? No copy/duplication allowed.

**Q03. Higher-level safe-home resources and scarcity.**
Does a purchased island's resource **level cap** follow a tier ladder, reaching level 60 eventually? Are these nodes lower yield/rarer positives than frontier materials, or can careful safe-island play eventually access **all resource levels and beneficial traits** without PvP? Otherwise PvP becomes a hidden requirement.

**Q04. Personal versus tribe-level-60 PvPvE unlock.**
Once **one playable person reaches level 60**, does their tribe keep **account/tribe permission to access level-60 PvPvE islands** when control switches to a new level-1 adult? If so, can that low-level person enter (and risk death) but only equip appropriate gear, or must the *currently played person* also be level 60 to enter? Can lower-level companions/workers accompany a level-60 leader?

**Q05. Character level, skill and research jurisdiction.**
Does the character's personal **level** control equipment, island entry, recipe ability, skill maximum and genetic trait realization? Which crafting **blueprint unlocks/knowledge** persist as shared tribe achievements after a body switch, versus require personal training? Ensure veteran artisans remain productive.

**Q06. Offline raid consequences without raid windows.**
May other players kill/capture remote deployed tribe members and dinosaurs **while the owner is entirely offline**? If yes, can defenses fight at full trained potential, should there be a cap on irreversible loss per successful raid, and how does a defender learn the settlement was attacked? The home is always safe.

**Q07. Captive humans and dinosaurs: status and recovery.**
When seized in a frontier raid, is a **captured adult human or dinosaur** permanently converted to the attacker's tribe, held as a **prisoner** for rescue/ransom/exchange, or available as a temporary uncooperative laborer? What rules prevent captive farming from trivializing rare breeding/education? Can a player-controlled avatar be captured? What if all external members are seized?

**Q08. Region power fairness.**
Given level-60-only PvPvE, do weight classes still matter *inside* level 60? E.g. fresh 60 vs fifth-generation 60 with superior tool traits/boats/defenders. Would you prefer different **territory risk classes**, a limit on deployed assault power, matchups based on entire participating tribe, or a hybrid? Can local alphas hold a defensible position indefinitely?

### High leverage: production, progression, and raids

**Q09. Age and adulthood.**
Does the displayed age represent **real years**, career experience, or both? How do fixed growth timers interact with age that advances as characters level? Can older adults die naturally or be retired, or only die through battle/hazards?

**Q10. Personal gear restriction details.**
Must required level equal item level in all gear categories, or can item definitions have a lower explicit `equip_required_level`? Do tools, ranged weapons, food, accessories, ammunition, mounts and building/boat operations follow the same gate? Can an NPC worker wear gear above their current level (recommend no)?

**Q11. Remote outposts and unstable geography.**
Where do players establish **persistent** PvE/PvPvE outposts: on stable claimable zones distinct from **timed sinking islands**, or temporary gathering installations destined to disappear? Are level-60 PvPvE islands temporary or permanent, and can the owner abandon an outpost freely?

**Q12. Siege and losses.**
Can raiders fully demolish an entire optional outpost, or only attack specified structures and withdraw? What fraction of materials can be salvaged, how many people/creatures can be captured, and what permanently happens to a contested land claim after defeat?

**Q13. Raider attack frequency.**
Since **no player-scheduled raid windows**, should the attacker need **rare consumable siege permits and substantial siege supplies, with cooldowns**, or should attempts be unlimited but ruinously expensive? Is there recovery protection for repeatedly defeated outposts? Should PvE raider frequency follow distinct rules?

**Q14. Dock escape mechanics.**
Workers may load and launch a boat **during** the raid, at level/trait-limited capacity. Are dock workers/loaders vulnerable until departure? Does loading take seconds/minutes? Can attackers block a dock but **not** affect a departed boat? What prevents instant-launch spam of unlimited boats?

**Q15. Outpost workforce and resource economics.**
Can NPC miners/haulers work **while the player is offline**? Is there worker food/shelter/repair/risk upkeep in exposed zones? Are remote mining/lumber sites finite/diminishing, and what maintains material prices if protected-home islands eventually generate increasingly strong resources?

**Q16. Population and pregnancy/nurture limits.**
Does every new human require **two available adult parents, a home/nursery slot, food and a timed raising plan**? Which physical/genetic disadvantages and resource shortages can alter child outcomes without frustrating players? How long is early-to-adult growth, and what can mentors teach before adult level 1?

**Q17. Equipment durability at work.**
AI workers stop automatic work tools at 1 durability. Does that apply to **combat weapons**, defensive guards, mounted riders and mining under raid pressure? Are repair jobs automatic? Can the player authorize override?

**Q18. What counts as the actual beginner-to-60 progression?**
Old Durango research presumes island level, SP investment and research gates. What is the intended pace for **first hour, level 15, level 30, level 45, level 60**, first tame, first safe island upgrade, first child, and first optional PvPvE domain? What forms of XP besides hunting (building, cooking, mentoring, trading) count?

### Important: crafting, combat, and interface

**Q19. Material trait math and bag usability.**
What are negative/positive/neutral roll rates? Does one harvest generate a coherent lot or roll per unit? Can refining remove negatives without destroying positives? Is a charm's +20% a **relative multiplier** or **20 percentage points**? How are mixed-quality stacks organized?

**Q20. Building blueprint economy.**
Is the blueprint item **consumed on placement** after one-time knowledge unlock, with all real building materials deposited later at the worksite? Who builds and at what labor rates? Can damaging material traits affect a permanent structure's quality? How do finished buildings and worksites dismantle during safe-island migration versus raids?

**Q21. Expedition slot and mounted deaths.**
The **three slots** hold humans, dinosaurs and combined rider+mount. Does the **actively controlled survivor** count? Does their mount consume a slot? If a rider dies but the dinosaur survives, does the dinosaur keep the single slot, flee or return? What if captured in PvP?

**Q22. Exhaustion/food/effect semantics.**
Sleep reduces Exhaustion **per second** while sitting slowly reduces it and raises Energy. Does shelter use get consumed on interrupted sleep? Can the player sit/sleep while threatened? Worker/child food needs versus no player Hunger meter? Status glyph cap of 3 versus many equipment, food and support buffs; which are displayed?

**Q23. Bulk inventory and rare-item safety.**
Multi-select lock/drop/destroy should protect treasured trait items and equipment. What is the lock's exact effect on crafting, repair, work consumption and NPC logistics? Does dropping a stack make a reclaimable world object, and how long does it persist on safe/unstable/contested land?

**Q24. Support role effects.**
How do medicine, teachers, pharmacists and other support workers produce genuinely significant **tribe-wide** and expedition buffs without creating a hard gender-only meta, infinite stacking or paid-power shortcuts? Are these passive aura effects, manufactured supplies, or per-child instruction slots?

**Q25. Genuine multiplayer and accounts.**
Is the intended release sequence **offline/single-player prototype -> online market/social -> server-authoritative PvPvE**, or always-online from the early access release? Which persistence/storage layers own human IDs, market trades, outpost claims and captured humans? No code changes until this architecture is chosen.

**Q26. Ethical/economy constraints on payments.**
Could selling additional survivor slots, houses, worker capacity, livestock capacity, premium island sizes or rare-trait charms create pay-to-win once genetics and PvPvE exist? The Oct 16 ship-readiness document suggested slot convenience, but later design makes these raw productive power. Recommend cosmetics only until tested.

## C. Prioritized workshop rounds

**Round 1: Progression backbone (ask owner first):** Q01-Q05 (new home transfer/vault and lvl60 unlock persistence) plus Q06-Q08 (offline irreversible losses/captive/fairness), but split into manageable chat turns.

**Round 2: Siege risk economics:** Q11-Q15, especially rare attacker opportunity versus irreversible defender cost. Test raiding cannot out-earn manufacturing/expeditions.

**Round 3: Character and creature investment:** Q09-Q10, Q16-Q18, Q21 and Q24. A new descendant's level, inherited potential and aging must agree with market/equip restrictions.

**Round 4: Everyday play and implementation:** Q19-Q20, Q22-Q23, Q25-Q26, then chapter writing and data-contract signoff.

## D. Design deliverables and validation

- Establish **one canonical chapter per system** according to [the folder index](README.md), updating [the decision register](decisions.md) after each owner answer.
- Give every rule a scenario, formulas (only when approved), UI, progression/cost, failure/recovery, migration and anti-exploit tests.
- **Never** conflate historic Durango behavior with desired Deadfront rules, conceptual PvP with network-verified PvP, or a new design markdown file with shipped code.
- For island migration in particular, write a full **atomic transfer test matrix**: old private island, Ender Chest containing salvage-only, nested containers, regular inventory, humans/animals/eggs, boats, stations/unfinished sites, jobs, building traits, rollback, save/load and failure.
- For PvPvE, build **power-tier and gear equip exploit tests**: level-60 veteran unlock -> control level-1 offspring -> bought level-60 weapon, allied attackers, super-bred mounts, captured humans, PvPvE attempt. A safe island must remain attack-proof in every combination.
- Before choosing a monetary balance, run **economic stress examples** comparing island upgrade prices and base production against raid costs, probability of victory, loot/salvage values, boat escape rates and offline exposure.
