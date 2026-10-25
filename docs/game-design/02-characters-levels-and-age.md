# 02 | Characters, personal levels, shared attributes and cross-domain professions

**Status:** DRAFT design chapter, 2026-10-25. The owner's new **direction** is to share general-purpose attributes between combat and crafting (explicit examples: **Might** helps smithing AND physical combat; **Dexterity** helps tailoring AND ranged combat). Exact attribute roster, formulas, trainability, caps and relative balance are **PROPOSED / OPEN**, not approved. None of this is implemented by writing the document.
**Related:** [Owner decisions](decisions.md), [audit backlog](audit-and-open-questions.md), [historical skills trees](../design/skills.md), [persistent tribe and genetics](../design/tribe-lineage-domain-and-labor.md), [food/growth](../design/safe-home-expeditions-offspring-and-identity.md), [captives and IV/EV](16-pvp-frontier-siege-and-captives.md).

**2026-10-25 owner-approved naming and IV direction:** **Dexterity (D)** and **Might (M)** are the two primary **inherited, intrinsic IV attributes**. Dexterity governs **weapon/tool handling and ranged precision**; Might governs **physical weapon power and heavy-tool ability**. Combat attack verbs are **Impact (I)**, **Pierce (P)** and **Slash (S)**. The six action-mode archetypes are **DI / DP / DS / MI / MP / MS**, with distinct letters. Individual people/dinosaurs can possess both IVs and use different move types. Profession proficiency, training EVs, equipment requirements and genetic migration are separate design matters. See [canonical combat and dino mode matrix](15-pve-exploration-and-combat.md).

## 1. Design motivation: your body is useful in every profession

**OWNER DESIGN DIRECTION:** Combat, gathering, construction and manufacturing should **share general-purpose character attributes**, not separate mutually disconnected 'crafting stats' and 'combat stats'. The same high-Might individual can excel in heavy forging AND melee fighting; the same high-Dexterity individual can excel in delicate tailoring AND archery/crossbows/firearms. Players should recognize their characters' potential across different jobs and enjoy surprising dual-specialty individuals.

**Critical distinction:** A shared attribute is an **aptitude and performance modifier**, NOT a free substitute for mastery, gear, material quality or an item-level requirement. A powerful warrior with zero Smithing skill is not automatically a master smith. A skilled tailor with high Dexterity has ranged potential but must learn weapon use and access level-appropriate equipment.

## 2. Confirmed innate IVs and proposed broader attribute roster

| Attribute | Combat advantage | Civilian advantage | Design notes |
|---|---|---|---|
| **Might** | Melee power, carrying heavy arms, grappling | Forging heavy metal, mining impact, hauling | Helps force-dependent jobs; not a universal 'best crafter' stat |
| **Dexterity** | Ranged accuracy, weak-point targeting, controlled weapon handling | Fine tailoring, detailed leatherwork, fine assembly, carpentry joints | Fine control rather than generic speed |
| **Agility** | Evasion, repositioning, attack responsiveness | Agile hunting/gathering, quick manual tasks | Keep distinct from fine-accuracy precision |
| **Endurance** | Energy/Exhaustion resistance and sustained fights | **Construction worksite labor**, extended manual shifts | Especially affects how long builders can work before rest, not instant construction quality or material refunds |
| **Intelligence** | **Alpha/pack coordination, tactical leadership, rally/support orders** with credible Might or Dexterity and trained Command | **Research, technology development, blueprints**, engineering and education | Separate underlying Intelligence from learned Command and Research skills; existing pack alpha has no Intelligence stat yet |
| **Care / Social aptitude (OPTIONAL)** | Healer assistance, morale support | Nursing, tutoring, childcare, taming/handling | Prefer starting with learned care professions influenced by Intelligence/Dexterity rather than assuming a mandatory sixth inherited stat |

