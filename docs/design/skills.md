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
