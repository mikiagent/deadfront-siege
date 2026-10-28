# Occlusion — see-through props that hide the survivor

Owner: `game/scripts/world/occlusion.gd` (selection, fades, the 8 MultiMesh slots), the material
replica in `game/scripts/world/occlusion_material.gd`, the shader bodies in
`game/scripts/world/occlu_fade.gdshaderinc` (+ `occlu_occluder_standard.gdshaderinc`) and, for CARD2D
cards, `game/shaders/occlusion/occlusion.gdshaderinc` with `game/shaders/card_sway.gdshader`.

## The rule
A prop fades only when it is **between the camera and the survivor**: nearer the camera along the
view ray from her chest (`Occlusion.in_the_way`, a `GRID_M` 8 m grid lookup then one cylinder or box
test per object) **and** overlapping her on screen. A prop farther from the camera than she is stays
fully solid, even when its crown covers her silhouette on screen.

## Numbers (constants in `occlusion.gd`)
| Constant | Value | Meaning |
|---|---|---|
| `BETWEEN_DROP` | 0.55 | share of a fading prop's pixels dropped (9 of the 16 dither cells) |
| `INSIDE_DROP` | 0.85 | share dropped for a roof the survivor stands under |
| `BODY_DROP` / `OCCL_COVER_DROP` | 0.6875 | share a **fading** prop drops over her silhouette |
| `FADE_S` | 0.25 s | fade in/out step (`delta / FADE_S` per frame) |
| `TRUNK_FRAC` | 0.45 | bottom share of a tree kept solid (`set_trunk`) |
| `SLOTS` | 8 | MultiMesh instances that can fade at once (`occl_slot_0..7`) |
| `REACH_MAX_M` | 60 m | longest sight line tested |

## How a frame runs
`_process`: `in_the_way(chest, back)` (back = chest towards the camera) → `step_between` writes the
per-node `occl_fade` instance parameter or fills the slots → `step_inside` for roofs → `_send_body`
publishes her screen ellipse as `occl_body`. The fragment shader dithers with a 4x4 Bayer pattern in
screen space; a prop with `occl_drop` 0 (`occl_cut` in `occlu_fade.gdshaderinc`) draws solid
everywhere, over her silhouette included.

## Tests
`game/tests/t_occlfix.gd` (behind / in front / beside, mesh + MultiMesh + card, plus a GDScript mirror
of `occl_cut`), `t_occlude.gd` (materials, fades, slots), `t_occlude2.gd` (selection, timing, roof).
