extends Node
## TUTPERF probe: a fresh new game on the tutorial island, measured in a real window with the real
## camera and HUD. Finishes character creation, times the island build, then samples frames standing
## in town, walking out toward the wild zones and standing in the wild, and prints per phase:
##   [tutperf] PHASE <name> frames fps_min fps_avg frame_p95_ms process_ms physics_ms draws prims nodes
## plus the processing-node census (nodes with _process/_physics_process on, by script).
## Run (windowed, vsync off so frame time is the game's cost, not the display's):
##   Godot --path game --position 6000,3000 --resolution 1600x900 --disable-vsync -- --tutperf-probe --new-game
## (add --tutperf-ablate to also pause one subsystem at a time in town). Headless it still prints the
## counts, build time and process/physics monitors; frame times and draws need the window.
## Quits by itself.

const SETTLE_S := 4.0
const PHASE_S := 10.0

var _host: Node
var _spikes := 0
var _last_fc := 0

class Mark extends Node:
	var tag := ""
	var log: Dictionary
	func _process(_d: float) -> void:
		log["p_" + tag] = Time.get_ticks_usec()
	func _physics_process(_d: float) -> void:
		log["f_" + tag] = Time.get_ticks_usec()
		log["fc_" + tag] = int(log.get("fc_" + tag, 0)) + 1

var _marks := {}

func run(host: Node) -> void:
	_host = host
	for t in ["a", "z"]:
		var m := Mark.new()
		m.tag = t
		m.log = _marks
		m.process_priority = -100000 if t == "a" else 100000
		m.process_physics_priority = -100000 if t == "a" else 100000
		get_tree().root.add_child.call_deferred(m)
	RenderingServer.frame_pre_draw.connect(func () -> void: _marks["r_a"] = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func () -> void: _marks["r_z"] = Time.get_ticks_usec())
	await get_tree().create_timer(1.5).timeout
	var cc := host.get_node_or_null("CharacterCreation") as CharacterCreation
	if cc == null:
		for n in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false):
			cc = n
	if cc:
		cc.select_occupation(str((SkillState.occupations()[0] as Dictionary).get("id", "")))
		cc.naming.field.text = "Perf"
		var t0 := Time.get_ticks_usec()
		cc._finish()
		print("[tutperf] BUILD island=%s build_ms=%.0f" % [World.island_id, float(Time.get_ticks_usec() - t0) / 1000.0])
	var player := PlayerRegistry.local()
	if player == null or not World.is_tutorial():
		print("[tutperf] FAIL no survivor on the tutorial island (island=%s)" % World.island_id)
		get_tree().quit(1)
		return
	await get_tree().create_timer(SETTLE_S).timeout
	_census("town")
	await _phase("town", PHASE_S)
	if "--tutperf-ablate" in OS.get_cmdline_user_args():
		for key in ["card_prop.gd", "harvest_node.gd", "hunt_hud.gd", "*ui", "*all"]:
			var off := _toggle(key, false)
			await get_tree().create_timer(1.0).timeout
			await _phase("town-no-%s(%d)" % [key, off.size()], 4.0)
			for n in off:
				if is_instance_valid(n):
					n.process_mode = Node.PROCESS_MODE_INHERIT
	# Toward the wild zones: the raptor ring sits at ~260 degrees, 300 m from the town.
	var town: Vector3 = player.global_position
	var a := deg_to_rad(260.0)
	var dir := Vector3(cos(a), 0, sin(a))
	var goal := town + dir * 260.0
	player.toggle_sprint()
	player.nav_to(goal)
	await _phase("walk", 20.0, player, goal)
	# Stand out in the wild (teleport the rest of the way so the phase is always measured there).
	var rt: Node = World.runtime
	var p := town + dir * 250.0
	p.y = float(rt.call("surface_y", p.x, p.z)) + 1.0
	player.clear_nav()
	player.global_position = p
	player.reset_physics_interpolation()
	await get_tree().create_timer(SETTLE_S).timeout
	_census("wild")
	await _phase("wild", PHASE_S)
	print("[tutperf] DONE")
	get_tree().quit(0)

