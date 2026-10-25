# DEADFRONT | Canonical game design (v2)

**Status:** New design workspace created 2026-10-25. First detailed drafts exist for **private-island migration, world resets, and PvPvE prisoners/ransom**. The rest are still planned chapters. Do not treat drafts as implemented/approved formulas. **Do not implement chapters that have not been reviewed and approved by the product owner.**

## Purpose

DEADFRONT's intended identity is **Minecraft Skyblock-style protected-island economic growth + Durango-style expedition/gathering/attribute crafting + ARK-style creatures, lineage and optional territorial danger**. A long-lived protected tribe economy is the primary game; PvE expedition play advances it; optional level-60 PvPvE gives committed endgame players a high-risk branch. Each character personally earns levels and skills; material traits and rare inheritance make items and individuals meaningfully distinct.

The October owner decisions live in [Decision Register](decisions.md). Conflicts, unknowns and owner questions live in [Design Audit and Open Questions](audit-and-open-questions.md).

**Authority for design work:**
1. Latest explicit player/owner answers.
2. This directory's confirmed decisions and, when written, approved subsystem specs.
3. Newer `docs/design/` owner-directed design briefs, read with their explicit CONFIRMED vs PROPOSED markers.
4. Historical `docs/prd/` Durango research and `docs/orchestration/` planning prompts: **references, not current DEADFRONT requirements**.
5. `HANDOFF.md`, `GAUNTLET.md`, code and test documentation: authoritative for *how the existing implementation works and is shipped*, not a veto against future design decisions.

Do not silently turn a proposal, historical observation or example number into a confirmed rule. Mark each specification item **CONFIRMED**, **PROPOSED**, **OPEN** or **IMPLEMENTED/VERIFIED** separately. A new requirement can be confirmed without being in the game yet.

## Confirmed backbone

- **Every player has a permanently attack-proof private island.** Home personnel, dinosaurs, gear, loot and production never become raidable because of wealth or level.
- **Safe island upgrades replace, rather than expand, the home.** The player pays a substantial price for a fresh larger home island with higher-level natural resource nodes. The old island is abandoned; the resources obtained from **dismantling** buildings go into a dedicated Ender Chest-style recovery box. Transfer rules for people, pets, storage, placed worksites and undismantled buildings are OPEN.
- **Personal character level is earned.** Switching to a new member does not reset the tribe/base or the former avatar; a newly controlled person begins with their own level. High-level bought, dropped, gifted, looted or crafted equipment is **unequippable** until the equipping individual's level requirement is satisfied.
- **Level 60 unlocks level-60 islands and access to the optional PvPvE frontier.** The **tribe keeps the unlock**, but the **currently controlled human must personally be level 60** to enter PvPvE; a lower-level successor cannot use the inherited unlock until leveled.
- **No scheduled player-selected raid vulnerability windows.** Remote PvE/PvPvE settlements are exposed; the protected home never is. Raiding should be expensive, limited and defensible, with anti-punching-down and local-alpha progression. Important exposed prizes can include dismantled outpost materials, equipped items, unshipped cargo, and captured humans/dinosaurs; exact capture and loss rules remain OPEN.
- **Boats may depart during active remote raids.** Boat + harbor levels and special traits limit real cargo capacity. A departed vessel traveling home, with its cargo/crew, is protected from all raids or interception; goods still in contested storage or dock loading remain at risk.
- **Generations are persistent characters**, with expensive resource-intensive reproduction, timed food-quality-dependent upbringing, youth education and inherited potential. Former avatars become experienced workers; dinosaurs have separate breeding and rosters. Total human loss yields a new mediocre survivor, while the protected home is not attacked.
- **Workers have individual equipment, skills and jobs.** Mining/lumber sites, hauling, a Monitoring Stand for preferences, and default stopping automatic work tools at 1 durability are intended.
- **Crafting and building merge.** Unlock/craft blueprint items in one crafting UI; place unfinished worksites; deliver materials and labor.
- **Materials are distinct.** Nearly all gathered lots should have consequential drawbacks and rare positives; traits especially matter for lasting tools, weapons and structures, while food changes temporary effects. Multi-item inventory selection, lock/drop/destroy, explicit effect values and sit/sleep recovery are part of the confirmed direction.
- **Three mixed Expedition slots.** Human/dinosaur rider pair counts as one tactical slot, shifting dinosaur instincts toward coordinated mounted movement and weapon use.

