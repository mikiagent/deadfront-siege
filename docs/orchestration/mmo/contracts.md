# DEADFRONT online: shared contracts (v1, 2026-10-18)

Every agent building online, economy or marketplace code builds against this file. Change it only
through the orchestrator. Where it is silent, pick the simplest thing and mark it `# ASSUMPTION:`.

## 0. Authority decision (v2, 2026-10-18; supersedes the v1 "client deposit" trust model)

The audit (economy, security and multiplayer auditors independently) rated v1's validated client
deposits P0: every item, pet and T-stone is minted on the client, so a market fed by deposits is
only as honest as its caps. The owner asked for a real, server-validated economy. Therefore:

1. **Online characters are server-owned from creation.** The server stores their bag, equipment,
   wallet, pets, skills and position (a `CharacterStore` persisted with the same snapshot+journal
   as the ledger). Offline saves never import into online characters. The client's copy is a cache
   that the server overwrites.
2. **Server-simulated islands.** The server runs the island headless (`Game.is_server` guards
   skip visuals, UI, autosave, shell): IslandRuntime, HarvestNode pools, creatures and brains,
   corpses, structures. Clients in online mode do not simulate creatures or nodes; they render
   replicas from server snapshots (10 Hz, interest radius 80 m).
3. **Clients send intents, the server decides.** One `PlayerActions` command layer is the only
   path that mutates inventory, equipment, crafting, building, eating, combat, looting and taming.
   Offline it applies locally exactly as today (no behaviour change, proven by existing labs).
   Online it sends `act.<verb>` ops (`act.gather {node_id, option}`, `act.attack {net_id}`,
   `act.loot {corpse_id, slot}`, `act.craft {recipe_id, picks}`, `act.place {kind, cell, rot}`,
   `act.equip`, `act.eat`, `act.tame {net_id, food}`), and the server runs the same domain code
   (Inventory, Crafting, CaptureSystem, FieldTame, Hunt) on its copy with a server-owned RNG,
   then pushes `evt char_delta` / `evt world_delta`.
4. **Movement** stays client-predicted and server-checked (speed/teleport bound, navmesh/terrain
   plausibility); the server's position is the one used for reach checks.
5. **Provenance.** Every server-minted stack and pet carries `uid` and `origin`
   (`gather|loot|craft|tame|breed|settlers|objective|market`) + the journal seq. Only assets with
   server provenance can enter the vault/market; the v1 dict-deposit ops are removed from the
   client API (`vault.deposit_*` take a bag slot or pet uid of the server-side character).
6. **Accounts.** Token accounts stay for local testing. Before public hosting: verified login and
   creation limits (owner decision at hosting time). New accounts are trade-locked until 30 min of
   server-observed play (`# ASSUMPTION`), and the starting wallet is bound (non-tradable).
7. **Faucets** are server-observed: objective rewards fire on server-observed state, Settler
   issuance is per active account per day with diminishing returns, missions.json is the renewable
   faucet. Sinks are named ledger entries.

Interim (until 2+3 land): the Exchange runs with Settlers and server-provenance assets only; no
client-claimed deposits are accepted on any server. The economy engine's deposit validation stays
as defence in depth.

## 1. Process model

- One Godot project, two roles. The **server** is the same project run headless:
  `Godot --headless --path game -- --server [--port=8910] [--data=<abs dir>]`.
  `Game` parses `--server`; `main.gd` loads `res://scenes/net/server.tscn` instead of the playfield
  (the same way labs load), so no island, player or HUD exists on the server in v1.
- The **client** is the normal game. Online is opt-in: `-- --online=ws://127.0.0.1:8910` on the
  command line, or the Connect button in the Exchange screen. Offline single-player stays the
  default and must keep working unchanged.
- No new autoload. The client connection lives at `Game.net` (a `NetClient` node added as a child
  of the `Game` autoload on first use). The server root is the `server.tscn` scene.

## 2. Transport and envelope

