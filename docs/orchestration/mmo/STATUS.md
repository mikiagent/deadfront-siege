# DEADFRONT AAA survival-MMO program: status

Owner request (2026-10-18): raise every system to an ARK: Survival Ascended bar and turn the game
into a persistent multiplayer MMO with a real, server-validated marketplace. This file is the loop's
memory: each iteration reads it, runs the next wave, and updates it.

**2026-10-20 16:30: the orchestration loop is stopped and the work is handed over to `~/Documents/deadfront`.
Read `HANDOFF.md` (same folder) first.**

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
| 1 (merged) | W1-TAME, W1-CANIM, W1-BUILD, W1-ITEMS, W1-WEB, W1-AI, W1-LIGHT (blind judge 6/6), W1-COMBAT, W1-SAVE, W1-HARBOUR (blind judge 6/6), dsc re-animations (velociraptor, utahraptor, protoceratops, megaloceros combat/ground/rest, compsognathus, coelophysis, gallimimus) passed review and are merged into `claude/mmo-overhaul`; gates: import, [tests] PASS, t_tame/t_canim/t_build/t_items PASS, SMOKE PASS | done |
| 1 | W1-LIGHT, SAVE, TAME, AI, CANIM, COMBAT, BUILD, ITEMS, SRVDOM, QA, UI, ICONART, WEB, BIOME, STRUCTART (each `claude/mmo-w1-<key>`) | launching, reviewer-gated, blind A/B judge on visual packages |
| 2a | W2-PLAYER (player split + PlayerActions), W2-BREED (breeding, growth, mutations, capture rule 09, bonded cap 3->7), W2-ECO (ecosystem, structure targeting) in claude/mmo-w2-<key>; builders hand mechanical parts to dsc sub-worktrees | running (wf_e4b5bc5d-f50) |
| 2a+ | W2-OCCLUDE: shared see-through occlusion (tall trees, later roofs/walls; roof fades when the survivor is under it) | running (wf_6986c1a3-c0c) |
| 2a+ | W2-BUILDSYS: modular foundations/walls/doorways/windows/ceilings/roofs/ramps/stairs with snapping, structure HP, tiers + upgrade/repair, owner-passable walls; stand-in meshes swap to Blender models by data (structures.json); roofs fade via the occlusion API | running (wf_dcd34d26-be7) |
| finish-1..4 | finish-1 merged W1-STRUCTART (+hooks) and W1-ICONART; finish-2 merged DSC-MINORS; finish-3 merged DSC-CLIPS (judge 6/6); each was cut by a usage limit. finish-5 (wf_0472e0fd-634, replaced finish-4 at 16:10 after the owner took DeepSeek off) continues all open packages from their real state: UI fix r3, reviews for W2-OCCLUDE / W2-BUILDSYS / W2-PLAYER / W1-SRVDOM (builds done), DSC-CAMP fix r1 (dirt disc hides the fields; bed/shelter/fence scale) with a squash-merge, DSC-QUADS2 (new walk/run, megaloceros run 71 % of target by rig reach), W2-RAGDOLL, W1-UIICONS wiring after UI, then BREED, ECO, QA, BIOME, ECON, NET | running |
| dsc | quads-loco2 done (VERIFY PASS, $1.26), mmo-camp done (VERIFY PASS, $0.51; review r1 found the field/disc issue), mmo-icons2 and mmo-w2-ragdoll-dsc1 stopped by the owner's call (0/4 milestones), taken over by Claude in finish-5 | 2026-10-20 16:10 |
| 1-INT | merge econ/net/audio + sound settings + market over socket | after wave 1a and audio pass review |
| 1-ART | ARTA/ARTB Tripo species | concept sheets generating (Higgsfield gpt_image_2_5, critic-checked, wf_4ea0904a-0e6); then one owner batch approval |
| merge | survivor-v2/armor/T. rex mount merged into `claude/mmo-overhaul` (0fef2a3) | import, [tests] PASS, SMOKE PASS |
| 1a-audio | CC0 audio layer (`claude/mmo-audio`) | running, reviewer-gated (wf_abafae3d-0a6) |
| 1a | economy engine (`claude/mmo-econ`); net core: server, auth, presence, chat (`claude/mmo-net`) | running, reviewer-gated (workflow wf_158b264c-baf) |

