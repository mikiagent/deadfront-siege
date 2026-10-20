# W1-UIICONS: one custom white icon set for every UI action and HUD element

Branch `claude/mmo-w1-uiicons`, cut from `claude/mmo-overhaul`. Commits:

- `efd7ce2` 112 hand-written white SVG icons, `data/ui_icons.json`, `UiIcons` loader
- `29ebb17` owner direction sync from `claude/mmo-overhaul` (not package work)
- `a69d827` optical-centring nudges on 30 icons, the lab (`ui_icons_lab`) and `t_uiicons`
- this report

No Meshy or Tripo credits spent. Owner complaint (2026-10-19): "functionally it's fine but the symbols/icons need work".

## What shipped

- `game/assets/icons/ui/*.svg`: 112 drawings, all on a 64x64 grid (live area 6..58). They use one line weight (`stroke-width 5`, round caps and joins) and fill solid shapes with a 1.5 softening stroke. White `#FFFFFF` is the only paint, and no icon contains text. The motifs are prehistoric: bone club (attack), flint hand-axe (chop), stone pick (mine), bone knife (butcher), hide tent (build, warp_home), lashed fence (pen), hide shirt (tailoring), rope lasso (snare), knotted net (net), raptor head (animals, sic, dismiss), tripod drying rack, crock pot, mortar and stone grill. Import: `svg/scale=2.0` (128 px texture) with mipmaps, so the icons stay crisp from 24 to 64 px and when the HUD scales down.
- `game/data/ui_icons.json`: 165 action ids map to the 112 files (an alias such as `capture` uses `net`). It also has `glyphs`, a table of the 54 legacy emoji and symbol characters with the action id that replaces each, `typographic`, a list of symbols that stay text (`× · • … — – → ○ ≥`), and `fallback: "action"`.
- `game/scripts/ui/ui_icons.gd`: the `UiIcons` class. `UiIcons.icon(id) -> Texture2D` returns the cached texture. An unknown id returns the `action` sparkle with a warning, and `""` returns null. `UiIcons.path_for(id)` returns the file path, and `UiIcons.for_glyph("🏃")` is the migration helper for legacy glyphs. Spec deviation: the brief asked for `UiIcons.get(id)`, but a static `get()` shadows `Object.get` and does not compile, so the method is `icon()`.
- `game/scripts/dev/ui_icons_lab.gd` and `game/scenes/dev/ui_icons_lab.tscn`. The lab has four modes, chosen with `--icons=`:
  - `sheet`: every icon in a real 64 px `HexButton` over the lab world, with its id.
  - `sizes:<page>`, pages 0 to 5: each icon at 24, 32, 48 and 64 px on the dark `UiTokens.INK` panel, at 24, 32 and 48 px in ink on a light panel, and in a 72 px hex.
  - `hud`: the real HuntHud with its legacy glyphs swapped for icons at runtime, a preview of the hooks below.
  - `filter`: linear filtering compared with linear plus mipmaps at 24 and 32 px.

  Headless without `--shot`, the lab loads every icon through `UiIcons` and checks it is 128 px with mipmaps.
- `game/tests/t_uiicons.gd` checks:
  - Every id resolves to an existing SVG, and every SVG is used by some id.
  - Every SVG is on the 64 grid and contains no style, opacity, gradient, image, text or `currentColor`. Every fill and stroke is white, and every stroke-width is a house weight.
  - Each SVG rasterised by the engine has no off-white pixel and stays inside 2..61. Its optical centre (the mean of the bbox centre and the alpha centroid) is within 3 grid units of 32,32.
  - Every inventoried action, every `statuses.json` status and every skill tree in `trees.json` has an icon.
  - Every non-ASCII symbol in a string literal of `scripts/ui/*.gd`, `scripts/world/*.gd`, `player.gd` and `skill_state.gd` is mapped to an icon or listed as typographic.
  - The loader falls back safely, `for_glyph` works, and textures import at 2x with mipmaps.

## Acceptance (run on `a69d827`, every line copied from the run's output)

