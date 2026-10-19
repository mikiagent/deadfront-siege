class_name AudioHooks
extends Node
## Turns game signals into sound events. Every node is hooked once through SceneTree.node_added,
## so screens and gameplay scripts never call audio themselves; they only emit.

const DIG_FAMILIES := ["mud", "clay"]
const STEP_MIN_SPEED := 0.6
const CREATURE_POLL_S := 0.25
const CREATURE_EAR_M := 90.0
## Notices that report a refusal get the error blip; anything else is a soft tick.
const ERROR_PREFIXES := ["Can't", "Bag is full", "Out of stamina", "Move closer", "Already", "No ", "Only ",
	"Snare need", "Equip an", "Coat your", "Need ", "Not enough"]
## When the strike lands inside each work clip (seconds), so the chop is heard on the hit.
## Button words that mean back-out or commit; every other button gets the plain click.
const CANCEL_WORDS := ["close", "cancel", "back", "dismiss", "no", "refund", "end combat", "×", "✕"]
const CONFIRM_WORDS := ["ok", "confirm", "yes", "done", "craft", "build", "unlock", "accept", "buy", "sell", "enter the rift", "respawn", "eat", "feed"]
const WORK_DELAY := {&"gather_chop": 0.36, &"gather_mine": 0.40, &"gather_pick": 0.22, &"gather_dig": 0.30,
	&"gather_butcher": 0.25, &"gather_craft": 0.30, &"survivor_eat": 0.35}

var director: AudioDirector
var player: Player
## True while something is actively fighting the survivor (music combat input).
var threat: bool = false

var _force_combat: bool = false
var _step_acc: float = 0.0
var _was_moving: bool = false
var _levels: Dictionary = {}       # skill tree -> last level heard
var _t_stones: int = -1
var _last_craft_ms: int = -100000
var _poll_left: float = 0.0
var _cstate: Dictionary = {}       # creature instance id -> {state, idle, alert_cd, hurt_cd, attack_cd, pos, step}

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)
	if World:
		World.pioneer_changed.connect(_on_pioneer_changed)

func _on_pioneer_changed(_level: int) -> void:
	director.play(&"ui_level_up")

