extends SceneTree
## CHARCREATE (spec 19): the three creation steps, the look and the portrait. Prints "[t_charcreate] PASS"
## (or FAIL lines) and exits 0/1.
##   Godot --headless --path game --script res://tests/t_charcreate.gd
## Needs the package's hooks (World.look, its save and load); it fails on the old creation screen, which
## has no live 3D preview and no skill line. Scripts that touch autoloads load on the first frame.

const RUN_DIR := "user://runs/t_charcreate"
const UI_FILES := [
	"res://scripts/ui/character_creation.gd", "res://scripts/ui/portrait_service.gd",
	"res://scripts/ui/charcreate/cc_ui.gd", "res://scripts/ui/charcreate/cc_profession_step.gd",
	"res://scripts/ui/charcreate/cc_create_step.gd", "res://scripts/ui/charcreate/cc_name_step.gd",
	"res://scripts/ui/charcreate/survivor_stage.gd",
]
const TYPE_MIN := 12

class ErrorCounter extends Logger:
	var lines: PackedStringArray = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			var where := ""
			for bt in script_backtraces:
				if bt.get_frame_count() > 0:
					where += " <- %s:%d" % [bt.get_frame_file(0), bt.get_frame_line(0)]
			lines.append("%s (%s:%d %s)%s" % [rationale if rationale != "" else code, file, line, function, where])
	func _log_message(_message: String, _error: bool) -> void:
		pass

var errors := ErrorCounter.new()
var failures: Array[String] = []
var _started := false
var W: Node
var SG: GDScript
var CCS: GDScript
var LOOK: GDScript
var PS: GDScript
var host: Node3D
var player: Node

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	OS.add_logger(errors)
	_run.call_deferred()
	return false

func _run() -> void:
	W = root.get_node("World")
	SG = load("res://scripts/core/save_game.gd")
	CCS = load("res://scripts/ui/character_creation.gd")
	LOOK = load("res://scripts/player/character_look.gd")
	PS = load("res://scripts/ui/portrait_service.gd")
	_check(str(SG.path) == RUN_DIR + "/save_1.json", "a --script run saves under %s (got %s)" % [RUN_DIR, SG.path])
	_clean()
	host = Node3D.new()
	host.name = "CcHost"
	root.add_child(host)
	player = (load("res://scripts/dev/lab_kit.gd") as GDScript).build(host)["player"]
	W.home_terrain = &"meadow"
	W.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)
	await process_frame
	if await _test_preview_and_skill_lines():
		_test_sources()
		_test_names()
		_test_look_data()
		await _test_tint()
		_test_portrait()
		await _test_layout()
		await _test_phone_fit()
		await _test_flow_and_save()
		await _test_old_save()
	_finish()

