class_name AttackKit
extends RefCounted
## Species special moves (brain.kit), tuned in ai.json attack_kits and listed per species in
## ai.json species.<id>.attacks: spit (ranged glob), charge (straight dash, knockback), tail_sweep
## (rear arc around the body), lunge (dash then the heavy bite, not a pounce in place) and roar
## (deafens the survivor, scatters grazers). One move at a time: windup (telegraph), active,
## recover. While one runs the brain resolves it every physics frame (CreatureBrain._full_rate).

## Times each kind started (labs and tests read it).
var used: Dictionary = {}
var move: Dictionary = {}
var phase: StringName = &""
var left: float = 0.0
var _b: CreatureBrain
var _rows: Array[Dictionary] = []
var _ready_at: Dictionary = {}
var _dir := Vector3.FORWARD
var _from := Vector3.ZERO
var _target: Node3D
var _tele: Node3D
var _struck: Array[Node] = []

func _init(brain: CreatureBrain) -> void:
	_b = brain

## Parsed after the brain has its profile.
func setup() -> void:
	_rows = rows_for(_b.profile)
	_b.creature.anim.attack_hit.connect(_on_attack_hit)

## The species' attack rows: each listed kind's attack_kits row with the species' overrides merged.
static func rows_for(profile: Dictionary) -> Array[Dictionary]:
	var kits: Dictionary = Data.creature_ai.get("attack_kits", {})
	var out: Array[Dictionary] = []
	var listed: Variant = profile.get("attacks", [])
	if not listed is Array:
		return out
	for a in listed:
		var kind := str((a as Dictionary).get("kind", "")) if a is Dictionary else str(a)
		var base: Variant = kits.get(kind)
		if not base is Dictionary:
			continue
		var row := (base as Dictionary).duplicate()
		if a is Dictionary:
			row.merge(a as Dictionary, true)
		row["kind"] = kind
		out.append(row)
	return out

func kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in _rows:
		out.append(StringName(str(r["kind"])))
	return out

func busy() -> bool:
	return not move.is_empty()

## Seconds until this kind is off cooldown (0 = ready).
func ready_in(kind: StringName) -> float:
	return maxf(0.0, float(_ready_at.get(str(kind), 0.0)) - _b._now_s())

## Locomotion while a move runs (CreatureBrain.move_speed).
func move_speed(base: float) -> float:
	if phase == &"active":
		return base * float(move.get("speed_mult", 1.0))
	return base

## One think: resolve the running move, or start one that fits. True when it handled the tick.
func tick(dt: float) -> bool:
	if busy():
		_run(dt)
		return true
	return _try_start()

func _try_start() -> bool:
	if _rows.is_empty() or not (_b.state == &"approach" or _b.state == &"attack") or not _b._valid_target():
		return false
	var c := _b.creature
	if c.anim._busy or c.stagger_left > 0.0 or not c.statuses.can_act():
		return false
	var t := _b.attack_target
	if not (t is Player or t is Creature):
		return false
	var d := _b._flat_dist(t)
	var now := _b._now_s()
	for row in _rows:
		var kind := str(row["kind"])
		if now < float(_ready_at.get(kind, 0.0)):
			continue
		if d < float(row.get("range_min", 0.0)) or d > float(row.get("range_max", 0.0)):
			continue
		if not _fits(kind, row, t):
			continue
		_begin(row, t)
		return true
	return false

func _fits(kind: String, row: Dictionary, t: Node3D) -> bool:
	match kind:
		"spit", "charge", "lunge":
			return EcoSense.clear_ray(_b.creature, t)
		"tail_sweep":
			return true  # the body turns its tail to the target during the windup
		"roar":
			return t is Player and not (t as Player).statuses.has(StringName(str(row.get("status", "deafened"))))
	return false

func _rear_dot(t: Node3D) -> float:
	var to := t.global_position - _b.creature.global_position
	to.y = 0.0
	var fwd := -_b.creature.global_basis.z
	fwd.y = 0.0
	if to.length_squared() < 0.0001 or fwd.length_squared() < 0.0001:
		return 1.0
	return fwd.normalized().dot(to.normalized())

