# DEADFRONT design-document audit and decision backlog

**Audit date:** 2026-10-25.
**Scope inspected:** root `HANDOFF.md` and `GAUNTLET.md`; `docs/design/` briefs (world, skills, economy, weapons, traits, tribe, safe home, raiding, progression), the historical Durango systems and dinosaur-roster PRDs, `docs/level-scaling.md`, `docs/controls.md`, `docs/engine-decision.md`, `docs/orchestration/plan.md`, `docs/release/ship-readiness.md` and the repository's markdown inventory. The `docs/orchestration/prompts`, `docs/orchestration/reports` and `docs/playtests` are historical implementation evidence; they are **not** treated as current design authority. This is a **product-spec audit**, not a line-by-line code audit or game execution test.

**Ground rules:** `docs/game-design/decisions.md` captures confirmed owner choices. A **CONFLICT** is an old statement superseded by an owner decision; an **OPEN** item requires an owner decision; a **SPEC GAP** needs detailed engineering/economy rules after intent is chosen. Illustrative numbers from old research are not a commitment.

## A. Obsolete or conflicting design language requiring canonicalization

| ID | Earlier docs/ambiguity | New owner decision and remaining action |
|---|---|---|
| C01 | Earlier briefs treated expansion versus moving to a fresh private island as undecided. | **RESOLVED:** new higher-level-resource island purchased; **automatic dismantling after preview/confirmation**, abandon old land; **100% return of building materials to salvage-only vault**; workers/animals/regular inventory transfer separately. Failure/crop/unfinished construction rules OPEN. |
| C02 | [World](../design/world-design.md) assumed starter-tier private-home resources and a 1–60 world resource ladder. | **RESOLVED:** paid higher-tier private islands can reach **level 50–55 resource nodes**, while **level 60+ is obtained elsewhere**. Need reconcile possible >60 resource levels with the current scale, and clarify safe PvE sources. |
| C03 | Earlier notes treated level-60 PvPvE access as merely a suggested unlock. | **RESOLVED:** tribe retains the unlock permanently once any level-60 person earns it, but **current controlled person must be level 60 to enter**. NPC companion levels and active-transition exploit controls OPEN. |
| C04 | [Skills](../design/skills.md) and [progression](../design/progression-risk-and-island-economy.md) present full item downscaling versus equip-level gate as alternatives. | **RESOLVED:** **unequippable** unless individual's level meets item requirement. Skills, traits, equip errors and NPC/boat effects still require specs. |
| C05 | Previous [PvP](../design/pvp-raiding-local-alphas-and-siege-fairness.md) suggested selected raid windows. | **RESOLVED:** owner says **NO scheduled player-selected windows**. Needs protection based on attacker scarcity/cost and robust garrison rather than online appointments. |
| C06 | [Durango systems PRD](../prd/durango-wild-lands-systems-prd.md) describes historic Savage/Combat Island and early/late PvP rules, plus no shipped breeding. | Research only. Do not copy as Deadfront. Current design explicitly wants **human and dinosaur breeding** and late, opt-in PvPvE outposts. |
| C07 | [World design](../design/world-design.md) states harbor **route list, never sailing**, while new boat/cargo specs require in-transit manifests. | No technical contradiction if harbor routes remain abstract with visible boats, but explicitly decide **map travel simulation vs steerable voyage**. Homebound vessel combat immunity is CONFIRMED. |
| C08 | [World design](../design/world-design.md) historically says unstable islands sink and reappear, while newer design suggests persistent contestable outposts. | **RESOLVED target fantasy:** unstable islands **reset resources and dismantle all placed bases automatically to salvage vault**; **islands cannot be raided**, only PvPvE settlements by players and PvE settlements by dinosaurs/animals. Need design rules for terrain regeneration, residents/storage and reset refund percentage. |
| C09 | [Economy](../design/economy.md) adds 25% price per latent attribute; [new material brief](../design/2026-10-25-systems-vision-and-open-decisions.md) requires **mostly negative traits**. | Market must price signed practical utility and levels, not every attribute as positive. Trait transfer and valuation still OPEN. |
| C10 | [Orchestration plan](../orchestration/plan.md) says solo-first/no PvP, mobile-first/no web, historic split agents; [HANDOFF](../../HANDOFF.md) uses deployed web as primary test. | Historical plans are not current product scope. Canonical design target supports future authoritative PvPvE while shipping strategy/platform/implementation sequencing remain OPEN. |
| C11 | [Ship readiness](../release/ship-readiness.md) suggests purchasing **extra character slots** as convenience; expanded tribe/population/gene system now makes capacity a major power source. | **OPEN** whether selling slots/housing/worker capacity is de facto pay-to-win. Do not approve purchased capacity until tribe economy and monetization fairness are resolved. |
| C12 | [Materials and inventory proposal](../design/2026-10-25-systems-vision-and-open-decisions.md) changes buildings from finished kits to blueprints + delivered worksites, while [world's building catalog](../design/world-design.md) describes costs for direct kit crafting. | Future spec must clarify **blueprint drafting cost vs worksite deposit cost** and dismantle/salvage behavior, plus save migration. |

## B. Priority owner questions (answer these before drafting implementation-grade specs)

### Critical: world, character, irreversible loss

**Q01. Protected-island move: RESOLVED in principle.**
**Confirmed:** Show a transfer preview, obtain explicit confirmation, then **automatically dismantle the old home**, abandon it, and move to a fresh larger island with higher-resource nodes. **Still OPEN:** whether the transfer can be cancelled after confirmation, what happens to unfinished construction/crops/temporary structures, how long it takes and how rollback works after a failed save or interruption.

**Q02. Salvage vault and asset transfer: RESOLVED in principle.**
**Confirmed:** All materials originally invested in buildings dismantled during **paid home upgrade** are returned at **100%** to a **special Ender Chest-like vault dedicated to dismantling refunds**. People, dinosaurs and ordinary inventory/storage transfer **separately**. **Still OPEN:** when dismantling includes crafted subcomponents or consumed blueprint items, unfinished building resources, chest capacity and UI, empty/missing container handling, and whether **unstable-island resets** also give 100% material refunds (not explicitly answered).

**Q03. Highest home resource level: RESOLVED in principle.**
**Confirmed:** The most expensive protected private islands yield **level 50–55 resource nodes**; **level 60+ nodes are elsewhere**. **Still OPEN:** exact island tier-price ladder, rare traits/biomes, whether level 60+ signifies numbers **above the historical level-60 cap**, and whether level-60 materials are obtainable in **PvE** without opting into PvPvE.

**Q04. Level-60 island unlock with successor: RESOLVED.**
**Confirmed:** The **tribe permanently keeps the level-60 island unlock** earned by any level-60 human; nevertheless, the **currently controlled individual must personally be level 60** to enter PvPvE. The player may switch back to a veteran level-60 human to participate. **Still OPEN:** which lower-level NPC companions, logistic crews, captive units or remote worker deployments can enter under that veteran's authorization and whether entry is locked on switching during an active deployment.

**Q05. Character level, skill and research jurisdiction.**
Does the character's personal **level** control equipment, island entry, recipe ability, skill maximum and genetic trait realization? Which crafting **blueprint unlocks/knowledge** persist as shared tribe achievements after a body switch, versus require personal training? Ensure veteran artisans remain productive.

**Q06. Offline raid consequences without raid windows.**
May other players kill/capture remote deployed tribe members and dinosaurs **while the owner is entirely offline**? If yes, can defenses fight at full trained potential, should there be a cap on irreversible loss per successful raid, and how does a defender learn the settlement was attacked? The home is always safe.

**Q07. Prisoner outcomes: 72-hour ransom, prices and trained-progress reset SETTLED in principle.**

**CONFIRMED:** Captured humans/dinosaurs enter a prisoner state; system calculates ransom and gives original owner **72 real-world hours** to pay. On timely payment, the original owner recovers the captive with **original inherited IVs + earned level + learned skills + trained EVs preserved**. After 72h unpaid, attacker may acquire a **level-1 adult with original inherited IVs and physical appearance**, then must earn levels, skills and trained EVs anew. The original owner's earned progress does not transfer. Exchange is possible. **OPEN:** exact algorithm/currency, reminders and outage protections, expiry claim button vs auto transfer, level-1 adult appearance versus general level-based age styling, equipment, recruiting time/loyalty, rescue, exchange effect on earned skills/EVs and caps on how many people/dinos one raid can capture.


**Q08. Region power fairness.**
Given level-60-only PvPvE, do weight classes still matter *inside* level 60? E.g. fresh 60 vs fifth-generation 60 with superior tool traits/boats/defenders. Would you prefer different **territory risk classes**, a limit on deployed assault power, matchups based on entire participating tribe, or a hybrid? Can local alphas hold a defensible position indefinitely?

### High leverage: production, progression, and raids

**Q09. Age and adulthood.**
Does the displayed age represent **real years**, career experience, or both? How do fixed growth timers interact with age that advances as characters level? Can older adults die naturally or be retired, or only die through battle/hazards?

**Q10. Personal gear restriction details.**
Must required level equal item level in all gear categories, or can item definitions have a lower explicit `equip_required_level`? Do tools, ranged weapons, food, accessories, ammunition, mounts and building/boat operations follow the same gate? Can an NPC worker wear gear above their current level (recommend no)?

**Q11. Island lifecycle versus raid scope: RESOLVED at product-rule level.**
**Confirmed:** **An island itself cannot be raided. Only constructed settlements can be attacked**: player raids target **PvPvE settlements**, while **PvE settlements can be attacked by dinosaurs/animals**. Unstable islands are **periodically reset** (resources refreshed), and **any base on them is automatically dismantled into the special Ender Chest-like dismantling recovery box**. **Still OPEN:** whether the same island footprint/land seed remains or regenerates, whether people/dinosaurs and ordinary stored items are auto-evacuated before reset, how much refund a reset returns, whether PvPvE settlements can also be attacked by wildlife, and whether any settlements persist across resets. These remain distinct from protected private-home purchases.

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

## E. Owner decisions incorporated, 2026-10-25

**Settled this turn:** Q01 automatic confirmed move/dismantle; Q02 100% paid-home building-material refund, separate transport of people/animals/ordinary goods; Q03 level 50–55 ceiling for expensive private-home resources, level 60+ outside; Q04 tribal unlock persists but the controlled human must be personally 60 to enter; Q07 prisoner with recruit/exchange/ransom; Q11 only built settlements are raided, while unstable islands reset their nodes and dismantle placed bases into the dedicated recovery chest. **Q06 remains unsettled:** offline permanent-loss handling, ransom notice delivery and server-outage rules are OPEN. **Confirmed:** ransom timer is 72 real-world hours, and nonpayment enables attacker acquisition with inherited IVs and preserved adult appearance, while their level resets to **1** and their earned skills/EVs must be rebuilt.

**Captive expiry and absent player:** the ransom/buyback opportunity is **72 real-world hours**, then attacker **may acquire a level-1 adult**, preserving their adult appearance and inherited IVs but resetting owner-trained EVs/skills/levels. **System-calculated pricing** is settled, while formula/currency, delivery of notices, server-outage fairness and attacker claim semantics are still critical decisions.

**New nontrivial design interactions surfaced:** 
- A full 100% **safe-home upgrade refund** does not automatically imply 100% return from **unstable reset** or **enemy-dismantled outpost**.
- Protected private-home island purchase **does not mean the old landmass itself is raided**; it is simply abandoned.
- A level-60 tribe unlock must coexist with individual-level entry, strict item equip requirements, autonomous NPC workers and player body switching, without level laundering.
- The old document's island `sink` lifecycle is a **historical implementation/reference**, while current design wants **resetting resources**. Whether terrain layout disappears and recreates remains unresolved.
- Distinguish **wildlife assault in PvE settlements**, **PvP raids of PvPvE settlements** and **non-raid exploration on shared islands**.
- **Ransom** offers a recovery path for permanent-loss stakes but can become captive-farming unless both sides have incentives, caps and secure settlement.

## F. Cross-domain character attributes (owner direction, 2026-10-25)

**Design intent newly raised:** Might should have utility both in melee and force-intensive craftsmanship (smithing); Dexterity should have utility both in ranged combat and detail-intensive craftsmanship (tailoring). This belongs in the same individual **IV/EV, age/level, professions and worker assignment** architecture, not new completely isolated combat and crafting stat pools. Refer to [character attributes draft](02-characters-levels-and-age.md).

**NEW owner questions:**

- **Q27. Shared attribute EV training:** Does repeated smithing contribute a **small amount of Might EV** usable in melee, and does shooting or fine crafting contribute a **small amount of Dexterity EV** usable across domains? Or are generic EVs earned only through dedicated exercises and upbringing? Cross-domain AFK exploit risk.
- **Q28. Craft attribute impact:** Should generic stats mostly affect **work speed/energy**, **quality/defects**, **special trait control**, or a mix? How to ensure profession skill/material input remain dominant for premium outputs?
- **Q29. Primary attribute roster:** Should the final set be Might, Dexterity, Agility, Endurance, Insight, and an optional Care/Empathy value, or another narrower set? Generic Care could be learned profession expertise instead of innate aptitude.
- **Q30. Worker and combat split:** Are cross-trained worksite workers capable of switching to fighting using their generic attributes but limited by separately trained combat technique, gear equip level and garrison orders? That would make an exceptional smith a potential defender without free expert warrior status.

**Do not infer:** a confirmed six-attribute roster, EV transfer rate, named skills, profession quality formula or passive female/male stat bonuses. The owner established the **shared-attribute principle** with Might/Dexterity examples; everything beyond that is a proposal.

## G. Combat taxonomy and actual Godot hooks (2026-10-25)

**Owner design directions, not implemented:** **Endurance** for construction work shifts, **Intelligence** for research/technology and pack/party alpha leadership with **Might or Dexterity** combat credibility; and six precise weapon styles: Dexterity/Impact (boulder thrower, catapult, slingshot), Dexterity/Pierce (bow, gun, blowdart), Dexterity/Slash (whip, throwing axe), Might/Impact (hammer/boxing), Might/Pierce (javelin/spear), Might/Slash (sword/axe).

**Existing code fact:** [Combat counter table](../../game/data/combat_counters.json) already distinguishes `blunt`, `pierce`, `cut`; no need to invent a new damage-type array. [CreatureBrain](../../game/scripts/creatures/brains/creature_brain.gd) chooses a wild pack leader by tier, HP, attack and defense, **not Intelligence**. [RaptorPackBrain](../../game/scripts/creatures/brains/raptor_pack_brain.gd) coordinates same-target pursuit and flanking. [BuildPlacer](../../game/scripts/world/build_placer.gd) currently instantly places a building and gives Construction XP, so **Endurance-driven building labor requires the separately confirmed unfinished-worksite implementation first**. Skill-tree research gates are metadata, not a staffed research gameplay system. [Full implementation bridge](15-pve-exploration-and-combat.md).

- **Q31. Alpha selection:** Should Intelligence participate in **choosing** the strongest leader if the candidate also has combat credibility, or should the physically strongest always lead while Intelligence improves their tactics and rallies?
- **Q32. Rally outcomes:** Target-switching/flank/retreat/formation AI only, or timed accuracy/defense/stamina buffs as well? Can an intelligent human lead both humans and dinosaurs via one command?
- **Q33. Construction Endurance:** Reduce Exhaustion/allow longer labor shifts only, or also build quality and speed? Future worksite must remain material- and Construction-skill-gated.
- **Q34. Research ownership:** Tech unlocked globally for tribe while personal Research + Intelligence determines contribution (recommended), or individually discovered knowledge? Which current trees require formal research projects?
- **Q35. Weapon modes and mastery:** Swinging vs throwing same axe uses Might/Slash vs Dexterity/Slash, and how does proficiency transfer between Melee and Ranged? Catapult is existing siege hardware, not just handheld Dexterity weapon.
- **Q36. Genetic/stat migration:** Current creature IV schema has seven combat stats and no Intelligence; should wild and owned dinos inherit new coordination IQ, or should Intelligence exist only for selected species/handlers?

**No determined coefficients, alpha selection score, new status buff, genetic schema changes, or shipped features are implied by this audit.**

**Naming superseded and locked (owner latest choice, 2026-10-25):** Inherited IVs **Dexterity (D)** and **Might (M)**; attack verbs **Impact (I)**, **Pierce (P)**, **Slash (S)**; six cells **DI, DP, DS, MI, MP, MS**. Do not reuse provisional **Precision**, **Blunt** or **Impale** as current UI names. Internal `blunt/pierce/cut` engine tokens remain unchanged. This is no longer an owner naming question.

## H. Inherited Dexterity/Might and dinosaur attack modes (owner latest decision)

**Confirmed:** **Dexterity (D)** for weapon/tool handling and ranged action control, and **Might (M)** for physical weapon strength and heavy tools, are intrinsic **IVs**. **Impact/Pierce/Slash** are **attack categories / verbs**, not another three individual IVs. Every move can be tagged with one IV and one damage verb. Same species can have multiple attacks and thus multiple cells: a heavy tail spike is **MP**, an accurately placed spike **DP**, and a careful grazing rake **DS** (last is proposal).

**Owner's Brontosaurus example:** exceptionally high HP, low defense, **Slash is effective**. Its whipping tail = **DS**, stomping foot = **MI**. **Conflict:** current data contains Brachiosaurus, with the `titan` family (high defense, Slash-resistant giant 0.5× cut). **Do not reinterpret or modify Brachiosaurus silently**. Make a distinct Brontosaurus entry or a species-specific vulnerable-flesh resistance profile and confirm balancing.

**Stegosaurus factual project state:** Current `stegosaurus.json` uses `spiked_tail`, 8500 HP, defense 300, spiked-tail sweep and `deep_bleed`. Candidate **MP heavy puncture** and **DP precision puncture** both retain Pierce category but offer distinct stat expression. Optional **DS rake** rewards positioning and bleeding (requires a different animation/hit contact). Species is currently a defensive armored enemy weak to Impact in `combat_counters.json`, which is consistent with an armored spiked defender.

**New balance questions:**
- **Q37:** Stegosaurus: should it default to **MP** with **DP** as a precision-bred alternative and **DS** as a trained rake, or should its sweeping tail be **DS** first, with **Pierce** reserved for deliberate targeted thrusts?
- **Q38:** Does the game's counter triangle treat **Impact -> hardened armor**, **Pierce -> fast/mobile enemies and weak points**, **Slash -> soft high-HP low-defense bodies**? What are concrete tradeoffs so each matters and no universal best attack exists?
- **Q39:** What is the **IV/EV separation** for Dexterity and Might? Inherited base values locked, and training can improve **separate expressive EVs**, or IV-only physical limits plus learned proficiencies? Existing 7-stat creature IV schema needs backwards-compatible migration.
- **Q40:** Is Brontosaurus a **new distinct species** with its own tail-whip clips and `soft_titan` defense family, leaving current **Brachiosaurus** stomp-only tank intact?
- **Q41:** Which attack modes can the same creature train/choose, and do active moves depend on genetic aptitudes, species physiology, individual levels and trained skill without making every unit able to perform every archetype?

No numerical combat tuning, actual breeding algorithm or new attack animations were introduced by documentation.

## I. Dinosaur defensive taxonomy review (2026-10-25 proposal, NOT yet approved per species)

**Working taxonomy proposed by owner:** **big and slow -> Slash weakness; heavily armored or small -> Impact weakness; lightly armored or fast -> Pierce weakness.** Design clarification: large **unarmored** slow giants are Slash-weak while **fast** lightly armored targets are Pierce-weak; tiny **grouped swarms** can be Impact-weak due to area effects, but tiny lone targets are not necessarily susceptible to a narrow hammer swing. Defense vulnerability and the creature's attack labels must remain **independent**.

**Audit completed:** [Full 19-existing-species proposed matchup/attack catalog](11-dinosaurs-and-genetics.md) cross-checks actual `game/data/creatures/*.json`, `game/data/combat_counters.json` and genetic schema. Baseline `fast_hunter` currently favors `cut` (Slash) rather than proposed fast -> Pierce; `giant` heavily resists `cut` rather than Brontosaurus-style Slash weakness; `armored` already favors Impact. **Keep these existing data values until mechanics/prototypes are reviewed**, not replace family multipliers globally.

**New decisions:** Does a raptor pack universally become Pierce-weak while its attacks remain mostly Slash/Pierce? Does a Compsognathus swarm need **Impact area** instead of global Impact vulnerability? Do Tyrannosaurus and Tarbosaurus become Slash-weak, or remain Impact-weak as protected bosses? Should the Codex expose only `Weak: Impact` or detailed current multipliers? Can every species have a single primary weakness with neutral secondary channels before unique resistance kits are authored?

## J. Worn armor weight versus creature defense (2026-10-25, owner requested exploration)

**Latest owner direction (2026-10-25):** [Equipment and armor draft](06-inventory-equipment-and-storage.md) supersedes the earlier Light->Pierce-only, Medium->neutral proposal. **New favored matchups:** **Slash -> Exposed + Light**, **Pierce -> Light + Medium**, **Impact -> Medium + Heavy**. Each damage type has two favorable defensive tiers. Unarmored Exposed is a natural body baseline, worn Light/Medium/Heavy are equipment categories, and natural defense/armor is independent of DI/DP/DS/MI/MP/MS attack moves. Pierce still catches fast evasive Light animals more readily; Slash gets soft giants, Light armor, sustained DPS, optional bleed/AoE. **These qualitative preferences are owner-suggested; values/code remain OPEN.**

**Current code fact:** `Inventory.equipped_armor()` sums Head/Body/Legs defense ratings and `CreatureAttack` applies generic armor. No 3-weight-class system, per-damage worn mitigation or gear mobility weights exist yet. There is high-level **Raid Hide** three-piece armor with a special tyrant anti-fracture/anti-pin full-set protection check; preserve it. `Vitals` provides Energy/Exhaustion and `Player` sprint drain/speed that could be extended. Tailoring planned hide/scute unlocks; recipes for raid kit present. Personal equip-level gate remains absolute. Never introduce armor type as a third IV.

**Open choices:** (Q42) Three weight classes with Unarmored baseline vs three inherent defense profiles? (Q43) Impact against Heavy primarily guard/stagger vs HP damage? (Q44) Might reduces heavy gear mobility/energy penalty, with strict personal equip levels intact? (Q45) Medium customizable by leather/scute/metal traits? (Q46) Barding/saddles for tamed dinos and whether equipment stacks with natural shell? (Q47) Does Light evade slow Impact through existing rolls, not an arbitrary all-purpose immunity? (Q48) How are positive/negative material traits and climate effects incorporated?

**Q49 overlap tests (OPEN):** (a) Are the 4 tiers the default for all creatures and wearable humans, allowing situational species overrides? (b) How to avoid base defense + tier damage multipliers double-penalizing Medium? (c) Does Slash favor *bleeding, hit uptime or attack arcs* to ensure parity with Pierce target acquisition and Impact stagger? (d) Can Heavy be hardest to kill even against its relatively favored Impact counter? (e) Keep fixed-DPS/status cap vs giant bosses so Slash's soft-giant niche isn't max-HP bleed abuse.
