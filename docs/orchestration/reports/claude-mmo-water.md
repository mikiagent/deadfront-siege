# claude-mmo-water: Drink and Wash next to water (spec 17)

Owner, verbatim: "when next to water, menu items pop up like washing and drinkinh". Spec:
`docs/design/durango-prompts/17_water_context_actions.md`, reference `docs/reference/durango-water-actions.webp`.

Branch `claude/mmo-water` from `claude/mmo-overhaul` at 73527576. Commits:

- `c46c3f3d` water_lab, the reproduction lab (committed before any game change)
- `9d705512` WaterAccess, water.json, t_water, the Dirty and Thirsty icons
- `2a4eb93e` Dirty icon redrawn (the first one read as the fallback sparkle at chip size)
- `a0418f36`, `1041c450` the report and the hooks patch
- `af97a593` review fixes (next section)
- the report commit for the fixes

The call sites live in files other packages own, so they are not committed on the branch. They ship as
`docs/orchestration/reports/claude-mmo-water-hooks.patch` (12 files, 167+/38-). `git apply --cached --check` passes
on the branch head and on `claude/mmo-overhaul` at e5f3ec8a. The work tree has them applied, and every gate below
ran with them applied. Since `af97a593`, `water_access.gd` calls `IslandTerrain.fresh_water_at_world`, which only
the hooks patch adds, so the branch and the patch must land together.

## Review fixes (af97a593)

The package passed review with three minor findings. The orchestrator ruled on them:

1. **No Thirsty from the sea** (review minor 1, orchestrator ruling). No doc supports "wading in the sea for 5 s
   gives Thirsty": PRD :284 says "Rain / standing in water 5s → Wet", and the research lists seawater thirst under
   drinking it. PlayerSim no longer applies Thirsty; standing in the sea gives Wet only. Thirsty stays in
   `statuses.json` (x1.2 fatigue, cleared by Drink) for a later trigger, and Drink still grants Quenched.
2. **Statuses on every PlayerSim branch** (review minor 3). `fatigue_gain_mult` and `in_water` were set in
   `_walk`, which the mounted, rolling, staggered, swinging and `cannot_act` branches return before. They are now
   set at the top of `PlayerSim.tick()`, before any branch returns.
3. **Fresh-water mask** (review minor 2). `is_fresh` read the live tile type, and a harvested node turns its tile
   BARE until it regrows, so a node in the river made that tile count as salt. `IslandTerrain._build_tile_types`
   now keeps `IslandRuntime.fresh_water` (1 on MUD tiles as built), `IslandTerrain.fresh_water_at_world` reads it,
   and `is_fresh` uses it. The `shortcut:` comment that named this limit is gone.

t_water changes, each failing on the old code (see Gates):

- "5 s in the sea: Wet, not Thirsty" (was "Wet and Thirsty").
- "a harvested (BARE) river tile is still fresh water": sets the river tile BARE the way
  `IslandRuntime._on_tile_bare` does, checks it reads BARE, then checks `WaterAccess.is_fresh`.
- "staggered in the river: Dirty's x1.2 and in_water still apply": Dirty, `fatigue_gain_mult` forced to 1.0,
  `in_water` forced false, a 10 s stagger, 3 physics frames in the river.

Credits spent: none (no Meshy, no Tripo).

## What the owner gets

Stand on a river bank or in the river and the bottom-right hex row shows Drink and Wash, with white icons, the
same place and look as the Durango reference. Fill shows as well when the bag holds an empty bucket. Walk about
3 m from the water and the hexes go away. The sea shows nothing, on purpose (next section).

- Drink clears Thirsty and gives Quenched. Quenched cuts heat fatigue by a fifth for 6 minutes. Drink no longer gives
  Energy; the base gave +5, and food is what fills Energy (PRD 6.2).
- Wash clears Dirty and Very dirty and gives Clean, -20 % fatigue gain for 6 minutes (PRD 6.4). Wash no longer
  takes 2 fatigue off at once.
- Fill turns one empty bucket into a water bucket at the bucket's level, as the well's `fill_bucket` recipe does.
- Gathering, butchering and taking hits make the survivor Dirty, then Very dirty. Standing in the sea for 5 s makes
  them Wet, as in the river (PRD :284). Thirsty exists as a status that Drink clears, but nothing applies it yet
  (orchestrator ruling, see Review fixes). All of these are statuses with chips under the minimap. None is a meter.

## Repro on the base, then after

`water_lab` stands the survivor at spots it finds on the home island's heightmap and records the HUD's context
hexes. Same lab, same spots, before and after.