func _begin(row: Dictionary, t: Node3D) -> void:
	var c := _b.creature
	var kind := str(row["kind"])
	move = row
	_target = t
	_struck.clear()
	used[kind] = int(used.get(kind, 0)) + 1
	_ready_at[kind] = _b._now_s() + float(row.get("cooldown_s", 5.0))
	_from = c.global_position
	var to := t.global_position - c.global_position
	to.y = 0.0
	_dir = to.normalized() if to.length_squared() > 0.0001 else -c.global_basis.z
	c.stop_move()
	if kind != "tail_sweep":
		c.face_towards(t.global_position, 1.0)
	phase = &"windup"
	left = float(row.get("windup_s", 0.5))
	_b._set_state(StringName(kind))
	match kind:
		"spit":
			c.anim.play_clip(&"attack_primary")  # the primary's own hit frame is out of reach here
		"charge":
			c.anim.play_clip(&"alert")
			_tele = _lane(c, _dir, _b._flat_dist(t) + 3.0, c.body_radius() * 2.0 + 0.6, left)
		"tail_sweep":
			# The ring lasts through the strike (freed on recover), so a roll on the impact counts.
			var tele := Telegraph.show_tyrant(c, _sweep_radius(), left + 1.6, &"attack_heavy")
			for ch in tele.get_children():
				if ch is Label3D:
					(ch as Label3D).text = "TAIL - ROLL OR BACK OFF"
			_tele = tele
		"roar":
			c.anim.play_clip(&"alert")
	_b._log("[ai] %s %s at %.1fm" % [c.def.id, kind, _b._flat_dist(t)])

func _run(dt: float) -> void:
	var c := _b.creature
	var kind := str(move.get("kind", ""))
	# The leash, a knockdown or death took the brain elsewhere: drop the move quietly.
	if _b.state != StringName(kind) or not is_instance_valid(_target):
		_abort()
		return
	left -= dt
	match phase:
		&"windup":
			if kind == "spit" or kind == "roar":
				c.face_towards(_target.global_position, dt * 3.0)
			elif kind == "tail_sweep":
				c.face_towards(c.global_position * 2.0 - _target.global_position, dt * 3.0)  # tail to the target
			if left > 0.0:
				return
			_release(kind)
		&"active":
			_active(kind, dt)
		&"strike":
			c.stop_move()
			if left <= 0.0:
				_recover()  # the clip never reported its hit frame
		&"recover":
			c.stop_move()
			if left <= 0.0:
				_finish()

func _release(kind: String) -> void:
	var c := _b.creature
	match kind:
		"spit":
			SpitProjectile.launch(c, _target, float(move.get("speed_mps", 10.0)), float(move.get("hit_radius_m", 0.3)), StringName(str(move.get("clip", "attack_heavy"))))
			_recover()
		"roar":
			_roar()
			phase = &"recover"
			left = float(move.get("hold_s", 1.2))
		"tail_sweep":
			var clip := &"tail_swipe" if c.anim._param.has(&"tail_swipe") else &"attack_heavy"
			c.anim.play_clip(clip)
			phase = &"strike"
			left = 1.5  # fallback if the clip never reports its hit frame
		_:
			phase = &"active"
			left = float(move.get("max_s", 1.0))
			_clear_tele()

func _active(kind: String, dt: float) -> void:
	var c := _b.creature
	var reach := _b.reach_to(_target)
	if kind == "lunge":
		c.move_to(_target.global_position)
		if _b._flat_dist(_target) <= reach - 0.2 or left <= 0.0:
			c.stop_move()
			c.anim.play_clip(&"attack_heavy")  # the pounce bite lands through the normal hit frame
			phase = &"strike"
			left = 1.5
		return
	# charge: a straight line from where it started; no homing
	c.move_to(_from + _dir * 40.0)
	for victim in _victims(c.body_radius() + 1.0):
		_charge_hit(victim)
	if not _struck.is_empty() or left <= 0.0:
		_recover()

