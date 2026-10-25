# 15 | Combat archetypes, pack intelligence, leadership and existing system integration

**Status:** DRAFT for owner workshop, 2026-10-25. The user specifically proposed a **Dexterity/Might × Impact/Pierce/Slash** six-cell weapon classification and asked to reuse existing pack alphas, fatigue/construction, crafting and research. **Confirmed directions:** those weapon examples, cross-domain attributes, Endurance supporting building, Intelligence supporting research and pack/team coordination. Numerical effects, complete stat roster and implementation are **NOT APPROVED**.
**Companion chapter:** [02 Characters, Levels and Shared Attributes](02-characters-levels-and-age.md). [Old weapon notes](../design/weapons.md), [Skills](../design/skills.md).

**LOCKED COMBAT NAMES and inherited IV concept (owner-approved 2026-10-25):** The two core **inherited/intrinsic individual-value (IV) attributes** are **Dexterity (D)** and **Might (M)**. Dexterity influences accurate weapon/tool **handling**, delicate control and ranged attacks. Might influences **physical attack force** and heavy-tool capability. The three player-facing **attack/damage verbs** are **Impact (I)**, **Pierce (P)** and **Slash (S)**, forming **DI, DP, DS, MI, MP, MS** with five unique initials. An action's primary attribute and damage verb are independent; the *individual dinosaur* may have several attack modes with different combinations. These are inherited base potentials; **whether work/combat can grow a separate EV contribution, and by how much, remains OPEN**. Learned weapon/profession skills and personal equip level remain separate. This is a design decision only, not an implemented genetics schema.

## 1. Design principle

Weapons have **two independent dimensions**:
- **Primary application attribute:** how effectiveness is generated, **Might** (force/body impact) or **Dexterity** (aim/control/targeting). A secondary attribute can influence handling, timing or load.
- **Damage channel:** **Impact**, **Pierce** (player-facing term for existing `pierce`), or **Slash** (player-facing term for existing `cut` / `slashing`). The channel is the counter to armor, monster anatomy and resistance, **not** a separate stat to level in isolation.

The current engine already uses **Blunt / Pierce / Cut** channels in [`game/data/combat_counters.json`](../../game/data/combat_counters.json), with `CombatCounters.channel` mapping `slashing` to `cut`. **Do not rename the internal `blunt` token to `impact`, or `cut` to `slash`**. Change only UI terminology or map content labels at the data boundary. Poison/bleed remain status/DOT channels, not extra cells in this six-category weapon grid.

## 2. Six archetypes (owner-provided examples)

| Inherited IV | **Impact (I)** | **Pierce (P)** | **Slash (S)** |
|---|---|---|---|
| **Dexterity (D)** | **DI:** boulder thrower, **catapult**, **slingshot** | **DP:** bow, gun, blowdart (crossbow proposed) | **DS:** whip, **throwing axe** |
| **Might (M)** | **MI:** hammer warrior, boxer/unarmed, stomp | **MP:** javelin, spear, heavy spiked-tail strike | **MS:** sword, axe |

This assigns **primary** scaling identity, not exclusive requirements. A bow benefits secondarily from physical ability to handle the weapon; a spear benefits from proper aiming or technique; catapult accuracy comes from a precision operator even though building/loading the siege equipment can involve Might and Endurance. A thrown axe occupies **Dexterity/Slash**, while the same axe *swung in melee* occupies **Might/Slash** if game implements attack-mode-specific profiles. A whip can be implemented as cutting/slashing for this matrix even if real-world whips vary. Throwing weapons must not be automatically reclassified solely from being ranged; maintain explicit owner choices.

**Existing weapon reality, not a content promise:** [`docs/design/weapons.md`](../design/weapons.md) already describes knife, club, axes, spear, bow, crossbow and thrown stones. [`game/data/items.json`](../../game/data/items.json) contains a **slingshot**, **hammer** and **catapult kit**. [`game/scripts/world/field_catapult.gd`](../../game/scripts/world/field_catapult.gd) implements a manually fired catapult spending **stone shot** or toxic ammunition and aiming at a selected creature. **Boulder throwers, guns, blowdarts, whips and throwing axes** should be marked planned until individually present as item/attack implementations. The **crossbow** naturally falls under **Dexterity/Pierce**, retaining its reload/counter identity. "Boxer" denotes an unarmed human archetype, not an existing separate class.

