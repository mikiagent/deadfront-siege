# Crafting formulas, recipes, tools and failure

## Three recipe operation types
- Type 0 **Crafting**: 625 recipes producing new items.
- Type 1 **Processing**: 73 recipes transforming a selected ingredient in place, commonly spending processing count.
- Type 2 **Modification**: 22 recipes writing modification properties to equipment; their probability system can differ.

Recipes may require specified material categories/quantities, learned technique, crafting ability, tool, and workstation type/level. Some are basic, skill-unlocked, proficiency-gated, book-learned, hidden or event-locked.

## Core crafting success function
Given required ability `d`, actual ability `a`:

`P(success) = clamp(1 − (max(0,d−a)/100)^2, 0, 1)`

| Ability shortfall | Success |
|---:|---:|
| 0 | 100% |
| 20 | 96% |
| 40 | 84% |
| 60 | 64% |
| 80 | 36% |
| 100 | 0% |

The function is classified Original (confirmed) by the wiki. On failure, individual input loss probabilities partly use estimated server behavior. Flawless is a separate chance, with category-specific caps. Do not treat all results as one roll without checking the operation type.

## Item level
Ingredient-level averaging, recipe min/max limits, skill caps and station requirements must be kept distinct. The restoration explicitly changed some technique-level item-cap behavior, so require version-specific rules.

## Efficient data import strategy
Use original recipe ID as an import key. Store ingredients as typed slots with allowed tags, primary material status, tool/station requirements, technique, ability requirement expression, work time, and outputs. Build a source-status field per rule. Validate all referenced item and node IDs.

References: [Crafting rules](https://kghj76138.github.io/durango-homecoming-guide/en/craft.html), [All 720 recipes](https://kghj76138.github.io/durango-homecoming-guide/en/craft-list.html).
