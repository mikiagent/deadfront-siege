export const meta = {
  name: 'deadfront-invui',
  description: 'INVUI: recreate Durango Bag, Character/Gear and Equipment screens (spec 13) on the instance inventory; scout, design, phased build, independent review + fidelity judge vs the Durango references + blind A/B',
  phases: [
    { title: 'Scout', detail: 'UI framework, item/equipment data, docs' },
    { title: 'Design', detail: 'spec, owned files, gates, worktree' },
    { title: 'Build', detail: 'bag, inspection, character/gear, integration, polish' },
    { title: 'Review', detail: 'independent reviewer, fidelity judge, blind A/B, fix loop' },
  ],
}

const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const R = `${REPO}/.claude/worktrees`
const WT = `${R}/mmo-invui`
const BR = 'claude/mmo-invui'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const GSLOT = `${OSP}/gslot.sh`
const MKWT = `${OSP}/mkwt.sh`
const MKS = `${SP}/mkscratch.sh`
const SPEC13 = 'docs/design/durango-prompts/13_inventory_equipment_ui.md'
const REFS = `${OWNER}/docs/reference/durango-bag-instances.webp (Bag), ${OWNER}/docs/reference/durango-character-gear.webp (Character -> Gear), ${OWNER}/docs/reference/durango-equipment-myinfo.webp (Equipment / My Info)`
const STORAGE_REF = `${OWNER}/docs/reference/durango-storage-transfer.webp - the owner's second inventory example ("Another example of the inventory menu"), read in the addendum at the end of ${OWNER}/${SPEC13}: Bag 61/200 | Small Box 75/80 tabs (the active one gold), a "1 Select" multi-select header with a gold check on selected items, a left column of category filter icons, Lv. labels top-right and small gold/grey attribute pips under each icon, a notice over someone else's box (cannot take), a right panel with the gold title band, Lv., durability, a processing-count chip (hammer x3), family chips (Chunk, Iron, Ore, Rock) and attribute chips (Firm Lv. 4 gold, Heavy Lv. 2 grey), and a toolbar Auto Sort / select-many / select-all / search / lock / trash with a yellow Transfer to Bag button`
const PANEL_REF = `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/durango-bag-ingame-panel.webp - the owner's THIRD inventory reference ("inventory menu while in game, scrollview"): while playing, the bag is NOT full screen - it docks as a panel on the right half (header 'Bolsa' with back arrow and X, a 'Bolsa 186 / 200' tab, the category icon column, a vertically scrolling 5-column grid of single instances with Lv. labels, small white '+' marks and gold/grey attribute pips, yellow corner brackets on the selected item) while the world stays visible and live on the left; the item card floats BETWEEN the world and the bag (gold title band 'Carne', icon, 'Nvl. 23', durability 100/100, hammer x2 processing count, family chips Edible / Fragment / Meat, a processing-state chip 'Raw Lv. 1', an Info section with Satiety 20 and Animal Vigor 50, a colour hex, a flavour text line, a Maintenance section (Repair: not possible, Required performance), a 'Create' section, and a yellow primary action 'Eat'); bottom toolbar Auto Sort with caret plus select-many, filter, lock, trash`
const DESIGN = 'docs/orchestration/mmo/invui-spec.md'
const REPORT = 'docs/orchestration/reports/claude-mmo-invui.md'
const HOOKS = 'docs/orchestration/reports/claude-mmo-invui-hooks.patch'

