export const meta = {
  name: 'deadfront-exchange',
  description: 'W3-EXCHANGE: Durango Island Market screens (HUD > Main Menu > Island Market > Buy / My Market / Sell) on the real ECON engine; scout, design, phased build, reviewer + fidelity judge vs the Durango market references',
  phases: [
    { title: 'Scout', detail: 'menu/UI, ECON API and transport, docs' },
    { title: 'Design', detail: 'spec, transport decision, gates, worktree' },
    { title: 'Build', detail: 'shell+Buy, Sell, My Market, polish' },
    { title: 'Review', detail: 'independent reviewer, fidelity judge, fix loop' },
  ],
}

const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const R = `${REPO}/.claude/worktrees`
const WT = `${R}/mmo-exchange`
const BR = 'claude/mmo-exchange'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const GSLOT = `${OSP}/gslot.sh`
const MKWT = `${OSP}/mkwt.sh`
const MKS = `${SP}/mkscratch.sh`
const REFS = `${OWNER}/docs/reference/durango-market-buy-search.webp (Buy with a search chip) and ${OWNER}/docs/reference/durango-market-buy-taming.webp (Buy with the Taming Materials category column and caged pets)`
const DESIGN = 'docs/orchestration/mmo/exchange-spec.md'
const REPORT = 'docs/orchestration/reports/claude-mmo-exchange.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-exchange-hooks.patch'
const ECON_HOOKS = 'docs/orchestration/reports/claude-mmo-econ-hooks.patch'

const RULES = `
Shared rules (binding):
- Godot: ${G} (4.7.1 Mono; game/ is the project). Run EVERY Godot command through ${GSLOT} with its own timeout, from your tree (e.g. ${GSLOT} perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_exchange.gd). gslot holds one of 5 machine-wide slots shared with two other running workflows, forces silent audio (never play audio) and caps runs at 20 min; start long runs with run_in_background rather than blocking a foreground call past 10 minutes. Never pass --editor. Run one --import (alarm 900) after adding class_name files or assets.
- Pixels: windowed runs only (${G} --path game --resolution 1600x900 -- --lab=<lab> --shot=<png> --shot-delay=6; add --rendering-method gl_compatibility for the web renderer, which is the judge; phones are LANDSCAPE 844x390). Open every PNG with the Read tool and compare it with the Durango references before claiming anything visual.
- Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs, as on base); run_all.gd [tests] PASS; tools/smoke.sh --no-import SMOKE PASS; the economy tests on the branch; the package labs with 0 SCRIPT ERROR lines; no new ~/Library/Logs/DiagnosticReports/Godot-*.ips.
- Isolation: keep the git-excluded game/override.cfg; never touch ~/Library/Application Support/Godot/app_userdata (the owner's real save), the owner's checkouts ${REPO} and ${OWNER}, or other packages' worktrees. Throwaway trees: bash ${MKS} <name> <ref> [patch relative to the tree].
- Code: typed GDScript in the house style, class_name per file, short why-comments, no new autoloads or third-party deps, no god-file growth, presentation separate from authority. Tests are SceneTree scripts that load classes via load() inside functions and must fail on the old behaviour.
- NOTHING FAKE (owner): every Buy, Sell, cancel and Receive moves real items, currency and ownership through the ECON engine's single client relay (VaultBridge.client, see the ECON report); the UI never invents listings, prices or buyers; where no server runs, say so honestly (spec 06: an honest harness with simulated buyers - ECON's Settlers - never a falsely represented live market). Market defaults (0.25x-4x bands, fees, 30-min trade lock) come from ECON's data. No monetization: no "+" purchase button (a control that does nothing is not shown).
- No downloads; use the project's fonts, rendered item icons (ItemArt/ArtSlot, game/assets/icons/render, captured_animal / tamed_animal cage renders) and the white UI icons (game/data/ui_icons.json); procedural textures only.
- Ownership: this package owns game/scripts/ui/market/ (new), its lab and tests, ${DESIGN}, ${REPORT}. Economy files (ECON, merging separately), integrator-only files (game/scripts/core/{game,main,world}.gd, game/project.godot, game/tests/run_all.gd, game/scripts/ui/touch_controls.gd) and other packages' files (incl. hunt_hud.gd's main menu) get exact compiling changes in ${HOOKS}. Other packages are being fixed right now by other workflows (ECON, W2-INV, INVUI on claude/mmo-invui, ...): never edit their branches or worktrees. Reuse INVUI's components (claude/mmo-invui: slot, icon, level label, brackets, inspect panel, the exact-instance picker, the theme) when they exist; if not yet, build the minimum the market needs in its own files with the same look and note what to swap later.
- Base: this branch is stacked on claude/mmo-econ (the engine, still being fixed). At the start of every step: if git log claude/mmo-overhaul shows ECON merged, git merge claude/mmo-overhaul; otherwise git merge claude/mmo-econ and re-apply any change in ECON's hooks patch (${ECON_HOOKS}) since the commit "Apply ECON hooks (EXCHANGE base)". Resolve conflicts keeping both intents.
- Design truth: the owner's navigation "Gameplay HUD → Main Menu → Island Market → Buy / My Market / Sell", docs/design/durango-prompts/14_island_market_ui.md and the two references (${REFS}) are the newest owner input; spec 06, spec 13 (shared Durango look), docs/design/economy.md, contracts.md sections 0, 4-6 and 8, STATUS owner decisions and GAUNTLET.md's UI rules (white actions, coloured things, targets 44 px+, landscape 844x390, desktop 1600x900 gl_compatibility is the judge) also bind. Do not invent species or categories: market categories come from item data (market_category) and the real species roster; mark mapping choices # ASSUMPTION.
- Commit early and often; messages end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Never git add -A; never commit override.cfg, .godot/ or import/uid churn you did not create; no preview PNGs in the repo. Never push, never merge into claude/mmo-overhaul, never deploy. Never use SendMessage. Never claim a check you did not run; quote the decisive line.`

