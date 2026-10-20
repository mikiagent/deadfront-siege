export const meta = {
  name: 'deadfront-finish-5',
  description: 'Finish every open DEADFRONT package with Claude doing the work (owner took DeepSeek off: no progress), icons and ragdoll profiles taken over from dsc, one serialized gated integrator',
  phases: [
    { title: 'Work', detail: 'fix / build / finish each package in its own worktree' },
    { title: 'Review', detail: 'independent demanding reviewer, fix loop' },
    { title: 'Judge', detail: 'blind A/B art judge for visual packages' },
    { title: 'Integrate', detail: 'one integrator at a time: test-merge, hooks, full gates, screenshots, fast-forward' },
  ],
}

const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const R = '/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees'
const BASE = `${R}/mmo-overhaul`
const INT = `${R}/mmo-int`
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'
const FIND = `${SP}/finish`
const ARGS = `${FIND}/finish2-args.json`

const RULES = `
Shared rules (binding):
- Godot: ${G}. Wrap EVERY Godot run with ${SP}/gslot.sh and a timeout (perl -e 'alarm N; exec @ARGV'), run from your work tree (gslot also caps any run without one at 20 min). gslot forces silent audio: the owner asked that tests make no sound; never play audio by other means. Never pass --editor. Run one --import (alarm 900) after adding assets or new class_name files. Headless renders nothing: for pixels use a windowed run (--resolution 1600x900 -- --shot=<png> [--lab=<lab>] [--shot-delay=N]); add --rendering-method gl_compatibility for the web renderer; phone checks are LANDSCAPE 844x390. Look at every PNG with the Read tool before claiming anything visual. If Godot crashes (a new ~/Library/Logs/DiagnosticReports/Godot-*.ips appears), say so in your report with the file name and the command that crashed; the owner sees those as "Godot quit unexpectedly".
- game/override.cfg (git-excluded) isolates user://; keep it; never touch ~/Library/Application Support/Godot/app_userdata (the owner's real save). Never touch the owner's main checkout /Users/milankinzy/Documents/deadfront-siege (its uncommitted UI pass stays untouched) or other packages' worktrees.
- Typed GDScript in the house style, class_name per file, short why-comments, no new autoloads, no new third-party deps, no god-file growth, # ASSUMPTION: markers listed in the report. Tests are SceneTree scripts that load game classes via load() inside functions, never by class_name at parse time.
- Commit early and often (a usage limit can cut you off at any time; uncommitted work is lost), messages ending "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Never git add -A blindly; never commit override.cfg, .godot/, or *.import/*.uid/_Image_* churn you did not deliberately create. Never push, never deploy.
- Read docs/orchestration/mmo/STATUS.md (owner decisions, newest wins), contracts.md and docs/design/durango-prompts/ (owner's binding design input; 08 no stacking of materials/food, 09 capture rule and bonded caps 3->7, 10 construction quality, 11 processing, 12 remaining skill trees) where they touch your system.
- DO THE WORK YOURSELF (owner, 2026-10-20: "take over deepseek's work because i don't think they are making progress"). Do not start new dsc (DeepSeek) workers. Where a dsc sub-worktree or dsc commits already hold work for your package, review them critically and keep only what is correct.
- Never claim a check passed unless you ran it and saw the line.`

const REVIEW_SCHEMA = { type: 'object', properties: {
  pass: { type: 'boolean', description: 'true only with zero blockers, zero majors, every acceptance item verified' },
  acceptance: { type: 'array', items: { type: 'object', properties: { item: { type: 'string' }, met: { type: 'boolean' }, evidence: { type: 'string' } }, required: ['item', 'met', 'evidence'] } },
  findings: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string', enum: ['blocker', 'major', 'minor'] }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  pairs: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, before: { type: 'string' }, after: { type: 'string' } }, required: ['scene', 'before', 'after'] } },
  summary: { type: 'string' } }, required: ['pass', 'findings', 'summary'] }
const JUDGE_SCHEMA = { type: 'object', properties: {
  verdicts: { type: 'array', items: { type: 'object', properties: { scene: { type: 'string' }, better: { type: 'string', enum: ['first', 'second', 'tie'] }, reasons: { type: 'string' } }, required: ['scene', 'better', 'reasons'] } },
  overall: { type: 'string' } }, required: ['verdicts', 'overall'] }
const INT_SCHEMA = { type: 'object', properties: {
  merged: { type: 'boolean', description: 'true only if claude/mmo-overhaul now contains the package and every gate passed' },
  sha: { type: 'string' }, gates: { type: 'array', items: { type: 'string' } },
  pending_hooks: { type: 'array', items: { type: 'string' } },
  failures: { type: 'array', items: { type: 'object', properties: { severity: { type: 'string' }, where: { type: 'string' }, problem: { type: 'string' }, fix: { type: 'string' } }, required: ['severity', 'where', 'problem', 'fix'] } },
  shots: { type: 'array', items: { type: 'string' } }, summary: { type: 'string' } }, required: ['merged', 'summary'] }

