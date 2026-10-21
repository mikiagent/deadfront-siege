export const meta = {
  name: 'deadfront-rest',
  description: 'REST: reproduce the owner\'s production bug, then a real Rest that sits you down, heals and lowers fatigue by place (anywhere, bonfire, shelter/bed); independent review, blind A/B',
  phases: [
    { title: 'Build', detail: 'reproduce on production, rest action, rates by place, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-rest`
const BR = 'claude/mmo-rest'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-rest.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-rest-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with Durango: Wild Lands systems; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner bug report (production): "resting should sit you down and heal you and lower exhaustion. I tried this on vercel and it didn't work". Production is commit 31c064a08 (stamp 31c064a08/2284b9bf56) of claude/mmo-overhaul; the branch has moved since. The base has no standalone rest action: only Vitals.rest(amount) (game/scripts/combat/vitals.gd:151), a Sleep context hex at beds/tents (player_input.gd context_actions -> p.sim.start_sleep / nearest_sleep_spot) and a RESTED status chip.
Binding docs: docs/design/durango-prompts/01_fatigue_and_exhaustion.md (stamina, energy and fatigue are separate; :19 recovery at tents, beds, comfortable furniture, campfires, safe camps, conditions affect recovery; :22 fatigue UI with recovery explanations; :25 the loop "reach a camp -> rest/sleep and use appropriate recovery -> resume work"), the PRD (docs/prd/durango-wild-lands-systems-prd.md :118 resting in a residence is the main fatigue dump, Health and Energy slowly auto-recover; :285 Bonfire: clears Wet, effects while sitting; :416 fatigue falls from rest; :803 houses give rest bonuses, tents cheap fatigue management), STATUS owner decisions (no unrecoverable exhaustion state). Values the docs do not give go in data marked # ASSUMPTION.
Package REST: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh rest). Report ${REPORT}; hooks ${HOOKS}.
Scope: (1) REPRODUCE FIRST on the production commit (bash ${SP}/mkscratch.sh rest-prod 31c064a08) and on the base: try every way a player could rest (the Sleep hex at a bed/tent, standing at a bonfire, any rest button) and record what happens to pose, HP and fatigue over 30 s (numbers) - find exactly why "resting" did nothing for the owner. (2) A real Rest: a Rest action that is always available out of combat (context hex, white icon, and a desktop key), which sits the survivor down (a seated pose from the existing clips - sleep_down/sleep or a proper sit if one exists; no T-pose, no sliding), heals HP and lowers fatigue over time while seated, with the rate depending on where: anywhere (small), next to a lit bonfire/campfire (more; PRD:285 sitting effects), in a tent/shelter/bed or a closed house (most; the Sleep flow stays for beds); moving, taking damage, entering combat or a creature aggroing cancels it with a stand-up; a "Resting" status chip shows the live recovery rates (spec 01:22 recovery explanation). Online it goes through PlayerActions as an intent. (3) Make sure the existing Sleep flow at beds/tents also heals and lowers fatigue visibly (fix it if it is the broken path). Test game/tests/t_rest.gd that fails on the old code and checks: sits, HP rises, fatigue falls at the data rates per place, cancels on move/damage/combat, never below 0 or above max, save/load mid-rest.
Rules: Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_rest.gd), silent, never --editor; --import once after adding a class_name file. Shots: windowed, the survivor seated at a bonfire and in open ground, the status chip, 1600x900 (Forward+ and gl_compatibility) and 844x390; open every PNG. Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS, the labs you touch with 0 SCRIPT ERROR. Files of merged packages (player_input.gd / player_actions.gd / player_sim.gd from W2-PLAYER, vitals.gd, hunt_hud.gd, statuses.json) get exact compiling changes in the hooks patch; new files are yours. WATER (merging now) adds Thirsty/Quenched/Dirty statuses and touches player_sim.gd: merge claude/mmo-overhaul again before you finish. Keep game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (many workflows run). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch] (reuse names). Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, REPRODUCE on the production commit and the base first (numbers and shots), then build the package, the hooks patch and the test, run every gate, take AFTER shots at the same spots (1600x900 Forward+ and gl_compatibility, 844x390), LOOK at them, write ${REPORT} (the root cause of the owner's report, before/after numbers, rates with their doc lines, assumptions, hooks), commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of REST. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/rest/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-rest ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-rest claude/mmo-overhaul. Run every gate and t_rest; check every rate against the cited doc line or its # ASSUMPTION; try to break it (rest while a creature approaches, take damage while seated, rest mounted, rest in water, rest at an unlit bonfire, spam rest, rest then save and load, the Sleep flow at a bed and a tent, HP and fatigue clamps, the pose on slopes); check scope (new files + hooks) and that the test fails on the old code. Take matched BEFORE/AFTER shots of the survivor trying to rest at a bonfire and in open ground (1600x900 gl_compatibility and 844x390) as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same moment from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped game screen (is it clear the survivor is resting and recovering, pose, readability, polish). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`REST review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
