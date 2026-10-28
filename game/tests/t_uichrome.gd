extends SceneTree
## UICHROME: one shared §8 sheet chrome. Every way a sheet gets its header (a SheetChrome instance,
## SheetChrome.build(), the UiWorldSheet base) yields the same SheetChrome: 88 / 64 px band, thin ‹
## and ✕ glyphs as 64 px targets inside the view, title / counter / right slot not colliding; and no
## other UI script draws its own torn header edge.
## Run: Godot --headless --path game --script res://tests/t_uichrome.gd -> "[t_uichrome] PASS".

const WATCHDOG_S := 60.0
const VIEWS := [Vector2(1600, 900), Vector2(844, 390)]

var _fails: PackedStringArray = []
var _started := false
var _elapsed := 0.0
var _host: Control

func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > WATCHDOG_S:
		print("[t_uichrome] FAIL watchdog: %.0f s without finishing" % _elapsed)
		quit(1)
		return true
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_uichrome] FAIL %s" % what)

func _run() -> void:
	_host = Control.new()
	root.add_child(_host)
	for view: Vector2 in VIEWS:
		_test_header(view)
		_test_build(view)
	await _test_world_sheet()
	_test_single_source()
	if _fails.is_empty():
		print("[t_uichrome] PASS")
		quit(0)
	else:
		print("[t_uichrome] FAIL count=%d" % _fails.size())
		quit(1)

func _check(c: SheetChrome, view: Vector2, tag: String) -> void:
	var want := 64.0 if UiTokens.is_compact(view) else 88.0
	_expect(is_equal_approx(c.size.y, want), "%s %s: header band is %.0f px (want %.0f)" % [tag, view, c.size.y, want])
	var vr := Rect2(Vector2.ZERO, view)
	for b: Button in [c.back, c.close]:
		_expect(b is SheetChrome.Glyph, "%s %s: %s is the shared thin glyph" % [tag, view, b.name])
		_expect(b.size.x >= 64.0 and b.size.y >= 64.0, "%s %s: %s is a 64 px target (%s)" % [tag, view, b.name, b.size])
		_expect(vr.encloses(b.get_global_rect()), "%s %s: %s is on screen" % [tag, view, b.name])
	_expect(c.title.get_global_rect().end.x <= c.close.get_global_rect().position.x, "%s %s: title stays left of ✕" % [tag, view])

func _test_header(view: Vector2) -> void:
	var c := SheetChrome.new("Animals")
	_host.add_child(c)
	c.add_tab("Pack", true)
	c.counter.text = "Bonded 2 / 3   (grows to 7)"
	c.layout(view)
	_check(c, view, "instance")
	var cr := c.counter.get_global_rect()
	_expect(cr.size.x > 40.0 and cr.end.x <= c.close.position.x and cr.position.x >= c.title.get_global_rect().end.x, "instance %s: counter sits between title and ✕ (%s)" % [view, cr])
	_expect(c.tabs.get_child(0).get_meta("active", false) == true, "instance %s: the active tab keeps its GOLD underline" % view)
	c.free()

func _test_build(view: Vector2) -> void:
	var host := Control.new()
	_host.add_child(host)
	var parts := SheetChrome.build(host, "Skills")
	var pill := Label.new()
	pill.text = "SP 3 free"
	(parts["right"] as Control).add_child(pill)
	SheetChrome.fit(parts, view, Vector4.ZERO)
	var c: SheetChrome = parts["header"]
	_check(c, view, "build")
	var body: Control = parts["body"]
	_expect(body.position.y >= c.size.y + UiTokens.TORN_MAX - 0.5, "build %s: the body starts under the torn edge" % view)
	var pr := (parts["right"] as Control).get_global_rect()
	_expect(pr.size.x >= pill.get_combined_minimum_size().x - 0.5 and pr.end.x <= c.close.position.x, "build %s: the right slot fits its content left of ✕ (%s)" % [view, pr])
	host.free()

func _test_world_sheet() -> void:
	var s := UiWorldSheet.new("Domain")
	_host.add_child(s)
	await process_frame
	_expect(s.header is SheetChrome and s.back_btn == s.header.back and s.close_btn == s.header.close, "UiWorldSheet's header is the shared SheetChrome")
	s.set_counter("Guides [color=#f4c430]0[/color] / 3")
	_expect(s.counter.get_parent() == s.header.right and s.counter.custom_minimum_size.x > 40.0, "UiWorldSheet's rich counter sits in the right slot")
	var hits := [0, 0]
	s.back_pressed.connect(func () -> void: hits[0] += 1)
	s.close_pressed.connect(func () -> void: hits[1] += 1)
	s.back_btn.pressed.emit()
	s.close_btn.pressed.emit()
	_expect(hits == [1, 1], "UiWorldSheet relays ‹ and ✕ (%s)" % [hits])
	s.free()

## The torn header edge has one home: nothing else under scripts/ui draws it.
func _test_single_source() -> void:
	var stray: PackedStringArray = []
	for path in _scripts("res://scripts/ui"):
		if path.ends_with("/sheet_chrome.gd") or path.ends_with("/ui_tokens.gd"):
			continue
		if FileAccess.get_file_as_string(path).contains("draw_torn_edge("):
			stray.append(path)
	_expect(stray.is_empty(), "only SheetChrome draws the torn header (%s)" % ", ".join(stray))

func _scripts(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
