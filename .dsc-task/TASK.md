# Task: LANDMARKS M1 — landmark layer (data + generator)

Repo: WildLands MMO, Godot 4.7.1 typed GDScript. Read AGENTS.md first. Work only in this worktree. HEADLESS ONLY: never start a windowed Godot run (owner rule); skip any screenshot deliverable and say so.
Owner-approved design: `git show origin/claude/mmo-island-resources-doc:docs/design/island-resources.md` — read it all, then build ONLY milestone **M1 Landmark layer** from section 6:
- `game/data/world/landmarks.json` (landmark types, per-climate lists, budgets 4-10 per expedition island, spacing and camp-distance rules, as the doc specifies; numbers # ASSUMPTION where the doc says so).
- An `IslandLandmarks` generator pass run during island build (after ISLANDSHAPES topography; see game/data/world/island_families.json and docs/orchestration/reports/claude-islandshapes.md), with validation, deterministic by seed.
- Map-lab `landmark` markers with a `type` field imported by MapDoc (docs/current/map-format.md).
- Today's single crater becomes one landmark.
- Never place landmarks on claims, `claim_free` circles or the tutorial island's safe ring; the tutorial island keeps its hand-tuned layout.
- islandgen_lab (headless) prints `[landmarks] island=<id> placed=<n> skipped=<n> types=<list>`.
- New `game/tests/t_landmarks.gd` per the doc's M1 gate: 15 islands x 5 seeds, count in band, every landmark reachable from the harbour by TilePath, spacing and camp-distance hold, at least one within 140 m of the landing, none on claims/claim_free/safe ring, deterministic. Print `[t_landmarks] PASS`.
- Island build time +0.3 s at most (t_buildspeed is timing-flaky under load: rerun alone; if its digests change by design, re-record them and prove it by building the old digests on canon).
Don't build M2-M6. Update docs/current/world-biomes.md.
Run Godot exactly: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 600; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > $TMPDIR/<t>.log 2>&1`, then read the log; never pipe Godot output. Run --import after adding a class_name.
Done when `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_landmarks.sh` prints VERIFY PASS. Write docs/orchestration/reports/dsc-landmarks.md. Commit with a message ending `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. Do not push.