| Check | Command | Result |
|---|---|---|
| t_uiicons | `gslot.sh Godot --headless --path game --script res://tests/t_uiicons.gd` | `[t_uiicons] PASS ids=165 files=112 glyphs=54` (exit 0) |
| run_all | `gslot.sh Godot --headless --path game --script res://tests/run_all.gd` | `[tests] PASS` (exit 0) |
| smoke | `gslot.sh tools/smoke.sh --no-import` | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` / `SMOKE PASS` |
| lab headless | `gslot.sh Godot --headless --path game -- --lab=ui_icons_lab` | `[uiicons_lab] icons=112 bad=[] fallback=true` (exit 0) |
| at least 48 icons | t_uiicons | 112 files, 165 ids |

The expected warning `[ui_icons] no icon for 'no_such_action_xyz', using fallback` comes from the fallback test.

## Screenshots looked at

All screenshots are in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1x/uiicons/`. They were taken in windowed mode after the import that followed the centring commit (`.ctex` 20:42:44, shots 20:42:58 to 20:46:31). Each one was opened with Read.

- `fwd_sheet_1600.png`, `gl_sheet_1600.png`: all 112 icons on real 64 px hexes, Forward+ and gl_compatibility. They show one family: the same line weight, solid silhouettes, centred in the hex, with no colour. The two renderers look the same.
- `fwd_sheet_phone.png`, `gl_sheet_phone.png` (844x390 landscape): every hex is still readable as a shape.
- `fwd_sizes_p0_1600.png` to `fwd_sizes_p5_1600.png`, `gl_sizes_p0_1600.png`: all 112 icons at 24, 32, 48 and 64 px on dark and light panels and in a 72 px hex. No blurry edges, no off-centre glyphs. The thin details (net knots, steam lines, map fold) survive at 24 px.
- `zoom_fwd_sizes_p0.png`, `zoom_fwd_sheet_a.png`: nearest-neighbour zooms. Edges are anti-aliased, with no halo or dark fringe on the light panel.
- `fwd_hud_1600.png`, `gl_hud_1600.png`, `fwd_hud_phone.png`, `gl_hud_phone.png`, and the zooms `zoom_gl_hud_phone_r.png` and `zoom_fwd_hud_phone_l.png`: the real HUD with the hooks previewed. The rail shows menu, animals, build and skills, the combat cluster shows feed, net, tackle, kick, roll and auto, and chase is on the left. No system emoji remain on the hexes.
- `fwd_filter_1600.png`: linear compared with linear plus mipmaps. At 24 px the mipmapped row is a little steadier. Hook 1 below.

Findings from the screenshots:
- At 844x390 rendered at 1x, the HUD draws its hexes at about 34 px, so each icon is about 20 px. The densest icons (chase, auto, kick) soften there. A real phone renders the same layout at 2x or 3x, so this is the worst case. The HUD hex size belongs to the UI package.
- The RESTED fatigue face in the top-left is a coloured meter drawn by hunt_hud, not an action, so it was left as it is.

## Glyph and icon inventory

Sources were grepped for emoji and symbol code points (U+2010 and above, string literals only) and for icon paths: `game/scripts/ui/*.gd`, `game/scripts/world/*.gd`, `player.gd` (context actions) and `skill_state.gd` (skill-tree glyphs). Item icons (`res://assets/icons/%s.png` in craft_card, pickup_toast, station_menu and station_radial, plus ItemIcons and game-icons) are things, so they keep colour and are out of scope.

Legacy glyph collisions this set resolves (one emoji meant several actions):
- 🍖: eat, cook and stone grill.
- 🔥: cauterise and bonfire or campfire.
- 💧: drink and well.
- 🦖: animals and sic.
- ◎: stance and t-stones.
- 🛡: guard and defense.
- The single letters `F`, `V`, `C`, `S` and the words `Auto` and `FEED` stand for fire, toxin, siege, snare, auto and feed.

The hooks below therefore wire by action id, not by glyph.

