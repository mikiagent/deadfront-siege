extends Node3D
## UNSTABLE ISLE lab: rolls a fresh unstable isle (docs/design/unstable-isles.md) and lands the survivor at its
## dock, its 40-minute clock running. Play: tools/unstable_isle.command, or
##   Godot --path game -- --lab=unstable_isle --skip-charcreate [--seed=N] [--template=<roster island id>]
## --template forces the template roster island (its climate, tier, spawns and size); without it the roll picks.
## ISLESHOW (--isleshow=<dir>): rolls SHOW_SET, shoots each from a top-down overview and from the landing,
## writes <dir>/isle_<n>_{top,ground}.png, summary.txt and contact_sheet.png, then quits. Run windowed off-screen:
##   Godot --path game --position 6000,3000 --resolution 1600x900 -- --lab=unstable_isle --skip-charcreate --isleshow=<dir>

const SHOW_SET := [["savannah_15", 101], ["tropical_25", 202], ["tundra_30", 303], ["desert_35", 404], ["swamp_55", 505], ["volcanic_60", 606]]

var _player: Player
var _cam: IsoCamera

func _ready() -> void:
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	(kit["nav"] as Node).visible = false
	LabKit.give(_player, &"work_axe", 1)
	LabKit.give(_player, &"stone_knife_work", 1)
	var rseed := randi() % 1000000
	var template := ""
	var show_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			rseed = int(a.substr(7))
		elif a.begins_with("--template="):
			template = a.substr(11)
		elif a.begins_with("--isleshow="):
			show_dir = a.substr(11)
	if show_dir != "":
		World.creation_pending = true  # no clocks or background rolls while shooting
		_isleshow.call_deferred(show_dir)
		return
	var id := _land(template, rseed)
	if id == "":
		push_error("[isle] no isle rolled (template %s)" % template)
		return
	var info := _info(id)
	print("[isle] %s template=%s seed=%d (replay: --seed=%d --template=%s)" % [info["name"], info["template"], rseed, rseed, info["template"]])
	_player.notice("%s: %s isle, %d landmarks. It sinks in 40:00. Replay with --seed=%d --template=%s" % [
		info["name"], info["family"], info["landmarks"].size(), rseed, info["template"]])

