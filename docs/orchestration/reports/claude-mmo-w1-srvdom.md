# W1-SRVDOM: server character store and intent handlers

Branch `claude/mmo-w1-srvdom` (cut from `claude/mmo-overhaul` at `ea2d167`). Pure domain code, no
networking, no nodes, no autoloads. Credits spent: 0.

## What shipped

All new, in `game/scripts/server/`:

| File | What it is |
|---|---|
| `character_store.gd` (`CharacterStore`) | Server-owned characters (contract v2 §0.1) with the economy engine's durability: `apply(op, account, args, ts)`; a change bumps `seq`, appends one canonical JSON line to `journal.jsonl` and flushes before returning. Snapshot = canonical state JSON written to `.tmp`, read back, renamed. Boot = snapshot, then journal lines with `seq > snapshot.seq`; a torn last line is cut, a seq gap or bad middle line stops boot. Memory mode (`dir == ""`) keeps the journal in `lines`. Also: optional `rid` idempotency (64 per character), an error-counting `Logger` that rolls the character back if an op hits a script error part-way, `invariants()`, `state_json()` / `state_hash()`. |
| `character_state.gd` (`CharacterState`) | One character as plain data: bag (20 slots), equipment and gather tool by uid, wallet mirror, pets by uid, skills `{tree: {level, xp}}`, position. `inventory()` builds a real `Inventory` over a deep copy; `commit()` writes it back. Stacks that were already in the bag keep their stamp; every new stack gets `uid`, `origin`, `seq`. |
| `intent_handlers.gd` (`IntentHandlers`) | One handler per intent, each validating everything before it mutates: `act.gather`, `act.loot`, `act.craft`, `act.place`, `act.equip`, `act.eat`, `act.tame`, `act.capture`, `act.attack`, `act.deposit`, plus `char.import` (always `invalid_asset`), `char.get`, and the server-only `char.create`, `char.move`, `char.wallet`, `char.receive`. They run the game's own `Inventory`, `Crafting` (plan, `consume_for_craft`, `build_output`), `Food`, `PetRecord.from_def`, `CreatureGenetics.roll(rng)`, `ProgressionScaling`, `FieldTame` thresholds and `CaptureSystem.TIER_BASE`. |
| `world_facade.gd` (`WorldFacade`) | What the handlers may read from and write to the island. The base class is a plain in-memory island (tests, the fuzz); W3-SRVWORLD subclasses it over `IslandRuntime`. |
| `server_rng.gd` (`ServerRng`) | The server's only randomness: one `RandomNumberGenerator` per op, seeded with sha256 of `world_seed:seq:op`. |
| `provenance.gd` (`Provenance`) | `uid` / `origin` / `seq` stamping, origins `gather loot craft tame breed settlers objective market`, `is_server()`. |
| `domain_checks.gd` (no `class_name`) | The acceptance checks. The test loads this script by path on its first frame, once the `Data` autoload exists. |

