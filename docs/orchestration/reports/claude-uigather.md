# UIGATHER — B1 field HUD (gathering) and B2 combat HUD

Branch `claude/mmo-uigather` (from `claude/mmo-overhaul`). Spec: `docs/design/ui-redesign-spec.md` §4,
§5, §6, §7 B1/B2, §11. Credits spent: none.

## What shipped

### B1 field HUD, gathering variant
- `gather_radial.gd`: hexes are 124 px flat-top on desktop and 64 px on a compact canvas
  (`GatherRadial.hex_px`). Each hex has a HUD fill, a light rim and the resource symbol greyed out
  (`icon_grey`). The seconds sit on top and the units left at the bottom. Labels show the name only, in a
  21 px box on desktop. A locked option reads "Log · Needs an axe" in DANGER. The picked hex pie-fills
  0 → 1 per unit (`fill_ratio`), and the other hexes stay disabled while it runs.
  `show_running(node, inv)` opens the fan with that option running when a gather starts without it
  (INTERACT, Space, a one-option node).
- `radial_hold.gd`: `solve()` takes the hex size (default 64, so t_gatherglide is unchanged).
- `gather_ring.gd`: retired for harvest nodes (see Assumptions). `player_actions._update_gather_ring`
  now opens the radial on its node and feeds its pie. The ring stays for tame feeding and crafting.
- `hud_pills.gd`: the pill is a dark box with the resource glyph greyed (`HexButton.grey_texture`). It
  is 30 px tall with 18 px type on desktop and keeps 22 / 14 on a phone. A depleted node dims the glyph
  and a missing tool tints it red, taking over from the old dot. Harvest pills are tappable:
  `HudPills.hit_pills` / `node_at()`, read in `HuntHud._input`. The tap calls
  `player._interact_tap_target(node)`, the same as tapping the node, and cancels the world-tap fallback
  behind it.
- Camera pan: already built (`Player.camera_interest` → `IsoCamera.SELECTION_BIAS` 0.35, follow lerp
  8). It covers the open radial's node and the gather target. Values left alone (camera is outside this
  package).
- `yield_card.gd` (new, `YieldCard`): the yield card. It replaces the top-centre "+n Item" toast, and
  `pickup_toast.gd` is deleted (`station_craft.gd` no longer creates one; the HUD's toast already
  covers crafts).
  - The card is 300 px wide (220 on a phone) and sits above the worked node, or above the survivor for
    crafts and loot. It is placed with `UiTokens.free_spot` off `taken_rects` and the open radial.
  - Contents: a natural-colour thumbnail (`ItemStack.tint_color`), the name, "Wood · Lv. 1 · +2", and
    trait chips from every instance that gain added (rare first). A 3 px top edge takes the best chip's
    colour.
  - It shows for 3 s, or until the next gain.
  - New instances are found by diffing the bag's uids against a baseline taken at `HuntHud.bind`.
- Left XP feed (§6, owner §1.6): `YieldCard.draw_feed` draws the skill XP toasts under the vitals. Each
  row has a hex with the skill's initial, "Gathering +3 XP Lv. 1" and a thin XP bar. `HudEventState` is
  unchanged.
- `hunt_hud.gd` hooks:
  - the `_yield` member, with `toast()` → `show_gain`, `_process` → `tick` and `bind` → `sync`;
  - in `_draw`, the skill-toast and item-toast blocks are replaced by two calls (feed, card);
  - the pill tap in `_input`.

### B2 combat HUD
- `hunt_hud.gd` (small entry points only):
  - `_combat_style()` gives the NET/TACKLE/KICK/ROLL, AUTO, FEED and CHASE hexes the HUD fill and rim.
    ROLL gets the "Q" key cap.
  - `_net_gold()` makes the NET hex GOLD-filled with a GOLD rim and a dark net while it is enabled. It
    is enabled when the spec 09 window is open (stunned or ≤ 30 %) and a net and technique cover the
    tier, and it is not FIRE/SIEGE.
  - The target plate's HP bar turns GOLD in the capture window. Its status chips are now named chips.
  - `_draw_capture_hint()` draws "Weaken to 30% to capture" / "Capturable — throw the net!" by the
    animal. It is drawn before the pills so they give way to it.
- `hud_status_chip.gd`: `draw_named()` draws an icon, the name and a rim in the status's `fx_color`
  (Bleed, Groggy). The player's own 26 px chips are unchanged.
