<!-- Owner's prompt, pasted 2026-10-21 evening, answering "what should upgrade slots?". Filed verbatim as spec 31. -->

# Implement Durango: Wild Lands-Inspired Bag Levels, Quality, and Inventory Capacity

## Objective

Implement the original Durango: Wild Lands-style bag and inventory expansion system in my existing survival game.

**Bag level, bag type, material quality, and inherited attributes must all contribute appropriately to storage capacity.**

Do not implement a simplistic system where every bag provides the same number of slots or where bag capacity is determined entirely by item level.

Inspect the existing inventory, equipment, crafting, material attributes, character stats, and persistence systems before making changes.

## 1. Base Inventory Capacity

Players begin with 100 inventory spaces.

Calculate personal capacity dynamically:

```python
total_capacity = (
    base_inventory_capacity
    + equipped_bag_capacity
    + equipment_storage_bonuses
    + other_valid_capacity_modifiers
)
```

Do not count dinosaur cargo or storage-container slots as personal inventory capacity.

Those must remain separate inventories.

## 2. Bag Types

Implement multiple craftable bag types with different capacity progression.

Examples:

- Basic Bag
- Small Pouch
- Large Pouch
- Advanced Backpack
- Specialized Storage Bag

Use existing recipes and equipment definitions where available.

Different bag types should have their own:

- Base capacity
- Crafting requirements
- Minimum crafting level
- Material requirements
- Equipment restrictions
- Capacity scaling rules
- Possible inherited properties

Do not invent a universal formula that makes every bag type identical.

## 3. Bag Item Level

Every crafted bag must have an individual item level.

Determine the level through the existing material-based crafting system, considering:

- Levels of selected materials
- Relevant crafting category level
- Recipe maximum level
- Recipe-specific level calculation

The bag's level can influence its base storage capacity where the bag definition specifies level scaling.

Example:

```python
base_capacity = bag_definition.get_capacity_for_level(
    crafted_bag.level
)
```

Use a configurable table or scaling curve.

**Important:** Bag level and capacity bonus are different statistics. A level-60 bag does not automatically grant 60 spaces.

## 4. Material Quality and Inherited Attributes

Crafting materials can have their own positive, negative, and rare attributes.

When creating bags, use the existing material-inheritance system.

A bag made from carefully selected high-quality materials should potentially provide better storage bonuses than an ordinary bag of the same level.

Preserve:

- Individual material instances
- Material levels
- Positive attributes
- Negative attributes
- Rare attributes
- Primary-material inheritance
- Crafting quality
- Flawless outcomes where applicable

Do not replace material-based quality with arbitrary Common, Rare, Epic, or Legendary rolls.

## 5. Pocket Attribute

Implement the **Pocket** equipment property as an inventory-capacity modifier.

Use this historical reference value:

**Pocket Lv. 1 = +6 inventory spaces**

Formula:

```python
pocket_capacity_bonus = pocket_level * 6
```

Examples:

| Pocket level | Extra inventory spaces |
|---|---:|
| 1 | +6 |
| 3 | +18 |
| 5 | +30 |
| 8 | +48 |

This value should be configurable.

The Pocket attribute must come from compatible equipment properties or inherited crafting attributes, not appear automatically on every high-level bag.

## 6. Bag Capacity Calculation

Calculate a bag's contribution from its actual definition and inherited modifiers.

```python
bag_capacity_bonus = (
    bag_base_capacity
    + pocket_capacity_bonus
    + other_compatible_storage_modifiers
)
```

Example comparison:

| Property | Ordinary Bag | Specialized Bag |
|---|---:|---:|
| Item level | 60 | 60 |
| Base capacity bonus | +60 | +60 |
| Pocket | None | Lv. 5 |
| Pocket capacity bonus | 0 | +30 |
| Total bag bonus | +60 | +90 |

These values are illustrative, not verified original bag recipes.

Both bags have the same level, but the specialized bag provides more inventory space.

## 7. Equipment Integration

Inventory capacity must update when players equip or unequip bags or clothing that modifies storage.

Requirements:

- Recalculate maximum capacity.
- Remove modifiers from unequipped gear.
- Apply modifiers from newly equipped gear.
- Prevent duplicate modifier application.
- Preserve existing inventory items.
- Refresh the Bag capacity indicator.

Example:

Base capacity: 100

Equipped pouch bonus: +90