const W1_SCOPE = (key) => `Your binding spec is the section "#### W1-${key.toUpperCase()}" in docs/orchestration/mmo/plan-register.md (Owns / Must not touch / Closes / Acceptance). Edit only files it Owns plus new files in owned directories. Protected for everyone unless this prompt grants it: game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd, game/data/{items,recipes,icons_manifest}.json, game/scripts/items/{inventory,item_def}.gd, game/scripts/player/, game/scripts/core/rigged_model.gd, game/scripts/creatures/creature_view.gd. Only the integrator edits game/scripts/core/{game,main,world}.gd, game/project.godot, game/tests/run_all.gd, game/scripts/ui/touch_controls.gd: put such lines under "Integrator hooks" in your report (exact, compiling code). Tests: game/tests/t_${key}.gd. Report: docs/orchestration/reports/claude-mmo-w1-${key}.md (acceptance checklist with exact output lines, screenshots looked at, assumptions, integrator hooks, labs to register, what is left). Finish with tools/smoke.sh --no-import SMOKE PASS, your t_${key}.gd and run_all.gd passing. Sync with the moving base first: git merge claude/mmo-overhaul (resolve conflicts correctly; never copy base files by hand), so your branch merges clean.`

const W2_SCOPE = (spec, specText) => `${specText}
Other packages running now own: game/scripts/ui/* (W1-UI, W1-UIICONS), game/assets/props/blender + tools/blender/structures + props_manifest.json (dsc camp pieces), game/assets/icons/ (dsc icons2), terrain/foliage shaders (W1-BIOME), game/scripts/server/ (W1-SRVDOM), tools/test.sh + tools/smoke.sh + QA labs (W1-QA), game/scripts/player/ (W2-PLAYER), game/scripts/pets/ (W2-BREED), game/scripts/creatures/brains/ (W2-ECO), the occlusion system (W2-OCCLUDE), structures/build_placer (W2-BUILDSYS). Anything outside your spec goes under "Integrator hooks" in your report as exact compiling code. Do not edit run_all.gd. Tests: game/tests/t_<key>.gd. Report: docs/orchestration/reports/claude-mmo-${spec.toLowerCase()}.md (acceptance lines, integrator hooks, assumptions, limits). Finish with SMOKE PASS, your test PASS, run_all [tests] PASS and every other game/tests/t_*.gd PASS. Sync with the moving base before you finish: git merge claude/mmo-overhaul.`

