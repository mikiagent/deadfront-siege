# dsc: CLAIMS2 - Tamed Island Domain (spec 29 Phase A+B, footprint rule, no grass)

**Task:** CLAIMS2 (dsc, 2026-10-21/22), spec `docs/design/durango-prompts/29_domain_land_claiming_and_territories.md`
sections 2-4, 9, 12-14 plus the owner's grass rule. Branch `claude/mmo-claims2`, worktree `mmo-claims2`.
Nothing pushed or merged. Credits spent: none (no Meshy calls).

## Outcome

A Tamed Island now has a **Domain**: a set of 4x4-tile cells on the island-origin grid, declared and expanded
from a new Domain screen with a ground-grid preview, capped at 13 cells at Pioneer rank 1, edge-adjacent growth
only, saved with the island, migrated from old 14x14 saves, with no grass on claimed land.

Verified: `[t_claims2] PASS`, `t_claimfix` / `t_domain` / `t_save` PASS, `claims2_lab` PASS at 1600x900 and
844x390 (`[claims2] RESULT cell_tiles=4 cap=13 claimed=13 refused_at_cap=1 non_contiguous_refused=1
eligible_shown=16 invalid_shown=49 tabs=4 grass_in_claim=0 other_nodes_kept=1 footprint_cross_refused=1
legacy_buildings_inside=1 save_roundtrip=1 ui_min_px=48|64`), `tools/smoke.sh` prints `SMOKE PASS`.

## What shipped

### Model (game/scripts/world/island_claims.gd, rewritten around cells)
- `cell_tiles()` / `cell_rect()` / `cell_of()` / `cells_covering()`: one cell = `cell_tiles` x `cell_tiles` tiles
  (4 by default) on a grid anchored at the island origin.
- Domain record per spec 29 §3: `domain_id, kind, island_id, owner, owner_clan_id, cells, max_cells, status,
  renewal_deadline, permissions_profile_id`. `to_save`/`from_save` write cells as `[[x, z], ...]`.
- `claim_cells(cells)` claims one batch atomically: checks `batch_reason` for the whole set first
  (`no_cells`, `already_owned`, `cap`, `outside_the_island`, `terrain`, `ownership`, `not_adjacent`, in that
  order), then appends, clears grass, rebuilds `rt.claims` and the outline, and emits
  `IslandRuntime.claims_changed(rect)` **once** per batch.
- `eligible_cells()` / `classify()` / `preview()` feed the ground grid: claimed / eligible (edge-adjacent to
  held land, island land only) / invalid (water or off-island, or another owner).
- `claim_at(tile)` is the CLAIM press: claims the **cell the survivor stands in**. `block_reason` /
  `expand_reason` keep their old signatures so `claim_panel`, `player_actions` and the bot work unchanged.
- `used()` / `cap()` / `at_cap()`; `sync_cap()` refreshes `max_cells` after a rank change.
- `is_grass()`, `clear_grass()`, `grass_in()`, `other_nodes_in()` as below.

### Config (game/data/world/domains.json + game/scripts/world/domain_rules.gd)
`{"cell_tiles": 4, "tamed_island": {"start_cap": 13, "rank_caps": {"1": 13, "2": 17, "6": 23, "7": 30}}}`.
`DomainRules.cap_for_rank(rank)` returns the cap of the highest documented rank at or below `rank` (a rank
between documented ones keeps the previous cap). The four numbers are the spec's `historical, provisional`
values; Pioneer rank is `World.pioneer_level` for now (the rank upgrade track is a later job).

### The camp's landing claim
`rt.camp_claim` is the camp's buildable landing block (4x4 cells / 16x16 tiles, snapped to the cell grid so the
old 14x14 plot and its buildings stay claimed). It is claimed and buildable, appears first in `rt.claims`, but is
**not** a domain cell and does **not** count against the 13. Without that, the camp alone would eat the cap.

### Persistence and old saves (owner decision: the save format changes)
- `save_game.gd` writes `home.domain` / `away.domain` **only when a domain exists**, so old saves and the frozen
  `t_save` fixtures re-save byte-identical; `World.home_domain` / `away_domain` hold the records,
  `World.domain_for_current()` reads the right one.
- `save_sanitizer.gd` `_domain()` is the trust boundary for a forged record: kind whitelisted, cell coordinates
  coerced to ints in range, repeats dropped, `max_cells` clamped, unknown keys dropped.
- Migration: a saved domain record loads directly. An OLD save's 14x14 `home_claims` rows become cells: the
  first row is the camp land, every other row becomes the cells that cover it, plus the cells covering every
  placed building's footprint. Legacy rows are left untouched in the save. A migrated save may exceed the cap;
  then it keeps its cells and simply allows no new ones (never drops cells).
