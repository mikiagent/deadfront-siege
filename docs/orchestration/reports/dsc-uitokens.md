# dsc-uitokens — UI redesign package 1: tokens, HexButton extensions, chrome helpers

Task: docs/design/ui-redesign-spec.md §2, §3, §8 as opt-in building blocks for later packages. No screen
was restyled in this package.

## What shipped

### game/scripts/ui/ui_tokens.gd (every existing constant and function kept)

- §2 palette: `HUD_FILL`, `HUD_RIM`, `HEADER`, `SCREEN_DIM`, `PANEL`, `GOLD`, `GOLD_DIM`, `CTA_INK`,
  `PARCHMENT_TOP`, `PARCHMENT_BOTTOM`, `PARCHMENT_INK`, `OK_GREEN`, `LIFE`, `ENERGY`, `XP`, `MUTED`.
- Trait chips: `TRAIT_NEG_BG/FG`, `TRAIT_POS_BG/FG`, `TRAIT_RARE_BG/FG`; `MOOD` (4 exhaustion tints).
- Geometry: `hex_points(center, r, flat_top)`, `hex_radius_at(a, r, flat_top)` (spec formula),
  `hex_vertex_angles(flat_top)`, `pie_points(center, r, f, flat_top)`, `polygon_area(pts)`.
- Chips: `trait_chip_style(polarity)` (0 radius, 3x8 padding; unknown -> negative), `trait_chip_fg`,
  `trait_chip_prefix` (`−`, `+`, U+2726).
- Chrome: `bracket_segments(rect, arm)` / `draw_brackets(ci, rect, color = GOLD, arm = 18, w = 3)`,
  `header_style()`, `torn_edge_points(rect, amp = 12, step)` / `draw_torn_edge(...)` (deterministic
  0–12 px zig-zag under the header), constants `HEADER_H`, `TORN_MAX`, `BRACKET_ARM`, `BRACKET_W`,
  `PIE_STEP`.
- Type (owner decision 2026-10-28): `UI_FONT_PATH`, `WEIGHT_REGULAR`/`WEIGHT_BOLD`, `TITLE_PX`,
  `HEADER_PX`, `CHIP_PX`, and `ui_font(weight)` / `ui_font_regular()` / `ui_font_bold()` / `ui_face()`
  building cached `FontVariation`s (wght 400 / 700) from
  `res://assets/fonts/RobotoCondensed-Variable.ttf`. `HEX_FLAT_TOP := true` (owner decision, not an
  ASSUMPTION).

### game/scripts/ui/hex_button.gd

- `flat_top` (default `UiTokens.HEX_FLAT_TOP`), `rim_color` (default transparent = follow `accent`),
  `rim_width` (default 2.0 = today's stroke), `fill_ratio` (pie fill, independent of `cooldown`),
  `icon_grey`, `key_hint` (+ `key_visible()`, `key_rect()`; hidden when `UiTokens.is_compact(view)`).
- `_hex()` now calls `UiTokens.hex_points`; `hex_rect()` is orientation-aware. Draw order per §3:
  rim hex → fill hex inset by `rim_width/2` → pie sector → focus ring → icon → texts → key cap → badge
  → cooldown sweep → label. `effective_rim()` centralises the rim decision.
- New constant `HINT_PX` (key cap size): `KEY_PX` would have collided with `TargetSwordsHex.KEY_PX`
  and broke that subclass's compile — caught by the first test run.

## Before / after numbers (measured by game/tests/t_uitokens.gd)

| quantity | before | after |
|---|---|---|
| default HexButton corners | pointy-top, 60°i−30°, width √3r | flat-top `UiTokens.hex_points`, width 2r, height √3r |
| `hex_rect()` at 64 px control (r 30) | 51.96 × 60 | 60 × 51.96 |
| hex area | 3√3/2 r² | unchanged; pie at f=1 gives 2338.27 px² vs hex 2338.27 px² (0.00 %) |
| pie sampling | — | worst boundary gap 5.96° (limit 6°), reaches r exactly at every swept vertex |
| rim stroke | 2 px, accent-ish grey | same (default); `rim_color`/`rim_width` opt-in |
| torn edge | — | 101 points across 1600 px, teeth 0.0–12.0 px, stable across redraws |

## What the test covers (game/tests/t_uitokens.gd)

Palette values incl. existing tokens kept; `HEX_FLAT_TOP` true; 6 corners at radius r for both
orientations with flat-top's two level corners and pointy-top's two vertical ones; pointy path equals
the old `60°i−30°` maths; `hex_radius_at` = r at all six vertices and apothem at edge midpoints, never
outside that band over 720 samples; pie monotone over 40 steps, f=1 area within 1 %, f=0 empty;
three distinct chip backgrounds, 0 radius, 3x8 padding, prefixes; brackets inside the rect, arm 18
(capped on a small rect); torn edge depth/span/stability; default HexButton polygon = flat-top
`hex_points`; `fill_ratio`/`icon_grey` leave `fill` and `accent` untouched, grey copy desaturated with
its alpha kept and cached; `rim_color` 4 px settable, defaults = accent/TEAL, restyled = HUD_RIM/GOLD;
`key_hint` visible at 1600×900, hidden at 844×390. Fonts: constants checked; with the TTF absent (this
worktree) the helpers answer null and `ui_face()` falls back to the engine font — the present branch is
covered too for after the merge.

## Shots looked at

None: the owner reserved the machine for the gate (`HEADLESS_ONLY` in the gate dir), so the 1600×900 /
844×390 labs are deferred. This package adds no new screen surface — the only visible change is the
global flat-top orientation of existing hexes, which the headless tests assert geometrically. The
integrator should look at the HUD, gather radial, station radial and pet radial once windowed.

## Assumptions / decisions

- Hex orientation is flat-top (owner decision 2026-10-28), overriding spec §9 question 1.
- "Hidden on phone" for `key_hint` uses `UiTokens.is_compact` — `is_phone` is width-based and would keep
  key caps on a landscape phone (844×390), which the spec also treats as a phone.
- Defaults reproduce the shipped look: rim = `accent`, 2 px; selected = TEAL. GOLD selection on a hex
  (and GOLD brackets generally) is applied by later restyle packages, per §2 ("on restyled screens").
- Roboto Condensed: the TTF lives on `claude/mmo-overhaul` and this worktree may not merge branches, so
  `UI_FONT_PATH` references it and the helpers degrade to null/fallback here.
- Key cap drawn in `UiTokens.INK`/TEXT so it reads on any hex; spec gives no exact style.

## What the integrator needs

1. Merge `claude/mmo-overhaul` for `game/assets/fonts/RobotoCondensed-Variable.ttf` (import step needed);
   `t_uitokens` then exercises the `FontVariation` branch.
2. Every hex is now flat-top by default (`HexButton.flat_top`, `UiTokens.HEX_FLAT_TOP`). `hex_rect()` and
   `hud_layout`/`taken_rects` follow it, so on-screen HUD gaps changed shape with it.
3. For the gather pie (package 2): set `fill_ratio` 0→1 on the pressed hex and `bottom_text` = remaining
   node count; keep `cooldown` for the sweep.
4. Trait polarity per attribute key is still missing in item data (spec §5 open question); the chip
   helper takes a polarity the caller must supply.
5. Use `UiTokens.pie_points` for the eating/eat-progress pie too — don't fork a second sector formula.