const PKGS = [
  { key: 'ui', label: 'W1-UI', wt: `${R}/mmo-w1-ui`, branch: 'claude/mmo-w1-ui', visual: true, startRound: 4, maxRound: 6,
    scope: W1_SCOPE('ui') + `
ORCHESTRATOR DECISIONS (binding, 2026-10-20): option (a) - for this package you OWN game/scripts/ui/hunt_hud.gd and game/scripts/ui/inventory_ui.gd and may land hook 1 in game/scripts/core/main.gd (already on your branch). New survivors show "Lv. 1". The level-1 title "Venture into the World" is held from character creation (show it as the current title from the start, no toast). Skills keeping internal "Lv. 0" is a known W2-SKILLS item, not yours. Durango references docs/reference/durango-craft-build-menu.webp and durango-skill-screen.webp are direction, not new acceptance. Owner: "the UI/UX needs a lot of work"; "the symbols/icons need work"; mobile is LANDSCAPE.`,
    first: `ROLE: implementer of W1-UI, continuing. Your round-3 independent review findings are in ${ARGS} under key "ui3" (JSON list: two majors - hunt_hud _refresh_context with display_mode, and creature_plates _separate_visible_creature_plates - plus minors incl. hunt_hud growing 1376 -> 1674 lines: extract helpers into new files, do not grow the god file). Fix every major and the cheap minors, add checks that fail on the old behaviour, rerun ui_real_capture_lab at every size and renderer, t_ui, run_all and smoke, LOOK at the shots, update the report, commit.` },
  { key: 'camp', label: 'DSC-CAMP', wt: `${R}/mmo-camp`, branch: 'claude/mmo-camp', visual: true, startRound: 2, maxRound: 4,
    intNote: 'SQUASH-MERGE this package (git merge --squash claude/mmo-camp) and commit only in-scope paths: tools/blender/structures/*.py, game/assets/props/blender/* (new GLBs and their .import), game/data/props_manifest.json, docs/orchestration/reports/dsc-camp-pieces.md, tools/dsc/verify_camp.sh and camp_base_glbs.sha256. Drop work/ (2-3 MB preview PNGs), the root TASK.md, stray .uid files and the 6 Meshy .glb.import changes (git restore --staged/--worktree them) so none of it reaches the base history.',
    scope: `Package DSC-CAMP: a DeepSeek worker built Blender models for the 18 camp kinds that still showed Kenney placeholders (campfire_stand, technical_workbench, grindstone, tent_canvas, bedroll, large_box, chest, barrel, bucket, fence_fortified, signpost, fishing_stand, field_small, field_large, stone_grill, straw_roll, log_shelter, cabin_bed) with the merged W1-STRUCTART kit (tools/blender/structures/), wrote their props_manifest rows and passed tools/dsc/verify_camp.sh. Brief: TASK.md; report docs/orchestration/reports/dsc-camp-pieces.md. Owner: the buildings hold the game back from AAA. Model changes go through the builder (structures.py + build.py headless, then check_manifest.py --write and check), never by hand-editing GLBs; keep the atlas and the 24 merged GLBs byte-identical. Headless Blender only (/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P ...). You may edit game/scripts/world/prop_visuals.gd ensure_foundation ONLY to skip the dirt disc for field_small/field_large (as straw_roll is skipped). Ignore committed work/ previews (the integrator squash-merges without them).`,
    first: `ROLE: implementer for DSC-CAMP, continuing in ${R}/mmo-camp. Your round-1 independent review findings are in ${ARGS} under key "camp1". The major: the game draws an opaque dirt disc at y=0.08 m under buildings, which hides 73-76 % of the fields' soil and furrows, half the bedroll, the tent ground sheet and the fire ember beds - lift low details above ~0.09 m (fields: bed ~0.10-0.11, darker furrows, ridges 0.11-0.20) and/or skip the disc for fields; add the disc to preview.py so sheets match the game. Minors: cabin_bed mattress ~1.85 m and bedroll pad ~1.8 m, fence_fortified 2.0-2.2 m pointed stakes, log_shelter eave ~1.95-2.0 m so a standing survivor fits, field AABB <= 0.35 m (lay the hoe flat), drop the stale report section. Make the model edits yourself. Rerun tools/dsc/verify_camp.sh (full), take in-game windowed shots (build_lab or a placement probe; Forward+ and gl_compatibility; 844x390) of every changed kind next to the survivor, LOOK at them, update the report, commit.` },
  { key: 'quads2', label: 'DSC-QUADS2', wt: `${R}/mmo-quads2`, branch: 'claude/mmo-quads2', visual: true,
    scope: `Package DSC-QUADS2: the finished DeepSeek job /Users/milankinzy/Documents/DeepseekCLI/deadfront-reanim/quads-loco2 made new walk/run loops for protoceratops and megaloceros with planted-foot strides in MESH units (targets 0.94/2.34 and 2.62/6.55 m/s; megaloceros run reached 4.656 because of a rig reach limit - read out/REPORT.md), skin stretch and hip-height gates, ./verify.sh PASS. Today the game plays these species' runs at x2.7-x16 so the feet slide. Clip rules: skeleton-only WITH the skin, 0 meshes/images, 1 animation; after replacing GLBs force a re-import (touch them, then --import) or Godot serves stale clips; 0 "couldn't resolve track" warnings. Only game/assets/creatures/{protoceratops,megaloceros}/anim/{walk,run}.glb, game/data/creatures/anim_events.json (re-baked by tools/bake_clip_speeds.py) and creature tests may change; t_canim's KNOWN_GLIDERS must drop protoceratops and megaloceros once their clips stride (the integrator noted that line fails until someone does). Report: docs/orchestration/reports/claude-mmo-quads2.md.`,
    first: `ROLE: integrator-vetter for DSC-QUADS2. If ${R}/mmo-quads2 does not exist create it with: bash ${SP}/mkwt.sh quads2. Run the job's ./verify.sh yourself; open its contact sheets (out/<s>/sheets/walk.png, run.png) and LOOK (feet planted, no sliding, no crouch, no torn skin, legs bend the right way); compare with the game's current clips. Copy the four accepted GLBs into the work tree, re-bake anim_events.json, force re-import, drop the two species from KNOWN_GLIDERS, run t_canim, run_all, smoke and the creature_anim_lab cadence log (report the new play-rate multipliers at walk and run speed), take windowed shots of each species walking and running (Forward+ and gl_compatibility) and look at them. Reject a clip that is worse than the current one and say why. Commit.` },
  { key: 'icons2', label: 'ICONS2', wt: `${R}/mmo-icons2`, branch: 'claude/mmo-icons2', visual: true,
    intNote: 'SQUASH-MERGE this package (git merge --squash claude/mmo-icons2) and commit only in-scope paths: tools/blender/items/*, tools/render_icons.py, game/assets/icons/render/* (PNGs, their .import, manifest.json), docs/orchestration/reports/dsc-icons2.md (or claude-mmo-icons2.md), tools/dsc/verify_icons2.sh and icons2_base.json. Drop work/, the root TASK.md and any stray .uid or out-of-scope file.',
    scope: `Package ICONS2: render the 32 item icons that have none (manifest "missing") and redo the 33 weakest renders (marked "replace" with a reason) in the existing pipeline. The brief is TASK.md in ${R}/mmo-icons2 and the gate is tools/dsc/verify_icons2.sh (read both; the gate is the spec; never edit it or icons2_base.json). A DeepSeek worker ran 3.5 h and was STOPPED by the owner for lack of progress: its checkpoints rendered the 17 raw materials (they pass the gate) but none of the 15 kits/feed/cage items nor the 33 flagged ones; its last verify also failed on an out-of-scope game/scripts/dev/siege_probe.gd.uid. Owner rules: items should look cool; a captured or traded animal is shown IN A CAGE (captured_animal: lashed wooden cage with a small generic dinosaur inside; tamed_animal: same cage, door open, hide collar and lead on it). Headless Blender only (/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/render_icons.py -- --only id1,id2). Look at every render at full size and in a contact sheet next to existing icons.`,
    first: `ROLE: implementer taking over ICONS2 from DeepSeek. Keep the 17 passing raw materials (fix cloth_scrap if it still reads as paper), remove the out-of-scope .uid from the branch, render the 15 kits/feed/cage items, then redo the 33 flagged items so each "replace" reason no longer applies and clear their marks. Run tools/dsc/verify_icons2.sh --fast as you go and the full gate at the end (VERIFY PASS: re-render byte-identical, import, t_iconart, run_all). Write docs/orchestration/reports/claude-mmo-icons2.md (per id: what changed, sheet path) and commit.` },
  { key: 'ragdoll', label: 'W2-RAGDOLL', wt: `${R}/mmo-w2-ragdoll`, branch: 'claude/mmo-w2-ragdoll', visual: true,
    scope: `Package W2-RAGDOLL. The full binding spec (owner request "if you're having issues with dead dinosaurs not staying on the ground, try having them ragdoll on death", what to build, ownership, dsc use, acceptance gates) is in ${FIND}/ragdoll-spec.md - read it first. A previous attempt was cut by a usage limit mid-build; its dsc profile worker in ${R}/mmo-w2-ragdoll-dsc1 (branch claude/mmo-w2-ragdoll-dsc1) was STOPPED by the owner (no milestone after 2 h): review its committed checkpoints, keep what is correct, and write and tune the 11 per-species profiles yourself against your ragdoll_lab gate. The spec's dsc instructions no longer apply. Never merge into claude/mmo-overhaul yourself (the integrator does).`,
    first: `ROLE: implementer of W2-RAGDOLL, continuing. Read git log and the work so far, keep what is good, finish the package to the spec in ${FIND}/ragdoll-spec.md. Finish with commits, acceptance lines and what is left.` },
  { key: 'uiicons', label: 'W1-UIICONS', wt: `${R}/mmo-w1-uiicons`, branch: 'claude/mmo-w1-uiicons', visual: true, waitFor: 'ui',
    scope: W1_SCOPE('uiicons') + ` Owner: "the symbols/icons need work". White icon set in game/assets/icons/ui/ with game/data/ui_icons.json and UiIcons loader; its round-2 review fixes are committed (redraws, generator sources, ink coverage).`,
    first: `ROLE: implementer of W1-UIICONS, wiring step. W1-UI has now been integrated into claude/mmo-overhaul (or failed; then wire against the base as it is). Merge claude/mmo-overhaul into your branch. ORCHESTRATOR GRANT: for this step you may edit game/scripts/ui/hunt_hud.gd, game/scripts/ui/creature_plates.gd and the other ui/*.gd files your hooks name, to wire the icon set into the real HUD yourself (replace the remaining colour-emoji glyphs too, e.g. the ANIMALS rail's dinosaur emoji). Every word-glyph you replace keeps a caption (AUTO etc.); creature_plates must not use a Label .icon (use a fixed 16x16 TextureRect or _draw; read the 'giant world knife' comment); fix the quick-food per-frame reassign.  Prove it compiles and renders: run_all, t_ui, t_uiicons, ui_real_capture_lab at 1600x900 and 844x390 in both renderers, smoke; look at the HUD shots; the real game must now show the new icons. Commit and update the report.` },
  { key: 'player', label: 'W2-PLAYER', wt: `${R}/mmo-w2-player`, branch: 'claude/mmo-w2-player', visual: false, skipWork: true,
    scope: W2_SCOPE('W2-PLAYER', `Your spec is the section "#### W2-PLAYER" in docs/orchestration/mmo/plan-register.md (binding). Keep the howdah ride and armor slots working (equip_mount_lab must PASS). The owner's hybrid action combat is a LATER package: build PlayerActions so it can add verbs, do not build action mode now. A previous attempt committed PlayerRegistry; its dsc sub-worktree ${R}/mmo-w2-player-dsc1 (branch claude/mmo-w2-player-dsc1) FINISHED replacing get_first_node_in_group("player") call sites: review its diff and merge it if correct.`),
    first: `ROLE: implementer. Previous attempts were cut off by usage limits: read git log and the work so far, keep what is good, finish the package. Finish with commits, acceptance lines and what is left.` },
  { key: 'occlude', label: 'W2-OCCLUDE', wt: `${R}/mmo-w2-occlude`, branch: 'claude/mmo-w2-occlude', visual: true, skipWork: true,
    scope: W2_SCOPE('W2-OCCLUDE', `Spec (owner 2026-10-20): "make tall trees that obscure the survivor see-through"; roofs: "you can see [them] when away from the building but when under it it's transparent". ONE shared see-through system: global shader parameters (survivor screen/world position, camera) plus a dithered/alpha discard in a cylinder or capsule between camera and survivor, in Forward+ AND gl_compatibility (web), cheap on phones. API: Occlusion.make_occludable(node, mode) with "between" (trees, upper walls: fade only the part between camera and survivor) and "inside" (a roof/ceiling above the survivor fades entirely while the survivor is under it; solid from outside). Apply "between" to tall trees and big rocks via the foliage/prop spawning path (hook if you do not own it). Owns: new game/scripts/world/occlusion*.gd, new shaders under game/shaders/occlusion/, occlusion_lab + scene, game/tests/t_occlude.gd. Acceptance: t_occlude PASS; occlusion_lab windowed shots in both renderers showing the survivor visible behind a tall tree and a test roof faded inside and solid outside (LOOK at them); island_lab frame time not worse than 0.3 ms; no visual change when nothing occludes. Document the API for W2-BUILDSYS.
OWNER CORRECTION (2026-10-20, binding, wins over the text above): "you want it to make the tree partially see through not fully see through, it should still feel like the tree is there not a clear hole in it". So an occluding tree or rock fades AS A WHOLE OBJECT to roughly half coverage (keep 40-60 % of its pixels), evenly over its silhouette with a soft edge and a ~0.25 s fade in/out, never a hard-edged circular cut; its trunk, crown shape and silhouette stay readable while the survivor shows through. The branch's current 'between' mode drops up to 80 % of fragments inside a cylinder around the sight line (occluder_standard.gdshaderinc: occl_between(...) * 0.8), which reads as a hole: replace it (e.g. a per-instance fade driven by a cheap CPU or shader test of whether the object's bounds cross the camera-survivor line, dithered at ~50 % with a finer pattern so it does not look like a mesh screen). Roofs/ceilings in "inside" mode may fade further (the owner asked that a roof be transparent when the survivor is under it) but must keep a faint readable outline. New acceptance (pixel gates in occlusion_lab, both renderers): the occluding tree keeps 40-60 % of its unoccluded pixel count; no 48x48 px window inside its silhouette drops below 30 % coverage (no hole); the survivor keeps >= 50 % of its unoccluded pixels behind it; shots LOOKED at, side by side with the unfaded tree.`),
    first: `ROLE: implementer. If the work tree has no commits beyond the base, start; otherwise continue. Build the package. Finish with commits, acceptance lines, screenshots looked at and what is left.` },
  { key: 'buildsys', label: 'W2-BUILDSYS', wt: `${R}/mmo-w2-buildsys`, branch: 'claude/mmo-w2-buildsys', visual: true, skipWork: true,
    scope: W2_SCOPE('W2-BUILDSYS', `Your spec: the section "#### W2-BUILDSYS" in docs/orchestration/mmo/plan-register.md, with owner changes that win: clean procedural stand-in pieces (bevelled, tier-tinted, readable, not grey boxes) defined in a new game/data/structures.json (model, footprint, sockets, tier materials, HP, cost) so Blender models swap in BY DATA; do not edit props_manifest.json (list rows under hooks). Snapping foundations, walls, doorways, windows, ceilings, roofs, ramps, stairs; structure HP; tiers thatch/wood/stone/metal with in-place upgrade and repair at material cost; wild dinosaurs attack structures that block them (StructureHealth, creature damage routed through it; an API for W2-ECO); owner walls/doors let the owner pass while blocking enemies and TilePath respects it; grid-locked placement, no overlap with resource nodes; costs from existing bag materials (no items/recipes edits); a BuildPlacer API (select, rotate, place, upgrade, repair, demolish) plus a lab path; HUD wiring under hooks. ROOFS USE THE OCCLUSION API of W2-OCCLUDE (branch claude/mmo-w2-occlude, in progress) through ONE small adapter guarded by ResourceLoader.exists. Spec 10 (construction quality) is a LATER layer: keep the data shape ready. The dsc minors batch has now been merged into claude/mmo-overhaul: merge the base before you finish. Acceptance: t_buildsys PASS, build_lab and the siege probe PASS, island_lab counts unchanged, a snapped 2-storey house in windowed Forward+ and gl_compatibility shots you looked at (outside, and inside with the roof faded once bound).`),
    first: `ROLE: implementer. A previous attempt committed early work: read git log, keep what is good, finish the package.` },
  { key: 'srvdom', label: 'W1-SRVDOM', wt: `${R}/mmo-w1-srvdom`, branch: 'claude/mmo-w1-srvdom', visual: false, skipWork: true,
    scope: W1_SCOPE('srvdom') + ` The economy engine lives on branch claude/mmo-econ; do not edit economy files. A round-1 review PASSED at dee1bbe (${FIND}/srvdom-last-review.json); later commits came after it.`,
    first: `ROLE: implementer of W1-SRVDOM, finishing. Merge claude/mmo-overhaul into the branch, resolve conflicts correctly, fix the cheap minors in ${FIND}/srvdom-last-review.json, rerun every acceptance item (t_server_domain, t_srvdom, run_all, smoke), update the report, commit.` },
  { key: 'breed', label: 'W2-BREED', wt: `${R}/mmo-w2-breed`, branch: 'claude/mmo-w2-breed', visual: false,
    scope: W2_SCOPE('W2-BREED', `Spec (owner's request + durango-prompts 02 and 09): breeding of two bonded adults of one species and opposite sex (sex on PetRecord), maturity, proximity at home, cooldown -> fertilised EGG item (unique: species, parent uids, rolled genetics, mutation flags) or gestation for mammals; inheritance per stat 55/45 toward the higher parent (configurable), EVs not inherited, grade from W1-TAME's single source; mutations with lineage counters and a soft cap; incubation in a placed nest kind with temperature from climate data, timestamp-based across save/load; babies with growth stages, care/imprint raising final stats, neglect slows but never kills; bonded cap 3 + Animal Handling I-IV (Survival 35/45/55/60, SP 4/5/5/6) -> 7, caged animals never count, a reset keeps pets but blocks new bonds; capture eligible when stunned at ANY HP or HP <= 30 %, chance from real HP/level/capture ability, the ~50 % hint "Stun the dinosaur to capture it safely". Owns game/scripts/pets/, creature_genetics.gd, taming_pen.gd, a new nest/incubator script, game/data/breeding.json, skills data rows for Animal Handling, items.json ONLY for egg/nest entries appended at the end, capture_lab, pets_lab, breeding_lab, t_breed.gd. Acceptance: 1,000 seeded pairings within 2 % of the split; mutation rate within 1 %; counters lower the chance; an egg saved mid-incubation hatches on time after load; growth monotonic; imprint 100 % beats 0 %; cap 3 -> 7 with a clear refusal at 3/3 and no animal lost; capture cases stunned 80 % yes, unstunned 50 % no, unstunned 29 % yes. A dsc sub-worktree ${R}/mmo-w2-breed-dsc1 may hold unfinished mechanical work: review and merge what is correct.`),
    first: `ROLE: implementer. A previous attempt committed work and was cut off: read git log, keep what is good, finish the package.` },
  { key: 'eco', label: 'W2-ECO', wt: `${R}/mmo-w2-eco`, branch: 'claude/mmo-w2-eco', visual: false,
    scope: W2_SCOPE('W2-ECO', `Your spec is the section "#### W2-ECO" in docs/orchestration/mmo/plan-register.md. Owner decisions: wild dinosaurs DO attack player structures that block them (target the blocking structure; damage only through a structure method that exists - W2-BUILDSYS adds StructureHealth; if absent, add targeting and a clear hook); per-area mob caps and player caps (respect rules.json caps, do not raise populations). Hunt, flee, roam, eat, drink, sleep and defend territory must read clearly. A dsc sub-worktree ${R}/mmo-w2-eco-dsc1 may hold unfinished mechanical work: review and merge what is correct.`),
    first: `ROLE: implementer. A previous attempt committed work and was cut off: read git log, keep what is good, finish the package.` },
  { key: 'qa', label: 'W1-QA', wt: `${R}/mmo-w1-qa`, branch: 'claude/mmo-w1-qa', visual: false,
    scope: W1_SCOPE('qa') + ` Do NOT push to GitHub; .github/workflows/ci.yml only runs later. Labs owned by other packages are listed in your spec; do not edit them.`,
    first: `ROLE: implementer of W1-QA. A previous attempt committed work and was cut off: read git log and the work, keep what is good, finish the package to its spec.` },
  { key: 'biome', label: 'W1-BIOME', wt: `${R}/mmo-w1-biome`, branch: 'claude/mmo-w1-biome', visual: true,
    scope: W1_SCOPE('biome') + ` Use HEADLESS Blender only (${BLENDER} -b -P). Known pixel defects: hard water band at the screen bottom, blown water sun glare.`,
    first: `ROLE: implementer of W1-BIOME. A previous attempt committed work and was cut off: read git log and the work, keep what is good, finish the package to its spec.` },
  { key: 'econ', label: 'ECON', wt: `${R}/mmo-econ`, branch: 'claude/mmo-econ', visual: false,
    scope: `Package: the server-side economy engine (game/scripts/economy/, game/data/economy/, game/tests/economy_tests.gd) built to docs/orchestration/mmo/contracts.md sections 4, 5.1-5.3 and 6 (fixed listings, auctions with anti-snipe, buy orders, instant buy/sell, pet listings, search/filters, price history with wash-trade damping, escrow, fees, Settlers NPC, journal + snapshot, rid idempotency, invariants fuzz). Report: docs/orchestration/reports/claude-mmo-econ.md. Its last review round was cut by a usage limit. Since then contracts.md gained v2 section 0 (server-owned characters, provenance uid+origin, no client-claimed deposits) and the caged-pet rule in 6.1; the base moved ~130 commits. Owner rule: pets trade as caged items; materials do not stack (specs 05/08): instances keep uid. Do not edit inventory UI files.`,
    first: `ROLE: implementer of the economy engine, finishing. Merge claude/mmo-overhaul into the branch and resolve conflicts correctly. Bring the engine in line with contracts v2 where it is the economy's job (provenance uid+origin kept through escrow, deposits only of server-known assets, caged-pet listings), list what belongs to W1-INT (socket wiring, UI) in the report, rerun economy_tests (fuzz >= 3000 ops), run_all and smoke, update the report, commit.` },
  { key: 'net', label: 'NET', wt: `${R}/mmo-net`, branch: 'claude/mmo-net', visual: false,
    scope: `Package: the network core (game/scripts/net/, game/scenes/net/, game/tests/net_tests.gd, tools/net_smoke.sh, docs/orchestration/mmo/net-runbook.md) built to contracts.md sections 1, 2, 3, 5.3, 5.4 and 7: --server mode, WebSocket server with frame caps and strict validation, token-bucket limits, rid idempotency, AccountStore + auth.hello, presence rooms with teleport/speed checks, chat, NetClient with reconnect, remote player puppets. Report: docs/orchestration/reports/claude-mmo-net.md. Its last review round was cut by a usage limit; the base moved ~130 commits; contracts v2 adds area caps (max_players_area, max_creatures_area) to presence. The server stays LOCAL (owner): no hosting work.`,
    first: `ROLE: implementer of the network core, finishing. Merge claude/mmo-overhaul into the branch and resolve conflicts correctly (game.gd/main.gd edits are part of this package's original grant; keep them minimal). Add the v2 presence area caps, rerun net_tests, tools/net_smoke.sh (NET SMOKE PASS), run_all and smoke, update the report, commit.` },
]

