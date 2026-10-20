# W1-ICONART report (claude, branch claude/mmo-w1-iconart)

## What shipped
- **122 rendered item PNGs** (121 items + `_unknown` silhouette) in `game/assets/icons/render/`, built by procedural
  bpy builders in `tools/blender/items/{resources,gear,food,camp}.py` through `tools/render_icons.py`
  (headless Blender 5.2 only, one studio rig `studio_v1`: Cycles CPU, fixed seed and samples, no denoiser;
  deterministic PNG encoder). `manifest.json` lists item id, source script, builder, sha256, bytes, opaque rect
  and the rig settings. Imports are lossless (`compress/mode=0`), like the other icons.
- **Every render rises above its slot.** Flat items wider than ~1.39:1 cannot be lifted 12 % above the slot top
  without spilling past the side rims, so `kit.upright()` leans them onto the diagonal (<= 1.3:1). Fourteen
  builders use it (armor_scute, charcoal, cloth, copper_ore, dried_hide, lava, ore, pine_log, raw_meat, salt,
  sashimi, silver_ore, tent_kit, wood_log); ingots and the pearl are staged as a stack / open shell.
- **Replacement marking** (owner: low-quality / low-poly assets are marked for replacement): every entry carries
  `"quality": "procedural_v1"`; 28 carry a `"replace"` reason (the worst-reading renders plus pairs not told apart at
  slot size): armor_scute, berry, black_iron, burnt_food, capture_net_ii, clay, cloth, dense_bone, dried_hide, fish,
  grilled_meat, heavy_snare, ingot, iron_ingot, mango, metal_shard, obsidian, pillar, pine_log, raid_cuirass,
  raid_greaves, raptor_hide, raw_hide, seasoned_roast, sign_kit, smoked_meat, steel_ingot, tent_kit. The 32 items.json
  ids with no render are in the manifest's top-level `"missing"` array; they show the white symbol until art lands.
  The list lives in `REPLACE` in tools/render_icons.py so re-renders keep it. A GLB render (`id=path.glb`,
  `--quality model_v2`) is the upgrade route and clears the mark.
- `game/data/item_rarity.json`: every items.json id (153) gets common/uncommon/rare/epic/legendary, plus tier colours.
- `game/scripts/ui/item_art.gd` (ItemArt): `texture_for` (render, then white ItemIcons symbol, then `_unknown`),
  `is_rendered`, `content_rect` (from the manifest rect; GPU readback only for symbol fallbacks), `rarity`,
  `rim_color`, `color_for_rarity`, `rarity_order`.
- `game/scripts/ui/art_slot.gd` (ArtSlot, a Button, 64 px floor): rarity rim + shadow glow + lower rarity wash;
  every object stands on one slot floor (80 % down) and its top rises 12-20 % above the slot (tall art 16 %, wide
  art lifts off the floor up to 20 % to reach 12 %), never past the side rims. Count bottom-right with a 14 px
  physical floor. Style boxes cached per slot.
- Lab `--lab=item_art_lab`: 5x4 grid covering all five rarities + a row of white HUD action hexes; headless
  self-check. `--light` swaps to a light background (HANDOFF P7 dark/light check); `--ids=a,b,...` shows any items
  (with `--shot`) to review renders at slot size. The grid now fits a landscape phone (sized by height as well).
- Test `game/tests/t_iconart.gd`.

## Acceptance checklist (exact lines seen this session)
- >= 60 PNGs, 256x256 RGBA, edge rows transparent, <= 64 KB, manifest with script, settings and pixel-true rect,
  rarity for every item, `missing` complete, every manifest item rising 12-20 % above the slot inside the side
  rims, the review's illegible renders marked `replace`: `[t_iconart] pngs=122 missing=32` then `[t_iconart] PASS`
- Byte-identical re-render: `Blender -b --factory-startup -P tools/render_icons.py -- --verify wood_log,steel_ingot,straw_roll_kit`
  printed `REPRO wood_log identical`, `REPRO steel_ingot identical`, `REPRO straw_roll_kit identical`, `REPRO PASS n=3`
