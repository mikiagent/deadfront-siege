# 03 | Protected private islands, paid upgrades and migration

**Status:** DRAFT, 2026-10-25. Confirmed player rules are distinguished from proposed implementation and remaining owner questions.
**Related:** [Decisions](decisions.md), [Audit](audit-and-open-questions.md), [Reset islands](04-world-biomes-and-travel.md).

## Player promise
A private island is the safe, expanding-through-replacement heart of the Skyblock-like tribe economy. It cannot be raided by players or animals. Larger protected homes cost substantial in-game resources, have **higher-level natural resource nodes**, and more room for housing, farming, education, fabrication and breeding. Elite people, dinosaurs and treasured gear can live safely here.

## Confirmed home purchase rules
1. Buying the next protected home means **abandoning the old private island and replacing it with a fresh larger one**. It is **not a land-expansion operation** or simultaneous multiple-home ownership.
2. Show the player a preview and request confirmation. After confirmation, **automatically dismantle every eligible building** on the old island. No obligation to tear down everything manually.
3. The paid-upgrade operation refunds **100% of the original invested building materials**. Keep item lots, levels, traits and quantities stable through the transaction.
4. All returned dismantled-building materials go to the special **Ender Chest-style salvage-only recovery box**, not ordinary inventory. Regular storage contents and gathered resources are separate.
5. Workers, human tribe members, dinosaur roster and normal stored items **move separately** from building-material salvage. Their exact migration UI and transit semantics are not locked.
6. The most expensive safe home gives approximately **level-50-to-55** local resource nodes; **level 60+** resources must be found beyond the private home.

## Proposed transaction design
- Display the new island's size, natural resource ceiling, terrain and huge purchase price.
- Summarize structures to dismantle, expected material returns, people/animals and storage to move, and unresolved property such as crops, incubators and worksites.
- On confirmation, freeze relevant transactions, reserve upgrade payment, atomically snapshot old world and generate new one, return salvage once, transfer residents and regular goods once, validate completeness, then commit. On failure, rollback to original world and belongings. **Atomicity and rollback are engineering recommendations.**
- Make the recovery vault accessible before rebuilding; require meaningful labor and placement when reconstructing buildings, but don't force repetitive manual salvaging of the old settlement.

## Separate unstable-island reset
Unstable islands **periodically reset their resources/world state** and **automatically dismantle placed bases into the dismantled-material recovery chest**. This is **not a raid**. The owner confirmed **100% returns for paid private-home upgrades**, but has **not explicitly settled whether unstable reset dismantles yield 100%**. Nor has the owner fixed the handling of active workers, storage contents and animals during reset.

## Open
- Construction material refund identity: original input lots vs recipe equivalents; blueprints, station upgrades, repairs and unfinished worksites.
- Container contents, crops, boats, nests/eggs, residents away on expedition and overloaded vault capacity.
- Exact upgrade tiers/prices/terrain and whether the current 1–60 item-scale extends numerically above 60.
- Private-home save-failure behavior, cancellation, nested equipment and prevention of duplicated items.
- Unstable reset **refund percentage**, warnings and non-building assets.

## Acceptance
- One confirmed purchase produces one abandoned home, one new higher-resource larger home, one 100%-material refund manifest and separately transferred people, animals and ordinary storage.
- Item level and traits are preserved and a saved migration cannot duplicate or delete assets.
- Paid home dismantling rules do not silently grant 100% salvage for enemy demolition or unstable reset.
- A wealthy low-level descendant can own inherited gear but cannot equip it until personally leveled.
