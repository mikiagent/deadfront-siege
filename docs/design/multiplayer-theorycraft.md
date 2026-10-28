# Multiplayer theory-craft — how WildLands MMO goes online

Status: **proposal, no code**. Written 2026-10-28 against `claude/mmo-overhaul` (83673a40). Multiplayer
authority is one of Milan's gates; this document informs that decision and ends with the questions only
Milan can answer. Nothing here changes gameplay code.

Sources read: `GAUNTLET.md`, `HANDOFF.md`, `docs/orchestration/mmo/STATUS.md` (owner decisions, on the
package branches), `docs/vision/WildLandsMMO_Game_Vision.md` §2-3, §18-20,
`docs/vision/WildLandsMMO_Loss_Recruitment_Revival.md`, `docs/current/server-contract.md`,
`docs/current/saves-persistence.md`, `docs/current/economy-trading.md`, and the code under
`game/scripts/{server,economy,player,creatures,world,core}`.

---

## 0. The short answer

1. **Every island is a room.** WildLands never needs a seamless open world. Travel is already a load
   swap (ferry, sail, warp), so the natural unit of multiplayer is one island instance on one server
   process. Personal homes, the tutorial island, expeditions, hubs and the future frontier are all the
   same thing with different rules about who may enter and how long the island lives.
2. **The server owns everything that lasts.** Inventory, items, pets, tribe members, claims, buildings,
   currency, market, XP and island state live on the server. Clients send *intents* ("gather this
   node", "walk to here", "attack that") and draw what the server says happened. This is already the
   project's written contract ("contracts v2 §0", 2026-10-18: online characters are server-owned,
   islands are server-simulated, clients send intents), and half of it is already built in
   `game/scripts/server/` and `game/scripts/economy/`.
3. **Players never host.** No listen-server or "host's island is the truth" mode for online play,
   because anything a host simulates can feed the shared market. Offline single-player stays exactly
   as it is today: a separate local save that never imports into an online character (`char.import`
   is already refused).
4. **One transport: WebSockets.** The web build cannot use ENet, Vercel cannot hold sockets, and an
   isometric click-to-move game tolerates TCP well. Godot's `WebSocketMultiplayerPeer` serves web,
   desktop and phones with one code path. WebRTC is a later option only if fast PvP needs it.
5. **The path:** first cut an "intent seam" in the single-player game (no network), then a local
   dedicated server with 2-4 friends on one island, then a small hosted world (tutorial channels, a
   harbour hub, market, chat), and only then MMO-scale orchestration and the PvPvE frontier.
6. **One global market** outside the island rooms (§7): the existing engine already is one order book
   with escrow, inbox delivery and anti-dupe rules; offline single-player has no market.

---

## 1. What exists today (the honest starting point)

| piece | state | where |
|---|---|---|
| Server character store | Built and tested, **not used by the live game**. Append-only journal + snapshots, idempotent request ids, replayable seeded RNG, provenance uids on every minted item/pet. | `game/scripts/server/character_store.gd`, `intent_handlers.gd` |
| Intent ops | `act.gather`, `act.loot`, `act.craft`, `act.place`, `act.equip`, `act.eat`, `act.tame`, `act.capture`, `act.attack`, `act.roll`, `char.move` (distance budget 7 m/s), reach checks 2.6 m | `intent_handlers.gd`, `docs/current/server-contract.md` |
| Market / economy | Built server-side and in-process: ledger, listings, auctions, buy orders, Settlers NPC orders, bound vs tradable T-stones, 30-min trade lock, crash recovery. Screens show an honest "offline" card in single-player. | `game/scripts/economy/`, `game/scripts/ui/market/` |
| Transport | **None.** No `MultiplayerPeer`, socket, port, auth, presence or chat code anywhere. A `claude/mmo-net` package (server, auth, presence, chat) was planned but no branch was pushed. | — |
| Live single-player | Runs on `World` + `SaveGame` (`user://save_1.json`, schema 4, sanitizer, `.bak`, quarantine, 60 s autosave, 7-day offline catch-up cap). | `game/scripts/core/` |
| Simulation split | `PlayerSim` is already a `RefCounted` sim separate from the view (good for prediction). Creatures are `CharacterBody3D` + `NavigationAgent3D` with brains in `creatures/brains/` (good for a server; they would run there only). | `player/player_sim.gd`, `creatures/` |
| Determinism | Island layout is seeded from the island id; creature genetics are seeded from a spawn key; roll timing is one shared rule (`RollRules`) used by client and server. **Not deterministic:** weather rolls (`randf` in `world_weather.gd`), brain choices (`randf` in 4 brain files), bolt seeds. | `world/island_terrain.gd`, `creatures/creature.gd`, `world/world_weather.gd` |
| Web build | `gl_compatibility`, no threads (`thread_support=false`), 254 MB pack, ~6 fps with 60 creatures on web (STATUS). | `game/export_presets.cfg` |

