# DEADFRONT: protected home, contested domains, cargo logistics, maturation and identity

**Design status:** 2026-10-25 owner-directed refinement. **CONFIRMED** means explicitly requested; **PROPOSED** means a design interpretation to review; **OPEN** means no owner decision yet.
**Companion specifications:** [Tribe, lineage, domains and labor](tribe-lineage-domain-and-labor.md), [systems vision](2026-10-25-systems-vision-and-open-decisions.md), [world design](world-design.md).
**Scope:** Planning only. Nothing here claims implemented AI, boats, online PvP, inheritance, or sex-based balance.

## 1. The fundamental risk bargain

**CONFIRMED: Every player owns a permanent, completely protected private home island by default.** This is the tribe's safe harbor for human workers, raised children, dinosaurs, workstations, gear, buildings, resources and stored loot. It is **not** a raidable settlement, cannot be attacked by hostile PvE enemies or PvP players, and should never force the player to expose workers to combat. Materials gathered or recovered from elsewhere can be stored safely once they reach the home island.

**CONFIRMED: Going beyond the island is an explicit voluntary risk-reward choice.** Players can claim/build additional **contested settlements** in two broad kinds of territory:
- **PvE contested territory:** enemy raiders/environmental threats attack vulnerable outposts; better resource access and production justify defense.
- **PvPvE contested territory:** other players and AI threats can compete over settlements, logistics and resources. Real PvP requires a server-authoritative multiplayer implementation; never fake online opponents in the local game.

**Design principle:** Safe home enables gradual growth for risk-averse players. Contested domains should be lucrative and more efficient, **not a mandatory gate for basic tribe survival**. They reward deliberate investment in guards, defenses, equipment, worker logistics and logistics routes. PvE/PvPvE exposure applies to specific people, goods and structures *assigned to or passing through contested space*, not to every member of the owner's protected tribe.

**PROPOSED tiered reward profile:** home gathers renewable starter-level materials slowly; PvE expeditions/outposts yield higher levels, unusual biomes and rarer trait pools; PvPvE may offer exclusive market opportunities or favorable concentration of scarce endgame inputs. The *exact* access to all late-game resources while playing safely remains OPEN; do not make PvP mandatory by assumption.

**Critical edge cases:**
- Home never becomes raidable due to wealth, prestige, island level, raider attention, or a full tribe wipe.
- Residents who never leave home must not die to hostile raids or player combat. Normal voluntary combat outside home remains risky.
- A worker or dinosaur deliberately dispatched off-island can suffer the danger of that assignment, including permanent combat death in applicable territories.
- Contested outposts may be damaged, looted or destroyed under explicit zone-specific rules. The protected home is separate from them.
- On total human tribe extinction, the default mediocre survivor must respawn at the protected home and can rebuild from home assets; losses suffered in contested settlements remain losses. This is the proposed direct consequence of a genuinely safe private island; owner should still confirm specific survivor/inheritance and claim rules.

## 2. Boats, routes and physical cargo transfer

**CONFIRMED logistics risk rule (2026-10-25):** The remote resource-gathering settlement is **fully raidable** in its applicable contested PvE/PvPvE zone. **A transport boat already in transit toward the protected private home island cannot be raided, intercepted, looted, sunk by attackers, or otherwise attacked during that homeward voyage.** The home island and its stockpiles are also protected. The exact implementation of worker-assigned boat routes, loading and departure timing remains **PROPOSED**; there is no implemented boat system yet.

**Proposed logistics loop:**
1. Discover/unlock harbor access, build docks at home and the raidable settlement, and obtain boats. **The boat's level/traits and the remote harbor's level/traits constrain how much can depart per voyage**, with exact formula not yet set.
2. Assign one or more tribe workers (possible guards/pack dinosaurs later) to a **cargo route**: origin storage/stockpile -> vessel -> destination home storage.
3. Set material/trait/level filters, minimum reserve at source, boat capacity, route frequency and risk tolerance in a logistics/monitoring interface. Never silently take a prized item reserved for crafting.
4. A job claims concrete inventory stacks with unique IDs and reserves them against local consumption and other haulers. Workers physically load the vessel with a real cargo manifest up to the **boat-and-harbor capacity**. Merely reserving items does not protect them from an ongoing raid.
5. From the moment a shipment **successfully departs** the remote dock for the protected home island, its manifest is safe from raids throughout transit. On arrival, unload it into permanently protected home storage. Never duplicate or teleport cargo in the accounting model. Actual travel time, capacity and cost can still matter even though combat interception does not.
6. Log departures, arrivals, delays, losses, assigned crew, material quality, fuel/maintenance where applicable and obstruction reasons.

