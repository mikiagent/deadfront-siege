# Skills

**Status:** v1, 2026-09-17. Data: `game/data/skills/trees.json`. Source: systems PRD §7, §5.3, Appendix A.

Twelve trees, chained from the root. Node types are **unlock** (new action, recipe or access) and **rate** (a percentage). SP comes from character levels (10 per level to 20, then 12, 14, 16 per band), milestones and Radio University career guides: about 897 at level 60. All twelve trees together cost 2246, and the four production-critical trees alone cost more than a character will ever have. That is the specialisation pressure the PRD requires (§7.3): main two or three trees, buy the rest at the market.

Research gates: past skill 20, every fifth level needs a timed research before the next (20 min at 20→21 up to 3 days at 59→60, Appendix A). Survival has none and simply tracks play. A skill level never exceeds the character level.

Refunds: 5 free unlearns a day, then 30 Warp Gems, max 10 a day. Unlearning capture nodes does **not** release bonded animals in Durango; we keep that as-is (PRD §12.2 exploit) until it proves abusive.

Capture ladder lives in Survival (tiers I–V, PRD §12.1 numbers), as do island access and the bonded-animal cap ranks.


## Persistent human careers and inherited potential (2026-10-25 owner direction)

The existing twelve-tree skills research concerns **individual earned proficiency**. [Tribe/lineage design](tribe-lineage-domain-and-labor.md) now establishes a larger model:

- A human character owns a durable ID, earned level/XP, learned skills, equipment and occupation. **Switching the playable body does not reset or erase any career.** A former avatar's high crafting skill still makes them valuable as an assigned worker. The new avatar begins at its own low level and must learn its own skills.
- Genetics influence inherited *potential / aptitudes / stat distributions*, not transfer of completed research XP/skills from one parent to offspring. Which knowledge is tribe-wide versus individual is **OPEN** and should be made explicit.
- Housing, childcare and productive infrastructure impose lasting population and breeding costs. Human and dinosaur breeding should reward selective lineage development without making generations identical or effectively perfect.
- The baseline-survivor fallback on full human-tribe extinction preserves the ability to continue, with exact remaining tribe/domain/world state **OPEN**.

**Implementation prerequisite:** separate the controller from the human character record, then migrate all save data and make skill allocation, equipment and labor actions reference specific character IDs. Do not keep singleton avatar skill/XP as the sole authoritative source once switching is supported.


## Growth-phase education and sex-independent careers (2026-10-25)

In the new [offspring and identity design](safe-home-expeditions-offspring-and-identity.md), children grow on **timers** using sustained food supplies; food **quality in each growth phase** influences expression of future stats. During a youth-learning period they can study with assigned mentors, teachers or facilities. When adults become controllable they retain **their own personally earned low level and growth history**, not their parents' mastered skills. Nursery and education facilities may enable social/professional opportunities but cannot instantly clone a veteran.

Human sex affects a proposed overlapping *starting distribution* for stature/strength and certain caretaker/heavy-labor role inclinations; **all skills and careers remain available to everyone**. Both sexes have the same baseline intelligence distribution. Women can be capable warriors with bows, crossbows, firearms and tactical training, with exceptional melee warriors possible. Men can specialize as doctors, nurses and educators. Effective educators, nurses, doctors and pharmacists should provide measurable development, recovery and combat-readiness benefits. These are fictional game design parameters, **not claims about real-world universal ability differences**. Numeric probabilities and role modifiers are unapproved until balancing.

## Age tied to earned level; no shortcut through bought gear (2026-10-25)

See the [current progression design](progression-risk-and-island-economy.md).

**Confirmed:** The personal survivor's apparent **age/maturity should be meaningfully related to their personal level**. Human offspring still grow through food-supported timers and an education phase. **Proposed compatibility:** time/care gates babies/children/youth becoming adults; then adult level bands convey youthful, mature, seasoned and veteran presentation, without level gain causing death. Exact literal age and life-span mapping remain open.

**Confirmed market protection requirement:** An individual must not circumvent personal skill/level progression by purchasing, receiving, looting, equipping or inheriting over-leveled gear. Choose one of two rules: **(A)** equipment cannot be equipped until the individual reaches its required personal level (possibly with skill requirements), or **(B)** the item is equippable but **all** its stats, special traits and skill effects are capped at the individual's effective allowed level. **Proposed preference:** A, the strict level gate. This must apply to playable people, NPC workers and captured/recruited people alike. Account-wide history, possession of exceptional crafting materials, rich tribal storage and switching to a descendant are not substitute personal levels. Profession and station prerequisites should also be designed to avoid economic shortcut exploits.

Personal skills and access to high-grade crafting remain distinct from **collective** knowledge/blueprints; allowing a wealthy tribe to retain blueprints does not confer instant individual mastery on a fresh body.
