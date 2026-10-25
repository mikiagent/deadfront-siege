# DEADFRONT | Canonical game design (v2)

**Status:** New design workspace created 2026-10-25. Detailed drafts exist for **unified attributes/individual progression, private-island migration, world resets, and PvPvE prisoners/ransom**. The rest are still planned chapters. Do not treat drafts as implemented/approved formulas. **Do not implement chapters that have not been reviewed and approved by the product owner.**

## Purpose

DEADFRONT's intended identity is **Minecraft Skyblock-style protected-island economic growth + Durango-style expedition/gathering/attribute crafting + ARK-style creatures, lineage and optional territorial danger**. A long-lived protected tribe economy is the primary game; PvE expedition play advances it; optional level-60 PvPvE gives committed endgame players a high-risk branch. Each character personally earns levels and skills; material traits and rare inheritance make items and individuals meaningfully distinct.

The October owner decisions live in [Decision Register](decisions.md). Conflicts, unknowns and owner questions live in [Design Audit and Open Questions](audit-and-open-questions.md).

**Authority for design work:**
1. Latest explicit player/owner answers.
2. This directory's confirmed decisions and, when written, approved subsystem specs.
3. Newer `docs/design/` owner-directed design briefs, read with their explicit CONFIRMED vs PROPOSED markers.
4. Historical `docs/prd/` Durango research and `docs/orchestration/` planning prompts: **references, not current DEADFRONT requirements**.
5. `HANDOFF.md`, `GAUNTLET.md`, code and test documentation: authoritative for *how the existing implementation works and is shipped*, not a veto against future design decisions.

Do not silently turn a proposal, historical observation or example number into a confirmed rule. Mark each specification item **CONFIRMED**, **PROPOSED**, **OPEN** or **IMPLEMENTED/VERIFIED** separately. A new requirement can be confirmed without being in the game yet.

## Confirmed backbone

- **Every player has a permanently attack-proof private island.** Home personnel, dinosaurs, gear, loot and production never become raidable because of wealth or level.
- **Safe island upgrades replace, rather than expand, the home.** The player pays a substantial price for a fresh larger home island with higher-level natural resource nodes. The old island is abandoned; the resources obtained from **dismantling** buildings go into a dedicated Ender Chest-style recovery box. Transfer rules for people, pets, storage, placed worksites and undismantled buildings are OPEN.
- **Personal character level is earned.** Switching to a new member does not reset the tribe/base or the former avatar; a newly controlled person begins with their own level. High-level bought, dropped, gifted, looted or crafted equipment is **unequippable** until the equipping individual's level requirement is satisfied.
- **Level 60 unlocks level-60 islands and access to the optional PvPvE frontier.** The **tribe keeps the unlock**, but the **currently controlled human must personally be level 60** to enter PvPvE; a lower-level successor cannot use the inherited unlock until leveled.
- **No scheduled player-selected raid vulnerability windows.** Remote PvE/PvPvE settlements are exposed; the protected home never is. Raiding should be expensive, limited and defensible, with anti-punching-down and local-alpha progression. Important exposed prizes can include dismantled outpost materials, equipped items, unshipped cargo, and captured humans/dinosaurs; exact capture and loss rules remain OPEN.
- **Boats may depart during active remote raids.** Boat + harbor levels and special traits limit real cargo capacity. A departed vessel traveling home, with its cargo/crew, is protected from all raids or interception; goods still in contested storage or dock loading remain at risk.
- **Generations are persistent characters**, with expensive resource-intensive reproduction, timed food-quality-dependent upbringing, youth education and inherited potential. Former avatars become experienced workers; dinosaurs have separate breeding and rosters. Total human loss yields a new mediocre survivor, while the protected home is not attacked.
- **Workers have individual equipment, skills and jobs.** Mining/lumber sites, hauling, a Monitoring Stand for preferences, and default stopping automatic work tools at 1 durability are intended.
- **Crafting and building merge.** Unlock/craft blueprint items in one crafting UI; place unfinished worksites; deliver materials and labor.
- **Materials are distinct.** Nearly all gathered lots should have consequential drawbacks and rare positives; traits especially matter for lasting tools, weapons and structures, while food changes temporary effects. Multi-item inventory selection, lock/drop/destroy, explicit effect values and sit/sleep recovery are part of the confirmed direction.
- **Three mixed Expedition slots.** Human/dinosaur rider pair counts as one tactical slot, shifting dinosaur instincts toward coordinated mounted movement and weapon use.

