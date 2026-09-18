# Engine decision: Godot 4, not Three.js

**Decision:** build the Durango-like in **Godot 4.7** (already installed on this machine, Mono build, with .NET 10).
**Status:** recommended, pending your call.
**Applies to:** the rebuild described in [`docs/prd/durango-wild-lands-systems-prd.md`](./prd/durango-wild-lands-systems-prd.md) and [`docs/prd/dinosaur-roster-and-3d-pipeline.md`](./prd/dinosaur-roster-and-3d-pipeline.md).

---

## The short version

The port was already necessary. `index.html` is 6,204 lines of Three.js r128 in a single file with a global `S` state object, no modules, no build, and no tests. Attribute crafting and island generation alone would double it. So the question was never "port or not," it was **port to what**.

Given that the game logic gets rewritten either way, the only thing that carries across is the art — and **GLB imports into Godot unchanged**. The Meshy pipeline in the roster spec works identically for both targets. So the engine choice costs nothing extra and should be made on merit.

On merit it is not close.

## Why Godot wins for this specific game

**Three.js is a renderer. It is not a game engine.** It draws things. Everything else — scene management, animation state machines, navmesh pathfinding, save/load, input mapping, spatial queries, a content editor — you write yourself. For a wave-defense game that is fine. For a survival MMO-like with 18 rigged creatures, 12 skill trees, an attribute crafting graph, and procedurally generated islands, you would spend most of your time rebuilding an engine badly.

**Animation is the deciding factor, and it is your stated priority.** You asked for dinosaurs that are animated well. Look at what the current file does to get one character moving:

```js
const POSE = {
  recover: { RightArm: [0.3044, -0.2722, -0.2344, 0.8822], ... },
  windup:  { RightArm: [-0.1056, -0.3651, 0.3894, 0.839], ... },
```

Hardcoded quaternions, hand-tuned per pose, for a single survivor. That is the cost of a Three.js `AnimationMixer` with no state machine on top. Multiply by 18 creatures, each needing idle, walk, run, two attacks, hit react, knockdown, and death, with blending between them.

Godot has `AnimationTree` with a visual state machine, 1D and 2D blend spaces, root motion, and per-bone masking built in. That is not a convenience. It is the difference between creatures that animate well and creatures that snap between clips.

**The rest of the roster spec maps onto engine features you would otherwise hand-build:**

| What the design needs | Godot gives you | Three.js |
|---|---|---|
| Creature animation blending | `AnimationTree` state machines, blend spaces | hand-rolled mixer + quaternions |
| Pack AI flanking on terrain | `NavigationServer3D`, navmesh baking, avoidance | write A* and steering yourself |
| Island generation, placing nodes | `GridMap`, editor tooling, `MultiMeshInstance3D` for vegetation | manual instancing |
| Status effect timers and stacking | Nodes + signals, or plain C# | fine either way |
| Skill trees, recipes, stat blocks | `Resource` files, editable in the inspector, serialize free | JSON you hand-parse |
| Save/load a domain | `ResourceSaver` / binary serialization | write it yourself |
| Inventory drag-drop UI | Control nodes with built-in drag-and-drop | DOM, which you already fought |
| Many creatures on screen | proper culling, LOD, instancing | you will hit a wall |

**The Mono build is already installed**, so C# is available. For systems this dense — an inventory graph, a crafting resolver, status stacks — a typed language with real refactoring support is worth a lot more than it would be for a small game. GDScript stays available for scene glue.

## What you lose

Being honest about the trade, because it is real:

- **Instant share links.** Right now you open an HTML file and it runs. Godot's web export is a 20–40 MB WASM bundle with a loading bar, and mobile web performance is noticeably worse. If someone opening a link on a phone in two seconds is a hard requirement, that is the one genuine argument for staying on the web stack.
- **Your current iteration loop.** The ~90 HTML snapshots in this repo are a working method — generate a variant, open it, compare. Godot replaces that with a project you run. Probably an upgrade, but it is a change.
- **Vercel.** You have the Vercel MCP configured. Godot web exports deploy there fine as static files, but it stops being a one-file drop.

Godot exports to desktop and mobile natively, and for a dense systems game those are better targets than mobile web anyway. Durango itself died partly because a game this heavy was mobile-only — anti-requirement §22.5 in the systems PRD.

## The one thing that would change this answer

If the real goal is **a game people click a link and play in a browser in five seconds**, stay on the web stack, and port to Vite plus modules plus modern Three.js instead. Everything else in the two PRDs still applies — the island architecture, attribute crafting, the status system, the creature roster. Only the animation quality ceiling drops, and that is the thing you specifically asked to raise.

So: how much does browser-instant matter to you? That is the whole decision.

## Setup already done

Both MCP servers are configured and healthy:

```
meshy-mcp-server  npx -y @meshy-ai/meshy-mcp-server   ✔ Connected
godot             npx -y @coding-solo/godot-mcp       ✔ Connected
```

The Godot server is [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp), 5.7k stars, published to npm as `@coding-solo/godot-mcp`. It is configured with `GODOT_PATH` pointing at the installed 4.7.1 Mono binary. It launches the editor, runs projects, captures debug output, inspects project structure, and manages scenes.

It is community software, not official Godot tooling. I picked it over the alternatives specifically because it drives Godot through the CLI and **does not inject an editor plugin or autoloads into your project**. The other main option, `mkdevkit/godot-mcp`, exposes 173 deeper editor tools but requires copying an addon into `addons/` and injecting three autoloads, on a repo with 14 stars and 4 commits. Not worth the exposure yet.

**MCP tools register at session start.** Restart Claude Code before the `godot` and `meshy` tools are callable.

## If you say go

1. `godot --headless --quit` a new project at `game/`, C# enabled, Forward+ renderer.
2. Port systems from `index.html` one at a time, treating it as a spec rather than a base: harvest nodes, inventory, crafting, stations, build placement, day/night.
3. Move the ~90 HTML snapshots to `archive/` and the root GLBs to `assets/`, so the repo root is the actual game.
4. Attribute-tagged materials go in **first** — they change what every other system stores, and retrofitting tags later is miserable.
5. Creature pipeline runs in parallel on the art side, blocked on the reference-image problem in the roster spec §4.2.