## Old code fails here: it has no live 3D preview and no "Lv. 20 <Tree>" line.
func _test_preview_and_skill_lines() -> bool:
	var cc = CCS.new()
	host.add_child(cc)
	await process_frame
	var vp: SubViewport = null
	for n in cc.find_children("*", "SubViewport", true, false):
		if (n as SubViewport).own_world_3d and not n.find_children("*", "Skeleton3D", true, false).is_empty():
			vp = n
	_check(vp != null, "creation shows a live 3D survivor (own-world SubViewport with a skinned skeleton)")
	var ap: AnimationPlayer = vp.find_children("*", "AnimationPlayer", true, false)[0] if vp and not vp.find_children("*", "AnimationPlayer", true, false).is_empty() else null
	_check(ap != null and ap.is_playing() and ap.current_animation == "idle", "the preview plays the idle clip (got %s)" % [ap.current_animation if ap else "none"])
	var lit := vp != null and vp.find_children("*", "DirectionalLight3D", true, false).any(func (l: Node) -> bool: return (l as DirectionalLight3D).shadow_enabled)
	_check(lit, "the stage has a shadow-casting key light (ground shadow)")
	if not ("profession" in cc) or cc.get("profession") == null:
		_check(false, "creation has a Gender/Profession step with a skill line (old code: none)")
		cc.free()
		return false
	var skills = load("res://scripts/skills/skill_state.gd")
	var names: Dictionary = skills.NAMES
	var rows: Array = skills.occupations()
	_check(rows.size() == 8, "occupations.json has the 8 PRD occupations (got %d)" % rows.size())
	var seen_trees := {}
	for row in rows:
		var id := str(row["id"])
		cc.select_occupation(id)
		# The rule itself: a fresh SkillState given this occupation.
		var probe = skills.new()
		probe._load()
		probe.apply_occupation(id)
		var tree := str(row["tree"])
		var want := "Lv. %d %s" % [probe.level_of(tree), names[tree]]
		probe.free()
		_check(cc.profession.skill_line.text == want, "%s: skill line %s from occupations.json (got %s)" % [id, want, cc.profession.skill_line.text])
		_check(cc.profession.title.text == str(row["name"]) and cc.profession.story.text == str(row["story"]), "%s: title and story from the data" % id)
		_check(cc.profession.rows.has(id), "%s has a row in the list" % id)
		seen_trees[tree] = true
	for banned in ["survival", "processing", "butchering", "ranged"]:
		_check(not seen_trees.has(banned), "PRD 5.1: no occupation starts in %s" % banned)
	# PRD 5.1's table words.
	var prd := {"soldier": "Soldier", "job_seeker": "Job Seeker", "office_worker": "Office Worker", "technician": "Technician", "flight_attendant": "Flight Attendant", "student": "Student", "homemaker": "Homemaker", "farmer": "Farmer"}
	for row in rows:
		_check(prd.get(str(row["id"]), "") == str(row["name"]), "%s shows the PRD's name %s (got %s)" % [row["id"], prd.get(str(row["id"]), "?"), row["name"]])
	cc.queue_free()
	await process_frame
	return true

## Type floor and no emoji in the new UI files (t_ui's rules for its owned files).
func _test_sources() -> void:
	var re := RegEx.create_from_string("font_size\",\\s*(\\d+)\\)|(?:label|yellow_button|row_button)\\([^,]+,\\s*(\\d+)")
	for path in UI_FILES:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "readable: %s" % path)
		var n := 0
		for line in text.split("\n"):
			n += 1
			for i in line.length():
				var cp := line.unicode_at(i)
				if cp >= 0x1F300 and cp <= 0x1FAFF:
					_check(false, "emoji U+%X at %s:%d" % [cp, path, n])
					break
			for m in re.search_all(line):
				var v := m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
				_check(int(v) >= TYPE_MIN, "font size %s under %d at %s:%d" % [v, TYPE_MIN, path, n])

func _test_names() -> void:
	var NS: GDScript = load("res://scripts/ui/charcreate/cc_name_step.gd")
	var ok := ["Ana", "Ana-Lu", "Dr. Ana Lu", "Zoë Ångström", "李小龍", "R2-D2", "A", "Abcdefghij Klmnopqrs"]
	# Review r1: a name needs at least one letter or digit ("-.-", "." and "- ." were accepted).
	var bad := ["", " ", " Ana", "Ana ", "Ana  Lu", "Ana_Lu", "Ana!", "Abcdefghij Klmnopqrst", "<b>x</b>", "Ana\tLu", "-.-", ".", "-", "- .", "...."]
	for nm in ok:
		_check(NS.name_error(nm) == "", "name \"%s\" is valid (got %s)" % [nm, NS.name_error(nm)])
	for nm in bad:
		_check(NS.name_error(nm) != "", "name \"%s\" is refused" % nm)