- `t_save` passes on all 7 fixtures, including the hostile/forged payloads.

### Footprint rule (spec 29 §9)
`BuildGrid.can_place` already demanded that **every** footprint cell be claimed, so an anchor inside the domain
with the rotated footprint crossing the border is refused with `unclaimed`. Confirmed by
`t_claims2._test_footprint_rule` (28 straddling anchors refused, 3 wholly-inside allowed); no production change
was needed beyond keeping `rt.claims` derived from the cells.

### No grass on claimed land (owner)
`island_scatter.gd` skips the grass families (`Grass, Grass_Short, WildGrass, DryGrassTuft`) on claimed tiles,
both harvest nodes and the grass decor multimeshes (tracked in `rt.grass_mm`). Claiming a cell calls
`clear_grass`, which frees those nodes and rebuilds each decor multimesh without the instances inside the new
cells. Trees, bushes, rocks, flowers and reeds stay (ASSUMPTION, listed below).

### UI
- **Domain screen** (`game/scripts/ui/domain_screen.gd`, reached from Main Menu -> Domain): four tabs
  (Tamed Island / Civilized Island / Clan / Outpost), Plots used/cap, owner, grid, upkeep, land state, and
  Declare (no domain) or Expand / Release (domain held), plus Close.
- **Preview** (`game/scripts/world/domain_preview.gd`): a ground-grid mesh over the island - claimed cells gold
  with dashed borders, eligible cells teal, invalid cells red, not-yet-adjacent cells neutral, picked cells
  with a white frame. Tap toggles a cell (drag does not), the footer shows `Selected n - holds n / cap` with
  Confirm / Cancel / Close, the camera still moves, a refused tap prints the reason in the footer, and Confirm
  commits the whole selection as one `claim_cells` batch.
- Layout: a container stack (tab rail + content) on desktop; on a compact landscape-phone canvas the rail
  becomes a row, the card goes full width up to 600 px, decorative lines drop and every action is 64 px
  (`min_target_px()` = 48 at 1600x900 - the tab rail, not an action - and 64 at 844x390).
- HUD: Main Menu gained a **Domain** row (`hunt_hud.gd` `_open_domain` / `domain_screen()`).
- Civilized Island / Clan / Outpost tabs show a "not in the game yet" notice; nothing fake is wired.
- The CLAIM press now routes to the same confirm panel and claims the cell under the survivor rather than a
  centred 14x14 plot.

### Lab and test
- `game/scripts/dev/claims2_lab.gd` + `game/scenes/dev/claims2_lab.tscn`: boots the HUD, declares through the
  Domain screen, expands to the cap, checks the cap and non-adjacent refusals, the footprint straddle, grass
  clearing vs other props, legacy migration and a save round trip, prints the `[claims2] RESULT k=v` line and
  saves 5 screenshots per resolution.
- `game/tests/t_claims2.gd` covers the same model surface headless.

## What failed / traps found

- **`class_name` after adding a file:** a new script is not resolvable until `--headless --import` runs; the
  symptom is a wave of false "Identifier not declared" parse errors.
- **Test environment:** autoloads do not exist under `--script`, so tests that name `Data` / `World` / `Game` or
  their dependants as types fail to compile; the tests use `load()`ed script vars instead.
- **Headless multimesh:** the dummy renderer reports every instance at the origin, so grass decor can only be
  measured in a windowed lab (`grass_in_claim=0` comes from the lab, not the unit test).
- **UI:** the first card hand-positioned every label and clipped its tabs behind the body - rebuilt as a
  container stack. The first preview fills were one flat wash - alpha raised, per-cell borders added, picked
  cells got a white frame, and non-adjacent cells made neutral so red means a real refusal.
- **Not done:** the rank upgrade track (rank is the player level for now), and Phases D-G (Communications
  Center upgrades, Civilized Islands, clans, outposts) - their tabs are locked placeholders by design.

## Owner decisions / assumptions to note
- **Save format change is an owner decision** (the owner asked for spec 29): `home.domain` / `away.domain`
  records, written only when a domain exists so old saves stay loadable and re-save identically.
- The camp's landing claim is buildable land but not a domain cell and is not counted against the cap.
- A fresh Tamed Island starts with **no** domain cells; the screen offers Declare.
- Rank caps 13/17/23/30 are the spec's `historical, provisional` numbers; a rank between them keeps the
  previous cap; a migrated over-cap domain never loses cells, it just cannot grow.
- ASSUMPTION: grass families are `Grass, Grass_Short, WildGrass, DryGrassTuft`. Flowers, reeds, trees, rocks and
  bushes stay on claimed land.