const ctx = (p) => `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival game (game/ is the project) being raised to an ARK: Survival Ascended-class, server-authoritative multiplayer survival game with a real marketplace; judged in desktop Chrome (web renderer) and on landscape phones.
Package: ${p.label}. Work tree: ${p.wt} (branch ${p.branch}). Work only there (plus dsc sub-worktrees you create).
${p.scope}
${RULES}`

const reviewPrompt = (p, round) => `${ctx(p)}

ROLE: independent, exceptionally demanding reviewer (round ${round}) for ${p.label}. You did not write this; do not edit or commit anything in the repo; probes and screenshots go under ${SP}/finish2-review/${p.key}/r${round}/.
Read the spec, the report and the full diff (git -C ${p.wt} log claude/mmo-overhaul..HEAD; git -C ${p.wt} diff claude/mmo-overhaul...HEAD), including merged dsc work.
1. Run EVERY acceptance item yourself through gslot and record met/evidence (quote the decisive line or name the screenshot). Unrunnable = met false with the reason.
2. Check the diff against the scope (owned files, grants in this prompt); an unsanctioned edit is a blocker.
3. Check git merge-tree --write-tree claude/mmo-overhaul HEAD is clean; a conflicting branch is a major.
4. Try to break it: hostile inputs, save round-trips, edge cases, regressions in neighbouring systems (run_all, every game/tests/t_*.gd, the labs the spec names, smoke), performance claims.
5. Code quality: house style, no god-file growth, no dead code, tests that can fail (a test that cannot fail is a blocker).
6. ${p.visual ? `Visual: take your OWN screenshots - matched BEFORE (base tree ${BASE}, read-only, through gslot) and AFTER (${p.wt}) of the same scene, camera, resolution and renderer, Forward+ and gl_compatibility where relevant, 844x390 for UI; look at every one; judge against ARK: Survival Ascended, the Durango references in docs/reference/ and GAUNTLET.md's visual rules. Return 2-6 matched pairs (absolute PNG paths) in "pairs".` : 'Non-visual: pairs empty.'}
Severity: blocker = data loss, crash, unsanctioned edit, acceptance unmet, test that cannot fail, visible regression; major = required behaviour missing/untested or clearly sub-par; minor = polish. pass=true only with zero blockers and zero majors.`

const fixPrompt = (p, findings) => `${ctx(p)}