func _phase(name: String, seconds: float, player: Node3D = null, goal := Vector3.ZERO) -> void:
	var dts: PackedFloat32Array = []
	var proc := 0.0
	var phys := 0.0
	var draws := 0.0
	var prims := 0.0
	var t := 0.0
	var last := Time.get_ticks_usec()
	while t < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000.0
		last = now
		t += dt / 1000.0
		dts.append(dt)
		var _fc_now := int(_marks.get("fc_a", 0))
		var pr := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += pr
		phys += ph
		if dt > 25.0 and _spikes < 40:
			_spikes += 1
			var mk := _marks
			print("[tutperf] SPIKE %s t=%.2f dt=%.1f proc_span=%.1f phys_span=%.1f(n=%d) draw_span=%.1f process=%.1f physics=%.1f nodes=%d creatures=%d" % [
				name, t, dt, (int(mk.get("p_z", 0)) - int(mk.get("p_a", 0))) / 1000.0,
				(int(mk.get("f_z", 0)) - int(mk.get("f_a", 0))) / 1000.0, int(mk.get("fc_a", 0)) - _last_fc,
				(int(mk.get("r_z", 0)) - int(mk.get("r_a", 0))) / 1000.0, pr, ph, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				get_tree().get_nodes_in_group("creatures").size()])
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		_last_fc = _fc_now
	var n := maxi(dts.size(), 1)
	var sorted := dts.duplicate()
	sorted.sort()
	var p95 := sorted[int(0.95 * float(sorted.size() - 1))] if sorted.size() > 0 else 0.0
	var worst := sorted[sorted.size() - 1] if sorted.size() > 0 else 0.0
	var mean := 0.0
	for d in dts:
		mean += d
	mean /= float(n)
	var moved := ""
	if player != null:
		moved = " dist_to_goal=%.0f" % player.global_position.distance_to(goal)
	print("[tutperf] PHASE %s frames=%d fps_avg=%.1f fps_min=%.1f frame_mean_ms=%.2f frame_p95_ms=%.2f frame_worst_ms=%.1f process_ms=%.2f physics_ms=%.2f draws=%.0f prims=%.0f nodes=%d godot_procs=%s%s" % [
		name, dts.size(), 1000.0 / mean, 1000.0 / maxf(worst, 0.001), mean, p95, worst,
		proc / n, phys / n, draws / n, prims / n,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _load(), moved])

## Nodes that tick every frame, grouped by script: the count every per-frame cost scales with.
func _census(tag: String) -> void:
	var by := {}
	var total := 0
	var stack: Array[Node] = [get_tree().root]
	var particles := 0
	var lights := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is GPUParticles3D or n is CPUParticles3D:
			if (n as Node3D).is_visible_in_tree():
				particles += 1
		if n is Light3D and (n as Node3D).is_visible_in_tree():
			lights += 1
		if (n.is_processing() or n.is_physics_processing()) and n.can_process():
			total += 1
			var s: Script = n.get_script()
			var key: String = s.resource_path.get_file() if s != null else n.get_class()
			by[key] = int(by.get(key, 0)) + 1
	var rows: Array = []
	for k in by:
		rows.append([int(by[k]), k])
	rows.sort_custom(func (x, y) -> bool: return x[0] > y[0])
	var parts: PackedStringArray = []
	for r in rows.slice(0, 18):
		parts.append("%s=%d" % [r[1], r[0]])
	print("[tutperf] CENSUS %s ticking=%d particles=%d lights=%d creatures=%d top: %s" % [
		tag, total, particles, lights, get_tree().get_nodes_in_group("creatures").size(), " ".join(parts)])

func _load() -> String:
	var out := []
	OS.execute("/bin/sh", ["-c", "ps -axo comm | grep -c 'MacOS/Godot$'"], out)
	return str(out[0]).strip_edges() if out.size() > 0 else "?"

## Ablation: pause every node of one script (or "*ui": every Control, "*all": every ticking node but
## this probe and the player) so the phase that follows shows what they cost.
func _toggle(key: String, _on: bool) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n == self or n.process_mode != Node.PROCESS_MODE_INHERIT:
			continue
		var s: Script = n.get_script()
		var file := s.resource_path.get_file() if s != null else ""
		var hit := false
		if key == "*ui":
			hit = n is CanvasItem and not (n is Node3D) and (n.is_processing() or n.is_physics_processing())
		elif key == "*all":
			hit = (n.is_processing() or n.is_physics_processing()) and not (n is Player) and n.get_parent() != get_tree().root
		else:
			hit = file == key
		if hit:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			out.append(n)
	return out
