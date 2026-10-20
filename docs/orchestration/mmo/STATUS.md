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

## Known defects (owner-reported)

- 2026-10-18 "weird brightness, too bright" in a raptor test window. Cause: flat-colour ambient at
  0.7-0.75 energy plus a 1.2-1.3 sun with the default linear tonemap and no exposure control, in
  both `dev/lab_kit.gd:6-18` and `world/island_runtime.gd:187-219`; labs also build their own
  lighting, so lab screenshots do not match the game. Evidence: audit shots
  `dino-art/raptor_scale_lab_cam10.png`, `dino-ai/aival_pack.png`. Fix belongs to the lighting
  package: one shared lighting builder used by island and labs, sky-sourced ambient, AgX/filmic
  tonemap with calibrated exposure, and a no-blown-highlights pixel check.

## Waves

| Wave | Packages | State |
|---|---|---|
| 0 | 16-system audit with adversarial verify and plan | plan done: `plan-register.md` (ranked gaps, waves 1-4, 21 owner questions) |
| 1 (merged) | W1-TAME, W1-CANIM, W1-BUILD, W1-ITEMS, W1-WEB, W1-AI, W1-LIGHT (blind judge 6/6), W1-COMBAT, W1-SAVE, raptor re-animation (dsc) passed review and are merged into `claude/mmo-overhaul`; gates: import, [tests] PASS, t_tame/t_canim/t_build/t_items PASS, SMOKE PASS | done |
| 1 | W1-LIGHT, SAVE, TAME, AI, CANIM, COMBAT, BUILD, ITEMS, SRVDOM, QA, UI, ICONART, WEB, BIOME, STRUCTART (each `claude/mmo-w1-<key>`) | launching, reviewer-gated, blind A/B judge on visual packages |
| 1-INT | merge econ/net/audio + sound settings + market over socket | after wave 1a and audio pass review |
| 1-ART | ARTA/ARTB Tripo species | concept sheets generating (Higgsfield gpt_image_2_5, critic-checked, wf_4ea0904a-0e6); then one owner batch approval |
| merge | survivor-v2/armor/T. rex mount merged into `claude/mmo-overhaul` (0fef2a3) | import, [tests] PASS, SMOKE PASS |
| 1a-audio | CC0 audio layer (`claude/mmo-audio`) | running, reviewer-gated (wf_abafae3d-0a6) |
| 1a | economy engine (`claude/mmo-econ`); net core: server, auth, presence, chat (`claude/mmo-net`) | running, reviewer-gated (workflow wf_158b264c-baf) |

## Releases

- 2026-10-18 22:00 production: `548804ac8/f34e148e39` (claude/mmo-overhaul = main + survivor v2/armor/T. rex
  mount; wave 1 not yet merged). Local browser boot checked into the world before deploy; alias
  stamp verified.

## Plan amendments for wave 2+ (from plan-critic.md)

- W2-SURVIVAL (new): hunger, thirst and temperature meters with drinking, starvation and climate/
  weather/clothing temperature; HUD bars; tuned so the loop stays fun.
- W2-BREED (new, pulled forward from W4): breeding, eggs/gestation, incubation, hatching, growth
  stages, imprinting/offspring care, inheritance and mutations (incl. colour mutations), lineage;
  domain built node-free like W1-SRVDOM, plus UI and tests.
- W2-ACTION (new): the owner's hybrid combat action mode (click-to-swing, dodge, block, aimed ranged)
  with its camera; acceptance must be measurable.
- W2-DEATH (new): recoverable death loot bag (ownership, despawn timer, server authority later) and
  equipped-gear durability loss on death.
- W2-CVIEW gains: remove the Stegosaurus box override (creature_view.gd:65-66, one line now), and the
  web render cost of creatures (60 creatures = ~6 fps in gl_compatibility; Label3D, particles and two
  AnimationPlayers each) with a Chrome fps gate.
- W2-ECO and W2-BUILDSYS: wild dinosaurs attack blocking structures (owner yes), with a test.
- Camera: occlusion fade/roof cutaway for tall builds and relief; action-mode camera.
- W3: server restart persistence test (structures, nodes, pets, population), latency/loss injection,
  replication of armor/held weapon/mount state, players-per-island target.
- Later/owner: PvP and tribes (PRD default no PvP), weight/encumbrance, loot crates and supply
  drops, map discovery, swimming, caves, onboarding, accessibility (rarity not by colour only),
  key rebinding, graphics settings, telemetry, account deletion.
