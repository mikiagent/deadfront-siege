# Orchestration plan: the Durango-like in Godot

**Owner:** Claude Code (orchestrator). **Date:** 2026-09-17.
**Inputs:** `docs/engine-decision.md`, `docs/prd/durango-wild-lands-systems-prd.md`, `docs/prd/dinosaur-roster-and-3d-pipeline.md`, `game/data/creatures/SCHEMA.md`.

## 1. Decisions taken so the work can start

These resolve the open questions in systems PRD §25 far enough to build. Each is reversible early and expensive later; say so now if one is wrong.

| # | Decision | Why |
|---|---|---|
| D1 | **Intent C**: a new game that is Durango with the anti-requirements fixed. Not a faithful clone, not a Deadfront mod. | The roster PRD already rejects Durango's tame nerf and adds status effects. |
| D2 | **Mobile-first controls, desktop as the dev target.** Godot 4.7.1, orthographic isometric camera, landscape. Touch is the primary input (floating joystick, action buttons, pinch zoom); keyboard and mouse must keep working. Godot's `mobile` renderer on phones, Forward+ on desktop. No web export in v1. *(Changed 2026-09-17 from PC-only at the owner's request.)* | Owner wants a mobile game. Anti-requirement §22.5 still applies: keep the session loop light and the HUD uncluttered. |
| D3 | **Typed GDScript, not C#.** | Both coding agents drive Godot from the CLI; C# adds a build step to every run loop. Revisit only if a system profiles hot. |
| D4 | **Single-player first.** Data models must not assume one player (no globals for inventory, pets, claims), but no server in v1. | A solo project cannot staff an MMO. Systems PRD §20 says private islands are the scalable part anyway. |
| D5 | **Snapshot C rules**: pen taming with S–C grades, no Savage islands, no PvP. | PRD default. |
| D6 | **Biped-first roster, three theropods before anything else.** | Roster PRD §4.1: the quadruped route is manual and ~5x the cost. |
| D7 | **Attribute-tagged items go into the data layer in M0**, before any crafting UI. | Engine decision, step 4: retrofitting tags is miserable. |
| D8 | The old `index.html` is a spec. Nothing is ported line-for-line. | Engine decision. |

## 2. The first playable: "the raptor slice"

One temperate island at tier 25. The player lands at camp, harvests fibre and herbs, crafts a bandage and a stone knife, hunts a Velociraptor pack, takes Bleed and Knockdown, bandages, knocks a raptor down, nets it, pens it, bonds it, rides it. Deinonychus and Utahraptor roam the far side of the island as the escalation.

That slice exercises: creature animation, pack AI, hunt combat, the Bleed status family and its counters, capture, the pen, pets, gathering, slot-based inventory with attributes, one flexible recipe. It does not need islands that sink, skill research timers, factions, markets, or domains. Those come after the slice is fun.

## 3. Who does what

```
Claude Code ── plan, contracts, review, merge, smoke test, credit approval
   ├── Codex  ── Meshy pipeline: reference image → image-to-3D → rig → clips → validation sheet
   └── Cursor ── Godot: milestones M0..M5 in order, one prompt each
```

Folder ownership is in `AGENTS.md`. Codex and Cursor never edit the same folders, so they run in parallel without branches. Communication is asynchronous through `docs/orchestration/reports/`. Claude Code reads every report, runs the game through the Godot MCP, and writes the next prompt.

Codex is on a small budget, so its prompts are few and dense and it works through `tools/meshy.py` (a batch script) rather than a long conversation. Cursor gets one milestone per prompt.

## 4. Milestones

Each milestone ends with: smoke test passes, a dev scene shows the feature, a report is written. Estimated Meshy credits are listed where they apply. Balance at start: 3,895.

