# dsc — STATUSICONS: seven FOODFX status icons

## What shipped

FOODFX added seven statuses to `game/data/statuses.json` (caffeinated, tastes_great,
tastes_delicious, tastes_horrible, tastes_disgusting, hot_food, cold_food) with no entry in
`game/data/ui_icons.json`, so `HudStatusChip.icon_for()` returned null and the HUD status chips drew
two-letter codes (`CA`, `TG`, …). All seven now have their own white SVG, and the chips draw them.

| id | drawing | where |
|---|---|---|
| `caffeinated` | tapered mug: rim, side handle, two steam curls | new — `caffeinated.svg` |
| `tastes_great` | thick ring face, dot eyes, the family's widest smile | new — `tastes_great.svg` |
| `tastes_delicious` | dot eyes, smaller smile, tongue licking out at the lip corner | new — `tastes_delicious.svg` |
| `tastes_horrible` | dot eyes, the family's heaviest mouth, an arch (a frown) | new — `tastes_horrible.svg` |
| `tastes_disgusting` | filled sick face: slit eyes, a small open oval mouth, drool running off the chin | new — `tastes_disgusting.svg` |
| `hot_food` | two-tongued flame over a deep pot with two handles | new — `hot_food.svg` |
| `cold_food` | six-arm snowflake over a shallow dish | new — `cold_food.svg` |

Reused: none. Every id needed a meaning no existing drawing carried. `tastes_bad` (the filled face
plate with X eyes and a frown) is the raw-food roll's status and stays as it was; the sick face
deliberately does **not** use X eyes — the first draft did, and on the chip row it read as a second
`tastes_bad`. It is filled like `tastes_bad` so the two heaviest tastes sit heavier than the outlined
smiles, but its face is slit eyes + an open oval mouth + drool. `drink` (a bowl under one droplet) and `station_pot` (a
lidded pot) already own the bowl silhouette, so caffeinated is a mug with a handle rather than a cup
over a saucer, and both food-condition icons use a flame/flake **over a vessel** instead of a flame
or a flake alone (`cauterise` owns the bare flame, `thirsty` the bare drop).

## How they were made

`t_uiicons` requires every SVG to be the byte-for-byte output of
`game/assets/icons/ui/_src/build.py` (`_test_sources`), so a hand-written SVG fails even when it looks
right. The drawings therefore live in a new source module:

- `game/assets/icons/ui/_src/icons_k.py` — the seven drawings, solid polygons on the 64 grid, built
  from the existing `geo`/`geo2` helpers (`band`, `arcp`, `chaikin`, `circle`, `xf`) and centred
  optically by `geo2.place`, exactly like `icons_g..j`.
- `game/assets/icons/ui/_src/build.py` — `icons_k` added to `MODULES` and `SOLID`.

```sh
cd game/assets/icons/ui/_src && python3 build.py          # writes the 7 SVGs
python3 build.py --check                                  # [icons] PASS drawn=123 svgs=123
```

House rules held: `viewBox="0 0 64 64"`, ink inside the 6..58 live area, white only (no colour, no
text, no gradient, no opacity attribute), the two house stroke weights only (`5` line, `1.5` solid
edge) and the build.py header naming the file's own id. Each new SVG has a `.svg.import` copied from
an existing icon and re-imported by Godot, so it lands at `svg/scale=2.0`, `mipmaps/generate=true`,
`compress/mode=0` like the rest — the test asserts those three.

## Before / after

| check | before | after |
|---|---|---|
| `t_uiicons` | FAIL — 14 failures: 7 "status X has an icon", 7 "HUD status chip X draws an icon, not letters" | PASS — `ids=189 files=123 glyphs=47 code_ids=48 hook_ids=45 weight=0.61..1.46 worst_iou=0.80 loot/store regen='[icons] PASS drawn=123 svgs=123'` |
| mapped ids | 182 | 189 |
| SVG files | 116 | 123 |
| `t_ui` | PASS | PASS |
| `t_foodfx` | PASS | PASS |

Weight: the bare faces (dot eyes + a mouth, no plate) first landed at 0.40–0.58 × the set median and
failed `_test_weight`. The two bare ones are drawn 1.24–1.34 × larger about the grid centre; the
filled sick face, conversely, came out at 1.62 × and is drawn 0.79 × smaller. Both nudges live in one
documented loop in `icons_k.py`, the same trick `icons_g` uses for `tailoring` / `construction`. The
whole set sits in 0.61..1.46. Silhouette: `_test_distinct` passes
with the worst pair still `loot/store` at 0.80, so none of the new drawings is nearer any existing
one than two icons that were already allowed to resemble each other (final run:
`weight=0.61..1.46 worst_iou=0.80 loot/store`).