## 3. Combat channels preserve real creature counters

The existing [counter table](../../game/data/combat_counters.json) provides tangible encounter variety: armored and giant creatures resist cutting/piercing more while being more vulnerable to blunt; fast hunters can be more vulnerable to cut. Do not replace those with a universal 2D multiplier that makes one attribute and one damage type automatically superior.

**Player decision:** Choose weapons by **character aptitude + learned expertise + enemy defense**, not only item rarity. An intelligent squad leader might bring a Might/Impact hammer specialist versus an armored dinosaur, Dexterity/Pierce archer against a running creature, and Dexterity/Slash throwing-axe specialist to exploit exposed targets. Real enemy archetype counters, bleed/poison status, reload/handling, danger range and equipment item-level gates all matter.

**Confirmed:** player-facing **Impact** maps to internal `blunt`, **Pierce** maps to internal `pierce`, and **Slash** maps to internal `cut`/`slashing`. **OPEN:** canonicalizing legacy `slashing` versus `cut` tags on disk is a serialization problem, not a new damage category; avoid silent save-schema breaks.

**Latest categorization proposal:** Defensive matchups use **Slash** for huge slow exposed HP tanks, **Impact** for heavy armor and suitably clustered small swarms, and **Pierce** for fast/low-armored mobile prey; vulnerability and a dinosaur's attack verb are independent. Current `fast_hunter` and `giant` multipliers conflict with this new generalized scheme. **All nineteen existing creatures** are now provisionally categorized with their attack moves, present stats, and migration risks in [11 Dinosaur Taxonomy & Genetics](11-dinosaurs-and-genetics.md). **Nothing has been balanced/implemented yet.**

**Equipment layer (new proposal):** **Light / Medium / Heavy** worn armor would add mobility, Energy/Exhaustion, coverage and damage-channel protection on top of a species' *natural* flesh/mobile/plated vulnerability. Heavy protects against Slash/Pierce but is relatively Impact-stagger vulnerable; Light evades some slow Impact but risks Pierce on hit; Medium offers material-dependent balance. This does **not** overwrite the confirmed **D/M × I/P/S** offense matrix or the current three-slot equipment/raid set mechanics. [Armor and equipment proposal](06-inventory-equipment-and-storage.md). Neither armor tiers nor multipliers are currently implemented/approved.

## 3A. Dinosaur attack modes and matchup strategy: sauropods and Stegosaurus

**OWNER DESIGN EXAMPLE: a future Brontosaurus** should be a **very-high-HP, low-defense** creature that is **particularly vulnerable to Slash**. It has at least two distinctly classified attacks:
- **DS Dexterity/Slash: Tail Whip.** Long-arc accuracy/placement and repeated whipping/recovery can favor high innate Dexterity. Does not imply the tail must be a sword.
- **MI Might/Impact: Stomp.** High weight, powerful knockback/area denial and a slower telegraph favor Might.
- The species can be raised/trained with emphasis on either attack mode or mixed utility; it retains **both inherited IVs** regardless of specialization. These moves are **PROPOSED** unless the owner separately settles timing, telegraphs and statuses.

**Repo reality:** There is presently **Brachiosaurus**, not an implemented distinct Brontosaurus, in [`game/data/creatures/brachiosaurus.json`](../../game/data/creatures/brachiosaurus.json). That existing Brachiosaurus has **90,000 HP**, **500 defense**, `titan` archetype, and **stomp attacks**; it is currently non-tameable. Current [`game/data/combat_counters.json`](../../game/data/combat_counters.json) maps `titan` to **giant**, where cutting attacks deal only **0.5×**. This **contradicts** the proposed high-HP, Slash-weak Brontosaurus fantasy. **Do not silently modify the existing Brachiosaurus or giant counter table**. Proposed future solution: species-level resistance overrides or a distinct **soft_sauropod / fleshy_titan** family with high HP but weak Slash defense, while sturdier titans retain distinct defenses. Actual stats and multipliers remain OPEN.

**Stegosaurus proposal:** [`game/data/creatures/stegosaurus.json`](../../game/data/creatures/stegosaurus.json) **already exists** with the `spiked_tail` archetype, **8500 HP, 300 defense**, `attack_primary`/ `attack_heavy` spiked-tail sweep clips and **`deep_bleed`** inflicted on hit. Its existing `spiked_tail` -> `armored` counter family is tough versus Slash and Pierce, but vulnerable to Impact. Do not change that species' defenses as a side effect of assigning its attack type.

