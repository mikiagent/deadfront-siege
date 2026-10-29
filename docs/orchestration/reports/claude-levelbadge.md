# LEVELBADGE (Claude agent): tiered level badge, boxless vitals and minimap, belt sticker, map coordinates, bigger B/W buff chips, ghost-trail bars, stomach in the buff row

Branch `claude/mmo-levelbadge` from `origin/claude/mmo-overhaul`. Owner requests, 2026-10-28 (all verbatim via the coordinator):
"the level gets more impressive looking as it gets closer to 60 ... Remove the black box background ... (same treatment
to the minimap)"; "move the exhaustion level emoji on top of the bar like a sticker"; "add the x and y coordinates to
the bottom of the minimap"; "the buffs under the healthbars etc should be larger and black/white except for a blue arrow
up or a red arrow down"; "do that for health and energy too please" (Pokémon-style ghost fill); "move stomach indicator
by the buffs/debuffs please".

## What shipped
- `game/scripts/ui/hud_level_badge.gd` (new): the top-left level badge, canvas draws only, reversing LEVELBAR's
  "no top-left level". Tiers by shown level (1/10/25/40/55/60): slate ring; bronze; silver + notches; gold + filigree +
  12-point spiked star; glowing gold with turning 16-point star, breathing halo, a shimmer arc circling the band, 4
  sparks; Lv 60 adds a 3-spike crown, brighter halo, 7 sparks. Number + LEVEL in a dark well. LEVELFX rings pulse out of
  it on level-up. Animated off the HUD's existing per-frame redraw; ~20-70 small draws.
- Vitals: the `draw_rect(vitals, UiTokens.INK)` panel is gone. Bars get a drop shadow, dark rim, lit top edge and
  outlined numbers; the tier word and map text are outlined; the stomach ring has its own shadow.
- Bars: `HuntHud._trail` / `bar_trail` — a loss drops the fill and a pale ghost holds 0.4 s then eases down; a gain puts
  the ghost up and the fill eases to it (health, energy, mount energy under its own key).
- Exhaustion face is a sticker (white rim + shadow) on the treadmill belt at the strain marker.
- Stomach ring moved from beside the bars to the start of the buff row, chip-sized (38 px); bars take its width.
- Buff row (`hud_buff_row.gd`): 38 px chips (44 pitch), black tile, white rim/icon, blue up / red down arrow badge
  (buff+boon / debuff). The resting chip uses the same drawing; the dead `HudRestBox.chip` is removed. Tooltips unchanged.
- Minimap: no square box or corner covers. Terrain and fog are UV-mapped disc polygons (`_map_disc`), framed by a
  shadowed bronze rim (`MAP_RIM` 6 px) with a compass pip at the bottom. Under it, centred, "X n  Y n" = world X/Z in
  whole metres (was the build-tile readout), formatted only when a metre changes.
- Layout: desktop vitals block = 300 + badge column (78). Compact canvases (844x390) keep 300 px so the centre band
  (top feed, quest card) is unchanged; the bars there are 198 px.
- Capture hook: `--shot=` paths containing `levelbadge-lvN` (HudrulesShot): Lv N, 72 % HP, 38 % strain, Well Rested +
  dirty + thirsty; `trail` freezes a 92 % -> 45 % health ghost.

## Tests
- New `game/tests/t_levelbadge.gd`: tiers for Lv 1/20/40/58/60 climb (0,1,3,4,5); badge on screen, left of the bars,
  at the right tier, reach growing; no vitals panel / minimap box in source; sticker on the belt at the marker; buff +
  debuff chips >= 38 px, touch >= 64 on compact, tooltip still pins; stomach leads the row; ghost trail (drop/hold/ease,
  heal lead); coordinates follow her and hang under the map. Both 1600x900 and 844x390.
- Updated for the owner's reversals: `t_levelbar` (badge column, ring position, compact bar width), `t_treadmill`
  (belt starts after the badge column), `t_hudrules` (ring under the vitals).
- `tools/all_tests.sh`: TOTAL 126 pass=126 fail=0. `tools/smoke.sh --no-import`: SMOKE PASS.

## Captures
`docs/orchestration/reports/levelbadge/levelbadge-lv{5,30,58,58-trail}-{1600x900,844x390}.png`.
Captures must be written outside a path containing "tree" (e.g. `worktrees/`): `hunt_hud.gd` opens the Skills sheet for
any `--shot` path containing "tree". I shot to the scratchpad and copied.

## Assumptions
- Level cap 60 (owner's reference; no data names one). Tier breakpoints 10/25/40/55/60 are mine.
- The stomach ring had no tap tooltip to keep (none exists in canon); it still has none.
- Coordinates are world metres from the island origin, not build tiles.

## For the next agent
- `HuntHud._bar` takes an optional `trail_key`; `HudBuffRow.draw_chip` is the shared B/W chip.
- Branches touching the vitals lines in `hunt_hud.gd` (`full_w`, `ring_d`, the status row start) will conflict.