| Spot | Where | Base 73527576 | After |
|---|---|---|---|
| river_bank_1m | dry bank, river water 1.3 m away | **no hexes** (claim only) | Drink, Wash |
| river_shallow | in the river, ground -0.22 m | Drink, Wash, but `in_water=false` | Drink, Wash, `in_water=true` |
| sea_bank_1m | beach sand, sea 0.9 m away | Drink, Wash | none (salt water) |
| sea_shallow | in the sea by the harbour | Drink, Wash, `in_water=false` | none, `in_water=true` |
| dry_mid | dry grass at (-48, 0), 12 m from any water | **Drink, Wash, `in_water=true`** | none, `in_water=false` |
| bank_statuses | river bank, Dirty + Thirsty, empty bucket | no hexes; the statuses do not exist | Drink, Wash, Fill; Dirty and Thirsty chips |
| bank_after | after pressing Drink, Wash, Fill | energy +5, fatigue -2, nothing else | Quenched + Clean, water bucket 1, empty bucket 0 |

Three base bugs sat behind this.

1. The test was "terrain under the survivor below 0.15 m". On the river's banks that band is about half a metre wide,
   so 1 m from the water showed nothing.
2. `in_water` came from a straight 10 m wide Area3D box along z = 0 (`IslandRuntime._river_trigger`). The river
   meanders up to 20 m off that line, so the box missed the river and covered dry grass across the whole island.
   The hexes appeared on dry land there, and Wet never applied in the real river.
3. The 0.15 m band also lit up on every beach, so the hexes appeared at the sea.

Shots (windowed, real HUD):

- before: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/water/shots/before/{1600x900_glc,844x390_glc}/<spot>_<w>x<h>.png`
- after: `.../scratchpad/water/shots/after/{1600x900_glc,1600x900_fwd,844x390_glc,844x390_fwd}/<spot>_<w>x<h>.png`

I looked at them next to the reference. The reference has the sprint hex plus Wash and Drink at the bottom right,
Drink outermost. Ours has Drink outermost, then Wash, then Fill, in the house hexes with white icons and captions. In
`bank_statuses` the Dirty splat and the hollow cracked Thirsty drop sit under the minimap, with no countdown. At
844x390 the three hexes sit in the bottom-right corner and clear the hands hex. Forward+ and gl_compatibility differ
only in terrain colour.

Run it: `Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility] res://scenes/dev/water_lab.tscn -- --lab=water_lab --shot-dir=DIR`
(also 844x390). Headless without `--shot-dir` it prints the same `[waterlab] spot=...` lines.

## Fresh water and the sea

The docs settle this, and I followed them. PRD :314 gives drink, wash and fill to fresh water. PRD :315 gives
seawater salt and some recipes. Research `durango-wild-lands-systems.md` §1.3 says "Fresh water (river/puddle, not
sea): drink, wash, or fill a container" (high confidence) and "Seawater is harmful and increases fatigue". The
world-environment notes list "Thirst +20% from seawater", which the research ties to drinking it. So the sea shows
no hexes, and wading in it gives Wet only.

The reference shot shows a survivor in shallow water near clams and a shoal of fish, with Wash and Drink up. That
looks like a beach. If that water is the sea, the reference and the docs disagree. **The owner should know the beach by
the harbour shows no Drink/Wash**; the nearest fresh water on the home island is the river, about 55 m north of the
harbour. Letting the sea count is a one-line change in `WaterAccess.is_fresh`, but the docs say no.

How "fresh" is decided: terrain under the water plane (`HarbourSite.WATER_Y`, the plane the water shader draws)
on a tile `IslandTerrain` marks MUD when it builds the tiles. MUD is the river channel and its banks, computed from
the same river formula that carves the channel. The open sea is never MUD. The MUD tiles are kept as a fresh-water
mask at build time, so harvesting a node in the river (its tile turns BARE) does not make the water salt. On the home island that gives 258 m² of river water and
11,989 m² of sea. "Next to" samples 17 points (feet, then 8 directions at 1 m and 2 m). It costs 9.5 µs per call
in t_water, so it can run every frame; the HUD already polls every 0.3 s.

## Effects, statuses and their sources

All five statuses are rows in `statuses.json`, applied through the existing StatusEffects. Two new StatusDef
fields, `fatigue_mult` (every fatigue gain) and `heat_fatigue_mult` (climate heat only), carry the percentages.
PlayerSim multiplies them into `Vitals.fatigue_gain_mult` every physics frame, next to coziness.

