# claude-mmo-targetui: tap selects, the red swords start the fight (spec 23)

Owner, verbatim: "You can tap on an animal, that selects it, if you press red swords you initiate combat with it."
Spec `docs/design/durango-prompts/23_target_select_pet_radial.md`, reference `docs/reference/durango-target-select.webp`.
The pet radial half of spec 23 is not in this package.

Branch `claude/mmo-targetui` from `claude/mmo-overhaul` at e5f3ec8a, with `claude/mmo-overhaul` ddaab662 merged in.
Commits:

- `157cf440` TargetSelect, TargetSwordsHex, t_targetui
- `a0a6e696` the swords hex redrawn closer to the reference, and targetui_lab
- `2ce32755` merge of `claude/mmo-overhaul` (WATER, specs 23-24)
- `29be035d` this report and the hooks patch
- `6ef4a23a` review round 1 fixes (swords hex placement, E/F/SIC only while the hex shows, tame and mount cases)
- `1ce733b9` merge of `claude/mmo-overhaul` 946da955 (HUD-DAYNIGHT); the hooks patch was rebased onto it
- `026b214a` round 1 report and hooks patch
- `0d819983` review round 2 fixes (swords beside a bench, animal tap beside a bench, crowded phone screens) and
  the regenerated hooks patch
- the commit that updates this report

The call sites are in files that other packages own, so they are not committed on the branch. They ship as
`docs/orchestration/reports/claude-mmo-targetui-hooks.patch` (5 files, 45+/13-). `git apply --cached --check` passes on
`claude/mmo-overhaul` acc684a6 (no `game/` change there since 946da955, the last merge). Every gate below ran in the work tree with the patch applied. The branch does nothing
until the patch lands (nothing creates the selection or the hex), and the patch does not compile without the branch's
two new classes, so they must land together.

Credits spent: none.

## What the owner gets

