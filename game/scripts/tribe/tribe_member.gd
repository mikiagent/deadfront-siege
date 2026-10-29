class_name TribeMember
extends CharacterBody3D
## TRIBE M1: the live body of a TribeRecord - the survivor's own model, rig and clips with the member's
## look. It follows and fights with pet-style orders (PetBrain's follow slots, Hunt's swing rules), or
## works its one job at home: walk to a node of the job's kind inside the radius, harvest ONE item per
## pass at the tool's speed (GatherService), carry, deposit into the chosen chest, eat from storage
## when hungry, rest when exhausted. A recruit still waiting at the dock (pending) only stands there.
## Kills leave the corpse on the ground as any kill does; a member never butchers or loots.

const PENDING_GROUP := &"tribe_pending"
const GROUP := &"tribe_member"
const HALF_H := 1.0  # capsule half height (the survivor's 2 m capsule)
const RADIUS := 0.35
const THINK_S := 0.2
const GATHER_CLIPS := {&"mine": &"gather_mine", &"chop": &"gather_chop", &"gather": &"gather"}

var record: TribeRecord
var pending: bool = false
var health: Health
var rig: RiggedModel
var visual: Node3D
## What the brain is doing: idle, follow, fight, find, walk, gather, deposit, eat, rest, down.
var state: StringName = &"idle"
var target: Creature
## Every harvest this body made: {"item", "count", "seconds"} (tests and the report read it).
var harvests: Array[Dictionary] = []
var deposited: int = 0
var meals: int = 0

var _goal := Vector3.ZERO
var _moving := false
var _running := false
var _path := PackedVector3Array()
var _path_i := 0
var _replan_left := 0.0
var _think_left := 0.0
var _following := false
var _swing_cd := 0.0
var _swing_pending := false
var _work_node: HarvestNode
var _work_left := 0.0
var _unit_s := 0.0
var _no_food_until := -1.0
var _clip: StringName = &""
var _held: Node3D
var _held_id: StringName = &""
var _tools := Inventory.new(1)
## TRIBE M2a: the station or site of its work order, and the plate over its head that names the job.
var _station: Node3D
var plate: Label3D
var _hammer: Array[MeshInstance3D] = []
var _hammer_loaded := false

func setup(rec: TribeRecord, p_pending: bool = false) -> void:
	record = rec
	pending = p_pending
	name = "Tribe_%s" % rec.uid

func _ready() -> void:
	add_to_group(PENDING_GROUP if pending else GROUP)
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HALF_H * 2.0
	shape.shape = cap
	add_child(shape)
	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.setup(record.max_hp())
	health.hp = record.hp()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_rig()
	plate = StationState.floating_label("JobPlate", HALF_H + 0.55)
	plate.font_size = 30
	plate.visible = false
	add_child(plate)
	var p := PlayerRegistry.local()
	if p:
		add_collision_exception_with(p)  # never shove or block the survivor (as pets pass through)

func _build_rig() -> void:
	var meta: Dictionary = CharacterLook._json(CharacterLook.SURVIVOR_JSON)  # the survivor's pipeline row, as build_rig reads it
	var pipeline: Dictionary = meta.get("pipeline", {})
	var height := float(meta.get("height_meters", 1.72))
	rig = RiggedModel.new()
	rig.name = "Rig"
	visual.add_child(rig)
	if not rig.setup(CharacterLook.SURVIVOR_GLB, CharacterLook.SURVIVOR_ANIM_DIR, str(pipeline.get("forward_axis", "+Z")), height, "tribe", true, float(pipeline.get("source_height_m", height))):
		return
	for node in rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		PlayerView.web_safe_mesh(node as MeshInstance3D)
	rig.scale *= 1.18  # the survivor's silhouette lift (PlayerView), so a member reads as her size
	rig.position.y = -HALF_H
	CharacterLook.apply(rig, record.look)
	rig.clip_finished.connect(_on_clip_finished)
	_play(&"idle")

