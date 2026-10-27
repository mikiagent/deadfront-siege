# Repository bloat review and cleanup

Date: 2026-10-27. Live changes are in the `claude/mmo-overhaul` checkout.

## What shipped

- Commit `c99fe857` removes the tracked `game/scripts/camera/iso_new.tmp`, an unreferenced camera scratch draft. The active scene names `game/scripts/camera/iso_camera.gd`; the removed draft remains recoverable from the parent commit.
- Removed unused `hdr`, `OUT_TEXT`, and `W` placeholders from the wiki data generator and the unused `dismissAuto` function from the wiki frontend. A temporary-copy comparison with the real data produced 13 byte-identical documents and sheets. The live sheets were not regenerated.
- Added a measured, evidence-led bloat-removal process to `docs/wiki-maintenance.md` and corrected stale Open Questions links in the canon docs and agent entry point.

## Verification and limitations

- The 49 wiki tests, archive-navigation browser fixture, JavaScript syntax and whitespace checks passed. `tools/smoke.sh` printed `SMOKE PASS`.
- `tools/test.sh` exited 0 and printed `[tests] PASS`, but emitted three compile errors involving `TouchControls` and dependent scripts. A second run with the camera scratch file temporarily restored emitted the same three compile errors and also printed PASS. The harness needs separate investigation; the pass marker is not a clean error-free test result.
- Repository searches found no reference to `iso_new.tmp`, and an isolated Godot check found that it is not a loadable resource. This does not prove that an external tool never reads the file.
- Ten identical survivor texture PNGs account for about 49.8 MiB of duplicate bytes. Godot recreated one matching PNG from a GLB in an isolated import but assigned different compression and size-limit settings. Preserve these assets until the art owner verifies import settings, web export and visual results. No unique art, archive records, or unrelated untracked files were deleted.
- The DeepSeek read-only trail review flagged ambiguous path evidence and unproven external consumers; the log was supplemented with the exact deleted and active paths. The review reached its output limit. The active-task transcript was unavailable to that review.

The docs and wiki changes remain uncommitted alongside existing OpenCode changes; the existing staged coelophysis deletions were preserved. Meshy credits spent: 0. DeepSeek review spend reported: $0.0035 total across two small capped attempts. No gameplay mechanics or assumptions were added. The next agent should investigate the test harness errors and coordinate any asset deduplication with the art-pipeline owner.
