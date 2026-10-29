# claude-craftradial: station radial, right-side craft panel, Construction panel, tag recipes

Branch `claude/mmo-craftradial` (from `origin/claude/mmo-overhaul`). Rules written into
`docs/design/ui-redesign-spec.md` §7a (D4 station radial, D5 right-side pop-out). Open question A6 in
`docs/vision/WildLandsMMO_Open_Questions.md` marked answered (recipes accept by material tag).

## What shipped

**Station radial (D4)**, `game/scripts/ui/station_menu.gd` (dispatch in `game/scripts/items/station_craft.gd`)
- Every placed building opens one radial: a dark ring with its wedges as flat-top hexes (64 px or more), the
  main action on top with a GOLD rim, then PACKAGE and REMOVE (red). The station name sits in the ring's centre.
  The HUD's world chip for that station is hidden while the ring is open (`hud_pills.gd`).
- Main wedge by kind (`StationMenu.ACTIONS`): workbench CRAFT; bonfire and campfire COOK; stone grill (the
  "oven"), crock pot, steamer and smoker COOK; drying rack DRY; taming pen PEN (opens the Taming Pen screen);
  basket OPEN (storage); beds SLEEP. Fires keep LOAD WOOD and CAUTERISE. COLLECT and TAKE BACK still come first.
  The fire-fuel UI from claude/mmo-firefuel is not touched: LOAD WOOD is unchanged.
- PACKAGE calls the existing `BuildPlacer.pack_up_node`: the kit and the station's contents go back to the bag,
  all or nothing. REMOVE turns into CONFIRM on the first tap and demolishes on the second
  (`StationCraft.remove_station`).
- A card at the top left shows the icon, "Name Lv n", durability (when the station has health), the type, and
  the station's own state line (fuel). `info_label` still holds that line, so t_firepits reads it unchanged.
- Under the ring, a horizontally scrolling row with one slot per distinct recipe output of the station
  (`StationMenu.outputs_for`). Each slot shows the icon and quality dots (rarity tier). A tap opens that recipe's
  detail in the craft panel (`CraftUI.show_recipe`).
- The pen and basket used to open their screens directly on tap. They now open the radial first
  (`player_input.gd`, `PlayerActions.building_interact`, with the new `PlayerActions.open_basket`).

**Fixed-slot radial (Milan: "like kingdom rush", the bonfire ring was glitching)**
- The cause: every frame the old menu re-solved its ring with `ContextRadial.hex_positions`. That function
  turns the ring in 24 steps and checks HUD overlap, so a sub-pixel camera or anchor change could flip the
  ring to a different turn, and the hexes jumped.
- `StationMenu` no longer calls it. There are six fixed screen slots (`SLOT_ANGLES`), each action always gets
  the same one (`SLOT_OF`, main action on top), and the radius is fixed.
- The whole cluster slides inside the safe area as one; on a phone it also stays above the output row.
- The anchor follows the camera with smoothing and holds still once the camera stops: it does not re-solve for
  moves under 0.75 px.
- On open the hexes fly out from the station: 0.15 s ease-out, 0.03 s stagger.
- Tested: the slots are identical across two opens and a rotated camera, and drift is 0 px over 12 still
  frames.
- **Not done: the same layout for the gather / loot / pet radials** (`gather_radial.gd`, `pet_radial.gd`). They
  already hold their solved layout through `RadialHold`, and t_ui / t_controls / t_lootradial assert their
  turn-away-from-HUD behaviour. Switching them is a separate package.
- No collapse animation on close: closing stays immediate, which the tests rely on.

**Right-side pop-out (D5)**, new component **`RightSheet`** (`game/scripts/ui/right_sheet.gd`)
- A full-height panel on the right edge that holds the shared SheetChrome header. It is about 42 % of a desktop
  (560 to 760 px) and at least 440 px on a phone. Wide sub-views use `share = 0.86`.
