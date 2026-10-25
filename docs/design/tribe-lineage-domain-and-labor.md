# DEADFRONT: tribe, lineage, domains, labor and mounted expedition design

**Status:** Owner-approved **direction** from 2026-10-25, with explicit **OPEN** mechanics. This is a future-gameplay specification, **not a claim of implementation or balance lock**.
**Related:** [Systems vision / material traits / crafting](2026-10-25-systems-vision-and-open-decisions.md), [world design](world-design.md), [skills](skills.md), [economy](economy.md), [orchestration plan](../orchestration/plan.md).
**Supersedes:** The earlier suggestion that a successor resets the existing playable character, base, gear, tribe, technology or account progress. **No existing character or world state is reset when control transfers.** The *new* person starts with their own personal low level and learns skills normally.

## 1. The experience we are making

**Core fantasy:** An individual survivor is temporary; the tribe is the player-built continuity. Domains attract danger and opportunity. Collect, train and selectively breed people and dinosaurs with distinctive heritable strengths; spend expensive resources raising exceptional descendants; accumulate master artisans and capable defenders; choose which tribe member to personally play. Valuable members can die. If the human tribe is wiped out, the player can restart personally as a default, mediocre survivor rather than losing the entire account.

**Three independent progression axes:**
1. **Civilization:** persistent base, domains, infrastructure, work sites, production knowledge, storage, gear, dinosaurs, and surviving tribe members.
2. **Individual career:** each human's personal XP, level, trainable skills, profession, equipment, fatigue and memories of their earned work. A played former survivor retains all of this when reassigned to base labor.
3. **Heritable potential:** individual genetics/aptitudes for humans and dinosaurs, selected over generations through expensive reproduction and breeding. Potential is **not** the same as freely inherited personal XP or fully developed proficiency.

**Player motivation:** Your current skilled craftsperson can become an extraordinary permanent base artisan. You then play their next-generation descendant, who initially lacks experience but may have better potential. No prestige button deletes the previous survivor's work or career. Different people can fulfill different economic and combat roles.

**Terminology:** Use **lineage / genetic selection / selective breeding** for fictional game mechanics, rather than using the real-world term *eugenics* as a user-facing game label. Human characters are distinct people with careers and agency; the fiction should not celebrate real-world coercive practices. Specific reproductive relationship rules remain open.

## 2. Domain pressure: raiders and exiled wanderers

**CONFIRMED:** A tribe's domain located in PvE and/or PvP zones attracts **hostile raiders** and **exiled wanderers** seeking admission. Territorial expansion brings both risk and recruitment opportunity.

**Suggested loop:**
- Claim/build a domain in an applicable zone; accumulate production, inhabitants, visible wealth and strategic significance.
- Create **domain attention** (a pressure/opportunity stat). A rising signal may increase raider interest and wanderer arrivals. This is a proposed mechanic to make the owner's direction legible, not a decided formula.
- Warn the player about expected threats with readable scouting/defense signals before permanent-member-loss encounters. Fortifications, combat-ready members, defensive dinosaurs and supply chains matter.
- Wanderers have individual starting aptitudes and skills, optional needs, and clear housing/upkeep requirements. Accepting one creates a true tribe member, not a free collectible. Declining should remain possible.
- PvE raids can eventually run in a single-player simulation. Genuine PvP raids and ownership require a future authoritative multiplayer server; do not present scripted NPC raiders as multiplayer.
- A domain outside protected starting territory can be damaged or captured under zone rules once defined. Death and asset-loss policies need to be explicit and fair.

**CONFIRMED (owner correction, 2026-10-25):** Every player has a permanent, **unraidable private home island** where workers, dinosaurs, infrastructure and stockpiled materials can be kept safe. PvE and PvPvE danger belongs only to voluntarily built settlements and deployments **outside** that island. Contested settlements create reward and liability; the private home never becomes raidable by attaining wealth. **OPEN:** raid triggers and timing, offline attacks in contested areas, warning periods, and what attackers may destroy/steal outside home. See [protected-home, cargo, upbringing, and identity design](safe-home-expeditions-offspring-and-identity.md). Should wanderer arrivals correlate with domain prestige, available housing, fame, or rescue actions?


### Home-to-frontier cargo logistics (owner idea, pending mechanics)

A protected home storage island should accept materials gathered in every region. Transport workers assigned to boats/routes may ferry tagged material lots from vulnerable outposts to safe home storage. Keep real manifests, reserved stack IDs and provenance; unloading at home ends exposure to territory raids. **OPEN:** whether ships themselves can be attacked, how route transit is shown, escorts and offline timing. The marine supply loop is described in [protected-home, cargo, upbringing, and identity design](safe-home-expeditions-offspring-and-identity.md).

