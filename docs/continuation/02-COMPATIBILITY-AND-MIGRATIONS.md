# Save compatibility, downgrade risk and irreversible transactions

**Source:** `game/scripts/core/save_game.gd`, `game/scripts/core/save_migrations.gd`, `game/scripts/items/item_stack.gd`, `world/placed_building.gd`; actual current schema **3**. This document is the in-place migration strategy, **not** permission to rewrite saves or convert them automatically.

## Existing file and schema must survive

Existing main saves to `user://save_1.json`; bot mode uses ephemeral `user://bot_save.json`. `SaveGame` serializes a snapshot and calls `SaveMigrations.migrate` before restoring current `World` and `Player`. `SaveMigrations.CURRENT_SCHEMA=3` with transitions `0->1`, `1->2`, `2->3`.

Keep `SaveGame.save_now()` and `load_now(host)` as public API. Do not move existing saved fields to a completely new root format for convenience.

## C0 safest required changes, in order

1. Capture fixture copies of the current `schema: 0/1/2/3` save shapes. Existing tests include save migrations; add whole-save golden roundtrip verifying levels, material attributes, flags, packed kit, world claims, camp layout, T-stones, pets/genetics, unlocks, food buffs, structures/cargo and saved island.
2. Create a non-destructive save writer: serialize to temporary sibling path, verify it parses as a `Dictionary` with expected schema and invariants; preserve last known good save with explicit backup; then atomically replace **where filesystem semantics permit**. On web/mobile where replacement semantics differ, define and test safe write/rename fallback. Never call `WRITE` on the only saved copy until a recovery file is valid.
3. On invalid JSON/unsupported newer schema, offer recover/restore or explicit new-game action and **do not autosave over the unreadable file**. Current code starts new world on invalid save, which is a loss risk. Preserve old `load_now` signature and gameplay bootstrap behavior by introducing non-destructive error/recovery state.
4. Test abrupt interruption: before temp file write, during temp write, after temp flush but before promotion, and immediately after promotion. At each stage at least one known-good snapshot must remain readable.
5. Keep bot path throwaway behavior; never redirect bot saves to user save or alter real `user://` path inadvertently.
6. Only after these gates pass, introduce *new feature fields* with `v3_to_v4` (if schema bump required), not a fresh `schema:1`. Continue support of all earlier versions.

## Table of future schema deltas

| Feature | Current record | Recommended additive field | Default for old saves | Critical invariants |
|---|---|---|---|---|
| Material lots | `ItemStack.attributes`, flags, level, process, durability, count | optional `trait_lineage` or reserved namespaced attrs/provenance, `lot_id` if required | legacy source marker derived once in explicit migration | traits/levels/stack counts unchanged; no re-roll |
| Food spoilage | `ItemStack` no dedicated food freshness state | `food_state: {freshness, settled_unix, profile}` | old food receives documented conservative first-load policy | avoid instant old-food rot; no freshening on transfer |
| Workers/tribe | one `Player`, `Player.skills`, `Player.bonded` | `tribe: {humans[], controlled_human_id, homes...}` | import current survivor **exactly once**, preserving original level/skills/gear and its own ID | switching bodies never duplicates equipped inventory or XP |
| Dinosaur armor/load | `PetRecord` genetics/bag/level/tamed role | `loadout`, mass profile reference, fitted armor IDs | old pets unloaded / no armor without changing raw stats | IV/EV in old 7 stats retained |
| Structure packaging | `PlacedBuilding.to_dict()`: kind, cell, rot, contents, sleeps_left | `structure_uid`, material traits, maker, pack_state | legacy building IDs assigned deterministically on first migration and persisted | same building only placed OR packed; basket contents not duplicated |
| Shared mounted ammo | current Player inventory + placed catapult | `platform_saddle`, `turret_components`, `ammo_box`, seats | none by default; existing catapults untouched | no free turret magazine/crew or duplicate rounds |
| Cargo boats | current `World.cargo_home` simple inventory | durable `shipments[]`, manifest and departure phase | old cargo remains in home cargo inventory | departure not a second credit to `cargo_home` |
| Captives / frontier | no authoritative custody ledger | `captive_cases[]` with UTC timestamps, original IDs | empty | no captive ownership duplicated or reset on clock changes |
| Home replacement | one `home` object, `World.home_terrain` etc. | migration intent, new home ID, special salvage vault | old home remains protected, no auto-move | 100% installed building material refunds, once |

**Every field name above is a proposed migration shape**, not a new saved schema already in code. Group schema changes by actual small feature and test fixtures rather than bump schema for documentation.

## Unique IDs without blowing up legacy stacking

Existing `ItemStack.can_merge_with` compares def, level, process, durability, attributes and flags. If a `lot_id` is naively inserted into `attributes`, two otherwise equal lots may never stack. Choose one of:
- **Preferred for first feature:** typed persisted `trait_lineage` plus canonical signature, merge only when equivalent, preserving source provenance by an explicitly bounded set/aggregate.
- **Alternative:** per-lot subrecords for mixed stacks, preserving every source roll at the cost of UI/storage complexity.

Neither alternative is implicitly approved. Do not invent one in code without evaluating all current merge/transfer and auto-recipe paths.

## Transaction boundary hazards to protect

- `Inventory.add` may partially accept and mutates input count; when moving input/output ensure exactly accepted units removed from source.
- `PlacedBuilding.pack_up` currently may attempt to return kit/storage into a nearly full inventory without an all-or-nothing capacity preflight. In extended packable structures reject packing when return capacity is insufficient; do not repackage occupied containers or spawn free duplicates.
- `Crafting.build_output` should inherit new material traits from *real consumed* lots and preserve existing level/process behavior; don't consume on preview, failed station check or reroll.
- `FieldCatapult.fire` currently consumes Player ammo, so mobile ammo work must abstract origin and loader with a safe compatibility path.
- Current saved `World.cargo_home` contents cannot be silently moved into a new in-flight manifest on load or counted in two stores.
- Once offline food spoilage is introduced, settle at old location rate **before** changing location so transfers cannot refresh food.
- Home migration must be transactional; refund delivered inputs exactly once and move other stores/residents separately.

## Save fixture matrix before each schema bump

- v0 old x/z building, no schema; v1 x/z; v2 grid cell; v3 inventory extras + camp layout; future v4 after explicit feature.
- Current home player with no buildings; with basket containing multiple stacked item lots; with spent bedding; with 1+ bonded pets and IV/EV; in unstable island with harvested depletion and inventory flagged unstable.
- Offline catch-up via `saved_unix` and field growth; invalid future schema; corrupt JSON; interrupted save; bot save isolated.
- For each fixture compare counts/levels/traits and completed structure positions pre/post load. Run old baseline `_test_save_migrations` plus new save lab.
- Downgrade policy: a newer save loaded in an older build should not be overwritten or interpreted as schema 0; keep explicit backup/read-only warning.

## Stage labels

`EXISTING`: save schema 3 and migrators. `DESIGN_ONLY`: global persistent IDs, original-owner prisoners, special Ender-chest materials vault, human generations and packed building UUID. `PROPOSED`: exact new field names, backup algorithm, pseudo-atomic update strategy. `VERIFIED` only after Godot fixtures and reload runs succeed.
