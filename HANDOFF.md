# DEADFRONT build handoff for Claude Fable

**Source-of-truth snapshot:** reconciled 2026-10-27 against local `main` (`aaca9aa1`, four tidy-up commits on top of the Oct 22 work tree named in section 7). Sections 3, 7, 9 and 10 carry current truth; the 2026-09-21 claims that moved are superseded by those sections.

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

Measured 2026-10-27 (brains moved out of creature.gd into `creatures/brains/` — keep extracting that way):

- `player/player.gd` (~2,331 lines): movement, combat, gathering, tame/feed, pets, mounts, build/context actions, death/respawn and much UI coordination. New independent behavior should move into a focused component/state object.
- `world/island_runtime.gd` (~1,527): terrain, vegetation scatter, creature spawn, props, weather. Extract new biome/ecology services rather than adding another mode.
- `ui/hunt_hud.gd` (~1,483): HUD composition and every sheet panel inside one class. Keep new screens/components independent.
- `ui/inventory_ui.gd` (~826), `dev/bot_survivor.gd` (~769), `creatures/creature.gd` (~812), `world/build_placer.gd` (~696), `ui/creature_plates.gd` (~634), `creatures/brains/creature_brain.gd` (~613), `items/crafting.gd` (~427).

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

## 7. Shipped state (reconciled 2026-10-27)