## Rolls the isle from `seed` (template forced when given) and loads it with the survivor at the dock.
func _land(template: String, rseed: int) -> String:
	World.drift = {}
	var surv := 30
	if template != "":
		if not World.islands.has(template) or bool((World.islands[template] as Dictionary).get("generated", false)):
			push_error("[isle] --template=%s is not a roster island" % template)
			return ""
		surv = World.route_level(StringName(template))
	var id := World.roll_drift(rseed, surv)
	if id == "":
		return ""
	if template != "":
		var t: Dictionary = World.islands[template]
		var rng := RandomNumberGenerator.new()
		rng.seed = rseed
		var share: Array = World.drift_rules().get("size_share", [0.9, 1.0])
		World.drift["template"] = template
		World.drift["climate"] = str(t.get("climate", ""))
		World.drift["tier"] = int(t.get("tier", 15))
		World.drift["size_m"] = roundi(float(t.get("size_m", 368)) * rng.randf_range(float(share[0]), float(share[1])))
		World._install_drift()
	World.load_island(self, StringName(id), Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	if World.runtime:
		_player.global_position = World.runtime.arrival_point() + Vector3.UP
	_cam._target = _player
	_cam._snap()
	return id

func _info(id: String) -> Dictionary:
	var def: Dictionary = World.def_of(StringName(id))
	var rt = World.runtime
	var marks: Array = []
	for s in rt.landmarks:
		marks.append(str((s as Dictionary).get("display", (s as Dictionary).get("type", ""))))
	var t := int(World.drift_time_left())
	return {
		"name": str(def.get("display_name", id)), "template": str(World.drift.get("template", "")),
		"seed": int(World.drift.get("seed", 0)), "family": str(def.get("shape_family", "")),
		"size": int(def.get("size_m", 0)), "tier": int(def.get("tier", 0)), "climate": str(def.get("climate", "")),
		"landmarks": marks, "timer": "%d:%02d" % [t / 60, t % 60],
		"nodes": int(rt.harvest_count), "creatures": int(rt.creature_count),
	}

func _isleshow(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var rows: Array = []
	var lines := PackedStringArray()
	for i in SHOW_SET.size():
		var id := _land(str(SHOW_SET[i][0]), int(SHOW_SET[i][1]))
		if id == "":
			lines.append("%s seed %d: NO ISLE ROLLED" % SHOW_SET[i])
			continue
		await get_tree().create_timer(2.0).timeout  # creatures spawn, foliage settles
		var info := _info(id)
		info["roll_seed"] = int(SHOW_SET[i][1])
		# The drift clock is frozen in the lab (creation_pending), so it reads the full life on landing.
		info["timer"] = "%d:00" % int(float(World.drift_rules().get("life_s", 2400)) / 60.0)
		var top := "%s/isle_%d_top.png" % [dir, i + 1]
		var ground := "%s/isle_%d_ground.png" % [dir, i + 1]
		await _overview(top)
		await _ground(ground)
		info["top"] = top
		info["ground"] = ground
		rows.append(info)
		var line := "%s | template %s | roll seed %d (isle seed %d) | %s | %d m | tier %d | %d landmarks: %s | %d nodes, %d creatures | sinks %s after landing" % [
			info["name"], info["template"], info["roll_seed"], info["seed"], info["family"], info["size"], info["tier"],
			info["landmarks"].size(), ", ".join(info["landmarks"]), info["nodes"], info["creatures"], info["timer"]]
		lines.append(line)
		print("[isleshow] ", line)
	var f := FileAccess.open("%s/summary.txt" % dir, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	await _sheet(rows, "%s/contact_sheet.png" % dir)
	print("[isleshow] DONE")
	get_tree().quit(0)

func _hide_ui(on: bool) -> void:
	for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = not on

func _marker(at: Vector3, r: float, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	s.material = mat
	m.mesh = s
	add_child(m)
	m.global_position = at + Vector3.UP * 20.0  # above canopy so the top-down camera sees it
	return m

## Top-down orthographic view of the whole isle (minimap-style): red = landing, yellow = landmarks, magenta = Rift Pool.
func _overview(path: String) -> void:
	var rt = World.runtime
	var pins: Array[Node] = [_marker(rt.arrival_point(), rt._size * 0.018, Color(1, 0.15, 0.1))]
	for s in rt.landmarks:
		var d := s as Dictionary
		var rift := str(d.get("type", "")) == "rift"
		pins.append(_marker(Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0))), rt._size * 0.012,
			Color(1, 0.2, 1) if rift else Color(1, 0.9, 0.1)))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rt._size * 1.02
	cam.far = rt._size * 3.0
	cam.position = Vector3(0.0, rt._size * 1.5, 0.0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	add_child(cam)
	# The climate fog is tuned for the 40 m play camera; from 600 m up it greys the whole isle out.
	var envs: Array[Environment] = []
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var e := (we as WorldEnvironment).environment
		if e and e.fog_enabled:
			e.fog_enabled = false
			envs.append(e)
	await _snap(cam, path)
	for e in envs:
		e.fog_enabled = true
	for p in pins:
		p.queue_free()

## The landing as the survivor arrives: low, behind the dock, looking inland.
func _ground(path: String) -> void:
	var rt = World.runtime
	var at: Vector3 = rt.arrival_point()
	var inland := Vector3(-at.x, 0.0, -at.z).normalized()
	if inland.length_squared() < 0.01:
		inland = Vector3.FORWARD
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = rt._size * 4.0
	add_child(cam)
	cam.global_position = at - inland * 9.0 + Vector3.UP * 6.0
	cam.look_at(at + inland * 40.0 + Vector3.UP * 1.5)
	await _snap(cam, path)

func _snap(cam: Camera3D, path: String) -> void:
	cam.make_current()
	_hide_ui(true)
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[isleshow] shot %s" % path)
	_hide_ui(false)
	cam.queue_free()
	_cam.make_current()

## 3 x 2 grid: overview (square crop) over the landing shot, with the isle's facts under them.
func _sheet(rows: Array, path: String) -> void:
	const W := 560
	const GH := 315
	const TXT := 200
	const PAD := 16
	var cols := 3
	var n_rows := int(ceil(rows.size() / float(cols)))
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * (W + PAD) + PAD, 70 + n_rows * (W + GH + TXT + PAD * 2))
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var title := Label.new()
	title.text = "Unstable isles: 6 rolls (overview: red = landing, yellow = landmark, magenta = Rift Pool)"
	title.position = Vector2(PAD, 18)
	title.add_theme_font_size_override("font_size", 26)
	vp.add_child(title)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var x := PAD + (i % cols) * (W + PAD)
		var y := 70 + (i / cols) * (W + GH + TXT + PAD * 2)
		var top := Image.load_from_file(str(r["top"]))
		var side := mini(top.get_width(), top.get_height())
		top = top.get_region(Rect2i((top.get_width() - side) / 2, (top.get_height() - side) / 2, side, side))
		top.resize(W, W, Image.INTERPOLATE_BILINEAR)
		var g := Image.load_from_file(str(r["ground"]))
		g.resize(W, GH, Image.INTERPOLATE_BILINEAR)
		for pair in [[top, Vector2(x, y)], [g, Vector2(x, y + W + 4)]]:
			var tr := TextureRect.new()
			tr.texture = ImageTexture.create_from_image(pair[0])
			tr.position = pair[1]
			vp.add_child(tr)
		var lab := Label.new()
		lab.position = Vector2(x, y + W + GH + 10)
		lab.size = Vector2(W, TXT)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 17)
		lab.text = "%s   (template %s, seed %d)\n%s shape, %d m, level %d, sinks %s after landing\n%d landmarks: %s\n%d resource nodes, %d creatures" % [
			r["name"], r["template"], r["roll_seed"], r["family"], r["size"], r["tier"], r["timer"],
			r["landmarks"].size(), ", ".join(r["landmarks"]), r["nodes"], r["creatures"]]
		vp.add_child(lab)
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("[isleshow] sheet %s" % path)
