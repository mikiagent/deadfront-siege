# W1-SRVDOM: server character store and intent handlers

Branch `claude/mmo-w1-srvdom` (cut from `claude/mmo-overhaul` at `ea2d167`; `claude/mmo-overhaul`
`4cbc117` merged in at `4803641` and `cdb2c16` at `08f8583`, both with no conflicts). Pure domain code, no networking, no nodes, no
autoloads. Credits spent: 0 (Meshy, Tripo). dsc spend: see "dsc usage".

## What shipped

All new, in `game/scripts/server/`:

| File | What it is |
|---|---|
| `character_store.gd` (`CharacterStore`) | Server-owned characters (contract v2 §0.1) with the economy engine's durability: `apply(op, account, args, ts)`; a change bumps `seq`, appends one canonical JSON line to `journal.jsonl` and flushes before returning. Snapshot = canonical state JSON written to `.tmp`, read back, renamed. Boot = snapshot, then journal lines with `seq > snapshot.seq`; a torn last line is cut, a seq gap or bad middle line stops boot. Memory mode (`dir == ""`) keeps the journal in `lines`. Also: optional `rid` idempotency (64 per character), an error-counting `Logger` that rolls the character back if an op hits a script error part-way, `invariants()`, `state_json()` / `state_hash()`. |
| `character_state.gd` (`CharacterState`) | One character as plain data: bag (20 slots), equipment and gather tool by uid, wallet mirror, pets by uid, skills `{tree: {level, xp}}`, position. `inventory()` builds a real `Inventory` over a deep copy; `commit()` writes it back. Stacks that were already in the bag keep their stamp; every new stack gets `uid`, `origin`, `seq`. |
| `intent_handlers.gd` (`IntentHandlers`) | One handler per intent, each validating everything before it mutates: `act.gather`, `act.loot`, `act.craft`, `act.place`, `act.equip`, `act.eat`, `act.tame`, `act.capture`, `act.attack`, `act.deposit`, plus `char.import` (always `invalid_asset`), `char.get`, and the server-only `char.create`, `char.move`, `char.wallet`, `char.receive`, `char.settled`. `ARG_KEYS` lists the keys each op reads; `CharacterStore.apply()` drops every other key before the op runs and is journaled. They run the game's own `Inventory`, `Crafting` (plan, `consume_for_craft`, `build_output`), `Food`, `PetRecord.from_def`, `CreatureGenetics.roll(rng)`, `ProgressionScaling`, `FieldTame` thresholds and `CaptureSystem.TIER_BASE`. |
| `world_facade.gd` (`WorldFacade`) | What the handlers may read from and write to the island. The base class is a plain in-memory island (tests, the fuzz); W3-SRVWORLD subclasses it over `IslandRuntime`. |
| `server_rng.gd` (`ServerRng`) | The server's only randomness: one `RandomNumberGenerator` per op, seeded with sha256 of `world_seed:seq:op`. (The finishing pass deleted `seed_global`: crafts now burn through `Crafting.rolls_burn(rec, skill, rng)` on the op's RNG, so the process-wide RNG is never touched.) |
| `provenance.gd` (`Provenance`) | `uid` / `origin` / `seq` stamping, origins `gather loot craft tame breed settlers objective market`, `is_server()`. |
| `game/tests/srvdom_checks.gd` (no `class_name`; was `scripts/server/domain_checks.gd` until the finishing pass) | The acceptance checks. The test loads this script by path on its first frame, once the `Data` autoload exists. It lives under `tests/`, which every export preset excludes, so it no longer ships. |

