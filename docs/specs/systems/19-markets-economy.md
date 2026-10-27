# ECO | Trade, currency, finite inputs, crafted goods and progression fairness

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** ECO-01/02, BUILD-03, LVL-02, PVP-05. **Dependencies:** FND, INV, CRF, BLD, LOG, CHR. **Source:** `docs/design/economy.md`, `docs/design/progression-risk-and-island-economy.md`.

## Player fantasy, scope and non-goals
A builder packages a unique treated-plank house with creator attribution and signed traits, lists it for sale, and buyer redeploys it with the same identity, but the buyer's level-1 human still cannot equip a bought level-50 weapon.

**Confirmed owner intent:** Protected-home production and non-PvP trading are viable core progression, not inferior to raiding. Goods with traits, material sources and work ownership have distinct value; trade cannot bypass personal-level equip restrictions. Finished constructed objects remain unique through sale and redeploy.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
CurrencyLedger{owner_id,balance_minor_units,escrow_minor_units}; Listing{id,seller_id,item_or_structure_id,price_minor_units,expires_utc,state}; TradeReceipt{listing_id,buyer_id,seller_id,actual_paid,item_id,tax,command_id}. Market inventory in escrow is still uniquely owned/reserved.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
`List`: verify item can legally transfer (no equipped actor, no current room residents, packaged structure unloaded), reserve item in unique escrow. `Buy`: validate buyer funds, listing open, tax parameters, space for delivered goods; atomically debit buyer, credit seller minus tax, transfer escrow item, mark SOLD and record receipt. Cancel returns same item. Client UI cannot mutate listings bypassing command handlers.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
CANDIDATE currency is integer minor units. Sale price p>=1; proposed tax floor(p*0.03), seller_credit=p-tax, buyer_debit=p. Conservation across accounts and treasury: buyer_debit = seller_credit + tax. For p=1000 minor units, tax=30, seller=970. NPC floor/ceiling prices require supply model; do not treat as approved economy.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
Buyer balance 1200 buys listed unique structure priced 1000 -> buyer 200, seller +970 and treasury +30; structure id and material traits unchanged and listing SOLD. Retrying purchase id returns same receipt, not a second credit. Buyer cannot equip purchased sword level50 at character level49.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Canceled and sold listing mutually exclusive; locked quest goods and human/animal actors cannot pass as manufactured structure inventory. Avoid client-offline trading claims until authoritative transaction service. Prohibit sales to self for duplication/XP abuse via trade volumes; no arbitrary tax creates free money.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Currency name/source/sinks, final tax/listing fees, accessible global market topology, NPC buy orders, post-sale delivery/storage and trade of live animals.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
