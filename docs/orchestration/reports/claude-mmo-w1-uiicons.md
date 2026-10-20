# W1-UIICONS: one custom white icon set for every UI action and HUD element

Branch `claude/mmo-w1-uiicons`, cut from `claude/mmo-overhaul` and synced with it by merge (latest `2262a6e`, no conflicts; the branch only adds files the package owns). Package commits:

- `efd7ce2` first drawing pass: 112 white SVG icons, `data/ui_icons.json`, the `UiIcons` loader
- `a69d827` the lab (`ui_icons_lab`) and `t_uiicons`; `db25569` first report
- `29ebb17` docs copied from the base by hand, reverted in `a030e90`
- `8572ab7`, `d0834a3` review r1: 28 icons redrawn, inventory read from code, silhouette and composition checks
- `466215b` review r2: the drawing sources committed under `game/assets/icons/ui/_src/`
- `713dca8` review r2: misreads redrawn, period material, even optical weight, hook ids as a const list, lab hides the player and the hands slot, hooks as a checked patch
- `740840b`, `8e1b995`, `df736a0`, `df9c2b9` review r2, finished: butcher and stone grill (blind-read misses), material for the remaining stock pictograms, parcel cargo, byte-identical regeneration in t_uiicons

No Meshy or Tripo credits spent. Owner (2026-10-19): "the symbols/icons need work".

## Review r2: findings and what changed

The hook findings (1, 3, 5) are fixed in the hooks patch, which the integrator applies after W1-UI merges. Everything else is fixed in this branch.

| # | Finding | Fix | Check |
|---|---|---|---|
| 1 major | Hook 5 did not compile (`knife` is a Label; `unlocked` out of scope) | The patch swaps the Label for a fixed 16x16 TextureRect (`EXPAND_IGNORE_SIZE`, `STRETCH_KEEP_ASPECT_CENTERED`, mipmaps), sets `texture` inside the `unlocked` scope at :94 and `UiIcons.icon(&"butcher")` at :273 | `git apply --check docs/orchestration/reports/claude-mmo-w1-uiicons-hooks.patch` exits 0 on the merged tree |
| 2 major | roll, feed, deafened, harbour, cargo, heel unreadable without labels | roll: a tucked body with the head clear of it, under a curved arrow, on the ground. feed: the raptor head of the pet family taking a drumstick. deafened: an ear (helix into the lobe, inner curl) struck through. harbour: a paddler in one unbroken canoe hull on a water line. cargo: the package convention, a rope-tied hide bale seen from above the corner, with speed marks. heel: the survivor standing with the raptor at their side | Blind read: lab `--icons=blind` shuffles every icon onto a 50 px hex at 24 px with a number and no id (key printed separately). All eight read as intended (list under Screenshots). Two other icons missed in an earlier blind read and were redrawn: butcher (a leaf blade read as a club; now a single-edged flint knife) and station_grill (bars over flames read as the drying rack; now meat on a hot stone slab over fire between two stones) |
| 3 major | Hook 3 left the auto hex with no label | The patch adds `_auto_hex.caption = "AUTO"`; the lab's hud mode shows it | `hud_gl_phone_r.png` |
| 4 major | 60 SVGs were machine dumps whose generators lived only in the scratchpad | Sources committed in `game/assets/icons/ui/_src/` (with `.gdignore`): `build.py`, the path helpers `geo.py` and `geo2.py`, `offsets.py`, and one module per drawing pass `icons_a.py` .. `icons_i.py`, each id drawn in exactly one module. Every SVG carries a header naming its id | t_uiicons runs `python3 _src/build.py --check`: `regen='[icons] PASS drawn=113 svgs=113'`. Adding one space to roll.svg made it fail: `[t_uiicons] FAIL _src/build.py --check regenerates every SVG byte for byte (exit 1): [icons] DIFFERS roll.svg` |
| 5 minor | Quick-food hook still redrew every frame | The patch compares `h.bottom_text != "×%d" % n` | `git apply --check` |
| 6 minor | A third of the set were stock modern pictograms | Conventions kept, material added. `713dca8`: crossed bones (close), carved stele (save), gash with spores (infected), figure driving into an impact burst (tackle). `8e1b995` (new module `icons_i.py`): knapped-flint gear with scalloped flake scars and an uneven bored hole (settings), rough-hewn stone padlock with a bone shackle whose knobbed end shows when open (lock, unlock), hide speech bubble with leg lobes (chat), blown animal horn with sound waves, or with an X (sound, mute), magnifier on a knobbed bone handle (zoom_in, zoom_out), balance on a post set in a stone, beam lashed on, rope cords and gourd pans (market), star knapped from flint with scalloped edges (skills), tapping hand with a wrapped wrist (use). confirm keeps the plain check | `stock.png` (before) against `mat1.png`, `mat2.png`, `star2.png` (after) |
| 7 minor | Uneven optical weight; no check | Heavier menu, back, swap, rotate, fire_ranged, end_combat, dismount, gathering and the tool hafts; lighter pen, chest, chat, notice, t_stone, processing, tunic, wall, face, pot | `_test_weight`: mean alpha at 24 px of every icon within 0.6..1.5 x the set median. This run: `weight=0.61..1.47` |
| 8 minor | Test read the report; t_uiicons not registered | `HOOK_IDS` is a const list in the test (45 ids) and `BADGES` checks the two badge glyph mappings. The patch adds t_uiicons to `tools/test.sh` | `hook_ids=45` in the PASS line |
| 9 minor | HeldItemSlot and the player drew over the sheet and size pages | Hidden outside `hud` mode (`ui_icons_lab.gd` `_ready`) | `sheet_fwd.png`: no player, no hands slot |
| 10 minor | cauterise read as a drop beside bleed; wet repeated auto's slashes | cauterise: a flame over a stitched cut. wet: vertical rain onto water | Blind read, below |

