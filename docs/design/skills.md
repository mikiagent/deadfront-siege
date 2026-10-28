# Skills

**Status:** v1.1, 2026-10-27 (adds the Durango reference UI section). Data: `game/data/skills/trees.json`. Source: systems PRD §7, §5.3, Appendix A.

Twelve trees, chained from the root. Node types are **unlock** (new action, recipe or access) and **rate** (a percentage). SP comes from character levels (10 per level to 20, then 12, 14, 16 per band), milestones and Radio University career guides: about 897 at level 60. All twelve trees together cost 2246, and the four production-critical trees alone cost more than a character will ever have. That is the specialisation pressure the PRD requires (§7.3): main two or three trees, buy the rest at the market.

Research gates: past skill 20, every fifth level needs a timed research before the next (20 min at 20→21 up to 3 days at 59→60, Appendix A). Survival has none and simply tracks play. A skill level never exceeds the character level.

Refunds: 5 free unlearns a day, then 30 Warp Gems, max 10 a day. Unlearning capture nodes does **not** release bonded animals in Durango; we keep that as-is (PRD §12.2 exploit) until it proves abusive.

Capture ladder lives in Survival (tiers I–V, PRD §12.1 numbers), as do island access and the bonded-animal cap ranks.

## Durango reference UI — skill upgrade with SP (owner screenshots, 2026-10-27)

Pasted screenshots of the original skill interface (home grid, an open tree page for Melee, another for Survival's Animal Taming, and a Weapon/Tool node detail; not saved to `docs/reference`). The layout below is the orchestrator's reading — our SP economy and research gates above stay authoritative; the reference informs the UI, not the numbers.

### Home grid (12 tiles + detail rail)
A 3×4 grid of category tiles — Gathering Lv.20, Survival Lv.6, Weapon/Tool Lv.4, Defense Lv.4, Processing Lv.4, Melee Lv.3, Butchering Lv.2, Ranged Lv.1, Cooking Lv.1, Tailoring Lv.1, Construction Lv.1, Farming Lv.1 — each tile an icon with a small progress tick and its level. Some tiles carry a corner dot (Melee, Weapon/Tool, Gathering, Farming, Trading/skills readout) — most plausibly an unspent-XP or unread marker; unverified. Selecting a tile fills the right rail: category name + Lv., a "Skill Level" bar (Melee Lv.3 shows 0 / 1), "Used SP" (0), the category's flavor paragraph ("Keep your friends close, but your enemies closer…"), and the primary **Select Skill** button. The window header always carries both wallet counters plus the SP counter (37 / 45 on this screen).

### Tree page (SP purchase)
Opening a category swaps to a horizontal node field under level columns — Lv. 5, 15, 25, 35, 45, 55 — with a yellow progress arrow under the header ending at the category's current level. Every node is a hexagon with its **SP cost in a corner tag**:
- **Learned:** cream hex, dark icon, small green check badge; a yellow arrow chains adjacent learned nodes.
- **Purchasable:** white hex.
- **Locked:** dark grey hex, dimmed caption; the dotted column line is the level gate it still needs.

Two independent lines run in parallel (Melee Lv.17 screen): **Melee Weapon Mastery I–VI** and **Melee Weapon Specialization I–VI**, each SP 1 / 2 / 3 / 4 / 5 / 5 down the columns. The left rail lists the tree's menu lines in the same states (Melee: Melee Specialization, Two-Handed Action, Lance Action, Combat Stance, Enhanced Melee Attack, One-Handed Action). Survival's Animal Taming page shows identical furniture at columns Lv. 15 / 20 / 30: Capturing Quadrupedal Dinos I (SP 2) → Capturing Bipedal Dinos I (SP 3) → Capturing Combative Bipedal Dinos I (SP 3, locked) — node specifics live in `durango-prompts/09`. Header on every tree page: category name + Lv. plaque, both wallets, the SP counter (79 / 133 here), close X.

### Node detail rail
Selecting a node opens the right rail: node name, a one-sentence description ("Learn how to make a wooden harpoon used for catching fish."), concrete effect lines ("Capture Ability +7", "Learn to capture" species lists), **Learn <node>** as the primary action, and for recipe-unlock nodes a **Craft → <item>** link that jumps into the crafting browser (see `durango-prompts/04`). A learned node instead shows **Unlearn** — the refund rule above (free daily, then paid) applies to that same button.

Flags to verify when the trees.json UI is drafted: what the tile dots mean; what the "Skill Level x / y" meter counts in research-gated categories vs plain ones; and whether locked node captions hide their names until the column gate is reached.
