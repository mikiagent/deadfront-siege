# Factions, reputation and the Faction Hall

Status: design for v1 (branch `claude/mmo-factions`). Owner ask, 2026-10-29: "You need factions, faction
reputation and missions per faction. 5 factions total, be creative. the main building should be this
faction hall. Assume this will be a multiplayer server and have tons of new players milling in and out".

Every number in this doc is `# ASSUMPTION` unless it cites the PRD. Numbers are logged as FA1-FA14 in
`docs/vision/WildLandsMMO_Open_Questions.md`. Data: `game/data/world/factions.json`.

## 0. Which five factions

The systems PRD (§15.1) already has five support organisations, and `factions.json`, the Comms screen
and the ui-redesign spec (F3) already use them. Five new factions next to five existing ones would mean
ten groups and two trust systems. So the five factions **are** the five PRD organisations. The creative
part is their look, their hall, what each one pays for, and their mission lists. Names and ids stay.

PRD facts kept as they are:
- They never meet in person; they radio. The Faction Hall is the island's **Communications Center**
  (PRD: "Taken at Communications Center"): five radio desks, one per organisation, staffed by survivors
  who volunteer for them. No faction NPC leader stands in the hall; K, Charlie and Dr. Lamar stay voices.
- Trust has 10 ranks. Rank bands 1-3, 4-6 and 7-10 each have a support crate.
- Up to 4 missions are active at once. Each one pays XP, T-stones and about 50 trust.
- Unlocks: Company at the tutorial, Chlorophyll Forum next to the tutorial, Pioneer Council at about
  level 16, Committee and Radio University at about level 20.
- Chlorophyll Forum and Pioneer Council oppose each other. The Committee pays most.
- Radio University has no crates and no fetch quests, only career guides. Guides are its only
  reputation path and give extra SP.

## 1. The five factions

| Faction | Identity | Banner | Values | Pays for |
|---|---|---|---|---|
| **The Company** | Relief and supply. They run the radios that brought every survivor in. Callsigns, not names (K, Charlie). | Signal orange on cream; a radio mast over a lifebuoy | Feeding and clothing newcomers, keeping fires lit | Gathering herbs and fuel, cooking, bandages, clothing; food and fish deliveries |
| **Chlorophyll Forum** | Conservation. "Take what grows back." | Leaf green on bark brown; an open leaf | Living with the herds, seeds, gentle harvests | Berries and herbs, saving seed, compost, **taming**, finding plant craters |
| **Pioneer Council** | Industry and science. "Build the frontier." | Iron blue with brass trim; hammer over compass | Ore, ingots, planks, standing buildings | Mining, smelting, **building in the domain**, plank deliveries, mineral craters |
| **The Committee** | Authoritarian; high pay, little thanks. "Results." | Black with a crimson bar; a closed eye | Kills, clean captures, rare parts | **Hunting**, butchering, captures, rare part deliveries; T-stones x1.8 (PRD "high pay", data `reward_multiplier`) |
| **Radio University** | Dr. Lamar's one-man university on the air. "Every island is a lecture." | Violet on ivory; three radio arcs | Learning by doing | **Career guides**: lifetime milestones (first knife, first tame, ten crafts, three islands, steam cooking, first ingot, a log shelter). Rewards are SP and reputation. |

The five banners hang on the hall front in this order, left to right: Company, Chlorophyll, Radio
University (centre, over the door), Pioneer, Committee. This puts the two rivals on opposite wings.

## 2. Reputation

- Reputation is a number of points per faction, from 0 up. Rank comes from the points:
  rank n needs `25 * n * (n + 1)` points (FA1). That is 50, 150, 300, 500, 750, 1050, 1400, 1800,
  2250 and 2750, so rank 1 takes one daily mission (50, as the PRD says) and rank 10 takes about 55.
- **Tiers** group the ranks, and each tier carries a title. The titles come from Durango's rank titles
  (`docs/reference/durango_tasks_csv/faction_rank_titles.csv`). In Durango those titles also gave stat
  bonuses; v1 drops the stat bonuses (FA2).

