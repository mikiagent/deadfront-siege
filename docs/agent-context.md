# Wildlands MMO: entry point for coding agents

This is a navigation guide. The linked vision documents, game code, and data remain the sources; this page does not define game rules. The wiki and this guide point to those same files. Work from the canon checkout identified by [docs/README.md](README.md).

## Start a feature

1. Identify the system and open its row below. Read only the relevant vision sections and current page. Check the [current index](current/README.md) for pages that are not yet written.
2. Check the owner-confirmed and proposal labels in the [vision index](vision/README.md), then read the relevant source section. A proposal is not an approved rule; flag unresolved decisions instead of implementing its numbers as fact.
3. Verify present behavior and numeric values in the owning game code and data. A data record alone does not establish that a feature is reachable. Use the listed tests as starting points, and find other affected consumers and tests.
4. Report differences between intended and current behavior with source paths. If the task changes implementation, update its existing current page with evidence. Follow [wiki maintenance](wiki-maintenance.md) for vision changes, generated pages, visual references, tuning proposals, and archiving.

| Task | Vision | Current and implementation | Tests to inspect |
| --- | --- | --- | --- |
| Needs, food, and HUD | [Food and recovery](vision/WildLandsMMO_Game_Vision.md#10-food-preservation-and-recovery) | [Survival needs](current/survival-needs.md), [HUD](current/hud.md), [combat vitals](../game/scripts/combat/vitals.gd) | [Needs](../game/tests/t_needs.gd), [UI](../game/tests/t_ui.gd) |
| Inventory and bags | [Resources and traits](vision/WildLandsMMO_Game_Vision.md#8-resources-material-levels-and-traits) | Current system page pending; inspect [inventory](../game/scripts/items/inventory.gd) and [bag capacity](../game/scripts/items/bag_capacity.gd) | [Inventory](../game/tests/t_inventory.gd), [bags](../game/tests/t_bags.gd) |
| Crafting and processing | [Manufacturing](vision/WildLandsMMO_Game_Vision.md#9-processing-crafting-and-the-manufacturing-economy), [crafting math](vision/WildLandsMMO_Crafting_Building_Math.md) | [Recipe catalog](current/recipes.md), [crafting](../game/scripts/items/crafting.gd), [recipe data](../game/data/recipes.json) | [Data](../game/tests/t_data.gd) |
| Material traits and gathering | [Materials](vision/WildLandsMMO_Game_Vision.md#8-resources-material-levels-and-traits), [trait and gathering math](vision/WildLandsMMO_Traits_Gathering_Processing_Math.md) | [Items and traits](current/items-traits.md), [inventory](../game/scripts/items/inventory.gd), [world rules](../game/data/world/rules.json) | [Inventory](../game/tests/t_inventory.gd), [data](../game/tests/t_data.gd) |
| Creatures and taming | [Dinosaurs and taming](vision/WildLandsMMO_Game_Vision.md#6-dinosaurs-taming-and-genetics) | Current system page pending; inspect [creature runtime](../game/scripts/creatures/creature.gd) and [species data](../game/data/creatures/) | [Taming](../game/tests/t_tame.gd), [AI](../game/tests/t_ai.gd) |
| World and islands | [World and islands](vision/WildLandsMMO_Game_Vision.md#2-the-world-and-its-islands) | [World and biomes](current/world-biomes.md), [island data](../game/data/islands/), [climates](../game/data/world/climates.json) | [Biomes](../game/tests/t_biomes.gd) |
| Combat | [Combat](vision/WildLandsMMO_Game_Vision.md#13-combat-and-weapon-identities), [combat math](vision/WildLandsMMO_Combat_Math.md) | Current system page pending; inspect [combat tuning](../game/data/combat_tuning.json) and [combat scripts](../game/scripts/combat/) | [Combat](../game/tests/t_combat.gd) |
| Saves and multiplayer | [Hybrid world](vision/WildLandsMMO_Game_Vision.md#one-hybrid-world-different-ways-to-be-together) | Current pages pending; inspect [save code](../game/scripts/core/save_game.gd) and [server handlers](../game/scripts/server/intent_handlers.gd) | [Save](../game/tests/t_save.gd), [server domains](../game/tests/t_srvdom.gd) |

## Known gaps

- Consult the [Open Questions register](vision/WildLandsMMO_Open_Questions.md) for unresolved decisions and their owning documents. Do not treat a listed proposal as settled.
- Owner curation may live in local `tools/docs_wiki/state.json`, which is gitignored. If available, consult it as review context; distinguish user marks from seeded suggestions and verify claims against their sources.

The archive on `main` is historical. It is outside normal wiki search and must not be loaded as default context. If a task requires provenance or a source conflict cannot be resolved from current documents, use `/archive <term>` in the wiki or consult a specific archived file.
