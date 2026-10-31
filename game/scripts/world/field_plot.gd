class_name FieldPlot
extends StaticBody3D
## Farm field on claimed tiles. Plant / water / fertilise / harvest via GatherRadial options.
## Shows its state: a planted field grows rows of plants through sprout / young / growing / mature
## (failed wilts brown) and floats its harvest timer ("4m 13s", "Ready"); an empty field is bare soil.

var kind: StringName = &"field_small"
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var crop_id: StringName = &""
var growth: float = 0.0 ## 0..1
var watered: float = 0.0 ## water units applied
var fertilizer: float = 0.0 ## current plant fertilizer
var fertilizer_overflow: float = 0.0
var mature: bool = false
var failed: bool = false

const DATA_PATH := "res://data/farming.json"
## ASSUMPTION: one stack of fruit_fertilizer (stack_max 20). Real overflow is the fraction left
## after a harvest (< 1 at fertilizer_yield_bonus 1.0).
const OVERFLOW_MAX := 20.0

const VIS_S := 0.25 ## crop model / timer refresh
## Soil top of the Blender field (aabb 0.34 m with its log border).
const SOIL_Y := 0.26

static var _data: Dictionary = {}

var _vis_left: float = 0.0
var _shown_stage: String = "?"
var _crop_root: Node3D
var _timer_label: Label3D

static func make(p_kind: StringName = &"field_small") -> FieldPlot:
	var f := FieldPlot.new()
	f.kind = p_kind
	f.name = str(p_kind)
	return f

static func from_dict(d: Dictionary) -> FieldPlot:
	var f := make(StringName(str(d.get("kind", "field_small"))))
	var cell_v: Variant = d.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		f.build_cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	f.build_rot = int(d.get("rot", 0))
	f.crop_id = StringName(str(d.get("crop_id", "")))
	f.growth = float(d.get("growth", 0.0))
	f.watered = float(d.get("watered", 0.0))
	f.fertilizer = float(d.get("fertilizer", 0.0))
	# Pack-up turns overflow into fruit_fertilizer items: a forged save value must not mint a pile.
	var over := float(d.get("fertilizer_overflow", 0.0))
	f.fertilizer_overflow = clampf(over, 0.0, OVERFLOW_MAX) if is_finite(over) else 0.0
	f.mature = bool(d.get("mature", false))
	f.failed = bool(d.get("failed", false))
	return f

func to_dict() -> Dictionary:
	return {
		"kind": str(kind),
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"crop_id": str(crop_id),
		"growth": growth,
		"watered": watered,
		"fertilizer": fertilizer,
		"fertilizer_overflow": fertilizer_overflow,
		"mature": mature,
		"failed": failed,
		"x": global_position.x,
		"z": global_position.z,
	}

func pack_up(player: Player) -> bool:
	return BuildPlacer.pack_up_node(self, player)

# ASSUMPTION: a planted field refuses so seeds, water and fertiliser are never silently lost.
# A harvested field can hold overflow fertiliser (bonus units past the yield): that is stored goods
# like a basket's contents, so it packs up with the kit instead of being dropped.
func pack_up_block_reason() -> String:
	if crop_id != &"":
		return "Harvest or clear the field first"
	return ""

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)

func _ready() -> void:
	add_to_group("placed_building")
	add_to_group("field")
	add_to_group(str(kind))
	if get_node_or_null("Shape") == null and get_node_or_null("Prop") == null and get_node_or_null("FallbackMesh") == null:
		PropVisuals.apply_building_visual(self, kind, _fallback_size(), Color(0.35, 0.28, 0.16))
	set_process(true)

func _exit_tree() -> void:
	if World.runtime == null:
		return
	var grid: Variant = World.runtime.get("build_grid")
	if grid is BuildGrid:
		(grid as BuildGrid).release(self)

func _process(delta: float) -> void:
	_vis_left -= delta
	if _vis_left <= 0.0:
		_vis_left = VIS_S
		sync_visual()
	if crop_id == &"" or mature or failed:
		return
	var crop := _crop_row(crop_id)
	if crop.is_empty():
		return
	var need := maxf(1.0, float(crop.get("growth_seconds", 120.0)))
	growth = minf(1.0, growth + delta / need)
	if growth >= 1.0:
		_roll_maturity()

func advance_offline(seconds: float) -> void:
	if crop_id == &"" or mature or failed or seconds <= 0.0:
		return
	var crop := _crop_row(crop_id)
	if crop.is_empty():
		return
	var need := maxf(1.0, float(crop.get("growth_seconds", 120.0)))
	growth = minf(1.0, growth + seconds / need)
	if growth >= 1.0:
		_roll_maturity()

