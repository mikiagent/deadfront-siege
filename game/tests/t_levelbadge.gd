extends SceneTree
## LEVELBADGE acceptance (owner 2026-10-28): "the level gets more impressive looking as it gets closer to
## 60 ... Remove the black box background, give the ui border/boundaries so they look good without the
## black box. (same treatment to the minimap)", "move the exhaustion level emoji on top of the bar like a
## sticker", "add the x and y coordinates to the bottom of the minimap".
## - the badge tier climbs with level: 1 < 20 < 40 < 58 < 60, each tier reaching further (spikes, glow);
## - the HUD draws the badge top-left, on screen, left of the bars, at that tier (1600x900 and 844x390);
## - no backdrop panel behind the vitals or the minimap;
## - the exhaustion face rides the belt at the strain marker;
## - "X n  Y n" under the map is her world X / Z in whole metres and follows her.
## Usage: godot --headless --path game --script res://tests/t_levelbadge.gd -> "[t_levelbadge] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _hud
var _world: Node
const LEVELS := [1, 20, 40, 58, 60]

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
	print("[t_levelbadge] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_world = root.get_node("World")
	var B: GDScript = load("res://scripts/ui/hud_level_badge.gd")
	var tiers: Array = LEVELS.map(func (l: int) -> int: return B.tier_of(l))
	var rising := true
	for i in range(1, tiers.size()):
		rising = rising and tiers[i] > tiers[i - 1]
	_expect(rising and tiers[0] == 0 and tiers[-1] == B.TIER_FROM.size() - 1, "tiers climb with level %s -> %s, the cap is the top tier" % [LEVELS, tiers])
	_expect(B.tier_of(B.MAX_LEVEL) == B.TIER_FROM.size() - 1 and B.MAX_LEVEL == 60, "level cap 60 is the top tier")
	var src := FileAccess.get_file_as_string("res://scripts/ui/hunt_hud.gd")
	_expect(not src.contains("draw_rect(vitals, UiTokens.INK)"), "no dark panel drawn behind the vitals")
	_expect(not src.contains("c.draw_rect(Rect2(Vector2.ZERO, c.size)") and not src.contains("var cover :="), "no square box or corner covers on the minimap")
	_host = Node3D.new()
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("hands_spot"):
			_hud = c
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	var was_size: Vector2i = root.size
	var was_scale: Vector2i = root.content_scale_size
	for size in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = size
		root.content_scale_size = size
		await _test_hud(Vector2(size), B)
	root.size = was_size
	root.content_scale_size = was_scale
	if _fails.is_empty():
		print("[t_levelbadge] PASS")
		quit(0)
	else:
		print("[t_levelbadge] FAIL count=%d" % _fails.size())
		quit(1)

func _test_hud(view: Vector2, B: GDScript) -> void:
	var tag := "%dx%d" % [view.x, view.y]
	var last_reach := 0.0
	for shown: int in LEVELS:
		_world.pioneer_level = shown - 1
		_hud.queue_redraw()
		await _frames(3)
		var br: Rect2 = _hud.level_badge_rect
		var hp: Rect2 = _hud.hp_bar_rect
		_expect(_hud.level_badge_tier == B.tier_of(shown), "%s Lv %d draws tier %d (got %d)" % [tag, shown, B.tier_of(shown), _hud.level_badge_tier])
		_expect(br.position.x >= 0.0 and br.position.y >= 0.0, "%s Lv %d badge stays on screen (%s)" % [tag, shown, br])
		_expect(br.get_center().x < hp.position.x and br.get_center().y < hp.end.y + 40.0, "%s Lv %d badge sits top-left of the bars (%s / %s)" % [tag, shown, br, hp])
		_expect(br.size.x >= last_reach, "%s Lv %d badge reaches at least as far as the tier below (%.0f)" % [tag, shown, br.size.x])
		last_reach = br.size.x
	_expect(last_reach > B.R * 2.0 + 20.0, "%s the Lv 60 badge reaches past its ring (spikes, glow)" % tag)
	var vit: Rect2 = _hud.drawn_blocks.get("vitals", Rect2())
	_expect(vit.encloses(_hud.hp_bar_rect) and vit.position.x <= _hud.level_badge_rect.get_center().x, "%s the vitals block holds badge and bars (%s)" % [tag, vit])
	# The sticker: the face sits on the belt at the strain marker.
	var p = _hud.player
	p.vitals.fatigue = p.vitals.max_fatigue * 0.5
	_hud.queue_redraw()
	await _frames(3)
	var st: Rect2 = _hud.exhaust_sticker_rect
	var belt: Rect2 = load("res://scripts/ui/exhaust_treadmill.gd").last_rect
	var mk: Rect2 = load("res://scripts/ui/exhaust_treadmill.gd").marker_rect
	_expect(st.intersects(belt) and absf(st.get_center().y - belt.get_center().y) < 1.0, "%s the face rides the belt (%s on %s)" % [tag, st, belt])
	_expect(absf(st.get_center().x - mk.get_center().x) < 1.0, "%s the face sits at the strain marker (%.0f vs %.0f)" % [tag, st.get_center().x, mk.get_center().x])
	# Buff row (owner): bigger black-and-white chips; a blue up arrow for a buff, a red down arrow for a debuff.
	var RW: GDScript = load("res://scripts/ui/hud_buff_row.gd")
	for id: StringName in [&"caffeinated", &"dirty"]:
		p.statuses.apply(id)
	_hud.queue_redraw()
	await _frames(3)
	var row = _hud._buff_row
	_expect(row.chips.has("caffeinated") and row.chips.has("dirty"), "%s a buff and a debuff show in the row (%s)" % [tag, row.chips.keys()])
	for k in row.chips:
		var cr: Rect2 = row.chips[k]
		_expect(cr.size.x >= 38.0 and cr.size.y >= 38.0, "%s chip %s is larger (%s, was 26)" % [tag, k, cr.size])
		var tr: Rect2 = row.touch_rect(k)
		_expect(not TOK_compact(view) or (tr.size.x >= 64.0 and tr.size.y >= 64.0), "%s chip %s touch area >= 64 px" % [tag, k])
	_expect(RW.UP_BLUE.b > RW.UP_BLUE.r and RW.DOWN_RED.r > 0.8 and RW.DOWN_RED.b < 0.4, "arrows: buff blue, debuff red")
	row.toggle("dirty")
	_hud.queue_redraw()
	await _frames(2)
	_expect(row.tooltip_rect.has_area(), "%s a tap still pins the chip's tooltip" % tag)
	row.toggle("dirty")
	# Stomach (owner): the ring leads the buff row, chip-sized.
	var ring: Rect2 = _hud.stomach_rect
	var first_chip := Rect2()
	for k in row.chips:
		first_chip = row.chips[k] if not first_chip.has_area() or row.chips[k].position.x < first_chip.position.x else first_chip
	_expect(absf(ring.size.y - RW.CHIP) < 1.0 and absf(ring.get_center().y - first_chip.get_center().y) < 1.0 and ring.end.x <= first_chip.position.x, "%s the stomach ring leads the buff row (%s before %s)" % [tag, ring, first_chip])
	_expect(ring.position.y > _hud.hp_bar_rect.end.y + 20.0, "%s the ring is no longer beside the health bar" % tag)
	# Ghost trail (owner: Pokémon-style): a loss drops the fill, the pale ghost holds then eases down; a gain leads with the ghost.
	var v = p.vitals
	v.health = v.effective_max_health()
	await _frames(20)
	v.health = v.effective_max_health() * 0.5
	await _frames(2)
	var t0: Vector3 = _hud.bar_trail[&"hp"]
	_expect(absf(t0.x - 0.5) < 0.01 and t0.y > 0.97, "%s damage: the fill drops at once, the ghost holds (%s)" % [tag, t0])
	await create_timer(1.6).timeout
	await _frames(2)
	var t1: Vector3 = _hud.bar_trail[&"hp"]
	_expect(t1.y < 0.53, "%s after the hold the ghost eases down to the fill (%s)" % [tag, t1])
	v.health = v.effective_max_health()
	await _frames(2)
	var t2: Vector3 = _hud.bar_trail[&"hp"]
	_expect(t2.y > 0.99 and t2.x < 0.9, "%s heal: the ghost leads, the fill eases up (%s)" % [tag, t2])
	await create_timer(1.6).timeout
	await _frames(2)
	_expect((_hud.bar_trail[&"hp"] as Vector3).x > 0.99, "%s the fill reaches the healed value" % tag)
	# Coordinates: world X / Z in whole metres, following her.
	for d in [Vector3.ZERO, Vector3(12.4, 0, -7.6)]:
		p.global_position += d
		_hud.queue_redraw()
		await _frames(2)
		var want := "X %d  Y %d" % [roundi(p.global_position.x), roundi(p.global_position.z)]
		_expect(_hud.map_xy_text == want, "%s map coordinates read \"%s\" (got \"%s\")" % [tag, want, _hud.map_xy_text])
	var mt: Rect2 = _hud.drawn_blocks.get("map_text", Rect2())
	var mp: Vector2 = _hud._minimap.position
	_expect(mt.position.y > mp.y + _hud.MAP_PX and mt.position.x >= mp.x - 1.0 and mt.end.x <= mp.x + _hud.MAP_PX + 1.0, "%s coordinates hang under the map (%s)" % [tag, mt])

func TOK_compact(view: Vector2) -> bool:
	return load("res://scripts/ui/ui_tokens.gd").is_compact(view)
