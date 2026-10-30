# AI studio workflow: audit and integration plan

Thread "Upgrade the AI game dev workflow", 2026-10-30. Branch `claude/mmo-studio-doc`, cut from
`claude/mmo-overhaul` at `fc08395e`. Not merged. Audit only: no game code, data, tests, CI or
existing docs were changed. The only additions on the branch are this report and four proposed
skills under `.claude/skills/` (section 10.1).

Inspiration read as untrusted material: the Iron Curtain Call workflow as Milan described it,
google/elephant-goldfish-model (EGM, Apache-2.0), Donchitos/Claude-Code-Game-Studios (CCGS, MIT), and a
video transcript on the Claude Code team's review process that Milan shared at 17:10 (section 2.1).

Status labels used throughout:
**HAVE** already implemented · **PARTIAL** partly there · **MISSING** · **NOT NOW** unnecessary at
our scale · **INVESTIGATE** needs a measurement or decision first.

## Summary

We are already running most of the Iron Curtain Call workflow. GAUNTLET.md is a lead/feature-branch/
headless-test/independent-review/serialized-integrator loop, there are 160 headless test scripts,
two bots that play the real game (`bot_survivor.gd`, `tutorial_bot.gd`), ~100 deterministic labs,
save fixtures with migration goldens, and a wiki that keeps vision, current state, open questions and
evidence apart. The problems are not missing systems. They are:

1. **The process docs are stale.** GAUNTLET.md and AGENTS.md still route work to DeepSeek, Codex and
   Cursor, and point at `docs/orchestration/mmo/HANDOFF.md`, which does not exist. There is no
   `CLAUDE.md`, so Claude Code sessions only get the rules when a prompt says to read them.
2. **No automated gate runs on the integration branch.** GitHub CI last ran on `claude/mmo-overhaul`
   on 2026-10-23 (315 merges ago) and only ever ran `run_all.gd` + smoke, not `all_tests.sh`. Every
   gate today is the build thread's discipline on Milan's Mac.
3. **Tests can pass while the game logs script errors.** `all_tests.sh` only requires exit 0 plus a
   PASS line; just 5 of 160 tests count SCRIPT ERRORs themselves.
4. **No machine-readable test report and no retry budget.** Failures are summarized as one line;
   nothing stops an agent looping.
5. **Design review before building is informal.** The independent review happens after the code.

The plan: refresh the docs, add one gate script with a JSON report, wire CI to the integration
branch, add a fresh-context design review step, and pilot it on one small, real spec gap
(**taming pen feeding by diet**, section 8). No new permanent agents, no hooks, no CCGS framework.

---

## 1. Current workflow audit

### 1.1 People and sessions (from project memory and STATUS.md)

| Role | Who today | Status |
|---|---|---|
| Creative direction, gates, fun | Milan (species, saves, money, deploy, merge to main, visual direction) | HAVE |
| Lead + integrator | Mac Remote Control thread "Build the game along the roadmap": plans, spawns Opus 5.5 subagents in worktrees, reviews, merges one at a time, pushes when green | HAVE |
| Implementers | Opus subagents in Mac worktrees; cloud Opus thread on `claude/mmo-*-opus` (own Linux Godot, push only) | HAVE |
| Relay | Project coordinator (the two build threads cannot message each other) | HAVE (cost: every handoff is a hop) |
| Doc writers | One cloud thread per design memo, writes `docs/design/` on `claude/mmo-*-doc` | HAVE |
| Retired 10-30 | DeepSeek `dsc`, GLM; Codex never | docs not updated (1.6) |

### 1.2 Process documents

| File | What it does | Status |
|---|---|---|
| `GAUNTLET.md` | 13-step loop: translate, ground, classify risk (FABLE-CRITICAL / OPUS-SAFE), reproduce first, implement narrowly, prove behaviour, prove appearance, independent review + blind A/B, test-merge then integrate, deploy only on Milan's word. Integrator-only files listed. | HAVE, but stale in places (1.6) |
| `AGENTS.md` | Agent ownership table and house rules (`# ASSUMPTION:`, reports per task, smoke before done) | PARTIAL: table describes the Cursor/Codex era |
| `docs/agent-context.md` | Feature entry point: per system, the vision section, current page, code and tests | HAVE (some rows out of date) |
| `docs/wiki-maintenance.md` | Separates current / vision / proposal / archive; evidence; experiments; milestones | HAVE |
| `docs/orchestration/mmo/plan-register.md` | Gap register and package file ownership (1,623 lines, dated 10-18) | PARTIAL: old |
| `docs/orchestration/mmo/STATUS.md` | Owner decisions + merge log; marked archive on 10-29, top section refreshed 10-30 | HAVE |
| `docs/orchestration/reports/` | 203 per-package reports | HAVE |
| `.claude/skills/wiki-steward` | Audit / reconcile / capture / experiment / scope for the wiki | HAVE (landed 10-29) |
| `CLAUDE.md` | — | MISSING |
| `.claude/settings.json`, hooks, `.claude/agents/` | — | MISSING (and mostly NOT NOW, see 3.3) |
| `.cursor/rules/durango.mdc` | Cursor-era rules pointing at an archived plan | stale |

