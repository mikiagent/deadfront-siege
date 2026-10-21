export const meta = {
  name: 'deadfront-hud-daynight',
  description: 'HUD-DAYNIGHT: a Durango-style day/night dial next to the minimap reading the existing cycle; build, independent review, blind A/B vs the current HUD',
  phases: [
    { title: 'Build', detail: 'worktree, dial component, hook, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-hud-daynight`
const BR = 'claude/mmo-hud-daynight'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REF = `${OWNER}/docs/reference/durango-hud-daynight.webp`
const REPORT = 'docs/orchestration/reports/claude-mmo-hud-daynight.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-hud-daynight-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with Durango: Wild Lands UI; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner: "We don't have the day/night cycle component in the UI next to the map". Spec ${OWNER}/docs/design/durango-prompts/16_hud_day_night_dial.md; reference ${REF} (open it: the small round dial just left of the round minimap, top right). The game already has the cycle: Game.time_of_day (0 = midnight, 0.5 = noon), Game.phase_name() (dawn/day/dusk/night), lighting.json follows it; PRD:289 says do not invent a cycle length - the dial READS the game's cycle and never sets it.
Package HUD-DAYNIGHT: branch ${BR}, work tree ${WT} (create with: bash ${OSP}/mkwt.sh hud-daynight). Report ${REPORT}; hooks ${HOOKS}.
Scope: a new component file (e.g. game/scripts/ui/day_night_dial.gd) that draws a compact round dial in the Durango look - a sun or moon disc whose position or needle shows the time of day, tinted by phase, legible at 844x390 and 1600x900, a tap/click target >= 44 px that shows the phase and the time until the next phase in a small label (no inert control); placed beside the minimap without overlapping the minimap, its coordinates, the END button, the quest tracker or safe areas, and laid out again on resize. hunt_hud.gd / hud_layout.gd belong to the merged W1-UI: wire the dial through exact compiling changes in the hooks patch (git apply --check clean on claude/mmo-overhaul). Colour = things, white = actions: the sun/moon are things (warm sun, pale moon), the ring and needle are white/neutral. Online play later reads time from the server: keep the dial reading one function so that swap is one line (note it). A test game/tests/t_daynight_dial.gd that fails on the old code (dial missing) and checks phase mapping at time_of_day 0.0/0.25/0.5/0.75 and that the dial never writes time.
Rules: Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_daynight_dial.gd), silent, never --editor; --import once after adding a class_name file. Shots: windowed ui_real_capture_lab (--lab=ui_real_capture_lab --shot-dir=<dir>) or home_lab at 1600x900 (Forward+ and gl_compatibility) and 844x390, at day and at night; open every PNG. Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS, ui_real_capture_lab [uireal] PASS at every size. Keep the git-excluded game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (other workflows are running). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch]. Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, read hunt_hud.gd, hud_layout.gd, the minimap code and Game's time API, build the dial, the hooks patch and the test, run every gate, take the shots (day and night, all sizes), LOOK at them next to the reference, write ${REPORT}, commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of HUD-DAYNIGHT. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/hud-daynight/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-daynight ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-daynight claude/mmo-overhaul. Run every gate and the test; try to break it (time_of_day wrap at midnight, every phase boundary, resize between phone and desktop, safe areas, the dial overlapping the minimap/coords/END/quest tracker, tap target size, night readability, the dial writing time); check scope (new file + hooks only) and that the test fails on the old code. Take matched BEFORE/AFTER HUD shots (same scene, time of day, size, renderer: 1600x900 gl_compatibility day and night, 844x390 day) and return them as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same HUD from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped HUD (readability, hierarchy, polish, no overlap or clutter). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new HUD (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`HUD-DAYNIGHT review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
