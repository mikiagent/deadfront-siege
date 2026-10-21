export const meta = {
  name: 'deadfront-domain',
  description: 'DOMAIN: "<name>\'s Domain" banner with the owner portrait on entering claimed land, plus the dotted claim edge; reproduce, build, independent review, blind A/B',
  phases: [
    { title: 'Build', detail: 'reproduce, banner, portrait, claim edge, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-domain`
const BR = 'claude/mmo-domain'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-domain.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-domain-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with Durango: Wild Lands systems and UI; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner: "When entering player's claimed regions, it says 'Player's Domain' with their profile picture." Read ${OWNER}/docs/design/durango-prompts/18_domain_banner.md and open ${OWNER}/docs/reference/durango-domain-claims.webp and ${OWNER}/docs/reference/durango-house-4x4.webp (claimed land outlined on the ground by a dotted yellow line; spec 15's map shows the same "<name>'s Domain" label with the portrait).
Package DOMAIN: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh domain). Report ${REPORT}; hooks ${HOOKS}.
Scope: (1) REPRODUCE FIRST on the base: walk the survivor into its own claimed land (claims: BuildGrid tiles, World.runtime.is_claimed, claim stakes) and record with windowed shots whether any banner or visible claim edge exists; (2) on crossing INTO a claimed region show a Durango-style banner "<owner name>'s Domain" with the owner's portrait (a dark pill, gold name, white text, the portrait in a round frame), for a few seconds with a short fade, not again while staying inside, again after leaving and re-entering; never over the minimap, quest tracker, vitals or safe areas; (3) the owner's portrait: reuse a portrait the game already has (check claude/mmo-invui's Character screen portrait and any portrait/avatar code on claude/mmo-overhaul); if none exists, render the survivor's head once into a cached texture from its real appearance (SubViewport snapshot), with a neutral silhouette for owners whose appearance is unknown; (4) the claim edge: if claimed land has no visible edge today, draw the reference's dotted yellow boundary on the ground around each claimed region (cheap: one mesh or decal strip per region, rebuilt when claims change, readable in both renderers); (5) claim data stays the source of truth (who owns which tile; online the server sends it later - keep that one function); (6) a test game/tests/t_domain.gd that fails on the old code (no banner on entry) and covers enter/stay/leave/re-enter, own vs another owner, the boundary following claim changes. Files of merged packages (hunt_hud.gd from W1-UI, island_runtime/claims code, player code) get exact compiling changes in the hooks patch; new files are yours.
Rules: Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_domain.gd), silent, never --editor; --import once after adding a class_name file. Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS, the labs you touch with 0 SCRIPT ERROR. Keep the git-excluded game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (other workflows are running). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch]. Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, reproduce on the base first (shots), then build the package, the hooks patch and the test, run every gate, take AFTER shots at the same spots (1600x900 Forward+ and gl_compatibility, 844x390), LOOK at them next to the references, write ${REPORT} (repro before/after, assumptions, hooks), commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of DOMAIN. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/domain/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-domain ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-domain claude/mmo-overhaul. Run every gate and t_domain; try to break it (enter/leave fast along an edge, mounted entry, harbour travel landing inside a claim, claims changing while inside, many small claims, save/load, the banner overlapping HUD parts at 844x390, the portrait missing, the boundary in both renderers and at night, frame cost of the boundary); check scope (new files + hooks) and that the test fails on the old code. Take matched BEFORE/AFTER shots (survivor just inside a claimed region, 1600x900 gl_compatibility and 844x390) as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same moment from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped game screen (is it clear whose land this is, readability, hierarchy, polish, no clutter). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`DOMAIN review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
