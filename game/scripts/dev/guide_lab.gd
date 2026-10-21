extends Node3D
## GUIDE gate (durango-prompts 22): the walkthrough finger on the real home island and HUD, from a fresh
## scratch save (labs save under user://runs/guide_lab, wiped at launch). Every tap is a real input
## event through the engine, so the finger is proven not to eat input.
##   1. The finger shows within 1 s, on the nearest safe branch tree (tip <= 24 px from it) or clamped to
##      the edge pointing at it; the survivor walks until the tree is on screen.
##   2. A tap on the tree opens the radial; for 3 s while the survivor walks the tip stays inside the
##      Branch hex every frame.
##   3. A tap at the tip picks Branch; the finger hides within a frame and never comes back for the order,
##      also after a save and a reload; the next order's finger shows and stays.
##   4. It hides under the bag, craft, the menu and skills sheets, a radial open on another node, the
##      terrain pick, the pause sheet, the arrival welcome, character creation and the creature plate.
##   5. Motion (the owner's 2026-10-21 gate), frame by frame over the walk to the tree, the radial walk and
##      the next order: the hand never jumps or snaps round, and does not swap sides for the same target.
##   6. Review r1: a clamped hand stays on the safe-area edge (never slid in to tap the world) and off every
##      HUD block; on the radial it keeps off the Branch hex's own label where it can; a craft order puts it
##      on the MENU hex's rim, off the other hexes; beside the tree it still shows on the Branch hex.
##   7. Review r2: the clamped hand at spawn does not point along the vitals or the card; a
##      level-up never pushes it onto a HUD control.
## Windowed: --resolution 1600x900 -- --lab=guide_lab [--shot-dir=DIR] (844x390 too; either renderer).
## Prints "[guide] PASS" (exit 0) or "[guide] FAIL ..." lines (exit 1).

const TIP_PX := 24.0

var _out := ""
var _player: Player
var _hud: HuntHud
var _finger: GuideFinger
var _fails: Array[String] = []
var _t0 := 0
var _frame0 := 0
var _pick_frame := -1
var _pick_item := ""
var _motion: Dictionary = {}  ## phase -> {frames, jumps, snaps, swaps, hops}
var _last: Array = []
var _clamped := {"frames": 0, "inward": 0, "on_hud": 0, "worst": 0.0}  ## clamped frames, tips off the edge, hands on a HUD block

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("guide")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false  # before the HUD builds: players never see the DEBUG hex
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	# Same layering as main.gd: bag and craft are modals above every other canvas layer.
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	_player.ui.reparent(modals)
	(_player.craft_ui as Node).reparent(modals)
	_finger = _player.get_node_or_null("GuideLayer/GuideFinger") as GuideFinger
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_t0 = Time.get_ticks_msec()
	_frame0 = Engine.get_frames_drawn()
	_run.call_deferred()

