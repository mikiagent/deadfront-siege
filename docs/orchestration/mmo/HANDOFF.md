# DEADFRONT MMO program: handoff (2026-10-20)

Read this first when you pick the work up in `~/Documents/deadfront`. It says where everything is, what is
merged, what is half done and on which branch, what has not started, and the rules that bit us.
The program's running memory is `docs/orchestration/mmo/STATUS.md` (owner decisions, waves, merge log);
the package specs are in `docs/orchestration/mmo/plan-register.md`; the owner's design input is
`docs/design/durango-prompts/01`-`12`.

## 0. How every request is run

**The gauntlet loop applies to every request**: `GAUNTLET.md` at the repo root, section "The gauntlet loop - run
this on every request" (translate -> ground -> classify risk -> reproduce -> implement narrowly -> prove behavior ->
prove appearance -> deploy the exact commit -> verify the production stamp -> report bluntly), its "Gauntlet
completion test" (done only when a new tester can reload production and see the requested outcome) and its
"Next-request prompt frame" (Classification / Outcome / Binding details / Ground first / Implementation boundary /
Acceptance / Required evidence).

Where GAUNTLET.md (written 2026-09-21) is out of date, these newer owner decisions win:
- **Ground against `claude/mmo-overhaul`**, the integration branch, not `origin/main`, until PR #17 is merged.
- **Phone checks are landscape 844x390**, not portrait 390x844; desktop Chrome 1600x900 stays the judge.
- **Deploy only when the owner says.** Current condition: deploy once the UI package passes (lighting already
  merged). Steps 8-9 of the loop wait for that; everything else runs on every request.
- **The Durango prompt pack** (`docs/design/durango-prompts/01`-`12`) and `docs/reference/durango-*` extend the
  visual gauntlet as binding design input.

**The program loop.** The multi-package program ran under this `/loop` prompt (self-paced, "Ultracode" means a
workflow per substantive task with independent review and blind A/B judging):

```text
/loop Continue the DEADFRONT AAA survival-MMO program in /Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-overhaul: read docs/orchestration/mmo/STATUS.md, run the next wave (implement in parallel worktrees → independent critical review → fix → integrate → tests/smoke/labs → real screenshots inspected), update STATUS.md, and stop only when every system meets its acceptance criteria or is blocked on an owner decision. Ultracode.
```

To continue it from this folder, use the same prompt with the path changed to `~/Documents/deadfront` (the
integration branch is now this checkout, not the old `.claude/worktrees/mmo-overhaul`).

## 1. Where things are

