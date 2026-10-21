# W2-BUILDSYS: ARK-style modular building with structure HP, tiers and repair

Branch `claude/mmo-w2-buildsys`, base `claude/mmo-overhaul` merged in (last to base tip 809be2e8, which brought
HUD-DAYNIGHT and the W2-DATA sync; see resume pass 4). Review r1 stopped before any run.
Closes build-struct-01, build-def-01, build-tier-01, build-place-02, phys-wall-01, build-storage-01 (chest and
large box), build-sign-01 (signboard with text), dino-ai-17 (with hook 3 below).

## Owner gate: save schema 3 -> 4

`save_migrations.gd` raises `CURRENT_SCHEMA` from 3 to 4, with a `_v3_to_v4` step that only sets the version.
plan-register.md:660 and :672 prescribe it ("save schema 4 for piece rows", "an old schema-3 save migrates"),
but STATUS records no owner approval. The shared rules list "a rev bump" as an owner gate. W2-INV's save change
got its own approval (STATUS:325).

- **What it does.** Old saves load unchanged. The new rows are optional: pieces, `durability` on worn kits, and
  loot bags. The bump only matters on a rollback. An older build then refuses a schema-4 save: it quarantines
  the file and falls back to `.bak`.
- **Without the bump**, an older build would load the save and refund the piece rows as unknown kinds.
  `SaveRestore._items_of` gives back a row's `contents` (chest items go to camp cargo), but a piece has no kit
  to refund. The house and the materials it cost would be gone at the next save.
- **Asked of the owner:** approve the 3 -> 4 bump (recommended). Or say keep schema 3, and accept that a
  rollback build drops houses without refunding them.

## Resume pass 4 (2026-10-21, base 809be2e8)

- **Base**: merged 809be2e8 (9ad13ce0), 17 commits: HUD-DAYNIGHT (day/night dial, `hunt_hud.gd`, `lab_kit.gd`) and
  the W2-DATA sync (docs and its patch). The merge had no conflicts and no game file of this package changed.
  W2-PROCESS is still unmerged. Its branch (f7ec5239) does not touch `build_placer.gd`. `git merge-tree` of it
  against this branch is clean. Its `salvage_contents() -> Array[ItemStack]` (craft_station.gd:48,
  process_station.gd:288) and `pack_up_block_reason()` still match the duck-typed calls here
  (`structure_health.gd:120`, `build_placer.gd:302`). The branch keeps the `pack_up_block_reason()` check.
- **Hooks patch, regenerated** (508f48ec). HUD-DAYNIGHT moved the `hunt_hud.gd` hunk down 4 lines
  (`@@ -798,17 +798,27 @@`). The body is byte-identical apart from that hunk header and the index lines. Checked
  through a throwaway index: `APPLY OK on 809be2e8` and `APPLY OK on 9ad13ce0`, with no offsets.
- **Hook 4**: the base still has no lab registry (`fatal: path 'tools/labs.txt' does not exist in
  'claude/mmo-overhaul'`). Labs load by scene name (`--lab=snap_build_lab`), so the patch has no hook 4. The two
  rows for W1-QA's file, for when it lands, are under Integrator hooks.
- **Docs**: re-read on the merged tree, unchanged. Spec 10:90 "level-60 Large Leaf Box holding 160 spaces. Do not
  impose this value on every box". Spec 05:14 "basket about 100 slots; level-60 Large Leaf Box up to 160". PRD:582
  "baskets (~100 slots early) → boxes → large boxes". Spec 10:102 "must not silently delete stored items". Spec
  11:155 "Handle demolished stations ... without losing items". No doc gives a sign length. So `structures.json`
  keeps chest 100 and large box 160 (flat, `# ASSUMPTION` until building level exists), and the signboard keeps
  48 characters (`# ASSUMPTION`, `structure_piece.gd:195`). Vision fixes 1 and 2 stay as shipped in 2c993dda.
  `grep -rn "lost (logged)" game/scripts` finds nothing. Every `queue_free` of a piece or kit goes through
  `spill_storage`/`salvage`, or through pack-up, which returns everything to the bag or refuses.