func _exit_tree() -> void:
	if record and not pending and is_inside_tree():
		record.pos = [global_position.x, global_position.y, global_position.z]
	if _work_node and is_instance_valid(_work_node) and _work_node.get_meta(&"tribe_claim", "") == record.uid:
		_work_node.remove_meta(&"tribe_claim")
	CharacterLook.release(rig)

# ---------------------------------------------------------------- tick

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	_swing_cd = maxf(0.0, _swing_cd - delta)
	if not pending:
		_tick_needs(delta)
		_think_left -= delta
		if _think_left <= 0.0:
			_think_left = THINK_S
			_think()
		if state == &"gather":
			_tick_gather(delta)
		elif state == &"craft":
			TribeWork.advance(record, _station if is_instance_valid(_station) else null, delta)
		elif state == &"rest" or state == &"down":
			_tick_rest(delta)
	_steer(delta)
	move_and_slide()
	_animate()
	if not pending:
		record.pos = [global_position.x, global_position.y, global_position.z]
		record.health = health.hp

## Fullness drains all day; energy and HP come back while not working or fighting.
func _tick_needs(delta: float) -> void:
	record.fullness = maxf(0.0, record.fullness - Tribe.num("fullness_per_day", 60.0) / Tribe.day_seconds() * delta)
	if state in [&"idle", &"follow", &"walk", &"find", &"deposit", &"eat", &"rest"]:
		record.energy = minf(Tribe.num("energy_max", 100.0), record.energy + Tribe.num("energy_regen_per_s", 1.5) * delta)
	if state != &"fight" and not health.dead:
		health.heal(Tribe.num("hp_regen_per_s", 0.4) * delta)

func _think() -> void:
	if state == &"down":
		return
	var p := PlayerRegistry.local()
	if record.is_following():
		if p == null or p.dead:
			_stop_work()
			_halt(&"idle")
			return
		var t := _pick_target(p)
		if t:
			_fight(t)
		else:
			target = null
			_follow(p)
		return
	target = null
	_sync_plate()
	if TribeWork.is_station_job(record):
		_station_work()
		return
	if record.order == &"work" and not record.job.is_empty():
		_work()
		return
	_stop_work()
	_halt(&"idle")

# ---------------------------------------------------------------- follow and fight

## Its follow slot: after the survivor's summoned pets, in tribe order (PetBrain's slot geometry).
func follow_slot(p: Player) -> Vector3:
	var idx := p.pets.summoned.size() if p.pets else 0
	for r in Tribe.members:
		if r == record:
			break
		if r.is_following():
			idx += 1
	return PetBrain.slot_for(p, idx, RADIUS, &"heel" if record.order == &"heel" else &"guard")

func _follow(p: Player) -> void:
	_stop_work()
	var slot := follow_slot(p)
	var d := _flat(global_position, slot)
	# ASSUMPTION: the pet band without the size scale (walk past 4 m from the slot, settle inside 1.5 m).
	if d > 4.0:
		_following = true
	elif d < 1.5:
		_following = false
	state = &"follow"
	if _following:
		_go(slot, d > 8.0)
	else:
		_moving = false

## guard: what fights the survivor, her pets or this member, and her own hunt target. follow: only what
## fights this member. attack: the survivor's hunt target. heel: nothing.
func _pick_target(p: Player) -> Creature:
	if record.order == &"heel":
		return null
	if record.order in [&"guard", &"attack"] and p.hunt and _alive(p.hunt.target):
		return p.hunt.target
	if record.order == &"attack":
		return null
	var best: Creature = null
	var best_d := Tribe.num("guard_radius_m", 9.0) if record.order == &"guard" else 30.0
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if not _alive(c) or c.is_pet or c.brain == null:
			continue
		var at: Variant = c.brain.get("attack_target")
		var on_me: bool = at == self
		var on_her: bool = record.order == &"guard" and c.brain.has_method("hunting_player") and c.brain.hunting_player()
		if not (on_me or on_her) or not c.brain.state in CreatureBrain.COMBAT_STATES:
			continue
		var d := minf(c.global_position.distance_to(global_position), c.global_position.distance_to(p.global_position))
		if d < best_d:
			best_d = d
			best = c
	if best and best.global_position.distance_to(p.global_position) > Tribe.num("leash_m", 20.0):
		return null
	return best

