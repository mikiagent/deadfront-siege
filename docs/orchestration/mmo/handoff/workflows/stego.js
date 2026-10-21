export const meta = {
  name: 'deadfront-stego',
  description: 'STEGO: remove the stale placeholder override so the merged Stegosaurus v2 (Tripo mesh, 34-bone rig, 9 clips) shows in game; verify motion, scale, clips; independent review, blind A/B',
  phases: [
    { title: 'Build', detail: 'remove the override, verify v2 in game, test, shots' },
    { title: 'Review', detail: 'independent reviewer, blind A/B, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-stego`
const BR = 'claude/mmo-stego'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REPORT = 'docs/orchestration/reports/claude-mmo-stego.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-stego-hooks.patch'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) at an ARK: Survival Ascended visual bar; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
Owner: "stegosaurus model is wrong, we should have a new one from an earlier coding job for you to use". Facts: Stegosaurus v2 is already in the repo - game/assets/creatures/stegosaurus/stegosaurus.glb + anim/ (Tripo H3.1 mesh, Opus rig in Blender: 34 bones incl. jaw and 7 tail bones, IK feet, rigid plates/spikes; faces -Z; 6.4 m; clips idle, walk, run, attack_primary, attack_heavy, hit_react, knockdown, death, alert; creature-verify --height 6.4 ALL HARD CHECKS PASSED; game/data/creatures/stegosaurus.json pipeline version 2; report docs/orchestration/reports/art-survivor-v2-armor-mount.md; v1 kept under stegosaurus/v1/). But game/scripts/creatures/creature_view.gd:64-66 forces a low-poly placeholder for every stegosaurus ("The current transplanted Stegosaurus skin has catastrophic weights") - a stale override written for v1 - and :159-160 draws that fallback; docs/orchestration/mmo/asset-replacement.md:20 lists it ("One-line fix + review v2").
Package STEGO: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh stego). Report ${REPORT}; hooks ${HOOKS}. ORCHESTRATOR GRANT: you may edit the stegosaurus override/fallback lines in creature_view.gd (W2-CVIEW, its owner, has not started) and game/data/creatures/stegosaurus.json; other packages' files through hooks.
Scope: remove the forced placeholder so the real v2 model loads; make sure the game honours v2's -Z forward axis and 6.4 m scale (the view's axis/scale handling from stegosaurus.json pipeline), every clip the game asks for resolves (0 "couldn't resolve track"), the walk/run play rates match its ground speed (no sliding; re-bake anim_events/clip speeds if the game uses them), hit/knockdown/death/alert play, feet sit on the terrain on slopes, plates and HP bar/aggro ring sit at the right height for a 6.4 m animal, the capture flow and pet/mount code that read creature height still work, and the placeholder code is deleted (no dead fallback). If the W2-RAGDOLL work (claude/mmo-w2-ragdoll, another workflow) has a stegosaurus profile built for the placeholder, list in the report what it must re-tune - do not edit that branch. If v2 shows any skinning defect in motion (stretching, popping plates), stop and report it with frames rather than hiding it.
Gates: a test game/tests/t_stego.gd that fails on the old code (placeholder forced) and checks the real mesh, skeleton and every clip load; creature_anim_lab (or a creature lab) with the stegosaurus: 0 "couldn't resolve track", 0 SCRIPT ERROR; windowed shots of v2 idle, walking, attacking, hit and dead on the home island and a temperate island, next to the survivor for scale, 1600x900 Forward+ and gl_compatibility and 844x390 - open every PNG and check silhouettes, plates, tail spikes, feet on ground, no stretching; frame cost with 4 stegosauri in view in gl_compatibility; every game/tests/t_*.gd, run_all, smoke PASS.
Rules: Godot only through ${OSP}/gslot.sh with its own timeout (perl -e 'alarm N; exec @ARGV'), silent, never --editor; --import once after changes to assets. Keep game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (many workflows run). Throwaway trees: bash ${SP}/mkscratch.sh <name> <ref> [patch] (reuse names; disk is tight). Typed GDScript in the house style, no new autoloads/deps, no downloads, no Tripo/Meshy spend. Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge into claude/mmo-overhaul or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
const b = await agent(`${ctx}

ROLE: builder. Create the work tree, take BEFORE shots of today's placeholder stegosaurus, then do the package and the test, run every gate, take AFTER shots, LOOK at them, write ${REPORT} (before/after, anything the ragdoll profile must re-tune), commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }

phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, demanding reviewer (round ${round}) of STEGO. You did not write it. Do not edit ${WT}; probes and shots under ${SP}/review/stego/r${round}/. Review the branch WITH its hooks: bash ${SP}/mkscratch.sh rev-stego ${BR} ${HOOKS}; before-tree: bash ${SP}/mkscratch.sh revbase-stego claude/mmo-overhaul. Run every gate and t_stego; try to break it (every clip in motion frame by frame for stretching or popping plates, slopes, a pack of 4, capture, taming, death and the corpse, plates/HP bar height, the old placeholder fully gone, frame cost in the web renderer); check scope (new files + hooks) and that the test fails on the old code. Take matched BEFORE/AFTER shots of a stegosaurus next to the survivor (idle and walking; 1600x900 gl_compatibility and Forward+) as pairs; look at every one. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', build: b }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass, ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    ab = await agent(`You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same moment from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is the better shipped game screen (which looks like a believable ARK-quality Stegosaurus: silhouette, plates, tail spikes, materials, grounding). Pick first, second or tie per scene with reasons.
${rv.pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `Judge did not prefer the new build (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  } else if (pass) { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no matched before/after pairs', fix: 'take them' }) }
  final = { round, pass, summary: rv.summary, findings, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null }
  log(`STEGO review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors below, add a check for each, rerun the gates and shots, look at them, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show evidence in the report.
Findings (JSON): ${JSON.stringify(findings, null, 1)}
Return done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final, build: b }