| Tier | Ranks | Company | Chlorophyll Forum | Pioneer Council | Committee | Radio University |
|---|---|---|---|---|---|---|
| 0 | 0 | Stranger | Stranger | Stranger | Stranger | Stranger |
| 1 | 1-3 | Walk-and-Talker | Green Cell | Five-Toed Sloth | Ill-Informed | Freshman |
| 2 | 4-6 | K's Acquaintance | Born Again Green | Intern No More | Obedient | Sophomore |
| 3 | 7-9 | Kindhearted | Busy Bee | Brown-Noser | Harried | Junior |
| 4 | 10 | Trustworthy | Ecological Elite | Pampered Executive | Philosophical | Senior |

**What a new rank unlocks** (paid once, on the Receive that crosses the threshold):
1. **Support crate** (PRD): one of each item in the faction's crate band for the new rank. The bands are
   1-3, 4-6 and 7-10 in `crate_bands`. Items go into the bag; what does not fit goes to home cargo.
   The four crate factions get this.
2. **Skill point**: Radio University has no crates (PRD), so each new rank there pays 1 SP instead (FA3).
3. **Missions**: some missions need a minimum rank (`min_rank`), so a higher rank opens harder and
   better-paid work.
4. **Title**: the tier's title shows on the Factions screen. Wearing a title on the nameplate is v2.
5. v2, not built: market discounts at the faction's stall, radio logs that unlock with trust (PRD), and
   cosmetic banners for the domain.

## 3. Missions

Every mission counts something the game already tracks. All counting goes through `Tasks.note`:

| Kind | Fires when | Status |
|---|---|---|
| `gather`, `gather:<item>` | a gathered unit lands in the bag | `gather:<item>` is new |
| `craft`, `craft:<recipe>` | a craft finishes | existing |
| `hunt` | a kill by the survivor or her pet | existing |
| `butcher` | a part kind is taken from a carcass | existing |
| `build`, `build:<kind>` | a building is placed and finished | `build:<kind>` is new |
| `tame` | a field tame bonds | new |
| `capture` | a capture net lands | new |
| `crater` | a crater (the landmark of each island) is discovered | new |
| `land` | an arrival by travel (World.travel); loading a save never counts | new |
| `explore30` | a landing on a Lv 30+ island | existing |
| `deliver:<item>` | the bag holds the items; Receive takes them | new |

Mission rules (v1):
- **Offers**: each faction's board offers up to 3 missions (PRD: 3 offers). The offers are its eligible
  missions, rotated by the UTC day so the list changes daily. Eligible means: the faction is unlocked by
  character level, `min_rank` is met, the mission is not already active, and it was not already taken
  this period.
- **Accept** at a faction board in the hall or plaza, or on the Factions screen. Accept is capped at
  4 active across all factions (PRD).
- **Cadence**: `daily` missions can be accepted once per UTC day, `weekly` once per UTC week (Monday),
  and `once` (career guides) once ever. The reset clock is the same as the Task screen's.
- **Progress** counts from the moment of accept, with one exception: career guides read lifetime counts,
  because "your first knife" may already be done. Deliveries read the bag.
- An active mission does not expire when its day ends. It stays until it is received or abandoned (FA6).
  Abandon frees the slot, but the mission cannot be taken again in the same period (the PRD's cooldown,
  simplified).
- **Receive** pays XP, T-stones (Committee x1.8), SP (guides) and reputation, then any rank-up unlock.
  This is the same `Tasks.claim` path and "<Task> Complete" popup as the Task screen. The PRD's "turn in
  at the camp shed and visit the objective pin" rule is deferred (FA7).
- Rerolls (PRD: 3 free, then Warp Gems) are deferred. The daily rotation stands in for them (FA8).

Mission lists are in `factions.json` under each faction's `missions`. Each faction's PRD `mission_pool`
ids map onto them: gather_herbs, catch_fish, gather_fuel, cook_meatballs and craft_clothing for the
Company; gather_plants_no_uproot, plant_seeds, discover_plant_crater and observe_herd for the
Chlorophyll Forum; mine_ore, smelt_ingot, build_structure, discover_mineral_crater and deliver_planks
for the Pioneer Council; hunt_predator, capture_animal, clear_crater_guardians and deliver_rare_part
for the Committee; Radio University's `guides`.

