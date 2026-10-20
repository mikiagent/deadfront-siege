# W1-LIGHT report (claude, branch claude/mmo-w1-light)

## What shipped

1. **Behaviour-preserving split** (commit d54d252, alone). `island_runtime.gd` went from 1,527 to 363 lines. It keeps build orchestration and its public API. The rest moved to `island_terrain.gd` (435), `island_scatter.gd` (388), `island_spawns.gd` (100), `island_claims.gd` (90), `world_lighting.gd` and `world_weather.gd`. The island_lab counts were the same before and after.
2. **One shared lighting builder** (`WorldLighting.install(host, climate)`), used by both IslandRuntime and LabKit:
   - AgX tonemap, exposure set per renderer in the profile.
   - Sun 2.2 against sky-sourced ambient 0.3. This replaces the flat 0.75 grey fill, and LabKit's second 1.2 sun is gone.
   - PSSM 4-split shadows with splits fitted to the iso camera's depth band, normal bias 1.0 (see review round 2). The sun yaw sweeps from -35 to -85 deg, which keeps it 80-130 deg off the iso camera's 45 deg axis.
   - A cool moon light at night. Fog and sky colours follow time of day.
   - Warm dawn and dusk keyed to the Game.phase_name() thresholds (0.22 / 0.30 / 0.72 / 0.80).
   - Glow on. The key light never drops below 6 deg of elevation.
   - The first WorldEnvironment in the tree is reused, because it is the one Godot renders. Other directional lights are hidden, and a lab's driver yields to the island's.
3. **Per-climate profiles** in `game/data/world/lighting.json`. `default` fills every key, and every climate in climates.json has its own row.
4. **Rain**: a 2-triangle QuadMesh streak replaces the 4,224-triangle sphere. Its material has `vertex_color_use_as_albedo` and alpha, and `cast_shadow` is OFF.
5. **Dirt discs**: the texture adds detail around the tint instead of multiplying it, so the near-black stains are gone, and the pad stays within about 20 % of the grass luminance (round 2). The normal is forced to face up, so the back face no longer renders black.
6. **lighting_lab** (`game/scripts/dev/lighting_lab.gd` + `game/scenes/dev/lighting_lab.tscn`) is a windowed pixel verifier. `--light-shots=<dir>` saves the frames.
7. **Tests**: `game/tests/t_lighting.gd`, plus `game/tests/t_light.gd`, an alias that extends it, because the wave-1 runner looks for that name.

## Commits

- d54d252 Split island_runtime.gd into terrain, scatter, spawns, claims, lighting and weather (alone; island_lab counts unchanged)
- 559c437 WIP light (interrupted by usage limit): the lighting change itself
- 3f229fa Drop .uid churn for files this package does not own
- d9f28f0 First report
- 7bf6003 Review round 2 fixes (below)
- (this report)

## Review round 2: what each finding got

