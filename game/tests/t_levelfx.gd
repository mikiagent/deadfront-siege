extends SceneTree
## LEVELFX acceptance (owner 2026-10-21: "make it flashy. Level ups should have light effect
## animations. Also watch out for glitchy movement of UI and player"). With the real HUD, survivor
## and camera (LabKit):
## - a character level-up spawns the big light at the survivor's feet (pillar, two rings, rays,
##   flash, sparkles, a shadowless OmniLight) and the HUD celebration;
## - a skill category level-up spawns the small one (no pillar, fewer sparkles, a weaker light) and
##   the skill banner; the occupation's head start (an emit of skill_changed) celebrates nothing;
## - every light frees itself on time and leaves the survivor's children as they were; riding a
##   mount, the light stands on the mount's root (her body hangs from its saddle), not 1 m underground;
## - one XP grant worth two character levels and two categories queues: one celebration and one
##   light at a time, each starting only after the last has faded, the two character levels merged;
## - the camera keeps no shake offset and stays put while the survivor stands; the celebration's
##   block does not move between frames;
## - toasts and notices on screen while a skill level-up starts and ends move only by their own rise
##   (a skill banner at the top centre made them jump 52-60 px in one frame: review, fix round 1);
## - at 844x390 a skill level-up keeps the quest card and stands beside it, a character level-up takes
##   the band; a target plate appearing under either never has the banner across it (the banner moves
##   only while it fades back in), and the banner glides back up when the plate leaves;
## - riding, the light stands on the saddle with her, held in the mount's frame; dismounting mid-way
##   it moves to her feet;
## - particle counts stay in a phone budget, the sparkle quad and its material are shared between
##   level-ups (a fresh BaseMaterial3D per level-up recompiled its shader every time: a 120 ms frame
##   on gl_compatibility); the light's life comes from data/level_fx.json.
## Fails on the base: no light, no skill celebration, no queue.
## Usage: godot --headless --path game --script res://tests/t_levelfx.gd

const FX_GROUP := &"level_up_fx"
const SPARKS_MAX := 64  ## sparkles per light, phone budget
const LIGHT_RANGE_MAX := 8.0

var failures: Array[String] = []
var _started := false
var host: Node3D
## `godot --script` compiles this file before the autoloads exist: game classes are loaded at run
## time and used untyped (the t_player pattern).
var world: Node
var player
var hud
var cam
var cel
var _char_mesh: Mesh  ## the first character light's sparkle quad

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_levelfx] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	world = get_root().get_node("World")
	world.pioneer_level = 2
	world.pioneer_xp = 0
	host = Node3D.new()
	host.name = "TLevelFx"
	get_root().add_child(host)
	var lab_kit = load("res://scripts/dev/lab_kit.gd")
	var kit: Dictionary = lab_kit.build(host, 30.0)
	player = kit["player"]
	cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.get_script() == load("res://scripts/ui/hunt_hud.gd"):
			hud = c
	await _frames(40)  # she lands on the floor; the warm-up copy comes and goes
	cel = hud.get("_levelups")
	_expect(cel != null, "the HUD holds a level-up queue (_levelups)")
	await _test_character()
	await _test_skill()
	await _test_burst()
	await _test_toasts()
	await _test_mounted()
	await _test_phone()
	for size in [Vector2i(1600, 900), Vector2i(844, 390)]:
		await _test_neighbours(size)
		await _test_top_feed(size)
	await _test_menu_pulse()
	await _test_occupation()
	Engine.time_scale = 1.0
	_finish()

