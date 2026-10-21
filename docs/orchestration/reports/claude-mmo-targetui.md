# claude-mmo-targetui: tap selects, the red swords start the fight (spec 23)

Owner, verbatim: "You can tap on an animal, that selects it, if you press red swords you initiate combat with it."
Spec `docs/design/durango-prompts/23_target_select_pet_radial.md`, reference `docs/reference/durango-target-select.webp`.
The pet radial half of spec 23 is not in this package.

Branch `claude/mmo-targetui` from `claude/mmo-overhaul` at e5f3ec8a, with `claude/mmo-overhaul` ddaab662 merged in.
Commits:

- `157cf440` TargetSelect, TargetSwordsHex, t_targetui
- `a0a6e696` the swords hex redrawn closer to the reference, and targetui_lab
- `2ce32755` merge of `claude/mmo-overhaul` (WATER, specs 23-24)
- the commit that adds this report and the hooks patch

The call sites are in files that other packages own, so they are not committed on the branch. They ship as
`docs/orchestration/reports/claude-mmo-targetui-hooks.patch` (4 files, 28+/8-). `git apply --cached --check` passes on
`claude/mmo-overhaul` ddaab662. Every gate below ran in the work tree with the patch applied. The branch does nothing
until the patch lands (nothing creates the selection or the hex), and the patch does not compile without the branch's
two new classes, so they must land together.

Credits spent: none.

## What the owner gets

- **Tapping a wild animal only selects it.** These appear:
  - a pale ring at its feet;
  - the top-centre target plate: a dark band, the name, a red "Lv. n", the portrait square on the right, and a red
    HP bar with "hp / max";
  - its world name plate;
  - a dark hex with red crossed swords beside the animal. The hex follows the animal, and on desktop it has an "E"
    key cap, as in the reference.

  No combat HUD, red frame or swing appears until you press the swords.
- **The swords, E or F start the fight** on the selected animal through `PlayerActions.attack`. Online that is the
  `act.attack` intent and nothing is applied locally. Auto-attack, Chase/Hold, End Combat and the bottom-right
  cluster (NET, TACKLE, KICK, ROLL, AUTO) work as before. The swords hide while that animal is the fight and come back
  after End Combat. F with nothing selected still fights the nearest animal within 28 m.
- **An animal that bites is fought at once**, selected or not (`Player.receive_creature_hit` is unchanged). The
  survivor is never defenceless.
- **Deselecting:** tap empty ground, or tap another target (another animal, a tree or a station). The selection also
  drops when the animal dies, is tamed or freed, or is more than 40 m away.
- **The aggro ring stays visible.** The select ring is a separate pale torus, and both show together (aggro_select
  shot).
- **Pets are excluded.** Tapping your own pet never selects it and never shows the swords, and `select(pet)` is refused.
  The pet tap still opens its hex menu. A tap on your pet during a fight no longer ends the fight; on the old code it
  called `hunt.stop()`.
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
  - a creature tap selects instead of calling `actions.attack`;
  - a tap on any creature keeps the hunt;
  - `_walk_to_tile` deselects;
  - E engages the selection, after the dismount check;
  - F prefers the fight, then the selection, then the nearest animal.
- `hunt_hud.gd`
  - builds the swords hex;
  - the plate shows the hunt target, else the selection, else the last animal attacked;
  - the plate gets a dark name band;
  - the Animals head icon replaces the grey first-letter square.
- `creature_plates.gd`: the selection's world plate is forced visible and emphasised.
- `dev/hunt_lab.gd`: after its tap it calls `selection.engage()`, so its acceptance shot is still the combat HUD.

## Gates (all run on the final tree, with the patch applied)

- Every `game/tests/t_*.gd` (23 files) exits 0 and prints PASS. The only SCRIPT ERRORs are t_save's 5 deliberate
  ones.
- run_all: `[tests] PASS`. smoke: `SMOKE PASS`.
- **t_targetui on the old code** (hooks reverted, same tree, after the merge): exit 1, `FAIL count=12`. On the old
  code a tap hunts and swings (HP 1069 / 1070 after 1.2 s), selects nothing, shows no ring or swords, makes F hit
  the nearer animal, and ends the fight when you tap your pet. With the patch it passes.
- **targetui_lab:** `[targetui] PASS`, exit 0, 0 SCRIPT ERROR and 0 ERROR, in Forward+ 1600x900,
  gl_compatibility 1600x900 and gl_compatibility 844x390. It uses real mouse events on the home island.
- **hunt_lab** (touched by the patch):
  - headless: `[hunt_lab] PASS`, 0 SCRIPT ERROR. In headless the tap misses; the raptor bites and the survivor
    retaliates.
  - windowed gl_compatibility 1600x900: `[combat] select velociraptor`, then `hunt start`, 0 SCRIPT ERROR.

## Shots (looked at, each next to the reference)

`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/targetui/`

- `before/{fwd1600x900,glc1600x900,glc844x390}/`: wild_tap_0s and wild_tap_2_5s (the tap went straight to combat,
  with the red frame, End Combat and the path line), plus pet_tap and the other pet shots.
- `after4/{fwd1600x900,glc1600x900,glc844x390}/`:
  - select: plate, ring, and the swords with E beside the protoceratops;
  - engaged: the combat HUD after the swords;
  - aggro_select: the raptor's yellow aggro ring together with the select ring and the swords;
  - pet_tap: the pet menu, with no swords and no plate.
- `after4/hunt_lab_glc1600x900.png`

Compared with the reference:

- The plate layout, the red level, the red HP bar with numbers, and the dark hex with red crossed swords and an E cap
  beside the animal all match.
- The reference portrait is species art. We have none, so a white dino head stands in.

## Assumptions (marked `# ASSUMPTION:` in code)

- A selection drops past 40 m, the distance the HUD already uses for its last-target plate.
- The plate portrait is the generic Animals head until per-species portraits exist.

## For the next agent

- **Pet radial (spec 23, second shot):** not built.
  - `StationMenu` still hides the pet menu whenever `player.nav_active`.
  - `hunt.stop()` does not clear the chase route, so a pet tap right after End Combat can flash the menu shut.
  - Dismiss, Rename and an Animals-menu entry are missing.
- **Retargeting during a fight:** tapping another animal mid-fight selects it and shows its swords. The top plate
  stays on the current fight target until you press them.
- **World plate placement:** when the selected animal stands right under the survivor, the world plate is lifted
  well above it. That is the existing overlap rule in `creature_plates.gd`; this package did not change it.
- **Hunt objective hint:** the "Hunt something for meat" hint does not mention the swords. It may want a few words
  once the owner approves copy.
- **Long-press:** PRD 10.2's "long-press starts combat immediately [memo]" is not built.