- **The bagui agent's Bag panel should use this same component when the branches merge.**
- **CraftUI** (`craft_ui.gd`) now sits inside a RightSheet with the world visible beside it. It has Search, a
  2-row grid of category tabs (All, Material Processing, Cooking, Tool, Clothing, Building Components, Weapon,
  Farming) and recipes under thin section headers in two columns, with the footer "Select a pattern.". It shows
  one page at a time: tapping a recipe opens its detail (existing detail and Craft / Craft ×5), and ‹ goes back.
- From the menu the list holds every recipe, each judged against its own station. From a station it holds only
  that station's recipes. The station chooser row is gone, but the `STATIONS` table stays: tests and icon
  checks read it.
- The Build button in the header switches the panel to a Build page: kits in the bag and blueprints. A tap uses
  the existing BuildUI entry points (`pick_kit` for the ghost with ROTATE / SAVE / CANCEL, `tap_blueprint` for
  the site).
- **Craft and Construction share one slot panel**, `CraftPlace` (`craft_place.gd`):
  - Shared parts: Crafting complete %, chevron slot groups, the candidate grid with numbered pick badges,
    Expected Result and Success Rate.
  - Craft adds the existing quantity stepper and the failure note.
  - **Construction** (`CraftUI.open_site` → `CraftPlace.open_site`) runs on blueprint slots:
    - It accepts items by tag through `Blueprints.fits`, including the level gate.
    - Items already placed show a GOLD check.
    - The action goes Fill Automatically (best level first) → Place Material, which deposits the exact
      instances through `ConstructionSite.deposit` → the build timer runs → Finish (`BuildFlow.complete`).
    - It shows the Construction level the blueprint needs and the timer as HH:MM:SS.
  - A site tap now opens this panel (`BuildUI.show_site` hands off to it). The old site drawer code is kept
    only as a fallback for labs that have no craft menu.
- The construction timer: a new `ConstructionSite.building` flag plus a `_process` that advances `work_progress`
  once every material is placed. The manual `work()` is unchanged.
- When BuildFlow places a site, the survivor plays the `kick_dirt` clip, but only if
  `res://assets/characters/survivor/anim/kick_dirt.glb` exists (that clip is being made on claude/mmo-rummage).

**Tags and recipes** (data: `items.json`, `recipes.json`, `item_rarity.json`)
- Recipe slots already accept items by tag: their `category` is checked against the item's `categories`
  through `ItemDef.has_category`. **That is the single tag check**:
  - `Inventory.find_by_category`, `Blueprints.fits` and the new `Crafting.recipes_accepting` all go through it.
  - To use bagui's `ItemDB.has_tag`, change `ItemDef.has_category` to call it.
- `Crafting.recipes_accepting(def_id)` is the "Craft into..." list for bagui's item detail panel.
- Bones become planks: the Plank slot now asks for `thick_pillar` instead of `split`. Split wood, large leg
  bones and stout leg bones carry that tag.
- Metal becomes sticks: new items `silver_chunk`, `metal_stick` (tags metal / stick / handle, so it fills handle
  slots) and `metal_nail`. `metal_shard` gains the `chunk` tag.
- New anvil recipes: `metal_stick` (1 chunk → 2 sticks, 10:00) and `metal_nail` (1 chunk → 4 nails, 2:00).
  The new items have stack_max 1, so each output is its own item. Outputs inherit the primary input's
  attributes through the existing `build_output`; the test checks that Firm 4 carries over.
- **I added `metal_nail` to the canon data. If claude/mmo-stationstate adds `metal_nails`, keep only one.**

## Verification

- New test `game/tests/t_craftradial.gd` runs at 1600x900 and 844x390, and the bone and metal checks run once.
  It checks:
  - the wedges for each kind, the main wedge on top, 64 px taps, the card at the top left, and the output row
    count and that it is on screen;
  - an output slot opens its recipe; REMOVE asks to confirm, then demolishes; PACKAGE returns the kit;
  - the panel is on the right, the Weapon tab filters, and search filters;
  - a bone pillar crafts a plank, and a bone's craft-into list includes Plank; silver makes 2 sticks that each
    keep Firm 4 and that fit a handle slot;
  - the Construction slots accept by tag and enforce the Lv 10 gate; Fill Automatically picks the best items;
    100 %; the timer starts and runs.
