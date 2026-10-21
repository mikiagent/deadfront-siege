# DOMAIN report: "<name>'s Domain" banner, owner portraits, dotted yellow claim edge (spec 18)

Branch `claude/mmo-domain` (work tree `.claude/worktrees/mmo-domain`), cut from `claude/mmo-overhaul` at `b0090082`.
Owner (spec 18): "When entering player's claimed regions, it says 'Player's Domain' with their profile picture."
References: `docs/reference/durango-domain-claims.webp`, `durango-house-4x4.webp` (dotted yellow claim line on the
ground) and `durango-island-map.webp` (spec 15's "Zeekuel's Domain" label: dark pill, round portrait, gold name).
No credits spent. Hooks: `docs/orchestration/reports/claude-mmo-domain-hooks.patch`. It is applied, uncommitted, in the work tree.
The pre-merge gates below ran in a throwaway tree of the branch with the patch applied (`mkscratch.sh fix-domain`).

## Pre-merge fixes (orchestrator ruling after review and the blind judge, 2026-10-21)

The blind judge preferred DOMAIN 3-1 on desktop but called it not phone-ready. The ruling asked for seven changes; all
are on the branch, each has a check in `t_domain.gd` that fails on the reviewed code (`723e7921`), and the hooks patch
is regenerated against `claude/mmo-overhaul` `946da955`.

1. **Phone slot.** On a landscape phone the banner is now a slim toast (26 px tall, 15 px text, the portrait inside
   the pill) in a slot of its own: the top of the band between the vitals and the minimap, above the quest card
   (844x390: `[P: (411, 6), S: (160, 26)]`, quest card from y 34). If the target plate or the level-up banner holds
   that slot, the banner is not drawn. It never drops into the play area over the survivor or a mount. Desktop is
   unchanged (top centre between the vitals and the quest card).
2. **Your edges and other players' edges look different.** Yours are long yellow dashes (0.45 m, `#F5D15C`). Other
   players' are short salmon dots (0.25 m, `#FF9478`). Of other players' claims, only the 4 nearest the survivor draw.
   They are picked again whenever the survivor moves onto a new tile, so a crowded island never becomes a full-screen
   lattice (lab `crowd` step: `36 other claims, 4 drawn`).
3. **Night and water.** The dashes now use a lit, opaque material with vertex colours read as sRGB:
   - They dim with the ground at night. They used to be unshaded and kept their day colour all night.
   - The material faces the dashes up, wound clockwise (Godot's front face). The first lit build wound them
     counter-clockwise; Godot then flipped their normals and drew them black.
   - Over rivers the dashes sit 7 cm above the water plane (`HarbourSite.WATER_Y`, the plane IslandTerrain draws).
     They were already at that height, but they were alpha-blended and the water drew after them and washed over
     them. Opaque dashes write depth, so the water can no longer cover them.
4. **Rebuild cost.** `ClaimOutline.dashes` paints one tile-to-owner lookup (an `Image`, `fill_rect` per claim) before
   the loop; it no longer calls `owner_at` (a scan of every claim) twice per dash. `set_others` cuts each server rect
   to the island and drops rows that miss it. 401 claims rebuild in **1.4-2.5 ms** headless (five runs). On the reviewed code the same
   rows took **167-232 ms** (three runs) and drew every edge.
5. **Self portrait.** The cached portrait is keyed by a stamp: name, occupation, worn equipment and `World.look`
   (CHARCREATE's field, null until it merges). A save load, a new survivor or an equipment change gives a new stamp,
   which drops the picture, and the next banner renders it again. A render still in flight when the stamp changes is
   thrown away. This needs no hooks in `world.gd`, `save_game.gd` or `player_equipment.gd`. `player_portrait.gd` stays
   thin: when CHARCREATE's `PortraitService` lands, the own branch of `texture_for` becomes
   `PortraitService.of_player()` (noted in its header).
6. **Claims.** `IslandClaims.claim_at` refuses a plot that would take any tile another player holds.
   `PlayerActions.claim` (hook) now does three things in order:
   - checks a stake is in the bag;
   - claims;
   - spends the stake (and the free first plot) only after the claim succeeded.

   A refused claim used to lose the stake.
7. **Banner timing.**
   - Switching owners is debounced the same way as leaving. From open ground a domain still shows at once. Out of a
     domain, whether onto open ground or into the next owner's land, the switch counts only after 0.5 s away. Walking
     along a border two owners share no longer flashes either banner.
   - An island change takes a showing banner down.

**Fails on the old code.** I ran the new `t_domain.gd` in a throwaway tree of `723e7921` plus the old hooks. It exits 1
with `FAIL count=15`, plus SCRIPT ERRORs where it calls the new `ClaimOutline.dashes`. Decisive lines:
`FAIL walking along a shared border does not flash either banner (20 ticks showing)`,
`FAIL sailing to another island takes the banner down`,
`FAIL the claim edge is lit and opaque (shading 0, transparency 1)`,
`FAIL 400 claims rebuild in under 20 ms (217.16 ms)`,
`FAIL a row reaching off the island is cut to it ([P: (76, 0), S: (12, 12)])`,
`FAIL a plot on another player's land is refused`,
`FAIL claiming on another player's land keeps the stake (1 -> 0)`,
`FAIL equipping gear drops your cached portrait`,
`FAIL on a landscape phone the banner sits above the quest card ([P: (328.0, 162.4512), S: (188.0, 40.0)], quest [P: (422.0, 34.0), S: (240.0, 72.0)])`,
`FAIL on a landscape phone the banner is clear of the survivor ([P: (328.0, 162.4512), S: (188.0, 40.0)], [P: (503.6332, 97.86946), S: (44.0, 65.2737)])`.
With the fixes: `[t_domain] crowd: 401 rows, rebuild 1.61 ms`, `[t_domain] phone view=(844.0, 390.0) banner=[P: (411.0, 6.0), S: (160.0, 26.0)] quest=[P: (422.0, 34.0), ...]`,
`[t_domain] PASS`.

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
- `game/scripts/ui/domain_banner.gd` (DomainBanner, RefCounted). `tick(delta, rt, at)` reads whose land the
  survivor stands on through `rt.owner_at`. When the owner changes to a non-empty owner, the banner shows for
  3.5 s with a 0.35 s fade in and out. Rules:
  - Staying inside shows it once. Leaving for 0.5 s or more and coming back shows it again. A shorter step over the
    edge (walking along it) does not.
  - Crossing from one owner's land into another's shows the new owner after 0.5 s on it (fix 7), so a shared
    border does not flash.
  - Island loads, voyages, respawns and teleports (a move of more than 6 m in one frame) set a baseline and show
    nothing; an island change also takes a showing banner down.
  - One long frame cannot use up the banner: each frame advances it by at most 0.1 s. A loaded machine once used
    up the whole 3.5 s in one frame.

  `draw(hud)` draws, in order: a dark pill (radius h/2, alpha 0.9), the portrait in a round frame on its left end
  (it stands out above and below the pill, with a warm-white ring), the name in gold `#F5B545` and "'s Domain" in white.
  - Sizes: 22 px text, 46 px pill and a 54 px portrait on desktop; on a landscape phone a slim 15 / 26 px toast with
    the portrait inside the pill (fix 1); 17 / 34 / 40 px on a portrait phone.
  - Desktop placement starts at top centre inside the safe insets, then moves to the nearest free spot straight down
    (`UiTokens.free_spot` against `HuntHud.taken_rects()`: vitals, minimap, map text, quest card, target plate,
    level-up, hexes, the survivor's figure). On a landscape phone it takes its slot at the top of
    `HudLayout.centre_band`, above the quest card, or is not drawn while something holds the slot.
  - It registers `drawn_blocks["domain"]`, so the toasts, notices and world pills drawn after it keep off it.
  - Long names are cut with an ellipsis.
- `game/scripts/ui/player_portrait.gd` (PlayerPortrait). `texture_for(owner, host)` caches a portrait per owner id.
  - Own land: one render of the live survivor (gear included), rendered again after a save load, a new survivor or
    an equipment change (fix 5). Each visible mesh is baked in its current pose
    (`bake_mesh_from_current_skeleton_pose`), so no skeleton or sockets are copied and nothing warns.
  - The render is lit in a 128 px SubViewport with its own world and framed on the Head -> HeadTop_End bone line
    from the face side. The pixels are copied to an ImageTexture and the viewport is freed.
  - Others, and headless runs: a neutral grey head-and-shoulders silhouette, generated once.
  - The silhouette also shows until the render lands (two frames).
- `game/scripts/world/claim_outline.gd` (ClaimOutline, the `ClaimBoundary` MeshInstance3D). A dotted edge on the
  ground, lit and opaque, vertex-coloured (fixes 2-4):
  - Yours: one 0.45 x 0.13 m yellow (`#F5D15C`) quad per metre of outline. Other players': 0.25 m salmon (`#FF9478`)
    dots. Each sits 7 cm above the ground, or above the water plane where an edge crosses a river or the shallows.
  - A dash is drawn only where the tile across belongs to a different owner (or nobody). Touching plots of one
    owner read as one domain, and a border between two owners is drawn once (in yours when it is yours).
  - Whose each tile is comes from one lookup painted before the loop. Of other players' claims only the
    `NEAREST` (4) to the survivor draw; `_process` picks them again when the survivor's tile changes.
  - One mesh for the whole island. `dashes(rt, others)` is the pure data (`[vertices, colours]`); tests read it
    because headless meshes keep no arrays.
- `game/scripts/dev/domain_lab.gd` + `game/scenes/dev/domain_lab.tscn`: the repro lab above. Steps:
  - outside, entered, staying and reentered on your own land;
  - neighbour: another owner "Rowan" gets a 12x12 plot 10 tiles east of the camp claim, and the survivor walks in;
  - crowd: 36 plots of 36 owners around it; the log prints how many draw.

  `--tod=0.92` runs it at night.

  Each step prints `banner`, `text`, `rect`, `age`, `owner`, `fps` and `max_frame` and saves a shot. It also logs
  every banner and inside/outside transition with a timestamp, and checks that the banner is inside the view and
  clear of the vitals, quest card, map text, plate, minimap and the survivor, and on a landscape phone above the
  quest card. It prints `[domain] PASS ...` (exit 0) or FAIL lines.
- `game/tests/t_domain.gd`: see Test.

Hooks (`claude-mmo-domain-hooks.patch`, 4 files). It was regenerated against `claude/mmo-overhaul` `946da955`, and
`git apply --check` passes there with no offset. On `claude/mmo-domain` it applies with line offsets only, which is
how the throwaway gate tree gets it:
- `scripts/world/island_claims.gd`:
  - `SELF_ID := "self"`.
  - `owner_at(rt, tile)`: your claims first (`{"id": "self", "name": display_name(), "own": true}`), then other
    players' rows, else `{}`. This is the one function that reads claim ownership.
  - `set_others(rt, rows)`: replaces the other players' claims with `[{"rect": [x, z, w, d], "owner": {"id", "name"}}]`.
    It drops malformed rows, empty or forged `"self"` ids and zero sizes, cuts each rect to the island and drops
    those that miss it, then redraws.
  - `claim_at` refuses a plot that would take any tile another player holds.
  - `_rebuild_claim_mesh` now adds a `ClaimOutline.new()` and calls its `rebuild(rt)`. The 40-line line-mesh
    builder is gone.
- `scripts/world/island_runtime.gd`:
  - `var other_claims: Array[Dictionary]` (only `set_others` writes it).
  - `owner_at(tile)` and `set_other_claims(rows)` forwards.
  - The unused `_claim_mat` is dropped.
- `scripts/ui/hunt_hud.gd`, 3 lines:
  - `var _domain := DomainBanner.new()`;
  - `_domain.tick(delta, World.runtime, player.global_position)` after `_events.tick`;
  - `_domain.draw(self)` just before the toasts and notices.
- `scripts/player/player_actions.gd` `claim()`: it checks for the stake first, then claims, then spends the stake (and
  the free first plot) only once the claim succeeded.

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
  - 0.6 s on his land shows "Rowan's Domain", and 0.6 s back on yours shows yours;
  - the border between you is drawn once, in yellow (72 vertices = 12 dashes); his other three sides are salmon;
  - clearing his rows frees his land.
- A shared border walked along (a step either side every 0.2 s for 4 s) shows neither banner; ticking with another
  runtime (an island change) takes a showing banner down.
- Malformed rows are dropped: a short rect, no owner, an empty id, a forged `"self"`, a zero size, a string, a
  number, a rect off the island.
- The outline:
  - yours is yellow, other players' differ in colour and dash length;
  - the material is lit, opaque, vertex-coloured, sRGB; every dash triangle faces up;
  - one camp plot gives 56 dashes (336 vertices), all 0-20 cm above the ground;
  - staking a touching plot rebuilds the mesh, leaves no dash on the shared line and grows the outline by exactly
    the new plot's three outer sides.
- A crowd: 400 plots tiling the island plus one reaching 8 tiles off its edge. Every row is kept, the off-island
  one is cut to the island, the rebuild takes under 20 ms, only the 4 nearest draw, and they are the nearest;
  after a teleport to a corner the next frame picks the 4 nearest there.
- Claims: a plot on another player's land, or reaching into it, is refused and adds nothing. On an unstable island
  with the free plot used, `PlayerActions.claim` on his land keeps the claim stake, and a claim on free dry land
  spends it.
- Portraits: every owner gets one, they are cached per owner, an unknown owner gets the silhouette, and the
  silhouette has a head on its backdrop. Your cached portrait stays while nothing changes and is dropped by an
  equipment change and by a new occupation (what a save load or a new survivor sets).
- The phone HUD: at 844x390 the banner sits above the quest card and clear of the survivor.

**Fails on the old code** (first build): in a throwaway tree at `b0090082` with only `t_domain.gd` copied in:
`[t_domain] hud entry banner=false`, `FAIL walking into your own claim: the HUD draws no "Tess's Domain" banner`,
`FAIL spec 18 is not built: domain_banner.gd false, claim_outline.gd false, player_portrait.gd false,
IslandRuntime.owner_at false`, `FAIL count=2`, exit 1.
With the package and hooks: `[t_domain] PASS`, exit 0. For the pre-merge fixes, see "Fails on the old code" at the
top of this report.

## Gates (pre-merge fixes: `8f58662e` + hooks, throwaway tree, after `--import`)

Tree: `mkscratch.sh fix-domain claude/mmo-domain docs/orchestration/reports/claude-mmo-domain-hooks.patch`. All four
hunks applied cleanly ("Applied patch to 'game/scripts/world/island_claims.gd' cleanly.", and the same for the other
three). The import exited 0. The patch also passes `git apply --check` on `claude/mmo-overhaul` `809be2e8` (exit 0, no offsets).

| gate | result |
|---|---|
| every `game/tests/t_*.gd` (20) | all exit 0 with PASS: t_ai, t_build, t_canim, t_combat, t_domain, t_harbour (`islands=15`), t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (its 5 deliberate SCRIPT ERRORs, each announced by the test), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons (`ids=169 files=114 ...`), t_web; 0 SCRIPT ERROR elsewhere |
| t_domain decisive lines | `[t_domain] crowd: 401 rows, rebuild 1.35 ms, island 160 tiles, last row [P: (76, 0), S: (4, 12)]`; `[t_domain] phone view=(844.0, 390.0) banner=[P: (411.0, 6.0), S: (160.0, 26.0)] quest=[P: (422.0, 34.0), S: (240.0, 72.0)] ...`; `[t_domain] PASS` |
| run_all | `[tests] PASS`, exit 0 |
| smoke (`tools/smoke.sh --no-import` through gslot) | `SMOKE PASS`, exit 0 |
| domain_lab, windowed, day (`--tod=0.38`) and night (`--tod=0.95`): 1600x900 Forward+, 844x390 gl_compatibility | all four `[domain] PASS tod=... steps=outside,entered,staying,reentered,neighbour,crowd`, exit 0, 0 SCRIPT ERROR; every crowd step `36 other claims, 4 drawn` |
| ui_real_capture_lab 844x390 and 1600x900 gl_compatibility (the HUD is hooked) | both `[uireal] PASS screens=hud,...,camp_workbench,...,resize_back`, exit 0; 844: `phone=true ... logical_width=844` |

My first lab attempt in this round booted the lab scenes by path instead of through `--lab=` (main.gd). That skipped
main.gd's canvas fit (`logical=1947x900` on an 844x390 window), and uireal failed its phone-canvas check. That was my
command line, not the code. Rerun through `-- --lab=<name>` (`[display] window (844, 390) -> logical (844, 390)`), both
labs pass as above. Only the rerun's shots are cited.

The first build's gates (`d5e4a3a5`, same list, all PASS) are superseded by the table above. One failure from that
build is still worth knowing: before the teleport rule, ui_real_capture_lab teleported the survivor into the camp, the
banner came up and took the camp labels' spot (`FAIL camp_workbench: at least 2 camp labels ... (labels 1)`). A
teleport is now an arrival, and both sizes pass.

## Shots looked at (pre-merge fixes)

Scratchpad `.../scratchpad/fixdom/shots7/{fwd1600,glc844}_{day,night}/{outside,entered,staying,reentered,neighbour,crowd}_<w>x<h>.png`
(not in the repo). I opened `entered`, `neighbour` and `crowd` at 844x390 day and night, and at 1600x900 day and night:
- **844x390.** The banner is a slim pill at the top between the vitals and the minimap, with the quest card directly
  under it. It covers nothing in the play area: the survivor, the camp labels (Workbench, Cargo Warp, Tent), the
  rocks and HANDS are all clear in both `entered` and `neighbour`. Logged rect: `[P: (406.5, 6.0), S: (169.0, 26.0)]`.
  The quest card starts at y 34.
- **1600x900.** Unchanged from the first build: the banner sits top centre between the vitals and the quest card, and
  shows the survivor's face (Milan) or the grey silhouette (Rowan).
- **Yours and theirs.** Your camp edge is long yellow dashes. Rowan's is short salmon dots. They read apart at both
  sizes, also where both meet at the top left of `neighbour`.
- **Crowd.** With 36 other plots around, only 4 claims' dots draw. The left half shows a few dotted lines, not a
  lattice over the whole screen.
- **Night.** The yellow dashes dim to khaki, and the salmon dots dim with the grass. Both are still visible next to the
  survivor's light, and neither glows at full day colour.
- **River.** Rowan's dots run down the bank and across the river. At 1600x900 they show on the water by day and by
  night; the water no longer washes them out.

First build's shots (`.../scratchpad/domain/final4/`), still true where the fixes did not change them: the edge reads
like the references' dotted line, a little brighter and more even than Durango's worn-in line. The portrait is framed
on the live pose with the eyes level with its centre (`final4/fwd1600/banner_zoom.png`). A rest-pose attempt showed only
hair and was dropped.

## Assumptions

1. Arriving is not entering: an island load, a voyage, a respawn, or any move over 6 m in one frame sets a baseline
   without a banner. Only walking or riding across the edge shows it. The spec says "entering"; on a teleport the
   banner covered the camp labels.
2. Your own land shows the banner too ("Milan's Domain"). Spec 18 says "another player's (or your own)".
3. A domain is "left" after 0.5 s away from it, whether onto open ground or into the next owner's land, so walking
   along an edge or a shared border does not flash it. Entering from open ground shows at once.
4. On screen 3.5 s with 0.35 s fades. There is no reference for the timing.
5. On desktop it sits at top centre and slides under the target plate when one shows. On a landscape phone it is a
   slim toast in its own slot at the top of the band between the vitals and the minimap, above the quest card; while
   the target plate or level-up banner holds that slot it is not drawn (combat first). There is no reference for the
   HUD placement; the label's look is the spec 15 map label.
6. Gold `#F5B545` name, white "'s Domain", a 90 % black pill and a warm-white portrait ring, sampled by eye from
   durango-island-map.webp.
7. The references show one colour, yellow, for the edge: that is yours. Other players' edges are salmon dots
   (`#FF9478`, 0.25 m) so they read differently by hue and by dash length (for colour-blind players too), and only
   the 4 claims nearest the survivor draw. 4 is not from a spec. The lit dashes dim with the scene at night; there
   is no reference for a night claim edge.
8. On unstable islands the landing camp is already claimed for the survivor (an existing assumption in
   IslandClaims.setup), so walking into it shows "<you>'s Domain".
9. Portraits:
   - Yours is rendered from the live model at the first banner and again after the stamp (name, occupation, worn
     equipment, `World.look`) changes.
   - Other owners get the silhouette until the server sends appearances.
   - No portrait existed on the base (`claude/mmo-overhaul`). INVUI's CharacterScreen renders the raw survivor.glb
     on its unmerged branch, so this package does not depend on it.

## For the next agent / integrator

- Apply `claude-mmo-domain-hooks.patch` after merging the branch (it touches W1-UI's hunt_hud.gd with 3 lines, the
  island claims code and `PlayerActions.claim`). The new classes need one `--import` (ClaimOutline, DomainBanner,
  PlayerPortrait); ClaimOutline is now a MeshInstance3D, so an old import cache must be refreshed.
- When CHARCREATE merges: the own branch of `PlayerPortrait.texture_for` can return `PortraitService.of_player()`
  (its stamp already includes `World.look`).
- Online (W3): send claim rows to `World.runtime.set_other_claims(rows)` on island join and on every change.
- INVUI's `CharacterScreen._portrait_texture` could call `PlayerPortrait.texture_for({"id": "self", "own": true}, self)`
  to show the real look (gear included) instead of the bare survivor.glb.
- Not done (outside this package's scope):
  - the spec 15 map screen's "<name>'s Domain" label (PlayerPortrait and the colours are ready for it);
  - spec 18's third bullet, name plates on buildings inside a domain (HudPills already draws them within 8 m).
- Fixed here (it was "found, not fixed" at review): `claim_at` refuses another player's tiles, and the stake is spent
  only after a successful claim. The server (W3) should still refuse overlaps on its side.
- Incident: one of my commands ran Godot in the main checkout by mistake (Godot ran there with `--path game` after a
  `cd` into a throwaway tree failed). It failed at once
  ("Can't load script res://tests/t_domain.gd": the file is not in the main checkout). No file under the main
  checkout's `game/` changed (checked with `find -newermt`). The owner's `save_1.json` is untouched (Oct 18). It did
  write `logs/godot.log` in the owner's user dir and rotated the previous log there to a timestamped name.
