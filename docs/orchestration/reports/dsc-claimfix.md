# dsc: CLAIMFIX - CLAIM moves your land; build ghost under the HUD

**Task:** CLAIMFIX (dsc, 2026-10-21). Report for the production playtest findings of 2026-10-21 in
`docs/orchestration/reports/`. Branch `claude/mmo-claimfix`, worktree `mmo-claimfix`. Nothing pushed, merged or deployed.

## Outcome

Both defects are fixed, each with a headless test that fails on the old code. `game/tests/t_claimfix.gd` prints
`[t_claimfix] PASS`; `tools/smoke.sh` prints `SMOKE PASS`; `t_domain`, `t_ui`, `t_build`, `t_save` and `run_all` pass.

## Defect 1: a second CLAIM

**What it did (before-fix numbers from `game/tests/probe_claimfix.gd`, now kept as a probe).** The home island starts
with the camp plot `[P(-7,1) S(14,14)]`. Walking 12 m east and pressing CLAIM appended `[P(4,10) S(14,14)]` (2 plots for
the survivor). Walking 3 m further and pressing again appended a third: 3 claims, no panel, no confirm, nothing spent
or asked. A press never moved the plot; it **added** a 14x14 anywhere the survivor stood, 3 m from the last one, which
is what lost the claimed land in the playtest (a fresh plot half off the base, the old one still there but now
unreachable from the camp).

