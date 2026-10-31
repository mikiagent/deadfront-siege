# claude-tuttown: the tutorial town, menu guidance, Craft / Build order

Branch `claude/mmo-tuttown` (local, not pushed), from `origin/claude/mmo-overhaul`, with canon
465b1827 (TUTPERF, ISLANDSHAPES, WIKI-STEWARD) merged in. Headless only (owner rule): no window was
opened for the final work, so there are no in-game screenshots. Instead there is a top-down
footprint map rendered from data: `docs/orchestration/reports/tuttown/town_map.png`.

## What shipped

### The town (`game/scripts/world/town_dress.gd`, `Tutorial.dress` -> `TownDress.build`)
- **Moved** (owner: "move it"). `tutorial_isle.json` now uses `dock_rule: south`, so the dock is on
  the southern-most coast, at about (-67, 317). The camp, which is the town centre, is the flattest
  dry ground about 48 m inland, at (-51, 271), on the southern peninsula. The harbour district runs
  down to the dock.
- **Districts**, set by angle from the dock:
  - harbour: stone warehouses, two extra piers with their boats, crates and fish, quay stacks and
    fish racks;
  - market: stalls under striped canvas with goods and signs;
  - homes: timber-framed and thatched;
  - workshops: open shelters with a station each; the forge and the stone grill are always busy
    through `StationState` (glow, sparks, at most 4 real lights), the rest hold drying racks, kilns,
    looms, ovens, smokers or a grindstone, each with a townsperson at work;
  - farms: fenced fields in four crop stages, scarecrows, compost, wells;
  - pens: fenced paddocks with tamed zebraceratops and compsognathus, plus hunters' hide tents.
- **The Adventurer's Guild hall** is the landmark: two storeys of stone and timber, a banner pole,
  torches and a sign. It stands behind the guild pavilion, which keeps the tap that opens the
  orders.
- **Upgrade** (owner: "looks very unfinished"):
  - an infill pass fills every free lot with a cottage, a fenced kitchen garden or a yard;
  - houses are 4-8 m by 4-6 m, one or two storeys, with four roof finishes (thatch, shingle,
    slate, tile) and varied pitches;
  - footpaths run from every front door to its street;
  - streets are paved inside the inner ring and dirt beyond;
  - a palisade runs at 97 m, with a gate (posts, lintel, lamps, signpost) wherever an avenue
    leaves and a 4 m wicket gap every ~25 m;
  - lamp posts line the avenues and rings.
- **Townsfolk.** There are 13 townsfolk (the survivor body with random looks): they idle or loop a
  work clip, and up to 4 walk the avenues (stat `npcs`; the cap is 16 bodies). Bodies and pen
  animals hide and stop animating beyond 60 m.
- **Scenery only.** Nothing in the town is saved, damaged, claimed or packed up. The footprints are
  marked occupied in the BuildGrid, so nothing can be built over them and the tile router walks the
  streets. Ground cover, dressing, props and non-tutorial harvest nodes are cleared on footprints
  and roads.
- **Island rule** (owner): only compsognathus and zebraceratops spawn. The wild zones are
  rewritten: compy singles at 100 m and packs further out, zebraceratops herds of 2-3 at
  120-360 m.
- **Water.** The river is about 205 m from the new town, so the water search reaches 260 m. The
  drink hint now says to go out through the north gate.

### Pointer and order targets
- **Hunt pointer.** It went to a protoceratops; that is fixed at the root.
  `world:creature:<species>` names only a living animal of that species, otherwise the nearest
  zone of it. `tut_hunt` uses `world:creature:compsognathus`.
- **Smooth pointer** (owner: "moves by updating its position"). Every frame the pointer eases
  toward its goal (exponential approach at 12/s, never faster than 2,600 px/s). A target that is a
  node (a creature, a carcass, a harvest node) is read every frame, so the arrow follows it.

### Menu guidance (`Tutorial.guide`, `tutorial_pointer.gd`, objectives.json `menu`)
- Every order done in a menu lists its taps, for example MENU > Craft > Materials > Twine > Craft.
- One shared rule: the pointer rings the deepest element that is on screen, with a "Tap <name>"
  caption.