const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project) with Durango: Wild Lands UI and a real player economy; judged in desktop Chrome at 1600x900 (web renderer) and on landscape phones (844x390).
Package W3-EXCHANGE: the Island Market screens - header with the island's name and currencies, left rail Buy / My Market / Sell, Buy with a category column, search chips and a sortable Level / Durability / Price table where every row is one exact instance (caged pets as cages: a bonded tame with a "B" badge and pet carrier, a captured wild one as a wooden crate), Sell from an exact-instance picker with a fee/tax/proceeds preview, My Market with active listings, sold, expired, history and Receive All - reached from the gameplay HUD's main menu. Open both references (${REFS}) and read docs/design/durango-prompts/14_island_market_ui.md and spec 06 first. Branch ${BR}, work tree ${WT}. Design doc ${DESIGN}; report ${REPORT}; hooks ${HOOKS}.
${RULES}`

const SCOUT = { type: 'object', properties: { notes: { type: 'string' }, files: { type: 'array', items: { type: 'string' } }, questions: { type: 'array', items: { type: 'string' } } }, required: ['notes', 'files'] }
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, owner_gate: { type: 'string', description: "'' unless the work cannot go on without the owner" }, owner_question: { type: 'string', description: "'' or one focused question the owner must answer before players can use the market (work continues meanwhile)" }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'owner_gate', 'owner_question', 'head', 'summary'] }
const REVIEW = { type: 'object', properties: {
  pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  ours: { type: 'array', items: { type: 'object', properties: { screen: { type: 'string' }, path: { type: 'string' } }, required: ['screen', 'path'] }, description: 'our 1600x900 gl_compatibility shots: buy-search, buy-category-taming, sell, my-market, and 844x390 buy' },
  summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'ours', 'summary'] }
const FIDELITY = { type: 'object', properties: {
  details: { type: 'array', items: { type: 'object', properties: { detail: { type: 'string' }, verdict: { type: 'string', enum: ['met', 'partial', 'missing'] }, note: { type: 'string' } }, required: ['detail', 'verdict', 'note'] } },
  defects: { type: 'array', items: { type: 'string' } }, overall: { type: 'string' } }, required: ['details', 'defects', 'overall'] }

phase('Scout')
const scoutBase = `${ctx}

