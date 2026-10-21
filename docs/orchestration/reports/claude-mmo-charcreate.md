# claude-mmo-charcreate: Durango's character creation (spec 19)

Owner, verbatim: "This is what the player creation page looks like", then "You can choose the size and profile
pic, 3D model", then "height, hairstyles, skin color, facial hair/features", "outfit color" and "enter name".
Spec: `docs/design/durango-prompts/19_character_creation.md`. References: `docs/reference/durango-character-creation.png`
and `docs/reference/durango-create-character.png`. PRD §5.1 (`durango-wild-lands-systems-prd.md:326-340`).

Branch `claude/mmo-charcreate`, fast-forwarded to `claude/mmo-overhaul` at ddaab662 before any commit. Commits:

- `06b052b8` the three creation steps, CharacterLook, PortraitService, the look shader and masks, the Blender
  mask bake, appearance.json, the survivor.json text fix, t_charcreate, charcreate_lab
- `c367e7fa` lips follow the skin tone, the portrait frames the whole head, skin swatches at skin-like albedos
- `87efa2d5` larger gender sign, tighter note lines, lip swatches near real albedos, the lab's world shot from the
  sun's side
- the report commit (this file and the hooks patch)

Credits spent: 0 (no Tripo, Meshy or image generation; the masks come from a local headless Blender script).

## Owner questions

1. **A female survivor.** The only v2 survivor is a man (short dark hair, stubble, charcoal tee and shorts). There
   is no female base at v2 standard, and none is faked here: no scaling or recolouring of the man. The gender hex
   works and saves "m"/"f", and with "f" the screen shows the current model plus a line saying no female model
   exists yet. A female survivor needs a concept sheet for your approval before any Tripo mesh is made. Do you
   want that sheet made?
2. **Painted portraits.** Durango's portrait grid is a set of painted faces. That is new art, and none was generated
   or downloaded. The portrait here is a headshot rendered from the player's own model over a pattern and
   background colour. Where should a painted set come from, if you want one?

## What shipped

**Step 1, Gender/Profession** (`cc_profession_step.gd`). Black torn header band "Gender/Profession"; occupation
list on the left with dotted separators, the selected row lighter with yellow corner brackets (the list scrolls on
a phone); the gold occupation title; the live 3D survivor; at the bottom left the gold skill line and the story;
a bottom bar with the gold gender hex and its label ("Male"/"Female") and a yellow Next.

- The skill line is `LevelDisplay.label(SkillState.OCCUPATION_LEVEL)` plus `SkillState.NAMES[tree]`, with the
  tree read from `occupations.json`. Nothing is hard-coded: t_charcreate builds the expected line for every
  occupation from a fresh `SkillState.apply_occupation(id)`.
- Display names: `occupations.json` already uses the PRD table's words (Soldier, Job Seeker, Office Worker,
  Technician, Flight Attendant, Student, Homemaker, Farmer), so no id mapping was needed. Durango's own words
  ("Engineer", "Attendant") are not used; the PRD binds. No occupation starts in Survival, Processing, Butchering
  or Ranged (checked).
- Occupation outfits: the base has none. Its three armour kits (forager, hide_and_bone, travel_clothes) are game
  items, not occupation clothes, so step 1 does not dress the preview per occupation. Linking a kit to an
  occupation would invent lore.

**The live preview** (`survivor_stage.gd`). The real `survivor.glb` with its clips, built like the player's rig
(same height and facing, web-safe materials), playing `idle` in its own-world SubViewport. Dark stage: a shadowed
key light from the front left, a fill, a warm rim, a floor that takes the shadow, and depth fog in the backdrop
colour so the far floor has no horizon line. Drag (mouse or touch) turns the survivor. The same stage moves between
the three steps.

**Step 2, Create Character** (`cc_create_step.gd`). Header "Create Character" with a back arrow. Left: the current
portrait in yellow brackets (the Portrait tab), then the Appearance and Color tabs, and the randomise die at the
bottom. Next to it, the tab's hex column. Centre: the same live preview. Right: the round clothing toggles (the
preview tries a kit on: preview only, nothing is given or saved), the tab's options, and a yellow Next.