- **Gates**: scratch tree `trees/bs6-gates` (mkscratch at 9ad13ce0 with the hooks patch). Logs and PNGs are in the
  72cebc8b scratchpad under `bs6/`.
  - `--import`: exit 0, 0 SCRIPT ERROR, 0 "Failed to compile".
  - All 24 `t_*.gd` exit 0 with their PASS line and 0 SCRIPT ERROR, except t_save's 5 deliberate ones (`[t_save]
    PASS`, `round trip save_v3_golden.json fields=23 diffs=0`). New since the last pass: t_daynight_dial
    (`[t_daynight] PASS`).
  - t_buildsys: `ok repair_upgrade`, `ok furniture`, `ok salvage`, `ok snap_resources`, `[t_buildsys] PASS`.
  - run_all: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- **Labs (headless)**, each exit 0 with 0 SCRIPT ERROR and 0 "couldn't resolve track":
  - snap_build_lab: `[snap] PASS`, including `schema 4 save holds 59 piece rows (got 59)`, `load restores every
    piece: 59/59, 0 differ`, `the chest comes back with its 7 stone`, `a schema-3 save migrates to 4`.
  - `--snap-touch`: `[snap] PASS`.
  - build_lab: `[build] PASS`.
  - siege probe (`-- --siege-probe`): `[siege] destroyed-after=12s occupancy-cleared=true`.
- **Fail on old behaviour**, redone on the merged code. `bs3/mutate.sh` put back the six old behaviours in the
  gates tree: lost (logged), 20/40 slots, no `salvage_contents()`, repair and upgrade that check the cost but do
  not pay, and no resource rule. t_buildsys then exits 1 with `[t_buildsys] FAIL count=21`, among them:
  - `FAIL demolish: item l5f8dbc8f769cd6d2 is kept exactly once (seen 0 times)`
  - `FAIL destroyed by a raptor: item leb61133685d8d5a0 is kept exactly once (seen 0 times)`
  - `FAIL loot bags load with the same 0 instances (got 0)`
  - `FAIL destroyed kits: item ldd53794e2398d5f6 is kept exactly once (seen 0 times)`
  - `FAIL a chest holds at least 100 (PRD:582 baskets ~100 early; got 20)`
  - `FAIL repair took exactly its cost of plank`, `FAIL the upgrade took exactly its 8 stone (left 8)`
  - `FAIL a foundation ghost aimed at a tree is never valid on its module (try 1: )`

  `git checkout` restored the files afterwards (`git diff --stat -- game/scripts/world game/data` is empty).
- **Pixels (windowed, each one looked at)**:
  - `house_fwd.png` / `house_glc.png` (1600x900): the snapped 2-storey plank house, with gable roof, storey band,
    framed door, windows on both storeys and a stone ramp. The two renderers match. The new day/night dial sits
    left of the minimap.
  - `inside_fwd.png` / `inside_glc.png`: the roof and upper storey fade to a dithered outline, and the front wall
    fades to a blue dither. The survivor inside is still hard to see: the label and ring read, the body barely
    does. This is W2-OCCLUDE's look, unchanged here.
  - Touch at 844x390 on gl_compatibility (`--touch --snap-touch`): `[snap] PASS`, with all 19 touch ok lines.
    - `touch_ghost.png`: the ghost, snap points, ROTATE/PLACE/CANCEL hexes, and the whole cost label "Wood
      Foundation plank ×6 · twine ×3".
    - `touch_card.png`: Wood Wall 1200/1200, "Upgrade to Stone / stone ×8 · plank ×2", "Demolish / half back",
      "Building to Stone (5) / stone ×40 · plank ×11".
    - `touch_house_card.png`: Wood Door 600/600, with Open door, Upgrade, Demolish and "Building to Stone (45) /
      stone ×344 · plank ×88".
    - `touch_sign.png`: the chest and the signboard on the new foundations.
    - `touch_chest.png`: the bag panel opens, but the chest grid is below the fold (the known limit, W2-SCREENS/
      INVUI). The HUD hexes and now the day/night dial draw over the panel.
    - The lab's LEVEL UP banner covers the top of the phone screen (a dev fixture).
- **Crash reports**: no new `~/Library/Logs/DiagnosticReports/Godot-*.ips`. The before and after listings are
  identical (25 files, newest `-232613`).

## Resume pass 3 (2026-10-21, base ddaab662)

- **Base**: merged ddaab662 (c2e9c7ac), 113 commits: W2-DATA, W2-SKILLS, WATER and docs. The merge was clean, with
  no conflicts. W2-PROCESS is still unmerged and its branch (6081da84) does not touch `build_placer.gd`. The base's
  `pack_up_blocker` still calls `pack_up_block_reason()`, and the branch keeps it. W2-PROCESS's
  `ProcessStation`/`CraftStation.salvage_contents()` and `pack_up_block_reason()` still match the duck-typed calls
  here.
- **Hooks patch, regenerated** (ca0c5529). W2-SKILLS moved t_save's v3 golden comparison into `_check_v3_golden`,
  so hook 5 now sits there: the same `/schema` skip and the same current-schema check. Hooks 1-3 are unchanged
  apart from line offsets. Checked through a throwaway index: `APPLY OK on ddaab662` and `APPLY OK on HEAD
  c2e9c7ac`.
- **Hook 4**: the base still has no lab registry (no `tools/labs.txt`), so nothing needs registering. The rows
  for W1-QA's file are under Integrator hooks.
- **Docs**: I re-read the cited lines on the merged tree, and they are unchanged.
  - Spec 10:90: "level-60 Large Leaf Box holding 160 spaces. Do not impose this value on every box".
  - Spec 10:102: "must not silently delete stored items".
  - Spec 05:14: "basket about 100 slots; level-60 Large Leaf Box up to 160".
  - Spec 11:155: "Handle demolished stations ... without losing items or duplicating output".
  - PRD:582: "baskets (~100 slots early) → boxes → large boxes".
  - PRD:819: "Signs (text, images, animated billboards ...)", with no length.

  So the values stay as they were: chest 100, large box 160 flat (`# ASSUMPTION` until building level exists), and
  the signboard's 48 characters `# ASSUMPTION`. Vision fixes 1 and 2 were already in the code. A grep of the owned
  files finds no "lost (logged)" path. Every queue_free of a piece goes through `spill_storage`/`salvage`. A kit
  destroyed by damage calls `salvage_contents()` before `queue_free`.
- **Gates**: scratch tree `trees/bs5-gates` (mkscratch at ca0c5529 with the hooks patch applied). Logs and PNGs
  are in the 72cebc8b scratchpad under `bs5/`.
  - `--import`: 0 SCRIPT ERROR, 0 "Failed to compile".
  - All 23 `t_*.gd` exit 0 with their PASS line and 0 SCRIPT ERROR, except t_save's 5 deliberate ones (`[t_save]
    PASS`, `round trip save_v3_golden.json fields=23 diffs=0`). New since the last pass: t_data (`[t_data] PASS
    items=223 recipes=155`), t_w2_skills and t_water.
  - t_buildsys: `ok repair_upgrade`, `ok furniture`, `ok salvage`, `ok snap_resources`, `[t_buildsys] PASS`.
  - run_all: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- **Labs (headless)**, each with 0 SCRIPT ERROR and 0 "couldn't resolve track":
  - snap_build_lab: `[snap] PASS`. The raptor's wall bite is now `69.0 (want 69.0)` because W2-DATA's numbers
    changed; the expectation is computed from data.
  - `--snap-touch`: `[snap] PASS`, with all 19 touch ok lines.
  - build_lab: `[build] PASS`.
  - siege probe: `[siege] destroyed-after=12s occupancy-cleared=true`.
- **Fail on old behaviour**, redone on the merged code. In the gates tree, `bs3/mutate.sh` applied its six
  mutations: lost (logged), 20/40 slots, no `salvage_contents()`, repair and upgrade that check the cost but do
  not pay, and no resource rule. The result was `[t_buildsys] FAIL count=21`, for example:
  - `FAIL demolish: item l12a1e6ac5a432f13 is kept exactly once (seen 0 times)`
  - `FAIL destroyed by a raptor: item l653d745d1959dbaf is kept exactly once (seen 0 times)`
  - `FAIL destroyed kits: item l1581c147b2a7bb1c is kept exactly once (seen 0 times)`
  - `FAIL a chest holds at least 100 (PRD:582 baskets ~100 early; got 20)`
  - `FAIL repair took exactly its cost of plank`
  - `FAIL the upgrade took exactly its 8 stone (left 8)`
  - `FAIL a foundation ghost aimed at a tree is never valid on its module (try 1: )`

  The mutations were reverted afterwards, and `git diff -- game/scripts/world game/data` is empty.
- **Pixels (windowed, each one looked at)**:
  - `house_fwd.png` / `house_glc.png` (1600x900): the snapped 2-storey plank house, with gable roof, storey band,
    framed door, windows on both storeys and a stone ramp. The two renderers match.
  - `inside_fwd.png` / `inside_glc.png`: the roof and upper storey fade to a dithered outline, and the front wall
    fades to a blue dither. The survivor inside is hard to see (the label and ring read, the body barely does) in
    both renderers. This is W2-OCCLUDE's look, unchanged here.
  - The lab's fixture also draws a level-up stat list at the top left (W2-SKILLS' banner, a dev fixture).
  - Touch at 844x390 on gl_compatibility (`--touch --snap-touch`): `[snap] PASS`.
    - `touch_ghost.png`: the ghost, snap points, ROTATE/PLACE/CANCEL hexes, and the cost label "Wood Foundation
      plank ×6 · twine", whose tail runs under the DEBUG hex.
    - `touch_card.png`: Wood Wall 1200/1200, "Upgrade to Stone / stone ×8 · plank ×2", "Demolish / half back",
      "Building to Stone (5)".
    - `touch_house_card.png`: Wood Door 600/600, with Open door, Upgrade, Demolish and "Building to Stone (45) /
      stone ×344 · plank ×88".
    - `touch_sign.png`: the chest and the signboard on the new foundations.
    - `touch_chest.png`: the bag panel opens, but the chest grid is below the fold (the known limit, W2-SCREENS/
      INVUI).
    - The lab's LEVEL UP banner covers the card's top right on the phone (a dev fixture).
- **Crash reports**: no new `~/Library/Logs/DiagnosticReports/Godot-*.ips`. The before and after listings are
  identical, and the newest is `-232613`, which predates this pass.

## Resume pass 2 (2026-10-20 ~21:45, finish-6 resumed again)

- **Base**: merged cecc936b (HANDOFF, exchange.js and invui.js: docs only), so `git diff fa833312 HEAD -- game/
  tools/` is empty. W2-PROCESS (add208b3) still does not touch `build_placer.gd`. Its `salvage_contents()` and
  `pack_up_block_reason()` match the duck-typed calls here, so nothing needs keeping or redoing.
- **Hooks patch**: unchanged. Through a throwaway index: `APPLY OK on cecc936b` and `APPLY OK on f1ee5b17`.
- **Hook 4**: there is still no `tools/labs.txt` on the base. W1-QA owns it and is not merged. When it lands,
  append (its format):
  `snap_build_lab | 120 | -- --lab=snap_build_lab | shot` and
  `snap_build_touch | 120 | -- --lab=snap_build_lab --snap-touch`.
- **Docs answers**, checked against the files again: spec 10:90, 10:102, 05:14, 11:155 and PRD:582 say what the
  first resume pass quotes. PRD:819 "Signs (text, images, animated billboards)" gives no length, so the 48
  characters stay `# ASSUMPTION`.