| # | Finding | Result |
|---|---|---|
| 1 | Shadows invisible at the 1024 mobile atlas | Fixed. `fit_shadows()` places the PSSM splits in metres around the iso camera's depth band (Godot spreads them over the camera's 4000 m far for orthographic cameras); normal bias back to 1.0. lighting_lab now also measures with `directional_shadow_atlas_set_size(1024)`: box 0.426 (was 0.921). |
| 2 | Character-scale casters cast nothing | Fixed by the same change. The lab now measures a 0.3 m pole and the survivor (shadow-only) at both atlases, limit 0.80: pole 0.433 / 0.449, survivor 0.544 / 0.546. The survivor stands where the game puts him, among the camp's own shadows, so his patch is compared with the same patch once he stops casting. See also "Survivor floats 0.9 m" below. |
| 3 | Dirt pads pale cream | Fixed: `tint * (0.11 + 0.22 * detail)`. Lab checks the median pad luminance against grass just outside it, band 0.8-1.2: Forward+ 1.18, compat 0.83. |
| 4 | Uncommitted WIP with `[dbg]` prints | Finished, `[dbg]` removed, committed in 7bf6003. The WIP's saturation 1.1 -> 1.25 is kept (ground_lum still 0.347). |
| 5 | GL texture leak per install on the web renderer | Fixed: an Environment this builder made is reused with its Sky on the next install. compat lab (LabKit install + island install): 0 `leaked` lines (was 2). t_light checks the second install keeps the same Environment and Sky. |
| 6 | Sky rewritten every frame; moon and sun both shadowed | Fixed: `drive()` skips steps under 1/1440 of a day; `moon.shadow_enabled = not sun.visible`. t_light checks no tod has both shadowed. |
| 7 | Warmth leaks into the day phase | Fixed: warm only from DAY-0.04 to DAY and DUSK to DUSK+0.02. t_light now checks DAY, DAY+0.02, 0.5, DUSK-0.02 and DUSK are neutral (the old formula fails at DAY+0.02). |
| 8 | Report gaps | This section; lv-sky-17 listed as not done; integrator hooks listed. |
| 9 | Lab does not fail closed; bad JSON gives a black screen | Fixed: 120 s watchdog quits 1; missing WorldLighting quits 1; `profile_for` falls back to a built-in `FALLBACK` profile once and stops re-parsing. |
| 10 | LabKit returns a dangling `lighting` handle | Dropped the key (no caller used it). |
| 11 | Compat nights near-black | Fixed: moon 0.8 -> 1.1, night ambient 0.3 -> 0.4, night sky a touch lighter, and `moon_energy_compat` 2.0 for gl_compatibility only (raising compat night ambient alone changed nothing: 0.033 -> 0.033). Lab now checks terrain 8-10 m from the fire at midnight: Forward+ 0.102, compat 0.068 (was 0.033), limit 0.05. |

### Survivor floats 0.9 m (not this package; evidence for the player owner)

`player.tscn` centres its 1.8 m capsule on the CharacterBody3D origin, but the survivor rig's feet are at that origin (bones span 4-172 cm above it). The survivor rests 0.9 m above the ground: smoke prints `player_pos=(0.0, 0.900182, 0.0)` on flat ground at y 0, and in island_lab the green ground ring sits below his feet. His shadow lands 0.7 m (noon) to several metres (dusk) downwind of where his feet appear and often merges into the tent's shadow, which is why it reads as missing in the dusk shots. Shadows themselves render (probe crops `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/iso/crop_e_camp_grounded.png` grounded, `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/iso/crop_b_island.png` floating). I also found his skinned AABB is 2 cm (cm-scale armature, metre mesh AABB). A fix in WorldLighting made no measurable difference to his shadow (lab survivor ratio 0.544 with and without), so I removed it; it still affects camera culling and belongs in rigged_model.gd.

## Acceptance checklist (each run in this session; output lines copied)

| Item | Output |
|---|---|
| Forward+ lighting_lab (committed 7bf6003) | `[lighting] shadow_ratio=0.426`, `[lighting] thin desk atlas=4096 pole=0.433 survivor=0.544`, `[lighting] mobile atlas=1024 box=0.426 pole=0.449 survivor=0.546`, `[lighting] blown_pct=0.000`, `[lighting] ground_lum=0.347`, `[lighting] disc_lum=0.393 grass_lum=0.333 disc_ratio=1.18`, `[lighting] night_lum=0.102`, `[lighting] PASS` |
| gl_compatibility lighting_lab | `[lighting] shadow_ratio=0.347`, `[lighting] thin desk atlas=4096 pole=0.346 survivor=0.445`, `[lighting] mobile atlas=1024 box=0.346 pole=0.346 survivor=0.409`, `[lighting] blown_pct=0.000`, `[lighting] ground_lum=0.361`, `[lighting] disc_lum=0.289 grass_lum=0.347 disc_ratio=0.83`, `[lighting] night_lum=0.068`, `[lighting] PASS`; 0 `leaked` lines |
| mobile renderer lighting_lab | `[lighting] shadow_ratio=0.427`, `[lighting] mobile atlas=1024 box=0.426 pole=0.428 survivor=0.537`, `[lighting] disc_lum=0.392 grass_lum=0.333 disc_ratio=1.18`, `[lighting] night_lum=0.102`, `[lighting] PASS` |
| Only world_lighting.gd builds lights | grep lists `world_lighting.gd:121 WorldEnvironment.new()`, `:133 Environment.new()`, `:161 DirectionalLight3D.new()` |
| Sizes | island_runtime 363; world_lighting 218; others unchanged from round 1 (all <= 450) |
| Behaviour preserved | `[world] island temperate_25 nodes=378 creatures=24 spawn_rejected=0` |
| Smoke | `SMOKE PASS` (tools/smoke.sh --no-import through gslot) |
| Suite | `[tests] PASS` (run_all.gd) |
| t_light (night, moon, warm dawn/dusk, neutral day incl. DAY+0.02 and DUSK-0.02, one shadowed light, split fit, never from below, profiles, rain, Environment reuse) | `[t_light] PASS` |

