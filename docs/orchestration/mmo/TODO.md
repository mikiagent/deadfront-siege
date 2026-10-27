# DEADFRONT to-do (2026-10-21)

What is left, in priority order, and what you need to read before starting each item. Production is
`a01e41ed3/5bf3729622` (https://durango-like.vercel.app). The integration branch is `claude/mmo-overhaul` (worktree
`~/Documents/deadfront-siege/.claude/worktrees/mmo-overhaul`); the owner's copy is `~/Documents/deadfront`.

## Context every item needs

- **Read first:** `docs/orchestration/mmo/STATUS.md` (owner decisions, merge log, releases, open questions) and
  `docs/orchestration/mmo/HANDOFF.md` (where everything is). Design truth: `docs/design/durango-prompts/` (specs 01-25)
  and `docs/prd/`. Answer design questions from those before asking the owner.
- **Owner rules:** merge into main only when the owner says; every production deploy needs the owner's "deploy" (the
  permission check blocks unattended deploys); anything that changes saves, money, multiplayer authority, species identity
  or a major visual direction needs the owner; no buying credits; Tripo for creatures/characters, Blender for props.
  Usage is tight: hand mechanical work to DeepSeek (dsc, see `dsc-coding-workers` in memory and
  `docs/orchestration/dsc-improvements.md`); Claude writes tasks, reviews diffs, integrates.
- **Running Godot:** only through `gslot.sh` (5 machine-wide slots) with a perl alarm; keep `game/override.cfg` (it
  isolates the test save); `--import` after merging assets or class_name files; labs, bakes and screenshots need a window
  (`--rendering-method gl_compatibility`), never `--headless`.
- **Gates for any merge:** every `game/tests/t_*.gd` (t_save prints 5 deliberate SCRIPT ERRORs), `run_all` `[tests] PASS`,
  `tools/smoke.sh --no-import` `SMOKE PASS`, windowed shots at 1600x900 and 844x390 looked at, and the motion gate (no HUD
  element, label or player position jumping between frames).
- **Ship:** `scratchpad/deploy/ship.sh <sha>` (export, headless-Chrome boot check, Vercel prod, stamp check); run with
  `NO_DEPLOY=1` until the owner says deploy.
