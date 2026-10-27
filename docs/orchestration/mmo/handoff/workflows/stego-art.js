export const meta = {
  name: 'deadfront-stego-art',
  description: 'STEGO-ART (0 credits): trim the Stegosaurus v2 thagomizer to four spikes and shift the hide toward the PRD green-brown in headless Blender, keeping the rig and clips; reviewer, blind judge, fix loop',
  phases: [{ title: 'Build', detail: 'mesh and texture fix' }, { title: 'Review', detail: 'reviewer, blind judge, fix' }],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const BAKE = '/Users/milankinzy/Documents/deadfront-dsc-work/bakeoff'
const BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'
const WT = `${REPO}/.claude/worktrees/mmo-stego-art`
const ctx = `Project: DEADFRONT, a Godot 4.7.1 dinosaur survival MMO (game/ is the project) at an ARK: Survival Ascended creature bar; judged in desktop Chrome at 1600x900 (gl_compatibility) and on landscape phones (844x390).
Package STEGO-ART (0 credits). The Stegosaurus v2 (Tripo mesh, 34-bone rig, 9 skeleton-only clips; game/assets/creatures/stegosaurus/) now shows in game on branch claude/mmo-stego (its review passed; it removes the old placeholder override). Two asset faults: (1) the thagomizer fans about 7 spikes like a starburst; a Stegosaurus has FOUR (two pairs, angled up and back) - the owner's approved journal art insists on "exactly four spikes" (assets/concept-art/INDEX.md, combat knockback row); (2) the hide reads grey-blue; the PRD (docs/prd/dinosaur-roster-and-3d-pipeline.md, the stegosaurus row) and the approved concept sheet (assets/concept-art/creatures/stegosaurus/) want the green-brown colouring - read them and match the sheet.
Branch claude/mmo-stego-art from claude/mmo-stego, work tree ${WT} (create: bash ${OSP}/mkwt.sh stego-art, then git checkout -B claude/mmo-stego-art claude/mmo-stego there, and apply docs/orchestration/reports/claude-mmo-stego-hooks.patch uncommitted so the game path shows v2). Headless Blender only (${BLENDER} -b --factory-startup -P <script>), every script committed under tools/blender/stegosaurus_art/ so the change is reproducible from the committed v2 GLB. Keep the 34-bone skeleton, bone names, bind pose, weights of everything you keep, UVs and the 9 clips untouched; remove the extra spike geometry cleanly (no holes, no floating fragments, tail tip closed) and keep four spikes on the tail bones with their weights; shift the base colour map toward the sheet's palette (hue/saturation/value on the albedo; plates may keep a contrasting tone if the sheet shows one), roughness unchanged unless the look needs it. Keep the old GLB and texture under game/assets/creatures/stegosaurus/v2a/ for comparison only if the asset register asks for it; otherwise git history is enough.
Gates: creature-verify.mjs (in ${BAKE}, as Stegosaurus v2 used it) ALL HARD CHECKS PASSED; --import after replacing assets (0 errors, 0 "couldn't resolve track"); t_stego (from claude/mmo-stego) PASS; every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs), run_all [tests] PASS, smoke SMOKE PASS; stego_lab windowed on home_grassland and temperate_45 at 1600x900 Forward+ and gl_compatibility and 844x390: idle, walk, attack (tail swing), dead, iso - open every PNG; plus a close rear-3/4 render of the tail in headless Blender showing exactly four spikes. Godot only through ${OSP}/gslot.sh with its own timeout (perl -e 'alarm N; exec @ARGV'), silent, never --editor. Rules: never touch the owner's real save, ${REPO}'s main checkout, ~/Documents/deadfront or other packages' worktrees; throwaway trees via bash ${SP}/mkscratch.sh <name> <ref> (reuse names); commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"), never git add -A; never push, merge or deploy; never use SendMessage; never claim a check you did not run. Report docs/orchestration/reports/claude-mmo-stego-art.md.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' }, spikes: { type: 'number' },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: PAIR }, summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'spikes', 'findings', 'pairs', 'summary'] }
const JUDGE = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } }, overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

phase('Build')
let b = await agent(`${ctx}\n\nROLE: builder. Do the package to its gates, look at every render and shot, write the report, commit. Return done, head, gates, shots, summary.`, { label: 'build', phase: 'Build', schema: STEP })
if (!b) return { stopped: 'cut at build' }
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}\n\nROLE: independent, demanding reviewer (round ${round}). You did not build it; do not edit ${WT}; probes under ${SP}/review/stego-art/r${round}/ (bash ${SP}/mkscratch.sh rev-stego-art claude/mmo-stego-art, then apply the STEGO hooks patch). Count the thagomizer spikes yourself in a close render (return the number in "spikes"); look for holes, floating fragments, stretched or torn tail skin in every clip frame by frame (attack swings the tail); compare the hide with the approved sheet; rerun every gate. Take matched BEFORE (claude/mmo-stego with its hooks) / AFTER shots at the same moments: idle side, walk side, attack rear 3/4 (tail visible), iso camera, phone 844x390; return them in "pairs" and look at all of them. pass=true only with exactly 4 spikes, zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review', final }
  const findings = (rv.findings || []).slice()
  let pass = rv.pass && rv.spikes === 4
  if (rv.spikes !== 4) findings.push({ severity: 'blocker', where: 'thagomizer', problem: `Reviewer counted ${rv.spikes} spikes.`, fix: 'Exactly four.' })
  let ab = null
  if (pass && rv.pairs && rv.pairs.length) {
    const pr = rv.pairs.map((p, i) => i % 2 === 0 ? { scene: p.scene, first: p.after, second: p.before } : { scene: p.scene, first: p.before, second: p.after })
    const j = await agent(`You are a blind creature art director for a dinosaur survival game at the ARK: Survival Ascended bar. For each scene, open both images with the Read tool; you are NOT told which build is newer; ignore file names. Judge which Stegosaurus looks better as a shipped game asset (anatomy - a Stegosaurus has four tail spikes -, silhouette, believable colouring, materials, no artefacts). first/second/tie with reasons.\n${pr.map((p, i) => `Scene ${i + 1} "${p.scene}": first=${p.first} second=${p.second}`).join('\n')}`, { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (j) {
      let aw = 0, bw = 0
      j.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'first') === (i % 2 === 0)) ? aw++ : bw++ })
      ab = { afterWins: aw, beforeWins: bw, overall: j.overall }
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind judge', problem: `New did not win (new ${aw}, old ${bw}). ${j.overall} ${JSON.stringify(j.verdicts)}`, fix: "Address the judge's reasons." }) }
    }
  }
  final = { round, pass, ab, reviewed_sha: rv.reviewed_sha, summary: rv.summary, findings }
  log(`STEGO-ART review r${round}: ${pass ? 'PASS' : 'not yet'} (spikes ${rv.spikes})`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}\n\nROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors, rerun the gates and renders, look at them, update the report, commit. If a finding is wrong, show evidence.\nFindings (JSON): ${JSON.stringify(findings, null, 1)}\nReturn done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final }