- W1-INT's reviewer must deep-audit the econ/net/audio branches (no auditor ever ran them).

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
- 2026-10-18 building and crafting (owner): intricate building and crafting systems; building is a
  big deal. Processing must feel impactful, e.g. drying meat: you see the strips hang on the rack,
  change colour over time, smoke drifts, it sounds right, and the result matters (dried meat keeps
  while raw meat spoils, carries a real buff, sells well). Apply that bar to every station.
- Balances 2026-10-18: Tripo 3,240 credits (works). Meshy MCP key returns 401 (revoked), so the
  art route is Tripo + the game-asset-pipeline skill until the owner replaces the Meshy key.

- 2026-10-18 orchestrator decision: contracts v2 section 0. Online characters are server-owned and
  islands are server-simulated; clients send intents. The audit rated v1's client deposits P0.

- 2026-10-18: Blender MCP connected (Blender 5.2, addon 1.8, port 9876, execute_code + viewport
  screenshots). One Blender instance: only one agent drives Blender MCP at a time; others use
  headless Blender scripts kept in tools/. Asset libraries (Poly Haven etc.) are off.

- 2026-10-18 (owner): add a sound setting, and keep the game muted while agents test. Done for
  tests: scratchpad gslot.sh forces `--audio-driver Dummy` on every Godot launch and exports
  DEADFRONT_MUTE=1. Rule for every agent prompt: never play audio aloud (no afplay/ffplay/say);
  judge audio by measurement. Required in the audio package (follow-up after its build): a Sound
  settings panel (Master, Music, Ambience, SFX, Creatures, UI sliders + Mute all), persisted,
  reachable from the menu with a one-line hook, a mute hotkey, and the game honouring `--mute` and
  the DEADFRONT_MUTE env var by muting Master at boot.

- Decided by the owner's original 2026-10-18 request (planner questions 7, 8, 13, 19 and 9): breeding,
  inherited traits, mutations, growth stages and offspring care are IN (overrides PRD:747);
  ARK-style survival meters (health, stamina, hunger, thirst, temperature) and hazards are IN; caves
  are IN; base defenses imply wild dinosaurs can attack blocking structures; predators may outrun a
  walking survivor (data-driven, tuned per species). Market defaults (0.25x-4x bands, 30 min trade
  lock), faucet rate and steam cap use the planner's defaults as # ASSUMPTION until the owner tunes them.

- 2026-10-18 owner answers: (1) merge the survivor-v2/armor/T. rex mount branch into the MMO
  branch now; (2) the 7 new species' concept sheets are approved as one batch before any Tripo mesh;
  (3) combat = keep tap-target auto-attack AND add an action mode (click-to-swing, dodge, block,
  aimed ranged); (4) death = inventory drops in a recoverable loot bag at the death spot and
  equipped gear loses durability; pets keep the 3-minute respawn rule.

- 2026-10-19 (owner): low-quality and low-poly assets are marked for replacement in
  `asset-replacement.md`; every art package reads and updates it.
- 2026-10-19 (owner): delegate long mechanical work to dsc overnight. Running: re-animation of
  velociraptor+utahraptor and protoceratops+megaloceros in ~/Documents/DeepseekCLI/deadfront-reanim/
  ({bipeds,quads}, $6 and 8 h cap each, verify.sh = creature-verify + contact sheets). Review before
  anything enters the repo.
- 2026-10-19: usage limit cut every running workflow; partial work is WIP-committed on each branch.

