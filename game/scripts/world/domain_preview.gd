class_name DomainPreview
extends MeshInstance3D
## Spec 29 section 2's ground-grid preview for Domain -> Declare / Expand: the cells around the
## survivor drawn flat on the ground in three colours - claimed (gold, yours already), eligible
## (teal, tap to select) and invalid (red, with the reason in the Domain screen's line) - and the
## cells a tap picked drawn brighter with a white border. It is a ground overlay, not a panel, so
## the survivor can still walk, drag the camera and read the terrain they are claiming.
##
## The preview owns the tap: one touch or click on a cell toggles it (a press, not a drag, so a
## camera drag across the grid moves nothing). Confirm/Cancel live in DomainScreen and call
## claim_domain()/finish() here.

signal selection_changed(count: int)
signal cell_refused(reason: String)

## Fills are strong enough to read on bright grass and dark sand alike (the first pass at 0.26-0.30
## alpha was one uniform wash on the ground, measured in the lab shots), and every cell gets its own
## border so a cell's state shows even where the fill lands on similar ground.
const CLAIMED_COLOR := Color(0.96, 0.82, 0.36, 0.40)
const CLAIMED_EDGE := Color(1.0, 0.88, 0.42, 0.95)
const ELIGIBLE_COLOR := Color(0.16, 0.86, 0.80, 0.34)
const ELIGIBLE_EDGE := Color(0.42, 1.0, 0.94, 0.85)
const INVALID_COLOR := Color(0.95, 0.18, 0.12, 0.30)
const INVALID_EDGE := Color(1.0, 0.36, 0.28, 0.80)
## A cell that is merely not adjacent is not a refusal the survivor has to act on (the whole window
## outside the domain is like that): it draws as a faint neutral cell so the red is reserved for
## water, cliffs, the island's edge and other owners' land.
const NEUTRAL_COLOR := Color(1.0, 1.0, 1.0, 0.06)
const NEUTRAL_EDGE := Color(0.85, 0.92, 1.0, 0.30)
const PICKED_COLOR := Color(1.0, 1.0, 1.0, 0.55)
const PICKED_EDGE := Color(1.0, 1.0, 1.0, 1.0)
const EDGE_W := 0.16  ## metres of border inside each cell's own edge
const LIFT := 0.08  ## above the ground (the claim outline's dashes sit at 0.07)
const INSET := 0.06  ## metres of gap each side, so neighbouring cells read as a grid
const MAX_INVALID := 240  ## a wide window on a big island draws this many red cells at most

var rt: IslandRuntime
var centre := IslandClaims.NO_CELL
var radius: int = IslandClaims.PREVIEW_RADIUS
var info := {}  ## Vector2i -> {"state", "reason"} for the drawn window
var picked: Array[Vector2i] = []

var _quads: Array = []  ## [cell, fill, border] drawn this frame (picked cells last, so they win)
var _press_at := Vector2.ZERO
var _pressing := false

func _init() -> void:
	name = "DomainPreview"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Drawn over the ground it lies on: the cells must read on a slope without z-fighting the grass.
	mat.no_depth_test = false
	mat.render_priority = 1
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Open the preview around the cell the survivor stands in (claim cells either side).
func begin(runtime: IslandRuntime, at: Vector2i, r: int = IslandClaims.PREVIEW_RADIUS) -> void:
	rt = runtime
	centre = at
	radius = maxi(1, r)
	picked.clear()
	refresh()