func _test_character() -> void:
	var children: int = player.get_child_count()
	var cam_at: Vector3 = cam.global_position
	world.add_xp(world.xp_for_level(world.pioneer_level) - world.pioneer_xp)
	await _frames(3)
	var fxs := _fxs()
	_expect(fxs.size() == 1, "character level-up: one light effect (got %d)" % fxs.size())
	if fxs.is_empty():
		return
	var fx: Node3D = fxs[0]
	var parts := _parts(fx)
	_expect(str(fx.get("kind")) == "character" and fx.get_parent() == player, "character level-up: the big light, a child of the survivor (kind %s)" % fx.get("kind"))
	_expect(absf(fx.position.y + float(player.half_height())) < 0.01, "character level-up: the light stands at her feet (y %.2f)" % fx.position.y)
	_expect(parts["meshes"] >= 5 and parts["has_pillar"], "character level-up: pillar, rings, rays and flash (%d meshes, pillar %s)" % [parts["meshes"], parts["has_pillar"]])
	_expect(parts["light"] != null and not (parts["light"] as OmniLight3D).shadow_enabled and (parts["light"] as OmniLight3D).omni_range <= LIGHT_RANGE_MAX, "character level-up: a shadowless OmniLight of at most %.0f m" % LIGHT_RANGE_MAX)
	_expect(parts["sparks"] > 0 and parts["sparks"] <= SPARKS_MAX, "character level-up: sparkles within the phone budget (%d <= %d)" % [parts["sparks"], SPARKS_MAX])
	_char_mesh = parts["spark_mesh"]
	var want_life := float((_json().get("character", {}) as Dictionary).get("life", -1.0))
	_expect(absf(float(fx.get("life")) - want_life) < 0.001, "character level-up: its life comes from level_fx.json (%.2f s)" % want_life)
	_expect(cel != null and str(cel.call("showing_key")).begins_with("character:%d" % (world.pioneer_level + 1)), "character level-up: the HUD celebrates Lv. %d (%s)" % [world.pioneer_level + 1, cel.call("showing_key") if cel else "no queue"])
	var rec := await _watch(float(fx.get("life")) + 0.3, true)
	_expect(float(rec["light_max"]) > 1.0, "character level-up: the light flares (peak energy %.1f)" % rec["light_max"])
	_expect(_fxs().is_empty() and player.get_child_count() == children, "character level-up: the light frees itself (children %d, was %d)" % [player.get_child_count(), children])
	_expect(rec["blocks"] > 0, "character level-up: the HUD draws its block (%d frames)" % rec["blocks"])
	_expect(float(rec["block_jump"]) == 0.0, "character level-up: the HUD block does not move between frames (max %.2f px)" % rec["block_jump"])
	var lu_r: Rect2 = rec["block_rect"]
	var vit: Rect2 = load("res://scripts/ui/hud_layout.gd").vitals_rect(hud, Vector2(get_root().size))
	_expect(lu_r.has_area() and lu_r.position.x <= vit.position.x + 16.5 and lu_r.position.y >= vit.end.y, "character level-up: the stack hugs the left edge, under the vitals (owner: far left; %s, vitals %s)" % [lu_r, vit])
	_expect(float(rec["cam_offset"]) == 0.0 and float(rec["trauma"]) == 0.0, "character level-up: no camera shake (offset %.4f, trauma %.3f)" % [rec["cam_offset"], rec["trauma"]])
	_expect(cam.global_position.distance_to(cam_at) < 0.01 and float(rec["cam_step"]) < 0.001, "character level-up: the camera stays put (moved %.4f m, max step %.5f m)" % [cam.global_position.distance_to(cam_at), rec["cam_step"]])
	await _quiet()

func _test_skill() -> void:
	var s = player.skills
	var lv: int = s.level_of("survival")
	var big_sparks := int(((_json().get("character", {}) as Dictionary).get("sparkles", {}) as Dictionary).get("amount", 0))
	s.add_xp("survival", s.xp_to_next(lv) - s.xp_of("survival"), true)
	_expect(s.level_of("survival") == lv + 1, "skill level-up: survival rose to Lv. %d" % s.level_of("survival"))
	await _frames(3)
	var fxs := _fxs()
	_expect(fxs.size() == 1, "skill level-up: one light effect (got %d)" % fxs.size())
	if fxs.is_empty():
		return
	var parts := _parts(fxs[0])
	_expect(str(fxs[0].get("kind")) == "skill" and not parts["has_pillar"] and parts["meshes"] >= 1, "skill level-up: the small light, a ring and no pillar (kind %s, %d meshes)" % [fxs[0].get("kind"), parts["meshes"]])
	_expect(parts["sparks"] > 0 and parts["sparks"] < big_sparks, "skill level-up: fewer sparkles than a character level-up (%d < %d)" % [parts["sparks"], big_sparks])
	_expect(cel != null and str(cel.call("showing_key")) == "skill:survival:%d" % (lv + 1), "skill level-up: the HUD shows Survival Lv. %d (%s)" % [lv + 1, cel.call("showing_key") if cel else "no queue"])
	var rec := await _watch(float(fxs[0].get("life")) + 0.3, true)
	var big := float(((_json().get("character", {}) as Dictionary).get("light", {}) as Dictionary).get("energy", 0.0))
	_expect(float(rec["light_max"]) > 0.0 and float(rec["light_max"]) < big, "skill level-up: a weaker light (peak %.1f < %.1f)" % [rec["light_max"], big])
	_expect(_fxs().is_empty(), "skill level-up: the light frees itself")
	_expect(rec["blocks"] > 0 and float(rec["block_jump"]) == 0.0, "skill level-up: the skill banner is drawn and stays put (%d frames, max jump %.2f px)" % [rec["blocks"], rec["block_jump"]])
	_expect(float(rec["cam_offset"]) == 0.0, "skill level-up: no camera shake")
	await _quiet()

