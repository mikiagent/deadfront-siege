class_name StatusFx
extends RefCounted
## STATUSFX (owner 2026-10-28: "status effects should appear next to the player as a box with the effect
## symbol inside (bleed is a claw mark, red color, and then there's some kind of particle effect or
## overlay, and it shows red negative numbers for the bleed tick damage)").
## Per active status on the survivor: a box beside her (white icon on HUD ink, rim and time bar in the
## status colour), a particle preset on her body (drip / bubbles / embers) or a faint tint over her, a red
## screen edge that pulses with the ticks (fx.vignette), and a small red "-N" per damage tick.
## Every look comes from the status's statuses.json fx block (StatusDef.fx_*). HuntHud calls tick() from
## _process and the draw_* functions from _draw; this file owns no node but the emitters on the player.

const BOX := 42.0          ## desktop box side
const BOX_COMPACT := 32.0  ## phone box side (844x390 and portrait): a 20 px icon inside
const GAP := 4.0           ## between stacked boxes
const SIDE_GAP := 10.0     ## between her figure and the column
const INSET := 6.0
const MAX_EMITTERS := 3    ## particle presets alive at once (the debuff cap is three anyway)
const TICK_COL := Color(1.0, 0.28, 0.22)  ## fallback only: a tick takes its status's fx colour (owner 2026-10-28)
const BADGE := 10.0        ## the stack-count disc pokes this far right of a box; the column reserves it
const SLOT_SPEED := 8.0    ## slots per second a box glides when one above it ends
const PARTICLE_PRESETS: Array[StringName] = [&"drip", &"bubbles", &"embers", &"water", &"cough"]

## Drawn this frame, for the HUD's taken rects and the tests: status id -> box rect, and the column.
var boxes: Dictionary = {}
var column: Rect2 = Rect2()
## status id -> CPUParticles3D under the player.
var emitters: Dictionary = {}
## WEATHER: the box tooltip, pinned by a press on a box or shown under the pointer, and its rect.
var pinned: StringName = &""
var hovered: StringName = &""
var tip_rect := Rect2()
## The vignette's edge alpha drawn this frame (0 = none).
var vignette_alpha := 0.0
var _slot: Dictionary = {}
var _side := 1.0  # +1 right of her, -1 left; kept until that side is blocked (no flip-flopping)
var _pulse := 0.0
var _events: HudEventState = null
var _watched: StatusEffects = null

func tick(p: Player, events: HudEventState, delta: float) -> void:
	_events = events
	if p == null or p.statuses == null:
		return
	if _watched != p.statuses:
		if _watched and is_instance_valid(_watched) and _watched.ticked.is_connected(_on_tick):
			_watched.ticked.disconnect(_on_tick)
		_watched = p.statuses
		_watched.ticked.connect(_on_tick)
	_pulse = move_toward(_pulse, 0.0, delta * 1.8)
	var live: Dictionary = {}
	var i := 0
	for inst in effects(p):
		live[inst.id] = true
		_slot[inst.id] = move_toward(float(_slot.get(inst.id, i)), float(i), delta * SLOT_SPEED)
		i += 1
	for id in _slot.keys():
		if not live.has(id):
			_slot.erase(id)
	_sync_emitters(p, live)

## A tick landed: its red number over her, and a pulse of the screen edge when the status has one.
func _on_tick(id: StringName, amount: float) -> void:
	var def := Data.status(id)
	if _events:
		_events.add_tick(dot_text(amount), def.fx_color if def else TICK_COL)
	if def and def.fx_vignette:
		_pulse = 1.0

## "-3" for whole damage, "-0.2" for the fraction a light bleed takes per 0.5 s tick.
static func dot_text(amount: float) -> String:
	var a := maxf(0.1, snappedf(amount, 0.1))
	return "-%d" % roundi(a) if absf(a - roundf(a)) < 0.05 else "-%.1f" % a

