# claude-factions: five factions, reputation, faction missions, the Faction Hall

Branch `claude/mmo-factions`, cut from `origin/claude/mmo-overhaul` 24d2a22f. Pushed, not merged.
Design: `docs/design/factions.md` (committed first). Assumptions FA0-FA14 are logged in
`docs/vision/WildLandsMMO_Open_Questions.md`.

## The five factions

These are the PRD's five support organisations (systems PRD §15.1), not five new groups (FA0). New
for each: a look, values, a mission list, rank unlocks and a desk in the hall.

- **The Company** (signal orange on cream): relief and supply. Pays for gathering herbs and fuel,
  cooking, bandage deliveries and clothing.
- **Chlorophyll Forum** (leaf green on bark): conservation. Pays for berries, seed saving, compost,
  **taming** and plant crater surveys. Rival of the Pioneer Council.
- **Pioneer Council** (iron blue with brass trim): industry. Pays for ore, ingots, **building**,
  plank deliveries and mineral crater surveys. Unlocks at level 16.
- **The Committee** (black with crimson): **hunting**, butchering, captures and rare parts. Pays
  T-stones x1.8. Unlocks at level 20.
- **Radio University** (violet on ivory): career guides only, no fetch quests (PRD). Lifetime
  milestones: first knife, first tame, ten crafts, three islands, steam cooking, first ingot, a log
  shelter. Each pays SP. Unlocks at level 20.

## What shipped

