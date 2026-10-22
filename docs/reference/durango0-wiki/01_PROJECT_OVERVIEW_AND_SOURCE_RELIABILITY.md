# Durango:0 Homecoming: project and source reliability

Durango:0 Homecoming Dreamer is an **unofficial restoration and data-reference project** for Durango: Wild Lands. Its wiki combines extracted original client definitions, preserved rule-function outputs, and behavior supplied by restoration developers. **The public wiki is not evidence that a complete reusable server repository or license is available.**

## Evidence categories
- **Original (confirmed):** original extracted data field or surviving original client rule output, as classified by the wiki; still verify provenance for commercially important details.
- **Estimated:** reconstruction of server logic or missing fields.
- **Changed from original:** intentional rebalance, e.g. shorter work timers, food buff multipliers or skill availability.
- **Unverified:** page sections without solid evidence.

## Scope and catalog sizes
- 918 technique-tree nodes; 720 recipes (625 normal crafts, 73 in-place processing, 22 modifications).
- 220 wild animals in restoration data, including 214 originating from original animal data and six additions/clones.
- 111 pet entries; 352 food definitions; 262 original region templates; hundreds of structures and gatherables.
- Counts are database counts, **not** all guaranteed reachable player content.

## Recommended workflow for the game project
1. Start with definitions (skills, ingredient types, recipes, animals, structures).
2. Identify original client function outputs separately from reconstructed rules.
3. Carry `source_url`, `source_status`, `version`, and `last_verified` alongside every imported balancing datum.
4. Implement mechanics independently in your project's code; do not ship borrowed art, code or game branding without permission.
5. Treat rebalanced fork-specific numbers as optional presets, not historical originals.

## Availability limitation
This research pack is a **curated, source-linked guide**, not an offline mirror of the wiki or a full export of its hundreds of tables. Direct wiki page downloads were unavailable during compilation; indexed page extracts were checked. Follow the links for complete original tables.

References: [Wiki home](https://kghj76138.github.io/durango-homecoming-guide/en/index.html), [Crafting](https://kghj76138.github.io/durango-homecoming-guide/en/craft.html), [Skills](https://kghj76138.github.io/durango-homecoming-guide/en/skills.html), [Changes](https://kghj76138.github.io/durango-homecoming-guide/en/changes.html).
