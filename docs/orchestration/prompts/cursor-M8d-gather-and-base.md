# Cursor milestone M8d — gathering radial, context hexes, land claim, label pills

Do this after M8c (HUD + combat). Same rules: `scripts/ui/` + `scenes/ui/` for UI, no
autoloads, no `project.godot`, no `game/shell/`, no `tools/`. Reuse M8c's `HexButton`.
References: `docs/reference/durango-gather-reference.webp`, `docs/reference/durango-base-reference.jpg`.

## Part A — gathering UI, from `docs/reference/durango-gather-reference.webp`

In words: the player taps a boulder by the river. The boulder gets a thin **hexagonal
selection outline** on the ground with its name and level under it (`Boulder`, `Lv. 1`
in green). Next to it a small **radial of hexagonal option buttons** fans out, one per
thing that node can yield: each hex shows the yield's icon, the gather time at the top
(`3.0s`), the count it gives at the bottom (`3`), and a label to the right
(`Boulder Lv. 1`, `Pebble Lv. 1`). An option you cannot take (wrong tool, skill too
low) shows a red no-entry badge and a hint. Tapping a hex walks there and gathers with
the M8a ring. Bottom-right, standing by water, three **context hexes** appear (drink,
wash hands, fill container). A quest-hint card top-right (`Axe Materials · Find new
pebbles to use as a blade`) is out of scope for now.

Tasks:
11. **Node yield options.** `nature_manifest.json` families may list several `yields`
    (`[{"item": "stone", "count": 3, "seconds": 3.0, "tool": "pick"}, {"item": "pebble",
    "count": 2, "seconds": 3.0, "tool": "none"}]`); migrate the current single yield into
    that list (`# ASSUMPTION` second options: rocks → pebble, trees → branch without an
    axe, bushes → fibre + berry, mud → mud + clay). `HarvestNode` exposes `options()`.