ROLE: implementer of ${p.label}, continuing. An independent reviewer (and for visual work a blind art judge, or the integrator) found the problems below. Fix every blocker and major and the cheap minors, add a check that would have caught each, rerun the affected acceptance items, merge claude/mmo-overhaul if the base moved, update the report, commit. If a finding is wrong, show the evidence in the report.

Findings (JSON):
${JSON.stringify(findings, null, 1)}`

const judgePrompt = (pairs) => `You are a blind art director for a dinosaur survival game aiming at ARK: Survival Ascended / AAA quality. For each scene there are two screenshots of the same view from two builds; you are NOT told which is newer; ignore file names and paths. Open both with the Read tool and judge which looks better as a shipped game: lighting and exposure, contrast and depth, materials, readability of silhouettes, icons and UI, composition, and visible defects (clipping, overlapping text, blown highlights, floating objects, placeholder art). Pick first, second or tie per scene with concrete reasons.
${pairs.map((pr, i) => `Scene ${i + 1} "${pr.scene}": first = ${i % 2 ? pr.after : pr.before} ; second = ${i % 2 ? pr.before : pr.after}`).join('\n')}`

const integratePrompt = (p, attempt) => `Project: DEADFRONT (Godot 4.7.1 typed GDScript, game/ is the project). You are the INTEGRATOR, the only agent that changes claude/mmo-overhaul (work tree ${BASE}). Integration attempt ${attempt} for package ${p.label} (branch ${p.branch}, work tree ${p.wt}), which passed independent review.${p.intNote ? ' PACKAGE NOTE: ' + p.intNote : ''}
${RULES}

