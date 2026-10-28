extends SceneTree
## W2-RAGDOLL: death ragdolls keep their budget and fall back safely, and the corpse still works.
## Run: Godot --headless --fixed-fps 60 --path game --script res://tests/t_ragdoll.gd
## Prints "[t_ragdoll] PASS" and exits 0, or FAIL lines and exits 1.

var failures: Array[String] = []
var _started := false
var data: Node
var R: GDScript  # Ragdoll, loaded after the autoloads exist

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	R = load("res://scripts/creatures/ragdoll.gd")
	_run()
	return false

func _run() -> void:
	_floor()
	await _test_budget_fallback()
	await _test_missing_profile()
	await _test_injected_nan()
	await _test_abort_lies_down()
	await _test_abort_late_lies_down()
	await _test_cancel_lies_down()
	await _test_blow_directions()
	await _test_settle_depth()
	await _test_corpse_after_ragdoll()
	await _test_placeholder_body()
	_test_seam()
	await _test_server_seam()
	if failures.is_empty():
		print("[t_ragdoll] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_ragdoll] FAIL " + f)
		quit(1)

func _expect(ok: bool, what: String) -> void:
	print("[t_ragdoll] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _floor() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	body.add_child(cs)
	body.position.y = -0.5
	root.add_child(body)

func _spawn(id: StringName, at: Vector3):
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	root.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _kill(c) -> void:
	c.health.take_damage(c.health.hp + 1.0, null)

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second

func _ragdoll(c) -> Node:
	return c.get_node_or_null("Ragdoll")

func _wait_frozen(cs: Array, cap_s: float = 8.0) -> void:
	var t := 0.0
	while t < cap_s:
		var all := true
		for c in cs:
			var rd = _ragdoll(c)
			if rd == null or rd.phase != &"frozen":
				all = false
		if all:
			return
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second

func _free_all(cs: Array) -> void:
	for c in cs:
		if is_instance_valid(c):
			c.queue_free()
	for n in root.get_children():
		if n.is_in_group("corpse"):
			n.queue_free()
	await process_frame

## Five deaths in the same frame: the budget (4) simulates four, the fifth plays the death clip.
func _test_budget_fallback() -> void:
	var cs: Array = []
	for k in 5:
		cs.append(_spawn(&"velociraptor", Vector3(k * 30.0, 0.05, 0.0)))
	await _wait(0.3)
	for c in cs:
		_kill(c)
	await _wait(0.6)
	var ragdolls := 0
	var budget_fallbacks := 0
	for c in cs:
		var rd = _ragdoll(c)
		if rd and rd.mode == &"ragdoll":
			ragdolls += 1
		elif rd and rd.mode == &"fallback" and str(rd.reason).begins_with("budget"):
			budget_fallbacks += 1
	_expect(ragdolls == 4 and budget_fallbacks == 1, "5 simultaneous deaths: 4 ragdolls + 1 budget fallback (got %d + %d)" % [ragdolls, budget_fallbacks])
	_expect(R.active_count() <= 4, "never more than 4 simulating (%d)" % R.active_count())
	await _wait_frozen(cs)
	var frozen := 0
	for c in cs:
		var rd = _ragdoll(c)
		if rd and rd.phase == &"frozen" and c.find_children("*", "PhysicalBone3D", true, false).is_empty() and not c.anim.tree.active:
			frozen += 1
	_expect(frozen == 5, "all five frozen with no physical bones and no animation left (%d)" % frozen)
	_expect(R.active_count() == 0, "budget released after the freeze (%d)" % R.active_count())
	await _free_all(cs)

## A species without a profile falls back to the death clip and still settles its corpse.
func _test_missing_profile() -> void:
	var species: Dictionary = R.data()["species"]
	var saved = species.get("velociraptor")
	species.erase("velociraptor")
	var c = _spawn(&"velociraptor", Vector3(0, 0.05, 60.0))
	await _wait(0.3)
	_kill(c)
	await _wait(0.5)
	var rd = _ragdoll(c)
	_expect(rd != null and rd.mode == &"fallback" and rd.reason == "no profile", "missing profile -> fallback (%s)" % (rd.reason if rd else "no ragdoll"))
	_expect(c.anim.tree.active, "fallback keeps playing the death clip")
	species["velociraptor"] = saved
	await _wait_frozen([c])
	_expect(rd != null and rd.phase == &"frozen", "fallback freezes when the clip ends")
	var corpse = rd.corpse if rd else null
	_expect(corpse != null and absf(corpse.global_position.y) < 0.02, "fallback corpse sits on the terrain under the hips (y=%.3f)" % (corpse.global_position.y if corpse else -1.0))
	await _free_all([c])

## A NaN mid-simulation aborts to the fallback: physics freed, IK feet re-parented back, clip resumed.
func _test_injected_nan() -> void:
	R.inject_fault = &"nan"
	var c = _spawn(&"velociraptor", Vector3(60.0, 0.05, 60.0))
	var sk: Skeleton3D = c.view.rig.skeleton
	var foot: int = sk.find_bone("BackFoot.L")
	var parent_before: int = sk.get_bone_parent(foot)
	await _wait(0.3)
	_kill(c)
	R.inject_fault = &""
	await _wait(0.8)
	var rd = _ragdoll(c)
	_expect(rd != null and rd.mode == &"fallback" and str(rd.reason).begins_with("NaN"), "injected NaN -> fallback (%s)" % (rd.reason if rd else "no ragdoll"))
	_expect(c.find_children("*", "PhysicalBone3D", true, false).is_empty(), "aborted ragdoll freed its physical bones")
	_expect(sk.get_bone_parent(foot) == parent_before, "IK foot back under its original parent")
	_expect(R.active_count() == 0, "aborted ragdoll left the budget")
	await _wait_frozen([c])
	_expect(rd != null and rd.phase == &"frozen", "NaN fallback still freezes")
	await _free_all([c])

## A simulation that aborts on its first frame (the stretch guard at hand-off) still ends lying on
## the ground: the death clip restarts where it would be and plays to its end, then the conform.
func _test_abort_lies_down() -> void:
	var c = _spawn(&"velociraptor", Vector3(-60.0, 0.05, -60.0))
	var sk: Skeleton3D = c.view.rig.skeleton
	var hips: int = sk.find_bone("Hips")
	await _wait(0.3)
	var stand: float = (sk.global_transform * sk.get_bone_global_pose(hips).origin).y
	R.inject_fault = &"abort"
	_kill(c)
	R.inject_fault = &""
	await _wait_frozen([c])
	var rd = _ragdoll(c)
	_expect(rd != null and rd.mode == &"fallback" and str(rd.reason).begins_with("injected abort"), "first-frame abort -> fallback (%s)" % (rd.reason if rd else "no ragdoll"))
	var lying: float = (sk.global_transform * sk.get_bone_global_pose(hips).origin).y
	_expect(lying <= stand * 0.5, "aborted ragdoll lies down after the clip (hips %.2f m, standing %.2f m)" % [lying, stand])
	var gap := 1.0
	if rd and rd.mesh_instance():
		var skin: GDScript = load("res://scripts/creatures/ragdoll_skin.gd")
		var cl: Dictionary = skin.clearance(c.get_world_3d().direct_space_state, skin.posed_points(rd.mesh_instance(), sk, 7), [rd.corpse.get_rid()] as Array[RID])
		gap = float(cl["min"])
	_expect(absf(gap) <= 0.06, "aborted ragdoll's lowest skin vertex on the ground (%+.3f m)" % gap)
	await _free_all([c])

## An abort deep into the simulation (a body over the speed guard, a joint that tore at 0.6 s) must
## also end lying down: the death clip takes over where it would be and the conforming lays it out.
func _test_abort_late_lies_down() -> void:
	var c = _spawn(&"velociraptor", Vector3(-20.0, 0.05, -60.0))
	var sk: Skeleton3D = c.view.rig.skeleton
	var hips: int = sk.find_bone("Hips")
	await _wait(0.3)
	var stand: float = (sk.global_transform * sk.get_bone_global_pose(hips).origin).y
	R.inject_abort_at_s = 0.6
	_kill(c)
	await _wait_frozen([c])
	R.inject_abort_at_s = -1.0
	var rd = _ragdoll(c)
	var why: String = str(rd.reason) if rd else "no ragdoll"
	_expect(rd != null and rd.mode == &"fallback" and why.begins_with("injected abort at 0.6"), "abort at 0.6 s -> fallback (%s)" % why)
	_expect(rd != null and rd.phase == &"frozen" and not c.anim.tree.active, "the aborted body stops on the death clip pose")
	var lying: float = (sk.global_transform * sk.get_bone_global_pose(hips).origin).y
	_expect(lying <= stand * 0.5, "late abort lies down (hips %.2f m, standing %.2f m)" % [lying, stand])
	var gap := 1.0
	if rd and rd.mesh_instance():
		var skin: GDScript = load("res://scripts/creatures/ragdoll_skin.gd")
		var cl: Dictionary = skin.clearance(c.get_world_3d().direct_space_state, skin.posed_points(rd.mesh_instance(), sk, 7), [rd.corpse.get_rid()] as Array[RID])
		gap = float(cl["min"])
	_expect(absf(gap) <= 0.06, "late abort's lowest skin vertex on the ground (%+.3f m)" % gap)
	await _free_all([c])

## A ragdoll cancelled mid-simulation (the presentation was abandoned) must not leave the body in
## the half-simulated pose, standing: it lands on the death clip's last frame straight away.
func _test_cancel_lies_down() -> void:
	var c = _spawn(&"velociraptor", Vector3(-20.0, 0.05, 0.0))
	var sk: Skeleton3D = c.view.rig.skeleton
	var hips: int = sk.find_bone("Hips")
	await _wait(0.3)
	var stand: float = (sk.global_transform * sk.get_bone_global_pose(hips).origin).y
	_kill(c)
	await _wait(0.9)  # mid-simulation
	var rd = _ragdoll(c)
	_expect(rd != null and rd.phase == &"simulate", "cancelled case is mid-simulation (%s)" % (rd.phase if rd else "no ragdoll"))
	if rd:
		rd.cancel()
	await _wait(0.4)
	if rd:
		_expect(rd.phase == &"frozen" and rd.mode == &"fallback" and rd.reason == "cancelled", "cancel lands at once (%s/%s)" % [rd.phase, rd.reason])
		_expect(c.find_children("*", "PhysicalBone3D", true, false).is_empty(), "cancel freed the physical bones")
	_expect(not c.anim.tree.active, "a cancelled ragdoll does not leave the clip running")
	var lying: float = (sk.global_transform * sk.get_bone_global_pose(hips).origin).y
	_expect(lying <= stand * 0.5, "cancelled ragdoll lies down (hips %.2f m, standing %.2f m)" % [lying, stand])
	var gap := 1.0
	if rd and rd.mesh_instance():
		var skin: GDScript = load("res://scripts/creatures/ragdoll_skin.gd")
		var cl: Dictionary = skin.clearance(c.get_world_3d().direct_space_state, skin.posed_points(rd.mesh_instance(), sk, 7), [rd.corpse.get_rid()] as Array[RID])
		gap = float(cl["min"])
	_expect(absf(gap) <= 0.06, "cancelled ragdoll's lowest skin vertex on the ground (%+.3f m)" % gap)
	await _free_all([c])

## A blow from the front, the back, the left or the right topples the body AWAY from it: the
## carcass' hips end displaced along the blow's push (the way the body was shoved), never back
## toward the attacker.
func _test_blow_directions() -> void:
	# Facing -Z (the creature's forward), its right is +X.
	var blows := {
		"left": Vector3.RIGHT, "right": Vector3.LEFT,
		"front": Vector3.BACK, "back": Vector3.FORWARD,
	}
	var at := Vector3(-90.0, 0.05, 0.0)
	for name: String in blows:
		var push: Vector3 = blows[name]  # where the body is shoved, in creature space
		var src := Node3D.new()
		root.add_child(src)
		src.global_position = at - push * 3.0
		var c = _spawn(&"velociraptor", at)
		var sk: Skeleton3D = c.view.rig.skeleton
		var hips: int = sk.find_bone("Hips")
		await _wait(0.4)
		var stand: Vector3 = sk.global_transform * sk.get_bone_global_pose(hips).origin
		c.health.take_damage(c.health.hp + 1.0, src)
		await _wait_frozen([c])
		var rd = _ragdoll(c)
		var rest: Vector3 = sk.global_transform * sk.get_bone_global_pose(hips).origin
		var moved := Vector2(rest.x - stand.x, rest.z - stand.z)
		var along := moved.dot(Vector2(push.x, push.z))
		_expect(rd != null and rd.phase == &"frozen", "%s blow freezes (%s)" % [name, rd.phase if rd else "no ragdoll"])
		# The whole body's centre of mass, from every posed bone: where the carcass ended up.
		var cen := Vector3.ZERO
		for bi in sk.get_bone_count():
			var bp: Vector3 = sk.global_transform * sk.get_bone_global_pose(bi).origin
			cen += Vector3(bp.x - stand.x, 0.0, bp.z - stand.z)
		cen /= float(maxi(1, sk.get_bone_count()))
		# The trunk's up axis: a body that fell onto its far flank points it away from the blow.
		var trunk: int = sk.find_bone("Body")
		var upv: Vector3 = (sk.global_transform.basis * sk.get_bone_global_pose(trunk).basis.y).normalized()
		var up_push := Vector2(upv.x, upv.z).dot(Vector2(push.x, push.z))
		print("[t_ragdoll] %s blow: hips %+.2f m, centre %+.2f m, up axis %+.2f along the shove" % [name, along, cen.dot(push), up_push])
		_expect(along > 0.0 and cen.dot(push) >= 0.3, "%s blow topples the body away from it (centre %.2f m along the shove, hips %.2f m)" % [name, cen.dot(push), along])
		_expect(up_push > -0.2, "%s blow does not tip the body's up axis back toward the attacker (%.2f)" % [name, up_push])
		if name in ["left", "right"]:
			_expect(up_push >= 0.5, "%s flank blow lays the body onto its far flank (up axis %.2f along the shove)" % [name, up_push])
		await _free_all([c])
		src.queue_free()
		await process_frame

## Every species with a ragdoll profile settles ON the ground, not in it: the lowest point of its
## posed skin (the mesh's own vertices, dense sample) is at most SETTLE_DEPTH_M under the terrain.
## The T. rex used to sink 0.66 m (head and neck buried, tail up).
const SETTLE_DEPTH_M := 0.08  # ASSUMPTION: how far a carcass may cut into the terrain at its lowest point

func _test_settle_depth() -> void:
	var species: Dictionary = R.data()["species"]
	var at := Vector3(120.0, 0.05, 0.0)
	var worst := ""
	var worst_gap := 0.0
	for id in species:
		var sid := StringName(id)
		if data.creature(sid) == null:
			continue
		var c = _spawn(sid, at)
		var src: Node3D = null
		if sid == &"tyrannosaurus":
			c.rotation.y = PI  # the review's case: heading 180, hit from its flank (-X)
			src = Node3D.new()
			root.add_child(src)
			src.global_position = at - Vector3.RIGHT * 3.0
		await _wait(0.4)
		var sk: Skeleton3D = c.view.rig.skeleton if c.view.using_glb and c.view.rig else null
		# The review's T. rex case was a blow from its flank (source at -X, heading 180): it buried
		# its head and neck. Every other species is killed with no attacker (a blow from behind).
		if src:
			c.health.take_damage(c.health.hp + 1.0, src)
		else:
			_kill(c)
		await _wait_frozen([c])
		var rd = _ragdoll(c)
		var gap := -99.0
		if sk and rd and rd.mesh_instance():
			var skin: GDScript = load("res://scripts/creatures/ragdoll_skin.gd")
			var pts: PackedVector3Array = skin.posed_points(rd.mesh_instance(), sk, 3)
			var cl: Dictionary = skin.clearance(c.get_world_3d().direct_space_state, pts, [rd.corpse.get_rid()] as Array[RID], 1, 2.0, SETTLE_DEPTH_M)
			gap = float(cl["min"])
			_expect(int(cl["hits"]) > 0, "%s: the ground was found under its skin (%d samples)" % [id, int(cl["hits"])])
		elif rd and rd.mode == &"fallback":
			gap = -(rd as Node).call("_box_gap", c.get_world_3d().direct_space_state)
		_expect(rd != null and rd.phase == &"frozen", "%s froze (%s)" % [id, rd.phase if rd else "no ragdoll"])
		_expect(gap >= -SETTLE_DEPTH_M, "%s settles on the ground (lowest point %+.3f m, max %+.2f)" % [id, gap, -SETTLE_DEPTH_M])
		if sid == &"tyrannosaurus":
			_expect(rd != null and rd.mode == &"ragdoll", "the T. rex flank blow simulates a ragdoll (%s)" % (rd.reason if rd else "-"))
		if gap < worst_gap:
			worst_gap = gap
			worst = id
		if sid == &"tyrannosaurus":
			var corpse = rd.corpse if rd else null
			var inv = load("res://scripts/items/inventory.gd").new(8)
			_expect(corpse != null and not corpse.loot_options(inv).is_empty(), "the settled T. rex is still harvestable (%d stacks)" % (corpse.loot.used_slots() if corpse else 0))
		await _free_all([c])
		if src:
			src.queue_free()
		if id == "tyrannosaurus":
			print("[t_ragdoll] settle depth worst so far: %s %+.3f m" % [worst, worst_gap])
	await _free_all([])

## After a real ragdoll the corpse keeps its loot, its knife rule and its take path.
func _test_corpse_after_ragdoll() -> void:
	var c = _spawn(&"velociraptor", Vector3(-60.0, 0.05, 0.0))
	await _wait(0.3)
	_kill(c)
	await _wait_frozen([c])
	var rd = _ragdoll(c)
	_expect(rd != null and rd.mode == &"ragdoll" and rd.phase == &"frozen", "ragdoll froze (%s)" % (rd.reason if rd else "-"))
	var corpse = rd.corpse if rd else null
	_expect(corpse != null and corpse.loot.used_slots() > 0, "corpse has loot after the ragdoll")
	if corpse:
		var inv = load("res://scripts/items/inventory.gd").new(8)
		_expect(corpse.can_butcher(inv) == "need tool knife", "butchering still needs a knife")
		var opts: Array = corpse.loot_options(inv)
		_expect(not opts.is_empty(), "loot options listed (%d)" % opts.size())
		var before: int = corpse.loot.used_slots()
		var taken = corpse.take_slot(int(opts[0]["slot"]), null)
		_expect(taken != null and corpse.loot.used_slots() == before - 1, "take_slot moves one stack out")
		var flat := Vector2(corpse.global_position.x - c.global_position.x, corpse.global_position.z - c.global_position.z).length()
		_expect(flat < 0.01 and absf(corpse.global_position.y) < 0.05, "corpse at the body's resting point on the ground")
	await _free_all([c])

## The in-game stegosaurus is a box placeholder with no skeleton: death clip, then the body's lowest
## box sits on the ground and the corpse is placed (no ragdoll, no crash).
func _test_placeholder_body() -> void:
	var c = _spawn(&"stegosaurus", Vector3(60.0, 0.05, -60.0))
	_expect(not c.view.using_glb, "stegosaurus is the placeholder in game")
	await _wait(0.3)
	_kill(c)
	await _wait_frozen([c])
	var rd = _ragdoll(c)
	_expect(rd != null and rd.mode == &"fallback" and rd.reason == "no skeleton" and rd.phase == &"frozen", "placeholder -> fallback (%s)" % (rd.reason if rd else "-"))
	var corpse = rd.corpse if rd else null
	_expect(corpse != null and absf(corpse.global_position.y) < 0.02, "placeholder corpse on the ground")
	await _free_all([c])

## place_settled is the one seam for the corpse's authoritative position: corpse and body move.
func _test_seam() -> void:
	var c = _spawn(&"velociraptor", Vector3(-60.0, 0.05, 60.0))
	var corpse = load("res://scripts/creatures/corpse.gd").new()
	corpse.setup(c)
	root.add_child(corpse)
	var p := Vector3(-55.0, 0.0, 61.0)
	corpse.place_settled(p)
	_expect(corpse.global_position.is_equal_approx(p) and c.global_position.is_equal_approx(p), "place_settled moves corpse and body")
	corpse.free()
	c.free()

## A server placement wins: the client's ragdoll result does not move the corpse afterwards, and the
## frozen body is moved to the server's spot with its pose.
func _test_server_seam() -> void:
	var c = _spawn(&"velociraptor", Vector3(90.0, 0.05, 90.0))
	await _wait(0.3)
	_kill(c)
	await _wait(0.5)
	var rd = _ragdoll(c)
	var p := Vector3(92.0, 0.0, 93.0)
	rd.corpse.place_settled(p, true)
	rd.corpse.place_settled(Vector3(80.0, 0.0, 80.0))
	_expect(rd.corpse.global_position.is_equal_approx(p), "a client placement after the server's is ignored")
	await _wait_frozen([c])
	var flat := Vector2(c.global_position.x - p.x, c.global_position.z - p.z).length()
	_expect(rd.corpse.global_position.is_equal_approx(p) and flat < 0.01, "the frozen body and corpse rest at the server's spot (%.2f m off)" % flat)
	await _free_all([c])
