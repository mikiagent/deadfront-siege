# DEADFRONT: local alphas, fair territorial PvP and costly sieges

**Status:** Workshop draft, 2026-10-25. Confirmed owner intent and proposals are explicitly distinguished. This document is for **design only**, not permission to implement or proof that multiplayer exists.
**Read with:** [Protected home and cargo rules](safe-home-expeditions-offspring-and-identity.md), [Tribe, Lineage, Domain and Labor](tribe-lineage-domain-and-labor.md), [World Design](world-design.md), and [Orchestration Plan](../orchestration/plan.md).
**Authoritative multiplayer requirement:** PvP attack eligibility, siege scheduling, item ownership, manifest transfers, casualty outcomes and loot must eventually be enforced by an authoritative server. The current Godot solo-first client cannot make fair or secure PvP guarantees.

## 1. Design intent and confirmed boundaries

**CONFIRMED FROM OWNER:**
- Strong and weak are **relative to the environment**. The world should contain **local alphas**: players or tribes who have become meaningfully powerful in a particular region, while still encountering equal or greater challenges elsewhere.
- Introduce **anti-punching-down rules**. A highly developed tribe must not be able to repeatedly and cheaply farm much weaker opponents simply because its gear, high-level bred characters, infrastructure, and material wealth are vastly superior.
- Raiding must be **difficult, costly and risky**, but sometimes **worth attempting** for a capable, prepared attacker.
- A well-prepared defender should have a **realistic and often strong chance to win**, rather than requiring both sides to be equal in raw power.
- Every player's private **home island remains unraidable**. Only voluntarily established settlements in **contested PvE or PvPvE territory** are attacked. Humans and dinosaurs assigned to dangerous settlements can die permanently.
- An attacked remote base, its extraction sites, warehouses, and staged goods are **absolutely raidable** subject to zone rules.
- **Transport boats may depart even during an active raid.** Once a boat has **actually departed on its voyage toward the protected home island**, the boat, crew, and cargo are **not attackable or interceptable**. Any remaining goods, workers and buildings at the remote base stay exposed.
- **Boat and harbor level and their special traits limit how much cargo can be evacuated per voyage.** Creating a shipment order is not equivalent to loading/departure. The quantity and logistics throughput matter in a siege.

**Unsettled:** precise matchmaking formula, zone boundaries, PvP windows/offline risk, attacker stake and defender loot, percentage of available resources that can be taken, structural destruction and reoccupation, mechanics for declaring a siege, allied attackers, frequency/cooldowns and scope of population deaths.

## 2. Local alphas: regional dominance, not global invincibility

**Proposed mechanic: Regional power leagues.** Contestable regions belong to *progression brackets* or **frontier weight classes** broadly aligned with achievable survivor level, tier of material, available siege engines and strength of domesticated creatures. Examples, **not finalized labels/numbers**:

| Example region | Expected progression | Power experience |
|---|---|---|
| Stone Frontier | Early levels and stone/bone-era loadouts | A developed local tribe feels formidable here |
| Flint Marches | Experienced survivors, flint/obsidian and better trained mounts | Former alphas meet comparable rivals |
| Metal Borderlands | Strong lineage, advanced forged gear, fortification | Defenders and attackers can field specialized groups |
| High Frontier | Endgame breeds, siege engines, well-developed tribes | The same characters are no longer dominant by default |

**Regional dominance should be earned and visible.** Within a league, a player can be genuinely stronger through lineage, superior trait-rolled materials, skilled production, training, fortifications and better tactics. Do **not** flatten everyone into identical standardized stats. A recognizable local alpha should inspire admiration and provide a valuable aspirational target. They should not automatically lose their eligibility to remain in the league simply because they win.

