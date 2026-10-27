# Task: random natural colours for wild dinosaurs, kept on taming - COLORS

Context: DEADFRONT, Godot 4.7.1 typed GDScript (project `game/`). Owner: "it would be cool if wild dinosaurs have somewhat
(within reason) random colorations and taming them keeps the color profile as well as stats". Individual stats already exist
and survive taming and saving: `game/scripts/creatures/creature_genetics.gd` (IVs, EVs, level gains; read its header and
where it is rolled, stored on PetRecord `game/scripts/pets/pet_record.gd`, and saved). Creature visuals:
`game/scripts/creatures/creature_view.gd` (GLB rigs via RiggedModel; placeholder boxes use `_tint`).

## Requirements
1. Colour profile per individual, stored in CreatureGenetics next to the IVs (so it follows the same tame and save path):
   a hue shift, a saturation scale and a value scale, rolled at spawn from per-species ranges in
   `game/data/creatures/<species>.json` key `"coloration": {"hue_deg": 14, "sat": 0.18, "val": 0.12}` (defaults when absent:
   hue +-12 deg, sat +-15 %, value +-10 %; ASSUMPTION, natural-looking, never neon). Optionally 2-4 named morphs per species
   (e.g. "dark", "pale") picked with weights; keep it data-driven.
2. Apply it to every mesh surface of the creature's rig with a shader that samples the original albedo and shifts it in
   HSV (keep the normal/roughness/other maps), one material per individual; the placeholder box path uses the same shift on
   `_tint`. Status FX tints (`set_status_fx`) must still work on top.
3. Taming: the tamed pet keeps the wild individual's colour profile and its genetics exactly (check today's capture/tame code
   path and fix it if anything is re-rolled); save/load keeps both; an old save without a colour profile gets a deterministic
   one derived from the pet's id (no change on every load).
4. Test `game/tests/t_colors.gd` (copy the pattern of game/tests/t_domain.gd: load() scripts on the first frame after the
   autoloads exist, a 60 s watchdog `get_tree().create_timer(60).timeout.connect(func(): quit(2))`): 20 wild spawns of one
   species give at least 5 distinct profiles, all inside the ranges; a tamed pet's profile and genetics equal the wild
   individual's; a save/load round trip keeps them; a pet record without a profile gets the same derived profile twice.
   Prints `[t_colors] PASS`.
5. Lab `game/scripts/dev/colors_lab.gd` (+ scene; wire like other labs through LabKit) that lines up 8 wild individuals of two
   species (velociraptor and one quadruped with a GLB, e.g. protoceratops) on flat ground in good light and saves
   `--shot=<png>`; print `[colors_lab] PASS n=<count>`.

## How to run Godot (exactly)
- Always through the slot limiter with an alarm, output to a file, never piped into tail/head/grep:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 240; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_colors.gd > /tmp/colors_t.log 2>&1`
  and give the bash tool timeout_ms = 300000; then read the log file.
- The lab needs a window (it renders): drop `--headless` and add `--resolution 1600x900 --rendering-method gl_compatibility`.
- After adding class_name files: `... --headless --path game --import > /tmp/import.log 2>&1` (alarm 900, timeout_ms 960000).
- Parse-check a script before running a long job: `... --headless --path game --check-only --script res://<path>`.

## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxi/maxf or explicit types.
- Await coroutines. A `--script` test must not name typed global classes before the autoloads exist (use load()).
- Baseline: t_save prints 5 deliberate SCRIPT ERRORs; that is normal.

## Milestones (write them into .dsc/PLAN.md and call milestone_done after each)
1. Profile in CreatureGenetics + data ranges + t_colors spawn cases pass.
2. Shader applied on GLB rigs and placeholders; colors_lab shot looks natural (look at it).
3. Tame + save/load + old-save cases pass.
4. Full verify passes; report `docs/orchestration/reports/dsc-colors.md` (ranges chosen, shot path, before/after of the tame path).

## Constraints
Keep game/override.cfg. Never touch other folders under .claude/worktrees/, the owner's save, or ~/Documents/deadfront.
Do not change creature meshes, rigs, clips or species stats. No new dependencies. Do not push, merge or deploy.
Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_colors.sh`.
