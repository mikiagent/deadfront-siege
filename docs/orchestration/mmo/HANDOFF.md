# DEADFRONT MMO program: handoff (2026-10-20, evening clean stop)

Read this first when you pick the work up in `~/Documents/deadfront`. It says where everything is, what is
merged, what is half done and on which branch, what has not started, and the rules that bit us.
The program's running memory is `docs/orchestration/mmo/STATUS.md` (owner decisions, waves, merge log);
the package specs are in `docs/orchestration/mmo/plan-register.md`; the owner's design input is
`docs/design/durango-prompts/01`-`12`; the owner's program prompt is `docs/orchestration/prompts/mmo-program-prompt.md`.

## Graceful stop, 2026-10-20 ~19:05 (owner: "graceful stop to resume later") - read this first

Nothing is running: three workflows were stopped, no Godot or dsc process is left, and the wakeup loop is off. Every package
branch tip is pushed to GitHub (w2-data 178e320c, w2-skills 42e9ce6d, w2-inv 5ff239a6, w2-process 061cc651, w2-gather
e4d20cb8, w2-buildsys 4b8c6d23, econ 0853cc6f, w2-ragdoll 052c5646 (WIP commit at the stop), icons2 95be9029, invui 3ecb02ca).
Nothing new is merged into claude/mmo-overhaul since section 2; production is unchanged (31c064a08/2284b9bf56).

| Run | Script (repo copy) | State at the stop | Resume |
|---|---|---|---|
| finish-6, wf_c321f8a4-028 | `handoff/workflows/finish-6.js` | Priority 1: the 7 merges in the handoff order plus W2-RAGDOLL, ICONS2, FORGEART. Restarted twice (see below), so every package restarts from its branch tip. Results of the derailed resume are not trusted and are not replayed: W2-PROCESS r2 pass + A/B 2/1 and ECON r5 pass need a fresh review; W2-SKILLS r2 found a real blocker (fixed in fix r2) | Same session: `Workflow({scriptPath: ".claude/worktrees/deadfront-finish-6.js", resumeFromRunId: "wf_c321f8a4-028"})`. New session: launch the script file fresh (same effect) |
| INVUI, wf_cdb79ed1-deb | `handoff/workflows/invui.js` | Spec 13 (Durango Bag, Character -> Gear, Equipment). Scouts done; the design step was cut. Worktree `mmo-invui` exists with "Apply W2-INV hooks (INVUI base)" | Same session: `Workflow({scriptPath: ".claude/worktrees/deadfront-invui.js", resumeFromRunId: "wf_cdb79ed1-deb"})`; new session: launch fresh |
| W3-EXCHANGE, wf_4cbd48e0-5b9 | `handoff/workflows/exchange.js` | Spec 14 (Island Market). Two of three scouts done; no worktree yet | Same session: `Workflow({scriptPath: ".claude/worktrees/deadfront-exchange.js", resumeFromRunId: "wf_4cbd48e0-5b9"})`; new session: launch fresh |

Before resuming:
- **Launch or resume a workflow ONLY in a turn whose user message is about that work** (e.g. the owner saying "resume").
  The Workflow tool hands that turn's message to every agent as overriding their task. Resuming finish-6 in the turn of the
  owner's question "is the vision check necessary?" made its agents answer the question, skip gates, or stop with a false
  owner gate.
- **Helpers.** The scripts call gslot.sh, mkwt.sh and the slot locks in the 2026-10-19 session scratchpad
  (`/private/tmp/claude-501/.../1899b1df-.../scratchpad`), and mkscratch.sh (detached review trees) in the 2026-10-20 one
  (`.../72cebc8b-.../scratchpad`). /private/tmp does not survive a reboot. If they are gone, copy
  `handoff/scripts/{gslot,mkwt,mkscratch}.sh` back to those paths (and `mkdir locks`), or change the constants at the top
  of each script.
- **Dirty worktrees.**
  - `mmo-econ` has the ECON hooks applied for local testing (`intent_handlers.gd`, `run_all.gd` modified). Do not commit them; they ship in the hooks patch.
  - `mmo-icons2` has a report edit and a preview sheet.
  - The untracked `game/assets/{nature,resources}/generated` files are import noise.
