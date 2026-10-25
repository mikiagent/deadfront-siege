# 15 | Combat archetypes, pack intelligence, leadership and existing system integration

**Status:** DRAFT for owner workshop, 2026-10-25. The user specifically proposed a **Precision/Might × Blunt/Impale/Slash** six-cell weapon classification and asked to reuse existing pack alphas, fatigue/construction, crafting and research. **Confirmed directions:** those weapon examples, cross-domain attributes, Endurance supporting building, Intelligence supporting research and pack/team coordination. Numerical effects, complete stat roster and implementation are **NOT APPROVED**.
**Companion chapter:** [02 Characters, Levels and Shared Attributes](02-characters-levels-and-age.md). [Old weapon notes](../design/weapons.md), [Skills](../design/skills.md).

**LOCKED COMBAT NAMES (owner-approved 2026-10-25):** the player-facing primary attributes are **Precision (P)** and **Might (M)**. The player-facing damage types are **Blunt (B)**, **Impale (I)** and **Slash (S)**. Together they yield **PB, PI, PS, MB, MI, MS**, with **no shared initials**. **Impale** replaces the earlier provisional label *Point* or *Thrust*, and **Might** replaces the earlier provisional combat attribute name *Strength*. This is a **display/design terminology decision only**, not permission to rename saved internal combat tokens or change weapon performance. Map **Impale -> internal `pierce`** and **Slash -> internal `cut` / `slashing`**. Distinct learned Melee/Ranged proficiency and character-level equipment requirements still apply.

## 1. Design principle

Weapons have **two independent dimensions**:
- **Primary application attribute:** how effectiveness is generated, **Might** (force/body impact) or **Precision** (aim/control/targeting). A secondary attribute can influence handling, timing or load.
- **Damage channel:** **Blunt**, **Impale** (player-facing term for existing `pierce`), or **Slash** (player-facing term for existing `cut` / `slashing`). The channel is the counter to armor, monster anatomy and resistance, **not** a separate stat to level in isolation.

The current engine already uses **Blunt / Pierce / Cut** channels in [`game/data/combat_counters.json`](../../game/data/combat_counters.json), with `CombatCounters.channel` mapping `slashing` to `cut`. **Do not add new internal damage enum values for the display labels Impale or Slash**. Change only UI terminology or map content labels at the data boundary. Poison/bleed remain status/DOT channels, not extra cells in this six-category weapon grid.

## 2. Six archetypes (owner-provided examples)

| Primary attribute | Blunt **B** | Impale **I** | Slash **S** |
|---|---|---|---|
| **Precision (P)** | **PB:** boulder thrower, **catapult**, **slingshot** | **PI:** bow, gun, blowdart (crossbow proposed) | **PS:** whip, **throwing axe** |
| **Might (M)** | **MB:** hammer warrior, boxer/unarmed | **MI:** javelin, spear | **MS:** sword, axe |

This assigns **primary** scaling identity, not exclusive requirements. A bow benefits secondarily from physical ability to handle the weapon; a spear benefits from proper aiming or technique; catapult accuracy comes from a precision operator even though building/loading the siege equipment can involve Might and Endurance. A thrown axe occupies **Precision/Slash**, while the same axe *swung in melee* occupies **Might/Slash** if game implements attack-mode-specific profiles. A whip can be implemented as cutting/slashing for this matrix even if real-world whips vary. Throwing weapons must not be automatically reclassified solely from being ranged; maintain explicit owner choices.

**Existing weapon reality, not a content promise:** [`docs/design/weapons.md`](../design/weapons.md) already describes knife, club, axes, spear, bow, crossbow and thrown stones. [`game/data/items.json`](../../game/data/items.json) contains a **slingshot**, **hammer** and **catapult kit**. [`game/scripts/world/field_catapult.gd`](../../game/scripts/world/field_catapult.gd) implements a manually fired catapult spending **stone shot** or toxic ammunition and aiming at a selected creature. **Boulder throwers, guns, blowdarts, whips and throwing axes** should be marked planned until individually present as item/attack implementations. The **crossbow** naturally falls under **Precision/Impale**, retaining its reload/counter identity. "Boxer" denotes an unarmed human archetype, not an existing separate class.

## 3. Combat channels preserve real creature counters

The existing [counter table](../../game/data/combat_counters.json) provides tangible encounter variety: armored and giant creatures resist cutting/piercing more while being more vulnerable to blunt; fast hunters can be more vulnerable to cut. Do not replace those with a universal 2D multiplier that makes one attribute and one damage type automatically superior.

**Player decision:** Choose weapons by **character aptitude + learned expertise + enemy defense**, not only item rarity. An intelligent squad leader might bring a Might/Blunt hammer specialist versus an armored dinosaur, Precision/Impale archer against a running creature, and Precision/Slash throwing-axe specialist to exploit exposed targets. Real enemy archetype counters, bleed/poison status, reload/handling, danger range and equipment item-level gates all matter.