The physical **thagomizer** tail spikes chiefly **Pierce** when driven into a target; the lateral tail motion is not itself evidence of an Impact attack. **Recommended owner-reviewable Stegosaurus specializations:**

| Mode | Attack description | Play tradeoff |
|---|---|---|
| **MP Might/Pierce** | Heavy tail-spike drive or powerful rear sweep that plants spikes | Greater single-hit force/puncture, slower commit and recovery; default suggested identity |
| **DP Dexterity/Pierce** | Controlled tail-spike placement targeting an opening | Better aimed/mobile-target hits, less raw impact force; natural precision build |
| **DS Dexterity/Slash (optional)** | Glancing side rake with the points during a sweeping pass | Lower puncture, cutting/bleeding pressure and spacing play; **requires separate move/rules** |
| **MI Might/Impact (optional)** | Tail shaft/hip-side strike or body shove that misses spike tips | Area denial/stagger without puncture; must be visibly distinct from spiking animation |

The same creature has both IVs; attack behavior can be **mode-dependent** rather than a permanent whole-species class. Do not arbitrarily turn a spiked sweep into Slash merely because its movement arcs sideways; assign based on **contact geometry** (spike tip penetrating = Pierce, grazing spike edges = Slash, blunt body/tail base = Impact). `deep_bleed` is a status overlay, not a fourth damage channel. Animal breeding could seek high Dexterity IV or Might IV according to preferred modes; actual training EV, skill and animation profiles are still OPEN.

**Designing an understandable rock-paper-scissors:** Three verbs should define **clear tactical matchup niches**, but IVs should not independently form a fake advantage triangle. **PROPOSED:** Impact threatens **hard armor/shells** and staggerable guards; Pierce threatens **mobile targets / exploitable openings at reach**; Slash excels in **sustained damage to soft, low-defense, high-health bodies**, including the proposed Brontosaurus. Cost these with reach, telegraph, dodge windows, stamina, equipment, status and defenses. This is **not yet a complete mathematical cycle**: determine creature vulnerabilities/defenses and verify equal-level encounter tests rather than claiming a perfect counter loop. The existing `bleeding_target` is currently **fixed DPS**, not percent of target max HP; do not introduce unbounded %HP bleed to make Slash beat giants without a separate anti-boss balance decision.

**Genetics migration implication:** Current [`CreatureGenetics`](../../game/scripts/creatures/creature_genetics.gd) has seven combat-related IVs (`health`, defense/attack, `accuracy`, `speed`) and **no `dexterity` or `might` keys**. Owner has approved these *as the conceptual primary inherited attributes*, not deletion or replacement of saved current stats. Proposed schema work must decide whether legacy `accuracy` and `melee_attack` derive from IV Dexterity/Might or coexist as separate genetic values, preserving existing saves and creatures. Similar human IV integration is new development, not already live.

## 4. Intelligence: existing pack alpha evolves into credible command

**Existing code verified:**
- [`game/scripts/creatures/brains/creature_brain.gd`](../../game/scripts/creatures/brains/creature_brain.gd): wild pack leader currently = **strongest** wild creature in the group, sorted by species tier, HP, Attack and Defense; it directs roaming, target acquisition and spacing. There is **no Intelligence attribute** in the sort today.
- [`game/scripts/creatures/brains/raptor_pack_brain.gd`](../../game/scripts/creatures/brains/raptor_pack_brain.gd): followers inherit alpha's prey, move to flanking slots and enforce shared attack pacing.
- [`game/scripts/creatures/brains/pet_brain.gd`](../../game/scripts/creatures/brains/pet_brain.gd): tamed companions already respond to **Guard / Attack / Heel** orders; no trained human field-commander or multi-human squad/rally API yet.
- [`game/scripts/creatures/creature_genetics.gd`](../../game/scripts/creatures/creature_genetics.gd): wild/tamed animal IVs already cover **health, melee/ranged defense, melee/ranged attack, accuracy, speed**, but **not Intelligence**. Adding animal Intelligence/coordination genetics is a **schema migration and balancing decision**, not a free rename of Accuracy.

**Owner direction:** An effective alpha/leader needs **credible combat aptitude (Might OR Dexterity) plus Intelligence**. Intelligence should guide coordination, rallying and support, not act as an unbounded generic damage percentage.

