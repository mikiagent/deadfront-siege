# claude-mmo-net: network core

Branch `claude/mmo-net`. Spec: `docs/orchestration/mmo/contracts.md` sections 0 (v2), 1, 2, 3, 5.3, 5.4 and 7.
How to run it: `docs/orchestration/mmo/net-runbook.md`.
Integrator hooks: `docs/orchestration/reports/claude-mmo-net-hooks.patch` (`world.gd`, `shell/boot.gd`).
Commits: `9e80261`, `26dd455`, `baf5f72` (first pass), `4b8ec30` (review 1 fixes), `b40a1e6`
(review 2 fixes), `ff81acb` (merge of `claude/mmo-overhaul` at `de73f92` plus the adaptation),
`9ded4e4`, `71a77aa`, `4621f4b` (merge of the base at `29ffa29`: W2-SKILLS), `317d225` (merge of
`e5f3ec8`, docs only), plus this report. The branch contains `claude/mmo-overhaul` up to `e5f3ec8`.

## Sync with claude/mmo-overhaul (2026-10-20, NET+CHAT run)

The branch was 465 commits behind. `git merge de73f92` (the base head when I started; it moved
three docs-only commits past `c5c920e` during the run) had **no textual conflicts**, so nothing
of the base was dropped or reverted. While the gates ran the base merged W2-SKILLS (52 commits,
including `character_state.gd` and `intent_handlers.gd`) and then one docs commit; both merged in
cleanly too, and every gate was run again on that tree (below). The work was semantic: the base split the player (W2-PLAYER)
and added the server character domain (W1-SRVDOM), and the network code had to follow.

