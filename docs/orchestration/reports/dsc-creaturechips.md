# dsc-creaturechips — creature status effects look and count like the player's

Owner complaint (verbatim): "bleed on dinosaurs doesn't show stacks count and doesnt match the
player's bleed". The plate showed a plain red blood-drop ring with no number, the top target bar a red
"Bleeding" pill, and the floating "BLEED" text overlapped the creature's name.

## Shipped
- **Shared renderer**: `HudBuffRow.draw_chip` (game/scripts/ui/hud_buff_row.gd) gained a `stacks`
  parameter and a `draw_stack_badge` (black disc, white rim, white count, bottom-right) — the same
  numbered badge look. A new static `HudBuffRow.creature_entries(c)` builds the same entry shape the
  player's row uses ({key, name, kind, desc, time_left, icon, color, stacks}) from a creature's
  StatusEffects, so creature chips and player chips come from one helper.
- **Creature plate** (game/scripts/ui/creature_plates.gd): the old 26 px StatusGlyph countdown ring row
  (`_status_rows`/`_add_status`/`_status_icon`) is gone. line3 now lays out `CreaturePlateChip` nodes
  (new game/scripts/ui/creature_plate_chip.gd, 38 px) that draw `HudBuffRow.draw_chip` with the stack
  badge. Plate full height 102 -> 114, tame row moved under the chip row, pill fit follows.
- **Hunt target bar** (game/scripts/ui/hunt_hud.gd `_draw_target_plate`): the red named pills
  (`HudStatusChip.draw_named`) are replaced by the same 38 px chips with stack badges, one per active
  status, laid out on `HudBuffRow.PITCH`; rects exposed as `target_rows["chips"]` for tests/tooltip.
- **Floater fix**: status floaters (BLEED, VENOM...) now spawn at y=24 — below the plate's 0..20 name
  strip — and rise slower (18 px/s vs 34) so they never cross the name line.
- **Colour rule kept**: floaters still use `Creature.STATUS_COLORS` (bleed red, venom green-yellow as
  its status colour; green is reserved for heals — the heal float path is untouched).

## Tests
- New `game/tests/t_creaturechips.gd` (20 checks): 3-bleed-stack creature reports stacks 3 through
  `creature_entries`, the plate draws its chips through the player's renderer with the badge, the target
  bar draws the same chips, the old glyph ring and named pill calls are gone, two chips (bleed + venom)
  sit side by side without overlap, the floater rect misses the name rect, bleed's colour is red.
- t_statusfx, t_targetui, t_hudrules, t_dodgetext, run_all, smoke: all PASS unchanged (they encoded no
  old pill/glyph expectations).

## Verification
`verify_creaturechips.sh` (t_creaturechips, t_statusfx, t_targetui, t_hudrules, t_dodgetext, run_all,
smoke, report file) prints **VERIFY PASS**.

## Notes / assumptions
- Creature afflictions (kind "effect") now render as chips with no buff/debuff arrow (arrow only for
  buff/boon/debuff kinds) — matches the owner's ask that they "match the player's" look.
- A `.godot` class-cache refresh (`--import`) was needed once after adding CreaturePlateChip; stale
  caches fail all scripts with "missing CreaturePlateChip".

## For the next agent
- `HudBuffRow.draw_chip` signature changed (added `stacks: int = 1`); only t_creaturechips and this code
  call it with more than 5 args.
- If a new creature status is added, no plate/table edits are needed: it shows automatically via
  `creature_entries` as long as it has a statuses.json row (icon falls back to two letters).
