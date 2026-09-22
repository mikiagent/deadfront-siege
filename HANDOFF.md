# DEADFRONT build handoff for Claude Fable

**Source-of-truth snapshot:** 2026-09-21, prepared from `main` at `ab489b0ccfa53fed3ea7ee0e31fe8e8fd22d91f5` plus the focused raptor, post-kill retreat, Stegosaurus silhouette, and AI regression patch described below.

Use this file as standing context with Milan's next message. Milan's newest explicit request wins. If a request conflicts with this file, stop and call out the conflict instead of silently merging the two.

## 1. Job and quality bar

Build **DEADFRONT**, a dinosaur survival, gathering, crafting, taming, and base-building game in Godot. Its interaction and progression references are Durango: Wild Lands and Last Day on Earth; base growth also borrows from Clash of Clans. The result must look deliberate and near-AAA within the project's stylized low-poly direction, feel addictive in minute-to-minute play, and run reliably in desktop Chrome.

Milan's explicit requests are binding product requirements. Do not substitute a nearby interpretation. If he calls a visual ugly, broken, gray, boxy, worm-like, or unreadable, treat that as a failed gate, not a taste note to explain away. Prefer a smaller polished implementation over a broad placeholder that reads badly.

Current acceptance target:

- **Native judge:** desktop/laptop Chrome, real mouse and keyboard, 16:9. The iOS app is parked while an Apple developer-support case remains open.
- **Secondary constraint:** do not knowingly break mobile/touch. Historical mobile requirements remain useful, but desktop is the current ship gate until Milan changes it.
- **Visual truth:** a successful export, DOM state, node tree, log, or automated test does not prove a visual claim. Open the actual build, inspect pixels at the intended viewport, and retain a screenshot.
- **Production truth:** report the commit, immutable deployment URL, production alias, displayed `commit/pack-hash` stamp, and test results. Never call a build live until the alias serves the exact expected stamp.
- Be blunt. Do not report optimistic feature recaps over a broken build.

## 2. Working protocol for each Milan request

1. Convert the one-liner into a bounded build prompt: user-visible outcome, files/systems likely involved, non-negotiable requirements, acceptance checks, and likely regressions.
2. Inspect the live code and the current production behavior before changing it. Do not assume an old orchestration prompt still describes `main`.
3. Implement the narrowest complete change. Preserve unrelated working behavior.
4. Add or extend a deterministic test/lab that reproduces the exact species, UI family, or state path involved.
5. Run static import, full tests, smoke, targeted labs, then a deployed desktop Chrome soak.
6. For visual or spatial work, inspect actual screenshots. Fix the first visible defect and inspect again.
7. Commit once the tree is clean and evidence passes. Deploy from that exact commit.
8. Verify the alias and stamp. State what changed, what did not, exact evidence, and remaining risk.

Do not use “tests pass” as a substitute for the requested experience. Never promote production when the decisive visual or interaction gate fails.

## 3. Repository and runtime map

Repository: <https://github.com/mikiagent/deadfront-siege>

### Root

- `AGENTS.md` - historical multi-agent ownership guide. Useful background, but some target and agent assignments are stale. This handoff and the newest Milan request win.
- `HANDOFF.md` - this live execution context. Update it when architecture, shipped state, pipelines, or standing rules materially change.
- `game/` - authoritative Godot 4.7 project.
- `tools/` - test, export, deployment, web-pack, asset, and conversion scripts.
- `hosting/web/` - Vercel configuration for the web game.
- `hosting/builds/` - manifest endpoint for downloadable native packs.
- `docs/prd/` - product/design background; useful, not stronger than later explicit Milan requests.
- `docs/orchestration/` - old milestone prompts and reports. Read as history. Do not rebuild from old branches or blindly replay them.
- `docs/reference/` - Durango visual references.

### Godot project