ROLE: read-only scout for the W3-EXCHANGE designer (the work tree does not exist yet; read branches with git -C ${REPO} show <branch>:<path> and git grep <pattern> <branch>; docs in ${OWNER}). Do not edit anything or run Godot. Return dense notes with file:line refs.`
const scouts = await parallel([
  () => agent(`${scoutBase}
SLICE: the client side. The gameplay HUD's main menu on claude/mmo-overhaul (hunt_hud.gd rails/menu, where an "Island Market" entry goes), the theme and fonts, INVUI's components on claude/mmo-invui so far (it is being built now: slot, icon, brackets, picker, theme) and its design doc docs/orchestration/mmo/invui-spec.md if present, item icons and the cage renders (captured_animal, tamed_animal), the white icon set (cart, ledger, tag, search, sort arrows, back, close), how UI labs build state and take shots (ui_real_capture_lab). Say what to reuse and which hooks the market needs.`, { label: 'scout:client', phase: 'Scout', schema: SCOUT }),
  () => agent(`${scoutBase}
SLICE: the economy and its transport. On claude/mmo-econ: the report (docs/orchestration/reports/claude-mmo-econ.md), VaultBridge.client() and every client op (list_fixed, buy, cancel, search/query with filters and sorts, my listings, sold/expired/history, receive all/withdraw, wallet.get with bound/tradable, fees/tax preview if any, price history, pet/cage listings and the PetRecord they carry), errors (trade lock, insufficient tradable funds, limit_reached), Settlers (simulated buyers), how categories and market_category work, and how the engine persists. On claude/mmo-net and claude/mmo-overhaul: is there any transport today that lets a playing client reach the engine (a --server mode, a local server, a socket client, W1-SRVDOM's character store in single-player)? What would an in-game client need to call it honestly - and does single-player play keep its character outside the server store (so selling would first need the character to be server-owned)? Be precise; this decides the design.`, { label: 'scout:econ', phase: 'Scout', schema: SCOUT }),
  () => agent(`${scoutBase}
SLICE: the docs. docs/design/durango-prompts/14_island_market_ui.md and both references (open them), spec 06 (all), docs/design/economy.md, contracts.md sections 0, 4-6 and 8, the PRD's market sections, STATUS owner decisions (pets as caged items, nothing fake, server local until a host is picked) and GAUNTLET.md. Produce: (1) a numbered acceptance checklist with measurable gates (layout vs the references, one row per instance, sorting/search/filter, caged-pet rows, fee/tax/proceeds preview, Receive All, honest offline state, targets at 844x390), (2) what the docs settle about categories, fees, tax, bands, listing duration, cancellation, regional markets per island, (3) what they leave open (simplest choice, # ASSUMPTION), (4) owner questions only if the docs truly do not settle something that changes money, authority or saves.`, { label: 'scout:docs', phase: 'Scout', schema: SCOUT }),
])
const scoutNotes = scouts.map((s, i) => `--- scout ${['client', 'econ', 'docs'][i]} ---\n${s ? s.notes + '\nFiles: ' + (s.files || []).join(', ') + (s.questions && s.questions.length ? '\nQuestions: ' + s.questions.join(' | ') : '') : '(scout failed)'}`).join('\n\n')

