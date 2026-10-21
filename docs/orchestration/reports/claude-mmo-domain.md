# DOMAIN report: "<name>'s Domain" banner, owner portraits, dotted yellow claim edge (spec 18)

Branch `claude/mmo-domain` (work tree `.claude/worktrees/mmo-domain`), cut from `claude/mmo-overhaul` at `b0090082`.
Owner (spec 18): "When entering player's claimed regions, it says 'Player's Domain' with their profile picture."
References: `docs/reference/durango-domain-claims.webp`, `durango-house-4x4.webp` (dotted yellow claim line on the
ground) and `durango-island-map.webp` (spec 15's "Zeekuel's Domain" label: dark pill, round portrait, gold name).
No credits spent. Hooks: `docs/orchestration/reports/claude-mmo-domain-hooks.patch`. It is applied, uncommitted, in the work tree,
and every gate below ran with it applied.

## Repro on the base (before)

`domain_lab` (new, windowed) boots the home island with the real HUD. It walks the survivor from 5 tiles outside the
camp claim's +z edge to 3 tiles inside (`nav_to`, a real walk), waits, walks out and back in, and records each step.
Run on `b0090082` plus only the lab, at 1600x900 Forward+, 1600x900 gl_compatibility and 844x390 gl_compatibility:

- `[domain] entered tile=(2, 11) claimed=true banner=false` and `reentered ... banner=false` in all three: **no
  banner of any kind on entry**. Exit 1 (`FAIL entered: banner false, want true`).
- `[domain] edge: ClaimBoundary lines verts=112 colour=(0.72, 0.74, 0.58, 0.3)`: an edge mesh existed, but it was
  1 px `PRIMITIVE_LINES` in a 30 % grey-green. In the shots it cannot be seen at normal size in either renderer.
  At 2x zoom a few faint grey ticks show (`before/fwd1600/outside_zoom.png`). The CLAIM hex vanishing was the only
  sign that the survivor was on claimed land.
- The Forward+ base run also logged one SCRIPT ERROR from a bug in the lab's own mesh probe
  (`surface_get_primitive_type` on an ImmediateMesh). It is fixed in the lab, and the glc runs have the edge line above.
- No other player's land existed: claims had no owner (`IslandRuntime.claims: Array[Rect2i]`, all the survivor's).

Shots (scratchpad, not in the repo): `.../scratchpad/domain/before/{fwd1600,glc1600,glc844}/{outside,entered,staying,reentered}_<w>x<h>.png`.

## What shipped

