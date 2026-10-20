# W1-UIICONS: one custom white icon set for every UI action and HUD element

Branch `claude/mmo-w1-uiicons`, cut from `claude/mmo-overhaul`. Commits:

- `efd7ce2` first drawing pass: 112 white SVG icons, `data/ui_icons.json`, `UiIcons` loader
- `29ebb17` docs copied from `claude/mmo-overhaul`, reverted by `a030e90` (not package work; see review r1)
- `a69d827` optical-centring nudges, the lab (`ui_icons_lab`) and `t_uiicons`
- `db25569` first report
- `8572ab7` review r1: 28 icons redrawn plus the new `station_smoker`, three new ids, inventory read from code, silhouette and composition checks, 12/16 px and status-chip columns in the lab
- this report update

No Meshy or Tripo credits spent. Owner complaint (2026-10-19): "functionally it's fine but the symbols/icons need work".

## Review r1: findings and what changed

| # | Finding | Fix | Check that now catches it |
|---|---|---|---|
| 1 major | `wet` and `bleed_deep` had one composition (big drop left, two small right) | `wet` is rain streaks falling onto a water line (no drop shapes). `bleed_deep` is three equal drops (one drop = bleed, three = deep bleed) | `_test_composition`: the parts of each drawing (area share, centre in the ink box, aspect, fill) are compared, and 3+ parts that all pair up fail. Run on the old pair through the same code (`probe/comp.gd`): `parts 3 3 same=true`. The suggested IoU check is also in (`_test_distinct`, 24 px, cap 0.85), but alone it would not have caught this pair: the old wet/bleed_deep IoU is 0.63 at 24 px, 0.65 at 12 px and 0.65 at 6 px, because the drops sit a few units apart |
| 2 major | status icons unreadable at 9-12 px; hook 6 shrank the icon | Status glyphs redrawn solid with fewer, heavier parts: venom (heavy jaw, two fangs, one drip), pinned (bold stake through split ground), deafened (8.6-wide ear bands, slash with a cut gap), infected (spore ball), groggy (one 7.5-wide spiral band), stomachache (solid J stomach, bolt cut out), tastes_bad (solid face, eyes and mouth cut out), snare (6.6-wide noose band). Hook 6 rewritten: a 24 px chip with a 16 px icon (it was 18 px and 12 px; the old hook made it about 9.4 px) | Lab `sizes` rows now have 12 and 16 px columns, plus the chip as drawn today (18 px, 12 px icon) and as hook 6 draws it (24 px, 16 px icon). Looked at: `r1_zoom_chips_left.png`, `r1_zoom_chips_right.png` |
| 3 major | inventory was hand-typed; `sleeping` and `station_smoker` fell back | New ids: `sleeping` -> sleep.svg, `station_smoker` -> new station_smoker.svg (domed smoke hut), `station_stone_fire_pit` -> station_fire.svg | `_test_code_inventory` reads the ids from the code: every `icon_id` and `_add_status(..., &"id")` in creature_plates.gd, every `station` in recipes.json (`station_<id>`, or `craft_hand` for null), every row of craft_ui.gd `STATIONS`, every props_manifest building whose note says station, every `"id"` in `player.context_actions()` and every match arm of `player.context_action()`. 39 ids, each must have its own entry (no fallback) |
| 4 major | about 40% of the set were stock modern pictograms | Redrawn for the period: chop is a knapped flint axe head lashed to a haft, mine a long knapped stone pick lashed across a haft, dig an antler-tine hoe lashed to a haft striking the ground with clods, butcher a knapped flint blade on a sinew-wrapped grip, construction a dry-stacked stone wall, tailoring a fringed hide tunic with a laced neck, toxin a stoppered gourd with a drip, claim a horned skull on a stake driven into the ground, cargo a rope-tied hide bale moving (speed marks), save a carved stone slab with the store-down mark cut in, harbour a dugout canoe on the water with a paddle | Looked at in the lab and the contact sheets (list below). The motif text in this report now matches the drawings |
| 5 minor | thin stick figures next to solid silhouettes; feed, roll, auto, hold/hands misread | chase, kick and roll are solid-bodied figures (10-wide torso, 7-8.5-wide limbs, round head). roll is a figure mid-tumble, head down and legs over, with motion marks. feed is meat lying on an open palm-up hand. auto is three claw slashes inside a cycle arrow. hold is a stop palm with the fingers together, standing on a bar (hands stays the spread palm). pack_up (a tent in equip's focus frame) is now a tent with arrows closing in | Style rule now: figures and objects solid; the 5-unit line is kept for arrows and marks only (menu, swap, rotate, end_combat, dismount, stance, survival, net, knockdown). `_test_composition` caught pack_up sharing equip's composition |
| 6 minor | hook 3 redraw loop and duplicate `var id` | Hook 3 rewritten: the food hex compares against the resolved texture, and the context block is one full replacement with one `id` declaration | `_test_hook_ids` (below) |
| 7 minor | sync commit copied 12 docs files | Reverted in `a030e90` (no history rewrite). `git diff bd75fa0..HEAD --stat -- docs` shows only this report | |
| 8 minor | `UiIcons.icon()` caches the fallback, so a typo warns once | Kept `icon()`. `_test_hook_ids` reads this report and checks that every `&"id"` passed to `UiIcons.icon(` in the hooks resolves without the fallback | t_uiicons fails on any hook id typo |

## What shipped

- `game/assets/icons/ui/*.svg`: 113 drawings on a 64x64 grid, live area 6..58, white `#FFFFFF` only, no text in any icon.
  - First-pass icons (84 files): one line weight (`stroke-width 5`, round caps and joins) for arrows and marks, and solid shapes softened by a 1.5 edge stroke.
  - Review-r1 icons (29 files: 28 redrawn, 1 new): solid polygons only, with the same 1.5 edge stroke. Knockout gaps (the slash across the ear, the cuts beside the ropes on the bale, the paddle across the hull) are real gaps in the geometry, because masks are not allowed. Each is centred optically (mean of the ink centroid and the bounding-box centre) and scaled into the live area.
  - Motifs, as drawn: knapped flint axe, stone pick and antler hoe lashed to hafts (chop, mine, dig), knapped flint knife on a wrapped grip (butcher), bone club (attack), dry-stone wall (construction), fringed hide tunic (tailoring), horned skull on a stake (claim), rope-tied hide bale (cargo), carved stone slab (save), dugout canoe (harbour), stoppered gourd (toxin), hide tent (build, pack_up, warp_home), lashed fence (pen), knotted net (net), rope noose (snare), raptor head (animals, sic, dismiss), drying rack (station_dryer), domed smoke hut (station_smoker), crock pot, mortar and stone grill.
  - Import: `svg/scale=2.0` (128 px texture) with mipmaps, so icons stay crisp from 12 to 64 px and when the HUD scales.
- `game/data/ui_icons.json`: 168 action ids map to the 113 files (aliases such as `capture` -> net.svg). It also has `glyphs`, a table of 54 legacy emoji and symbol characters with the action id that replaces each, `typographic` (symbols that stay text: `× · • … — – → ○ ≥`), and `fallback: "action"`.
- `game/scripts/ui/ui_icons.gd`: `UiIcons.icon(id) -> Texture2D` returns the cached texture. An unknown id returns the `action` sparkle with a warning, and `""` returns null. `UiIcons.path_for(id)` returns the file path, and `UiIcons.for_glyph("🏃")` maps a legacy glyph. Spec deviation: the brief asked for `UiIcons.get(id)`, but a static `get()` shadows `Object.get` and does not compile, so the method is `icon()`.
- `game/scripts/dev/ui_icons_lab.gd` and `game/scenes/dev/ui_icons_lab.tscn`. Modes, chosen with `--icons=`:
  - `sheet`: every icon in a real 64 px `HexButton` over the lab world, with its id.
  - `sizes:<page>`, pages 0 to 5: each icon at 12, 16, 24, 32, 48 and 64 px on the dark `UiTokens.INK` panel; at 24, 32 and 48 px in ink on a light panel; as a creature-plate status chip today (18 px chip, 12 px icon) and per hook 6 (24 px chip, 16 px icon); and in a 72 px hex.
  - `hud`: the real HuntHud with its legacy glyphs swapped for icons at runtime, a preview of the hooks.
  - `filter`: linear filtering compared with linear plus mipmaps at 24 and 32 px.

  Headless without `--shot`, the lab loads every icon through `UiIcons` and checks it is 128 px with mipmaps.
- `game/tests/t_uiicons.gd` checks:
  - Every id resolves to an existing SVG, and every SVG is used by some id.
  - Every SVG is on the 64 grid and has no style, opacity, gradient, image, text or `currentColor`. Every fill and stroke is white, and every stroke-width is a house weight (5 or 1.5).
  - Each SVG rasterised by the engine has no off-white pixel, stays inside 2..61, and its optical centre is within 3 grid units of 32,32.
  - The hand-kept inventory, every `statuses.json` status, every skill tree in `trees.json`, and the 39 ids read from code (`_test_code_inventory`, above) have their own icons.
  - Every `&"id"` passed to `UiIcons.icon(` in this report's hooks resolves (`_test_hook_ids`).
  - No two files share a silhouette: soft IoU of alpha masks at 24 px is at most 0.85 (`_test_distinct`). Three opposite-action pairs that differ by one conventional mark are capped at 0.95 instead: lock/unlock (0.88 at 24 px), store/take_all (0.88), zoom_in/zoom_out (0.93). They sit side by side or swap in one slot, so the mark is the message.
  - No two files share a composition of 3+ parts (`_test_composition`, above).
  - Every non-ASCII symbol in a string literal of `scripts/ui/*.gd`, `scripts/world/*.gd`, `player.gd` and `skill_state.gd` is mapped to an icon or listed as typographic.
  - The loader falls back safely, `for_glyph` works, and textures import at 2x with mipmaps.

## Acceptance (run on the commit that adds this report; every line copied from the run's output)

| Check | Command | Result |
|---|---|---|
| t_uiicons | `gslot.sh Godot --headless --path game --script res://tests/t_uiicons.gd` | `[t_uiicons] PASS ids=168 files=113 glyphs=54 code_ids=39 worst_iou=0.80 notice/save` (exit 0) |
| run_all | `gslot.sh Godot --headless --path game --script res://tests/run_all.gd` | `[tests] PASS` (exit 0) |
| smoke | `gslot.sh tools/smoke.sh --no-import` | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` / `SMOKE PASS` (exit 0) |
| lab headless | `gslot.sh Godot --headless --path game -- --lab=ui_icons_lab` | `[uiicons_lab] icons=113 bad=[] fallback=true` (exit 0) |
| at least 48 icons | t_uiicons | 113 files, 168 ids |

The warning `[ui_icons] no icon for 'no_such_action_xyz', using fallback` is expected; it comes from the fallback test. In the t_uiicons line, `worst_iou` is the most similar pair outside the three capped pairs.

## Screenshots looked at

All screenshots are in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1x/uiicons/`. They are windowed runs taken after the import that followed the r1 redraw. Each one listed was opened with Read.

- `r1_fwd_sheet_1600.png` (Forward+) and its zoom `r1_zoom_sheet_row1.png`; `r1_zoom_gl_row7.png` (a zoom of `r1_gl_sheet_1600.png`, gl_compatibility): all 113 icons on real 64 px hexes. One family: solid silhouettes, the same edge softening, no colour, centred in the hex. The renderers match.
- `r1_gl_sheet_phone.png` (844x390 landscape, gl_compatibility): every hex still reads as a shape.
- `r1_fwd_sizes_p0.png`, `r1_fwd_sizes_p1.png`, `r1_fwd_sizes_p2.png`, `r1_fwd_sizes_p3.png`, `r1_fwd_sizes_p4.png`, `r1_fwd_sizes_p5.png` and `r1_gl_sizes_p4.png`: every icon from 12 to 64 px on dark and light panels, the two status chips and the 72 px hex. No blurry edges and no off-centre glyphs. At 12 px the status set separates by silhouette: one drop (bleed), three drops (bleed_deep), streaks over a wave (wet), jaw (venom), bone (fracture), stake (pinned), slashed ear (deafened), spore (infected), spiral (groggy), chevrons (knockdown), noose (snare), face with brows (enraged), bowl (full), J stomach (stomachache), round face (tastes_bad), moon (sleep).
- `r1_zoom_chips_left.png`, `r1_zoom_chips_right.png`: the status chip today (18 px, 12 px icon) beside the hook 6 chip (24 px, 16 px icon). The 24 px chip is clearly more legible; this is the case for hook 6.
- `r1_gl_hud_phone.png` with the zooms `r1_zoom_gl_hud_phone_r.png` and `r1_zoom_fwd_hud_phone_l.png`: the real HUD at 844x390 with the hooks previewed. The combat cluster (feed, net, kick, tackle, roll, auto) and the rail (menu, animals, build, skills) plus chase. The solid kick, roll and chase figures now carry the same weight as tackle and net. At 1x phone scale the auto claws inside the ring are small (about 14 px icon); a 2x or 3x device renders them sharper.

Taken but not opened this round: `r1_gl_sheet_1600.png` as a whole (only its zoom), `r1_fwd_sheet_phone.png`, `r1_gl_sizes_p0..p3,p5.png`, `r1_fwd_hud_1600.png`, `r1_fwd_hud_phone.png` as a whole (only its zoom), `r1_zoom_small_right.png`.

## Glyph and icon inventory

Sources were grepped for emoji and symbol code points (U+2010 and above, string literals only) and for icon paths: `game/scripts/ui/*.gd`, `game/scripts/world/*.gd`, `player.gd` (context actions) and `skill_state.gd` (skill-tree glyphs). Since r1, t_uiicons also reads the emitted ids from creature_plates.gd, recipes.json, craft_ui.gd `STATIONS`, props_manifest station buildings and player.gd. Item icons (`res://assets/icons/%s.png` in craft_card, pickup_toast, station_menu and station_radial, plus ItemIcons and game-icons) are things, so they keep colour and are out of scope.

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
| sleep | sleep, sleeping | player.gd:2223 `☾`; station_menu.gd:20 `☾`; station_menu.gd:21 `☾`; station_menu.gd:22 `☾`; creature_plates.gd:454 sleeping row (`icon_id "sleeping"`, glyph "Z") |
| snare | rope_snare, heavy_snare, snare, snared | player.gd:2213 context rope_snare/heavy_snare (glyph "S"); statuses.json snared |
| sound | sound | forward: settings sound toggle |
| stance | stance | hunt_hud.gd:337 `◎`; hunt_hud.gd:641 `◎` |
| station_dryer | station_dryer, station_drying_rack | craft_ui.gd:12 `🪢` |
| station_fire | station_fire, station_bonfire, station_campfire, station_stone_fire_pit | craft_ui.gd:11 bonfire/campfire (🔥 collides with cauterise); props_manifest stone_fire_pit (station building) |
| station_grill | station_grill, station_stone_grill | craft_ui.gd:12 stone_grill (🍖 collides with eat) |
| station_mortar | station_mortar | craft_ui.gd:12 `🥣` |
| station_pot | station_pot, station_crock_pot, cooking | craft_ui.gd:12 `🍲`; skill_state.gd:12 `🍲` |
| station_smoker | station_smoker | recipes.json station "smoker"; build_placer.gd:497 `CraftStation.make(&"smoker")`; props_manifest smoker (no craft tab yet) |
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

## Integrator hooks (UI package: hex_button.gd, hunt_hud.gd, status_glyph.gd and the other ui/*.gd)

This package does not edit any UI script. Each change below is exact. t_uiicons checks that every `&"id"` named here resolves without the fallback. After these hooks, `UiIcons` is the only source of action art, and the `glyph` strings become dead text.

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
   - Lines 242-247, the quick-food hexes. Replace the whole block from `var tex := ItemIcons.texture(StringName(fid))` to `h.bottom_text = "×%d" % n` (line 248 `h.queue_redraw()` stays inside the `if`) with:
     ```gdscript
     			var tex := ItemIcons.texture(StringName(fid))
     			var want: Texture2D = tex if tex else UiIcons.icon(&"eat")
     			if h.icon != want or h.bottom_text != str(n):
     				h.icon = want
     				h.color_icon = tex != null
     				h.glyph = ""
     				h.bottom_text = "×%d" % n
     ```
     Comparing against `want` (not `tex`) stops the per-frame reassign and redraw when the food has no item icon.
   - Line 299, combat specs: replace `h.glyph = s[0]` with `h.icon = UiIcons.icon(StringName(s[1]))` (net, tackle, kick, roll).
   - Line 306: replace `_auto_hex.glyph = "Auto"` with `_auto_hex.icon = UiIcons.icon(&"auto")`.
   - Line 317, whistles: replace `wh.glyph = spec[1]` with `wh.icon = UiIcons.icon(&"sic" if spec[0] == "attack" else StringName(spec[0]))` (sic, heel, guard).
   - Line 328: replace `_feed_hex.glyph = "FEED"` with `_feed_hex.icon = UiIcons.icon(&"feed")`.
   - Line 344: replace `_chase_hex.glyph = "🏃"` with `_chase_hex.icon = UiIcons.icon(&"chase")`. Line 351: replace it with `_chase_hex.icon = UiIcons.icon(&"hold" if player.hunt.hold else &"chase")`.
   - Line 481: replace `_done_hex.glyph = "✓"` with `_done_hex.icon = UiIcons.icon(&"confirm")`.
   - Line 494, placement: replace `h.glyph = sp[0]` with `h.icon = UiIcons.icon(StringName(sp[1]))` (rotate, confirm, cancel).
   - Lines 586-593, context actions. Replace these eight lines, from `var h := HexButton.new(70.0)` through `var id := str(a["id"])`, as one block with:
     ```gdscript
     		var h := HexButton.new(70.0)
     		var id := str(a["id"])
     		h.icon = UiIcons.icon(StringName(id))
     		h.caption = str(a["label"]).to_upper()
     		h.bottom_text = str(a.get("uses", ""))
     ```
     There is one `id` declaration; line 594 (`h.pressed.connect(...)`) and everything after it stay as they are. Every id that `player.context_actions()` emits has an icon, and t_uiicons reads them from player.gd: dismount, catapult_stone, catapult_toxin, fire_ranged, coat_weapon, rope_snare, heavy_snare, drink, wash, sleep, cook, cauterise, loot, harbour, warp, pen, claim. The `glyph` keys in player.gd become unused.
   - Line 868: replace with `_skill_hexes[1].icon = UiIcons.icon(&"toxin" if siege else &"tackle")`.
   - Line 873: replace with `_skill_hexes[0].icon = UiIcons.icon(&"fire_ranged" if ranged else &"net")`.
   - Line 877: replace with `_skill_hexes[0].icon = UiIcons.icon(&"siege")`.
   - Lines 640-641, the level-up lines: drop `👁 ` and `◎ ` from the strings. In the `_levelup_lines` draw loop (line 994), draw `UiIcons.icon(&"xp")` or `UiIcons.icon(&"t_stone")` as a square at font height before the text. A third array slot (`[text, size, color, icon_id]`) carries the icon id.
4. `held_item_slot.gd`:
   - Line 46: replace `ItemIcons.texture(&"fists" if _fighting_shown else &"hands")` with `UiIcons.icon(&"fists" if _fighting_shown else &"hands")`. Bare hands are an action, not an item.
   - Lines 154-155: replace the `⇄` string with `draw_texture_rect(UiIcons.icon(&"swap"), Rect2(bc - Vector2.ONE * r * 0.18, Vector2.ONE * r * 0.36), false)`.
5. `creature_plates.gd:435`, status rows: pass `UiIcons.icon(StringName(str(row.get("icon_id", ""))))` as the 4th `configure` argument in place of `_icon_for(...)`. Every `icon_id` the plates emit (each `statuses.json` id and `sleeping`) has its own icon; t_uiicons reads them from creature_plates.gd. At lines 94 and 273 (`knife.text = "🔪"` / `"🔒"`), set `knife.icon = UiIcons.icon(&"butcher" if unlocked else &"lock")` and clear the text.
6. `status_glyph.gd`: make the chip 24 px and the icon 16 px (today 18 px and a fixed 12 px; the status icons are drawn for 12-16 px). In `_ready`, replace `custom_minimum_size = Vector2(18, 18)` with
   ```gdscript
   	custom_minimum_size = Vector2(24, 24)
   	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
   ```
   In `_draw` (line 28), replace `draw_texture_rect(icon, Rect2(c - Vector2(6, 6), Vector2(12, 12)), false)` with
   ```gdscript
   		var s := radius * 1.6  # 16 px on the 24 px chip
   		draw_texture_rect(icon, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
   ```
   The lab's `sizes` view draws both chips side by side (`_draw_chip`).
7. Text buttons that carry emoji inside `text`. Set `b.icon = UiIcons.icon(<id>)` with `b.expand_icon = true` and `b.add_theme_constant_override("icon_max_width", 28)`, and drop the emoji from `text`:
   - `craft_ui.gd:168`: id `&"craft_hand"` when `sid == ""`, otherwise `StringName("station_" + sid)`. Every station in recipes.json, the craft tabs and the station buildings is mapped, including `station_smoker` (recipes.json uses it; the tab list does not show it yet) and `station_stone_fire_pit`.
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
- Deep bleed is drawn as three drops (more drops, worse bleeding); wet is rain onto water.
- claim is a horned skull on a stake (a territory marker), not a flag.

## What is left

- The hooks above. Until the UI package wires them, the game still shows the old glyphs. Only the lab's `hud` mode shows the result.
- Hook 6 grows the status chip from 18 to 24 px; the creature plate's third line must have room for it (UI package).
- Forward icons with no screen yet: chat, market/exchange, settings, save, sound and mute. They are drawn and mapped, but nothing shows them.
- The phone HUD at 1x draws icons at about 20 px (combat hexes about 14-20 px). After the hooks land, review on a device, or with `--touch` at 2532x1170, to decide whether the HUD hexes need to grow (UI package).
- `player.gd` context actions still carry `glyph` keys. They are dead text once hook 3 lands, and player.gd is protected.
- Lines remain for arrows and marks (menu, swap, rotate, end_combat, dismount, stance, survival, net, knockdown); figures and objects are solid.
- No blind A/B against the old emoji set was run. That is the reviewer's call.
- The drawing sources (python geometry in the scratchpad: `uiicons_tools/icons_*.py`, `geo.py`, `geo2.py`, `write.py`) are not in the repo; the SVGs are the source of truth.
