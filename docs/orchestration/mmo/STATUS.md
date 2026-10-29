> **2026-10-29: this file is an archive.** The body below was last edited 2026-10-21 and is kept
> unchanged for its owner decisions and merge log. The live record is the Roadmap
> (`tools/docs_wiki/phase-map.json`, shown in the docs wiki) and the per-task reports in
> `docs/orchestration/reports/`. Check those first for what has landed and what is in flight.

# DEADFRONT AAA survival-MMO program: status

Owner request (2026-10-18): raise every system to an ARK: Survival Ascended bar and turn the game
into a persistent multiplayer MMO with a real, server-validated marketplace. This file is the loop's
memory: each iteration reads it, runs the next wave, and updates it.

**2026-10-20 ~19:05: graceful stop (owner); resumed on the owner's "continue" (finish-6, INVUI, W3-EXCHANGE running).** 2026-10-20 16:30: the orchestration loop is stopped and the work is handed over to `~/Documents/deadfront`.
Read `HANDOFF.md` (same folder) first.** 2026-10-20 night: the loop resumed from the owner's program prompt (finish-6 below).

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
| finish-6 | 2026-10-20 night, new session (owner program prompt, priority 1): wf_c321f8a4-028, script `handoff/workflows/finish-6.js`. Fix -> independent review (branch + hooks) -> blind A/B for visual -> base sync + delta review -> one serialized integrator that pushes. Merge order W2-DATA -> W2-SKILLS -> W2-INV -> W2-PROCESS -> W2-GATHER -> W2-BUILDSYS -> ECON; alongside W2-RAGDOLL, ICONS2 and new FORGEART (forge/anvil Blender models, after W2-DATA). Orchestrator grants: W2-SKILLS owns the single bonded-cap function and the taming_pen bond refusal (W2-BREED not running); ICONS2 may change t_iconart.gd. Review trees: scratchpad mkscratch.sh. Resumed once (same run id) after a docs check: ten fixes the docs settle were added to W2-DATA, W2-SKILLS, W2-INV, W2-PROCESS, W2-GATHER, W2-BUILDSYS and ECON (`vision-check.md`, which also ranks the next core-loop packages). Resumed a second time at 18:58: the first resume ran in the turn of an owner question, which the Workflow tool relays to every agent as overriding, so agents answered it, skipped gates or stopped (W2-INV with a false owner gate). Every result since then is redone; W2-INV's vision scope is ruled (crafting default picks only, spec 05:23); unmet acceptance items now reach the implementer | stopped 19:05 (owner: graceful stop), resumed on the owner's "continue" running |
| invui | 2026-10-20 night: owner spec 13 (Durango Bag, Character -> Gear, Equipment / My Info), wf_cdb79ed1-deb, script `handoff/workflows/invui.js`, branch claude/mmo-invui stacked on claude/mmo-w2-inv: scouts -> design (invui-spec.md, bag_ui_lab, t_invui) -> builds B1 bag+inspect, B2 character/gear, B3 storage/cargo/picker, B4 polish -> reviewer + fidelity judge vs the Durango references + blind A/B. Ends ready-to-merge; integrated after W2-INV lands | stopped 19:05 after the scouts, resumed on "continue"; running |
| exchange | 2026-10-20 night: owner spec 14 (Island Market: HUD > Main Menu > Island Market > Buy / My Market / Sell), wf_4cbd48e0-5b9, script `handoff/workflows/exchange.js`, branch claude/mmo-exchange stacked on claude/mmo-econ: scouts -> design (transport decision; one owner question if single-player selling needs server-owned characters) -> B1 shell+Buy, B2 Sell, B3 My Market, B4 polish -> reviewer + fidelity judge vs the market references. Ends ready-to-merge; integrated after ECON (and INVUI) | stopped 19:05 during the scouts, resumed on "continue"; running |
| owner refs | 2026-10-20 night, one run per owner reference: island/map check wf_a8231c29-144 (read-only, specs 15; plan only); HUD-DAYNIGHT wf_985adb37-366 (spec 16, `claude/mmo-hud-daynight`); WATER wf_3b444b00-9ee (spec 17, `claude/mmo-water`); DOMAIN wf_bd458c96-ec8 (spec 18, `claude/mmo-domain`); INVUI resumed with the spec 13 storage addendum. Scripts in `handoff/workflows/`. Each ends ready-to-merge; merged one at a time after finish-6's chain | running |
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
- 2026-10-21 09:27 production (owner: "get the game to a shippable state soon. You're taking forever to push updates to vercel"): `af03937f1/22a5004823` (W2-INV, W2-SKILLS, W2-DATA, WATER, HUD-DAYNIGHT, camp, see-through trees, HUD icons on top of 31c064a08), dpl_3ehdvXvRNnfyCnBJeSVEaJnKAL8H; alias stamp verified by curl and by an independent fresh-profile browser run (create -> island -> world -> gather, 0 console errors). Pack 255 MB (PAYLOAD_MAX_MB=260). Defects found, now in SHIPFIX (wf_b83bd7a7-61a): skill nodes all "not in the game yet"; phone tap targets ~26 CSS px; CLAIM re-press moves the claim; placer ghost under the HUD; autosave during character creation skips creation on reload; max HP drifts; fast energy drain; pack over 220 MB; survivor hidden by the harbour roof and bushes. CONTROLS owns the two-tap gather and trunk-only tree taps; INVUI the duplicate knife display; MAPUI (backlog) the atlas zoom.
- 2026-10-21 production (owner: "deploy"): `a01e41ed3/5bf3729622` (DOMAIN banner + borders, day/night sun moving every frame, on top of af03937f). Export PAYLOAD_MAX_MB=260 PASS; headless Chrome boot to character creation, 0 console errors; alias stamp verified by curl. Deploys now need the owner's go each time (the production-deploy permission check blocks unattended deploys).

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