| What | Where |
|---|---|
| Your working folder | `~/Documents/deadfront` = clone of GitHub `mikiagent/deadfront-siege`, branch `claude/mmo-overhaul` |
| Integration branch | `claude/mmo-overhaul` (on GitHub; draft PR [mikiagent/deadfront-siege#17](https://github.com/mikiagent/deadfront-siege/pull/17) to `main`, not to be merged until you say) |
| Package branches (local only) | in the old repo `~/Documents/deadfront-siege`; in your folder they are reachable through the git remote `local` (`git fetch local`, then `git switch -c <name> local/<branch>`) |
| Old folder | `~/Documents/deadfront-siege`: your main checkout still holds an uncommitted UI pass (hunt_hud.gd, inventory_ui.gd, animal_screen.gd, item_icons.gd) that nobody touched; all package worktrees live in `.claude/worktrees/mmo-*` |
| Production web build | Vercel, last deploy 2026-10-18 `548804ac8/f34e148e39` (survivor v2 + armor + T. rex mount; none of wave 1). You asked to deploy again only after lighting AND UI pass: lighting is merged, UI is not yet |
| Godot | `/Applications/Godot_mono.app/Contents/MacOS/Godot` 4.7.1 Mono, typed GDScript, `game/` is the project |

## 2. Merged into `claude/mmo-overhaul` (every test passes on it)

Every `game/tests/t_*.gd` prints PASS, `run_all.gd` prints `[tests] PASS`, `tools/smoke.sh` prints `SMOKE PASS`;
island/build/harbour labs run with 0 SCRIPT ERROR; merge screenshots inspected at 1600x900 and 844x390.

- Wave 1: W1-TAME, W1-CANIM, W1-BUILD, W1-ITEMS, W1-WEB, W1-AI, W1-LIGHT (fixes "too bright"), W1-COMBAT,
  W1-SAVE, W1-HARBOUR (coast-forced, pier on water), W1-STRUCTART (Blender building set) plus its camp hooks,
  W1-ICONART (122 rendered item icons with rarity rims; NOT yet shown in the bag/craft screens, see W1-WIRE).
- Survivor v2, armor slots, T. rex mount (merged before wave 1).
- Creature clips: dsc re-animations for velociraptor, utahraptor, protoceratops/megaloceros (combat/ground/rest),
  compsognathus, coelophysis, gallimimus; DSC-CLIPS (zebraceratops combat/ground, grounded T. rex sleep).
- DSC-MINORS (38 review minors), Codex fixes: harbour (travel to a moved dock, basket follows, walkable pier,
  site check) and the Animals screen (0x0 rect / no backdrop).

## 3. Half done: branch, state, next step

Branch names are `claude/<name>`; "+N" = commits not yet in `claude/mmo-overhaul`. Open review findings are in
`docs/orchestration/mmo/handoff/findings/`.

| Package | Branch | State | Next step |
|---|---|---|---|
| W1-UI (phone layout, theme, readable glyphs) | `mmo-w1-ui` (+61) | Reviews r1-r3 failed on landscape-phone HUD overlaps; a 4th fix round was committed ("W1-UI review 10") but not re-reviewed. Owns hunt_hud.gd + inventory_ui.gd by orchestrator decision; new survivors show Lv. 1; the Lv-1 title is held from character creation | Re-review; check `findings/w1-ui-review-r3.json` and `w1-ui-second-reviewer-r2.json` are all closed; merge; then deploy (your condition) |
| W1-UIICONS (white action icon set) | `mmo-w1-uiicons` (+15, 119 behind) | Icon redraws done; the HUD wiring step waits for W1-UI (it may then edit hunt_hud/creature_plates) | After UI merges: merge the base in, wire the icons into the real HUD (keep captions, no Label .icon in plates), review, merge |
| W1-WIRE (not a branch yet) | - | ArtSlot/ItemArt exist but the bag, craft and market slots still draw old symbols | After UI: swap inventory_ui/item_icons/craft slots to ArtSlot + ItemArt.texture_for |
| DSC-CAMP (18 Blender camp pieces) | `mmo-camp` (+10) | Built by DeepSeek, gate passed; review r1 found the game's 0.08 m dirt disc hides 73-76 % of the fields (and half the bedroll, ember beds); minors: bed 1.56 m, fortified fence lower than the plain one, shelter doorway 1.49 m, field collider 0.82 m tall. A Claude fix round started (WIP commit: field lift / disc skip / preview disc) | Finish `findings/dsc-camp-review-r1.json`, re-review with in-game shots; SQUASH-merge only in-scope paths (drop `work/` previews, root TASK.md, stray .uid, 6 Meshy .import changes) |
| DSC-QUADS2 (protoceratops/megaloceros walk/run) | `mmo-quads2` (+2) | DeepSeek clips passed every gate (strides in mesh units, no crouch, skin stretch in bounds; megaloceros run 71 % of target due to rig reach, so the game time-scales it x1.4 instead of today's x7-16); copied into the game, KNOWN_GLIDERS emptied | Review (look at walk/run in game), merge. Source job: `~/Documents/DeepseekCLI/deadfront-reanim/quads-loco2/` |
| ICONS2 (32 missing + 33 weak item icons) | `mmo-icons2` (+10) | DeepSeek rendered the 17 raw materials (pass) and some kit/cage renders, then was stopped (no milestone in 3.5 h). Gate: `tools/dsc/verify_icons2.sh`; brief: TASK.md in that branch | Finish the 15 kits/feed/cage items (captured animal = in a cage) and the 33 flagged; full gate; squash-merge in-scope paths |
| W2-RAGDOLL (dinosaurs ragdoll on death) | `mmo-w2-ragdoll` (+5) and `mmo-w2-ragdoll-dsc1` (+7, DeepSeek profiles, stopped) | System partly built (ragdoll_lab, profiles in game/data/creatures/ragdoll.json); spec with gates in `handoff/ragdoll-spec.md` | Merge the useful dsc profiles, finish the system to the spec (settle on terrain, freeze, 4-at-once budget, fallback), review with screenshots, merge |
| W2-PLAYER (player split + PlayerActions) | `mmo-w2-player` (+21) | Built, not reviewed | Independent review, merge |
| W2-OCCLUDE (see-through occluders) | `mmo-w2-occlude` (+13, 27 behind) | Built to your correction: an occluding tree fades as a whole object to about half, no hole; roofs fade more when you are under them but keep an outline. Not reviewed | Review incl. the pixel gates (tree keeps 40-60 % of pixels, no 48x48 hole, survivor >= 50 % visible), merge |
| W2-BUILDSYS (ARK-style modular building) | `mmo-w2-buildsys` (+21) | Built with stand-in pieces from game/data/structures.json, structure HP/tiers, roofs bound to the occlusion API by an adapter. Not reviewed | Review (2-storey house shots), merge after OCCLUDE |
| W1-SRVDOM (server character store, intents) | `mmo-w1-srvdom` (+16) | Passed review r1 earlier; finishing pass done since | Short re-review, merge |
| W2-BREED (breeding, eggs, growth, cap 3->7, capture rule 09) | `mmo-w2-breed` (+3, 126 behind) | Early | Build to the spec in STATUS / finish-5.js, review, merge |
| W2-ECO (ecosystem, attack kits, structure siege) | `mmo-w2-eco` (+1, 126 behind) | Early | Build, review, merge |
| W1-QA (gates that can fail, CI file) | `mmo-w1-qa` (+16, 238 behind) | Partial; never reviewed | Merge the base in, finish, review |
| W1-BIOME (per-climate ground, foliage) | `mmo-w1-biome` (+11, 238 behind) | Partial | Merge the base in, finish, review |
| ECON (server economy engine) | `mmo-econ` (+5, 251 behind) | Built, two review rounds; last review cut. Needs contracts v2 (provenance uid+origin, caged-pet listings) | Merge the base in, v2 changes, review, merge (feeds W1-INT) |
| NET (WebSocket server, auth, presence, chat) | `mmo-net` (+7, 251 behind) | Built, last review cut; needs v2 area caps | Merge the base in, area caps, review, merge |
| AUDIO (CC0 sounds, sound settings, mute) | `mmo-audio` (+12, 250 behind) | Built + DeepSeek fixed 11 review findings and added the settings panel | Review, merge with W1-INT |
| Deinonychus rebuild | `mmo-art-deinonychus` (+1) | Concept sheet v01 approved by you | Four views -> Tripo -> rig/animate |

## 4. Not started (mapped to specs)

- W1-INT: market served over the socket, Settlers NPC orders, contracts v2.1, audio merge.
- W2: CAGE (pets as caged items, repackage/release, portraits, area caps), SURVIVAL (01 fatigue/energy/stamina),
  SKILLS (03 + 09 + 11 + 12: Durango 1-60 levels, Lv1 AUTO nodes, Animal Handling I-IV, Processing tree; import the
  918-node table as data and mark each node functional/partial/defined), INV (05/08: materials and food do not
  stack, instances), CRAFT/PROCESS/COOK (04/08/11, drying racks driven by real station state), CONSTRUCT (10),
  GATHER/BUTCHER (12 sections 1-2), FARM, TAILOR, ACTION (hybrid tap-target + action combat), DEATH (loot bag +
  gear wear), HUD/SCREENS (Durango craft/skill screens in `docs/reference/`), TERRAIN/water fixes, WEATHER, VFX.
- W3: server-simulated islands, the Exchange UI, social, net QA. W4: hosting (you decide the host), economy policy.
- Art: Tripo species from concept sheets v2 (7 species, one batch approval by you), W2-RERIG.

## 5. Rules and decisions that matter (full list in STATUS.md "Owner decisions")

- Mobile is LANDSCAPE (844x390); desktop Chrome 1600x900 on the web renderer is the judge.
- Durango pack 01-12 is binding design input; values it marks illustrative stay configurable; do not invent canon.
- Occluders are partly see-through, never a hole. Dinosaurs ragdoll on death. Building is a big deal; processing
  must be visible.
- Asset routing: Tripo only for complex creatures and characters (credits approved, existing balance only, never
  buy); Blender (headless scripts) for buildings and props.
- Workers: Claude agents do the work. DeepSeek (dsc) is off unless you ask (it stalled on open-ended jobs).
  Codex: debugging only, model `gpt-reserve` (your plan refuses gpt-6.1-sol/6-sol/6-luna), one bug per job.
- Tests make no sound; never touch `~/Library/Application Support/Godot/app_userdata` (your real save).
- Push to GitHub when work is done (authorized); deploy only when you say (currently: after UI passes).

## 6. How to run things

Your folder has NO `game/override.cfg`, so Godot there uses your real save. For agent test runs, first add a
git-excluded override so tests use their own user dir:

```bash
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="deadfront-dev"\n' > game/override.cfg
echo game/override.cfg >> .git/info/exclude
```

- Tests: `Godot --headless --path game --script res://tests/run_all.gd` and each `res://tests/t_*.gd`.
- Smoke: `tools/smoke.sh --no-import` (must print SMOKE PASS).
- Labs: `Godot --headless --path game -- --lab=<name>`; screenshots: `Godot --path game --resolution 1600x900 -- --lab=home_lab --shot=<png> --shot-delay=6` (add `--rendering-method gl_compatibility` for the web renderer).
- After merging new assets or class_name files run `Godot --headless --path game --import` once; a stale
  `.godot` cache shows up as missing-resource ERRORs that look like code bugs.
- Web export/deploy: `tools/export_web.sh`, `tools/deploy_web.sh` (Vercel); verify the alias stamp after deploying.
- `handoff/scripts/gslot.sh` (5 shared Godot slots, silent audio, 20-minute ceiling) and `mkwt.sh` (package
  worktree with a cloned, re-imported cache) were the multi-agent helpers; their paths point at the old session
  scratchpad, so adjust them before reuse.

## 7. Pitfalls we hit

- Usage limits cut workflows mid-run; agents commit WIP often, and after a cut check for hung Godot runs.
- Resuming a parallel workflow re-runs finished agents (the replay prefix breaks); restart from each package's
  real state instead (see `handoff/workflows/finish-5.js` for the last orchestration script).
- Never message a running workflow agent: it forks a second copy.
- Codex sandbox: needs the repo's `.git` dir writable to commit, and cannot open a display (headless only).
- Clips: skeleton-only GLBs WITH the skin; re-import after replacing them; strides are in MESH units.