Procedure:
1. Scratch tree: if ${INT} does not exist run: bash ${SP}/mkwt.sh int. Then: git -C ${INT} reset --hard (it is scratch) and git -C ${INT} checkout -B claude/mmo-int claude/mmo-overhaul.
2. git -C ${INT} merge --no-ff ${p.branch} -m "Merge ${p.label} (passed independent review${p.visual ? ' and blind judge' : ''})" plus the trailer. Resolve conflicts correctly (both sides' intent), never by dropping one package's work.
3. Apply the package report's "Integrator hooks" that touch integrator-only files (game/scripts/core/{game,main,world}.gd, game/project.godot, game/tests/run_all.gd, game/scripts/ui/touch_controls.gd) and register its tests/labs in run_all.gd if asked. Hooks in files whose owning package is ALREADY MERGED and has no running successor (e.g. W1-BUILD, W1-HARBOUR, W1-TAME, W1-AI, W1-COMBAT, W1-ITEMS, W1-SAVE, W1-LIGHT, W1-WEB, W1-CANIM, W1-STRUCTART, W1-ICONART files) you DO apply, with their tests. Hooks in files a running package owns (see the ownership list above): do NOT apply; list them in pending_hooks. Commit.
4. --import once (alarm 900). Gates, all through gslot from ${INT}: run_all.gd ([tests] PASS); EVERY game/tests/t_*.gd (each PASS); tools/smoke.sh --no-import (SMOKE PASS); --lab=island_lab headless (exit 0, zero SCRIPT ERROR lines, node/creature counts as before unless the package intends a change); --lab=build_lab; the package's own labs; grep a creature lab run for "couldn't resolve track" (must be 0); no new ~/Library/Logs/DiagnosticReports/Godot-*.ips during your run.
5. Pixels: windowed 1600x900 shots with --lab=home_lab --shot-delay 6 in Forward+ and with --rendering-method gl_compatibility, plus 844x390 landscape, plus the package's own scene if it is visual; save under ${SP}/int/${p.key}-f2a${attempt}-*.png and LOOK at them; compare with earlier shots in ${SP}/int/. A visible regression (blown light, missing HUD, broken layout, floating objects) is a failure.
6. If a gate fails because of the merge itself (conflict resolution, a hook), fix it in ${INT} and rerun. If it fails because of the package, do NOT fast-forward: return merged=false with failures (severity, where, problem, fix).
7. On success: in ${BASE}, move any untracked files that would block the merge to ${SP}/moved-imports/ (never delete), then git -C ${BASE} merge --ff-only claude/mmo-int. If the base moved meanwhile, merge claude/mmo-overhaul into claude/mmo-int, rerun run_all and smoke, and fast-forward again. Then append one line to the "## Merge log" section at the END of ${BASE}/docs/orchestration/mmo/STATUS.md (create it if missing): "- 2026-10-20 merged ${p.label} (<short sha>): <gates>; pending hooks: <list or none>", commit it in ${BASE}.
Return merged, sha, gates (decisive lines), pending_hooks, failures, shots, summary.`

const done = {}
const resolvers = {}
PKGS.forEach(p => { done[p.key] = new Promise(res => { resolvers[p.key] = res }) })
let intChain = Promise.resolve()
const integrate = (p, attempt) => {
  const run = intChain.then(() => agent(integratePrompt(p, attempt), { label: `integrate:${p.key}:a${attempt}`, phase: 'Integrate', schema: INT_SCHEMA, effort: 'high' }))
  intChain = run.catch(() => null)
  return run
}

async function reviewLoop(p, startRound, maxRound) {
  for (let round = startRound; round <= maxRound; round++) {
    const rv = await agent(reviewPrompt(p, round), { label: `review:${p.key}:r${round}`, phase: 'Review', schema: REVIEW_SCHEMA, effort: 'high' })
    if (!rv) return { passed: false, last: null }
    let pass = rv.pass
    const findings = (rv.findings || []).slice()
    let judge = null
    if (pass && p.visual && rv.pairs && rv.pairs.length) {
      judge = await agent(judgePrompt(rv.pairs), { label: `judge:${p.key}:r${round}`, phase: 'Judge', schema: JUDGE_SCHEMA })
      if (judge) {
        let aw = 0, bw = 0
        judge.verdicts.forEach((v, i) => { if (v.better === 'tie') return; ((v.better === 'second') !== (i % 2 === 1)) ? aw++ : bw++ })
        judge.afterWins = aw; judge.beforeWins = bw
        if (bw >= aw) { pass = false; findings.push({ severity: 'major', where: 'blind A/B judge', problem: `A blind judge did not prefer the new build (new ${aw}, old ${bw}). ${judge.overall} Per scene: ${JSON.stringify(judge.verdicts)}`, fix: "Address the judge's concrete reasons so the new build clearly wins every scene." }) }
      }
    }
    if (pass) return { passed: true, last: { round, summary: rv.summary, findings, judge } }
    if (round === maxRound) return { passed: false, last: { round, summary: rv.summary, findings, unmet: (rv.acceptance || []).filter(a => !a.met), judge } }
    await agent(fixPrompt(p, findings), { label: `fix:${p.key}:r${round}`, phase: 'Review' })
  }
  return { passed: false, last: null }
}

async function runPkg(p) {
  try {
    let r
    if (p.integrateOnly) {
      r = { passed: true, last: null }
    } else {
      if (p.waitFor) await done[p.waitFor]
      if (!p.skipWork) await agent(`${ctx(p)}\n\n${p.first}`, { label: `work:${p.key}`, phase: 'Work' })
      const s = p.startRound || 1
      r = await reviewLoop(p, s, p.maxRound || (s + 2))
    }
    let merged = null
    for (let attempt = 1; r.passed && attempt <= 2; attempt++) {
      merged = await integrate(p, attempt)
      if (merged && merged.merged) break
      if (attempt === 2 || !merged) break
      await agent(fixPrompt(p, (merged.failures && merged.failures.length) ? merged.failures : [{ severity: 'blocker', where: 'integration', problem: merged.summary, fix: 'Make the package pass the integration gates on the merged tree.' }]), { label: `fix:${p.key}:int`, phase: 'Review' })
      r = await reviewLoop(p, 9, 9)
    }
    const ok = !!(merged && merged.merged)
    log(`${p.label}: ${ok ? 'MERGED ' + (merged.sha || '') : (r.passed ? 'passed review, integration failed' : 'NOT PASSED')}`)
    return { key: p.key, label: p.label, merged: ok, reviewPassed: r.passed, review: r.last, integration: merged }
  } finally {
    resolvers[p.key]()
  }
}

// Dependents (uiicons waits for ui, buildsys for minors) sit after their dependency in this order, so a waiting
// item never holds a slot its dependency needs.
const POOL = 6
const queue = PKGS.slice()
const results = []
async function worker() {
  while (queue.length) {
    const p = queue.shift()
    const res = await runPkg(p).catch(e => ({ key: p.key, label: p.label, merged: false, error: String(e) }))
    results.push(res)
  }
}
await parallel(Array.from({ length: POOL }, () => () => worker()))
return results.map(r => r ? { key: r.key, label: r.label, merged: r.merged, reviewPassed: r.reviewPassed, error: r.error, last: r.review, integration: r.integration ? { merged: r.integration.merged, sha: r.integration.sha, pending_hooks: r.integration.pending_hooks, summary: r.integration.summary } : null } : null)
