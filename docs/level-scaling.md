# Unified level scaling

Every level-bearing thing uses the same 1-60 scale: zones set the target level; resources and creatures inherit it; gathered material stacks persist it; crafted outputs use the quantity-weighted floor of input levels, capped by the relevant specialist skill; tools, food, weapons and armor read their item level when calculating stats.

## First-slice formulas

- General item stat: `base × (1 + 0.08 × (level - 1))` unless the item defines a different per-level rate.
- Tool power: `(1 + 0.10 × (tool level - 1)) × material tier multiplier`.
- Material tiers: Stone 1.00, Bone 1.12, Flint 1.25, Obsidian 1.42, Copper 1.62, Bronze 1.85, Iron 2.12, Steel 2.45.
- Specialist ability: `1 + 0.025 × (skill level - 1)`. This shared hook lets Gathering, Cooking, Weapon/Tools and later specialists use the same progression model.
- Zone pressure: `1 + 0.12 × max(0, zone level - specialist level)`. Being five levels behind means 1.60x effort before tool and skill power offset it.
- Gather time: `base seconds × zone pressure ÷ (tool power × specialist ability)`, with a 0.25 second floor.
- Gather yield multiplier: `(tool power × specialist ability) ÷ zone pressure`, clamped from 1.0x to 4.0x.
- Crafted item level: `floor(sum(input item level × consumed count) ÷ total consumed count)`, capped by the recipe and specialist skill.

The first slice stores material tier on the primary crafting material and copies it to tool output. Resource yield now stores its zone/material level on the ItemStack itself, not only inside attributes. This keeps levels through inventory, save/load, crafting and tool use.


## 2026-10-25 owner-level gate and geographic unlock (future design)

See [canonical design decisions](game-design/decisions.md). An individual's equipment level is now an **equip requirement** as well as a scaling input: **an underleveled person cannot equip a higher-level item**, regardless of whether it was traded, bought, given, dropped, inherited or crafted. Downscaled equipment is **not** the selected solution. The exact use/equip threshold for food, tools, ammunition and other non-standard items and how specialist prerequisites compose with individual level remain open.

**PvPvE access requires reaching individual player level 60 to unlock level-60 islands.** The permission transition across switching to a different, low-level survivor in the same persistent tribe is OPEN and must not be assumed either way. This is new design guidance, **not confirmation current code enforces it**.

New private homes are purchased as **fresh larger islands with higher-level natural materials**, replacing abandoned older homes. Dismantled building materials are returned to a special vault; resources/levels/traits are not magically copied twice in migration.