### 1.3 Wiki

`tools/docs_wiki` serves `docs/current` (22 system pages, each fact cites a file), `docs/vision`
(owner-confirmed vs workshop proposal labels, Open Questions register), and the Roadmap tab
(`phase-map.json`, plan of record). `phase_map.py audit` lists buildable / blocked / done-without-
evidence rows; `check` validates sources and evidence paths. Eight Python test suites cover the wiki
tools. The 10-30 refresh marked 28 packages done with evidence. **HAVE.** The prior assessment
(`claude-wiki-steward.md`) already covered the wiki in depth; this report does not redo it.

### 1.4 Testing and verification tools

| Tool | What it checks | Status |
|---|---|---|
| `tools/all_tests.sh` | Runs every `game/tests/t_*.gd` headless, 4 in parallel, own HOME per test, per-test timeout, PASS/FAIL summary, logs dir. Subset by name. | HAVE |
| 160 `t_*.gd` | Systems from AI, combat, gather, crafting, inventory, bags, durability (knife split), hunger, taming odds, tribe, tutorial, saves, islands, landmarks, perf gates, UI layout | HAVE |
| `t_save` + `tests/fixtures/` | Golden saves v0-v3, stacked→instance migration, truncated/forged/future saves, field-for-field round trip, own ErrorCounter | HAVE (strong) |
| `tools/smoke.sh` | Main scene boots, player on the floor after 2 s | HAVE |
| `tools/test.sh` | import + `run_all.gd` (older aggregate) | HAVE (used by CI) |
| `game/scripts/dev/*lab.gd` (~100) | Deterministic labs, many with screenshots; `--lab=creature_lab`, `map_lab`, weather flags | HAVE |
| `bot_survivor.gd` (`-- --bot`) | Plays the early loop through real entry points: gather, craft knife→club→axe→pick, build fire/bench/basket, hunt, cook, net, tame, sail, return, grind. Each rung OK / BLOCKED / TIMEOUT with a closing report. | HAVE |
| `tutorial_bot.gd` (`-- --tutorial-bot`, driven headless by `t_tutorial`) | Plays every tutorial order with real actions, 3 tries per order, presses Receive in the Task screen, captures shots windowed | HAVE |
| `tools/ui_screens.sh` | Screenshots every UI screen at 844x390 (windowed) | HAVE |
| Quickstart / character-creation skip flags | Agent runs drop straight into the world | HAVE |
| `t_perfgates`, `perf_lab`, `tutperf_probe` | Node/tick budgets, build time | HAVE (Mac-only timings) |
| `.github/workflows/ci.yml` | export payload guard, `tools/test.sh`, smoke; on PRs and pushes to `main` | PARTIAL (1.5) |
| `tools/production_soak.mjs`, `web_soak` | Deployed web route soak | HAVE (deploys on hold) |

### 1.5 Git and CI as they actually run

- One integration branch, one branch per package, serialized integrator: **HAVE**. 315 merges into
  `claude/mmo-overhaul` since 10-23. 311 `claude/mmo-*` branches on GitHub (merged ones are never
  deleted; harmless on GitHub, but they bury live work).
- Worktrees on the Mac for parallel subagents: **HAVE**. Each worktree carries the 1.1 GB
  `game/assets` checkout plus its own `.godot` import cache; disk hit 92% on 10-30. Agents cannot
  delete worktrees (permission guard); Milan runs cleanup scripts.
- CI: runs on `pull_request` and pushes to `main` only. Draft PR #17 (`claude/mmo-overhaul` → `main`)
  was the only trigger for the integration branch; its last run was 2026-10-23. **INVESTIGATE:** the
  likely cause is that PR #17 no longer merges cleanly into `main` (GitHub skips `pull_request` runs
  for unmergeable PRs). The two most recent runs (10-28, 10-29) were on archive branches and failed.
  CI pins Godot 4.7.0; the docs say 4.7.1.

### 1.6 Discrepancies found (flagged, not fixed)