Tests: `game/tests/t_server_domain.gd` (the spec name, prints `[t_server_domain] PASS`) and
`game/tests/t_srvdom.gd` (the wave-1 runner's name; it extends the first and prints `[t_srvdom] PASS`).

How replay works without the island: every world read goes through `IntentHandlers._read()`,
which records the answer. The journal line stores those answers as `w` beside `{seq, ts, account,
op, a}`. On replay the handlers get the recorded answers back and skip world writes, so the
characters rebuild from the journal alone. Args and world answers pass through canonical JSON
before the live op sees them, so live and replay see the same numbers.

## Acceptance checklist (each line seen in the runs below)

Runs on the final code (`08f8583`, after the second base merge; logs `scratchpad/w1/srvdom/*7.log`):
`perl -e 'alarm 300; exec @ARGV' gslot.sh Godot --headless --path game -s res://tests/t_srvdom.gd`,
the same for `t_server_domain.gd`, `--script res://tests/run_all.gd` (alarm 900) and
`gslot.sh tools/smoke.sh --no-import`. All four exit 0, with no `SCRIPT ERROR` or `Parse Error` lines.
Every `[srvdom]` line below is from `t_srvdom7.log`; apart from the fuzz's `ms=` they are identical
to the run on `70bd87c` before that merge.

- [x] `t_server_domain.gd` prints `[t_server_domain] PASS`; `t_srvdom.gd` prints `[t_srvdom] PASS`.
- [x] A gather on a node 1.5 m away with pool > 0 mints a stack with uid, origin=gather and the
  journal seq. Out of range, an empty pool and a missing tool each return their own code, and the
  canonical state hash and journal length stay the same:
  `[srvdom] gather uid=i4.0 origin=gather seq=4 count=4; refusals far:out_of_range:unchanged=true bare:depleted:unchanged=true ore:missing_tool:unchanged=true nope:not_found:unchanged=true`
  The check also confirms the last journal line is that gather at that seq, and that the node lost one unit.
- [x] Craft consumes exactly the planned inputs (`Crafting.slot_level_contributions` before
  vs. bag delta after) and mints a uid'd output with origin=craft. Refusals change nothing:
  `[srvdom] craft twine planned={ "fibre_stalk": 2 } used={ "fibre_stalk": 2 } output=i10.0 origin=craft seq=10; club dur=60; refusals insufficient_items,insufficient_items,out_of_range unchanged=true`
- [x] Tame draws on the server RNG, so the same journal gives the same genetics. Two independent
  runs and a replay of the journal all produce the same pet:
  `[srvdom] tame pet=p9.0 origin=tame seq=9 grade=C+ genetics_equal_runs=true genetics_equal_replay=true ivs={"accuracy":2,"health":0,"melee_attack":18,"melee_defense":27,"ranged_attack":0,"ranged_defense":1,"speed":30}`
  A tame on a creature that is not knocked out below 30 % returns `not_ready` and changes nothing.
- [x] 10,000-op seeded fuzz over 3 characters, covering every intent with valid and invalid
  args. After every op it checks: minted - consumed - exported == units held for each def, no
  negative counts, every uid in exactly one container (bags and pets), every stack and pet stamped,
  and equipment pointing only at bag uids. Every failed op left the canonical state byte-identical:
  `[srvdom] fuzz ops=10000 seq=3230 ms=11731 held_units=686 pets_minted=6 invariants=held_after_every_op stats={"act.attack":[835,273],"act.capture":[2,311],"act.craft":[408,777],"act.deposit":[204,365],"act.eat":[93,635],"act.equip":[115,556],"act.fly":[0,94],"act.gather":[570,2422],"act.loot":[149,354],"act.place":[32,272],"act.tame":[69,458],"char.import":[0,88],"char.move":[750,61],"char.wallet":[102,5]}`
  (`[ok, refused]` per op; the test fails if any intent except `act.capture` never succeeds. Since
  the finishing pass, capture's success path has its own scripted check, so a change to capture odds cannot
  turn the fuzz into a failure that says nothing.) The `ms` value is wall time on a shared machine.
- [x] Replaying the journal from empty, against an empty island, reproduces byte-identical canonical JSON:
  `[srvdom] replay lines=3230 byte_identical=true bytes=62138 sha256=ceaa5b7f4d51cb2a`
- [x] An offline save dict offered as an import or deposit returns `invalid_asset`. The cases
  are the real `tests/fixtures/save_v2.json` as `char.import`, a forged `raid_helm x5000 L9999`
  `slot_dict`, a forged T. rex `pet_dict`, and a slot deposit carrying an `item` dict. A slot
  deposit of a server stack hands over a stamped asset:
  `[srvdom] offline import/deposit dicts -> invalid_asset,invalid_asset,invalid_asset,invalid_asset unchanged=true; slot deposit uid=i5.0 origin=gather`
- [x] Extra: durability. A crash (no shutdown snapshot) boots from snapshot plus journal to the live
  state; a clean `close()` snapshots with the data hash and empties the journal; a torn tail is cut;
  a snapshot taken under other data files sets `data_changed` and is re-snapshotted:
  `[srvdom] disk seq=46 crash_replay_lines=6 reopen_equal=true clean_close_snapshot=true torn_tail_cut=true data_change_flagged=true wrong_seed_refused=true early_wrong_seed_refused=true apply_before_open=server_error orphan_journal_refused=true`
  (round 2 also: a boot with another world_seed is refused, before and after the first automatic
  snapshot; genesis is snapshotted by `open()`; `apply()` before `open()` is `server_error`; a
  journal with no snapshot is refused)
- [x] Extra: a repeated rid applies once, and reusing it for another op is a conflict:
  `[srvdom] rid repeat duplicate=true seq_unchanged=true other_op=conflict first_seq=4`
  and a present but unusable rid (65 chars, an int) is refused with nothing applied:
  `[srvdom] rid invalid long=bad_request int=bad_request unchanged=true`
- [x] Extra: `char.move` keeps one second's distance budget across all updates in that second
  (the reviewer's probe of ten 12 m hops at one ts now accepts 1; twenty 1 m hops accept 12):
  `[srvdom] move budget bound=12.2 same_second_12m_accepted=1/10 same_second_1m_accepted=12/20 next_second=true reset=true teleport_after_idle=bad_request`
  (idle time banks at most 2 s, so 5000 m after 999 s of silence is refused)
- [x] Extra: `char.receive` takes back only the exact body `act.deposit` recorded under that uid,
  once (the reviewer's three probes: same asset twice while other units of the def are exported,
  an edited level, a forged pet with a fresh uid after a real pet export; the real pet still returns):
  `[srvdom] receive item=true restored=true twice=invalid_asset forged=invalid_asset unstamped=invalid_asset pet=ok pet_twice=conflict same_def_first=ok same_def_second=invalid_asset edited_level=invalid_asset forged_pet=invalid_asset real_pet_back=ok`
- [x] Extra: world writes are queued and land only when the op commits:
  `[srvdom] world writes queued_untouched=true uncommitted_dropped=true committed_landed=true`
- [x] Extra (finishing pass): a scripted capture. Craft a tier-1 net, refuse an awake compy, knock it under
  30 % and throw until it lands; the bag gets a stamped `captured_animal`, the net is spent and the
  creature leaves the island:
  `[srvdom] capture throws=2 captured=true stack=i11.0 origin=tame net_spent=true awake_refused=not_ready`
- [x] Extra (finishing pass): the review probes. Non-bool `clear` / `reset` are `bad_request`; a gather with a
  200 KB junk key commits a 242-byte journal line without it; `char.settled` drops the export record,
  so a later `char.receive` is refused; melee follows `combat_tuning.json` (a forced dodge misses, and
  `unarmed_damage` set to 20 in the loaded tuning gives exactly the formula's damage):
  `[srvdom] hardening flags=bad_request,bad_request,bad_request junk_dropped=true journal_line_bytes=242 settled=true receive_after_settle=invalid_asset settle_twice=not_found forced_dodge=dodge unarmed20_dealt=19.69 want=19.69`
- [x] Extra (finishing pass, table written by dsc): 153 hostile requests across all 16 non-read ops (wrong
  types, missing keys, 1.5, negatives, out-of-range ints, 65-char strings, NaN/INF positions,
  asset dicts), each refused with its literal code, with the state hash, journal length and
  script-error count unchanged; then `known_args` keeps exactly `ARG_KEYS` plus `rid` for all 17 ops:
  `[srvdom] hostile rows=153 ops_covered=16 matched=153 script_errors=0 unchanged=true allowlist_ops=17`
  (The NaN/INF rows print two engine WARNINGs from `JSON.stringify`, which replaces them with null;
  they are warnings, not errors, and the request is still `bad_request`.)
- [x] Existing suite: `--script res://tests/run_all.gd` printed `[tests] PASS` (exit 0, `run_all7.log`).
  It also prints Godot's exit-time `resources still in use` ERROR lines, which come from the base
  suite at shutdown, not from a test.
- [x] `gslot.sh tools/smoke.sh --no-import` printed `SMOKE PASS` (exit 0, `smoke7.log`).
- [x] No Godot crash: `~/Library/Logs/DiagnosticReports/` held 25 `Godot-*` reports before this
  pass's first run and 25 after the last.

## Screenshots inspected

None. The package draws nothing: it is headless domain code with no scene, UI or lab. So no
1600x900 or 390x844 shots apply, and I make no claims about appearance.

## Assumptions (`# ASSUMPTION:` in code)

1. New intent error codes beyond contract §2: `out_of_range`, `depleted`, `missing_tool`,
   `bag_full`, `not_ready` (`intent_handlers.gd:9`). Placement refusals use `conflict`; offline
   dicts use `invalid_asset`.
2. Online characters start with an empty bag and level-0 skills; nothing is imported (`character_state.gd:17`).
3. `REACH_SLACK` 0.5 m on top of a creature's body reach (`Hunt.melee_reach`'s formula) for attack,
   tame and capture. It is a server latency allowance and deliberately wider than the client's own
   swing check (`combat_tuning.json` `hit_reach_slack_m` 0.3), since the server judges a position
   one presence update old.
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
melee only, never "from behind", and no attacker or target statuses (`accuracy_mult`,
`defense_mult`); kits only for placement (no
branch+twine fallback); skill points and unlocked nodes stay client-side; the in-memory island
treats one structure as one cell.

## Integrator hooks

- **Tests:** register `game/tests/t_server_domain.gd` in `run_all.gd`, or let W1-QA's runner pick
  up every `t_*.gd`. `t_srvdom.gd` runs the same checks under the wave-1 name, so a `t_*.gd` glob
  runs the suite twice (about 15 s each on a loaded machine). Keep one in the glob: skip
  `t_srvdom.gd` there, or delete it once the wave-1 runner no longer names it.
  `game/tests/srvdom_checks.gd` is the shared check script (no `class_name`, not a runner).
- **No edits needed** in `game.gd`, `main.gd`, `world.gd`, `project.godot` or `touch_controls.gd`.
- **Contract §2 / §0.3** (orchestrator): add the five error codes above. Record the intent ops
  `act.capture {net_id}`, `act.deposit {bag_slot, count?} | {pet_uid}`, `char.import` (refused),
  `char.get`, and the server-only `char.create {name}`, `char.move {p, reset?}`,
  `char.wallet {wallet}`, `char.receive {asset}`, `char.settled {uid}`. Journal lines carry an
  extra `w` (world answers). `clear` and `reset` must be JSON booleans.
- **Adding an op or an arg:** list every key the op reads in `IntentHandlers.ARG_KEYS`.
  `CharacterStore.apply()` drops unlisted keys before the handler sees them, so a key missing
  there is silently ignored (the hostile table's allow-list check covers the existing 17 ops).
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
  refuses a deposit or on a withdrawal. `act.deposit` records each exported asset in
  `s.exported_assets[uid] = canon(body)`; receive needs that uid with a byte-identical canonical
  body, then erases the entry. A pet uid already held is a `conflict`. The vault must hand back
  the asset unchanged (no re-stamping, no added fields).
- **Integration trap (W3):** assets the economy mints itself (origins `market`, `settlers`,
  `objective`) have no `exported_assets` entry, so `char.receive` refuses them. W3 needs an explicit
  server-only economy-mint op (for example `char.grant {asset}` called by the ledger after its own
  mint, which also bumps `minted`/`pets_minted` so the invariants hold). Not built here: no
  economy mint path exists in this package to test it against.
- **`CharacterStore.new(world, dir, world_seed)`**: `world_seed` is now required. W3 must pass a
  random, persisted, secret seed per world; anyone who knows it can predict capture, crit and
  genetics rolls for any seq.
- **Boot:** call `open()` before `apply()` (a disk store refuses ops until then). A fresh `open()`
  snapshots genesis at once, so `world_seed` is always on disk; a later boot with another seed, or
  a journal with no snapshot, returns an error and must stop boot.
- **Shutdown:** call `close()` on clean shutdown (it snapshots). After `open()`, `data_changed`
  tells the host that the journal replayed under different data files (items, recipes,
  combat_counters, combat_tuning, world/rules); boot then snapshots at once.
- **Process RNG:** nothing in this package touches the global RNG any more (`seed_global` is gone;
  crafts burn via `Crafting.rolls_burn(rec, skill, rng)` on the op RNG), so the island's AI can share
  the process. The old W3-SRVWORLD precondition is closed.
- **W3-SRVWORLD `creature()` read:** report `dodge` as the creature's effective dodge
  (`dodge_chance()` + status `evasion_add()` x `evasion_add_scale`), the number `Hunt.hit_chance`
  uses, and `defense` as `defense_for(false)` x status `defense_mult()`. `act.attack` feeds them to
  `CombatTuning.hit_chance(base_accuracy, dodge)` and the `player_melee` formula as they arrive.
- **Vault bridge (W3):** call `char.settled {uid}` once the economy keeps an exported asset for
  good (sold, consumed, destroyed). That drops its `exported_assets` record, so the registry (which
  every snapshot carries and every op backs up) holds only assets in flight. Until then a vault
  that never settles grows it by one entry per deposit.
- **W3-SRVACT item:** gathers and attacks have no domain time gate (a probe accepted 200 attacks at
  one ts); only the §5.4 write bucket limits them. `ts` is whole seconds, too coarse for a swing
  period, so W3-SRVACT adds `last_gather_ts` / `last_swing_ts` with sub-second server time.

## Labs to register

None.

## What failed or is left

Nothing in the acceptance list failed. Left for later packages:
- Ranged attacks (ammo, projectiles), the from-behind bonus, groggy/counter statuses, attacker and
  target status multipliers (`accuracy_mult`, `defense_mult`) and weapon wear in combat: W3-SRVACT.
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

## Review fixes, round 2 (2026-10-19)

| Finding | Fix | Caught by |
|---|---|---|
| major: `char.receive` is a mint path (forged pet, edited level, double receive) | per-uid registry `exported_assets` of canonical bodies, written by `act.deposit`, matched exactly and erased by `char.receive`; per-def/global counter checks dropped from receive (counters stay for the invariants) | `receive ... same_def_second=invalid_asset edited_level=invalid_asset forged_pet=invalid_asset real_pet_back=ok` |
| minor: idle time banks move distance | `elapsed` capped at 2 s | `move budget ... teleport_after_idle=bad_request` |
| minor: world_seed only in memory before the first snapshot | `open()` snapshots genesis; boot refuses a seed mismatch and a journal with no snapshot | `disk ... wrong_seed_refused=true early_wrong_seed_refused=true orphan_journal_refused=true` |
| minor: `apply()` before `open()` crashes | `server_error` "call open() first" | `disk ... apply_before_open=server_error` |
| minor: error rollback leaves world writes | `_write` queues; `CharacterStore._run` calls `handlers.flush()` only after the op commits; `begin()` clears the queue | `world writes queued_untouched=true uncommitted_dropped=true committed_landed=true` |
| minor: economy-minted assets cannot come back | recorded as an integrator hook (economy-mint op for W3) | n/a |

Not covered by a test: the world-write check drives the queue directly rather than through a real
mid-handler script error, since no handler can be made to error on demand. Old snapshots without
`exported_assets` would fail to load deposits back; none exist outside tests (unmerged branch).

After the fixes (logs in `scratchpad/w1/srvdom/`): `t_srvdom2.log` `[t_srvdom] PASS` (exit 0),
`run_all2.log` `[tests] PASS` (exit 0), `smoke2.log` `SMOKE PASS` (exit 0).

## Merge check against `claude/mmo-overhaul` (round 3, 2026-10-19)

`claude/mmo-overhaul` moved on (W1-TAME, W1-ITEMS, W1-AI merged; tip `773a975`). `git merge-tree`
merges this branch into it with no conflicts. I exported that merged tree to
`scratchpad/w1/srvdom/merge-trial/` (`git archive`, no ref or worktree created), imported it and ran
`t_srvdom.gd` there. Two breaks showed up that only exist after the merge:

| Break after merge | Cause | Fix |
|---|---|---|
| `[t_srvdom] FAIL journal replay from empty reproduces byte-identical canonical JSON (57727 vs 57727 bytes)` | W1-TAME's `PetRecord.from_def` sets `tamed_at` from the wall clock | committed here: `act.tame` sets `tamed_at` to the op's ts and `owner` to the account (`intent_handlers.gd` `_tame`); on this branch the two keys are just extra pet fields |
| server crafts never burn (no test fails) | W1-ITEMS moved the burn roll out of `build_output` into `Crafting.rolls_burn(rec, skill, rng)` | post-merge integrator edit (below); the API does not exist on this branch's base |

With both applied, the merged tree prints `[srvdom] replay lines=3231 byte_identical=true bytes=57706 sha256=fb23de558588714e`
and `[t_srvdom] PASS` (exit 0, `trial_t_srvdom2.log`, no SCRIPT ERROR lines).

**Integrator hook (post-merge, `game/scripts/server/intent_handlers.gd` `_craft`)** (applied in
the finishing pass after the base merge brought W1-ITEMS in; kept here for the record): replace

    ServerRng.seed_global(int(s.world_seed), seq)
    var out := Crafting.build_output(rec, consumed[0], level, consumed)

with

    var out := Crafting.build_output(rec, consumed[0], level, consumed, Crafting.rolls_burn(rec, ch.level_of(tree), rng))

then delete `ServerRng.seed_global` (no other caller). That also clears the W3-SRVWORLD
precondition above. Seen after the merge but not a failure: `act.capture` succeeded 1 time in 10,000
fuzz ops (6 on this branch); the fuzz requires at least one success per intent, so a later tuning
of capture odds could make that check flaky. Raise the fuzz's captures or seed more knocked-out
creatures if it does.

After the fix, on this branch (`*3.log`): `[t_srvdom] PASS`, `[t_server_domain] PASS`, run_all `[tests] PASS`,
`tools/smoke.sh --no-import` `SMOKE PASS`, all exit 0, no SCRIPT ERROR or Parse Error lines.

## Finishing pass (2026-10-20)

Base sync: merged `claude/mmo-overhaul` at `4cbc117` (`4803641`) and again at `cdb2c16` (`08f8583`),
both with no conflicts. Before the first merge, 65 untracked editor-made `.import` files in the work
tree blocked it (the base now tracks them). I moved them to `scratchpad/srvdom-untracked-backup/`
rather than deleting them, and the merge brought the tracked versions. One `--import` (alarm 900)
ran after the merge. After the second merge, `git merge-tree` against `claude/mmo-overhaul` shows
no conflicts.

Review findings from `finish/srvdom-last-review.json` (round 1 passed at `dee1bbe`; all seven were minors):

| Finding | Fix | Caught by |
|---|---|---|
| melee keeps hard-coded copies of `combat_tuning.json`; the file is not hashed | `_attack` reads `CombatTuning.section("player_melee")` (unarmed damage, work-tool mult, defense factor, min-damage fraction, per-level damage, crit base, per-level crit, crit mult, XP per hit) and rolls `CombatTuning.hit_chance(base_accuracy, dodge)` on the op RNG. `combat_tuning.json` joins `DATA_FILES`. `REACH_SLACK` 0.5 stays as a stated server latency allowance (assumption 3). | `hardening ... forced_dodge=dodge unarmed20_dealt=19.69 want=19.69` |
| `bool()` on client JSON (`clear`, `reset`) is a script error | both must be real bools, else `bad_request` | `hardening flags=bad_request,bad_request,bad_request`; hostile rows |
| `exported_assets` grows forever | server-only `char.settled {uid}` drops a record once the economy keeps the asset (hook above) | `hardening ... settled=true receive_after_settle=invalid_asset settle_twice=not_found` |
| the whole args dict is journaled, junk included | `IntentHandlers.ARG_KEYS` per op; `apply()` keeps only those plus `rid` before running and journaling. Args that do not survive JSON (NaN, INF) still become `{}`. | `hardening ... junk_dropped=true journal_line_bytes=242`; `hostile ... allowlist_ops=17` |
| fuzz needs a capture success it gets about once in 10,000 ops | capture removed from the fuzz's must-succeed list; new scripted `_capture_checks()` | `capture throws=2 captured=true ...` |
| test code in `scripts/server/` ships in exports; two runners | `git mv` to `game/tests/srvdom_checks.gd` (`tests/*` is in every preset's `exclude_filter`). The duplicate runner is an integrator hook: W1-QA's glob is not on the base yet, and both names are acceptance items. | `t_server_domain.gd` loads the new path |
| `seed_global` reseeds the process RNG; server crafts never burn after W1-ITEMS | `build_output(..., Crafting.rolls_burn(rec, ch.level_of(tree), rng))`; `ServerRng.seed_global` deleted (no other caller) | replay stays byte-identical |

Also changed in this pass:
- `act.deposit {pet_uid: <non-string>}` is `bad_request` (it was `not_found`). The dsc table found it.
- `t_server_domain.gd` prints `FAIL ... did not compile` and exits 1 when `srvdom_checks.gd` has a
  parse error. Before this, a parse error printed a SCRIPT ERROR and the run still exited 0 with no
  PASS line. I hit that while writing this pass's checks.

Not done: the per-op rollback backup still copies `exported_assets` (the reviewer's other option).
With `char.settled` in use, that dict holds only assets in flight, so the copy stays small.

### dsc usage

One dsc worker (DeepSeek V4.1 Flash via `dsc cook start TASK.md --once --verify ./verify_hostile.sh
--budget 2 --max-hours 4 --effort high`), in sub-worktree `mmo-w1-srvdom-dsc1` on branch
`claude/mmo-w1-srvdom-dsc1`, cut from `96b41ed`. It ran for about 5 minutes and spent about $0.03 of
the $2 budget. Its task was the mechanical part of this pass: the table-driven hostile-args check
(`HOSTILE`, 153 one-line `[op, args, literal code]` rows, and `_hostile_arg_checks()`).

The read-only verify script was the spec. Scope: only the test file may change. The table must be
literal, with at least 60 one-line rows, at least 3 per op and never `server_error`. The suite must
PASS with the evidence line's counts (16 ops, all rows matched, 0 script errors, state unchanged,
17 allow-list ops) and every earlier `[srvdom]` line intact. A mutation run then flips the first
row's expected code to `zz_mutant`, and the suite must FAIL; this proves the rows are really
compared.

I ran the verify myself on its commit `61f55fc`. Every check held except the scope check, which
flagged `verify_hostile.sh` itself: dsc's commit had swept the untracked TASK.md and verify script
in, and my scope check did not exempt its own file. The content was unchanged (`cmp` against the
committed copy, mode 555, same size), so I stopped the worker and took only
`game/tests/srvdom_checks.gd` (`git checkout claude/mmo-w1-srvdom-dsc1 -- <file>`, commit `97f8dc6`).
The TASK.md and verify script stay out of the branch. Its commit message also lacked the dsc
trailer; my commit carries both trailers.

My changes to its diff, in `70bd87c`:
- the `{pet_uid: 5}` row now expects `bad_request`, and I fixed the handler to match;
- I dropped a meaningless `not got.has("missing")` clause from the allow-list check.

dsc reported no handler bugs. I re-read every row against the handlers and agree with each
expected code.

### Labs, screenshots

None. This pass is headless domain code: no scene, UI or lab, so I took no screenshots and make
no visual claims.

### Note for the orchestrator

The user request relayed with this run was about making trees partly see-through (camera
occlusion). That is not part of W1-SRVDOM, so this package changed nothing for it.