| icon file | action ids (aliases) | legacy glyph sites (file:line) |
|---|---|---|
| action | action | station_menu.gd:76 `✦` |
| aid | aid, bandage | Bandage use (items.json bandage); future inventory Use verb |
| animals | animals, pets | hunt_hud.gd:208 `🦖`; hunt_hud.gd:315 `🦖` |
| attack | attack | player attack / Attack Stance (hunt_hud.gd:337 label); combat tap |
| auto | auto | hunt_hud.gd:306 "Auto" |
| back | back | skills_sheet.gd:153 `◀` |
| bag | bag, inventory | inventory open (I key, inventory_ui.gd); pause/menu sheet |
| bleed | bleed, bleeding_target | statuses.json bleed, bleeding_target; creature_plates.gd:457 _add_status rows (letter glyphs today) |
| bleed_deep | bleed_deep, deep_bleed | statuses.json deep_bleed; creature_plates.gd:466 (letter "B") |
| blocked | blocked | gather_radial.gd:186 `⊘`; gather_radial.gd:83 `⊘`; hex_button.gd:43 `⊘` |
| build | build, place | hunt_hud.gd:210 `⌂` |
| butcher | tool_knife, butcher, butchering | creature_plates.gd:273 `🔪`; creature_plates.gd:94 `🔪`; skill_state.gd:12 `🔪` |
| cargo | warp, cargo | player.gd:2237 `📦` |
| cauterise | cauterise | craft_ui.gd:11 `🔥`; player.gd:2228 `🔥`; station_menu.gd:56 `🔥` |
| chase | chase | hunt_hud.gd:344 `🏃`; hunt_hud.gd:351 `🏃` |
| chat | chat | forward: MMO chat button (no chat UI in this branch yet) |
| chop | tool_axe, chop | gather verb (survivor.json chop clip, gather_radial.gd:70 per-item hexes); held tool axe (held_item_slot.gd:49) |
| claim | claim | player.gd:2243 `▦` |
| close | close, cancel, place_cancel | hunt_hud.gd:491 `✕`; inventory_ui.gd:83 `✕` |
| coast | coast, coastal | world_ui.gd:98 `◒` |
| coat | coat_weapon, coat | player.gd:2210 context "coat_weapon" (glyph "V") |
| confirm | confirm, place_confirm, done, ok | hex_button.gd:49 `✓`; hunt_hud.gd:481 `✓`; hunt_hud.gd:491 `✓` |
| construction | construction | skill_state.gd:12 `🏗` |
| cook | cook | player.gd:2226 context "cook" (glyph 🍖, collides with eat); station_menu.gd:23 bonfire COOK |
| craft | craft, station_workbench, weapon_tools | craft_ui.gd:11 `🔨`; skill_state.gd:12 `🔨`; station_menu.gd:23 `🔨`; station_menu.gd:51 `🔨` |
| deafened | deafened | statuses.json deafened (status rows) |
| dig | tool_hoe, dig | gather verb (survivor.json dig clip); held tool hoe |
| dismiss | dismiss | animal_screen.gd:223, hunt_hud.gd:724 pet commands |
| dismount | dismount | player.gd:2200 `⤓` |
| drink | drink | craft_ui.gd:13 `💧`; player.gd:2218 `💧` |
| eat | eat, quick_food | craft_ui.gd:12 `🍖`; hunt_hud.gd:216 `🍖`; hunt_hud.gd:246 `🍖`; player.gd:2226 `🍖` +2 more |
| end_combat | end_combat | hunt_hud.gd:282 _end_btn "End combat" |
| enraged | enraged | statuses.json enraged |
| equip | equip | animal_screen.gd:223 equip saddle/gear; player.gd:849 |
| farming | farming | skill_state.gd:12 `🌾` |
| feed | feed, tame, feed_pet | hunt_hud.gd:328 "FEED"; hunt_hud.gd:329 "FEED" |
| fire_ranged | fire_ranged, fire | hunt_hud.gd:873 "F"; player.gd:2208 "F" |
| fish | fish | gather verb (survivor.json fish clip) |
| fists | fists | held_item_slot.gd:47 "FISTS" |
| forest | forest | world_ui.gd:95 `♣` |
| fracture | fracture | statuses.json fracture |
| full | full | statuses.json full (food buff) |
| gathering | gathering | skill_state.gd:12 `🌿` |
| groggy | groggy, dizziness | statuses.json groggy, dizziness |
| guard | guard, defense | hunt_hud.gd:315 `🛡`; skill_state.gd:12 `🛡` |
| hands | hands, tool_none, craft_hand | held_item_slot.gd:47 "HANDS" |
| harbour | harbour, harbour_routes | player.gd:2234 `⚓` |
| heel | heel | hunt_hud.gd:315 `↩` |
| hold | hold | craft_ui.gd:11 `✋`; hunt_hud.gd:351 `✋` |
| infected | infected, infected_wound | statuses.json infected_wound |
| inspect | inspect, debug | hunt_hud.gd:224 `🔍` |
| kick | kick | hunt_hud.gd:296 `🦵` |
| knockdown | knockdown | statuses.json knockdown |
| layout | layout, move | hunt_hud.gd:480 HUD layout mode ("Layout saved") |
| lock | lock | creature_plates.gd:94 `🔒` |
| loot | loot | player.gd:2231 `🎒` |
| map | map | map_screen.gd open (input_setup.gd:27 "map" action, hunt_hud.gd:693 minimap tap) |
| market | market, exchange | forward: island market / exchange (data/world/market.json); no button yet |
| meadow | meadow | craft_ui.gd:160 `●`; world_ui.gd:94 `●` |
| melee | melee, skill_melee | skill_state.gd:12 `⚔` |
| menu | menu | hunt_hud.gd:206 `≡` |
| mine | tool_pick, mine | gather verb (survivor.json mine clip); held tool pick |
| mute | mute | forward: settings sound toggle |
| net | net, capture | hunt_hud.gd:296 `🕸`; hunt_hud.gd:873 `🕸` |
| notice | notice | notice toasts (Game.notice, core/game.gd:115) |
| pack_up | pack_up | build_placer.gd:183 pack up a placed building |
| pen | pen | player.gd:2240 `🪤` |
| pick | pick | gather verb (berries, plants: gather_radial.gd) |
| pinned | pinned | statuses.json pinned |
| processing | processing | skill_state.gd:12 `⚙` |
| ranged | ranged | skill_state.gd:12 `🏹` |
| recall_camp | recall_camp | pet/camp recall (hunt_hud whistle row, warp to camp) |
| river | river, riverside | world_ui.gd:97 `≈` |
| rocky | rocky | world_ui.gd:96 `▲` |
| roll | roll | hunt_hud.gd:296 `↯` |
| rotate | rotate, place_rotate | hunt_hud.gd:491 `↻` |
| save | save | forward: menu Save (save_game.gd) |
| settings | settings | forward: menu Settings (core/settings.gd) |
| sic | sic | hunt_hud.gd:315 whistle ["attack", 🦖, "SIC"] (🦖 collides with animals) |
| siege | catapult_stone, siege | hunt_hud.gd:877 "C"; player.gd:2204 "C" |
| skills | skills | hunt_hud.gd:212 `★` |
| sleep | sleep | player.gd:2223 `☾`; station_menu.gd:20 `☾`; station_menu.gd:21 `☾`; station_menu.gd:22 `☾` |
| snare | rope_snare, heavy_snare, snare, snared | player.gd:2213 context rope_snare/heavy_snare (glyph "S"); statuses.json snared |
| sound | sound | forward: settings sound toggle |
| stance | stance | hunt_hud.gd:337 `◎`; hunt_hud.gd:641 `◎` |
| station_dryer | station_dryer, station_drying_rack | craft_ui.gd:12 `🪢` |
| station_fire | station_fire, station_bonfire, station_campfire | craft_ui.gd:11 bonfire/campfire (🔥 collides with cauterise) |
| station_grill | station_grill, station_stone_grill | craft_ui.gd:12 stone_grill (🍖 collides with eat) |
| station_mortar | station_mortar | craft_ui.gd:12 `🥣` |
| station_pot | station_pot, station_crock_pot, cooking | craft_ui.gd:12 `🍲`; skill_state.gd:12 `🍲` |
| station_steamer | station_steamer | craft_ui.gd:13 `♨` |
| station_well | station_well | craft_ui.gd:13 well (💧 collides with drink) |
| stomachache | stomachache | statuses.json stomachache (items/food.gd:78) |
| store | store | inventory_ui.gd:215 storage "Store" |
| summon | summon | player.gd:1681, hunt_hud.gd:724 pet summon |
| survival | survival | skill_state.gd:12 `🧭` |
| swap | swap | held_item_slot.gd:154 `⇄`; held_item_slot.gd:155 `⇄` |
| t_stone | t_stone, t_stones | hunt_hud.gd:641 level-up "◎ %d" t-stones (◎ collides with stance) |
| tackle | tackle | hunt_hud.gd:296 `💥`; hunt_hud.gd:868 `💥` |
| tailoring | tailoring | skill_state.gd:12 `🧵` |
| take_all | take_all | inventory_ui.gd:216 storage "Take all" |
| tastes_bad | tastes_bad | statuses.json tastes_bad |
| toxin | catapult_toxin, toxin | hunt_hud.gd:868 "V"; player.gd:2205 "V"; player.gd:2210 "V" |
| unlock | unlock | skills_sheet.gd node unlock (trees.json) |
| use | use, interact | inventory/world Use and interact |
| venom | venom, poisoned_target | statuses.json venom, poisoned_target |
| warp_home | warp_home | map_screen.gd:49, world_ui.gd:204 warp home |
| wash | wash | player.gd:2219 `🫧` |
| wet | wet | statuses.json wet (player.gd:471) |
| xp | xp, pioneer_xp | hunt_hud.gd:640 `👁` |
| zoom_in | zoom_in | map_screen.gd zoom "+" (next to the − at :34) |
| zoom_out | zoom_out | map_screen.gd:34 `−` |

