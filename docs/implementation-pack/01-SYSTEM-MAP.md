# DEADFRONT | System context map and dependency graph

**Status:** Navigation and proposed engineering boundaries. The linked design chapters are drafts unless explicitly approved. The map defines coupling, not final implementation detail.

## Core graph

```text
Account / Save / IDs
    -> Tribe & unique Human identities -> Levels / IVs / EVs / Learned Skills
    -> Animal identities / Species / Genetics / Training
    -> Island instances / Zones / Territory / World reset lifecycle
    -> Inventory ownership / material lots / equipment gates
           -> Harvest & loot -> Trait rolls -> Processing & fusion
           -> Recipes / stations / tools / food & spoilage
           -> Blueprints -> physical worksite -> labor -> packed building
           -> Equipment -> combat / mounts / turrets
    -> Expedition roster / transport / boat cargo -> contested outposts
    -> Trade and currency / workers / reproduction / optional PvPvE custody
    -> UI and interaction, save/load, tests and telemetry across every node
```

**Important cycle:** Material traits affect food, crafted gear, saddles, building properties and ship cargo. Construction changes worker productivity; workers produce processed components; training and expedition access change acquisition. Break code cycles with stable entity IDs, data definitions and bounded domain events, not direct cross-subsystem mutations.

## Canonical systems and contracts

| ID | Domain | Design source | Dependencies / contract |
|---|---|---|---|
| S00 | Player-facing core loop and tutorial | Planned `docs/game-design/01-core-loop-and-onboarding.md` | All slice domains; first-hour metrics and failure paths OPEN |
| S01 | Unique IDs, saves, migration, permissions | Planned `19-save-data-network-and-security.md` | Foundation for every persistent entity; build spec missing |
| S02 | Human identity, levels, genes, skills | `02-characters-levels-and-age.md` | Strict gear gate, level-60 entry, separate innate and trained stats |
| S03 | Tribe roster, upbringing, labor & research | `docs/design/tribe-lineage-domain-and-labor.md`, planned `09`, `10`, `13` | Actor ownership, housing, supply, work orders; math and detailed workflow open |
| S04 | Islands, biome nodes, reset/migration | `03-private-islands-and-upgrade-migration.md`, `04-world-biomes-and-travel.md` | Island identities, home safety, vault and atomic migration |
| S05 | Material lots, signed traits, level, loot | `05-material-level-traits-and-loot.md` | Source-specific traits, deterministic fusion and provenance |
| S06 | Inventories, equipment, storage & vault | `06-inventory-equipment-and-storage.md` | Identity, stack compatibility, mass, transfer atomicity, equipment gates |
| S07 | Production, processing, food & spoilage | `07-crafting-processing-and-food.md`, `23-weapons-and-material-crafting-progression.md` | S05/S06; ingredients and stations must actually exist |
| S08 | Blueprints, worksites, structures, packing | `08-blueprints-worksites-and-building.md` | S05-S07, construction knowledge, worker inputs, immutable object IDs |
| S09 | Dinosaur ecology, taming & genetics | `11-dinosaurs-and-genetics.md`, `22-dinosaur-mass-armor-and-grappling.md` | Actor stats, species eligibility, physical hit zones |
| S10 | Expedition slots, followers & mounts | `12-expedition-mounts-and-command.md` | S02/S03/S09, roster limits, seat occupancy and AI commands |
| S11 | Combat, armor, status & weapons | `15-pve-exploration-and-combat.md`, `22`, `23` | DI/DP/DS/MI/MP/MS, geometry, item durability, consequence rules |
| S12 | Crewed/automatic turrets, shared ammo | `24-turrets-siege-ammunition-and-guard-crews.md`, `25-platform-saddles-and-mobile-siege.md` | S06/S09/S10/S11, authorizations, atomic ammo, mass |
| S13 | Expedition economy, trading, transport | `docs/design/economy.md`, planned `17-economy-market-and-trading.md` | Unique assets, cargo, remote outposts, transaction proofs |
| S14 | PvE outpost attacks, frontier PvPvE, capture | `16-pvp-frontier-siege-and-captives.md` | Server authority (later), home immunity, 72h custody state machine |
| S15 | UI, input, accessibility, art & tests | `docs/controls.md`, planned `18-ui-controls-accessibility.md`, `GAUNTLET.md` | All domain states; desktop and touch must agree on commands |

All relative numbered design paths above are under `docs/game-design/` except explicitly prefixed paths. "Planned" paths do **not** currently exist. Do not create placeholder code from them.

## Shared entity/ownership contract (proposed base architecture)

- **HumanInstance:** globally unique human ID, tribe ownership, individual level, intrinsic IVs, trained EVs, acquired skills, vitals, equipment inventory ID, role, location, occupancy status. Avatar control is a pointer to one such actor, not a second created actor.
- **DinosaurInstance:** unique dinosaur ID, species, genetics/IVs, learned training, physical mass, fitted equipment IDs, injuries, tame ownership, world/party state.
- **MaterialLot:** distinct provenance and signed trait set; stack only if the approved equivalence contract says safe. Processing never loses traceability needed for downstream construction traits.
- **ItemInstance / Stack:** one authoritative inventory location or equipped socket, never both; equipment has one unique item ID even if visually replicated.
- **IslandInstance:** safe-home vs PvE vs PvPvE zone, revision, resources and structures; a raid permission check must not derive solely from creature level or structure richness.
- **Structure/BlueprintInstance:** unique identity, recipe + committed materials, construction stage, placed geometry, later packaging state, condition and ownership.
- **CargoShipment / CaptiveCase:** durable state machine with timestamps and unique identifiers; transfer between legal states is idempotent and never double-awards rewards.

These fields are an **interface proposal**, not an approved storage schema. Each subsystem spec must fix exact types, invariants, serialization and migration before code begins.

## Recommended first fresh-build dependency path

1. Foundation: Godot bootstrap, input abstractions, stable IDs/save revision, data definitions and automated tests.
2. Playable survivor: move, interact, gather actual resources, show item lots and inventory.
3. Core material chain: level/trait-aware processing, recipe, one workstation, equip gate, full save/load.
4. Combat and fauna: one species with animation, AI, damage/status, capture, tame and small expedition.
5. Home loop: finite storage, blueprint/worksite, safe home and return with loot.
6. Expand: tribe humans/labor, mount crew, big-animal mass/saddle, boat transport, economy.
7. Only after authority/abuse rules: shared trade, real multiplayer, frontier PvPvE/captures.

Each path is a **proposed dependency order**, not authorization to implement unapproved game formulas.