**Confirmed:** display **Impale**, even though the internal resistance token stays `pierce`. **OPEN:** canonicalizing legacy `slashing` versus `cut` tags on disk is a serialization problem, not a new damage category; avoid silent save-schema breaks.

## 4. Intelligence: existing pack alpha evolves into credible command

**Existing code verified:**
- [`game/scripts/creatures/brains/creature_brain.gd`](../../game/scripts/creatures/brains/creature_brain.gd): wild pack leader currently = **strongest** wild creature in the group, sorted by species tier, HP, Attack and Defense; it directs roaming, target acquisition and spacing. There is **no Intelligence attribute** in the sort today.
- [`game/scripts/creatures/brains/raptor_pack_brain.gd`](../../game/scripts/creatures/brains/raptor_pack_brain.gd): followers inherit alpha's prey, move to flanking slots and enforce shared attack pacing.
- [`game/scripts/creatures/brains/pet_brain.gd`](../../game/scripts/creatures/brains/pet_brain.gd): tamed companions already respond to **Guard / Attack / Heel** orders; no trained human field-commander or multi-human squad/rally API yet.
- [`game/scripts/creatures/creature_genetics.gd`](../../game/scripts/creatures/creature_genetics.gd): wild/tamed animal IVs already cover **health, melee/ranged defense, melee/ranged attack, accuracy, speed**, but **not Intelligence**. Adding animal Intelligence/coordination genetics is a **schema migration and balancing decision**, not a free rename of Accuracy.

**Owner direction:** An effective alpha/leader needs **credible combat aptitude (Might OR Precision) plus Intelligence**. Intelligence should guide coordination, rallying and support, not act as an unbounded generic damage percentage.

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
- **Endurance** increases *sustainable active labor time* or reduces **exertion-generated** fatigue; **Construction skill** unlocks techniques and determines craftsmanship/construction proficiency. Might helps lift heavy parts; Precision helps fine assembly or placement tolerance; Intelligence helps understanding complex plans.
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
A melee `axe` mode would instead use Might/Slash and `melee` skill. **The numeric level above is purely illustrative**, not a confirmed unlock. Catapult weapon mode can share Precision/Blunt damage while using a distinct siege proficiency or siege/station eligibility in addition to material/blueprint requirements. The existing catapult already has manual ammo, reload and range.

## 8. Acceptance tests

1. A high-Might low-Smithing survivor cannot forge masterwork tools without learned skills/stations but works a heavy hammer better than an equally inexperienced low-Might individual.
2. A high-Precision tailor with no Ranged proficiency remains novice at archery; training Ranged makes the same base Precision useful.
3. Four fighters use mixed Might/Blunt, Might/Impale, Precision/Impale and Precision/Slash weapons and encounter meaningful armored-versus-fast dinosaur counters using the current data channels.
4. Strong, low-Int pack alpha leads roaming/target selection but coordinates less intelligently than a comparably strong high-Int alpha, **if animal Intelligence is approved**. No existing behavior is removed before migration tests.
5. An Intelligence-heavy researcher does not bypass personal level-60 PvPvE entry or strict equipment equip levels, even when discovering endgame technologies.
6. A high-Endurance builder assigned to the future worksite lasts longer before rest, using actual Energy/Exhaustion values and delivered material lots, than a low-Endurance builder with equal Construction skill.
7. A smart human leader can rally 3-slot expedition allies or a bounded camp squad while obeying range, energy, cooldown and follower limits. Support cannot stack unlimited global damage buffs.
8. Wild pack alpha selection and raptor flanking continue to work against baseline test cases; progression for pets remains distinct until genetics schema decision.

## 9. Owner decisions needed before implementation

1. **Alpha choice:** Should high Intelligence **help determine who becomes alpha** (subject to a minimum Might/Precision combat credibility), or should alpha remain the **strongest creature** while Intelligence controls how cleverly the pack follows?
2. **Rally effects:** Should a leader primarily improve **target switching, flanking and courage**, or also provide short-lived direct **accuracy/attack/defense** buffs? Prefer tactical behavior over blanket multiplier.
3. **Constructing:** Should Endurance influence only *how long a worker can build before resting*, or also construction *speed/quality*? Prefer sustained shifts plus reduced fatigue.
4. **Research:** Shared tribe tech tree staffed by individual Intelligence/Research workers vs individualized discoveries. Prefer tribe-global unlocked knowledge with personally earned Research skill.
5. **Weapon mode:** When the same axe is swung versus thrown, does its primary attribute change (Might/Slash vs Precision/Slash)? This follows the new weapon matrix and makes modular weapons interesting.
6. **Attribute EV training:** Should builders and researchers slowly improve the general Endurance and Intelligence attributes through work, or only occupational proficiency, with generic EVs trained separately?

**No game code changes are made by this design chapter.**
