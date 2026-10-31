class_name BigStomp
extends RefCounted
## BIGSTOMP (owner 2026-10-31: "I think the bigger dinosaurs all need a stomp mechanic where if you get close they will
## stomp the ground, shake the screen, and if you get stomped you probably take a lot of damage or die. Maybe you get
## pinned by the stomp attack"). One shared, data-driven move for every big species: CreatureBrain owns one (for_creature)
## and ticks it before its own think, so any brain gets it with no code of its own.
##
## Who stomps: a wild animal whose rig has the big_stomp clip, at least ai.json big_stomp.min_height_m tall, unless its
## tactics profile (species "tactics" or the archetype's) or its archetype row says "big_stomp": false; true or a dict
## (overrides) turns it on below the size.
## When: its target (standing, not pinned) is inside the near ring round the spot the foot comes down on (under the
## body: ai.json big_stomp.species.<id>.land, x across and z ahead of the centre in body heights).
## The move: the foot is hauled up and held (windup_s by size, 0.6-0.9 s) over a ring (the near ring, yellow) with the
## foot's shadow in it (the direct ring); then the slam: dust, a camera shake scaled by size and distance, and
## - inside the shadow: damage_mult x its attack (kills outside GOD) and Pinned under the foot (Creature.start_pin:
##   the pin_foot clip, PINFEEL's pin; it bites once while it holds, pin_bite_s);
## - inside the ring: near_mult damage and a knockdown (PlayerKnock tier from near_force);
## - a roll (its opening window) or being outside the ring dodges it. Not on someone already down.

const CLIP := &"big_stomp"
## anim_events.json big_stomp hit_frac: every big_stomp clip lands its foot on this fraction.
const HIT_FRAC := 0.72

var creature: Creature
var cfg: Dictionary
var phase: StringName = &""  ## &"windup" until the foot lands, &"after" for the rest of the clip
var t := 0.0
var windup := 0.0
var spot := Vector3.ZERO
var cd := 0.0
var telegraph: Telegraph
## For tests and the review lab: stomps started, the last outcome (&"direct", &"near", &"dodged", &"clear") and the
## camera shake the last slam asked for (before IsoCamera's own reduce-shake setting).
var stomps := 0
var last: StringName = &""
var last_shake := 0.0

static func section() -> Dictionary:
	var s: Variant = Data.creature_ai.get("big_stomp", {})
	return s if s is Dictionary else {}

## The stomp an animal uses, or null when it has none.
static func for_creature(c: Creature) -> BigStomp:
	if c == null or c.def == null or c.is_pet or c.anim == null or not c.anim.has_state(CLIP):
		return null
	var opt: Variant = opt_in(c.def)
	if opt is bool and not opt:
		return null
	if opt == null and c.def.height_meters < float(section().get("min_height_m", 2.9)):
		return null
	var s := BigStomp.new()
	s.creature = c
	s.cfg = section().duplicate(true)
	s.cfg.erase("species")
	s.cfg.merge(species_row(c.def.id), true)
	if opt is Dictionary:
		s.cfg.merge(opt, true)
	return s

## The tactics profile's (species, then archetype) or the archetype row's "big_stomp": false, true, a dict, or null.
static func opt_in(def: CreatureDef) -> Variant:
	var tac := TacticalBrain.tactics_for_def(def)
	if tac.has("big_stomp"):
		return tac["big_stomp"]
	var row: Variant = (Data.creature_ai.get("archetypes", {}) as Dictionary).get(str(def.archetype), {})
	return (row as Dictionary).get("big_stomp") if row is Dictionary else null

static func species_row(id: StringName) -> Dictionary:
	var r: Variant = (section().get("species", {}) as Dictionary).get(str(id), {})
	return r if r is Dictionary else {}

func _num(key: String, fallback: float) -> float:
	return float(cfg.get(key, fallback))

## Body height in metres (the size every number scales by).
func height() -> float:
	return creature.def.height_meters * creature.size_scale()

## 0 at the smallest stomper, 1 at the biggest (windup and shake run between their two numbers on it).
func size_t() -> float:
	var hr: Array = cfg.get("size_range_m", [3.0, 10.0])
	return clampf((height() - float(hr[0])) / maxf(0.01, float(hr[1]) - float(hr[0])), 0.0, 1.0)

func direct_radius() -> float:
	return _num("direct_frac", 0.16) * height()

func near_radius() -> float:
	return _num("near_frac", 0.42) * height()

## Where the foot comes down, from where the body stands now.
func land_point() -> Vector3:
	var land: Array = cfg.get("land", [0.0, 0.0])
	var h := height()
	var p := creature.global_position + creature.global_basis.orthonormalized() * Vector3(float(land[0]) * h, 0.0, -float(land[1]) * h)
	p.y = creature.global_position.y
	return p

static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Called by CreatureBrain every physics frame before it thinks; true while the stomp owns the body.
func tick(delta: float, brain: CreatureBrain) -> bool:
	cd = maxf(0.0, cd - delta)
	if phase != &"":
		_step(delta)
		return phase != &""
	if cd > 0.0 or not brain.stomp_ready():
		return false
	var v := brain.attack_target
	if not _standing(v) or flat(v.global_position, land_point()) > near_radius():
		return false
	_start()
	return true

static func _standing(v: Node3D) -> bool:
	if v is Player:
		var p := v as Player
		return not p.dead and not p.statuses.has(&"knockdown") and not p.statuses.has(&"pinned")
	if v is Creature:
		var c := v as Creature
		return not c.health.dead and not c.statuses.has(&"knockdown") and not c.statuses.has(&"pinned")
	return false