| Change | Why | Test that fails on the old behaviour |
|---|---|---|
| `remote_puppet.gd` takes `SURVIVOR_JSON`, `SURVIVOR_BASE_GLB`, `SURVIVOR_ANIM_DIR` and `web_safe_mesh()` from `PlayerView` | The split moved them off `Player`; the merged branch did not compile. Reusing `PlayerView.web_safe_mesh` deleted the puppet's copy of it. | `net_checks.gd` "the puppet reuses the survivor rig and clips". The unadapted merge names `Player.SURVIVOR_BASE_GLB`, which `player.gd` no longer has (found by grep; I fixed it before the first run, so no failing run was seen). |
| `PresenceSender` reads `PlayerRegistry.local()` every tick; it no longer holds a `Player` | W2-PLAYER made the registry the one answer to "which survivor"; `main.gd` passes nothing now. Puppets are plain `Node3D`s, never in the `player` group, so AI, credit and `local()` never see them. | NET SMOKE (`instance=1` and `puppets=1` on both probes). |
| **Area caps.** `presence.join {island, instance?}`; a public island room is one instance of at most `max_players_area` players (`rules.json`, 30). A full instance answers `limit_reached`, the message `"desert_35 instance 1 is full (2/2 players); join instance 2"` and `r.next_instance`. Without an instance (and on the implicit join of `presence.update`) the server takes the player's current instance of that island, else the first with room. The answer is `{island, instance, players, max_players}`. Presence and chat are per instance. A player switching instance gets `presence_leave` for every roommate left behind, so the client drops their puppets. `PresenceSender` remembers its instance and asks for it again after a reconnect; on `limit_reached` it takes `next_instance`. | Contract §7 (owner rule 2026-10-19). | `_test_area_caps`: cap read from `rules.json`; third join refused with reason and `next_instance == 2`; fractional and out-of-range instance `bad_request`; an auto join lands in instance 2; instance 1 neither sees nor hears instance 2; switching instance delivers `presence_leave`; `PresenceSender` takes the offered instance. Old code: the third join returned `ok` with `players: 3`. |
| `max_creatures_area` (`rules.json`, 24 = today's `creature_cap_mobile`) | Contract §7: creatures per area are capped. In v1 the client simulates its island, so the hooks patch makes `World` set `Game.max_creatures_per_island = min(creature_cap_mobile, max_creatures_area)`, which the island spawner already honours. Released animals (W2-CAGE) and the server's spawner (W3-SRVWORLD) must check the same number. | None of its own: no behaviour changes at 24. |
| **Server-owned characters on the socket** (`net_characters.gd`, new). The server opens W1-SRVDOM's `CharacterStore` in `<data>/chars` under a secret 48-bit world seed kept in `<data>/world_seed` (JSON keeps integers exact only below 2^53). The first hello runs `char.create`; later hellos find the character. `IntentHandlers.CLIENT_OPS` are registered as ops (`char.get` read; `act.*` and `char.import` mutating, `write` class) and relayed into `store.apply()` with the envelope rid copied into `a.rid`, so the store's own rid record also covers a crash between its journal and `rids.jsonl`. `SYSTEM_OPS` are never registered. Before each intent the last position presence accepted is committed with `char.move {reset: true}` (presence already speed-checked every update; committing each 10 Hz update would journal ten lines a second per player). The island is an empty in-memory `WorldFacade` until W3-SRVWORLD (`shortcut:` in code). | Contract v2 §0.1, §0.3, §0.4, and W1-SRVDOM's handoff ("char.create on hello, char.move from accepted presence, relay only CLIENT_OPS"). | `_test_characters`: the hello made the character (`char.get`); `char.import` is `invalid_asset`; `char.wallet` and `char.move` from a client are unknown ops; a gather before any presence is `out_of_range`, after `presence.update` next to the rock it runs on the server's copy; a repeated rid answers the same and gathers once (9 left of 10); the stone is in the server's bag; the bag survives a store close and reopen. NET SMOKE: each probe reads its own character back over the socket (`char=<name>`). |
| `NetProtocol.ERR_CODES` gains `out_of_range`, `depleted`, `missing_tool`, `bag_full`, `not_ready`; a failure may carry `r` (`fail(code, msg, r)`, `res_frame`, `NetRequest.finish`) | The domain returns those five codes; `is_result` turned them into `server_error`. `limit_reached` must name the next instance (§7). Both are `# ASSUMPTION`s for the orchestrator to add to contract §2. | `_test_characters` (`out_of_range`), `_test_area_caps` (`next_instance`). |
| `net_tests.gd` is a standalone runner; the checks moved to `net_checks.gd` | `run_all.gd` is integrator-only, so the branch's edit there is gone (back to base). `--script` compiles the runner before autoloads exist, so it loads the checks on the first frame after `Data`, like `t_server_domain.gd`. It prints `[net_tests] PASS` or one FAIL line per check and exits 0 or 1. | n/a |
| Hooks patch | `world.gd` (skip `_boot` for `--server` and `--net-probe`, no autosave for probes, the creature cap above) and `shell/boot.gd` (load `server.tscn` for `--server`) are outside this package's grant (`game.gd`/`main.gd` only), so they left the branch and live in `claude-mmo-net-hooks.patch`. | NET SMOKE runs with the patch applied and fails if the server log shows the playfield. |

Mutation check: with the cap check, the character op registration and `PresenceSender`'s
`limit_reached` branch disabled at once, `net_tests.gd` printed `[net_tests] FAIL count=11`, among them
`a full instance refuses a join with the reason and the next instance ({ ... "ok": true, "r": { "instance": 1.0, ... "players": 3.0 } ...})`,
`act.gather runs on the server's copy at the position presence accepted ({ "err": "bad_request", ... "msg": "unknown op act.gather" ...})`
and `PresenceSender takes the next instance the server offers (instance 2)`. The files were
restored from a copy and checked byte for byte.

### What W1-INT still owes

- **The market over the socket.** ECON's report (`claude/mmo-econ`, section "Boot and per request")
  routes every client frame through `VaultBridge.client()`. This branch already has the seam:
  `NetServer.characters` (`NetCharacters`) owns the `CharacterStore` (`characters.store`, with the
  world seed and data dir set up). W1-INT builds `VaultBridge.new(econ, characters.store)` next to
  it, runs `bridge.recover()` at boot (refuse to start when it reports a stuck asset), replaces
  `NetCharacters._relay`'s `store.apply(...)` with `bridge.client(op, aid, args, now)` and
  `_on_online`'s `char.create` with `bridge.hello(aid, name, now)`, registers the economy's
  `CLIENT_OPS` (`market.*`, `vault.*`, `wallet.*`) with `register_op` (read or write class), and
  ticks `bridge.apply("sys.tick", 0, {}, now)` once a second from `NetServer._process`.
  `_relay` already copies the envelope rid into `a.rid`, which is what W3-EXCHANGE's
  `NetMarketClient` expects ("the relay copies it into a.rid"). ECON's hooks move `act.deposit`
  to `SYSTEM_OPS`; `NetCharacters` registers whatever `CLIENT_OPS` lists, so it follows.
- The client's `World.t_stones` mirror of the server wallet, `objective.claim` on server-observed
  state, and the econ store's journal replay calling `server.remember_rid()` (runbook §5).
- Contract §2 additions (five error codes, `r` on a failure) and the `presence` rate class (§5.4).

### Still not here (other packages)

- W3-SRVACT: `PlayerActions._send` still queues intents locally (its ids are local instance ids),
  so the game client plays its island offline-style even when online.
- W3-SRVWORLD: the server island. Until then every node, corpse and creature intent answers
  `not_found` and reach is checked against an empty world.
- The region chat screen (spec 20) is `claude/mmo-chat`'s; it builds on `chat.send` and `evt chat`,
  which are per instance now.

## What shipped

| File | What it does |
|---|---|
| `game/scripts/core/game.gd` | Parses `--server`, `--port=` (0-65535), `--data=` (absolute or `user://`), `--online=<ws url>` and `--net-probe`. On web it reads `?online=` from the page URL. `Game.net` is a lazy getter that adds a `NetClient` child to the Game autoload the first time something uses it. |
| `game/shell/boot.gd` (hooks patch) | With `--server` the shell loads `res://scenes/net/server.tscn` in place of `main.tscn`, so the island, player and HUD are never loaded. `main.gd` keeps a two-line fallback that swaps to the server scene if `main.tscn` is opened directly. |
| `game/scripts/core/world.gd` (hooks patch) | `_boot` is skipped for the server and for probes. `_save_now` is a no-op for probes. |
| `game/scenes/net/server.tscn`, `net_server.gd` | `TCPServer` plus `WebSocketPeer.accept_stream()`, polled in `_process`. Strict envelope parsing (64 KiB cap, text frames only, known keys only, integer `id`, op-name and `rid` patterns). Rate limits: before hello, per connection; after hello, per account, by class; plus a flood budget that closes sockets sending garbage. `register_op(name, handler, mutating, rate_class)`, where the handler takes `(account_id, a)` or `(account_id, a, rid)`. Mutating responses are saved under their `rid`. Results over 64 KiB become `server_error`, and oversize events are dropped and logged. Kicks the old connection (`evt kicked` plus close code 4003) on a second hello. Handshake, hello and idle timeouts. Slow readers are dropped instead of buffered. A heartbeat lock on the data dir. One JSON log line per connection event. |
| `rid_store.gd` | The last 64 mutating responses per account. Each is appended to `rids.jsonl` and flushed before the reply is sent; a write that fails (checked by file length, see review 2 #3) closes the store. The file is reloaded at start: a torn last line is dropped, any other bad line refuses to boot. It is compacted (tmp + rename) at open and whenever it reaches twice the cache size (at least 4096 lines). |
| `account_store.gd` | Identity only: id, name, `sha256(token)`, created. On each new account `accounts.json` is rewritten through tmp + rename, and the previous file is copied to `accounts.json.bak` first. A corrupt file refuses to open instead of starting empty. |
| `presence_rooms.gd` | One room per island instance (at most `max_players_area` players, see the sync section), and one per account for private home islands. A distance-budget teleport check (see below). 10 Hz batched `evt presence` carrying only states that changed. Newcomers get a snapshot of who is already there. `evt presence_leave` on leave or disconnect. |
| `net_chat.gd` | `chat.send` (rate class `chat`): strips every Cc, Cf, Co, Zl and Zp character, turns every other space and the blank fillers into a plain space, caps combining marks at 3 per base character, trims, refuses a line with nothing visible, allows 1-200 characters, and sends `evt chat {from, id, text, ts}` to the sender's room. |
| `net_protocol.gd`, `token_bucket.gd`, `net_request.gd` | Frame builders, error codes, strict int/number/vec3/name/token validators, uuid4, the token bucket, and the awaitable request (`req.rid`, `req.sent`). |
| `net_client.gd` | Connects and says hello with the token saved in `user://online_token.json` (keyed by server URL). A token is never deleted: a replaced one moves to `"lost"`, and a rejected one makes the client try the archived keys before it makes a fresh account. Name conflicts retry with a `-123` suffix. `request(op, a, timeout) -> NetRequest` (`await req.done`). `retry(req)` resends with the same `rid`. On reconnect, pending requests are resent with their `rid`, paced at 4/s burst 8, and requests made meanwhile queue behind them (except `presence.update`). A `chat.send` or `presence.update` that was already sent is not resent: it ends with `offline`. 15 s ping, 45 s silence timeout, exponential backoff with jitter. Signals: `state_changed` and `event` (server events, plus the client's own `kicked` and `token_rejected`). |
| `presence_sender.gd`, `remote_players.gd`, `remote_puppet.gd` | Sends position, world yaw and `PlayerAnim.current_clip` at 10 Hz, only while online and only when something changed. Puppets reuse `Player.SURVIVOR_BASE_GLB` and the clip folder through `RiggedModel`, with 100 ms interpolation, a snap past 15 m, a `Label3D` nameplate and a 6 s chat bubble. The client validates server data again. |
| `game/scripts/dev/net_probe.gd`, `tools/net_smoke.sh` | Multi-process smoke: one headless server and two headless `--net-probe` clients. The smoke now also fails if the server log shows the playfield loading. |
| `game/tests/net_tests.gd` (runner) + `net_checks.gd` | A real server and real clients over localhost sockets on a random free port, including a real server restart on the same port and data dir. Standalone since the sync; `run_all.gd` is untouched. |
| `net_characters.gd` | Server-owned characters on the socket (see the sync section). |

### Teleport check (contract section 7)

Run speed: `Player.run_speed = 7.0` (`game/scripts/player/player.gd:19`, not overridden in
`player.tscn`). The server reads it from the script with `get_property_default_value` and falls
back to the same constant. Rate: 1.6 × 7.0 = 11.2 m/s.

Each accepted update leaves a budget. The next update may move `carry + 11.2 × (time since the
last accepted update)`. The carry is capped at 3 s of running (33.6 m). The time term is not
capped, so a client that kept running through a long disconnect is accepted when it comes back.
Climbing counts like horizontal distance, and falling is free. `y` must stay within -20 to 30 m.
Islands are flat (heights about -2.6 to 4.5 m), nothing flies, and the fall guard re-seats anyone
below -15 m. The roll (13 m/s for 0.45 s) fits inside the carry.

## Review 1 fixes (independent review, 11 findings)

Every finding was accepted. For each: what changed, and the test that would have caught it.

| # | Sev | Finding | Fix | Test (`net_tests.gd`) |
|---|---|---|---|---|
| 1 | blocker | `rid` cache only in memory, wiped by a TTL sweep, and handlers never see the `rid` | `RidStore` persists every mutating response to `rids.jsonl` before the reply. The TTL is gone, so the cap is 64 per account and nothing else evicts. Handlers can take `rid` as a third argument. `server.remember_rid()` exists for the economy's journal replay. ~~A mutating op is refused with `server_error` while the store cannot write.~~ That claim was wrong: it held only after a failed compaction. Fixed in review 2 (#3). | `_test_restart`: the op applies, the server dies before answering, and a new server starts on the same port and data dir. Bob's NetClient resends the pending frame, gets the saved response, and the handler does not run (the reviewer's dupe scenario). An older `rid` also replays after the restart. `_test_rid_replay`: after `_sweep(now + 2 h)` the `rid` still replays. A 3-argument handler receives the `rid`. `_test_store_reload`: a torn last line is dropped; a bad line mid-file refuses to open. |
| 2 | major | Vertical moves were never checked | Climbing counts against the budget, falling is free, and `y` must stay within -20 to 30 m. | `_test_presence_rules`: `y` of 99000 and -99000 rejected; a 25 m climb passes; another 10 m climb with 8.6 m left is rejected; a 20 m fall passes. |
| 3 | major | Bunched frames rejected (`dt` ≈ 0, 0.5 m slack) | The distance budget with a 3 s carry described above replaces the slack. | 40 updates 0.7 m apart, delivered at once, all pass. A 7 m jump right after, with 5.6 m left, is rejected (the carry is capped). After 30 s without updates, a 200 m move passes (no freeze after a disconnect). |
| 4 | major | A timed-out mutating request cannot be retried safely | `req.rid` is exposed, and `NetClient.retry(req)` resends under the same `rid`. The docs say that `timeout` and `offline` mean the outcome is unknown. | `_test_client_retry`: an op applies, the server never answers, the request times out, `retry(req)` reuses the `rid` under a new id, and the server replays without applying again. |
| 5 | major | Responses over 64 KiB killed the socket (4004) and looped | After the handler, a result over `MAX_FRAME - 256` becomes `server_error` ("response too large") and is logged. Events over 64 KiB are logged and dropped. | A 200 KB read result gives `server_error`. A 200 KB `send_event` returns false. The same socket then still answers a ping. |
| 6 | minor | Island hops reset the check without any server-side travel | Not fixed in review 1. Partly fixed in review 2 (#4). | see review 2 |
| 7 | minor | The chat sanitiser missed U+00AD, tags, U+061C, and zalgo | All `\p{Cc}\p{Cf}\p{Zl}\p{Zp}` stripped, and combining marks capped at 3 per base character. | `_test_chat_clean`: the soft hyphen, U+061C, tag and isolate characters are stripped; 199 marks become 3; ordinary accented text is unchanged. |
| 8 | minor | The server instantiated `main.tscn` | The shell loads `server.tscn` directly, and `NetServer.autostart` (set in the scene) starts it from Game's flags. | `tools/net_smoke.sh` fails if the server log has `[boot] main scene ready` or any `[player]` line. A manual server boot printed neither. |
| 9 | minor | Reconnect resent chat (dupe) and flushed the backlog in one go (4005 loop) | An already-sent `chat.send` or `presence.update` ends with `offline` instead of being resent. The backlog drains at 4/s burst 8, under the 5/s burst 10 write class. | A chat already sent before a drop ends `offline` while a ping is resent and answered. A 20-request backlog made while offline finishes with 0 `rate_limited`. Unpaced, about 10 would be refused, because the write burst is 10. |
| 10 | minor | Persistence hardening | `accounts.json.bak`. A heartbeat lock on the data dir: `server.lock`, beat every 3 s, stale after 10 s. A corrupt file logs where the `.bak` is. No fsync: GDScript has none. O(N) rewrite per new account, with a `shortcut:` comment. | A second `NetServer` on the same dir gets `ERR_ALREADY_IN_USE`. `.bak` exists after account writes. |
| 11 | minor | `presence.update` used half the read budget | A new `presence` class: 12/s, burst 50 (a 5 s stall of 10 Hz frames). | Erin sends 30 presence updates, then 40 pings: all 70 are ok. |

The relay accumulator now subtracts the interval instead of resetting to 0. The change is
trivial, so it has no dedicated test.

A bug I found while fixing #1: `_handle` read `c.account_id` after the handler ran. A handler
that drops its own socket clears that field, so the `rid` would have been saved under account
-1. The account id is now captured before the call. `_test_restart` exercises this path, because
its handler drops the caller.

## Review 2 fixes (independent review, 10 findings)

I accepted all ten. #8 and #10 change no code: #8 is noted under Limits, and #10 is a request
to the orchestrator.

| # | Sev | Finding | Fix | Test (`net_tests.gd`) |
|---|---|---|---|---|
| 1 | major | On `unauthorized`, the client deleted the token and quietly made a new account | The token is never deleted. `_save_entry` moves any key it replaces to `"lost"` in the token file (newest 32 per server). On `unauthorized`, the client tries the archived keys newest first and only then makes a fresh account. It prints `[net] WARNING: ... rejected the saved token` and emits `event("token_rejected", {name})`. After the operator restores the data, the next connect finds the old account by itself. | `_test_token_kept`: a stale token falls back to a fresh account, emits `token_rejected`, and stays on disk under `"lost"`. Then the "restore": the current key is unknown and an archived one is known. The client signs back in to that account, and every refused key is still on disk. |
| 2 | minor | Requests made during the resend drain overtook the backlog and skipped its bucket | While `_resend` is not empty, `_submit` appends to it, so new requests are paced by the same bucket. `presence.update` is the exception: it is written at once, because at 10 Hz it would outrun the 4/s drain and the backlog would never finish. | 20 `test.order` ops are queued offline, and a 21st is made once online, while the backlog is draining. Applied order is `0..20` with no `rate_limited`. The old code applied `0..7, 20, 8..19`. |
| 3 | minor | The rid store was only fail-closed after a failed compaction | `remember()` closes the store when a write fails, so `NetServer` refuses later mutating ops with `server_error`. I also found the reviewer's suspicion is true, and worse: on a full disk (a 2 MB disk image, Godot 4.7.1 on macOS), `store_line()` returns true and `flush()` leaves `get_error()` at OK. Only `get_length() != get_position()` shows the bytes never landed. `NetProtocol.flushed(f)` checks that, and every writer uses it: `rids.jsonl` appends, rid compaction (before, a full disk could rename a short file over the real one), `accounts.json`, and the client's token file. | `_test_rid_write_failure` (read-only handle): the failing op's answer is still sent, the store closes, the next mutating op gets `server_error` without running, the failed rid still replays in-process, reads still work, and a reopened store takes writes. A manual run on a real full disk image: 11 rids acknowledged and 11 on disk after a reopen, the 12th refused, the store closed, and `accounts.json` and the token file intact. |
| 4 | minor | Island hops gave a free teleport (A, then B, then back to A anywhere) | The last accepted spot is kept per island. A return to an island is checked against where the player last stood there. A first visit still starts anywhere (contract section 7: travel resets). That leaves one free placement per island per 600 s, not one per hop. Server-side travel records still need the economy. | `_test_presence_rules`: tundra (0,0,0), then temperate at 900 m (accepted, first visit), then back to tundra at 900 m is rejected `moved too fast`, and 5 m from the old spot passes. |
| 5 | minor | Blank-looking chat: NBSP, U+3000, U+3164, U+2800, private use | Every `\p{Zs}` plus U+115F, U+1160, U+3164, U+FFA0 and U+2800 becomes a plain space before trimming. `\p{Co}` is stripped. A line must contain one character that is not a space, mark or control, so a line of only combining marks or variation selectors is refused too. I kept `\p{Cn}`: an unassigned code point draws a box, not a blank, and stripping it would eat emoji newer than the engine's Unicode tables. | `_test_chat_clean`: the invisible set leaves `""`, marks alone leave `""`, and edge spaces are trimmed while inner ones read as spaces. CJK and emoji are unchanged. End to end, Alice's invisible-only line gets `bad_request`. |
| 6 | minor | SIGTERM left `server.lock`, so a restart within 10 s exited 1 | I confirmed it: Godot runs no exit code on SIGTERM. An autostarted server now calls `start_when_free()`, which waits up to 13 s (stale time + one beat) for a dead server's heartbeat and then starts. A live holder still makes it exit 1. The runbook now says that Ctrl+C, `kill` and `systemctl stop` all leave the lock. | `_test_lock_wait`: a lock 8 s old refuses a plain `start()`, `start_when_free()` succeeds after waiting 1-10 s, and `stop()` removes the lock. Manual check: SIGTERM a server, start a new one at once on the same dir, and it was listening 9 s later. |
| 7 | minor | `$` matched before a trailing newline | Op, rid, token, name and clip patterns end in `\z`. | `"sys.ping\n"`, rid `"abcdefgh\n"`, clip `"idle\n"` and a token plus `"\n"` all get `bad_request`. |
| 8 | minor | Rid caches stay in RAM, and compaction stalls the main thread | Not changed for v1; see Limits. | none |
| 9 | minor | The probe's PASS line printed the current puppet count (0 once the other probe left) | It prints the count from the moment PASS was earned. | `tools/net_smoke.sh` output below: `puppets=1` on both. |
| 10 | minor | The `presence` rate class is not in contract 5.4 | **Request to the orchestrator:** add `presence` 12/s burst 50, for `presence.update` only, to contracts.md section 5.4. Without it, 10 Hz updates would use half of the `read` budget (20/s). I did not edit the contract, which only the orchestrator may change. | review 1 #11 test (30 updates and 40 pings all ok) |

Mutation check: I put all seven code bugs back at once (no archive on replace, direct write
during the drain, no close on a failed write, a reset on every hop, the old chat cleaner, `$`
in the rid pattern, no lock wait) and ran the suite. It printed `[tests] FAIL count=15`, and
each reintroduced bug failed its own new checks. I restored the files from a backup and checked
them byte for byte against it.

## Gates (sync pass, seen this session after the last code change)

All through `gslot.sh`. The final run is on `4621f4b` (the code tree of the branch head; `317d225`
only adds base docs): import after the merge (alarm 900, exit 0, 0 SCRIPT ERROR), then with the
hooks patch applied (the integrated state; reverted afterwards). The same set had passed on
`9ded4e4` before W2-SKILLS arrived.

```
net_tests exit=0 errors=0 :: [net_tests] PASS
t_ai, t_build, t_canim, t_combat, t_harbour (islands=15), t_iconart, t_items, t_light, t_lighting,
t_occlude, t_player, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_web: exit=0 errors=0 PASS
t_data exit=0 errors=0 :: [t_data] PASS items=223 recipes=155
t_save exit=0 errors=5 :: [t_save] PASS          (the 5 deliberate SCRIPT ERRORs, as on base)
t_uiicons exit=0 errors=0 :: [t_uiicons] PASS ids=171 files=114 ...
t_w2_skills exit=0 errors=0 :: [t_w2_skills] PASS
run_all exit=0 errors=0 :: [tests] PASS
smoke exit=0 :: SMOKE PASS
net_smoke exit=0 :: NET SMOKE PASS
[a] [netprobe] PASS me=Survivor8630 char=Survivor8630 saw=["Survivor2241"] heard="hello from Survivor2241" puppets=1 instance=1 rejected=0
[b] [netprobe] PASS me=Survivor2241 char=Survivor2241 saw=["Survivor8630"] heard="hello from Survivor8630" puppets=1 instance=1 rejected=0
```

On the branch alone (no hooks, at `9ded4e4`): `SMOKE PASS` (exit 0) and `[net_tests] PASS` (exit 0,
0 SCRIPT ERROR, `[nettests] presence latency 48 ms`). `net_checks.gd` makes 179 `_check` calls. The only
`ERROR:` lines in the suite are the four deliberate `register_op refused` cases.

Disk: the volume hit 0 bytes free during the run (other workflows' scratch trees hold about
115 GB). I deleted only my own stale import cache. The untracked files I moved out of this
worktree before the merge (import products the base now tracks) are in
`scratchpad/net-untracked-backup/` (1.2 GB) and can go.

## Limits and assumptions (all marked `# ASSUMPTION:` or `shortcut:` in code)

- **One free placement per island per 600 s.** A first visit to an island (or one after the
  10-minute TTL) starts anywhere, because the contract says travel resets the check and nothing
  server-side can prove travel yet. Fix once the economy lands: allow a fresh spot only after a
  recent accepted `wallet.spend {reason: travel}`, or a server travel record. The 2 s hop
  cooldown remains.
- **Rid caches live in RAM for every account, and compaction runs on the main thread** (review 2
  #8). At 10k accounts with 64 rids each, that is about 640k entries, and each compaction
  rewrites all of them. That stall takes seconds, long enough for the 10 s lock heartbeat to go
  stale and for client timeouts to fire. This is acceptable for v1. Move `rid_cache` into the
  economy's Account snapshot and journal (contract section 4) when it lands.
- **Rejected tokens are capped at 32 per server**, oldest dropped. Without the cap, a hostile
  server could grow the file by one key per reconnect. The token file also keeps at most 16
  servers and drops the least recently saved one, which loses that server's keys. Both are
  `shortcut:`s.
- **The client still makes a fresh account after its keys are refused**, instead of pausing for
  the UI to ask. Nothing is lost now, because every key stays on disk and is retried first. A UI
  can listen for `token_rejected` and tell the player. One gap remains: anything put into the
  temporary account (for example vault deposits on a server with the wrong `--data`) stays with
  that account.
- **The check bounds speed, not physics.** The server has no heightmap, so a client can "fly"
  at up to 11.2 m/s anywhere in the -20 to 30 m band, and can bank up to 33.6 m by standing still.
  Server-simulated islands (v2) remove this.
- **Mounts faster than 11.2 m/s are rejected** by the contract's 1.6 × run-speed rule (gallimimus:
  base 9 m/s before genetics). A rider like that freezes for other players. The contract needs a
  mount-aware limit; the orchestrator should decide.
- **A server restart resets the presence check**, because the last accepted positions are in
  memory only. Presence is cosmetic in v1.
- **Durability is per process, not per power loss.** `FileAccess.flush()` survives a process
  crash. Godot exposes no fsync, so an OS crash or power cut can lose the last writes. A full disk
  is detected by file length (review 2 #3); the op whose rid write failed has already applied
  and is replayable only until the process exits.
- **The economy must journal `rid`.** `rids.jsonl` covers every response the server sent. There
  is one window it misses: the economy flushes its journal, then the server dies before writing
  the rid. Closing it needs the economy to journal `rid` with each op and call
  `server.remember_rid()` on replay (see the runbook, section 5).
- **Lock trade-off:** after a crash or any signal, a restart waits up to 10 s for the heartbeat
  to go stale, logging `lock_error` once a second. A main-thread stall longer than 10 s (see the
  rid compaction limit) would let a second server take the dir. A heartbeat is used because
  Godot cannot check whether an unrelated pid is alive (`OS.is_process_running` covers only
  child processes).
- `presence` is a fourth rate class. Contract 5.4 lists three (see review 2 #10).
- Chat also strips ZWJ and ZWNJ, which splits emoji ZWJ sequences and changes Persian word shapes.
  It turns NBSP and U+3000 inside a line into plain spaces.
- On the server, autoloads (`TouchControls`, Game's perf label) still instantiate, because an
  autoload cannot be skipped per run. The playfield no longer loads.
- No TLS in the server. `wss://` needs a reverse proxy (Caddy, nginx) in front. Behind a proxy,
  every client has the proxy's IP, so the per-IP caps apply to all clients together. Those caps:
  16 sockets, 256 total, and 10 new accounts per hour per IP.
- The token is a bearer credential in plain JSON in `user://online_token.json`, along with the
  archived `"lost"` keys. There are no passwords (contract section 3).
- Values I picked: pre-hello limit 2/s burst 4; flood budget 3/s burst 30; timeouts of 5 s
  (handshake), 20 s (hello) and 60 s (idle); `max_players_area` 30 and `max_creatures_area` 24
  (`rules.json`) and at most 99 instances per island; a `lobby` room for the default
  playfield; per-account rooms for private islands; a 2 s island-hop cooldown; reserved names
  `settlers`, `server`, `system` and `admin`; a 3 s carry; the -20 to 30 m band; 3 combining marks;
  32 lost keys per server.
- No UI. There is no chat input box, no online indicator and no prompt for `token_rejected`. The
  chat screen is `claude/mmo-chat`'s, the Exchange screen W3-EXCHANGE's, and `hunt_hud.gd` is off limits.
- The server character's position is one point with no island: `char.move` commits the last
  presence spot whichever island it was on. Fine while the server world is empty; W3-SRVWORLD
  must key reach checks by island too.
- The server process still runs the `ShellLoader` autoload, which applies downloaded build packs
  from the server's own `user://builds` (empty unless someone puts packs there).
- Two desktop windows from one checkout share `user://`, so they sign in as the same account and
  the second kicks the first. Use web plus desktop, or the probes. See the runbook.
- The web path (`?online=`) is written but I did not test it: I did not run a web export.

## For the economy agent

`server.register_op("market.x", handler, mutating, "read"|"write"|"chat")`. The handler is
`func(account_id: int, a: Dictionary) -> Dictionary`, or the same with a third `rid: String`
parameter. Return `NetProtocol.ok(r)` or `NetProtocol.fail(code, msg)`. Anything else becomes
`server_error`, and so does a result over about 64 KiB, so page your searches.

Before your handler runs, the server has checked auth, the rate class and `rid` replay. After it
returns, the server saves the response under the `rid` before replying. If you journal: take the
`rid`, journal it with the op, and on boot call `server.remember_rid(account_id, rid, op,
response)` for each replayed entry, in the same frame as `server.start()`.

Other hooks: `server.send_event` / `server.broadcast_event` push events, and the signals are
`account_created`, `account_online` and `account_offline`. Once the rid store has failed a
write, every mutating op gets `server_error` before your handler runs. On the client, a
mutating request that ends in `timeout` or `offline` may have been applied. Retry it with
`Game.net.retry(req)`, never with a fresh `request()`. Requests keep their order across a
reconnect.