- `game/scenes/` - scenes; `main.tscn` is the gameplay root.
- `game/scripts/core/` - boot, global `Data`, `Game`, `World`, input and save coordination.
- `game/scripts/player/` - player lifecycle, movement, combat, gather/build actions, persistence hooks.
- `game/scripts/creatures/` - creature entity, animation/view, definitions, corpses, genetics.
- `game/scripts/creatures/brains/` - base AI plus species/archetype brains. **Species overrides may bypass base logic.** Any base AI fix needs per-species verification.
- `game/scripts/combat/` - vitals, health, attacks, status, telegraphs and hunt logic.
- `game/scripts/items/` - inventory, crafting, food, item definitions and level scaling.
- `game/scripts/pets/` - capture, field tame and persistent pet records.
- `game/scripts/world/` - island runtime, spawns, gatherables, building, stations, farms, harbour.
- `game/scripts/ui/` - HUD, inventory, Animals/Growth, crafting, gathering, map, plates, touch.
- `game/scripts/dev/` - deterministic labs and web-soak route.
- `game/data/` - JSON-driven items, creatures, recipes, islands, world rules and status data.
- `game/assets/` - imported meshes, textures, animation libraries, icons and nature assets.
- `game/shell/` - downloadable pack loader, checksum/install logic and safe fallback.

### Architecture and god-file split status

The cleanup established typed subsystem classes and JSON-driven definitions, but the god-file split is **not finished**. Do not make large files larger unless the change truly belongs there.

Largest remaining concentration points at this snapshot:

- `player/player.gd` (~2,023 lines): movement, combat, gathering, build/context actions, death/respawn and much UI coordination. New independent behavior should move into a focused component/state object.
- `world/island_runtime.gd` (~1,478): terrain, island population, navigation and runtime world orchestration. Extract new biome/ecology services rather than adding another mode.
- `ui/hunt_hud.gd` (~1,150): HUD composition and screen coordination. Keep new screens/components independent.
- `creatures/creature.gd` (~768), `build_placer.gd` (~617), `creature_brain.gd` (~600), `creature_plates.gd` (~560), `inventory_ui.gd` (~529).

Before a split, protect behavior with a lab. Keep data definitions in `game/data`, reusable domain logic in its subsystem, and presentation in `ui` or view classes. Avoid cross-subsystem calls through scene-tree path guessing; use typed references/signals and existing autoload contracts.

## 4. Build, test and release commands

Use the repo-local scripts. On Linux in this environment the known Godot binary was `/tmp/godot/Godot_v4.7-stable_linux.x86_64`; elsewhere set the paths explicitly.

```bash
export GODOT_PATH=/path/to/Godot_4.7
export GODOT_WEB_PATH=/path/to/standard-non-Mono-Godot-4.7

# Import/compile gate
$GODOT_PATH --headless --path game --editor --quit

# Full behavioral tests and basic runtime smoke
GODOT_PATH="$GODOT_PATH" ./tools/test.sh
GODOT_PATH="$GODOT_PATH" ./tools/smoke.sh        # must print SMOKE PASS

# Exact AI behavior, including raptor radius exit and post-kill retreat
$GODOT_PATH --headless --path game -- --lab=ai_validation_lab

# Inventory/Animals/Growth/UI-family state
$GODOT_PATH --headless --path game -- --lab=ui_family_lab

# Other focused labs use the same --lab=<name> pattern
# names live in game/scripts/dev/*lab.gd

# Web export and production deployment
./tools/export_web.sh
./tools/deploy_web.sh

# Desktop Chrome production soak
CHROME_PATH=/path/to/chrome \
SOAK_ARTIFACTS=/tmp/deadfront-soak \
node tools/production_soak.mjs https://durango-like.vercel.app/
```

The production soak must run at a desktop viewport for desktop acceptance. If the current `production_soak.mjs` defaults to a mobile context, update or invoke the desktop-capable soak used by the current release and keep mobile as an additional check. Exercise real mouse events. A synthetic touch pass does not prove desktop clicks.

Minimum gate for gameplay/UI releases:

- Import has no parse/script errors.
- `tools/test.sh` prints `[tests] PASS`.
- `tools/smoke.sh` prints `SMOKE PASS`.
- Relevant focused labs print PASS and assert the exact bug path.
- Production soak reaches every checkpoint and prints PASS.
- Screenshots show lit, correctly framed gameplay, not a loader/error/black canvas.
- Alias stamp exactly matches the release commit and pack hash.

## 5. Web deployment, stamps and cache behavior

Production alias: <https://durango-like.vercel.app>

The last fully verified big desktop release before this handoff was:

- Commit `ab489b0ccfa53fed3ea7ee0e31fe8e8fd22d91f5`
- Displayed stamp `ab489b0cc/f375312413`
- Immutable deployment <https://durango-like-80ugcha6b-mikiagents-projects.vercel.app>