func _scan(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_scan(c)

func consume_force_combat() -> bool:
	var f := _force_combat
	_force_combat = false
	return f

# ---------------------------------------------------------------- hookup

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		_once(n, func () -> void: (n as BaseButton).pressed.connect(_on_ui_pressed.bind(n)))
	elif n is HexButton:
		_once(n, func () -> void: (n as HexButton).pressed.connect(_on_ui_pressed.bind(n)))
	elif n is InventoryUI or n is CraftUI or n is MapScreen or n is AnimalScreen or n is SkillsSheet or n is FoodInspector or n is FatiguePanel:
		_once(n, func () -> void:
			n.set_meta(&"_audio_since", Time.get_ticks_msec())
			(n as CanvasItem).visibility_changed.connect(_on_panel_visibility.bind(n)))
	elif n is Player:
		_when_ready(n, _hook_player)
	elif n is Creature:
		_when_ready(n, _hook_creature)
	elif n is HarvestNode:
		_once(n, func () -> void: (n as HarvestNode).depleted_tile.connect(_on_depleted))
	elif n is StoneProjectile:
		_once(n, func () -> void:
			_projectile_release.call_deferred(n, &"proj_stone_release")
			n.tree_exiting.connect(_on_stone_exit.bind(n)))
	elif n is SiegeProjectile:
		_once(n, func () -> void:
			_projectile_release.call_deferred(n, &"proj_catapult_release")
			n.tree_exiting.connect(func () -> void: director.play(&"proj_catapult_hit", (n as Node3D).global_position)))
	elif n is Bonfire:
		_once(n, func () -> void: director.attach_loop(&"amb_fire", n as Node3D))

func _once(n: Node, hook: Callable) -> void:
	if n.has_meta(&"_audio_hooked"):
		return
	n.set_meta(&"_audio_hooked", true)
	hook.call()

func _when_ready(n: Node, hook: Callable) -> void:
	if n.has_meta(&"_audio_hooked"):
		return
	n.set_meta(&"_audio_hooked", true)
	if n.is_node_ready():
		hook.call(n)
	else:
		n.ready.connect(hook.bind(n), CONNECT_ONE_SHOT)

# ---------------------------------------------------------------- UI

func _on_ui_pressed(n: Node) -> void:
	director.play(button_event(n))

static func button_event(n: Node) -> StringName:
	var word := ""
	if n is Button:
		word = (n as Button).text
	elif n is HexButton:
		var h := n as HexButton
		word = h.caption if h.caption != "" else h.label_text
	word = word.strip_edges().to_lower()
	if word in CANCEL_WORDS:
		return &"ui_cancel"
	if word in CONFIRM_WORDS:
		return &"ui_confirm"
	return &"ui_click"

func _on_panel_visibility(n: Node) -> void:
	if Time.get_ticks_msec() - int(n.get_meta(&"_audio_since", 0)) < 600:
		return  # screens hide themselves while building; that is not the player closing them
	director.play(&"ui_panel_open" if (n as CanvasItem).visible else &"ui_panel_close")

func _on_notice(text: String) -> void:
	for p in ERROR_PREFIXES:
		if text.begins_with(p):
			director.play(&"ui_error")
			return
	director.play(&"ui_notice")

func _on_item_gained(_id: StringName, _n: int) -> void:
	if Time.get_ticks_msec() - _last_craft_ms < 200:
		return  # the craft chime already covers the crafted item landing in the bag
	director.play(&"ui_item_pickup")

func _on_crafted(_recipe: StringName) -> void:
	_last_craft_ms = Time.get_ticks_msec()
	director.play(&"ui_craft_complete")

func _on_skill_changed(tree: StringName, level: int) -> void:
	if level > int(_levels.get(tree, level)):
		director.play(&"ui_level_up")
	_levels[tree] = level

# ---------------------------------------------------------------- survivor

func _hook_player(p: Player) -> void:
	if p.vitals == null or not p.is_in_group("player"):
		return  # the hidden DefaultPlayfield survivor in labs never finishes setup
	player = p
	p.vitals.damaged.connect(_on_player_damaged)
	p.vitals.died.connect(func () -> void: director.play(&"survivor_death", p.global_position))
	p.anim.clip_played.connect(_on_player_clip)
	p.noticed.connect(_on_notice)
	p.item_gained.connect(_on_item_gained)
	p.context_used.connect(_on_context_used)
	if p.station_craft:
		p.station_craft.crafted.connect(_on_crafted)
	if p.skills:
		p.skills.skill_changed.connect(_on_skill_changed)
		for tree in p.skills.trees:
			_levels[StringName(str(tree))] = p.skills.level_of(str(tree))

func _on_player_damaged() -> void:
	_force_combat = true
	var at := player.global_position
	director.play(&"impact_flesh_medium", at)
	if player.inventory and player.inventory.equipped_armor() > 0.0:
		director.play(&"armour_hit", at)
	if not player.dead:
		director.play(&"survivor_hurt", at)

func _on_context_used(id: String) -> void:
	if id == "drink":
		director.play(&"survivor_drink", player.global_position)

func _on_player_clip(clip: StringName) -> void:
	if player == null:
		return
	var at := player.global_position
	match clip:
		&"attack_primary":
			director.play(&"swing_light", at)
		&"punch":
			director.play(&"swing_light", at, {"pitch": 1.12})
		&"attack_heavy":
			director.play(&"swing_heavy", at)
			if randf() < 0.6:
				director.play(&"survivor_effort", at)
		&"roll":
			director.play(&"survivor_roll", at)
		&"knockdown":
			director.play(&"knockdown_thud", at, {"delay": 0.35})
		&"sleep_down":
			director.play(&"survivor_sleep", at)
		&"sleep_up":
			director.play(&"survivor_wake", at)
		&"gather", &"gather_chop", &"gather_mine", &"craft":
			var ev := work_event(clip)
			director.play(ev, _work_position(), {"delay": float(WORK_DELAY.get(ev, 0.25))})

## Which work sound a clip means. The plain reach clip is shared by berry picking, eating,
## butchering and feeding, so the survivor's current job decides.
func work_event(clip: StringName) -> StringName:
	match clip:
		&"gather_chop":
			return &"gather_chop"
		&"gather_mine":
			return &"gather_mine"
		&"craft":
			return &"gather_craft"
	if player:
		if player.eat_session and player.eat_session.eating:
			return &"survivor_eat"
		if player.butcher_target and is_instance_valid(player.butcher_target):
			return &"gather_butcher"
		var node := player.gather_target
		if node and is_instance_valid(node):
			var role := str((Data.nature_families.get(node.family, {}) as Dictionary).get("role", ""))
			if node.family in DIG_FAMILIES or role == "ground":
				return &"gather_dig"
	return &"gather_pick"

func _work_position() -> Vector3:
	if player.gather_target and is_instance_valid(player.gather_target):
		return player.gather_target.global_position + Vector3.UP * 0.6
	if player.butcher_target and is_instance_valid(player.butcher_target):
		return player.butcher_target.global_position
	return player.global_position

## island_runtime.TileType values (the runtime has no class_name to import the enum from).
static func surface_for_tile(tile: int, snowy: bool) -> StringName:
	match tile:
		3:
			return &"sand"
		4, 8:
			return &"water"
		5, 9:
			return &"stone"
		6, 10:
			return &"mud"
	return &"snow" if snowy else &"dirt"

func surface_under(p: Player) -> StringName:
	if p.in_water:
		return &"water"
	var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.3, p.global_position + Vector3.DOWN * 2.2)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	var col := hit.get("collider") as Node
	if col and col.is_in_group("placed_building"):
		return &"wood"
	var rt := World.runtime
	if rt == null or not is_instance_valid(rt) or not rt.has_method("_tile_type_at_world"):
		return &"dirt"
	var local := p.global_position - rt.global_position
	var snowy := str(World.island_def.get("climate", "")) in ["tundra", "snowfield"]
	return surface_for_tile(int(rt.call("_tile_type_at_world", local.x, local.z)), snowy)