## Releases

- 2026-10-18 22:00 production: `548804ac8/f34e148e39` (claude/mmo-overhaul = main + survivor v2/armor/T. rex
  mount; wave 1 not yet merged). Local browser boot checked into the world before deploy; alias
  stamp verified.
- 2026-10-20 16:25 GitHub: pushed `claude/mmo-overhaul` (255d0434) to origin; draft PR https://github.com/mikiagent/deadfront-siege/pull/17 to main (owner asked; not merging into main until the owner says). Push again as packages merge.
- 2026-10-20 16:35 production (owner: "deploy now if its working well enough"): `31c064a08/2284b9bf56` (W1-UI, W1-SRVDOM, W2-PLAYER on top of wave 1), dpl_A5KprWiU5R8LZ1VSyBbigEs8w4cA, alias https://durango-like.vercel.app verified (index.html build stamp + pack.manifest.json). Pack 254.0 MB: over the W1-WEB 220 MB ceiling, exported with PAYLOAD_MAX_MB=260 after dropping survivor_v1 (unused) from the Web preset; trimming survivor (69 MB) and nature/generated (51 MB) is open. Local browser boot: character creation -> island pick -> world -> gather ring, no console errors. Seen defects: Lv. 0 on a new survivor's badge and XP line, HANDS hex over character creation, a grey harbour slab on the meadow home.

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
  Note: fatigue/exhaustion returns (owner removed exhaustion on 2026-09-20; the pack, being newer,
  reintroduces it with no unrecoverable state).

- 2026-10-20 (owner) addenda 08 and 09 (docs/design/durango-prompts/), superseding my earlier calls and
  the older HANDOFF rules they contradict:
  * STACKING: gathered materials, food and cooking ingredients do NOT stack by name. Each is its own
    instance with level/traits/processing state and its own bag slot; visual grouping only. Stacking
    stays configurable per category (currency, some consumables). Save migration splits old stacks into
    instances without ever deleting any (overflow goes to home cargo/storage, logged). Bag capacity per
    pack 05 (base 100 + equipment/Pocket bonuses).
  * CAPTURE: eligible when the animal is stunned/collapsed at ANY HP, OR HP <= 30 % (supersedes
    "knocked out AND under 30 %"); chance uses actual current HP, level and Capture Ability; ~50 % HP
    tutorial hint "Stun the dinosaur to capture it safely"; never force damaging a stunned animal down.
  * BONDED PETS: capacity 3, raised by Survival -> Animal Taming -> Animal Handling I-IV (Survival 35/
    45/55/60, SP 4/5/5/6, +1 each) to 7; checked when forming a bond; caged/unbonded animals and pens
    never count; a reset keeps existing pets but blocks new bonds until under capacity (supersedes
    "unlimited owned, 3 active"). Pets UI shows "n / cap".
  * COOKING (08): in-place processing vs new-food recipes from exact ingredient instances; slot roles
    main/topping/sauce/broth/spice with per-recipe inheritance flags; topping/broth buffs; digestion;
    buff stacking rules; Cooking category + crafting ability + flawless via the shared pipeline.
    Package W2-COOK (with W2-PROCESS and W2-INV).

- 2026-10-20 (owner): use DeepSeek (dsc) subagent workers for coding tasks. Standing rule for every
  package from now on: Claude agents design, review and integrate; MECHANICAL coding (fix lists, data
  entry, test writing, wiring, migrations with a clear spec, repetitive edits across files) goes to dsc
  via a TASK.md + a read-only verify script (`dsc cook start TASK.md --once --verify <script> --budget N
  --max-hours N --effort high` in the package worktree), and the Claude agent reviews dsc's diff before
  committing it as its own. dsc runs Godot only through gslot.sh. First dsc coding batch: 38 reviewer
  minors on the merged wave-1 packages (worktree mmo-dsc-minors, gate tools/dsc/verify_minors.sh).
- 2026-10-20 (owner): parallelize dsc workers, up to 6 at a time. Split big mechanical jobs into several
  independent workers (one folder or worktree each, own fast milestone gate, full gate at the end).

