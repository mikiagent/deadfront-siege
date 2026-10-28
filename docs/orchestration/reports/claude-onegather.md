# ONEGATHER: one item per harvest

Owner, 2026-10-28: "it should be only gathering one at a time. it looks like you gather like 12 of them in one
harvest. cap it to 1 per harvest and upgrades can change the speed and quality of the materials you harvest, not
the amount".

## What shipped

- Every gather pass lands exactly one instance, on the client (`HarvestNode.roll_yield`, `PlayerActions.finish_gather`)
  and the server (`act.gather`). The manifest's `[min, max]` per pass no longer counts (data left in place).
- The count multiplier is gone: `GatherService.yield_multiplier*` and `ProgressionScaling.gather_yield_multiplier` deleted.
- Speed: unchanged code path (`ProgressionScaling.gather_seconds`): tool tier, tool level and Gathering level shorten a pass.
- Quality: the working tool's material tier raises the per-unit rare-trait odds, `loot_tables.json`
  `rare_trait.tool_tier_bonus` 0.15 of the base per tier above stone, cap `max_chance` 0.15 (`LootRoller.trait_chance`).
  Bare hands and stone keep the documented 5%. Gathering level still never raises it (spec 12:42).
- Node pools unchanged (Rock / CommonTree 30 passes, Bush 12).
- The top-middle feed toasts +1 per pass; repeats still collapse.
- trees.json: butchering `yield_1` / `yield_2` "+20% / +40% yield" now "+20% / +40% cut speed (still one part per
  cut)"; `yield_1` impl functional to defined (its impl_ref named the old count code; cut speed reads the Butchering
  level, not the node). Gathering `great_success_1` / `_2` reworded "a finer material, never extra units", still defined.

## Before / after (Rock stone, CommonTree branch at Gathering 1 and 30; avg of the [2, 4] per-pass roll)

| Tool | units/pass before (G1 / G30) | s/pass (G1 / G30) | s/unit before (G1 / G30) | units/pass after | s/unit after (G1 / G30) |
|---|---|---|---|---|---|
| Rock, hands | 3.0 / 5.2 | 3.78 / 2.19 | 1.26 / 0.42 | 1 | 3.78 / 2.19 |
| Rock, stone pick | 3.0 / 5.2 | 2.80 / 1.62 | 0.93 / 0.31 | 1 | 2.80 / 1.62 |
| Rock, flint pick | 3.8 / 6.5 | 2.24 / 1.30 | 0.60 / 0.20 | 1 | 2.24 / 1.30 |
| Rock, copper pick | 4.9 / 8.4 | 1.73 / 1.00 | 0.36 / 0.12 | 1 | 1.73 / 1.00 |
| Rock, iron pick | 6.4 / 11.0 | 1.32 / 0.77 | 0.21 / 0.07 | 1 | 1.32 / 0.77 |
| Rock, steel pick | 7.4 / 12.0 | 1.14 / 0.66 | 0.16 / 0.06 | 1 | 1.14 / 0.66 |
| Tree branch, hands | 3.0 / 5.2 | 2.16 / 1.25 | 0.72 / 0.24 | 1 | 2.16 / 1.25 |
| Tree branch, stone axe | 3.0 / 5.2 | 1.60 / 0.93 | 0.53 / 0.18 | 1 | 1.60 / 0.93 |
| Tree branch, steel axe | 7.4 / 12.0 | 0.65 / 0.38 | 0.09 / 0.03 | 1 | 0.65 / 0.38 |

Rare-trait odds per unit after: hands/stone 5%, bone 5.75%, flint 6.5%, obsidian 7.25%, copper 8%, bronze 8.75%,
iron 9.5%, steel 10.25%.

## Tests

t_onegather (new), t_gather, t_rareattr, t_xpecon, t_levelfx, t_uigather, t_gatherglide, t_lootradial, t_butcher,
t_skilltrees, t_save PASS; run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.

## ASSUMPTIONS and notes for the next agent

- `# ASSUMPTION`: tool tier is the quality lever (+15% of the 5% per tier, cap 15%). Material level stays the node's
  level downranked to max(Gathering, 5).
- Seconds per pass were left as they were, so material throughput drops 3x to 12x. If gathering now feels slow, tune
  `gather_seconds` / `OPTION_SECONDS`, not the count.
- `nature_manifest.json` `harvest` [min, max] pairs and srvdom's fixture `min`/`max` are now inert; remove them in a
  data cleanup if wanted.
- Butchering code was not touched (LOOTRADIAL owns it); only the two yield node texts changed.
