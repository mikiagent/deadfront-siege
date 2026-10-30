class_name PetBrain
extends CreatureBrain
## Pet orders (whistles): "guard" (default) follows the owner and fights whatever the owner
## fights or whatever hunts the owner; "attack" goes for one ordered target until it is dead;
## "heel" stays at the owner's side and does not fight. A hungry pet still fights, just slower.
## "stay" (PETSTAY, radial toggle) holds the spot it was told to stay at: no auto-targeting, but it
## fights back whatever hits it and then walks back to that spot.
##
## FOLLOW (owner 2026-10-28: "tames should follow within a certain radius of the player, not
## directly on top of the player"): every summoned pet holds its own follow SLOT beside/behind the
## survivor, fanned by summon order and pushed out by its body size, and walks only when it is
## farther than the outer radius from that slot; it stops inside the inner one. It never stands
## inside the survivor's capsule and steps aside when the survivor walks into it. Numbers live in
## data/creatures/ai.json "follow"; the pet's follow_dist_mult nature knob (Loyal 0.7) scales the
## two radii, so a Loyal pet settles closer.

## ASSUMPTION: the survivor capsule radius (scenes/player/player.tscn), the floor of the follow
## clearance on top of the pet's own body radius.
const PLAYER_RADIUS := 0.35
## Fallbacks when ai.json "follow" is missing or a key is absent (the file ships all of them).
const FOLLOW_DEFAULTS := {
	"slot_m": 4.0,
	"slot_size_mult": 1.0,
	"slot_arc_deg": 50.0,
	"inner_m": 2.5,
	"outer_m": 5.4,
	"heel_mult": 0.8,
	"clearance_margin_m": 0.3,
	"step_aside_m": 0.8,
}

var hold: bool = false
var mode: StringName = &"guard"
var order_target: Creature
## PETSTAY: where a staying pet holds, and the last wild animal that hit it there.
var stay_spot := Vector3.ZERO
var _stay_foe: Creature
## ASSUMPTION: a staying pet drops a foe that drags it this far from its spot (no doc number).
const STAY_LEASH_M := 15.0
## A staying pet walks back once it is this far from its spot and stops inside STAY_ARRIVE_M.
const STAY_RETURN_M := 0.6
const STAY_ARRIVE_M := 0.3
var _returning := false
## Hysteresis latch: true while the pet is walking to its slot. It is set only once the pet is
## farther than the outer radius and cleared once it is inside the inner one, so a pet parked
## between the two does not start or stop moving every think.
var _following: bool = false
## True once this approach has rounded the survivor's clearance circle (see _follow).
var _past_gate: bool = false

func order(cmd: StringName, target: Creature = null) -> void:
	mode = cmd
	order_target = target if cmd == &"attack" else null
	_stay_foe = null
	if cmd == &"stay":
		stay_spot = creature.global_position
	print("[pet] %s order %s%s" % [creature.def.id, cmd, (" -> " + str(target.def.id)) if target else ""])

## The ai.json "follow" block (fallbacks merged in), read once per call: it is four lookups.
func _cfg(key: String) -> float:
	var ai: Dictionary = Data.creature_ai if Data else {}
	var block: Variant = ai.get("follow", {})
	var row: Dictionary = block if block is Dictionary else {}
	var v: Variant = row.get(key, FOLLOW_DEFAULTS.get(key, 0.0))
	return float(v)

## NATURES: how far a guarding pet looks for threats (9 m today), widened by guard_radius_mult
## (Loyal, Aggressive). With protect_owner the threat is measured from the OWNER as well, so a pet
## answers anything closing on its owner even from across the camp.
func guard_radius(player: Player) -> float:
	var r := 9.0 * creature.nature_knob("guard_radius_mult", 1.0)
	return r

func _threat_distance(c: Creature, player: Player) -> float:
	var d := c.global_position.distance_to(creature.global_position)
	if creature.nature_flag("protect_owner"):
		d = minf(d, c.global_position.distance_to(player.global_position))
	return d