**LOCKED threat boundary (owner clarified 2026-10-25):** Hostile players/NPCs can raid the **remote settlement, resource sites, warehouses and material stockpiles** according to its PvE/PvPvE zone rules, including materials awaiting loading. **The defender may launch a loaded transport boat even in the middle of an active raid**. They **cannot attack the homebound boat or its in-transit cargo/crew after confirmed departure**. Evacuated volume is limited by **boat and harbor levels and special traits**, not by the amount of loot on site. A successful transfer of ownership from remote inventory into an actual vessel manifest at departure must be atomic and auditable. Avoid making queued shipping orders function as instant, unlimited raid-escape storage. **OPEN:** precise dock-loading vulnerability/interruptions, departure loading time and cooldowns, boat fleet/crew/cargo costs, offline transport, and whether voyages *outbound from home* follow the same protection rule. **NOT OPEN:** actual homeward departure is allowed during a raid, and confirmed homebound transit is invulnerable. No ocean-combat, piracy or escort requirement for the protected homebound transit leg. Abstract harbor-route transit with a visible boat is fine.

**Economy interaction:** The distance and risk of transporting premium materials increases their value. Trait-aware sorting and preservation must continue from contested quarry to home storage to a crafted prized crossbow. The transport system depends on meaningful material stacks, work orders, reservations, inventory and stable storage IDs.


### Example: exposure boundary and raid resolution (owner-confirmed rule)

| Location/state | Can raiders attack it? | Design interpretation |
|---|---|---|
| Remote mining/lumbering site and warehouse | **Yes** | Valuable materials and on-site human/dinosaur workers are exposed under zone rules |
| Cargo awaiting pickup or being staged at the contested dock | **Yes, until confirmed departure** | No immunity from merely assigning a shipment; boat/harbor level and traits cap evacuation capacity |
| Boat confirmed underway **toward protected home** | **No** | May depart while siege is active; no ambush, PvE/PvP interception, cargo theft or combat loss in transit |
| Shipment received in home storage | **No** | Permanently protected with the private island |

**Design implication:** The strategy is protecting a remote extraction base, deciding how much stock to hold there, and arranging transport before the next raid. Boat travel has a logistical time/capacity cost, **not another combat hazard**. Raiding the remote base must not be bypassed by converting its entire inventory into invulnerable 'pending' shipments in one frame.


### Under-siege escape cargo and anti-exploit rule

**CONFIRMED:** Defenders may evacuate cargo aboard a boat while attackers are already raiding. **CONFIRMED:** Total volume moved per voyage is constrained by the **boat's level and signed traits together with the origin harbor's level and signed traits**. In-progress outbound orders do not gain boat-travel immunity before actual departure. All details of speed, voyage frequency and whether boats carry workers or dinosaurs are pending balance.

**PROPOSED implementation:** Build an immutable server-controlled departure manifest at the instant the loaded vessel leaves the dock. Remove each shipped lot atomically from vulnerable dock/staging inventory, then store it in a protected in-transit shipment with ETA. Lower-tier boats and ports make fewer goods escapable under siege. Higher-tier boats, upgraded harbor handling equipment, and rare capacity/handling traits improve the amount saved. No instant warehouse-to-boat teleport, infinite departure spam, manifest duplication or alteration during transit. Once departed, attackers may still plunder the **remaining** contested base.

**Workshopping:** see [local alphas and fair sieges](pvp-raiding-local-alphas-and-siege-fairness.md) for how evacuation, attacker commitments, defended raid windows and power brackets fit together.

## 3. Offspring stages, food quality and education

**CONFIRMED:** Human offspring mature through **timed development stages** with food requirements. **Food quality during particular growth phases contributes to final stats**. Children eventually enter a **youth education/training phase** during which they can learn, then become eligible as adult workers/warriors/playable survivors. Breeding and upbringing remain expensive even late-game.

**Proposed stages (duration values all OPEN):**
- **Infancy:** shelter, caregivers and adequate nutrition. Poor supply may slow growth or limit potential realization; avoid unavoidable infant death from short, routine player absences without clear warnings.
- **Childhood:** ongoing food supply, housing and care quality; nutrition influences eventual physical development, health and perhaps growth trajectory within inherited genetic limits.
- **Adolescence / young learner:** timed education in tribal facilities and assigned mentors. The person learns limited early skills, behavioral tendencies and disciplines such as medicine, crafting, combat drills, farming and navigation. Training should not instantly grant an adult master's levels.
- **Adulthood:** full career, worksite job eligibility, equipment, combat assignment, reproduction eligibility under separate rules and optional adoption as the player-controlled survivor. A newly controlled adult still starts **low personal level**, unless owner-approved educational head start is explicitly defined.