- Portrait tab: Pattern (plain, checker, stripes, dots) and Background Color (12 muted colours).
- Appearance tab: Height, a vertical slider between a tall and a small figure, 92 % to 108 % in 1 % steps
  (`appearance.json`). It is visual scale only, in the preview and in the world. The capsule, collision, reach,
  speed and every gameplay number are unchanged; the panel says so. Part slots appear here only when they have two
  or more options (none do yet, see below).
- Color tab: Skin Color, Outfit Color 1, 2, 3, Eye Color and Lip Color down the hex column (the selected one with a
  gold hex outline), a grid of hex swatches on the right (the chosen one with a gold border and a check), and an
  "Original" swatch that puts the painted colour back. The outfit grid has rows of greys, browns, oranges, reds,
  pinks and purples, muted per STYLE.md.
- The die rolls every choice from the data's own range and palettes and keeps the gender.

**Step 3, Name** (`cc_name_step.gd`). "Name" header with a back arrow; the dressed, coloured survivor on the left
half; on the right "Enter the character's name.", a wide field, the help line "Can use up to 20 characters,
including spaces and special characters such as - and ." with a ? mark, an inline error, and a yellow OK.

- `CcNameStep.name_error()` is the one check: 1-20 characters after trimming; letters of any script, digits,
  spaces, "-" and "."; no space at either end and none doubled. OK stays disabled until it returns "". Online
  uniqueness is the server's job; it joins this function.
- On a phone with an on-screen keyboard the column lifts until the field clears the keyboard
  (`DisplayServer.virtual_keyboard_get_height`). Not checked on a device; there is no virtual keyboard in the
  desktop shots.
- OK emits `done(occupation, gender, name)` exactly as before; World saves occupation and name as before.

**The look** (`character_look.gd`, `appearance.json`). One Dictionary: gender, height, colours, parts and portrait
settings. `CharacterLook.clean()` is the trust boundary: every field is coerced to a value the data offers, and a
save without "look" gets the default look. `CharacterLook.apply(rig, look)` puts it on any survivor rig: the
creation preview, the portrait studio and the player in the world. Armour attached later takes it too (the
PlayerEquipment hook calls `CharacterLook.refresh`).

**Colour masks** (`tools/blender/survivor_look_masks.py`, committed, headless Blender, no network). Masks are baked
from the UV triangles of each body region, never from colour keys: each texel takes its region from its own
bind-pose position. Inside a region a colour test separates only skin from not-skin.

- Base atlas, RGBA at 2048: R T-shirt (Outfit Color 1), G shorts (Outfit Color 2), B skin, A hair and brows
  (baked, not exposed as a slot). Checks in the bake: 0 skin texels in the shirt, shorts or hair channels.
- Face mask on the same atlas: R iris (978 texels), G lips (3,979 texels), tightened from the eye and lip boxes by
  a colour test.
- One RGBA mask per kit atlas (forager, hide_and_bone, travel_clothes): R chest piece (Outfit 1), G legs piece
  (Outfit 2), B arms and helmet pieces (Outfit 3, "sleeves and trim"), A the skin the kit kept from its Tripo body
  (hands, a forearm, the face under a helmet), so the chosen skin tone carries into the kit.
- Every mask is dilated 8 texels into empty atlas space. The PNGs import lossless at 1024.
- The shader (`survivor_look.gdshader`) tints each channel by colour x (texel luminance / region mean luminance),
  so the painted folds stay. With no colour chosen the rig keeps its plain material.
- Outfit regions on this mesh: **Outfit 1 = T-shirt (base) and chest pieces; Outfit 2 = shorts (base) and leg pieces
  (travel_clothes' leg piece includes the vest's lower band, the belt and the boots); Outfit 3 = the kits' arms and
  helmet pieces.** The base is barefoot and has no third garment, so Outfit Color 3 drives kit sleeves and trim
  only (`# ASSUMPTION`); picking that slot puts the first kit on the preview so its swatches never look inert.
