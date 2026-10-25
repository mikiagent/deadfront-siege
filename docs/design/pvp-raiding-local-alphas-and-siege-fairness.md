# DEADFRONT: local alphas, fair territorial PvP and costly sieges

**Status:** Workshop draft, 2026-10-25. Confirmed owner intent and proposals are explicitly distinguished. This document is for **design only**, not permission to implement or proof that multiplayer exists.
**Read with:** [Protected home and cargo rules](safe-home-expeditions-offspring-and-identity.md), [Tribe, Lineage, Domain and Labor](tribe-lineage-domain-and-labor.md), [World Design](world-design.md), and [Orchestration Plan](../orchestration/plan.md).
**Authoritative multiplayer requirement:** PvP attack eligibility, siege scheduling, item ownership, manifest transfers, casualty outcomes and loot must eventually be enforced by an authoritative server. The current Godot solo-first client cannot make fair or secure PvP guarantees.

**2026-10-25 owner clarification, superseding any broad island-raid wording:** **Islands are not raided as landmasses.** Only *built PvPvE settlements* can be raided by players. **PvE settlements** can be attacked by dinosaurs/animals, not by players. Unstable islands periodically reset resources and automatically dismantle any base placed there into the special Ender Chest-style material recovery box. **Captive ransom is now confirmed:** seized humans/dinosaurs enter prisoner status with a ransom deadline; paying on time returns them, but nonpayment lets the attacker acquire/claim them. It is **not yet decided** how long the defender has, how ransom is priced, whether the attacker manually claims, or when the prisoner becomes an effective loyal worker/mount. See [canonical world chapter](../game-design/04-world-biomes-and-travel.md) and [ransom design](../game-design/16-pvp-frontier-siege-and-captives.md).

**Confirmed ransom economics, 2026-10-25:** For a captured human/dinosaur, the game computes a ransom price and the original owner gets **72 real-world hours** to pay. Payment returns the original captive with **level, learned skills, earned EVs, and inherited IVs preserved**. On nonpayment the attacking player may acquire them but receives **inherited IV genetic potential only as an advancement asset**: the new owner must **recruit, re-level and retrain EVs/skills**. This avoids raids cheaply transferring expert trained labor or master fighters. The ransom formula and claim/notification rules remain open. [Canonical prisoner chapter](../game-design/16-pvp-frontier-siege-and-captives.md).

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

**Confirmed additional owner direction (2026-10-25):** The world loop is **Skyblock-like protected island economy + Durango exploration/crafting + ARK dinosaur and lineage progression**. Owners may **buy larger private islands for a hefty in-game price**. PvPvE access **requires a personally achieved level-60 island unlock** (rule confirmed; unlock behavior after switching playable body OPEN), and must not become the best way to acquire wealth. Defenders should ideally deploy replaceable laborers, backups and expendable stock to frontier bases while keeping elite humans/dinosaurs/gear safe at home. No owner-selected PvP raid windows or siege appointments. **Candidate raid prizes:** materials recovered by disassembling exposed outpost structures, captured exposed adult humans, captured dinosaurs, unstored/unshipped resources, and equipped items/accessories. Exact capture/salvage/looting rules and power brackets remain OPEN.

**Unsettled:** precise matchmaking formula, zone boundaries, offline raid consequences, attacker stake and rewards, percentage of exposed assets that can be taken, structural salvage/capture, allied attackers, raid frequency/cooldowns and scope of combat deaths. **Declaring a scheduled raid window was explicitly declined by owner.**

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
- **No mandatory declared raid windows/appointments.** An attacker may still require a costly siege permit, preparatory construction, vulnerable muster/deployment, clear siege objectives and telegraphed tactical advance to allow defense. Don't implement a time-of-day vulnerability choice after the owner declined it.

