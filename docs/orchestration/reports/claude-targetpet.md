# claude-targetpet: TARGETUI and PETRADIAL landed on the integration line

Branch `claude/mmo-targetpet`, cut from `claude/mmo-overhaul` at 080f2617. Not pushed, not merged into
`claude/mmo-overhaul`. Credits spent: none.

## What landed

Commits, in order:

1. Merge `claude/mmo-targetui` (tip 9f7c3ce8). It brings the new files: TargetSelect, TargetSwordsHex, t_targetui and targetui_lab.
2. `f20dafe7` applies `claude-mmo-targetui-hooks.patch` (player_input, player_pets, hunt_hud, creature_plates, hunt_lab).
3. `HUD desktop: whistle column stands on the BAG hex ...` is a fix for a conflict between canon and TARGETUI (see below).
4. Merge `claude/mmo-petradial` (tip 7a63b9e1). It brings PetRadial, PetRenameDialog, the ride/rename icons, t_petradial and pet_radial_lab.
5. `06b569b0` applies `claude-mmo-petradial-hooks.patch` plus the follow-up fixes listed below.

Both branches kept their call-site edits in a hooks patch instead of committing them, so the `git merge` steps
had no conflicts. The real conflicts showed up when I applied the patches with `git apply --3way`.

What the owner gets (owner ruling 2026-10-21, spec 23):

- **Target select.** Tapping a wild animal only selects it: a ring, the plate and the red swords hex beside it.
- **Starting a fight.** The swords hex starts the fight, and so do E and F, but only while the hex shows.
- **Self-defence.** An animal that bites is fought at once. `Player.receive_creature_hit` is unchanged.
- **Second tap.** Tapping an animal that is already selected does nothing more, because `TargetSelect.select` returns early.
- **Pet radial.** Tapping your own pet, or pressing E beside it, opens the radial: Animals, Bag, Feed, Ride (Dismount while riding), Dismiss, Rename.

## Conflicts and resolutions

- **player_input.gd `interact_tap_target` (TARGETUI patch).** Canon has since added a `ConstructionSite` branch right
  after the old `else: p.actions.attack(c)`. Resolution: I dropped the tap-attack, because a tap now only selects,
  and kept canon's ConstructionSite branch. Canon's water-tap `_walk_to_tile` change merged cleanly with TARGETUI's
  `selection.clear()`.
- **player_input.gd (PETRADIAL patch), two hunks.** Both packages made the same `tap_blocked()` fallback change and
  the same hunt-stop change. I kept TARGETUI's lines, which already contain PETRADIAL's change. PETRADIAL's report
  calls for exactly this resolution.
- **player_actions.gd.** Canon added `clear_prop_in_front()` in the same spot where PETRADIAL adds `rename_pet()`.
  I kept both.

## Fixes beyond the two patches (canon moved under them)

- **BAG covered SIC on desktop.** Canon 198ced6e put a BAG hex on HANDS's own layer, which sits above the HUD. It
  landed exactly on the SIC whistle, so SIC never got a tap. This is why t_targetui failed 3 cases after the merge
  ("a tap on SIC runs SIC", "SIC with the swords shown sics the selection"). The changes, in `hud_layout.place_desktop`:
  - the whistle column now stands on BAG (moved up 82 px);
  - End Combat moves 70 px left (`r.x - 270`), so GUARD clears it at 900 px tall and at 720.

  BAG is now a taken rect in `HudLayout.taken_rects` and in `HuntHud`'s placer rects, so plates, toasts and the swords
  hex keep off it.
- **PetRadial fade.** The ring fades HANDS only when it covers HANDS's own rect. It now also checks the BAG hex,
  which is a child of HANDS and fades with it.
- **`_open_animals` became `open_animals`** (PETRADIAL). TARGETUI's `targetui_lab.gd` and `t_targetui.gd` still
  called the old name, so I updated both. This changes no assert.
- **needs_lab.gd** cast the pet menu to StationMenu, which now gives null and would crash. It now skips menus that are
  not StationMenu and feeds through `PetRadial.choose`.

The pre-merge fix lists in the two reports are the hooks patches plus PETRADIAL's merge note on `player_input.gd`.
All of them are done. Neither report lists other required pre-merge code fixes. The TARGETUI tip 9f7c3ce8 (r3) has
its fixes in the commit, but its report text stops at r2.

## Gates (final tree, Godot 4.7.1 mono, headless via gslot)

Logs: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/targetpet_gates/`
(`summary` holds one line per test).

- Import: exit 0, no ERROR lines.
- `t_targetui`: `[t_targetui] PASS`. `t_petradial`: `[t_petradial] PASS`.
- `t_ui`, `t_combat`, `t_player`, `t_tame`, `t_controls`, `t_gatherglide`, `t_mapui`, `t_skillfeel`, `t_foodfx` and
  `t_camera` each exit 0 with 0 SCRIPT ERROR. Overall, 59 of the 63 `t_*.gd` files plus run_all exit 0 with 0 SCRIPT ERROR.
- `run_all.gd`: `[tests] PASS`. It prints the 3 compile-order SCRIPT ERRORs (`Identifier not found: TouchControls`),
  the same ones the base is documented to print.
- `t_save`: exit 0, with its 5 deliberate SCRIPT ERRORs.
- `smoke.sh --no-import`: `SMOKE PASS`.
- **Two failures that predate this merge.** This merge does not touch `game/data` except `ui_icons.json` (+ride, +rename).
  - `t_mounts`: `FAIL coelophysis has no saddle and is not in mounts_skip.json`. Base commit 47592db4 removed the
    coelophysis saddle but did not add it to `mounts_skip.json`.
  - `t_uiicons`: 14 FAIL, because the FOODFX statuses (caffeinated, tastes_*, hot_food, cold_food) have no UI icon.

  Both belong to their owning packages. I did not change them here.

## Needs a visual check at 844x390 and 1600x900 (no windowed runs were allowed)

- Desktop 1600x900 with a pet out:
  - the SIC, HEEL and GUARD column now sits above BAG;
  - End Combat sits 70 px further left;
  - check that nothing overlaps (whistles, BAG, End Combat, ROLL and AUTO), and also at 1280x720.
- The swords hex beside an animal near the bottom-right on desktop, now that BAG is a taken rect.
- The pet radial at 844x390 in a fight: the BAG hex should fade along with HANDS.
- Canon's PHONEHUD, CAMERA (long lens) and GATHERGLIDE against the swords hex placement and the ring placement. The
  packages' own sweeps ran on the older camera. Run `targetui_lab` and `pet_radial_lab` at both sizes (gl_compatibility,
  plus Forward+ at 1600).

## Risks

- A capture-rule change may land soon in `hunt.gd` / `hunt_hud.gd`. This branch touches `hunt_hud.gd` only in the
  patches' small hunks: the swords hex child, the plate's selection fallback, the name band and portrait icon,
  `open_animals`, and the nameplate under the radial. Also the BAG placer rect. It does not touch `hunt.gd`.
- The End Combat move on desktop is a layout change to canon. It is small, but the owner should see it.