phase('Design')
const design = await agent(`${ctx}

ROLE: designer of W3-EXCHANGE. Scout notes are below.
1. Create the work tree: bash ${MKWT} exchange claude/mmo-econ (reuse ${WT} if it exists). Apply ECON's hooks patch (${ECON_HOOKS}; git apply --3way) and commit "Apply ECON hooks (EXCHANGE base)". Run --import once.
2. Decide the transport HONESTLY and write it down: the screens talk only to one MarketClient interface whose calls are VaultBridge.client() ops. Name every transport and when each is used - e.g. a socket transport over the network core when connected to a server, an in-process server stack only if the game already runs one, and a lab/test transport that runs the real engine for labs and tests (never shown to players as a live market). If letting players use the market in the current single-player build requires something the docs and owner decisions do not settle (e.g. making single-player characters server-owned - a save/authority change), put ONE focused question with the options in owner_question and design the screens to show an honest "market offline" state until it is answered; do not stop the build for it.
3. Write ${DESIGN}: screens and components (header with island name and currencies, left rail tabs with yellow brackets, category column, search with chips, sortable table, instance rows incl. cage rows with the B badge, buy confirm with price/fee and errors such as trade lock or not enough tradable coins, Sell picker + price input within the bands + fee/tax/proceeds preview + confirm, My Market tabs: listings with cancel, sold, expired, history, Receive All), the main-menu entry hook, data each element reads, every # ASSUMPTION with its doc check, and MEASURABLE gates (proportions vs the references, targets >= 44 px at 844x390, no clipping, one row per instance, sorting never changes uids, every action moves real items/coins in the engine, a test per error path).
4. Skeletons: game/scripts/dev/market_ui_lab.gd (deterministic engine state through the test transport: listings of branches, bones, a bonded tame and captured cages, a player with a bag and a wallet incl. bound coins; --screen=buy|buy_taming|sell|my_market|confirm --shot=<png>) and game/tests/t_exchange.gd.
5. Build plan: B1 shell + navigation + Buy; B2 Sell; B3 My Market + Receive All; B4 polish, responsive (1600x900, 1920x1080, 844x390, 667x375), 500-listing performance.
Commit. Return done, owner_gate, owner_question, head, gates, shots, summary.

Scout notes:
${scoutNotes}`, { label: 'design', phase: 'Design', schema: STEP, effort: 'high' })
if (!design || design.owner_gate) return { stopped: 'design', design }
const questions = []
if (design.owner_question) questions.push(design.owner_question)

phase('Build')
const BUILD = [
  { key: 'b1', text: 'B1: the market shell (header, left rail, honest offline state), the HUD main-menu entry (hook), and the Buy tab (category column, search chips, sortable table of single-instance rows, cage rows, buy confirm with fee and every error path).' },
  { key: 'b2', text: 'B2: the Sell tab: exact-instance picker (INVUI components when available), price within the bands, fee/tax/proceeds preview, list; caged pets listed as cages; locked items refuse.' },
  { key: 'b3', text: 'B3: My Market: active listings with cancel, Sold, Expired, History, Receive All - every one through the engine, with tests that items and coins really move.' },
  { key: 'b4', text: 'B4: polish to the references (textures, gold names, dotted separators, yellow active sort header, chevron rows), responsive layouts at 1600x900, 1920x1080, 844x390 and 667x375 with safe areas, keyboard/mouse/scroll, 500 listings scroll smoothly (measure).' },
]
const built = []
for (const b of BUILD) {
  const r = await agent(`${ctx}

ROLE: builder of W3-EXCHANGE step ${b.text}
Read ${DESIGN} and ${REPORT} (if present) and git log first; previous steps and cut runs may have left work - keep what is good. Sync the base as the rules say. Implement the step, fill the tests and lab for it, run t_exchange, the economy tests, every t_*.gd, run_all and smoke, take the lab shots this step touches at 1600x900 (Forward+ and gl_compatibility) and 844x390, OPEN each next to the matching Durango reference and fix what does not match before you finish. Update ${REPORT} and ${HOOKS}. Commit.
Return done, owner_gate, owner_question, head, gates, shots, summary.`, { label: `build:${b.key}`, phase: 'Build', schema: STEP })
  built.push({ step: b.key, r })
  if (!r) return { stopped: 'cut at ' + b.key, built, questions }
  if (r.owner_question) questions.push(r.owner_question)
  if (r.owner_gate) return { stopped: 'owner gate at ' + b.key, owner_gate: r.owner_gate, built, questions }
}

phase('Review')
const fidelityPrompt = (ours) => `You are an art director who played Durango: Wild Lands for years. Compare our Island Market screens with the original Durango screenshots and judge how faithfully we recreated them. Open every image with the Read tool.
Durango references: ${REFS}
Ours: ${ours.map(o => `${o.screen} ${o.path}`).join(' ; ')}
For each recognizable detail say met, partial or missing with a concrete note: dark header with the island name, currency counters and close X over a torn-edge band; left rail of tall Buy / My Market / Sell tabs with icons, the active one lighter with yellow corner brackets and a yellow label; category column with a gold-highlighted selected row and yellow chevron; search icon and removable filter chips; column headers Item Name/Type, Level, Durability, Price with sort arrows and the active sort in yellow; one row per item with icon, gold name over a grey type line, Lv., cur/max durability, coin icon and price; caged pets (B badge + pet carrier for a bonded tame, wooden crate for a captured one); dotted row separators; earthy textured panels; typography and density; consistency with the Bag look. Then list the most visible defects.`