## Randomise stays inside the data; clean() refuses forged values; colour slots need a mask.
func _test_look_data() -> void:
	var data: Dictionary = LOOK.data()
	var hr: Dictionary = data["height"]
	_check(float(hr["min"]) >= 0.9 and float(hr["max"]) <= 1.1 and float(hr["min"]) < 1.0 and float(hr["max"]) > 1.0, "height range is small and data-driven (%s)" % hr)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1919
	var heights := {}
	for i in 200:
		var g: String = ["m", "f"][i % 2]
		var lk: Dictionary = LOOK.randomized(g, rng)
		heights[lk["height"]] = true
		_check(lk["gender"] == g, "the die keeps the gender")
		_check(float(lk["height"]) >= float(hr["min"]) - 1e-6 and float(lk["height"]) <= float(hr["max"]) + 1e-6, "rolled height %s inside %s" % [lk["height"], hr])
		for slot in lk["colors"]:
			_check(LOOK._in_rows(LOOK.palette(slot), lk["colors"][slot]), "rolled %s %s is in its palette" % [slot, lk["colors"][slot]])
		_check(LOOK.clean(lk) == lk, "a rolled look survives clean() unchanged")
		_check(LOOK._in_rows(LOOK.backgrounds(), lk["portrait"]["bg"]), "rolled portrait background in the data")
	_check(heights.size() > 5, "the die varies the height (%d values)" % heights.size())
	var forged: Dictionary = LOOK.clean({"gender": "x", "height": 9.0, "colors": {"skin": "#ff00ff", "outfit1": "#4a4946", "hair": "#000000"}, "parts": {"hair": "mohawk"}, "portrait": {"pattern": "nope", "bg": 7}})
	_check(forged["gender"] == "m" and is_equal_approx(float(forged["height"]), float(hr["max"])), "forged gender and height are coerced (%s)" % forged)
	_check(forged["colors"] == {"outfit1": "#4a4946"}, "only palette colours of real slots survive (%s)" % forged["colors"])
	_check(forged["parts"]["hair"] == "base_short" and forged["portrait"] == LOOK.defaults()["portrait"], "unknown part and portrait values fall back")
	_check(LOOK.clean(null) == LOOK.defaults(), "no look (an old save) is the default look")
	var slots: Array = LOOK.color_slots().map(func (s: Dictionary) -> String: return str(s["id"]))
	for want in ["skin", "outfit1", "outfit2", "outfit3", "eyes", "lips"]:
		_check(want in slots, "colour slot %s has a mask region" % want)
	_check(LOOK.kit_only("outfit3") and not LOOK.kit_only("outfit1"), "Outfit Color 3 is carried by the kits only (the base is barefoot)")
	var masks: Dictionary = LOOK.masks()
	for k in ["skin_in_outfit1", "skin_in_outfit2", "skin_in_hair"]:
		_check(int(masks["checks"][k]) == 0, "mask bake: %s is 0" % k)
	_check(int(masks["dilate_texels"]) >= 2, "masks dilated >= 2 texels")
	for p in LOOK.part_slots("m"):
		_check((p["options"] as Array).size() >= 1, "part slot %s lists the base model's own option" % p["id"])
	_check(LOOK.pickable_parts("m").is_empty(), "no part slot has two options yet: no inert picker")

## A colour reaches only meshes with a mask atlas, through the look shader; clearing it restores the material.
func _test_tint() -> void:
	var rig = player.rig
	var base_mesh: MeshInstance3D = null
	for m in rig.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).visible and (m as MeshInstance3D).get_active_material(0) is BaseMaterial3D:
			base_mesh = m
			break
	_check(base_mesh != null, "the player has a visible survivor mesh")
	if base_mesh == null:
		return
	var before := base_mesh.get_active_material(0)
	var scale0: Vector3 = rig.scale
	var lk: Dictionary = LOOK.defaults()
	lk["colors"] = {"skin": "#5c3a28", "outfit1": "#7c3f38"}
	lk["height"] = 1.05
	LOOK.apply(rig, lk)
	var sm := base_mesh.get_active_material(0) as ShaderMaterial
	_check(sm != null and sm.get_shader_parameter("tint_a2") == Color.html("#5c3a28") and sm.get_shader_parameter("tint_a0") == Color.html("#7c3f38"), "skin and outfit 1 tint their mask channels (B, R)")
	_check(sm != null and (sm.get_shader_parameter("tint_a1") as Color).a == 0.0, "an unchosen slot leaves its region as painted")
	# The lips sit outside the skin mask: without a chosen lip colour they follow the skin tone (darker
	# skin, darker lips), and a chosen lip colour wins.
	var lips_dark: Color = sm.get_shader_parameter("tint_b1") if sm else Color(0, 0, 0, 0)
	_check(lips_dark.a == 1.0 and lips_dark.get_luminance() < LOOK.painted("lips").get_luminance(), "unchosen lips follow a darker skin (%s vs painted %s)" % [lips_dark.to_html(false), LOOK.painted("lips").to_html(false)])
	_check(not lk["colors"].has("lips"), "the follow is shown only: the look keeps no lip colour")
	var lk_lips: Dictionary = lk.duplicate(true)
	lk_lips["colors"]["lips"] = "#8a514c"
	LOOK.apply(rig, lk_lips)
	_check(sm.get_shader_parameter("tint_b1") == Color.html("#8a514c"), "a chosen lip colour is used as chosen")
	LOOK.apply(rig, lk)
	_check(rig.scale.is_equal_approx(scale0 * 1.05), "height 1.05 scales the rig only (got %s from %s)" % [rig.scale, scale0])
	var body: CollisionShape3D = player.find_child("*", false, false) as CollisionShape3D
	for c in player.get_children():
		if c is CollisionShape3D:
			body = c
	_check(body == null or body.scale.is_equal_approx(Vector3.ONE), "the capsule is untouched")
	player.inventory.add((load("res://scripts/items/item_stack.gd") as GDScript).make(&"travel_shirt", 1))
	player.inventory.equip(&"body", &"travel_shirt")
	await process_frame
	var kit_tinted := false
	for m in rig.find_children("*", "MeshInstance3D", true, false):
		var mm := (m as MeshInstance3D).get_active_material(0) as ShaderMaterial
		if mm and str((mm.get_meta(&"plain") as BaseMaterial3D).albedo_texture.resource_path).contains("travel_clothes"):
			kit_tinted = mm.get_shader_parameter("tint_a0") == Color.html("#7c3f38") and mm.get_shader_parameter("tint_a3") == Color.html("#5c3a28")
	_check(kit_tinted, "a piece equipped later takes outfit 1 (chest) and the skin tone (PlayerEquipment hook)")
	player.inventory.unequip(&"body")
	LOOK.apply(rig, LOOK.defaults())
	_check(base_mesh.get_active_material(0) == before and rig.scale.is_equal_approx(scale0), "the default look restores the plain material and scale")

