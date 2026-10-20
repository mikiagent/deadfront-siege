export const meta = {
  name: 'deadfront-finish-6',
  description: 'Merge the built DEADFRONT packages in the handoff order (data, skills, inv, process, gather, buildsys, econ) plus ragdoll, icons2 and forge/anvil art: fix, independent review, blind A/B, base sync, one serialized integrator that pushes',
  whenToUse: 'Owner priority 1 of the MMO program prompt: land the built packages',
  phases: [
    { title: 'Work', detail: 'fix known findings from the real branch state, sync base, regenerate hooks' },
    { title: 'Review', detail: 'independent reviewer on branch + hooks, fix loop' },
    { title: 'Judge', detail: 'blind A/B for visual packages' },
    { title: 'Sync', detail: 'merge the new base after the package ahead lands; delta review' },
    { title: 'Integrate', detail: 'one integrator at a time: merge, hooks, every gate, pixels, push' },
  ],
}

const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const R = `${REPO}/.claude/worktrees`
const BASE = `${R}/mmo-overhaul`
const INT = `${R}/mmo-int`
const OWNER = '/Users/milankinzy/Documents/deadfront'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'
const GSLOT = `${OSP}/gslot.sh`
const MKWT = `${OSP}/mkwt.sh`
const MKS = `${SP}/mkscratch.sh`
const FINDINGS = 'docs/orchestration/mmo/handoff/findings'

const RULES = `
Shared rules (binding for every agent in this run):
- Godot: ${G} (4.7.1 Mono; game/ is the project). Run EVERY Godot command through ${GSLOT} with its own timeout, from your tree, e.g. ${GSLOT} perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_save.gd . gslot holds one of 5 machine-wide slots (the owner's cap), forces silent audio (tests make no sound; never play audio any other way) and caps any run at 20 min. A slot can take minutes to free: start long runs with the Bash tool's run_in_background and read their output, rather than blocking a foreground call past 10 minutes. Never pass --editor. After a merge that adds assets or class_name files run one --import (alarm 900) first: a stale cache prints "Failed to compile depended scripts" / missing-resource errors that look like code bugs.
- Pixels: headless renders nothing. Windowed: ${G} --path game --resolution 1600x900 -- --lab=<lab> --shot=<png> --shot-delay=6 (add --rendering-method gl_compatibility for the web renderer, which is the judge); phones are LANDSCAPE 844x390. HUD: --lab=ui_real_capture_lab --shot-dir=<dir>. Open every PNG with the Read tool before claiming anything visual; logs and node trees are not visual evidence.
- Gates: --import; every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs, as on base); --script res://tests/run_all.gd prints [tests] PASS; tools/smoke.sh --no-import prints SMOKE PASS; the package's labs with 0 SCRIPT ERROR lines; creature runs 0 "couldn't resolve track"; no new ~/Library/Logs/DiagnosticReports/Godot-*.ips (if one appears, name it and the command).
- Isolation: every tree has a git-excluded game/override.cfg (custom user dir); keep it. Never touch ~/Library/Application Support/Godot/app_userdata (the owner's real save). Never touch the owner's checkouts ${REPO} (main checkout with an uncommitted UI pass) or ${OWNER}, nor another package's worktree. Throwaway trees for reviews and gate runs: bash ${MKS} <name> <ref> [hooks patch path relative to the tree] (detached, cloned import cache, override.cfg, patch applied, imported; prints its path; reusing a name replaces it).
- Code: typed GDScript in the house style, class_name per file, short why-comments, no new autoloads or third-party deps, no god-file growth (extract instead), data in game/data JSON. Tests are SceneTree scripts that load game classes via load() inside functions, never by class_name at parse time, and must FAIL on the old behaviour (prove it: run against the old code or a mutation and quote the FAIL line).
- Ownership: one package per branch. Edit only your package's files (its plan-register.md section, its report, plus grants in this prompt). Integrator-only files (game/scripts/core/{game,main,world}.gd, game/project.godot, game/tests/run_all.gd, game/scripts/ui/touch_controls.gd) and files owned by any other package (merged or not) get exact, compiling changes in the package's hooks patch (git apply --check clean on the current claude/mmo-overhaul; regenerate it after every base merge), never edits on the branch. The integrator applies the patch at merge time; reviewers test the branch WITH it applied.
- Design truth: docs/orchestration/mmo/STATUS.md "Owner decisions" (newest wins), docs/orchestration/mmo/contracts.md, docs/design/durango-prompts/01-12 and docs/prd/ are binding. Answer design questions from them first and quote the line in the report; do not invent lore, species or mechanics; where they are silent pick the simplest thing, keep the value in data and mark # ASSUMPTION (list each in the report). Owner rules that bite: gathered materials and food never stack (instances with uids; grouping is visual only); colour = things, white = actions; targets 44 px+ (56-64 px for contextual actions); mobile is landscape 844x390; desktop Chrome 1600x900 on gl_compatibility is the judge; nothing fake in the economy; packing up or demolishing never destroys items.
- Owner gates: if a change alters the save format beyond new optional fields that old saves load without (a migration, a rev bump, a changed meaning), money or multiplayer authority, species identity or a major visual direction, and this prompt does not record the owner's approval, put it in owner_gate and do not work around it.
- Commits: commit early and often (usage limits cut runs; uncommitted work is lost); messages end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Never git add -A; never commit override.cfg, .godot/, or *.import/*.uid/_Image_* churn you did not deliberately create; no preview PNGs or work/ dirs in the repo. Only the integrator merges into claude/mmo-overhaul and pushes; nobody deploys or touches main.
- DeepSeek: a narrow mechanical sub-job with a fast verify gate (data rows, table-driven tests, call-site sweeps, Blender builds from an existing kit) MAY go to one dsc worker per GAUNTLET.md "DeepSeek workers" (sub-worktree, a read-only verify script that is the spec, --budget 2 --max-hours 3; at most 2 dsc workers machine-wide: pgrep -f 'node .*dsc cook run' | wc -l). Stop it after ~1 h without a milestone and take over; review its diff; append the dated outcome and a DeepseekCLI improvement prompt to docs/orchestration/dsc-improvements.md on your branch. Otherwise do it yourself.
- Never use SendMessage. Never claim a check passed unless you ran it and saw the line; quote the decisive output line.`

const WORK_SCHEMA = { type: 'object', properties: {
  done: { type: 'boolean', description: 'true when every item of the task is fixed, committed and its gates pass' },
  owner_gate: { type: 'string', description: "'' if none; otherwise the exact change that needs the owner's yes" },
  hooks_patch: { type: 'string' }, head: { type: 'string', description: 'git rev-parse HEAD of the branch' },
  gates: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } },
  required: ['done', 'owner_gate', 'head', 'summary'] }