const RULES = `
Shared rules (binding):
- Godot: ${G} (4.7.1 Mono; game/ is the project). Run EVERY Godot command through ${GSLOT} with its own timeout, from your tree (e.g. ${GSLOT} perl -e 'alarm 600; exec @ARGV' ${G} --headless --path game --script res://tests/t_invui.gd). gslot holds one of 5 machine-wide slots shared with another running workflow, forces silent audio (never play audio) and caps runs at 20 min; start long runs with run_in_background rather than blocking a foreground call past 10 minutes. Never pass --editor. Run one --import (alarm 900) after adding class_name files or assets.
- Pixels: windowed runs only (${G} --path game --resolution 1600x900 -- --lab=<lab> --shot=<png> --shot-delay=6; add --rendering-method gl_compatibility for the web renderer, which is the judge; phones are LANDSCAPE 844x390). Open every PNG with the Read tool and compare it side by side with the Durango references before claiming anything visual.
- Gates: every game/tests/t_*.gd PASS (t_save prints 5 deliberate SCRIPT ERRORs, as on base); run_all.gd [tests] PASS; tools/smoke.sh --no-import SMOKE PASS; the package labs with 0 SCRIPT ERROR lines; no new ~/Library/Logs/DiagnosticReports/Godot-*.ips.
- Isolation: keep the git-excluded game/override.cfg; never touch ~/Library/Application Support/Godot/app_userdata (the owner's real save), the owner's checkouts ${REPO} and ${OWNER}, or other packages' worktrees. Throwaway trees: bash ${MKS} <name> <ref> [patch relative to the tree].
- Code: typed GDScript in the house style, class_name per file, short why-comments, no new autoloads or third-party deps, no god-file growth (extract components), presentation separate from authoritative inventory state (the UI reads the inventory and sends commands through PlayerActions where the game has them). Tests are SceneTree scripts that load classes via load() inside functions and must fail on the old behaviour.
- No downloads (no fonts, textures or packs from the web); use fonts and art already in the project, and make textures procedurally (shader noise or a generated PNG from a script you commit). Item art: the project's rendered item icons (ItemArt/ArtSlot, game/assets/icons/render) and the white UI icon set (game/data/ui_icons.json); never emoji.
- Ownership: this package owns its new files, ${DESIGN}, ${REPORT}, its lab and tests, and the bag/character/equipment screens the design assigns it. Integrator-only files (game/scripts/core/{game,main,world}.gd, game/project.godot, game/tests/run_all.gd, game/scripts/ui/touch_controls.gd) and other packages' files get exact compiling changes in ${HOOKS}, regenerated after every base sync. Other packages are being fixed right now on their branches by another workflow (W2-DATA, W2-SKILLS, W2-INV, W2-PROCESS, W2-GATHER, W2-BUILDSYS, ECON, W2-RAGDOLL, ICONS2): never edit their branches or worktrees.
- Base: this branch is stacked on claude/mmo-w2-inv (the non-stacking instance inventory, still in review). At the start of every step: if git log claude/mmo-overhaul shows W2-INV merged, git merge claude/mmo-overhaul; otherwise git merge claude/mmo-w2-inv and re-apply any change in its hooks patch (docs/orchestration/reports/claude-mmo-w2-inv-hooks.patch) since the commit "Apply W2-INV hooks (INVUI base)". Resolve conflicts keeping both intents.
- Design truth: spec 13 (${SPEC13}) and the three references (${REFS}) are the owner's direct request (newest wins); specs 04, 05, 06, 08, GAUNTLET.md's binding UI rules (colour = things, white = actions; targets 44 px+, 56-64 px for contextual actions; 8 px rhythm; no clipped or overlapping text; landscape 844x390; desktop 1600x900 on gl_compatibility is the judge) and STATUS owner decisions also bind. Durango's look wins over earlier DEADFRONT UI styling where they conflict. Where the docs are silent, pick the simplest thing, keep it in data, mark # ASSUMPTION and list it; never show inert UI (a control must do something real or not be shown).
- Owner gates: optional new save fields that old saves load without (NEW flag, locked flag, presets) are fine; anything else that changes saves, money or multiplayer authority goes in owner_gate.
- Commit early and often; messages end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Never git add -A; never commit override.cfg, .godot/ or import/uid churn you did not create; no preview PNGs in the repo. Never push, never merge into claude/mmo-overhaul, never deploy. Never use SendMessage. Never claim a check you did not run; quote the decisive line.`