## Two character levels, then survival and gathering, from one grant: queued, merged, one at a time.
## Survival holds banked XP at its cap first: SkillState hears pioneer_changed before the HUD and
## releases it, so survival's level-up arrives before the character level that freed it.
func _test_burst() -> void:
	var s = player.skills
	s.add_xp("survival", 5000.0, true)
	await _quiet()
	var before: int = world.pioneer_level
	var need: int = world.xp_for_level(before) - world.pioneer_xp + world.xp_for_level(before + 1)
	var lv_g: int = s.level_of("gathering")
	s.add_xp("gathering", float(need))
	var after: int = world.pioneer_level
	_expect(after == before + 2 and s.level_of("gathering") > lv_g, "burst: one grant gave two character levels (%d -> %d) and gathering levels (%d -> %d)" % [before + 1, after + 1, lv_g, s.level_of("gathering")])
	if cel == null:
		return
	var pending: Array = cel.get("queue")
	var chars := pending.filter(func (e: Dictionary) -> bool: return e["kind"] == &"character").size()
	_expect(chars == 1 and pending.size() == 3, "burst: queued as one character level-up (merged) and one per category (%s)" % [pending.map(func (e: Dictionary) -> String: return "%s:%s:%d" % [e["kind"], e["tree"], e["level"]])])
	Engine.time_scale = 3.0
	var rec := await _watch(40.0, false)
	Engine.time_scale = 1.0
	var order: Array = rec["order"]
	print("[t_levelfx] burst order %s" % [order])
	_expect(order.size() == 3 and str(order[0]) == "character:%d" % (after + 1), "burst: the character level-up shows first, at the new level, then the categories (%s)" % [order])
	_expect(order.has("skill:gathering:%d" % s.level_of("gathering")) and order.has("skill:survival:%d" % s.level_of("survival")), "burst: gathering and survival each show their top level once")
	_expect(int(rec["fx_max"]) <= 1, "burst: one light effect at a time (max %d)" % rec["fx_max"])
	_expect(rec["char_meshes"] > 0 and rec["new_meshes"] == 0, "burst: the character light reuses the first one's sparkle quad and material (%d frames, %d with a new one)" % [rec["char_meshes"], rec["new_meshes"]])
	_expect(rec["overlaps"] == 0, "burst: each celebration starts after the last has faded (%d early starts)" % rec["overlaps"])
	_expect(float(rec["block_jump"]) == 0.0, "burst: no celebration moves between frames (max %.2f px)" % rec["block_jump"])
	_expect(float(rec["cam_offset"]) == 0.0 and float(rec["cam_step"]) < 0.001, "burst: the camera neither shakes nor moves (offset %.4f, step %.5f m)" % [rec["cam_offset"], rec["cam_step"]])
	_expect(_fxs().is_empty() and str(cel.call("showing_key")) == "", "burst: everything ends on its own")

## A character level-up while riding the T. rex (Player.mount's saddle path, as equip_mount_lab).
func _test_mounted() -> void:
	var data: Node = get_root().get_node("Data")
	var def = data.creature(&"tyrannosaurus")
	var pet_record = load("res://scripts/pets/pet_record.gd")
	var rec = pet_record.from_def(def, &"A") if def else null
	if def == null or rec == null:
		_expect(false, "mounted: a T. rex mount can be made (def %s, record %s)" % [def, rec])
		return
	var c: Node3D = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.set("is_pet", true)
	c.set("pet_record", rec)
	c.call("spawn", def, rec.variant)
	c.global_position = Vector3(player.global_position.x + 6.0, 0.0, player.global_position.z)
	await _frames(20)
	player.mount(c)
	await _frames(5)
	world.add_xp(world.xp_for_level(world.pioneer_level) - world.pioneer_xp)
	await _frames(3)
	var fxs := _fxs()
	var fx: Node3D = fxs[0] if fxs.size() == 1 else null
	_expect(fx != null and player.get("mounted_on") == c and fx.get_parent() == c, "mounted: a level-up while riding plays one light, a child of the mount (%d, parent %s)" % [fxs.size(), fx.get_parent().name if fx else "none"])
	var rig: Node3D = player.rig
	var seat := rig.global_position.y - c.global_position.y
	var local: Vector3 = fx.position if fx else Vector3.ZERO
	var off := 0.0
	var moved := 0.0
	var ring_y: Array = []
	var t := 0.0
	while fx and is_instance_valid(fx) and t < 2.5:
		if t > 0.3 and ring_y.is_empty():
			for mi in fx.get_children():
				if mi is MeshInstance3D and (mi as MeshInstance3D).mesh is PlaneMesh and not (mi as MeshInstance3D).mesh is QuadMesh:
					ring_y.append(snappedf((mi as Node3D).global_position.y - c.global_position.y, 0.01))
		off = maxf(off, fx.global_position.distance_to(rig.global_position))
		moved = maxf(moved, fx.position.distance_to(local))
		await process_frame
		t += cam.get_process_delta_time()
	print("[t_levelfx] mounted: seat %.2f m over the mount's feet, light at y %.2f in the mount's frame, rings at %s m" % [seat, local.y, ring_y])
	_expect(not ring_y.is_empty() and ring_y.all(func (y: float) -> bool: return absf(y) < 0.5), "mounted: its rings stay on the ground under the mount (%s m over its feet)" % [ring_y])
	_expect(seat > 2.0 and absf(local.y - seat) < 0.3, "mounted: the light stands on the saddle with her (y %.2f, seat %.2f m), not at the mount's feet inside its body" % [local.y, seat])
	_expect(off < 1.0 and moved == 0.0, "mounted: it stays with her (within the saddle's bob) and does not follow the bone (max %.3f m from her, moved %.3f m on the mount)" % [off, moved])
	await _quiet()
	world.add_xp(world.xp_for_level(world.pioneer_level) - world.pioneer_xp)
	await _frames(3)
	fxs = _fxs()
	await create_timer(0.4).timeout
	player.dismount()
	await _frames(3)
	fx = fxs[0] if fxs.size() == 1 and is_instance_valid(fxs[0]) else null
	_expect(fx != null and fx.get_parent() == player and absf(fx.position.y + float(player.half_height())) < 0.01 and is_equal_approx(fx.scale.x, 1.0), "mounted: dismounting mid-way moves the light to her feet (parent %s, y %.2f, scale %.2f)" % [fx.get_parent().name if fx else "none", fx.position.y if fx else 0.0, fx.scale.x if fx else 0.0])
	await _quiet()
	c.queue_free()
	await _frames(2)