- **Workflows:** launch or resume only from a turn about that work (a turn's message is relayed to every agent); scripts
  in `.claude/worktrees/deadfront-*.js`, copies in `docs/orchestration/mmo/handoff/workflows/`.

## 1. Ship blockers from the production playtest (DeepSeek, running)

Playtest evidence: STATUS "Releases" (af03937f entry) and the shots in the session scratchpad `shots/deploy-af03937f/`.
Each job: worktree `.claude/worktrees/mmo-<key>`, task `docs/orchestration/dsc/<key>-TASK.md`, verify
`scratchpad/dsc/verify_<key>.sh`, watch with `dsc cook status` in that worktree. Review the diff and rerun the gates before
merging. The 2026-10-21 audit (dsc-improvements.md) found task errors that change the brief:

| Key | What | Context the audit added |
|---|---|---|
| SKILLBUY | Skill nodes all say "not in the game yet" | It is a deliberate gate (`SkillRules.buyable`, spec 12:215): wire real effects, never flip the status; target unavailable <= half |
| SAVEFIX | Autosave during character creation; max HP drift; "fast energy drain" | The energy numbers are the stamina cap at high fatigue (0.65 x max), so the bug is fatigue rising too fast (suspect Wet's fatigue_per_min); do not touch stamina regen |
| CLAIMFIX | CLAIM re-press; build ghost under the HUD | CLAIM appends plots, it does not move them; PRD 13.1 says a second claim is an orthogonal expansion - refuse non-adjacent/overlapping with a notice |
| PHONEHUD | Phone tap targets ~26 CSS px, tiny text | Not started. Web content scaling at DPR 3 (`project.godot` stretch settings, HUD compact layout); needs a browser check with a phone viewport |
| WEBPACK | Pack 255 MB, ceiling 220 MB | Not started. survivor 69 MB, nature/generated 51 MB; texture import settings for the web preset; no visible loss |
| OCCLUDE2 | Survivor hidden under the harbour roof and behind bushes | Not started. Extends W2-OCCLUDE (see-through trees) |

## 2. Reviewed packages waiting to merge (Claude, batched)

All passed independent review (most also a blind A/B). Each has a pre-merge fix list in
`docs/orchestration/mmo/handoff/workflows/side-int2-args.json`. Merge with the batched side integrator
(`deadfront-side-int2.js`, run `wf_d670b08f-f36`, resume with those args) in this order:
REST, SAILUI, DEINO | NET, STEGO, CHARCREATE | TARGETUI, PETRADIAL. CAGEICON waits for ICONS2.
Reports: `docs/orchestration/reports/claude-mmo-<key>.md` on each branch `claude/mmo-<key>` (DEINO: `claude/mmo-art-deinonychus`).

## 3. The core merge chain (finish-6, run `wf_c321f8a4-028`)

Owner's priority order. State: W2-DATA and W2-SKILLS and W2-INV merged; W2-PROCESS passed review r3; ECON passed r6;
W2-GATHER failed r2 (rare XP not in the docs, phone rare pop, motion gate) and is in its fix round; W2-BUILDSYS in work;
ICONS2 and FORGEART in review; W2-RAGDOLL paused (it hogged every Godot slot). Resume finish-6 from a loop tick; its
PAUSED list is in the script. GATHERUI (spec 22) follows W2-GATHER.

## 4. Owner requests in progress

| Item | State | Context |
|---|---|---|
| 2D resource cards (spec 25 s1; owner: "resources 2D but realistic, kind of look 3D", buildings stay 3D) | DeepSeek CARD2D running; nothing baked yet | Bake windowed; map every model the home island spawns (Quaternius Grass/Rock_1-7/Plant_1-5, -a/-b variants); share materials (MultiMesh); check the normal-map frame in the first shot; send the owner the split shot and sway clip |
| Saddles for every rideable tame ("make more tames mountable and have this") | DeepSeek SADDLES running | T. rex howdah pattern: `docs/orchestration/reports/art-survivor-v2-armor-mount.md` s3, scripts in `~/Documents/deadfront-dsc-work/survivor-v2/anim/work/`; known bug: `creature_view.rider_transform()` carries the mesh scale (riders K times too big except the T. rex) |
| Triceratops | Mesh, rig, nine clips on `claude/mmo-trike` 1aeb461f (50 Tripo credits); review not run | Run `deadfront-trike-mesh.js` review rounds; check the global `giant_mass` 60 -> 40 change (affects every species near the kick line) |
| Stegosaurus art (4 tail spikes, green-brown hide) | STEGO-ART paused | `deadfront-stego-art.js`; merges after STEGO |
| Gather radial glitch | B1 merged (6ede0bd4) | Follow-ups in `docs/orchestration/reports/claude-mmo-gatherfix.md`: one 45 px click step, the phone re-solve jump, the phone lab set-up |
| CONTROLS B2-B4 (WASD + floating joystick, pathfinding, walk-to-and-interact; also owns two-tap gather and trunk-only tree taps) | Built through B3 + B4 lab on `claude/mmo-controls`, unreviewed | Report `claude-mmo-controls.md`; B1 already merged separately, so rebase onto 6ede0bd4 first |
| GUIDE (walkthrough finger) | Needs round 4 | Orthographic behind-camera mirroring bug, disabled-hex tap, clamped-cost minors |
| INVUI (bag/gear screens, spec 13) | Fix r2 | Depends on W2-INV (merged) |
| EXCHANGE (Island Market, spec 14) | Review r2 | Depends on ECON + INVUI |
| CHAT (region chat, spec 20) | Paused in fix r2 | After NET merges; majors: row rebuild per line, Enter-flood disconnect |
| COMBATFX (damage numbers that expand, fade and float up; bigger for crits) | Paused in build | spec 24 + owner corrections in STATUS |
| LEVELFX ("make it flashy") | Paused in fix r1 | |
| APPEAR-A (hair split, helmet shells, beards) | Paused in review r1 | Merges after CHARCREATE |

## 5. Spec 25 (owner observations), not started

Map: fog revealed like a brush, icons for claims, campfires, trade and quest facilities, your trail as black dots, other
players as grey dots (extends spec 15, MAPUI). Interaction camera: tapping a resource or enemy pans to it and the menu stays
locked to it. Walking HUD bottom right: jump, scan, combat toggle, inventory, search; quest-giver bubble with portrait and
direction. Knife combat: basic attack, stab and slash, tackle, kick, roll (blue), Attack Stance button, red End Combat;
energy recovers in combat (spec 07). Corpse harvest radial with tool-gated parts (Leather/Teeth need tools). Skill bar FULL
at the character level cap with XP shown (spec 12). Skewer cooking: meat + bone/stick, success rate, inherited traits, "if
crafting fails, materials disappear" (spec 08). Communication Center NPC missions. References: `docs/reference/durango-*.webp`.

## 6. Backlog

ISLANDSHAPE (waits on the owner's island-size answer), FOREST density, LIGHT2 (soft shadows), MAPUI, the Codex one-bug job
for Godot's exit-time SIGABRT, W3-SRVACT/W3-SRVWORLD server-side gates (first-visit position check is a prerequisite),
real_length_m balance pass (Triceratops 9 m, Stegosaurus 18 m vs 11.9 m model).

## 7. DeepSeek CLI fixes (from the audit; source `~/Documents/DeepseekCLI/deepseek-code/src`)

P0: bash tool kills the whole process group on timeout and stops waiting on orphaned pipes (`tools/shell.ts runShell`);
force a PLAN.md before work and stop plan-less runs (`task.ts gate()`); show in-flight tool calls and flag hung ones
(`agent.ts executeOne`, `monitor.ts`, `cook.ts` status). Full list with P1/P2 in `docs/orchestration/dsc-improvements.md`.

## 8. Waiting on the owner

Island size target (Durango ~300x375 m, the docs' 160/240 m, or ours); a female v2 survivor base (~250 Tripo credits);
a painted portrait set (source?); a standing permission for production deploys (or say "deploy" each time).