func _tick_steps(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.dead or player.rolling or player.mounted_on:
		_was_moving = false
		return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed < STEP_MIN_SPEED or not (player.is_on_floor() or player.in_water):
		_was_moving = false
		return
	# Stride grows with pace (5.5 m/s walk ~1.8 m, sprint caps at 2.2 m): about three steps a second.
	var stride := clampf(speed * 0.32, 0.9, 2.2)
	if not _was_moving:
		_was_moving = true
		_step_acc = stride * 0.7  # first footfall right after setting off
	_step_acc += speed * delta
	if _step_acc >= stride:
		_step_acc -= stride
		director.play(StringName("step_%s" % surface_under(player)), player.global_position, {"volume_db": 0.0 if speed > 6.0 else -2.0})

# ---------------------------------------------------------------- creatures

func _hook_creature(c: Creature) -> void:
	c.combat_float.connect(_on_creature_float.bind(c))
	c.health.died.connect(_on_creature_died.bind(c))
	c.anim.attack_windup.connect(_on_creature_windup.bind(c))

func _species(c: Creature) -> StringName:
	return c.def.id if c and c.def else &""

## Juveniles squeak higher; everything else uses the species pitch.
func _pitch(c: Creature) -> float:
	return 1.25 if "juvenile" in str(c.variant) else 1.0

func _impact_event(size: StringName) -> StringName:
	match size:
		&"small":
			return &"impact_flesh_small"
		&"large":
			return &"impact_hide_large"
		&"huge":
			return &"impact_hide_huge"
	return &"impact_flesh_medium"

func _on_creature_float(_amount: float, kind: StringName, c: Creature) -> void:
	if not is_instance_valid(c) or c.def == null or not kind in [&"hit", &"weak", &"strong", &"crit"]:
		return
	var at := c.global_position + Vector3.UP
	if player and is_instance_valid(player) and player.global_position.distance_to(c.global_position) < 20.0:
		_force_combat = true
	director.play(_impact_event(director.creature_size(_species(c))), at)
	if kind == &"crit":
		director.play(&"impact_crit", at)
	elif kind == &"strong":
		director.play(&"impact_bone", at, {"volume_db": -4.0})
	var st := _state(c)
	var now := Time.get_ticks_msec()
	if now >= int(st["hurt_cd"]) and randf() < 0.7:
		st["hurt_cd"] = now + 800
		director.play_creature(c, _species(c), &"hurt", _pitch(c))

func _on_creature_died(_source: Node, c: Creature) -> void:
	if not is_instance_valid(c) or c.def == null:
		return
	var size := director.creature_size(_species(c))
	director.play(_impact_event(size), c.global_position + Vector3.UP)
	director.play_creature(c, _species(c), &"death", _pitch(c))
	var fall_delay := {&"small": 0.45, &"medium": 0.7, &"large": 1.0, &"huge": 1.4}
	director.play(StringName("body_fall_%s" % size), c.global_position, {"delay": float(fall_delay.get(size, 0.7))})
	_cstate.erase(c.get_instance_id())

func _on_creature_windup(_clip: StringName, c: Creature) -> void:
	if not is_instance_valid(c) or c.def == null:
		return
	var st := _state(c)
	var now := Time.get_ticks_msec()
	if now >= int(st["attack_cd"]) and randf() < 0.85:
		st["attack_cd"] = now + 1200
		director.play_creature(c, _species(c), &"attack", _pitch(c))

func _state(c: Creature) -> Dictionary:
	var id := c.get_instance_id()
	if not _cstate.has(id):
		_cstate[id] = {"state": c.brain_state, "idle": randf_range(3.0, 15.0), "alert_cd": 0, "hurt_cd": 0, "attack_cd": 0,
			"pos": c.global_position, "step": 0.0}
	return _cstate[id]

## Brain-state edges give alert calls; roaming creatures call on a random timer; big ones thud.
func _tick_creatures(delta: float) -> void:
	_poll_left -= delta
	var poll := _poll_left <= 0.0
	if poll:
		_poll_left = CREATURE_POLL_S
	var ear := director.listener.global_position if director.listener else Vector3.ZERO
	var now := Time.get_ticks_msec()
	var danger := false
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.def == null or c.health == null or c.health.dead or not c.is_inside_tree():
			continue
		var d := c.global_position.distance_to(ear)
		if d > CREATURE_EAR_M:
			continue
		var st := _state(c)
		var size := director.creature_size(_species(c))
		if size in [&"large", &"huge"]:
			_tick_footfalls(c, st, size, delta)
		if not poll:
			continue
		var bs := c.brain_state
		if bs != st["state"]:
			var calm := str(st["state"]) in ["roam", "heel", "sleep", ""]
			var herb := c.def.is_herbivore_diet()
			if now >= int(st["alert_cd"]) and ((calm and bs in [&"alert", &"approach", &"chase"]) or (bs == &"flee" and herb)):
				st["alert_cd"] = now + 8000
				director.play_creature(c, _species(c), &"alert", _pitch(c))
			st["state"] = bs
		if bs in [&"roam", &"heel"] and d < 55.0:
			st["idle"] = float(st["idle"]) - CREATURE_POLL_S
			if float(st["idle"]) <= 0.0:
				st["idle"] = randf_range(6.0, 14.0) if size == &"small" else randf_range(10.0, 24.0)
				director.play_creature(c, _species(c), &"idle", _pitch(c))
		if player and not c.is_pet and bs in [&"alert", &"approach", &"attack", &"chase"] and c.global_position.distance_to(player.global_position) < 35.0:
			var b := c.brain
			if b and b.get("attack_target") == player:
				danger = true
	if poll:
		threat = danger or (player != null and is_instance_valid(player) and player.vitals != null and player.vitals.in_combat and not player.dead)

func _tick_footfalls(c: Creature, st: Dictionary, size: StringName, delta: float) -> void:
	var pos := c.global_position
	var moved := Vector2(pos.x - (st["pos"] as Vector3).x, pos.z - (st["pos"] as Vector3).z).length()
	st["pos"] = pos
	if moved > 3.0 or moved <= 0.0001:
		return  # a warp or standing still
	st["step"] = float(st["step"]) + moved
	var stride := clampf(c.def.height_meters * 0.75, 2.5, 7.0)
	if float(st["step"]) >= stride:
		st["step"] = float(st["step"]) - stride
		director.play(&"creature_step_huge" if size == &"huge" else &"creature_step_large", pos)

# ---------------------------------------------------------------- world

func _on_depleted(node: HarvestNode, _tile: Vector2i) -> void:
	var role := str((Data.nature_families.get(node.family, {}) as Dictionary).get("role", ""))
	var ev := &"node_depleted_tree" if role.begins_with("tree") else (&"node_depleted_rock" if role == "rock" else &"node_depleted_bush")
	director.play(ev, node.global_position + Vector3.UP * 0.5)

func _projectile_release(n: Node, ev: StringName) -> void:
	if is_instance_valid(n) and n.is_inside_tree():
		director.play(ev, (n as Node3D).global_position)

## The shot frees itself with range left only when it struck something.
func _on_stone_exit(n: StoneProjectile) -> void:
	if n.range_left > 0.05 and is_instance_valid(n.source):
		director.play(&"proj_stone_hit", n.global_position)

func _process(delta: float) -> void:
	if player and not is_instance_valid(player):
		player = null
	_tick_steps(delta)
	_tick_creatures(delta)
	if World and World.t_stones != _t_stones:
		if _t_stones >= 0:
			director.play(&"ui_tstone" if World.t_stones > _t_stones else &"ui_coin")
		_t_stones = World.t_stones
