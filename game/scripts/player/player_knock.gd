class_name PlayerKnock
extends RefCounted
## KNOCKDOWN (owner 2026-10-31: "the dinosaurs should be able to charge and knock us on our ass or throw us etc. the
## player should get thrown around and have a falling on his butt animation, wind knocked out of him").
##
## One hit-reaction ladder for heavy creature hits, picked from the hit itself, never per species:
##   light      a small push: the old shove + flinch (PlayerSim.shove carries on as before)
##   knockdown  shoved along the push, falls on her butt and back (fall_back), lies (lie), gets up (get_up)
##   throw      launched on a ballistic arc (airborne), lands on her butt, tumbles on, then the knockdown get-up
## force = push metres x attacker size (height / SIZE_REF_M); any upward lift (a horn toss) throws.
## After a knockdown or throw she is Winded (statuses.json): slower, no sprint, no attack, the `winded` idle.
## While down she holds the `knockdown` status (cannot_act: no move, roll, swing or tactic) and its HUD chip.
## Damage is never this class's business: GOD mode lands every reaction and no damage.
## Clips: tools/make_knockdown_clips.py. Test: game/tests/t_knockdown.gd.

enum Tier { LIGHT, KNOCKDOWN, THROW }
enum Phase { NONE, AIR, FALL, LIE, UP }

## ASSUMPTION: the push x size at which a hit knocks her down, and at which it throws her.
const KNOCKDOWN_FORCE := 2.0
const THROW_FORCE := 5.0
## ASSUMPTION: an animal this tall counts its push at face value; the scale is clamped to 0.6..1.5.
const SIZE_REF_M := 3.0
const SIZE_MIN := 0.6
const SIZE_MAX := 1.5
## ASSUMPTION: a throw with no lift of its own leaves the ground at 5 m/s (about 1.3 m up, 1 s in the air).
const THROW_LIFT_MPS := 5.0
## ASSUMPTION: a throw carries her the move's push metres, clamped to 3..9 m.
const THROW_MIN_M := 3.0
const THROW_MAX_M := 9.0
## ASSUMPTION: seconds flat on her back before she gets up (the wind knocked out of her).
const LIE_S := 1.0
## A knockdown's shove slides her over this long (linear decay, as PlayerSim.shove).
const SLIDE_S := 0.5
## On landing from a throw she tumbles on at this share of the flight speed, decaying over TUMBLE_S.
const TUMBLE_KEEP := 0.45
const TUMBLE_S := 0.4
## fall_back from this far in on landing from a throw: the drop onto the butt (the flight already did the stagger).
const LAND_FROM_S := 0.3
const MAX_AIR_S := 3.0
## A hit this soon after she starts falling is the same impact (its knockdown token arrives a frame apart).
const SAME_IMPACT_S := 0.1
const BLEND := 0.12

var p: Player
var phase: int = Phase.NONE
var tier: int = Tier.LIGHT
var _t := 0.0
var _vel := Vector3.ZERO
var _slide_s := 0.0
var _lie_s := LIE_S
## Where the last throw left the ground and came down (tests and the report read them).
## fall_back's start offset this fall (LAND_FROM_S after a throw, else 0).
var _fall_from := 0.0
## Set by CreatureAttack while a basic attack's Knockdown token is applied: that one does not lay her down.
var token_light := false
var launched_at := Vector3.ZERO
## The throw's flat distance: past it she only drops (thrown from a height she would fly on further).
var _throw_m := 0.0
var landed_at := Vector3.ZERO

func _init(player: Player) -> void:
	p = player

func active() -> bool:
	return phase != Phase.NONE

static func size_scale(who: Creature) -> float:
	if who == null or who.def == null:
		return 1.0
	return clampf(who.def.height_meters / SIZE_REF_M, SIZE_MIN, SIZE_MAX)

static func tier_for(push_m: float, lift_mps: float, who: Creature) -> int:
	var force := push_m * size_scale(who)
	if lift_mps > 0.0 or force >= THROW_FORCE:
		return Tier.THROW
	return Tier.KNOCKDOWN if force >= KNOCKDOWN_FORCE else Tier.LIGHT

## A shove landed (PlayerSim.shove). Returns the tier it reacted with; LIGHT leaves the shove to the caller.
func hit(push: Vector3, lift_mps: float, who: Creature) -> int:
	push.y = 0.0
	var want := tier_for(push.length(), lift_mps, who)
	if want == Tier.LIGHT or not _can_react():
		return Tier.LIGHT
	if p.mounted_on:
		if want != Tier.THROW:
			return Tier.LIGHT  # ASSUMPTION: the mount takes a ram; only a throw unseats her
		p.dismount()
	if active():
		# ROOTED (owner 2026-10-31: "when the player is knocked down, they should be unable to move from the place
		# they fell on their ass"): once down she stays where she fell. Only the impact that laid her down a moment
		# ago (its own knockdown token, same frame or two) may still set her slide; nothing new moves her.
		if phase == Phase.FALL and _t <= SAME_IMPACT_S and want != Tier.THROW:
			_push(push)
		return tier
	if want == Tier.THROW:
		_throw(push, lift_mps if lift_mps > 0.0 else THROW_LIFT_MPS, who)  # the move's own metres: size picks the tier only
	else:
		_knockdown(push, LIE_S)
	return want

## The `knockdown` status landed from anything else (a heavy hit's species token, the club tail's smash): she falls and lies
## out the status. Ignored while she is already down, pinned, riding or swimming.
func on_knockdown_status() -> void:
	if token_light or active() or not _can_react() or p.mounted_on:
		return
	var inst := p.statuses.get_instance(&"knockdown")
	var left := inst.time_left if inst else LIE_S
	_knockdown(Vector3.ZERO, maxf(LIE_S, left - _clip_len(&"fall_back") - _clip_len(&"get_up")))

