export const meta = {
  name: 'deadfront-water',
  description: 'WATER: Drink / Wash (and Fill if a container exists) whenever the survivor is next to or in fresh water, with the PRD effects (statuses, not meters); reproduce, build, independent review, blind A/B',
  phases: [
    { title: 'Build', detail: 'reproduce at the shoreline, implement, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-water`
const BR = 'claude/mmo-water'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-water.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-water-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with Durango: Wild Lands systems and UI; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner: "when next to water, menu items pop up like washing and drinking". Read ${OWNER}/docs/design/durango-prompts/17_water_context_actions.md (it quotes the binding PRD lines: :105 drink/wash/fill container prompts near water; :314 drink cuts heat fatigue, wash clears dirty; §6.3 :409-416 Thirsty/Quenched/Hungry/Full are fatigue-rate STATUSES, never meters; :434/:447 Dirty/Very dirty +20 %/+50 % fatigue until washed; :284 Wet after 5 s in water; :72/:1030 no hunger/thirst/temperature meters) and open the reference ${OWNER}/docs/reference/durango-water-actions.webp.
Base today: game/scripts/player/player_input.gd context_actions() shows Drink/Wash only when p.in_water or surface_y < 0.15 (misses standing NEXT to water); drink adds 5 energy, wash rests 2 fatigue (both off-spec); white icons drink.svg/wash.svg exist (ui_icons.json).
Package WATER: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh water). Report ${REPORT}; hooks ${HOOKS}.
Scope: (1) a reliable "next to fresh water" test (shoreline within reach of the survivor, standing in shallow water, river/lake bands; NOT salt sea if the docs distinguish fresh water - check world-design.md and rules.json "water": "drinkable") cheap enough to run every frame or on a timer; (2) Drink and Wash hexes appear in the HUD context cluster whenever it is true and disappear when the survivor walks away, white icons, the Durango look; (3) effects from the PRD, values in data marked # ASSUMPTION where the PRD gives no number: Drink removes Thirsty / grants Quenched and cuts heat fatigue; Wash clears Dirty / Very dirty; if those statuses do not exist yet, add them as data-driven statuses (with what makes a survivor Dirty per the PRD - gathering, butchering, combat, as the PRD says) through the existing status system, never as meters; Fill container only if a container item exists in items.json (otherwise list it as a follow-up, no inert button); (4) the actions go through the player's command layer (PlayerActions) so the server path stays one place; (5) a test game/tests/t_water.gd that fails on the old code (no hex beside water; drink/wash effects off-spec) and covers next-to/in/away, each effect and status, and that no meter is introduced. Files of merged packages (player_input.gd/player_actions.gd from W2-PLAYER, statuses data from W1-COMBAT, hunt_hud.gd from W1-UI) get exact compiling changes in the hooks patch; new files are yours.
Rules: REPRODUCE FIRST: on the base, stand the survivor one metre from the shoreline and in shallow water (a probe or lab), take windowed shots at 1600x900 gl_compatibility and 844x390 and record whether the hexes show. Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_water.gd), silent, never --editor; --import once after adding a class_name file. Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS, the labs you touch with 0 SCRIPT ERROR. Keep the git-excluded game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (other workflows are running). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch]. Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, reproduce on the base first (shots), then build the package, the hooks patch and the test, run every gate, take AFTER shots at the same spots (1600x900 Forward+ and gl_compatibility, 844x390), LOOK at them next to the reference, write ${REPORT} (repro before/after, effects with their PRD lines, assumptions, hooks), commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of WATER. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/water/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-water ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-water claude/mmo-overhaul. Run every gate and t_water; check each effect against the cited PRD line; try to break it (shoreline at different slopes and islands, rivers/lakes, salt sea if distinguished, walking away mid-action, mounted, in combat, spamming drink/wash, save/load with statuses, no meter introduced, the hexes not crowding the other context hexes at 844x390); check scope (new files + hooks) and that the test fails on the old code. Take matched BEFORE/AFTER shots (survivor beside water, 1600x900 gl_compatibility and 844x390) as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same moment from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped game screen (does the player get the right contextual actions at the water, readability, hierarchy, polish, no clutter). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`WATER review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
