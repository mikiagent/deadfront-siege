# Gathering, resource ecology and farming

## Gathering
The restoration records several hundred resource definitions and 244 gatherables with yield lines in the gatherable catalog. Data includes required tool, technique unlock, output item, work time and compatible islands. A gathering attempt can roll success, item level, traits and processing count. Some server-side chance distributions are estimated.

For implementation: define per-node quantity, health/depletion, biome and habitat, resource respawn, harvesting action, tool requirements, materials generated, XP and fatigue cost. Preserve exact item instance per gathered resource.

## Farming
The wiki documents 53 crops, with seed/field compatibility, crop level, growth time, watering, sprinkler effects, soil fertility and affinity, survival chance and harvest yields. Treat seeds and harvested crops as separately leveled/attributed items. Farming experience and skill unlocks govern advanced crops and infrastructure.

## Biome integration
Resource lists depend on island level, biome and sometimes unstable index. A high-level resource may be in a special mining site rather than distributed across all terrain. The wiki describes source-specific guardians and contested resource locations. Reconstructed volcanic resources include sulfur, charcoal and black iron ore.

## Recommended data schemas
`GatherableDefinition(id, biome_tags, level_range, required_tool_tags, required_skill_nodes, yields, respawn_rules)`
`CropDefinition(id, seed_id, soil_affinity, water_curve, growth_duration, harvest_outputs, skill_requirements)`

References: [Gathering rules](https://kghj76138.github.io/durango-homecoming-guide/en/gather.html), [Gatherable catalog](https://kghj76138.github.io/durango-homecoming-guide/en/gather-list.html), [Farming](https://kghj76138.github.io/durango-homecoming-guide/en/farming.html), [Islands](https://kghj76138.github.io/durango-homecoming-guide/en/world.html).