const ctx = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival game (game/ is the project) raised to ARK-quality visuals with Durango: Wild Lands UI and system depth; judged in desktop Chrome at 1600x900 (web renderer) and on landscape phones (844x390).
Package INVUI: recreate the original Durango inventory and equipment interface (owner's spec 13, ${SPEC13}, read it fully; references ${REFS} - open all three images) on the existing instance inventory. Branch ${BR}, work tree ${WT}. Design doc ${DESIGN}; report ${REPORT}; hooks ${HOOKS}.
${RULES}`

const SCOUT = { type: 'object', properties: { notes: { type: 'string', description: 'dense findings with file:line refs' }, files: { type: 'array', items: { type: 'string' } }, questions: { type: 'array', items: { type: 'string' } } }, required: ['notes', 'files'] }
const STEP = { type: 'object', properties: { done: { type: 'boolean' }, owner_gate: { type: 'string' }, head: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } }, shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['done', 'owner_gate', 'head', 'summary'] }
const PAIR = { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] }
const REVIEW = { type: 'object', properties: {
  pass: { type: 'boolean' }, reviewed_sha: { type: 'string' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  ours: { type: 'array', items: { type: 'object', properties: { screen: { type: 'string', enum: ['bag', 'bag_panel', 'character', 'equipment', 'storage'] }, path: { type: 'string' } }, required: ['screen', 'path'] }, description: 'our 1600x900 gl_compatibility shots of the four reference screens (bag, character, equipment, storage)' },
  pairs: { type: 'array', items: PAIR, description: 'matched BEFORE (base build) / AFTER (this branch) shots for a blind A/B' },
  summary: { type: 'string' } }, required: ['pass', 'reviewed_sha', 'findings', 'ours', 'pairs', 'summary'] }
const FIDELITY = { type: 'object', properties: {
  details: { type: 'array', items: { type: 'object', properties: { detail: { type: 'string' }, verdict: { type: 'string', enum: ['met', 'partial', 'missing'] }, note: { type: 'string' } }, required: ['detail', 'verdict', 'note'] } },
  defects: { type: 'array', items: { type: 'string' } }, overall: { type: 'string' } }, required: ['details', 'defects', 'overall'] }
const JUDGE = { type: 'object', properties: {
  verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } },
  overall: { type: 'string' } }, required: ['verdicts', 'overall'] }

// An agent sometimes writes 'none ...' instead of '' in owner_gate.
const isGate = (g) => !!g && !/^\s*(none|no |n\/a)/i.test(g)

phase('Scout')
const scoutBase = `${ctx}

ROLE: read-only scout for the INVUI designer (the work tree does not exist yet; read claude/mmo-overhaul and claude/mmo-w2-inv with git -C ${REPO} show <branch>:<path> / git grep <pattern> <branch>, and ${OWNER} for docs). Do not edit anything or run Godot. Return dense notes with file:line refs.`
const scouts = await parallel([
  () => agent(`${scoutBase}
SLICE: the existing UI. The theme and fonts W1-UI set up; the current bag (game/scripts/ui/inventory_ui.gd and what W2-INV's hooks patch changes there), how the HUD opens it (hunt_hud.gd rails, menu), any character/skills sheet, the Animals screen and pet cargo/bag UI, craft_ui.gd and its picks, station and basket/chest storage UIs (also claude/mmo-w2-buildsys' chest UI), item_icons.gd / ItemArt / ArtSlot (rendered item icons), ui_icons.json (white action icons, incl. lock, filter, select, back, close), touch handling and safe areas, the UI capture labs (ui_real_capture_lab and others) and how they build a deterministic player and take shots. Say which files INVUI should own, which need hooks, and what to reuse.`, { label: 'scout:ui', phase: 'Scout', schema: SCOUT }),
  () => agent(`${scoutBase}
SLICE: the data and commands on claude/mmo-w2-inv. The instance model (uid, def id, level, traits/attributes, processed state, durability, created/acquired time), capacity and its bonuses (pack 05: base 100 + equipment/Pocket), equip slots (equip_at, worn gear, held weapon, armor slots from survivor v2), the stats the game really has (attack, defense, accuracy or equivalents; crafting ability; gathering; climate resistance; carry), PlayerActions commands for equip/unequip/drop/eat/use, crafting picks (Crafting.default_picks/picks_valid), containers (basket storage, home cargo, BUILDSYS chests on its branch, pet cargo), any market hook (none on base?), save/load of inventory and where optional fields (new, locked, presets) would go. List exact APIs the UI can call.`, { label: 'scout:data', phase: 'Scout', schema: SCOUT }),
  () => agent(`${scoutBase}
SLICE: the docs. Read spec 13 fully and open the three reference images; then specs 04, 05, 06, 08 and 03, the PRD (docs/prd/durango-wild-lands-systems-prd.md) sections on inventory, equipment and stats, STATUS owner decisions and GAUNTLET.md's binding UI rules. Produce: (1) a numbered acceptance checklist for INVUI drawn from spec 13 sections 4-25 with measurable gates (layout proportions per section 3, ~7 columns at the reference 16:9 width, label sizes, tap targets, colours), (2) what the docs settle about gear presets, Decorative Gear, Combat/Crafting/Gathering Power, Detailed Stats, NEW rules, item locking, attribute classes and colours, sorting and filters, (3) what they do not settle, with the simplest non-inert choice to mark # ASSUMPTION, (4) conflicts between spec 13 and older UI rules and which wins (the owner's spec 13 is newest).`, { label: 'scout:docs', phase: 'Scout', schema: SCOUT }),
])
const scoutNotes = scouts.map((s, i) => `--- scout ${['ui', 'data', 'docs'][i]} ---\n${s ? s.notes + '\nFiles: ' + (s.files || []).join(', ') + (s.questions && s.questions.length ? '\nQuestions: ' + s.questions.join(' | ') : '') : '(scout failed)'}`).join('\n\n')

phase('Design')
const design = await agent(`${ctx}

