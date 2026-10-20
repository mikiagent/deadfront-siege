# Claude implementation prompt: Durango-inspired Leveling, Skill Trees and Research

Recreate the activity-based profession progression of *Durango: Wild Lands*, where **character level, per-category skill level, and individual purchased skill nodes are distinct systems**. Integrate with the game rather than building decorative skill menus.

## Three parallel progression layers
1. Character XP and global level 1–60. Most productive activities award overall XP; leveling earns shared Skill Points (SP).
2. Independent XP and category level for each profession. A category **cannot exceed character level**, even when the player has lots of category XP.
3. Branching, prerequisite-based node trees bought with limited shared SP. Reaching a level makes a node eligible but does not automatically purchase it. Some foundational nodes may be automatic.

## Twelve primary categories
Survival (environment, animal capture/taming), Melee (weapons/actions), Ranged (bow/crossbow), Defense (roll/avoidance/training), Gathering (wood/ore/plants), Butchering (animal materials), Cooking (food/recipes), Weapon and Tool Crafting, Tailoring (clothes/armor), Construction, Farming, Processing (raw-material transformation). Make categories extensible. Award XP only on eligible completed actions, scale against difficulty, and prevent repeated/cancelled-action exploits. Defense XP should reward well-timed defensive action, not spam.

## Limited SP and specialization
Historical community estimates include around **830 SP from leveling**, roughly **930 with extras**, versus roughly **3,223 SP to unlock every original skill**. Treat these as approximate historical anchors and scale to the number of nodes actually implemented. The crucial mechanic: players can level many professions but cannot afford all nodes simultaneously. Store SP earned/spent/available, validate every transaction, and award extra SP via appropriate one-time career tasks.

## Node definitions and effects
Each node needs stable ID, category, name, required category level, SP cost, prerequisites, max rank, and typed effect definitions. Support active combat actions, crafting recipes, gathering access, animal capture eligibility, passive bonuses, and multi-rank improvements. Validate missing IDs and dependency cycles. Learning/unlearning nodes must add/remove real gameplay effects without permanent stacking bugs. A recipe learned through SP should be shown but locked when requirements aren't met.

## Research gates
Use optional category research timers before designated transitions (Survival exempt from normal research). Historical durations as configurable starting points:

| Transition | Time |
|---|---|
| 20→21 | 5 minutes |
| 25→26 | 20 minutes |
| 30→31 | 1 hour |
| 35→36 | 2 hours |
| 40→41 | 4 hours |
| 45→46 | 12 hours |
| 50→51 | 24 hours |
| 55→56 | 48 hours |
| 59→60 | 72 hours |

Use authoritative start/end timestamps so timers survive restarts. Handle XP at gated/capped levels consistently.

## Skill resets, stats and guides
Allow SP refunds/respecialization without erasing category XP. Historical player reports suggest five free resets/day, with paid extras; keep configurable, do not require monetization. Handle dependent learned nodes safely. Attributes can include Strength, Dexterity, Agility, Endurance and Intelligence, affected by skill progression, equipment, food, title and temporary effects; don't invent exact original attribute coefficients. Implement profession Career Guides as one-time rewarded objective chains for exploration, crafting, farming and construction.

## UI and integration
Create category overview (global level, category levels and SP), branching hexagonal node trees with prerequisites, level locks, costs, learned/ranked/available states, research progress and reset controls. Wire combat, harvest, butchery, crafting, construction, recipes, and animal capture to these requirements. Test caps, experience, SP accounting, missing prerequisites, reset stat cleanup, timestamped research, one-time career rewards, save/load and UI vs authoritative state.

## Implementation standards
Inspect the existing project and its architecture first. Reuse existing gameplay, inventory, persistence, UI, and network components rather than introducing parallel systems. Implement working code in the project's language and engine, not just pseudocode. Separate definitions/configuration from saved runtime state. Make balancing parameters configurable. Preserve unique instance IDs and enforce atomic ownership/currency transitions. Where multiplayer exists, validate gameplay authoritatively and make retried operations idempotent. Include tests and summarize modified files, verified behavior, assumptions, and remaining limitations.

**Historical fidelity:** Durango: Wild Lands was updated during 2019; published guides can describe different revisions. Distinguish verified original mechanics from contemporary player reports, community reconstruction formulas, and new design choices. Do not claim illustrative values are exact original Nexon server values.
