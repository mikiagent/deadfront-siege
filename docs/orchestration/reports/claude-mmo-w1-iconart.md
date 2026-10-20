# W1-ICONART report (claude, branch claude/mmo-w1-iconart)

## What shipped
- **133 rendered item PNGs** (132 items + `_unknown` silhouette) in `game/assets/icons/render/`. 121 come from procedural
  bpy builders in `tools/blender/items/{resources,gear,food,camp}.py` through `tools/render_icons.py`
  (headless Blender 5.2 only, one studio rig `studio_v1`: Cycles on one CPU thread, fixed seed and samples, no
  denoiser, emissive materials not sampled as lights; deterministic PNG encoder). `manifest.json` lists item id, source script, builder, sha256, bytes, opaque rect
  and the rig settings. Imports are lossless (`compress/mode=0`), like the other icons.
- **The 11 armour items** (travel_shirt/sleeves/trousers, forager_hood/vest/wraps/leggings, hide_bone_helm/cuirass/
  bracers/greaves) are rendered from their own kit GLBs in `game/assets/characters/survivor/armor/` through the same
  rig (`id=path.glb`, tier `model_v2`, script `glb:...` in the manifest), so they are the real textured meshes, not
  primitives. A full run / `--verify all` re-renders them from those GLBs.
- **Every render rises above its slot.** Flat items wider than ~1.39:1 cannot be lifted 12 % above the slot top
  without spilling past the side rims, so `kit.upright()` leans them onto the diagonal (<= 1.3:1). Fourteen
  builders use it (armor_scute, charcoal, cloth, copper_ore, dried_hide, lava, ore, pine_log, raw_meat, salt,
  sashimi, silver_ore, tent_kit, wood_log); ingots and the pearl are staged as a stack / open shell.
- **Replacement marking** (owner: low-quality / low-poly assets are marked for replacement): every entry carries
  `"quality": "procedural_v1"` (the 11 armour renders are `model_v2`); 29 carry a `"replace"` reason (the worst-reading renders plus pairs not told apart at
  slot size): armor_scute, berry, black_iron, burnt_food, capture_net_ii, clay, cloth, dense_bone, dried_hide, fish,
  grilled_meat, heavy_snare, ingot, iron_ingot, mango, metal_shard, obsidian, pillar, pine_log, raid_cuirass,
  raid_greaves, raptor_hide, raw_hide, seasoned_roast, sign_kit, smoked_meat, steel_ingot, stone_knife, tent_kit. The 32 items.json
  ids with no render are in the manifest's top-level `"missing"` array; they show the white symbol until art lands.
  The list lives in `REPLACE` in tools/render_icons.py so re-renders keep it. A GLB render (`id=path.glb`,
  `--quality model_v2`) is the upgrade route and clears the mark. Once an id holds GLB art, a full run and
  `--verify all` re-render it from its GLB (keeping its tier); if the GLB is gone the PNG and entry are left alone.
  The procedural builder never overwrites it.
- `game/data/item_rarity.json`: every items.json id (164) gets common/uncommon/rare/epic/legendary, plus tier colours.
- `game/scripts/ui/item_art.gd` (ItemArt): `texture_for` (render, then white ItemIcons symbol, then `_unknown`),
  `is_rendered`, `content_rect` (from the manifest rect; GPU readback only for symbol fallbacks), `rarity`,
  `rim_color`, `color_for_rarity`, `rarity_order`.
- `game/scripts/ui/art_slot.gd` (ArtSlot, a Button, 64 px floor): rarity rim + shadow glow + lower rarity wash;
  every object stands on one slot floor (80 % down) and its top rises 12-20 % above the slot (tall art 16 %, wide
  art lifts off the floor up to 20 % to reach 12 %), never past the side rims. Count bottom-right with a 14 px
  physical floor. Rarity pips climb the left rim from the floor (0 common, 1 uncommon .. 4 legendary diamonds), with
  a 4 px physical half-size floor, so rarity does not rest on colour alone. The frame is a square cell (full width,
  centred, never taller than wide); a tall slot keeps the whole button as its tap target. The interior is one step
  above INK_SOLID so dark items keep contrast. Focus draws a white ring outside the rim and a lighter, thicker rim with a wider, stronger glow;
  a press (touch or confirm) lights the frame the same way and sinks the art to 92 %. Samples with
  `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`; every render's .import now has `mipmaps/generate=true`.
  Style boxes cached per slot.
