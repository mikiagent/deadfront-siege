# dsc — NATURETAG: the nature is a tag under the name

Owner (2026-10-28): "for animal's natures, put it as a tag under their name, not in the name itself."

## What shipped

The nature is out of every creature name and onto a chip directly under it. Behaviour, balance and
data are untouched.

| surface | before | after |
|---|---|---|
| World plate (`creature_plates.gd`) | "Lv. 25  Timid Velociraptor" | "Lv. 25  Velociraptor" + a `NatureChip` reading "Timid" between the name and the HP bar |
| Animals screen roster row | "Timid Velociraptor   Lv.1   B" | "Velociraptor   Lv.1   B" + chip under the row |
| Animals ACTIVE slot | "Timid Velociraptor" | "Velociraptor" + centred chip under it |
| Animals detail header | "Timid Velociraptor" as line 1 of the stat block | name label "Velociraptor" + chip "Timid" + the stat block |
| Pet radial centre disc | given name / species line only | unchanged name line + chip "Timid" under it, inside the disc |

Variant words STAY in the name: "Alpha Velociraptor", "Crested Velociraptor" (pack leader and
colour variant), as the task requires.

Code:
- `game/scripts/creatures/brains/brain_natures.gd` — `display_name(variant_label, species_text)` and
  `display_title(c)` no longer take or emit a nature (the old signature had it as the first
  argument, so a caller physically cannot put it back). New `tag(nature)` and `tag_for(node)` give
  the chip text from the same `label()` the table uses, so the word under the name and the name
  can never disagree.
- `game/scripts/ui/nature_chip.gd` — **new**, `class_name NatureChip`: a `Panel` + `Label`, 14 px
  tall, `UiTokens.trait_chip_style(&"positive")` with the content margins removed and 2 px corners,
  `UI CHIP_PX` (12 px) type, `PAD_X` 6. Hidden (and taking no space) when the nature is empty.
- `game/scripts/ui/creature_plates.gd` — chip at `CHIP_POS` (8, 16) inside the pill; the name line is
  16 px and the rows under it moved up 13 px (HP bar 29-43, XP 43-47, status 47-73, tame 73-93) so
  `FULL_H` stays **94** and the pill does not grow. The chip row is always reserved (the bar sits at
  y 29 for every creature) so nothing jumps between a nature and no nature. The chip re-measures only
  when the nature changes (`chip_nature`/`chip_ready` on the entry), not every frame.
- `game/scripts/ui/animal_screen.gd` — each roster row is a `VBox` of the name `Button` + a
  `NatureChip`; the ACTIVE slots carry a centred chip (the slot drops to 46 px so slot + 2 + chip 14
  = 62 stays inside the 64 px active band); the detail pane is `DetailName` + `NatureChip` + the
  stat `Label` (was one label with the name inside its text).
- `game/scripts/ui/pet_radial.gd` — `_chip` under the centre-disc name (and the species line when the
  pet has a given name), centred on the disc and hidden if it would not fit inside it
  (`below + h <= r_in` and width `<= 2*r_in - 8`); set only when the pet's nature changes.
- Fixed in passing: `creature_plates._separate_visible_creature_plates` assigned an untyped `Array`
  to `Array[Rect2]` when there was no HUD (`hud_rects`) — a live SCRIPT ERROR the new test hit. The
  else branch is now `([] as Array[Rect2])`.

## Chip style decision (ASSUMPTION)

`UiTokens.trait_chip_style` already expresses three polarities and a nature is neither good nor bad,
so no 4th style was added (the task allows one only if the three cannot express neutral). The chip
uses `&"positive"` — gold on the dark plate, the neutral-looking of the three; `&"negative"` is grey
and carries the "−" prefix (reads as a penalty) and `&"rare"` is green ("rare special"). No prefix
glyph is drawn: there is no polarity for a colour-blind player to be told about. The three existing
styles and `trait_chip_prefix`/`trait_chip_fg` are untouched.