The compat and mobile runs were made one edit before 7bf6003: the web moon key was then gated on "not Forward+" instead of "gl_compatibility". That is the same value in compat; mobile ran with the plain moon, as it does now.

## Screenshots inspected (round 2)

- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/final2_fwd/lighting_camp_fwd.png`, `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/final_fwd/crop_camp.png`: camp pads are a mid earth brown, slightly lighter than the grass, not cream.
- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/final_gl_compatibility/lighting_camp_compat.png`: pads are dark brown against the brighter compat grass.
- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/fwd2/crop_mobile.png` (1024 atlas): box, pole and tent shadows are solid on the grey probe.
- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/final_gl_compatibility/lighting_night_compat.png`: terrain past the fire is dark green and readable, not black.
- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/fwd2/lighting_night_fwd.png`, `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/final_fwd/crop_dusk.png`: night readable; warm dusk with long tent and chest shadows.
- `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/iso/crop_e_camp_grounded.png`, `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/r3/iso/crop_b_island.png`: survivor shadow present when grounded and when floating.

## Assumptions

- `# ASSUMPTION:` lighting_lab measures at tod 0.42 (mid-morning). The spec names no time.
- `# ASSUMPTION:` a non-IsoCamera orthographic camera looks at ground about 40 m away (fit_shadows).
- `# ASSUMPTION:` night is readable when terrain 8-10 m from the fire has mean luminance >= 0.05.
- Every per-climate row in lighting.json is an assumed tint; `moon_energy_compat` is tuned by eye and by the night_lum check.
- `t_light.gd` is an alias of the spec's `t_lighting.gd`.

## Integrator hooks

- `game/project.godot`: `rendering/anti_aliasing/quality/msaa_3d.web=0` leaves the web build without AA (lv-post-08). Suggest `msaa_3d.web=1` (2x) if the web frame budget allows; I did not measure its cost.
- `game/project.godot`: `rendering/lights_and_shadows/directional_shadow/size.mobile=1024` now works with fitted splits (box 0.426 at 1024). Keep it; raise to 2048 only if the compat shadows still look stair-stepped up close (raptor_scale_lab, round 1).
- Player owner (`game/scenes/player/player.tscn`, not in this package): give the `Shape` node `transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)` so the capsule bottom sits at the feet, then recheck spawn heights (`world.gd` adds 1.0 to surface_y). Check that every caller of player height agrees before changing it.
- `game/scripts/core/rigged_model.gd` owner: set a `custom_aabb` on skinned meshes from the bone extents (survivor's is 2 cm).

## Labs to register

- `lighting_lab`: `game/scripts/dev/lighting_lab.gd` + `game/scenes/dev/lighting_lab.tscn`. Windowed only; headless prints `[lighting] SKIP`.

## What failed or is left

- **lv-sky-17 not done**: the sky is still never visible from the iso camera, and there are no cloud shadows.
- The survivor floats 0.9 m (above). It is the remaining reason his shadow looks detached at dusk.
- Compat shadows are still stair-stepped up close (round 1 note); not re-measured this round.
- The lab measures one camp at one time of day; other climates are only checked by t_light's profile bands.