The **two confirmed inherited attributes** are **Dexterity** and **Might**. The larger six-row roster is **only a proposal**: Agility, Endurance, Intelligence and optional Care are not yet finalized as IVs, EVs or learned abilities. Dexterity is specifically **fine weapon/tool handling** (not a synonym for dodge/evasion); Agility, if retained, should have a distinct mobility role. Endurance may link to existing Energy/Exhaustion and construction, Intelligence to research/pack command. Do not duplicate effective-attack or accuracy mechanics merely because IV values are being introduced. Avoid needless UI complexity.

## 3. Work recipes declare what matters

**PROPOSED:** Each combat action, manual work order and crafting recipe defines an **attribute profile**: one dominant attribute (and optionally one or two secondary attributes), in addition to the relevant *learned skill*, required tool/workstation, recipe knowledge, material quality and signed traits.

| Example activity | Primary attribute | Secondary | Profession skill (separate) | Expected effect |
|---|---|---|---|---|
| Forging a heavy axe head | Might | Endurance, Dexterity | Smithing | Easier handling of metal; work speed/consistency with adequate mastery |
| Forging intricate metal mechanisms | Dexterity | Intelligence | Fine Smithing / Mechanisms | Tiny-tolerance assembly accuracy |
| Tailoring fine armor seams | Dexterity | Intelligence or Care | Tailoring | Fewer mistakes, clean seams, better finishing opportunity |
| Mining dense ore | Might | Endurance | Mining | Work rate and stamina; cannot conjure extra node yield |
| Using a greatsword | Might | Agility | Melee | Damage/handling where equipment and technique allow |
| Using a crossbow or bow | Dexterity | Agility | Ranged | Aim, weak spots and weapon consistency |
| Operating a firearm | Dexterity | Insight | Ranged / Firearms | Accuracy, composure, informed target selection |
| Medical treatment | Insight | Care, Dexterity | Medicine | Reliable diagnosis/application and patient outcomes |
| Teaching a youth | Insight or Care | Dexterity in applicable disciplines | Education | More effective education opportunities and learning support |
| Navigating an expedition | Insight | Endurance | Exploration | Route assessment, hazards and expedition resilience |

Examples are gameplay proposals, not a fixed recipe list or data schema. Some work requires both force and fine control (smithing is not **only** Might; bows require equipment and training). Jobs should vary by specialization and progression, preventing one dominant stat from taking over the economy.

## 3A. Tie the abstract attributes to current game mechanics

**The owner specified Endurance for Construction and Intelligence for Research and pack/team leadership, alongside a confirmed six-way Dexterity/Might × Impact/Pierce/Slash weapon taxonomy.** Detailed combat/AI integration and weapon definitions are in [15 Combat, Leadership and Current-System Integration](15-pve-exploration-and-combat.md).

| Owner idea | Existing implementation verified in the Godot repository | Future integration (PROPOSED) |
|---|---|---|
| **Endurance -> building** | [BuildPlacer](../../game/scripts/world/build_placer.gd) currently places complete buildings from kits and awards +8 Construction XP; [Vitals](../../game/scripts/combat/vitals.gd) manages Energy/Exhaustion and fatigue penalties | Use Endurance for sustainable **blueprint worksite** construction shifts, resting/rotation and reduced exertion fatigue. Construction skill still governs proficiency and unlocks; new unfinished-worksite labor doesn't exist yet |
| **Intelligence -> research** | [12 skill trees](../../game/data/skills/trees.json) include research-gate **metadata** and unlock nodes, while [SkillState](../../game/scripts/skills/skill_state.gd) handles proficiency/SP; a staffed Research worksite/tech project is not an existing implementation | Intelligence + learned Research skill support tribe-wide research projects, within skill/item-level and resource gates |
| **Intelligence + Might/Dexterity -> alpha leader** | [CreatureBrain](../../game/scripts/creatures/brains/creature_brain.gd) selects strongest alpha by species tier, HP, attack/defense; [RaptorPackBrain](../../game/scripts/creatures/brains/raptor_pack_brain.gd) inherits targets and coordinates flanking; [PetBrain](../../game/scripts/creatures/brains/pet_brain.gd) implements Guard/Attack/Heel | Add leadership intelligence controlling target priority, rally and coordinated formations; preserve combat credibility. Whether Intelligence affects alpha **selection** or only tactics remains OPEN |
| **Dexterity/Might × 3 damage types** | [Combat counters](../../game/data/combat_counters.json) already model **blunt/pierce/cut** against creature families; [weapons](../design/weapons.md) include bows, axes, clubs, spear, crossbow | Primary-use attribute + damage channel per weapon **attack mode**, using Impact -> internal blunt, Pierce -> pierce and Slash -> cut mapping, learned Melee/Ranged separately; see the owner's exact 6-cell matrix in [15](15-pve-exploration-and-combat.md) |
| **IV/EV cross-domain potential** | [CreatureGenetics](../../game/scripts/creatures/creature_genetics.gd) currently saves seven combat-specific stats including Accuracy, but **no Intelligence and no human shared-attribute data** | New human IV/EV schema and potentially new creature Intelligence/genetic stat must be designed explicitly, without silently replacing current save data |