Clothing Pocket bonus: +24

**Total capacity: 214 spaces.**

Use the actual equipped-item data for every calculation.

## 8. Inventory Overflow

Handle capacity reductions safely.

If a player has 175 occupied slots and attempts to remove equipment that would reduce maximum capacity to 150, the game should not delete items.

Prefer blocking the unequip action and displaying an informative message.

If the project supports a different overflow policy, use it consistently.

Never silently discard rare items.

## 9. Bag Inspection UI

The inventory interface should clearly show the difference between bag level and storage capacity.

Example:

**Advanced Pouch**

Level 60

Storage Capacity: +90

Base Capacity: +60

Pocket Lv. 5: +30

Crafting Quality: Normal

Durability: 180/180

The player should see the actual capacity improvement before equipping the item.

### Equipment Comparison

When comparing bags, show the change in capacity.

Example:

Current bag: +60 slots

New bag: +90 slots

**Capacity change: +30 slots**

Use green for improvements and an appropriate warning color for reductions.

## 10. Crafting Integration

Bag recipes must use the existing item crafting pipeline.

Players should select exact material instances.

The crafting preview must calculate:

- Expected bag level
- Base storage capacity
- Inherited storage attributes
- Pocket bonus
- Other applicable modifiers
- Final expected capacity
- Crafting success chance
- Flawless chance where supported

Do not assign random capacity bonuses unrelated to the selected materials.

The preview and final crafting result must use the same calculation rules.

## 11. Inventory UI Integration

The Bag header should display:

**Bag: 91 / 190**

Where:

- 91 is the number of occupied inventory spaces.
- 190 is the current maximum capacity after equipped bonuses.

Update the indicator immediately after equipment changes.

Ordinary materials must remain individually stored.

A larger backpack increases the number of available spaces. It does not automatically merge bones, berries, leather, or other individually attributed resources into stacks.

## 12. Cargo Dinosaur Distinction

Dinosaur cargo inventories must remain separate.

Example:

Player Bag: 150 spaces

Cargo Dinosaur: 200 spaces

These are two independent inventories.

Do not display them as one 350-space personal Bag.

The player must transfer items between them through the existing inventory system.

## 13. Technical Architecture

Keep these responsibilities separate:

- Bag item definitions
- Individual crafted bag instances
- Material attribute inheritance
- Bag capacity calculation
- Character inventory capacity calculation
- Equipment modifiers
- Inventory occupancy
- Inventory UI

Use a centralized capacity calculation rather than duplicating formulas across scripts.

All capacity modifiers must be deterministic and derived from equipped items and active effects.

## 14. Testing Requirements

Test:

1. Starting inventory capacity of 100.
2. Equipping a basic bag.
3. Equipping a high-level bag.
4. Two same-level bags with different attributes.
5. Pocket Lv. 1 granting six spaces.
6. Pocket Lv. 5 granting 30 spaces.
7. Multiple compatible storage modifiers.
8. Equipping and unequipping repeatedly.
9. Prevention of duplicate capacity bonuses.
10. Inventory overflow handling.
11. Bag crafting from individually selected materials.
12. Correct crafting previews.
13. Saving and loading equipped bags.
14. Saving and loading bag attributes.
15. Accurate Bag capacity display.
16. Preservation of individual nonstacking items.
17. Separation of personal and dinosaur inventory capacity.

## 15. Historical Accuracy

Preserve the original Durango design principles:

- Base personal capacity of 100 spaces.
- Storage bonuses from equipped bags and clothing.
- Individual equipment levels.
- Material-derived bonuses.
- Pocket attributes contributing extra storage.
- Separately managed dinosaur cargo inventories.
- Individually stored resources.

Distinguish original documented mechanics from illustrative bag progression curves and newly designed recipes.

Do not claim that every higher-level bag automatically has greater capacity. Its actual bonus must be determined by its bag definition and compatible attributes.

## Final Objective

Create a system where players have meaningful reasons to craft better bags and search for materials with useful storage-related attributes.

Two bags of the same level can have different capacities.

A specialized bag built from carefully selected materials can provide more storage than an ordinary version.

The player should be able to inspect, compare, craft, equip, and use these bags through the existing inventory interface.

**Implement this directly into the existing game, connect it to the previous Durango-inspired material crafting and inventory systems, and verify that all capacity changes work correctly.**

Do not stop at pseudocode or a conceptual design.