## 3. Tribe roster, roles, population and durable identity

**CONFIRMED:**
- Human **Tribe** and dinosaur **Creatures** are separate owned populations and screens/data stores.
- All humans remain persistent individuals who may serve as active playable survivor, deployed companion, base worker, crafter, or a candidate for parenthood.
- Tribe members and owned dinosaurs can die permanently in PvE or PvP combat.
- Population is constrained by *what the player has built and supports*: houses, facilities, materials, food and other infrastructure, not just an arbitrary roster purchase.

**Proposed simulation:**
- Person = unique persistent ID + family graph + inheritable genotype + developed level/skills + equipment + health/needs + AI job/party state.
- Housing grants supported residential capacity. Further infrastructure may gate breeding, childcare, food distribution, occupations, medical care, defense, and the next population tier. Avoid a purely linear beds-equal-people formula if it trivializes late-game growth.
- A human cannot simultaneously be an expedition unit and base worker; assigning one role suspends the other. Their carried equipment, inventory and skills follow the person, not the player-control camera.
- Over capacity should not silently kill or delete people. Agree on a clear grace/penalty rule before design lock.
- Use distinct UI layers: **Expedition** (active 3 slots), **Tribe** (human roster, jobs, family), **Creatures** (dinosaur roster, genetics, care).
- Abilities should derive from human profession and real equipment; a high-skill crafter should remain valuable when reassigned to a station.

**OPEN:** Recruitment rules, residence limits, construction/upkeep costs, whether unassigned members rest/defend/idle, offscreen persistence, death recovery or revival exceptions, morale and settlement allegiance.

## 4. Human reproduction, raising and generational transfer

**CONFIRMED:**
- Human reproduction and child-raising is **materially expensive and taxing even at endgame**. It is a considered strategic investment, not a passive rapid population fountain.
- Descendants inherit innate strengths and weaknesses from parents; the new body has **low personal level and undeveloped skills**.
- The player may choose to control a new adult tribe member. The previously controlled character keeps their personal levels, skills and physical equipment and can be reassigned to base jobs. No civilization, personal career, discovery, building, or inventory state is erased just because control changes.
- Personal control can transfer between living eligible human tribe members; succession is not forced retirement/new-game reset.

**Recommended inherit-vs-earn distinction (not yet formula locked):**
- **Inherited:** genes, stat potential/ranges, growth rates, physical strengths, weaknesses, and limited trait combinations from parents.
- **Earned per person:** profession and crafting skills, XP, player level, technique unlocks tied to the individual's training, and learned combat proficiency.
- **Shared tribe state:** buildings, researched designs/knowledge where explicitly tribe-wide, storage, assets, cultural discoveries, population and territory.
- **Equipment:** actual possessions remain with their owner, but can be transferred through the inventory/station system; adopting a body does not conjure duplicate gear.

**Why this works:** A new low-level descendant is a real fresh character, while the legendary veteran stays alive and may run an automated forge. You can even return to controlling the veteran later, if switching is unrestricted.

**Breeding design (proposed constraints to protect the fantasy):**
- Reproduction requires eligible adult parents and infrastructure, consumes substantial scarce resources, caregiving capacity and time, and imposes opportunity costs on the participating adults and tribe.
- Raising is its own progression: nurture, training, food quality, shelter, education and safety could shape which inherited potentials become realized.
- Genetics should create **spiky** individuals. The chance for truly outstanding multi-stat descendants should be low. Recombination and trade-offs keep excellent parents from trivially yielding perfect offspring.
- Use a bounded inheritance system with sensible soft caps, trade-offs, and mutations; lineage improvement should be important, but not turn PvP into pure birth-stat supremacy with no counterplay.
- Avoid unbounded exponential stats, breeding loops that bypass resource cost, mandatory lengthy idle timers without gameplay, or punishments that make extinction unrecoverable.

**CONFIRMED (owner correction):** Offspring develop automatically on a **timer**, consuming food. **Food quality in successive growth phases influences their final realized stats.** In a youth/young learner phase they can be **educated and trained**; they become playable adults with their own low personal level. **OPEN:** exact timers, food deficits, two-parent/relationship eligibility, mentor slots, whether teen education grants introductory XP, and which genetic potentials are fully visible. See [protected-home, cargo, upbringing, and identity design](safe-home-expeditions-offspring-and-identity.md).


### 2026-10-25 clarification: body type, sex differences and non-exclusive careers