## Recompute the window's cells and redraw. Cheap enough for a tap (a few hundred cells).
func refresh() -> void:
	_quads.clear()
	info.clear()
	if rt == null:
		mesh = null
		return
	var look: Dictionary = IslandClaims.preview(rt, centre, radius)
	for c: Vector2i in look["claimed"]:
		info[c] = {"state": "claimed", "reason": ""}
		_quads.append([c, CLAIMED_COLOR, CLAIMED_EDGE])
	var invalid := 0
	for row in look["invalid"]:
		var cell: Vector2i = row["cell"]
		if invalid >= MAX_INVALID:
			break
		invalid += 1
		var why := str(row["reason"])
		info[cell] = {"state": "invalid", "reason": why}
		_quads.append([cell, NEUTRAL_COLOR, NEUTRAL_EDGE] if why == "not_adjacent" else [cell, INVALID_COLOR, INVALID_EDGE])
	var elig: Array = look["eligible"]
	elig.sort_custom(func (a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	for c: Vector2i in elig:
		info[c] = {"state": "eligible", "reason": ""}
		_quads.append([c, ELIGIBLE_COLOR, ELIGIBLE_EDGE])
	# Last, so a picked cell's white border is drawn over its neighbours' edges.
	for c in picked:
		if info.has(c):
			_quads.append([c, PICKED_COLOR, PICKED_EDGE])
	mesh = _build_mesh()

## Tap a cell: eligible toggles it into the selection, anything else answers with its reason.
func pick(cell: Vector2i) -> bool:
	var row: Variant = info.get(cell)
	if row == null:
		cell_refused.emit("outside_the_island")
		return false
	var state := str((row as Dictionary)["state"])
	if state == "claimed":
		cell_refused.emit("already_owned")
		return false
	if state == "invalid":
		cell_refused.emit(str((row as Dictionary)["reason"]))
		return false
	if picked.has(cell):
		picked.erase(cell)
	else:
		picked.append(cell)
	refresh()
	selection_changed.emit(picked.size())
	return state == "eligible"

func selected_cells() -> Array[Vector2i]:
	return picked.duplicate()

func clear_selection() -> void:
	picked.clear()
	refresh()
	selection_changed.emit(0)

## The selection as one batch: what DomainScreen's Confirm commits.
func commit() -> Dictionary:
	if rt == null:
		return {"ok": false, "reason": "outside_the_island", "cells": []}
	var out: Dictionary = IslandClaims.claim_cells(rt, picked)
	if bool(out["ok"]):
		picked.clear()
		refresh()
		selection_changed.emit(0)
	return out

func counts() -> Dictionary:
	var claimed := 0
	var eligible := 0
	var invalid := 0
	for row in info.values():
		match str((row as Dictionary)["state"]):
			"claimed":
				claimed += 1
			"eligible":
				eligible += 1
			_:
				invalid += 1
	return {"claimed": claimed, "eligible": eligible, "invalid": invalid}

## Why the tapped cell could not be taken, in the Domain screen's words (the last refusal).
func reason_text(reason: String) -> String:
	return IslandClaims.reason_text(reason)

func finish() -> void:
	rt = null
	picked.clear()
	info.clear()
	_quads.clear()
	mesh = null
	queue_free()

# ---------------------------------------------------------------- ground input

func _unhandled_input(event: InputEvent) -> void:
	if rt == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press_at = touch.position
			_pressing = true
		elif _pressing and touch.position.distance_to(_press_at) < 24.0:
			_pressing = false
			_tap(touch.position)
		else:
			_pressing = false
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_press_at = mb.position
			_pressing = true
		elif mb.button_index == MOUSE_BUTTON_LEFT and _pressing:
			_pressing = false
			if mb.position.distance_to(_press_at) < 8.0:
				_tap(mb.position)

func _tap(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * cam.far
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_tree().root.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	pick(IslandClaims.cell_of(rt, BuildGrid.tile_of(hit["position"])))

# ---------------------------------------------------------------- the mesh

## A flat quad per cell that follows the terrain, then a frame inside its edge for the border (four
## thin quads, so a border never needs a second material or line primitive).
func _build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for row in _quads:
		var rect: Rect2i = IslandClaims.cell_rect(rt, row[0])
		var fill: Color = row[1]
		var edge: Color = row[2]
		var x0 := float(rect.position.x) + INSET
		var x1 := float(rect.end.x) - INSET
		var z0 := float(rect.position.y) + INSET
		var z1 := float(rect.end.y) - INSET
		for tri in _quad_tris(Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)):
			verts.append(tri)
			cols.append(fill)
		var w := EDGE_W
		var frames := [
			[Vector2(x0, z0), Vector2(x1, z0 + w)],
			[Vector2(x0, z1 - w), Vector2(x1, z1)],
			[Vector2(x0, z0 + w), Vector2(x0 + w, z1 - w)],
			[Vector2(x1 - w, z0 + w), Vector2(x1, z1 - w)],
		]
		for f in frames:
			var p: Vector2 = f[0]
			var q: Vector2 = f[1]
			for tri in _quad_tris(Vector2(p.x, p.y), Vector2(q.x, p.y), Vector2(q.x, q.y), Vector2(p.x, q.y)):
				verts.append(tri)
				cols.append(edge)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func _quad_tris(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Array:
	return [_corner(a), _corner(b), _corner(c), _corner(a), _corner(c), _corner(d)]

## A tile-space point on the terrain, lifted clear of it.
func _corner(at: Vector2) -> Vector3:
	var y := rt.surface_y(at.x, at.y)
	return Vector3(at.x, y + LIFT, at.y)