**New custody rule:** captured humans/dinosaurs become prisoners with **72 real-world hours** to pay a **game-calculated ransom**. Paying returns the original earned progression; unpaid expiry allows attacker acquisition as a **level-1 adult preserving inherited IVs and mature appearance**. Manual claim, pricing formula, allegiance and offline notifications remain OPEN. **Island rule:** only **constructed PvPvE settlements** face player raids; PvE built settlements face dinosaur/animal raids; unstable islands **reset** resource nodes and automatically dismantle bases into the recovery chest. Paid safe home upgrades return 100% materials; unstable reset refund rate remains OPEN.

**Confirmed custody balance (2026-10-25):** Human/dinosaur captives receive a **72-real-world-hour** ransom window at a **game-calculated price**. A successful ransom preserves **inherited IVs, original level/XP, trained EVs and learned skills**. If unpaid, attacker acquisition yields a **level-1 adult retaining the same mature physical appearance, identity and inherited IVs**, but previous earned XP, skills and EVs reset and must be trained anew. The ransom formula, transfer/claim action, notices, and loyalty training costs remain **OPEN**. [Detailed state and abuse tests](16-pvp-frontier-siege-and-captives.md). [Detailed state and abuse checks](16-pvp-frontier-siege-and-captives.md).


**New owner direction (2026-10-25):** **General-purpose attributes should affect both fighting and craftsmanship**: Might supports heavy forging and melee, Dexterity supports tailoring/fine crafts and ranged weapons. **Proposed expanded attribute families, shared EV training and per-recipe weights still require confirmation.** Learned profession skill, material traits and workstation/weapon quality remain separate factors. [Read the character/attribute draft](02-characters-levels-and-age.md).

**New owner combat and research direction (2026-10-25):** **Latest final combat framework:** weapon/tool handling **Dexterity (D) IV** and physical power/heavy-tool **Might (M) IV**, crossed with **Impact (I), Pierce (P), Slash (S)** attack verbs, producing **DI, DP, DS, MI, MP, MS**. Underlying engine counters remain `blunt/pierce/cut`. **Endurance** is connected to construction labor/Exhaustion; **Intelligence** to research, coordination, alpha leadership and rallies. Existing raptor packs pick alphas by physical strength/tier and share/flank targets; adding Intelligence is still a proposed change. [Combat and leadership integration](15-pve-exploration-and-combat.md), [shared attributes](02-characters-levels-and-age.md).


**New dinosaur body/defense proposal (2026-10-25):** **big, slow, fleshy -> Slash**, **armored/plated -> Impact**, **fast/evasive -> Pierce**. A **small swarm** may favor **wide-area Impact**, but single tiny creatures should not magically be weak to any hammer regardless of hitbox. This is a **proposed defensive weakness per species**, separate from an animal's own **Dexterity/Might × Impact/Pierce/Slash** attack modes. [Nineteen-species vulnerability and attack catalog](11-dinosaurs-and-genetics.md) maps all present JSON species, notes conflicts with the old resistance table and keeps Brontosaurus separate from existing Brachiosaurus.

**Species illustration (owner direction):** The proposed **Brontosaurus** should have giant HP but relatively low defense, rewarding Slash attacks. Its tail whip is **DS** and stomp **MI**. Existing **Brachiosaurus** is not a Brontosaurus and currently resists Slash due to its `giant` counter family; no balance table has been changed. Proposed Stegosaurus is chiefly **Pierce**: **MP** heavy spike, **DP** controlled spike, with optional **DS** rake. [Full combat chapter](15-pve-exploration-and-combat.md).

**Updated armor design (owner 2026-10-25):** Overlap the 3 attack verbs across **Exposed (unarmored) / Light / Medium / Heavy** tiers: **Slash** beats **Exposed + Light**, **Pierce** beats **Light + Medium**, **Impact** beats **Medium + Heavy**. Each favors two tiers. Light's speed/evasion remains separate from actual on-hit damage; Pierce can be easier to connect with against fast prey while Slash trades on sustained DPS/bleed and exposed soft giants. Medium and Heavy provide increasing base mitigation at increasing mobility/energy cost. Natural body armor and removable worn gear remain independent of animal offensive attack codes. **Latest proposed direction, not coded or numerically locked.** [Equipment and armor design](06-inventory-equipment-and-storage.md).

