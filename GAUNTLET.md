# DEADFRONT gauntlet handoff for Claude Fable

Filed 2026-09-21 from Milan's pasted handoff. Standing context for every request; Milan's
newest explicit correction wins. Companion documents: `HANDOFF.md`, `UI-REDESIGN-AUDIT.md`,
`OPUS-UI-REDESIGN-PROMPT.md`, `docs/orchestration/prompts/` (newest superseding file wins).

**Classification: FABLE-CRITICAL for core gameplay/save/economy changes. UI-only passes may be delegated as OPUS-SAFE.**
**Repository:** https://github.com/mikiagent/deadfront-siege
**Production:** https://durango-like.vercel.app
**Visual north star:** Durango: Wild Lands information hierarchy, readability, contextual hex interactions, environmental density and finish. Do not copy proprietary art. Build DEADFRONT's own assets to that bar.

## The gauntlet loop - run this on every request

Do not stop at "implemented." Repeat this loop until the build survives it.

1. **Translate** Milan's words into one visible outcome, binding details, protected behavior and measurable gates. His newest explicit correction wins.
2. **Ground** against current `origin/main`, the live production stamp and actual pixels. Never start from an old branch, report or remembered code shape.
3. **Classify risk:**
   - `FABLE-CRITICAL`: gameplay loop, save compatibility, capture/taming, economy, inventory ownership, combat/progression or multiplayer authority.
   - `OPUS-SAFE`: isolated reversible presentation, UI screens, journal/content wiring, exact-note asset integration and test harnesses.
4. **Reproduce** the exact defect/path first. For AI, reproduce the exact species brain. For UI, capture the exact current screen at desktop and phone sizes.
5. **Implement narrowly** in the owning subsystem. Add data to schemas, presentation to views/UI and independent behavior to a focused component. Do not grow god files casually.
6. **Prove behavior:** import/compile, full tests, smoke, exact targeted lab and save/migration coverage when relevant.
7. **Prove appearance:** open the current build, inspect pixels, compare to the supplied Durango references, fix the first visible defect, and inspect again. Logs/node trees are not visual evidence.
8. **Deploy the exact commit.** Preserve the DEADFRONT splash, one-buffer loader and cache-eviction behavior.
9. **Verify production:** immutable URL, alias, manifest, and displayed `<commit>/<pack-hash>` stamp. If the alias is stale, the task is not delivered.
10. **Report bluntly:** changed / unchanged / gates / screenshots / commit / immutable URL / alias stamp / remaining risk. A failed visual or interaction gate blocks promotion.

### Gauntlet completion test

A change is done only when a new tester can reload production and experience Milan's requested outcome without reading the implementation explanation. "Tests pass" is insufficient. "Easy to fix later" is insufficient. A placeholder Milan calls boxy, worm-like, gray, clipped, tiny or ugly has failed.

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
- Desktop Chrome 1600x900 is the native judge. Also verify 390x844.
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
- Capture/feed requires knocked out **and under 30% HP**. The old 10% note is superseded.
- Wild dinosaurs disengage immediately when the target crosses the displayed aggro radius. Verify every species override.
- After dinosaurs kill the player, engaged wild dinosaurs clear combat memory and retreat beyond immediate re-aggro range before respawn.
- Unlimited owned animals; three equipped/active. Wild genetics hidden until tame; tamed animals may show tier/growth.
- Pets: no death loot bag; persisted HP/regen; combat XP; XP under HP; repeat attacks when sicced; spacing; no player collision; 3-minute death cooldown in Animals UI.
- Packs follow the strongest alpha and remain coherent after a kill.
- Workstations remain two-step: station selection, then expanded hex action.
- Gathering is from reach without teleport; movement cancels; progress appears above the node.
- Player walls may turn transparent/passable for the player while blocking enemies.
- Never let first-run or death presentation look like a crash.
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

