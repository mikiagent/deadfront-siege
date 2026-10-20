class_name BrainSiege
extends RefCounted
## Owner rule (2026-10-18): wild animals attack player structures that block them. A hunter on
## the survivor or a pet that stops gaining ground, or stands in reach with a structure in the
## line, swings at that structure instead (state siege) until the line opens. Damage goes only
## through a method the structure has: receive_creature_hit(attacker, amount, clip), else a
## catapult's receive_siege_hit(amount). Plain placed buildings have no HP yet, so their swings
## are counted and logged; W2-BUILDSYS adds receive_creature_hit (integrator hook).

const CHECK_EVERY_S := 0.5
const STUCK_S := 2.0
const SWING_CD_S := 1.4

## Swings that reached a structure (labs and tests), and the method the last one used.
static var hit_count: int = 0
static var last_hook: String = ""
static var _logged: Dictionary = {}

var target: Node3D
var _b: CreatureBrain
var _check_at: float = 0.0
var _best_d: float = INF
var _stuck: float = 0.0
var _swing_cd: float = 0.0
var _contact := Vector3.ZERO

func _init(brain: CreatureBrain) -> void:
	_b = brain

func setup() -> void:
	_b.creature.anim.attack_hit.connect(_on_attack_hit)

static func is_structure(n: Node) -> bool:
	for i in 3:
		if n == null:
			return false
		if n.is_in_group("placed_building") or n is FieldCatapult:
			return true
		n = n.get_parent()
	return false

## The structure node (walks up from a collider child).
static func structure_of(n: Node) -> Node3D:
	for i in 3:
		if n == null:
			return null
		if n.is_in_group("placed_building") or n is FieldCatapult:
			return n as Node3D
		n = n.get_parent()
	return null

func tick(dt: float) -> bool:
	if _b.state == &"siege":
		_siege(dt)
		return true
	if not (_b.state == &"approach" or _b.state == &"attack") or not _hunting_owner_side():
		_stuck = 0.0
		_best_d = INF
		return false
	var d := _b._flat_dist(_b.attack_target)
	if d < _best_d - 0.3:
		_best_d = d
		_stuck = 0.0
	else:
		_stuck += dt
	var in_reach := d <= _b.reach_to(_b.attack_target) + 0.1
	var now := _b._now_s()
	if (_stuck < STUCK_S and not in_reach) or now < _check_at:
		return false
	_check_at = now + CHECK_EVERY_S
	var s := _blocking_structure()
	if s == null:
		return false
	target = s
	_swing_cd = 0.0
	_b._set_state(&"siege")
	_b._log("[ai] %s siege %s" % [_b.creature.def.id, s.name])
	return true

func _hunting_owner_side() -> bool:
	var t := _b.attack_target
	return _b._valid_target() and (t is Player or (t is Creature and (t as Creature).is_pet))

## The player structure on the line to the target (knee height, like MeleeQuery), or null.
func _blocking_structure() -> Node3D:
	var c := _b.creature
	var t := _b.attack_target
	var from := Vector3(c.global_position.x, MeleeQuery.feet_y(c) + minf(MeleeQuery.KNEE_M, MeleeQuery.body_height(c) * 0.5), c.global_position.z)
	var to := Vector3(t.global_position.x, MeleeQuery.feet_y(t) + minf(MeleeQuery.KNEE_M, MeleeQuery.body_height(t) * 0.5), t.global_position.z)
	var space := c.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = [c.get_rid()]
	if t is CollisionObject3D:
		exclude.append((t as CollisionObject3D).get_rid())
	for i in EcoSense.RAY_PASSES:
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return null
		var s := structure_of(hit.get("collider") as Node)
		if s:
			_contact = hit.get("position", s.global_position)
			return s
		var col := hit.get("collider") as Node
		if col is StaticBody3D and not (col is Corpse or col is HarvestNode):
			return null  # terrain or a plain wall: not a player structure to break
		exclude.append(hit.get("rid") as RID)
	return null

func _siege(dt: float) -> void:
	var c := _b.creature
	if not is_instance_valid(target) or not _b._valid_target():
		_end()
		return
	var now := _b._now_s()
	if now >= _check_at:
		_check_at = now + CHECK_EVERY_S
		if _blocking_structure() != target:
			_end()  # the line opened (gate, demolished piece) or another piece is in the way
			return
	_swing_cd = maxf(0.0, _swing_cd - dt)
	var stand := c.body_radius() + float(_b.profile.get("attack_range", 1.8)) * 0.5
	if _b._flat_dist_to(_contact) > stand + 0.2:
		c.move_to(_contact)
		return
	c.stop_move()
	c.face_towards(_contact, dt * 3.0)
	if _swing_cd <= 0.0 and not c.anim._busy and c.stagger_left <= 0.0:
		_swing_cd = SWING_CD_S
		c.anim.play_clip(&"attack_heavy" if randf() < 0.3 else &"attack_primary")

func _on_attack_hit(clip: StringName) -> void:
	if _b.state == &"siege" and is_instance_valid(target):
		hit(_b.creature, target, clip)

static func hit(c: Creature, s: Node3D, clip: StringName) -> void:
	var dmg := c.attack_for(false) * c.statuses.attack_mult() * (1.5 if clip == &"attack_heavy" else 1.0)
	hit_count += 1
	if s.has_method("receive_creature_hit"):
		s.call("receive_creature_hit", c, dmg, clip)
		last_hook = "receive_creature_hit"
	elif s.has_method("receive_siege_hit"):
		s.call("receive_siege_hit", dmg)
		last_hook = "receive_siege_hit"
	else:
		last_hook = "none"
		if not _logged.has(s.get_instance_id()):
			_logged[s.get_instance_id()] = true
			print("[eco] structure hit %s by %s dmg=%.0f (no structure HP yet: W2-BUILDSYS hook receive_creature_hit)" % [s.name, c.def.id, dmg])

func _end() -> void:
	target = null
	_stuck = 0.0
	_best_d = INF
	_b._set_state(&"approach" if _b._valid_target() else &"roam")
