# Online runbook: local server and two clients

Spec: `contracts.md` sections 1-3, 5.3, 5.4 and 7. Code: `game/scripts/net/`, `game/scenes/net/server.tscn`.
`G` below is your Godot binary, for example `/Applications/Godot_mono.app/Contents/MacOS/Godot`.
Run every command from the repo root.

## 1. Start a server

```sh
"$G" --headless --path game -- --server --port=8910 --data="$PWD/.server-data"
```

- `--port=` takes 0 to 65535. 0 picks a free port; the log prints which one.
- `--data=` must be an absolute path or a `user://` path. It defaults to `user://server/`.
  `accounts.json` is stored there (ids, names, `sha256(token)`, never the token itself).
- The server never builds the island, the player or the HUD. It logs one JSON line per
  connection event:
  `[net] {"ev":"listen","port":8910,...}`, then `connect`, `open`, `hello`, `drop` and `close`.
- Ctrl+C stops it. Accounts are written to disk when they are created (tmp file, then rename), so
  stopping the server at any moment is safe.

## 2. Desktop client

```sh
"$G" --path game -- --online=ws://127.0.0.1:8910
```

The client says hello with the survivor's name from the save. If the name is taken it adds
`-123` and tries again. It keeps the token in `user://online_token.json`, one entry per server URL,
so the next launch signs back in to the same account. If the connection drops, it reconnects with
backoff (0.5 s doubling to 30 s). The default playfield (no island loaded) is the `lobby` room.
Every island id is its own room, and each player's private home island is a room of its own.

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
- In the same room, each window shows the other survivor (same rig and clips), its name above it,
  and a 6-second chat bubble. There is no chat input UI yet; send chat from code with
  `Game.net.request("chat.send", {"text": "hi"})`.
- Creatures, combat and gathering are still simulated on each client (contract section 7, honest
  limit), so each player sees their own dinosaurs.

## 5. For economy code

```gdscript
server.register_op("market.buy", engine.op_buy, true, "write")
# handler: func(account_id: int, a: Dictionary) -> Dictionary  (NetProtocol.ok(r) / NetProtocol.fail(code, msg))
```

Handlers run on the main thread one at a time and must not await. The server has already
authenticated the account, rate limited it by class (`read`, `write`, `chat`) and, for mutating
ops, checked the `rid`: a repeated `rid` returns the cached response without calling the handler.
The last 64 rids per account live in `server.rid_caches` (memory only). Persisting them with the
snapshot is the economy's job (contract section 4). `server.account_created`,
`account_online` and `account_offline` are signals. `send_event` and `broadcast_event` push
`evt` frames to clients.

## 6. Checks

```sh
"$G" --headless --path game --script res://tests/run_all.gd   # net_tests.gd runs inside it
tools/smoke.sh --no-import                                     # SMOKE PASS
tools/net_smoke.sh                                             # NET SMOKE PASS
```