Typographic symbols that stay text: `× · • … — – → ○ ≥` (counts, separators, ellipsis). Note that `craft_ui.gd:160 "● here"` is a bullet, not the meadow icon.

## Integrator hooks (UI package: hex_button.gd, hunt_hud.gd and the other ui/*.gd)

This package does not edit any UI script. Each change below is exact. After them, `UiIcons` is the only source of action art, and the `glyph` strings become dead text.

1. `hex_button.gd`: keep icons crisp when scaled, and skip whitening icons that are already white. Add this line to `_init`:
   ```gdscript
   texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
   ```
   In `_draw` (line 96), replace
   `var shown: Texture2D = icon if color_icon else _white_symbol(icon)`
   with
   ```gdscript
   var shown: Texture2D = icon if color_icon or icon.resource_path.begins_with(UiIcons.DIR) else _white_symbol(icon)
   ```
   `_white_symbol` copies each icon into an `ImageTexture` once, with a per-pixel loop. That work is wasted on these icons, which are already white. The lab sets this filter on its own hexes (`ui_icons_lab.gd` `_hex`, comment "integrator hook 1").
2. `hex_button.gd` badges: `set_blocked` (line 43, `badge = "⊘"`) and `set_ok_badge` (line 49, `badge = "✓"`) draw text in the badge circle. Draw `UiIcons.icon(&"blocked")` and `UiIcons.icon(&"confirm")` in that circle at 0.8 of its radius instead. `gather_radial.gd:83` and `:186` (`b.badge = "⊘"`) need no change once the badge draws the icon.
3. `hunt_hud.gd`:
   - `_hex()` (lines 198-203): change the parameter to `id: StringName` and replace `h.glyph = glyph` with `h.icon = UiIcons.icon(id)`. Callers: `206 _hex(&"menu", HEX, "MENU")`, `208 _hex(&"animals", ...)`, `210 _hex(&"build", ...)`, `212 _hex(&"skills", ...)`, `224 _hex(&"inspect", 56.0, "DEBUG")`.
   - Line 216, `fh.glyph = "🍖"`: replace with `fh.icon = UiIcons.icon(&"eat")`.
   - Lines 244-246: replace with
     ```gdscript
     h.icon = tex if tex else UiIcons.icon(&"eat")
     h.color_icon = tex != null
     h.glyph = ""
     ```
   - Line 299, combat specs: replace `h.glyph = s[0]` with `h.icon = UiIcons.icon(StringName(s[1]))` (net, tackle, kick, roll).
   - Line 306: replace `_auto_hex.glyph = "Auto"` with `_auto_hex.icon = UiIcons.icon(&"auto")`.
   - Line 317, whistles: replace `wh.glyph = spec[1]` with `wh.icon = UiIcons.icon(&"sic" if spec[0] == "attack" else StringName(spec[0]))` (sic, heel, guard).
   - Line 328: replace `_feed_hex.glyph = "FEED"` with `_feed_hex.icon = UiIcons.icon(&"feed")`.
   - Line 344: replace `_chase_hex.glyph = "🏃"` with `_chase_hex.icon = UiIcons.icon(&"chase")`. Line 351: replace it with `_chase_hex.icon = UiIcons.icon(&"hold" if player.hunt.hold else &"chase")`.
   - Line 481: replace `_done_hex.glyph = "✓"` with `_done_hex.icon = UiIcons.icon(&"confirm")`.
   - Line 494, placement: replace `h.glyph = sp[0]` with `h.icon = UiIcons.icon(StringName(sp[1]))` (rotate, confirm, cancel).
   - Lines 587-593, context actions: replace the `glyph` lines with
     ```gdscript
     var id := str(a["id"])
     h.icon = UiIcons.icon(StringName(id))
     h.caption = str(a["label"]).to_upper()
     h.bottom_text = str(a.get("uses", ""))
     ```
     Every id that `player.context_actions()` emits has an icon, and t_uiicons enforces it: dismount, catapult_stone, catapult_toxin, fire_ranged, coat_weapon, rope_snare, heavy_snare, drink, wash, sleep, cook, cauterise, loot, harbour, warp, pen, claim. The `glyph` keys in player.gd become unused.
   - Line 868: replace with `_skill_hexes[1].icon = UiIcons.icon(&"toxin" if siege else &"tackle")`.
   - Line 873: replace with `_skill_hexes[0].icon = UiIcons.icon(&"fire_ranged" if ranged else &"net")`.
   - Line 877: replace with `_skill_hexes[0].icon = UiIcons.icon(&"siege")`.
   - Lines 640-641, the level-up lines: drop `👁 ` and `◎ ` from the strings. In the `_levelup_lines` draw loop (line 994), draw `UiIcons.icon(&"xp")` or `UiIcons.icon(&"t_stone")` as a square at font height before the text. A third array slot (`[text, size, color, icon_id]`) carries the icon id.