func _alive(c: Variant) -> bool:
	return c is Creature and is_instance_valid(c) and not (c as Creature).health.dead

func _fight(t: Creature) -> void:
	_stop_work()
	target = t
	state = &"fight"
	var reach := Hunt.melee_reach(t)
	var d := _flat(global_position, t.global_position)
	if d > reach:
		_go(t.global_position, true)
		return
	_moving = false
	_face(t.global_position)
	if _swing_cd > 0.0 or _swing_pending:
		return
	var w := _weapon()
	var rate := w.def().attack_rate if w and w.def() and w.def().attack_rate > 0.0 else 1.0
	_swing_cd = maxf(1.0 / maxf(0.2, rate), Tribe.num("swing_cooldown_s", 1.1))
	_swing_pending = true
	_play(&"attack_primary" if w else (&"punch" if rig and rig.has_clip(&"punch") else &"attack_primary"), true)
	record.energy = maxf(0.0, record.energy - Tribe.num("energy_per_swing", 4.0))
	get_tree().create_timer(Hunt.hit_delay(w), false).timeout.connect(_on_swing_hit.bind(weakref(t), w), CONNECT_ONE_SHOT)

func _on_swing_hit(ref: WeakRef, w: ItemStack) -> void:
	_swing_pending = false
	var t := ref.get_ref() as Creature
	if t == null or t != target or t.health.dead or health.dead:
		return
	if _flat(global_position, t.global_position) > Hunt.melee_reach(t) + 0.3:
		return
	land_hit(t, w)

## One landed swing: Hunt's damage model (weapon or fists, work tools weaker, defense, +1 % per Melee
## level). The damage source is this member, so the kill credit and corpse rules stay the world's.
func land_hit(t: Creature, w: ItemStack) -> float:
	var tune := CombatTuning.section("player_melee")
	var dmg := Tribe.num("unarmed_damage", 6.0)
	if w:
		dmg = w.scaled_damage()
		if w.def() and w.def().is_work_tool:
			dmg *= float(tune.get("work_tool_mult", 0.45))
	var defense := t.defense_for(false) * t.statuses.defense_mult()
	var dealt: float = maxf(dmg * float(tune.get("min_damage_frac", 0.05)), dmg - defense * float(tune.get("defense_factor", 0.5)))
	dealt *= 1.0 + float(tune.get("damage_per_melee_level", 0.01)) * float(record.skill("melee") - 1)
	t.health.take_damage(dealt, self)
	record.add_skill_xp("melee", Tribe.num("xp_per_hit", 2.0))
	if w and w.max_durability > 0:
		w.wear(1)
	print("[tribe] %s hit %s dmg=%.1f" % [record.name, t.def.id, dealt])
	return dealt

func _weapon() -> ItemStack:
	var w := record.equipment.worn(&"weapon")
	return null if w == null or w.is_broken() else w

## A creature's bite (CreatureAttack): the member's own defense, base + worn armour.
func take_creature_hit(attacker: Creature, atk: float) -> bool:
	if health.dead:
		return false
	var armor := 0.0
	for slot in [&"head", &"body", &"arms", &"legs"]:
		var it := record.equipment.worn(slot)
		if it and not it.is_broken():
			armor += it.scaled_armor()
	var dealt := CreatureAttack.mitigated(atk, Tribe.num("base_defense", 15.0) + armor)
	health.take_damage(dealt, attacker)
	return true

func _on_damaged(_amount: float, _source: Node) -> void:
	if not health.dead and rig and rig.has_clip(&"hit_react") and state != &"gather":
		_play(&"hit_react", true)