func radial_options(player: Player) -> Array:
	var opts: Array = []
	if crop_id == &"":
		for cid in _crop_ids():
			var row := _crop_row(StringName(cid))
			var seed_id := StringName(str(row.get("seed", "")))
			var blocked := ""
			if player and player.inventory.find_first(seed_id) < 0:
				blocked = "needs %s" % seed_id
			var farm_min := int(row.get("farming_min", 1))
			if player and player.skills and player.skills.level_of("farming") < farm_min:
				blocked = "farming %d" % farm_min
			opts.append({
				"item": seed_id,
				"min": 1, "max": 1,
				"tool": "none",
				"seconds": 1.0,
				"action": "plant",
				"crop": cid,
				"blocked_reason": blocked,
			})
	else:
		opts.append({
			"item": &"water_bucket",
			"min": 1, "max": 1,
			"tool": "none",
			"seconds": 1.0,
			"action": "water",
			"blocked_reason": "" if (player and player.inventory.find_first(&"water_bucket") >= 0) else "needs water_bucket",
		})
		opts.append({
			"item": &"fruit_fertilizer",
			"min": 1, "max": 1,
			"tool": "none",
			"seconds": 1.0,
			"action": "fertilize",
			"blocked_reason": "" if (player and player.inventory.find_first(&"fruit_fertilizer") >= 0) else "needs fruit_fertilizer",
		})
		if mature and not failed:
			var out_id := StringName(str(_crop_row(crop_id).get("output", crop_id)))
			opts.append({
				"item": out_id,
				"min": 1, "max": 4,
				"tool": "none",
				"seconds": 1.2,
				"action": "harvest",
				"blocked_reason": "",
			})
		elif failed:
			opts.append({
				"item": &"mud",
				"min": 1, "max": 1,
				"tool": "none",
				"seconds": 0.8,
				"action": "clear",
				"blocked_reason": "",
			})
	return opts

func apply_action(player: Player, opt: Dictionary) -> void:
	var action := str(opt.get("action", ""))
	match action:
		"plant":
			_plant(player, StringName(str(opt.get("crop", ""))))
		"water":
			_water(player)
		"fertilize":
			_fertilize(player)
		"harvest":
			_harvest(player)
		"clear":
			_clear_crop()
	sync_visual()

func _plant(player: Player, crop: StringName) -> void:
	if crop_id != &"" or crop == &"":
		return
	var row := _crop_row(crop)
	var seed_id := StringName(str(row.get("seed", "")))
	if not player.inventory.consume(seed_id, 1):
		print("[farm] plant blocked: needs %s" % seed_id)
		return
	crop_id = crop
	growth = 0.0
	watered = 0.0
	failed = false
	mature = false
	fertilizer = fertilizer_overflow
	fertilizer_overflow = 0.0
	print("[farm] planted %s fert=%.1f" % [crop, fertilizer])
	if player.skills:
		player.skills.add_xp("farming", 4)

func _water(player: Player) -> void:
	if crop_id == &"":
		return
	if not player.inventory.consume(&"water_bucket", 1):
		print("[farm] water blocked")
		return
	# Return the empty bucket; with no room for it, undo the pour instead of destroying the bucket.
	if player.inventory.add(ItemStack.make(&"empty_bucket", 1)) > 0:
		player.inventory.add(ItemStack.make(&"water_bucket", 1))
		player.notice("Your bag has no room for the empty bucket")
		print("[farm] water blocked: bag full")
		return
	watered += 1.0
	print("[farm] watered amount=%.0f" % watered)

func _fertilize(player: Player) -> void:
	if crop_id == &"":
		return
	if not player.inventory.consume(&"fruit_fertilizer", 1):
		print("[farm] fertilize blocked")
		return
	fertilizer += 1.0
	print("[farm] fertilized amount=%.1f" % fertilizer)

func _harvest(player: Player) -> void:
	if not mature or failed or crop_id == &"":
		return
	var row := _crop_row(crop_id)
	var out_id := StringName(str(row.get("output", crop_id)))
	var base_y := int(row.get("base_yield", 2))
	var bonus := int(floor(fertilizer * float(_farm_cfg().get("fertilizer_yield_bonus", 1.0))))
	var used_fert := float(bonus) # ASSUMPTION: each yield bonus unit consumes 1 fertilizer.
	var leftover := maxf(0.0, fertilizer - used_fert)
	var count := maxi(1, base_y + bonus)
	var farm_lvl := 1
	if player.skills:
		farm_lvl = maxi(1, player.skills.level_of("farming"))
	var stack := ItemStack.make(out_id, count)
	stack.level = clampi(farm_lvl, 1, farm_lvl) # capped by farming skill
	# A full bag leaves the crop standing; it used to vanish into a refused add().
	if not BuildPlacer.fits_in_bag(player.inventory, [stack]):
		player.notice("Your bag has no room for the harvest")
		print("[farm] harvest blocked: bag full")
		return
	fertilizer_overflow = leftover
	player.inventory.add(stack)
	print("[farm] harvest %s x%d lv%d overflow=%.1f" % [out_id, count, stack.level, fertilizer_overflow])
	if player.skills:
		player.skills.add_xp("farming", 8)
	_clear_crop()

func _clear_crop() -> void:
	crop_id = &""
	growth = 0.0
	watered = 0.0
	fertilizer = 0.0
	mature = false
	failed = false

