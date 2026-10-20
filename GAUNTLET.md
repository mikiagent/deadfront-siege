# DEADFRONT gauntlet handoff for Claude Fable

Filed 2026-09-21 from Milan's pasted handoff; loop and stale rules updated 2026-10-20 to the MMO program's
working practice. Standing context for every request; Milan's newest explicit correction wins. Companion
documents: `docs/orchestration/mmo/HANDOFF.md` (where everything is, open packages),
`docs/orchestration/mmo/STATUS.md` (owner decisions, merge log), `docs/design/durango-prompts/01`-`12`
(binding design input), `HANDOFF.md`, `UI-REDESIGN-AUDIT.md`, `OPUS-UI-REDESIGN-PROMPT.md`,
`docs/orchestration/prompts/` (newest superseding file wins).

**Classification: FABLE-CRITICAL for core gameplay/save/economy changes. UI-only passes may be delegated as OPUS-SAFE.**
**Repository:** https://github.com/mikiagent/deadfront-siege
**Production:** https://durango-like.vercel.app
**Visual north star:** Durango: Wild Lands information hierarchy, readability, contextual hex interactions, environmental density and finish. Do not copy proprietary art. Build DEADFRONT's own assets to that bar.

## The gauntlet loop - run this on every request

Do not stop at "implemented." Repeat this loop until the build survives it.

