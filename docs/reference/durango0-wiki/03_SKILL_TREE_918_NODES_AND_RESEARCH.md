# Skill trees, SP economy and research gates

## Model
Durango separates character level, per-category technique XP/level, and individually purchased skill-tree nodes. The original data contains 918 nodes. Skill prerequisites, SP cost, effect, level requirements, and the exact node catalog are in the linked wiki.

Twelve major categories: Survival, Melee, Ranged, Defense, Gathering, Butchering, Cooking, Weapon/Tool Crafting, Tailoring, Construction, Farming, Processing. A specialized Toxic Oil Island Survival category is separately recorded in some versions.

## Key behaviors
- Activity XP advances the corresponding category; category level does not automatically purchase every node.
- Individual nodes can grant recipes, combat abilities, harvesting rights, or bonuses such as Handicraft Ability +4.
- Research progression barriers appear at selected category milestones; preserve timer state and completion persistently.
- Historical original SP was limited and encouraged specializations. The restoration intentionally relaxed this constraint and resets.
- The restoration's work-speed bonuses and its choice to cap item level by technique level are labeled **changed from original**. Do not treat these as universally confirmed historical rules.

## Implementation
Static node definitions: `id, category, required_level, prerequisite_ids, sp_cost, ranks, effects, provenance`. Player save: category level, XP, purchased ranks, spent SP, research state. Validate prerequisite graph and award SP only once.

## Full catalogs
The full 918-row interactive skill table is available at the source link. It should be used as a source of truth for original node names/requirements rather than recreating all node records from this abridged overview.

References: [Skills and 918-node catalog](https://kghj76138.github.io/durango-homecoming-guide/en/skills.html), [Character stats](https://kghj76138.github.io/durango-homecoming-guide/en/stats.html).
