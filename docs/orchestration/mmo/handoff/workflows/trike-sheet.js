export const meta = {
  name: 'deadfront-trike-sheet',
  description: 'TRIKE concept sheet: up to two more fix rounds against the paleo-art critic (front horns, true top view, neutral stance, json length to the PRD 9 m), then hand it to the owner',
  phases: [{ title: 'Sheet', detail: 'fix, critic, fix, critic' }],
}
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const WT = `${REPO}/.claude/worktrees/mmo-trike`
const SHEET = `${WT}/assets/concept-art/creatures/triceratops/concept-sheet-v01.png`
const REVIEWCOPY = `${WT}/assets/concept-art/creatures/triceratops/concept-sheet-v01-review.png`
const DEINO = `${WT}/assets/concept-art/creatures/deinonychus/concept-sheet-v01.png`
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, credits: { type: 'number' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const CRIT = { type: 'object', properties: { pass: { type: 'boolean' }, notes: { type: 'string' } }, required: ['pass', 'notes'] }
const ctx = `Project: DEADFRONT, a Godot 4.7.1 dinosaur survival MMO at an ARK: Survival Ascended creature bar. Package TRIKE, concept stage only: branch claude/mmo-trike, work tree ${WT} (exists; stay on that branch). The owner rejected the DeepSeek bake-off Triceratops builds; the Triceratops goes the Stegosaurus v2 route (Tripo multiview mesh + rig), and the OWNER must approve the concept sheet before any Tripo spend. Sheet: ${SHEET} (clean, generation input: no labels, no figures) plus the labelled review copy ${REVIEWCOPY}. Make changes the way the earlier rounds did (see git log and the provenance rows in assets/concept-art/INDEX.md; same tools, no paid credits; never buy anything; if a route needs a paid balance you cannot confirm, stop and report). Rules: do NOT call Tripo, Meshy or any paid generator; never touch the owner's real save, ${REPO}'s main checkout, ~/Documents/deadfront or other packages' worktrees; commit only the sheet files, INDEX.md rows and the json fix ("Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"); never git add -A; never push, merge or deploy; never use SendMessage; never claim a check you did not run; look at every image you produce.`
const critic = (r) => `You are a paleo-art director for a dinosaur survival game at the ARK: Survival Ascended bar. Open with the Read tool the Triceratops concept sheet ${SHEET}, its review copy ${REVIEWCOPY}, and the approved Deinonychus sheet ${DEINO}. This sheet is the input to a Tripo multiview 3D generation, so every view must agree. Judge: correct Triceratops anatomy (two long brow horns, a short nasal horn, a solid frill with epoccipitals, a beak, hips at or above the shoulders, heavier hind legs); the SAME individual in every view; the FRONT view's brow horns are foreshortened cones pointing toward the camera, consistent with the side and top views; the TOP view is a true orthographic top-down (left-right symmetric, both sides' feet equal, a smooth barrel outline); a neutral standing pose (or the same gait in every view); no cropping; style consistent with the approved sheet; the review copy shows the scale at the PRD's 9 m. Measure in pixels where it helps. pass true only if a multiview generator would get one consistent animal. Round ${r}. Concrete fixes if not.`
let notes = args.critic
let last = null
for (let r = 2; r <= 3; r++) {
  const fx = await agent(`${ctx}\n\nROLE: builder, sheet fix round ${r}. A paleo-art director said:\n${notes}\nFix every blocking item (and the cheap non-blocking ones). Item 6: set game/data/creatures/triceratops.json real_length_m to the PRD's 9.0 (docs/prd/dinosaur-roster-and-3d-pipeline.md ~line 57) and redo the review copy's scale figure with one 1.8 m human at 9 m; grep for anything that reads real_length_m for this species and note in the report what the change affects in game (do not change game code). Keep what passes; do not redraw from scratch unless a targeted fix cannot work. Look at the result full size and in crops of the front head and the top view, update INDEX.md (still DRAFT, awaiting owner approval), commit. Return done, head, credits, gates, shots (the sheet paths), summary.`, { label: `sheetfix:r${r}`, phase: 'Sheet', schema: STEP })
  if (!fx) return { ready: false, stopped: `cut at sheet fix r${r}`, last }
  const cr = await agent(critic(r + 1), { label: `sheetcritic:r${r + 1}`, phase: 'Sheet', schema: CRIT })
  if (!cr) return { ready: false, stopped: `cut at critic r${r + 1}`, last }
  last = { round: r + 1, head: fx.head, fix: fx.summary, critic: cr.notes }
  if (cr.pass) return { ready: true, sheet: SHEET, review: REVIEWCOPY, ...last }
  notes = cr.notes
}
return { ready: false, sheet: SHEET, review: REVIEWCOPY, ...last }
