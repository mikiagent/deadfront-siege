# TASK: split HuntHud's layout geometry and world pills out of hunt_hud.gd (behaviour unchanged)

## Why

`game/scripts/ui/hunt_hud.gd` grew from 1376 lines (its size on the base branch) to 1674 lines in this
package. The rule is "no god-file growth". A reviewer asked to move the self-contained layout geometry
into a small helper of static functions over the HUD's nodes, leaving hunt_hud.gd at or under 1376 lines.
The world label pills (`_draw_pills` and its two helpers) are the other big self-contained block, so they
move into a second helper. This is a pure move: every pixel the HUD draws and every control position must
stay exactly the same. The gate compares the HUD's control positions in a real windowed run against a
baseline taken before the move.

## The files

Only these four files may change (plus `DSC_NOTES.md` if you want notes):

- `game/scripts/ui/hunt_hud.gd` (class `HuntHud`): code moves out of it.
- `game/scripts/ui/hud_layout.gd` (class `HudLayout`, a stub exists): receives the layout geometry.
- `game/scripts/ui/hud_pills.gd` (class `HudPills`, a stub exists): receives the world pills.
- `game/scripts/ui/gather_radial.gd`: one call site, `HuntHud.nameplate_rect(` becomes `HudLayout.nameplate_rect(`.

Both helper files already have their `class_name` line and are registered with Godot (the import was run).
Do NOT add any other `class_name` and do not create other files under `game/`. Do NOT touch tests, labs,
`project.godot` or any other script.

## What moves where

Into `HudLayout` (all `static func`, no member `var`, the HUD passed in as `hud: HuntHud`):

| hunt_hud.gd now | HudLayout |
|---|---|
| `static func _landscape_phone(r: Vector2) -> bool` | `static func landscape_phone(r: Vector2) -> bool` |
| `func _vitals_rect(r: Vector2) -> Rect2` | `static func vitals_rect(hud: HuntHud, r: Vector2) -> Rect2` |
| `func _centre_band(r: Vector2) -> Rect2` | `static func centre_band(hud: HuntHud, r: Vector2) -> Rect2` |
| `func _layout_landscape_phone(r, inset)` | `static func place_landscape_phone(hud: HuntHud, r: Vector2, inset: Vector4) -> void` |
| `func _layout_portrait(r, inset, rail_y)` | `static func place_portrait(hud: HuntHud, r: Vector2, inset: Vector4, rail_y: float) -> void` |
| the desktop `else:` branch inside `_layout()` (End Combat, the honeycomb skill cluster, Auto, Feed, whistle column, stance label) | `static func place_desktop(hud: HuntHud, r: Vector2, inset: Vector4) -> void` |
| `func _fit_sheet(r, inset, rail_y)` | `static func fit_sheet(hud: HuntHud, r: Vector2, inset: Vector4, rail_y: float) -> void` |
| `func taken_rects(skip)` body | `static func taken_rects(hud: HuntHud, skip: PackedStringArray = []) -> Array[Rect2]` |
| `func figure_rect()` body | `static func figure_rect(hud: HuntHud) -> Rect2` |
| `static func nameplate_rect(cam, who, font)` | `static func nameplate_rect(cam: Camera3D, who: Player, font: Font) -> Rect2` |
| `func _draw_levelup_banner(box, a)` | `static func draw_levelup_banner(hud: HuntHud, box: Rect2, a: float) -> void` |

Into `HudPills` (all `static func`, no member `var`):

| hunt_hud.gd now | HudPills |
|---|---|
| `const TOOL_ICON_ITEM := {...}` | `const TOOL_ICON_ITEM := {...}` |
| `func _gather_radial_node() -> Node3D` | `static func gather_radial_node(hud: HuntHud) -> Node3D` |
| `func _tools_for_node(n3, grp) -> Array` | `static func tools_for_node(hud: HuntHud, n3: Node3D, grp: String) -> Array` |
| `func _draw_pills(cam, avoid)` | `static func draw(hud: HuntHud, cam: Camera3D, avoid: Array[Rect2]) -> void` |

