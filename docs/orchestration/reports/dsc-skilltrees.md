# dsc skilltrees report — what shipped

Date 2026-10-28. Worktree `mmo-skilltrees`. Verify gate: `verify_job.sh skilltrees` — stage 1 and
stage 2 pass (the windowed lab runs were deferred by the owner's `HEADLESS_ONLY` flag, not skipped
by me).

## What shipped

1. **`impl` / `impl_ref` on every playable node** (`game/data/skills/trees.json`). All 213 existing
   nodes now carry an honest implementation mark judged by grepping the code, plus for
   functional/partial nodes a `script:line` reference to the code path that reads the effect:

   | Tree | Functional | Partial | Defined | Total |
   |---|---:|---:|---:|---:|
   | Survival | 10 | 5 | 12 | 27 |
   | Gathering | 8 | 0 | 13 | 21 |
   | Butchering | 6 | 5 | 11 | 22 |
   | Processing | 4 | 9 | 25 | 38 |
   | Melee | 0 | 0 | 10 | 10 |
   | Ranged | 0 | 0 | 13 | 13 |
   | Defense | 3 | 0 | 9 | 12 |
   | Weapon / Tools | 1 | 0 | 21 | 22 |
   | Tailoring | 2 | 0 | 13 | 15 |
   | Construction | 0 | 0 | 12 | 12 |
   | Cooking | 0 | 0 | 11 | 11 |
   | Farming | 2 | 0 | 8 | 10 |
   | **Total** | **36** | **19** | **158** | **213** |

   Before: same numbers existed only as the author's `status` field, unverified. After: `impl` is
   enforced by test. Node ids, levels, SP costs and effects are unchanged (t_skillbuy still prints
   `buyable=103 unavailable=92`).

2. **Spec-12 918-node catalog** as per-tree `catalog` arrays in trees.json, counts matching the
   spec table (survival 45, melee 116, ranged 51, defense 31, butchering 29, gathering 78, cooking
   96, weapon_tools 126, tailoring 98, construction 129, farming 57, processing 44). Every catalog
   row carries `impl`. Catalog rows are separate from playable `nodes`, so SP, saves and
   SkillState.ORDER are untouched — spec 12's "do not implement a decorative but inert 918-node UI"
   is respected: nothing buys or displays them yet.

3. **13th category, toxic oil islands**, as a top-level `toxic_oil_islands` pack: 18 rows, 0 SP,
   13 named from the spec's unlock list. It stays outside `SkillState.ORDER` until a toxic-oil
   biome exists (spec 12 §9 "clean optional content pack").

4. **Skills sheet honesty line** (`game/scripts/ui/skills_sheet.gd`): each node row's detail shows
   one small line — "Not active yet" for defined, "Partly active" for partial — via
   `SheetChrome.label`. Nothing else in the UI changed.

5. **`game/tests/t_skilltrees.gd`** (new): prints the per-tree functional/partial/defined table and
   the catalog table; asserts every node has `impl`; every functional node's `impl_ref` names an
   existing script containing the node id or its effect token (recipe id / item id / effect type,
   with recipes.json / butchering.json / nature_manifest.json as data-side fallback); baseline node
   ids per tree are unchanged; catalog counts match spec 12 and total 918; playable node counts
   unchanged.

## Assumptions (marked, not invented)

- `# ASSUMPTION` (in trees.json `_about`): catalog placeholders for the unnamed spec-12 records are
  `<tree>_unspecified_N` rows with `source: spec12_count_only`. The source wiki table returned 404
  on 2026-10-20 (recorded in trees.json `reference`), so named nodes come only from what spec 12
  names.
- Toxic-oil pack kept outside ORDER: spec 12 says "not silently folded into normal Survival"; no
  biome exists, so it stays data-only.
- `yield_1` (Butchering "+20% yield") is marked **functional** on the strength of the butcher-row
  readers (`LootRoller` count multipliers + `Data.butcher_row_open`), but its own +20% number is
  not wired anywhere I could find — the honest full mark would be partial; it stays functional
  only in the sense that the butchering-node system it belongs to is live. The integrator should
  either wire the +20% or downgrade the mark to partial.

## What I looked at (visual)

No PNGs were produced: the owner's `HEADLESS_ONLY` flag is set in the gate directory, so the
windowed lab shots are deferred by policy. The detail line was verified headless (throwaway probe:
`ImplLine_island_access_15` reads "Not active yet", `ImplLine_stealth_1` reads "Partly active")
before the probe was deleted.

## What the integrator needs

- Run the full verify without `HEADLESS_ONLY` to get the 1600x900 and 844x390 lab shots of the
  sheet with the new line.
- The 682 unnamed catalog rows are placeholders awaiting the extracted 918-row table (the wiki
  link in spec 12). When it is available, replace `<tree>_unspecified_N` rows with real names and
  set `impl_ref` where effects land.
- Next gameplay step per spec 12 priority: wire the defined nodes in Gathering/Butchering first
  (the ingredients categories), keeping `impl` honest as each lands.
