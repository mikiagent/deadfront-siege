# DEADFRONT | Product north star

**Status:** Summary of confirmed owner direction, with explicitly noted gaps. Cross-check each binding detail against `docs/game-design/decisions.md`.

## One-sentence promise

Build a long-lived prehistoric tribe and safe home economy through risky expeditions, physically meaningful materials and crafted structures, individual human and dinosaur progression, and optional high-stakes frontier conflict.

## Game identity

- **Protected home, earned civilization.** Every player has a permanently attack-proof private home island. It is the persistent center of people, dinosaurs, crafting, growing resources, housing, industry and trade. Home upgrades are paid migrations to new, larger resource-richer islands, not raidable land expansion.
- **Expeditions with consequential choices.** Explore levelled regions, gather distinct material lots, fight and tame actual creatures, carry finite loads, establish temporary worksites, and bring resources home. Unstable islands reset; relevant installed buildings are dismantled to the special recovery vault at reset, with refund percentages and occupant safety still open.
- **Craftsmanship is the economy.** Gather, refine and combine material traits, build intermediates, construct durable blueprints and eventually pack/sell finished buildings. Workers and logistics must move physical inputs rather than produce unexplained free outputs.
- **People are individuals.** Each human has their own level, inherited potential, acquired skills, needs and identity. Generations can inherit potential and a civilized base, not a magical transfer of earned experience. Higher-level equipment cannot be equipped by a lower-level individual.
- **Dinosaurs are creatures, not itemized mounts.** Capture, care, breeding, anatomy, mass, attacks, armor, riding and companionship must be visible, grounded and tactically legible. A rider's melee weapon has actual reach; giant bodies have real geometry.
- **Cooperative siege is a deliberate extension of the mount fantasy.** Very large eligible mounts may hold one crewed siege weapon, two automatic turrets and one shared physical ammo box. The player may drive while a real tribe member operates the weapon, or man the gun while a real tribe member drives. Every human, machine, round and cargo load must exist in game state.
- **Optional danger, not forced home loss.** Level 60 opens an optional PvPvE frontier for individually eligible characters while their tribe retains its unlock. The home remains unraidable. PvE outposts face wildlife threats; player raids concern built frontier settlements. A loaded boat is safe from attack once it genuinely departs for home. Human/dinosaur captives in permitted PvPvE follow the confirmed 72-hour ransom framework.

## Emotional and experiential target

The player should see their private island grow from a small camp into a bustling working community. Their best materials, crafted equipment, workers, animals, and family line should have history. A dangerous expedition should matter because it can improve that community, and losing an exposed frontier venture should hurt without deleting civilization at home.

## Primary player loop

1. Prepare a person, expedition party, dinosaurs, equipment and real supplies at the protected home.
2. Choose a destination and risk tier.
3. Explore, fight, tame and gather materials with distinct quality/traits.
4. Move real cargo back to safety, manually or through eligible physical logistics.
5. Process material lots; craft consumables, gear, blueprints and finished structures.
6. Invest in home production, workers, offspring, animals, upgrades and market goods.
7. Unlock more specialized expeditions. Optionally compete over exposed PvPvE settlements after the personal level gate.

## Non-negotiables

- Do not turn a player's permanent home into a raidable base through progression, wealth or offline status.
- Do not introduce high-level gear downscaling as a workaround to personal equipment level gates.
- Do not silently replace the confirmed Dexterity/Might plus Impact/Pierce/Slash attack taxonomy.
- Do not let procedural/simulated work create free goods, duplicate owners or skip real inputs.
- Do not teleport actors into seats, duplicate projectile/ammo ownership, give unstaffed guns imaginary crew or ignore geometry.
- Do not call a proposed number or formula approved.
- Do not copy Durango assets, code, names or other proprietary material. Draw design lessons but build original identity.

## Scope and quality

**Long-term product intent:** a mobile-compatible dinosaur survival/economy game with optional PvPvE at high progression. **Existing implementation:** Godot 4.7.1, typed GDScript, current desktop Chrome verification gate, touch preservation; older project plans sometimes still say mobile-first native as the immediate release target. A new-from-scratch plan must explicitly choose its initial runtime/export gate rather than inherit contradictory historical execution instructions.

**Implementation strategy:** a polished **single-player proof first** with multiplayer-compatible identity and ownership boundaries. No claim of live PvP/markets without server-side authority, persistence and abuse prevention. A vertical slice demonstrating gathering -> trait-aware inventory -> refining -> crafted gear -> expedition -> tame -> return and save is more valuable than dozens of menu-only systems.

## Explicitly not settled here

Final number balancing, crafting yield curves, inheritance equations, material trait distribution, species capacities, population economy, multiplayer server topology, raids and timers for resets are not fully approved just because they have draft text. See the gap register. The north star is a compass, not an executable ruleset.