**Six-class weapon handling framework now selected for further design testing (2026-10-25):** Dexterity = **control**, Might = **force/heavy handling**, both for **ranged as well as melee**; Impact = **disrupt**, Pierce = **penetrate**, Slash = **shred**. **Delivery, attack speed, fire mode, reach, spread and area coverage are separate weapon properties.** Planned Might ranged examples: **MI portable heavy cannon, MP harpoon gun, MS carried heavy rotary/minigun**. Lightweight precision/supported guns favor Dexterity. Shotgun/Gatling Slash is an intentional potential videogame *shredding* abstraction, not a physics claim. [All 19 dinosaurs, ideal Dexterity vs Might matchup test](../design/dinosaur-weapon-matchups.md). These weapon examples, all species matchup assignments and exact combat statistics remain provisional, not shipped.

**Latest combat direction (2026-10-25, owner intent):** Deadfront may remain **mostly primitive rather than progressing to common firearms, powered exosuits, rocket launchers or Gatling guns**. **Might offers the strongest immediately accessible physical survival kit**, while **Dexterity earns a larger variety of precise ranged weapons and specialized operations later**; neither stat becomes obsolete. Mounted humans/dinosaur teams should make **melee and polearms viable against giants** through **repositioning, mounted height/reach, committed charge timing and coordinated tactical movement**, not an unexplained blanket damage bonus. A future **Brontosaurus** is frightening because **DS long-tail whip threatens at range** and **MI stomp threatens close to its legs**; both need fair telegraphs and attack windows. **Mounts can be struck, knocked down or injured**. This builds on the approved **one rider + one dino = one expedition companion slot**, not two free full fighters. [Mounted combat, primitive weapon and giant boss design](12-expedition-mounts-and-command.md). Technology ceiling, exact damage, saddle skills, mounted AI and attack behavior remain proposals.

**Mounted weapon mastery direction (2026-10-25):** certain weapon *modes* reward **condition-based execution** instead of simple firing speed or permanent numerical scaling. **MP** mounted spear/lance/javelin can gain **Momentum Strike** from a meaningful forward charge aligned with contact; **DI** sling/aimed blunt projectile can earn **Longshot** for hitting accurately over substantial range. Make both capped, readable and non-exploitable (direction/run-up and projectile accuracy/effective range; no blanket free damage on all mounted attacks). User approved the **seven mount archetype names** as a working set, while species assignments and exact mechanics are still proposed. [Full mounted mastery / cavalry roles](12-expedition-mounts-and-command.md).

**T. rex + consecutive-hit + mount height owner clarifications (2026-10-25):** **T. rex is intended to be tameable AND rideable** as a Tyrant mount; existing `tyrannosaurus.json` presently contradicts this (`tameable: false`, no `mount` role) and needs a future implementation reconciliation without trivializing its current raid boss. **Very large mounts create rider-weapon reach limits:** a sword on a high T. rex saddle cannot strike ground Compys merely because the Rex's jaws/stomp can. Rider hit geometry and dinosaur natural attack reach are independent. **Melee Slash should reward successive landed attacks** through a capped Combo/Rend, while **Berserker Frenzy** emphasizes maintained consecutive-hit pressure; misses or disruptions can break a streak. T. rex Tyrant remains a deliberate bite/stomp threat, not an automatic Berserker. Detailed design and still-unapproved numbers: [Mount geometry, Rex and Frenzy](12-expedition-mounts-and-command.md).

**Latest dinosaur physical-combat idea (2026-10-25):** A new **natural body mass + added equipment load + species carrying capacity/encumbrance** system supports **footprint-based trample against multiple tiny animals, relative-size Pin against smaller prey, and raptor Pounce -> Pin -> Maul/Gore** where the animal's anatomy and hitbox actually permit contact. Add **fitted Light/Medium/Heavy dinosaur barding** with protected body regions and true carrying/mobility/energy/turning trade-offs. Showcase **heavily armored Brontosaurus**, with Heavy-protected back/flanks countered relatively by Impact, while exposed legs still reward Slash; enormous mass and long DS whip/MI stomp remain dangerous but become less agile under load. **Status names already exist in code**, not these mass/armor/contact mechanics. [New mass, armor and trapping chapter](22-dinosaur-mass-armor-and-grappling.md). Specific weight formulas, geometry and implementation unapproved.

