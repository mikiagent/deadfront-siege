# Online runbook: local server and two clients

Spec: `contracts.md` sections 0 (v2), 1-3, 5.3, 5.4 and 7. Code: `game/scripts/net/`, `game/scenes/net/server.tscn`.
`G` below is your Godot binary, for example `/Applications/Godot_mono.app/Contents/MacOS/Godot`.
Run every command from the repo root. The server boot path needs the package's integrator hooks
(`docs/orchestration/reports/claude-mmo-net-hooks.patch`: `world.gd` skips its boot and autosave for
the server and probes, `shell/boot.gd` loads `server.tscn`). Until they are applied, `--server`
still starts through `main.gd`'s fallback, but World boots the save first.

## 1. Start a server

```sh
"$G" --headless --path game -- --server --port=8910 --data="$PWD/.server-data"
```

- `--port=` takes 0 to 65535. 0 picks a free port; the log prints which one.
- `--max-per-ip=N` caps the sockets one IP address may hold. Without it the server uses
  `max_connections_per_ip` from `game/data/world/rules.json` (30, one full area, so a household or
  a school behind one NAT can fill an instance). The `listen` log line prints the value in use
  (`"max_per_ip":30`); a socket past it is closed at once and logged as `refused`.
- `--data=` must be an absolute path or a `user://` path. It defaults to `user://server/`.
  It holds `accounts.json` (ids, names, `sha256(token)`, never the token itself) plus
  `accounts.json.bak` (the version before the last write), `rids.jsonl` (the last 64 mutating
  responses per account), `server.lock`, `world_seed` (the secret that seeds every server roll;
  made once, keep it with the data) and `chars/` (W1-SRVDOM's CharacterStore: `snapshot.json`
  plus `journal.jsonl`, the server-owned characters). A `chars/` whose `world_seed` is missing or
  different refuses to start: restore the seed file rather than delete the characters.
- One server per data dir. `server.lock` is a heartbeat rewritten every 3 s. A second server
  waits while the heartbeat is under 10 s old, logging `lock_error` once a second. If the
  heartbeat is still fresh after 13 s, another server really holds the dir, and it exits 1.
- The shell loads `server.tscn` directly, so the island, the player and the HUD are never
  loaded. The server logs one JSON line per connection event:
  `[net] {"ev":"listen","port":8910,...}`, then `connect`, `open`, `hello`, `drop` and `close`.
- Ctrl+C, `kill` and `systemctl stop` all stop it at once. Godot runs no exit code on a signal,
  so every one of them leaves `server.lock` behind (only a scene quit removes it). A restart
  right away therefore waits up to 10 s for the heartbeat to go stale, then starts by itself.
- The data is safe at any stopping point. Accounts and rids are written to disk before the reply
  is sent (accounts: tmp file, then rename; rids: appended and flushed), and a retry after a
  restart replays the saved response. A power cut is not covered: Godot has no fsync.
- Disk full: each write is checked by file length, because on a full disk Godot's writes and
  flushes report success. A failed account write refuses that hello with `server_error`. A failed
  rid write closes the rid store, so every later mutating op gets `server_error` until you free
  space and restart. The op whose write failed has already applied: its answer is sent, and its
  rid replays until the process exits.
- If `accounts.json` does not parse, the server refuses to start rather than run with an empty
  store. To recover, copy `accounts.json.bak` over it by hand.

## 2. Desktop client

```sh
"$G" --path game -- --online=ws://127.0.0.1:8910
```

The client says hello with the survivor's name from the save. If the name is taken it adds
`-123` and tries again. It keeps the token in `user://online_token.json`, one entry per server URL,
so the next launch signs back in to the same account. If the connection drops, it reconnects with
backoff (0.5 s doubling to 30 s).

The token is the account's only key, so the client never deletes one. If the server rejects it
(data reset or restored, wrong `--data` dir, a different server on the same address), the client
logs `[net] WARNING: ... rejected the saved token` and emits `event("token_rejected")`. It then
tries the keys archived under `"lost"` in the token file, newest first, and only after that
makes a fresh account. Any key that gets replaced moves to `"lost"` (the newest 32 per server are
kept). So once you restore the right data, the client finds its old account by itself on the
next connect. The default playfield (no island loaded) is the `lobby` room.
Every island id is its own room, and each player's private home island is a room of its own.