const SYNC_SCHEMA = { type: 'object', properties: {
  up_to_date_before: { type: 'boolean' }, code_changed: { type: 'boolean', description: 'true if anything beyond a conflict-free merge and a regenerated patch changed' },
  gates_pass: { type: 'boolean' }, head: { type: 'string' }, owner_gate: { type: 'string' },
  gates: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } },
  required: ['up_to_date_before', 'code_changed', 'gates_pass', 'head', 'owner_gate', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW_SCHEMA = { type: 'object', properties: {
  pass: { type: 'boolean', description: 'true only with zero blockers, zero majors and every acceptance item verified' },
  reviewed_sha: { type: 'string', description: 'git rev-parse of the branch tip you reviewed' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } },
  required: ['pass', 'reviewed_sha', 'findings', 'summary'] }
const PAIRS_SCHEMA = { type: 'object', properties: { pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pairs', 'summary'] }
const JUDGE_SCHEMA = { type: 'object', properties: {
  verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } },
  overall: { type: 'string' } }, required: ['verdicts', 'overall'] }
const INT_SCHEMA = { type: 'object', properties: {
  merged: { type: 'boolean', description: 'true only if claude/mmo-overhaul now contains the package and every gate passed' },
  sha: { type: 'string' }, pushed: { type: 'boolean' }, owner_pulled: { type: 'boolean' },
  gates: { type: 'array', items: { type: 'string' } }, pending: { type: 'array', items: { type: 'string' } },
  failures: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string' }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } },
  required: ['merged', 'summary'] }

const hp = (key) => `docs/orchestration/reports/claude-mmo-${key}-hooks.patch`

const PKGS = [
  { key: 'w2-data', label: 'W2-DATA', visual: false, startRound: 1,
    scope: `Package W2-DATA (items/recipes ladder). Spec: "#### W2-DATA" in docs/orchestration/mmo/plan-register.md, durango-prompts 04, 05, 08, 11, 12 and GAUNTLET.md's ladder Stone -> Bone -> Flint -> Obsidian -> Copper -> Bronze -> Iron -> Steel (crafted item level derives from the inputs; a level 5 tool must feel clearly better than level 1). Built: the ladder to steel (tin, forge, anvil), tools per tier, nets I-V, armour bands 1-60, market_category/rarity/insulation on every item, requires_node recipe gates, the t_data reachability walk, 3 dup exploits fixed. Report docs/orchestration/reports/claude-mmo-w2-data.md; hooks 1-8 in its patch (forge/anvil kits and icons, crafting.gd progression_block enforcing requires_node, ...). On the branch alone t_build and t_uiicons fail until the hooks land. It also edited game/data/nature_manifest.json and game/data/rules.json outside its list. NEVER REVIEWED. Forge and anvil have no models yet (fallback box): the separate package FORGEART builds them after this merges; do not build them here. W2-SKILLS (next in the merge order) re-keys the skill trees: every requires_node id must exist on the base AND in claude/mmo-w2-skills' trees (read with git show claude/mmo-w2-skills:<path>); use ids both have, or list exactly which ids W2-SKILLS must keep.`,
    first: `Merge claude/mmo-overhaul into the branch. Regenerate the hooks patch so git apply --check is clean on the current base; add any missing hook. Justify every nature_manifest.json / rules.json edit in the report or move it into the hooks patch. Check the requires_node ids against both trees as above. Commit, then in a scratch tree with the hooks applied (bash ${MKS} work-w2-data claude/mmo-w2-data ${hp('w2-data')}) run every gate: every t_*.gd, run_all, smoke, craft_lab, equip_mount_lab, the progression probe. Check the ladder numbers (rung times, tool levels, net tiers) against the specs and fix what they contradict. Update the report (acceptance with exact lines, hooks, assumptions), commit.`,
    reviewFocus: `ladder correctness against the specs (every rung reachable on the islands that exist; a higher-tier tool clearly better; nets I-V; armour bands); the 3 dup exploits really closed (reproduce each on the base, then fail to on the branch); requires_node gates enforced in the real crafting path with the hooks; items.json/recipes.json integrity (ids, icons, market_category, rarity); nothing outside scope.` },
  { key: 'w2-skills', label: 'W2-SKILLS', visual: true, startRound: 2,
    approved: 'the save rev 2 bump with migration of rev-1 saves (the owner listed "skill trees (fix the save-test review issue)" for merging)',
    scope: `Package W2-SKILLS (Durango 1-60 skill trees). Spec: its plan-register.md section, durango-prompts 03, 09, 11, 12. Built: Lv. 1 start, character level caps trees, AUTO nodes, Animal Handling I-IV (bonded cap 3 -> 7), Processing tree, spec 12 nodes, recipe gates, SP per character level (spec 03), save rev 2 with migration of rev-1 saves. Hooks H1-H6 in its patch. Report docs/orchestration/reports/claude-mmo-w2-skills.md; review r1 in ${FINDINGS}/w2-skills-review-r1.json (on the branch). Only 212 of the 918 reference nodes were imported because the source table returned 404: look for the node table in docs/design/durango-prompts/12 and docs/reference; import what the repo holds, never invent nodes, mark each node functional/partial/defined.`,
    first: `Fix review r1. MAJOR: the old-save goldens (game/tests/fixtures/save_v3_golden.json, save_v3_away_golden.json) were rewritten into rev-2 form, so t_save no longer loads a real rev-1 save. Restore the originals from the base byte for byte as untouched INPUTS, load them end to end through the migration in t_save and assert the rev-2 result (levels, AUTO nodes, SP budget, unspent SP, every existing unlock kept); keep any rev-2 expectation in separate new fixtures; prove the test FAILS when the migration is broken (mutation; quote the line). MINORS, answered from the specs first: old saves lose unspent SP (keep it unless spec 03 says otherwise); the field kit waits for character Lv. 2; Processing gates at Lv. 10 (specs 11/12); taming_pen bonds without the cap. ORCHESTRATOR GRANT (W2-BREED is not running): provide ONE function that returns a player's bonded-pet cap (3 + Animal Handling I-IV, max 7, spec 09) and make the bond path in game/scripts/pets/taming_pen.gd refuse at the cap with a clear notice and no animal lost (caged animals never count); the market's caged-pet unpack will call the same function. Merge claude/mmo-overhaul, regenerate the hooks patch (apply-clean), commit, then in a scratch tree with the hooks run t_save, t_srvdom, t_server_domain, every t_*.gd, run_all, smoke and the skills labs, and take skills-sheet shots at 1600x900 (Forward+ and gl_compatibility) and 844x390; LOOK at them (no "Lv. 0", readable at phone size). Update the report, commit.`,
    reviewFocus: `migration of a REAL rev-1 save (git diff claude/mmo-overhaul -- game/tests/fixtures must show the old goldens untouched); unspent SP and unlocks kept; spec 03 SP per character level; the bonded cap 3 -> 7 refusal with no animal lost; every requires_node id W2-DATA uses exists; the skills sheet at 844x390 and 1600x900.` },
  { key: 'w2-inv', label: 'W2-INV', visual: true, startRound: 1,
    approved: 'the save format change (owner, 2026-10-20: "merge it once its independent review passes and old saves migrate cleanly in tests")',
    scope: `Package W2-INV (non-stacking instance inventory, durango-prompts 05 and 08). Built: gathered materials and food do not stack (each is an instance with uid, level, traits, processing state and its own bag slot), 100-slot bag, equip_at, worn gear in the save, stacked-save migration. Hooks in its patch; 8 tests fail on the branch alone (they assume stacking) and pass with the hooks. Report docs/orchestration/reports/claude-mmo-w2-inv.md. NEVER REVIEWED; its bag shots were never looked at. Migration rule (spec 08): split old stacks into instances and never delete any; what does not fit goes to home cargo/storage and is logged. Stacking stays configurable per category (currency, some consumables). Bag capacity per pack 05 (base 100 + equipment/Pocket bonuses). The server character store (game/scripts/server/, merged W1-SRVDOM) must migrate a stacked character the same way (hooks patch). Grouping is VISUAL ONLY: a bag of 100 single instances must be usable at 844x390 landscape and 1600x900 (group identical items in the bag view with a count badge that expands to the instances; never merge instances). game/scripts/ui/inventory_ui.gd belongs to the merged W1-UI: changes there go in the hooks patch.`,
    first: `Merge claude/mmo-overhaul into the branch and regenerate the hooks patch (apply-clean). Add what is missing: the server-store migration, visual grouping in the bag, migration tests that load REAL old stacked saves (fixtures from the base, untouched) and assert every unit survives as an instance (count per item id and in total), overflow lands in home storage with a log line, a save/load round-trip keeps uids, a stack bigger than the bag, worn gear kept, currency still stacks. Prove each test fails on the old code. Commit. In a scratch tree with the hooks run every t_*.gd, run_all, smoke, the inventory/craft/equip labs, and take bag shots (a full bag of 100 mixed instances) at 844x390 and 1600x900 in both renderers; LOOK at them and fix what is unreadable. Update the report, commit.`,
    reviewFocus: `no item is ever lost or duplicated: real old stacked saves migrate with every unit accounted for; overflow to storage; split/merge/drop/craft/equip/trade/station paths on instances; uids unique after load; server store migration; currency/consumable stacking rules; the bag at 844x390 is usable with 100 instances and grouping is visual only.` },
  { key: 'w2-process', label: 'W2-PROCESS', visual: true, startRound: 2,
    scope: `Package W2-PROCESS (processing stations: drying rack, smoker, crock pot, steamer; timed wall-clock jobs, COLLECT, visible stages; spec 08: about 2 in-place processing opportunities per instance, no spoil timer, no invented buffs; spec 11 processing). Owner: "processing must feel impactful: you see the strips hang on the rack, change colour over time, smoke drifts, and the result matters"; reference docs/reference/durango-camp-workstations.webp. Report docs/orchestration/reports/claude-mmo-w2-process.md; review r1 in ${FINDINGS}/w2-process-review-r1.json (on the branch). game/scripts/player/player_actions.gd (merged W2-PLAYER) and build_placer.gd (W2-BUILDSYS, in this run) are not yours: changes there go in the hooks patch ${hp('w2-process')}.`,
    first: `Fix review r1. BLOCKER: the shift-tap pack-up (player_actions.gd:568 -> BuildPlacer.pack_up_node) destroys station contents; CraftStation.pack_up is never called. Rule: packing up never destroys an item. Give stations a pack_up_block_reason() (inputs, outputs or running jobs present -> a clear notice such as "Collect the rack first") that every pack-up path consults BEFORE any side effect (a duck-typed check in BuildPlacer.pack_up_node via the hooks patch covers every path). MAJOR: a refused pack-up must not cancel running jobs or move items (all checks before any change). MAJOR: slow stations are strictly worse than the grill: answer from the specs (08: no spoil timer, ~2 in-place opportunities, effects come from item properties; 11: in-place modification with trade-off traits; 04: instance attributes) what drying, smoking, steaming and the crock pot give, and implement that as data (quote the spec lines; values the specs call illustrative stay configurable, # ASSUMPTION) so each slow station has a real payoff. Break tests: pack-up loaded/empty/running, save/load mid-job, collect into a full bag (nothing lost), two jobs at once. Merge the base, regenerate the hooks patch, commit, run every gate in a scratch tree with the hooks, take windowed shots of each station's stages (Forward+ and gl_compatibility, 844x390) and LOOK at them. Update the report, commit.`,
    reviewFocus: `item safety on every station path (pack-up, demolish, collect into a full bag, save/load mid-job, wall-clock across reload); each slow station's payoff matches the specs; stages visibly change in-game.` },
  { key: 'w2-gather', label: 'W2-GATHER', visual: true, startRound: 1,
    scope: `Package W2-GATHER (gathering and loot; durango-prompts 04 and 12 priority 1). Built: tool-dependent gather speed/yield (hands 1.35x slower, logs need an axe, flint 1.25x yield), data-driven rare finds (game/data/loot_tables.json, announced in gold), butchering scaled by knife tier and level, rare carcass parts rolled, "+n Item" popups, a GatherXp sink for W2-SKILLS. Report docs/orchestration/reports/claude-mmo-w2-gather.md. NEVER REVIEWED. Its edits in player_actions.gd and corpse.gd are other packages' files: they move into the hooks patch ${hp('w2-gather')}. Rare odds are illustrative (the PRDs give none): data, # ASSUMPTION. Once W2-INV merges, gathered items are instances (no stacking); the sync step adapts to that.`,
    first: `Merge claude/mmo-overhaul. Move the player_actions.gd/corpse.gd edits into the hooks patch (apply-clean on the base) and restore those files on the branch. Register gather_lab where the base registers labs (find how; if there is no registry, list it in the report). Check every gather rule against specs 04/12 and GAUNTLET.md ("gathering is from reach without teleport; movement cancels; progress appears above the node; starter-island gatherables are level 1"). Commit. In a scratch tree with the hooks run every gate and gather_lab, and take windowed shots of a gather with a rare find and the "+n" popups at 1600x900 (both renderers) and 844x390; LOOK at them (popups readable, no overlap with plates or the gather ring). Update the report, commit.`,
    reviewFocus: `gather and butcher outcomes per tool and level (seeded statistical runs), rare-find rates match the data, no duplication through repeated taps or interrupted gathers, GatherXp reaches the skills, popups readable and not overlapping at 844x390.` },
  { key: 'w2-buildsys', label: 'W2-BUILDSYS', visual: true, startRound: 1,
    scope: `Package W2-BUILDSYS (modular building; its plan-register.md section and STATUS owner decisions; spec 10's data shape kept compatible). Built: modular foundations/walls/doorways/windows/ceilings/roofs/ramps/stairs with snapping, structure HP, 4 tiers, repair/upgrade/demolish, whole-building rows, chest/large box/signboard, a full touch flow at 844x390, roofs fade through the merged occlusion API. Report docs/orchestration/reports/claude-mmo-w2-buildsys.md; hooks 1-3 in its patch; hook 4 (register snap_build_lab) is missing from the patch. Review r1 stopped before any run (${FINDINGS}/w2-buildsys-review-r1.json). Owner: "building is a big deal"; walls may be passable for the owner while blocking enemies; wild dinosaurs attack blocking structures. W2-PROCESS (merging before you) adds a duck-typed pack_up_block_reason() check to BuildPlacer.pack_up_node through its hooks: keep it when you sync.`,
    first: `Merge claude/mmo-overhaul. Add hook 4 (or, if the base has no lab registry, list the lab in the report) and regenerate the patch (apply-clean). Answer from the docs: chest and large box slot counts (the build says 20/40) and the 48-character sign limit (specs 05/10, PRDs); fix to the docs or mark # ASSUMPTION. Break tests: a chest with items packed up, demolished, destroyed by a dinosaur, saved and loaded (nothing lost, nothing duplicated); upgrade/repair spends exact materials; snapping cannot overlap resource nodes. Commit. In a scratch tree with the hooks run every gate, snap_build_lab and its --snap-touch flow, build_lab, the siege probe; take windowed shots of a snapped 2-storey house outside and inside (roof faded) at 1600x900 in both renderers and the touch flow at 844x390; LOOK at them. Update the report, commit.`,
    reviewFocus: `container safety (contents never lost or duplicated on pack-up, demolish, destruction, save/load), structure HP and dinosaur damage, tier/upgrade/repair costs, owner-passable walls vs enemies, the touch flow at 844x390, the house against ARK and docs/reference/durango-placing-reference.webp.` },
  { key: 'econ', label: 'ECON', visual: false, startRound: 4,
    approved: 'merging the market engine once the deposit fix is finished and tested (owner priority list); contracts v2 section 0 (server-owned characters, no client-claimed deposits) is the program decision',
    scope: `Package ECON (server-side economy engine: market, auctions with anti-snipe, buy orders, caged pets, ledger/escrow/fees, VaultBridge to the server character store, crash recovery; contracts.md sections 0 (v2), 4, 5.1-5.3, 6 (6.1 caged pets) and spec 06). Report docs/orchestration/reports/claude-mmo-econ.md (its "Review r3" section lists every item); findings ${FINDINGS}/econ-review-r3.json (on the branch). Nothing fake: every transaction moves real items, currency and ownership. Market defaults (0.25x-4x bands, 30-minute trade lock) are planner defaults: configurable, # ASSUMPTION. Materials are instances (W2-INV): escrow keeps uid and origin. The bonded-pet cap comes from W2-SKILLS' single function once that merges (sync step). Server files owned by the merged W1-SRVDOM go in the hooks patch ${hp('econ')}.`,
    first: `A fix round stopped part-way: the last commit is an UNTESTED WIP (act.deposit server-only, char.grant, pet owner rewrite, bonded cap). Run the economy tests first (it likely fails in _test_pets_and_cages) and fix. Then finish EVERY review r3 item. BLOCKER: a client must not be able to send act.deposit (remove it from IntentHandlers.CLIENT_OPS and the relay list; only the server's VaultBridge deposits; a client-sent act.deposit is refused and logged). MAJOR: assets the books split stay withdrawable (partial buy, part listing, partial order fill, the seller's remainder). MAJOR: contract 0.6/0.7: objective rewards only from server-observed state (objective.claim never mints from a client claim), the starting wallet is bound (not tradable), new accounts are trade-locked 30 minutes. MAJOR: bridge recovery runs at any time, not only at boot (orphaned exports, the double-refusal branch of _into_vault). Then the minors. For each item write a test that FAILS on the old behaviour (run it against the pre-fix commit and quote the FAIL line) and passes now. Fuzz >= 3000 ops with the invariants (no currency or item created or destroyed outside faucets/sinks). Merge claude/mmo-overhaul, regenerate the hooks patch, commit, run every gate in a scratch tree with the hooks. Update the report, commit.`,
    reviewFocus: `authority: try to mint, duplicate or steal through every client-reachable op (act.deposit, objective.claim, withdraw, cancel, partial fills, replayed rid, crash mid-escrow, recovery); conservation invariants under fuzz; caged-pet listings carry the full PetRecord and respect the bonded cap; split assets withdrawable; trade lock and bound wallet.` },
  { key: 'w2-ragdoll', label: 'W2-RAGDOLL', visual: true, startRound: 2, lane: 'polish',
    scope: `Package W2-RAGDOLL (11 species ragdoll and settle on death). Binding spec docs/orchestration/mmo/handoff/ragdoll-spec.md (owner: "if you're having issues with dead dinosaurs not staying on the ground, try having them ragdoll on death"; GAUNTLET: dinosaurs ragdoll onto the terrain, then freeze). Report docs/orchestration/reports/claude-mmo-w2-ragdoll.md; review r1 in ${FINDINGS}/w2-ragdoll-review-r1.json (on the branch). Its A/B on slopes already beat the base.`,
    first: `Fix review r1. MAJOR: an aborted ragdoll (stretch guard in the first frames) leaves the body standing: the fallback must still lay the corpse on the ground (death clip to its end plus a terrain-conformed pose), never upright. MAJOR: widen ragdoll_lab to every species x {flat, 10, 20, 30 degree slopes} x 4+ headings x 2+ blow directions, with per-case gates (lowest posed-skin vertex within a few cm of the terrain, nothing deeper than the spec's limit, lying height, settle time, frozen afterwards) and a total fallback-rate gate; fix profiles until the sweep passes (the reviewer saw 10 of 80 deaths fall back, mostly on slopes). MAJOR: tyrannosaurus on flat ground, heading 180, ends 0.655 m under the ground: fix the profile/conform. Then the minors. Windowed runs: shots of several species lying on slopes in Forward+ and gl_compatibility; LOOK at them. Merge claude/mmo-overhaul. Update the report, commit.`,
    reviewFocus: `your own death sweep (species x slopes x headings x blow directions, plus real kills in island play): bodies always lie on the terrain, never stand, sink or float; frame cost and the 4-simulating cap; freeze after settle; the look in both renderers.` },
  { key: 'icons2', label: 'ICONS2', visual: true, startRound: 1, lane: 'polish', noHooks: true,
    intNote: 'SQUASH-MERGE (git merge --squash claude/mmo-icons2) and commit only the in-scope paths the report lists (tools/blender/items/*, tools/render_icons.py, game/assets/icons/render/* with their .import and manifest, the t_iconart.gd change, the report, tools/dsc/verify_icons2.sh and icons2_base.json); drop work/, the root TASK.md, stray .uid and anything else.',
    scope: `Package ICONS2 (item icon renders: 32 missing + 33 weak; owner: items should look cool; a captured animal is shown in a lashed wooden cage with a small generic dinosaur inside, a tamed one in the same cage with the door open and a hide collar and lead). Brief TASK.md and gate tools/dsc/verify_icons2.sh in the tree (the gate is the spec; never edit it or icons2_base.json). Headless Blender only (${BLENDER} -b --factory-startup -P tools/render_icons.py -- --only id1,id2). Report docs/orchestration/reports/dsc-icons2.md (write the final one as docs/orchestration/reports/claude-mmo-icons2.md). The branch is 45 commits behind the base.`,
    first: `All 65 renders are done and were looked at; the full gate does not pass yet. Merge claude/mmo-overhaul. Make armor_scute re-render byte-identically (find the nondeterminism: seeds, dict order, time-based noise), repro-check the 7 ids not yet checked, and make the full tools/dsc/verify_icons2.sh pass. ORCHESTRATOR GRANT: the t_iconart.gd change the gate flags as out of scope is approved (keep it minimal, explain it in the report). Look at a contact sheet of all 65 next to existing icons at full size and at HUD size. List the in-scope paths for the squash merge in the report. Commit.`,
    reviewFocus: `every one of the 65 ids at full size and HUD size against its neighbours (consistent light, scale, silhouette, colour = things), the cage reading for captured vs tamed animals, determinism (byte-identical re-render), only in-scope paths in the squash list.` },
  { key: 'forgeart', label: 'FORGEART', visual: true, startRound: 1, lane: 'polish', create: true,
    intNote: 'SQUASH-MERGE (git merge --squash claude/mmo-forgeart) and commit only in-scope paths (builder scripts, new GLBs and their .import, props_manifest rows, the report and any hooks); drop previews and work/.',
    scope: `Package FORGEART: real models for the forge and anvil stations W2-DATA added (they show a fallback box; owner: a placeholder that looks boxy has failed; building is a big deal). Build them with the merged headless Blender structure kit (tools/blender/structures/, the way DSC-CAMP built the 18 camp pieces: builder scripts, ${BLENDER} -b --factory-startup -P ..., check_manifest.py) with their props_manifest rows so the game swaps them in BY DATA: a stone forge with a visible ember bed, bellows and chimney; an anvil on a stump with a hammer; scaled against the survivor; the shared atlas and every existing GLB stay byte-identical. Reference docs/reference/durango-camp-workstations.webp. Report docs/orchestration/reports/claude-mmo-forgeart.md.`,
    first: `If ${R}/mmo-forgeart does not exist create it with: bash ${MKWT} forgeart (it branches from claude/mmo-overhaul, which now has W2-DATA). Build both models, wire their manifest rows, run t_structart, t_build, every t_*.gd, run_all, smoke and build_lab; take windowed in-game shots of both placed next to the survivor (Forward+ and gl_compatibility, 844x390) and LOOK at them. Commit.`,
    reviewFocus: `silhouette and materials against the camp reference and the other Blender camp pieces, scale next to the survivor, embers visible above the ground disc, no out-of-scope edits.` },
]
PKGS.forEach(p => { p.branch = `claude/mmo-${p.key}`; p.wt = `${R}/mmo-${p.key}`; p.hooks = p.noHooks ? '' : hp(p.key) })

// Vision check (docs vs this run, 2026-10-20): fixes the docs settle for files these packages are editing now.
const VISION = {
  'w2-data': `(1) PRD durango-wild-lands-systems-prd.md:531-533 makes processing mandatory: "Stalks / reeds -> twine -> rope", "Hide -> dried hide -> straps". hide_strap takes dried hide only (not raw hide), rope takes twine only (not raw reed/stalk), and armour/tent/bed hide slots take dried hide/leather or straps. Make sure dried hide and twine are obtainable on the start island before anything needs them (a drying-rack processing row - W2-PROCESS owns processing.json, so put that row in your hooks patch and name it in the report - or a recipe at an existing station) and t_data's reachability walk proves it. (2) docs/design/world-design.md:66: the home grassland yields no ore; metal starts with desert copper_ore (35/50) and volcanic black_iron (60). Remove ore from grassland nodes (e.g. GraniteBoulder's ore yield), keep every rung reachable through the islands that exist, and add a t_data assert that no metal source sits on the home climate.`,
  'w2-skills': `(1) Spec 12:215 "Do not implement a decorative but inert 918-node UI" and STATUS "never an inert tree": a node whose status is not functional cannot be bought for SP (show it locked, "not in the game yet"), except prerequisites a functional node needs (keep the chain buyable or reroute it). (2) docs/design/skills.md:9 "Refunds: 5 free unlearns a day, then 30 Warp Gems, max 10 a day" (spec 03:37 keeps it configurable): refund() enforces the daily limit from trees.json's refund config with a clear notice; charge Warp Gems only if that currency exists, else refuse past the free count; the day counter is an optional save field (no rev bump).`,
  'w2-inv': `Spec 05:23 "protect valuable items from default auto-consumption" (and 04:41): every default consume path (crafting auto-pick, consume / consume_by_category, autofeed, quick-eat) takes the least valuable instance first (no trait attributes, then lowest level, then oldest), never silently a rare or higher-level one. One ordering function, used everywhere; paths in other packages' files go in the hooks patch. Test it.`,
  'w2-process': `(1) Spec 08:98 "a multi-material recipe consumes specific instance IDs atomically": a station consumes the exact instances the player picked and previewed (pass the sheet's picks into ProcessStation.load_from; invalid picks refuse with a notice; never substitute); only queued repeats auto-pick, with W2-INV's least-valuable-first order. (2) Spec 11:155 "demolished stations ... without losing items" and spec 10:102: a station destroyed by damage never deletes its inputs, outputs or queued inputs: give CraftStation/ProcessStation a duck-typed salvage_contents() that returns them; W2-BUILDSYS's destruction path calls it and drops them into the bag, home cargo or a recoverable loot bag.`,
  'w2-gather': `docs/design/world-design.md:66-71 gives each climate its own materials (home grassland: fibre_stalk, branch, stone, herb_leaf, berries, clay; flint is temperate, copper_ore desert): every rare-find row in loot_tables.json lists the climates whose materials include it and only rolls on a node of that climate (node climate from the island data); a home-grassland node never yields flint or copper. Values # ASSUMPTION, data only; a test proves it.`,
  'w2-buildsys': `(1) Spec 10:102 "must not silently delete stored items" and spec 11:155: a destroyed, collapsed or demolished structure never deletes contents - bag, then home cargo, then a recoverable loot bag at the spot; never "lost (logged)". Before queue_free call a duck-typed host.salvage_contents() when present (W2-PROCESS stations implement it). Test it. (2) Storage capacity is settled by PRD:582 "baskets (~100 slots early) -> boxes -> large boxes", spec 05:14 and spec 10:90 (large box up to 160 at Lv. 60): chest >= 100 slots, large box 160 (scaled by level if building level exists), in structures.json - not 20/40.`,
  'econ': `PRD:131 (gathered and processed goods are sold on the island market) and spec 06 (a listing shows the real instance, including processing remaining): escrow and listings keep every per-instance field W2-INV, W2-PROCESS and W2-GATHER write (uid, origin, level, traits, processing state such as attributes.processed): whitelist them in limits.json and add a test that deposits, lists, buys and withdraws a processed instance (e.g. dried meat) with every field intact.`,
}
PKGS.forEach(p => {
  const v = VISION[p.key]
  if (!v) return
  p.first += `\nVISION FIXES (the docs settle these; check each cited line first - if it does not say this, show that in the report and skip the item): ${v}`
  p.reviewFocus += ` Also verify the vision fixes against the cited doc lines: ${v}`
})
const byKey = {}
PKGS.forEach(p => { byKey[p.key] = p })

const ctx = (p) => `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival game (game/ is the project) being raised to an ARK: Survival Ascended-quality, server-authoritative survival MMO with Durango: Wild Lands-depth systems and a real player economy; judged in desktop Chrome at 1600x900 on the web renderer and on landscape phones (844x390). Owner direction: gameplay first; the next push must be fun and playable.
Package: ${p.label}. Branch ${p.branch}; package work tree ${p.wt} (implementers work only there and in scratch trees they create). Hooks patch: ${p.hooks || 'none (squash-merged package)'}. Owner approvals recorded for this package: ${p.approved || 'none beyond the rules'}.
${p.scope}
${RULES}`

const workPrompt = (p) => `${ctx(p)}

ROLE: implementer of ${p.label}, continuing from the branch's real state (read git log, the report and the findings; keep what is good). Previous runs were cut by usage limits; restart from what is committed.
TASK: ${p.first}
Return done, owner_gate ('' if none), hooks_patch, head, gates (decisive lines), summary.`

const reviewPrompt = (p, round, mode, sinceSha) => `${ctx(p)}

ROLE: independent, exceptionally demanding reviewer (${mode === 'delta' ? `DELTA review ${round}: since the last passing review at ${sinceSha}, the branch merged a newer base and/or fixed integration failures` : `round ${round}`}) for ${p.label}. You did not write this. Do not edit or commit anything in ${p.wt}; probes and screenshots go under ${SP}/review/${p.key}/${mode === 'delta' ? 'd' : 'r'}${round}/.
Review what will merge: the branch WITH its hooks applied: bash ${MKS} rev-${p.key} ${p.branch}${p.hooks ? ' ' + p.hooks : ''} (it fails loudly if the patch does not apply). git merge-tree --write-tree claude/mmo-overhaul ${p.branch} must be clean (a conflict is a major).
1. Read the spec, the report, earlier findings and ${mode === 'delta' ? `what changed since ${sinceSha}: git log --no-merges ${sinceSha}..${p.branch}, the conflict resolutions in its merge commits, and git diff ${sinceSha} ${p.branch} restricted to the package's files and the hooks patch` : `the full diff (git log claude/mmo-overhaul..${p.branch}; git diff claude/mmo-overhaul...${p.branch}) and the hooks patch`}.
2. Run EVERY acceptance item yourself through gslot in the scratch tree (the report's acceptance list, the plan-register section and the task given to the implementer) and record met/evidence (quote the decisive line or name the screenshot). Unrunnable = met false with the reason. Rerun every t_*.gd, run_all and smoke.
3. Scope: an edit outside the package's files and grants (instead of the hooks patch) is a blocker.
4. Try to break it: ${p.reviewFocus} Also save round-trips, hostile inputs, regressions in neighbouring systems and the labs the spec names.
5. Code quality: house style, no god-file growth, no dead code. A test that cannot fail is a blocker (mutate the code under test and see it fail).
6. Design truth: check each # ASSUMPTION and each "owner decision" in the report against durango-prompts, PRDs and STATUS owner decisions; a value the docs settle differently is a major.
7. ${p.visual ? `Visual: take your OWN matched screenshots - BEFORE from a base tree (bash ${MKS} revbase-${p.key} claude/mmo-overhaul) and AFTER from your review tree, same scene, camera, resolution and renderer; 1600x900 Forward+ and gl_compatibility, plus 844x390 for anything on the HUD or touch flow; look at every one; judge against ARK: Survival Ascended, the Durango references in docs/reference/ and GAUNTLET.md's visual rules. ${mode === 'delta' ? 'Return pairs only if something visual changed since the last review.' : 'Return 2-6 matched pairs (absolute PNG paths) in "pairs" - a blind judge uses them.'}` : 'Non-visual: pairs empty.'}
Severity: blocker = item loss or duplication, crash, save break, unsanctioned edit, acceptance unmet, test that cannot fail, visible regression; major = required behaviour missing or untested, or clearly sub-par; minor = polish. pass=true only with zero blockers and zero majors. reviewed_sha = git rev-parse ${p.branch} at the time you reviewed.`

const fixPrompt = (p, findings, source) => `${ctx(p)}

ROLE: implementer of ${p.label}, continuing. ${source === 'integration' ? 'The integrator could not merge the package: the gates below failed on the merged tree (claude/mmo-overhaul + this branch + its hooks).' : 'An independent reviewer (and for visual work a blind art judge) found the problems below.'} Fix every blocker and major and the cheap minors, add a check that would have caught each, rerun the affected acceptance items, merge claude/mmo-overhaul if the base moved and regenerate the hooks patch, update the report, commit. If a finding is wrong, show the evidence in the report instead.
Findings (JSON):
${JSON.stringify(findings, null, 1)}
Return done, owner_gate, hooks_patch, head, gates, summary.`

const shotsPrompt = (p) => `${ctx(p)}

ROLE: screenshot taker for a blind A/B of ${p.label}. Do not edit the repo. Make a BEFORE tree (bash ${MKS} shotbase-${p.key} claude/mmo-overhaul) and an AFTER tree (bash ${MKS} shotnew-${p.key} ${p.branch}${p.hooks ? ' ' + p.hooks : ''}); take 3-6 matched windowed shots of the scenes this package changes (same scene, camera, resolution, renderer; 1600x900 gl_compatibility and Forward+, 844x390 for HUD/touch) into ${SP}/review/${p.key}/shots/; open each to confirm it shows the scene. Return the pairs with absolute paths.`

const judgePrompt = (pairs) => `You are a blind art director for a dinosaur survival game aiming at ARK: Survival Ascended / AAA quality with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same view from two builds; you are NOT told which is newer; ignore file names and paths. Open both with the Read tool and judge which looks better as a shipped game: lighting and exposure, contrast and depth, materials, readability of silhouettes, icons and UI, information hierarchy, composition, and visible defects (clipping, overlapping text, blown highlights, floating or sunken objects, placeholder art). Pick first, second or tie per scene with concrete reasons.
${pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`

const syncPrompt = (p, attempt, forced) => `${ctx(p)}

ROLE: implementer of ${p.label}, SYNC step ${attempt} before integration. The package passed review; packages ahead of it may have landed since (see git log claude/mmo-overhaul and the "## Merge log" at the end of docs/orchestration/mmo/STATUS.md on claude/mmo-overhaul).
Merge claude/mmo-overhaul into ${p.branch} in ${p.wt}. ${forced ? 'Code changed since the last review (an integration fix): run the full gates below even if the merge is a no-op.' : `If the branch already contained the base${p.hooks ? ' and git -C ' + BASE + ' apply --check <the hooks patch> is clean' : ''}, return up_to_date_before=true, code_changed=false, gates_pass=true without running gates.`} Otherwise resolve conflicts keeping both sides' intent (never drop a merged package's work), adapt the package to what landed (for example instances instead of stacks after W2-INV, skill node ids and the bonded-cap function after W2-SKILLS, the pack-up guard after W2-PROCESS), regenerate the hooks patch (apply-clean on the new base), commit, then in a scratch tree with the hooks (bash ${MKS} sync-${p.key} ${p.branch}${p.hooks ? ' ' + p.hooks : ''}) run every gate (every t_*.gd, run_all, smoke, the package's labs) and fix what fails; commit. code_changed=true if you changed anything beyond a conflict-free merge and the regenerated patch. Return the fields.`

const integratePrompt = (p, attempt) => `Project: DEADFRONT (Godot 4.7.1 typed GDScript, game/ is the project). You are the INTEGRATOR, the only agent that changes claude/mmo-overhaul (work tree ${BASE}) and pushes. Integration attempt ${attempt} for ${p.label} (branch ${p.branch}), which passed independent review${p.visual ? ' and a blind A/B judge' : ''} and was synced with the base. Owner approvals recorded: ${p.approved || 'none needed'}.${p.intNote ? '\nPACKAGE NOTE: ' + p.intNote : ''}
${RULES}

Procedure (the integrator is serialized: nobody else merges while you run):
1. Scratch: if ${INT} does not exist run: bash ${MKWT} int. Ensure ${INT}/game/override.cfg exists (custom user dir). git -C ${INT} reset --hard; git -C ${INT} checkout -B claude/mmo-int claude/mmo-overhaul (claude/mmo-int is scratch).
2. Merge: ${p.intNote ? 'as the package note says' : `git -C ${INT} merge --no-ff ${p.branch}`} with a message "Merge ${p.label}: <one line of what it gives the player> (<review round> pass${p.visual ? ', blind A/B <wins>' : ''})" and the trailer. Resolve conflicts correctly (both sides' intent), never by dropping a package's work.
3. ${p.hooks ? `Apply the hooks patch ${p.hooks} from the merged tree (git apply --3way; fix trivial drift yourself; a hook that cannot work is a failure) and commit "Apply ${p.label} integrator hooks".` : 'No hooks patch.'} Register the package's tests/labs where the report asks (run_all.gd is integrator-only).
4. --import (alarm 900). Gates through gslot from ${INT}: EVERY game/tests/t_*.gd; run_all.gd ([tests] PASS); tools/smoke.sh --no-import (SMOKE PASS); --lab=island_lab headless (exit 0, zero SCRIPT ERROR lines, node/creature counts as before unless the package intends a change); --lab=build_lab; the package's own labs; a creature lab grep for "couldn't resolve track" (must be 0); no new ~/Library/Logs/DiagnosticReports/Godot-*.ips during your run. Merging two green packages can go red: every t_*.gd, every time.
5. Pixels: windowed --lab=home_lab --shot-delay=6 at 1600x900 in Forward+ and gl_compatibility, 844x390 gl_compatibility, plus the package's own scene if it is visual; save under ${SP}/int/${p.key}-a${attempt}-*.png; LOOK at each; compare with earlier shots in ${SP}/int/ and ${OSP}/int/. A visible regression (blown light, missing HUD, broken layout, floating objects) is a failure.
6. A failure caused by the merge itself (conflict resolution, a hook) you fix in ${INT} and rerun. A failure caused by the package: do NOT fast-forward; return merged=false with failures (severity, where, problem, fix).
7. On success: in ${BASE}, move any untracked files that would block the fast-forward to ${SP}/moved-imports/ (never delete), then git -C ${BASE} merge --ff-only claude/mmo-int (if the base moved, merge it into claude/mmo-int, rerun run_all and smoke, and fast-forward again). Append one line to the "## Merge log" section at the end of ${BASE}/docs/orchestration/mmo/STATUS.md: "- $(date +%F) merged ${p.label} (<short sha>): <decisive gate lines>; review <round> pass${p.visual ? '; blind A/B <a>/<b>' : ''}; pending: <none or list>" and commit it in ${BASE}. Push: git -C ${BASE} push origin claude/mmo-overhaul, and git -C ${REPO} push origin ${p.branch}. Then refresh the owner's folder: if git -C ${OWNER} status --porcelain --untracked-files=no prints nothing, git -C ${OWNER} pull --ff-only (never run Godot there); otherwise leave it and say so.
Return merged, sha, pushed, owner_pulled, gates (decisive lines), pending, failures, shots, summary.`

// Integration is one-at-a-time across every lane.
let lock = Promise.resolve()
const withLock = (fn) => { const run = lock.then(fn); lock = run.catch(() => null); return run }

async function runJudge(p, pairs, tag) {
  for (let t = 1; t <= 2; t++) {
    const j = await agent(judgePrompt(pairs), { label: `judge:${p.key}:${tag}${t > 1 ? '-' + t : ''}`, phase: 'Judge', schema: JUDGE_SCHEMA })
    if (j) {
      let aw = 0, bw = 0
      j.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      j.afterWins = aw; j.beforeWins = bw
      return j
    }
  }
  return null
}

async function reviewLoop(p, start, max, mode, sinceSha, tag) {
  let last = null
  for (let round = start; round <= max; round++) {
    const rtag = `${tag || ''}${mode === 'delta' ? 'd' : 'r'}${round}`
    const rv = await agent(reviewPrompt(p, round, mode, sinceSha), { label: `review:${p.key}:${rtag}`, phase: mode === 'delta' ? 'Sync' : 'Review', schema: REVIEW_SCHEMA, effort: 'high' })
    if (!rv) return { passed: false, cut: true, stage: 'review', last }
    let pass = rv.pass
    const findings = (rv.findings || []).slice()
    let judge = null
    let pairs = rv.pairs || []
    if (pass && p.visual && !pairs.length && mode === 'full') {
      const sh = await agent(shotsPrompt(p), { label: `shots:${p.key}:${rtag}`, phase: 'Judge', schema: PAIRS_SCHEMA })
      pairs = (sh && sh.pairs) || []
    }
    if (pass && p.visual && pairs.length) {
      judge = await runJudge(p, pairs, rtag)
      if (!judge) return { passed: false, cut: true, stage: 'judge', last }
      if (judge.afterWins <= judge.beforeWins) {
        pass = false
        findings.push({ severity: 'major', where: 'blind A/B judge', problem: `A blind judge did not prefer the new build (new ${judge.afterWins}, old ${judge.beforeWins}). ${judge.overall} Per scene (first/second order flips each scene; scene i odd => first is NEW): ${JSON.stringify(judge.verdicts)}`, fix: "Address the judge's concrete reasons so the new build clearly wins every scene." })
      }
    }
    last = { round, mode, reviewed_sha: rv.reviewed_sha, summary: rv.summary, findings, judge: judge ? { afterWins: judge.afterWins, beforeWins: judge.beforeWins, overall: judge.overall } : null, unmet: (rv.acceptance || []).filter(a => !a.met) }
    if (pass) return { passed: true, last }
    if (round === max) return { passed: false, last }
    const fx = await agent(fixPrompt(p, findings, 'review'), { label: `fix:${p.key}:${rtag}`, phase: mode === 'delta' ? 'Sync' : 'Review', schema: WORK_SCHEMA })
    if (!fx) return { passed: false, cut: true, stage: 'fix', last }
    if (fx.owner_gate) return { passed: false, owner_gate: fx.owner_gate, last }
  }
  return { passed: false, last }
}

async function prepare(p) {
  const w = await agent(workPrompt(p), { label: `work:${p.key}`, phase: 'Work', schema: WORK_SCHEMA })
  if (!w) return { passed: false, cut: true, stage: 'work' }
  if (w.owner_gate) return { passed: false, owner_gate: w.owner_gate, stage: 'work', work: w.summary }
  return reviewLoop(p, p.startRound, p.startRound + 2, 'full', null, '')
}

async function land(p, prep) {
  if (!prep || !prep.passed) return { merged: false, reason: !prep ? 'no result' : prep.owner_gate ? 'owner gate: ' + prep.owner_gate : prep.cut ? 'cut' : 'review not passed', cut: !!(prep && prep.cut) }
  let reviewedSha = prep.last && prep.last.reviewed_sha
  let dirty = false
  for (let attempt = 1; attempt <= 3; attempt++) {
    const sy = await agent(syncPrompt(p, attempt, dirty), { label: `sync:${p.key}:a${attempt}`, phase: 'Sync', schema: SYNC_SCHEMA })
    if (!sy) return { merged: false, reason: 'cut', cut: true }
    if (sy.owner_gate) return { merged: false, reason: 'owner gate: ' + sy.owner_gate }
    if (dirty || sy.code_changed || !sy.gates_pass) {
      const dr = await reviewLoop(p, 1, 2, 'delta', reviewedSha, `a${attempt}`)
      if (!dr.passed) return { merged: false, reason: dr.cut ? 'cut' : dr.owner_gate ? 'owner gate: ' + dr.owner_gate : 'delta review not passed', cut: !!dr.cut, last: dr.last }
      reviewedSha = dr.last.reviewed_sha
    }
    const ir = await withLock(() => agent(integratePrompt(p, attempt), { label: `integrate:${p.key}:a${attempt}`, phase: 'Integrate', schema: INT_SCHEMA, effort: 'high' }))
    if (!ir) return { merged: false, reason: 'cut', cut: true }
    if (ir.merged) return { merged: true, integration: ir }
    if (attempt === 3) return { merged: false, reason: 'integration failed', integration: ir }
    const fails = (ir.failures && ir.failures.length) ? ir.failures : [{ severity: 'blocker', where: 'integration', problem: ir.summary, fix: 'Make the package pass every gate on the merged tree.' }]
    const fx = await agent(fixPrompt(p, fails, 'integration'), { label: `fix:${p.key}:int${attempt}`, phase: 'Sync', schema: WORK_SCHEMA })
    if (!fx) return { merged: false, reason: 'cut', cut: true }
    if (fx.owner_gate) return { merged: false, reason: 'owner gate: ' + fx.owner_gate }
    dirty = true
  }
  return { merged: false, reason: 'integration failed' }
}

const prepared = {}, prepResolve = {}, landed = {}, landedResolve = {}
PKGS.forEach(p => {
  prepared[p.key] = new Promise(res => { prepResolve[p.key] = res })
  landed[p.key] = new Promise(res => { landedResolve[p.key] = res })
})
const results = {}
const record = (k, prep, l) => {
  results[k] = { label: byKey[k].label, merged: !!l.merged, reason: l.reason || '', sha: l.integration ? l.integration.sha : '', pushed: l.integration ? l.integration.pushed : false, owner_pulled: l.integration ? l.integration.owner_pulled : false, pending: l.integration ? l.integration.pending : [], int_summary: l.integration ? l.integration.summary : '', review: (l.last || (prep && prep.last)) || null }
  landedResolve[k](l)
  log(`${byKey[k].label}: ${l.merged ? 'MERGED ' + (l.integration.sha || '') : 'not merged (' + (l.reason || '') + ')'}`)
}

// Fix/review runs 6 packages at a time (5 Godot slots are the real limit), in merge-priority order.
const POOL_ORDER = ['w2-data', 'w2-skills', 'w2-inv', 'w2-process', 'econ', 'w2-gather', 'w2-buildsys', 'w2-ragdoll', 'icons2']
const queue = POOL_ORDER.slice()
async function worker() {
  while (queue.length) {
    const k = queue.shift()
    const r = await prepare(byKey[k]).catch(e => ({ passed: false, error: String(e) }))
    prepResolve[k](r)
  }
}

// The owner's merge order; a later package lands only after the one ahead has landed or failed.
const ORDER = ['w2-data', 'w2-skills', 'w2-inv', 'w2-process', 'w2-gather', 'w2-buildsys', 'econ']
async function landChain() {
  let stopped = false
  for (const k of ORDER) {
    const prep = await prepared[k]
    if (stopped) { record(k, prep, { merged: false, reason: 'chain stopped after a usage cut' }); continue }
    const l = await land(byKey[k], prep).catch(e => ({ merged: false, reason: 'error: ' + String(e) }))
    record(k, prep, l)
    if (l.cut) { stopped = true; log('Merge chain stopped: an agent was cut (usage limit?). Resume the run.') }
  }
}
async function landPolish(k) {
  const prep = await prepared[k]
  const l = await land(byKey[k], prep).catch(e => ({ merged: false, reason: 'error: ' + String(e) }))
  record(k, prep, l)
}
async function forgeChain() {
  const d = await landed['w2-data']
  if (!d || !d.merged) { prepResolve.forgeart(null); record('forgeart', null, { merged: false, reason: 'W2-DATA did not merge' }); return }
  const prep = await prepare(byKey.forgeart).catch(e => ({ passed: false, error: String(e) }))
  prepResolve.forgeart(prep)
  await landPolish('forgeart')
}

const pool = parallel(Array.from({ length: 6 }, () => () => worker()))
await parallel([() => pool, () => landChain(), () => landPolish('w2-ragdoll'), () => landPolish('icons2'), () => forgeChain()])
return results