## Desktop: a toast and a notice when a skill level-up starts, another toast when it ends. Every
## frame each one may move only by its own rise (35 px/s); none may sit under the banner.
func _test_toasts() -> void:
	await _quiet()
	var s = player.skills
	var lv: int = s.level_of("processing")
	_expect(lv < s.level_cap("processing"), "toasts: processing can still level (Lv. %d, cap %d)" % [lv, s.level_cap("processing")])
	hud.toast(&"wood", 3)
	hud.notice("Too heavy to carry more")
	await create_timer(0.6).timeout  # the yield card (UIGATHER, toast0) has popped in and settled
	s.add_xp("processing", s.xp_to_next(lv) - s.xp_of("processing"), true)
	var last: Dictionary = {}  # "toast:<item>" or "notice:<text>" -> [box, k]
	var worst := 0.0
	var worst_at := ""
	var under := 0
	var seen_start := false
	var seen_end := false
	var was_showing := false
	var t := 0.0
	var pushed := false
	var compared := 0
	while t < 4.2:
		await process_frame
		t += cam.get_process_delta_time()
		if not pushed and t > 2.5:
			pushed = true
			hud.toast(&"stone", 2)
		var blocks: Dictionary = hud.get("drawn_blocks")
		var lu: Rect2 = blocks.get("levelup", Rect2())
		var showing: bool = lu.has_area()
		var now: Dictionary = {}
		var events = hud.get("_events")
		var feed_rows: Array = hud.get("top_feed").get("rows").filter(func (r: Dictionary) -> bool: return r["kind"] == &"gain")
		for kind in ["toast", "notice"]:
			var list: Array = feed_rows if kind == "toast" else events.get("notices")
			for i in list.size():
				var box: Rect2 = blocks.get("%s%d" % [kind, i], Rect2())
				if not box.has_area():
					continue
				var e: Dictionary = list[i]
				var k := float(e["t"])
				var key := "%s:%s" % [kind, e.get("id", e.get("text", ""))]
				now[key] = [box, k]
				if showing and box.intersects(lu):
					under += 1
				if showing != was_showing:
					seen_start = seen_start or showing
					seen_end = seen_end or not showing
				if last.has(key):
					compared += 1
					var pb: Rect2 = last[key][0]
					# TopFeed rows ease to a new spot when the column changes (never snap): 20 px a frame at most.
					var err := absf(box.position.y - pb.position.y) + absf(box.position.x - pb.position.x)
					if kind == "toast":
						err = maxf(0.0, err - 20.0)
					if err > worst:
						worst = err
						worst_at = "%s at %.2f s" % [kind, t]
		last = now
		was_showing = showing
	print("[t_levelfx] toasts: worst move beyond the rise %.2f px (%s), %d frame pairs, seen start %s end %s" % [worst, worst_at, compared, seen_start, seen_end])
	_expect(seen_start and seen_end and compared > 100, "toasts: toasts were on screen when the skill banner started and ended (start %s, end %s, %d frame pairs)" % [seen_start, seen_end, compared])
	_expect(worst <= 1.0, "toasts: no gain row or notice jumps when a skill banner starts or ends (worst %.2f px past an eased step, %s)" % [worst, worst_at])
	_expect(under == 0, "toasts: no toast or notice under the skill banner (%d frames)" % under)
	await _quiet()

## 844x390: the quest card stays beside a skill level-up and yields the band to a character one; a
## target plate appearing under either never has the banner across it (it moves only while fading
## back in) and the banner glides back up after the plate leaves.
func _test_phone() -> void:
	var start_size := get_root().size
	var start_canvas := get_root().content_scale_size
	get_root().size = Vector2i(844, 390)
	get_root().content_scale_size = Vector2i(844, 390)
	await _frames(6)
	var data: Node = get_root().get_node("Data")
	var c: Node3D = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.call("spawn", data.creature(&"compsognathus"), &"A")
	c.global_position = player.global_position + Vector3(5.0, 0.0, 3.0)
	c.process_mode = Node.PROCESS_MODE_DISABLED  # a target plate only, never a fight that sets one itself
	await _frames(4)
	for kind in ["skill", "character"]:
		await _quiet()
		hud.set("_last_target", null)
		if kind == "skill":
			cel.call("push_skill", &"processing", 9)
		else:
			hud.call("_on_level_up", world.pioneer_level)
		var rec := await _phone_watch(0.6, false, null)
		if kind == "skill":
			_expect(rec["orders_frames"] == rec["frames"] and rec["lu_frames"] > 0 and rec["quest_hits"] == 0, "phone: a skill level-up keeps the order (card or minimap badge) and stays off it (%d/%d frames with the order, %d drawn, %d overlaps)" % [rec["orders_frames"], rec["frames"], rec["lu_frames"], rec["quest_hits"]])
		else:
			_expect(rec["quest_frames"] == 0 and rec["lu_frames"] > 0, "phone: a character level-up takes the band from the quest card (%d frames with the card)" % rec["quest_frames"])
		var at := (hud.get("drawn_blocks") as Dictionary).get("levelup", Rect2()) as Rect2
		rec = await _phone_watch(0.8, true, c)
		_expect(rec["plate_frames"] > 0 and rec["plate_hits"] == 0, "phone %s: a plate appearing never has the banner across it (%d frames with the plate, %d overlaps)" % [kind, rec["plate_frames"], rec["plate_hits"]])
		if kind == "character":
			_expect(float(rec["seen_jump"]) > 0.0 and float(rec["bad_jump"]) == 0.0, "phone %s: pushed below the plate, the banner moves only while it fades back in (moved %.0f px, %.0f px while shown)" % [kind, rec["seen_jump"], rec["bad_jump"]])
		else:
			_expect(float(rec["step"]) <= 20.0, "phone skill: the top-middle row under the band eases below the plate, never jumps (largest step %.1f px)" % rec["step"])
		rec = await _phone_watch(0.8, true, null)
		var back := (hud.get("drawn_blocks") as Dictionary).get("levelup", Rect2()) as Rect2
		_expect(back.is_equal_approx(at), "phone %s: when the plate leaves, the banner is back where it stood (%s, was %s)" % [kind, back, at])
		if kind == "character":
			_expect(float(rec["step"]) > 0.0 and float(rec["step"]) < 60.0, "phone character: it glides back up over several frames, height too (largest step %.1f px of 124)" % rec["step"])
		else:
			_expect(float(rec["step"]) <= 20.0, "phone skill: back under the band, easing (largest step %.1f px)" % rec["step"])
	await _quiet()
	c.queue_free()
	get_root().size = start_size
	get_root().content_scale_size = start_canvas
	await _frames(4)