**Anti-stomp enforcement:**
1. **A regional ceiling on offensive power**: entering a lower-tier PvP contest either downscales disallowed excess in a legible way or refuses over-tier humans/gear/dinosaurs/siege equipment. This is stronger protection than character-level-only gating, because a low-level child can wield outstanding equipment with remarkable inherited genetics and veteran backup.
2. **Raid class includes the whole attacker deployment**, not just the currently played avatar: companion humans, dinosaurs, mounted pairs, equipment, trait bonuses, level, permanent lineage potential currently expressed, consumables, siege tech, and any participating allied tribes. Evaluate the live raid manifest before and during combat; block gear-swapping or bringing in unregistered high-tier reinforcements.
3. **Match target entitlement to a declared domain class**, not a trivially manipulable garrison snapshot. The defender's zone/license/structural tier and persistent combat capacity establish its class, with protection against temporarily dismissing guards or unequipping gear to feign weakness.
4. **No profitable repeat farming**: a successful attack creates a temporary **siege recovery/protection interval**, and eligible rewards taper for attempts against the same repeatedly weakened target. Avoid making newcomers lucrative, perennial loot piñatas.
5. **No attack through proxies**: new alternate accounts, substitute low-level riders, low-tier disposable allies and guild coalitions cannot secretly route a top-tier army into a protected bracket. Detection and account-linked eligibility requirements will need an actual anti-abuse policy.

**Important tradeoff:** A giant player can still visit lower zones, but their **PvP attack capability** obeys that region's rules. The system should not punish PvE social play, ordinary travel or routine low-level resource gathering unnecessarily.

## 3. The raid should be a siege, not an instant inventory robbery

**Proposed four-phase loop:**

**A. Reconnaissance and choice**
- Identify a *PvPvE contested settlement*, its weight class, visible approximate fortification tier, and proposed attacker raid cost.
- Give the attacker reasons to attack a strong, valuable rival or lucrative high-tier extractor, not an undefended beginner shack. Rewards scale with **defended exposed value and rival tier**, not merely the weakest base found.
- Show the defender a comprehensible danger level and fortification vulnerabilities, while concealing selected tactical details so scouts matter.

**B. Commit resources and disclose risk**
- Attacker invests consumable **siege supplies** (explosives/ram/temporary field camp/transport equipment as appropriate for world tier), incurs preparation cost, and places its own humans, gear and dinosaurs at risk. A declared siege cannot be spammed for free.
- Recommend a server-controlled **raid bond/stake** paid at the start, with a portion going to successful defenders. Exact amount/currency and whether attacker equipment is already sufficient at-risk stake are OPEN.
- If the PvP system uses declaration/warning windows, the attacker cannot immediately start killing workers after a single hidden click.

**C. Tactical assault and live evacuation**
- Attacker must get past outer defenses, traps, chokepoints, guard AI, mounted patrols and active players to reach **contested** stockpiles and possibly a domain capture objective. Defense is inherently advantaged because it has prepared ground and fixed infrastructure.
- Defender may dispatch/launch cargo boats **during the siege**. Workers must load **real, finite** goods into a manifest; **boat level, harbor level and their special traits cap voyage capacity and/or throughput**. Valuable trait-bearing cargo remains vulnerable until the boat is actually underway. Once a ship departs **homeward**, it and its crew/cargo are invulnerable to combat throughout transit.
- A siege may interrupt loading by attacking contested dock workers, disabling exposed production/harbor facilities or occupying the access route, but **must not** directly cancel, intercept or sink a departed homebound vessel.
- The defender can decide whether to evacuate an irreplaceable breeding material or stand and defend it. Attackers can try to reach the warehouses/dock first.
- Ensure no bulk instant-loading exploit: goods require time, capacity and real reservations; a one-click "send all" operation cannot mark 100% of stock safe in a frame.

**D. Resolution, rewards and recovery**
- Attacker wins a **specific siege objective** such as taking a stockpile, holding an exposed control point, or demolishing a particular contested facility. Do not assume a victory automatically destroys the entire settlement or wipes every human.
- Loot is constrained by **exposed contested goods**, region league and raid objective/limits. Never raid protected home assets or goods already shipped home.
- Successful defense should offer meaningful **defender rewards**: recovered siege supplies, captured attack gear, reputation/prestige, settlement stability, and raid cooldown/protection, with reward quantities OPEN.
- A raid has a definite end, retreat rules, and cooldowns, so players cannot be griefed by continuous siege chaining.
- Allow expensive siege assaults to be **net losses to attackers** if they choose a well-defended target or attack badly.