let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(`${ctx}

ROLE: independent, exceptionally demanding reviewer (round ${round}) of W3-EXCHANGE. You did not write it. Do not edit ${WT}; probes and shots go under ${SP}/review/exchange/r${round}/. Review what will merge: bash ${MKS} rev-exchange ${BR} ${HOOKS}.
1. Read the references, docs/design/durango-prompts/14_island_market_ui.md, spec 06, ${DESIGN}, ${REPORT} and the full diff against its base.
2. Run every acceptance item yourself and record met/evidence; rerun every t_*.gd, the economy tests, run_all and smoke.
3. Try to break it: buy your own listing, buy with only bound coins, buy inside the trade lock, double-tap buy (rid idempotency), cancel a sold listing, Receive All twice, list a locked item, list an equipped item, list a caged pet and a bonded active pet, price outside the bands, sort/search never change uids, a listing bought by someone else while you look, offline state honest, 844x390 targets and clipping, 500 listings.
4. NOTHING FAKE: prove every action moved real items and coins in the engine (read the ledger/vaults before and after); any listing, buyer or price the UI made up is a blocker.
5. Scope (owned files, hooks for the rest), no inert controls, no "+" purchase button, tests that can fail.
6. Shots: our buy-search, buy-category (taming), sell, my-market at 1600x900 gl_compatibility and buy at 844x390, in "ours"; look at them.
Severity: blocker = item/coin loss, duplication or minting, fake market data, crash, unsanctioned edit, acceptance unmet, test that cannot fail; major = required behaviour missing or untested, or clearly unlike the references; minor = polish. pass=true only with zero blockers and zero majors.`, { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review r' + round, built, questions }
  const findings = (rv.findings || []).slice()
  let pass = rv.pass
  let fid = null
  if (rv.ours && rv.ours.length) {
    fid = await agent(fidelityPrompt(rv.ours), { label: `fidelity:r${round}`, phase: 'Review', schema: FIDELITY })
    if (fid) {
      const missing = fid.details.filter(d => d.verdict === 'missing')
      const partial = fid.details.filter(d => d.verdict === 'partial')
      if (missing.length || partial.length > 2) {
        pass = false
        findings.push({ severity: 'major', where: 'fidelity judge vs Durango market references', problem: `Missing: ${missing.map(d => d.detail + ' (' + d.note + ')').join('; ') || 'none'}. Partial: ${partial.map(d => d.detail + ' (' + d.note + ')').join('; ') || 'none'}. Defects: ${(fid.defects || []).join('; ')}`, fix: 'Make every detail read as Durango at 1600x900 and 844x390.' })
      }
    }
  } else { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no screenshots of our market screens', fix: 'the lab must shoot every screen' }) }
  final = { round, pass, reviewed_sha: rv.reviewed_sha, summary: rv.summary, findings, fidelity: fid, unmet: (rv.acceptance || []).filter(a => !a.met) }
  log(`EXCHANGE review r${round}: ${pass ? 'PASS' : 'not yet'} (findings ${findings.length})`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder of W3-EXCHANGE, fix round ${round}. An independent reviewer and a fidelity judge comparing our screens with the Durango references found the problems below. Sync the base, fix every blocker and major and the cheap minors, add a check that would have caught each, rerun the affected acceptance items and lab shots, LOOK at them next to the references, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show the evidence in the report.
Findings (JSON):
${JSON.stringify(findings, null, 1)}
Return done, owner_gate, owner_question, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix r' + round, built, final, questions }
  if (fx.owner_question) questions.push(fx.owner_question)
  if (fx.owner_gate) return { stopped: 'owner gate', owner_gate: fx.owner_gate, built, final, questions }
}
return { ready: !!(final && final.pass), final, questions, built: built.map(b => ({ step: b.step, done: b.r && b.r.done, summary: b.r && b.r.summary })) }
