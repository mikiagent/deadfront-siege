# W1-ICONART report (claude, branch claude/mmo-w1-iconart)

## What shipped
- **122 rendered item PNGs** (121 items + `_unknown` silhouette) in `game/assets/icons/render/`, built by procedural
  bpy builders in `tools/blender/items/{resources,gear,food,camp}.py` through `tools/render_icons.py`
  (headless Blender 5.2 only, one studio rig `studio_v1`: Cycles on one CPU thread, fixed seed and samples, no
  denoiser, emissive materials not sampled as lights; deterministic PNG encoder). `manifest.json` lists item id, source script, builder, sha256, bytes, opaque rect
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
  `--quality model_v2`) is the upgrade route and clears the mark. Once an id holds GLB art, a full run and
  `--verify all` re-render it from its GLB (keeping its tier); if the GLB is gone the PNG and entry are left alone.
  The procedural builder never overwrites it.
- `game/data/item_rarity.json`: every items.json id (153) gets common/uncommon/rare/epic/legendary, plus tier colours.
- `game/scripts/ui/item_art.gd` (ItemArt): `texture_for` (render, then white ItemIcons symbol, then `_unknown`),
  `is_rendered`, `content_rect` (from the manifest rect; GPU readback only for symbol fallbacks), `rarity`,
  `rim_color`, `color_for_rarity`, `rarity_order`.
- `game/scripts/ui/art_slot.gd` (ArtSlot, a Button, 64 px floor): rarity rim + shadow glow + lower rarity wash;
  every object stands on one slot floor (80 % down) and its top rises 12-20 % above the slot (tall art 16 %, wide
  art lifts off the floor up to 20 % to reach 12 %), never past the side rims. Count bottom-right with a 14 px
  physical floor. Rarity pips bottom-left (0 common, 1 uncommon .. 4 legendary diamonds), so rarity does not rest
  on colour alone. Focus draws a white ring outside the rim and a lighter, thicker rim with a wider, stronger glow;
  a press (touch or confirm) lights the frame the same way and sinks the art to 92 %. Samples with
  `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`; every render's .import now has `mipmaps/generate=true`.
  Style boxes cached per slot.
- Lab `--lab=item_art_lab`: 5x4 grid covering all five rarities + a row of white HUD action hexes; headless
  self-check. `--light` swaps to a light background (HANDOFF P7 dark/light check); `--ids=a,b,...` shows any items
  (with `--shot`) to review renders at slot size. The grid now fits a landscape phone (sized by height as well).
  Slot 14 (stone_knife) holds focus so the focus state is judged next to idle slots.
- Test `game/tests/t_iconart.gd`.

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

Web payload: the 122 imported textures (lossless, now with mipmaps) total 5,102,890 bytes in `.godot/imported`
(source PNGs 4.6 MB). Not changed here; W1-WEB can export a 128 px or lossy-with-alpha variant if it needs the room.

## Acceptance checklist (exact lines seen this session)
- >= 60 PNGs, 256x256 RGBA, edge rows transparent, <= 64 KB, manifest with script, settings and pixel-true rect,
  rarity for every item, `missing` complete, every manifest item rising 12-20 % above the slot inside the side
  rims, the review's illegible renders marked `replace`, empty-id fallback, slot states, pips, mipmaps:
  `[t_iconart] pngs=122 missing=32` then `[t_iconart] PASS`
- Byte-identical re-render, every item: two `Blender -b --factory-startup -P tools/render_icons.py -- --verify all`
  runs side by side (`verify_r3a.log`, `verify_r3b.log`): both ended `REPRO PASS n=122`, with `REPRO herb_buff_meal identical` and `REPRO split_wood identical`, no DIFFERS line
- Manifest planning keeps model art: `Blender -b --factory-startup -P tools/render_icons.py -- --selftest` -> `SELFTEST PASS`
- Lab grid, every rarity, all rendered, every object framed (rise 12-20 %, inside the rims, on the floor), count
  >= 14 px on screen: `[itemart] slots=20 rarities=5 rendered=20 framed=true count_px_ok=true ok=true`
- Lab windowed at 1600x900, 844x390 and 390x844, screenshots inspected (below): art rises above every slot
  top edge, rims and glows coloured by rarity (grey/green/blue/purple/orange) with 0-4 pips, the focused
  stone_knife slot clearly ringed, MENU/SKILLS/BUILD/ANIMALS glyphs white; copper, bronze, iron, steel ingot and
  straw_roll_kit have art (top row).
- `ItemArt.texture_for(&"no_such_id")` and `texture_for(&"")` return the fallback with no error: covered in
  t_iconart (`[t_iconart] PASS`, no ERROR lines in the log)
- `tools/smoke.sh --no-import` (through gslot): `SMOKE PASS`
- `run_all.gd`: `[tests] PASS`
- Branch merges cleanly into claude/mmo-overhaul: `merge-tree rc=0`

## Screenshots inspected
All under /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/iconart/
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
- One-thread renders are slower: a full `--verify all` took about 39 minutes per run (two in parallel, one core each) on the shared box.
- Every icon is procedural_v1 and should be replaced by higher-quality art (marked in the manifest); 28 are flagged
  first. The confusable families (four drumsticks, iron/steel/ingot, obsidian/black_iron), noisy fish/mango, the
  single-ball berry and the flat tent_kit are in that list; W2 art should give them distinct silhouettes.
- New renders get Godot's default import (no mipmaps); t_iconart fails until their .import says
  `mipmaps/generate=true`.
- HexButton captions are tiny on an 844x390 window (W1-UI's phone layout).