**Weight-power and anti-pounce refinement (owner direction, 2026-10-25):** Extra **physical mass increases the actual force/damage of connected MI stomps, tackles, body slams and tramples**, with diminishing/capped rewards offset by worse acceleration/turns/energy costs. **Heavy creature armor on the struck pounce zone blocks the raptor's pin attempt outright**, causing a distinct **recoil/back-off** and no automatic pounce knockdown/pin/maul sequence; it may still take reduced contact damage or lose plate durability. A more massive animal's **different** body crush, foot stomp or jaw grapple can still affect a Heavy target. Pounce suppression must occur **before** current status assignment. [Mass and Heavy Pounce Deflection design](22-dinosaur-mass-armor-and-grappling.md). Numbers and implementation open.

**Latest relative-mass stomp defense rule (owner direction, 2026-10-25):** a **heavier defender takes less damage from body-weight stomps/tackles**, and sufficient Heavy body mass/plate/stance can **resist stagger and knockback outright**, permitting a steady **close-range Bulwark approach**. Light Cavalry avoids stomps via speed; Bulwarks sometimes absorb contact without being interrupted, at the cost of worse mobility/stamina. When a much heavier Titan stomps a small armored creature, the extreme mass gap still hurts. The attacker gains stomp power from physical mass; the defender gains stomp mitigation/poise from its own mass; avoid double-counting mass or falsely claiming Heavy resists every Impact weapon. [Relative-mass and stability rule](22-dinosaur-mass-armor-and-grappling.md). Values and code still OPEN.

**Weapon crafting progression, owner request 2026-10-25:** Define exactly **18 iconic weapons**, one per **DI/DP/DS/MI/MP/MS** slot for **Early Stone/Bone**, **Mid animal composites/first copper**, **Late forged iron and dinosaur trophy composites**. Design ingredient recipes grounded in existing `nature_manifest.json` and `butchering.json`, and record **every missing ingredient, ammo, output, station, source or skill gate as an explicit WPN-01..WPN-24 implementation backlog**. Home Compy/ceratops drops support bone/tendon/scute; rare raptor talons support Mid; Desert ~35 copper ore begins metal; need actual Smelter and iron-ore Tier45–50 source (missing) and dedicated ingot recipes. Existing generic workbench `ingot` recipe bypasses believable metallurgy. Metal should transform durability, crossbow mechanisms, piercing/impact/edge engineering, not erase dino bone/tendon. [Full 18 weapon tables, recipes, resource sources and task list](23-weapons-and-material-crafting-progression.md). **No runtime code changed.**

**Processed-component endgame rule (owner correction, 2026-10-25):** Final Late-game weapon and metal-tool assembly should **never directly use raw logs, bones, talons, hide, tendons, ore or crude metal ingots**. Instead use full cross-career work chains: `wood_log → split_wood → plank → treated_plank → reinforced_stock/haft`; `dense_bone → carved_bone_rib → reinforced_bone_block` (binding pitch and cured hide); `predator_tendon → sinew_cord → braided_sinew_cable`; `raptor_talon → honed_talon_set`; `iron_ore → iron_ingot (Smelter) → refined_iron_bar (Forge) → shaped head/fittings/trigger/chain`. **Scute-Core Maul** needs a specifically **shaped_scute_plate**, not an unrepresented scute. Existing `plank`, `split_wood`, `dried_hide`, `hide_strap`, `twine`, `charcoal` processing recipes form the early foundation; most advanced components are **new item/recipe and station backlog WPN-21..WPN-24**, not shipped. [Complete processing dependency tables and revised six final assemblies](23-weapons-and-material-crafting-progression.md).

## Proposed chapter library

The following are **planned chapter paths**. The files do not yet exist unless linked elsewhere. Create and lock them incrementally after the relevant owner questions are answered, rather than scaffolding empty or fabricated specifications.

