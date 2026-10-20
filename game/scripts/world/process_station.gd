class_name ProcessStation
extends Node3D
## Process jobs on a placed station (drying rack, smoker, crock pot, steamer; processing.json).
## Inputs leave the bag and sit on the station; a job finishes on the wall clock (now_s), so it
## keeps running with the player 50 m away, on another island or with the game closed. Outputs wait
## on the station until collected. State is only timestamps: no ticking is needed for correctness,
## _process just advances and redraws (stage model, smoke/steam, glow, label).

const NODE_NAME := "Process"
const REDRAW_S := 0.25
const RULES_PATH := "res://data/processing.json"

static var _rules: Dictionary = {}
## Added to the wall clock: labs and tests fast-forward station jobs with it.
static var clock_skew_s: float = 0.0

var station_id: StringName = &""
var cfg: Dictionary = {}
## In order: {recipe, inputs: Array[ItemStack], queued_at, started (-1 = waiting), level, burnt, by}.
var jobs: Array[Dictionary] = []
## Finished, waiting to be collected: {recipe, stack: ItemStack}.
var outputs: Array[Dictionary] = []
## What the last collect_into moved, per item id (the COLLECT toast).
var last_collected: Dictionary = {}

var _redraw_left: float = 0.0
var _shown_stage: String = "?"
var _models: Dictionary = {}  # stage id -> PackedScene
var _fx: CPUParticles3D
var _glow: OmniLight3D
var _label: Label3D
var _label_r: float = 0.8  # metres from the station's centre to its front corner

## The clock jobs run on: wall time, so they keep going while the game is closed.
static func now_s() -> float:
	return Time.get_unix_time_from_system() + clock_skew_s