The big gap is not "the server" (a lot of it exists); it is that **the game you play does not talk to
it**. Everything in this document flows from closing that gap without breaking the single-player game.

---

## 2. Topology: where players are together

### Options

| option | what it means | good | bad |
|---|---|---|---|
| **A. Seamless shared world** | One big map split into server-owned regions, players cross borders live (classic MMO). | Strangers everywhere, "real MMO" feel. | Very expensive to build (handoff between servers, region borders on the sea), the game's islands already make borders natural, so the cost buys little. Personal homes would have to be carved out of shared space. |
| **B. Island instances (rooms)** | Each island copy runs as one instance; travel = leave one room, join another. Shared spaces are just instances many people may join, split into channels when full. | Matches what the game already is (island swap, ferry, sail). Cheap: an empty island costs nothing. Personal homes are naturally private. Channels solve crowding (owner plan 2026-10-19: per-area player cap, full area sends new players to another instance). | Strangers only where we put them (hubs, shared islands). Needs an "orchestrator" that starts/stops island instances. |
| **C. Player-hosted (listen server)** | The island owner's game is the server; friends connect to it. | Nearly free to run, fast to prototype. | The host can cheat anything, and anything they make can reach the shared market. Breaks the economy the vision depends on. Host leaves = everyone leaves. |

### Recommendation: B, with five island kinds

| island kind | who is in it | lifetime | instance rule |
|---|---|---|---|
| **Home island** (private) | Owner, their tames and tribe; invited visitors (party/friends) | Permanent record; **runs only while someone is there** | One instance per owner. Asleep = just data. |
| **Tutorial island** | New characters | Per character until they take the ferry home | Channels of ~8-16 new players sharing the indestructible town (social first impression), each with their own Orders and own harvest state. *Unknown:* whether Milan wants new players to see each other here at all (channel size 1 is also fine). |
| **Expedition / unstable island** | A party (1-4) | Resets anyway (vision §2) | One instance per party; destroyed when the party leaves or the timer ends. |
| **Hub island** (harbour town / market) | Everyone | Permanent, shared | Channels capped at `max_players_area` (e.g. 40-60). Mostly social: market stalls, chat, recruit boats, notice boards. Little or no combat. |
| **Frontier (PvPvE)** | Level-60 characters who opt in | Persistent regions | Few persistent instances, one per frontier island, with raid rules. **Last phase.** |

Why this fits WildLands specifically: vision §2 already describes exactly this hybrid (private homes,
expedition instances, shared hubs, optional frontier); the ferry/sail/warp travel exists; the tutorial
island is already a separate prebuilt island; and the owner already asked for mob and player caps per
area with overflow into channels.

---

## 3. Authority: who decides what is true

### Options

| model | description | verdict |
|---|---|---|
| Client-authoritative | Client says "I gathered 3 logs, I hit for 40". Server stores it. | No. Dupes and fake items flow straight into the market. |
| Host-authoritative | One player's game is the truth for an island. | No for online (see option C above). Fine for a LAN demo only. |
| **Server-authoritative with client prediction** | Server runs the island; clients send intents, predict their own movement for responsiveness, and accept corrections. | **Yes.** It is what contracts v2 already decided and what `CharacterStore` is built for. |

### What must be server-side, and what may stay on the client