- Eye colour: the iris is about 12 texels wide, a few pixels in play. It shows in the portrait and close up; in the
  world it is effectively portrait-only.
- Lips without a chosen colour follow the skin tone (they sit outside the skin mask, and a new skin left them pale on
  a dark face). This is shown only; the saved look keeps no lip colour.

**Hairstyle, facial hair, facial features** (data-driven). `appearance.json` lists the options per slot (id, name,
scene, attach bone, genders). The model's own baked hair, stubble and face are option 1 of their slots, with no
scene to attach. A slot with fewer than two options shows no picker, so today none shows. An option with a scene
attaches through `RiggedModel.attach_skinned` (the path PlayerEquipment uses for armour slots), or rides its
attach bone when it has no skin. CHAR-APPEARANCE's options drop into the JSON.

**Portrait** (`portrait_service.gd`, `PortraitService`). One shared service: `request(look)` renders a 256 px headshot
of a survivor rig wearing the look, in its own studio SubViewport, over the look's pattern and background colour;
it caches by look (height excluded: it does not change the head), coalesces bursts (a slider drag) into one render,
and emits `changed`. `PortraitService.of_player()` is the player's picture for any screen. Headless it draws the
backdrop only (`captured` says so).

**Save.** `look` is an optional field; an old save loads unchanged and gets the default look (t_charcreate loads the
v3 golden). The look's gender replaces the old screen's unsaved gender, which defaulted to "f"; a new survivor now
defaults to "m" because the model is a man (`# ASSUMPTION` in character_look.gd).

**survivor.json** now describes the v2 survivor as a man in a charcoal tee and shorts, and says the woman was v1.

## Assumptions

- Height 0.92-1.08, step 0.01, default 1.0 (visual scale only).
- Every palette colour: skin (12 skin-like albedos), outfit (6 rows x 6), eyes (12), lips (12 near the painted lip
  colour), portrait backgrounds (12); muted per STYLE.md. The first skin and lip drafts drew chalk-white skin and
  white lips under the stage light.
- Portrait patterns plain, checker, stripes, dots.
- Outfit Color 3 drives kit sleeves and trim only.
- Preview outfits are the three existing kits, preview only.
- A new survivor's gender defaults to "m".
- The bag/market torn-band chrome (specs 13/14) lives in other branches; `CcUi` draws the same look locally until
  they merge.

## Hooks patch

`docs/orchestration/reports/claude-mmo-charcreate-hooks.patch`, 5 files. `git apply --cached --check` passes on the
branch head (and on ddaab662: none of the five files changed between them). The work tree has it applied and every
gate below ran with it.

- `world.gd`: `var look: Dictionary`; the creation `done` handler keeps `CharacterLook.clean(cc.look)` and applies it
  to the player's rig.
- `save_game.gd`: saves `"look"`; loading cleans it and applies it after the worn pieces attach.
- `save_sanitizer.gd`: `"look": {}` in SHAPE (a non-Dictionary look is dropped, then defaulted).
- `player_equipment.gd`: `equip()` calls `CharacterLook.refresh(rig)` after attaching a piece, so armour takes the
  chosen colours and skin. APPEAR's branch also edits this file (hair region); expect a small textual merge.