**New custody rule:** captured humans/dinosaurs enter prisoner status with a **time-limited ransom**. If the owner pays by the deadline they return; if not, the attacking player may **claim/acquire** them. Details of clock duration, automatic pricing, manual claim, allegiance and offline notifications remain OPEN. **Island rule:** only **constructed PvPvE settlements** face player raids; PvE built settlements face dinosaur/animal raids; unstable islands **reset** resource nodes and automatically dismantle bases into the recovery chest. Paid safe home upgrades return 100% materials; unstable reset refund rate remains OPEN.

## Proposed chapter library

The following are **planned chapter paths**. The files do not yet exist unless linked elsewhere. Create and lock them incrementally after the relevant owner questions are answered, rather than scaffolding empty or fabricated specifications.

| Draft chapter | Scope |
|---|---|
| `01-core-loop-and-onboarding.md` | First hour, fantasy, beginner experience, PvE vs PvPvE choice |
| `02-characters-levels-and-age.md` | Individual level, XP, skill trees, adult age, equipment requirements, level-60 entry |
| [03-private-islands-and-upgrade-migration.md](03-private-islands-and-upgrade-migration.md) | Protected homes, island size tiers, abandonment, salvage vault, map generation |
| [04-world-biomes-and-travel.md](04-world-biomes-and-travel.md) | PvE regions, level-60 frontier, instability, ports, route unlocking |
| `05-material-level-traits-and-loot.md` | Signed trait rolls, rarity, charm odds, gathering, processing, premium material hunting |
| `06-inventory-equipment-and-storage.md` | Stacking, bag slots, batch selection, locks, overflow, death drops, vault |
| `07-crafting-processing-and-food.md` | Recipes, inheritance, item level, crafting quality, buffs, agriculture |
| `08-blueprints-worksites-and-building.md` | Unlocks, craftable blueprint items, material deposits, labor, dismantling |
| `09-tribe-population-and-recruitment.md` | Unique persons, housing/support capacity, exiled wanderers, allegiance |
| `10-human-genetics-upbringing-and-education.md` | Parentage, expense, food stages, inherited potential, visibility and physical variation |
| `11-dinosaurs-and-genetics.md` | Wild captures, spiky stats, species AI, husbandry, breeding, permanence |
| `12-expedition-mounts-and-command.md` | Three slots, riders as composites, human followers, inventory, mounted behavior |
| `13-workers-automation-and-logistics.md` | Mining/lumber sites, monitoring stand, work orders, tool durability, boat shipping |
| `14-vitals-rest-status-and-medicine.md` | Exhaustion, Energy, continuous sleep, Sit, effect tooltip, medical/education buffs |
| `15-pve-exploration-and-combat.md` | Level ladders, hunting, capture, hazards, guards, PvE raids |
| [16-pvp-frontier-siege-and-captives.md](16-pvp-frontier-siege-and-captives.md) | Level-60 entry, power class, local alphas, raid economics, capture and defender rules |
| `17-economy-market-and-trading.md` | Currency, island sinks, sales, anti-progression bypass, profitable non-PvP economy |
| `18-ui-controls-accessibility.md` | Desktop/touch/gamepad, menus, hover/tap, compact HUD, status and trait visibility |
| `19-save-data-network-and-security.md` | Character IDs, home migration, items/vault, authority, market, raid anti-exploits |
| `20-monetization-and-live-operations.md` | Fair cosmetics, identity/account, anti-pay-to-win, analytics, live balancing |
| `21-tutorial-missions-and-progression-tests.md` | Teaching systems, levels 1-60, first tame, island upgrade, optional PvPvE teaching |

## Format for each future chapter

1. **Status and owner decisions** with date; purpose/non-goals.
2. **Player fantasy and concrete playable example.**
3. **Rules and invariants:** exact applicability and restrictions.
4. **Progression/unlocks/costs** (mark sample numbers as provisional).
5. **State machine, data contracts and item/character ownership.**
6. **UX:** desktop and touch states, tooltips, error messages.
7. **Economy and exploit constraints.**
8. **Save migration, failure/recovery, offline and multiplayer rules.**
9. **Test acceptance scenarios** for ordinary/edge/abuse cases.
10. **Remaining owner questions** and explicit alternatives.

## Execution order for design, not feature implementation

1. Lock **character level/account unlock/home migration**. These underpin access, item progression and saves.
2. Lock **PvPvE opt-in and irreversible loss/capture**. These underpin whether the permanent tribe fantasy is sustainable.
3. Lock **material and crafting quality**. These underpin equipment value, blueprint construction and economic pricing.
4. Lock **tribe identity, offspring and automation**. These underpin body switching, workers, mounts and raids.
5. Lock **tech, UX, monetization and acceptance plans** only after the above economic invariants are clear.

The current code and historical documents remain untouched until the user approves design chapters and requests implementation.