| # | What the docs say | What is true | Owner |
|---|---|---|---|
| D1 | GAUNTLET.md and project memory: read `docs/orchestration/mmo/HANDOFF.md` | Missing on `claude/mmo-overhaul`; root `HANDOFF.md` describes 2026-09-21 state | build thread |
| D2 | GAUNTLET step 5 + "DeepSeek workers" section, AGENTS.md tools section, `.cursor/rules` | dsc/GLM retired 10-30 (Milan), Codex never, Cursor no longer used | build thread |
| D3 | Spec 02: "Diet groups herbivore/carnivore/omnivore; validate food items and consume them exactly once" (pen feeding) | `TamingPen.feed` accepts only `raptor_meat` for every species, including the herbivore first tame Zebraceratops whose data lists `preferred_food: berry, herb_leaf`; UI says "Needs raptor meat" (`game/scripts/world/taming_pen.gd:199`, `taming_pen_ui.gd:385`) | design + build (pilot candidate) |
| D4 | Roadmap `shape-consumers` status `next` | Its note says "folded into country-islands", which Milan closed 10-30 | wiki steward |
| D5 | `docs/agent-context.md`: "current page pending" for inventory, creatures/taming, saves | `docs/current/inventory-bags.md`, `creatures-capture-taming.md`, `saves-persistence.md` exist | wiki steward |
| D6 | `.gitignore` ignores `.dsc-task/` | `.dsc-task/TASK.md` (84 commits since 10-23) and `.dsc-broken-1854/` are tracked | build thread |
| D7 | GAUNTLET: CI/`test.sh` + smoke as the release gate | Real gate is `all_tests.sh` on the Mac; CI does not run it | this plan |

---

## 2. Gap analysis against the Iron Curtain Call practices

| Practice | Us | Status | Gap |
|---|---|---|---|
| One lead session coordinating | Build thread | HAVE | Lead also integrates and reviews, so it is the bottleneck (see 3) |
| Specialized feature sessions in parallel | Opus subagents + cloud Opus thread | HAVE | No written check that two packages don't share hot files before they start |
| One branch per workstream | `claude/mmo-<key>` | HAVE | Merged branches never pruned |
| Agents build from human-authored design docs | `docs/design/`, Durango prompts, vision | HAVE | No per-package brief that quotes the binding lines and lists open questions; agents re-derive it each time |
| Headless tests before merge | `all_tests.sh`, smoke, labs, run by the integrator | PARTIAL | Not enforced by anything but discipline; no CI on the integration branch |
| Script error checks | Smoke greps errors; 5 tests count them | PARTIAL | `all_tests.sh` passes a test that logs SCRIPT ERRORs; no parse-all-scripts check |
| Level navigation / geometry checks | `t_islandgen`, `t_landmarks`, `t_pathcache`, `t_northup`, island shape gates | PARTIAL | No single sweep "every island: dock reachable on foot, spawn on dry land, nodes not in water" |
| Bot playthroughs | `bot_survivor`, `tutorial_bot` | HAVE | Bot asserts that rungs complete, not the state deltas along the way (inventory counts, durability, HP); not run on every merge; no save→reload mid-run |
| Humans own feel, levels, fun, story | Milan's gates, `# ASSUMPTION`, "is it fun?" yardstick | HAVE | Merge reports do not separate "tests passed" from "Milan played it" |
| Bugs via reproducible tests and measurements | GAUNTLET step 4 | PARTIAL | No retry budget or stop rule; no standard failure report |

### 2.1 Second input: the Claude Code team's review workflow (Milan, 17:10)

Milan added a video transcript describing how the Claude Code team checks agent work (evals before
building, a separate reviewer, capped fix loops). Read as inspiration, mapped onto what we have:

| Idea | Us today | Status | Proposal |
|---|---|---|---|
| Per-feature spec folder: requirements doc + eval file written before building | Roadmap row + design doc; acceptance lives in prompts and reports | PARTIAL | The `package-brief` acceptance table *is* the eval file: every item names a test that can fail. One file per package in `docs/orchestration/briefs/`, no second spec tree. |
| Milan reviews the evals before any build | Milan sets direction; no small questions | PARTIAL, by choice | Only for new features with `HUMAN:` items or a Milan gate: the lead posts the brief's acceptance list once, as one message; build proceeds on the recommended reading meanwhile (reversible). Tuning-level briefs do not wait. |
| Mockup before UI work, checked at desktop and phone size | UI spec, Durango references, 1600x900 + 844x390 shots, blind A/B (GAUNTLET 7-8) | PARTIAL | For brand-new screens only: a static mockup (HTML or a lab scene) Milan approves before the Godot build. Existing screens keep the A/B loop. |
| Hook that blocks "done" until evals pass | Discipline + GAUNTLET step 6 | MISSING, deliberately | NOT NOW as a hook: a repo Stop hook fires in every session (doc threads, the coordinator's tools) and Godot runs take minutes. Instead `merge-gate` refuses without the gate output, and implementers must paste `tools/gate.sh quick`'s verdict line in their report. Revisit a worktree-scoped hook after the pilot. |
| Separate reviewer, never the builder | GAUNTLET step 8 says so; in practice often the lead | PARTIAL | `goldfish-review` (fresh subagent, read-only). The built-in `/code-review` command can be the branch-mode reviewer for code bugs. |
| `review.md` rules file linked from CLAUDE.md, "rules learned" grows only on approval | GAUNTLET binding rules, STATUS owner decisions; no CLAUDE.md | MISSING | `docs/review.md` (what breaks for a player in this game: saves, item ownership, capture rolls, wear, hot files) linked from a new `CLAUDE.md`; a "Rules learned" section the lead appends to only after Milan or the lead approves a recurring finding. |
| Build → verify → review loop with a state file, 3-5 round cap, round 2+ re-checks only the latest fixes, reviewer names the *kind* of problem | Package report as state; no cap | PARTIAL | Cap 3 rounds per gate (in `merge-gate` and `repro-bug`); the round count and each round's findings go in the package report; `goldfish-review` round 2+ re-checks only the fixes and names the problem class so the builder sweeps for siblings. |
| Risk classifier ("what happens to the player if this breaks") sets review depth | FABLE-CRITICAL / OPUS-SAFE in GAUNTLET step 3 | HAVE | Tie depth to it: OPUS-SAFE = one reviewer; FABLE-CRITICAL (saves, economy, capture, inventory ownership, combat/progression) = two reviewers + save round trip. |
| First-time-user agent that cannot read the code and plays a new build | `tutorial_bot` plays every order, but it is code that knows the internals | MISSING | INVESTIGATE: a windowed "fresh player" agent on the Mac that only sees screenshots and presses keys/clicks (computer use), given only the store-page pitch, reporting where it got stuck. Good for the tutorial; costly per run, so per milestone, not per merge. |
| Fix-a-bug skill: reproduce first, then fix | GAUNTLET step 4 | PARTIAL | `repro-bug` skill (on this branch). |
| One branch per feature, working versions saved for rollback | `claude/mmo-<key>`, merge shas in STATUS/roadmap evidence | HAVE | Nothing new; the merge sha in each roadmap row is the rollback point. |

Net effect: the video's loop is mostly GAUNTLET plus the wiki-steward evidence rules, made explicit.
The real additions are `docs/review.md` + `CLAUDE.md`, the round cap with problem-class findings,
and the fresh-player agent as an experiment.

---

## 3. Proposed architecture

### 3.1 Roles: four, not five, and no new permanent agents

| Role | Runs as | Combines | Status |
|---|---|---|---|
| **Lead / integrator** | The existing build thread (one session, serialized merges) | Orchestrator + integration reviewer's merge decision | HAVE, keep |
| **Implementers** | Opus subagents in worktrees, the cloud Opus thread; 1-3 at a time | Implementation + writing their own failing tests first (QA "author" role) | HAVE, keep |
| **Fresh reviewer ("goldfish")** | A read-only general-purpose subagent spawned per check, never the author, no conversation history | Game design reviewer (before code) + QA/integration reviewer (before merge) | PARTIAL → new skill `goldfish-review` |
| **Milan** | Thread messages, play sessions | Creative director, final acceptance | HAVE |

Why combine: a permanent QA agent and a permanent design agent would each need the full context the
lead already holds, and would mostly wait. A fresh subagent per check costs one agent call, has no
stale context, and is the "who did not write it" reviewer GAUNTLET step 8 already demands. Keeping
the integrator in the lead thread preserves the one-merger rule that keeps conflicts sane.

What the lead stops doing itself: re-reading every diff in full context. It reads the goldfish
findings and the gate output instead.

### 3.2 Flow per package

```
Milan ask / roadmap row
  -> package-brief        (lead; quotes canon, lists open questions, owned files, tests, budget)
  -> goldfish-review design (fresh subagent; blockers stop here, Milan gets one question if needed)
  -> implement            (implementer on claude/mmo-<key>; failing test first; repro-bug on trouble)
  -> gate quick           (implementer runs it before saying done)
  -> goldfish-review branch (fresh subagent; reruns new tests on base and branch)
  -> merge-gate           (lead: scratch merge, full gate, three verdicts, push if green)
  -> docs status          (docs/current page, roadmap evidence, open questions; vision untouched)
  -> Milan plays          (HUMAN: items; only then "verified")
```

### 3.3 What we do not adopt

| From | Item | Verdict |
|---|---|---|
| CCGS | 49 agents, 3 director tiers, 74 skills, 62 templates, sprint/epic/story files, `project.yaml`, `production/` tree | NOT NOW: built for teams starting from nothing; we already have a roadmap, design docs and reports. Its skills call its own `yaml-helper.sh` and config, so none of them run here unmodified. |
| CCGS | 15 hooks (commit/push/write validators, session logs, gap detection) | NOT NOW: each runs on every tool call; `update-check.sh` calls the GitHub API from every session. Revisit one narrow hook later (10.4). |
| CCGS | Godot engine-specialist agents | NOT NOW: the project's own conventions (GAUNTLET architecture section) are more specific than a generic Godot persona. |
| CCGS | `godot-parse-check.gd` idea: load every script after `--import` and fail on any that cannot instantiate (works where `--check-only` fails on autoloads) | ADOPT as an idea in our own tool (10.2) |
| EGM | Elephant (context-holder drafts) / Goldfish (zero-context reviewer) | ADOPT, adapted: `goldfish-review` |
| EGM | Five-stage review with nine personas and interactive single-question gates; brainstorm → draft → review → resolve chain | NOT NOW: 5-9 agent calls per review and a question gate at each stage clash with Milan's async, no-small-questions style. Could be worth it for one big decision doc (full 3D). Installing the EGM plugin user-level on the Mac is an option Milan can take; it is not vendored here. |
| EGM | `egm-drift-report` (docs vs code) | Already covered by `wiki-steward audit` |

---

## 4. Parallel development strategy

**Worktrees vs branches.** Keep worktrees for Mac subagents (HAVE): they let several agents build
and run Godot at once without stepping on one checkout. Ordinary branches in one directory would
force agents to take turns. The cost is disk: ~1.1 GB of assets plus an import cache each.
Recommendation: cap concurrent Mac worktrees at 3, and give the lead permission to run
`git worktree remove` on merged package worktrees (Milan decides whether to allow that one command;
today he runs cleanup by hand). **PARTIAL.**

**Local vs cloud.** Cloud Opus thread for logic packages that are judged by headless tests (no Mac
disk, no window). Mac for anything visual, perf-timed, or needing Godot windows. Never both on the
same files. **HAVE**, keep.

**File ownership.** Hot files since 10-23, by commits: `hunt_hud.gd` 61, Open Questions 38,
`docs/current/hud.md` 36, `player_sim.gd` 29, `creature.gd` 28, `phase-map.json` 26,
`anim_events.json` 26, `player.gd` 24, `ai.json` 24, `save_sanitizer.gd` 23. Rule: two packages may
run at once only when their briefs' owned-file lists do not intersect, except for append-only data
rows and docs that the integrator reconciles. Integrator-only files stay hooks-in-report (HAVE in
GAUNTLET). Wiki files (`phase-map.json`, `docs/current`, Open Questions) are updated by the
integrator at merge time, not by packages, which removes most doc conflicts. **PARTIAL → brief.**

**Dependencies.** The roadmap's `depends` + `phase_map.py audit` already gives "buildable next".
The brief adds "conflicts with" (shared files with packages in flight). **HAVE / PARTIAL.**

**Handoffs.** Brief in, report out (`docs/orchestration/reports/claude-<key>.md`, HAVE). The cloud
thread and build thread exchange through the coordinator; giving them the brief path and the report
path instead of retyped context cuts relay size. **PARTIAL.**

**Integration order.** One integrator, smallest/most-depended-on first, rebase or merge the
integration branch into a package before its gate when it is behind (HAVE in practice).

**Concurrency and tokens.** Each extra concurrent implementer adds its own full-context run plus
review. With the integrator serialized, more than ~3 implementers mostly produces branches waiting
in line. Recommendation: 2-3 implementers, plus fresh reviewers as needed. **NOT NOW** for more.

---

## 5. Testing strategy

### 5.1 Technical tests

| Check | Status | How |
|---|---|---|
| Project loads | HAVE | `--import`, `smoke.sh` |
| Scripts compile | PARTIAL | Add parse-all step: load every `res://scripts/**/*.gd` after import (10.2) |
| No unexpected runtime errors | PARTIAL | `all_tests.sh` scans each log for `SCRIPT ERROR` / `Parse Error`; fail unless the test is on an explicit allowlist (10.2). Existing ErrorCounter pattern stays. |
| Regressions | HAVE | 160 tests; full suite on the Mac before every merge |
| Save/load consistent | HAVE | `t_save` goldens + migrations; `t_savefix`; add round trip inside scenario tests (5.3) |
| Perf budgets | PARTIAL | `t_perfgates`; Mac-only timings, advisory on Linux CI |

### 5.2 Gameplay scenario tests: what is feasible

| Scenario | Today | Status |
|---|---|---|
| Player spawns | smoke, `t_player`, `t_tutorial` | HAVE |
| Move and interact | `t_controls`, `t_movepriority`, bots | HAVE |
| Resources spawn by config | `t_landmarks`, `t_islandgen`, `t_biomeprops`, `t_unstable_isles` | HAVE (per system) |
| Gathering results | `t_gather`, `t_onegather`, `t_harvestroll`, `t_rareattr` | HAVE |
| Tool durability | `t_knifesplit`; wear-scaling/repair packages in flight now | PARTIAL (coming with those packages) |
| Crafting consumes materials | `t_craftfeel`, `t_outputs`, `t_uicraft` | HAVE (verify exact counts per recipe: INVESTIGATE) |
| Inventory accuracy | `t_inventory`, `t_bags`, `t_invslots` | HAVE |
| Creatures follow rules | `t_ai`, `t_tactical`, `t_styraco`, `t_swarm`, `t_alphas`, AI labs | HAVE (species brains each need their own) |
| Combat damage and death | `t_combat`, `t_death`, `t_roll` | HAVE |
| Building placement rules | `t_build`, `t_buildsys`, `t_buildflow`, `t_claims2` | HAVE (headless uses grid cells, not pointer) |
| End-to-end chain with state assertions + save/reload | Bots complete the chain but assert only rung success | PARTIAL → 5.3 |
| Feel, readability, fun, camera, animation quality | Labs + screenshots + A/B | needs human / graphical |

### 5.3 The headless player: extend what exists, do not build a new one

`BotSurvivor` already walks, gathers via the radial, crafts via `StationCraft`, hunts, builds through
the real `BuildPlacer` validation, and reports OK / BLOCKED / TIMEOUT. The missing piece is
**assertions on state deltas** and a **save→reload checkpoint**. Proposal (10.2): a small
`game/tests/scenario_kit.gd` that tests can use to (1) boot a seeded world on a named island,
(2) snapshot player state (bag counts by item id, tool durability, HP, bonded count), (3) run a
`BotSurvivor` step, (4) assert the exact delta, (5) save to a temp `user://`, reload, and compare the
snapshot. First scenario, `t_scn_first_loop`: gather wood and stone → craft Stone Dagger and Work Axe
→ gather with the axe (durability drops by the expected amount) → kill a compsognathus (HP and loot)
→ save/reload → snapshot equal. Milan's 10-step example maps onto this almost one to one; step 8
depends on the wear packages now in flight. **MISSING (small).** Determinism (seeded RNG per
system) needs checking system by system: **INVESTIGATE**; where a roll cannot be seeded, assert
ranges, not exact values.

---

## 6. Quality gates

Three verdicts, recorded separately by the `merge-gate` skill. Passing tests never mean "fun".

| Gate | Who | Pass means |
|---|---|---|
| **Technical** (automated) | `tools/gate.sh full` on a scratch merge | import OK; every script parses; every `t_*.gd` PASS; no new SCRIPT ERROR in any log; smoke PASS; `phase_map.py check` OK; brief's labs/bots green; no new crash report; save fixtures untouched unless Milan approved |
| **Design consistency** | `goldfish-review` (fresh subagent) | no Blockers; every requirement traces to canon; every `# ASSUMPTION` listed; no unbriefed gameplay/balance change; `docs/current` matches code; vision untouched |
| **Human gameplay** | Milan | `HUMAN:` items played and accepted; until then the row is merged, not verified |

Gate levels: `quick` (implementer, before "done": import, parse, smoke, the brief's tests, ~5 min);
`full` (integrator, before merge: everything above, ~15-25 min on the Mac); `visual` (when the brief
touches presentation: `ui_screens.sh` + lab shots at 1600x900 and 844x390 + blind A/B, as GAUNTLET
steps 7-8 already require).

CI (10.3): run `quick` plus `all_tests.sh` on every push to `claude/mmo-overhaul` on Linux, with
perf timings advisory. It is a second opinion and a record, not a replacement for the Mac gate. No
branch protection: the integrator pushes directly and Milan is the only human.

---

## 7. Wiki integration

The wiki already separates the four things Milan listed. The plan only wires the package flow into it:

| Moment | Action | Where | Status |
|---|---|---|---|
| Before | Brief quotes binding lines from vision/design, lists open questions | `docs/orchestration/briefs/<key>.md` | MISSING → `package-brief` |
| Before | Missing requirement: Milan gate → one question; else `# ASSUMPTION` default | brief + code | HAVE (rule), formalized |
| During | New conflict or ambiguity → appended to the brief, not silently decided | brief | MISSING |
| After | `docs/current/<system>.md` updated to what the code does, with file citations | integrator at merge | HAVE |
| After | Roadmap row `evidence`: merge sha + test path (+ Milan play note when it exists) | `phase-map.json` | HAVE (since 10-29) |
| After | Remaining gaps → Open Questions register | `docs/vision/WildLandsMMO_Open_Questions.md` | HAVE |
| Never | Rewriting `docs/vision/` to match code | — | HAVE (rule) |

Intended design = `docs/vision`, `docs/design`. Current implementation = `docs/current`.
Unresolved = Open Questions + brief. Verified = roadmap `evidence` + merge-gate verdicts.

---

## 8. Implementation roadmap

**Phase 0: housekeeping (docs only, ~1 hour, build thread).** Fix D1, D2, D5, D6; add a short
`CLAUDE.md` that points to AGENTS.md, GAUNTLET.md and `docs/agent-context.md`; mark retired workers.

**Phase 1: gate tooling (one package, `claude/mmo-gatekit`, ~half a day).** `tools/gate.sh`,
parse-all, error scan + JSON report in `all_tests.sh`, CI trigger on the integration branch
(10.2, 10.3). Prove it by planting a script error in a scratch branch and watching both the Mac gate
and CI fail.

**Phase 2: pilot (approval needed).** One feature through the whole cycle, below.

**Phase 3: scenario kit.** `scenario_kit.gd` + `t_scn_first_loop` once the durability packages land.

**Phase 4: review after ~5 packages.** Count: merges that later needed a fix, gate time, agent calls
per package, Milan's debugging asks. Keep what helped, drop what didn't.

### Pilot recommendation: taming pen feeding by diet (D3)

- **Why this one.** A real, small gap between canon and code: spec 02 says pen feeding validates diet
  and consumes food exactly once; the code feeds raptor meat to every species, so the herbivore
  first tame cannot be fed its own food. Species data already carries `preferred_food` and
  `accepted_food`, and field feeding (`apply_feed`) already values preferred 1.0 / accepted 0.5.
- **Dependencies are done:** capture rule, pens and tiers (STATIONSTATE), torpor capture
  (FOODTORPOR). Nothing in flight touches `taming_pen.gd` (the build thread is on durability, town
  polish, prop cards).
- **Coverage it buys:** inventory exact consumption, refusal of wrong diet with nothing consumed,
  timer effect, finished-pen refusal (existing `t_w2_skills` check), save/reload while taming,
  spoiled food handling.
- **Open questions it will surface** (good for the design-review step): how much a preferred vs
  accepted feed shortens the timer (today a flat ×0.6, itself an assumption); whether spoiled meat or
  Rot is refused; whether food quality/perks matter. Defaults would be marked `# ASSUMPTION` unless
  Milan wants to decide.
- **Human part:** the pen UI message and which foods it lists; Milan checks it reads clearly.
- **Size:** `taming_pen.gd`, `taming_pen_ui.gd`, `player_actions.gd` call site, one new
  `t_penfeed.gd`, `docs/current/creatures-capture-taming.md`. No save schema change expected
  (pen already saves `remaining`); the brief must confirm that.

Alternative if Milan prefers a non-creature pilot: **level-up flash** (LEVELFX, roadmap `next`,
paused branch exists), smaller but mostly visual, so weaker on automated coverage.

---

## 9. Estimated overhead

| Item | Cost | Notes |
|---|---|---|
| Brief per package | ~1 lead turn | Replaces context the lead already writes into subagent prompts |
| Goldfish reviews | 2 subagent calls per package (design + branch), 3-4 for FABLE-CRITICAL | Each reads the brief + diff, not the history; cheaper than a full-context review |
| Gate runtime | quick ~5 min, full ~15-25 min on the Mac (today's `all_tests.sh` at JOBS=4) | Already paid today; adds parse + scan (seconds) |
| CI | ~15-20 Actions minutes per integration push | **INVESTIGATE:** private-repo minute quota; with ~45 merges/day this could exceed the free tier. Option: CI on every Nth push or nightly instead. |
| Maintenance | 4 skill files + 1 script + CI yaml | Small; skills are plain text |

Failure modes to watch:
- **Ceremony creep:** briefs and reviews for one-line fixes. Rule: `repro-bug` only for those.
- **Review rubber-stamping:** a goldfish that always passes. Check its findings rate after 5 packages.
- **Flaky CI on x86** (`int(1e30)`, timing budgets): mark known Mac-only tests advisory, never skip them on the Mac.
- **False confidence:** green gates on a feature nobody played. The human verdict is separate on purpose.
- **Lead bottleneck:** if merges queue, add a second reviewer, not a second integrator.

---

## 10. Exact proposed changes

### 10.1 Installed on this branch (not merged)

| File | What | Source |
|---|---|---|
| `.claude/skills/package-brief/SKILL.md` | Brief template and steps (canon quotes, open questions, owned files, tests, budget) | Our own; idea from CCGS story/readiness |
| `.claude/skills/goldfish-review/SKILL.md` | Fresh-context read-only reviewer, design and branch modes, 1-2 agents, no question gates | Adapted from EGM's Elephant/Goldfish model |
| `.claude/skills/merge-gate/SKILL.md` | Three-verdict merge checklist and report block; retry stop | Our own; writes down GAUNTLET 6-9; idea from CCGS gate-check |
| `.claude/skills/repro-bug/SKILL.md` | Reproduce-first steps, measurement, failure report, retry budget | Our own; GAUNTLET step 4 |
| `docs/orchestration/reports/claude-studio-workflow.md` | This report | — |

Skipped: every CCGS skill, agent, hook and rule (framework-coupled, see 3.3); EGM's seven skills
and nine agents (interactive, token-heavy; optional user-level plugin install instead). No code
copied from either repo.

Note: `merge-gate` already asks the integrator to scan logs for SCRIPT ERROR by hand; 10.2 automates it.

### 10.2 Phase 1 package `claude/mmo-gatekit` (proposed, not built)

- `tools/gate.sh` (new): `quick | full | visual`. Wraps `--import`, parse-all, `all_tests.sh`
  (full set or the brief's subset), `smoke.sh --no-import`, `phase_map.py check`; prints one
  verdict line and the report path.
- `game/tests/parse_all.gd` (new, ~30 lines): loads every `res://scripts/**/*.gd`, prints
  `PARSE FAIL` per broken script, exits 1. Pattern from CCGS's parse check, written fresh.
- `tools/all_tests.sh` (modify): after each test, count `SCRIPT ERROR` / `Parse Error` lines and
  fail the test unless listed in `game/tests/error_allowlist.txt`; write `$LOGS/_report.json`
  (test, result, seconds, first error, log path, commit); print the last 30 lines of each failing log.
- `game/tests/error_allowlist.txt` (new): seeded from one baseline run so the change starts green.
- `docs/orchestration/briefs/` (new folder) for package briefs.

### 10.3 CI (proposed)

`.github/workflows/ci.yml`: add `push: branches: [claude/mmo-overhaul]` and a step running
`tools/all_tests.sh` with `TEST_TIMEOUT=300`, upload `_report.json` and failing logs as an artifact,
bump Godot to the version the Mac uses. Mark perf-timed tests advisory on Linux via an env flag the
tests already can read (INVESTIGATE which ones). Check first why PR #17 runs stopped (D7).

### 10.4 Docs (Phase 0, proposed)

- `CLAUDE.md` (new, ~15 lines): read order, gate command, Milan's gates, `# ASSUMPTION` rule,
  and a link to `docs/review.md` so `/code-review` and goldfish reviewers follow it.
- `docs/review.md` (new): what can go wrong for a player in this game and how to catch it (saves and
  migrations, item instance ownership, capture/tame rolls exactly once, wear and repair numbers,
  hot shared files, integrator-only files), plus a "Rules learned" section appended only on approval.
- `GAUNTLET.md`: replace dsc/Codex lines with the current roles; point step 3 to briefs, step 6 to
  `tools/gate.sh`, step 8 to `goldfish-review`; fix the HANDOFF path. Archive the DeepSeek section.
- `AGENTS.md`: current ownership table (lead/integrator, implementers, cloud thread).
- `docs/agent-context.md`: fix the "pending" rows (D5).
- Untrack `.dsc-task/` and `.dsc-broken-1854/` (D6).

### 10.5 Later, only if a need shows up

- One PreToolUse hook that refuses edits to integrator-only files on `claude/mmo-*` package
  branches. NOT NOW: the brief + branch review catches this without a per-call hook.
- Pruning merged `claude/mmo-*` branches on GitHub (311 today). Needs Milan's OK; harmless to leave.
- EGM plugin user-level install for big decision docs (e.g. full 3D). Milan's call.
- A Stop hook in implementer worktrees that refuses to end without a passing `gate.sh quick` (2.1).
- Fresh-player agent per milestone (2.1), run as an experiment with `docs/templates/experiment.md`.

### Commands

```
# Phase 1 proof (after gatekit lands)
tools/gate.sh quick                    # implementer, before "done"
tools/gate.sh full                     # integrator, scratch merge, before push
tools/all_tests.sh t_penfeed t_tame    # subset during the pilot
python3 tools/docs_wiki/phase_map.py audit
```

Nothing here starts without Milan's approval: Phase 0-1 are reversible tooling and docs; the pilot
is a gameplay change and waits for his go.