## Frames for `seconds` at the phone size (after 3 frames the HUD's target becomes `target` when
## `retarget`): frames with the quest card, the banner, the plate, overlaps of the banner with either,
## its largest per-frame move or resize, the largest move over 40 px, and such a move while the
## celebration had not just re-placed it (its fade-back-in over 0.15).
func _phone_watch(seconds: float, retarget: bool, target: Node3D) -> Dictionary:
	var out := {"frames": 0, "orders_frames": 0, "quest_frames": 0, "lu_frames": 0, "quest_hits": 0, "plate_frames": 0, "plate_hits": 0, "step": 0.0, "bad_jump": 0.0, "seen_jump": 0.0}
	var last := Rect2()
	var t := 0.0
	while t < seconds:
		await process_frame
		t += cam.get_process_delta_time()
		if retarget and out["frames"] == 3:
			hud.set("_last_target", target)
		var blocks: Dictionary = hud.get("drawn_blocks")
		var lu: Rect2 = blocks.get("levelup", Rect2())
		var quest: Rect2 = blocks.get("quest", Rect2())
		var plate: Rect2 = blocks.get("plate", Rect2())
		out["frames"] += 1
		out["quest_frames"] += 1 if quest.has_area() else 0
		out["orders_frames"] += 1 if quest.has_area() or blocks.has("orders_badge") else 0  # HUDRULES: collapsed, the order is a minimap badge
		out["lu_frames"] += 1 if lu.has_area() else 0
		out["plate_frames"] += 1 if plate.has_area() else 0
		out["quest_hits"] += 1 if lu.has_area() and quest.has_area() and lu.intersects(quest) else 0
		out["plate_hits"] += 1 if lu.has_area() and plate.has_area() and lu.intersects(plate) else 0
		if lu.has_area() and last.has_area():
			var step := absf(lu.position.y - last.position.y) + absf(lu.size.y - last.size.y) + absf(lu.position.x - last.position.x)
			out["step"] = maxf(out["step"], step)
			if step > 40.0:
				out["seen_jump"] = maxf(out["seen_jump"], step)
				if float(cel.get("_in")) > 0.15:
					out["bad_jump"] = maxf(out["bad_jump"], step)
		last = lu
	return out