## 4. Defense is achievable, but never automatic

**Suggested defender advantages:**
- Fortifications and traps grant meaningful environment control, not generic HP multiplication.
- NPC workers/guards and selected dinosaurs can execute configurable defense orders, with trained human/dinosaur rider pairs performing coordinated mounted defense, and unmounted animals providing species-specific counters.
- Defensive **healers, cooks, teachers and pharmacists** matter: medicine, stamina, prepared food/buffs, medical stations and training make a town more resilient.
- **Local intelligence** provides raid warnings, scouting, fallback rally points, defensive patrols and alarm permissions.
- The attacker has logistics constraints: finite siege supply, troop/party budget, attack time, territory restrictions and genuine risk of human/animal permanent death. The defenders have their prebuilt logistics and fortifications.
- Successful players can feel like **local alphas** by maintaining an impressive, defended frontier domain, rather than simply having inflated characters.

**Proposed balancing objective, not settled:** When attack and defense are in the same bracket, a prepared defender with adequate garrison, supplies and sensible fortification should generally be favored over an equivalently prepared attacker. More skilled or specialized raiders must still be able to win by choosing the right objective, scouting, timing and equipment. A **70% prepared-defense win rate** is an example experimental tuning goal, NOT a mandated target; refine through trials and metrics.

**Anti-exploit:** Avoid infinitely repairing walls during combat, invulnerable harbor structures that make siege impossible, unbounded defenders supplied via safe-home teleport, unlimited attackers reinforcing from other brackets, and automatic all-cargo evacuation immediately after raid declaration.

## 5. Weight class must resist power laundering

**Level-only gates are too weak.** A newly adopted level-1 adult could have powerful heritable stats, a master's forged crossbow, mounted high-level dinosaurs, veteran human companions, elaborate fortifications and enormous wealth. Build a *transparent effective power budget* rather than evaluating only the current avatar's level.

**Proposed player-facing two-part system:**
- **Frontier Class**: the maximum permissible tier of personnel, mounted pairs, gear, consumables and siege resources deployed **offensively** in a given region. Equipment/characters above tier can either be normalized to the regional maximum (the simpler social-play experience, but harder to implement fairly) or disallowed from PvP entry (easier to reason about, but less friendly). This is OPEN.
- **Raid Rating**: roughly expected power of a **specific attacking roster and siege loadout** with actual counts and synergies. Eligible targets are from the same frontier class and a nearby rating band; allied attackers are counted together. Defender-side class comes from persistent domain tier/license and defended infrastructure, not just people currently present.

Do not tie matchmaking to nominal level alone or solely to a defender's stored loot. A highly optimized breeder / powerful settlement should feel strong in its intended league without having access to stomping brand-new settlements for free. Conversely, a deliberately lightly equipped elite may choose an honest lower-tier contest within the zone's hard cap; that player's knowledge/tactics can still outperform locals, but high wealth has much less direct effect and raid rewards scale to actual challenge.

## 6. Offline raid options requiring a real product decision

**Option A, preferred for early PvP:** **Defender-declared raid vulnerability windows** with a notice period; actual PvP sieges can happen only during selected windows, at a minimum number per week. Outside windows the contested territory may still face ordinary non-siege PvE hazards, but no surprise complete PvP dismantling of a base while the owner sleeps. To avoid invulnerability abuse, players cannot freely cancel windows after an attacker legitimately commits.

**Option B:** Persistent raiding, but an automated defense AI protects the camp when the owner is absent, with strict loot caps and no permanent destruction of their entire remote settlement offline. Hard to balance with permadeath and high genetic investment.

**Option C:** PvP domains always exposed but attacks require substantial in-game scouting, warning, and real-time siege progression (including when offline). This has stronger persistent-world fantasy but very high grief/retention risk.

**Decision needed:** The user has not yet selected a raid schedule or offline policy. **Do not silently select Option A as binding.** PvE raids may have separate telegraphed rules.

## 7. Anti-punching-down guardrails and outcomes