**Skill-tree preservation:** Maintain the twelve existing categories unless the owner approves a redesign. Attributes modify fitness for a task; **profession practice is still earned**. Example: a high-Int human with no Command training isn't magically a perfect alpha; an Endurance-rich builder without Construction skills cannot erect sophisticated structures. Keep item level gates strict.

**Leadership effects should be behavioral and bounded:** Focus Fire, Rally, coordinated Flank, Hold/Retreat and Protect Support can reuse existing commands and pack target selection. No indefinite global damage buffs or unlimited Expedition slots. Distinguish wild-animal instinct leadership from trainable human/dino expedition command.

## 3B. Dinosaur builds: species anatomy constrains the move, IVs express the specialization

Each attack has an **explicit archetype** rather than stamping a single type on the whole creature. The shared IVs are genetically fixed potential; **which move it uses and how well** also depend on species anatomy, its available attack clips, progression/training and tactic.

**OWNER EXAMPLE, proposed future Brontosaurus:** An enormous dinosaur with **extremely high HP but low defense, especially weak to Slash**. **DS Dexterity/Slash** is a long-range tail-whip specialist. **MI Might/Impact** is a heavy stomper. A mixed-IV specimen can support both. **Current game contains Brachiosaurus (not Brontosaurus)** with a `titan` archetype, large defense and strong **resistance** to the `cut` channel; this is a *design conflict* requiring a new creature/defense-family specification, not a change to the existing titan's stats without approval.

**Stegosaurus (already present):** The four-spiked **thagomizer** normally uses **Pierce**. **MP Might/Pierce** is a heavy puncturing tail drive; **DP Dexterity/Pierce** is a carefully aimed tail-spike thrust. **DS Dexterity/Slash** could be a *separate glancing-rake move* that deals less piercing force but exploits soft targets and existing bleed effects. The current Stegosaurus has `spiked_tail` archetype and `deep_bleed`, not these new attack-selection stat checks yet. Impact would require a visibly blunt tail-base/body contact rather than automatically labeling every spike sweep Impact.

**Core rock-paper-scissors target (PROPOSED, not mechanically balanced yet):** **Impact** versus hard armor/shell; **Pierce** versus mobile targets or targeted defensive openings; **Slash** versus low-defense, high-HP flesh. These are **matchup roles** not genetic stats or magic constants. Existing status/counter formulas and resistance families need auditing because the current `giant` family resists `cut` rather than being Slash-weak. Never silently multiply all bleeding by target max HP.

[Detailed anatomy, combat taxonomy and current code compatibility](15-pve-exploration-and-combat.md).

## 4. One character, four fundamentally different progression sources

**CONFIRMED pre-existing concepts:**
1. **IVs / genes**: inheritable long-term potential, species/body variability and appearance. Never inherited as trained profession XP.
2. **EVs**: developed potential via childhood nutrition and training/experience; exact attribution of childhood nutrition to realized stats vs EV categories remains OPEN.
3. **Personal level and learned skills**: one persistent career per person, not account-wide power. Level unlocks personal item equip and other progression. A newly adopted descendant does not gain prior avatar's level.
4. **Equipped items, workstations and material traits**: real external inputs; **strict individual item-level requirements** apply even to bought/looted/gifted gear.

