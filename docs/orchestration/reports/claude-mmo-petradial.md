# claude-mmo-petradial: the Durango pet radial (spec 23)

Owner, verbatim: "You can tap on an animal, that selects it, if you press red swords you initiate combat with it.
Pet radial menu to mount and ride, etc". Spec: `docs/design/durango-prompts/23_target_select_pet_radial.md`,
reference `docs/reference/durango-pet-radial.webp`. This package is the pet radial half; the target select and red
swords half is TARGETUI (`claude/mmo-targetui`).

Branch `claude/mmo-petradial`, fast-forwarded to `claude/mmo-overhaul` at ddaab662 before any commit (the tree had
been cut at e5f3ec8a; an earlier, killed run of this package had left uncommitted work in it, which I carried over,
reviewed and finished). Commits:

- `63c87be3` PetRadial, PetRenameDialog, the Ride and Rename icons (`icons_k.py`), t_petradial, pet_radial_lab,
  the hooks patch
- the commit that adds this report and the regenerated hooks patch

New files are committed. Changes to files other packages own ship as
`docs/orchestration/reports/claude-mmo-petradial-hooks.patch` (12 files, 111+/46-). `git apply --cached --check`
passes on `claude/mmo-overhaul` ddaab662 and on the branch head. The work tree has the patch applied, and every gate
below ran with it applied. The branch and the patch must land together: without the patch `build.py --check` reports
`ride.svg` / `rename.svg` as NOT FROM SOURCE (icons_k is listed in build.py by the patch) and nothing opens the radial.

Credits spent: none (no Meshy, no Tripo).

## What the owner gets

Tap your own pet (or press E next to it) and a dark ring opens around it, as in the reference:

- a see-through centre disc on the pet, with its name in large type ("REX"), the species under it ("Zebraceratops")
  and a yellow arc on the right side that is the pet's fullness;
- one segment per thing the pet can do, each a white icon in the band with its label in a dark tag outside the ring,
  clockwise from the top left as in the reference: **Animals, Bag, Feed, Ride, Dismiss, Rename**.