| ID | Agent | Deliverable | Depends on | Prompt |
|---|---|---|---|---|
| **C1** | Codex | Prove image-to-3D on Utahraptor: accepted side-view reference, one mesh with a horizontal spine and a long tail, validation renders. ≤ 60 credits. | — | `prompts/codex-01-utahraptor-proof.md` |
| **C2** | Codex | ~~Velociraptor, Deinonychus, Utahraptor fully rigged with all contract clips.~~ **BLOCKED 2026-09-17**: Meshy's rigging API is humanoid-only and rejected all three meshes (HTTP 422, pose estimation). Meshes and references are good and kept. 48 credits spent. | C1 accepted | `reports/codex-C2-three-theropods.md` |
| **C2b** | Codex | **Route decided 2026-09-17: skeleton transplant.** Meshy mesh + Quaternius CC0 donor rig and clips, fitted in Blender (`tools/transplant_rig.py`, proven by the orchestrator on all three theropods). Codex hardens it (landmark fit, mesh repair, missing clips, Protoceratops) and finishes the survivor's clips. | — | `prompts/codex-03-transplant-hardening.md` |
| **P1** | Claude | **Done 2026-09-17.** Player character through Meshy's humanoid route: reference → Meshy 7 mesh → rig → idle/walk/run/hit_react/death. 53 credits. Files in `game/assets/characters/survivor/`. | — | `prompts/cursor-M4a-player-mesh.md` integrates it |
| **S1** | Claude | Stand-in creatures: import a CC0 animated dinosaur pack (Gobkit, 10 species, idle/attack/dead/walk) mapped onto the clip contract so M1–M3 are visible and tunable before C2b lands. | owner OK on stand-ins | — |
| **M0** | Cursor | Repo cleanup to `archive/`, Godot MCP loop proven, item/attribute data layer, inventory, harvest node, dev lab scene. | — | `prompts/cursor-M0-foundation.md` |
| **M1** | Cursor | Creature runtime: JSON → CreatureDef, AnimationTree state machine on the clip contract, clip merging loader, placeholder mesh, navmesh, `raptor_pack` brain. Works with placeholders before C2 lands. | M0 | `prompts/cursor-M1-creature-runtime.md` |
| **M1b** | Cursor | Real GLBs: clip-track remap, facing/scale normalisation, input hygiene, commit M0–M3. | M1 | `prompts/cursor-M1b-real-meshes.md` |
| **M2** | Cursor | Hunt combat + status effects: vitals, auto-attack, tactics, telegraphs, roll, Bleed / Deep Bleed / Knockdown / Groggy with on-model FX, Bandage and Cauterise. | M1 | `prompts/cursor-M2-hunt-and-status.md` |
| **M3** | Cursor | Capture, pen, bond, summon, mount, bag. Wild stat block unchanged when tamed. | M2 | `prompts/cursor-M3-capture-and-pets.md` |
| **M4** | Cursor | Gathering tools, processing chain, flexible recipes with primary-slot attribute inheritance, craft UI that shows the primary slot. | M0 | written after M1 review |
| **M5** | Cursor | The island: terrain, camp, climate/fatigue, day-night, crater, spawn tables by tier, sink timer. Vegetation from the Quaternius Ultimate Nature Pack (CC0, 150 models converted to `game/assets/nature/`, mapped in `game/data/nature_manifest.json`). | M1b, M4a | `prompts/cursor-M5-island.md` |
| **C3** | Codex | Protoceratops (Triceratops donor rig), then Ankylosaurus, Stegosaurus, Coelophysis, Compsognathus in tier order; side + front references with arms tucked for every theropod. | C2b | written after C2b review |
| **M4** | Cursor | Tools, butchering, processing chain, flexible recipes with primary-slot inheritance, craft UI. | M5 | `prompts/cursor-M4-crafting.md` |
| **M6** | Cursor | **Your own island**: home grassland island with a one-time terrain choice, harbour travel graph, protected no-tax building, tent rest, cargo warp for unstable goods, save/load. | M5, M4 | `prompts/cursor-M6-private-island-and-save.md` |
| **MOB1** | Cursor | iOS export preset, Xcode project, on-device performance pass, touch pass on a real phone. | M5 | `prompts/cursor-MOB1-phone-build.md` |
| **M7** | Cursor | Cooking and food: energy from meals, skewer → grill → steam, boil-to-uprank, poison persists, food inspector. Farming fields and wells. | M4, M6 | later |
| **M8** | Cursor | Skills: 12 trees as data, SP budget that forces specialisation (PRD §7.3), research gates, capture ladder wired to real SP. | M4 | later |
| **M9** | Cursor | Factions, missions and the **Island Market**: Communications Centre, four radio organisations, mission pins, trust ranks, T-stone sinks, and the simulated four-region market with price memory (`docs/design/economy.md`, `game/data/world/market.json`). | M6 | later |
| **M10** | Cursor | Unstable island lifecycle: islands spawn per climate and tier, sink on timer, craters and warp ruins, follow-route unlock, volcanic later. | M6 | later |
| **M11** | Cursor | Remaining creature archetypes on the roster as art lands: herds with solidarity AI, scavengers on corpses, night behaviour, raid-scale Tarbosaurus. | C3 | later |

