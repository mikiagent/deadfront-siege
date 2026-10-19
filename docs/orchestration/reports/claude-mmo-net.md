# claude-mmo-net: network core

Branch `claude/mmo-net`. Spec: `docs/orchestration/mmo/contracts.md` sections 1, 2, 3, 5.3, 5.4 and 7.
How to run it: `docs/orchestration/mmo/net-runbook.md`.

## What shipped

| File | What it does |
|---|---|
| `game/scripts/core/game.gd` | Parses `--server`, `--port=` (0-65535), `--data=` (absolute or `user://`), `--online=<ws url>` and `--net-probe`. On web it reads `?online=` from the page URL. `Game.net` is a lazy getter that adds a `NetClient` child to the Game autoload the first time something uses it. |
| `game/scripts/core/main.gd` | `--server` loads `res://scenes/net/server.tscn` and frees the playfield and camera, so the server never builds the island, player or HUD. `--online=` adds `RemotePlayers` and `PresenceSender`, then connects. |
| `game/scripts/core/world.gd` | `_boot` is skipped for the server and for probes. `_save_now` is a no-op for probes. |
| `game/scenes/net/server.tscn`, `net_server.gd` | `TCPServer` plus `WebSocketPeer.accept_stream()`, polled in `_process`. Strict envelope parsing (64 KiB cap, text frames only, known keys only, integer `id`, op-name and `rid` patterns). Rate limits: before hello, per connection; after hello, per account, by `read`/`write`/`chat` class; plus a flood budget that closes sockets sending garbage. `register_op(name, handler, mutating, rate_class)`. Last-64 `rid` cache per account for mutating ops. Kicks the old connection (`evt kicked` plus close code 4003) when an account says hello a second time. Handshake, hello and idle timeouts. Slow readers are dropped instead of buffered. One JSON log line per connection event. |
| `account_store.gd` | Identity only: id, name, `sha256(token)`, created. `accounts.json` is rewritten through tmp + rename on each new account. A corrupt file refuses to open instead of starting empty. |
| `presence_rooms.gd` | One room per island id, and one per account for private home islands. Teleport check against 1.6 × run speed. 10 Hz batched `evt presence` carrying only states that changed. Newcomers get a snapshot of who is already there. `evt presence_leave` on leave or disconnect. |
| `net_chat.gd` | `chat.send` (rate class `chat`): strips C0, C1, DEL, zero-width and bidi-override characters, trims, 1-200 characters, sends `evt chat {from, id, text, ts}` to the sender's room. |
| `net_protocol.gd`, `token_bucket.gd`, `net_request.gd` | Frame builders, error codes, strict int/number/vec3/name/token validators, uuid4, the token bucket, the awaitable request object. |
| `net_client.gd` | Connects and says hello with the token saved in `user://online_token.json` (keyed by server URL). Name conflicts retry with a `-123` suffix. `request(op, a, timeout) -> NetRequest` (`await req.done`). A fresh `rid` goes on every request. Requests made while reconnecting are sent once the client is back online, with the same `rid`. 15 s ping, 45 s silence timeout, exponential backoff with jitter. Signals: `state_changed` and `event`. |
| `presence_sender.gd`, `remote_players.gd`, `remote_puppet.gd` | Sends position, world yaw and `PlayerAnim.current_clip` at 10 Hz, only while online and only when something changed. Puppets reuse `Player.SURVIVOR_BASE_GLB` and the clip folder through `RiggedModel`, with 100 ms interpolation, a snap past 15 m, a `Label3D` nameplate and a 6 s chat bubble. Server data is validated again on the client. |
| `game/scripts/dev/net_probe.gd`, `tools/net_smoke.sh` | Multi-process smoke: one headless server and two headless `--net-probe` clients. |
| `game/tests/net_tests.gd` (+1 call in `run_all.gd`) | A real server and real clients over localhost sockets on a random free port. |

Run speed: `Player.run_speed = 7.0` (`game/scripts/player/player.gd:19`, not overridden in
`player.tscn`). The server reads it from the script with `get_property_default_value` and falls back
to the same constant. Limit: 1.6 × 7.0 = 11.2 m/s, plus 0.5 m slack per update for frame jitter and
the roll (13 m/s for 0.45 s).

## Test output (seen this session, after the last code change)

```
[nettests] presence latency 90 ms
[tests] PASS
SMOKE PASS
[a] [netprobe] PASS me=Survivor2574 saw=["Survivor8622"] heard="hello from Survivor8622" puppets=1 rejected=0
[b] [netprobe] PASS me=Survivor8622 saw=["Survivor2574"] heard="hello from Survivor2574" puppets=1 rejected=0
NET SMOKE PASS
```