## ASSUMPTION (M1): a member at 0 HP is knocked out, not killed; it lies down and gets up at half HP.
## Permanent death on expeditions is a later milestone (vision §5 continuity after loss).
func _on_died(_source: Node) -> void:
	print("[tribe] %s is down" % record.name)
	target = null
	_stop_work()
	_halt(&"down")
	_play(&"knockdown" if rig and rig.has_clip(&"knockdown") else &"sleep", true)

# ---------------------------------------------------------------- work

## Rest when exhausted, eat from the job's chest when hungry. True when that took the turn.
func _tend_needs() -> bool:
	var m := record
	if m.fatigue >= Tribe.num("rest_at", 75.0) or m.energy < Tribe.num("energy_per_harvest", 3.0):
		_stop_work()
		_halt(&"rest")
		return true
	var now := Time.get_ticks_msec() / 1000.0
	if m.fullness < Tribe.num("eat_below", 30.0) and now >= _no_food_until:
		var food_at := _storage_with_food()
		if food_at:
			_eat_from(food_at)
			return true
		_no_food_until = now + 30.0  # ASSUMPTION: nothing to eat; look again in 30 s, keep working
	return false

func _work() -> void:
	var m := record
	if state == &"rest":
		return
	if _tend_needs():
		return
	if m.carry.used_slots() >= mini(int(Tribe.num("carry_units", 5.0)), m.carry.slot_count):
		_deposit()
		return
	if state == &"gather":
		return
	if _work_node == null or not is_instance_valid(_work_node) or _work_node.pool_units_left() <= 0:
		_release_node()
		_work_node = _find_node()
		if _work_node == null:
			if m.carry.used_slots() > 0:
				_deposit()
			else:
				_halt(&"idle")  # nothing left to work in the radius: wait for regrowth
			return
		_work_node.set_meta(&"tribe_claim", m.uid)
	var reach := work_reach(_work_node)
	if _flat(global_position, _work_node.global_position) > reach:
		state = &"walk"
		_go(_stand_near(_work_node.global_position, reach - 0.25), false)
		return
	_begin_gather()

## Stand at the node's edge, not inside it: its collision half-width plus the body and a hand's reach.
static func work_reach(n: HarvestNode) -> float:
	return n.visual_radius() + RADIUS + 0.3  # ASSUMPTION: 0.3 m arm's reach past the visible edge

func job_center() -> Vector3:
	var c: Array = record.job.get("center", [0.0, 0.0])
	return Vector3(float(c[0]), global_position.y, float(c[1]))

## The nearest node of the job's kind inside the radius that this member's tool can work.
func _find_node() -> HarvestNode:
	_sync_tools()
	var kind := StringName(str(record.job.get("kind", "")))
	var center := job_center()
	var radius := float(record.job.get("radius", 12.0))
	var best: HarvestNode = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("harvest"):
		var h := n as HarvestNode
		if h == null or h.is_queued_for_deletion() or h.pool_units_left() <= 0 or h.gather_kind() != kind:
			continue
		if _flat(h.global_position, center) > radius:
			continue
		var claim: String = str(h.get_meta(&"tribe_claim", ""))
		if claim != "" and claim != record.uid:
			continue
		if h.can_gather(_tools) != "":
			continue
		var d := _flat(h.global_position, global_position)
		if d < best_d:
			best_d = d
			best = h
	return best

func _sync_tools() -> void:
	_tools.slots[0] = record.equipment.worn(&"weapon")

func _begin_gather() -> void:
	_sync_tools()
	_moving = false
	_face(_work_node.global_position)
	_unit_s = GatherService.unit_seconds_for(_tools, _work_node, record.skill("gathering"))
	_work_left = _unit_s
	state = &"gather"
	_show_held(record.equipment.worn(&"weapon"))
	_play(GATHER_CLIPS.get(_work_node.gather_kind(), &"gather"), true)

func _tick_gather(delta: float) -> void:
	if _work_node == null or not is_instance_valid(_work_node):
		state = &"find"
		return
	_work_left -= delta
	if _work_left <= 0.0:
		_harvest()