func _start() -> void:
	var w: Array = cfg.get("windup_s", [0.6, 0.9])
	windup = lerpf(float(w[0]), float(w[1]), size_t())
	phase = &"windup"
	t = 0.0
	spot = land_point()
	stomps += 1
	creature.stop_move()
	creature.anim.play_timed_attack(CLIP, windup)
	telegraph = Telegraph.show_stomp(creature, spot, direct_radius(), near_radius(), windup)
	print("[ai] %s big stomp (wind-up %.2fs, ring %.1f m)" % [creature.def.id, windup, near_radius()])

func _step(delta: float) -> void:
	t += delta
	if creature.health.dead or (t > 0.1 and creature.anim.current_clip != CLIP and not creature.anim.is_pinning()):
		_end()  # knocked down, killed or cut off
		return
	if creature.pin_victim != null:
		return  # the stomp pinned: Creature._tick_pin holds the body until it lets go
	creature.stop_move()
	if phase == &"windup":
		if t >= windup:
			phase = &"after"
			_land()
	elif t >= windup * (1.0 / HIT_FRAC):
		_end()

func _land() -> void:
	_clear_telegraph()
	_dust(spot)
	var s: Array = cfg.get("shake", [0.45, 0.9])
	last_shake = shake_at_spot(spot, lerpf(float(s[0]), float(s[1]), size_t()), near_radius() * _num("shake_range", 3.0))
	var local := PlayerRegistry.local()
	last = &"clear"
	var victims: Array[Node3D] = []
	var tgt := creature.brain.attack_target if creature.brain else null
	if tgt is Player or tgt is Creature:
		victims.append(tgt)
	if local and not victims.has(local):
		victims.append(local)
	for v in victims:
		if not is_instance_valid(v):
			continue
		var d := flat(v.global_position, spot) - ((v as Creature).body_radius() if v is Creature else 0.0)
		if d <= direct_radius():
			_direct(v)
		elif d <= near_radius():
			_near(v)

## (CreatureAttack._deal_damage, not apply_for: the ring is the reach, and a body under the belly has no clear line
## to the head; the stomp carries no species status tokens.)
func _direct(v: Node3D) -> void:
	if not CreatureAttack._deal_damage(creature, v, CLIP, _num("damage_mult", 2.5)):
		last = &"dodged"
		return
	last = &"direct"
	var st: StatusEffects = (v as Player).statuses if v is Player else (v as Creature).statuses
	if v is Player:
		(v as Player).receive_creature_hit(creature, CLIP)
	if CreatureAttack._target_dead(v) or not bool(cfg.get("pin", true)):
		return
	# the raid kit keeps the tyrant from pinning (CreatureAttack's rule for its stomp)
	var kit := v is Player and creature.def.id == &"tyrannosaurus" and (v as Player).inventory.has_raid_protection()
	if not kit:
		st.apply(&"pinned", creature, 1)
		if st.has(&"pinned") and creature.start_pin(v):
			print("[combat] %s stomp-pins %s" % [creature.def.id, v.name])
			return
		st.clear_id(&"pinned")
	_knock(v)

func _near(v: Node3D) -> void:
	if not CreatureAttack._deal_damage(creature, v, CLIP, _num("near_mult", 0.35)):
		last = &"dodged"
		return
	last = &"near"
	if v is Player:
		(v as Player).receive_creature_hit(creature, CLIP)
	if not CreatureAttack._target_dead(v):
		_knock(v)

## Knocked flat away from the foot (PlayerKnock's knockdown tier for a survivor).
func _knock(v: Node3D) -> void:
	var away := v.global_position - spot
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else -creature.global_basis.z
	if v is Player:
		var pl := v as Player
		if pl.sim:
			pl.sim.shove(away * _num("near_force", 3.0) / PlayerKnock.size_scale(creature), 0.6, 0.0, creature)
		if not pl.statuses.has(&"knockdown"):
			pl.statuses.apply(&"knockdown", creature, 1)
	elif v is Creature:
		(v as Creature).statuses.apply(&"knockdown", creature, 1)
		(v as Creature).anim.play_clip(&"knockdown")

func _end() -> void:
	phase = &""
	cd = _num("cooldown_s", 3.5)
	_clear_telegraph()
	if creature.anim.timed_attack:
		creature.anim.end_timed_attack()

func _clear_telegraph() -> void:
	if is_instance_valid(telegraph):
		telegraph.queue_free()
	telegraph = null

## A short dust burst where the foot lands (one-shot particles, freed when done).
## The ground shake on the local survivor from a slam at `at`: amount, fading to 0 at range_m. Returns what it asked of
## IsoCamera (before its reduce-shake setting). Shared: THERO-ROAR's burst and SPACING STOMP's slam use it too.
static func shake_at_spot(at: Vector3, amount: float, range_m: float) -> float:
	var local := PlayerRegistry.local()
	if local == null:
		return 0.0
	var out := amount * clampf(1.0 - flat(local.global_position, at) / maxf(0.01, range_m), 0.0, 1.0)
	if out > 0.0:
		IsoCamera.shake(local, out)
	return out

func _dust(at: Vector3) -> void:
	dust(creature.get_parent(), at, height(), direct_radius())

## A dust burst kicked up from a ring of `radius` at `at` by something `h` metres tall (one-shot particles, freed when
## done). Shared with THERO-ROAR and SPACING STOMP.
static func dust(parent: Node, at: Vector3, h: float, radius: float) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 48
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.5
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5 + 0.3 * h
	p.initial_velocity_max = 3.0 + 0.5 * h
	p.gravity = Vector3(0, -4.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.4 + 0.08 * h
	p.scale_amount_max = 0.8 + 0.15 * h
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.53, 0.42, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	p.global_position = at + Vector3.UP * 0.2
	p.emitting = true
	p.finished.connect(p.queue_free)