4. `held_item_slot.gd`:
   - Line 46: replace `ItemIcons.texture(&"fists" if _fighting_shown else &"hands")` with `UiIcons.icon(&"fists" if _fighting_shown else &"hands")`. Bare hands are an action, not an item.
   - Lines 154-155: replace the `⇄` string with `draw_texture_rect(UiIcons.icon(&"swap"), Rect2(bc - Vector2.ONE * r * 0.18, Vector2.ONE * r * 0.36), false)`.
5. `creature_plates.gd:431`, status rows: pass `UiIcons.icon(StringName(str(row.get("icon_id", ""))))` as the 4th `configure` argument in place of `_icon_for(...)`. `icon_id` is already the status id, and every `statuses.json` id has an icon. At lines 94 and 273 (`knife.text = "🔪"` / `"🔒"`), set `knife.icon = UiIcons.icon(&"butcher" if unlocked else &"lock")` and clear the text.
6. `status_glyph.gd:28`: draw the icon at 0.62 of the diameter (`radius * 1.24`) instead of a fixed 12 px, so it scales with the plate.
7. Text buttons that carry emoji inside `text`. Set `b.icon = UiIcons.icon(<id>)` with `b.expand_icon = true` and `b.add_theme_constant_override("icon_max_width", 28)`, and drop the emoji from `text`:
   - `craft_ui.gd:168`: id `&"craft_hand"` when `sid == ""`, otherwise `StringName("station_" + sid)` (all ten are mapped).
   - `skills_sheet.gd:90` and `:111` (`SkillState.GLYPHS`): `UiIcons.icon(StringName(tree_id))`. All twelve trees are mapped.
   - `skills_sheet.gd:153` "◀ All skills": `&"back"`.
   - `world_ui.gd:102` terrain cards: id `row[4]` (meadow, forest, rocky, riverside, coastal).
   - `inventory_ui.gd:83` close "✕": `&"close"`.
   - `map_screen.gd:34`, zoom "−" and "+": `&"zoom_out"` and `&"zoom_in"`.
   - `station_menu.gd:76` `btn.glyph = str(row.get("glyph", "✦"))`: replace with `btn.icon = UiIcons.icon(StringName(str(row.get("id", "action"))))` (sleep, craft, cook, cauterise and the other station verbs).
