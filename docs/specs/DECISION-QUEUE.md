# DEADFRONT | Owner decision queue and conflict-resolution log

**Stage:** NEEDS OWNER DECISION. These are the **ten highest-impact outstanding decisions** from `docs/game-design/audit-and-open-questions.md`, newer confirmed owner rules and the detailed chapter analyses. Candidate picks are **recommendations, not owner approvals**. This queue does not request the owner to answer everything before safe engineering-only scaffolding begins.

## 1. P0-D01 | First release target and build boundary
**Known:** Godot 4.7.1 typed GDScript. Historical AGENTS mobile-first; HANDOFF current desktop Chrome ship gate; native iOS temporarily parked. **Choices:** (A) desktop browser-first plus touch-preservation, (B) native phone-first with desktop development, (C) synchronized both. **Recommended candidate:** A initially, explicitly preserve touch input abstraction. **Affects:** project render/export, UI safe areas, performance and QA.

## 2. P0-D02 | Individual XP/attributes/professions
**Known:** own levels, strict item-level gate, Dexterity/Might inherited IVs, Endurance construction, Intelligence research/leadership, 60 requirement personally for PvPvE. **Choices:** (A) fixed IV + separate skill XP + training-only EV, (B) skill actions passively raise EV slowly/capped, (C) work action drives all stats. **Candidate:** B with strict daily cap and separate profession skills; finalize XP curve, EV influence and level/age map. **Affects:** combat, worker/economy exploits, offspring progression.

## 3. P0-D03 | Signed trait RNG, lineage and duplicate fusion
**Known:** near-all-negative lots, rare positives; two compatible main lots both transfer positive and negative traits, duplicate IDs diminish/cap with origin provenance; no free purity. **Choices:** duplicate `max + k*min` with cap; total diminishing powers; lineage-signature weighted resolver. **Candidate:** max+0.25*other, hard cap by trait, single origin counted once, roll probabilities 90% negative/8% positive/2% neutral solely as playtest sample. **Affects:** entire economy, craft output, food, buildings and saves.

## 4. P0-D04 | Material processing, source coverage and first playable content
**Known:** one craft menu, blueprint/worksite, real intermediate components and six weapon classes × three eras. Some component nodes/items and iron source/smelter are not implemented in current content. **Choices:** small first-hour subset approved now vs full 18 recipe batch approval. **Candidate:** approve a small functional starting recipe chain and explicit source-provenance table, defer expensive later-era items until their source nodes exist. **Affects:** M1-M4 and every inventory operation.

## 5. P0-D05 | Home migration, unstable resets, material recovery contradiction
**Known:** HOME-02/03 home move => 100% installed material salvage; WORLD-01 says unstable island resets automatically dismantle base materials to vault; newer building reference suggests abandoned unstable structures/resources lost, recorded as WORLD-02 conflict. **Choices:** (A) unstable resets salvage some defined fraction to vault, (B) structure entirely lost, (C) refunds depend on packing/time/structure stability. **Candidate:** A with 50% recovered installed material quantities, explicit advance warnings and occupant evacuation; this is NOT owner-approved. **Affects:** construction economy, insurance, save atomicity and player trust. Never apply this 50% to protected home migration.

## 6. P1-D06 | Dinosaur mass/armor/eligibility and six-mode damage math
**Known:** physical added mass aids valid stomps/tackles but burdens turning, defender mass reduces stagger, heavy plate blocks ordinary raptor Pounce Pin before status; T. rex tameable and rideable in future while code currently disagrees. **Choices:** species-by-species realistic geometry/mass + capped sqrt force, versus abstract weight classes. **Candidate:** mass/geometry data by species, capped diminishing sqrt, separate local armor zones. **Affects:** combat, saddle sockets, skill balance, creature assets, PvP ratings.

## 7. P1-D07 | Expedition slots and platform-saddle crew
**Known:** three companion slots and follower human+dino rider pair = one; platform max 1 crewed, 2 autos, 1 ammo box; player/tribe swap driver/gunner. **OPEN:** avatar vs party slot, extra crew cost, seat transitions, allowed species, who can drive when player guns. **Candidate:** keep controlled avatar outside the 3 follower slots, count distinct real NPC gunner as another follower slot where separately deployed; prevent free auto duplication. **Affects:** follower count, AI, UI, fairness.

## 8. P1-D08 | Workers, supplies and offline catch-up
**Known:** people have jobs and equipment, work tools stop at 1 durability, physical site supply/hauling is required. **Choices:** (A) offline time simulated with bounded realistic input/output, (B) work pauses offline, (C) capped offline passive grants. **Candidate:** A with persisted finite node input, travel/labor time and safe-area limits; never produce without stock. **Affects:** economy and resource scarcity, mobile session design, anti-AFK exploitation.

## 9. P2-D09 | Optional frontier fairness and 72h captive price
**Known:** homes safe; PvPvE settlements built only; personally level60 plus tribe unlock; no raid window; 72 real hours for game-set ransom; paid returns original earned career, unpaid attacker gets same adult/IV but level1 empty career. **OPEN:** actual currency formula, outage/claim semantics, cooldowns, force-class matchmaking, region risk classes. **Candidate:** regional effective-force bands, meaningful prepaid siege supplies, server-clock deadline with explicit outage grace. **Affects:** online architecture, coercion/grief safeguards and balancing. Must be locked before PvP public release.

## 10. P1-D10 | Trade, food economy, and final technology ceiling
**Known:** owner favors primitive world, late metallurgy, realistic material/meal/structure perks, packed finished-building trade, real food spoilage; no clear firearms/modern power ceiling. **Choices:** late iron/clockwork as ceiling, selective firearms, unrestricted modern tech. **Candidate:** late iron and mechanical primitive automatic sentries, no modern firearms in first release. Set food category lifetimes and sale tax only after testing provisioning. **Affects:** 18 weapon roster, sentry plausibility, ingredient sources, economy liquidity.

## Other tracked unresolved decisions

Housing and offspring time, aging/death, robot-free auto-sentry targeting, NPC crew gunner/driver training, critical hit formula, rare trait cap, packing empty-inventory semantics, worker meals, station power, harbor load rates, PvE raid drops, monetization, accessibility and target hardware are also open. Review `REGISTRY.md` and each system's final section for full list. Those are not automatically resolved by the ten picks.

## Promotion process

At approval, append an immutable row to `docs/game-design/decisions.md` stating ID, owner answer, approval date and affected versioned spec/fixture hashes; then update the relevant candidate model and rerun fixture validation. Do not quietly change old owner entries or present this queue as already resolved.