**Proposed two-factor command eligibility:**
1. **Presence/credibility:** capable combat stat, level/skill, species/body role, or trained command reputation. A pure scholar with no field capability cannot automatically lead a pack of elite fighting animals.
2. **Coordination:** Intelligence plus training/obedience/leadership skill determines how effectively followers respond and perform joint tactics.

This permits **strong but unintelligent frontline bruisers** and **precise intelligent tactical leaders**, as well as **smart but weak support researchers**. The wild-alpha selection could remain biased toward combat prowess while the Intelligence/coordination of the alpha determines *tactical quality*; or leader selection could use a joint score with a minimum combat credibility floor. **Owner has not approved a specific algorithm.** An intelligently commanded pack should look **smarter**, not merely hit 20% harder.

**Specific command actions to explore:**
- **Focus Target:** followers acquire the same marked threat sooner; avoid stacking direct damage bonuses.
- **Rally:** nearby fighters recover from disorganization/panic faster or regain formation, subject to Energy/cooldown, distance, line-of-sight and morale/status limits.
- **Flank / Hold / Disengage:** better timing and safer spacing, building on the existing raptor flank, shared target and Guard/Heel behaviors.
- **Protect Support:** coordinate bodyguard placement for doctors, medics, researchers or haulers.
- **Mounted Pair Lead:** intelligent rider uses one party slot with their dinosaur, improving command interpretation and controlled weapon attacks rather than the dinosaur's uncontrolled specials.

**Anti-exploit:** Commands must obey three mixed Expedition slots in normal party play (larger settlement/garrison force may be separate, OPEN), bounded command radius, lossy/non-stacking active command budget, follower morale/obedience/skills and item-level requirements. One world-global high-Int leader cannot buff every NPC at every settlement from a safe island. Separate **human tactical leadership** and **creature-instinct/pack leadership** while reusing a shared coordination interface where practical.

## 5. Endurance connects construction to existing vitals

**Existing code:** [`game/scripts/world/build_placer.gd`](../../game/scripts/world/build_placer.gd) currently consumes a building kit, **instantly** spawns a building and gives Construction XP (+8). It **does not** yet simulate a material-delivery, labor-progress worksite. [`game/scripts/combat/vitals.gd`](../../game/scripts/combat/vitals.gd) already models **Energy, Exhaustion, stamina cost/regeneration and exhaustion penalties**, including heavy fatigue restricting the useful Energy ceiling.

**Owner direction:** Endurance is especially valuable in **building/construction**. Proposed implementation *after* the confirmed unfinished-worksite feature:
- Each physical labor step spends Energy and accumulates Exhaustion; the worker must hold a real hammer/tool and consume real delivered building materials according to the work order.
- **Endurance** increases *sustainable active labor time* or reduces **exertion-generated** fatigue; **Construction skill** unlocks techniques and determines craftsmanship/construction proficiency. Might helps lift heavy parts; Dexterity helps fine assembly or placement tolerance; Intelligence helps understanding complex plans.
- The Site/Monitoring Stand system can schedule rotations/rest, let support staff deliver materials, and prevent tool breakage at 1 durability during automated jobs.
- No magic refund multiplier, no free extra ingredients, no unbounded work speed, and no separate Construction Stamina meter unless testing demonstrates it is needed.
- Retain current Construction XP concept but move its future award from *instant placement* to meaningful construction progress/completion as the blueprint-worksite feature ships. Rate and EV training are OPEN.

**Synergy:** Endurance benefits frontline stamina and the economic value of resilient builders who can work longer, but a veteran builder still needs Melee training and gear to become a warrior.

## 6. Intelligence connects research/technology without buying progression

**Existing code:** [`game/data/skills/trees.json`](../../game/data/skills/trees.json) contains twelve skills and describes **timed research gates** for many trees, but its `research_gates` fields are **metadata/descriptions**, not evidence that a staffed research station or researcher system currently exists. [`game/scripts/skills/skill_state.gd`](../../game/scripts/skills/skill_state.gd) implements level/XP, skill points, and unlockable nodes. [`game/scripts/items/crafting.gd`](../../game/scripts/items/crafting.gd) checks required survival, recipe skill and material levels for some recipes.

