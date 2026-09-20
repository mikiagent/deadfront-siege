class_name Hunt
extends Node
## Auto-attack overlay plus Body Tackle / Kick / Roll / Net.

signal started(target: Creature)
signal ended

var target: Creature
var hold: bool = false
var auto: bool = true  # HUD Auto hexagon: auto-attack when in range
var _ring: MeshInstance3D
var _swing_cd: float = 0.0
var _tackle_cd: float = 0.0
var _kick_cd: float = 0.0
var _net_cd: float = 0.0
var player: Player

func setup(p: Player) -> void:
	player = p

func start(t: Creature) -> void:
	if t == null or t.health.dead:
		return
	target = t
	_attach_ring(t)
	started.emit(t)
	print("[combat] hunt start %s" % t.def.id)

func stop() -> void:
	target = null
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	ended.emit()

## Red ground ring on the target's tile (combat reference).
func _attach_ring(t: Creature) -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	var PV := load("res://scripts/world/prop_visuals.gd") as GDScript
	_ring = MeshInstance3D.new()
	_ring.name = "TargetRing"
	_ring.mesh = PV.make_disc_mesh(1.15, 32)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.12, 0.1, 0.45)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.add_child(_ring)
	_ring.position = Vector3(0, 0.06, 0)

func tactic_label(slot: int) -> String:
	match slot:
		1:
			return "Tackle" if _tackle_cd <= 0.0 else "Tackle %.0f" % _tackle_cd
		2:
			return "Kick" if _kick_cd <= 0.0 else "Kick %.0f" % _kick_cd
		3:
			return "Roll"
		4:
			if target and target.capturable() and _best_net_ok():
				return "Net"
			return "—"
		_:
			return ""

func _process(delta: float) -> void:
	_swing_cd = maxf(0.0, _swing_cd - delta)
	_tackle_cd = maxf(0.0, _tackle_cd - delta)
	_kick_cd = maxf(0.0, _kick_cd - delta)
	_net_cd = maxf(0.0, _net_cd - delta)
	if target == null or not is_instance_valid(target) or target.health.dead:
		if target:
			stop()
		return
	if hold or not auto:
		return
	if player.global_position.distance_to(target.global_position) > 28.0:
		stop()
		return
	_auto_attack()

func _auto_attack() -> void:
	if player.statuses.has_flag(&"cannot_act"):
		return
	if player.rolling:
		return
	var dist := player.global_position.distance_to(target.global_position)
	if dist > 2.1:
		if not hold:
			player.nav_to(target.global_position)
		return
	player.clear_nav()
	player.face_world(target.global_position)
	if _swing_cd > 0.0:
		return
	var w := player.inventory.equipped_weapon()
	var def := w.def() if w else null
	var rate := def.attack_rate if def and def.attack_rate > 0.0 else 1.0
	var dmg := w.scaled_damage() if w else 8.0
	var dtype := def.damage_type if def else &"blunt"
	if def and def.is_work_tool:
		dmg *= 0.45
	player.play_attack(dtype == &"blunt" and dmg > 10.0)
	var defense := target.def.defense * target.statuses.defense_mult()
	var raw: float = dmg - defense * 0.5
	var dealt: float = maxf(dmg * 0.05, raw)
	var behind := _is_behind()
	if behind:
		dealt *= 1.25
	var melee_lv := player.skills.level_of("melee") if player.skills else 0
	if player.skills:
		dealt *= 1.0 + 0.01 * float(melee_lv)  # ASSUMPTION +1 % per Melee level
	# Type matchup from ai.json (weak_to x1.5 orange, resists x0.6 grey), then a crit roll
	# (x1.75 red): 8 % base, +20 % from behind, +0.2 % per Melee level.
	var kind := effectiveness(target, dtype)
	if kind == &"strong":
		dealt *= 1.5
	elif kind == &"weak":
		dealt *= 0.6
	var crit_chance := 0.08 + (0.20 if behind else 0.0) + 0.002 * float(melee_lv)
	if randf() < crit_chance:
		dealt *= 1.75
		kind = &"crit"
	target.next_hit_kind = kind
	target.health.take_damage(dealt, player)
	if player.skills:
		player.skills.add_xp("melee", 2)
	print("[combat] player hit %s dmg=%.1f type=%s kind=%s" % [target.def.id, dealt, dtype, kind])
	if dtype == &"slashing" and randf() < 0.25:
		target.statuses.apply(&"bleeding_target", player)
	if dtype == &"blunt" and randf() < 0.35:
		target.statuses.apply(&"groggy", player)
	_swing_cd = 1.0 / maxf(0.2, rate)

## &"strong" when the creature's archetype lists the damage type under weak_to, &"weak" under
## resists, else &"hit".
static func effectiveness(c: Creature, dtype: StringName) -> StringName:
	if c == null or c.def == null or dtype == &"":
		return &"hit"
	var all: Dictionary = Data.creature_ai.get("archetypes", {})
	var row: Variant = all.get(str(c.def.archetype), {})
	var dflt: Dictionary = Data.creature_ai.get("default", {})
	var weak: Array = row.get("weak_to", dflt.get("weak_to", [])) if row is Dictionary else dflt.get("weak_to", [])
	var res: Array = row.get("resists", dflt.get("resists", [])) if row is Dictionary else dflt.get("resists", [])
	if str(dtype) in weak:
		return &"strong"
	if str(dtype) in res:
		return &"weak"
	return &"hit"

func use_tackle() -> void:
	if target == null or _tackle_cd > 0.0:
		return
	if player.global_position.distance_to(target.global_position) > 2.4:
		return
	target.statuses.apply(&"groggy", player)
	_tackle_cd = 8.0
	player.play_attack(true)
	print("[combat] body tackle %s" % target.def.id)

func use_kick() -> void:
	if target == null or _kick_cd > 0.0:
		return
	if player.global_position.distance_to(target.global_position) > 2.4:
		return
	var away := (target.global_position - player.global_position).normalized() * 3.5
	target.global_position += Vector3(away.x, 0, away.z)
	_kick_cd = 6.0
	print("[combat] kick %s" % target.def.id)

func use_net() -> void:
	if target == null or not target.capturable():
		return
	CaptureSystem.attempt(player, target)

func _best_net_ok() -> bool:
	var net := player.inventory.best_capture_net()
	if net == null:
		return false
	var d := net.def()
	return d != null and d.capture_tier >= target.def.capture_tier and Data.has_capture_technique(target.def.capture_tier)

func _is_behind() -> bool:
	var to_player := player.global_position - target.global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.001:
		return false
	return to_player.normalized().dot(target.global_basis.z) > 0.35