- 2026-10-20 orchestrator pixel check of the merged build (home island, web renderer, harbour_lab wide):
  lighting and coast read well; harbour is a pier on the shore. Defects logged: world label overlap
  (Harbour over Survivor) -> W1-UI/W2-HUD; blown white sun glare on water and a hard water band at the
  screen bottom -> W2-TERRAIN water; salmon prop palette -> W1-STRUCTART.

- 2026-10-20 (owner): tall trees that obscure the survivor must turn see-through; modular buildings need
  square foundations and roofs that are visible from outside but transparent when the survivor is under
  them. One shared occlusion system (W2-OCCLUDE) serves trees now and W2-BUILDSYS roofs/walls later.

- 2026-10-20 (owner) spec 10 `docs/design/durango-prompts/10_construction_building_quality.md` + reference
  `docs/reference/durango-camp-workstations.webp` (a working camp: kiln with fire, hides on drying racks,
  loom, spinning wheel, colour dye vats, workbench, all visibly in use). Buildings are CRAFTED objects:
  blueprint unlocked in the Construction tree -> construction site -> exact material instances ->
  finished level = min(clamp(avg material level, bp min, bp max), construction level); material traits
  convert to building effects (Lightweight -> storage space, High Density -> durability, Beautiful
  Pattern -> comfort, disinfectant -> antibiotic...); storage capacity, comfort/antibiotic recovery,
  house complexity, workstation types/levels/parallel job slots, durability and repair.
  Split: W2-BUILDSYS (running) keeps the modular pieces/snapping/HP/tiers/roof fade but MUST keep its
  data compatible with spec 10 section 11 (blueprint material_slots, building instance with level,
  inherited_attributes, max/current durability, owner, container_id). New package W2-CONSTRUCT does the
  spec-10 quality layer (sites, level/attribute inheritance, storage/comfort/antibiotic/complexity,
  workstation levels and queues) after W2-INV, W2-CRAFT and W2-SKILLS. The camp reference is the art
  target for W1-STRUCTART/W2-PROCESS stations (dye vats, loom, spinning wheel, kiln, hide racks).

- 2026-10-20 (owner) spec 11 `docs/design/durango-prompts/11_processing_skill_material_transformations.md`
  + UI references `docs/reference/durango-craft-build-menu.webp` (category column, sectioned recipe list,
  detail card with Max Level / Related Ability / Skill Category, a material slot that takes a FAMILY
  such as "Leaf, Stalk 0/2" filled with exact picked instances, yellow Craft) and
  `docs/reference/durango-skill-screen.webp` (12-category icon grid with levels, Career Guide banner,
  detail panel with skill level and Used SP, SP counter). Processing = component manufacture,
  in-place modification (finite processing attempts per instance, trade-off traits), and alloys;
  Handicraft and Metal Processing Ability separate from category level; station type/level and tool
  gates; delegated queue jobs; one shared transformation + preview service. Mapping: 11 -> W2-PROCESS
  (engine, recipes, stations, queues) + W2-SKILLS (Processing tree nodes, abilities, research gates);
  the two screens are layout targets for W1-UI (skills sheet grid, craft card) now and W2-SCREENS later.

- 2026-10-20 (owner) spec 12 `docs/design/durango-prompts/12_remaining_skill_trees.md`: coverage for the
  undercovered categories (13 incl. optional Toxic Oil Islands; 918 reference nodes, import as data, mark each
  node functional/partial/defined, never an inert tree). Extends existing data (game/data/butchering.json,
  farming.json, skills/), no second XP/item/combat systems. Mapping, in the spec's priority order:
  1) gathering parts + techniques + abilities and carcass part selection -> new W2-GATHER and W2-BUTCHER
  (after W2-INV + W2-SKILLS); 2) fields/seed instances/growth -> W2-FARM, clothing slots + fabric-trait
  climate bonuses -> W2-TAILOR (with W2-SURVIVAL climate); 3) tool/weapon part branches, saws gating
  harvest tiers -> W2-CRAFT; 4) Barrage, Roll Duration, parry -> W2-ACTION; 5) Stealth Ability in the
  real AI detection + mineral nodes -> W2-SKILLS/eco; Toxic Oil Islands -> optional W3 content pack.