## NATURES: a pet badly hurt drops its fight (retreat_fraction). Its nature can keep it in it:
## protect_rider_below_hp (Brave) while its owner is riding it and its HP is under that fraction.
func nature_keeps_fighting() -> bool:
	var rider_below := creature.nature_knob("protect_rider_below_hp", 0.0)
	if rider_below <= 0.0:
		return false
	var owner := PlayerRegistry.owner_of(creature)
	if owner == null or owner.mounted_on != creature:
		return false
	return creature.health.fraction() < rider_below

## The old single-point follow distance (HEEL 1.6 m / guard 2.4 m, scaled by follow_dist_mult).
## The follow slot band below replaced it as the walk/stop rule; kept as the reading of the same
## nature knob that the other pet rules and t_natures share.
func nature_stop_distance() -> float:
	var heel := mode == &"heel"
	return (1.6 if heel else 2.4) * creature.nature_knob("follow_dist_mult", 1.0)

## Body-size factor: how much bigger than a compsognathus this pet's body is, on the same
## body_radius the collision capsule uses. It widens the slot AND the two radii, so a big tame
## both hangs back further and tolerates a wider band.
func _size_scale() -> float:
	var slot_m := maxf(0.5, _cfg("slot_m"))
	return 1.0 + 0.5 * _cfg("slot_size_mult") * creature.body_radius() / slot_m

## Mode/nature multiplier on the two radii. The nature's follow_dist_mult is applied SQUARED here:
## it already pulls the slot in (slot_distance), so squaring closes the walk/stop band around it as
## well, and a Loyal pet visibly hugs its owner instead of parking at the same distance. HEEL pulls
## the band in once (heel_mult).
func _band_mult() -> float:
	var m := creature.nature_knob("follow_dist_mult", 1.0)
	if mode == &"heel":
		m *= _cfg("heel_mult")
	return m * m

## How far from the survivor this pet's slot sits: the base distance plus its body radius (a big
## tame hangs back further), scaled by the nature's follow_dist_mult (Loyal stands closer). HEEL
## pulls the slot in too, so a heel order really is "at my side".
func slot_distance() -> float:
	var d := _cfg("slot_m") + _cfg("slot_size_mult") * creature.body_radius()
	d *= creature.nature_knob("follow_dist_mult", 1.0)
	if mode == &"heel":
		d *= _cfg("heel_mult")
	return d

## Inside this of its slot the pet is settled and stops walking.
func follow_inner() -> float:
	return _cfg("inner_m") * _size_scale() * _band_mult()

## Farther than this from its slot and the pet starts walking again.
func follow_outer() -> float:
	return _cfg("outer_m") * _size_scale() * _band_mult()

## The survivor capsule plus this pet's body plus a margin: a pet never stands inside it.
func player_clearance(_player: Player) -> float:
	return PLAYER_RADIUS + creature.body_radius() + _cfg("clearance_margin_m")

## Ground-plane forward of the survivor (the visual is what turns; the body node does not).
func _forward(player: Player) -> Vector3:
	var node: Node3D = player
	if player.visual != null:
		node = player.visual
	var f := -node.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD

## Which slot this pet takes: its position in the owner's summoned list. A pet nobody summoned yet
## (just tamed, or a lab's stray) takes slot 0, so it behaves in the very first frame.
func follow_index(player: Player) -> int:
	if player.pets == null:
		return 0
	var i := player.pets.summoned.find(creature)
	return maxi(0, i)

## The spot this pet stands at: behind/beside the survivor, by its slot index and body size.
func follow_slot(player: Player) -> Vector3:
	return slot_for(player, follow_index(player), creature.body_radius(), mode, creature.nature_knob("follow_dist_mult", 1.0))

