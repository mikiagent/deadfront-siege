# dsc — CURRENTDOCS (docs/current five missing pages)

Date: 2026-10-28. Scope: `docs/current/` only, plus this report.

## What shipped
Five new present-tense pages, each under 130 lines, every number tied to a named file or data key:

| page | lines | covers |
|---|---|---|
| `docs/current/inventory-bags.md` | 94 | `Inventory`/`ItemStack` instances, uid rules (`i<seq>` server, `l<hex>` offline), merge rules, the 6 `stacking_categories` that still stack, `BASE_SLOTS` 100, `slot_span` 4 captured animals, 5 bag types with curves from `game/data/bags.json`, 7 storage containers with slot counts, multi-select/lock/batch actions, save keys and the load migration |
| `docs/current/creatures-capture-taming.md` | 112 | 19-species roster table (tier, archetype, tameable, capture_tier, hp/atk/def/speed, feeds, pen), AI states/archetypes/leash numbers, spawns and the 24 cap, capture rule exactly as coded (<30 % HP + knockdown + net tier + technique + `TIER_BASE × (1.5−HP)`), field tame, pen, bonded cap 3–7, `MAX_OUT` 3, mounts |
| `docs/current/saves-persistence.md` | 88 | `user://save_1.json`, `user://runs/<name>/` for automated runs, `game/override.cfg` user dir, schema 4 + its 4 migrations, full key table, sanitizer clamps, `.bak`/quarantine/`LOAD_UNFINISHED` rescue, autosave triggers |
| `docs/current/server-contract.md` | 88 | `game/scripts/server/` is a local in-process engine with no transport; 12 client + 5 system ops, journal+snapshot `CharacterStore`, `CharacterState`, `WorldFacade`, `Provenance`, `ServerRng`, and an explicit "not on this line" list |
| `docs/current/economy-trading.md` | 70 | single T-stone int, 2 sinks (sail `sail_cost` 5, cargo warp 2), 3 sources (start 20, objectives, crater 30), `market.json` summarised as data only — no market UI, engine, ledger or selling exists |

`docs/current/README.md`: the five "needs writing" rows now link their pages with a
"written 2026-10-28 — …" state line.

## How it was checked
The task's verify script: `VERIFY PASS` (length, ≥4 real `game/` paths, every `name()` matching a
real `func`, no "needs writing" row, no changes outside `docs/current/`). No Godot run.

## Findings the other agents should know
- The capture chance table `TIER_BASE` in `game/scripts/pets/capture_system.gd` is still an
  in-code assumption; the doc states it as the current rule and does not describe pending changes.
- `rules.json` `craters.open_cost_tstones` = 50 and `missions.json` / `factions.json` T-stone
  numbers have no reader. The docs say so.
- `captured_animal` occupies 4 inventory slots (`slot_span` 4), not 2; an early draft said 2 and
  was corrected from `game/data/items.json`.
- `hunt.gd`'s `_net_cd` is decremented but never set — net cooldown is effectively not enforced.
  Not documented as a rule; flagging it here.

Credits spent: none. Nothing merged, pushed or deployed.