- 2026-10-20 (orchestrator) W1-UI's last blocker was a lab gate on the bag that needed edits to
  hunt_hud.gd/inventory_ui.gd. W2-HUD/W2-SCREENS have not started, so W1-UI now owns those two files and
  lands its hooks patch on its own branch (option a). New survivors show "Lv. 1" (Durango, ARK and the
  old bag all start at 1). W1-UIICONS wires its icons into the HUD itself after W1-UI merges. All five
  dsc workers (minors, audio, quads-loco, zebra, trex-sleep) and the player dsc worker finished; their
  results are vetted and integrated by finish-1 (audio waits for W1-INT).

- 2026-10-20 (orchestrator) W1-UI open questions: the level-1 title "Venture into the World" is held
  from character creation (no level-up toast); skills keep their internal levels in W1-UI, and W2-SKILLS
  re-keys them to Durango's 1-60 scale with Lv1 AUTO nodes (spec 12), so "skills show Lv. 0" is a known
  item for W2-SKILLS, not a W1-UI blocker.

- 2026-10-20 (owner) see-through occluders: "partially see through not fully see through, it should still
  feel like the tree is there not a clear hole in it". A tree or rock between camera and survivor fades as a
  whole object to about half coverage (keep 40-60 % of its pixels, no hard circular cut, soft 0.25 s fade);
  roofs may fade further when the survivor is under them but keep a faint outline. W2-OCCLUDE restarted with
  pixel gates for this in finish-3 (wf_ffc48fe3-dc5); W2-BUILDSYS walls/roofs follow the same rule.

- 2026-10-20 (owner) "if you're having issues with dead dinosaurs not staying on the ground, try having them
  ragdoll on death". New package W2-RAGDOLL (wf_2cc5d74a-087, branch claude/mmo-w2-ragdoll): the death clip's
  first beat as the hit reaction, then PhysicalBone3D ragdoll onto the terrain collider, freeze once settled
  (no per-frame cost), at most 4 simulating, fallback to the clip plus terrain-conformed pose; per-species
  profiles in game/data/creatures/ragdoll.json written by a dsc worker; gates on posed-skin ground contact,
  lying height, joint limits, physics cost and a blind judge. The orchestrator integrates it after review.

- 2026-10-20 (owner) "enlist codex for some debugging tasks but use a smaller model than astra". Codex runs on
  gpt-reserve (the smaller model the ChatGPT plan accepts; gpt-6.1-sol/6-sol/6-luna are refused), medium
  reasoning, one bug per worktree: codex-harbour (travel to a moved dock, basket follow, walkable pier, site
  check rows), codex-animals (Animals screen 0x0 rect / no backdrop / CLOSE over HARBOUR), codex-errors
  (the world.gd:124 / hunt_hud.gd:965 SCRIPT ERRORs and a lab sweep). Found so far: worktree clones copied a
  stale import cache from mmo-overhaul; the base was re-imported and mkwt.sh now imports after cloning.

- 2026-10-20 (owner) "take over deepseek's work because i don't think they are making progress". The icons2
  (3.5 h) and ragdoll-profile (2.1 h) dsc workers had ticked 0 of 4 milestones; both stopped, their work kept as
  WIP commits, and Claude agents took them over. Claude agents now do all package work; no new dsc workers
  unless the owner asks. finish-4 was replaced by finish-5 (wf_0472e0fd-634, `.claude/worktrees/deadfront-finish-5.js`)
  with ICONS2 added and the "delegate to dsc" rule removed.

- 2026-10-20 (owner) the non-stacking inventory save change is approved: merge it once its independent review passes and old saves migrate cleanly in tests.

## Owner questions (open)

- none

## Merge log