**Owner preferences for the game's population:** Male/female characters should be visibly distinguishable in stature/build, with men tending taller and stronger on average and no default intelligence gap. Men are more likely to excel in strength-demanding heavy labor, craftsmanship and heavy melee; women have an intended average advantage in caretaker/support roles (nursing, medicine, teaching, healing and tribe-wide development). Support specialists must give major measurable benefits to the tribe and its warriors. **Women can be formidable warriors**, especially through bows, crossbows, firearms, good positioning, training and equipment; exceptional female melee specialists and male healers are possible.

**Balance recommendation, NOT a numeric requirement:** Model these as overlapping distributions and trainable skills in the *fictional game simulation*, never sex-locked jobs, blanket female weapon damage penalties or intellectual differences. Genetics, upbringing, education and work experience should dominate the outcome for an individual. Visuals (height, muscle, build) should sometimes suggest strength without serving as a perfect stat scanner: a slim elite archer, tall weak worker or short powerful fighter can surprise the player. Reveal earned current skills and useful qualitative potential hints while keeping some hereditary potential undisclosed until growth or assessment. See [protected-home, cargo, upbringing, and identity design](safe-home-expeditions-offspring-and-identity.md) for detailed acceptance scenarios.

## 5. Dinosaur genetics and combat loss

**CONFIRMED:**
- Wild dinosaurs usually have **uneven/spiky stats within a species- and level-dependent range**, and genuinely exceptional natural individuals are rare.
- Selective breeding of **owned dinosaurs** can produce offspring more capable than ordinary wild-caught animals across generations.
- Tamed dinosaur deaths during PvE/PvP combat are meaningful and can be permanent.
- Preserve the human Tribe as separate from the dinosaur breeding/growth registry, even if reusable genetic and lineage math is shared.

**Suggested rules (OPEN):**
- Each species has its own trait pool and potential distributions. Not every animal should excel at every job; aggressive combat, mounted control, defense, hauling and labor can reward different stat profiles.
- Breeding is an investment with infrastructure, nutrition, incubation/raising time, and risk or maintenance costs. A rare wild specimen can be an important breeding input, not only immediate battle loot.
- Skill and equipment can partly compensate for poor innate combat potential. Better dinosaurs are strategically meaningful, but player knowledge, positioning and gear still matter.
- Make parentage and offspring attributes inspectable; persist genetics and identity. Permit hereditary positives and negatives without unlimited perfect-stat propagation.

**OPEN:** Animal sex/eligibility mechanics, breeding rate/resource budget, mutation and inheritance math, adulthood rate, whether injuries can be treated versus death permanence, and whether human/dino generations share the same timeline.

## 6. Worker economy and self-directed task AI

**CONFIRMED:**
- Build dedicated **mining sites**, **lumbering sites**, and similar processing/gathering infrastructure, in the spirit of Palworld.
- Tribe workers can equip gear like playable humans. Items degrade with use; by default AI workers **stop using a tool at 1 remaining durability** (e.g. 1/250), instead of breaking it through automatic repetitive work.
- Normally workers autonomously select jobs **they are capable of**, weighted toward jobs **they are good at**.
- A placeable **Monitoring Stand** grants player control of which jobs are allowed and their priority, overriding the default task preferences.

**Suggested worker decision loop:**
1. Identify allowed jobs at built sites and workstations, available work orders, permits, food/rest/safety limits, travel and equipment requirements.
2. Filter out jobs the worker cannot perform, jobs paused by Monitoring Stand, unreachable stations and work orders that cannot get inputs.
3. Prefer suitable jobs by aptitudes, trained profession/skill, expected efficiency, current job priority, proximity and needs. Avoid constant job-flipping.
4. Claim a task/reservation, carry finite physical supplies to the station/worksite, perform labor while consuming Energy and gathering real XP, deliver outputs to assigned storage.
5. If tool durability is at or will reach the floor, pause the operation, store/flag the tool for repair, and find an allowed alternative. Do not complete the damaging action and then retroactively undo breakage.
6. If stock is insufficient, job is dangerous, facility is at capacity, or path is blocked, show a concrete idle/blocker reason. Monitoring Stand changes should immediately affect the next safe task selection.

**Infrastructure:** Resource extractors / lumber yards should have zones, production/regeneration rules and input-output logistics; a site is not unlimited free ore or timber. Work sites and crafted blueprints can be stocked by haulers. Equipment improves quality/throughput and can inherit material traits. Worker exhaust/needs should connect to sit, sleep, food and housing.

