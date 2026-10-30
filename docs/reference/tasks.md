# Durango task research: what it holds and how our tasks use it

Source: `durango_all_tasks_research.xlsx` (Milan, 2026-10-28; researched the same day). Each sheet is exported
to CSV in `durango_tasks_csv/`. The xlsx stays the original. Our task data lives in `game/data/world/tasks.json`;
the code is `game/scripts/core/tasks.gd` (the Task screen is `game/scripts/ui/orders_sheet.gd`).

## Sheets

| Sheet (CSV) | Rows | What it is |
|---|---|---|
| `overview.csv` | summary | Record counts per system, coverage notes and caveats. |
| `task_catalog.csv` | 137 | Every record in one table (the sheets below are slices of it). |
| `task_board.csv` | 14 | The in-game Tasks board: Daily, Weekly, In-game achievements, Career/construction, tutorial. |
| `faction_missions.csv` | 42 | Communication-centre faction commissions (deliver items to The Company, Committee, ...). |
| `career_guides.csv` | 58 | Career Guide completion titles; their checklists are missing. |
| `google_achievements.csv` | 16 | Google Play platform achievements (not in-game). |
| `events_and_finale.csv` | 7 | Limited events, titles, the 8-part finale. |
| `faction_rank_titles.csv` | 20 | Faction rank titles and their stat bonuses. |
| `sources.csv`, `missing_data.csv` | | Where each row came from; what is still unknown. |

## Columns (task tables)

`ID` (DW-Txxxx), `System`, `Task / title`, `Faction / path`, `Island / context`, `Objective / requirement`,
`Target item / enemy`, `Qty`, `Min item Lv.`, `Rewards / effects`, `Recurrence`, `Evidence`,
`Official task name?`, `Research notes`, `Source URL`. Blank means unknown, never zero.

## How they map to `tasks.json`

| Sheet column | tasks.json field | Notes |
|---|---|---|
| `ID` | `source` | Kept on every imported task. |
| `System` / `Recurrence` | category (`daily`, `weekly`, `achievement.tasks`, `domain`, `main_hidden`) | Daily tasks -> daily; Weekly -> weekly; In-game achievements -> achievement; Career / construction -> domain; General / tutorial and Endgame story -> main_hidden. |
| `Task / title` | `title` | Kept as written, except descriptive labels in brackets. |
| `Objective / requirement` + `Qty` | `desc` (`%d` = want), `want` | Blank Qty: our number (ASSUMPTION). |
| `Target item / enemy` | `count` | What `Tasks.note` counts: `gather`, `butcher`, `craft:<recipe>`, `build`, `hunt`, `explore30`, `mineral60`. Durango items map to our nearest recipe (below). |
| `Rewards / effects` | `t_stones`, `xp`, `sp` | The sheet names reward kinds, almost never amounts. Amounts are ours (ASSUMPTION) unless written; the Durango text is kept in `durango_reward`. |

### Imported (shown and tracked)

| DW id | Ours | Category | Change |
|---|---|---|---|
| DW-T0122 Gather resources | `daily.gather` Gather Resources, 30 | Daily | Qty ours. |
| DW-T0119 Butcher 10 times | `daily.butcher` Butcher 10 Times, 10 | Daily | One count per part kind taken from a carcass (the same anti-farm rule as Butchering XP). |
| DW-T0117/0118 Material Processing / Trim Materials | `daily.trim`, 3 trimmed planks | Daily | "Trimmed Material" -> our `trimmed_plank` workbench recipe. Qty ours. |
| DW-T0121 Craft stone blades | `daily.stone_blade`, 2 | Daily | "Pebble Stone Blade" -> our `improvised_stone_knife` / `stone_knife`. |
| DW-T0123 Construct a building | `daily.build`, 1 | Daily | Any placed or finished build. |
| DW-T0125 Explore Level-30 islands | `weekly.explore30`, 2 landings | Weekly | Reward scaled: Durango's ~10,000 T-Stones would be 500x our starting purse; we pay 100 (Open Questions TS9). |
| DW-T0137 Gather 1,000 Level-60 minerals | `achievement.minerals60`, +1 Skill Point | Achievement | "Minerals" = material Lv 60 from a rock-role node. |
| DW-T0128 Civilized domain building tasks | every `domain` task pays 1 Skill Point | Domain Construction | The sheet says these tasks pay extra SP; the tasks themselves are ours. |

### Data only (in tasks.json with `hidden: true`, not shown)

| DW id | Why |
|---|---|
| DW-T0120 Craft leaf outfits | The Tailoring node exists, the recipe does not. |
| DW-T0124 Daily task points (50) -> 15 Warp Gems | No task points or Warp Gems. |
| DW-T0127 Construct an Advanced Kiln | No placeable kiln. |
| DW-T0126 Cheer another pioneer | No emotes, no other players. |
| DW-T0135 Final storyline | No story chapters in the PRDs. |

### Not imported

Faction missions (42), Career guides (58), Google Play achievements (16), events, rank titles: they belong to
other systems (Communication centre, Career Guide, platform), not the five Task tabs. DW-T0129 (Rank III
Leather Outfits) is a career-guide milestone. Our own tasks with no sheet row stay as ASSUMPTIONS: the daily
and weekly hunts, weekly gather and craft, the eight domain builds, and the level achievement chains.

### Main Task

Main Task is our standing orders (`objectives.json` `steps`) and, while the tutorial runs, the tutorial
island's orders (`objectives.json` `tutorial`, on `claude/mmo-tutorialfix`, not on canon yet). The sheet
has no main-quest data beyond DW-T0126 and the finale.