Also: the test now loads `UiIcons` by path (`load("res://scripts/ui/ui_icons.gd")`) instead of by class_name, as the test rules require.

## What shipped

- `game/assets/icons/ui/*.svg`: 113 drawings on a 64x64 grid, live area 6..58, white `#FFFFFF` only, no text. Lines (stroke 5, round caps and joins) only for arrows and marks; figures and objects are solid, softened by a 1.5 edge stroke. Knockouts (the slash across the ear, the string across the bale, the keyhole) are real gaps in the geometry; masks are not allowed. Imported at `svg/scale=2.0` (128 px) with mipmaps.
- `game/assets/icons/ui/_src/` (ignored by Godot): the drawing sources. To change an icon, edit its module and regenerate:
  ```
  python3 game/assets/icons/ui/_src/build.py           # redraw every SVG
  python3 game/assets/icons/ui/_src/build.py --check   # write nothing; exit 1 if any SVG differs
  ```
  Then run one `--import`. `icons_a`..`icons_f` are the first pass (line and solid elements written as SVG path syntax, nudged by `offsets.py`); `icons_g`, `icons_h` and `icons_i` are solid polygons placed by hand and centred optically by `geo2.place`.
- `game/data/ui_icons.json`: 168 action ids map to the 113 files (aliases such as `capture` -> net.svg), a `glyphs` table of 54 legacy emoji and symbols with the id that replaces each, `typographic` (`× · • … — – → ○ ≥` stay text), and `fallback: "action"`.
- `game/scripts/ui/ui_icons.gd`: `UiIcons.icon(id) -> Texture2D` (cached; unknown id -> the `action` sparkle with a warning; `""` -> null), `UiIcons.path_for(id)`, `UiIcons.for_glyph(glyph)`. The brief named it `get()`; a static `get()` shadows `Object.get` and does not compile.
- `game/scripts/dev/ui_icons_lab.gd`, `game/scenes/dev/ui_icons_lab.tscn`, modes via `--icons=`: `sheet` (every icon in a 64 px HexButton with its id), `blind` (shuffled, numbered, no ids, 24 px), `sizes:0`..`sizes:5` (12 to 64 px on dark and light panels, the status chip today and per hook 6, a 72 px hex), `hud` (the real HuntHud with the hooks previewed at runtime), `filter` (linear vs mipmaps). Headless without `--shot` it loads every icon and checks size and mipmaps.
- `game/tests/t_uiicons.gd`: ids resolve and every SVG is used; white only, house stroke weights, inside the canvas, optically centred; inventory, statuses, skill trees and 39 ids read from code have icons; hook ids and badge glyphs resolve; ink weight band; byte-identical regeneration from `_src`; no shared silhouette (IoU <= 0.85 at 24 px, three opposite-action pairs <= 0.95); no shared composition of 3+ parts; every non-ASCII symbol in HUD string literals is mapped or typographic; loader fallback and 2x mipmapped import.

