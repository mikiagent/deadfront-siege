# Task: render the 32 missing item icons and redo the 33 weakest ones

## Why
The owner wants items to "look cool": each item is rendered PNG art that rises above its slot with a rarity rim.
The icon set (game/assets/icons/render/, manifest.json) has 122 renders, but 32 items in items.json still have
no render (they fall back to a flat white symbol: manifest "missing") and 33 renders are marked "replace" in
the manifest because they read badly (each entry's "replace" text says why). Fix both, in the same style.

## Pipeline (read it first: docs/orchestration/reports/claude-mmo-w1-iconart.md explains every rule)
- Models are procedural bpy builders in tools/blender/items/{resources,gear,food,camp}.py with kit.py helpers;
  tools/render_icons.py renders them with one fixed studio rig into 256x256 RGBA PNGs and updates manifest.json
  (png, sha256, rect, quality). Render only what you touch:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/render_icons.py -- --only id1,id2
- Contact sheets: tools/blender/items/contact_sheet.py. Make work/sheets/all.png with every id you rendered
  (and a few untouched neighbours for comparison) and LOOK at it at full size: silhouette readable at 64 px,
  same light and palette as the set, nothing clipped at the frame edge, no blank or black renders.
- Item names and descriptions: game/data/items.json. Rarity: game/data/item_rarity.json (already covers them).

## The work
1. Missing (32): acacia_wood, ash, bark_strip, cactus_spine, cloth_scrap, leech, marsh_herb, mud, ochre, peat,
   petals, reed, root, snow_pine, spice_herb, vine, willow_wood (raw materials: distinct from each other - two
   woods must differ by bark colour and grain, herbs by leaf shape);
   cabin_bed_kit, canvas_tent_kit, field_large_kit, field_small_kit, log_shelter_kit, makeshift_taming_pen,
   smoker_kit, steamer_kit, stone_fire_pit_kit (kits: a bundled kit - lashed parts with a rope tie - that hints
   at the finished piece, like the existing tent_kit/sign_kit style but better);
   carnivore_feed, herbivore_feed, fruit_fertilizer, pressure_dressing;
   captured_animal (owner rule: a captured or traded animal is an item shown IN A CAGE: a lashed wooden cage
   with a small generic dinosaur inside) and tamed_animal (the same cage with its door open and a hide collar
   and lead hanging on it). Each gets its own builder, then the id leaves manifest "missing".
2. Flagged (33): redo each one so its "replace" reason no longer applies (e.g. dark items lost on a dark slot
   need lighter key materials or a rim; ingots should differ by metal; armour must not show body parts).
   When you are satisfied, remove its "replace" mark in render_icons.py's REPLACE list / manifest.
- Do not change any other render: the gate checks the other 100 PNGs stay byte-identical. Do not change the rig.
- Renders must be reproducible: `--verify <ids>` must end REPRO PASS (no randomness without a fixed seed).
- Godot only through /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
  (the gate runs it). Never touch game/scripts, game/data or game/scenes.
- Commit at each milestone on branch claude/mmo-icons2, messages ending
  "Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>". No .import/.uid churn, never game/override.cfg.

## Milestones
1. The 17 raw materials rendered: `./tools/dsc/verify_icons2.sh --fast --stage missing` lists PASS for them.
2. The 15 kits/feed/cage items: `./tools/dsc/verify_icons2.sh --fast --stage missing` prints VERIFY FAST PASS.
3. The 33 flagged items redone: `./tools/dsc/verify_icons2.sh --fast` prints VERIFY FAST PASS.
4. docs/orchestration/reports/dsc-icons2.md (per id: builder, what changed, sheet path) and the full
   `./tools/dsc/verify_icons2.sh` prints VERIFY PASS (re-render, import, t_iconart, run_all).
Never edit tools/dsc/verify_icons2.sh or tools/dsc/icons2_base.json.
