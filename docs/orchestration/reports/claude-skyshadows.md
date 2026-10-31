# SKYSHADOWS — cloud cover and pteranodon shadows (Claude, 2026-10-28)

Owner, verbatim: "add the shadows of pteranodons flying overhead and cloud cover as part of the polish and
performance patch". Roadmap `sky-shadows` (tools/docs_wiki/phase-map.json, source
docs/design/islands-and-loop-plan.md). Branch `claude/mmo-skyshadows` off `claude/mmo-overhaul`; not merged,
not pushed. The roadmap status is left at `later` for whoever merges it.

## What shipped

- **Cloud cover**: soft cloud shadows drift across the island with the wind. One 256 px seamless noise image
  (FastNoiseLite, built once and shared across islands) tiles every 240 m of ground; a threshold taken from
  the image's own histogram makes `cloud_cover` in sky.json the true share of ground in shadow (t_skyshadows
  checks it within 5 points). The edge is about 4-6 m soft.
- **Sun dip**: while a cloud covers the survivor the sun's energy eases down by up to 22 % (`sun_dip`) over
  about a second. SkyShadows runs at process_priority 10, after WorldLighting rewrites the sun each frame, so
  world_lighting.gd is untouched (the lightport A/B branch can merge independently).
- **Pteranodon shadows**: 1-3 per climate glide in 14-30 m circles around a point that trails the survivor by
  ~12 s and wanders 10 m, at 9 m/s, with a two-beat flap (span folds to 72 %) every 9 s. The silhouette is an
  analytic signed-distance shape in the shader (swept 6 m wings, body, long beak), soft-edged 0.3 m. No
  pteranodon mesh exists in game/assets/creatures, and none is drawn: at the default zoom the 4.3 deg lens shows
  a ~40 x 22 m patch of ground, so a 6 m flyer inside the frustum would sit mid-screen at a sixth of its width,
  not glimpse past an edge. Only the shadows are shown.
- **Night**: every strength scales by `1 - WorldLighting.night`, so the shadows fade through dusk and are gone at
  night. No night lighting change.
- **Where it shows**: `shaders/sky/sky_shadow.gdshaderinc` is included by the terrain (per pixel), dirt pads
  and water (per pixel), grass (foliage_sway), ground cover, card_sway and PropCards cards (per vertex, one value
  at the card's ground point). 3D glb props, creatures and the survivor are not darkened; the sun dip covers the
  survivor.
- **Quality toggle**: `SkyShadows.enabled`. Default off on a phone browser (`web_android` / `web_ios` features),
  on elsewhere; `--skyshadows=off|on` and `--no-skyshadows` override; `SkyShadows.set_enabled(on, tree)` flips it
  live. Off writes zero strengths, so every shader returns after one branch, stops the node's processing and
  removes the dip. No settings-menu button (nav menu belongs to the UI agents).
- **Data**: `game/data/world/sky.json`, default merged under each climate: cloud_cover, cloud_strength,
  wind_mps, sun_dip, flyers, flyer_strength, glide_mps, compat_scale.
- **Docs**: the generator `tools/docs_wiki/gen_game_data.py` now writes a "Sky shadows" section into
  `docs/current/world-biomes.md` from sky.json; regenerated (only that page changed).

Files: game/scripts/world/sky_shadows.gd (new), game/shaders/sky/sky_shadow.gdshaderinc (new),
game/data/world/sky.json (new), game/project.godot (6 shader globals), game/scripts/world/island_runtime.gd
(install), 7 shaders/shader sources (one include, one multiply each), game/tests/t_skyshadows.gd,
game/scripts/dev/skyshadows_lab.gd + game/scenes/dev/skyshadows_lab.tscn.

## Frame cost

| measure | on | off | delta |
|---|---|---|---|
| CPU, SkyShadows.step (t_skyshadows, 7200 frames) | 1.5 us/frame | — | 1.5 us |
| gl_compatibility 1600x900, frame time (4 x 240 frames interleaved, M5 Pro) | 4.177 ms | 3.989 ms | +0.19 ms (an earlier run: +0.12) |
| gl_compatibility 844x390 | 3.479 ms | 3.434 ms | +0.045 ms |
| Forward+ (Metal), 1600x900 and 844x390 | 8.33 ms | 8.33 ms | within +-0.016 ms: Metal paces at 120 Hz even with --disable-vsync |

No per-frame allocations: step() writes value types into preallocated PackedVector4Array / Vector4 fields.
Two minutes of simulated sky: node count 44 -> 44, object count 2369 -> 2369. GPU timers
(viewport_get_measured_render_time_gpu) read 0 on Metal and on this GL driver, so wall-clock deltas are the
measure. The globals take 5 vec4 slots of the 1024-item global shader buffer plus one sampler.

## Captures (docs/orchestration/reports/skyshadows/, all <= 260 KB, palette-quantized)

- skyshadows_flyer_fwd_1600x900.png: a pteranodon shadow crossing the camp, Forward+.
- skyshadows_flyer_compat_844x390.png: the same on the web renderer at phone landscape.
- skyshadows_cloud_on_off_compat_1600x900.png: a cloud edge over the camp, on (left) and quality off (right).
- skyshadows_cloud_fwd_844x390.png: the cloud edge, Forward+, phone landscape.
- skyshadows_dusk_fwd_1600x900.png: tod 0.79, the flyer shadow half-faded.

Reproduce: `Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility] --disable-vsync
--max-fps 0 -- --lab=skyshadows_lab --shot-dir=DIR`. Default camera zoom, untouched.

## Gates

- t_skyshadows PASS (spawn with the climate's flyers, cloud share matches cloud_cover, flyers glide and flap,
  clouds drift, the sun dips 15-40 % under full cover, night zeroes everything and dusk half-fades, toggle off
  removes shadows and dip and toggle on restores them, no node or object growth over 2 min, CPU < 50 us).
- t_web PASS, t_colors PASS, t_ui PASS, run_all `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS.

## Assumptions (all `ASSUMPTION` in sky.json / code)

- Every number in sky.json (cover per climate, darkening, wind, flyer count per climate, glide speed, sun dip,
  compat_scale 0.7 because the web renderer's tonemap made the same albedo cut about a third darker).
- "Lowest web/mobile tier" = a browser on a phone; native iOS and desktop web keep it on.
- Circle radii, anchor lag and wander, flap timing, the 50 us CPU budget in the test.
- The sky is local per client (anchored on the local survivor), never synced: it is cosmetic.

## Risks / for the next agent

- It darkens albedo rather than removing direct light, so ambient dims too; tuned by eye on home_grassland at
  tod 0.42. Other climates' grounds (snow, sand) were not captured and may want their own strength.
- 3D props (rocks, the big glb trees, the tent) and creatures are not shaded: on native they go through the
  occlusion include, on web through plain StandardMaterial3D, and covering only one would split the look.
- Desktop gl_compatibility prints "Too many instances using shader instance variables" on islands; it does so
  on the base branch too (lighting_lab on temperate_25: 194 lines), not from this change.
- The dip relies on running after WorldLighting each frame (process_priority 10). If lighting ever stops
  rewriting sun.light_energy every frame, the dip would compound; t_skyshadows re-drives the sun per frame like
  the game does.
- Not done: a settings-menu toggle button, any flyer mesh or glimpse, rain-linked cloud cover.
