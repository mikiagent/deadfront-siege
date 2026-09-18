# Addendum for Cursor: world data is canonical (applies to M5, M6, M10)

The orchestrator wrote the level design: `docs/design/world-design.md` (read it, it is short) and its machine-readable twin under `game/data/world/`:

- `rules.json` — island size, the five rings with radii and material level offsets, crater and warp-ruin rules, lifetimes, the crafted-level rule, latent attribute meanings.
- `climates.json` — every climate: tiers, resistances, vegetation families (nature manifest names), materials with their latent attribute, weather set.
- `islands.json` — the catalogue: home island with its five terrains, and fourteen unstable islands with per-ring spawn tables (species, count per group, groups, tier offset, chance).

Use these instead of inventing `game/data/islands/temperate_25.json` from scratch: M5's island generator takes an entry from `islands.json` plus `rules.json` and `climates.json`; the ring layout (landing → gathering → working → crater → far shore) is the level design. Material levels come from island tier + ring offset. Items named in `climates.json` that are not yet in `items.json` get added with sensible categories. Species not yet modelled fall back to the placeholder creature exactly as M1 did; do not skip them.

You may add fields to these files (positions, seeds) but ask before changing numbers; they are tuned against the PRD's progression geography (§17).

## Also available (added later the same day)

- `game/data/icons_manifest.json` + `game/assets/icons/*.png`: 128 px transparent inventory icons rendered from the real models, with aliases and per-category fallbacks. Inventory and craft UI should use them instead of text-only slots (M4/M6 UI pass).
- `game/data/world/factions.json` and `missions.json`: the four radio organisations plus Radio University, trust ranks, crate bands, and mission templates with pins per island ring. M9 consumes these.
- `game/data/world/market.json` with `docs/design/economy.md`: the simulated four-region Island Market. M9.
- `game/data/skills/trees.json` with `docs/design/skills.md`: the twelve skill trees, SP costs, level gates, research gates. M8. `survival.json` stays yours; migrate its capture nodes into the tree file's Survival tree when M8 lands.