ROLE: designer of INVUI. Scout notes are below.
1. Create the work tree: bash ${MKWT} invui claude/mmo-w2-inv (if ${WT} exists, reuse it). In it, apply W2-INV's hooks patch (docs/orchestration/reports/claude-mmo-w2-inv-hooks.patch; git apply --3way) and commit "Apply W2-INV hooks (INVUI base)" so the UI is built on the real merged inventory. Run --import once.
2. Write ${DESIGN}: the component tree (reusable InventoryGrid, InventorySlot, ItemIcon, LevelLabel, NewTag, SelectionBrackets, RareMarker, ItemInspectPanel, BagToolbar, CapacityIndicator, EquipmentSlot, GearPresetSelector, plus the Bag, Character -> Gear and Equipment/My Info screens and the shared grid for storage, dinosaur cargo and the craft/cook ingredient picker), each with its file; the palette and type scale from spec 13 section 2 as one theme resource; the procedural texture plan; owned files vs hooks; the data each element reads; optional save fields (new, locked, presets) and their defaults for old saves; every # ASSUMPTION with its doc check; and the acceptance checklist with MEASURABLE gates (header 8-10 % and toolbar 10-12 % of height, ~7 columns at 1600x900, all tap targets >= 44 px at 844x390 and >= 56 px for contextual actions, level text legible at 844x390, no clipped or overlapping text, capacity from real data incl. bonuses, NEW and lock round-trip a save, sorting/filtering never change uids, exact-instance selection in the picker, valid actions only).
3. Write the lab: game/scripts/dev/bag_ui_lab.gd (+ scene if needed) that builds a deterministic survivor with a bag of 91 instances (berries Lv. 12/25/42 with a trait, bones Lv. 45/60 with a rare attribute if the data supports one, leaves, a caged animal, a workbench kit, weapons and armour), some NEW, some locked, worn gear, a bonded pet with cargo and a storage box, and shoots --screen=bag|inspect|character|equipment|storage|cargo|picker to --shot=<png>; and game/tests/t_invui.gd covering spec 13 section 23's functional items. Both start as failing skeletons the builders fill.
4. Phase plan for the builders, matching spec 13 section 24: B1 Bag (phases 1+2: layout, grid, icons, levels, capacity, brackets, toolbar, inspection, attribute colours, contextual actions), B2 Character/Gear/Equipment (phase 3), B3 integration (phase 4: storage split, dinosaur cargo, craft/cook picker, Sell on Market only if a market exists - otherwise no button and a hook point), B4 polish (phase 5: textures, responsive layouts at 1600x900, 1920x1080, 844x390 and 667x375, restrained animation, accessibility, performance). Each with its own acceptance subset.
Commit everything. Return done, owner_gate, head, gates, shots, summary.

