# W3-EXCHANGE report (Claude): Island Market screens

Branch `claude/mmo-exchange` (worktree `.claude/worktrees/mmo-exchange`), stacked on `claude/mmo-econ` 5cea0a58 plus ECON's
hooks patch (commit "Apply ECON hooks (EXCHANGE base)" 20b83d37). ECON is not merged into `claude/mmo-overhaul` yet.

## Design step (done)

- Design: `docs/orchestration/mmo/exchange-spec.md` (screens, components, data, error text, hooks H0-H4, build plan B1-B4,
  14 measurable gates, assumptions A1-A12 with the docs each was checked against).
- Transport, decided: the screens talk only to `MarketClient` (`game/scripts/ui/market/market_client.gd`), whose calls are
  `VaultBridge.client()` ops. Base class = offline (today's single-player build: honest "Island Market offline", no ops);
  `NetMarketClient` (B1) = the socket over `Game.net` once W1-INT merges NET and the server relay (also the dev local server:
  `--server` plus `--online=ws://127.0.0.1:<port>`); `LocalMarketClient` = labs and tests only, labelled "Local test server:
  not the live market". The owner settled authority on 2026-10-20 (STATUS 548059bc), so there is no owner question.
- Skeletons:
  - `game/scripts/ui/market/market_client.gd`, `local_market_client.gd` (the transport seam, working).
  - `game/scripts/dev/market_harness.gd`: a deterministic local economy over the real VaultBridge. Every item, coin and
    listing comes from client ops or the server tick: gather/loot/craft/tame/capture, selling to Settlers' orders for
    tradable coins, deposit, list, buy. ECON's default rules unchanged; the trade lock is waited out on the harness clock.
    The scene: 3 single branches, a bone, a crafted Improvised Stone Knife (Trader2), a bonded compsognathus and 3 captured
    cages (Trader3), and the viewer with a 123-coin wallet (20 bound), 1 active, 1 sold, 1 expired listing, and a bought
    bone plus the expired berry waiting in the vault.
  - `game/scripts/dev/market_ui_lab.gd` + `game/scenes/dev/market_ui_lab.tscn`: `--screen=buy|buy_taming|sell|my_market|confirm|offline`;
    for now it seeds the economy and prints/shows what the screens will read (B1 replaces `_show()` with the real screen).
  - `game/tests/t_exchange.gd`: offline client, relay refusals (act.deposit is unauthorized), rid on writes, the seeded
    scene (one listing per instance, distinct uids, bound + tradable wallet, My Market states, vault waiting) and
    determinism (two fresh harnesses give the same listings). PASS; it prints 10 `PENDING` gates for B1-B4.

## Checks run (design step)

See the commit message of the design commit for the quoted lines; summary: every `game/tests/t_*.gd` and `run_all.gd`,
`tools/smoke.sh --no-import`, and `market_ui_lab` windowed at 1600x900 gl_compatibility (screen=buy) and 844x390
gl_compatibility (screen=offline) with 0 SCRIPT ERROR lines. The shots show the skeleton's text dump over the island
("Private Grassland" from island data), as expected before B1.

## For the next agent (B1)

- Build in `game/scripts/ui/market/` per spec §3; write the hooks patch (H0 hunt_hud menu row, H1/H2 MarketQuery sorts and
  filters) as exact compiling diffs; turn the B1 `PENDING` lines in t_exchange into checks.
- INVUI has no components yet (`claude/mmo-invui` holds only W2-INV); mark every look component `# swap: INVUI <Component>`.
- ICONS2's `captured_animal` / `tamed_animal` renders are not on this base; until they merge both icons are the same
  placeholder, so rows tell apart by the "B" badge and the "Captured" name.
- Risks: `market.mine` can exceed NET's 64 KiB frame (tell W1-INT/ECON); H1-H3 touch ECON-owned files while ECON is still
  being fixed, so the patch may need a rebase at merge.

Credits spent: none. Meshy/Tripo not used.