**C. Tactical assault and live evacuation**
- Attacker must get past outer defenses, traps, chokepoints, guard AI, mounted patrols and active players to reach **contested** stockpiles and possibly a domain capture objective. Defense is inherently advantaged because it has prepared ground and fixed infrastructure.
- Defender may dispatch/launch cargo boats **during the siege**. Workers must load **real, finite** goods into a manifest; **boat level, harbor level and their special traits cap voyage capacity and/or throughput**. Valuable trait-bearing cargo remains vulnerable until the boat is actually underway. Once a ship departs **homeward**, it and its crew/cargo are invulnerable to combat throughout transit.
- A siege may interrupt loading by attacking contested dock workers, disabling exposed production/harbor facilities or occupying the access route, but **must not** directly cancel, intercept or sink a departed homebound vessel.
- The defender can decide whether to evacuate an irreplaceable breeding material or stand and defend it. Attackers can try to reach the warehouses/dock first.
- Ensure no bulk instant-loading exploit: goods require time, capacity and real reservations; a one-click "send all" operation cannot mark 100% of stock safe in a frame.

**D. Resolution, rewards and recovery**
- Attacker wins a **specific siege objective** such as taking a stockpile, holding an exposed control point, **capturing an exposed adult human or dinosaur**, or dismantling particular **contested** facilities for recoverable materials. Do not assume a victory automatically destroys every structure or transfers every person. Capturing trained people/bred dinosaurs must be **rare, difficult, costly and limited** to prevent raiding from becoming the fastest bloodline-acquisition strategy; containment, escape/rescue, handling and loyalty are unresolved.
- Loot may include **exposed contested goods not yet shipped home, equipped accessories/weapons, recovered materials from dismantled frontier buildings and captured exposed humans/dinosaurs**. Constrain the obtainable amount by actual raid objectives, siege time/capacity, defender power class and possible loot/capture limits. Never raid protected home assets or goods already shipped home. Owner-approved categories are *possible*, not a mandate for total stripping or guaranteed capturing.
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

## 6. Persistent frontier risk WITHOUT player-declared raid windows

**CONFIRMED: The owner does not want selected vulnerability windows or mutually scheduled siege appointments.** Do not recommend such windows as the default or claim they remain undecided. Risk is a property of the **voluntary frontier PvPvE settlement**, not a calendar appointment. Players who refuse this risk can keep their critical people/creatures/materials on the private home island and progress via Skyblock-like expansion, production, trading, breeding and PvE.

**CONFIRMED PvPvE entry:** the player must **reach level 60 and unlock level-60 islands** before PvPvE access. Exact personal-vs-tribe persistence when controlling a new low-level descendant is OPEN. The owner suggested this but has not settled exact criteria or whether any endgame resources are exclusive to PvP. Joining PvP should remain a deliberate opt-in by placing a contested outpost; regular PvE should stay substantial.

**Open offline policy (not raid windows):**
- **Persistent threats with NPC garrison:** An attacked offline outpost defends itself via assigned guards, prepared traps, walls, mounted units, medical supplies and logistics AI. The live defender may also participate. Simulate honestly, without arbitrary attacker instant-win.
- **Loss protection by outcome, not schedule:** Reduce excessive snowballing with limited recoverable stock, contestable siege objectives, attacker-paid siege permits/cooldowns, and recovery protection **after** an attack. The owner has not approved any exact cap.
- **High-risk option:** True full offline permanent deaths/capture at optional PvPvE outposts might be allowed, but permanent genetic loss without chance to react can damage retention. Keep exact offline character capture/death and claim-destruction rules OPEN.

**Anti-grief scheduling substitute:** Scarce/earned siege charges, substantial material/worker exposure, region-specific attack cost and cooldowns, plus defender loot/reputation on success. These restrict the *attacker's frequency and economics*, not the defender's login schedule. Avoid PvP as the dominant strategy.

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
7. A successful defense creates meaningful recovered supplies/prestige and a post-raid recovery/cooldown, while expensive attack permits/supplies cap farming frequency **without scheduled defender vulnerability windows**.
8. Simulate solo vs solo, veteran vs beginner, multiple attackers vs a solo defender, optimized lineage vs average genetics, online vs offline with clear telemetry: attack success by class and power ratio, human/dino losses, defender retention, voluntary frontier adoption, resource profit/loss, and frequency of repeat targeting.