`tools/export_web.sh` performs a standard Godot HTML5 export, splits the main `.pck` into one-buffer streaming chunks through `tools/web_pack_for_vercel.py`, derives the pack hash from `pack.manifest.json`, and injects `--build=<9-char-commit>/<pack-hash>` into Godot's runtime args. That stamp is displayed in game and is the only reliable tester-facing build identity.

Cache rules:

- `index.html`, the service worker, and manifests are served `no-cache, no-store, must-revalidate` by `hosting/web/vercel.json`.
- Pack chunks are content-hashed and may be cached immutably.
- The old PWA service worker must not pin stale content. `web_pack_for_vercel.py` installs a stub that deletes old caches and unregisters itself, or patches the worker's cache list as appropriate.
- The branded DEADFRONT splash and one-buffer streaming loader must remain intact.
- A Vercel deploy URL is not proof of alias promotion or cache eviction. Fetch/open the alias, read the in-game stamp, and confirm the expected pack manifest.

Native downloadable packs are separate: `tools/publish_clean.sh <ref>` builds from a clean detached worktree, and `tools/publish_pck.sh` exports `core` and `assets`, SHA-256 checks them, uploads changed packs to Vercel Blob, writes `hosting/builds/manifest.json`, and deploys the manifest endpoint. The app downloads, checks and atomically applies them; safe mode removes a bad pack after a failed launch.

## 6. Origin push flow

This workspace may not hold the authenticated GitHub credentials. The established flow is:

1. Commit the tested change locally with author `Instinct Agent <agent@instinct.com>`.
2. Record all identity needed to reproduce the object:

```bash
git show -s --format='%H%n%an%n%ae%n%aI%n%cn%n%ce%n%cI' HEAD
```

3. Generate a single-commit format patch against the exact current `origin/main` parent:

```bash
git format-patch -1 --stdout HEAD > /tmp/deadfront.patch
```

4. Hand the patch and the exact committer timestamp `%cI` to the authenticated push agent. `git format-patch` does **not** preserve committer time, so ordinary `git am` produces a different SHA.
5. The push agent applies it on the exact parent with the recorded committer name/email/date, verifies `git rev-parse HEAD` equals the expected SHA, pushes, and reads `origin/main` back.
6. If the SHA differs, do not push and do not rewrite history casually. Fix the metadata mismatch or provide a git bundle containing the commit and parent.

Always include `%cI` with future patches. Do not claim origin is synced until remote readback returns the exact SHA.

## 7. Shipped state at `ab489b0c`

Live big desktop update:

- Durango-style inventory/character family: stats panel, 5x4 bag, loadout and 3x3 equipment grid.
- Animals + Growth screen: unlimited owned roster, three equipped/active, genetics and level-growth presentation.
- Full map branded as World Atlas.
- Desktop workbench interaction fixed at the root: Chrome's touch-plus-click duplication no longer toggles the radial closed.
- Stegosaurus worm removed; a safe procedural body shipped as a temporary fallback. Milan rejected its first box-like reading.
- Capture/feed eligibility changed to knocked out **and below 30% HP**.
- Base dinosaur AI disengages immediately when a survivor leaves the visible aggro radius.
- One-buffer streaming loader, DEADFRONT splash and visible commit/pack stamp retained.

Focused patch prepared with this handoff and required before the next release:

- `RaptorPackBrain` enforces the same hard radius boundary before combat-memory refresh or alpha target inheritance. This fixes Velociraptor's override bypassing `CreatureBrain._think`.
- `ai_validation_lab` now runs a Velociraptor-specific radius regression and continues to verify base behavior.
- When the player dies, every engaged wild dinosaur clears combat/provocation memory and retreats to valid island terrain at least 14 m away and at least `aggro_radius + 4 m`; the retreat destination becomes its local home to prevent immediate walking back.
- Stegosaurus procedural fallback gains a dorsal plate row and four tail spikes so it reads as a rough Stegosaurus rather than a literal box while the real asset is pending.

At preparation time the focused gates passed: full tests, smoke, `raptor_radius_deaggro=true`, `post_kill_retreat=true` at 24.33 m, and AI lab PASS. It still requires commit, deployment, desktop production soak, exact stamp verification, and visual pixel inspection before it can be called live.

## 8. Binding gameplay and presentation rules

Newest instruction supersedes older contradictions.

### Current core rules