- `ui_real_capture_lab.gd` (W1-UI's lab): the old card/EnterRift checks are replaced by checks on the three steps
  (primary controls present and full size, nothing outside the view or overlapping outside the scrolling lists)
  and a capture of each step.

## Notes for the integrator

- **PortraitService is the canonical portrait.** DOMAIN has its own snapshot (`PlayerPortrait.texture_for`, for the
  domain banner). At its sync, the own-claim case should call `PortraitService.of_player()` and listen to
  `PortraitService.shared().changed`; other owners keep DOMAIN's silhouette until the server sends looks. INVUI's
  character view, the HUD and the map should call the same. The base has no HUD portrait slot or Character screen,
  so nothing here draws the portrait outside creation yet.
- The portrait studio keeps one survivor rig alive (update disabled) after creation, so a later look change can
  re-render without a reload.
- `CcUi` duplicates the torn band and yellow button look; fold it into the bag/market chrome when those merge.

## Gates

All in this work tree at `87efa2d5` with the hooks patch applied (the patch equals the tree's diff of the five
files, checked with `cmp`), after one `--import` (exit 0, 0 errors) for the new class_name files. Logs:
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cc3/gates/r2/`.

| Gate | Result |
|---|---|
| every `game/tests/t_*.gd` (23 files) | all exit 0 and PASS: t_ai, t_build, t_canim, t_charcreate, t_combat, t_data (`items=223 recipes=155`), t_harbour (`islands=15`), t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (its 5 deliberate SCRIPT ERRORs, each announced), t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons (`ids=177 files=116`, `[icons] PASS drawn=116 svgs=116`), t_w2_skills, t_water, t_web; 0 SCRIPT ERROR elsewhere |
| `run_all.gd` | exit 0, `[tests] PASS`. Its two `ERROR` lines ("Save schema 4 is newer", "1 resources still in use at exit") print on the base too (run_all in a throwaway tree at ddaab662: the same two) |
| `tools/smoke.sh --no-import` | `[smoke] ok player_pos=(0.0, 1.0, 0.0) phase=day`, `SMOKE PASS`, 0 SCRIPT ERROR (a fresh run dir, so the boot builds the creation screen) |
| `ui_real_capture_lab` (hooked) windowed gl_compatibility | 1600x900 and 844x390: `[uireal] PASS screens=...,bag,charcreate,resize_other,resize_back`, 0 SCRIPT ERROR, 0 FAIL lines; it checks and captures all three steps |
| `charcreate_lab` | every windowed shot below: exit 0, 0 SCRIPT ERROR, 0 ERROR |
| crash reports | no new Godot `.ips` since this run started (the last is 23:26, the earlier builder's) |

t_charcreate against the old code: a throwaway tree at ddaab662 (no package, no hooks) with only `t_charcreate.gd`
copied in exits 1:

- `[t_charcreate] FAIL creation shows a live 3D survivor (own-world SubViewport with a skinned skeleton)`
- `[t_charcreate] FAIL the preview plays the idle clip (got none)`
- `[t_charcreate] FAIL the stage has a shadow-casting key light (ground shadow)`
- `[t_charcreate] FAIL creation has a Gender/Profession step with a skill line (old code: none)`
- plus the missing `character_look.gd` and `portrait_service.gd` loads

What t_charcreate checks on the new code: the live preview (own-world SubViewport, skinned skeleton, idle playing,
shadowed key light); for all 8 occupations the skill line equals `Lv. <level_of(tree)> <NAMES[tree]>` from a fresh
`SkillState.apply_occupation`, the title and story come from the data, and the names are the PRD's; no Survival,
Processing, Butchering or Ranged start; type floor 12 px and no emoji in the new UI files; 8 valid and 10 refused
names; 200 die rolls stay inside the height range and palettes and survive `clean()`; forged looks are coerced; every
colour slot has a mask region; mask bake checks; no part slot has a picker yet; skin and outfit 1 tint their channels,
an unchosen slot stays painted, unchosen lips follow the skin, a chosen lip colour wins; height scales the rig and not
the capsule; a kit equipped later takes the colours and skin (the PlayerEquipment hook); the default look restores
the plain material; the portrait renders, caches, ignores height, re-renders on a colour, pattern or background
change, and uses the chosen backdrop; at 844x390 and 1600x900 every control of all three steps sits inside the view,
primary targets are 56 px+ and the rest 44 px+; the flow through World.start_new (gender toggle and its note, Next,
height slider, Outfit Color 3 putting a kit on, colour change re-rendering the portrait, Name validation and OK) emits
`done("farmer", "f", "Ana-Lu Quispe.")`, World keeps occupation, name and look, the world model takes the height, the
save holds them and loading restores them; the v3 golden save (no "look") loads with the default look and its name
and occupation.

An earlier full run (`.../cc3/gates/r1/`) started at `c367e7fa` + hooks and also passed, but files changed while it
ran (the `87efa2d5` polish), so r2 above, on the committed head, is the run that counts.

## Shots

Windowed captures, every one opened and compared with the two references. Before: the real first launch at ddaab662
(fresh run dir). After: the same first launch on this branch, plus `charcreate_lab` for chosen occupations and steps.

Matched first-launch pairs (`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cc3/before/` and `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cc3/final/`):

| Size, renderer | Before | After |
|---|---|---|
| 1600x900 Forward+ | `before_1600_fwd.png` | `after_main_1600_fwd.png` |
| 1600x900 gl_compatibility | `before_1600_glc.png` | `after_main_1600_glc.png` |
| 844x390 gl_compatibility | `before_844_glc.png` | `after_main_844_glc.png` |

Before: "CREATE YOUR SURVIVOR" over a grid of eight cards, Woman/Man buttons, a name field and ENTER THE RIFT, with
the HUD showing through. After: the reference's layout; Soldier is selected on open (Durango opens with a row
selected).

More after shots in `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cc3/final/`:

- Step 1: `after_1600_fwd_step0_soldier.png`, `after_1600_glc_step0_farmer.png`, `after_844_glc_step0_technician.png`,
  `after_844_glc_step0_gender_f.png` (Female, with the "no female model yet" note).
- Step 2: `after_1600_fwd_step1_portrait.png` (Portrait tab), `after_1600_glc_step1_color_outfit1.png` (Color tab),
  `after_1600_fwd_step1_color_outfit3.png` (Outfit Color 3 with travel_clothes on), `after_844_glc_step1_height.png`
  (108 %), `after_844_glc_step1_color_skin.png`, `after_1600_fwd_step1_seed.png` (a die roll, dotted portrait).
- Step 3: `after_1600_fwd_step2_name.png`, `after_1600_glc_step2_name_error.png` (double space: inline error, OK
  disabled), `after_844_glc_step2_name.png`.
- World: `after_1600_fwd_world_base.png` (the look on the player at 92 %), `after_1600_glc_world_travel.png`
  (travel_clothes taking all three outfit colours and the skin tone at 108 %), each with the rendered portrait in a
  corner.

The first-launch trio, the four step 1 shots, the height, seed and world shots were taken on `87efa2d5`. The other
step 2 and step 3 shots were taken on `c367e7fa`; `87efa2d5` changes nothing they show (the gender sign, two wrapped
notes they do not contain, the lip palette with no lip colour chosen in them, the lab's world camera).

What I saw against the references, and fixed: the lips stayed painted on a dark skin (pale band, fixed: they follow
the skin); the portrait cut the top of the head (fixed: reframed); the palest skin swatch and the light lip swatches
drew chalk-white (fixed: palettes near real albedos); the gender sign was small in its hex (fixed); wrapped notes had
loose lines (fixed); the lab's world camera was backlit (fixed). Checked and left: the hair reads greyer next to a
dark skin, but its pixels are unchanged (sampled #4c433f plain vs #4a413d with a dark skin); on travel_clothes the
vest's lower band and the boots belong to the leg piece, so they take Outfit Color 2.

Differences from the references that stay: no occupation outfits (none exist); the height slider sits in the
Appearance tab instead of always beside the clothing toggles (the owner listed height with the appearance options);
the portrait grid is our rendered headshot with pattern and background, not painted faces.

## Not done, and what the next agent needs

- A female v2 base (owner question 1), and occupation outfits (CHAR-APPEARANCE P8).
- Hair, facial hair and feature options: the slots and attach path are ready; CHAR-APPEARANCE supplies the scenes.
- A painted portrait set (owner question 2).
- The on-screen keyboard lift is untested on a device.
- Online: other players' looks need the server to send them; the name check's uniqueness lives server-side.
