# Material traits, rare properties and processing

## Core philosophy
Material quality is separate from material level. Two bones of the same level may have different positive, negative, or rare latent attributes and different processing counts. They must remain unique item instances.

## Selected mappings
- Firm: higher weapon attack; Soft: lower attack.
- Lightweight: weapon accuracy, clothing evasion, or storage capacity depending on eligible crafted item.
- Compact Structure: lethality potential; High Density: durability.
- Tough Fiber: armor defense; Fluffy: cold resistance; Thin: heat resistance.
- Beautiful Pattern: comfort on appropriate construction.
- Some rare properties produce combat procs, gathering effects or workstation improvements; validate compatibility with recipe/material role.

## Processing operations
- Compressed material: can improve High Density.
- Surface processing: can improve Lightweight.
- Precision work: can improve Compact Structure.
- Debris processing: can improve Firm while introducing a Low Density drawback.
- Tanning changes leather properties; metalwork refines ores and creates specialized alloys.

Some per-level numerical conversion coefficients come from the restoration or estimates. Consult the live property table before treating values as original.

## Architecture
Every item holds `instance_id`, definition, level, attribute IDs and strengths, processing_remaining and processing_history. Processing validates exact instance, station, tool, recipe, ingredients, and locks item for the transaction. Finished-item trait inheritance depends on primary-material slots and recipe-specific compatibility.

## Rare-effect examples
Black Sheen and Low Vibration are examples of latent material properties associated with special combat effects. The same raw latent tag does not mean the same applied perk on every output type. Record provenance for transfer rules.

References: [Material properties](https://kghj76138.github.io/durango-homecoming-guide/en/materials.html), [Crafting & processing](https://kghj76138.github.io/durango-homecoming-guide/en/craft.html), [Recipes](https://kghj76138.github.io/durango-homecoming-guide/en/craft-list.html).