**OPEN:** Does the 1-durability safety floor also apply to worker combat and gathering risks, or only assigned work? Can players override it? Does a person automatically repair/re-equip from storage? Is there a job cap, and what happens while the player is offline? What is the Monitoring Stand's max scope and authority (per worker, per structure, global)? **CONFIRMED logistics context:** home workers and stores can remain safe, while optional remote deployments expose workers to danger. **PROPOSED:** boat transporters can move real reserved cargo from contested outposts to protected home storage, with exact route vulnerability still open. See [protected-home, cargo, upbringing, and identity design](safe-home-expeditions-offspring-and-identity.md).

## 7. Expedition slots: human, dinosaur, mounted pair

**CONFIRMED:**
- There are **three active expedition companion slots** shared by humans, dinosaurs and human+dinosaur mounted pairs.
- A **human rider + one dinosaur consumes ONE slot**, a composite deployment unit.
- The mounted combination is **not** the full independent combat output of both creatures added together. The owner's heuristic is **1+1 feels ~1.5**, not 3; this is a design goal, **not a fixed damage multiplier**.
- Unmounted dinosaurs should use their species-typical, relatively less coordinated behavior: a large predator might behave as an aggressive berserker; a charger rams; defensive herbivores buck, tackle or tail-swipe.
- A mounted human improves pathfinding, tactical intelligence and coordination, and may use mounted weapons such as spears. Mounting shifts the pair toward **rider-led attack patterns**, with fewer purely dinosaur-style actions. This trades brute/animal behavior for controlled movement, positioning and timing.

**Proposed slot record:** `{slot_id, occupant_kind: human|dinosaur|mounted_pair, human_id?, dinosaur_id?, role, command_state}`. A composite pair remains two owned entities with independent genetics, gear, health and death states, represented as one party slot. The current player avatar is conceptually distinct from the three *companion* slots unless changed by explicit decision.

**AI and combat contract:** A mounted pair is one tactical agent for navigation/target commands and group formation but two health/damage components. Balance around loss of autonomous attack frequency, limited weapon arcs, rider vulnerability and mounted skill. Do not just multiply stats. Test rider dismount, rider KO/death, dinosaur KO/death, combat aggro, status effects, pathing, no duplicate party slot and save/load.

**OPEN:** If rider dies but dinosaur survives, does the dinosaur remain on the expedition as one slot, flee, or auto-return home? Is a human without a mount a combat-capable follower? Can the current player ride an animal without occupying a companion slot? Which mounts permit spears vs ranged weapons? How do rider-controlled T. rex animations/attacks work?

## 8. Resource quality and targeted trait discovery

**CONFIRMED:** Trait rolls are central to **durable investments**, especially a new main crossbow, high-tier tools and long-lived buildings. Food and consumables should have effects, but their value is usually immediate and much less worthy of min/max scrutiny. A material's *level* and traits both affect its long-term usefulness.

**CONFIRMED:** Very rare treasure items can **bias the player's gathering rolls toward a named beneficial trait**, e.g. a `[beneficial trait] charm` advertising a **+20% chance** to find that target trait.

**Recommended design:**
- Make weapon/tool/structure trait contributions substantial: damage, handling speed, durability, weight, structure strength, repair cost, temperature and work throughput, as appropriate for the material.
- Foods mostly magnify, modify or alter existing potion/buff effects, stamina relief or duration rather than introducing massive lasting stat changes. Simple edibles should stay quick to inspect and consume.
- Provide a **trait targeted-loot progression**: unlock/obtain rare charm -> configure desired positive trait -> pursue eligible materials -> process/craft premium permanent item. Show real eligible sources, current chance, charm effect and resulting probabilities.
- Negative traits remain frequent and impactful. For durable items, top-tier inputs with exceptional positive traits are a genuine resource-hunting goal, not purely color grades.
- Charms may need caps and eligibility filters. **+20%** is ambiguous: **relative multiplier** (`p -> 1.2p`) versus **20 percentage points** (`p -> p+0.20`). Do not lock one without asking the owner.

**OPEN:** trait roll rates and weighting by item category; whether traits on one-use items can be simplified; charm stacking, duration, tradeability and PvP loss; whether worksite structures preserve ingredient-specific traits; balance vs crafted-item level.

## 9. Survival of a tribe wipe

**CONFIRMED:** If all playable/owned humans die, the player resumes as a **new default baseline survivor** with low-to-middling innate stats. This safety net prevents permanent account deletion.

