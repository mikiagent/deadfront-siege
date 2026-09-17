# Cursor M4 — tools, processing, flexible crafting

Durango's crown jewel: recipes ask for category slots, and only the **primary** slot's attributes (and tint) land on the output.

## What shipped
- Tool auto-equip on tap-to-gather. `Inventory.find_gather_tool` skips `locked` and broken stacks, prefers `is_work_tool`. Combat weapons can gather but lose 3 durability vs 1 for work tools (`# ASSUMPTION:`). Broken tools stop working.
- `ItemStack.durability` / `max_durability`; inventory **Lock / Unlock** is a 64 px tap (no hover-only).
- Corpses are knife interactables. Drops live in `game/data/butchering.json` because Codex owns `game/data/creatures/*.json`. Velociraptor: meat, bone `{hardness: 2, tint}`, hide `{feathered: 1}`. Rare talon gated by Butchering I/II stubs in `survival.json`.
- `game/data/recipes.json` + `scripts/items/crafting.gd`: category slots, player picks (default first match), primary attributes/level/tint inherit, `process_count` increments by `process_add`. Secondary slots are bulk only. Print `[craft] <output> from primary=<id attrs>`.
- Slice recipes: improvised stone knife, work axe, club, bandage, capture net I, pressure dressing, splint, twine, rope, thread, cloth, dried hide, hide strap, split wood, plank, charcoal, ingot, bonfire kit, taming pen kit, workbench kit, drying rack kit.
- Workbench and drying rack as `CraftStation` placeables (2 m range). C opens craft UI; place buttons start `BuildPlacer`.
- Craft UI: Can/All filter, **PRIMARY** badge, tap a slot to pick stacks with attributes, output preview before confirm. 64 px targets, safe-area padding.

## Lab output (PRD §24 test 2)
```
[item] refused thicket: need tool knife
[item] auto-equip stone_knife_work knife
[craft] stone_knife_work from primary=raptor_bone { "hardness": 2, "tint": "#d4c4a8" }
[craft] stone_knife_work from primary=stone { "tint": "#8a8a8a" }
[craft] knives bone=true stone=true merge=false bone_tint=#d4c4a8 stone_tint=#8a8a8a
[item] butcher velociraptor +2 raptor_meat {  }
[item] butcher velociraptor +2 raptor_bone { "hardness": 2.0, "tint": "#d4c4a8" }
[item] butcher velociraptor +1 raptor_hide { "feathered": 1.0, "tint": "#6b5a3e" }
```
Locked combat knife never auto-used. Bone-blade and stone-blade knives differ and do not merge. `tools/smoke.sh` → `SMOKE PASS`.

## Assumptions
- Butcher tables are a Cursor-owned JSON file, not species JSON.
- Work-tool gather costs 1 durability; combat-as-tool costs 3. Repair is later.
- Bandage/pressure dressing treat **herb** as the primary slot.
- Ore → ingot uses the workbench until a furnace exists.
- Hide strap can consume any `hide` category (including dried).

## Reproduce
```
/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=craft_lab
```
C = craft UI. Tap a slot chip to pick the primary material. Place buttons for workbench / drying rack / pen / bonfire.

## Next agent
M6 can consume these recipes and stations. Do not edit `game/data/creatures/*.json`; extend `butchering.json` if more species land.