**Owner direction:** **Intelligence influences research** alongside leadership. A new Research/Technology system should use:
- **Tribe-wide blueprint/tech discovery** or shared documented research results (which survive switching playable bodies).
- **Individual learned research skill** plus Intelligence determining work contribution, hypothesis choice, reduced error, or efficient research time/resources, without permitting a level-1 scholar to unlock level-60 equipment or PvPvE entry.
- **Research facilities** built through the confirmed blueprint -> unfinished worksite construction flow, resource/food upkeep, rare material samples from expeditions, and worker assignments.
- **Mentors/teachers** as multipliers of education quality and knowledge transmission, not direct Intelligence transfer to all recruits.

**OPEN:** whether research is a separately leveled discipline, a shared Tech tree project staffed by workers, or a subset of existing trees; whether a research breakthrough can be bought/traded and how to prevent level-gate bypass; whether leadership and research should share the same Intelligence generic stat but depend on different learned skills (recommended yes).

## 7. Six-archetype weapon and research skill implementation boundary

**Current `SkillState.ORDER`** already includes `melee`, `ranged`, `defense`, `weapon_tools`, `tailoring`, `construction` and others. **Do not replace 12 trees with six new weapon skills without owner approval.** Prefer adding each **weapon action** a `primary_attribute` and a `damage_channel`, using current learned Melee/Ranged skill proficiency and weapon requirements.

Example **PROPOSED data only**, not existing runtime:
```json
{
  "weapon_id": "throwing_axe",
  "mode": "throw",
  "primary_attribute": "precision",
  "damage_channel": "cut",
  "learned_skill": "ranged",
  "required_level": 25
}
```
A melee `axe` mode would instead use Might/Slash and `melee` skill. **The numeric level above is purely illustrative**, not a confirmed unlock. Catapult weapon mode can share Dexterity/Impact damage while using a distinct siege proficiency or siege/station eligibility in addition to material/blueprint requirements. The existing catapult already has manual ammo, reload and range.

## 8. Acceptance tests

1. A high-Might low-Smithing survivor cannot forge masterwork tools without learned skills/stations but works a heavy hammer better than an equally inexperienced low-Might individual.
2. A high-Dexterity tailor with no Ranged proficiency remains novice at archery; training Ranged makes the same base Dexterity useful.
3. Four fighters use mixed Might/Impact, Might/Pierce, Dexterity/Pierce and Dexterity/Slash weapons and encounter meaningful armored-versus-fast dinosaur counters using the current data channels.
4. Strong, low-Int pack alpha leads roaming/target selection but coordinates less intelligently than a comparably strong high-Int alpha, **if animal Intelligence is approved**. No existing behavior is removed before migration tests.
5. An Intelligence-heavy researcher does not bypass personal level-60 PvPvE entry or strict equipment equip levels, even when discovering endgame technologies.
6. A high-Endurance builder assigned to the future worksite lasts longer before rest, using actual Energy/Exhaustion values and delivered material lots, than a low-Endurance builder with equal Construction skill.
7. A smart human leader can rally 3-slot expedition allies or a bounded camp squad while obeying range, energy, cooldown and follower limits. Support cannot stack unlimited global damage buffs.
8. Wild pack alpha selection and raptor flanking continue to work against baseline test cases; progression for pets remains distinct until genetics schema decision.

## 9. Owner decisions needed before implementation

1. **Alpha choice:** Should high Intelligence **help determine who becomes alpha** (subject to a minimum Might/Dexterity combat credibility), or should alpha remain the **strongest creature** while Intelligence controls how cleverly the pack follows?
2. **Rally effects:** Should a leader primarily improve **target switching, flanking and courage**, or also provide short-lived direct **accuracy/attack/defense** buffs? Prefer tactical behavior over blanket multiplier.
3. **Constructing:** Should Endurance influence only *how long a worker can build before resting*, or also construction *speed/quality*? Prefer sustained shifts plus reduced fatigue.
4. **Research:** Shared tribe tech tree staffed by individual Intelligence/Research workers vs individualized discoveries. Prefer tribe-global unlocked knowledge with personally earned Research skill.
5. **Weapon mode:** When the same axe is swung versus thrown, does its primary attribute change (Might/Slash vs Dexterity/Slash)? This follows the new weapon matrix and makes modular weapons interesting.
6. **Attribute EV training:** Should builders and researchers slowly improve the general Endurance and Intelligence attributes through work, or only occupational proficiency, with generic EVs trained separately?

**No game code changes are made by this design chapter.**
