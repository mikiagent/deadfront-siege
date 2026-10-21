export const meta = {
  name: 'deadfront-guide',
  description: 'GUIDE: Durango walkthrough finger pointing at the next tap for the current order step; build, independent review, blind A/B',
  phases: [
    { title: 'Build', detail: 'finger, resolver, hooks, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-guide`
const BR = 'claude/mmo-guide'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-guide.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-guide-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with Durango: Wild Lands UI; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner: "notice the game ui and how the resource gathering looks. The finger icon is a walkthrough guide" (spec ${OWNER}/docs/design/durango-prompts/22_gather_ui_walkthrough.md). A check found NO tutorial pointer or hint system on any branch; steps live in game/data/world/objectives.json read by game/scripts/core/objectives.gd (id, title, hint, one of have/have_any/pets/visit/away/survival_level; no target).
Package GUIDE: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh guide). Report ${REPORT}; hooks ${HOOKS}.
Scope: a walkthrough finger - a white vector-drawn pointing hand (Durango style, >= 64 px tall at 844x390, gentle tap animation, no text) on its own CanvasLayer between 66 and 95 (above the gather radial at 64 and the work ring at 65, below modals at 96), MOUSE_FILTER_IGNORE so it never eats input (the radial closes on presses off a hex). New files: game/scripts/ui/guide_finger.gd, game/scripts/core/guide.gd (step -> target resolver + seen/done), game/tests/t_guide.gd, game/scenes/dev/guide_lab.tscn + game/scripts/dev/guide_lab.gd.
Targets: gather steps (branches, stone, fibre, logs) -> the nearest HarvestNode whose options() list the 'have' item, preferring one outside every living hostile creature's aggro radius (# ASSUMPTION); once the radial opens on that node the finger moves to that item's hex (a public GatherRadial.hex_rect_for(item) hook - the layout re-solves every frame, so re-read it each frame); craft steps -> the HUD craft control (a public HuntHud.control_for(id) hook); station steps -> the nearest craft_station; meat/tame -> creatures by id; an optional "guide" field per step only where derivation fails; off-screen or behind-camera world targets clamp to the safe-area edge with the finger rotated toward them (cam.unproject_position).
Show when the current order is not done, its id is not in a new World.guide_done list, a target resolves, and no sheet, modal, creature plate or death screen is up (a HuntHud query hook); hide on the pick of the right hex or when the order advances, mark the step done and save it (save_game.gd hook; old saves default every step before World.objective to done - optional field, no rev bump); never overlap the vitals or the Orders card. Hooks (exact compiling changes in the hooks patch): world.gd guide_done; save_game.gd; objectives.gd exposing the step definition; gather_radial.gd hex_rect_for; hunt_hud.gd control_for + modal/plate query; mounting the overlay (player_view.gd or main.gd, and LabKit for labs). Also fix the Order 1 hint text if it says "wheel" (objectives.json, hook).
Gates: on a fresh scratch save the finger shows within 1 s with its tip <= 24 px from the chosen tree (or edge-clamped and pointing at it); after a real tap opens the radial the tip stays inside the Branch hex rect every frame for 3 s while the survivor walks; a tap at the tip picks Branch; the finger hides within 1 frame of the pick and never returns for that step, also after save and reload, and the next step's finger shows once; hidden under bag, craft, sheets and the creature plate; t_guide resolves steps 0-10 to a target kind or an explicit none; every t_*.gd, run_all, smoke and ui_real_capture_lab PASS.
Rules: Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_guide.gd), silent, never --editor; --import once after adding a class_name file. Shots: windowed guide_lab at 1600x900 (Forward+ and gl_compatibility) and 844x390: finger on the node, on the hex, gone; open every PNG. Keep the git-excluded game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (other workflows are running). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch] (reuse names; disk is tight). Typed GDScript in the house style, no new autoloads/deps, no god-file growth, no downloads. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, take BEFORE shots of the first order with no guide, then build the package, the hooks patch and the test, run every gate, take AFTER shots (1600x900 Forward+ and gl_compatibility, 844x390), LOOK at them, write ${REPORT} (before/after, assumptions, hooks), commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 4; round++) {  // one extra round (orchestrator 2026-10-21: r3 left one precise major)
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of GUIDE. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/guide/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-guide ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-guide claude/mmo-overhaul. Run every gate and t_guide; try to break it (every order step 0-10, the target behind the camera or off screen, a hostile creature near the target, opening the bag/craft/sheets mid-guide, picking the wrong hex, save/load mid-step, old saves, resizing, the finger eating a tap, the finger over the vitals or Orders card); check scope (new files + hooks) and that the test fails on the old code. Take matched BEFORE/AFTER shots of the first order (1600x900 gl_compatibility and 844x390) as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same moment from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped game screen (would a new player know what to tap next, readability, polish, no clutter). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`GUIDE review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 4) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