- **Data**: `game/data/world/factions.json` keeps every existing key. Each faction gains colour,
  trim, motto, values, four tier titles (Durango's rank titles) and `missions`, built from the PRD
  `mission_pool` ids. A new `_rules` block sets rank_k, offers, max_active, rank_sp and tiers.
- **Core**:
  - `game/scripts/core/factions.gd` (`Factions`, new): reputation per faction. Rank n needs
    25·n·(n+1) points, 10 ranks. Tiers carry titles. `add_rep` pays every rank it crosses: crate
    band items go to the bag, and anything that does not fit goes to home cargo; Radio University
    pays 1 SP per rank instead.
  - Faction missions live in `Tasks` (`tasks.gd`) as category `faction`:
    - `offers`: up to 3 per faction, rotating by UTC day.
    - `accept` is gated by unlock level, min_rank, the 4-active cap (PRD) and once per day / week /
      ever.
    - `abandon`, plus rows with progress. Progress counts from accept; career guides count over the
      survivor's lifetime; deliveries read the bag.
    - `claim` (Receive) takes delivered items, pays gold (x multiplier), XP, SP and reputation, and
      returns the ranks gained.
    - `claimable_count()` (the HUD Tasks badge) includes faction missions. The Task screen keeps
      Durango's 5 tabs (FA9).
- **New counted events** (`Tasks.note`): `gather:<item>` (GatherService), `build:<kind>`,
  `crater` and `land` (World), `tame` (FieldTame), `capture` (CaptureSystem).
- **Factions screen**: `CommsUI` rewritten. It is the F3 sheet, now titled "Factions", and the nav
  entry "Communication" is renamed to "Factions".
  - It uses SheetChrome; Accept, Receive and Abandon are 64 px tall.
  - Left: 5 faction rows, each with a colour swatch, icon, name, tier title (or Locked · Lv N),
    "Rank r / 10" and a reputation bar. The bar is tinted with the faction colour and uses the skill
    bar's ghost fill: a gain shows as a light lead, and the real fill eases up to it after 0.6 s.
  - Right: parchment header (name, motto, title), then the last result line, "Your missions"
    (progress, Receive / Abandon), "Mission offers" (Accept, or why not), "Next rank" (crate items or
    SP, and the next title) and "About".
  - `HuntHud.open_comms(fid)` preselects a faction. Radio University's own screen and Contribute are
    unchanged.
- **Faction Hall** (tutorial town):
  - `Tutorial._faction_plaza`: the desk (TownGuild, role `guild` kept, named "Faction Hall") stands
    north-east of the square, east of the road north to the water so that road stays open. All of it
    sits on the 1 m BuildGrid facing south, the placer's default (owner rule 2026-10-30); benches turn
    only in 90 degree steps.
  - Seven `faction_board` TownBuildings (`sign`): five faction boards in a row in front of the hall
    in banner order, one on the square's dock side, and one by the dock arrival. Tapping a board opens
    the Factions screen on its faction. The desk opens the tutorial orders while the tutorial runs,
    then the Factions screen.
  - The market stall, sign, barrel, crates and the two tutorial trees moved to dock-relative spots
    on the square's flanks.
  - `TownDress._guild_hall`: a two-storey 14x10 stone hall with two one-storey wings, flush with the
    hall. Tall colliders over it, because the land rises behind the square. Four banner poles and a
    centre banner over the door in the faction colours. Lamps at the door.
  - Each board has a stall: four posts, a flat awning in the faction colour, and a valance in the trim
    colour.
  - Eight benches ring the square. Ground-cover grass on the square is cleared; props, dress and
    harvest nodes stay. WildGrass is a gather prop that the fibre order uses.
  - Plaza crowd: 6 survivors stand at the desk and boards, and 2 walk dock -> square and along the
    hall front. They have their own cap and their own RNG, so the district townsfolk stay as before.
  - All of it is MultiMesh, except the 8 rigs and 7 board bodies.
- **Tutorial orders**: tut_camp is now "Report to the Faction Hall" and the pit hint says "on the
  square". The pointer and `near` still use `guild`. docs/current/tutorial.md is updated.

## Save change (owner gate)

- **New top-level `"factions"` block**: `{"rep": {faction_id: points}}`.
- **The `"tasks"` block gains two keys**:
  - `"active"`: `{"faction.<fid>.<mid>": {"base": life count at accept, "at": period}}`
  - `"taken"`: `{"faction.<fid>.<mid>": period}`, where period is `d<utc day>`, `w<utc week>` or
    `once`.
- **Old saves**, without these blocks, load with 0 reputation and no faction missions. Nothing pays
  twice.
- SaveSanitizer SHAPE lists both blocks. `Factions.from_dict` and `Tasks.from_dict` type-check
  every field and drop unknown factions and missions; a forged block is covered in t_factions.

## Tests

- **t_factions** (new): PASS. It covers:
  - the data;
  - per-faction tracking from accept;
  - Receive: 50 rep -> rank 1 "Walk-and-Talker" and the crate;
  - deliveries;
  - Radio University SP;
  - the Committee x1.8;
  - gates: level, min_rank, once a day, 4 active, 3 offers, next-day reopen;
  - the screen: 5 factions, 64 px taps, Accept, Receive and the ghost fill catching up;
  - save round trip, an old save, and a forged save.
- **t_taskscreen, t_tutguide, t_perfgates, t_uiworld**: PASS. t_uiworld's comms check now expects
  live Accept buttons.
- **t_perfgates**, tutorial island: ticking 653 (budget 900), scene nodes 5,970 (budget 9,000).
- **run_all** `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.
- **t_tutorial** (own HOME, alarm 1200): PASS 3/3 on the final tree. Each run retries the axe step
  once, as canon 24d2a22f also does (canon was 2/2 PASS in this session).
  - Earlier layouts failed: the hall stood straight across from the dock, on the road north to
    the water, and the bot snagged on a wing corner and got sent past a compy zone.
  - The fixes: a 1 m router pad round the hall and wings, tall colliders, the hall turned 30
    degrees off the dock line (`Tutorial.HALL_DEG` = 210), and the two tutorial trees moved clear
    of the board arc.
- **Footprint map**: `docs/orchestration/reports/factions/plaza_footprint.png` (written by
  `game/scripts/dev/faction_plaza_map.gd`, headless). Dock at the bottom; the white desk with the hall
  behind it; the five board colours in a row; grey general boards; the crowd and walkers in cyan.
- **Windowed shots**: `docs/orchestration/reports/factions/hall_{hall,boards,plaza,dock}_{1600x900,844x390}.png`
  and `factions_company_*`, `factions_forum_receive_*`. They come from
  `game/scripts/dev/faction_shots_probe.gd`; run it with
  `-- --faction-shots=<dir> --new-game --occupation=farmer`. It quits by itself.

## Known issues and next steps

- The land rises about 4.5 m across the hall's footprint, so its back-left corner sits in the slope.
  Tall colliders keep anyone off the roofs: before them, the tutorial bot walked off the hill onto a
  wing roof and got stuck there.
- At the widest camera zoom, the town's walls and FAR_PROP scenery fall outside their visibility
  ranges. This is not new; it is the town's own setting. The hall reads properly at the default zoom.
- The hall changes the lots of the ring behind it, so the district layout differs from canon. The
  town still has 40 houses, and t_tutorial's floors are unchanged except townsfolk <= 24 (16 + 8
  plaza).
- The market stall, sign, barrel, crates and the two tutorial trees moved to dock-relative spots.
- Not built (v2, in the doc): rerolls, the turn-in at the shed with an objective pin, wearing titles,
  market discounts, radio logs, contested rival missions, faction-wide weekly goals on a server, and
  a sixth "Faction" tab on the Task screen.
- The map_lab / sample.map marker still says "Adventurer's Guild" (a dev map; t_maplab checks it).
- `bot_survivor.gd` craft-blocked events and `tutorial_bot.gd` "could not walk" now also print
  positions, so stuck spots can be found.
- Credits spent: 0.