- 2026-10-20 (owner) spec 13 inventory and equipment UI (`docs/design/durango-prompts/13_inventory_equipment_ui.md`, references
  `docs/reference/durango-{bag-instances,character-gear,equipment-myinfo}.webp`): recreate Durango's Bag, Character -> Gear and
  Equipment / My Info screens on the instance inventory - dense ~7-column grid with every instance in its own slot, small grey
  Lv labels, blue NEW tags, yellow corner brackets, Auto Sort + select/filter/lock toolbar, capacity from real data, a contextual
  inspect panel (grey negative, gold positive, green rare attributes; only valid actions), Character panel (portrait, level/XP,
  Combat/Crafting/Gathering Power, Detailed Stats), Gear | Decorative Gear tabs, numbered presets, silhouette slots, My Info
  Attack/Defense/Accuracy; the same grid for storage, dinosaur cargo, the craft/cook ingredient picker and Sell on Market.
  It supersedes W2-INV's grouped bag view (grouping only if it expands back to instances). Package INVUI (`claude/mmo-invui`,
  stacked on `claude/mmo-w2-inv`), merged right after W2-INV.

- 2026-10-20 (owner) Island Market UI: "Gameplay HUD → Main Menu → Island Market → Buy / My Market / Sell" with two Durango
  screenshots (`docs/design/durango-prompts/14_island_market_ui.md`, `docs/reference/durango-market-buy-{search,taming}.webp`).
  Package W3-EXCHANGE (`claude/mmo-exchange`, stacked on `claude/mmo-econ`): the market screens on the REAL ECON engine through
  `VaultBridge.client()` (local authority until a host is picked; no fake listings: spec 06's honest offline harness),
  one row per instance, caged pets as cages; merged after ECON (and INVUI for the Sell picker).

- 2026-10-20 (owner) "this will be an online multiplayer game at some point": the Island Market is an online feature on the
  server (contracts v2: server-owned characters, clients send intents). W3-EXCHANGE builds the screens for the server path
  (socket transport; a local server for dev and tests until a host is picked) and shows an honest "market offline" state in
  offline single-player. It does NOT move single-player characters into a server store to make offline selling work.

- 2026-10-20 (owner) island scale, shape and map UI reference: "To give you an idea of the scale and shape of an island, as well
  as the UI" (`docs/design/durango-prompts/15_island_map_scale.md`, `docs/reference/durango-island-map.webp`): a Durango Lv. 10
  island about 165 x 215 m with an irregular coastline, and the map screen (fog of war, island info panel with climate, life span,
  fatigue and its rate, difficulty laurel, scale bar, domain label, legend, To Harbor / To Waypoint). Being compared with our
  islands (home 160 m; unstable 240 m by the design doc, about 480 m as generated) and map_screen.gd before a package is planned.

- 2026-10-20 (owner) "We don't have the day/night cycle component in the UI next to the map" (`docs/design/durango-prompts/16_hud_day_night_dial.md`,
  `docs/reference/durango-hud-daynight.webp`): a day/night dial beside the minimap reading Game.time_of_day / phase_name.
  Package HUD-DAYNIGHT (`claude/mmo-hud-daynight`).

- 2026-10-20 (owner) "when next to water, menu items pop up like washing and drinking" (`docs/design/durango-prompts/17_water_context_actions.md`,
  `docs/reference/durango-water-actions.webp`): Drink / Wash (and Fill container if a container item exists) appear whenever the survivor
  is next to or in fresh water, with the PRD's effects (drink cuts heat fatigue / Quenched; wash clears Dirty; statuses, not meters).
  Package WATER (`claude/mmo-water`).

- 2026-10-20 (owner) three references (`docs/reference/durango-{domain-claims,storage-transfer,house-4x4}.webp`):
  (1) "When entering player's claimed regions, it says 'Player's Domain' with their profile picture" (spec 18): package DOMAIN, a domain banner
  with the owner's portrait plus the dotted claim edge; (2) "Another example of the inventory menu" (spec 13 addendum): the storage view with
  Bag | Small Box tabs, "N Select", category column, attribute chips and Transfer to Bag, fed into INVUI B3/B4 and its fidelity judge;
  (3) "Our house building system may be more robust than the original game, i will look into this. See this house is only 4x4": the owner
  is evaluating; W2-BUILDSYS is unchanged until the owner decides.

- 2026-10-20 (owner) "This is what the player creation page looks like" (`docs/design/durango-prompts/19_character_creation.md`,
  `docs/reference/durango-character-creation.png`): Durango's Gender/Profession screen. Package CHARCREATE (`claude/mmo-charcreate`) restyles
  the existing character_creation.gd (occupations, gender, name already work). A male survivor model needs owner-approved concept art first. Owner added step 2 ("You can choose the size and profile pic, 3D model"):
  CHARCREATE (wf_423a264e-02f, script `handoff/workflows/charcreate.js`) also builds Create Character - size slider, a portrait RENDERED from the
  player's model with Pattern/Background Color (the canonical PortraitService; DOMAIN/INVUI adapt at their sync), appearance/colour options the
  model really supports.
  Owner then listed "height, hairstyles, skin color, facial hair/features", "outfit color" and "enter name" (spec 19 last section): CHARCREATE also
  builds the Color tab (skin, outfit 1-3, eye, lip through texture masks), the Name step (1-20 chars, letters/digits/space/-/.) and data-driven
  hairstyle/facial-hair/feature slots; CHAR-APPEARANCE plan (wf_05041ba1-aa5, read-only, no spend) plans that art and a male base.

- 2026-10-20 (owner) "region chat" (`docs/design/durango-prompts/20_region_chat.md`, `docs/reference/durango-region-chat.webp`): Durango chat screen
  (Region / System channels, New Group, gold names, emotes, relative times, Enter message / + / Send). Run NET+CHAT: finish the network core
  (`claude/mmo-net`: sync the base, fix, review; it is the market's online path too) and build the chat screen on it (`claude/mmo-chat`).

- 2026-10-20 island/map check done (`islandmap-check.md`).
  Findings:
  - Our home island is 134 x 131 m. Unstable islands are 406 x 404 m. All islands are near-round discs, from only 4 heightmaps.
  - The atlas is a flat pixel map with no fog, info panel or scale bar.
  - The travel menu is a vertical text list, not the Sail chart.
  Packages queued, in this order:
  - SAILUI: the rightward Sail chart. It is the cheapest visible win.
  - MAPUI: the painted map with fog of war and the island info panel.
  - ISLANDSHAPE: seeded, elongated, ragged islands. This waits for the owner's answer on island size.
  Assumptions until the owner says otherwise: keep our 14 fixed islands on the chart, and "To Harbor" / "To Waypoint" auto-walk (no new mechanic).
- 2026-10-20 (owner) "example of tall trees and transparency" (`docs/design/durango-prompts/21_tall_trees_transparency.md`): it matches the merged
  W2-OCCLUDE rule. A visual check of our build against it is running.

- 2026-10-20 (owner) "notice the game ui and how the resource gathering looks. The finger icon is a walkthrough guide" (spec 22):
  - Gather hexes show the gather time and the yield per part.
  - A tutorial pointing hand guides the current order step.
  A comparison with our gather radial and Orders tracker is running. GATHERUI follows W2-GATHER's merge; GUIDE (the finger) can start sooner.

- 2026-10-20 (owner) "the cage icon should look like there's a dino inside": CAGEICON (wf_fd47200c-882, `claude/mmo-cageicon` stacked on ICONS2)
  re-renders captured_animal with a real dinosaur mesh inside the cage. Blind naming judges at 48 px and full size must see a dinosaur and a cage,
  an A/B judge must prefer it over the old render, and captured vs tamed must be distinct at 48 px. It merges right after ICONS2.
- 2026-10-20 CHAR-APPEARANCE plan (`char-appearance-plan.md`).
  - The shipped v2 survivor is male; the missing base is a female v2.
  - APPEAR-A (wf_c94a70f4-71e, 0 credits): hair split into its own piece (current, buzz, bald, short crop), helmet shells, facial-hair decals plus 2 shell beards, feature decals.
  - CHARCREATE does the colour masks with the plan's geometry method.
  - Settled from the docs, so not owner questions: muted palettes per STYLE.md; tied-back hair only until the rig has hair bones; facial features start as free decals; the creation screen keeps the tee-and-shorts base layer.
  - Needs the owner: concept sheets CA-01..04, 4 Tripo hairstyles (cap 300), a female v2 base (cap 250), occupation outfits later.
- 2026-10-20 checks (`tree-and-gather-checks.md`).
  - Tree fade: right strength, not a hole.
  - Gaps: forest density (about 4 trees per hectare on unstable islands against 24 at home, almost no understory), hard dark shadows, trunks fade with the crown.
  - Gather hexes: the shown time is static and will be wrong after W2-GATHER; the count means passes left; hexes sit far apart and jump while walking.
  - No tutorial pointer exists. GUIDE (wf_987c83ae-267) builds the walkthrough finger.
  - Backlog, in order: GATHERUI (after W2-GATHER merges), FOREST (density scaled to area, understory under tree clumps), OCCLUDE2 (solid trunks, per-object dither), LIGHT2 (soft sun edges, ambient 0.3 -> ~0.45, Forward+/compat colour match), MAPUI, ISLANDSHAPE (after the owner's island-size answer).
- 2026-10-20 22:45 the disk filled up: review agents made about 80 uniquely named 1.6 GB scratch trees. Cleaned to 122 GB free. mkscratch.sh now keeps at most 12 trees and refuses below 15 GB.

- 2026-10-20 (owner) more references and requests, each filed as a spec with its own run:
  - Target select and pet radial (spec 23): TARGET-PET wf_12d62955-8bb.
    - Ruling, from the owner's newer description: tapping a wild animal selects it, the red swords hex starts combat,
      an animal already fighting you stays engaged, and the action mode stays.
  - Crit numbers that balloon out (spec 24): COMBATFX wf_1c0f1639-5fc.
  - "UI glitching on resource nodes, WASD + a joystick on the left that only appears when you hold and drag, better
    pathfinding, movement and interactions": CONTROLS wf_1178f1fd-3e0.
  - "Stegosaurus model is wrong": the merged v2 was hidden behind a stale override. STEGO wf_56306bba-f17.
  - "Should be a triceratops too" (from the DeepSeek bake-off) and "a newer deinonychus": CREATURE-ART wf_3a741584-856.
    - Triceratops: the better bake-off build goes into the game.
    - Deinonychus: a Tripo rebuild from the approved sheet v01, capped at 100 credits.
  - "The cage icon should look like there's a dino inside": CAGEICON round 3 wf_9cde60cc-597, with an inside-the-cage judge.
  - In-game bag panel reference (spec 13 addendum 2): fed into INVUI B4.
  - "Resting should sit you down and heal you and lower exhaustion. It didn't work on Vercel": REST wf_3af39880-3bb.
    It reproduces on production first; there is no standalone rest action today.
- Side integrator (`handoff/workflows/side-int.js`): merges finished side packages one at a time with every gate, and waits while
  finish-6's integrator runs. WATER merged (4cd47f42). Queued: HUD-DAYNIGHT, then DOMAIN, each with a pre-merge polish fix.
- Backlog: a one-bug Codex job for the Godot exit-time SIGABRT (std::system_error from a mutex lock 0.7-10 s after launch; about 10
  .ips reports; it shows the owner "Godot quit unexpectedly").
- 2026-10-21 (owner) "as a rule of thumb: make it flashy. Level ups should have light effect animations." Standing art direction:
  feedback moments (level-ups, crits, rare finds, rewards, unlocks) get light, motion and punch, readable in the web renderer and on
  phones. Package LEVELFX (light-effect level-up animations).
- 2026-10-21 (owner) "Also watch out for glitchy movement of UI and player." Standing quality gate: every UI or movement review and every
  merge checks motion over frame sequences (HUD elements, labels, radials and the player must not jump, snap, stutter or swap sides
  between frames); a measured glitch is a failure. The side integrator and new package reviews carry the gate.
- 2026-10-21 (owner) corrections to the 2026-10-20 requests:
  - Damage numbers, not crit balloons: "Just add damage numbers, make them small and informative but make them bigger if you hit a crit
    or did a lot of damage", "you want them to kind of expand out and dissipate", "you can make it float up too". COMBATFX is
    rescoped (wf_1c0f1639-5fc): small numbers that expand outward while fading and float up; crits and big hits are larger;
    white for damage dealt, red for damage taken; no outline.
  - "That white triceratops is not acceptable, neither is the blocky stegosaurus." The Triceratops bake-off build is rejected:
    CREATURE-ART makes a concept sheet first, and the owner approves it before any Tripo spend. The blocky Stegosaurus is the
    placeholder that STEGO removes, so the shipped Tripo v2 shows.
- 2026-10-21 (orchestrator) NET (network core) passed review r1 and is queued for the side integrator with four NET-side pre-merge fixes (auth.hello strike, rate-limited chat no longer a flood strike, MAX_PER_IP >= max_players_area, no journal writes on char.get). Merging into claude/mmo-overhaul only; the server stays local and nothing is deployed. Open prerequisite for W3-SRVWORLD/W3-SRVACT: the first presence.update on an unvisited island is accepted at any position (one free teleport per island).
- 2026-10-21 (orchestrator) real_length_m drives collision radius, reach, kick mass and plate boxes, not the drawn size. Triceratops 18 -> 9 m (PRD) is on claude/mmo-trike only: it halves the body radius and makes it kickable (t_combat _test_kick_mass fails), so it needs a balance pass with the Tripo mesh before merging. Stegosaurus is 18 m in data vs an 11.9 m model; DEINO sets 8.1 m to match its mesh.
- 2026-10-21 (orchestrator) The Triceratops concept sheet is generated in ChatGPT web on the owner's Plus plan (text-only prompts, driven in a debug Chrome); told the owner, awaiting any objection.
- 2026-10-21 (orchestrator) Triceratops concept sheet v01 (claude/mmo-trike ad147d93) passed the paleo-art critic in round 4 and went to the owner for approval; no Tripo spend until the owner says yes. Round 3's front view came from a Codex CLI image edit on gpt-6-astra (the owner prefers a smaller model for Codex) - reported to the owner. Owner question added: approve the sheet?
- 2026-10-21 (orchestrator) STEGO passed review r1 (Stegosaurus v2 shows in game, stride-matched, feet conform to slopes) and is queued for the side integrator. Asset follow-up STEGO-ART (0 credits, headless Blender): the Tripo thagomizer fans about 7 spikes (the owner's journal art insisted on exactly four) and the hide reads grey-blue against the PRD's green-brown; trim to four spikes and shift the hide, keeping the rig and clips.
- 2026-10-21 (orchestrator) CHARCREATE passed review r1 (blind A/B 4-0) and is queued for the side integrator. Save change: an optional "look" field (gender, height, colours); old saves load with the default look. Ruled additive and backward compatible like INVUI's optional "new" flag, so not an owner gate; the owner can object. APPEAR-A merges after it (it adds rows to CHARCREATE's appearance.json).
- 2026-10-21 (orchestrator) TARGET-PET done: TARGETUI passed review r3 (blind A/B 12-0) and PETRADIAL review r1 (blind A/B 7-0); both queued for the side integrator (TARGETUI first). Ruling: a tap on a wild animal only selects it; the red swords (or E/F) start combat; the self-defence auto-hunt stays for animals that attack first; a second tap on a selected animal does nothing extra (the owner's description gives the swords as the way to fight). This replaces the 2026-10-18 "keep tap-target auto-attack".
- 2026-10-21 (orchestrator) REST passed review r2 (blind A/B 5-0): reproduced the owner's Vercel bug (no Rest action existed; Sleep only by a tent, laid down, healed nothing, any tap cancelled it). Queued for the side integrator with a pre-merge fix: one upright seated pose everywhere (the open-ground pose read as a knockdown), nameplate off the torso, a readable rest pill, visible recovery feedback. Rates in data/rest.json are assumptions (open < fire < shelter per spec 01 and PRD :118/:803).
- 2026-10-21 (owner) "triceratops looks good": Triceratops concept sheet v01 APPROVED (claude/mmo-trike f9b4e780, INDEX.md anchor). TRIKE mesh started (wf_6985c533-058): Tripo multiview from the sheet, cap 100 credits, headless-Blender quadruped rig and clips; the sheet's scale (9 m, back ~3.8 m) sets height_meters, and the kick-mass outcome is kept with the smallest data change (# ASSUMPTION, listed for the owner).
- 2026-10-21 (owner) "pause lowest priority": paused APPEAR-A, LEVELFX, COMBATFX, STEGO-ART, CHAT and W2-RAGDOLL (its sweep held all 5 Godot slots) so merges and deploys get the slots; deploy after every landed merge batch from now on; side integrator v2 (parallel pre-merge fixes, batches of 3).
- 2026-10-21 ~09:50 (owner) "pause everything": every workflow and the loop stopped, leftover Godot/Blender runs cleared; base claude/mmo-overhaul c9ec27c6 clean and pushed. Nothing merges or deploys until the owner says. Resume points (Workflow({scriptPath, resumeFromRunId}); scripts in .claude/worktrees/deadfront-*.js, copies in handoff/workflows/; resume from a /loop tick, never in an off-topic turn):
  - finish-6 wf_c321f8a4-028 (W2-PROCESS sync, W2-GATHER r3, W2-BUILDSYS, ECON passed r6, ICONS2, FORGEART; W2-RAGDOLL in its PAUSED list).
  - side integrator v2 wf_d670b08f-f36 (args handoff/workflows/side-int2-args.json: REST, SAILUI, DEINO | NET, STEGO, CHARCREATE | TARGETUI, PETRADIAL; parallel pre-merge fixes were in flight).
  - SHIPFIX wf_b83bd7a7-61a (skillbuy, phonehud, claimfix, savefix, webpack, occlude2 - builds in flight).
  - GUIDE wf_987c83ae-267 (extra round 4), INVUI wf_cdb79ed1-deb (fix r2), W3-EXCHANGE wf_4cbd48e0-5b9 (review r2), CONTROLS wf_1178f1fd-3e0 (build B3).
  - TRIKE mesh wf_6985c533-058: built and committed on claude/mmo-trike 1aeb461f (Tripo task 555e7332, 50 credits; 31-bone rig, nine clips, height_meters 4.645 to the sheet); review not started. Note for the owner: it lowered the global kick threshold giant_mass 60 -> 40 (ASSUMPTION) so the 9 m triceratops stays too heavy to kick - this affects every species near the line; the review must check it.
  - Paused earlier (lowest priority): APPEAR-A wf_c94a70f4-71e, LEVELFX wf_21781920-37e, COMBATFX wf_1c0f1639-5fc, STEGO-ART wf_340be69a-017, NET+CHAT wf_129d4a7d-7fc (CHAT fix r2), W2-RAGDOLL.
  - Ready, waiting for the side queue: CAGEICON (after ICONS2).

- 2026-10-21 afternoon (owner):
  - "game balancing like tuning hp and damage wont make sense until crafting building and skills is done and tuned";
    "we need to be able to eat, sleep, clean, drink, etc". Order: survival actions, then crafting/building/skills, then
    balance. LOOP1's bot balance thresholds wait.
  - "no i want you to use deepseek workers": DeepSeek jobs do the work, scouting included; Claude writes short tasks,
    reviews, integrates. Idle default: "asset generation and building biomes using our 2D concept art as references".
  - "the inventory system doesn't match what I asked for in the docs ... a scroll view with slots, 1 item per slot and we
    can upgrade slots" (INVSLOTS, DeepSeek).
  - Camera: "yeah merge it" -> merged a7928ce3 (Durango long-lens perspective, pitch 38.7). The phone zoom-out drops from
    28 m to 18 m (Durango's range); kept as built, the owner may ask for more.
  - "start switching to the 2D assets. Utilize deepseek workers": SWITCH2D (resources as painted cards, buildings 3D,
    resource_render "card" by default) and GROUND2D (painted ground cover) started on claude/mmo-switch2d (camera + CARD2D +
    SPRITES2D merged there); props visuals move to painted cards after the PROPS job.

## Owner questions (open)

- Female v2 survivor base (PRD: 8 occupations x 2 genders; the shipped v2 is a MAN; an earlier version of this question wrongly asked for a male base): a concept sheet for approval, then a Tripo mesh plus refitting the 3 armour kits, about 250 credits? Before or after extra hairstyles (4 Tripo styles, cap 300)? (2026-10-20; unanswered)
- Painted portrait set like Durango's (15+ faces): new art; which source, if any? Until then portraits are rendered from the player's model.
- Island size target (asked 2026-10-20; unanswered): match Durango (~300 x 375 m, recommended), the design doc (160 home / 240 unstable), or keep ours (134 home / 406 unstable) with ragged shapes only? ISLANDSHAPE waits for it.

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
- 2026-10-20 merged W2-DATA (9c4226c8): Stone-to-Steel ladder (tin, forge, anvil, 28 named tools), nets I-V, armour bands 1-60, raid kit from steel, recipe node gates (hook 6), t_data validator; hooks applied clean (be970c8c). Merged tree: all 20 t_*.gd PASS incl. "[t_data] PASS items=223 recipes=155" (t_save 5 deliberate SCRIPT ERRORs); [tests] PASS; SMOKE PASS; island_lab "nodes=397 creatures=24" (base 378; intended: corn on home grassland, wheat/tin nodes), build_lab [build] PASS, craft_lab and equip_mount_lab PASS, 0 SCRIPT ERROR, 0 "couldn't resolve track"; home_lab 1600x900 Forward+/gl_compat and 844x390 match base; no new Godot .ips; review r4 pass; pending: repairs rows have no consumer yet, W2-SKILLS rebases H1 onto hook 6
- 2026-10-20 merged W2-SKILLS (dfcf833e, hooks 6f65f615, base docs merge 846dd6d9): Durango 1-60 trees from Lv. 1, Lv1 AUTO nodes, Animal Handling I-IV bonded cap 3-7 via Data.bonded_cap, recipe node gates via SkillRules.recipe_block (H1 replaces W2-DATA's requires_node check), save rev 2 with rev-1 migration (owner-approved); 15-file hooks applied clean. Merged tree: all 21 t_*.gd PASS incl. "[t_w2_skills] PASS", "[t_data] PASS items=223 recipes=155" (t_save 5 deliberate SCRIPT ERRORs); [tests] PASS; SMOKE PASS (both rerun after the spec 20-22 docs base merge); island_lab "nodes=397 creatures=24" (unchanged); build/craft/equip_mount labs PASS; skills_lab "[skill] PASS level-up pays 10 SP, small_field bought", capture_lab "[capture] PASS bonded+=2", ui_family_lab active_cap=3; 0 SCRIPT ERROR, 0 "couldn't resolve track"; ui_real_capture_lab [uireal] PASS 1600x900 and 844x390 gl_compat; home_lab 1600x900 Forward+/gl_compat and 844x390 match base; no new Godot .ips (34); review r8 pass + sync delta; blind A/B pass; pending: ui_real_capture_lab radial-vs-vitals check flaky at 844x390 (spawn varies; failed once, passed on rerun), --shot names containing "skills"/"tree" auto-open the skills sheet (hunt_hud.gd:92 debug hook), open owner decisions 4-7 in the W2-SKILLS report (cured-hide pacing, occupation Lv. 20 vs cap, island/capture pacing, rev-1 sp_extra), W3-SRVACT server-side gates
- 2026-10-20 merged WATER (229719b0, merge c5f1db63, hooks 3abc6503): Drink/Wash (and Fill with an empty bucket) hexes within 2 m of fresh river water, none at the sea; Dirty/Very dirty/Thirsty/Quenched/Clean statuses; in_water from the heightmap (straight river box removed). Merge fix: t_data STATUS_ACTIONS accepts wash/drink (W2-DATA's check failed "status dirty cleared_by wash is an item or a listed action" x3). import exit 0; all 23 t_*.gd exit 0 incl. "[t_water] PASS", "[t_data] PASS items=223 recipes=155", "[t_w2_skills] PASS", t_uiicons "PASS ids=177 files=116" (t_save 5 deliberate SCRIPT ERRORs); run_all "[tests] PASS"; "SMOKE PASS"; island_lab exit 0, 0 SCRIPT ERROR, "nodes=397 creatures=24" (unchanged); build_lab "[build] PASS"; water_lab headless matches the report's after table (river_bank_1m ctx drink/wash, sea_bank_1m claim only, bank_after quenched+clean, water_bucket=1); creature_anim_lab 0 "couldn't resolve track"; home_lab 1600x900 Forward+/gl_compat and 844x390 match base (first Forward+ run showed the bag sheet open and the first phone run a passing herd; reruns match), water_lab windowed 4 configs looked at; one new Godot .ips (23:26:13) is another agent's charcreate_lab shot (cc2 b2_world_glc.log, same recursive_mutex abort), not this merge; review pass; blind A/B pass; side integrator. Pending: W3-SRVACT handlers for act.drink/act.wash/act.fill
- 2026-10-21 merged HUD-DAYNIGHT (4e69ed22, merge 951da683): 60 px day/night dial docked left of the minimap (sun/moon on an arc; tap opens "Day  08:28 / Dusk in 4 min"), the map's clock line dropped, radial reserve 190/178 -> 240 px, LabKit --tod=. Hooks applied cleanly, no merge fixes. import exit 0; all 23 t_*.gd exit 0 incl. "[t_daynight] PASS", "[t_data] PASS items=223 recipes=155", "[t_ui] PASS", t_uiicons "PASS ids=177 files=116" (t_save 5 deliberate SCRIPT ERRORs); run_all "[tests] PASS"; "SMOKE PASS"; island_lab exit 0, 0 SCRIPT ERROR, "nodes=397 creatures=24" (unchanged); build_lab "[build] PASS"; creature_anim_lab 0 "couldn't resolve track"; ui_real_capture_lab 1600x900/844x390 x Forward+/gl_compat x --tod 0.4/0.9 "[uireal] PASS screens=hud,hud_daynight,...", 0 SCRIPT ERROR; home_lab 1600 Forward+/gl_compat and 844x390 match base except the dial and the dropped clock line; no new Godot .ips. Motion gate (home_lab, 180 frames walking 9.7 m past bush berries, label open): dial/label rect constant (1250,128 176x60 at 1600; 501,128 169x60 at 844), vitals/quest/map blocks 0 px per frame, nameplate <=1.03 px (1600), player step <=0.117 m/physics tick, yaw <=0.42 rad on the first turn frame then eased; same numbers on base ddaab662. Pre-existing, not this merge (base shows it too, 104-106 px): the harvest-node world pill snaps when it meets the survivor's figure rect (one 105 px jump, then a 2 px/frame drift with 24 px snaps every ~12 frames, UiTokens.layout_labels) - backlog for a pill-layout fix. Review pass; blind A/B 3-0; side integrator.
- 2026-10-21 merged W2-DATA (c206a97f, hooks 9762c735): re-integration of the sync-1/round-5 report and the regenerated hooks-patch record; no game code or data changed (the package itself merged 2026-10-20 in 9c4226c8/be970c8c). Hooks: git apply --3way rc=0 with no tree change, -R --check (excluding crafting.gd, superseded by W2-SKILLS H1) rc=0. import exit 0, 0 error lines; all 23 t_*.gd exit 0 incl. "[t_data] PASS items=223 recipes=155", "[t_w2_skills] PASS", "[t_daynight] PASS", "[t_water] PASS", t_uiicons "PASS ids=177 files=116" (t_save 5 deliberate SCRIPT ERRORs, all others 0); run_all "[tests] PASS"; "SMOKE PASS"; island_lab exit 0, "nodes=397 creatures=24" (unchanged); build_lab "[build] PASS"; craft_lab "[craft_lab] PASS", equip_mount_lab "[equiplab] PASS"; creature_anim_lab 0 "couldn't resolve track" over 735 s (endless lab, stopped); home_lab 1600x900 Forward+/gl_compat and 844x390 gl_compat match base; no new Godot .ips (25); review round 5 pass; pending: W3-SRVACT server-side node gate on act.craft (intent_handlers.gd _craft)
- 2026-10-21 merged W2-INV (e42d8219, hooks 0c57276b): gathered materials and food are single instances with uids (grouped bag view with count pills and level ranges, exact-instance equip, default craft picks skip locked and spare valuable units, stacked saves and server characters migrate without loss; owner-approved save change). Hooks: git apply --3way rc=0, 24 files, no fixes. import exit 0, 0 error lines; all 24 t_*.gd exit 0 incl. "[t_inventory] PASS", "[t_items] PASS", "[t_save] PASS" (5 deliberate SCRIPT ERRORs), "[t_player] PASS", "[t_srvdom] PASS", "[t_data] PASS items=223 recipes=155", t_uiicons "PASS ids=177 files=116", all others 0 SCRIPT ERROR; run_all "[tests] PASS"; "SMOKE PASS"; island_lab exit 0, "nodes=397 creatures=24" (unchanged); build_lab "[build] PASS"; "[invlab] PASS empty_cells=100/97 slots=100 groups=20 stone_open=17 equip_l30=true full_unequip_notice=true", "[craft_lab] PASS", "[equiplab] PASS", "[kitchen_lab] PASS"; creature_anim_lab 0 "couldn't resolve track" (300 s); home_lab 1600x900 Forward+/gl_compat and 844x390 gl_compat match base; inventory_lab 1600x900/844x390 gl_compat looked at (group pills 16..2, Lv ranges, x45/x6 stacks, knife and pick worn); no new Godot .ips (25); review round 5 pass; blind A/B pass; pending: W2-BUILDSYS raises container capacities (spec 05:14) and INVUI virtualizes the storage/cargo grid (one button per instance) before players with large old saves update; server operators snapshot on the old build before upgrading; INVUI drops its plan_spends_traits hunk at next sync
- 2026-10-21 merged DOMAIN (800d19cc, merge 0b7cb607, hooks 857dd668, base W2-INV merged in aa4556b5): walking into a claim shows "<name>'s Domain" with the owner's portrait (slim toast above the quest card on a landscape phone), your claim edge is yellow dashes, other players' salmon dots (4 nearest), claim_at refuses another owner's tiles and the stake is spent only after a claim succeeds. Hooks applied cleanly (4 files). Merge fix after W2-INV: t_domain equipped an id that was not in the bag (W2-INV equip wears a bag instance), "FAIL equipping gear drops your cached portrait"; the test now wears a real raid_helm (800d19cc), rerun "[t_domain] PASS", 0 SCRIPT ERROR. import exit 0 (before and after the W2-INV merge); all 25 t_*.gd exit 0 incl. "[t_domain] PASS" ("crowd: 401 rows, rebuild 2.42 ms"), "[t_inventory] PASS", "[t_data] PASS items=223 recipes=155", t_uiicons "PASS ids=177 files=116" (t_save 5 deliberate SCRIPT ERRORs, all others 0); run_all "[tests] PASS"; "SMOKE PASS" (both rerun after the W2-INV merge); island_lab exit 0, "nodes=397 creatures=24" (unchanged); build_lab "[build] PASS"; domain_lab 1600x900 Forward+ and 844x390 gl_compat, day 0.38 and night 0.95: "[domain] PASS ... steps=outside,entered,staying,reentered,neighbour,crowd", "36 other claims, 4 drawn", 0 SCRIPT ERROR; ui_real_capture_lab 1600x900/844x390 gl_compat "[uireal] PASS"; creature_anim_lab 0 "couldn't resolve track" (endless lab, stopped at 295 s); home_lab 1600 Forward+/gl_compat and 844x390 match base except the dashed claim edge; no new Godot .ips (25). Motion gate (home_lab, 420 frames, 3.8-4.6 s, walking 8.5 m into the camp claim past bush berries, banner up from frame 92/102): banner rect constant (661.5,14 277x54 at 1600; 396.5,6 189x26 at 844), never overlaps another HUD block; vitals/quest/map/level/dial 0 px per frame; player step <=0.117 m per physics tick, no yaw or Y pop; nameplate 40.8/15.1 px and the harvest pill's jump to the top band at the claim edge are on base acc684a6 too (40.5/14.7 px, same pill backlog). Review pass; blind A/B 3-1; side integrator.