- Raw `WebSocketPeer` (works in browsers; ENet does not). Server: `TCPServer` +
  `WebSocketPeer.accept_stream()`. Text frames, one JSON object per frame, max 64 KiB.
- Client request: `{"t":"req","id":<int>,"rid":"<uuid>","op":"<name>","a":{...}}`
  - `id` matches the response; `rid` is the idempotency key for mutating ops (see 5.3).
- Server response: `{"t":"res","id":<int>,"ok":true,"r":{...}}` or
  `{"t":"res","id":<int>,"ok":false,"err":"<code>","msg":"<human text>"}`.
- Server push: `{"t":"evt","ev":"<name>","d":{...}}`.
- Error codes are stable strings: `bad_request`, `unauthorized`, `rate_limited`, `not_found`,
  `insufficient_funds`, `insufficient_items`, `not_owner`, `self_trade`, `expired`, `closed`,
  `bid_too_low`, `limit_reached`, `invalid_asset`, `conflict`, `server_error`.
- Every argument is validated on the server: type, range, length, enum. A request that fails
  validation changes nothing.

## 3. Identity

- `auth.hello {name, token?}` → `{account_id, name, token, server_time}`.
  First contact creates an account and returns a random 32-byte hex `token`; the client keeps it
  in `user://online_token.json` and sends it on reconnect. The server stores only
  `sha256(token)`. Names: 3–20 chars `[A-Za-z0-9 _-]`, unique case-insensitively.
  # ASSUMPTION: no passwords or email in v1; the token is the credential.
- Every other op requires a hello on that connection, else `unauthorized`.
- One live connection per account; a second hello for the same account closes the first.

## 4. Server-owned state (authoritative)

```
Account { id:int, name, token_hash, created, wallet:int (T-stones),
          vault_items: { uid -> ItemStackDict }, vault_pets: { uid -> PetDict },
          claimed_objectives: [int], inbox: [Event], rid_cache: {rid -> response} (last 64) }
```
- `ItemStackDict` is exactly `Inventory.to_array()`'s per-slot dict shape (def_id, count, level,
  process_count, attributes, flags, durability, max_durability). `PetDict` is `PetRecord.to_dict()`.
- Every asset on the server has a server-issued `uid` (`"i<seq>"` / `"p<seq>"`); uids are never reused.
- An asset unit lives in exactly one place: an account vault, a listing's escrow, or it has been
  withdrawn to a client (left the server). T-stones live in exactly one place: a wallet, an
  escrow hold (bid or buy order), the fee sink, or the faucet ledger.

### Vault = the bridge between a character and the economy
- `vault.deposit_item {slot_dict, count}` / `vault.deposit_pet {pet_dict}`: the client removes the
  stack or pet locally only after `ok`. Trust boundary: the server validates def/species exists,
  count > 0 and ≤ the def's stack rules, level 1..60, attributes and flags whitelisted (`locked`,
  `unstable` and broken items are refused), durability ≤ max at that level, pets' stats recompute
  from species + level + genetics within 0.5 %, IVs 0..31, EV total ≤ 300, empty pet bag, not summoned.
  Per-account per-def deposit caps per rolling 24 h come from `game/data/economy/limits.json`.
- `vault.withdraw_item {uid, count}` / `vault.withdraw_pet {uid}` remove from the vault and return
  the dict; the client adds it locally. Withdraw is authoritative and cannot duplicate.
- **Superseded by section 0:** deposits come from the server-side character, not a client dict.
  The validation above stays as defence in depth inside the engine.

### Wallet
- In online mode `World.t_stones` mirrors the server wallet. Client spends go through
  `wallet.spend {reason, amount}` (reasons: `travel`, `cargo_warp`, `claim`), validated against
  the server's copy of the cost tables. Faucets in v1: objective rewards via
  `objective.claim {index}` (once per index per account, amount from the server's
  `Data.world_objectives`), and settler NPC buy orders (6.6). Starting wallet 20.

## 5. Durability, atomicity, abuse limits

