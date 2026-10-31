# Claude: EYETRAILS round 2 (flame shader, strands, quality toggle, cost)

Owner, round 1: "creepy, deadly and cinematic ... not 2 misplaced candles ... emanate from the eye
outwards", "a flame in the wind". Round 2 scope: a noise-texture flame shader on the trail strands,
thinner and longer tapering strands, a web/mobile quality toggle, and a small, measured cost.

## What shipped

| File | Change |
|---|---|
| `game/scripts/creatures/eye_trail.gd` | **Flame shader** (`FLAME_SHADER`, a spatial ShaderMaterial in place of the StandardMaterial: additive, unshaded, no depth write, no fog, no shadow). A 64x64 tileable noise texture (built once, synchronously) scrolls from the eye to the tip. A fragment survives only where the noise beats a threshold that rises towards the tip and the edges, so each strand tears into licks and flickers. Heat follows the noise and falls along the strand. **Strands**: each eye now draws a fan of 4 strands over the shared curve: a main tongue, two shorter, thinner ones that fan out to either side, and a wide faint glow in the eye colour. All start at the eye and taper to a point, each with its own flicker and lateral flutter. They are thinner (main half-width 2.6 px floor instead of 4) and longer (`MAX_LENGTH_M` 1.6 -> 3.2 m, scale floor 0.5 -> 0.6). **Quality toggle**: `EyeTrail.low_quality` (static). It is on when the renderer is not Forward+, or on web or phones, the same split `WorldLighting`/`ProcessFx` use. Low drops the glow strand, uses 7 rows instead of 10, draws half the embers, and the shader's `#define LOW` takes one noise tap instead of two. **Cost**: an indexed ArrayMesh with a fixed layout. The index buffer and UVs are written once, and per frame only positions and core colours are written by index. A 256-entry noise table replaces `sin()`. No per-frame allocation in script. **Two bugs fixed**: (1) at 120 fps the 12-sample cap, not the 0.3 s fade, set the flame length (the head moved under `FORCE_STEP_M` per frame, so it sampled every frame). The force step is now at least `max_length / (samples - 1)`. (2) At 120 fps the head bone moves on 60 Hz physics frames only, so the raw speed alternated between 0 and 2x and lit a flame on an idle head. Head speed is now smoothed (`SPEED_SMOOTH`). |
| `game/tests/t_eyetrails.gd` | The material checks now read the shader's render modes and the noise texture. New `_test_quality_and_alloc`: for high and low, it checks that the toggle took effect (strand count, shader variant), that low draws fewer than 0.7x the vertices and costs less than 0.9x the script (best of 3 batches), that the vertex buffer keeps its size, that no Object is created per tick, that static memory stays flat over 360 ticks, and it scans the tick-path functions for allocating constructs (`[]`, `{}`, `.new(`, `Array(`, `.resize(`, `.duplicate(`, `%` formatting). **The cost test is now honest**: animals keep running during the 240 timed frames, and only `tick()` is timed. Round 1 timed standing animals whose flames had died after 0.3 s, so its "1.5 ms" was mostly the bloom. The game-camera width floor is lowered to 3.5 / 5 px (thinner on purpose), and the length floor raised from 30 to 60 px. Shot pass: `--shot-tod=` (dusk = 0.79), 60 fps cap, and real frame time. |
| `docs/current/eyes.md` | Rewritten for the strands, shader, quality toggle, allocation rule, constants and the honest cost. |

## A/B for the owner (`docs/orchestration/reports/eyetrails2/`)
All shots: the game `IsoCamera` at the default 14 m zoom (~190 m back; the T. rex at 18 m, max game zoom, so
its head stays in frame), 1600x900 window, 60 fps, animal running a curve at 8 m/s.

- `AB_tyrannosaurus_night_2x.png`: **left = A (round 1, canon), right = B (round 2)**. Midnight,
  Forward+. A 400x225 crop of the game-camera frame, scaled 2x (nearest). A: two smooth wavy bars.
  B: from each eye, a fanned tuft of thin licks that tear and thin out towards the tips.
- `AB_deinonychus_night_2x.png`: **left = A, right = B**, same setup, 480x270 crop at 2x. A: two short
  blobs with white cores sitting on the head. B: longer green flame tongues streaming back along the
  neck, ragged at the ends, with sparks.
- `B_tyrannosaurus_dusk_web.png`: dusk (night 0.43), gl_compatibility (the web renderer, low-quality
  path), native 800x450 crop.
- `B_deinonychus_night_web.png`: midnight, gl_compatibility, low path, native crop.
- `B_deinonychus_dusk.png`: dusk, Forward+, native crop.
- `B_tyrannosaurus_turn_night.png`: stop and snap the head 150 deg: one long torn arc sweeps up from the eye.

Honest verdict: at the game camera this reads as fire streaming off the eyes, not as candles. The
strands are 2-5 px wide there, so the noise tearing shows mostly as ragged, broken tips and a flicker
from frame to frame, not as visible internal texture. Dusk is weaker than night in both A and B: the
glow is scaled by the night factor (0.43-0.48 at dusk), which is round-1 behaviour and unchanged. The
web (gl_compatibility) flame is thinner and crisper than Forward+ (no glow strand, no HDR bloom). The
snap-turn arc on the T. rex is long (5.5 m, the length cap scales with eye separation) and reads more as
a scythe than a lick. If the owner finds it too much, lower `max_length_m` for that species in its
`eyes.trail` block.

## Cost (this Mac, script time in `tick()`, animals running at full flame strength)

| | per creature | 20 creatures |
|---|---|---|
| round 1 code, measured the same way | ~280 us | 5.6 ms |
| round 2 high (Forward+) | ~68 us | 1.36-1.43 ms (gate 2 ms) |
| round 2 low (web / phones) | ~52 us | ~1.05 ms |

Vertices per creature: 392 high, 242 low (round 1: up to 1032). Upload (`add_surface_from_arrays`)
about 2 us per creature. Draw calls are unchanged: one per eyed creature. GPU: one or two noise taps per
fragment on small additive strips.

## Gates (through gslot)
`t_eyetrails` PASS, `t_eyeglow` PASS, `t_web` PASS, `t_colors` PASS, `run_all` `[tests] PASS`,
`tools/smoke.sh --no-import` SMOKE PASS. The only SCRIPT ERRORs are the known ones (TouchControls compile
order, the deliberate econ fault test).

## Risks / for the next agent
- The engine still copies the vertex buffer to the GPU every frame (one `add_surface_from_arrays`), as
  the ImmediateMesh did. "No per-frame allocation" covers the script only.
- `low_quality` is read at `setup()`. Changing it at runtime affects animals spawned afterwards only.
- Collapsed (unused) ribbon blocks sit at the world origin as degenerate triangles; `custom_aabb` keeps
  culling and transparent sorting on the real reach. Anything that reads the mesh AABB directly would
  see the origin.
- The web cost is not measured in a browser (only on this Mac). GDScript on the web is slower, so
  expect a few times the low numbers.
- No credits spent. No sound. No creature brains or anim clips touched. No data files changed (per-species
  `eyes.trail` overrides still work and are clamped).

## Assumptions (marked in code)
Strand count, lengths, widths, fan, alphas and heat; FAN_SPREAD 4.5; tear 0.7 (glow 0.4x); flow 1.7;
TIP_POW 0.9; HOT_HEAD 0.25; MAX_LENGTH_M 3.2; SAMPLE_DT 0.03; SPEED_SMOOTH 25; the quality split.