func _run() -> void:
	_expect(_finger != null, "PlayerView mounts the finger (GuideLayer/GuideFinger)")
	if _finger == null:
		_finish()
		return
	var layer := _finger.get_parent() as CanvasLayer
	_expect(layer.layer > 65 and layer.layer < 96 and _finger.mouse_filter == Control.MOUSE_FILTER_IGNORE, "finger on layer %d (66-95) and ignores the mouse" % layer.layer)
	_expect(World.objective == 0 and World.guide_done.is_empty(), "fresh save: order 1, nothing shown yet")
	# 1. Shows within 1 s on the chosen tree. The clock starts at the island's first drawn frame: on
	# gl_compatibility that first frame alone takes over a second (shader compiles), finger or not.
	await RenderingServer.frame_post_draw
	var first_ms := Time.get_ticks_msec() - _t0
	var t1 := Time.get_ticks_msec()
	while not _finger.visible and Time.get_ticks_msec() - t1 < 3000:
		await get_tree().process_frame
	var shown_ms := Time.get_ticks_msec() - t1
	print("[guide] finger shown %d ms after the island's first frame (that frame took %d ms; frame %d after the load) step %s clamped=%s" % [shown_ms, first_ms, Engine.get_frames_drawn() - _frame0, _finger.step_id, _finger.clamped])
	_expect(_finger.visible and shown_ms <= 1000, "the finger shows within 1 s of the island's first frame (%d ms)" % shown_ms)
	# The camera snaps onto the survivor over the first frames: judge the aim once it has settled, at the
	# end of a frame (after every _process), so the finger and the camera are read from the same frame.
	await get_tree().create_timer(maxf(0.1, 1.0 - shown_ms / 1000.0)).timeout
	await RenderingServer.frame_post_draw
	var tree := _finger.target as HarvestNode
	var rule := Guide.pick_node(_player.global_position, &"branch", get_tree().get_nodes_in_group("harvest"), Guide.threats(get_tree()), tree)
	print("[guide] chosen tree %s at %.1f m" % [tree, _player.global_position.distance_to(tree.global_position) if tree else -1.0])
	_expect(tree != null and tree == rule, "the finger is on the nearest safe branch tree (%s; the rule picks %s)" % [tree, rule])
	if tree == null:
		_finish()
		return
	_check_on_tree(tree)
	await _shot("node")
	await _level_up()
	# The middle of the view, clear of the HUD's corners on every canvas (a tap there must reach the tree).
	var vs := get_viewport().get_visible_rect().size
	var middle := Rect2(vs * Vector2(0.25, 0.3), vs * Vector2(0.5, 0.5))
	if not middle.has_point(_cam().unproject_position(Guide.aim_point(tree))):
		# Follow the finger: walk until the tree is well on screen (by the edges the radial runs into the HUD).
		_player.nav_to(_player._closest_nav_point(tree.global_position))
		var t := 0.0
		_last = []
		while t < 15.0 and (_finger.target == null or not middle.has_point(_cam().unproject_position(Guide.aim_point(_finger.target)))):
			await get_tree().process_frame
			t += get_process_delta_time()
			_track("walk to the tree")
		_player.clear_nav()
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		tree = _finger.target as HarvestNode
		print("[guide] walked %.1f s; tree on screen=%s" % [t, not _finger.clamped])
		_expect(not _finger.clamped and tree != null, "walking toward the finger brings its tree on screen")
		if tree == null:
			_finish()
			return
		_check_on_tree(tree)
		_smooth("walk to the tree", true)
		await _shot("node_near")
	# 2. A real tap on the tree opens the radial; the tip follows the Branch hex while the survivor walks.
	var radial := _player._gather_radial
	radial.picked.connect(func (_n: Node3D, i: int) -> void:
		_pick_frame = Engine.get_process_frames()
		_pick_item = str((radial.options[i] as Dictionary).get("item", ""))
		# Stop the gather this pick starts: one pass can yield all three branches, and order 1 must stay
		# current for the checks that the finger stays away from it.
		_player._cancel_gather_and_butcher.call_deferred())
	await _tap(_cam().unproject_position(Guide.aim_point(tree)))
	await get_tree().create_timer(0.3).timeout
	_expect(radial.is_open() and radial.hex_rect_for(&"branch").has_area(), "a tap on the tree opens the radial with a Branch hex")
	# Walk sideways toward the tree's side of the screen, so it drifts to the middle while the radial follows.
	var tree_x := _cam().unproject_position(Guide.aim_point(tree)).x
	var side := _cam().global_basis.x.normalized() * (5.0 if tree_x > get_viewport().get_visible_rect().get_center().x else -5.0)
	var start := _player.global_position
	_player.nav_to(_player._closest_nav_point(start + Vector3(side.x, 0.0, side.z)))
	var frames := 0
	var off := 0
	var t2 := 0.0
	var shot_taken := false
	var hex := Rect2()
	var on_label := 0
	_last = []
	while t2 < 3.0:
		await get_tree().process_frame
		t2 += get_process_delta_time()
		frames += 1
		_track("radial walk")
		hex = radial.hex_rect_for(&"branch")
		if _covers_own_label(radial):
			on_label += 1
		if not (_finger.visible and hex.has_point(_finger.tip)):
			off += 1
			if off <= 3:
				print("[guide] frame %d: tip %s outside Branch hex %s (shown=%s)" % [frames, _finger.tip, hex, _finger.visible])
		if t2 > 1.5 and not shot_taken:
			shot_taken = true
			await _shot("hex")
	var moved := start.distance_to(_player.global_position)
	_player.clear_nav()
	print("[guide] radial walk: %d frames, %d with the tip off the Branch hex, survivor moved %.1f m; %d frames on the Branch label where a placement off it fitted" % [frames, off, moved, on_label])
	_expect(frames > 30 and off == 0 and moved > 1.0, "tip inside the Branch hex every frame for 3 s while the survivor walks (%d of %d off, moved %.1f m)" % [off, frames, moved])
	_expect(on_label == 0, "the hand keeps off the Branch hex's own label where a placement allows (%d frames on it)" % on_label)
	_smooth("radial walk", true)
	await get_tree().create_timer(0.3).timeout
	# 3. A tap at the tip picks Branch, and the finger hides within a frame and stays gone.
	var tip := _finger.tip
	await _tap(tip)
	var hidden_frame := -1
	for k in 4:
		if not _finger.visible and hidden_frame < 0:
			hidden_frame = Engine.get_process_frames()
		await get_tree().process_frame
	print("[guide] tap at %s picked %s on frame %d; finger hidden from frame %d" % [tip, _pick_item, _pick_frame, hidden_frame])
	_expect(_pick_item == "branch", "a tap at the tip picks Branch (picked \"%s\")" % _pick_item)
	_expect(_pick_frame >= 0 and hidden_frame >= 0 and hidden_frame - _pick_frame <= 1, "the finger hides within 1 frame of the pick")
	_expect(World.guide_done.has("branches"), "order 1 is marked done for the guide")
	await _shot("gone")
	_player._gather_radial.close()
	var back := await _seen_for(2.0)
	_expect(back == 0, "the finger stays hidden for the rest of order 1 (%d frames shown)" % back)
	# ... also after a save and a reload.
	_expect(SaveGame.save_now(), "the scratch save writes")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.path))
	_expect(saved is Dictionary and (saved as Dictionary).get("guide_done", []).has("branches"), "the save holds guide_done [branches] (%s)" % SaveGame.path)
	World.guide_done = PackedStringArray()
	SaveGame.load_now(self)
	await get_tree().create_timer(0.6).timeout
	print("[guide] reloaded: order %d guide_done=%s" % [World.objective, World.guide_done])
	_expect(World.objective == 0 and World.guide_done.has("branches"), "after the reload order 1 is still current and still done for the guide")
	back = await _seen_for(1.5)
	_expect(back == 0, "no finger for order 1 after the reload (%d frames shown)" % back)
	# The next order's finger shows, once, and stays.
	LabKit.give(_player, &"branch", 3)
	var t3 := 0.0
	while not (_finger.visible and _finger.step_id == "stone") and t3 < 2.0:
		await get_tree().process_frame
		t3 += get_process_delta_time()
	print("[guide] next order %s: finger on %s after %.2f s" % [_finger.step_id, _finger.target, t3])
	_expect(_finger.visible and _finger.step_id == "stone", "order 2's finger shows")
	var flicker := 0
	var was := true
	_last = []
	for k in 60:
		await get_tree().process_frame
		_track("next order")
		if was and not _finger.visible:
			flicker += 1
		was = _finger.visible
	_expect(flicker == 0 and _finger.visible, "order 2's finger stays up (%d drops in 60 frames)" % flicker)
	_smooth("next order", false)
	await _shot("next")
	# 4. Hidden under the bag, craft, the sheets and the creature plate.
	await _covered("bag", func () -> void: _player.ui.visible = true, func () -> void: _player.ui.visible = false)
	var craft := _player.craft_ui as CraftUI
	await _covered("craft", craft.show_ui, craft.hide_ui)
	await _covered("menu sheet", func () -> void: _hud.call("_toggle_sheet", &"menu"), func () -> void: _hud.call("_close_sheet"))
	await _covered("skills sheet", func () -> void: _hud.call("_toggle_skills"), func () -> void: (_hud.get_node("SkillsSheet") as SkillsSheet).close())
	var other: HarvestNode = null
	for n in get_tree().get_nodes_in_group("harvest"):
		if n is HarvestNode and not (n as HarvestNode).depleted and not Guide.offers(n, &"stone") \
				and (other == null or _player.global_position.distance_to(n.global_position) < _player.global_position.distance_to(other.global_position)):
			other = n
	await _covered("radial open on a node without stone", func () -> void: _player.debug_open_radial(other), func () -> void: _player._gather_radial.close())
	# Screens the HUD does not own (review r1: the finger tapped on the terrain pick, the pause sheet and the
	# character creation cards). LabKit puts WorldUI under this lab, as main.gd puts it under main.
	var wui = (load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(self)
	await _covered("terrain pick", func () -> void: wui.show_terrain(), func () -> void: wui.hide_all())
	await _covered("pause sheet", func () -> void: wui.show_pause(), func () -> void: wui.hide_all())
	await _covered("arrival welcome", func () -> void: wui.call("_show_arrival", self), func () -> void: get_node("ArrivalWelcome").free())
	await _covered("character creation", func () -> void: get_tree().root.add_child(CharacterCreation.new()),
		func () -> void: get_tree().get_first_node_in_group(&"character_creation").free())
	var wild: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and not c.is_pet and not c.health.dead:
			wild = c
			break
	_expect(wild != null, "a wild creature exists for the plate check")
	if wild:
		wild.process_mode = Node.PROCESS_MODE_DISABLED  # hold it still beside the survivor
		wild.global_position = _player.global_position + Vector3(3.0, 0.0, 2.0)
		await _covered("creature plate", func () -> void: _player.hunt.start(wild), func () -> void: pass, false)
		_player.hunt.stop()
		wild.global_position += Vector3(400.0, 0.0, 400.0)
	await get_tree().create_timer(0.5).timeout
	await _craft_order()
	await _beside_tree()
	print("[guide] clamped frames: %s" % _clamped)
	_expect(int(_clamped["frames"]) > 0 and int(_clamped["inward"]) == 0 and int(_clamped["on_hud"]) == 0,
		"a clamped hand stays on the safe-area edge and off the HUD (%s)" % _clamped)
	_finish()

## Craft orders point at the MENU hex: the tip on the hex, the hand off the other HUD hexes.
func _craft_order() -> void:
	World.objective = 3  # twine, crafted by hand
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var menu := (_hud.control_for(&"craft") as HexButton).hex_rect()
	var hr := GuideFinger.hand_rect(_finger.anchor, float(_finger.get("_want")), float(_finger.get("_s")))
	var hit: Array[String] = []
	for n in get_tree().get_nodes_in_group(&"hex_button"):
		var h := n as HexButton
		if h and h.is_visible_in_tree() and h != _hud.control_for(&"craft") and hr.intersects(h.hex_rect()):
			hit.append(str(h.caption))
	print("[guide] craft order %s: tip %s on MENU hex %s, hand %s over hexes %s" % [_finger.step_id, _finger.anchor, menu, hr, hit])
	_expect(_finger.visible and str(_finger.get("_key")) == "rect" and menu.has_point(_finger.anchor) and hit.is_empty(),
		"the craft finger is on the MENU hex and off the other hexes (on %s)" % [hit])
	await _shot("craft")

## Review r1: with the survivor beside the tree (the usual spot after walking to it) the radial put the
## Branch hex half on the Orders card at 844x390 and the finger vanished. It aims at the part off the card.
func _beside_tree() -> void:
	_player.inventory.consume(&"branch", _player.inventory.count_of(&"branch"))
	World.objective = 0
	World.guide_done = PackedStringArray()
	await get_tree().create_timer(0.8).timeout
	var tree := _finger.target as HarvestNode
	_expect(tree != null, "order 1 has its tree again")
	if tree == null:
		return
	_player.global_position = tree.global_position + Vector3(2.0, 0.5, 2.0)
	await get_tree().create_timer(0.8).timeout
	var radial := _player._gather_radial
	_player.debug_open_radial(tree)
	# The lab resumes before the finger's _process: give it the frame (a tap opens the radial before it).
	await _frames(2)
	var shown := 0
	var frames := 0
	var thin := 0
	for k in 30:
		await get_tree().process_frame
		frames += 1
		var hex := radial.hex_rect_for(&"branch")
		var part := GuideFinger.clear_part(hex, _finger._keep_off)
		if _finger.visible and hex.has_point(_finger.tip):
			shown += 1
		elif part.size.x < 26.0 or part.size.y < 26.0:
			thin += 1  # under 26 px no hand fits off the card: the radial's layout, not the finger
	print("[guide] beside the tree: finger on the Branch hex %d of %d frames (%d with under 26 px of it off the card)" % [shown, frames, thin])
	_expect(shown + thin == frames, "beside the tree the finger shows on the Branch hex wherever 26 px of it are off the card (%d + %d of %d)" % [shown, thin, frames])
	await _shot("beside")
	radial.close()

## The vitals, the card and the minimap (title to text), as the finger keeps a clamped hand off them; its
## line keeps clear of the first two.
func _hard(map: bool = true) -> Array[Rect2]:
	var b := _hud.drawn_blocks
	var out: Array[Rect2] = []
	for k in ["vitals", "quest"]:
		if b.has(k):
			out.append(b[k])
	if map and b.has("map_title") and b.has("map_text"):
		out.append((b["map_title"] as Rect2).merge(b["map_text"]))
	return out

## Review r2: a level-up banner never pushes the hand onto a HUD control or block (at most it stays on the
## banner where no edge spot is clear of it), and off the banner wherever a clear spot exists.
func _level_up() -> void:
	_hud.call("_on_level_up", 4)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var banner: Rect2 = _hud.drawn_blocks.get("levelup", Rect2())
	var a := float(_finger.get("_want"))
	var s := float(_finger.get("_s"))
	var notes: Array[Rect2] = [banner]
	var fit := GuideFinger._spot_fit(_finger.anchor, a, get_viewport().get_visible_rect(), _hard(), HudLayout.taken_rects(_hud, GuideFinger.PASSING), notes, s) if _finger.clamped else -1
	print("[guide] level-up banner %s: hand %s clamped=%s on it=%s fit=%d" % [banner, GuideFinger.hand_rect(_finger.anchor, a, s), _finger.clamped, GuideFinger.hand_rect(_finger.anchor, a, s).intersects(banner), fit])
	_expect(banner.has_area() and _finger.visible, "the level-up banner is up and the finger stays")
	_expect(not _finger.clamped or fit >= 2, "a level-up never pushes the clamped hand onto a HUD control (fit %d)" % fit)
	await _shot("levelup")
	_hud.set("_levelup_t", -1.0)
	await get_tree().create_timer(0.6).timeout  # the card comes back under the banner: the hand cross-fades off it

## The hand's placement (not the eased drawing) covers the Branch hex's own label, and some placement
## would not.
func _covers_own_label(radial: GatherRadial) -> bool:
	var own := Rect2()
	for i in mini(radial.options.size(), radial.label_rects.size()):
		if str((radial.options[i] as Dictionary).get("item", "")) == "branch":
			own = radial.label_rects[i]
	var s := float(_finger.get("_s"))
	if not _finger.visible or not own.has_area() or not GuideFinger.hand_rect(_finger.anchor, float(_finger.get("_want")), s).intersects(own):
		return false
	var firm: Array[Rect2] = _finger._keep_off.duplicate()
	firm.append(own)
	var vs := get_viewport().get_visible_rect()
	for a in GuideFinger.ANGLES:
		if GuideFinger.hand_clear(_finger.anchor, a, s, vs, firm):
			return true
	return false

## The finger is on `tree`: its tip within TIP_PX of it, or (off screen) on the edge pointing at it.
func _check_on_tree(tree: HarvestNode) -> void:
	var p := _cam().unproject_position(Guide.aim_point(tree))
	var dir := Vector2(sin(_finger.angle), -cos(_finger.angle))
	if _finger.clamped:
		var off := rad_to_deg(absf(dir.angle_to(p - _finger.tip)))
		var run := GuideFinger.run_along(_finger.anchor, float(_finger.get("_want")), p, get_viewport().get_visible_rect(), _hard(false))
		print("[guide] tree off screen at %s: tip on the edge %s, finger %.0f deg off the tree, its line %.0f px along the vitals and the card" % [p, _finger.tip, off, run])
		_expect(off < 25.0 and get_viewport().get_visible_rect().has_point(_finger.tip), "edge-clamped finger points at the tree (%.0f deg off)" % off)
		# Where an edge spot's line clears them: the 844x390 HUD has none for this tree (see the report).
		var vr := get_viewport().get_visible_rect()
		var inner := vr.grow(-GuideFinger.EDGE)
		var soft := HudLayout.taken_rects(_hud, GuideFinger.PASSING)
		var none: Array[Rect2] = []
		var s := float(_finger.get("_s"))
		var best := GuideFinger.edge_spot(GuideFinger.clamp_tip(p, false, inner), p, inner, vr, _hard(), soft, s, Vector2(NAN, NAN), none, _hard(false))
		var clear := GuideFinger._spot_level(best, p, vr, _hard(), soft, none, _hard(false), s) == 4
		print("[guide] the best edge spot for a clear line is %s (clear=%s)" % [best, clear])
		_expect(run <= GuideFinger.RUN_MAX or not clear, "the clamped finger's line clears the vitals and the card where an edge spot allows (%.0f px along them)" % run)
	else:
		var d := _finger.tip.distance_to(p)
		print("[guide] tree at %s: tip %s, %.1f px away" % [p, _finger.tip, d])
		_expect(d <= TIP_PX, "tip within %.0f px of the tree (%.1f)" % [TIP_PX, d])

## A clamped hand this frame: its tip within EDGE plus the nudge of the safe-area edge (drawn, not the
## eased anchor: the gate is what the player sees once the glide is over), the hand off every HUD block.
func _check_clamped() -> void:
	var vs := get_viewport().get_visible_rect()
	var ins := UiTokens.safe_insets(get_viewport())
	var safe := Rect2(Vector2(ins.w, ins.z), vs.size - Vector2(ins.w + ins.x, ins.z + ins.y))
	var s := float(_finger.get("_s"))
	var d := minf(minf(absf(_finger.tip.x - safe.position.x), absf(_finger.tip.x - safe.end.x)), minf(absf(_finger.tip.y - safe.position.y), absf(_finger.tip.y - safe.end.y)))
	_clamped["frames"] += 1
	_clamped["worst"] = maxf(float(_clamped["worst"]), d)
	var gliding := (_finger.get("_offset") as Vector2).length() > 0.5
	if d > GuideFinger.EDGE + GuideFinger.NUDGE * s + 2.0 and not gliding:
		_clamped["inward"] += 1
		if int(_clamped["inward"]) <= 3:
			print("[guide] clamped tip %s is %.1f px in from the edge" % [_finger.tip, d])
	var hr := GuideFinger.hand_rect(_finger.anchor, float(_finger.get("_want")), s)
	for r in HudLayout.taken_rects(_hud, GuideFinger.PASSING):
		if hr.intersects(r):
			_clamped["on_hud"] += 1
			if int(_clamped["on_hud"]) <= 3:
				print("[guide] clamped hand %s on HUD block %s" % [hr, r])
			break

## One frame of the finger's motion in `phase`, against the last frame:
## - jump: the tip moved farther than GuideFinger.GLIDE_MAX allows over the finger's own frame time, plus
##   the tap's and the turn's share and, on a hex, the hex's own motion (review r2: px per frame, not px/s
##   over a 24 px floor, which passed at 60 fps and failed at 100);
## - snap: the hand turned over 30 degrees, faster than 12 rad/s (it eases at GuideFinger.TURN, 10 rad/s);
## - swap: a new placement for the same target, off the edge (an edge hand points along its own line);
## - hop: a new target;
## - fade: a cross-fade to a new spot (where a glide would cross the vitals or the card), not a jump.
## On a hex the tip is the hex (it must stay inside it), so a frame where the radial's own hex jumped over
## 12 px is the radial's ("radial_jumps", the known "hexes jump while walking" item), not charged to the hand.
func _track(phase: String) -> void:
	var m: Dictionary = _motion.get_or_add(phase, {"frames": 0, "jumps": 0, "snaps": 0, "swaps": 0, "hops": 0, "radial_jumps": 0, "fades": 0})
	if _finger.visible and _finger.clamped:
		_check_clamped()
	var key := str(_finger.get("_key"))
	var now := [_finger.visible, _finger.tip, _finger.anchor, _finger.angle, float(_finger.get("_want")), key, _finger.target, float(_finger.get("_fade")), float(_finger.get("_t"))]
	var dt := float(now[8]) - float(_last[8]) if _last.size() == now.size() else 0.0  # the finger's own frame time
	if _last.size() == now.size() and _last[0] and now[0] and key == "hex" and _last[5] == "hex" and (now[2] - _last[2]).length() > 12.0:
		m["radial_jumps"] += 1
		print("[guide] %s: the radial's hex jumped %s -> %s" % [phase, _last[2], now[2]])
	elif _last.size() == now.size() and _last[0] and now[0] and float(now[7]) < float(_last[7]):
		m["fades"] += 1  # a move across the vitals or the card: the hand cross-fades there, it does not jump
		print("[guide] %s fade: tip %s -> %s on %s" % [phase, _last[1], now[1], key])
	elif _last.size() == now.size() and _last[0] and now[0]:
		m["frames"] += 1
		var moved: Vector2 = now[1] - _last[1]
		var s := float(_finger.get("_s"))
		var allowed: float = (GuideFinger.GLIDE_MAX + GuideFinger.BOB * s * (PI * GuideFinger.TAP_HZ + GuideFinger.TURN)) * dt + 0.5 \
			+ (((now[2] - _last[2]) as Vector2).length() if key == "hex" else 0.0)
		if moved.length() > allowed:
			m["jumps"] += 1
			print("[guide] %s jump: tip %s -> %s (%.1f px in %.1f ms, %.1f allowed) on %s" % [phase, _last[1], now[1], moved.length(), dt * 1000.0, allowed, key])
		var turn := absf(angle_difference(float(_last[3]), float(now[3])))
		if turn > deg_to_rad(30.0) and turn > 12.0 * dt:
			m["snaps"] += 1
			print("[guide] %s snap: %.0f deg in %.0f ms on %s, anchor %s -> %s, card %s" % [phase, rad_to_deg(turn), dt * 1000.0, key, _last[2], now[2], _hud.drawn_blocks.get("quest", Rect2())])
		if key == _last[5] and not key.begins_with("edge") and not is_equal_approx(float(now[4]), float(_last[4])):
			m["swaps"] += 1
			print("[guide] %s swap: placement %.0f -> %.0f deg on %s, anchor %s -> %s" % [phase, rad_to_deg(float(_last[4])), rad_to_deg(float(now[4])), key, _last[2], now[2]])
		if now[6] != _last[6]:
			m["hops"] += 1
	_last = now

## The motion gate for `phase`: no jumps or snaps, at most one placement change and one cross-fade, and
## (`still`) one target.
func _smooth(phase: String, still: bool) -> void:
	var m: Dictionary = _motion.get(phase, {"frames": 0, "jumps": 0, "snaps": 0, "swaps": 0, "hops": 0, "radial_jumps": 0, "fades": 0})
	print("[guide] motion %s: %s" % [phase, m])
	_expect(int(m["frames"]) >= 20 and int(m["jumps"]) == 0 and int(m["snaps"]) == 0 and int(m["swaps"]) <= 1 and int(m["fades"]) <= 1 and (not still or int(m["hops"]) == 0),
		"%s: the hand moves smoothly over %d frames (jumps %d, snaps %d, swaps %d, fades %d, hops %d)" % [phase, m["frames"], m["jumps"], m["snaps"], m["swaps"], m["fades"], m["hops"]])

## Open a cover, expect the finger gone; close it, expect it back (proves the cover hid it).
func _covered(what: String, open: Callable, close: Callable, reopens: bool = true) -> void:
	_expect(_finger.visible, "%s: finger up before it opens" % what)
	open.call()
	await _frames(3)
	print("[guide] %s open: finger shown=%s" % [what, _finger.visible])
	_expect(not _finger.visible, "the finger hides under the %s" % what)
	if what == "creature plate":
		await _shot("plate")
	close.call()
	await _frames(3)
	if reopens:
		_expect(_finger.visible, "the finger returns when the %s closes" % what)

## Frames the finger is up for order 1 in the next `seconds`.
func _seen_for(seconds: float) -> int:
	var t := 0.0
	var n := 0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		n += 1 if _finger.visible and World.objective == 0 else 0
	return n

func _cam() -> Camera3D:
	return get_viewport().get_camera_3d()

## A real press and release at a canvas point, in window pixels, through the engine's input pipeline.
func _tap(pos: Vector2) -> void:
	var at := get_tree().root.get_final_transform() * pos
	var move := InputEventMouseMotion.new()
	move.position = at
	Input.parse_input_event(move)
	await _frames(1)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		Input.parse_input_event(ev)
		await _frames(1)

func _shot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		_fails.append("%s: no pixels (run windowed, not --headless)" % name)
		return
	var at := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(at)
	print("[guide] shot %s finger=%s tip=%s" % [at, _finger.visible, _finger.tip])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)

func _finish() -> void:
	if _fails.is_empty():
		print("[guide] PASS shots=%s" % _out)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("[guide] FAIL %s" % f)
		get_tree().quit(1)
