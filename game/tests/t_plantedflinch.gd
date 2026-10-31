extends SceneTree
## PLANTEDFLINCH (owner 2026-10-31): "when the ankylosaurus is hit, the feet go through the floor. make it so it is
## rattled but the feet stay planted to the floor. This is likely a fix needed for most dinosaurs".
## Hits every modelled species (CreatureDef.has_model) standing still and records its foot bones (the bones within
## FOOT_BAND of the body's height of the lowest bone, in the pre-hit pose) through the reaction: the authored
## hit_react clip or the procedural flinch. Each foot must stay within TOL_M of where it stood (down = sank into the
## floor, up = lifted, sideways = slid). The same window of plain idle is measured first as the control. Also checks
## the flinch still moves the head (the body is rattled). Dead, ragdoll and knockdown are not hit here.
## Usage: godot --headless --fixed-fps 60 --path game --script res://tests/t_plantedflinch.gd -> "[t_plantedflinch] PASS"

const TOL_M := 0.05
const FOOT_BAND := 0.06
const FRAMES := 60  # 1 s at --fixed-fps 60; the longest hit_react is under that

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
## The pose as drawn: read on skeleton_updated, after the modifiers (outside it a bone reads the animation alone).
var _drawn: Array[Vector3] = []

func _process(_delta: float) -> bool:
	if _started or get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").debug_overlay = false
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_plantedflinch] %s %s" % ["ok  " if ok else "FAIL", msg])

func _run() -> void:
	seed(20261031)
	host = Node3D.new()
	get_root().add_child(host)
	var ids: Array = data.creatures.keys()
	ids.sort()
	var x := 0.0
	for id: StringName in ids:
		if not load("res://scripts/creatures/creature_def.gd").has_model(id):
			continue
		await _probe(id, Vector3(x, 0, 0))
		x += 30.0
	if failures.is_empty():
		print("[t_plantedflinch] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_plantedflinch] FAIL " + f)
		quit(1)

func _bones_world(sk: Skeleton3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in sk.get_bone_count():
		out.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
	return out

## Worst drop, rise and slide of the feet against `base` over FRAMES frames; also the head's largest move.
func _watch(sk: Skeleton3D, feet: Array[int], base: Array[Vector3], head: int) -> Dictionary:
	var r := {"sink": 0.0, "lift": 0.0, "slide": 0.0, "head": 0.0, "slid": ""}
	var head0: Vector3 = base[head] if head >= 0 else Vector3.ZERO
	for f in FRAMES:
		await process_frame
		var now := _drawn
		for b in feet:
			var d: Vector3 = now[b] - base[b]
			r.sink = maxf(r.sink, -d.y)
			r.lift = maxf(r.lift, d.y)
			if Vector2(d.x, d.z).length() > r.slide:
				r.slide = Vector2(d.x, d.z).length()
				r.slid = sk.get_bone_name(b)
		if head >= 0:
			r.head = maxf(r.head, (now[head] - head0).length())
	return r

## A jaw or head bone low enough to graze the floor (the ankylosaurus) is not a foot.
func _under(sk: Skeleton3D, bone: int, head: int) -> bool:
	while bone >= 0:
		if bone == head:
			return true
		bone = sk.get_bone_parent(bone)
	return false

func _probe(id: StringName, at: Vector3) -> void:
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id), &"", 0, null, 0, &"aggressive")
	c.set_physics_process(false)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	for k in 30:
		await process_frame
	if not (c.view.using_glb and c.view.rig and c.view.rig.skeleton):
		_expect(false, "%s has a model but no rig loaded" % id)
		c.queue_free()
		return
	var sk: Skeleton3D = c.view.rig.skeleton
	sk.skeleton_updated.connect(func() -> void: _drawn = _bones_world(sk))
	await process_frame
	var pose := _drawn
	var head: int = sk.find_bone("Head") if sk.find_bone("Head") >= 0 else sk.find_bone("head")
	var lo := INF
	# Not the root (it sits on the floor), not on the head (a low-slung jaw), not an "_end" tip (no skin weights).
	var limb: Array[int] = []
	for i in pose.size():
		if sk.get_bone_parent(i) >= 0 and not _under(sk, i, head) and not sk.get_bone_name(i).ends_with("_end"):
			limb.append(i)
			lo = minf(lo, pose[i].y)
	var feet: Array[int] = []
	for i in limb:
		if pose[i].y <= lo + FOOT_BAND * float(c.def.height_meters):
			feet.append(i)
	var idle: Dictionary = await _watch(sk, feet, pose, -1)
	pose = _drawn
	c.next_hit_kind = &"crit"  # the strongest flinch
	c._on_damaged(1.0, null)
	var how: String = str(c.anim.current_clip) if c.anim.current_clip == &"hit_react" else "flinch"
	if c.brain.get_script().get_global_name() == &"TyrantBrain":
		how = "none (tyrant)"
	var hit: Dictionary = await _watch(sk, feet, pose, head)
	var worst := maxf(hit.sink, maxf(hit.lift, hit.slide))
	var idle_worst := maxf(idle.sink, maxf(idle.lift, idle.slide))  # a shuffling idle is not the hit's doing
	print("[t_plantedflinch] %s via %s: %d feet, sink %.1f cm, lift %.1f cm, slide %.1f cm (%s), head moves %.1f cm (idle control: sink %.1f, lift %.1f, slide %.1f)" % [
		id, how, feet.size(), hit.sink * 100.0, hit.lift * 100.0, hit.slide * 100.0, hit.slid, hit.head * 100.0,
		idle.sink * 100.0, idle.lift * 100.0, idle.slide * 100.0])
	_expect(worst <= TOL_M + idle_worst, "%s feet stay within %.0f cm through the hit (worst %.1f cm, idle %.1f cm)" % [id, TOL_M * 100.0, worst * 100.0, idle_worst * 100.0])
	if how == "flinch":
		_expect(head >= 0 and hit.head >= 0.02 * float(c.def.height_meters), "%s flinch rattles the head (%.1f cm)" % [id, hit.head * 100.0])
	c.queue_free()
	await process_frame
