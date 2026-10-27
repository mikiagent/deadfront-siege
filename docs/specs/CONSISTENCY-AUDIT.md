# Cross-system consistency audit | 2026-10-26

**Reviewed against:** the current canonical decision register, audit backlog, 15 existing detailed game-design chapters, implementation-pack docs, candidate specs and source weapon chapter 23. Document-only review; **not an executable Godot test**.

## Locked product rules correctly carried through
- Safe home immutability and no enemy attacks: HOME-01, PVP-01; remote PvE creature vs PvPvE player raid separation.
- Paid home replacement and 100% invested building material salvage: HOME-02/03; ordinary residents/inventories migrate separately.
- Personal level/equip restriction, separately persistent tribe unlock: LVL-01/02, TRIBE-01.
- Human/dino inherited potential versus trained XP and professional knowledge; captured ransom preservation/reset: TRIBE-02/03, PVP-04.
- Dexterity/Might crossed with Impact/Pierce/Slash, six mode codes and actual hit geometry: COMBAT-02/05, MOUNT-02.
- Finite autonomous/crewed turrets, platform limits **1 crewed + 2 automatic + 1 shared box**, 2 actor role modes: TURRET-01, PLATFORM-01.
- Material dual-source signed trait inheritance and processed endgame ingredients: MAT-02, CRAFT-03.
- Food spoilage anywhere, including offline home storage: FOOD-01.

## Known conflicts not resolved by writing candidate math
- WORLD-02 reset salvage to vault versus newer prefab source says abandoned structures/resources may be lost. This is P0-D05 owner choice.
- Historical mobile-first `AGENTS.md` and current desktop Chrome `HANDOFF.md` reflect different execution eras. Current build evidence is not a new-release target approval.
- T. rex intended tameable/rideable but existing creature JSON disagrees; Brontosaurus not existing Brachiosaurus.
- Existing crafting copies `primary.attributes` but new dual-input fusion requires both trait signatures.
- A 3×3 fixed field catapult is NOT automatically an eligible mobile-saddle weapon; dedicated compact geometry required.
- Existing inventory/equipment chapter 06 emphasizes armor and is not sufficient for full storage/lot schema.
- Real multiplayer market/raids/captive timers are not certified by single-player UI or mock clock.

## Proposed formulas require owner review

Level XP curve, trait roll weights and diminishing cap, output item level, food shelf-life baseline, worker time, construction productivity, per-zone damage, mass mobility and stomp force, armor mitigation, genetic delta, barrel/ammo size, boat cap, listing tax, ransom cost, offline progression and first-hour pacing. Each is labeled PROPOSED in source spec/data.

## Graph cycles and implementation layering

The `system-graph.v0.json` dependency network contains loops by **game design**, e.g. material↔inventory, worker↔construction, dinosaurs↔combat and islands↔structures. These are *not* an instruction to create circular GDScript imports. First establish data DTO/ID definitions, then pure domain functions and command/event interfaces, then external service adapters, then scenes/AI. The M0–M12 roadmap is a build ordering, not a topological sort of unbroken module imports.

## Source-to-machine-data reconciliation

A first draft of `candidate-recipes.v0.json` was compared to original chapter 23: corrected plank output **2 split_wood→1 plank**, shaped bone source **dense_bone×2 +stone×1**, sinew cord **tendon×2+twine×1**, treated plank **plank×2+resin×1→2**, laminated bone both binding pitch and cured hide, iron smelting **iron_ore×3 +charcoal×2**, refinement **iron_ingot×2 +charcoal×1**. All are historical **proposed or existing-reference** recipes, NOT tested against current `game/data/recipes.json`.

The 18-weapon candidate matrix mirrors documented six archetypes × three eras. A subsequent static cross-check against live items.json/recipes.json is recorded in CONTENT-AUDIT.md, with per-weapon existence flags. This still does not validate runtime functionality. Missing iron ore and Smelter, Forge, Lamination Press must be created and tested before era completion.

## Ship/no-ship conclusion

**Ship documentation PR for owner review only**. Do not claim any gameplay formulas owner-approved, all 24 specs BUILD_READY, online PvP functioning, or new Godot tests passing. Engineering-only M0 architecture proof is safe to request in isolated workspace; gameplay milestones require approved numbers and exact fixture versions.