| Draft chapter | Scope |
|---|---|
| `01-core-loop-and-onboarding.md` | First hour, fantasy, beginner experience, PvE vs PvPvE choice |
| [02-characters-levels-and-age.md](02-characters-levels-and-age.md) | Personal level, body maturity, **shared combat/crafting attributes**, IVs/EVs, professions, equipment gates and level-60 entry |
| [03-private-islands-and-upgrade-migration.md](03-private-islands-and-upgrade-migration.md) | Protected homes, island size tiers, abandonment, salvage vault, map generation |
| [04-world-biomes-and-travel.md](04-world-biomes-and-travel.md) | PvE regions, level-60 frontier, instability, ports, route unlocking |
| `05-material-level-traits-and-loot.md` | Signed trait rolls, rarity, charm odds, gathering, processing, premium material hunting |
| [06-inventory-equipment-and-storage.md](06-inventory-equipment-and-storage.md) | Stacking, bag slots, batch selection, locks, overflow, death drops, vault |
| `07-crafting-processing-and-food.md` | Recipes, inheritance, item level, crafting quality, buffs, agriculture |
| `08-blueprints-worksites-and-building.md` | Unlocks, craftable blueprint items, material deposits, labor, dismantling |
| `09-tribe-population-and-recruitment.md` | Unique persons, housing/support capacity, exiled wanderers, allegiance |
| `10-human-genetics-upbringing-and-education.md` | Parentage, expense, food stages, inherited potential, visibility and physical variation |
| [11-dinosaurs-and-genetics.md](11-dinosaurs-and-genetics.md) | Wild captures, spiky stats, species AI, husbandry, breeding, permanence |
| [12-expedition-mounts-and-command.md](12-expedition-mounts-and-command.md) | Three slots, riders as composites, human followers, inventory, mounted behavior |
| `13-workers-automation-and-logistics.md` | Mining/lumber sites, monitoring stand, work orders, tool durability, boat shipping |
| `14-vitals-rest-status-and-medicine.md` | Exhaustion, Energy, continuous sleep, Sit, effect tooltip, medical/education buffs |
| [15-pve-exploration-and-combat.md](15-pve-exploration-and-combat.md) | Level ladders, hunting, capture, hazards, guards, PvE raids |
| [16-pvp-frontier-siege-and-captives.md](16-pvp-frontier-siege-and-captives.md) | Level-60 entry, power class, local alphas, raid economics, capture and defender rules |
| `17-economy-market-and-trading.md` | Currency, island sinks, sales, anti-progression bypass, profitable non-PvP economy |
| `18-ui-controls-accessibility.md` | Desktop/touch/gamepad, menus, hover/tap, compact HUD, status and trait visibility |
| `19-save-data-network-and-security.md` | Character IDs, home migration, items/vault, authority, market, raid anti-exploits |
| `20-monetization-and-live-operations.md` | Fair cosmetics, identity/account, anti-pay-to-win, analytics, live balancing |
| [22-dinosaur-mass-armor-and-grappling.md](22-dinosaur-mass-armor-and-grappling.md) | Natural mass, footprint trample, relative-size pins, raptor Pounce/Maul, dinosaur armor/barding/load, armored Brontosaurus |
| `21-tutorial-missions-and-progression-tests.md` | Teaching systems, levels 1-60, first tame, island upgrade, optional PvPvE teaching |

| [23-weapons-and-material-crafting-progression.md](23-weapons-and-material-crafting-progression.md) | 18 six-class weapon recipes, grounded biome/butchery ingredients, copper/iron metallurgy and explicit missing-content backlog |

## Format for each future chapter

1. **Status and owner decisions** with date; purpose/non-goals.
2. **Player fantasy and concrete playable example.**
3. **Rules and invariants:** exact applicability and restrictions.
4. **Progression/unlocks/costs** (mark sample numbers as provisional).
5. **State machine, data contracts and item/character ownership.**
6. **UX:** desktop and touch states, tooltips, error messages.
7. **Economy and exploit constraints.**
8. **Save migration, failure/recovery, offline and multiplayer rules.**
9. **Test acceptance scenarios** for ordinary/edge/abuse cases.
10. **Remaining owner questions** and explicit alternatives.

## Execution order for design, not feature implementation

1. Lock **character level/account unlock/home migration**. These underpin access, item progression and saves.
2. Lock **PvPvE opt-in and irreversible loss/capture**. These underpin whether the permanent tribe fantasy is sustainable.
3. Lock **material and crafting quality**. These underpin equipment value, blueprint construction and economic pricing.
4. Lock **tribe identity, offspring and automation**. These underpin body switching, workers, mounts and raids.
5. Lock **tech, UX, monetization and acceptance plans** only after the above economic invariants are clear.

The current code and historical documents remain untouched until the user approves design chapters and requests implementation.