- Starter island dinos and gatherables are level 1. Higher zones/tools/materials must feel clearly stronger and harder, usually in ~5-level bands.
- Material ladder: Stone -> Bone -> Flint -> Obsidian -> Copper -> Bronze -> Iron -> Steel.
- Crafted item level derives from input material levels; a level 5 tool must feel significantly better than level 1.
- Capture/feed requires the dinosaur to be knocked out **and under 30% HP**. An older note says lowest 10%; that was superseded by the shipped 30% rule.
- A wild dinosaur disengages immediately when its target crosses the displayed red aggro radius.
- After dinosaurs kill the player, engaged wild dinosaurs retreat clearly beyond immediate re-aggro distance before respawn.
- Owned animals are unlimited; only three may be equipped/active.
- Wild genetics/IV tiers remain hidden until tame. Tamed pets can show their tier and growth.
- Pets: no loot bag on death; persistent HP and regeneration; combat XP; XP under HP; repeat attacks when sicced; spacing from pets; no collision with the player; 3-minute respawn cooldown shown in Animals UI.
- Pack hunters follow the strongest alpha and do not disperse after a kill. Species overrides must preserve radius disengage and post-player-kill retreat.
- **Color = things, white = actions.** Item/resource/creature icons may be colored. HUD commands, menu actions, gathering glyphs and controls are monochrome white. Do not blur this rule.
- Workstations require two-step interaction: select station, then choose the expanded hex action such as CRAFT or COOK.
- Gathering happens from reach without teleporting the survivor; progress appears above the resource; moving cancels.
- Player-owned walls turn transparent/passable for the player while blocking enemies. Placement is grid-locked, with clear footprints and no overlapping resource nodes.
- Inventory resources stack without an arbitrary cap. Equipment/tools remain meaningful slots.

### Visual and animation rules to retain

- Every meaningful actor and action should animate. Avoid frozen stand-ins as final work.
- Harvest swing is a controlled horizontal wind-up, not a vertical slap or flail. Tools must be reasonably scaled and visible in hand.
- Preserve readable silhouettes and real species anatomy. Do not ship a worm, box, stretched mesh or washed-out gray material as “safe.”
- Aggro rings disappear on death. Gathering UI wins z-order over pet health plates.
- Do not let first-run/tutorial presentation look like a crash.
- Maintain a testing/showcase route for models, animations and assets.

## 9. Product direction and open queue

Execute in this priority order unless Milan overrides it.

### P0 - stabilize current release

1. Ship and verify Velociraptor radius disengage, post-kill retreat, and the readable Stegosaurus fallback.
2. Replace the fallback with the approved real Stegosaurus asset after Gate 1 approval and live credit verification.

### P1 - biome gatherables, approved design

Implement distinct gatherables by biome/climate, not palette-swapped copies. Preserve level-1 starter access and clear silhouettes. Resource-node identity, yield, required tool, climate/biome, level, rarity and visual variant belong in data. Integrate with existing island spawning, gather radial, inventory item colors and level-scaling. Prevent overlap and stale invisible interaction nodes. The approved design brief is available as the private project File previously shared with Milan; if it is not accessible to Fable, ask for its contents rather than guessing.

Acceptance: each biome reads differently at walking distance; starter gatherables remain available at level 1; colors represent items; action glyphs stay white; full gather loop works and persists.

### P2 - dinosaur ecology

Build data-driven habitats, feeding, wandering, herd/pack grouping, predator-prey selection, alpha leadership, territorial/aggression differences and population limits. Avoid omniscient target acquisition. Preserve species-specific brains and radius behavior. Ecology should create observable stories without turning the starter island into constant combat.

### P3 - mistake and quality system

Make crafting/cooking quality respond to player choices and specialist skill rather than a flat timer. Define clear mistake windows, recoverable errors, quality tiers, material/tool/skill influence and readable feedback. Never make errors feel random when the UI implied success. Keep outputs and formulas data-driven and test deterministic boundaries.

### P4 - player bot / companion

Tracked as `todo-01M33A1W96ZQ88SZV3PNA7MKM4`.

Two related outcomes:

- Autonomous playtesting/grind bot that can gather, craft, fight, tame, progress and log time/resource/death/stall metrics. It must expose bad pacing and unreachable loops, not cheat around them.
- In-world companion capable of co-op support and trade. Treat it as a real game actor with explicit inventory ownership, permissions, failure states and networking boundary. Do not fake global multiplayer state inside a local UI.

