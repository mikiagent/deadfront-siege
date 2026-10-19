# W1-WEB report: smaller, safer web build and culled vegetation

Branch `claude/mmo-w1-web`. Package commit 3babadd. After review: ca46889 reverts the WIP .uid churn,
and the review-fix commit that adds this report.

## What shipped

- **Export presets** (`game/export_presets.cfg`): client presets exclude `scripts/dev`, `scenes/dev`,
  `tests`, creature `ref/` and `work/`, and `sheet.png`. `WebSoak` keeps `scripts/dev` so `?soak=1`
  works. New Linux `Server` preset (dedicated server, visuals stripped).
- **Generated nature and resource GLBs** (`*.import` under `assets/nature/generated` and
  `assets/resources/generated`) embed their textures and run `game/tools/import/strip_emission.gd`.
  The script drops emission, caps textures at 512 px and re-encodes them as Basis UASTC with RDO 1.0.
- **VegBatch** (`game/scripts/world/veg_batch.gd`) splits each batch into 32 m cells, one MultiMesh
  per cell, each with a 120 m visibility range. The public API is unchanged. Shadows are now decided
  per cell from that cell's tallest instance: a cell whose instances are all under 2.5 m casts no shadow.
- **Web loader** (`tools/web_pack_for_vercel.py`): fetches 4 parts at a time and logs
  `time_to_main_ms` (load time, at `[boot] main scene ready`) and `time_to_world_ms` (includes the
  player's time on the menu and character creation). The `?soak=1` hook is only injected for `--soak` exports.
- **Payload gate** (`tools/check_export_payload.py`, called by `tools/export_web.sh`): parses the pack,
  fails on dev, test or ref files, and fails when the pack is over the ceiling (default 220 MB, decimal:
  1 MB = 1,000,000 bytes). It also fails a release `index.html` that carries the `?soak=1` hook.
- **Shell manifests** (`game/shell/shell_loader.gd`, `boot.gd`): `manifest_error` requires a non-empty
  `packs` list, names matching `[a-z0-9_-]{1,32}`, unique names, a lowercase sha256, an http(s) url and a
  size of 0 or more. `boot.gd` refuses anything else.
- **Builds host** (`hosting/builds/`): only `public/` is served, so `manifest.json` can only be fetched
  through `/api/manifest`.

## Review fixes (this round)

| Finding | Fix | Check that would have caught it |
|---|---|---|
| blocker: no report | this file | n/a |
| blocker: 15 foreign `.uid` files in 930375d | `git revert 930375d` (ca46889). Against base ea2d167, the branch now adds only `t_web.gd.uid` and `strip_emission.gd.uid` | `git diff --stat ea2d167 HEAD -- '*.uid'` lists those 2 files only |
| soak hook in release html | hook only with `web_pack_for_vercel.py --soak`; `export_web.sh` passes it through | payload gate: `release index.html carries the ?soak=1 hook` -> `[payload] FAIL` |
| time_to_world counts dwell | added `time_to_main_ms`; world line says `(includes menu and creation time)` | code check (patched html contains `time_to_main_ms`) |
| shadows from batch-wide max | per-cell max height | t_web `a 1 m rock added after a tall one stays shadowless`: FAILS on the old veg_batch.gd, PASSES now |
| MiB vs MB | `MB = 1_000_000` in the gate; split line labelled MiB | 221,000,000-byte pack -> `pack is 221.0 MB, over the 220 MB ceiling` |
| empty packs passes | `packs is empty` refusal | t_web `manifest with no packs is refused`, and boot.gd refuses `[]` |
| keep_all_compressed_buffers leaks | saved and restored around `_walk` | none headless (editor-only import path; see "left") |
| rock check skipped silently, HTTPRequest leak | `_check(r != null, ...)`, `http.free()` | t_web `rock batch builds` |

## Acceptance checklist

Lines seen in runs from this worktree. The lines marked "(first round)" come from logs of the package
run on 2026-10-18 (scratchpad `w1/web/`). Only VegBatch shadows and the loader text changed since then,
and both were re-checked below.

- [x] Pack <= 200 MB (was 317,479,824 bytes) (first round, `export_after.log`):
  `[payload] pack .../export/web bytes=189008844 (180.3 MB) files=1747`. 189.0 MB in decimal units.
- [x] Over 220 MB fails (this round, synthetic 221,000,000-byte pack):
  `pack is 221.0 MB, over the 220 MB ceiling` / `[payload] FAIL`.
- [x] 0 forbidden files (first round): `[payload] shipping presets exclude authoring and dev files and the pack is clean` / `[payload] PASS`.
  Preset check this round: `[payload] PASS`.
- [x] 0 emissive generated materials (this round): `[t_web] generated glbs=60 materials=62 emissive=0 texture_slots=210 over_512px=0`.
- [x] Camp primitives (this round, windowed, 1600x900, temperate_25):
  - `[camp] renderer=forward_plus max over 30 frames: prims visible=50296 shadow=2588204 | draws visible=73 shadow=88 | objects visible=73 | vegbatches=45 cells=300`
  - `[camp] renderer=gl_compatibility max over 30 frames: prims visible=50296 shadow=2588204 | draws visible=161 shadow=0 | objects visible=161 | vegbatches=45 cells=300`
  - Visible is under 900k and shadow is under 3.0M in both renderers.
- [x] `--lab=resource_visibility_lab` (this round): `[resource_visibility] PASS nearby cells render, the far cell is culled, interaction lifetime matches`.
- [x] island_lab counts unchanged (this round): `[world] island temperate_25 nodes=378 creatures=24 spawn_rejected=0`.
- [x] Loader fetches 4 parts at a time: `const PARALLEL = 4;` plus the worker pool in `tools/web_pack_for_vercel.py`.
- [~] Local export reaches the world in desktop Chrome with the time logged: the reviewer's run logged
  pack load in 382 ms and time_to_world 22984 ms (mostly time on the creation screen). This round adds
  `time_to_main_ms` but no new Chrome run was made, so there is no measured `time_to_main_ms` yet.
- [x] boot.gd refuses a missing sha256, a bad name and an empty packs list (this round): `[t_web] PASS`.
- [x] `tools/smoke.sh --no-import` (this round, through gslot): `SMOKE PASS`.
- [x] `run_all.gd` (this round): `[tests] PASS`.
- [x] `t_web.gd` (this round): `[t_web] PASS`.

## Screenshots inspected

- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/web/camp_forward_plus_v2.png`
  and `camp_gl_compatibility_v2.png` (this round). Camp renders the same in both: the survivor, bonfire, tent,
  workbench, ground and HUD, with no glowing props and nothing missing.
- First round: `camp_*.png`, `forest_*.png`, `crater_*.png` in the same folder.

## Assumptions

- `# ASSUMPTION:` `VegBatch.CELL_RANGE_END_M = 120.0`. A cell is drawn up to 120 m from the camera. The
  farthest visible ground point is about 70 m at max zoom, plus half a cell diagonal. This should hold up to 32:9.
- `# ASSUMPTION:` `VegBatch.SMALL_PROP_M = 2.5`. Props shorter than 2.5 m (bushes, rocks, plants) cast no
  shadow. At iso zoom their shadow was a few pixels but cost about 1.3M shadow triangles at camp.

## Integrator hooks

None needed.

## Labs to register

None new. `resource_visibility_lab` already exists; this package only changed it.

## What failed or is left

- **perf_budget_lab thresholds:** to be recorded after W1-AI and W1-WEB merge (plan-register line 374). The
  camp budget to use is visible <= 900k and shadow <= 3.0M.
- **WebSoak export not yet run:** `tools/export_web.sh --soak` has not been exercised end to end. Its hook
  and gate logic were only tested on a synthetic export dir.
- **No fresh full web export this round.** The tools/ changes were tested on a synthetic 221 MB pack, and a
  real `tools/export_web.sh` run should confirm them. No deploy was run.
- `strip_emission.gd` restoring `keep_all_compressed_buffers` has no automated test, because it only runs
  inside an editor import. No reimport was run this round.
- `time_to_main_ms` still needs a Chrome run to get a number.