func _roll_maturity() -> void:
	var cfg := _farm_cfg()
	var chance := float(cfg.get("base_success", 0.55)) + watered * float(cfg.get("water_bonus_per_unit", 0.12))
	chance = minf(float(cfg.get("max_success", 0.95)), chance)
	if randf() <= chance:
		mature = true
		failed = false
		print("[farm] mature %s chance=%.2f" % [crop_id, chance])
	else:
		mature = false
		failed = true
		print("[farm] failed %s chance=%.2f" % [crop_id, chance])

# --- what the field shows ---

## "" (empty), "sprout", "young", "growing", "mature" or "failed".
func crop_stage() -> String:
	if crop_id == &"":
		return ""
	if failed:
		return "failed"
	if mature:
		return "mature"
	return "sprout" if growth < 0.25 else ("young" if growth < 0.6 else "growing")

## Seconds until the crop is grown (0 when grown or empty).
func seconds_left() -> float:
	if crop_id == &"" or mature or failed:
		return 0.0
	return maxf(0.0, (1.0 - growth) * maxf(1.0, float(_crop_row(crop_id).get("growth_seconds", 120.0))))

## The floating line over the field: "4m 13s", "45s", "Ready", "Failed", "" when empty.
func timer_text() -> String:
	match crop_stage():
		"":
			return ""
		"mature":
			return "Ready"
		"failed":
			return "Failed"
	return duration_text(ceili(seconds_left()))

static func duration_text(secs: int) -> String:
	return "%dm %02ds" % [secs / 60, secs % 60] if secs >= 60 else "%ds" % secs

func sync_visual() -> void:
	if not is_inside_tree():
		return
	if _timer_label == null:
		_timer_label = StationState.floating_label("HarvestTimer", 1.1)
		add_child(_timer_label)
	var t := timer_text()
	_timer_label.text = t
	_timer_label.visible = t != ""
	var stage := crop_stage()
	var key := "%s/%s/%d" % [crop_id, stage, int(growth * 10.0)]
	if key == _shown_stage:
		return
	_shown_stage = key
	_build_crop(stage)

## Rows of plants over the soil, their size following growth; mature ones carry a crop-coloured head.
func _build_crop(stage: String) -> void:
	if _crop_root != null:
		remove_child(_crop_root)
		_crop_root.queue_free()
		_crop_root = null
	if stage == "":
		return
	_crop_root = Node3D.new()
	_crop_root.name = "Crop"
	add_child(_crop_root)
	var n := 3 if kind == &"field_small" else 4
	var span := (1.4 if kind == &"field_small" else 2.4) / float(n)
	var g := 1.0 if stage == "mature" else (0.45 if stage == "failed" else clampf(growth, 0.08, 1.0))
	var leaf := Color("#5e8f36") if stage != "failed" else Color("#7a5a32")
	var head_col := Color(str(_crop_row(crop_id).get("color", "#d9b25a")))
	var stem_mat := _mat(leaf)
	var head_mat := _mat(head_col)
	for ix in n:
		for iz in n:
			var plant := Node3D.new()
			plant.position = Vector3((float(ix) - float(n - 1) * 0.5) * span, SOIL_Y, (float(iz) - float(n - 1) * 0.5) * span)
			var h := lerpf(0.06, 0.55, g) * (0.85 + 0.3 * float((ix * 7 + iz * 3) % 5) / 4.0)
			var stem := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.01
			cone.bottom_radius = lerpf(0.04, 0.09, g)
			cone.height = h
			cone.radial_segments = 6
			stem.mesh = cone
			stem.position.y = h * 0.5
			stem.material_override = stem_mat
			plant.add_child(stem)
			if stage == "mature" or (stage == "growing" and g > 0.75):
				var head := MeshInstance3D.new()
				var ball := SphereMesh.new()
				ball.radius = 0.07 if stage == "mature" else 0.04
				ball.height = ball.radius * 2.4
				ball.radial_segments = 8
				ball.rings = 4
				head.mesh = ball
				head.position.y = h
				head.material_override = head_mat
				plant.add_child(head)
			if stage == "failed":
				plant.rotation_degrees = Vector3(55.0, float((ix * 47 + iz * 31) % 360), 0.0)
			_crop_root.add_child(plant)

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

func _fallback_size() -> Vector3:
	return Vector3(2.0, 0.2, 2.0) if kind == &"field_small" else Vector3(3.0, 0.2, 3.0)

static func _farm_cfg() -> Dictionary:
	_ensure()
	return _data

static func _crop_row(id: StringName) -> Dictionary:
	_ensure()
	var crops: Dictionary = _data.get("crops", {})
	var row: Variant = crops.get(str(id), {})
	return row as Dictionary if row is Dictionary else {}

static func _crop_ids() -> Array:
	_ensure()
	return (_data.get("crops", {}) as Dictionary).keys()

static func _ensure() -> void:
	if not _data.is_empty():
		return
	if not FileAccess.file_exists(DATA_PATH):
		_data = {"crops": {}, "base_success": 0.55}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_data = parsed as Dictionary