### P5 - mounts

Use large tameable dinosaurs for travel and utility. First define eligible species, saddle/equipment, mount/dismount, collision/camera, stamina/speed, combat limits and save state. Do not scale creatures arbitrarily just to make riding fit.

### P6 - global trading

Design server-authoritative listing, escrow, settlement, cancellation, abuse/rate limits, item identity, duplication prevention, offline delivery and audit logs before UI. This requires backend work and cannot be honestly shipped as a local-only screen.

### P7 - coherent icon set

Finish item/resource/gear/status icons using the color rule. Meshy-made or rendered object icons may be used for items; action icons stay white. Verify every icon at actual inventory/HUD size and against dark/light contexts.

## 10. Asset pipeline and credit constraints

### Non-negotiable spend rule

Use **Meshy web subscription credits already available only**. No API-credit workaround, no subscription upgrade and no purchase. Verify the live web balance before generation. A stale API balance or old log is not proof. State the cap for each batch and stop when reached. No speculative “one more try.”

### Gate 1 and Batch 2

Gate 1 proves one asset end to end before batch production: approved concept/reference -> clean multi-view inputs -> Meshy web generation -> topology/material/scale review -> rig/animation -> Godot import -> creature lab -> desktop gameplay pixels. Milan approves the reference direction before any generation credits are spent.

Batch 2 begins only after Gate 1 proves the pipeline. Keep source, processed GLB, import settings, license/source notes, scale and animation mapping recoverable. Reject assets with broken anatomy, unreadable silhouette, baked labels, gray materials, bad pivots, missing textures or animation deformation before integration.

### Stegosaurus status

A Gate 1 concept/reference sheet is pending Milan's approval: unsaddled realistic adult, olive/sand body, rust-charcoal plates, clear side/front/top/rear-three-quarter views, long raised tail, staggered plates and four-spike thagomizer. No Meshy generation was started and zero credits were spent. The live balance check was blocked until local midnight; the previously recorded API figure of 3,823 is stale and must not authorize spend.

After approval, crop/export clean side/front/top input views so labels and sheet layout do not enter generation. Do not generate before live web balance confirmation.

### Astra hybrid verdict

Use the hybrid pipeline for rig surgery: GPT-6 Astra through Codex can write and run Blender scripts for bone mapping, transforms, weight repair, animation transplant, batch validation and reproducible export. It does not replace visual judgment. Meshy supplies/generates the base asset; Blender scripts perform deterministic surgery; a person/agent inspects deformation and in-game pixels. Keep scripts and mapping artifacts in the repo so later models are not forced to repeat manual fixes.

## 11. How to work with Milan

- He sends rapid-fire bursts. Preserve each explicit requirement, condense them into one ordered prompt, identify contradictions and use the newest correction.
- He judges the browser build, not the explanation. Give him a reloadable production link and a short exact stamp.
- Desktop Chrome is his current judge. Use real mouse input. Keep mobile from regressing, but do not cite a mobile emulation pass as desktop proof.
- He notices ugly placeholders immediately. Make honest visual calls before asking him to review.
- Use short, blunt closeouts: what changed, stamp/link, what passed, what remains. Do not make him audit your confidence.
- If the alias is stale, say it is stale. If pixels were not inspected, say they were not inspected. If a generation balance is unknown, do not spend.

## 12. Prompt template for the next build

Give Fable this file plus Milan's newest words, then use this frame:

```text
Outcome
- [One user-visible result stated in Milan's terms.]

Binding details
- [Exact new requirements and corrections.]
- Preserve HANDOFF.md rules unless this request explicitly changes one.

Ground first
- Reproduce on the current production alias and inspect current main.
- Name the exact species/state/UI path involved.

Implementation boundary
- Likely files: [...]
- Data/schema changes: [...]
- Do not change: [...]

Acceptance
- Functional: [...]
- Visual at desktop Chrome viewport: [...]
- Regression: [...]
- Stamp expected: <commit>/<pack hash>.

Required evidence
- Import, full tests, smoke, exact labs.
- Desktop production soak with real mouse.
- Inspected screenshot(s).
- Commit SHA, immutable URL, alias readback and displayed stamp.
```

If the one-liner is ambiguous in a way that changes money, public behavior, save compatibility, multiplayer authority, species identity, or a major visual direction, prepare the plan and ask one focused question before implementation. Otherwise fill small gaps conservatively and build.
