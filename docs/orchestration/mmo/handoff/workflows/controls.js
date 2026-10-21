export const meta = {
  name: 'deadfront-controls',
  description: 'CONTROLS: stop the gather radial / node UI jitter, WASD + a floating left-side joystick, better pathfinding and movement, reliable walk-to-and-interact with buildings, stations and resources; phased build, independent review, blind A/B, route bot',
  phases: [
    { title: 'Build', detail: 'B1 UI jitter, B2 WASD + joystick, B3 pathfinding + movement, B4 interactions' },
    { title: 'Review', detail: 'independent reviewer, route bot, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-controls`
const BR = 'claude/mmo-controls'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-controls.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-controls-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with Durango: Wild Lands controls; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390, touch).
Owner (newest): "UI glitching up and down on resource nodes when clicking around. Do wasd control and a virtual joystick for movement on the bottom left that only appears when hold and drag on the left side. Improve the pathfinding and movement, player interactions with buildings, crafting stations, and resources".
Known cause of the glitch (gather check, docs/orchestration/mmo/tree-and-gather-checks.md on claude/mmo-overhaul): game/scripts/ui/gather_radial.gd re-solves its hex layout every frame, so hexes jump sides while the camera follows the walk; node labels may jitter the same way.
Package CONTROLS: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh controls). Report ${REPORT}; hooks ${HOOKS}.
Binding rules: all input goes through InputMap actions and the autoloaded touch layer presses them (AGENTS.md); game/scripts/ui/touch_controls.gd is integrator-only and other packages' files (player_input.gd / player_actions.gd / player movement from W2-PLAYER, hunt_hud.gd, gather_radial.gd from W1-UI, TilePath / build placer) change only through exact compiling hooks; new files are yours. GAUNTLET: gathering is from reach without teleport, movement cancels, progress shows above the node; workstations stay two-step (select the station, then its expanded hex action); player walls may be passable for their owner while blocking enemies; targets >= 44 px (56-64 px for contextual actions), safe areas, landscape 844x390. Do not change gather rules, timings or yields (W2-GATHER owns them), or target selection (TARGETUI, in another workflow, makes tapping a wild animal select it and a red swords hex start combat), or the gather hex look (GATHERUI later) - keep GatherRadial's public API and add only what the jitter fix needs.
Scope:
B1 JITTER: the gather radial solves its layout once when it opens (relative to the node's anchor) and keeps it while the camera moves; it re-solves only when the screen space really runs out (with hysteresis); node labels and plates are stable too. Gate: while the survivor walks 3 s toward the node, each hex's offset from the anchor changes by <= 2 px per frame with no side swaps; clicking around several nodes never makes UI jump.
B2 WASD + JOYSTICK: WASD (and arrows) move the survivor relative to the camera with diagonal normalisation, at the existing walk/run speeds; pressing a move key cancels a tap-to-move path or a pending interaction; mouse click-to-move still works. On touch: a press on the LEFT half of the screen that is not on a HUD control and drags beyond a dead zone (~12 px) spawns a floating joystick centred at the press point (base + knob, Durango-style, semi-transparent, safe-area aware), the knob clamps to its radius, deflection sets walk vs run, release hides it; a short tap there without drag still behaves as a tap (move/select/interact); the right half keeps its current role. Gates: t_controls cases for each, and shots of the joystick at 844x390.
B3 PATHFINDING + MOVEMENT: smoother tap-to-move paths (string-pulled / smoothed, no zig-zag), dynamic obstacles (buildings, placed props, resource nodes, owner-passable walls), stuck detection with repath and a graceful give-up notice, no sliding through solids, consistent acceleration and turning. Gate: a route bot on 3 islands (home, a temperate and a tropical one) walks to 100 random reachable targets each: success >= 99 %, no stuck stretch over 2 s, path length <= 1.15x the shortest grid path, and heading changes per metre within a bound you measure on the base and improve.
B4 INTERACTIONS: tapping a resource node, a crafting station or a building (door, chest, bed, workbench) from 5-40 m walks to the nearest reachable reach point on its open side (never through it), faces it and starts the right interaction (gather radial / the two-step station flow / open / use) without teleport; re-tapping or moving cancels cleanly; interactions from behind obstacles path around; an unreachable target gives a clear notice. Gate: the bot interacts with 50 nodes, 20 stations and 20 building parts per island type: success >= 98 %, mean time-to-interact recorded before and after (must not get worse), 0 teleports.
Rules: Godot only through ${OSP}/gslot.sh with its own timeout (perl -e 'alarm N; exec @ARGV'), silent, never --editor; --import once after adding class_name files. Shots: windowed at 1600x900 (Forward+ and gl_compatibility) and 844x390 (with --touch for the joystick); open every PNG. Gates also: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS, ui_real_capture_lab [uireal] PASS, the labs you touch with 0 SCRIPT ERROR. Keep game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (many workflows run). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch] (reuse names; disk is tight). Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads; tests must fail on the old behaviour. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const STEPS = [
  { key: 'b1', text: 'B1 the gather radial / node UI jitter (reproduce it first on the base with a measured per-frame offset log and shots).' },
  { key: 'b2', text: 'B2 WASD and the floating left-side joystick.' },
  { key: 'b3', text: 'B3 pathfinding and movement, with the route bot (measure the base first).' },
  { key: 'b4', text: 'B4 walk-to-and-interact with resources, crafting stations and buildings, with the interaction bot (measure the base first).' },
]
for (const st of STEPS) {
  const r = await agent(`${ctx}\n\nROLE: builder, step ${st.text} Read git log and the report first (earlier steps may be done). Implement the step to its gate, write its tests, run its gates and every t_*.gd, run_all and smoke, take its shots and look at them, update the report (before/after numbers), commit. Return done, head, gates, shots, summary.`, { label: `build:${st.key}`, phase: 'Build', schema: STEP })
  if (!r) return { stopped: 'cut at ' + st.key }
}
phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}\n\nROLE: independent, demanding reviewer (round ${round}) of CONTROLS. You did not write it; do not edit ${WT}; probes under ${SP}/review/controls/r${round}/; review the branch WITH its hooks (bash ${SP}/mkscratch.sh rev-controls ${BR} ${HOOKS}). Rerun every gate and both bots yourself (your own seeds); try to break it: clicking rapidly between nodes, stations and buildings; WASD while a path or interaction runs; the joystick starting on a HUD button, multi-touch, a tap vs a tiny drag, rotating the camera; tight spaces between buildings, owner walls, water edges, steep slopes; mounted movement; the two-step station flow; no teleports; frame cost of the pathing. Check scope (hooks only for others' files) and that every test fails on the old code. Take matched BEFORE/AFTER shots (the radial mid-walk, the joystick at 844x390, an interaction at a station) as pairs; look at them. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', final }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind game-feel director for a dinosaur survival game with Durango: Wild Lands-grade controls and UI. Two screenshots of the same moment from two builds per scene; you are NOT told which is newer; ignore file names. Open both and judge which is the better shipped game (UI stability, clarity of controls, polish). first/second/tie with reasons.\n${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) { let aw = 0, bw = 0; ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ }); ab.afterWins = aw; ab.beforeWins = bw; if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall}`, fix: "Address the judge's reasons." }) } }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`CONTROLS review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}\n\nROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors, add a check for each, rerun the gates, bots and shots, look at them, update the report and hooks, commit. If a finding is wrong, show evidence.\nFindings (JSON): ${JSON.stringify(findings, null, 1)}\nReturn done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final }