`net_tests.gd` covers:
- hello creates accounts and returns tokens; only the hash is stored
- reconnect with the saved token gives back the same account; a second login kicks the first
- automatic reconnect with backoff, and requests queued meanwhile still go through
- names: duplicates rejected case-insensitively, invalid names rejected, reserved names rejected
- tokens: malformed or unknown tokens rejected
- bad frames: bad JSON, non-object frames, JSON nested 20,000 deep, missing, fractional or wrong
  `id`, `t`, `op` or `a`, unknown envelope fields, unknown ops, missing or infinite presence
  fields, binary frames, a 70 KB frame (`bad_request`), and a 300 KB frame (only that socket closes)
- rate limits: pre-hello limit, chat burst, and the chat bucket belongs to the account, not the socket
- `rid`: a replay returns the cached response, reusing a `rid` for another op is `conflict`, a
  mutating op without a `rid` is refused, the cache survives a dropped socket, exactly the last 64
  are kept, and a handler returning garbage gives `server_error`
- presence: a move arrives within 300 ms; puppets use the rig and clips and interpolate; a
  teleport is rejected and never relayed; reconnecting does not reset the teleport check; quick
  island hops are refused; private islands stay apart; leaving removes the avatar
- chat: delivered, trimmed and stripped, oversize and blank messages rejected
- accounts reload from disk; a corrupt store refuses to open; every connection is released at the end

## What failed during the resume, and what fixed it

- `net_tests.gd` did not parse: a literal U+202E in a string. It is escaped now. `run_all.gd` now
  records a failure instead of hanging if `net_tests.gd` cannot load.
- `evt kicked` never reached the first client. `WebSocketPeer` reports no packets once the socket
  is CLOSED, so an event sent together with the close was lost. The client now reads frames before
  it looks at the socket state, and also treats close code 4003 as the kick.
- The "unknown token" test hit the pre-hello rate limit (burst 4) on a reused socket. It uses a fresh socket now.
- Hardening added: the teleport check keeps the last accepted position across reconnects (swept
  after 10 min), and an account can change islands at most once every 2 s. Without this, a
  reconnect or an island hop reset the check. The sender uses world yaw, which is correct while
  mounted, and replaces any clip name the server would refuse with `idle`. Probes never write the save.

## Limits and assumptions (all marked `# ASSUMPTION:` in code)

- **Mounts faster than 11.2 m/s are rejected** by the contract's 1.6 × run-speed rule (gallimimus:
  base 9 m/s before genetics). A rider like that freezes for other players. The contract needs a
  mount-aware limit. This is for the orchestrator to decide.
- The `rid` cache is memory only. Contract section 4 puts it on the Account, so the economy
  snapshot should persist `server.rid_caches`. Without that, a retry that crosses a server restart
  can apply twice.
- No TLS in the server. `wss://` needs a reverse proxy (Caddy, nginx) in front. Behind a proxy,
  every client has the proxy's IP, so the per-IP caps apply to all clients together. Those caps:
  16 sockets, 256 total, and 10 new accounts per hour per IP.
- The token is a bearer credential in plain JSON in `user://online_token.json`. There are no
  passwords (contract section 3).
- Values I picked: pre-hello limit 2/s burst 4; flood budget 3/s burst 30; timeouts of 5 s
  (handshake), 20 s (hello) and 60 s (idle); 100 per room; `lobby` room for the default
  playfield; per-account rooms for private islands; 2 s island-hop cooldown; reserved names
  `settlers`, `server`, `system` and `admin`.
- No UI. There is no chat input box and no online indicator: the Exchange screen and HUD belong
  to other packages, and `hunt_hud.gd` is off limits. Chat can be sent from code
  (`Game.net.request("chat.send", ...)`).
- Two desktop windows from one checkout share `user://`, so they are the same account and the
  second kicks the first. Use web plus desktop, or the probes. See the runbook.
- The web path (`?online=`) is written but I did not test it: I did not run a web export.
- The server boots `main.tscn` and frees the playfield in `_ready`, so it still pays the
  playfield's load cost once at boot (contract section 1 asks for it to load "the same way labs load").
- The test run also prints `Save schema 4 is newer than this build (3)` and `1 resources still in
  use at exit`. I did not trace either one, so I cannot say whether they predate this package.

## For the economy agent

`server.register_op("market.x", handler, mutating, "read"|"write"|"chat")`, where the handler is
`func(account_id: int, a: Dictionary) -> Dictionary`. Return `NetProtocol.ok(r)` or
`NetProtocol.fail(code, msg)`. Anything else is turned into `server_error`. Before your handler
runs, the server has already checked auth, the rate class and `rid` replay. Push events with
`server.send_event` / `server.broadcast_event`. The signals are `account_created`,
`account_online` and `account_offline`. `auth.hello` cannot be registered over. Duplicate names
and unknown rate classes are refused.