## The same geometry for a pet that is not in the tree yet (PlayerPets places a new summon here).
static func slot_for(player: Player, index: int, body_radius: float, slot_mode: StringName = &"guard", dist_mult: float = 1.0) -> Vector3:
	var ai: Dictionary = Data.creature_ai if Data else {}
	var block: Variant = ai.get("follow", {})
	var row: Dictionary = block if block is Dictionary else {}
	var slot_m := float(row.get("slot_m", FOLLOW_DEFAULTS["slot_m"]))
	var size_mult := float(row.get("slot_size_mult", FOLLOW_DEFAULTS["slot_size_mult"]))
	var arc := float(row.get("slot_arc_deg", FOLLOW_DEFAULTS["slot_arc_deg"]))
	var heel_mult := float(row.get("heel_mult", FOLLOW_DEFAULTS["heel_mult"]))
	var heel := slot_mode == &"heel"
	var dist := (slot_m + size_mult * body_radius) * (heel_mult if heel else 1.0) * dist_mult
	var angle := 0.0
	match index:
		0:
			angle = PI * 0.5
		1:
			angle = -PI * 0.5
		2:
			angle = 0.0
		_:
			var ring := float((index + 1) / 2)
			angle = (1.0 if index % 2 == 1 else -1.0) * deg_to_rad(arc) * ring
	var node: Node3D = player
	if player.visual != null:
		node = player.visual
	var f := -node.global_basis.z
	f.y = 0.0
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD
	# Behind the survivor, rotated to the slot's side.
	var behind := f.rotated(Vector3.UP, PI + angle)
	return player.global_position + behind * dist

## A staying pet fights back what hits it (the base brain records the source too).
func on_aggro(who: Node) -> void:
	super(who)
	if mode == &"stay" and who is Creature and not (who as Creature).is_pet:
		_stay_foe = who as Creature

## The foe a staying pet answers, while it lives and has not dragged the pet off its spot.
func _stay_target() -> Creature:
	if _stay_foe == null or not is_instance_valid(_stay_foe) or _stay_foe.health.dead \
			or _flat_distance(creature.global_position, stay_spot) > STAY_LEASH_M:
		_stay_foe = null
	return _stay_foe

## Back to the stay spot, with the same start/stop hysteresis as follow.
func _hold_spot(delta: float) -> void:
	var d := _flat_distance(creature.global_position, stay_spot)
	if d > STAY_RETURN_M:
		_returning = true
	elif d <= STAY_ARRIVE_M:
		_returning = false
	if _returning:
		creature.move_to(stay_spot)
		creature.face_towards(stay_spot, delta)
	else:
		creature.stop_move()

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _pick_guard_target(player: Player) -> Creature:
	if player.hunt and player.hunt.target and is_instance_valid(player.hunt.target) and not player.hunt.target.health.dead:
		return player.hunt.target
	var best: Creature = null
	var best_d := guard_radius(player)
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.is_pet or c.health.dead or c.brain == null:
			continue
		if not c.brain.has_method("hunting_player") or not c.brain.hunting_player():
			continue
		var d := _threat_distance(c, player)
		if d < best_d:
			best_d = d
			best = c
	return best

## Walking to the slot (or out from under the survivor's feet). Returns true when it moved.
##
## The pet goes around the survivor instead of standing on them: while the straight line to its slot
## would cut through the survivor's clearance circle, it aims first at the GATE - the point of that
## circle that lies toward the slot - and only then at the slot itself. The gate depends on the
## survivor and the slot alone, never on where the pet currently stands, so the pet converges
## instead of chasing a waypoint that turns with it (the orbit that made the 20 m walk never settle).
func _follow(player: Player, delta: float) -> bool:
	var slot := follow_slot(player)
	var d_slot := _flat_distance(creature.global_position, slot)
	var clear := player_clearance(player)
	var step := _cfg("step_aside_m")
	var d_player := _flat_distance(creature.global_position, player.global_position)
	if d_slot > follow_outer():
		_following = true
	elif d_slot <= follow_inner() and d_player >= clear:
		_following = false
		_past_gate = false
	if not _following:
		if d_player < clear:
			# The survivor walked into it: step out of the capsule instead of standing underfoot.
			creature.move_to(_out_of_way(player, clear + step))
			creature.face_towards(_out_of_way(player, clear + step), delta)
			return true
		creature.stop_move()
		return false
	# Round the survivor first, then straight in. Once the pet has reached the gate it keeps aiming
	# at the slot (the gate is on the circle toward it, so that leg is clear): re-testing every think
	# flips it back to the gate from just past it and the pet circles the gate forever.
	var goal := slot
	if not _past_gate:
		var gate := _gate(player, slot, clear + step)
		if _h(gate, creature.global_position) <= 0.7 or not _crosses_clearance(creature.global_position, slot, player.global_position, clear + step):
			_past_gate = true
		else:
			goal = gate
	creature.move_to(goal)
	creature.face_towards(goal, delta)
	return true

