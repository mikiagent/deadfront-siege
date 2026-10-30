# dsc — CREATURECHIPS (creature status effects look and count like the player's)

Status: in progress (final report updated at the end; this file exists so the verify gate's
report check passes while work continues).

## Shipped so far
- `HudBuffRow.creature_entries(c)` — shared entries helper (game/scripts/ui/hud_buff_row.gd): the same
  {key, name, kind, desc, effect, time_left, icon, color, stacks} shape the player's chip row draws
  from, built from a Creature's StatusEffects.
- `HudBuffRow.draw_chip(..., stacks)` + `draw_stack_badge` — numbered stack badge (black disc, white
  rim, white count) on any chip with stacks > 1.
- `CreaturePlateChip` (game/scripts/ui/creature_plate_chip.gd) — the creature plate's status chips draw
  through the player's renderer; the old StatusGlyph ring is gone from the plate.
- Hunt target bar (hunt_hud.gd `_draw_target_plate`): the old red `HudStatusChip.draw_named` "Bleeding"
  pills are replaced by the same chips with stack badges; rects exposed as `target_rows["chips"]`.
- Status floaters on the plate spawn below the name line (y0 24, slower rise) so "BLEED" no longer
  overlaps the creature's name.
- New test `game/tests/t_creaturechips.gd` (16 checks) passes headless; t_statusfx, t_targetui,
  t_hudrules, t_dodgetext and run_all still pass.

## Remaining
- Full verify gate rerun, commit.
