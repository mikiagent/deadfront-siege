extends SceneTree
## STATUSFX acceptance (owner 2026-10-28: "status effects should appear next to the player as a box with
## the effect symbol inside (bleed is a claw mark, red color, and then there's some kind of particle
## effect or overlay, and it shows red negative numbers for the bleed tick damage)"), on the home island
## at 844x390 and 1600x900:
##   bleed gives a box with the claw icon beside the survivor (within NEAR_PX of her figure, level with
##   it), inside the screen, off every other HUD rect and off her; bleed and venom stack without overlap;
##   each bleed tick adds exactly one red "-N" float equal to the Health it took, and pulses the
##   vignette; drip particles and the red vignette exist while she bleeds and are gone once it is
##   treated; every status's fx block parses (colour, icon, preset).
## Usage: godot --headless --path game --script res://tests/t_statusfx.gd -> "[t_statusfx] PASS", exit 0/1.

const NEAR_PX := 24.0

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _world: Node
var SFX: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_statusfx] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	SFX = load("res://scripts/ui/status_fx.gd")
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TStatusFxHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("hands_spot"):
			_hud = c
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # statuses tick only when the test says so
	_test_data()
	var was_size: Vector2i = root.size
	var was_scale: Vector2i = root.content_scale_size
	for size in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = size
		root.content_scale_size = size
		await _test_at(Vector2(size))
	root.size = was_size
	root.content_scale_size = was_scale
	if _fails.is_empty():
		print("[t_statusfx] PASS")
		quit(0)
	else:
		print("[t_statusfx] FAIL count=%d" % _fails.size())
		quit(1)

func _test_data() -> void:
	var data: Node = root.get_node("Data")
	var bleed = data.status(&"bleed")
	_expect(bleed != null and bleed.fx_icon == &"claw" and bleed.fx_vignette and bleed.fx_particles == &"drip", "bleed's fx block: claw icon, drip particles, vignette")
	_expect(bleed != null and bleed.fx_color.r > 0.7 and bleed.fx_color.g < 0.4, "bleed is red (%s)" % [bleed.fx_color if bleed else null])
	var icons: GDScript = load("res://scripts/ui/ui_icons.gd")
	_expect(str(icons.path_for(&"claw")).ends_with("/claw.svg") and icons.icon(&"claw") != null, "the claw icon is in the white set")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/statuses.json"))
	for s in (parsed as Dictionary).get("statuses", []):
		var fx: Variant = s.get("fx")
		var def = data.status(StringName(str(s["id"])))
		_expect(fx is Dictionary and def != null and str(fx.get("color", "")).begins_with("#")
			and str(fx.get("particles", "")) in ["drip", "bubbles", "embers", "tint", "none"]
			and icons.path_for(def.fx_icon) != "", "%s has an fx block with a colour, a preset and an icon" % s["id"])