| Segment | What it does (the existing path it calls) |
|---|---|
| Animals | `HuntHud.open_animals(rec)`: the Animals screen, opened on that pet's row |
| Bag | `p.ui.show_pet_bag(rec)`: the current pet cargo screen (INVUI's shared bag grid is not on the base) |
| Feed | `PlayerPets.feed_best(c)`: one unit of the first food in your bag the pet eats |
| Ride | `p.mount(c)`; only for species with the `mount` role. On the pet you are riding it reads **Dismount** (`p.dismount()`) |
| Dismiss | `PlayerPets.dismiss(c)`: the same dismiss the Animals screen's DISMISS and the summon toggle use (HP kept) |
| Rename | a name dialog; OK goes through `PlayerActions.rename_pet`, which uses the character-name rule |

Absent features are left out, not greyed: a compsognathus (combat role) gets no Ride; Animals only shows when the HUD
that owns the Animals screen is there. A tap anywhere off the segments closes the ring and does nothing else (no walk,
no station). Esc / pad B closes it; arrows / d-pad pick a segment and Enter / pad A fires it. Tapping the same pet
again closes it.

Rename: the dialog starts from the current name, refuses with the server's own reason ("Name must be 3..20
characters", "Name may use letters, digits, space, _ and -") and stays open, and closes on a good name. The name then
shows in the ring's centre and on the Animals screen ("Rex II (Zebraceratops)"); before this package `PetRecord.name`
was shown nowhere. On a landscape phone the dialog sits at the top, clear of the on-screen keyboard.

## Defects the scout found, fixed here

- **The pet menu closed itself while the survivor walked** (`station_menu.gd` hides on `player.nav_active`). PetRadial
  has no such rule; it closes on a tap outside, Esc, the pet dying or being dismissed, or a bag/craft sheet opening.
  t_petradial: "walking does not close the ring".
- **Tapping your pet during a fight ended the fight** (`player_input.gd` stopped the hunt for any tap that was not a
  wild creature). Any creature tap now keeps the hunt. t_petradial: "tapping your pet mid-fight keeps the fight".
  TARGETUI makes the identical change on the same line (see Merge notes).
- **A click on a control could also tap a station underneath it** (the deferred desktop click fallback did not ask
  `tap_blocked()`). It now does, like the normal tap path.

## Hooks (files other packages own)

- `player_pets.gd`: `menu` is a PetRadial, `rename_dialog` a PetRenameDialog; `MENU` rows carry UiIcons ids;
  `entries()` builds Animals / Bag / Feed / Ride or Dismount / Dismiss / Rename; `_on_menu` dispatches them; the
  ORDERS sub-menu is gone (the whistle hexes SIC / HEEL / GUARD stay on the HUD and cover it).
- `player_actions.gd`: `rename_pet(rec, name)`; online it is an `act.pet_rename` intent `{pet_uid, name}`.
- `character_store.gd`: the char.create name rule moved into `static func name_problem(nm)` (same checks, same
  messages), so the pet rename and char.create cannot drift.
- `hunt_hud.gd`: `_open_animals()` becomes public `open_animals(rec = null)`; the survivor's nameplate is not drawn
  while the radial is open (the ring cut it in two and the centre is see-through).
- `hud_pills.gd`: world label pills keep out of the ring and its labels (a "Bush Berries" pill sat in the centre).
- `animal_screen.gd`: `open(p, rec = null)` selects that pet's row; rows and detail show "Name (Species)".
- `player_input.gd`: the hunt-stop line above, and `tap_blocked()` in the desktop click fallback.
- `ui_icons.json` (+ride, +rename), `build.py` (icons_k), `ui_real_capture_lab.gd` (calls `open_animals`),
  `t_player.gd` (the pet menu check expects Dismiss instead of Orders), `t_ui.gd` (OWNED scans pet_radial.gd and
  pet_rename_dialog.gd for emoji, small type and late consts).

## Merge notes

- **TARGETUI** (`claude-mmo-targetui-hooks.patch`): both patches apply on ddaab662 alone. Applied after TARGETUI's,
  this patch conflicts in one place only, `player_input.gd` `interact_tap_target`: both sides make the same hunt-stop
  change and TARGETUI adds `selection.select(col as Creature)` under it. Resolution: keep TARGETUI's lines (they
  contain this package's change). Checked with a scratch index (TARGETUI patch, then this one `--3way`); the
  `hunt_hud.gd` hunks of the two merge cleanly.
- WATER's `icons_j.py` was on the base by the time this branch synced, so the pet icons are a new `icons_k.py`.

## Assumptions (marked in code where they are code)

1. The centre disc is see-through and shows the pet itself rather than a rendered portrait. In the reference the
   world (a tree trunk) continues through the disc, and the game has no creature portrait renderer (the target plate
   uses a letter). When the ring has to slide to stay on screen the pet can sit off-centre in the disc.
2. `# ASSUMPTION:` the yellow arc is fullness (`hunger / hunger_max`, the meter Feed acts on); HP if a species had no
   hunger. No doc names the arc.
3. Bag shows for every pet: every PetRecord has a bag (`PetRecord.bag_slots_for`, an earlier ASSUMPTION of 10 slots),
   and hiding the segment for non-cargo species would strand what is already in those bags.
4. Ride becomes Dismount on the pet you ride (spec 02 lists Dismount as a command; the reference shot is not mounted).
5. Rename uses the character-name rule (3..20 letters, digits, space, _ or -). `PetRecord.NAME_MAX` (24) is unchanged.
6. Labels are English (Animals, Bag, Feed, Ride, Dismiss, Rename); the reference is the Portuguese client.
7. Not built: the reference's "[F2]" hint (no doc meaning), and an Orders segment (not in the reference).

## Gates (work tree with the hooks applied, Godot 4.7.1 mono, via gslot)

| Gate | Result |
|---|---|
| every `game/tests/t_*.gd` (22 files) | all exit 0 and PASS: t_ai, t_build, t_canim, t_combat, t_data, t_harbour (islands=15), t_iconart, t_items, t_light, t_lighting, t_occlude, t_petradial, t_player, t_save (its 5 deliberate SCRIPT ERRORs), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons (`ids=179 files=118`, `[icons] PASS drawn=118 svgs=118`), t_w2_skills, t_water, t_web; 0 SCRIPT ERROR elsewhere |
| `run_all.gd` | exit 0, `[tests] PASS` |
| `tools/smoke.sh` | SMOKE PASS |
| pet_radial_lab, 1600x900 Forward+, 1600x900 gl_compatibility, 844x390 gl_compatibility | each exit 0, `[petradial] PASS`, 0 SCRIPT ERROR |
| ui_real_capture_lab (touched), 844x390 and 1600x900 gl_compatibility | each exit 0, `[uireal] PASS`, 0 SCRIPT ERROR |

The table is the final run, on the work tree as committed plus the patch, after the last code edit.

t_petradial on the old code (`claude/mmo-overhaul` ddaab662 plus the new files, no hooks):

- Throwaway tree at `63c87be3` without the patch: exit 1, 0 SCRIPT ERROR, 5 FAIL: "tapping your own pet opens the
  pet radial (menu=PetMenu)", "no radial for the compsognathus", "PlayerActions has a rename_pet verb", "tapping
  your pet mid-fight keeps the fight (target <null>)", "walking does not close the ring (nav true)".
- The same tree after `git apply` of this patch: exit 0, `[t_petradial] PASS`, 0 SCRIPT ERROR.

## Shots (looked at, next to the references)

BEFORE (old hex menu, `before_*`) and AFTER (`after_*`) are in
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/petradial/`:
`pet_tap`, `rename`, `rename_refused`, `radial_renamed`, `radial_mounted`, `radial_compy`, `animals_screen` at
1600x900 Forward+ (`after_fwd1600`), 1600x900 gl_compatibility (`after_glc1600`) and 844x390 gl_compatibility
(`after_glc844`).

- BEFORE: four white hexes (ORDERS, RIDE, FEED, BAG) scattered round the pet with text glyphs; at 1600 FEED sits on
  the "Survivor" nameplate. No name, no meter.
- AFTER 1600: the ring reads like the reference: six dark segments split by thin seams, white icons, dark label tags
  outside, the zebraceratops visible in the centre with "REX / Zebraceratops" and the yellow arc on the right.
  Mounted, the Ride segment reads Dismount and the HUD's own DISMOUNT hex stays at bottom right. The compsognathus
  ring has five segments (no Ride).
- AFTER 844x390: the ring (64 px bands) sits under the vitals and quest card; its left labels cover the HANDS hex
  while it is open (a tap there closes the ring). "Compsognathus" steps down to the small size instead of being cut.
  The rename card sits at the top.

## Limits and follow-ups

- Online, `act.pet_rename` is only queued (`PlayerActions.sent`, like every other verb); the server has no pet verb
  handlers yet. Feed, Ride, Dismiss and Bag still run locally as before this package.
- Touch was exercised as emulated mouse taps in the lab and test, not on a device.
- The pet's world HP bar can peek out beside the ring (creature plates are a separate layer).