## ONE item per pass (ONEGATHER), the node's tool and tier rules (can_gather), tool wear, the Gathering
## downrank floor of 5, into the member's carry.
func _harvest() -> void:
	var node := _work_node
	state = &"find"
	_sync_tools()
	if node.can_gather(_tools) != "":
		_release_node()
		return
	if node.required_tool_class != &"" and node.required_tool_class != &"none":
		if not _tools.wear_gather_tool(node.required_tool_class):
			_release_node()
			return
	var stack := node.roll_yield(GatherService.rng, GatherService.tool_tier(_tools, node.required_tool_class, node.family), maxi(1, record.skill("gathering")))
	var cap := maxi(record.skill("gathering"), 5)
	if stack.level > cap:
		stack.level = cap
		stack.attributes["level"] = cap
	var units := stack.count  # always 1 (ONEGATHER); read before the bag takes the instance
	if record.carry.add(stack) > 0:
		_deposit()
		return
	node.consume_unit()
	GatherService.wear_role_tool(_tools, node.required_tool_class, node.family)
	harvests.append({"item": stack.def_id, "count": units, "seconds": _unit_s})
	record.add_skill_xp("gathering", Tribe.num("xp_per_harvest", 2.0))
	record.fatigue = minf(Tribe.num("fatigue_max", 100.0), record.fatigue + Tribe.num("fatigue_per_harvest", 2.5))
	record.energy = maxf(0.0, record.energy - Tribe.num("energy_per_harvest", 3.0))
	print("[tribe] %s +1 %s (%.2fs, pool %d)" % [record.name, stack.def_id, _unit_s, node.pool_units_left()])
	_work()  # straight into the next pass, or off to the chest / meal / rest

func _release_node() -> void:
	if _work_node and is_instance_valid(_work_node) and str(_work_node.get_meta(&"tribe_claim", "")) == record.uid:
		_work_node.remove_meta(&"tribe_claim")
	_work_node = null

func _stop_work() -> void:
	_release_node()
	_station = null
	if state in [&"gather", &"walk", &"find", &"deposit", &"eat", &"rest", &"craft"]:
		state = &"idle"

# ---------------------------------------------------------------- M2a station work orders

## A craft or build order: walk to the station (or site), then work it with the station's clip while
## TribeWork.advance runs the clock. A station that is gone pauses a craft (Stay cancels it and hands
## the materials back); a site that is gone (finished or cancelled by the survivor) ends the order.
func _station_work() -> void:
	if state == &"rest":
		return
	if _tend_needs():
		return
	var t := TribeWork.target_of(record)
	if t == null:
		_station = null
		if TribeWork.job_kind(record) == &"build":
			TribeWork.cancel(PlayerRegistry.local(), record)
		_halt(&"idle")
		return
	_station = t
	if state == &"craft":
		return
	var r := TribeWork.reach(t)
	if _flat(global_position, t.global_position) > r:
		state = &"walk"
		_go(_stand_near(t.global_position, r - 0.4), false)
		return
	state = &"craft"
	_moving = false
	_face(t.global_position)
	_show_held(null)
	_play(work_clip(), true)

## The station's work loop (station_state.json work_anim: hammer at the workbench, stir at the grill),
## a hammer at a construction site, the old craft reach when the station names none.
func work_clip() -> StringName:
	var kind := &"hammer"
	if TribeWork.job_kind(record) == &"craft":
		kind = StationState.work_kind(StringName(str(record.job.get("station_id", ""))))
	var clip := StringName("work_" + str(kind)) if kind != &"" else &"craft"
	return clip if rig and rig.has_clip(clip) else &"craft"

func _sync_plate() -> void:
	if plate == null:
		return
	var on := TribeWork.is_station_job(record)
	plate.visible = on
	if on:
		plate.text = "%s\n%s" % [record.name, TribeWork.plate_text(record)]