- **Gates**: scratch tree `trees/bs4-gates` (mkscratch, f1ee5b17 + hooks), logs and PNGs in the 72cebc8b
  scratchpad under `bs4/`.
  - `--import`: 0 SCRIPT ERROR, 0 "Failed to compile".
  - All 20 `t_*.gd` exit 0 with their PASS line and 0 SCRIPT ERROR, except t_save's 5 deliberate ones
    (`[t_save] PASS`). t_harbour prints `PASS islands=15`.
  - t_buildsys: `ok repair_upgrade`, `ok furniture`, `ok salvage`, `ok snap_resources`, `[t_buildsys] PASS`.
  - run_all: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- **Labs (headless)**, 0 SCRIPT ERROR, 0 "couldn't resolve track":
  - snap_build_lab: `[snap] PASS`, including `house: 52 pieces, its ramp, a chest and a sign placed through
    socket snapping (got 55)`, `the chest comes back with its 7 stone` and `a schema-3 save migrates to 4`.
  - `--snap-touch`: `[snap] PASS`.
  - build_lab: `[build] PASS`.
  - siege probe: `[siege] destroyed-after=12s occupancy-cleared=true`.
- **Fail on old behaviour**: not redone, because the code is unchanged. The six-mutation run of the first resume
  pass (`bs3/mutlogs/t_buildsys.log`) ends `[t_buildsys] FAIL count=21`.