**Growth model:** genes set *potential distributions*, nutrition affects *expressed development*, teachers/mentors affect *learned foundation and aptitude activation*, real activity produces adult XP and mastery. Education must not trivially bypass the principle that a fresh playable descendant needs to level and learn.

**Suggested care economy:** Different food categories offer varied nutrition profiles and inherited-lot food traits modify quality/effects. A *balanced and sustained feeding history* across phases should matter more than one last-second rare meal; track quality in rolling developmental phase records. Existing food/trait/cooking features should feed the upbringing system rather than generate a parallel unconnected nutrition currency.

**Proposed meaningful support infrastructure:** childcare shelter/nursery, school or training hall, food stores/kitchen, clinic/healer station, and caregivers/teachers. **Successful caregiver, educator and healer roles provide substantial tribe-wide benefits**, such as better growth outcomes, health/recovery, and training quality, rather than functioning as decorative buffs. Effects should be bounded, visible and linked to the skill and coverage of the actual supporting individual.

**OPEN:** What is a full upbringing duration? Can time pass while offline? Can the player speed a stage through care/education investment? Are offspring born from two specifically chosen adult parents? Which specific traits respond to protein/vegetables/medicinal foods? What happens if food is insufficient? How early do apprentices gain XP; are they deployable only once adults?

## 4. Body and role diversity (fictional game rules, not statements about real people)

**CONFIRMED design preference:** Human tribe members should have recognizable male/female physical differences as a default. Men trend **taller, heavier and physically stronger**, while baseline intelligence is comparable across sexes. Women lean toward strong **nurturer/support specializations**, such as nursing, healing, teaching, medical/pharmaceutical work and related morale/health/education bonuses. Men lean toward physical labor, craftsmanship and heavy-frontline fighting. **Support and frontline roles are synergistic**: warriors are not at full effectiveness without good healers, caretakers and logistical support.

**Additional CONFIRMED combat clarification:** Women **can absolutely be warriors**. Bows, crossbows, guns/firearms, positional combat, training and equipment let women compete as effective combatants despite an intended **average** unarmed/heavy-melee physical disadvantage. A female ranged specialist should be a desirable member of a fighting party, not a token second-class fighter. A talented woman can also specialize in melee; a man can be a nurse, teacher or healer.

**Recommended implementation of that preference:**
- For this *fictional* game's population, use overlapping **stat distributions**, not a male-only Warrior or female-only Healer toggle. Sex is neither a job lock nor an intelligence modifier. A physically strong woman or gifted male educator should be possible and valuable.
- Role effectiveness should depend primarily on developed skills, intrinsic aptitudes, gear quality, facility quality and teamwork. Sex can shift starting probabilities for strength/body size, labor/nurture inclinations or selected perks without guaranteeing an outcome or deciding individual worth.
- Distinguish **support skills** (medical care, nutrition, teaching, morale, logistics) from a fixed innate sex stat if possible, so players can deliberately educate exceptional specialists of any sex. If there are direct sex-linked bonuses, tune them to avoid rendering whole playstyles noncompetitive.
- Distinct physiques from gene expression: height, shoulder/body build, musculature, facial silhouette, stance, voice and equipment fit where feasible. These affect art/animation plus a small readable set of gameplay properties; do not make *every* visual tell mathematically deterministic.

**Presentation and fairness risk:** The game should explicitly treat these as chosen fictional balancing tendencies, not universal factual claims about real populations. Keep broad individual variation and no forced life role. Female armor, bows, crossbows and firearms should perform according to actual item/skill stats, not suffer a hidden blanket damage tax simply because of sex.

## 5. Observable physique vs hidden genetic potential

**Owner uncertainty:** The user likes both (a) a mostly weak, small, slow starting tribe that visibly develops taller/stronger/buffer individuals over generations, and (b) randomized appearances with partially hidden underlying stats so discovery and surprise remain fun. Neither preference needs to be discarded.

**PROPOSED hybrid:** 
- **Visible phenotype:** height, muscularity, body composition, posture, gait and age/sex presentation are sampled from **genes + upbringing + personal variation**. Build tends to **correlate**, not perfectly determine, with physical stat potential and training.
- **Displayed current ability:** when owned, a person has inspectable *current/earned* health, stamina, strength, work speed, learned skills, gear and roles. Player should know why an assignment works.
- **Hidden inherited potential:** long-term ceiling, dormant alleles, rare trait combinations and mutation chance are partly concealed until adulthood, training milestones, repeated use or a specialized research/education facility reveals estimates. Parents and broad growth reports give useful hints without perfect forecasts.
- **Aesthetics need diversity:** naturally short strong people, tall gentle educators, muscular healers, slim elite archers and taller weak workers should exist. Avoid a rigid "buff = mathematically best" pipeline, which erases surprise and visual variety.
- **Readable feedback:** family trees and development summaries explain **which** growth-phase food, mentoring, training or traits mattered after a stage resolves; do not hide all numbers behind opaque randomness.