In `hunt_hud.gd`:
- `_layout()` calls `HudLayout.place_landscape_phone(self, r, inset)`, `HudLayout.place_portrait(self, r, inset, y)`,
  `HudLayout.place_desktop(self, r, inset)` and `HudLayout.fit_sheet(self, r, inset, y)` in the same branches
  as today. Keep the lines at the end of `_layout()` that reset `_ctx_ids` and `_ctx_timer` (and their comment).
- Every other caller uses the helper: `HudLayout.vitals_rect(self, r)`, `HudLayout.centre_band(self, r)`,
  `HudLayout.landscape_phone(...)`, `HudLayout.nameplate_rect(cam, player, _font)`,
  `HudLayout.draw_levelup_banner(self, ..., la)`, `HudPills.draw(self, cam, taken)`.
- `taken_rects` and `figure_rect` stay on HuntHud as one-line delegations, because creature_plates.gd and the
  lab call them on the HUD:
  ```gdscript
  func taken_rects(skip: PackedStringArray = []) -> Array[Rect2]:
  	return HudLayout.taken_rects(self, skip)
  ```
  and the same for `figure_rect()` -> `return HudLayout.figure_rect(self)`. Keep their `##` doc comments
  in HudLayout (a one-line `##` on the wrapper is fine).
- Keep `## doc` comments and `# ASSUMPTION:` comments with the code they describe (they move too).

Inside the helpers, the code reads the HUD's members through `hud.` (`hud._minimap`, `hud._whistle_hexes`,
`hud._end_btn`, `hud._skill_hexes`, `hud._auto_hex`, `hud._feed_hex`, `hud._stance_label`, `hud._sheet`,
`hud._sheet_rows`, `hud._font`, `hud.player`, `hud.drawn_blocks`, `hud._safe_insets()`,
`hud.get_viewport()`, `hud.get_tree()`, `hud.get_children()`, `hud.is_inside_tree()`,
`hud.get_viewport_rect()`) and draws with `hud.draw_rect(...)`, `hud.draw_string(...)`,
`hud.draw_circle(...)`, `hud.draw_texture_rect(...)` (drawing on a CanvasItem from a static function works
while that item is inside its `_draw()`, which is where HuntHud calls them). Constants: `HuntHud.HEX`,
`HuntHud.MAP_PX`, `HuntHud.CAPTION_H`, `HuntHud.SKILL_HEX`, `HuntHud.NAME_PX`. Use typed GDScript (`var x: T`
or `:=` with a typed right-hand side). Copy the logic exactly; do not "improve" numbers, order or branches.
Do not compress code (no `;` joins, no deleted comments, no shortened lines) to hit the line count: moving
the listed functions is enough to get hunt_hud.gd under 1376 lines.

## Rules

- Run Godot ONLY through `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh`
  with a perl alarm, from the worktree root, e.g.
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 240; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_ui.gd`.
  Never pass `--editor`. Never run `--import` (it is done; tell the reviewer if you think one is needed).
  Never play audio.
- Quick parse check while you work: the t_ui command above must print `[t_ui] PASS`.
- `./verify_w1ui_dsc2.sh` is the gate (read-only, do not edit it). It runs static checks, t_ui, the smoke
  boot and the real-scene UI lab windowed at 844x390 and 1600x900 (each lab run takes several minutes;
  run the full verify only when the static checks and t_ui pass).
- Never touch `game/override.cfg`, `.godot/`, `*.import`, `_Image_*` files. Never `git add -A`: add the four
  files by name. Never push.
- Commit when done with a message ending in the line
  `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`

## Milestones

1. HudLayout: move the layout functions (table 1), update callers, t_ui passes. Commit.
2. HudPills: move the pill functions (table 2), update the caller, t_ui passes. Commit.
3. `./verify_w1ui_dsc2.sh` prints `VERIFY PASS`. Commit.
