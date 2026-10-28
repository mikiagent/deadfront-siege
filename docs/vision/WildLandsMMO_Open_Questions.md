# Open Questions — Wildlands MMO register

This is the register, not the answer sheet: a question lives here until the owner decides, then it moves into the doc that owns the rule and the register entry is struck. Proposals written elsewhere stay proposals; they are never canon because they are written. Each section is dated and named for its source; cite section (for example `01` Q3) when commenting.

Backlog import still owed: older unresolved items from pre-redesign conversations join later with their own dated section.

## 2026-10-27 — Crafting and materials

Source: `docs/design/durango-prompts/34_crafting_materials_catalog.md` (transcribed historical recipe catalog; research, not canon). Deeper research gaps are § "Open research gaps" in 34 itself; the integration items below are ours.

| # | Question | Why it matters | Lands in |
|---|---|---|---|
| **01** | Adopt the **modular weapon part-chain** (Blade + Handle/Tang/Grip, separate Axe/Hammer Heads, Bow Limb + String, Crossbow Limb + Body, PRO/Improved/Standard tiers) as a first-class recipe layer, or keep today's single-stage hand recipes? | Reshapes `recipes.json` schema, part taxonomy (04 §11, 12 §5), the market value of intermediates, and 04's formula structure. | 04, phase-map crafting features |
| **02** | Which historical **workstations** exist and at what level gates: Medical Lab, Weapon Workbench, Tailoring Workbench, Loom, Simple vs Advanced Kiln, Oven/Stove/Kitchen tiers (34 gates at Workbench Lv.15/35/40/50/55/60, Kiln 35/55, Weapon Workbench 50)? | 30 §12 lists only the workbench chain + racks/looms; 34 adds named specialist benches with station-level recipe gating. | 30, 10, world-design.md stations |
| **03** | Adopt the historical **material tier naming** (Trimmed → Processed across wood/stone/bone/leather; High Purity Metal; size-tier ops: Cut Pillar, Long Stick, Combined Metal, Combined → Large), or map them onto our trait vocabulary? | Touches the signed-trait catalog, 11's transformation ops, and every recipe above. Applies to **Antiserum Material / Slime Material / Topping** (medical + cooking slots) too. | Traits doc §families, 11, 04 |
| **04** | 34 marks most processing **deltas** as restoration data (High Density +2, Lightweight +2, Tough Fiber +2, Firm +2/Low Density +1…). Confirm they stay community-reconstructed, never canon, until extracted original data lands. | 04/11 already cite the same ops; 34's tabulation makes the provenance boundary explicit. | 04, 11 |
| **05** | The restoration reports **22 modification recipes** (item modification family) — entirely unaddressed on our side. Needed at all, and if so what do they modify (traits? durability?)? | A missing economy sink if adopted; 06 has no modification listings. | 04, 06 |
| **06** | Food/medicine recipes to adopt from 34: **Survival Food** (1 Bug + 3 Fruit/Grain, Cooking Fire Lv.45+ — the expedition food), **antiserum family** (plant/bug/poison-sac + slime; Medical Lab Lv.40+), **medical items** (Anti-Bleeding Agent, Painkiller Root), **pizza** (2 Bread Dough + 1 Cheese + 1 Topping). | Extends 08 beyond buffs into medicine; our build has bandages only. Station levels come from 02. | 08, current recipes data |
| **07** | **Fishing has no loop spec.** 34 lists a Metal Harpoon and our UI pulls showed a Wooden Harpoon node (12/09), but no fishing/capture-with-harpoon loop is documented anywhere. | Unclear ownership for harpoon recipes + fish species + fishing actions. | 07 or a future spec |
| **08** | **Tag hygiene: Bow String vs Bowstring.** 34 flags the source itself confusing the pair. Our recipe slots bind by tags (30 §4), so string/tang/grip need fixed data tags distinct from display names. | averts a broken-binding class of bug before any part-chain ships. | 30, 04 |
| **09** | **"PRO-Class" naming.** Keep the historical tier word in reference docs but name our tiers differently (era vocabulary, game-vision §22)? | Cosmetic; affects every weapon recipe table if 01 is adopted. | weapons.md |
| **10** | **88 name-only recipes carry no quantities.** Rule: unquantified (and unverified, like the axe-section title-inferred rows) recipes cannot enter build data as real recipes — they stay reference rows until extracted data lands with lawful access. | Keeps `docs/current/recipes.md` (generated) and balance honest; also backs the verdict on Q4. | Owner canon rule, 04 |

## 2026-10-28 — Assumptions taken by the build (defaults in code, tune any time)

Source: merges into `claude/mmo-overhaul` on 2026-10-28. Each is marked `# ASSUMPTION` where it lives; the build runs on the default until the owner changes it.

| # | Default taken | Where | Why it matters |
|---|---|---|---|
| **A1** | A rolled trait carries a level 1..60 (the item level range); the market refuses anything else. | ECON `limits.json`, report `claude-econ2.md` | No doc defines trait levels; tighter bounds would change which crafted items can be listed. |
| **A2** | `flawless_bonus` is 0..1 and raises the durability cap through `rules.json`, never the item's own field. | ECON validator | Keeps forged durability off the market. |
| **A3** | The 30-minute trade lock runs on wall-clock time, not play time. | ECON (carried over) | Affects how fast a fresh survivor can sell. |
| **A4** | Traded pets move as pet records; the owner rule (2026-10-19) says as cages. Switch with the caged-pets work. | ECON / roadmap `caged-pets` | Contract 6.1 drift. |
| **A5** | Base butchering parts keep at least 1 unit even with the 0.75x no-knife multiplier. | W2-GATHER `ButcherLoot` | Without it a poison kill could yield nothing. |
| **A6** | **Open:** keyed outputs by slot-1 material (`outputs_by_primary`, design doc §7) ship as a mechanism only; no recipe uses them. Which recipe families get keyed outputs (for example work knife/axe/pick: stone → stone tool, bone → bone tool), and does a keyed output need its own cost and requirements? | OUTPUTS `Crafting.output_for`, report `claude-outputs.md` | Keying the work recipes by bone would make a bone axe/pick from 1 bone without the `work_pick` node (the `bone_*` recipes cost 2 and need it), and a bone knife by hand without a workbench. |

## Parked by other docs

Each vision doc's unresolved points remain inside that doc until the workshop; the sections listed below are the owners' pointers, collected here only for reachability:

- Loss/revival: `WildLandsMMO_Loss_Recruitment_Revival.md` (deciders section).
- Combat coefficients: `WildLandsMMO_Combat_Math.md` (closing questions).
- Crafting/building weights + 100% home-move refund: `WildLandsMMO_Crafting_Building_Math.md`.
- Traits/gathering/purification rates: `WildLandsMMO_Traits_Gathering_Processing_Math.md` (the 96%/7% figures are not approved).
- Vision unknowns: `WildLandsMMO_Game_Vision.md` (§5 revival, §20 UI, …).