### 5.1 Single writer
All state mutation happens on the server's main thread, one request at a time. An op either
completes fully or changes nothing (validate everything first, then mutate). No awaits inside a
mutating op.

### 5.2 Persistence
- Data dir (default `user://server/`): `snapshot.json` + `journal.jsonl`.
- Every mutating op appends `{seq, ts, account, op, a}` to the journal and flushes **before** the
  response is sent. `ts` is the server time the op used; ids derive from `seq`, so replay is
  deterministic. Timers (auction end, order expiry) are journaled as `sys.tick {ts}` ops.
- Snapshot every 60 s or 500 ops: write `snapshot.json.tmp`, flush, rename over `snapshot.json`,
  then truncate the journal to entries after the snapshot's `seq`.
- Boot: load snapshot, replay journal entries with `seq > snapshot.seq`, then accept connections.
  A torn last journal line is discarded.

### 5.3 Idempotency
Mutating ops carry `rid`. If `rid` is in the account's `rid_cache`, return the cached response and
change nothing. Double clicks, retries after a dropped socket and replayed frames cannot apply twice.

### 5.4 Rate limits
Token bucket per account per op class (`read` 20/s burst 40, `write` 5/s burst 10, `chat` 1/s
burst 5) and per connection before hello (2/s). Over limit → `rate_limited`, nothing applied.

## 6. Marketplace rules

Numbers live in `game/data/economy/market_rules.json` (create it); defaults below.

### 6.1 Asset keys and fungibility
- Item key = `def_id`. Units are fungible for buy orders only when `level >= order.min_level` and
  `level <= order.max_level` (default 60) and the stack has no `unstable`/`locked` flags. Listings
  sell the exact stack (with its level, attributes, durability) shown to the buyer.
- Pets are unique assets; key = species. Owner rule (2026-10-19): a traded pet IS a caged item. A
  bonded pet is repackaged into a unique `caged_animal` stack (attributes carry the full PetDict, uid,
  origin, lineage) before it can enter the vault or a listing; the buyer unpacks the cage into a
  bonded pet without re-taming. Captured (untamed) cages are tradable too and still need taming.

### 6.2 Fixed-price listing (instant buy)
- `market.list_fixed {asset:{uid, count?}, unit_price, duration_h}`: moves the asset (or `count`
  of a stack, splitting it) from vault into listing escrow. Listing fee
  `ceil(listing_fee * unit_price * count)` (default 5 %, min 1) is charged now and never refunded.
- `market.buy {listing_id, count}` (partial buys allowed for stackable listings): buyer pays
  `unit_price * count` from wallet; seller is credited minus sales tax (default 3 %); the units go
  to the buyer's vault. Self-buy → `self_trade`.
- `market.cancel {listing_id}` returns unsold units to the seller's vault; fee is kept.
- Durations 12/24/48/72 h. Expiry returns unsold units to the seller's vault and inboxes the seller.

### 6.3 Auctions
- `market.list_auction {asset:{uid,count?}, start_bid, buyout?, duration_h}`; fee on `start_bid`.
- `market.bid {listing_id, amount}`: amount ≥ max(start_bid, current_bid × (1 + min_increment))
  (default 5 %, at least +1). The bid amount moves from the bidder's wallet into an escrow hold;
  the previous high bidder's hold is released to their wallet and they get an `outbid` event.
  Seller cannot bid (`self_trade`). A bid within the last 60 s extends the end to now + 60 s
  (at most 10 extensions).
- `market.buyout {listing_id}` if `buyout` is set: settles immediately at the buyout price;
  any standing bid is refunded.
- Settlement at end (server tick): high bidder's hold → seller wallet minus sales tax; asset →
  winner's vault; both inboxed. No bids → asset back to seller's vault. Auctions cannot be
  cancelled once they have a bid.

### 6.4 Buy orders and instant sell
- `market.order_create {def_id, min_level, max_level?, qty, unit_price, duration_h}`: escrows
  `qty × unit_price` from the buyer's wallet. Max 20 open orders per account.
