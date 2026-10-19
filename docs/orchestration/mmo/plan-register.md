# DEADFRONT AAA survival-MMO program: gap register and build plan

Date 2026-10-18. Integration branch `claude/mmo-overhaul`, HEAD `cb03754` (docs-only commits since the
audited code at 77748a4/ef8b1be). Sources: 16 system audits plus adversarial verify passes, kept under
`scratchpad/audit/<system>/` and `scratchpad/audit/<system>-verify/`. P2/P3 rows were not re-verified.

## What is binding (newer than anything else)

From `docs/orchestration/mmo/STATUS.md` and `contracts.md` v2 section 0:

- Server stays local; build and test with local clients. Public hosting is a later owner decision.
- Contracts v2: online characters are server-owned, islands are server-simulated, clients send
  intents (`act.<verb>`), and only assets with server provenance (`uid` + `origin`) enter the market.
- CC0/royalty-free audio approved (record source and licence per file).
- Credit spend approved from existing balances only (Tripo 3,240; Meshy key revoked). Tripo only for
  complex creatures and player characters; DeepSeek `dsc` rigs and animates as a subagent; Blender MCP
  builds buildings and world objects. One Blender instance: one agent drives Blender MCP at a time,
  the rest use headless Blender scripts in `tools/`. Asset libraries (Poly Haven) are off.
- Leave the owner's uncommitted 2026-10-17 UI pass alone (hunt_hud.gd, inventory_ui.gd,
  animal_screen.gd, item_icons.gd).
- Priority: the gather -> craft -> build loop, rare items, recipe-gated progression; intricate,
  impactful building and processing (drying meat must be visible and matter); rendered item art that
  overflows its slot with rarity rims; fix the overexposure with one shared lighting builder.
- Already running, integration only: economy engine (`claude/mmo-econ`, finished, report at
  `docs/orchestration/reports/claude-mmo-econ.md`), network core (`claude/mmo-net`, finished, NET SMOKE
  PASS reported), audio layer (`claude/mmo-audio`, uncommitted WIP: 456 asset files, events.json,
  bus layout, settings.gd).
- Concurrent session branch `claude/survivor-v2-equip-mount-code-de20f0` (done, not merged) touches
  items.json, recipes.json, inventory.gd, item_def.gd, inventory_ui.gd, **and also** player.gd,
  player_anim.gd, rigged_model.gd, creature_view.gd, stegosaurus.json (Stegosaurus v2),
  tyrannosaurus.json, survivor.json, icons_manifest.json. Wave 1 treats all of these as off limits.

## 1. Cross-system ranking

Ranked by how far each gap keeps the game from "polished ARK:SA-class multiplayer survival with a real
marketplace", weighting what a player sees and what the gap unblocks. Severity is the verified one
(verifier adjustments applied). Merged duplicates are listed in brackets.

| # | Gap (primary id) | Sev | System | Why it ranks here |
|---|---|---|---|---|
| 1 | net-auth-02 Every outcome is client-side [net-single-04, pc-mmo-01, dino-ai-02, mmo-02, sec-mint-01, phys-net-01, world-mmo-state-11, sec-gather-11] | P0 | multiplayer | The MMO core. Net core and economy engine exist on branches; without server-simulated islands and the PlayerActions intent layer there is no shared world and no honest supply for the market. |
| 2 | mmo-01 No item or pet identity/provenance [net-identity-06, tame-06, econ-identity-01, econ-dino-01, sec-admin-13] | P0 | survival-crafting | Contract v2 needs uid + origin on every server-minted stack and pet; escrow, dupe checks and tradable dinosaurs depend on it. Cheap to start now. |
| 3 | lv-shadow-01 + lv-exposure-02 Invisible shadows, blown/flat daylight [lv-lab-mismatch-13, dino-art-13, lv-night-06, qa-render-01] | P0 | lighting-vfx | Owner-reported ("too bright"); every frame floats and washes out; labs light differently so all art QA is unreliable. The real fix is known: PSSM + sun yaw off the camera axis (verifier: ratio 0.989 -> 0.694 Forward+, 0.930 -> 0.492 compat). |
| 4 | econ-market-01 No marketplace at HEAD [ui-mmo-01, econ-tests-01] | P0 | economy | The owner's headline feature. Engine + net core are built but not merged or wired, and there is no Exchange UI. |
| 5 | ladder-02 + level-01 + ladder-01 Material tier does nothing; L5 is +7.8 %; bronze/steel unreachable | P0 | survival-crafting | The owner's stated priority is rare-resource, recipe-gated progression. Today gear tiers are cosmetic, so there is nothing rare to trade. |
| 6 | build-struct-01 No structural building [build-def-01, build-tier-01, build-gate-01, build-remove-01] | P0 | building | "Building is a big deal" (owner). 21 single prefab kits, no foundations/walls/roofs, no HP, gates are solid boxes, most kits cannot be removed. |
| 7 | tame-05 / econ-petbag-01 Pet bags truncate to 10 slots on every load | P0 | taming | Silent permanent loss of player goods each save/load (measured 140 -> 10 slots). S effort. |
| 8 | build-save-01 / sec-corrupt-06 / qa-savesafety-01 A bad or newer save is silently replaced | P1 | building | Verified: a schema-99 save is overwritten within 63 s while sitting on character creation; labs write the shared save; other worktrees lack override.cfg. Data loss for every player on any rollback. |
| 9 | dino-ai-01 Herbivores freeze forever after the first night | P0 | dino-ai | Every herbivore becomes a statue 324 s into a session. S effort. |
| 10 | dino-art-01 8 spawning species are box placeholders | P0 | dino-art | Visibly amateur on 8 islands; breaks HANDOFF.md:219. Credits are approved; Tripo route proven on the T. rex. |
| 11 | world-biome-01 + world-terrain-02 + world-veg-03 Every biome is the same flat, sparse, green disc | P0 | world-terrain | Desert/tundra/volcano look like a meadow, ~6 m relief, grass culled 48 m from island centre (even at spawn). Removes any sense of an ARK world. |
| 12 | tame-04 Pet levelling compounds (x93.8 HP at Lv60) [econ-pet-stats-01] | P0 | taming | Breaks every tier and boss and makes tradable dinosaur value meaningless; the economy engine's pet validator copied the formula, so it must change in step. |
| 13 | phys-hit-01 Melee resolves through walls both ways | P0 | physics | Bases cannot defend anything; through-wall hits were reproduced on a real island. |
| 14 | pc-combat-02 + pc-combat-01 Defence is broken (statuses land on dodged hits; telegraph gone 0.18-0.42 s before impact; roll refused 65 % of a swing) | P0 | player-combat | Combat cannot be learned; hunt_lab kills the survivor in under 2 s. |
| 15 | pc-anim-01 + pc-anim-02 Survivor floats 0.9 m and its mesh leaves the capsule (1.4 m lunge, 4.5 m roll overshoot) | P0 | player-combat | The player character looks broken in every frame; overlaps the survivor-v2 branch, so it is planned right after that merge. |
| 16 | qa-soak-01 + qa-runner-01 + qa-labs-01 The release gate has been red 12 days and most gates cannot fail | P0 | qa | Nothing above can be proven shipped until gates fail honestly. S-M effort. |
| 17 | survival-01 (+ owner direction on processing) No spoilage; processing is a timer | P1 | survival-crafting | Owner asked for visible, impactful processing (drying rack strips, colour change, smoke, dried meat keeps, buff, sells). Today nothing spoils, so processing has no reason to exist. |
| 18 | econ-faucet-01 Currency is finite (122 T-stones per save) | P0 | economy | Sailing soft-locks in single player; the MMO needs a renewable, per-account faucet (missions.json) before prices mean anything. |
| 19 | durability-01 No item sinks (no combat wear, no repair, no death cost) | P1 | survival-crafting | Without sinks a player market inflates; needs an owner call on death penalty. |
| 20 | tame-02 + tame-03 8 of 16 species untameable; the pen route ends in a dead item | P0 | taming | Half the roster (4 mounts) is unreachable content; pen tames vanish. |
| 21 | dino-art-05 + dino-art-03 Creature animation: speed_scale ignored (T. rex stomp lands 0.65 s after damage), generic donor clips, dead-bug knockdowns | P0 | dino-art | Readability of every fight; the time-scale fix is S effort. |
| 22 | perf-anim-load-01 12 clips (survivor sleep/craft/fish/gather_chop, T. rex sleep/tail_swipe) are not in the web export | P1 | performance | Verified by parsing the shipped pack: only `.glb.import` entries exist, so the DirAccess scan never matches on web. |
| 23 | perf-payload-01 + perf-tex-01 303 MB single web pack, 220 MB of it textures | P1 | performance | First load and every deploy re-download everything; blocks a web MMO. |
| 24 | dino-ai-03 No ecosystem (no predator-prey, hunger, scavenging, territory) | P1 | dino-ai | ARK's "living world"; needed once the island is shared. |
| 25 | econ-account-01 / sec-sybil-02 Free token accounts are a faucet | P0 | economy | 92 tradable T-stones per scripted account; contract v2 adds a 30-minute trade lock but objective rewards are not yet bound. Blocks public launch, not local. |
| 26 | ui-phone-01 Real runtime has no phone layout (24 % scale) | P0 | ui-ux | Every is_phone branch is dead at runtime; the lab hides it. Desktop is the current judge, so ranked below desktop-visible gaps. |
| 27 | ui-theme-01 + ui-inventory-01 + owner item-art direction No design system; bag shows icons and counts only | P1 | ui-ux | The owner asked for cool rendered item art overflowing slots with rarity rims; current UI reads as dev UI. |
| 28 | dino-ai-10 + tame-07 Ring/crater levels never apply and wild level does not change stats | P1 | dino-ai | Breaks "later ~5-level bands must feel harder" (GAUNTLET.md:66). |
| 29 | build-kits-01 Farming and steaming kits cannot be placed | P1 | building | Farming is unreachable in real play. S effort. |
| 30 | perf-ai-01 / dino-ai-11 AI cost ~0.1 ms per creature, O(N^2) scans, no AI LOD | P1 | performance | 129 creatures fill 90 % of a 60 Hz tick on an M5 Pro; a server holding several islands needs LOD. |
| 31 | lv-weather-03 + world-weather-09 Weather is one white-speck rain on every climate | P1 | lighting-vfx | Biome identity and survival pressure. |
| 32 | world-scale-04 World is 15 disconnected discs joined by a menu teleport | P0 | world-terrain | Owner decision on topology (shared zone maps vs island shards with sailing) shapes the server design. |
| 33 | net-hosting-07 + net-auth-08 No host that holds WebSockets; no real accounts | P1 | multiplayer | Blocks public launch only (owner kept the server local). |
| 34 | tame-01 Breeding, eggs, mutations, growth, imprinting absent | P1 | taming | ARK's endgame and the main source of high-value traded dinosaurs; PRD:747 forbids it, so owner decision. |
| 35 | audio-core-01 The game is silent | P0 | audio | Being fixed by the running 1a-audio package; ranked here because only integration remains to plan. |

## 2. Waves at a glance

Rule inside a wave: `files_owned` sets are disjoint. New tests go in new files `game/tests/t_<pkg>.gd`
(SceneTree scripts that print `[t_<pkg>] PASS` and exit 0/1); W1-QA makes `tools/test.sh` run every
`t_*.gd`, so nobody but the integrator edits `run_all.gd`. New labs register in `tools/labs.txt`
(one line each, appended by the integrator at merge).

| Wave | Starts when | Packages (priority order if agent slots are short) |
|---|---|---|
| 1 | now | W1-INT, W1-LIGHT, W1-SAVE, W1-TAME, W1-AI, W1-QA, W1-ITEMS, W1-COMBAT, W1-BUILD, W1-SRVDOM, W1-CANIM, W1-UI, W1-WEB, W1-STRUCTART (holds the Blender MCP lock), W1-ICONART (headless Blender), W1-BIOME (headless Blender), W1-ARTA, W1-ARTB |
| 2 | W1 merged; survivor-v2 branch merged; owner answers on the UI pass for W2-HUD/W2-SCREENS | W2-INT, W2-PLAYER, W2-PANIM, W2-DATA, W2-PROCESS, W2-BUILDSYS, W2-INV, W2-LOOP, W2-TERRAIN, W2-SCATTER, W2-SPAWN, W2-CVIEW, W2-ECO, W2-WEATHER, W2-VFX, W2-HUD, W2-SCREENS, W2-RERIG, W2-ARTC, W2-WEB2 |
| 3 | W2-PLAYER (PlayerActions) and W2-INT merged | W3-SRVACT, W3-SRVWORLD, W3-EXCHANGE, W3-SOCIAL, W3-NETQA, W3-WEAPONS, W3-NATUREART |
| 4 | owner decisions (hosting, breeding, topology, economy policy) | W4-HOST, W4-TAMING, W4-ECONH, W4-WORLD |

Integration of the three running branches is W1-INT. Audio's own one-line signal emits may land in
files other wave-1 packages own; the integrator keeps both at merge (they are additive).

## 3. Work packages


### Wave 1

Starts now. Foundations, owner-reported defects and cheap P0 fixes, all outside the protected files.

| Key | Title | Size | Blocker | Depends on |
|---|---|---|---|---|
| W1-INT | Integrate net core, economy engine and audio; serve the market over the socket | L | none | - |
| W1-LIGHT | Split island_runtime.gd and ship one shared lighting builder | L | none | - |
| W1-SAVE | Crash-safe, sanitized and isolated saves | M | none | - |
| W1-TAME | Pet record integrity, honest growth and complete taming routes | M | none | - |
| W1-AI | Wild AI that wakes, flees, levels and scales | L | none | - |
| W1-CANIM | Creature animation runtime that obeys time scale and speed | M | none | - |
| W1-COMBAT | Combat rules: walls block, dodges count, telegraphs last, hits land on the swing | L | none | - |
| W1-BUILD | Building correctness: every kit places, everything packs up, gates open, paths update fast | M | none | - |
| W1-ITEMS | Item identity, tier and level that matter, tool-gated gathering, no lost items | L | none | - |
| W1-SRVDOM | Server character store and intent handlers (pure domain, no networking) | L | none | - |
| W1-QA | Gates that can fail and a green release soak | M | none | - |
| W1-UI | Real phone layout, a theme, readable glyphs and the non-protected screens | L | none | - |
| W1-ICONART | Rendered item art that overflows its slot, with rarity rims | M | none | - |
| W1-ARTA | Tripo theropods: Allosaurus, Tarbosaurus, Dilophosaurus, plus a creature studio lab | XL | credits | - |
| W1-ARTB | Tripo quadrupeds and cat: Triceratops, Styracosaurus, Ankylosaurus, Smilodon | XL | credits | - |
| W1-WEB | Smaller, safer web build and culled vegetation | L | none | - |
| W1-BIOME | Per-climate ground: textures, palettes, ground cover and foliage tint | M | none | - |
| W1-STRUCTART | Blender structure set with visible processing stages | L | none | - |

#### W1-INT: Integrate net core, economy engine and audio; serve the market over the socket

**Size** L · **Blocker** none · **Depends on** nothing

Merge claude/mmo-net and claude/mmo-econ (both finished) and, once its reviewer passes, claude/mmo-audio into claude/mmo-overhaul. Register the MarketEngine ops on NetServer through EconStore in a new game/scripts/net/server_market.gd (auth.hello calls account.ensure). Persist rid caches in the econ snapshot. Make the presence speed limit mount-aware. Skip TouchControls under --server. Settlers issuance per active account per day (contract 0.7); bind the starting wallet and objective rewards (non-tradable). Write contracts.md v2.1: every act.* op with argument types, the CharacterState dict shape, PetStats as the single pet-stat formula, the structure interact() interface, the t_*.gd test convention, GD-Sync rejected.

**Owns:** `game/scripts/core/game.gd`; `game/scripts/core/main.gd`; `game/scripts/core/world.gd`; `game/project.godot`; `game/tests/run_all.gd`; `game/tests/economy_tests.gd`; `game/tests/net_tests.gd`; `game/tests/audio_tests.gd`; `game/scripts/net/`; `game/scripts/net/server_market.gd (new)`; `game/scripts/economy/`; `game/scenes/net/`; `game/data/economy/`; `game/scripts/dev/net_probe.gd`; `game/scripts/dev/audio_lab.gd`; `tools/net_smoke.sh`; `game/scripts/audio/`; `game/data/audio/`; `game/assets/audio/`; `game/default_bus_layout.tres`; `game/scripts/core/settings.gd`; `game/scripts/ui/touch_controls.gd`; `docs/orchestration/mmo/contracts.md`; `docs/orchestration/mmo/net-runbook.md`; `docs/design/economy.md`; `docs/orchestration/plan.md`

**Must not touch:** `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd`; `game/data/{items,recipes,icons_manifest}.json`; `game/scripts/items/{inventory,item_def}.gd`; `game/scripts/player/{player,player_anim}.gd`; `game/scripts/core/rigged_model.gd`; `game/scripts/creatures/creature_view.gd`; `game/export_presets.cfg (W1-WEB)`; `game/scripts/pets/ (W1-TAME: the AssetValidator switch to PetStats is W2-INT)`

**Closes:** net-core-01, econ-market-01, econ-tests-01, qa-mmo-01, sec-replay-09, sec-move-10, net-server-boot-09, econ-doc-drift-01, net-gdsync-17, sec-names-24, econ-faucet-01, sec-sybil-02, audio-core-01, audio-combat-02, audio-creature-03, audio-ambience-04, audio-music-05, audio-ui-07, audio-bus-13, audio-deafened-11, audio-proof-21, pc-audio-01, audio-footsteps-08, audio-gather-09, audio-build-10, audio-spatial-12, audio-web-14, audio-player-16, audio-pets-17, audio-telegraph-18, audio-licence-20, audio-mobile-22

**Acceptance (a reviewer can run or inspect each):**

- After the merge, tools/net_smoke.sh prints 'NET SMOKE PASS' and tools/test.sh prints '[tests] PASS' with the economy_tests and net_tests PASS lines present in the log; tools/smoke.sh prints 'SMOKE PASS'.
- New net test market_over_socket: hello, then market.orders returns at least 1 order with npc:true (Settlers); a write op re-sent with the same rid after a server restart returns the cached response and journal.jsonl gains no line.
- Presence test: a 9 m/s update from a mounted character is accepted; a 30 m jump inside 0.1 s is rejected.
- Under --server, get_node_or_null for TouchControls returns null (net test).
- The audio merge adds no autoload line to game/project.godot (Game.audio is a lazy child per contract 1); --lab=audio_lab prints its PASS line; a test applying Deafened lowers the SFX bus by at least 20 dB.
- economy_tests fuzz holds invariants 1-5 for at least 10,000 ops with a bound starting wallet and per-active-account Settlers issuance.
- contracts.md has a v2.1 section listing every act.* op with argument types and the CharacterState shape.


#### W1-LIGHT: Split island_runtime.gd and ship one shared lighting builder

**Size** L · **Blocker** none · **Depends on** nothing

Behaviour-preserving split of the 1,527-line island_runtime.gd into world_lighting.gd, world_weather.gd, island_terrain.gd, island_scatter.gd, island_spawns.gd and island_claims.gd (island_runtime keeps build orchestration and its public API). Then fix the owner-reported overexposure and the invisible shadows inside WorldLighting, which both IslandRuntime and LabKit use: AgX tonemap with calibrated exposure, sun about 2.0-2.5 against ambient 0.25-0.35, PSSM2/4 shadows with the sun yaw at least 45 deg away from the camera's 45 deg axis (the verifier's real root cause), fog colour driven by time of day plus a cool moon light at night, warm dawn and dusk keyed to Game.phase_name() thresholds, glow on, per-climate lighting profiles in lighting.json. Rain gets a vertex-colour streak material with shadows off; dirt discs brightened.

**Owns:** `game/scripts/world/island_runtime.gd`; `game/scripts/world/world_lighting.gd (new)`; `game/scripts/world/world_weather.gd (new)`; `game/scripts/world/island_terrain.gd (new)`; `game/scripts/world/island_scatter.gd (new)`; `game/scripts/world/island_spawns.gd (new)`; `game/scripts/world/island_claims.gd (new)`; `game/scripts/dev/lab_kit.gd`; `game/data/world/lighting.json (new)`; `game/scripts/world/dirt_disc.gdshader`; `game/scripts/dev/lighting_lab.gd (new)`; `game/scenes/dev/lighting_lab.tscn (new)`; `game/tests/t_lighting.gd (new)`

**Must not touch:** `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd`; `game/scripts/player/player.gd`; `game/scripts/creatures/creature_view.gd`; `game/scripts/world/{terrain_tiles.gdshader,foliage_sway.gdshader,climate_palette.gd} (W1-BIOME)`; `game/scripts/world/veg_batch.gd (W1-WEB)`; `game/scripts/world/harvest_node.gd (W1-ITEMS)`; `game/scripts/world/spawner.gd (W1-AI)`; `game/scripts/world/bonfire.gd (W1-BUILD)`; `game/data/world/{climates,rules}.json`

**Closes:** lv-shadow-01, lv-exposure-02, lv-night-06, lv-dawn-dusk-11, lv-climate-12, lv-lab-mismatch-13, lv-sky-17, lv-dirt-18, lv-particle-color-05, lv-post-08, perf-fx-01, dino-art-13, dino-art-08, world-lighting-12, qa-render-01

**Acceptance (a reviewer can run or inspect each):**

- --lab=lighting_lab windowed at 1600x900 in Forward+ and with --rendering-method gl_compatibility prints '[lighting] shadow_ratio=<r>' for a 1x3x1 SHADOWS_ONLY box on a grey plane under the temperate_25 profile with r <= 0.75 in both (baseline 0.989 and 0.930), then '[lighting] PASS'; exit 1 otherwise.
- Same lab, camp view: '[lighting] blown_pct=<p>' with p <= 1.0 % of pixels whose R, G and B all exceed 0.95, and ground mean luminance between 0.25 and 0.55, in both renderers.
- grep -rn 'Environment.new()\|DirectionalLight3D.new()' game/scripts lists only world_lighting.gd (and tests).
- wc -l game/scripts/world/island_runtime.gd <= 450 and every new island_*.gd and world_*.gd <= 450.
- Behaviour preserved: --lab=island_lab headless prints '[world] island temperate_25 nodes=378 creatures=24 spawn_rejected=0' exactly as before; SMOKE PASS; [tests] PASS.
- t_lighting: at tod 0.0 fog_light_color luminance <= 0.15 and a moon DirectionalLight3D is active; at tod 0.27 and 0.73 the sun colour R/B >= 1.3; the key light never points up from below the horizon.
- t_lighting: the rain draw pass has a material with vertex_color_use_as_albedo and cast_shadow OFF.
- Screenshots inspected (scratch dir): island_lab camp in both renderers; raptor_scale_lab in compat (compare with audit/dino-art/raptor_scale_lab_gl_cam10.png, which was near-white); night at tod 0.0; dusk at tod 0.73.


#### W1-SAVE: Crash-safe, sanitized and isolated saves

**Size** M · **Blocker** none · **Depends on** nothing

