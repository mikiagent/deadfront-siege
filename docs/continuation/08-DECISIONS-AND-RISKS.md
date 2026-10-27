# Continuation-specific owner decisions and risks

This list differs from a clean rebuild's design queue because **the current game already has important shipped rules and persistent saves**. Owner decisions must account for existing saves, level ranges, recipes, current UI and known code callers.

| Priority | Decision | Current implemented fact | Proposed migration path, not automatic owner approval |
|---|---|---|---|
| C-P0-01 | Whether existing saves must remain compatible | Current schema3, versions0..3 migratable; invalid future file leads to start_new | **Default safe recommendation:** yes, preserve all known saves and never silently overwrite unreadable save |
| C-P0-02 | How to merge signed traits into `ItemStack` without changing stacking | `attributes` equality controls merging; `Crafting.build_output` currently inherits primary only | Opt-in `TraitResolver` and persisted compact provenance signature; no per-stack UUID injected into attrs blindly |
| C-P0-03 | Level/attribute transition for legacy avatar | `World.pioneer_level/xp` and `SkillState` exist, 7 creature genetic IV types are 0..31 | Import one human identity retaining earned career, keep old creature IV/EV fields and add mapping to D/M taxonomy deliberately |
| C-P0-04 | Unstable reset materials | Existing instability/cargo warp behavior differs from new owner WORLD-01 salvage-to-vault; newest prefab source suggests structure loss | Choose exact recovery percentage and occupant handling before migration; home paid move 100% remains locked |
| C-P1-05 | Food freshness for existing stored food | Current food and saved inventories lack `food_state` | Decide first-load freshness and timestamp policy; old food shouldn't all rot upon update due to old save age unless explicitly approved |
| C-P1-06 | Structure IDs and pack/transfer policy | Current `PlacedBuilding.pack_up` kit-return and storage emptying; no maker/trait UUID | Add stable structure ID only for new advanced prefabs, with legacy migration, capacity preflight and de-dup test |
| C-P1-07 | Human crew/expedition party slots | Player rides pet on single mount socket; no true human crew roster | Count real extra gunner as real deployed actor; exact avatar-vs-3 companion slots unresolved |
| C-P1-08 | T. rex and Brontosaurus | Current tyrannosaurus JSON `tameable:false`; existing Brachiosaurus separate | Approve proper late-game capture mechanics and distinct Brontosaurus content; don't flip boss tame flag without balance tests |
| C-P1-09 | Turret automation and tech ceiling | Catapult currently manual Player-only, 8-24m and `stone_shot`/`toxin_pot` | Preserve stationary catapult; approve primitive automatic mechanism, arcs, finite ammo, NPC skills, species mount fits |
| C-P2-10 | Multiplayer authority/frontier scope | World tracks an in-game tyrant boss win, but this is not live PvPvE | Require server-authoritative raid and 72h ransom for real players, anti-punch-down class rules and no client-trust custody |
| C-P1-11 | Deployment and target client | Current HANDOFF uses desktop Chrome as native acceptance and preserve touch; older iOS-first docs differ | Continue current desktop + touch gate until owner changes platform; preserve web export and exact pack hash |
| C-P1-12 | Rebalancing legacy items/recipe levels | Existing item/recipe IDs and skill/progression tables power real play | Introduce new tiers and stations only with measured impact and old save compatibility, don't silently reassign acquired gear levels |

## Highest-severity concrete problems to test while extending

1. Corrupt or unsupported schema currently starts a new world; autosave after that may overwrite a valuable save.
2. Stacking breaks if unique per-lot ID is inserted into the `attributes` dictionary and equality is blindly preserved.
3. New trait fusion without truly representing all consumed lots discards negatives or makes rare-source properties duplicate.
4. Existing `PlacedBuilding.pack_up` doesn't preflight bag acceptance for the kit and stored contents, risking loss/duplication when unique prefabs are introduced.
5. Third-party/AI gunner logic cannot call `FieldCatapult.fire(Player,...)` without a compatibility abstraction, and its current Player inventory must not become hidden magic shared ammo.
6. New `CreatureGenetics` taxonomy could erase or reinterpret existing IV=31/EV=100/300 profiles and level gains.
7. An offline worker, gunner, mate or rider could be represented multiple times if an individual actor's physical job/seat location isn't unique.
8. `World.cargo_warp` is currently an instant paid cargo mechanic, not a protected moving boat. Replacing it immediately will break existing expedition logistics.
9. `WORLD-02` unresolved reset refund conflicts with one source; never delete or refund exposed buildings based on an unapproved interpretation.
10. Current client game has no server authority for actual player PvPvE. Implementing capture/ransom purely on client invites duplication and integrity issues.

## Rule precedence

1. Latest explicit owner direction for desired future behavior.
2. Current `docs/game-design/decisions.md` confirmed rule IDs; mark unresolved details as OPEN.
3. Current code/tests for what actually executes, including schema 3 and current item/creature IDs.
4. Existing `HANDOFF.md` and `GAUNTLET.md` for shipping discipline, unless superseded.
5. Proposed formulas/design chapters and clean-rebuild drafts as references only.

If a future decision must deliberately break current saves or behavior, require explicit migration/transition path and a reviewable compatibility report. Do not silently take that breaking step.