- 2026-10-19 (owner): the mobile view is HORIZONTAL (landscape). Phone checks use 844x390, not
  390x844 (GAUNTLET.md's 390x844 is superseded). project.godot already uses sensor-landscape.

- 2026-10-19 (owner): next production deploy waits until W1-LIGHT and W1-UI pass review and merge;
  then deploy everything merged and verify the stamp.

- 2026-10-19 (owner): the UI pass may want new custom icons for many UI elements. Plan: a W1-UIICONS
  package after W1-UI merges (it owns hex_button/status_glyph): one coherent custom white action
  icon set (menu, animals, build, skills, hands/held tool, claim, harbour, gather verbs, combat verbs,
  craft/cook, settings, market) authored as SVG, rendered to PNG at HUD sizes, replacing system emoji
  and game-icons glyphs; reviewed at real HUD size on desktop and landscape phone.
- Quad dsc clips (protoceratops, megaloceros) reverted: the skeleton-only re-export dropped the skin
  (skins=0), so Godot could not resolve tracks. Redo with a skin-preserving export.

- 2026-10-19 (owner) pets as items: tamed animals show an icon of that animal. As an item an animal is
  in a CAGE (when traded or freshly captured). Taming consumes the caged animal (pen/tame turns the
  cage into a bonded pet; already true for captured_animal). A tame can be REPACKAGED into a caged item
  and sold. Plan W2-CAGE: repackage (bonded pet -> unique caged item carrying the full PetRecord, uid,
  lineage; refused while summoned/active or with items in its bag) and unpack (caged tame -> bonded pet,
  no re-taming); per-species portrait icons and caged-animal item art (species render inside a cage,
  rarity rim from grade) via headless Blender; Animals screen uses the portraits (W2-SCREENS consumes
  them); the Exchange lists pets as caged items. Captured (untamed) and repackaged (tamed) cages read
  differently (e.g. rope-tied wild vs tagged tame).

- 2026-10-19 (owner): a caged animal (captured or repackaged) can also be RELEASED as a wild dinosaur
  that you can fight (it turns hostile/wild at its own level and genetics; pet ownership ends; the
  cage is consumed). There must be a MOB LIMIT and a PLAYER LIMIT per area for performance. Plan:
  data-driven caps per area/island (rules.json: max_creatures_area, max_players_area); released
  animals count toward the mob cap and a release at the cap is refused with a notice; the population
  director (W2-SPAWN) never spawns past the cap; on the server (W3-SRVWORLD) a full area/instance sends
  new players to another instance (channel) and presence rooms enforce max_players_area. Caps get a
  perf test (perf_budget_lab at the cap stays inside the frame budget on web).

- 2026-10-19 (owner): "functionally fine, but the symbols/icons need work; the building system needs real
  buildings; the harbour is a grey block in the middle of land and must be attached to water; stuff
  like that is holding the game back from AAA." Re-prioritised: W1-HARBOUR (coast-forced placement,
  dock over water, real composite instead of the box) and W1-UIICONS (custom white SVG action set)
  started now (wf_8598d187-a3f); W1-STRUCTART (Blender buildings + 4-stage drying rack + dock) is the
  next wave-1 batch; W2-BUILDSYS (modular foundations/walls/roofs, tiers, HP, repair) starts as soon as
  W1-STRUCTART and W1-HARBOUR merge.

- 2026-10-20 (owner) Durango prompt pack: `docs/design/durango-prompts/01..07` (fatigue/energy/stamina;
  taming pen and companions; level 60, 12 categories, SP, research gates, resets; instance loot with
  Firm/Lightweight/... attributes, processing, primary/secondary slots, crafting ability, flawless;
  instance inventory, capacity, containers, dino cargo, one-location rule; fixed-price Island Market
  with exact instances, fees/tax, Receive All; semi-auto combat, stances, telegraph + timed roll, net
  capture). Binding as design input; values the pack marks illustrative stay configurable. Refs:
  docs/reference/durango-{fatigue-meter,gather-hud-levelup,bag-caged-animal}.*. Package mapping:
  01 -> W2-SURVIVAL; 02 -> W2-CAGE + taming depth; 03 -> W2-SKILLS (new); 04 -> W2-DATA/W2-PROCESS +
  W2-CRAFT (new); 05 -> W2-INV; 06 -> W3-EXCHANGE (Durango tabs Buy/Sell/My Listings/Sold/Expired/
  History + Receive All, on top of the owner's auctions and buy orders); 07 -> W2-ACTION + combat.
  Kept from earlier binding rules unless the owner says otherwise: capture below 30 % HP (pack says
  ~50 %, configurable); unlimited owned pets with 3 active (pack says 7 bonded, configurable).
  Stacking decision (orchestrator, compatible with pack 05 'configurable category-specific stacking'
  and with existing saves): items stack only when def, level, every attribute, flags and durability
  match exactly (today's ItemStack rule); trait-bearing materials therefore stay individual, plain
  goods still stack; the bag shows optional visual grouping. Owner may switch to strict non-stacking.
  Note: fatigue/exhaustion returns (owner removed exhaustion on 2026-09-20; the pack, being newer,
  reintroduces it with no unrecoverable state).

## Owner questions (open)

- none