$GODOT_PATH --headless --path game --editor --quit
GODOT_PATH="$GODOT_PATH" ./tools/test.sh
GODOT_PATH="$GODOT_PATH" ./tools/smoke.sh
$GODOT_PATH --headless --path game -- --lab=ai_validation_lab
$GODOT_PATH --headless --path game -- --lab=ui_family_lab
./tools/export_web.sh
./tools/deploy_web.sh
CHROME_PATH=/path/to/chrome node tools/production_soak.mjs https://durango-like.vercel.app/
```

Use additional exact labs under `game/scripts/dev/*lab.gd`. `smoke.sh` must print `SMOKE PASS`. The deployed desktop route must exercise real mouse input. Inspect screenshots at 1600x900 and 390x844. Test longest strings, large counts and three-digit timers.

Web export splits the PCK into content-hashed one-buffer chunks and injects `--build=<commit>/<pack hash>`. HTML/worker/manifests are no-store; hashed pack parts are immutable; the stub service worker removes old PWA caches. Do not break the branded splash or streaming loader.

If this workspace lacks GitHub credentials, create one tested commit on exact `origin/main`, record `%H %P %an %ae %aI %cn %ce %cI`, generate a one-commit format patch, and route it to the authenticated push agent with exact `%cI`. `git format-patch` does not preserve committer time. Require exact SHA before push and remote readback after.

## Asset and art service contract

Canonical concepts live at repo root `assets/concept-art/`, outside Godot packaging:

- `STYLE.md` art bible.
- `README.md` versioning/spend rules.
- `INDEX.md` ledger using `DRAFT`, `APPROVED`, `GENERATED`, `REJECTED`, `INTEGRATED`.
- Per-clip states: `preset-confirmed`, `preset-needs-cleanup`, `custom-T2M-approved`, `Blender-authored`, `fallback-rejected`, `missing`.
- `game/assets/creatures/<species>/ref/` is approved clean-input staging only; retain `.gdignore`.

Existing Meshy web-subscription credits only. Never buy, top up, upgrade or use the API-credit route. Record task IDs, spend, source and rejected history. Current autonomous asset grant allows quality-first production within the established operating ceiling; weak output is diagnosed before another spend.

Creature service: concept sheet -> review/grant provenance -> live web balance -> mesh -> geometry QA -> free Smart-Rig -> actual preset audit -> accepted clips -> approved T2M/Astra-Blender fallback -> Godot creature-lab and desktop pixel gate.

Journal behavior art: herbivores get idle grazing/social + defensive scene; carnivores get stalk/rest + feeding on a plausible kill; no gore. Use the newest filed Journal spec.

The future `/showcase` route is the review range. It must be manifest-driven and light, never load the full game. Every rigged asset exposes exact clips with Play/Pause/Restart, loop, 0.25x/0.5x/1x, scrub, orbit/zoom/reset, neutral light, ground/grid and optional skeleton. Error reports bind immutable item/model version, exact clip/action, playback time and camera angle. Showcase votes are review evidence only; they do not authorize spend or mutate INDEX without trusted owner-channel evidence.

## Priority queue

Use newest user instruction first. Otherwise:

1. Stabilize current release and exact production proof.
2. Durango-style UI gauntlet from the root audit/prompt.
3. Survivor's Journal from the newest OPUS-SAFE filed spec.
4. `/showcase` testing range with per-clip inspection.
5. Biome gatherables from approved design: data-driven identity, yield/tool/climate/level; distinct silhouettes; no overlap/stale nodes.
6. Dinosaur ecology: habitats, herds/packs, predator-prey, territory and population limits.
7. Mistake/quality system: deterministic choice/skill-driven quality.
8. Player bot (`todo-01M33A1W96ZQ88SZV3PNA7MKM4`): autonomous grind metrics plus in-world co-op/trade companion.
9. Mounts, then server-authoritative global trading, then coherent icon set.

Do not fake backend/global trading state locally. Do not scale animals arbitrarily to force mount fit. Fish and birds start as showcase concepts with gameplay/readability/performance answers before deep production.

## How Milan works

Milan sends rapid-fire ideas. Preserve all explicit requirements, surface contradictions and follow the newest correction. He judges the browser build and screenshots, not the explanation. He wants short, blunt delivery with a reloadable link and exact stamp. Do not make him audit confidence. If evidence is missing, say so. If capped, report cloud-browser usage as `X/1200 min` and plain `capped til midnight` rather than silently stalling.

## Next-request prompt frame

```text
Classification
- FABLE-CRITICAL or OPUS-SAFE, with one sentence why.

Outcome
- One user-visible result in Milan's exact terms.

Binding details
- New requirements/corrections.
- Protected behavior and HANDOFF rules.

Ground first
- Reproduce on current production and inspect current origin/main.
- Name exact species/state/screen/data path.

Implementation boundary
- Likely files and schema changes.
- Explicit do-not-change list.

Acceptance
- Functional result.
- Desktop and phone pixels.
- Regression/save compatibility.
- Expected production stamp.

Required evidence
- Import, tests, smoke, exact labs.
- Real desktop interaction soak.
- Inspected screenshots.
- Commit, immutable URL, alias manifest/stamp.
```

Ask one focused question only when ambiguity changes money, save compatibility, public behavior, multiplayer authority, species identity or a major visual direction. Fill small reversible gaps conservatively and continue the gauntlet.
