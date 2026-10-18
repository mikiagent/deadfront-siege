# DEADFRONT AAA survival-MMO program: status

Owner request (2026-10-18): raise every system to an ARK: Survival Ascended bar and turn the game
into a persistent multiplayer MMO with a real, server-validated marketplace. This file is the loop's
memory: each iteration reads it, runs the next wave, and updates it.

Integration branch: `claude/mmo-overhaul` (worktree `.claude/worktrees/mmo-overhaul`), cut from
local `main` at 77748a4. Contracts: `docs/orchestration/mmo/contracts.md`.

## Constraints found so far

- Engine stays Godot 4.7.1 typed GDScript (the owner's prompt says "Three.js and the existing
  stack"; the existing stack is Godot, and a rewrite would discard 540 commits of working game).
- The web build uses the gl_compatibility renderer: no SDFGI, volumetric fog, SSR or SSIL there.
- No audio exists in the project (0 sound files). Sourcing sounds means downloading packs, which
  needs the owner's yes.
- New creature meshes cost Meshy/Tripo credits, which need the owner's yes per batch.
- A public multiplayer server needs a host that keeps WebSockets open (Vercel cannot). Until the
  owner picks one, the server runs locally and is tested with real local clients.
- Concurrent session `deadfront-armor-mount` owns survivor v2, armor slots and the T. rex mount
  (touches items.json, recipes.json, inventory.gd, item_def.gd, inventory_ui.gd).
- The owner's main checkout holds an uncommitted UI pass (hunt_hud.gd, inventory_ui.gd,
  animal_screen.gd, item_icons.gd). Not in this branch; do not overwrite it.
- Machine: 15 cores, 24 GB. Godot runs go through the scratchpad `gslot.sh` (5 at a time).
  Every work tree has a git-excluded `game/override.cfg` so user:// never touches the owner's save.

## Waves

| Wave | Packages | State |
|---|---|---|
| 0 | 16-system audit with adversarial verify and plan | running |
| 1a-audio | CC0 audio layer (`claude/mmo-audio`) | running, reviewer-gated (wf_abafae3d-0a6) |
| 1a | economy engine (`claude/mmo-econ`); net core: server, auth, presence, chat (`claude/mmo-net`) | running, reviewer-gated (workflow wf_158b264c-baf) |

## Owner decisions

- 2026-10-18: keep the server local for now; build and test with local clients; ask about hosting when it is ready.

- 2026-10-18: agents may download CC0/royalty-free audio packs (record source and licence per file).
- 2026-10-18: Meshy/Tripo credit spend approved with no cap, from existing balances only (never buy,
  top up or upgrade). Record task ids and spend per asset; diagnose weak output before re-spending.
- 2026-10-18: the uncommitted 2026-10-17 UI pass in the main checkout: owner is not sure whose it
  is. Leave it untouched; do not commit or overwrite it.

- 2026-10-18 asset routing: Tripo ONLY for complicated creatures and player characters; rigging and
  animation by the DeepSeek CLI (dsc) used as a subagent (game-asset-pipeline skill); buildings and
  most world objects built with Blender MCP + Blender skills. Do not use Tripo for everything.
- 2026-10-18: when the program is done, ship it to GitHub (push; owner authorised).
- 2026-10-18 design direction (owner): UI/UX needs a lot of work. Make a clear, fun gameplay loop
  of gathering -> crafting -> building (and back), and an economy of resources: rare items, with
  progression locked behind rare items or crafting recipes. The loop is the priority that makes it
  fun; the marketplace should trade those rare goods.
- 2026-10-18 item look (owner): items should look cool with cool icons; idea: each item is a PNG
  render that sits above / overflows its button rather than a flat glyph inside it. Plan: render
  real item art (3D models built in Blender MCP, rendered with consistent studio light, transparent
  PNG, rarity rim/glow) via tools/render_icons.py, and give slots an art-overflow layout. Colour =
  things, white = actions still holds.
- Balances 2026-10-18: Tripo 3,240 credits (works). Meshy MCP key returns 401 (revoked), so the
  art route is Tripo + the game-asset-pipeline skill until the owner replaces the Meshy key.

## Owner questions (open)

- none