func _test_portrait() -> void:
	var ps = PS.shared()
	var lk: Dictionary = LOOK.defaults()
	ps.request(lk)
	var n: int = ps.renders
	_check(ps.texture() != null and ps.is_current(lk), "the portrait renders and caches")
	ps.request(lk)
	_check(ps.renders == n, "the same look does not render again")
	lk["height"] = 1.04
	ps.request(lk)
	_check(ps.renders == n, "height does not re-render the headshot")
	lk["colors"] = {"skin": "#82563b"}
	ps.request(lk)
	_check(ps.renders == n + 1 and ps.is_current(lk), "a colour change re-renders the portrait")
	lk["portrait"] = {"pattern": "checker", "bg": "#7a4a4a"}
	ps.request(lk)
	_check(ps.renders == n + 2, "a pattern or background change re-renders the portrait")
	var img: Image = ps.image
	var px := img.get_pixel(2, 2)
	var bg := Color.html("#7a4a4a")
	_check(_near(px, bg) or _near(px, bg.darkened(0.22)), "the backdrop uses the chosen colour (got %s)" % px.to_html(false))

## Both canvases fit: every control inside the view, primary targets >= 56 px and the rest >= 44 px.
func _test_layout() -> void:
	var cc = CCS.new()
	host.add_child(cc)
	await process_frame
	for view in [Vector2(844, 390), Vector2(1600, 900)]:
		for step in [0, 1, 2]:
			cc._go(step)
			cc.relayout(view, view, Vector4.ZERO)
			var tag := "%dx%d step %d" % [view.x, view.y, step]
			var shown: Control = [cc.profession, cc.create, cc.naming][step]
			var stage: Rect2 = Rect2(cc.stage.position, cc.stage.size)
			_check(stage.size.x > 120.0 and stage.size.y > 200.0 and Rect2(Vector2.ZERO, view).encloses(stage), "%s: the preview fits (%s)" % [tag, stage])
			for c in shown.find_children("*", "Control", true, false):
				var ctl := c as Control
				if not ctl.is_visible_in_tree() or not (ctl is Button or ctl is LineEdit or ctl is Slider):
					continue
				if _scrolled(ctl, shown):
					continue
				var r := Rect2(ctl.position, ctl.size)
				var p := ctl.get_parent() as Control
				while p != null and p != shown:
					r.position += p.position
					p = p.get_parent() as Control
				_check(Rect2(Vector2.ZERO, view).grow(0.5).encloses(r), "%s: %s inside the view (%s)" % [tag, ctl.name, r])
				var short := minf(r.size.x, r.size.y)
				var want := 56.0 if str(ctl.name) in ["Next", "OK", "NameField"] else 44.0
				_check(short >= want - 0.5, "%s: %s is a %d px+ target (%s)" % [tag, ctl.name, want, r.size])
	cc.queue_free()
	await process_frame