**Owner-approved inherited IV relationship:** **Dexterity IV and Might IV** are inherent to the individual, preserved through their career and captivity/owner transfer. Their values should not be changed simply by crafting, fighting or leveling. **OPEN:** whether a separate EV layer can improve *expressed performance* for Dexterity/Might without rewriting base IV, and how that coexists with the current animal genetics stats (`accuracy`, `melee_attack`, seven total existing stats). Maintaining existing save/roster IDs is mandatory.

**PROPOSED conceptual model:**
- **Effective attribute** = inherited baseline/potential + expressed upbringing outcomes + accumulated attribute EV/training + legitimate temporary effects (food, status, equipment); bounded by explicitly designed curves/caps.
- **Combat outcome** = action-specific attribute weights + learned combat discipline + weapon/equip level/durability + terrain/status + tactical situation.
- **Craft outcome** = relevant shared attribute weights + profession proficiency + workstation/tools + material level/trait inheritance + recipe difficulty.
- **Level XP**, **profession XP**, and **attribute EVs** must be distinguishable. Do not award all three identically for every repetitive action or make buying rare materials a shortcut to personal mastery.
- **Craft quality/effects** must not invent rare positive material traits out of nothing: preserve traceability and balancing with signed ingredient traits. Attributes may improve workmanship, reduce defect chances, adjust work speed/energy, or optimize existing traits **within constrained limits**. Which is most important remains OPEN.

No coefficients above are locked. Recommend initially giving profession skill the dominant effect on *craft quality*, attributes a noticeable but bounded effect on *handling, consistency or speed*, and the ingredients/station their own irreplaceable roles.

## 5. Shared attributes create interesting dual-specialists, with a training-exploit risk

**Intended interesting characters:**
- A strong early miner slowly becomes an able physical survivor and eventually studies Smithing.
- A precision-oriented fletcher learns Ranged combat; their archery needs additional weapon practice.
- A specialized doctor with high Insight and Care also improves a settlement's preparedness while taking a support role in battle.
- An expert melee veteran brings strong heavy-forging aptitude but still must learn the steps/recipes to build a fine sword.
- A young adult inherits exceptional Dexterity IVs, receives nurturing and education, then chooses Tailoring or Ranged practice (or both); their adult career skills remain individually earned.

**Design danger:** If AFK smithing automatically raises raw Might EVs quickly, someone can AFK farm melee dominance on an invulnerable private island. If archery trains Dexterity enough to become a master tailor instantly, combat becomes the fastest way to mint high-end crafts.

**PROPOSED anti-skip solution:**
- **Attribute EV gain by activity** is possible but slow, subject to diminishing returns or daily/phase caps; actions earn their **own profession XP much faster** than they raise the underlying attribute.
- **Training transfer is about shared potential, not shared mastered profession**. Might earned in labor is helpful in combat, but Melee still requires practice; Dexterity from shooting helps Tailoring aptitude but not the Tailoring profession's learned steps.
- Progression across legitimate play is desirable; fully automated, risk-free work shouldn't be the most efficient way to create maximum-power PvP characters.
- A worker's actual **item requirements** and tool durability 1-floor rules always apply. A high-Might level-1 adult cannot equip a level-40 hammer, and an IV-exceptional female character can earn equal professional success via skill and training.

**Highest-impact OPEN decision:** Should **working/fighting actually train the underlying shared attribute** (e.g. smithing raises Might EV over time, ranged practice raises Dexterity EV, and those gains carry across domains), or should activities primarily train occupation skills while shared attributes are influenced only by upbringing and special training? A hybrid with **slow attribute EV crossover** is the recommended direction, pending owner choice.

## 6. Age, body switching, generations and prisoner reset