12. **Tap a node → selection hex + radial.** One node selected at a time: hex outline
    (flat 1.4 m hexagon mesh, unshaded, 60 % alpha) on its tile, name + `Lv. N` label
    under it, and a `GatherRadial` Control (`scripts/ui/gather_radial.gd`) placed by
    unprojecting the node, with one `HexButton` per option (icon, seconds, count, label;
    red badge + `needs pick` when blocked). Single-option nodes skip the radial and start
    at once (keeps M8a's flow). Tapping a hex starts the M8a auto-gather with that
    option; tap-outside dismisses. Radial hexes ≥ 64 px.
13. **Context hexes.** Standing within 2 m of water (river trigger / shallow water
    tiles): a bottom-right cluster of hexes `Drink` (energy +5, `# ASSUMPTION`), `Wash`
    (clears `dirty` if the status exists, else fatigue −2), `Fill` (fills a bucket/bottle
    item if in the bag). Near a bonfire: `Cauterise`, `Cook` (opens craft filtered to
    the bonfire). Near a corpse: `Loot`. These replace the old USE button.

Acceptance additions: `m8c-gather-radial.png` showing a selected rock with the hex
outline, its label and two option hexes (one blocked with the red badge), and the water
context hexes; `[item] option pebble x2 3.0s` printed when an option is chosen in the
island lab hook.

## Part B — base building, from `docs/reference/durango-base-reference.jpg`

In words: the player's camp is a **claimed plot** drawn as a glowing dotted light-blue
boundary along the tile edges (an isometric diamond of about 14×14 tiles). Inside it,
every building has a **floating label pill**: dark rounded pill with the building's icon,
a small green status dot, and its name (`Basket`, `Makeshift Tent`, `Bonfire`,
`Makeshift Workbench`); a `Small Field` shows a second pill with a clock and the time
left (`19m 54s`). Resource nodes outside the plot have the same pills (`Boulder`,
`Pebble`). Bottom-right two hexes: a fence glyph (claim / expand land) and an anchor
(harbour routes). The quest card on the right stays out of scope.

Tasks:
14. **Land claim.** `LandClaim` data on the island runtime: a set of claimed tiles with
    an owner. Home island: the camp plot (14×14 tiles around the camp) is claimed at
    creation and can be **expanded** by 4 tiles a side per Pioneer level 5/10/15
    (`# ASSUMPTION`). Unstable islands: the first plot is free (14×14 where the player
    stands, tap the fence hex → tap a tile), later ones cost `claim_stake` items
    (add to `items.json`, craftable from 4 branches). Buildings may only be placed on
    claimed tiles (`BuildGrid.can_place` returns `unclaimed`); the camp props count as
    claimed. Draw the boundary as a dotted emissive line (ImmediateMesh or a ribbon of
    small quads) on the plot's outer tile edges, 0.03 m above ground, animated dash
    offset; hide it beyond 40 m. Saved in schema 2 (`claims: [{x, z, w, d}]`).
15. **Label pills.** A `WorldLabels` CanvasLayer draws a pill for every building,
    crafting station, pen, field and harvest node within 30 m (icon from
    `icons_manifest.json` or the item glyph, green dot = usable / grey = depleted /
    red = needs tool, name from the manifest). Fields, drying racks, taming pens and
    regrowing nodes get a second pill with a clock and `Nm Ns` remaining. Pills fade
    with distance and never overlap the target plate or the radial (skip when a
    radial is open for that node). Tapping a pill = tapping the object.
16. **Plot hexes.** Bottom-right cluster gets `Claim/Expand` (fence glyph) and
    `Harbour` (anchor glyph, opens the existing harbour routes when within 12 m of the
    dock). Placement (M8b) shows the claimed area tinted while placing.

Acceptance additions: `m8c-base.png` (home camp with the dotted boundary, pills on
tent/basket/bonfire/workbench, a timer pill on a regrowing node, the two plot hexes);
headless `build_lab` prints `[build] rejected unclaimed` for a tile outside the plot and
`[world] claimed 14x14 at (x,z)` on the unstable island.

## Part C — corpses use the radial; level-up overlay; pickup toasts
Reference: `docs/reference/durango-levelup-loot-reference.webp`. In words: a dead
compsognathus is labelled `Compsognathus Corpse` with `Lv. 6` under it and the killer's
name above; next to it the same hex radial as a rock: `Meat Lv. 6`, `1.6s`, count `1`.
When something is taken, a small toast with the item icon and `+1` floats up near the
top-centre. On a level-up a gold text stack appears at the top-left under the bars:
`Lv. 5`, an eye glyph with the XP total, a coin glyph with the coin total,
`Available Skill Points: 4`, `Title Venture into the World acquired.`, then one line per
stat gained (`Strength + 5` … in gold); it stays ~6 s and fades.

Tasks:
17. **Corpse = node with options.** Replace M9a's loot panel with the Part A radial on
    bodies: options from `butchering.json` (meat, hide, bone, sinew… each with
    `seconds` and `count`, tool `knife` where the table says so → red badge without a
    knife). The body's label pill reads `<Species> Corpse` + `Lv. N` and shows the
    killer's name above when the player killed it. Taking the last option removes the
    body (M9a despawn timers still apply).
18. **Pickup toasts.** Every item gained (gather, loot, craft output, pet dump) shows a
    toast near the top-centre: item icon (or glyph) + `+N`, rising 40 px over 1.2 s and
    fading; stack repeated ids into one toast with an updated count.
19. **Level-up overlay.** `LevelUpOverlay` (`scripts/ui/level_up_overlay.gd`) listens to
    `World.pioneer_changed`: shows `Lv. N`, XP (`World.pioneer_xp` — add it if missing,
    fed by crafts/buildings/discoveries the way Pioneer level is), T-stones with a coin
    glyph, `Available Skill Points: N` (survival tree points if the skill system tracks
    them, else the unlock count), a title line when `game/data/skills/titles.json`
    (create: level → title, `# ASSUMPTION` names) has one for that level, and the per
    level stat gains from `game/data/skills/pioneer_levels.json` (create: `{level:
    {strength: 5, endurance: 5, ...}}` `# ASSUMPTION` +5 each, one +6 per level rotating)
    applied to the player's `Vitals` max values. Debug key F9 forces a level-up in labs.

Acceptance additions: `m8d-corpse-radial.png` (body with its pill and the Meat hex),
`m8d-levelup.png` (the gold stack), `[item] +1 raw_meat` followed by a
`[ui] toast raw_meat +1` print, and `[world] pioneer level 5 title="…"` in the lab.

## Acceptance (whole milestone)
- The screenshots and prints listed under Parts A, B and C.
- Headless `--lab=island_lab` and `--lab=build_lab` pass; `tools/smoke.sh` → `SMOKE PASS`.
- Report `docs/orchestration/reports/cursor-M8d-gather-and-base.md`; commit as
  `M8d: gather radial, context hexes, land claim, label pills`.
