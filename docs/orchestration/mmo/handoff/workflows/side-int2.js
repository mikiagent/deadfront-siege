export const meta = {
  name: 'deadfront-side-integrate-v2',
  description: 'Faster side integrator: every pre-merge fix in parallel on its own branch, then merge in batches (up to 3 packages per batch, gates once per batch) into claude/mmo-overhaul, dropping a package that breaks its batch; waits while finish-6 integrates; push',
  phases: [
    { title: 'Fix', detail: 'pre-merge fixes in parallel' },
    { title: 'Integrate', detail: 'batched merges, every gate once per batch, push' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const BASE = `${REPO}/.claude/worktrees/mmo-overhaul`
const OWNER = '/Users/milankinzy/Documents/deadfront'
const F6 = '/Users/milankinzy/.claude/projects/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/subagents/workflows/wf_c321f8a4-028/journal.jsonl'
const RULES = `Rules: Godot only through ${OSP}/gslot.sh with its own timeout (perl -e 'alarm N; exec @ARGV'), silent, never --editor; --import (alarm 900) after merging assets or class_name files. Keep game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER} (except the final ff pull), or other packages' worktrees. Commit messages end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Never use SendMessage. Never claim a check you did not run; quote decisive lines. Look at every PNG you cite. The owner wants a shippable game on Vercel soon: be fast, but never skip a gate.`
const FIX = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const INT = { type: 'object', properties: { merged: { type: 'array', items: { type: 'string' } }, dropped: { type: 'array', items: { type: 'object', properties: { key: { type: 'string' }, reason: { type: 'string' } }, required: ['key', 'reason'] } }, sha: { type: 'string' }, pushed: { type: 'boolean' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['merged', 'dropped', 'summary'] }

const PKGS = (args && args.pkgs) || []
const BATCH = (args && args.batch) || 3

phase('Fix')
const fixed = await parallel(PKGS.map(p => async () => {
  if (!p.fix) return { p, ok: true }
  const fx = await agent(`Project: DEADFRONT (Godot 4.7.1 typed GDScript, game/ is the project). Package ${p.label}, branch ${p.branch}, work tree ${p.wt}. It passed independent review${p.visual ? ' and a blind A/B judge' : ''}; before it merges the orchestrator ruled these small changes:\n${p.fix}\nFirst merge claude/mmo-overhaul into the branch (it has moved: other packages merged) and resolve conflicts keeping both sides' intent. If the work tree has uncommitted changes from an interrupted earlier fix, review them first: keep what fits the fix list, discard the rest. Make the changes on the branch (files the package owns, or its hooks patch ${p.hooks || '(none)'} for others' files, regenerated so it applies clean on claude/mmo-overhaul), add or adjust a test that fails on the old behaviour, rerun the package's own tests and labs, every t_*.gd, run_all and smoke in a throwaway tree with the hooks (bash ${SP}/mkscratch.sh fix-${p.key} ${p.branch} ${p.hooks || ''}), look at the shots the fix list asks for, update the report, commit. Other packages are fixed in parallel on their own branches; touch only this one.\n${RULES}\nReturn done, head, gates, summary.`, { label: `fix:${p.key}`, phase: 'Fix', schema: FIX })
  return { p, ok: !!(fx && fx.done), fx }
}))
const ready = fixed.filter(Boolean).filter(f => f.ok).map(f => f.p)
const notFixed = fixed.filter(Boolean).filter(f => !f.ok).map(f => ({ key: f.p.key, reason: 'pre-merge fix not done', fx: f.fx && f.fx.summary }))
log(`fixed: ${ready.map(p => p.key).join(', ') || 'none'}; not fixed: ${notFixed.map(n => n.key).join(', ') || 'none'}`)

phase('Integrate')
const out = { merged: [], dropped: notFixed.slice(), batches: [] }
const landed = new Set()
let queue = ready.slice()
while (queue.length) {
  // a package whose dependency was dropped or is not in this run waits for a later run
  const batch = []
  for (const p of queue) {
    if (batch.length >= BATCH) break
    if (p.needs && !(landed.has(p.needs) || batch.some(b => b.key === p.needs))) continue
    batch.push(p)
  }
  if (!batch.length) { queue.forEach(p => out.dropped.push({ key: p.key, reason: `needs ${p.needs}, which did not land` })); break }
  queue = queue.filter(p => !batch.includes(p))
  const names = batch.map(p => p.label).join(', ')
  const r = await agent(`Project: DEADFRONT (Godot 4.7.1 typed GDScript, game/ is the project). You are the SIDE INTEGRATOR for a BATCH of ${batch.length} reviewed packages, merged together with one gate run: ${names}. Another integrator (finish-6) also merges into claude/mmo-overhaul (work tree ${BASE}); you must not collide with it.
${RULES}
Packages, in merge order:
${batch.map((p, i) => `${i + 1}. ${p.label}: branch ${p.branch}${p.hooks ? ', hooks patch ' + p.hooks : ''}${p.visual ? ' (visual; passed a blind A/B)' : ''}`).join('\n')}
Procedure:
1. Wait while finish-6's integrator runs: it is running when its journal ${F6} has a line with "type":"started" and a label starting "integrate:" whose key has no later "type":"result" line. Check with a short script; if running, sleep in a background loop (max 30 min per wait) and re-check; never touch ${REPO}/.claude/worktrees/mmo-int (finish-6's scratch).
2. Scratch tree: bash ${SP}/mkscratch.sh side-int claude/mmo-overhaul (reuse the name). git checkout -B claude/mmo-side-int. For each package in order: git merge --no-ff <branch> -m "Merge <label>: <what it gives the player> (review pass; blind A/B for visual packages)" + trailer; resolve conflicts keeping both sides' intent (many packages hook hunt_hud.gd, player_input.gd, player_sim.gd - keep every merged feature); then apply its hooks patch if any (git apply --3way; fix trivial drift) and commit "Apply <label> integrator hooks"; register its tests/labs where its report asks. Note the commit after each package so you can drop one.
3. --import, then EVERY game/tests/t_*.gd, run_all ([tests] PASS), tools/smoke.sh --no-import (SMOKE PASS), --lab=island_lab headless (exit 0, 0 SCRIPT ERROR, counts unchanged unless intended), build_lab, each package's own tests/labs, 0 "couldn't resolve track", no new Godot .ips. Pixels: windowed home_lab 1600x900 Forward+ and gl_compatibility and 844x390, plus each package's own scene, under ${SP}/side-int/<key>-*.png; look at them; a visible regression is a failure. MOTION GATE (owner: "watch out for glitchy movement of UI and player"): 3 s frame sequence of the survivor walking past resource nodes on home_lab with the HUD up (and each UI package's screen open): a HUD element, label or radial that jumps or swaps sides between frames, or a player position/rotation pop, that the base does not show, is a failure - report measured per-frame deltas.
4. A failure: find which package causes it (rerun the failing gate with that package's merge reverted in a throwaway branch). Fix it yourself only if it is a merge-level conflict; otherwise drop that package (rebuild claude/mmo-side-int without it), list it in dropped with the evidence, and rerun the gates for the rest.
5. Land: re-check step 1; git -C ${REPO} fetch; if claude/mmo-overhaul moved since your merge, merge it into claude/mmo-side-int and rerun EVERY t_*.gd, run_all and smoke. Then git -C ${BASE} merge --ff-only claude/mmo-side-int (move untracked files that block it to ${SP}/moved-imports/, never delete). Append one line per merged package "- $(date +%F) merged <label> (<short sha>): <decisive gate lines>; review pass; side integrator, batch with <others>" to the "## Merge log" at the end of ${BASE}/docs/orchestration/mmo/STATUS.md, commit in ${BASE}, git -C ${BASE} push origin claude/mmo-overhaul, push each merged package branch; if git -C ${OWNER} status --porcelain --untracked-files=no is empty, git -C ${OWNER} pull --ff-only.
Return merged (keys), dropped ({key, reason}), sha, pushed, gates, shots, summary.`, { label: `integrate:${batch.map(p => p.key).join('+')}`, phase: 'Integrate', schema: INT, effort: 'high' })
  if (!r) { out.dropped.push(...batch.map(p => ({ key: p.key, reason: 'integrator cut' }))); break }
  ;(r.merged || []).forEach(k => { landed.add(k); out.merged.push(k) })
  ;(r.dropped || []).forEach(d => out.dropped.push(d))
  out.batches.push({ keys: batch.map(p => p.key), sha: r.sha, merged: r.merged, dropped: r.dropped, summary: r.summary })
  log(`batch ${batch.map(p => p.key).join('+')}: merged ${(r.merged || []).join(', ') || 'none'} ${r.sha || ''}`)
}
return out