- `market.sell_to_order {order_id, uid, count}`: moves matching units from the seller's vault to
  the buyer's vault, pays `unit_price × count` minus sales tax from the order's escrow; partial fills
  allowed; order closes at qty filled. Own order → `self_trade`.
- `market.order_cancel` / expiry refunds the unfilled escrow.
- Instant sell from the UI = pick the best open order for that def whose level range accepts the
  stack (highest unit_price, then oldest).

### 6.5 Search, inspection, history
- `market.search {q?, kind?: fixed|auction|any, asset?: item|pet|any, category?, species?,
  min_level?, max_level?, min_price?, max_price?, grade?, stat_min?:{stat:value}, sort:
  price_asc|price_desc|ending_soon|newest|level_desc, page, page_size<=50}` → listings with full
  asset dicts (pets include genetics, grade, level, stats, lineage when breeding exists).
- `market.orders {def_id?}` → open buy orders (best first). `market.item_detail {def_id|species}` →
  best ask, best bid, last price, 24 h volume, 7 d volume, and hourly OHLC + volume buckets for the
  last 7 days. `market.trades {def_id|species, limit}` → recent trades.
- Reference price = volume-weighted median of the last 7 d trades, excluding trades priced
  outside 0.25×–4× the previous reference and trades between the same two accounts more than
  twice in 24 h (wash-trade damping).
- `market.mine {}` → my listings, bids I hold, my orders, and my last 100 trades with fees.

### 6.6 Settlers (NPC liquidity)
The server account `Settlers` (id 0) posts buy orders from `game/data/world/market.json` demand,
refreshed every server hour, with a daily issuance budget (default 2,000 T-stones). It is the only
faucet besides objectives. Its orders are marked `npc: true` in every response and the UI says
"Settlers". It never sells. # ASSUMPTION: Settlers only buy; they replace the single-player
simulated market as the price floor.

### 6.7 Invariants (tests must assert after every op in a fuzz run)
1. Coins: Σ wallets + Σ escrow holds + fee sink == initial grants + faucet issued.
2. Items: for each def, deposited − withdrawn == units in vaults + units in listing escrow.
3. Every uid appears in exactly one container. No negative counts or balances.
4. A listing is in exactly one state: `active`, `sold`, `expired`, `cancelled`.
5. Replaying journal from empty reproduces byte-identical state.

## 7. Presence and chat (v1)

- Rooms are island ids. `presence.join {island}` then `presence.update {p:[x,y,z], yaw, anim,
  island}` at ≤ 10 Hz. The server rejects moves faster than 1.6 × the survivor's run speed since
  the last accepted update (teleport check; travel between islands resets), and relays accepted
  states to the room at 10 Hz as `evt presence {players:[{id,name,p,yaw,anim}]}`; leaves as
  `evt presence_leave {id}`.
- `chat.send {text}` ≤ 200 chars, rate limited, control chars stripped → `evt chat {from, text, ts}`
  to the room.
- **Honest limit (v1):** creatures, combat and gathering nodes are still simulated per client, so
  two players see their own dinosaurs. Server-simulated islands are the v2 networking milestone.

## 8. Files and ownership

- `game/scripts/economy/` — pure market and ledger domain (no networking, no nodes): engine,
  rules, ledger, journal, invariants. Deterministic; time injected.
- `game/scripts/net/` — `net_server.gd`, `net_client.gd`, protocol helpers, presence, chat, auth.
- `game/scenes/net/server.tscn` — server root.
- `game/scripts/ui/market/` — Exchange screens. Never edit `hunt_hud.gd`, `inventory_ui.gd`,
  `animal_screen.gd`, `item_icons.gd` beyond a one-line hook to open the screen.
- `game/data/economy/` — `market_rules.json`, `limits.json`.
- `game/tests/` — `economy_tests.gd` (engine + fuzz invariants), `net_tests.gd`.
- Labs: `net_lab` (server + 2 clients), `market_lab` (UI states, screenshots).