- Lab `--lab=item_art_lab`: 5x4 grid covering all five rarities + a row of white HUD action hexes; headless
  self-check. `--light` swaps to a light background (HANDOFF P7 dark/light check); `--ids=a,b,...` shows any items
  (with `--shot`) to review renders at slot size. The grid now fits a landscape phone (sized by height as well).
  Slot 14 (stone_knife) holds focus so the focus state is judged next to idle slots.
- Test `game/tests/t_iconart.gd`.

## Review 4 (2026-10-20, round 2): findings and what changed
| Severity | Finding | Fix | Evidence |
|---|---|---|---|
| major | Branch stale: base added 11 armour items with no tier; exact-equality `missing` check breaks whenever any package adds an item | Merged claude/mmo-overhaul (e93b863, clean, docs only since the last sync). The 11 got tiers by armour value: travel common, forager uncommon, hide and bone rare (`_assumption` updated). They are now rendered (above), so `missing` stays the same 32. The `missing` check is now: every listed id is a real unrendered item, and every unrendered item with no white symbol must be listed; an item another package adds that has a symbol does not fail it. The rarity-coverage check stays strict on purpose (an unlisted item would silently rim common), with a message that says where to add the tier | `[t_iconart] pngs=133 missing=32 unrendered=32`, `[t_iconart] PASS`; `merge-tree rc=0` |
| minor | ArtSlot rise wrong in non-square slots (64x120 lifted 6-9 %) | ArtSlot frames a square `cell()` (full width, at most as tall as wide, centred); rise, floor, wash, count and pips are measured against it | t_iconart checks the 12-20 % band for every manifest item at 80x80, 64x120, 140x64 and 64x64 |
| minor | Fallback test only checked non-null | Asserts `no_such_id` -> `ItemArt.UNKNOWN`, an unrendered item with a symbol -> its `ItemIcons.path_for` path, `steel_ingot` -> its render path | `[t_iconart] PASS` |
| minor | Pips ~6 px at a 64 px slot | Pip half-size floored at `PIP_PX = 4` physical px (8 px diamonds), capped so 4 pips fit; pips climb the left rim so they never meet an `x999` count. Also found: `get_screen_transform()` leaves out the canvas_items stretch (reported 1.0 at 844x390 where the stretch is 0.433), so the 14 px count floor never applied on a phone; `screen_scale()` now uses the viewport's final transform | t_iconart `_test_stretch`: `[t_iconart] stretch final=0.500 slot=0.500`, count and pip floors hold on screen; pips clear of `x999` and inside the frame for 3- and 4-pip items |
| minor | Dark items low contrast on the slot interior | Interior lifted one step (`INTERIOR` 0.12/0.13/0.14 vs INK_SOLID); stone_knife gets a `replace` mark (obsidian and black_iron already had one) | t_iconart: interior luminance >= INK_SOLID + 0.05; `r5_armour_gl.png` |
| minor | ~5 MB of lossless textures in the web pack, no concrete option | Measured options (below) and handed one to W1-WEB | `[webweight] n=133 { "lossless256": 5516168, "lossy80_256": 1754002, "lossless128": 2034548, "lossy80_128": 889768 }` |

