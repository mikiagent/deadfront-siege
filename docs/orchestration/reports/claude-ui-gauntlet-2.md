# UI gauntlet pass 2: defects found in the redesign screenshots

Date: 2026-09-21. Agent: Claude Code, with a scoped Grok 4.7 subagent for three density fixes.
Presentation only. No gameplay, save, taming, economy or combat change.

Grounding: reviewed commit 7face69's own screenshots at `/tmp/deadfront-ui-shots`, the live
alias at `b6377b3d0/9b5c9415b4`, and the real Durango captures in `docs/reference/` (the
previous run reported those as missing; they exist and were read this time).

## Fixed

1. **Contextual wheel now reads like Durango's.** `ContextRadial.hex_positions` laid the option
   hexes on a 1.6-radian arc that always fanned to one side, so the source label sat under the
   lower hexes and collided with the next node's label. It is now a full ring around the anchor
   whose radius clears the centred title, the title and level sit inside the ring, labels face
   outward from the ring centre instead of from the screen midline, and when the ring is clamped
   against a screen edge the title steps aside from any hex it would touch.
2. **Action words no longer cross the hex outline.** `HexButton` drew the caption with
   `bottom_text`, which is the count slot inside the hex. New `HexButton.caption` draws the word
   under the hex, and the HUD rail, food, skills, whistle, feed, chase and done hexes use it.
   `CAPTION_H` reserves the room so the rail still sits inside the safe area. The bottom-right
   held-tool hex (`held_item_slot.gd`) matches, and an edge-hugging hex right-aligns its caption
   to the hex edge instead of running off screen. Captions ellipsise at 1.25x the hex width, so
   "STONE WORK KNIFE" reads as "STONE WO…" instead of being cut by the screen.
3. **Desktop vitals are legible.** The panel was 236 px with 12 px bars and 12 px numbers. Desktop
   now gets a 300 px panel, 16 px health and energy bars, 10 px hunger and thirst bars, and
   `UiTokens.body`-sized numbers vertically centred in each bar. Phone keeps the compact block.
4. **Quest chip fits its island name.** 168 px truncated "Home Grassland" to "Home Grassl…";
   desktop is now 240 px.
5. **Character screen fills the panel** (Grok): bag and equipment cells scale to at least 64 px
   at 1600x900, still 5x4 and 3x3, stat rows use `UiTokens.body` on the 8 px rhythm, the
   equipment grid is vertically centred against the bag.
6. **Craft metadata never truncates** (Grok): the recipe name and `Lv 60 · 2.0s` are separate
   labels, the metadata keeps a reserved width, only the name ellipsises.
7. **Growth list clears the button bar** (Grok): the scroll container stops 8 px above the
   EQUIP / CLOSE bar and its content carries a matching bottom margin.

## Tradeoff

Craft rows are taller because the actions moved under the title so the name row keeps the column
width: six recipes are visible at 1600x900 where eleven were before. Targets stay at 44 px and
above and nothing truncates. Revisit by widening the recipe column against the mostly empty
result column rather than by shrinking text.

## Gates

- Godot import clean; `tools/test.sh` `[tests] PASS`; `tools/smoke.sh` `SMOKE PASS`.
- `ai_validation_lab` `[aival] PASS`; `ui_family_lab` prints inventory/animals/unlimited/active_cap=3.
- `ui_screenshot_lab` PASS for hud, inventory, animals, craft, atlas, death and radial at
  1600x900 and 390x844; every PNG was inspected, not just the lab verdict.
- `--gather-test` passes for a bush and a tree, and still logs `[player] work clip gather_chop`.
- Real home camp captured windowed at 1600x900 to check the rail, held-tool hex, harbour hex and
  quest chip against actual world content rather than the lab's empty scene.

## Not done

Desktop Chrome interaction was not re-exercised by hand; the deployed soak covers mouse input.
The audit's "low-detail stand-in structures" is art, not layout, and is untouched.