- **Tapping a wild animal only selects it.** These appear:
  - a pale ring at its feet;
  - the top-centre target plate: a dark band, the name, a red "Lv. n", the portrait square on the right, and a red
    HP bar with "hp / max";
  - its world name plate;
  - a translucent dark hex with red crossed swords beside the animal. The hex follows the animal, and on desktop it
    has an "E" key cap on its right edge, as in the reference. It shows only while:
    - the animal's middle is inside the screen (off screen it hides; it is never pinned to the screen edge);
    - the animal is within 28 m (`PlayerActions.ATTACK_SEEK_RANGE`; the hunt drops past that, so the swords would
      start nothing);
    - the animal cannot be field-tamed right now (FEED/NET own that state);
    - a spot is clear of every HUD block and hex (`HudLayout.taken_rects`). First choice is beside the animal's
      middle (right, else left, slid at most one hex up or down), as in the reference. When the HUD crowds that (on
      a phone the selection's own plate, the minimap or a hex cluster often does), the hex takes the clear spot
      touching the animal's screen box nearest the right-hand one, never over its middle. Only when no clear spot
      touches the animal does it hide rather than cover a HUD control.

    It is the HUD's first child, so where it and a HUD control ever meet, the HUD control gets the tap. While riding,
    the key cap is hidden, because E dismounts.

  No combat HUD, red frame or swing appears until you press the swords.
- **The swords, E or F start the fight** on the selected animal through `PlayerActions.attack`. E and F act on the
  selection only while its swords hex shows (`TargetSelect.shown()`). Otherwise E does its usual job (bench, bed,
  bonfire, pet, ...) and F fights the nearest animal within 28 m. Online that is the
  `act.attack` intent and nothing is applied locally. Auto-attack, Chase/Hold, End Combat and the bottom-right
  cluster (NET, TACKLE, KICK, ROLL, AUTO) work as before. The swords hide while that animal is the fight and come back
  after End Combat. F with nothing selected still fights the nearest animal within 28 m.
- **An animal that bites is fought at once**, selected or not (`Player.receive_creature_hit` is unchanged). The
  survivor is never defenceless.
- **Deselecting:** tap empty ground, or tap another target (another animal, a tree or a station). The selection also
  drops when the animal dies, is tamed or freed, or is more than 40 m away.
- **The aggro ring stays visible.** The select ring is a separate pale torus, and both show together (aggro_select
  shot).
- **SIC** with no fight sics the pets on the selection while its swords show, else on the nearest wild animal as before
  (PRD 10.2, "pets you have summoned join").
- **Pets are excluded.** Tapping your own pet never selects it and never shows the swords, and `select(pet)` is refused.
  Out of a fight, with the survivor standing still, the pet tap still opens its hex menu. A tap on your pet during a
  fight no longer ends the fight; on the old code it called `hunt.stop()`. The menu still does not show during a
  fight: the chase route keeps `nav_active` true and `StationMenu` closes the menu the frame it opens. That was
  already broken before this package (the review's E_pet_tap_in_fight shows menu=false on the old and new code); it
  is left to the pet radial package.
- **Capture stays where it was.** The NET hex in the combat cluster still shows capture readiness. Tapping a
  knocked-down tameable animal still begins the field tame.

## Files

New (committed):

- `game/scripts/player/target_select.gd`, class `TargetSelect` (RefCounted, owned by PlayerInput). It provides
  `select`, `clear`, `current` and `engage`.
- `game/scripts/ui/target_swords_hex.gd`, class `TargetSwordsHex` (a 64 px HexButton). It draws the swords itself,
  because the `attack` UI icon is a club, not crossed swords.
- `game/tests/t_targetui.gd`
- `game/scripts/dev/targetui_lab.gd` and `game/scenes/dev/targetui_lab.tscn`

Hooks patch:

- `player_input.gd`
  - adds `selection`;
  - the deferred desktop-click fallback ignores a press a HUD control took (`tap_blocked()`), so pressing the swords
    beside a bench no longer opens the bench;
  - a tap whose ray lands straight on a wild animal selects it, even within 96 px of a station
    (`_station_for_tap`, used by `tap_world` and the fallback);
  - a creature tap selects instead of calling `actions.attack`;
  - a tap on any creature keeps the hunt;
  - `_walk_to_tile` deselects;
  - E engages the selection while its swords show, after the dismount check;
  - F prefers the fight, then the selection while its swords show, then the nearest animal.
- `player_pets.gd`: SIC with no fight takes the selection while its swords show, before the nearest animal.
- `hunt_hud.gd`
  - builds the swords hex as its first child (under every HUD control);
  - the plate shows the hunt target, else the selection, else the last animal attacked;
  - the plate gets a dark name band;
  - the Animals head icon replaces the grey first-letter square.
- `creature_plates.gd`: the selection's world plate is forced visible and emphasised.
- `dev/hunt_lab.gd`: after its tap it calls `selection.engage()`, so its acceptance shot is still the combat HUD.

## Review round 2: what changed

Each finding, the fix, and the check that now covers it. The new t_targetui cases fail on the round-1 code
(round-1 `target_swords_hex.gd` and round-1 `player_input.gd` hook, new test): exit 1, `FAIL count=3`, one per case below
(`targetui/r2fix/t_targetui_r1code.log`). On the fixed tree the test passes.

- **Major: pressing the swords beside a bench opened the bench and dropped the selection.** The deferred desktop-click
  fallback now returns when `tap_blocked()` says a HUD control took the press. So a press on the swords (or any HUD
  button) is never also a world tap, with a mouse or with a finger (touch sends the same mouse press).
  - Check: `station: the swords N px from a bench fight the selection`. A workbench sits under the hex; the click must
    leave `hunt.target == selection`, the selection kept and the bench menu closed. On the round-1 code: hunt null,
    selection null, bench menu open.
  - Reviewer probe rv2k2_lab on the fixed tree, 3 spots in each config: 9 of 9 `after_release hunt=protoceratops`
    with the selection kept and `station menu visible=false`, in gl_compatibility 1600x900 (mouse), Forward+
    1600x900 and gl_compatibility 844x390 (`--touch`, ScreenTouch). The reviewer's run on the round-1 code had 6 of 6
    `hunt=null sel=null` with the station menu open.
- **Major: on the landscape phone the swords often hid for an animal in plain view.** `_spot()` still tries beside
  the middle first (right, else left, slid at most one hex), as in the reference. When the HUD crowds that, it searches
  a 16 px grid over the animal's screen box grown by one hex, inside the safe area. It takes the clear spot (off every
  HUD block and hex) nearest the right-hand one, never over the animal's middle. It hides only when no clear spot
  touches the animal. The search runs only on frames where both side spots are blocked.
  - Check: `phone: the swords show whenever a clear spot touches the animal`. The test runs at 844x390 and sweeps
    protoceratops and T. rex at 6 and 12 m over 12 angles. Every on-screen case with a hex-sized clear spot touching
    the animal's box (32 px grid) must show the swords. Fixed tree: 44 of 46 on-screen cases shown, none missed. The
    2 hidden ones sit at the bottom edge under the bottom-left hexes. Round-1 code: 32 of 46, 11 missed.
  - Reviewer sweeps re-run on the fixed tree. rv2s_lab at gl_compatibility 844x390 touch and at 1600x900: every
    on-screen stegosaurus, triceratops and T. rex at 4, 6, 9 and 12 m shows the swords (stegosaurus 6 m 12/12, T. rex
    6 m 12/12, T. rex 9 m 10/10). The reviewer had stegosaurus 6 m 10/12 and T. rex 6 m 5/12 at 844x390.
  - rv2_probe_lab at 844x390 touch: T. rex 6, 10 and 16 m all shown (12/12, 8/8, 8/8; the reviewer had 3/12, 5/8,
    4/8). Protoceratops 3, 5 and 8 m all shown; 12 m 7/11 (reviewer 6/11); 18 m 1/2 (reviewer 0/2). At 1600x900
    every on-screen case shows.
  - The 5 protoceratops cases still hidden at 844x390 are covered by the HUD. A diagnostic sweep (`targetui/diag/`)
    logged the box and the HUD rects and shot each case. The animal sits under the status block (12 m 180 deg), the
    target plate at the top edge (210, 239 deg), the minimap (300 deg) or the bottom-left hexes (18 m 90 deg). The
    12 m 180 and 300 deg shots show the animal cannot be seen at all, so there is nothing to put the hex beside.
  - The reviewer's case: `diag/fall844/fallback_stegosaurus_6_210.png` is the same frame as the reviewer's
    `r2/s844/hidden_stegosaurus_6_210.png`. The hex now sits at (512, 88), right of the stegosaurus under the plate.
    T. rex 6 m at 0 and 270 deg (both hidden before) show it too, and a touch press on it starts the fight
    (`fall844.log`, 0 SCRIPT ERROR, no `[rv] OVERLAP`).
- **Minor: a tap on an animal near a bench opened the bench.** `tap_world` and the click fallback now skip the 96 px
  station pick when the ray lands straight on a wild animal (`_station_for_tap`). Only a direct ray hit counts, not
  the 1 m bubble, so a tap on the bench beside a grazing animal still opens the bench.
  - Check: `station: a tap on an animal N px from a bench selects it`. Round-1 code: selection null, bench menu open.
  - rv2_probe_lab K_station_tap_animal: `sel=protoceratops` and `menu=false` at 844x390 touch (28 px from the
    campfire) and 1600x900 (64 px). The reviewer had `sel=null` there.

## Review round 1: what changed

Each finding, the fix, and the check that now covers it. The new t_targetui cases fail on the round-0 code:
exit 1, `FAIL count=12`, all of them in the new cases (the old cases still pass there).

- **Major: swords hex pinned to the screen edge, on top of SIC, taking its taps.** The hex now shows only while the
  animal's middle is inside the viewport. It also needs a spot beside the animal that is clear of
  `HudLayout.taken_rects` (right side, else left, slid at most one hex up or down), or it hides. It is the HUD's first
  child, so a HUD control above it in tree order gets the tap.
  - Checks: `off screen: no swords hex` and `a tap on SIC runs SIC and starts no hunt`.
  - Checks: `HUD: beside SIC the swords never cover a HUD hex`. The animal is placed at 5 spots left of SIC. The old
    code covered SIC at all 5, and 4 of the 5 SIC clicks started a hunt.
  - Checks: `HUD: the swords hex sits under the HUD hexes in tree order`.
  - Re-run of the reviewer's probes: no `[rv] OVERLAP` line at 1600x900 (Forward+ and gl_compatibility) or at
    844x390 with touch. At 844x390, H_spot_87_80 now puts the hex at (688, 284), clear of CLAIM; on the old code it
    covered CLAIM at (752, 284). In probe2 (26 m away, off screen) `X_before swords=false` at both sizes, so nothing
    sits on SIC.
- **Major: E engaged a selection 26 m away, off screen, ahead of every other E interaction.** E (and F) act on the
  selection only through `TargetSelect.shown()`, which returns it only while its swords hex is visible. The hex hides
  past 28 m (`ATTACK_SEEK_RANGE`), off screen, and while its spot is blocked. Otherwise E falls through to the normal
  chain.
  - Check: `off screen: E beside the pet does its own job, no hunt`.
  - Probe F_far_after_E (dist 26.1): `hunt=null` at both sizes and in both renderers. Before the fix it was
    `hunt start protoceratops`.
- **Minor: E key cap shown while mounted.** The cap is hidden while `player.mounted_on` is set; E keeps dismounting.
  Checks: `mounted: the swords show, without the E key cap` and `dismounted: the E key cap is back`. G_mounted_tap
  shows no cap.
- **Minor: swords beside a knocked-down tameable animal.** The hex hides while `FieldTame.can_attempt(selection)`, so
  E does not attack it either. Check: `knocked down and tameable: still selected, no swords` and `E does not attack it`.
- **Minor: SIC ignored the selection.** `PlayerPets.order(&"attack")` with no fight takes `selection.shown()` before
  the nearest animal. Check: `SIC with the swords shown sics the selection` (a nearer wild animal is present).
- **Minor: pet tap during a fight shows no menu.** This was broken before the package, and it is not changed here.
  The "What the owner gets" section above now says so. Left to the pet radial package.
- **Minor: look.** The fill is now translucent grey (alpha 0.72) with a dark rim instead of the white one. The E cap
  overlaps the hex's right edge as in the reference. Crop: `after5/zoom_swords_r1fix.png` next to
  `review/targetui/r1/zr.png`.

## Gates (round 2, all run on the final tree with the patch applied; `claude/mmo-overhaul` acc684a6 has no `game/` change since the 946da955 merge)

Logs: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/targetui/gates_r2fix/` and `gates_r2fix.summary`.

- Every `game/tests/t_*.gd` (24 files) exits 0 and prints PASS. The only SCRIPT ERRORs are t_save's 5 deliberate ones.
- run_all: `[tests] PASS`. smoke: `SMOKE PASS`.
- **t_targetui on the round-1 code** (round-1 `_spot` and player_input hook, new test): exit 1, `FAIL count=3`, as listed
  under round 2.
- **targetui_lab:** `[targetui] PASS`, exit 0, 0 SCRIPT ERROR and 0 ERROR, in Forward+ 1600x900, gl_compatibility
  1600x900 and gl_compatibility 844x390.
- **hunt_lab** headless: `[hunt_lab] PASS`, 0 SCRIPT ERROR.
- **Reviewer r2 probes** (rv2k2_lab, rv2s_lab, rv2_probe_lab) and my two diagnostic probes (rvdiag_lab, rvfall_lab)
  were copied into the work tree for the run and removed afterwards, not committed. All exited 0 with 0 SCRIPT ERROR
  and 0 ERROR. Configs: rv2k2_lab in gl_compatibility 1600x900, Forward+ 1600x900 and gl_compatibility 844x390
  touch; rv2s_lab in gl_compatibility 844x390 touch and 1600x900; rv2_probe_lab in gl_compatibility 844x390 touch
  and 1600x900 (no `[rv] OVERLAP` line); rvfall_lab in gl_compatibility 844x390 touch and Forward+ 1600x900.

## Shots (round 2, looked at, each next to the reference)

`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/targetui/`

- `after6/targetui/{fwd1600x900,glc1600x900,glc844x390}/`: select, engaged, aggro_select, pet_tap. Where the hex is not
  crowded it sits exactly where round 1 put it (select: right of the protoceratops, with the E cap on desktop).
- `after6/rv2k2_lab/{glc1600x900,fwd1600x900,glc844x390_touch}/K_*.png`: after a press on the swords beside the bench
  or campfire, the combat HUD runs on the animal and no bench menu is open.
- `after6/rv2_probe_lab/{glc1600x900,glc844x390_touch}/`: K_station_tap_animal (an animal beside the campfire is
  selected, with its swords over the bench), K_station_swords, and the rest of the probe's beats.
- `diag/fall844/fallback_{stegosaurus_6_210,tyrannosaurus_6_0,tyrannosaurus_6_270}.png` and `diag/fall1600fwd/`: the
  crowded-phone placement. The stegosaurus one pairs with the reviewer's `review/targetui/r2/s844/hidden_stegosaurus_6_210.png`.
- `diag/glc844/diag_*.png`: the 5 protoceratops cases still hidden. The animal is under the HUD.

Round 1 shots:

`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/targetui/`

- `before/{fwd1600x900,glc1600x900,glc844x390}/`: the pre-package flow. wild_tap_0s and wild_tap_2_5s show that the
  tap went straight to combat, with the red frame, End Combat and the path line. Also pet_tap and the other pet shots.
- `after5/targetui/{fwd1600x900,glc1600x900,glc844x390}/` (this round):
  - select: plate, ring, and the swords with E beside the protoceratops;
  - engaged: the combat HUD after the swords;
  - aggro_select: the raptor's yellow aggro ring together with the select ring and the swords. At 844x390 the hex
    slides up to the raptor's head, because the survivor stands on its right-hand spot;
  - pet_tap: the pet menu, with no swords and no plate.
- `after5/rv_probe_lab/{glc1600x900,fwd1600x900,glc844x390_touch}/`:
  - F_far_offscreen: the selection is off screen, and there is no hex and no hex by the T. rex pet;
  - G_mounted_tap: swords with no E cap;
  - H_spot_87_80: the hex is clear of SIC, HANDS and CLAIM. The probe's protoceratops is not visible at that spot in
    this round or in the reviewer's run; it is the probe's ground guess, not this package;
  - the rest of the probe's beats.
- `after5/hunt_lab/hunt_lab_glc1600x900.png`
- `after5/zoom_swords_r1fix.png`: the hex up close.

Compared with the reference:

- The plate layout, the red level, the red HP bar with numbers, and the translucent dark hex with red crossed swords
  and a flush E cap beside the animal all match.
- The reference portrait is species art. We have none, so a white dino head stands in.

- **Stations within 96 px:** a tap whose ray lands straight on a wild animal selects it, even beside a station. A tap
  that misses the animal's collider by less than 1 m still opens the station, so a bench tap is never stolen.

## Assumptions (marked `# ASSUMPTION:` in code)

- A selection drops past 40 m, the distance the HUD already uses for its last-target plate.
- The plate portrait is the generic Animals head until per-species portraits exist.

## For the next agent

- **Pet radial (spec 23, second shot):** not built.
  - `StationMenu` still hides the pet menu whenever `player.nav_active`.
  - `hunt.stop()` does not clear the chase route, so a pet tap right after End Combat can flash the menu shut.
  - Dismiss, Rename and an Animals-menu entry are missing.
- **E beside a bench with an animal selected on screen:** E fights the selection while its swords show (the key the
  hex displays), so a bench or bed needs the ground tap that deselects first. Off screen or past 28 m, E is back to
  normal.
- **Swords hidden when crowded:** the hex hides only when no hex-sized spot clear of the HUD touches the animal's screen
  box, that is when the animal is under the status block, the plate, the minimap or a hex cluster. That animal can then
  be fought only by moving, or after it bites. PRD 10.2's long-press memo is not built.
- **Retargeting during a fight:** tapping another animal mid-fight selects it and shows its swords. The top plate
  stays on the current fight target until you press them.
- **World plate placement:** when the selected animal stands right under the survivor, the world plate is lifted
  well above it. That is the existing overlap rule in `creature_plates.gd`; this package did not change it.
- **Hunt objective hint:** the "Hunt something for meat" hint does not mention the swords. It may want a few words
  once the owner approves copy.
- **Long-press:** PRD 10.2's "long-press starts combat immediately [memo]" is not built.