## Review 3 (2026-10-20): findings and what changed
| Severity | Finding | Fix | Evidence |
|---|---|---|---|
| blocker | Branch carried hand-copied STATUS/plan-register/contracts and the Durango pack; `merge-tree` conflicted in STATUS.md | Restored those paths to the merge base (ea2d167) so the branch no longer touches them (commit "drop hand-copied orchestrator docs") | `git merge-tree --write-tree claude/mmo-overhaul HEAD` -> `merge-tree rc=0`; `git diff --name-only claude/mmo-overhaul...HEAD -- docs` lists only this report |
| major | `_rects` sentinel key `""` made `is_rendered(&"")` true and `texture_for(&"")` load `render/.png` | `static var _rects_loaded` flag instead of the sentinel | t_iconart now asserts the empty id is not rendered, falls back to a texture, is not cached, and that `_rects` has no `""` key. Run against the old item_art.gd it printed `ERROR: Resource file not found: res://assets/icons/render/.png`, `[t_iconart] FAIL empty id is not rendered`, `... FAIL empty id is not cached`, `... FAIL manifest rects hold no empty key`; with the fix `[t_iconart] PASS` |
| minor | `--verify all` ended `REPRO FAIL n=122` (herb_buff_meal, split_wood) | Two causes: herb_buff_meal changed over ~3700 px by <= 2 LSB between full runs (emissive star sampled as a light, so the light tree's emitter order mattered); split_wood changed 1 px by 1 LSB between two runs started together (threaded BVH build). Emissive materials now use `cycles.emission_sampling = "NONE"` and the rig renders on 1 thread (RIG `threads: 1`, `emission_sampling: NONE` in the manifest). The 12 emissive items were re-rendered; 9 PNGs changed (burnt_food, charcoal, herb_buff_meal, lava, raid_maul, resin, toxin_coating, toxin_pot, venom_gland), side by side they look the same (`emit_compare.png`). Non-emissive renders are byte-identical at 1 and 4 threads (bamboo, split_wood checked), so nothing else was re-rendered. | See the REPRO line in the checklist |
| minor | A full run rebuilt the manifest from empty and overwrote model_v2 art with procedural art | `plan()` in render_icons.py: a full run starts from the manifest's `glb:` entries, renders those ids from their GLB (keeping their tier), and skips them if the GLB is missing; `--only` of such an id prints `SKIP` | `render_icons.py -- --selftest` -> `SELFTEST PASS` |
| minor | Focus/press was a 1 px wider border | White focus ring, lighter + thicker rim, wider and stronger glow, art sinks on press | t_iconart `_test_slot_states` (lit rim luminance +0.12, glow +6 px and stronger, thicker border, press scale <= 0.95); `lab9_focus_zoom.png` |
| minor | No mipmaps for 256 px art drawn at ~60 px | `mipmaps/generate=true` in all 122 .import files; ArtSlot samples with mipmaps | t_iconart `_test_mipmaps` (every .import has it; the imported fish texture `has_mipmaps()`) |
| minor | Rarity by colour only; confusable families | Rarity pips 0-4 | t_iconart: five tiers give five pip counts; screenshots. The confusable families stay in the `replace` register for W2 art |

Web payload: the 133 imported textures (lossless, mipmaps) total 6,046,506 bytes in `.godot/imported` (source PNGs
5.1 MB). Measured per-mip WebP sizes for the whole set (scratchpad `web_weight.gd`): lossless 256 px 5.5 MB, lossy
q0.8 256 px **1.75 MB**, lossless 128 px 2.0 MB, lossy q0.8 128 px 0.89 MB.
**Option for W1-WEB:** keep 256 px and switch the render imports to lossy WebP at 0.8, which is about 70 % smaller. Side by side at
1:1 (`lossy/sheet.png`: hide_bone_helm, fish, raid_maul, stone_knife) I could not tell lossy from lossless. It is one command, then a re-import:
`sed -i '' 's/^compress\/mode=0/compress\/mode=1/; s/^compress\/lossy_quality=0.7/compress\/lossy_quality=0.8/' game/assets/icons/render/*.png.import`
Same VRAM (decoded to RGBA8). 128 px is not recommended: on a 3x phone the slot is ~170 physical px.

## Acceptance checklist (exact lines seen this session)
- >= 60 PNGs, 256x256 RGBA, edge rows transparent, <= 64 KB, manifest with script, settings and pixel-true rect,
  rarity for every item, `missing` complete, every manifest item rising 12-20 % above the slot inside the side
  rims, the review's illegible renders marked `replace`, empty-id fallback, slot states, pips, mipmaps:
  `[t_iconart] pngs=133 missing=32 unrendered=32`, `[t_iconart] stretch final=0.500 slot=0.500`, then `[t_iconart] PASS`
- Byte-identical re-render, every item: two `Blender -b --factory-startup -P tools/render_icons.py -- --verify all`
  runs side by side (`verify_r3a.log`, `verify_r3b.log`): both ended `REPRO PASS n=122`, with `REPRO herb_buff_meal identical` and `REPRO split_wood identical`, no DIFFERS line.
  Round 4 (armour GLB renders + two procedural): `--verify travel_shirt,...,hide_bone_greaves,stone_knife,raid_maul`
  -> 13 `identical` lines, `REPRO PASS n=13`. The armour renders also matched byte for byte between a scratch run and
  the real run (same sha256 prefixes). A full `--verify all` (n=133) was not re-run this round (about 40 min).
- Manifest planning keeps model art: `Blender -b --factory-startup -P tools/render_icons.py -- --selftest` -> `SELFTEST PASS`
- Lab grid, every rarity, all rendered, every object framed (rise 12-20 %, inside the rims, on the floor), count
  >= 14 px on screen: `[itemart] slots=20 rarities=5 rendered=20 framed=true count_px_ok=true ok=true`
- Lab windowed at 1600x900, 844x390 and 390x844, screenshots inspected (below): art rises above every slot
  top edge, rims and glows coloured by rarity (grey/green/blue/purple/orange) with 0-4 pips, the focused
  stone_knife slot clearly ringed, MENU/SKILLS/BUILD/ANIMALS glyphs white; copper, bronze, iron, steel ingot and
  straw_roll_kit have art (top row).
- `ItemArt.texture_for(&"no_such_id")` and `texture_for(&"")` return the fallback with no error: covered in
  t_iconart (`[t_iconart] PASS`, no ERROR lines in the log)
- `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS` (round 4, after the merge of e93b863)
- `run_all.gd`: `[tests] PASS` (round 4)
- Branch merges cleanly into claude/mmo-overhaul (e93b863): `merge-tree rc=0`

## Screenshots inspected
All under /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/
- Round 4: `r5_armour_gl.png` (gl_compatibility 1600x900), `r5_armour_fwd.png` (Forward+), `r5_armour_phone.png`
  (844x390), `--ids=` the 11 armour items, raid gear, stone_knife, obsidian, black_iron, iron_ingot, raid_maul,
  steel_ingot. Armour reads as real textured gear (shirt, sleeves, jeans, straw hat, quilted vest, bone skull helm,
  scaled cuirass, spiked bracers and greaves) and rises above the slot; pips stack up the left rim and do not touch
  the counts; on the phone shot the 1-4 pips are countable at 1:1. The stone_knife blade now separates from the
  lighter interior; obsidian and black_iron are still one dark family (both marked replace).
- Round 4 sheets: `../../armour1/sheet.png` (first GLB try, pieces shrunk to specks by the stray Icosphere),
  `../../armour2/sheet.png` (fixed), `../../lossy/sheet.png` (lossless vs lossy q0.8 pairs).
- `lab9_1600x900.png`: the 5x4 grid; every object breaks the slot top edge; pips 1/2/3/4 on the green/blue/
  purple/orange slots, none on grey; the focused stone_knife has a white ring and a lighter rim and glow; hex glyphs white.
- `lab9_focus_zoom.png`: 2x crop of work_pick (idle), stone_knife (focused), slingshot (idle, 1 pip): focus is
  plain at a glance.
- `lab9_844x390.png` (landscape phone) and `lab9_390x844.png` (portrait): whole grid fits; pips are small but
  countable at 1:1; counts read. HexButton captions are tiny (W1-UI's widget, not ArtSlot).
- `emit_compare.png`: before/after pairs of the 9 re-rendered emissive items; no visible change.
- Earlier rounds: `lab7_844x390.png`, `lab7_844x390_light.png`, `lab7_flat_1600x900.png`, `upright_sheet.png`,
  `final_part_a{a,b,c}.png`.
- Not taken: a shot of a slot mid-press (press is checked by the test and by reading the code only).

## Assumptions
- `# ASSUMPTION` in item_rarity.json (`_assumption`): placeholder tiers by material ladder until W2-DATA's rare-item
  design; bulk materials (iron_ingot, steel_ingot, black_iron) capped at rare so epic/legendary glow stays a gear signal.
- Flat items are staged on a diagonal (`kit.upright`) rather than letting the slot shrink them below the top edge.
- Rarity pips: one diamond per tier above common (common shows none). The PRD does not specify a rarity mark.
- Armour tiers by armour value (travel 15-30 common, forager 40-110 uncommon, hide and bone 120-350 rare, raid 700
  epic); placeholder like the rest of item_rarity.json.
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
- Round 4, armour art: both helmet icons include the survivor's face because the kit's helmet slot mesh is the whole
  head (forager_hood is a face under a straw hat; hide_bone_helm is a face inside a skull). They read fine at slot size, but
  W2 art should cut the face from the helmet piece. They are not marked `replace`, because a GLB render clears marks on
  re-render. hide_bone_helm has two stray specks of loose geometry at the sides, which widen its rect slightly.
- For the armour kit owner: every armour kit GLB (travel_clothes, forager, hide_and_bone: all 11 framed as specks before the fix; I listed the objects of 3 of them)
  carries an unskinned `Icosphere` mesh of radius 1 m at the origin, beside the skinned slot mesh. render_icons.py now drops it.
  I did not check whether it shows in game.
- t_iconart is standalone (see Integrator hooks).
- One-thread renders are slower: a full `--verify all` took about 39 minutes per run (two in parallel, one core each) on the shared box.
- Every icon is procedural_v1 and should be replaced by higher-quality art (marked in the manifest); 28 are flagged
  first. The confusable families (four drumsticks, iron/steel/ingot, obsidian/black_iron), noisy fish/mango, the
  single-ball berry and the flat tent_kit are in that list; W2 art should give them distinct silhouettes.
- New renders get Godot's default import (no mipmaps); t_iconart fails until their .import says
  `mipmaps/generate=true` (round 4 did this with one sed over the new .import files, then re-imported).
- HexButton captions are tiny on an 844x390 window (W1-UI's phone layout).
