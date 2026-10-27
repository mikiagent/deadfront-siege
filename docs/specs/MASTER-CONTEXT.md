# DEADFRONT | Master context and north star

**Status:** Consolidated vision + design dependency map (owner-approved *direction*, proposed concrete system mechanics).

## Promise and identity

Build a long-lived, protected prehistoric home economy from meaningful expeditions. Every gathered lot, dinosaur, survivor, crafted building and next-generation individual has a history. Progress is accumulated through skilled labor, material refinement, capture, trade, genetics and education. A player can pursue civilization and PvE indefinitely without submitting the home to raids. Optional level-60 PvPvE frontier is dangerous, expensive, defensible and cannot invalidate the protected civilization core.

Reference inspirations are *design lessons* from Skyblock's safe economic compounding, Durango's ingredient-level crafting and expedition worlds, and ARK's individual creature lineages. **Use original DEADFRONT assets and systems, not copied source/art.**

## Experiential pillars

1. **Permanent safety anchors risk:** safe home never raidable, exposed settlements/cargo at risk by explicit zone rules.
2. **Real input economies:** material source lots, labor, durability, shipping, finished structure identities, ammunition and worker time conserved.
3. **Individuals matter:** personal level/innate IVs/learned skills; switching bodies retains the tribe but never transfers veteran skill to a child.
4. **Living dinosaurs and human crews:** anatomy/reach/mass/armor/load/skills/seat occupancy decide actions, not cosmetic mounts or phantom workers.
5. **Recognizable counters:** Dexterity or Might drives controlled vs forceful moves; each move has Impact/Pierce/Slash channel. Armor and actual hit geometry matter.
6. **Specialized trade:** refined inputs, worker occupations, interchangeable but individually made blueprints/buildings, market goods with meaningful provenance.
7. **Fair danger:** opt-in frontier where high-end encounters are expensive and territorial power is local, with strong anti-punch-down rules before online release.

## Canonical looping example

Prepare at safe home -> travel with one personally levelled human, real supplies and eligible companions -> hunt/gather/capture at increasingly difficult islands -> return cargo by physical trip/ship -> sort signed material lots -> process ingredients into composites (carry negatives too) -> craft equipment or construction blueprints -> place worksite, deliver materials, spend real worker effort -> expand home industry, breed/raise/train tribe and dinosaurs -> specialize and repeat. PvPvE settlement is optional endgame.

**First 20-minute target (PROPOSED):** spawn at safe island camp, gather wood/fiber/stone, inspect trait penalty, make a simple blade/bandage, hunt one small dinosaur, get hurt and recover, secure a material lot, return and save. This is a UX test aspiration, not owner-approved pacing.

## Relationship map

```text
[Identity, save, ruleset version, permissions]
  ├── [Human actors: IV, learned skills, personal level] ──┬─ [Tribe / generations / upbringing]
  │                                                        └─ [Workers / hauling / training]
  ├── [Dinosaur instances / anatomy / genetics / load] ────── [Expedition slots / saddles / crew]
  ├── [Island category / climate / regions] ───────────────── [Nodes, settlements, raids, resets]
  └── [Unique materials and items] ─┬─ [Inventory + durable lot provenance]
                                    ├─ [Food spoilage / buffs]
                                    ├─ [Processing + material fusion]
                                    ├─ [Tools + weapon engineering]
                                    └─ [Blueprint -> worksite -> structure -> package -> trade]
                            [Combat D/M × I/P/S] ───┬─ [Armor / reach / pounce / mass]
                                                     └─ [Stationary and mobile siege]
  [Boat + harbor + route] -> [Cargo custody] -> [Secure home storage]
  [PvPvE frontier] -> [Raid permissions] -> [Captive custody and ransom]
  [UI, input, animations, server authority, QA] applies across all domains
```

## Cross-system contract: resource provenance

One harvested lot has origin world/seed, source species/node, quality, material level and signed traits. Inventory owns it. Recipes transform real lots into new instances with exactly accounted inputs; the output carries lineage signatures according to the approved resolver. Worksite construction commits exact parts to a structure; packaging moves the same structure ID and held traits, not a fresh cloned building. A damaged/unloaded turret has a persistent unique instance. A dinosaur is an actor, not a tradable bag containing people or unrecorded goods.

## Cross-system contract: avatar and party

One currently controlled human ID points to a human in the existing tribe. Human rider and dinosaur are separately existing entities; a mounted human+dino follower pair may use one composite companion slot, up to three slots total (PARTY-01). Exact avatar/deployed crew slot accounting is still OPEN. No mount control spawns a second human.

## Cross-system contract: home and danger

`home` is immune to intentional enemy/player raid targeting. World `pve` settlements face wild creature raids, `pvpve` constructed settlements can be raided by players, level-gated to a personally level-60 controlling human with tribe unlock persisted. A boat is invulnerable to interception only **after actual departure while homebound**, even if a raid is happening. Custody for captured human/dino uses exact 72h real time and preservation/reset of earned progression per PVP-04.

## Hard architectural invariants

- A unique item, human, dinosaur, building, weapon, cargo manifest or captive case has exactly one legal owner/location at a time.
- A transaction is either fully applied or not applied; replays with same `command_id` return the same outcome.
- All ammo/food/construction/recipe transformations reconcile inputs, outputs and explicit losses.
- Offline catch-up may not grant resources without inputs, worker time, capacity and valid location.
- A low-level individual cannot equip an above-level item even if another tribe member owns the item.
- Damage projectiles and melee checks honor physical geometry, faction permissions and hit-zone rules.
- Zero crew implies zero crewed weapon shots; one box never becomes three infinite magazines.
- No historical draft or hypothetical formula automatically becomes a product-approved requirement.

## Source resolution

See `docs/game-design/README.md` for confirmed backbone, `decisions.md` for rule IDs, `audit-and-open-questions.md` for conflicts, `docs/design/` for owner workshop context and each `systems/` file's Source paragraph. `docs/prd/` is historical.
