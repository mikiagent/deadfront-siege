class_name Hitbox
extends RefCounted
## HITBOXES: what an attack hits with. Every move (a creature's attack_primary / attack_heavy /
## bite_combo / tail_swipe / kick / pounce / charge, the survivor's swing per weapon class, punch, kick,
## tackle) names its attacking parts in data/creatures/hitboxes.json: a bone plus a sphere radius, or a
## capsule (length along a bone axis: a blade in the fist, a horn), and an active window in clip time
## (default: the lead_frac of the clip before its hit frame from anim_events.json, up to the hit frame).
## The window is baked once per animal and move from the clip's own tracks (skeleton space), then at the
## hit the parts' path through the window is swept frame to frame (capsules between samples ~1/60 s of
## clip apart, so a fast swing cannot tunnel) against the target's hurtboxes (Hurtboxes, physics layer
## 20). The first hurtbox the sweep touches is the hit location, handed to damage as health/vitals
## last_hit_part. Bodies without a skeleton (box stand-ins, structures) keep the old reach rule.
# ASSUMPTION: the hit is judged at the hit frame over the whole window behind it (the clip's sweep with
# the body where it stands at the hit), not at the first contact mid-window: the roll, telegraph and
# damage timing all hang off the hit frame. Owner question logged in the hitboxes report.

const DATA_PATH := "res://data/creatures/hitboxes.json"
const STEP_S := 1.0 / 60.0  ## clip seconds between sweep samples
const MAX_SAMPLES := 48
const DEBUG_LINGER_MS := 450

## The debug draw (hitboxes red after they swing, hurtboxes green). Toggled with the debug toggle and
## the fight lab's H key; HitboxDebug draws it.
static var debug_draw := false:
	set(v):
		debug_draw = v
		HitboxDebug.ensure()
## Sweeps judged in the last DEBUG_LINGER_MS: [until_ms, a, b, r, hit].
static var recent: Array = []
## Wall time spent in strike() (perf gate), and calls.
static var spent_usec := 0
static var strikes := 0

static var _data: Dictionary = {}
static var _shape := CapsuleShape3D.new()

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"_error": true}
	return _data

## True when both bodies have skeletons, so hits are judged by hitbox against hurtbox.
static func applies(attacker: Node, target: Node) -> bool:
	return Hurtboxes.skeleton_of(attacker) != null and Hurtboxes.of(target) != null

## The move as data: {clip, window: Vector2 (clip fractions), parts: [{bone, radius, length, axis, offset}]}.
## hit_index picks the bite of a multi-hit clip (bite_combo); weapon is the survivor's weapon class.
static func move_spec(attacker: Node, move: StringName, hit_index: int = 0, weapon: StringName = &"") -> Dictionary:
	var row: Dictionary = {}
	var d := data()
	if attacker is Creature:
		var sp: Dictionary = (d.get("species", {}) as Dictionary).get(str((attacker as Creature).def.id), {})
		row = ((sp.get("moves", {}) as Dictionary).get(str(move), {}) as Dictionary).duplicate()
		if not row.has("parts"):
			row["parts"] = sp.get("parts", (d.get("creature_defaults", {}) as Dictionary).get("parts", []))
	else:
		var sv: Dictionary = d.get("survivor", {})
		row = ((sv.get("moves", {}) as Dictionary).get(str(move), {}) as Dictionary).duplicate()
		if weapon != &"" and row.get("armed", false) and (sv.get("weapons", {}) as Dictionary).has(str(weapon)):
			row.merge(sv["weapons"][str(weapon)], true)
	var clip := StringName(str(row.get("clip", move)))
	row["clip"] = clip
	if row.get("window") is Array:
		row["window"] = Vector2(float(row["window"][0]), float(row["window"][1]))
	else:
		var fracs := CreatureClips.hit_fracs(clip)
		var hit := fracs[clamp(hit_index, 0, fracs.size() - 1)] if not fracs.is_empty() else CreatureClips._hit_frac(clip)
		var lead := float(row.get("lead_frac", (d.get("creature_defaults", {}) as Dictionary).get("lead_frac", 0.25)))
		var lo := 0.0 if hit_index <= 0 or fracs.size() <= 1 else fracs[hit_index - 1]
		row["window"] = Vector2(maxf(lo, hit - lead), hit)
	return row

