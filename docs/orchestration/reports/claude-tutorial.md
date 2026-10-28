# TUTORIAL ISLAND — Claude report (2026-10-28)

Branch `claude/mmo-tutorial-island` (from `claude/mmo-overhaul`, canon merged in once, with FIREPITS).
Facts page: `docs/current/tutorial.md`. Assumptions: Open Questions A12-A19 (2026-10-28 section).
No credits spent, no push, no merge into canon.

## What shipped
- **New survivors spawn on a shared tutorial island**, not a home: character creation →
  `Tutorial.begin` → `tutorial_isle` at its dock. The island pick (ISLANDPICK A2) moved to the
  end of the tutorial.
- **19 tutorial orders on the existing Orders system** (`objectives.json "tutorial"`): report to the
  Adventurer's Guild, branches, stones, fibre, drink, eat berries, rest, twine, stone knife, work axe,
  logs, hunt a compsognathus, butcher it, light the stone fire pit (FIREPITS `load_wood`), cook a
  Herb Roast (COOKROLES: meat main + herb topping + branch support), eat it (buff), learn a skill,
  build a straw bedroll, board the ferry. HUD orders card/badge, Orders sheet and payouts work
  unchanged (`Objectives._steps()` switches lists). No taming order (vision §1).
- **Onboarding pointer** (`TutorialPointer`): gold ring on the exact HUD element (MENU, BUILD, BAG,
  a context hex `Ctx_<id>`/INTERACT) or an arrow over the world target (guild, bench, fire pit, the
  nearest branch/herb node, the animal, the carcass, the river bank, the dock), edge arrow off screen.
- **Home grant**: the last order opens the Tamed Island pick; SELECT AND MOVE fades and ferries the
  survivor to the picked home (`World.complete_pick`), "YOU MADE IT". Everything carried comes along;
  standing orders resume at "Weave a capture net".
- **Owner's town + size pass (M4)**: landmass 795 x 636 m (4.5x the home's land); a prebuilt
  indestructible town at the landing (Adventurer's Guild → Orders sheet, market stall → Island
  Market, camp fire/bench/shed/cargo, stone fire pit, drying rack, sign, crates; never saved, never
  damaged, never packed, grid-occupied); the island cannot be claimed and shows no domain banner;
  wild lands as 11 streamed `ZoneSpawner` groups (compsognathus by the town → deinonychus 360 m out).
- **Saves**: `"tutorial": {done, did}` written only while running; no row = done, so every old save
  loads into its home exactly as before (no migration, homes untouched). Mid-tutorial saves resume
  on the island at the same order; a save waiting on the grant re-opens it.
- **Dev**: `--skip-tutorial`, `--tutorial-step=<n>`, `--lab=tutorial` (fresh run folder, real new
  game), `--tutorial-bot [--tutorial-shots=<dir>]` (plays every order windowed).

## Gates (all on the merged branch)
t_tutorial PASS (bot plays all 19 orders with the real actions in ~3.5 min game time, mid-way
save/reload resumes, home grant + ferry, old save skips, forged row cleaned, skip/step flags, town
indestructible + unclaimable, 4.5x size, cover ceiling, zone streaming). t_islandpick, t_charcreate
(updated for the new flow), t_save, t_savefix, t_domain, t_gather, t_build, t_ui, t_fieldhud,
t_hudrules, t_data, t_harbour, t_islandgen, t_biomes PASS; run_all `[tests] PASS`;
`tools/smoke.sh --no-import` SMOKE PASS. t_perfgates PASS and unchanged vs canon run back to back
(home 3465 vs 3459 ms, 171.3 MB both; its three islands do not include the tutorial island).

## Tutorial island cost (measured headless, alone)
Build 8.2-9.0 s (home ~3.5-3.9 s), ~5.6k scene nodes, 609 harvest nodes, ~66k multimesh
instances (52k ground cover), ~215 MB static heap added, up to 24 live creatures. Limits that
got it there: cover full within 120 m of the town and 6 % beyond, dressing 30 %, terrain res 241,
zone-streamed creatures. Before limits: 15 s, 397k cover instances, 266 MB.

## Captures (`docs/orchestration/reports/tutorial/`, 64-colour PNG <= 285 KB)
Windowed `--lab=tutorial --tutorial-bot` runs at 1600x900 (saved at 960x540) and 844x390:
`01_spawn_1600.png` (dock, edge arrow to the guild, 1/19 badge), `02_guild_town_1600.png` and
`02_guild_town_844x390.png` (Adventurer's Guild, sign, crates, camp), `03_fight_1600.png` and
`03_fight_844x390.png` (compsognathus hunt, pointer on the animal), `04_fire_1600.png` (stone fire
pit loaded, pointer), `07_build_1600.png` (straw roll placed, MENU ring), `08_grant_pick_1600.png`
(Tamed Island pick), `09_home_arrival_1600.png` (YOU MADE IT on the home, orders 10/28).
Looked at: HUD, pointer and town read correctly; the town models are stand-ins.

## Left / risks
- Terrain, nav and scatter are not chunk-streamed: the big island's build time and heap are ~2x a
  home's and will matter on web/phone. Next: chunk the terrain mesh + scatter by distance.
- The guild opens the Orders sheet only; it does not offer comms_ui faction missions (none are live).
- The town uses stand-in models (log shelter, fishing stand); a real guild/market art pass is open.
- The bot retries an order up to 3 times (the live island can interrupt a craft); a fully
  deterministic run would need a quiet test island.
- `World.camp_layout` is keyed by camp-piece names shared with the home (a moved home fire would
  move the tutorial fire too); only matters for a survivor who already has a home, who never visits.