## Horns at contact: the heavy hit (statuses, hit roll) plus the shove. A rolling survivor slips it.
func _charge_hit(victim: Node3D) -> void:
	if victim in _struck:
		return
	_struck.append(victim)
	if victim is Player and (victim as Player).rolling:
		return
	var c := _b.creature
	if CreatureAttack.apply_for(c, &"attack_heavy", victim) and victim is Player:
		(victim as Player).receive_creature_hit(c, &"attack_heavy")
	Knockback.push(victim, _dir, float(move.get("knockback_m", 3.0)), 0.3)

## Bodies the move can hit within r of the attacker: its target, and for a wild animal the
## survivor and live pets (not other wild animals).
func _victims(r: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var c := _b.creature
	var cands: Array[Node3D] = [_target]
	var p := c.get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead:
		cands.append(p)
		for pet in p.live_pets():
			cands.append(pet)
	for v in cands:
		if v == null or not is_instance_valid(v) or v in out:
			continue
		if v is Creature and ((v as Creature).health.dead or v == c):
			continue
		if v is Player and (v as Player).dead:
			continue
		if MeleeQuery.surface_gap(c, v) <= r - c.body_radius():
			out.append(v)
	return out

func _sweep_radius() -> float:
	return _b.creature.body_radius() + float(move.get("radius_extra_m", 2.5))

## The anim's hit frame. Lunge damage already went through Creature._on_hit; the sweep adds every
## other body in its rear arc and shoves them.
func _on_attack_hit(_clip: StringName) -> void:
	if phase != &"strike":
		return
	if str(move.get("kind", "")) == "tail_sweep":
		var c := _b.creature
		var r := _sweep_radius()
		for v in _victims(r):
			if _rear_dot(v) >= float(move.get("rear_dot", 0.3)):
				continue
			# Creature._on_hit already landed this swing on a target inside its own reach.
			if v == _b.attack_target and _b._flat_dist(v) <= _b.reach_to(v) + 0.3:
				continue
			if CreatureAttack.apply_for(c, &"attack_heavy", v) and v is Player:
				(v as Player).receive_creature_hit(c, &"attack_heavy")
			var away := v.global_position - c.global_position
			Knockback.push(v, away, float(move.get("knockback_m", 1.5)), 0.25)
	_recover()

func _roar() -> void:
	var c := _b.creature
	var status := StringName(str(move.get("status", "deafened")))
	var r := float(move.get("range_max", 14.0))
	var p := c.get_tree().get_first_node_in_group("player") as Player
	if p and not p.dead and c.global_position.distance_to(p.global_position) <= r:
		p.statuses.apply(status, c)
	var fear := float(move.get("fear_m", r))
	for n in c.get_tree().get_nodes_in_group("creatures"):
		var o := n as Creature
		if o == null or o == c or o.is_pet or o.health.dead or o.brain == null or not o.brain._is_herbivore():
			continue
		if o.global_position.distance_to(c.global_position) <= fear and o.brain.state in CreatureBrain.CALM_STATES:
			o.brain._spot(c)

func _recover() -> void:
	_clear_tele()
	phase = &"recover"
	left = float(move.get("recover_s", 0.5))
	_b.creature.stop_move()

func _finish() -> void:
	_clear_tele()
	move = {}
	phase = &""
	_target = null
	_b._set_state(&"approach" if _b._valid_target() else &"roam")

func _abort() -> void:
	_clear_tele()
	move = {}
	phase = &""
	_target = null

func _clear_tele() -> void:
	if is_instance_valid(_tele):
		_tele.queue_free()
	_tele = null

## Flat yellow lane on the ground: where the charge will run.
static func _lane(c: Creature, dir: Vector3, length: float, width: float, life: float) -> Node3D:
	var m := MeshInstance3D.new()
	m.name = "ChargeLane"
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.04, length)
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.9, 0.2, 0.45)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.get_parent().add_child(m)
	m.global_position = c.global_position + dir * (length * 0.5) + Vector3.UP * 0.06
	m.look_at(m.global_position + dir, Vector3.UP)
	c.get_tree().create_timer(life + 1.6).timeout.connect(m.queue_free)
	return m