| Status | Effect | Length | Source |
|---|---|---|---|
| dirty | fatigue gain x1.2 | until washed | PRD 6.4 table, research bestiary 4.2 |
| very_dirty | fatigue gain x1.5 | until washed | same |
| thirsty | fatigue gain x1.2 | until fresh water | PRD 6.3; bestiary 4.2 (+20 %). Nothing applies it yet (orchestrator ruling) |
| quenched | heat fatigue x0.8 | 6 min | PRD :314 "drink (cuts heat fatigue)"; numbers are ASSUMPTIONS |
| clean | fatigue gain x0.8 | 6 min | PRD 6.4 Cleanliness |

"Until washed" uses 9,999 s, as `infected_wound` already does; the HUD now hides the countdown for anything over
an hour. `cleared_by` carries the remedy (`wash`, `drink`), so Wash is `clear_by_item(&"wash")` plus Clean.
Becoming Dirty removes Clean.

No meter exists. t_water checks the Player, Vitals and StatusEffects property lists for thirst, hunger, hygiene,
dirt, clean, quench or satiety names, checks that the saved vitals are still exactly Health, Energy and fatigue,
and checks that the HUD source has no thirst, hunger or hygiene bar. The grime count is hidden in Object meta and
never drawn.

## Assumptions (PRD silent; each is marked in code or data)

- `reach_m` 2.0: the hexes show while fresh water is within about 2 m (PRD :105 says "on/near"). `data/water.json`.
- Dirt: 1 point per gathered unit, 3 per butchered loot stack, 2 per hit taken. Dirty at 20, Very dirty at 60,
  reset by Wash. The PRD makes dirt a fatigue cause but never says what makes you dirty. `data/water.json`.
- Quenched cuts heat fatigue by 20 % (Wet's documented heat cut) for 6 min (Clean's length). `statuses.json` `_note`.
- Thirsty has no trigger. The orchestrator ruled out the sea; drinking seawater would be one, and the game has no
  verb for it.
- Fill keeps the empty bucket's level, matching the well recipe's mean-of-materials result.
- The grime count lives in Object meta, not the save (`shortcut:` comment in WaterAccess). A reload keeps the
  status and restarts the count at that status's threshold.

## Files

New, on the branch:

- `game/scripts/player/water_access.gd` (class `WaterAccess`): `in_water`, `is_fresh`, `near_fresh`, `drink`,
  `wash`, `fill`, `soil`, `grime`. The verbs re-check the water, because a sent intent is not the HUD.
- `game/data/water.json`: reach and dirt numbers.
- `game/tests/t_water.gd`: the acceptance test.
- `game/scripts/dev/water_lab.gd`, `game/scenes/dev/water_lab.tscn`: the lab above.
- `game/assets/icons/ui/_src/icons_j.py`, `dirty.svg`, `thirsty.svg` (+ `.import` with the house settings:
  lossless, mipmaps, svg scale 2).

Hooks patch, one line each:

- `player_input.gd` (W2-PLAYER): `context_actions` asks `WaterAccess.near_fresh`, adds Fill when the bag has an
  empty bucket, and drops the emoji glyph for Fill. `context_action` routes drink/wash/fill to PlayerActions.
- `player_actions.gd` (W2-PLAYER): verbs `drink()`, `wash()`, `fill_water()`. Offline they apply; online they become
  `act.drink`, `act.wash`, `act.fill` intents. `soil` on a gathered unit and a butchered loot stack.
- `player.gd`: `soil` on `receive_creature_hit`; Quenched's multiplier in `tick_climate_fatigue` (heat only);
  a doc line on `in_water`.
- `player_sim.gd`: at the top of `tick()`, before any branch returns, `fatigue_gain_mult` times the statuses'
  multiplier and `in_water` from the heightmap.
- `island_runtime.gd`: deletes `_river_trigger` and `_wet_area`, the straight box that set `in_water`; adds the
  `fresh_water` mask var.
- `island_terrain.gd`: builds `fresh_water` with the tiles (1 on MUD); `fresh_water_at_world` reads it.
- `status_def.gd`, `status_effects.gd` (W1-COMBAT): `fatigue_mult`, `heat_fatigue_mult`, and their products.
- `statuses.json` (W1-COMBAT): dirty, very_dirty, thirsty, quenched, clean.
- `ui_icons.json` (W1-UIICONS): fill (well icon), dirty, very_dirty, thirsty, quenched (drink icon), clean (wash
  icon). t_uiicons requires every status to have an icon.