Atomic writes (tmp + rename) with a .bak of the previous good save. An unreadable or newer-schema save never silently starts a new world: rename it to .corrupt-<unix>, fall back to .bak, and refuse every save_now() until the player confirms a new game (this also stops World's 60 s autosave without editing world.gd). A save sanitizer drops unknown ids and clamps count, level, durability, skills and SP, t_stones and position. Every --lab, --smoke, probe flag or --script run saves under user://runs/<name>/. Persist the current non-home island's buildings and storage. Clamp offline catch-up. Restored building rows pass can_place; unknown kinds are refunded. shell_test.sh uses a temp dir.

**Owns:** `game/scripts/core/save_game.gd`; `game/scripts/core/save_migrations.gd`; `game/scripts/core/save_sanitizer.gd (new)`; `game/tests/t_save.gd (new)`; `game/tests/fixtures/ (new: save_v1, save_v3_golden, save_truncated, save_future, save_forged)`; `tools/shell_test.sh`; `game/scripts/dev/home_lab.gd`

**Must not touch:** `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd`; `game/scripts/items/{inventory,item_def,item_stack}.gd`; `game/scripts/player/player.gd`; `game/scripts/core/{world,game}.gd (W1-INT)`; `game/scripts/pets/pet_record.gd (W1-TAME)`; `game/scripts/world/ (other W1 packages)`

**Closes:** build-save-01, sec-corrupt-06, qa-save-01, qa-savesafety-01, qa-hermetic-01, sec-save-05, sec-clock-15, build-persist-01, build-restore-01, net-persist-05, qa-flaky-01

**Acceptance (a reviewer can run or inspect each):**

- --script res://tests/t_save.gd prints '[t_save] PASS'. Truncated fixture: sha256 of the original unchanged, a .corrupt-* file exists, SaveGame.save_now() returns false until confirm_new_game(). Future-schema fixture: file bytes unchanged after 70 s of simulated autosave. Two saves: .bak holds the first and no .tmp remains. v0, v1, v2 and v3-golden fixtures load and re-save field-for-field equal.
- Forged fixture (raid_helm x5000 L9999, an unknown id, count -7, t_stones -5, skill 99, empty position) loads with count 1, level 60, unknown and negative stacks dropped, t_stones 0, skills <= 60, a default position and no SCRIPT ERROR.
- Repeat of the verifier's probe (scratchpad/audit/sec-verify/overwrite.log): schema-99 save, boot main.tscn, idle 63 s on character creation: the on-disk schema is still 99 (was rewritten to 3).
- --lab=build_lab headless leaves user://save_1.json mtime and sha256 unchanged; its save lands under user://runs/build_lab/.
- Away-island probe (scratchpad/audit/build-verify): a basket with 9 stone placed on temperate_25 survives save and load ('placed_baskets=1 stone_in_baskets=9'; was 0).
- A save with saved_unix=0 clamps offline catch-up to <= 7 days (log line).
- grep -n 'app_userdata' tools/shell_test.sh returns nothing.


#### W1-TAME: Pet record integrity, honest growth and complete taming routes

**Size** M · **Blocker** none · **Depends on** nothing

PetStats.compute(def, genetics, level) becomes the only stat source: additive growth, and level_gains and EVs count. The bag is sized from the species on load (legacy saves re-expand). One grade derived from genetics also sets xp_rate and hunger efficiency. PetRecord gains uid, owner, origin, tamer, tamed_at, wild_level, name and parent_uids (defaults keep old saves loading). Fresh tames start at the wild level. RESPAWN_TIME 180 s. Nets refuse above 30 % HP; field tame checks capture technique; pen completion bonds directly (no dead tamed_animal item) and a field tame at the cap no longer frees the animal. capture_lab and pets_lab assert and exit non-zero.

**Owns:** `game/scripts/pets/pet_record.gd`; `game/scripts/pets/pet_stats.gd (new)`; `game/scripts/pets/field_tame.gd`; `game/scripts/pets/capture_system.gd`; `game/scripts/world/taming_pen.gd`; `game/scripts/creatures/creature_genetics.gd`; `game/scripts/dev/capture_lab.gd`; `game/scripts/dev/pets_lab.gd`; `game/tests/t_pets.gd (new)`

**Must not touch:** `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd`; `game/data/{items,recipes}.json`; `game/scripts/player/player.gd`; `game/scripts/economy/ (W1-INT; the validator switch is W2-INT)`; `game/scripts/creatures/creature.gd (W1-AI)`; `game/scripts/combat/hunt.gd (W1-COMBAT)`

**Closes:** tame-05, econ-petbag-01, tame-04, econ-pet-stats-01, tame-09, tame-10, econ-grade-01, tame-07, tame-03, tame-11, tame-15, tame-18, qa-tame-01, net-identity-06, econ-dino-01, sec-loss-08, qa-spec-01, tame-06, sec-pets-03, econ-conservation-01

**Acceptance (a reviewer can run or inspect each):**

- --script res://tests/t_pets.gd prints '[t_pets] PASS': a 140-slot triceratops bag with a stack in slot 50 survives a JSON round trip; a legacy 10-slot dict loads into 140 slots (was 140 -> 10).
- Growth: for every tameable species Lv60 HP <= 3.0x Lv1 HP and attack <= 2.5x (was 93.8x and 17.8x); no Lv60 pet exceeds the wild tyrannosaurus (hp 200000, attack 1100); stats after add_xp equal PetStats.compute exactly.
- genetics.train() raises the trained stat; for 200 random genetics rec.grade == genetics.overall_tier() and xp_rate comes from that grade; grep -rn '_roll_grade' game/scripts returns nothing.
- 1,000 tames give 1,000 distinct non-empty uids with origin in {tame, capture}; a fresh tame's level equals the wild level (capped at 60).
- PetRecord.RESPAWN_TIME == 180.0; CaptureSystem.attempt refuses a creature at 50 % HP; a fresh survivor's field tame of a tier-5 smilodon is refused with a 'Needs Capture Technique 5' hint.
- --lab=capture_lab headless lowers HP below 30 %, completes one field tame and one pen tame, prints '[capture] PASS bonded+=2' and exits 1 otherwise; --lab=pets_lab exits 1 when any of its five checks fails.


#### W1-AI: Wild AI that wakes, flees, levels and scales

**Size** L · **Blocker** none · **Depends on** nothing

CreatureBrain: a sleep branch that wakes at dawn and on close proximity; flee from the real threat (last damage source) with the herd clamp lifted while fleeing; one leash per pack plus 0.5 s re-acquire hysteresis; temperaments (skittish, defensive, territorial) in ai.json; shared _pre_think guards for every species override; pack slots sized to bodies; reach measured to the target's capsule so pets can bite giants; solo spawns pack 0; tames leave their wild pack; the post-kill spawn_home move expires after 120 s; disengage prints only with Game.debug_overlay; signal state_changed(prev, next) emitted in _set_state (audio hook). Creature: ring level offset and row tier_offset applied at spawn (Spawner passes its parent runtime); wild stats scale with level (rate in rules.json, # ASSUMPTION); the O(N^2) separation scan removed; brains think at 10 Hz staggered and freeze beyond 60 m of every player; authored hit_react plays when present; the corpse owner stops colliding (no 0.9 m float) and loot XP pays only when units moved. Chase speed multiplier exposed per archetype in ai.json with today's value until the owner answers.

**Owns:** `game/scripts/creatures/creature.gd`; `game/scripts/creatures/creature_def.gd`; `game/scripts/creatures/corpse.gd`; `game/scripts/creatures/brains/`; `game/scripts/world/spawner.gd`; `game/data/creatures/ai.json`; `game/data/world/rules.json`; `game/scripts/dev/ai_validation_lab.gd`; `game/scripts/dev/wild_ai_sweep_lab.gd (new) + scene`; `game/tests/t_ai.gd (new)`

**Must not touch:** `game/scripts/creatures/creature_view.gd`; `game/scripts/creatures/{creature_anim,creature_clips}.gd (W1-CANIM)`; `game/scripts/world/island_runtime.gd and island_*.gd (W1-LIGHT)`; `game/scripts/combat/ (W1-COMBAT)`; `game/scripts/pets/ (W1-TAME)`; `game/data/creatures/{stegosaurus,tyrannosaurus}.json`; `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd`

**Closes:** dino-ai-01, dino-ai-04, dino-ai-05, dino-ai-06, dino-ai-10, dino-ai-11, dino-ai-12, dino-ai-13, dino-ai-14, dino-ai-15, dino-ai-18, dino-ai-19, dino-ai-20, qa-ai-01, perf-ai-01, phys-perf-01, phys-reach-01, phys-corpse-01, pc-hitreact-01, sec-xpfarm-07, tame-07, perf-log-01, audio-creature-03

**Acceptance (a reviewer can run or inspect each):**

- --lab=wild_ai_sweep_lab headless covers all 19 species and prints '[aisweep] PASS', exit 1 on any failure: every species roams >= 0.5 m in 10 s; herbivores asleep at night leave sleep and move >= 1.0 m within 10 s of dawn and wake within 1 s when the survivor stands 2 m away (was never); a lone zebraceratops chased at 5.5 m/s for 10 s ends >= 8 m ahead and >= 25 m from home (was 1.6 m and 14.3 m); a herbivore bitten by a pet 1.7 m away while the survivor is 90 m away moves away from the pet.
- Levels: protoceratops in the gathering ring = tier-5 and velociraptor in the crater = tier+5+row tier_offset (were 20 and 25); a creature at tier+5 has higher stat_value(health) than one at tier.
- Same-species velociraptor pack while the survivor walks out at 5.5 m/s: <= 6 follower state changes in 10 s and no disengage print without the debug overlay.
- A velociraptor pet ordered onto a triceratops and onto a T. rex deals > 0 damage within 8 s (was 0).
- Corpses: dead body feet gap to terrain <= 0.05 m on temperate_25 (was 0.90 m); 50 loot-slot taps with a full bag give 0 XP (was +150).
- Perf, one headless Godot process: 120 creatures physics_ms_avg <= 8.0 (was 16.42), 24 creatures <= 2.0 (was 3.38).
- --lab=ai_validation_lab prints '[aival] PASS' and now exits 1 when pet repeat damage or post-kill pack coherence fails; t_ai sees state_changed exactly once per transition.


#### W1-CANIM: Creature animation runtime that obeys time scale and speed

**Size** M · **Blocker** none · **Depends on** nothing

Replace AnimationPlayer.speed_scale retiming with AnimationNodeTimeScale nodes in the CreatureAnim state machine (fixes the boss telegraph desync, run x1.6 and the limp). Add set_move_speed(mps) and set_time_scale(x) that drive the walk/run blend and cadence from baked natural clip speeds (tools/bake_clip_speeds.py -> clip_speeds.json). Trim the frozen second half of biped walk loops at load. Add sleep, feed and tail_swipe nodes so play_clip reaches the T. rex's authored clips and falls back to idle elsewhere. Switching creature.gd call sites to the new API is W2-CVIEW.

**Owns:** `game/scripts/creatures/creature_anim.gd`; `game/scripts/creatures/creature_clips.gd`; `game/data/creatures/anim_events.json`; `game/data/creatures/clip_speeds.json (new)`; `tools/bake_clip_speeds.py (new)`; `game/tests/t_creature_anim.gd (new)`; `game/scripts/dev/creature_anim_lab.gd (new) + scene`

**Must not touch:** `game/scripts/creatures/creature_view.gd`; `game/scripts/core/rigged_model.gd`; `game/scripts/creatures/creature.gd and brains/ (W1-AI)`; `game/assets/creatures/ (art packages)`

**Closes:** dino-art-05, dino-art-04, dino-art-10, dino-art-03

**Acceptance (a reviewer can run or inspect each):**

- t_creature_anim: velociraptor attack_primary at time scale 0.184 gives tree advance / wall time in [0.16, 0.21] (was 1.000); run at 1.6 gives [1.5, 1.7].
- T. rex attack_heavy under the tyrant's 1.2 s windup: the animation hit event lands within 0.05 s of the brain's damage time (was 0.65 s late).
- set_move_speed at species walk and run speed for velociraptor, megaloceros, protoceratops and tyrannosaurus: planted-foot ground speed / body speed in [0.75, 1.30] (stride method of scratchpad/audit/dino-art/stride.gd).
- No bone channel is static for more than 25 % of any biped walk loop (was 51 %).
- play_clip(&"sleep") on a T. rex puts the state machine on its sleep node; on a velociraptor it stays on idle with no error.
- tools/verify_rig_imports.gd still prints 'RIG IMPORT PASS'.


#### W1-COMBAT: Combat rules: walls block, dodges count, telegraphs last, hits land on the swing

**Size** L · **Blocker** none · **Depends on** nothing

One MeleeQuery (ray or short shape cast attacker->target excluding both; abort on structure or terrain) used by player melee, tackle, kick, creature contact and tyrant impact. Statuses apply only on landed hits and apply_for returns whether it landed. Telegraph life = real hit time + 0.1 s; the textureless Decal goes. Player damage applies at the clip's hit fraction. Kick and tackle range measured to the target surface, shove scaled by mass and refused for giants. Weapons wear per landed hit; accuracy_mult and evasion_add apply. Hit-chance and damage formulas move into combat_tuning.json with today's numbers until the owner answers. IsoCamera trauma shake on heavy hits and player damage. Hunt.start rejects pets; ranged blocked-LOS gives a notice; nets respect the 30 % rule; hunt_lab uses starter-level raptors and asserts.

**Owns:** `game/scripts/combat/hunt.gd`; `game/scripts/combat/creature_attack.gd`; `game/scripts/combat/telegraph.gd`; `game/scripts/combat/stone_projectile.gd`; `game/scripts/combat/siege_projectile.gd`; `game/scripts/combat/ground_snare.gd`; `game/scripts/combat/status_effects.gd`; `game/scripts/status/status_def.gd`; `game/scripts/combat/melee_query.gd (new)`; `game/data/combat_tuning.json (new)`; `game/data/statuses.json`; `game/scripts/camera/iso_camera.gd`; `game/scripts/dev/hunt_lab.gd`; `game/scripts/dev/combat_rules_lab.gd (new) + scene`; `game/tests/t_combat.gd (new)`

**Must not touch:** `game/scripts/player/{player,player_anim}.gd`; `game/scripts/creatures/creature.gd (W1-AI)`; `game/scripts/world/build_*.gd (W1-BUILD)`; `game/scripts/pets/ (W1-TAME)`; `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd`

**Closes:** phys-hit-01, pc-combat-02, pc-combat-03, pc-feel-01, pc-data-01, pc-data-02, pc-ranged-01, phys-kick-01, phys-aoe-01, phys-melee-02, pc-bug-01, pc-hitreact-02, pc-test-01, pc-lab-01, pc-misc-01, lv-decal-10, perf-decal-01, armor-01, pc-balance-01, durability-01, phys-test-01, tame-11

**Acceptance (a reviewer can run or inspect each):**

- --lab=combat_rules_lab headless prints '[combatrules] PASS', exit 1 on any failure: a fence ring (BuildGrid occupancy) between survivor and velociraptor for 10 s gives 0 bites and 0 player hits through the wall, while the same set-up without the fence gives >= 3 bites (control).
- Forced dodge 1.0 and forced miss: a velociraptor heavy applies 0 statuses (no knockdown, no bleed).
- At the HIT frame of a velociraptor heavy and a protoceratops heavy at least 1 live telegraph exists for that attacker (was 0).
- Stone-knife damage lands >= 0.25 s after the swing starts (was the same frame).
- Kick: compsognathus moves >= 1.5 m; triceratops and T. rex move <= 0.3 m with a 'too heavy' notice; a kick at contact range on a T. rex is accepted (was 'Too far').
- 10 landed club hits lower its durability by 10.
- 1,000 seeded swings by a groggy attacker hit at base x accuracy_mult +- 3 %.
- IsoCamera trauma > 0 right after a heavy hit and back to 0 within 1.0 s.
- --lab=hunt_lab: the survivor is alive at the 3.2 s acceptance shot; the lab exits 1 when no corpse or loot appears. Hunt.start on a pet starts no hunt.


#### W1-BUILD: Building correctness: every kit places, everything packs up, gates open, paths update fast

**Size** M · **Blocker** none · **Depends on** nothing

Route field_small, field_large and steamer kits; pay after a successful spawn; one shared pack_up for every placed kind on owned land that returns kit and contents only when the bag has room (FieldCatapult gets one, removing the script error); fence auto-rotation only as an initial suggestion; gates get a saved open state that toggles collision and TilePath walkability, exposed as interact(player) for W2-PLAYER; TilePath builds once and updates only changed cells (Vector2i keys) and returns a reachable flag; player-facing rejection reasons; build_lab tests water inside a claimed rect and exits non-zero.

**Owns:** `game/scripts/world/build_placer.gd`; `game/scripts/world/build_grid.gd`; `game/scripts/world/placed_building.gd`; `game/scripts/world/craft_station.gd`; `game/scripts/world/field_catapult.gd`; `game/scripts/world/field_plot.gd`; `game/scripts/world/bonfire.gd`; `game/scripts/world/tile_path.gd`; `game/scripts/world/prop_visuals.gd`; `game/scripts/dev/build_lab.gd`; `game/scripts/dev/siege_probe.gd`; `game/tests/t_build.gd (new)`

**Must not touch:** `game/data/{items,recipes}.json (steamer_kit recipe is W2-DATA)`; `game/data/props_manifest.json (W1-STRUCTART)`; `game/scripts/world/island_runtime.gd and island_*.gd (W1-LIGHT)`; `game/scripts/items/station_craft.gd (W1-ITEMS)`; `game/scripts/player/player.gd`; `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd`

**Closes:** build-kits-01, build-remove-01, build-gate-01, build-place-03, build-place-04, perf-path-01, phys-path-01, build-test-01, build-ux-01, sec-loss-08, econ-conservation-01

**Acceptance (a reviewer can run or inspect each):**

- t_build: a loop over every items.json place_as prints '[build] route <kit> ok' for all 24 kits including field_small_kit, field_large_kit and steamer_kit (were UNPLACEABLE).
- A forced _spawn failure leaves the kit in the bag.
- pack_up on every placed kind returns its kit (and basket contents) when the bag has room; with a full bag it refuses, the structure stays and units before == units after; catapult pack_up raises no SCRIPT ERROR.
- A fence placed with a manual rotation keeps it (requested rot == placed rot).
- Gate: open state round-trips to_dict; with the gate open a TilePath route through it exists, closed none does.
- TilePath: occupy/release updates take <= 5 ms on temperate_25 (was a 440-572 ms full rebuild); path() to an enclosed target returns reachable=false.
- --lab=build_lab headless prints '[build] rejected water' for a water cell inside a claimed rect and '[build] PASS', exit 1 on mismatch; --siege-probe still reports catapult destruction and the label uses max_hp.


#### W1-ITEMS: Item identity, tier and level that matter, tool-gated gathering, no lost items

**Size** L · **Blocker** none · **Depends on** nothing

ItemStack gains uid, origin, creator and created_at for non-fungible stacks; uid'd stacks never merge, fungible stacks and old saves are unchanged; climate stops splitting gathered stacks. scaled_damage, armor and durability = base x level_multiplier(level, 0.08) x tier_multiplier(material_tier) inside ItemStack (item_def.gd untouched). Per-family minimum pick tier in nature_manifest.json for flint, obsidian, copper and iron (loose stone stays hand-pickable) and held-pick power on rock nodes; manifest yield ranges honoured; harvest colliders sized from the manifest. Crafting refuses when the output cannot fit; station refunds never drop units; a recipe switch mid-craft cancels and refunds. Crafted level cap monotonic (no skill-0 = 60 fallback); preview_level -1 when picks are invalid; burn chance exposed, reduced by cooking skill, injectable RNG; eat cancel past 50 % rolls raw/poison risk. The hand shows the equipped weapon while hunting. Raid probes retuned and given neutral boss genetics.

**Owns:** `game/scripts/items/item_stack.gd`; `game/scripts/items/progression_scaling.gd`; `game/scripts/items/crafting.gd`; `game/scripts/items/station_craft.gd`; `game/scripts/items/eat_session.gd`; `game/scripts/items/food.gd`; `game/scripts/world/harvest_node.gd`; `game/scripts/world/harvest_yield.gd`; `game/data/nature_manifest.json`; `game/scripts/dev/craft_lab.gd`; `game/scripts/dev/kitchen_lab.gd`; `game/scripts/dev/loot_level_probe.gd`; `game/scripts/dev/progression_probe.gd`; `game/scripts/dev/raid_gear_probe.gd`; `game/scripts/dev/raid_fight_probe.gd`; `game/tests/t_items.gd (new)`

**Must not touch:** `game/scripts/items/{inventory,item_def}.gd`; `game/data/{items,recipes}.json`; `game/scripts/creatures/corpse.gd (W1-AI)`; `game/scripts/combat/hunt.gd (W1-COMBAT)`; `game/scripts/world/veg_batch.gd (W1-WEB)`; `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd`

**Closes:** ladder-02, level-01, mmo-01, net-identity-06, econ-identity-01, inv-01, gather-02, craft-01, craft-03, craft-04, sec-skill0-16, sec-craft-22, sec-eat-23, sec-loss-08, econ-conservation-01, qa-craft-01, qa-flaky-01, pc-raid-01, phys-node-01, pc-weapon-01

**Acceptance (a reviewer can run or inspect each):**

- --script res://tests/t_items.gd prints '[t_items] PASS': uid'd stacks never merge and round-trip uid/origin; fungible stone stacks still merge; same-level temperate and tropical fibre stacks merge.
- work_axe scaled_damage L5/L1 >= 1.30 (was 1.078); a copper-tier knife out-damages a stone-tier knife of the same level by the tier_multiplier ratio.
- copper_ore and black_iron refuse bare hands with 'needs <tier> pick'; loose stone still gathers bare-handed; a flint pick gathers flint faster than bare hands would at the minimum tier.
- 200 Rock rolls stay within the manifest's [2,4] stone range with mean > 2.4 (was always 1).
- Craft with a full bag: inputs unchanged, a refusal notice, no output lost; station cancel with a full bag keeps the refund in the station; switching recipe mid-craft refunds the first recipe's inputs.
- crafted_level at skill 0 <= at skill 1 for the same materials; preview_level == -1 for invalid picks; burn chance falls monotonically from cooking skill 0 to 60 and is reproducible with a seeded RNG; cancelling a raw-meat meal at 60 % applies the raw-risk roll.
- --raid-gear-probe passes 10 of 10 runs (was failing 4 of 6) with retuned thresholds; --lab=craft_lab and --lab=kitchen_lab print PASS and exit 1 on failure.
- With a hunt target set, the hand shows the equipped weapon model (club or crossbow from props_manifest) instead of the gather tool (windowed screenshot inspected).


#### W1-SRVDOM: Server character store and intent handlers (pure domain, no networking)

**Size** L · **Blocker** none · **Depends on** nothing

The server side of contract v2 section 0 as deterministic, node-free code in the style of the economy engine: CharacterStore (bag, equipment, wallet mirror, pets, skills, position) persisted with snapshot + journal; intent handlers for gather, loot, craft, place, equip, eat, tame and attack that run the existing domain classes (Inventory, Crafting, CaptureSystem, FieldTame, ProgressionScaling) on the server copy against a WorldFacade interface; a server-owned RNG seeded per op seq; uid + origin + seq on every created stack and pet; offline save import refused. Networking and the simulated island come in W3.

**Owns:** `game/scripts/server/ (new: character_store.gd, character_state.gd, world_facade.gd, intent_handlers.gd, server_rng.gd, provenance.gd)`; `game/tests/t_server_domain.gd (new)`

**Must not touch:** `game/scripts/net/ and game/scripts/economy/ (W1-INT)`; `game/scripts/items/ and game/scripts/pets/ (W1-ITEMS, W1-TAME: public APIs only)`; `game/scripts/player/player.gd`; `game/data/{items,recipes}.json`

**Closes:** net-auth-02, sec-mint-01, mmo-02, mmo-01, econ-supply-trust-01, tame-06

**Acceptance (a reviewer can run or inspect each):**

- --script res://tests/t_server_domain.gd prints '[t_server_domain] PASS'.
- gather on a facade node within 2.6 m with pool > 0 mints a stack with uid, origin=gather and the journal seq; out of range, empty pool or missing tool returns the matching error code and the canonical state hash is unchanged.
- craft(recipe_id, picks) consumes exactly the planned inputs and mints a uid'd output with origin=craft; tame draws on the server RNG so the same journal gives the same genetics.
- 10,000-op seeded fuzz: per def minted - consumed == units held; no negative counts; every uid in exactly one container.
- Replaying the journal from empty reproduces byte-identical canonical JSON.
- An offline save dict offered as an import or deposit returns invalid_asset.


#### W1-QA: Gates that can fail and a green release soak

**Size** M · **Blocker** none · **Depends on** nothing

test.sh and smoke.sh fail on any 'SCRIPT ERROR' or 'Parse Error' line, and test.sh runs every game/tests/t_*.gd; smoke also boots island_lab and checks counts. A shared LabResult helper (expect/finish -> exit 1). tools/labs.sh runs every lab in tools/labs.txt headless with a timeout and needs a PASS line. Labs that never exit (creature_lab, raptor_scale_lab, foundation_lab renamed harvest_lab) get a headless quit; creature_lab gets an invulnerable survivor. counter_matchup, tyrant_window (<= 200 s) and bot gate mode exit 1 on PARTIAL or FAIL. web_soak gives its survivor Survival 20 and times out every await. production_soak.mjs checks the expected stamp and records rAF p95. CI pinned to Godot 4.7.1, triggered on claude/** pushes, running test, smoke and labs and uploading PNGs. A perf_budget_lab and a t_rules.gd with GAUNTLET literals.

**Owns:** `tools/test.sh`; `tools/smoke.sh`; `tools/labs.sh (new)`; `tools/labs.txt (new)`; `tools/production_soak.mjs`; `.github/workflows/ci.yml`; `game/scripts/dev/lab_result.gd (new)`; `game/scripts/dev/web_soak.gd`; `game/scripts/dev/creature_lab.gd`; `game/scripts/dev/raptor_scale_lab.gd`; `game/scripts/dev/foundation_lab.gd (renamed harvest_lab.gd + scene)`; `game/scripts/dev/counter_matchup_probe.gd`; `game/scripts/dev/tyrant_window_probe.gd`; `game/scripts/dev/bot_survivor.gd`; `game/scripts/dev/bot_rest_probe.gd`; `game/scripts/dev/earned_training_probe.gd`; `game/scripts/dev/camp_travel_probe.gd`; `game/scripts/dev/cargo_capacity_probe.gd`; `game/scripts/dev/island_lab.gd`; `game/scripts/dev/skills_lab.gd`; `game/scripts/dev/sleep_lab.gd`; `game/scripts/dev/plain_bush_lab.gd`; `game/scripts/dev/berry_state_lab.gd`; `game/scripts/dev/layout_perf_lab.gd`; `game/scripts/dev/pet_passthrough_lab.gd`; `game/scripts/dev/perf_budget_lab.gd (new) + scene`; `game/tests/t_rules.gd (new)`

**Must not touch:** `game/tests/run_all.gd`; `game/scripts/core/main.gd (W1-INT)`; `labs owned by other W1 packages (ai_validation, wild_ai_sweep, capture, pets, build, siege, hunt, combat_rules, craft, kitchen, loot_level, progression, raid_*, home, ui_*, resource_visibility, lighting, biome, item_art, creature_studio, creature_anim)`

**Closes:** qa-soak-01, qa-runner-01, qa-labs-01, qa-smoke-01, qa-ci-01, qa-noise-01, qa-runner-02, qa-perf-01, perf-gate-01, qa-stamp-01, qa-bot-01, test-01, qa-render-01, qa-visual-01, dino-art-21, phys-test-01, qa-hermetic-01, qa-spec-01, build-test-01

**Acceptance (a reviewer can run or inspect each):**

- A scratch t_crash.gd that calls a method on null makes tools/test.sh exit 1 (deleted after the demo); the real suite exits 0.
- tools/labs.sh prints one PASS row per lab in labs.txt and exits 0; flipping one expectation makes it exit 1.
- creature_lab, raptor_scale_lab and harvest_lab exit headless within 30 s with a PASS or FAIL line (were killed at 240 s).
- Desktop --web-soak prints every checkpoint through travel and '[soak] PASS' (was hanging on 'Needs Survival 20'); production_soak.mjs against a local or preview export prints PASS and fails when the expected stamp differs.
- --counter-matchup-probe exits 1 on 'correct=false'; --bot --bot-gate exits 1 on PARTIAL.
- The CI run uses Godot 4.7.1, triggers on a push to claude/**, and its log shows '[tests] PASS', 'SMOKE PASS' and the labs table.
- t_rules.gd asserts GAUNTLET literals (pet cooldown 180 s, 3 active pets, capture below 30 %) and passes once W1-TAME is merged.
- perf_budget_lab prints '[perf] physics_ms=... frame_ms=... prims_visible=...' and fails above thresholds recorded after W1-AI and W1-WEB merge.


#### W1-UI: Real phone layout, a theme, readable glyphs and the non-protected screens

**Size** L · **Blocker** none · **Depends on** nothing

Drive root content_scale_size from the window and device scale so a 390-pt phone gets about 390 logical px and UiTokens.is_phone works at runtime, with 1600x900 desktop unchanged. A Theme generated from UiTokens applied at runtime. One UiTokens.draw_centered helper fixing four off-centre draw_string sites; type floor 12 px; white symbol icons instead of system emoji in the files this package owns. ContextRadial resolves hex overlap by rotating the whole ring instead of clamping each hex. Skills sheet as an aligned grid inside the content area; craft card 'Lv —' and stat lines; atlas axis-aligned with distinct legend colours and display names; plate backing pill and fixed glyph centring; one LevelDisplay helper for fatigue panel and atlas; HexButton focusable with a focus ring; a real-scene capture lab.

**Owns:** `game/scripts/core/display_mode.gd`; `game/scripts/ui/ui_tokens.gd`; `game/scripts/ui/hex_button.gd`; `game/scripts/ui/status_glyph.gd`; `game/scripts/ui/gather_ring.gd`; `game/scripts/ui/eat_progress.gd`; `game/scripts/ui/held_item_slot.gd`; `game/scripts/ui/craft_ui.gd`; `game/scripts/ui/craft_card.gd`; `game/scripts/ui/station_menu.gd`; `game/scripts/ui/station_radial.gd`; `game/scripts/ui/skills_sheet.gd`; `game/scripts/ui/map_screen.gd`; `game/scripts/ui/fatigue_panel.gd`; `game/scripts/ui/world_ui.gd`; `game/scripts/ui/creature_plates.gd`; `game/scripts/ui/context_radial.gd`; `game/scripts/ui/gather_radial.gd`; `game/scripts/ui/food_inspector.gd`; `game/scripts/ui/pickup_toast.gd`; `game/scripts/ui/respawn_ring.gd`; `game/scripts/ui/character_creation.gd`; `game/scripts/ui/level_display.gd (new)`; `game/ui/deadfront_theme.tres (new)`; `game/scripts/dev/ui_screenshot_lab.gd`; `game/scripts/dev/ui_family_lab.gd`; `game/scripts/dev/ui_real_capture_lab.gd (new) + scene`; `game/tests/t_ui.gd (new)`

**Must not touch:** `game/scripts/ui/{hunt_hud,inventory_ui,animal_screen,item_icons}.gd (owner UI pass)`; `game/scripts/ui/touch_controls.gd and game/project.godot (W1-INT)`; `game/scripts/ui/{item_art,art_slot}.gd (W1-ICONART)`

**Closes:** ui-phone-01, ui-gates-01, ui-glyph-01, ui-radial-01, ui-center-01, ui-typo-01, ui-theme-01, ui-skills-01, ui-craft-01, ui-map-01, ui-level-01, ui-taming-01, ui-gamepad-01, tame-17, qa-visual-01, craft-04

**Acceptance (a reviewer can run or inspect each):**

- --lab=ui_real_capture_lab boots the real island at --resolution 390x844 and at 1600x900: prints '[uireal] phone=true min_font_px=<n>' with n >= 12 at 390x844, and 'phone=false' with logical width 1600 at 1600x900; saves root-viewport PNGs of HUD, craft, skills, atlas, radial and character creation; exit 1 otherwise.
- t_ui scans the owned ui/*.gd files: no code point in U+1F300-1FAFF and no literal font size below 12.
- draw_centered: a 40 px string centred at x=100 starts at x=80 (unit test).
- ContextRadial with two options and an anchor above the view returns hex centres at least one hex diameter apart (the verifier found them identical).
- A craft card for a recipe with missing inputs shows 'Lv —' (label text check and screenshot).
- Screenshots inspected at 1600x900 and 390x844: no text over the vitals block in skills or craft, distinct atlas legend colours, plate letters fully inside their circles.


#### W1-ICONART: Rendered item art that overflows its slot, with rarity rims

**Size** M · **Blocker** none · **Depends on** nothing

Headless Blender scripts (tools/blender/items/*.py, run with Blender -b -P; the Blender MCP lock belongs to W1-STRUCTART) build models for at least 60 items (tools, weapons, armor, food, rare materials, kits); tools/render_icons.py renders them under one studio light rig to transparent 256 px PNGs. item_rarity.json assigns common/uncommon/rare/epic/legendary per item (# ASSUMPTION until W2-DATA's rare-item design). ItemArt returns texture + rim colour and falls back to the white symbol; ArtSlot is a reusable slot widget whose art rises 12-20 % above the slot with a rarity rim and glow. inventory_ui/item_icons consume it in W2-SCREENS.

**Owns:** `tools/render_icons.py`; `tools/blender/items/ (new)`; `game/assets/icons/render/ (new)`; `game/data/item_rarity.json (new)`; `game/scripts/ui/item_art.gd (new)`; `game/scripts/ui/art_slot.gd (new)`; `game/scripts/dev/item_art_lab.gd (new) + scene`

**Must not touch:** `game/scripts/ui/{item_icons,inventory_ui,hunt_hud,animal_screen}.gd`; `game/data/{icons_manifest,items}.json`; `Blender MCP (held by W1-STRUCTART)`

**Closes:** ui-icons-01, ui-inventory-01, ui-theme-01

**Acceptance (a reviewer can run or inspect each):**

- >= 60 PNGs in game/assets/icons/render/, 256x256 RGBA, all four edge rows fully transparent, each <= 64 KB, with a manifest listing item id, source script and render settings.
- Re-running the render for one item reproduces a byte-identical PNG.
- --lab=item_art_lab windowed at 1600x900 and 390x844 shows a 5x4 ArtSlot grid covering every rarity; screenshots inspected: art rises above the slot top edge, rims coloured by rarity, white action glyphs unchanged; copper/bronze/iron/steel ingot and straw_roll_kit (previously iconless) have art.
- ItemArt.texture_for(&"no_such_id") returns the symbol fallback with no error.


#### W1-ARTA: Tripo theropods: Allosaurus, Tarbosaurus, Dilophosaurus, plus a creature studio lab

**Size** XL · **Blocker** credits · **Depends on** nothing

game-asset-pipeline route per species: concept, owner Gate-1 approval, Tripo multiview mesh, dsc bespoke rig with Jaw, >= 2 neck and >= 6 tail bones, authored clips (the 9 contract clips plus a roar with open jaw), Godot import, review. A creature_studio_lab (--species --clip --t, perspective camera, shared island lighting once W1-LIGHT merges) replaces the out-of-repo studio script. Back-fill assets/concept-art/INDEX.md for every species with task ids and credits. Credit cap: 300 Tripo credits for this package; stop and report at the cap. Spend is approved from the existing balance (2026-10-18).

**Owns:** `game/assets/creatures/allosaurus/ (new)`; `game/assets/creatures/tarbosaurus/ (new)`; `game/assets/creatures/dilophosaurus/ (new)`; `game/data/creatures/allosaurus.json`; `game/data/creatures/tarbosaurus.json`; `game/data/creatures/dilophosaurus.json`; `assets/concept-art/INDEX.md`; `game/scripts/dev/creature_studio_lab.gd (new) + scene`

**Must not touch:** `game/data/creatures/{stegosaurus,tyrannosaurus}.json`; `game/scripts/creatures/creature_view.gd`; `other species folders (W1-ARTB, W2-RERIG)`

**Closes:** dino-art-01, dino-art-18, dino-art-21, dino-art-17

**Acceptance (a reviewer can run or inspect each):**

- Per species: Tripo task ids and credits recorded in the JSON pipeline block; package total <= 300 credits.
- GLB 10k-20k tris with 2K Color/ORM/Normal; skeleton has Jaw, >= 2 neck and >= 6 tail bones.
- tools/verify_rig_imports.gd prints 'RIG IMPORT PASS' including the new species; tools/audit_creature_deformation.py gives max_edge_ratio <= 3.0 and p99 <= 1.6 on every clip; idle/walk/run feet within 0.03 m of the ground.
- creature_studio_lab gl_compatibility shots (idle, walk, attack hit frame, knockdown end, roar) inspected: side-lying knockdown, open jaw on roar, no stretching.
- On every island whose islands.json table spawns the species, the creature spawn log shows using_glb=true for it (was the box placeholder).


#### W1-ARTB: Tripo quadrupeds and cat: Triceratops, Styracosaurus, Ankylosaurus, Smilodon

**Size** XL · **Blocker** credits · **Depends on** nothing

Same route as W1-ARTA for four body plans the transplanted donor rigs cannot serve: ceratopsians with jaw, neck chain and frill-safe weights, an ankylosaur with a club-tail chain, and a cat for Smilodon. Credit cap: 400 Tripo credits; stop and report at the cap. Hand INDEX.md rows to W1-ARTA through the package report.

**Owns:** `game/assets/creatures/triceratops/ (new)`; `game/assets/creatures/styracosaurus/ (new)`; `game/assets/creatures/ankylosaurus/ (new)`; `game/assets/creatures/smilodon/ (new)`; `game/data/creatures/triceratops.json`; `game/data/creatures/styracosaurus.json`; `game/data/creatures/ankylosaurus.json`; `game/data/creatures/smilodon.json`

**Must not touch:** `assets/concept-art/INDEX.md (W1-ARTA)`; `game/data/creatures/{stegosaurus,tyrannosaurus}.json`; `game/scripts/creatures/creature_view.gd`; `other species folders`

**Closes:** dino-art-01

**Acceptance (a reviewer can run or inspect each):**

- Per species: Tripo task ids and credits recorded; package total <= 400 credits.
- GLB 10k-20k tris, 2K PBR; skeleton has Jaw, >= 2 neck and >= 5 tail bones (ankylosaur club on the last tail bone).
- 'RIG IMPORT PASS' including the new species; max_edge_ratio <= 3.0 and p99 <= 1.6 on every clip; feet within 0.03 m of the ground in idle/walk/run.
- Studio lab compat shots inspected: no frill or plate clipping in attack and knockdown; knockdown side-lying.
- swamp_55 (triceratops), tundra_55 (smilodon), volcanic_60 (ankylosaurus) and every island spawning styracosaurus log using_glb=true.


#### W1-WEB: Smaller, safer web build and culled vegetation

**Size** L · **Blocker** none · **Depends on** nothing

Exclude scripts/dev, scenes/dev, tests, creature ref/ folders and sheet.png from client exports and add a Linux 'Server' preset (dedicated_server, strip visuals). Strip emissive maps at import for generated nature and resources and cap prop textures at 512 px. Payload ceiling in export_web.sh; parallel part fetch (4) in the loader. VegBatch chunks its instances into 32 m cells internally (same public API) with a per-chunk visibility range and shadows off for small props. Shell manifests require sha256 and valid names; the static manifest.json is no longer deployed.

**Owns:** `game/export_presets.cfg`; `tools/web_pack_for_vercel.py`; `tools/export_web.sh`; `tools/check_export_payload.py`; `tools/payload_report.sh`; `hosting/web/vercel.json`; `hosting/builds/`; `game/shell/boot.gd`; `game/shell/shell_loader.gd`; `game/scripts/world/veg_batch.gd`; `game/scripts/dev/resource_visibility_lab.gd`; `*.import under game/assets/nature/generated/ and game/assets/resources/generated/`; `tools/import/strip_emission.gd (new post-import script)`

**Must not touch:** `game/project.godot (W1-INT)`; `game/scripts/world/island_runtime.gd and island_*.gd (W1-LIGHT)`; `game/scripts/world/harvest_node.gd and game/data/nature_manifest.json (W1-ITEMS)`; `game/assets/creatures/ and game/assets/characters/`

**Closes:** perf-payload-01, perf-tex-01, perf-export-01, sec-webpack-19, sec-shell-20, perf-veg-01, net-server-boot-09

**Acceptance (a reviewer can run or inspect each):**

- tools/export_web.sh produces a pack <= 200 MB (was 317,479,824 bytes) and fails when the pack exceeds 220 MB.
- check_export_payload.py parses the pack and finds 0 files under scripts/dev, scenes/dev, tests, assets/creatures/*/ref or named sheet.png.
- 0 materials with emission_enabled among loaded generated nature and resource meshes (the runtime _strip_emission stays as a guard).
- temperate_25 camp view, render info in Forward+ and compat: visible primitives <= 900k (was 1.43M) and shadow primitives <= 3.0M (was 3.8-4.5M); --lab=resource_visibility_lab PASS; island_lab counts unchanged.
- The loader fetches 4 parts concurrently (code check) and a local export served from export/web reaches the world in desktop Chrome with time-to-world logged.
- boot.gd refuses a scratch manifest entry with no sha256 or a name outside [a-z0-9_-]{1,32}.


#### W1-BIOME: Per-climate ground: textures, palettes, ground cover and foliage tint

**Size** M · **Blocker** none · **Depends on** nothing

biomes.json for all 10 climates (texture set, palette, ground-cover families, foliage tint, palm allowlist, special-tile allowlist). Ten ground texture sets baked procedurally with headless Blender (tools/blender/terrain/*.py), since asset libraries are off. terrain_tiles.gdshader and foliage_sway.gdshader take the new uniforms with defaults that reproduce today's look. BiomeMaterial builds terrain and foliage materials from biomes.json; biome_lab renders a patch per climate. Hooking it into island generation is W2-TERRAIN and W2-SCATTER.

**Owns:** `game/data/world/biomes.json (new)`; `game/assets/terrain/<climate>/ (new)`; `tools/blender/terrain/ (new)`; `game/scripts/world/terrain_tiles.gdshader`; `game/scripts/world/foliage_sway.gdshader`; `game/scripts/world/climate_palette.gd`; `game/scripts/world/biome_material.gd (new)`; `game/scripts/dev/biome_lab.gd (new) + scene`

**Must not touch:** `game/scripts/world/island_runtime.gd and island_*.gd (W1-LIGHT)`; `game/data/world/climates.json`; `game/data/nature_manifest.json (W1-ITEMS)`; `Blender MCP (held by W1-STRUCTART)`

**Closes:** world-biome-01, world-placement-08

**Acceptance (a reviewer can run or inspect each):**

- biomes.json has an entry for each of the 10 climates in climates.json, and every texture path exists.
- --lab=biome_lab windowed writes 10 PNGs (one 40x40 m patch per climate, shared lighting); pairwise mean ground RGB distance >= 0.08 for every pair except tropical/blue_tropical and tundra/snowfield; screenshots inspected: desert reads as sand, tundra as snow or frozen dirt, volcanic as basalt and ash, swamp as peat and mud.
- With biomes.json not yet hooked, the island_lab camp screenshot differs from the pre-change shot by <= 1 % mean (shader defaults unchanged).
- Each texture set is 1024 px and <= 3 MB imported; the bake scripts regenerate it.


#### W1-STRUCTART: Blender structure set with visible processing stages

**Size** L · **Blocker** none · **Depends on** nothing

With Blender MCP (this package holds the single Blender lock in wave 1), build a coherent stylized set: tent (canvas), basket, workbench, campfire, stone fire pit, bonfire, fence, gate (two leaves with hinge pivots), sign, catapult with textured wheels, drying rack in 4 stages (empty, raw strips, darker drying strips, dried), smoker, crock pot, steamer, mortar, well, pier/dock, plus floor/wall/doorway/roof stand-ins for W2-BUILDSYS. One 1024 atlas per set; tools/blender/structures/*.py reproduce each; props_manifest.json points every kind at the new GLBs.

**Owns:** `game/assets/props/blender/ (new)`; `tools/blender/structures/ (new)`; `game/data/props_manifest.json`

**Must not touch:** `game/scripts/world/{prop_visuals,placed_building,craft_station}.gd (W1-BUILD)`; `game/data/{items,recipes}.json`

**Closes:** build-art-01, world-harbour-07

**Acceptance (a reviewer can run or inspect each):**

- tools/blender/structures/check_manifest.py prints PASS: every building kind in props_manifest resolves to an existing GLB.
- Each GLB <= 4k triangles, one atlas material, origin at ground centre, footprint within the manifest AABB +- 5 %.
- Windowed 1600x900 shot of a scripted base (the scratchpad/audit/building/built_base.png set-up) inspected: no flat salmon palette, readable silhouettes, the four drying-rack stages visibly differ; the same in gl_compatibility.
- --lab=build_lab headless still PASS (colliders still match the AABBs).


### Wave 2

After W1 merges, the survivor-v2 branch merges (W2-INT), and the owner answers on the UI pass (W2-HUD, W2-SCREENS).

| Key | Title | Size | Blocker | Depends on |
|---|---|---|---|---|
| W2-INT | Merge wave 1 and the survivor-v2 branch; economy follow-ups | M | other_session | all W1 packages |
| W2-PLAYER | Split player.gd and add PlayerActions; fix grounding, roll, attack and pet interactions | XL | other_session | W2-INT |
| W2-PANIM | Player animation: grounded root motion, layered tree, web-safe clip loading, shared libraries | M | other_session | W2-INT |
| W2-DATA | Item and recipe data: the full material ladder, nets, armor tiers, rare-item gates | L | owner_decision | W2-INT |
| W2-PROCESS | Impactful processing: visible stations, spoilage, queues that keep running | L | owner_decision | W2-INT |
| W2-BUILDSYS | ARK-style modular building with structure HP, tiers and repair | XL | none | W2-INT |
| W2-INV | Inventory and equipment by instance | M | other_session | W2-INT |
| W2-LOOP | Renewable faucet and the harbour as mission and market hub | M | owner_decision | W2-INT |
| W2-TERRAIN | Real terrain: relief, rivers, lakes, coast-side harbour, inland crater, staged build | XL | none | W2-INT |
| W2-SCATTER | Dense, biome-correct vegetation that is never culled near the player | M | none | W2-INT |
| W2-SPAWN | Population director: refill, variety, rings that fit the land | M | none | W2-INT |
| W2-CVIEW | Creature view and body: status overlay, hurt volumes, IK, wired animation API | L | other_session | W2-INT |
| W2-ECO | Ecosystem and species attack kits | XL | none | W2-INT |
| W2-WEATHER | Biome weather that changes light, fog, surfaces and survival | M | none | W2-INT |
| W2-VFX | Fire, impact and world effects, pooled and web-safe | M | none | W2-INT |
| W2-HUD | Split hunt_hud.gd into widgets; settings, notices, radial collision, wallet | XL | owner_decision | W2-INT |
| W2-SCREENS | Inventory, Animals and character screens at ARK depth, with art-overflow item slots | L | owner_decision | W2-INT, W2-INV |
| W2-RERIG | Bespoke rigs and per-species clips for eight transplanted species | XL | credits | W2-INT |
| W2-ARTC | Rest of the roster and a /showcase review scene | L | owner_decision | W2-INT |
| W2-WEB2 | Web delivery: split packs, web render settings, latency headroom | M | none | W2-INT |

#### W2-INT: Merge wave 1 and the survivor-v2 branch; economy follow-ups

**Size** M · **Blocker** other_session · **Depends on** all W1 packages

Merge every W1 package and, with the other session's sign-off, claude/survivor-v2-equip-mount-code-de20f0. Switch the economy AssetValidator to PetStats.compute. Economy follow-ups: buy-order filters (min durability %, forbidden flags defaulting to poisoned), settlement boundary (a bid is valid only if ts < end_ts), two-phase withdraw (reserve, client confirm, timeout back to vault), saddle-with-listed-pet rule, objective rewards bound. Define phys_layers.gd constants. Save on NOTIFICATION_WM_CLOSE_REQUEST and APPLICATION_FOCUS_OUT plus a debounced request_save after build, pack-up and storage moves. --gather-test on a fresh island. Expand the perf overlay. Register every W1 lab in tools/labs.txt.

**Owns:** `game/scripts/core/game.gd`; `game/scripts/core/main.gd`; `game/scripts/core/world.gd`; `game/tests/run_all.gd`; `game/scripts/economy/`; `game/data/economy/`; `game/scripts/core/phys_layers.gd (new)`; `tools/labs.txt`; `docs/orchestration/mmo/contracts.md`

**Must not touch:** `files owned by other W2 packages`; `game/project.godot (W2-WEB2)`

**Closes:** econ-fungibility-01, sec-buyorder-18, sec-time-21, econ-conservation-01, econ-mount-pet-01, econ-account-01, build-save-02, gather-01, perf-overlay-01, phys-layers-01, sec-sybil-02

**Acceptance (a reviewer can run or inspect each):**

- survivor-v2 branch merged; --lab=equip_mount_lab PASS; tools/labs.sh all PASS; SMOKE PASS; [tests] PASS.
- economy_tests: a poisoned stack cannot fill a default order; a 1/82-durability knife is refused by a 50 % min-durability order; a bid at ts == end_ts is rejected; an unconfirmed withdraw returns to the vault after the timeout; AssetValidator accepts 200 honest PetStats pets and rejects one with an edited IV.
- Closing the desktop window writes the save (t check on the WM close notification); --gather-test passes 5 of 5 on a fresh island.


#### W2-PLAYER: Split player.gd and add PlayerActions; fix grounding, roll, attack and pet interactions

**Size** XL · **Blocker** other_session · **Depends on** W2-INT

Split player.gd (2,331 lines) into PlayerSim, PlayerView and PlayerInput plus PlayerActions, the single command layer for gather, loot, craft, place, equip, eat, tame and attack (offline it applies locally exactly as today; the online path is a stub for W3). PlayerRegistry replaces the 36 get_first_node_in_group("player") calls in player-facing code. Ground the survivor-v2 rig on the capsule bottom. Roll cancels attack and hit_react, follows the input vector, buffers 0.2 s, ends busy with the dash and explains refusals. F/left-click swings manually and HOLD still attacks in range; F never targets pets. Pet radial (Ride, Bag, Feed, Orders), feeding any summoned pet, pet hp_now persisted and used on summon, summon positioned before add_child. _unstick takes a collision-tested step and never into a Creature. Corpse radial takes keep leftovers and pay XP once; pet bag dumps keep overflow. Structures' interact() (gate open/close, demolish). Footstep stride signal and an AudioListener3D at head height for audio. Mount speed from pet_record, keeping the other session's howdah path.

**Owns:** `game/scripts/player/player.gd`; `game/scripts/player/player_sim.gd (new)`; `game/scripts/player/player_view.gd (new)`; `game/scripts/player/player_input.gd (new)`; `game/scripts/player/player_actions.gd (new)`; `game/scripts/player/player_equipment.gd`; `game/scripts/core/player_registry.gd (new)`; `game/scripts/core/input_setup.gd`; `game/scripts/combat/hunt.gd`; `game/scenes/player/player.tscn`; `game/scripts/dev/player_lab.gd (new) + scene`; `game/tests/t_player.gd (new)`

**Must not touch:** `game/scripts/player/player_anim.gd and game/scripts/core/rigged_model.gd (W2-PANIM)`; `game/scripts/ui/ (W2-HUD, W2-SCREENS)`; `game/scripts/items/ (W2-PROCESS, W2-INV)`

**Closes:** pc-anim-01, pc-combat-01, pc-combat-04, pc-bug-01, net-single-04, net-split-11, tame-11, tame-13, tame-16, tame-21, sec-xpfarm-07, sec-loss-08, build-storage-01, build-gate-01, build-remove-01, phys-climb-01, phys-spawn-01, phys-wall-01, phys-mount-01, phys-path-01, phys-aoe-01, pc-misc-01, audio-footsteps-08, audio-spatial-12, audio-player-16, gather-01, dino-ai-02, econ-conservation-01

**Acceptance (a reviewer can run or inspect each):**

- wc -l player.gd <= 800 and no new player_*.gd > 600.
- player_lab/t_player: idle lowest bone within 0.05 m of the floor (was 0.95 m above).
- Roll accepted in 20 of 20 tries 0.3 s into an attack; dash direction equals the input vector; busy clears within 0.05 s of the dash end.
- HOLD with a target in range lands >= 1 hit per swing period; F with only a pet nearby starts no hunt.
- A pet dismissed at 40 % HP is summoned back at 40 %; the Bag entry opens a protoceratops's bag; a corpse radial take with a full bag leaves the stack in the corpse.
- Walking into a compsognathus, zebraceratops and velociraptor for 5 s raises the survivor <= 0.15 m (was +0.97, +1.16, +1.82 m); a summon at the island origin produces no velocity above 15 m/s.
- grep -c 'get_first_node_in_group("player")' -r game/scripts <= 3.
- equip_mount_lab, --combat-test, --gather-test, pets_lab and capture_lab PASS; desktop Chrome soak PASS.


#### W2-PANIM: Player animation: grounded root motion, layered tree, web-safe clip loading, shared libraries

**Size** M · **Blocker** other_session · **Depends on** W2-INT

Strip Hips XZ root motion at import (or consume it as movement); an AnimationTree with a locomotion BlendSpace on real speed and an upper-body OneShot for attacks; 0.08-0.15 s crossfades; a get-up after knockdown and the knockdown clip actually playing; locomotion playback speed matched to horizontal speed; attack clips at authored speed (v2 swing 1.21 s); clip discovery that matches .glb.import/.remap entries in exports; a static AnimationLibrary cache per anim_dir; prints behind debug; v1 survivor clip textures dropped if v1 still ships.

**Owns:** `game/scripts/player/player_anim.gd`; `game/scripts/core/rigged_model.gd`; `game/assets/characters/survivor/anim/ (import settings only)`; `game/tests/t_player_anim.gd (new)`

**Must not touch:** `game/scripts/player/player.gd and new player_*.gd (W2-PLAYER)`; `game/scripts/creatures/ (W2-CVIEW)`

**Closes:** pc-anim-02, pc-anim-03, pc-anim-04, pc-combat-03, perf-anim-load-01, perf-spawn-01, perf-survivor-01, perf-log-01

**Acceptance (a reviewer can run or inspect each):**

- During attack_primary and roll the hips stay within 0.15 m of the capsule in XZ (was 1.52 m and 4.45 m).
- A knockdown status plays the knockdown clip and then get-up (was idle with cannot_act).
- Walk and run playback speed equals horizontal speed / natural clip speed within 10 %.
- t_player_anim parses a local web export's pack listing and finds every clip the rig loads on desktop, including survivor sleep, craft, fish_cast, gather_chop, gather_mine, throw_spear and T. rex sleep and tail_swipe (currently missing on web).
- A second velociraptor's RiggedModel.setup <= 2 ms (was 6.2-7.0 ms) and a warm survivor rig <= 20 ms (was ~100 ms).
- No attack clip plays faster than 1.6x.


#### W2-DATA: Item and recipe data: the full material ladder, nets, armor tiers, rare-item gates

**Size** L · **Blocker** owner_decision · **Depends on** W2-INT

Owns items.json, recipes.json, factions.json, climates.json, skills/trees.json and icons_manifest.json for wave 2. Tin ore family and tin; copper, bronze, iron and steel ingots via a fuelled forge station and an anvil bench; named per-tier tools and weapons on every rung; capture nets II-V (and the factions.json ids fixed); steamer_kit and hoe recipes; metal armor tiers with insulation fields and per-tier clothing; market_category and rarity on every item (rarity moved from item_rarity.json); rare-material drops and recipe gates per construction and skill node; repair recipes per tier; one recipe per structures.json piece (W2-BUILDSYS); ingot icons; dead references cleaned; a data validator.

**Owns:** `game/data/items.json`; `game/data/recipes.json`; `game/data/world/factions.json`; `game/data/world/climates.json`; `game/data/skills/trees.json`; `game/data/icons_manifest.json`; `game/data/item_rarity.json`; `game/tests/t_data.gd (new)`

**Must not touch:** `game/data/statuses.json (W2-WEATHER)`; `game/data/world/{missions,market,objectives}.json (W2-LOOP)`; `game/data/structures.json (W2-BUILDSYS)`

**Closes:** ladder-01, equip-01, tame-02, build-kits-01, craft-02, data-01, econ-catalog-01, gather-03, durability-01, build-tier-01, climate-01, test-01

**Acceptance (a reviewer can run or inspect each):**

- t_data: every item id referenced by recipes, factions, rules, statuses and climates exists; every item has market_category and rarity.
- An extended progression probe gathers and crafts one tool per rung stone..steel from data and logs time per rung, with no unreachable rung (bronze and steel were unobtainable).
- Capture nets I-V are craftable and every tameable species has a reachable net tier (8 of 16 were unreachable).
- steamer_kit and hoe are craftable; armor exists in every 5-10 level band from 1 to 60 (was nothing between 1 and 55).
- equip_mount_lab and craft_lab PASS.


#### W2-PROCESS: Impactful processing: visible stations, spoilage, queues that keep running

**Size** L · **Blocker** owner_decision · **Depends on** W2-INT

Owner direction 'processing must feel impactful'. A process-station system (drying rack, smoker, crock pot, steamer, tanning frame): inputs appear on the station, move through visual stages over time (W1-STRUCTART stage models plus material tint), emit smoke or steam, persist their queues in saves and keep running while the player is away. Raw food spoils (spoil timestamp on ItemStack, rules in processing.json) while dried and smoked meat keeps and carries its buff. Crafting quality windows per HANDOFF P3 (skill and material driven, visible odds). Steam stacking capped per the owner's answer. Hand-held tool and weapon sync stays in station_craft.

**Owns:** `game/scripts/items/item_stack.gd`; `game/scripts/items/station_craft.gd`; `game/scripts/items/crafting.gd`; `game/scripts/items/food.gd`; `game/scripts/items/eat_session.gd`; `game/scripts/world/craft_station.gd`; `game/scripts/world/process_station.gd (new)`; `game/data/processing.json (new)`; `game/scripts/dev/process_lab.gd (new) + scene`; `game/scripts/dev/kitchen_lab.gd`; `game/scripts/dev/craft_lab.gd`; `game/tests/t_process.gd (new)`

**Must not touch:** `game/data/{items,recipes}.json (W2-DATA)`; `game/scripts/items/{inventory,item_def}.gd (W2-INV)`; `game/scripts/world/{placed_building,build_grid,build_placer}.gd (W2-BUILDSYS)`

**Closes:** survival-01, food-01, craft-02, craft-03, audio-build-10

**Acceptance (a reviewer can run or inspect each):**

- process_lab windowed: 4 raw strips hung on a drying rack visibly pass through 3 stages over the configured time (screenshots at 0, 50 and 100 % inspected) with smoke while active.
- Save, quit and reload mid-process resumes with the right remaining time; t_process: the queue keeps running with the player 50 m away.
- Raw meat spoils after its spoil time per processing.json while dried_meat in the same bag does not; eating dried_meat applies its buff status.
- kitchen_lab and craft_lab PASS.


#### W2-BUILDSYS: ARK-style modular building with structure HP, tiers and repair

**Size** XL · **Blocker** none · **Depends on** W2-INT

Modular building beside the kit prefabs: StructurePiece with sockets (edge, top, wall slot), occupancy keyed by (cell, level, face), the ghost snapping to the nearest free socket with green and red snap points; foundation, wall, doorway, door, window, ceiling, roof, ramp, stairs, pillar; structural support; multi-storey. StructureHealth on every placed kind (tier HP, resistances, repair cost, saved) with creature damage routed through it. Tiers thatch/wood/stone/metal with upgrade in place and construction-node gating (structures.json). Chests and a large box; a gate/door permission stub (owner id); a structure physics layer so walls block creatures; signs with text; a skirt down to the lowest corner on slopes; save schema 4 for piece rows.

**Owns:** `game/scripts/world/build_grid.gd`; `game/scripts/world/build_placer.gd`; `game/scripts/world/placed_building.gd`; `game/scripts/world/prop_visuals.gd`; `game/scripts/world/tile_path.gd`; `game/scripts/world/field_catapult.gd`; `game/scripts/world/field_plot.gd`; `game/scripts/world/structure_piece.gd (new)`; `game/scripts/world/structure_health.gd (new)`; `game/data/structures.json (new)`; `game/data/props_manifest.json`; `game/scripts/combat/creature_attack.gd`; `game/scripts/core/save_game.gd`; `game/scripts/core/save_migrations.gd`; `game/scripts/dev/build_lab.gd`; `game/scripts/dev/siege_probe.gd`; `game/scripts/dev/snap_build_lab.gd (new) + scene`; `game/tests/t_buildsys.gd (new)`

**Must not touch:** `game/data/{items,recipes}.json (W2-DATA adds the piece recipes)`; `game/scripts/creatures/brains/ (W2-ECO)`; `game/scripts/player/ (W2-PLAYER)`

**Closes:** build-struct-01, build-def-01, build-tier-01, build-storage-01, build-sign-01, build-place-02, phys-wall-01, dino-ai-17

**Acceptance (a reviewer can run or inspect each):**

- snap_build_lab builds a 2-storey 3x3 house (9 foundations, walls with a doorway, ceilings, upper walls, roof) only through BuildPlacer socket snapping, every piece within 1 cm of its socket.
- Removing a supporting wall collapses the unsupported pieces above it.
- Save and load restore every piece (schema 4) and an old schema-3 save migrates.
- A raptor damages a wood wall, the player repairs it at the material cost, and a wood-to-stone upgrade swaps in place.
- A creature cannot path through a closed wall; the owner passes the owned door.
- Windowed screenshots of the house in both renderers inspected; build_lab and the siege probe PASS.


#### W2-INV: Inventory and equipment by instance

**Size** M · **Blocker** other_session · **Depends on** W2-INT

After the survivor-v2 merge: equipment references the exact item (slot index or uid); equipped gear moves into an equipment container out of the 20-slot grid; can_accept(stack) before every consume; negative and zero amounts rejected; the best tool is auto-selected by gather_power; level scaling read only from ItemStack.

**Owns:** `game/scripts/items/inventory.gd`; `game/scripts/items/item_def.gd`; `game/tests/t_inventory.gd (new)`

**Must not touch:** `game/scripts/items/item_stack.gd (W2-PROCESS)`; `game/scripts/ui/inventory_ui.gd (W2-SCREENS)`

**Closes:** equip-02, inv-01, sec-neg-17, tool-01, econ-identity-01, sec-loss-08

**Acceptance (a reviewer can run or inspect each):**

- With raid_helm L1 and L60 in the bag, equipping L60 keeps it equipped after a sort and a save/load.
- remove_at(i, -100) and consume(id, 0) return null/false and change nothing.
- Equipped items no longer occupy the 20 bag slots; with nothing equipped a flint pick is chosen over a stone pick.
- equip_mount_lab PASS.


#### W2-LOOP: Renewable faucet and the harbour as mission and market hub

**Size** M · **Blocker** owner_decision · **Depends on** W2-INT

missions.json wired as a mission board (faction missions with T-stone rewards, daily rotation) that fires on observed state; objectives fire on observed state too; market.json categories aligned with items; harbour.gd uses the pier model and opens missions (and the Exchange in W3).

**Owns:** `game/scripts/core/objectives.gd`; `game/scripts/world/missions.gd (new)`; `game/scripts/world/harbour.gd`; `game/scripts/ui/world_ui.gd`; `game/data/world/missions.json`; `game/data/world/market.json`; `game/data/world/objectives.json`; `game/tests/t_missions.gd (new)`

**Must not touch:** `game/data/items.json (W2-DATA)`; `game/scripts/core/world.gd (W2-INT)`

**Closes:** econ-faucet-01, world-harbour-07, econ-catalog-01

**Acceptance (a reviewer can run or inspect each):**

- A 2-hour bot run earns >= 3 T-stones per 10 minutes after the objectives run out (was 0) and never soft-locks sailing.
- t_missions: a completed mission pays once; the rotation is deterministic for a day seed.
- The harbour shows the pier model (screenshot inspected); every market.json category matches at least one items.json category.


#### W2-TERRAIN: Real terrain: relief, rivers, lakes, coast-side harbour, inland crater, staged build

**Size** XL · **Blocker** none · **Depends on** W2-INT

island_terrain.gd and island_runtime orchestration: per-climate height recipes (ridged mountains and plateaus, a volcano cone and caldera, dunes, basins), per-island seeds, 1-2 m cells in chunks, cliffs or triplanar rock so ROCK tiles appear; spline rivers from inland sources plus lakes and marsh pools with their own water; ocean waves and sun glint in water.gdshader and an ocean to the horizon; BiomeMaterial hooked in; harbour and camp on the real coast; the crater inland as a real bowl; no navmesh bake when TilePath is used; a staged build that yields behind the fade; wet state from tile sampling; world-gen tests.

**Owns:** `game/scripts/world/island_terrain.gd`; `game/scripts/world/island_runtime.gd`; `game/scripts/world/water.gdshader`; `game/scripts/world/terrain_tiles.gdshader`; `game/scripts/world/biome_material.gd`; `game/scripts/world/climate_palette.gd`; `game/data/world/biomes.json`; `game/scripts/dev/island_lab.gd`; `game/tests/t_worldgen.gd (new)`

**Must not touch:** `game/scripts/world/island_scatter.gd (W2-SCATTER)`; `game/scripts/world/island_spawns.gd (W2-SPAWN)`; `game/scripts/world/{world_lighting,world_weather}.gd (W2-WEATHER)`

**Closes:** world-terrain-02, world-water-05, world-poi-06, world-harbour-07, world-wet-14, world-build-15, world-ocean-17, world-data-18, perf-nav-01, perf-load-01, lv-water-14, world-biome-01

**Acceptance (a reviewer can run or inspect each):**

- t_worldgen builds every island id: land relief >= 25 m on mountain climates and >= 8 m elsewhere (was ~3.7 m); >= 8 distinct heightmap hashes across the 14 unstable islands (was 4).
- Harbour within 10 m of the waterline (was 171-187 m inland); crater centre inside 0.7 x land radius (was on the beach); no water-role node above sea level; ROCK tiles > 0 on mountain climates.
- No single build frame > 250 ms (was one 1.9 s block) and no navmesh-bake warning in the log.
- Gameplay-camera and eye-level screenshots of desert, tundra, volcanic and swamp inspected; island_lab and smoke PASS.


#### W2-SCATTER: Dense, biome-correct vegetation that is never culled near the player

**Size** M · **Blocker** none · **Depends on** W2-INT

island_scatter.gd: ground cover in 32 m chunks with their own visibility range (fixes the 48 m-from-island-centre cull), density scaled by land area, climate ground-cover lists and foliage tint from biomes.json, lilypads only on shallow water, a palm allowlist, special tiles gated by climate materials, terrain-pick multipliers that change trees, rocks and water, harvest-node cells reserved, decor and tree-disc ranges chunked.

**Owns:** `game/scripts/world/island_scatter.gd`; `game/data/nature_manifest.json`; `game/scripts/world/foliage_sway.gdshader`; `game/scripts/world/veg_batch.gd`; `game/tests/t_scatter.gd (new)`

**Must not touch:** `game/scripts/world/island_terrain.gd and island_runtime.gd (W2-TERRAIN)`; `game/scripts/world/build_grid.gd (W2-BUILDSYS: use its reserve API)`

**Closes:** world-veg-03, world-placement-08, world-terrainpick-10, perf-range-01, build-place-02, world-biome-01

**Acceptance (a reviewer can run or inspect each):**

- temperate_25, survivor 104 m from centre: >= 150 visible grass instances within 25 m (was 3).
- swamp_55: 0 lilypads on dry tiles (was 24); desert: 0 palms unless allowlisted (was 36).
- Home terrain picks differ by >= 30 % in tree count (forest vs rocky) and rock count (rocky vs forest) (were identical).
- A build ghost on a harvest-node cell is rejected; visible primitives at camp stay within the W1-WEB budget (<= 900k).


#### W2-SPAWN: Population director: refill, variety, rings that fit the land

**Size** M · **Blocker** none · **Depends on** W2-INT

island_spawns.gd plus a PopulationDirector: per-ring target counts per species, refills every ~20 s out of sight (> 40 m from any player) with a per-instance seed, platform and ring caps, roam goals between points of interest scaled by archetype, ring radii as fractions of land radius measured from the harbour, apex and crater in the far quadrant, brachiosaurus in a crater or far-shore table, and an interim refusal (logged) of species with no GLB.

**Owns:** `game/scripts/world/island_spawns.gd`; `game/scripts/world/population_director.gd (new)`; `game/scripts/world/spawner.gd`; `game/data/world/rules.json`; `game/data/world/islands.json`; `game/data/islands/`; `game/tests/t_spawn.gd (new)`

**Must not touch:** `game/scripts/creatures/ (W2-CVIEW, W2-ECO)`; `game/scripts/world/island_runtime.gd (W2-TERRAIN)`

**Closes:** dino-ai-09, world-rings-13, dino-ai-20, dino-ai-10, world-poi-06

**Acceptance (a reviewer can run or inspect each):**

- After 6 kills on temperate_25 the population is back to target within 60 s and no spawn lands within 40 m of the survivor (kills were never refilled).
- Two instances of the same unstable island place creatures differently.
- The far_shore ring holds >= 1 creature on islands that define it (was 0); brachiosaurus spawns once its GLB exists; the AI sweep lab still PASS.


#### W2-CVIEW: Creature view and body: status overlay, hurt volumes, IK, wired animation API

**Size** L · **Blocker** other_session · **Depends on** W2-INT

creature.gd, creature_view.gd and corpse.gd after the survivor-v2 merge: a material_overlay shader on GLB meshes for hit flash, venom/enraged tint, bleed darken and death grey; wire set_move_speed and set_time_scale (stride, limp); receive_creature_hit only on landed hits; hurt volumes on head, body and tail bones and a body-fitted movement collider; species turn rates; foot IK and head look-at (SkeletonModifier3D); a four-legged procedural fallback with an attached head; remove the stale Stegosaurus override if the other session's v2 has not; variant scale and tint from data; creature visibility range ~80 m; a body-shaped corpse collider on a corpse layer; pooled blood quads; coloured drip particles.

**Owns:** `game/scripts/creatures/creature.gd`; `game/scripts/creatures/creature_view.gd`; `game/scripts/creatures/corpse.gd`; `game/scripts/creatures/creature_anim.gd`; `game/scenes/creatures/creature.tscn`; `game/scripts/creatures/creature_overlay.gdshader (new)`; `game/tests/t_creature_view.gd (new)`

**Must not touch:** `game/scripts/creatures/brains/ (W2-ECO)`; `game/assets/creatures/ (W2-RERIG, W2-ARTC)`

**Closes:** dino-art-09, dino-art-02, dino-art-14, dino-art-04, phys-body-01, phys-turn-01, phys-mount-01, pc-hitreact-02, tame-20, dino-art-16, perf-range-01, lv-particle-color-05, phys-layers-01

**Acceptance (a reviewer can run or inspect each):**

- Flash and tint visible on a velociraptor GLB: windowed screenshot pair with mean colour shift >= 0.1 in the flashed frame.
- A bite at the T. rex head (9.7 m forward) registers on the head hurt volume and a hit at the old hip centre does not; the survivor cannot stand inside the jaw (>= 0.3 m from the head volume).
- A fractured creature's ground speed is 0.65x; in-game stride ratio in [0.75, 1.30]; the stegosaurus renders its GLB in game; missed attacks play no hit_react.


#### W2-ECO: Ecosystem and species attack kits

**Size** XL · **Blocker** none · **Depends on** W2-INT

In the brains and ai.json: diet and prey size, a hunger meter for wild animals with eat_corpse/graze/drink states, scavengers to carcasses, territory with warning alerts, predator-prey between wild species, schedules (diurnal, nocturnal), one cached sight ray plus a hearing radius, per-species attack tables (Dilophosaurus spit projectile, ceratopsian charge, stego/ankylo tail sweep, raptor lunge, roar), tyrant brain by archetype (Tarbosaurus), Allosaurus its own archetype, pet stances (passive, defend, attack; stay, follow), predators repositioning, structure targeting only if the owner says yes.

**Owns:** `game/scripts/creatures/brains/`; `game/data/creatures/ai.json`; `game/scripts/creatures/creature_def.gd`; `game/scripts/creatures/spit_projectile.gd (new)`; `game/scripts/dev/wild_ai_sweep_lab.gd`; `game/scripts/dev/eco_lab.gd (new) + scene`

**Must not touch:** `game/scripts/creatures/creature.gd and corpse.gd (W2-CVIEW)`; `game/scripts/combat/creature_attack.gd (W2-BUILDSYS)`

**Closes:** dino-ai-03, dino-ai-07, dino-ai-08, dino-ai-16, dino-ai-17, pc-ai-01, tame-19

**Acceptance (a reviewer can run or inspect each):**

- eco_lab: a hungry velociraptor attacks a protoceratops within 20 s (prey_hp_lost > 0; was 0); compys reach a fresh carcass within 30 s; thirsty herbivores drink at water tiles.
- A Dilophosaurus spits from >= 6 m and the spit can be dodged; a triceratops charge knocks back; a survivor behind a 6 m wall 9 m away is not detected in daylight (was detected).
- Nocturnal species roam at night; the AI sweep still PASS; the 120-creature physics budget from W1-AI rises by no more than 15 %.


#### W2-WEATHER: Biome weather that changes light, fog, surfaces and survival

**Size** M · **Blocker** none · **Depends on** W2-INT

world_weather.gd with world_lighting.gd: weather states weighted from climates.json (weather.json), 20-60 s blends driving sun, ambient, fog, cloud-shadow strength and terrain wetness; rain streaks, snow, sand and ash particles; a shelter check under roofs; weather statuses (wet, chilled, scorched, sandblind) feeding climate fatigue; a weather seed the server will own.

**Owns:** `game/scripts/world/world_weather.gd`; `game/scripts/world/world_lighting.gd`; `game/data/world/lighting.json`; `game/data/world/weather.json (new)`; `game/data/statuses.json`; `game/scripts/dev/weather_lab.gd (new) + scene`

**Must not touch:** `game/data/world/climates.json (W2-DATA; read only)`; `game/scripts/world/island_runtime.gd (W2-TERRAIN)`

**Closes:** lv-weather-03, world-weather-09, climate-01, lv-rain-rules-19, audio-weather-19, lv-climate-12, data-01

**Acceptance (a reviewer can run or inspect each):**

- weather_lab: desert never rains, tundra snows, volcanic gets ash storms (rain fell on every climate).
- A state change blends over >= 20 s with a monotone sun-energy curve; wet is not applied under a placed roof.
- Snow particles read white and rain streaks blue-grey (pixel check); per-state screenshots inspected in gl_compatibility.


#### W2-VFX: Fire, impact and world effects, pooled and web-safe

**Size** M · **Blocker** none · **Depends on** W2-INT

A pooled VfxLibrary (wood chips, stone sparks, dust, splash, blood spray, projectile trails, level-up); flame, embers and smoke on campfire, bonfire and fire pit with the light fading with night instead of popping, glow-enabled emissive flame; telegraph and blood decals replaced by terrain quads; a shader warm-up behind the loader; no per-hit material allocation; shadows from the nearest fires on desktop only.

**Owns:** `game/scripts/world/vfx_library.gd (new)`; `game/scripts/world/bonfire.gd`; `game/scripts/combat/stone_projectile.gd`; `game/scripts/combat/siege_projectile.gd`; `game/scripts/combat/telegraph.gd`; `game/scripts/world/dirt_disc.gdshader`; `game/scripts/dev/vfx_lab.gd (new) + scene`

**Must not touch:** `game/scripts/creatures/creature.gd (W2-CVIEW)`; `game/scripts/combat/hunt.gd (W2-PLAYER)`

**Closes:** lv-fire-07, lv-vfx-09, lv-decal-10, lv-hitch-15, lv-local-shadows-20, perf-fx-01, perf-decal-01

**Acceptance (a reviewer can run or inspect each):**

- vfx_lab: the bonfire shows flame and smoke by day and night (screenshots inspected); fire light energy changes continuously between 17:00 and 19:00 with no step > 10 % (it popped at 17:17).
- 200 hits allocate 0 new materials after warm-up (pool counters).
- After warm-up, no effect's first appearance causes a frame > 100 ms in gl_compatibility; projectiles leave a trail.


#### W2-HUD: Split hunt_hud.gd into widgets; settings, notices, radial collision, wallet

**Size** XL · **Blocker** owner_decision · **Depends on** W2-INT

hunt_hud.gd (1,376 lines, hand-drawn) split into Control widgets under game/scripts/ui/hud/ (VitalsPanel, OrdersCard, Minimap, ActionRail, StatusTray, NoticeStack, ModalHost). Radial avoids HUD rects; notice kinds (info, success, warn, error); status icons with timers; a wallet chip; key and pad hints; a settings screen (Master, Music, Ambience, Effects, UI sliders, mute, mute in background) on the audio package's Settings store; the BUILD sheet as a kit catalog with costs and lock state; pack-up and demolish hexes; a credits row; death-screen respawn options; the combat ability arc; damage-float lanes; the player nameplate in label layout; display names from data; HUD redraw throttled; emoji replaced; the taming plate with progress and window rings.

**Owns:** `game/scripts/ui/hunt_hud.gd`; `game/scripts/ui/hud/ (new)`; `game/scripts/ui/settings_screen.gd (new)`; `game/scripts/ui/context_radial.gd`; `game/scripts/ui/creature_plates.gd`; `game/scripts/ui/hud_event_state.gd`; `game/scripts/ui/pickup_toast.gd`; `game/scripts/dev/ui_real_capture_lab.gd`

**Must not touch:** `game/scripts/ui/{inventory_ui,animal_screen,item_icons,character_creation}.gd (W2-SCREENS)`; `game/scripts/player/ (W2-PLAYER)`

**Closes:** ui-radial-01, ui-settings-01, audio-settings-06, ui-notice-01, ui-status-01, ui-modal-01, ui-labels-01, ui-combat-01, ui-hud-01, ui-death-01, ui-level-01, ui-glyph-01, pc-ui-01, econ-hud-wallet-01, build-ux-01, build-remove-01, tame-17, ui-taming-01, perf-hud-01, audio-licence-20

**Acceptance (a reviewer can run or inspect each):**

- wc -l hunt_hud.gd <= 400.
- ui_real_capture_lab at 1600x900 and 390x844 asserts that no radial hex or world label intersects a HUD widget rect and that every modal hides the HUD; screenshots inspected.
- Settings sliders change AudioServer bus volume and persist across a restart.
- Notices are colour-coded by kind; idle HUD redraws <= 10 Hz (counter); desktop Chrome soak PASS.


#### W2-SCREENS: Inventory, Animals and character screens at ARK depth, with art-overflow item slots

**Size** L · **Blocker** owner_decision · **Depends on** W2-INT, W2-INV

inventory_ui.gd, animal_screen.gd, item_icons.gd and character_creation.gd. Animals screen backdrop sized with set_anchors_and_offsets_preset, a 3D creature preview, stat bars with IV, growth and EV, allocation '+', owner/tamer/uid, rename, store-as-item; the duplicate pets sheet removed. Inventory with ArtSlot art-overflow cells, names, rarity rims, durability bars, level badges, drag and drop with long-press split, sort and search, a stat card replacing tooltip(), equipment silhouettes and a 3D survivor preview. A PetCard shared with the Exchange. Character creation with the survivor-v2 preview. Stable test hooks (debug_state()).

**Owns:** `game/scripts/ui/inventory_ui.gd`; `game/scripts/ui/animal_screen.gd`; `game/scripts/ui/item_icons.gd`; `game/scripts/ui/character_creation.gd`; `game/scripts/ui/pet_card.gd (new)`; `game/scripts/dev/ui_family_lab.gd`

**Must not touch:** `game/scripts/ui/hunt_hud.gd and ui/hud/ (W2-HUD)`; `game/scripts/items/inventory.gd (W2-INV)`

**Closes:** tame-12, ui-animals-01, ui-inventory-01, inv-02, tame-09, econ-inspect-01, dino-art-17, ui-charcreate-01, qa-uifamily-01, tame-19, ui-gamepad-01

**Acceptance (a reviewer can run or inspect each):**

- ui_family_lab through debug_state(): the Animals backdrop rect equals the viewport rect at 1600x900 and 390x844 (was 0x0).
- An allocation '+' raises the pet stat in PetStats; drag and drop moves a stack with units conserved; inventory cells show names and rarity rims.
- Real-scene screenshots at 1600x900 and 390x844 inspected: item art overflows its slot (owner direction), nothing overlaps the HUD.


#### W2-RERIG: Bespoke rigs and per-species clips for eight transplanted species

**Size** XL · **Blocker** credits · **Depends on** W2-INT

Bespoke skeletons per body plan (small and large theropod, ceratopsian, cervid) on the T. rex layout, built by dsc in headless Blender; re-weight with the jaw/skull split; per-species clips (bite, claw, charge, antler sweep with anticipation, roar with open jaw, side-lying knockdown with a breathing loop, death on the side, sleep, eat/graze, turn in place); the rig-audit gate at <= 3x edge ratio; pale-albedo fixes judged under the new lighting; Deinonychus regenerated on Tripo (cap 80 credits, approved); black emission maps and orphan textures removed; the T. rex clip build scripts committed under tools/trex/.

**Owns:** `game/assets/creatures/{velociraptor,utahraptor,compsognathus,coelophysis,gallimimus,deinonychus,protoceratops,megaloceros}/`; `game/data/creatures/{velociraptor,utahraptor,compsognathus,coelophysis,gallimimus,deinonychus,protoceratops,megaloceros}.json`; `tools/transplant_rig.py`; `tools/check_rig_audit.py`; `tools/audit_creature_deformation.py`; `tools/rig_audit_after.json`; `tools/trex/ (new)`; `game/assets/creatures/tyrannosaurus/work/REPORT.md`

**Must not touch:** `game/assets/creatures/{stegosaurus,tyrannosaurus,zebraceratops,brachiosaurus}/ (other session, W2-ARTC)`; `game/scripts/creatures/ (W2-CVIEW, W2-ECO)`

**Closes:** dino-art-03, dino-art-06, dino-art-07, dino-art-08, dino-art-10, dino-art-15, dino-art-19, dino-art-20, perf-mesh-01

**Acceptance (a reviewer can run or inspect each):**

- Every re-rigged species has Jaw, >= 2 neck and >= 5 tail bones; check_rig_audit.py fails above 3.0 and passes on all of them.
- No two species share every clip duration (all 6 bipeds did); knockdown end pose is side-lying (spine roll 80-100 deg) with no legs-up pose.
- RIG IMPORT PASS; studio lab screenshots inspected; Deinonychus is a multiview mesh of 16k-20k tris and its spend <= 80 credits.


#### W2-ARTC: Rest of the roster and a /showcase review scene

**Size** L · **Blocker** owner_decision · **Depends on** W2-INT

Brachiosaurus on Tripo (cap 120 credits); the Zebraceratops replacement or redesign per the owner's answer (the swap in spawn tables goes to W2-SPAWN through the report); a check that the other session's Stegosaurus v2 shows in game; a manifest-driven /showcase scene per GAUNTLET:139 (per-clip play, pause, restart, loop, 0.25x/0.5x/1x, scrub, orbit, zoom, neutral light, grid, optional skeleton).

**Owns:** `game/assets/creatures/brachiosaurus/ (new)`; `game/assets/creatures/zebraceratops/ (or its replacement id)`; `game/data/creatures/brachiosaurus.json`; `game/data/creatures/zebraceratops.json`; `game/scripts/dev/showcase.gd (new) + scene`; `assets/concept-art/INDEX.md`

**Must not touch:** `game/data/islands/ and game/data/world/islands.json (W2-SPAWN)`; `game/assets/creatures/stegosaurus/ (other session)`

**Closes:** dino-art-12, dino-art-01, dino-art-17, dino-art-02

**Acceptance (a reviewer can run or inspect each):**

- Brachiosaurus passes the W1-ARTA asset checks with spend <= 120 credits.
- The Zebraceratops answer is implemented with no Durango reference left in its art_direction.json.
- /showcase plays every clip of every GLB species from the creature JSON clip lists at 0.25x/0.5x/1x with scrub; screenshots inspected.


#### W2-WEB2: Web delivery: split packs, web render settings, latency headroom

**Size** M · **Blocker** none · **Depends on** W2-INT

project.godot web settings (directional shadow size.web 2048, soft shadow quality web 0, MSAA 2x on web, audio output_latency.web ~100 ms, physics layer names from phys_layers.gd); a core pack plus per-island packs loaded on demand with ProjectSettings.load_resource_pack and per-pack content hashes; threaded main.tscn load where available; COOP/COEP threads only if the owner agrees.

**Owns:** `game/project.godot`; `game/export_presets.cfg`; `game/shell/boot.gd`; `game/shell/shell_loader.gd`; `tools/web_pack_for_vercel.py`; `tools/export_web.sh`; `hosting/web/vercel.json`

**Must not touch:** `game/scripts/core/{game,world,main}.gd (W2-INT)`

**Closes:** perf-payload-01, perf-shadow-01, perf-load-01, lv-post-08, audio-web-14, phys-layers-01

**Acceptance (a reviewer can run or inspect each):**

- First play downloads <= 60 MB (core pack plus home island); travelling to an unstable island downloads only its pack.
- A redeploy that changes one island re-downloads only that pack (other pack hashes unchanged).
- Desktop Chrome production soak PASS with the expected stamp; a web edge crop shows MSAA (inspected).


### Wave 3

The MMO core: server-simulated islands, intents end to end, the Exchange and social UI.

| Key | Title | Size | Blocker | Depends on |
|---|---|---|---|---|
| W3-SRVWORLD | Server-simulated islands with interest-managed replication | XL | none | W2-PLAYER, W2-INT |
| W3-SRVACT | Intents end to end: PlayerActions online path onto the server character | XL | none | W2-PLAYER, W2-INT |
| W3-EXCHANGE | The Exchange: browse, list, bid, buy orders and dinosaur listings | L | none | W2-HUD, W2-SCREENS |
| W3-SOCIAL | Chat, presence, parties and face-to-face trade | L | none | W2-HUD |
| W3-NETQA | Multi-client test harness and load soak | M | none | W2-INT |
| W3-NATUREART | One art style for rocks and plants | M | none | W2-SCATTER |

#### W3-SRVWORLD: Server-simulated islands with interest-managed replication

**Size** XL · **Blocker** none · **Depends on** W2-PLAYER, W2-INT

Contract v2 points 2 and 4: the server runs IslandRuntime, HarvestNode pools, creatures and brains, corpses and structures headless (Game.is_server guards skip views, UI, autosave and shell); 10 Hz world snapshots with an 80 m interest radius and 48/60 m enter/leave hysteresis; a client replica renderer for creatures, corpses, nodes and structures; deterministic node-id diffs on join; a TargetIndex over all registered players and pets in the brains; on_player_killed scoped to the victim; server clock, day phase and weather broadcast; timers as server deadlines; AI dormant beyond 80 m of any player; cheap lanterns on remote players; one process per island instance.

**Owns:** `game/scripts/net/world_snapshot.gd (new)`; `game/scripts/net/replica_*.gd (new)`; `game/scripts/net/remote_puppet.gd`; `game/scripts/net/remote_players.gd`; `game/scripts/core/world.gd`; `game/scripts/core/game.gd`; `game/scripts/core/main.gd`; `game/scripts/world/island_runtime.gd and island_*.gd (server guards)`; `game/scripts/creatures/creature.gd`; `game/scripts/creatures/creature_view.gd`; `game/scripts/creatures/brains/creature_brain.gd`

**Must not touch:** `game/scripts/player/player_actions.gd and game/scripts/server/ (W3-SRVACT)`; `game/scripts/ui/market/ (W3-EXCHANGE)`

**Closes:** net-core-01, net-auth-02, dino-ai-02, net-single-04, world-mmo-state-11, lv-mmo-sync-04, net-timers-12, net-interest-13, net-headless-cost-10, net-web-caveats-15, lv-light-budget-16, lv-daylen-21, sec-move-10

**Acceptance (a reviewer can run or inspect each):**

- net_lab (W3-NETQA) with a server and 2 headless clients on one island: creature positions agree within 0.5 m at 10 Hz; a node gathered by client A shows depleted for client B within 200 ms; time_of_day agrees within 1 s.
- Server tick <= 16 ms headless with 2 clients and 24 creatures; idle snapshot traffic <= 8 KB/s per client.
- Offline single player unchanged: tools/labs.sh all PASS and SMOKE PASS.


#### W3-SRVACT: Intents end to end: PlayerActions online path onto the server character

**Size** XL · **Blocker** none · **Depends on** W2-PLAYER, W2-INT

PlayerActions' online path sends act.* ops; the server runs the W1-SRVDOM handlers on the server-side character against the live island (WorldFacade implemented on W3-SRVWORLD's runtime; built in parallel against the facade interface); char_delta events overwrite the client cache; vault deposits take a server bag slot or pet uid only; pets are server-owned with uids; server taming and combat use the server RNG; one World.earn/spend path for T-stones; objective rewards on server-observed state; structures server-owned.

**Owns:** `game/scripts/player/player_actions.gd`; `game/scripts/server/`; `game/scripts/net/server_actions.gd (new)`; `game/scripts/net/char_sync.gd (new)`; `game/scripts/core/objectives.gd`

**Must not touch:** `game/scripts/net/replica_*.gd and world_snapshot.gd (W3-SRVWORLD)`; `game/scripts/economy/ except calls`

**Closes:** mmo-02, sec-mint-01, econ-supply-trust-01, econ-dupe-01, sec-pets-03, tame-06, pc-mmo-01, phys-net-01, sec-gather-11, sec-wallet-14, build-mmo-01, net-econ-03, net-auth-02, econ-dino-01

**Acceptance (a reviewer can run or inspect each):**

- net_lab: a client that edits its local bag (+500 wood) and crafts gets insufficient_items and its cache is overwritten by the server copy.
- gather, craft, loot and tame produce server uids with origin; a withdraw, client crash and reconnect never duplicates (economy invariants hold over a 1-hour bot soak).
- No client API accepts an item or pet dict for deposit (only slot indexes and uids); online combat damage is computed on the server (no client randf in the online path).


#### W3-EXCHANGE: The Exchange: browse, list, bid, buy orders and dinosaur listings

**Size** L · **Blocker** none · **Depends on** W2-HUD, W2-SCREENS

Market screens under game/scripts/ui/market/: browse, search, filter and sort; item detail with best ask/bid, last price, volume and hourly OHLC; list fixed price, list auction (duration, reserve, buyout), place and cancel buy orders, instant sell to the best order; my listings, bids, orders and escrow; dinosaur listing cards (PetCard with genetics, grade, level, owner, lineage); Settlers labelled; pending, confirmed and failed states with the server's error text; vault and market mutations only at the harbour; opened from the harbour and a HUD slot.

**Owns:** `game/scripts/ui/market/ (new)`; `game/scripts/dev/market_lab.gd (new) + scene`; `game/scripts/world/harbour.gd (open hook)`

**Must not touch:** `game/scripts/ui/hunt_hud.gd beyond the HUD slot API`; `game/scripts/economy/`

**Closes:** econ-market-01, ui-mmo-01, econ-inspect-01, econ-vault-location-01, net-econ-03, econ-supply-trust-01

**Acceptance (a reviewer can run or inspect each):**

- market_lab at 1600x900 and 390x844 (screenshots inspected): browse, search, filter and sort 200 listings at >= 55 fps; list fixed, list auction, place a buy order, cancel each.
- An outbid event updates the UI within 1 s; Settlers orders carry their badge; a failed op shows the server error text; a vault mutation away from the harbour is refused.
- Two real clients on a local server: A lists a dried_meat stack, B buys it, and wallets and vaults satisfy the economy invariants afterwards.


#### W3-SOCIAL: Chat, presence, parties and face-to-face trade

**Size** L · **Blocker** none · **Depends on** W2-HUD

Chat panel (island, party, whisper) above the hex rail, online indicator and player nameplates, a party/tribe panel, inbox notifications with sounds (market_sold, outbid, order_filled, trade_request), a two-party trade window (both escrow, both confirm, atomic settle), block and report, NPC badge.

**Owns:** `game/scripts/ui/social/ (new)`; `game/scripts/net/server_social.gd (new)`; `game/scripts/dev/social_lab.gd (new) + scene`

**Must not touch:** `game/scripts/net/net_server.gd beyond register_op calls`; `game/scripts/ui/market/ (W3-EXCHANGE)`

**Closes:** ui-mmo-01, econ-direct-trade-01, audio-mmo-15, sec-names-24

**Acceptance (a reviewer can run or inspect each):**

- social_lab with 2 clients: a chat line arrives within 300 ms and a blocked player's lines never show.
- A face-to-face trade settles atomically: cancelling at either confirm step leaves both sides unchanged; invariants hold.
- Notification sounds fire at most once per 2 s per type.


#### W3-NETQA: Multi-client test harness and load soak

**Size** M · **Blocker** none · **Depends on** W2-INT

net_lab (server plus N headless clients via OS.create_process) asserting replica agreement, damage applied once, no duplication across disconnect and reconnect, rid replay idempotence; a 50-100 bot-client soak logging server tick ms and bytes per client; both in CI.

**Owns:** `game/scripts/dev/net_lab.gd (new) + scene`; `game/scripts/dev/bot_net_client.gd (new)`; `game/tests/t_net_world.gd (new)`; `tools/net_soak.sh (new)`

**Must not touch:** `game/scripts/net/ (W3-SRVWORLD)`; `game/scripts/server/ (W3-SRVACT)`

**Closes:** qa-mmo-01, net-tests-16

**Acceptance (a reviewer can run or inspect each):**

- net_lab prints PASS with 2 and with 8 clients; a forced disconnect during escrow never duplicates an asset.
- net_soak with 50 bots for 30 min: server tick p95 <= 25 ms and no invariant violation; results attached to the report.


#### W3-NATUREART: One art style for rocks and plants

**Size** M · **Blocker** none · **Depends on** W2-SCATTER

Rebuild the Quaternius-only nature families (Rock, Rock_Moss, Rock_Snow, Plant, Lilypad, snow and dead trees) in the generated style with headless Blender scripts (or Blender MCP when the lock is free), within the W1-WEB texture budget.

**Owns:** `game/assets/nature/ (replaced families)`; `game/data/nature_manifest.json`; `tools/blender/nature/ (new)`

**Must not touch:** `game/scripts/world/island_scatter.gd`

**Closes:** world-artstyle-16

**Acceptance (a reviewer can run or inspect each):**

- No manifest family still points at a Quaternius-only model; eye-level and gameplay screenshots of temperate_25 and tundra_30 inspected show one style; payload stays under the W1-WEB ceiling.


### Wave 4

Needs owner decisions or a host.

| Key | Title | Size | Blocker | Depends on |
|---|---|---|---|---|
| W4-HOST | Public hosting, real accounts, durable ledger, admin tools | XL | hosting | W3-SRVACT, W3-SRVWORLD |
| W4-TAMING | Taming depth and breeding (owner decision) | XL | owner_decision | W3-SRVACT |
| W4-ECONH | Economy hardening and policy (owner decision) | M | owner_decision | W3-EXCHANGE |
| W4-WORLD | World topology, traversal and the combat model (owner decision) | XL | owner_decision | W3-SRVWORLD |

#### W4-HOST: Public hosting, real accounts, durable ledger, admin tools

**Size** XL · **Blocker** hosting · **Depends on** W3-SRVACT, W3-SRVWORLD

After the owner picks a host: TLS reverse proxy (wss only in release clients), process supervisor and health endpoint, a dedicated-server export deploy, Postgres for ledger, journal and character store (one transaction per op, rid unique index), rotating backups, admin ops (freeze, claw back, revert to seq) on a separate auth role, verified login (owner's providers), account creation limits per IP and device, metrics (tick ms, peers, snapshot bytes).

**Owns:** `hosting/server/ (new)`; `game/scripts/server/persistence_pg.gd (new)`; `game/scripts/net/admin_ops.gd (new)`; `tools/deploy_server.sh (new)`

**Must not touch:** `client gameplay code`

**Closes:** net-hosting-07, net-auth-08, net-persist-05, net-ledger-durability-14, econ-persistence-01, sec-admin-13, sec-sybil-02, econ-account-01, sec-replay-09, build-mmo-01, net-econ-03

**Acceptance (a reviewer can run or inspect each):**

- A desktop Chrome client connects over wss to the hosted server and plays a session; kill -9 of the server process loses no acknowledged op (journal or Postgres replay test).
- A restore from last night's backup reproduces the canonical state hash; an admin claw-back of a duplicated uid is journaled and visible in both affected accounts.


#### W4-TAMING: Taming depth and breeding (owner decision)

**Size** XL · **Blocker** owner_decision · **Depends on** W3-SRVACT

If the owner overrides PRD:747: a torpor meter separate from HP with narcotics, per-species food tables and timed feeding with taming effectiveness and bonus levels, tame methods per species; breeding with sexes, mating, eggs with incubation bands or gestation, inheritance weighted to the better parent, mutations with counters, colour regions (region-mask shader, inherited, mutable), baby/juvenile/adolescent growth with imprinting care; pet death and roster caps as sinks; all timers on the server clock; lineage in the market PetCard.

**Owns:** `game/scripts/pets/`; `game/scripts/creatures/creature_genetics.gd`; `game/scripts/server/breeding.gd (new)`; `game/scripts/creatures/region_tint.gdshader (new)`

**Must not touch:** `game/scripts/economy/ (contract change through the orchestrator)`

**Closes:** tame-01, dino-art-11, dino-art-16, tame-08, tame-14

**Acceptance (a reviewer can run or inspect each):**

- Two bonded opposite-sex velociraptors produce an egg; the hatchling's IVs each come from a parent with the better one chosen >= 55 % of the time over 1,000 seeded breeds; mutation rate matches the configured value +- 1 %; colour regions render on the GLB (screenshot) and appear in market listings.


#### W4-ECONH: Economy hardening and policy (owner decision)

**Size** M · **Blocker** owner_decision · **Depends on** W3-EXCHANGE

Buy-order placement fee and cancel cooldown, listing price bands against the reference price, per-def listing-share caps, anomaly alerts, auction soft close (extend while bids arrive, hard stop end + 2 h), linked-account checks for shill bids and funnels, regional Settlers orders filled only at their harbour, land-claim rules (expansion cost, tax, decay) as the owner sets them.

**Owns:** `game/scripts/economy/`; `game/data/economy/`

**Must not touch:** `game/scripts/ui/market/`

**Closes:** econ-settlers-01, econ-manipulation-01, sec-auction-12, build-claim-01

**Acceptance (a reviewer can run or inspect each):**

- economy_tests: a listing outside the band is held; 20 orders placed and cancelled cost the configured fees; an auction with bids every 50 s for 3 h ends at end + 2 h; a regional Settlers order cannot be filled from another region.


#### W4-WORLD: World topology, traversal and the combat model (owner decision)

**Size** XL · **Blocker** owner_decision · **Depends on** W3-SRVWORLD

Per the owner's answers: shared zone maps streamed in chunks or island shards with real sailing; swimming and oxygen; boats; a perspective third-person camera option for exploration; caves if allowed; jump, crouch, block and shields; the bow, crossbow and spear roster with arrow drop and reload; an aimed action mode if chosen.

**Owns:** `game/scripts/world/streaming/ (new)`; `game/scripts/camera/`; `game/scripts/combat/hunt.gd`; `game/scripts/combat/arrow_projectile.gd (new)`; `game/data/{items,recipes}.json (weapon rows)`

**Must not touch:** `game/scripts/economy/`

**Closes:** world-scale-04, world-poi-06, pc-defense-01, pc-combat-05, pc-weapon-02, phys-proj-01

**Acceptance (a reviewer can run or inspect each):**

- Defined after the owner's answers; at minimum: a player can travel between two regions without a fade-to-black load, and a bow shot arcs (vertical drop measured) and can miss.

## 4. Questions only the owner can answer

1. Hosting: which host for the public game server (a VM such as Hetzner or Fly.io, or an orchestrator such as Edgegap) plus managed Postgres, and what monthly budget?
2. Public login: Sign in with Apple, Google, email magic link, or Steam later — which providers?
3. May the orchestrator merge the finished survivor-v2/armor/T. rex mount branch (`claude/survivor-v2-equip-mount-code-de20f0`) into the MMO branch now?
4. The uncommitted 2026-10-17 UI pass in the main checkout: land it as the base for the UI rebuild, discard it, or keep waiting?
5. Zebraceratops (modelled from a Durango screenshot; the roster PRD says "No Zebraceratops"): replace it with a real ceratopsian (which one?) or redesign an original creature?
6. HANDOFF Gate 1: approve concept references for the 8 missing species as one batch, or one species at a time?
7. Breeding, eggs, mutations and colour regions for tradable dinosaurs: override PRD:747 ("no breeding") for the MMO?
8. Survival pressure: keep Durango's fatigue model, or add ARK-style food, water and temperature meters?
9. Should predators outrun a walking survivor (full species speed plus a stamina burst) instead of today's 0.7x chase?
10. Death penalty: none, durability loss, or a lootable bag — and for pets: respawn timer, revive cost, or permadeath?
11. World topology: a few large shared zone maps streamed in chunks, or the current islands as server-hosted shards with real sailing between them?
12. Combat model: keep Durango tap-target auto-attack, or add an aimed action mode (orbit camera, click-to-swing, crosshair)?
13. Should wild dinosaurs attack player structures that block them (base sieges)?
14. Rare-item progression: will you approve a design table of which rare drops gate which recipes before W2-DATA builds it?
15. Market defaults: buy-order placement fee, listing price bands of 0.25x-4x the reference price, and a 30-minute new-account trade lock — accept?
16. Faucet rate: how many T-stones per hour of play should missions pay (this sets every price)?
17. Steam-steam food stacking (the PRD calls it a player engine): keep, cap at 3 steams, or remove?
18. Music: allow CC-BY tracks with an in-game credits screen, or CC0 only?
19. Caves: keep the PRD's "No caves" rule, or allow cave points of interest?
20. Ship gate: AGENTS.md says mobile is primary, HANDOFF.md says desktop Chrome is the gate — which governs this program?
21. Web threads: allow cross-origin isolation headers (COOP/COEP) so the web build can use threads (this can break iframe embedding)?

## 5. Hard constraints

- **Renderer.** The judge is desktop Chrome at 1600x900 on gl_compatibility: no SDFGI, SSIL, SSAO, SSR, volumetric fog, decals, TAA or FSR. Glow, AgX/filmic tonemap, BCS/LUT grading, MSAA and GPUParticles are available. PSSM shadows work in compat (verified 0.492 shadow ratio) once the sun yaw is off the camera axis. Every visual acceptance shot is taken in Forward+ and with `--rendering-method gl_compatibility`; local compat (macOS GL 4.1) reads brighter than WebGL, so final colour sign-off happens in desktop Chrome on a deployed or locally served export.
- **Web runtime.** The export is single-threaded (`thread_support=false`): no threaded loads or bakes, audio mixed on the main thread, stream players need latency headroom. Web audio uses Sample playback: no bus effects; interactive and playlist streams must STREAM. Browsers block ws:// from an https page, so public play needs wss behind a proxy.
- **Payload.** The current pack is 317 MB; the target after W1-WEB is <= 200 MB, then <= 60 MB first play after W2-WEB2. Every new asset counts against it.
- **Credits.** Tripo 3,240 from the existing balance only (never buy, top up or upgrade); the Meshy key returns 401. Per-package caps: W1-ARTA 300, W1-ARTB 400, W2-RERIG 80, W2-ARTC 120. Record task ids and spend per asset; diagnose weak output before re-spending; stop and report at a cap. HANDOFF Gate 1 (owner approves the reference) still applies per species.
- **Asset routing.** Tripo only for complex creatures and player characters; dsc rigs and animates; Blender MCP builds buildings and world objects. One Blender instance: one agent holds Blender MCP at a time (W1-STRUCTART in wave 1); others run headless Blender (`/Applications/Blender.app/Contents/MacOS/Blender -b -P <script>`) from scripts in `tools/blender/`. Asset libraries (Poly Haven) are off.
- **Machine.** 15 cores, 24 GB. At most 5 Godot processes at once through `gslot.sh`, every run with a timeout, never `--editor`; builders that add assets run one `--import` through gslot. Schedule about 8 agents at a time; wave 1 lists a priority order.
- **Saves.** Never touch `~/Library/Application Support/Godot/app_userdata` (the owner's real save). Every worktree needs `game/override.cfg` before any Godot run; the main checkout and several worktrees lack it today (verified), so worktree setup must create it.
- **Concurrency.** Wave 1 must not touch the owner's UI pass (hunt_hud.gd, inventory_ui.gd, animal_screen.gd, item_icons.gd) or the survivor-v2 branch's files (items.json, recipes.json, icons_manifest.json, inventory.gd, item_def.gd, player.gd, player_anim.gd, rigged_model.gd, creature_view.gd, stegosaurus.json, tyrannosaurus.json, characters/). One owner per god file per wave. Only the integrator edits run_all.gd; tests go in `game/tests/t_<pkg>.gd`; labs register in `tools/labs.txt` at merge. The audio branch may add one-line signal emits in files other packages own; the integrator keeps them.
- **Hosting.** The server stays local until the owner decides. Vercel cannot hold WebSockets. Behind a proxy the per-IP caps collapse onto the proxy address.
- **Engine and process.** Godot 4.7.1 typed GDScript, no C#, no new autoloads (Game.net and Game.audio are lazy children); contracts.md changes only through the orchestrator. No invented lore, species or mechanics beyond the PRDs; `# ASSUMPTION:` markers listed in each report.
- **Gates.** Every package ends with `tools/smoke.sh` SMOKE PASS, `tools/test.sh` [tests] PASS, its own labs, and inspected screenshots at 1600x900 and 390x844. A release additionally needs the desktop Chrome production soak PASS and the displayed `commit/pack-hash` stamp matching the release.

## 6. Full gap register

Columns: **Sev** as filed; **Adj** is the verifier's recommended severity or blocker change (blank =
none); **V** = confirmed (C), partly (P), unverified (U); **Eff** = effort; **Pkg** = the package(s)
that close it. Evidence is abbreviated; full evidence, screenshots and probe logs are in the
per-system audit folders. "1a-audio" means the running audio package, merged by W1-INT.

### Dinosaur models, textures, materials and animation (dino-art)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| dino-art-01 | P0 | | C | credits | XL | 8 species have no mesh and spawn as a box on two sticks | No GLB for allosaurus, ankylosaurus, brachiosaurus, dilophosaurus, smilodon, styracosaurus, tarbosaurus, triceratops; spawn on 8 islands; creature_view.gd:113-130; gl_triceratops_sheet.png | W1-ARTA, W1-ARTB, W2-ARTC |
| dino-art-02 | P0 | blocker other_session | C | owner_decision | S | Stale override forces a box for Stegosaurus although its GLB renders | creature_view.gd:63; rig v3 edge ratio 1.07-5.74; glbforce_stegosaurus_sheet.png; the survivor-v2 branch ships Stegosaurus v2 | W2-CVIEW, W2-ARTC |
| dino-art-03 | P0 | | C | none | XL | Generic donor/procedural animation; tail whips up; quadruped attack = idle; dead-bug knockdown | Identical clip lengths across 6 bipeds; transplant_rig.py:584-620; biped walks frozen 51 % of the loop | W2-RERIG, W1-CANIM (loop trim) |
| dino-art-04 | P1 | | P | none | M | Foot sliding: stride not matched to speed, walk/run blend unsynced | creature.gd:290 frac=speed/8; megaloceros back foot 0.18 m per run cycle at 7.6 m/s | W1-CANIM, W2-CVIEW |
| dino-art-05 | P1 | | C | none | S | AnimationPlayer.speed_scale ignored by the AnimationTree | '[speedprobe] ... ratio=1.000'; T. rex stomp lands 0.65 s after damage | W1-CANIM |
| dino-art-06 | P1 | | C | none | L | Donor skeleton: no jaw, one neck bone, 5 tail bones | 37/39-joint skins; only tyrannosaurus.glb has Jaw | W2-RERIG |
| dino-art-07 | P1 | | C | credits | M | Deinonychus is the old single-image mesh (paddle tail, slab hands) | 12,414 tris; JPEG normal; gl_deinonychus_idle_q34.png | W2-RERIG |
| dino-art-08 | P1 | P2 | P | credits | M | White/pale texture regions | gallimimus 8.2 % near-white texels; compy "white" is blown exposure | W1-LIGHT, W2-RERIG |
| dino-art-09 | P1 | | C | none | S | Hit flash and status tints never reach GLB creatures | creature_view.gd:200-211 `pass`; death grey and wobble also missing | W2-CVIEW |
| dino-art-10 | P1 | | C | none | L | No sleep/eat/turn/unconscious/roar clips; T. rex feed/sleep/tail_swipe never played | creature_clips.gd:87-88 feed = idle copy; creature_brain.gd:186-188 | W1-CANIM, W2-RERIG |
| dino-art-11 | P1 | | U | owner_decision | L | No colour regions, mutations or visible variants | variants are names only (creature_def.gd:61) | W4-TAMING |
| dino-art-12 | P1 | | U | owner_decision | M | Zebraceratops is a Durango original modelled from a Durango screenshot | art_direction.json references a BlueStacks Durango guide; PRD:10 "No Zebraceratops" | W2-ARTC |
| dino-art-13 | P2 | | U | renderer | S | Web renderer paler; LabKit blown out on gl_compatibility | raptor_scale_lab_gl_cam10.png near-white | W1-LIGHT |
| dino-art-14 | P2 | | U | none | M | No foot IK, look-at, turn-in-place or death physics | no SkeletonIK/LookAt in creatures/ | W2-CVIEW |
| dino-art-15 | P2 | | U | none | M | Rig audit shows heavy stretch in several clips | rig_audit_after.json max edge 9.5 (megaloceros run) | W2-RERIG |
| dino-art-16 | P2 | | U | owner_decision | M | No juvenile scale or growth | juvenile variants unused | W2-CVIEW (scale), W4-TAMING |
| dino-art-17 | P2 | | U | other_session | M | No portraits or /showcase review route | animal_screen text only; no 'showcase' in game/ | W1-ARTA (studio lab), W2-ARTC, W2-SCREENS |
| dino-art-18 | P2 | | U | owner_decision | S | Concept ledger INDEX.md stale | 4 species listed as DRAFT; T. rex missing | W1-ARTA |
| dino-art-19 | P3 | | U | none | S | Black 2K emission maps and orphan textures | Image_3 maxL <= 0.06 | W2-RERIG |
| dino-art-20 | P3 | | U | none | S | T. rex rig sources live outside the repo | work/ gitignored; .blend in DeepseekCLI | W2-RERIG |
| dino-art-21 | P3 | | U | none | S | No close-up art lab; creature_lab kills the survivor in ~2 s | creature_lab_gl.png shows YOU DIED | W1-ARTA, W1-QA |

### Dinosaur AI, ecosystem and spawning (dino-ai)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| dino-ai-01 | P0 | | C | none | S | Herbivores sleep at the first night and never wake | creature_brain.gd:186-214 no sleep branch; '[vprobe] A day10s ... zeb=sleep moved=0.00' | W1-AI |
| dino-ai-02 | P0 | blocker none (local) | C | hosting | XL | Brains assume one local player, run client-side, persist nothing | 9 first-player lookups; on_player_killed resets every engaged dino | W2-PLAYER (registry), W3-SRVWORLD |
| dino-ai-03 | P0 | P1 | C | none | XL | No ecosystem: no wild hunting, eating, drinking, scavenging, territory | '[probe] predator_prey ... prey_hp_lost=0.0 ... dist=2.1' | W2-ECO |
| dino-ai-04 | P1 | P2 | P | none | S | Pack followers flip state when the alpha's leash is longer | only mixed packs (lab-built) thrash every frame; shipped packs flicker 1-2 s | W1-AI |
| dino-ai-05 | P1 | | C | none | S | Flee stays inside ~14 m and runs from the survivor, not the attacker | '[probe2] flee_summary max_from_home=14.3 min_gap=1.6' | W1-AI |
| dino-ai-06 | P1 | | P | owner_decision | S | Predators chase at 0.7x, slower than a walking survivor | creature.gd:261-263; ai.json:19 ASSUMPTION | W1-AI (data), owner |
| dino-ai-07 | P1 | P2 | P | none | M | Detection is a 360° radius through walls; night x1.5 | '[probe] los wall_between=true raptor_state=approach' | W2-ECO |
| dino-ai-08 | P1 | | P | none | L | Archetypes are labels; no spit/charge/tail kits; Tarbosaurus gets the base brain | creature.gd:345-346; creature_def.gd:67-73 | W2-ECO |
| dino-ai-09 | P1 | | C | none | L | One-shot spawn, seed 41, no respawn, identical layout every visit | island_runtime.gd:970-1037 | W2-SPAWN |
| dino-ai-10 | P1 | | P | none | S | Ring level offsets and crater tier_offset never apply; level does not scale stats | 'velociraptor@crater tier=25 levels=[25,...]'; creature.gd:170-178 | W1-AI, W2-SPAWN |
| dino-ai-11 | P1 | | U | none | M | O(N²) scans, no AI LOD: 16.42 ms physics at 120 creatures | '[probe] perf creatures=120 physics_ms_avg=16.42' | W1-AI |
| dino-ai-12 | P1 | | U | none | S | Every herbivore (14,000 HP Triceratops too) flees on sight | creature_brain.gd:201, PROVOKE_HITS=3 | W1-AI |
| dino-ai-13 | P2 | | U | none | S | Pack members interpenetrate | aival_pack.png; slot radius 1.8-2.15 m for all | W1-AI |
| dino-ai-14 | P2 | | U | none | M | Species overrides bypass base rules | raptor_pack_brain.gd:24-52; tyrant_brain.gd:16-33 | W1-AI |
| dino-ai-15 | P2 | | U | none | M | AI tests thin; lab passes while printing failures | '[aival] PASS' after a stalled pet_repeat | W1-AI |
| dino-ai-16 | P2 | | U | none | M | Thin day/night schedule | only herbivore sleep + perception x1.5 | W2-ECO |
| dino-ai-17 | P3 | | U | owner_decision | M | Wild AI never targets structures | _valid_target handles 3 types | W2-BUILDSYS / W2-ECO after owner |
| dino-ai-18 | P3 | | U | none | S | Solo spawns get pack ids and flank from the far side | spawner.gd:30 | W1-AI |
| dino-ai-19 | P3 | | U | none | S | Tames keep their wild pack id | become_pet keeps pack_id | W1-AI |
| dino-ai-20 | P3 | | U | none | S | Brachiosaurus never spawns; post-kill retreat moves spawn_home forever | creature_brain.gd:79 | W1-AI, W2-SPAWN |

### Taming, breeding and creature progression (taming-breeding)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| tame-01 | P0 | P1 | C | owner_decision | XL | Breeding, eggs, inheritance, mutations, growth, imprinting absent | grep finds none; PRD:747 forbids breeding; contracts list a breed origin | W4-TAMING |
| tame-02 | P0 | | C | none | M | 8 of 16 tameable species can never be tamed | only capture_net_i has a recipe; nets III/V missing from items.json | W2-DATA |
| tame-03 | P0 | blocker none | P | other_session | S | Pen route ends in a tamed_animal item nothing can bond | bond_from_inventory only from capture_lab F9 | W1-TAME |
| tame-04 | P0 | | C | none | S | Pet levelling compounds: Lv60 raptor HP x93.8 | pet_record.gd:54-58; '[verify] raptor lv=60 ... hp 643 -> 60295' | W1-TAME |
| tame-05 | P0 | | C | none | S | Pet bags shrink to 10 slots on every load | pet_record.gd:167; 'triceratops bag slots before=140 after=10' | W1-TAME |
| tame-06 | P0 | blocker none (local) | C | hosting | XL | No creature id, owner, authority or transfer path | pet_record.gd:5-40; client randf in tames | W1-TAME, W1-SRVDOM, W3-SRVACT |
| tame-07 | P1 | | C | none | M | Wild level is cosmetic and dropped on tame | stat_value ignores level; from_def starts at 1 | W1-AI, W1-TAME |
| tame-08 | P1 | | P | none | L | Taming is shallow: two food sets, 4-8 s tame, no torpor/effectiveness | field_tame.gd:5-10; pen takes only raptor_meat | W4-TAMING |
| tame-09 | P1 | | C | none | M | Growth points and EVs shown but never applied; no allocation | animal_screen.gd:218-222; train() has no caller | W1-TAME, W2-SCREENS |
| tame-10 | P1 | | C | none | S | Displayed grade differs from the grade driving XP and hunger | 'rolled S, IV0 -> grade=D- xp_rate=1.30' | W1-TAME |
| tame-11 | P1 | | U | none | S | 60 s respawn (rule says 3 min), HP not persisted, nets ignore the 30 % rule | pet_record.gd:24; player.gd:1697 | W1-TAME, W1-COMBAT, W2-PLAYER |
| tame-12 | P0 | | U | other_session | M | Animals screen looks amateur in game | ingame_animals.png: no backdrop, title over vitals | W2-SCREENS |
| tame-13 | P1 | | U | none | S | Mount species with bags can never open the bag | player.gd:1585-1592 | W2-PLAYER |
| tame-14 | P1 | | U | owner_decision | M | Pet death costs nothing; roster unlimited | bonded_cap 2147483647 | W4-TAMING |
| tame-15 | P2 | | U | none | S | Field tame ignores capture-technique gating | field_tame.gd:15-22 | W1-TAME |
| tame-16 | P2 | | U | none | S | Only the first summoned pet can be fed | player.gd:219-225 | W2-PLAYER |
| tame-17 | P2 | | U | other_session | S | Tame plate minimal; status glyph half hidden | plate_zoom.png | W1-UI, W2-HUD |
| tame-18 | P2 | | U | none | S | Labs do not verify taming end to end | capture_lab has no '[tame]' line | W1-TAME |
| tame-19 | P2 | | U | none | M | No naming, stances or storage item | pet_brain orders attack/heel/guard only | W2-ECO, W2-SCREENS |
| tame-20 | P2 | | U | none | S | Variants (juvenile, snow) have no effect | creature_view stores variant only | W2-CVIEW |
| tame-21 | P2 | | U | other_session | M | Mounting bare; ridden and walking speeds differ | player.gd:1594-1627 | W2-PLAYER |

### Player movement, animation and combat (player-combat)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| pc-anim-01 | P0 | | C | none | S | Survivor mesh floats ~0.9 m (rig feet at capsule centre) | '[pcv] idle ... lowest bone above floor by 0.95 m'; idle_verify_zoom.png | W2-PLAYER |
| pc-anim-02 | P0 | | C | none | M | Root motion never extracted (1.4 m lunge, 4.5 m roll overshoot); knockdown clip never plays | 'roll t=1.86 ... hipsFwd=4.45'; has_flag(knockdown)=false | W2-PANIM |
| pc-combat-01 | P0 | | C | none | M | Roll refused ~65 % of a swing, aims at the enemy, locks 1.87 s | '[pcv] re-roll attempt at t=0.72 -> accepted=false' | W2-PLAYER |
| pc-combat-02 | P0 | | C | none | S | Statuses land on dodged hits; telegraph vanishes before impact | creature_attack.gd:9-12 before :47; telegraph life 0.9 vs hit 1.08/1.32 s | W1-COMBAT |
| pc-mmo-01 | P0 | blocker none (local) | C | hosting | XL | Combat client-authoritative and single-player | hunt.gd:140-159 client randf; static Telegraph._active | W3-SRVACT |
| pc-audio-01 | P0 | | C | owner_decision | L | Combat is silent | 0 audio files | W1-INT (1a-audio) |
| pc-combat-03 | P1 | blocker mostly none | C | credits | M | Damage at swing start; 3 s clip played 4.7-6.5x; attack_hit never emitted | hunt.gd:133-159; spd=4.67 | W1-COMBAT, W2-PANIM |
| pc-feel-01 | P1 | P2 | C | none | S | No hitstop, no camera shake | iso_camera.gd follow/zoom only | W1-COMBAT |
| pc-anim-03 | P1 | | C | none | S | Player foot sliding (walk 5.5 m/s on a ~1.7 m/s clip) | 'anim_speed=1.00 horiz_speed=5.50' | W2-PANIM |
| pc-weapon-01 | P1 | | C | credits (partly none) | M | Hand shows the gather tool, never the combat weapon | station_craft.gd:351-370; props_manifest weapons unread | W1-ITEMS |
| pc-weapon-02 | P1 | | U | credits | L | Designed roster (bow, crossbow, spear) missing | items.json has no bow/crossbow/spear | W4-WORLD |
| pc-combat-04 | P1 | | U | none | S | No manual attack; HOLD/Auto-off disable attacking | hunt.gd:81-82 | W2-PLAYER |
| pc-combat-05 | P1 | | U | owner_decision | XL | Tap-target auto-attack, not aimed action combat | ortho iso camera; distance + RNG hits | W4-WORLD |
| pc-balance-01 | P1 | | U | owner_decision | M | Damage cliff: 20-40 swings for a compy, 1-2 hits to die | 'dmg=3.9'; raptor heavies 78-109 vs 100 HP | W1-COMBAT (data), owner |
| pc-hitreact-01 | P1 | | U | none | S | Authored creature hit_react never plays (condition inverted) | creature.gd:543 | W1-AI |
| pc-bug-01 | P1 | | U | none | S | F attacks your own pet | _nearest_creature ignores is_pet | W1-COMBAT, W2-PLAYER |
| pc-anim-04 | P1 | | U | none | M | Zero-blend one-shots; no layering; no moving while attacking | player_anim.gd:193-195 | W2-PANIM |
| pc-defense-01 | P1 | | U | owner_decision | L | No block, parry, shield, jump, crouch or swim | input_setup.gd | W4-WORLD |
| pc-ai-01 | P2 | | U | none | M | Primary bites untelegraphed; pounce in place; no circling | creature_anim.gd:55-56 | W2-ECO |
| pc-hitreact-02 | P2 | | U | none | S | Player hit reaction fires twice and on misses | creature.gd:486-488 | W1-COMBAT, W2-CVIEW |
| pc-ui-01 | P2 | | U | none | S | Damage floats overlap; cartoon jaw overlay | combat_test_zoom.png 'GTACKLE!' | W2-HUD |
| pc-data-01 | P2 | | U | none | S | accuracy_mult, evasion_add, struggle ignored | status_effects.gd:147 unused | W1-COMBAT |
| pc-data-02 | P2 | | U | none | S | Weapons never wear in combat | only wear_gather_tool calls wear | W1-COMBAT |
| pc-ranged-01 | P2 | | U | none | S | Ranged stalls silently on blocked LOS; no gravity | hunt.gd:291-294 | W1-COMBAT |
| pc-raid-01 | P2 | | U | owner_decision | M | T. rex raid untested for winnability | '[raidfight] PARTIAL ... playerHP=0' | W1-ITEMS (probe), owner |
| pc-test-01 | P2 | | U | none | S | Combat probe passes when the kick fails | '[combattest] kick moved=0.00' then ok | W1-COMBAT |
| pc-lab-01 | P3 | | U | none | S | hunt_lab shows YOU DIED; corpse shot calls a missing method | hunt_lab.gd:127 | W1-COMBAT |
| pc-misc-01 | P3 | | U | none | S | Textureless telegraph decal; 2.03 m survivor in a 1.8 m capsule | telegraph.gd:36-39; player.gd:1844 | W1-COMBAT, W2-PLAYER |

### Survival, gathering, inventory, crafting, equipment (survival-crafting)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| ladder-01 | P0 | P1 | P | none | L | Bronze and Steel unobtainable; no fuelled smelting | no recipe/node for bronze_ingot, steel_ingot, tin | W2-DATA |
| ladder-02 | P0 | | C | none | M | Material tier does nothing for mining or combat | harvest_node.gd:204 tool 'none' on all rock; hunt.gd:129 no tier term | W1-ITEMS |
| equip-01 | P0 | | C | other_session | L | No armor between level 1 and 55 | only raid_* armor at HEAD; branch adds 3 kits, no metal tiers or insulation | W2-DATA |
| mmo-01 | P0 | | C | none | M | Items have no instance identity or provenance | item_stack.gd:5-12, to_dict | W1-ITEMS, W1-SRVDOM |
| mmo-02 | P0 | blocker none (local) | C | hosting | XL | Inventory, gathering, crafting run client-side with local RNG | crafting.gd:288-292; randf at crafting.gd:160 | W1-SRVDOM, W3-SRVACT |
| craft-01 | P1 | P2 | P | owner_decision | S | Crafted-level cliff: skill 0 caps at 60, skill 1 caps at 1 | '[craft] knife expected=32 got=1' | W1-ITEMS |
| level-01 | P1 | | C | none | S | A level-5 weapon is only 7.8 % stronger than level 1 | 'work_axe dmg L1=22.44 L5=24.20' | W1-ITEMS |
| survival-01 | P1 | | P | owner_decision | L | Almost no survival pressure; no spoilage | vitals.gd health/energy/fatigue only | W2-PROCESS, owner |
| food-01 | P1 | P2, owner_decision | P | none | S | Steaming has no cap (PRD celebrates it) | 'sashimi-steam-steam energy/piece=37.0 process=4' | W2-PROCESS |
| durability-01 | P1 | | C | owner_decision | M | No item sinks: no combat wear, no repair, no death cost | wear only via gather; grep 'repair' empty | W1-COMBAT, W2-DATA, owner |
| inv-01 | P1 | | U | other_session | M | Stacks fragment by level and climate in a 20-slot bag | island_runtime.gd:803 stamps climate | W1-ITEMS, W2-INV |
| equip-02 | P1 | | U | other_session | S | Equipment by item type: the first copy is worn | inventory.gd:27-42 | W2-INV |
| climate-01 | P1 | | U | owner_decision | M | Temperature only adds fatigue; weather list dead | island_runtime.gd:1183-1204 rain only | W2-WEATHER, W2-DATA |
| craft-02 | P1 | | U | none | XL | Crafting shallow: one item per tool class, no background stations, no fuel | 71 recipes; StationCraft cancels when you walk away | W2-DATA, W2-PROCESS |
| gather-01 | P1 | | U | none | S | --gather-test fails (scaled time, nav stall) | '[gathertest] FAIL no branches gathered' | W2-INT, W2-PLAYER |
| test-01 | P1 | | U | none | M | No end-to-end ladder test | '[progression] PARTIAL ...' | W1-QA, W2-DATA |
| inv-02 | P1 | | U | other_session | M | Inventory chrome overlaps; world nameplate through the bag | bag_family.png | W2-SCREENS |
| craft-03 | P2 | | U | none | S | Grill burn is a hidden 20 % coin flip | crafting.gd:158-162 | W1-ITEMS, W2-PROCESS |
| craft-04 | P2 | | U | none | S | Craft screen shows Lv 60 for unmakeable recipes | crafting.gd:328-332 | W1-ITEMS, W1-UI |
| armor-01 | P2 | | U | none | S | Subtractive armor; raid gear probe fails | creature_attack.gd:44-47 | W1-COMBAT |
| gather-02 | P2 | | U | none | S | Manifest yield ranges and some harvest ids ignored | harvest_node.gd:219 min=max=1 | W1-ITEMS |
| gather-03 | P2 | | U | none | M | Latent material attributes dead data; some tiers wrong | attr never stamped | W2-DATA |
| data-01 | P2 | | U | none | S | Hoe unobtainable; dead item references | requires_tool never read; 15 missing ids | W2-DATA, W2-WEATHER (statuses) |
| tool-01 | P3 | | U | none | S | Auto tool selection takes the first tool | inventory.gd:294-310 | W2-INV |

### Base building, structures and persistence (building)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| build-struct-01 | P0 | | C | none | XL | No structural building (foundations, walls, roofs, sockets, storeys) | build_grid.gd flat Vector2i occupancy | W2-BUILDSYS |
| build-mmo-01 | P0 | | C | hosting | XL | No server authority, ids, owners or permissions for structures | save_game.gd:90-94 local JSON | W3-SRVACT, W4-HOST |
| build-art-01 | P0 | blocker none (Blender) | P | credits | L | Structures read as placeholders (salmon palette, primitive catapult) | built_base.png, catapult_zoom.png | W1-STRUCTART |
| build-kits-01 | P1 | | C | none | S | field_small, field_large, steamer kits cannot be placed | '[kitprobe] field_small_kit ... UNPLACEABLE' | W1-BUILD, W2-DATA |
| build-remove-01 | P1 | | C | none | M | No demolish for most kinds; catapult shift-tap script error | 'Nonexistent function pack_up ... FieldCatapult' | W1-BUILD, W2-PLAYER, W2-HUD |
| build-persist-01 | P1 | | C | none | M | Buildings on an unstable island vanish on reload | 'placed_baskets=1 stone_in_baskets=9' -> 0 | W1-SAVE |
| build-save-01 | P1 | | C | none | S | Corrupt/newer save starts a new world and the autosave overwrites it | '[world] unsupported save schema=4; starting new world' | W1-SAVE |
| build-def-01 | P1 | | C | none | L | Only the catapult has HP; no repair, turrets or raids | creature_attack.gd:32-34 | W2-BUILDSYS |
| build-tier-01 | P1 | | C | none | L | No material tiers; construction tree promises missing structures | trees.json large_box, furnace, barn absent | W2-BUILDSYS, W2-DATA |
| build-gate-01 | P1 | | C | none | M | Gate is a solid block | tile_path.gd:84-87 | W1-BUILD, W2-PLAYER |
| build-claim-01 | P1 | | U | owner_decision | M | Claims free and unlimited; failed claims burn stakes | player.gd:2261-2272 | W4-ECONH |
| build-storage-01 | P2 | | U | other_session | M | One 60-slot basket; pet dump deletes overflow | player.gd:1737 ignores add() leftover | W2-PLAYER, W2-BUILDSYS |
| build-ux-01 | P2 | | U | other_session | M | Ghost label 8 px with raw reason codes; no catalog | ghost_label_zoom.png | W1-BUILD, W2-HUD |
| build-save-02 | P2 | | U | none | S | Only a 60 s autosave; nothing on tab close | world.gd:64-67 | W2-INT |
| build-place-02 | P3 | | U | none | S | Placement ignores trees and rocks; no leveling | _reserve_box has no callers | W2-SCATTER, W2-BUILDSYS |
| build-place-03 | P3 | | U | none | S | Kit paid before spawn succeeds | build_placer.gd:368-380 | W1-BUILD |
| build-place-04 | P3 | | U | none | S | Fence auto-rotation overrides manual rotation | build_lab rot=0 | W1-BUILD |
| build-sign-01 | P3 | | U | none | S | Signs can never get text | placed_building.gd:27 | W2-BUILDSYS |
| build-test-01 | P3 | | U | none | S | Build tests miss real risks; foundation_lab never exits | foundation_lab EXIT 70 | W1-BUILD, W1-QA |
| build-restore-01 | P3 | | U | none | S | Restored rows unchecked; unknown kinds become boxes | save_game.gd:232-248 | W1-SAVE |

### World generation, biomes, terrain, vegetation, water (world-terrain)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| world-biome-01 | P0 | | C | none | M | Every climate renders as the same green meadow | 3 of 10 palettes; one texture set; desert_35_inland.png green | W1-BIOME, W2-TERRAIN, W2-SCATTER |
| world-terrain-02 | P0 | | C | none | L | Flat disc, ~3.7 m land relief, 3-4 distinct heightmaps | seed 25 or 17 (:274); 'distinct heightmaps=4' | W2-TERRAIN |
| world-veg-03 | P0 | | C | none | M | Sparse vegetation; grass culled 48 m from island centre | 'count=162 range_end=48.0'; camp camera 48.4 m from origin | W2-SCATTER |
| world-scale-04 | P0 | | C | owner_decision | XL | 15 disconnected discs joined by a menu teleport; ~50 m ortho view | world.gd:147-180; iso_camera.gd:16 | W4-WORLD |
| world-water-05 | P1 | | C | none | L | Flat water; disconnected sine trench river; no lakes or waves | island_runtime.gd:313-318; water.gdshader no vertex waves | W2-TERRAIN |
| world-poi-06 | P1 | | C | owner_decision (caves) | L | Crater on 1 of 14 islands, on the beach; no warp ruins or landmarks | crater at 184.5 vs land 182.4 | W2-TERRAIN, W2-SPAWN, W4-WORLD |
| world-harbour-07 | P1 | blocker none | P | credits | M | Harbour is a grey box 150+ m inland | 'harbour_to_water_m=187' | W2-TERRAIN, W1-STRUCTART, W2-LOOP |
| world-placement-08 | P1 | | C | none | S | Lilypads on dry land, palms in desert, berries on volcano | 'lily=24 lily_dry=24'; palms=36 desert | W1-BIOME, W2-SCATTER |
| world-weather-09 | P1 | | C | none | M | Rain only, on every climate | _weather no climate check | W2-WEATHER |
| world-terrainpick-10 | P1 | | C | none | S | First-island picker changes nothing but grass | identical role counts for 5 picks | W2-SCATTER |
| world-mmo-state-11 | P1 | | U | hosting | XL | World state per player and local | world.gd:14-30 | W3-SRVWORLD |
| world-lighting-12 | P2 | | U | renderer | M | Flat hazy atmosphere | no tonemap, flat ambient | W1-LIGHT |
| world-rings-13 | P2 | | U | none | S | Rings do not fit the land; measured from centre | far_shore 210-240 m vs land 182 m | W2-SPAWN |
| world-wet-14 | P2 | | U | none | S | Wet trigger is a straight band, not the river | island_runtime.gd:549-567 | W2-TERRAIN |
| world-build-15 | P2 | | U | none | M | Island generation blocks the main thread 1.7-1.9 s | 'build temperate_25 ms=1921' | W2-TERRAIN |
| world-artstyle-16 | P2 | | U | credits | L | Low-poly Quaternius beside textured Meshy assets | temperate25_inland.png | W3-NATUREART |
| world-ocean-17 | P3 | | U | none | S | Ocean has a hard square edge | island_runtime.gd:481-510 | W2-TERRAIN |
| world-data-18 | P3 | | U | none | S | Dead climates/families; no world-gen tests | snowfield, blue_tropical unused | W2-TERRAIN |

### Lighting, sky, weather, atmosphere, VFX (lighting-vfx)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| lv-shadow-01 | P0 | fix: PSSM + sun yaw off camera axis | P | none | M | Sun cast shadows effectively invisible on every island | 'ghost_shipped ratio=0.989' (fwd), 0.930 (compat); fixed 0.694/0.492 | W1-LIGHT |
| lv-exposure-02 | P1 | | P | none | S | Flat, hazy, low-contrast daylight (owner: "too bright") | no tonemap set; ambient 0.75; crop-probe-a vs -d | W1-LIGHT |
| lv-weather-03 | P1 | | C | none | L | One white-speck rain on every climate | climates.json weather lists never read | W2-WEATHER |
| lv-mmo-sync-04 | P1 | | C | hosting | M | Clock and weather client-local and random | game.gd:140; save_game.gd:85 | W3-SRVWORLD |
| lv-particle-color-05 | P1 | P2 | C | none | S | Rain and bleed particles render white | pcolor-fwd.png | W1-LIGHT, W2-CVIEW |
| lv-night-06 | P1 | | C | none | S | Night is a grey-blue fog wash; no moon | fog_light_color never driven | W1-LIGHT |
| lv-fire-07 | P1 | | C | none | M | Fires have no flame; light pops on at dusk | c7-073.png | W2-VFX |
| lv-post-08 | P1 | blocker none for web part | P | renderer | S | No glow, grade or AA on web | msaa_3d.web=0 | W1-LIGHT, W2-WEB2 |
| lv-vfx-09 | P1 | | C | none | L | No gather, impact, footstep, water, projectile or level-up VFX | only 3 Particles3D sites | W2-VFX |
| lv-decal-10 | P2 | | U | renderer | S | Blood and telegraph decals invisible; unsupported on web | probe6-decals-rain-fwd.png | W1-COMBAT, W2-VFX |
| lv-dawn-dusk-11 | P2 | | U | none | S | No sunrise or sunset hue; curve disagrees with phases | island_runtime.gd:1147-1151 | W1-LIGHT |
| lv-climate-12 | P2 | | U | none | M | Every climate lit identically | constants in _apply_env_setup | W1-LIGHT, W2-WEATHER |
| lv-lab-mismatch-13 | P2 | | U | none | S | Labs use different, brighter lighting | lab_kit.gd:6-19 | W1-LIGHT |
| lv-water-14 | P2 | | U | none | M | Water has no glint or waves; differs by renderer | day-shore-fwd vs compat | W2-TERRAIN |
| lv-hitch-15 | P2 | | U | renderer | M | Compat shader compile stalls | day-ctx-compat.png blank at 6 s | W2-VFX |
| lv-light-budget-16 | P2 | | U | none | M | Every survivor carries a 14 m omni lantern | player.gd:1994-2020 | W3-SRVWORLD |
| lv-sky-17 | P2 | | U | none | S | Sky never visible; no cloud shadows | ortho camera pitch | W1-LIGHT |
| lv-dirt-18 | P2 | | U | none | S | Dirt discs render as black stains | home-fwd.png | W1-LIGHT |
| lv-rain-rules-19 | P2 | | U | none | S | Rain ignores shelter; snaps on/off | island_runtime.gd:1186-1206 | W2-WEATHER |
| lv-local-shadows-20 | P3 | | U | renderer | S | Fire and lantern cast no shadows | shadow_enabled=false | W2-VFX |
| lv-daylen-21 | P3 | | U | owner_decision | S | Day length hard-coded 720 s | game.gd:8 | W3-SRVWORLD |

### Multiplayer (multiplayer)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| net-core-01 | P0 | now on claude/mmo-net | C | none | XL | No transport, server process or replication at HEAD | grep finds only HTTPRequest; 'ws connected in 282 ms' probe | W1-INT, W3-SRVWORLD |
| net-auth-02 | P0 | | C | none | XL | Every gameplay outcome computed on the client | hunt.gd:140-159; player.gd:969-986; world.gd:164 | W1-SRVDOM, W3-SRVACT, W3-SRVWORLD |
| net-econ-03 | P0 | resolved in contract v2 | C | owner_decision | L | v1 market trusted client-minted assets; token accounts a faucet | contracts.md v1 §4 | W3-SRVACT, W3-EXCHANGE, W4-HOST |
| net-single-04 | P0 | P1 | C | none | L | Single-player assumptions in AI, pets, kill credit, globals | 36 first-player lookups; world.gd:11-36 | W2-PLAYER, W3-SRVWORLD |
| net-persist-05 | P0 | P0 for MMO only | C | hosting | L | One non-atomic local JSON holds currency, pets, buildings | save_game.gd:90-94 | W1-SAVE, W4-HOST |
| net-identity-06 | P0 | P1, blocker none | P | other_session | M | No uid or owner on items and pets | item_stack.gd:5-12 | W1-ITEMS, W1-TAME |
| net-hosting-07 | P1 | | C | hosting | M | No host holds WebSockets; https needs wss | vercel.json headers only | W4-HOST |
| net-auth-08 | P1 | | C | owner_decision | M | No real accounts | manifest.js access code; token-only contract | W4-HOST |
| net-server-boot-09 | P1 | P3 | P | none | S | Server boot leftovers (TouchControls; no server preset) | project.godot:25; dedicated_server=false | W1-INT, W1-WEB |
| net-headless-cost-10 | P1 | P2 | P | none | M | Headless island costs 231 MB, 3-4 ms physics | 'mem_delta=231 MB' | W3-SRVWORLD |
| net-split-11 | P1 | | U | other_session | L | Player and creature nodes mix sim, input, visuals, UI | player.gd 2,331 lines | W2-PLAYER |
| net-timers-12 | P1 | | U | none | M | Timers on client frame time or wall clock | taming_pen.gd:94 | W3-SRVWORLD |
| net-interest-13 | P1 | | U | none | L | No zone, instance or interest model | world.gd:31 single runtime | W3-SRVWORLD |
| net-ledger-durability-14 | P1 | | U | hosting | M | JSON snapshot + journal via FileAccess, no fsync | contracts §5.2 | W4-HOST |
| net-web-caveats-15 | P2 | | U | renderer | S | Web transport traps (TCP, 64 KiB, background tabs) | net_defaults.log | W3-SRVWORLD |
| net-tests-16 | P2 | | U | none | M | No multi-client harness (net_tests now on branch) | game/tests | W3-NETQA |
| net-gdsync-17 | P3 | | U | owner_decision | S | Untracked GD-Sync relay addon in main checkout | plugin.cfg | W1-INT (record rejection) |

### Economy and marketplace (economy)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| econ-supply-trust-01 | P0 | decided by contract v2 | C | owner_decision | XL | Everything entering the market is a client claim | 'forged pet hp=999999 ...' | W1-SRVDOM, W3-SRVACT, W3-EXCHANGE |
| econ-dupe-01 | P0 | P1 | P | none | M | Dupe by save restore or crash after deposit | world.gd:64-67 60 s autosave | W3-SRVACT |
| econ-dino-01 | P0 | P1 | P | none | L | Pets cannot change owner; genetics client-rolled | pet_record.gd no uid; creature_genetics.gd:18-27 | W1-TAME, W3-SRVACT |
| econ-market-01 | P0 | blocker none (local) | C | hosting | XL | No marketplace at HEAD (engine on branch, no UI) | 'Data properties containing market: []' | W1-INT, W3-EXCHANGE |
| econ-faucet-01 | P0 | | C | owner_decision | M | 122 T-stones per save; sailing soft-locks; global Settlers budget | objectives 72 + start 20 + crater 30 | W2-LOOP, W1-INT |
| econ-pet-stats-01 | P1 | P2 | P | none | M | Growth and EVs never change pet stats | train() no caller | W1-TAME |
| econ-fungibility-01 | P1 | | C | owner_decision | M | Buy orders accept poisoned or broken units | contracts §6.1 | W2-INT |
| econ-account-01 | P1 | P0 | C | owner_decision | L | Free token accounts: alt faucets and wash funnels | 92 tradable T-stones per account | W2-INT, W4-HOST |
| econ-grade-01 | P1 | P2 | P | none | S | Two grade systems disagree | 'from_def(p_grade=C) grade=A' | W1-TAME |
| econ-petbag-01 | P1 | P0 | C | none | S | Pet bags shrink to 10 slots on reload | 'before=140 after_reload=10' | W1-TAME |
| econ-conservation-01 | P1 | | U | none | M | Items destroyed when a destination is full; one-phase withdraw | player.gd:1729-1738; taming_pen.gd:117 | W1-ITEMS, W1-BUILD, W1-TAME, W2-PLAYER, W2-INT |
| econ-identity-01 | P1 | | U | other_session | M | No stable item instance identity; equipment points at a def | stack dict keys | W1-ITEMS, W2-INV |
| econ-settlers-01 | P1 | | U | owner_decision | M | Global Settlers invite sniping; drops the regional hauling loop | contracts §6.6 | W4-ECONH |
| econ-vault-location-01 | P1 | | U | none | S | Vault usable from anywhere | contracts §4 | W3-EXCHANGE |
| econ-inspect-01 | P1 | | U | none | M | Pet inspection inadequate for listings | animals_detail.png | W2-SCREENS, W3-EXCHANGE |
| econ-persistence-01 | P1 | | U | hosting | L | No backups, replication or admin tools | contracts §5.2 | W4-HOST |
| econ-manipulation-01 | P2 | | U | owner_decision | M | Free buy-order spoofing; no price bands | contracts §6.4 | W4-ECONH |
| econ-catalog-01 | P2 | | U | other_session | S | market.json categories do not match items | 11 of 22 categories unmatched | W2-DATA, W2-LOOP |
| econ-hud-wallet-01 | P2 | | U | none | S | T-stone balance not on HUD or bag | harbour2.png | W2-HUD |
| econ-doc-drift-01 | P2 | | U | none | S | Docs and contract disagree with code | contracts 'def_id' vs 'id' | W1-INT |
| econ-tests-01 | P2 | | U | none | M | No economy tests at HEAD (economy_tests on branch) | run_all.gd | W1-INT |
| econ-mount-pet-01 | P3 | | U | other_session | S | Saddle state for listed pets undefined | contracts §4 | W2-INT |
| econ-direct-trade-01 | P3 | | U | hosting | M | No face-to-face trade window | none in scripts | W3-SOCIAL |

### UI/UX (ui-ux)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| ui-phone-01 | P0 | | C | none | M | Runtime has no phone layout; HUD at 24 % on 390x844 | project.godot:29-32 expand; play_390x844.png | W1-UI |
| ui-mmo-01 | P0 | blocker none for layouts | C | hosting | XL | No multiplayer, social or market UI | grep finds none | W3-EXCHANGE, W3-SOCIAL |
| ui-radial-01 | P1 | | C | none | M | Radial hexes overlap each other and the HUD; clip at top | context_radial.gd:29-35; z_ring_topright.png | W1-UI, W2-HUD |
| ui-animals-01 | P1 | | C | none | S | Animals screen has zero size; no backdrop | '[aprobe] screen size=(0.0, 0.0)' | W2-SCREENS |
| ui-level-01 | P1 | | C | none | S | Three different player levels shown | HUD 0, sheet 1, fatigue 2 | W1-UI, W2-HUD |
| ui-glyph-01 | P1 | | C | none | M | System emoji glyphs (coloured on macOS/iOS) | hunt_hud.gd:208,216; craft_ui.gd:11-13 | W1-UI, W2-HUD |
| ui-settings-01 | P1 | | C | none | M | No settings screen | world_ui.gd:220-226 | W2-HUD |
| ui-gates-01 | P1 | | C | none | M | UI labs pass while screens are broken | '[uishot] PASS' with zero-size Animals | W1-UI |
| ui-inventory-01 | P1 | | P | other_session | L | Bag far below ARK (no names, drag, sort, rarity, preview) | inventory_1600x900.png | W2-SCREENS, W1-ICONART |
| ui-taming-01 | P1 | | P | none | M | Creature plates and taming feedback unfinished | z_capture_plate.png | W1-UI, W2-HUD |
| ui-skills-01 | P1 | | U | none | S | Skills sheet covers vitals; columns misaligned | w_p_skills.png | W1-UI |
| ui-theme-01 | P1 | | U | none | L | No Theme, brand font or UI art; 246 Color literals | game/assets/fonts | W1-UI, W1-ICONART |
| ui-typo-01 | P2 | | U | none | S | Metadata drawn at 9-11 px | hex_button.gd:105 | W1-UI |
| ui-center-01 | P2 | | U | none | S | Centred draw_string calls shifted right | status_glyph.gd:32 | W1-UI |
| ui-labels-01 | P2 | | U | none | M | World labels overlap and leak raw ids | gather_radial_live.png | W2-HUD |
| ui-craft-01 | P2 | | U | none | M | Craft screen misleading levels, raw names, repeated buttons | craft_1600x900.png | W1-UI |
| ui-status-01 | P2 | | U | none | S | Status badges are 2-letter codes | z_status_badges.png | W2-HUD |
| ui-notice-01 | P2 | | U | none | S | Every notice is danger red | hunt_hud.gd:1024 | W2-HUD |
| ui-modal-01 | P2 | | U | none | S | Modals do not hide the HUD | held_craft.png | W2-HUD |
| ui-map-01 | P2 | | U | none | M | Atlas rough (diamond, shared legend colours, raw ids) | w_p_map.png | W1-UI |
| ui-combat-01 | P2 | | U | none | M | Combat hexes scattered, overlapping captions | z_combat_cluster.png | W2-HUD |
| ui-gamepad-01 | P2 | | U | none | M | No UI focus, so no controller menus | grep grab_focus = 0 | W1-UI, W2-SCREENS |
| ui-hud-01 | P2 | | U | owner_decision | L | HUD hand-drawn in 1,376 lines; no hotbar or key hints | hunt_hud.gd:906-1036 | W2-HUD |
| ui-charcreate-01 | P2 | | U | other_session | M | Character creation has no art or preview | w_p_charcreate.png | W2-SCREENS |
| ui-death-01 | P3 | | U | none | S | Death screen offers one option | death_1600x900.png | W2-HUD |
| ui-icons-01 | P3 | | U | none | S | 5 items have no icon | icon coverage script | W1-ICONART |

### Physics, collision and hit detection (physics)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| phys-hit-01 | P0 | | C | none | M | Melee resolves through walls both ways | '[ring] t=5.40 raptor BIT player ... same_side=false' | W1-COMBAT |
| phys-body-01 | P0 | | C | none | L | One upright hip capsule; head/tail have no volume | T. rex 19.37 m long vs 5.76 m capsule; trex_zoom.png | W2-CVIEW |
| phys-climb-01 | P1 | P2 (cause: _unstick) | P | none | S | Survivor climbs onto small dinosaurs | '[climb2] ... stuck=2.02 ... floor_col=Creature' | W2-PLAYER |
| phys-corpse-01 | P1 | | C | none | S | Carcasses float 0.9 m on their own cylinder | 'gap=0.90 ... floor_collider=Corpse_velociraptor' | W1-AI |
| phys-wall-01 | P1 | | C | none | M | Player walls not passable for the player; gates solid | 'escaped=false ... nav_active=true' | W2-BUILDSYS, W2-PLAYER |
| phys-reach-01 | P1 | | C | none | S | Pets cannot reach large targets | 'vs triceratops dmg_dealt_8s=0' | W1-AI |
| phys-kick-01 | P1 | P2 | C | none | S | Kick ignores mass; T. rex cannot be kicked | 'tarbosaurus ... kick-moved=3.33m' | W1-COMBAT |
| phys-net-01 | P1 | | P | hosting | XL | No authoritative hit model | client randf in combat | W3-SRVACT |
| phys-perf-01 | P1 | P2 | C | none | S | Separation steer O(N²) and effectively dead | 'movers=320 ... 21.52 ms' | W1-AI |
| phys-path-01 | P2 | | U | none | M | Silent partial paths; wedging | ring_exit nav=true for 10 s | W1-BUILD, W2-PLAYER |
| phys-spawn-01 | P2 | | U | none | S | Bodies simulated at parent origin for one step; ~90 m/s launch | 'v=(71.5, 53.96, 0.0)' | W2-PLAYER |
| phys-melee-02 | P2 | | U | none | M | Instant 360° melee ignoring height | hunt.gd:120-159 | W1-COMBAT |
| phys-aoe-01 | P2 | | U | none | S | AoE and traps measure to feet origin | siege_projectile.gd:56 | W1-COMBAT, W2-PLAYER |
| phys-turn-01 | P2 | | U | none | S | Every species turns at the same rate | creature.gd:158-165 | W2-CVIEW |
| phys-layers-01 | P2 | | U | none | M | Everything on layer 1 with ad-hoc exceptions | project.godot no layer names | W2-INT, W2-WEB2, W2-CVIEW |
| phys-mount-01 | P2 | | U | other_session | M | Mount steering overwritten by the creature | creature.gd:266-298 | W2-PLAYER, W2-CVIEW |
| phys-proj-01 | P3 | | U | none | S | Stone shot straight, no drop | stone_projectile.gd:24-41 | W4-WORLD |
| phys-node-01 | P3 | | U | none | S | Fixed node colliders; regrow under players | harvest_node.gd:85-94 | W1-ITEMS |
| phys-test-01 | P3 | | U | none | S | Physics labs test bookkeeping, not motion | pet_passthrough_lab exception lists | W1-COMBAT, W1-QA |

### Performance, LOD, loading, memory (performance)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| perf-payload-01 | P0 | P1 | C | none | L | Single ~303 MB web pack, re-downloaded on any change | pack.manifest size 317,479,824; gzip 0.97 | W1-WEB, W2-WEB2 |
| perf-veg-01 | P0 | P1/P2 (LOD works) | P | none | M | Island-wide vegetation MultiMeshes never culled, all cast shadows | veg_batch.gd:30-31; LOD probe 794k vs 5.24M | W1-WEB |
| perf-ai-01 | P0 | P1 | P | none | L | Per-creature CPU ~0.1 ms, no AI/anim LOD | 'physics_ms 14.75' at 129 bodies | W1-AI |
| perf-spawn-01 | P1 | | C | none | M | Animation library rebuilt per spawn (5-200 ms) | rigged_model.gd:151-166 | W2-PANIM |
| perf-path-01 | P1 | | C | none | S | Full TilePath rebuild 440-572 ms per change | 'tilepath _rebuild = 444.4 ms' | W1-BUILD |
| perf-nav-01 | P1 | | C | none | S | Unused navmesh baked on every island load (1.9 s) | 'nav bake (sync ...) = 1904.3 ms' | W2-TERRAIN |
| perf-tex-01 | P1 | | P | none | M | 8 bpp UASTC, no RDO, 3-4 textures per prop | 220.7 MB of ctex in the pack | W1-WEB |
| perf-load-01 | P1 | | C | none | M | Synchronous loads with no progress | boot.gd:367; world.gd:117-128 | W2-TERRAIN, W2-WEB2 |
| perf-anim-load-01 | P1 | | C | none | S | DirAccess clip discovery misses 12 clips in exports | pack lists only *.glb.import | W2-PANIM |
| perf-gate-01 | P1 | | C | none | S | No performance or payload budget in any gate | production_soak.mjs black-frame check only | W1-QA |
| perf-survivor-01 | P1 | | U | other_session | S | 8 survivor clip GLBs embed the mesh and a 5.6 MB texture | glbstat | W2-PANIM |
| perf-fx-01 | P2 | | U | none | S | Particles draw 4,224-tri spheres | '[sphere] ... tris=4224' | W1-LIGHT, W2-VFX |
| perf-shadow-01 | P2 | | U | renderer | S | Web shadow settings at desktop defaults | no .web override | W2-WEB2 |
| perf-mesh-01 | P2 | | U | none | M | Creatures over PRD polycount; 514/516 materials double-sided | target 12000; tris 20.7k | W2-RERIG |
| perf-range-01 | P2 | | U | none | S | Visibility ranges anchored to island origin; creature ranges off | island_runtime.gd:961 | W2-SCATTER, W2-CVIEW |
| perf-hud-01 | P2 | | U | none | S | HUD redraws every frame | hunt_hud.gd:903-904 | W2-HUD |
| perf-overlay-01 | P3 | | U | none | S | Perf overlay thin and overlaps vitals | main_debug_perfcrop.png | W2-INT |
| perf-log-01 | P3 | | U | none | S | 219 print calls in runtime paths | rigged_model.gd:202 | W1-AI, W2-PANIM |
| perf-decal-01 | P3 | | U | renderer | S | Textureless decals spawned and render nothing | creature.gd:403 | W1-COMBAT, W2-VFX |
| perf-export-01 | P3 | | U | none | S | all_resources export ships dev labs and refs | export_filter all_resources | W1-WEB |

### Security and abuse (security)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| sec-mint-01 | P0 | blocker none (decided v2) | P | owner_decision | XL | Every item, pet, T-stone minted client-side | 'FORGED-LOAD bag ... raid_helm x5000 L9999' | W1-SRVDOM, W3-SRVACT |
| sec-sybil-02 | P0 | P1, hosting | P | owner_decision | L | Free unlimited accounts multiply faucets and caps | contracts §3; 28 objectives = 72 | W1-INT, W2-INT, W4-HOST |
| sec-pets-03 | P0 | dup of sec-mint-01 | P | owner_decision | L | Pet grade, IVs, stats rolled and stored client-side | field_tame.gd:149 | W1-TAME, W3-SRVACT |
| sec-save-05 | P1 | P2 | P | none | M | Save loader trusts every field | 'stone x-7'; 'sp_available=99999' | W1-SAVE |
| sec-corrupt-06 | P1 | | C | none | S | Truncated/newer save starts a new world; autosave destroys the old one | '[vprobe] t=63 ... on_disk_schema=3.0' | W1-SAVE |
| sec-xpfarm-07 | P1 | | C | none | S | Infinite Butchering/player XP from loot taps with a full bag | 'XPFARM 50 take clicks ... delta 150' | W1-AI, W2-PLAYER |
| sec-loss-08 | P1 | | C | none | M | Eight paths destroy items or pets when the bag is full | 'CRAFT-FULL fence_kit: branch 10->8 fence_kit_in_bag=0' | W1-ITEMS, W1-BUILD, W1-TAME, W2-PLAYER, W2-INV |
| sec-replay-09 | P1 | P2, hosting | P | hosting | S | 64-entry rid cache; ws:// transport | market_rules.json rid_cache 64 | W1-INT, W4-HOST |
| sec-move-10 | P1 | P2, blocker none | P | other_session | M | Teleport check is one 1.6x bound; mounts rejected | contracts §7 | W1-INT, W3-SRVWORLD |
| sec-gather-11 | P1 | | U | hosting | XL | Gather/craft/tame rates client-only | player.gd:952-998 | W3-SRVACT |
| sec-auction-12 | P1 | | U | none | M | Anti-snipe capped at 10; no shill defence | contracts §6.3 | W4-ECONH |
| sec-admin-13 | P1 | | U | none | M | No provenance, rollback, freeze or claw-back tooling | contracts has no admin ops | W4-HOST |
| sec-wallet-14 | P2 | | U | none | S | T-stones are a plain client variable | world.gd:164,251,274 | W3-SRVACT |
| sec-clock-15 | P2 | | U | none | S | Offline progress trusts device clock | '[farm] offline catch-up 1792359975s' | W1-SAVE |
| sec-skill0-16 | P2 | | U | none | S | Skill 0 removes the crafted-level cap | crafting.gd:135-145 | W1-ITEMS |
| sec-neg-17 | P2 | | U | other_session | S | Negative and zero amounts accepted | 'remove_at(idx,-100): bag_branch=108' | W2-INV |
| sec-buyorder-18 | P2 | | U | none | S | Buy orders filled by poisoned/near-broken units | limits.json allowed_flags | W2-INT |
| sec-webpack-19 | P2 | | U | none | S | Clients ship dev labs; load any listed pack | pack lists scripts/dev/*.gd | W1-WEB |
| sec-shell-20 | P2 | | U | none | M | Public manifest, unsigned packs, optional checksum | boot.gd:241-246 | W1-WEB |
| sec-time-21 | P2 | | U | none | S | Auction settlement boundary undefined | contracts §5.2 | W2-INT |
| sec-craft-22 | P3 | | U | none | S | Recipe switch mid-craft uses old inputs | station_craft.gd:159-168 | W1-ITEMS |
| sec-eat-23 | P3 | | U | none | S | Cancel a meal at 99 % keeps energy, skips raw risk | eat_session.gd:57-88 | W1-ITEMS |
| sec-names-24 | P3 | | U | none | S | No impersonation or chat-abuse controls | contracts §3, §7 | W1-INT, W3-SOCIAL |
| sec-deposit-04 | refuted | | | | | Deposit/withdraw two-ledger dupe without cheating | refuted by verifier | none |

### QA and test infrastructure (qa)

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| qa-soak-01 | P0 | | C | none | S | Production soak cannot pass (travel hangs on a Survival gate) | 'SOAK FAIL: timed out ...' after 'Needs Survival 20' | W1-QA |
| qa-mmo-01 | P0 | | C | none | XL | No server, market or multiplayer test infrastructure at HEAD | game/tests holds run_all only | W1-INT, W3-NETQA |
| qa-runner-01 | P1 | | C | none | S | Runner and smoke report PASS when a test crashes | 'SCRIPT ERROR ...' then '[tests] PASS reached=1' | W1-QA |
| qa-labs-01 | P1 | | C | none | M | Most labs and probes cannot fail | 7 of 21 exit 0 regardless; 3 never exit | W1-QA |
| qa-flaky-01 | P1 | P2 | P | none | S | raid-gear-probe flaky (unseeded boss genetics, shared save) | 4 of 6 runs fail | W1-ITEMS, W1-SAVE |
| qa-hermetic-01 | P1 | | C | none | S | Shared save, run-order dependence, hardcoded /tmp | world.gd:89-92; ui_screenshot_lab.gd:5 | W1-SAVE, W1-QA |
| qa-savesafety-01 | P1 | | C | none | S | Save isolation only via an untracked override.cfg (missing in several worktrees) | main checkout and survivor-v2 worktree lack it | W1-SAVE |
| qa-render-01 | P1 | | P | none | M | No gate runs the web renderer before deploy | creature_lab_compat.png overexposed | W1-LIGHT, W1-QA |
| qa-visual-01 | P1 | P2 | P | none | M | No golden or exposure checks on screenshots | soak checks lit>=12 only | W1-UI, W1-QA |
| qa-save-01 | P1 | | C | none | M | Save path barely tested | 2 tiny fixtures; no v3 golden | W1-SAVE |
| qa-ai-01 | P1 | | U | none | M | AI radius rule checked for 2 of 19 species | ai_validation_lab spawns 3 species | W1-AI |
| qa-spec-01 | P1 | | U | none | S | Tests take expected values from code (60 s pet cooldown) | pet_record.gd:24 vs GAUNTLET:73 | W1-QA, W1-TAME |
| qa-smoke-01 | P1 | | U | none | S | Smoke never builds the real world | world.gd:79-80 | W1-QA |
| qa-ci-01 | P1 | | U | none | M | CI on 4.7.0, main/PR only, unit+smoke only | ci.yml | W1-QA |
| qa-craft-01 | P1 | | U | none | S | Crafted-level cap untested | run_all.gd:392-393 | W1-ITEMS |
| qa-tame-01 | P1 | | U | none | S | Taming rule partly tested; capture lab asserts nothing | capture_lab.gd:101-102 | W1-TAME |
| qa-noise-01 | P2 | | U | none | S | Passing runs full of ERROR/WARNING lines | 'RID allocations ... leaked' | W1-QA |
| qa-uifamily-01 | P2 | | U | none | S | ui_family_lab depends on private fields | ui_family_lab.gd:38-39 | W2-SCREENS |
| qa-runner-02 | P2 | | U | none | M | Hand-wired unit file; no discovery or per-test report | run_all.gd:6-53 | W1-QA |
| qa-perf-01 | P2 | | U | none | M | No perf budgets gated | layout_perf_lab thresholds absent | W1-QA |
| qa-stamp-01 | P2 | | U | none | S | Soak never checks which build it tested | production_soak.mjs | W1-QA |
| qa-bot-01 | P3 | | U | none | S | Bot exits 0 on PARTIAL; misleading reason | bot_survivor.gd:98 | W1-QA |

### Sound and audio (audio) — being built by the running 1a-audio package

| ID | Sev | Adj | V | Blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| audio-core-01 | P0 | blocker resolved (CC0 approved) | C | owner_decision | L | Game completely silent | 0 audio files; 1 empty Master bus | 1a-audio -> W1-INT |
| audio-combat-02 | P0 | | C | none | L | Combat silent | hooks exist, nothing plays | 1a-audio -> W1-INT |
| audio-creature-03 | P0 | | C | none | XL | No creature voices | no voice field; _set_state emits nothing | 1a-audio, W1-AI (state_changed) |
| audio-ambience-04 | P1 | | C | none | L | No ambience per climate or day phase | no listeners on day_phase_changed | 1a-audio |
| audio-music-05 | P1 | | C | none | L | No music system | grep music = 0 | 1a-audio |
| audio-settings-06 | P1 | | C | none | M | No volume sliders or mute | pause_menu_1600x900.png | W2-HUD |
| audio-ui-07 | P1 | | C | none | M | UI interactions silent | HexButton.pressed silent | 1a-audio |
| audio-footsteps-08 | P1 | | C | none | M | No footsteps | TileType grid exists | 1a-audio, W2-PLAYER |
| audio-gather-09 | P1 | | P | none | M | Gathering, butchering, farming silent (fishing does not exist) | harvest_node.gd:428-434 | 1a-audio |
| audio-build-10 | P1 | | C | none | M | Building, stations and siege silent | build_placer.gd hooks | 1a-audio, W2-PROCESS |
| audio-deafened-11 | P1 | | U | none | S | Deafened's mute effect never applied | statuses.json fx mute unused | 1a-audio |
| audio-spatial-12 | P1 | | U | none | S | Listener would be the camera 40 m away | iso_camera.gd:7 | 1a-audio, W2-PLAYER |
| audio-bus-13 | P1 | | U | none | S | No bus layout, limiter or ducking | bus_count=1 | 1a-audio |
| audio-web-14 | P1 | | U | none | M | Web audio constraints unplanned | playback_type.web=1; no threads | 1a-audio, W2-WEB2 |
| audio-mmo-15 | P1 | | U | none | M | No audio plan for networked events | contracts evt names | W3-SOCIAL |
| audio-player-16 | P2 | | U | none | M | Survivor has no voice or vital sounds | vitals.gd signals | 1a-audio, W2-PLAYER |
| audio-pets-17 | P2 | | U | none | M | Taming and pet commands silent | creature.gd:6 captured | 1a-audio |
| audio-telegraph-18 | P2 | | U | none | S | Telegraphs visual only | tyrant_brain.gd:48-51 | 1a-audio |
| audio-weather-19 | P2 | | U | none | L | No weather audio (no weather system) | rain only | W2-WEATHER |
| audio-licence-20 | P2 | | U | none | S | No provenance ledger or credits path | credits.json in WIP | 1a-audio, W2-HUD |
| audio-proof-21 | P2 | | U | none | S | No way to prove audio in tests | no audio lab | 1a-audio |
| audio-mobile-22 | P3 | | U | none | S | Backgrounding not handled for audio | game.gd:154-160 | 1a-audio |