## LEVELFX2 (canon since 2026-10-28: the left XP feed and the yield card, UIGATHER; status boxes
## beside her, STATUSFX): a real gathering grant that levels gathering, with a status on her. While
## the banners show, no HUD block, hex or feed row sits under them, and the feed rows, status boxes
## and yield card do not jump on the frame a banner appears or goes (they re-place around blocks).
func _test_neighbours(size: Vector2i) -> void:
	await _quiet()
	var start_size := get_root().size
	var start_canvas := get_root().content_scale_size
	get_root().size = size
	get_root().content_scale_size = size
	player.statuses.apply(&"bleed_3")
	await _frames(8)
	var s = player.skills
	var tree := ""
	for tr in ["gathering", "processing", "cooking", "farming", "tailoring", "construction"]:
		if s.level_of(tr) < s.level_cap(tr):
			tree = tr
			break
	_expect(tree != "", "neighbours: a category below its cap to level (%s)" % tree)
	var lv: int = s.level_of(tree)
	hud.toast(&"fiber", 2)
	await _frames(4)
	s.add_xp(tree, s.xp_to_next(lv) - s.xp_of(tree))  # not mirrored: the feed row and pioneer XP too
	var hits := 0
	var hit_what := ""
	var jumps := 0
	var jump_what := ""
	var frames := 0
	var seen_feed := false
	var seen_status := false
	var last: Dictionary = (hud.get("drawn_blocks") as Dictionary).duplicate()  # the boxes and the yield card were up before it
	var was := false
	var t := 0.0
	while t < 3.5:
		await process_frame
		t += cam.get_process_delta_time()
		var blocks: Dictionary = hud.get("drawn_blocks")
		var lu: Rect2 = blocks.get("levelup", Rect2())
		var now := lu.has_area()
		if now:
			frames += 1
			for k in blocks:
				var b: Rect2 = blocks[k]
				seen_feed = seen_feed or str(k).begins_with("skilltoast")
				seen_status = seen_status or str(k) == "statusfx"
				if str(k) != "levelup" and b.has_area() and b.intersects(lu):
					hits += 1
					hit_what = "%s %s" % [k, b]
			for h in hud.get_tree().get_nodes_in_group(&"hex_button"):
				if h.is_visible_in_tree() and h.hex_rect().intersects(lu):
					hits += 1
					hit_what = "hex %s" % h.name
		if now != was:
			for k in last:
				if blocks.has(k) and (str(k).begins_with("skilltoast") or str(k) == "statusfx" or str(k).begins_with("toast")):
					var d: float = (blocks[k] as Rect2).position.distance_to((last[k] as Rect2).position)
					if d > (20.0 if str(k).begins_with("toast") else 1.0):  # TopFeed rows ease (<= 20 px a frame)
						jumps += 1
						jump_what = "%s %.0f px" % [k, d]
		last = blocks.duplicate()
		was = now
	var tag := "%dx%d" % [size.x, size.y]
	_expect(frames > 0 and seen_feed and seen_status, "%s neighbours: a banner shows with the XP feed and the status boxes up (%d frames, feed %s, boxes %s)" % [tag, frames, seen_feed, seen_status])
	_expect(hits == 0, "%s neighbours: nothing of the HUD under the banner (%d, last %s)" % [tag, hits, hit_what])
	_expect(jumps == 0, "%s neighbours: the feed, the boxes and the yield card do not jump as a banner starts or ends (%d, %s)" % [tag, jumps, jump_what])
	player.statuses.clear_all()
	await _quiet()
	get_root().size = start_size
	get_root().content_scale_size = start_canvas
	await _frames(4)

