# C0 Implementation ticket | Protect existing saves and preserve shipped behavior

**Ticket:** CONT-C0-SAVE-SAFETY
**Category:** core-save critical; in-place change only.
**Base branch:** current `origin/main` at time of work. **Audited reference:** `923657262cd335fefee9126df61dd0fff4b93321`.
**Game:** existing `game/`; **no separate fresh Godot project**.
**Status:** Proposed small engineering change; no gameplay formula approval required.

## Scope

1. Re-run baseline import, `tools/test.sh`, `tools/smoke.sh`; record result on untouched main and capture in-game screenshot(s). If baseline fails, report exact current failures before editing.
2. Write representative **schema 0/1/2/3** save fixtures from current layouts, with essential human/pet inventory, material levels/attributes, camp layout, world island, T-stones and structure positions.
3. Add a small recovery helper or safe-write routine behind `SaveGame.save_now()` that stages JSON before replacing the only real save, retains a last-known-good copy, and tests failed/partial write scenarios on the Godot target filesystem. Preserve `SaveGame.path` selection and `SaveMigrations` versions.
4. Change invalid-save behavior **only** to prevent data destruction. Keep bad files untouched, do not autosave a fresh world over them, show a clear recovery/new-game choice or safe error state through existing boot/UI. Do not silently reset world or corrupt file when encountering schema >CURRENT.
5. Add/update `game/tests/run_all.gd` and a focused save lab using existing lab wiring. Verify old save migration plus interrupted write; ensure bot uses `user://bot_save.json` with old bot semantics.
6. Demonstrate return to working gameplay with existing home, inventory, buildings, pets, craft and UI. Do not change loot/XP/weapon specs in this ticket.
7. Commit in a small code branch and hand off exact changed files/tests; no production deployment unless separately requested and all export checks pass.

## Protected existing calls and fields

Do not remove/rename `SaveGame.save_now()`, `load_now(host)`, `SaveMigrations.migrate()`, `World.island_id`, `World.cargo_home`, `World._home_buildings_cache`, `World.home_claims`, `Player.inventory`, `Player.bonded`. Preserve schema 3 shape and all migrators 0->1->2->3. Do not add generic `entities` root, per-stack UUIDs or change the core Player class.

## Regression fixtures and explicit expected outcomes

| Given | When | Then |
|---|---|---|
| schema 3 known-good save with wood/material traits and bonded pet | save + reload | same counts, levels, attrs, flags, IVs, EVs and placement |
| schema 0 world-coordinate house | load + migrate | old x/z building lands in valid grid location |
| schema 2 with grid cell and schema 3 with camp layout | load + save | retained placement and layout, no missing structures |
| corrupt JSON or truncated save | load | original bytes unmodified; no silent overwrite via autosave; recovery possible |
| future schema 99 | load on current code | do not rewrite save or pretend it was legacy |
| staged temp fails before replacement | simulated disk/IO error | old known-good save still available |
| new file fully staged then interrupted before final rename | restart | recover one valid snapshot with no partial mixed records |
| bot starts with `--bot` | boot, autosave | only `user://bot_save.json` affected |
| full basket and attempt to pack | existing behavior baseline documented | no unrelated change to packaging; future preflight is a separate C4 ticket |

## Testing commands

```bash
export GODOT_PATH=/path/to/Godot_4.7
"$GODOT_PATH" --headless --path game --editor --quit
GODOT_PATH="$GODOT_PATH" ./tools/test.sh
GODOT_PATH="$GODOT_PATH" ./tools/smoke.sh
"$GODOT_PATH" --headless --path game -- --lab=ui_family_lab
# New targeted save recovery lab: use existing --lab=<name> approach.
# For a web export / deploy only with explicit release approval:
./tools/export_web.sh
```

Do not assert these commands passed until run. `tools/test.sh` uses `tools/find_godot.sh` and executes `game/tests/run_all.gd`; `tools/smoke.sh` expects `SMOKE PASS`.

## Definition of done

Good old save fixtures survive; broken/newer saves are retained without silent overwrite; feature is reachable through existing boot path; existing gameplay regression and real visual checks pass; branch diff is scoped to save and tests only; exact reproduction/evidence recorded.

## Rollback strategy

Before testing keep original saved bytes, backup copies, and exact baseline commit. The feature must never rely on the older build understanding newer schema. Roll back code branch if tests fail, and keep backups rather than importing unverified new-format data.
