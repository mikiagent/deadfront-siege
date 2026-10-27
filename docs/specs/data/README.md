# Machine-readable data conventions

All files under this directory are **candidate proposal fixtures**, not approved gameplay balancing. They may be used to compare implementations in a sandbox but must not be treated as LIVE product rules until the owner signs off.

- `candidate-balancing.v0.json`: every numeric coefficient in the candidate formula set grouped by domain, including intentional nulls for unresolved values.
- `candidate-fixtures.v0.json`: input/output goldens; `status=test_vectors_not_run_in_Godot`.
- `candidate-weapon-matrix.v0.json`: 18 source-informed weapon assembly candidates and verified item/recipe presence flags, NOT approved or built.
- `candidate-recipes.v0.json`: intermediate material path with source verification markers; **not** all items exist in old game data.
- `candidate-save-schema.v0.json`: proposed shape of persistent snapshot; requires engineering review and migration plan.
- `system-graph.v0.json`: domains and load-on-demand links. Dependency cycles in this document represent design interactions, not legal source import cycles.

Before promotion, validate JSON schema, cross-reference every `def_id` and source via `game/data/items.json`, `game/data/recipes.json`, `game/data/nature_manifest.json`, `game/data/butchering.json`, then write verified `approved-v1` tables and immutable golden fixtures. No invisible default values for OPEN fields.
