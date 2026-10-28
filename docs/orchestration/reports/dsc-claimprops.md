# dsc — CLAIMPROPS: no stray props inside claimed land

Owner, verbatim: "props should be removed from claimed land/domains (I shouldn't have a tree stump or
log with my claimed land so it's a bug (especially if it can't be harvested))."

## What shipped

Claimed and expanded domain cells hold no scenery:

| file | change |
|---|---|
| `game/scripts/world/island_props.gd` | placement filter `_claimed_footprint()` + `_foot_radius()` (a prop whose centre is outside but whose body reaches into a claim is skipped); `clear_claimed()` (sweep, force-clears indestructible cliffs too); `on_claimed_count()`; `rows_in_rect()`; `_clear_index(i, record, force)` |
| `game/scripts/world/island_claims.gd` | `clean_claimed(rt)` + `node_gatherable(node)`; called from `claim_cells()` right after the grass clear, so Declare and Expand both clean |
| `game/scripts/world/island_runtime.gd` | `IslandClaims.clean_claimed(self)` immediately after `IslandProps.build(self)` — the load-time sweep |
| `game/scripts/world/island_scatter.gd` | `family_gatherable()`; the clump scatter and the special-tile placement skip claimed tiles for any family with no usable gather option |
| `game/tests/t_claimprops.gd` | new acceptance test |
| `docs/current/world-biomes.md` | new section "Claimed land is clear of scenery" |

Harvestable nodes stay (spec 29 section 6 gives the owner build/manage rights, not a stripped plot);
grass/ground cover was already kept off claimed land and is unchanged.

## Numbers (headless, home_grassland, `[props]`/test log)

- Claim of one 4x4 cell with a planted fallen log, tree stump, 4 m cliff and a non-gatherable HarvestNode:
  3 props removed, 0 left in the cell, 0 left on claimed land; the non-gatherable node removed; a
  gatherable Plant node kept and still offering `herb_leaf`.
- Expansion into the next cell: 1 prop removed, 0 on claimed land `(used=2)`.
- Reload from the seed with the same saved claim (3 cells): `props on them=0`, no non-gatherable node.
- After simulated regrow time (`Game.fast_regen_mult = 60`, 8 frames): `props on claimed land=0`.
- Whole island: `[props] built ...` unchanged in kind mix apart from the claim tiles; `on_claimed_count()`
  is 0 everywhere the test measures.
- The same test with the fix reverted fails 8 assertions (3 props left in the claimed cell, 5 on claimed
  land, dud node kept, 1 left after expansion, 6 after the expansion check, 2 after a rebuild, 2 after
  regrow), so the test can fail.

## Shots

None. The gate's conf runs `LAB=snap_build_lab` with `LAB_ASSERT=True`, and the owner's
`HEADLESS_ONLY` marker is present in the gate scratchpad, so the windowed lab is explicitly deferred for
this run: visual approval is **not** claimed. The rule is invisible in a screenshot anyway (absence of
props); the measured counts above are the evidence.

## Verification run

- `res://tests/t_claimprops.gd` — `[t_claimprops] PASS`, no SCRIPT ERROR.
- Related, all PASS: `t_claims2`, `t_props`, `t_props2d`; full gate (stage 3) runs `t_domain`,
  `t_domaind`, `t_claimfix`, `t_gather`, `t_build`, `t_save`, `t_perfgates`, smoke and the scope check.

## Assumptions

- `# ASSUMPTION`: an indestructible cliff/mesa **is** removed when its tile is claimed. The owner asked
  for no props on their land; attacks still cannot clear these (`clear_at_tile` unchanged), only a claim
  does.
- `# ASSUMPTION`: claim-driven clears are **not** written into the save's cleared-prop list, so a
  released claim can grow scenery again and the save format is untouched (the domain record alone
  decides what is clean).
- `# ASSUMPTION`: a harvest node counts as a prop when none of its `options()` item ids exist in
  `items.json` — i.e. it cannot be gathered at all, which is the owner's "especially if it can't be
  harvested".
- `# ASSUMPTION`: footprint overlap uses the same radius rule the prop body uses (`radius_m * scale`, or
  the painted card's art width), rounded to whole 1 m tiles.

## Integrator notes

- No save-schema change, no data file change, no balance numbers touched. Nothing outside the job scope.
- `IslandClaims.clean_claimed` is the single entry point if a later system (farming, taming pens) needs
  the same sweep on a new claim path.
- If claimed land should also drop resources later, the hook is `node_gatherable()` — invert it there,
  not in `island_scatter`.
