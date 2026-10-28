# Server contract — what `game/scripts/server/` does today

This line ships a **local, in-process** server engine and **no networking**. Nothing in
`game/scripts/server/` opens a socket, listens on a port or talks to a host: there is no
`MultiplayerPeer`, `WebSocketPeer`, `PacketPeer`, `StreamPeer` or `HTTPRequest` use anywhere under
`game/scripts`. The classes are plain `RefCounted`s with `class_name`; none of them is an autoload
(autoloads are `ShellLoader, InputSetup, Data, Game, World, TouchControls` in `game/project.godot`).
On this branch they are instantiated only by tests (`game/tests/srvdom_checks.gd`).

## Pieces
| file | role |
|---|---|
| `game/scripts/server/character_store.gd` | `CharacterStore` — the one entry point, durable character state |
| `game/scripts/server/intent_handlers.gd` | `IntentHandlers` — one handler per op |
| `game/scripts/server/character_state.gd` | `CharacterState` — the server-side dictionary for one character |
| `game/scripts/server/world_facade.gd` | `WorldFacade` — in-memory island the handlers may touch |
| `game/scripts/server/provenance.gd` | `Provenance` — uid/origin/seq stamp on minted assets |
| `game/scripts/server/server_rng.gd` | `ServerRng` — the server's only source of chance |

## Character store (`CharacterStore`)
- `CharacterStore.apply` is the single entry point. It drops unread argument keys, runs the
  handler, bumps `seq`, appends the op to `journal.jsonl` on disk, flushes, and only then returns
  the result.
- Durable form is a directory given to `_init`: `journal.jsonl` (append-only, one canonical JSON
  line per op, carrying `w` — the world answers the op read) plus `snapshot.json` written to
  `.tmp`, read back and renamed. Automatic snapshot every `snapshot_every_ops` = 500 ops.
  `dir == ""` is memory-only mode, used by tests.
- Boot (`CharacterStore.open`): read the snapshot, replay journal lines with a higher `seq`, cut a
  torn last line. Refuses a disk written under another `world_seed`, and warns when the hashed
  data files (`DATA_FILES`: items, recipes, combat_counters, combat_tuning, rules, inventory)
  changed since the snapshot. Store `VERSION` = 1.
- Idempotency: a client `rid` (1–64 chars) is remembered per character, `RIDS_KEPT` = 64; a
  repeated `rid` returns `conflict` with the original op instead of applying twice.
- Every op's stored text is what handlers parse, so a replay draws the same numbers
  (`ServerRng.seed_for` = sha256 of `"<world_seed>:<seq>:<salt>"`).
- `broken` is set on a journal write failure; from then on every op returns `server_error`.

## Ops the handlers answer (`IntentHandlers.run`)
Client ops (`CLIENT_OPS`), each validated in full before it mutates anything:

| op | handler | does |
|---|---|---|
| `act.gather` | `_gather` | one harvest-node pass, tool-class check, yield multiplier, gathering XP |
| `act.loot` | `_loot` | move a corpse slot into the bag |
| `act.craft` | `_craft` | `Crafting.plan_craft` + `run_plan` on the server bag |
| `act.place` | `_place` | consume one kit whose `place_as` matches the kind, queue a `place` write |
| `act.equip` | `_equip` | equip by bag slot/uid, or clear a slot |
| `act.eat` | `_eat` | one food unit: energy, buffs, raw-food status roll |
| `act.tame` | `_tame` | one `FieldTame` feed; the last feed bonds the pet (pen needed if the species requires one) |
| `act.capture` | `_capture` | `CaptureSystem` chance on a knocked creature under 30% HP; success gives a `captured_animal` stack, net consumed |
| `act.attack` | `_attack` | one melee swing with the client's combat numbers on the server RNG; ranged refused |
| `act.deposit` | `_deposit` | export a provenance-stamped item or pet to the economy vault |
| `char.get` | — | read-only `CharacterState.view` |
| `char.import` | — | always refused: an offline save never imports into an online character |

System ops (`SYSTEM_OPS`, never relayed from a client): `char.create` (`CharacterStore._create`),
`char.move` (`_move` — a distance budget of `RUN_SPEED` 7.0 m/s per second, or a travel `reset`),
`char.wallet` (`_wallet` — mirrors the economy wallet; the ledger stays authoritative),
`char.receive` (`_receive` — accepts only the exact exported body, once), `char.settled`
(`_settled` — vault confirms an export is consumed forever).

Reach constants: `GATHER_REACH` = 2.6 m, `LOOT_REACH` = 2.6 m, `REACH_SLACK` = 0.5 m. Asset
dictionaries in a request are refused (`ASSET_DICT_KEYS`); online characters move assets only by
slot or uid.

## Character state, provenance, world facade
- `CharacterState` wraps the stored dict: `bag`, `equipment`, `tool`, `wallet`, `pets`, `skills`,
  `pos`, `pos_ts`, `rids`. `CharacterState.inventory` hands a deep-copied `Inventory` over the bag;
  `commit` writes it back and mints uids. Created by `CharacterState.fresh`.
- `Provenance` stamps uid + origin + seq: item uids `"i<seq>.<k>"`, pet uids `"p<seq>.<k>"`,
  origins `gather, loot, craft, tame, breed, settlers, objective, market`. Only stamped assets may
  leave through `act.deposit`.
- `WorldFacade` holds in-memory dicts for nodes, corpses, creatures, stations, structures and
  blocked cells. Reads return plain JSON (positions as `[x, y, z]`) and are recorded on the op's
  `tape`, so replay never needs the island. Writes: `take_node_unit`, `take_corpse`,
  `damage_creature`, `set_tame_feeds`, `bond_creature`, `fail_capture`, `place`.

## Not on this line
- No transport, host, listen or port code; no client relay; no matchmaking.
- No authentication beyond "the account id must be positive", no sessions or tokens, no presence
  service, no region chat. `char.move` is the only presence-shaped op (a distance budget).
- No economy ledger or market on this side: `char.wallet` / `char.deposit` / `char.receive` /
  `char.settled` mirror a vault that does not exist in this repo.
- Skill nodes and unlocked techniques stay client-side; the comment in `intent_handlers.gd`
  defers that to a later workstream.
- The live game (single-player) keeps using `World` and `SaveGame`, not `CharacterStore`; see
  [saves-persistence.md](saves-persistence.md).
