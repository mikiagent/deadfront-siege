export const meta = {
  name: 'deadfront-side-integrate',
  description: 'Serialized side integrator: for each ready side package (args), an optional pre-merge fix, then merge into claude/mmo-overhaul in its own scratch tree with every gate and the merge shots, waiting while finish-6\'s integrator runs; push',
  phases: [
    { title: 'Fix', detail: 'small pre-merge fixes the orchestrator ruled' },
    { title: 'Integrate', detail: 'one package at a time: merge, hooks, every gate, pixels, push' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const BASE = `${REPO}/.claude/worktrees/mmo-overhaul`
const OWNER = '/Users/milankinzy/Documents/deadfront'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const F6 = '/Users/milankinzy/.claude/projects/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/subagents/workflows/wf_c321f8a4-028/journal.jsonl'
const RULES = `Rules: Godot only through ${OSP}/gslot.sh with its own timeout (perl -e 'alarm N; exec @ARGV'), silent, never --editor; --import (alarm 900) after merging assets or class_name files. Keep game/override.cfg; never touch the owner's real save, ${REPO}'s main checkout, ${OWNER} (except the final ff pull), or other packages' worktrees. Commit messages end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Never use SendMessage. Never claim a check you did not run; quote decisive lines. Look at every PNG you cite.`
const FIX = { type: 'object', properties: { done: { type: 'boolean' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'head', 'summary'] }
const INT = { type: 'object', properties: { merged: { type: 'boolean' }, sha: { type: 'string' }, pushed: { type: 'boolean' }, gates: { type: 'array', items: { type: 'string' } }, failures: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['merged', 'summary'] }

const PKGS = args || []
const out = []
for (const p of PKGS) {
  if (p.fix) {
    const fx = await agent(`Project: DEADFRONT (Godot 4.7.1 typed GDScript, game/ is the project). Package ${p.label}, branch ${p.branch}, work tree ${p.wt}. It passed independent review; before it merges the orchestrator ruled these small changes:\n${p.fix}\nMake them on the branch (files the package owns, or its hooks patch ${p.hooks || '(none)'} for others' files, regenerated apply-clean on claude/mmo-overhaul), add or adjust a test that fails on the old behaviour, rerun the package's tests, every t_*.gd, run_all and smoke in a throwaway tree with the hooks (bash ${SP}/mkscratch.sh fix-${p.key} ${p.branch} ${p.hooks || ''}), update the report, commit.\n${RULES}\nReturn done, head, gates, summary.`, { label: `fix:${p.key}`, phase: 'Fix', schema: FIX })
    if (!fx || !fx.done) { out.push({ key: p.key, merged: false, reason: 'pre-merge fix not done', fx }); continue }
  }
  const r = await agent(`Project: DEADFRONT (Godot 4.7.1 typed GDScript, game/ is the project). You are the SIDE INTEGRATOR for ${p.label} (branch ${p.branch}${p.hooks ? ', hooks patch ' + p.hooks : ''}), which passed independent review${p.visual ? ' and a blind A/B judge' : ''}. Another integrator (finish-6) also merges into claude/mmo-overhaul (work tree ${BASE}); you must not collide with it.
${RULES}
Procedure:
1. Wait while finish-6's integrator runs: it is running when its journal ${F6} has a line with "type":"started" and a label starting "integrate:" whose key has no later "type":"result" line. Check with a short script; if running, sleep in a background loop (max 30 min per wait) and re-check; never touch ${REPO}/.claude/worktrees/mmo-int (finish-6's scratch).
2. Your scratch tree: bash ${SP}/mkscratch.sh side-int claude/mmo-overhaul (reuse the name). In it: git checkout -B claude/mmo-side-int; git merge --no-ff ${p.branch} -m "Merge ${p.label}: <what it gives the player> (review pass${p.visual ? ', blind A/B' : ''})" + trailer; resolve conflicts keeping both sides' intent (many side packages hook hunt_hud.gd / player files - keep every merged feature); ${p.hooks ? `apply the hooks patch ${p.hooks} (git apply --3way; fix trivial drift) and commit "Apply ${p.label} integrator hooks";` : ''} register its tests/labs where its report asks.
3. --import, then EVERY game/tests/t_*.gd, run_all ([tests] PASS), tools/smoke.sh --no-import (SMOKE PASS), --lab=island_lab headless (exit 0, 0 SCRIPT ERROR, counts unchanged unless intended), build_lab, the package's own tests/labs, 0 "couldn't resolve track", no new Godot .ips. Pixels: windowed home_lab 1600x900 Forward+ and gl_compatibility and 844x390, plus the package's own scene, under ${SP}/side-int/${p.key}-*.png; look at them; a visible regression is a failure. MOTION GATE (owner: "watch out for glitchy movement of UI and player"): record a 3 s frame sequence (every frame's positions logged, plus a few PNGs) of the survivor walking past resource nodes on home_lab with the HUD up and, if the package is UI, with its screen open; any HUD element, label or radial that jumps or swaps sides between frames, or a player position/rotation pop, is a failure - report the measured per-frame deltas.
4. A failure caused by the merge you fix; one caused by the package: stop, return merged=false with failures.
5. Land: re-check step 1 (wait if finish-6's integrator started); git -C ${REPO} fetch; if claude/mmo-overhaul moved since your merge, merge it into claude/mmo-side-int and rerun EVERY t_*.gd, run_all and smoke. Then git -C ${BASE} merge --ff-only claude/mmo-side-int (move untracked files that block it to ${SP}/moved-imports/, never delete). Append "- $(date +%F) merged ${p.label} (<short sha>): <decisive gate lines>; review pass${p.visual ? '; blind A/B <score>' : ''}; side integrator" to the "## Merge log" at the end of ${BASE}/docs/orchestration/mmo/STATUS.md, commit in ${BASE}, git -C ${BASE} push origin claude/mmo-overhaul, git -C ${REPO} push origin ${p.branch}; if git -C ${OWNER} status --porcelain --untracked-files=no is empty, git -C ${OWNER} pull --ff-only.
Return merged, sha, pushed, gates, failures, shots, summary.`, { label: `integrate:${p.key}`, phase: 'Integrate', schema: INT, effort: 'high' })
  out.push({ key: p.key, merged: !!(r && r.merged), sha: r && r.sha, summary: r && r.summary, failures: r && r.failures })
  log(`${p.label}: ${r && r.merged ? 'MERGED ' + r.sha : 'not merged'}`)
}
return out