- Lab grid, every rarity, all rendered, every object framed (rise 12-20 %, inside the rims, on the floor), count
  >= 14 px on screen: `[itemart] slots=20 rarities=5 rendered=20 framed=true count_px_ok=true ok=true`
- Lab windowed at 1600x900 and 844x390 (dark and light), screenshots inspected (below): art rises above every slot
  top edge, rims and glows coloured by rarity (grey/green/blue/purple/orange), MENU/SKILLS/BUILD/ANIMALS glyphs
  white; copper, bronze, iron, steel ingot and straw_roll_kit have art (top row).
- `ItemArt.texture_for(&"no_such_id")` returns the fallback with no error: covered in t_iconart (`[t_iconart] PASS`, no ERROR lines in the log)
- `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS`
- `run_all.gd`: `[tests] PASS`

## Screenshots inspected
All under /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/
- `lab6_1600x900.png`: the 5x4 grid; every object breaks the slot top edge; ingots fill the width up to (not past)
  the rims; rims grey/green/blue/purple/orange; hex glyphs white.
- `lab7_844x390.png`, `lab7_844x390_light.png`: landscape phone, dark and sunlit-sand backgrounds; the whole grid
  and the hex row fit (in `lab6_844x390.png`, before the height fit, the hex row fell off the bottom). Art and counts
  read on both backgrounds. HexButton captions are tiny at this size (W1-UI's widget, not ArtSlot).
- `lab7_flat_1600x900.png` (`--ids=` the 14 upright items + iron/steel ingot, obsidian, burnt_food, fish, berry):
  logs, ores, lava, charcoal, salt, hide roll, cloth, scute, raw meat, sashimi and tent kit now rise above the slot top.
- `upright_sheet.png`: contact sheet of the 14 re-rendered PNGs on alternating dark/light tiles.
- Earlier: `final_part_a{a,b,c}.png` (contact sheets of all 122), `lab3_*`, `lab4_*` (superseded layouts).

## Assumptions
- `# ASSUMPTION` in item_rarity.json (`_assumption`): placeholder tiers by material ladder until W2-DATA's rare-item
  design; bulk materials (iron_ingot, steel_ingot, black_iron) capped at rare so epic/legendary glow stays a gear signal.
- Flat items are staged on a diagonal (`kit.upright`) rather than letting the slot shrink them below the top edge.
- 32 items in items.json have no render yet and fall back to their white symbol (ItemArt handles it).

## Integrator hooks
- Register the test (run_all.gd has no external-script hook today; run it as its own step next to run_all in
  tools/smoke.sh or the CI script):
  `"$GODOT" --headless --path game --script res://tests/t_iconart.gd`  (prints `[t_iconart] PASS`, exits 0/1)
- W2-SCREENS swaps inventory_ui/item_icons slots to ArtSlot / ItemArt.texture_for.
- Add a row to docs/orchestration/mmo/asset-replacement.md: "item icons: all procedural_v1, see manifest.json
  `replace` fields and `missing`".

## Labs to register
- item_art_lab (game/scripts/dev/item_art_lab.gd + game/scenes/dev/item_art_lab.tscn)

## Failed / left
- t_iconart is standalone (see Integrator hooks).
- Determinism is near, not total: the previous attempt's `--verify all` logs (`cyc_verify1.log`, `cyc_verify2.log`
  in the folder above) end `REPRO FAIL n=122` with 121 identical; herb_buff_meal DIFFERS in both runs and split_wood
  in one. Not re-run this session (a full verify is ~10 min of 4-thread CPU on a shared box).
- Every icon is procedural_v1 and should be replaced by higher-quality art (marked in the manifest); 28 are flagged
  first. Rarity is shown by colour only (accessibility item in STATUS "Later").
- HexButton captions are tiny on an 844x390 window (W1-UI's phone layout).
