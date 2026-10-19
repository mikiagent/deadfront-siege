# W1-ICONART report (claude, branch claude/mmo-w1-iconart)

## What shipped
- **122 rendered item PNGs** (121 items + `_unknown` silhouette) in `game/assets/icons/render/`, built by procedural
  bpy builders in `tools/blender/items/{resources,gear,food,camp}.py` through `tools/render_icons.py`
  (headless Blender only, one studio rig `studio_v1`, deterministic PNG encoder). `manifest.json` lists item id,
  source script, builder, sha256, bytes and the rig settings. Imports are lossless (`compress/mode=0`), like the other icons.
- **Replacement marking (owner request "low quality and low poly assets need to be marked for replacement")**:
  every manifest entry carries `"quality": "procedural_v1"` (low-poly bpy primitives, placeholder tier), and the
  nine that read worst at slot size carry a `"replace"` reason: metal_shard, raw_hide, raptor_hide, dried_hide,
  clay, pillar, sign_kit, tent_kit, ingot. The list lives in `REPLACE` in tools/render_icons.py so re-renders keep it.
  The asset replacement register (docs/orchestration/mmo/asset-replacement.md) landed on claude/mmo-overhaul after
  this branch was cut and is not mine to edit; the integrator should add one row pointing at this manifest field.
- `game/data/item_rarity.json`: every items.json id (153) gets common/uncommon/rare/epic/legendary, plus tier colours.
- `game/scripts/ui/item_art.gd` (ItemArt): `texture_for` (render, then white ItemIcons symbol, then `_unknown`),
  `is_rendered`, `content_rect` (opaque pixels), `rarity`, `rim_color`, `color_for_rarity`, `rarity_order`.
- `game/scripts/ui/art_slot.gd` (ArtSlot, a Button, 64 px floor): rarity rim + shadow glow + lower rarity wash,
  object fitted top-anchored so it rises 16 % above the slot top, count bottom-right.
- Lab `--lab=item_art_lab` (5x4 grid covering all five rarities + a row of white HUD action hexes); headless self-check.
- Test `game/tests/t_iconart.gd`.

## Acceptance checklist (exact lines seen)
- >= 60 PNGs, 256x256 RGBA, edge rows transparent, <= 64 KB, manifest with script: `[t_iconart] pngs=122` then `[t_iconart] PASS`
- Byte-identical re-render: `Blender -b --factory-startup -P tools/render_icons.py -- --verify steel_ingot,straw_roll_kit` printed
  `REPRO steel_ingot identical`, `REPRO straw_roll_kit identical`, `REPRO PASS n=2`
- Lab grid, every rarity, all rendered, art rises 12-20 %: `[itemart] slots=20 rarities=5 rendered=20 overflow=true ok=true`
- Screenshots inspected (windowed, `--resolution 1600x900` and `390x844`): art pops above every slot top edge, rims and
  glows coloured by rarity (grey/green/blue/purple/orange), MENU/SKILLS/BUILD/ANIMALS hex glyphs still white;
  copper, bronze, iron, steel ingot and straw_roll_kit have art (top row).
- `ItemArt.texture_for(&"no_such_id")` returns the fallback with no error: covered in t_iconart (`[t_iconart] PASS`, no ERROR lines in the log)
- `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS`
- `run_all.gd`: `[tests] PASS`

## Screenshots inspected
- /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/lab2_1600x900.png
- /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/lab2_390x844.png
- contact sheets of all 122 renders: /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/final_part_aa.png, final_part_ab.png, final_part_ac.png
- (earlier, superseded layout: lab_1600x900.png, lab_390x844.png, where flat items did not overflow; fixed by fitting the opaque rect)

## Assumptions
- `# ASSUMPTION` in item_rarity.json: placeholder tiers by material ladder until W2-DATA's rare-item design.
- Flat/wide items (ingots) are top-anchored so they still overflow; their lower slot is empty under the count.
- 32 items in items.json have no render yet and fall back to their white symbol (ItemArt handles it).

## Integrator hooks
- None required. W2-SCREENS swaps inventory_ui/item_icons slots to ArtSlot / ItemArt.texture_for.
- Add a row to docs/orchestration/mmo/asset-replacement.md: "item icons: all procedural_v1, see manifest.json replace fields".

## Labs to register
- item_art_lab (game/scripts/dev/item_art_lab.gd + game/scenes/dev/item_art_lab.tscn)

## Failed / left
- t_iconart is standalone; adding it to run_all.gd is the integrator's call.
- On a 390x844 window HexButton captions render tiny under the 1600x900 canvas_items stretch; that is W1-UI's phone layout, not ArtSlot.
- Every icon is procedural_v1 and should eventually be replaced by higher-quality art (marked in the manifest).