func _sync_emitters(p: Player, live: Dictionary) -> void:
	var want: Dictionary = {}
	for inst in p.statuses.instances():
		var def := Data.status(inst.id)
		if def and def.fx_particles in PARTICLE_PRESETS and want.size() < MAX_EMITTERS:
			want[inst.id] = def
	for id in emitters.keys():
		if not want.has(id) or not is_instance_valid(emitters[id]):
			if is_instance_valid(emitters[id]):
				(emitters[id] as Node).queue_free()
			emitters.erase(id)
	if p.dead:
		return
	for id in want:
		if not emitters.has(id):
			var e := make_emitter((want[id] as StatusDef).fx_particles, (want[id] as StatusDef).fx_color)
			e.name = "StatusFx_%s" % id
			p.add_child(e)
			emitters[id] = e

## One cheap CPU emitter (Compatibility renderer, web): at most 10 unshaded 6-sided spheres alive.
static func make_emitter(preset: StringName, col: Color) -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.amount = 10
	e.lifetime = 0.9
	e.local_coords = false  # drips stay where they fell as she walks on
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.3  # outside her torso, or the body hides them
	e.position = Vector3(0.0, 0.85, 0.0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat  # opaque and shrinking out: an alpha fade over her shirt read pink, not red
	e.mesh = mesh
	var c := col
	match preset:
		&"drip":  # blood runs off her and falls
			c = Color(col.r * 0.85, col.g * 0.2, col.b * 0.2)  # blood: the family red, desaturated
			e.direction = Vector3.DOWN
			e.spread = 12.0
			e.gravity = Vector3(0.0, -4.0, 0.0)
			e.initial_velocity_min = 0.1
			e.initial_velocity_max = 0.4
			e.scale_amount_min = 0.6
			e.scale_amount_max = 1.1
			e.lifetime = 0.7
		&"bubbles":  # sickly bubbles drift up off her
			e.direction = Vector3.UP
			e.spread = 35.0
			e.gravity = Vector3(0.0, 0.6, 0.0)
			e.initial_velocity_min = 0.1
			e.initial_velocity_max = 0.3
			e.scale_amount_min = 0.7
			e.scale_amount_max = 1.5
			e.lifetime = 1.3
			e.amount = 8
		&"water":  # WEATHER, Wet: clear drops run off her and fall, pale water blue
			c = col.lerp(Color.WHITE, 0.35)
			e.direction = Vector3.DOWN
			e.spread = 15.0
			e.gravity = Vector3(0.0, -6.0, 0.0)
			e.initial_velocity_min = 0.2
			e.initial_velocity_max = 0.6
			e.scale_amount_min = 0.4
			e.scale_amount_max = 0.8
			e.lifetime = 0.6
			e.amount = 8
		&"cough":  # Smoke Inhalation: grey puffs pushed out from her face in short bursts
			e.position = Vector3(0.0, 1.45, 0.0)
			e.emission_sphere_radius = 0.08
			e.direction = Vector3(0.0, 0.3, 1.0)
			e.spread = 25.0
			e.gravity = Vector3(0.0, 0.4, 0.0)
			e.initial_velocity_min = 0.5
			e.initial_velocity_max = 1.0
			e.scale_amount_min = 0.8
			e.scale_amount_max = 1.6
			e.explosiveness = 0.7
			e.lifetime = 0.9
			e.amount = 6
		&"embers":  # small sparks rise
			e.direction = Vector3.UP
			e.spread = 40.0
			e.gravity = Vector3(0.0, 1.2, 0.0)
			e.initial_velocity_min = 0.3
			e.initial_velocity_max = 0.8
			e.scale_amount_min = 0.35
			e.scale_amount_max = 0.7
			e.amount = 8
	mat.albedo_color = c
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.25))
	e.scale_amount_curve = shrink
	return e

## The red screen edge while a vignette status is on: faint, brighter on each tick, fading back.
func draw_vignette(ci: CanvasItem, p: Player, r: Vector2) -> void:
	var def := _first(p, func (d: StatusDef) -> bool: return d.fx_vignette)
	vignette_alpha = 0.0
	if def == null:
		return
	var a := 0.16 + 0.26 * _pulse  # ASSUMPTION: no reference for the strength; faint, never a wash
	vignette_alpha = a
	var depth := minf(r.x, r.y) * 0.14
	var deep := Color(def.fx_color.r, def.fx_color.g * 0.25, def.fx_color.b * 0.25)  # over green grass the family red read orange
	var edge := Color(deep, a)
	var clear := Color(deep, 0.0)
	var o := [Vector2.ZERO, Vector2(r.x, 0.0), r, Vector2(0.0, r.y)]
	var n := [Vector2(depth, depth), Vector2(r.x - depth, depth), r - Vector2(depth, depth), Vector2(depth, r.y - depth)]
	for k in 4:
		var j := (k + 1) % 4
		ci.draw_polygon(PackedVector2Array([o[k], o[j], n[j], n[k]]), PackedColorArray([edge, edge, clear, clear]))