1. **Translate** Milan's words into one visible outcome, binding details, protected behavior and measurable gates. His newest explicit correction wins. Check `STATUS.md` "Owner decisions" and the Durango pack for rules that already apply. Do not invent lore, species or mechanics; where the specs are silent, pick the simplest thing and mark it `# ASSUMPTION:`.
2. **Ground** against the integration branch `claude/mmo-overhaul` (until PR #17 merges it into `main`), `docs/orchestration/mmo/HANDOFF.md`, the live production stamp and actual pixels. Never start from an old branch, report or remembered code shape. After pulling merged assets or `class_name` files, run one `--import` first: a stale `.godot` cache shows missing-resource ERRORs that look like code bugs.
3. **Classify risk and scope:**
   - `FABLE-CRITICAL`: gameplay loop, save compatibility, capture/taming, economy, inventory ownership, combat/progression or multiplayer authority.
   - `OPUS-SAFE`: isolated reversible presentation, UI screens, journal/content wiring, exact-note asset integration and test harnesses.
   - Name the owning package and its files (`docs/orchestration/mmo/plan-register.md`). Work on its own branch `claude/mmo-<key>`. Files another package owns, and the integrator-only files (`game/scripts/core/{game,main,world}.gd`, `game/project.godot`, `game/tests/run_all.gd`, `game/scripts/ui/touch_controls.gd`), get exact compiling hooks in the report, not edits.
4. **Reproduce** the exact defect/path first: write the probe or test and see it fail on the old code. For AI, reproduce the exact species brain. For UI, capture the exact current screen at 1600x900 and 844x390 landscape.
5. **Implement narrowly** in the owning subsystem: typed GDScript, data in schemas, presentation in views/UI, independent behavior in a focused component; extract rather than grow god files. Commit early and often (usage limits cut work mid-run). Who does what: Claude agents build; Codex (`gpt-reserve`) for focused one-bug debugging; DeepSeek only if Milan asks; Tripo only for complex creatures and characters; headless Blender scripts for buildings and props.
6. **Prove behavior:** `--import`, every `game/tests/t_*.gd` PASS, `run_all.gd` `[tests] PASS`, `tools/smoke.sh --no-import` `SMOKE PASS`, the exact labs with 0 SCRIPT ERROR lines (creature runs: 0 "couldn't resolve track"), and save/migration coverage when relevant. Tests are silent and use a git-excluded `game/override.cfg` so they never touch Milan's real save; a new `~/Library/Logs/DiagnosticReports/Godot-*.ips` is a failure to explain.
7. **Prove appearance:** windowed shots at 1600x900 in Forward+ AND `--rendering-method gl_compatibility` (the web renderer), plus 844x390 landscape. Look at every one, compare to the Durango references, fix the first visible defect, and inspect again. Logs/node trees are not visual evidence.
8. **Independent review:** someone who did not write the change reruns every acceptance item, tries to break it, and checks scope and code quality; a test that cannot fail is a blocker. Visual work also gets matched before/after shots for a blind A/B judge (not told which is new, order flipped per scene); the new build must win. Fix and re-review until no blocker or major remains.
9. **Integrate:** test-merge into a scratch copy of `claude/mmo-overhaul`, apply the hooks, rerun steps 6-7 on the merged tree, then fast-forward the integration branch, add a line to the STATUS.md merge log and push to GitHub.
10. **Deploy the exact commit only when Milan says.** Current condition: after the UI package passes (lighting is merged). Preserve the DEADFRONT splash, one-buffer loader and cache-eviction behavior.
11. **Verify production:** immutable URL, alias, manifest, and displayed `<commit>/<pack-hash>` stamp. If the alias is stale, the task is not delivered.
12. **Report bluntly:** changed / unchanged / gates / screenshots / review and judge verdicts / commit and PR / immutable URL / alias stamp / remaining risk. Record new owner decisions in STATUS.md. A failed visual or interaction gate blocks promotion.

### Gauntlet completion test

A change is done only when a new tester can reload production and experience Milan's requested outcome without reading the implementation explanation. "Tests pass" is insufficient. "Easy to fix later" is insufficient. A placeholder Milan calls boxy, worm-like, gray, clipped, tiny or ugly has failed. While deploys are on hold (step 10), a change that passed steps 1-9 is integrated, not delivered: say so.

## Durango visual gauntlet

Read the real Durango captures before UI/world presentation work:

- `docs/reference/durango-base-reference.jpg` - stable bottom navigation, quest card, minimap and world labels.
- `durango-combat-reference.jpg` - focused target identity, combat action hierarchy.
- `durango-gather-reference.webp`, `durango-tree-options-reference.webp` - contextual hex wheels and resource identity.
- `durango-crafting-reference.webp` - compact contextual crafting result.
- `durango-placing-reference.webp` - readable placement grid and check/X controls.
- `durango-taming-reference.jpg` - animal focus and contextual verbs.
- `durango-levelup-loot-reference.webp` - level/stat reward hierarchy.
- `durango-look-reference.webp`, `durango-shore-reference.webp` - exploration density and restrained HUD.

Read the implementation-ready UI artifacts at repo root:

- `UI-REDESIGN-AUDIT.md` - ranked current gaps, evidence limits and acceptance matrix.
- `OPUS-UI-REDESIGN-PROMPT.md` - standalone OPUS-SAFE UI implementation prompt.
- `docs/orchestration/prompts/` - filed Journal and UI specs; use the newest superseding file.

Binding UI rules:

- **Color = things; white = actions.** Items/resources/creatures/gear are colored. Commands, menus, gather and HUD action glyphs are white.
- Desktop Chrome 1600x900 is the native judge. Phones play landscape: verify 844x390 (the old portrait 390x844 check is superseded).
- Use responsive anchors, not a phone canvas uniformly enlarged on desktop.
- 8 px spacing rhythm; 44 px minimum target; 56-64 px contextual action target; no metadata below a legible size.
- No overlapping world labels, cropped glyphs, vertical text clipping, controls outside safe areas or text baked into icons.
- Keep one focused target, one contextual wheel and one stable navigation rail. Avoid equal-weight information everywhere.
- Preserve the shipped two-step station interaction.

Fresh live audit corrections: workbench mouse input is fixed; bottom MENU/ANIMALS/BUILD/SKILLS hex family is a viable foundation; circular minimap is stable and now 58% tighter around the player. Current problems still visible include tiny desktop typography, overlapping Workbench/Cargo Warp labels, exposed DEBUG control, sparse hierarchy and low-detail stand-in structures. Recapture Inventory/Animals/Growth/Atlas/craft/build/death before judging them; historical screenshots are not current evidence.

## Binding product rules

- Starter-island dinos and gatherables are level 1. Later ~5-level bands must feel materially harder and more rewarding.
- Material ladder: Stone -> Bone -> Flint -> Obsidian -> Copper -> Bronze -> Iron -> Steel.
- Crafted item level derives from input materials; a level 5 tool must feel clearly better than level 1.
- Capture (spec 09): eligible when stunned/collapsed at ANY HP, or at HP <= 30 %; the chance uses real HP, level and Capture Ability. Supersedes "knocked out and under 30% HP".
- Wild dinosaurs disengage immediately when the target crosses the displayed aggro radius. Verify every species override.
- After dinosaurs kill the player, engaged wild dinosaurs clear combat memory and retreat beyond immediate re-aggro range before respawn.
- Bonded companions (spec 09): 3 slots + 1 per Animal Handling I-IV (Survival 35/45/55/60) up to 7; caged animals are items and never count; three active at once. Captured or traded animals are shown in a cage. Wild genetics hidden until tame; tamed animals may show tier/growth.
- Pets: no death loot bag; persisted HP/regen; combat XP; XP under HP; repeat attacks when sicced; spacing; no player collision; 3-minute death cooldown in Animals UI.
- Packs follow the strongest alpha and remain coherent after a kill.
- Workstations remain two-step: station selection, then expanded hex action.
- Gathering is from reach without teleport; movement cancels; progress appears above the node.
- Player walls may turn transparent/passable for the player while blocking enemies.
- Never let first-run or death presentation look like a crash. Dinosaurs ragdoll onto the terrain on death, then freeze.
- Gathered materials and food do not stack by name (specs 05/08): each is an instance; grouping is visual only.
- Trees, rocks and walls between camera and survivor go partly see-through (about half), never a clear hole; a roof fades when the survivor is under it.
- The harbour stands on the coast with its pier over water.
- Aggro rings disappear on death. Gathering UI stays above pet plates.

## Current architecture

Godot 4.7 typed GDScript. Authoritative project is `game/`.

- `game/scripts/core/` - boot, Data, Game, World, input/save coordination.
- `player/` - lifecycle, movement, combat, gather/build actions.
- `creatures/` and `creatures/brains/` - entity/view/animation/genetics and base/species AI.
- `combat/` - health, vitals, attacks, status, hunt.
- `items/` - inventory, crafting, food and level scaling.
- `pets/` - capture/tame/persistent records.
- `world/` - island runtime, spawn, gather, build, stations, farms, harbour.
- `ui/` - HUD, inventory, Animals/Growth, crafting, gathering, atlas, plates and touch.
- `dev/` - deterministic labs and deployed soak route.
- `game/data/` - JSON definitions.
- `tools/`, `hosting/web/`, `hosting/builds/` - tests, exports, Vercel and native packs.

The god-file split is unfinished. `player.gd`, `island_runtime.gd` and `hunt_hud.gd` are major concentration points. Protect behavior with a lab, then extract new independent behavior instead of adding another mode. Species brains may bypass base AI, so base tests never prove every species.

Repo instructions and old orchestration reports are historical source material, not authority to override this handoff or Milan's newest message.

## Exact release gates

```bash
export GODOT_PATH=/path/to/Godot_4.7
export GODOT_WEB_PATH=/path/to/standard-non-Mono-Godot-4.7

$GODOT_PATH --headless --path game --import
GODOT_PATH="$GODOT_PATH" ./tools/test.sh
GODOT_PATH="$GODOT_PATH" ./tools/smoke.sh
$GODOT_PATH --headless --path game -- --lab=ai_validation_lab
$GODOT_PATH --headless --path game -- --lab=ui_family_lab
./tools/export_web.sh
./tools/deploy_web.sh
CHROME_PATH=/path/to/chrome node tools/production_soak.mjs https://durango-like.vercel.app/
```

Use additional exact labs under `game/scripts/dev/*lab.gd`. `smoke.sh` must print `SMOKE PASS`. The deployed desktop route must exercise real mouse input. Inspect screenshots at 1600x900 (Forward+ and gl_compatibility) and 844x390 landscape. Test longest strings, large counts and three-digit timers.

Web export splits the PCK into content-hashed one-buffer chunks and injects `--build=<commit>/<pack hash>`. HTML/worker/manifests are no-store; hashed pack parts are immutable; the stub service worker removes old PWA caches. Do not break the branded splash or streaming loader.

The `gh` CLI is normally authenticated as `mikiagent`; push work branches and open draft PRs to `main`, and merge into `main` only when Milan says. If this workspace lacks GitHub credentials, create one tested commit on exact `origin/main`, record `%H %P %an %ae %aI %cn %ce %cI`, generate a one-commit format patch, and route it to the authenticated push agent with exact `%cI`. `git format-patch` does not preserve committer time. Require exact SHA before push and remote readback after.

## Asset and art service contract

Canonical concepts live at repo root `assets/concept-art/`, outside Godot packaging:

- `STYLE.md` art bible.
- `README.md` versioning/spend rules.
- `INDEX.md` ledger using `DRAFT`, `APPROVED`, `GENERATED`, `REJECTED`, `INTEGRATED`.
- Per-clip states: `preset-confirmed`, `preset-needs-cleanup`, `custom-T2M-approved`, `Blender-authored`, `fallback-rejected`, `missing`.
- `game/assets/creatures/<species>/ref/` is approved clean-input staging only; retain `.gdignore`.

Existing Meshy and Tripo balances only (spend approved, no cap). Never buy, top up, upgrade or use the API-credit route. Asset routing: Tripo for complex creatures and player characters; headless Blender scripts for buildings and most world objects; do not use Tripo for everything. Record task IDs, spend, source and rejected history. Current autonomous asset grant allows quality-first production within the established operating ceiling; weak output is diagnosed before another spend.

Creature service: concept sheet (Milan approves, batch approvals allowed) -> four clean views -> Tripo multiview mesh -> geometry QA -> rig and clips in headless Blender (library retarget for humanoids) -> verifier gate (skeleton-only clip GLBs WITH the skin, strides in MESH units, limb and ground rules, skin stretch) -> re-import -> Godot creature lab and desktop pixel gate.

Journal behavior art: herbivores get idle grazing/social + defensive scene; carnivores get stalk/rest + feeding on a plausible kill; no gore. Use the newest filed Journal spec.

The future `/showcase` route is the review range. It must be manifest-driven and light, never load the full game. Every rigged asset exposes exact clips with Play/Pause/Restart, loop, 0.25x/0.5x/1x, scrub, orbit/zoom/reset, neutral light, ground/grid and optional skeleton. Error reports bind immutable item/model version, exact clip/action, playback time and camera angle. Showcase votes are review evidence only; they do not authorize spend or mutate INDEX without trusted owner-channel evidence.

## Priority queue

Use the newest user instruction first. Otherwise follow `docs/orchestration/mmo/HANDOFF.md`: section 3 (half-done
packages, UI first because the next deploy waits on it), then section 4 (not started). The old 2026-09-21 list
(release proof, UI gauntlet, Journal, `/showcase`, gatherables, ecology, quality, player bot, mounts and trading)
is folded into those packages.

Do not fake backend/global trading state locally. Do not scale animals arbitrarily to force mount fit. Fish and birds start as showcase concepts with gameplay/readability/performance answers before deep production.

## How Milan works

Milan sends rapid-fire ideas. Preserve all explicit requirements, surface contradictions and follow the newest correction. He judges the browser build and screenshots, not the explanation. He wants short, blunt delivery with a reloadable link and exact stamp. Do not make him audit confidence. If evidence is missing, say so. If capped, report cloud-browser usage as `X/1200 min` and plain `capped til midnight` rather than silently stalling.

## Next-request prompt frame

```text
Classification
- FABLE-CRITICAL or OPUS-SAFE, with one sentence why.
- Owning package, branch (claude/mmo-<key>) and files; hooks needed in files others own.

Outcome
- One user-visible result in Milan's exact terms.

Binding details
- New requirements/corrections.
- Protected behavior, STATUS.md owner decisions, Durango pack rules that apply.

Ground first
- Reproduce on current production and on the integration branch claude/mmo-overhaul.
- Name exact species/state/screen/data path; the failing probe or test.

Implementation boundary
- Likely files and schema changes.
- Explicit do-not-change list.

Acceptance
- Functional result.
- Pixels at 1600x900 (Forward+ and gl_compatibility) and 844x390 landscape.
- Regression/save compatibility.
- Expected production stamp, or "integrated, deploy on hold".

Required evidence
- Import, every t_*.gd, run_all, smoke, exact labs.
- Real desktop interaction soak.
- Inspected screenshots; independent review verdict; blind A/B judge for visual work.
- Merge commit and PR; immutable URL and alias manifest/stamp when deployed.
```

Ask one focused question only when ambiguity changes money, save compatibility, public behavior, multiplayer authority, species identity or a major visual direction. Fill small reversible gaps conservatively and continue the gauntlet.