**Rule built (PRD `durango-wild-lands-systems-prd.md` 13.1: "First claim 4x4. One additional same-size expansion free.
Further expansions cost T-stones, orthogonal only (no diagonal).")** This build's plot is 14x14 and its first claim is
the camp plot, so a second claim is **one orthogonal expansion** of land already held:
- shares a full edge with land you hold (`IslandClaims.expand_reason`);
- never takes a tile you hold again (self-overlap) and never another survivor's land, never water (existing `block_reason`);
- never moves or drops a plot: plots only ever add, so no building can be orphaned by a press;
- the CLAIM press with land held **asks first**: a panel names what you keep and what EXPAND does, or refuses with the
  reason. Only EXPAND stakes. Close, a second press, Esc or walking off the tile cancels. The stake is spent only on
  the commit.
- the first claim (no plot on this island) stays one tap, the tutorial flow, so `t_domain` and the bot are unchanged
  apart from the success path.

**Files.** `scripts/world/island_claims.gd` (`plot_at`, `block_reason`, `expand_reason`), `scripts/world/island_runtime.gd`
(`claim_plot`, `claim_block_reason`, `claim_expand_reason`), `scripts/ui/claim_panel.gd` (new), `scripts/ui/hunt_hud.gd`
(`open_claim_confirm`, `claim_panel_open`, `claim_panel_text`, `claim_confirm`, `claim_confirm_cancel`, `_refresh_claim_panel`;
the panel closes when you leave its tile or start placing), `scripts/player/player_actions.gd` (`claim` asks when land is
held, `claim_confirmed` commits; the commit re-checks the expansion so a stale panel cannot stake a hop),
`scripts/ui/held_item_slot.gd` (HANDS hides under the panel, which is on a lower canvas layer on a phone).

**Test evidence.** `t_claimfix` before the fix printed 24 FAILs (first: "a second CLAIM press does not take land by
itself (2 claims)", "the press saved no new plot", "FAIL the press opens the confirm panel"). After, it checks: a press
away from the land opens the panel and names the refusal ("a plot must share an edge with your land (no diagonal, no
hop)"), confirming it takes nothing; a press inside the land is refused as overlapping your own land, Close takes nothing;
one plot east the panel offers "EXPAND adds a 14x14 plot at (14, 8), sharing an edge with your land" and EXPAND adds
exactly that plot, keeps the camp plot and saves it; on an unstable island the ask spends no stake and the confirm
spends exactly one.

## Defect 2: the build ghost and its hexes

**What it did (before-fix numbers).** `Game.pointer` is where the finger last was; after tapping the BUILD sheet it is
still on the bottom-left HUD. `begin()` snapped the ghost to the tile under that pointer: ghost at `(-2.5, 13.5)`,
**20.33 m** from the survivor at `(14.9, 24.0)`, cell `(-3,13)`, refused `too_far` - the ghost under the rail. The
ROTATE / PLACE / CANCEL row hung 40 px under the ghost: hex rects at x -81..135, y 894..982 at 1600x900 (CANCEL off the
left edge, all of it below the XP line) and y 375..463 on a 390 px canvas (off the bottom): 4 intersections with HUD
controls at each size (MENU at (22,806,52,60) / (22,296,52,60) and its caption).

**Fix.**
- `BuildPlacer._seat_in_front()`: the ghost starts 2 m in front of the survivor (facing, then ±0.6/±1.2/±1.8 rad, then
  behind, then a 1 m ring out to 6 m) at the first tile `can_place` accepts - valid, inside the claim - and the pointer
  is ignored until it moves, so the opening tap does not drag it back to the HUD button.
  `# ASSUMPTION:` no PRD line fixes the gap; 2 m reads as "in front" at the 15 m zoom and stays inside the 8 m reach.
- `HudLayout.placer_anchor()`: the row takes the anchor nearest the ghost whose three hexagons and captions are inside
  the safe area and off every HUD rect (per-candidate score: off-screen 100, overlap 1). The geometry comes from the
  hexes themselves, so the placement uses the same rects the test and the drawing use.
- `HuntHud._placer_taken()` rebuilds the HUD's taken rects minus the row's own nodes (by node, not by last frame's rect).

**Test evidence.** `t_claimfix` before: "the ghost spawns within 6 m of the survivor (8.35 m)", "the ghost lands on
ground it can be placed on (valid=false reason=too_far)", "the ghost is ahead of where the survivor faces (-6.20 m)",
plus placer rects off the canvas. After: ghost 2.29 m ahead, valid, on a claimed tile; at 1600x900 the row sits at
~701..917 x 752..859 and at 844x390 at ~324..541 x 155..262, with **0 HUD overlaps** at both sizes, every rect inside
the view, every hex a 64 px target. Shots: `claimfix_ghost_844x390.png`, `claimfix_ghost_1600x900.png`,
`claimfix_panel_844x390.png`, `claimfix_panel_1600x900.png` (web renderer, gl_compatibility), taken by
`scenes/dev/claimfix_lab.tscn` (`--lab=claimfix_lab --step=panel|ghost`).

## Other changes, and why

- `game/tests/t_domain.gd`: its success path now calls `claim()` + `claim_confirmed()`, and its free tile is one
  orthogonal plot out from the land held - the old "any dry tile east, 3 tiles apart" is now a refused hop.
- `scripts/ui/held_item_slot.gd`: HANDS hides under the CLAIM panel (it is on a higher canvas layer; the 844x390 shot
  showed it over the panel's Close). It is **not** hidden while placing any more: the row keeps off it.

## Assumptions

- A second claim expands, it does not move and does not add a detached plot (`# ASSUMPTION:` in
  `island_claims.gd:expand_reason`; PRD 13.1's expansions are the only second-claim rule in the docs).
- Ghost gap 2 m, search out to 6 m (`build_placer.gd`).
- The panel's copy and size (340x196 desktop over the centre, 272x166 on a phone left of the map column).

## What the next agent needs

- The 14x14 vs 4x4 difference and PRD 13.1's paid expansions (T-stones, cap) are still not modelled; a third expansion
  is free here as before. Marked `# ASSUMPTION:` at `player_actions.gd:claim`.
- Old saves: unchanged format, `home_claims` / `away.claims` rows are still `[x, z, w, d]`; `SaveSanitizer` untouched,
  `t_save` passes.
- Godot: run `--import` once after pulling (new `class_name ClaimPanel`); run tests with
  `gslot.sh perl -e 'alarm 150; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_claimfix.gd`.
