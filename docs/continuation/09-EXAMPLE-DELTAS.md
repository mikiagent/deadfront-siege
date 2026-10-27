# Three concrete delta-spec examples for the existing codebase

These show the level of implementation detail needed *without creating replacement systems*. Confirmed qualitative owner intent is distinguished from proposed algorithms. Numerical balance and full schema field names still require approval.

## Delta A | Trait-aware crafting in real ItemStack and Crafting

**Existing seam:** `Crafting._plan(inv, rec, picks)` produces explicit consumed plan and `Crafting.build_output(rec, primary, crafted_level, consumed=[])` produces an `ItemStack`. Today it duplicates `primary.attributes`, then applies material-tier / flags / level/process / food buff rules. `ItemStack.can_merge_with()` compares definition, level, process, durability, attrs and flags; `Inventory.add()` partially accepts and mutates offered count.

**Goal:** Two compatible required source material lots create one composite retaining distinct signed traits, and equal trait IDs combine under bounded diminishing returns with original lot attribution. Material level and process count remain governed by existing `ProgressionScaling` unless an approved recipe explicitly changes them.

**Proposed additive design:**
- `Data` loads a new typed material-trait catalog only when present. Missing catalog does not break historical recipes.
- Specific `recipes.json` rows specify `fusion_rule_id`, exactly two primary eligible material slots, permitted catalysts, output definition and station.
- New `items/trait_resolver.gd` pure function uses **actual consumed stacks and amounts**, not inventory defaults and not `primary` alone.
- New compact `trait_lineage` persisted in `ItemStack.to_dict/from_dict` only as needed; legacy `attributes` stay intact. If lot provenance must be tracked per quantity, use bounded sublots rather than fabricating a unique ID for an entire merged quantity.
- The preview and completion call the same resolver with the same lot selection. No new RNG for trait inheritance on output. Deterministic seed only for initial harvest roll.
- A recipe without `fusion_rule_id` takes the exact old code branch, preserving food poison, `keep_output_id`, process and buff behavior.

**Proposed example fixtures pending owner coefficient:**
1. Primary +8% Resilient, second +6% Shock Absorbent -> output holds both positive signatures.
2. Primary +8% Resilient, second -4% Brittle -> output holds both opposite-role traits.
3. Duplicate Resilient +8% and +4% -> one displayed capped magnitude under approved merge rule (sample 8% +25% of4%=9%, **not locked**).
4. Input item level41+40 follows existing `ProgressionScaling.crafted_level`, not a new improvised floor average.
5. Same source signature accidentally appears twice through a multi-stage component lineage -> attribution counted once or production rejected according to approved policy.
6. Save/reload -> same count, trait lineage and display; attempt two concurrent crafts with one rare source -> exactly one uses it.
7. Legacy recipe slingshot, food, smelt/burn and station/craft XP goldens unchanged.

**Protect:** existing `_test_multistack_crafting`, `_test_json_attribute_merging`, `_test_slingshot_recipe`, `_test_dried_meat_recipe`, `craft_lab`, `kitchen_lab` and save migration cases.

**Blockers:** trait roll distribution, stack equivalence, duplicate cap and provenance compression, first recipe and station data availability.

## Delta B | Unique packable buildings without breaking current kits

**Existing seam:** `BuildPlacer` grid occupancy, `PlacedBuilding.make/from_dict/to_dict/pack_up`, `World._home_buildings_cache`, `SaveGame._restore_buildings`. Current `to_dict` stores kind, grid cell/rotation, sign, cargo, contents and bedding use, with old x/z compatibility.

**Goal:** Fully constructed structures become unique manufactured tradable assets retaining maker, material composition, traits and wear. On safe home island move, paid building dismantle returns 100% of their *actual committed* material inputs to special salvage-only vault.

