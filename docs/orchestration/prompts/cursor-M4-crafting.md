# Cursor milestone M4 — gathering tools, processing, and flexible crafting

This is Durango's crown-jewel system (systems PRD §9.1): recipes ask for **category slots**, not specific items, and the finished item inherits attributes from the **primary slot only**. Do it after M5 so recipes have real materials to consume.

## Read first
- `docs/prd/durango-wild-lands-systems-prd.md` §8.1–8.4 (tools, butchering, processing chain, item level), §9.1–9.2 (flexible recipes, stations), §21 item 1 (craft UI must show the primary slot)
- `docs/orchestration/plan.md` decision D7, your M0 item model (`ItemDef`, `ItemStack`, `Inventory`)
- `game/data/nature_manifest.json` (what the island yields), `game/data/items.json`

## Tasks

1. **Tool auto-equip.** Tapping a node auto-equips the matching tool class from the bag (knife for plants and thickets, axe for trees, pick for rock). Combat weapons can gather but burn durability; an `ItemStack.flags` entry `locked` prevents a weapon from being auto-used (PRD §8.1 MUST). Durability on tools: `durability`/`max_durability` on the stack; broken tools stop working and can be repaired later.

2. **Butchering.** Creature corpses from M1 become a `Corpse` interactable: knife required, yields meat, bone, hide from the species JSON (add a `drops` block to each creature JSON: base parts plus rare parts gated by a Butchering skill level stub). Species carry latent attributes on parts (`raptor_bone` gets `{"hardness": 2}`, velociraptor hide `{"feathered": 1}`), which is why you hunt that animal.

3. **Processing chain** as data in `game/data/recipes.json`, each recipe with `slots: [{category, count, primary: bool}]`, `output`, `station` (null for hand craft), `seconds`, `process_step` (bake, boil, dry, hammer, mince, split, twist). The chain from PRD §8.3: stalks → twine → rope; logs → split wood → planks/pillars; hide → dried hide → straps; ore → ingot; fibre → thread → cloth; charcoal from burnables. Each processing step increments the output stack's `process_count`.

4. **Crafting resolver** (`scripts/items/crafting.gd`): given a recipe and the inventory, list every stack that satisfies each slot by category; the player picks (default: first match); on craft, consume, then build the output: `attributes` = primary slot's attributes, `level` = primary's level, `process_count` = recipe adds, colour = primary material colour (store a `tint` attribute on materials so a knife with raptor bone looks different from one with stone). **Secondary slots contribute nothing but bulk.** Print `[craft] <output> from primary=<id attrs>`.

5. **Recipes for the slice**: improvised stone knife (blade: stone/bone/metal_shard; handle: branch/bone; lashing: reed/root/twine), work axe, club, bandage (cloth + herb), capture net I (twine + branch), pressure dressing, splint, twine, rope, cloth, dried hide, split wood, charcoal, bonfire kit, makeshift taming pen kit.

6. **Stations**: workbench and drying rack as placeable buildings (reuse `BuildPlacer` from M3); recipes with a `station` need the player within 2 m of one. Bonfire gains cooking later (M7).

7. **Craft UI** (touch-first, 64 px targets): recipe list filtered by what you can make now vs. all; the recipe view shows each slot as a category chip with a **PRIMARY** badge on the inheriting slot; tapping a slot opens the matching stacks with their attributes so the choice is informed. Output preview shows the resulting attributes before confirming. This is PRD §21 item 1 and it is the whole point of the system.

## Acceptance
- PRD §24 test 2: craft two stone knives, one with a raptor bone blade and one with a stone blade, and the resulting stacks differ in attributes and tint and do not merge.
- Locked combat knife is never auto-used for gathering.
- Butchering a velociraptor yields the JSON drops; smoke passes; report written; commit as `M4: tools, processing, flexible crafting`.