- **Owner input since section 3.**
  - Specs 13 (inventory/equipment UI) and 14 (Island Market UI) with references in docs/reference.
  - "This will be an online multiplayer game": the market is a server feature; offline single-player shows it offline.
  - The vision check (`vision-check.md`): ten doc-settled fixes are in the finish-6 prompts. Its next-package ranking is W2-CRAFT, W2-COOK, W2-CAPTURE, W2-CONSTRUCT, W2-SURVIVAL, then W3-EXCHANGE, which is now running early.
  - W2-INV's vision scope was ruled by the orchestrator: crafting default picks only (spec 05:23).
- **Merge order after resuming.** W2-DATA -> W2-SKILLS -> W2-INV -> W2-PROCESS -> W2-GATHER -> W2-BUILDSYS -> ECON (finish-6's integrator). INVUI right after W2-INV, W3-EXCHANGE after ECON and INVUI. Merge them one at a time, never while another integrator runs.

## 0. How every request is run

**The gauntlet loop applies to every request**: `GAUNTLET.md` at the repo root (translate -> ground -> classify
risk -> reproduce -> implement narrowly -> prove behavior -> prove appearance -> independent review + blind A/B for
visual work -> serialized integrator merges, reruns every gate and screenshot, pushes -> deploy only when the owner
says -> verify the production stamp -> report bluntly).

**Owner direction (2026-10-20, newest wins):** gameplay first. "Work on actual gameplay like what is outlined in
docs. Improve loot, the gameplay loop, skills, crafting, building, etc. The game should be fun and playable on the
next vercel push." Polish (icons, ragdoll, art) runs alongside, never instead, and loses when Godot slots are short.
Before the next deploy, play the loop yourself in the web build (gather -> loot -> craft a better tool -> level a
skill -> build) and tell the owner what a new player can actually do. Answer design questions from
`docs/design/durango-prompts` and `docs/prd` before asking the owner ("the docs should have information like that").
Walk/run animation fixes live in their own thread (branch `claude/mmo-locomotion`, checkout deadfront-art-wave);
integrate its finished clips after an in-game check, below gameplay priority.

## 1. Where things are

| What | Where |
|---|---|
| Owner's folder | `~/Documents/deadfront` = clone of GitHub `mikiagent/deadfront-siege`, branch `claude/mmo-overhaul` (pulled to the tip below) |
| Integration branch | `claude/mmo-overhaul` on GitHub; draft PR [mikiagent/deadfront-siege#17](https://github.com/mikiagent/deadfront-siege/pull/17) to `main`, not to be merged until the owner says |
| Integrator worktree used this session | `~/Documents/deadfront-siege/.claude/worktrees/mmo-overhaul` (same branch; has a git-excluded override.cfg and a warm import cache) |
| Package branches | ALL pushed to GitHub as `claude/mmo-<key>` (also local in `~/Documents/deadfront-siege`, worktrees in `.claude/worktrees/mmo-<key>`) |
| Old folder | `~/Documents/deadfront-siege`: the owner's main checkout still holds an uncommitted UI pass nobody touched |
| Production web build | https://durango-like.vercel.app, deployed 2026-10-20 16:35 CT: stamp `31c064a08/2284b9bf56` (W1-UI, W1-SRVDOM, W2-PLAYER on wave 1). Not yet deployed: camp pieces, see-through trees, HUD icons |
| Godot | `/Applications/Godot_mono.app/Contents/MacOS/Godot` 4.7.1 Mono, typed GDScript, `game/` is the project |
| Tripo | 3,205 credits left (35 spent on the megaloceros trial) |

## 2. Merged into `claude/mmo-overhaul` (every test passes on it)

At the tip: run_all `[tests] PASS`, all 19 `game/tests/t_*.gd` PASS (t_save's announced deliberate SCRIPT ERRORs
only), `SMOKE PASS`. Details per merge in the STATUS.md merge log.

- Wave 1 (see STATUS), survivor v2 / armor / T. rex mount, creature clips, DSC-MINORS, Codex harbour/animals fixes.
- 2026-10-20 this session: **W1-UI** (landscape-phone HUD, theme), **W1-SRVDOM** (server character store),
  **W2-PLAYER** (player split + PlayerActions, with its 4 hooks), **DSC-CAMP** (18 Blender camp pieces, squash),
  **W2-OCCLUDE** (trees/rocks fade whole to half, roofs ghost from inside), **W1-UIICONS** (white icon set in the
  HUD, grindstone icon).

## 3. Half done: branch, state, next step

Every branch below is on GitHub. "Hooks" = a patch in `docs/orchestration/reports/claude-mmo-<key>-hooks.patch` on
that branch that the integrator applies at merge time (it touches other owners' files). Findings files are under
`docs/orchestration/mmo/handoff/findings/` on the package branch.

| Package | Branch (tip) | State | Next step |
|---|---|---|---|
| W2-PROCESS: drying rack, smoker, crock pot, steamer; timed wall-clock jobs, COLLECT, visible stages; spec 08 in-place opportunities (2), no spoil timer, no invented buffs | `mmo-w2-process` (02c1d0f3) | Built and reworked to spec 08; review r1 PARTIAL, pass=false: **blocker** shift-tap pack-up (`player_actions.gd:568` -> `BuildPlacer.pack_up_node`) destroys station contents (`CraftStation.pack_up` is never called); **major** a refused pack-up cancels running jobs; **major** slow stations are strictly worse than the grill (owner/doc payoff needed) | Fix blocker (refuse pack-up while loaded via `pack_up_block_reason`) and job-cancel; check spec 08/11 for what drying/smoking should give; finish review (screens, A/B, runtime break tests) |
| W2-SKILLS: Lv. 1 start, character level caps trees, AUTO nodes, Animal Handling I-IV (cap 3->7), Processing tree, spec 12 nodes, recipe gates, SP per character level (spec 03), save rev 2 | `mmo-w2-skills` (65853f76) + hooks H1-H6 | Built; review r1 PARTIAL: **major** the old-save goldens were rewritten as rev 2, so t_save no longer loads a real rev-1 save (keep originals as inputs); minors: old saves lose unspent SP, field kit waits for character Lv. 2, Processing gates at Lv. 10, taming_pen bonds without the cap. 212 of 918 nodes imported (source table 404) | Fix the golden major; finish review with H1-H6 applied (t_save, srvdom, labs, skills shots); merge with hooks |
| W2-BUILDSYS: modular building, HP, 4 tiers, repair/upgrade/demolish, whole-building rows, chest/large box/signboard, full touch flow at 844x390 | `mmo-w2-buildsys` (58c3a87d) + hooks 1-3 (hook 4 = add snap_build_lab to tools/labs.txt, missing from the patch) | Built (snap lab 55 pieces, --snap-touch PASS with hooks); review r1 stopped before any run | Full review with hooks: gates, break tests (chest dup/loss), doc check of 20/40 slots and 48-char sign, house shots, A/B; merge |
| W2-DATA: material ladder stone->steel (tin, forge, anvil), tools per tier, nets I-V, armour bands 1-60, market_category/rarity/insulation, `requires_node` gates, t_data reachability walk; 3 dup exploits fixed | `mmo-w2-data` (3fee1795) + hooks 1-8 | Built; t_build and t_uiicons fail on the branch alone until hooks (forge/anvil); smoke not rerun on the merged tree. Edited `nature_manifest.json` and `rules.json` outside its list (review them). Forge/anvil have no models (fallback box) | Apply hooks, rerun gates + smoke, independent review, merge. `requires_node` ids must match W2-SKILLS' trees.json |
| W2-INV: materials/food do not stack (instances with uids), 100-slot bag, equip_at, worn gear in save, stacked-save migration | `mmo-w2-inv` (872ea4e3) + hooks | Built; 8 tests fail on the branch alone (they assume stacking) and all pass with the hooks; never reviewed; inventory shots taken but not looked at. **Save format change** (owner gate). Server store still needs a migration | Review with hooks; owner OK on the save change; look at bag at 844x390 (100 slots needs W2-SCREENS grouping); merge |
| W2-GATHER: tool-dependent gather speed/yield (hands 1.35x slower, logs need an axe, flint 1.25x yield), data-driven rare finds (`loot_tables.json`, announced in gold), butchering scaled by knife tier and level, rare carcass parts rolled, "+n Item" popups, GatherXp sink for W2-SKILLS | `mmo-w2-gather` (d8a81a8d) | Built, base merged; all 20 t_*.gd incl. t_gather PASS, gather_lab PASS (glc 1600x900 and 844x390); minimal edits in `player_actions.gd` and `corpse.gd`; never reviewed; rare odds are illustrative (PRDs give none) | Register gather_lab in tools/labs.txt, independent review (Forward+ shots, A/B), merge after W2-DATA |
| ECON: market, auctions, buy orders, caged pets, ledger, VaultBridge to the character store, crash recovery | `mmo-econ` (e0d34c74) | Review r3 failed (**blocker** client could send `act.deposit`; majors: split stacks never withdrawable, contract 0.6/0.7 not met (objective.claim mints, tradable starting wallet, no 30-min trade lock), bridge only recovers at boot). Fix round stopped part-way: an UNTESTED WIP moves act.deposit server-only, adds char.grant, rewrites pet owner, caps bonded pets; t_econ will likely fail in `_test_pets_and_cages` | Finish every r3 item (list in the report's "Review r3" section), tests that fail on each old behaviour, rerun gates, re-review, merge |
| W2-RAGDOLL: 11 species ragdoll and settle | `mmo-w2-ragdoll` (94016f60) | Built (lab 33/33, perf ok); review r1 PARTIAL pass=false: **majors** an aborted ragdoll leaves the body standing; lab covers one blow direction (10/80 fallbacks in a heading sweep, mostly slopes); T. rex flat heading 180 ends 0.655 m under the ground. Branch beats base on slopes in A/B | Fix the three majors, widen the lab to headings x slopes, finish review (windowed runs), merge |
| ICONS2: 32 missing + 33 weak item renders | `mmo-icons2` (1c5c377b) | All 65 renders done and looked at; full gate not passing: armor_scute does not re-render identically, 7 ids not repro-checked, gate flags the needed t_iconart.gd change as out of scope | Fix armor_scute determinism, finish --verify, accept the t_iconart change, squash-merge in-scope paths (list in its report) |
| DSC-QUADS2 | `mmo-quads2` | Review r1 failed (legs in lockstep, megaloceros run skates and tears). Superseded by the locomotion thread | Do not merge |
| Tripo megaloceros trial | `mmo-tripo-megaloceros` | Quadruped walk only, scissoring hind legs; not adopted | Keep for reference |
| W2-BREED, W2-ECO, W1-QA, W1-BIOME, NET, AUDIO, Deinonychus | as before (`mmo-w2-breed`, `mmo-w2-eco`, `mmo-w1-qa`, `mmo-w1-biome`, `mmo-net`, `mmo-audio`, `mmo-art-deinonychus`) | Unchanged this session (early / partial / built-not-reviewed) | See STATUS; W2-BREED must add the bonded cap to `taming_pen.gd:132` |

**Suggested merge order** (shared files and hooks): W2-DATA -> W2-SKILLS (its trees.json node ids feed
DATA's `requires_node`) -> W2-INV (save change, owner OK first) -> W2-PROCESS -> W2-GATHER -> W2-BUILDSYS ->
ECON (then NET/W1-INT for the market over the socket). Re-import after every merge that adds assets or class_name
files; rerun every t_*.gd, run_all, smoke and the merge screenshots; push after each merge.

## 4. Not started (mapped to specs)

- W1-INT: market served over the socket, Settlers NPC orders, contracts v2.1, audio merge.
- W2: CAGE (caged pet items, portraits, area caps), SURVIVAL (01), CRAFT quality windows / COOK (08) / rest of
  spec 11 Processing, CONSTRUCT (10) beyond BUILDSYS, FARM, TAILOR, FISHING (fish has no source yet), ACTION
  combat, DEATH (loot bag, gear wear), SCREENS (100-slot bag, craft/skill screens, chest grid at 844x390),
  W1-WIRE (ArtSlot/ItemArt in bag/craft/market), TERRAIN/water, WEATHER, VFX, models for forge and anvil, kits
  for the 11 camp pieces that cannot be placed yet.
- W3: server-simulated islands, the Exchange UI, social, net QA. W4: hosting (owner picks), economy policy.
- Art: Tripo species from concept sheets (owner batch approval), locomotion thread outputs.

## 5. Rules and decisions that matter (full list in STATUS.md "Owner decisions")

- Mobile is LANDSCAPE (844x390); desktop Chrome 1600x900 on the web renderer is the judge.
- Durango pack 01-12 and the PRDs are binding and answer most design questions; values they mark illustrative stay
  configurable; do not invent canon; mark gaps `# ASSUMPTION`.
- Occluders are partly see-through, never a hole. Dinosaurs ragdoll on death. Building is a big deal; processing
  must be visible. Nothing fake in the economy.
- Asset routing: Tripo only for complex creatures and characters (existing balance only, never buy); headless
  Blender for buildings and props.
- Workers: Claude agents design, review and integrate. DeepSeek (dsc) may take narrow gated mechanical jobs per
  GAUNTLET.md (owner, 2026-10-20 evening: "you can also send off work to Deepseek CLI"); log each in
  docs/orchestration/dsc-improvements.md. Codex: one-bug debugging, model `gpt-reserve`.
- Tests make no sound; never touch `~/Library/Application Support/Godot/app_userdata` (the owner's real save).
- The integrator pushes `claude/mmo-overhaul` and package branches after each merge (owner said "push"). Deploys
  and merging into `main` only when the owner says.

## 6. How to run things

`~/Documents/deadfront` has NO `game/override.cfg`, so Godot there uses the owner's real save. For agent test
runs, first add a git-excluded override:

```bash
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="deadfront-dev"\n' > game/override.cfg
echo game/override.cfg >> .git/info/exclude
```

- Tests: `Godot --headless --path game --script res://tests/run_all.gd` and each `res://tests/t_*.gd`.
- Smoke: `tools/smoke.sh --no-import` (must print SMOKE PASS).
- Labs: `Godot --headless --path game -- --lab=<name>`; screenshots: `Godot --path game --resolution 1600x900 -- --lab=home_lab --shot=<png> --shot-delay=6` (add `--rendering-method gl_compatibility` for the web renderer). HUD: `--lab=ui_real_capture_lab --shot-dir=<dir>` at 844x390, 667x375, 1600x900.
- After merging new assets or class_name files run `Godot --headless --path game --import` once: this session's
  first test run after merging W2-OCCLUDE was all "Failed to compile depended scripts" until the import ran.
- Web: `tools/export_web.sh` then `npx vercel deploy export/web --prod --project durango-like --scope mikiagents-projects --archive=tgz` (what `tools/deploy_web.sh` does); verify the alias: `curl -s https://durango-like.vercel.app/ | grep -o 'build=[^)]*'`. The pack is 254 MB, over the 220 MB W1-WEB ceiling; the last export used `PAYLOAD_MAX_MB=260` (trim survivor 69 MB / nature 51 MB to get back under).
- Helpers: `handoff/scripts/gslot.sh` (5 shared Godot slots, silent audio, 20-minute ceiling) and `mkwt.sh`
  (package worktree with a cloned, re-imported cache); the live copies are in the old session scratchpad
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/`.

## 7. Pitfalls we hit

- Usage limits cut runs; agents commit WIP often; after a stop, check for orphaned Godot runs (`pgrep -fl Godot`).
- Merging two green packages can go red: W2-PLAYER broke the server's gather reach constant; DSC-CAMP's new
  grindstone station broke t_uiicons. Always rerun every t_*.gd on the merged tree before pushing.
- Workers invent values the docs already settle (spoilage timer, steam cap, buffs): check each "owner decision" in
  a report against durango-prompts/PRDs before asking.
- Never message a running workflow agent: it forks a second copy. (Plain Agent-tool subagents can be messaged.)
- Codex sandbox: needs the repo's `.git` dir writable to commit, and cannot open a display.
- Clips: skeleton-only GLBs WITH the skin; re-import after replacing them; strides are in MESH units.