- A tab that is open but wrong blocks the entry behind it. With All open, the pointer still asks
  for Materials first.
- A list entry is scrolled into view. If the player scrolls it away, a "Scroll down" or "Scroll up"
  cue shows instead of the ring.
- The pointer has its own canvas layer (97), above the menus and modals.
- The hints spell out the same route (tab, entry, button).
- Orders covered: eat, twine, knife, axe, fire, cook, meal, skill and build.

### Craft / Build (`craft_ui.gd`)
- The tabs are Materials (renamed from "Material Processing"), Tool, Weapon, Cooking, Clothing,
  Building Components, Farming, All.
- Build moved from the header to the bottom row of the list page.
- On a phone (844x390) the tabs are one row that scrolls sideways. Without that, the recipe list
  was 12 px tall; it is now about 70 px (one row of recipes), which is still cramped.

## Perf (headless)

| Measure | Before (canon, old town) | After |
|---|---|---|
| Island scene nodes (`tuttown_map`) | 5,608 added | 5,926 added; 6,537 total with the lab kit (TUTPERF budget 9,000) |
| Ticking nodes | ~656 (TUTPERF note: 637 + harvest) | 656-666 (budget 900) |
| t_perfgates `scene_nodes` | n/a | 5,918, PASS |
| MultiMeshInstance3D in the town | 0 | 182 (80 m chunks, visibility ranges: houses 220 m, props 110 m without shadows) |
| Town instances / collision boxes | n/a | ~1,960 / 235, on one PhysicsServer3D body with no nodes |
| Island build | 5.3 s | 5.4-6.0 s (the town is ~0.9 s of it, mostly townsfolk rigs) |
| Real lights in town | 0 | at most 4 (busy forge and grill hearths) |

Draw calls cannot be measured headless.

## Tests
- `t_tutorial`: 3/3 PASS in parallel, each with its own HOME (421, 519 and 714 s). One more PASS
  alone through all_tests (520 s). An earlier run had a storm during the fire order, after the bot
  was slowed walking back from the hunt round the palisade. Wicket gaps now open the wall every
  ~25 m.
- run_all: 140 tests, 139 pass. The 1 failure was t_tutorial hitting all_tests' 600 s per-test
  alarm under the parallel load (rc=70). It passed alone, as above. SMOKE PASS.
- `t_tutguide` (new) checks, at 1600x900 and 844x390:
  - every menu order walks its path element by element, and each element is on screen and inside
    its list (scrolled in);
  - a wrong tab is asked for before the entry;
  - a scrolled-away list shows the cue;
  - the hints name the tabs;
  - the tab order and Build at the bottom;
  - the pointer's per-frame step is bounded and it settles on and keeps up with moving targets,
    including following a world node.
- `t_tutorial` additions:
  - a big-town check (counts, lights ≤ 4, batches with visibility ranges, the guild hall);
  - from the square and from the dock, every order target is reachable on TilePath: guild,
    bench, pit, water, the town's herbs, berries and trees, and every wild zone;
  - the hunt pointer names a compsognathus;
  - only compsognathus and zebraceratops are on the island.
- `t_uicraft` updated (Build at the bottom). `t_craftradial`, `t_islandgen` and `t_perfgates` pass.

## Assumptions (`# ASSUMPTION:` in code and data; Open Questions TT1-TT6)
TT1 layout numbers. TT2 cost limits. TT3 tab order and labels. TT4 the guidance rule. TT5 the move,
the species and the 260 m water search. TT6 pointer easing.

## Save changes
None. Town pieces are never saved. The tutorial row is unchanged. An old mid-tutorial save that
loads will land at its saved position on the reshaped layout.

## Next
- Look at the town in a window when windowed runs are allowed again: wall and roof alignment,
  thatch texture, lamp glow.
- A well or spring inside the town would shorten the 205 m drink walk.
- Phone Craft / Build: the list is one recipe row tall at 844x390. The header, search and hint
  could share rows.
- Two of the five avenue gates fall on water. Only two gates are built (both on the north wall),
  plus the wickets.
- t_tutorial now takes 7-12 min (the drink walk is ~205 m and the hunt is beyond the wall). That is
  close to all_tests' 600 s alarm when 4 tests run in parallel.

## Credits
None spent.