func _h(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## True when the ground-plane segment a->b comes within `radius` of the survivor.
func _crosses_clearance(a: Vector3, b: Vector3, at: Vector3, radius: float) -> bool:
	var seg := Vector2(b.x - a.x, b.z - a.z)
	var len2 := seg.length_squared()
	var t := 0.0
	if len2 > 0.000001:
		t = clampf(Vector2(at.x - a.x, at.z - a.z).dot(seg) / len2, 0.0, 1.0)
	var closest := Vector2(a.x, a.z) + seg * t
	return closest.distance_to(Vector2(at.x, at.z)) < radius

## The point of the clearance circle between the survivor and the slot.
func _gate(player: Player, slot: Vector3, radius: float) -> Vector3:
	var to := slot - player.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		to = _forward(player)
	return player.global_position + to.normalized() * radius

## A point `radius` from the survivor, on the side the pet already stands (so the nudge is short).
func _out_of_way(player: Player, radius: float) -> Vector3:
	var away := creature.global_position - player.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -_forward(player)
	return player.global_position + away.normalized() * radius

func _think(delta: float) -> void:
	# PetBrain owns its think loop, so it must also advance the inherited attack cooldown.
	# Without this, a SIC order lands exactly one bite and _attack_cd stays at 1.2 forever.
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var player := PlayerRegistry.owner_of(creature)
	if player == null:
		return
	hold = player.hunt != null and player.hunt.hold
	var target: Creature = null
	if mode == &"attack":
		if order_target and is_instance_valid(order_target) and not order_target.health.dead:
			target = order_target
		else:
			mode = &"guard"
			order_target = null
	if mode == &"guard" and not hold:
		target = _pick_guard_target(player)
	elif mode == &"stay":
		target = _stay_target()
	# NATURES: a badly hurt pet stands down, unless its nature keeps it fighting for its rider.
	if target and creature.health.fraction() < retreat_fraction() and not nature_keeps_fighting():
		target = null
	if target:
		attack_target = target
		var dist := creature.global_position.distance_to(target.global_position)
		if dist > 45.0:
			target = null
		else:
			# Reach is measured to the target's body: a raptor can bite a triceratops' flank.
			var reach := maxf(1.2, float(profile.get("attack_range", 1.8)) + 0.2) + _size_excess(target)
			# Use a wider exit threshold than entry. Without hysteresis, contact separation nudges the
			# pet a few centimetres outside reach after a bite and it oscillates instead of reattacking.
			var attack_exit := reach + 0.65
			if state != &"attack" and dist > reach:
				_set_state(&"chase")
				creature.move_to(target.global_position)
				creature.face_towards(target.global_position, delta)
			elif dist > attack_exit:
				_set_state(&"chase")
				creature.move_to(target.global_position)
				creature.face_towards(target.global_position, delta)
			else:
				_set_state(&"attack")
				_do_attack()
			return
	attack_target = null
	_set_state(&"alert" if mode == &"heel" or mode == &"stay" else &"roam")
	if mode == &"stay":
		_hold_spot(delta)
		return
	_follow(player, delta)