| thing | authority | notes |
|---|---|---|
| Inventory, items, equipment, bags, per-tame inventories | **Server, from day one** | Already modelled: provenance uids, slot/uid moves only, asset dictionaries refused. |
| Currency, market, trades, deposits | **Server, from day one** | Already built (`VaultBridge`, ledger, trade lock, bound T-stones). |
| Claims, domains, release land, buildings, storage contents | **Server, from day one** | `act.place` exists; release/claim/storage ops still to write. |
| Gathering, butchering, crafting, cooking, taming, capture | **Server, from day one** | Ops exist for most; butchering cuts, cooking on lit fires, drying racks need ops. |
| XP, skill points, skill trees, titles, levels | **Server, from day one** | Today skill nodes stay client-side (comment in `intent_handlers.gd`): must move. |
| Creature AI, spawns, genetics, alphas, enrage | **Server only** | Clients never run brains for online islands; they animate what they receive. |
| Combat hits (player → creature, creature → player, PvP) | **Server** | `act.attack` today uses *the client's* combat numbers: must switch to server-derived stats. Creature → player hits are not validated yet; `rolls_dodge()` is ready for it. |
| Player movement | **Client-predicted, server-checked** | Client moves instantly; server re-simulates with `PlayerSim` and corrects drift. `char.move` speed budget exists. |
| Vitals (health, stomach, exhaustion, wet, status effects) | **Server**, client-predicted for display | Low cheat value in PvE, high in PvP; move them before the frontier at the latest. |
| Weather, time of day, lightning, fire burn | **Server per island**, broadcast | Today local `randf`; becomes a server event stream. |
| Camera, UI, VFX, sound, tree fade, eye glow, ragdolls | **Client only** | Pure presentation. Ragdoll *results* (where a carcass lies) come from the server. |

**Offline single-player** keeps its own local authority and local save. The two never mix: an offline
survivor cannot be imported into an online world (already enforced). This is the cleanest way to keep
the solo game fully playable without letting it print market goods.

---

## 4. State sync and tick strategy in Godot 4.7

### Transport

| transport | web build | desktop/mobile | notes |
|---|---|---|---|
| **WebSocket** (`WebSocketMultiplayerPeer`) | Yes | Yes | One code path everywhere. TCP: a lost packet delays later ones (head-of-line). Fine at our pace. **Recommended.** |
| ENet (`ENetMultiplayerPeer`) | **No** (browsers cannot open UDP) | Yes | Would split the player base by platform. |
| WebRTC (`WebRTCMultiplayerPeer`) | Yes | Yes (with the webrtc extension on native) | Unreliable channels are nicer for fast action; needs a signalling server plus STUN/TURN relays. Keep as a later upgrade for PvP if needed. |

