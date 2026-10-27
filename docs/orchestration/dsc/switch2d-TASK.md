# Task: SWITCH2D: resources draw as painted 2D cards (buildings stay 3D)

Owner, verbatim: "keep buildings 3D and make resources 2D but realistic and kind of look 3D", "for 2.5D, make the flat assets
align with the camera angle at all times", and today "start switching to the 2D assets".
DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`), web build (gl_compatibility), mobile-first.

## What is already in this tree (merged for you)
- The new camera (merged): a long-lens PERSPECTIVE camera, pitch -38.7, yaw 45, in game/scripts/camera/iso_camera.gd. It
  publishes global shader parameters in game/project.godot [shader_globals]: camera_focus, camera_pitch_deg, camera_yaw_deg,
  camera_distance, parallax_strength, tall_fade_height.
- CARD2D (merged): game/scripts/world/card_prop.gd (CardProp: setup(), _face_camera(), _feed_camera(), rustle()),
  game/shaders/card_sway.gdshader, game/data/card2d.json (24 cards BAKED from the 3D models, albedo + normal),
  game/scripts/world/island_scatter.gd:175 (picks a card when rules.json resource_render == "card"),
  game/scripts/world/harvest_node.gd:441 set_card_visual(card, empty_card), game/tests/t_card2d.gd, card2d_lab.
  Its project.godot [card2d] section was a stand-in until the camera globals existed.
- SPRITES2D (merged): the owner's PAINTED art cut into sprites: game/assets/nature/sprites2d/<sheet>/*.png and
  game/data/world/sprites2d.json (one row per sprite: id, sheet, file, px, pivot, name, kind, height_m, blocks,
  destroyable; kind is a nature family id such as PalmTree/Rock_Moss/Grass, or prop:*, icon:*, unused). More sprites
  arrive later (three more sheets are being cut): read the manifest at runtime, never hard-code ids.
## What to build
1. Painted cards: CardProp can draw a painted sprite from sprites2d.json (texture = the PNG, world size from height_m and
   the PNG aspect, pivot from the manifest's pivot = the ground point). Painted art carries its own shading: light it so it
   still darkens at night and under shade but does not get a second fake 3D shading (ASSUMPTION: unshaded albedo times the
   scene's light colour/energy, or lit with a camera-facing flat normal; pick one, show both in a shot, say why).
2. Mapping: a nature family with painted sprites (kind == family id) draws one of them, chosen deterministically per node
   (hash of the node's position), so variants mix; a family without painted art keeps its BAKED card; with
   resource_render "card" no resource draws as a 3D model. Buildings stay 3D. Write the mapping in
   game/data/world/sprites2d_map.json only if you need overrides (e.g. two families share a sprite).
3. Facing: every card faces the active Camera3D at all times (the new perspective camera); never hard-code 45/-35.264/-38.7
   or orthographic. Move CardProp from the [card2d] project settings to the camera's global shader parameters, then remove
   the [card2d] section from project.godot (keep [shader_globals] untouched).
4. Behaviour unchanged: tap/selection on a card opens the node's radial; the depleted (-empty) state shows; collision and
   step-over follow HarvestNode.blocks_movement (not the card); see-through for tall cards still works.
5. Switch the default: game/data/world/rules.json "resource_render": "card" (update its _note).
## Milestones
- M1 game/tests/t_switch2d.gd: the mapping (every family with painted sprites resolves to >= 1 sprite; the variant is
  stable for a node; a family without painted art falls back to its baked card; buildings are never cards); a painted
  CardProp has a texture, a world size from height_m and the manifest pivot. Stage 1.
- M2 Painted CardProp + mapping + camera globals + facing. Stage 1.
- M3 game/scripts/dev/switch2d_lab.gd + scene: on home_grassland and on tropical_25, with resource_render "card", print
  `[switch2d] RESULT painted_nodes= baked_nodes= model_nodes= grey_cards= ms_cards= ms_models= tap_ok= empty_ok=
  facing_err_deg=` where model_nodes = resource nodes still drawing a 3D mesh, grey_cards = cards whose on-screen rect has
  pixel standard deviation < 6 (flat grey or blank), ms_* = median frame ms of the same view with resource_render "card"
  vs "model", tap_ok = a simulated tap on a card selects its node, empty_ok = a depleted bush shows its empty card,
  facing_err_deg = the worst angle between a card's normal and the direction to the camera. Save shots (home and tropical,
  cards and models) into --shot-dir. Stage 2.
- M4 Look at every shot (write path + verdict in NOTES.md): painted cards must read as the owner's art, upright, sized
  sensibly next to the 1.8 m survivor, not floating or sunk. Fix and re-shoot. Stage 2.
- M5 Report and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/switch2d_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=switch2d_lab --shot-dir=/tmp/switch2d_shots > /tmp/switch2d_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/switch2d_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- A lab log with `SHADER ERROR` or `Unknown character` means the shader did not compile and every card draws grey: the
  gate fails on it. GDScript `##` comments are not shader syntax; shaders use `//`.
- Scratch files go in $TMPDIR/switch2d, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh switch2d [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_switch2d.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[switch2d] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-switch2d.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