## A faint colour over her for a status whose preset is "tint" (fracture, groggy...) or whose body is
## "sheen" (Wet: a light blue gloss, stronger the more soaked she is).
func draw_tint(ci: CanvasItem, p: Player, fig: Rect2) -> void:
	if not fig.has_area():
		return
	var def := _first(p, func (d: StatusDef) -> bool: return d.fx_particles == &"tint" or d.fx == &"sheen")
	if def == null:
		return
	var inst := p.statuses.get_instance(def.id)
	var a := 0.16 if def.fx != &"sheen" or inst == null else 0.1 + 0.05 * float(inst.stacks)
	var c := fig.get_center()
	var rx := fig.size.x * 0.75
	var ry := fig.size.y * 0.55
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([Color(def.fx_color.lerp(Color.WHITE, 0.25) if def.fx == &"sheen" else def.fx_color, a)])
	for k in 25:
		var ang := TAU * float(k) / 24.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
		cols.append(Color(def.fx_color, 0.0))
	for k in 24:
		ci.draw_polygon(PackedVector2Array([pts[0], pts[k + 1], pts[k + 2]]), PackedColorArray([cols[0], cols[k + 1], cols[k + 2]]))

## The status boxes beside her figure, stacked down from her head, on the side that is free of `taken`.
## Returns the column drawn (empty when nothing shows or there is no room).
func draw_boxes(ci: CanvasItem, font: Font, p: Player, fig: Rect2, taken: Array[Rect2], r: Vector2) -> Rect2:
	boxes.clear()
	column = Rect2()
	var list: Array = effects(p)
	if list.is_empty() or not fig.has_area():
		return column
	var side_px := BOX_COMPACT if UiTokens.is_compact(r) else BOX
	var rows := 0.0
	for inst in list:
		rows = maxf(rows, float(_slot.get(inst.id, 0.0)))
	column = place_column(fig, int(ceil(rows)) + 1, side_px, taken, r)
	if not column.has_area():
		return column
	for inst in list:
		var def := Data.status(inst.id)
		if def == null:
			continue
		var b := Rect2(column.position + Vector2(0.0, float(_slot.get(inst.id, 0.0)) * (side_px + GAP)), Vector2(side_px, side_px))
		boxes[inst.id] = b
		_draw_box(ci, font, b, inst, def)
	return column

## The column rect: right of her (or left, keeping the last side that worked), level with her head, slid
## up or down off any taken rect; empty when neither side has room on screen.
func place_column(fig: Rect2, n: int, side_px: float, taken: Array[Rect2], r: Vector2) -> Rect2:
	var h := float(n) * side_px + float(n - 1) * GAP
	for s in [_side, -_side]:
		var w := side_px + BADGE
		var x: float = fig.end.x + SIDE_GAP if s > 0.0 else fig.position.x - SIDE_GAP - w
		if x < 8.0 or x + w > r.x - 8.0:
			continue
		# The first box sits at her shoulders (a fifth down the figure), the rest stack down from it.
		var top := fig.position.y + fig.size.y * 0.2
		var spot := UiTokens.free_spot(Rect2(x, clampf(top, 8.0, maxf(8.0, r.y - h - 8.0)), w, h), taken, r)
		if spot.has_area():
			_side = s
			return spot
	return Rect2()