- **Pixels (windowed, looked at each)**:
  - `house_fwd.png` / `house_glc.png` (1600x900): the snapped 2-storey plank house. Gable roof, storey band,
    framed door and windows on both storeys, stone ramp. The two renderers match.
  - `inside_fwd.png` / `inside_glc.png`: the roof and upper storey fade to a dithered outline, and the front wall
    to a dither. The survivor behind it is faint in both renderers (W2-OCCLUDE's look).
  - Touch at 844x390 on gl_compatibility (`--touch --snap-touch`): `[snap] PASS` with 19 touch ok lines.
    - `touch_ghost.png`: the ghost, snap points and the ROTATE/PLACE/CANCEL hexes. The cost label's tail runs
      under the DEBUG hex and the lab's level-up banner (dev overlays).
    - `touch_card.png`: Wood Wall card. "Upgrade to Stone / stone ×8 · plank ×2", "Demolish / half back",
      "Building to Stone (5) / stone ×40 · plank ×11".
    - `touch_house_card.png`: Wood Door card. Open door, Upgrade, Demolish, "Building to Stone (45) / stone ×344
      · plank ×88".
    - `touch_chest.png`: the bag panel opens, but the chest grid is below the fold under the HUD hexes. This is
      the known limit (W2-SCREENS/INVUI).
- **Crash reports**: no new `~/Library/Logs/DiagnosticReports/Godot-*.ips`. The before and after listings are
  identical; the newest is still `-202004`.

## Resume pass (2026-10-20 ~20:10, finish-6 resumed on the owner's "continue")

Earlier results from the derailed resume were not trusted, so every gate, lab, pixel run and the fail-on-old
proof was run again here. Scratch tree `trees/bs-gates` (mkscratch, branch 777a678c, hooks patch applied);
logs and PNGs are in the 72cebc8b scratchpad under `bs3/`.

- **Base**: merged 34b6d459 (HANDOFF, STATUS, exchange.js, mkscratch.sh; docs only). W2-PROCESS is not on the
  base yet. Its branch (76875ea4) and its hooks patch do not touch `build_placer.gd`. The base's
  `pack_up_blocker` already calls the structure's duck-typed `pack_up_block_reason()`, so the merge has nothing
  to keep or redo. Its `CraftStation`/`ProcessStation.salvage_contents() -> Array[ItemStack]` matches the
  duck-typed call in `StructureHealth.take_damage`.
- **Hooks patch**: unchanged, apply-clean. `git apply --cached --check` through a throwaway index printed `APPLY
  OK on 34b6d459` and `APPLY OK on HEAD`. **Hook 4**: the base has no lab registry. There is no `tools/labs.txt`,
  and `main.gd:17` loads `res://scenes/dev/%s.tscn` by `--lab=` name, so nothing needs registering.
- **Docs answers, checked line by line again**:
  - Spec 10:90: "a **level-60 Large Leaf Box holding 160 spaces**. Do not impose this value on every box."
  - Spec 05:14: "basket about 100 slots; level-60 Large Leaf Box up to 160".
  - PRD:582: "Storage: baskets (~100 slots early) → boxes → large boxes".
  - So the chest has 100 slots and the large box 160 (structures.json, `# ASSUMPTION` flat until building level
    exists). The old 20/40 are gone.
  - Sign text: the specs and PRDs give no limit. PRD:972 "sign flair" is a cosmetic only. So 48 is now marked
    `# ASSUMPTION` in `StructurePiece.set_sign_text` (777a678c).
  - Spec 10:102: "A change in building state must not silently delete stored items". Spec 11:155: "Handle
    demolished stations, ... without losing items or duplicating output".
  - Code paths: `destroy`, `collapse_unsupported` and a kit's death in `StructureHealth.take_damage` all go
    through `StructureHealth.salvage`: the bag of the player who took the structure down, then home cargo,
    then a loot bag. Kits also call `salvage_contents()` when they have it. No "lost (logged)" path is left
    (grep).
- **Fail on old behaviour** (scratch `trees/bs-mut`, `bs3/mutate.sh`). Six mutations put back the old
  behaviours:
  1. the old "lost (logged)" instead of a loot bag;
  2. chest/large box 20/40;
  3. no `salvage_contents()` call;
  4. repair checks the cost but does not pay;
  5. upgrade checks the cost but does not pay;
  6. no resource rule for pieces.

  Result: `[t_buildsys] FAIL count=21`. Each mutation is caught:
  - `FAIL demolish: item laa16e8eaa15ba564 is kept exactly once (seen 0 times)`, `FAIL destroyed by a raptor:
    item ldcfdd3f6e796ffb6 is kept exactly once (seen 0 times)`
  - `FAIL a chest holds at least 100 (PRD:582 baskets ~100 early; got 20)`, `FAIL a large box holds 160`
  - `FAIL destroyed kits: item lae77c5a341138751 is kept exactly once (seen 0 times)`
  - `FAIL repair took exactly its cost of plank`
  - `FAIL the upgrade took exactly its 8 stone (left 8)`
  - `FAIL a foundation ghost aimed at a tree is never valid on its module (try 1: )`, `FAIL no piece stands
    on the tree's module`

  The mutations were reverted afterwards.
- **Gates (hooks applied)**:
  - `--import`: 0 SCRIPT ERROR, 0 "Failed to compile".
  - Every `game/tests/t_*.gd` (20 files) exits 0 with its PASS line and 0 SCRIPT ERROR, except t_save's 5
    deliberate ones. The 20 files: t_ai, t_build, t_buildsys, t_canim, t_combat, t_harbour (`islands=15`),
    t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (`round trip save_v3_golden.json
    fields=23 diffs=0`), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_web.
  - t_buildsys: `ok salvage`, `ok snap_resources`, `[t_buildsys] PASS`.
  - run_all: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- **Labs (headless)**, all with 0 SCRIPT ERROR and 0 "couldn't resolve track" in any log:
  - snap_build_lab: `[snap] PASS`, including `house: 52 pieces, its ramp, a chest and a sign placed through
    socket snapping (got 55)`.
  - `--snap-touch`: `[snap] PASS`.
  - build_lab: `[build] PASS`.
  - `--siege-probe`: `[siege] destroyed-after=12s occupancy-cleared=true`, exit 0.
- **Pixels (windowed, looked at each)**:
  - `house_fwd.png` / `house_glc.png` (1600x900): the snapped 2-storey plank house. Gable roof, storey band,
    framed door and windows on both storeys, stone ramp. Same in both renderers.
  - `inside_fwd.png` / `inside_glc.png`: the roof and upper storey fade to a dithered outline, and the front
    wall fades to about half with the survivor behind it. On gl_compatibility the survivor reads fainter (as
    before; W2-OCCLUDE's look).
  - Touch at 844x390 on gl_compatibility with `--touch --snap-touch`: `[snap] PASS`, with all 19 touch ok lines
    (BUILD, tier, piece, tap, PLACE, ROTATE, CANCEL, wall card, Upgrade, Repair, chest Open, sign text,
    Demolish, whole-building row).
  - `touch_ghost.png`: ghost, green/red snap points, ROTATE/PLACE/CANCEL hexes. The cost label's right end
    ("· twine") runs under the DEBUG hex and the lab's level-up banner (dev overlays).
  - `touch_card.png`: Wood Wall card. "Upgrade to Stone / stone ×8 · plank ×2", "Demolish / half back",
    "Building to Stone (5)".
  - `touch_house_card.png`: Wood Door card. Open door, Upgrade, Demolish, "Building to Stone (45) stone ×344 ·
    plank ×88".
  - `touch_chest.png`: the bag panel opens, but the chest grid is below the fold and the HUD hexes draw over it.
    This is the known limit, listed below for W2-SCREENS/INVUI.
- **Crash reports**: new `Godot-2026-10-20-201057.ips`, `-201134.ips` and `-201146.ips` appeared while my runs
  were in flight. Three more appeared later (`-201353`, `-201403`, `-201415`) while I had no Godot process
  running. All six have the signature of `-195503.ips` and `-195619.ips`, which predate this session:
  - SIGABRT from `std::system_error` in `recursive_mutex::lock` on the main thread, about 10 s after launch.
  - The parent process (pid one or two lower) had already exited.

  Every Godot run of mine returned exit 0 with its PASS line. Rerunning the two runs that started in the same
  second as a crash (`--snap-touch` and t_harbour) added no `.ips`. They come from concurrent agents' runs, not
  from this package's commands.

## Re-review pass (2026-10-20, findings: none)

- The reviewer returned an empty findings list, so nothing needed fixing.
- Base merged (dc6417cc: spec 14 and STATUS, docs only). `git diff 404c365a HEAD -- game/ tools/` is empty, so the
  game code is byte-identical to the state the gates and the pixel runs above were run on.
- Hooks patch unchanged, no regeneration needed: `git apply --cached --check` through a throwaway index prints
  `APPLY OK on dc6417cc` and `APPLY OK on branch HEAD`.
- No gate, lab or screenshot run was repeated: no finding to recheck and no game code changed. A repeat would
  have re-proved results already listed below. Hook 4 is still "no registry needed" (see Integrator hooks).

## Review r1 fixes (2026-10-20, finish-6)

- **Blocker, t_save.gd edited on the branch**: reverted on the branch (080cb796); the same 3-line hunk is now
  hook 5 in the patch. `git apply --cached --check` of the whole patch on claude/mmo-overhaul dd7ff218 (through a
  throwaway index): `APPLY CHECK OK on dd7ff218`. Rerun, scratch tree at 080cb796 with hooks 1-3 and 5 applied:
  `[t_save] round trip save_v3_golden.json fields=23 diffs=0`, `[t_save] PASS`, 5 SCRIPT ERROR (the deliberate
  ones), exit 0; no new `.ips` (newest still 2026-10-20-131531). The check that catches this: compare
  `git diff --name-only claude/mmo-overhaul...HEAD` with the plan-register Owns list. It now lists only owned
  files, new files extracted from them (structure_*, loot_bag, snap_touch), and this report, its patch and the
  r1 findings.
- **Minor, large box 160 flat**: left as is, as the finding allows, until W2-CONSTRUCT adds
  `base_capacity_at_level`. It stays marked `# ASSUMPTION` (see Assumptions).
- **Minor, chest grid below the fold at 844x390; no card for floors/stairs/ramps**: no change, as the finding
  says. Listed under Limits for W2-SCREENS / W1-UI.
- Base merged (dd7ff218: spec 13 and STATUS, docs only). No game code changed, so no other gate or pixel run was
  repeated.

## Contents-never-lost pass (2026-10-20 evening, finish-6)

- **Owner's question, "this vision check is too exhaustive, is it really necessary?"** For this package its two
  items were cheap and both are real, but neither needed a multi-agent audit: reading the four cited lines took
  minutes. Item 1 closed live loss paths (below). Item 2 is two numbers, and one part of it overreaches the doc
  (the flat 160, see below). The audit itself was already stopped (`vision-check.md`); nothing more was audited here.
- **Docs, checked line by line.** Spec 10:102 "A change in building state must not silently delete stored
  items." Spec 11:155 "Handle demolished stations, ... without losing items or duplicating output." PRD:582
  "Storage: baskets (~100 slots early) → boxes → large boxes (pillar requirements)". Spec 05:14 "basket about 100
  slots; level-60 Large Leaf Box up to 160 ... These are references rather than universal capacities." Spec 10:90
  "a level-60 Large Leaf Box holding 160 spaces. Do not impose this value on every box." Sign text: the specs and
  PRDs give no limit (PRD:972 names "sign flair" as a cosmetic, nothing more), so 48 characters stays an assumption.
- **Capacity (structures.json):** chest 20 -> 100, large box 40 -> 160. The chest is the "box" rung after the
  ~100-slot basket. 160 is a level-60 figure (10:90); pieces have no building level in play yet (all level 1), so
  it is flat for now: # ASSUMPTION in the file's doc, and W2-CONSTRUCT's base_capacity_at_level replaces it. The
  basket kit stays at 60 (placed_building.gd's existing assumption).
- **Nothing a structure held is deleted any more.** What was lost before (proved by running the new test on the
  old code, 24 FAIL lines such as `FAIL demolish: item l35643c0344bd7322 is kept exactly once (seen 0 times)`):
  a demolished chest's contents after its refund had filled the cargo, a destroyed chest's contents past a full
  cargo ("lost (logged)"), every item in a kit destroyed by damage (a basket's storage, a pen's animal), demolish
  refunds past a full cargo, and a chest whose save row was skipped on load. Now one function,
  `StructureHealth.salvage(stacks, at, by)`, puts them in the bag of whoever took the structure down, then home
  cargo, then a **loot bag** at the spot (`loot_bag.gd`, new: a tappable bag icon in the placed_building group, so
  the existing building tap opens it with Take all; saved as a building row `{kind: loot_bag, x, y, z, contents}`
  and restored by `SaveGame._restore_buildings`; gone when emptied; it settles on the floor still under it). A
  build without this code refunds such a row into the cargo (unknown kind), so nothing is lost there either.
  Demolish puts contents first, then the refund, in one salvage (one bag). A kit destroyed by damage gives back
  `BuildPlacer.stored_items` (split out of the pack-up returns) and, when it has one, the duck-typed
  `salvage_contents() -> Array` of ItemStack, which W2-PROCESS stations implement (they remove what they return).
  Pack-up is unchanged: `pack_up_blocker` still calls the structure's `pack_up_block_reason()` (W2-PROCESS's
  loaded-station refusal needs no change here); a chest is not a kit, so pack-up refuses it and keeps it whole.
- **t_buildsys** gains `salvage` (pack-up refused, demolish with a full bag and 2 free cargo slots, a raptor's
  bite destroying a 1 hp chest, loot bags through `_live_buildings` -> JSON -> SaveSanitizer -> restore, a chest
  row round trip, a broken chest row, a basket and a station with `salvage_contents()` destroyed by damage; every
  stamped instance counted exactly once across bag, cargo and loot bags) and `snap_resources` (a foundation ghost
  aimed at a tree, with a free socket beside it, never lands on the tree's module), and `repair_upgrade` now
  checks the upgrade takes exactly its blueprint and that one item short takes nothing. Proved: the old code
  fails `salvage` (24 lines); two mutations (no resource rule; upgrade checks but does not pay) give
  `FAIL a foundation ghost aimed at a tree is never valid on its module (try 1: )`, `FAIL no piece stands on the
  tree's module (foundation (-14, -9, 0, 0))` and `FAIL the upgrade took exactly its 8 stone (left 8)`.
- **Hook 4**: the base has no lab registry (no tools/labs.txt; main.gd loads `res://scenes/dev/<lab>.tscn` by
  name), so there is nothing to register: run it as `--lab=snap_build_lab`. The patch holds hooks 1-3 (and hook 5
  since review r1).

### Gates (this pass; scratch tree at 2c993dda, then 8d4e2ed1, hooks 1-3 applied, lines seen)

- `--import`: 0 SCRIPT ERROR / "Failed to compile". Every `game/tests/t_*.gd` PASS, 0 SCRIPT ERROR except t_save's 5
  deliberate ones: t_ai, t_build, t_buildsys, t_canim, t_combat, t_harbour (`islands=15`), t_iconart, t_items,
  t_light, t_lighting, t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons,
  t_web. run_all `[tests] PASS`; `tools/smoke.sh --no-import` `SMOKE PASS`. Re-run on 8d4e2ed1 (the loot bag's
  settle): `[t_buildsys] ok salvage`, `ok snap_resources`, `[t_buildsys] PASS`, snap_build_lab `[snap] PASS`.
- Labs headless, 0 SCRIPT ERROR, 0 "couldn't resolve track": snap_build_lab `[snap] PASS`, `--snap-touch`
  `[snap] PASS`, build_lab `[build] PASS`, siege probe `[siege] destroyed-after=12s occupancy-cleared=true` exit 0.
- Windowed on 8d4e2ed1, looked at each (scratchpad `bs2/`): `house_fwd.png` / `house_glc.png` (1600x900): the
  snapped 2-storey house, plank walls, storey band, framed door and windows on both storeys, ramp, gable roof; the
  same in both renderers. `inside_fwd.png` / `inside_glc.png`: roof and upper storey fade to a dithered outline,
  the front wall to about half; on gl_compatibility the survivor behind the dithered front wall is fainter than on
  Forward+ (W2-OCCLUDE's look, not changed here). Touch at 844x390 glc with `--touch`: `[snap] PASS`;
  `touch_ghost.png` (ghost, snap points, ROTATE/PLACE/CANCEL hexes, cost label), `touch_card.png` (Wood Wall
  card: Upgrade to Stone with its cost, Demolish, Building to Stone (5)), `touch_chest.png` (the bag panel opens;
  the chest's grid, now 100 slots, is below the fold as before).
- No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (newest is still 2026-10-20-131531).
- Not done: no shot of a loot bag on the ground (it reuses the corpse's loot-bag icon; tested headless only);
  no blind A/B (the house look is unchanged from the reviewed shots).

## Finishing pass (earlier session)

- Merged the base twice (W2-PLAYER split, W1-UI HUD split, W2-OCCLUDE, W1-UIICONS). One merge fix in an owned
  file: `build_grid.gd` called `_cells_changed` (base name) where this branch has `cells_changed`; game.gd
  failed to parse until fixed.
- **Chests, large box, signboard**: three new pieces in structures.json (`slot: "on_floor"`, one per floor
  module, all four tiers). Chest 20 slots, large box 40 (`storage_slots`), signboard text up to 48 characters
  (`text_max`) drawn on the board. Contents and text ride in the piece row (`contents`, `text`,
  `container_id` = piece id) and are type-checked on load. A demolished chest's contents go to the demolisher's
  bag, then camp cargo; a collapsed or destroyed one goes to camp cargo (logged when there is none). Kits and
  furniture never share a floor module (both directions refused with `overlap`). The piece was first called
  `sign`, which is also the sign kit's kind: BuildPlacer took the kit for a piece (t_build caught it), so it is
  `signboard` and t_buildsys now fails on any piece/kit name clash.
- **Whole building**: `StructurePlacer.building_of/upgrade_all/repair_all` (+ BuildPlacer wrappers): a wall's
  card offers "Building to Stone (45) stone ×344 · plank ×88" and "Repair building", all or nothing.
- **Touch** (`structure_sheet.gd`, new): the HUD's Build sheet gets a tier row (Thatch/Wood/Stone/Metal, a locked
  tier shows its Construction level) and one two-line button per piece ("Wall / plank ×4 · twine ×2"). A tapped
  piece opens its card: Open/Close door, Open chest (n / 20 slots), signboard text field + Save text, Upgrade to
  <next tier> with cost, Repair with cost (when damaged), Demolish, and the whole-building rows. Floors, stairs
  and ramps are not tap targets (a tap there stays a move); only a direct ray hit opens a card, never the 1 m
  pick bubble (indoors every spot is within 1 m of a wall).
- **Placer for touch**: a piece ghost no longer follows the pointer (on a phone the pointer is wherever the
  last finger was, e.g. the PLACE hex, so the ghost jumped under the button). It starts one module in front of
  the survivor and moves only by taps on the world (`tap_ground` aims, then it snaps to the nearest free
  socket). The ghost's cost label scales with the orthographic camera to ~20 px on any screen (it was ~7 px on
  a 390 px tall phone) and sits 2 m up for pieces.
- **snap_build_lab --snap-touch** (`snap_touch.gd`, new): the whole loop by screen touches only
  (InputEventScreenTouch press/release at the controls' and world points): BUILD hex, tier, piece, tap ground,
  ROTATE, PLACE, CANCEL, tap a wall, Upgrade, Repair, chest Open, signboard text, Demolish, the house door's
  whole-building row. Headless it sizes the window to 844x390 (headless defaults to 64x64). It needs hooks 1-2
  and fails with `the HUD has the W2-BUILDSYS hook (open_structure)` without them.
- The lab house now also holds a chest and a signboard; its save/load check covers their contents and text.
- props_manifest.json: the four 1 m building stand-in rows' `upgrade` now points at structures.json (art_status
  stays REPLACE, t_structart requires it).

## What shipped

- `game/data/structures.json`: one lattice (2 m modules, 2.5 m storeys), four tiers (thatch/wood/stone/metal:
  rank, tint, creature damage multiplier 1.0/0.8/0.35/0.15, Construction level 0/5/20/35), eleven building pieces
  (foundation, wall, doorway, door, window, ceiling, roof, roof ridge, pillar, stairs, ramp; plus chest, large
  box and signboard from the finishing pass, 56 blueprints in all) with slot,
  footprint, levels, support rule, what they block, occlusion mode and XP; `piece_tiers`: 44 blueprints in the
  spec-10 section-11 shape (material_slots with role/item/quantity/counts_for_level/counts_for_attributes,
  minimum/maximum_level, required_skill_node, required_building_ability, supported_building_effects,
  max_durability, `model`). `model` is the swap point: a res:// GLB path there replaces the procedural stand-in
  for that piece and tier (`model_contract` in the file says origin, axes and scale). `placed_kinds`: durability
  and repair materials for all 24 kit kinds plus a default. Costs use bag materials only (branch, fibre_stalk,
  plank, twine, stone, iron_ingot, rope, clay); items.json and recipes.json are untouched.
- `structure_piece.gd` (StructurePiece, StaticBody3D): one piece at a slot (module x, module z, level, code:
  cell, edge x/z, corner, door x/z, on-floor, stairwell). Pose, keys, cost, durability, spec-10 instance row
  (`to_dict`: id, blueprint_id, tier, owner_id, level, inherited_attributes, max/current_durability, position,
  rotation, container_id), a type-checked `from_dict` for untrusted saves, door open/close (`interact`),
  in-place `set_tier`, `destroy` (collapses what it held). Walls, doorways, windows, closed doors and pillars
  are on layer 1|16 so creatures collide; the owning survivor gets a collision exception (HANDOFF 8: owned
  walls are passable for the player, blocking for enemies).
- `structure_grid.gd` (StructureGrid, `BuildGrid.structures`): occupancy by slot, placement rules with reason
  codes (occupied, no_support, stairwell, max_level, unclaimed, water, resource, reserved, overlap, slope,
  no_blueprint), structural support level by level with span from a supported slab (max_span 2) and
  `collapse_unsupported`, socket candidates, enemy path cells (level-0 blockers; a doorway is open, a door
  blocks while closed), `restore` / `to_rows` for saves, and roof groups (below).
- `structure_mesh.gd` (StructureMesh): the procedural stand-ins. Bevelled boxes per tier (thatch bundles,
  wood planks, stone courses, riveted metal), sill and cap bands that mark each storey, door and window
  frames, gable roofs and a ridge, stairs with stringers, a sloped skirt down to the lowest corner, box-projected
  UVs over a subtle noise grain (triplanar was dropped: W2-OCCLUDE's derived material does not replicate it).
- `structure_health.gd` (StructureHealth): durability on every piece and, lazily, on every placed kit
  (catapult, fence, workbench...). Creature damage reaches structures only through it, scaled by the tier's
  creature multiplier; at 0 a piece is destroyed and what it held collapses, a kit is freed. Camp pieces,
  the harbour and cargo are not structures. API for brains: `of`, `is_structure`, `blocker_between`,
  `siege_target(creature, goal)` (the blocking wall, only while TilePath says the goal is unreachable).
- `structure_placer.gd` (StructurePlacer) + `build_placer.gd`: the BuildPlacer API. `begin_piece(kind, tier)`
  selects; the ghost snaps to the nearest free socket that accepts the piece within `snap_radius_m`
  (pointer ray, or `aim_at(world)` for labs/tests) with green snap points on free sockets and red on refused
  ones; `rotate_clockwise()`, `confirm(player)`, `cancel()` work as for kits, so the HUD's existing
  rotate/place/cancel hexes drive pieces with no HUD change. `upgrade(target, tier, player)`,
  `repair(target, player)`, `demolish(target, player)` return bool and give a notice with the reason.
  Costs: place = blueprint; upgrade = the new tier's blueprint, same node, slot and pose, full new durability;
  repair = repair_fraction (0.5) of the blueprint x missing share (kits: their placed_kinds list x missing
  share), rounded up; demolish refunds 0.5 x health share (camp cargo takes what the bag cannot). Construction
  level gates tiers; placing gives the piece's construction XP; 8 m reach (flat).
- Roofs and the occlusion adapter: `StructurePiece._occlusion(node, mode)` is the one adapter to W2-OCCLUDE
  (`Occlusion.make_occludable(node, "between"|"inside")` / `release`), guarded by
  `ResourceLoader.exists("res://scripts/world/occlusion.gd")`; without it pieces simply stay opaque. Walls and
  pillars register per piece ("between"). Roofs and ceilings hang their look under one `RoofGroup` node per
  storey of a connected building, registered "inside": a per-piece inside fade was useless (first bound shot:
  only the 2x2 m piece overhead faded, while from the iso pitch the roof hiding an indoor survivor is the part
  nearest the camera). Pieces that bridge two groups merge them.
- `tile_path.gd`: structure cells are part of the build blockers (they were dropped on a dirty refresh);
  `path(..., for_owner)` / `path_result(..., for_owner)` give the owner's path through its own walls and doors.
- `build_grid.gd`: kits may stand fully on a foundation (on its deck height), never half on one; nothing goes
  on a resource node's cell (index built once the island has its nodes); `blocks_path(c, for_owner)`.
- `creature_attack.gd`: structure targets go through StructureHealth (the catapult too, by the same path) and
  skip the melee line check (the structure is the obstacle). `field_catapult.gd`: `receive_siege_hit` uses it.
- Saves: piece rows ride in the home/away building lists; `save_game.gd` restores pieces before kits (a kit on
  a foundation needs its floor) and keeps kit wear (`durability`). `save_migrations.gd`: schema 4 (a v3 save
  has nothing to rewrite; the step marks the version so a schema-3 build refuses a schema-4 file).
- `snap_build_lab` (+ scene) and `game/tests/t_buildsys.gd` (dsc2, below).

## Acceptance (run this session on 131f3210 + 23d4a548, lines seen)

- **snap_build_lab** headless: `[snap] PASS`, among its 40 ok lines: `house: 52 pieces, its ramp, a chest and a
  sign placed through socket snapping (got 55)`, `every piece within 1 cm of its socket (worst 0.0000 m)`,
  `removing the last support collapses the ceiling and the wall on it (fell 2)`, `raptor bite on the wood wall
  through StructureHealth: 86.7 (want 86.7)`, `repair took exactly 1 plank`, `the upgrade swaps in place (same
  node, same socket)`, `stone durability 3000`, `a creature cannot path into the closed house`, `the owner's path
  goes through its own door`, `a kit cannot stand on the chest's module (overlap)`, `schema 4 save holds 59 piece
  rows (got 59)`, `load restores every piece: 59/59, 0 differ`, `the chest comes back with its 7 stone`, `the sign
  comes back with its text`, `a schema-3 save migrates to 4`.
- **Touch, 844x390**: `--snap-touch` windowed at 844x390 gl_compatibility with `--touch`: `[snap] PASS` (three
  runs), and headless `[snap] PASS`; ok lines: `touch: BUILD, Wood, Foundation select a wood foundation ghost`,
  `a tap on the ground snaps the ghost`, `PLACE puts the foundation in the tapped module`, `the foundation took
  its planks`, `ROTATE turns the ghost`, `a wall placed on the tapped edge`, `a chest stands on the first
  foundation`, `tapping the wall opens its card`, `Upgrade to Stone swaps the wall in place at full stone
  durability`, `the upgrade took the stone blueprint`, `Repair brings the bitten wall back (2685 -> 3000 for
  { &"stone": 1, &"plank": 1 })`, `Open chest shows the chest's storage`, `the sign card saves its text ('Raptors
  east')`, `Demolish takes the wall down`, `the demolished wall refunds part of its stone`, `a house wall's card
  offers the whole building's upgrade (Building to Stone (45) stone ×344 · plank ×88)`. With hooks 1-2 applied
  (scratch, not committed).
- **t_buildsys** `[t_buildsys] PASS`: data_rows, costs, reasons cases=14, snap, collapse, damage_tiers,
  kits_and_camp, repair_upgrade, paths, rows_round_trip, bad_rows cases=9, migrations, furniture, building_all.
  New cases checked against three mutations, all caught: no spill on destroy (`its 5 stone come back to the
  bag (bag has 0)`), upgrade-all not all-or-nothing (`upgrade-all one item short is refused`), furniture
  ignoring kits (`a chest cannot go where a kit stands`).
- **Whole suite**, committed branch (no hooks): SMOKE PASS (`tools/smoke.sh --no-import`), run_all `[tests]
  PASS`, t_ai, t_build, t_buildsys, t_canim, t_combat, t_harbour (islands=15), t_iconart, t_items, t_light,
  t_lighting, t_occlude, t_player, t_save (its 5 deliberate SCRIPT ERRORs, as on base), t_server_domain, t_srvdom,
  t_structart, t_tame, t_ui, t_uiicons, t_web all PASS; build_lab `[build] PASS`; siege probe `destroyed-after=12s
  occupancy-cleared=true` exit 0; snap_build_lab PASS; --snap-touch FAILs as designed (no hooks).
- **Same suite with hooks 1-3 applied** (scratch): all of the above PASS, --snap-touch PASS.
- Not re-run this session: the wild-raptor break-in probe for hook 3 (its script was never committed; the hook
  is byte-identical to the one it passed with).

## Screenshots inspected (scratchpad bs/, looked at each)

- `house_fwd.png` (1600x900 Forward+), `house_glc.png` (1600x900 gl_compatibility): the snapped 2-storey 3x3
  house: plank walls with posts, storey bands, framed door and windows on both storeys, stone ramp, thatch
  gable roof in courses; same look in both renderers.
- `house_phone_glc.png` (844x390 glc, --touch): the house reads at phone size; the lab's fixture XP raises a
  level-up banner over its roof line for a few seconds (lab artefact).
- `inside_fwd.png`, `inside_glc.png`, `inside_phone_glc.png` (survivor inside, W2-OCCLUDE from the base): roof and
  upper storey fade to a dithered outline, the front walls to about half, the survivor shows through, the house
  keeps its shadow; no adapter errors. The ground-floor interior reads dark through the dithered ceiling, so the
  chest inside is not visible from outside (W2-OCCLUDE's look, unchanged here).
- Touch steps at 844x390 glc: `touch_ghost.png` (ghost with green/red snap points, ROTATE/PLACE/CANCEL hexes,
  cost label readable), `touch_card.png` (Wood Wall card: Upgrade to Stone, Demolish, Building to Stone (5), 64 px
  buttons in two columns), `touch_chest.png` (bag panel with the chest storage open), `touch_sign.png`
  (signboard and chest on the new foundations), `touch_house_card.png` (Wood Door card: Open door, Upgrade,
  Demolish, Building to Stone (45)).
- Found and fixed through the shots: the Build sheet's "No building kits" note ate the rows area on the phone
  (one row visible); a stale-frame capture (window throttled, fixed with force_draw); a first run where a wall
  in front hid the chest from the tap (the probe builds the wall on the far side now).

## DeepSeek workers

- **dsc1** (`claude/mmo-w2-buildsys-dsc1`, ~$0.03): typed the 36 missing blueprint rows (9 pieces x 4 tiers)
  and the 25 placed-kind rows into structures.json from formulas and a table I wrote in its TASK.md. Its
  read-only `verify_structures.sh` checked every value, key order, formatting, that only two keys changed and
  that every item exists: `VERIFY PASS (rows piece_tiers=44 placed_kinds=25)`. What I changed: took only
  structures.json from its branch (it had committed TASK.md and the verify script too), then opened thatch at
  Construction 0 (skill levels start at 0).
- **dsc2** (`claude/mmo-w2-buildsys-dsc2`, ~$0.18): wrote `game/tests/t_buildsys.gd` (12 table-driven cases)
  against `verify_buildsys.sh`, which runs it on the real code and on twelve deliberate breakages (half costs,
  no collapse, tier multiplier ignored, owner path ignored, walls not blocking, foundations on trees, bad slot
  codes loading, schema stuck at 3, free repair, downgrades allowed, camp pieces damageable, snapping from any
  distance): `VERIFY PASS (reason rows=14, bad rows=9, 12/12 mutations caught)`; I read the clean and mutation
  logs. What I changed: split its `a ; b` statement joins onto their own lines (house style) and re-ran it on
  the current code (PASS).

## Integrator hooks

`docs/orchestration/reports/claude-mmo-w2-buildsys-hooks.patch` holds hooks 1-3 and 5 as one patch; `git apply --check`
passes on claude/mmo-overhaul 809be2e8 (resume pass 4). The hooked tree passed the whole suite and --snap-touch (resume pass 4 above).

1. **W2-PLAYER, `game/scripts/player/player_input.gd`**: `interact_tap_target`: `elif col is StructurePiece:`
   find the `hud` group node and call `hud.open_structure(col)`; `is_interactable`: a `StructurePiece` is
   interactable when `is_tap_target()`; `pick_interactable`'s 1 m bubble skips `StructurePiece` (direct hits
   only). **`player_sim.gd`**: `pathing.path(p.global_position, p._path_goal, 96, true)` (the owner walks through
   its own walls and doors, HANDOFF 8).
2. **W1-UI / W2-HUD, `game/scripts/ui/hunt_hud.gd`** (+10 lines): in the `&"build"` sheet after the kit rows
   `StructureSheet.fill_build(player, func (t, cb): _sheet_btn(box, t, cb), _refresh_sheet, _close_sheet)` and
   `any = true`; a `&"structure"` sheet whose title is `StructureSheet.fill_card(box, player, btn, _close_sheet)`;
   `func open_structure(sp: StructurePiece)` sets `StructureSheet.card` and opens that sheet.
3. **W2-ECO, `game/scripts/creatures/brains/creature_brain.gd`**: unchanged from the first pass: `_break_in()`
   before `_think` retargets the blocking wall from `StructureHealth.siege_target` once a second;
   `hunting_player` and the leash treat any structure like the catapult.
4. **No registration needed on the base**: it has no lab registry (still none on 809be2e8), labs load by scene
   name. When W1-QA's `tools/labs.txt` lands, append `snap_build_lab | 120 | -- --lab=snap_build_lab | shot` and
   `snap_build_touch | 120 | -- --lab=snap_build_lab --snap-touch`. `--lab=snap_build_lab`
   (headless `[snap] PASS`; `--shot=<png>` frames the house, `--snap-inside` puts the survivor inside,
   `--snap-ghost` stages a ghost; `--snap-touch` runs the touch loop and needs hooks 1-2, `--snap-shots=<stem>`
   saves a PNG per touch step).
5. **W1 save, `game/tests/t_save.gd`** (+3 -1, in the patch since review r1; in W2-SKILLS' `_check_v3_golden`
   since resume pass 3): skips `/schema` in the v3 golden comparison and checks the re-save is at the current schema. Needed by the schema-4 bump in save_game.gd.
6. **W2-OCCLUDE**: nothing to change; the adapter (`StructurePiece._occlusion`) works against the merged
   `Occlusion.make_occludable(node, "between"|"inside")` / `release`.

## Assumptions (# ASSUMPTION in code, or values in structures.json)

- Offline every structure belongs to the local survivor (`owner_id "local"`); W3 replaces the collision
  exception with a per-owner server check.
- Tier gates Construction 0/5/20/35, no skill node until W2-SKILLS defines one (`requires_node`).
- All numbers in structures.json are first-pass: tier HP 400/1200/3000/7000 per wall-sized piece scaled by
  piece size, creature multipliers, costs (wall: 4 primary + binding), placed_kinds durability and repair lists,
  repair_fraction 0.5, demolish_refund 0.5, snap radius 3 m, max span 2.
- Upgrade costs the new tier's whole blueprint (ARK), no credit for the old tier.
- Camp pieces, the harbour and cargo are indestructible (they are rebuilt every load anyway).
- Pieces use the kits' 8 m reach, measured flat.
- A schema-3 save needs no rewrite; schema 4 only adds piece rows and kit `durability`.
- Chest 100 slots, large box 160 flat (the level-60 reference, until building level exists); signboard 48
  characters (the docs give no limit); one piece of furniture per floor module; furniture costs and durability
  (structures.json) are first-pass.
- A structure destroyed by damage or collapse has no demolisher, so its contents skip the bag: home cargo, then a
  loot bag. A loot bag does not occupy build cells (a kit can be placed over one; the bag stays tappable).
- Whole-building actions cover pieces connected within one module and one storey; Upgrade all lifts every
  piece below the next tier to it, paid up front.

## Limits and what is left

- Floors (foundations, ceilings), stairs and ramps have no card of their own on touch (a tap there walks);
  they are upgraded and repaired through any wall's whole-building rows, but cannot be demolished one by one
  by touch.
- A piece hidden behind another (a chest behind a wall from the iso camera) takes the front piece's card; walls
  only fade when the survivor is behind them.
- The chest opens in the bag panel (inventory_ui.gd, W2-INV/W1-UI): at 844x390 the storage grid is below the
  fold and the HUD hexes draw over the panel. Signboard text is legible at 1600x900 but not at the phone's
  default zoom.
- **Spec 10 (construction quality)** is a later layer (W2-CONSTRUCT): the data is in its shape (blueprints with
  material_slots and level bounds; instances with level, inherited_attributes, max/current_durability, owner,
  container_id), but pieces are built from counted materials, level 1, no attributes, no construction sites.
- Real creatures only break walls once hook 3 lands; this branch routes the damage, the brains are W2-ECO's.
- Shortcuts in code: a roof group never splits when a middle piece goes (the halves fade together until the
  island reloads); the owner's collision exception lives on the current Player node (a re-instanced Player
  walks into its walls until the pieces reload).
- A wall blocks one row of 1 m path cells on one side of its edge, so path tests are about crossing, not about
  the exact inner cells; pets (creatures) are blocked by owned walls like wild ones.
- Stand-ins only: no Blender modular models yet (the four 1 m W1-STRUCTART stand-ins do not fit the 2 m
  lattice).
- The lab and test seed materials and set Construction 40 as fixtures; nothing here was earned in play.
- Godot crash report: `~/Library/Logs/DiagnosticReports/Godot-2026-10-20-131531.ips` appeared at 13:15:29
  during the first pass: SIGABRT in HIServices `_RegisterApplication` 47 ms after launch, before any project code,
  parent process already exited. I could not tie it to one command: my Godot launches in flight then were a
  headless `--import` in the scratch tree and a scratch probe, both through gslot, and other agents' runs share
  the same coalition. No other new .ips since the session began.