## Owner 2026-10-28: one top-middle column for skill level-ups and gains. A gain's tier comes from its
## traits (grey plain, yellow a positive trait, green a rare one or a rare find); a repeat of a showing
## item collapses into its row; at most max_rows show, the rest wait; a rare trait or find never adds a
## stack by the node beside the row; the skill row stands at the top middle.
func _test_top_feed(size: Vector2i) -> void:
	await _quiet()
	var start_size := get_root().size
	var start_canvas := get_root().content_scale_size
	get_root().size = size
	get_root().content_scale_size = size
	await _frames(4)
	var tag := "%dx%d" % [size.x, size.y]
	var feed = hud.get("top_feed")
	var Stack = load("res://scripts/items/item_stack.gd")
	var tiers := {}
	for spec in [[&"stone", {}], [&"branch", {"firm": 3}], [&"fibre_stalk", {"split_easily": true}]]:
		feed.clear()
		feed.sync(player)
		player.inventory.add(Stack.make(spec[0], 1, spec[1]))
		hud.toast(spec[0], 1)
		tiers[str(spec[0])] = str(feed.rows[0]["tier"]) if not feed.rows.is_empty() else "none"
	_expect(tiers == {"stone": "grey", "branch": "yellow", "fibre_stalk": "green"}, "%s top feed: tiers from traits, plain grey, a positive trait yellow, a rare one green (%s)" % [tag, tiers])
	await _frames(3)
	var row: Rect2 = (hud.get("drawn_blocks") as Dictionary).get("toast0", Rect2())
	var view := Vector2(size)
	var band: Rect2 = load("res://scripts/ui/hud_layout.gd").centre_band(hud, view)
	var cx: float = load("res://scripts/ui/top_feed.gd").column_cx(hud, view)
	_expect(row.has_area() and absf(row.get_center().x - cx) < 2.0 and row.end.y < view.y * 0.6, "%s top feed: the row stands at the top middle (%s, centre %.0f; band %s, figure %s)" % [tag, row, cx, band, hud.call("figure_rect")])
	var hits := 0
	for k in hud.get("drawn_blocks"):
		var b: Rect2 = hud.get("drawn_blocks")[k]
		if str(k) != "toast0" and b.has_area() and b.intersects(row):
			hits += 1
	var stom: Rect2 = hud.get("stomach_rect")
	if stom.has_area() and stom.intersects(row):
		hits += 1
	_expect(hits == 0, "%s top feed: the row keeps off every other HUD block, the orders badge and the stomach ring (%d)" % [tag, hits])
	# Collapse, then the cap.
	feed.clear()
	feed.sync(player)
	player.inventory.add(Stack.make(&"stone", 3, {}))
	hud.toast(&"stone", 3)
	player.inventory.add(Stack.make(&"stone", 2, {}))
	hud.toast(&"stone", 2)
	_expect(feed.rows.size() == 1 and int(feed.rows[0]["n"]) == 5, "%s top feed: +3 then +2 Stone collapse into one +5 row (%d rows, n %s)" % [tag, feed.rows.size(), feed.rows[0]["n"] if not feed.rows.is_empty() else "-"])
	for id in [&"branch", &"fibre_stalk", &"flint", &"resin"]:
		player.inventory.add(Stack.make(id, 1, {}))
		hud.toast(id, 1)
	var cap: int = feed.max_rows(load("res://scripts/ui/ui_tokens.gd").is_compact(view))
	_expect(feed.rows.size() == cap and feed.waiting.size() == 5 - cap, "%s top feed: at most %d rows show, the rest wait (%d showing, %d waiting)" % [tag, cap, feed.rows.size(), feed.waiting.size()])
	# A find lifts its row to green; the node gets no second popup.
	feed.clear()
	feed.sync(player)
	player.inventory.add(Stack.make(&"resin", 1, {}))
	hud.toast(&"resin", 1)
	var GF = load("res://scripts/gather/gather_feedback.gd")
	GF.show_yield(player, player.global_position, &"stone", 1, [&"resin"] as Array[StringName], [&"black_sheen"] as Array[StringName])
	await _frames(2)
	var layer: Node = current_scene.get_node_or_null("GatherPopups") if current_scene else null
	var popups := layer.get_child_count() if layer else 0
	_expect(feed.rows.size() == 1 and feed.rows[0]["tier"] == &"green" and popups == 0, "%s top feed: a rare find turns its row green, one popup per gain (%d rows, tier %s, %d stacks by the node)" % [tag, feed.rows.size(), feed.rows[0]["tier"] if not feed.rows.is_empty() else "-", popups])
	# The skill row at the top middle.
	feed.clear()
	cel.call("push_skill", &"cooking", 3)
	await _frames(4)
	var lu: Rect2 = (hud.get("drawn_blocks") as Dictionary).get("levelup", Rect2())
	if lu.position.y >= view.y * 0.4:
		for k in hud.get("drawn_blocks"):
			print("[t_levelfx] DBG %s %s" % [k, hud.get("drawn_blocks")[k]])
		print("[t_levelfx] DBG rows %s" % [feed.rows.map(func (x): return [x["kind"], x["id"], x.get("y")])])
	_expect(lu.has_area() and absf(lu.get_center().x - cx) < 2.0 and lu.position.y < view.y * 0.4, "%s top feed: a skill level-up is a row at the top middle (%s)" % [tag, lu])
	if not band.has_area():  # the desktop character stack: far left (owner 2026-10-28), off the HUD
		await _quiet()
		player.statuses.apply(&"well_rested")  # HUDRULES: a buff chip in the row under the vitals
		hud.call("_on_level_up", world.pioneer_level)
		await create_timer(0.8).timeout
		var st: Rect2 = (hud.get("drawn_blocks") as Dictionary).get("levelup", Rect2())
		var vit: Rect2 = load("res://scripts/ui/hud_layout.gd").vitals_rect(hud, view)
		var inset: Vector4 = hud.call("_safe_insets")
		var over := 0
		var over_what := ""
		for k in hud.get("drawn_blocks"):
			var b: Rect2 = hud.get("drawn_blocks")[k]
			if str(k) != "levelup" and b.has_area() and b.intersects(st):
				over += 1
				over_what = str(k)
		for h in hud.get_tree().get_nodes_in_group(&"hex_button"):
			if h.is_visible_in_tree() and h.hex_rect().intersects(st):
				over += 1
				over_what = str(h.name)
		_expect(st.has_area() and st.position.x >= inset.w and st.position.x <= vit.position.x + 16.5 and st.position.y >= vit.end.y and st.end.y <= view.y, "%s character stack: it hugs the left edge, under the vitals, inside the view (%s)" % [tag, st])
		var stomach: Rect2 = hud.get("stomach_rect")
		var feed_rows: Array = []
		for k in hud.get("drawn_blocks"):
			if str(k).begins_with("toast"):
				feed_rows.append(hud.get("drawn_blocks")[k])
		_expect(over == 0 and (hud.get("drawn_blocks") as Dictionary).has("statuses"), "%s character stack: nothing of the HUD under it, the buff row up (%d, %s)" % [tag, over, over_what])
		_expect(not stomach.has_area() or (not stomach.intersects(st) and not feed_rows.any(func (b: Rect2) -> bool: return b.intersects(stomach))), "%s: the stomach ring (%s) clear of the stack and the feed" % [tag, stomach])
		player.statuses.clear_all()
	await _quiet()
	get_root().size = start_size
	get_root().content_scale_size = start_canvas
	await _frames(4)

## The old SKILLS rail hex's pulse lands on the MENU hex and the nav menu's Skills badge: a skill
## level-up adds a skills notice, the MENU hex pulses, the open menu's Skills entry shows the badge
## and keeps redrawing while it pulses, and the pulse ends on its own.
func _test_menu_pulse() -> void:
	await _quiet()
	hud.get("field").clear(&"skills")
	var s = player.skills
	var lv: int = s.level_of("butchering")
	s.add_xp("butchering", s.xp_to_next(lv) - s.xp_of("butchering"), true)
	await _frames(3)
	_expect(int(hud.get("field").count(&"skills")) >= 1, "menu pulse: the skill level-up is a MENU skills notice (%d)" % hud.get("field").count(&"skills"))
	_expect(float(cel.call("menu_pulse")) > 0.0, "menu pulse: the MENU hex pulses as the level-up shows (%.2f)" % cel.call("menu_pulse"))
	hud.call("_toggle_sheet", &"menu")
	await _frames(3)
	var nav = hud.get("_sheet")
	_expect(nav != null and nav.get_script() == load("res://scripts/ui/nav_menu.gd") and str(nav.call("badge_text", &"skills")) != "", "menu pulse: the open nav menu's Skills entry carries the badge (%s)" % (nav.call("badge_text", &"skills") if nav else "no menu"))
	var t := 0.0
	while float(cel.call("menu_pulse")) > 0.0 and t < 6.0:
		await process_frame
		t += cam.get_process_delta_time()
	_expect(t < 6.0, "menu pulse: it ends on its own (%.1f s)" % t)
	hud.call("_close_sheet")
	await _quiet()