## Judge one move against one target: {} when no part touched it, else {part, region, at}.
static func strike(attacker: Node3D, move: StringName, target: Node3D, hit_index: int = 0, weapon: StringName = &"") -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var out := _strike(attacker, move, target, hit_index, weapon)
	spent_usec += Time.get_ticks_usec() - t0
	strikes += 1
	return out

static func _strike(attacker: Node3D, move: StringName, target: Node3D, hit_index: int, weapon: StringName) -> Dictionary:
	var hurt := Hurtboxes.of(target)
	var sk := Hurtboxes.skeleton_of(attacker)
	if hurt == null or sk == null:
		return {}
	var samples := baked(attacker, move, hit_index, weapon)
	if samples.is_empty():
		return {}
	hurt.sync(true)
	var xf := sk.global_transform
	var space := attacker.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Hurtboxes.LAYER
	var own := attacker.get_node_or_null(NodePath(Hurtboxes.NAME)) as Hurtboxes
	if own:
		q.exclude = [own.get_rid()]
	var draw := debug_draw
	var found := {}
	for k in samples.size():
		var cur: Array = samples[k]
		var prev: Array = samples[maxi(0, k - 1)]
		for pi in cur.size():
			var p: Array = cur[pi]
			var pp: Array = prev[pi]
			var r := float(p[2])
			var a: Vector3 = xf * (p[0] as Vector3)
			var b: Vector3 = xf * (p[1] as Vector3)
			# The part where it is now, and each end's path since the last sample (no tunnelling).
			var segs := [[a, b]]
			if k > 0:
				segs.append([xf * (pp[0] as Vector3), a])
				if (p[1] as Vector3) != (p[0] as Vector3):
					segs.append([xf * (pp[1] as Vector3), b])
					segs.append([xf * ((pp[0] as Vector3) + (pp[1] as Vector3)) * 0.5, (a + b) * 0.5])
			for s in segs:
				if found.is_empty():
					found = _touch(space, q, s[0], s[1], r, hurt)
				if draw:
					recent.append([Time.get_ticks_msec() + DEBUG_LINGER_MS, s[0], s[1], r, not found.is_empty()])
			if not found.is_empty() and not draw:
				return found
	return found

static func _touch(space: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, a: Vector3, b: Vector3, r: float, hurt: Hurtboxes) -> Dictionary:
	_shape.radius = maxf(0.01, r)
	_shape.height = a.distance_to(b) + 2.0 * _shape.radius
	q.transform = Transform3D(Hurtboxes._basis_along(b - a), (a + b) * 0.5)
	for res in space.intersect_shape(q, 32):
		if res.get("collider") == hurt:
			var row := hurt.part_of(int(res.get("shape", 0)))
			if not row.is_empty():
				return {"part": row["part"], "region": row["region"], "at": (a + b) * 0.5}
	return {}

