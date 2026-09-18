# Addendum for Cursor: world data is canonical (applies to M5, M6, M10)

The orchestrator wrote the level design: `docs/design/world-design.md` (read it, it is short) and its machine-readable twin under `game/data/world/`:

- `rules.json` — island size, the five rings with radii and material level offsets, crater and warp-ruin rules, lifetimes, the crafted-level rule, latent attribute meanings.
- `climates.json` — every climate: tiers, resistances, vegetation families (nature manifest names), materials with their latent attribute, weather set.
- `islands.json` — the catalogue: home island with its five terrains, and fourteen unstable islands with per-ring spawn tables (species, count per group, groups, tier offset, chance).

Use these instead of inventing `game/data/islands/temperate_25.json` from scratch: M5's island generator takes an entry from `islands.json` plus `rules.json` and `climates.json`; the ring layout (landing → gathering → working → crater → far shore) is the level design. Material levels come from island tier + ring offset. Items named in `climates.json` that are not yet in `items.json` get added with sensible categories. Species not yet modelled fall back to the placeholder creature exactly as M1 did; do not skip them.

You may add fields to these files (positions, seeds) but ask before changing numbers; they are tuned against the PRD's progression geography (§17).