Fully verified big desktop release on the production alias remains `ab489b0c` (stamp `ab489b0cc/f375312413`, immutable URL <https://durango-like-80ugcha6b-mikiagents-projects.vercel.app>). Work since then is committed to `main` but has **not** been re-deployed, re-soaked or stamp-verified unless a playtest doc says so. Theme summary of everything shipped since `ab489b0c` (evidence: git log, `docs/playtests/`):

- **Biome-distinct gatherables (former P1) — done deep.** 10 climates in `game/data/world/climates.json`; 60+ families in `game/data/nature_manifest.json` with per-climate models, harvest-yield tables and mineral nodes (obsidian→tropical, copper→desert, silver→snowfield, black iron→volcanic, coral/pearl→blue-tropical); `island_runtime` scatters from the climate tables; climate palette + climate fatigue. Starter island stays level 1 via `level_override` (regression-tested).
- **Creature AI.** Raptor radius disengage and post-kill retreat (≥14 m, re-homed) shipped and regression-locked in `ai_validation_lab`; brains split into `creatures/brains/` (`raptor_pack_brain.gd`: alpha election, flank slots, post-kill retargeting; `tyrant_brain.gd`; `pet_brain.gd`).
- **Taming/pets.** Capture requires knockdown **and <30% HP**; preferred/accepted feed loop with window timer and rage-fail; net-capture tiers I–V gated by skills; unlimited roster, 3 active (`MAX_PETS_OUT`), pet XP/grades; genetics/IVs (0–31, EV caps, D-→S+) persist through save schema v3.
- **Playtest bot.** `dev/bot_survivor.gd` plays the real game loop through a 14-rung ladder with its own throwaway save; bugs it found got fixed: cargo capacity, hide-strap recycle exploit, corpse material quality, harvest pathing, storage training, craft-skill XP routing, camp travel, save merges.
- **Sleep and fatigue.** Explicit tent sleep button, retargeted sleep clips, fatigue gains tuned per owner (×0.5), stronger tired/exhausted penalties, fatigue scaled by island level gap and climate, fatigue breakdown panel.
- **Nature art waves.** Berry bush full/empty pair, common/palm/pine/willow/birch/acacia trees incl. snow variants, ground plants, rocks, stumps/logs, mineral and plant resource nodes. True snow bush asset still open.
- **Tyrannosaurus.** Stand-in replaced by Tripo-converted mesh with DeepSeek (dsc) rig transplant; final heavy-animation judgment still needs hands-on review.
- **UI pass (Oct 17–22, committed 2026-10-27).** Animals screen rebuild (pinned actives, roster + detail, hex portraits), menu sheet (Save, display toggle, Controls page, new-survivor tip), named bag cards, item icon manifest; screens captured under `docs/design/current-ui/`. Still not redesigned: craft sheet, World Atlas, build placement, death/respawn screen, HUD nav labels, settings screens; gamepad focus on the 4 HUD hexes.
- **Platform.** Fullscreen (F11) and gamepad bindings; TestFlight release uploaded (installs remain blocked by the Apple support case; iOS parked; iOS is secondary, desktop Chrome is the ship gate).
- **Stegosaurus.** 48-credit mesh generated and transplanted onto the Quaternius Triceratops donor skeleton under `game/assets/creatures/stegosaurus/`; catastrophic weights mean `creature_view.gd` still forces the procedural fallback (plate row + thagomizer); the animated clip set loads in-engine. Weight repair is the open asset task.
- **Zebraceratops.** Build completed at 48 of the authorized 96-credit cap, no paid rigging (`game/assets/creatures/zebraceratops/work/art_direction.json`).

The 2026-09-21 "focused patch required before next release" (raptor override radius, post-kill re-home, stego plate row) shipped and is covered by the AI lab; that paragraph is superseded by this section.

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

## 9. Work queue (reconciled 2026-10-27)

Status of the old P0–P7 list: P0 done (raptor radius/retreat shipped); P1 done deep (biome gatherables, climate data, mineral nodes); P2 partial (herds, per-island spawn tables, population caps exist; habitat/diet/wild-feeding data absent); P3 absent beyond level-math quality and a random burn roll; P4 half done (playtest bot yes, in-world companion no); P5 thin (mount/dismount + MountSocket + 10 species tagged, no saddle items or stamina); P6 restarted as simulated-economy-first per Milan 2026-10-27; P7 mostly shipped via the icon manifest, rule not code-enforced. The queue below contains only open work, in this order unless Milan overrides:

1. **Housekeeping decisions** (owner input needed): `game/addons/` (55 MB: GD-Sync, godot_ai, kanban_tasks, terrain_3d — none enabled in project.godot, but terrain_3d ships a .gdextension that auto-loads) and `game/demo/` (24 MB Sep 2026 Codex demo kit, referenced by nothing). Commit, gitignore, or delete each.
2. **Stegosaurus weight repair** (asset task): Blender bone/weight surgery on the transplanted mesh per section 13; lift the `creature_view.gd` forced placeholder once deformation is clean; creature lab + desktop pixel inspection; then set INDEX.md to INTEGRATED with the real route.
3. **UI gap pass**: craft sheet, World Atlas, build placement, death/respawn screen, HUD nav labels/density, settings screens (graphics/volume/UI size/reduced motion/colorblind/gamepad), gamepad focus model for the 4 HUD hexes. Spec: `docs/design/ui-ux-spec.md`.
4. **Ecology (P2 remainder)**: habitat/diet fields per species JSON, wild feeding loop, predator–prey selection data, population-pressure stories; keep species brains and radius behavior supreme.
5. **Quality/mistake system (P3)**: deterministic quality tiers, mistake windows, skill/tool influence, readable feedback; never random when the UI implied success; feed proposals from `docs/design/durango-informed-improvements.md` items 6–7.
6. **Simulated economy (was P6, Milan decision 2026-10-27)**: regional markets per `docs/design/economy.md`, wired to `data/world/market.json` (currently loaded by no script); listing fee, price formula, buy side, unstable-goods gate, T-stone sinks. No server work, no public trading, until the simulation proves the formulas.
7. **P4 remainder / P5 remainder / P7b**: in-world companion actor; saddle items + recipes, stamina, mount save state; enforce colour=things / white=actions on icons.
8. **Release gates still open**: production soak on the exact commit, 390x844 pass for touched screens, grove label density, save-migration soak, first-human-tame onboarding check, true snow bush asset, T-rex heavy-animation confirmation.

## 10. Asset pipeline and credit constraints

### Non-negotiable spend rule

Use **Meshy web subscription credits already available only**. No API-credit workaround, no subscription upgrade and no purchase. Verify the live web balance before generation. A stale API balance or old log is not proof. State the cap for each batch and stop when reached. No speculative “one more try.”

### Gate 1 and Batch 2

Gate 1 proves one asset end to end before batch production: approved concept/reference -> clean multi-view inputs -> Meshy web generation -> topology/material/scale review -> rig/animation -> Godot import -> creature lab -> desktop gameplay pixels. Milan approves the reference direction before any generation credits are spent.

Batch 2 begins only after Gate 1 proves the pipeline. Keep source, processed GLB, import settings, license/source notes, scale and animation mapping recoverable. Reject assets with broken anatomy, unreadable silhouette, baked labels, gray materials, bad pivots, missing textures or animation deformation before integration.

### Stegosaurus status (2026-10-27)

- Gate 1 journal art: concept and the idle+combat two-scene pattern authenticated in `assets/concept-art/INDEX.md`; approval anchor recorded there.
- Mesh: `work/stegosaurus_i2m_v1.glb` generated and transplanted onto the Quaternius Triceratops donor skeleton (`skeleton_transplant_v3` in `game/data/creatures/stegosaurus.json`), 48 credits. The animated clip set (idle/walk/run/attack/alert/hit_react/knockdown/death/feed) loads in-engine.
- Blocker: catastrophic bone weights cause worm-like stretching, so `creature_view.gd` deliberately forces the procedural fallback. The route forward is Blender weight surgery per the section 13 pipeline (bone mapping, donor vertex-group transfer, per-clip deformation audit); do not spend on regeneration before the repair route is judged futile.
- Triangle budgets: `assets/concept-art/STYLE.md` was reconciled 2026-10-27 to the measured Durango table in `docs/art/durango-asset-benchmarks-and-tripo-prompts.md` (small 1.2–1.8k, medium 1.8–2.5k, large/boss 2.5–4k tris, 512² textures, matcap-first). Current creatures measure 24–31k tris and owe remeshing.

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

## 13. Canonical concept library and rig service

Concept and production inputs are deliberately separate:

- `assets/concept-art/` at repository root is the canonical, versioned concept library. Keeping it outside `game/` prevents Godot from importing or packaging working art.
- `assets/concept-art/STYLE.md` is the shared art bible.
- `assets/concept-art/README.md` owns approval, versioning and credit-spend rules.
- `assets/concept-art/INDEX.md` is the status ledger. Use only `DRAFT`, `APPROVED`, `GENERATED`, `REJECTED`, or `INTEGRATED`; record exact approval anchor, Meshy task ID/route, credits, output, rig state and per-clip state.
- Clip states are `preset-confirmed`, `preset-needs-cleanup`, `custom-T2M-approved`, `Blender-authored`, `fallback-rejected`, or `missing`. Never infer coverage from a marketing clip count.
- Store sheets and clean views under `assets/concept-art/creatures/<species>/`. Approval is version-specific. A changed sheet gets a new numbered version and new Milan review.
- `game/assets/creatures/<species>/ref/` is generation-input staging only. Copy approved, label-free clean crops there and retain `.gdignore` so reference art never enters the game pack.

Use this nine-step rig and animation service for every creature:

1. Create the numbered concept sheet and ledger row as `DRAFT`.
2. Get Milan's approval of that exact version and record the authenticated message anchor.
3. Verify the current Meshy web-subscription credit balance and the approved batch cap.
4. Generate the mesh through the existing-subscription web route; record task and spend.
5. Run Meshy Smart-Rig on the accepted mesh.
6. Audit the actual preset/action catalog for that species and deformation; update each clip independently.
7. Export only accepted clips, with exact source/action and file recorded.
8. For missing or bad clips, use approved Text to Motion when its cap covers it, then Astra-authored Blender rig/weight/animation surgery. Mark rejected fallbacks rather than silently shipping them.
9. Import into Godot, run the creature lab, and inspect desktop gameplay pixels for anatomy, scale, material, foot contact, plate/tail deformation and every required state before `INTEGRATED`.