func _draw_box(ci: CanvasItem, font: Font, b: Rect2, inst: StatusInstance, def: StatusDef) -> void:
	ci.draw_rect(b, UiTokens.HUD_FILL)
	ci.draw_rect(b.grow(-1.0), def.fx_color, false, 2.0)
	var tex: Texture2D = UiIcons.icon(def.fx_icon) if UiIcons.path_for(def.fx_icon) != "" else HudStatusChip.icon_for(inst.id)
	var icon := Rect2(b.position + Vector2(INSET, INSET - 2.0), b.size - Vector2(INSET, INSET) * 2.0)
	if tex:
		ci.draw_texture_rect(tex, icon, false)
	else:
		ci.draw_string(font, b.position + Vector2(0.0, b.size.y * 0.62), str(inst.id).left(2).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 12, Color.WHITE)
	# Time left as a thin bar along the bottom; "until treated" statuses (>= 3600 s) stay full.
	var frac := 1.0 if inst.time_left >= 3600.0 else clampf(inst.time_left / maxf(0.1, def.duration), 0.0, 1.0)
	var track := Rect2(b.position.x + 3.0, b.end.y - 7.0, b.size.x - 6.0, 4.0)
	ci.draw_rect(track, Color(0, 0, 0, 0.6))
	ci.draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)), def.fx_color)
	if inst.stacks > 1:  # the stack count in a disc on the box's outer corner, off the icon
		var c := Vector2(b.end.x + 1.0, b.position.y + 9.0)
		ci.draw_circle(c, 8.0, def.fx_color)
		ci.draw_string(font, c + Vector2(-8.0, 4.5), str(inst.stacks), HORIZONTAL_ALIGNMENT_CENTER, 16.0, 12, UiTokens.CTA_INK)

## The box under a press or the pointer: its status id, else &"".
func box_at(pos: Vector2) -> StringName:
	for id in boxes:
		if (boxes[id] as Rect2).grow(6.0).has_point(pos):
			return id
	return &""

## A click or tap on a box pins its tooltip (again unpins it); the pointer over a box shows it.
## Returns true when the event was the boxes'.
func input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		hovered = box_at((event as InputEventMouseMotion).position)
		return false
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and event.pressed:
		pos = (event as InputEventScreenTouch).position
	if pos == Vector2.INF:
		return false
	var id := box_at(pos)
	if id == &"":
		pinned = &""
		return false
	pinned = &"" if pinned == id else id
	return true

## The open box's tooltip (its name, stacks and desc) beside the column, off `taken`.
func draw_tip(ci: CanvasItem, font: Font, taken: Array[Rect2], r: Vector2) -> Rect2:
	tip_rect = Rect2()
	var id := pinned if pinned != &"" else hovered
	if id == &"" or not boxes.has(id):
		return tip_rect
	var def := Data.status(id)
	if def == null:
		return tip_rect
	var inst: StatusInstance = _watched.get_instance(id) if _watched else null
	var w := 220.0 if UiTokens.is_compact(r) else 280.0
	var px := UiTokens.meta(r)
	var head := UiTokens.body(r)
	var body_h := font.get_multiline_string_size(def.desc, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, px).y
	var size := Vector2(w, 10.0 + head + 6.0 + body_h + 10.0)
	var b: Rect2 = boxes[id]
	for x in [b.end.x + BADGE + 6.0, b.position.x - w - 6.0]:
		tip_rect = UiTokens.free_spot(Rect2(Vector2(clampf(x, 8.0, r.x - w - 8.0), clampf(b.position.y, 8.0, r.y - size.y - 8.0)), size), taken, r)
		if tip_rect.has_area():
			break
	if not tip_rect.has_area():
		return tip_rect
	ci.draw_rect(tip_rect, UiTokens.HUD_FILL)
	ci.draw_rect(Rect2(tip_rect.position, Vector2(w, 3.0)), def.fx_color)
	var title := def.display_name + (" x%d" % inst.stacks if inst and inst.stacks > 1 else "")
	ci.draw_string(font, tip_rect.position + Vector2(10.0, 10.0 + head * 0.8), title, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, head, Color.WHITE)
	ci.draw_multiline_string(font, tip_rect.position + Vector2(10.0, 16.0 + head + px * 0.8), def.desc, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, px, -1, UiTokens.TEXT)
	return tip_rect

## HUDRULES: the afflictions (kind "effect") only; buffs, boons and debuffs live in the chip row.
static func effects(p: Player) -> Array:
	if p == null or p.statuses == null:
		return []
	return p.statuses.instances().filter(func (inst: StatusInstance) -> bool:
		var def := Data.status(inst.id)
		return def == null or not def.is_modifier())

func _first(p: Player, pick: Callable) -> StatusDef:
	if p == null or p.statuses == null:
		return null
	for inst in p.statuses.instances():
		var def := Data.status(inst.id)
		if def and pick.call(def):
			return def
	return null
