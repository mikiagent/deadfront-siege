# dsc-unclaim — release claimed land (owner: "Also need a way to unclaim land too")

## What shipped

One plot of the Domain can be given up, from two places, always behind a confirm that states the
consequence.

**Model** — `game/scripts/world/island_claims.gd`
- `building_on(rt, cell)` — what stands on the plot (a kit's node in `BuildGrid._occupied`, a
  construction site, or a modular `StructurePiece` whose module covers the plot); `""` when clear.
- `release_reason(rt, cell)` — `not_owned` / `camp_land` / `last_cell` / `building` / `split`, `""`
  when the plot can go. `split` is an edge-connectivity flood fill over the remaining cells.
- `release_cell(rt, cell)` — the one write path, mirroring `claim_cells`: the record loses the cell,
  `rt.claims` loses its rect (the camp's own landing plot and every other cell stay), the outline
  redraws, the world's saved copy (`World.home_claims` / `unstable_claims`) follows, and
  `claims_changed` fires once with the released rect. `{"ok", "reason", "cell"}`; a refusal changes
  nothing.
- `reason_text` gained the four refusal sentences (they are what the panel quotes).
- `game/scripts/world/island_runtime.gd` — facade `release_reason(cell)` / `release_cell(cell)`.

**UI**
- `game/scripts/ui/claim_panel.gd` — the CLAIM confirm panel now has a **release mode**
  (`open_release`, `released(cell)` signal, static `describe_release`). A CLAIM press while standing
  on one of your own plots opens it (decided inside `open()` from the plot under the survivor, so
  `hunt_hud.gd` — outside this job's SCOPE — is untouched and no second HUD path exists). Body:
  how many plots you keep, the plot's size and cell, that it stops being yours (no building or
  managing there) and can be claimed again later, what happens to anything built there, that cleared
  grass/props do not regrow and no claim stake is refunded. Buttons **Keep** / **Release plot**,
  64 px. The chrome was factored into `_shell()` so both modes share it.
- `game/scripts/ui/domain_screen.gd` — the 7x7 plot grid now takes taps (`cell_at` / `tap_at` /
  `picked` signal; the picked plot draws a white frame); **Release plot** (renamed from "Release")
  asks first in the preview card with the same consequence text, Confirm **Release plot** / Cancel
  **Keep**; after a release the screen says so. The old `_on_release` wiped the WHOLE Domain with no
  confirm and no selection — that is gone. Release plot is disabled while a confirm/preview is up.

**Rules** (spec 29 names a Release button but gives no release rules — everything below is the
task's ASSUMPTION, marked `# ASSUMPTION` in the code):
- the last plot is refused (`last_cell`): a Domain always keeps at least one;
- the camp's own 16x16 landing plot is not a Domain plot and is refused (`camp_land`);
- a plot with a building on it is refused until the building is packed up (`building`) — the task's
  safer option, chosen over "becomes unowned": nothing is moved, destroyed or orphaned, and storage
  keeps its owner;
- a release that would cut the Domain into two pieces is refused (`split`);
- no T-stone or claim-stake refund, no cooldown (the spec gives neither);
- a released plot can be claimed again under the ordinary rules (adjacency, terrain, cap);
- grass/props the claim cleaned stay cleaned (the island rebuild rules decide, as before).

**Saves**: no format change. The cell is simply absent from `home.domain.cells`; a reload rebuilds
only what the record lists.

## Before / after

| | before | after |
|---|---|---|
| Release a plot | not possible except `IslandClaims.clear_domain`, which wiped EVERY plot with no confirm and no selection (Domain screen's Release button) | one plot at a time from the Domain grid or the CLAIM panel, always behind a consequence confirm |
| Refusals | — | last plot, camp land, building on it, split — each with a sentence the UI quotes |
| Save after release | — | cell absent from the record; reload keeps it released; re-claim works |
| Tests | — | `game/tests/t_unclaim.gd` (7 sections, ~40 assertions) |

Measured from the test run (`/tmp/unclaim_t.log`): a 3-plot chain releases to 2 plots, saves
2 cells, reloads 2 cells, re-claims 3; the last plot, camp plot, the chain's middle plot (split) and a
built-on plot are each refused with the expected reason; the confirm gate releases nothing until its
button is pressed.

## Shots

**None.** The gate directory carries the orchestrator's `HEADLESS_ONLY` marker ("owner requested
headless/background-only DeepSeek work… Do not run visible Godot labs until this marker is removed"),
so this job ran no windowed lab and produced no PNGs. The visual behaviour is asserted headlessly in
`t_unclaim` through the real panels (text, button labels, 64 px minimums, live/disabled states) and by
`t_uiworld`, which measures every visible Domain-screen button at 844x390 and 1600x900 (inside the
view, no overlap, >= 64 px) — it passes on this change as well. The integrator should take the two
Domain/claim screenshots when the marker is lifted.

## Verified

- `verify_job.sh unclaim 1` → `VERIFY STAGE 1 PASS` (t_unclaim PASS, no SCRIPT ERROR).
- `t_uiworld` PASS at both viewports, `t_claimfix` PASS (claim panel text/confirm unchanged).
- Mutation check: with the `split` guard removed, `t_unclaim` fails on exactly the split assertions
  (then restored) — the test can fail.
- Full gate: see below / the runner.

## What the integrator needs

- `hunt_hud.gd` and `player_actions.gd` were **not** touched (SCOPE): the claim-vs-release choice
  lives in `ClaimPanel.open()`. If the HUD later gets its own release entry point, call
  `ClaimPanel.open_release(...)` (or `IslandClaims.release_cell`) rather than adding a second path.
- The Domain screen's Release no longer wipes the Domain. If anything (docs, lab, bot) relied on that
  shortcut, it must call `IslandClaims.clear_domain()` explicitly (it still exists).
- The release confirm reuses the preview card's "Note" label; the card's Confirm/Cancel texts are
  swapped back when the release ends, so the claim previews read as before.