## The survivor's skinned work hammer (PlayerAnim.HAMMER_GLB) in the fist during hammer clips.
func _sync_hammer(clip: StringName) -> void:
	var show := clip in PlayerAnim.HAMMER_CLIPS
	if show and not _hammer_loaded and rig and rig.skeleton:
		_hammer_loaded = true
		_hammer = RiggedModel.attach_skinned(rig.skeleton, PlayerAnim.HAMMER_GLB)
	for mi in _hammer:
		if is_instance_valid(mi):
			mi.visible = show

## The job's chest: the storage building nearest the chosen spot (or the job centre), else null.
func storage() -> Node3D:
	var c: Array = record.job.get("chest", [])
	var at := job_center() if c.is_empty() else Vector3(float(c[0]), 0.0, float(c[1]))
	var best: Node3D = null
	var best_d := 30.0  # ASSUMPTION: a chest farther than 30 m from the chosen spot is not this job's
	for n in get_tree().get_nodes_in_group("placed_building"):
		if n.get("storage") == null or n.is_queued_for_deletion():
			continue
		var d := _flat((n as Node3D).global_position, at)
		if d < best_d:
			best_d = d
			best = n
	return best

func _storage_with_food() -> Node3D:
	var s := storage()
	if s == null:
		return null
	for st in (s.get("storage") as Inventory).slots:
		if Food.is_food(st) and not Food.is_poisoned(st):
			return s
	return null

func _near(n: Node3D) -> bool:
	return _flat(global_position, n.global_position) <= 2.0

func _deposit() -> void:
	_release_node()
	var s := storage()
	if s == null:
		_halt(&"idle")  # no chest: hold what it carries and wait (the Tribe screen says so)
		return
	state = &"deposit"
	if not _near(s):
		_go(_stand_near(s.global_position, 1.5), false)
		return
	_moving = false
	var inv := s.get("storage") as Inventory
	for i in record.carry.slot_count:
		var st := record.carry.slots[i]
		if st == null or st.def_id == Inventory.LOCK:
			continue
		var had := st.count  # Inventory.add may take the instance itself, so count first
		var left := inv.add(st)
		var moved := had - left
		deposited += moved
		if left <= 0:
			record.carry.slots[i] = null
		else:
			st.count = left
	record.carry.changed.emit()
	inv.changed.emit()
	print("[tribe] %s deposited into %s (%d total)" % [record.name, s.name, deposited])
	state = &"find"

func _eat_from(s: Node3D) -> void:
	_release_node()
	state = &"eat"
	if not _near(s):
		_go(_stand_near(s.global_position, 1.5), false)
		return
	_moving = false
	var inv := s.get("storage") as Inventory
	for i in inv.slot_count:
		var st := inv.slots[i]
		if Food.is_food(st) and not Food.is_poisoned(st):
			var one := inv.remove_at(i, 1)
			var gain := maxf(Tribe.num("food_min", 15.0), Food.energy_restore(one))
			record.fullness = minf(Tribe.num("fullness_max", 100.0), record.fullness + gain)
			meals += 1
			_play(&"eat" if rig and rig.has_clip(&"eat") else &"idle", true)
			print("[tribe] %s ate %s (+%.0f, fullness %.0f)" % [record.name, one.def_id if one else &"?", gain, record.fullness])
			break
	state = &"find"

func _tick_rest(delta: float) -> void:
	_moving = false
	var m := record
	m.fatigue = maxf(0.0, m.fatigue - Tribe.num("rest_recover_per_s", 4.0) * delta)
	m.energy = minf(Tribe.num("energy_max", 100.0), m.energy + Tribe.num("rest_recover_per_s", 4.0) * delta)
	if state == &"down":
		health.hp = minf(health.max_hp, health.hp + Tribe.num("hp_regen_per_s", 0.4) * 3.0 * delta)
		if health.fraction() >= 0.5:
			health.dead = false
			state = &"idle"
			print("[tribe] %s is back up" % m.name)
		return
	if m.fatigue <= Tribe.num("rest_until", 10.0) and m.energy >= Tribe.num("energy_max", 100.0) * 0.5:
		state = &"idle"
		print("[tribe] %s rested" % m.name)

