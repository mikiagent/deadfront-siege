export const meta = {
  name: 'deadfront-levelfx',
  description: 'LEVELFX: flashy light-effect level-up animations (character and skill) with a ballooning LEVEL UP celebration, no glitchy motion; independent review, blind A/B',
  phases: [
    { title: 'Build', detail: 'light pillar, rings, rays, HUD celebration, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-levelfx`
const BR = 'claude/mmo-levelfx'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-levelfx.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-levelfx-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with ARK-quality visuals and Durango: Wild Lands UI; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner (standing rule, 2026-10-21): "as a rule of thumb: make it flashy. Level ups should have light effect animations. Also watch out for glitchy movement of UI and player". References: ${OWNER}/docs/reference/durango-levelup-loot-reference.webp and durango-gather-hud-levelup.webp (open both).
Package LEVELFX: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh levelfx). Report ${REPORT}; hooks ${HOOKS}.
Find first: where character level-ups and skill-category level-ups happen (W2-SKILLS merged: Lv. 1-60, categories), and the existing level-up toast/notice in the HUD (ui_real_capture_lab has busy_levelup / levelup screens).
Scope: (1) CHARACTER LEVEL-UP - a flashy light-effect animation at the survivor: a warm gold light pillar rising from the ground, an expanding ground ring, radial light rays, rising sparkles and a short bright flash on the survivor (~1.5-2 s), built to look good in BOTH renderers (gl_compatibility has weaker glow: use additive unshaded meshes/particles and a short-lived OmniLight, not only post glow), plus the HUD celebration: a big "LEVEL UP" with the new level number popping in (overshoot then settle), the level badge pulsing, and the reward lines (SP gained, unlocks) per the Durango references; (2) SKILL LEVEL-UP - a smaller version (a ring and sparkles at the survivor, the category icon popping on the HUD with its new level); (3) several level-ups at once queue cleanly (no overlapping text); (4) NO glitchy movement: the camera does not shake or jump; the effect and its UI are anchored smoothly (the HUD text never jitters, follows no per-frame jumps); measure it over a frame sequence; (5) cheap: one-shot nodes freed after, particle counts within a phone budget; frame cost measured at 844x390 in gl_compatibility; (6) data-driven colours/timings (# ASSUMPTION values). No audio (tests are silent; audio is another package) - leave a hook point.
Test game/tests/t_levelfx.gd that fails on the old code (no effect) and checks: an effect and HUD celebration spawn on a character level-up and a smaller one on a skill level-up, they free themselves, queued level-ups do not overlap, no camera offset change. A lab levelfx_lab that triggers both for shots at their peak and a frame sequence.
Rules: Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_levelfx.gd), silent, never --editor; --import once after adding a class_name file. Shots: windowed at the effect's peak and mid-way, day and night, 1600x900 (Forward+ and gl_compatibility) and 844x390; open every PNG. Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS, ui_real_capture_lab [uireal] PASS, 0 SCRIPT ERROR. Files of merged packages (hunt_hud.gd, the skills code) get exact compiling changes in the hooks patch; new files are yours (game/scripts/fx/ or ui/). Keep game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees. Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch] (reuse names). Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, take BEFORE shots of today's level-up, then build the package, the hooks patch and the test, run every gate, take AFTER shots (1600x900 Forward+ and gl_compatibility, 844x390, day and night), LOOK at them next to the references, write ${REPORT}, commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of LEVELFX. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/levelfx/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-levelfx ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-levelfx claude/mmo-overhaul. Run every gate and t_levelfx; try to break it (several level-ups at once, level-up while mounted, in combat, at night, indoors under a roof, at 844x390 with the HUD busy, frame cost on the web renderer, the camera or HUD jittering over a frame sequence - measure per-frame deltas, leaked nodes after the effect); check scope (new files + hooks) and that the test fails on the old code. Take matched BEFORE/AFTER shots of a character level-up at its peak and a skill level-up (1600x900 gl_compatibility and 844x390) as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same moment from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped game screen (how rewarding and flashy the level-up feels while staying readable and clean). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`LEVELFX review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
