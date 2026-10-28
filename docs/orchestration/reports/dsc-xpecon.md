# XPECON — XP economy from the islands-and-loop plan

## What shipped
- `game/data/world/rules.json`, new `xp` block: `gather_base` 1, `build_first` 30, `build_repeat` 8,
  `build_spam_radius_m` 10.0, `build_spam_seconds` 60.0, with an `_about` naming the plan section.
  Every number the task names is here; no XP number lives in code.
- **Gather** (`game/scripts/player/player_actions.gd`): `PlayerActions.gather_pass_xp(seconds)` =
  `xp.gather_base + round(seconds)`, paid to `skills.add_xp("gathering", ...)` (unchanged Rock/clay +1
  Processing beside it). The seconds are the ones that pass's ring really waited
  (`_gather_unit_time`, set by `_start_gather_cycle(GatherService.unit_seconds(...))`), so a tool or a
  Gathering level that shortens the work shortens the award. `World.add_xp` is not called separately
  any more: `SkillState.add_xp` mirrors every grant into it (the old flat 2 landed twice only because
  the code asked twice), so both bars pay the same number.
- **Build** (`game/scripts/core/world.gd`): `World.build_placement_xp(kind, at)` returns 0 for the same
  kind within 10 m of a placement of that kind inside 60 s, else 8 when `pioneer_buildings` already has
  the kind, else 30. `World.note_building(kind, at, player, extra_xp)` records the kind and pays one
  grant to Construction (mirrored to the character bar). `build_placer.confirm` now calls it instead of
  its own flat 8 + `note_building` pair. `game/scripts/items/build_flow.gd` is outside this job's
  SCOPE, so its blueprint call keeps its own `+bp.xp` grant and also pays the 30/8/0 rule through
  `World.note_building(kind)` — see "What the integrator needs", it is a one-line fix.
- Tests: `game/tests/t_xpecon.gd` -> `[t_xpecon] PASS`.
- Docs: `docs/current/economy-trading.md` has a new "XP economy (rules.json `xp`)" table.

## Before / after (measured in the test, on the live home island)
| action | before | after |
|---|---|---|
| stone pass, 2.8 s base, stone pick, skill 1 | 2 Gathering + 2 character | 1.62 s waited -> 3 Gathering, 4 character (3 + 1 Processing) |
| log pass, 3.0 s base, axe | 2 + 2 | 1.74 s waited -> 3 / 3 |
| berries pass, 1.1 s base | 2 + 2 | 0.86 s waited -> 2 / 2 |
| Lv-60 rock, bare hands vs pick | 2 + 2 each | 10.08 s -> 11 vs 7.47 s -> 8 |
| first basket ever | 8 Construction + 30 character | 30 + 30 |
| basket 1 m from its twin, minutes apart | 8 + 30 | 0 + 0 |
| basket 11 m+ away | 8 + 30 | 8 + 8 |
| basket moved beside a twin older than 60 s | 8 + 30 | 8 + 8 |
| fence beside a basket | 8 + 30 | 30 + 30 (per kind) |
| sign, first then repeat | 8 + 30 each | 30 + 30, then 8 + 8 |
| pack up and place again | 0 | 0 (repacked kits unchanged) |
| `World.xp_for_level` | 100 + 25 n | unchanged; Lv 1..10 sums to 2,125 |

## Assumptions
- **The pass's own seconds** are read from the ring timer rather than recomputed: the ring is what the
  player waits, and a recomputation after `park`/skill changes would disagree with it.
- A gather pass pays its XP even when the bag refuses the unit? No: the grants sit after the bag
  accepts, exactly where the old +2 sat, so a refused pass still pays nothing.
- The 60 s spam window is **transient** (`World.build_recent`): a save stores no placement times, so a
  reloaded island pays a fresh build normally. The first-of-kind memory *is* saved (the plan says so).
- Only the Tamed Island (is_home) keeps the first-of-kind memory and the spam rule. An unstable island
  is a visit: every build there pays the repeat award (8, the old flat number) and remembers no kind,
  so `t_build`'s "a fresh build still pays construction and pioneer XP" stays true there.
- The spam rule asks for a twin **placed** inside the window, not necessarily still standing (a packed
  up twin still counts), which is the simplest reading of "the same kit within 10 m of another of its
  kind within 60 s".

## Verification
- `bash .../verify_job.sh xpecon` full gate: see the log; related tests `t_gather t_build t_w2_skills
  t_skillfeel t_save` + `tools/smoke.sh` run by it.
- Visual half: the gate directory has `HEADLESS_ONLY` and `home_lab.gd` is outside SCOPE, so the
  windowed lab/screenshots were deferred by the owner's reservation — nothing visual changed anyway
  (the HUD text is untouched; only the numbers it already prints moved).
- No shots were looked at; the change has no rendered surface.

## What the integrator needs
- **Blueprint structures (`game/scripts/items/build_flow.gd`, outside this job's SCOPE):** it still
  calls `player.skills.add_xp("construction", bp.xp)` *and* `World.note_building(kind)`, so a workbench
  pays `bp.xp` (60) + 30 the first time, `bp.xp` + 8 after, and passes no position (so two blueprints of
  one kind anywhere would trip the 10 m spam rule). The intended shape is one call:
  `World.note_building(kind, station.global_position, player, int(bp.get("xp", 25.0)))`, which pays the
  blueprint reward and the 30/8/0 rule in a single grant. `World.note_building`'s new `extra_xp`
  parameter exists for exactly that.
- `t_gather` asserts "finish_gather pays only the base 2 Gathering XP" — it passed because that test's
  bush is a 1.3 s fibre pass (1 + round(1.3) = 2). Read it as a coincidence if it ever fails after a
  gather-seconds change; it should assert 1 + round(seconds), not 2.
- `t_build._test_pack_up_replacement_xp` asserts a fresh build pays construction and pioneer XP and a
  repack pays none: still true (it now sees +30, not +8).
- `game/scripts/gather/gather_service.gd`'s header comment ("base +2 Gathering is the whole award")
  and `game/data/gather_rules.json`'s `_about` mention the old flat 2. Both files are outside this
  task's SCOPE (`gather_rules.json` is in scope, the comment is not the number); the sentence is stale
  and worth one line in a docs pass.