The static web build stays on Vercel. Game servers run on a host that keeps sockets open (STATUS: "a
public multiplayer server needs a host that keeps WebSockets open (Vercel cannot)"). Browsers on an
`https` page need `wss://`, so the server needs TLS (a proxy such as Caddy in front of it is the usual
cheap answer).

### Two layers, two styles

1. **Durable layer (account + character + economy):** request/response intents in the journal format
   that already exists (`op`, `rid`, args → result). Can travel as JSON messages over the same
   WebSocket. Every op is idempotent (`rid`) so a reconnect never double-spends.
2. **Live layer (one island instance):** Godot's high-level `MultiplayerAPI` inside the island process:
   `MultiplayerSpawner` for creatures, players, pets, carcasses, projectiles; a small custom snapshot
   for positions (cheaper than one `MultiplayerSynchronizer` per creature at scale); RPCs for intents
   and one-shot events (strike, roar, hit number, loot drop).

### Ticks (starting numbers, all `# ASSUMPTION` until measured)

| clock | rate | why |
|---|---|---|
| Server physics / AI | 30 Hz | Half the client's 60 Hz; brains and nav do not need more. |
| Snapshots to clients | 10-15 Hz | Position, facing, clip id + clip start time, health bars. Delta-compressed against the last acked snapshot. |
| Client render | 60 fps with ~100 ms interpolation buffer | `physics_interpolation=true` is already on; other entities draw slightly in the past, smoothly. |
| Own survivor | predicted every frame | `PlayerSim.tick()` already isolated; server answers with an authoritative position + input sequence number; client replays unacked inputs. |
| Weather / day clock | event-driven + 1 Hz sync | Server sends state changes ("pour started", "bolt at x,z at t") and the clock; clients animate locally. |

### Things that make WildLands cheaper to network than an action MMO

- **Click-to-move.** Most movement is "walk to point P". The client sends one intent, the server
  pathfinds, everyone else needs only the route and speed. Joystick/WASD movement is the costlier case
  and is handled by prediction.
- **Terrain from a seed.** Island layout is seeded from the island id and data files, so clients
  build terrain, props and ground cover locally. The server only sends *differences*: harvested nodes,
  felled trees, carcasses, buildings, claims. This needs a version handshake so both sides run the same
  data (the store already hashes its data files and warns when they change).
- **Small rooms.** One island with 24 creatures (today's `max_creatures_per_island`) and a handful of
  players is a tiny snapshot. Interest management can start as "everything on the island" and become
  "within ~80 m" for hubs.
- **Combat is cooldown-based**, not twitch: attacks are intents with timestamps; the roll i-frame window
  is already timed by one shared rule, and the server can check it against the timestamp.

### Things that are hard

- **Mounts.** A ridden creature moves like the player (predicted) but is a creature (server AI when
  unridden). Ownership of its movement must hand over cleanly on mount/dismount.
- **Many creatures on web.** 60 creatures ≈ 6 fps on the web renderer today: the bottleneck is client
  rendering, not the network. Player and mob caps per area must be tuned by the web budget.
- **Physics-heavy moments** (knockdown, leaps, ragdoll death) need the server to decide the outcome
  and the client to play it convincingly a few frames late.

---

## 5. Persistence and saves

| what | today | online target |
|---|---|---|
| Offline survivor | `user://save_1.json` with migrations, sanitizer, `.bak` | Unchanged. |
| Online character | `CharacterStore` journal + snapshot per store dir (tests only) | Same model behind a database. Start: one journal per character on disk (it already works). Hosted: Postgres (or SQLite per server for the small phase), with the journal kept as an append-only audit table. |
| Island state (home, claims, buildings, storage, harvested nodes, carcasses) | Inside the offline save (`home`, `away`, `carcasses`) | New **IslandStore**: one record per persistent island, same journal + snapshot pattern as characters. *Not built yet.* |
| Economy | `EconStore` journal + snapshots | Unchanged pattern; moves to the same database later. |
| Live creatures, AI state | Not saved (respawn from island data) | Same. Tamed pets and tribe members are records, not live state. |

**Sleeping islands.** An empty home island should cost nothing. Anything that "keeps going" while
nobody is there (bonfires burning out, drying racks, crops, tribe workers mining, recruits leaving after
a day) should be computed **from timestamps when the island wakes**, not simulated. The offline save
already does a version of this (7-day catch-up cap). Rule for every new system: *"what does this look
like after N hours of nobody watching?"* must be a formula.

**Recovery.** Journals + idempotent `rid` + snapshots give crash safety per character. Cross-record
operations (trade, deposit, gift) already use the bridge mark-and-recover pattern; island ↔ character
moves (placing a kit, looting storage) need the same treatment.

---

## 6. Cheating surface

| threat | how it would work | defence | status |
|---|---|---|---|
| Item duplication | Replay a request, crash mid-trade, race two clients | Idempotent `rid`, journal-before-reply, provenance uids, bridge recovery | Built for character + market; needed for island storage |
| Fake items / save editing | Edit a local save, inject items | Offline saves never import; online assets exist only on the server | Built (`char.import` refused) |
| Speed / teleport | Modified client moves too fast | Server re-simulates movement; `char.move` 7 m/s budget; reach checks 2.6 m | Partly built |
| Damage hacks | Client claims big hits | Server computes damage from server-side stats and gear | **Open:** `act.attack` takes client numbers today |
| Dodge abuse / god mode | Client ignores hits | Creature → player hits resolved on server with `rolls_dodge()` | **Open:** not wired |
| Gather bots / macros | Script harvests 24/7 | Reach, one-per-harvest timings (already slow), rate limits, anomaly flags on the journal | Timings built; rate limits open |
| Market manipulation | Fresh accounts funnel money, wash trades | Bound starting wallet, 30-min trade lock, listing fees, audit log | Built; tune later |
| PvP exploits (frontier) | Lag switching, aim help, raid griefing | Server-side hits with timestamp checks, raid cost/limits (vision §19) | Future |
| Reading hidden info | Seeing rare spawns or other players' storage | Server sends only what the client may see (interest + permission filter) | Design rule from day one |

Rule of thumb: **anything that can end up in someone else's hands (via market, trade, raid or captive)
must be decided by the server.** Cosmetic and comfort features can be trusted to the client.

---

## 7. The Island Market online

Short version: **one global market, run by one service, reachable from any island.** Listings, money
and items in escrow never live inside an island room; they live in the economy store, so a room can
crash, sleep or be cheated on without touching anyone's sale.

### One market or many?

| option | verdict |
|---|---|
| **One global order book** (recommended) | Everyone sees the same listings and prices, so even a few hundred players make a liquid market. This is what the engine already is: `MarketEngine` has one book, one ledger and one price history, no region field. The UI opens it from the menu anywhere (owner spec 14, Durango style), so it does not depend on which hub channel you are in. |
| A market per harbour hub / room | Prices would differ per channel, and channels are a crowd-control trick, not a place. A small player base split into several books means empty markets. No. |
| Regional markets (Temperate Exchange, Tropic Bazaar, Frontier Post, Northern Depot in `market.json`) | Keep them as **flavour on the NPC side**: they set what the Settlers NPC buyer wants and pays per region. Player listings stay global. Later, if logistics becomes a profession (vision §18), delivery could cost time or a fee by distance; that is a design choice, not a technical need. |

### Where things live

- **Money:** one T-stone wallet per account in the economy ledger. Two kinds of coin already exist:
  *bound* (starting wallet and objective rewards, spend-only on fees and sinks) and *tradable* (earned
  from other players or Settlers). Online, the character's wallet mirrors the ledger (`char.wallet`),
  never the other way round.
- **Items and pets for sale:** to list, the character store *exports* the exact item (with its uid
  and provenance) into the market vault (`VaultBridge`, `act.deposit`). While listed it exists only in
  the vault, not in the seller's bag. A sale moves it to the buyer's **inbox**; "Receive All" pulls it
  into the buyer's bag (`char.receive`). Every hop is journalled, idempotent and crash-recoverable.
- **Pets** sell as caged items (captured wild vs repackaged tame), owner set to the buyer on receive.
- **Tribe members** are not on the market in the current design. Captives and ransom (vision §20)
  will use the same custody pattern later, as server-owned records.

### Players vs NPC prices

- **Player trades** set real prices: fixed listings, auctions (anti-snipe extension), buy orders.
  Fees: 5 % listing fee (a money sink), 3 % sales tax.
- **Settlers** is the NPC buyer (account 0). Every hour it posts buy orders priced from
  `market.json` base prices × regional demand × 0.8, capped at **2,000 T-stones a day** in total. It
  gives a price floor and a way to sell when no player is buying, without printing unlimited money.
  Animals and unstable loot are excluded.
- **Reference price** per item comes from recent trades, ignoring outliers (under 0.25× or over 4×),
  so one silly sale cannot move it.

### Anti-dupe and anti-exploit (already built unless marked)

| exploit | defence |
|---|---|
| Duplicating an item by selling it and keeping it | Export removes it from the bag in the same journalled step; only provenance-stamped items can be listed. |
| Double buy / double receive on a reconnect | Every write op carries a request id (`rid`); a repeat returns the first answer. Withdrawals keep their full answer so a lost reply can be fetched again. |
| Crash halfway through a deposit or withdrawal | `bridge.begin` mark plus `recover()` finishes or undoes the move at boot or right after the fault. |
| Fresh-account money funnels (alts feeding a main) | Starting wallet is bound; 30-minute trade lock on new accounts; wash-trade limit (max 2 trades per account pair per day). |
| Price manipulation | Outlier trades do not move the reference price; max unit price; listing fees cost something. |
| Fake rewards | Objective rewards mint only from server-observed state (`objective.claim` is a system op). |
| Editing local data to fake an item | Offline saves never import; a deposit is the server's own export, never a client's dictionary. |
| Bots flooding listings | **Open:** per-account rate limits and listing caps. |
| Cross-room timing (selling an item still in use in a room) | **Open:** the island room must hand the item back to the character store before export (same rule as any island ↔ character move in §5). |

### What happens offline

- **Offline single-player has no market.** The screens show an honest "Market offline" card (owner
  decision 2026-10-20) and nothing can be sold or bought. This keeps local saves from feeding the
  shared economy.
- **When an online player logs off,** their listings stay up, auctions finish, and buy orders keep
  filling. Proceeds and bought items wait in the inbox (up to 200 entries, kept 7 days per
  `retention_s`; *unknown:* what happens to an unclaimed entry after that: return to the vault is the
  safe default).
- **If the economy service is down,** the market shows offline and islands keep running; nothing that
  touches money happens until it returns.

### Still to decide

- Can you list and receive from anywhere, or only at a harbour or market stall? (Default: anywhere, as
  in spec 14. "Harbour only" makes hubs busier and logistics matter.)
- Does a bought item arrive in your bag, or in home cargo / the harbour, and does distance cost anything?
- How much the Settlers budget grows with the number of players.

## 8. Scaling and cost (rough, mark as unknown until measured)

- **Server shape:** one headless Godot server build (`--headless`, dedicated server export that strips
  textures and audio), running several island instances per process or one per process. Terrain
  collision and navmesh are needed server-side; visuals are not.
- **Unknown #1 — memory and CPU per live island.** Island build is ~2.2 s and includes navmesh; a guess
  is 100-300 MB and a fraction of one core per active island at 30 Hz. Needs a measurement (headless
  run of the home island with 24 creatures + 4 bot clients) before any hosting decision.
- **Back of the envelope** if a live island costs ~200 MB and ~0.15 core: one 4-core / 8-16 GB VM
  (~€15-40/month at budget hosts) holds ~20-30 live islands. Since homes sleep when empty, that is
  roughly **50-150 concurrent players** for a small public test. Bandwidth is small (10-15 Hz snapshots
  of a few dozen entities: a few KB/s per player).
- **Static web build** stays on Vercel (free tier fine), but the 254 MB pack is a bigger barrier to
  online play on phones than the server. Distance loading and pack trimming are already on the list.
- **Growth path:** add island-host VMs behind an orchestrator; a single account/economy service with
  Postgres scales well past what one indie world needs. Managed game-server hosts (Edgegap, Hathora,
  Fly.io machines, a plain VM) all work with headless Godot; pick at the hosting gate.

---

## 9. How existing systems map

Legend: **Ready** = server logic exists; **Seam** = logic is data-driven and only needs routing through
intents; **Refactor** = state or randomness lives in the wrong place; **New** = nothing yet.

| system | rating | what it needs |
|---|---|---|
| Items, bags, instances, backpacks | Ready | Route bag UI actions through `act.equip`/move ops; per-tame inventory ops. |
| Gathering (one per harvest) | Ready/Seam | Harvest node state into IslandStore; client plays the swing, server grants the unit. |
| Butchering + carcass loot radial | Seam | `act.loot` exists; per-cut op, carcass ownership and despawn timer (W2-DEATH plan). |
| Crafting, recipes, cooking roles | Ready/Seam | `act.craft` exists; cooking needs "is this fire lit" from server state. |
| Building, quality, structures, storage | Seam | `act.place` exists; repair, pack up, storage transfer ops; IslandStore. |
| Domains, claims, release land | Seam | `DomainRules` is data-driven; claim/release ops with the same confirm rules. |
| Taming, capture, saddles, pets | Ready/Seam | Ops exist; pet records already owned by account; mounts need movement hand-over. |
| Tribe members (in progress) | **Design now** | Build them as server-owned records like pets (owner, job, needs, gear, potential) and make offline work a timestamp formula. Recruits at the harbour = server-generated offers with expiry. Cheapest moment to get this right is now. |
| Creature AI, natures, enrage, alphas, packs | Refactor (small) | Runs only on the server online. Replace global `randf` in brains with a per-creature seeded RNG so fights replay in tests; clients receive clip + timing. |
| Combat (player), roll, no-spam rule | Seam | `act.attack`/`act.roll` exist; switch damage to server stats; wire creature → player hits. |
| Status effects, stomach, exhaustion, wet | Refactor | Vitals live in `World`/`PlayerSim` only; add server vitals with client display prediction. |
| Weather, lightning, fire-vs-rain, smoke | Refactor | `randf` rolls → server-chosen events per island, broadcast. |
| Day/night clock | Refactor (small) | `Game.time_of_day` from the server clock (global or per island: Milan's taste question, default global). |
| Market (Island Market) | Ready | Needs transport + auth; screens already have the client door (`MarketClient`). |
| Region chat (owner spec 20) | New | Presence + chat service over the same socket. |
| Tutorial island + Orders | Seam | Orders progress per character on the server; town is static data. |
| Saves | Split | Offline keeps `SaveGame`; online uses CharacterStore + new IslandStore. |
| Genetics, island terrain | Ready | Already seeded; just keep it that way. |

---

## 10. Phased path

### Phase 0 — the intent seam (no network, now)

Goal: the single-player game calls the same intents the server answers, so online becomes a transport
swap instead of a rewrite.

- An `IntentClient` interface with a `LocalExecutor` (today's behaviour, writes `SaveGame`) and later a
  `RemoteClient`. Player actions, bag, build, tame, craft call it instead of mutating `World` directly.
- Parity tests: every op gives the same result through `LocalExecutor` and through `CharacterStore`.
- Seeded RNG for brains and weather; a `Clock` abstraction for day/night and timers.
- Design rule for every new package (tribe members first): state as records, offline progress as a
  formula, randomness from a seeded source.
- Cost: moderate, mostly plumbing; touches integrator-only files, so it is an orchestrator package.

### Phase 1 — local co-op (server stays local, per owner decision 2026-10-18)

Goal: 2-4 people on one island through a real server on Milan's Mac or LAN.

- Headless Godot server, `WebSocketMultiplayerPeer`, one island instance.
- Visit a friend's home island; hunt and build together; server-side combat and AI.
- Minimal auth (dev tokens), presence, the market over the socket (the market already exists).
- Gates: two windows + one web client on the same island, latency/loss injection test, server restart
  keeps structures, nodes and pets (STATUS W3 item).

### Phase 2 — small hosted world (hosting gate)

Goal: a public test with tens to low hundreds of players.

- Account service (login), character + island + economy stores in a database.
- Island orchestrator: wake a home island when its owner or a visitor arrives, sleep it when empty.
- Tutorial channels, one harbour hub with channels, region chat, Island Market live.
- Expedition islands per party. Mob/player caps per area.
- Ops basics: logs, crash restarts, backups, a kill switch for the market.

### Phase 3 — MMO features

- Many island hosts, regions, parties and guilds/alliances.
- Frontier PvPvE: persistent outposts, raids with costs and limits, captives with the 72-hour ransom
  (server-owned custody), better recruits at outposts.
- Anti-cheat analytics, moderation tools, maybe WebRTC for faster PvP.

---

## 11. Recommendation and trade-offs

**Recommended:** island instances (option B) + dedicated server-authoritative islands + client
prediction for your own survivor + WebSockets everywhere + offline single-player kept as a separate
local mode. Start with Phase 0 now, because every package that lands without the seam (tribe members,
weather round 2, butchering) adds to the later refactor.

| you get | you give up |
|---|---|
| A market and trades nobody can dupe or forge | Every online player needs a connection; hosting costs money from Phase 2 |
| Cheap servers: empty homes cost nothing | Strangers appear only where we place them (hubs, tutorial, frontier), not everywhere |
| One code path for web, desktop and phones | TCP can hitch on bad mobile networks; fast PvP may later want WebRTC |
| The solo game keeps working offline | Offline survivors never become online ones (two separate progressions) |
| Matches the existing server code and contracts v2 | Phase 0 plumbing delays visible multiplayer by a package or two |

## 12. Unknowns to measure or decide later

- Memory/CPU per live headless island (measure before hosting).
- Web client frame budget with other players + creatures in view (today's 6 fps at 60 creatures).
- Pack size on phones (254 MB) for online onboarding.
- Global vs per-island day/night clock.
- Whether tutorial channels show other new players.
- Home-visit permissions: can visitors gather, build, open storage? (vision §2 lists it as open).
- Raid, captive and ransom rules (vision §19-20 open items) — only needed in Phase 3.

## 13. Questions only Milan can answer

1. **Online and offline: two modes or one?** Recommended: keep offline single-player as its own local
   save forever, and online characters live only on the server (they never mix). The alternative is
   "always online, even solo", which simplifies to one progression but means no play without a
   connection and a server bill from the first public player.
2. **Which multiplayer comes first: friends or strangers?** Recommended: friends first (visit a home
   island, hunt and build together, Phase 1), then the harbour hub, market and chat with strangers
   (Phase 2). The other order leads with the market and chat but delays playing together.
3. **Approve server-authoritative dedicated servers (no player hosting), and a hosting budget for the
   public test?** Recommended: yes, starting around €20-40/month for one VM in Phase 2, with the server
   staying local until then.