**To formalize (OPEN):**
- A living tribe member is eligible to become the player avatar; transfer does not reset world or character records.
- On last-human death, create a fresh baseline survivor. It starts personally low-level and underpowered, allowing eventual rebuilding of strong lineages.
- **CONFIRMED:** The private home island and any people/items/structures/creatures remaining there are outside enemy-raid and PvP danger. **PROPOSED** as the consistent wipe fallback: respawn the baseline survivor at protected home with its surviving stockpile, buildings and livestock intact. **OPEN:** how external PvE/PvPvE claims, gear carried by the dead, and property rights transfer after the wipe.
- Determine what happens in PvP if a raid destroys the last active member, to prevent protected-respawn abuse or instant return to a besieged base.
- Unowned wanderers and other options may accelerate rebuilding, but the fallback must function even if the island has no resources.

## 10. Dependency-driven delivery roadmap

| Stage | Design / deliverable | Dependencies and proof |
|---|---|---|
| D0 | Lock contested-zone loss policy, timed food-dependent growth rates, genetic visibility, PvE/PvPvE cargo-route danger and party edge cases | **Home-island permanent safety is already settled**; actual PvP remains conceptual until authoritative networking |
| D1 | Persistent human ID/Tribe registry, separable avatar controller, death + baseline survivor fallback | Save migration and switching lab; prior avatars remain valid workers |
| D2 | Housing and settlement support cap, wanderer recruitment and domain attention in PvE | No deadlocked population; meaningful alerts and housing limits |
| D3 | Worker job reservations, mining/lumber sites, equip/durability safety, Monitoring Stand | No resource duplication, valid pathing, worker skill use |
| D4 | Generalized Expedition slots, species/rider AI split, mounted combat | 1 composite slot; 2 identities; visibly distinct combat patterns |
| D5 | Human and dinosaur genotype/phenotype records, pedigree and offspring simulation | Bounded improvements; signed inherited downsides; deterministic tests |
| D6 | Resource-heavy breeding and childhood/training systems, playable successor transfer | High opportunity cost; all world and previous-human careers persist |
| D7 | PvP domains/raids with server-authoritative ownership if multiplayer is pursued | Fair warning, persistence, anti-exploit and recovery policies |

The owner may reorder stages. No system should be marked shipped before targeted labs, UI tests, save migration and exact release verification.

## 11. Prototype acceptance stories

1. Train Survivor A in smithing; switch to descendant B; A's level, skills, and equipment are still present, and A can craft independently at the forge. B is personally low level, but the domain and knowledge remain.
2. Accept a strong wandering specialist only after building/upgrading enough housing; use that person as a miner. More production increases pressure and attracts future risk/opportunity.
3. Two comparable wild dinosaurs have markedly different innate stat spikes. Long-term selective breeding can yield an offspring with better relevant potential than ordinary wild catches, while still carrying trade-offs.
4. Assign a worker with a 250-durability tool to repeated lumbering. The tool reaches 1 durability and the worker pauses instead of using/breaking it; a Monitoring Stand order changes the worker's priority.
5. Place human H on dinosaur D in slot #1. The party has 1 occupied slot (not two); mounted H+D navigates and attacks coherently with rider-compatible weapons, while unmounted D uses its own species-style combat logic.
6. A raid kills a human/dinosaur permanently and their absence affects the tribe/production/party; death does not clone their gear, genes or XP.
7. When the last human dies, the player receives a fresh mediocre default playable survivor, while world-ownership effects follow the explicitly agreed wipe policy.
8. Gather with a targeted beneficial-trait charm; the tooltip provides a mathematically accurate modified chance. Long-lived gear made with exceptional material is measurably different; a simple consumable remains low-friction.

## 12. Decisions requiring the next owner answers

1. **Territory risk:** Home is **always safe and never raidable**. How much can be lost in **optional contested** PvE/PvPvE outposts, and can boat cargo/crews be ambushed along a sea route?
2. **Reproduction and raising:** Timed, food-dependent maturation and youth education are **confirmed**. What is the full timer, how do food quality/mentors change *realized* stats, and what resource cost keeps reproduction expensive at endgame?
3. **Genetics and looks:** How visible are hereditary abilities, and how do height/musculature and adult appearance correlate without perfectly revealing potential? How strong can lineages become while allowing training/gear and ranged tactics to compete?
4. **Wipe persistence:** Safe-home assets remain protected; which **contested claims and outpost possessions** survive a full wipe, and what happens to the lost member's carried equipment?
5. **Automation:** offline work, tool safety in combat, allowed autonomous repair, monitoring stand scope and override semantics.
6. **Companions:** fate of a mount after rider death, slot behavior after dismount and whether the playable survivor's personal mount counts.
7. **Trait charms:** whether "+20%" means relative probability or +20 percentage points, how charms are acquired, and whether they stack.