- `_src/build.py` (W1-UIICONS): adds `icons_j` to MODULES and SOLID, so `build.py --check` accepts the two new SVGs.
- `hunt_hud.gd` (W1-UI): no countdown under a status chip with more than an hour left.

## Gates

### After the review fixes (af97a593)

In a throwaway tree made by `mkscratch.sh fix-water claude/mmo-water docs/orchestration/reports/claude-mmo-water-hooks.patch`
(branch at af97a593, all 12 hook files "Applied patch ... cleanly", `--import` done, 0 SCRIPT ERROR in its log):

| Gate | Result |
|---|---|
| every `game/tests/t_*.gd` (20 files) | all exit 0 and PASS: t_ai, t_build, t_canim, t_combat, t_harbour (islands=15), t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (its 5 deliberate SCRIPT ERRORs, each announced by the test), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons (`ids=175 files=116`, `[icons] PASS drawn=116 svgs=116`), t_water, t_web; 0 SCRIPT ERROR elsewhere |
| `run_all.gd` | exit 0, `[tests] PASS` |
| `tools/smoke.sh --no-import` | `[smoke] ok player_pos=(0.0, 1.0, 0.0) phase=day`, `SMOKE PASS` |

t_water's three new checks in that tree:

- `[t_water] ok a harvested (BARE) river tile is still fresh water (bare=true)`
- `[t_water] ok 5 s in the sea: Wet, not Thirsty (PRD :284; seawater thirst is for drinking it) ["wet"]`
- `[t_water] ok staggered in the river: Dirty's x1.2 and in_water still apply (mult 1.20, in_water true)`

The new t_water against the old code: a throwaway tree at 1041c450 (the reviewed head) with the old hooks patch
and only the new `t_water.gd` copied in exits 1 with exactly those three failing:

- `[t_water] FAIL a harvested (BARE) river tile is still fresh water (bare=true)`
- `[t_water] FAIL 5 s in the sea: Wet, not Thirsty (PRD :284; seawater thirst is for drinking it) ["wet", "thirsty"]`
- `[t_water] FAIL staggered in the river: Dirty's x1.2 and in_water still apply (mult 1.00, in_water false)`
- `[t_water] FAIL count=3`

### Before review (1041c450)

All with the hooks applied, in this work tree:

| Gate | Result |
|---|---|
| every `game/tests/t_*.gd` (20 files) | all exit 0 and PASS: t_ai, t_build, t_canim, t_combat, t_harbour (islands=15), t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (its 5 deliberate SCRIPT ERRORs), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons (`ids=175 files=116`, `build.py --check` PASS), t_water, t_web; 0 SCRIPT ERROR elsewhere |
| `run_all.gd` | `[tests] PASS` |
| `tools/smoke.sh --no-import` | `SMOKE PASS` |

t_water against the old code: in a throwaway tree at 73527576 with only `t_water.gd` copied in, it exits 1 with
32 FAILs. Among them: "1 m from the river: Drink and Wash are offered ["claim"]", "standing in the salt sea: no
Drink/Wash ["drink", "wash", "claim"]", "Drink gives no Energy ... 55.0", "Wash is no instant rest ... 38.0",
"in_water is false on dry grass on z = 0".

Also run: `--import` exit 0 after adding the class_name file and the SVGs; `ui_icons_lab` headless
`icons=116 bad=[]`, 0 SCRIPT ERROR; `water_lab` headless and windowed in all four configurations, exit 0,
0 SCRIPT ERROR.

## Not done, and what the next agent needs

- Server side. PlayerActions sends `act.drink`, `act.wash`, `act.fill`; W3-SRVACT needs handlers that call
  WaterAccess on the server's survivor. The verbs already re-check the water.
- The fatigue panel shows dirt and thirst only as a larger total, because they multiply other sources and add none
  of their own. A remedy line ("drink fresh water" for heat, "wash" for dirt) would match the research's help text.
- Wash's icon is the existing bubbles; the reference draws a hand under drops. Fill borrows the well icon. ICONS2
  may want dedicated drawings.
- The status cap (three statuses, the fourth replaces the weakest) can push Dirty out during a fight with bleeds;
  the next dirtying action puts it back.
- The grime count is not saved (see Assumptions).
- The reference's beach water: if the owner wants Drink/Wash at the sea, that overrides PRD :315 and is a
  one-line change.
- Disk: the machine ran out of space mid-run (124 MB free on /System/Volumes/Data, one tool call failed to write).
  I removed my own throwaway tree `trees/water-old`, which freed about 2 GB; by the final gate run 122 GB were free.
  If a later Godot run dies at startup, check `df` before suspecting code.