- 2026-10-20 merged W1-STRUCTART (37b6de7): import exit 0; [tests] PASS; t_ai/t_build/t_canim/t_combat/t_harbour (islands=15)/t_items/t_light/t_lighting/t_save/t_structart/t_tame/t_web PASS; SMOKE PASS; island_lab exit 0, 0 SCRIPT ERROR, nodes=378 creatures=24 (unchanged); build_lab [build] PASS; harbour_lab rot=2 on the coast; creature lab 0 "couldn't resolve track"; home/harbour shots Forward+, compat, 844x390 checked (pier on the water, home unchanged); pending hooks: tools/blender/structures/integrator_hooks.patch (W1-BUILD prop_visuals.gd, placed_building.gd, field_catapult.gd; W1-HARBOUR harbour.gd tap box)
- 2026-10-20 merged W1-ICONART (519f5c0): import exit 0; [tests] PASS; t_ai/t_build/t_canim/t_combat/t_harbour (islands=15)/t_iconart/t_items/t_light/t_lighting/t_save/t_structart/t_tame/t_web PASS; SMOKE PASS; island_lab exit 0, 0 SCRIPT ERROR, nodes=378 creatures=24 (unchanged); build_lab [build] PASS; harbour_lab rot=2; item_art_lab [itemart] ok=true; creature lab 0 "couldn't resolve track"; base moved (structart hooks 0d0f8c2) and was merged in, run_all/smoke/t_iconart/t_structart/t_harbour rerun PASS; home shots Forward+, compat, 844x390 unchanged; asset register icon row updated; pending hooks: t_iconart in tools/smoke.sh or CI (gates already run every t_*.gd), W2-SCREENS swaps inventory_ui/item_icons to ArtSlot/ItemArt
- 2026-10-20 merged DSC-MINORS (1174800): clean merge, no conflicts; import exit 0; [tests] PASS; t_ai/t_build/t_canim/t_combat/t_harbour (islands=15)/t_iconart/t_items/t_light/t_lighting/t_save (5 deliberate SCRIPT ERRORs, as on base)/t_structart/t_tame/t_web PASS; SMOKE PASS; island_lab exit 0, 0 SCRIPT ERROR, nodes=378 creatures=24 (unchanged); build_lab [build] PASS; harbour_lab rot=2; item_art_lab ok=true; package labs combat_rules/aival/hunt_lab/capture/petslab/aisweep PASS, foundation_lab fibre merged line; creature_anim_lab 0 "couldn't resolve track"; no new Godot .ips; home shots Forward+, compat (grass a little more saturated, camp pad lighter, as intended), 844x390 checked; lighting_lab windowed Forward+ PASS (worst pad 1.42), compat FAIL on mobile survivor shadow 0.803 > 0.80, identical on base b221e24 (pre-existing, not this package; compat worst pad 0.80 PASS); pending hooks: player.gd `_begin_gather` refusal hunk (finding 18) must be carried into PlayerActions by W2-PLAYER (running)
- 2026-10-20 merged DSC-CLIPS (4def2d1): clean merge, no integrator hooks in the report; import exit 0, 0 "couldn't resolve track"; [tests] PASS; t_ai/t_build/t_canim/t_combat/t_harbour (islands=15)/t_iconart/t_items/t_light/t_lighting/t_save (5 deliberate SCRIPT ERRORs, as on base)/t_structart/t_tame/t_web PASS; SMOKE PASS; island_lab exit 0, 0 SCRIPT ERROR, nodes=378 creatures=24 (unchanged); build_lab [build] PASS; sleep_lab ok; creature_anim_lab 0 "couldn't resolve track", 0 SCRIPT ERROR (quads still run x6.67/x16 at speed, known, quads-loco2); base moved (dd3b110 docs) and was merged in, run_all/smoke rerun PASS; home shots Forward+, compat, 844x390 identical to DSC-MINORS; creature_anim_lab windowed shot grounded; one Godot-2026-10-20-131531.ips appeared mid-run (AppKit abort 47 ms after launch, before project code; every run of mine produced its output, so not attributable to this package); pending hooks: none from DSC-CLIPS (quads-loco2 must drop protoceratops/megaloceros from t_canim KNOWN_GLIDERS when it lands)
- 2026-10-20 merged codex-harbour (fc202c39) and codex-animals (1e96dbc7), Codex gpt-reserve fixes verified by the orchestrator: every t_*.gd PASS, run_all [tests] PASS, SMOKE PASS, harbour_lab/island_lab 0 SCRIPT ERROR, windowed harbour and Animals shots looked at. codex-errors code change rejected (it hid a failed script load; its test grepped source text); its finding (stale cloned import cache) fixed in mkwt.sh. DSC-CLIPS merged by finish-3 (3317960b, judge 6/6).
- 2026-10-20 merged W1-UI (3e93c488) after re-review r4 by the new orchestrator (r3 majors closed: hexes and skills sheet rebuild on resize, plates keep off their creature; hunt_hud.gd 1345 lines < base 1376): ui_real_capture_lab "[uireal] PASS" at 844x390 glc, 667x375 glc, 1600x900 glc and fwd, 0 SCRIPT ERROR; combat, plate_front, levelup, busy_levelup, resize_back, bag shots looked at. Left open (minor): bag scrolls at 844x390 (W2-SCREENS), HUD colour emoji and ANIMALS symbol (W1-UIICONS, running).
- 2026-10-20 merged W1-SRVDOM (6730ad43): review r2 pass, all r1 minors closed, merge-tree clean; nits in findings/w1-srvdom-review-r2.json (char.settled depositor, force_dodge in a server process, t_srvdom/t_server_domain duplicate runners).
- 2026-10-20 merged W2-PLAYER (review r1 pass, 7 minors in findings/w2-player-review-r1.json) + hooks f612d946: PlayerRegistry.local() for the last 7 first-player lookups (incl. W1-UI's gather_radial.gd), PetRecord.hp_now, --combat-test/--gather-test load an island ("[combattest] ok chest open storage=true", "[gathertest] ok +2 branch", exit 0), web soak survival gate (Chrome soak not rerun); intent_handlers GATHER_REACH now reads PlayerInput (the split broke the t_srvdom/t_server_domain parse). Merged tree: import exit 0; [tests] PASS; all 17 t_*.gd PASS (t_save deliberate SCRIPT ERRORs); SMOKE PASS; home_lab 1600x900 fwd+glc and 844x390 glc exit 0, 0 SCRIPT ERROR, shots looked at; no new Godot .ips. Open: PlayerActions is not yet the only command layer (inventory_ui equip, hunt_hud placer.confirm), a hook is needed before W3-SRVACT.
- 2026-10-20 merged DSC-CAMP squash (9b8d618d): review r2 pass, blind A/B 4/4 (tent, fortified fence, large box, campfire stand) vs the Kenney placeholders; work/ previews dropped. Open (minor, findings/dsc-camp-review-r2.json): 11 of 18 kinds have no kit or _spawn case, stone_grill embers hidden, bucket/cabin_bed details, flat placement on slopes floats/sinks disc-less kinds ±0.3 m, verify_camp step 4 two-dot diff false-fails on base drift.
- 2026-10-20 merged W2-OCCLUDE: review r1 pass (pixel gates PASS in Forward+ and gl_compatibility: tree_kept 0.437, no 48x48 hole, survivor_shown 0.684, roof 0.125 inside / unchanged outside), 7 minors in findings/w2-occlude-review-r1.json (phone discard cost unmeasured, roof near-invisible at night, private _target read, roof scan not gridded). The first test run after the merge was all compile errors from a stale class cache: always --import after merging new class_name files.
- 2026-10-20 merged W1-UIICONS (review r3 major + 5 minors fixed; blind A/B 6/6) and its follow-up (grindstone station icon, code inventory reads player_input.gd). Merged tree: [tests] PASS; all 19 t_*.gd PASS incl. t_occlude, t_uiicons "PASS ids=169 files=114"; SMOKE PASS. Phone combat shot looked at: white icon set with captions, no colour emoji.
- 2026-10-20 evening: owner asked for a clean stop and handoff. Every worker committed and stopped; all package branches pushed. Built but not merged (state, findings and next steps in HANDOFF.md section 3): W2-PROCESS (review blocker: pack-up destroys station contents), W2-SKILLS (review major: rev-1 goldens rewritten), W2-BUILDSYS (review not run), W2-DATA, W2-INV (save format change, owner gate), W2-GATHER, ECON (review r3 blocker; fix WIP untested), W2-RAGDOLL (3 review majors), ICONS2 (armor_scute repro). Owner decisions this session: deploy now (done, 31c064a08/2284b9bf56), push after each merge, gameplay before polish, answer design questions from durango-prompts/PRDs (spec 08: no spoil timer, ~2 in-place processing opportunities, effects from item properties), DeepSeek allowed for narrow gated jobs, walk/run animations moved to the locomotion thread.
- 2026-10-20 DSC-QUADS2 not merged: review r1 failed (left/right legs in exact lockstep in all four clips, megaloceros run skates and tears). Tripo trial on the megaloceros (35 credits, branch claude/mmo-tripo-megaloceros, not pushed): quadruped walk only, scissoring hind legs, no run/idle presets; not adopted.
