# W1-ICONART report (claude, branch claude/mmo-w1-iconart)

## What shipped
- **122 rendered item PNGs** (121 items + `_unknown` silhouette) in `game/assets/icons/render/`, built by procedural
  bpy builders in `tools/blender/items/{resources,gear,food,camp}.py` through `tools/render_icons.py`
  (headless Blender only, one studio rig `studio_v1`, deterministic PNG encoder). `manifest.json` lists item id,
  source script, builder, sha256, bytes and the rig settings. Imports are lossless (`compress/mode=0`), like the other icons.
- **Replacement marking (owner request "low quality and low poly assets need to be marked for replacement")**:
  every manifest entry carries `"quality": "procedural_v1"` (low-poly bpy primitives, placeholder tier), and the
  fifteen that read worst at slot size carry a `"replace"` reason: metal_shard, raw_hide, raptor_hide, dried_hide,
  clay, pillar, sign_kit, tent_kit, ingot, raid_cuirass, raid_greaves, cloth, grilled_meat, armor_scute, heavy_snare.
  The 32 items.json ids with no render at all (bark_strip, reed, smoker_kit, steamer_kit, canvas_tent_kit, ...) are
  listed in the manifest's top-level `"missing"` array; they show the flat white symbol until art lands. The list lives in `REPLACE` in tools/render_icons.py so re-renders keep it.
  The asset replacement register (docs/orchestration/mmo/asset-replacement.md) landed on claude/mmo-overhaul after
  this branch was cut and is not mine to edit; the integrator should add one row pointing at this manifest field.
- `game/data/item_rarity.json`: every items.json id (153) gets common/uncommon/rare/epic/legendary, plus tier colours.
- `game/scripts/ui/item_art.gd` (ItemArt): `texture_for` (render, then white ItemIcons symbol, then `_unknown`),
  `is_rendered`, `content_rect` (opaque pixels), `rarity`, `rim_color`, `color_for_rarity`, `rarity_order`.
- `game/scripts/ui/art_slot.gd` (ArtSlot, a Button, 64 px floor): rarity rim + shadow glow + lower rarity wash,
  every object stands on one slot floor (80 % down): tall items fill the height and rise 16 % above the slot top;
  wide flat items (ingots, fish, pearl) may use the full slot width and sit in the slot instead of hanging from the
  top. Count bottom-right with a 14 px physical floor. Style boxes are cached per slot, not allocated per draw.
- Each manifest entry has `"rect"` (opaque [x, y, w, h], written by render_icons.py), so ItemArt.content_rect no
  longer does a GPU readback for rendered items; only symbol fallbacks still call get_image.
- Lab `--lab=item_art_lab` (5x4 grid covering all five rarities + a row of white HUD action hexes); headless self-check.
- Test `game/tests/t_iconart.gd`.

## Acceptance checklist (exact lines seen)
- >= 60 PNGs, 256x256 RGBA, edge rows transparent, <= 64 KB, manifest with script and pixel-true rect, rarity
  listed for every item in the JSON itself, `missing` complete, wide steel_ingot centred on the slot floor, tall
  raid_maul rising 12-20 %: `[t_iconart] pngs=122 missing=32` then `[t_iconart] PASS`
- Byte-identical re-render: `Blender -b --factory-startup -P tools/render_icons.py -- --verify steel_ingot,straw_roll_kit` printed
  `REPRO steel_ingot identical`, `REPRO straw_roll_kit identical`, `REPRO PASS n=2`
- Lab grid, every rarity, all rendered, every object centred in its slot on the floor, tall ones rising 12-20 %,
  count >= 14 px on screen: `[itemart] slots=20 rarities=5 rendered=20 framed=true count_px_ok=true ok=true`
- `--verify steel_ingot,nope`: `REPRO steel_ingot identical`, `REPRO nope UNKNOWN`, `REPRO FAIL n=2` (no traceback)
- GLB mode merges and refuses over-budget art: `testprop=<bush-berries-a-empty.glb>` printed
  `ICON testprop 68796 ... OVER_64KB (not written)`, `ICONS DONE n=1 over_64kb=1`, exit 1, manifest still 122 entries
  (manifest and PNG folder restored afterwards).
- Screenshots inspected (windowed, `--resolution 1600x900` and `390x844`): art pops above every slot top edge, rims and
  glows coloured by rarity (grey/green/blue/purple/orange), MENU/SKILLS/BUILD/ANIMALS hex glyphs still white;
  copper, bronze, iron, steel ingot and straw_roll_kit have art (top row).
- `ItemArt.texture_for(&"no_such_id")` returns the fallback with no error: covered in t_iconart (`[t_iconart] PASS`, no ERROR lines in the log)
- `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS`
- `run_all.gd`: `[tests] PASS`

## Screenshots inspected
- After the review fixes (windowed, Forward+): /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/lab3_1600x900.png and /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/lab3_390x844.png.
  Seen: copper/bronze/iron/steel ingots now sit in the lower slot on the floor line, filling the width (slightly past
  the side rims), no empty slot body under them; pearl and fish centred likewise; tall items (straw roll, maul, helm,
  axe, berries, rope) still break the top edge. Iron/steel ingot rims are now blue (rare); purple/orange only on gear.
  At 390x844 the stack counts read clearly (x3/x12/x5); the white HexButton captions are still tiny (W1-UI's).
- /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/lab2_1600x900.png
- /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/lab2_390x844.png
- contact sheets of all 122 renders: /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/final_part_aa.png, final_part_ab.png, final_part_ac.png
- (earlier, superseded layout: lab_1600x900.png, lab_390x844.png, where flat items did not overflow; fixed by fitting the opaque rect)

## Assumptions
- `# ASSUMPTION` in item_rarity.json: placeholder tiers by material ladder until W2-DATA's rare-item design.
- Flat/wide items stand on the slot floor and may grow 8 % past each side rim; they do not rise above the top edge.
- Bulk materials (iron_ingot, steel_ingot, black_iron) capped at rare until W2-DATA's rarity design.
- 32 items in items.json have no render yet and fall back to their white symbol (ItemArt handles it).

## Integrator hooks
- Register the test (game/tests/run_all.gd has no external-script hook today; run it as its own step next to run_all
  in tools/smoke.sh or the CI script):
  `"$GODOT" --headless --path game --script res://tests/t_iconart.gd`  (prints `[t_iconart] PASS`, exits 0/1)
- W2-SCREENS swaps inventory_ui/item_icons slots to ArtSlot / ItemArt.texture_for.
- Add a row to docs/orchestration/mmo/asset-replacement.md: "item icons: all procedural_v1, see manifest.json replace fields".

## Labs to register
- item_art_lab (game/scripts/dev/item_art_lab.gd + game/scenes/dev/item_art_lab.tscn)

## Failed / left
- t_iconart is standalone (see Integrator hooks for the exact line).
- Renders are not fully byte-deterministic: a full re-render changed boiled_meat, camp_stew and smoked_meat (and on an
  earlier run seasoned_roast) by 1-5 bytes. `--verify` holds for e.g. steel_ingot; the food materials' noise looks
  run-dependent. The committed manifest matches the committed PNGs (t_iconart checks sha-independent pixel rects).
- On a 390x844 window HexButton captions render tiny under the 1600x900 canvas_items stretch; that is W1-UI's phone layout, not ArtSlot.
- Every icon is procedural_v1 and should eventually be replaced by higher-quality art (marked in the manifest).
