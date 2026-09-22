# instinct — layout-mode drag lag (build_placer overlay)

## Shipped
- `game/scripts/world/build_placer.gd`: ghost overlay rebuild is ~3x cheaper and no longer
  churns nodes. Grid lines and cell quads are now ArrayMeshes built from packed arrays (one
  server call each) instead of ImmediateMesh per-vertex calls plus a MeshInstance3D +
  PlaneMesh allocation per highlighted tile per rebuild. Terrain heights are sampled once
  per unique grid point (121) instead of once per vertex (360). Water/nature-blocked tile
  checks are cached per tile for the loaded island. Ghost re-tint only on validity change;
  Label3D text only rewritten on change.
- `game/scripts/dev/layout_perf_lab.gd` + `scenes/dev/layout_perf_lab.tscn`: headless perf
  + functional lab (`-- --lab=layout_perf_lab`). Simulates a cross-island layout drag with
  frame-time capture, micro-benchmarks the rebuild path, and asserts overlay mesh contents
  plus an end-to-end pick-up -> drag -> drop -> re-pick -> put-back cycle.

## Why
Milan: moving buildings in build mode lagged (iPhone web). During a drag the ghost crosses
a cell border most frames, so the overlay rebuilt ~every frame: ~1.0-1.2 ms headless per
rebuild (dominated by per-tile node churn at ~0.75 ms per 40 quads), plus queue_free spikes.
On WASM that is several times worse and hit GC every rebuild.

## Measured (headless, layout_perf_lab, per overlay rebuild)
- before: draw_overlay 1029-1211 us, sync_rebuild 694-843 us
- after:  draw_overlay 239-320 us,  sync_rebuild 267-360 us
- node churn per rebuild: eliminated (was ~750-880 us per 40 quads)

## Validation
- tools/smoke.sh SMOKE PASS; tools/test.sh [tests] PASS; build_lab acceptance demo passes
  (place/reject overlap/unclaimed/save+restore).
- layout_perf_lab: [perf] functional PASS (mesh contents, red/blue quads, move, put-back).
- Rendered 844x390 phone-viewport shots (xvfb + opengl3, build_lab staged ghost): overlay
  pixel parity before/after (blue footprint quads, red blocked quads, grid lines intact).

## Notes for next agent
- No leased files touched: only build_placer.gd + new dev lab files.
- The remaining per-rebuild cost is mostly the 9x9 spawn_ok scan and height sampling; if
  more is needed, the next lever is caching the blocked-tile window per island.