## Review r1 at 844x390: a selected row below the fold scrolls into view; every hex caption fits its
## column (two lines when one is too wide) without shrinking the hex; SaveGame's unreadable-save note
## sits under the story, set like it (left, as tight). Old code: Farmer stayed below the fold,
## "Background Color" overran the 86 px column, the note was centred with loose lines.
func _test_phone_fit() -> void:
	var cc = CCS.new()
	cc.name = "CharacterCreation"  # where SaveGame._warn_new_world looks
	host.add_child(cc)
	await process_frame
	var view := Vector2(844, 390)
	cc._go(0)
	cc.relayout(view, view, Vector4.ZERO)
	cc.select_occupation("farmer")
	await process_frame
	await process_frame
	var row: Control = cc.profession.rows["farmer"]
	var list: Rect2 = cc.profession.list_scroll.get_global_rect()
	_check(list.grow(0.5).encloses(row.get_global_rect()), "844x390: the selected Farmer row scrolls into view (row %s, list %s)" % [row.get_global_rect(), list])
	SG._warn_new_world(host, "the file is damaged", "save_1.json.corrupt-1")
	var note := cc.profession.info.get_node_or_null("SaveWarning") as Label
	var story: Label = cc.profession.story
	for size in [view, Vector2(1600, 900), view]:
		cc.relayout(size, size, Vector4.ZERO)
		await process_frame
		_check(note != null and note.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and is_equal_approx(note.get_global_rect().position.x, story.get_global_rect().position.x), "%s: the save note is left-aligned with the story" % size)
		_check(note != null and note.get_theme_constant("line_spacing") == story.get_theme_constant("line_spacing") and story.get_theme_constant("line_spacing") < 0 and note.get_theme_font_size("font_size") == story.get_theme_font_size("font_size"), "%s: the save note has the story's size and tight line spacing" % size)
	cc._go(1)
	for size in [view, Vector2(1600, 900)]:
		cc.relayout(size, size, Vector4.ZERO)
		for t in ["portrait", "appearance", "color"]:
			cc.create._set_tab(t)
			await process_frame
			var radii := {}
			for h in cc.create.sub_list.get_children():
				var font: Font = h.get_theme_default_font()
				for l in str(h.caption).split("\n"):
					var w := font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, h.caption_px).x
					_check(w <= h.size.x + 0.5, "%s %s tab: caption \"%s\" fits its %d px column (%.0f px)" % [size, t, l, h.size.x, w])
				radii[snappedf(h.hex_radius(), 0.5)] = true
			_check(radii.size() == 1, "%s %s tab: a two-line caption keeps the hex its size (radii %s)" % [size, t, radii.keys()])
	cc.queue_free()
	await process_frame

func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01

func _scrolled(c: Node, top: Node) -> bool:
	var n := c.get_parent()
	while n != null and n != top:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false

