# DeepSeek/MiniMax fleet (2026-10-21 evening)

Each job: worktree `~/Documents/deadfront-siege/.claude/worktrees/mmo-<key>` on branch `claude/mmo-<key>`, task
`docs/orchestration/dsc/<key>-TASK.md` in that tree. SP = `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad`.
- **Check:** `dsc cook status` in a tree.
- **Talk to it:** `dsc cook say "..."`.
- **Resume:** `dsc cook resume` after a pause, or `dsc cook start <task> --once --resume <session id> --verify ...` after it finished.
- **Gates:** `SP/dsc/verify_job.sh <key> [1|2]` for code jobs (settings in `SP/dsc/job_<key>.conf`), `SP/dsc/verify_blender.sh <key>`
  for Blender jobs (`blender_<key>.conf`), plus the job-specific `verify_<key>.sh` for older jobs.
- **Settings (DeepseekCLI 047993a and later):** watchdogIdleSec 0, maxTurns 300.
- **Checkpoints:** they do not commit in this repo (`.dsc` is gitignored). The worker's output stays staged or uncommitted, so
  commit it yourself before merging.

## Running
| key | model | what | merge notes |
|---|---|---|---|
| buildflow | DeepSeek | spec 30: components, construction site, Basic Workbench, station job | tree = overhaul + W2-PROCESS + W2-BUILDSYS (hooks applied); M0 fixed t_process |
| claims2 | DeepSeek | spec 29: 4x4 cells, 13-cell cap, Domain menu, preview, no grass | save format change (owner OK in spec) |
| switch2d | DeepSeek | resources as painted 2D cards; buildings 3D | tree = overhaul + CARD2D + SPRITES2D |
| ground2d | DeepSeek | painted ground cover; none on claimed land | branched from switch2d |
| gatherglide | DeepSeek | gather radial glides, no jumps | |
| occlude2 | DeepSeek | roofs/bushes fade so the survivor stays visible | |
| skillfeel | DeepSeek | skill XP toasts, FULL at cap, Skills hex pulse, first-hour node table | |
| mapui | DeepSeek | map fog revealed by walking, trail dots, icons | save field added (owner decision) |
| stationart | MiniMax | 15 Blender models: workbench tiers, kiln, loom, oven, sites | finished; being judged |
| housekit | MiniMax | modular house parts in 3 tiers | |
| farmkit | MiniMax | field plots + crop stages, paths, fences, farm props | |
| review w2gather / w2buildsys | MiniMax | first-pass reviews (scratch trees `SP/trees/rev-*`) | output `docs/orchestration/reports/dsc-review-*.json` |

## Finished, waiting for merge review (a Claude judging workflow ran on them)
invslots, needs, stationart, sprites2d (7 sheets), eyeglow, islandgen, props, biomeassets, biomezones, colors (gave up after 11
verify failures), card2d (inside switch2d), webpack2 (owner decision: the 512 px cap also hits desktop/iOS).

## Next after these
- **Unblocked by BUILDFLOW:**
  - CRAFTFEEL: craft success rate, failure loses materials, flawless (spec 04, 25 §8).
  - Domain phase D: Communications Center raising the plot cap (spec 29 §4), after CLAIMS2.
- **Unblocked by SWITCH2D/GROUND2D:**
  - Props as painted cards.
  - Biome dressing per zone with the painted sheets.
- **After islandgen:** Tamed Island shape choice (five templates; docs/reference/durango-domain-tamed-island-select.webp).
- **Balance (HP, damage, pacing, LOOP1 bot thresholds):** only after crafting, building and skills are done (owner).