**Areas (instances).** A public island room is split into instances of at most `max_players_area`
players (`game/data/world/rules.json`, 30 for now). `presence.join {island}` puts you in the first
instance with room and answers `{island, instance, players, max_players}`. `presence.join {island,
instance}` asks for one; a full one answers `limit_reached` with a reason ("desert_35 instance 1 is
full (30/30 players); join instance 2") and `r.next_instance`. The client remembers its instance
and asks for it again after a reconnect, so a group stays together; when that instance filled up
meanwhile, it takes `next_instance`. Presence and chat stay inside one instance. Creatures per
area are capped by `max_creatures_area` (the hooks patch makes the island spawner honour it).

**Characters.** Online characters are server-owned (contracts v2 §0.1): the first hello makes the
account's character on the server, and `char.get` reads it. Offline saves never import
(`char.import` is always `invalid_asset`). The act intents (`act.gather`, `act.loot`, `act.craft`,
`act.place`, `act.equip`, `act.eat`, `act.tame`, `act.capture`, `act.attack`, `act.deposit`) run
on the server's copy, with reach measured from the last position presence accepted. The server has
no island yet (W3-SRVWORLD), so intents that need a node, corpse or creature answer `not_found`,
and the game client still plays its island locally (PlayerActions sends nothing until W3-SRVACT).

Without `--online=`, the game runs offline exactly as before. `Game.net` is only created the first
time something uses it.

## 3. A second client

Two desktop windows from the same checkout share `user://`, which means they share the token file
and the single-player save. They sign in as the **same account**, so the second window kicks the
first one (`evt kicked`, close code 4003). This is deliberate: an account gets one live connection.
For a second player, use one of these:

- **Web build.** A browser keeps its own `user://`:
  ```sh
  tools/export_web.sh                      # needs the standard (non-Mono) Godot and web templates
  python3 -m http.server 8060 -d export/web
  ```
  Then open `http://localhost:8060/?online=ws://127.0.0.1:8910`. A browser has no command line,
  so `?online=` stands in for `--online=`. A page served over https can only reach `wss://`.
  Open a private window for a third player.
- **Headless probes.** `tools/net_smoke.sh` starts a server on a free port and two headless
  clients (`-- --online=ws://127.0.0.1:<port> --net-probe`). Each probe has a throwaway identity
  and skips the save. The script prints `NET SMOKE PASS` once both have seen each other move and
  heard each other's chat.

## 4. What you should see

- Each client logs `[net] online as <name> (#<id>) at ws://...`.
- In the same room (island instance), each window shows the other survivor (same rig and clips),
  its name above it, and a 6-second chat bubble. The chat screen is `claude/mmo-chat`'s; from code,
  `Game.net.request("chat.send", {"text": "hi"})`.
- Creatures, combat and gathering are still simulated on each client (contract section 7, honest
  limit), so each player sees their own dinosaurs.

## 5. For economy code

```gdscript
server.register_op("market.buy", engine.op_buy, true, "write")
# handler: func(account_id: int, a: Dictionary) -> Dictionary  (NetProtocol.ok(r) / NetProtocol.fail(code, msg))
#      or: func(account_id: int, a: Dictionary, rid: String) -> Dictionary
```

Handlers run on the main thread one at a time and must not await. Before your handler runs, the
server has already authenticated the account, rate limited it by class (`read`, `write`, `chat`;
`presence` is for presence.update only and is not in contract 5.4 yet) and, for mutating ops, checked the `rid`: a repeated
`rid` returns the cached response without calling the handler.

An answer over the class bucket is `rate_limited` and the socket stays open, so a player mashing
Send is only throttled. Frames no bucket covers count as flood strikes instead: bad JSON, a bad
envelope, an unknown op, a second `auth.hello` on a signed-in socket ("already signed in on this
connection") and requests before hello past the pre-hello bucket. 30 strikes in a burst (3/s
refill) close the socket with code 4005. So does going past the bucket more than 200 times in a
burst (20/s refill), which only a script does. After the handler returns, the
server writes the response to `rids.jsonl` before sending it, so the cache survives restarts.

If your op journals itself (contract 5.2), take the third `rid` parameter and journal the rid
with the op. When you replay the journal at boot, call
`server.remember_rid(account_id, rid, op, response)` for each entry, in the same frame as
`server.start()`. This covers a crash that lands after your journal flush and before the
server's rid write. Results over 64 KiB are replaced with `server_error` ("response too large"),
so page your searches.

`server.account_created`, `account_online` and `account_offline` are signals. `send_event` and
`broadcast_event` push `evt` frames to clients. An event over 64 KiB is logged and dropped.

On the client, `Game.net.request()` returns a `NetRequest` with `req.rid`. A mutating request
that ends in `timeout` or `offline` may have been applied. Retry it with `Game.net.retry(req)`,
which reuses the rid, and never with a fresh `request()`.

## 6. Checks

```sh
"$G" --headless --path game --script res://tests/net_tests.gd  # [net_tests] PASS
tools/smoke.sh --no-import                                     # SMOKE PASS
tools/net_smoke.sh                                             # NET SMOKE PASS (needs the hooks patch)
```
