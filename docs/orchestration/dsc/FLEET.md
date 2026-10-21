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
| bags | DeepSeek | spec 31: bag types with level curves, material-inherited storage, Pocket +6/level, inspect/compare, craft preview | branched from claude/mmo-invslots; invslots keeps grid/layout only; migrates woven_bag saves |
| stationart | MiniMax | 15 Blender models: workbench tiers, kiln, loom, oven, sites | finished; being judged |
| housekit | MiniMax | modular house parts in 3 tiers | |
| farmkit | MiniMax | field plots + crop stages, paths, fences, farm props | |
| review w2gather / w2buildsys | MiniMax | first-pass reviews (scratch trees `SP/trees/rev-*`) | output `docs/orchestration/reports/dsc-review-*.json` |

## Fix rounds (merge review 2026-10-21 18:30: none of the ten was mergeable; each resumed on its session with the judge's
fix message in SP/dsc/fix_<key>.txt; worker output committed on each branch first)
invslots (desktop actions/tip off-panel, storage box unreachable on desktop, phone action row clipped, drag-takes-item,
raw id), needs (eat check vs 16/s regen; bag buttons belong to invslots), colors (t_colors respawn check, patterns too faint,
morph names), sprites2d (despill flattens foliage, jungle-trees glued, labels slipped, hanging vines block), stationart
(floating scaffold planks, lintel without a door gap, stage-0 too thin to read), props (stale shots, spawn inside a bush,
top-up heavy bushes, pet->prop attack bug), eyeglow (lab clock not frozen, eye dots too big on deinonychus/compsognathus),
biomezones (camp flattening out of scope, pack size), islandgen (land cut at the grid edge, canal rivers, shore rock
sawtooth, circular mesas), biomeassets (step-pyramid cliff and hollow basalt never rebuilt). The judges' full verdicts:
SP/merge-review.json. webpack2 still waits on the owner (512 px cap also hits desktop/iOS).

## Next after these
- **Unblocked by BUILDFLOW:**
  - CRAFTFEEL: craft success rate, failure loses materials, flawless (spec 04, 25 §8).
  - Domain phase D: Communications Center raising the plot cap (spec 29 §4), after CLAIMS2.
- **Unblocked by SWITCH2D/GROUND2D:**
  - Props as painted cards.
  - Biome dressing per zone with the painted sheets.
- **After islandgen:** Tamed Island shape choice (five templates; docs/reference/durango-domain-tamed-island-select.webp).
- **Balance (HP, damage, pacing, LOOP1 bot thresholds):** only after crafting, building and skills are done (owner).
