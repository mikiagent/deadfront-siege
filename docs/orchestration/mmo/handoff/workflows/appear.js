export const meta = {
  name: 'deadfront-appear-a',
  description: 'APPEAR-A (0 credits): split the v2 survivor hair into its own piece (bald/buzz/short crop), shell-cut the helmets, facial-hair and feature decals and two shell beards; headless Blender; verifier, clip and portrait gates; ugly-test judge',
  phases: [
    { title: 'Build', detail: 'P2 hair split, P3 helmet shells, P4 face decals and beards' },
    { title: 'Review', detail: 'independent reviewer, blind ugly-test judge, fix loop' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const WT = `${REPO}/.claude/worktrees/mmo-appear`
const BR = 'claude/mmo-appear'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'
const PLAN = `${REPO}/.claude/worktrees/mmo-overhaul/docs/orchestration/mmo/char-appearance-plan.md`
const INSPECT = `${SP}/char-appearance/out`
const REPORT = 'docs/orchestration/reports/claude-mmo-appear.md'
const ctx = `Project: DEADFRONT, a Godot 4.7.1 dinosaur survival MMO (game/ is the project) at an ARK: Survival Ascended visual bar. Owner: character creation with "height, hairstyles, skin color, facial hair/features" and "outfit color" (spec ${OWNER}/docs/design/durango-prompts/19_character_creation.md - NOTE its gender line is wrong: the shipped survivor v2 (game/assets/characters/survivor/survivor.glb, Tripo, 65 Mixamo bones, 29 clips, 3 armour kits) is a MAN; the woman was v1).
Read the plan ${PLAN} (phases P2, P3, P4 are this package; P1 masks belong to CHARCREATE; P5-P8 need the owner) and look at the inspection renders in ${INSPECT}/.
Package APPEAR-A: branch ${BR}, work tree ${WT} (create: bash ${OSP}/mkwt.sh appear). Report ${REPORT}. 0 credits: no Tripo, Meshy or image generation; headless Blender only (${BLENDER} -b --factory-startup -P <script>), every script committed under tools/blender/survivor_appearance/ so results are reproducible.
Scope:
- P2 HAIR SPLIT: cut the baked hair shell (about 3.7k tris, 1.4-1.6 cm above the scalp) into its own skinned piece on the 65-joint bind (weights on Head/HeadTop_End), leaving a bald head; trim one ring at the hairline and repaint the scalp; options: current hair, buzz (stubble scalp repaint), bald (skin scalp), short crop (scalp pushed out 6-10 mm with a strand texture). Each option is a skinned GLB that attaches through the same path armour kit pieces use (RiggedModel.attach_skinned / PlayerEquipment regions - add a 'hair' region through the hooks patch); the default look stays exactly as today.
- P3 HELMET SHELLS: re-extract the forager and hide_and_bone helmets as shells (no face shards, no floating spikes, closed crown) so the chosen hair, skin and beard show under them; kit.json hides ['hair'] where the helmet covers it.
- P4 FACE: inpaint a clean-shaven jaw; facial-hair decals (stubble = current, heavy stubble, moustache, goatee) project-baked into an alpha mask tinted by hair colour; two shell beards (short full, long) from the beard-zone faces pushed out 6-12 mm, rigid on Head; feature decals (3 brow shapes, brow scar, cheek scar, freckles, face paint, age lines) baked the same way.
- Data: list every option for CHARCREATE's data-driven slots (game/data/characters/appearance.json: id, name, scene/mesh path, attach bone/region, genders) - CHARCREATE (branch claude/mmo-charcreate) creates that file; put your rows in the report and, if the file exists on the base when you sync, add them there; otherwise in the hooks patch docs/orchestration/reports/claude-mmo-appear-hooks.patch.
Gates: every option renders front/side/3-4/portrait in headless Blender with neutral light AND in Godot (a lab or probe at 1600x900 gl_compatibility and Forward+ and 844x390) next to the unchanged base; every one of the 29 clips still plays with each option attached (0 "couldn't resolve track"); no clipping of hair/beard through helmets or the head in the walk, run, attack and gather clips (measure penetration on sampled frames); default appearance pixel-identical to today in the home_lab shot; every t_*.gd, run_all, smoke PASS. Godot only through ${OSP}/gslot.sh with its own timeout (perl alarm), silent, never --editor; --import after adding assets.
Rules: never touch the owner's real save, ${REPO}'s main checkout, ${OWNER}, or other packages' worktrees (many workflows run); throwaway trees via bash ${SP}/mkscratch.sh <name> <ref> (reuse names; disk is tight). Commit often ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A (no previews in the repo); never push, merge or deploy; never use SendMessage; never claim a check you did not run.`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const REVIEW = { type: 'object', properties: { pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  portraits: { type: 'array', items: { type: 'object', properties: { option: { type: 'string' }, path: { type: 'string' } }, required: ['option', 'path'] } },
  summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'portraits', 'summary'] }
const UGLY = { type: 'object', properties: { verdicts: { type: 'array', items: { type: 'object', properties: { option: { type: 'string' }, ok: { type: 'boolean' }, notes: { type: 'string' } }, required: ['option', 'ok', 'notes'] } } }, required: ['verdicts'] }

const STEPS = [
  { key: 'p2', text: 'P2 hair split and the four hair options.' },
  { key: 'p3', text: 'P3 helmet shells (forager, hide_and_bone) so hair, skin and beards show correctly under them.' },
  { key: 'p4', text: 'P4 clean-shaven inpaint, facial-hair decals, two shell beards and the feature decals; then the appearance rows and the full gate set.' },
]
phase('Build')
for (const st of STEPS) {
  const r = await agent(`${ctx}\n\nROLE: builder, step ${st.text} Read the plan, git log and the report first (earlier steps may be done). Do the step, run its gates, look at every render, update the report, commit. Return done, head, gates, shots, summary.`, { label: `build:${st.key}`, phase: 'Build', schema: STEP })
  if (!r) return { stopped: 'cut at ' + st.key }
}
phase('Review')
let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}\n\nROLE: independent, demanding reviewer (round ${round}) of APPEAR-A. You did not build it; do not edit ${WT}; probes under ${SP}/review/appear/r${round}/ (bash ${SP}/mkscratch.sh rev-appear ${BR}). Rerun every gate yourself; try to break it (every option x every clip, helmets on/off, the default look unchanged, skinning weights at the neck, decal seams in the portrait, frame cost). Return portrait renders (head and shoulders, neutral light) of EVERY option next to the base in "portraits"; look at all of them. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review' }
  const findings = (rv.findings || []).slice()
  if (!rv.pass) (rv.acceptance || []).filter(a => !a.met).forEach(a => findings.push({ severity: 'major', where: 'acceptance', problem: `Unmet: ${a.item} - ${a.evidence}`, fix: 'Meet it.' }))
  let pass = rv.pass
  if (rv.portraits && rv.portraits.length) {
    const ug = await agent(`You are an art director for a survival game at the ARK: Survival Ascended character bar. Open each portrait with the Read tool: ${rv.portraits.map(p => p.option + ' = ' + p.path).join(' ; ')}. For each option, would a player accept it as a shipped character customization option next to the base face (no blobby or smeared hair or beard, no visible seams, no floating pieces, believable materials)? ok true/false with concrete notes.`, { label: `ugly:r${round}`, phase: 'Review', schema: UGLY })
    if (ug) { const bad = ug.verdicts.filter(v => !v.ok); if (bad.length) { pass = false; findings.push({ severity: 'major', where: 'ugly-test judge', problem: bad.map(v => v.option + ': ' + v.notes).join(' | '), fix: 'Fix each, or drop an option that cannot reach the bar and say so in the report.' }) } }
  } else { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no portrait renders', fix: 'render them' }) }
  final = { round, pass, summary: rv.summary, findings }
  log(`APPEAR-A review r${round}: ${pass ? 'PASS' : 'not yet'}`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}\n\nROLE: builder, fix round ${round}. Fix every blocker and major and the cheap minors, rerun the gates and renders, look at them, update the report, commit. If a finding is wrong, show evidence.\nFindings (JSON): ${JSON.stringify(findings, null, 1)}\nReturn done, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix', final }
}
return { ready: !!(final && final.pass), final }