func _test_at(view: Vector2) -> void:
	var tag := "%dx%d" % [view.x, view.y]
	var sx = _hud.get("_status_fx")
	_player.statuses.from_array([])
	_player.vitals.health = _player.vitals.effective_max_health()
	await _frames(3)
	_expect(sx.boxes.is_empty() and sx.emitters.is_empty() and sx.vignette_alpha == 0.0, "%s nothing shows without a status" % tag)
	_player.statuses.apply(&"bleed")
	await _frames(4)
	var fig: Rect2 = _hud.figure_rect()
	_expect(fig.has_area(), "%s the survivor is on screen (%s)" % [tag, fig])
	var box: Rect2 = sx.boxes.get(&"bleed", Rect2())
	_expect(box.has_area(), "%s bleed shows a box (%s)" % [tag, box])
	var gap := box.position.x - fig.end.x if box.position.x >= fig.end.x else fig.position.x - box.end.x
	_expect(gap >= 0.0 and gap <= NEAR_PX, "%s the box sits beside her, %.0f px off her figure" % [tag, gap])
	_expect(box.position.y < fig.end.y and box.end.y > fig.position.y, "%s the box is level with her (box %s, figure %s)" % [tag, box, fig])
	_check_clear(view, tag + " bleed")
	# Particles and the vignette while she bleeds.
	var drip = _player.get_node_or_null("StatusFx_bleed")
	_expect(drip is CPUParticles3D and drip.emitting and drip.amount <= 12, "%s drip particles run on her (%s)" % [tag, drip])
	_expect(sx.vignette_alpha > 0.0, "%s the red vignette shows while she bleeds" % tag)
	# Ticks: one red number each, equal to the Health the tick took.
	for i in 3:
		var before := _ticks(_hud.get("_events").player_floats)
		var hp: float = _player.vitals.health
		_player.statuses._dot(_player.statuses.get_instance(&"bleed"))
		var took: float = hp - _player.vitals.health
		var after := _ticks(_hud.get("_events").player_floats)
		_expect(after.size() == before.size() + 1, "%s tick %d adds one number (%d -> %d)" % [tag, i, before.size(), after.size()])
		if after.size() == before.size() + 1:
			var f: Dictionary = after[after.size() - 1]
			_expect(str(f["txt"]) == SFX.dot_text(took) and str(f["txt"]).begins_with("-"), "%s tick %d reads %s for %.2f Health" % [tag, i, f["txt"], took])
			var col: Color = f["col"]
			_expect(col.r > 0.8 and col.g < 0.4 and col.b < 0.4, "%s tick numbers are red" % tag)
			_expect(int(f["px"]) < 22, "%s a tick number is smaller than a hit's (%d px)" % [tag, int(f["px"])])
		await _frames(1)
		_expect(sx.vignette_alpha > 0.15, "%s the vignette pulses on the tick (%.2f)" % [tag, sx.vignette_alpha])
	# A second status stacks under the first.
	_player.statuses.apply(&"venom")
	await _frames(4)
	var a: Rect2 = sx.boxes.get(&"bleed", Rect2())
	var b: Rect2 = sx.boxes.get(&"venom", Rect2())
	_expect(a.has_area() and b.has_area() and not a.intersects(b), "%s bleed and venom boxes stack without overlap (%s, %s)" % [tag, a, b])
	_expect(is_equal_approx(a.position.x, b.position.x) and b.position.y > a.position.y, "%s the second box stacks under the first" % tag)
	_expect(_player.get_node_or_null("StatusFx_venom") is CPUParticles3D, "%s venom bubbles run too" % tag)
	_check_clear(view, tag + " bleed+venom")
	# Treated: everything goes.
	_player.statuses.clear_id(&"bleed")
	_player.statuses.clear_id(&"venom")
	await _frames(3)
	_expect(sx.boxes.is_empty(), "%s no box once treated" % tag)
	_expect(sx.emitters.is_empty() and _player.get_node_or_null("StatusFx_bleed") == null and _player.get_node_or_null("StatusFx_venom") == null, "%s the particles are gone once treated" % tag)
	_expect(sx.vignette_alpha == 0.0, "%s the vignette is gone once treated" % tag)

func _ticks(floats: Array) -> Array:
	return floats.filter(func (f: Dictionary) -> bool: return f.get("pop", false))

## Every box inside the view, off every other HUD rect (its own column excepted) and off her figure.
func _check_clear(view: Vector2, tag: String) -> void:
	var sx = _hud.get("_status_fx")
	var taken: Array = _hud.taken_rects(PackedStringArray(["statusfx"]))
	var fig: Rect2 = _hud.figure_rect()
	var screen := Rect2(Vector2.ZERO, view)
	for id in sx.boxes:
		var b: Rect2 = sx.boxes[id]
		_expect(screen.encloses(b), "%s %s box inside the screen (%s)" % [tag, id, b])
		var hit := Rect2()
		for t: Rect2 in taken:
			if t.intersects(b) and t != fig:
				hit = t
		_expect(not hit.has_area(), "%s %s box clear of the HUD (hits %s)" % [tag, id, hit])
		_expect(not b.intersects(fig), "%s %s box clear of her figure" % [tag, id])