| Abusive scenario | Required defense in design |
|---|---|
| Level-60 tribe assaults level-5 starter frontier | Frontier class and equipment/party ceiling; ineligible raid if mismatch |
| Level-1 descendant uses mythical crossbow and max-stat T. rex | Count gear, genes, companion stats and mount in raid class |
| Big clan sends 10 weak accounts against solo settler | Alliance and total raid budget; participation registration and caps |
| Attacker farms same weak outpost daily | Target recovery cooldown and declining repeat rewards |
| Defender hides troops to qualify for beginner matchmaking | Rate persistent domain class and historical peak/authorized capacity |
| Defender moves full warehouse to pending cargo to escape in 1 click | Only *actually loaded and departed*, capacity-limited shipment is protected |
| Raider attacks home storage instead of risky outpost | Private home always attack-proof |
| Successful raider loses nothing after failed attack | Meaningful siege consumables, equipment exposure, individual death and/or stake |
| Defenders cannot possibly win despite preparation | Defensive terrain, NPC guards, consumable supplies, raid time limit and fair class |
| High-tier veteran is excellent in their region | **Allow local alpha status**; fame and mastery are rewards, not reasons for forced eviction |

## 8. First player-visible tests and measurement

1. A high-tier tribe with mythic equipment is prevented from using its true power against a very low class outpost, even when controlling a level-1 descendant.
2. A player in a frontier class can become noticeably stronger than other peers through skill, genetics, crafted trait gear and defense planning without trivializing all opponents.
3. A raider attempting a same-class siege must risk valuable resources or fighters and pass concrete attack objectives; defenders can repel it with prepared tactics.
4. Two invaders together cannot exceed the league's raid army budget by splitting across accounts/guilds or swapping gear midfight.
5. Two vulnerable warehouses hold rare ore when siege begins. The defender starts evacuation; the boat's **boat+harbor level and traits** cap cargo. Raid pressure can capture goods not yet loaded/departed. A ship that leaves while the battle is ongoing cannot be attacked in transit.
6. All remaining at-risk residents/dinosaurs can defend; casualties are persistent. The safe-home roster and all safe-home stock remain unchanged.
7. A successful defense creates a meaningful reward/cooldown, and attackers cannot immediately repeat the same raid as a profitable grief tactic.
8. Simulate solo vs solo, veteran vs beginner, multiple attackers vs a solo defender, optimized lineage vs average genetics, online vs offline with clear telemetry: attack success by class and power ratio, human/dino losses, defender retention, voluntary frontier adoption, resource profit/loss, and frequency of repeat targeting.

## 9. Priority decisions for the next owner discussion

1. **Where does the power-class restriction live?** Would you rather bracket **territories themselves** (Stone/Flint/Metal frontier, with combat caps inside each) or match **each raid by involved tribes' true army power**, while any tribe may settle any region? A hybrid can use both.
2. **When may PvP raiding happen?** Selected vulnerability windows / announced siege appointments, persistent attacks with strong NPC auto-defense, or a hybrid? Can rare bred humans/dinosaurs die during an offline raid?
3. **What can winning attackers actually take?** Primarily **exposed stockpiles**, or also special building parts, a temporary tax, or even the contested territory claim? Should there be a maximum-per-raid loss cap?
4. **What does the failed attacker lose?** Consumable siege supplies only; combat casualties/gear; a stake transferred to defenders; or some combination?
5. **How many people can raid?** One avatar plus three mixed Expedition slots per side, a larger declared siege force using home worker garrisons, or group/guild warfare? How are attackers with different tribe strengths pooled?
6. **When does a boat become protected?** Current proposed precise boundary: after physical loading and confirmed departure, even if battle is ongoing; before that the dock/warehouse/loading workers are vulnerable. Are dock departure cooldowns/physical queue desirable, or should every ready boat be able to depart immediately?
7. **What is a local alpha's reward?** Prestige, political influence, rare wanderer interest, better economic output, an optional bounty, or better chances to attract rival challenges? Avoid giving compounding raw combat damage that worsens regional monopolies.

**Suggested workshop order:** Start with regional class approach, siege scheduling/offline deaths, and tangible raid loot limits. These define whether players can safely choose PvP, how quickly they can be wiped, and whether becoming a local alpha is enjoyable for everyone.
