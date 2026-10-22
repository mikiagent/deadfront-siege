# Vercel deployment and bug audit, 2026-10-22

Agent: Codex

## What shipped

- Deployed integration commit `b1f07de37bcb49928e6778d632d2264f5f4b5a3a` from `claude/mmo-overhaul` to Vercel production.
- Production alias: <https://durango-like.vercel.app>
- Immutable deployment: <https://durango-like-glnj0btwk-mikiagents-projects.vercel.app>
- Vercel inspection: <https://vercel.com/mikiagents-projects/durango-like/DS3VUqDnSq77a6bLkdYvDPAmQ71K>
- Verified the protected production response with `vercel curl`. The page contains build stamp `--build=b1f07de37/d0a79d2906`.
- Ran the release in headless Chromium against the production URL. Godot 4.7.1 reached `[boot] main scene ready` with no browser crash, page error, parse error, or WebGL loss.
- Ran `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Ran a direct headless boot with `--smoke --touch`: the touch layer selected tap-only mode and the smoke scene completed.

## Confirmed defects

### P1: layout placement emits a typed-array error every frame

Reproduction on the current desktop build:

1. Enter layout mode.
2. Pick up a placed workbench so the placer ghost is active.
3. Leave the ghost active for several frames.

Godot repeatedly reports:

```text
ERROR: Attempted to use 'has' an object into a TypedArray, that does not inherit from 'GDScript'.
  [0] _placer_taken (res://scripts/ui/hunt_hud.gd:781)
  [1] _refresh_place_hexes (res://scripts/ui/hunt_hud.gd:749)
  [2] _process (res://scripts/ui/hunt_hud.gd:1141)
```

Cause: `_place_hexes` is a typed `Array[HexButton]`, but `_placer_taken()` calls `_place_hexes.has(ctl)` where `ctl` is statically a `Control`. Godot validates the lookup argument against the typed array before checking membership. Because `_refresh_place_hexes()` runs from `_process()`, the error repeats every frame while a ghost is active. This can flood logs and consume frame time even though a later placement may still succeed.

Fix direction: avoid passing a `Control` into `Array[HexButton].has()`. Compare untyped node identity, cast only after confirming `ctl is HexButton`, or keep a separate untyped exclusion set. Add an integration check that opens layout mode, lifts a station, advances several frames, and fails on any engine error.

### P2: a rigid branch pile sways like a plant

Cause: `game/data/card2d.json` classifies `branch-pile` as `kind: plant`. The plant sway configuration has amplitude `0.06`; `CardProp.setup()` copies it into the material, and `game/shaders/card_sway.gdshader` animates it from `TIME` every frame.

A temporary Godot regression probe produced the exact failing signal:

```text
[bug-probe] FAIL branch-pile is rigid but sway amplitude is 0.060 (kind=plant)
```

Fix direction: give rigid cards a named zero-amplitude/static sway category, or otherwise map `branch-pile` to zero amplitude. Add a `t_card2d.gd` assertion that its material amplitude is exactly zero. Using the existing `rock` category would stop motion but would blur the data model.

### P2: minimap footsteps never expire

Cause: `MapFog.trail` is an `Array[Vector2]`. A dot contains only position, and `walk()` removes entries only when the list exceeds `TRAIL_MAX = 200`. `to_dict()` persists each entry as `[x, z]`; `from_dict()` restores it forever. Both `map_screen.gd` and the HUD minimap draw every stored point. There is no timestamp, age, TTL, or time-based prune path.

The exact regression probe reported:

```text
[bug-probe] FAIL trail dot has no timestamp/age, so it cannot expire: [[0.0, 0.0]]
```

The existing `t_mapui.gd` currently locks in the wrong behavior: it tests only the 200-dot cap and requires every trail point to survive save/load. It passed during this audit while the expiry probe failed.

Fix direction: store a creation time or remaining lifetime per dot, prune from the simulation clock, increment `version` when dots expire, update both minimap render paths, keep old `[x, z]` saves backward-compatible, update `World.load_map_map()` sanitization, and replace the permanent round-trip assertion with deterministic TTL coverage.

### P1 release risk: the initial web payload is too large for the mobile-first target

The production loader downloaded a `322,530,836` byte PCK plus a `39,513,091` byte WASM. On local desktop Chromium the pack alone took `18,873 ms`; main-scene readiness was `20,122 ms`. This is before normal mobile network and device constraints. The build does boot, but this payload and startup time put mobile playability at high risk.

Fix direction: inspect the exported PCK by largest resource, exclude source/unreferenced development assets, split optional content, and establish a mobile payload and time-to-main budget in CI.

## QA defects and gaps

- `node tools/production_soak.mjs https://durango-like.vercel.app/` timed out after six minutes waiting for `[soak] PASS`. It reached the main scene, but emitted zero soak checkpoints. The script adds `?soak=1`; the release `index.html` does not translate that query into `--web-soak`, while `main.gd` only starts the route for the command-line argument. The release export also intentionally excludes the development soak script. This means the named production soak currently verifies boot only and then hangs. Artifacts are in the ignored local directory `artifacts/web-soak/`.
- `t_card2d.gd` emits `ERROR: String formatting error: unsupported format character` at line 235 because a percent sign in a formatted assertion is not escaped. The test still prints `PASS` and exits zero, so an engine error can hide inside a green test.
- `t_mapui.gd` needs a requirement update for time-expiring footsteps. Its current persistence assertions contradict the owner's stated behavior.

## Verification results

- Production build stamp: PASS, `b1f07de37/d0a79d2906`.
- Production browser boot: PASS, main scene ready.
- `tools/smoke.sh --no-import`: PASS.
- Headless `--smoke --touch`: PASS.
- `t_mapui.gd`: PASS, but covers the stale permanent-trail contract.
- `t_card2d.gd`: PASS exit code, with the formatting error described above.
- Targeted branch and trail regression probe: FAIL on both confirmed symptoms, as expected for the current build. The temporary probe was removed after the run.
- Production deterministic soak: FAIL, harness timed out before any checkpoint.

## What failed

- The deployed release could not complete the deterministic gameplay soak because the release and soak entry points do not connect.
- This task was diagnostic. No gameplay fixes were made, so all confirmed defects remain in production.

## Credits spent

- Meshy: 0.
- Tripo: 0.

## What the next agent needs

- Treat this report as superseding the earlier statement that no runtime errors appeared. The layout error surfaced only after interacting with the build.
- Fix in this order: layout-mode per-frame error, branch-pile static classification, footstep TTL and save migration, then web payload and soak wiring.
- Preserve backward compatibility for existing map saves. Old trail rows have only two coordinates.
- After fixes, rerun the two targeted regression checks, `t_mapui.gd`, `t_card2d.gd`, `tools/smoke.sh`, the `--touch` smoke, and a corrected production soak.