func _can_react() -> bool:
	return not p.dead and not p.swimming and not p.rolling and p.statuses != null and not p.statuses.has(&"pinned")

func _knockdown(push: Vector3, lie_s: float) -> void:
	tier = Tier.KNOCKDOWN
	_lie_s = lie_s
	_push(push)
	_enter(Phase.FALL)
	_play(&"fall_back")
	print("[knock] knockdown push=%.1f lie=%.1f" % [push.length(), lie_s])

## A knockdown's shove: slid push metres over SLIDE_S, falling back away from it.
func _push(push: Vector3) -> void:
	_vel = push * (2.0 / SLIDE_S)
	_slide_s = SLIDE_S
	if push.length_squared() > 0.0001:
		p.face_world(p.global_position - push)

func _throw(push: Vector3, lift: float, who: Creature) -> void:
	tier = Tier.THROW
	_lie_s = LIE_S
	var g := absf(p.get_gravity().y) if p.get_gravity().y != 0.0 else 9.8
	var flight := 2.0 * lift / g
	var dir := push.normalized() if push.length_squared() > 0.0001 else -p.visual.global_basis.z
	var dist := clampf(push.length(), THROW_MIN_M, THROW_MAX_M)
	_throw_m = dist
	_vel = dir * (dist / flight)
	p.velocity = _vel + Vector3.UP * lift
	p.face_world(p.global_position - dir)
	launched_at = p.global_position
	_enter(Phase.AIR)
	_play(&"airborne", 0.08)
	print("[knock] thrown by %s %.1f m up %.1f m/s" % [who.def.id if who and who.def else "?", dist, lift])

func _enter(next: int) -> void:
	var was := phase
	phase = next
	_t = 0.0
	p.clear_nav()
	if was == Phase.NONE:
		p.statuses.apply(&"knockdown")  # cannot_act and the HUD chip while she is down
	_hold_status()

## The knockdown status lasts exactly as long as she is down: topped up every frame, cleared when she stands.
func _hold_status() -> void:
	var inst := p.statuses.get_instance(&"knockdown")
	if inst:
		inst.time_left = maxf(inst.time_left, 0.5)

## PlayerSim.tick: true while this owns the body this frame.
func tick(delta: float) -> bool:
	if phase == Phase.NONE:
		return false
	if p.dead or p.statuses.has(&"pinned"):
		_end(false)  # death or a pin takes over (PINFEEL lays her down its own way)
		return false
	_t += delta
	_hold_status()
	if not p.is_on_floor():
		p.velocity += p.get_gravity() * delta
	match phase:
		Phase.AIR:
			var flown := Vector2(p.global_position.x - launched_at.x, p.global_position.z - launched_at.z).length()
			var k := 1.0 if flown < _throw_m else 0.0
			p.velocity.x = _vel.x * k
			p.velocity.z = _vel.z * k
			p.move_and_slide()
			p.sim.shoreline_guard()
			if p.swimming:
				_end(true)  # into the water: she comes up swimming, winded
			elif (p.is_on_floor() and _t > 0.1 and p.velocity.y <= 0.0) or _t > MAX_AIR_S:
				_land()
		Phase.FALL:
			_slide(delta)
			if _t >= _clip_len(&"fall_back") - _fall_from:
				_enter(Phase.LIE)
				_play(&"lie", 0.2)
		Phase.LIE:
			_slide(delta)
			if _t >= _lie_s:
				_enter(Phase.UP)
				_play(&"get_up", 0.15)
		Phase.UP:
			p.sim.hold_still(delta)
			if _t >= _clip_len(&"get_up"):
				_end(true)
	return true

func _land() -> void:
	landed_at = p.global_position
	_vel *= TUMBLE_KEEP * 2.0  # linear decay over TUMBLE_S: covers TUMBLE_KEEP x speed x TUMBLE_S
	_slide_s = TUMBLE_S
	_enter(Phase.FALL)
	_play(&"fall_back", BLEND, LAND_FROM_S)
	print("[knock] landed %.1f m from launch" % Vector2(landed_at.x - launched_at.x, landed_at.z - launched_at.z).length())

func _slide(delta: float) -> void:
	var k := 0.0
	if _slide_s > 0.0:
		_slide_s = maxf(0.0, _slide_s - delta)
		k = _slide_s / (SLIDE_S if tier == Tier.KNOCKDOWN else TUMBLE_S)
	p.velocity.x = _vel.x * k
	p.velocity.z = _vel.z * k
	p.move_and_slide()
	p.sim.shoreline_guard()

## Death, a respawn or a load: drop the reaction without Winded.
func cancel() -> void:
	if active():
		_end(false)

## winded: true when she got up (Winded follows); false when something else took over.
func _end(winded: bool) -> void:
	phase = Phase.NONE
	_t = 0.0
	_vel = Vector3.ZERO
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	if not p.dead and not p.statuses.has(&"pinned"):
		p.statuses.clear_id(&"knockdown")
	if winded and not p.dead:
		p.statuses.apply(&"winded")
		p.notice("Winded")
	if p.anim:
		p.anim.end_knock()

func _play(clip: StringName, blend: float = BLEND, from_s: float = 0.0) -> void:
	_fall_from = from_s if clip == &"fall_back" else _fall_from
	if p.anim:
		p.anim.play_knock(clip, blend, from_s)

func _clip_len(clip: StringName) -> float:
	var ap: AnimationPlayer = p.rig.anim_player if p.rig else null
	return ap.get_animation(clip).length if ap and ap.has_animation(clip) else 0.6