**Proposed additive design:**
- Keep old kit buildings and old `pack_up` route untouched initially. Add `worksite` for new blueprint construction and unique `structure_uid` generated once at completion, not on every `from_dict` call.
- Extend building save row with optional `structure_uid`, `creator_human_id`, `consumed_materials`, `derived_traits`, `pack_state` and `condition`. Old rows load with backward-compatible defaults and deterministic one-time ID assignment only if actually needed.
- Add `StructurePackaging` helper which verifies combat status, occupants, station queues, cargo contents and player bag capacity **before** changing structure state. Package is a durable item referencing same structure UID, not a new free kit.
- Original baskets still have `contents`; never silently drop items or duplicate them on packing. Extended advanced prefabs must be empty or use explicit all-or-nothing contents transfer.
- Dismantling is not packaging; home-move salvage uses stored material delivery ledger, never attempts to reconstruct nonexistent historical ingredient lots for a legacy basket.

**Key tests:** pack→redeploy uses identical UID/creator/traits/health; serialize placed and packaged states without duplication; overfull bag packing rejects with original building intact; used bedding remains handled according to current rules; old v0/1 world x/z and v2/3 grid building saves migrate; land reset obeys explicitly approved refund, not accidental 100% from home rule.

**Blockers:** how to price/size package, unknown material investment for legacy kits, owner resolution of WORLD-02, room functional buffs.

## Delta C | Real tribe gunner and dinosaur-mounted siege

**Existing seam:** `Player.mount(c)`, `dismount()`, `_mounted_move(delta)` reparent the single avatar to `CreatureView.mount_socket()`; `PetRecord` stores tame/role/genes/bag; `FieldCatapult.fire(player: Player,victim: Creature,poison)` checks nearby player, aim within 8..24m, consumes player inventory ammunition, starts 3s reload and creates `SiegeProjectile` with source Player.

**Goal:** An eligible large tameable mount carries ≤1 crewed siege hardpoint, ≤2 automatic defense hardpoints, exactly one shared finite ammo box; player and one *real* tribe human can swap driver and gunner roles. No infinite ammunition, phantom people or free extra party slots.

**Sequence of compatible extension:**
1. First add real human tribe roster/seated actor references with unique IDs and location state. Do not invent NPC by name string or duplicate player scene.
2. Add validated `PlatformSaddleRecord` to a suitable existing `PetRecord`, only for whitelisted species with real back geometry and carry mass. Do not silently make currently untameable T. rex mount-eligible; never treat Brachiosaurus as Brontosaurus.
3. Keep `Player.mount` and old `mount_socket` path for normal riding. Add `CrewSeatController` with driver and gunner seats on platform-deck view, mutually exclusive person IDs, safe transfer/action and trained fallback.
4. Split firing into `SiegeFireService` receiving validated source actor, muzzle world transform, world target pose, ammo holder and unique shot ID. Existing `FieldCatapult.fire(Player,...)` calls this through a compatibility adapter while preserving 8..24m, 3s reload, inventory cost and historic behavior.
5. Automatic turrets use physically plausible detection and loaded chamber; they consume one shared box reserve via an atomic debit on reload. Every shot has a world-space launch snapshot and stored source; no projectile remains parented to dinosaur transform.
6. Add load weight from saddle + both seats/humans + fitted guns + loaded ammo + barding/cargo to species carrying constraints. Force/stagger mass effects and instability coefficients remain separate PROPOSED design and need owner signoff.
7. Add existing-style HUD turret/box panels, Hold Fire, ammo priority and person role/switch actions via same mouse/touch game input.

**Conservation proof:** for a single ammo type, initially six, load one each of three guns -> box three, magazines three; main fires -> box three, magazines two, fired one; gunner goes KO -> no new crewed shot, but already chambered rounds stay recorded; reload vs reload for single last round -> one succeeds.

**Regression:** Player can still mount/dismount small tame without platform, PetRecord saves/loads all old fields, placed catapult remains Player-operable and consumes old ammo, `siege_probe` and catapult save tests pass. Platform roles and auto turrets do not work on private-home raid targets.

**Blockers:** real tribe roster, exact party slot rules, eligible species, platform socket geometry, mobile recoil/automation mechanical tech, capacity curves and future server authority.