## processing.json, parsed once.
static func rules() -> Dictionary:
	if _rules.is_empty() and FileAccess.file_exists(RULES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		if parsed is Dictionary:
			_rules = parsed as Dictionary
	return _rules

static func config_for(sid: StringName) -> Dictionary:
	var st: Variant = (rules().get("stations", {}) as Dictionary).get(str(sid), {})
	return st if st is Dictionary else {}

## Seconds a job of this recipe takes on this station; 0 = the station does not run it.
static func job_seconds(sid: StringName, rid: StringName) -> float:
	var row: Variant = (config_for(sid).get("recipes", {}) as Dictionary).get(str(rid), {})
	return maxf(0.0, float((row as Dictionary).get("seconds", 0.0))) if row is Dictionary else 0.0

static func of(n: Node) -> ProcessStation:
	return n.get_node_or_null(NODE_NAME) as ProcessStation if n else null

## Called by CraftStation._ready: kinds with a processing.json row get a ProcessStation child.
static func attach_to(host: Node3D, sid: StringName) -> ProcessStation:
	var existing := of(host)
	if existing:
		return existing
	var c := config_for(sid)
	if c.is_empty():
		return null
	var ps := ProcessStation.new()
	ps.name = NODE_NAME
	ps.station_id = sid
	ps.cfg = c
	host.add_child(ps)
	return ps

func _ready() -> void:
	if cfg.is_empty():
		cfg = config_for(station_id)
	_build_fx()
	advance(now_s())
	_redraw()

func slots() -> int:
	return maxi(1, int(cfg.get("slots", 1)))

func capacity() -> int:
	return slots() + maxi(0, int(cfg.get("queue", 0)))

func running_count() -> int:
	var n := 0
	for j in jobs:
		if float(j["started"]) >= 0.0:
			n += 1
	return n

func runs(rid: StringName) -> bool:
	return job_seconds(station_id, rid) > 0.0

func is_active() -> bool:
	return running_count() > 0

## 0..1 for a job, by the station clock.
func job_progress(j: Dictionary, now: float = -1.0) -> float:
	var t := now_s() if now < 0.0 else now
	if float(j["started"]) < 0.0:
		return 0.0
	return clampf((t - float(j["started"])) / maxf(0.1, job_seconds(station_id, StringName(str(j["recipe"])))), 0.0, 1.0)

## Why `inv` cannot load one `rid` now, or "" when it can.
func refuse_reason(inv: Inventory, rid: StringName, player: Player = null) -> String:
	var rec := Crafting.recipe(rid)
	if rec.is_empty() or not runs(rid) or Crafting.station_id(rec) != str(station_id):
		return "%s does not run %s" % [str(cfg.get("label", station_id)), rid]
	if jobs.size() >= capacity():
		return "The %s is full." % str(station_id).replace("_", " ")
	if player and Crafting.progression_block(player, rec) != "":
		return Crafting.progression_block(player, rec)
	if _picks(inv, rec).is_empty():
		var missing := Crafting.missing_ingredient_name(inv, rec)
		return "No processing left on that one." if missing == "" else "Needs %s." % missing
	return ""

## Load up to `count` jobs of `rid` from the bag. Inputs leave the bag now; returns jobs loaded.
func load_from(inv: Inventory, rid: StringName, count: int = 1, player: Player = null, rng: RandomNumberGenerator = null) -> int:
	var rec := Crafting.recipe(rid)
	var loaded := 0
	var now := now_s()
	advance(now)
	while loaded < count and refuse_reason(inv, rid, player) == "":
		var picks := _picks(inv, rec)
		var levels := Crafting.consumed_levels(inv, rec, picks)
		var inputs := Crafting.consume_for_craft(inv, rec, picks)
		if inputs.is_empty():
			break
		jobs.append({
			"recipe": str(rid),
			"inputs": inputs,
			"queued_at": now,
			"started": now if running_count() < slots() else -1.0,
			"level": Crafting.crafted_level_for(rec, levels, player),
			"burnt": Crafting.rolls_burn(rec, Crafting.skill_level_for(rec, player), rng),
			"by": World.player_name if player else "",
		})
		loaded += 1
	if loaded > 0:
		print("[process] %s loaded %d x %s (%d/%d) %.0fs each" % [station_id, loaded, rid, jobs.size(), capacity(), job_seconds(station_id, rid)])
		_redraw()
	return loaded

## Default picks, with a primary that has no processing left swapped for one that has; [] when
## no valid set exists.
func _picks(inv: Inventory, rec: Dictionary) -> Array[int]:
	var picks := Crafting.default_picks(inv, rec)
	var pi := Crafting.primary_index(rec)
	if pi < picks.size() and picks[pi] >= 0 and Crafting.processing_left(rec, inv.slots[picks[pi]]) == 0:
		picks[pi] = -1
		for idx in Crafting.stacks_for_slot(inv, (rec.get("slots", []) as Array)[pi]):
			if idx not in picks and Crafting.processing_left(rec, inv.slots[idx]) != 0:
				picks[pi] = idx
				break
	if -1 in picks or not Crafting.picks_valid(inv, rec, picks):
		return []
	return picks

## Finish every job due by `now`, in time order; a freed slot starts the next waiting job at the
## moment it freed (not at the next frame), so offline catch-up matches a watched run.
func advance(now: float) -> bool:
	var did := false
	while true:
		var fi := -1
		var fend := INF
		for i in jobs.size():
			var st := float(jobs[i]["started"])
			if st < 0.0:
				continue
			var e := st + job_seconds(station_id, StringName(str(jobs[i]["recipe"])))
			if e <= now and e < fend:
				fi = i
				fend = e
		if fi < 0:
			break
		_finish(fi)
		did = true
		for j in jobs:
			if float(j["started"]) < 0.0:
				j["started"] = maxf(float(j["queued_at"]), fend)
				break
	return did

func _finish(i: int) -> void:
	var j: Dictionary = jobs[i]
	jobs.remove_at(i)
	var rec := Crafting.recipe(StringName(str(j["recipe"])))
	var inputs: Array = j["inputs"]
	var consumed: Array[ItemStack] = []
	for s in inputs:
		consumed.append(s as ItemStack)
	var out := Crafting.build_output(rec, consumed[0], int(j["level"]), consumed, bool(j.get("burnt", false)))
	if not out.is_fungible() and out.uid == "":  # in-place output keeps its identity
		out.stamp_identity("craft", str(j.get("by", "")))
	outputs.append({"recipe": str(j["recipe"]), "stack": out})
	print("[process] %s finished %s -> %s x%d lv%d" % [station_id, j["recipe"], out.def_id, out.count, out.level])

func ready_count() -> int:
	var n := 0
	for o in outputs:
		n += (o["stack"] as ItemStack).count
	return n

## Move finished outputs into `inv`; what does not fit stays on the station. XP is paid once, when
## a job's last unit leaves the station. Returns units moved; last_collected has them per item id.
func collect_into(inv: Inventory, player: Player = null) -> int:
	advance(now_s())
	var moved := 0
	last_collected = {}
	while not outputs.is_empty():
		var o: Dictionary = outputs[0]
		var s: ItemStack = o["stack"]
		var id := s.def_id
		var before := s.count
		var left := inv.add(s)
		moved += before - left
		if before > left:
			last_collected[id] = int(last_collected.get(id, 0)) + before - left
		if left > 0:
			s.count = left
			if player:
				player.notice("Bag is full: %d left on the %s." % [ready_count(), str(station_id).replace("_", " ")])
			break
		outputs.remove_at(0)
		var rec := Crafting.recipe(StringName(str(o["recipe"])))
		World.note_craft(StringName(str(o["recipe"])))
		if player:
			Crafting.grant_craft_xp(player, rec)
	if moved > 0:
		print("[process] %s collected %d" % [station_id, moved])
		_redraw()
	return moved

## Everything on the station: inputs of unfinished jobs and finished outputs.
func contents() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for j in jobs:
		for s in j["inputs"]:
			out.append(s as ItemStack)
	for o in outputs:
		out.append(o["stack"] as ItemStack)
	return out

## Why the station cannot be packed up now ("" = it can). BuildPlacer.pack_up_blocker asks this (via
## CraftStation) before it touches anything, on every pack-up path, so a refusal moves nothing and
## cancels no job, and packing up never destroys what hangs on the station.
func pack_up_block_reason() -> String:
	advance(now_s())
	var what := str(station_id).replace("_", " ")
	if not jobs.is_empty():
		return "the %s is still working: collect it when it is ready" % what
	if not outputs.is_empty():
		return "collect the %s first" % what
	return ""

func to_dict() -> Dictionary:
	var js: Array = []
	for j in jobs:
		var ins: Array = []
		for s in j["inputs"]:
			ins.append((s as ItemStack).to_dict())
		js.append({"recipe": j["recipe"], "inputs": ins, "queued_at": j["queued_at"], "started": j["started"],
			"level": j["level"], "burnt": j.get("burnt", false), "by": j.get("by", "")})
	var outs: Array = []
	for o in outputs:
		outs.append({"recipe": o["recipe"], "stack": (o["stack"] as ItemStack).to_dict()})
	return {"jobs": js, "outputs": outs}

## Restore saved jobs. Rows for recipes this station no longer runs are kept as finished outputs of
## their inputs (never deleted); a start time in the future is clamped to now.
func load_dict(d: Dictionary) -> void:
	jobs.clear()
	outputs.clear()
	var now := now_s()
	for row in d.get("jobs", []):
		if not row is Dictionary:
			continue
		var ins: Array[ItemStack] = []
		for sd in (row as Dictionary).get("inputs", []):
			if sd is Dictionary:
				var s := ItemStack.from_dict(sd)
				if s.def() != null and s.count > 0:
					ins.append(s)
		if ins.is_empty():
			continue
		var rid := StringName(str(row.get("recipe", "")))
		if not runs(rid) or Crafting.recipe(rid).is_empty():
			for s in ins:
				outputs.append({"recipe": "", "stack": s})
			continue
		var started := float(row.get("started", -1.0))
		jobs.append({
			"recipe": str(rid),
			"inputs": ins,
			"queued_at": minf(float(row.get("queued_at", now)), now),
			"started": minf(started, now) if started >= 0.0 else -1.0,
			"level": maxi(1, int(row.get("level", 1))),
			"burnt": bool(row.get("burnt", false)),
			"by": str(row.get("by", "")),
		})
	for row in d.get("outputs", []):
		if row is Dictionary and (row as Dictionary).get("stack") is Dictionary:
			var s := ItemStack.from_dict(row["stack"])
			if s.def() != null and s.count > 0:
				outputs.append({"recipe": str(row.get("recipe", "")), "stack": s})
	# Waiting jobs with a free slot (slots raised in config) start now.
	for j in jobs:
		if float(j["started"]) < 0.0 and running_count() < slots():
			j["started"] = now
	if is_inside_tree():
		advance(now)
		_redraw()

# --- presentation ---

func _process(delta: float) -> void:
	_redraw_left -= delta
	if _redraw_left > 0.0:
		return
	_redraw_left = REDRAW_S
	advance(now_s())
	_redraw()

func stage_id() -> String:
	var stages: Array = cfg.get("stages", [])
	if stages.is_empty():
		return ""
	if is_active():
		var p := 1.0
		for j in jobs:
			if float(j["started"]) >= 0.0:
				p = minf(p, job_progress(j))
		var id := ""
		for st in stages:
			if p >= float((st as Dictionary).get("at", 0.0)):
				id = str((st as Dictionary).get("id", ""))
		return id
	return str(cfg.get("ready_stage", "")) if not outputs.is_empty() else str(cfg.get("idle_stage", ""))

func _redraw() -> void:
	if not is_inside_tree():
		return
	_swap_stage(stage_id())
	var active := is_active()
	if _fx:
		_fx.emitting = active
	if _glow:
		_glow.visible = active
	if _label:
		# fixed_size text shrinks with the window; hold it near HUD size on a 390 px phone.
		_label.pixel_size = 0.0012 * clampf(900.0 / maxf(1.0, get_viewport().get_visible_rect().size.y), 1.0, 2.4)
		_label.text = label_text()
		_label.visible = _label.text != ""
		_place_label()

## Under the station, at its corner nearest the camera. Over the roof it sat in the top band a phone
## gives to the HUD (orders panel, vitals) and was hidden whenever the survivor stood beside it.
func _place_label() -> void:
	var cam := get_viewport().get_camera_3d()
	var host := get_parent() as Node3D
	if cam == null or host == null:
		return
	var toward := cam.global_basis.z * Vector3(1.0, 0.0, 1.0)
	if toward.length_squared() > 0.0001:
		_label.global_position = host.global_position + toward.normalized() * _label_r

func label_text() -> String:
	var now := now_s()
	if is_active():
		var soonest := INF
		for j in jobs:
			if float(j["started"]) >= 0.0:
				var secs := job_seconds(station_id, StringName(str(j["recipe"])))
				# A clock moved back must not show more time than the job takes.
				soonest = minf(soonest, minf(secs, float(j["started"]) + secs - now))
		var left := maxi(0, ceili(soonest))
		var t := "%d:%02d" % [left / 60, left % 60]
		var ready := "  ·  %d ready" % ready_count() if not outputs.is_empty() else ""
		return "%s %d/%d  ·  %s%s" % [str(cfg.get("label", "Working")), jobs.size(), capacity(), t, ready]
	if not outputs.is_empty():
		var first: ItemStack = outputs[0]["stack"]
		var d := first.def()
		return "Ready: %d %s" % [ready_count(), d.display_name if d else str(first.def_id)]
	return ""

## The station's own model per stage (props_manifest stages); kinds without stages keep theirs.
func _swap_stage(id: String) -> void:
	if id == "" or id == _shown_stage:
		return
	var host := get_parent() as Node3D
	var packed := _stage_scene(id)
	if host == null or packed == null:
		return
	var old := host.get_node_or_null("Prop")
	if old:
		host.remove_child(old)
		old.queue_free()
	var inst := packed.instantiate() as Node3D
	inst.name = "Prop"
	host.add_child(inst)
	_shown_stage = id

func _stage_scene(id: String) -> PackedScene:
	if _models.has(id):
		return _models[id]
	var row: Variant = (Data.props_manifest.get("buildings", {}) as Dictionary).get(str(station_id), {})
	var path := ""
	if row is Dictionary:
		for st in (row as Dictionary).get("stages", []):
			if st is Dictionary and str((st as Dictionary).get("id", "")) == id:
				path = str((st as Dictionary).get("glb", ""))
	var packed: PackedScene = load(path) as PackedScene if path != "" and ResourceLoader.exists(path) else null
	_models[id] = packed
	return packed

## Smoke or steam while a job runs, an ember glow for fired stations, and a world label.
## CPUParticles3D: the same look in Forward+ and gl_compatibility (web, phones).
func _build_fx() -> void:
	var off_v: Variant = cfg.get("fx_offset", [0.0, 1.0, 0.0])
	var off := Vector3(float(off_v[0]), float(off_v[1]), float(off_v[2])) if off_v is Array and (off_v as Array).size() >= 3 else Vector3.UP
	var kind := str(cfg.get("fx", ""))
	if kind != "":
		_fx = CPUParticles3D.new()
		_fx.name = "ProcessFx"
		_fx.position = off
		var steam := kind == "steam"
		_fx.amount = 18 if steam else 26
		_fx.lifetime = 2.2 if steam else 4.0
		_fx.preprocess = _fx.lifetime
		_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_fx.emission_sphere_radius = 0.18 if steam else 0.35
		_fx.direction = Vector3.UP
		_fx.spread = 12.0
		_fx.gravity = Vector3(0.12, 0.35 if steam else 0.2, 0.0)  # a light drift downwind
		_fx.initial_velocity_min = 0.35
		_fx.initial_velocity_max = 0.7
		_fx.scale_amount_min = 0.5
		_fx.scale_amount_max = 0.9
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.35))
		grow.add_point(Vector2(1.0, 1.6))
		_fx.scale_amount_curve = grow
		var ramp := Gradient.new()
		var c := Color(0.96, 0.97, 1.0) if steam else Color(0.55, 0.53, 0.5)
		var a := float(cfg.get("fx_alpha", 0.55 if steam else 0.5))
		ramp.set_color(0, Color(c, 0.0))
		ramp.set_color(1, Color(c, 0.0))
		ramp.add_point(0.15, Color(c, a))
		ramp.add_point(0.6, Color(c, a * 0.55))
		_fx.color_ramp = ramp
		var quad := QuadMesh.new()
		quad.size = Vector2(0.6, 0.6)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = _puff_texture()
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		quad.material = mat
		_fx.mesh = quad
		_fx.emitting = false
		add_child(_fx)
	var light := str(cfg.get("light", ""))
	if light != "":
		_glow = OmniLight3D.new()
		_glow.name = "ProcessGlow"
		_glow.light_color = Color(light)
		_glow.light_energy = 1.4
		_glow.omni_range = 2.6
		_glow.position = Vector3(0.0, 0.5, 0.0)
		_glow.visible = false
		add_child(_glow)
	_label = Label3D.new()
	_label.name = "ProcessLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 10  # over the smoke it floats in
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 32
	_label.outline_size = 14
	# Saturated: the tonemapper turns a pale yellow into beige that vanishes on grass.
	_label.modulate = Color(1.0, 0.82, 0.25)
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP  # the text hangs below its anchor
	var aabb: Variant = ((Data.props_manifest.get("buildings", {}) as Dictionary).get(str(station_id), {}) as Dictionary).get("aabb_m", [1, 1.4, 1])
	if aabb is Array and (aabb as Array).size() >= 3:
		_label_r = 0.5 * Vector2(float(aabb[0]), float(aabb[2])).length() + 0.1
	_label.visible = false
	add_child(_label)

static var _puff: Texture2D

## A soft round puff, made once: no texture file to ship.
static func _puff_texture() -> Texture2D:
	if _puff:
		return _puff
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_puff = t
	return _puff