Order of execution (updated 2026-09-17 evening): Cursor M4a → M5 → M4 → M6 → MOB1 → M7…; Codex C2b → C3. Product target restated by the owner: a Durango-like with a persistent private island, playable on a phone. M1 starts when M0 reports. C2 starts when C1 is accepted. M1 ships against placeholders, then swaps in C2's meshes. M2 and M3 follow. M4 can interleave whenever Cursor is blocked on review.

## 5. How the loop runs

1. Paste the prompt file into the agent. Prompts are self-contained; they name the files to read.
2. The agent works, then writes its report.
3. Claude Code: reads the report, runs `tools/smoke.sh`, opens the dev scene through the Godot MCP, reads the diff, and either accepts (commit + next prompt) or sends the agent a short follow-up listing what to fix.
4. Meshy spend: every Codex prompt has a hard cap. Codex reports credits used; Claude Code checks the balance through the Meshy MCP before writing the next prompt.

## 6. Contracts everyone codes against

- **Creature files and clip names:** `game/data/creatures/SCHEMA.md`.
- **Orientation:** Meshy meshes face +Z; Godot `CreatureView` rotates them 180 degrees. Nobody bakes the rotation into the asset.
- **Data before code:** stats, recipes, statuses, and archetype tuning are JSON under `game/data/`, loaded into Resources by `scripts/core/data.gd`. Scripts never carry balance numbers.
- **Print tags:** `[boot]`, `[smoke]`, `[creature]`, `[combat]`, `[status]`, `[capture]`, `[item]`. The smoke script and reviewers grep for these.
- **Every input is an InputMap action.** The touch layer (`scenes/ui/touch_controls.tscn`, autoloaded) presses actions; gameplay reads actions. Never read touch, mouse or keys directly in gameplay code. New verbs get an action in `input_setup.gd` and, if they need a thumb, a button in `touch_controls.gd`.
- **Touch UI rules:** tap targets at least 64 px in the 1600x900 canvas, respect `DisplayServer.get_display_safe_area()`, no hover-only information, tooltips open on tap and close on tap-outside.
- **Statuses** are defined once in `game/data/statuses.json` with the numbers from roster PRD §3, and applied through one `StatusEffects` component that enforces the cap of three.

## 7. Known risks and what to do about them

- **(Resolved) Meshy cannot rig dinosaurs; the transplant route does.** Meshy image-to-3D gives correct silhouettes for ~24 credits per species; a CC0 donor rig (Quaternius, 37 bones, six clips) is fitted and weighted in Blender, with a voxel proxy because bone-heat weighting fails on AI meshes with holes. The main character uses Meshy end to end (humanoid rig + presets + text-to-motion). Blender MCP is configured for all three agents.
- **(Realised) Meshy cannot rig dinosaurs.** The roster PRD §4.1 assumed "biped" meant any two-legged animal; the API means humanoid. Three requests, three 422s, zero credits. Consequence: the whole roster, theropods included, needs an external rigging route. The Meshy image-to-3D + texture stage still works and is cheap (24 credits per species); only rig and motion move elsewhere. Do not spend Meshy credits on motion clips until a rig exists.

- **Image-to-3D might not fix the tail either.** C1 exists to find out for 60 credits. If it fails, the fallback is a commissioned or hand-drawn silhouette, and C1 says so in its report instead of spending more.
- **Meshy's rig output names bones differently across runs.** C2 re-rigs from the same refine task, so all clips for one species share a rig. The loader checks bone paths on merge and logs a `[creature]` error rather than crashing.
- **Godot's headless run cannot show animation.** Visual acceptance for M1 and beyond happens in the editor window through `launch_editor` / `run_project`, with Claude Code looking at the running scene and the debug output.
- **Codex's Meshy key** in `~/.codex/config.toml` differs from the one Claude Code and Cursor use, and the roster PRD notes an earlier key was revoked. Verify it before C1 or copy the working key across.
- **Two agents on one working tree.** Folder ownership avoids conflicts; each agent commits only its own folders. If a prompt needs a cross-folder change, Claude Code makes it.
