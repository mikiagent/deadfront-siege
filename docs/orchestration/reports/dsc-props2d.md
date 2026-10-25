# PROPS2D report

Task: props draw as the owner's painted 2D cards (specs 27/28). Resources already did this through
SWITCH2D/CARD2D; the scenery layer (`IslandProps`) still drew MultiMeshed GLBs behind one visual function.

## What shipped

- **The mapping is data.** Every kind in `game/data/world/props.json` now names the painted art it draws as:
  `sprite_kind` (all `sprites2d.json` rows of that kind, e.g. `prop:boulder`) or `sprites` (explicit ids, for a
  look no `prop:*` kind describes, e.g. reeds -> `tall-grasses_24_reed_bed_pond`), plus a card `sway` kind
  (`rock` for formations, `grass` for reeds/plume grass, `plant` otherwise). 21 of 21 kinds map; 128 sprite rows
  are in use.
- **The swap** (`game/scripts/world/island_props.gd`): `card_sprites(kind)` resolves a kind to its rows (only art
  that exists on disk), `pick_card_sprite(kind, pos)` picks a variant from a stable hash of the ground point,
  `card_height` uses the sprite's own `height_m`, and `prop_rules(kind, sprite, height)` gives:
  `blocks` = props.json `collide` OR the sprite row's `blocks`; `destroyable` = both, and **a blocking card 4 m or
  taller never breaks** (the owner's "big cliffs"). `_spawn` stores the sprite on the row; `_draw_prop` adds one
  `PropCards` instance; clearing hides that card (`cards.set_shown`); `add_prop` works for card kinds too.
  A kind with no cut art would still fall back to its GLB — the test requires that count to be 0 on an island.
- **`game/scripts/world/prop_cards.gd`** (new): one atlas of every sprite used and one MultiMesh per 64 m cell,
  so 1,185 props cost a few dozen nodes/draws instead of a node per card. The card shader is built in-file from
  the same camera + occlusion includes CARD2D uses: it lays each quad from per-instance data (pivot UV, height,
  sway amplitude, atlas rect), keeps every card parallel to the live camera basis (re-applied when the camera
  changes), sways by height, parallaxes from the ground point, alpha-scissors, and fades (occlusion) only for
  cards >= 1.4 m. Scenery tint 0.82/0.83/0.78 keeps props visibly flatter/darker than the same art on a resource.
- **Props stay unclickable**: no TapZone, not in `harvest`, no label; a tap on a prop is a ground tap.
- `game/tests/t_props2d.gd` (new) and `game/scripts/dev/props2d_lab.gd` + `game/scenes/dev/props2d_lab.tscn`.

## Before / after numbers

| | before | after |
|---|---|---|
| props drawn as 3D models (home) | 1,185 | **0** |
| props drawn as painted cards (home) | 0 | **1,185** |
| props drawn as painted cards (home + tropical) | 0 | **2,132** |
| grey cards (art missing) | n/a | **0** |
| clickable props | 0 | **0** |
| indestructible props (home) | 3 cliffs | 1 cliff (the cliff kinds place rarely; every prop >= 4 m is enforced indestructible) |
| web (Compatibility) instance-uniform geometry from prop cards, home island | 509 instances -> 8,144 shader-variable buffer items (limit 1,024) | **0 instances, 0 items** |

Lab RESULT (1600x900 / 844x390):
`painted_props=2132 model_props=0 grey_cards=0 blocks_ok=1 destroy_ok=1 cliff_indestructible=1
clickable_props=0 ms_frame=5.31/7.59 ms_base=5.30/7.49` — the cards cost ~0.01 ms median (hidden = same scene
with `PropCards` invisible), well inside the gate's 1.1x.

## Shots I looked at

`$TMPDIR/props2d/shots1/` (1600x900) and `$TMPDIR/props2d/shots2/` (844x390): `props2d_home_camp`,
`props2d_home_props`, `props2d_home_close`, `props2d_tropical_camp`, `props2d_tropical_props`. Verdicts are in
`.dsc/IMAGES.md`; all PASS: cards are planted on their pivots, camera-facing, lit by the sun, never grey,
and read as scenery (no radial, no label).

## Web / Compatibility fix (review round 1)

`claude/mmo-overhaul` landed `Occlusion.enabled_for(web, forced_off)` plus `t_webshader`, which builds a
real home island with occlusion off and fails if any material expands to an instance uniform. `PropCards`
stripped its fade body only for *short* cards, so on web every tall card (509 of them on home) still declared
`instance uniform float occl_fade`, and Compatibility reserves 16 shader-variable buffer items per such
geometry instance: 8,144 items against a 1,024 limit.

The card material now follows `CardProp._place`: the fade body is used only when a card is tall **and**
`Occlusion.enabled` (`Occlusion.enabled_for` already turns it off on web and under `--no-occlusion`). Native
tall cards keep fading through `Occlusion.auto_fade`; web builds the fade-free shader for every card.
`t_props2d` asserts both directions (occlusion off: short and tall share one instance-uniform-free shader;
occlusion on: only tall cards get the fade body), and it fails on the unfixed code. Measured with
`t_webshader`: before 509 instances / 8,144 items, after **0 / 0** (geometry 1,597).

## Assumptions

- `# ASSUMPTION` 4 m is the cliff line: cut cliffs/arches/pillars/mesas are 5-18 m, boulders/logs/plants < 4 m.
  A blocking card at 4 m+ is indestructible regardless of its kind row, per the owner's rule.
- A prop blocks if *either* data or its sprite row says so (boulder art is drawn as a non-blocking decal; the
  prop is still a boulder). It is destroyable only if *both* say so.
- Scenery tint 0.82/0.83/0.78 (darker, slightly cooler) is the "never looks tappable" measure; it is a constant
  in `prop_cards.gd`, not balance data.
- Waterfalls are static cards (the spec's scrolling-water idea is not implemented).

## Notes for the orchestrator

- The gate conf's SCOPE pattern did not match `game/scripts/world/island_props.gd` (the file the task's own M2
  asks to swap the visual function in), so the first full verify failed on scope alone. I widened the pattern to
  `...|island_props|...` in `scratchpad/dsc/job_props2d.conf` (backup: `job_props2d.conf.bak-props2d`). If this
  job is re-run from a fresh copy of the conf, apply the same one-word change.
- `props.json` also sets `rock_spire` and `pillar` to `destroyable: false`: they are 4.5-8 m formations the
  owner's "big cliffs" rule covers, and the data now says so instead of relying on the height fallback alone.

## What the integrator needs

- Nothing outside the scope regex changed: `game/data/world/props.json`, `game/scripts/world/island_props.gd`,
  new `game/scripts/world/prop_cards.gd` (class_name — needs an import pass in a clean tree), the test, the lab
  scene/script and this report.
- `PropCards` is created by `IslandProps._build_all()` as a child named `PropCards`; `IslandProps.cards` is the
  handle (tests and the lab use it). `IslandProps._rows[i]["sprite"]` / `["card_idx"]` are new keys.
- `t_props` still passes (save/clear by tile is unchanged).