## 4. Rivals

v1 has **no reputation loss**. Gaining with the Chlorophyll Forum never costs Pioneer reputation. The
rivalry shows in the hall's layout (opposite wings) and in each faction's blurb.

Proposal for v2 (doc-worthy, not built): one weekly "contested" mission pair. The Forum's "Leave the
grove standing" and the Council's "Clear-cut the grove" sit on the same island, and finishing one closes
the other for that week. Rivals then compete through what they choose to do, and nobody loses points.

## 5. Where it lives in the UI

- **Factions screen** (`CommsUI`, the F3 screen, renamed on screen to "Factions"): SheetChrome, 64 px
  taps. On the left, the 5 factions, one row each: icon, name, tier title, and a reputation bar that
  shows rank and points. The bar has a ghost fill: a gain shows first as a light lead, then the real
  fill eases up to it, like the skill bars. On the right, the selected faction: its motto and values,
  then its mission offers (Accept), its active missions (progress, Receive, Abandon), and the unlocks of
  its next rank. The Radio University screen keeps its own layout behind its "Career guides" button.
- **Task screen**: keeps Durango's five tabs. Faction missions use the same Tasks system (rows, claim,
  save), as category `faction`. A sixth "Faction" tab is a one-line change if the owner wants one (FA9).
- **HUD**: the Tasks badge counts faction missions waiting for Receive (FA10).

## 6. The Faction Hall and plaza (tutorial town)

The tutorial town's guild hall becomes the **Faction Hall**. Its tap role stays `guild` internally,
which keeps the tutorial pointer and map markers working, and every name shown in the game is
"Faction Hall".

- **Placement**: the hall stands on the north-east side of the square, east of the road north out of town so that road stays open (`Tutorial.HALL_DESK`, FA11). Like every town building, it follows the player's building rules (owner 2026-10-30): it sits on the 1 m BuildGrid, faces south (the placer's default) and turns only in 90 degree steps. A survivor stepping off the
  ferry walks straight up the harbour avenue, across the plaza and into the hall. This is the arrival
  flow.
- **Building**: a 14 x 9 m two-storey stone hall with two one-storey wings. Five faction banners hang
  on the front on tall poles in the faction colours, and lamps light the door.
- **Boards**: five faction stalls stand in a row in front of the hall, all facing south, one per faction. Each has a
  canvas in that faction's colour and a tappable board that opens the Factions screen on that faction.
  Two more general mission boards stand at the dock arrival and at the plaza's far side, so a crowd at
  the hall door is never the only place to take work (FA11). That makes seven tap points in all.
- **Crowd**: survivors mill about. They are cheap: the townsfolk rigs, some standing in groups by the
  boards, some walking dock to hall and hall to plaza on loops (FA12: 8 plaza rigs on top of the town's
  16 townsfolk, so up to 24 rigs). Benches stand round the plaza edge, and the fire
  pit shelter is the gathering spot.
- **Budget**: everything is MultiMesh scenery, as in TUTTOWN. The boards are TownBuildings (one static
  body each), and the rigs are culled past 60 m. Gates: t_perfgates, at most 900 ticking nodes and 9,000
  scene nodes.
- **Multiplayer**: missions and reputation are per survivor. The hall, boards and crowd are shared
  scenery. With a server, the stand-in rigs give way to real players, and a v2 idea is a faction-wide
  weekly goal shown on each banner (for example "Company: 4,210 / 10,000 meals this week"). Networking
  stays deferred.

## 7. Save

There is a new top-level `"factions"` block: `{"rep": {faction_id: points}}`. The Tasks block gains
`"active"` (mission key -> {base count, accepted period}) and `"taken"` (mission key -> period id). An
old save has neither block and loads with 0 reputation and no active missions, so nothing is paid twice.
SaveSanitizer's SHAPE includes both. `Factions.from_dict` type-checks every field.