## 9. Protecting the primary economy from raiding incentives

**Owner priority:** Most expected wealth and long-term progression must come from **protected-home development, larger-island upgrades, production, gathering, crafting, food, research, teaching, selective breeding, and legitimate trade**. Frontier outposts carry replaceable capital, not a mandatory all-in wager. An optimized raider should not have a simple, reliable profit advantage over players who master PvE production.

**Proposed balance levers:**
1. **Expensive attacker-only siege permission/supplies and meaningful casualty risk**, with a finite number of raids per time period but **not** defender-selected raid hours.
2. **Actual stock is the ceiling**: the attacked frontier outpost may contain modest replaceable assets. Never draw from protected-home vaults or steal a family's exceptional safe-home breeders.
3. **Actual salvage, not full reimbursement**: dismantling an exposed base costs time/tool use and yields only salvageable material fractions. No endless recycled building farms.
4. **Human/dinosaur capture is a long and risky extra objective**: elite specimens should usually be kept at home; prisoner handling and animal taming remain separate requirements. A successful raid should not automatically create a loyal high-stat workforce.
5. **Supply exit matters**: the defender can launch level/trait-capacity-limited boats home even while under attack; the attackers can seize only goods not yet shipped.
6. **Avoid market loopholes**: all characters have personal earned-level requirements for effective weapons/equipment, with strict equip gating vs comprehensive stat capping pending decision.
7. **Skill and class checks** include whole attacking group/companions/gear/genes/siege, not simply a level-1 newly adopted descendant.
8. **PvPvE entrance requires level 60 and level-60 island unlock** (CONFIRMED) and remains an optional activity; substantial PvE and protected-island upgrade paths remain competitive. **Strict individual gear-level equip requirements** prevent bought/looted item skips.

A well-defended outpost should be a poor target for an impatient attacker and an impressive local-alpha accomplishment for its owner. Compare **net raid return after casualties/costs** against equivalent production/trading hours in playtest simulations.

## 9. Priority decisions for the next owner discussion

1. **After level-60 entry, where does the power-class restriction live?** Would you rather bracket **territories themselves** (Stone/Flint/Metal frontier, with combat caps inside each) or match **each raid by involved tribes' true army power**, while any tribe may settle any region? A hybrid can use both.
2. **PvP without windows (CONFIRMED):** Persistent exposure applies when a player voluntarily owns a PvPvE outpost. What degree of offline permanent death/capture and NPC garrison resilience should be allowed, and should expensive raid permits/cooldowns control frequency?
3. **Raid loot categories (CONFIRMED):** Exposed resources not homebound, salvaged materials of demolished frontier buildings, equipped weapons/accessories, captured deployed humans and dinosaurs. Should there be quantitative raid/capture limits, allegiance/rescue mechanics, and permission to claim the outpost territory itself?
4. **What does the failed attacker lose?** Consumable siege supplies only; combat casualties/gear; a stake transferred to defenders; or some combination?
5. **How many people can raid?** One avatar plus three mixed Expedition slots per side, a larger declared siege force using home worker garrisons, or group/guild warfare? How are attackers with different tribe strengths pooled?
6. **When does a boat become protected?** Current proposed precise boundary: after physical loading and confirmed departure, even if battle is ongoing; before that the dock/warehouse/loading workers are vulnerable. Are dock departure cooldowns/physical queue desirable, or should every ready boat be able to depart immediately?
7. **What is a local alpha's reward?** Prestige, political influence, rare wanderer interest, better economic output, an optional bounty, or better chances to attract rival challenges? Avoid giving compounding raw combat damage that worsens regional monopolies.

**Suggested workshop order:** Start with optional late-PvP unlock criteria, region/force class limits, persistent/offline raid consequences, and bounded capture/salvage economics. **Do not reopen mandatory defender raid windows without an explicit change of mind.** These define whether players can safely choose PvP, how quickly they can be wiped, and whether becoming a local alpha is enjoyable for everyone.