8. Optional: the `"Attack Stance ◎"` label (`hunt_hud.gd:337`) can become a TextureRect with `UiIcons.icon(&"stance")` beside a plain label.

## Labs to register

- `ui_icons_lab` (`game/scenes/dev/ui_icons_lab.tscn`). Add it to `tools/labs.txt` at merge; that file does not exist on this branch. Shot commands (1600x900 or 844x390, optionally with `--rendering-method gl_compatibility`):
  ```
  Godot --path game --resolution 1600x900 -- --lab=ui_icons_lab --icons=sheet --shot=<png> --shot-delay=3.5
  ... --icons=sizes:0 .. sizes:5 | --icons=hud | --icons=filter
  ```

## ASSUMPTION markers

None in code. Design choices, none of them stated in the PRD:
- Every status effect and skill tree gets a white icon. The rule "colour = things, white = actions" is read as covering HUD state glyphs as well. Severity colour stays on the ring that status_glyph draws, not on the icon.
- The `xp` icon is an eye, because the legacy `👁` stood for pioneer XP. `t_stone` is a holed disc (a whetstone).

## What is left

- The hooks above. Until the UI package wires them, the game still shows the old glyphs. Only the lab's `hud` mode shows the result.
- Forward icons with no screen yet: chat, market/exchange, settings, save, sound and mute. They are drawn and mapped, but nothing shows them.
- The phone HUD is small at 1x (each icon about 20 px). After the hooks land, review on a device, or with `--touch` at 2532x1170, to decide whether the HUD hexes need to grow (UI package).
- `player.gd` context actions still carry `glyph` keys. They are dead text once hook 3 lands, and player.gd is protected.
- No blind A/B against the old emoji set was run. That is the reviewer's call.