Tests: `game/tests/t_server_domain.gd` (the spec name, prints `[t_server_domain] PASS`) and
`game/tests/t_srvdom.gd` (the wave-1 runner's name; it extends the first and prints `[t_srvdom] PASS`).

How replay works without the island: every world read goes through `IntentHandlers._read()`,
which records the answer. The journal line stores those answers as `w` beside `{seq, ts, account,
op, a}`. On replay the handlers get the recorded answers back and skip world writes, so the
characters rebuild from the journal alone. Args and world answers pass through canonical JSON
before the live op sees them, so live and replay see the same numbers.

## Acceptance checklist (each line seen in the runs below)

Runs (after the review fixes): `perl -e 'alarm 300; exec @ARGV' gslot.sh Godot --headless --path game -s res://tests/t_srvdom.gd`.
`t_server_domain.gd` runs the same checks under the spec name; only `t_srvdom.gd` was re-run after the fixes.

- [x] `t_srvdom.gd` prints `[t_srvdom] PASS` (re-run after the fixes; `t_server_domain.gd`
  printed `[t_server_domain] PASS` before them and runs the identical checks).
- [x] A gather on a node 1.5 m away with pool > 0 mints a stack with uid, origin=gather and the
  journal seq. Out of range, an empty pool and a missing tool each return their own code, and the
  canonical state hash and journal length stay the same:
  `[srvdom] gather uid=i4.0 origin=gather seq=4 count=4; refusals far:out_of_range:unchanged=true bare:depleted:unchanged=true ore:missing_tool:unchanged=true nope:not_found:unchanged=true`
  The check also confirms the last journal line is that gather at that seq, and that the node lost one unit.
- [x] Craft consumes exactly the planned inputs (`Crafting.slot_level_contributions` before
  vs. bag delta after) and mints a uid'd output with origin=craft. Refusals change nothing:
  `[srvdom] craft twine planned={ "fibre_stalk": 2 } used={ "fibre_stalk": 2 } output=i10.0 origin=craft seq=10; club dur=61; refusals insufficient_items,insufficient_items,out_of_range unchanged=true`
- [x] Tame draws on the server RNG, so the same journal gives the same genetics. Two independent
  runs and a replay of the journal all produce the same pet:
  `[srvdom] tame pet=p9.0 origin=tame seq=9 grade=C+ genetics_equal_runs=true genetics_equal_replay=true ivs={"accuracy":2,"health":0,"melee_attack":18,"melee_defense":27,"ranged_attack":0,"ranged_defense":1,"speed":30}`
  A tame on a creature that is not knocked out below 30 % returns `not_ready` and changes nothing.
- [x] 10,000-op seeded fuzz over 3 characters, covering every intent with valid and invalid
  args. After every op it checks: minted - consumed - exported == units held for each def, no
  negative counts, every uid in exactly one container (bags and pets), every stack and pet stamped,
  and equipment pointing only at bag uids. Every failed op left the canonical state byte-identical:
  `[srvdom] fuzz ops=10000 seq=3099 ms=4269 held_units=659 pets_minted=3 invariants=held_after_every_op stats={"act.attack":[773,337],"act.capture":[6,306],"act.craft":[388,796],"act.deposit":[199,369],"act.eat":[88,636],"act.equip":[119,553],"act.fly":[0,93],"act.gather":[532,2464],"act.loot":[147,356],"act.place":[34,271],"act.tame":[57,468],"char.import":[0,88],"char.move":[750,63],"char.wallet":[102,5]}`
  (`[ok, refused]` per op; the test fails if any intent never succeeds.)
- [x] Replaying the journal from empty, against an empty island, reproduces byte-identical canonical JSON:
  `[srvdom] replay lines=3099 byte_identical=true bytes=10712 sha256=07d90f8303eb5249`
- [x] An offline save dict offered as an import or deposit returns `invalid_asset`. The cases
  are the real `tests/fixtures/save_v2.json` as `char.import`, a forged `raid_helm x5000 L9999`
  `slot_dict`, a forged T. rex `pet_dict`, and a slot deposit carrying an `item` dict. A slot
  deposit of a server stack hands over a stamped asset:
  `[srvdom] offline import/deposit dicts -> invalid_asset,invalid_asset,invalid_asset,invalid_asset unchanged=true; slot deposit uid=i5.0 origin=gather`
- [x] Extra: durability. A crash (no shutdown snapshot) boots from snapshot plus journal to the live
  state; a clean `close()` snapshots with the data hash and empties the journal; a torn tail is cut;
  a snapshot taken under other data files sets `data_changed` and is re-snapshotted:
  `[srvdom] disk seq=43 crash_replay_lines=3 reopen_equal=true clean_close_snapshot=true torn_tail_cut=true data_change_flagged=true`
- [x] Extra: a repeated rid applies once, and reusing it for another op is a conflict:
  `[srvdom] rid repeat duplicate=true seq_unchanged=true other_op=conflict first_seq=4`
  and a present but unusable rid (65 chars, an int) is refused with nothing applied:
  `[srvdom] rid invalid long=bad_request int=bad_request unchanged=true`
- [x] Extra: `char.move` keeps one second's distance budget across all updates in that second
  (the reviewer's probe of ten 12 m hops at one ts now accepts 1; twenty 1 m hops accept 12):
  `[srvdom] move budget bound=12.2 same_second_12m_accepted=1/10 same_second_1m_accepted=12/20 next_second=true reset=true`
- [x] Extra: `char.receive` returns a deposited asset once and refuses forged or never-exported ones:
  `[srvdom] receive item=true restored=true twice=invalid_asset forged=invalid_asset unstamped=invalid_asset pet=ok pet_twice=conflict`
- [x] Existing suite: `--script res://tests/run_all.gd` printed `[tests] PASS` (exit 0, `run_all.log`).
- [x] `gslot.sh tools/smoke.sh --no-import` printed `SMOKE PASS` (exit 0, `smoke.log`).

## Screenshots inspected

None. The package draws nothing: it is headless domain code with no scene, UI or lab. So no
1600x900 or 390x844 shots apply, and I make no claims about appearance.

## Assumptions (`# ASSUMPTION:` in code)

1. New intent error codes beyond contract §2: `out_of_range`, `depleted`, `missing_tool`,
   `bag_full`, `not_ready` (`intent_handlers.gd:9`). Placement refusals use `conflict`; offline
   dicts use `invalid_asset`.
2. Online characters start with an empty bag and level-0 skills; nothing is imported (`character_state.gd:17`).
3. `REACH_SLACK` 0.5 m on top of a creature's body reach (`Hunt.melee_reach`'s formula) for attack, tame and capture.
4. `RUN_SPEED` 7.0 mirrors `Player.run_speed`, an export var. `char.move` allows
   1.6 x 7 m per elapsed second + 1 m, shared by every update inside the same whole second
   (`move_cm` on the character), unless `reset` (travel).
5. Placing a building trains Construction by 2 XP.
6. Vitals (energy, Full, buffs) stay client-side in W1. `act.eat` owns the food unit and the
   raw-risk roll, and returns `{energy, buffs, status}` for the client to apply.
7. Capture-technique unlocks are still client-side (`Data.survival_unlocked`). The server checks
   net tier against species tier, knockdown and < 30 % HP only.
8. Tame and capture genetics come from the island when it reports them, otherwise from the op's
   RNG. The in-memory island never reports them, so the tests exercise the RNG path.
9. The crafted level cap is `max(1, skill)`, which is monotonic in skill (the client's skill-0 = 60
   fallback is what W1-ITEMS removes).
10. The pet grade comes from `genetics.overall_tier()`, W1-TAME's rule, which replaces `FieldTame._roll_grade`.
11. A deposit of part of a stack gives the leaving part a new uid `i<seq>.0`. The rest keeps
    the original uid, matching the ledger's `take_item`.

Shortcuts with known limits (`# shortcut:` in code): one snapshot generation (EconStore keeps two
plus `journal.prev.jsonl`); a repeated rid returns `{duplicate, op, seq}`, not the first body;
`ServerRng.seed_global` reseeds the process RNG around `Crafting.build_output`'s burn roll until
W1-ITEMS lands its injectable RNG; melee only, never "from behind"; kits only for placement (no
branch+twine fallback); skill points and unlocked nodes stay client-side; the in-memory island
treats one structure as one cell.

## Integrator hooks

- **Tests:** register `game/tests/t_server_domain.gd` in `run_all.gd`, or let W1-QA's
  `tools/test.sh` run every `t_*.gd`. `t_srvdom.gd` runs the same checks under the wave-1 name.
  If both are picked up, the suite runs twice (about 5 s each), so drop one from the runner if
  that matters.
- **No edits needed** in `game.gd`, `main.gd`, `world.gd`, `project.godot` or `touch_controls.gd`.
- **Contract §2 / §0.3** (orchestrator): add the five error codes above. Record the intent ops
  `act.capture {net_id}`, `act.deposit {bag_slot, count?} | {pet_uid}`, `char.import` (refused),
  `char.get`, and the server-only `char.create {name}`, `char.move {p, reset?}`,
  `char.wallet {wallet}`. Journal lines carry an extra `w` (world answers).
- **uid namespace:** character uids are `i<seq>.<k>` / `p<seq>.<k>`. The dot keeps them distinct
  from the economy ledger's `i<n>` / `p<n>`, which come from its own counter.
- **W3-SRVACT / net:** relay only `IntentHandlers.CLIENT_OPS` from clients. `SYSTEM_OPS`
  (`char.create` on hello, `char.move` from accepted presence, `char.wallet` from the ledger) are
  server-internal. `act.deposit`'s returned `asset` is what goes to the vault. The engine's
  `AssetValidator` stays as defence in depth. Run the economy's validation before `act.deposit`
  removes the asset, or have the bridge put the asset back on refusal.
- **W3-SRVWORLD:** subclass `WorldFacade` over `IslandRuntime` and override each read
  (`node`, `corpse`, `creature`, `station_near`, `placement`) and write (`take_node_unit`,
  `take_corpse`, `damage_creature`, `set_tame_feeds` (which also extends the knockdown),
  `bond_creature`, `fail_capture`, `place`). Reads return plain JSON with positions as `[x, y, z]`,
  and `{}` when the thing is missing.

- **Identity rule (contract §0.5):** this package stamps every server stack `i<seq>.<k>` on the
  bag dict, and units merged into an existing stack take that stack's uid/origin/seq. W1-ITEMS'
  `ItemStack.uid` comment says the server issues uids on non-fungible stacks only, and its
  `can_merge` refuses to merge stacks that carry a uid. The server strips the stamp before handing
  rows to `Inventory`, so merging still works here after W1-ITEMS lands. The integrator picks one
  rule; this package's choice is "every server stack" per §0.5.
- **`char.receive {asset}`** (server-only, `SYSTEM_OPS`): the vault bridge calls it when the economy
  refuses a deposit or on a withdrawal. It accepts only stamped assets the `exported` counters cover
  and refuses a pet uid already held. Counters are per def, so the bridge must not return the same
  asset twice.
- **`CharacterStore.new(world, dir, world_seed)`**: `world_seed` is now required. W3 must pass a
  random, persisted, secret seed per world; anyone who knows it can predict capture, crit and
  genetics rolls for any seq.
- **Shutdown:** call `close()` on clean shutdown (it snapshots). After `open()`, `data_changed`
  tells the host that the journal replayed under different data files (items, recipes,
  combat_counters, world/rules); boot then snapshots at once.
- **W3-SRVWORLD precondition:** `ServerRng.seed_global` reseeds the process-wide RNG on every craft.
  Before the island's AI shares a process with this store, W1-ITEMS' injectable burn RNG must be in
  and `seed_global` removed, or creature `randf()` becomes a function of the craft seq.
- **W3-SRVACT item:** gathers and attacks have no domain time gate (a probe accepted 200 attacks at
  one ts); only the §5.4 write bucket limits them. `ts` is whole seconds, too coarse for a swing
  period, so W3-SRVACT adds `last_gather_ts` / `last_swing_ts` with sub-second server time.

## Labs to register

None.

## What failed or is left

Nothing in the acceptance list failed. Left for later packages:
- Ranged attacks (ammo, projectiles), the from-behind bonus, groggy/counter statuses and tool wear in
  combat: W3-SRVACT.
- Pen tames (feeds accumulate; completion is the taming pen's job) and server-side capture-technique unlocks.
- Skill points, unlocked skill nodes, character XP/level (`World.add_xp`), objectives (`World.note_craft`)
  and vitals are not on the server yet.
- Merging keeps the container's stamp. Units gathered into an existing stone stack take on that
  stack's origin and seq. Every unit still has server provenance, but per-unit origin is lost on merge.
- Movement is bounded by distance per second only. Terrain and navmesh plausibility come with W3-SRVWORLD.
- The first test run printed one `String formatting error` from my own check message (an empty
  Array used as format args). It was fixed before the final runs above, which print no errors.

## Resume check (2026-10-19)

A later run picked up the branch after the interruption and re-ran everything on `00c5d17` with no
code changes. Logs are in `scratchpad/w1/srvdom/final_*.log`: `[t_srvdom] PASS` and `[t_server_domain] PASS`
(exit 0), `[tests] PASS` (run_all, exit 0), `SMOKE PASS` (smoke --no-import, exit 0).

## Review fixes (2026-10-19)

| Finding | Fix | Caught by |
|---|---|---|
| blocker: 15 unowned `.uid` files in `00c5d17` | `git rm --cached` in `79568aa` (no history rewrite) | `git show --stat` |
| major: `char.move` cap per update | one-second distance budget (`move_cm`, whole cm so the snapshot round-trips bit-exact) | `move budget` line |
| minor: no gather/attack time gate | recorded as a W3-SRVACT item (integrator hooks); whole-second `ts` cannot express a swing period | n/a |
| minor: invalid rid ignored | `bad_request` when `rid` is present but not a 1..64-char string | `rid invalid` line |
| minor: default `world_seed` 1 | argument now required, secrecy documented | compile (all callers pass it) |
| minor: `seed_global` | shortcut kept; made a W3-SRVWORLD precondition (hooks) | n/a |
| minor: replay under new data | `close()` snapshots; snapshot stores `data` hash; boot sets `data_changed`, warns, re-snapshots | `disk` line |
| minor: `class_name` on test harness | dropped | t_srvdom loads it by path |
| minor: uid rule vs W1-ITEMS | recorded in integrator hooks | n/a |
| minor: deposit loses asset on vault refusal | server-only `char.receive {asset}` | `receive` line |

After the fixes: `[t_srvdom] PASS`, run_all `[tests] PASS`, `tools/smoke.sh --no-import` `SMOKE PASS`.
