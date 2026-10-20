# Claude implementation prompt: Durango-inspired Inventory, Nonstacking Resources and Storage

Recreate Durango's individual-object inventory. Ordinary gathered and crafted resources **generally did not stack**, even when they shared a name. Their distinct levels, durability, traits and processing history were central to gameplay. A full exception list is not verified, so allow configurable category-specific stacking (currency in a wallet, certain consumables if needed).

## Core model
Separate static ItemDefinition from persistent ItemInstance. Each physical material/equipment/animal has a stable unique ID, definition, level, condition/durability, positive/negative/green attributes, processing history/opportunities, ownership/location and optional quantity if genuinely stackable. Five Large Leg Bones with different Firm/Black Sheen values consume five physical spaces. Even visually identical unique materials should remain individually identifiable.

Rare bonuses are **attributes of the item**, never extra inventory objects. Moving one Black Sheen bone from player to box to dinosaur to craft must preserve precisely its attributes, ID and condition. Do not reroll properties on pickup or transfer.

## Capacity
Historical reference: base player inventory **100 spaces**, equipment adds storage slots, with Pocket attribute +6 spaces per level. Add equipment and bag bonuses once, remove modifiers on unequip. When capacity would shrink below occupied slots, disallow invalid unequip or apply a clearly defined safe overflow policy; never delete rare items. Pickup failure leaves an item safely in the world or existing claim storage.

## Physical containers
Placeable baskets, boxes, personal boxes and clan storages have **independent inventories**, owner/permission settings and persistence. Reported historical examples: basket about 100 slots; level-60 Large Leaf Box up to 160; some event personal boxes 300; clan storage up to 2,000. These are references rather than universal capacities. Support personal/tradebound rules, restricted items and clan permissions. Some storage containers can be packaged/moved with contents when allowed without duplicating cargo.

## Dinosaur cargo
Each bonded cargo-capable dinosaur owns one persistent independent container. Preserve cargo through follow, mount, dismiss, store, travel, save/load and death/recovery rules. Implement player ↔ dinosaur and player ↔ storage exact-instance transfers.

## Item location and transactions
One item can exist in **exactly one** location: player inventory, equipped slot, world, storage box, dinosaur cargo, crafting/processing reservation, trade escrow, or marketplace escrow/delivery. Atomic transfers validate ownership, restrictions, destination capacity, and retry-safe state. Use shared inventory logic across harvesting, crafting, dropping, depositing, trading and market; don't invent another bag subsystem. Dropped items keep the same ID and metadata.

## Inventory UI
Grid-style item presentation with level, durability and green rare-property indicators. Inspection shows source, ordinary/negative/rare perks and levels, processing left, compatible recipes and valid actions. Provide filters by category, level, processing count and rare traits; sorting by name/level/rarity/age. Optional **visual grouping** ('12 Large Leg Bones') is not physical stacking: it expands to 12 selectable unique instances consuming 12 slots. When crafting, let users explicitly choose exactly which bone is consumed and protect valuable items from default auto-consumption.

## Performance and tests
Use shared definitions, indexed instance lookup, virtualized lists where necessary and incremental UI updates. Test duplicate IDs, multiple identical names, nonstacking capacity, attribute preservation, full-inventory pickup, pocket equip/unequip, restricted container access, storage packing, dinosaur cargo, item drop/pickup, save/load, atomic rollback and rare-material crafting selection. Vertical slice: harvest five bones → store rare bone → transfer second to dinosaur → process third → craft with fourth → reload → verify exact unchanged identities for survivors.

## Implementation standards
Inspect the existing project and its architecture first. Reuse existing gameplay, inventory, persistence, UI, and network components rather than introducing parallel systems. Implement working code in the project's language and engine, not just pseudocode. Separate definitions/configuration from saved runtime state. Make balancing parameters configurable. Preserve unique instance IDs and enforce atomic ownership/currency transitions. Where multiplayer exists, validate gameplay authoritatively and make retried operations idempotent. Include tests and summarize modified files, verified behavior, assumptions, and remaining limitations.

**Historical fidelity:** Durango: Wild Lands was updated during 2019; published guides can describe different revisions. Distinguish verified original mechanics from contemporary player reports, community reconstruction formulas, and new design choices. Do not claim illustrative values are exact original Nexon server values.