**Optional rare late-game systems:** advanced examination/genetics labs that reveal greater confidence intervals for heritable potential and pedigree strengths. Avoid monetized pay-to-reveal hidden character stats.

**OPEN:** Should players see exact base stats at birth, only qualitative aptitudes, or measured stats that become more accurate with training? How much of morphology is heritable versus individually random? Can nutrition affect adult height/build beyond ancestry? 

## 6. Non-negotiable end-to-end scenarios

1. A tribe of valuable human workers and dinosaurs remains at the default home island indefinitely without enemy attacks or PvP losses. All materials stored there remain safe.
2. The player builds a remote PvE mining site, recruits workers, equips miners, and operates it for better ore. Raiders may threaten that remote site but never teleport an attack onto the safe home.
3. A dangerous PvPvE settlement has better trade/resource rewards, but the player may choose not to establish one. Losing the external site does not delete home assets.
4. A boat loads premium ore from a **raidable** remote stockpile; hostile raiders may seize goods before departure. After successful departure homeward, the vessel/crew/cargo are **unattackable throughout transit**. It delivers an unchanged traceable manifest with levels/traits into permanently protected home storage. Delayed or failed orders never duplicate goods.
5. Two genetically similar children experience different quality nutrition in growth phases and reach adulthood with detectably different **expressed** stat outcomes, without overwriting their distinct genes. Youth education conveys initial knowledge but not free veteran mastery.
6. The starting population has varied recognizable body types and average sex-linked physical tendencies, with significant overlap and no barred careers. A female ranged warrior and a male doctor are both viable, effective and valuable to the tribe.
7. A veteran warrior benefits measurably from nutrition, healer/recovery and education/coordination systems. Support specialists are consequential even if they never join a fighting party.
8. A seemingly weak-looking person can reveal unexpectedly good potential; a large muscular person can lack particular skills. Visuals are informative but not an infallible genetics readout.
9. Total loss of every human abroad respawns a baseline playable survivor at the protected home, where remaining home equipment and infrastructure persist. Exactly how dinosaur ownership works on total tribe wipe needs clarification.

## 7. Decisions to settle next

- **Boat exposure and siege departure (RESOLVED):** Remote gathering bases are fully raidable; **homebound boats in transit are not attackable or interceptable, even when they departed during an active raid**. Shipments are capacity-limited by **boat and harbor level/traits**. **Still OPEN:** time/vulnerability of dock loading, loading/departure cooldowns, and whether outbound trips share this immunity.
- **Offline safety:** No defender-chosen PvP raid windows (owner declined them). If a player is offline, may a remote PvPvE settlement and its guards suffer permanent losses, and does the boat keep operating?
- **Nursery pacing:** Rough real-time target from offspring to playable adult (hours, days, weeks); minimum food/care tier, quality and consequences of shortfalls?
- **Stat discovery:** Reveal numeric current stats and some qualitative hereditary clues, while concealing exact growth ceilings, or hide more?
- **Combat attributes:** How large should overlapping male/female strength distributions differ in balance terms, relative to weapons, professions and learned skills?
- **Risk-reward access:** Can the highest-quality breeding and crafting materials be obtained solo in safe expeditions/PvE, or are some exclusive to PvPvE territories?

## 8. Private-island upgrades and what is exposed (2026-10-25)

[Core-loop economic progression](progression-risk-and-island-economy.md). Every player begins with an **unraidable private production island** and may purchase **larger protected islands for a hefty in-game price** to build housing, industry, education, storage and safe dinosaur breeding facilities. The Skyblock-like progression is building a self-sufficient home economy; harvesting/crafting is Durango-like and dinosaurs/breeding/frontier survival borrow the ARK design shape.

A rational player puts their **best workers, rare bred dinosaurs, prized gear, advanced nurseries and premium resources at home**, using more replaceable laborers, animals, tools and materials in voluntarily raidable frontier outposts. Raids target only what is **actually exposed**. Cargo vessels may depart the contested harbor during active attacks, with the number/weight of safely evacuated items limited by the **boat and harbor levels and their special traits**. Once departed **homeward**, a ship and its manifest are safe in transit.

The owner rejected player-scheduled PvP raid windows; PvP may be **late-game opt-in** as a current suggested direction (exact gate open). Offline risk, attacker siege charges/cooldowns and capture/loss remain a balance workshop rather than a finalized system. Larger island upgrade behavior (expansion, relocation or multiple protected islands) is not yet selected.