- **TAMINGODDS:** the NET hex's `bottom_text` stays empty for the odds figure, and `_net_gold` is the
  only NET styling hook. `t_uigather` asserts the empty bottom line.
- The treadmill draws in combat as before. §11 is kept: no code path changed, and t_targetui is green.
- `creature_plates.gd` and `target_swords_hex.gd` are untouched (see Not done).

### Tests and captures
- New `game/tests/t_uigather.gd`, run at 1600x900 and 844x390:
  - a pill tap opens the radial;
  - hex sizes are 124 / 64;
  - hexes and labels are on screen, the hexes don't overlap each other, and no label sits on a hex;
  - the pie fills and the other hexes lock;
  - a gather with no fan opens the radial running, with the ring hidden;
  - the yield card shows the rare chip first, colours its edge, sits on screen and is 300 px wide;
  - the XP line is in the left feed and clear of the card;
  - NET is not gold at 60 % and is gold at 25 %, with its bottom line free.
- `t_gather.gd`: one set-up node moved by -0.5 m. The shorter name-only labels had moved the radial
  off the HUD's own notice spot, so the precondition "the HUD-only spot sits on the radial" no longer
  held. The assertion itself is unchanged.
- `t_ui.gd`: the owned-script list drops `pickup_toast.gd` and adds `yield_card.gd`.
- Capture lab `game/scripts/dev/uigather_lab.gd` (+ `scenes/dev/uigather_lab.tscn`), run windowed:
  `--resolution WxH -- --lab=uigather_lab --shot-dir=DIR --canvas=WxH`. It runs the real input and
  gather paths and checks itself (`failed=0` at both sizes).

| Screen | 1600x900 (saved at 960x540) | 844x390 |
|---|---|---|
| B1 field HUD | uigather/b1_field_hud_1600x900.png | uigather/b1_field_hud_844x390.png |
| B1 gathering | uigather/b1_field_hud_gathering_1600x900.png | uigather/b1_field_hud_gathering_844x390.png |
| B2 combat | uigather/b2_combat_hud_1600x900.png | uigather/b2_combat_hud_844x390.png |
| B2 net ready | uigather/b2_combat_hud_net_ready_1600x900.png | uigather/b2_combat_hud_net_ready_844x390.png |

All are palette-quantized PNGs under 300 KB (ffmpeg palettegen). The desktop ones are downscaled to
960x540.

## Gates
`t_ui`, `t_uiicons`, `t_fieldhud`, `t_gather`, `t_targetui`, `t_statusfx`, `t_uinav`, `t_controls`,
`t_gatherglide`, `t_skillfeel`, `t_uigather`, `t_capture09`, `t_card2d`, `t_process`: all PASS.
`run_all`: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.

## Assumptions (`# ASSUMPTION:` in code)
1. Open question 7: `gather_ring.gd` is retired for harvest nodes. The hex pie, the hex's units-left
   count and the yield card cover progress, depletion and the result. The ring stays for taming and
   crafting (`gather_ring.gd` header, `player_actions._update_gather_ring`).
2. A gain whose new instances cannot be identified falls back to the bag's last instance of that id
   (`yield_card.gd`).
3. Only ROLL shows a desktop key cap. The canvas shows 1/2/4/Q on the combat hexes, but `tactic_1..4`
   have no handler (`hunt_hud.gd`).
4. A pill tap behaves exactly like a tap on its node. That means one tap opens the radial; the spec's
   "select" step is that tap.

## Not done / risks
- The yield card and GatherFeedback's rising "+n Item" stack (in `gather/`, left as is by instruction)
  both show on a gain. They avoid each other only through the shared free-spot rules. The owner may
  want the "+n" rise dropped now that the card exists. That change belongs in `gather_feedback.gd`.
- The spec's camera value (45 % of the screen offset, 0.6 s ease) is not applied. The existing lean
  (0.35, lerp 8) is kept, because `iso_camera.gd` is outside this package and other tests read it.
- `creature_plates.gd` was not restyled. On desktop the world plate's "Timid" nature chip is partly
  covered by the HP bar in my captures. This comes from the NATURES layout and is not part of this
  change.
- Party frames, the quest-card restyle and quick-slot counts (§6) are not part of this package.
- Trait polarity comes from `InvAttributes` (inv_ui.json classes plus the rules.json rare list), which
  is the same source the bag and craft screens use. §5's open data question stays open.