## Pick, look, name, OK: done carries (occupation, gender, name) as before, World keeps them and the
## look, and the save holds them; loading puts the look back on the player.
func _test_flow_and_save() -> void:
	W.start_new(host)
	var cc = host.get_node_or_null("CharacterCreation")
	_check(cc != null, "World.start_new opens character creation")
	if cc == null:
		return
	await process_frame
	var got: Array = []
	cc.done.connect(func (o: String, g: String, nm: String) -> void: got.append_array([o, g, nm]))
	cc.select_occupation("farmer")
	cc.profession.gender_hex.pressed.emit()
	_check(cc.look["gender"] == "f" and cc.profession.model_note.text != "", "the gender toggle flips to f and says no female model exists yet")
	cc.profession.next.pressed.emit()
	_check(cc.step == 1, "Next opens Create Character")
	var ps = PS.shared()
	var renders: int = ps.renders
	cc.create._set_tab("appearance")
	cc.create.slider.value = 1.06
	_check(is_equal_approx(float(cc.look["height"]), 1.06) and cc.stage.rig.scale.is_equal_approx((cc.stage.rig.get_meta(&"look_scale") as Vector3) * 1.06), "the height slider scales the preview")
	cc.create._set_tab("color")
	cc.create._set_sub("outfit3")
	_check(cc.stage.outfit != "", "Outfit Color 3 puts a kit on the preview so its swatches show (%s)" % cc.stage.outfit)
	cc.set_color("skin", "#6f4831")
	cc.set_color("outfit1", "#b0773f")
	_check(ps.renders > renders, "a colour change re-renders the portrait on the Create Character step")
	cc.create.next.pressed.emit()
	_check(cc.step == 2, "Next opens the Name step")
	cc.naming.field.text = "Ana  Lu"
	cc.naming.validate()
	_check(cc.naming.ok.disabled and cc.naming.error.text != "", "OK is disabled with an inline error for a double space")
	cc.naming.field.text = "Ana-Lu Quispe."
	cc.naming.validate()
	_check(not cc.naming.ok.disabled and cc.naming.error.text == "", "a valid name enables OK")
	var want_look: Dictionary = cc.look.duplicate(true)
	cc.naming.ok.pressed.emit()
	await process_frame
	_check(got == ["farmer", "f", "Ana-Lu Quispe."], "done(occupation, gender, name) as before (got %s)" % [got])
	_check(W.occupation == "farmer" and W.player_name == "Ana-Lu Quispe.", "World keeps occupation and name")
	if not ("look" in W):
		_check(false, "hooks patch not applied: World.look is missing")
		return
	_check(W.look == want_look, "World keeps the look (%s)" % [W.look])
	var p = W._player()
	_check(p.rig.scale.is_equal_approx((p.rig.get_meta(&"look_scale") as Vector3) * 1.06), "the world model takes the height")
	SG.save_now()
	var saved: Dictionary = _saved()
	_check(saved.get("occupation") == "farmer" and saved.get("player_name") == "Ana-Lu Quispe.", "the save keeps occupation and name as before")
	_check(saved.get("look") is Dictionary and is_equal_approx(float(saved["look"]["height"]), 1.06) and saved["look"]["colors"] == {"skin": "#6f4831", "outfit1": "#b0773f"} and saved["look"]["gender"] == "f", "the save keeps the look (%s)" % [saved.get("look")])
	W.look = {}
	LOOK.apply(p.rig, LOOK.defaults())
	SG.load_now(host)
	await process_frame
	p = W._player()
	_check(W.look == want_look, "loading restores the look")
	_check(p.rig.scale.is_equal_approx((p.rig.get_meta(&"look_scale") as Vector3) * 1.06), "loading puts the height back on the player")

## A save from before CHARCREATE has no "look": it loads, keeps everything, and gets the default look.
func _test_old_save() -> void:
	_clean()
	var golden := FileAccess.get_file_as_string("res://tests/fixtures/save_v3_golden.json")
	var d: Dictionary = JSON.parse_string(golden)
	_check(not d.has("look"), "the v3 golden predates the look")
	var f := FileAccess.open(SG.path, FileAccess.WRITE)
	f.store_string(golden)
	f.close()
	SG.load_now(host)
	await process_frame
	_check(SG.blocked_reason == "", "an old save loads")
	_check(W.look == LOOK.defaults(), "an old save gets the default look")
	_check(W.player_name == str(d.get("player_name", "")) and W.occupation == str(d.get("occupation", "")), "an old save keeps its name and occupation")
	var p = W._player()
	_check(p.rig.scale.is_equal_approx(p.rig.get_meta(&"look_scale", p.rig.scale)), "an old save draws the survivor at its usual size")

func _clean() -> void:
	SG.blocked_reason = ""
	var dir := ProjectSettings.globalize_path(RUN_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))

func _saved() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	return parsed as Dictionary if parsed is Dictionary else {}

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
		print("[t_charcreate] FAIL %s" % what)

func _finish() -> void:
	OS.remove_logger(errors)
	for l in errors.lines:
		failures.append("engine error: %s" % l)
		print("[t_charcreate] FAIL engine error: %s" % l)
	if failures.is_empty():
		print("[t_charcreate] PASS")
		quit(0)
	else:
		print("[t_charcreate] FAILED %d" % failures.size())
		quit(1)