## The move's parts through its window in skeleton space: one Array per sample of [a, b, radius_m]
## per part. Cached per animal, move, bite and body size.
static func baked(attacker: Node3D, move: StringName, hit_index: int = 0, weapon: StringName = &"") -> Array:
	var sk := Hurtboxes.skeleton_of(attacker)
	if sk == null:
		return []
	var s := sk.global_basis.get_scale().x
	var key := "%s|%d|%s|%.4f" % [move, hit_index, weapon, s]
	var cache: Dictionary = attacker.get_meta(&"hitbox_bake", {})
	if cache.has(key):
		return cache[key]
	var spec := move_spec(attacker, move, hit_index, weapon)
	var ap := _anim_player(attacker)
	var clip: StringName = spec["clip"]
	if ap and not ap.has_animation(clip):
		# A rig without the clip plays a stand-in (the survivor punches with the thrust; a charge is the run).
		clip = StringName(str(spec.get("fallback_clip", "run" if move == &"charge" else "attack_primary")))
	var anim := ap.get_animation(clip) if ap and ap.has_animation(clip) else null
	var out := []
	if anim != null:
		var tracks := _tracks(anim)
		var w: Vector2 = spec["window"]
		var t_from := anim.length * clampf(w.x, 0.0, 1.0)
		var t_to := anim.length * clampf(w.y, 0.0, 1.0)
		var n := clampi(int(ceil((t_to - t_from) / STEP_S)) + 1, 2, MAX_SAMPLES)
		var size := (attacker as Creature).size_scale() if attacker is Creature else 1.0
		var own := Hurtboxes.of(attacker)
		for i in n:
			var t := lerpf(t_from, t_to, float(i) / float(n - 1))
			var row := []
			for part in spec.get("parts", []) as Array:
				var p := part as Dictionary
				var bone := sk.find_bone(str(p.get("bone", "")))
				if bone < 0:
					continue
				var g := sample_pose(sk, anim, tracks, bone, t)
				var basis := g.basis.orthonormalized()
				var off: Array = p.get("offset", [0, 0, 0])
				var ax: Array = p.get("axis", [0, 1, 0])
				var a := g.origin + basis * (Vector3(float(off[0]), float(off[1]), float(off[2])) * size / s)
				var b := a + basis * (Vector3(float(ax[0]), float(ax[1]), float(ax[2])).normalized() * float(p.get("length", 0.0)) * size / s)
				var r := float(p.get("radius", -1.0)) * size
				if r <= 0.0:
					r = _own_radius(own, sk, bone) * float(p.get("radius_scale", 1.0))
				row.append([a, b, r])
			out.append(row)
	cache[key] = out
	attacker.set_meta(&"hitbox_bake", cache)
	return out

## The attacker's own hurtbox radius at that bone (or the nearest ancestor that has one), in metres.
static func _own_radius(own: Hurtboxes, sk: Skeleton3D, bone: int) -> float:
	var b := bone
	while b >= 0 and own:
		for c in own.caps:
			if int(c["bone"]) == b:
				return float(c["r"]) * sk.global_basis.get_scale().x
		b = sk.get_bone_parent(b)
	return 0.3

static func _anim_player(n: Node) -> AnimationPlayer:
	if n is Creature:
		var v := (n as Creature).view
		return v.rig.anim_player if v and v.rig else null
	var rig: Variant = n.get(&"rig")
	return (rig as RiggedModel).anim_player if rig is RiggedModel else null

## bone name -> [position track, rotation track] of one clip.
static func _tracks(anim: Animation) -> Dictionary:
	var out := {}
	for i in anim.get_track_count():
		var ty := anim.track_get_type(i)
		if ty != Animation.TYPE_POSITION_3D and ty != Animation.TYPE_ROTATION_3D:
			continue
		var bone := anim.track_get_path(i).get_concatenated_subnames()
		var row: Array = out.get(bone, [-1, -1])
		row[0 if ty == Animation.TYPE_POSITION_3D else 1] = i
		out[bone] = row
	return out

## One bone's skeleton-space pose at clip time t, from the clip's tracks over the rest pose.
static func sample_pose(sk: Skeleton3D, anim: Animation, tracks: Dictionary, bone: int, t: float) -> Transform3D:
	var chain: Array[int] = []
	var b := bone
	while b >= 0:
		chain.append(b)
		b = sk.get_bone_parent(b)
	var g := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		var bi := chain[i]
		var rest := sk.get_bone_rest(bi)
		var pos := rest.origin
		var rot := rest.basis.get_rotation_quaternion()
		var tr: Array = tracks.get(sk.get_bone_name(bi), [-1, -1])
		if int(tr[0]) >= 0:
			pos = anim.position_track_interpolate(int(tr[0]), t)
		if int(tr[1]) >= 0:
			rot = anim.rotation_track_interpolate(int(tr[1]), t)
		g = g * Transform3D(Basis(rot) * Basis.from_scale(rest.basis.get_scale()), pos)
	return g

## Hand the hit location to whatever takes the damage next (Health / Vitals last_hit_part).
static func mark(target: Node, hit: Dictionary) -> void:
	var part: StringName = hit.get("part", &"")
	if target is Creature:
		(target as Creature).health.last_hit_part = part
	elif target is Player:
		(target as Player).vitals.last_hit_part = part