## SkillState.apply_occupation emits skill_changed (Lv. 20) without a level gained by play: no light.
func _test_occupation() -> void:
	player.skills.apply_occupation("soldier")
	await _frames(4)
	_expect(_fxs().is_empty() and (cel == null or str(cel.call("showing_key")) == ""), "occupation head start: nothing celebrates")

## Frames until `seconds` pass (or, unless `fixed`, until nothing shows or glows): the order the
## celebrations show in, the most lights alive at once, early starts (a celebration replacing one
## that had not faded), the largest move of the drawn block while the same level-up shows, the
## camera's shake offset, trauma and largest per-frame step, and the lights' peak energy.
func _watch(seconds: float, fixed: bool) -> Dictionary:
	var out := {"block_rect": Rect2(), "order": [], "fx_max": 0, "overlaps": 0, "block_jump": 0.0, "blocks": 0, "cam_offset": 0.0, "trauma": 0.0, "cam_step": 0.0, "light_max": 0.0, "char_meshes": 0, "new_meshes": 0}
	var fade := float((_json().get("hud", {}) as Dictionary).get("fade_s", 0.45))
	var t := 0.0
	var last_key := ""
	var last_fading := 0.0
	var last_block := Rect2()
	var last_cam: Vector3 = cam.global_position
	var quiet := 0
	while t < seconds:
		await process_frame
		t += cam.get_process_delta_time()
		var fxs := _fxs()
		out["fx_max"] = maxi(out["fx_max"], fxs.size())
		for fx in fxs:
			var parts := _parts(fx)
			var l: OmniLight3D = parts["light"]
			if l:
				out["light_max"] = maxf(out["light_max"], l.light_energy)
			if str(fx.get("kind")) == "character":
				out["char_meshes"] += 1
				out["new_meshes"] += 0 if parts["spark_mesh"] == _char_mesh else 1
		var key: String = str(cel.call("showing_key")) if cel else ""
		var block: Rect2 = (hud.get("drawn_blocks") as Dictionary).get("levelup", Rect2())
		if key != "" and block.has_area():
			out["blocks"] += 1
			out["block_rect"] = block
			if key == last_key and last_block.has_area():
				out["block_jump"] = maxf(out["block_jump"], block.position.distance_to(last_block.position) + absf(block.size.y - last_block.size.y))
		if key != "" and key != last_key:
			(out["order"] as Array).append(key)
			if last_key != "" and last_fading < fade - 0.1:
				out["overlaps"] += 1
		if key != "":
			var cur: Dictionary = cel.get("current")
			last_fading = float(cur["t"]) - float(cur["out"]) if float(cur["out"]) >= 0.0 else 0.0
		last_key = key if key != "" else last_key
		last_block = block if key != "" else Rect2()
		out["cam_offset"] = maxf(out["cam_offset"], absf(cam.h_offset) + absf(cam.v_offset))
		out["trauma"] = maxf(out["trauma"], float(cam.trauma))
		out["cam_step"] = maxf(out["cam_step"], cam.global_position.distance_to(last_cam))
		last_cam = cam.global_position
		quiet = quiet + 1 if (key == "" and fxs.is_empty()) else 0
		if not fixed and quiet > 5:
			break
	return out

func _parts(fx: Node) -> Dictionary:
	var out := {"meshes": 0, "has_pillar": false, "light": null, "sparks": 0, "spark_mesh": null}
	for c in fx.get_children():
		if c is MeshInstance3D:
			out["meshes"] += 1
			out["has_pillar"] = out["has_pillar"] or (c as MeshInstance3D).mesh is CylinderMesh
		elif c is OmniLight3D:
			out["light"] = c
		elif c is CPUParticles3D:
			out["sparks"] += (c as CPUParticles3D).amount
			out["spark_mesh"] = (c as CPUParticles3D).mesh
		elif c is GPUParticles3D:
			out["sparks"] += (c as GPUParticles3D).amount
	return out

func _fxs() -> Array:
	return get_nodes_in_group(FX_GROUP)

func _json() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_fx.json")) if FileAccess.file_exists("res://data/level_fx.json") else null
	return parsed if parsed is Dictionary else {}

## Ends what still shows and waits out any light.
func _quiet() -> void:
	if cel:
		cel.call("clear")
	var t := 0.0
	while not _fxs().is_empty() and t < 5.0:
		await process_frame
		t += cam.get_process_delta_time()
	await _frames(2)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _finish() -> void:
	if failures.is_empty():
		print("[t_levelfx] PASS")
		quit(0)
		return
	for f in failures:
		print("[t_levelfx] FAIL %s" % f)
	print("[t_levelfx] FAIL count=%d" % failures.size())
	quit(1)