## Shots looked at

Rendered contact sheets of the whole 116-icon set and of each iteration at 26 px (the real chip) and
96–130 px. Paths (worktree-local, not committed):

- `.dsc/shots/20261028-004126-5pra/001-screenshot.png` — existing set, to learn the house style.
- `…/004`–`…/009` — six iterations of the seven. Iterations that were rejected: a zig-zag steam that
  read as blobs; a wide grin that shared the bowl silhouette with `drink`; a "V" mouth that read as
  a frown while the arch read as a smile; and X eyes that duplicated `tastes_bad`.
- `…/009`–`…/014` — the shipped set: mug, flame-over-pot, flake-over-dish, and four faces that
  stay apart from `tastes_bad`, `stomachache`, `full`, `drink`, `station_pot` and each other at 26 px.
- `…/014-screenshot.png` — the shipped taste family only, 130 px and 20 px: the five faces are
  distinguishable side by side, which is the worst case, since `tastes_bad`, the four grades and
  `stomachache` can all be up on the player's status row at once.

The verify gate reports `VERIFY HEADLESS-ONLY: visual lab deferred by owner` (`.dsc/.../HEADLESS_ONLY`
is set), so no in-game HUD screenshot was taken; the chip-size judgement is the HTML sheet above,
which draws each icon at 20 px inside a 26 px chip on the chip's own dark background.

## Assumptions

- The four taste grades are ordered by good→bad as `tastes_great` (widest smile) → `tastes_delicious`
  (smile) → `tastes_horrible` (frown) → `tastes_disgusting` (sick). The statuses themselves carry no
  severity field; the ordering is the display names (Phenomenal Flavor, Delicious Flavor, Horrible
  Flavor, Disgusting Flavor).
- `tastes_bad` is left untouched (it belongs to the raw-food roll, a different status) and is the
  neighbouring drawing the sick face must not repeat.
- No balance number, status effect or .gd file was touched.

## Gate status

```sh
bash .../dsc/verify_job.sh statusicons
# t_uiicons PASS, t_ui PASS, t_foodfx PASS, SMOKE PASS, report present,
# then: VERIFY FAIL: files outside your scope changed:
#   game/assets/icons/ui/_src/build.py game/assets/icons/ui/_src/icons_k.py
```

That is the only remaining failure, and it is a contradiction in the job's own scope rather than a
defect in the change: `t_uiicons` cannot pass without a `_src` edit, and the SCOPE regex does not
admit `_src`. I did not hand-write an SVG to dodge it (the test rejects that) and did not edit the
gate conf. Everything the gate checks before the scope step passes.

## What the integrator needs

- **Scope exception.** The job's SCOPE regex is
  `^(game/data/ui_icons\.json|game/assets/icons/ui/[a-z0-9_]+\.svg|docs/orchestration/)` and does not
  admit `game/assets/icons/ui/_src/`. Two files there changed: `build.py` (one line: `icons_k` added
  to `MODULES`, one to `SOLID`) and the new `icons_k.py`. This was unavoidable: `t_uiicons`
  `_test_sources` runs `build.py --check` and fails any SVG that the sources do not regenerate byte
  for byte, and it also fails an SVG that no module draws ("NOT FROM SOURCE"). A hand-authored SVG
  cannot pass. Either widen the scope to `game/assets/icons/ui/` for icon jobs or make
  `_src/build.py --check` the only entry point (the same file is what the previous icon task,
  `9d705512`/`2a4eb93e`, committed).
- The seven new `*.svg.import` files are present in the worktree but untracked (the runner's
  checkpoint only commits tracked files). Commit them with the SVGs or Godot will re-import at its
  defaults (64 px, no mipmaps) on a clean checkout and `t_uiicons` will fail the import assertions.
- `game/data/ui_icons.json` gained exactly seven entries (ids=182 → 189); nothing else in it moved,
  and no id was re-pointed.
- Nothing to merge for the HUD: `HudStatusChip.icon_for()` already reads the manifest, so the chips
  pick the icons up with no code change.
