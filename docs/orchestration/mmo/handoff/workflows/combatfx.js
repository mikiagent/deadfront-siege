export const meta = {
  name: 'deadfront-combatfx',
  description: 'COMBATFX: small informative damage numbers on every hit, bigger for crits and big hits (owner correction); build, independent review, blind A/B',
  phases: [
    { title: 'Build', detail: 'damage numbers, size ladder, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-combatfx`
const BR = 'claude/mmo-combatfx'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-combatfx.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-combatfx-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with ARK-quality visuals and Durango: Wild Lands UI; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner: "this guy shot a bow and arrow at the stego and it critted, the crit number expands and balloons out, max visibility". Read ${OWNER}/docs/design/durango-prompts/24_crit_numbers.md and open ${OWNER}/docs/reference/durango-crit-number.webp. Crits already exist: game/data/combat_tuning.json (crit_base, crit_mult), creature_attack.gd emits combat_float(dealt, &"crit") / next_hit_kind; find the player's melee and ranged hit paths and the floating-number code that shows them today.
Package COMBATFX: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh combatfx). Report ${REPORT}; hooks ${HOOKS}.
OWNER CORRECTION (newest, binding): "the crit thing I think you took too literally. Just add damage numbers, make them small and informative but make them bigger if you hit a crit or did a lot of damage". Scope: DAMAGE NUMBERS only. (1) Every hit shows a small, clean, informative number near the struck creature or the survivor: damage you deal in white, damage you take in red, a heal in green if heals exist; MOTION (owner: "you want them to kind of expand out and dissipate, its hard to explain"): the number appears (a quick pop), then EXPANDS OUTWARD while it DISSIPATES - its scale grows smoothly (about 1.0x -> 1.4x) as its opacity fades to 0 over ~0.6-0.8 s, while it also FLOATS UP (owner: "you can make it float up too") - a smooth upward drift of roughly one number-height over its life, easing out; expansion and float together, centred on the number, no jitter, no jumps. Readable at 844x390 and 1600x900; never clipped at the screen edge. (2) Size scales with significance: a crit starts noticeably bigger (about 1.5x) and yellow/gold with an outline, and a big hit (a large share of the target's max HP, threshold in data) starts bigger too; both expand and dissipate the same way; never a giant number covering the target. (3) Rapid hits never stack illegibly (small offsets or merging within a short window); misses or blocks show a small grey word if the game has them. (4) No target outline (dropped by the owner). (5) Smooth motion: numbers move steadily, no jitter over a frame sequence. Data-driven sizes, colours and timings (# ASSUMPTION values). Test game/tests/t_combatfx.gd fails on the old code (no numbers or no crit/big-hit sizing) and checks the size ladder (normal < big hit < crit), colours by direction, cleanup, no overlap. A lab (or lab path) that stages normal, big and crit hits from melee and a bow on a Stegosaurus for shots. Frame cost at 10 hits/s in the web renderer. Rules: Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_combatfx.gd), silent, never --editor; --import once after adding a class_name file. Shots: windowed, the crit at its peak and a normal hit, 1600x900 (Forward+ and gl_compatibility) and 844x390; open every PNG next to the reference. Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS, combat labs 0 SCRIPT ERROR. Files of merged packages get exact compiling changes in the hooks patch; new files are yours. Keep game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (many workflows run; TARGETUI is changing target selection in parallel - stay in the hit-feedback lane). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch] (reuse names). Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, take BEFORE shots of today's hit feedback (normal, big and crit hits), then build the package, the hooks patch and the test, run every gate, take AFTER shots (1600x900 Forward+ and gl_compatibility, 844x390), LOOK at them next to the reference, write ${REPORT}, commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of COMBATFX. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/combatfx/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-combatfx ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-combatfx claude/mmo-overhaul. Run every gate and t_combatfx; try to break it (hits at the screen edge, many hits per second, several targets, crits vs big hits vs normal hits, mounted combat, ranged and melee, frame cost in the web renderer, readability at 844x390, jitter over a frame sequence); check scope (new files + hooks) and that the test fails on the old code. Take matched BEFORE/AFTER shots of a normal hit, a big hit and a crit (1600x900 gl_compatibility and 844x390) as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same moment from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped game screen (informative, readable hit numbers that stay out of the way, crits and big hits clearly bigger, no clutter). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`COMBATFX review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