Scout notes:
${scoutNotes}`, { label: 'design', phase: 'Design', schema: STEP, effort: 'high' })
if (!design || isGate(design.owner_gate)) return { stopped: 'design', design }

phase('Build')
const BUILD = [
  { key: 'b1', text: 'B1: the Bag screen and item inspection (spec 13 sections 4-12; phases 1 and 2).' },
  { key: 'b2', text: 'B2: Character -> Gear, gear presets, Detailed Stats and the Equipment / My Info select-and-compare flow (spec 13 sections 13-15; phase 3). Equipping must really change stats once, never twice.' },
  { key: 'b3', text: 'B3: integration (spec 13 sections 17-19; phase 4). The storage view follows the owner\'s second reference ' + STORAGE_REF + ' (open it). Storage box split view, dinosaur cargo, the craft and cook ingredient picker with exact-instance selection (least valuable preselected, never the rarest silently), Sell on Market only if a market screen exists. Wire the HUD/menu entry points through hooks where the files are not yours.' },
  { key: 'b4', text: 'B4: the IN-GAME bag panel and polish. FIRST: when opened during play (the HUD bag button / key), the bag must be the docked right-side panel with the world visible and the floating item card of ' + PANEL_REF + ' (open it); keep the full-screen Bag from the first reference only where the design needs it (or drop it if the panel covers every use), and make the panel the default; the grid scrolls smoothly (touch drag, wheel, kinetic), the card shows every field the data has (satiety/energy from food data, processing state, durability, family chips, flavour text) and only valid actions. THEN polish (spec 13 sections 2, 16, 20, 21; phase 5); match all bag references, incl. ' + STORAGE_REF + ': subtle procedural textures and irregular dark borders, one unified look across Bag/Character/Equipment, responsive layouts at 1600x900, 1920x1080, 844x390 and 667x375 with safe areas, restrained transitions, keyboard/mouse/scroll on desktop, accessibility (rarity not by colour alone), performance (a 142-slot bag opens in < 50 ms; measure).' },
]
const built = []
for (const b of BUILD) {
  const r = await agent(`${ctx}

ROLE: builder of INVUI step ${b.text}
Read ${DESIGN} and ${REPORT} (if present) and git log first; previous steps and cut runs may have left work - keep what is good. Sync the base as the rules say. Implement the step to the design, fill the tests and lab for it, run t_invui, every t_*.gd, run_all and smoke, take the lab shots of the screens this step touches at 1600x900 (Forward+ and gl_compatibility) and 844x390, OPEN each next to the matching Durango reference and fix what does not match before you finish. Update ${REPORT} (what this step shipped, acceptance lines, shots looked at, assumptions, hooks, limits) and ${HOOKS}. Commit.
Return done, owner_gate, head, gates, shots, summary.`, { label: `build:${b.key}`, phase: 'Build', schema: STEP })
  built.push({ step: b.key, r })
  if (!r) return { stopped: 'cut at ' + b.key, built }
  if (isGate(r.owner_gate)) return { stopped: 'owner gate at ' + b.key, owner_gate: r.owner_gate, built }
}

phase('Review')
const reviewPrompt = (round) => `${ctx}