## Acceptance (run on `df9c2b9` plus this report; every line copied from the output)

| Check | Command | Result |
|---|---|---|
| t_uiicons | `gslot.sh Godot --headless --path game --script res://tests/t_uiicons.gd` | `[t_uiicons] PASS ids=168 files=113 glyphs=54 code_ids=39 hook_ids=45 weight=0.61..1.47 worst_iou=0.80 loot/store regen='[icons] PASS drawn=113 svgs=113'` (exit 0) |
| run_all | `gslot.sh Godot --headless --path game --script res://tests/run_all.gd` | `[tests] PASS` (exit 0) |
| smoke | `gslot.sh tools/smoke.sh --no-import` | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` / `SMOKE PASS` (exit 0) |
| lab headless | `gslot.sh Godot --headless --path game -- --lab=ui_icons_lab` | `[uiicons_lab] icons=113 bad=[] fallback=true` (exit 0) |
| sources | `python3 game/assets/icons/ui/_src/build.py --check` | `[icons] PASS drawn=113 svgs=113` |
| hooks patch | `git apply --check docs/orchestration/reports/claude-mmo-w1-uiicons-hooks.patch` | exit 0 |

The warning `[ui_icons] no icon for 'no_such_action_xyz', using fallback` comes from the fallback test. `worst_iou` is the most similar pair outside the three capped pairs.

## Screenshots looked at

In `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1x/uiicons/r3/`, each opened with Read after the import that followed the last redraw (the ladders are rendered by the engine's SVG rasteriser at 128 px and downsampled, as mipmaps do).

- `redraw.png`: the eight review icons plus butcher and station_grill at 12, 16, 20, 24 and 48 px. `weak.png`: the eight at 24 and 64 px.
- `stock.png` (before) and `mat1.png`, `mat2.png`, `star2.png`, `star2_ladder.png` (after): the stock pictograms. The first stone padlock used scalloped edges and read as a postage stamp, and rope lashing on the magnifier handle read as key teeth; both were dropped (`mat2.png`). A faceted star (`star.png`, cuts to the centre) read as a hollow grey star on the phone rail; the kept star is solid with knapped edges.
- `c1.png`, `c2.png`: rejected candidates. A crouched figure for roll read as a chess knight; a knotted bundle for cargo read as a rabbit. The parcel and the ball-with-head were kept.
- `blind_gl.png` (gl_compatibility, 1600x900) and zooms `blind_a.png` .. `blind_d.png`: the blind read. With the key, the eight review icons are 41 roll (ball and head under an arrow on the ground), 79 feed (raptor jaws on a drumstick), 76 deafened (ear struck through), 46 harbour (paddler in a canoe), 36 cargo (parcel with speed marks), 38 heel (person with the raptor beside them), 68 cauterise (flame over a cut, unlike the 85 bleed drop), 31 wet (rain onto water, unlike the 57 auto slashes). The material icons still read by convention at 24 px (3 gear, 7/107 padlock, 23 bubble, 63/71 horn, 16/88 magnifier, 73 balance, 17 star, 70 tapping hand); the material shows from about 48 px up.
- `sheet_fwd.png` (Forward+): all 113 on 64 px hexes with ids, with no player and no hands slot over them.
- `hud_gl_phone.png` (844x390 landscape, gl_compatibility) and zooms `hud_gl_phone_r.png`, `hud_gl_phone_l.png`: the combat cluster (feed, net, tackle, kick, roll, auto with its AUTO caption) and the rail (menu, animals, build, skills, chase). The faceted skills star read light here. `hud_gl_phone2_l.png` (fuller faceted star, still grey) and `hud_gl_phone3_l.png` (final solid knapped star): the star now carries the same weight as menu, animals and build.

Taken but not opened: `sheet_gl.png`, and `hud_gl_phone2.png` / `hud_gl_phone3.png` as wholes (only their rail zooms). The blind sheet and the full sheet were taken before the final star change.

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

## Integrator hooks

This package edits no UI script. The hooks are one patch, `docs/orchestration/reports/claude-mmo-w1-uiicons-hooks.patch`; `git apply --check` passes on this branch after the base merge. W1-UI owns the HUD and bag scripts, so the wiring waits until W1-UI merges; the patch will need a refresh against W1-UI's edits then. Every id it passes to `UiIcons.icon()` is in `HOOK_IDS` in t_uiicons, which checks they resolve without the fallback.

What the patch does, by file:

1. `hex_button.gd`: mipmapped filtering in `_init`; skip `_white_symbol` for icons under `UiIcons.DIR` (they are already white).
2. `hex_button.gd` badges: the badge circle draws `UiIcons.for_glyph(badge)` (`⊘` -> blocked, `✓` -> confirm; t_uiicons `BADGES` checks both mappings) and falls back to the text for any other badge.
3. `hunt_hud.gd`: `_hex()` takes an id; menu, animals, build, skills, inspect, eat, quick food (compares `h.bottom_text != "×%d" % n`, so no per-frame redraw), combat specs (net, tackle, kick, roll), auto (icon plus `_auto_hex.caption = "AUTO"`), whistles (sic, heel, guard), feed, chase/hold, done, placement (rotate, confirm, cancel), context actions by id (one `id` declaration), skill hexes (toxin, tackle, fire_ranged, net, siege), level-up lines draw the xp and t_stone icons.
4. `held_item_slot.gd`: fists and hands from `UiIcons`; the swap mark is the swap icon.
5. `creature_plates.gd`: status rows take `UiIcons.icon(icon_id)`; the knife lock is a fixed 16x16 TextureRect (`EXPAND_IGNORE_SIZE`, `STRETCH_KEEP_ASPECT_CENTERED`, mipmaps) set to butcher or lock inside the `unlocked` scope.
6. `status_glyph.gd`: 24 px chip with a 16 px icon (today 18 and 12).
7. `craft_ui.gd`, `skills_sheet.gd`, `world_ui.gd`, `inventory_ui.gd`, `map_screen.gd`, `station_menu.gd`: Button icons by id instead of emoji in the text.
8. `tools/test.sh`: runs `res://tests/t_uiicons.gd` after `run_all.gd`. (`run_all.gd` is one file of inline checks, not a list, so the gate is the script.)