- `t_uicraft` D1 was rewritten for the pop-out and passes. `uicraft_lab` now uses the `tool` category.
- PNGs in `docs/orchestration/reports/craftradial/`. Each was taken at both `1600x900` and `844x390`, made by
  `game/scripts/dev/craftradial_lab.gd`, windowed at `--position 6000,3000`:
  - `craft_panel_*`, `craft_detail_*`
  - `radial_workbench_*`, `radial_remove_confirm_*`, `radial_oven_*`
  - `construction_*` (half filled)
  - `build_page_*`, `placement_*`
- `tools/all_tests.sh` and `tools/smoke.sh --no-import`: see the commit message for the final counts.

## Assumptions (# ASSUMPTION in code)

- There is no oven in the data, so the stone grill is the "oven". Crock pot, steamer and smoker also lead with
  COOK, and the drying rack with DRY.
- REMOVE refunds per the demolish rule: 0.5 × health × cost. A station's cost is one kit, which rounds down to 0,
  so only its contents come back. PACKAGE is the lossless way to move a station.
- REMOVE is refused for camp pieces, off your land, and while a process station still holds jobs.
- PACKAGE returns a plain kit. A kit-placed station starts at Lv 1, as before, so a station's level is not
  carried through packing. A kit that kept its level would need a save-format field; I did not add one.
- The craft panel's tabs follow the owner's reference. Tool and Weapon split the `weapon_tools` skill by what the
  recipe makes: an output whose first category is weapon or ammunition is a Weapon. Farming is kept as an
  eighth tab.
- The Construction panel shows the blueprint's Construction level as its requirement, because blueprints name no
  station to build at. Success is always 100 %, because spec 30 has no failure roll for construction.
- The metal stick recipe has no Tool slot (our recipes never consume tools). The amounts and times for sticks
  and nails are mine.
- `ConstructionSite.building` is not saved, so a reloaded site's timer waits until its panel is opened again
  ("Start build") or Work is used.

## Not done / for the next agent

- **Placement uses the existing build system** (Milan: "use that older build system"): `build_placer.gd` with
  its 1 m grid snap, drag-to-move ghost, rotate, SAVE / CANCEL, the existing grid overlay with its claim
  colouring, and layout mode. I removed nothing from it, so nothing needed restoring.
  - The new `BuildPlacer.begin_blueprint(bp_id)` puts blueprints on that same ghost. Before, a blueprint was
    dropped on the survivor's own cell with no ghost.
  - Confirm places a construction plot (`BuildFlow.place_site`) with no materials asked for. The level and
    skill-node gates, the claim and the footprint are still checked.
  - The Construction panel opens on the new plot.
  - The ghost label reads "Plot · materials go in later".
  - Tested: with an empty bag a plot is placed and cannot complete; once every slot group is filled and worked,
    it completes.
- **Still missing from placement mode:**
  - the camera tilt;
  - the exact banner "The building must be completely within the Domain to be protected.";
  - the round interact icon over a worksite. A site tap does open the Construction panel.
- The Build page icon for each blueprint is its station kit's icon (`CraftUI.blueprint_icon`). The Comm Center
  is a workbench-kind building, so it shows the workbench kit too; it needs its own icon.
- The Build page has no Components / Decoration category tabs, only the Stations and Blueprints sections.
- On a phone, a station near the screen edge pushes the ring over HUD elements (see `radial_oven_844x390.png`).
  The old hex menu did the same.
- The placement ghost shows a world chip named "@static Body 3d@…" (in `placement_*.png`). It comes from
  HudPills and appears to be older than this branch.
- The Construction panel opens bagui's item detail only as the existing focus card. Wire it to bagui's panel at
  merge.
- No save-format change.