**CONFIRMED other chapters:**
- Offspring move through infancy/childhood/youth **timers** with food requirements and youth education. High-quality food affects eventual expressed stats.
- Apparent adult age and earned career level relate somehow, but biological maturation and personal level are **not identical**.
- Tribe control can switch to a different human without destroying previously earned human careers or the safe base; former played veterans become excellent workers.
- A captured human or dinosaur is a prisoner for **72 real-world hours**, with **game-calculated ransom**. A paid ransom returns **their same IVs, earned level, learned skills and EVs**.
- An unpaid captive, once attacker acquisition is allowed/completed, joins as a **level-1 adult** retaining the **same physical adulthood, identity, appearance and inherited IVs**, but **old XP/learned skill and trained EVs reset**. They must be trained anew. This is not de-aging or another timed upbringing.

**PROPOSED age model:** track **biological life stage / appearance** and **career level** in separate fields. Ordinary level-ups may communicate greater seasoned experience visually, but acquiring an adult at level 1 never turns them into a child. Exact display of literal years, biology-related retirement/death and elder roles remain OPEN.

## 7. UX, AI workers, and fairness requirements

- Each character card could show **Attributes**, **Skills**, **Equipment**, **IV/EV Details** (some inherited potential intentionally undisclosed), **Work Aptitude**, and **Expedition**. A tooltip explains which attribute affects each craft or combat action.
- A worksite job label: 'Heavy Forge: Might primary; Dexterity secondary; Smithing skill required'. Display separately **required level/skill**, **efficiency** and possible **quality** so high Might cannot override missing skill.
- NPC workers choose tasks using actual aptitude + relevant profession, tools, durability and workspace, with a Monitoring Stand allowing manual priority adjustments.
- Keep the owner's fictional average sex/body type preferences as overlapping tendencies without sex-locked careers or an intellect gap. Individual IVs, upbringing and training matter more than a demographic label.
- PvPvE requires a currently controlled level-60 human and future authoritative server enforcement. Raid effective-power ratings must count attributes/EVs, real gear, dino stats, buffs, and whole deployed forces; personal level by itself is not enough to prevent punching down.
- Do not let market equipment or captive IVs bypass equipment level requirements, profession practice, safe-island economics or time-intensive nurturing.

## 8. Acceptance examples

1. Two level-25 workers have equal Smithing skill, same forge and identical ore. One is stronger and may enjoy a **bounded, visible** heavy-forging benefit; the other's high Dexterity may make them better at intricate mechanism production. Neither automatically rolls an impossible rare ingredient trait.
2. A high-Might fighter with minimal Smithing skill cannot instantly produce an elite forged sword from bought ingredients; their Might is helpful, but they must learn the profession.
3. A highly precise tailor with no Ranged experience has useful *potential* but still must train to be an effective bow/crossbow/gun specialist.
4. Training work and weapon use cannot endlessly increase stats through zero-cost automated loops; total level/equip/profession requirements continue to matter.
5. A prisoner acquired after ransom expiry is an adult level-1 person/creature with old appearance and IVs, new EVs/skills and strict level-gated gear.
6. Player can inspect understandable causes of a crafted result without manually calculating six hidden multipliers.

## 9. Workshop questions

1. **Shared EV training:** Should Smithing/Mining gradually improve Might used in melee, and Tailoring/Fletching gradually improve Dexterity used in archery, or should only targeted stat training change EVs?
2. **What do generic attributes change in crafting?** **Speed/energy**, **finish quality and defects**, **trait-expression control**, or a mixture, while personal profession skill remains the main expertise requirement?
3. **Which stats deserve to be primary?** Are Might + Dexterity + Agility + Endurance + Intelligence/Insight sufficient, with Care/Empathy learned as a specialized skill, or should Care be a true sixth general attribute?
4. **Skill UX and specialization:** Do proficiencies follow the historical twelve skill trees, or should crafts (Smithing, Tailoring, Medicine, Teaching) have independent practice/mastery levels and a separate shared-attributes screen?

No unapproved coefficient, EV rate, stat cap, demographic advantage or recipe formula should be treated as final.
