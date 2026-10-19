# W1-LIGHT report (claude, branch claude/mmo-w1-light)

## What shipped

1. **Behaviour-preserving split** (commit d54d252, alone). `island_runtime.gd` went from 1,527 to 363 lines. It keeps build orchestration and its public API. The rest moved to `island_terrain.gd` (435), `island_scatter.gd` (388), `island_spawns.gd` (100), `island_claims.gd` (90), `world_lighting.gd` and `world_weather.gd`. The island_lab counts were the same before and after.
2. **One shared lighting builder** (`WorldLighting.install(host, climate)`), used by both IslandRuntime and LabKit:
   - AgX tonemap, exposure set per renderer in the profile.
   - Sun 2.2 against sky-sourced ambient 0.3. This replaces the flat 0.75 grey fill, and LabKit's second 1.2 sun is gone.
   - PSSM 4-split shadows, normal bias 2.0. The sun yaw sweeps from -35 to -85 deg, which keeps it 80-130 deg off the iso camera's 45 deg axis.
   - A cool moon light at night. Fog and sky colours follow time of day.
   - Warm dawn and dusk keyed to the Game.phase_name() thresholds (0.22 / 0.30 / 0.72 / 0.80).
   - Glow on. The key light never drops below 6 deg of elevation.
   - The first WorldEnvironment in the tree is reused, because it is the one Godot renders. Other directional lights are hidden, and a lab's driver yields to the island's.
3. **Per-climate profiles** in `game/data/world/lighting.json`. `default` fills every key, and every climate in climates.json has its own row.
4. **Rain**: a 2-triangle QuadMesh streak replaces the 4,224-triangle sphere. Its material has `vertex_color_use_as_albedo` and alpha, and `cast_shadow` is OFF.
5. **Dirt discs**: the texture now adds detail around the tint instead of multiplying it, so the near-black stains are gone. The normal is forced to face up, so the back face no longer renders black.
6. **lighting_lab** (`game/scripts/dev/lighting_lab.gd` + `game/scenes/dev/lighting_lab.tscn`) is a windowed pixel verifier. `--light-shots=<dir>` saves the frames.
7. **Tests**: `game/tests/t_lighting.gd`, plus `game/tests/t_light.gd`, an alias that extends it, because the wave-1 runner looks for that name.

## Commits

- d54d252 Split island_runtime.gd into terrain, scatter, spawns, claims, lighting and weather
- 559c437 WIP light (interrupted by usage limit; to be finished): the lighting change itself
- 3f229fa Drop .uid churn for files this package does not own
- (this report)

## Acceptance checklist (I ran each of these in this session and saw the line)

| Item | Output |
|---|---|
| lighting_lab Forward+ shadow | `[lighting] shadow_ratio=0.428` (baseline 0.989) |
| lighting_lab compat shadow | `[lighting] shadow_ratio=0.343` (baseline 0.930) |
| Forward+ camp exposure | `[lighting] blown_pct=0.000`, `[lighting] ground_lum=0.355`, `[lighting] PASS` |
| compat camp exposure | `[lighting] blown_pct=0.000`, `[lighting] ground_lum=0.369`, `[lighting] PASS` |
| Only world_lighting.gd builds lights | grep lists only `world_lighting.gd:80 Environment.new()` and `:105 DirectionalLight3D.new()` (and `:69 WorldEnvironment.new()`) |
| File sizes | island_runtime 363; island_terrain 435, island_scatter 388, island_spawns 100, island_claims 90, world_lighting 157, world_weather 75 (all <= 450) |
| Behaviour preserved | island_lab headless before and after: `[world] island temperate_25 nodes=378 creatures=24 spawn_rejected=0` |
| Smoke | `SMOKE PASS` (tools/smoke.sh --no-import through gslot) |
| Suite | `[tests] PASS` (run_all.gd) |
| t_lighting: night fog, moon, warm dawn and dusk, never from below, phase thresholds, profiles, rain material and shadows | `[t_light] PASS` |

## Screenshots inspected

All are under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/light/`.

- `shots2/island_camp_fwd.png` and `shots2/island_camp_compat.png`: island_lab camp. The ground is mid-green, not washed out, and the tree casts a dark, clearly visible shadow. Compat is slightly brighter and greener.
- `shots2/raptor_compat.png`: raptor_scale_lab in compat. The compy, velociraptor and deinonychus show their textures and colours. Compare `audit/dino-art/raptor_scale_lab_gl_cam10.png`, which was near-white. Their shadows show, but they are **blocky and stair-stepped** on the web renderer.
- `shots2/lighting_box_fwd.png`: the box probe throws a dark shadow on the grey plane.
- `shots/lighting_night_fwd.png` (tod 0.0): dark blue-black night. The camp is lit by the fire, and the moonlit faces are cool.
- `shots/lighting_dusk_compat.png` (tod 0.73): a warm orange key light with long shadows.

## Assumptions

- `# ASSUMPTION:` lighting_lab measures at tod 0.42 (mid-morning, sun about 51 deg up). The spec names no time.
- Every per-climate lighting row in lighting.json is an assumed tint. The PRD gives no per-climate lighting values; the `_about` key says so.
- `t_light.gd` is an alias of the spec's `t_lighting.gd`.

## Integrator hooks

None needed. IslandRuntime and LabKit call `WorldLighting.install` themselves. If `main.gd` or `game.gd` still build their own WorldEnvironment or DirectionalLight3D, WorldLighting takes them over at runtime, so the integrator may delete them later. That is optional.

## Labs to register

- `lighting_lab`: `game/scripts/dev/lighting_lab.gd` + `game/scenes/dev/lighting_lab.tscn`. Run it windowed; headless prints `[lighting] SKIP`.

## What failed or is left

- Compat shadows still look blocky and stair-stepped up close (raptor_scale_lab). Raising the web renderer's shadow atlas size in project.godot is the integrator's call, so I did not touch it.
- The gl_compatibility run prints `ERROR: Texture with GL ID ...: leaked` at exit. I saw this, but I did not check whether it comes from this package.
- The lighting change landed under the WIP commit title (559c437). History was not rewritten.