New files (committed):
- `game/scripts/ui/domain_banner.gd` (DomainBanner, RefCounted, 107 lines). `tick(delta, rt, at)` reads whose land the
  survivor stands on through `rt.owner_at`. When the owner changes to a non-empty owner, the banner shows for
  3.5 s with a 0.35 s fade in and out. Rules:
  - Staying inside shows it once. Leaving for 0.5 s or more and coming back shows it again. A shorter step over the
    edge (walking along it) does not.
  - Stepping straight from one owner's land into another's shows the new owner.
  - Island loads, voyages, respawns and teleports (a move of more than 6 m in one frame) set a baseline and show nothing.
  - One long frame cannot use up the banner: each frame advances it by at most 0.1 s. A loaded machine once used
    up the whole 3.5 s in one frame.

  `draw(hud)` draws, in order: a dark pill (radius h/2, alpha 0.9), the portrait in a round frame on its left end
  (it stands out above and below the pill, with a warm-white ring), the name in gold `#F5B545` and "'s Domain" in white.
  - Sizes: 22 px text, 46 px pill and a 54 px portrait on desktop; 17 / 34 / 40 px on a compact canvas.
  - Placement starts at top centre inside the safe insets, then moves to the nearest free spot straight down
    (`UiTokens.free_spot` against `HuntHud.taken_rects()`: vitals, minimap, map text, quest card, target plate,
    level-up, hexes, the survivor's figure).
  - It registers `drawn_blocks["domain"]`, so the toasts, notices and world pills drawn after it keep off it.
  - Long names are cut with an ellipsis.
- `game/scripts/ui/player_portrait.gd` (PlayerPortrait). `texture_for(owner, host)` caches a portrait per owner id.
  - Own land: one render of the live survivor (gear included). Each visible mesh is baked in its current pose
    (`bake_mesh_from_current_skeleton_pose`), so no skeleton or sockets are copied and nothing warns.
  - The render is lit in a 128 px SubViewport with its own world and framed on the Head -> HeadTop_End bone line
    from the face side. The pixels are copied to an ImageTexture and the viewport is freed.
  - Others, and headless runs: a neutral grey head-and-shoulders silhouette, generated once.
  - The silhouette also shows until the render lands (two frames).
- `game/scripts/world/claim_outline.gd` (ClaimOutline). Dotted yellow edge (`#F5D15C`, alpha 0.85, unshaded):
  - One 0.45 x 0.13 m flat quad per metre of outline, 7 cm above the ground, or above the sea where an edge crosses
    the shallows.
  - A dash is drawn only where the tile across belongs to a different owner (or nobody). Touching plots of one
    owner read as one domain, and a border between two owners is drawn once.
  - One mesh for the whole island. `vertices(rt)` is the pure data; tests read it because headless meshes keep no
    arrays.
- `game/scripts/dev/domain_lab.gd` + `game/scenes/dev/domain_lab.tscn`: the repro lab above. Steps:
  - outside, entered, staying and reentered on your own land;
  - neighbour: another owner "Rowan" gets a 12x12 plot 10 tiles east of the camp claim, and the survivor walks in.

  Each step prints `banner`, `text`, `rect`, `age`, `owner`, `fps` and `max_frame` and saves a shot. It also logs
  every banner and inside/outside transition with a timestamp, and checks that the banner is inside the view and
  clear of the vitals, quest card, map text, plate and minimap. It prints `[domain] PASS ...` (exit 0) or FAIL lines.
- `game/tests/t_domain.gd`: see Test.

Hooks (`claude-mmo-domain-hooks.patch`, 3 files, `git apply --check` clean on `claude/mmo-overhaul` `b0090082`,
`claude/mmo-invui`, `claude/mmo-hud-daynight`, `claude/mmo-exchange`; on `claude/mmo-int` it applies with a 2-line offset):
- `scripts/world/island_claims.gd`:
  - `SELF_ID := "self"`.
  - `owner_at(rt, tile)`: your claims first (`{"id": "self", "name": display_name(), "own": true}`), then other
    players' rows, else `{}`. This is the one function that reads claim ownership.
  - `set_others(rt, rows)`: replaces the other players' claims with `[{"rect": [x, z, w, d], "owner": {"id", "name"}}]`.
    It drops malformed rows, empty or forged `"self"` ids and zero sizes, then redraws.
  - `_rebuild_claim_mesh` now builds `ClaimOutline.make_instance()` / `ClaimOutline.build(rt)`. The 40-line line-mesh
    builder is gone.
- `scripts/world/island_runtime.gd`:
  - `var other_claims: Array[Dictionary]` (only `set_others` writes it).
  - `owner_at(tile)` and `set_other_claims(rows)` forwards.
  - The unused `_claim_mat` is dropped.
- `scripts/ui/hunt_hud.gd`, 3 lines:
  - `var _domain := DomainBanner.new()`;
  - `_domain.tick(delta, World.runtime, player.global_position)` after `_events.tick`;
  - `_domain.draw(self)` just before the toasts and notices.

Claim data stays the source of truth: `rt.claims` (yours, saved as before) plus `rt.other_claims`. Nothing about
saving changed. Online, the server's claim rows go through `IslandRuntime.set_other_claims` / `IslandClaims.set_others`.
That is the only entry point, and `owner_at` the only reader. `is_claimed` (build permission) still means "yours":
another owner's land is not yours to build on (tested).

## Test (`game/tests/t_domain.gd`)

Run: `gslot.sh perl -e 'alarm 600; exec @ARGV' Godot --headless --path game --script res://tests/t_domain.gd`.
It loads the home island with the real HUD and checks:
- The real HUD:
  - no banner outside;
  - walking in tile by tile draws `drawn_blocks["domain"]` reading "Tess's Domain";
  - the banner is inside the view and clear of the vitals, quest card, map title and text, statuses, level line,
    nameplate and minimap.
- `owner_at`: your tile is yours, an unclaimed tile is nobody's.
- Timing:
  - entering shows it, for 2-6 s (measured 3.5 s);
  - 10 more seconds inside: never again;
  - out 0.6 s and back in: shown again;
  - a 0.1 s step over the edge and back: not shown.
- Arrivals:
  - arriving on the island inside your claim: nothing;
  - a 10 m teleport in: nothing;
  - walking out and back after that: shown;
  - one 5 s frame right after entering: still shown.
- Another owner:
  - Rowan's 12x12 plot touching the camp plot rebuilds the mesh;
  - his tile is his (`own` false) and not yours to build on;
  - stepping from your land into his shows "Rowan's Domain", and stepping back shows yours;
  - the border between you is drawn once (72 vertices = 12 dashes);
  - clearing his rows frees his land.
- Malformed rows are dropped: a short rect, no owner, an empty id, a forged `"self"`, a zero size, a string, a number.
- The outline:
  - it is yellow;
  - one camp plot gives 56 dashes (336 vertices), all 0-20 cm above the ground;
  - staking a touching plot rebuilds the mesh, leaves no dash on the shared line and grows the outline by exactly
    the new plot's three outer sides.
- Portraits: every owner gets one, they are cached per owner, an unknown owner gets the silhouette, and the
  silhouette has a head on its backdrop.

**Fails on the old code**: in a throwaway tree at `b0090082` with only `t_domain.gd` copied in:
`[t_domain] hud entry banner=false`, `FAIL walking into your own claim: the HUD draws no "Tess's Domain" banner`,
`FAIL spec 18 is not built: domain_banner.gd false, claim_outline.gd false, player_portrait.gd false,
IslandRuntime.owner_at false`, `FAIL count=2`, exit 1.
With the package and hooks: `[t_domain] PASS`, exit 0.

## Gates (final code `d5e4a3a5` + hooks applied, after `--import`)

| gate | result |
|---|---|
| every `game/tests/t_*.gd` (20) | all exit 0 with PASS: t_ai, t_build, t_canim, t_combat, t_domain, t_harbour (`islands=15`), t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (5 deliberate SCRIPT ERRORs), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons (`ids=169 files=114 ...`), t_web; 0 SCRIPT ERROR elsewhere |
| run_all | `[tests] PASS`, exit 0 |
| smoke (`tools/smoke.sh --no-import` through gslot) | `SMOKE PASS` |
| domain_lab 1600x900 Forward+, 1600x900 glc, 844x390 glc (windowed) | `[domain] PASS steps=outside,entered,staying,reentered,neighbour`, exit 0, 0 SCRIPT ERROR, no new warnings (the nav-bake and camera-interpolation warnings are on the base too) |
| ui_real_capture_lab 844x390 glc and 1600x900 glc (HUD gate; the HUD is hooked) | `[uireal] PASS screens=hud,...,camp_workbench,...,resize_back`, exit 0 |

One failure found and fixed on the way: before the teleport rule, ui_real_capture_lab teleported the survivor into
the camp, the banner came up and took the camp labels' spot (`FAIL camp_workbench: at least 2 camp labels ...
(labels 1)`). A teleport is now an arrival, and both sizes pass.

## Shots looked at (after)

Scratchpad `.../scratchpad/domain/final4/{fwd1600,glc1600,glc844}/{outside,entered,staying,reentered,neighbour}_<w>x<h>.png`,
not in the repo. Each was opened next to durango-domain-claims.webp, durango-house-4x4.webp and durango-island-map.webp:
- Edge: the camp plot shows as a diamond of yellow dashes on the grass, like the references' dotted line. It reads at
  1600x900 in both renderers and at 844x390. Rowan's plot edge runs through the river bank and over the water. It is
  slightly brighter and more even than Durango's, which is lit and worn into the ground.
- Banner, 1600x900 (Forward+ and glc look the same):
  - top centre between the vitals and the quest card;
  - matches the map label: the survivor's real face in a round frame on a dark pill, "Milan" gold, "'s Domain" white;
  - Rowan gets the grey silhouette.
- Banner, 844x390: under the quest card and above the survivor's head, clear of the vitals, minimap, HANDS and camp
  labels. An earlier 38 px version did not fit there and dropped below the survivor; the compact size is now 40 px tall.
- staying: no banner; reentered: the banner again.
- Portrait crops: `final4/fwd1600/banner_zoom.png`. A rest-pose attempt showed only hair (dropped). The face is
  framed on the live pose, eyes level with the portrait's centre.

## Assumptions

1. Arriving is not entering: an island load, a voyage, a respawn, or any move over 6 m in one frame sets a baseline
   without a banner. Only walking or riding across the edge shows it. The spec says "entering"; on a teleport the
   banner covered the camp labels.
2. Your own land shows the banner too ("Milan's Domain"). Spec 18 says "another player's (or your own)".
3. A domain is "left" after 0.5 s outside, so walking along the edge does not flash it.
4. On screen 3.5 s with 0.35 s fades. There is no reference for the timing.
5. On desktop it sits at top centre and slides under the target plate when one shows. On a landscape phone it sits
   under the quest card and above the survivor. It never covers the quest card (the plate and level-up banner do
   take that band). There is no reference for the HUD placement; the label's look is the spec 15 map label.
6. Gold `#F5B545` name, white "'s Domain", a 90 % black pill and a warm-white portrait ring, sampled by eye from
   durango-island-map.webp.
7. Every owner's edge is the same yellow (the references only show one colour).
8. On unstable islands the landing camp is already claimed for the survivor (an existing assumption in
   IslandClaims.setup), so walking into it shows "<you>'s Domain".
9. Portraits:
   - Yours is rendered once per session from the look at first entry. Gear changed later is not re-rendered.
   - Other owners get the silhouette until the server sends appearances.
   - No portrait existed on the base (`claude/mmo-overhaul`). INVUI's CharacterScreen renders the raw survivor.glb
     on its unmerged branch, so this package does not depend on it.

## For the next agent / integrator

- Apply `claude-mmo-domain-hooks.patch` after merging the branch (it touches W1-UI's hunt_hud.gd with 3 lines and the
  island claims code). The new classes need one `--import` (ClaimOutline, DomainBanner, PlayerPortrait).
- Online (W3): send claim rows to `World.runtime.set_other_claims(rows)` on island join and on every change.
- INVUI's `CharacterScreen._portrait_texture` could call `PlayerPortrait.texture_for({"id": "self", "own": true}, self)`
  to show the real look (gear included) instead of the bare survivor.glb.
- Not done (outside this package's scope):
  - the spec 15 map screen's "<name>'s Domain" label (PlayerPortrait and the colours are ready for it);
  - spec 18's third bullet, name plates on buildings inside a domain (HudPills already draws them within 8 m).
- Found, not fixed: claiming is not refused on another owner's land. `claim_at` only checks dry land, and on an
  unstable island `PlayerActions.claim` spends the claim_stake before `claim_at` can refuse, so a refused claim
  loses the stake. That bug is already on the base. Offline there are no other owners. The server (W3) should
  refuse overlaps, and the stake should be spent only after `claim_at` succeeds.
- Incident: one of my commands ran Godot in the main checkout by mistake (Godot ran there with `--path game` after a
  `cd` into a throwaway tree failed). It failed at once
  ("Can't load script res://tests/t_domain.gd": the file is not in the main checkout). No file under the main
  checkout's `game/` changed (checked with `find -newermt`). The owner's `save_1.json` is untouched (Oct 18). It did
  write `logs/godot.log` in the owner's user dir and rotated the previous log there to a timestamped name.
