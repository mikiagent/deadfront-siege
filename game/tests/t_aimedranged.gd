extends SceneTree
## AIMED RANGED (owner: "Crits should be small and hard to hit, so like a ranged weapon would be aiming at the crit but
## hardly hit it unless the animal is staying still or the projectile velocity is high"). Volleys of real projectiles
## (Hunt.aimed_shot: the section's live point plus spread, flown by StoneProjectile against the hurtboxes), seeded:
## 1. arrows aimed at a still raptor's head spot hit the spot at a high rate;
## 2. the same arrows at the raptor running across at 8 m/s hit it rarely;
## 3. at a moderate 2 m/s the faster arrow hits the spot more often than a stone;
## 4. a tyrannosaurus head (outside its collision capsule) is hittable: arrows land on the head section and its spot;
## 5. the spread grows with target speed and shrinks with projectile speed (shot_sigma).
## Usage: godot --headless --path game --script res://tests/t_aimedranged.gd -> "[t_aimedranged] PASS", exit 0.

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var HU: GDScript
var IS: GDScript
const N := 40

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
	print("[t_aimedranged] %s %s" % ["ok  " if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	HU = load("res://scripts/combat/hunt.gd")
	IS = load("res://scripts/items/item_stack.gd")
	root.get_node("Game").debug_overlay = false
	var CT: GDScript = load("res://scripts/combat/combat_tuning.gd")
	CT.force_dodge = 0.0
	CT.force_accuracy = 1.0
	HU.shot_rng.seed = 20261031
	host = Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await _frames(3)
	var bow = IS.make(&"pro_bow", 1, {}, 30)
	var sling = IS.make(&"slingshot", 1, {}, 30)
	_expect(HU.projectile_speed(&"arrow") > HU.projectile_speed(&"stone_shot"), "an arrow (%.0f m/s) flies faster than a stone (%.0f m/s)" % [HU.projectile_speed(&"arrow"), HU.projectile_speed(&"stone_shot")])
	_expect(HU.shot_sigma(12.0, 45.0, 0.0) < HU.shot_sigma(12.0, 18.0, 0.0), "the spread shrinks with projectile speed (%.2f vs %.2f m at 12 m)" % [HU.shot_sigma(12.0, 45.0, 0.0), HU.shot_sigma(12.0, 18.0, 0.0)])
	_expect(HU.shot_sigma(12.0, 45.0, 8.0) > HU.shot_sigma(12.0, 45.0, 0.0), "the spread grows with target speed (%.2f m at 8 m/s)" % HU.shot_sigma(12.0, 45.0, 8.0))

	var raptor = await _spawn(&"raptor", Vector3(0, 0, -12))
	var still: Array = await _volley(raptor, &"head", bow, &"arrow", Vector3.ZERO)
	_expect(still[0] >= 0.6, "arrows at a still raptor's head spot: %.0f %% hit the spot (%.0f %% hit the raptor)" % [still[0] * 100, still[1] * 100])
	var fast: Array = await _volley(raptor, &"head", bow, &"arrow", Vector3(8, 0, 0))
	_expect(fast[0] <= 0.15, "the same arrows at the raptor running across at 8 m/s: %.0f %% hit the spot (%.0f %% the raptor)" % [fast[0] * 100, fast[1] * 100])
	var a2: Array = await _volley(raptor, &"head", bow, &"arrow", Vector3(2, 0, 0))
	var s2: Array = await _volley(raptor, &"head", sling, &"stone_shot", Vector3(2, 0, 0))
	_expect(a2[0] > s2[0] + 0.15, "at 2 m/s the faster arrow hits the spot more often: arrow %.0f %%, stone %.0f %%" % [a2[0] * 100, s2[0] * 100])
	raptor.queue_free()
	await _frames(2)

	var rex = await _spawn(&"tyrannosaurus", Vector3(0, 0, -16))
	var head_cap := false
	var hb = load("res://scripts/combat/hurtboxes.gd").of(rex)
	for cap in hb.caps:
		if str(cap["part"]) == "Head":
			head_cap = true
	_expect(head_cap, "the tyrannosaurus has a head hurtbox")
	var rx: Array = await _volley(rex, &"head", bow, &"arrow", Vector3.ZERO)
	_expect(rx[2] >= 0.5 and rx[0] > 0.0, "arrows at a still tyrannosaurus head: %.0f %% land on the head section, %.0f %% in its spot" % [rx[2] * 100, rx[0] * 100])
	print("[t_aimedranged] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _spawn(id: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(root.get_node("Data").creature(id))
	c.health.setup(1e9)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	var to: Vector3 = player.global_position
	to.y = c.global_position.y
	c.look_at(to, Vector3.UP)  # head-on to the archer: its head is the nearest part
	await _frames(4)
	player.face_world(c.global_position)
	return c

## N shots at the section, the target moving at v (it runs past, centred on its start when the shots land).
## [share in the crit spot, share hitting the animal at all, share in the aimed section].
func _volley(c, section: StringName, w, ammo: StringName, v: Vector3) -> Array:
	var home: Vector3 = c.global_position
	var spot := 0
	var any := 0
	var sec := 0
	for k in N:
		# Each shot alone: the animal starts back along its run so it crosses the aim line as the shot arrives.
		var flight: float = player.global_position.distance_to(home) / HU.projectile_speed(ammo)
		c.global_position = home - v * flight
		c.velocity = v
		await _frames(1)
		var shot = HU.aimed_shot(player, w, c, section, ammo, host)
		var res := [{}]
		shot.landed.connect(func(r: Dictionary) -> void: res[0] = r)
		var f := 0
		while is_instance_valid(shot) and f < 120:
			c.global_position += v / 60.0
			await physics_frame
			f += 1
		var r: Dictionary = res[0]
		if not r.is_empty() and r.get("victim") == c:
			any += 1
			if not (r.get("spot", {}) as Dictionary).is_empty():
				spot += 1
			if r.get("section") == section:
				sec += 1
	c.global_position = home
	c.velocity = Vector3.ZERO
	return [float(spot) / N, float(any) / N, float(sec) / N]