## Labs to register

- `ui_icons_lab` (`game/scenes/dev/ui_icons_lab.tscn`). `tools/labs.txt` does not exist on this branch; add it wherever labs are listed at merge. Shots (1600x900 or 844x390; add `--rendering-method gl_compatibility` for the web renderer):
  ```
  Godot --path game --resolution 1600x900 -- --lab=ui_icons_lab --icons=sheet --shot=<png> --shot-delay=3.5
  ... --icons=blind | --icons=sizes:0 .. sizes:5 | --icons=hud | --icons=filter
  ```

## ASSUMPTION markers

None in code. Design choices the PRD does not state:
- Every status effect and skill tree gets a white icon: "colour = things, white = actions" is read as covering HUD state glyphs. Severity colour stays on the ring that status_glyph draws.
- `xp` is an eye (the legacy `👁` stood for pioneer XP); `t_stone` is a holed disc (a whetstone).
- Deep bleed is three drops; wet is rain onto water; claim is a horned skull on a stake.
- Material for conventional pictograms: stone, bone, hide, rope and gourd, as listed in finding 6. confirm stays a plain check.
- t_uiicons needs `python3` on PATH for the regeneration check (dev machines; exports never run tests). Without it the check fails with its exit code rather than skipping.

## What is left

- The wiring (the patch above), after W1-UI merges. Until then the game shows the old glyphs; only the lab's `hud` mode shows the icons.
- Hook 6 grows the status chip from 18 to 24 px; the creature plate's third line needs room for it (W1-UI).
- Forward icons with no screen yet: chat, market, settings, save, sound, mute. Drawn and mapped, not shown anywhere.
- At 844x390 1x the combat hexes draw icons at about 14-20 px. Review on a device (or `--touch` at 2532x1170) after wiring to decide whether the HUD hexes grow (W1-UI).
- `player.gd` context actions keep their `glyph` keys; they are dead text after hook 3, and player.gd is protected.
- The material on the conventional pictograms shows from about 48 px; at 24 px they read by convention only. That is intended (the convention is what a player taps on).
- The file:line references in the inventory table were taken on the r1 tree; the test reads the ids from the code, so it does not depend on them.
