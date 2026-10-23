export const meta = {
  name: 'deadfront-sailui',
  description: 'SAILUI: the Durango Sail chart (rightward-scrolling sea of our islands by level) replacing the harbour text list; build, independent review, blind A/B',
  phases: [
    { title: 'Build', detail: 'chart, nodes, scroll, states, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-sailui`
const BR = 'claude/mmo-sailui'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-sailui.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-sailui-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with Durango: Wild Lands UI; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner: "Menu scrolls rightward and has many islands" (the Durango Sail menu; read its description in the second section of ${OWNER}/docs/design/durango-prompts/15_island_map_scale.md) and the island/map comparison ${OWNER}/docs/orchestration/mmo/islandmap-check.md (our travel menu today: world_ui.show_harbour's vertical sheet of grey text rows; shots in /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/islandmap/shots/harbour_*.png - open them).
Package SAILUI: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh sailui). Report ${REPORT}; hooks ${HOOKS}.
Scope (from the comparison plan, binding): Replace world_ui.show_harbour's vertical sheet with a full-screen rightward-scrolling 'Sail' chart: Home Lv10 at the far left, then 11 tier bands 15..60 darkening to the right, and one round node per island with a climate icon, name, Lv and a state badge (check visited, '?' never visited, lock with 'Survival N'). Tapping a node opens a card with cost and Sail, and travel goes through the unchanged World.sail. On unstable islands, 'Free return home' and 'Return to camp' sit in the header. Add one shared display-name function (also used by the atlas). Files: world_ui.gd (or a new sail_screen.gd), world.gd (name helper), and a sail_lab or a mode in harbour_lab.
Gates (from the plan): 1) At 1600x900 and 844x390: the scroll content is at least 2x the viewport width, the vertical scrollbar is absent, and node x is strictly increasing with tier. 2) Every node and button tap rect is at least 64x64 px, with no rect overlaps (a lab asserts it), inside the safe area. 3) Visible without scrolling: at least 6 nodes at 1600x900 and at least 4 at 844x390 (Home plus 3). 4) A touch drag of 400 px moves the content by 400 +/- 10 px. 5) At Survival 0 all 14 unstable nodes show a lock. After visiting savannah_15 its node shows a check, and never-visited nodes show '?'. 6) t_harbour, camp_travel_probe and smoke pass, and island_lab still prints nodes=378 creatures=24. 7) Desktop Chrome web build shots at 1600x900 and 844x390, judged against spec 15's Sail description.
Orchestrator rulings until the owner says otherwise: keep the 14 fixed islands we have (do not invent seas, cities or new islands, do not change travel rules, costs or survival requirements - only present them); undiscovered vs visited comes from visited_islands; locked destinations read clearly with their requirement; travel itself goes through the existing harbour code path. Reuse the Durango look being built in claude/mmo-invui (its theme file, if present) or match it in your own files. Files of merged packages (world_ui.gd, harbour code, HUD) get exact compiling changes in the hooks patch; new files are yours. A test game/tests/t_sailui.gd that fails on the old code (no chart) and checks order by level, scroll, discovery/lock states and that choosing a node calls the same travel path.
Rules: Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_sailui.gd), silent, never --editor; --import once after adding a class_name file. Shots: windowed, the Sail chart at 1600x900 (Forward+ and gl_compatibility) and 844x390, scrolled left and right; open every PNG. Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS, harbour_lab and t_harbour PASS, 0 SCRIPT ERROR. Keep the git-excluded game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (other workflows are running). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch]. Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads, no art spend (draw the chart and island nodes procedurally or from existing art). Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, take BEFORE shots of today's travel menu, then build the package, the hooks patch and the test, run every gate, take AFTER shots (1600x900 Forward+ and gl_compatibility, 844x390), LOOK at them against the Sail description, write ${REPORT} (before/after, assumptions, hooks), commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of SAILUI. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/sailui/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-sailui ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-sailui claude/mmo-overhaul. Run every gate, t_sailui, t_harbour and harbour_lab; try to break it (every destination, locked vs unlocked, visited vs not, scrolling with mouse wheel, drag and touch, opening at the far left/right, 844x390 targets, travel still charging and landing exactly as before, closing mid-scroll); check scope (new files + hooks) and that the test fails on the old code. Take matched BEFORE/AFTER shots of the travel menu (1600x900 gl_compatibility and 844x390) as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same moment from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped game screen (does it invite you to sail, readability, hierarchy, polish). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`SAILUI review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