## Before / after numbers (`game/tests/t_natures.gd`, measured on the live nodes)

| check | before | after |
|---|---|---|
| plate name label | "Lv. 25  Timid Velociraptor  [B]" | "Lv. 25  Velociraptor  [B]" |
| plate chip | — (no node) | "Timid" at (8, 16), 49x14 px, above the bar at y 29, inside the 94 px plate |
| plate variant name | "Lv. 25  Brave Crested Velociraptor" | "Lv. 25  Crested Velociraptor", chip "Brave"; "Alpha" still in the name when the brain names it leader |
| nature-less plate | — | no chip, plate still 94 px (nothing jumps) |
| Animals row | "Timid Velociraptor   Lv.1   B" | "Velociraptor   Lv.1   B", chip "Timid" under it |
| Animals detail | first line "Timid Velociraptor" | name "Velociraptor", chip "Timid", stats below |
| pet radial | name/species only | chip "Timid" at centre + (0, 57), inside the 88 px disc |

## Shots

None: the owner reserved the machine for headless work (`HEADLESS_ONLY`), so no windowed lab or
screenshot ran. Everything above is measured from the live `Control`/`Label` nodes in `t_natures`
(position, size, visibility, text) rather than from constants; the visual pass (chip colour against
the plate, the Animals row rhythm, the radial disc) still needs a windowed run — see "what the
integrator needs".

## Checks run

- `game/tests/t_natures.gd` — PASS, 14 sections (table, roll, names, **nature tag**, old-save
  fixture, timid, brave, aggressive, stubborn, loyal, taming, pen, docile damage, pet keeps nature).
- Related, all PASS with 0 SCRIPT ERROR: `t_ui`, `t_targetui`, `t_petradial`, `t_tame`,
  `t_invscreens`, `t_w2_skills`, `t_gather`.
- `tools/smoke.sh --no-import` — SMOKE PASS.
- `verify_job.sh naturetag 1` — VERIFY STAGE 1 PASS after every milestone.

## Assumptions (also `# ASSUMPTION` in code)

- The chip style is the gold/positive trait chip, no 4th style, no prefix glyph (see above).
- The chip sits between the name and the HP bar, not below the whole plate: "under the name" taken
  literally, and it keeps the plate's rows (and its 94 px budget) where they were.
- The nature tag is drawn on the compact phone plate only when the plate shows rows; a bar-only
  plate has no room for it.
- The pet radial's chip is dropped rather than drawn over the ring when it would not fit the disc
  (a 52 px phone disc).
- Item stacks that carry a nature (`captured_animal`) still show the plain item name; no UI in this
  job's scope shows a captured animal's nature, so nothing was invented for it.
- Pet names are untouched: `PetRecord.name` is the player's own name, and it never carried a nature.

## What the integrator needs

- **Visual pass** (windowed, `--resolution 1600x900` and `844x390`): plate chip colour/legibility on
  the dark pill, the Animals row + chip spacing against the 56 px row, the ACTIVE slot at 46+14, and
  the radial chip inside the disc. Watch `ui_real_capture_lab.gd` and `pet_radial_lab.gd`, which
  assert plate/pill geometry (the pill height deliberately did **not** change).
- **API change to note**: `CreatureNatures.display_name()` lost its `nature` first parameter (two
  arguments now). Nothing outside `ui/` called it; `display_title()` is unchanged for callers.
- The earlier `dsc-natures` report still describes the name prefix — this report supersedes the
  "Name" paragraph; `docs/current/creatures-capture-taming.md` and `docs/current/hud.md` and spec
  §11 are updated.
- Unrelated, still open from `dsc-natures`: `core/data.gd` logs `[data] FAIL … natures.json` on every
  boot (one-line skip beside `anim_events.json`/`ai.json`); the server `_tame` mints pets without the
  wild nature.
