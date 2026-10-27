# DIN | Species, capture, taming, breeding and persistent dinosaurs

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** TRIBE-03, COMBAT-03/04, MOUNT-01. **Dependencies:** FND, CHR, ISL, CBT, INV.

**Source:** `docs/game-design/11-dinosaurs-and-genetics.md`, `docs/prd/dinosaur-roster-and-3d-pipeline.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
A wild raptor with strong Pierce aptitude and weak endurance is hunted, physically downed, captured and nurtured into a persistent mount; future breeding passes potential, not earned XP/conditioning.

## 2. Confirmed direction and non-goals
Dinosaurs are persistent identifiable creatures with genetically varied, often uneven innate stats. T. rex is intended tameable and rideable though existing JSON contradicts this. Brontosaurus is a future distinct species, not existing Brachiosaurus. Attack and defense identities remain separate.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
SpeciesDef{id,body_mass_kg,geometry_socket_profile,biome,base_stats,allowed_attack_modes,tame_policy,breeding_policy}; DinosaurInstance{id,species_id,individual_iv,trained_ev,xp,health,age_stage,owner_id,training,barding,location}; CaptureCase{id,actor_id,target_id,downed_until,pen_id,status}.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Spawn species with seed/IV table; AI hunts via real nav/vision; capture requires correct downed state, safe pen/free capacity and compatible supplies, consumes them once, transfers species instance ownership. Breeding references two eligible animals, calculates deterministic genetic draw and costs; no cloning parent instance. Mount/socket authorization checks species profile.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
CANDIDATE spawned IV_i = clamp(base_species_iv_i + seeded integer from [-20,20],0,100); bred IV = round_half_up((parentA_iv+parentB_iv)/2 + seeded_delta_i) with limited [-8,8] and inherited cap. For a 60 and 80 parent with delta +3 -> child 73. These are illustrative until owner approves distribution and species-level modifiers.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
A pinned but still standing dino cannot be captured by a pen action requiring Downed; once captured its unique ID remains unchanged. Two parent IVs 60 and 80 and seed delta +3 yield 73. A flagged existing Brachiosaurus must not be auto-relabeled Brontosaurus; T. rex tameability requires future approved data migration.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
Cannot spawn a duplicate creature when saving during capture. Death releases its unique ownership and attached gear by explicit loot rules, not silently; sexual/genetic variation must not enable race to guaranteed max IV without costs; no editing current tyrannosaurus.json in documentation stage.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Taming costs and durations, breeding IV caps, creature death/capture severity, species attack geometry, future Bronto art/roster and T. rex boss-to-tame path.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