ROLE: independent, exceptionally demanding reviewer (round ${round}) of INVUI. You did not write it. Do not edit ${WT}; probes and shots go under ${SP}/review/invui/r${round}/. Review what will merge: bash ${MKS} rev-invui ${BR} ${HOOKS}; a BEFORE tree for comparisons: bash ${MKS} revbase-invui claude/mmo-w2-inv docs/orchestration/reports/claude-mmo-w2-inv-hooks.patch.
1. Read spec 13, the three references, ${DESIGN}, ${REPORT} and the full diff against the base it is stacked on.
2. Run every acceptance item yourself (the design's checklist and spec 13 section 23's twenty tests) and record met/evidence. Rerun every t_*.gd, run_all and smoke.
3. Try to break it: exact-instance selection (berries Lv. 12/25/42, a rare bone) through picker, sell and transfer; sorting/filtering never change uids; locked items refuse drop/sell/process/craft consumption; NEW and locked survive save/load; capacity with and without bonuses and when full; equip/unequip changes stats exactly once; presets never unlock unearned loadouts; selection survives refreshes and clears safely on removal; 844x390 tap targets, safe areas, no overlap or clipping; desktop mouse/scroll/keyboard; a 142-slot bag's open time.
4. Scope and quality: owned files only (hooks for the rest), no inert controls, no god-file growth, tests that can fail.
5. Shots: our in-game bag panel (world visible on the left, item card between, as the third reference), our Bag, Character, Equipment and Storage (bag + a box, the owner's storage reference: ${STORAGE_REF}) screens at 1600x900 gl_compatibility (return in "ours"), and 3-5 matched BEFORE/AFTER pairs of the same screens (base bag vs new; 1600x900 and 844x390) in "pairs"; look at all of them.
Severity: blocker = item loss/duplication, crash, save break, unsanctioned edit, acceptance unmet, a test that cannot fail, visible regression; major = required behaviour missing or untested, or clearly unlike the references; minor = polish. pass=true only with zero blockers and zero majors.`
const fidelityPrompt = (ours) => `You are an art director who played Durango: Wild Lands for years. Compare our screens with the original Durango screenshots and judge how faithfully we recreated them. Open every image with the Read tool.
Durango references: In-game bag panel ${PANEL_REF.split(' - ')[0]} ; Storage ${OWNER}/docs/reference/durango-storage-transfer.webp ; Bag ${OWNER}/docs/reference/durango-bag-instances.webp ; Character -> Gear ${OWNER}/docs/reference/durango-character-gear.webp ; Equipment / My Info ${OWNER}/docs/reference/durango-equipment-myinfo.webp
Ours: ${ours.map(o => `${o.screen} ${o.path}`).join(' ; ')}
For each recognizable detail, say met, partial or missing with a concrete note: dark earthy background; dense ~7-column grid at reference proportions with fine separators and visible empty slots; small grey item levels; blue NEW tags top-left; bright yellow corner selection brackets; wide Auto Sort button with a dropdown arrow at bottom-left; compact square utility buttons at bottom-right; Bag capacity at the top with a yellow bag icon; contextual right-hand inspection panel with a yellow title band and compact rows; dark character information panel with portrait, level/XP bar and power rows; yellow active Gear tab vs dark inactive tab; numbered presets with a lock; equipment silhouette slots; Detailed Stats button; My Info Attack/Defense/Accuracy columns with icons and hex ability row; consistent individual-item inspection; the in-game bag docked on the right with the world visible and the floating item card (title band, level, durability, processing count, family chips, info rows, flavour text, yellow primary action); the storage view (Bag | box tabs with counts, multi-select header with checks, category column, attribute pips and chips, someone-else's-box notice, Transfer to Bag); textures and borders (weathered, dark, irregular, not glossy or modern); typography and density. Then list the most visible defects (layout, proportions, colours, text size, clipping, placeholder art).`
const judgePrompt = (pairs) => `You are a blind art director for a dinosaur survival game with Durango: Wild Lands-grade UI. For each scene there are two screenshots of the same screen from two builds; you are NOT told which is newer; ignore file names. Open both with the Read tool and judge which is better as a shipped game UI: readability, information hierarchy, density, tap targets, consistency, visual finish, visible defects. Pick first, second or tie per scene with reasons.
${pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`

let final = null
for (let round = 1; round <= 3; round++) {
  const rv = await agent(reviewPrompt(round), { label: `review:r${round}`, phase: 'Review', schema: REVIEW, effort: 'high' })
  if (!rv) return { stopped: 'cut at review r' + round, built }
  const findings = (rv.findings || []).slice()
  let pass = rv.pass
  let fid = null, ab = null
  if (rv.ours && rv.ours.length) {
    fid = await agent(fidelityPrompt(rv.ours), { label: `fidelity:r${round}`, phase: 'Review', schema: FIDELITY })
    if (fid) {
      const missing = fid.details.filter(d => d.verdict === 'missing')
      const partial = fid.details.filter(d => d.verdict === 'partial')
      if (missing.length || partial.length > 2) {
        pass = false
        findings.push({ severity: 'major', where: 'fidelity judge vs Durango references', problem: `Missing: ${missing.map(d => d.detail + ' (' + d.note + ')').join('; ') || 'none'}. Partial: ${partial.map(d => d.detail + ' (' + d.note + ')').join('; ') || 'none'}. Defects: ${(fid.defects || []).join('; ')}`, fix: 'Make every detail read as Durango at 1600x900 and 844x390.' })
      }
    }
  } else { pass = false; findings.push({ severity: 'major', where: 'review evidence', problem: 'no screenshots of our Bag/Character/Equipment screens', fix: 'the lab must shoot all three screens' }) }
  if (rv.pairs && rv.pairs.length) {
    ab = await agent(judgePrompt(rv.pairs), { label: `judge:r${round}`, phase: 'Review', schema: JUDGE })
    if (ab) {
      let aw = 0, bw = 0
      ab.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
      ab.afterWins = aw; ab.beforeWins = bw
      if (aw <= bw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `The blind judge did not prefer the new UI (new ${aw}, old ${bw}). ${ab.overall} ${JSON.stringify(ab.verdicts)} (scene i odd => first is NEW)`, fix: "Address the judge's reasons." }) }
    }
  }
  final = { round, pass, reviewed_sha: rv.reviewed_sha, summary: rv.summary, findings, fidelity: fid, ab: ab ? { afterWins: ab.afterWins, beforeWins: ab.beforeWins, overall: ab.overall } : null, unmet: (rv.acceptance || []).filter(a => !a.met) }
  log(`INVUI review r${round}: ${pass ? 'PASS' : 'not yet'} (findings ${findings.length}${ab ? ', A/B ' + ab.afterWins + '/' + ab.beforeWins : ''})`)
  if (pass || round === 3) break
  const fx = await agent(`${ctx}

ROLE: builder of INVUI, fix round ${round}. An independent reviewer, a fidelity judge comparing our screens with the Durango references, and a blind A/B judge found the problems below. Sync the base, fix every blocker and major and the cheap minors, add a check that would have caught each, rerun the affected acceptance items and the lab shots, LOOK at them next to the references, update ${REPORT} and ${HOOKS}, commit. If a finding is wrong, show the evidence in the report.
Findings (JSON):
${JSON.stringify(findings, null, 1)}
Return done, owner_gate, head, gates, shots, summary.`, { label: `fix:r${round}`, phase: 'Review', schema: STEP })
  if (!fx) return { stopped: 'cut at fix r' + round, built, final }
  if (isGate(fx.owner_gate)) return { stopped: 'owner gate', owner_gate: fx.owner_gate, built, final }
}
return { ready: !!(final && final.pass), final, built: built.map(b => ({ step: b.step, done: b.r && b.r.done, summary: b.r && b.r.summary })) }