# ---------------------------------------------------------------- movement and clips

## The spot `dist` from `at` on this member's side: walk to the edge of a rock or chest, not into it.
func _stand_near(at: Vector3, dist: float) -> Vector3:
	var away := global_position - at
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3.BACK
	return at + away.normalized() * maxf(0.0, dist)

func _halt(s: StringName) -> void:
	state = s
	_moving = false

func _go(at: Vector3, run: bool) -> void:
	if not _moving or _goal.distance_to(at) > 1.0:
		_replan_left = 0.0
	_goal = at
	_moving = true
	_running = run

func _steer(delta: float) -> void:
	if not _moving or state in [&"down", &"rest", &"gather", &"craft"]:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := _next_dir(delta)
	var speed := Tribe.num("run_mps", 5.6) if _running else Tribe.num("walk_mps", 3.4)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length_squared() > 0.01:
		_face(global_position + dir)

## Tile path on an island (the creatures' pathing), else straight at the goal (labs).
func _next_dir(delta: float) -> Vector3:
	var pathing: Variant = World.runtime.get("pathing") if World and World.runtime and get_parent() == World.runtime else null
	if pathing != null:
		_replan_left -= delta
		if _replan_left <= 0.0:
			_replan_left = 0.5
			_path = pathing.path(global_position, _goal, 72)
			_path_i = 0
		while _path_i < _path.size():
			var to := _path[_path_i] - global_position
			to.y = 0.0
			if to.length() > 0.3:
				return to.normalized()
			_path_i += 1
	var direct := _goal - global_position
	direct.y = 0.0
	return direct.normalized() if direct.length() > 0.3 else Vector3.ZERO

func _face(at: Vector3) -> void:
	var to := at - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		visual.rotation.y = atan2(-to.x, -to.z)  # RiggedModel faces -Z

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

const ONESHOTS: Array[StringName] = [&"attack_primary", &"attack_heavy", &"punch", &"hit_react", &"eat", &"knockdown", &"gather", &"gather_mine", &"gather_chop"]

func _play(clip: StringName, force: bool = false) -> void:
	if rig == null or rig.anim_player == null:
		_clip = clip
		return
	if clip == _clip and not force:
		return
	if not rig.has_clip(clip):
		clip = &"idle"
	_clip = clip
	rig.play(clip, 1.0, 0.15)
	_sync_hammer(clip)

func _on_clip_finished(clip: StringName) -> void:
	if state == &"gather" and clip in GATHER_CLIPS.values():
		_play(clip, true)  # the work loop re-triggers its one-shot, as PlayerAnim does
	elif state == &"craft" and (clip in PlayerAnim.WORK_CLIPS or clip == &"craft"):
		_play(clip, true)
	elif clip in ONESHOTS:
		_clip = &""

func _animate() -> void:
	if _clip in ONESHOTS or state == &"craft":
		return
	var want: StringName = &"idle"
	if state == &"rest" or state == &"down":
		want = &"sleep" if rig and rig.has_clip(&"sleep") else &"idle_exhausted"
	elif Vector2(velocity.x, velocity.z).length() > 0.3:
		want = &"run" if _running else &"walk"
	elif record and record.fatigue >= Tribe.num("rest_at", 75.0) * 0.67:
		want = &"idle_tired"
	_play(want)
	if state != &"gather" and state != &"fight":
		_show_held(null)
	elif state == &"fight":
		_show_held(_weapon())

## The worn tool or weapon in the right fist while it works or fights (HeldModel, the survivor's grip).
func _show_held(s: ItemStack) -> void:
	var id: StringName = s.def_id if s else &""
	if id == _held_id:
		return
	_held_id = id
	if _held and is_instance_valid(_held):
		_held.queue_free()
	_held = null
	if s and rig and rig.hand_socket:
		_held = HeldModel.attach(rig.hand_socket, id, state == &"fight")
